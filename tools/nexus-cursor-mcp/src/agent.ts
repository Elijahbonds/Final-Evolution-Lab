import { runAgentCli } from "./safe-exec.js";

const ALLOWED_COMMAND_PREFIXES = [
  "terrain.",
  "fel.",
  "fitness.",
  "world.",
  "entity.",
  "cell.",
];

function extractCommandName(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }
  const record = payload as Record<string, unknown>;
  const inner = record.payload;
  if (!inner || typeof inner !== "object") {
    return null;
  }
  const innerRecord = inner as Record<string, unknown>;
  if (typeof innerRecord.command === "string") {
    return innerRecord.command;
  }
  if (typeof innerRecord.query === "string") {
    return innerRecord.query;
  }
  return null;
}

function isAllowedAgentPayload(payload: unknown): boolean {
  if (!payload || typeof payload !== "object") {
    return false;
  }
  const record = payload as Record<string, unknown>;
  const type = record.type;
  if (type !== "command" && type !== "query" && type !== "auth") {
    return false;
  }

  const name = extractCommandName(payload);
  if (!name) {
    return type === "auth";
  }

  return ALLOWED_COMMAND_PREFIXES.some(
    (prefix) => name === prefix.slice(0, -1) || name.startsWith(prefix),
  );
}

export async function dispatchAgentCommand(
  command: Record<string, unknown> | Record<string, unknown>[],
): Promise<{ ok: boolean; responses: unknown; raw?: string; error?: string }> {
  const messages = Array.isArray(command) ? command : [command];
  for (const message of messages) {
    if (!isAllowedAgentPayload(message)) {
      const name = extractCommandName(message) ?? "(missing command/query)";
      return {
        ok: false,
        responses: [],
        error: `Blocked agent message: "${name}" is outside the NEXUS command whitelist`,
      };
    }
  }

  const jsonPayload = Array.isArray(command)
    ? JSON.stringify({ messages: command })
    : JSON.stringify(command);

  const result = await runAgentCli(jsonPayload);
  const combined = `${result.stdout}\n${result.stderr}`.trim();

  try {
    const responses = JSON.parse(result.stdout || "[]");
    return { ok: result.ok, responses, raw: combined };
  } catch {
    return {
      ok: false,
      responses: [],
      raw: combined,
      error: "nexus_agent_cli did not return JSON",
    };
  }
}
