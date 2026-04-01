# AI Asset Pipeline — DeepMotion + Meshy + Luma AI

Automated pipeline for generating 3D animations, models, and environments for Final Evolution Lab using three AI services.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      AI Asset Pipeline                           │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│  Luma AI     │  DeepMotion  │    Meshy     │  Asset Manager     │
│  (Reference  │  (Motion     │  (3D Model   │  (Manifest +       │
│   Images &   │   Capture)   │   Generation)│   Cache + UE       │
│   Videos)    │              │              │   Import)          │
├──────────────┴──────┬───────┴──────────────┴────────────────────┤
│                     │                                            │
│  Exercise Pipeline: │  Environment Pipeline:                     │
│  1. Luma → Video    │  1. Luma → Reference Image                 │
│  2. DeepMotion →    │  2. Meshy → Image-to-3D Model              │
│     FBX/BVH Mocap   │                                            │
│  3. Meshy → Props   │                                            │
├─────────────────────┴────────────────────────────────────────────┤
│            Unreal Engine 5 Import + Runtime Loading              │
│  - UFELAIAssetManagerSubsystem (C++ runtime loader)              │
│  - fel_import_ai_assets.py (Editor Python batch import)          │
│  - FELGeneratedAssetPaths.h (compile-time soft references)       │
└──────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Install Dependencies

```bash
pip install -r scripts/ai_asset_pipeline/requirements.txt
```

### 2. Set API Keys

```bash
cp scripts/ai_asset_pipeline/.env.example .env
# Edit .env with your API keys
```

| Service    | Key Variable              | Get From                                  |
|------------|---------------------------|-------------------------------------------|
| DeepMotion | `DEEPMOTION_CLIENT_ID`    | https://www.deepmotion.com/animate-3d-api |
|            | `DEEPMOTION_CLIENT_SECRET`|                                           |
| Meshy      | `MESHY_API_KEY`           | https://www.meshy.ai/api → Settings       |
| Luma AI    | `LUMA_API_KEY`            | https://lumalabs.ai/dream-machine/api     |

### 3. Generate Exercise Animations (All 23)

```bash
# Dry run — see what would be generated
python -m scripts.ai_asset_pipeline.exercise_batch_generator --all --dry-run

# Generate everything
python -m scripts.ai_asset_pipeline.exercise_batch_generator --all

# Single exercise
python -m scripts.ai_asset_pipeline.exercise_batch_generator --exercise squat_form

# By category
python -m scripts.ai_asset_pipeline.exercise_batch_generator --category strength
```

### 4. Generate Environment Assets (12 Venues)

```bash
python -m scripts.ai_asset_pipeline.environment_generator --all --dry-run
python -m scripts.ai_asset_pipeline.environment_generator --all
python -m scripts.ai_asset_pipeline.environment_generator --venue venice_basketball
```

### 5. Import into Unreal Engine

```bash
# Update ExerciseCatalog.json with generated asset paths
python -m scripts.ai_asset_pipeline.unreal_import_helper --update-catalog

# Generate UE Editor Python import script
python -m scripts.ai_asset_pipeline.unreal_import_helper --generate-import-script

# Generate C++ asset paths header
python -m scripts.ai_asset_pipeline.unreal_import_helper --generate-header

# All of the above
python -m scripts.ai_asset_pipeline.unreal_import_helper --all
```

Then in Unreal Editor: **Tools → Execute Python Script** → select `EditorPython/fel_import_ai_assets.py`.

## Services

### DeepMotion (`deepmotion_service.py`)

Wraps the existing `scripts/deepmotion_animate3d_pipeline.py` with a unified interface.

```python
from scripts.ai_asset_pipeline.deepmotion_service import DeepMotionService
svc = DeepMotionService()
result = svc.process_video("exercise_clip.mp4", out_dir="./out", formats=["fbx","bvh"])
```

### Meshy (`meshy_service.py`)

REST API client for Meshy's Text-to-3D and Image-to-3D endpoints.

```python
from scripts.ai_asset_pipeline.meshy_service import MeshyService
svc = MeshyService()

# Text-to-3D (preview → refine → download)
result = svc.text_to_3d_full("Olympic barbell with weight plates", out_dir=Path("./out"))

# Image-to-3D
result = svc.image_to_3d_full("https://upload.wikimedia.org/wikipedia/commons/5/5d/Hardcourt_tennis_court_curtiss_park_saline_michigan.JPG", out_dir=Path("./out"))

# Check balance
print(svc.get_balance())
```

