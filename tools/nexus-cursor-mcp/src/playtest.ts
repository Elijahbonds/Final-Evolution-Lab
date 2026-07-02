import fs from "node:fs";
import path from "node:path";
import {
  cursorPlaytestMirrorPath,
  devStatsTickPath,
  hudSnapshotPath,
  repoRoot,
} from "./config.js";
import { runWhitelistedScript } from "./safe-exec.js";

export type PlaytestStats = {
  kind: "validate-only" | "bench" | "full";
  mode: string;
  venue: string;
  readiness?: number;
  ok: boolean;
  exitCode: number | null;
  durationMs: number;
  artifactPath: string;
  hudSnapshotPath?: string;
  snapshot?: unknown;
  rawStdout: string;
  rawStderr: string;
};

const PLAYTEST_JSON = path.join(repoRoot(), "artifacts", "playtest", "latest.json");

export async function runPlaytest(options: {
  kind: "validate-only" | "bench";
  mode: string;
  venue?: string;
  durationSec?: number;
  readiness?: number;
  skipBuild?: boolean;
  timeoutMs?: number;
}): Promise<PlaytestStats> {
  const venue = options.venue ?? "venice_beach";
  const durationSec =
    options.kind === "validate-only" ? 0 : (options.durationSec ?? 10);

  const args = [
    "--mode",
    options.mode,
    "--venue",
    venue,
    "--duration",
    String(durationSec),
  ];
  if (options.skipBuild !== false) {
    args.push("--skip-build");
  }

  const timeoutMs =
    options.timeoutMs ??
    (durationSec > 0 ? durationSec * 1000 + 300_000 : 180_000);

  const result = await runWhitelistedScript("scripts/nexus_playtest.sh", args, {
    env: {
      NEXUS_PLAYTEST_MODE: options.mode,
      NEXUS_PLAYTEST_VENUE: venue,
      NEXUS_PLAYTEST_DURATION: String(durationSec),
      BUILD_DIR: process.env.NEXUS_RUNTIME_BUILD_DIR?.trim() || "build-full",
    },
    timeoutMs,
  });

  let snapshot: unknown;
  if (fs.existsSync(PLAYTEST_JSON)) {
    try {
      snapshot = JSON.parse(fs.readFileSync(PLAYTEST_JSON, "utf8"));
      fs.mkdirSync(path.dirname(cursorPlaytestMirrorPath()), { recursive: true });
      fs.writeFileSync(cursorPlaytestMirrorPath(), JSON.stringify(snapshot, null, 2));
    } catch {
      snapshot = { error: "Could not parse artifacts/playtest/latest.json" };
    }
  }

  const tickPath = devStatsTickPath();
  if (fs.existsSync(tickPath)) {
    try {
      fs.mkdirSync(path.dirname(hudSnapshotPath()), { recursive: true });
      fs.copyFileSync(tickPath, hudSnapshotPath());
    } catch {
      // Best-effort HUD snapshot mirror for Cursor.
    }
  }

  const overallOk = Boolean(
    snapshot &&
      typeof snapshot === "object" &&
      "overall_status" in snapshot &&
      (snapshot as { overall_status: string }).overall_status === "pass",
  );

  return {
    kind: durationSec > 0 ? "bench" : "validate-only",
    mode: options.mode,
    venue,
    readiness: options.readiness,
    ok: result.ok && overallOk,
    exitCode: result.exitCode,
    durationMs: result.durationMs,
    artifactPath: PLAYTEST_JSON,
    hudSnapshotPath: fs.existsSync(hudSnapshotPath()) ? hudSnapshotPath() : undefined,
    snapshot,
    rawStdout: result.stdout,
    rawStderr: result.stderr,
  };
}
