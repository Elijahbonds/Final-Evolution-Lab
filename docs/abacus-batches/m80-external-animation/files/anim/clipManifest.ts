// clipManifest — the list of clips the game plays, and where a real animation
// file for each one would live.
//
// THIS IS THE FILE YOU EDIT WHEN YOU BUY OR RECORD AN ANIMATION.
//
// Everything below is currently either (a) riding inside the character GLB or
// (b) hand-authored quaternion angles in code. Neither is mocap. Drop a
// conformed file at the listed path and it takes over automatically — no code
// change, no mode change. Remove the file and the procedural version comes
// back. That is deliberate: the game must never depend on an asset being
// present, because a 404 in the middle of a match is not recoverable.
//
// NAMING IS THE CONTRACT. `assets/ready/anim/<id>.glb` where <id> is exactly
// the clip id below. Not `Dunk Launch.glb`, not `dunk-launch.glb`.

import type { ClipSource } from './ExternalClipLoader';

/** Where conformed, animation-only files live. Served as a static asset. */
export const ANIM_ROOT = '/assets/ready/anim';

export type ClipOrigin = 'glb' | 'procedural';

export interface ClipEntry {
  id: string;
  /** Where the CURRENT version of this clip comes from. */
  origin: ClipOrigin;
  /** Modes that play it — so you can tell what a bad clip would break. */
  usedBy: string[];
  /** True where mocap is the obvious upgrade and the procedural version is
   *  visibly stiff. Sorted first by `priorityOrder()`. */
  wantsMocap: boolean;
}

// Ordered roughly by how much the game leans on each one.
export const CLIP_MANIFEST: ClipEntry[] = [
  // ── base locomotion: every 3-D mode falls back to these ────────────────
  { id: 'idle_stand',  origin: 'procedural', usedBy: ['*'], wantsMocap: true },
  { id: 'walk',        origin: 'glb',        usedBy: ['*'], wantsMocap: true },
  { id: 'run',         origin: 'glb',        usedBy: ['*'], wantsMocap: true },
  { id: 'strafe_left', origin: 'procedural', usedBy: ['*'], wantsMocap: true },
  { id: 'strafe_right',origin: 'procedural', usedBy: ['*'], wantsMocap: true },
  { id: 'jump_up',     origin: 'procedural', usedBy: ['*'], wantsMocap: false },
  { id: 'jump_land',   origin: 'procedural', usedBy: ['*'], wantsMocap: false },

  // ── basketball ────────────────────────────────────────────────────────
  { id: 'jumpshot',           origin: 'glb',        usedBy: ['onevone', 'threevthree', 'simulator'], wantsMocap: true },
  { id: 'dunk_charge_gather', origin: 'procedural', usedBy: ['dunk'], wantsMocap: true },
  { id: 'dunk_launch',        origin: 'procedural', usedBy: ['dunk'], wantsMocap: true },
  { id: 'dunk_360_eastbay',   origin: 'procedural', usedBy: ['dunk'], wantsMocap: true },
  { id: 'dunk_score_hang',    origin: 'procedural', usedBy: ['dunk'], wantsMocap: true },
  { id: 'dunk_land_crouch',   origin: 'procedural', usedBy: ['dunk'], wantsMocap: true },

  // ── combat ────────────────────────────────────────────────────────────
  { id: 'guard',            origin: 'glb',        usedBy: ['karate', 'karate-vs'], wantsMocap: false },
  { id: 'jab',              origin: 'glb',        usedBy: ['karate', 'karate-vs'], wantsMocap: true },
  { id: 'hook',             origin: 'glb',        usedBy: ['karate', 'karate-vs'], wantsMocap: true },
  { id: 'uppercut',         origin: 'glb',        usedBy: ['karate', 'karate-vs'], wantsMocap: true },
  { id: 'high_kick',        origin: 'glb',        usedBy: ['karate', 'karate-vs'], wantsMocap: true },
  { id: 'roundhouse',       origin: 'glb',        usedBy: ['karate', 'karate-vs'], wantsMocap: true },
  { id: 'karate_hit_react', origin: 'procedural', usedBy: ['karate', 'karate-vs'], wantsMocap: false },
  { id: 'karate_knockdown', origin: 'procedural', usedBy: ['karate', 'karate-vs'], wantsMocap: false },

  // ── football ──────────────────────────────────────────────────────────
  { id: 'football_juke_left',    origin: 'procedural', usedBy: ['football'], wantsMocap: true },
  { id: 'football_juke_right',   origin: 'procedural', usedBy: ['football'], wantsMocap: true },
  { id: 'football_spin_move',    origin: 'procedural', usedBy: ['football'], wantsMocap: true },
  { id: 'football_tackled_fall', origin: 'procedural', usedBy: ['football'], wantsMocap: false },
];

/** Every clip id the game can play. */
export const ALL_CLIP_IDS = CLIP_MANIFEST.map((c) => c.id);

/** Turn the manifest into loader input. */
export function clipSources(ids: string[] = ALL_CLIP_IDS): ClipSource[] {
  return ids.map((id) => ({ id, url: `${ANIM_ROOT}/${id}.glb` }));
}

/**
 * What to buy or record first.
 *
 * `usedBy: ['*']` clips come first because they play in every mode: one good
 * run cycle changes the whole product, one good dunk changes one screen.
 */
export function priorityOrder(): ClipEntry[] {
  const score = (c: ClipEntry) =>
    (c.wantsMocap ? 0 : 100) + (c.usedBy.includes('*') ? 0 : 10) - c.usedBy.length;
  return [...CLIP_MANIFEST].sort((a, b) => score(a) - score(b));
}

/**
 * Only ask the network for files that plausibly exist.
 *
 * Requesting all 25 on every load means 25 requests and up to 25 404s in the
 * console before the first frame. `loadedIds` should come from a directory
 * listing or a small index file written when clips are dropped.
 */
export function sourcesPresent(available: string[]): ClipSource[] {
  const known = new Set(ALL_CLIP_IDS);
  return available.filter((id) => known.has(id)).map((id) => ({ id, url: `${ANIM_ROOT}/${id}.glb` }));
}

/** Ids in `available` that no mode plays — a typo in a filename, usually. */
export function unknownClips(available: string[]): string[] {
  const known = new Set(ALL_CLIP_IDS);
  return available.filter((id) => !known.has(id));
}
