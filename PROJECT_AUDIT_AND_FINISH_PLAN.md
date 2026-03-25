# Final Evolution Lab — Full project audit & finish plan

**Date:** March 2026 · **Repo:** `final-evolution-lab` (local folder name may vary)

This document consolidates **vision** (`UNREAL_ONLY.md`, `app-synopsis.md`, `PROJECT_FLOWS.md`), **implementation reality** (Swift, Unity, Unreal templates), and a **phased plan** to reach a shippable game/app.

---

## 1. Executive summary

| Layer | Role in repo | Maturity |
|--------|----------------|----------|
| **Swift / SwiftUI** (`FinalEvolutionLab/`) | Primary **playable** product in-tree: Games hub, Lab (RealityKit dunk), Arena (12 modes), Train, Dashboard, Vault, Film/Stream tabs, PRQ/shards, Multipeer, controllers | **High** — flows work; Arena is arcade/PRQ shell, not full physics per sport |
| **Unity 6** (`UnityProject/`) | UaaL / slice: Meshy GLBs, `FELMeshyStreamingLoader`, game mode stubs, `FELNativeBridge` ↔ iOS | **Medium** — needs editor wiring, scenes, input hookup; optional ship path |
| **Unreal** (`UnrealStarter/`) | **Canonical ship** per `UNREAL_ONLY.md`: C++ basketball slice, readiness JSON, Python level tools | **Template** — merge into a real `.uproject`, cook, iOS package |

**Strategic tension:** Docs describe **Unreal + Firebase + full digital twin**; the **runnable app today** is **Swift**. Finishing “the game” means **choosing one primary runtime** for App Store gameplay (recommended: **Unreal** for 3D parity with vision, or **Swift** for fastest ship of current feature set).

---

## 2. What is strong / complete

### iOS app (Swift)

- **Tab shell:** Games (Emulator dashboard + venue shortcuts), Lab, Arena, Train, Dashboard, Social, Vault — see `ContentView.swift`.
- **Arena:** All `GameModeRegistry` modes → Get Ready → Play → Result; solo + Local Play; Brain Brawl full quiz; soccer/golf multi-round solo; dunk contest path (`ArenaDunkPlayView`); PRQ/shard persistence (`LabViewModel`, `SaveSystem`).
- **Lab:** RealityKit dunk (`RealityKitDunkView`, `DunkContestEngine`), system scan, biomechanics education, training hooks.
- **Cross-cutting:** Theme, `GameMode` model, `PRQScoring`, `GlobalLeaderboardService`, `ControllerDiscoveryService`, GameplaySound, accessibility-minded copy.
- **Native bridge:** `FELNativeCallProxy` / `FELUnityNativeCallbacks` for Unity ↔ metrics when embedded.
- **Docs:** `PROJECT_FLOWS.md`, `IOS_PLAY_TEST_READINESS.md`, `XCODE_CLEAN_AND_RUN.md`.

### Unity

- **Packages:** URP, Input System, **glTFast**, **AI Navigation** (manifest), OpenUPM.
- **Runtime:** `FELMeshyStreamingLoader` (StreamingAssets Meshy GLBs), `FELNativeBridge`, `NativeCallProxy`, `GameModeManager`, per-mode scripts, `EXECUTION_FIRST_PASS.md`.
- **Git LFS:** `.gitattributes` for `*.glb`.

### Unreal (templates)

- **Readiness → gameplay:** `FELReadinessIO`, `ApplyReadiness`, `FELBasketballCharacter`, hoop volumes, session export, editor Python for level setup.
- **Modular AAA framework (in progress):** `UFELArenaModeData` Primary Data Assets (12 modes), `IFELBiometricReceiver` for Character/Ball/Environment, `UFELDemoManager` for ghost demos + Perfect Form HUD, `FStreamableManager` async load per `active_mode` — see `UnrealStarter/BasketballGame/Content/FEL/Data/README_DA_ArenaModes.md`.
- **Docs:** `PACKAGE_AND_TEST.md`, `NEURO_MECHANIC_BRIDGE.md`, `VISION_ALIGNMENT.md`.

### Tooling

- `scripts/generate_ai_studio_bundle.py` → `AI_STUDIO_FEL_ARCHITECTURE_BUNDLE.md` for AI Studio / Gemini review.
- `scripts/fel_pipeline_unity_ios.sh`, `fel_claw_device_build.sh` (Unity export + device).

---

## 3. Gaps & risks (audit)

### Vision vs code

| Vision (synopsis / deck) | Gap |
|--------------------------|-----|
| Firebase cloud sync | Not evidenced as full production backend in-tree; save is largely local (`SaveSystem`). |
| Full CV pipeline for “Calibrate()” | Scan is **simulated** / structured UI; not a shipped on-device CV product. |
| “Gaming Labs” in Unreal as primary | **Unreal not in Xcode app**; Swift Arena is 2D/arcade shell. |
| Web3 / dual currency | Product/marketing; not a full on-chain implementation in this repo. |

### Technical debt / fragmentation

- **Three engines:** Swift (live), Unity (optional embed), Unreal (external) — duplicate concepts (`GameMode`, readiness, shards).
- **Unity vs `Unity/` mirror:** Root `Unity/` scripts vs `UnityProject/Assets` — merge policy needed.
- **iOS target naming:** `FinalEvolutionLabUnreal` / docs mention `FinalEvolutionLab` — keep identifiers consistent with provisioning.
- **Optional:** `UnityOnWorkoutSummary` not in `FELNativeCallProxy.h` — only if you need native parity.

### Gameplay (Swift) — from `GAMEPLAY_STATUS.md`

