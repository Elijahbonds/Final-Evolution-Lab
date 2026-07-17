# M13-05 · P1 — Board Sports: Ground Rendering, Floating Rider (Skate · Surf · Snowboard)

## Observed (live playtest — Skate Run, Venice Skatepark)

1. **The entire park surface renders BLACK.** During a full 2:00 run at speed 63–65,
   the ground, ramps, rails, and bowls were a featureless black void; only a sunset
   skyline band at the top of frame proved the renderer was alive. The park geometry
   from the arena-picker thumbnail (which looks great) is invisible in play.
2. **See-through at angles:** as the camera dips with speed, the surface disappears
   entirely — consistent with looking along/under a plane whose backfaces are culled,
   and/or a material that receives no light.
3. **Rider floats.** The skater hovers with a glowing marker at the feet; no contact
   shadow, no board visibly touching a surface — because the surface isn't visible.
4. Trick inputs show no animation (covered by doc 01) and score stayed 0.

Surf and Snowboard share the camera/board pipeline — apply the same audit to all three.

## Required fix

### A. Ground visibility (three layers, all needed)
1. **Material/lighting:** the park surface material currently receives no light or is
   unlit-black. Give ground materials an ambient floor (or bake light) so they can never
   render pure black regardless of sun angle. Verify the sunset directional light
   actually illuminates the ground layer (check light layers/masks).
2. **Geometry:** ground meshes must be double-sided OR guaranteed camera-above-surface
   (see C). No open backfaces facing the sky.
3. **Ground read at speed:** add surface detail that communicates motion — concrete
   texture, painted lines, grind-edge highlights. A uniform surface at speed reads as
   void even when lit.

### B. Rider grounding ("floating issue")
- Foot/board IK or transform snap to the surface height under the board each frame.
- Blob/contact shadow under the board at all times (cheap, huge effect).
- Landing compression animation on touchdown (doc 01 clip map).

### C. Camera (with doc 03)
- **Elevate the chase cam:** min height above surface + 10–18° downward pitch so the
  player sees the actual ground plane ahead. This is the specific fix requested:
  raise the camera so you see the ground, not through it.
- Never allow the camera origin below surface height + 0.5 m.

### D. Fast sanity pass on Surf + Snowboard
- Same checklist: surface lit and opaque at every legal camera angle, rider/board
  contact, camera pitch floor. Snowboard slalom gates and surf wave face must be
  readable 20+ m ahead at top speed.

## Acceptance
- Full Skate Run recording: park surface visibly textured and lit in every frame;
  ramps/rails identifiable; no black-void frames.
- Rider's board contacts the visible surface with a contact shadow throughout;
  no hovering at rest or in carve.
- Same pass verified in Surf Break and both Snowboard modes.
