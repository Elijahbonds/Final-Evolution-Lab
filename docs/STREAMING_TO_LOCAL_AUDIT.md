# Streaming → Local Build Audit Report

**Generated:** 2026-05-23  
**Scope:** Full codebase audit of Final Evolution Lab to identify cloud-streaming dependencies and document the changes required for a native local-build (IPA/APK) architecture.  
**Branch context:** `anti-gravity-fel`  
**Test baseline:** 180 tests passing (147 smoke + 33 economy) — must remain green.

---

## Executive Summary

### Verdict: LOW-TO-MODERATE migration effort

The codebase is **already predominantly architected for local/native builds**. Eagle 3D Streaming (E3DS) cloud GPU infrastructure exists as an **optional overlay** — the backend explicitly defaults to `cloud_streaming: False, e3ds_disabled: True` (Local Sovereign Mode). The iOS build script (`fel_ue5_ios_shipping_package.sh`) already cooks, stages, and archives native `.ipa` bundles. The Swift `UnrealManager` loads UE as an **embedded framework** (`UnrealFramework.framework`), not via pixel streaming.

The primary work is **removing vestigial E3DS code paths**, **cleaning Pixel Streaming 2 config from DefaultEngine.ini**, and **updating the frontend to remove the iframe/E3DS streaming UI** in favor of pure download distribution.

---

## 1. Architecture Overview

### Current Hybrid Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FINAL EVOLUTION LAB                       │
│                                                             │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │  Swift    │←──→│  FastAPI      │←──→│  MongoDB         │  │
│  │  iOS App  │    │  Backend      │    │  (sessions, PRQ, │  │
│  │           │    │  :8888        │    │   shards, users) │  │
│  └────┬─────┘    └──────┬───────┘    └──────────────────┘  │
│       │                 │                                    │
│       │  ┌──────────────┤                                    │
│       │  │              │                                    │
│       ▼  ▼              ▼                                    │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │  UE 5.7  │    │  Sovereign   │    │  React Frontend  │  │
│  │  Embedded│←──→│  WebSocket   │    │  (Web Dashboard)  │  │
│  │  Fwk     │    │  /ws/sov     │    │                   │  │
│  └──────────┘    └──────────────┘    └──────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ★ OPTIONAL (NOT ACTIVE BY DEFAULT) ★                │  │
│  │  E3DS Pixel Streaming 2 — Linux cloud GPU            │  │
│  │  infra/e3ds/, deploy_e3ds.sh, Pulumi IaC             │  │
│  │  DefaultEngine.ini: NVENC, WebRTC, SFU/Simulcast     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Key Finding: Two Parallel Rendering Paths

| Path | Status | How It Works |
|---|---|---|
| **Local Native (Sovereign)** | ✅ Active by default | UE5 compiled as `UnrealFramework.framework`, embedded in iOS `.app` bundle. Swift `UnrealManager` loads via `NSBundle.loadAndReturnError()`. Renders natively on device GPU (Metal). |
| **Cloud Streaming (E3DS)** | ❌ Disabled by default | Linux Pixel Streaming 2 binary deployed to E3DS cloud GPUs (RTX 4080/3070). Video streamed via WebRTC to iframe in React frontend. Requires `E3DS_API_KEY` + Pulumi deploy. |

---

## 2. iOS Swift App — Unreal Integration (LOCAL, No Streaming)

### Files Examined

| File | Purpose | Streaming Dependency |
|---|---|---|
| `FinalEvolutionLab/Services/UnrealManager.swift` | Embedded UE framework manager | **NONE** — loads `UnrealFramework.framework` from app bundle |
| `FinalEvolutionLab/Views/UnrealContainerView.swift` | SwiftUI wrapper for UE rendering surface | **NONE** — `UIViewControllerRepresentable` with native `UIView` |
| `FinalEvolutionLab/Views/GameSceneHostView.swift` | SceneKit fallback for game scenes | **NONE** — `SCNView` local rendering |
| `FinalEvolutionLab/Views/GameModeSelectionView.swift` | Game mode launcher | **NONE** — uses `UnrealManager.shared.isUnrealActive` |
| `FinalEvolutionLab/FinalEvolutionLabApp.swift` | App entry point | **NONE** — calls `UnrealManager.shared.startFirebaseIdentityObservation()` |
| `FinalEvolutionLab/Services/SystemScanFirestoreSync.swift` | Scan data → Firestore + UE bridge | **NONE** — calls `UnrealManager.shared.deliverSystemScanJSON()` |

