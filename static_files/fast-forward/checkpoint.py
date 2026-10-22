#!/usr/bin/env python3
"""The checkpoint path for fast_forward: beacon nodes start from the generated chain's last finalized
checkpoint instead of importing the whole history.

  feed   Replays ff-gen's engine_newPayload requests (payloads/<slot>.json) into every EL, following the
         generator: while it runs, each EL is fed up to the finalized checkpoint in progress.json; once
         summary.json appears, up to the anchor (the final finalized checkpoint) and never past it, since
         geth refuses forkchoice updates that rewind its head by more than 32 blocks. A head-only
         forkchoice update goes out every 32 payloads (geth stops taking payloads far above its head)
         and one more at the anchor.
  tail   Copies the anchor (block, post-state, envelope) plus the blocks and envelopes after it, with a
         manifest of only those, so insert.py publishes just the tail.
  serve  A minimal beacon API serving the anchor as the finalized checkpoint, and the genesis state
         (Prysm's --genesis-beacon-api-url), for each beacon node's checkpoint sync.

usage: checkpoint.py feed --chain DIR --jwt FILE --slots-per-epoch N --report FILE name=http://el:8551 [...]
       checkpoint.py tail --chain DIR --out DIR
       checkpoint.py serve --dir TAIL_DIR --network-config DIR --port P
"""
import argparse
import base64
import hashlib
import hmac
import http.client
import json
import os
import re
import shutil
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

FCU_EVERY = 32
POLL = 0.5
ZERO_HASH = "0x" + "00" * 32
RETRIES = 5


def jwt_token(secret):
    def b64(b):
        return base64.urlsafe_b64encode(b).rstrip(b"=")

    header = b64(b'{"alg":"HS256","typ":"JWT"}')
    claims = b64(json.dumps({"iat": int(time.time())}).encode())
    sig = b64(hmac.new(secret, header + b"." + claims, hashlib.sha256).digest())
    return (header + b"." + claims + b"." + sig).decode()


class Engine:
    def __init__(self, name, url, secret):
        self.name, self.url, self.secret = name, url, secret
        parsed = urllib.parse.urlparse(url)
        self.host, self.port = parsed.hostname, parsed.port or 8551
        self.conn = None
        self.token, self.token_at = None, 0

    def call(self, method, params):
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
        last = None
        for attempt in range(RETRIES):
            if time.time() - self.token_at > 20:
                self.token, self.token_at = jwt_token(self.secret), time.time()
            try:
                if self.conn is None:
                    self.conn = http.client.HTTPConnection(self.host, self.port, timeout=120)
                self.conn.request("POST", "/", body, {"Content-Type": "application/json", "Authorization": "Bearer " + self.token})
                resp = self.conn.getresponse()
                raw = resp.read()
                if resp.status != 200:
                    raise RuntimeError(f"HTTP {resp.status}: {raw[:200]!r}")
                doc = json.loads(raw)
                if "error" in doc:
                    raise RuntimeError(f"{method}: {doc['error']}")
                return doc["result"]
            except (OSError, http.client.HTTPException, RuntimeError, ValueError) as e:
                last = e
                self.conn = None
                time.sleep(0.5 * (attempt + 1))
        raise RuntimeError(f"{self.name}: {method} failed after {RETRIES} attempts: {last}")


def load_payload(chain, slot):
    with open(f"{chain}/payloads/{slot}.json") as f:
        req = json.load(f)
    fcu = "engine_forkchoiceUpdatedV4" if req["method"] == "engine_newPayloadV5" else "engine_forkchoiceUpdatedV3"
    return req["method"], req["params"], req["params"][0]["blockHash"], fcu


class Feed:
    """Shared target: feeders go up to `limit`; `final` is set once the anchor is known."""

    def __init__(self):
        self.cond = threading.Condition()
        self.limit = 0
        self.final = None
        self.failed = None

    def wait_for_work(self, next_slot):
        with self.cond:
            self.cond.wait_for(lambda: self.failed or self.limit >= next_slot or (self.final is not None and next_slot > self.final), timeout=5)
            return self.limit, self.final

    def advance(self, limit, final=None):
        with self.cond:
            self.limit = max(self.limit, limit)
            if final is not None:
                self.final = final
            self.cond.notify_all()


