# NEXUS Migration Audit — UE/Unity → NEXUS Only

**Audit date:** 2026-06-19  
**Authority:** `NEXUS_ONLY_PIVOT.md`, `SHIPPING_ARCHITECTURE.md`, `NEXUS_DELIVERY_MATRIX.md`  
**Repos audited:**

| Role | Path |
|------|------|
| **Canonical (production ship)** | `/Users/elijahbonds/Final-Evolution-Lab` |
| **Legacy mirror (reference)** | `/Users/elijahbonds/Documents/rork-final-evolution-lab` |

**Mandate:** Retail ship is **NEXUS only** (C++20 engine + Swift iOS). UE 5.7 and Unity 6 are archived — do not delete large trees; deprecate, gate, and label honestly.

**P0 code fixes applied this pass (canonical repo only):** See §6.

---

## 1. Active UE/Unity reference inventory

### 1.1 Swift iOS — user-touchable (both repos unless noted)

| Artifact | Canonical | Legacy mirror | Active behavior |
|----------|:---------:|:-------------:|-----------------|
| `UnrealManager.swift` | ✅ | ✅ | Loads `UnrealFramework.framework`; JSON bridges (scan, Body IQ, neuro tuning) |
| `UnityManager.swift` | ✅ | ✅ | Unity embed stub; screenshot fallback |
| `UnrealContainerView.swift` | ✅ (P0 fixed) | ✅ | Full-screen UE host; **canonical now shows “UE ARCHIVED” + NEXUS back** |
| `UnityContainerView.swift` | ✅ | ✅ | Unity host shell (no retail path) |
| `GameModeSelectionView.swift` | ✅ (P0 fixed) | ✅ | **Legacy:** every mode card → neural scan → UE embed if framework present. **Canonical:** routes to `GamePlayView` / NEXUS only |
| `GamePlayView.swift` | ✅ (P0 fixed) | ✅ | SceneKit + `NexusGameplayEngine`; canonical adds `PREVIEW · NEXUS` toolbar badge |
| `DashboardView.swift` | ✅ (P0 fixed) | ✅ | Neural sync card; **canonical** uses `NexusGameplayBridge.isLinked` |
| `BodyIQEducationLabView.swift` | ✅ (P0 fixed) | ✅ | Movement snack UI; **canonical** queues NEXUS preview (no `deliverBodyIQSnackJSON`) |
| `ShareToFeedView.swift` | ✅ (P0 fixed) | ✅ | **Legacy/canonical pre-fix:** UE/Unity screenshots. **Canonical:** layout card only |
| `BondsStandardCoachView.swift` | ✅ | ✅ | SceneKit reference; docstring cites UE montages |
| `FinalEvolutionLabApp.swift` | ✅ | ✅ | Starts `UnrealManager` Firebase observer on launch |
| `GameplaySessionReceiptCoordinator.swift` | ✅ | ✅ | Parses UE/Emergent JSON receipts |
| `SystemScanFirestoreSync.swift` | ✅ | ✅ | Pushes scan JSON toward UE bridge |
| `CoreMotionHelper.swift` | ✅ | ✅ | Comments reference UE motion relay |
| `SettingsSheet.swift` | ✅ | ✅ | **Unity Bridge** manifest export UI |
| `UnityExportManifest.swift` | ✅ | ✅ | Unity export builder |
| `NativeBridgeManager.swift` | ✅ | ✅ | `simulateUnityScore` helper |
| `TrainingLabSocialBridge.swift` | ✅ | ✅ | Feed posts cite `requiredUnrealAnimationAssetID` |
| `GameMode.swift` | ✅ | ✅ | Subtitle fallback `"Unreal Engine 5.7 Mode"`; mode comments cite UE maps |
| `MovementSnackEngine.swift` | ✅ | ✅ | `unrealCorrectivePoseAssetID`, `requiredUnrealAnimationAssetID` field names |
| `FELPreviewLabel.swift` | ✅ | ❌ | Honest preview badges — **canonical only** |

### 1.2 Swift / ObjC — NEXUS bridge (canonical; keep)

| Artifact | UE lineage | Status |
|----------|------------|--------|
| `NexusGameplayEngine.swift` | Ports `FELGameplayManager` fel.* protocol | **Active ship path** |
| `Bridge/NexusGameplayBridge.mm` | Replaces UE ObjC host | **Active** |
| `FELNativeBridge.swift` / `FELNativeSwiftBridge.swift` | Emergent/UE WS naming | Review for rename |

### 1.3 Root scripts — UE cook/package (canonical)

