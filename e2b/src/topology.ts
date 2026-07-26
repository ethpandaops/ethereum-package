import { parse } from "yaml";

import { networks, type Network } from "./config.js";

export type ExecutionClient = "geth";
export type ConsensusClient = "lighthouse" | "prysm";
export type ValidatorClient = ConsensusClient;

export interface NodePair {
  id: string;
  participantIndex: number;
  instance: number;
  elType: ExecutionClient;
  clType: ConsensusClient;
  vcType: ValidatorClient;
  validatorCount: number;
}

export interface DevnetConfig {
  networkId: string;
  preset: "mainnet" | "minimal";
  secondsPerSlot: number;
  genesisDelaySeconds: number;
  genesisTime?: number;
  preregisteredValidatorCount?: number;
  mnemonic: string;
}

export interface Topology {
  network: Network;
  pairs: NodePair[];
  sandboxCount: number;
  devnet?: DevnetConfig;
}

interface ParticipantInput {
  el_type?: unknown;
  cl_type?: unknown;
  vc_type?: unknown;
  validator_count?: unknown;
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
  vc_type: true,
  validator_count: true,
  count: true,
};
const matrixKeys: Record<string, true> = { el: true, cl: true, count: true };
const elMatrixKeys: Record<string, true> = { el_type: true };
const clMatrixKeys: Record<string, true> = { cl_type: true, count: true };
const rootKeys: Record<string, true> = {
  participants: true,
  participants_matrix: true,
  network_params: true,
  additional_services: true,
};
const devnetNetworkParameterKeys: Record<string, true> = {
  network: true,
  network_id: true,
  preset: true,
  seconds_per_slot: true,
  genesis_delay: true,
  genesis_time: true,
  num_validator_keys_per_node: true,
  preregistered_validator_count: true,
  preregistered_validator_keys_mnemonic: true,
};
const publicNetworkParameterKeys: Record<string, true> = { network: true };
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
  defaultValidatorCount: number,
): NodePair {
  rejectUnknownKeys(input, participantKeys, `participant ${participantIndex}`);
  const elType = input.el_type ?? "geth";
  const clType = input.cl_type ?? "lighthouse";
  const vcType = input.vc_type ?? clType;
  if (elType !== "geth") {
    throw new Error(`unsupported EL client in participant ${participantIndex}: ${String(elType)}`);
  }
  if (clType !== "lighthouse" && clType !== "prysm") {
    throw new Error(`unsupported CL client in participant ${participantIndex}: ${String(clType)}`);
  }
  if (vcType !== "lighthouse" && vcType !== "prysm") {
    throw new Error(`unsupported VC client in participant ${participantIndex}: ${String(vcType)}`);
  }
  const validatorCount =
    input.validator_count == null
      ? defaultValidatorCount
      : countOf(input.validator_count, `participant ${participantIndex}.validator_count`);
  return {
    id: `participant-${participantIndex}-${instance}`,
    participantIndex,
    instance,
    elType,
    clType,
    vcType,
    validatorCount,
  };
}

function expandParticipants(value: unknown, defaultValidatorCount: number): NodePair[] {
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
      pairs.push(parseParticipant(participant, offset + 1, instance, defaultValidatorCount));
    }
  }
  return pairs;
}

function expandMatrix(
  value: unknown,
  participantOffset: number,
  defaultValidatorCount: number,
): NodePair[] {
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
            defaultValidatorCount,
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
    throw new Error("E2B topology requires network_params.network or --network");
  }
  if (!networks.includes(configured as Network)) {
    throw new Error(`network must be one of: ${networks.join(", ")}`);
  }
  return configured as Network;
}

const defaultMnemonic =
  "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete";

function integerParameter(
  value: unknown,
  fallback: number,
  label: string,
  minimum: number,
): number {
  const result = value ?? fallback;
  if (!Number.isInteger(result) || (result as number) < minimum) {
    throw new Error(`${label} must be an integer greater than or equal to ${minimum}`);
  }
  return result as number;
}

function devnetConfig(networkParams: Record<string, unknown>): DevnetConfig {
  const networkIdValue = networkParams.network_id ?? "3151908";
  if (
    (typeof networkIdValue !== "string" && typeof networkIdValue !== "number") ||
    String(networkIdValue).length === 0
  ) {
    throw new Error("network_params.network_id must be a string or number");
  }
  const preset = networkParams.preset ?? "mainnet";
  if (preset !== "mainnet" && preset !== "minimal") {
    throw new Error("network_params.preset must be mainnet or minimal");
  }
  const mnemonic = networkParams.preregistered_validator_keys_mnemonic ?? defaultMnemonic;
  if (typeof mnemonic !== "string" || mnemonic.trim().length === 0) {
    throw new Error("network_params.preregistered_validator_keys_mnemonic must be a string");
  }
  return {
    networkId: String(networkIdValue),
    preset,
    secondsPerSlot: integerParameter(
      networkParams.seconds_per_slot,
      preset === "minimal" ? 6 : 12,
      "network_params.seconds_per_slot",
      1,
    ),
    genesisDelaySeconds: integerParameter(
      networkParams.genesis_delay,
      20,
      "network_params.genesis_delay",
      0,
    ),
    genesisTime: integerParameter(
      networkParams.genesis_time,
      0,
      "network_params.genesis_time",
      0,
    ),
    preregisteredValidatorCount: integerParameter(
      networkParams.preregistered_validator_count,
      0,
      "network_params.preregistered_validator_count",
      0,
    ),
    mnemonic: mnemonic.trim().replaceAll(/\s+/g, " "),
  };
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

  const network = resolveNetwork(config, networkOverride);
  const networkParams =
    config.network_params === undefined
      ? {}
      : asRecord(config.network_params, "network_params");
  rejectUnknownKeys(
    networkParams,
    network === "kurtosis" ? devnetNetworkParameterKeys : publicNetworkParameterKeys,
    "network_params",
  );
  const defaultValidatorCount =
    network === "kurtosis"
      ? integerParameter(
          networkParams.num_validator_keys_per_node,
          128,
          "network_params.num_validator_keys_per_node",
          0,
        )
      : 0;
  const hasConfiguredParticipants =
    config.participants !== undefined || config.participants_matrix !== undefined;
  const explicit = expandParticipants(config.participants, defaultValidatorCount);
  const matrix = expandMatrix(
    config.participants_matrix,
    explicit.length,
    defaultValidatorCount,
  );
  const expandedPairs = [...explicit, ...matrix];
  if (expandedPairs.length === 0 && hasConfiguredParticipants) {
    throw new Error("configuration expands to zero participants");
  }
  if (expandedPairs.length === 0) {
    expandedPairs.push(parseParticipant({}, 1, 1, defaultValidatorCount));
  }
  const pairs = expandedPairs.map((pair, index) => ({
    ...pair,
    id: `participant-${index + 1}`,
    participantIndex: index + 1,
  }));
  const topology: Topology = {
    network,
    pairs,
    sandboxCount: pairs.length * 2,
  };
  if (network !== "kurtosis" && pairs.some(({ validatorCount }) => validatorCount > 0)) {
    throw new Error("validator clients are only supported on private E2B devnets");
  }
  if (network === "kurtosis") {
    if (pairs.length !== 1) {
      throw new Error("a private E2B devnet supports exactly one EL-CL participant pair");
    }
    if (pairs.every(({ validatorCount }) => validatorCount === 0)) {
      throw new Error("a private devnet requires at least one validator");
    }
    topology.devnet = devnetConfig(networkParams);
  }
  return topology;
}
