#!/usr/bin/env node
// clip_check.mjs — inspect a .glb BEFORE it goes anywhere near the game.
//
//     node tools/clip_check.mjs assets/ready/anim/dunk_launch.glb
//     node tools/clip_check.mjs assets/ready/anim/          # whole folder
//
// WHY THIS EXISTS
// The single most common way an external animation "doesn't fire" is that its
// bone names are still prefixed (`mixamorig:Hips`). FEL resolves bones by
// UNPREFIXED name, so a prefixed clip targets bones that do not exist,
// animates nothing, and leaves the character in bind pose — which looks
// exactly like the animation never loaded.
//
// You cannot see that by looking at the file, and you should not have to
// deploy to find out. This reads the glTF JSON chunk directly: no Blender, no
// Babylon, no npm install, no network. It reports the bone names, the
// animated channels, and whether the file will bind to the FEL rig.
//
// Exit 1 if any file would fail — so it can gate a drop.

import { readFile, readdir, stat } from 'node:fs/promises';
import path from 'node:path';

// MIRROR OF anim/boneNames.ts. This file must run with no npm install and no
// TypeScript, so it cannot import the real one — it copies it instead, and
// `tests/anim_test.ts` fails if the two ever disagree. `tools/fel_conform.py`
// is the third copy of the same list.
export const REQUIRED_BONES = [
  'Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head',
  'LeftShoulder', 'LeftArm', 'LeftForeArm', 'LeftHand',
  'RightShoulder', 'RightArm', 'RightForeArm', 'RightHand',
  'LeftUpLeg', 'LeftLeg', 'LeftFoot', 'LeftToeBase',
  'RightUpLeg', 'RightLeg', 'RightFoot', 'RightToeBase',
];

const KNOWN_PREFIXES = ['mixamorig:', 'mixamorig1:', 'Armature|', 'root|'];

export function stripPrefix(name) {
  for (const p of KNOWN_PREFIXES) {
    if (name.startsWith(p)) return name.slice(p.length);
  }
  const m = name.match(/^(?:mixamorig\d*|Armature)_(.+)$/);
  return m ? m[1] : name;
}

const GLB_MAGIC = 0x46546c67;   // 'glTF'
const CHUNK_JSON = 0x4e4f534a;  // 'JSON'

/**
 * Pull the JSON chunk out of a .glb.
 *
 * Handles the container only — the binary chunk holds keyframe values we do
 * not need to read. Everything this tool checks (names, channel targets,
 * paths) lives in the JSON.
 */
export function parseGlbJson(buf) {
  if (buf.length < 12) throw new Error('too short to be a GLB');
  const magic = buf.readUInt32LE(0);
  if (magic !== GLB_MAGIC) {
    // A .gltf (JSON, not binary) is a perfectly valid input — accept it.
    const text = buf.toString('utf8').trimStart();
    if (text.startsWith('{')) return JSON.parse(text);
    throw new Error('not a GLB (bad magic) and not JSON glTF');
  }
  const version = buf.readUInt32LE(4);
  if (version !== 2) throw new Error(`glTF version ${version}; FEL needs 2`);

  let off = 12;
  while (off + 8 <= buf.length) {
    const len = buf.readUInt32LE(off);
    const type = buf.readUInt32LE(off + 4);
    const start = off + 8;
    if (type === CHUNK_JSON) {
      return JSON.parse(buf.subarray(start, start + len).toString('utf8'));
    }
    off = start + len;
    // chunks are 4-byte aligned; length already includes padding per spec,
    // but be forgiving of exporters that do not pad.
    if (off % 4) off += 4 - (off % 4);
  }
  throw new Error('no JSON chunk found');
}

/**
 * Everything worth knowing about one animation file.
 *
 * `animatedBones` is the set that actually matters: a file can declare a
 * hundred joints and animate four of them.
 */
