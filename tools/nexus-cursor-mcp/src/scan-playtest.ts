import { runWhitelistedScript } from "./safe-exec.js";

export type ScanPlaytestStats = {
  ok: boolean;
  exitCode: number | null;
  durationMs: number;
  command: string;
  stdout: string;
  stderr: string;
  doc: string;
  buildHint: string;
};

export async function runScanEnvelopeTest(
  options: { timeoutMs?: number } = {},
): Promise<ScanPlaytestStats> {
  const result = await runWhitelistedScript("nexus_scan_envelope_test", [], {
    timeoutMs: options.timeoutMs ?? 60_000,
  });

  return {
    ok: result.ok,
    exitCode: result.exitCode,
    durationMs: result.durationMs,
    command: result.command,
    stdout: result.stdout,
    stderr: result.stderr,
    doc: "docs/NEXUS_SCAN_TO_GENERATION.md",
    buildHint:
      "cmake --build build-headless --target nexus_scan_envelope_test",
  };
}
