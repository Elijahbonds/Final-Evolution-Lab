# M40 — PRECISION SPORTS · tennis / golf / baseball / soccer rebuilt with athletes

Copy this into Abacus with `files/` + `KNOWN-ERRORS.md`. Prerequisites: M35 +
M37 deployed.

---

## PROMPT FOR ABACUS

### LIVE AUDIT (July 2026, screenshots on file)
All four modes (E11): rounds tick, a ball sometimes moves — but **no athlete
ever spawns**, no net/flag/plate/keeper exists, and there's no readable loop.
Golf and baseball are an empty green plane. This batch rebuilds all four on
one shared core.

### FILES
| File | What it builds |
|---|---|
| `modes/aimSwingCore.ts` | The shared engine: real athlete spawning (grounded, neverBindPose, heroRef), aim Reticle, oscillating PowerMeter, swing-timing quality, ballistic Flight, and the missing furniture — tennis net+posts+tape, golf green+hole+flag, home plate+pitcher's mound, regulation goal+net. |
| `modes/precisionModes.ts` | All four modes, REPLACING the live ones: **Tennis** (7 timed returns, stick steers placement, sweet-spot bonuses) · **Golf** (3 shots: aim → power wave → strike, distance-to-pin scoring, hole-out = 100) · **Home Run Derby** (10 pitches from a VISIBLE pitcher, timing × launch angle = distance points) · **Penalty Shootout** (5 kicks: aim inside the frame, power vs accuracy tradeoff, keeper reads your aim 62% and dives). |

### WIRING
1. `modeConfigs.ts`: add `export const PRECISION_CONFIG = { heroUrl: HERO_URL };`
2. Alias table (M24): map `tennis_forehand`, `golf_address`,
   `golf_drive_swing`, `derby_bat_stance`, `derby_swing`, `derby_pitch`,
   `penalty_strike`, `keeper_dive_left/right` to the closest real GLB clips
   (fallback chain → `idle_stand`; zero MISSING CLIP allowed).
3. `modeVerbs.ts` keys = live slugs: `tennis`, `golf`, `baseball`, `soccer`
   (rename `derby`/`penalty` keys). One button each (A) + stick aim.
4. M34 venue pass stays (field/stadium walls); this batch adds the sport
   furniture on top.
5. KNOWN-ERRORS regression sweep before promote.

## ACCEPTANCE (record each)
1. Every mode shows a real athlete swinging on every action — E11 checks:
   `[FEL-SPAWN] OK` ×4, zero `[FEL-FRAME]`, no T-pose/sink frames.
2. Tennis: 7 returns with visible net; a perfectly timed return banners SWEET
   SPOT; a late swing whiffs and the round advances (no stall).
3. Golf: flag + green visible from the tee; power wave reads on the HUD;
   hole-out path scores 100; card completes after 3 shots.
4. Baseball: pitcher visibly winds up and throws all 10; a squared-up swing
   banners DINGER; whiffs advance (no stall).
5. Soccer: keeper dives every kick; GOOOAL/SAVED/OFF TARGET all reachable;
   shootout ends after 5 with the tally.
6. Touch, keyboard (J = swing/strike/kick), and gamepad all work on all four.