| Script | Action |
|--------|--------|
| `fel_ue5_ios_shipping_package.sh` | **deprecate** — archived; not retail |
| `fel_ue5_win64_cook_only.sh` | **deprecate** |
| `fel_ue5_mac_package.sh` | **deprecate** |
| `infra/deprecated/fel_ue5_eagle3d_linux_package.sh` | **keep-reference** (already under `deprecated/`) |
| `scripts/setup_fel_migration.py` | **deprecate** — copies from `UnrealIntegration/` |
| `prepare_fel_bridge.sh` | **deprecate** |
| `infra/fel_prebuild_ci_check.sh` | **migrate** — still resolves `UnrealStarter/.../*.uproject` |
| `infra/fix_ios_descriptor_path.sh` | **deprecate** — UE IPA descriptor |

**Legacy mirror** duplicates the above plus `scripts/fel_ue5_safe_cleanup.sh`, `scripts/fel_release_preflight.sh`.

### 1.4 CI / release infra

| Artifact | Repo | Issue |
|----------|------|-------|
| `.github/workflows/fel-prebuild-ci.yml` | Both | **DEPRECATED** — UE checks disabled; manual `workflow_dispatch` only |
| `.github/workflows/nexus-build-gate.yml` | Both | **NEXUS ship CI (authoritative)** — runs `./scripts/nexus_build_gate.sh` on push/PR |
| `.github/workflows/nexus-ci.yml` | Canonical | **NEXUS ship CI** — path-filtered headless + renderer matrix (keep) |
| `infra/SHIPPING.md` § Legacy UE | Canonical | Documents UE scripts as archived (good) but §173–186 still lists UE troubleshooting steps |
| `fastlane/Fastfile` | Both | NEXUS-neutral (IPA upload) — **keep** |
| `backend/tests/test_iteration5_quality_gates.py` | Both | Asserts Pixel Streaming / `DefaultEngine.ini` UE sections |

### 1.5 Archived trees (do not delete)

| Tree | Files (approx) | Status |
|------|----------------|--------|
| `UnrealIntegration/` | ~55 C++/INI/TSX | **keep-reference** — port source for NEXUS |
| `UnrealStarter/BasketballGame/` | Config + Content JSON | **keep-reference** — venue registry, ArenaSettings |
| `Unity6-FinalEvolutionLab/` | README only (canonical) | **keep-reference** |
| `infra/ue5_config/` | ExportOptions, DefaultEngine.ini snippets | **keep-reference** |
| `seeles_work/` | Historical UE reviews | **delete-safe** only after explicit archive policy |

### 1.6 Deep links → UE maps

| Mechanism | Location | Retail status |
|-----------|----------|---------------|
| `fel://play/{mode}` → `UFELDeepLinkSubsystem` | `UnrealIntegration/.../FELDeepLinkSubsystem.{h,cpp}` | **Not wired in iOS Swift** — no `onOpenURL` handler found |
| `finalevolution://` URL scheme | `DefaultEngine.FEL_iOS_URL_scheme.snippet.ini` | **Keep** — pivot doc preserves scheme for NEXUS |
| INI `[FELButtonArenaMode]` / `[FELPlayMap]` | `DefaultGame.FEL_full_ship.snippet.ini` | **P2 port** to JSON config (`NEXUS_UE_Port_Plan.md`) |
| `ArenaSettings.json` / `FEL_VenueRegistry.production.json` | `UnrealStarter/BasketballGame/` | **migrate** data into `assets/nexus/` manifests |

### 1.7 Web / frontend (canonical)

| Artifact | UE reference | Action |
|----------|--------------|--------|
| `frontend/src/components/FELOSDashboard.js` | “UE5 Bridge”, “Live Combat — UE5” | **migrate** copy to NEXUS |
| `frontend/src/App.js` | Low/no direct UE | **keep** |

### 1.8 NEXUS C++ — intentional UE port comments (keep)

Headers under `app/gameplay/include/nexus/gameplay/` cite UE origins (`FELBridgeSubsystem`, `FELHudRelaySubsystem`, etc.). These are **keep-reference** lineage comments, not active UE dependencies.

---

## 2. Per-file action matrix

**Legend:** `migrate` = wire to NEXUS · `deprecate` = label/archive, no retail use · `delete-safe` = removable without ship impact · `keep-reference` = archived tree/docs · `keep` = production

### 2.1 Swift iOS (`FinalEvolutionLab/`)

