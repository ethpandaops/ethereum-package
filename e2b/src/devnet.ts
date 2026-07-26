import { type Sandbox } from "e2b";

import { type DevnetConfig, type NodePair, type Topology } from "./topology.js";

export const devnetRoot = "/home/user/devnet";
export const devnetGenesisPath = `${devnetRoot}/metadata/genesis.json`;

const feeRecipient = "0x0000000000000000000000000000000000000000";

export function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}

function requireDevnet(topology: Topology): DevnetConfig {
  if (!topology.devnet) {
    throw new Error("private devnet configuration is missing");
  }
  return topology.devnet;
}

function genesisEnvironment(topology: Topology, genesisTimestamp: number): string {
  const config = requireDevnet(topology);
  const participantValidatorCount = topology.pairs.reduce(
    (total, pair) => total + pair.validatorCount,
    0,
  );
  const validatorCount =
    config.preregisteredValidatorCount && config.preregisteredValidatorCount > 0
      ? config.preregisteredValidatorCount
      : participantValidatorCount;
  return [
    `export PRESET_BASE=${shellQuote(config.preset)}`,
    `export CHAIN_ID=${shellQuote(config.networkId)}`,
    `export EL_AND_CL_MNEMONIC=${shellQuote(config.mnemonic)}`,
    `export NUMBER_OF_VALIDATORS=${validatorCount}`,
    `export GENESIS_TIMESTAMP=${genesisTimestamp}`,
    `export GENESIS_DELAY=0`,
    `export SLOT_DURATION_IN_SECONDS=${config.secondsPerSlot}`,
    `export SLOT_DURATION_MS=${config.secondsPerSlot * 1_000}`,
    "export ALTAIR_FORK_EPOCH=0",
    "export BELLATRIX_FORK_EPOCH=0",
    "export CAPELLA_FORK_EPOCH=0",
    "export DENEB_FORK_EPOCH=0",
    "export ELECTRA_FORK_EPOCH=0",
    "export FULU_FORK_EPOCH=0",
    "export GLOAS_FORK_EPOCH=18446744073709551615",
    "export HEZE_FORK_EPOCH=18446744073709551615",
    "export WITHDRAWAL_TYPE=0x01",
    `export WITHDRAWAL_ADDRESS=${feeRecipient}`,
    "",
  ].join("\n");
}

export function plannedGenesisTimestamp(topology: Topology): number {
  const config = requireDevnet(topology);
  if (config.genesisTime && config.genesisTime > 0) {
    return config.genesisTime;
  }
  const startupAllowance = 60 + topology.pairs.length * 10;
  return Math.floor(Date.now() / 1_000) + Math.max(config.genesisDelaySeconds, startupAllowance);
}

export async function generateDevnetArtifacts(
  sandbox: Sandbox,
  topology: Topology,
  genesisTimestamp: number,
): Promise<Uint8Array> {
  const config = requireDevnet(topology);
  await sandbox.files.write("/config/values.env", genesisEnvironment(topology, genesisTimestamp));
  await sandbox.commands.run("rm -rf /data/* && /work/entrypoint.sh all", {
    timeoutMs: 120_000,
  });

  let validatorIndex = 0;
  const commands: string[] = ["mkdir -p /data/keystores"];
  for (const pair of topology.pairs) {
    const start = validatorIndex;
    const stop = start + pair.validatorCount;
    validatorIndex = stop;
    if (pair.validatorCount === 0) {
      continue;
    }
    commands.push(
      [
        "eth2-val-tools",
        "keystores",
        "--insecure",
        "--prysm-pass",
        "password",
        "--out-loc",
        `/data/keystores/${pair.id}`,
        "--source-mnemonic",
        config.mnemonic,
        "--source-min",
        String(start),
        "--source-max",
        String(stop),
      ]
        .map(shellQuote)
        .join(" "),
    );
  }
  commands.push(
    "printf 'password\\n' > /data/prysm-password.txt",
    "tar -C /data -czf /tmp/e2b-devnet.tar.gz metadata keystores prysm-password.txt",
  );
  await sandbox.commands.run(commands.join(" && "), { timeoutMs: 120_000 });
  return sandbox.files.read("/tmp/e2b-devnet.tar.gz", { format: "bytes" });
}

