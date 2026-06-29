# Mac Mini Handoff Checklist

Everything here **cannot** be done in the cloud VM (no GPU, no Xcode/macOS, no UE editor,
no 3D art tools/source assets). Do these on the Mac mini. Paths are relative to the repo root.

Prereqs on the Mac: Xcode (for iOS + MoltenVK), CMake ≥ 3.24, Vulkan SDK / MoltenVK +
`glslc` (`brew install shaderc`), UE 5.7 editor, and Blender/assimp + Meshy/Tripo access for art.

---

## 1. Vulkan `nexus_runtime` preview (GPU)
The VM builds only the headless libs; the SDL/Vulkan window runs only on the Mac.

```bash
# (optional) refresh embedded SPIR-V if shaders changed
GLSLC=glslc ./scripts/compile_nexus_shaders.sh

cmake -S . -B build-full -DNEXUS_ENABLE_RENDERER=ON
cmake --build build-full --target nexus_runtime
./build-full/nexus_runtime          # SDL window: orbit camera + arena
```
- Expect an SDL window (orbit camera + cube/arena field). Scene is static after init today.
- Historical note: `nexus_runtime` has SIGSEGV'd on launch via the MoltenVK loader; if it
  crashes, that is the Vulkan/MoltenVK init path, not the iOS app. See
  `docs/audit/READINESS_AUDIT_2026-06-19.md`.

## 2. iOS app (Xcode)
The shipping product shell. The ObjC++ bridge links the C++ `libnexus_gameplay`.

```bash
# Pre-build the headless gameplay static lib for the active SDK (Xcode also runs this
# as a build phase). It configures cmake with renderer/runtime/tests OFF.
SRCROOT="$(pwd)" ./scripts/build-nexus-ios.sh
```
Then:
- Open `FinalEvolutionLab.xcodeproj`, scheme **FinalEvolutionLab**, pick device/Simulator, ⌘R.
- Confirm `FinalEvolutionLab/Bridge/NexusGameplayBridge.mm` links `libnexus_gameplay.a`
  (no undefined symbols).
- Do **not** pass `-ScreenshotHarness` for normal runs (dev-only harness; see root `README.md`).
- Archive / distribution: `scripts/ios_archive.sh`, `fastlane/`.

## 3. UE 5.7 venue content (editor)
```bash
# Open the UE project / cook & package (Mac)
./fel_ue5_mac_package.sh
# Other targets:
./fel_ue5_ios_shipping_package.sh
./fel_ue5_win64_cook_only.sh
```
- Project content under `UnrealStarter/` and `UnrealIntegration/`.
- Pixel Streaming WebServers infra ships under the UE samples tree; validate streaming on Mac.

## 4. Real 3D assets (Meshy / Tripo / Blender)
Only **Venice Beach** is a real converted mesh; other venues are stub/procedural. Source FBX
lives on a remote CDN not fetchable in the VM, and Meshy/Tripo adapters are stubs with **no API
keys in the repo**.

```bash
# After you have source FBX + (optionally) Meshy/Tripo output locally:
python3 scripts/nexus_import_assets.py --help     # downloads + converts to .nexusmesh.json
# or single-file convert:
./scripts/nexus_convert_mesh.sh <input.fbx|gltf> <output.nexusmesh.json>
```
- Importer uses assimp CLI / Blender fallback (`/opt/homebrew/bin/assimp`, `blender`).
- Output target: `assets/nexus/imported/`; manifest `assets/nexus/manifests/nexus_asset_manifest.json`.
- To enable external generative APIs, provide Meshy/Tripo credentials on the Mac (not committed);
  without them the engine uses the procedural placeholder path.

## 5. GPU-dependent verification / screenshots
- Any renderer screenshot, frame-capture, or visual diff must come from the Mac (`nexus_runtime`
  or the iOS Simulator). The VM cannot produce GPU frames.
- Mode/venue screenshot harness: `scripts/capture_game_mode_screenshots.sh`,
  `infra/GAME_MODE_SCREENSHOT_RUNBOOK.md`.

---

## What stays in the VM (do NOT wait on the Mac for these)
- Headless engine build + `ctest` (4/4), Python backend + `backend_test.py`, and the CRA
  `frontend/`. Build the `libnexus_gameplay.a` the iOS bridge needs on the VM and hand it over;
  the Mac side only links and runs it.
