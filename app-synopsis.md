# Final Evolution Lab: Technical & Functional Synopsis

## 1. Abstract & Vision

Final Evolution Lab is a high-performance athletic optimization ecosystem that bridges elite biomechanical coaching with immersive digital simulation. It utilizes a **"Digital Twin"** architecture to translate forensic video data into a dynamic 3D avatar.

- **Core Metric:** PRQ (Performance Readiness Quotient).
- **Philosophy:** "Delete the Fear" — removing neural friction and biomechanical leaks.
- **Primary Stack:** Swift/SwiftUI (Social/UI Layer) + Unreal Engine (3D Simulation/Physics) + Firebase (Persistence/Cloud Sync).

---

## 2. The Digital Twin Pipeline (Data Flow)

The application follows a strict data-ingestion pipeline to maintain the "Digital Twin":

1. **Capture:** Raw video upload of athletic movements.
2. **Calibrate():** Computer vision extracts kinematics (Vertical Jump, Neural Drive, Pop Force, Efficiency).
3. **Audit():** Comparison against "Pro Signatures" to identify dysfunction.
4. **Sync():** Biomechanical data is injected into the Unreal Engine Character Blueprint to modify physics constraints (e.g., max impulse, jump height, recovery frames).

---

## 3. Core Functional Modules

### A. The Digital Vault (The Curriculum)

- **Bonds Bounce Blueprint:** Multi-phase training (Foundations → Load → Launch → Flight).
- **Forensic Insights:** Deep-dive technical breakdowns and "Mental Priming" scripts.
- **Academy Progression:** Mentor selection, node-based unlocks, and mastery interactions.

### B. The Gaming Labs (Unreal Engine 5)

- **Environments:** High-fidelity stylized recreations (e.g., Venice Beach Court).
- **Game Modes:** 1v1/2v2 Basketball, Dunk Contests, 3-Point Shootouts, and Sport-specific drills (QB/Soccer).
- **Readiness-Influenced Sim:** Avatar performance is dynamically gated by the user's real-world "Neural Readiness" scores.
- **Repo alignment:** **`UnrealStarter/VISION_ALIGNMENT.md`** ties Unreal work to the same **measure → train → play** story, **Arena** naming, and Swift schemas (`PerformanceMetrics`, `GameSessionResult`, `GameModeId`, `PRQScoring`) for the MyProjec / **`BasketballGame/`** lab slice — plus what is still to wire for full product parity.

### C. Recovery & Coaching Portal

- **Neural Decompression:** Guided 3D visualizations for posterior chain release.
- **Command Center:** Orchestrates critique request/review loops with "Verified Coaches."
- **Scout Bounties:** A marketplace where pro-team opportunities are unlocked via verified PRQ milestones.

---

## 4. Economic Architecture (Web3-Enabled)

A dual-currency system manages the "Play-to-Earn" loop:

- **Evolution Shards (ES):** Soft currency. Earned via training streaks. Used for gear, skins, and maintenance drains (inflation control).
- **Blueprint Credits (BC):** Hard currency. Purchased for elite coaching, "Forensic Feedback," and unlocking advanced curriculum phases.
- **Creator Cards:** Collectible assets that provide attribute boosts within the Labs.

---

## 5. Technical Specifications for Cursor

- **Frontend Architecture:** SwiftUI-heavy navigation with a persistent AppState coordinator.
- **3D Integration:** Unreal Engine integrated as a library or sub-view, communicating with the Swift layer via a bridge (data snapshots).
- **Physics Engine:** Unreal Engine Physics (high-fidelity collision and ball mechanics).
- **State Management:**
  - **Local:** Swift Persistence / UserDefaults for offline readiness.
  - **Cloud:** Firebase Firestore for global leaderboards (Venice Kings), matchmaking, and Digital Twin backups.
- **Async Patterns:** Stale-task protection for media observers, navigation-safe timers, and lifecycle-aware feedback banners.

---

## 6. Data Schema (Cursor-Ready Reference)

Key persisted types and their roles. All are Codable/Sendable where applicable.

