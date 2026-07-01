# NEXUS content gaps (manifest vs FEL_ModeManager.production.json)

Last audited: 2026-06-27

## Abacus / Seele ingest inventory (Phase 2 — NEXUS AI Studio migration)

Abacus AI Studio exports land as **Seele CDN FBX URLs** recorded in `seeles_work/assets/models/<asset_id>/<asset_id>.json`. The NEXUS import path is `python3 scripts/nexus_import_assets.py --download --convert --mobile --update-manifest` (or `--from-gltf` for Meshy/Luma GLB drops).

### `~/Downloads/` scan (last 30 days — 2026-06-27)

| file | size | pipeline? | notes |
|------|------|-----------|-------|
| `GoogleService-Info.plist` | 895 B | no | Firebase iOS config duplicate |
| `GoogleService-Info (1).plist` | 895 B | no | same SHA as above — not a mesh asset |
| `app.ipa` | 71 MB | no | iOS build artifact |
| `fel_gdd_analysis.pdf` | 97 KB | no | GDD analysis doc (Abacus session output) |
| `fel_gdd_analysis.docx` | 29 KB | no | same GDD analysis |

**No `.fbx`, `.glb`, `.gltf`, Meshy, or Luma mesh exports** matched the ingest globs in Downloads. Firebase plists and GDD docs are **out of scope** for `assets/nexus/` — route Firebase config through `FinalEvolutionLab/GoogleService-Info.plist` / Xcode target, not the mesh pipeline.

### `seeles_work/assets/models/` cross-reference (48 descriptors)

| bucket | count | in `nexus_asset_manifest.json` | status |
|--------|-------|----------------------------------|--------|
| environment_fbx (venues) | 17 | 13 | **13 shipped**; 4 alternate/legacy IDs below |
| character / avatar FBX | 10 | 0 | pending — no NEXUS avatar rig yet |
| prop FBX / GLB | 18 | 0 | pending — gameplay props not wired |
| sports_prop | 2 | 0 | pending |
| procedural / marker | 1 | 1 | `demo_venue_marker` |

**Alternate environment IDs (Seele descriptors present, manifest uses canonical id):**

| seele descriptor id | manifest asset_id | same FEL venue | action |
|---------------------|-------------------|----------------|--------|
| `links_golf_course_environment_model_fbx` | `golf_course_environment_model_fbx` | Links_Golf_Court / golf | skip — superseded export |
| `sand_volleyball_court_environment_model_fbx` | `volleyball_sand_court_environment_model_fbx` | Sand_Court / volleyball | skip — naming alias |
| `training_floor_environment_model_fbx` | `gymnastics_floor_environment_model_fbx` | Training_Floor / gymnastics | skip — superseded export |
| `luma_venice_market_model_fbx` | `luma_venice_shop_environment_model_fbx` | Luma_Venice_Shop / market_browse | skip — shop variant consolidated |

**Abacus session marker:** `.abacus.donotdelete` in mirror repo only (encrypted blob) — not a mesh drop.

### Canonical `assets/nexus/` on-disk (post-ingest)

| path | count | notes |
|------|-------|-------|
| `source/*.fbx` | 13 | Seele CDN downloads checked in |
| `imported/*_mobile.nexusmesh.json` | 13 | mobile LOD sidecars (iOS ship path) |
| `imported/*.nexusmesh.json` (desktop) | 2 full + 11 symlinks → mobile | Venice + gymnastics retain full desktop mesh |
| `imported/demo_venue_marker.nexusmesh.json` | 1 | pipeline QA |
| `imported/movement_lab_preview_placeholder.nexusmesh.json` | 1 | preview stub, unassigned |

Mirror repo (`rork-final-evolution-lab`) trails canonical: desktop `.nexusmesh.json` without `_mobile` sidecars or symlinks — **do not import from mirror**; canonical is source of truth.

## Imported environment asset inventory

