# Unreal Engine 5.2 — repo alignment

This repo’s **UnrealStarter** assets and docs target **Unreal Engine 5.2 and newer** (5.2 is the baseline; later 5.x builds behave similarly with minor plugin renames).

## Import (GLB / glTF)

- **5.2:** In **Edit → Plugins**, search **glTF**, **Interchange**, or **GLTF** and enable what your build offers (e.g. **Interchange** + importer assets for glTF, or legacy **glTF Importer** if listed). Restart the editor after enabling.
- **Large environments (Venice court):** If the Meshy `.glb` fails or crashes, use the pre-converted **`MeshyAssets/Venice_beach_UE5/`** OBJ + textures — **OBJ import is stable on 5.2** and avoids glTF edge cases.
- **Characters:** Blender → **FBX** remains the most portable path if direct GLB import fails.

## C++ (`FELPlayerController`)

- Uses **legacy axis actions** (`BindAction` + Project Settings → Input) so it compiles **without** the Enhanced Input module.
- Optional Enhanced Input blocks are commented out; uncomment only if your **Build.cs** adds `"EnhancedInput"` and you assign IMC/IA assets.

## Nanite / materials

- **Nanite** for static meshes is available in 5.2; enable on high-poly imports when appropriate.
- Shader snippets in **`FascialSpiralLine_ShaderSnippet.md`** use standard Material Custom Expression HLSL — verify node inputs match your exact 5.2 Material Editor if something fails (engine UI names can differ slightly by hotfix).

## Build: “Platform Mac is not a valid platform” / project “could not be compiled”

Often **Xcode is too new for UE 5.2**: UBT log shows e.g. `Found Sdk Version: 26.x` with **`MaxRequired=15.9.9`** → use a **newer Unreal** or **Xcode 15.x** + `xcode-select`. Less often: incomplete engine (**`Engine/Platforms/Mac`** missing). See **`MAC_PLATFORM_MAC_INVALID.md`** and run UBT with **`-verbose`** to read the real line in **`~/Library/Application Support/Epic/UnrealBuildTool/Log.txt`**.

## Mac crash: `posix_spawn` (86) Bad CPU type — `IOSTargetPlatform` / `QueryDevices`

On **Apple Silicon**, older UE (including **5.2**) can crash when listing **iOS devices** because a spawned helper is **Intel-only** or your `PATH` picks a wrong-arch binary (e.g. `ios-deploy`). **`EpicAccountId` in the log is unrelated** — it’s just crash metadata.

**See:** **`MAC_IOS_BAD_CPU_SPAWN.md`** (Rosetta, native vs x86_64 editor, `file` checks, Xcode, upgrading 5.x).
