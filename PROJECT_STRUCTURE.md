# Final Evolution Lab — Project Structure Report

**Generated**: 2026-04-02  
**Purpose**: Locate UE5 project files and determine build readiness for Phase 2 (iOS build)

---

## ✅ UE5 Projects Found

### Two UE5 projects exist in this repository:

### 1. Main Game Project (Full Feature Set)
- **Path**: `UnrealStarter/BasketballGame/FinalEvolutionLab.uproject`
- **Engine**: UE **5.7** ⚠️ (user has 5.4 installed)
- **Source Files**: ~180+ C++ files in `Source/FinalEvolutionLab/`
- **Content**: Full content tree with 12 venue maps, configs, animations, Meshy assets, UI
- **Plugins**: Niagara, PixelStreaming, MotionWarping, LiveLink, AppleARKit, AppleARKitFaceSupport
- **EditorPython**: 15+ import/verification scripts
- **Config**: DefaultEngine.ini, DefaultGame.ini, DefaultInput.ini, IOS/IOSEngine.ini
- **Status**: This is the **canonical production project** with all game logic

### 2. iOS Bridge Project (Lightweight iOS Scaffold)
- **Path**: `ios/FinalEvolutionLab_Unreal/FinalEvolutionLab.uproject`
- **Engine**: UE **5.4** ✅ (matches user's installation)
- **Source Files**: ~11 C++ files with Public/Private layout
- **Content**: ❌ **No Content directory** (no maps, no assets, no configs)
- **Plugins**: EnhancedInput, CommonUI only
- **Config**: Minimal (only engine redirect)
- **Status**: Lightweight scaffold with iOS native bridge stubs (Objective-C++ `.mm` file)

### 3. Template Project (Bare Bones)
- **Path**: `ios/UnrealProjectTemplate/` (no .uproject file)
- **Source Files**: ~6 C++ files — subset of the iOS bridge project
- **Status**: Template/reference only, not buildable

---

## Directory Overview

| Directory | Purpose | Status |
|-----------|---------|--------|
| `UnrealStarter/BasketballGame/` | Main UE5 game (5.7) | ✅ Full project, wrong engine version |
| `ios/FinalEvolutionLab_Unreal/` | iOS UE5 scaffold (5.4) | ⚠️ Missing Content, minimal code |
| `ios/FinalEvolutionLab/` | Swift iOS app (native) | ✅ Complete Swift app |
| `ios/FinalEvolutionLab.xcodeproj/` | Xcode project for Swift app | ✅ Exists |
| `streaming/` | Pixel Streaming signalling + frontend | ✅ Complete |
| `GeneratedAssets/` | AI-generated assets (animations, environments) | ✅ Pipeline reports exist |
| `scripts/ai_asset_pipeline/` | AI asset generation pipeline | ✅ Complete |
| `scripts/ue5_setup/` | UE5 setup/build scripts | ✅ Complete |
| `Unity/` and `UnityProject/` | Legacy Unity projects | 🔵 Legacy/unused |
| `web/` | Web frontend | ✅ Complete |

---

## What's in the Main Project (UnrealStarter/BasketballGame/)

### Source Code (180+ files)
- Game modes: Basketball, Soccer, Tennis, Volleyball, Football, Golf, Baseball, Karate, Gymnastics, Surfing, Skateboarding, Snowboarding
- Subsystems: Arena, Academy, AI Asset Manager, Pixel Streaming Bridge, Biomechanics, NeuroMechanic, Exercise Catalog, Cloud Sync, Save Game
- Characters, HUD, Input, Camera, Physics (Dunk Ballistics, Kick Return Sim)
- LiveLink face tracking, DeepMotion session, Avatar system
- Creator economy: Cards, Gallery, Challenges, Shop
- Clinical UI, Subscription, Onboarding, Progression

### Content
- 12 Venue maps (.umap): VeniceBeach, SoccerStadium, TennisCourt, Dojo, Gridiron, BaseballPark, Links, SandCourt, TrainingFloor, NeuroArena, Luma_Venice_Shop
- Meshy 3D assets (GLB): Tennis Ball, Soccer Ball, Tennis Racket, Stadium, Goal Posts
- Exercise Catalog JSON, Arena Settings, Brain Brawl Curriculum
- Face rig configs, Creator profiles, Workout catalogues

### Config
- `DefaultEngine.ini`: Full game config with iOS settings (BundleID: `com.finalevolution.FinalEvoAPP`, TeamID: `78L8GWA44F`)
- `DefaultGame.ini`: Map cooking list
- `Config/IOS/IOSEngine.ini`: iOS-specific settings
- `Config/IOS/DefaultScalability.ini`: iOS performance

---

## ⚠️ Key Issue: Engine Version Mismatch

| Project | Engine | User Has | Compatible? |
|---------|--------|----------|-------------|
| `UnrealStarter/BasketballGame/` | **5.7** | 5.4 | ❌ No |
| `ios/FinalEvolutionLab_Unreal/` | **5.4** | 5.4 | ✅ Yes |

---

## 🎯 Recommended Path for Phase 2 (iOS Build)

### Option A: Use the iOS Project with Main Project's Code (RECOMMENDED)
1. **Change engine version** in `UnrealStarter/BasketballGame/FinalEvolutionLab.uproject` from `5.7` → `5.4`
2. Copy the main project to the user's Mac
3. Open in UE5 5.4 (it will prompt to convert — accept)
4. Build for iOS from the full project

### Option B: Merge Main Code into iOS Project
1. Copy Source code from `UnrealStarter/BasketballGame/Source/` into `ios/FinalEvolutionLab_Unreal/Source/`
2. Copy Content from `UnrealStarter/BasketballGame/Content/` into `ios/FinalEvolutionLab_Unreal/Content/`
3. Copy Config from `UnrealStarter/BasketballGame/Config/` into `ios/FinalEvolutionLab_Unreal/Config/`
4. Update .uproject plugins list
5. Build for iOS

### Option C: Downgrade .uproject Only (SIMPLEST)
1. Simply change `"EngineAssociation": "5.7"` → `"EngineAssociation": "5.4"` in the main .uproject
2. The C++ code should be compatible (most UE5 APIs are stable between 5.4-5.7)
3. Some features/plugins may need minor adjustments

---

## Files the User Needs on Their Mac

For the iOS build, the user needs to transfer:
```
UnrealStarter/BasketballGame/          # The full UE5 project
├── FinalEvolutionLab.uproject         # (with engine version fixed to 5.4)
├── Source/                            # All C++ code
├── Content/                           # All assets, maps, configs
├── Config/                            # Engine/game configuration
└── EditorPython/                      # Asset import scripts

ios/FinalEvolutionLab/                 # Swift iOS app
ios/FinalEvolutionLab.xcodeproj/       # Xcode project
certs/                                 # Signing certificates (.pem files)
```

---

## What's NOT in the Repo (Would Need Creating)
- **Intermediate/**: Auto-generated by UE5 on first build (expected to be missing)
- **Binaries/**: Auto-generated by UE5 on first compile (expected to be missing)  
- **Saved/**: Auto-generated by UE5 Editor (expected to be missing)
- **DerivedDataCache/**: Auto-generated (expected to be missing)
- **.sln / .xcworkspace for UE5**: Generated by UE5's "Generate Project Files"
