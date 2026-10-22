#!/usr/bin/env python3
"""Publish the generated blocks after the inserted history at their own slot times, then hand over to the validators.

usage: drip.py --chain DIR --history-head SLOT --out DIR --seconds-per-slot N --go-file FILE
               [--lead-slots L] [--vc-lead-seconds S] [--el-confirm name,...] name=http://beacon:port[@http://el:port] ...

Every node already holds the chain up to --history-head. Each later block (and its envelope) goes to every node at
the start of its slot; a node that is down or answers 503 is retried until it takes it. Once --go-file exists, the
script waits for every node to be at the current block, picks the handover slot X = wall slot + L, stops publishing
after X, and writes the slashing-protection interchange for X with handover.json/handover.env into --out.
"""
import argparse
import json
import os
import sys
import threading
import time

import insert

POST_RETRY = 0.5
NODE_DOWN_TIMEOUT = 180
CAUGHT_UP_TIMEOUT = 240


def slot_start(genesis, sps, slot):
    return genesis + slot * sps


def wall_slot(genesis, sps):
    return int((time.time() - genesis) // sps)


class Drip:
    def __init__(self, blocks, genesis, sps):
        self.blocks = blocks
        self.genesis = genesis
        self.sps = sps
        self.stop_slot = blocks[-1]["slot"] if blocks else None
        self.lock = threading.Lock()

    def stop_at(self, slot):
        with self.lock:
            self.stop_slot = slot

    def allowed(self, slot):
        with self.lock:
            return slot <= self.stop_slot


# Posts until the node confirms; connection errors and 503s mean the node is restarting or catching up, so keep trying.
def post_until_confirmed(node, url, body, headers, codes, confirm):
    deadline = time.time() + NODE_DOWN_TIMEOUT
    while time.time() < deadline:
        if confirm():
            return True
        st, _ = insert.http("POST", url, body=body, headers=headers)
        node.posts += 1
        codes[st] = codes.get(st, 0) + 1
        if insert.wait_until(confirm, POST_RETRY if st in (-1, 503) else insert.CONFIRM_TIMEOUT):
            return True
    return False


def drip_node(node, chain, drip):
    block_url = node.url + "/eth/v2/beacon/blocks"
    envelope_url = node.url + "/eth/v1/beacon/execution_payload_envelopes?broadcast_validation=consensus"
    node.confirmed = {}
    for b in drip.blocks:
        slot, version = b["slot"], b["version"]
        while time.time() < slot_start(drip.genesis, drip.sps, slot):
            time.sleep(0.01)
        if not drip.allowed(slot):
            break
        with open(f"{chain}/blocks/{slot}.ssz", "rb") as f:
            block = f.read()
        body = block if version in insert.BARE_BLOCK_FORKS else insert.with_empty_blobs(block)
        headers = {"Content-Type": "application/octet-stream", "Eth-Consensus-Version": version}
        posted = time.time()
        if not post_until_confirmed(node, block_url, body, headers, node.codes, lambda: insert.block_imported(node, slot, b["root"])):
            node.unconfirmed.append(slot)
            return
        if b.get("envelope_ssz_bytes") is not None:
            with open(f"{chain}/envelopes/{slot}.ssz", "rb") as f:
                body = insert.with_empty_blobs(f.read())
            headers = {"Content-Type": "application/octet-stream", "Eth-Consensus-Version": version, "Eth-Blob-Data-Included": "true"}
            if not post_until_confirmed(node, envelope_url, body, headers, node.envelope_codes, lambda: insert.envelope_imported(node, b)):
                node.unconfirmed_envelopes.append(slot)
                return
        node.confirmed[slot] = round(time.time() - slot_start(drip.genesis, drip.sps, slot), 3)
        node.late = max(node.late, time.time() - posted)


def caught_up(nodes, roots, genesis, sps, last_slot):
    current = min(wall_slot(genesis, sps), last_slot)
    expected = roots.get(current)
    for n in nodes:
        slot, root = insert.head(n.url)
        if slot is None or slot < current or (expected is not None and slot == current and root != expected):
            return False
    return True


# One record per key: its last generated block at or before X, and its last attestation published in a block at or before X.
# Without per-slot attester records, the generated tip's watermark is used as is: safe, but it may skip duties up to X.
def interchange_for(chain, handover_slot):
    full = json.load(open(f"{chain}/interchange.json"))
    if not os.path.exists(f"{chain}/attesters.json"):
        print("ff-drip: no attesters.json, using the watermark at the generated tip", flush=True)
        return full
    manifest = json.load(open(f"{chain}/manifest.json"))
    attesters = json.load(open(f"{chain}/attesters.json"))
    blocks = {}
    for b in manifest:
        if b["slot"] <= handover_slot:
            i = int(b["proposer_index"])
            blocks[i] = max(blocks.get(i, 0), b["slot"])
    marks = {}
    for rec in attesters:
        if int(rec["slot"]) >= handover_slot:
            continue
        target = int(rec["target"])
        for i in rec["validators"]:
            if i not in marks or target > marks[i][1]:
                marks[i] = (int(rec["source"]), target)
    data = []
    for i, record in enumerate(full["data"]):
        data.append({
            "pubkey": record["pubkey"],
            "signed_blocks": [{"slot": str(blocks[i])}] if i in blocks else [],
            "signed_attestations": [{"source_epoch": str(marks[i][0]), "target_epoch": str(marks[i][1])}] if i in marks else [],
        })
    return {"metadata": full["metadata"], "data": data}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chain", required=True)
    ap.add_argument("--history-head", type=int, required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--seconds-per-slot", type=int, required=True)
    ap.add_argument("--go-file", required=True)
    ap.add_argument("--lead-slots", type=int, default=4)
    ap.add_argument("--vc-lead-seconds", type=int, default=6)
    ap.add_argument("--el-confirm", default="")
    ap.add_argument("nodes", nargs="+")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    manifest = json.load(open(f"{args.chain}/manifest.json"))
    summary = json.load(open(f"{args.chain}/summary.json"))
    genesis = int(summary["genesis"]["genesis_time"])
    sps = args.seconds_per_slot
    roots = {b["slot"]: b["root"] for b in manifest}
    last_slot = manifest[-1]["slot"]
    blocks = [b for b in manifest if b["slot"] > args.history_head]
    el_confirm = set(filter(None, args.el_confirm.split(",")))
    nodes = [insert.Node(spec, el_confirm) for spec in args.nodes]
    for n in nodes:
        n.late = 0.0

    drip = Drip(blocks, genesis, sps)
    threads = [threading.Thread(target=drip_node, args=(n, args.chain, drip), daemon=True) for n in nodes]
    for t in threads:
        t.start()
    print(f"ff-drip: history head {args.history_head}, {len(blocks)} blocks to slot {last_slot} at slot times", flush=True)

    while not os.path.exists(args.go_file):
        time.sleep(0.2)
    go = time.time()
    status = {"status": "failed"}
    if not insert.wait_until(lambda: caught_up(nodes, roots, genesis, sps, last_slot), CAUGHT_UP_TIMEOUT):
        status["error"] = f"nodes not at the dripped head within {CAUGHT_UP_TIMEOUT}s: " + ", ".join(f"{n.name}@{insert.head(n.url)[0]}" for n in nodes)
    else:
        chosen_wall = wall_slot(genesis, sps)
        handover_slot = chosen_wall + args.lead_slots
        if handover_slot > last_slot:
            status["error"] = f"handover slot {handover_slot} is past the generated history (last slot {last_slot})"
        else:
            drip.stop_at(handover_slot)
            json.dump(interchange_for(args.chain, handover_slot), open(f"{args.out}/interchange.json", "w"))
            vc_start_at = int(slot_start(genesis, sps, handover_slot) - args.vc_lead_seconds)
            status = {
                "status": "ok",
                "handover_slot": handover_slot,
                "history_head": args.history_head,
                "go_at": round(go, 3),
                "caught_up_at": round(time.time(), 3),
                "chosen_wall_slot": chosen_wall,
                "genesis_time": genesis,
                "seconds_per_slot": sps,
                "vc_start_at": vc_start_at,
            }
            with open(f"{args.out}/handover.env", "w") as f:
                f.write(f"FF_HANDOVER_SLOT={handover_slot}\nFF_VC_START_AT={vc_start_at}\n")
    json.dump(status, open(f"{args.out}/handover.json", "w"), indent=1)
    with open(f"{args.out}/status", "w") as f:
        f.write(status["status"])
    print(f"ff-handover: {json.dumps(status)}", flush=True)
    if status["status"] != "ok":
        drip.stop_at(-1)

    for t in threads:
        t.join()
    report = {
        n.name: {
            "confirmed_after_slot_start_s": n.confirmed,
            "max_confirm_s": round(n.late, 3),
            "codes": {str(k): v for k, v in n.codes.items()},
            "envelope_codes": {str(k): v for k, v in n.envelope_codes.items()},
            "unconfirmed": n.unconfirmed,
            "unconfirmed_envelopes": n.unconfirmed_envelopes,
        }
        for n in nodes
    }
    json.dump(report, open(f"{args.out}/drip.json", "w"), indent=1)
    for name, r in report.items():
        late = max(r["confirmed_after_slot_start_s"].values(), default=None)
        print(f"ff-drip {name}: {len(r['confirmed_after_slot_start_s'])} blocks, latest confirm {late}s after slot start, codes {r['codes']}, unconfirmed {r['unconfirmed']}", flush=True)
    sys.stdout.flush()
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    main()
