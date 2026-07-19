// Exercise library — the plan generator selects from these by targeted deficit.
// `clip` names must exist in the canonical-rig clip registry (author via the same
// pipeline as game Movie Events). Cues are conventional coaching cues — no
// unverified physiology claims (content-integrity rule).

import type { ExerciseDef } from './contracts';

export const EXERCISES: Record<string, ExerciseDef> = {
  // ── Mobility ─────────────────────────────────────────────────────────────
  worlds_greatest_stretch: {
    id: 'worlds_greatest_stretch', name: "World's Greatest Stretch",
    clip: 'ex.worlds_greatest_stretch', cameraTrack: 'side',
    targets: ['hip_mobility', 'ankle_mobility'], equipment: 'none',
    cues: ['Long spine over the front leg', 'Drive the back heel away', 'Rotate chest open'],
    progression: 'cossack_squat',
  },
  deep_squat_hold: {
    id: 'deep_squat_hold', name: 'Deep Squat Hold',
    clip: 'ex.deep_squat_hold', cameraTrack: 'side',
    targets: ['hip_mobility', 'ankle_mobility'], equipment: 'none',
    cues: ['Heels down', 'Knees track over toes', 'Chest tall'],
    tempo: '30s hold',
  },
  ankle_rock: {
    id: 'ankle_rock', name: 'Ankle Rockers',
    clip: 'ex.ankle_rock', cameraTrack: 'side',
    targets: ['ankle_mobility'], equipment: 'none',
    cues: ['Knee over pinky toe', 'Heel stays glued down'],
  },
  cossack_squat: {
    id: 'cossack_squat', name: 'Cossack Squat',
    clip: 'ex.cossack_squat', cameraTrack: 'front',
    targets: ['hip_mobility', 'symmetry'], equipment: 'none',
    cues: ['Sit into one hip', 'Opposite leg long', 'Heel down on the working side'],
    regression: 'deep_squat_hold',
  },

  // ── Stability / control ──────────────────────────────────────────────────
  goblet_squat: {
    id: 'goblet_squat', name: 'Goblet Squat',
    clip: 'ex.goblet_squat', cameraTrack: 'side',
    targets: ['knee_stability', 'trunk_control', 'hip_mobility'], equipment: 'dumbbell',
    cues: ['Elbows inside knees at depth', 'Push the floor apart', 'Stand tall through the crown'],
    tempo: '3-1-1', progression: 'rear_foot_split_squat',
  },
  rear_foot_split_squat: {
    id: 'rear_foot_split_squat', name: 'Rear-Foot Elevated Split Squat',
    clip: 'ex.rfe_split_squat', cameraTrack: 'side',
    targets: ['knee_stability', 'symmetry', 'hip_stability'], equipment: 'box',
    cues: ['Front shin vertical-ish', 'Hips square', 'Drive through mid-foot'],
    regression: 'split_squat',
  },
  split_squat: {
    id: 'split_squat', name: 'Split Squat',
    clip: 'ex.split_squat', cameraTrack: 'side',
    targets: ['knee_stability', 'symmetry'], equipment: 'none',
    cues: ['Back knee kisses the floor', 'Front knee tracks the toe'],
    progression: 'rear_foot_split_squat',
  },
  lateral_band_walk: {
    id: 'lateral_band_walk', name: 'Lateral Band Walk',
    clip: 'ex.lateral_band_walk', cameraTrack: 'front',
    targets: ['hip_stability', 'knee_stability'], equipment: 'band',
    cues: ['Stay low', 'Knees pushed out against the band', 'Steps small and controlled'],
  },
  single_leg_rdl: {
    id: 'single_leg_rdl', name: 'Single-Leg RDL',
    clip: 'ex.single_leg_rdl', cameraTrack: 'side',
    targets: ['hip_stability', 'symmetry', 'trunk_control'], equipment: 'dumbbell',
    cues: ['Hips stay square to the floor', 'Long line crown-to-heel', 'Soft knee, load the hip'],
  },
  dead_bug: {
    id: 'dead_bug', name: 'Dead Bug',
    clip: 'ex.dead_bug', cameraTrack: 'orbit',
    targets: ['trunk_control'], equipment: 'none',
    cues: ['Low back stays pressed down', 'Opposite arm and leg reach long', 'Exhale on the reach'],
    progression: 'plank_reach',
  },
  plank_reach: {
    id: 'plank_reach', name: 'Plank with Reach',
    clip: 'ex.plank_reach', cameraTrack: 'front',
    targets: ['trunk_control', 'symmetry'], equipment: 'none',
    cues: ['Hips level — no rocking', 'Reach without shifting weight'],
    regression: 'dead_bug',
  },

  // ── Power / elasticity ───────────────────────────────────────────────────
  pogo_hops: {
    id: 'pogo_hops', name: 'Pogo Hops',
    clip: 'ex.pogo_hops', cameraTrack: 'side',
    targets: ['elastic_stiffness', 'reactive_power'], equipment: 'none',
    cues: ['Stiff ankles — bounce, don’t squat', 'Quick off the floor', 'Tall posture'],
    progression: 'depth_drop',
  },
  depth_drop: {
    id: 'depth_drop', name: 'Depth Drop to Stick',
    clip: 'ex.depth_drop', cameraTrack: 'side',
    targets: ['reactive_power', 'knee_stability'], equipment: 'box',
    cues: ['Land soft, stick silent', 'Knees out, chest up', 'Hold the landing 2s'],
    regression: 'pogo_hops', progression: 'depth_jump',
  },
  depth_jump: {
    id: 'depth_jump', name: 'Depth Jump',
    clip: 'ex.depth_jump', cameraTrack: 'side',
    targets: ['reactive_power', 'elastic_stiffness'], equipment: 'box',
    cues: ['Minimal ground time', 'Punch the ground and go', 'Arms drive the rise'],
    regression: 'depth_drop',
  },
  broad_jump: {
    id: 'broad_jump', name: 'Broad Jump to Stick',
    clip: 'ex.broad_jump', cameraTrack: 'side',
    targets: ['reactive_power'], equipment: 'none',
    cues: ['Big arm swing', 'Land in an athletic base', 'Stick — no stumble'],
  },
  squat_jump: {
    id: 'squat_jump', name: 'Squat Jump',
    clip: 'ex.squat_jump', cameraTrack: 'side',
    targets: ['reactive_power'], equipment: 'none',
    cues: ['Load the hips', 'Explode through full extension'],
    progression: 'depth_jump',
  },

  // ── Locomotion / conditioning ────────────────────────────────────────────
  a_skip: {
    id: 'a_skip', name: 'A-Skips',
    clip: 'ex.a_skip', cameraTrack: 'side',
    targets: ['sprint_mechanics', 'elastic_stiffness'], equipment: 'none',
    cues: ['Knee up, toe up', 'Strike under the hips', 'Rhythm over height'],
  },
  high_knees: {
    id: 'high_knees', name: 'High-Knee Run',
    clip: 'ex.high_knees', cameraTrack: 'front',
    targets: ['sprint_mechanics', 'aerobic_base'], equipment: 'none',
    cues: ['Tall hips', 'Fast, light contacts'],
  },
  tempo_stride: {
    id: 'tempo_stride', name: 'Tempo Strides',
    clip: 'ex.tempo_stride', cameraTrack: 'side',
    targets: ['aerobic_base', 'sprint_mechanics'], equipment: 'none',
    cues: ['Smooth 75% effort', 'Relaxed jaw and hands'],
  },
};

/** Exercises that target a deficit, primary-target matches first. */
export function forDeficit(d: string): ExerciseDef[] {
  const all = Object.values(EXERCISES);
  const primary = all.filter((e) => e.targets[0] === d);
  const secondary = all.filter((e) => e.targets.includes(d as any) && e.targets[0] !== d);
  return [...primary, ...secondary];
}
