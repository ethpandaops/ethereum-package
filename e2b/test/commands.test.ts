import assert from "node:assert/strict";
import test from "node:test";

import { type Sandbox } from "e2b";

import {
  gethArgs,
  lighthouseArgs,
  parseOptions,
  prysmArgs,
  resolveCheckpointUrl,
} from "../src/config.js";
import {
  generateDevnetArtifacts,
  gethDevnetArgs,
  lighthouseDevnetArgs,
  prysmDevnetArgs,
  plannedGenesisTimestamp,
  validatorArgs,
} from "../src/devnet.js";

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

test("accepts public and private networks with bounded sandbox lifetimes", () => {
  assert.deepEqual(parseOptions(["--network", "sepolia", "--timeout", "5"]), {
    network: "sepolia",
    timeoutMinutes: 5,
    checkpointUrl: "https://checkpoint-sync.sepolia.ethpandaops.io",
  });
  assert.deepEqual(parseOptions(["--config", "network_params.yaml", "--timeout", "10"]), {
    configPath: "network_params.yaml",
    timeoutMinutes: 10,
  });
  assert.deepEqual(parseOptions(["--network", "kurtosis"]), {
    network: "kurtosis",
    timeoutMinutes: 60,
  });
  assert.throws(
    () => parseOptions(["--timeout", "4"]),
    /timeout must be an integer from 5 to 1440 minutes/,
  );
  assert.throws(() => parseOptions(["--timeout", "1441"]), /timeout/);
});
test("rejects plaintext checkpoint URLs", () => {
  assert.throws(
    () => parseOptions(["--checkpoint-url", "http://checkpoint.example"]),
    /checkpoint URL must use HTTPS/,
  );
});

test("rejects checkpoint sync after a config resolves to a private network", () => {
  assert.throws(
    () => resolveCheckpointUrl("kurtosis", "https://checkpoint.example"),
    /checkpoint URL is only valid for public networks/,
  );
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

test("honors an explicit private genesis timestamp", () => {
  assert.equal(
    plannedGenesisTimestamp({
      network: "kurtosis",
      pairs: [],
      sandboxCount: 0,
      devnet: {
        networkId: "424242",
        preset: "mainnet",
        secondsPerSlot: 12,
        genesisDelaySeconds: 20,
        genesisTime: 1234567890,
        preregisteredValidatorCount: 64,
        mnemonic: "test mnemonic",
      },
    }),
    1234567890,
  );
});

test("uses the preregistered validator count in generated genesis", async () => {
  let valuesEnvironment = "";
  const sandbox = {
    files: {
      write: async (path: string, value: unknown) => {
        if (path === "/config/values.env") {
          valuesEnvironment = String(value);
        }
      },
      read: async () => new Uint8Array(),
    },
    commands: {
      run: async () => ({}),
    },
  } as unknown as Sandbox;
  await generateDevnetArtifacts(
    sandbox,
    {
      network: "kurtosis",
      sandboxCount: 2,
      pairs: [
        {
          id: "participant-1",
          participantIndex: 1,
          instance: 1,
          elType: "geth",
          clType: "lighthouse",
          vcType: "lighthouse",
          validatorCount: 32,
        },
      ],
      devnet: {
        networkId: "424242",
        preset: "mainnet",
        secondsPerSlot: 12,
        genesisDelaySeconds: 20,
        preregisteredValidatorCount: 64,
        mnemonic: "test mnemonic",
      },
    },
    1234567890,
  );

  assert.match(valuesEnvironment, /export NUMBER_OF_VALIDATORS=64\n/);
});

test("configures native private clients over the E2B HTTPS Engine bridge", () => {
  const config = {
    networkId: "424242",
    preset: "mainnet" as const,
    secondsPerSlot: 12,
    genesisDelaySeconds: 20,
    mnemonic: "test mnemonic",
  };
  const geth = gethDevnetArgs(config, "/jwt");
  assert.ok(geth.includes("--networkid=424242"));
  assert.ok(geth.includes("--http.addr=127.0.0.1"));
  assert.ok(geth.includes("--nodiscover"));
  assert.ok(geth.includes("--authrpc.addr=0.0.0.0"));

  const lighthouse = lighthouseDevnetArgs("/jwt", "https://engine.example");
  assert.ok(lighthouse.includes("--testnet-dir=/home/user/devnet/metadata"));
  assert.ok(lighthouse.includes("--execution-endpoints=https://engine.example"));
  assert.ok(lighthouse.includes("--disable-discovery"));

  const prysm = prysmDevnetArgs(config, "/jwt", "https://engine.example");
  assert.ok(prysm.includes("--chain-config-file=/home/user/devnet/metadata/config.yaml"));
  assert.ok(prysm.includes("--p2p-host-ip=127.0.0.1"));
  assert.ok(prysm.includes("--execution-endpoint=https://engine.example"));

  const validator = validatorArgs(
    {
      id: "participant-1",
      participantIndex: 1,
      instance: 1,
      elType: "geth",
      clType: "lighthouse",
      vcType: "lighthouse",
      validatorCount: 128,
    },
    "http://127.0.0.1:4000",
  );
  assert.ok(
    validator.includes("--validators-dir=/home/user/devnet/keystores/participant-1/keys"),
  );
  assert.ok(validator.includes("--beacon-nodes=http://127.0.0.1:4000"));
});
