# M13-03 · P1 — Camera Rig Rules (never lose the action)

## Observed (live playtest, screenshots on file)

1. **Dunk Contest — "RISE…" phase films the floor.** In BROADCAST cam the entire rise is
   a frame of blurry court/water with the player completely out of frame; he re-enters
   only at the slam window. The single most important beat of the mode is invisible.
2. **Dunk Contest — auto camera switching.** Approach starts in FOLLOW, air phase flips
   to BROADCAST on its own; players never get a stable reference.
3. **Karate Endless — pillar occlusion.** The default camera sits so the dojo's central
   structural pillar covers the middle of the arena; the player fights behind it, small
   and far away in the corner of the frame.
4. **Board sports — camera below/along the ground plane.** At speed the camera drops so
   low it looks ALONG (or through) the park surface. Combined with the unlit ground
   material (see doc 05) the world reads as a black void with a sunset skyline strip.
5. **Football — flat framing.** Head-on framing hides depth; distance to defenders is
   unreadable, contributing to instant tackles.

## Required fix — shared camera rig with hard constraints

### Constraint set (applies to every mode)
- **Framing invariant:** the player character AND the current objective (ball, rim,
  target enemy, next gate/kicker) must both be inside the safe frame (inner 80%) at all
  times during active play. If the solver can't satisfy it, widen FOV / pull back —
  never let the subject leave frame.
- **Ground invariant:** camera pitch must keep the ground plane visibly UNDER the
  action. Minimum height above ground: ~1.6 m equivalent; minimum downward pitch on
  fast board modes: 10–18° so the surface is always read as a surface.
  (This is the "elevate the camera so you see the actual ground, not through it" fix.)
- **Occlusion probe:** raycast camera→player every frame; if static geometry (dojo
  pillar!) blocks it, orbit/dolly to the nearest clear angle within 250 ms, or fade the
  occluder to 20% opacity.
- **No autonomous cam mode switches** mid-attempt (see doc 02 §4).

### Per-mode cams (M13 minimum)
- **Dunk:** FOLLOW = behind-shoulder during drive; on liftoff, crane UP with the player,
  keeping player + rim in frame (rim near upper third at apex); on slam, quick push-in;
  brief impact hold (0.2–0.3 s) before landing cam. The ball and rim must be watchable
  the whole flight — the slam QTE should be timeable by WATCHING THE PLAYER REACH THE
  RIM, not by reading a UI bar (see doc 04).
- **Karate:** raised 3/4 side view of the mat, pillar never between camera and player;
  fight distance framed so both fighters are ≥25% of frame height.
- **Football:** behind-runner pursuit cam, slight high angle so the next 15–20 yd of
  defenders are visible and closing speed is readable.
- **Board sports:** chase cam locked above deck height with the downward pitch floor;
  on big air, crane with the rider but keep the landing zone in the lower frame.

## Acceptance
- Full dunk attempt recorded with player+ball+rim visible in every frame from gather
  to landing, in both FOLLOW and BROADCAST.
- Karate: no frame during a full wave where a static prop occludes the player.
- Skate/Surf/Snowboard: no frame where the ground plane is absent from the bottom
  third of the screen while riding.
- Football: at least 15 yards of oncoming defenders visible ahead of the runner.
