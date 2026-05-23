# SEELE AI EXECUTION PACKAGE
## Final Evolution Lab — Antigravity × Seele Production Stack
### v1.0 · 2026-05-22 · Branch: `anti-gravity-fel`

> **Audience:** Seele AI agents (autonomous execution). Every section is self-contained  
> and machine-parseable. No human interpretation gaps.  
> **Repository:** `github.com/<owner>/Final-Evolution-Lab`  
> **Engine:** Unreal Engine 5.7 · Android AAB (Google Play)  
> **Architecture:** UE 5.7 native host → Swift bridge → WKWebView overlay → FastAPI backend → MongoDB/Firestore  
> **Distribution:** Google Play Store ONLY (no App Store)  
> **Companion Docs:** `designs/fel_seele_10_phase_execution_directive.md` (245 quality gates)

---

## TABLE OF CONTENTS

1. [Antigravity × Seele Integration Model](#1-antigravity--seele-integration-model)
2. [Google Distribution Pipeline](#2-google-distribution-pipeline)
3. [Complete Asset Creation Checklist](#3-complete-asset-creation-checklist)
4. [Economy System Implementation](#4-economy-system-implementation)
5. [Build Pipeline & CI/CD](#5-build-pipeline--cicd)
6. [Seele-Specific Directives](#6-seele-specific-directives)
7. [Phase-by-Phase Execution Plan](#7-phase-by-phase-execution-plan)

---

## 1. ANTIGRAVITY × SEELE INTEGRATION MODEL

### 1.1 Division of Responsibility

```
┌─────────────────────────────────────────────────────────────┐
│                    SEELE AI (Creator)                        │
│                                                             │
│  1. Clone repo → branch: seele/<feature-name>               │
│  2. Mirror existing component patterns                      │
│  3. Decipher needs from registries + design docs            │
│  4. Create ALL assets from scratch:                         │
│     • 3D venue models (.umap, .uasset)                     │
│     • Character animations (Blueprints)                     │
│     • UI widgets (UMG)                                      │
│     • Audio (SFX + ambient loops)                           │
│     • Textures + materials                                  │
│     • Game mode Blueprints (BP_<ModeName>)                  │
│  5. Validate against quality gates                          │
│  6. Push seele/ branch → open PR                            │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                  ANTI-GRAVITY (Wirer)                        │
│                                                             │
│  1. Review Seele PRs                                        │
│  2. Wire assets into registries:                            │
│     • FEL_ModeManager.production.json                       │
│     • ue_mode_maps.json                                     │
│     • DefaultGame.ini [EmergentPlayMap]                     │
│     • ArenaSettings.json                                    │
│     • FEL_VenueRegistry.production.json                     │
│     • GameMode.swift                                        │
│  3. Economy integration (PRQ weights, shard tables)         │
│  4. Backend route wiring (server.py endpoints)              │
│  5. Merge seele/ branches → anti-gravity-fel                │
│  6. Run full validation suite                               │
│  7. Build & distribute via Google Play                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Clone & Mirror Protocol

```bash
# Step 1: Seele clones the repo
git clone --depth=50 https://github.com/<owner>/Final-Evolution-Lab.git
cd Final-Evolution-Lab
git checkout anti-gravity-fel

# Step 2: Create feature branch
git checkout -b seele/<feature-name>

# Step 3: Mirror pattern — find reference implementation
# Example: Creating surfing venue
# Mirror from: UnrealStarter/BasketballGame/Content/FEL/Venues/VeniceBeach/
# Copy structure, rename assets, adapt for surfing mechanics
```

### 1.3 Registry Source-of-Truth Files

| # | File | Purpose | Format |
|---|------|---------|--------|
| 1 | `backend/FEL_ModeManager.production.json` | Master mode registry (19 modes) | JSON |
| 2 | `backend/ue_mode_maps.json` | Mode→Unreal map token mapping | JSON |
| 3 | `infra/ue5_config/DefaultGame.ini` | `[EmergentPlayMap]` cooked map paths | INI |
| 4 | `UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json` | Venue metadata (spawn, physics, audio) | JSON |
| 5 | `UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json` | Per-mode gameplay params (score, time, physics) | JSON |
| 6 | `FinalEvolutionLab/Models/GameMode.swift` | iOS-side mode enum + UI metadata | Swift |

**Rule:** ALL 6 registries must agree. If Seele adds a mode or venue, all 6 must be updated in the same PR.

### 1.4 Mode Inventory (Current State — Post P0 Fixes)

| # | Mode ID | Status | Venue | Map Path |
|---|---------|--------|-------|----------|
| 1 | `basketball_h2h` | ✅ production | Venice Beach | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| 2 | `basketball_dunk` | ✅ production | Venice Beach | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| 3 | `basketball_3v3` | ✅ production | Venice Beach | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| 4 | `karate_h2h` | ✅ production | Dojo | `/Game/FEL/Venues/Dojo/Dojo` |
| 5 | `karate_endless` | ✅ production | Dojo | `/Game/FEL/Venues/Dojo/Dojo` |
| 6 | `baseball` | ✅ production | Baseball Park | `/Game/FEL/Venues/BaseballPark/BaseballPark` |
| 7 | `football` | ✅ production | Gridiron | `/Game/FEL/Venues/Gridiron/Gridiron` |
| 8 | `soccer` | ✅ production | Soccer Stadium | `/Game/FEL/Venues/SoccerStadium/SoccerStadium` |
| 9 | `golf` | ✅ production | Links | `/Game/FEL/Venues/Links/Links` |
| 10 | `tennis` | ✅ production | Tennis Court | `/Game/FEL/Venues/TennisCourt/TennisCourt` |
| 11 | `volleyball` | ✅ production | Sand Court | `/Game/FEL/Venues/SandCourt/SandCourt` |
| 12 | `surfing` | ✅ production | Venice Beach | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| 13 | `skateboarding` | 🟡 staging | Skate Park | `/Game/FEL/Venues/SkatePark/SkatePark` |
| 14 | `snowboarding` | 🟡 staging | Mountain Slope | `/Game/FEL/Venues/MountainSlope/MountainSlope` |
| 15 | `gymnastics` | 🟡 staging | Training Floor | `/Game/FEL/Venues/TrainingFloor/TrainingFloor` |
| 16 | `brain_brawl` | 🟡 staging | Neuro Arena | `/Game/FEL/Venues/NeuroArena/NeuroArena` |
| 17 | `who_scene_it` | 🔵 preview | Neuro Arena | `/Game/FEL/Venues/NeuroArena/NeuroArena` |
| 18 | `court_carnival` | 🔵 preview | Venice Beach | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| 19 | `market_browse` | ⚪ non-game-module | Luma Venice Shop | `/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop` |

**Counts:** 12 production · 4 staging · 2 preview · 1 non-game-module = **19 total**

---

## 2. GOOGLE DISTRIBUTION PIPELINE

### 2.1 Store Configuration

Reference config: `infra/distribution/google_play_distribution.json`

| Parameter | Value |
|-----------|-------|
| Package Name | `com.antigravity.finalevolutionlab` |
| Category | `GAME_SPORTS` |
| Content Rating | `EVERYONE_10_PLUS` |
| Target SDK | 35 (Android 15) |
| Min SDK | 28 (Android 9 Pie) |
| ABI | `arm64-v8a` only |
| Texture Compression | ASTC |
| Pricing | Free with IAP |

### 2.2 Release Track Progression

```
Internal Testing ──→ Closed Alpha ──→ Open Beta ──→ Production
    (Seele team)    (100 testers)    (14-day soak)   (10% staged → 100%)
```

| Track | Gate Criteria |
|-------|---------------|
| **Internal** | All 147+ smoke tests pass · JSON valid · Swift compiles · economy tests pass |
| **Closed Alpha** | All internal gates + 12 production modes playable end-to-end · crash rate < 2% |
| **Open Beta** | Alpha gates + PRQ/shard economy validated · session receipts correct · 72h no ANR > 0.5% |
| **Production** | Beta gates + 14-day soak clean · store listing approved · privacy policy live |

### 2.3 AAB Build Configuration

```
Build Output: app/build/outputs/bundle/release/app-release.aab
Signing:      Google Play App Signing (upload key → fel-release-key)
Split APKs:   Enabled (per-ABI, per-density, per-language)

Asset Packs:
  ├── venue_assets (install-time) — core 12 production venue maps + textures
  └── staging_venues (on-demand) — skateboarding, snowboarding, gymnastics, brain_brawl
```

### 2.4 IAP SKUs

| SKU | Price | Type |
|-----|-------|------|
| `fel_shard_pack_100` | $0.99 | Consumable |
| `fel_shard_pack_500` | $3.99 | Consumable |
| `fel_shard_pack_2000` | $9.99 | Consumable |
| `fel_creator_card_pack` | $4.99 | Consumable |
| `fel_sovereign_pass_monthly` | $9.99 | Subscription |
| `fel_sovereign_pass_yearly` | $79.99 | Subscription |

### 2.5 Firebase Integration

| Service | Purpose |
|---------|---------|
| Crashlytics | Crash reporting + ANR monitoring |
| Remote Config | Feature flags, A/B testing, mode enable/disable |
| Analytics | Session events, economy flow, funnel tracking |
| Cloud Messaging | Push notifications for tournaments, new modes |

---

## 3. COMPLETE ASSET CREATION CHECKLIST

### 3.1 Legend

- ✅ = Exists and wired
- 🔨 = Seele must create from scratch
- 🔗 = Exists but needs wiring by Anti-Gravity
- ❌ = Missing, blocks release track

### 3.2 Per-Mode Asset Matrix

#### Production Modes (12) — Must be complete for Internal Testing track

| Mode | .umap | BP_GameMode | Animations | SFX | UI Widget | ArenaSettings | VenueRegistry | Economy Wired |
|------|-------|-------------|------------|-----|-----------|---------------|---------------|---------------|
| basketball_h2h | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| basketball_dunk | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| basketball_3v3 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| karate_h2h | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| karate_endless | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| baseball | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| football | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| soccer | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| golf | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| tennis | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| volleyball | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| surfing | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

#### Staging Modes (4) — Must be complete for Open Beta track

| Mode | .umap | BP_GameMode | Animations | SFX | UI Widget | ArenaSettings | VenueRegistry | Economy Wired |
|------|-------|-------------|------------|-----|-----------|---------------|---------------|---------------|
| skateboarding | 🔨 Skate_Park.umap | 🔨 BP_Skateboarding | 🔨 | 🔨 | 🔨 | ✅ (wired) | ✅ (wired) | 🔨 PRQ weight TBD |
| snowboarding | 🔨 Mountain_Slope.umap | 🔨 BP_Snowboarding | 🔨 | 🔨 | 🔨 | ✅ (wired) | ✅ (wired) | 🔨 PRQ weight TBD |
| gymnastics | 🔨 TrainingFloor needs gym assets | 🔨 BP_Gymnastics | 🔨 | 🔨 | 🔨 | ✅ (wired) | ✅ (wired) | 🔨 PRQ weight TBD |
| brain_brawl | ✅ NeuroArena | 🔗 exists but non-standard | 🔨 quiz animations | 🔨 | 🔨 | ✅ (wired) | ✅ (wired) | 🔨 standardize receipt |

#### Preview Modes (2) — Must be complete for Production track

| Mode | .umap | BP_GameMode | Animations | SFX | UI Widget | ArenaSettings | VenueRegistry | Economy Wired |
|------|-------|-------------|------------|-----|-----------|---------------|---------------|---------------|
| who_scene_it | ✅ NeuroArena (shared) | 🔨 BP_WhoSceneIt | 🔨 | 🔨 | 🔨 | ✅ (wired) | ✅ (wired) | 🔨 session receipt |
| court_carnival | ✅ VeniceBeach (shared) | 🔨 BP_CourtCarnival | 🔨 | 🔨 | 🔨 | ✅ (wired) | ✅ (wired) | 🔨 mini-game framework |

#### Non-Game Module (1)

| Mode | .umap | BP_Module | UI Widget | Backend |
|------|-------|-----------|-----------|---------|
| market_browse | 🔨 Luma_Venice_Shop.umap | 🔨 BP_MarketBrowse | 🔨 shop UI + card browser | 🔨 `/api/market/*` endpoints |

### 3.3 Global Assets (Seele Creates)

| Asset Category | Items | Priority |
|----------------|-------|----------|
| **Character Rigs** | Base athlete mesh + sport-specific skeleton variants (12 sports) | P0 |
| **Creator Card Renders** | 3D card model + holographic shader + pack-open animation | P0 |
| **Venue Skyboxes** | Per-venue HDRi skybox (Venice Beach, Dojo, Gridiron, etc.) | P0 |
| **HUD/UI Kit** | Score overlay, timer, PRQ meter, shard counter, XP bar | P0 |
| **Audio Bank** | Per-sport ambient + crowd + impact SFX (12 sports × ~20 clips) | P1 |
| **Loading Screens** | Per-venue loading art (12 venues) | P1 |
| **Tutorial Sequences** | First-time-user onboarding per mode (gesture hints) | P1 |
| **Store Assets** | Google Play screenshots (8), feature graphic (1024×500), icon (512×512) | P0 for launch |

### 3.4 Seele Asset Naming Convention

```
Content/FEL/
├── Venues/
│   ├── {VenueName}/
│   │   ├── {VenueName}.umap          # Level map
│   │   ├── BP_{ModeName}.uasset      # Game mode Blueprint
│   │   ├── M_{VenueName}_Floor.uasset # Material
│   │   └── T_{VenueName}_*.uasset    # Textures
│   └── ...
├── Characters/
│   ├── SK_Athlete_Base.uasset        # Base skeleton
│   ├── ABP_{Sport}.uasset            # Animation Blueprint per sport
│   └── AM_{Sport}_{Action}.uasset    # Animation Montage
├── UI/
│   ├── WBP_HUD_Main.uasset          # Main HUD widget
│   ├── WBP_ScoreOverlay.uasset       # Score display
│   └── WBP_CreatorCard.uasset        # Card viewer
├── Audio/
│   ├── SFX_{Sport}_{Action}.uasset   # Sport-specific SFX
│   └── AMB_{Venue}.uasset            # Venue ambient loop
└── Config/
    └── ArenaSettings.json             # Already wired
```

---

## 4. ECONOMY SYSTEM IMPLEMENTATION

### 4.1 Architecture (Already Implemented in server.py)

```
Session End → _compute_prq_delta() → _compute_shard_reward() → Session Receipt
                    │                         │
                    ▼                         ▼
              PRQ.modeReward()          Shard Ledger
              (Firestore)               (MongoDB: shard_ledger)
```

### 4.2 PRQ Delta Formula

```python
PRQ_MODE_WEIGHTS = {
    "basketball_h2h": 1.2,  "basketball_dunk": 1.0,  "basketball_3v3": 1.3,
    "karate_h2h": 1.4,      "karate_endless": 1.4,   "baseball": 1.1,
    "football": 1.5,         "soccer": 1.1,           "golf": 0.9,
    "tennis": 1.1,           "volleyball": 1.2,       "surfing": 1.05,
}

def _compute_prq_delta(mode, score, duration_s, outcome):
    base = score * 0.1
    time_factor = min(duration_s / 300, 1.0)   # cap at 5 min
    outcome_mult = {"win": 1.5, "draw": 1.0, "loss": 0.7}[outcome]
    weight = PRQ_MODE_WEIGHTS.get(mode, 1.0)
    return round(base * time_factor * outcome_mult * weight, 2)
```

### 4.3 Shard Reward Table

| Outcome | Base Shards | Combo Bonus | Critical Hit Bonus |
|---------|-------------|-------------|-------------------|
| Win | 50 | +5 per combo | +10 if score > 90th percentile |
| Draw | 25 | +3 per combo | +5 if score > 90th percentile |
| Loss | 15 | +2 per combo | +3 if score > 90th percentile |

```python
def _compute_shard_reward(outcome, combo_count=0, is_critical=False):
    table = {"win": (50, 5, 10), "draw": (25, 3, 5), "loss": (15, 2, 3)}
    base, combo_bonus, crit_bonus = table.get(outcome, (15, 2, 3))
    total = base + (combo_count * combo_bonus)
    if is_critical:
        total += crit_bonus
    return total
```

### 4.4 Session Receipt Schema

```json
{
    "session_id": "uuid",
    "user_id": "string",
    "mode": "basketball_h2h",
    "score": 87,
    "outcome": "win",
    "duration_s": 240,
    "xp_earned": 45,
    "prq_delta": 15.12,
    "shards_earned": 55,
    "combo_count": 1,
    "is_critical": false,
    "timestamp": "ISO-8601"
}
```

### 4.5 XP System

| Parameter | Value |
|-----------|-------|
| XP per session formula | `max(10, score / 5)` |
| XP cap per session | **500** (`XP_CAP_PER_SESSION = 500`) |
| XP cap prevents | Exploit via AFK/idle farming |

### 4.6 Creator Card Economy

| Item | Acquisition | Shard Cost |
|------|-------------|------------|
| Common Card | Gameplay drop (10% per session) | 100 shards |
| Rare Card | Gameplay drop (2% per session) | 500 shards |
| Epic Card | Pack purchase only | 2000 shards / $4.99 |
| Legendary Card | Tournament reward / limited event | Non-purchasable |

### 4.7 Coach Escrow System (Future — Seele Implements)

```
Player deposits shards → Escrow hold → AI Coach session → 
  If coaching completed: shards transfer to coach pool
  If session abandoned: shards refund to player (minus 10% fee)
```

### 4.8 Staging/Preview Mode Economy Rules

- **Staging modes** (skateboarding, snowboarding, gymnastics, brain_brawl): Economy DISABLED. No shards, no PRQ, no session receipts. XP only for testing.
- **Preview modes** (who_scene_it, court_carnival): Economy DISABLED until promoted to production.
- **market_browse**: No economy. It's a shop browser module.

---

## 5. BUILD PIPELINE & CI/CD

### 5.1 Pipeline Overview

```
git push → GitHub Actions → Validate → UE5 Cook → Package AAB → Sign → Upload to Play Console
              │                │            │           │          │         │
              ▼                ▼            ▼           ▼          ▼         ▼
         Trigger on      smoke_test    Cook Android   Bundle    Play App   Internal
         anti-gravity-   economy_test  content for    .aab      Signing    track
         fel push        validate_*    arm64+ASTC     artifact  (upload    deploy
                                                                 key)
```

### 5.2 Validation Scripts (Already Created)

| Script | Tests | Purpose |
|--------|-------|---------|
| `scripts/smoke_test_modes.py` | 147 | Registry alignment across all 6 files |
| `scripts/test_economy_transactions.py` | 33 | PRQ delta, shard rewards, XP cap |
| `scripts/validate_cooked_payload.py` | ~15 | Map presence, ArenaSettings completeness |
| `scripts/validate_ios_descriptor.py` | ~10 | Swift enum coverage, Registry→Swift mapping |

**Pre-push gate:** ALL scripts must pass with 0 failures before any push to `anti-gravity-fel`.

### 5.3 GitHub Actions Workflow (Seele Creates)

```yaml
# .github/workflows/fel-build-validate.yml
name: FEL Build & Validate
on:
  push:
    branches: [anti-gravity-fel]
  pull_request:
    branches: [anti-gravity-fel]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Run smoke tests
        run: python scripts/smoke_test_modes.py
      - name: Run economy tests
        run: python scripts/test_economy_transactions.py
      - name: Validate cooked payload
        run: python scripts/validate_cooked_payload.py
      - name: Validate iOS descriptor
        run: python scripts/validate_ios_descriptor.py

  build-aab:
    needs: validate
    runs-on: ubuntu-latest  # or self-hosted with UE5 + Android SDK
    steps:
      - uses: actions/checkout@v4
      - name: Setup UE5.7 + Android SDK
        run: echo "Configure UE5 build tools + Android NDK r25c"
      - name: Cook Android content
        run: |
          UnrealBuildTool -project=FinalEvolutionLab.uproject \
            -platform=Android -configuration=Shipping \
            -cook -stage -pak -compressed
      - name: Bundle AAB
        run: ./gradlew bundleRelease
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: fel-release-aab
          path: app/build/outputs/bundle/release/app-release.aab

  deploy-internal:
    needs: build-aab
    if: github.ref == 'refs/heads/anti-gravity-fel'
    runs-on: ubuntu-latest
    steps:
      - name: Download AAB
        uses: actions/download-artifact@v4
        with:
          name: fel-release-aab
      - name: Upload to Play Console (Internal)
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT }}
          packageName: com.antigravity.finalevolutionlab
          releaseFiles: app-release.aab
          track: internal
```

### 5.4 UE5 Cook Command (Android/Google Play)

```bash
# Cook for Android (arm64 + ASTC textures)
RunUAT BuildCookRun \
  -project=/path/to/FinalEvolutionLab.uproject \
  -platform=Android \
  -clientconfig=Shipping \
  -cook -stage -pak -compressed \
  -cookflavor=ASTC \
  -architecture=arm64 \
  -distribution \
  -nodebuginfo

# Maps to cook (from DefaultGame.ini [EmergentPlayMap])
+MapsToCook=(FilePath="/Game/FEL/Venues/VeniceBeach/VeniceBeach")
+MapsToCook=(FilePath="/Game/FEL/Venues/Dojo/Dojo")
+MapsToCook=(FilePath="/Game/FEL/Venues/BaseballPark/BaseballPark")
+MapsToCook=(FilePath="/Game/FEL/Venues/Gridiron/Gridiron")
+MapsToCook=(FilePath="/Game/FEL/Venues/SoccerStadium/SoccerStadium")
+MapsToCook=(FilePath="/Game/FEL/Venues/Links/Links")
+MapsToCook=(FilePath="/Game/FEL/Venues/TennisCourt/TennisCourt")
+MapsToCook=(FilePath="/Game/FEL/Venues/SandCourt/SandCourt")
+MapsToCook=(FilePath="/Game/FEL/Venues/SkatePark/SkatePark")
+MapsToCook=(FilePath="/Game/FEL/Venues/MountainSlope/MountainSlope")
+MapsToCook=(FilePath="/Game/FEL/Venues/TrainingFloor/TrainingFloor")
+MapsToCook=(FilePath="/Game/FEL/Venues/NeuroArena/NeuroArena")
+MapsToCook=(FilePath="/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop")
```

### 5.5 Signing & Upload

```bash
# Generate upload keystore (one-time)
keytool -genkeypair -v -keystore fel-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias fel-release-key \
  -dname "CN=Antigravity, OU=FEL, O=Antigravity, L=Venice Beach, ST=CA, C=US"

# Sign AAB
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore fel-upload.jks app-release.aab fel-release-key

# Upload via bundletool for local testing
bundletool build-apks --bundle=app-release.aab --output=fel.apks \
  --ks=fel-upload.jks --ks-key-alias=fel-release-key
bundletool install-apks --apks=fel.apks
```

---

## 6. SEELE-SPECIFIC DIRECTIVES

### 6.1 Execution Philosophy

```
ANALYZE → CREATE → INTEGRATE → VALIDATE → REPEAT
```

Seele operates as an autonomous creator agent. These directives govern behavior:

### 6.2 Hard Rules

| # | Rule | Consequence of Violation |
|---|------|------------------------|
| 1 | **Never invent venue names or map paths.** Use `DefaultGame.ini [EmergentPlayMap]` as truth. | Routing crash at runtime |
| 2 | **Cooked path format: `/Game/FEL/Venues/{VenueName}/{VenueName}`.** No `/Maps/` prefix. | Asset not found crash |
| 3 | **`karate` is alias for `karate_h2h`.** Never expose as separate mode. | Duplicate mode in UI |
| 4 | **`market_browse` is NOT a game mode.** No session receipt, no PRQ, no shards. | Economy corruption |
| 5 | **Preview modes (`who_scene_it`, `court_carnival`) stay preview** until gameplay contracts + session receipts complete. | Broken production flow |
| 6 | **All 6 registries must be updated atomically** when adding/modifying a mode. | Registry desync = crash |
| 7 | **UE 5.7 is the native host.** No Unity, no SwiftUI-first, no Unreal-as-Library. | Architecture violation |
| 8 | **XP_CAP_PER_SESSION = 500.** Never remove or increase without economy review. | XP farming exploit |
| 9 | **Run all 4 validation scripts after every change.** Zero failures required. | Silent regression |
| 10 | **Branch naming: `seele/<feature-name>`.** Never commit directly to `anti-gravity-fel`. | Unreviewed changes |

### 6.3 Seele Analysis Phase Protocol

Before creating ANY asset, Seele MUST:

1. **Read all 6 registry files** to understand current state
2. **Read `designs/fel_seele_10_phase_execution_directive.md`** for quality gates
3. **Read `designs/fel_per_game_mode_blueprint_design.md`** for mode specifications
4. **Read `designs/fel_master_architecture_blueprint_design.md`** for system architecture
5. **Identify the closest existing mode** that mirrors the target (for pattern copying)
6. **List all files that will be created/modified** before writing any code
7. **Verify no naming conflicts** with existing assets

### 6.4 Seele Creation Phase Protocol

For each new asset:

1. **Copy the mirror template** from the closest existing mode
2. **Rename all internal references** (class names, asset paths, mode IDs)
3. **Adapt gameplay parameters** per the mode blueprint design doc
4. **Create placeholder content** that compiles and runs (even if visually basic)
5. **Wire into all 6 registries** in the same commit
6. **Add ArenaSettings entry** with sport-specific params (targetScore, timeLimit, physics)
7. **Add VenueRegistry entry** with spawn points, audio config, lighting preset

### 6.5 Seele Validation Phase Protocol

After EVERY creation pass:

```bash
# Mandatory validation suite
python3 scripts/smoke_test_modes.py          # Must: 0 failures
python3 scripts/test_economy_transactions.py # Must: 0 failures
python3 scripts/validate_cooked_payload.py   # Must: 0 failures
python3 scripts/validate_ios_descriptor.py   # Must: 0 failures

# Additional checks
python3 -m json.tool backend/FEL_ModeManager.production.json > /dev/null  # JSON valid
python3 -m json.tool backend/ue_mode_maps.json > /dev/null                # JSON valid
python3 -c "import ast; ast.parse(open('backend/server.py').read())"      # Python valid
swiftc -typecheck FinalEvolutionLab/Models/GameMode.swift 2>&1 || true    # Swift check
```

### 6.6 Seele Integration Handoff

When Seele completes a feature branch:

```
1. Push seele/<feature> branch
2. Open PR targeting anti-gravity-fel
3. PR description MUST include:
   - [ ] Files created (full paths)
   - [ ] Registries updated (which of the 6)
   - [ ] Validation results (paste test output)
   - [ ] Mode status (production/staging/preview)
   - [ ] Screenshot/recording of mode running (if UE assets)
4. Anti-Gravity reviews + merges
5. Anti-Gravity runs full validation suite post-merge
```

---

## 7. PHASE-BY-PHASE EXECUTION PLAN

### Phase 0: Foundation (✅ COMPLETE)
**Duration:** Done  
**Owner:** Anti-Gravity

| Deliverable | Status |
|-------------|--------|
| Repository structure established | ✅ |
| 6 registry files created and aligned | ✅ |
| 12 production modes registered | ✅ |
| 4 staging modes registered | ✅ |
| 2 preview modes registered | ✅ |
| 1 non-game module registered | ✅ |
| Economy system (PRQ + shards + XP) in server.py | ✅ |
| Validation suite (4 scripts, 180+ tests) | ✅ |
| Google Play distribution config | ✅ |
| All P0 registry fixes applied | ✅ |

**Quality Gate:** 147 smoke tests + 33 economy tests = **0 failures** ✅

---

### Phase 1: Core Asset Creation (Seele)
**Duration:** 2–3 weeks  
**Owner:** Seele AI  
**Branch:** `seele/core-assets`

| Task | Mode(s) | Deliverables |
|------|---------|-------------|
| 1.1 Audit existing UE assets | All 12 production | Inventory report: which .umaps exist, which need creation |
| 1.2 Create missing venue maps | Any production mode without .umap | `.umap` files in `Content/FEL/Venues/` |
| 1.3 Create game mode Blueprints | All 12 production | `BP_<ModeName>.uasset` per mode |
| 1.4 Character animation sets | 12 sports | `ABP_<Sport>.uasset` + `AM_<Sport>_<Action>.uasset` |
| 1.5 HUD/UI widgets | Global | `WBP_HUD_Main`, `WBP_ScoreOverlay`, `WBP_CreatorCard` |
| 1.6 Audio bank | 12 sports + 12 venues | `SFX_*` + `AMB_*` assets |

**Quality Gate:**
- [ ] All 12 production modes launch in UE5 PIE (Play In Editor)
- [ ] No missing asset warnings in UE5 output log
- [ ] All 4 validation scripts: 0 failures
- [ ] Each mode plays for 60s without crash

**Rollback:** `git revert` the merge commit → return to Phase 0 state

---

### Phase 2: Economy Wiring (Anti-Gravity + Seele)
**Duration:** 1 week  
**Owner:** Anti-Gravity (backend) + Seele (frontend)

| Task | Deliverables |
|------|-------------|
| 2.1 Wire PRQ computation into UE HUD | PRQ delta shown in post-game screen |
| 2.2 Wire shard rewards into UE HUD | Shard count animated in post-game screen |
| 2.3 Creator Card drop system | Card drop animation + inventory storage |
| 2.4 IAP integration (Google Play Billing) | Shard pack purchase flow, subscription handling |
| 2.5 Shard ledger read API | `/api/economy/balance` → shows shards, cards, PRQ |

**Quality Gate:**
- [ ] Play basketball_h2h → win → see PRQ delta + shards in receipt
- [ ] Purchase `fel_shard_pack_100` → balance increases by 100
- [ ] XP cap enforced (score 10000 → only 500 XP awarded)
- [ ] 33 economy unit tests: 0 failures

**Rollback:** Disable economy display in HUD via Firebase Remote Config flag

---

### Phase 3: Staging Mode Build-Out (Seele)
**Duration:** 2–3 weeks  
**Owner:** Seele AI  
**Branch:** `seele/staging-modes`

| Task | Mode | Key Challenge |
|------|------|--------------|
| 3.1 Skateboarding | skateboarding | Create `Skate_Park.umap` from scratch, trick system |
| 3.2 Snowboarding | snowboarding | Create `Mountain_Slope.umap`, downhill physics |
| 3.3 Gymnastics | gymnastics | Extend `TrainingFloor.umap` with gym apparatus |
| 3.4 Brain Brawl standardization | brain_brawl | Migrate from custom `/api/brain-brawl/submit` to standard session receipt |

**Quality Gate:**
- [ ] All 4 staging modes launch in UE5 PIE
- [ ] skateboarding routes to SkatePark (not VeniceBeach)
- [ ] snowboarding routes to MountainSlope (not VeniceBeach)
- [ ] brain_brawl uses standard `/api/games/session` endpoint
- [ ] Smoke tests updated for staging mode economy (disabled)

**Rollback:** Staging modes remain in on-demand asset pack, not exposed in production UI

---

### Phase 4: Preview Mode Prototyping (Seele)
**Duration:** 2 weeks  
**Owner:** Seele AI  
**Branch:** `seele/preview-modes`

| Task | Mode | Key Challenge |
|------|------|--------------|
| 4.1 Who Scene It gameplay | who_scene_it | Scene recognition game loop, multimedia pipeline, question DB |
| 4.2 Court Carnival mini-games | court_carnival | Mini-game framework, board state machine, 4-player party logic |
| 4.3 Market Browse module | market_browse | 3D shop environment, Creator Card browser, purchase flow |

**Quality Gate:**
- [ ] who_scene_it: Load 5 questions, play through, score displayed
- [ ] court_carnival: Load board, play 1 mini-game, return to board
- [ ] market_browse: Browse cards, view 3D card model, initiate purchase
- [ ] Preview modes remain status "preview" (not promoted)

**Rollback:** Preview modes disabled via Firebase Remote Config

---

### Phase 5: Google Play Internal Testing (Anti-Gravity)
**Duration:** 1 week  
**Owner:** Anti-Gravity

| Task | Deliverables |
|------|-------------|
| 5.1 Cook Android AAB | `app-release.aab` with all production venues |
| 5.2 Configure Play Console | Package, listing, content rating, privacy policy |
| 5.3 Upload to Internal track | AAB + store assets (screenshots, feature graphic) |
| 5.4 Internal team testing | Seele team plays all 12 production modes |
| 5.5 Crash/ANR triage | Fix any Crashlytics issues |

**Quality Gate:**
- [ ] AAB installs and launches on Pixel 7+ and Samsung S23+
- [ ] All 12 production modes playable end-to-end
- [ ] Crash rate < 2% over 48 hours
- [ ] ANR rate < 0.5%
- [ ] Store listing preview approved

**Rollback:** Revoke internal testing access, revert to previous AAB

---

### Phase 6: Closed Alpha (Anti-Gravity)
**Duration:** 2 weeks  
**Owner:** Anti-Gravity

| Task | Deliverables |
|------|-------------|
| 6.1 Promote to Closed Alpha track | 100 testers (Venice Beach beta group) |
| 6.2 Feedback collection | In-app feedback form + Discord channel |
| 6.3 Economy balance testing | Verify shard earn rate vs spend rate |
| 6.4 Performance profiling | GPU/CPU frame times, memory leaks |
| 6.5 Bug triage + hotfixes | Critical fix → rebuild → re-upload |

**Quality Gate:**
- [ ] 100 testers active for 7+ days
- [ ] Median session length > 5 minutes
- [ ] Shard economy: earn/spend ratio between 0.8–1.2
- [ ] No P0 bugs open
- [ ] Crash rate < 1%

---

### Phase 7: Open Beta (Anti-Gravity)
**Duration:** 14 days (mandatory soak)  
**Owner:** Anti-Gravity

| Task | Deliverables |
|------|-------------|
| 7.1 Promote to Open Beta | Public access |
| 7.2 Include staging modes | On-demand asset pack download |
| 7.3 A/B test economy params | Firebase Remote Config experiments |
| 7.4 Localization | en-US + es + pt-BR + ja + ko |
| 7.5 Accessibility audit | TalkBack support, color contrast, touch targets |

**Quality Gate:**
- [ ] 14-day soak period complete
- [ ] ANR rate < 0.47% (Play Console threshold)
- [ ] Crash rate < 1.09% (Play Console threshold)
- [ ] Vitals: startup time < 5s, frame render < 32ms (95th %ile)
- [ ] No P0 or P1 bugs open

---

### Phase 8: Production Launch (Anti-Gravity)
**Duration:** 1 week staged rollout  
**Owner:** Anti-Gravity

| Task | Deliverables |
|------|-------------|
| 8.1 Promote to Production track | 10% staged rollout |
| 8.2 Monitor vitals | Real-time Crashlytics + Play Console dashboards |
| 8.3 Expand rollout | 10% → 25% → 50% → 100% over 7 days |
| 8.4 Post-launch hotfix pipeline | Same-day AAB rebuild if P0 found |

**Quality Gate:**
- [ ] 10% rollout: crash rate < 1% for 24h → expand
- [ ] 50% rollout: no new P0 bugs for 48h → expand
- [ ] 100% rollout: store rating > 4.0 after 100+ reviews

**Rollback:** Staged rollout halt → revert to previous AAB version in Play Console

---

### Phase 9: Post-Launch Evolution (Seele + Anti-Gravity)
**Duration:** Ongoing  
**Owner:** Both

| Task | Deliverables |
|------|-------------|
| 9.1 Promote staging → production | skateboarding, snowboarding, gymnastics, brain_brawl |
| 9.2 Promote preview → staging | who_scene_it, court_carnival |
| 9.3 New mode development | Seele creates on `seele/<mode-name>` branches |
| 9.4 Seasonal events | Tournament modes, limited-time Creator Cards |
| 9.5 Coach escrow launch | AI coaching with shard escrow system |
| 9.6 market_browse polish | Full 3D shop with card trading |

---

## APPENDIX A: QUICK REFERENCE — KEY COMMANDS

```bash
# Validate everything
cd /path/to/Final-Evolution-Lab
python3 scripts/smoke_test_modes.py
python3 scripts/test_economy_transactions.py
python3 scripts/validate_cooked_payload.py
python3 scripts/validate_ios_descriptor.py

# Check JSON validity
python3 -m json.tool backend/FEL_ModeManager.production.json > /dev/null
python3 -m json.tool backend/ue_mode_maps.json > /dev/null

# Git workflow (Seele)
git checkout anti-gravity-fel && git pull
git checkout -b seele/<feature-name>
# ... make changes ...
git add -A && git commit -m "seele: <description>"
git push origin seele/<feature-name>
# → Open PR targeting anti-gravity-fel

# Build AAB
./gradlew bundleRelease
```

## APPENDIX B: FILE INDEX

| File | Lines | Purpose |
|------|-------|---------|
| `backend/FEL_ModeManager.production.json` | ~200 | Master mode registry |
| `backend/ue_mode_maps.json` | ~50 | Mode→UE map token |
| `backend/server.py` | ~2400 | FastAPI backend (economy, sessions, matchmaking) |
| `FinalEvolutionLab/Models/GameMode.swift` | ~150 | iOS mode enum + UI metadata |
| `infra/ue5_config/DefaultGame.ini` | ~100 | UE5 config (EmergentPlayMap, MapsToCook) |
| `UnrealStarter/.../ArenaSettings.json` | ~300 | Per-mode gameplay parameters |
| `UnrealStarter/.../FEL_VenueRegistry.production.json` | ~200 | Venue metadata |
| `infra/distribution/google_play_distribution.json` | ~80 | Google Play Store config |
| `scripts/smoke_test_modes.py` | ~260 | 147 registry alignment tests |
| `scripts/test_economy_transactions.py` | ~150 | 33 economy unit tests |
| `scripts/validate_cooked_payload.py` | ~100 | Build artifact validation |
| `scripts/validate_ios_descriptor.py` | ~80 | Swift↔Registry mapping validation |

## APPENDIX C: CONTACTS & ENDPOINTS

| System | Endpoint |
|--------|----------|
| Backend API | `https://api.antigravity.io/fel/v1` |
| Sovereign Hub (WebSocket) | `wss://readiness-stack.preview.emergentagent.com/ws/sovereign` |
| Analytics | `https://analytics.antigravity.io/fel` |
| Crash Reporting | Firebase Crashlytics |
| Remote Config | Firebase Remote Config |
| Play Console | `https://play.google.com/console` |

---

*Generated by Anti-Gravity for Seele AI autonomous execution.*  
*Last updated: 2026-05-22 · Branch: anti-gravity-fel*
