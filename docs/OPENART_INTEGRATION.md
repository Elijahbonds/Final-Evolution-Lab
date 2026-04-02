# OpenArt.ai Enhanced Environment Integration

## Overview

The OpenArt integration adds **504 additional world assets** across all **12 preset environments** in Final Evolution Lab. These assets enhance visual quality by adding detailed props, PBR material sets, atmospheric effects, skybox variations, and detail decals to every scene.

### Asset Summary

| Category | Per Environment | Total (12 envs) | Description |
|----------|----------------|-----------------|-------------|
| Props | 12 | 144 | Scene objects (trees, signs, furniture, equipment) |
| Textures | 5 | 60 | Tileable surface textures (walls, floors, ground) |
| Materials | 3 × 5 maps | 180 files | PBR material sets (albedo, normal, roughness, metallic, AO) |
| Atmosphere | 3 | 36 | Fog, particles, light rays, weather effects |
| Skybox | 3 | 36 | Equirectangular panoramic sky variations |
| Details | 4 | 48 | Graffiti, stains, cracks, decorative elements |
| **Total** | **30 entries** | **504 files** | |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│         OpenArt Enhanced Environment Pipeline        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  openart_prompt_templates.py                        │
│    └─ 12 environments × 6 categories of prompts    │
│                                                     │
│  openart_api_client.py                              │
│    ├─ OpenArt.ai API (when available)               │
│    └─ Procedural Fallback (PIL + NumPy)             │
│                                                     │
│  procedural_asset_generator.py                      │
│    ├─ PBR texture generation (noise-based)          │
│    ├─ Prop silhouette cards (draw-based)            │
│    ├─ Atmospheric overlays (fog, rain, particles)   │
│    ├─ Skybox gradients (environment-aware)          │
│    └─ Detail/decal generation                       │
│                                                     │
│  openart_enhanced_pipeline.py                       │
│    ├─ Orchestrates generation across environments   │
│    ├─ Manifest-based caching (no re-generation)     │
│    └─ Quality presets (ultra/high/medium/mobile)    │
│                                                     │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│          GeneratedAssets/Environments/               │
│  ├─ retro_tokyo_night/openart/                      │
│  │   ├─ props/          (12 PNG files)              │
│  │   ├─ textures/       (5 PNG files)               │
│  │   ├─ materials/      (3 dirs × 5 maps each)     │
│  │   ├─ atmosphere/     (3 PNG files)               │
│  │   ├─ skybox/         (3 PNG files)               │
│  │   └─ details/        (4 PNG files)               │
│  ├─ venice_beach_sunset/openart/                    │
│  ├─ cyberpunk_gym/openart/                          │
│  └─ ... (12 environments total)                     │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│           UE5 Integration                           │
│  ├─ fel_import_openart_assets.py  (Editor Python)   │
│  ├─ FELOpenArtAssetPaths.h        (C++ header)      │
│  └─ import_all_assets.sh          (build pipeline)  │
└─────────────────────────────────────────────────────┘
```

---

## Quick Start

### Generate Assets

```bash
cd /path/to/rork-final-evolution-lab

# Generate all environments at high quality
python -m scripts.environment_gen.openart_enhanced_pipeline --quality high

# Generate a single environment
python -m scripts.environment_gen.openart_enhanced_pipeline --env retro_tokyo_night

# Generate only textures for all environments
python -m scripts.environment_gen.openart_enhanced_pipeline --category textures

# Preview without generating
python -m scripts.environment_gen.openart_enhanced_pipeline --dry-run

# List all environments and asset counts
python -m scripts.environment_gen.openart_enhanced_pipeline --list
```

### Import into UE5

```bash
# Via the full build pipeline
./scripts/ue5_setup/fel_complete_pipeline.sh

# Or import OpenArt assets only (in UE5 Editor)
# Edit → Editor Preferences → Python → Execute:
#   EditorPython/fel_import_openart_assets.py

# Or via commandlet
$UE_CMD $FEL_PROJECT -run=pythonscript \
  -script=EditorPython/fel_import_openart_assets.py \
  -nosplash -unattended -nopause
