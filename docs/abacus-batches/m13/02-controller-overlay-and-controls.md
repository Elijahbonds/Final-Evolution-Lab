# M13-02 · P0 — Uniform Controller Overlay + Control Normalization

## Observed (live playtest)
- A gamepad FAB (bottom-right) exists in **Karate Endless** and **Skate Run**, but is
  absent in **Dunk Contest** (both guest `/try` and account version) and **Street Football**.
- The guest dunk — the first thing every new player touches — shows
  "WASD — drive the lane · HOLD SPACE — charge your jump" and
  "CONTROLS — DUNK CONTEST: W/A/S/D — Move, SPACE — Charge/Jump, E — Signature Dunk"
  **on a phone-sized viewport where no keyboard exists.** A mobile visitor from the
  landing page ("No account. No download. PLAY NOW") hits an unplayable screen.
- Football's control set (←/→ steer · Q/E juke · S spin · F stiff-arm · SPACE hurdle) is
  only shown in a one-line caption below the canvas, and the mode starts instantly —
  I was tackled before reading it.
- Camera and movement fight each other on desktop: there is no way to nudge the camera,
  and modes switch between FOLLOW and BROADCAST on their own mid-play.

## Required fix

### 1. One `ControllerOverlay` component, mounted in EVERY mode
- Same visual language everywhere: left virtual stick (or D-pad) for movement/steer,
  right-side action cluster of 2–4 labeled buttons, top-right camera toggle.
- Per-mode button config is data, not code:
  - **Dunk:** stick = drive · A = charge/jump (hold) · B = style cycle · X = signature (E).
  - **Karate:** stick = move · A = strike · B = kick · X = block · Y = chi special.
  - **Football:** stick = steer · A = hurdle · B = spin · X = juke L · Y = juke R
    (or swipe gestures on the stick side) · shoulder = stiff-arm.
  - **Skate/Surf/Snowboard:** stick = carve · A = pop/jump · B/X = grabs · Y = grind.
  - **Tennis/Derby/Penalty:** single big timing button + aim stick.
- **Auto-show on touch devices, toggleable via the FAB on desktop.** The FAB must exist
  in every mode, same position, same icon (it already looks right in Karate/Skate).
- Buttons emit the SAME input events as the keyboard so game logic doesn't fork.

### 2. Desktop key-hint bar
- The same config renders the bottom hint caption, so hints can never drift from the
  real bindings. Show it during READY phase, fade it after first successful input,
  re-show on 5 s of idle.

### 3. Ready gate on every mode
- No mode may take live input before an explicit start: "READY → tap/press to begin →
  3-2-1 → GO". Football currently starts the run the instant the scene loads —
  that plus unreadable controls guarantees a first-run tackle.

### 4. Camera control affordance
- Dedicated camera toggle button (overlay + C key) cycling FOLLOW → BROADCAST.
  The game must NOT auto-switch cameras mid-attempt (observed in Dunk: FOLLOW during
  approach flipped to BROADCAST in the air).

## Acceptance
- Every playable mode shows the overlay on a touch viewport with correctly labeled
  buttons and a working stick, and every overlay button drives the same logic as its key.
- Guest `/try` dunk is fully playable with thumbs only, portrait and landscape.
- No mode accepts gameplay input before its ready gate.
- Camera never changes mode without the player pressing the camera toggle.