### How Unreal Integration Works (Already Local)

```
UnrealManager.swift (line 111-172):
  1. Probes for UnrealFramework.framework in app Frameworks/
  2. Bundle(url:).loadAndReturnError() — loads native Mach-O
  3. principalClass.getInstance() → UE host object
  4. host.runEmbedded() — starts UE rendering loop
  5. host.rootView() → UIView added to UnrealHostViewController
```

**The Swift → UE bridge uses Objective-C selectors**, not WebRTC/WebSocket:
- `receiveSystemScanJSON:` — scan data into UE
- `receiveFirebaseBridgeJSON:` — auth identity into UE
- `receiveBodyIQJSON:` — Movement Lab snacks into UE

### ✅ Verdict: iOS Swift app requires ZERO changes for local builds

The entire Swift layer is already designed for embedded native rendering. No pixel streaming, iframe, or cloud GPU references exist in the iOS codebase.

---

## 3. Backend API — Streaming Endpoints

### Files Examined

| File | Lines | Purpose |
|---|---|---|
| `backend/server.py` | 2620 total | FastAPI application |
| `backend/core.py` | ~100 | Auth dependencies |
| `backend/requirements.txt` | — | Python dependencies |

### Streaming-Related Endpoints (3 endpoints)

| Endpoint | Method | Location | What It Does | Action |
|---|---|---|---|---|
| `/api/streaming/status` | GET | `server.py:1294` | Returns `cloud_streaming: False, e3ds_disabled: True` | **KEEP** — already reports local mode; refactor to remove E3DS references |
| `/api/streaming/connect` | POST | `server.py:1324` | Returns `status: local_sovereign` — no cloud URL | **KEEP** — rename to `/api/sovereign/connect` |
| `/api/streaming/launch-mode` | POST | `server.py:1329` | Launches UE5 via deep link + creates live session | **KEEP** — this is the native launch path (deep links, not streaming) |

### Streaming-Free Endpoints (PRESERVE ALL)

The vast majority of `server.py` (2600+ lines) has **zero streaming dependency**:

- `/api/auth/*` — OAuth session management (Emergent backend)
- `/api/games/session` — PRQ delta, shard rewards, XP calculation
- `/api/prq/*` — PRQ metrics and history
- `/api/stats/*` — Statistics overview
- `/api/creator-cards/*` — Creator card economy
- `/api/coach/*` — Coach marketplace
- `/api/brain-brawl/*` — Trivia sessions
- `/ws/sovereign` — WebSocket bridge for UE telemetry (this is LOCAL, not cloud)

### Backend Economy System (NO STREAMING DEPENDENCY)

```python
# server.py:530-599 — All calculations are local/stateless
PRQ_MODE_WEIGHTS = { ... }           # 15 modes, all local
_compute_prq_delta(mode_id, ...)     # Pure math, no cloud call
_compute_shard_reward(outcome, ...)   # Pure math, no cloud call
XP_CAP_PER_SESSION = 500             # Local constant
```

### E3DS References in Backend (TO REMOVE/CLEAN)

```python
# server.py:1313-1314  — Hardcoded but already False
"cloud_streaming": False,
"e3ds_disabled": True,

# server.py:1768 — E3DS commands object in production health
"e3ds_commands": { ... }

# server.py:2485 — Boot log entry
"Cloud streaming: DISABLED (E3DS bypassed)"
```

### SovereignBridge WebSocket (`/ws/sovereign`)

This is **NOT a streaming dependency** — it's a bidirectional telemetry bridge:
- UE5 → Backend: match scores, telemetry, hardware auth
- Backend → UE5: session config, mode launch broadcasts
- Encrypted with AES-256-GCM
- Falls back to `'fel-sovereign'` key when `E3DS_API_KEY` absent

**KEEP** — this WebSocket channel is used by native local builds for real-time data sync.

### ✅ Backend Verdict: Minor cleanup of 3 streaming endpoints + remove E3DS string references

---

## 4. Build Scripts — iOS and Cloud Paths

### Build Script Inventory

