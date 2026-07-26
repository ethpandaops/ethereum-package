import { randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { setTimeout as delay } from "node:timers/promises";

import { Sandbox, type CommandHandle } from "e2b";

import {
  resolveCheckpointUrl,
  gethArgs,
  lighthouseArgs,
  parseOptions,
  prysmArgs,
  type PublicNetwork,
} from "./config.js";
import {
  devnetGenesisPath,
  generateDevnetArtifacts,
  gethDevnetArgs,
  installDevnetArtifacts,
  lighthouseDevnetArgs,
  plannedGenesisTimestamp,
  prysmDevnetArgs,
  shellQuote,
  validatorArgs,
} from "./devnet.js";
import { parseTopology, type ConsensusClient, type NodePair } from "./topology.js";

const template = process.env.E2B_TEMPLATE ?? "ethereum-client-topology";
const jwtPath = "/home/user/ethereum/jwt.hex";

type InterruptSignal = "SIGINT" | "SIGTERM";
type ClientLayer = "el" | "cl" | "generator";
type ClientName = "geth" | ConsensusClient | "genesis";

interface ManagedSandbox {
  pairId: string;
  layer: ClientLayer;
  client: ClientName;
  sandbox: Sandbox;
  logPath: string;
}

interface PairRuntime {
  plan: NodePair;
  jwt: string;
  geth?: ManagedSandbox;
  consensus?: ManagedSandbox;
  gethHandle?: CommandHandle;
  consensusHandle?: CommandHandle;
  validatorHandle?: CommandHandle;
  validatorLogPath?: string;
}

function command(args: string[], logPath: string): string {
  return `${args.map(shellQuote).join(" ")} > ${shellQuote(logPath)} 2>&1`;
}

function throwIfAborted(signal?: AbortSignal): void {
  if (!signal?.aborted) {
    return;
  }
  throw signal.reason instanceof Error ? signal.reason : new Error("startup readiness cancelled");
}

async function waitForCommand(
  sandbox: Sandbox,
  commandText: string,
  label: string,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    throwIfAborted(signal);
    const remainingMs = deadline - Date.now();
    try {
      await sandbox.commands.run(commandText, {
        timeoutMs: Math.min(5_000, remainingMs),
        ...(signal ? { signal } : {}),
      });
      return;
    } catch {
      throwIfAborted(signal);
      if (Date.now() >= deadline) {
        break;
      }
      await delay(
        Math.min(2_000, deadline - Date.now()),
        undefined,
        signal ? { signal } : undefined,
      );
    }
  }
  throw new Error(`${label} did not become ready within ${timeoutMs / 1_000} seconds`);
}

function waitForHttp(
  sandbox: Sandbox,
  url: string,
  label: string,
  signal?: AbortSignal,
): Promise<void> {
  return waitForCommand(
    sandbox,
    `curl --fail --silent ${shellQuote(url)} >/dev/null`,
    label,
    120_000,
    signal,
  );
}

function waitForConsensusExecution(
  sandbox: Sandbox,
  apiPort: number,
  label: string,
  signal?: AbortSignal,
): Promise<void> {
  return waitForCommand(
    sandbox,
    `curl --fail --silent http://127.0.0.1:${apiPort}/eth/v1/node/syncing | jq --exit-status '.data.el_offline == false' >/dev/null`,
    label,
    120_000,
    signal,
  );
}

function waitForExecutionBlock(sandbox: Sandbox, signal?: AbortSignal): Promise<void> {
  const payload = JSON.stringify({
    jsonrpc: "2.0",
    method: "eth_blockNumber",
    params: [],
    id: 1,
  });
  return waitForCommand(
    sandbox,
    `curl --fail --silent -H 'Content-Type: application/json' --data ${shellQuote(payload)} http://127.0.0.1:8545 | jq --exit-status '.result != "0x0" and .result != null' >/dev/null`,
    "private testnet execution block",
    240_000,
    signal,
  );
}

async function raceStartup(
  readiness: (signal: AbortSignal) => Promise<void>,
  failures: Promise<never>[],
): Promise<void> {
  const controller = new AbortController();
  try {
    await Promise.race([readiness(controller.signal), ...failures]);
  } finally {
    controller.abort(new Error("startup readiness settled"));
  }
}


