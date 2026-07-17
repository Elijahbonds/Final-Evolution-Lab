# M13-06 · P1 — Street Football (The Gridiron)

## Observed (live playtest)

1. **Defenders are six static pink capsules.** No skinned meshes, no run cycles, no
   pursuit angles — pills floating on a dark field.
2. **Tackled at 17 yards in ~2 seconds, 0 evaded.** The run starts the instant the scene
   loads (no ready gate), the first defenders are on top of you immediately, and there is
   no window to read the controls caption (←/→ or A/D steer · Q/E juke · S spin ·
   F stiff-arm · SPACE hurdle).
3. **Runner uses a wrong/placeholder animation and faces the camera** while moving
   down-field — he back-pedals holding a white slab (the "ball" reads as a rectangle,
   not a football). The locomotion looks borrowed from another mode's rig setup
   (board-sport-style glide rather than a sprint cycle).
4. **No juke/spin/hurdle/stiff-arm animations** — the moves exist as inputs but nothing
   plays (doc 01).
5. **The Gridiron is a void:** black ground, neon side lines, nothing else. No street
   context, no chains/yard markers, no crowd, no end zone celebration.
6. Result screen (XP/shards/season XP/CHALLENGE A FRIEND/REPLAY) is polished — keep it.

## Required fix

### A. Skinned, moving defenders (the headline fix)
- Replace all capsules with skinned defender characters running real pursuit:
  - Run cycle + closing-angle steering toward the runner's predicted position.
  - Dive/wrap tackle animation on contact; whiff animation when evaded.
  - Spawn waves down-field with lane variety so steering matters, and give them
    realistic closing speeds (see C).
- Defenders must be visibly moving at all times — juking a STATIC pill is meaningless;
  the requested experience is hitting spin moves ON moving, skinned defenders.

### B. Runner
- Proper sprint cycle with a tucked FOOTBALL (real ball mesh), chest facing down-field
  (doc 01 §B).
- Move set with i-frames/evade windows: juke L/R (lateral burst), spin (360° with
  brief tackle immunity), hurdle (over diving tacklers), stiff-arm (breaks wrap from
  the stiff-arm side). Each with its clip and a small camera/FX accent.
- Successful evades feed an EVADED counter and score multiplier (counter exists — wire
  the feel: slow-mo 0.15 s + score pop on each evade).

### C. Difficulty curve / survivability
- Ready gate + 3-2-1 (doc 02 §3). First defender contact no earlier than ~15 yd AFTER
  the gate, first 20 yd tuned so an average first run reaches 30+ yd.
- Closing speed scales with yards gained; breakaway sprint state past 50 yd.

### D. Controller overlay
- Full overlay config (doc 02): stick steer, A hurdle, B spin, X/Y juke, shoulder
  stiff-arm. Touch-playable end to end.

### E. Field dressing (M13-light)
- Lit street-asphalt field, yard markers every 10, end zone, simple sideline set
  dressing (fences/lights/billboard). End-zone celebration clip on a TD.

## Acceptance
- Recording: runner with proper sprint + football, at least 3 distinct evade moves
  landing against MOVING skinned defenders, one full-field TD run possible.
- No capsules anywhere. No tackle before the post-gate grace distance.
- Playable with thumbs on mobile via the overlay.