| Script | Platform | Type | Streaming? | Action |
|---|---|---|---|---|
| `fel_ue5_ios_shipping_package.sh` (826 lines) | iOS | **Native IPA** | ❌ No | **KEEP** — this IS the local build path |
| `fel_ue5_eagle3d_linux_package.sh` (316 lines) | Linux | **E3DS Cloud** | ✅ Yes | **DEPRECATE** — cloud streaming only |
| `fel_ue5_win64_cook_only.sh` | Win64 | Content factory | Partial | **KEEP** — useful for Win64 local builds |
| `prepare_fel_full_ship.sh` | All | Config merge | ❌ No | **KEEP** |
| `prepare_fel_emergent.sh` | All | Emergent bridge | ❌ No | **KEEP** — bridges Swift↔UE, not streaming |

### iOS Build Script Analysis (`fel_ue5_ios_shipping_package.sh`)

Already produces native local builds:

```bash
# Core RunUAT command (native cook + stage + archive):
RunUAT BuildCookRun \
  -project="$UPROJECT" \
  -platform=iOS \
  -clientconfig=$IOS_CLIENTCONFIG \
  -cook -allmaps -stage -archive \
  -pak -compressed
```

Produces:
- `.app` bundle with `cookeddata/` or `.pak` files embedded
- Optional `.ipa` via `xcodebuild -exportArchive`
- Descriptor-safe staging (promotes fully staged `.app` before archive)

**No Pixel Streaming flags in the iOS script.** ✅

### Linux E3DS Build Script (`fel_ue5_eagle3d_linux_package.sh`)

This is the ONLY build script tied to cloud streaming:

```bash
# E3DS-specific flags:
RunUAT BuildCookRun \
  -platform=Linux \
  -cook -stage -pak -archive \
  -compressed
# Then zips for E3DS Control Panel upload
```

Also bundles PixelStreaming WebServers.

**Recommend: Move to `infra/deprecated/` or add "DEPRECATED" header.**

---

## 5. Unreal Engine Configuration

### DefaultEngine.ini — REQUIRES MAJOR CLEANUP

**Location:** `infra/ue5_config/DefaultEngine.ini` (115 lines)  
**Current state:** Entirely configured for E3DS Pixel Streaming 2

```ini
; ═══════════════════════════════════════════════════════════════
; UE 5.7 Pixel Streaming 2 · Eagle 3D Streaming (E3DS) Compatible
; ═══════════════════════════════════════════════════════════════

[/Script/PixelStreamingServers.PixelStreamingServers]
bUseInternalSignalling=False        ; ← E3DS-specific

[PixelStreaming]
AllowPixelStreamingCommands=true    ; ← E3DS-specific
PixelStreamingIP=0.0.0.0           ; ← E3DS-specific
PixelStreamingPort=8888             ; ← E3DS-specific
Encoder.TargetBitrate=20000000      ; ← NVENC for RTX 4080
Encoder.RateControl=CBR             ; ← NVENC-specific
WebRTC.MaxFps=60                    ; ← WebRTC streaming
; ... (40+ lines of Pixel Streaming config)

[/Script/Engine.RendererSettings]
r.Lumen.HardwareRayTracing=1       ; ← RTX 4080 cloud GPU
r.Nanite.Enabled=1                  ; ← Cloud GPU capability
r.RayTracing=1                      ; ← Cloud GPU capability
```

#### Required Changes for Local Builds:

| Section | Action | Reason |
|---|---|---|
| `[/Script/PixelStreamingServers.*]` | **REMOVE** | No pixel streaming on device |
| `[PixelStreaming]` (all 30+ lines) | **REMOVE** | No NVENC/WebRTC on mobile |
| `[PixelStreamingPluginSettings]` | **REMOVE** | Plugin should not be enabled |
| `[/Script/PixelStreaming.PixelStreamingSettings]` | **REMOVE** | Simulcast/SFU not applicable |
| `[/Script/Engine.RendererSettings]` | **MODIFY** | Disable Lumen HW RT, Nanite for mobile; use Forward/mobile renderer |
| `[Audio] bEnableAudioStreaming=true` | **MODIFY** | Change to local audio output |
| `[/Script/EngineSettings.GameMapsSettings]` | **KEEP** | Map registry is platform-agnostic |
| `[/Script/Engine.GameEngine]` | **KEEP** | Travel commands used by deep links |

