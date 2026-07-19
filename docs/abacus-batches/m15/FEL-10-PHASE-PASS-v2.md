# FEL 10-PHASE REMEDIATION PASS v2 — Abacus Build Prompt

Copy everything below into Abacus.

---

## PROMPT

Execute this 10-phase remediation pass on Final Evolution. **Begin with Phase 0
(diagnostic gate), then Phase 1. Report Phase 0's findings and Phase 1's proof before
touching Phase 2.** Every phase ends with a runnable proof — a screen recording,
console output, and file list — not a claim. The previous pass shipped code that did
not change observable behavior; the acceptance criteria below exist to make that
impossible to repeat. If a phase cannot be proven, stop and report. Never regress the
working meta layer (season pass, result screens, PRQ/XP/LC rewards, shop, hub).

Stack note: architecture below assumes Babylon.js (TypeScript) + Havok on Vercel with
Abacus AI endpoints. If any part of the actual codebase differs, translate the idioms
— the diagnostics, bone-map/blend architecture, and phase order are engine-agnostic.

---

## PHASE 0 — DIAGNOSTIC GATE (before any feature code)

Build a `/debug/anim` route that, for every loaded character asset, logs:

```ts
console.table(skeleton.bones.map(b => b.name));
animationGroups.forEach(g => {
  console.log(g.name,
    'targetedAnims:', g.targetedAnimations.length,
    'from:', g.from, 'to:', g.to,
    'unmatched:', g.targetedAnimations.filter(t => !t.target).length
  );
});
```

Expected failure signatures:
- `targetedAnims: 0` → clip never bound to skeleton (bone naming mismatch)
- `unmatched > 0` → partial retarget, bones silently dropped
- Groups non-zero but pose static → blend weights all zero, or
  `scene.animationsEnabled === false`, or a cloned mesh sharing a skeleton reference
  incorrectly, or an idle group pinned at weight 1.0 on the same bones

**Deliverable:** `DIAGNOSTIC_REPORT.md` with actual console output pasted in.
**If clips are empty or unmatched: stop and report. No downstream phase is meaningful
until the rig retargets correctly.**

---

## PHASE 1 — ANIMATION SYSTEM REBUILD (blocking; everything depends on this)

### 1.1 Canonical skeleton
One rig for all humanoid modes. Standardize on Mixamo bone naming
(`mixamorig:Hips`, `mixamorig:Spine`, `mixamorig:LeftArm`, …) — widest compatibility
for DeepMotion/SayMotion output and Blender retargets.
`src/anim/BoneMap.ts`: explicit source→canonical bone map. Never implicit matching.

### 1.2 Animation controller
Replace every direct `.play()` with one state machine:

```ts
class CharacterAnimator {
  private groups: Map<string, AnimationGroup>;
  private current: AnimationGroup | null = null;

  play(name: string, opts: { loop: boolean; blendMs: number; onEnd?: () => void }) {
    const next = this.groups.get(name);
    if (!next) { console.error(`MISSING CLIP: ${name}`); return; }
    if (next.targetedAnimations.length === 0) {
      console.error(`EMPTY CLIP (retarget failed): ${name}`); return;
    }
    next.setWeightForAllAnimatables(0);
    next.play(opts.loop);
    this.blend(this.current, next, opts.blendMs);   // old→0, new→1 over blendMs
    this.current = next;
  }
}
```

Hard requirement: cross-fade weights must ramp old→0 AND new→1. The T-pose/penguin
symptom is almost always both groups sitting at weight 0. A missing/empty clip plays
a shared fallback action clip and logs — bind pose is never shown.

### 1.3 Locomotion — real human gait
Blend tree driven by planar velocity magnitude:

| Speed (m/s) | Clip | Notes |
|---|---|---|
| 0 | `idle` | subtle sway, breathing |
| 0.1–1.4 | `walk` | ~1.9 m stride, heel-strike → toe-off |
| 1.4–3.5 | `jog` | contralateral arm swing, ~0.15 s flight phase |
| 3.5+ | `sprint` | torso lean 12–18°, high knee drive |

