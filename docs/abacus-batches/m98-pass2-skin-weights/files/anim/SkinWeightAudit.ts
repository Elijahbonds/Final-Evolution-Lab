// SkinWeightAudit — the reason every animation batch in this project failed.
//
// MEASURED INSIDE THE DEPLOYED BUILD, 2026-07-28, on `Body_c5` (18,409 verts,
// skeleton `Armature_c57`, 52 bones):
//
//   vertex                          weighted to        weight
//   left hand   (x=+0.91, y=0.62)   Head  (index 5)      0.78
//   right hand  (x=-0.91, y=0.57)   Head  (index 5)      0.68
//   left forearm(x=+0.42, y=0.62)   Head  (index 5)      0.90
//   chest       (x=-0.06, y=0.88)   Head  (index 5)      0.97
//   left foot   (x=+0.11, y=-0.84)  LeftUpLeg (44)       0.48
//
//   **14,128 of 18,409 vertices — 77% of the character — are dominated by the
//   Head bone.**
//
// The entire upper body is one rigid lump welded to `Head`. The arms cannot
// move, because nothing about the arms is bound to the arm bones.
//
// WHAT THIS EXPLAINS
// Everything. The skeleton has been correct this whole time — M97 measured the
// arm bones sitting at 20 degrees from vertical, exactly where M64's solver put
// them, with the transform nodes and the bone matrices in agreement. The rest
// pose works. `idle_stand` plays. And the mesh renders a T-pose regardless,
// because the mesh is not listening to those bones.
//
// M24, M42, M51, M64, M69 and M80 all worked on the skeleton, the clips, or the
// pose. **Not one of them could have fixed this.** Nor could conformed mocap:
// Phase 4's whole premise was that better clips would fix the arms, and better
// clips drive the same bones the mesh ignores.
//
// WHY IT NEEDS A GATE AND NOT JUST A FIX
// The fix is an asset re-export, which happens on someone's machine, by hand,
// and can silently regress on the next character. This module is the check that
// runs at load and refuses to let it happen quietly again. It is deliberately
// pure — positions, indices, weights and bone names in, a verdict out — so it
// can be tested here and run anywhere.

/** Where a vertex sits on a character standing in bind pose. */
export type Region = 'head' | 'torso' | 'arm' | 'hand' | 'leg' | 'foot' | 'unknown';

/** Bone-name patterns that legitimately own each region. */
const OWNERS: Record<Region, RegExp> = {
  head: /^(Head|HeadTop|Neck)/i,
  torso: /^(Hips|Spine|Neck|.*Shoulder)/i,
  arm: /^(Left|Right)(Shoulder|Arm|ForeArm)$/i,
  hand: /^(Left|Right)(Hand|ForeArm)/i,
  leg: /^(Left|Right)(UpLeg|Leg)$/i,
  foot: /^(Left|Right)(Foot|ToeBase)/i,
  unknown: /.^/,
};

export interface Vertex {
  x: number; y: number; z: number;
  /** Bone NAMES, resolved from matricesIndices, with their weights. */
  bones: { name: string; weight: number }[];
}

export interface Bounds {
  minY: number; maxY: number; maxAbsX: number;
}

/**
 * Classify a bind-pose vertex anatomically.
 *
 * The rig is a T-pose — the hands are the widest points, at roughly shoulder
 * height. That is what makes this classifiable at all without a human: in a
 * T-pose, lateral extent IS arm-ness.
 */
export function regionOf(v: { x: number; y: number }, b: Bounds): Region {
  const h = b.maxY - b.minY;
  if (h <= 0 || b.maxAbsX <= 0) return 'unknown';
  const up = (v.y - b.minY) / h;          // 0 = feet, 1 = top of head
  const out = Math.abs(v.x) / b.maxAbsX;  // 0 = centreline, 1 = fingertips

  if (out > 0.75) return 'hand';
  if (out > 0.35 && up > 0.55) return 'arm';
  if (up > 0.88) return 'head';
  if (up < 0.12) return 'foot';
  if (up < 0.45) return 'leg';
  return 'torso';
}

export interface AuditResult {
  checked: number;
  /** Vertices whose dominant bone cannot legitimately own their region. */
  mismatched: number;
  mismatchRate: number;
  /** The single bone dominating the most vertices, and by how much. */
  dominantBone: string;
  dominantShare: number;
  /** Region → the bone most often driving it. */
  regionOwners: Record<string, string>;
  verdict: 'ok' | 'suspect' | 'broken';
  reasons: string[];
}

/**
 * No single bone should dominate this much of a character.
 *
 * A correctly weighted humanoid spreads across ~20 bones; the largest share is
 * typically the hips or spine at 10-15%. The measured character is 77% Head.
 * 40% is a wide margin that still catches a collapse this total.
 */
export const MAX_SINGLE_BONE_SHARE = 0.4;