### DefaultGame.ini — MOSTLY CLEAN

**Location:** `infra/ue5_config/DefaultGame.ini`

Already contains native shipping config:
- `bCookAll=True`
- 13 `+MapsToCook` entries
- `[EmergentPlayMap]` registry (used by both local and streaming)
- `BuildConfiguration=PPBC_Shipping`

Minor items:
- `GameWebSocketUrl=wss://readiness-stack.preview.emergentagent.com/ws/sovereign` — **UPDATE** to production domain
- `bFocusKeepalive=True` + `KeepaliveInterval=0.5` — **REMOVE** (iframe focus-lock for E3DS only)

### Existing Local Sovereign Snippet

**`UnrealIntegration/Config/DefaultEngine.FEL_IOS_local_sovereign.snippet.ini`:**

```ini
[ConsoleVariables]
PixelStreaming.WebRTC.StartStreaming=0
PixelStreaming2.AutoStartStream=0
```

This snippet already exists to disable streaming on iOS! **Merge into main DefaultEngine.ini** as the default.

---

## 6. Frontend / Web Portal

### Files Examined

| File | Lines | Purpose |
|---|---|---|
| `frontend/src/App.js` | 1248 | Main React app — landing, dashboard, all views |
| `frontend/src/components/SovereignDashboard.js` | 227 | Sovereign Hub monitoring UI |
| `frontend/src/components/FELOSDashboard.js` | — | FEL OS dashboard |

### Streaming-Specific Frontend Code (TO MODIFY)

#### A. Pixel Streaming View (`App.js:1006-1130`)

```javascript
// ===================== PIXEL STREAMING =====================
const PixelStreamingView = () => {
  // E3DS iframe viewer, connect form, Pulumi deploy instructions
  // ~124 lines of pure streaming UI
};
```

**Action:** Replace with **Download Portal** — native IPA/APK distribution UI.

#### B. Sidebar Navigation (`App.js:199`)

```javascript
{id:'streaming', icon:Radio, label:'Pixel Stream'}
```

**Action:** Rename to `{id:'download', icon:Download, label:'Get App'}` or remove.

#### C. Route Switch (`App.js:1216`)

```javascript
case 'streaming': return <SovereignDashboard />;
```

**Action:** Route to download portal instead.

#### D. Game Mode Launch (`App.js:510`)

```javascript
const r = await axios.post(`${API}/streaming/launch-mode`, { mode_id: mode.id });
```

**Action:** Rename endpoint to `/api/sovereign/launch-mode` or `/api/games/launch`.

### Sovereign Dashboard (KEEP — NOT Streaming)

The `SovereignDashboard.js` monitors the **local WebSocket bridge** health:
- WebSocket connection status
- MongoDB readiness
- Telemetry data flow
- Creator card scanning

This is **not E3DS-dependent** — it monitors the native local backend.

---

## 7. Infrastructure / Deployment

### E3DS Infrastructure (TO DEPRECATE)

| Path | Type | Action |
|---|---|---|
| `infra/e3ds/__main__.py` (167 lines) | Pulumi IaC | **DEPRECATE** — cloud GPU provisioning |
| `infra/e3ds/Pulumi.yaml` | Pulumi config | **DEPRECATE** |
| `infra/e3ds/requirements.txt` | Python deps | **DEPRECATE** |
| `infra/deploy_e3ds.sh` (86 lines) | Deploy script | **DEPRECATE** |

### Distribution Config (KEEP + MODIFY)

| Path | Action | Notes |
|---|---|---|
| `infra/distribution/google_play_distribution.json` | **KEEP** | Already configured for AAB local distribution; asset packs (install-time) are correct |
| `infra/SHIPPING.md` | **KEEP** | Already documents native iOS shipping via TestFlight |
| `infra/ue5_config/ExportOptions.plist` | **KEEP** | Used by `--export-ipa` for App Store export |
| `infra/fix_ios_descriptor_path.sh` | **KEEP** | Validates `.app` contains cooked data |
| `infra/fel_prebuild_ci_check.sh` | **KEEP** | Pre-build validation |

### Google Play Distribution Config

