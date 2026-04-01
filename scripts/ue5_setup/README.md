# UE5 Setup & iOS Deployment Pipeline

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **GPU** | NVIDIA GTX 1080 / AMD RX 6700 | NVIDIA RTX 3080+ |
| **RAM** | 32 GB | 64 GB |
| **Disk** | 200 GB free | 500 GB SSD |
| **CPU** | 6+ cores | 16+ cores |
| **OS** | Ubuntu 22.04+ / macOS 13+ | Ubuntu 22.04 + macOS 14 |

> ⚠️ **GPU Required**: UE5 rendering and Pixel Streaming require a GPU. The current VM has no GPU — run these scripts on a GPU-enabled machine.

## Quick Start

### One-Command Pipeline (GPU machine)
```bash
# Full pipeline: install UE5 → import assets → cook → build iOS
./scripts/ue5_setup/fel_complete_pipeline.sh
```

### Step-by-Step

```bash
# 1. Install UE5 from source (requires Epic Games GitHub access)
export GITHUB_TOKEN="ghp_your_token"
./scripts/ue5_setup/install_ue5_linux.sh --branch 5.4

# 2. Source environment
source .ue5_env

# 3. Import all assets into UE5
./scripts/ue5_setup/import_all_assets.sh

# 4. Cook for Linux server (Pixel Streaming)
./scripts/ue5_setup/cook_fel_linux_server.sh --config Shipping

# 5. Cook for iOS (macOS only)
./scripts/ue5_setup/cook_fel_ios.sh --config Shipping

# 6. Build iOS app & IPA
./scripts/ue5_setup/prepare_ios_build.sh --upload-testflight
```

## Script Reference

| Script | Purpose | Platform |
|--------|---------|----------|
| `install_ue5_linux.sh` | Build UE5 from GitHub source | Linux (GPU) |
| `import_all_assets.sh` | Run all UE5 Editor import scripts | Linux/Mac (UE5) |
| `cook_fel_linux_server.sh` | Package for Linux dedicated server | Linux (UE5+GPU) |
| `cook_fel_ios.sh` | Package for iOS platform | macOS (UE5+Xcode) |
| `prepare_ios_build.sh` | Build IPA, upload to TestFlight | macOS (Xcode) |
| `fel_complete_pipeline.sh` | Master orchestration | Any |

## UE5 Editor Python Scripts

Located in `UnrealStarter/BasketballGame/EditorPython/`:

| Script | Assets |
|--------|--------|
| `fel_import_ai_assets.py` | 49 AI-generated assets (Meshy, Luma, DeepMotion) |
| `fel_import_elijahbonds_animations.py` | 26 Elijah Bonds motion capture animations |
| `fel_import_catalogue_animations.py` | 130+ UE5 Marketplace animation references |
| `fel_verify_assets.py` | Verification of all imported assets |

## Animation Coverage

### Custom Animations (Elijah Bonds / DeepMotion)
- 47 unique basketball movements from 10 Instagram videos
- Covers: dunking, dribbling, shooting, driving, passing, defense
- Primary modes: basketball_5v5, basketball_3v3, slam_dunk_contest, streetball

### UE5 Marketplace Animations Needed
12 sport-specific packs for non-basketball game modes:

| Pack | Game Mode | Animations |
|------|-----------|------------|
| Soccer | soccer | 10 |
| Football | football | 10 |
| Tennis | tennis | 10 |
| Boxing | boxing | 12 |
| Martial Arts | martial_arts | 10 |
| Track & Field | track_and_field | 11 |
| Swimming | swimming | 11 |
| Volleyball | volleyball | 10 |
| Baseball | baseball | 10 |
| Gymnastics | gymnastics | 10 |
| Skateboarding | skateboarding | 10 |
| Wrestling | wrestling | 10 |

### UE5 Built-in (Mannequin Pack)
7 core locomotion animations that ship with UE5 (idle, walk, run, jump, fall, land, sprint).

## iOS Deployment

### Configuration
- **Bundle ID**: `com.finalevolutiongroup.lab`
- **Streaming Server**: `wss://stream.finalevolutiongroup.com`
- **TURN Server**: `turn:turn.finalevolutiongroup.com:3478`
- **Minimum iOS**: 16.0

### Build Flow
1. Configure signing in Xcode (Team ID, provisioning profile)
2. Cook UE5 project for iOS (if using native UE5 rendering)
3. Build Swift iOS app (Pixel Streaming client)
4. Archive → Export IPA → Upload to TestFlight

### Files Modified for iOS
- `ios/FinalEvolutionLab/Config.swift` — Production streaming URLs
- `ios/FinalEvolutionLab/Services/PixelStreamingService.swift` — Default server URL
- `ios/FinalEvolutionLab/FinalEvolutionLab.entitlements` — HealthKit, networking
- `ios/FinalEvolutionLab/Info.plist` — Privacy descriptions, ATS config

## Pixel Streaming Architecture

```
┌──────────────┐     WebRTC      ┌─────────────────┐
│  iOS App     │◄───────────────►│  UE5 Server     │
│  (Swift)     │                 │  (Linux+GPU)    │
└──────┬───────┘                 └────────┬────────┘
       │ WSS                              │ WS
       ▼                                  ▼
┌──────────────────────────────────────────────────┐
│  Signalling Server (Node.js)                     │
│  stream.finalevolutiongroup.com:8888             │
└──────────────────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│  TURN/STUN   │
│  (coturn)    │
└──────────────┘
```

## Troubleshooting

### "No GPU detected" during UE5 install
Expected on cloud VMs without GPU. Transfer project to GPU machine.

### UE5 clone fails with 403
Your GitHub account must be linked to Epic Games:
1. Visit https://www.unrealengine.com/ue-on-github
2. Link your GitHub account
3. Accept the organization invite

### iOS build fails with signing error
1. Open Xcode → Preferences → Accounts → Add Apple ID
2. Set Team in project settings
3. Update `YOUR_TEAM_ID` in ExportOptions plists

### Marketplace animations not found
1. Open UE5 Editor → Epic Games Marketplace
2. Search for the pack name listed in `fel_import_catalogue_animations.py`
3. Purchase/download → will auto-install to Content directory
4. Re-run `import_all_assets.sh`
