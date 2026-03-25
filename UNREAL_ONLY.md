# Final Evolution Lab — Unreal-Only Architecture

**Canonical direction:** The **Unreal Engine project** is the single **runtime**, **UI shell**, and **shipping client** for Final Evolution Lab. **iOS and console are both first-class products** — same Unreal game, packaged per platform (with tuning for mobile vs. console). Swift/SwiftUI under `FinalEvolutionLab/` is an **older prototype shell**, not the intended ship path for the App Store build.

This document is the **source of truth** for agents and humans: **new features ship in Unreal** (C++ / Blueprint / UMG / Media).

---

## Why Unreal-only

| Concern | Unreal |
|--------|--------|
| Arena, physics, character, Venice/Luma | Native |
| Film review, dual video, telestrator | **Media Framework** + UMG / HUD + render targets |
| Live/VOD instruction | **Media Player** (HLS/DASH URLs) + UI; backend unchanged |
| iOS / desktop / console | **Single codebase** via UE packaging (same gameplay, per-platform tuning) |

Swift is **not** required for gameplay, film vault, or streaming UI when those live in-engine.

---

## Repository layout (mental model)

| Path | Role |
|------|------|
| **`UnrealStarter/`** | **Active.** C++ snippets, editor Python, import docs, BasketballGame module — merge into **your** `.uproject` (e.g. `~/Documents/Unreal Projects/MyProjec`). |
| **`FinalEvolutionLab/`** | **Frozen / reference.** Prior iOS shell; do not extend for new product features unless you deliberately split platforms again. |
| **Root markdown** (`PITCH_DECK.md`, `VISION_ALIGNMENT.md`, etc.) | Product + planning; implementation lands in **Unreal**. |

---

## Feature migration map (conceptual)

| Former idea (multi-stack) | Unreal implementation |
|---------------------------|------------------------|
| Film Vault dual player | Two `MediaPlayer` / `MediaTexture` or twin `FileMediaSource` players; **UMG** for layout; sync via shared timeline or replicated seek |
| Vector / joint overlays | **Canvas**-style: `UUserWidget` custom paint, **Slate** `OnPaint`, or material on quad over video |
| Analyst checkpoints JSON | `FJsonObject` / `UDataTable` / `UDataAsset` rows; load from `Content/` or HTTP |
| Instructor stream | `StreamMediaSource` or URL in `MediaPlayer`; WebSocket plugin or HTTP for `REP_GOAL`-style signals |
| XP / progress | `UGameInstanceSubsystem` or **SaveGame** + your backend; same design as any UE title |
| Readiness / PRQ bridge | Already sketched in `BasketballGame/` (e.g. readiness I/O) — extend in C++ |

---

## Phased work (recommended)

1. **Lock the UE project** — One `.uproject` under version control (or separate repo) with `UnrealStarter` code merged and building.
2. **One vertical slice** — Open level → Elijah pawn → ball + hoop logic from `BasketballGame/` (see `PACKAGE_AND_TEST.md`).
3. **Film Vault v0** — Single `MediaPlayer` full-screen + pause/seek; then add second player + sync.
4. **Deprecate parallel Swift features** — No new tabs in iOS for features that exist in UE; document parity gaps in this file if any.

---

## Agent / Cursor instructions

When implementing Final Evolution Lab features:

- **Default target:** Unreal C++ / Blueprint / UMG under the user’s UE project + files in **`UnrealStarter/`**.
- **Do not** add large Swift modules for arena, film, or stream unless the task explicitly says “iOS native.”
- Follow **`.cursorrules`** (UE 5.2+ C++ standard) for engine code.

---

## Swift codebase status

The **`FinalEvolutionLab`** Xcode target remains in the repo as **historical / reference** code (ideas, UI experiments, data models). It is **not** the canonical way to ship **iOS** — that is **Unreal’s iOS target** (same game as console/PC). If you need Apple-only APIs (e.g. HealthKit), prefer **Unreal plugins** or a **minimal** native bridge; you still do **not** need a separate “side” app.

**Removing** the Swift tree is a **manual product decision** (archive, export, then delete). This doc does not delete it automatically.

---

*Last updated: canonical Unreal-only direction for Final Evolution Lab.*