`infra/distribution/google_play_distribution.json` already defines:
```json
{
  "aab_config": {
    "abi_filters": ["arm64-v8a"],
    "texture_compression": "ASTC",
    "split_apks": true,
    "asset_packs": {
      "venue_assets": {"delivery_mode": "install_time"},
      "staging_venues": {"delivery_mode": "on_demand"}
    }
  }
}
```

This is already correct for local native builds. ✅

---

## 8. Test Suite Impact

### Current Test Status

| Test Suite | Count | Status | Streaming Dependency |
|---|---|---|---|
| `scripts/smoke_test_modes.py` | 147 | ✅ All pass | **NONE** — tests JSON/INI/Swift registry alignment |
| `scripts/test_economy_transactions.py` | 33 | ✅ All pass | **NONE** — tests PRQ/shard/XP math |
| `scripts/validate_ios_descriptor.py` | — | Standalone | **NONE** — validates native iOS packaging config |
| `scripts/validate_cooked_payload.py` | — | Standalone | **NONE** — validates cooked content directories |

### ✅ All 180 tests are streaming-agnostic and will remain green after migration.

No tests reference E3DS, Pixel Streaming, iframe URLs, or cloud GPU instances. They validate:
- Mode registry consistency across JSON/INI/Swift/Python
- Economy formula correctness (PRQ delta, shards, XP cap)
- iOS build descriptor safety
- Cooked payload completeness

---

## 9. Complete Change Manifest

### Priority 0 — Must Change (Production Blockers)

| # | File | Change | Effort | Risk |
|---|---|---|---|---|
| P0-1 | `infra/ue5_config/DefaultEngine.ini` | **Replace** entire file with mobile/native renderer config. Remove all Pixel Streaming 2, NVENC, WebRTC, SFU, iframe sections. Set mobile-appropriate renderer settings (Forward shading, no Lumen HW RT, no Nanite). | Medium | Low — native builds ignore these anyway, but keeping them bloats config and may trigger plugin loading |
| P0-2 | `infra/ue5_config/DefaultGame.ini` | Remove `bFocusKeepalive` and `KeepaliveInterval` from `[Emergent]` section. Update `GameWebSocketUrl` to production domain. | Low | Low |
| P0-3 | `.uproject` file | Ensure `PixelStreaming` plugin is **not** enabled in the Unreal project plugin list. Verify `Platforms` only includes iOS and Android (not LinuxServer for streaming). | Low | Medium — plugin presence may trigger compile errors on mobile if PS2 headers are missing |

### Priority 1 — Should Change (Quality / Clarity)

| # | File | Change | Effort | Risk |
|---|---|---|---|---|
| P1-1 | `backend/server.py` | Rename `/api/streaming/*` endpoints → `/api/sovereign/*`. Remove `cloud_streaming`, `e3ds_disabled`, `e3ds_commands` keys from responses. Clean boot log E3DS reference. | Low | Low — frontend must update API calls to match |
| P1-2 | `frontend/src/App.js` | Replace `PixelStreamingView` (lines 1006-1130) with a **Download Portal** component showing TestFlight link + Google Play link. Rename sidebar entry. Update `launch-mode` API path. | Medium | Low |
| P1-3 | `frontend/src/App.js` | Remove sidebar `{id:'streaming', icon:Radio, label:'Pixel Stream'}` nav item; add `{id:'download', icon:Download, label:'Get App'}`. | Low | Low |
| P1-4 | `fel_ue5_eagle3d_linux_package.sh` | Add deprecation header: `# DEPRECATED — Use fel_ue5_ios_shipping_package.sh for native builds`. Move to `infra/deprecated/`. | Low | None |
| P1-5 | `infra/deploy_e3ds.sh` | Add deprecation header. Move to `infra/deprecated/`. | Low | None |
| P1-6 | `infra/e3ds/` | Move entire directory to `infra/deprecated/e3ds/`. | Low | None |

### Priority 2 — Nice to Have (Tech Debt)

