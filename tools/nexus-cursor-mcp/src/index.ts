#!/usr/bin/env node
/**
 * NEXUS Cursor MCP — canonical stdio server for Cursor Desktop.
 * Registry: Config/nexus_cursor_tool_registry.json
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { dispatchTool } from "./dispatch.js";
import { loadRegistry } from "./registry.js";

const registry = loadRegistry();

function toolResult(name: string, result: Awaited<ReturnType<typeof dispatchTool>>) {
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(
          {
            tool: name,
            success: result.success,
            summary: result.summary,
            payload: result.payload,
          },
          null,
          2,
        ),
      },
    ],
    isError: !result.success,
  };
}

const server = new Server(
  { name: "nexus-cursor-mcp", version: "1.0.0" },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: registry.mcp_surface_tools.map((name) => {
    const entry = registry.tools[name];
    return {
      name,
      description: entry.description,
      inputSchema: entry.parameters ?? { type: "object", properties: {} },
    };
  }),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args = {} } = request.params;

  if (!registry.mcp_surface_tools.includes(name)) {
    return toolResult(name, {
      success: false,
      summary: `Unexpected MCP tool '${name}'`,
      payload: { error: "unexpected_tool" },
    });
  }

  const result = await dispatchTool(
    name,
    (args ?? {}) as Record<string, unknown>,
  );
  return toolResult(name, result);
});

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
