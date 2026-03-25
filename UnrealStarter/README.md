# Unreal Starter: Player Controller (drop-in for Cursor + UE5)

**Canonical runtime:** Final Evolution Lab is **Unreal-first**. New features belong in your UE project + this folder. The Swift iOS app in `FinalEvolutionLab/` is **legacy / reference** — see repo root **`UNREAL_ONLY.md`**.

**Start here for “why this exists”:** **`VISION_ALIGNMENT.md`** — north star from **`PITCH_DECK.md`** (measure → train → play, PRQ, readiness-gated Arena/Lab, one ecosystem, same avatar/data path for console/desktop/mobile via UE), honest scope of the Venice/Luma + Elijah + modes lab, guardrails, and ordered integration steps with pointers to **`app-synopsis.md`**.

**Product vision (one line):** Unreal assets and C++ here are **Final Evolution Lab Arena / sim** infrastructure — not a separate game IP. The basketball slice in **`BasketballGame/`** is **FEL Gaming Labs** content, fed by the same readiness story as the product (historically mirrored in Swift; **source of truth is now UE**).

These files are **starter C++ for Unreal Engine 5.2+** that you can drop into your project and edit with Cursor. They follow the Unreal Coding Standard and the rules in the repo root `.cursorrules`.

**Version / import notes:** See **`UE52_COMPATIBILITY.md`** (GLB plugins, OBJ fallback, Enhanced Input).

**Full scene setup (Luma env + props + Elijah):** **`IMPORT_CHECKLIST.md`** (steps) · **`FEL_UE52_LevelSetup.md`** (detail) · **`EditorPython/fel_setup_level.py`**.

**Basketball game modes (C++):** **`BasketballGame/`** — game mode, Elijah pawn, physics ball, Venice + Luma level notes.

**Test / package builds:** **`BasketballGame/PACKAGE_AND_TEST.md`** · **`scripts/package_fel_mac.sh`** · **`EditorPython/fel_quick_playtest_level.py`** (minimal map for cook).

## Where to put the files

1. In your Unreal project, open **Source/YourProjectName/** (e.g. `Source/FinalEvolutionLab/`).
2. Copy:
   - `FELPlayerController.h` → `Source/YourProjectName/Player/FELPlayerController.h`
   - `FELPlayerController.cpp` → `Source/YourProjectName/Player/FELPlayerController.cpp`
3. Rename the class/module if needed (e.g. `FEL` → your project prefix).
4. Add the module to your `.Build.cs` if you introduce new dependencies (e.g. `"EnhancedInput"`).
5. In the Editor: **Project Settings → Input → Default Classes** (or your Game Mode) set **Default Pawn Class** / **Player Controller Class** to `AFELPlayerController`, or create a Blueprint that inherits from it.

## Live Coding

After dropping the files in:

- Build from the Editor (**Ctrl+Alt+F11** or **Live Coding** button) so the new class is compiled.
- Keep Live Coding enabled so Cursor’s C++ edits hot-reload without restarting the engine.

## Cursor tips

- Point Cursor’s indexer at your project’s **Source** folder so it can see engine and project APIs.
- When asking for changes, say: *"Use Unreal Coding Standard"* or *"Follow our .cursorrules for UE5."*
- For new UPROPERTY/UFUNCTION, ask for **EditAnywhere** / **BlueprintReadOnly** / **BlueprintCallable** as needed.

## Optional: Input (Enhanced Input)

If your project uses **Enhanced Input**, uncomment the `#include` and the `InputMappingContext` / `InputAction` UPROPERTYs in the header, and the `SetupInputComponent` block in the .cpp. Then assign your IMC and IA assets in the Blueprint or defaults.
