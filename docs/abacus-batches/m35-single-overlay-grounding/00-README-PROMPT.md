# M35 — STOP THE REGRESSION · One Overlay · Grounded Characters · Karate + Dunk v2

Copy this document into Abacus with every file in `files/`. This batch includes
DELETIONS — the regression is coming from old and new systems running at once.

---

## PROMPT FOR ABACUS

### LIVE AUDIT (screenshots on file, July 2026)
Progress confirmed deployed: M30 (zero MISSING CLIP errors), M34 dojo venue
renders (tatami/walls/lanterns visible). Regressions confirmed:
1. **TWO control sets render simultaneously** in karate (in-canvas
   MOVE/PUNCH/KICK/BLOCK/HEAVY circles AND a bottom deck JAB/KICK/SPCL/BLOCK
   + joystick). Neither drives the Babylon InputBus → buttons "don't work."
2. **Characters sunk to their waists in the floor, arms spread** — imported GLB
   clips animate `Hips.position` in the clip's own space (below our floor), and
   finished one-shot clips leave the rig in bind pose (T-pose returns).
3. Camera in karate is too high/far (subjects tiny at the top of frame).
4. Dunk: same input wiring gap — the on-screen buttons don't reach the mode.

### ROOT RULE THIS BATCH ENFORCES: ONE OF EACH, DELETE THE REST
The build regresses because parallel implementations coexist. After this batch:
- **Exactly ONE touch control component** (`TouchOverlay.tsx`) mounted by the
  harness. **DELETE** the legacy in-canvas control circles (the component
  rendering MOVE/PWR/FLSH/SIG/CHARGE/SLAM and PUNCH/KICK/BLOCK/HEAVY inside
  the game frame) and any second deck. Grep for those verb strings — remove
  every render path except TouchOverlay.
- **Exactly ONE animator path** (M30 CharacterAnimator + `importSanitizer`).
- If a file in this batch shares a name with an earlier one, it REPLACES it.

### FIXES IN THIS BATCH
| File | Fixes |
|---|---|
| `files/ui/TouchOverlay.tsx` | THE single control deck: portrait bottom-deck / landscape side overlay, per-mode verbs, wired to InputBus.emit with press+release, analog HOLD button (charge), stick vector streaming. |
| `files/ui/modeVerbs.ts` | Verb/button config for every mode (labels, FelInput bindings, hold buttons). |
| `files/anim/importSanitizer.ts` | (a) strips `position` tracks targeting Hips from IMPORTED groups (authored clips keep theirs — tuned to our floor); (b) `neverBindPose()` — every non-looping play auto-returns to the mode's base loop; (c) `GroundLock` per-frame clamp: root.y ≥ 0, hips ≥ 45% of bind height — sinking becomes impossible. |
| `files/modes/KarateEndlessMode.ts` | v2 REPLACEMENT: spawn separation (no overlap), 'fight' camera actually applied (low 3/4 framing), strikes wired to overlay actions with auto-return-to-stance, KO sink+despawn, KO-gated waves, chi meter hooks. |
| `files/modes/DunkMode.ts` | v2 REPLACEMENT: touch-first flow (HOLD CHARGE button = analog charge, release = launch; style buttons pre-select; SLAM pulses when the window opens), cinematic watchdog (sequence can never stall — auto-resolves as miss), ball attached from spawn, works identically via keyboard/gamepad. |

### WIRING / ORCHESTRATION (deploy order matters)
1. Confirm M30 + M34 fully deployed (they are prerequisites).
2. Apply `importSanitizer` inside CharacterLibrary.spawn (one call, marked in
   the file) and mount `GroundLock` in ModeHarness's render loop.
3. Replace KarateEndlessMode + DunkMode files.
4. Mount TouchOverlay from ModeHarness (per-mode verbs from modeVerbs.ts);
   DELETE legacy overlays (grep list above) — the acceptance requires exactly
   one control set in the DOM.
5. Re-run the smoke test (M31) — it must pass before promote.

## ACCEPTANCE
1. DOM census on karate + dunk (mobile viewport): exactly ONE stick and ONE
   action cluster; every verb press visibly acts in-game (recorded).
2. Karate: fighters stand ON the tatami at all times (record 60s incl. strikes,
   hits, KO — no waist-sinking frame, no T-pose frame); KO'd enemies sink+fade
   then despawn; camera at fight framing (both fighters ≥25% frame height).
3. Dunk: full touch-only attempt on a phone viewport — hold CHARGE, release,
   style pick, SLAM pulse tap → flush + score; then a deliberately ignored
   slam auto-resolves as a miss (no stall).
4. Smoke test green across all modes; screenshots attached to the report.
