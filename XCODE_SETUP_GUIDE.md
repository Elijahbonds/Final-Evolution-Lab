# Xcode Setup Guide — Final Evolution Lab

> Step-by-step instructions for opening, configuring, and building the  
> Final Evolution Lab in Xcode on your Mac Mini M4 Pro.

---

## Table of Contents

1. [Opening the Project](#1-opening-the-project)
2. [Project Structure in Xcode](#2-project-structure-in-xcode)
3. [Required Xcode Settings](#3-required-xcode-settings)
4. [Code Signing & Provisioning](#4-code-signing--provisioning)
5. [Adding the UE5 Game Framework](#5-adding-the-ue5-game-framework)
6. [Build Settings for iOS and macOS](#6-build-settings-for-ios-and-macos)
7. [Schemes & Configurations](#7-schemes--configurations)
8. [Testing & Debugging](#8-testing--debugging)
9. [Archiving & Distribution](#9-archiving--distribution)
10. [Xcode Tips for M4 Pro](#10-xcode-tips-for-m4-pro)

---

## 1. Opening the Project

### First Time Setup

```bash
cd ~/Documents/rork-final-evolution-lab

# Open the Xcode project
open ios/FinalEvolutionLab.xcodeproj
```

### If Using a Workspace (with UE5 subproject or CocoaPods)

```bash
# Create workspace if not present
# (only needed if integrating UE5 as Xcode subproject)
open ios/FinalEvolutionLab.xcworkspace
```

### What You'll See

When Xcode opens, the navigator shows:

```
FinalEvolutionLab.xcodeproj
├── FinalEvolutionLab/          ← Main app target
│   ├── FinalEvolutionLabApp.swift   ← @main entry point
│   ├── ContentView.swift            ← Root TabView (5 tabs)
│   ├── Config.swift                 ← Server URLs & feature flags
│   ├── Models/                      ← 40+ data models
│   ├── Views/                       ← 50+ SwiftUI views
│   ├── ViewModels/                  ← LabViewModel, TrainingViewModel
│   ├── Services/                    ← Networking, HealthKit, bridges
│   ├── Utilities/                   ← Theme, scoring, helpers
│   ├── Meshy/                       ← 3D model assets (bundled)
│   ├── Assets.xcassets              ← App icon, colors, images
│   └── FinalEvolutionLab.entitlements
├── FinalEvolutionLabTests/     ← Unit tests
└── FinalEvolutionLabUITests/   ← UI automation tests
```

---

## 2. Project Structure in Xcode

### Targets

| Target | Type | Purpose |
|--------|------|---------|
| **FinalEvolutionLab** | iOS App | Main app with SwiftUI |
| **FinalEvolutionLabTests** | Unit Test | Model & service tests |
| **FinalEvolutionLabUITests** | UI Test | Automated UI flows |

### Key Source Files

#### Entry Point & Navigation
| File | Purpose |
|------|---------|
| `FinalEvolutionLabApp.swift` | `@main` — Firebase init, deep links |
| `ContentView.swift` | Root `TabView` with 5 tabs |
| `Config.swift` | All server URLs, bundle ID, feature flags |

#### Game System (Arena Tab)
| File | Purpose |
|------|---------|
| `Models/GameMode.swift` | 17 game mode definitions (12 `GameModeId` enums) |
| `Views/GameModeSelectionView.swift` | Grid of game modes with categories |
| `Views/GamePlayView.swift` | Full gameplay controller (SceneKit + physics) |
| `Views/StreamingArenaView.swift` | Pixel Streaming WebRTC view |
| `Services/PixelStreamingService.swift` | WebSocket signalling client |

#### Training & Body System (Train Tab)
| File | Purpose |
|------|---------|
| `Views/TrainingHubView.swift` | Exercise catalog & workout programs |
| `Views/ExerciseDemoView.swift` | 3D exercise demonstrations |
| `Services/HealthKitService.swift` | Heart rate, HRV, steps, calories |
| `Services/CoreMotionHelper.swift` | Accelerometer & gyroscope |
| `Views/SystemScanView.swift` | Body scanning interface |

#### Native Bridge (Swift ↔ UE5)
| File | Purpose |
|------|---------|
| `Services/NativeBridgeManager.swift` | Main bridge coordinator |
| `Services/RorkNativeBridge.swift` | C-level exports for UE5 |
| `Services/RorkScoreManager.swift` | Score sync between Swift & UE5 |

#### Economy & Profile (Command/Profile Tabs)
| File | Purpose |
|------|---------|
| `Views/CommandCenterView.swift` | Stats dashboard |
| `Views/VaultView.swift` | Profile & digital assets |
| `Models/ShardEconomy.swift` | In-app currency system |
| `Services/SaveSystem.swift` | Local persistence |

---

## 3. Required Xcode Settings

### General Tab (Target Settings)

```
FinalEvolutionLab target → General
├── Display Name: Final Evolution Lab
├── Bundle Identifier: com.finalevolutiongroup.lab
├── Version: 1.0.0
├── Build: 1
├── Minimum Deployments: iOS 16.0
├── Device Orientation: Portrait, Landscape Left, Landscape Right
└── Status Bar Style: Dark Content
```

### Info Tab

Add these keys to Info.plist (via Xcode Info tab):

| Key | Value | Required For |
|-----|-------|-------------|
| `NSCameraUsageDescription` | "Body scanning and AR features" | Camera access |
| `NSMotionUsageDescription` | "Biomechanical movement tracking" | CoreMotion |
| `NSHealthShareUsageDescription` | "Reading heart rate and HRV data" | HealthKit read |
| `NSHealthUpdateUsageDescription` | "Recording workout calories" | HealthKit write |
| `NSLocalNetworkUsageDescription` | "Multiplayer game connections" | MultipeerConnectivity |
| `NSMicrophoneUsageDescription` | "Voice chat in multiplayer" | Microphone |

### Build Settings to Verify

```
Build Settings → Search for each:

SWIFT_VERSION                     = 5.9  (or 6.0)
IPHONEOS_DEPLOYMENT_TARGET        = 16.0
TARGETED_DEVICE_FAMILY            = 1,2  (iPhone + iPad)
ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES
ENABLE_BITCODE                    = NO   (deprecated in Xcode 16)
CODE_SIGN_STYLE                   = Automatic
DEVELOPMENT_TEAM                  = <Your Team ID>
PRODUCT_BUNDLE_IDENTIFIER         = com.finalevolutiongroup.lab
```

---

## 4. Code Signing & Provisioning

### Automatic Signing (Development)

1. Select target **FinalEvolutionLab**
2. **Signing & Capabilities** tab
3. ✅ **Automatically manage signing**
4. **Team**: Select your Apple Developer account
5. Xcode creates development provisioning profile automatically

### Manual Signing (Distribution)

For App Store / TestFlight:

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Create certificates:
   - **Apple Distribution** certificate
   - **Apple Push Notification** certificate (using provided PEM)
3. Register App ID: `com.finalevolutiongroup.lab`
   - Enable capabilities: HealthKit, Push Notifications
4. Create provisioning profiles:
   - **iOS App Development** (for testing)
   - **App Store Distribution** (for release)
5. Download and double-click profiles to install

### Using Provided PEM Certificates

```bash
# The provided PEM files:
# - FinalEvolutionLab.pem        → Development/Distribution cert
# - Final Evolution Lab.pem      → Push notification cert

# Import into Keychain Access
open -a "Keychain Access"
# File → Import Items → select the .pem files

# Or via command line:
security import "certs/FinalEvolutionLab.pem" -k ~/Library/Keychains/login.keychain-db
```

### Entitlements File

The existing `FinalEvolutionLab.entitlements` has HealthKit enabled.
Add more capabilities in Xcode:

```
Target → Signing & Capabilities → "+ Capability"
→ Add: HealthKit
→ Add: Push Notifications  (if using remote notifications)
→ Add: Background Modes    (Audio, Background fetch)
```

---

## 5. Adding the UE5 Game Framework

### Step 1: Build UE5 for iOS

See [IOS_NATIVE_BUILD_GUIDE.md § 5](./IOS_NATIVE_BUILD_GUIDE.md#5-building-ue5-for-ios-on-mac).

After building, you'll have:
```
Builds/iOS/FinalEvolutionLab.framework   (or .xcframework)
```

### Step 2: Add Framework to Xcode

1. In Xcode, select the **FinalEvolutionLab** project in the navigator
2. Select the **FinalEvolutionLab** target → **General** tab
3. Scroll to **Frameworks, Libraries, and Embedded Content**
4. Click **"+"** → **Add Other** → **Add Files**
5. Navigate to `Builds/iOS/FinalEvolutionLab.framework`
6. Set embed option: **Embed & Sign**

### Step 3: Configure Framework Search Paths

```
Build Settings → Framework Search Paths →
  $(PROJECT_DIR)/../Builds/iOS     (recursive)

Build Settings → Library Search Paths →
  $(PROJECT_DIR)/../Builds/iOS/lib  (recursive)

Build Settings → Header Search Paths →
  $(PROJECT_DIR)/../ios/FinalEvolutionLab_Unreal/Source  (recursive)
```

### Step 4: Add Required System Frameworks

```
Target → General → Frameworks, Libraries →
  + Metal.framework
  + MetalKit.framework
  + GameKit.framework
  + ARKit.framework
  + CoreMotion.framework
  + HealthKit.framework
  + AVFoundation.framework
  + AudioToolbox.framework
```

### Step 5: Bridging Header (if needed)

If calling UE5 C++ from Swift, create `FinalEvolutionLab-Bridging-Header.h`:

```objc
// FinalEvolutionLab-Bridging-Header.h
// Bridge between Swift and UE5 Objective-C++ code

#import "RorkNativeBridgeIOSStub.h"

// UE5 game entry points
void UE5_Initialize(void);
void UE5_LaunchMode(const char* modeId);
void UE5_Shutdown(void);
```

Set in Build Settings:
```
SWIFT_OBJC_BRIDGING_HEADER = FinalEvolutionLab/FinalEvolutionLab-Bridging-Header.h
```

---

## 6. Build Settings for iOS and macOS

### iOS Build Settings

| Setting | Debug | Release |
|---------|-------|---------|
| Optimization | `-Onone` | `-O -whole-module-optimization` |
| Debug Info | DWARF with dSYM | DWARF with dSYM |
| Strip Debug Symbols | No | Yes |
| Enable Testability | Yes | No |
| Swift Strict Concurrency | Targeted | Complete |

### macOS (Mac Catalyst) Build Settings

To also run on Mac natively:

1. Target → General → **Supported Destinations** → Add **Mac (Mac Catalyst)**
2. Set `SUPPORTS_MACCATALYST = YES` in Build Settings
3. Minimum macOS version: 14.0

### Universal Build (iOS + macOS)

```
Build Settings:
  ARCHS = arm64
  VALID_ARCHS = arm64
  SUPPORTS_MACCATALYST = YES
  DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = YES
```

---

## 7. Schemes & Configurations

### Default Scheme: FinalEvolutionLab

```
Product → Scheme → Edit Scheme (⌘<)

Run:
  Build Configuration: Debug
  Executable: FinalEvolutionLab.app
  Arguments: (none)
  Environment Variables:
    FEL_ENVIRONMENT = development

Test:
  Build Configuration: Debug
  Test Plans: FinalEvolutionLabTests, FinalEvolutionLabUITests

Profile:
  Build Configuration: Release
  Executable: FinalEvolutionLab.app

Analyze:
  Build Configuration: Debug

Archive:
  Build Configuration: Release
  Reveal Archive in Organizer: ✅
```

### Create Additional Schemes

For testing specific configurations:

1. **FinalEvolutionLab-Staging**: Points to staging server
2. **FinalEvolutionLab-Local**: Points to localhost (for local UE5 testing)

```
Product → Scheme → New Scheme → Duplicate "FinalEvolutionLab"
→ Rename → Edit environment variables
```

### Build Configurations

| Configuration | Use | Key Differences |
|--------------|-----|----------------|
| **Debug** | Daily development | No optimization, assertions ON |
| **Release** | TestFlight / App Store | Full optimization, assertions OFF |
| **Staging** (custom) | QA testing | Release optimization, staging URLs |

---

## 8. Testing & Debugging

### Running Unit Tests

```bash
# From command line
xcodebuild test \
  -project ios/FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -resultBundlePath TestResults

# In Xcode: ⌘U (or Product → Test)
```

### Running UI Tests

```bash
xcodebuild test \
  -project ios/FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing FinalEvolutionLabUITests
```

### Debugging Tips

#### Console Output
```
Xcode → View → Debug Area → Activate Console (⇧⌘C)
```

#### Breakpoints
- **Exception breakpoint**: Debug → Breakpoints → "+" → Exception Breakpoint → All Exceptions
- **Symbolic breakpoint**: `UIViewAlertForUnsatisfiableConstraints` for layout issues

#### Memory Debugging
```
Product → Scheme → Edit Scheme → Run → Diagnostics
  ✅ Malloc Scribble
  ✅ Zombie Objects (for EXC_BAD_ACCESS)
  ✅ Address Sanitizer (for memory corruption)
```

#### Network Debugging
```
Xcode → Product → Profile (⌘I) → Network → Record
```

#### Metal GPU Debugging (for UE5)
```
Product → Scheme → Edit Scheme → Run → Options
  GPU Frame Capture: Metal
  Metal API Validation: Enabled
```

### Testing HealthKit

HealthKit requires a physical device. In the Simulator:
- Use **Health app** to add sample data
- Or mock the `HealthKitService` in tests

### Testing Without UE5

The Swift app works standalone:
- Game modes use SceneKit fallback rendering
- All menus, training, and profile features work without UE5
- Set `Config.ENABLE_PIXEL_STREAMING = false` to skip streaming

---

## 9. Archiving & Distribution

### Archive for TestFlight

```bash
# 1. Archive
xcodebuild archive \
  -project ios/FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath build/FinalEvolutionLab.xcarchive

# 2. Export IPA
xcodebuild -exportArchive \
  -archivePath build/FinalEvolutionLab.xcarchive \
  -exportOptionsPlist ios/ExportOptions_AppStore.plist \
  -exportPath build/IPA/

# 3. Upload to App Store Connect
xcrun altool --upload-app \
  -f build/IPA/FinalEvolutionLab.ipa \
  -t ios \
  -u your@apple.id \
  -p @keychain:AC_PASSWORD
```

### ExportOptions_AppStore.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

### In Xcode (GUI)

1. **Product → Archive** (builds Release config)
2. **Organizer** opens → Select archive → **Distribute App**
3. Choose **App Store Connect** → **Upload**
4. Follow prompts for signing
5. Go to [App Store Connect](https://appstoreconnect.apple.com) → TestFlight

---

## 10. Xcode Tips for M4 Pro

### Speed Up Builds

```bash
# Increase build parallelism
defaults write com.apple.dt.XCBuild EnableSwiftBuildSystemIntegration 1

# Use new Swift build system
defaults write com.apple.dt.Xcode UseSanitizedBuildSystemEnvironment -bool YES
```

### Derived Data Location

```bash
# Move derived data to fast NVMe (default is already on internal SSD)
# Check current location:
defaults read com.apple.dt.Xcode IDECustomDerivedDataLocation

# Clean when needed:
rm -rf ~/Library/Developer/Xcode/DerivedData/FinalEvolutionLab-*
```

### Useful Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘B | Build |
| ⌘R | Run |
| ⌘U | Test |
| ⌘⇧K | Clean Build Folder |
| ⌘⇧O | Open Quickly (file search) |
| ⌘⇧J | Reveal in Navigator |
| ⌘⇧L | Library (add views) |
| ⌃⌘R | Run without building |
| ⌘I | Profile (Instruments) |

### Xcode Previews

SwiftUI views support live previews. Add to any view file:

```swift
#Preview {
    GameModeSelectionView(viewModel: LabViewModel())
}
```

Use **Canvas** (⌥⌘↩) for side-by-side preview while coding.

---

*Last updated: April 2, 2026 · Final Evolution Lab v1.0*
