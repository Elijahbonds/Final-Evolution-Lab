# FEL — Dual track: Unreal (Luma) + SceneKit iOS — 10-phase pass

**Intent:** Advance **both** (1) the **canonical Unreal** client with Luma/Venice environments and shippable iOS builds, and (2) the **legacy Swift/SceneKit** shell so daily TestFlight / demos stay credible until Unreal fully owns Arena.

**Principles**

| Track | Role |
|--------|------|
| **Unreal** (`UnrealStarter/BasketballGame/`) | Long-term ship: Luma imports, `Luma_Venice_Shop` / Venice maps, packaging, UMG/HUD. See `UNREAL_ONLY.md`. |
| **SceneKit** (`ios/FinalEvolutionLab/`, `GameSceneFactory.swift`) | Short-term: larger arenas, clearer art pass, mode-consistent scenes — **not** a substitute for importing Luma meshes into UE. |

**Cross-links:** `IMPORT_CHECKLIST.md`, `VENICE_LUMA_LEVEL.md`, `UnrealStarter/RUN_UNREAL_ON_IPHONE_XCODE.md`, `UnrealStarter/scripts/verify_fel_build_matrix.sh`, `UnrealStarter/scripts/verify_fel_phase10_signoff.sh`, `UnrealStarter/scripts/verify_fel_phase10_dual_track_static.sh`, `UnrealStarter/scripts/verify_fel_phase5_scenekit.sh`, `UnrealStarter/scripts/verify_fel_phase6_arena_modes.sh`, `UnrealStarter/scripts/verify_fel_phase7_mobile_tuning.sh`, `UnrealStarter/scripts/verify_fel_phase8_product_story.sh`, `UnrealStarter/scripts/verify_fel_phase9_automation.sh`, `DOCS/FEL_PHASE10_DUAL_TRACK_SIGNOFF.md`, `DOCS/CHANGELOG_FEL_DUAL_TRACK.md`.

---

## Phase 1 — Inventory & entry points (both)

**Unreal**

- Confirm `Content/FEL/Venues/` maps referenced by `ArenaSettings.json` / `FELArenaVenueTravel` exist or are listed in `VENUE_SETUP.txt` / `fel_clinical_placeholder_venues.py`.
- List **MapsToCook** in `Config/DefaultGame.ini` vs actual `.umap` paths (no black screen on OpenLevel).

**SceneKit**

- Map each `GameMode` → `GameSceneFactory.buildScene(for:)` branch; note floor bounds (`addArenaWalls` width/depth/height) per mode.
- Document where `GameSceneHostView` is presented from `LabView` / navigation.

**Exit:** Short table in this doc (or team wiki): “mode → UE level path” and “mode → SceneKit scene recipe.”

### Phase 1 inventory (repo snapshot)

**Unreal — `ArenaSettings.json` → `unrealOpenLevelPackage`**

| Mode key (`modes`) | UE package (OpenLevel) |
|--------------------|-------------------------|
| `basketball_h2h`, `basketball_dunk`, `basketball_3v3` | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| `karate` | `/Game/FEL/Venues/Dojo/Dojo` |
| `baseball` | `/Game/FEL/Venues/BaseballPark/BaseballPark` |
| `football` | `/Game/FEL/Venues/Gridiron/Gridiron` |
| `soccer` | `/Game/FEL/Venues/SoccerStadium/SoccerStadium` |
| `golf` | `/Game/FEL/Venues/Links/Links` |
| `tennis` | `/Game/FEL/Venues/TennisCourt/TennisCourt` |
| `volleyball` | `/Game/FEL/Venues/SandCourt/SandCourt` |
| `gymnastics` | `/Game/FEL/Venues/TrainingFloor/TrainingFloor` |
| `brain_brawl` | `/Game/FEL/Venues/NeuroArena/NeuroArena` |
| `surfing`, `skateboarding` | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| `snowboarding` | `/Game/FEL/Venues/TrainingFloor/TrainingFloor` |
| `market_browse` | `/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop` |

**MapsToCook** (`Config/DefaultGame.ini`) lists the same 11 venue roots as `fel_clinical_placeholder_venues.py` `VENUES` (VeniceBeach … Luma_Venice_Shop). **On-disk `.umap` files:** none under `UnrealStarter/BasketballGame/Content/FEL` in this clone — run `EditorPython/fel_clinical_placeholder_venues.py` (or batch) before cook so packaging does not fail (`VENUE_SETUP.txt`).