function failWhenProcessExits(handle: CommandHandle, label: string): Promise<never> {
  return handle.wait().then(
    ({ exitCode }) => {
      throw new Error(`${label} exited before startup completed (exit code ${exitCode})`);
    },
    (error: unknown) => {
      const exitCode = handle.exitCode === undefined ? "" : ` (exit code ${handle.exitCode})`;
      throw new Error(`${label} exited before startup completed${exitCode}`, { cause: error });
    },
  );
}

function assertProcessRunning(handle: CommandHandle | undefined, label: string): void {
  if (!handle || handle.exitCode !== undefined) {
    const exitCode = handle?.exitCode === undefined ? "" : ` (exit code ${handle.exitCode})`;
    throw new Error(`${label} exited before startup completed${exitCode}`);
  }
}

async function settleAll(tasks: Promise<void>[], label: string): Promise<void> {
  const results = await Promise.allSettled(tasks);
  const failures = results
    .filter((result): result is PromiseRejectedResult => result.status === "rejected")
    .map(({ reason }) => reason);
  if (failures.length > 0) {
    throw new AggregateError(failures, `${label} failed`);
  }
}

function requireSandbox(
  runtime: PairRuntime,
  layer: "geth" | "consensus",
): ManagedSandbox {
  const managed = runtime[layer];
  if (!managed) {
    throw new Error(`${runtime.plan.id} has no ${layer} sandbox`);
  }
  return managed;
}


