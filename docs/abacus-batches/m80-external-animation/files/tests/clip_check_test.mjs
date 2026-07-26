#!/usr/bin/env node
// clip_check_test.mjs — run:  node tests/clip_check_test.mjs
//
// Builds real GLB byte streams in memory (header + JSON chunk, correctly
// padded) and runs the checker over them. Not mocks — if the container parser
// is wrong these fail, which is the point: this tool's whole job is to be
// trusted about a file nobody can eyeball.

import assert from 'node:assert/strict';
import { parseGlbJson, inspect, verdict, stripPrefix, parseManifestIds } from '../tools/clip_check.mjs';
import { readFile } from 'node:fs/promises';

let passed = 0;
const t = (name, fn) => {
  try { fn(); passed++; }
  catch (e) { console.error(`✗ ${name}\n  ${e.message}`); process.exitCode = 1; }
};

/** Pack a glTF JSON object into a spec-correct GLB buffer. */
function glb(gltf) {
  const json = Buffer.from(JSON.stringify(gltf), 'utf8');
  const pad = (4 - (json.length % 4)) % 4;
  const chunk = Buffer.concat([json, Buffer.alloc(pad, 0x20)]); // pad with spaces
  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + chunk.length, 8);
  const chunkHead = Buffer.alloc(8);
  chunkHead.writeUInt32LE(chunk.length, 0);
  chunkHead.writeUInt32LE(0x4e4f534a, 4);
  return Buffer.concat([header, chunkHead, chunk]);
}

/** A minimal but structurally honest animation file. */
function clipGltf(boneNames, { paths = ['rotation'], meshes = 0, animations = 1 } = {}) {
  const nodes = boneNames.map((name) => ({ name }));
  const anims = [];
  for (let a = 0; a < animations; a++) {
    const channels = [];
    boneNames.forEach((_, i) => {
      for (const p of paths) channels.push({ sampler: 0, target: { node: i, path: p } });
    });
    anims.push({ name: `clip${a}`, channels, samplers: [{ input: 0, output: 1 }] });
  }
  return {
    asset: { version: '2.0' },
    nodes,
    skins: [{ joints: boneNames.map((_, i) => i) }],
    animations: anims,
    meshes: Array.from({ length: meshes }, (_, i) => ({ name: `mesh${i}` })),
  };
}

const FEL = ['Hips', 'Spine', 'LeftArm', 'RightArm', 'LeftUpLeg', 'RightUpLeg'];
const MIXAMO = FEL.map((b) => `mixamorig:${b}`);

// ── container ────────────────────────────────────────────────────────────
t('parses a well-formed GLB', () => {
  const g = parseGlbJson(glb(clipGltf(FEL)));
  assert.equal(g.nodes.length, 6);
});

t('parses a JSON .gltf too', () => {
  const g = parseGlbJson(Buffer.from(JSON.stringify(clipGltf(FEL)), 'utf8'));
  assert.equal(g.animations.length, 1);
});

t('padding does not corrupt the JSON', () => {
  // exercise all four alignments
  for (const extra of ['', 'a', 'ab', 'abc']) {
    const src = clipGltf(FEL);
    src.asset.generator = `x${extra}`;
    assert.equal(parseGlbJson(glb(src)).asset.generator, `x${extra}`);
  }
});

t('rejects a non-GLB', () => {
  assert.throws(() => parseGlbJson(Buffer.from('not a model at all')), /not a GLB/);
});

t('rejects glTF 1.0', () => {
  const b = glb(clipGltf(FEL));
  b.writeUInt32LE(1, 4);
  assert.throws(() => parseGlbJson(b), /version 1/);
});

// ── prefix stripping ─────────────────────────────────────────────────────
t('strips every known prefix form', () => {
  assert.equal(stripPrefix('mixamorig:Hips'), 'Hips');
  assert.equal(stripPrefix('mixamorig1:LeftArm'), 'LeftArm');
  assert.equal(stripPrefix('mixamorig_Spine'), 'Spine');
  assert.equal(stripPrefix('Armature|Hips'), 'Hips');
  assert.equal(stripPrefix('Armature_Hips'), 'Hips');
  assert.equal(stripPrefix('Hips'), 'Hips');
});