**SceneKit — `GameModeId` → `GameSceneFactory.buildScene(for:)`**

| `GameModeId` | Builder | Floor / play footprint (approx.) | `addArenaWalls` (W×D×H m) |
|--------------|---------|-----------------------------------|---------------------------|
| `basketballHeadToHead` | `buildBasketballScene` | Court box 10×6.25 (Phase 5 scale) | *(none — `addVeniceBeachWalls`)* |
| `basketballDunkContest` | `buildDunkContestScene` | Court 15×10 + runway | *(none — `addVeniceBeachWalls`)* |
| `basketball3v3` | `build3v3Scene` | Court 12.5×7.5 | *(none — `addVeniceBeachWalls`)* |
| `karate` | `buildDojoScene` | Tatami 6×6 | 12 × 12 × 5 |
| `baseball` | `buildBaseballScene` | Outfield 16×14 | 16 × 14 × 5 |
| `football` | `buildFootballScene` | Field 12×20 | 18 × 24 × 5 |
| `soccer` | `buildSoccerScene` | Pitch 14×10 | 16 × 14 × 4 |
| `golf` | `buildGolfScene` | Green radius 5 | 16 × 14 × 4 |
| `tennis` | `buildTennisScene` | Court 8.2×11 | *(none — `addVeniceBeachWalls`)* |
| `volleyball` | `buildVolleyballScene` | Sand 9×9 | *(none — beach walls)* |
| `gymnastics` | `buildGymnasticsScene` | Floor 7×7 | 16 × 16 × 5 |

**Gap:** `ArenaSettings.json` includes `brain_brawl`, `surfing`, `skateboarding`, `snowboarding`, `market_browse` — **no** matching `GameModeId` / `GameSceneFactory` branch in Swift; Unreal-only until added.

**iOS entry — `GameSceneHostView`**

- `LabView` sets `pendingArenaMode` → `navigateToArenaGame` → **`GamePlayView`** (`navigationDestination`).
- `GamePlayView.sceneArea` embeds **`GameSceneHostView(gameMode: gameMode.id, …)`** (`GamePlayView.swift`), which calls `GameSceneFactory.buildScene(for: gameMode)` (`GameSceneHostView.swift`).

---

## Phase 2 — Unreal: Luma / Venice content lock

**Unreal**

- Import Luma scan per `IMPORT_CHECKLIST.md` → `/Game/FEL/Environment/Luma/` (`SM_LumaCourt` or project naming).
- Venice court + composition per `VENICE_LUMA_LEVEL.md` (scale Luma shell if ~4 m footprint feels small).
- Ensure **Market / Sovereign Shop** path resolves: `FELDigitalTwinVenuePaths::LumaVeniceShop`, `Luma_Venice_Shop` cooked.

**SceneKit**

- No blocking dependency; optional: capture reference screenshots from UE for art direction.

**Exit:** Editor PIE on target maps; cook list includes shop + primary arena maps.

### Phase 2 — Repo automation & checklist (done here)

| Artifact | Purpose |
|----------|---------|
| `DOCS/FEL_PHASE2_UNREAL_LUMA_VENICE_LOCK.md` | Editor steps: import Luma/Venice, compose VeniceBeach, lock `Luma_Venice_Shop`, optional `DirectoriesToAlwaysCook`. |
| `UnrealStarter/scripts/verify_fel_phase2_venue_paths.sh` | Verifies `FELDigitalTwinVenuePaths`, `DefaultGame.ini` MapsToCook, and `ArenaSettings.json` agree (run in CI or before packaging). |

**Still local (Unreal Editor):** import meshes, save real `.umap` files, PIE — cannot be done from git alone.

---

## Phase 3 — Unreal: iOS package & device smoke

**Unreal**

- Run `verify_fel_build_matrix.sh` (optional `VERIFY_FEL_SKIP_IOS=1` for fast loop).
- Package iOS via `UnrealStarter/scripts/package_fel_ios.sh` (or project’s Gold Master flow); install on device; confirm default map + one arena mode loads.

**SceneKit**

- Parallel: ensure `ios/FinalEvolutionLab` scheme builds **Release** for same device OS target.

**Exit:** UE-built `.ipa` or Xcode archive runs; SceneKit app runs — two artifacts, same device class documented.

### Phase 3 — Repo automation & checklist (done here)

