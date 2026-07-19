# FINAL EVOLUTION — THE 10-PHASE PASS

## ▶ PROMPT FOR ABACUS (paste this whole document)

Execute the 10-phase plan below on the Final Evolution app. **Start with Phase 1 and
build ONLY Phase 1 now.** Do not touch later phases until Phase 1's acceptance list
passes in the live build. Work phase by phase in order; each phase ends with its
acceptance checks verified and a one-paragraph completion report. The M13 and M14
batch documents already provided are the detailed specs behind these phases — where a
phase references them, follow those documents exactly. Never regress: no T-poses, no
black surfaces, no invisible actors, thumbs-playable on mobile, and the existing
result screens / season pass / economy must keep working after every phase.

---

## PHASE 1 — CINEMATIC MOVIE ENGINE + HERO MODE (Dunk Contest) ⟵ START HERE
The engine that fixes animation everywhere, proven on the hero mode first.
1. **Clip/registry audit:** log every animation request that finds no clip (T-pose =
   missing/unretargeted clip — bind-pose fallback is forbidden; a shared fallback
   action clip plays instead and the miss is logged).
2. **Build the Movie Event engine** (M14 §1): baked full-body animation + camera
   track + QTE windows inside the movie; gameplay outcome lands on the clip's
   contact frame; scene keeps rendering live in the background; camera returns to
   gameplay cam after.
3. **Wire it into Dunk Contest end-to-end:** the dunk sequence IS a movie event with
   amazing animation — gather → rise → style → slam → rim hang → landing, ball in
   hand the entire time. **The movie played is selected by the input you choose
   BEFORE launch:** style pick (d-pad/buttons or card tap) during the approach arms
   which dunk movie fires. Three visibly distinct movies minimum (POWER / FLASHY /
   SIG), each with anticipation → contact → follow-through motion (real human
   biomechanics reference, M14 §1).
4. **Input frame:** on-screen controller for this mode = **dual joysticks + 4 face
   buttons** (+ triggers per the shell spec). Camera and controls must be easy: left
   stick drive, R2/hold charge, face buttons = style/slam verbs, one camera toggle
   button. No auto camera switching mid-attempt.
5. Locomotion baseline: root motion + foot IK so walking/running never penguin-shuffles.

**Acceptance:** zero T-poses in Dunk; each of the 3 pre-selected styles fires its own
cinematic; slam QTE happens inside the movie at rim arrival; ball visible in hand
launch-to-net; controls operable with thumbs (dual sticks + 4 buttons); camera never
loses the dunker.

## PHASE 2 — CAMERA + CONTROLS REWIRE, EVERY MODE (including soccer)
- Universal controller overlay in ALL modes: dual sticks, d-pad, 4 verb-labeled face
  buttons, triggers, START/pause, SELECT/camera toggle (handoff doc 03 layout).
- Camera constraint rig everywhere (M13-03): player + objective always framed, ground
  always visible, occlusion probe (dojo pillar), pitch floor on fast modes; easy
  manual camera: SELECT cycles presets, right stick nudges. No mode starts before a
  READY gate + 3-2-1.
**Acceptance:** every mode playable thumbs-only with the same layout; camera never
shows floor-only/void frames; camera toggle works in every mode including soccer.

## PHASE 3 — LIGHT + VENUE BOXES (kill every dark/void scene)
- Global lighting floor: no material renders black (this is why football defenders
  are INVISIBLE and the skatepark is a void — unlit materials, M14 §2).
- 4-wall venue boxes for all scenes; Venice gets ocean/pier, boardwalk + vendors,
  bleachers, bathrooms/showers building, the Hoopbus; blacktop court (no water floor).
- Color/lighting pass on all board sports + The Gridiron.
**Acceptance:** no black surfaces at any reachable camera angle; Venice set dressing
visible in play; football defenders clearly visible and lit.

## PHASE 4 — BASKETBALL FAMILY (2K controls + free movement)
- 1v1 + 3v3 rebuilt as free-moving open dribbling systems with 2K-familiar mapping
  (M14 §3.2): left stick dribble movement, right stick pro-stick (crossover/spin/
  stepback; hold = shot stick with green window), R2 sprint, L2 post/protect, B pass
  (3v3 cutter targeting), real on-ball defense.
