import fs from "node:fs";
import { registryPath } from "./config.js";

export type RegistryTool = {
  description: string;
  hosts?: string[];
  parameters?: Record<string, unknown>;
  routes_to?: string[];
};

export type NexusToolRegistry = {
  schema: string;
  mcp_surface_tools: string[];
  tools: Record<string, RegistryTool>;
};

export function loadRegistry(): NexusToolRegistry {
  const raw = fs.readFileSync(registryPath(), "utf8");
  return JSON.parse(raw) as NexusToolRegistry;
}
