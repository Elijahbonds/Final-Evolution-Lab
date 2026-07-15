// Feature flags for the 3D upgrade. Each game mode opts in individually so a
// broken 3D scene can NEVER take down the live 2D app — flip a mode back to
// false and it instantly falls back to the proven Canvas-2D implementation.
//
// Rollout is staged: Dunk Contest is the first vertical slice.

export type GameModeKey =
  | 'dunkContest' | 'hoops1v1' | 'streetball' | 'threePoint'
  | 'karate' | 'tennis' | 'skateboard' | 'soccer' | 'baseball'
  | 'golf' | 'gymnastics' | 'training';

// Modes rendered with the real-time 3D engine. Everything else stays 2D.
const THREE_D_MODES: Partial<Record<string, boolean>> = {
  dunkContest: true,
  hoops1v1: true,
  hoops3v3: true,
  threePoint: true,
  karateEndless: true,
  karateVersus: true,
  skateboard: true,
  surfing: true,
  snowboarding: true,
  bigAir: true,
};

export function is3D(mode: string): boolean {
  // Global kill-switch via env — set NEXT_PUBLIC_DISABLE_3D=1 to force all modes
  // back to 2D instantly (e.g. if a device/GPU issue is reported in production).
  if (typeof process !== 'undefined' && process.env.NEXT_PUBLIC_DISABLE_3D === '1') return false;
  return THREE_D_MODES[mode] === true;
}
