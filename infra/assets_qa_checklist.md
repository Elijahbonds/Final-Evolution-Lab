# Per-Mode Asset & Gameplay QA Checklist

Run per mode after asset integration. Evidence: snapshot renders
(`/tmp/fel_snapshots` via FELSceneSnapshotTests) + on-device playtest.

## Universal (every mode)
- [ ] Venue loads (no placeholder fallback triggered); grounded at y=0; footprint clears chase camera
- [ ] Background panorama fills horizon (no black void); lightingEnvironment sane (no blowout)
- [ ] Character(s) render at 1.75–1.85 m, feet on floor, facing correct direction
- [ ] Animations play: idle loop seamless; one-shots return to idle; no T-pose flashes
- [ ] Root-motion clips move the entity; in-place clips don't drift
- [ ] Audio events fire (match_start, score) — or skip silently if unfetched
- [ ] 60 fps on device (A15+); no memory growth across 3 sessions
- [ ] Deterministic scoring parity for judged modes (same seed -> same judge offsets; replay_validator passes)

## basketball_dunk_3d (High)
- [ ] Approach -> launch -> airborne -> land phase transitions blend (120 ms window)
- [ ] Dunk clip swaps in at airborne (setDunkClipActive) and restores runner on land
- [ ] Peak hand contacts rim at 3.05 m (rim-normalized clips)
- [ ] Judges visible + idle-animating; scores reveal in sync with crowd_hype audio
- [ ] Trick buttons (face + right stick) register mid-air only

## karate_h2h / karate_endless (High)
- [ ] Both fighters visible & distinct (tint or distinct model)
- [ ] Strikes fire per button (square jab / circle hook / triangle roundhouse / cross uppercut); overlapping strikes cancel cleanly
- [ ] Block window 100 ms; perfect_guard vfx+audio on frame-perfect block
- [ ] HP/chakra HUD tracks hits; KO -> fall clip -> result screen
- [ ] Endless: wave spawn escalates; stage venue (Muscle Beach) loads

## tennis (High)
- [ ] Racket attached to right hand socket during swings
- [ ] Serve/forehand/backhand map to inputs; ball contact syncs to racket_pop audio
- [ ] Court camera frames both baselines; net collision blocks low shots

## gymnastics (High)
- [ ] Rhythm windows align beat markers to clip contact frames (cartwheel hands, vault board)
- [ ] Wobble plays on near-miss; stick landing freezes 500 ms; judge_beep on each element

## skateboarding (High)
- [ ] Push loop drives movement; ollie root motion clears obstacle height
- [ ] Bail triggers on failed landing angle; board separates (prop socket released)

## Remaining modes (Medium/Low)
- [ ] baseball / football / soccer / golf / volleyball / surfing / snowboarding:
      venue + background + idle/primary action clip verified (matrix pass)
- [ ] brain_brawl / who_scene_it: podium scene, thinking_idle, correct/wrong stings
- [ ] court_carnival: 10 stations reachable; HoopBus prop placed; station markers glow

## CI idea (documented, not yet wired)
Headless: run simulator suite -> export replays -> replay_validator -> upload
snapshot renders as artifacts; fail on placeholder-fallback warnings for
modes marked asset-complete in assets_manifest.json.
