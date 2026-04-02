# Phase 2: UE5 iOS Build & Integration Guide

> **Goal:** Make all 17 game modes fully playable in the iOS app  
> **Estimated Time:** ~4 hours  
> **Requirements:** Mac with GPU, Xcode 15+, Unreal Engine 5.4

---

## Overview

There are two paths to playable games:

| Approach | Best For | Timeline |
|----------|----------|----------|
| **A: Pixel Streaming** | Quick demo, cloud gaming | 2-3 hours |
| **B: Native iOS Embed** | Offline play, App Store | 3-4 hours |

**Recommendation:** Start with **Pixel Streaming** for fastest results, then add native embed later.

---

## Option A: Pixel Streaming (Fastest Path)

### Step 1: Open UE5 Project on Mac (15 min)

```bash
# 1. Pull latest code
cd rork-final-evolution-lab
git pull origin main

# 2. Open in Unreal Engine
# Launch Epic Games Launcher → Library → Browse
# Navigate to: UnrealStarter/BasketballGame/BasketballGame.uproject
```

### Step 2: Import AI Assets (15 min)

In UE5 Editor:
```
Tools → Execute Python Script → EditorPython/fel_import_ai_assets.py
Tools → Execute Python Script → EditorPython/fel_import_elijahbonds_animations.py
```

Or use the batch script:
```bash
source .ue5_env  # Set UE5 paths
bash scripts/ue5_setup/import_all_assets.sh
```

### Step 3: Enable Pixel Streaming Plugin (5 min)

1. In UE5 Editor: `Edit → Plugins`
2. Search "Pixel Streaming"
3. Enable it → Restart Editor

### Step 4: Package for Linux Server (1 hour)

```bash
# Cook for Linux Dedicated Server with Pixel Streaming
bash scripts/ue5_setup/cook_fel_linux_server.sh --config Development
```

This creates:
- `Builds/LinuxServer/` - The packaged server
- `launch_pixel_streaming.sh` - Launch script
- `Dockerfile` + `docker-compose.yml` - Container deployment

### Step 5: Deploy Streaming Server (30 min)

```bash
# Option 1: Docker (recommended)
cd Builds/LinuxServer
docker-compose up -d

# Option 2: Direct run
./launch_pixel_streaming.sh
```

The server runs on a GPU cloud instance (AWS g4dn, GCP T4, etc.).

### Step 6: Update iOS App Config (5 min)

Edit `ios/FinalEvolutionLab/Config.swift`:
```swift
static let STREAMING_SERVER_URL = "wss://your-server-ip:8888"
```

### Step 7: Build & Run iOS App (10 min)

```bash
# In Xcode:
# 1. Open ios/FinalEvolutionLab.xcodeproj
# 2. Select your iPhone
# 3. Cmd+R to build and run
```

The app connects to the streaming server and games are playable!

---

## Option B: Native UE5 iOS Embed (Full Offline)

### Step 1: Configure iOS in UE5 (15 min)

1. Open UE5 Project Settings → Platforms → iOS
2. Set:
   - **Bundle Identifier:** `com.finalevolutiongroup.lab`
   - **Minimum iOS Version:** 16.0
   - **Supported Devices:** iPhone only (or Universal)
   - **Orientation:** Landscape
3. Under Rendering:
   - **Metal:** Enabled
   - **Forward Shading:** Recommended for mobile

### Step 2: Configure Signing (10 min)

1. **Project Settings → iOS → Signing**
2. Set your:
   - Team ID
   - Provisioning Profile (from Apple Developer Portal)
   - Signing Certificate

Or use automatic signing in Xcode after export.

### Step 3: Package for iOS (1-2 hours)

```bash
# From UE5 Editor:
# File → Package Project → iOS

# Or from command line:
source .ue5_env
$RUN_UAT BuildCookRun \
  -project="$FEL_PROJECT" \
  -platform=iOS \
  -clientconfig=Development \
  -cook -stage -package -archive \
  -archivedir=Builds/iOS
```

This produces an `.ipa` file or Xcode project.

### Step 4: Integrate UE5 Framework with Swift App (1 hour)

#### 4a. Create a UE5 Wrapper View

Create `ios/FinalEvolutionLab/Views/UE5GameView.swift`:
```swift
import SwiftUI
import UIKit

struct UE5GameView: UIViewControllerRepresentable {
    let gameMode: String
    
    func makeUIViewController(context: Context) -> UE5ViewController {
        let vc = UE5ViewController()
        vc.gameMode = gameMode
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UE5ViewController, context: Context) {}
}

class UE5ViewController: UIViewController {
    var gameMode: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize UE5 with the selected game mode
        // This calls into the UE5 framework
        launchUE5Game(mode: gameMode)
    }
    
    private func launchUE5Game(mode: String) {
        // UE5 iOS framework integration point
        // The exact API depends on UE5's iOS framework output
    }
}
```

#### 4b. Add UE5 Framework to Xcode Project

1. Drag the UE5 `.framework` file into the Xcode project
2. Add to "Frameworks, Libraries, and Embedded Content"
3. Set to "Embed & Sign"

#### 4c. Update Game Mode Views

In each game mode view, replace the placeholder with:
```swift
UE5GameView(gameMode: "basketball_h2h")
```

### Step 5: Test on Device (30 min)

1. Connect iPhone via USB
2. Select device in Xcode
3. `Cmd + R` to build and run
4. Test each game mode

---

## Asset Checklist

Before building, verify all assets are imported:

| Category | Count | Status |
|----------|-------|--------|
| Exercise Animations (DeepMotion) | 23 | Generated ✅ |
| Exercise Props (Meshy) | 9 | Generated ✅ |
| Environment Models | 12 | Generated ✅ |
| Elijah Bonds Animations | 10 | Generated ✅ |
| UE5 Catalogue Animations | 15+ | References Ready ✅ |
| **Total** | **49+** | **Ready for Import** |

---

## Troubleshooting

### "No GPU found" on Cloud VM
UE5 requires a GPU for rendering. Use a Mac with discrete GPU or Apple Silicon (M1+).

### Xcode Signing Errors
1. Ensure Apple Developer account is active
2. In Xcode: `Preferences → Accounts → Add Apple ID`
3. Select team under Signing & Capabilities

### UE5 iOS Build Fails
1. Ensure iOS support is installed in UE5 (Epic Games Launcher → Options)
2. Check Xcode Command Line Tools: `xcode-select --install`
3. Accept Xcode license: `sudo xcodebuild -license accept`

### Pixel Streaming Won't Connect
1. Check server is running: `curl http://server-ip:8888/healthz`
2. Verify WebSocket URL in Config.swift matches server
3. Check firewall allows ports 8888 (signalling) and 3478 (TURN)

### App Shows Old Build
```bash
# Pull latest changes
git pull origin main
# In Xcode: Product → Clean Build Folder (Shift+Cmd+K)
# Then rebuild: Cmd+R
```

---

## Quick Reference Commands

```bash
# Pull latest
git pull origin main

# Start streaming services (for development)
bash scripts/start_services.sh

# Stop services
bash scripts/stop_services.sh

# Run deployment tests
bash scripts/test_deployment.sh

# Test game modes
bash scripts/test_game_modes.sh

# Full pipeline (Linux - no GPU needed for scripts)
bash scripts/ue5_setup/fel_complete_pipeline.sh --skip-cv
```

---

## Next Steps After Phase 2

1. **TestFlight Beta** - Upload .ipa to App Store Connect
2. **Cloud GPU Setup** - Deploy Pixel Streaming on AWS/GCP
3. **Multiplayer** - Enable H2H game modes via server
4. **App Store Submission** - Final review and publish