- Dunk Contest inherits Phase 1; alternating skinned rival turns to 21 (M13-04).
**Acceptance:** a 2K player runs 1v1/3v3 without instructions; open-floor dribbling
works; shot meter with timing window; rival takes turns in Dunk.

## PHASE 5 — COMBAT (Soul Calibur karate)
- Karate 1v1 → mixed combat (M14 §3.1): 8-way movement, A horizontal / B vertical /
  X kick / Y guard, throws close-range A+B, chi special movie event on R2;
  **character-bound signature items** (e.g. keyblade-class) render in hand and
  re-skin strike movies — style differs, stats stay fair.
- Karate Endless: honest waves (clear ONLY by KOs), engagement facing, hit-reacts,
  KO freeze-frame (M13-07).
**Acceptance:** all four verbs + guard functional; item visible and re-skins strikes;
no wave advances without matching KO count.

## PHASE 6 — BALL PHYSICS MODES (soccer, tennis, penalty)
- **Soccer:** currently allows only ONE shot — full session loop: five-round shootout
  (or timed multi-shot), rebounds live (follow-up shots on keeper parries), keeper
  animation, aim via stick + curve on trigger, per-shot movie events on strikes.
- **Tennis:** ball currently passes THROUGH the racket on the rebound — real racket
  collision: swing timing window = contact; clean rebound physics with placement from
  stick; serve/forehand/backhand movie events; rally loop (Match Play first-to-5,
  Tiebreak first-to-7).
- Penalty Shootout: verify same standards (aim, keeper, 5 rounds).
**Acceptance:** soccer supports its full multi-shot loop with rebounds; tennis ball
never tunnels through the racket — every timed swing makes contact and returns.

## PHASE 7 — 3D CONVERSIONS (Wii-Sports bar)
- Baseball: 2D stick figures → 3D avatar Home Run Derby at Catalina venue box
  (M14 §3.3): pitcher windup movie, timed swing + aim, contact movies, ball-flight cam.
- Golf: 2D → 3D (M14 §3.4): analog backswing power, aim stick, wind, drive/chip/putt
  movies, ball-follow camera.
**Acceptance:** both modes are 3D with avatar swings and readable ball flight.

## PHASE 8 — BOARD SPORTS DEEP PASS
- Skatepark expanded: 3+ linked zones (street → bowl → vert) in a flowing loop;
  natural riding (carve lean, crouch-pump, arm balance), trick movie events on
  R-stick flicks; grounded board + contact shadows (M13-05).
- Surf + Snowboard (Slalom, Big Air): same riding/ground/camera standards.
**Acceptance:** bigger park verifiably (3 zones), riding looks natural, tricks fire
movies, no floating.

## PHASE 9 — LIBRARY CONSISTENCY + GUEST FUNNEL
- Remaining modes to standard (Beach Sprint, Brain Brawl, Who Scene It, Nexus
  Initiative, Home Run Derby variants): controller overlay, ready gates, movie events
  where actions warrant, result screens verified.
- Guest `/try` gets the full controller + Phase-1 dunk experience (the funnel shows
  the best of the game). DDA numbers hidden from HUD.
**Acceptance:** every one of the 22 modes passes the global checklist rows
(m13-08 "Global"); /try is thumbs-perfect.

## PHASE 10 — FULL QA + POLISH
- Run the complete m13-08 checklist on every mode, both orientations, desktop +
  mobile + gamepad.
- Performance: stable frame rate on mid-range phones; asset/lighting budget audit.
- Sound + haptics pass: button feedback, impact stingers, boot/eject, venue beds.
- Regression sweep on meta (season pass, rewards, PRQ, shop, challenges).
**Acceptance:** checklist green across the board; founder playtest sign-off.

---
*Specs referenced: M13 batch (9 docs), M14 batch (movie events / venue boxes / 2K
controls / conversions), Console Shell spec (handoff doc 03). Phases 1–3 are the
foundation — everything after gets cheaper because of them.*