Lateral movement uses dedicated strafe clips — do **not** yaw the whole model to fake
sideways motion (that IS the penguin artifact).
Foot IK: raycast down from each foot bone, adjust hip Y to the lower hit, plant feet
to surface normal. Without it everything slides.

### 1.4 Character facing/orientation (moved up from Phase 10 — reported twice now)
- At import: verify each model's authored forward axis matches engine forward (+Z);
  bake a corrective rotation at the prefab level once, never per-mode.
- At spawn: set forward vector explicitly (court modes face the rim/opponent;
  runners face down-field; fighters face each other).
- At runtime: yaw follows velocity; when engaged, blend toward the engagement target
  (rim, opponent, end zone) at a max slew (~540°/s). Strikes/dunks/jukes must never
  play with the chest pointed away from the target.

### 1.5 Striking (karate)
Root-motion, three-phase clips — never single poses:
- **Wind-up** (0.10–0.15 s): weight to rear leg, hip rotates away
- **Execute** (0.05–0.08 s): kinetic chain proximal→distal — hip leads shoulder leads
  elbow leads fist by ~40 ms; arm-first reads fake
- **Recovery** (0.15–0.25 s): return to guard
Upper-body strikes on an additive layer masked `Spine`-up (strike while moving);
full-body kicks override the whole skeleton.

**Phase 1 proof:** video of one character walking, jogging, sprinting, strafing, and
throwing three distinct strikes — correct facing throughout, no T-pose in any frame,
plus `/debug/anim` output showing bound clips and live weights.

---

## PHASE 2 — CINEMATIC MOVE ENGINE (Dunk Contest hero mode)

Replace procedural dunking with **CinematicMoveEvent**:

```ts
interface CinematicMove {
  id: string;                  // 'windmill_360'
  inputSignature: string;      // 'RS_DOWN+A' — selected BEFORE launch
  clip: string;                // full-body root-motion animation
  duration: number;
  cameraTrack: CameraKeyframe[];
  qteWindows?: { atMs: number; widthMs: number }[];  // slam timing lives INSIDE the movie
  physicsMode: 'kinematic';
  exitState: 'landing';
}
```

Flow: player selects the move via input **before takeoff** (the movie type is chosen
by the pre-launch input) → on takeoff the sim hands control to the cinematic → camera
detaches from follow-cam onto the authored track → ball parented to the hand bone
throughout → slam QTE fires at the rim-arrival keyframe → on land, control returns.

Camera track per dunk, minimum 3 keyframes: low approach → orbit to side profile at
apex (where the dunk reads) → cut to rim-level or crowd reverse on finish. Cubic
ease in/out — linear camera moves look like debug cams.

This mechanism is also the mocap-gap fix: authored clips + authored camera beat
procedural blending for hero moments, and these events become the reference/target
format for AI-generated animation later.

**Phase 2 proof:** three visually distinct dunks (POWER/FLASHY/SIG-class), each with
its own camera track, each selected by a different pre-launch input, ball in hand
end-to-end, QTE inside the movie.

---

## PHASE 3 — ENVIRONMENT & LIGHTING (all modes)

### 3.1 BackdropRig
Every scene: 4 large planes at distance forming a room. Unlit/emissive, no shadow
cast/receive, `isPickable = false`, `freezeWorldMatrix()`. Set dressing only.

### 3.2 Venice Beach (basketball hero scene), camera-outward:
- **Near:** blacktop court + painted lines, chain nets, bleachers, chain-link fence
- **Mid:** boardwalk strip, vendor canopies, bathroom/shower building, palms, Hoopbus
- **Far:** ocean plane with animated normal map, sky, horizon haze

### 3.3 Lighting (fixes "incredibly dark" + INVISIBLE football defenders)
Standard rig every scene:

