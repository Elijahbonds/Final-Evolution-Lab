# Native App Architecture — Final Evolution Lab

> How the hybrid Swift UI + UE5 native app works end-to-end.  
> No cloud streaming. No monthly server costs. Pure on-device performance.

---

## Table of Contents

1. [High-Level Architecture](#1-high-level-architecture)
2. [App Structure & Navigation](#2-app-structure--navigation)
3. [Swift UI Layer — What's Implemented](#3-swift-ui-layer--whats-implemented)
4. [UE5 Game Engine Layer](#4-ue5-game-engine-layer)
5. [Swift ↔ UE5 Bridge](#5-swift--ue5-bridge)
6. [Game Mode Launch Flow](#6-game-mode-launch-flow)
7. [Data Flow & State Management](#7-data-flow--state-management)
8. [Subscription & Monetization](#8-subscription--monetization)
9. [Body Scanning & Health Integration](#9-body-scanning--health-integration)
10. [Offline Functionality](#10-offline-functionality)
11. [What Needs to Be Added](#11-what-needs-to-be-added)
12. [Integration Plan](#12-integration-plan)

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Final Evolution Lab App                       │
│                    (Single Native Binary)                        │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Swift UI Host Layer                       │ │
│  │                                                            │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │ │
│  │  │   Lab    │ │  Train   │ │  Arena   │ │   Command    │ │ │
│  │  │   Tab    │ │   Tab    │ │   Tab    │ │   Center     │ │ │
│  │  └──────────┘ └──────────┘ └────┬─────┘ └──────────────┘ │ │
│  │                                  │                         │ │
│  │  ┌──────────┐ ┌──────────┐     │    ┌─────────────────┐  │ │
│  │  │ Profile  │ │  Health  │     │    │   Onboarding    │  │ │
│  │  │ & Vault  │ │ Kit Svc  │     │    │    & Settings   │  │ │
│  │  └──────────┘ └──────────┘     │    └─────────────────┘  │ │
│  │                                │                          │ │
│  │  ┌─────────────────────────────▼──────────────────────┐   │ │
│  │  │              Native Bridge Manager                  │   │ │
│  │  │        (Swift ↔ UE5 C++ via @_cdecl)               │   │ │
│  │  └─────────────────────────────┬──────────────────────┘   │ │
│  └────────────────────────────────│───────────────────────────┘ │
│                                   │                             │
│  ┌────────────────────────────────▼───────────────────────────┐ │
│  │                UE5 Game Engine Layer                        │ │
│  │              (Metal rendering, embedded)                    │ │
│  │                                                            │ │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────────────────┐ │ │
│  │  │  17 Game   │ │ 23 Exercise│ │  12 Venue Environments │ │ │
│  │  │   Modes    │ │ Animations │ │  (AI-Generated 3D)     │ │ │
│  │  └────────────┘ └────────────┘ └────────────────────────┘ │ │
│  │                                                            │ │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────────────────┐ │ │
│  │  │  Physics   │ │  AI Asset  │ │   Animation System     │ │ │
│  │  │  Engine    │ │  Manager   │ │   (54 custom + UE5)    │ │ │
│  │  └────────────┘ └────────────┘ └────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │ CoreMotion/ARKit │  │    HealthKit     │  │   Metal 3    │  │
│  │  (body tracking) │  │ (HR, HRV, steps) │  │  (GPU render)│  │
│  └──────────────────┘  └──────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Why Hybrid Native?

| Aspect | Cloud Streaming | **Native Hybrid (Our Approach)** |
|--------|----------------|----------------------------------|
| Monthly cost | $200–800/mo GPU servers | **$0** |
| Latency | 30–100ms network + encode | **< 1ms** (on-device) |
| Offline play | ❌ | **✅** |
| Device sensors | Limited passthrough | **Full access** (camera, motion, health) |
| Quality | Compressed video stream | **Native Metal rendering** |
| Budget fit | ❌ Exceeds $400 in 1–2 months | **✅ One-time build cost** |

---

## 2. App Structure & Navigation

### Tab Bar (5 Tabs)

```swift
// ContentView.swift — Root navigation
TabView(selection: $selectedTab) {
    Tab("Lab",     systemImage: "brain.head.profile.fill",              value: .lab)
    Tab("Train",   systemImage: "figure.highintensity.intervaltraining", value: .training)
    Tab("Arena",   systemImage: "trophy.fill",                          value: .social)
    Tab("Command", systemImage: "square.grid.2x2.fill",                 value: .dashboard)
    Tab("Profile", systemImage: "person.crop.circle.fill",              value: .vault)
}
```

### Navigation Flow

```
App Launch
  ↓
Onboarding (first launch only)
  → Sport selection, age, goal
  ↓
ContentView (TabView)
  ├── Lab Tab → LabView
  │     ├── Neural Drive Orb (readiness)
  │     ├── Academy Progress
  │     └── Blueprints Library
  │
  ├── Train Tab → TrainingHubView
  │     ├── Workout Day schedule
  │     ├── Exercise catalog (23 exercises)
  │     └── Exercise Demo (3D animation)
  │
  ├── Arena Tab → GameModeSelectionView
  │     ├── Sport categories grid
  │     ├── Neural Readiness Scan
  │     ├── Matchmaking
  │     └── GamePlayView → UE5 Game Container
  │           ├── SceneKit fallback (no UE5)
  │           └── UE5GameContainerView (with UE5)
  │
  ├── Command Tab → CommandCenterView
  │     ├── Performance dashboard
  │     ├── Leaderboards
  │     └── Analytics
  │
  └── Profile Tab → VaultView
        ├── User profile
        ├── Creator cards
        ├── Shard economy
        └── Settings
```

---

## 3. Swift UI Layer — What's Implemented

### ✅ Fully Implemented (50+ Views)

| Category | Views | Status |
|----------|-------|--------|
| **Navigation** | `ContentView`, `OnboardingView`, `SettingsSheet` | ✅ Complete |
| **Lab** | `LabView`, `NeuralDriveOrb`, `BlueprintsView` | ✅ Complete |
| **Training** | `TrainingHubView`, `WorkoutDayView`, `ExerciseDemoView`, `CoachView` | ✅ Complete |
| **Arena** | `GameModeSelectionView`, `GamePlayView`, `MatchmakingView` | ✅ Complete |
| **Streaming** | `StreamingArenaView` (WebRTC client) | ✅ Complete |
| **Command** | `CommandCenterView`, `DashboardView` | ✅ Complete |
| **Profile** | `VaultView`, `SocialView`, `ShareToFeedView` | ✅ Complete |
| **Economy** | `ShardShopView`, `CreatorCardBoostView`, `CreatorMarketplaceHubView` | ✅ Complete |
| **Overlays** | `PS2ControllerShellView`, `PS2GamepadOverlay`, `RorkOverlayView` | ✅ Complete |
| **Body Scan** | `SystemScanView`, `NeuralScanOverlay`, `BiomechanicsOverlayView` | ✅ Complete |
| **Events** | `LiveEventsHubView`, `CritiqueRequestView`, `CritiqueSubmitView` | ✅ Complete |

### ✅ Models (40+ Data Models)

| Model | Purpose |
|-------|---------|
| `GameMode` | 12 game mode IDs with input schemes, physics DNA |
| `Exercise` | 23 exercise definitions |
| `UserProfile` | Player profile, stats, progression |
| `TrainingProgram` | Workout programming |
| `ShardEconomy` | Dual currency (shards + credits) |
| `CreatorCard` | Collectible athlete cards |
| `Matchmaking` | Online matchmaking state |
| `DunkContestEngine` | Dunk contest scoring physics |
| `MatrixPhysicsEngine` | Advanced game physics |
| `MovementScreening` | Body movement analysis |

### ✅ Services (15+ Services)

| Service | Purpose |
|---------|---------|
| `PixelStreamingService` | WebSocket + WebRTC signalling |
| `HealthKitService` | Heart rate, HRV, steps, calories |
| `CoreMotionHelper` | Accelerometer, gyroscope |
| `NativeBridgeManager` | Swift ↔ UE5 communication |
| `RorkScoreManager` | Score synchronization |
| `MultipeerService` | Local multiplayer |
| `SaveSystem` | Local data persistence |
| `FirebasePersistenceService` | Cloud sync (optional) |
| `GlobalLeaderboardService` | Online leaderboards |
| `NarrationSpeechService` | Voice narration |
| `SystemScanAnalysisEngine` | Body analysis AI |
| `DemoEngine` | Exercise demo playback |

---

## 4. UE5 Game Engine Layer

### What UE5 Provides

| Component | Details |
|-----------|---------|
| **3D Rendering** | Metal-based, 60 FPS on M4 Pro |
| **17 Game Modes** | Basketball (3), Karate (2), Baseball, Football, Soccer, Golf, Tennis, Volleyball, Gymnastics |
| **23 Exercise Animations** | DeepMotion motion-captured, mapped to exercises |
| **12 Venue Environments** | AI-generated 3D (Luma + Meshy) |
| **54 Custom Animations** | Elijah Bonds basketball videos |
| **Physics Engine** | Per-sport physics simulation |
| **AI Opponents** | UE5 AI controllers |

### UE5 Project Structure

```
ios/FinalEvolutionLab_Unreal/
├── FinalEvolutionLab.uproject
├── Config/
│   ├── DefaultGame.ini
│   ├── DefaultEngine.ini
│   └── DefaultInput.ini
└── Source/FinalEvolutionLab/
    ├── Public/
    │   ├── FE_LabManager.h          ← Master game manager
    │   ├── FE_GameInstance.h         ← Game instance (mode switching)
    │   ├── FinalEvolutionTypes.h     ← Shared type definitions
    │   ├── RorkPlayerCharacter.h     ← Player controller
    │   ├── ArenaActor.h              ← Arena scene actor
    │   ├── PlayerScoreManager.h      ← Score tracking
    │   ├── RorkNativeBridgeComponent.h  ← Swift bridge
    │   ├── RorkBridgeRoutingLibrary.h   ← Bridge routing
    │   ├── MotionDataReceiverComponent.h ← Body motion data
    │   ├── FE_CoachingPortalWidget.h    ← In-game coaching UI
    │   └── FE_SaveGame.h               ← Save/load state
    └── Private/
        ├── ... .cpp implementations
        └── IOS/
            └── RorkNativeBridgeIOSStub.mm  ← Obj-C++ bridge stub
```

---

## 5. Swift ↔ UE5 Bridge

### Bridge Architecture

```
┌─────────────────┐              ┌──────────────────┐
│   Swift Layer    │              │   UE5 C++ Layer  │
│                  │              │                  │
│  NativeBridge    │───@_cdecl──→│  RorkNativeBridge │
│  Manager.swift   │   C funcs   │  Component.h/cpp │
│                  │              │                  │
│  RorkScore       │←─callback──│  PlayerScore      │
│  Manager.swift   │   funcs     │  Manager.h/cpp   │
│                  │              │                  │
│  PixelStreaming  │──WebSocket─→│  (or embedded    │
│  Service.swift   │             │   Metal view)    │
└─────────────────┘              └──────────────────┘
```

### Bridge Communication Methods

#### Method 1: @_cdecl C Function Exports (Primary)

```swift
// Swift exports C functions that UE5 can call
@_cdecl("_PostRorkScore")
func postRorkScore(_ score: Int32) { ... }

@_cdecl("_LaunchGameMode")
func launchGameMode(_ modeId: UnsafePointer<CChar>) { ... }

@_cdecl("_SendMotionData")
func sendMotionData(_ jsonData: UnsafePointer<CChar>) { ... }
```

```cpp
// UE5 calls Swift via extern "C"
extern "C" void _PostRorkScore(int32 score);
extern "C" void _LaunchGameMode(const char* modeId);
```

#### Method 2: NotificationCenter (Swift → Swift)

```swift
// Score updates flow through NotificationCenter
NotificationCenter.default.post(
    name: rorkScoreUpdatedNotification,
    object: nil,
    userInfo: ["score": newScore]
)
```

#### Method 3: Embedded Metal View (Rendering)

```swift
// UE5 provides a Metal CAMetalLayer that's hosted in a UIView
class UE5GameViewController: UIViewController {
    func initializeUE5Engine() {
        let metalView = UE5Bridge.shared.createGameView()
        view.addSubview(metalView)
    }
}
```

---

## 6. Game Mode Launch Flow

### Complete Flow: User Taps Game Mode → UE5 Renders

```
1. User taps "Basketball H2H" in GameModeSelectionView
   │
2. GameModeSelectionView presents options:
   ├── "Quick Start" → skip scan, readiness = 50%
   ├── "Neural Scan First" → NeuralReadinessScanView
   │     └── Uses CoreMotion + HealthKit to assess readiness
   └── "Find Opponent" → MatchmakingView
         └── Uses MultipeerService for local discovery
   │
3. Navigate to GamePlayView(gameMode: .basketballHeadToHead)
   │
4. GamePlayView checks UE5 availability:
   ├── UE5 Framework loaded?
   │   ├── YES → Present UE5GameContainerView
   │   │         └── UE5Bridge.launchMode("basketball_h2h")
   │   │         └── Metal view renders 3D game
   │   └── NO  → Fall back to SceneKit renderer
   │             └── CourtSceneView (built-in 2D/3D)
   │
5. During gameplay:
   │  Swift ←──scores──── UE5 (_PostRorkScore)
   │  Swift ──motion────→ UE5 (_SendMotionData)
   │  Swift ←──events──── UE5 (game state changes)
   │
6. Game ends:
   └── UE5 signals completion
       └── GamePlayView shows results overlay
           ├── Score, combo, stats
           ├── XP + shard rewards
           └── Save to profile
```

### Game Mode ID Mapping

| Swift `GameModeId` | UE5 Arena Key | Sport |
|---------------------|---------------|-------|
| `.basketballHeadToHead` | `basketball_h2h` | 🏀 Basketball |
| `.basketballDunkContest` | `basketball_dunk` | 🏀 Basketball |
| `.basketball3v3` | `basketball_3v3` | 🏀 Basketball |
| `.karate1v1` | `karate_h2h` | 🥋 Karate |
| `.karateEndless` | `karate_endless` | 🥋 Karate |
| `.baseball` | `baseball` | ⚾ Baseball |
| `.football` | `football` | 🏈 Football |
| `.soccer` | `soccer` | ⚽ Soccer |
| `.golf` | `golf` | ⛳ Golf |
| `.tennis` | `tennis` | 🎾 Tennis |
| `.volleyball` | `volleyball` | 🏐 Volleyball |
| `.gymnastics` | `gymnastics` | 🤸 Gymnastics |

*Note: 17 total game modes in the full system (12 coded IDs + 5 sub-modes/variants).*

---

## 7. Data Flow & State Management

### State Architecture

```
┌──────────────────────────────────────────┐
│            LabViewModel (@Observable)     │
│  ┌─────────────────────────────────────┐ │
│  │ profile: UserProfile                │ │
│  │ exercises: [Exercise]               │ │
│  │ gameModes: [GameMode]               │ │
│  │ trainingPrograms: [TrainingProgram] │ │
│  │ shards / credits                    │ │
│  └─────────────────────────────────────┘ │
│                    │                     │
│         ┌──────────┼──────────┐          │
│         ▼          ▼          ▼          │
│   SaveSystem   Firebase   HealthKit      │
│   (local)      (cloud)    (device)       │
└──────────────────────────────────────────┘
```

### Persistence Layers

| Layer | Purpose | Mechanism |
|-------|---------|-----------|
| **UserDefaults** | Simple preferences, feature flags | `@AppStorage` |
| **SaveSystem** | Full profile, progression, scores | JSON file encoding |
| **HealthKit** | Health data (HR, HRV, steps) | `HKHealthStore` |
| **Firebase** (optional) | Cloud sync, leaderboards | `FirebasePersistenceService` |
| **UE5 SaveGame** | In-game state, checkpoints | `FE_SaveGame` (UE5 side) |

### Data Flow Example: Score Update

```
UE5 Game → _PostRorkScore(85) → RorkScoreManager
  → NotificationCenter.post("rorkScoreUpdated", score: 85)
    → NativeBridgeManager.prqScore = 85
      → ContentView re-renders shards badge
    → LabViewModel.profile.metrics update
      → SaveSystem.saveProfile()
    → GlobalLeaderboardService.submit(score: 85)
```

---

## 8. Subscription & Monetization

### Implemented Economy

```swift
// Models/ShardEconomy.swift
struct ShardEconomy {
    var evolutionShards: Int     // Earned through gameplay
    var premiumCredits: Int      // Purchased via IAP
}

// Models/CreditEconomy.swift
// Dual currency: shards (free) + credits (paid)
```

### Revenue Streams (Designed)

| Feature | Currency | Status |
|---------|----------|--------|
| Game mode unlocks | Shards | ✅ Implemented |
| Creator card boosts | Credits | ✅ Implemented |
| Marketplace trades | Credits | ✅ Designed |
| Event tickets | Credits | ✅ Designed |
| Body scan premium | Subscription | 🔲 Needs StoreKit 2 |
| Ad-free experience | Subscription | 🔲 Needs StoreKit 2 |

### What Needs to Be Added for Subscriptions

```swift
// TODO: Add StoreKit 2 integration
// ios/FinalEvolutionLab/Services/SubscriptionService.swift
import StoreKit

@Observable
class SubscriptionService {
    var activeSubscription: Product.SubscriptionInfo?
    var availableProducts: [Product] = []
    
    func loadProducts() async {
        // Product IDs configured in App Store Connect
        let ids = ["com.finalevolutiongroup.lab.monthly",
                    "com.finalevolutiongroup.lab.annual"]
        availableProducts = try await Product.products(for: Set(ids))
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        // Handle transaction
    }
}
```

---

## 9. Body Scanning & Health Integration

### HealthKit Integration (✅ Implemented)

```swift
// Services/HealthKitService.swift
class HealthKitService {
    var heartRate: Double          // Real-time HR
    var hrvValue: Double           // Heart rate variability
    var activeCalories: Double     // Workout calories
    var stepCount: Double          // Daily steps
    var neuralReadinessScore: Double  // Computed readiness (0–100)
}
```

### CoreMotion (✅ Implemented)

```swift
// Services/CoreMotionHelper.swift
// Accelerometer + gyroscope for movement detection
// Used during Neural Readiness Scan and gameplay
```

### Body Scanning Architecture

```
Camera (ARKit) → Body Pose Detection
  → Joint positions (17 keypoints)
    → MovementScreening analysis
      → PRQ Score (Physical Readiness Quotient)
        → Training recommendations
        → Game difficulty adjustment
```

### Views Involved

| View | Purpose |
|------|---------|
| `SystemScanView` | Full body scan wizard |
| `NeuralReadinessScanView` | Pre-game readiness check |
| `NeuralScanOverlay` | AR overlay during scan |
| `BiomechanicsOverlayView` | Real-time joint visualization |
| `LiveBiomechanicsOverlay` | During gameplay |

---

## 10. Offline Functionality

### What Works Offline

| Feature | Offline Status | Storage |
|---------|---------------|---------|
| All menus & navigation | ✅ Full | App bundle |
| 17 game modes (SceneKit) | ✅ Full | App bundle |
| UE5 game modes | ✅ Full | Embedded framework |
| 23 exercise demos | ✅ Full | Bundled animations |
| Body scanning | ✅ Full | On-device ARKit |
| HealthKit data | ✅ Full | Device health store |
| Profile & progression | ✅ Full | Local SaveSystem |
| Training programs | ✅ Full | Bundled data |
| Leaderboards | ❌ Needs network | Firebase |
| Multiplayer | ⚡ Local only | MultipeerConnectivity |
| Cloud sync | ❌ Needs network | Firebase |

### Offline Data Sync Strategy

```swift
// When network returns:
// 1. Queue local changes
// 2. Batch upload scores & progress
// 3. Pull updated leaderboards
// 4. Resolve conflicts (last-write-wins)
```

---

## 11. What Needs to Be Added

### Priority 1: UE5 Integration (Required)

| Task | Effort | Files |
|------|--------|-------|
| Build UE5 for iOS framework | 2–4 hours | Build scripts |
| Create `UE5GameContainerView` | 1–2 hours | New Swift view |
| Wire game modes to UE5 | 2–3 hours | `GamePlayView`, bridge |
| Test all 17 modes launch | 2–3 hours | Testing |

### Priority 2: Subscription (Revenue)

| Task | Effort | Files |
|------|--------|-------|
| StoreKit 2 service | 3–4 hours | New `SubscriptionService.swift` |
| Paywall UI | 2–3 hours | New `PaywallView.swift` |
| App Store Connect products | 1 hour | ASC portal |
| Receipt validation | 2–3 hours | Server-side or on-device |

### Priority 3: Polish

| Task | Effort | Files |
|------|--------|-------|
| App icon & launch screen | 1–2 hours | Assets.xcassets |
| Push notifications | 2–3 hours | Using provided PEM |
| Crash reporting | 1 hour | Firebase Crashlytics |
| Analytics | 1–2 hours | Firebase Analytics |

---

## 12. Integration Plan

### Phase 1: Swift App Standalone (Week 1)

```
✅ Open project in Xcode
✅ Configure signing
✅ Build and run on device
✅ Test all Swift UI features
✅ Verify HealthKit & CoreMotion
```

### Phase 2: UE5 Build for iOS (Week 2)

```
□ Configure UE5 project for iOS (see IOS_NATIVE_BUILD_GUIDE.md § 4)
□ Import all 49 AI assets into UE5
□ Build UE5 as iOS framework
□ Test UE5 standalone on device
```

### Phase 3: Hybrid Integration (Week 3)

```
□ Add UE5 framework to Xcode project
□ Create UE5GameContainerView
□ Connect bridge functions
□ Wire game mode selection → UE5 launch
□ Test score propagation UE5 → Swift
□ Test all 17 game modes
```

### Phase 4: Monetization & Distribution (Week 4)

```
□ Add StoreKit 2 subscription
□ Configure App Store Connect
□ TestFlight beta build
□ Submit for App Store review
```

### Total Estimated Timeline: 4 Weeks

| Phase | Estimated Cost (from $400 budget) |
|-------|-----------------------------------|
| Apple Developer Program | $99/year |
| Assets already generated | $0 (done) |
| Build & test on Mac Mini | $0 (owned hardware) |
| **Remaining budget** | **$301** (for future iterations) |

---

## File Map Summary

```
rork-final-evolution-lab/
├── ios/
│   ├── FinalEvolutionLab.xcodeproj       ← Xcode project (open this)
│   ├── FinalEvolutionLab/                ← Swift app source
│   │   ├── FinalEvolutionLabApp.swift    ← @main entry
│   │   ├── ContentView.swift             ← Root TabView
│   │   ├── Config.swift                  ← URLs & flags
│   │   ├── Models/         (40+ files)   ← Data models
│   │   ├── Views/          (50+ files)   ← SwiftUI views
│   │   ├── ViewModels/     (2 files)     ← Observable state
│   │   ├── Services/       (15+ files)   ← Business logic
│   │   ├── Utilities/      (3 files)     ← Theme, scoring
│   │   ├── Meshy/                        ← Bundled 3D models
│   │   └── Assets.xcassets               ← App icon, colors
│   ├── FinalEvolutionLab_Unreal/         ← UE5 game project
│   │   ├── FinalEvolutionLab.uproject
│   │   ├── Config/
│   │   └── Source/FinalEvolutionLab/     ← C++ game code
│   ├── FinalEvolutionLabTests/           ← Unit tests
│   └── FinalEvolutionLabUITests/         ← UI tests
├── IOS_NATIVE_BUILD_GUIDE.md             ← How to build
├── XCODE_SETUP_GUIDE.md                  ← Xcode configuration
├── NATIVE_APP_ARCHITECTURE.md            ← This file
├── UnrealStarter/                        ← UE5 starter project
├── GeneratedAssets/                      ← AI-generated content
├── SourceVideos/                         ← Elijah Bonds videos
├── scripts/                              ← Build & asset pipelines
└── streaming/                            ← Web streaming (optional)
```

---

*Last updated: April 2, 2026 · Final Evolution Lab v1.0*