export function inspect(gltf) {
  const nodes = gltf.nodes ?? [];
  const nameOf = (i) => nodes[i]?.name ?? `<node ${i}>`;

  const jointIdx = new Set();
  for (const skin of gltf.skins ?? []) for (const j of skin.joints ?? []) jointIdx.add(j);

  const animations = (gltf.animations ?? []).map((a, i) => {
    const bones = new Set();
    const paths = new Set();
    for (const ch of a.channels ?? []) {
      if (ch.target?.node === undefined) continue;
      bones.add(nameOf(ch.target.node));
      if (ch.target.path) paths.add(ch.target.path);
    }
    return {
      name: a.name ?? `<animation ${i}>`,
      bones: [...bones],
      paths: [...paths],
      channelCount: (a.channels ?? []).length,
    };
  });

  const animatedBones = new Set();
  for (const a of animations) for (const b of a.bones) animatedBones.add(b);

  return {
    nodeCount: nodes.length,
    jointNames: [...jointIdx].map(nameOf),
    animations,
    animatedBones: [...animatedBones],
    meshCount: (gltf.meshes ?? []).length,
  };
}

/** Turn an inspection into pass/fail with reasons a human can act on. */
export function verdict(info) {
  const problems = [];
  const notes = [];

  if (info.animations.length === 0) {
    problems.push('NO ANIMATIONS. The exporter did not bake an action. '
      + 'In Blender: push the action down to an NLA strip, or enable '
      + '"Export Animations" with the action selected.');
  }
  if (info.animations.length > 1) {
    notes.push(`${info.animations.length} animations in one file — FEL loads the first `
      + `("${info.animations[0].name}"). Split into one file per clip.`);
  }

  const prefixed = info.animatedBones.filter((n) => stripPrefix(n) !== n);
  if (prefixed.length) {
    problems.push(`${prefixed.length}/${info.animatedBones.length} animated bones are PREFIXED `
      + `(e.g. "${prefixed[0]}"). FEL resolves bones by unprefixed name, so this clip would `
      + 'animate NOTHING and the character would stay in bind pose.\n'
      + '      FIX:  blender --background --python tools/fel_conform.py -- \\\n'
      + '              --input <this file> --output <same>.glb --strip-mesh');
  }

  // Which canonical bones does this clip actually drive?
  const driven = new Set(info.animatedBones.map(stripPrefix));
  const matched = REQUIRED_BONES.filter((b) => driven.has(b));
  const foreign = [...driven].filter((b) => !REQUIRED_BONES.includes(b));

  if (!prefixed.length && matched.length === 0 && info.animations.length) {
    problems.push('ZERO canonical bones driven. Names are unprefixed but do not match the FEL '
      + `rig at all. This clip drives: ${[...driven].slice(0, 8).join(', ')}. `
      + 'Compare against AvatarSkeletonSpec.md.');
  }

  if (info.meshCount > 0) {
    notes.push(`carries ${info.meshCount} mesh(es). Harmless — the loader discards them — but `
      + '--strip-mesh makes the file much smaller and the download faster.');
  }

  const hasHips = driven.has('Hips');
  if (matched.length && !hasHips) {
    notes.push('no Hips track — the clip will animate in place with no root motion. '
      + 'Correct for an idle or an upper-body action; wrong for a run or a jump.');
  }

  if (foreign.length) {
    notes.push(`${foreign.length} bone(s) this rig does not have (${foreign.slice(0, 4).join(', ')}`
      + `${foreign.length > 4 ? ', …' : ''}) — usually fingers or twist joints. Ignored at runtime.`);
  }

  return { ok: problems.length === 0, problems, notes, matched, foreign };
}

/**
 * Read the clip ids out of anim/clipManifest.ts by text.
 *
 * Yes, by regex. This tool must run with no TypeScript and no npm install,
 * and the alternative — not checking filenames at all — is worse: the loader
 * builds its URLs from manifest ids, so a file named `run_cycle.glb` is never
 * requested. It does not error. It does not 404. It is simply never loaded,
 * and the game keeps playing the procedural clip while a perfectly good mocap
 * file sits on disk. That is the exact silent failure this whole batch is
 * about, so it gets checked even by an imperfect method.
 *
 * Returns null if the manifest cannot be found — filename checking is then
 * skipped rather than guessed at.
 */
