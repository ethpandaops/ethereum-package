#!/usr/bin/env python3
"""Publish an ff-gen chain into every beacon node, in slot order, until each one's head is the generated head.

usage: insert.py --chain DIR --report FILE --seconds-per-slot N [--timeout S] [--el-confirm name,...]
                 name=http://beacon:port[@http://el:port] [...]

A block counts as imported once the node's head slot reaches it or the node serves its root. A 503 means the node is syncing
from a peer that is already ahead, so that node only gets polled from then on. No node runs more than
WINDOW blocks ahead of the slowest one still being published to, so none sees a peer far enough ahead
to fall back to range sync (Prysm then answers 503, Lighthouse stays in head-chain sync).
A manifest entry marked envelope_only (a checkpoint anchor the node already has) gets only its envelope.
A Gloas block's payload envelope (envelopes/<slot>.ssz) is posted right after the block, with empty
blobs under `Eth-Blob-Data-Included: true` and `broadcast_validation=consensus`, and counts as imported
once the node serves it back. Nodes in --el-confirm wait for their EL head to reach the payload
instead, which also keeps their forkchoice updates in order.
"""
import argparse
import json
import struct
import threading
import time
import urllib.error
import urllib.request

CONFIRM_TIMEOUT = 15
RESENDS = 2
POLL = 0.02
MAX_GAP_SLOTS = 32
WINDOW = 16
BARE_BLOCK_FORKS = ("gloas", "heze")


def http(method, url, body=None, headers=None, timeout=30):
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        return -1, repr(e).encode()


def head(url):
    st, body = http("GET", url + "/eth/v1/beacon/headers/head", headers={"Accept": "application/json"}, timeout=10)
    if st != 200:
        return None, None
    doc = json.loads(body)["data"]
    return int(doc["header"]["message"]["slot"]), doc["root"]


def finality(url):
    st, body = http("GET", url + "/eth/v1/beacon/states/head/finality_checkpoints", headers={"Accept": "application/json"}, timeout=10)
    if st != 200:
        return None
    data = json.loads(body)["data"]
    return {"justified": int(data["current_justified"]["epoch"]), "finalized": int(data["finalized"]["epoch"])}


def el_head(url):
    if not url:
        return None
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_getBlockByNumber", "params": ["latest", False]}).encode()
    st, raw = http("POST", url, body=body, headers={"Content-Type": "application/json"}, timeout=10)
    if st != 200:
        return None
    r = json.loads(raw).get("result")
    return {"number": int(r["number"], 16), "hash": r["hash"]} if r else None


def with_empty_blobs(ssz):
    # Container of the object plus empty kzg_proofs and blobs: three offsets, then the object.
    end = 12 + len(ssz)
    return struct.pack("<III", 12, end, end) + ssz


class Pace:
    def __init__(self, nodes):
        self.cond = threading.Condition()
        self.done = {n.name: -1 for n in nodes}

    def wait_turn(self, index):
        with self.cond:
            self.cond.wait_for(lambda: index - min(self.done.values(), default=index) <= WINDOW)

    def confirmed(self, node, index):
        with self.cond:
            self.done[node.name] = index
            self.cond.notify_all()

    def leave(self, node):
        with self.cond:
            self.done.pop(node.name, None)
            self.cond.notify_all()


class Node:
    def __init__(self, spec, el_confirm):
        self.name, rest = spec.split("=", 1)
        self.url, _, self.el = rest.partition("@")
        self.el_confirm = self.name in el_confirm
        self.codes = {}
        self.envelope_codes = {}
        self.posts = 0
        self.envelopes = 0
        self.envelope_s = 0.0
        self.stopped_at = None
        self.unconfirmed = []
        self.unconfirmed_envelopes = []
        self.publish_done = None
        self.anchor_envelope_rejected = False
        self.at_head = None


def wait_until(check, timeout):
    end = time.time() + timeout
    while time.time() < end:
        if check():
            return True
        time.sleep(POLL)
    return False


# A node may import a block without making it head: right after checkpoint sync, the anchor's children
# carry an older justified checkpoint than the anchor and stay out of fork choice's viable heads.
def block_imported(node, slot, root):
    s, _ = head(node.url)
    if s is not None and s >= slot:
        return True
    st, _ = http("GET", f"{node.url}/eth/v1/beacon/blocks/{root}/root", headers={"Accept": "application/json"}, timeout=10)
    return st == 200


def envelope_imported(node, b):
    if node.el_confirm:
        h = el_head(node.el)
        return h is not None and h["hash"] == b["el_block_hash"]
    st, _ = http("GET", f"{node.url}/eth/v1/beacon/execution_payload_envelopes/{b['root']}", headers={"Accept": "application/json"}, timeout=10)
    return st == 200


# Posts until confirmed; returns False when the node should get no more posts.
def post(node, url, body, headers, codes, confirm, slot, resends=RESENDS, timeout=CONFIRM_TIMEOUT):
    for _ in range(resends + 1):
        st, _ = http("POST", url, body=body, headers=headers)
        node.posts += 1
        codes[st] = codes.get(st, 0) + 1
        if st == 503:
            node.stopped_at = slot
            return False
        if wait_until(confirm, timeout):
            return True
    return False


def publish(node, chain, blocks, pace):
    try:
        publish_blocks(node, chain, blocks, pace)
    finally:
        pace.leave(node)
        node.publish_done = time.time()