| Artifact | Purpose |
|----------|---------|
| `DOCS/FEL_PHASE3_IOS_PACKAGE_SMOKE.md` | Commands: `verify_fel_build_matrix.sh`, `package_fel_ios.sh`, SceneKit Release `xcodebuild`, device smoke notes. |
| `UnrealStarter/scripts/verify_fel_phase3_smoke.sh` | Runs `verify_fel_phase2_venue_paths.sh` + optional `VERIFY_FEL_PHASE3_UE_MATRIX=1` Unreal matrix + **Release** iOS app build (`CODE_SIGNING_ALLOWED=NO` for CI compile). |

**Local (device):** install UE build from `package_fel_ios.sh` / Xcode; confirm default map + one arena mode — not automated.

---

## Phase 4 — Shell integration: path from Swift to Unreal

**Unreal**

- Confirm native bridge / URL scheme / Pixel Streaming hooks documented in `FELNativeBridge`, `RUN_UNREAL_ON_IPHONE_XCODE.md`.

**SceneKit / app shell**

- Define **one** user-visible switch or deep link: e.g. “Full Simulation (Unreal)” opens packaged UE client or streaming URL; “Lightweight Arena (native)” keeps SceneKit.
- Implement minimal routing (even if Unreal is stubbed): `UserDefaults` flag + `open URL` or separate target.

**Exit:** Written UX + stub or working handoff; no false expectation that SceneKit *is* Luma.

### Phase 4 — Delivered in repo

| Artifact | Purpose |
|----------|---------|
| `ios/FinalEvolutionLab/Models/FELArenaRuntimePreference.swift` | `UserDefaults` + `fel://arena/*` parsing |
| `SettingsSheet` | **Arena experience** picker + optional Pixel Streaming URL |
| `GamePlayView` | Banner when **Full Simulation (Unreal)** is selected (honest lightweight native vs UE) |
| `FinalEvolutionLabApp` | `.onOpenURL` → `applyIfHandled` |
| `DOCS/FEL_PHASE4_SHELL_UNREAL_HANDOFF.md` | UX + URL scheme registration steps |
| `UnrealStarter/scripts/verify_fel_phase4_shell.sh` | Greps for Phase 4 wiring |

**Manual:** Xcode → **URL Types** → scheme `fel` (see `FEL_PHASE4_SHELL_UNREAL_HANDOFF.md`).

---

## Phase 5 — SceneKit: arena scale & readability

**SceneKit**

- Increase per-mode bounds (or shared `ArenaDimensions` config) in `GameSceneFactory` — reduce “tiny box” feel; add sky gradient / simple horizon where cheap.
- Keep HUD/controller overlays readable at new scale.

**Unreal**

- Optional: match approximate **playable area** dimensions in editor so training muscle memory transfers.

**Exit:** Before/after screenshots; numeric bounds documented in code comments or small `ArenaSceneConfig.swift`.

### Phase 5 — Delivered in repo

| Artifact | Purpose |
|----------|---------|
| `ios/FinalEvolutionLab/Models/ArenaSceneConfig.swift` | Documented court widths/lengths, hoop ratios, 3v3 homing clamps; `arenaTwilightSkyGradientImage()` for `SCNScene.background`. |
| `GameSceneFactory` basketball builders | Larger courts, parameterized `addCourtLines(halfWidth:halfDepth:)`, sky gradient, camera/particle/crowd tweaks; dunk stadium uses `sideBaseX` with scaled court. |
| `UnrealStarter/scripts/verify_fel_phase5_scenekit.sh` | Greps for Phase 5 wiring (`ArenaSceneConfig`, `addCourtLines` signature). |

**Unreal (optional):** match playable area in-editor when tuning Venice/Luma — not enforced in repo.

---

## Phase 6 — SceneKit: mode parity & polish

**SceneKit**

- Align dunk / trick / sport modes with **same verbs** as `EFELArenaMode` naming where `GamePlayView` branches exist.
- Gate **diagnostic** skeleton overlays (LEAKING/MODERATE) behind `#if DEBUG` or a “Diagnostics” toggle so retail builds look intentional.

**Unreal**

- Verify `ArenaSettings.json` / `active_mode` strings match `FELArenaModeIds` for modes you ship in both stacks.

**Exit:** Checklist of modes: “SceneKit OK / Unreal OK / both.”

### Phase 6 — Delivered in repo

