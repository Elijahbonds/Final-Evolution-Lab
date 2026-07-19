# M14 — Animation Movie Events · 3D Conversions · 2K Controls · Venue Boxes

Founder playtest gripes + engineering specs. This supersedes nothing — M13's five root
causes still apply; this batch adds the SOLUTION ARCHITECTURE for the animation crisis
and new mode-level direction.

---

## 1. THE ANIMATION CRISIS — diagnosis + the fix architecture

### Observed (founder playtest)
- Characters **T-pose** during strikes: the input triggers (state changes, damage
  registers) but the model holds bind pose.
- **"Penguin walking"** locomotion: feet shuffle with no stride, no weight shift.
- Dunks: **no body parts move** — it does not read as a dunk at any point.

### Root-cause diagnosis (tell the builder to check exactly this)
1. **T-pose = missing/unretargeted clips.** A T-pose means the animation system found
   NO clip and fell back to bind pose — the clips either don't exist, aren't loaded,
   or aren't retargeted to this rig's skeleton. Audit the clip registry: log every
   requested-but-missing clip name. (This matches M13-01's "never silently skip" rule.)
2. **Penguin walk = no root motion + no foot IK.** The capsule slides and legs paddle.
   Either use root-motion clips or match stride cycle speed to actual velocity, and
   add foot-plant IK.
3. Human movement reference: every action clip needs the three phases of real
   biomechanics — **anticipation (windup/load), contact (strike/plant), follow-through
   (recovery)**. A jab loads the shoulder and hips before extending. A dunk gathers on
   two feet, drives knees up, cocks the ball back, extends through the rim, hangs,
   drops. If a clip lacks anticipation and follow-through it will look wrong even
   when it fires. Reference real footage of each motion when authoring/generating.

### THE FIX: "Movie Events" (authored action cinematics) — adopt for ALL key actions
Instead of fighting procedural per-bone animation, every significant input triggers a
**Movie Event**: a pre-authored (or AI-generated, then baked) full-body animation
sequence + a camera track, played in-engine with the live venue in the background.

**System spec:**
- `MovieEvent = { id, actorClip (baked keyframes), cameraTrack, duration, qteWindows[], interruptible }`
- Input fires → gameplay commits the outcome window → the Movie Event plays the
  motion cinematically → results (score/damage) land at the clip's contact frame.
- **QTEs live INSIDE the movie** (e.g., dunk slam timing at the rim-arrival frame) so
  timing stays a skill test while the visual is always correct.
- Camera cuts to the authored angle for the event, then returns to gameplay cam
  (respect M13-03 framing rules; events are exempt because they own their camera).
- The scene keeps simulating in the background — this is in-engine cinema, not video.
- Library needed for v1 (each 1–3 s): dunk ×3 styles (POWER/FLASHY/SIG), karate
  jab/cross/kick/block-react/chi-special/KO, football juke L/R/spin/hurdle/stiff-arm/
  tackle, skate ollie/grab×2/grind/bail, baseball swing×3 outcomes, golf drive/chip/
  putt, tennis serve/forehand/backhand.
- **AI-generation pipeline note:** these Movie Events double as the reference source
  for AI-generated animation clips — generate against the biomechanics phase spec
  above, bake to keyframes, register in the clip library. One pipeline, every mode.
- Locomotion stays procedural (walk/run/carve loops with root motion + foot IK);
  ACTIONS become Movie Events. This split is the pragmatic path to shipping feel.

**Acceptance:** zero T-poses anywhere (a missing clip shows the fallback action clip +
logs); every action listed above plays a full anticipation→contact→follow-through
motion with a camera that shows it; dunk reads as a dunk with the ball in hand
throughout (M13-04 ball pipeline still required).

---

## 2. VENUE BOXES — fix every background with 4 walls

Every scene gets a **venue box**: four large backdrop walls (+ sky) at distance,
art-directed per venue, so no camera angle ever shows void/black horizon.

- Walls are simple large quads/curved billboards with venue art (parallax-friendly,
  lit consistently with the scene). Cheap, and kills the "flooded void" look.
- **Venice Beach Court (dunk, 1v1, 3v3):** ocean + pier wall on one side; boardwalk
  wall with vendors + palm line; **bleachers wall** with crowd; **bathrooms/showers
  building** + graffiti wall; **the Hoopbus** parked courtside; blacktop court surface
  (opaque — no water shader on the floor). Golden-hour sky stays.
- **Venice Skatepark:** boardwalk + palms, graffiti bowls, spectator fence line.
- **Shimogamo Dojo:** keep (it works); just complete the 4th wall when camera swings.
- **The Gridiron:** street walls — fences, murals, container stands, floodlight rigs.
- **Catalina Ballpark / golf course / tennis / slope / surf:** same 4-wall treatment
  with venue-appropriate art.
- **Lighting floor (global):** no surface may render black — ambient minimum on all
  materials (this is also why FOOTBALL DEFENDERS ARE NOW INVISIBLE: they're unlit in
  a dark scene; same root cause as the black skatepark). Fix lighting + color grade
  for ALL board sports and the Gridiron: sunset warmth, readable surfaces, contact
  shadows.

---

## 3. MODE DIRECTION CHANGES

### 3.1 Karate 1v1 → **Soul Calibur-style mixed combat**
- **8-way movement** around your opponent (left stick), lock-on facing (M13-01 §B).
- Four attack verbs on the face buttons: **A horizontal strike · B vertical strike ·
  X kick · Y guard** (hold Y = block, Y+direction = sidestep guard). Throws = A+B
  close-range. Chi special on R2 when meter full (Movie Event).
- **Character-bound items/weapons:** if a signature item is part of your character
  (equipped cosmetic/loadout — e.g., a keyblade-class item), it appears in the fight
  and re-skins the strike Movie Events (weapon arcs instead of fists). Movesets can
  differ in STYLE; stats stay fair (no pay-to-win — item = moveset skin + reach
  class, tuned equal).
- Ring positioning matters: pushback on blocks, ring-edge danger zone (no ring-outs
  v1, just corner pressure).
- Rounds: best-of-3, KO freeze-frame + winner pose Movie Events (M13-07).

### 3.2 Basketball 1v1 + 3v3 → **2K-familiar console controls, free movement**
Founder intent: a 2K player picks this up with zero relearning. Map onto the
universal controller (docs/handoff/03):
- **Left stick:** free dribble movement (full-court open movement — 3v3 must become a
  free-moving dribble system, not stations/zones).
- **Right stick = Pro-stick:** dribble moves in open floor (flick L/R = crossover,
  half-circle = spin, back = stepback); hold = shot stick (release timing = shot
  meter).
- **R2:** sprint. **L2:** post-up/protect ball.
- **A** shoot (alternative to shot stick, same meter) · **B** pass · **X** pump
  fake/steal (defense) · **Y** alley/lob (offense) / block (defense).
- Shot meter with green-window release; defenders play real on-ball defense.
- 3v3: teammate AI runs cuts/screens; B targets nearest cutter; icon-pass later.
- Same map for 1v1 minus pass verbs. Momentum/clutch systems from the iOS reference
  designs (see handoff 00 — port mechanics from `FinalEvolutionLab/Views/`).

### 3.3 Baseball → **3D, Wii-Sports-style** (currently 2D stick figures — furthest
from vision)
- Rebuild Home Run Derby on the SAME 3D pipeline as dunk/karate: 3D batter avatar at
  Catalina Ballpark venue box, pitcher winds (Movie Event), ball 3D flight in, swing
  = timing + R-stick/stick aim, contact Movie Event (drive/liner/pop) with ball-flight
  camera, distance celebration. Wii Sports Baseball is the explicit look/feel bar:
  chunky, readable, joyful.