export async function installDevnetArtifacts(
  sandbox: Sandbox,
  artifacts: Uint8Array,
): Promise<void> {
  const buffer =
    artifacts.byteOffset === 0 && artifacts.byteLength === artifacts.buffer.byteLength
      ? (artifacts.buffer as ArrayBuffer)
      : artifacts.slice().buffer;
  await sandbox.files.write("/tmp/e2b-devnet.tar.gz", buffer);
  await sandbox.commands.run(
    `rm -rf ${shellQuote(devnetRoot)} && mkdir -p ${shellQuote(devnetRoot)} && tar -C ${shellQuote(devnetRoot)} -xzf /tmp/e2b-devnet.tar.gz`,
    { timeoutMs: 30_000 },
  );
}

export function gethDevnetArgs(config: DevnetConfig, jwtPath: string): string[] {
  return [
    "geth",
    `--override.genesis=${devnetGenesisPath}`,
    `--networkid=${config.networkId}`,
    "--datadir=/home/user/ethereum/geth",
    "--syncmode=full",
    "--nodiscover",
    "--http",
    "--http.addr=127.0.0.1",
    "--http.port=8545",
    "--http.vhosts=*",
    "--http.corsdomain=*",
    "--http.api=admin,eth,net,web3",
    "--authrpc.addr=0.0.0.0",
    "--authrpc.port=8551",
    "--authrpc.vhosts=*",
    `--authrpc.jwtsecret=${jwtPath}`,
    "--rpc.allow-unprotected-txs",
    "--miner.gasprice=1",
    "--metrics",
    "--metrics.addr=127.0.0.1",
    "--metrics.port=9001",
  ];
}

export function lighthouseDevnetArgs(
  jwtPath: string,
  executionEndpoint: string,
): string[] {
  return [
    "lighthouse",
    "beacon_node",
    `--testnet-dir=${devnetRoot}/metadata`,
    "--datadir=/home/user/ethereum/lighthouse",
    `--execution-endpoints=${executionEndpoint}`,
    `--jwt-secrets=${jwtPath}`,
    "--suggested-fee-recipient=" + feeRecipient,
    "--disable-discovery",
    "--allow-insecure-genesis-sync",
    "--http",
    "--http-address=127.0.0.1",
    "--http-port=4000",
    "--metrics",
    "--metrics-address=127.0.0.1",
    "--metrics-port=5054",
  ];
}

export function prysmDevnetArgs(
  config: DevnetConfig,
  jwtPath: string,
  executionEndpoint: string,
): string[] {
  const args = [
    "beacon-chain",
    "--accept-terms-of-use=true",
    "--datadir=/home/user/ethereum/prysm",
    `--chain-config-file=${devnetRoot}/metadata/config.yaml`,
    `--genesis-state=${devnetRoot}/metadata/genesis.ssz`,
    "--contract-deployment-block=0",
    `--execution-endpoint=${executionEndpoint}`,
    `--jwt-secret=${jwtPath}`,
    "--p2p-host-ip=127.0.0.1",
    "--p2p-tcp-port=13000",
    "--p2p-udp-port=12000",
    "--p2p-quic-port=14000",
    "--p2p-static-id=true",
    "--min-sync-peers=0",
    "--http-host=127.0.0.1",
    "--http-cors-domain=*",
    "--http-port=3500",
    "--rpc-host=127.0.0.1",
    "--rpc-port=4000",
    "--disable-monitoring=false",
    "--monitoring-host=127.0.0.1",
    "--monitoring-port=8080",
    "--suggested-fee-recipient=" + feeRecipient,
  ];
  if (config.preset === "minimal") {
    args.push("--minimal-config=true");
  }
  return args;
}

export function validatorArgs(pair: NodePair, beaconApiUrl: string): string[] {
  const keyRoot = `${devnetRoot}/keystores/${pair.id}`;
  if (pair.vcType === "lighthouse") {
    return [
      "lighthouse",
      "vc",
      `--testnet-dir=${devnetRoot}/metadata`,
      `--validators-dir=${keyRoot}/keys`,
      `--secrets-dir=${keyRoot}/secrets`,
      "--init-slashing-protection",
      `--beacon-nodes=${beaconApiUrl}`,
      "--suggested-fee-recipient=" + feeRecipient,
      "--metrics",
      "--metrics-address=127.0.0.1",
      "--metrics-port=8081",
    ];
  }
  return [
    "validator",
    "--accept-terms-of-use=true",
    `--chain-config-file=${devnetRoot}/metadata/config.yaml`,
    `--beacon-rest-api-provider=${beaconApiUrl}`,
    "--enable-beacon-rest-api",
    `--wallet-dir=${keyRoot}/prysm`,
    `--wallet-password-file=${devnetRoot}/prysm-password.txt`,
    "--suggested-fee-recipient=" + feeRecipient,
    "--disable-monitoring=false",
    "--monitoring-host=127.0.0.1",
    "--monitoring-port=8081",
  ];
}