| File | Action | Notes |
|------|--------|-------|
| `Views/GameModeSelectionView.swift` | **migrate** | P0: UE launch bypassed; remove dead `showEmbeddedUnreal` in follow-up |
| `Views/GamePlayView.swift` | **keep** | NEXUS + SceneKit; P0 preview badge added |
| `Views/GameSceneHostView.swift` | **migrate** | `NEXUS_USE_METAL` flag; Metal path partial |
| `Views/UnrealContainerView.swift` | **deprecate** | P0: archived panel; retain for reference builds |
| `Views/UnityContainerView.swift` | **deprecate** | No retail entry |
| `Services/UnrealManager.swift` | **deprecate** | P0 header comment; stop app-init observer in P1 |
| `Services/UnityManager.swift` | **deprecate** | P0 header comment |
| `Services/NexusGameplayEngine.swift` | **keep** | Canonical has fuller HUD poll than legacy mirror |
| `Bridge/NexusGameplayBridge.mm` | **keep** | |
| `Views/DashboardView.swift` | **migrate** | P0: NEXUS link indicator |
| `Views/BodyIQEducationLabView.swift` | **migrate** | P0: NEXUS cue queue; port education to C++ P2 |
| `Views/ShareToFeedView.swift` | **migrate** | P0: no UE capture |
| `Views/BondsStandardCoachView.swift` | **migrate** | Update footer copy |
| `Views/SettingsSheet.swift` | **deprecate** | Hide Unity export behind DEBUG |
| `Services/GameplaySessionReceiptCoordinator.swift` | **migrate** | Prefer `SessionReceiptUploadService` |
| `Services/SystemScanFirestoreSync.swift` | **migrate** | Route scan to NEXUS bridge only |
| `Services/TrainingLabSocialBridge.swift` | **migrate** | Rename UE asset IDs in feed copy |
| `Models/GameMode.swift` | **migrate** | Change UE subtitle fallback |
| `Models/MovementSnackEngine.swift` | **migrate** | Rename `unreal*` fields → `nexus*` (breaking; P2) |
| `Utilities/FELPreviewLabel.swift` | **keep** | Copy to legacy mirror |
| `FinalEvolutionLabApp.swift` | **migrate** | Remove `UnrealManager` observer when bridge complete |
| `EmbeddedFrameworks/README.md` | **deprecate** | States UE embed instructions |

### 2.2 Scripts & CI

| File | Action |
|------|--------|
| `fel_ue5_*.sh` (root) | **deprecate** → move to `infra/deprecated/` |
| `scripts/nexus_build_gate.sh` | **keep** |
| `scripts/build-nexus-ios.sh` | **keep** |
| `scripts/archive-ios-testflight.sh` | **keep** |
| `infra/fel_prebuild_ci_check.sh` | **migrate** → NEXUS-only checks |
| `.github/workflows/fel-prebuild-ci.yml` | **deprecated** — UE gates disabled; see `nexus-build-gate.yml` |
| `.github/workflows/nexus-build-gate.yml` | **keep** — authoritative push/PR gate |
| `scripts/setup_fel_migration.py` | **deprecate** |

### 2.3 Archived UE/Unity trees

| Path | Action |
|------|--------|
| `UnrealIntegration/` | **keep-reference** |
| `UnrealStarter/` | **keep-reference** |
| `Unity6-FinalEvolution-Lab/` | **keep-reference** |
| `infra/ue5_config/` | **keep-reference** |
| `infra/UNITY6_MIGRATION_RULES.md` | **keep-reference** |

### 2.4 Docs

| File | Action |
|------|--------|
| `NEXUS_ONLY_PIVOT.md` | **keep** |
| `NEXUS_DELIVERY_MATRIX.md` | **keep** |
| `SHIPPING_ARCHITECTURE.md` | **keep** |
| `infra/SHIPPING.md` | **migrate** — trim UE troubleshooting § to appendix |
| `docs/architecture/NEXUS_UE_Port_Inventory.md` | **keep-reference** |
| `AGENTS.md` (legacy mirror) | **migrate** — already notes NEXUS canonical |

### 2.5 Legacy mirror drift (sync from canonical)

| Gap | Priority |
|-----|----------|
| Missing `FELPreviewLabel.swift` | P1 |
| `GameModeSelectionView` still forces neural scan → UE on every mode | **P0** (fixed in canonical only) |
| Thinner `NexusGameplayEngine` (no HUD poll / receipt flush) | P1 |
| Missing `SessionReceiptUploadService`, `NexusEconomyAuthority` | P1 |
| `FEL_DELIVERY_MATRIX.md` / `FEL_CONTENT_UX_MATRIX.md` untracked | P2 docs |

---

## 3. User-facing flows still pointing at UE — fix priority