async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const source = options.configPath ? await readFile(options.configPath, "utf8") : undefined;
  const defaultNetwork = options.network ?? "hoodi";
  const topology = source
    ? parseTopology(source, options.network)
    : parseTopology(
        `network_params:\n  network: ${defaultNetwork}\nparticipants:\n  - el_type: geth\n    cl_type: lighthouse\n`,
      );
  const isDevnet = topology.network === "kurtosis";
  const checkpointUrl = resolveCheckpointUrl(topology.network, options.checkpointUrl);
  const launchId = `${Date.now().toString(36)}-${randomBytes(8).toString("hex")}`;
  const runtimes: PairRuntime[] = topology.pairs.map((plan) => ({
    plan,
    jwt: randomBytes(32).toString("hex"),
  }));
  const managedSandboxes: ManagedSandbox[] = [];
  let cleanupPromise: Promise<void> | undefined;
  let cleanupFailureReported = false;
  let interruptedSignal: InterruptSignal | undefined;
  let genesisTimestamp: number | undefined;
  const { promise: interruption, resolve: resolveInterruption } =
    Promise.withResolvers<InterruptSignal>();

  async function killSandbox(sandboxId: string): Promise<void> {
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        await Sandbox.kill(sandboxId);
        return;
      } catch (error) {
        if (attempt === 3) {
          throw error;
        }
        await delay(attempt * 500);
      }
    }
  }

  async function discoverLaunchSandboxIds(): Promise<string[]> {
    const paginator = Sandbox.list({
      query: {
        metadata: {
          application: "ethereum-package",
          launch_id: launchId,
        },
      },
    });
    const sandboxIds: string[] = [];
    while (paginator.hasNext) {
      const sandboxes = await paginator.nextItems();
      sandboxIds.push(...sandboxes.map(({ sandboxId }) => sandboxId));
    }
    return sandboxIds;
  }

  const cleanupSandboxes = (): Promise<void> => {
    cleanupPromise ??= (async () => {
      const sandboxIds = new Set(
        managedSandboxes.map(({ sandbox }) => sandbox.sandboxId),
      );
      let discovered = false;
      let discoveryError: unknown;
      for (let scan = 0; scan < 3; scan += 1) {
        try {
          for (const sandboxId of await discoverLaunchSandboxIds()) {
            sandboxIds.add(sandboxId);
          }
          discovered = true;
          discoveryError = undefined;
        } catch (error) {
          discoveryError = error;
        }
        await settleAll(
          [...sandboxIds].map((sandboxId) => killSandbox(sandboxId)),
          "sandbox cleanup",
        );
        if (scan < 2) {
          await delay(1_000);
        }
      }
      if (!discovered) {
        throw new Error("could not reconcile launch sandboxes during cleanup", {
          cause: discoveryError,
        });
      }
    })();
    return cleanupPromise;
  };

  const reportCleanupFailure = (context: string, cleanupError: unknown): void => {
    if (cleanupFailureReported) {
      return;
    }
    cleanupFailureReported = true;
    const sandboxIds = managedSandboxes
      .map(({ pairId, layer, sandbox }) => `${pairId}/${layer}=${sandbox.sandboxId}`)
      .join(", ");
    console.error(`Failed to clean up sandboxes (${sandboxIds}) ${context}:`, cleanupError);
  };

  function removeSignalHandlers(): void {
    process.off("SIGINT", handleSigint);
    process.off("SIGTERM", handleSigterm);
  }

  function throwIfInterrupted(): void {
    if (interruptedSignal !== undefined) {
      throw new Error(`Startup interrupted by ${interruptedSignal}`);
    }
  }

  function failOnInterruption(): Promise<never> {
    return interruption.then((signal) => {
      throw new Error(`Startup interrupted by ${signal}`);
    });
  }

  function handleSignal(signal: InterruptSignal): void {
    if (interruptedSignal !== undefined) {
      return;
    }
    interruptedSignal = signal;
    resolveInterruption(signal);
  }

  function handleSigint(): void {
    handleSignal("SIGINT");
  }

  function handleSigterm(): void {
    handleSignal("SIGTERM");
  }

  async function createSandbox(
    pairId: string,
    layer: ClientLayer,
    client: ClientName,
    allowPublicTraffic: boolean,
  ): Promise<ManagedSandbox> {
    const sandbox = await Sandbox.create(template, {
      timeoutMs: options.timeoutMinutes * 60_000,
      allowInternetAccess: true,
      network: { allowPublicTraffic },
      metadata: {
        application: "ethereum-package",
        launch_id: launchId,
        network: topology.network,
        participant: pairId,
        layer,
        client,
      },
    });
    const managed = {
      pairId,
      layer,
      client,
      sandbox,
      logPath: `/home/user/${pairId}-${client}.log`,
    } satisfies ManagedSandbox;
    managedSandboxes.push(managed);
    return managed;
  }

  async function releaseSandbox(managed: ManagedSandbox): Promise<void> {
    await killSandbox(managed.sandbox.sandboxId);
    const index = managedSandboxes.indexOf(managed);
    if (index >= 0) {
      managedSandboxes.splice(index, 1);
    }
  }

  async function startConsensus(runtime: PairRuntime): Promise<void> {
    const geth = requireSandbox(runtime, "geth");
    const consensus = requireSandbox(runtime, "consensus");
    const executionEndpoint = `https://${geth.sandbox.getHost(8551)}`;
    const args = isDevnet
      ? runtime.plan.clType === "lighthouse"
        ? lighthouseDevnetArgs(jwtPath, executionEndpoint)
        : prysmDevnetArgs(topology.devnet!, jwtPath, executionEndpoint)
      : runtime.plan.clType === "lighthouse"
        ? lighthouseArgs(
            topology.network as PublicNetwork,
            jwtPath,
            executionEndpoint,
            checkpointUrl,
          )
        : prysmArgs(
            topology.network as PublicNetwork,
            jwtPath,
            executionEndpoint,
            checkpointUrl,
          );
    const apiPort = runtime.plan.clType === "lighthouse" ? 4000 : 3500;
    runtime.consensusHandle = await consensus.sandbox.commands.run(
      command(args, consensus.logPath),
      { background: true, timeoutMs: 0 },
    );
    await raceStartup(
      (signal) =>
        waitForConsensusExecution(
          consensus.sandbox,
          apiPort,
          `${runtime.plan.id} ${runtime.plan.clType} execution connection`,
          signal,
        ),
      [
        failWhenProcessExits(runtime.gethHandle!, `${runtime.plan.id} Geth`),
        failWhenProcessExits(
          runtime.consensusHandle,
          `${runtime.plan.id} ${runtime.plan.clType}`,
        ),
        failOnInterruption(),
      ],
    );
  }

  process.on("SIGINT", handleSigint);
  process.on("SIGTERM", handleSigterm);

  try {
    let devnetArtifacts: Uint8Array | undefined;
    if (isDevnet) {
      genesisTimestamp = plannedGenesisTimestamp(topology);
      const generator = await createSandbox("devnet", "generator", "genesis", false);
      try {
        devnetArtifacts = await generateDevnetArtifacts(
          generator.sandbox,
          topology,
          genesisTimestamp,
        );
      } finally {
        await releaseSandbox(generator);
      }
      throwIfInterrupted();
    }

    await settleAll(
      runtimes.flatMap((runtime) => [
        (async () => {
          runtime.geth = await createSandbox(
            runtime.plan.id,
            "el",
            "geth",
            true,
          );
        })(),
        (async () => {
          runtime.consensus = await createSandbox(
            runtime.plan.id,
            "cl",
            runtime.plan.clType,
            false,
          );
        })(),
      ]),
      "client sandbox creation",
    );
    throwIfInterrupted();


    await settleAll(
      runtimes.map(async (runtime) => {
        const geth = requireSandbox(runtime, "geth");
        const consensus = requireSandbox(runtime, "consensus");
        await Promise.all([
          geth.sandbox.files.write(jwtPath, runtime.jwt),
          consensus.sandbox.files.write(jwtPath, runtime.jwt),
          ...(devnetArtifacts
            ? [
                installDevnetArtifacts(geth.sandbox, devnetArtifacts),
                installDevnetArtifacts(consensus.sandbox, devnetArtifacts),
              ]
            : []),
        ]);
      }),
      "client configuration",
    );
    throwIfInterrupted();

    await settleAll(
      runtimes.map(async (runtime) => {
        const geth = requireSandbox(runtime, "geth");
        if (isDevnet) {
          await geth.sandbox.commands.run(
            `geth init --datadir=/home/user/ethereum/geth ${shellQuote(devnetGenesisPath)}`,
            { timeoutMs: 30_000 },
          );
        }
        const args = isDevnet
          ? gethDevnetArgs(topology.devnet!, jwtPath)
          : gethArgs(topology.network as PublicNetwork, jwtPath);
        runtime.gethHandle = await geth.sandbox.commands.run(command(args, geth.logPath), {
          background: true,
          timeoutMs: 0,
        });
        await raceStartup(
          (signal) =>
            waitForHttp(
              geth.sandbox,
              "http://127.0.0.1:8545",
              `${runtime.plan.id} geth RPC`,
              signal,
            ),
          [
            failWhenProcessExits(runtime.gethHandle, `${runtime.plan.id} Geth`),
            failOnInterruption(),
          ],
        );
      }),
      "execution client startup",
    );
    throwIfInterrupted();

    await settleAll(runtimes.map((runtime) => startConsensus(runtime)), "consensus client startup");
    throwIfInterrupted();

    if (isDevnet) {
      await settleAll(
        runtimes
          .filter(({ plan }) => plan.validatorCount > 0)
          .map(async (runtime) => {
            const consensus = requireSandbox(runtime, "consensus");
            const apiPort = runtime.plan.clType === "lighthouse" ? 4000 : 3500;
            runtime.validatorLogPath = `/home/user/${runtime.plan.id}-${runtime.plan.vcType}-vc.log`;
            runtime.validatorHandle = await consensus.sandbox.commands.run(
              command(
                validatorArgs(runtime.plan, `http://127.0.0.1:${apiPort}`),
                runtime.validatorLogPath,
              ),
              { background: true, timeoutMs: 0 },
            );
            await raceStartup(
              (signal) =>
                waitForHttp(
                  consensus.sandbox,
                  "http://127.0.0.1:8081/metrics",
                  `${runtime.plan.id} ${runtime.plan.vcType} validator metrics`,
                  signal,
                ),
              [
                failWhenProcessExits(runtime.gethHandle!, `${runtime.plan.id} Geth`),
                failWhenProcessExits(
                  runtime.consensusHandle!,
                  `${runtime.plan.id} ${runtime.plan.clType}`,
                ),
                failWhenProcessExits(
                  runtime.validatorHandle,
                  `${runtime.plan.id} ${runtime.plan.vcType} validator`,
                ),
                failOnInterruption(),
              ],
            );
          }),
        "validator client startup",
      );
      await raceStartup(
        (signal) =>
          waitForExecutionBlock(requireSandbox(runtimes[0]!, "geth").sandbox, signal),
        [
          ...runtimes.flatMap((runtime) => [
            failWhenProcessExits(runtime.gethHandle!, `${runtime.plan.id} Geth`),
            failWhenProcessExits(
              runtime.consensusHandle!,
              `${runtime.plan.id} ${runtime.plan.clType}`,
            ),
            ...(runtime.validatorHandle
              ? [
                  failWhenProcessExits(
                    runtime.validatorHandle,
                    `${runtime.plan.id} ${runtime.plan.vcType} validator`,
                  ),
                ]
              : []),
          ]),
          failOnInterruption(),
        ],
      );
    }

    for (const runtime of runtimes) {
      assertProcessRunning(runtime.gethHandle, `${runtime.plan.id} Geth`);
      assertProcessRunning(
        runtime.consensusHandle,
        `${runtime.plan.id} ${runtime.plan.clType}`,
      );
      if (runtime.plan.validatorCount > 0 && isDevnet) {
        assertProcessRunning(
          runtime.validatorHandle,
          `${runtime.plan.id} ${runtime.plan.vcType} validator`,
        );
      }
    }
    await Promise.all(
      runtimes.flatMap((runtime) => [
        runtime.gethHandle!.disconnect(),
        runtime.consensusHandle!.disconnect(),
        ...(runtime.validatorHandle ? [runtime.validatorHandle.disconnect()] : []),
      ]),
    );
    throwIfInterrupted();
    removeSignalHandlers();

    console.log(
      JSON.stringify(
        {
          network: topology.network,
          configuredTimeoutMinutes: options.timeoutMinutes,
          participantCount: topology.pairs.length,
          sandboxCount: topology.sandboxCount,
          ...(genesisTimestamp === undefined ? {} : { genesisTimestamp }),
          nodes: runtimes.map((runtime) => {
            const geth = requireSandbox(runtime, "geth");
            const consensus = requireSandbox(runtime, "consensus");
            const apiPort = runtime.plan.clType === "lighthouse" ? 4000 : 3500;
            const metricsPort = runtime.plan.clType === "lighthouse" ? 5054 : 8080;
            return {
              id: runtime.plan.id,
              participantIndex: runtime.plan.participantIndex,
              instance: runtime.plan.instance,
              execution: {
                client: "geth",
                sandboxId: geth.sandbox.sandboxId,
                rpcUrl: "http://127.0.0.1:8545",
                access: "sandbox-local via the E2B SDK",
                log: geth.logPath,
              },
              consensus: {
                client: runtime.plan.clType,
                sandboxId: consensus.sandbox.sandboxId,
                ...(isDevnet
                  ? {
                      apiUrl: `http://127.0.0.1:${apiPort}`,
                      metricsUrl: `http://127.0.0.1:${metricsPort}/metrics`,
                      access: "sandbox-local via the E2B SDK",
                    }
                  : {
                      trafficAccessToken: consensus.sandbox.trafficAccessToken,
                      apiUrl: `https://${consensus.sandbox.getHost(apiPort)}`,
                      metricsUrl: `https://${consensus.sandbox.getHost(metricsPort)}/metrics`,
                    }),
                log: consensus.logPath,
              },
              ...(runtime.validatorHandle
                ? {
                    validator: {
                      client: runtime.plan.vcType,
                      count: runtime.plan.validatorCount,
                      log: runtime.validatorLogPath,
                    },
                  }
                : {}),
            };
          }),
        },
        null,
        2,
      ),
    );
  } catch (error) {
    try {
      if (interruptedSignal !== undefined) {
        try {
          await cleanupSandboxes();
        } catch (cleanupError) {
          reportCleanupFailure(`after ${interruptedSignal}`, cleanupError);
        }
        process.exitCode = interruptedSignal === "SIGINT" ? 130 : 143;
        return;
      }

      const logTails = await Promise.all(
        managedSandboxes.map(async ({ pairId, client, sandbox, logPath }) => {
          const log = await sandbox.commands
            .run(`tail -c 4000 ${shellQuote(logPath)}`)
            .then(({ stdout }) => stdout)
            .catch(() => "");
          return { label: `${pairId} ${client}`, log };
        }),
      );
      try {
        await cleanupSandboxes();
      } catch (cleanupError) {
        reportCleanupFailure("after startup failure", cleanupError);
      }
      if (interruptedSignal !== undefined) {
        process.exitCode = interruptedSignal === "SIGINT" ? 130 : 143;
        return;
      }
      for (const { label, log } of logTails) {
        console.error(`${label} log:\n${log}`);
      }
      throw error;
    } finally {
      removeSignalHandlers();
    }
  }
}

await main();
