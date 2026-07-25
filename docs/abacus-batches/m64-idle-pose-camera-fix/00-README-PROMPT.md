# M64 — PLAYTEST FIXES: natural idle pose (E25 closed), camera burial fix (E26), deep-ocean court

Copy this into Abacus with every file in `files/`. Prerequisites: M42+, M50
(CameraDirector), M63. `CameraDirector.ts` and `locomotion.ts` REPLACE their
predecessors by filename; `restPose.ts` and `CourtSurface.ts` are NEW.

---

## PROMPT FOR ABACUS

### 1. THE "EVERYTHING LOOKS T-POSED" ANSWER — it was the idle clip
The M63 live sweep settled the long-running E25 question: the charge pose is
visibly bent-forward, clearly different from idle, so **skeletal animation
works and always did** (exactly what the M51 instrumentation kept saying).
The real problem is content: the authored `idle_stand` keys the arms only
~8-10° off this rig's arms-out bind pose, so a standing character is
essentially indistinguishable from bind. Every mode's default look was a
near-bind pose.

**The fix, without guessing:** which axis and which sign swings an arm DOWN
is rig-dependent, and guessing wrong makes arms swing UP — worse than
nothing. `restPose.ts` MEASURES it instead: it tries a rotation about each
principal axis in both directions on the live skeleton, recomputes world
matrices, reads the resulting hand height, and keeps the candidate that
lowers the hand most without pulling it through the torso. Original pose
always restored; ~1ms once per spawn; logs what it solved.
`locomotion.ts` v2 then builds `idle_stand` and both strafes on that
measured rest pose (with the same breathing motion layered on), and falls
back to the exact M24 clip if a rig ever fails to yield a solution.
Because `idle_stand` is the base loop `neverBindPose()` returns to
everywhere, this one file fixes the standing pose in **every mode at once**.

### 2. E26 — the camera buries itself in the baseline wall
Found in the same sweep (1v1 late frame = a wall of flat paint; 3v3 = camera
under the court). **Root cause, confirmed by reading VenueKit:** the
occlusion probe filters on `isPickable && checkCollisions`, but VenueKit
builds `venue_ground` with `checkCollisions = false` and the walls as plain
planes with no collision flag — so **the probe has never been able to see a
venue wall at all.** That's also why the console showed zero `[FEL-FRAME]`
warnings while the camera sat inside one.
CameraDirector v2.5 fixes it three ways: the probe now also accepts meshes
matching the venue-shell name pattern (characters/props/backdrop still
excluded, so it can't yank in on a player); the final position is clamped
inside the venue's own auto-derived bounding box and above its floor; and
the fitTwo separation pull-back is capped (uncapped, a full-court 3v3
possession pushed the `team` preset clean through the back wall).
Bounds derive automatically on preset change — `setBounds()` /
`invalidateBounds()` are there if a mode wants explicit control.

### 3. THE DEEP OCEAN COURT (your ask)
`CourtSurface.ts` repaints the Venice court as **deep ocean-blue water**:
a depth gradient from the baseline, 26 long swell bands, 13 breaking crests
with broken foam lace, ~900 caustic glints, and a fine per-pixel breakup
pass that gives the surface the uneven, "captured" density of a photogram-
metric scan instead of flat vector fill — plus regulation court lines laid
over the top with a dark under-stroke so they stay readable against foam,
and a wet sheen so they sit IN the water rather than on it. The material
carries a real specular lobe (that's what separates "ocean" from "blue
floor", and it plays into M59's rim light and bloom), and the texture UVs
drift slowly so the surface breathes. Zero image assets — it holds the
project's procedural rule. `midnight` variant included for stadium-lit use.

### FILES
| File | What it does |
|---|---|
| `files/anim/restPose.ts` | **New.** Empirical arms-down solver + quaternion clip builder. |
| `files/anim/authored/locomotion.ts` | v2 — idle/strafes on the measured rest pose. REPLACES M24's. |
| `files/core/CameraDirector.ts` | v2.5 — venue-shell occlusion, bounds clamp, separation cap. REPLACES M50's. |
| `files/visual/CourtSurface.ts` | **New.** `applyOceanCourt(scene, style)`. |

### WIRING
1. Drop all four files in (two replace by filename).
2. **One line per basketball mode**, immediately after
   `VenueKit.buildCourt(ctx.scene, 'venice')` in `load()` of
   `DunkMode` / `OneVOneMode` / `ThreeVThreeMode` / `DunkDuelMode`:
   ```ts
   import { applyOceanCourt } from '../visual/CourtSurface';
   applyOceanCourt(ctx.scene, 'venice');
   ```
   (Dunk Contest builds its court through the same VenueKit call — same line.)
3. Nothing else changes. The idle and camera fixes need no wiring at all.
4. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. Stand still in ANY mode — the character's arms hang naturally at their
   sides, clearly not the arms-out bind pose. Console logs
   `[FEL-ANIM] restPose solved for N bone(s)` once per character.
2. If a rig ever fails to solve, the console warns and the old idle plays —
   never a broken pose.
3. 1v1/3v3: drive to the rim and shoot repeatedly — the camera never fills
   the frame with flat wall paint and never dips under the court. If it does
   get boxed in, `[FEL-FRAME]` now actually fires (it couldn't before).
4. 3v3: a full-court possession no longer pulls the camera past the back wall.
5. The court reads as deep ocean water with visible swells, crests and foam,
   court lines clearly legible over it, surface subtly drifting.
