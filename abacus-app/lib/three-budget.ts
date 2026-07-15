// Central performance budget for all 3D modes in Final Evolution Lab.
// HARD REQUIREMENT: target 60fps, acceptable floor 30fps on mid-tier mobile.
// These numbers gate what a scene is allowed to spend; the PerfHud flags violations live.

export const PERF_BUDGET = {
  targetFps: 60,
  floorFps: 30,
  // Per-frame GPU budget (whole scene)
  maxDrawCalls: 120,
  maxTriangles: 180_000,
  maxTextureMB: 48, // approximate GPU texture memory
  // Per skinned character
  maxCharTriangles: 30_000,
  maxCharBones: 60,
  // Device pixel ratio clamp — never render above 2x, scale down under load
  dprMin: 1,
  dprMax: 1.5,
} as const;

export type PerfSample = {
  fps: number;
  calls: number;
  triangles: number;
  textures: number;
  geometries: number;
  programs: number;
};

// Grade a live sample against the budget. Returns a status + human-readable notes.
export function gradePerf(s: PerfSample): { status: 'ok' | 'warn' | 'over'; notes: string[] } {
  const notes: string[] = [];
  let status: 'ok' | 'warn' | 'over' = 'ok';
  if (s.fps < PERF_BUDGET.floorFps) { status = 'over'; notes.push(`fps ${s.fps} < floor ${PERF_BUDGET.floorFps}`); }
  else if (s.fps < PERF_BUDGET.targetFps - 8) { status = 'warn'; notes.push(`fps ${s.fps} below target`); }
  if (s.calls > PERF_BUDGET.maxDrawCalls) { status = 'over'; notes.push(`draw calls ${s.calls} > ${PERF_BUDGET.maxDrawCalls}`); }
  if (s.triangles > PERF_BUDGET.maxTriangles) { status = 'over'; notes.push(`tris ${s.triangles} > ${PERF_BUDGET.maxTriangles}`); }
  return { status, notes };
}