| # | File | Change | Effort | Risk |
|---|---|---|---|---|
| P2-1 | `fel_ue5_win64_cook_only.sh` | Remove Pixel Streaming 2 WebRTC encoder snippet references (these are E3DS-specific). | Low | None |
| P2-2 | `backend/server.py` | Remove `video_feed: False` key from streaming status (concept no longer applies). | Low | None |
| P2-3 | `frontend/src/App.js` | Remove all `WifiOff`, `Radio` icon imports if streaming view is removed. Clean unused imports. | Low | None |
| P2-4 | `UnrealIntegration/Source/*/FELFocusKeepaliveTickComponent.*` | This component sends periodic focus pings to prevent iframe deactivation. Not needed for native. Consider removing or making conditional. | Low | Low — component is already no-op when keepalive is disabled |
| P2-5 | `SEELE_AI_EXECUTION_PACKAGE.md` | Update Section 2 (Google Distribution Pipeline) to remove E3DS references and clarify native-only distribution. | Low | None |

### No Change Required

| Component | Reason |
|---|---|
| `FinalEvolutionLab/` (entire Swift app) | Already designed for embedded native UE rendering |
| `UnrealManager.swift` | Loads `UnrealFramework.framework` locally — no streaming |
| `UnrealContainerView.swift` | Native `UIView` rendering — no iframe/WebRTC |
| `GameSceneHostView.swift` | SceneKit fallback — fully local |
| `FELEmergentBridgeSubsystem.h/.cpp` | WebSocket telemetry bridge — used by native builds |
| `FELEmergentDeepLinkSubsystem.h/.cpp` | Deep link handling — native app launch |
| `backend/core.py` | Auth system — no streaming dependency |
| `scripts/smoke_test_modes.py` | Registry tests — streaming-agnostic |
| `scripts/test_economy_transactions.py` | Economy tests — streaming-agnostic |
| `scripts/validate_ios_descriptor.py` | iOS build validation — already validates native packaging |
| `scripts/validate_cooked_payload.py` | Cooked content validation — local build focused |
| `FEL_ModeManager.production.json` | Mode registry — platform-agnostic |
| `ArenaSettings.json` | Arena config — platform-agnostic |
| `FEL_VenueRegistry.production.json` | Venue registry — platform-agnostic |
| `infra/distribution/google_play_distribution.json` | Already configured for native AAB distribution |
| `infra/SHIPPING.md` | Already documents native iOS shipping |
| `prepare_fel_full_ship.sh` | Merges native shipping config |
| `prepare_fel_emergent.sh` | Merges WebSocket bridge config (local, not streaming) |
| `fel_ue5_ios_shipping_package.sh` | Already the native local build script |
| `infra/fix_ios_descriptor_path.sh` | Validates native `.app` bundle integrity |
| `infra/fel_prebuild_ci_check.sh` | Pre-build checks — platform-agnostic |

---

## 10. DefaultEngine.ini — Proposed Native Replacement

```ini
; ═══════════════════════════════════════════════════════════════
; Final Evolution Lab — DefaultEngine.ini
; UE 5.7 · Native Mobile (iOS / Android) — No Pixel Streaming
; ═══════════════════════════════════════════════════════════════

[ConsoleVariables]
; Ensure Pixel Streaming does not auto-start (if plugin still compiled)
PixelStreaming.WebRTC.StartStreaming=0
PixelStreaming2.AutoStartStream=0

[/Script/EngineSettings.GameMapsSettings]
GameDefaultMap=/Game/FEL/Maps/Venice_Beach_Court
ServerDefaultMap=/Game/FEL/Maps/Venice_Beach_Court

[/Script/Engine.GameEngine]
bAllowTravel=true

[/Script/Engine.RendererSettings]
; Mobile-appropriate rendering (Metal / Vulkan)
r.Lumen.HardwareRayTracing=0
r.Nanite.Enabled=0
r.RayTracing=0
r.VirtualShadowMaps.Enable=1
; Forward shading for mobile performance
r.AntiAliasingMethod=2
; TSR at mobile quality
r.TSR.Quality=1

[Audio]
AudioMixerClassName=/Script/AudioMixerPlatformAudioUnit.AudioMixerPlatformAudioUnit
bEnableAudioStreaming=false
```

---

## 11. Migration Sequence (Recommended Order)

