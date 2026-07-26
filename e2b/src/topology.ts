import { parse } from "yaml";

import { networks, type Network } from "./config.js";

export type ExecutionClient = "geth";
export type ConsensusClient = "lighthouse" | "prysm";

export interface NodePair {
  id: string;
  participantIndex: number;
  instance: number;
  elType: ExecutionClient;
  clType: ConsensusClient;
}

export interface Topology {
  network: Network;
  pairs: NodePair[];
  sandboxCount: number;
}

interface ParticipantInput {
  el_type?: unknown;
  cl_type?: unknown;
  count?: unknown;
  [key: string]: unknown;
}

interface MatrixInput {
  el?: unknown;
  cl?: unknown;
  count?: unknown;
  [key: string]: unknown;
}

interface ConfigInput {
  participants?: unknown;
  participants_matrix?: unknown;
  network_params?: unknown;
  additional_services?: unknown;
}

const participantKeys: Record<string, true> = {
  el_type: true,
  cl_type: true,
  count: true,
};
const matrixKeys: Record<string, true> = { el: true, cl: true, count: true };
const elMatrixKeys: Record<string, true> = { el_type: true };
const clMatrixKeys: Record<string, true> = { cl_type: true, count: true };
const rootKeys: Record<string, true> = {
  participants: true,
  participants_matrix: true,
  network_params: true,
  port_publisher: true,
  additional_services: true,
  extra_files: true,
  blockscout_params: true,
  dora_params: true,
  checkpointz_params: true,
  docker_cache_params: true,
  tx_fuzz_params: true,
  rakoon_params: true,
  custom_flood_params: true,
  prometheus_params: true,
  grafana_params: true,
  tempo_params: true,
  assertoor_params: true,
  mev_params: true,
  xatu_sentry_params: true,
  snooper_params: true,
  spamoor_params: true,
  disruptoor_params: true,
  slashoor_params: true,
  mempool_bridge_params: true,
  ethereum_genesis_generator_params: true,
  bootnodoor_params: true,
  zkboost_params: true,
  buildoor_params: true,
  trueblocks_params: true,
  wait_for_finalization: true,
  global_log_level: true,
  snooper_enabled: true,
  ethereum_metrics_exporter_enabled: true,
  parallel_keystore_generation: true,
  disable_peer_scoring: true,
  persistent: true,
  mev_type: true,
  xatu_sentry_enabled: true,
  apache_port: true,
  nginx_port: true,
  global_tolerations: true,
  global_node_selectors: true,
  use_remote_signer: true,
  keymanager_enabled: true,
  checkpoint_sync_enabled: true,
  checkpoint_sync_url: true,
};
const maxPairs = 32;

function asRecord(value: unknown, label: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error(`${label} must be a mapping`);
  }
  return value as Record<string, unknown>;
}

