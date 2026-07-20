# M31 — FACE SCAN FIX · ONE CHARACTER PIPELINE · ZERO BLACK SCREENS

Copy this document into Abacus with every file in `files/`. Three deliverables:

---

## PROMPT FOR ABACUS

### 1 · FACE SCAN (fixed + completed)
The scan today measures the body (M17 proportions) but the FACE is a default —
the avatar doesn't look like the player. This batch adds the missing half:
- `FaceScanCapture.tsx` — selfie capture (camera or photo upload) with
  MediaPipe **FaceLandmarker** running CLIENT-side (same privacy model as the
  body scan: only derived numbers leave the device, never the image, unless the
  user opts in).
- `faceFromLandmarks.ts` — 478 landmarks → the M20 `FaceConfig`: face
  width/jaw/cheeks, eye shape/size/spacing, brow thickness/angle, nose
  width/length/bridge, mouth width/lip fullness, plus skin-tone sampling from
  the cheek region. Output lands in the Closet PRE-FILLED — the player fixes
  anything the scan got wrong with the existing sliders (scan proposes, player
  disposes).
Flow to wire: Scan tab → "SCAN MY FACE" → capture → auto-FaceConfig → Closet
opens with it applied → SAVE persists via the existing `/api/closet/look`.

### 2 · ONE CHARACTER PIPELINE (create/change once, applies EVERYWHERE)
Today look-application is per-surface and drifts. `characterPipeline.ts` makes
identity a single pipe:
```
scan proportions (M17) + face config (face scan / Closet edits, M20)
+ wardrobe/card skin (M20)  →  PlayerIdentity  →  applyIdentity(spawn)
```
- `resolveIdentity()` fetches + merges + caches the user's identity once per
  session (bust on Closet save).
- `CharacterPipeline.spawnPlayer(scene, url, opts)` = CharacterLibrary.spawn +
  applyIdentity — **the ONLY way modes may spawn the player-controlled
  character.** Replace direct `CharacterLibrary.spawn` calls for the player in
  every ModeDefinition (grep: any spawn without tint that represents the user).
- Same spawn path feeds workout mini-movies (M17), Closet preview (M20), and
  hub avatar — change your face once, it changes in ALL of them.
- NPCs/mobs keep `spawnNpc()` (tint/scale variety, never the player identity).

### 3 · ZERO BLACK SCREENS / NO BROKEN BUILDS (hard guarantees)
- `RenderWatchdog.ts` — after a mode reaches ready, samples the framebuffer;
  if frames render effectively black it (1) re-runs `liftBlackMaterials`,
  (2) boosts ambient, (3) if STILL black after 2s → fires the harness error
  phase with "display problem — tap to retry" instead of leaving a black
  screen. Every mode mounts it (one line in ModeHarness — wiring below).
- `GlobalErrorBoundary.tsx` — wraps all /play and hub routes: any component
  crash renders the branded recovery screen (retry + back to hub), never a
  white/black page.
- `smokeTest.ts` — the "no broken builds" gate: headless boot of EVERY mode
  route asserting (a) reaches 'ready' ≤ 20s, (b) zero `[FEL-ANIM] MISSING
  CLIP`, (c) watchdog reports non-black frames, (d) no uncaught errors.
  **Run it in CI/pre-deploy; a failing mode blocks the deploy.** This encodes
  the M15 lesson permanently: build-passing ≠ renders-correctly, so we assert
  rendering.

## WIRING
1. ModeHarness (M29/M30 version): after `setPhase('ready')`, add
   `new RenderWatchdog(scene, engine, (msg) => setPhase('error', msg)).arm()`.
2. Routes: wrap in `<GlobalErrorBoundary>`; keep BootSplash as its recovery UI.
3. Modes: player spawns via `CharacterPipeline.spawnPlayer`; mobs via
   `spawnNpc`.
4. Scan tab: add the face-scan step after the movement scan (both feed the
   same reveal-through-Closet flow, M22 §4).
5. CI: `node smokeTest.js` against the preview deploy before promote.

## ACCEPTANCE
1. Face scan: selfie → Closet opens pre-filled (skin tone + face sliders
   visibly moved from defaults toward the photo); save; the SAME face renders
   in: hub avatar, dunk mode player, karate player, a workout mini-movie.
   Network log proves no image upload in the default path.
2. Change hair + skin tone in Closet → both change in all four surfaces above
   without any per-mode code edits.
3. Kill-switch test: force a bad venue material → watchdog rescues or shows
   the retry screen within 3s. Force a component throw → branded recovery
   screen, not a blank page.
4. Smoke test run attached to the report: all modes green; then intentionally
   break one clip name and show the smoke test FAILING (proving the gate bites).
