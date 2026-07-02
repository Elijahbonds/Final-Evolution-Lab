# Final Evolution Lab — iOS (NEXUS Sprint)

Native SwiftUI shell embedding the headless NEXUS `nexus_gameplay` static libraries. SceneKit provides the sprint preview arena until Metal venue rendering lands.

## Prerequisites

- Xcode 16+ with iOS 16+ SDK
- CMake 3.20+
- Apple Developer team **7KJ6G7HLL4** (Debug automatic signing)

## Build NEXUS static libraries

The Xcode target runs **`Build NEXUS iOS static libs`** before compile (invokes `./scripts/build-nexus-ios.sh`). You can also build manually from the repo root:

```bash
./scripts/build-nexus-ios.sh
```

Produces `build-ios/libnexus_gameplay.a` (and sibling libs). Re-run after C++ gameplay changes. The script exits immediately when prebuilt libs are present.

## Run on iPhone / Simulator

1. Open `FinalEvolutionLab.xcodeproj`.
2. Scheme: **FinalEvolutionLab** (Debug). Do **not** add `-ScreenshotHarness` under Run → Arguments (that flag is PR/UI-test only).
3. Select a physical iPhone or simulator (e.g. iPhone 17 Pro).
4. **Product → Run**.

### Simulator smoke

Simulator-only CI/agent path — **do not** use `devicectl` or install to a physical iPhone.

1. **Boot simulator** (iPhone 17, iOS 26.5 preferred). If `simctl boot` fails with missing device data, delete the stale UDID and recreate:

```bash
xcrun simctl list devices available | grep "iPhone 17"
# If boot fails: xcrun simctl delete <UDID>
xcrun simctl create "iPhone 17" com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun simctl boot "iPhone 17" && open -a Simulator
```

2. **Build** from repo root (`~/Final-Evolution-Lab`):

```bash
cd ~/Final-Evolution-Lab
xcodebuild -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```

3. **Install + launch** on the booted simulator (`com.finalevolutionlab.app`):

```bash
APP="/tmp/FEL-DD-NEXUS/Build/Products/Debug-iphonesimulator/FinalEvolutionLab.app"
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.finalevolutionlab.app
```

**Last agent sim session (2026-06-19):**

| Field | Value |
|-------|--------|
| Simulator | **iPhone 17** (iOS 26.5) |
| UDID | `1B67D9BE-90BE-4206-8CA5-1747CBEDC4AB` |
| Debug app path | `/tmp/FEL-DD-NEXUS/Build/Products/Debug-iphonesimulator/FinalEvolutionLab.app` |
| UI-test DerivedData | **Same as build** — `/tmp/FEL-DD-NEXUS` (separate `-TEST` path can break Firebase Firestore SPM on cold resolve) |
| Bundle ID | `com.finalevolutionlab.app` |
| Firebase | Placeholder `GoogleService-Info.plist` (`FEL_FIREBASE_PREVIEW=1`) — **PREVIEW · FIREBASE OFFLINE** banner expected |

Product smoke (automated): `xcodebuild test … -only-testing:FinalEvolutionLabUITests/GameModeScreenshotUITests/testProductSmoke_KeySimulatorFlows` — see `docs/NEXUS_SIMULATOR_PRODUCT_TEST.md`.

4. **Optional headless validate** (basketball_dunk mesh + dunk lifecycle, no UI automation):

```bash
./scripts/nexus_playtest.sh --duration 0
```

### Metal viewport (`NEXUS_USE_METAL`)

Arena rendering picks **SceneKit** (camera follow, player movement, procedural Venice) unless Metal is selected.

| Trigger | Viewport |
|---------|----------|
| Default (mode without bundled mesh) | SceneKit |
| **Any production mode** + bundled manifest + mobile `.nexusmesh.json` | **Metal** (auto) |
| Launch env `NEXUS_USE_METAL=1` | Metal (any mode) |
| Launch env `NEXUS_USE_SCENEKIT=1` or `NEXUS_USE_METAL=0` | SceneKit (force) |
| Xcode compile flag `NEXUS_USE_METAL` | Metal (always) |

