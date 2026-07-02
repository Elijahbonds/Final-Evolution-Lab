# NEXUS Vision Alignment — Guardian Audit

**Audit date:** 2026-06-19 (sprint-vision-regression re-run)  
**Repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**Guardian mandate:** NEXUS-only production ship · world-class athlete OS · honest preview labeling · Cursor MCP + in-app agent control · integrated UX (scan→gen, agent commands, 9+ mode sims)

**Authority chain:** `NEXUS_ONLY_PIVOT.md` → `SHIPPING_ARCHITECTURE.md` → `DELIVERY_BAR_FINAL_EVOLUTION.md` → `NEXUS_QUALITY_BAR.md` → `NEXUS_DELIVERY_MATRIX.md`

---

## Vision pillars (user mandate)

| # | Pillar | Ship target | Acceptance doc |
|---|--------|-------------|----------------|
| 1 | **NEXUS-only retail** | C++20 engine + Swift iOS; no UE/Unity ship | `NEXUS_ONLY_PIVOT.md`, `SHIPPING_ARCHITECTURE.md` |
| 2 | **Athlete OS breadth** | Gameplay + economy + education + BioFuel + Studio IDE | `DELIVERY_BAR_FINAL_EVOLUTION.md` |
| 3 | **Honest preview labeling** | No fake ship / clinical / economy claims | `DELIVERY_BAR_FINAL_EVOLUTION.md` § Global |
| 4 | **Agent control plane** | In-app + Cursor MCP whitelisted tools | `docs/CURSOR_NEXUS_CONTROL.md`, `NEXUS_QUALITY_BAR.md` §4 |
| 5 | **Integrated UX bar** | Scan→gen, mode sims (≥7 mobile), agent launch | `NEXUS_QUALITY_BAR.md`, `docs/NEXUS_GAMEPLAY_UX_BAR.md` |

---

## Alignment score: **7.3 / 10**

| Dimension | Score | Notes |
|-----------|:-----:|-------|
| Engine + CI gates | 9/10 | Headless/full ctest green; iOS sim compile green; 14 production modes validate @ mobile |
| Architecture lock (canonical docs) | 8/10 | `SHIPPING_ARCHITECTURE`, `NEXUS_ONLY_PIVOT`, `NEXUS_DELIVERY_MATRIX` aligned |
| Entry-point doc honesty | 9/10 | **`AGENTS.md`**, **`README.md`** NEXUS-first; infra/milestone UE overclaims fixed (V-018, V-019, 2026-06-19) |
| Preview labeling (Swift UI) | 8/10 | 27+ views use `FELPreviewLabel` (2026-06-19 child-surface pass: marketplace, shard shop, cookbook, bio-fuel scan, DoorDash bridge, streaming, matchmaking, coach, system scan, HLS, drawing-in) |
| Registry / metadata honesty | 8/10 | `nexusMeshPath` + `legacyUeMapAlias`; 14 production modes aligned with validate script |
| Legacy runtime isolation | 9/10 | **Verified (sprint-vision-regression):** no Release-path `UnrealManager`/`UnityManager` dispatch outside `#if NEXUS_LEGACY`; flag absent from Release `SWIFT_ACTIVE_COMPILATION_CONDITIONS` → managers compiled out |
| TestFlight / ship artifact | 4/10 | Dry-run PASS; no signed `FEL.xcarchive` / IPA (Phase 8) |
| Agent IDE + MCP | 8/10 | Registry + `NEXUSAgentService` + MCP server present; labeled preview/beta |

**Composite:** Weighted toward **honest ship claims** and **agent-facing truth**. Engine + runtime isolation improved; remaining drag is TestFlight artifact gap (V-003). Cross-check: `NEXUS_QUALITY_BAR.md` composite **7.5/10** (engineering bar) vs this **7.3/10** (vision + honesty bar).

---

## Drift register (P0 → P3)