```

---

## Environment Details

### 1. Retro Tokyo Night
Neon-soaked Tokyo street court at night with rain reflections, graffiti, and vending machines.
- **Props**: Neon signs, vending machines, phone booths, ramen carts, shrine gates
- **Textures**: Wet asphalt, brick alleys, metal shutters
- **Atmosphere**: Neon fog, rain particles, volumetric light rays

### 2. Venice Beach Sunset
California beach court at golden hour with palm trees and skatepark vibes.
- **Props**: Palm trees, lifeguard tower, skateboard ramp, surfboard rack, taco truck
- **Textures**: Beach sand, boardwalk wood, stucco walls
- **Atmosphere**: Golden haze, dust in sunlight, sunset god rays

### 3. Cyberpunk Gym
Futuristic training facility with holograms, neon lighting, and tech equipment.
- **Props**: Hologram displays, training pods, LED floor strips, drone cameras
- **Textures**: Hexagonal tiles, carbon fiber, circuit board walls
- **Atmosphere**: Cyan/magenta haze, holographic particles, neon bloom

### 4. Classic NBA Arena
1990s-style basketball arena with hardwood court and packed crowd.
- **Props**: Jumbotron, courtside seats, championship banners, shot clocks
- **Textures**: Maple hardwood, painted lanes, arena seat fabric
- **Atmosphere**: Spotlight haze, crowd dust, dramatic light beams

### 5. Underground Bunker
Military-style underground training facility with raw concrete and industrial lighting.
- **Props**: Heavy bags, ammo crates, tire stacks, military lockers
- **Textures**: Raw concrete, rusted metal, cinder block, rubber mats
- **Atmosphere**: Chalk dust, condensation fog, harsh spotlights

### 6. Rooftop Cityscape
Urban rooftop court above a megacity skyline at dusk.
- **Props**: Chain-link fence, AC units, water towers, fire escapes
- **Textures**: Tar rooftop, brick parapet, metal grating
- **Atmosphere**: City haze, wind dust, sunset rays between buildings

### 7. Winter Outdoor
Outdoor court in winter with snow, frost, and warm street lamp glow.
- **Props**: Bare trees, frozen hoops, fire barrels, snow piles
- **Textures**: Snow ground, icy concrete, frozen asphalt
- **Atmosphere**: Snowfall particles, breath fog, warm lamp glow

### 8. Beach Tropical
Paradise island court on white sand with turquoise water.
- **Props**: Coconut palms, beach umbrellas, tiki torches, hammocks
- **Textures**: White sand, palm bark, bamboo mat, coral stone
- **Atmosphere**: Ocean mist, sun sparkle, tropical light rays

### 9. Warehouse Industrial
Converted warehouse gym with exposed brick and industrial fixtures.
- **Props**: Steel beams, cage lights, pallet stacks, boxing ring, forklifts
- **Textures**: Exposed brick, concrete, corrugated metal, wood planks
- **Atmosphere**: Dust haze, smoke wisps, skylight shafts

### 10. Neon Arcade
Synthwave 80s arcade with glowing grid floors and vaporwave aesthetics.
- **Props**: Arcade cabinets, pinball machines, disco balls, neon palms
- **Textures**: Neon grid floor, pixel tiles, chrome panels
- **Atmosphere**: Neon haze, sparkle particles, laser beams

### 11. Zen Dojo
Traditional Japanese training hall with tatami, wood, and serene minimalism.
- **Props**: Bonsai trees, paper screens, weapon racks, incense holders
- **Textures**: Tatami mats, dark wood beams, washi paper, zen garden sand
- **Atmosphere**: Incense smoke, dust in sunlight, warm lantern glow

### 12. Stadium Night Game
Professional soccer stadium under floodlights with packed crowd.
- **Props**: Floodlight towers, goal posts, corner flags, camera cranes
- **Textures**: Green grass pitch, running track, concrete terraces
- **Atmosphere**: Floodlight haze, crowd flare smoke, firework sparks

---

## OpenArt API Integration

### Current Status
OpenArt.ai does **not currently expose a public REST API**. The system is designed to seamlessly switch to the API when it becomes available.

### When API is Available
1. Set `OPENART_API_KEY` in `.env`
2. The client will automatically detect and use the API
3. All prompt templates are optimized for AI image generation
4. Polling-based task completion handles async generation

### Procedural Fallback
When the API is unavailable, assets are generated procedurally:
- **Textures**: Fractal Brownian Motion noise with environment-specific color palettes
- **Normal maps**: Gradient-based height → normal conversion
- **Roughness/Metallic**: Material-aware value ranges
- **Props**: Silhouette cards with themed shapes (trees, signs, furniture)
- **Atmosphere**: Layered noise fog, particle overlays, volumetric ray approximations
- **Skybox**: Multi-stop gradient with cloud noise and star patterns

All procedural assets are **deterministic** — the same prompt always produces the same result, enabling caching and reproducibility.

---

## Quality Presets

| Preset | Texture | Prop | Material | Skybox | Target |
|--------|---------|------|----------|--------|--------|
| ultra | 2048 | 1024 | 2048 | 4096 | High-end PC |
| high | 1024 | 512 | 1024 | 2048 | PC / Console |
| medium | 512 | 512 | 512 | 1024 | Mid-range PC |
| mobile | 512 | 256 | 512 | 1024 | iOS / Android |

---

## File Structure

```
scripts/environment_gen/
├── openart_api_client.py          # API client with procedural fallback
├── openart_prompt_templates.py    # 360 prompt definitions for 12 environments
├── openart_enhanced_pipeline.py   # Main generation orchestrator (CLI)
├── procedural_asset_generator.py  # PIL/NumPy procedural generation engine

GeneratedAssets/Environments/
├── openart_asset_manifest.json    # Master manifest tracking all 504 assets
├── <env_key>/openart/
│   ├── props/                     # 12 prop PNG files
│   ├── textures/                  # 5 texture PNG files
│   ├── materials/                 # 3 PBR material directories
│   │   └── <material_name>/       # 5 PBR maps each (albedo, normal, roughness, metallic, ao)
│   ├── atmosphere/                # 3 atmospheric overlay PNG files
│   ├── skybox/                    # 3 equirectangular skybox PNG files
│   └── details/                   # 4 detail/decal PNG files

UnrealStarter/BasketballGame/
├── EditorPython/
│   └── fel_import_openart_assets.py   # UE5 batch import script
└── Source/FinalEvolutionLab/
    └── FELOpenArtAssetPaths.h         # C++ asset path constants (360 entries)
```

---

## Troubleshooting

### "No assets generated"
- Ensure Python 3.8+ with `Pillow` and `numpy` installed
- Check that `GeneratedAssets/Environments/` directory exists
- Run with `--list` flag to verify prompt template loading

### "Material instances not created in UE5"
- Ensure base material `M_OpenArt_PBR` exists at `/Game/FEL/Materials/`
- Run import script inside UE5 Editor (not commandlet)

### "Manifest says cached but files missing"
- Delete `openart_asset_manifest.json` to force regeneration
- Or delete specific environment directory and re-run

### Performance
- Generation time: ~8 minutes for all 504 assets (medium quality)
- Disk usage: ~60-80 MB total (all environments)
- Memory: Peak ~200 MB during generation