```
Phase 1: Config (Day 1)
  ├── Replace DefaultEngine.ini with native mobile config
  ├── Merge IOS_local_sovereign snippet as default
  ├── Remove bFocusKeepalive from DefaultGame.ini [Emergent]
  └── Verify .uproject does not force-enable PixelStreaming plugin

Phase 2: Backend (Day 1-2)
  ├── Rename /api/streaming/* → /api/sovereign/*
  ├── Remove E3DS-related response keys
  ├── Clean boot log messages
  └── Run: python scripts/smoke_test_modes.py (expect 147 pass)
       python scripts/test_economy_transactions.py (expect 33 pass)

Phase 3: Frontend (Day 2-3)
  ├── Replace PixelStreamingView with DownloadPortalView
  ├── Update sidebar navigation
  ├── Update API endpoint paths
  └── Add TestFlight + Google Play distribution links

Phase 4: Deprecate E3DS (Day 3)
  ├── Move infra/e3ds/ → infra/deprecated/e3ds/
  ├── Move deploy_e3ds.sh → infra/deprecated/
  ├── Add deprecation headers to Linux build script
  └── Update documentation references

Phase 5: Validate (Day 3-4)
  ├── Run full test suite: 180 tests expected green
  ├── Run validate_ios_descriptor.py
  ├── Run validate_cooked_payload.py
  ├── Verify fel_ue5_ios_shipping_package.sh --verify-only
  └── Test deep link flow: finalevolution://launch?map=...
```

---

## 12. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Pixel Streaming 2 plugin compile errors on iOS after config removal | Low | Medium | Set `PixelStreaming.WebRTC.StartStreaming=0` as fallback; conditionally exclude plugin from iOS target in `.uproject` |
| Frontend API path mismatch after rename | Medium | Low | Update frontend API calls in same PR as backend rename |
| Renderer settings too aggressive for mobile (Nanite/Lumen off) | Low | Medium | Profile on target devices; TSR Quality 1 is safe for A15+ |
| Emergent WebSocket bridge breaks without E3DS encryption key | Very Low | Low | Already falls back to `'fel-sovereign'` when E3DS key absent |
| Google Play asset packs misconfigured after DefaultEngine changes | Low | Low | Android asset packs reference cooked content, not engine config |

---

## 13. Files Inventory — Streaming vs. Local

### Streaming-Only Files (7 files, ~600 lines — DEPRECATE)

```
infra/e3ds/__main__.py              167 lines  Pulumi IaC for GPU cloud
infra/e3ds/Pulumi.yaml               30 lines  Stack config
infra/e3ds/requirements.txt            5 lines  Python deps
infra/deploy_e3ds.sh                  86 lines  Deploy wrapper
fel_ue5_eagle3d_linux_package.sh     316 lines  Linux PS2 build
infra/ue5_config/DefaultEngine.ini   115 lines  PS2 encoder config (REPLACE, not delete)
```

### Local-Build Files (KEEP ALL — already correct)

```
fel_ue5_ios_shipping_package.sh      826 lines  Native iOS cook+stage+archive
prepare_fel_full_ship.sh              ~80 lines  Native shipping config merge
prepare_fel_emergent.sh               ~60 lines  WebSocket bridge config
infra/SHIPPING.md                    152 lines  Native iOS shipping runbook
infra/fix_ios_descriptor_path.sh      ~50 lines  Cooked payload validator
infra/fel_prebuild_ci_check.sh        ~80 lines  Build pre-flight
infra/ue5_config/ExportOptions.plist   ~20 lines  IPA export config
infra/distribution/google_play_dist.json  ~200 lines  Native AAB config
```

### Hybrid Files (MODIFY — remove streaming references)

```
backend/server.py                   2620 lines  Rename 3 endpoints, remove E3DS strings
frontend/src/App.js                 1248 lines  Replace PixelStreamingView, update sidebar
infra/ue5_config/DefaultGame.ini     ~150 lines  Remove focus-keepalive, update WS URL
```

---

## Conclusion

The Final Evolution Lab codebase is **architecturally ready for native local builds**. The E3DS cloud streaming layer is a **bolt-on overlay** that was never activated by default. The migration primarily involves:

1. **Cleaning config** — Replace E3DS-tuned DefaultEngine.ini with mobile renderer settings
2. **Removing UI** — Swap the Pixel Streaming frontend view for a download portal
3. **Renaming endpoints** — `streaming/*` → `sovereign/*` for clarity
4. **Deprecating E3DS infra** — Move ~600 lines of IaC to deprecated folder

**Estimated effort:** 2-4 days for a clean migration  
**Test impact:** Zero — all 180 tests are streaming-agnostic  
**Risk level:** Low — the native path is already the production default
