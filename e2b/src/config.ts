export const networks = ["mainnet", "sepolia", "hoodi"] as const;
export type Network = (typeof networks)[number];

export const defaultCheckpointUrls: Record<Network, string> = {
  mainnet: "https://mainnet.checkpoint.sigp.io",
  sepolia: "https://checkpoint-sync.sepolia.ethpandaops.io",
  hoodi: "https://hoodi.checkpoint.sigp.io",
};

export interface LaunchOptions {
  network?: Network;
  configPath?: string;
  timeoutMinutes: number;
  checkpointUrl?: string;
}

export function gethArgs(network: Network, jwtPath: string): string[] {
  return [
    "geth",
    `--${network}`,
    "--datadir=/home/user/ethereum/geth",
    "--syncmode=snap",
    "--http",
    "--http.addr=127.0.0.1",
    "--http.port=8545",
    "--http.vhosts=*",
    "--http.corsdomain=*",
    "--http.api=eth,net,web3",
    "--authrpc.addr=0.0.0.0",
    "--authrpc.port=8551",
    "--authrpc.vhosts=*",
    `--authrpc.jwtsecret=${jwtPath}`,
    "--metrics",
    "--metrics.addr=127.0.0.1",
    "--metrics.port=9001",
  ];
}

export function lighthouseArgs(
  network: Network,
  jwtPath: string,
  executionEndpoint: string,
  checkpointUrl?: string,
): string[] {
  const args = [
    "lighthouse",
    "beacon_node",
    `--network=${network}`,
    "--datadir=/home/user/ethereum/lighthouse",
    `--execution-endpoints=${executionEndpoint}`,
    `--jwt-secrets=${jwtPath}`,
    "--http",
    "--http-address=0.0.0.0",
    "--http-port=4000",
    "--metrics",
    "--metrics-address=0.0.0.0",
    "--metrics-port=5054",
    "--disable-enr-auto-update",
  ];
  if (checkpointUrl) {
    args.push(`--checkpoint-sync-url=${checkpointUrl}`);
  } else {
    args.push("--allow-insecure-genesis-sync", "--ignore-ws-check");
  }
  return args;
}
export function prysmArgs(
  network: Network,
  jwtPath: string,
  executionEndpoint: string,
  checkpointUrl?: string,
): string[] {
  const args = [
    "beacon-chain",
    `--${network}`,
    "--accept-terms-of-use=true",
    "--datadir=/home/user/ethereum/prysm",
    `--execution-endpoint=${executionEndpoint}`,
    `--jwt-secret=${jwtPath}`,
    "--http-host=0.0.0.0",
    "--http-cors-domain=*",
    "--http-port=3500",
    "--rpc-host=127.0.0.1",
    "--rpc-port=4000",
    "--disable-monitoring=false",
    "--monitoring-host=0.0.0.0",
    "--monitoring-port=8080",
  ];
  if (checkpointUrl) {
    args.push(
      `--checkpoint-sync-url=${checkpointUrl}`,
      `--genesis-beacon-api-url=${checkpointUrl}`,
    );
  }
  return args;
}


export function parseOptions(args: string[]): LaunchOptions {
  let network: Network | undefined;
  let configPath: string | undefined;
  let timeoutMinutes = 60;
  let checkpointUrl: string | undefined;

  for (let index = 0; index < args.length; index += 2) {
    const option = args[index];
    const value = args[index + 1];
    if (!option || !value) {
      throw new Error(`missing value for ${option ?? "option"}`);
    }
    if (option === "--network") {
      if (!networks.includes(value as Network)) {
        throw new Error(`network must be one of: ${networks.join(", ")}`);
      }
      network = value as Network;
    } else if (option === "--config") {
      configPath = value;
    } else if (option === "--timeout") {
      timeoutMinutes = Number(value);
      if (!Number.isInteger(timeoutMinutes) || timeoutMinutes < 5 || timeoutMinutes > 1440) {
        throw new Error("timeout must be an integer from 5 to 1440 minutes");
      }
    } else if (option === "--checkpoint-url") {
      const url = new URL(value);
      if (url.protocol !== "https:" && url.protocol !== "http:") {
        throw new Error("checkpoint URL must use HTTP or HTTPS");
      }
      checkpointUrl = url.toString().replace(/\/$/, "");
    } else {
      throw new Error(`unknown option: ${option}`);
    }
  }

  const options: LaunchOptions = { timeoutMinutes };
  if (network) {
    options.network = network;
    options.checkpointUrl = checkpointUrl ?? defaultCheckpointUrls[network];
  } else if (checkpointUrl) {
    options.checkpointUrl = checkpointUrl;
  }
  if (configPath) {
    options.configPath = configPath;
  }
  return options;
}
