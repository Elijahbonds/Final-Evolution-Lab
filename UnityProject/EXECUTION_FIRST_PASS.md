# Unity “first pass” — hybrid execution checklist

Use this **before** worrying about Unreal or Swift UaaL. Aligns with `UNITY_VISION_AUDIT.md` and `UNREAL_ONLY.md` (Unity = library / slice / bridge track).

## 1. Local Unity environment

1. **Open** `UnityProject` in **Unity 6000.x** (see `ProjectSettings/ProjectVersion.txt`).
2. **Package Manager** (Window → Package Manager):  
   - Packages → **In Project** → ensure **`com.atteneder.gltfast`** resolves (OpenUPM registry in `Packages/manifest.json`).  
   - **`com.unity.ai.navigation`** (AI Navigation) is listed in the manifest for **NavMeshSurface**, **NavMeshLink**, **NavMeshModifier**, scene overlays, and the Navigation window — use it for CPU / AI movement on walkable ground (e.g. stadium pitch after Meshy loads or on a proxy floor).  
   - If red errors mention **glTFast**: update to a **6.x** build compatible with Unity 6, or re-open the project after a network restore.
3. **Meshy GLBs** are already under `Assets/StreamingAssets/Meshy/` (runtime load). You do **not** need to drag them into the Hierarchy for the loader path; optional: import as prefabs separately if you want editor-only placement.
4. **Menu** → **FEL → Add Meshy Streaming Loader to Scene** (adds `FELMeshyStreamingLoader`).  
   - Tune **scale / local positions** on the component if meshes appear huge or offset.
5. **Enter Play Mode** and confirm the console logs `[FELMeshy] Loaded …` for each file (no missing-file warnings).

## 2. Console: `ImageGenerationDemo.cs` (not in this repo)

There is **no** `ImageGenerationDemo.cs` in this repo’s git tree. That warning usually comes from a **Unity package** (e.g. AI / Sentis / demo) in your local `Library/` or an added package.

**If it blocks or spams builds:**

- Window → Package Manager → **In Project** → identify **AI / ML / demo** packages and **Remove** unused ones, **or**
- Edit → Project Settings → **Player** → **Scripting Define Symbols** / package docs to exclude editor demos, **or**
- Delete the offending script only if it lives under `Assets/` and you own it (avoid deleting `Packages/` cache manually).

**If it’s only a warning** and the build succeeds, you can defer until you trim packages.

## 3. Git LFS for `.glb`

The repo includes `.gitattributes` for `*.glb` → LFS. On your machine:

```bash
brew install git-lfs   # if needed
git lfs install
git lfs track "*.glb"    # already in .gitattributes; safe to re-run
git add .gitattributes
```

Then commit GLBs as usual; they will **not** bloat history as raw blobs.

## 4. iOS pipeline script

`scripts/fel_pipeline_unity_ios.sh` expects:

- `UNITY_EDITOR` → path to Unity **6000** editor binary if that’s what you use, e.g.  
  `/Applications/Unity/Hub/Editor/6000.x.xf1/Unity.app/Contents/MacOS/Unity`
- `FEL_UNITY_PROJECT` → absolute path to this `UnityProject` folder

The script comment still mentions 2022.3; **use your 6000 editor path** for this project.

## 5. Zsh: `command not found: compdef`

`compdef` is defined after **`compinit`**. In `~/.zshrc`, ensure:

```zsh
autoload -Uz compinit && compinit
# then load plugin completions (OpenClaw, brew, etc.)
```

Do **not** source completion scripts that call `compdef` before `compinit` runs. This does **not** affect Unity batch builds; it only affects interactive shell completion.

## 6. `install_unity_hub.sh`

Installs **Unity Hub** via Homebrew. You still install the **6000.0.x** editor + **iOS Build Support** from Hub to match `UnityProject`.