All generative venue FBX exports (Seele pipeline: tripo3D / hunyuan3D) and the Luma Venice shop are converted to `*_mobile.nexusmesh.json` and assigned in `nexus_asset_manifest.json`. **No Meshy-branded exports are checked in** — future Meshy GLB drops use the same `nexus_import_assets.py --from-gltf` path documented in `docs/architecture/NEXUS_Asset_Pipeline.md`.

| asset_id | source | generator | assigned mode(s) | bundled iOS |
|----------|--------|-----------|------------------|-------------|
| `venice_beach_court_model_fbx` | seele | tripo3D | basketball_h2h, basketball_dunk, basketball_3v3, court_carnival, **surfing (proxy)** | yes |
| `zen_dojo_environment_model_fbx` | seele | hunyuan3D | karate_h2h, karate_endless | yes |
| `baseball_park_environment_model_fbx` | seele | tripo3D | baseball | yes |
| `gridiron_stadium_environment_model_fbx` | seele | tripo3D | football | yes |
| `soccer_stadium_environment_model_fbx` | seele | hunyuan3D | soccer | yes |
| `golf_course_environment_model_fbx` | seele | tripo3D | golf | yes |
| `tennis_court_environment_model_fbx` | seele | tripo3D | tennis | yes |
| `volleyball_sand_court_environment_model_fbx` | seele | tripo3D | volleyball | yes |
| `gymnastics_floor_environment_model_fbx` | seele | tripo3D | gymnastics | yes |
| `skate_park_environment_model_fbx` | seele | tripo3D | skateboarding | yes |
| `mountain_slope_environment_model_fbx` | seele | hunyuan3D | snowboarding | yes |
| `neuro_arena_environment_model_fbx` | seele | tripo3D | brain_brawl, who_scene_it | yes |
| `luma_venice_shop_environment_model_fbx` | luma | tripo3D | market_browse (non-game) | yes |
| `demo_venue_marker` | procedural | — | pipeline QA only | yes |
| `movement_lab_preview_placeholder` | procedural | — | **unassigned** (preview stub) | yes (copy-all) |

**Orphaned on disk:** `movement_lab_preview_placeholder.nexusmesh.json` only — not in manifest `venues[]`.

## Production modes (18) — manifest coverage

| mode_id | status | venue_key | environment_asset_id | validate-only (mobile) |
|---------|--------|-----------|----------------------|-------------------------|
| basketball_h2h | production | venice_beach_court | venice_beach_court_model_fbx | OK (80k tris) |
| basketball_dunk | production | venice_beach_court | venice_beach_court_model_fbx | OK |
| basketball_3v3 | production | venice_beach_court | venice_beach_court_model_fbx | OK |
| court_carnival | production | venice_beach_court | venice_beach_court_model_fbx | OK |
| karate_h2h | production | dojo_arena | zen_dojo_environment_model_fbx | OK |
| karate_endless | production | dojo_arena | zen_dojo_environment_model_fbx | OK |
| baseball | production | stadium_diamond | baseball_park_environment_model_fbx | OK |
| football | production | stadium_field | gridiron_stadium_environment_model_fbx | OK |
| soccer | production | stadium_pitch | soccer_stadium_environment_model_fbx | OK |
| golf | production | golf_green | golf_course_environment_model_fbx | OK |
| tennis | production | venice_beach_court_tennis | tennis_court_environment_model_fbx | OK |
| volleyball | production | beach_court | volleyball_sand_court_environment_model_fbx | OK |
| gymnastics | production | arena_floor | gymnastics_floor_environment_model_fbx | OK |
| surfing | production | venice_beach_surf | venice_beach_court_model_fbx | OK (Venice proxy — see below) |
| skateboarding | production | skate_park | skate_park_environment_model_fbx | OK |
| snowboarding | production | mountain_slope | mountain_slope_environment_model_fbx | OK |
| brain_brawl | production | neuro_arena | neuro_arena_environment_model_fbx | OK |
| who_scene_it | production | neuro_arena | neuro_arena_environment_model_fbx | OK |

