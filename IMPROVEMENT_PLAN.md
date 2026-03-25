# Improvement Plan: Compete with Inspirators

This document tracks the five improvement areas and the **"again"** workflow. When you prompt **"again"**, the agent will assess current state and continue building until game modes meet a satisfactory quality bar.

---

## 1. Exercise 3D Models (Movement Demos)

**Goal:** Every exercise shows a 3D model performing the movement—no "VIDEO UNAVAILABLE" as the primary experience.

**Current state:**
- `RealityKitExerciseAvatarView` exists and shows a procedural humanoid with category-based motion (jump, squat, sway).
- `ExerciseDemoView` uses the 3D avatar when coach video is unavailable but still shows "VIDEO UNAVAILABLE" in coach mode.
- `TrainingExerciseDetailView` uses `ExerciseCharacterView` (stick figure) when video is unavailable.

**Planned work:**
- [x] Use 3D avatar in `TrainingExerciseDetailView` when video is unavailable (replace stick figure + "VIDEO UNAVAILABLE").
- [x] Default to **avatar mode** in exercise demos (DemoEngine already sets `.avatar` when loading/failed; 3D is primary, video optional).
- [x] Expand `RealityKitExerciseAvatarView` with more exercise-specific motion profiles: jump (plyometric), squat (strength), stretch (mobility), shuffle (agility), breathe (recovery); body lean/tilt for stretch and agility.
- [ ] Optional: per-exercise motion presets in data (e.g. `motionPreset: "squat"`) for better fidelity.

---

## 2. System Scan & Avatar Creation

**Goal:** System scan is the place to customize appearance and clothing; full avatar creation flow.

**Current state:**
- `SystemScanView` runs a scan and produces `SystemScanResult` with `AvatarSkinConfig` (heightScale, weightScale, limbLength, skinTone, outfitStyle, aura, trail).
- Avatar preview is a simple `figure.stand` icon scaled by config, not a 3D rig.
- `UserProfile.effectiveAvatarConfig` comes from `systemScan?.avatarConfig ?? placeholder`.
- No dedicated "customize appearance" or "customize clothing" UI after scan.

**Planned work:**
- [x] Add **post-scan customization screen**: adjust skin tone, body proportions, outfit style (`AvatarCustomizeView`; "Customize appearance & outfit" on results; Save updates result and persists when user taps "ENTER THE LAB").
- [x] Add **clothing / outfit picker**: outfit styles (standard, developing, flight, elite) in `AvatarCustomizeView`; skin tone and aura sliders.
- [ ] Integrate `AvatarRigBuilder` / unified RealityKit rig so the same avatar appears in scan preview, arena, and lab.
- [ ] Optional: photo-based scan input for face/body reference (if in scope).
- [x] Persist customizations to `UserProfile` / `AvatarSkinConfig` and surface them in key views (Lab scan section, exercise demos via category, Dashboard athlete hub header).

---

## 3. Games Must Be Playable (Console-Quality Gameplay)

**Goal:** Gameplay runs at a quality comparable to console; you called out Unreal Engine specifically.

**Current state:**
- Arena modes use SwiftUI + custom canvas views (e.g. `VeniceCourtCanvasView`, `ArenaDunkPlayView`, `PenaltyKickView`, `GolfSwingView`, `KarateCanvasView`) and PRQ-driven outcomes.
- No Unreal Engine integration; no native console target yet.

**Options (to be executed in phases):**
- **Phase A – Swift/RealityKit polish (short term):** Maximize quality within the current stack: richer 2D/3D arenas, better camera, more responsive controls, clearer feedback. No engine swap.
- **Phase B – Unreal integration (medium/long term):** Embed Unreal (e.g. via Unity-style bridge or native UE plugin) for selected modes so gameplay runs in Unreal while the shell stays Swift/SwiftUI. This is a large architectural effort (binary size, build pipeline, platform support).
- **Phase C – Full Unreal client (long term):** Separate Unreal project for console/PC that shares design and backend; iOS app remains Swift for mobile, or becomes a companion.

**Planned work (Phase A first):**
- [ ] Per-mode playability pass: ensure each mode has clear input (controller + touch), visible feedback, and satisfying loop.
- [ ] Improve camera framing and scene composition for each venue.
- [x] Add more dynamic visuals: perfect-commit radial burst + ready-to-commit pulsing ring in Arena (`GenericArenaPlayView`).
- [ ] Document Phase B/C steps (integration points, build and packaging) when moving toward Unreal.

---

## 4. Console and Mobile Versions

**Goal:** Dedicated builds and UX for both console and mobile.

**Current state:**
- Single iOS app with virtual DualShock-style overlay (`PS2GamepadOverlay`) when no physical controller is connected.
- Controller discovery and mapping target PS5-style (Cross, sticks, triggers).

**Planned work:**
- [x] **Mobile:** Treat as first-class: clear "tap or controller" affordances — Get Ready shows "Tap or controller • both work in game"; Arena play shows "Tap the button below or use ✕ on the overlay" when no physical controller; action button has contentShape + accessibility hint for tap/virtual Cross; overlay already mobile-optimized (52pt face, 48pt d-pad).
- [ ] **Console (e.g. tvOS / future console SDK):** Add tvOS target (or equivalent), controller-only navigation, safe areas and typography for 10-foot UI. Reuse same game logic and PRQ; swap or enhance views for big screen.
- [ ] **Shared:** One codebase where possible; `#if os(tvOS)` or platform checks for UX differences. Document build and packaging for "console" and "mobile" in Xcode.

---

## 5. Remove All Inspirator / Tool References

**Goal:** No user-facing copy mentions other products (e.g. NBA Live 07, Big Brain Academy, Coursebox, Wii Sports, NFL Street, FIFA Street).

**Planned work:**
- [x] Replace `inspirationTag` (and any displayed equivalent) with neutral style tags (e.g. "Arcade", "Dunk contest", "Curriculum quiz").
- [x] Update game mode subtitles and hints (e.g. Brain Brawl: "Curriculum Quiz vs AI"; Dunk: remove "NBA Live 07–style").
- [x] Remove or replace inspirator references in Arena Get Ready screen, mode cards, and Emulator dashboard.
- [x] Clean comments in code that mention inspirators only where they affect user-visible strings; internal docs can stay in MODE_INSPIRATIONS_AND_PLAN.md.

---

## "Again" Workflow

When you say **"again"**:

1. **Assess:** Re-read this plan and the codebase; list what’s done vs pending for each of 1–5 and for game-mode-specific passes.
2. **Prioritize:** Pick the next highest-impact, uncompleted item(s)—e.g. next game mode polish, 3D avatar expansion, system scan customization, or Unreal/console steps.
3. **Execute:** Implement that slice (code, config, or docs) and update this plan (checkboxes, new bullets).
4. **Repeat:** Continue until you say stop or until all game modes and improvement areas reach the agreed quality bar.

---

## Game Mode Quality Bar (Target)

For "satisfactory quality quota of being objectively better":

- **Copy:** No inspirator references; clear, original descriptions and hints.
- **Input:** Controller (PS5-style) and touch both work; overlays match the mode.
- **Visuals:** Each mode has a distinct, readable scene (2D or 3D) and clear feedback.
- **Loop:** One round is understandable, completable, and rewarding; PRQ and mode-specific logic feel fair.
- **Training:** Exercises show 3D movement demo by default; system scan leads to a customizable avatar used across the app.

---

*Last updated: Phase 2 — Athlete hub card on Dashboard and avatar customization surfaced across core flows.*
