#!/usr/bin/env node
// glb_reskin.mjs — inspect and (optionally) repair a GLB's skin weights.
// No dependencies: parses the GLB container and glTF JSON by hand.
//
//     node tools/glb_reskin.mjs inspect character.glb
//     node tools/glb_reskin.mjs reskin character.glb out.glb [meshName]
//
// WHY THIS EXISTS
// M98 measured 77% of the DEPLOYED character mesh bound to the `Head` bone —
// the actual cause of the T-pose, found by reading vertex buffers out of the
// live Babylon scene. This is the offline half: point it at a `.glb`/source
// export directly (no browser, no running app) to read the same numbers, and
// to attempt a mechanical repair when the bug turns out to be fixable by
// geometry alone.
//
// `inspect` reads. `reskin` writes a NEW file and never touches the input —
// a tool that can silently overwrite the only copy of an asset is a tool
// nobody should run twice.
//
// THE RESKIN ALGORITHM, PLAINLY
// For every vertex: build a bone SEGMENT for each parent→child pair among the
// skin's joints (Hips→Spine, LeftArm→LeftForeArm, …), find the K=4 closest
// segments to the vertex in BIND-POSE space, weight by inverse distance,
// normalize, write back as JOINTS_0/WEIGHTS_0. This is the standard
// "nearest-bone" heuristic — a plainer version of what Blender's "Automatic
// Weights" does with heat diffusion. It needs no bone-name guessing and no
// region classification: a T-pose already separates the limbs geometrically,
// so the vertex's true nearest bone wins regardless of what a broken export
// said before.
//
// WHAT IT DOES NOT CLAIM
// This repairs GEOMETRY-VS-SKELETON mismatches. It cannot fix a mesh whose
// vertex positions themselves are wrong, and it cannot tell you whether the
// file you are pointing it at is the same file actually deployed — see
// docs/abacus-batches/m104-.../00-README-PROMPT.md for why that distinction
// mattered here.

import { readFileSync, writeFileSync } from 'node:fs';

// ── GLB container ───────────────────────────────────────────────────────

export function readGLB(path) {
  const buf = readFileSync(path);
  if (buf.readUInt32LE(0) !== 0x46546c67) throw new Error('not a GLB (bad magic)');
  const total = buf.readUInt32LE(8);
  let offset = 12, json = null, bin = null;
  while (offset < total) {
    const len = buf.readUInt32LE(offset);
    const type = buf.readUInt32LE(offset + 4);
    const data = buf.subarray(offset + 8, offset + 8 + len);
    if (type === 0x4e4f534a) json = JSON.parse(data.toString('utf8'));      // 'JSON'
    else if (type === 0x004e4942) bin = Buffer.from(data);                  // 'BIN\0' — copy, we mutate
    offset += 8 + len;
  }
  if (!json) throw new Error('no JSON chunk');
  return { json, bin };
}

export function writeGLB(path, json, bin) {
  const jsonStr = JSON.stringify(json);
  const jsonPad = (4 - (jsonStr.length % 4)) % 4;
  const jsonBuf = Buffer.from(jsonStr + ' '.repeat(jsonPad), 'utf8');
  const binPad = (4 - bin.length % 4) % 4;
  const binBuf = Buffer.concat([bin, Buffer.alloc(binPad)]);

  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jsonBuf.length + 8 + binBuf.length, 8);

  const jsonChunkHeader = Buffer.alloc(8);
  jsonChunkHeader.writeUInt32LE(jsonBuf.length, 0);
  jsonChunkHeader.writeUInt32LE(0x4e4f534a, 4);

  const binChunkHeader = Buffer.alloc(8);
  binChunkHeader.writeUInt32LE(binBuf.length, 0);
  binChunkHeader.writeUInt32LE(0x004e4942, 4);

  writeFileSync(path, Buffer.concat([header, jsonChunkHeader, jsonBuf, binChunkHeader, binBuf]));
}

// ── accessors ────────────────────────────────────────────────────────────

const COMPONENT_SIZES = { 5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4 };
const TYPE_COUNTS = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };
const ARR_TYPES = { 5120: Int8Array, 5121: Uint8Array, 5122: Int16Array, 5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array };

export function readAccessor(json, bin, idx) {
  const acc = json.accessors[idx];
  const bv = json.bufferViews[acc.bufferView];
  const compSize = COMPONENT_SIZES[acc.componentType];
  const count = TYPE_COUNTS[acc.type];
  const base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0);
  const stride = bv.byteStride ?? compSize * count;
  const ArrType = ARR_TYPES[acc.componentType];
  const out = [];
  for (let i = 0; i < acc.count; i++) {
    const rowStart = base + i * stride;
    const row = [];
    for (let c = 0; c < count; c++) {
      const view = new ArrType(bin.buffer, bin.byteOffset + rowStart + c * compSize, 1);
      row.push(view[0]);
    }
    out.push(count === 1 ? row[0] : row);
  }
  return out;
}