**CLI:**
```bash
python -m scripts.ai_asset_pipeline.meshy_service text2mesh --prompt "Basketball" --out ./out
python -m scripts.ai_asset_pipeline.meshy_service img2mesh --image-url "https://upload.wikimedia.org/wikipedia/commons/0/06/Steph_Curry_%2851915116957%29.jpg" --out ./out
python -m scripts.ai_asset_pipeline.meshy_service balance
```

### Luma AI (`luma_service.py`)

REST API client for Luma Dream Machine (images via Photon, videos via Ray2).

```python
from scripts.ai_asset_pipeline.luma_service import LumaAIService
svc = LumaAIService()

# Environment reference image
result = svc.generate_environment_reference("Venice Beach basketball court", out_dir=Path("./out"))

# Exercise reference video
result = svc.generate_exercise_reference_video("Person doing squats", out_dir=Path("./out"))
```

**CLI:**
```bash
python -m scripts.ai_asset_pipeline.luma_service generate_image --prompt "..." --out ./out
python -m scripts.ai_asset_pipeline.luma_service generate_video --prompt "..." --out ./out
python -m scripts.ai_asset_pipeline.luma_service environment --prompt "..." --out ./out
```

## Asset Caching

The `AssetManifest` (`GeneratedAssets/asset_manifest.json`) tracks all generated assets:

```json
{
  "squat_form_reference_video": {
    "service": "luma",
    "task_id": "abc123",
    "status": "completed",
    "created_at": "2026-04-01T...",
    "files": ["GeneratedAssets/luma/squat_form/vid_abc123.mp4"],
    "params": {"prompt": "..."}
  }
}
```

Re-running the pipeline skips already-completed assets automatically. Delete an entry from the manifest (or its files) to regenerate.

## Exercise Pipeline (23 Exercises)

Each exercise goes through up to 3 stages:

| Stage | Service    | Input              | Output           | Cost   |
|-------|------------|--------------------|------------------|--------|
| 1     | Luma AI    | Text prompt        | Reference video  | ~$0.05 |
| 2     | DeepMotion | Video file         | FBX + BVH mocap  | Varies |
| 3     | Meshy      | Text prompt (props)| GLB + FBX model  | ~30 cr |

Only 9 of 23 exercises need props (Stage 3).

## Unreal Integration

### Runtime (C++)

`UFELAIAssetManagerSubsystem` loads assets at runtime:

```cpp
// In any Actor or Subsystem
auto* AssetMgr = GetGameInstance()->GetSubsystem<UFELAIAssetManagerSubsystem>();
UAnimMontage* Anim = AssetMgr->LoadExerciseAnimation(TEXT("squat_form"));
UStaticMesh* Prop = AssetMgr->LoadExerciseProp(TEXT("squat_form"));
UStaticMesh* Env = AssetMgr->LoadEnvironmentMesh(TEXT("venice_basketball"));
```

### Pixel Streaming Bridge

The existing `UFELPixelStreamingBridge` can trigger exercise demos which now use AI-generated animations when available. The `HandleExerciseDemo()` function in the bridge routes to `UFELExerciseCatalogSubsystem`, which checks for AI-generated montages first.

## File Structure

```
scripts/ai_asset_pipeline/
├── __init__.py                  # Package init
├── config.py                    # Centralized config (env vars)
├── deepmotion_service.py        # DeepMotion wrapper
├── meshy_service.py             # Meshy REST API client
├── luma_service.py              # Luma AI REST API client
├── asset_cache.py               # Manifest & caching
├── exercise_batch_generator.py  # Batch exercise pipeline
├── environment_generator.py     # Venue environment pipeline
├── unreal_import_helper.py      # UE import script generator
├── requirements.txt             # Python dependencies
├── .env.example                 # API key template
└── README.md                    # This file

GeneratedAssets/                 # Output directory (gitignored)
├── deepmotion/                  # Motion capture FBX/BVH
├── meshy/                       # 3D models GLB/FBX
├── luma/                        # Reference images/videos
├── .cache/                      # Temporary files
└── asset_manifest.json          # Generation tracking

UnrealStarter/.../Source/FinalEvolutionLab/
├── FELGeneratedAssetPaths.h          # Auto-generated paths header
├── UFELAIAssetManagerSubsystem.h     # Runtime asset loader
└── UFELAIAssetManagerSubsystem.cpp   # Implementation
```