/** Above this share of anatomically impossible bindings, the rig is broken. */
export const MAX_MISMATCH_RATE = 0.25;

export function auditSkin(vertices: Vertex[]): AuditResult {
  const bounds: Bounds = { minY: Infinity, maxY: -Infinity, maxAbsX: 0 };
  for (const v of vertices) {
    bounds.minY = Math.min(bounds.minY, v.y);
    bounds.maxY = Math.max(bounds.maxY, v.y);
    bounds.maxAbsX = Math.max(bounds.maxAbsX, Math.abs(v.x));
  }

  const byBone = new Map<string, number>();
  const byRegion = new Map<string, Map<string, number>>();
  let mismatched = 0;
  let checked = 0;

  for (const v of vertices) {
    const dom = v.bones.reduce((a, b) => (b.weight > a.weight ? b : a),
      { name: '', weight: -1 });
    if (!dom.name || dom.weight <= 0) continue;
    checked++;
    byBone.set(dom.name, (byBone.get(dom.name) ?? 0) + 1);

    const region = regionOf(v, bounds);
    if (!byRegion.has(region)) byRegion.set(region, new Map());
    const rm = byRegion.get(region)!;
    rm.set(dom.name, (rm.get(dom.name) ?? 0) + 1);

    if (region !== 'unknown' && !OWNERS[region].test(dom.name)) mismatched++;
  }

  let dominantBone = ''; let dominantCount = 0;
  for (const [name, n] of byBone) if (n > dominantCount) { dominantCount = n; dominantBone = name; }
  const dominantShare = checked ? dominantCount / checked : 0;
  const mismatchRate = checked ? mismatched / checked : 0;

  const regionOwners: Record<string, string> = {};
  for (const [region, m] of byRegion) {
    let best = ''; let n = 0;
    for (const [name, c] of m) if (c > n) { n = c; best = name; }
    regionOwners[region] = best;
  }

  const reasons: string[] = [];
  if (dominantShare > MAX_SINGLE_BONE_SHARE) {
    reasons.push(`${Math.round(dominantShare * 100)}% of the mesh is welded to "${dominantBone}" `
      + '— a correctly weighted humanoid spreads across ~20 bones');
  }
  if (mismatchRate > MAX_MISMATCH_RATE) {
    reasons.push(`${Math.round(mismatchRate * 100)}% of vertices are bound to a bone that cannot `
      + 'anatomically own them');
  }
  for (const region of ['hand', 'arm', 'foot'] as const) {
    const owner = regionOwners[region];
    if (owner && !OWNERS[region].test(owner)) {
      reasons.push(`the ${region} region is driven by "${owner}" — it will not animate`);
    }
  }

  const verdict: AuditResult['verdict'] = reasons.length === 0 ? 'ok'
    : (dominantShare > MAX_SINGLE_BONE_SHARE || mismatchRate > MAX_MISMATCH_RATE) ? 'broken' : 'suspect';

  return { checked, mismatched, mismatchRate, dominantBone, dominantShare, regionOwners, verdict, reasons };
}

/**
 * Build the audit input from Babylon vertex data.
 *
 * `stride` samples the mesh — 18,409 vertices is more than needed to detect a
 * 77% collapse, and a load-time check that costs a visible hitch is a check
 * someone turns off.
 */
export function verticesFromBuffers(
  positions: ArrayLike<number>,
  matricesIndices: ArrayLike<number>,
  matricesWeights: ArrayLike<number>,
  boneNames: readonly string[],
  stride = 7,
): Vertex[] {
  const out: Vertex[] = [];
  const count = Math.floor(positions.length / 3);
  for (let i = 0; i < count; i += stride) {
    const bones: Vertex['bones'] = [];
    for (let k = 0; k < 4; k++) {
      const w = matricesWeights[i * 4 + k];
      if (w > 0) bones.push({ name: boneNames[matricesIndices[i * 4 + k]] ?? `#${matricesIndices[i * 4 + k]}`, weight: w });
    }
    out.push({ x: positions[i * 3], y: positions[i * 3 + 1], z: positions[i * 3 + 2], bones });
  }
  return out;
}

/**
 * One line for the console at spawn.
 *
 * It speaks ONLY when something is wrong, because a check that logs on every
 * healthy spawn becomes noise people filter out — which is how a 77% weight
 * collapse shipped past six animation batches.
 */
export function reportSkin(meshName: string, r: AuditResult): void {
  if (r.verdict === 'ok') return;
  const tag = r.verdict === 'broken' ? 'BROKEN' : 'suspect';
  console.error(`[FEL-SKIN] ${tag} weights on "${meshName}" — this mesh will not animate correctly.`);
  for (const why of r.reasons) console.error(`[FEL-SKIN]   ${why}`);
  console.error('[FEL-SKIN]   The skeleton is not the problem. Re-export the character with '
    + 'correct skin weights; no clip, pose or mocap can work around this.');
}
