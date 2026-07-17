# M13-01 · P0 — Global Animation Driver + Character Facing

## A. Animations do not fire on input (all modes)

### Observed (live playtest)
- **Karate Endless:** pressed movement + attack inputs (J, Space, E). Enemy waves spawned
  and even cleared ("WAVE 1 CLEAR · 0 KO") but the player mesh never played a strike,
  block, or special clip. Between two screenshots 700 ms apart during active input, the
  player pose is identical.
- **Skate Run:** trick inputs during a 65-speed run produced no ollie/grab/grind pose
  change. Score stayed 0 for the whole run.
- **Street Football:** the run ended ("TACKLED · 17 YD") without a single carry, juke,
  or tackle animation playing on any character.
- **Dunk Contest:** the airborne player holds one static spread-arm glide pose from
  liftoff to landing regardless of which style (POWER/FLASHY/SIG) was selected.

### Required fix — one shared system, not per-mode patches
Build/repair a single **AnimationDriver** that every mode uses:

1. **Input → state → clip contract.** Every gameplay input that mutates state must map to
   an animation state change in the same frame. If game logic registers a jab, the jab
   clip plays. If the clip is missing, play a shared fallback swing/action clip and log a
   warning — never silently skip.
2. **Interrupt rules.** Attack/trick clips interrupt locomotion; locomotion resumes on
   clip end. Specials interrupt normal attacks. A clip that cannot be interrupted queues
   at most ONE follow-up input (inputs during the lock window should not be dropped
   silently — buffer the last one).
3. **Latency budget:** input to first visible animation frame ≤ 100 ms.
4. **Per-mode clip map (minimum M13 set):**
   - Karate: jab, cross, kick, block, chi special, hit-react, KO fall, win pose.
   - Dunk: sprint, gather (2-foot plant), rise with ball, 3 style apex poses that are
     visually distinct (POWER two-hand tomahawk / FLASHY windmill / SIG one-hand cradle),
     rim hang, landing crouch.
   - Football: run cycle with ball tucked, juke L/R (Q/E), spin (S), stiff-arm (F),
     hurdle (SPACE), tackled/wrap, breakaway sprint.
   - Skate/Surf/Snowboard: push/pump, crouch, ollie/pop, 2 grabs, grind balance,
     bail, landing compression.
   - Tennis / Home Run Derby / Penalty: swing/serve/strike/dive clips on their inputs.
5. **State machine debug overlay** (dev flag): show current clip name + state on screen so
   regressions are caught instantly in playtests.

### Acceptance
- Recording of each mode shows a distinct visible animation for every mapped input.
- Frame-step: no input-to-clip latency above 100 ms.
- No mode contains an input that mutates score/state with zero animation response.

## B. Character faces the wrong way (Dunk, Karate, Football)

### Observed
- **Dunk:** during the drive the runner's model is angled away from the basket; at the
  slam window the model's chest faces the sideline/camera while the rim is behind him.
- **Karate:** player and enemies face away from each other and from the camera; fights
  read as people standing in a room ignoring each other.
- **Football:** the runner travels down-field (away from camera) while the mesh faces
  the camera — he back-pedals the entire run.

### Required fix — one orientation system
1. **Single source of truth:** `characterYaw = f(velocity, target)`. When moving:
   face the normalized velocity vector. When engaged (karate opponent, dunk rim,
   football end zone): blend facing toward the engagement target, never away.
2. **Model forward-axis audit:** several rigs appear imported with +Z/-Z (or +X) forward
   mismatches. Normalize every character prefab so its authored forward axis matches the
   engine's forward convention ONCE at import, instead of compensating per mode.
3. **Turn smoothing:** yaw changes slew at a max turn rate (e.g. 540°/s) so characters
   pivot instead of snapping.
4. **Mirrored clips:** karate/football need L/R mirrored strike/juke variants so facing
   stays correct when engaging targets on either side.

### Acceptance
- Dunk: runner's chest faces the rim from gather through slam.
- Karate: player and current target enemy always face each other while engaged.
- Football: runner's chest faces down-field while running; spins rotate a full 360° and
  return to down-field facing.
