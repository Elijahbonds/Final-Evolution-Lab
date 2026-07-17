# M13 BATCH — READ FIRST · Scope & Priority Order

**App:** finalevolution.abacusai.app (nexusllm.abacusai.app serves the same build)
**Source:** Live playtest, desktop Chrome 1280×800 + mobile viewport, July 2026.
Guest dunk flow, authenticated account, Karate Endless, Skate Run, Street Football all played hands-on.

## What this batch is

Milestone 13 is the **game-feel milestone**. The meta layer is already good — season pass,
PRQ/XP/shards result screens, hub, arena picker, guest funnel all work and look clean.
Every problem in this batch lives in the 3D gameplay layer, and they cluster into five
systemic root causes. Fix the root causes once, in shared systems, and every mode inherits
the fix. Do NOT patch mode-by-mode.

## The five root causes (fix in this order)

1. **Animations do not fire on input** (doc 01)
   Attack/trick/juke inputs change game state but the character mesh never plays a clip.
   Verified in Karate (J/Space/E → no pose change), Skate (trick keys → nothing),
   Football (tackled before any anim). This is the #1 feel-killer across the app.

2. **Character orientation/facing is wrong** (doc 01, section B)
   Player model faces away from or perpendicular to its movement/target in Dunk, Karate,
   and Football. Root cause is shared: model forward-axis vs. movement vector is not
   reconciled in one place.

3. **No uniform touch controller overlay** (doc 02)
   A gamepad FAB exists in Karate/Skate but not Dunk/Football; the guest dunk shows
   keyboard-only hints ("WASD — drive the lane") on mobile where there is no keyboard.
   One shared `ControllerOverlay` component must mount in EVERY mode.

4. **Camera framing loses the action** (doc 03)
   Dunk "RISE" phase shows only the floor (player/ball out of frame). Karate camera sits
   behind a structural pillar occluding the arena center. Board-sport camera drops so low
   the ground plane disappears (backface/see-through) and reads as a black void.

5. **Placeholder capsules instead of skinned characters** (docs 04, 06)
   Dunk opponent and all six Football defenders are static pink capsules. Defenders must
   be skinned, animated, and actually move.

## Priority order for the pass

| # | Ticket | Doc |
|---|--------|-----|
| P0 | Shared animation driver — inputs trigger clips in all modes | 01 |
| P0 | Facing/orientation reconciliation (one shared system) | 01 |
| P0 | Uniform ControllerOverlay in every mode, mobile + desktop | 02 |
| P1 | Camera rig rules: never lose player+ball/target from frame | 03 |
| P1 | Board sports: ground always visible — raise camera, fix material/lighting, fix rider float | 05 |
| P1 | Football: skinned moving defenders, juke/spin/hurdle anims, survivable opening | 06 |
| P2 | Dunk: ball attached to hand, visible flight, slam timed by watching the ball | 04 |
| P2 | Karate: attack anims, wave logic (no "WAVE CLEAR · 0 KO"), de-occluded camera | 07 |
| P2 | QA acceptance checklist for the whole batch | 08 |

## Global acceptance bar for M13

- Every player input that changes game state plays a visible animation within 100 ms.
- Player character always faces its movement direction (or its target when engaged).
- The controller overlay renders in every mode on touch devices, with the same layout
  language; desktop shows matching key hints.
- The player, the ball (when one exists), and the current objective are inside the
  camera frame at all times during active play.
- No pink capsule placeholder is visible anywhere in a shipped mode.