| Flow | Entry | Current behavior | Priority | Fix |
|------|-------|------------------|----------|-----|
| **Arena mode pick → play** | `GameModeSelectionView` | Legacy mirror: neural scan → UE embed. Canonical: **P0 fixed** → `GamePlayView` | **P0** | Sync legacy mirror; delete dead UE cover |
| **In-match gameplay** | `GamePlayView` / `GameSceneHostView` | SceneKit preview (Metal optional); NEXUS C++ score authority for P0/P1 modes | **P0** | Fix `sprintPriorityBadge` compile error; enable Metal embed |
| **UE full-screen host** | `UnrealContainerView` | “START UNREAL” if framework embedded | **P0** | Canonical shows archived panel (**done**) |
| **Body IQ → corrective montage** | `BodyIQEducationLabView` | “SEND TO UNREAL” | **P0** | Canonical → “QUEUE NEXUS CUE” (**done**) |
| **Dashboard neural sync** | `DashboardView` | Linked = UE/Unity loaded | **P0** | Canonical → `NexusGameplayBridge.isLinked` (**done**) |
| **Share training screenshot** | `ShareToFeedView` | UE/Unity `takeScreenshot()` | **P1** | Canonical uses layout card (**done**); add SceneKit capture |
| **App launch side effects** | `FinalEvolutionLabApp` | `UnrealManager.startFirebaseIdentityObservation()` | **P1** | Gate behind `#if FEL_REFERENCE_UE` or remove |
| **System scan debug** | `DashboardView` DEBUG card | Copy cites UnrealManager | **P2** | Canonical copy updated (**done**) |
| **Settings Unity export** | `SettingsSheet` | Unity manifest export | **P2** | Hide behind DEBUG |
| **Social feed posts** | `TrainingLabSocialBridge` | “UE {animationAsset}” in post body | **P2** | Rename to NEXUS education asset |
| **Bonds Standard coach** | `BondsStandardCoachView` | Footer cites UnrealManager | **P2** | Update copy |
| **Web FELOS dashboard** | `FELOSDashboard.js` | “UE5 Bridge” UI | **P2** | Rebrand to NEXUS |
| **Deep link `fel://play/`** | UE subsystem only | Not exposed in Swift | **P3** | Implement `DeepLinkService` when multi-venue travel ships |
| **Pixel Streaming / E3DS** | `fel_ue5_*`, backend tests | Dev-only streaming host | **P3** | Archive; not retail |

---

## 4. Quality gaps vs `NEXUS_DELIVERY_MATRIX.md`

| Matrix item | Target | Actual (2026-06-19) | Gap |
|-------------|--------|---------------------|-----|
| **DoD #1** Dunk on iPhone sim | Metal NEXUS embed | SceneKit fallback; Metal partial | **High** — user sees SceneKit, not Metal venue |
| **DoD #2** Venice 60 FPS | Device proof | Desktop validate only | **High** |
| **DoD #3** Touch → dunk → score | PASS | PASS via NEXUS fel.dunk.* | ✅ |
| **DoD #4** Session receipt → Firebase | Live POST | Disk queue only | **High** |
| **DoD #5** Karate Endless | PASS | PASS | ✅ |
| **DoD #6** Mode menu both modes | PASS | PASS | ✅ |
| **DoD #7** No engine exceptions | PASS | PASS | ✅ |
| **DoD #8** ctest | 6/6 | PASS | ✅ |
| **DoD #9** TestFlight candidate | Signed archive | Dry-run only | **Critical** |
| **Phase 8 Metal iOS** | PBR embed | Wireframe manifest draw | **High** |
| **Phase 5 Shadows** | GPU resolve | Preview flags only | Medium |
| **Phase 10 Perf** | Instruments | Budget ctest only | Medium |
| **iOS xcodebuild** | Clean compile | `GameModeSelectionView.swift:376` `sprintPriorityBadge` scope error | **P0 blocker** |
| **UE parity rubric** | 5.0 / 5 | ~3.6 / 5 | Audio, multiplayer, tooling open |

**Swift layer honesty:** Until Metal + TestFlight ship, all arena surfaces must show **PREVIEW · NEXUS** (canonical P0 pass adds badges to mode select, gameplay, feed, education).

---

## 5. Recommended fix order (10 steps)

