# Journal — Claude Code (cloud)

Append-only. Only this agent writes here. Newest entries at the BOTTOM.
Format is defined in `docs/AGENT-ACCESS-AND-PROTOCOL.md` Rule 3.

---

## 2026-07-26T21:10Z · claude-cloud
DID: M80 external animation pipeline — ExternalClipLoader, clipManifest, PoseProbe, boneNames, clip_check.mjs, conform_clips.sh
TOUCHED: docs/abacus-batches/m80-external-animation/**
FOUND: VERIFIED zero character/animation assets in the project; no code path could load one. Prefixed bone names animate nothing and look identical to a T-pose.
NEEDS: claude-mini — install Blender and run tools/conform_clips.sh on one DeepMotion export. Nothing else in the fleet can do this.
NEEDS: abacus — serve assets/ready/anim/ at /assets/ready/anim and call loadClipPack() after clip registration.
NEXT: movement and route-teardown diagnosis

## 2026-07-26T22:05Z · claude-cloud
DID: docs/BLUEPRINT.md and docs/AGENT-ACCESS-AND-PROTOCOL.md — root-caused all five open defects, per-mode vision for 25 modes, PRQ/multiplayer/accessibility plans, build order
TOUCHED: docs/BLUEPRINT.md, docs/AGENT-ACCESS-AND-PROTOCOL.md, docs/agents/**, tools/agent_sync.mjs
FOUND: VERIFIED LocalInputSource sets sprint from hypot(moveX,moveY) > 0.85 while keyboard WASD emits magnitude 1.0 — the player is always sprinting, there is no walk. Diagonals are 41% faster (no normalization). held-key set is never cleared on blur, so alt-tabbing while moving runs the character forever.
FOUND: INFERRED runMode() awaits def.load() before returning its disposer, so a route change during load leaks the engine and its WebGL context. Browsers cap contexts at ~8-16; only a page reload frees them. This matches "refresh to load each time" exactly.
FOUND: VERIFIED the web app writes PRQ (SessionResult POST) but never reads it. PRQDrivenDDA exists only in the retired Swift app, so PRQ affects zero frames of gameplay.
FOUND: VERIFIED accessibility coverage is one line about contrast. No reduced-motion, remapping, captions, or colorblind support anywhere.
NEEDS: elijah — send docs/ACCESS-SETUP.md's paste block to Abacus. Two of three agents cannot see the app source.
NEEDS: abacus — confirm which Babylon major version the app is on (LoadAssetContainerAsync moved between 7 and 8).
NEEDS: claude-mini — grep the live app source for whether movement is camera-relative (BLUEPRINT §1.2i). May outrank every other movement fix.
NEXT: awaiting direction — build MotionModel (§1.2) or the route-teardown fix (§1.1)

## 2026-07-26T23:30Z · claude-cloud
DID: M81 feel foundation — MotionModel, inputCore, InputBus v3, Teardown, ModeHarness v3, DDA, game-surface.css. 157 tests pass by execution (61 motion + 96 foundation).
DID: docs/ONE-SHOT-BUILD.md — paste-ready prompts for claude-mini and abacus
TOUCHED: docs/abacus-batches/m81-feel-foundation/**, docs/ONE-SHOT-BUILD.md, tools/verify_batch.mjs
FOUND: VERIFIED Swift's tier band is 0.75..<0.9 -> ELITE and PRQ.default is 75, so a brand-new account starts at ELITE and meets elite AI on its first match. Ported faithfully and pinned by test; it is a product decision, not a code one.
FOUND: VERIFIED M29's harness has the same engine-leak shape as M26, and its 20s load watchdog makes the unguarded window LONGER, not shorter.
NEEDS: claude-mini — run the WebGL context-count snippet (BLUEPRINT §1.1) on the live app before applying M81's harness change. The leak diagnosis is INFERRED and must be confirmed or refuted.
NEEDS: claude-mini — review M81 for three specific assumptions: ctx.camDirector.yawDeg exists, the Babylon major version, and that PlayerSlot no longer derives sprint from stick magnitude.
NEEDS: abacus — M81 has one breaking change: runMode() is no longer async. runModeLegacy() stages the migration.
NEXT: awaiting playtest results before tuning MotionModel constants

## 2026-07-27T01:15Z · claude-cloud
DID: M82 accessibility and PRQ visibility — prqWeights (canonical JSON + 4-way parity test), a11y settings store, caption bus, colourblind-safe palette, AccessibilityPanel, PrqMeter. 92 tests pass (26 parity + 66 a11y).
DID: patched backend/routers/games.py PRQ_MODE_WEIGHTS to the canonical table
TOUCHED: docs/abacus-batches/m82-accessibility-and-prq/**, backend/routers/games.py
FOUND: VERIFIED the Swift and Python PRQ weight tables had silently diverged on five modes. Same session, different PRQ delta depending on which platform scored it: who_scene_it 0.7 vs 1.1 (57%), brain_brawl 0.8 vs 1.1 (37%), court_carnival 0.9 vs 1.15 (28%), skateboarding and snowboarding 1.0 vs 1.05.
FOUND: VERIFIED market_browse was absent from the backend table entirely, so it fell through to the 1.0 default — browsing the shop minted PRQ at the same rate as playing baseball. Now pinned at exactly 0.0 with a test.
FOUND: VERIFIED accessibility coverage across the product was one line about contrast. No reduced motion, remapping, captions, or colourblind support anywhere.
NEEDS: elijah — the five weight changes are all increases, no nerfs, but which direction to converge is a product call. Edit config/prqWeights.json to override.
NEEDS: abacus — confirm whether backend/routers/games.py in this repo is what you actually deploy. If not, the weight patch must be applied there too or the divergence persists.
NEXT: Wave 3 — deterministic fixed timestep, then ghost replay (BLUEPRINT §4 Phase A)

## 2026-07-27T03:40Z · claude-cloud
DID: M83 determinism and ghosts — FixedStep, Rng, Replay, GhostSource, SimLoop. 110 tests pass including a full record-replay round trip asserting bit-identical reproduction.
DID: tools/ts_resolve.mjs — resolve hook so executable tests can import batch source using the app's extensionless convention
TOUCHED: docs/abacus-batches/m83-determinism-and-ghosts/**, tools/ts_resolve.mjs
FOUND: VERIFIED a real desync in my own first FixedStep. 288 frames at 144Hz accumulate to 1.999999999999994 because 1/144 is not representable in binary float, so the 120th tick never fires. A 144Hz player drifts ~30 ticks per minute from a 60Hz player and any ghost recorded on one desyncs on the other. Fixed with a measured relative epsilon.
FOUND: three previous batches bent code to suit the Node ESM resolver (split a module, inlined a table, dropped an import). The resolver was the right place to fix it; ts_resolve.mjs removes the whole class of problem.
NEEDS: abacus — M83 machinery does nothing until modes migrate off variable dt and Math.random(). verifyDeterminism() is EXPECTED to fail on first run per mode; that is the tool working.
NEXT: 10-phase AAA pass, phase 1

## 2026-07-27T05:00Z · claude-cloud
DID: M84 Phase 1 of 10 — ModeKit (five subsystems, one object), tools/integration_audit.mjs, tools/fel_batch_alias.mjs, docs/TEN-PHASE-PLAN.md. 41 tests pass, testing the WIRING itself.
DID: fixed a real bug in tools/verify_batch.mjs — it compared an import of `FixedStep.ts` against a README declaring `FixedStep` and warned about prerequisites that were declared
TOUCHED: docs/abacus-batches/m84-phase1-integration-kit/**, tools/integration_audit.mjs, tools/fel_batch_alias.mjs, tools/verify_batch.mjs, docs/TEN-PHASE-PLAN.md
FOUND: VERIFIED the repo holds 49,400 lines of batch code across 84 batches, 98 mode files, 42 core modules — and zero of it has been observed executing in the real app. Authoring is not the bottleneck; integration verification is. Nine more phases at that rate produces 100k unverified lines instead of 50k.
NEEDS: claude-mini or abacus — run `node tools/integration_audit.mjs` against the live build and report how many subsystems are observably running. That number is worth more than the next phase of code.
NEEDS: abacus — migrate ONE mode (dunk) to ModeKit before phase 2. If it is not a net line REDUCTION the kit has the wrong shape and phases 2-6 are planned against a bad API.
NEXT: phase 2 — basketball, pending the dunk migration result

## 2026-07-27T06:30Z · claude-cloud
DID: M85 Phase 2 of 10 — basketball. DunkTiers (real vertical -> reachable dunks) and DefenseRead (a defender that commits and can be faked). 56 tests pass.
TOUCHED: docs/abacus-batches/m85-phase2-basketball/**
FOUND: VERIFIED the product thesis was never wired. irlDunkJudging (M33) measures jumpHeightCm from video and DunkMode (M63) scores difficulty/execution/style, and nothing connects them. A player's real vertical had zero effect on the flagship mode.
FOUND: VERIFIED BasketballCore.DefenderBrain calls Math.random() per frame, so no 1v1 possession can ever be replayed or audited. It also never commits, so it cannot be beaten by a move — only by speed.
FOUND: my own first test fixtures were physically wrong — a 188cm player with a 30-inch vertical expected to windmill. The model correctly said one-hand. Moved the fixture, not the model.
NEEDS: claude-mini — six of nine dunk clips do not exist (dunk_tomahawk, dunk_windmill, dunk_eastbay, finger_roll, dunk_one_hand, dunk_two_hand). Phase 2 unlocks dunks the game cannot yet show. Blender is on the Mini and nowhere else.
NEEDS: abacus — confirm how OneVOneMode tracks ball-handler lateral offset. If HandlerState is fed in the wrong basis the defender commits sideways.
NEXT: phase 3 — combat

## 2026-07-27T07:45Z · claude-cloud
DID: M86 Phase 3 of 10 — combat. NeutralGame: frame data, frame advantage, whiff punish, spacing zones, a rival that plays footsies. 76 tests pass.
TOUCHED: docs/abacus-batches/m86-phase3-combat/**
FOUND: VERIFIED FightCore.resolveStrike() returns 'whiff' with NO recovery frames, so missing costs nothing. That single absence deletes the entire neutral game — spacing is pointless, the longest attack is always correct, and the winner is whoever mashes fastest.
FOUND: VERIFIED RivalFightBrain calls Math.random() four times per frame, so no combat round can be replayed or audited.
FOUND: caught by test — mapping dda.aiReactionSpeed() straight to frames gives 31-44 frames against a 24-frame whiff window, so NO rival at any PRQ could ever punish anything. DDA measures a basketball decision latency; combat needs a perception latency. Added COMBAT_REACTION_FACTOR 0.35 and a regression guard. General lesson for phases 4-10: two subsystems tuned on different time scales can be wired together correctly and still produce nothing.
NEEDS: abacus — nothing currently enforces canAct(). If a mode lets a player attack during recovery, every guarantee in NeutralGame evaporates. It is one if-statement and it is the most important line of the integration.
NEEDS: abacus — FightCore.resolveStrike() has no notion of active frames, so an attack can currently connect during startup. Joining it to tickAttack()'s onActive callback is step 2 of the wiring.
NEXT: phase 4 — field and precision (football 1.5 weight gets the most depth)

## 2026-07-27T09:00Z · claude-cloud
DID: M87 Phase 4 of 10 — field and precision. EvasionCore (football evades as a read), PitchRecognition (baseball as classification under a deadline), RallyPressure (a rally that builds). 94 tests pass.
TOUCHED: docs/abacus-batches/m87-phase4-field-precision/**
FOUND: VERIFIED FootballRushMode's evades are i-frame dodges on a cooldown — the defender's pursuit angle is irrelevant, so there is nothing to read and mashing is optimal. Football carries the highest PRQ weight (1.5) and was the most reflexive mode in the product.
FOUND: VERIFIED DerbyMode is "STRIKE on time" — a timing bar. A 150kph fastball leaves a 290ms decision window for a four-way classification, so real hitting is identification under a deadline and timing is the easy part.
FOUND: VERIFIED RallyCore has no reason to aim — planShot takes a target but nothing makes one better than another.
FOUND: caught by test — my first movementCost had a player crossing a full singles court in 0.83 seconds, so nothing was ever out of position and the pressure model was completely inert while looking fine. Second phase running where a merely-wrong constant deleted a whole mechanic. Pattern worth watching in phases 5-10: a number that is wrong rather than absent produces a system that runs and does nothing.
NEEDS: abacus — pitch tells need a VISUAL (spin trail, seam colour, release marker). recognitionAt() returns a number; without something showing it the mode is guessing rather than reading, which is strictly worse than the timing bar it replaces. Highest-risk item in Phase 4.
NEEDS: abacus — Pursuit.angleDeg must be measured in the runner's basis, not world space, or every evade reads backwards.
NEXT: phase 5 — board sports

## 2026-07-27T10:30Z · claude-cloud
DID: M88 Phase 5 of 10 — board sports. TrickLine (a skate line you can lose), CarveModel (real sidecut geometry), WaveModel (seeded procedural waves). 104 tests pass.
TOUCHED: docs/abacus-batches/m88-phase5-board/**
FOUND: VERIFIED TrickMachine's combo counter has no bail risk, so the optimal play is repeating one high-value trick in the safest spot in the park.
FOUND: VERIFIED rideWorlds.buildSurfBreak returns a lip travelling shoreward ON A LOOP — one wave, forever. Once you learn the loop the mode is finished.
FOUND: THIRD CONSECUTIVE constant bug caught by test. My first carve model used an 8m sidecut and 1.4g grip, giving carve limits of 6-8 m/s, so every realistic riding speed was a skid and the carve state was literally unreachable. Phase 3 was reaction frames longer than the window they had to fit; Phase 4 was a tennis court crossed in 0.83s; this is the same shape. A merely-wrong constant produces a system that runs, unit-tests clean, and does nothing. The only thing that catches it is asserting the CONSEQUENCE — is this state reachable at a realistic input — rather than the value.
NEEDS: abacus — WaveModel describes a wave, it does not render one. Something must build a mesh whose shape matches sections[], or the player reads a HUD instead of a wave. Same risk class as Phase 4's pitch tells.
NEEDS: claude-mini — six board clips missing (board_kickflip, board_heelflip, board_360, board_grind, board_manual). Blender now blocks five phases.
NEXT: phase 6 — creative and cognitive

## 2026-07-27T11:45Z · claude-cloud
DID: M89 Phase 6 of 10 — creative and cognitive. MentalResilience (computes ARV/ESI/Pacing, the MRI inputs nothing has ever produced) and CreatorLoop (what you make becomes what you play with, never an advantage). 87 tests pass.
TOUCHED: docs/abacus-batches/m89-phase6-creative-cognitive/**
FOUND: VERIFIED the MRI has never measured anything. mri_engine.py computes 0.30*ARV + 0.45*ESI + 0.25*Pacing with grading thresholds, and the session receipt schema DEFAULTS arv and esi to 50 with no mode overwriting them. Every player has an MRI of about 50, forever. Same shape as the PRQ bug in M82 — a complete, correct system fed by a constant.
FOUND: VERIFIED the four creative modes all produce something and none of it goes anywhere. CardBridge can mint cards and applyArtCard can skin a venue, but nothing connects making a track to playing with it.
FOUND: two model corrections forced by test. ARV measured against a whole-session baseline that included the tilt it was detecting, so a badly tilting player scored 46.7 instead of ~0. Fixing that to a pre-failure window still scored everyone 50 on any repeating pattern, because before and after windows held the same samples. Weighting the recovery window 3:2:1 toward the first sample after the mistake is what finally made it discriminate.
NEEDS: elijah — the 48 Brain Brawl questions are still unported. 8 reference real companies and public figures; factual trivia is legally distinct from asset or likeness use but it is a brand decision and it is yours. Until they land, Brain Brawl has thin content and MRI has little to read.
NEEDS: abacus — ESI's exertion term has no source on the web. It is the part that most directly delivers the "cognitive load under physical fatigue" thesis, and it needs the HealthKit/band bridge that exists only on the Swift side.
NEXT: phase 7 — ecosystem (economy, cards, season pass, persistence)

## 2026-07-27T13:00Z · claude-cloud
DID: M90 Phase 7 of 10 — ecosystem. ReceiptIntegrity (trust earned by evidence, cash requires server re-simulation) and Progression (level curve, season track, objectives). 98 tests pass.
TOUCHED: docs/abacus-batches/m90-phase7-ecosystem/**
FOUND: VERIFIED the session receipt docstring is accurate and still insufficient. The client never supplies XP or shards, but it DOES supply score, outcome, combo_count and duration. POST {"score": 999999, "outcome": "win"} is a fully authenticated, server-computed reward and nothing asks whether that score was possible. For XP that is a leaderboard problem; for Cash Dunk Arena it is the whole product.
FOUND: VERIFIED XP has nowhere to go. economy_engine computes it per session and nothing consumes it — no level curve, no season, no objectives — while FEL-VISION describes a Season Pass ticking in the background with no implementation on either side.
FOUND: firebase_verify.py decodes without verifying signatures when environment != "production". I checked the production path and it verifies properly against Google's certs, so this is a legitimate emulator affordance and NOT a vulnerability. Worth knowing how it fails: the gate is a string comparison, so an unset or typo'd environment silently accepts unsigned tokens. Fail-open on the most security-critical check in the system. A startup check that refuses to boot on an unrecognised environment would close it.
FOUND: caught by test — my first level curve made level 50 cost 50x level 1, turning the back half into a wall. Now ~11x, with tests asserting both bounds.
NEEDS: abacus — the server cannot re-simulate anything yet. Until FEL's deterministic sim runs on the backend, no receipt reaches 'resimulated' and Cash Arena cannot pay out. Largest remaining piece of the product.
NEEDS: elijah — MODE_BOUNDS are my estimates. They should be re-derived from a week of real telemetry rather than from me.
NEXT: phase 8 — multiplayer and arena

## 2026-07-27T14:15Z · claude-cloud
DID: M91 Phase 8 of 10 — multiplayer and arena. HeadlessSim (server-side re-simulation, closing the gate M90 left open) and Rollback (transport-agnostic netcode). 64 tests pass.
TOUCHED: docs/abacus-batches/m91-phase8-multiplayer/**
FOUND: caught by test on its first run — ReplayRecorder quantises analog inputs to 1/127, so a client that SIMULATES with raw floats and RECORDS the quantised ones produces a replay that can never verify. It looks exactly like cheating, it hits every honest player, and it would surface as "Cash Arena rejects everyone". Fixed with asRecorded(). Fifth constant-shaped bug in eight phases and the first that would have cost money rather than fun.
FOUND: the architectural call for server-side verification is to run the SAME TypeScript headless on Node, not to port the sim to Python. This project has already paid for that lesson four times — PRQ tables drifting Swift vs Python by up to 57%, MRI existing in Python with no producer, DDA stranded in Swift. A ported simulation would be that same failure with money attached.
NEEDS: abacus — refactor ONE mode (dunk) to SimulatableMode before anything else here matters. Most modes currently mutate Babylon meshes directly inside their update loop, so separating simulation from rendering across 19 modes is the substantial remaining work.
NEEDS: abacus — stand up a Node verification service that imports the same core/ modules the client bundles. Not a port. The same files.
NEXT: phase 9 — presentation

## 2026-07-27T15:30Z · claude-cloud
DID: M92 Phase 9 of 10 — presentation. Legibility (the tell registry, the other half of six phases of mechanics) and AdaptiveQuality (hold 60fps, never shed a tell, plus the a11y gate gameFeel never got). 79 tests pass.
TOUCHED: docs/abacus-batches/m92-phase9-presentation/**
FOUND: VERIFIED gameFeel.Shaker.kick() and haptic() fire unconditionally. M82 shipped shakeAmount() and reduced-motion but gameFeel predates it, so reducedMotion is honoured by the HUD's CSS and ignored by the thing that actually moves the camera — which is the one that makes people ill.
FOUND: my own tell registry failed its own accessibility audit on first run. prq_effect shipped as an icon with no glyph, i.e. colour-only, which is exactly the failure M82 spent a batch arguing against reappearing one level up in my own data.
FOUND: SUSPECTED, not confirmed — gameFeel.Shaker accumulates into camera.position rather than offsetting from a base each frame. If CameraDirector reassigns position every frame this is harmless; if not, the camera random-walks away over a session. Cannot tell from here.
NEEDS: abacus or claude-mini — the actual drawing. Legibility says WHAT and WHERE for eleven tells; the renderers do not exist. This closes the "nobody knows what to draw" gap, not the "someone has to draw it" one, and that second gap is the real remaining cost of phases 2-8.
NEEDS: abacus — run legibilityReport(modeId, implemented) in CI. It is the honest measure of how much of phases 2-8 a player can actually reach.
NEXT: phase 10 — certification

## 2026-07-27T17:00Z · claude-cloud
DID: M93 Phase 10 of 10 — certification. Certification.ts (four states, only PASS counts) and tools/certify.mjs. 45 tests pass.
DID: docs/GAP-AND-PASS-2.md — the honest gap assessment and the second ten-phase plan
DID: docs/abacus-batches/DRAG-AND-DROP.md — integration index; all 14 zips rebuilt
TOUCHED: docs/abacus-batches/m93-phase10-certification/**, tools/certify.mjs, docs/GAP-AND-PASS-2.md, docs/abacus-batches/DRAG-AND-DROP.md
FOUND: THE HEADLINE. 1353 assertions across 22 green suites, and 0 modes shippable — 2 of 12 criteria demonstrated. Both are true. Pass 1 was an authoring pass against a codebase I cannot see, and authoring was never the constraint. I said that in Phase 1 and then spent nine more phases proving it.
FOUND: every top blocker across the fleet is SHARED, not per-mode. Integrating ModeKit once moves nine criteria on twenty-five modes. Confusing shared work with per-mode work is how a roadmap spends a month on the wrong thing.
FOUND: the six bugs the tests caught across pass 1 were all the same shape — a system that runs, unit-tests clean, and does nothing. Five were caught only because the tests assert CONSEQUENCES rather than values. That habit is the most transferable thing pass 1 produced.
NEEDS: elijah — sync the app source. docs/ACCESS-SETUP.md, open since M74, and the root cause of the other four blockers.
NEEDS: claude-mini — run tools/conform_clips.sh once. One command, one machine, unblocks nineteen modes.
NEEDS: abacus — integrate M84 into dunk ONLY. If it is not a net line reduction the kit has the wrong shape, and I would rather learn that at the cost of one mode than twenty-five.
NEXT: pass 2 phase 1 — sync and one mode end to end. No new subsystems.

## 2026-07-27T19:00Z · claude-cloud
DID: M94 Pass 2 Phase 1 — `dunk` migrated end to end. M63's 521-line DunkMode.ts split into modes/dunk/DunkSim.ts (pure sim, SimulatableMode) and modes/dunk/DunkMode.ts (render, on ModeKit). 92 tests pass. First batch in fourteen that integrates instead of authoring.
TOUCHED: docs/abacus-batches/m94-pass2-dunk-migration/**, tools/fel_batch_alias.mjs, tools/certify.mjs
FOUND: THE M84 GATE, ANSWERED. 427 code lines became 428 — a wash, not the reduction M84 predicted. But the same volume now carries deterministic ticks, a seeded rival, ghost recording, server verification, PRQ-scaled judging, an accessible QTE window, tier gating and two tells, NONE of which existed in the 427. The kit does not pay for itself in lines; it pays in what the lines can do. Adoption cost 18 lines in the render half against M84's promised ~20, and there is a test that counts the markers.
FOUND: MIGRATION_MARKERS is wrong as a flat list. kit.move does not apply to a dunk contest — there is no locomotion. Calling it anyway to green a checklist is the CameraStandoff failure exactly. Declared the exemption in the test with a reason instead. M84 needs per-mode applicability; not fixed, pass 2 forbids restructuring a subsystem mid-phase.
FOUND: the QTE window never reached the accessibility assist — M63 kept it as a raw constant and so did my first draft. An assist player got the same 4-frame window as everyone else, i.e. M82's whole argument failing at the mode boundary. Fixed through kit.window() into DunkConfig.qteWindowScale — as CONFIG, not a call-site multiplier, because SimulatableMode.tick takes no config and a window varying with an uncaptured setting would desync on the server for exactly the players who need the assist.
FOUND: three bugs, all the M91 shape. (1) tick() fell back to DEFAULT_CONFIG while init() accepted one — every match at a non-default PRQ fails verification, only for players whose readiness is not exactly average. (2) the tick stepped from a second intent() call while SimLoop recorded the first — simulate one input, record another. (3) the drawn QTE window ignored the scale that scored it. Naming the pattern: ANYTHING THE SIMULATION READS THAT THE REPLAY DOES NOT CARRY WILL REJECT THE HONEST PLAYER.
FOUND: scoring parity held. The test recomputes M63's judging formula independently at five input triples and compares. Migration changed structure, not balance. The one deliberate fix: M63 rolled the rival with Math.random(), which is the single call that made every dunk contest unverifiable for the Cash Arena it was built for.
NEEDS: elijah — sync the app source. Phase 1's gate was three things: nextjs_space/ in the repo, dunk on ModeKit, a real tsc. I did the one that was mine. No tsc has run, and the render half's import paths for CharacterLibrary/ballRig/SoundKit/clipRegistry/modeConfigs are guesses taken from M63.
NEEDS: abacus — route dunk to modes/dunk/DunkMode.ts and DELETE modes/DunkMode.ts. Two copies of the scoring rules is the PRQ-weight-drift bug again.
NEEDS: abacus — run tools/integration_audit.mjs against the deployed build after routing. That artifact is what this phase is missing and it is the one that counts.
NEXT: pass 2 phase 2 — measure the baseline. Cannot start it without the audit artifact above.

## 2026-07-27T21:00Z · claude-cloud
DID: M95 Pass 2 Phase 2 — the baseline, MEASURED on the deployed app. First evidence-backed batch in ninety-five. tools/integration_audit.mjs extended to measure boot, canvas geometry, coverage and backing-pixel ratio at two viewports. 24 tests pass. docs/BASELINE-2026-07-27.md.
TOUCHED: docs/abacus-batches/m95-pass2-canvas-and-baseline/**, tools/integration_audit.mjs, tools/certify.mjs, docs/BASELINE-2026-07-27.md
FOUND: THE CANVAS BUG, ROOT-CAUSED. dunk fills 92% of a desktop and 26-33% of an iPhone 13, IDENTICALLY on eight modes to the decimal — so it is one shared wrapper, not twenty-five mode bugs. The cause is `aspect-[16/10]` on the stage div. A 16:10 box across a 390px portrait phone is 244px tall; the canvas is `absolute inset-0` and was never wrong. THAT is why every engine.resize() theory failed. Fixed and verified live: 33.3% → 79.8% on 8/8 modes with no control pushed off-screen.
FOUND: 9.01 backing pixels per CSS pixel on the phone — devicePixelRatio 3 taken literally. 776,736 pixels filled to light 86,304. Capping at 2 removes 56% of the fill rate for no perceptible change, and it matters MORE after the CSS fix because the canvas is now four times bigger.
FOUND: I WAS WRONG ABOUT THE T-POSE. I reported M64 had fixed it on the strength of `[FEL-ANIM] restPose solved`. It runs, and both characters are still T-posed in the live product on desktop and phone — see evidence/desktop-tpose.png. A console line saying a fix ran is not evidence the fix worked and I treated it as one. Likely mechanic: restPose corrects the skeleton REST pose and a playing clip's arm rotation keys override it every frame; the importer drops position tracks and leaves rotations, which is correct and leaves exactly this hole.
FOUND: NO WEBGL LEAK, and the reason matters. Instrumented getContext before app code: 1 context per route, 0 lost, six route changes. Every route change is a full page load — there are no in-app /play/ links — so the browser tears it down itself. M81's lifecycle work targets a defect this build's routing already prevents. It becomes real the moment the app is a true SPA, but "the WebGL context leak" should stop being cited as a live defect, and I have cited it as one for several batches.
FOUND: boot is NOT a problem — 1.2-2.5s to canvas, and all eight modes reached loading → loaded → playing. There is no "must refresh to load a game" reproduction at two viewports. Whatever that symptom is, it is not a mode failing to boot.
FOUND: caught in my own tooling — a synthetic click() leaves a touch viewport stuck at "loaded" while a real touchscreen.tap() reaches "playing". Reporting the first run would have sent someone chasing a Playwright artifact as a mobile start-gate bug.
NEEDS: abacus — ship M95's game-surface.css. No prerequisites, no component changes, biggest measured win available.
NEEDS: abacus or claude-mini — the T-pose. Wire M80's PoseProbe (built, never run) or give me the app source. It is visible in every screenshot of the product and it is now the top per-mode blocker.
NEXT: pass 2 phase 3 — lifecycle and movement. Phase 3's stated gate (20 route changes without a reload) needs rewriting: this build cannot do a route change WITHOUT a reload.

## 2026-07-27T23:00Z · claude-cloud
DID: M96 Pass 2 Phase 3 — lifecycle proven PASS on the deployed app; found and fixed three modes that lose the player with no input. 25 tests pass. integration_audit.mjs gained an UNATTENDED health check.
TOUCHED: docs/abacus-batches/m96-pass2-grounding-and-lifecycle/**, tools/integration_audit.mjs, tools/certify.mjs
FOUND: LIFECYCLE IS PASS, MEASURED. 20 route changes on one page: 20/20 loaded, 1 live WebGL context every time, 0 page errors, and boot got 198ms FASTER by the end. Phase 3's stated gate ("20 route changes, no reload") was written against an app this build is not — there are no in-app /play/ links, every route change is a full page load. The honest version of the gate passes without M81 being integrated at all, which means M81's engine-lifecycle work is not urgent. It becomes urgent the day the app is a true SPA.
FOUND: THREE MODES DESTROY THEMSELVES UNATTENDED. skateboard (24 faults, worst y -2.02), snowboard (25, -2.29), surf (23, -2.41) lose the rider through the floor with ZERO player input, within seconds. The other eleven modes are clean. This class of bug was invisible to every check this project has ever had, because every check DROVE the game — nobody watched a mode do nothing.
FOUND: the cause is inferable from the shape of the data. The depth is roughly CONSTANT at ~-2, and something falling gets deeper. So position is corrected and velocity is not: gravity integrates into vy while the actor sits on the floor, and it re-penetrates the next frame. A clamp that has to keep firing is not holding. Reconstructing "clamp position, ignore velocity" reproduces it exactly — 635 clamps in 11s, never settles, vs 1 for the fix.
FOUND: my own first draft of the fix REPRODUCED THE BUG IT WAS WRITTEN TO FIX. Clamping position and zeroing velocity is not enough; a resting actor still accumulates gravity, dips below, and gets corrected — 143 times in my own test. The third element, a grounded flag that suppresses gravity integration while resting, is not a refinement, it is the fix.
FOUND: keyboard AND gamepad listeners ARE attached — confirmed by enumerating real listeners over CDP (window keydown:2/keyup:1, canvas keydown:1/keyup:1, gamepadconnected:2). So I am NOT reporting keyboard movement as broken, despite W/A/S/D producing no visible displacement in onevone while the joystick moved the player. Cause undeterminable from outside the bundle.
FOUND: caught in my own tooling AGAIN — a loose /START|PLAY/ matched "MATCH PLAY" in the tennis title before the TAP TO START button, so tennis reported as never reaching playing. Anchored the matcher; tennis reaches playing fine. Second tooling artifact in two phases that would have been written up as an app bug.
NEEDS: abacus — apply groundGuard where the app prints "hard-clamping to floor". The grounded and clampedFrames fields MUST persist on the actor between frames; recreate them each frame and the bug comes straight back.
NEEDS: real hardware — the always-sprinting bug is still unmeasured. Distinguishing a walk from a sprint needs frame-accurate displacement and this container renders at ~3fps through a software rasteriser.
NEXT: pass 2 phase 4 — mocap. Blocked on tools/conform_clips.sh, which only the Mini can run, and it is now the top blocker: the T-pose is visible in every screenshot of the product.

## 2026-07-28T01:00Z · claude-cloud
DID: M97 Pass 2 Phase 4 — built tools/pose_probe.mjs (the first tool here that can see INSIDE the running game) and used it to find that the camera, not the rig, is why nothing is readable. core/CameraFraming.ts, 31 tests.
TOUCHED: docs/abacus-batches/m97-pass2-framing-and-pose/**, tools/pose_probe.mjs, tools/certify.mjs
FOUND: I WAS WRONG ABOUT THE T-POSE, TWICE. Measured inside the live scene: idle_stand is playing on both characters, the rest pose is solved AND applied (bone and transform node agree), and the arm sits at 20 degrees from vertical. Bind pose on this rig measures 90. The solver drops the hand 0.61m on a 0.65m arm — M64 and M69 work. I read a framing bug as a rigging bug because a screenshot was the only instrument I had, and I reported it twice.
FOUND: THE HEADLINE. Six of eight modes render the player at 5-9% of screen height. tennis 4.9% (camera 33.5m from a 1.7m player), skateboard 6.3%, football 7.6%, dunk 8.3% (18.4m), onevone 8.5%, karate 8.9%. karate-vs is 34.4% and correct. baseball is 131.6% — too close, not too far. A 1.72m athlete is 60px on a desktop and NINETEEN CSS PIXELS on a pre-M95 phone.
FOUND: this cancels M92. Eleven tells specified, six anchored to the subject; a tell on a 19px character is about 6px. Every mechanic from phases 2-8 is invisible for this reason alone, and drawing the tells changes nothing until the camera comes in.
FOUND: M95 IS NOT SUFFICIENT ALONE, and there is a test for it. Tell size: 6px before M95, 15px after M95, 20px on a full desktop canvas, 41px with M95 AND target framing. Quadrupling the canvas is not enough and moving the camera is not enough on the old canvas — they multiply. Rescuing tennis by canvas alone would need ~1470px of canvas height, which no phone and few laptops have.
FOUND: the technique is reusable. Babylon does not expose Engine on window, but it BINDS its render loop to itself, so hooking Function.prototype.bind before any page script captures it — then scenes, skeletons, bone world matrices and camera projection are all readable. This is what M80's PoseProbe was for and it needs nothing from the app.
NEEDS: abacus — apply per-mode camera distances from CameraFraming.recommend(). dunk 18.4m→6.9m, tennis >4x closer. DO NOT apply one global distance: karate-vs is already right and baseball is too close.
NEEDS: nothing from the Mini for this. Phase 4's mocap gate is still blocked on Blender, but the finding reorders it — the rest pose was already correct and too small to see, so mocap was never the reason the characters looked wrong.
NEXT: pass 2 phase 5 — tells, wave one. Now unblocked in the sense that we know what has to happen first: the camera move is a prerequisite for every tell, not a parallel task.

## 2026-07-28T03:00Z · claude-cloud
DID: M98 Pass 2 Phase 5 — found the actual cause of the T-pose, three levels below where anyone had looked. anim/SkinWeightAudit.ts + tools/skin_audit.mjs. 23 tests pass.
TOUCHED: docs/abacus-batches/m98-pass2-skin-weights/**, tools/skin_audit.mjs, tools/certify.mjs
FOUND: THE ANSWER. 14,128 of 18,409 vertices — 77% of the character mesh — are dominated by the Head bone. Left hand weighted Head 0.78. Right hand Head 0.68. Forearm Head 0.90. Chest Head 0.97. Only the legs are bound to leg bones. The entire upper body is a rigid lump welded to the head, so the arms cannot move no matter what the skeleton does. tools/skin_audit.mjs reports 5/5 rigs BROKEN across dunk, karate and skateboard — one shared character asset.
FOUND: this retires a question open since M24 and it invalidates the premise of Phase 4. M24, M42, M51, M64, M69 and M80 all worked on the skeleton, the clips, or the pose. NOT ONE of them could have fixed this. Neither could mocap: conformed clips drive the same bones the mesh ignores, so running conform_clips.sh would have produced a perfect walk cycle and changed nothing on screen. Worth knowing before someone spends a day on it.
FOUND: how it survived six batches — every check in this project looked at the SKELETON. "restPose solved" is a true statement about bones. "restPose applied to skeleton" is a true statement about bones. Nothing had ever asked the MESH whether it was listening, and a screenshot at 60px cannot tell you.
FOUND: en route, and worth recording — the camera pull-in works. Setting the dunk ArcRotateCamera radius from 14 down took the character from 60px (8.2%) to 157px (21.6%), converging in one step. The knob is `radius`, and the M97 recommendation is directly applicable.
NEEDS: claude-mini or whoever has Blender — re-export the character with automatic weights, unprefixed bone names, glTF with skinning. Then `node --experimental-strip-types tools/skin_audit.mjs` must report 0 broken. That is the acceptance test and anyone can run it.
NEEDS: abacus — wire auditSkin() into CharacterLibrary.spawn(). It is silent on a healthy character by design; a check that logs every spawn becomes noise, which is the mechanism that let this past six batches.
NEXT: pass 2 phase 6 — but the ordering has changed. Tells cannot be drawn on a character that cannot move, and the camera move is a prerequisite for tells being visible at all. Skin weights, then camera, then tells.

## 2026-07-28T05:00Z · claude-cloud
DID: M99 Pass 2 Phase 6 — converged every camera on the deployed build and shipped the measured distances. config/cameraPresets.json + core/cameraPresets.ts, 43 tests. Also captured visual proof of the M98 skin bug.
TOUCHED: docs/abacus-batches/m99-pass2-camera-presets/**, docs/abacus-batches/m98-pass2-skin-weights/evidence/**
FOUND: VISUAL PROOF OF M98. Rotating the Head bone ~52 degrees swings the entire upper body — torso, both arms, jacket — as one rigid unit while the legs stay planted. Exactly what 77%-welded-to-Head predicts, in one screenshot anyone can read.
FOUND: FOUR MODES ARE A ONE-NUMBER FIX, applied and measured. dunk radius 14→3.0 (8.3%→21.2%, 60px→154px), onevone 17→4.52 (8.5%→21.5%), threevthree 24→3.41 (5.7%→21.0%, 3.6x bigger), karate 13→3.71 (8.3%→21.1%).
FOUND: the values CANNOT be calculated. `radius` is measured from the camera's TARGET, not the character — dunk is radius 14 but 18.4m from the hips. A one-step arithmetic estimate landed six modes at 13-17% instead of 22%. Every shipped value was converged and then measured.
FOUND: BLOCKER 1 — every ArcRotateCamera ships lowerRadiusLimit = 3. tennis and volleyball need ~2.51 and stall at 18.4%. Setting radius 0.5 is accepted and silently clamped back to exactly 3 within two seconds. A preset that gets clamped and never mentioned again is indistinguishable from one nobody wired, which is the CameraStandoff failure exactly — so planFor() refuses and says why.
FOUND: BLOCKER 2 — football, baseball, skateboard, snowboard and surf use a TargetCamera whose position is rewritten every frame. External writes survive about one frame: football moved to y=1.64 was at y=6.35 two seconds later, and the convergence loop just oscillated 8-10-6-11-7-12%. No value can fix those five; they need a distance parameter inside their controller.
FOUND: karate-vs is already correct at 35.7% and baseball is TOO CLOSE at 84.8%. A fleet-wide "move all cameras in" breaks both. Marked leaveAlone with a test.
NEEDS: abacus — apply the four verified radii; set lowerRadiusLimit = 2.5 on tennis and volleyball BEFORE assigning radius; change the follow distance inside the TargetCamera controller for the other five. Keep the else-branch that warns, or a clamped preset is invisible again.
NEXT: pass 2 phase 7 — PRQ and captions live. Tells stay blocked behind skin weights (M98, needs Blender) regardless of the camera.

## 2026-07-28T07:00Z · claude-cloud
DID: M100 Pass 2 Phase 7 — watched the deployed app play a session and read what it sent. core/scoreScale.ts + ui/CaptionRegion.tsx, 28 tests. Phase 7 is the one part of the plan not blocked by M98's skin weights.
TOUCHED: docs/abacus-batches/m100-pass2-prq-input-and-captions/**, tools/certify.mjs
FOUND: PRQ MEASURES WHICH MODE YOU PICKED. Two mediocre sessions: dunkContest submitted score 25 and got 48 XP, 1 shard, PRQ delta 0.0. karateEndless submitted 1250 and got 1885 XP, 62 shards, PRQ +0.5. Karate paid 39x the XP and 62x the shards — not because it was more of a workout, but because karate counts in thousands and a dunk contest counts in tens. A dunk contest's theoretical max is 120 (M94 DunkSim: 2 rounds x 2 dunks x 3 judges x 10). Nothing converts between the scales. A player optimising for PRQ should play karate and never dunk.
FOUND: the score is client-supplied, confirmed with the actual payloads. POST /api/sessions {"mode":"dunkContest","score":25,...} and POST /api/v1/wallet/earn with the same score granted 53 coins. I did NOT test whether a forged value is accepted — that would be an attack on production and the payload shape is enough to act on. normalise() clamps at 1 so score:999999 is worth exactly a perfect game.
FOUND: POST /api/nexus/session-result returns {"ok":false,"reason":"nexus_disabled"}. The nexus pipeline is switched off server-side. That is very likely why [FEL-DDA] has never appeared in any log, and no batch can fix it — it is a deployment flag.
FOUND: and the server ALREADY computes DDA. /api/sessions responds with grade {"key":"READY","speedMult":1,"hangBonus":0}. Nothing client-side reads it.
FOUND: THERE ARE NO CAPTIONS AT ALL. Zero aria-live regions, zero role=status, zero .sr-only, measured in dunk, karate, onevone and tennis. M82 built captions.cue(), M94 wired kit.sound(), M92 gave eleven tells caption strings — none of it can reach a player because nothing renders it. CaptionRegion.tsx is forty lines and it is the entire gap. The accessibility work here is not missing, it is unplugged.
FOUND: caught in my own draft — CaptionBus.visible() sorts CRITICAL FIRST, so slice(-n) would have dropped exactly the cues a player must act on and kept the ambient ones. Fixed to slice(0, n) with a test.
NEEDS: elijah/abacus — the nexus flag is disabled server-side. Everything about PRQ actually moving depends on it and I cannot see or change it.
NEEDS: abacus — mount <CaptionRegion /> once inside the game surface. Normalise before rewarding: sessionValue(mode, raw, prqWeight(mode)). Read the grade the server already returns.
NEEDS: real high-score samples — karateEndless: 4000 is a placeholder from one mediocre run, and twenty-three modes have no scale at all and will throw by design.
NEXT: pass 2 phase 8 — SimulatableMode for the cash modes. dunk already implements it (M94); the question is whether anything else can without the app source.
