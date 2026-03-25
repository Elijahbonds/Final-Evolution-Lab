/**
 * Vertical Velocity Academy — module registry for web / Wix / future React shells.
 * Keep in sync with Swift `VerticalVelocityAcademyCurriculum` and `Config/ACADEMY_CURRICULUM_V1.json`.
 * Alpha 2: next five modules (13–17) are placeholders until curriculum copy is finalized.
 */

/** mod1 … mod17+ — extend as curriculum grows */
export type VVAModuleId = string;

export interface VVAModule {
  id: VVAModuleId;
  number: number;
  title: string;
  subtitle: string;
  phase: "Foundations" | "Load" | "Launch" | "Flight" | "Elite" | "TBD";
  cloudCortexTags: string[];
}

/** Shipped modules (1–12) — abbreviated for routing; full copy lives in app JSON. */
export const vvaShippedModules: VVAModule[] = [
  { id: "mod1", number: 1, title: "Bio-Electric Freeway", subtitle: "CNS freeway", phase: "Foundations", cloudCortexTags: ["freeway", "cns"] },
  { id: "mod2", number: 2, title: "Internal GPS", subtitle: "SFMA/FMS", phase: "Foundations", cloudCortexTags: ["screen", "gps", "ankle_piston_alias"] },
  { id: "mod3", number: 3, title: "The Piston", subtitle: "IAP", phase: "Foundations", cloudCortexTags: ["piston", "iap", "breathing"] },
  { id: "mod8", number: 8, title: "Rhythmic Penultimate", subtitle: "Push 1, 2", phase: "Launch", cloudCortexTags: ["penultimate", "rfd"] },
];

/** Next five modules (Alpha 2 expansion) — titles TBD; ingest into app when curriculum locks. */
export const vvaNextFiveModules: VVAModule[] = [
  { id: "mod13", number: 13, title: "TBD — Forensic Load Management", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2"] },
  { id: "mod14", number: 14, title: "TBD — Elastic Energy Accounting", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2"] },
  { id: "mod15", number: 15, title: "TBD — Competition taper", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2"] },
  { id: "mod16", number: 16, title: "TBD — Crew / broadcast mirror", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2"] },
  { id: "mod17", number: 17, title: "TBD — Sovereign economy + habits", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2", "shards"] },
];

export function moduleById(id: string): VVAModule | undefined {
  const all = [...vvaShippedModules, ...vvaNextFiveModules];
  return all.find((m) => m.id === id);
}
