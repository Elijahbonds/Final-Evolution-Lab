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

/** Prefixes the common exporters put in front of every bone name. */
export const KNOWN_PREFIXES = ['mixamorig:', 'mixamorig1:', 'Armature|', 'root|'];

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
  for (const p of KNOWN_PREFIXES) {
    if (name.startsWith(p)) return name.slice(p.length);
  }
  // Some exporters use `Armature_Hips` or `mixamorig_Hips`.
  const underscore = name.match(/^(?:mixamorig\d*|Armature)_(.+)$/);
  return underscore ? underscore[1] : name;
}

/** True if this name would fail to resolve against the live skeleton as-is. */
export function isPrefixed(name: string): boolean {
  return stripPrefix(name) !== name;
}
