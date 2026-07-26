import assert from "node:assert/strict";
import test from "node:test";

import { parseTopology } from "../src/topology.js";

test("expands ethereum-package participant counts into EL-CL sandbox pairs", () => {
  const topology = parseTopology(`
network_params:
  network: hoodi
participants:
  - el_type: geth
    cl_type: prysm
    count: 2
  - el_type: geth
    cl_type: lighthouse
    count: 2
`);

  assert.equal(topology.network, "hoodi");
  assert.equal(topology.pairs.length, 4);
  assert.equal(topology.sandboxCount, 8);
  assert.deepEqual(
    topology.pairs.map(({ elType, clType }) => [elType, clType]),
    [
      ["geth", "prysm"],
      ["geth", "prysm"],
      ["geth", "lighthouse"],
      ["geth", "lighthouse"],
    ],
  );
});

test("matches ethereum-package participants_matrix cartesian expansion", () => {
  const topology = parseTopology(`
network_params:
  network: sepolia
participants_matrix:
  el:
    - el_type: geth
  cl:
    - cl_type: lighthouse
    - cl_type: prysm
  count: 2
`);

  assert.equal(topology.pairs.length, 4);
  assert.deepEqual(
    topology.pairs.map(({ clType }) => clType),
    ["lighthouse", "lighthouse", "prysm", "prysm"],
  );
});

test("preserves ethereum-package count and participant numbering semantics", () => {
  const topology = parseTopology(`
network_params:
  network: hoodi
participants:
  - el_type: geth
    cl_type: lighthouse
    count: 0
  - el_type: geth
    cl_type: prysm
    count: 2
participants_matrix:
  el:
    - el_type: geth
  cl:
    - cl_type: lighthouse
      count: 2
  count: 2
`);

  assert.equal(topology.pairs.length, 6);
  assert.deepEqual(
    topology.pairs.map(({ participantIndex }) => participantIndex),
    [1, 2, 3, 4, 5, 6],
  );
  assert.deepEqual(
    topology.pairs.map(({ id }) => id),
    [
      "participant-1",
      "participant-2",
      "participant-3",
      "participant-4",
      "participant-5",
      "participant-6",
    ],
  );
});

test("parses private devnet and validator settings", () => {
  const topology = parseTopology(`
network_params:
  network: kurtosis
  network_id: "424242"
  preset: minimal
  seconds_per_slot: 6
  genesis_delay: 30
  num_validator_keys_per_node: 32
  genesis_time: 1234567890
  preregistered_validator_count: 64
participants:
  - el_type: geth
    cl_type: lighthouse
    vc_type: prysm
    validator_count: 48
`);

  assert.equal(topology.network, "kurtosis");
  assert.deepEqual(topology.devnet, {
    networkId: "424242",
    preset: "minimal",
    secondsPerSlot: 6,
    genesisDelaySeconds: 30,
    genesisTime: 1234567890,
    preregisteredValidatorCount: 64,
    mnemonic:
      "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete",
  });
  assert.deepEqual(
    topology.pairs.map(({ clType, vcType, validatorCount }) => ({
      clType,
      vcType,
      validatorCount,
    })),
    [{ clType: "lighthouse", vcType: "prysm", validatorCount: 48 }],
  );
});

test("uses ethereum-package null validator defaults", () => {
  const topology = parseTopology(`
network_params:
  network: kurtosis
  num_validator_keys_per_node: 32
participants:
  - el_type: geth
    cl_type: lighthouse
    validator_count: null
`);

  assert.equal(topology.pairs[0]?.validatorCount, 32);
});

test("rejects topology that E2B cannot reproduce safely", () => {
  assert.throws(
    () =>
      parseTopology(`
participants:
  - el_type: geth
    cl_type: lighthouse
`),
    /network_params.*--network/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: kurtosis
  num_validator_keys_per_node: 32
participants:
  - el_type: geth
    cl_type: lighthouse
  - el_type: geth
    cl_type: prysm
`),
    /exactly one EL-CL participant pair/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: hoodi
participants:
  - el_type: nethermind
    cl_type: lighthouse
`),
    /unsupported EL client/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: hoodi
participants:
  - el_type: geth
    cl_type: lighthouse
    cl_image: custom/lighthouse:latest
`),
    /unsupported participant 1 option.*cl_image/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: hoodi
participants:
  - el_type: geth
    cl_type: lighthouse
additional_services:
  - dora
`),
    /additional_services/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: hoodi
participants:
  - el_type: geth
    cl_type: prysm
    count: 1000000000
`),
    /limited to 32 participant pairs/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: hoodi
participants: []
`),
    /zero participants/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: hoodi
participant:
  - el_type: geth
    cl_type: lighthouse
`),
    /unsupported root option.*participant/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: hoodi
participants:
  - el_type: geth
    cl_type: lighthouse
    validator_count: 1
`),
    /validator clients are only supported on private/,
  );
  for (const unsupported of ["mev_params", "persistent"]) {
    assert.throws(
      () =>
        parseTopology(`
network_params:
  network: hoodi
${unsupported}: {}
`),
      new RegExp(`unsupported root option.*${unsupported}`),
    );
  }
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: hoodi
  network_id: "424242"
`),
    /unsupported network_params option.*network_id/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: kurtosis
  terminal_total_difficulty: "0"
`),
    /unsupported network_params option.*terminal_total_difficulty/,
  );
});
