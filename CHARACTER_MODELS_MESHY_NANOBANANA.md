# Character Models: Meshy + Nano Banana 3D

Use **Meshy** (meshy.ai) and **Nano Banana 3D** (nanobanana3d.app / ainanobanana.co) to create the character models needed for the Vertical Velocity Academy Arena and Final Evolution Lab. This doc lists required characters, prompt templates, and pipeline steps.

---

## Tools Overview

| Tool | Best for | Export | Notes |
|------|----------|--------|--------|
| **Meshy** | PBR textures, auto-rig, animations, game-ready assets | FBX, OBJ, glTF; Blender/Unity/Unreal | Text-to-3D, image-to-3D; Low Poly Mode for games; ~1.5 min per asset. |
| **Nano Banana 3D** | Consistent character/figurine from text or image; 3D print–ready | OBJ, FBX | Good for avatar variants and stylized figures; identity-consistent edits. |

**Suggested split:** Use **Meshy** for main rigged characters (dunker, arena athlete, Fascial Highway base mesh) and for PBR textures + animations. Use **Nano Banana 3D** for alternate avatar looks, figurine-style variants, or when you need strict character consistency across multiple exports.

---

## Required Character Models

### 1. Arena Athlete (base rigged character)

**Purpose:** Default player character for all arenas (basketball, karate, soccer, etc.). One rig, multiple material/outfit variants.

- **Meshy (Text-to-3D)**  
  - **Prompt:**  
    `Athletic human character, neutral T-pose, game-ready low-poly, stylized realism, wearing minimal sport gear, clean topology for rigging, full body, young adult, neutral expression.`
  - **Style:** Realistic or Cartoon (match your PS3-era target).
  - **Options:** Enable **Auto-Rig**; export **FBX** with skeleton. Use **Low Poly Mode** if available for game perf.
- **Nano Banana 3D**  
  - **Prompt:**  
    `Athletic figure, standing pose, game character style, full body, clean silhouette, ready for rigging.`
  - Use for **alternate base** or **outfit variant**; keep one “hero” from Meshy for main rig.

**Export:** FBX (with skinning if rigged). Import into Unreal → Skeletal Mesh + PBR material (Albedo, Normal, Roughness, AO).

---

### 2. Dunker (basketball dunk character)

**Purpose:** Venice Beach / Lab dunk contest. Needs clear dunk, gather, and landing poses; can be same rig as Arena Athlete with dunk animation.

- **Meshy**  
  - **Prompt:**  
    `Basketball dunker character, athletic build, arms up dunk pose, game-ready, low-poly, stylized realism, jersey and shorts, full body.`
  - Generate **2–3 key poses** (gather, apex dunk, land) as separate meshes for pose targets, or use Meshy **Animation** (e.g. “dunk” / “jump”) and export animated FBX.
- **Nano Banana 3D**  
  - **Prompt (image-to-3D if you have ref):**  
    `Basketball player dunking, mid-air, arms extended toward rim, stylized 3D figure.`
  - Use for **variant dunker look** or **promo/figurine**; retarget animation in Unreal from Meshy base.

**Pipeline:** One rigged dunker FBX from Meshy → Unreal; apply PBR materials and Fascial/emissive overlay for “neural” variant.

---

### 3. Fascial Highway / Neural Character

**Purpose:** Character that visualizes “neural signal flow” (CNS freeway, fascial slings). Same silhouette as athlete but with emissive/Fresnel-ready materials.

- **Meshy**  
  - **Prompt:**  
    `Semi-translucent athletic human figure, anatomical, subtle muscle definition, clean mesh for emissive glow, T-pose, game character, low-poly.`
  - **Text-to-Texture (Meshy):**  
    `Soft emissive blue and cyan gradient, vein-like lines, subtle pulse, PBR, seamless.`  
    Apply as **Emissive** map; use **Fresnel** in Unreal (see `UnrealStarter/FascialSpiralLine_ShaderSnippet.md`).
- **Nano Banana 3D**  
  - **Prompt:**  
    `Glowing anatomical figure, stylized, neural network style, human silhouette, clean 3D.`
  - Use for **alternate “neural” look** or **UI/hero art**; bring into Unreal as static or simple anim.

**Pipeline:** Base mesh from Meshy → in Unreal, apply custom material (Fresnel + emissive pulse + optional spiral line from FascialSpiralLine snippet).

---

### 4. Movement Snack / Rehydration Character (90/90, Wall Push)

