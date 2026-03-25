# Final Evolution Lab – Key Flows

Short reference for **sequencing and where 3D vs UI** lives. See also `XCODE_CLEAN_AND_RUN.md` and `INSPIRATIONS_COMPARISON.md`.

---

## 1. Lab → Dunk (3D)

- **Entry:** Lab tab → scroll to court → tap **START APPROACH** (guard: `phase == .idle`).
- **Cover:** `fullScreenCover(isPresented: $showDunkFullScreen)` → **DunkFlowView**.
- **DunkFlowView:**  
  - First: **GetReadyScreen** (“Dunk Contest”, countdown 3–2–1–GO).  
  - `onComplete` → `showGetReady = false` (animated) → **DunkFullScreenView**.
- **DunkFullScreenView:**  
  - **RealityKitDunkView** (procedural 3D: court, backdrop, hoop, net, dunker, camera, lights).  
  - **PS2GamepadOverlay** for stick + face buttons (console/emulator style).  
  - Phases: idle → approach (hold left stick up = sprint) → launch (press ✕ = commit, no timing bar) → airborne (△□○✕ = finishers) → landing (press ✕ = commit) → scored.  
  - On scored: **ResultScreen** overlay (judge total, CONTINUE?) → `onClaimRewards` or dismiss.
- **On dismiss:** `onDismiss` cancels timer and calls `freestyleDunk.advanceRound()` so next run starts from idle.

**3D:** Only the dunk uses 3D; all assets are procedural in `RealityKitDunkView` (no external models).

---

## 2. Arena (UI only)

- **Entry:** Arena tab → tap a **mode row** → `selectedMode = mode` → `fullScreenCover(item: $selectedMode)` presents **ArenaGameFlowView**.
- **ArenaGameFlowView:**  
  - **Get Ready** → **Playing** (`GenericArenaPlayView`) → **Result** (`ResultScreen`).  
  - Phase transitions use `.animation(.easeInOut(duration: 0.32), value: phase)` and opacity/scale transitions.
- **GenericArenaPlayView:**  
  - No 3D; **mode-specific backdrop** (**Venice Beach** `VeniceBeachHoopsArenaBackground` + `VeniceCourtCanvasView` for H2H/3v3, **dojo** Karate, **stadium** baseball, **gridiron** football, **beach tennis** `BeachTennisCourtBackground`, **beach volleyball** `BeachVolleyballArenaBackground` + `BeachVolleyballRallyCanvasView`, **gymnastics** `AcademyArenaGymnasticsBackground` + `GymnasticsFloorRoutineCanvasView`, **soccer** `PenaltyStadiumArenaBackground` + solo `PenaltyKickView` or MP `PenaltySpotCanvasView`, **golf** `GolfLinksArenaBackground` + solo `GolfSwingView` or MP `ClosestToPinCanvasView`, **Brain Brawl** `BrainBrawlAcademyBackground` + `BrainBrawlDuelCanvasView` in solo `BrainBrawlPlayView` or local Versus `GenericArenaPlayView` (OPP label), **Dunk** `DunkContestVenueBackground` + `DunkRunwayCanvasView` in `ArenaDunkPlayView`, etc.) + round label, P1/P2 score, **PS2GamepadOverlay** (console/emulator style).  
  - **Controller-first:** Press ✕ (Cross) or tap action button to commit the round — no timing bar. Outcome from PRQ + commit (quality 0.62–0.90). Physical controller Cross (button A) also commits.  
  - Commit → PERFECT/GOOD/MISS feedback → round result alert → Next → next round or **finishGame()** → `onGameEnd` → phase = .result.
- **Result:** ResultScreen (P1/P2, shards, PRQ) → “BACK TO ARENA” → `onDismiss` → `selectedMode = nil` (cover dismisses).

**3D:** Arena play is UI-only (gradient + meter). Lab dunk is the only 3D gameplay scene.

---

## 3. Get Ready screen

- Used by **Arena** (per-mode title/subtitle) and **Dunk** (fixed “Dunk Contest”).
- Countdown: 3 → 2 → 1 → GO! (snappy timing), then `onComplete()` after ~380ms.
- Triggers phase change (Arena: .playing; Dunk: show game view) with animation.

---

## 4. File reference

| Flow / 3D          | Main files |
|--------------------|------------|
| Lab court + dunk   | `LabView.swift`, `DunkContestEngine.swift` |
| Dunk 3D scene      | `RealityKitDunkView.swift` (court, backdrop, hoop, dunker, camera, lights) |
| Arena list + game  | `ArenaView.swift` (ArenaGameFlowView, GenericArenaPlayView) |
| Get Ready / Result | `GameScreensView.swift` |
| Modes / venues     | `GameMode.swift` (GameModeRegistry, arenaVenues) |