function asArray(value: unknown, label: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be a list`);
  }
  return value;
}

function countOf(value: unknown, label: string): number {
  const count = value ?? 1;
  if (!Number.isInteger(count) || (count as number) < 0) {
    throw new Error(`${label} must be a non-negative integer`);
  }
  return count as number;
}

function rejectUnknownKeys(
  value: Record<string, unknown>,
  allowed: Readonly<Record<string, true>>,
  label: string,
): void {
  const unsupported = Object.keys(value).find((key) => !allowed[key]);
  if (unsupported) {
    throw new Error(`unsupported ${label} option: ${unsupported}`);
  }
}

function parseParticipant(
  input: ParticipantInput,
  participantIndex: number,
  instance: number,
): NodePair {
  rejectUnknownKeys(input, participantKeys, `participant ${participantIndex}`);
  const elType = input.el_type ?? "geth";
  const clType = input.cl_type ?? "lighthouse";
  if (elType !== "geth") {
    throw new Error(`unsupported EL client in participant ${participantIndex}: ${String(elType)}`);
  }
  if (clType !== "lighthouse" && clType !== "prysm") {
    throw new Error(`unsupported CL client in participant ${participantIndex}: ${String(clType)}`);
  }
  return {
    id: `participant-${participantIndex}-${instance}`,
    participantIndex,
    instance,
    elType,
    clType,
  };
}

function expandParticipants(value: unknown): NodePair[] {
  if (value === undefined) {
    return [];
  }
  const participants = asArray(value, "participants");
  const pairs: NodePair[] = [];
  for (const [offset, entry] of participants.entries()) {
    const participant = asRecord(entry, `participants[${offset}]`) as ParticipantInput;
    const count = countOf(participant.count, `participants[${offset}].count`);
    if (count > maxPairs - pairs.length) {
      throw new Error(`E2B topology is limited to ${maxPairs} participant pairs`);
    }
    for (let instance = 1; instance <= count; instance += 1) {
      pairs.push(parseParticipant(participant, offset + 1, instance));
    }
  }
  return pairs;
}

function expandMatrix(value: unknown, participantOffset: number): NodePair[] {
  if (value === undefined) {
    return [];
  }
  const matrix = asRecord(value, "participants_matrix") as MatrixInput;
  rejectUnknownKeys(matrix, matrixKeys, "participants_matrix");
  const executionClients = asArray(matrix.el ?? [], "participants_matrix.el");
  const consensusClients = asArray(matrix.cl ?? [], "participants_matrix.cl");
  if (executionClients.length === 0 || consensusClients.length === 0) {
    throw new Error("participants_matrix requires non-empty el and cl lists");
  }
  const matrixCount = countOf(matrix.count, "participants_matrix.count");
  const pairs: NodePair[] = [];
  let participantIndex = participantOffset;
  for (const [elOffset, elValue] of executionClients.entries()) {
    const el = asRecord(elValue, `participants_matrix.el[${elOffset}]`);
    rejectUnknownKeys(el, elMatrixKeys, `participants_matrix.el[${elOffset}]`);
    for (const [clOffset, clValue] of consensusClients.entries()) {
      const cl = asRecord(clValue, `participants_matrix.cl[${clOffset}]`);
      rejectUnknownKeys(cl, clMatrixKeys, `participants_matrix.cl[${clOffset}]`);
      const clientCount = countOf(cl.count, `participants_matrix.cl[${clOffset}].count`);
      if (
        clientCount > 0 &&
        matrixCount > Math.floor((maxPairs - participantOffset - pairs.length) / clientCount)
      ) {
        throw new Error(`E2B topology is limited to ${maxPairs} participant pairs`);
      }
      participantIndex += 1;
      const count = matrixCount * clientCount;
      for (let instance = 1; instance <= count; instance += 1) {
        pairs.push(
          parseParticipant(
            { el_type: el.el_type, cl_type: cl.cl_type },
            participantIndex,
            instance,
          ),
        );
      }
    }
  }
  return pairs;
}

function resolveNetwork(config: ConfigInput, override?: Network): Network {
  if (override) {
    return override;
  }
  const networkParams =
    config.network_params === undefined
      ? undefined
      : asRecord(config.network_params, "network_params");
  const configured = networkParams?.network;
  if (configured === undefined) {
    throw new Error(
      "E2B topology requires a public network in network_params.network or --network",
    );
  }
  if (configured === "kurtosis") {
    throw new Error(
      "custom Kurtosis networks require inbound P2P and genesis services that E2B does not provide",
    );
  }
  if (!networks.includes(configured as Network)) {
    throw new Error(`network must be one of: ${networks.join(", ")}`);
  }
  return configured as Network;
}

export function parseTopology(source: string, networkOverride?: Network): Topology {
  const parsed: unknown = parse(source);
  const configRecord = asRecord(parsed, "configuration");
  rejectUnknownKeys(configRecord, rootKeys, "root");
  const config = configRecord as ConfigInput;
  if (
    config.additional_services !== undefined &&
    asArray(config.additional_services, "additional_services").length > 0
  ) {
    throw new Error("additional_services are not supported by the E2B topology adapter");
  }

  const hasConfiguredParticipants =
    config.participants !== undefined || config.participants_matrix !== undefined;
  const explicit = expandParticipants(config.participants);
  const matrix = expandMatrix(config.participants_matrix, explicit.length);
  const expandedPairs = [...explicit, ...matrix];
  if (expandedPairs.length === 0 && hasConfiguredParticipants) {
    throw new Error("configuration expands to zero participants");
  }
  if (expandedPairs.length === 0) {
    expandedPairs.push(parseParticipant({}, 1, 1));
  }
  const pairs = expandedPairs.map((pair, index) => ({
    ...pair,
    id: `participant-${index + 1}`,
    participantIndex: index + 1,
  }));

  return {
    network: resolveNetwork(config, networkOverride),
    pairs,
    sandboxCount: pairs.length * 2,
  };
}
