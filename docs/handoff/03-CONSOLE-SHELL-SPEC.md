# 03 — CONSOLE SHELL SPEC · "The Emulator"

The defining product surface: the app looks like a console and controls like a
handheld. One shell, every mode. This spec is implementation-ready.

---

## PART 1 · THE CONSOLE (visual layout)

### 1.1 Home screen ("the dashboard")
Layout language of a modern console home, tuned for web:
- **Top bar:** athlete avatar chip (tap → Profile) · PRQ pill · LC pill · streak flame.
- **Cartridge rail (the centerpiece):** horizontally scrolling row of large game-mode
  cards ("cartridges") with venue key art, mode name, and a live glint on the
  suggested next mode. Snap scrolling; joystick/d-pad moves the focus highlight
  (console-style focus ring); A/tap launches. Long-press/Y flips the card to show
  personal best, PRQ yield, and friends' scores.
- **Second shelf:** Season Pass tier strip · Signature Challenge · Triumph Arena ·
  Venues (Shop, Gym) as smaller tiles.
- **Bottom dock:** Home · Modes(Library) · Coach · Story · Profile — persistent.
- Background: subtle animated venue skybox of the focused cartridge (golden hour).

### 1.2 Launch / exit ritual (the emulator fantasy)
- **Launch:** card zooms to full-bleed "cartridge insert" (300–450 ms), mode **boot
  splash** (venue art + mode logotype + loading %), then **READY gate** — controller
  overlay fades in FIRST, then 3-2-1 → GO. Input before GO is ignored (m13-02 §3).
- **Exit/pause:** dedicated HOME button on the console frame (see 2.1) opens the pause
  sheet: Resume · Restart · Controls · Quit-to-Home. Quit plays a quick "eject" back
  to the rail with the card still focused.
- **Result screen** (existing, good) becomes the "post-game card" inside this ritual:
  result → eject → rail.

### 1.3 The console frame
During gameplay the viewport is framed as the console's "screen":
- Slim bezel chrome (theme-colored, venue-tinted) with: HOME button, camera toggle,
  mute, and the score/PRQ strip docked INTO the bezel instead of floating over the
  3D scene. The 3D canvas stays clean; UI lives on the hardware.
- Desktop: bezel + controller render as a "handheld in your hands" layout —
  game screen centered, controls flanking (Switch-in-hands look). Keyboard/gamepad
  users can hide the touch controls; the bezel stays.

---

## PART 2 · THE CONTROLLER (one overlay, every mode)

### 2.1 Physical layout (the "native controller")
A fixed layout language — per-mode configs relabel/hide, never rearrange:

```
 L2 ▔▔                                    ▔▔ R2        ← analog triggers (hold depth)
 L1 ▁▁                                    ▁▁ R1        ← bumpers
 ┌─────────┐                          ┌─────────┐
 │  LEFT   │      [ GAME SCREEN ]     │  RIGHT  │
 │  STICK  │       (touch-active)     │  STICK  │
 └─────────┘                          └─────────┘
   D-PAD                                A B X Y        ← face cluster (labeled per mode)
      SELECT ▪                      ▪ START/HOME
```

- **Left stick:** movement/steer (drag-anywhere within left zone; recenters on lift).
- **D-pad:** discrete alternative to stick (style select, menu focus, lane switch).
- **Right stick:** camera nudge / aim / trick-flick (flick gestures = tricks).
- **A B X Y:** primary/secondary/tertiary actions, ALWAYS labeled with the mode's verb
  ("SLAM", "JUKE L", "BLOCK") — verbs, not letters, on the labels; letter as sub-glyph.
- **L1/R1, L2/R2:** modifiers and analog holds (charge jump, stiff-arm, boost).
  Triggers report analog 0–1 from touch hold-duration or Gamepad API axes.
- **SELECT:** camera mode · **START/HOME:** pause sheet.

### 2.2 Touch-first, DS-style hybrid
- The game screen itself is ALWAYS touch-active on top of controller input: tap a
  style card, swipe a trick arc, drag aim — modes may register screen gestures that
  coexist with the sticks (like DS touch + buttons).