| ID | Pri | Category | Drift | Evidence | Status |
|----|:---:|----------|-------|----------|--------|
| V-001 | **P0** | Doc overclaim | `AGENTS.md` states UE 5.7 is primary shipping client | `AGENTS.md` L7–44 | **FIXED** (2026-06-19) |
| V-002 | **P0** | Doc overclaim | `README.md` opens with “Unreal Engine 5.7 game” before NEXUS | `README.md` L1–4 | **FIXED** (2026-06-19) |
| V-003 | **P0** | Ship artifact | No signed TestFlight archive / IPA on disk | `NEXUS_DELIVERY_MATRIX.md` Phase 8 | OPEN |
| V-004 | **P1** | Registry lie | `productionMapPath` fields are UE map paths; NEXUS ship uses `venueToken` + `.nexusmesh.json` | `arena_mode_registry.cpp` | **FIXED** (2026-06-19) — `nexusMeshPath` + `legacyUeMapAlias`; support `ecb78a50`: `productionMapPath` absent from `app/gameplay/` |
| V-005 | **P1** | Registry skew | C++ registry marks modes `kProduction` that validate script excludes (e.g. staging tiers) | `arena_mode_registry.cpp` vs `nexus_validate_production_modes.sh` | **FIXED** (2026-06-19) — 14 modes; `kProductionModeIds` constant; support `ecb78a50`: identical set vs validate script; staging modes (gymnastics, skateboarding, snowboarding, brain_brawl) excluded |
| V-006 | **P1** | Active legacy path | `SystemScanFirestoreSync` dispatches to `UnrealManager.shared` | `SystemScanFirestoreSync.swift` | **FIXED** (2026-06-19) — NEXUS bridge primary; UE gated `NEXUS_LEGACY` |
| V-007 | **P1** | Active legacy path | `CoreMotionHelper` sends JSON to `UnityManager` | `CoreMotionHelper.swift` | **FIXED** (2026-06-19) — Unity gated `NEXUS_LEGACY`; NEXUS-only preview log |
| V-008 | **P1** | Preview gap | `CommunityFeedView`, `DescribeArenaView`, `VaultView`, `BioFuelDashboardView`, `CreatorCardBoostView` — no `FELPreviewLabel` | Swift Views | **FIXED** (2026-06-19) |
| V-009 | **P2** | Comment drift | `GameSceneHostView` implied UE embed is active gameplay host | L206 comment | **FIXED** (2026-06-19) |
| V-010 | **P2** | Comment drift | `GameMode.swift` MARK references “Unreal 5.7 Mode Manager” | L527 | **FIXED** (2026-06-19) |
| V-011 | **P2** | Doc drift | `docs/NEXUS_GAMEPLAY_UX_BAR.md` cites “Unreal map path registry” as ahead | L149 | **FIXED** (2026-06-19) — competitive row: NEXUS venue registry (`nexusMeshPath` + venue tokens); support `9fd31de3` sprint-docs-v011 |
| V-012 | **P2** | DoD gap | Live Firebase session receipt POST (Spec v1 #4) | `NEXUS_DELIVERY_MATRIX.md` | OPEN |
| V-013 | **P2** | Renderer | Metal embed partial; SceneKit default for dunk/device | Phase 8 matrix | OPEN |
| V-014 | **P3** | Dead code | `UnrealContainerView` / `UnityContainerView` compiled, not navigated | grep — no call sites | ACCEPTABLE (archived) |
| V-015 | **P3** | CI | `fel-prebuild-ci.yml` deprecated but retained | workflow header | ACCEPTABLE |
| V-016 | **P3** | Mirror repo | `~/Documents/rork-final-evolution-lab` may lag canonical pivot | `NEXUS_ONLY_PIVOT.md` | OPEN (sync task) |
| V-017 | **P2** | Comment drift | Swift comments/UI still cite active UE bridge paths | `GameplaySessionReceiptCoordinator.swift`, `BondsStandardCoachView.swift`, `SystemScanFirestoreSync.swift` | **FIXED** (2026-06-19 sprint-vision-regression) |
| V-018 | **P2** | Doc overclaim | Infra docs describe `UnrealManager` as primary system-scan bridge | `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`, `infra/SWIFT_UNREAL_CONTAINER.md` | **FIXED** (2026-06-19) — NEXUS bridge primary; UE archived banner + `NEXUS_LEGACY` note |
| V-019 | **P2** | Doc overclaim | Milestone doc lists UE device embed (M4) as forward path | `docs/architecture/NEXUS_3D_Milestone.md` L72–74 | **FIXED** (2026-06-19) — M4 rewritten: Metal/SceneKit NEXUS path; UE archived |
| V-020 | **P3** | Stale mirror | `seeles_work/github_repos/Final-Evolution-Lab/` retains ungated UE/Unity dispatch | grep vs canonical | OPEN (archive or resync) |

---

## sprint-vision-regression — Release dispatch grep (2026-06-19)

```bash
cd /Users/elijahbonds/Final-Evolution-Lab
rg 'UnrealManager\.|UnityManager\.' FinalEvolutionLab --glob '*.swift'
rg 'NEXUS_LEGACY' FinalEvolutionLab --glob '*.swift'
```

**Result (canonical `FinalEvolutionLab/` only):**

| File | Dispatch | Gated? |
|------|----------|--------|
| `SystemScanFirestoreSync.swift` | `UnrealManager.shared.deliverSystemScanJSON` | ✅ `#if NEXUS_LEGACY` |
| `CoreMotionHelper.swift` | `UnityManager.shared.sendDataToUnity` | ✅ `#if NEXUS_LEGACY` |
| `UnrealContainerView.swift` | embed + screenshot hooks | ✅ entire file `#if NEXUS_LEGACY` |
| `UnityContainerView.swift` | embed + screenshot hooks | ✅ entire file `#if NEXUS_LEGACY` |
| `UnrealManager.swift` / `UnityManager.swift` | class bodies | ✅ entire file `#if NEXUS_LEGACY` |
| `FinalEvolutionLabApp.swift` | — | ✅ no manager init (removed) |
| `GameModeSelectionView.swift` | — | ✅ no manager references |
| `BondsStandardCoachView.swift` | UI caption only (no dispatch) | comment fixed |

**Release build note:** `NEXUS_LEGACY` is **not** listed in Release `SWIFT_ACTIVE_COMPILATION_CONDITIONS` (`project.pbxproj` — Debug only has `DEBUG`). Default App Store / Release compiles **exclude** all UE/Unity manager symbols. Opt-in legacy builds must define `NEXUS_LEGACY` explicitly.

**Non-trivial — doc overclaims UE ship (resolved 2026-06-19 vision_guardian pass):**

| File | Issue | Status |
|------|-------|--------|
| ~~`infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`~~ | ~~§ Native embedded framework still documents `UnrealManager.deliverSystemScanJSON` as post-write path~~ | **FIXED** (V-018) — NEXUS bridge primary |
| ~~`infra/SWIFT_UNREAL_CONTAINER.md`~~ | ~~Describes `UnrealManager` as runtime loading pattern without NEXUS-only banner~~ | **FIXED** (V-018) — archived banner + NEXUS production table |
| ~~`docs/architecture/NEXUS_3D_Milestone.md`~~ | ~~M4 "UE embed on device" milestone contradicts `NEXUS_ONLY_PIVOT.md`~~ | **FIXED** (V-019) — M4 Metal/SceneKit; UE archived |
| ~~`FinalEvolutionLab/EmbeddedFrameworks/README.md`~~ | ~~Operational UE framework drop instructions without archived banner~~ | **FIXED** (V-018) — archived banner + `NEXUS_LEGACY` note |
| `seeles_work/github_repos/Final-Evolution-Lab/**` | Stale fork: ungated `UnrealManager` in `SystemScanFirestoreSync`, `BodyIQEducationLabView`, `FinalEvolutionLabApp` | OPEN (V-020 — archive or resync) |

---

## What is aligned (keep)

- **`SHIPPING_ARCHITECTURE.md`**, **`NEXUS_ONLY_PIVOT.md`**, **`DELIVERY_BAR_FINAL_EVOLUTION.md`** — consistent NEXUS-only lock.
- **Engine gates:** `./scripts/nexus_build_gate.sh`, `./scripts/nexus_validate_production_modes.sh` (14 modes), `./scripts/build-nexus-ios.sh`.
- **Agent plane:** `Config/nexus_cursor_tool_registry.json`, `NEXUSAgentService.swift`, `tools/nexus-cursor-mcp/`.
- **Scan→gen:** `scan_envelope_mapper.cpp`, `ScanToGenerateView` with honest estimate copy.
- **Preview badges** on core arena surfaces: `GamePlayView`, `GameModeSelectionView`, `DashboardView`, `NexusStudioIDEView`, `ScanToGenerateView`.
- **Arena navigation** routes through `ArenaHubView` → `GameModeSelectionView` / NEXUS SceneKit — not `UnrealContainerView`.

---

## Guardian fixes applied (2026-06-19)

| File | Change |
|------|--------|
| `AGENTS.md` | NEXUS-only overview; UE/Unity marked archived; canonical build commands |
| `README.md` | NEXUS-first intro; UE demoted to legacy reference |
| `FinalEvolutionLab/Views/GameSceneHostView.swift` | Comment: SceneKit is NEXUS preview path (no UE ship claim) |
| `FinalEvolutionLab/Models/GameMode.swift` | MARK renamed: legacy mode-manager JSON compat (not UE ship) |
| `app/gameplay/include/nexus/gameplay/arena_mode_registry.h` | `nexusMeshPath` + `legacyUeMapAlias`; `kProductionModeIds` (14) |
| `app/gameplay/src/arena_mode_registry.cpp` | NEXUS mesh paths; court_carnival + who_scene_it → kProduction |
| `app/gameplay/src/fel_bridge_service.cpp` | Bridge JSON emits `nexus_mesh_path` + `legacy_ue_map_alias` |
| `FinalEvolutionLab/Models/GameMode.swift` | who_scene_it → `.production` |
| `FinalEvolutionLab/Views/VaultView.swift` | `FELPreviewLabel` — honest vault profile preview badge |
| `FinalEvolutionLab/Views/BioFuelDashboardView.swift` | `FELPreviewLabel` — bio-fuel stub badge |
| `FinalEvolutionLab/Views/CommunityFeedView.swift` | `FELPreviewLabel` — community feed preview badge |
| `FinalEvolutionLab/Views/DescribeArenaView.swift` | `FELPreviewLabel` — NEXUS generate preview badge |
| `FinalEvolutionLab/Views/CreatorCardBoostView.swift` | `FELPreviewLabel` — economy stub badge |
| Child economy / bio-fuel / streaming surfaces (2026-06-19) | `CardMarketplaceView`, `ShardShopView`, `CookbookView`, `BioFuelScannerView`, `DoorDashOrderBridgeView`, `StreamingPortalView`, `HlsPlayerView`, `MatchmakingView`, `CoachView`, `SystemScanView`, `DrawingInTutorialView` — honest `FELPreviewLabel` badges |
| `FinalEvolutionLab/Services/SystemScanFirestoreSync.swift` | Route system scan → `NexusGameplayBridge` + `fel.fitness.update`; UE gated `NEXUS_LEGACY` |
| `FinalEvolutionLab/Services/CoreMotionHelper.swift` | Unity relay gated `NEXUS_LEGACY`; NEXUS-only preview log when disabled |
| `FinalEvolutionLab/Services/GameplaySessionReceiptCoordinator.swift` | Doc comment: NEXUS receipt path primary; legacy UE JSON noted |
| `FinalEvolutionLab/Views/BondsStandardCoachView.swift` | Doc + caption: SceneKit/NEXUS preview; UE montages archived |
| `FinalEvolutionLab/Services/SystemScanFirestoreSync.swift` | Doc comment: NEXUS bridge primary (not "for UE") |
| `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md` | NEXUS bridge primary; UE `UnrealManager` under archived `NEXUS_LEGACY` subsection (V-018) |
| `infra/SWIFT_UNREAL_CONTAINER.md` | Archived banner; NEXUS production architecture table; UE embed demoted to legacy (V-018) |
| `FinalEvolutionLab/EmbeddedFrameworks/README.md` | Archived / NEXUS-only banner; `NEXUS_LEGACY` opt-in note (V-018) |
| `docs/architecture/NEXUS_3D_Milestone.md` | M4 rewritten: Metal/SceneKit NEXUS ship; UE embed archived (V-019) |

---

## Recommended retasks (other agents)

| Agent / owner | Task | Priority | Blocks |
|---------------|------|:--------:|--------|
| **iOS Ship** | Real `GoogleService-Info.plist` + `./scripts/archive-ios-testflight.sh --export` → signed IPA | P0 | V-003 |
| **iOS UX / Labeling** | Add `FELPreviewLabel` to Vault, BioFuel, Community feed, Describe arena, Creator Cards | P1 | ~~V-008~~ **DONE** |
| **NEXUS Integration** | Route `SystemScanFirestoreSync` → `NexusGameplayEngine` / bridge; remove `UnrealManager` dispatch | P1 | ~~V-006~~ **DONE** |
| **NEXUS Integration** | Retire `CoreMotionHelper` → Unity path; use NEXUS bridge or no-op in Release | P1 | ~~V-007~~ **DONE** |
| **Gameplay / Registry** | Align `ArenaReleaseState` with `nexus_validate_production_modes.sh`; rename or document `productionMapPath` | P1 | ~~V-004, V-005~~ **DONE** |
| **Backend / Receipts** | Wire live Firebase POST for session receipts (DoD #4) | P2 | V-012 |
| **Renderer** | Device Metal dunk + Instruments 60 FPS proof | P2 | V-013 |
| **Docs** | Fix `NEXUS_GAMEPLAY_UX_BAR.md` competitive row (NEXUS registry, not UE maps) | P2 | ~~V-011~~ **DONE** |
| **Mirror sync** | Port pivot docs + `AGENTS.md` fixes to `rork-final-evolution-lab` | P3 | V-016 |

---

## Verification (re-run before milestone tags)

```bash
cd /Users/elijahbonds/Final-Evolution-Lab
./scripts/nexus_build_gate.sh
./scripts/nexus_validate_production_modes.sh
./scripts/build-nexus-ios.sh
ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 ./scripts/archive-ios-testflight.sh --dry-run
```

---

*Next guardian audit: after TestFlight archive exists, any change to `SHIPPING_ARCHITECTURE.md` / arena registry, or if `NEXUS_LEGACY` is added to Release build settings.*