def publish_blocks(node, chain, blocks, pace):
    block_url = node.url + "/eth/v2/beacon/blocks"
    envelope_url = node.url + "/eth/v1/beacon/execution_payload_envelopes?broadcast_validation=consensus"
    for i, b in enumerate(blocks):
        pace.wait_turn(i)
        slot, version = b["slot"], b["version"]
        if not b.get("envelope_only"):
            with open(f"{chain}/blocks/{slot}.ssz", "rb") as f:
                block = f.read()
            body = block if version in BARE_BLOCK_FORKS else with_empty_blobs(block)
            headers = {"Content-Type": "application/octet-stream", "Eth-Consensus-Version": version}
            if not post(node, block_url, body, headers, node.codes, lambda: block_imported(node, slot, b["root"]), slot):
                if node.stopped_at is None:
                    node.unconfirmed.append(slot)
                return
        if b.get("envelope_ssz_bytes") is None:
            pace.confirmed(node, i)
            continue
        with open(f"{chain}/envelopes/{slot}.ssz", "rb") as f:
            body = with_empty_blobs(f.read())
        headers = {"Content-Type": "application/octet-stream", "Eth-Consensus-Version": version, "Eth-Blob-Data-Included": "true"}
        t = time.time()
        if b.get("envelope_only"):
            # Nodes that checkpoint-synced from the state alone have no anchor block to attach it to.
            if not post(node, envelope_url, body, headers, node.envelope_codes, lambda: envelope_imported(node, b), slot, resends=0, timeout=3):
                node.anchor_envelope_rejected = True
            pace.confirmed(node, i)
            continue
        ok = post(node, envelope_url, body, headers, node.envelope_codes, lambda: envelope_imported(node, b), slot)
        node.envelopes += 1
        node.envelope_s += time.time() - t
        if not ok:
            if node.stopped_at is None:
                node.unconfirmed_envelopes.append(slot)
            return
        pace.confirmed(node, i)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chain", required=True)
    ap.add_argument("--report", required=True)
    ap.add_argument("--timeout", type=float, default=300)
    ap.add_argument("--seconds-per-slot", type=int, required=True)
    ap.add_argument("--el-confirm", default="", help="comma-separated nodes whose envelopes are confirmed by their EL head")
    ap.add_argument("nodes", nargs="+")
    args = ap.parse_args()

    blocks = json.load(open(f"{args.chain}/manifest.json"))
    summary = json.load(open(f"{args.chain}/summary.json"))
    target = summary["head_root"]
    el_target = summary.get("el_head", {}).get("hash")
    el_confirm = set(filter(None, args.el_confirm.split(",")))
    nodes = [Node(spec, el_confirm) for spec in args.nodes]

    pace = Pace(nodes)
    started = time.time()
    threads = [threading.Thread(target=publish, args=(n, args.chain, blocks, pace), daemon=True) for n in nodes]
    for t in threads:
        t.start()

    deadline = started + args.timeout
    while time.time() < deadline:
        for n in nodes:
            if n.at_head is None and n.publish_done is not None and head(n.url)[1] == target:
                n.at_head = time.time()
        if all(n.at_head is not None for n in nodes):
            break
        time.sleep(0.1)

    report = {"started": started, "blocks": len(blocks), "head_slot": summary["head_slot"], "head_root": target, "el_head": el_target, "nodes": {}}
    for n in nodes:
        slot, root = head(n.url)
        el = el_head(n.el)
        report["nodes"][n.name] = {
            "at_head_s": None if n.at_head is None else round(n.at_head - started, 2),
            "publish_s": None if n.publish_done is None else round(n.publish_done - started, 2),
            "posts": n.posts,
            "codes": {str(k): v for k, v in n.codes.items()},
            "envelope_codes": {str(k): v for k, v in n.envelope_codes.items()},
            "envelopes": n.envelopes,
            "envelope_mean_s": round(n.envelope_s / n.envelopes, 3) if n.envelopes else None,
            "envelope_confirm": "el_head" if n.el_confirm else "get_envelope",
            "stopped_at_503": n.stopped_at,
            "unconfirmed": n.unconfirmed,
            "unconfirmed_envelopes": n.unconfirmed_envelopes,
            "anchor_envelope_rejected": n.anchor_envelope_rejected,
            "head_slot": slot,
            "head_root": root,
            "finality": finality(n.url),
            "el_head": el,
            "el_at_head": None if el is None or el_target is None else el["hash"] == el_target,
        }
        print(f"ff-insert {n.name}: {json.dumps(report['nodes'][n.name])}", flush=True)
    report["finished"] = time.time()
    genesis = int(summary["genesis"]["genesis_time"])
    report["gap_slots"] = int((report["finished"] - genesis) // args.seconds_per_slot) - summary["head_slot"]
    with open(args.report, "w") as f:
        json.dump(report, f, indent=1)
    if report["gap_slots"] >= MAX_GAP_SLOTS:
        raise SystemExit(f"ff-insert: handover gap is {report['gap_slots']} slots, at or over {MAX_GAP_SLOTS}; validators would start too far behind the head")
    missing = [n.name for n in nodes if n.at_head is None]
    if missing:
        raise SystemExit(f"ff-insert: {missing} did not reach head {target} within {args.timeout}s")
    print(f"ff-insert: all {len(nodes)} nodes at slot {summary['head_slot']} {target} after {report['finished'] - started:.1f}s, gap {report['gap_slots']} slots", flush=True)


if __name__ == "__main__":
    main()
