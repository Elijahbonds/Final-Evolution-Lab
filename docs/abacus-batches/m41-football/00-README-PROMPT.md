# M41 — FOOTBALL · the invisible game becomes visible

Copy this into Abacus with `files/` + `KNOWN-ERRORS.md`. Prerequisites: M35 +
M37 deployed.

---

## PROMPT FOR ABACUS

### LIVE AUDIT (July 2026, screenshots on file)
Street Football is the strangest broken mode: the LOGIC WORKS — downs advance,
yards accrue, "TOUCHDOWN!" banners fire, rewards pay out — while the field
shows nobody. The runner is out of frame in a corner (E9) and defenders either
never spawn visibly or are lost off-camera. The game literally plays itself
where the player can't see it.

### FILES
| File | Fixes |
|---|---|
| `modes/FootballRushMode.ts` | v2 REPLACEMENT. Chase camera locked to the runner from frame one (`snapTo` + `runner` preset + heroRef/FrameGuard). Defenders are real spawned characters in defense tints pursuing via MobSteering — you SEE who's chasing you. Evasions have teeth: JUKE L/R (X/Y), SPIN (B), HURDLE (A) grant i-frame windows; a timed dodge through contact banners EVADED and scores; an untimed hit is a tackle that advances the down. Full drive flow: 1st & 10 chain, 4 downs, turnover ends the run, 100-yard drives = TOUCHDOWN with a celebration the camera shows, then the next drive. Hit-stop + shake on tackles and evasions (M37 gameFeel). |

### WIRING
1. Drop the file in (REPLACES the live football mode).
2. `modeConfigs.ts`: `export const FOOTBALL_CONFIG = { heroUrl: HERO_URL };`
3. If MobPool lacks `disposeAll()`, add it (dispose each mob, clear list).
4. `modeVerbs.ts` key `football`: HURDLE=A · SPIN=B · JUKE L=X · JUKE R=Y.
5. KNOWN-ERRORS regression sweep before promote.

## ACCEPTANCE (record it)
1. Frame one: runner centered, defense visibly arrayed downfield. Zero
   `[FEL-FRAME]` for a full drive.
2. A timed JUKE through a defender banners EVADED (+points, hit-stop); an
   untimed contact is a visible tackle → next down; 4 failed downs ends the
   run with a result screen.
3. A 100-yard drive shows TOUCHDOWN + celebration ON CAMERA, then resets to
   a new drive with fresh defense.
4. Touch, keyboard (J/K/L/I), and gamepad all trigger all four evasions.
