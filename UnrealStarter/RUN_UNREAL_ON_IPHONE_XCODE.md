# Run your Unreal game on an iPhone (via Xcode)

You do **not** use **`MyProjec.xcworkspace`** as the app that installs on the phone. Unreal **cooks** the project and generates a **separate iOS `.xcworkspace`**. Follow the order below.

---

## At a glance (checklist)

1. **Fix Mac builds** so Unreal can compile your game module. On this Mac that means **UE 5.7** + **Xcode 26** (or **UE 5.2** + **Xcode 15** + `xcode-select`). See **`MyProjec/FEL_COMPILE_AND_MAP.md`** and **`MAC_PLATFORM_MAC_INVALID.md`**.
2. **Unreal Editor:** **Edit → Project Settings → Platforms → iOS** — **Bundle ID**, **signing** / team.
3. **Package / cook for iOS:** **Platforms → Apple → iOS** or **File → Package Project → iOS** (labels vary by engine version).
4. Open the **`.xcworkspace`** Unreal creates for the iOS build (often under **`Saved/StagedBuilds/IOS/`** or the path in the **Output Log**).
5. In that workspace: select your **iPhone**, set **Signing** team, **⌘R**.

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