| Type | Location | Purpose |
|------|----------|---------|
| **UserProfile** | `Models/UserProfile.swift` | Single source of truth: `metrics` (PRQ, verticalPotential, neuralDrive, popForce, etc.), `systemScan`, `evolutionShards`, `activeCreatorCard`, `sport`, `goal`, `critiqueRequests`. |
| **SystemScanResult** | `Models/UserProfile.swift` | Output of Calibrate pipeline: `prqScore`, `verticalEstimateInches`, `flightTimeSeconds`, `movementGrade`, `notes`, `recommendedTrack`, `avatarConfig` (AvatarSkinConfig). |
| **AvatarSkinConfig** | `Models/UserProfile.swift` | Injected into sim: `heightScale`, `weightScale`, `limbLength`, `skinTone`, `outfitStyle`, `auraColorR/G/B`, `trailIntensity`. |
| **PerformanceMetrics** | `Models/PerformanceMetrics.swift` | PRQ and related scores used for physics/readiness. |
| **BiomechanicsAudit** | `Models/BiomechanicsAudit.swift` | Output of Audit(): joint/zone status (e.g. ankleDorsiflexion, kneeTracking, hipExtension), leakage zones. Built from `SystemScanResult` via `BiomechanicsAudit.fromScanResult(_)`. |
| **GameSessionResult** | `Models/GameSession.swift` | Per-session record: `gameModeId`, `score`, `opponentScore`, `shardsEarned`, `prqBonus`, `roundsPlayed`, `duration`, `isMultiplayer`. Persisted via `SaveSystem.saveGameResult(_)`. |
| **GameMode / GameModeId** | `Models/GameMode.swift` | Registry of all modes (basketball H2H, dunk, 3v3, karate, baseball, football, soccer, golf, tennis, volleyball, gymnastics, brainBrawl). Used for scene selection, physics config, and PRQ weighting. |
| **TrainingProgram / TrainingDay / TrainingExercise** | `Models/TrainingProgram.swift`, `TrainingProgramData.swift` | Curriculum structure: tracks, days, warm-up/main work exercises, progression levels, equipment. |
| **Exercise** | `Models/Exercise.swift` | Lab exercise catalog: `id`, `category`, `difficulty`, `muscleGroups`, `sets`, `reps`, `restSeconds`, `demoDescription`. |
| **CreatorCard / CardPacksAndAuction** | `Models/CreatorCard.swift`, `CardPacksAndAuction.swift` | Collectibles and attribute boosts; economy hooks. |
| **SaveSystem** | (Services or Utilities) | Saves/loads `UserProfile`, `GameSessionResult`, and related state to local storage. |

**Firestore / Cloud:** Leaderboard entries, matchmaking state, and (when implemented) Digital Twin backups keyed by user ID; sync with local `UserProfile` and session results.

---

## 7. Unreal Engine Integration Points (Cursor-Ready Reference)

How the Swift/SwiftUI app hands off to (or receives data from) Unreal Engine.

| Concern | Swift Side | Unreal Side (Target) |
|---------|------------|----------------------|
| **Avatar calibration** | `SystemScanResult` + `AvatarSkinConfig`; `BiomechanicsAudit` (joint/zone status). | Character Blueprint: apply scale, limb ratios, and physics constraints (max impulse, jump height, recovery) from PRQ/audit. |
| **Readiness gating** | `PerformanceMetrics` (PRQ, neuralDrive, popForce, etc.); `ArcadePhysics.fromPRQ(_:neuralDrive:audit:)`; `GamePhysicsConfig.forMode(_:prq:audit:)`. | Sim reads a **data snapshot** (e.g. JSON or struct mirror) from the bridge; clamps or scales movement/ball physics by PRQ and audit flags. |
| **Session context** | `GameModeId`, `GameSessionResult`, optional `roundsPlayed`. | Level/mode selection; post-game stats and economy (shards, PRQ delta) can be reported back to Swift. |
| **Bridge contract** | Send: current `UserProfile` (or subset: metrics, avatarConfig, audit), selected `GameModeId`, session start. Receive: session end payload (score, opponentScore, duration). | Consume snapshot on level load; push session result back over the bridge for persistence and leaderboards. |
| **Scene / level mapping** | Lab court: `RealityKitDunkView` (RealityKit); migration path: replace or supplement with Unreal view per game mode. | One Unreal level (or sublevel) per game mode; Venice Beach, Dojo, Stadium, etc. |

**Note:** The current iOS app uses **RealityKit** for the Lab dunk court (`RealityKitDunkView`, `DunkFullScreenView`). The synopsis and this section describe the **target** architecture once Unreal Engine is integrated; the bridge and data snapshots should mirror the schema above so an LLM can map Swift types to Unreal parameters.

---

## 8. Key Logic Methods

| Method | Purpose |
|--------|---------|
| **Calibrate()** | Processes video into raw biomechanical metrics. (In-app: System Scan flow → `SystemScanResult`; full CV pipeline TBD.) |
| **Audit()** | Maps user metrics against elite benchmarks. (`BiomechanicsAudit.fromScanResult(_)`; leakage zones and joint status.) |
| **Simulate()** | Updates Unreal Avatar attributes based on latest PRQ. (Swift: `GamePhysicsConfig` / `ArcadePhysics`; Unreal: consume snapshot and drive Blueprint.) |
| **Program()** | Generates daily workout prescriptions based on PRQ gaps. (Training program/track selection, `TrainingDay`, recommended track from scan.) |
| **Verify()** | Signs off on metrics for pro-scouting eligibility. (Scout Bounties / critique flow; not yet fully implemented.) |

---

*Next step: Generate Swift boilerplate for the AppState coordinator or the PRQ data model from this synopsis, or extend the bridge contract for Unreal.*