All **18** production modes resolve a venue + environment mesh in `nexus_asset_manifest.json`, have `*_mobile.nexusmesh.json` on disk, are copied into the iOS app bundle (`Bundle NEXUS venue assets` run script), and pass `NEXUS_MESH_PROFILE=mobile ./scripts/nexus_validate_production_modes.sh`.

### Surfing — Venice Beach proxy (intentional gap)

`surfing` uses a **distinct venue key** (`venice_beach_surf`) but shares the **Venice court environment mesh** until a dedicated surf-break export ships.

| Field | Value |
|-------|-------|
| **Venue key** | `venice_beach_surf` |
| **FEL venue id** | `Venice_Beach_Surf` |
| **Mesh loaded** | `venice_beach_court_model_fbx_mobile.nexusmesh.json` (same asset as basketball Venice modes) |
| **Why proxy** | No Seele/Luma surf-break FBX or UE glTF export checked in; gameplay uses wave/surf physics on the shared beach backdrop |
| **Ship impact** | Validate-only and bundle resolution **PASS**; visual fidelity is court-centric, not surf-specific geometry |
| **Upgrade path** | 1) Export surf break from UE → `assets/nexus/source/venice_beach_surf.glb` 2) `python3 scripts/nexus_import_assets.py --from-gltf … --mobile --update-manifest --asset venice_beach_surf_environment_model_fbx` 3) Point `venues[].environment_asset_id` for `venice_beach_surf` at the new asset id |

### Venice Beach Luma backdrop (composite — 2026-06-27)

Venice gameplay modes composite the **playable court mesh** with the **Luma Venice shop scan** as a distant ambient skyline layer. The shop mesh is a **visual proxy** for a full Venice Beach Luma photogrammetry scan until a dedicated beach-wide export ships.

| Field | Value |
|-------|-------|
| **Venue keys** | `venice_beach_court`, `venice_beach_surf`, `venice_beach_court_tennis` |
| **Playable surface** | `venice_beach_court_model_fbx_mobile.nexusmesh.json` |
| **Backdrop layer** | `luma_venice_shop_environment_model_fbx_mobile.nexusmesh.json` via manifest `backdrop_asset_id` |
| **Metal path** | Hybrid `MTKView` renders court + decimated Luma backdrop (`engine/renderer/scene.cpp` `attachVenueBackdrop`) |
| **SceneKit fallback** | `GameSceneFactory.addVeniceLumaBackdrop` — sky dome + procedural shop silhouettes when `NEXUS_USE_SCENEKIT=1` or Metal init fails |
| **Modes wired** | `basketball_h2h`, `basketball_dunk`, `basketball_3v3`, `court_carnival`, `surfing`, `tennis` (+ `venice_pickup` alias) |
| **Triangle budget** | Backdrop auto-decimated so court + backdrop ≤ 130k tris (mobile validate-only) |
| **Upgrade path** | Import dedicated Luma beach scan → new asset id → replace `backdrop_asset_id` (optional new `venice_beach_luma` venue key if surf/court diverge) |

### All-mode atmospheric backdrop (2026-06-27)

Every **18 production modes** use layered 3D depth: Metal renders the bundled `*_mobile.nexusmesh.json` playable venue; hybrid SceneKit overlay retains `atmosphericBackdrop_*` nodes + player rig (see `GameSceneFactory.attachAtmosphericBackdrop`).