def feed_el(engine, chain, feed, stats):
    next_slot, last_hash, last_fcu = 1, None, None
    started = time.time()
    statuses = {}
    try:
        while True:
            limit, final = feed.wait_for_work(next_slot)
            if feed.failed:
                return
            if final is not None and next_slot > final:
                break
            while next_slot <= limit:
                method, params, block_hash, fcu = load_payload(chain, next_slot)
                status = engine.call(method, params)["status"]
                statuses[status] = statuses.get(status, 0) + 1
                if status != "VALID":
                    raise RuntimeError(f"{engine.name}: {method} for slot {next_slot} returned {status}")
                last_hash, last_fcu = block_hash, fcu
                if next_slot % FCU_EVERY == 0:
                    engine.call(fcu, [{"headBlockHash": last_hash, "safeBlockHash": ZERO_HASH, "finalizedBlockHash": ZERO_HASH}, None])
                if feed.final is not None and stats.get("fed_at_gen_end") is None:
                    stats["fed_at_gen_end"] = next_slot - 1
                    stats["gen_end_at_s"] = round(time.time() - started, 2)
                next_slot += 1
                stats["fed"] = next_slot - 1
        if last_hash is None:
            raise RuntimeError(f"{engine.name}: nothing to feed")
        result = engine.call(last_fcu, [{"headBlockHash": last_hash, "safeBlockHash": ZERO_HASH, "finalizedBlockHash": ZERO_HASH}, None])
        head_status = result["payloadStatus"]["status"]
        if head_status != "VALID":
            raise RuntimeError(f"{engine.name}: forkchoice update to the anchor payload {last_hash} returned {head_status}")
        stats.update(payloads=next_slot - 1, head=last_hash, head_status=head_status, statuses=statuses)
    except Exception as e:
        stats["error"] = str(e)
        with feed.cond:
            feed.failed = str(e)
            feed.cond.notify_all()
    finally:
        stats["seconds"] = round(time.time() - started, 2)
        stats.setdefault("fed_at_gen_end", next_slot - 1)


def prune(chain, done, keep_from):
    for slot in range(done + 1, keep_from):
        for path in (f"{chain}/payloads/{slot}.json", f"{chain}/blocks/{slot}.ssz", f"{chain}/envelopes/{slot}.ssz"):
            try:
                os.remove(path)
            except FileNotFoundError:
                pass
    return max(done, keep_from - 1)


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return None


def cmd_feed(args):
    secret_hex = open(args.jwt).read().strip()
    secret = bytes.fromhex(secret_hex[2:] if secret_hex.startswith("0x") else secret_hex)
    engines = []
    for spec in args.els:
        name, url = spec.split("=", 1)
        engines.append(Engine(name, url, secret))
    feed = Feed()
    stats = {e.name: {"el": e.url} for e in engines}
    threads = [threading.Thread(target=feed_el, args=(e, args.chain, feed, stats[e.name]), daemon=True) for e in engines]
    for t in threads:
        t.start()

    started = time.time()
    pruned = 0
    while not feed.failed:
        # Every EL has these payloads and the anchor lies at or after the finalized slot, so the
        # files before both are never read again; dropping them keeps disk use flat over long runs.
        keep_from = min([s.get("fed", 0) for s in stats.values()] + [feed.limit])
        if args.prune:
            pruned = prune(args.chain, pruned, keep_from)
        summary = read_json(f"{args.chain}/summary.json")
        if summary is not None:
            anchor = summary.get("anchor")
            if not anchor:
                feed.failed = "ff-gen wrote no anchor (no finalized checkpoint after genesis)"
                break
            feed.advance(anchor["slot"], final=anchor["slot"])
            break
        progress = read_json(f"{args.chain}/progress.json")
        if progress is not None and progress["finalized_epoch"] > 0:
            feed.advance(progress["finalized_epoch"] * args.slots_per_epoch)
        time.sleep(POLL)
    gen_done = time.time()
    for t in threads:
        t.join()

    report = {"seconds": round(time.time() - started, 2), "after_generation_s": round(time.time() - gen_done, 2), "anchor_slot": feed.final, "els": stats}
    with open(args.report, "w") as f:
        json.dump(report, f, indent=1)
    for name, s in stats.items():
        print(f"ff-feed {name}: {json.dumps(s)}", flush=True)
    if feed.failed:
        sys.exit(f"ff-feed: {feed.failed}")
    print(f"ff-feed: every EL is at the anchor payload (slot {feed.final}); {report['after_generation_s']}s after generation ended", flush=True)


