# Xcode: Run the Latest Build (Not the Old One)

This project is **Final Evolution Lab** — a **Swift/SwiftUI iOS app** with **RealityKit** 3D for the Lab dunk court and **SwiftUI Arena** modes (themed canvases + PRQ-driven commit). It is **not** an Unreal-in-Xcode project; `UnrealStarter/` is reference only. For what is playable on device, controller support, and Unity vs Unreal, see **IOS_PLAY_TEST_READINESS.md**. For flows, see **PROJECT_FLOWS.md**.

- **Project:** `final-evolution-lab/ios/FinalEvolutionLab.xcodeproj` (your clone folder name may differ)
- **Scheme:** **FinalEvolutionLab** (display name on device: **Final Evolution Lab - Unreal**)
- **Target:** The app uses a **PBXFileSystemSynchronizedRootGroup** for the **`Source/`** folder, so all Swift files under that directory are included in the target.

---

## Quick reminder: run the latest build

0. **Optional — automated DerivedData purge (Gold Master):** from the repo root run `./scripts/xcode_clean_and_run.sh` (set `FEL_DERIVED_DATA_FULL_PURGE=1` to wipe all of `~/Library/Developer/Xcode/DerivedData`).
1. **Product → Clean Build Folder** (⇧⌘K)
2. **Quit Xcode** (⌘Q)
3. **Delete DerivedData** for this project: remove the folder starting with `FinalEvolutionLab-` in `~/Library/Developer/Xcode/DerivedData`
4. **Reopen** the project (`ios/FinalEvolutionLab.xcodeproj`)
5. **Product → Build** (⌘B)
6. **Product → Run** (⌘R)

If Xcode is still showing an old build with no recent changes (no RFD/GRF education, Pop Force, Recovery Lab, etc.), follow the full steps below.

---

## 1. Confirm you have the right project open

- **File path:** `final-evolution-lab/ios/FinalEvolutionLab.xcodeproj` (your clone folder name may differ)
- **Scheme:** **FinalEvolutionLab** (selected in the Xcode toolbar next to the Run button)
- **Target:** FinalEvolutionLab (the app), not the test targets

---

## 2. Clean and force a full rebuild

### In Xcode

1. **Clean Build Folder**  
   **Product → Clean Build Folder** (or **⇧⌘K**).

2. **Quit Xcode**  
   **Xcode → Quit Xcode** (⌘Q).

### In Finder / Terminal

3. **Delete this project’s DerivedData** (so the next build is from scratch):

   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/FinalEvolutionLab-*
   ```

   Or in Finder: **Go → Go to Folder** (⌘⇧G), paste:
   `~/Library/Developer/Xcode/DerivedData`
   then delete any folder whose name starts with **FinalEvolutionLab-** .

### Back in Xcode

4. **Reopen the project**  
   Open `ios/FinalEvolutionLab.xcodeproj` (double‑click or from File → Open).

5. **Build**  
   **Product → Build** (⌘B). Wait until it finishes.

6. **Run**  
   Choose a simulator or your device in the scheme/destination menu, then **Product → Run** (⌘R).

---

## 3. What you should see after a fresh build

- **Lab tab:** Metrics grid includes **Pop Force**; **Movement Science** section with **RFD & GRF** and **Recovery Lab**.
- **System Scan results:** **POP FORCE** in the 2×2 grid and the line about RFD/GRF.
- **Arena:** Rotating **performance tip** strip about Pop Force / RFD / GRF.
- **Training:** **“Program() recommends: [Track]”** and **Switch** when the recommended track differs from current.
- **Dashboard (Status):** **Recovery Lab** button.
- **Onboarding:** “Delete the fear. Your movement, audited.” under sport selection.

If you still see the old UI, repeat step 2 (clean, quit, delete DerivedData, reopen, build, run).

---

## 4. Swift app vs Unreal (and how they meet)

- **This Xcode target (`FinalEvolutionLab`):** Swift/SwiftUI Arena + Lab flows; optional **Unity** embed via `UnityFramework`; 3D dunk path uses **RealityKit** where wired. It does **not** compile the C++ under `UnrealStarter/` — that tree is a **drop-in module** for your Unreal game project.
- **Unreal (`UnrealStarter/BasketballGame/`):** Copy headers/sources into your UE module (see `MyProjec.Build.cs.snippet` for **Json** dependencies). Add **`FELKineticLeakage.cpp/.h`** to the same module as `FELBasketballCharacter`.

### 4a. Cooking Unreal content (editor)

1. Open your **Unreal 5.2+** project that contains the FEL basketball map/pawn.
2. **File → Cook Content for** your target platform (iOS for device tests).
3. Output goes under your project’s **Saved/Cooked** (and staged build tree). For a **standalone iOS Unreal app**, use **Platforms → iOS** packaging from Unreal or automation per Epic docs — this produces its own `.ipa` / Xcode project from UE, **separate** from `ios/FinalEvolutionLab.xcodeproj`.

### 4b. Linking Unreal with Swift (realistic options)

**Option A — Two apps (simplest for testing):** Run **Final Evolution Lab** for the dashboard/scan/Arena shell; run the **Unreal iOS build** for 3D court. Sync data by copying **`readiness_snapshot.json`** from the Swift app’s **On My iPhone → FinalEvolutionLab → Documents → FEL/** (Files app) into Unreal **`Saved/FEL/readiness_snapshot.json`** before launching the UE build on device or in editor.

**Option B — Single Xcode app with Unreal embedded:** Requires Epic’s **Unreal iOS export** as a library or generated Xcode project merged with custom bridging — **not automated in this repo**. Follow **`UNREAL_EXPORT_TO_XCODE.md`** and Epic’s “Integrating Unreal into native iOS” guidance; expect manual project merge and signing.

### 4c. PRQ / Neuro-Mechanic JSON (shared contract)

- Swift **`PRQManager`** writes **`Documents/FEL/readiness_snapshot.json`** with keys matching **`FELReadinessIO.cpp`** (`prqScore`, `verticalEstimateInches`, `hangTimeScale`, `kineticLeakageMultiplier`, …). See **`NEURO_MECHANIC_BRIDGE.md`**.
- Unreal **`AFELBasketballGameMode`** loads the snapshot at **`StartPlay`** and applies it to characters via **`ApplyReadiness`** + **`FELKineticLeakage`**.

### 4d. Further Unreal docs in repo

- **`UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md`**
- **`UNREAL_EXPORT_TO_XCODE.md`**
- **`IOS_PLAY_TEST_READINESS.md`** (what is playable in Swift today)

---

## 5. Paste this into Xcode AI chat if needed

You can paste the following so Xcode AI has context:

```
This is the Final Evolution Lab iOS app (Swift/SwiftUI + SceneKit). The project path is final-evolution-lab/ios/FinalEvolutionLab.xcodeproj and the scheme is FinalEvolutionLab. I need to run the latest build. Please remind me to: (1) Product → Clean Build Folder, (2) quit Xcode, (3) delete DerivedData for this project (folder starting with FinalEvolutionLab- in ~/Library/Developer/Xcode/DerivedData), (4) reopen the project, (5) Product → Build, (6) Product → Run. The app uses a PBXFileSystemSynchronizedRootGroup for the **Source** folder so all Swift files under **Source/** are included in the target. For cloud deploy checks, see **Config/FEL_CLOUD_DEPLOY_CHECKLIST.txt**.
```
