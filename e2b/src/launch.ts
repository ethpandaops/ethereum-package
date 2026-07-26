import { randomBytes } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";

import { Sandbox, type CommandHandle } from "e2b";

import { gethArgs, lighthouseArgs, parseOptions } from "./config.js";

const template = process.env.E2B_TEMPLATE ?? "ethereum-lighthouse-geth";
const jwtPath = "/home/user/ethereum/jwt.hex";

type ClientRole = "geth" | "lighthouse";
type InterruptSignal = "SIGINT" | "SIGTERM";

interface ManagedSandbox {
  role: ClientRole;
  sandbox: Sandbox;
  logPath: string;
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

function assertProcessRunning(handle: CommandHandle, label: string): void {
  if (handle.exitCode !== undefined) {
    throw new Error(
      `${label} exited before startup completed (exit code ${handle.exitCode})`,
    );
  }
}

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  const jwt = randomBytes(32).toString("hex");
  const managedSandboxes: ManagedSandbox[] = [];
  let cleanupPromise: Promise<void> | undefined;
  let cleanupFailureReported = false;
  let interruptedSignal: InterruptSignal | undefined;
  const { promise: interruption, resolve: resolveInterruption } =
    Promise.withResolvers<InterruptSignal>();

  const cleanupSandboxes = (): Promise<void> => {
    cleanupPromise ??= Promise.all(
      managedSandboxes.map(async ({ role, sandbox }) => {
        const killed = await Sandbox.kill(sandbox.sandboxId);
        if (!killed) {
          throw new Error(`${role} sandbox ${sandbox.sandboxId} was not running`);
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
      .map(({ role, sandbox }) => `${role}=${sandbox.sandboxId}`)
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

  process.once("SIGINT", handleSigint);
  process.once("SIGTERM", handleSigterm);

  try {
    const gethSandbox = await Sandbox.create(template, {
      timeoutMs: options.timeoutMinutes * 60_000,
      allowInternetAccess: true,
      network: { allowPublicTraffic: true },
      metadata: {
        application: "ethereum-package",
        client: "geth",
        network: options.network,
      },
    });
    managedSandboxes.push({
      role: "geth",
      sandbox: gethSandbox,
      logPath: "/home/user/geth.log",
    });
    throwIfInterrupted();

    await gethSandbox.files.write(jwtPath, jwt);
    throwIfInterrupted();
    const gethHandle = await gethSandbox.commands.run(
      command(gethArgs(options.network, jwtPath), "/home/user/geth.log"),
      { background: true, timeoutMs: 0 },
    );
    const gethExit = failWhenProcessExits(gethHandle, "Geth");
    await Promise.race([
      waitForHttp(gethSandbox, "http://127.0.0.1:8545", "geth RPC"),
      gethExit,
      failOnInterruption(),
    ]);

    throwIfInterrupted();
    const executionEndpoint = `https://${gethSandbox.getHost(8551)}`;
    const lighthouseSandbox = await Sandbox.create(template, {
      timeoutMs: options.timeoutMinutes * 60_000,
      allowInternetAccess: true,
      network: { allowPublicTraffic: false },
      metadata: {
        application: "ethereum-package",
        client: "lighthouse",
        network: options.network,
      },
    });
    managedSandboxes.push({
      role: "lighthouse",
      sandbox: lighthouseSandbox,
      logPath: "/home/user/lighthouse.log",
    });
    throwIfInterrupted();

    await lighthouseSandbox.files.write(jwtPath, jwt);
    throwIfInterrupted();
    const lighthouseHandle = await lighthouseSandbox.commands.run(
      command(
        lighthouseArgs(
          options.network,
          jwtPath,
          executionEndpoint,
          options.checkpointUrl,
        ),
        "/home/user/lighthouse.log",
      ),
      { background: true, timeoutMs: 0 },
    );
    const lighthouseExit = failWhenProcessExits(lighthouseHandle, "Lighthouse");
    await Promise.race([
      waitForHttp(
        lighthouseSandbox,
        "http://127.0.0.1:4000/eth/v1/node/health",
        "Lighthouse HTTP API",
      ),
      gethExit,
      lighthouseExit,
      failOnInterruption(),
    ]);

    throwIfInterrupted();
    assertProcessRunning(gethHandle, "Geth");
    assertProcessRunning(lighthouseHandle, "Lighthouse");
    await Promise.all([gethHandle.disconnect(), lighthouseHandle.disconnect()]);
    throwIfInterrupted();
    removeSignalHandlers();

    console.log(
      JSON.stringify(
        {
          network: options.network,
          configuredTimeoutMinutes: options.timeoutMinutes,
          geth: {
            sandboxId: gethSandbox.sandboxId,
            rpcUrl: "http://127.0.0.1:8545",
            access: "sandbox-local via the E2B SDK",
            log: "/home/user/geth.log",
          },
          lighthouse: {
            sandboxId: lighthouseSandbox.sandboxId,
            trafficAccessToken: lighthouseSandbox.trafficAccessToken,
            apiUrl: `https://${lighthouseSandbox.getHost(4000)}`,
            metricsUrl: `https://${lighthouseSandbox.getHost(5054)}/metrics`,
            log: "/home/user/lighthouse.log",
          },
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
      managedSandboxes.map(async ({ role, sandbox, logPath }) => {
        const log = await sandbox.commands
          .run(`tail -c 4000 '${logPath}'`)
          .then(({ stdout }) => stdout)
          .catch(() => "");
        return { role, log };
      }),
    );
    try {
      await cleanupSandboxes();
    } catch (cleanupError) {
      reportCleanupFailure("after startup failure", cleanupError);
    }
    for (const { role, log } of logTails) {
      console.error(`${role} log:\n${log}`);
    }
    throw error;
  }
}

await main();