```ts
scene.environmentTexture = CubeTexture.CreateFromPrefilteredData(hdrPath, scene);
scene.environmentIntensity = 1.0;
const key = new DirectionalLight("key", new Vector3(-0.5, -1, -0.3), scene);
key.intensity = 2.5;
const fill = new HemisphericLight("fill", new Vector3(0, 1, 0), scene);
fill.intensity = 0.6; fill.groundColor = new Color3(0.4, 0.4, 0.45);
const pipeline = new DefaultRenderingPipeline("default", true, scene);
pipeline.imageProcessing.toneMappingEnabled = true;
pipeline.imageProcessing.toneMappingType = ImageProcessingConfiguration.TONEMAPPING_ACES;
pipeline.imageProcessing.exposure = 1.1;
```

Board sports get lifted saturation — bright, high-contrast, not muddy. Verify
football defender meshes are actually instanced INTO the scene (not logic-only
entities) and lit.

**Phase 3 proof:** screenshots of every venue at 3 camera angles — no black surfaces,
Venice set dressing visible, defenders visible.

---

## PHASE 4 — CAMERA & CONTROL STANDARDIZATION (all 23 modes, incl. soccer)

### 4.1 Universal layout — dual virtual sticks + 4 face buttons, everywhere
- **Left stick:** movement (8-way, analog magnitude)
- **Right stick:** camera orbit *and* context modifier (pro-stick-style move
  selection; doubles as the Phase 2 cinematic selector)
- **A/B/X/Y:** context verbs per mode, always same screen position, verb-labeled
- Triggers: analog charge/sprint per mode. Discrete button+direction combos, not
  free-form gesture tracing (abstracted inputs outperform gestural mimicry).

### 4.2 CameraDirector — one class, three modes
- `Follow`: spring-arm behind player, collision-aware (raycast pull-in so it never
  clips the Phase 3 backdrops), configurable lag
- `Cinematic`: authored keyframe track, blocks player input
- `Fixed`: rally sports (tennis, baseball)
Easy operation is the bar: one camera toggle input; no autonomous camera mode
switches mid-attempt; READY gate + 3-2-1 before any mode takes live input.

**Phase 4 proof:** video cycling all three camera modes in dunk, karate, soccer, and
skate; overlay visible and operable with thumbs in portrait and landscape.

---

## PHASE 5 — MODE REBUILDS (furthest from vision; all use Phase 1 animator + Phase 4 camera)

**5.1 Baseball → 3D (Wii Sports Baseball reference).** Delete the 2D stick-figure
implementation. Court-Rally core: 3D field, fixed cam behind batter, physics ball
with drag + Magnus, swing timing window, camera cuts to ball-follow on contact.

**5.2 Golf → 3D (Wii Sports Golf reference).** Delete 2D version. Three-click or
swipe power/accuracy meter, slope-aware roll, pre-shot fairway pan, flight follow,
landing settle.

**5.3 3v3 + 1v1 basketball → free-moving open dribble (biggest miss).**
- Continuous analog movement — no grid/tile snapping
- Dribble = persistent state with its own animation layer; ball parented to hand
  bone, offset driven by the dribble clip
- Right stick = dribble moves (crossover, between-legs, behind-back, hesi) as
  discrete combos; face buttons: shoot (hold = meter with green window), pass,
  pump-fake, sprint — 2K-familiar
- Defenders: steering behaviors (seek/pursue + lateral containment bias), not
  waypoint following

**5.4 Football.** Defenders invisible → verify meshes instanced + Phase 3 lighting;
then skinned pursuit, juke/spin/hurdle/stiff-arm three-phase clips, survivable
opening (no tackle before ~15 yd post-gate).

**5.5 Soccer.** Currently ONE shot only → after each shot resolves, reset to
kickoff/restart and return control; continuous play loop with possession states;
rebounds live (keeper parry → follow-up shot).

**5.6 Tennis.** Ball passes through racket → swept-sphere collision (`Ray` from
previous ball position to current vs. racket collider). Fast projectile + thin
collider REQUIRES continuous collision detection. A correctly timed swing always
makes contact.

