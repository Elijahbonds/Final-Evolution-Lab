// M17 shared contracts — every module in this package imports from here.

// ── Pose / scan ─────────────────────────────────────────────────────────────

/** One MediaPipe pose landmark (33 per frame), normalized image space + world m. */
export interface Landmark {
  x: number; y: number; z: number;      // world-space meters (hip-centered)
  vx: number; vy: number;               // normalized viewport coords for overlay
  visibility: number;                   // 0..1
}

export interface PoseFrame {
  tMs: number;
  landmarks: Landmark[];                // length 33, MediaPipe BlazePose order
}

export type ScanKind = 'movement_screen' | 'stress_test';
/** What the athlete filmed. Drives which analyzers run. */
export type ScanActivity = 'squat_screen' | 'run' | 'jump' | 'dunk' | 'sport_play' | 'freestyle';

export interface ScanSubmission {
  scanId: string;
  kind: ScanKind;
  activity: ScanActivity;
  fps: number;
  durationMs: number;
  athleteHeightCm: number;              // calibration input, user-entered
  frames: PoseFrame[];                  // the ONLY biometric payload uploaded by default
  videoOptIn: boolean;                  // true only if user chose coach review
}

// ── Movement screen results ─────────────────────────────────────────────────

export interface MovementMetrics {
  jumpHeightCm: number | null;          // stress tests with a jump
  squatDepthDeg: number | null;         // min knee angle achieved
  kneeValgusDeg: number | null;         // frontal-plane collapse at max load (worst side)
  hipHingeRatio: number | null;         // hip flexion / knee flexion balance
  asymmetryPct: number | null;          // L/R loading asymmetry, 0 = symmetric
  cadenceSpm: number | null;            // running cadence steps/min
  groundContactMs: number | null;       // running/jumping contact time
  trunkLeanDeg: number | null;          // mean sagittal trunk angle under load
  confidence: number;                   // 0..1 — mean landmark visibility over frames
}

/** Deficits the plan generator targets. Order = severity. */
export type Deficit =
  | 'ankle_mobility' | 'hip_mobility' | 'knee_stability' | 'hip_stability'
  | 'trunk_control' | 'reactive_power' | 'elastic_stiffness' | 'symmetry'
  | 'aerobic_base' | 'sprint_mechanics';

export interface ScreenResult {
  scanId: string;
  metrics: MovementMetrics;
  deficits: Deficit[];                  // ranked, max 4 targeted per plan
  strengths: Deficit[];                 // inverted — things that scored well
  summary: string;                      // one-paragraph human-readable readout
}

// ── Mini avatar ─────────────────────────────────────────────────────────────

/** Scale factors applied to the canonical Mixamo rig's bone lengths. 1.0 = default. */
export interface AvatarProportions {
  height: number;                       // overall uniform scale
  torso: number; arms: number; forearms: number;
  legs: number; shins: number; shoulders: number; hips: number;
}

export interface AvatarPalette {
  skin: string;                         // hex, sampled client-side (user-adjustable)
  jersey: string; shorts: string; shoes: string; accent: string;
}

export interface MiniAvatarSpec {
  avatarId: string;
  proportions: AvatarProportions;
  palette: AvatarPalette;
  sourceScanId: string;
}

// ── Workout plan ────────────────────────────────────────────────────────────

export interface ExerciseDef {
  id: string;                           // 'goblet_squat'
  name: string;
  clip: string;                         // canonical-rig animation clip id, e.g. 'ex.goblet_squat'
  cameraTrack: 'front' | 'side' | 'orbit';
  targets: Deficit[];
  equipment: 'none' | 'dumbbell' | 'band' | 'box';
  cues: string[];                       // max 3, shown one per set
  progression?: string;                 // harder exercise id
  regression?: string;                  // easier exercise id
  tempo?: string;                       // e.g. '3-1-1'
}

export interface PlannedExercise {
  exerciseId: string;
  sets: number;
  reps: string;                         // '8' | '10/side' | '20s hold'
  restSec: number;
  cueIndex: number;
}

export interface WorkoutDay {
  label: string;                        // 'Day 1 — Foundation: Hips + Trunk'
  focus: Deficit[];
  blocks: { title: string; exercises: PlannedExercise[] }[];  // warmup / main / finisher
  estMinutes: number;
}

export interface WorkoutPlan {
  planId: string;
  product: 'workout_4w' | 'program_12w';
  athleteAvatar: MiniAvatarSpec;
  basedOn: ScreenResult;
  weeks: { theme: string; days: WorkoutDay[] }[];   // 4 or 12
  createdAt: string;
}

// ── Mini movies ─────────────────────────────────────────────────────────────

export interface ExerciseMovie {
  exerciseId: string;
  clip: string;
  avatar: MiniAvatarSpec;
  cameraTrack: 'front' | 'side' | 'orbit';
  loop: boolean;
}

/** The athlete's own scanned movement, retargeted for replay on their avatar. */
export interface ScanReplayClip {
  scanId: string;
  clipName: string;                     // registered as `scan.{scanId}`
  frames: RetargetedFrame[];
}

export interface RetargetedFrame {
  tMs: number;
  /** canonical bone name → quaternion [x,y,z,w]; root gets position too */
  rotations: Record<string, [number, number, number, number]>;
  rootPos: [number, number, number];
}

// ── API DTOs ────────────────────────────────────────────────────────────────

export interface PurchaseRequest { product: 'workout_4w' | 'program_12w' }
export interface PurchaseReceipt {
  ok: boolean; ledgerId: string; product: string; shardsSpent: number; balance: number;
}

export type ScanStatus = 'received' | 'analyzing' | 'building_avatar' | 'generating_plan' | 'ready' | 'failed';
export interface ScanStatusResponse { scanId: string; status: ScanStatus; error?: string }

export const SHARD_PRICES = { workout_4w: 300, program_12w: 900 } as const;
