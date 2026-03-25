# PS3-Era Visual Spec: Vertical Velocity Academy Arena (Unreal Engine)

Upgrade the Arena visual pipeline from a flat/stylized look to **PS3-era fidelity**: PBR, dynamic lighting, bloom, motion blur, and higher-density meshes/animations. Use this doc as the strategic prompt for Cursor or implementation reference.

---

## 1. Material Pipeline (PBR)

- **BaseMaterial for skeletal characters**
  - Switch to a **Physically Based Rendering (PBR)** workflow.
  - Support: **Albedo**, **Normal**, **Roughness**, **Ambient Occlusion** (and Metalness if applicable).
  - Ensure all character materials use this master and instance from it.

- **“Fascial Highway” / neural characters**
  - Custom material/shader for characters that represent neural signal flow:
    - **Fresnel** for rim/edge highlight (signal at tissue boundaries).
    - **Emissive** driven by a pulse (e.g. time or gameplay) to visualize “signal flow” (brain → spine → limbs).
  - Target: high-end 7th-gen style (subtle but readable in motion).

---

## 2. Lighting & Post-Processing

- **PostProcessVolume**
  - **Bloom** – intensity and threshold tuned for 2008–2010 AAA sports (not overblown).
  - **Lens effects** – optional **Lens Flares** where appropriate (e.g. arena lights).
  - **Motion Blur** – per-object or camera motion blur consistent with that era.

- **Directional Light**
  - **Distance Field Shadows** enabled for sharp, stable shadows and good depth.

- **Sky Light**
  - **Real Time Capture** enabled so environment lighting and reflections update and characters get **realistic contact shadows** on the Arena floor.

---

## 3. Mesh & Animation Density

- **SkeletalMesh**
  - Replace low-poly placeholders with **higher-fidelity meshes** where needed.
  - Use **Normal Mapping** to suggest muscle/fascial definition without high polygon count (performance-friendly).

- **Movement snacks / “fascial rehydration”**
  - Use **Vertex Animation Textures (VAT)** for these sequences so they run at high frame rate and stay fluid (e.g. 90/90, rehydration flows).

---

## 4. Rendering Pipeline & Quality

- **Deferred Rendering** – project should use the **Deferred** rendering path.
- **TAA** – **Temporal Anti-Aliasing** enabled for stable, clean edges.
- **SSR** – **Screen Space Reflections** to ground characters in the environment (floor, walls).

---

## Key Engine Tools to Implement

| Tool | Purpose |
|------|--------|
| **Niagara (Fluids/Particles)** | “Neural Flow”: particles that **pulse** from brain down the spinal line when the player initiates a jump (or key movement), instead of static lines. |
| **Control Rig** | **90/90** and **Wall Push** reset animations: programmatic limb adjustment so **feet stay locked (IK)** to the floor regardless of character height. |
| **Virtual Textures** | High-detail Arena floor (e.g. pro hardwood, Total Body Board surface) without excessive GPU memory; stream high-res where needed. |

---

## Quick Reference: Cursor Prompts

Paste these when asking Cursor to implement:

1. **Materials**  
   *"Update the BaseMaterial for all skeletal characters to a PBR workflow (Albedo, Normal, Roughness, AO). Create a custom shader for Fascial Highway characters with Fresnel and Emissive pulses for neural signal flow."*

2. **Post & lighting**  
   *"Configure a PostProcessVolume with Bloom, Lens Flares, and Motion Blur (PS3-era sports style). Use Directional Light with Distance Field Shadows and Sky Light with Real Time Capture for contact shadows on the Arena floor."*

3. **Meshes & VAT**  
   *"Refactor SkeletalMesh usage: higher-fidelity models with Normal Mapping. Use Vertex Animation Textures (VAT) for movement snack / fascial rehydration animations."*

4. **Rendering**  
   *"Use Deferred Rendering. Enable TAA and Screen Space Reflections so characters are grounded in the environment."*

5. **Niagara**  
   *"Use Niagara for Neural Flow: particles that pulse from brain down the spine when the player initiates a jump."*

6. **Control Rig**  
   *"Use Control Rig for 90/90 and Wall Push resets so feet stay IK-locked to the floor regardless of character height."*

7. **Virtual Textures**  
   *"Use Virtual Textures for the detailed Arena floor (hardwood / Total Body Board) to keep memory under control."*

---

## iOS/Swift Side (Pre–Unreal Graphics Work)

Before touching Unreal graphics:

- **ArenaView.swift** scoring uses **`PRQ`** (from `Utilities/PRQScoring.swift`), not `PRQScoring`. All scoring calls use `PRQ.attributeLabel`, `PRQ.successChanceFromPRQ`, `PRQ.modeReward`, etc.
- Any **`Double.random`** must use **`Double.random(in: 0..<1)`** (the `in:` argument is required in Swift).
- There is no separate **ArenaViewModel**; flow and scoring are in **ArenaGameFlowView** and **GenericArenaPlayView** with state and `onGameEnd` callbacks.

---

## Optional: Fascial Spiral Line Shader (HLSL/C++)

For a **Fascial Spiral Line** (Anatomy Trains–style) in Unreal:

- Implement as a **custom Material** or **Material Function** that:
  - Samples a **flow texture** or **noise** along the spiral path.
  - Drives **Emissive** with a **Fresnel** term so the line is visible from the side and pulses with time or gameplay.
  - Optionally use a **Niagara ribbon** or **spline mesh** for the path and let the material handle the look.

A **concrete HLSL/Material snippet** for the Fascial Spiral Line is in **`UnrealStarter/FascialSpiralLine_ShaderSnippet.md`**: Custom Expression code, graph approximation, optional RGB flow, and mesh/Niagara usage.

---

*Vertical Velocity Academy — PS3-era visual spec for Unreal Engine integration.*
