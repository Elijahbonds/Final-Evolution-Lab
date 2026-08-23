// node --experimental-strip-types tests/anim_test.ts
//
// Covers the pure logic of the M80 animation pipeline: the T-pose measurement,
// its diagnosis, the manifest, and prefix stripping. Nothing here needs a
// browser or a Babylon scene — which is exactly why it can be run before a
// drop rather than discovered after one.

import { armSpreadDegrees, diagnose, type PoseSample } from '../anim/PoseProbe.ts';
import {
  CLIP_MANIFEST, ALL_CLIP_IDS, clipSources, priorityOrder, sourcesPresent,
  unknownClips, ANIM_ROOT,
} from '../anim/clipManifest.ts';
// From boneNames, not ExternalClipLoader: the loader imports Babylon, which
// does not exist outside the app. Keeping the naming rule dependency-free is
// what makes it testable here at all.
import { stripPrefix, isPrefixed, REQUIRED_BONES } from '../anim/boneNames.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// ── armSpreadDegrees: the T-pose measurement ─────────────────────────────
const S = { x: 0, y: 1.4, z: 0 };
const deg = (h: { x: number; y: number; z: number }) => armSpreadDegrees(S, h);

ok('arm hanging straight down = 0°', Math.abs(deg({ x: 0, y: 0.9, z: 0 })) < 0.01);
ok('arm straight out sideways = 90°', Math.abs(deg({ x: 0.5, y: 1.4, z: 0 }) - 90) < 0.01);
ok('arm straight up = 180°', Math.abs(deg({ x: 0, y: 1.9, z: 0 }) - 180) < 0.01);
ok('arm out and down = 45°', Math.abs(deg({ x: 0.5, y: 0.9, z: 0 }) - 45) < 0.01);
ok('forward reach is also 90° (axis-agnostic)', Math.abs(deg({ x: 0, y: 1.4, z: 0.5 }) - 90) < 0.01);
ok('degenerate zero-length arm does not NaN', deg(S) === 0);
ok('a natural rest arm reads below the T-pose threshold', deg({ x: 0.18, y: 0.95, z: 0.05 }) < 55);
ok('a bind-pose arm reads above it', deg({ x: 0.55, y: 1.38, z: 0 }) > 55);

// ── diagnose: three causes that look identical on screen ─────────────────
const smp = (o: Partial<PoseSample>): PoseSample =>
  ({ armSpread: 88, playing: ['idle_stand'], boundBones: 12, ...o });

ok('a healthy pose diagnoses to nothing', diagnose(smp({ armSpread: 20 })) === null);
ok('threshold is exclusive below 55°', diagnose(smp({ armSpread: 54.9 })) === null);
ok('55° trips it', diagnose(smp({ armSpread: 55 })) !== null);

const noClip = diagnose(smp({ playing: [] }))!;
ok('no clip playing → blames mode logic', /NO animation group/.test(noClip));
ok('no clip playing → names the fix', /neverBindPose/.test(noClip));

const noBones = diagnose(smp({ boundBones: 0 }))!;
ok('clip playing but zero bones → blames bone names', /ZERO bones/.test(noBones));
ok('clip playing but zero bones → points at clip_check', /clip_check/.test(noBones));

const thinClip = diagnose(smp({}))!;
ok('clip playing and bound → blames the keys', /KEYS are the problem/.test(thinClip));
ok('thin clip diagnosis names the clip', /idle_stand/.test(thinClip));
ok('the three causes give three different messages',
  new Set([noClip, noBones, thinClip]).size === 3);
ok('the reported angle is in the message', /88°/.test(thinClip));

// ── the manifest ─────────────────────────────────────────────────────────
ok('manifest is non-empty', CLIP_MANIFEST.length > 20);
ok('no duplicate clip ids', new Set(ALL_CLIP_IDS).size === ALL_CLIP_IDS.length);
ok('every id is snake_case and file-safe',
  ALL_CLIP_IDS.every((id) => /^[a-z0-9_]+$/.test(id)),
  ALL_CLIP_IDS.filter((id) => !/^[a-z0-9_]+$/.test(id)).join(','));
ok('every entry declares at least one consumer',
  CLIP_MANIFEST.every((c) => c.usedBy.length > 0));

