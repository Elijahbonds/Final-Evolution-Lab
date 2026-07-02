import fs from "node:fs";
import {
  buildGateLogPath,
  ctestLogCandidates,
  cursorPlaytestMirrorPath,
  deliveryMatrixPath,
  ensureArtifactDir,
  playtestArtifactPath,
  repoRoot,
} from "./config.js";

export type NexusState = {
  repoRoot: string;
  deliveryMatrixSummary: {
    path: string;
    auditDate?: string;
    preflightRows: Array<{ script: string; result: string }>;
    phaseHighlights: Array<{ phase: string; status: string }>;
    dodScore?: string;
  };
  buildLogs: {
    lastBuildGateLog?: string;
    lastBuildGateTail?: string;
    ctestLogs: Array<{ path: string; exists: boolean; tail?: string }>;
  };
  lastPlaytest?: unknown;
};

function tailText(filePath: string, maxLines = 40): string | undefined {
  if (!fs.existsSync(filePath)) {
    return undefined;
  }
  const lines = fs.readFileSync(filePath, "utf8").split("\n");
  return lines.slice(-maxLines).join("\n");
}

function parseDeliveryMatrix(source: string): NexusState["deliveryMatrixSummary"] {
  const auditDate = source.match(/\*\*Audit date:\*\*\s*(.+)/)?.[1]?.trim();
  const preflightRows: Array<{ script: string; result: string }> = [];
  for (const match of source.matchAll(
    /\|\s*`([^`]+)`\s*\|\s*\*\*([^*|]+)\*\*\s*\|/g,
  )) {
    if (match[1].startsWith("./scripts/")) {
      preflightRows.push({ script: match[1], result: match[2].trim() });
    }
  }

  const phaseHighlights: Array<{ phase: string; status: string }> = [];
  for (const match of source.matchAll(
    /\|\s*\*\*(\d+)\*\*\s*\|\s*[^|]+\|\s*\*\*([^*|]+)\*\*\s*\|\s*\*\*([^*|]+)\*\*\s*\|/g,
  )) {
    phaseHighlights.push({ phase: match[1], status: match[3].trim() });
  }

  const dodScore = source.match(/\*\*DoD score:\*\*\s*(.+)/)?.[1]?.trim();

  return {
    path: deliveryMatrixPath(),
    auditDate,
    preflightRows: preflightRows.slice(0, 6),
    phaseHighlights: phaseHighlights.slice(0, 10),
    dodScore,
  };
}

export function readNexusState(): NexusState {
  ensureArtifactDir();

  const matrixPath = deliveryMatrixPath();
  const matrixSource = fs.existsSync(matrixPath)
    ? fs.readFileSync(matrixPath, "utf8")
    : "";

  const buildGateLog = buildGateLogPath();
  const ctestLogs = ctestLogCandidates().map((logPath) => ({
    path: logPath,
    exists: fs.existsSync(logPath),
    tail: tailText(logPath, 30),
  }));

  let lastPlaytest: unknown;
  const primaryPlaytest = playtestArtifactPath();
  const mirrorPlaytest = cursorPlaytestMirrorPath();
  const playtestPath = fs.existsSync(primaryPlaytest)
    ? primaryPlaytest
    : fs.existsSync(mirrorPlaytest)
      ? mirrorPlaytest
      : undefined;
  if (playtestPath) {
    try {
      lastPlaytest = JSON.parse(fs.readFileSync(playtestPath, "utf8"));
    } catch {
      lastPlaytest = { error: "Could not parse playtest artifact", path: playtestPath };
    }
  }

  return {
    repoRoot: repoRoot(),
    deliveryMatrixSummary: parseDeliveryMatrix(matrixSource),
    buildLogs: {
      lastBuildGateLog: fs.existsSync(buildGateLog) ? buildGateLog : undefined,
      lastBuildGateTail: tailText(buildGateLog, 50),
      ctestLogs,
    },
    lastPlaytest,
  };
}

export function writeBuildGateLog(stdout: string, stderr: string): void {
  const content = `# nexus_build_gate\n# finished: ${new Date().toISOString()}\n\n${stdout}\n\n--- stderr ---\n${stderr}\n`;
  fs.writeFileSync(buildGateLogPath(), content);
}