1. **Fix iOS compile blocker** — `sprintPriorityBadge` scope in `GameModeSelectionView.swift` (per delivery matrix).
2. **Remove retail UE entry points** — delete/gate `showEmbeddedUnreal` code path; stop `UnrealManager` app-init in `FinalEvolutionLabApp` (canonical P0 partial).
3. **Sync legacy mirror P0** — copy `FELPreviewLabel`, `GameModeSelectionView` NEXUS routing, and preview badges to `rork-final-evolution-lab`.
4. **Metal embed default** — flip `GameSceneHostView` to NEXUS Metal when `NexusMetalBridge` linked; SceneKit as explicit fallback only.
5. **Session receipt live POST** — wire `SessionReceiptUploadService` to production Firebase/API (DoD #4).
6. **TestFlight archive** — real `GoogleService-Info.plist` + `./scripts/archive-ios-testflight.sh --export`.
7. **CI pivot** — replace `fel-prebuild-ci.yml` UE checks with `nexus_build_gate.sh` + iOS sim build. **✅ COMPLETE (2026-06-19)** — `nexus-build-gate.yml` on push/PR; `fel-prebuild-ci.yml` deprecated.
8. **Deprecate root `fel_ue5_*.sh`** — move to `infra/deprecated/`; update `infra/SHIPPING.md` appendix.
9. **Port deep-link config** — `FELDeepLinkSubsystem` INI → JSON consumed by iOS + NEXUS (`NEXUS_UE_Port_Plan.md` step 1).
10. **Frontend + social copy sweep** — `FELOSDashboard.js`, `TrainingLabSocialBridge`, `GameMode.swift` UE strings → NEXUS.

---

## 6. P0 fixes applied (canonical repo — 2026-06-19)

| File | Change |
|------|--------|
| `FinalEvolutionLab/Views/GameModeSelectionView.swift` | `launchNexusGameplay()` always routes to `GamePlayView`; `FELPreviewLabel` on arena header; UE cover commented archived; removed duplicate `sprintPriorityBadge` |
| `FinalEvolutionLab/Views/UnrealContainerView.swift` | Placeholder → “UE ARCHIVED” + `PREVIEW · NEXUS ONLY` + back button |
| `FinalEvolutionLab/Views/BodyIQEducationLabView.swift` | “QUEUE NEXUS CUE”; NEXUS copy; no `UnrealManager.deliverBodyIQSnackJSON` |
| `FinalEvolutionLab/Views/DashboardView.swift` | Neural sync uses `NexusGameplayBridge.isLinked`; DEBUG copy updated |
| `FinalEvolutionLab/Views/ShareToFeedView.swift` | No UE/Unity screenshot; `PREVIEW · NEXUS FEED` badge |
| `FinalEvolutionLab/Views/GamePlayView.swift` | `PREVIEW · NEXUS` toolbar badge |
| `FinalEvolutionLab/Services/UnrealManager.swift` | Archived header comment |
| `FinalEvolutionLab/Services/UnityManager.swift` | Archived header comment |
| `FinalEvolutionLab/FinalEvolutionLabApp.swift` | Comment on legacy UE observer |
| `FinalEvolutionLab/Services/GameplaySessionReceiptCoordinator.swift` | NEXUS receipt path comment |
| `.github/workflows/nexus-build-gate.yml` | **New** — push/PR runs `./scripts/nexus_build_gate.sh` (headless + renderer ctest) |
| `.github/workflows/fel-prebuild-ci.yml` | **Deprecated** — UE identifier/UPROJECT checks removed; points to `nexus-build-gate.yml` |

**Not changed (per mandate):** No deletion of `UnrealIntegration/`, `UnrealStarter/`, or `fel_ue5_*.sh` trees.

---

## 7. Top blockers (ship-critical)

| # | Blocker | Owner surface |
|---|---------|---------------|
| 1 | **iOS compile failure** — duplicate `sprintPriorityBadge` in `GameModeCard` (**fixed 2026-06-19**) | Xcode / Swift |
| 2 | **No signed TestFlight IPA** — DoD #9 FAIL | `archive-ios-testflight.sh` + signing |
| 3 | **Session receipts disk-only** — no live Firebase POST (DoD #4) | `SessionReceiptUploadService` |
| 4 | **Metal renderer partial** — SceneKit still primary arena viewport | `GameSceneHostView` / `NexusMetalBridge` |
| 5 | **Legacy mirror P0 drift** — users building from `rork-final-evolution-lab` still hit UE mode flow | Mirror sync |
| 6 | ~~**CI still validates UE**~~ — **resolved 2026-06-19** via `nexus-build-gate.yml` | GitHub Actions |

---

*Re-run `./scripts/nexus_build_gate.sh` and iOS `xcodebuild` after each migration tranche. Update this audit when legacy mirror is synced or UE trees are moved under `infra/deprecated/`.*