Metal path: `GameSceneHostView` → `MTKView` → `NexusMetalBridge` → C++ `MetalRenderer` (vertex-color venue mesh from manifest). SceneKit path unchanged for QA and modes without bundled mesh.

**Simulator — force Metal for all modes:**

```bash
NEXUS_USE_METAL=1 xcrun simctl launch booted com.finalevolutionlab.app
```

**Simulator — Dunk Contest auto-Metal** (bundled mesh present; no env var):

```bash
# After install (step 3): Arena → Dunk Contest; viewport uses Metal when bundle check passes.
test -f "$APP/assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json"
```

**Device — Metal launch** (phone unlocked):

```bash
DEVICECTL_CHILD_NEXUS_USE_METAL=1 xcrun devicectl device process launch \
  --device <UDID> --terminate-existing com.finalevolutionlab.app
```

**Host renderer regression** (Venice mesh load, no UI):

```bash
ctest --test-dir build-full -R nexus_renderer_test --output-on-failure
```


Physical iPhone path — **do not** install `Debug-iphonesimulator` products with `devicectl` (wrong platform / invalid signature).

1. **Rebuild NEXUS libs for device** when `NexusPrebuilt/*.a` were built for the simulator (link error: `building for 'iOS', but linking in object file ... built for 'iOS-simulator'`):

```bash
cd ~/Final-Evolution-Lab
rm -rf build-ios/nexus-ios
PLATFORM_NAME=iphoneos ARCHS=arm64 ./scripts/build-nexus-ios.sh
```

2. **Debug device build** (isolated DerivedData avoids concurrent simulator build DB locks):

```bash
xcodebuild -scheme FinalEvolutionLab \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  -derivedDataPath /tmp/FEL-DD-device \
  DEVELOPMENT_TEAM=7KJ6G7HLL4 \
  -allowProvisioningUpdates \
  build
```

Product: `/tmp/FEL-DD-device/Build/Products/Debug-iphoneos/FinalEvolutionLab.app`

3. **Install** (paired device; list with `xcrun devicectl list devices`):

```bash
xcrun devicectl device install app --device 77E005FC-16AB-55D3-A702-81D118AB3992 \
  "/tmp/FEL-DD-device/Build/Products/Debug-iphoneos/FinalEvolutionLab.app"
```

**Last agent install (2026-06-19, ref `78a4333f`):** **SUCCESS** on **Elijah's Iphone** (`77E005FC-16AB-55D3-A702-81D118AB3992`, iPhone 16 Pro Max). Bundle ID `com.finalevolutionlab.app`.

**Prior attempt:** `Debug-iphonesimulator` from DerivedData → **FAIL** (`CoreDeviceError` 3002 / invalid signature `0xe8008014`). **Device build** before NEXUS iphoneos refresh → **FAIL** (linker: simulator static libs).

4. **Bundle asset smoke** (host inspect of device build product — no unlock required):

```bash
APP="/tmp/FEL-DD-device/Build/Products/Debug-iphoneos/FinalEvolutionLab.app"
test -f "$APP/assets/nexus/manifests/nexus_asset_manifest.json"
find "$APP/assets/nexus/imported" -name '*.nexusmesh.json' | wc -l   # expect 28
test -f "$APP/assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json"
```

5. **Optional launch + Venice mesh** (phone **unlocked**; Metal viewport off by default):

```bash
DEVICECTL_CHILD_NEXUS_USE_METAL=1 xcrun devicectl device process launch \
  --device 77E005FC-16AB-55D3-A702-81D118AB3992 --terminate-existing \
  com.finalevolutionlab.app
# Arena → Dunk Contest; confirm no crash. Metal mesh load not log-visible without Instruments.
```

