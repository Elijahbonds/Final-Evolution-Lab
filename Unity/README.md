# Final Evolution — Unity (UaaL) scripts in this repo

Copy **`Scripts/`** and **`Editor/`** into your Unity project under **`Assets/`** (e.g. `Assets/FEL/Scripts`, `Assets/FEL/Editor`). Adjust assembly definitions if you use them.

## Batch iOS export

- **Unity menu:** **FEL → Build iOS Player** (or **FEL → Sync iOS Bundle Identifier** first).
- **CLI:** `FEL_IOS_OUT=/path/to/out Unity -batchmode -quit -projectPath ... -executeMethod FELIOSBuilder.BuildIOS`
- Repo script: **`scripts/fel_pipeline_unity_ios.sh`** (reads **`Config/FEL_IOS_BUNDLE_ID.txt`** for bundle checks).

## Seat the bridge (automated)

1. Open your **Final Evolution Unity** project in the Editor.
2. Menu: **FEL → Setup Film Vault Host (Canvas + Video)**  
   - Creates **`FELBridge`** if missing, adds **Canvas** → **RawImage** → **VideoPlayer** (render-to-texture for the Raw Image).
3. Save the scene.

**OpenClaw / external CLIs cannot click Unity’s UI.** Use this Editor menu (or extend `FELFilmVaultHostSetup.cs`) for repeatable setup.

## iOS handshake (Swift)

1. **File → Build Settings → iOS → Switch Platform**
2. **Player Settings**: Bundle ID aligned with Xcode (e.g. matches `PRODUCT_BUNDLE_IDENTIFIER`).
3. Export the **Unity iOS** project into a folder (e.g. `UnityExport`).
4. In Xcode, embed **UnityFramework** and data per Unity’s **Unity as a Library** docs; **`UnityManager.swift`** in this repo expects `UnityFramework.framework` under **Embedded Frameworks**.

## Streaming / Skill Lab

- For **live HLS**, set `VideoPlayer.url` to your stream; for **3D quad** projection, assign the same **Render Texture** to a material on a quad (setup not automated here—duplicate `RenderTexture` ref or use a second `VideoPlayer`).

See **`MIGRATION_ARCHITECT_UNITY.md`** and **`UNITY_IOS_INTEGRATION.md`** at the repo root for migration + native bridge + pipeline.
