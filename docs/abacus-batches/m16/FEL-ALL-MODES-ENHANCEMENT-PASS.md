# FEL ALL-MODES ENHANCEMENT PASS — Design · Visuals · Mechanics · Performance

Copy everything below into Abacus.

---

## PROMPT

Execute this comprehensive enhancement pass across every game mode in Final
Evolution. It builds ON TOP of the 10-Phase Remediation Pass — the animation system,
cinematic move engine, lighting rig, camera director, and universal controls from
that pass are prerequisites and must not be regressed. Work in the tier order at the
bottom (Tier 1 → 4). Every tier ends with proof: screen recordings of each enhanced
mode, a performance capture (FPS/frame-time on a mid-range phone profile), and the
list of files touched. Enhancements that cannot be proven on screen did not happen.
Do not break the meta layer (season pass, rewards, result screens, economy, shop).

---

# PART A — GLOBAL STANDARDS (apply to every mode)

## A1. Design bar — "60 seconds to fun, 60 hours of depth"
Every mode must have all five:
1. **Instant verb** — the core action is understood inside 10 seconds of play.
2. **Skill curve** — timing windows/combos/risk-reward that separate a first-timer
   from a tenth-session player (green windows, perfect chains, style multipliers).
3. **Session shape** — clear rounds/waves/clock with a mid-session "it's heating up"
   beat (clutch time, final wave, last hole, breakaway).
4. **One signature moment** per session — the thing a player screenshots (posterizing
   dunk, Dragon-class special, 40-yard breakaway, hole-in-one, perfect wave).
5. **Fail-forward** — losing still pays XP/PRQ and shows ONE actionable tip
   ("release at the peak of the jump") on the result screen.

## A2. Visual bar — the "juice kit" (shared library, wired into every mode)
Build once as `src/fx/JuiceKit.ts`, consume everywhere:
- **Hit-stop:** 40–90 ms freeze on significant contact (dunk slam, KO hit, tackle,
  bat crack, perfect landing).
- **Screen shake:** small directional shake (2–6 px, 80–150 ms, dampened) on impacts;
  never on ordinary movement.
- **Particles (GPU):** impact bursts, dust on landings, board sparks on grinds, net
  splash, chalk/sand kicks. Pooled, instanced, ≤2k particles live.
- **Slow-mo beat:** 0.3–0.5× for 300–500 ms on signature moments only.
- **Score pops:** points/PRQ float AT the action point (rim, KO spot, goal mouth) in
  world space, not only in the HUD.
- **Trail/streak FX:** ball flight trails, board carve lines, fist arcs on specials.
- **Crowd/ambient reaction layer:** venue-appropriate audience sprites/billboards
  with 3 states (idle, engaged, eruption) driven by play events.
- **Announcer/SFX stingers:** per-family one-shots (whistle, gong, horn, air horn)
  + UI ticks for focus/confirm. Central `AudioBus` with ducking (music dips under
  stingers).
- **Transitions:** venue-tinted wipe in/out of modes; no hard cuts to black.

## A3. Mechanics bar
- All timing windows explicit and tunable in one data file per mode
  (`modes/{id}.tuning.json`) — window sizes, speeds, multipliers, DDA bounds. No
  magic numbers buried in code.
- **Combo/multiplier grammar shared across modes:** consecutive perfects build ×1 →
  ×2 → ×3 with a visible meter; any miss halves it. Same visual language everywhere.
- **DDA:** adaptive difficulty adjusts within tuning bounds, invisible to the player
  (dev flag only), never rubber-bands a won session into a loss.
- **Input latency:** input→state ≤1 frame; input→visible response ≤100 ms (animator
  or JuiceKit acknowledgment even when the full animation is longer).

## A4. Performance bar (mid-range phone profile, e.g. 2022 Android / iPhone 11)
- **60 fps target, 30 fps floor** during eruption moments; frame-time spikes >33 ms
  are defects.
