import fs from "node:fs";
import path from "node:path";
import { join } from "node:path";
import { dispatchAgentCommand } from "./agent.js";
import { listArtifactPaths, repoRoot } from "./config.js";
import { filterModes, loadModes } from "./modes.js";
import { runPlaytest } from "./playtest.js";
import { runScanEnvelopeTest } from "./scan-playtest.js";
import { loadRegistry } from "./registry.js";
import { runWhitelistedScript } from "./safe-exec.js";
import { readNexusState, writeBuildGateLog } from "./state.js";

export type ToolDispatchResult = {
  success: boolean;
  summary: string;
  payload?: Record<string, unknown>;
};

function readRepoFile(relativePath: unknown): ToolDispatchResult {
  const trimmed = String(relativePath ?? "").trim();
  if (!trimmed || trimmed.startsWith("/") || trimmed.includes("..")) {
    return {
      success: false,
      summary: "Path blocked — use repo-relative paths without traversal",
      payload: { error: "path_blocked", path: trimmed },
    };
  }
  const absolute = join(repoRoot(), trimmed);
  if (!absolute.startsWith(repoRoot())) {
    return {
      success: false,
      summary: "Resolved path escapes repo root",
      payload: { error: "path_escape", path: trimmed },
    };
  }
  if (!fs.existsSync(absolute)) {
    return {
      success: false,
      summary: `File not found: ${trimmed}`,
      payload: { error: "not_found", path: trimmed },
    };
  }
  const text = fs.readFileSync(absolute, "utf8");
  const maxBytes = 256 * 1024;
  if (Buffer.byteLength(text, "utf8") > maxBytes) {
    return {
      success: false,
      summary: `File exceeds ${maxBytes} byte read cap`,
      payload: { error: "too_large", path: trimmed },
    };
  }
  return {
    success: true,
    summary: `Read ${trimmed} (${text.length} chars)`,
    payload: {
      path: trimmed,
      bytes: Buffer.byteLength(text, "utf8"),
      content: text,
    },
  };
}

function handleListModes(args: Record<string, unknown>): ToolDispatchResult {
  const includePreview = args.include_preview !== false;
  const loaded = loadModes();
  const modes = filterModes(loaded.modes, {
    includePreview,
    release: typeof args.release === "string" ? args.release : undefined,
    tier: typeof args.tier === "string" ? args.tier : undefined,
    sprintOnly: args.sprint_only === true,
  });

  return {
    success: true,
    summary: `Listed ${modes.length} mode(s)`,
    payload: {
      totalRegistered: loaded.total,
      filteredCount: modes.length,
      include_preview: includePreview,
      capabilityDocUpdated: loaded.capabilityDocUpdated,
      sprint_p0_p1: ["basketball_dunk", "karate_endless"],
      repo_root: repoRoot(),
      modes,
    },
  };
}

async function handlePlaytest(
  args: Record<string, unknown>,
): Promise<ToolDispatchResult> {
  const modeId = String(args.mode_id ?? "").trim();
  if (!modeId) {
    return {
      success: false,
      summary: "Missing mode_id",
      payload: { error: "missing_mode_id" },
    };
  }

  const kind = args.kind === "bench" ? "bench" : "validate-only";
  const readiness = Number(args.readiness ?? 75);

  try {
    const stats = await runPlaytest({
      kind,
      mode: modeId,
      venue: typeof args.venue === "string" ? args.venue : undefined,
      durationSec:
        typeof args.duration_sec === "number" ? args.duration_sec : undefined,
      readiness,
    });

    return {
      success: stats.ok,
      summary: stats.ok
        ? `Playtest pass for ${modeId}`
        : `Playtest failed for ${modeId}`,
      payload: stats as unknown as Record<string, unknown>,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      success: false,
      summary: message,
      payload: { error: "playtest_failed", mode_id: modeId },
    };
  }
}


async function handleScanPlaytest(): Promise<ToolDispatchResult> {
  try {
    const stats = await runScanEnvelopeTest();
    return {
      success: stats.ok,
      summary: stats.ok
        ? "nexus_scan_envelope_test PASS"
        : "nexus_scan_envelope_test FAILED",
      payload: stats as unknown as Record<string, unknown>,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      success: false,
      summary: message,
      payload: {
        error: "scan_playtest_failed",
        doc: "docs/NEXUS_SCAN_TO_GENERATION.md",
        buildHint:
          "cmake --build build-headless --target nexus_scan_envelope_test",
      },
    };
  }
}

async function handleBuildGate(
  args: Record<string, unknown>,
): Promise<ToolDispatchResult> {
  const target = args.target === "validate_only" ? "validate_only" : "full_gate";
  const script =
    target === "validate_only"
      ? "scripts/nexus_validate_production_modes.sh"
      : "scripts/nexus_build_gate.sh";
  const timeoutMinutes =
    typeof args.timeout_minutes === "number" ? args.timeout_minutes : 45;

  try {
    const result = await runWhitelistedScript(script, [], {
      timeoutMs: timeoutMinutes * 60_000,
    });

    if (target === "full_gate") {
      writeBuildGateLog(result.stdout, result.stderr);
    }

    return {
      success: result.ok,
      summary: result.ok
        ? `${script} PASS`
        : `${script} FAILED (exit ${result.exitCode ?? "unknown"})`,
      payload: {
        target,
        ok: result.ok,
        exitCode: result.exitCode,
        durationMs: result.durationMs,
        command: result.command,
        stdout: result.stdout,
        stderr: result.stderr,
      },
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      success: false,
      summary: message,
      payload: { error: "build_gate_failed", target },
    };
  }
}