- **Portrait phones:** DS layout — game screen top ~55%, controller pad bottom ~45%
  (opaque deck, big thumb zones). **Landscape phones/tablets:** Switch layout —
  translucent controls overlaid at the sides. Breakpoint-driven, automatic, with a
  user override in the pause sheet.
- Thumb zones ≥ 88 px; all controls in bottom-third reach on phones; left/right
  handedness flip option.

### 2.3 Input contract (one event bus for everything)
All sources — touch overlay, keyboard, Gamepad API — emit the SAME normalized events;
game logic never reads the DOM/keys directly:

```ts
type FelInput =
  | { t: 'stick';   side: 'L'|'R'; x: number; y: number }        // -1..1, deadzone 0.15
  | { t: 'dpad';    dir: 'up'|'down'|'left'|'right'; pressed: boolean }
  | { t: 'button';  btn: 'A'|'B'|'X'|'Y'|'L1'|'R1'|'SELECT'|'START'; pressed: boolean }
  | { t: 'trigger'; side: 'L'|'R'; value: number }               // analog 0..1
  | { t: 'screen';  kind: 'tap'|'swipe'|'drag'; x: number; y: number; dx?: number; dy?: number };
```

- Keyboard map (fixed): WASD→L-stick · arrows→d-pad · J/K/L/I or Z/X/C/V→A/B/X/Y ·
  Q/E→L1/R1 · Shift/Space as per-mode trigger aliases · C→SELECT · Esc→START.
- **Gamepad API:** poll on rAF; standard mapping; hot-plug toast ("Controller
  connected"); overlay auto-hides when a pad is active (bezel stays).
- **Haptics:** `navigator.vibrate` patterns on button-down (10 ms), heavy hit (30 ms),
  perfect timing (10-30-10); Gamepad haptic actuators when available.
- Latency budget: input event → game state ≤ 1 frame; → visible animation ≤ 100 ms.

### 2.4 Per-mode mapping table (initial)
| Mode | L-stick | A | B | X | Y | L2/R2 | Screen touch |
|---|---|---|---|---|---|---|---|
| Dunk Contest | drive | SLAM (timed) | style next | signature | — | R2 hold = charge jump | tap style card; swipe up = rise |
| Karate (both) | move | STRIKE | KICK | BLOCK | CHI SPECIAL | — | tap enemy = target |
| Street Football | steer | HURDLE | SPIN | JUKE L | JUKE R | R2 = stiff-arm | swipe L/R = juke |
| Skate / Snowboard / Surf | carve | POP/JUMP | GRAB 1 | GRAB 2 | GRIND | R2 = crouch/pump | R-stick flick = trick |
| Tennis / Tiebreak | position | SWING | LOB | DROP | — | R2 = power hold | tap placement |
| Penalty Shootout | aim | SHOOT | — | — | — | R2 = curve | drag = aim, flick = shoot |
| Home Run Derby | timing (d-pad zone) | SWING | bunt | — | — | — | tap = swing |
| Beach Sprint | — | L/R alternate = A/B rhythm | — | — | — | — | alternating taps |
| Brain Brawl / Who Scene It | d-pad focus | SELECT answer | back | — | — | — | tap answers (primary) |

### 2.5 Component requirements
- ONE shared component (`ConsoleShell` + `ControllerOverlay`), config-driven
  (`modes/{id}.controls.json` conforming to `06-DATA-CONTRACTS.md` §4). No mode forks it.
- Skinnable: bezel/buttons tint from venue palette; cosmetics can later re-skin the
  controller (shop item: controller shells — economy tie-in).
- Debug flag renders a live input-event inspector for QA.

---

## PART 3 · ACCEPTANCE
- Home passes the console glance test (01 §Experience bar); rail navigable entirely by
  d-pad/stick focus + A, and by touch.
- Launch ritual (insert → boot → READY → 3-2-1) and eject ritual run in every mode,
  including guest `/try`.
- Every mode playable end-to-end: thumbs-only (portrait AND landscape), keyboard-only,
  and with a physical gamepad — identical verbs, zero per-mode relearning.
- Overlay never occludes critical action: safe-frame rules from m13-03 respected.
- All m13-02 acceptance items pass via this shell (it supersedes that doc's overlay).