| Artifact | Purpose |
|----------|---------|
| `ios/FinalEvolutionLab/Models/FELArenaDiagnosticsPreference.swift` | UserDefaults key; DEBUG seeds overlay **on** once; release stays off until Settings. |
| `SettingsSheet` | **Arena diagnostics** toggle + footer (skeleton / MODERATE·LEAKING readouts). |
| `GamePlayView` | `LiveBiomechanicsOverlay` + toolbar skeleton toggle only when diagnostics enabled. |
| `LabView` | Joint-analysis sheet: skeleton preview gated like arena. |
| `GameMode.swift` | Doc comment: ids match `FELArenaModeIds` / `ArenaSettings.json`; tennis/volleyball **names** de-duplicated (“Tennis” / “Volleyball”). |
| `UnrealStarter/scripts/verify_fel_phase6_arena_modes.sh` | Every `GameModeId` raw value exists under `modes` in `ArenaSettings.json`; spot-checks `FELArenaModeDefinitions.h`. |

### Phase 6 — Mode checklist (shipped SceneKit ids)

| `GameModeId` / JSON key | SceneKit scene | Unreal `ArenaSettings` row |
|-------------------------|----------------|----------------------------|
| `basketball_h2h` | `buildBasketballScene` | Yes |
| `basketball_dunk` | `buildDunkContestScene` | Yes |
| `basketball_3v3` | `build3v3Scene` | Yes |
| `karate` … `gymnastics` | matching `GameSceneFactory` branch | Yes |
| `brain_brawl`, `surfing`, `skateboarding`, `snowboarding`, `market_browse` | Unreal-only today | Yes |

---

## Phase 7 — Unreal: mobile tuning for Luma-heavy maps

**Unreal**

- Run `fel_luma_venue_texture_presave.py` (or Gold Master stamp path) for iOS ASTC where applicable; scalability ini for shop/arena.
- Profile `UFELPlatformManager` luminance / FPS guard paths on Luma-tagged maps.

**SceneKit**

- Performance pass: reduce overdraw, fixed timestep for physics if needed.

**Exit:** Document target FPS and device tier; note in `PACKAGE_AND_TEST.md` or project README.

### Phase 7 — Delivered in repo

| Artifact | Purpose |
|----------|---------|
| `UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md` §13 | FPS targets (UE 60 / SceneKit 60), device-tier notes, Luma ASTC presave steps, `UFELPlatformManager` hook table. |
| `UnrealStarter/BasketballGame/Config/IOS/DefaultScalability.ini` | iOS scalability groups + streaming mip bias (Luma / shop friendly). |
| `EditorPython/fel_luma_venue_texture_presave.py` | Already canonical; §13 references pre-cook **ASTC** stamp for `Luma_Venice_Shop`. |
| `UFELPlatformManager.cpp` | Existing iOS DRS, luminance PP, PS5 Pro Luma guard — documented in §13 (no behavioral change required here). |
| `GameSceneHostView.swift` | Phase 7: **2× MSAA**, `physicsWorld.timeStep = 1/60`. |
| `UnrealStarter/scripts/verify_fel_phase7_mobile_tuning.sh` | Static checks for Phase 7 files and symbols. |

**Manual:** Editor run of Luma presave + device `stat fps` on Venice / shop maps.

---

## Phase 8 — Unified product story

**Both**

- Update user-facing copy: **two** experiences — “Full simulation (Unreal)” vs “Lightweight arena (native)” — until single binary is default.
- **UNREAL_ONLY.md** / App Store materials: one paragraph on convergence.

**Exit:** Marketing + in-app strings consistent; no duplicate conflicting claims.

### Phase 8 — Delivered in repo

| Artifact | Purpose |
|----------|---------|
| `UNREAL_ONLY.md` | § **Dual track until convergence** — one paragraph on two experiences + path to single Unreal iOS binary. |
| `FELArenaRuntimePreference.swift` | Picker titles **Lightweight Arena (native)** / **Full Simulation (Unreal)** + aligned detail strings. |
| `SettingsSheet` / `GamePlayView` | **Arena experience** label, unified footer, session banner copy. |
| `DOCS/FEL_PHASE4_SHELL_UNREAL_HANDOFF.md` | Tables/checklist updated to Phase 8 wording. |
| `RUN_UNREAL_ON_IPHONE_XCODE.md` | Points to Arena experience + `UNREAL_ONLY.md`. |
| `UnrealStarter/scripts/verify_fel_phase8_product_story.sh` | Greps canonical strings and `UNREAL_ONLY` convergence section. |

**App Store:** reuse the `UNREAL_ONLY` convergence paragraph or shorten for subtitle; no separate file required in-repo.

---

## Phase 9 — Automation

**Unreal**

- CI or local: `verify_fel_build_matrix.sh` + `verify_fel_phase10_signoff.sh` on release branches.