- **Budgets per scene:** ≤150 draw calls, ≤350k visible tris, ≤128 MB textures
  (compressed KTX2/basis), ≤8 MB per-mode JS chunk (code-split per mode route).
- **Techniques (apply everywhere):** mesh instancing for crowds/props/defenders;
  LODs on venue dressing; `freezeWorldMatrix()` + static batching on set pieces;
  texture atlases per venue; GPU particles only; shadow budget = 1 cascaded light,
  512–1024 px, static shadow bake where possible; no per-frame allocations in the
  game loop (object pools for balls/particles/vectors).
- **Loading:** venue assets lazy-loaded per mode with the boot splash as cover;
  first playable ≤5 s on 4G; asset manifest hashed for CDN caching.
- **Memory:** dispose scenes fully on exit (verify with heap snapshot — no mode may
  leak >5 MB per launch/exit cycle).
- Add `?perf=1` overlay: FPS, frame-time graph, draw calls, tri count, heap — used
  in every proof recording.

---

# PART B — PER-MODE ENHANCEMENT SHEETS
Format: **D** design · **V** visuals · **M** mechanics · **P** performance.
(Remediation-pass items assumed done; these are enhancements on top.)

## B1. Dunk Contest (hero mode)
- **D:** contest format — 3 rounds × 2 attempts, judge panel scores style+difficulty+
  timing; rival alternates; final round unlocks SIG dunks. Daily featured dunk with
  bonus PRQ.
- **V:** golden-hour god rays; rim-shake + net physics; crowd eruption tier on 9+
  scores; polaroid "poster frame" freeze at apex (shareable image).
- **M:** approach angle + takeoff distance affect difficulty multiplier; lob/self-
  alley variant on Y; perfect-release grace window tightens each round.
- **P:** Venice venue atlas; crowd as instanced billboards; poster-frame capture via
  render-target snapshot, not canvas readback stall.

## B2. Basketball 1v1
- **D:** first-to-11 by 1s/2s (2s beyond arc), win-by-2 cap 15; check-ball ritual;
  momentum "heat" states with visual escalation.
- **V:** on-fire VFX (subtle ember trail) at 3 straight buckets; ankle-breaker
  stumble reaction on successful stepback vs. lunging defender.
- **M:** full pro-stick (crossover/behind-back/hesi/stepback), steal risk window on
  defense (X), shot contest % from defender proximity + hand-up; stamina bar that
  punishes sprint spam.
- **P:** two characters + court = lightest 3D scene; lock 60 fps; preload as the
  default quick-play mode.

## B3. Basketball 3v3
- **D:** 21-point streetball rules, alternating possession, "heat check" bonus ball;
  teammates with distinct archetypes (slasher/shooter/big) the player can switch to.
- **V:** teammate call-out bubbles ("screen!", "corner!"); pick-and-roll ghost-line
  hint for new players (fades with mastery).
- **M:** icon passing (double-tap B cycles), off-ball switch (L1), screens on Y,
  help-defense AI with containment bias, hot zones per player rendered on the floor
  during timeouts only.
- **P:** 6 characters — LOD skeletal update (12 Hz for off-ball far actors), shared
  material instances, animation LOD.

## B4. Karate Endless
- **D:** wave modifiers every 3 waves (dual rushers, shielded striker, night wave);
  score chase with global daily leaderboard; chi meter banks between waves.
- **V:** enemy archetype silhouettes (color + build + stance readable at a glance);
  KO ragdoll launch on finishers; dojo lanterns dim as waves rise (tension lighting).
- **M:** parry (block tap at ≤120 ms before impact) rewards chi; grab-break QTE vs
  grapplers; positioning matters — back-to-wall increases damage taken.
- **P:** enemy pool (max 6 live), shared rig instances, ragdoll only on the final
  KO of a wave (others use baked fall clips).

## B5. Karate Versus (Soul-Calibur-style)
- **D:** best-of-3 vs Rival Sensei ladder (5 ranked senseis, each a moveset school);
  signature-item loadout pre-fight (keyblade-class weapons re-skin strike movies).
