# 06 — DATA CONTRACTS

Schemas every agent conforms to. Where the live app already stores these server-side,
these contracts describe the CLIENT-visible shape; do not invent parallel stats.
Authoritative mode/venue catalog: `backend/FEL_ModeManager.production.json` and
`backend/FEL_VenueRegistry.production.json` — reconcile ids against them.

## 1. Player profile (client-visible)
```ts
interface AthleteProfile {
  id: string;
  handle: string;            // e.g. "PLAYTESTCLAUDE"
  avatar: AvatarConfig;      // mesh/skin/cosmetic ids
  prq: number;               // Performance Readiness Quotient, integer (observed: 53)
  labCredits: number;        // LC, integer (observed: 500 starting)
  xp: number;                // lifetime XP
  streakDays: number;
  arena: ModeFamilyId;       // onboarding pick: streetball|karate|skate|surf|snowboard|tennis
  season: SeasonProgress;
}
interface SeasonProgress {
  seasonId: string;          // "golden-hour"
  seasonXp: number;
  tier: number;              // T0, T1, ...
  lane: 'free' | 'pro';
  daysLeft: number;
}
```

## 2. Session result (what every mode must emit on completion)
```ts
interface SessionResult {
  modeId: string;            // registry id, e.g. "football"
  outcome: string;           // mode-specific: "TACKLED_17YD" | "GREAT" | "WAVE_6" ...
  score: number;
  stats: Record<string, number>;   // mode-specific counters (yards, evaded, kos, combo...)
  rewards: {
    xp: number;              // observed: +138
    shards: number;          // observed: +4
    credits: number;         // LC delta
    prqDelta: number;        // may be 0
    seasonXp: number;        // observed: +273
  };
  timestamp: string;         // ISO
}
```
Rules: rewards are computed server-side or by the app's existing reward layer — modes
REPORT raw stats; they never mint rewards locally. The result screen consumes exactly
this shape.

## 3. Mode registry entry (client contract)
```ts
interface ModeConfig {
  id: string;                     // "dunk"
  title: string;                  // "DUNK CONTEST"
  venueId: string;                // "venice-beach-court"
  family: ModeFamilyId;
  blurb: string;                  // card copy
  sessionShape: 'timed'|'target'|'waves'|'match'|'run';
  sessionParam: number;           // 120 s, first-to-21, etc.
  controls: string;               // path to controls config (see 4)
  prqWeight: number;              // relative PRQ yield
  guestPlayable: boolean;         // true for the /try funnel mode(s)
}
```

## 4. Controller config (per mode — consumed by ControllerOverlay)
```ts
interface ControlsConfig {
  modeId: string;
  layoutHints?: { portrait?: 'ds'|'overlay'; landscape?: 'switch'|'overlay' };
  bindings: Array<{
    input: 'A'|'B'|'X'|'Y'|'L1'|'R1'|'L2'|'R2'|'dpad'|'stickL'|'stickR'|'screen';
    verb: string;                // label shown on the button: "SLAM", "JUKE L"
    action: string;              // event name game logic listens for: "fel.slam"
    kind?: 'press'|'hold'|'analog'|'flick'|'tap'|'swipe'|'drag';
    repeat?: boolean;
  }>;
  keyboard?: Record<string, string>;  // OVERRIDES only; defaults in 03 §2.3
}
```

## 5. Input events (runtime bus — normative copy of 03 §2.3)
```ts
type FelInput =
  | { t: 'stick';   side: 'L'|'R'; x: number; y: number }
  | { t: 'dpad';    dir: 'up'|'down'|'left'|'right'; pressed: boolean }
  | { t: 'button';  btn: 'A'|'B'|'X'|'Y'|'L1'|'R1'|'SELECT'|'START'; pressed: boolean }
  | { t: 'trigger'; side: 'L'|'R'; value: number }
  | { t: 'screen';  kind: 'tap'|'swipe'|'drag'; x: number; y: number; dx?: number; dy?: number };
```
Deadzone 0.15; stick values normalized -1..1; trigger 0..1; screen coords normalized
0..1 relative to the game canvas.

## 6. Animation state contract (AnimationDriver)
```ts
interface AnimRequest {
  actorId: string;
  clip: string;                  // registry name, e.g. "karate.jab"
  priority: 'locomotion'|'action'|'special'|'reaction';
  interrupt?: boolean;           // may cut same/lower priority
  onMissing?: 'fallback';        // play shared fallback + warn — NEVER silent-skip
}
```
Rules: input→clip ≤100 ms; one-slot input buffer during locked clips; facing resolved
by the orientation system before clip start (m13-01 §B).

## 7. DDA (adaptive difficulty)
Client receives opaque difficulty params per session (e.g. `aggression`, `speedMul`).
They must NEVER render on the player HUD (observed leak: "AGGR 0.68 · SPD ×1.01").
Expose behind `?dev=1` only.

## 8. Economy invariants
- Season Pass Pro lane: cosmetic only. No gameplay stat purchasable.
- Shards, LC, XP, PRQ, seasonXp are the ONLY scalar currencies/meters. New ones
  require a contract change here first.
- Guest sessions accrue a provisional `SessionResult` that converts on account claim.

## 9. Naming & id discipline
- Mode ids, venue ids, clip names, event names are lowercase dot/kebab, stable, and
  defined once. A batch introducing a new id lists it in its MANIFEST under Assumptions
  for reconciliation against the backend registries.
