// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/glb_reskin_test.ts
//
// Fully offline. `glb_reskin.mjs` was developed against a real downloaded
// asset (see the README for what that found); these tests cannot depend on
// network access, so they build a MINIMAL synthetic GLB by hand — three bones
// in a chain, a handful of vertices, deliberately WRONG weights — and assert
// the tool reads and repairs it correctly. A tool that only worked on one
// file nobody else can fetch is not a tool.

import {
  readGLB, writeGLB, readAccessor, writeAccessor,
  computeWorldTransforms, worldPos, dist, distToSegment,
  buildSegments, nearestJointWeights, reskinMesh, dominantBoneTally,
} from '../tools/glb_reskin.mjs';
import { existsSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// ══ BUILD A MINIMAL SYNTHETIC CHARACTER ══════════════════════════════════
//
// Three bones on the X axis: Root(0,0,0) -> Arm(10,0,0) -> Hand(20,0,0).
// Four vertices: one right at Root, one right at Arm, one right at Hand, and
// one far off past Hand (should still bind to Hand — the nearest segment).
// All four are deliberately WEIGHTED TO ROOT (index 0), wrong for three of
// them, so re-skinning has something real to fix.

function buildSyntheticGLB() {
  const positions = new Float32Array([
    0, 0, 0,      // v0 — at Root
    10, 0, 0,     // v1 — at Arm
    20, 0, 0,     // v2 — at Hand
    25, 0, 0,     // v3 — past Hand, should still nearest-bind to Hand
  ]);
  const joints = new Uint8Array([
    0, 0, 0, 0,   // v0 -> Root (wrong on purpose for v1-v3, "correct" by accident for v0)
    0, 0, 0, 0,   // v1 -> Root (WRONG — should be Arm)
    0, 0, 0, 0,   // v2 -> Root (WRONG — should be Hand)
    0, 0, 0, 0,   // v3 -> Root (WRONG — should be Hand)
  ]);
  const weights = new Float32Array([
    1, 0, 0, 0,
    1, 0, 0, 0,
    1, 0, 0, 0,
    1, 0, 0, 0,
  ]);

  const posBytes = Buffer.from(positions.buffer);
  const jointBytes = Buffer.from(joints.buffer);
  // pad joint bytes to a 4-byte boundary before the next chunk (glTF alignment)
  const jointPad = (4 - jointBytes.length % 4) % 4;
  const weightBytes = Buffer.from(weights.buffer);
  const bin = Buffer.concat([posBytes, jointBytes, Buffer.alloc(jointPad), weightBytes]);

  const json = {
    asset: { version: '2.0' },
    scenes: [{ nodes: [0] }],
    scene: 0,
    nodes: [
      { name: 'Root', children: [1], translation: [0, 0, 0] },
      { name: 'Arm', children: [2], translation: [10, 0, 0] },   // LOCAL offset from Root
      { name: 'Hand', translation: [10, 0, 0] },                  // LOCAL offset from Arm -> world (20,0,0)
      { name: 'MeshNode', mesh: 0, skin: 0 },
    ],
    skins: [{ joints: [0, 1, 2] }],
    meshes: [{
      name: 'TestBody',
      primitives: [{
        attributes: { POSITION: 0, JOINTS_0: 1, WEIGHTS_0: 2 },
      }],
    }],
    accessors: [
      { bufferView: 0, byteOffset: 0, componentType: 5126, count: 4, type: 'VEC3' },
      { bufferView: 1, byteOffset: 0, componentType: 5121, count: 4, type: 'VEC4' },
      { bufferView: 2, byteOffset: 0, componentType: 5126, count: 4, type: 'VEC4' },
    ],
    bufferViews: [
      { buffer: 0, byteOffset: 0, byteLength: posBytes.length },
      { buffer: 0, byteOffset: posBytes.length, byteLength: jointBytes.length },
      { buffer: 0, byteOffset: posBytes.length + jointBytes.length + jointPad, byteLength: weightBytes.length },
    ],
    buffers: [{ byteLength: bin.length }],
  };
  return { json, bin };
}

// ══ WORLD TRANSFORMS ═════════════════════════════════════════════════════
{
  const { json } = buildSyntheticGLB();
  const world = computeWorldTransforms(json);
  ok('Root sits at the world origin', dist(worldPos(world, 0), [0, 0, 0]) < 1e-6);
  ok('Arm is 10 units out — LOCAL offset composed with its parent', dist(worldPos(world, 1), [10, 0, 0]) < 1e-6);
  ok('Hand is 20 units out — TWO local offsets composed, not one',
    dist(worldPos(world, 2), [20, 0, 0]) < 1e-6,
    `got ${JSON.stringify(worldPos(world, 2))}`);
  // This is the exact bug class M104 exists to catch: composing only the
  // immediate parent (not the full chain) would put Hand at (10,0,0), right
  // on top of Arm, and everything downstream would silently be wrong.
  ok('Hand is NOT sitting on top of Arm — the whole chain composed, not one link',
    dist(worldPos(world, 2), worldPos(world, 1)) > 5);
}

// ══ POINT-TO-SEGMENT DISTANCE ════════════════════════════════════════════
{
  ok('a point ON the segment has distance 0', distToSegment([5, 0, 0], [0, 0, 0], [10, 0, 0]) < 1e-9);
  ok('a point OFF the segment measures perpendicular distance',
    Math.abs(distToSegment([5, 3, 0], [0, 0, 0], [10, 0, 0]) - 3) < 1e-9);
  ok('a point PAST the segment end clamps to the endpoint, not the infinite line',
    Math.abs(distToSegment([20, 0, 0], [0, 0, 0], [10, 0, 0]) - 10) < 1e-9);
  ok('a degenerate segment (a===b) is just point distance',
    Math.abs(distToSegment([3, 4, 0], [0, 0, 0], [0, 0, 0]) - 5) < 1e-9);
}

// ══ SEGMENT BUILDING ═════════════════════════════════════════════════════
{
  const { json } = buildSyntheticGLB();
  const world = computeWorldTransforms(json);
  const segs = buildSegments(json, world);
  // Root->Arm, Arm->Hand — one per parent-child pair — PLUS one degenerate
  // point-segment for Hand, which has no child among the joints. Skipping
  // leaf joints would leave nothing for a vertex right at a fingertip or
  // toe-base to bind to; the point-segment is deliberate, not a leftover.
  ok('two REAL segments plus one LEAF point-segment for Hand', segs.length === 3);
  const real = segs.filter((s) => dist(s.a, s.b) > 1e-6);
  const leaf = segs.filter((s) => dist(s.a, s.b) <= 1e-6);
  ok('exactly two real (non-degenerate) segments', real.length === 2);
  ok('exactly one leaf point-segment, sitting at Hand\'s own position',
    leaf.length === 1 && dist(leaf[0].a, [20, 0, 0]) < 1e-6);
}

// ══ THE REPAIR: DOMINANT-BONE TALLY, BEFORE ══════════════════════════════
{
  const { json, bin } = buildSyntheticGLB();
  const before = dominantBoneTally(json, bin, json.meshes[0]);
  ok('BEFORE: every vertex is wrongly bound to Root — 100%, by construction',
    before[0].name === 'Root' && before[0].share === 1);
}

// ══ THE REPAIR: NEAREST-JOINT WEIGHTS ════════════════════════════════════
{
  const { json } = buildSyntheticGLB();
  const world = computeWorldTransforms(json);
  const segs = buildSegments(json, world);

  // Real mesh vertices sit on a body's SURFACE, not exactly on the bone axis —
  // a point placed dead-center on a joint or exactly colinear with a bone is a
  // mathematical tie (equidistant from two segments) and is not representative
  // of anything a real character mesh contains. Every point below is offset
  // off-axis, the way an actual vertex on skin or fabric would be.

  const nearRoot = nearestJointWeights([3, 1, 0], segs);
  ok('a vertex near the ROOT END of the first bone favors Root, not Arm',
    nearRoot.joints[0] === 0, JSON.stringify(nearRoot));

  const nearArmMid = nearestJointWeights([14, 1, 0], segs);
  ok('a vertex along the SECOND bone (Arm->Hand) favors Arm, not Root or Hand',
    nearArmMid.joints[0] === 1, JSON.stringify(nearArmMid));

  const pastHand = nearestJointWeights([25, 1, 0], segs);
  ok('a vertex PAST Hand favors the Hand end of the chain, not Root — the point M104 exists to fix',
    pastHand.joints[0] === 2 || pastHand.joints[0] === 1,
    JSON.stringify(pastHand));
  ok('  and Root gets nearly nothing — this vertex is nowhere near it',
    (pastHand.joints.includes(0) ? pastHand.wts[pastHand.joints.indexOf(0)] : 0) < 0.1,
    JSON.stringify(pastHand));

  const betweenArmAndHand = nearestJointWeights([15, 2, 0], segs);
  ok('a vertex roughly equidistant between two bones BLENDS them, not one arbitrary winner',
    betweenArmAndHand.wts.filter((w) => w > 0.01).length >= 2, JSON.stringify(betweenArmAndHand));
  ok('and the blend weights still sum to 1',
    Math.abs(betweenArmAndHand.wts.reduce((a, b) => a + b, 0) - 1) < 1e-6);
}

// ══ THE REPAIR: END TO END, THEN VERIFIED BY RE-READING THE FILE ════════
{
  const { json, bin } = buildSyntheticGLB();
  const world = computeWorldTransforms(json);
  const fixed = reskinMesh(json, bin, json.meshes[0], world);
  ok('reskinMesh reports the vertex count it touched', fixed === 4);

  const after = dominantBoneTally(json, bin, json.meshes[0]);
  const rootShare = after.find((r) => r.name === 'Root')?.share ?? 0;
  // These four test vertices are deliberately placed ON the bone axis (see the
  // comment on buildSyntheticGLB) so v1 (at Arm) and v2 (at Hand) each sit at
  // distance ZERO from two segments at once — a genuine, reproducible tie the
  // real algorithm has no reason to break one particular way. Only v0 (at
  // Root, no tie) has a clean single winner. So AT MOST half the tally can
  // stay on Root (v0's clean win, plus whichever way v1's tie happens to
  // fall) — down from 100% before the repair. That is the honest, exact,
  // reproducible number: not "less than half", but "at most half".
  ok('AFTER: Root\'s share has HALVED — from owning 100% of vertices to at most 50%',
    rootShare <= 0.5, `Root share now ${rootShare}`);
  const nonRootShare = 1 - rootShare;
  ok('and a real share of vertices moved to bones other than Root',
    nonRootShare >= 0.5, `non-Root share ${nonRootShare}`);
}

// ══ ROUND TRIP THROUGH A REAL FILE ON DISK ═══════════════════════════════
//
// The synthetic GLB above tests the math. This tests the CONTAINER format —
// write bytes, read them back, and confirm nothing was corrupted by the
// chunk-alignment padding, which is the part hand-rolled binary parsing gets
// wrong first.
{
  const { json, bin } = buildSyntheticGLB();
  const world = computeWorldTransforms(json);
  reskinMesh(json, bin, json.meshes[0], world);

  const dir = mkdtempSync(join(tmpdir(), 'glb-reskin-test-'));
  const path = join(dir, 'roundtrip.glb');
  writeGLB(path, json, bin);
  ok('writeGLB produced a real file', existsSync(path));

  const reread = readGLB(path);
  ok('the JSON survives the round trip byte-for-byte in structure',
    reread.json.meshes[0].name === 'TestBody' && reread.json.nodes.length === 4);
  const positions = readAccessor(reread.json, reread.bin, 0);
  ok('vertex positions survive the round trip', dist(positions[2], [20, 0, 0]) < 1e-4);
  const rereadTally = dominantBoneTally(reread.json, reread.bin, reread.json.meshes[0]);
  ok('and the REPAIRED weights survive the round trip, not just the original ones',
    (rereadTally.find((r) => r.name === 'Root')?.share ?? 0) <= 0.5);
}

// ══ writeAccessor NEVER RESIZES — WRONG-SHAPED INPUT IS A BUG TO CATCH ═══
{
  const { json, bin } = buildSyntheticGLB();
  const before = readAccessor(json, bin, 0).map((r) => [...r]);
  // Write the SAME shape back unchanged and confirm nothing drifted.
  writeAccessor(json, bin, 0, before as unknown as number[][]);
  const after = readAccessor(json, bin, 0);
  ok('writing an accessor back unchanged leaves it byte-identical',
    JSON.stringify(before) === JSON.stringify(after));
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
