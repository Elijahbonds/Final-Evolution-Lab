# 01 — PRODUCT VISION (Rescope · July 2026)

## One sentence
Final Evolution is a **digital coaching & fitness platform wrapped in a personal game
console**: your athlete avatar carries real training identity (PRQ) into a library of
sports game modes that look like a console and play like a handheld.

## The rescope, verbatim intent
- **Platform:** Web app, hosted by Abacus (custom URL later). No download. Instant play.
- **Category:** Digital Coaching / Fitness app + Avatar Multi-Game-Mode Library.
- **Feel:** "It should feel like an emulator." The app presents itself as a CONSOLE:
  - **Visual layout of a console** — a home screen like a Switch/PS home: game-card
    library rail, avatar/profile presence, currencies, season pass — then launching a
    mode feels like inserting a cartridge.
  - **Its own native controller** — a persistent on-screen controller with
    **dual joysticks, dual triggers (L1/L2 · R1/R2), a d-pad, and face buttons**,
    the same layout language in EVERY mode.
  - **Plus touch** — direct touch on the game screen itself, "like a DS": tap targets,
    swipes, and drags coexist with the controller (Switch/Steam-Deck/Portal hybrid).
- **Every game mode uses this shell.** No mode invents its own control scheme UI again.

## The three pillars

### 1 · The Console (shell)
The app IS the hardware. Home screen = console dashboard: library rail of mode
"cartridges" (22 live modes), athlete avatar, PRQ/LC/XP/streak, Season Pass, Signature
Challenge, Triumph Arena, venues (Luma Venice Shop, Muscle Beach Gym), Coach and Story
tabs. Launch/exit transitions sell the emulator fantasy (cartridge in → mode boot
splash → READY gate; exit → back to home rail). Full spec: `03-CONSOLE-SHELL-SPEC.md`.

### 2 · The Athlete (coaching & fitness identity)
- **PRQ** (Performance Readiness Quotient) is the spine: every session feeds it; the
  Coach tab reads it; game performance and training compound into one number.
- The avatar is persistent across all modes — cosmetics, movement signature, aura.
- Coaching layer (Coach tab): training plans, streaks, Muscle Beach Gym mini-modes
  (Iron Paradise, Beach Sprint) as "fitness cartridges" — same shell, same controller.
- Long-term: real-world training input (IRL modes, motion capture) raises PRQ; the
  game library is the reward loop that makes training sticky.

### 3 · The Library (game modes)
22+ live modes across venues (Venice Beach Court, Shimogamo Dojo, Venice Skatepark,
Surf Break, Mountain Slope, Venice Tennis Court, Coastal FC Stadium, Catalina Ballpark,
The Gridiron, NeuroArena, The Nexus…). Each mode is a small, sharp arcade experience
(60-second-to-fun), scored into the one economy (XP, shards, LC, PRQ Δ, season XP).
Mode catalog source of truth: `backend/FEL_ModeManager.production.json` +
`FEL_VenueRegistry.production.json`.

## Experience bar ("what good feels like")
- Home screen passes the **console glance test**: a stranger seeing it says "that's a
  game console," not "that's a website."
- A phone user plays ANY mode end-to-end **with thumbs only**, controller overlay
  always in the same places; a desktop user can use keyboard or a physical gamepad
  (Gamepad API) with identical bindings.
- Input → visible animation ≤ 100 ms, everywhere (M13 P0).
- Every session, win or lose, lands on the same satisfying result screen
  (XP/shards/LC/PRQ Δ/season XP) — this already exists and is good; protect it.

## Non-goals (current phase)
- No native app-store build as primary target (iOS repo is reference only).
- No pay-to-win; Pro Lane of the season pass stays cosmetic.
- No real-IP media in Who Scene It.
- No new game engines: the web build's existing stack (React/Next + WebGL 3D) is the
  engine; agents improve it rather than proposing replatforms.

## North-star sequence for the shell fantasy
1. Land → console home boots (quick, animated, sound optional).
2. Pick DUNK CONTEST cartridge → boot splash with venue art → READY gate.
3. Controller overlay is already in your thumbs; 3-2-1; play a great 45 seconds.
4. Result screen pays XP into the season pass; PRQ ticks up in the top bar.
5. Back to the rail — next cartridge is glowing. That loop is the product.