### 3.4 Golf → **3D, Wii-Sports-style** (currently 2D)
- 3D tee box + fairway venue box; three-tap/hold-release swing meter on A or R2
  analog (backswing depth = power), stick = aim, wind indicator; drive/chip/putt
  Movie Events; ball-follow camera (M13-03 rules). Wii Sports Golf is the bar.

### 3.5 Skate Run → **bigger park, natural riding**
- Expand the map: at least 3 linked zones (street rail lines → bowl → vert quarter)
  with a flowing loop; spawn variety.
- Riding animation: continuous carve lean, crouch-pump on transitions, arm balance —
  no static statue on a board. Push-off Movie Event on start; trick Movie Events on
  R-stick flicks (Board sports also inherit §2 lighting fixes + M13-05 ground/contact
  fixes.)

### 3.6 Street Football — regression + spec
- **Defenders currently INVISIBLE** (regression from pink capsules — unlit materials
  in a dark scene, see §2 lighting floor). After lighting fix, M13-06 still stands:
  skinned moving defenders, evade Movie Events (juke/spin/hurdle/stiff-arm),
  survivable opening, Gridiron venue box.

---

## 4. PRIORITY ORDER FOR THIS BATCH
1. §1 clip-registry audit + Movie Event system + locomotion (root motion/foot IK) —
   this unblocks every mode.
2. §2 lighting floor + venue boxes (Venice first, then Gridiron/board sports).
3. §3.2 2K controls for 1v1/3v3 (the flagship family) + §3.6 football regression.
4. §3.1 Soul Calibur karate 1v1.
5. §3.3 baseball 3D + §3.4 golf 3D conversions.
6. §3.5 skatepark expansion.

## 5. ACCEPTANCE (quick list)
- No T-pose reachable in any mode; no black surfaces at any camera angle.
- Every action verb plays a full-motion Movie Event with correct camera; dunk looks
  like a dunk end-to-end with ball in hand.
- Venice shows ocean/boardwalk/bleachers/bathhouse/vendors/Hoopbus walls in-play.
- A 2K player can run 1v1/3v3 without reading instructions (stick dribble, shot
  stick + meter, R2 sprint).
- Karate 1v1: 8-way movement, 4-verb combat, guard works, signature item renders in
  hand and re-skins strikes.
- Baseball and golf are 3D with avatar swings (Wii-Sports readability bar).
- Football defenders visible, lit, moving, evadable.
- Skatepark: 3 zones, natural carve/pump riding, trick events.
