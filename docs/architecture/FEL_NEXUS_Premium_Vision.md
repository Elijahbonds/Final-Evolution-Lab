# FEL × NEXUS — Premium Vision (Spec v1)

> One-page north star for **world-class** Final Evolution Lab on NEXUS.  
> Tied to `FEL_NEXUS_Cursor_Spec_v1.pdf` (2026-06-19) and `FEL_NEXUS_Spec_v1_Implementation_Plan.md`.

---

## Executive summary

| Layer | Premium score | Sprint target |
|-------|---------------|---------------|
| **NEXUS Engine** | **74 / 100** | **92+** after M1 Metal + mobile gate |
| **FEL iOS App** | **61 / 100** | **90+** after M2 receipt UX + M3 TestFlight |

**Smoke (2026-06-19):** `./scripts/smoke_v1.sh --skip-build` → **PASS** (ctest 5/5, Venice + Dojo validate, dunk → receipt queued).

**Spec v1 DoD:** **5 / 9** met. Critical path: Metal embed (#1, #2) → Firebase receipt (#4) → TestFlight (#9).

### Path to 90+ in two sprints

| Sprint | Focus | Engine Δ | App Δ |
|--------|-------|----------|-------|
| **Sprint A** (v1.1 M1 + M2) | Metal venue on `CAMetalLayer`, `NEXUS_MESH_PROFILE=mobile` on iOS, live receipt POST, unified palette, HUD ownership | +14 → **88** | +22 → **83** |
| **Sprint B** (v1.1 M3 + polish) | Metal PBR parity, receipt success animation, TestFlight + device FPS gate, scan-to-play PRQ entry polish | +6 → **94** | +10 → **93** |

Detail rubrics: [NEXUS_Premium_Quality_Rubric.md](./NEXUS_Premium_Quality_Rubric.md) · [FEL_Premium_Quality_Rubric.md](./FEL_Premium_Quality_Rubric.md)

---

## What “world class” means for FEL

FEL is not a mini-game shell — it is an **athletic optimization product** where every session is measurable, every venue is iconic, and creative AI extends the world after play.

### 1. Scan-to-play

User flow: **body scan / exercise demo → PRQ fitness gate → curated arena**. Spec §2 ties MRI/HealthKit to `PRQScoring.swift` (app) and `prq_engine.*` (C++ stub at 75). Premium means:

- PRQ readout is visible before first dunk (not buried in settings).
- Failed gate offers coaching, not a dead end.
- Session receipt carries PRQ delta for progression UI.

### 2. Venice arenas

**Venice Beach** is the canonical P0 venue (`basketball_dunk`). World class = photographic coastal identity at **60 FPS on iPhone 12 class hardware**:

- Engine: manifest-driven mesh, `NEXUS_MESH_PROFILE=mobile` → ≤80k tris (`venice_beach_court_model_fbx_mobile.nexusmesh.json`).
- App: SceneKit preview **migrates to Metal** (`GameSceneHostView` → `CAMetalLayer` + `MetalRenderer`) so the same asset path renders on device as in `nexus_runtime` validate-only.
- 17 additional modes share venue registry (`arena_mode_registry.cpp` / `GameMode.swift`) with consistent FEL holographic accent lighting.

### 3. PRQ fitness

Performance Readiness Quotient links gameplay to real athletic data. Premium bar:

- HUD surfaces pacing / combo / critical hits aligned with C++ `fel.hud.poll` (Swift `NexusHUDSnapshot`).
- Receipt JSON includes telemetry envelope for backend PRQ reconciliation.
- Biomechanics overlay (`showBiomechanicsHUD`) is opt-in, not competing with score chrome.

### 4. LLM creative mode

Spec §7 creative commands (`fel.creative.*`) mutate voxel terrain post-session. Premium means:

- Creative mode is a **reward layer** after verified receipt, not a debug console.
- Agent TCP :9090 + generative pipeline stay headless; Swift gets summarized outcomes only.
- Venice voxel seed matches arena column height from renderer (`arena_scene` / `VoxelWorld`).

---

## Cross-cutting integration checklist

### A. Engine dev HUD ↔ App HUD — no conflict

| Layer | Today | Premium rule |
|-------|-------|--------------|
| Engine | `dev_stats` logs every 120 frames (`engine.cpp`); `HudRelayService` emits `fel.hud.frame` JSON (WS stub) | **Production embed:** log-only dev stats; no on-screen engine HUD |
| App | SwiftUI `hudBar` + optional biomechanics panel; `NexusGameplayEngine` polls `nexus_gameplay_session_hud_poll_json()` | **Single SoT:** C++ poll for P0/P1; Swift never double-writes score |
| Relay | `FELHUDRelayClient` when `FEL_HUD_WS_URL` set | Dev/backend only; disabled in Release TestFlight |

**Action:** Document mode matrix in `IOS_RUNBOOK.md`: NEXUS-linked modes ignore SceneKit `DunkEngine` score paths. Gate engine overlay behind `NEXUS_DEV_HUD=1` (runtime) — never set on iOS embed.

### B. Mobile mesh profile on iOS path

| Stage | Status |
|-------|--------|
| Desktop / CI | `asset_manifest.cpp` resolves `imported_mesh_mobile`; `NEXUS_MESH_PROFILE=mobile` validated in renderer tests |
| iOS today | `GameSceneHostView` uses **SceneKit** procedural Venice — does **not** load `*_mobile.nexusmesh.json` |
| Target | `MetalRenderer::render()` + manifest load with `meshProfilePrefersMobile()` forced at iOS link; retire SceneKit for P0/P1 |

**SceneKit → Metal migration (v1.1 M1):**

1. Add `NexusMetalHostView` (`UIView` + `CAMetalLayer`) beside `GameSceneHostView`.
2. Bridge calls `MetalRenderer::initialize` / `render` with venue from `arena_mode_registry`.
3. Set `NEXUS_MESH_PROFILE=mobile` in Xcode scheme / `Info.plist` build setting for Release.
4. Keep SceneKit for P2 “Coming Soon” modes until sims land.
5. Verify: Instruments GPU ≤16.6 ms frame on iPhone 12; tri count ≤80k post-cull.

### C. Receipt flow — premium success on upload

| Step | Today | Premium |
|------|-------|---------|
| Session end | `nexus_gameplay_session_end_arena` → receipt JSON | Same |
| Persist | `~/.fel/pending_receipts/*.json` | Same |
| Upload | `SessionReceiptUploadService.uploadPendingReceipts()` on launch + post-session | Same + retry/backoff |
| UX | Silent ingest via `GameplaySessionReceiptCoordinator` | **Celebration:** checkmark burst, PRQ delta ticker, haptic, 1.2s before dismiss |
| Trust | `GameSessionTrustLevel.server_verified` on HTTP 200 | Show “Verified” badge on history card |

**Gap:** No SwiftUI success animation today; coordinator applies payload without user-visible delight.

### D. Unified color palette (engine clear + SwiftUI theme)

Canonical FEL tokens (sRGB 0–1):

| Token | SwiftUI `Theme` | Engine / SceneKit | Use |
|-------|-----------------|-------------------|-----|
| `deepBlack` | `(0.02, 0.02, 0.02)` | SCN background `(0.02, 0.02, 0.04)` | App chrome, letterbox |
| `brandBlue` | `(0, 0.83, 1.0)` | `GameSceneFactory.brandBlue` | Primary accent, links |
| `brandCyan` | `(0, 0.95, 0.9)` | `GameSceneFactory.brandCyan` | HUD highlights, active state |
| `metalClear` | — | Metal `MTLClearColorMake(0.06, 0.09, 0.14, 1.0)` | Viewport letterbox until PBR |
| `elitePurple` | `(0.6, 0.2, 1.0)` | — | Combo / elite tier |

**Action:** Add `docs/design_reference/FEL_Color_Tokens.json` (single source); generate `Theme.swift` constants and `metal_renderer.mm` clear color from it. Align SceneKit `deepBlack` alpha with `Theme.deepBlack`.

---

## Spec v1 alignment (quick map)

| Spec pillar | Repo anchor | Premium gap |
|-------------|-------------|-------------|
| P0 Dunk | `dunk_contest_mode.*`, iOS touch bridge | Metal venue |
| P1 Karate | `karate_endless_mode.*` | Combat UX polish |
| Menu → receipt | `GameModeSelectionView` → `SessionReceiptUploadService` | Success animation + live POST |
| 60 FPS Venice | `NEXUS_Performance_Targets.md` | iOS profile + device proof |
| Creative LLM | `generative_pipeline`, `fel.creative.*` | Post-receipt UX shell |

---

## Top 5 cross-cutting actions (coordinator)

1. **HUD ownership matrix** — C++ poll SoT for P0/P1; disable SceneKit score + engine dev overlay in embed builds.
2. **iOS mobile mesh** — Force `NEXUS_MESH_PROFILE=mobile` in Metal host; wire manifest path in `GameSceneHostView` successor.
3. **Receipt celebration** — SwiftUI success animation + PRQ delta on `SessionReceiptUploadService` HTTP 200.
4. **Palette single source** — `FEL_Color_Tokens.json` → Theme + Metal clear + SceneKit backgrounds.
5. **Two-sprint ship gate** — Sprint A: Metal + Firebase POST; Sprint B: TestFlight + Instruments FPS + receipt polish → both layers **90+**.

---

*Coordinator: Premium Quality · Branch `anti-gravity-fel` · Do not commit from agent loop.*
