# iOS / macOS Native Build Guide — Final Evolution Lab

> **Target hardware**: Mac Mini M4 Pro · macOS Sequoia 15+ · Xcode 16+  
> **Engine**: Unreal Engine 5.4  
> **Project path on Mac**: `~/Documents/rork-final-evolution-lab`  
> **Budget-friendly**: Zero monthly cloud costs — everything runs natively.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Apple Developer Account Setup](#2-apple-developer-account-setup)
3. [Certificate & Provisioning Profiles](#3-certificate--provisioning-profiles)
4. [UE5 Project Configuration for iOS](#4-ue5-project-configuration-for-ios)
5. [Building UE5 for iOS on Mac](#5-building-ue5-for-ios-on-mac)
6. [Packaging the UE5 Game as an iOS Framework](#6-packaging-the-ue5-game-as-an-ios-framework)
7. [Integrating UE5 into the Swift App](#7-integrating-ue5-into-the-swift-app)
8. [Opening & Building in Xcode](#8-opening--building-in-xcode)
9. [Testing on Devices](#9-testing-on-devices)
10. [M4 Pro Optimizations](#10-m4-pro-optimizations)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

### Required Software

| Software | Minimum Version | Install |
|----------|----------------|---------|
| **macOS** | Sequoia 15.0+ | Apple Silicon native |
| **Xcode** | 16.0+ | Mac App Store |
| **Xcode Command Line Tools** | Latest | `xcode-select --install` |
| **Unreal Engine** | 5.4.x | Epic Games Launcher or source build |
| **iOS SDK** | 17.0+ | Bundled with Xcode |
| **CocoaPods** (optional) | 1.15+ | `sudo gem install cocoapods` |
| **Git** | 2.40+ | Bundled with Xcode CLT |

### Hardware Requirements

| Component | Recommended (Mac Mini M4 Pro) |
|-----------|------------------------------|
| **Chip** | Apple M4 Pro (14-core GPU) |
| **RAM** | 24 GB+ (48 GB ideal for UE5) |
| **Storage** | 100 GB free (UE5 + project + build artifacts) |
| **Display** | External monitor for Xcode + UE5 side-by-side |

### Verify Your Environment

```bash
# Check Xcode version
xcodebuild -version

# Check available iOS SDKs
xcodebuild -showsdks | grep iphoneos

# Check UE5 installation
ls ~/Library/UnrealEngine/UE_5.4/

# Check Apple Silicon
uname -m  # Should output "arm64"

# Check available disk space
df -h /
```

---

## 2. Apple Developer Account Setup

### Option A: Free Apple ID (Development Only)

- Sign in to Xcode → Settings → Accounts → Add Apple ID
- Allows on-device testing on **your own devices**
- No App Store distribution, no TestFlight
- Provisioning profiles expire every 7 days

### Option B: Apple Developer Program ($99/year) — Recommended

1. Visit [developer.apple.com/programs](https://developer.apple.com/programs/)
2. Enroll as **Individual** or **Organization**
3. Wait for approval (usually 24–48 hours)
4. After enrollment:
   - Access to App Store Connect
   - TestFlight beta distribution
   - Provisioning profiles last 1 year
   - Push notification certificates

### Add Your Account to Xcode

```
Xcode → Settings (⌘,) → Accounts → "+" → Apple ID → Sign In
```

Xcode will automatically manage signing certificates for development.

---

## 3. Certificate & Provisioning Profiles

### Using the Provided .pem Files

The project includes two `.pem` certificate files:

| File | Purpose |
|------|---------|
| `FinalEvolutionLab.pem` | Development/Distribution certificate |
| `Final Evolution Lab.pem` | Push notification certificate |

#### Import Certificates

```bash
# Copy PEM files to the project's certs directory
mkdir -p ~/Documents/rork-final-evolution-lab/certs
cp ~/Downloads/FinalEvolutionLab.pem ~/Documents/rork-final-evolution-lab/certs/
cp ~/Downloads/"Final Evolution Lab.pem" ~/Documents/rork-final-evolution-lab/certs/

# Convert PEM to P12 if needed (for Keychain import)
openssl pkcs12 -export \
  -in FinalEvolutionLab.pem \
  -out FinalEvolutionLab.p12 \
  -password pass:felcert2024

# Import into Keychain
security import FinalEvolutionLab.p12 -k ~/Library/Keychains/login.keychain-db
```

### Automatic Signing (Recommended for Development)

In Xcode:
1. Select the **FinalEvolutionLab** target
2. Go to **Signing & Capabilities**
3. Check ✅ **Automatically manage signing**
4. Select your **Team** (your Apple Developer account)
5. Xcode auto-creates provisioning profiles

### Manual Signing (For Distribution)

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. **Certificates** → Create iOS Distribution Certificate
3. **Identifiers** → Register App ID: `com.finalevolutiongroup.lab`
4. **Profiles** → Create provisioning profile for the App ID
5. Download and double-click to install

### Required Capabilities

The app uses these entitlements (configure in Xcode → Signing & Capabilities):

| Capability | Purpose |
|-----------|---------|
| **HealthKit** | Heart rate, HRV, step tracking |
| **Camera** | Body scanning, AR features |
| **Motion & Fitness** | CoreMotion biomechanics |
| **Local Network** | Multiplayer (MultipeerConnectivity) |
| **Background Modes** | Audio, fetch, processing |

---

## 4. UE5 Project Configuration for iOS

### 4.1 Enable iOS Platform Support

Open the UE5 project and configure for iOS:

```
UE5 Editor → Edit → Project Settings
```

#### Platform → iOS

| Setting | Value |
|---------|-------|
| **Minimum iOS Version** | 16.0 |
| **Target iOS Version** | 17.0+ |
| **Supported Orientations** | Landscape Left, Landscape Right |
| **Enable Metal** | ✅ Yes |
| **Max Metal Shader Standard** | 3.1 |
| **Enable Remote Notifications** | ✅ Yes |
| **Bundle Identifier** | `com.finalevolutiongroup.lab.unreal` |

#### Rendering

| Setting | Value |
|---------|-------|
| **Default RHI** | Metal |
| **Mobile HDR** | ✅ Yes |
| **Mobile MSAA** | 4x |
| **Allow Static Lighting** | ✅ Yes |
| **Support Compute Shaders** | ✅ Yes |

#### Packaging

| Setting | Value |
|---------|-------|
| **Build Configuration** | Development (debug) / Shipping (release) |
| **Use Pak File** | ✅ Yes |
| **Compress Pak** | ✅ Yes |

### 4.2 Update .uproject for iOS

Edit `ios/FinalEvolutionLab_Unreal/FinalEvolutionLab.uproject`:

```json
{
  "FileVersion": 3,
  "EngineAssociation": "5.4",
  "Category": "Games",
  "Description": "Final Evolution Lab - Native iOS Game",
  "Modules": [
    {
      "Name": "FinalEvolutionLab",
      "Type": "Runtime",
      "LoadingPhase": "Default"
    }
  ],
  "Plugins": [
    { "Name": "EnhancedInput", "Enabled": true },
    { "Name": "CommonUI", "Enabled": true },
    { "Name": "AppleARKit", "Enabled": true },
    { "Name": "AppleARKitFaceSupport", "Enabled": true }
  ],
  "TargetPlatforms": [ "IOS", "Mac" ]
}
```

### 4.3 Create iOS Target File

Create `Source/FinalEvolutionLabIOS.Target.cs`:

```csharp
using UnrealBuildTool;

public class FinalEvolutionLabIOSTarget : TargetRules
{
    public FinalEvolutionLabIOSTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V4;
        IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_4;
        
        ExtraModuleNames.AddRange(new string[] { "FinalEvolutionLab" });
        
        // iOS-specific settings
        if (Target.Platform == UnrealTargetPlatform.IOS)
        {
            bCompileAgainstEngine = true;
            bCompilePhysX = true;
            bUsesSlate = true;
            bBuildDeveloperTools = false;
        }
    }
}
```

### 4.4 Config INI Files for iOS

Create `Config/IOS/IOSEngine.ini`:

```ini
[/Script/IOSRuntimeSettings.IOSRuntimeSettings]
bSupportsPortraitOrientation=False
bSupportsUpsideDownOrientation=False
bSupportsLandscapeLeftOrientation=True
bSupportsLandscapeRightOrientation=True
MinimumIOSVersion=IOS_16
bSupportsMetalMRT=True
MobileProvisionFile=
SigningCertificate=
bAutomaticSigning=True

[/Script/Engine.RendererSettings]
r.MobileHDR=True
r.Mobile.EnableStaticAndCSMShadowReceivers=True
r.GenerateMeshDistanceFields=True
```

---

## 5. Building UE5 for iOS on Mac

### 5.1 Generate Xcode Project Files

```bash
cd ~/Documents/rork-final-evolution-lab/ios/FinalEvolutionLab_Unreal

# Generate Xcode project from UE5
/Users/Shared/Epic\ Games/UE_5.4/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh \
  -project="$(pwd)/FinalEvolutionLab.uproject" \
  -game -engine -Xcode
```

This creates `FinalEvolutionLab.xcworkspace` in the UE5 project directory.

### 5.2 Build via UE5 Editor

1. Open the project in UE5 Editor
2. **Platforms** → **iOS** → **Cook Content**
3. Wait for shader compilation (first time: 30–60 min on M4 Pro)
4. **Platforms** → **iOS** → **Package Project**
5. Select output directory: `Builds/iOS/`

### 5.3 Build via Command Line (Automation Tool)

```bash
# Set UE5 paths
export UE_ROOT="/Users/Shared/Epic Games/UE_5.4"
export PROJECT="$HOME/Documents/rork-final-evolution-lab/ios/FinalEvolutionLab_Unreal/FinalEvolutionLab.uproject"

# Build for iOS (Development)
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" \
  BuildCookRun \
  -project="$PROJECT" \
  -platform=IOS \
  -clientconfig=Development \
  -cook -build -stage -pak -package \
  -distribution \
  -prereqs \
  -archive \
  -archivedirectory="$HOME/Documents/rork-final-evolution-lab/Builds/iOS"

# Build for iOS (Shipping / Release)
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" \
  BuildCookRun \
  -project="$PROJECT" \
  -platform=IOS \
  -clientconfig=Shipping \
  -cook -build -stage -pak -package \
  -distribution
```

### 5.4 Build as Embeddable Framework

To embed UE5 as a framework inside the Swift app:

```bash
# Build UE5 as a static library / framework for iOS
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" \
  BuildCookRun \
  -project="$PROJECT" \
  -platform=IOS \
  -clientconfig=Development \
  -cook -build -stage -pak \
  -GenerateFramework
```

The output framework will be at:
```
Builds/iOS/FinalEvolutionLab.framework
```

---

## 6. Packaging the UE5 Game as an iOS Framework

### Architecture: Hybrid Swift + UE5

```
┌─────────────────────────────────────────────────┐
│              FinalEvolutionLab.app               │
│  ┌───────────────────────────────────────────┐   │
│  │         Swift UI Layer (Host App)          │   │
│  │  ┌─────────┐ ┌──────────┐ ┌────────────┐ │   │
│  │  │ Menus   │ │BodyScan  │ │Subscription│ │   │
│  │  │ & Nav   │ │& Health  │ │ & Profile  │ │   │
│  │  └────┬────┘ └────┬─────┘ └─────┬──────┘ │   │
│  │       │           │             │         │   │
│  │  ┌────▼───────────▼─────────────▼──────┐  │   │
│  │  │     UE5GameContainerView (UIKit)     │  │   │
│  │  │  ┌──────────────────────────────┐    │  │   │
│  │  │  │   UE5 Game Engine (Metal)    │    │  │   │
│  │  │  │  17 Game Modes + 23 Exer.    │    │  │   │
│  │  │  └──────────────────────────────┘    │  │   │
│  │  └─────────────────────────────────────┘  │   │
│  └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Option A: UE5 as Embedded Framework

1. Build UE5 for iOS as framework (Section 5.4)
2. Drag `FinalEvolutionLab.framework` into Xcode project
3. Set **Embed & Sign** in Frameworks panel
4. Bridge via `UE5GameContainerView` (see Section 7)

### Option B: UE5 as Xcode Subproject

1. Generate Xcode project from UE5 (Section 5.1)
2. Drag `FinalEvolutionLab.xcodeproj` into the Swift workspace
3. Add UE5 target as dependency of the Swift target
4. Link the UE5 output library

### Option C: Standalone UE5 App + Swift Package (Simplest)

1. Build UE5 as standalone iOS app
2. Launch via URL schemes from Swift app
3. Most isolated; least integration depth

**Recommended**: Option A for the tightest integration.

---

## 7. Integrating UE5 into the Swift App

### 7.1 Create the UE5 Container View

Create `ios/FinalEvolutionLab/Views/UE5GameContainerView.swift`:

```swift
import SwiftUI
import UIKit

/// Wraps the UE5 game view (Metal rendering) inside SwiftUI
struct UE5GameContainerView: UIViewControllerRepresentable {
    let gameMode: GameModeId
    let onExit: () -> Void
    let onScoreUpdate: (Int) -> Void
    
    func makeUIViewController(context: Context) -> UE5GameViewController {
        let vc = UE5GameViewController()
        vc.gameMode = gameMode
        vc.onExit = onExit
        vc.onScoreUpdate = onScoreUpdate
        return vc
    }
    
    func updateUIViewController(_ vc: UE5GameViewController, context: Context) {
        // Update game mode if changed
    }
}

/// UIKit controller that hosts the UE5 Metal view
class UE5GameViewController: UIViewController {
    var gameMode: GameModeId = .basketballHeadToHead
    var onExit: (() -> Void)?
    var onScoreUpdate: ((Int) -> Void)?
    
    // Reference to UE5 game instance
    private var ue5View: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeUE5Engine()
    }
    
    private func initializeUE5Engine() {
        // Initialize UE5 embedded engine
        // This calls into the UE5 framework's entry point
        // FELGameInstance::StartMode(gameMode.rawValue)
        
        // The UE5 Metal view is added as a subview
        // ue5View = UE5Bridge.shared.createGameView()
        // view.addSubview(ue5View!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Notify UE5 to pause/cleanup
    }
}
```

### 7.2 Native Bridge (Swift ↔ UE5 C++)

The bridge is already partially implemented:

- **Swift side**: `Services/RorkNativeBridge.swift`, `Services/NativeBridgeManager.swift`
- **UE5 side**: `RorkNativeBridgeComponent.h/.cpp`, `RorkNativeBridgeIOSStub.mm`

Key bridge functions:

```swift
// Swift → UE5 (via @_cdecl exports)
@_cdecl("_LaunchGameMode")
func launchGameMode(_ modeId: UnsafePointer<CChar>) {
    let mode = String(cString: modeId)
    // Tell UE5 to load the specified game mode
}

@_cdecl("_PostRorkScore")
func postRorkScore(_ score: Int32) {
    // Receive score from UE5, update Swift UI
    Task { @MainActor in
        NativeBridgeManager.shared.simulateScore(Int(score))
    }
}

// UE5 → Swift (via C function pointers)
// Defined in RorkNativeBridgeComponent.cpp
```

### 7.3 Connecting Game Modes

Update `GameModeSelectionView.swift` to launch UE5:

```swift
// When user selects a game mode:
NavigationLink(destination: 
    UE5GameContainerView(
        gameMode: selectedMode.id,
        onExit: { /* return to menu */ },
        onScoreUpdate: { score in viewModel.updateScore(score) }
    )
    .ignoresSafeArea()
    .navigationBarHidden(true)
)
```

---

## 8. Opening & Building in Xcode

### Quick Start

```bash
# Open the Swift project in Xcode
open ~/Documents/rork-final-evolution-lab/ios/FinalEvolutionLab.xcodeproj

# Or if using workspace with UE5:
open ~/Documents/rork-final-evolution-lab/ios/FinalEvolutionLab.xcworkspace
```

### Build Steps

1. **Open** the `.xcodeproj` (or `.xcworkspace` if using CocoaPods/UE5 subproject)
2. **Select target**: `FinalEvolutionLab`
3. **Select destination**: Your iPhone or iOS Simulator
4. **Set team**: Your Apple Developer account
5. Press **⌘B** to build or **⌘R** to build & run

### Build Configurations

| Config | Use Case | Optimization |
|--------|----------|-------------|
| **Debug** | Development, breakpoints | None (-O0) |
| **Release** | TestFlight, profiling | Full (-O, WMO) |

### Scheme Settings

```
Product → Scheme → Edit Scheme (⌘<)
├── Build: FinalEvolutionLab target
├── Run: Debug configuration
├── Test: Debug configuration
├── Profile: Release configuration
└── Archive: Release configuration
```

---

## 9. Testing on Devices

### 9.1 iOS Simulator (Quick Testing)

```bash
# List available simulators
xcrun simctl list devices

# Build and run on simulator
xcodebuild -project ios/FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

> ⚠️ **Note**: UE5 Metal rendering may not work in Simulator. Use a physical device for UE5 integration testing.

### 9.2 Physical iPhone/iPad

1. Connect device via USB or Wi-Fi
2. **Trust** the computer on the device
3. In Xcode: **Window → Devices and Simulators** — verify device appears
4. Select device as destination in the toolbar
5. Build & Run (⌘R)

If prompted:
- On device: **Settings → General → VPN & Device Management → Trust**

### 9.3 Mac (Designed for iPad / Mac Catalyst)

The app can also run natively on Mac:

```
Xcode destination → My Mac (Designed for iPad)
```

Or add Mac Catalyst:
1. Target → General → **Deployment Info** → check **Mac (Catalyst)**
2. Build for **My Mac**

### 9.4 Testing Checklist

- [ ] App launches without crash
- [ ] All 5 tabs render (Lab, Train, Arena, Command, Profile)
- [ ] Onboarding flow completes
- [ ] Game mode selection shows all 17 modes
- [ ] HealthKit authorization prompt appears
- [ ] Body scan (camera) works
- [ ] UE5 game view loads for basketball H2H
- [ ] Score updates propagate from UE5 → Swift UI
- [ ] Settings sheet opens and saves preferences
- [ ] App backgrounds and resumes cleanly

---

## 10. M4 Pro Optimizations

### Xcode Build Settings for Apple Silicon

```
Build Settings → Architectures → arm64
Build Settings → Build Active Architecture Only → Yes (Debug), No (Release)
```

### Parallel Compilation

The M4 Pro has 14 CPU cores. Maximize build speed:

```bash
# Set Xcode to use all cores
defaults write com.apple.Xcode BuildSystemSchedulerInherentParallelizationWidth -int 14

# Or in Xcode Build Settings:
# SWIFT_COMPILATION_MODE = wholemodule (Release)
# SWIFT_COMPILATION_MODE = incremental (Debug)
```

### Metal GPU Optimizations

The M4 Pro's 20-core GPU supports:

| Feature | Setting |
|---------|---------|
| **Metal 3** | Enable in UE5 project settings |
| **Mesh Shaders** | Available for complex scene rendering |
| **Ray Tracing** | Hardware RT available on M4 Pro |
| **ProRes** | Hardware encode for video capture |
| **Neural Engine** | 16-core — use for body pose estimation |

### UE5 Shader Compilation

First build compiles ~5000 shaders. M4 Pro handles this in ~15–20 min:

```bash
# Pre-compile shaders via command line
"$UE_ROOT/Engine/Binaries/Mac/UnrealEditor-Cmd" \
  "$PROJECT" \
  -run=DerivedDataCache \
  -TargetPlatform=IOS \
  -fill
```

### Memory Tips

- UE5 Editor + Xcode + Simulator ≈ 32 GB RAM
- Close Chrome/other apps during builds
- If 24 GB RAM: close UE5 Editor before Xcode archive

---

## 11. Troubleshooting

### "No signing certificate" Error

```
Xcode → Settings → Accounts → Select team → Manage Certificates
→ "+" → Apple Development → Create
```

### "Untrusted Developer" on Device

```
Device → Settings → General → VPN & Device Management
→ Tap your developer profile → Trust
```

### UE5 Shader Compilation Fails

```bash
# Clear derived data
rm -rf ~/Library/Caches/com.epicgames.UnrealEngine
rm -rf ~/Documents/rork-final-evolution-lab/ios/FinalEvolutionLab_Unreal/Saved/ShaderDebugInfo
rm -rf ~/Documents/rork-final-evolution-lab/ios/FinalEvolutionLab_Unreal/DerivedDataCache
```

### Build Takes Too Long

```bash
# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Use incremental builds
# Xcode → Product → Build (⌘B) — NOT Clean Build Folder
```

### "Metal is not supported" in Simulator

- Metal requires a **physical device** or Apple Silicon Mac
- Use "My Mac (Designed for iPad)" destination instead
- Or test on a connected iPhone/iPad

### UE5 Framework Linking Errors

```
Build Settings → Other Linker Flags → add:
  -framework Metal
  -framework MetalKit
  -framework GameKit
  -lz -lsqlite3
```

### App Crashes on Launch

1. Check **Console.app** for crash logs
2. Xcode → **Debug → Attach to Process** after launch
3. Add Exception Breakpoint: **Debug → Breakpoints → Create Exception Breakpoint**

### iOS Deployment Target Mismatch

Ensure all targets/frameworks agree on minimum iOS:

```
Build Settings → iOS Deployment Target → 16.0
```

---

## Quick Reference Commands

```bash
# ── Open in Xcode ──────────────────────────
open ios/FinalEvolutionLab.xcodeproj

# ── Build from CLI ─────────────────────────
xcodebuild -project ios/FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  build

# ── Archive for Distribution ───────────────
xcodebuild -project ios/FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath build/FinalEvolutionLab.xcarchive \
  archive

# ── Export IPA ─────────────────────────────
xcodebuild -exportArchive \
  -archivePath build/FinalEvolutionLab.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/IPA/

# ── Run Tests ──────────────────────────────
xcodebuild test -project ios/FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# ── Cook UE5 for iOS ──────────────────────
source .ue5_env
"$RUN_UAT" BuildCookRun -project="$FEL_PROJECT" \
  -platform=IOS -clientconfig=Development \
  -cook -build -stage -pak
```

---

*Last updated: April 2, 2026 · Final Evolution Lab v1.0*
