/**
 * CELL Agent — Zero-Cost Local AI Agent (MCP handler)
 *
 * Exposes cell.agent_run and cell.agent_status commands through the MCP
 * surface.  All inference is local — no token APIs, no per-query cost.
 * The agent uses NEXUS WisdomStore heuristics + git/terminal/IDE tools
 * in a ReAct loop to execute developer tasks.
 *
 * Routing:
 *   cell_agent        → cell.agent_run  command  (submit task to swarm)
 *   cell_agent_status → cell.agent_status query  (swarm health)
 *   cell_agent_result → cell.agent_result query  (poll completed task)
 */

import { dispatchAgentCommand } from "./agent.js";

/** Matches ToolDispatchResult in dispatch.ts — inlined to avoid circular import. */
type ToolDispatchResult = {
  success: boolean;
  summary: string;
  payload?: Record<string, unknown>;
};

// ── cell_agent ────────────────────────────────────────────────────────────────

export async function handleCellAgent(
  args: Record<string, unknown>,
): Promise<ToolDispatchResult> {
  const prompt = String(args.prompt ?? "").trim();
  if (!prompt) {
    return {
      success: false,
      summary: "Missing prompt",
      payload: { error: "missing_prompt" },
    };
  }

  const tools: string[] =
    Array.isArray(args.tools)
      ? (args.tools as string[]).filter((t) => typeof t === "string")
      : ["git", "terminal", "ide_file"];

  const task_id =
    typeof args.task_id === "string" && args.task_id.trim()
      ? args.task_id.trim()
      : "";

  const max_steps =
    typeof args.max_steps === "number" ? Math.max(1, Math.min(args.max_steps, 20)) : 10;

  const commandPayload = {
    type: "command",
    id: task_id || `mcp_agent_${Date.now()}`,
    payload: {
      command: "cell.agent_run",
      params: {
        prompt,
        tools,
        task_id,
        max_steps,
        wisdom_weight:
          typeof args.wisdom_weight === "number" ? args.wisdom_weight : 0.6,
      },
    },
  };

  const result = await dispatchAgentCommand(commandPayload);

  if (!result.ok) {
    return {
      success: false,
      summary: result.error ?? "cell.agent_run failed",
      payload: { error: result.error, raw: result.raw },
    };
  }

  const responses = Array.isArray(result.responses) ? result.responses : [];
  const first = responses[0] ?? {};
  const payload = (first as Record<string, unknown>).payload ?? {};

  const returned_task_id =
    typeof (payload as Record<string, unknown>).task_id === "string"
      ? (payload as Record<string, unknown>).task_id
      : task_id || commandPayload.id;

  return {
    success: true,
    summary: `Agent task submitted — task_id=${returned_task_id}. Poll with cell_agent_result.`,
    payload: {
      task_id: returned_task_id,
      prompt,
      tools,
      max_steps,
      note: "Zero-cost local agent — no tokens consumed. Results available via cell_agent_result.",
      ...(payload as Record<string, unknown>),
    },
  };
}

// ── cell_agent_status ─────────────────────────────────────────────────────────

export async function handleCellAgentStatus(
  _args: Record<string, unknown>,
): Promise<ToolDispatchResult> {
  const queryPayload = {
    type: "query",
    id: `mcp_agent_status_${Date.now()}`,
    payload: { query: "cell.agent_status", params: {} },
  };

  const result = await dispatchAgentCommand(queryPayload);

  if (!result.ok) {
    return {
      success: false,
      summary: result.error ?? "cell.agent_status query failed",
      payload: { error: result.error, raw: result.raw },
    };
  }

  const responses = Array.isArray(result.responses) ? result.responses : [];
  const first = responses[0] ?? {};
  const payload = (first as Record<string, unknown>).payload ?? {};

  return {
    success: true,
    summary: "CELL Agent Swarm status",
    payload: payload as Record<string, unknown>,
  };
}

// ── cell_agent_result ─────────────────────────────────────────────────────────

export async function handleCellAgentResult(
  args: Record<string, unknown>,
): Promise<ToolDispatchResult> {
  const task_id = String(args.task_id ?? "").trim();
  if (!task_id) {
    return {
      success: false,
      summary: "Missing task_id",
      payload: { error: "missing_task_id" },
    };
  }

  const queryPayload = {
    type: "query",
    id: `mcp_agent_result_${Date.now()}`,
    payload: { query: "cell.agent_result", params: { task_id } },
  };

  const result = await dispatchAgentCommand(queryPayload);

  if (!result.ok) {
    return {
      success: false,
      summary: result.error ?? "cell.agent_result query failed",
      payload: { error: result.error, raw: result.raw },
    };
  }

  const responses = Array.isArray(result.responses) ? result.responses : [];
  const first = responses[0] ?? {};
  const payload = (first as Record<string, unknown>).payload ?? {};
  const ready = (payload as Record<string, unknown>).ready === true;

  return {
    success: true,
    summary: ready
      ? `Agent task ${task_id} complete — ok=${(payload as Record<string, unknown>).ok}`
      : `Agent task ${task_id} still running`,
    payload: payload as Record<string, unknown>,
  };
}