const srcs = clipSources();
ok('clipSources covers the whole manifest', srcs.length === CLIP_MANIFEST.length);
ok('url is exactly ANIM_ROOT/<id>.glb — the naming contract',
  srcs.every((s) => s.url === `${ANIM_ROOT}/${s.id}.glb`));

// ── priority: what to record first ───────────────────────────────────────
const pri = priorityOrder();
ok('priorityOrder returns every clip', pri.length === CLIP_MANIFEST.length);
ok('the top pick wants mocap', pri[0].wantsMocap === true);
ok('a universal clip outranks a single-mode clip',
  pri.findIndex((c) => c.id === 'run') < pri.findIndex((c) => c.id === 'dunk_360_eastbay'));
ok('clips that do not want mocap sink to the bottom',
  pri.slice(-4).every((c) => c.wantsMocap === false));
ok('priorityOrder does not mutate the manifest', CLIP_MANIFEST[0].id === 'idle_stand');

// ── partial drops ────────────────────────────────────────────────────────
const present = sourcesPresent(['run', 'walk', 'not_a_clip']);
ok('sourcesPresent keeps only known ids', present.length === 2);
ok('sourcesPresent builds correct urls',
  present[0].url === `${ANIM_ROOT}/run.glb`);
ok('unknownClips catches the typo', unknownClips(['run', 'jumpshoot']).join() === 'jumpshoot');
ok('unknownClips is empty for a clean drop', unknownClips(['run', 'walk']).length === 0);
ok('an empty drop is not an error', sourcesPresent([]).length === 0);

// ── prefix stripping, shared with clip_check.mjs ─────────────────────────
ok('mixamorig: stripped', stripPrefix('mixamorig:Hips') === 'Hips');
ok('mixamorig1: stripped', stripPrefix('mixamorig1:LeftArm') === 'LeftArm');
// FEL's OWN base mesh (male_athlete_base_model_fbx — the character behind
// dunk and eleven other modes) is prefixed mixamorig10:, not mixamorig: or
// mixamorig1:. Confirmed by downloading the real source FBX and reading its
// converted glTF joint names directly. KNOWN_PREFIXES used to be an
// enumerated literal list that stopped at "1" and silently failed to strip
// this asset's bones — every lookup against it would have returned the
// prefixed name unchanged and matched nothing in the running game.
ok('mixamorig10: stripped — THE REAL PREFIX ON FEL\'S PRODUCTION BASE MESH',
  stripPrefix('mixamorig10:Head') === 'Head');
ok('and so is mixamorig2, mixamorig23, any digit run — this is a rule, not a list',
  stripPrefix('mixamorig2:RightUpLeg') === 'RightUpLeg'
  && stripPrefix('mixamorig23:Neck') === 'Neck');
ok('Armature| stripped', stripPrefix('Armature|Spine') === 'Spine');
ok('root| stripped', stripPrefix('root|Neck') === 'Neck');
ok('underscore form stripped', stripPrefix('mixamorig_RightFoot') === 'RightFoot');
ok('Armature_ form stripped', stripPrefix('Armature_Hips') === 'Hips');
ok('a clean name is untouched', stripPrefix('LeftForeArm') === 'LeftForeArm');
ok('a name that merely contains a keyword is untouched',
  stripPrefix('LeftHandIndex1') === 'LeftHandIndex1');

ok('isPrefixed agrees with stripPrefix',
  isPrefixed('mixamorig:Hips') && !isPrefixed('Hips'));

// ── DRIFT GUARD: the rule lives in three files and must not diverge ──────
// clip_check.mjs cannot import TypeScript, so it copies the list. This is the
// test that makes the copy safe. Without it, a bone added here and forgotten
// there means the offline checker green-lights a file the game rejects.
const mirror = await import('../tools/clip_check.mjs');
ok('clip_check.mjs REQUIRED_BONES matches boneNames.ts',
  mirror.REQUIRED_BONES.join() === REQUIRED_BONES.join(),
  `${mirror.REQUIRED_BONES.length} vs ${REQUIRED_BONES.length}`);
ok('clip_check.mjs stripPrefix matches boneNames.ts',
  ['mixamorig:Hips', 'Armature|Spine', 'mixamorig_Neck', 'root|Head', 'LeftHandIndex1', 'Hips']
    .every((n) => mirror.stripPrefix(n) === stripPrefix(n)));

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
