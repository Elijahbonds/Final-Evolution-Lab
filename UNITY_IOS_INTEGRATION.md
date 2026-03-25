# Unity ↔ iOS (Final Evolution Lab) — integration map

## 1. Native handshake

| Piece | Role |
|------|------|
| **`UnityManager.swift`** | Loads `UnityFramework.framework`, `runEmbedded`, `sendMessageToGO` / Film Vault + Skill Lab helpers. |
| **`FELNativeCallProxy.h` / `.m`** | C symbols `FEL_OnExerciseComplete`, `FEL_UpdateUserXP`, `FEL_OnRepCompleted` for Unity `[DllImport("__Internal")]`. |
| **`FELNativeBridge.cs`** (Unity) | Calls those C functions from gameplay / UI. |
| **`FELUnityNativeCallbacks.swift`** | Unity native callbacks → `PRQNativeBridge.postMetrics`; **`LabViewModel`** persists XP/shards. |

**Xcode:** Ensure `FELNativeCallProxy.m` is compiled into the **host app** target (same binary Unity links against). `PBXFileSystemSynchronizedRootGroup` includes `FinalEvolutionLab/` — add `NativeBridge/` if your tree does not sync automatically.

## 2. Unity features (this repo)

| Script | Purpose |
|--------|---------|
| **`FilmVaultController.cs`** | HLS/file `VideoPlayer` + JSON sidecar; **`BiomechanicsRenderer`** joint vectors (or fallback `LineRenderer`s). |
| **`StreamOverlayUIController.cs`** | HLS `VideoPlayer.url`, rep counter, CoachGhost stub. |
| **`JumbotronStreamDisplay.cs`** | Stream / render texture → in-scene jumbotron quad. |
| **`FELPostProcessBuild.cs`** | iOS post-build: **Metal** + **QuartzCore**, Obj-C exceptions + `libc++`, **NSCameraUsageDescription**, **UIBackgroundModes** audio, optional **`DEVELOPMENT_TEAM`** from **`FEL_APPLE_TEAM_ID`**. |
| **`FELPlayerSettingsM4.cs`** | Menu: Metal, MT rendering, 4-bone skinning. |
| **`FELIOSBuilder.cs`** / **`FELBuildScript.cs`** | Batch iOS export: `FELIOSBuilder.BuildIOS` or **`-executeMethod FELBuildScript.ExportIOS`**. |
| **`FELIOS120Hz.cs`** | Disables vSync, sets `Application.targetFrameRate` (request up to 120 FPS on ProMotion devices). |
| **`FELBundleIdSync.cs`** | Menu: set Unity iOS **applicationIdentifier** from `Config/FEL_IOS_BUNDLE_ID.txt`. |

## 3. Build pipeline

**`scripts/fel_pipeline_unity_ios.sh`**

- Runs **`FELIOSBuilder.BuildIOS`** by default (`-executeMethod FELIOSBuilder.BuildIOS`). Set **`FEL_IOS_OUT`** for the export folder (passed through to the builder via env).
- **`Config/FEL_IOS_BUNDLE_ID.txt`** supplies the default **`FEL_EXPECTED_BUNDLE_ID`** for the plist check (must match Xcode **`FinalEvoAPP`** unless you change both).
- Optional smoke **`xcodebuild`** (unsigned).

**Unity menu:** **FEL → Build iOS Player** runs the same builder from the Editor.

**`scripts/fel_claw_device_build.sh`** — Unity batch export via **`FELBuildScript.ExportIOS`**, opens the generated **`.xcworkspace`**, optional **`xcodebuild`** to a named device (`IOS_DEVICE_NAME` + **`FEL_APPLE_TEAM_ID`** for signing). Adjust **`UNITY_EDITOR`** path to your Hub editor binary.

**OpenClaw** does not run these scripts — use CI or your shell.

## 4. Bundle ID alignment

| Source | Value |
|--------|--------|
| Xcode app target | `PRODUCT_BUNDLE_IDENTIFIER` in `FinalEvolutionLabUnreal.xcodeproj` (`FinalEvoAPP`) |
| Repo canonical | `Config/FEL_IOS_BUNDLE_ID.txt` |
| Unity | **FEL → Sync iOS Bundle Identifier with host app** (`FELBundleIdSync.cs`) reads `FEL_IOS_BUNDLE_ID.txt` from common paths or falls back to `FinalEvoAPP` |

Change App Store–style identifiers in **both** Xcode and Unity (and the config file) together.

## 5. Unity metrics → profile (`PRQMetricsUpdated`)

- **`FELUnityNativeCallbacks`** posts **`PRQNativeBridge.postMetrics`** with `unityXP`, `unityExerciseComplete`, and **`unityRepShards`** (from **`FEL_OnRepCompleted`** / **`EvolutionRepRewards`**).
- **`LabViewModel`** observes **`PRQMetricsUpdated`**, adds shards (XP / rep shards capped per event), **`SaveSystem.saveProfile`**, **`PRQManager.shared.sync`**, leaderboard refresh.

Tune shard amounts in **`applyUnityHostMetrics`** in `LabViewModel.swift`.

## 6. M4 / Metal

Run **FEL → Apply M4-optimized Player Settings** in Unity; confirm **Graphics API = Metal** for iOS and review **Quality** tiers for your assets.

## 7. JsonUtility caveat

`FilmVaultController` uses `JsonUtility` with nested arrays — Unity’s JSON support is limited. For production biomechanics JSON, use **Newtonsoft.Json** or split into a flat keyframe list.
