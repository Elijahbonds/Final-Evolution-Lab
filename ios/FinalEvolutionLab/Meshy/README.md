# Meshy GLBs for SceneKit Arena (iOS)

Copy your **Meshy** exports here using the **exact base filenames** (no spaces). Files must be added to the **FinalEvolutionLab** target so they copy into the app bundle under the **`Meshy`** folder.

| File (`.glb`) | Role |
|----------------|------|
| `Meshy_AI_HoopBus_Basketball_0319064117_texture.glb` | Basketball — used in Arena H2H / Dunk / 3v3 when present |
| `Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin.glb` | Hero player (preferred) |
| `Meshy_AI_Elijah_Bonds_biped_Animation_Walking_withSkin.glb` | Hero player fallback |

**Loader:** `Utilities/FELMeshyBundledModels.swift` — `GameSceneFactory` uses these for the primary player and ball; if a file is missing, the app falls back to procedural geometry.

**Unreal parity:** Same assets should be imported per `UnrealStarter/IMPORT_CHECKLIST.md` (`SM_HoopBusBasketball`, `SKM_ElijahBonds_Walking`, etc.).

**Hoop / backboard:** SceneKit still uses procedural poles + rim until you add optional rim/backboard GLBs and wire them in `GameSceneFactory.addHoop`.