- **V:** intro face-off cinematic; round-win pose; KO slow-mo with camera orbit;
  weapon trail arcs.
- **M:** 8-way ring movement, horizontal/vertical/kick/guard verb square, throws
  (A+B), guard-impact push on perfect block timing, ring-corner pressure.
- **P:** two hero-quality characters; cap cloth/weapon physics to 30 Hz sim.

## B6. Street Football
- **D:** 4-down drive structure (gain 20 yd per down set) instead of one-shot runs;
  breakaway state past 50 yd with chaser cam; TD celebration picker.
- **V:** yard-marker chains, mural walls, floodlight pools; defender dive whiffs
  kick up dust; TD fireworks.
- **M:** juke chains (juke→spin within 400 ms = combo multiplier), stiff-arm mini-
  duel vs wrap tackles, kick-return variant mode.
- **P:** defender instancing + steering on staggered ticks (¼ per frame).

## B7. Soccer (full loop) + Penalty Shootout
- **D:** soccer = 3-min small-sided (3v3) street match with kickoff/possession loop;
  penalty = 5-round shootout with keeper mind-games (dive read).
- **V:** goal net ripple, keeper full-stretch saves, street-cage venue box (walls =
  part of play: wall passes).
- **M:** pass/through-pass/shoot verbs, curve on trigger hold, one-touch timing bonus;
  wall-bounce passes legal (cage football identity).
- **P:** ball physics substep only when velocity high; crowd billboards.

## B8. Tennis Match Play + Tiebreak Blitz
- **D:** match = first-to-5 games vs adaptive AI with personality (baseline grinder /
  net rusher); blitz = sudden-death 7 with serve-read minigame.
- **V:** clay/hard-court dust on slides, ball fuzz trail on top-spin, Hawk-Eye-style
  line-call replay on close calls (cinematic camera).
- **M:** shot palette (flat/top-spin/slice/lob/drop) on face buttons + stick aim,
  early/late timing shapes cross-court vs down-line, stamina on sprints.
- **P:** swept-sphere ball collision (from remediation) + fixed cam = cheap scene;
  60 fps locked.

## B9. Home Run Derby (baseball, 3D)
- **D:** 10 outs, pitch variety unlocks (fastball→curve→slider), streak bonus balls,
  distance leaderboard; "golden pitch" final ball worth 3×.
- **V:** ball-flight comet trail + landing splash markers (ocean shots at Catalina!),
  distance pop at apex, stadium lights glint on contact.
- **M:** swing timing × bat-path aim (stick up/down = launch angle), sweet-spot
  contact model, pitch-read tell animations.
- **P:** ballpark venue box + instanced crowd; ball trail = ribbon mesh, not
  particles.

## B10. Golf (3D)
- **D:** 3-hole runs (par 3/4/5) rotating daily; closest-to-pin bonus game; club
  selection matters (driver/iron/wedge/putter auto-suggested, overridable).
- **V:** fairway → green material zones, ball landing divot + roll line, flag
  flutter, dramatic low sun.
- **M:** analog backswing (trigger depth = power) + accuracy tap on downswing, wind
  + slope reads, green grid on putt.
- **P:** terrain LOD rings; physics only on the ball; pre-baked lighting.

## B11. Skate Run · B12. Surf Break · B13. Slalom Descent · B14. Big Air
- **D:** Skate: 2-min free run with line-score multipliers (combo until bail) on the
  expanded 3-zone park. Surf: wave sections (barrel/face/air) with flow meter.
  Slalom: gate-perfect streaks. Big Air: 5-kicker trick budget with rotation
  commitment.
- **V:** speed FOV push, motion-blur streaks at sprint speeds, spray/snow/spark
  particles per surface, landing compression dust; bright high-saturation grade
  (remediation lighting + color pop).
