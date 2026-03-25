# Emulator Architecture & Migration (Native Swift)

This document describes the pivot from project-internal naming to a **high-performance game emulator shell** using **native Swift 6** and **GCController**-first input. There is no custom scripting language or DSL in the codebase; an earlier pass replaced **legacy third-party overlay type names** with neutral **PRQ** types.

---

## 1. Legacy PRQ naming migration (completed)

- **PRQScoreManager** — notifications are `PRQScoreUpdated` / `PRQScoreDidUpdate`; UserDefaults key is `app_prq_score` (a one-time migration reads any score stored under an obsolete legacy key on first launch).
- **PRQNativeBridge** — Unity/ObjC bridges should post `PRQScoreUpdated`; `PRQNativeBridge.postScore(_:)` and `postMetrics(_:)` remain the native API.
- **PRQOverlayView** / **PRQScoreOverlayView** — global PRQ HUD and score overlay.
- **ContentView**, app entry, **NativeBridgeManager**, **TrainingViewModel** now reference only the PRQ types above.
- All game and UI logic is **standard Swift**; no proprietary runtime or scripting.

---

## 2. Controller & input layer (PS5 Remote Play feel)

- **GCController (GameController)** is used for DualShock, DualSense, Xbox, and MFi controllers. No web layer; direct system API.
- **ControllerDiscoveryService** (`ControllerDiscoveryService.shared`):
  - Observes `.GCControllerDidConnect` / `.GCControllerDidDisconnect`.
  - Exposes `hasPhysicalController` and `controllerName`.
  - Started in `FinalEvolutionLabApp.init()`.
- **Virtual on-screen controller**: **PS2GamepadOverlay** (PS-style layout, D-pad, sticks, face buttons △□○✕). When `ControllerDiscoveryService.shared.hasPhysicalController` is true, the overlay is **hidden** and a small “Controller connected” pill is shown (Arena and Lab/Dunk).
- **Physical controller**: **ControllerSupport.swift** provides `onPhysicalControllerCross(perform:)` (tap) and `onPhysicalControllerCross(down:up:)` (charge-and-release). Arena and Dunk use these for commit/charge.
- **Input path**: Touch → SwiftUI gestures; physical → `GCController` → same handlers. No artificial delay; design is 0ms-style handoff.

---

## 3. Emulator architecture (packaged as game ROMs)

- **Game Library** tab (**EmulatorDashboardView**): central “insert game” screen. Each card is a module:
  - **Arena** — venues and head-to-head modes.
  - **Lab** — court and dunk contest.
  - **Brain Brawl** — Big Brain × Coursebox (Arena → Academy Arena).
  - **Training** — blueprints and workouts.
  - **Academy** — Vertical Velocity Academy (10 modules), opens sheet.
  - **Status** — dashboard and metrics.
  - **Vault** — profile, shards, trade.
- Tabs (Games, Lab, Arena, Train, Status, Vault) remain; **Games** is the default and acts as the emulator dashboard. Each module is a distinct “ROM” entry point.
- **Arena** uses the highest-fidelity UI (gradients, charge bar, PRQ-based scoring). **Lab** uses RealityKit for the dunk court; both support controller or virtual overlay.

---

## 4. Vertical Velocity Academy & Brain Brawl

- **VerticalVelocityAcademyCurriculum** (10 modules):
  1. Bio-Electric Freeway (CNS, Tensegrity, Roadblock Theory)
  2. Internal GPS (SFMA/FMS)
  3. The Piston (IAP, diaphragm/pelvic floor)
  4. The 24/7 Athlete (Movement Snacks)
  5. Anatomy of the Sling (Spiral, Front, Back lines)
  6. Clearing the Path (NMS correctives)
  7. The Loaded Spring (PJF Band, TBB)
  8. The Rhythmic Penultimate (RFD, Push 1-2)
  9. The Elastic Engine (tiered plyometrics — extensive to deep)
  10. The Flight Blueprint (programming, TBB, approach variations)
- Corrective pairings (e.g. Rotation Fail → Isometric Wall Push) are stored on modules; tools are No Equipment / PJF Band / TBB.
- **VerticalVelocityAcademyView** lists all modules with objectives and correctives; opened from the Games dashboard **Academy** card.
- **Brain Brawl** is an Arena mode (Academy Arena); question bank is curriculum-track–based (general, foundations, flight, elite). Big Brain × Coursebox content lives in **BrainBrawlQuestion** and **BrainBrawlQuestionBank**.

---

## 5. Integrations (economy, education, fitness)

- **Economy**: Shards, Vault, Trade, SaveSystem; linked from dashboard and in-game.
- **Education**: Academy (10 modules) and Training (blueprints, exercises) are linked from the Game Library; Academy sheet and Training tab.
- **Fitness**: HealthKitService, PRQ, neural drive, HRV; Status/Dashboard and metrics. Training sessions and correctives tie into the same curriculum.

---

## 6. Technical stack (no “Base 44” dependency)

- **Swift 6**, **SwiftUI**, **GameController (GCController)**. No custom language or “Base 44” framework is referenced; the app is standard Apple frameworks.
- **Metal** is available for future high-tier rendering (e.g. custom Arena effects); current UI is SwiftUI + RealityKit in Lab.
- **Single .ipa**: one app; internally it behaves as an extensible “console” with multiple game modules and a central Game Library.

---

## 7. File and symbol reference

| Legacy (removed) | Current |
|------------------|---------|
| Legacy score manager type | `PRQScoreManager` |
| Legacy native bridge type | `PRQNativeBridge` |
| Legacy global overlay view | `PRQOverlayView` |
| Legacy score overlay view | `PRQScoreOverlayView` |
| Legacy notification symbol names | `prqScoreUpdatedNotification`, `prqScoreDidUpdateNotification` |
| Legacy notification string (if any) | `"PRQScoreUpdated"` |
| UserDefaults key | `app_prq_score` |

New files added:

- `Source/Services/PRQScoreManager.swift`
- `Source/Services/PRQNativeBridge.swift`
- `Source/Services/ControllerDiscoveryService.swift`
- `Source/Views/PRQOverlayView.swift`
- `Source/Views/PRQScoreOverlayView.swift`
- `Source/Views/EmulatorDashboardView.swift`
- `Source/Views/VerticalVelocityAcademyView.swift`
- `Source/Models/VerticalVelocityAcademy.swift`

Old files removed:

- Prior legacy score/overlay Swift files (superseded by the `PRQ*` types above).

If you have an existing Unity or ObjC bridge that posts a **legacy** score notification name, update it to post `PRQScoreUpdated` with the same `userInfo["score"]` so **PRQScoreManager** continues to receive updates.