/** Overwrite an accessor's bytes IN PLACE. `rows` must match its existing
 *  count/type/component exactly — this never resizes the buffer. */
export function writeAccessor(json, bin, idx, rows) {
  const acc = json.accessors[idx];
  const bv = json.bufferViews[acc.bufferView];
  const compSize = COMPONENT_SIZES[acc.componentType];
  const count = TYPE_COUNTS[acc.type];
  const base = (bv.byteOffset ?? 0) + (acc.byteOffset ?? 0);
  const stride = bv.byteStride ?? compSize * count;
  const ArrType = ARR_TYPES[acc.componentType];
  for (let i = 0; i < rows.length; i++) {
    const row = count === 1 ? [rows[i]] : rows[i];
    const rowStart = base + i * stride;
    for (let c = 0; c < count; c++) {
      const view = new ArrType(bin.buffer, bin.byteOffset + rowStart + c * compSize, 1);
      view[0] = row[c];
    }
  }
}

// ── bind-pose world transforms ──────────────────────────────────────────

function mat4FromTRS(t = [0, 0, 0], r = [0, 0, 0, 1], s = [1, 1, 1]) {
  const [x, y, z, w] = r;
  const x2 = x + x, y2 = y + y, z2 = z + z;
  const xx = x * x2, xy = x * y2, xz = x * z2;
  const yy = y * y2, yz = y * z2, zz = z * z2;
  const wx = w * x2, wy = w * y2, wz = w * z2;
  const [sx, sy, sz] = s;
  return [
    (1 - (yy + zz)) * sx, (xy + wz) * sx, (xz - wy) * sx, 0,
    (xy - wz) * sy, (1 - (xx + zz)) * sy, (yz + wx) * sy, 0,
    (xz + wy) * sz, (yz - wx) * sz, (1 - (xx + yy)) * sz, 0,
    t[0], t[1], t[2], 1,
  ];
}
function mat4Mul(a, b) {
  const out = new Array(16).fill(0);
  for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) {
    let sum = 0;
    for (let k = 0; k < 4; k++) sum += a[k * 4 + r] * b[c * 4 + k];
    out[c * 4 + r] = sum;
  }
  return out;
}
function mat4LocalOf(node) {
  return node.matrix ?? mat4FromTRS(node.translation, node.rotation, node.scale);
}

/** World transform (column-major 16-array) for every node index, bind pose. */
export function computeWorldTransforms(json) {
  const world = new Array(json.nodes.length).fill(null);
  const parent = new Array(json.nodes.length).fill(-1);
  json.nodes.forEach((n, i) => { for (const c of n.children ?? []) parent[c] = i; });
  const roots = json.nodes.map((_, i) => i).filter((i) => parent[i] === -1);
  function visit(i, parentWorld) {
    const w = parentWorld ? mat4Mul(parentWorld, mat4LocalOf(json.nodes[i])) : mat4LocalOf(json.nodes[i]);
    world[i] = w;
    for (const c of json.nodes[i].children ?? []) visit(c, w);
  }
  for (const r of roots) visit(r, null);
  return world;
}

export function worldPos(world, i) { const m = world[i]; return [m[12], m[13], m[14]]; }
export function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]); }

export function distToSegment(p, a, b) {
  const ab = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
  const ap = [p[0] - a[0], p[1] - a[1], p[2] - a[2]];
  const abLen2 = ab[0] ** 2 + ab[1] ** 2 + ab[2] ** 2;
  let t = abLen2 > 1e-9 ? (ap[0] * ab[0] + ap[1] * ab[1] + ap[2] * ab[2]) / abLen2 : 0;
  t = Math.max(0, Math.min(1, t));
  const proj = [a[0] + ab[0] * t, a[1] + ab[1] * t, a[2] + ab[2] * t];
  return dist(p, proj);
}

// ── diagnosis: dominant bone per mesh, same measurement as SkinWeightAudit ──

export function dominantBoneTally(json, bin, mesh) {
  const skin = json.skins[0];
  const prim = mesh.primitives[0];
  const joints = readAccessor(json, bin, prim.attributes.JOINTS_0);
  const weights = readAccessor(json, bin, prim.attributes.WEIGHTS_0);
  const tally = new Map();
  for (let i = 0; i < joints.length; i++) {
    let best = 0, bi = 0;
    for (let k = 0; k < 4; k++) if (weights[i][k] > best) { best = weights[i][k]; bi = joints[i][k]; }
    const name = json.nodes[skin.joints[bi]]?.name ?? `#${bi}`;
    tally.set(name, (tally.get(name) ?? 0) + 1);
  }
  const total = joints.length;
  return [...tally.entries()].sort((a, b) => b[1] - a[1]).map(([name, n]) => ({ name, n, share: n / total }));
}

