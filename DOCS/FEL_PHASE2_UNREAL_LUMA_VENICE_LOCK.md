# Phase 2 — Unreal: Luma / Venice content lock

**Goal:** Canonical **Venice Beach** court + **Luma** shell (scaled if needed) and a cookable **`Luma_Venice_Shop`** map for **`market_browse`**, aligned with `FELDigitalTwinVenuePaths` and `MapsToCook`.

**Canonical paths (already in code):**

- Street basketball: `FELDigitalTwinVenuePaths::VeniceBeachArena` → `/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach`
- Shop: `FELDigitalTwinVenuePaths::LumaVeniceShop` → `/Game/FEL/Venues/Luma_Venice_Shop.Luma_Venice_Shop`
- Luma capture UUID (analytics / hotspots): `FELLumaCaptureIds::LumaVeniceShop` in `FELDigitalTwinVenuePaths.h`

---

## 1. Import Meshy / Luma sources (editor)

1. **Luma scan** — `UnrealStarter/LumaScan/mesh.obj` + `textures/` → `/Game/FEL/Environment/Luma/`, rename mesh to **`SM_LumaCourt`** (or match `fel_setup_level.py` / `IMPORT_CHECKLIST.md`).
2. **Venice court** — `UnrealStarter/MeshyAssets/Venice_beach_UE5/Venice_mesh.obj` + textures → `/Game/FEL/Environment/Venice/`, **`SM_VeniceCourt`**.
3. **HoopBus ball + Elijah** — per `UnrealStarter/IMPORT_CHECKLIST.md` → `/Game/FEL/Props/`, `/Game/FEL/Characters/ElijahBonds/`.
4. **Compose** Venice + Luma in **`VeniceBeach`** level per `UnrealStarter/BasketballGame/VENICE_LUMA_LEVEL.md` (Luma footprint ~4 m — **scale up** if the shell should read larger).

---

## 2. Ensure maps exist

- If **no** `.umap` files are under `Content/FEL/Venues/` yet, run **`EditorPython/fel_clinical_placeholder_venues.py`** (see `Content/FEL/Venues/VENUE_SETUP.txt`) so **MapsToCook** targets exist and packaging does not fail.
- Replace placeholders with real geometry when art is ready.

---

## 3. Shop level (`market_browse`)

- Build or placeholder-save **`/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop`** so `OpenLevel` matches `ArenaSettings.json` and `FELDigitalTwinVenuePaths::LumaVeniceShop`.
- Optional: uncomment **`+DirectoriesToAlwaysCook`** for `/Game/FEL/Environment/Luma` | `Venice` in `CONFIG_DefaultGame_FEL.ini` after imports (merge into `DefaultGame.ini` for packaging).

---

## 4. Verify

- **Repo (no editor):** `bash UnrealStarter/scripts/verify_fel_phase2_venue_paths.sh`
- **Editor:** PIE on **VeniceBeach** and **Luma_Venice_Shop**; confirm `GameDefaultMap` in `Config/DefaultEngine.ini` points at a valid map.
- **Mobile:** After cook, `fel_luma_venue_texture_presave.py` / Gold Master stamp path when you enable platform texture rules (`scripts/package_gold_master.sh`).

---

## 5. Phase 2 exit (dual-track doc)

- Cook list includes **VeniceBeach** + **Luma_Venice_Shop** (already in `DefaultGame.ini`).
- Primary art: Luma + Venice composed in **VeniceBeach**; shop map loads for **`market_browse`**.

*See also:* `DOCS/FEL_UNREAL_AND_SCENKIT_10_PHASE_PASS.md` Phase 2.
