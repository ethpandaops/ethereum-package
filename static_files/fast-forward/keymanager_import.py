#!/usr/bin/env python3
"""At the handover start time, load each in-process validator's keys through its keymanager API, with their watermark.

usage: keymanager_import.py --handover DIR --token-file FILE name=http://keymanager:port@KEYS_DIR:SECRETS_DIR ...

KEYS_DIR holds <name>.json keystores and SECRETS_DIR the matching <name>.txt passwords. The slashing-protection
interchange from DIR/interchange.json is cut down to the node's own keys and sent in the same request.
"""
import argparse
import json
import os
import time

import insert


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--handover", required=True)
    ap.add_argument("--token-file", required=True)
    ap.add_argument("nodes", nargs="+")
    args = ap.parse_args()

    handover = json.load(open(f"{args.handover}/handover.json"))
    interchange = json.load(open(f"{args.handover}/interchange.json"))
    token = open(args.token_file).read().strip()
    if token.startswith("0x"):
        token = token[2:]
    delay = handover["vc_start_at"] - time.time()
    if delay > 0:
        print(f"ff-keymanager: waiting {delay:.1f}s for the validator start time", flush=True)
        time.sleep(delay)

    failed = []
    for spec in args.nodes:
        name, rest = spec.split("=", 1)
        url, _, dirs = rest.partition("@")
        keys_dir, _, secrets_dir = dirs.partition(":")
        keystores, passwords, pubkeys = [], [], set()
        for fname in sorted(os.listdir(keys_dir)):
            if not fname.endswith(".json"):
                continue
            keystore = open(os.path.join(keys_dir, fname)).read()
            keystores.append(keystore)
            passwords.append(open(os.path.join(secrets_dir, fname[:-5] + ".txt")).read().strip())
            pubkeys.add("0x" + json.loads(keystore)["pubkey"].removeprefix("0x"))
        protection = dict(interchange, data=[r for r in interchange["data"] if r["pubkey"] in pubkeys])
        body = json.dumps({"keystores": keystores, "passwords": passwords, "slashing_protection": json.dumps(protection)}).encode()
        headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"}
        deadline = time.time() + 60
        while True:
            st, raw = insert.http("POST", f"{url}/eth/v1/keystores", body=body, headers=headers, timeout=60)
            if st == 200 or time.time() > deadline:
                break
            time.sleep(1)
        statuses = []
        if st == 200:
            statuses = [d.get("status") for d in json.loads(raw)["data"]]
        ok = st == 200 and all(s in ("imported", "duplicate") for s in statuses)
        print(f"ff-keymanager {name}: HTTP {st}, {len(keystores)} keystores, {len(protection['data'])} watermark records, statuses {sorted(set(statuses))} at {time.time():.3f}", flush=True)
        if not ok:
            print(f"ff-keymanager {name}: {raw[:400]!r}", flush=True)
            failed.append(name)
    if failed:
        raise SystemExit(f"ff-keymanager: import failed for {failed}")


if __name__ == "__main__":
    main()
