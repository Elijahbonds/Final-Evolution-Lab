# Phase 4 — Shell integration: Swift ↔ Unreal

**Goal:** One clear product story: the **Swift** app’s Arena uses **SceneKit** for a fast in-app lab; **full Luma/Venice** ships in the **Unreal** iOS build (or Pixel Streaming). Users must not confuse the two.

---

## What ships in code

| Piece | Location |
|-------|-----------|
| **Preference** | `FELArenaRuntimePreference` — `UserDefaults` keys `felArenaRuntimePreference`, optional `felArenaPixelStreamingURL` |
| **Settings UI** | `SettingsSheet` → **Arena experience** picker + optional streaming URL |
| **In-session banner** | `GamePlayView` — when preference is **Full Simulation (Unreal)**, explains the lightweight native preview and links optional `https` stream |
| **Deep link (optional)** | `FinalEvolutionLabApp.onOpenURL` — `fel://arena/lab`, `fel://arena/unreal` (see § Register URL scheme) |

---

## Unreal / native bridge (reference)

- **`FELNativeBridge`** (`UnrealStarter/BasketballGame/Source/FinalEvolutionLab/`) — `FEL_IOS_*` stubs; full embed is a separate integration.
- **Device / paths:** `UnrealStarter/RUN_UNREAL_ON_IPHONE_XCODE.md` (RunUAT → Xcode → device).
- **Pixel Streaming:** point the optional URL field at your signalling/player page (`https://…`).

---

## Register `fel://` URL scheme (Xcode)

For `onOpenURL` to receive `fel://arena/…`:

1. Open **`ios/FinalEvolutionLab.xcodeproj`** → target **FinalEvolutionLab** → **Info** → **URL Types**.
2. Add **Identifier** e.g. `com.fel.arena`, **URL Schemes** `fel`, **Role** Editor.

Test in Safari: `fel://arena/unreal` should switch preference to Full Unreal (after cold launch handling).

---

## Phase 4 exit

- [ ] Settings shows **Lightweight Arena (native)** vs **Full Simulation (Unreal)** with honest copy (Phase 8 product story).
- [ ] Optional Pixel Streaming URL opens from the Arena banner when set.
- [ ] Deep link documented + optional URL type registered.
- [ ] No claim that SceneKit *is* Luma — banner when user picks Unreal path.

*See:* `DOCS/FEL_UNREAL_AND_SCENKIT_10_PHASE_PASS.md` — Phase 4.
