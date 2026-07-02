import fs from "node:fs";
import { arenaRegistryPath, modesCapabilityPath } from "./config.js";

export type NexusMode = {
  id: string;
  displayName: string;
  venueToken: string;
  releaseState: "production" | "staging" | "preview" | "non-game";
  tier?: "prod" | "sim" | "stub" | "non-game";
  source: "registry" | "capability_doc";
};

const REGISTRY_BLOCK =
  /\.id = "([^"]+)",\s*\n\s*\.displayName = "([^"]+)",\s*\n\s*\.venueToken = "([^"]+)",[\s\S]*?\.releaseState = ArenaReleaseState::(k\w+)/g;

function releaseFromCpp(token: string): NexusMode["releaseState"] {
  switch (token) {
    case "kProduction":
      return "production";
    case "kStaging":
      return "staging";
    case "kPreview":
      return "preview";
    case "kNonGameModule":
      return "non-game";
    default:
      return "staging";
  }
}

export function parseArenaRegistry(source: string): NexusMode[] {
  const modes: NexusMode[] = [];
  for (const match of source.matchAll(REGISTRY_BLOCK)) {
    modes.push({
      id: match[1],
      displayName: match[2],
      venueToken: match[3],
      releaseState: releaseFromCpp(match[4]),
      source: "registry",
    });
  }
  return modes;
}

function tierFromCapabilityDoc(modeId: string, doc: string): NexusMode["tier"] | undefined {
  const sections: Array<{ tier: NexusMode["tier"]; pattern: RegExp }> = [
    { tier: "prod", pattern: /## Production simulators[\s\S]*?(?=## |$)/ },
    { tier: "sim", pattern: /## Outcome-evaluator only[\s\S]*?(?=## |$)/ },
    { tier: "stub", pattern: /## Staging \/ preview stubs[\s\S]*?(?=## |$)/ },
    { tier: "non-game", pattern: /## Cross-cutting systems[\s\S]*?(?=## |$)/ },
  ];

  for (const { tier, pattern } of sections) {
    const section = doc.match(pattern)?.[0] ?? "";
    if (section.includes(`\`${modeId}\``) || section.includes(`| \`${modeId}\``)) {
      return tier;
    }
  }

  if (doc.includes(`\`${modeId}\``)) {
    return "sim";
  }
  return undefined;
}

export function loadModes(): {
  modes: NexusMode[];
  total: number;
  capabilityDocUpdated?: string;
} {
  const registrySource = fs.readFileSync(arenaRegistryPath(), "utf8");
  const modes = parseArenaRegistry(registrySource);

  let capabilityDocUpdated: string | undefined;
  if (fs.existsSync(modesCapabilityPath())) {
    const doc = fs.readFileSync(modesCapabilityPath(), "utf8");
    const updated = doc.match(/\*\*Updated:\*\*\s*(.+)/)?.[1]?.trim();
    capabilityDocUpdated = updated;
    for (const mode of modes) {
      mode.tier = tierFromCapabilityDoc(mode.id, doc);
    }
  }

  return { modes, total: modes.length, capabilityDocUpdated };
}

export function filterModes(
  modes: NexusMode[],
  filter?: { release?: string; tier?: string; sprintOnly?: boolean; includePreview?: boolean },
): NexusMode[] {
  let result = modes;
  if (filter?.includePreview === false) {
    result = result.filter((m) => m.releaseState !== "preview");
  }
  if (filter?.release) {
    result = result.filter((m) => m.releaseState === filter.release);
  }
  if (filter?.tier) {
    result = result.filter((m) => m.tier === filter.tier);
  }
  if (filter?.sprintOnly) {
    const sprintIds = new Set(["basketball_dunk", "karate_endless"]);
    result = result.filter((m) => sprintIds.has(m.id));
  }
  return result;
}
