# Integration runtime — Supabase, Unity, Unreal, Meshy, Luma

Single checklist to keep **economy**, **3D assets**, and **deploy** aligned.

## Supabase

| Piece | Location |
|--------|----------|
| Edge Functions | `supabase/functions/` — `wix-order-completed`, `stripe-webhook-handler` |
| Migrations | `supabase/migrations/` — `fel_apply_stripe_shard_credit`, `user_balances` |
| Local secrets | Never commit `.env`; use Dashboard secrets for production |
| Web client | `web/fel-public-config.example.js` → copy to `web/fel-public-config.js` (gitignored) |

Deploy: `supabase link` + `supabase functions deploy` (see `PRODUCTION_CONFIG.md`).

## Unity — Meshy GLBs at runtime

1. **StreamingAssets:** Place GLBs under `UnityProject/Assets/StreamingAssets/Meshy/` (see `UnityProject/Assets/StreamingAssets/Meshy/README.md`).
2. **Loader:** `FELMeshyStreamingLoader` (`UnityProject/Assets/Scripts/Environment/FELMeshyStreamingLoader.cs`) loads named files at runtime (glTFast). Editor menu: **FEL → Add Meshy Streaming Loader to Scene** (`FELMeshyBootstrapMenu.cs`).
3. **Game modes** (soccer/tennis) resolve ball/racket references via `FELMeshyStreamingLoader.Instance` when present.

If meshes do not appear: confirm paths match `MeshyFileNames` constants, platform build includes **StreamingAssets**, and glTFast package is installed per `Packages/manifest.json`.

## Unreal — Meshy + Luma environments

| Source | In repo | Load into UE |
|--------|---------|----------------|
| **Meshy** GLB/OBJ | `UnrealStarter/MeshyAssets/` | See `UnrealStarter/MeshyAssets/README_IMPORT.md` — glTF Importer or Blender → FBX fallback |
| **Luma** | **Not** raw `.luma` | Export **OBJ/FBX/GLB** from Luma app → import Static Mesh (`UnrealStarter/LUMA_DOT_LUMA_TO_UNREAL.md`) |
| Pre-exported scan | `UnrealStarter/LumaScan/mesh.obj` + `textures/` | `UnrealStarter/LumaScan/README_IMPORT.md` |
| Extra captures | `UnrealStarter/LumaExports/capture_*` | Same import pipeline |

**Python layout (optional):** `UnrealStarter/EditorPython/` can spawn actors; search for Luma prop paths in scripts.

## AI Studio sync

Regenerate the paste bundle after code or deploy config changes:

```bash
python3 scripts/generate_ai_studio_bundle.py
```

Output: `AI_STUDIO_FEL_ARCHITECTURE_BUNDLE.md` → paste into Google AI Studio for architecture review.

## GitHub / large assets

- **`.glb`** is configured for **Git LFS** in `.gitattributes` — install `git-lfs` before pushing GLB changes.
- **Large `.obj`** (~95 MB) scans: if GitHub rejects the push, run `git lfs track "*.obj"` for `UnrealStarter/LumaScan/` (or host meshes in Supabase Storage / DVC).
