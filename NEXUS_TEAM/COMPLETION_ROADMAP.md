# NEXUS Completion Roadmap

From current state → "engine + editor + app complete". Each item is tagged **[VM]**
(doable in a cloud agent on Linux/no-GPU) or **[MAC]** (needs the user's Mac mini /
Xcode / UE editor / GPU / art tools). Ordering is by dependency, not calendar time.

Legend: ✅ implemented · 🟡 partial · ⬜ stub/absent.

---

## Phase 0 — Foundation (mostly done)
- ✅ [VM] Headless engine builds; 4/4 unit tests pass (`core`, `physics`, `gameplay`, `generative`, `ai_interface` exercised).
- ✅ [VM] Deterministic physics integrator landed and unit-tested.
- ✅ [VM] AI agent protocol + routing + response channel.

## Phase 1 — Engine
- 🟡 [VM] **Core loop hardening:** wire `Engine::tick` consumers and fixed-timestep coupling to physics. *Dep:* core+physics owners; PM links `nexus_engine` (renderer-ON path) so full link-test happens on Mac.
- ✅ [VM] **Physics:** broaden integrator coverage (restitution, multi-body) with new headless tests.
- ⬜ [MAC] **Renderer:** scene is static after init — needs dynamic scene update, frame loop driving camera/objects, and on-GPU validation. *Dep:* GPU; not runnable in VM.
- ⬜ [MAC] **Shaders:** keep SPIR-V headers current via `scripts/compile_nexus_shaders.sh` (needs `glslc`/Vulkan SDK); verify visually in `nexus_runtime`.

## Phase 2 — Editor (does not exist yet)
- ⬜ [VM] **Editing protocol surface:** today "editing" = voxel/terrain commands over TCP (127.0.0.1:9090). Extend `nexus_ai_interface` command schema to cover scene/entity edits; unit-test headless.
- ⬜ [VM] **Headless edit-state model:** authoritative document model the editor mutates (serializes to JSON), testable without a GUI.
- ⬜ [MAC] **Editor viewport/GUI:** any real visual editor needs the GPU renderer first (Phase 1 renderer). Until then the external UE 5.7 Editor on Mac is the only WYSIWYG path.

## Phase 3 — Assets
- ✅ [VM] `.nexusmesh.json` import path + Venice Beach (only real converted mesh).
- 🟡 [VM] **Procedural venues:** other venues are being upgraded from stub geometry to procedural (`engine/generative/` `procedural_mesh`/`model_generator`). Expand and unit-test.
- ⬜ [VM] **glTF/FBX importer:** C++ side is a stub deferring to `scripts/nexus_import_assets.py` (assimp/Blender). Make the script path robust and CI-checkable for sample inputs.
- ⬜ [MAC] **Real 3D art:** Meshy/Tripo adapters are stubs (no API keys in repo); source FBX lives on a remote CDN not fetchable here. Authoring/import requires Meshy/Tripo/Blender on Mac. *Dep:* API keys + source assets.

## Phase 4 — Gameplay / App (unify the three paths)
The three gameplay paths (C++ `app/gameplay`, iOS Swift/SceneKit, UE 5.7) are **not unified**.
- ✅ [VM] **C++ gameplay:** fitness + throw-catch + Basketball Dunk Contest in `libnexus_gameplay`, headless-tested.
- 🟡 [MAC] **iOS shell (~85%, most complete):** consume `libnexus_gameplay` via `NexusGameplayBridge.mm`; finish mode coverage + onboarding. *Dep:* Xcode.
- 🟡 [MAC] **UE 5.7 venues:** content + Pixel Streaming; cook/package via `fel_ue5_mac_package.sh`. *Dep:* UE editor.
- 🟡 [VM] **Web (CRA):** `frontend/` shell.
- ⬜ [VM→MAC] **Unification:** define one shared gameplay/state contract in C++ that iOS (bridge) and UE consume, so the demo logic has a single source of truth. C++ contract + tests are [VM]; client wiring is [MAC].

## Phase 5 — Backend
- 🟡 [VM] **API server:** `backend/server.py` + economy/IAP verify; run `backend_test.py`.
- 🟡 [VM] **Supabase:** DB + Edge Functions under `supabase/`; local stack needs Docker (web degrades gracefully without it).
- ⬜ [VM] **Mode/venue registries:** keep `FEL_ModeManager.production.json` / `FEL_VenueRegistry.production.json` in sync with engine modes (owned by backend agent).

## Phase 6 — Distribution
- ⬜ [MAC] **iOS archive/TestFlight:** `scripts/ios_archive.sh`, `fastlane/`. *Dep:* Xcode + signing.
- ⬜ [MAC] **UE shipping packages:** `fel_ue5_ios_shipping_package.sh`, `fel_ue5_mac_package.sh`, `fel_ue5_win64_cook_only.sh`.
- 🟡 [VM] **Web deploy:** Firebase/Vercel config present (`firebase.json`, `frontend/vercel.json`).
- 🟡 [VM] **Preflight gates:** `scripts/fel_release_preflight.sh`, `scripts/verify_production_readiness.sh`.

---

## Dependency call-outs
- **Renderer GPU → Editor viewport:** no GUI editor is possible until the Vulkan renderer runs dynamically (Mac/GPU).
- **API keys + source FBX → real assets:** generative external adapters and FBX art are blocked on credentials and CDN assets, not on code in this repo.
- **C++ gameplay contract → unification:** unify in headless C++ first ([VM]), then wire iOS/UE clients ([MAC]).
