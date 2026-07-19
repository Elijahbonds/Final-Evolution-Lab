// clipResolver — maps the registry's ~60 clip names onto whatever the loaded GLB
// actually contains, with per-alias timeScale. Wire INSIDE the existing character
// hook's play(): resolve first, then look up the action.
//
//   // in play(name, opts):
//   const r = resolveClip(name, clipNames);
//   const action = actionMap.get(r.clip);
//   const timeScale = (opts?.timeScale ?? 1) * r.timeScale;
//
// Missing clips are IMPOSSIBLE to miss now: loud console.error + on-screen dev
// counter, and a guaranteed fallback so the character never freezes in bind pose.

export interface ResolvedClip { clip: string; timeScale: number; exact: boolean }

/** registry name → [asset clip, timeScale]. Current asset: elijah-hero.glb
 *  { guard, high_kick, hook, jab, jumpshot, roundhouse, run, walk, uppercut } */
const ALIASES: Record<string, [string, number]> = {
  // locomotion
  idle_stand:            ['guard', 0.45],   // slow guard sway reads as idle until authored idle lands
  walk_forward:          ['walk', 1.0],
  run_forward:           ['run', 1.0],
  run_backward:          ['run', -1.0],     // negative timeScale = reverse playback
  sprint_forward:        ['run', 1.4],
  jump_up:               ['jumpshot', 1.1], // launch portion reads as a two-foot jump
  jump_land:             ['guard', 1.6],
  fall_loop:             ['guard', 0.6],
  strafe_left:           ['walk', 1.1],
  strafe_right:          ['walk', 1.1],
  // dunk (until authoredClips register the real suite)
  dunk_approach_run:     ['run', 1.2],
  dunk_charge_gather:    ['guard', 1.2],
  dunk_launch:           ['jumpshot', 1.0],
  dunk_airborne_float:   ['jumpshot', 0.35],
  dunk_score_hang:       ['jumpshot', 0.5],
  dunk_land_crouch:      ['guard', 1.4],
  dunk_360_scoop:        ['jumpshot', 0.8],
  dunk_360_eastbay:      ['jumpshot', 0.8],
  dunk_360_fake_eastbay: ['jumpshot', 0.8],
  dunk_off_board_windmill: ['jumpshot', 0.8],
  // karate — these SHOULD have been direct hits; asset names differ
  karate_idle_stance:    ['guard', 0.8],
  karate_punch_light:    ['jab', 1.1],
  karate_punch_heavy:    ['hook', 0.95],
  karate_kick_roundhouse:['roundhouse', 1.0],
  karate_counter_throw:  ['uppercut', 0.9],
  karate_block:          ['guard', 1.6],
  karate_dodge_roll:     ['guard', 1.3],
  karate_hit_react:      ['guard', 2.0],
  karate_knockdown:      ['guard', 0.8],
  karate_victory_pose:   ['uppercut', 0.6],
  // basketball
  bball_dribble_run:     ['run', 0.9],
  bball_shoot_jumper:    ['jumpshot', 1.0],
  bball_score_celebrate: ['uppercut', 0.8],
  bball_defend_stance:   ['guard', 0.7],
  bball_block_reach:     ['jumpshot', 1.2],
  // football
  football_sprint_return:['run', 1.35],
  football_juke_left:    ['walk', 1.8],
  football_juke_right:   ['walk', 1.8],
  football_spin_move:    ['roundhouse', 1.2],
  football_stiff_arm:    ['jab', 0.8],
  football_touchdown_spike: ['uppercut', 0.9],
  football_tackled_fall: ['guard', 1.2],
  // soccer
  soccer_dribble_jog:    ['run', 0.85],
  soccer_kick_shoot:     ['high_kick', 1.0],
  soccer_kick_pass:      ['high_kick', 1.3],
  soccer_tackle_slide:   ['guard', 1.2],
  soccer_goal_celebrate: ['uppercut', 0.8],
  soccer_header_jump:    ['jumpshot', 1.1],
  // golf / baseball — swings alias to hook (horizontal power arc)
  golf_address_idle:     ['guard', 0.5],
  golf_swing_full:       ['hook', 0.7],
  golf_putt_stroke:      ['jab', 0.5],
  golf_fist_pump:        ['uppercut', 0.9],
  baseball_bat_stance:   ['guard', 0.6],
  baseball_swing_full:   ['hook', 0.85],
  baseball_contact_drive:['hook', 1.1],
  baseball_homer_trot:   ['run', 0.7],
  // board sports — rider poses until authored board clips land
  skate_idle_cruise:     ['guard', 0.5],
  skate_kickflip:        ['high_kick', 1.2],
  skate_heelflip:        ['high_kick', 1.1],
  skate_treflip:         ['roundhouse', 1.1],
  skate_bail:            ['guard', 1.5],
  snow_carve_loop:       ['guard', 0.5],
  snow_jump:             ['jumpshot', 1.0],
  snow_grab:             ['high_kick', 0.8],
  surf_carve_loop:       ['guard', 0.5],
  surf_aerial:           ['jumpshot', 0.9],
  surf_tube_loop:        ['guard', 0.4],
};

const FALLBACK: [string, number] = ['guard', 0.6];
const missing = new Set<string>();

export function resolveClip(name: string, available: string[]): ResolvedClip {
  if (available.includes(name)) return { clip: name, timeScale: 1, exact: true };

  const alias = ALIASES[name];
  if (alias && available.includes(alias[0])) {
    return { clip: alias[0], timeScale: alias[1], exact: false };
  }

  if (!missing.has(name)) {
    missing.add(name);
    // Loud by design — a silent null return is how the T-pose shipped three times.
    console.error(
      `[FEL-ANIM] MISSING CLIP "${name}" — no exact match and no alias into ` +
      `available clips [${available.join(', ')}]. Playing fallback "${FALLBACK[0]}". ` +
      `All missing so far: ${[...missing].join(', ')}`,
    );
  }
  const fb = available.includes(FALLBACK[0]) ? FALLBACK : [available[0], 1] as [string, number];
  return { clip: fb[0], timeScale: fb[1], exact: false };
}

/** Dev overlay hook: number of distinct unresolved clip names this session. */
export function missingClipCount(): number { return missing.size; }
export function missingClipList(): string[] { return [...missing]; }