**iOS**

- Xcode **test** target smoke (launch + one SceneKit scene) if not present; optional fastlane.

**Exit:** “Green” path documented in one command block at bottom of this file.

### Phase 9 — Delivered in repo

| Artifact | Purpose |
|----------|---------|
| `UnrealStarter/scripts/verify_fel_phase9_automation.sh` | Runs `verify_fel_phase10_signoff.sh` (static), optional `verify_fel_build_matrix.sh`, optional `xcodebuild test` for `FinalEvolutionLabTests`. |
| `FinalEvolutionLabTests` → `arenaSceneKitPhase9SmokeBuildsBasketballScene` | Builds `GameSceneFactory` H2H `SCNScene` and asserts the root has children. |
| This doc § One-command quick reference | Default green path for Phase 9. |

**Release branches:** run with `VERIFY_FEL_PHASE9_UE_MATRIX=1` before merge when Unreal compile coverage is required.

---

## Phase 10 — Sign-off

**Both**

- Device matrix (e.g. two iPhones + one iPad): Unreal build + SceneKit build.
- Content: Luma shop visible in UE; SceneKit arenas meet minimum size/quality bar from Phase 5.
- Sign-off checklist: copy from `verify_fel_phase10_signoff.sh` static checks + manual device rows.

**Exit:** Tagged release + changelog entry; optional Git tag `fel-dual-pass-10`.

### Phase 10 — Delivered in repo

| Artifact | Purpose |
|----------|---------|
| `UnrealStarter/scripts/verify_fel_phase10_dual_track_static.sh` | One-shot **static** sign-off: Phase 2–8 verify scripts + `verify_fel_phase10_signoff.sh` (no compile / no `xcodebuild test`). |
| `DOCS/FEL_PHASE10_DUAL_TRACK_SIGNOFF.md` | Manual device matrix, Luma/shop + arena content checks, optional `git tag fel-dual-pass-10`. |
| `DOCS/CHANGELOG_FEL_DUAL_TRACK.md` | Template entry for `fel-dual-pass-10` release notes. |
| `verify_fel_phase9_automation.sh` | Optional **full** automation (static Phase 10 + iOS tests + optional UE matrix) — already Phase 9. |

**Release owner:** run `verify_fel_phase10_dual_track_static.sh`, complete manual rows in `FEL_PHASE10_DUAL_TRACK_SIGNOFF.md`, append changelog, tag.

---

## One-command quick reference (Phase 9 green path)

**Default (macOS):** static Unreal Phase 10 checks + **all** `FinalEvolutionLabTests` (includes SceneKit arena smoke).

```bash
chmod +x UnrealStarter/scripts/verify_fel_phase9_automation.sh
bash UnrealStarter/scripts/verify_fel_phase9_automation.sh
```

**Optional — Unreal Editor + game UBT compile (macOS, slower):**

```bash
VERIFY_FEL_PHASE9_UE_MATRIX=1 bash UnrealStarter/scripts/verify_fel_phase9_automation.sh
```

**Optional — same as Phase 10 `--compile` only (no iOS tests):**

```bash
VERIFY_FEL_SKIP_IOS=1 bash UnrealStarter/scripts/verify_fel_phase10_signoff.sh --compile
```

**Linux CI / no Xcode:** skip `xcodebuild test`:

```bash
VERIFY_FEL_SKIP_IOS_TESTS=1 bash UnrealStarter/scripts/verify_fel_phase9_automation.sh
```

**Phase 3 smoke** (venue paths + `Release` build + optional UE matrix) remains available:

```bash
bash UnrealStarter/scripts/verify_fel_phase3_smoke.sh
VERIFY_FEL_PHASE3_UE_MATRIX=1 bash UnrealStarter/scripts/verify_fel_phase3_smoke.sh
```

**Phase 10 — static dual-track sign-off (no compile):**

```bash
chmod +x UnrealStarter/scripts/verify_fel_phase10_dual_track_static.sh
bash UnrealStarter/scripts/verify_fel_phase10_dual_track_static.sh
```

Then complete **`DOCS/FEL_PHASE10_DUAL_TRACK_SIGNOFF.md`** (manual devices + content) and **`DOCS/CHANGELOG_FEL_DUAL_TRACK.md`**.

*(For signed device installs, use Xcode with your Team; `CODE_SIGNING_ALLOWED=NO` is for compile/test automation only.)*

---

*FEL — dual-track 10-phase pass. Last updated with repo layout.*
