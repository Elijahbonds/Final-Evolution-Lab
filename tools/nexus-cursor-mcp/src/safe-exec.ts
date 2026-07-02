import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { repoRoot } from "./config.js";

/** Whitelisted scripts/binaries only — no arbitrary shell. */
const ALLOWED_SCRIPTS = new Set([
  "scripts/nexus_build_gate.sh",
  "scripts/bench_nexus_runtime.sh",
  "scripts/nexus_playtest.sh",
  "scripts/nexus_validate_production_modes.sh",
]);

const ALLOWED_BINARIES = new Set([
  "nexus_agent_cli",
  "nexus_runtime",
  "nexus_scan_envelope_test",
]);

export type ExecResult = {
  ok: boolean;
  exitCode: number | null;
  stdout: string;
  stderr: string;
  command: string;
  durationMs: number;
};

function resolveWhitelistedTarget(relativePath: string): string {
  const normalized = relativePath.replace(/\\/g, "/").replace(/^\/+/, "");
  if (ALLOWED_SCRIPTS.has(normalized)) {
    const absolute = path.join(repoRoot(), normalized);
    if (!fs.existsSync(absolute)) {
      throw new Error(`Whitelisted script missing: ${normalized}`);
    }
    return absolute;
  }

  const base = path.basename(normalized);
  if (ALLOWED_BINARIES.has(base)) {
    const buildDir = process.env.NEXUS_BUILD_DIR?.trim() || "build-headless";
    const absolute = path.join(repoRoot(), buildDir, base);
    if (!fs.existsSync(absolute)) {
      throw new Error(
        `${base} not built — run cmake build in ${buildDir} first`,
      );
    }
    return absolute;
  }

  throw new Error(
    `Blocked: "${relativePath}" is not whitelisted. Allowed scripts: ${[...ALLOWED_SCRIPTS].join(", ")}`,
  );
}

export async function runWhitelistedScript(
  relativeScript: string,
  args: string[] = [],
  options: {
    env?: Record<string, string>;
    cwd?: string;
    timeoutMs?: number;
    stdin?: string;
  } = {},
): Promise<ExecResult> {
  const executable = resolveWhitelistedTarget(relativeScript);
  const cwd = options.cwd ?? repoRoot();
  const started = Date.now();

  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, {
      cwd,
      env: { ...process.env, ...options.env },
      stdio: ["pipe", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    let timedOut = false;

    const timer =
      options.timeoutMs && options.timeoutMs > 0
        ? setTimeout(() => {
            timedOut = true;
            child.kill("SIGTERM");
          }, options.timeoutMs)
        : undefined;

    child.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });

    if (options.stdin) {
      child.stdin.write(options.stdin);
    }
    child.stdin.end();

    child.on("error", (error) => {
      if (timer) clearTimeout(timer);
      reject(error);
    });

    child.on("close", (code) => {
      if (timer) clearTimeout(timer);
      resolve({
        ok: !timedOut && code === 0,
        exitCode: timedOut ? null : code,
        stdout,
        stderr,
        command: [executable, ...args].join(" "),
        durationMs: Date.now() - started,
      });
    });
  });
}

export async function runAgentCli(jsonPayload: string): Promise<ExecResult> {
  return runWhitelistedScript("nexus_agent_cli", ["--json", jsonPayload], {
    timeoutMs: 30_000,
  });
}