t('does not mangle an already-clean name containing a known word', () => {
  assert.equal(stripPrefix('LeftHand'), 'LeftHand');
  assert.equal(stripPrefix('Head'), 'Head');
});

// ── the verdict ──────────────────────────────────────────────────────────
t('a conformed clip passes', () => {
  const v = verdict(inspect(clipGltf(FEL)));
  assert.equal(v.ok, true, v.problems.join('; '));
  assert.equal(v.matched.length, 6);
});

t('THE BIG ONE: a prefixed clip fails and says why', () => {
  const v = verdict(inspect(clipGltf(MIXAMO)));
  assert.equal(v.ok, false);
  assert.match(v.problems.join('\n'), /PREFIXED/);
  assert.match(v.problems.join('\n'), /fel_conform\.py/);
});

t('a clip with no animations fails', () => {
  const v = verdict(inspect(clipGltf(FEL, { animations: 0 })));
  assert.equal(v.ok, false);
  assert.match(v.problems.join('\n'), /NO ANIMATIONS/);
});

t('unprefixed but foreign names fail distinctly', () => {
  const v = verdict(inspect(clipGltf(['bone_01', 'bone_02', 'pelvis'])));
  assert.equal(v.ok, false);
  assert.match(v.problems.join('\n'), /ZERO canonical bones/);
  assert.doesNotMatch(v.problems.join('\n'), /PREFIXED/);
});

t('multi-clip file passes but is called out', () => {
  const v = verdict(inspect(clipGltf(FEL, { animations: 3 })));
  assert.equal(v.ok, true);
  assert.match(v.notes.join('\n'), /3 animations in one file/);
});

t('mesh payload is a note, not a failure', () => {
  const v = verdict(inspect(clipGltf(FEL, { meshes: 2 })));
  assert.equal(v.ok, true);
  assert.match(v.notes.join('\n'), /2 mesh/);
});

t('missing Hips is a note, not a failure', () => {
  const v = verdict(inspect(clipGltf(['Spine', 'LeftArm', 'RightArm'])));
  assert.equal(v.ok, true);
  assert.match(v.notes.join('\n'), /no Hips track/);
});

t('finger bones are reported as ignorable', () => {
  const v = verdict(inspect(clipGltf([...FEL, 'LeftHandIndex1', 'LeftHandIndex2'])));
  assert.equal(v.ok, true);
  assert.match(v.notes.join('\n'), /2 bone\(s\) this rig does not have/);
});

t('position-only tracks are still reported as paths', () => {
  const info = inspect(clipGltf(FEL, { paths: ['position', 'rotation'] }));
  assert.deepEqual(info.animations[0].paths.sort(), ['position', 'rotation']);
});

t('channel and bone counts are distinct', () => {
  const info = inspect(clipGltf(FEL, { paths: ['position', 'rotation', 'scale'] }));
  assert.equal(info.animations[0].bones.length, 6);
  assert.equal(info.animations[0].channelCount, 18);
});

// ── manifest parsing (regex over real TypeScript — so, tested on the real
//    file, not a hand-written sample that could drift from it) ────────────
const manifestSrc = await readFile(new URL('../anim/clipManifest.ts', import.meta.url), 'utf8');

t('parses ids out of the real clipManifest.ts', () => {
  const ids = parseManifestIds(manifestSrc);
  assert.ok(ids, 'returned null on the real manifest');
  assert.ok(ids.length > 20, `only found ${ids.length}`);
  for (const expected of ['idle_stand', 'run', 'jumpshot', 'dunk_launch', 'high_kick']) {
    assert.ok(ids.includes(expected), `missing ${expected}`);
  }
});

t('does not pick up ids from prose or type declarations', () => {
  const ids = parseManifestIds(manifestSrc);
  // `id: string;` in the interface and the doc-comment examples must not match
  assert.ok(!ids.includes('string'));
  assert.equal(new Set(ids).size, ids.length, 'duplicate ids parsed');
});

t('returns null rather than an empty list when there is no manifest', () => {
  assert.equal(parseManifestIds('export const NOTHING = 1;'), null);
});

t('ignores ids that are not file-safe', () => {
  assert.equal(parseManifestIds("  { id: 'Not Safe', origin: 'glb' },"), null);
});

console.log(`\n${passed} passed${process.exitCode ? ' — WITH FAILURES' : ''}`);