`devicectl launch` fails with `device locked` when the phone is passcode-locked.

Manual gameplay checklist: `./scripts/smoke-ios-device.sh --checklist`. Do **not** run TestFlight archive without a real `GoogleService-Info.plist`.

### Sprint gameplay flow

1. Launch app → tab shell (`ContentView`).
2. **Arena** tab → **Modes** segment (default).
3. Tap **Dunk Contest** (Venice Beach) or another mode card.
4. Without embedded Unreal, navigation goes straight to `GamePlayView`.
5. NEXUS session starts via `fel.arena.start_session`.

### NEXUS HUD poll (60 Hz)

While `GamePlayView` is visible, `NexusGameplayEngine` ticks the C++ session and polls **`nexus_gameplay_session_hud_poll_json()`** each frame. The center HUD overlay shows:

| Field | Source |
|-------|--------|
| `mode_id` | `fel.hud.frame` payload |
| `session_state` | `active` / `idle` / `ended` / `paused` |
| Score + combo | `score`, `combo` |
| Throw-catch | `throw_catch.phase`, `power_multiplier` |

Swift gameplay scores are pushed to the engine via `fel.arena.update_score` on score changes so HUD poll stays aligned with the UI columns.

### Touch → dunk (DoD #3) — `basketball_dunk` only

When `GamePlayView` is in Dunk Contest and the NEXUS session is linked, a full-screen gesture overlay drives the C++ dunk loop:

| Step | Gesture | NEXUS command |
|------|---------|---------------|
| 1 | Long-press / hold anywhere | `fel.dunk.charge_begin` |
| 2 | Release (power = hold duration ÷ 1.5s) | `fel.dunk.charge_release` |
| 3 | Tap at apex | `fel.dunk.apex_tap` |

Timing grade (`timing_grade`) and scores (`player_score`, `opponent_score`) return in command payloads and appear in the center HUD. Legacy SceneKit `DunkEngine` QTE remains for controller/keyboard paths; touch on device uses NEXUS when linked.

**DoD #3 status:** ✅ **Closed for iOS bridge** — touch → charge → release → apex tap → score wired via `NexusGameplayEngine` + `NexusGameplayBridge`. Metal venue renderer and physical-device QA remain separate gates (DoD #1/#2).

### Session end + receipt flush

On exit (`GamePlayView.onDisappear`):

1. **`nexus_gameplay_session_end_arena(session, playerScore, opponentScore)`** — finalizes arena session and generates receipt JSON.
2. **`nexus_gameplay_session_flush_receipts(session)`** — writes queued receipts to `~/.fel/pending_receipts/*.json` for offline sync.
3. **`SessionReceiptUploadService.uploadPendingReceipts()`** — scans that directory and POSTs each JSON to `Config.gameplaySessionReceiptURL` with Firebase Bearer auth. Files delete on HTTP 2xx; failures log via `os.Logger` and leave files for retry.

`ContentView.onAppear` and **foreground resume** (`scenePhase == .active`) drain pending receipts. Set `FEL_SESSION_RECEIPT_URL` to override the POST endpoint (local: `http://127.0.0.1:8000/api/games/session`).

**Fail-closed economy posture** (not App Store StoreKit — see `NexusEconomyAuthority`):

| Surface | Rule |
|---------|------|
| IAP breath metrics | Non-finite or out-of-range samples rejected — never mutate gameplay power |
| Shards / ranked PRQ | Applied only when receipt trust is `serverVerified` (POST 2xx) |
| NEXUS P0/P1 modes | Local finalize does not grant economy; server receipt required |
| Dashboard | Status tab → **DRAIN PENDING RECEIPTS** manually retries the queue |

See also `docs/NEXUS_PRODUCT_INTEGRATION.md` §3 and `infra/ECONOMY_AUTHORITY_CONTRACT.md`.

#### Disk queue (`~/.fel/pending_receipts/`)

