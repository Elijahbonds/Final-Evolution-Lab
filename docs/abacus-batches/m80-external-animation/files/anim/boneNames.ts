// boneNames — the FEL bone-naming contract, in one place with no dependencies.
//
// This is deliberately its own file. The same rule has to hold in three
// places that cannot import each other: the runtime loader (needs Babylon),
// the offline checker (`tools/clip_check.mjs`, plain Node, no npm), and the
// Blender conform script (Python). Three copies of a rule is three chances to
// drift, and the failure mode when they drift is silent — a clip that passes
// the checker and animates nothing in the game.
//
// So: TypeScript owns it here, `clip_check.mjs` mirrors it, and
// `tools/fel_conform.py` mirrors it. If you change this list, change all
// three. `tests/anim_test.ts` checks this copy; `tests/clip_check_test.mjs`
// checks that one.

/**
 * Prefixes the common exporters put in front of every bone name.
 *
 * `mixamorig1:` used to be the only numbered variant listed here — that
 * missed `mixamorig10:`, which is the ACTUAL prefix on FEL's own production
 * base mesh (male_athlete_base_model_fbx, the character behind dunk, karate,
 * baseball and nine other modes). Mixamo appends an incrementing suffix each
 * time an asset is re-downloaded through its auto-rigger, so any single digit
 * or pair of digits is possible, not just "1". An enumerated literal list can
 * never cover that; `stripPrefix` below matches the digits with a regex and
 * this list is kept for the two prefixes that carry no digit at all.
 */
export const KNOWN_PREFIXES = ['Armature|', 'root|'];

/**
 * The canonical FEL rig. Must stay in sync with `REQUIRED_BONES` in
 * `tools/fel_conform.py`.
 */
export const REQUIRED_BONES = [
  'Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head',
  'LeftShoulder', 'LeftArm', 'LeftForeArm', 'LeftHand',
  'RightShoulder', 'RightArm', 'RightForeArm', 'RightHand',
  'LeftUpLeg', 'LeftLeg', 'LeftFoot', 'LeftToeBase',
  'RightUpLeg', 'RightLeg', 'RightFoot', 'RightToeBase',
];

/**
 * Reduce an exporter's bone name to the name FEL resolves by.
 *
 * Note what this does NOT do: rename. `pelvis` does not become `Hips` and
 * `upperarm_l` does not become `LeftArm`. A guessed mapping that is 90% right
 * produces motion that is subtly, unfixably wrong, and hides the fact that the
 * rig was never conformed. Renaming belongs in Blender, on purpose, once.
 */
export function stripPrefix(name: string): string {
  // `mixamorig`, then any run of digits (or none), then `:` or `_`. Covers
  // `mixamorig:`, `mixamorig1:`, `mixamorig10:`, `mixamorig_`, ... in one
  // rule instead of an enumerated list that is always one export behind.
  const mixamo = name.match(/^mixamorig\d*[:_](.+)$/i);
  if (mixamo) return mixamo[1];
  for (const p of KNOWN_PREFIXES) {
    if (name.startsWith(p)) return name.slice(p.length);
  }
  // Some exporters use `Armature_Hips` instead of `Armature|Hips`.
  const underscore = name.match(/^Armature_(.+)$/);
  return underscore ? underscore[1] : name;
}

/** True if this name would fail to resolve against the live skeleton as-is. */
export function isPrefixed(name: string): boolean {
  return stripPrefix(name) !== name;
}
