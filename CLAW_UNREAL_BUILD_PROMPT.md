# OpenClaw prompt — Unreal game + repo alignment

Paste into **OpenClaw** (or Cursor) with the repo root as workspace. This does **not** run automatically; it is the canonical prompt for agents.

---

## Context

- Repository: **Final Evolution Lab** — iOS shell target **`FinalEvolutionLabUnreal`** (display name **Final Evolution Lab - Unreal**), Xcode project **`FinalEvolutionLabUnreal.xcodeproj`**.
- Canonical gameplay: **Unreal Engine** — see **`UNREAL_ONLY.md`**, **`UnrealStarter/README.md`**, **`UnrealStarter/BasketballGame/`**, **`FEL_UE52_LevelSetup.md`**.
- Swift app **does not** embed Unreal like UnityFramework; UE ships as Epic’s **iOS** build or via Pixel Streaming / URL scheme. **`UnrealRuntimePlaceholderView`** in the app explains this.

## Task

1. In the user’s Unreal project (e.g. `~/Documents/Unreal Projects/MyProjec`), merge **`UnrealStarter`** C++ and content import paths; produce a **PIE** vertical slice: Arena + ball + hoop + readiness JSON.
2. Implement **Film Vault** (Media + UMG, dual sync) and **Evolution Stream** (HLS + instructor cues) **in Unreal** per product spec; keep parity notes for the Swift placeholders **`FilmVaultView`** / **`EvolutionStreamChannelView`**.
3. Document **build steps** for iOS packaging and how the native shell deep-links or launches the UE build.
4. Do **not** duplicate large game logic in Swift unless explicitly requested.

## Outputs

- Short **`BUILD_NOTES.md`** in the Unreal project (or repo) listing maps, game modes, and launch arguments.
- List of **content paths** that match `fel_setup_level.py` / `ASSET_PATHS`.

---

*Run OpenClaw locally with `cd ~/openclaw` and your usual `openclaw` CLI; point it at this repo path.*