def cmd_tail(args):
    summary = read_json(f"{args.chain}/summary.json")
    anchor = summary.get("anchor") if summary else None
    if not anchor:
        sys.exit("ff-tail: summary.json has no anchor")
    manifest = read_json(f"{args.chain}/manifest.json")
    tail = [b for b in manifest if b["slot"] > anchor["slot"]]
    os.makedirs(f"{args.out}/blocks", exist_ok=True)
    os.makedirs(f"{args.out}/envelopes", exist_ok=True)
    shutil.copytree(f"{args.chain}/anchor", f"{args.out}/anchor", dirs_exist_ok=True)
    # Checkpoint sync gives nodes the anchor block but not its payload envelope, so children
    # building on the anchor's payload would have an unknown parent until it is posted.
    anchor_entry = next(b for b in manifest if b["slot"] == anchor["slot"])
    if anchor_entry.get("envelope_ssz_bytes") is not None:
        shutil.copy(f"{args.chain}/envelopes/{anchor['slot']}.ssz", f"{args.out}/envelopes/")
        tail.insert(0, {**anchor_entry, "envelope_only": True})
    for b in tail:
        shutil.copy(f"{args.chain}/blocks/{b['slot']}.ssz", f"{args.out}/blocks/")
        if b.get("envelope_ssz_bytes") is not None:
            shutil.copy(f"{args.chain}/envelopes/{b['slot']}.ssz", f"{args.out}/envelopes/")
    with open(f"{args.out}/manifest.json", "w") as f:
        json.dump(tail, f)
    shutil.copy(f"{args.chain}/summary.json", args.out)
    print(f"ff-tail: anchor slot {anchor['slot']} {anchor['block_root']}, {len(tail)} blocks after it", flush=True)


# Fork names in activation order, as config.yaml schedules them.
FORKS = ("phase0", "altair", "bellatrix", "capella", "deneb", "electra", "fulu", "gloas", "heze")


def read_config(path):
    config = {}
    with open(path) as f:
        for line in f:
            line = line.split("#", 1)[0].rstrip()
            if ":" not in line or line.startswith((" ", "-")):
                continue
            key, value = line.split(":", 1)
            value = value.strip().strip("'\"")
            if value:
                config[key.strip()] = value
    return config


def fork_schedule(config):
    schedule, previous = [], config.get("GENESIS_FORK_VERSION")
    for fork in FORKS[1:]:
        epoch = config.get(f"{fork.upper()}_FORK_EPOCH")
        version = config.get(f"{fork.upper()}_FORK_VERSION")
        if epoch is None or version is None or int(epoch) >= 2**64 - 1:
            continue
        schedule.append({"previous_version": previous, "current_version": version, "epoch": epoch})
        previous = version
    return schedule


def genesis_fork(config):
    name = "phase0"
    for fork in FORKS[1:]:
        if config.get(f"{fork.upper()}_FORK_EPOCH") == "0":
            name = fork
    return name