function handleListArtifacts(): ToolDispatchResult {
  const paths = listArtifactPaths();
  const entries = Object.entries(paths).map(([key, absolutePath]) => ({
    key,
    absolute_path: absolutePath,
    repo_relative: absolutePath.startsWith(repoRoot())
      ? path.relative(repoRoot(), absolutePath)
      : absolutePath,
    exists: fs.existsSync(absolutePath),
  }));

  return {
    success: true,
    summary: `Listed ${entries.length} artifact path(s)`,
    payload: {
      repo_root: repoRoot(),
      artifacts: entries,
      cursor_read_paths: {
        playtest: "artifacts/playtest/latest.json",
        hud_snapshot: "artifacts/cursor-nexus/last-hud-snapshot.json",
        dev_stats_tick: "artifacts/playtest/dev_stats_tick.json",
      },
    },
  };
}

function handleReadState(): ToolDispatchResult {
  const state = readNexusState();
  return {
    success: true,
    summary: "NEXUS repo state snapshot",
    payload: state as unknown as Record<string, unknown>,
  };
}

async function handleAgentCommand(
  args: Record<string, unknown>,
): Promise<ToolDispatchResult> {
  const registry = loadRegistry();
  const tool = String(args.tool ?? "").trim();
  const routes = registry.tools.agent_command?.routes_to ?? [];

  if (!tool || !routes.includes(tool)) {
    return {
      success: false,
      summary: `Tool '${tool}' is not whitelisted for agent_command`,
      payload: { error: "not_whitelisted", tool, routes_to: routes },
    };
  }

  const nested =
    args.arguments && typeof args.arguments === "object"
      ? (args.arguments as Record<string, unknown>)
      : {};

  const result = await dispatchTool(tool, nested);
  return {
    ...result,
    summary: `[agent_command → ${tool}] ${result.summary}`,
    payload: { routed_tool: tool, ...(result.payload ?? {}) },
  };
}

export async function dispatchTool(
  name: string,
  args: Record<string, unknown> = {},
): Promise<ToolDispatchResult> {
  switch (name) {
    case "list_modes":
      return handleListModes(args);
    case "playtest":
    case "launch_mode":
    case "studio_run_playtest":
      return handlePlaytest(args);
    case "build_gate":
    case "run_build_gate":
      return handleBuildGate(args);
    case "nexus_scan_playtest":
      return handleScanPlaytest();
    case "read_state":
      return handleReadState();
    case "list_artifacts":
      return handleListArtifacts();
    case "read_file":
      return readRepoFile(args.path);
    case "open_ide_file":
    case "studio_open_file": {
      const read = readRepoFile(args.path);
      if (!read.success) {
        return read;
      }
      const line = args.line ? `:${args.line}` : "";
      const relativePath = String(args.path ?? "").trim();
      return {
        success: true,
        summary: `Surfaced ${relativePath}${line}`,
        payload: {
          relative_path: relativePath,
          absolute_path: join(repoRoot(), relativePath),
          cursor_uri: `cursor://file/${join(repoRoot(), relativePath)}${line}`,
        },
      };
    }
    case "creative_command":
      return {
        success: false,
        summary: "creative_command requires in-app C++ bridge — use iOS Agent tab",
        payload: {
          blocked_reason: "host_only_in_ios_app",
          command: args.command,
        },
      };
    case "scan_to_generate":
      return {
        success: false,
        summary: "scan_to_generate requires in-app ScanToGenerationBridge — use iOS Agent tab",
        payload: { blocked_reason: "host_only_in_ios_app" },
      };
    case "generate_game": {
      const text = String(args.text ?? "").trim();
      if (!text) {
        return {
          success: false,
          summary: "Missing text prompt",
          payload: { error: "missing_text" },
        };
      }
      const refine = args.refine === true;
      const command = refine ? "fel.generate.refine_game" : "fel.generate.game";
      return dispatchAgentCliCommand({
        command: {
          type: "command",
          id: "mcp_generate_game",
          payload: {
            command,
            params: {
              text,
              include_arena: args.include_arena === true,
              start_session: args.start_session !== false,
              force_template: args.force_template === true,
              user_id: "cursor_mcp",
            },
          },
        },
      });
    }
    case "agent_command":
      return handleAgentCommand(args);
    default:
      return {
        success: false,
        summary: `Unknown or blocked tool '${name}'`,
        payload: { error: "unknown_tool", tool: name },
      };
  }
}

export async function dispatchAgentCliCommand(
  args: Record<string, unknown>,
): Promise<ToolDispatchResult> {
  const command = args.command;
  if (!command || (typeof command !== "object" && !Array.isArray(command))) {
    return {
      success: false,
      summary: "Missing command envelope",
      payload: { error: "missing_command" },
    };
  }

  const result = await dispatchAgentCommand(
    command as Record<string, unknown> | Record<string, unknown>[],
  );

  return {
    success: result.ok,
    summary: result.ok ? "Agent command accepted" : (result.error ?? "Agent command failed"),
    payload: {
      responses: result.responses,
      raw: result.raw,
      error: result.error,
    },
  };
}