**Purpose:** Characters for “movement snacks” (e.g. 90/90 seated, wall push). VAT (Vertex Animation Textures) or simple skeletal anims; feet IK-locked (Control Rig in Unreal).

- **Meshy**  
  - **Prompt (90/90):**  
    `Person seated on floor, 90/90 hip position, legs bent, relaxed upper body, low-poly game character, top-down and side view friendly.`
  - **Prompt (Wall Push):**  
    `Athlete in split-stance isometric push against wall, hands on wall, one leg forward, low-poly, game-ready.`
  - Export as **FBX**; in Unreal use **Control Rig** for IK so feet stay fixed regardless of character scale.
- **Nano Banana 3D**  
  - **Prompt:**  
    `Person in stretching pose, 90 degree legs, seated, 3D figurine style.`
  - Use for **consistent “rehydration” avatar** across multiple angles; export OBJ/FBX and drive with VAT or skeleton in Unreal.

**Pipeline:** One mesh per key pose (90/90, wall push); animate in Unreal with Control Rig or bake to VAT for many instances.

---

### 5. Avatar Outfit Variants (Standard, Developing, Flight, Elite)

**Purpose:** Same base athlete with different outfit/skin tones (see `UserProfile.AvatarSkinConfig`, `AvatarOutfitStyle`).

- **Meshy**  
  - **Text-to-Texture:**  
    `Jersey and shorts, [color], sport style, PBR, fabric, seamless.`  
    Create 4 texture sets (Standard = green/neutral, Developing = blue, Flight = cyan, Elite = purple) and instance material in Unreal.
- **Nano Banana 3D**  
  - Use **one base character image**; edit with text: “same character, elite purple outfit,” “same character, cyan flight suit,” etc. Export each as 3D or use 2D for UI; use 3D exports for in-scene figurines or lobby characters.

**Pipeline:** One Skeletal Mesh; 4+ Material Instances (Albedo/Normal/Roughness/AO + tint).

---

## Prompt Cheat Sheet (copy-paste)

| Character | Meshy (Text-to-3D) | Nano Banana 3D |
|-----------|--------------------|-----------------|
| **Arena Athlete** | `Athletic human character, T-pose, game-ready low-poly, stylized realism, minimal sport gear, full body, young adult.` | `Athletic figure, standing, game character, full body, clean.` |
| **Dunker** | `Basketball dunker, athletic, arms up dunk pose, game-ready low-poly, jersey and shorts.` | `Basketball player dunking, mid-air, arms to rim, 3D figure.` |
| **Fascial / Neural** | `Semi-translucent athletic figure, anatomical, clean mesh for emissive, T-pose, low-poly.` | `Glowing anatomical figure, neural style, human silhouette.` |
| **90/90 Seated** | `Person seated, 90/90 hip position, legs bent, low-poly game character.` | `Person stretching, 90 degree legs, seated, 3D figurine.` |
| **Wall Push** | `Athlete split-stance isometric push on wall, hands on wall, low-poly game.` | (Use Meshy as primary; Nano for alternate.) |

---

## Pipeline Summary

1. **Create in Meshy:** Base Arena Athlete + Dunker (+ key poses or animation). Enable Auto-Rig; export FBX. Use Text-to-Texture for PBR (Albedo, Normal, Roughness, AO).
2. **Create in Nano Banana 3D:** Alternate looks, figurine variants, or consistency passes; export OBJ/FBX.
3. **Unreal:** Import FBX → Skeletal Mesh. Apply PBR material; for Fascial character add Fresnel + Emissive (and optional FascialSpiralLine material). Use Control Rig for 90/90 and Wall Push IK. VAT for movement snack crowds if needed.
4. **iOS/RealityKit:** Currently uses procedural dunker (box/sphere); if you later ship 3D characters on iOS, export from Meshy/Nano as glTF or USD and convert for RealityKit.

---

## Links

- **Meshy:** https://www.meshy.ai (Text-to-3D, Image-to-3D, Text-to-Texture, Animation; API available)
- **Nano Banana 3D:** https://nanobanana3d.app / https://ainanobanana.co/nano-banana-3d (Text/Image to 3D figurine; OBJ/FBX)
- **Unreal Fascial Spiral shader:** `UnrealStarter/FascialSpiralLine_ShaderSnippet.md`
- **PS3-era visual spec:** `PS3_ERA_UNREAL_VISUAL_SPEC.md`

---

*Vertical Velocity Academy — character production with Meshy and Nano Banana 3D.*
