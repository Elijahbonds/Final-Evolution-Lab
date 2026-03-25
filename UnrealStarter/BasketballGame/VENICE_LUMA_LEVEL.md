# Venice court + Luma scan — one playable environment

**“Compile”** here means **import** meshes and **compose** them in a **Persistent Level** (no special C++ required for the static geometry).

## 1. Import

| Asset | Source in repo | Content path (suggested) | Rename to |
|--------|----------------|---------------------------|-----------|
| Luma scan | `UnrealStarter/LumaScan/mesh.obj` + `textures/` | `/Game/FEL/Environment/Luma/` | `SM_LumaCourt` |
| Venice court | `MeshyAssets/Venice_beach_UE5/Venice_mesh.obj` + `textures/` (or Meshy GLB) | `/Game/FEL/Environment/Venice/` | `SM_VeniceCourt` |

Use **Static Mesh**, **Nanite** if useful, **collision** on both (player must walk on Venice floor).

## 2. Layout (recommended starting point)

1. Drag **`SM_LumaCourt`** into the level — this is the **world / backdrop** (scan footprint ~4 m; scale up if you want it to read as “environment shell”).
2. Drag **`SM_VeniceCourt`** in front of the playable area — **this is the actual court** (lines, hoop zones). **Scale and rotate** so:
   - Floor normal is **+Z** (Unreal up).
   - Venice mesh **sits on** or **clips slightly into** the Luma ground so there is no gap.
3. Add **PlayerStart** on the Venice floor, facing along the court.
4. Add **Directional Light** + **Sky Atmosphere** or **Sky Light** so the Meshy materials read clearly.

## 3. Tuning

- If Venice and Luma **units** differ, uniform **scale** one mesh (often Luma stays 1.0, Venice scaled to match real-world feel).
- For a **single cohesive look**, later you can **replace** Luma materials with a shared neutral ground material in the **Material Instances** Unreal generated on import.

## 4. Game mode

Set **GameMode Override** to **`FELBasketballGameMode`** so the **Elijah** pawn and **ball** spawn automatically (after C++ integration and successful build).

---

*Final Evolution Lab — UnrealStarter.*