// ── repair: proximity-based re-skinning ─────────────────────────────────

const K = 4;         // glTF JOINTS_0/WEIGHTS_0 is always 4 wide
const POWER = 2.2;   // inverse-distance falloff sharpness

/** Bone segments: one per (parent joint, child joint) pair, plus a
 *  degenerate point-segment for any joint with no child joint (fingertips,
 *  toe base, head-top) so leaf-adjacent vertices still have somewhere to
 *  bind. */
export function buildSegments(json, world) {
  const skin = json.skins[0];
  const localOfNode = new Map(skin.joints.map((n, li) => [n, li]));
  const parentOf = new Map();
  json.nodes.forEach((n, i) => { for (const c of n.children ?? []) parentOf.set(c, i); });

  const segments = [];
  for (const childNode of skin.joints) {
    const parentNode = parentOf.get(childNode);
    if (parentNode !== undefined && localOfNode.has(parentNode)) {
      segments.push({ a: worldPos(world, parentNode), b: worldPos(world, childNode), localJoint: localOfNode.get(parentNode) });
    }
  }
  const hasChildSegment = new Set(segments.map((s) => s.localJoint));
  for (const [node, li] of localOfNode) {
    if (!hasChildSegment.has(li)) { const p = worldPos(world, node); segments.push({ a: p, b: p, localJoint: li }); }
  }
  return segments;
}

export function nearestJointWeights(p, segments) {
  const best = new Map();
  for (const s of segments) {
    const d = distToSegment(p, s.a, s.b);
    const cur = best.get(s.localJoint);
    if (cur === undefined || d < cur) best.set(s.localJoint, d);
  }
  const arr = [...best.entries()].map(([li, d]) => ({ li, d })).sort((a, b) => a.d - b.d).slice(0, K);
  const weights = arr.map((x) => 1 / (x.d + 1e-4) ** POWER);
  const sum = weights.reduce((a, b) => a + b, 0);
  const joints = [0, 0, 0, 0], wts = [0, 0, 0, 0];
  arr.forEach((x, i) => { joints[i] = x.li; wts[i] = weights[i] / sum; });
  return { joints, wts };
}

/** Re-skin one mesh's primitives in place (mutates `bin`). Returns vertex count fixed. */
export function reskinMesh(json, bin, mesh, world) {
  const segments = buildSegments(json, world);
  let n = 0;
  for (const prim of mesh.primitives) {
    if (prim.attributes.JOINTS_0 === undefined) continue;
    const positions = readAccessor(json, bin, prim.attributes.POSITION);
    const newJoints = [], newWeights = [];
    for (const p of positions) {
      const { joints, wts } = nearestJointWeights(p, segments);
      newJoints.push(joints); newWeights.push(wts);
    }
    writeAccessor(json, bin, prim.attributes.JOINTS_0, newJoints);
    writeAccessor(json, bin, prim.attributes.WEIGHTS_0, newWeights);
    n += positions.length;
  }
  return n;
}

// ── CLI ──────────────────────────────────────────────────────────────────

if (import.meta.url === `file://${process.argv[1]}`) {
  const [, , cmd, inPath, outOrMesh, meshArg] = process.argv;
  if (cmd === 'inspect') {
    const { json, bin } = readGLB(inPath);
    console.log(`${inPath} — ${json.nodes.length} nodes, ${json.meshes.length} meshes, ${json.skins?.length ?? 0} skins`);
    for (const mesh of json.meshes) {
      if (!mesh.primitives.some((p) => p.attributes.JOINTS_0 !== undefined)) continue;
      const rows = dominantBoneTally(json, bin, mesh);
      console.log(`\n  ${mesh.name} — ${rows.reduce((a, r) => a + r.n, 0)} vertices, dominant bone:`);
      for (const r of rows.slice(0, 6)) console.log(`    ${r.name.padEnd(28)} ${(r.share * 100).toFixed(1)}%`);
    }
  } else if (cmd === 'reskin') {
    const { json, bin } = readGLB(inPath);
    const world = computeWorldTransforms(json);
    const targets = meshArg ? json.meshes.filter((m) => m.name === meshArg) : json.meshes;
    let total = 0;
    for (const mesh of targets) total += reskinMesh(json, bin, mesh, world);
    writeGLB(outOrMesh, json, bin);
    console.log(`re-skinned ${targets.length} mesh(es), ${total} vertices -> ${outOrMesh}`);
  } else {
    console.log('usage: glb_reskin.mjs inspect <file.glb>');
    console.log('       glb_reskin.mjs reskin <in.glb> <out.glb> [meshName]');
    process.exit(1);
  }
}
