# Unreal: Build in Editor, Export to Xcode for iOS Testing

**Canonical Unreal project (in-repo):** `UnrealStarter/BasketballGame/FinalEvolutionLab.uproject` with module `Source/FinalEvolutionLab/` — open in UE 5.7, then **Generate Xcode Project** (or **File → Refresh Xcode Project**) for iOS. The **Swift/SwiftUI** app under `FinalEvolutionLab/` is the **legacy shell**; shipping gameplay is **Unreal-first** per **`UNREAL_ONLY.md`**.

If you have (or create) an Unreal project and want to run it in the Editor, then export to Xcode for iOS device/simulator testing, use the steps below.

**Run on a physical iPhone (step-by-step checklist):** **`UnrealStarter/RUN_UNREAL_ON_IPHONE_XCODE.md`**.

---

## 1. Finish and run the build in the Unreal Editor

1. **Open your Unreal project**  
   Double-click the `.uproject` file, or in Unreal Editor: **File → Open Project**.

2. **Build the project (compile C++)**  
   - **Ctrl+Alt+F11** (Windows) or **Cmd+Alt+F11** (Mac) for **Live Coding**, or  
   - **Tools → Refresh Visual Studio Project** (if you use it), then build from your IDE, or  
   - In Editor: **Build → Build [YourProject]** (if available).

3. **Run in Editor**  
   **Play** (e.g. **Alt+P** or the Play button) to confirm the game runs correctly in the Editor.

4. **Optional: Package for development**  
   **Platforms → Apple → iOS** (or **Platforms → Apple**) to open packaging options. For “export to Xcode” you typically use **Generate Xcode project** / **Export to Xcode**, not a full packaged build.

---

## 2. Export for iOS and generate Xcode project

1. **Switch to iOS**  
   In Unreal Editor: **Platforms → Apple → iOS** (or **Edit → Project Settings → Platforms → iOS**).

2. **Generate Xcode project**  
   - **File → Package Project → iOS** (or **Platforms → Apple → Package for iOS**) may offer “**Export to Xcode**” or “**Generate Xcode project**”, or  
   - Use **Launch** / **Export** so Unreal generates an Xcode workspace (`.xcworkspace`) or project.

3. **Output location**  
   Unreal usually writes to a folder like:  
   `[YourProject]/Saved/StagedBuilds/IOS/` or  
   `[YourProject]/Binaries/IOS/`  
   and creates an `.xcworkspace` you can open in Xcode.

4. **Metal toolchain (Mac)**  
   If you target iOS from Unreal on Mac, ensure the **Metal toolchain** is installed (see **METAL_TOOLCHAIN_UNREAL.md**). Xcode → Settings → Components → Metal Toolchain → Get.

---

## 3. Open in Xcode and run for testing

1. **Open the generated workspace**  
   In Finder, open the **`.xcworkspace`** (not only the `.xcodeproj`) Unreal created for iOS.

2. **Select scheme and destination**  
   - Scheme: your Unreal game target (e.g. **YourProject iOS**).  
   - Destination: **My Mac** (Designed for iPhone/iPad) or a connected **iPhone/iPad** or **iOS Simulator**.

3. **Build and run**  
   **Product → Build** (⌘B), then **Product → Run** (⌘R).

4. **If the build is stale**  
   **Product → Clean Build Folder** (⇧⌘K), then build and run again. For a nuclear clean you can delete DerivedData for that workspace.

---

## 4. Relation to this repo (Final Evolution Lab)

- **This repo:** iOS app **Final Evolution Lab** — Swift/SwiftUI, RealityKit dunk court, Arena UI. Build and run via **FinalEvolutionLabUnreal.xcodeproj** (see **XCODE_CLEAN_AND_RUN.md**).
- **Unreal:** Use **`UnrealStarter/BasketballGame/FinalEvolutionLab.uproject`** in this repo. Use the steps above to build in Editor and export to Xcode for iOS testing. Additional drop-in snippets (if any) are listed in **UnrealStarter/README.md**.

---

## Quick reference

| Step              | Action |
|-------------------|--------|
| Build in Editor   | Open `.uproject` → Build (e.g. Live Coding) → Play |
| Export to Xcode   | Platforms → Apple / iOS → Export / Generate Xcode project |
| Run on device     | Open generated `.xcworkspace` in Xcode → Select device → Run |
