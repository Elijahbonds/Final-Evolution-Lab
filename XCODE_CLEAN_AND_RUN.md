# Xcode: Run the Latest Build (Not the Old One)

This project is **Final Evolution Lab** — a **Swift/SwiftUI iOS app** with **SceneKit** 3D gameplay (Venice Beach, dunk contest, multi-sport Arena). It is **not** an Unreal Engine project; the gameplay runs in SceneKit inside this app.

- **Project:** `rork-final-evolution-lab/FinalEvolutionLab.xcodeproj`
- **Scheme:** **FinalEvolutionLab**
- **Target:** The app uses a **PBXFileSystemSynchronizedRootGroup** for the `FinalEvolutionLab` folder, so all Swift files under that directory are included in the target.

---

## Quick reminder: run the latest build

1. **Product → Clean Build Folder** (⇧⌘K)
2. **Quit Xcode** (⌘Q)
3. **Delete DerivedData** for this project: remove the folder starting with `FinalEvolutionLab-` in `~/Library/Developer/Xcode/DerivedData`
4. **Reopen** the project (`FinalEvolutionLab.xcodeproj`)
5. **Product → Build** (⌘B)
6. **Product → Run** (⌘R)

If Xcode is still showing an old build with no recent changes (no RFD/GRF education, Pop Force, Recovery Lab, etc.), follow the full steps below.

---

## 1. Confirm you have the right project open

- **File path:** `rork-final-evolution-lab/FinalEvolutionLab.xcodeproj`
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
   Open `FinalEvolutionLab.xcodeproj` (double‑click or from File → Open).

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

## 4. Unreal vs this repo

- **This repo:** One Xcode app (Swift/SwiftUI + SceneKit). All gameplay (Venice Court, dunk contest, sport modes) is in this codebase.
- **Unreal:** If you have a separate Unreal project, it is a different project. To run the **iOS app** with the latest changes, you must open and run **FinalEvolutionLab.xcodeproj** and follow the steps above.

---

## 5. Paste this into Xcode AI chat if needed

You can paste the following so Xcode AI has context:

```
This is the Final Evolution Lab iOS app (Swift/SwiftUI + SceneKit). The project path is rork-final-evolution-lab/FinalEvolutionLab.xcodeproj and the scheme is FinalEvolutionLab. I need to run the latest build. Please remind me to: (1) Product → Clean Build Folder, (2) quit Xcode, (3) delete DerivedData for FinalEvolutionLab (folder starting with FinalEvolutionLab- in ~/Library/Developer/Xcode/DerivedData), (4) reopen the project, (5) Product → Build, (6) Product → Run. The app uses a PBXFileSystemSynchronizedRootGroup for the FinalEvolutionLab folder so all Swift files under that directory are included in the target.
```
