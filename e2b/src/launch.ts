import { randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { setTimeout as delay } from "node:timers/promises";

import { Sandbox, type CommandHandle } from "e2b";

import {
  defaultCheckpointUrls,
  gethArgs,
  lighthouseArgs,
  parseOptions,
  prysmArgs,
} from "./config.js";
import { parseTopology, type ConsensusClient, type NodePair } from "./topology.js";

const template = process.env.E2B_TEMPLATE ?? "ethereum-client-topology";
const jwtPath = "/home/user/ethereum/jwt.hex";

type InterruptSignal = "SIGINT" | "SIGTERM";
type ClientLayer = "el" | "cl";

interface ManagedSandbox {
  pairId: string;
  layer: ClientLayer;
  client: "geth" | ConsensusClient;
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
}

function command(args: string[], logPath: string): string {
  const quoted = args.map((arg) => `'${arg.replaceAll("'", `'\"'\"'`)}'`).join(" ");
  return `${quoted} > '${logPath}' 2>&1`;
}

async function waitForHttp(sandbox: Sandbox, url: string, label: string): Promise<void> {
  const deadline = Date.now() + 120_000;
  while (true) {
    const remainingMs = deadline - Date.now();
    if (remainingMs <= 0) {
      break;
    }

    try {
      await sandbox.commands.run(`curl --fail --silent '${url}' >/dev/null`, {
        timeoutMs: Math.min(5_000, remainingMs),
      });
      return;
    } catch {
      const updatedRemainingMs = deadline - Date.now();
      if (updatedRemainingMs <= 0) {
        break;
      }
      await delay(Math.min(2_000, updatedRemainingMs));
    }
  }
  throw new Error(`${label} did not become ready within 120 seconds`);
}

function failWhenProcessExits(handle: CommandHandle, label: string): Promise<never> {
  return handle.wait().then(
    ({ exitCode }) => {
      throw new Error(`${label} exited before startup completed (exit code ${exitCode})`);
    },
    (error: unknown) => {
      const exitCode =
        handle.exitCode === undefined ? "" : ` (exit code ${handle.exitCode})`;
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

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const source = options.configPath ? await readFile(options.configPath, "utf8") : undefined;
  const defaultNetwork = options.network ?? "hoodi";
  const topology = source
    ? parseTopology(source, options.network)
    : parseTopology(
        `network_params:\n  network: ${defaultNetwork}\nparticipants:\n  - el_type: geth\n    cl_type: lighthouse\n`,
      );
  const checkpointUrl = options.checkpointUrl ?? defaultCheckpointUrls[topology.network];
  const runtimes: PairRuntime[] = topology.pairs.map((plan) => ({
    plan,
    jwt: randomBytes(32).toString("hex"),
  }));
  const managedSandboxes: ManagedSandbox[] = [];
  let cleanupPromise: Promise<void> | undefined;
  let cleanupFailureReported = false;
  let interruptedSignal: InterruptSignal | undefined;
  const { promise: interruption, resolve: resolveInterruption } =
    Promise.withResolvers<InterruptSignal>();

  const cleanupSandboxes = (): Promise<void> => {
    cleanupPromise ??= Promise.all(
      managedSandboxes.map(async ({ pairId, layer, sandbox }) => {
        const killed = await Sandbox.kill(sandbox.sandboxId);
        if (!killed) {
          throw new Error(`${pairId} ${layer} sandbox ${sandbox.sandboxId} was not running`);
        }
      }),
    ).then(() => undefined);
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
    runtime: PairRuntime,
    layer: ClientLayer,
    client: "geth" | ConsensusClient,
    allowPublicTraffic: boolean,
  ): Promise<ManagedSandbox> {
    const sandbox = await Sandbox.create(template, {
      timeoutMs: options.timeoutMinutes * 60_000,
      allowInternetAccess: true,
      network: { allowPublicTraffic },
      metadata: {
        application: "ethereum-package",
        network: topology.network,
        participant: runtime.plan.id,
        layer,
        client,
      },
    });
    const managed = {
      pairId: runtime.plan.id,
      layer,
      client,
      sandbox,
      logPath: `/home/user/${runtime.plan.id}-${client}.log`,
    } satisfies ManagedSandbox;
    managedSandboxes.push(managed);
    return managed;
  }

  process.once("SIGINT", handleSigint);
  process.once("SIGTERM", handleSigterm);

  try {
    await settleAll(
      runtimes.map(async (runtime) => {
        runtime.geth = await createSandbox(runtime, "el", "geth", true);
      }),
      "execution sandbox creation",
    );
    throwIfInterrupted();

    await settleAll(
      runtimes.map(async (runtime) => {
        const geth = runtime.geth;
        if (!geth) {
          throw new Error(`${runtime.plan.id} has no execution sandbox`);
        }
        await geth.sandbox.files.write(jwtPath, runtime.jwt);
        throwIfInterrupted();
        runtime.gethHandle = await geth.sandbox.commands.run(
          command(gethArgs(topology.network, jwtPath), geth.logPath),
          { background: true, timeoutMs: 0 },
        );
        await Promise.race([
          waitForHttp(
            geth.sandbox,
            "http://127.0.0.1:8545",
            `${runtime.plan.id} geth RPC`,
          ),
          failWhenProcessExits(runtime.gethHandle, `${runtime.plan.id} Geth`),
          failOnInterruption(),
        ]);
      }),
      "execution client startup",
    );
    throwIfInterrupted();

    await settleAll(
      runtimes.map(async (runtime) => {
        runtime.consensus = await createSandbox(
          runtime,
          "cl",
          runtime.plan.clType,
          false,
        );
      }),
      "consensus sandbox creation",
    );
    throwIfInterrupted();

    await settleAll(
      runtimes.map(async (runtime) => {
        const geth = runtime.geth;
        const consensus = runtime.consensus;
        if (!geth || !consensus) {
          throw new Error(`${runtime.plan.id} is missing a client sandbox`);
        }
        const executionEndpoint = `https://${geth.sandbox.getHost(8551)}`;
        const args =
          runtime.plan.clType === "lighthouse"
            ? lighthouseArgs(topology.network, jwtPath, executionEndpoint, checkpointUrl)
            : prysmArgs(topology.network, jwtPath, executionEndpoint, checkpointUrl);
        const apiPort = runtime.plan.clType === "lighthouse" ? 4000 : 3500;
        await consensus.sandbox.files.write(jwtPath, runtime.jwt);
        throwIfInterrupted();
        runtime.consensusHandle = await consensus.sandbox.commands.run(
          command(args, consensus.logPath),
          { background: true, timeoutMs: 0 },
        );
        await Promise.race([
          waitForHttp(
            consensus.sandbox,
            `http://127.0.0.1:${apiPort}/eth/v1/node/health`,
            `${runtime.plan.id} ${runtime.plan.clType} HTTP API`,
          ),
          failWhenProcessExits(runtime.gethHandle!, `${runtime.plan.id} Geth`),
          failWhenProcessExits(
            runtime.consensusHandle,
            `${runtime.plan.id} ${runtime.plan.clType}`,
          ),
          failOnInterruption(),
        ]);
      }),
      "consensus client startup",
    );
    throwIfInterrupted();

    for (const runtime of runtimes) {
      assertProcessRunning(runtime.gethHandle, `${runtime.plan.id} Geth`);
      assertProcessRunning(
        runtime.consensusHandle,
        `${runtime.plan.id} ${runtime.plan.clType}`,
      );
    }
    await Promise.all(
      runtimes.flatMap((runtime) => [
        runtime.gethHandle!.disconnect(),
        runtime.consensusHandle!.disconnect(),
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
          nodes: runtimes.map((runtime) => {
            const geth = runtime.geth!;
            const consensus = runtime.consensus!;
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
                trafficAccessToken: consensus.sandbox.trafficAccessToken,
                apiUrl: `https://${consensus.sandbox.getHost(apiPort)}`,
                metricsUrl: `https://${consensus.sandbox.getHost(metricsPort)}/metrics`,
                log: consensus.logPath,
              },
            };
          }),
        },
        null,
        2,
      ),
    );
  } catch (error) {
    removeSignalHandlers();
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
          .run(`tail -c 4000 '${logPath}'`)
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
    for (const { label, log } of logTails) {
      console.error(`${label} log:\n${log}`);
    }
    throw error;
  }
}

await main();