| Cluster | mode_ids | Primary mesh (mobile) | Backdrop layer | Luma photogrammetry? |
|---------|----------|----------------------|----------------|----------------------|
| Venice | basketball_h2h, basketball_dunk, basketball_3v3, court_carnival, surfing, tennis | `venice_beach_court_model_fbx` or mode venue mesh | `luma_venice_shop_environment_model_fbx` (Metal manifest) + procedural shop row (SceneKit) | **Yes** — only checked-in Luma scan |
| Dojo | karate_h2h, karate_endless | `zen_dojo_environment_model_fbx` | Procedural zen sky + torii + mist (SceneKit overlay) | No — Luma-tier depth without scan claim |
| Stadium | baseball, football, soccer | `baseball_park` / `gridiron_stadium` / `soccer_stadium` | Procedural stand tiers + night sky | No — Seele FBX + procedural |
| Golf | golf | `golf_course_environment_model_fbx` | Procedural horizon sky + tree line | No |
| Beach | volleyball | `volleyball_sand_court_environment_model_fbx` | Procedural ocean + palms | No |
| Board | gymnastics, skateboarding, snowboarding | respective env meshes | Procedural gym truss / urban skyline / alpine peaks | No |
| Neuro | brain_brawl, who_scene_it | `neuro_arena_environment_model_fbx` | Procedural cognitive glow rings | No |

**Future Luma import:** `luma_venice_market_model_fbx` descriptor in `seeles_work/assets/models/` — consolidated into `luma_venice_shop_environment_model_fbx`; re-import via `python3 scripts/nexus_import_assets.py --download --convert --mobile --update-manifest`.

Handoff: `artifacts/coord/all_modes_luma_environments_handoff.json`.

## Staging modes — none (promoted 2026-06-19)

Former staging modes (`gymnastics`, `skateboarding`, `snowboarding`, `brain_brawl`) are **production** in `arena_mode_registry.h`, `nexus_validate_production_modes.sh`, and `FEL_ModeManager.production.json`. `nexus_validate_staging_modes.sh` reports **0** modes.

## Non-game modes — mesh present, not production-shipped

| mode_id | status | venue_key | notes |
|---------|--------|-----------|-------|
| market_browse | non-game-module | vault_shop | Luma Venice shop mesh loads in Metal; **visual browse only** — no scoring/session receipt; PRQ weight 0 |

## Documented gaps (no NEXUS venue mesh)

| mode_id | status | FEL venue_id | gap |
|---------|--------|--------------|-----|
| movement_lab | preview | Movement_Lab | Education overlay only; **not** in `nexus_asset_manifest.json` `venues[]`. Preview mesh stub on disk only (see below). UE map `/Game/FEL/Venues/MovementLab/MovementLab`. |

### movement_lab preview stub (non-production)

- **Status:** `preview` / `scoring_enabled: false` in `backend/FEL_ModeManager.production.json` — excluded from `production_modes` and from `nexus_validate_production_modes.sh`.
- **On-disk placeholder:** `assets/nexus/imported/movement_lab_preview_placeholder.nexusmesh.json` (4-tris synthetic marker). **Not** registered in the manifest; **not** used by `--validate-only`. Bundled by the copy-all `*.nexusmesh.json` script but unused at runtime.
- **Ship claim:** No production venue until manifest + mobile sidecar + validate-only pass exist for `movement_lab`.

## Venues (16)

15 environment venues + 1 non-game shop (`vault_shop`). All **13** unique environment assets have `*_mobile.nexusmesh.json` sidecars within the 80k tri mobile budget (zen_dojo: 60k cap).

Desktop canonical paths (`{id}.nexusmesh.json`) symlink to mobile sidecars where full-resolution desktop exports are not checked in (UE-less shipping path).

## App bundle checklist

| Check | Expected |
|-------|----------|
| Manifest in bundle | `assets/nexus/manifests/nexus_asset_manifest.json` |
| Imported meshes | **28** `assets/nexus/imported/*.nexusmesh.json` (13 env × desktop+mobile + marker + movement_lab stub) |
| Production mode mesh refs | **18/18** resolve under `NEXUS_RESOURCE_ROOT` |
| Verify command | `./scripts/nexus_validate_production_modes.sh` → **PASS (18 modes)** |
