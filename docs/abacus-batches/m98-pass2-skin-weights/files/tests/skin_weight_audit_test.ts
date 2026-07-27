// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/skin_weight_audit_test.ts
//
// The first test reproduces the MEASURED character from the deployed build and
// asserts the audit calls it broken. The second builds a correctly weighted
// character and asserts the audit stays quiet — because a check that fails
// everything is as useless as one that fails nothing.

import {
  auditSkin, regionOf, verticesFromBuffers, reportSkin,
  MAX_SINGLE_BONE_SHARE, MAX_MISMATCH_RATE,
  type Vertex,
} from '../anim/SkinWeightAudit.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// The measured bind-pose bounds of `Body_c5`: feet at y=-0.84, head near +0.9,
// hands at x=±0.95.
const B = { minY: -0.84, maxY: 0.95, maxAbsX: 0.95 };

/** The bare point cloud of a humanoid in T-pose. */
function shape(): { x: number; y: number }[] {
  const p: { x: number; y: number }[] = [];
  // arms out to both sides at shoulder height
  for (let i = 0; i <= 20; i++) { const t = i / 20; p.push({ x: 0.95 * t, y: 0.62 }); p.push({ x: -0.95 * t, y: 0.6 }); }
  // spine
  for (let i = 0; i <= 20; i++) p.push({ x: 0, y: -0.2 + (1.1 * i) / 20 });
  // legs
  for (let i = 0; i <= 20; i++) { const t = i / 20; p.push({ x: 0.11, y: -0.84 + 0.75 * t }); p.push({ x: -0.11, y: -0.84 + 0.75 * t }); }
  return p;
}

/**
 * A humanoid in T-pose. `weightFn` decides how each vertex is bound.
 *
 * Bounds are derived from the cloud rather than hardcoded, because `auditSkin`
 * derives its own — and the first run of this file failed on two boundary
 * vertices for exactly that mismatch. The fixture was wrong, not the audit.
 */
function character(weightFn: (x: number, y: number, b: typeof BOUNDS) => string): Vertex[] {
  return shape().map((p) => ({ x: p.x, y: p.y, z: 0, bones: [{ name: weightFn(p.x, p.y, BOUNDS), weight: 0.9 }] }));
}

const BOUNDS = (() => {
  const p = shape();
  return {
    minY: Math.min(...p.map((v) => v.y)),
    maxY: Math.max(...p.map((v) => v.y)),
    maxAbsX: Math.max(...p.map((v) => Math.abs(v.x))),
  };
})();

const CORRECT = (x: number, y: number, b = BOUNDS): string => {
  const r = regionOf({ x, y }, b);
  if (r === 'hand') return x > 0 ? 'LeftHand' : 'RightHand';
  if (r === 'arm') return x > 0 ? 'LeftArm' : 'RightArm';
  if (r === 'head') return 'Head';
  if (r === 'foot') return x > 0 ? 'LeftFoot' : 'RightFoot';
  if (r === 'leg') return x > 0 ? 'LeftUpLeg' : 'RightUpLeg';
  return 'Spine1';
};

// ══ THE MEASURED CHARACTER ═══════════════════════════════════════════════
{
  // What the deployed build actually does: upper body welded to Head, legs to
  // leg bones. Reconstructed from the vertex probes in M98's README.
  const deployed = character((x, y, b) => (regionOf({ x, y }, b) === 'foot' || regionOf({ x, y }, b) === 'leg')
    ? (x > 0 ? 'LeftUpLeg' : 'RightUpLeg') : 'Head');
  const r = auditSkin(deployed);

  ok('THE DEPLOYED CHARACTER IS CALLED BROKEN', r.verdict === 'broken');
  ok('and the dominant bone is Head, as measured', r.dominantBone === 'Head');
  ok('and its share exceeds the threshold by a wide margin',
    r.dominantShare > MAX_SINGLE_BONE_SHARE, `${(r.dominantShare * 100).toFixed(0)}%`);
  ok('THE HANDS ARE REPORTED AS DRIVEN BY Head — the sentence that explains six batches',
    r.regionOwners.hand === 'Head');
  ok('and the report says the mesh will not animate',
    r.reasons.some((s) => /will not animate/.test(s)));
  ok('and it says the skeleton is not the problem', (() => {
    const lines: string[] = [];
    const err = console.error; console.error = (m: string) => lines.push(String(m));
    reportSkin('Body_c5', r); console.error = err;
    return lines.some((l) => /skeleton is not the problem/.test(l))
      && lines.some((l) => /no clip, pose or mocap can work around this/.test(l));
  })());
}