| Property | Behavior |
|----------|----------|
| Filename | `{telemetry.session_id}.json` (sanitized alnum/`_`/`-`) |
| Re-flush | Same session id **overwrites** the file (no duplicates) |
| Fallback | `{mode_id}_{counter}.json` when session id absent |
| When written | On `fel.arena.flush_receipts` / `nexus_gameplay_session_flush_receipts` only |

Simulator path: `/Users/<you>/.fel/pending_receipts/`. On device, use Xcode **Devices → Download Container** or inspect via Files if exposed.

Verify after a session:
```bash
ls ~/.fel/pending_receipts/*.json
./scripts/smoke_gameplay_session.sh --skip-build
```

### NEXUS score authority (iOS Swift shell)

For the current iOS Swift/SceneKit gameplay shell, **the user-visible Swift score is the receipt authority**. `GamePlayView` still routes supported taps into C++ (`fel.dunk.*`, `fel.karate.*`, `fel.sport.pulse`, board/academy, Brain Brawl, Who Scene It, pickup, and carnival helpers) so HUD telemetry and mode payloads stay live, but final receipt scores must match what the player saw unless a mode explicitly moves to HUD-only scoring.

| Direction | P0/P1 (dunk, karate_endless) | Other modes |
|-----------|------------------------------|-------------|
| C++ → Swift | HUD telemetry and mode payloads | HUD telemetry and mode payloads |
| Swift → C++ | Final `fel.arena.update_score` before end unless `usesNexusScoreAuthority` is enabled | Final `fel.arena.update_score` before end |
| End session | `use_live_scores=false` until the visible UI is HUD-authoritative | `use_live_scores=false` |
| Commands | `fel.dunk.*` / `fel.karate.action` update C++ runtime; HUD poll reflects next tick | `fel.sport.pulse`, board/academy, cognitive, pickup, carnival helpers |

Karate nested state (`wave`, `player_hp`, `opponents_alive`, `combo_chain`) is parsed from `mode_state.karate` in `NexusHUDSnapshot`. `NexusGameplayEngine.refreshHUDPoll()` maps `fel.hud.frame` 1:1 with `gameplay_application.cpp::emitHudTickFrame()`.

### Karate Endless touch (P1)

When NEXUS is linked, PS2 action buttons route through **`fel.arena.mode_input`** (C++ delegates to `fel.karate.action`):

| UI | mode_input action | C++ combat |
|----|-------------------|------------|
| Punch | `light_strike` | light strike |
| Kick | `heavy_strike` | heavy strike |
| Block | `block` | block |

Direct `fel.karate.action` remains available via `NexusGameplayEngine.karateAction(_:)` for headless/tests.

HUD shows wave + HP + opponents from `mode_state.karate` in the HUD poll payload.

### Live HUD WebSocket (optional)

Set `FEL_HUD_WS_URL=ws://host:8080/ws/hud` to push `fel.hud.frame` JSON during active sessions via `FELHUDRelayClient` (~30 Hz, Firebase `user_id` query param when signed in).

Without URL: zero socket activity, no crash.

### Screenshot harness (optional)

Add launch argument `-ScreenshotHarness` only when capturing PR screenshots or running `GameModeScreenshotUITests`. Normal Debug runs must use the tab menu.

## Signing & provisioning

| Config | Team | Style | Profile / identity |
|--------|------|-------|-------------------|
| **Debug** (simulator + device) | **7KJ6G7HLL4** | Automatic | Xcode-managed development |
| **Release** (archive / TestFlight) | **7KJ6G7HLL4** | Manual | `FEL_TestFlight_Distribution` + **iPhone Distribution** |

- **Bundle ID:** `com.finalevolutionlab.app`
- **Firebase:** `FinalEvolutionLab/GoogleService-Info.plist` required for Release archive (copy from Firebase Console; example at `GoogleService-Info.example.plist`). CI compile-only: `ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1`.
- **Apple Developer:** App ID `com.finalevolutionlab.app` must exist under team **7KJ6G7HLL4** with distribution profile `FEL_TestFlight_Distribution` installed on the archive Mac.
- **Xcode account:** Settings → Accounts → Apple ID with team access before archive.

