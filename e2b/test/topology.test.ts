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

test("rejects topology that E2B cannot reproduce safely", () => {
  assert.throws(
    () =>
      parseTopology(`
participants:
  - el_type: geth
    cl_type: lighthouse
`),
    /public network.*--network/,
  );
  assert.throws(
    () =>
      parseTopology(`
network_params:
  network: kurtosis
participants:
  - el_type: geth
    cl_type: lighthouse
`),
    /custom Kurtosis networks/,
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
});
