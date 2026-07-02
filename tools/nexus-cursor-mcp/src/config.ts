import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const DEFAULT_REPO = path.join(os.homedir(), "Final-Evolution-Lab");

export function repoRoot(): string {
  for (const key of ["NEXUS_REPO_ROOT", "FEL_NEXUS_REPO_ROOT"]) {
    const fromEnv = process.env[key]?.trim();
    if (fromEnv && fs.existsSync(fromEnv)) {
      return path.resolve(fromEnv);
    }
  }
  return DEFAULT_REPO;
}

export function artifactDir(): string {
  return path.join(repoRoot(), "artifacts", "cursor-nexus");
}

export function ensureArtifactDir(): string {
  const dir = artifactDir();
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

export function buildGateLogPath(): string {
  return path.join(ensureArtifactDir(), "last-build-gate.log");
}

export function playtestArtifactPath(): string {
  return path.join(repoRoot(), "artifacts", "playtest", "latest.json");
}

export function cursorPlaytestMirrorPath(): string {
  return path.join(ensureArtifactDir(), "last-playtest.json");
}

export function hudSnapshotPath(): string {
  return path.join(ensureArtifactDir(), "last-hud-snapshot.json");
}

export function devStatsTickPath(): string {
  return path.join(repoRoot(), "artifacts", "playtest", "dev_stats_tick.json");
}

export function listArtifactPaths(): Record<string, string> {
  return {
    playtest_latest: playtestArtifactPath(),
    playtest_mirror: cursorPlaytestMirrorPath(),
    hud_snapshot: hudSnapshotPath(),
    dev_stats_tick: devStatsTickPath(),
    build_gate_log: buildGateLogPath(),
    delivery_matrix: deliveryMatrixPath(),
    tool_registry: registryPath(),
  };
}

export function deliveryMatrixPath(): string {
  return path.join(repoRoot(), "NEXUS_DELIVERY_MATRIX.md");
}

export function modesCapabilityPath(): string {
  return path.join(repoRoot(), "docs", "NEXUS_MODES_CAPABILITY.md");
}

export function arenaRegistryPath(): string {
  return path.join(repoRoot(), "app", "gameplay", "src", "arena_mode_registry.cpp");
}

export function registryPath(): string {
  return path.join(repoRoot(), "Config", "nexus_cursor_tool_registry.json");
}

export function ctestLogCandidates(): string[] {
  const root = repoRoot();
  return [
    path.join(root, "build-headless", "Testing", "Temporary", "LastTest.log"),
    path.join(root, "build-full", "Testing", "Temporary", "LastTest.log"),
  ];
}