## Archive / TestFlight checklist (Phase 9 — DoD #9)

### Preflight

```bash
chmod +x ./scripts/archive-ios-testflight.sh ./scripts/smoke-ios-device.sh
./scripts/archive-ios-testflight.sh --dry-run    # NEXUS libs + signing preflight
```

- [ ] ≥12 GB free disk (DerivedData + SPM checkouts are large)
- [ ] `build-ios/libnexus_gameplay.a` present (or dry-run rebuilds it)
- [ ] `GoogleService-Info.plist` in `FinalEvolutionLab/`
- [ ] Xcode logged in; profile `FEL_TestFlight_Distribution` visible in Signing & Capabilities (Release)

### Archive (CLI)

```bash
./scripts/archive-ios-testflight.sh
# Optional: export IPA for Transporter
./scripts/archive-ios-testflight.sh --export
```

Output: `build/FEL.xcarchive` (export: `build/FEL-export/*.ipa`). Export options: `infra/ios/ExportOptions.testflight.plist`.

### Archive (Xcode UI)

1. `./scripts/build-nexus-ios.sh` (or let **Build NEXUS iOS static libs** run on archive)
2. Scheme **FinalEvolutionLab** → **Any iOS Device (arm64)**
3. **Product → Archive** (Release configuration)
4. **Organizer → Distribute App → TestFlight** (or App Store Connect)
5. Internal testers: install → run device smoke below

### Manual archive (fallback)

```bash
./scripts/build-nexus-ios.sh
xcodebuild -project FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/FEL.xcarchive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=7KJ6G7HLL4 \
  archive
```

## Device validation gate (Phase 10 — DoD #9)

Automated compile gate + printable manual checklist:

```bash
./scripts/smoke-ios-device.sh              # ctest + NEXUS libs + simulator build
./scripts/smoke-ios-device.sh --checklist  # manual steps only (no build)
./scripts/smoke-ios-device.sh --skip-build # ctest + checklist when disk tight
```

**Manual sign-off** (physical iPhone required):

1. **Menu** — Arena → Modes; Dunk Contest (P0) + Karate Endless (P1) launch; P2 shows Coming Soon
2. **Dunk** — hold → release → apex tap; HUD score + timing grade update
3. **Karate** — Punch/Kick/Block; combo + wave/HP in HUD
4. **Receipt** — exit gameplay → `~/.fel/pending_receipts/*.json` on device container; relaunch drains queue when authed
5. **Stability** — no crash on session start/end; return to menu

DoD **#9** is **partial** until build appears in App Store Connect and internal TestFlight install succeeds.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Link errors for `nexus_*` | Clean build; verify **Build NEXUS iOS static libs** phase ran |
| CMake missing in Xcode builds | Install CMake; or pre-run `./scripts/build-nexus-ios.sh` |
| Black SceneKit viewport | Loading overlay clears after prepare or 2.5s fallback |
| HUD missing NEXUS metrics | Confirm bridge linked; session must be `active` |
| Receipts not on disk | Check `lastFlushDelivered`; inspect `~/.fel/pending_receipts/` on device/sim |
| Menu skipped on launch | Remove `-ScreenshotHarness` from scheme arguments |
| Archive signing failure | Confirm team **7KJ6G7HLL4**, profile `FEL_TestFlight_Distribution`, `-allowProvisioningUpdates` |
| `GoogleService-Info.plist` missing (Release) | Add Firebase plist or `ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1` for CI-only compile |
| xcodebuild disk full | Free ≥12 GB; use `-derivedDataPath build/DerivedData-archive` |
| TestFlight upload rejected | Verify bundle ID, encryption export compliance (`ITSAppUsesNonExemptEncryption=NO`) |