- **M:** THPS-grammar tricks (button+direction, grind balance meter, manual links
  for combo continuation); bail = fail-forward (lose combo, keep run).
- **P:** track/park chunked streaming; rider cloth off on mid-tier; particle pools
  per surface type.

## B15. Beach Sprint (gym) · B16. Iron Paradise (gym)
- **D:** Sprint: rhythm alternation with cadence targets + rival ghost. Iron
  Paradise: set/rep timing holds (squat/press/row stations) with form meter — the
  fitness identity made playable; both feed PRQ hard (highest PRQ weight).
- **V:** cadence pulse ring UI, muscle-group highlight on the avatar per station,
  golden-hour beach backdrop.
- **M:** perfect-cadence windows tighten with PRQ; grip (dual trigger) holds for
  isometrics; breath cue (release timing) on final reps.
- **P:** UI-forward modes — trivial scenes, lock 60 fps, instant load (<2 s).

## B17. Brain Brawl · B18. Who Scene It
- **D:** Brawl: category wheel with streak "brain heat" ×multipliers, 120 s. Scene
  It: 15 questions/8 s with creator-content packs and a daily pack rotation
  (opt-in creator content ONLY — compliance).
- **V:** NeuroArena neon pulse to the beat of the timer; correct/incorrect
  neuron-burst FX; streak crown at 5+.
- **M:** speed scoring (faster = more), double-down wager on final question, 50/50
  lifeline earned by streaks.
- **P:** 2D/UI modes — preload instantly, use as connectivity-friendly fallback.

## B19. The Nexus Initiative (story/traversal)
- **D:** Sanctum hub → 3 rail-grind traversal missions → Glitch Boss with phase
  mechanics (uses karate verbs); mobs + obstacles per the redesign ask — patrolling
  glitch mobs (avoid or strike), moving platforms, data-wall obstacles.
- **V:** synthwave grid venue, glitch shader on enemies (vertex jitter + chroma
  split), boss phase color shifts.
- **M:** traversal = board-sport grammar (grind/jump) + combat = karate grammar;
  checkpoint respawns; boss DPS windows after dodge phases.
- **P:** shader-based glitch (cheap) over particle spam; mob cap 5; streamed
  sections.

## B20. Signature Challenge · B21. Triumph Arena (meta-modes)
- **D:** Challenge: weekly seeded hoops with ONE daily attempt (already right) + top-
  100 ghost playback. Arena: LC-stake duels vs async ghosts with escrowed wagers
  (server wallet from remediation Phase 6).
- **V:** gold-trim UI treatment, live leaderboard ticker, wager-reveal flourish.
- **M:** identical seed = identical conditions (verify determinism: same rng seed →
  same rack/wind/pitch sequence).
- **P:** ghost data = input streams not video (tiny payloads, deterministic replay).

---

# PART C — EXECUTION ORDER & PROOFS

**Tier 1 (foundation):** A2 JuiceKit + A3 tuning-file extraction + A4 perf overlay &
budgets + B1 Dunk + B2 1v1.
**Tier 2 (flagship families):** B3 3v3 + B4/B5 karate + B6 football + B7 soccer.
**Tier 3 (racket/club/board):** B8 tennis + B9 derby + B10 golf + B11–B14 boards.
**Tier 4 (identity & meta):** B15/B16 gym + B17/B18 quiz + B19 Nexus + B20/B21 meta.

**Per-tier proof:** for each mode touched — (1) 60–90 s gameplay recording showing
the D/V/M items, (2) the same recording with `?perf=1` overlay meeting A4 budgets,
(3) files touched. Plus one regression run of the m13-08 global checklist rows on
each touched mode.

**Global acceptance:** every mode exhibits the five A1 design properties; JuiceKit
events fire in every mode (hit-stop/shake/pops verifiable on screen); all timing
values live in `modes/*.tuning.json`; 60 fps on the phone profile with no >33 ms
spikes during signature moments; no mode leaks memory across 3 launch/exit cycles.