**5.7 Skatepark expansion.** ≥4× footprint; bowls, rails, ledges, quarter-pipes,
gaps in a flowing loop. Riding: crouch into transitions, extend on pops, shoulder
counter-rotation against the board. Discrete THPS-style trick inputs.

**Phase 5 proof:** one recorded session per rebuilt mode demonstrating its listed
requirements.

---

## PHASE 6 — ECONOMY: COINS & SHARDS (all modes)

Single server-authoritative `EconomyService`.
- **Coins** — soft currency, earned by play, spent on cosmetics
- **Shards** — hard currency, purchasable; spent on System Scan workouts, program
  upgrades, premium Creator Card slots (this is what creates real shard demand,
  with Phase 10)
Wire earn events into every mode.
**Compliance blocker:** no payment acceptance until the server-authoritative wallet
exists and is verified. Ledger server-side; client shows a cached read only.

**Phase 6 proof:** earn event log across 3 modes + server ledger entries matching.

---

## PHASE 7 — CREATOR CARD SYSTEM

Unified object: **Art** (cover, track, routine, highlight reel) + **Stats**
(moveset/gear modifier). Creation reachable in ≤3 taps from home. Cards are the
primary shareable artifact and main social loop — first-class onboarding step, not a
buried feature.

**Phase 7 proof:** video creating a card in ≤3 taps and sharing it.

---

## PHASE 8 — MARKETING FUNNEL

Email capture → onboarding sequence. Free-play tier of **Who Scene It** as the
top-of-funnel hook.
**Compliance blockers:** Who Scene It uses opt-in creator content only — no film
clips, no celebrity likenesses, no IMDb scraping. EU AI Act disclosure obligations
apply from **Aug 2, 2026** — AI-generated content surfaces ship a disclosure notice
before that date.

**Phase 8 proof:** funnel walkthrough recording + disclosure copy in place.

---

## PHASE 9 — MULTIPLAYER (after 8, before 10)

- **Async online:** ghost/replay-based — record a run (dunk routine, skate line,
  golf round); opponents play against the recording. Cheapest working multiplayer
  loop and it fits the mode set. Authoritative state server-side from day one so a
  real-time layer can be added later without rewrite.
- **Local:** same-device pass-and-play for karate, 1v1, tennis.
- Matchmaking via the existing Abacus endpoint.

**Phase 9 proof:** two accounts completing one async challenge end-to-end.

---

## PHASE 10 — SYSTEM SCAN + WORKOUTS + APP REDESIGN

### 10.1 System Scan — functional for EVERY user, not gated
Produces a body/movement profile. This is a core promise of the app.

### 10.2 Monetized workout tier (creates shard demand)
- Scan → free baseline profile
- Personalized workout for THEIR body, based on THEIR scan → costs shards
- Upsell → full 12-week individualized program
**Content integrity flag:** workout content draws on The Neuro-Mechanic's Blueprint;
fake-precise physics figures in the manuscript are NEEDS-VERIFY and must not ship as
fact in any curriculum surface.

### 10.3 App redesign
- Multiplayer reachable in ≤2 taps; System Scan and Creator Card creation surfaced
  on the home screen
- Mobs + obstacles in open-world/traversal modes (The Nexus, skatepark) for
  traversal interest — placed, animated (Phase 1 animator), avoidable
- Facing verification sweep app-wide (Phase 1.4 must already hold; re-verify here)

**Phase 10 proof:** scan → paid workout → 12-week upsell flow recorded with a shard
purchase against the server wallet; redesigned home recording.

---

## ACCEPTANCE CRITERIA (every phase)

1. Screen recording of the changed behavior
2. Console output proving the system fired (group names, weights, event log)
3. Explicit list of files touched
4. Regression note: meta layer (season pass, rewards, result screens, shop) still
   works; no T-pose, no black surface, no invisible actor reintroduced

**Start with Phase 0, then Phase 1. Report before proceeding to Phase 2.**
The failure mode where "nothing from the update happened" is work reported without
verification — Phases 0–1 are the real gate. If the animation rebuild doesn't hold,
the other nine phases will produce the same result as the last update.
