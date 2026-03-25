# Gold Master deployment (TestFlight / App Store)

This checklist closes the loop between **Swift**, **Unreal shipping**, and **on-device data** for a single shippable build.

## 1. Asset integration (App Icon & Launch)

| Item | Action |
|------|--------|
| **App icon** | Export Unreal / design **1024×1024** master → replace `FinalEvolutionLab/Assets.xcassets/AppIcon.appiconset/icon.png` (see `Contents.json`). |
| **Unreal iOS package** | After **File → Package Project → iOS**, open the **generated Xcode** project for the Unreal build and set the same **App Icon** / **Launch Screen** (or launch storyboard) so the embedded engine’s boot frame matches the Swift shell. Keep **display name** / **accent** aligned with `Theme` + `FELBranding`. |
| **Neuro-Mechanic colors** | Swift: `Theme.brandCyan` / `Theme.brandBlue` (`Utilities/Theme.swift`). Asset catalog mirrors: `NeuroMechanicCyan.colorset`, `NeuroMechanicBlue.colorset`. Unreal: `FELBranding.h` + Victory UI (`FELMatchResultsWidget.cpp`). |
| **Launch screen** | If you add a storyboard, set **Launch Screen File** in the app target; otherwise the system uses the asset catalog / plist defaults. Document your chosen storyboard name here when added. |
| **First launch** | Swift: **Delete the Fear** = `BondsBounceSplashView` once per install (`felHasSeenDeleteTheFearSplash`), then **System Scan** (`felHasCompletedFirstLaunchSystemScan`) before onboarding. |

## 2. Cold start & `Documents/FEL`

- **`FELUnrealSessionImporter.performLaunchRecoveryScan()`** runs from `FinalEvolutionLabUnrealApp.init` **before** the first frame so `session_results.json` / `last_session_result.json` left on disk after a force-quit are merged into the Vault + PRQ history.
- **Orphan scan:** enumerates `Documents/FEL/*.json`, skips `readiness_snapshot.json`, `progression_session.json`, and `*.flag`; imports `session_results*.json` and `last_session_result.json` by `GameSessionResult` decode + **id dedupe** against saved results. **`session_results.json` is processed first** when multiple files exist.
- **Data Protection:** iOS defaults place app `Documents` under file protection (typically **Complete Until First User Authentication**). Unreal/Swift both write under the same sandbox; do not rely on files being readable when the device is locked before first unlock. For stricter policies, set `NSFileProtectionKey` when creating sensitive files (coordinate with compliance).

## 3. Unreal Shipping build

| Goal | How |
|------|-----|
| **Strip Neuro debug HUD** | Already wrapped: `FELBasketballPlayerController.cpp` uses `#if !UE_BUILD_SHIPPING` for `UFELNeuroDebugHUDWidget` and hot-reload input. |
| **`UE_LOG` in Shipping** | Package **Shipping** configuration; engine strips most logging. Optionally add to packaged `DefaultEngine.ini`: `[Core.Log]` with `GlobalLogVerbosity=NoLogging` or project-specific log suppression. |
| **Module `Build.cs`** | Use `UnrealStarter/BasketballGame/MyProjec.Build.cs` (or merge `MyProjec.Build.cs.snippet`). **Shipping** sets `FEL_PACKAGE_SHIPPING=1`; dev-only HUD/logs use `#if !UE_BUILD_SHIPPING` in C++ (see `FELBasketballPlayerController.cpp`, `FELBasketballGameMode.cpp`, `UFELDemoManager.cpp`). |
| **`[Core.Log]`** | Optional: merge commented block from `CONFIG_DefaultEngine.ini.snippet` into **packaged Shipping** `DefaultEngine.ini` to reduce log verbosity on device. |

## 4. Swift “reward” haptics

- **`felUnrealSessionResultsReady`:** `FELUnrealSessionImporter` calls `FELHaptics.sessionRewardImpact()` (medium `UIImpactFeedbackGenerator`) **before** import.
- **Orphan merge** (cold start / directory watch): haptic fires when at least one **new** session id is merged.
- **`felUnrealUINotificationFeedback`:** Unreal `FELNativeBridge` → `UINotificationFeedbackGenerator` — Academy terminal (`kind` 0), module completion (1), elite dunk (2), match end (3).

## 5. CI/CD — DeepMotion (Production)

- **Do not** commit `DEEPMOTION_CLIENT_ID` / `DEEPMOTION_CLIENT_SECRET`. Inject via **GitLab CI/CD variables** (masked, protected) or Xcode **scheme environment** for local runs.
- **Pipeline:** pass the same variable names into the **Unreal iOS cook** / **Xcode archive** step (shell `export DEEPMOTION_CLIENT_ID=…` before `RunUAT` or `xcodebuild`). Python Animate3D scripts read the same names (`scripts/deepmotion_animate3d_service.py`).
- **`readiness_snapshot.json`:** metrics-only JSON (PRQ, vertical estimate, joint heat) — **no** API secrets; verify with `FelReadinessSnapshotExport` in `PRQManager.swift`.

## 6. Xcode build flag checklist (Release / Archive)

Use these when producing the **.ipa** for TestFlight:

| Setting | Debug | Release / Archive |
|---------|-------|-------------------|
| **Configuration** | Debug | **Release** |
| **Optimization** | `-Onone` | **Whole Module** / default Release |
| **`SWIFT_ACTIVE_COMPILATION_CONDITIONS`** | `DEBUG` | **empty** or `RELEASE` only if you branch in code |
| **`GCC_PREPROCESSOR_DEFINITIONS`** | `DEBUG=1` | **no `DEBUG`** (or `NDEBUG=1` if Obj-C++ needs it) |
| **`DEBUG_INFORMATION_FORMAT`** | DWARF with dSYM | **DWARF with dSYM File** (for crash symbolication) |
| **`ENABLE_TESTABILITY`** | Yes | **No** for store builds |
| **`DEVELOPMENT_TEAM` / signing** | Your team | Distribution cert + App Store provisioning |
| **Bitcode** | N/A (deprecated) | — |

**Swift:** Prefer `#if DEBUG` for dev-only UI; default isolation in this project may be MainActor — keep launch path synchronous on the main thread for cold recovery.

---

*See also: `IOS_PLAY_TEST_READINESS.md` for device play-test scope.*