export function parseManifestIds(source) {
  const ids = [...source.matchAll(/^\s*\{\s*id:\s*'([a-z0-9_]+)'/gm)].map((m) => m[1]);
  return ids.length ? ids : null;
}

async function loadManifestIds(explicit) {
  const candidates = explicit ? [explicit] : [
    path.join(process.cwd(), 'anim/clipManifest.ts'),
    path.join(process.cwd(), 'src/anim/clipManifest.ts'),
    path.resolve(path.dirname(new URL(import.meta.url).pathname), '../anim/clipManifest.ts'),
  ];
  for (const c of candidates) {
    try { return parseManifestIds(await readFile(c, 'utf8')); } catch { /* next */ }
  }
  return null;
}

async function checkFile(file, manifestIds) {
  let info; let v;
  try {
    info = inspect(parseGlbJson(await readFile(file)));
    v = verdict(info);
  } catch (e) {
    console.log(`[CLIP] FAIL  ${file}`);
    console.log(`       unreadable: ${e.message}`);
    return false;
  }

  // The filename IS the clip id. A file the manifest does not name is never
  // requested by the loader — it fails by being IGNORED, which is invisible.
  // Decided before the header line: a file that prints PASS and then a reason
  // it will not work is worse than no tool at all.
  const problems = [...v.problems];
  if (manifestIds) {
    const id = path.basename(file).replace(/\.(glb|gltf)$/i, '');
    if (!manifestIds.includes(id)) {
      problems.push(`FILENAME "${id}" is not a clip id in anim/clipManifest.ts, so nothing will `
        + 'ever load it. It would not 404 — it would simply never be requested.\n'
        + `      FIX:  rename it to the clip it replaces, or add "${id}" to the manifest.`);
    }
  }

  const ok = problems.length === 0;
  console.log(`[CLIP] ${ok ? 'PASS' : 'FAIL'}  ${file}`);
  const a = info.animations[0];
  if (a) {
    console.log(`       "${a.name}" · ${a.channelCount} channels · ${a.bones.length} bones · `
      + `${a.paths.join('+') || 'no paths'}`);
  }
  console.log(`       ${v.matched.length}/${REQUIRED_BONES.length} canonical bones driven`);
  for (const p of problems) console.log(`       ✗ ${p}`);
  for (const n of v.notes) console.log(`       · ${n}`);
  return ok;
}

async function expand(target) {
  const s = await stat(target);
  if (!s.isDirectory()) return [target];
  const out = [];
  for (const e of await readdir(target, { withFileTypes: true })) {
    const p = path.join(target, e.name);
    if (e.isDirectory()) out.push(...await expand(p));
    else if (/\.(glb|gltf)$/i.test(e.name)) out.push(p);
  }
  return out.sort();
}

// Importable as a module (the tests do that) without running the CLI.
if (process.argv[1] && process.argv[1].endsWith('clip_check.mjs')) {
  const argv = process.argv.slice(2);
  const mi = argv.indexOf('--manifest');
  const manifestPath = mi >= 0 ? argv[mi + 1] : null;
  const noNames = argv.includes('--no-name-check');
  const targets = argv.filter((a, i) => !a.startsWith('--') && i !== mi + 1);

  if (!targets.length) {
    console.log('usage: node tools/clip_check.mjs [--manifest anim/clipManifest.ts] '
      + '[--no-name-check] <file.glb | folder> …');
    process.exit(2);
  }

  const manifestIds = noNames ? null : await loadManifestIds(manifestPath);
  if (!manifestIds && !noNames) {
    console.log('[CLIP] note: anim/clipManifest.ts not found — skipping the filename check. '
      + 'Pass --manifest <path> to enable it.\n');
  }

  const files = (await Promise.all(targets.map(expand))).flat();
  if (!files.length) {
    console.log('[CLIP] no .glb/.gltf files found. Nothing to check.');
    console.log('       Conformed animations belong in assets/ready/anim/.');
    process.exit(1);
  }

  let bad = 0;
  for (const f of files) if (!(await checkFile(f, manifestIds))) bad++;
  console.log(`\n[CLIP] ${files.length - bad}/${files.length} ready to drop`);
  if (bad) process.exit(1);
}