class Store:
    def __init__(self, tail_dir, network_config):
        def rb(path):
            try:
                with open(path, "rb") as f:
                    return f.read()
            except FileNotFoundError:
                return None

        self.anchor = read_json(f"{tail_dir}/anchor/anchor.json")
        self.summary = read_json(f"{tail_dir}/summary.json")
        self.state = rb(f"{tail_dir}/anchor/state.ssz")
        self.block = rb(f"{tail_dir}/anchor/block.ssz")
        self.block_json = read_json(f"{tail_dir}/anchor/block.json")
        self.envelope = rb(f"{tail_dir}/anchor/envelope.ssz")
        self.envelope_json = read_json(f"{tail_dir}/anchor/envelope.json")
        self.genesis_state = rb(f"{network_config}/genesis.ssz")
        self.config = read_config(f"{network_config}/config.yaml")
        self.genesis_fork = genesis_fork(self.config)
        a = self.anchor
        self.anchor_ids = {"finalized", "head", "justified", str(a["slot"]), a["block_root"], a["state_root"]}
        self.genesis_ids = {"genesis", "0", self.summary["genesis_block_root"]}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    store = None

    def log_message(self, *a):
        pass

    def send(self, code, body, ctype="application/json", version=None):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        if version:
            self.send_header("Eth-Consensus-Version", version)
        self.end_headers()
        self.wfile.write(body)
        print(f"{time.strftime('%H:%M:%S')} {code} {self.command} {self.path} ua={self.headers.get('User-Agent', '')[:40]} bytes={len(body)}", flush=True)

    def wants_ssz(self):
        accept = self.headers.get("Accept", "")
        return "octet-stream" in accept and not accept.startswith("application/json")

    def object(self, ssz, doc, version):
        if self.wants_ssz() or doc is None:
            return self.send(200, ssz, "application/octet-stream", version)
        return self.send(200, {"version": version, "execution_optimistic": False, "finalized": True, "data": doc["data"]}, version=version)

    def do_GET(self):
        s, a = self.store, self.store.anchor
        path = self.path.split("?")[0].rstrip("/")
        meta = {"execution_optimistic": False, "finalized": True}

        m = re.match(r"^/eth/v[12]/debug/beacon/states/([^/]+)$", path)
        if m:
            if m.group(1) in s.anchor_ids:
                return self.send(200, s.state, "application/octet-stream", a["version"])
            if m.group(1) in s.genesis_ids and s.genesis_state:
                return self.send(200, s.genesis_state, "application/octet-stream", s.genesis_fork)
            return self.send(404, {"code": 404, "message": "state not found"})
        m = re.match(r"^/eth/v[12]/beacon/blocks/([^/]+)$", path)
        if m:
            if m.group(1) in s.anchor_ids:
                return self.object(s.block, s.block_json, a["version"])
            return self.send(404, {"code": 404, "message": "block not found"})
        m = re.match(r"^/eth/v\d/beacon/execution_payload_envelopes?/([^/]+)$", path)
        if m:
            if m.group(1) in s.anchor_ids and s.envelope:
                return self.object(s.envelope, s.envelope_json, a["version"])
            return self.send(404, {"code": 404, "message": "envelope not found"})
        m = re.match(r"^/eth/v1/beacon/blocks/([^/]+)/root$", path)
        if m:
            if m.group(1) in s.anchor_ids:
                return self.send(200, {**meta, "data": {"root": a["block_root"]}})
            if m.group(1) in s.genesis_ids:
                return self.send(200, {**meta, "data": {"root": s.summary["genesis_block_root"]}})
            return self.send(404, {"code": 404, "message": "block not found"})
        m = re.match(r"^/eth/v1/beacon/headers/([^/]+)$", path)
        if m:
            if m.group(1) in s.anchor_ids:
                header = {k: str(a[k]) for k in ("slot", "proposer_index")}
                header.update(parent_root=a["parent_root"], state_root=a["state_root"], body_root=a["body_root"])
                signature = s.block_json["data"]["signature"] if s.block_json else None
                return self.send(200, {**meta, "data": {"root": a["block_root"], "canonical": True, "header": {"message": header, "signature": signature}}})
            return self.send(404, {"code": 404, "message": "header not found"})
        m = re.match(r"^/eth/v1/beacon/states/([^/]+)/finality_checkpoints$", path)
        if m:
            cp = {"epoch": str(a["epoch"]), "root": a["block_root"]}
            return self.send(200, {**meta, "data": {"previous_justified": cp, "current_justified": cp, "finalized": cp}})
        m = re.match(r"^/eth/v1/beacon/states/([^/]+)/root$", path)
        if m and m.group(1) in s.anchor_ids:
            return self.send(200, {**meta, "data": {"root": a["state_root"]}})
        if re.match(r"^/eth/v1/beacon/(blob_sidecars|blobs)/", path) or re.match(r"^/eth/v1/debug/beacon/data_column_sidecars/", path):
            return self.send(200, {**meta, "data": []}, version=a["version"])
        static = {
            "/eth/v1/beacon/genesis": {
                "genesis_time": str(s.summary["genesis"]["genesis_time"]),
                "genesis_validators_root": s.summary["genesis"]["genesis_validators_root"],
                "genesis_fork_version": a["genesis_fork_version"],
            },
            "/eth/v1/config/spec": s.config,
            "/eth/v1/config/fork_schedule": fork_schedule(s.config),
            "/eth/v1/config/deposit_contract": {
                "chain_id": s.config.get("DEPOSIT_CHAIN_ID", "0"),
                "address": s.config.get("DEPOSIT_CONTRACT_ADDRESS", "0x" + "00" * 20),
            },
            "/eth/v1/node/version": {"version": "ff-checkpoint/1"},
            "/eth/v1/node/syncing": {"head_slot": str(a["slot"]), "sync_distance": "0", "is_syncing": False, "is_optimistic": False, "el_offline": False},
        }
        if path in static:
            return self.send(200, {"data": static[path]})
        if path == "/eth/v1/node/health":
            return self.send(200, b"", "text/plain")
        return self.send(404, {"code": 404, "message": f"not served: {path}"})


def cmd_serve(args):
    Handler.store = Store(args.dir, args.network_config)
    a = Handler.store.anchor
    server = ThreadingHTTPServer(("0.0.0.0", args.port), Handler)
    print(f"ff-checkpoint: serving anchor slot {a['slot']} epoch {a['epoch']} {a['block_root']} ({a['version']}) on :{args.port}", flush=True)
    server.serve_forever()


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="command", required=True)
    p = sub.add_parser("feed")
    p.add_argument("--chain", required=True)
    p.add_argument("--jwt", required=True)
    p.add_argument("--slots-per-epoch", type=int, required=True)
    p.add_argument("--report", required=True)
    p.add_argument("--prune", action="store_true", help="delete payload, block and envelope files once every EL is past them")
    p.add_argument("els", nargs="+")
    p = sub.add_parser("tail")
    p.add_argument("--chain", required=True)
    p.add_argument("--out", required=True)
    p = sub.add_parser("serve")
    p.add_argument("--dir", required=True)
    p.add_argument("--network-config", required=True)
    p.add_argument("--port", type=int, required=True)
    args = ap.parse_args()
    {"feed": cmd_feed, "tail": cmd_tail, "serve": cmd_serve}[args.command](args)


if __name__ == "__main__":
    main()
