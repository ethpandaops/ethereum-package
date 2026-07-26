import assert from "node:assert/strict";
import test from "node:test";

import { gethArgs, lighthouseArgs, parseOptions, prysmArgs } from "../src/config.js";

test("pairs separate sandboxes over the authenticated public Engine API", () => {
  const geth = gethArgs("hoodi", "/home/user/ethereum/jwt.hex");
  const lighthouse = lighthouseArgs(
    "hoodi",
    "/home/user/ethereum/jwt.hex",
    "https://engine.example",
  );

  assert.ok(geth.includes("--hoodi"));
  assert.ok(geth.includes("--http.addr=127.0.0.1"));
  assert.ok(geth.includes("--authrpc.addr=0.0.0.0"));
  assert.ok(geth.includes("--authrpc.jwtsecret=/home/user/ethereum/jwt.hex"));
  assert.ok(lighthouse.includes("--network=hoodi"));
  assert.ok(lighthouse.includes("--execution-endpoints=https://engine.example"));
  assert.ok(lighthouse.includes("--jwt-secrets=/home/user/ethereum/jwt.hex"));
  const prysm = prysmArgs(
    "hoodi",
    "/home/user/ethereum/jwt.hex",
    "https://engine.example",
  );
  assert.ok(prysm.includes("--hoodi"));
  assert.ok(prysm.includes("--execution-endpoint=https://engine.example"));
  assert.ok(prysm.includes("--jwt-secret=/home/user/ethereum/jwt.hex"));
});

test("only accepts public networks and bounded sandbox lifetimes", () => {
  assert.deepEqual(parseOptions(["--network", "sepolia", "--timeout", "5"]), {
    network: "sepolia",
    timeoutMinutes: 5,
    checkpointUrl: "https://checkpoint-sync.sepolia.ethpandaops.io",
  });
  assert.deepEqual(parseOptions(["--config", "network_params.yaml", "--timeout", "10"]), {
    configPath: "network_params.yaml",
    timeoutMinutes: 10,
  });
  assert.throws(() => parseOptions(["--network", "kurtosis"]), /network/);
  assert.throws(
    () => parseOptions(["--timeout", "4"]),
    /timeout must be an integer from 5 to 1440 minutes/,
  );
  assert.throws(() => parseOptions(["--timeout", "1441"]), /timeout/);
});

test("uses checkpoint sync when configured and insecure genesis sync otherwise", () => {
  assert.ok(
    lighthouseArgs("mainnet", "/jwt", "https://engine.example", "https://checkpoint.example").includes(
      "--checkpoint-sync-url=https://checkpoint.example",
    ),
  );
  const prysm = prysmArgs(
    "sepolia",
    "/jwt",
    "https://engine.example",
    "https://checkpoint.example",
  );
  assert.ok(prysm.includes("--checkpoint-sync-url=https://checkpoint.example"));
  assert.ok(prysm.includes("--genesis-beacon-api-url=https://checkpoint.example"));
  assert.ok(
    lighthouseArgs("mainnet", "/jwt", "https://engine.example").includes(
      "--allow-insecure-genesis-sync",
    ),
  );
  assert.ok(lighthouseArgs("mainnet", "/jwt", "https://engine.example").includes("--ignore-ws-check"));
});
