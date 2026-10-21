#!/usr/bin/env python3
"""Publish an ff-gen chain into every beacon node, in slot order, until each one's head is the generated head.

usage: insert.py --chain DIR --report FILE [--timeout S] name=http://beacon:port [...]

A block counts as imported once the node's head slot reaches it. A 503 means the node is syncing
from a peer that is already ahead, so that node only gets polled from then on.
A block's payload envelope (envelopes/<slot>.ssz, Gloas onwards) is posted right after the block.
"""
import argparse
import json
import os
import struct
import threading
import time
import urllib.error
import urllib.request

CONFIRM_TIMEOUT = 15
RESENDS = 2
POLL = 0.02


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


def block_contents(block_ssz):
    # SignedBlockContents with empty kzg_proofs and blobs: three offsets, then the block.
    end = 12 + len(block_ssz)
    return struct.pack("<III", 12, end, end) + block_ssz


class Node:
    def __init__(self, name, url):
        self.name, self.url = name, url
        self.codes = {}
        self.posts = 0
        self.stopped_at = None
        self.unconfirmed = []
        self.publish_done = None
        self.at_head = None


def wait_slot(node, slot, timeout):
    end = time.time() + timeout
    while time.time() < end:
        s, _ = head(node.url)
        if s is not None and s >= slot:
            return True
        time.sleep(POLL)
    return False


def publish(node, chain, blocks):
    for b in blocks:
        slot = b["slot"]
        with open(f"{chain}/blocks/{slot}.ssz", "rb") as f:
            body = block_contents(f.read())
        headers = {"Content-Type": "application/octet-stream", "Eth-Consensus-Version": b["version"]}
        for _ in range(RESENDS + 1):
            st, _ = http("POST", node.url + "/eth/v2/beacon/blocks", body=body, headers=headers)
            node.posts += 1
            node.codes[st] = node.codes.get(st, 0) + 1
            if st == 503:
                node.stopped_at = slot
                node.publish_done = time.time()
                return
            if wait_slot(node, slot, CONFIRM_TIMEOUT):
                break
        else:
            node.unconfirmed.append(slot)
        envelope = f"{chain}/envelopes/{slot}.ssz"
        if os.path.exists(envelope):
            with open(envelope, "rb") as f:
                st, _ = http(
                    "POST",
                    node.url + "/eth/v1/beacon/execution_payload_envelopes",
                    body=f.read(),
                    headers={
                        "Content-Type": "application/octet-stream",
                        "Eth-Consensus-Version": b["version"],
                        "Eth-Blob-Data-Included": "false",
                    },
                )
            node.posts += 1
            node.codes[st] = node.codes.get(st, 0) + 1
            if st == 503:
                node.stopped_at = slot
                node.publish_done = time.time()
                return
    node.publish_done = time.time()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chain", required=True)
    ap.add_argument("--report", required=True)
    ap.add_argument("--timeout", type=float, default=300)
    ap.add_argument("nodes", nargs="+")
    args = ap.parse_args()

    blocks = json.load(open(f"{args.chain}/manifest.json"))
    summary = json.load(open(f"{args.chain}/summary.json"))
    target = summary["head_root"]
    nodes = [Node(*spec.split("=", 1)) for spec in args.nodes]

    started = time.time()
    threads = [threading.Thread(target=publish, args=(n, args.chain, blocks), daemon=True) for n in nodes]
    for t in threads:
        t.start()

    deadline = started + args.timeout
    while time.time() < deadline:
        for n in nodes:
            if n.at_head is None and head(n.url)[1] == target:
                n.at_head = time.time()
        if all(n.at_head is not None for n in nodes):
            break
        time.sleep(0.1)

    report = {"started": started, "blocks": len(blocks), "head_slot": summary["head_slot"], "head_root": target, "nodes": {}}
    for n in nodes:
        slot, root = head(n.url)
        report["nodes"][n.name] = {
            "at_head_s": None if n.at_head is None else round(n.at_head - started, 2),
            "publish_s": None if n.publish_done is None else round(n.publish_done - started, 2),
            "posts": n.posts,
            "codes": {str(k): v for k, v in n.codes.items()},
            "stopped_at_503": n.stopped_at,
            "unconfirmed": n.unconfirmed,
            "head_slot": slot,
            "head_root": root,
            "finality": finality(n.url),
        }
        print(f"ff-insert {n.name}: {json.dumps(report['nodes'][n.name])}", flush=True)
    report["finished"] = time.time()
    with open(args.report, "w") as f:
        json.dump(report, f, indent=1)
    missing = [n.name for n in nodes if n.at_head is None]
    if missing:
        raise SystemExit(f"ff-insert: {missing} did not reach head {target} within {args.timeout}s")
    print(f"ff-insert: all {len(nodes)} nodes at slot {summary['head_slot']} {target} after {report['finished'] - started:.1f}s", flush=True)


if __name__ == "__main__":
    main()
