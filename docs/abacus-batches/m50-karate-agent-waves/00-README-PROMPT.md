# M50 — KARATE ENDLESS → "AGENT WAVES": third-person combat, co-op-ready ally, horde waves, reward-dodge

Copy this into Abacus with every file in `files/`. Prerequisite: M42, M45,
M47, M48 deployed. Files here are the current versions with this batch's
changes layered in — each REPLACES its predecessor by filename.

---

## PROMPT FOR ABACUS

### THE ASK, TRANSLATED INTO BUILDABLE SYSTEMS
The reference was third-person combat against waves of identical suited
pursuers, with a slow-motion dodge — a well-known action-horde template.
Four concrete systems make that feel real, all shipped:

1. **Third-person over-the-shoulder camera.** `CameraDirector`'s new
   `overShoulder` preset sits close and low, offset to one shoulder, and
   locks to your FACING direction rather than framing the nearest enemy the
   way the old `fight` preset did — this is the actual mechanical
   difference between "fighting game side-view" and "action game combat
   cam."
2. **Co-op-ready ally.** A second fighter built on `PlayerSlot` (the same
   abstraction M48 built for basketball) fights alongside you. Today it's
   driven by a simple always-on AI; because it already reads intent through
   the same `ControlSource` contract a real second player will use, turning
   this into networked co-op later is "point a transport at the slot," not
   "rewrite combat." Same honest boundary as M48 — no networking code
   shipped blind against infrastructure this repo can't see.
3. **A dodge with a real reward window.** BLOCK (X) is now dual-purpose:
   hold it to guard as before, or quick-tap it (under 220ms) for a
   directional dodge roll with genuine invincibility frames. Slip a hit in
   the last ~90ms of that window and you get a **local slow-motion beat**
   (0.6s, scoped to this mode only — not a global engine hijack) as the
   payoff for a well-timed dodge.
4. **Horde-scale waves.** Bigger counts (up to 12, was 6), faster ramp, and
   every enemy now materializes with a cyan glitch-burst spawn-in and a
   scale-up animation instead of just appearing — reads as pursuers being
   deployed, not a static roster waiting in the room.

### IP SAFETY (read this before wiring)
This is built to match the requested GAMEPLAY FEEL using entirely original
content — no franchise names, character names, dialogue, or the specific
green-cascading-code visual motif appear anywhere in this file. Enemies are
unnamed, dark-suited, and rendered in a cyan/white palette instead. This
follows the exact same standing rule already enforced for NeuroArena's Who
Scene It (original content only, no real IP). Please keep any copy/marketing
around this mode (card titles, descriptions) similarly generic if it's
rebranded away from "Karate Endless."

### FILES
| File | What it does |
|---|---|
| `files/core/CameraDirector.ts` | v2.4 — adds `overShoulder` (close, low, shoulder-offset, facing-locked) on top of M48's presets. Additive only. |
| `files/core/PlayerSlot.ts` | Unchanged from M48 — re-shipped for self-containment. The co-op input abstraction this mode's ally uses. |
| `files/anim/clipRegistry.ts` | Unchanged from M47 — re-shipped for self-containment. |
| `files/visual/EffectsKit.ts` | v2 — adds a `glitch` burst kind (tight, fast, cyan/white) for the enemy spawn-in flourish. Everything else byte-identical to M34. |
| `files/modes/KarateEndlessMode.ts` | The full rebuild described above. |

### WIRING
1. Drop every file in — each REPLACES its predecessor by filename.
2. No new `modeVerbs`/TouchOverlay/KeyboardMap changes — the dodge reuses
   the existing BLOCK (X) binding by timing the press/release instead of
   adding a new button.
3. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. Camera stays locked behind the player's shoulder as they turn to face
   different enemies — never re-centers on the "fight" midpoint framing.
2. An ally fighter is visible from load, moves toward and strikes the
   nearest enemy on its own, and never needs player input to function.
3. Quick-tap BLOCK dodges with a visible roll and brief invincibility;
   holding BLOCK still guards as before. Timing a dodge against an
   incoming hit at the last instant triggers a visible slow-motion beat
   that ends on schedule (~0.6s) and never gets stuck.
4. A wave of up to 12 enemies materializes with a visible glitch-burst
   pop-in, not an instant appear. No T-pose, no stalls, hero always framed.
