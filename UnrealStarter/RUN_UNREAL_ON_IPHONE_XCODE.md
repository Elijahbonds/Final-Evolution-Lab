# Run your Unreal game on an iPhone (via Xcode)

You do **not** use the Mac editor’s `.xcworkspace` as the app that installs on the phone. Unreal **cooks** the project and generates a **separate iOS `.xcworkspace`**. Follow the order below.

**This repo’s Unreal project:** `UnrealStarter/BasketballGame/FinalEvolutionLab.uproject`

---

## One-command path (CLI)

1. **Install iOS support for the engine** (required — see §0). Without it, UBT prints: *Missing files required to build IOS targets*.
2. From the repo root:
   ```bash
   chmod +x UnrealStarter/scripts/*.sh
   bash UnrealStarter/scripts/check_fel_ios_engine.sh   # must pass
   bash UnrealStarter/scripts/build_fel_ios_and_open_xcode.sh
   ```
   Or step-by-step: `package_fel_ios.sh` → `open_fel_ios_xcode.sh`
3. In Xcode: **Signing & Capabilities** → your **Team** → destination **your iPhone** → **⌘R**.

Archive output defaults to: `UnrealStarter/BasketballGame/Saved/Archive/IOS_Development/`

### Legacy Swift shell (optional)

The **legacy iOS app** (`ios/FinalEvolutionLab`) is **not** the ship path. **One** gaming app for players: the **packaged Unreal** iOS build. The Swift project is SceneKit lab / experiments; optional **Pixel Streaming** and `fel://` deep links are documented in **`DOCS/FEL_PHASE4_SHELL_UNREAL_HANDOFF.md`**. Product: **`UNREAL_ONLY.md`**.

### FEL runtime paths & native bridge (Phase 8)

- **Writable JSON / flags:** `ProjectSavedDir()/FEL/` (e.g. `session_results.json`, `readiness_snapshot.json`, `lab_onboarding_completed.flag`). Same layout on iOS inside the app sandbox.
- **Clinical / retail copy:** optional `Content/FEL/Config/FEL_ClinicalUIPolicy.json` (cooked with the game).
- **Native bridge:** `FELNativeBridge` calls `FEL_IOS_*` C entry points; the game module ships **stub** implementations for iOS Development. Replace with a static library only if you add a custom native host (not required for the single Unreal app).
- **Engine prerequisite:** Epic Launcher → UE 5.7 → **iOS** platform installed, or UBT reports *Missing files required to build IOS targets*.
- **Team / bundle:** `Config/DefaultEngine.ini` → `[/Script/IOSRuntimeSettings.IOSRuntimeSettings]` (`IOSTeamID`, bundle id) and Xcode Signing for device deploy.

---

## At a glance (checklist)

1. **Fix Mac builds** so Unreal can compile your game module (**UE 5.7** + current **Xcode**). See **`MAC_PLATFORM_MAC_INVALID.md`** if toolchain errors appear.
2. **Epic Games Launcher:** **Library → Unreal Engine 5.7 → ⋯ → Options** — install **iOS** target platform (large download).
3. **Unreal Editor:** **Edit → Project Settings → Platforms → iOS** — **Bundle ID**, **signing** / team (see `Config/IOS/IOSEngine.ini` for bundle id hints).
4. **Package / cook for iOS:** **Platforms → Apple → iOS**, **File → Package Project → iOS**, or **`UnrealStarter/scripts/package_fel_ios.sh`**.
5. Open the **`.xcworkspace`** Unreal creates (script `open_fel_ios_xcode.sh` searches under **`Saved/`**, **`Binaries/IOS`**, **`Intermediate/`**).
6. Select your **iPhone**, set **Signing** team, **⌘R**.

---

## 0. Prerequisites

1. **Editor compiles** (**MyProjecEditor** succeeds on Mac).
2. **Apple Developer** account (free or paid) for **device** signing.
3. **iPhone** trusted / **USB** (or Wi‑Fi debugging).
4. **Metal Toolchain** in Xcode if prompted (**Xcode → Settings → Components**).

---

## 1. Unreal Editor — iOS

1. Open **`MyProjec.uproject`** with the **same engine** you built with (e.g. **5.7**).
2. **Project Settings → Platforms → iOS:** bundle identifier, signing.
3. **Maps & Modes:** default map for device.

---

## 2. Package for iOS

Use **Platforms → Apple → iOS** or **File → Package Project → iOS**. When it finishes, note the logged folder containing **`.xcworkspace`**.

Common locations:

- **`[Project]/Saved/StagedBuilds/IOS/`**
- **`[Project]/Binaries/IOS/`**

---

## 3. Xcode — run on phone

1. Open Unreal’s **iOS `.xcworkspace`**.
2. **Signing & Capabilities** → your **Team**.
3. Destination: your **iPhone** → **Product → Run** (⌘R).
4. On device: **Settings → General → VPN & Device Management** → trust developer if needed.

---

## 4. Swift app in *this* repo (not Unreal)

**Final Evolution Lab:** **`ios/FinalEvolutionLab.xcodeproj`** → iPhone → **⌘R**. See **`XCODE_CLEAN_AND_RUN.md`**.

---

## 5. Quick reference

| Goal | Open in Xcode |
|------|----------------|
| **Unreal on iPhone** | iOS **`.xcworkspace`** from Unreal’s staged build |
| **Unreal Mac C++** | **`MyProjec.xcworkspace`** |
| **Swift FEL app** | **`ios/FinalEvolutionLab.xcodeproj`** |

---

*See also **`../UNREAL_EXPORT_TO_XCODE.md`**, **`../METAL_TOOLCHAIN_UNREAL.md`**, **`MyProjec/FEL_COMPILE_AND_MAP.md`**.