- Arena **Dunk** vs Lab **Dunk** experience parity (same 3D dunk in Arena vs simplified 2D).
- **Sport-specific input** (`inputScheme`) vs single tap-to-commit in most modes.
- **Tutorials** for Brain Brawl / Arena (partial overlays exist).
- **Brain Brawl** content expansion.

### Unity

- **Scenes / build:** Default scene + `FELMeshyStreamingLoader` + input → not yet a single polished “vertical slice” build.
- **iOS:** `UnityFramework` embed + Xcode integration is **manual** outside repo.

### Unreal

- **No `.uproject` in repo** — snippets only; must merge into your project.
- **iOS packaging** of Unreal is a **separate pipeline** from this Swift app.

---

## 4. Decision: pick a “finish line”

Choose **one** primary definition of done:

| Goal | Finish line | Effort |
|------|-------------|--------|
| **A. Ship Swift app** | App Store build of current SwiftUI app: polish Arena/Lab, analytics, backend as needed, **no** Unreal in binary | **Lower** (relative) |
| **B. Ship Unreal game** | UE5 project + cooked content + iOS/Android; Swift app deprecated or minimal shell | **High** — matches `UNREAL_ONLY.md` |
| **C. Hybrid** | Swift shell + **either** embedded Unity **or** Unreal as library; one bridge path | **Highest** coordination |

**Recommendation:** If the product owner wants **one codebase for 3D sports**, **B** is the vision; **A** is the **fastest playable milestone** with what exists.

---

## 5. Phased plan to finish

### Phase 0 — Lock scope (1–2 days)

- [ ] Decide **A / B / C** above and document in `UNREAL_ONLY.md` or a one-page **SHIP_CRITERIA.md**.
- [ ] Freeze **bundle ID**, signing, and **TestFlight** owner.
- [ ] Run `python3 scripts/generate_ai_studio_bundle.py` and archive `AI_STUDIO_FEL_ARCHITECTURE_BUNDLE.md` for stakeholders.

### Phase 1 — Swift app “complete playable” (1–3 weeks)

*If choosing **A** or hybrid shell.*

- [ ] **Polish:** Arena dunk parity with Lab (route or embed `RealityKitDunkView` for Dunk Contest) — see `GAMEPLAY_STATUS.md`.
- [ ] **Input differentiation:** Implement swipe/golf/penalty UIs per `GameModeId.inputScheme` where high priority.
- [ ] **Onboarding:** First-run Arena + Brain Brawl tips (extend existing overlays).
- [ ] **Stability:** Device test matrix on `IOS_PLAY_TEST_READINESS.md`; fix crashers.
- [ ] **Backend (optional):** Wire persistence/sync if product requires cloud saves.
- [ ] **App Store:** Screenshots, privacy copy, HealthKit/Gemini usage strings as applicable.

### Phase 2 — Unity slice (parallel, 1–2 weeks)

*If UaaL remains in roadmap.*

- [ ] One **Main** scene: lighting, camera, `FELMeshyStreamingLoader`, `GameModeManager`, test input → device.
- [ ] Resolve **glTFast** + package versions in Unity 6000; confirm **AI Navigation** bakes on proxy floor.
- [ ] Run `fel_pipeline_unity_ios.sh` with **6000** editor path; embed `UnityFramework` in Xcode; smoke test `UnityManager`.
- [ ] Merge duplicate `Unity/` vs `UnityProject/` scripts.

### Phase 3 — Unreal vertical slice (3–8+ weeks)

*If choosing **B** or serious **C**.*

- [ ] Create or clone **one** UE 5.2+ project; merge `UnrealStarter/BasketballGame` per `PACKAGE_AND_TEST.md`.
- [ ] **Luma/Meshy** import in Unreal for Venice/stadium art path (`UnrealStarter` import docs).
- [ ] **Readiness JSON** from iOS export or file → verify `ApplyReadiness` in PIE and packaged build.
- [ ] **iOS package** from Unreal; follow `RUN_UNREAL_ON_IPHONE_XCODE.md` / `UNREAL_EXPORT_TO_XCODE.md`.
- [ ] Deprecate or slim Swift gameplay duplication once UE is primary.

### Phase 4 — Production hardening

- [ ] **QA:** `AUDIT_QUALITY.md`, `QA_GAMEPLAY_AUDIT.md` (Unreal) checklists.
- [ ] **Performance:** 120 Hz / Metal on iOS; profiling on M-series / A-series devices.
- [ ] **CI:** Git LFS for large assets; optional Xcode + Unity batch on CI Mac runners.

---

## 6. Quick reference — key files

| Topic | File |
|-------|------|
| Flows | `PROJECT_FLOWS.md` |
| iOS test | `IOS_PLAY_TEST_READINESS.md` |
| Gameplay gaps | `GAMEPLAY_STATUS.md` |
| Unity vision | `UNITY_VISION_AUDIT.md` |
| Unreal canonical | `UNREAL_ONLY.md` |
| Unity execution | `UnityProject/EXECUTION_FIRST_PASS.md` |
| Bridge | `UNITY_IOS_INTEGRATION.md`, `NEURO_MECHANIC_BRIDGE.md` |
| Xcode | `XCODE_CLEAN_AND_RUN.md` |

---

## 7. Conclusion

The repo is **feature-rich and playable** as a **Swift arcade/training shell** with a **clear path to Unreal** via `UnrealStarter` and a **Unity library path** via `UnityProject`. **Finishing** requires a **product decision on ship runtime**, then executing **Phase 1** (Swift) and/or **Phase 3** (Unreal) with **Phase 2** (Unity) only if hybrid embedding stays in scope.

*Regenerate or amend this plan as scope changes.*
