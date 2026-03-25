# Gameplay Production Readiness

## Current state (freestyle dunk)

The only playable game mode is **solo freestyle dunk** in the Lab. The following are production-level.

### Game flow

1. **Idle** → User picks finisher, taps "Start approach".
2. **Get Ready** → Full-screen 3-2-1-GO with subtitle (hold stick ↑, release to launch, face buttons to finish).
3. **Full-screen play** → Approach (hold left stick up to sprint) → Release stick → Launch (tap face in green zone to jump) → Airborne (face buttons = finishers) → Landing (game auto-transitions) → Tap face to stick the landing.
4. **Result** → ResultScreen shows score, shards, PRQ; "Back to Lab" dismisses and scrolls to court.
5. **Cleanup** → Timer cancelled on Close or Claim; state reset so another round can start.

### Mechanics and logic

- **Scoring:** Single execution per dunk (guard: `freestyleJudgeScores == nil`). Shards 5–35, persisted via SaveSystem.
- **Phases:** Idle → approach → launch → airborne → landing → scored. Face button in **airborne** = finisher only (processArcadeInput). Face button in **landing** = confirm landing and run scoring.
- **Timing:** Launch green zone and landing green zone from DunkContestEngine; air time and rotation drive score.

### Controls and responsiveness

- **Left stick:** Hold threshold 0.28, release threshold 0.18 (hysteresis). Stick input drives sprint charge in full screen.
- **Face buttons:** One tap = one action. Haptic: launch (medium/light), landing (heavy), score (success/warning).
- **Close / Claim:** Both cancel the 16 ms game timer and dismiss; no stuck phases.

### Animations and visuals

- **RealityKit:** Phase-based dunker pose (lean, arms, squash on land), court lines (center, key, arc), key/fill/rim/ambient lights, rim flash on impact.
- **UI:** Phase label, jump height %, in-phase hints, screen shake and dunk flash on score.

### Assets

- **Required:** None. Court, dunker, hoop, net, and rim flash are procedural (RealityKit meshes and materials).
- **Optional for polish:** Sound effects (rim, crowd, UI) via AVFoundation or system sounds; skinned character + animation when moving to Unreal.

### Suggested next steps (optional)

- Add optional sound hooks (e.g. play system sound on launch, land, rim, score).
- If you add more game modes later, reuse the same flow (Get Ready → Play → ResultScreen) and guards (no double-score, timer cancel on exit).
