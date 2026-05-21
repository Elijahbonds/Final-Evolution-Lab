# Final Evolution Lab — Unity 6 project

> **Status: Unity prototype/reference track.** The production iOS target is the Unreal Engine 5.7 host with WKWebView dashboard overlay. See `SHIPPING_ARCHITECTURE.md`.

## Setup

1. Open **`UnityProject`** in **Unity 6000.x** (see `ProjectSettings/ProjectVersion.txt`).
2. Let the Editor resolve packages (first open may download **glTFast** from OpenUPM via `Packages/manifest.json`).
3. **Meshy GLBs:** Soccer/tennis props live in `Assets/StreamingAssets/Meshy/` (see `Meshy/README.md`).
4. Menu **FEL → Add Meshy Streaming Loader to Scene** if you need the runtime loader in a scene.
5. iOS builds: align native entry points with `FELNativeBridge.cs` / `FELNativeCallProxy` in the host app.

## Docs

- `EXECUTION_FIRST_PASS.md` — Package Manager, Meshy loader, glTFast, LFS, zsh `compdef`, pipeline env vars
- `../UNITY_VISION_AUDIT.md` — vision vs implementation
- `../UNREAL_ONLY.md` — canonical shipping direction (Unreal)