// ══ A CORRECT CHARACTER MUST PASS ════════════════════════════════════════
{
  const r = auditSkin(character(CORRECT));
  ok('A CORRECTLY WEIGHTED CHARACTER PASSES', r.verdict === 'ok', JSON.stringify(r.reasons));
  ok('and no single bone dominates it', r.dominantShare <= MAX_SINGLE_BONE_SHARE,
    `${r.dominantBone} ${(r.dominantShare * 100).toFixed(0)}%`);
  ok('and the mismatch rate is zero', r.mismatchRate === 0);
  ok('and reportSkin stays silent — a check that logs on healthy spawns becomes noise', (() => {
    const lines: string[] = [];
    const err = console.error; console.error = (m: string) => lines.push(String(m));
    reportSkin('Good', r); console.error = err;
    return lines.length === 0;
  })());
}

// ══ IT CATCHES THE NEAR MISSES TOO ═══════════════════════════════════════
{
  // Arms bound to the spine rather than the arm bones: subtler than the
  // measured bug, equally fatal to any arm animation.
  const armsToSpine = character((x, y, b) => {
    const r = regionOf({ x, y }, b);
    return (r === 'arm' || r === 'hand') ? 'Spine2' : CORRECT(x, y, b);
  });
  const a = auditSkin(armsToSpine);
  ok('arms bound to the spine are caught', a.verdict !== 'ok');
  ok('and it names the arm region specifically',
    a.reasons.some((s) => /arm region is driven by "Spine2"/.test(s)));

  // Left and right swapped is a real export bug and must NOT be reported,
  // because this audit cannot see handedness and a false positive here would
  // train people to ignore it.
  const swapped = character((x, y, b) => CORRECT(-x, y, b));
  ok('a left/right swap is OUTSIDE what this audit claims to detect',
    auditSkin(swapped).verdict === 'ok');
}

// ══ THE CLASSIFIER ═══════════════════════════════════════════════════════
{
  ok('fingertips classify as hand', regionOf({ x: 0.94, y: 0.62 }, B) === 'hand');
  ok('mid-arm classifies as arm', regionOf({ x: 0.5, y: 0.65 }, B) === 'arm');
  ok('top of head classifies as head', regionOf({ x: 0, y: 0.93 }, B) === 'head');
  ok('the floor classifies as foot', regionOf({ x: 0.1, y: -0.82 }, B) === 'foot');
  ok('the chest classifies as torso', regionOf({ x: 0, y: 0.4 }, B) === 'torso');
  ok('degenerate bounds do not throw', regionOf({ x: 0, y: 0 }, { minY: 0, maxY: 0, maxAbsX: 0 }) === 'unknown');
}

// ══ THE BUFFER ADAPTER ═══════════════════════════════════════════════════
{
  // Exactly the shape Babylon hands over, including the index→name lookup that
  // is where this whole class of bug lives.
  const positions = [0.9, 0.62, 0, 0, 0.4, 0, 0.11, -0.84, 0];
  const indices = [5, 8, 0, 0, /**/ 1, 0, 0, 0, /**/ 46, 0, 0, 0];
  const weights = [0.78, 0.16, 0, 0, /**/ 0.97, 0, 0, 0, /**/ 0.48, 0, 0, 0];
  const names = ['Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head', 'LeftShoulder', 'LeftArm',
    'LeftForeArm'];
  names[46] = 'LeftFoot';

  const v = verticesFromBuffers(positions, indices, weights, names, 1);
  ok('the adapter resolves indices to names', v[0].bones[0].name === 'Head' && v[0].bones[0].weight === 0.78);
  ok('and drops zero-weight influences', v[1].bones.length === 1);
  ok('and survives an index with no bone name', (() => {
    const bad = verticesFromBuffers([0, 0, 0], [99, 0, 0, 0], [1, 0, 0, 0], names, 1);
    return bad[0].bones[0].name === '#99';
  })());
  ok('stride samples rather than reading every vertex — a load check must not hitch',
    verticesFromBuffers(new Array(300).fill(0), new Array(400).fill(0), new Array(400).fill(1), names, 7).length
    < 20);
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
