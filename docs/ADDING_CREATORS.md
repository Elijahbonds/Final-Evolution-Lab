# Adding New Creators to Final Evolution Lab

This guide explains how to add new creators to the Creator Card System.

---

## Quick Start

```bash
# 1. Copy the template
cp Tools/creator_template.json Tools/my_new_creator.json

# 2. Edit the template with creator info
nano Tools/my_new_creator.json

# 3. Validate the data
python3 Tools/add_creator.py --validate Tools/my_new_creator.json

# 4. Add to the database
python3 Tools/add_creator.py --file Tools/my_new_creator.json

# 5. Generate visual assets
python3 -m scripts.creator_pipeline.generate_creator_assets --creator new_creator_id

# 6. (Optional) Generate 3D model
python3 -m scripts.creator_pipeline.meshy_creator_model --creator new_creator_id

# 7. Import into UE5
# Run EditorPython/fel_import_creator_assets.py in UE5 Editor
```

---

## Interactive Mode

For a guided setup:

```bash
python3 Tools/add_creator.py --interactive
```

---

## Creator Template Fields

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | string | Unique lowercase ID | `"john_doe"` |
| `display_name` | string | Full display name | `"John Doe"` |
| `tagline` | string | Short catchphrase (max 50 chars) | `"The Sharpshooter"` |
| `bio` | string | Full biography (100-500 chars) | `"Professional basketball..."` |
| `location` | string | Home location | `"Venice Beach, CA"` |
| `primary_sport` | string | Main sport | `"Basketball"` |
| `position` | string | Playing position | `"Guard"` |
| `tier` | enum | Creator tier | `"Community"` |
| `card_style` | enum | Card visual style | `"Standard"` |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `height` | string | `""` | Display height |
| `weight` | string | `""` | Display weight |
| `has_3d_model` | bool | `false` | Whether a 3D model exists |
| `is_featured` | bool | `false` | Show in featured carousel |
| `is_playable` | bool | `false` | Can players play as this creator |
| `sort_order` | int | `99` | Gallery display order |

### Tier Values

- **Featured** — Top-tier creators with full content (Elijah Bonds, Amir Smith)
- **Verified** — Verified creators with good content (Eric Nash)
- **Community** — Community contributors
- **ComingSoon** — Placeholder for upcoming creators

### Card Style Values

- **Standard** — Default card appearance
- **Premium** — Enhanced visuals with subtle effects
- **Legendary** — Gold/animated card border
- **Holographic** — 3D holographic effect (for creators with 3D models)

---

## Content Requirements

### Images

| Asset | Size | Format | Notes |
|-------|------|--------|-------|
| Profile Image | 512×512 px | PNG | Circular crop in UI |
| Banner Image | 1920×400 px | PNG | Wide landscape |
| Card Background | 400×530 px | PNG | Portrait orientation |

### Videos

| Format | Codec | Resolution | Max Duration |
|--------|-------|------------|-------------|
| MP4 | H.264 | 1080p or 720p | 120 seconds |

### 3D Models

| Format | Polygons | Textures |
|--------|----------|----------|
| GLB/FBX | <50,000 | PBR (4K max) |

---

## Highlight Types

- `gameplay` — Game/match footage
- `dunk` — Dunk highlights
- `training` — Training/coaching content
- `magic_reveal` — AR magic reveal videos
- `3d_model` — 3D model showcase (no video, model viewer)

---

## Signature Move Categories

- `dunk` — Dunks and slam moves
- `shooting` — Shooting techniques
- `ball_handling` — Dribble moves and crossovers
- `defense` — Defensive moves
- `passing` — Passing techniques
- `post_move` — Post-up moves
- `transition` — Fast break / transition plays

---

## Generating Visual Assets

The asset pipeline uses **Luma AI** for images and **Meshy** for 3D models.

### Prerequisites

```bash
# Set API keys in .env
LUMA_API_KEY=your_key_here
MESHY_API_KEY=your_key_here
```

### Generate Profile Images & Banners

```bash
# Single creator
python3 -m scripts.creator_pipeline.generate_creator_assets --creator john_doe

# All creators
python3 -m scripts.creator_pipeline.generate_creator_assets --all

# Icons only
python3 -m scripts.creator_pipeline.generate_creator_assets --icons-only

# Dry run (preview without generating)
python3 -m scripts.creator_pipeline.generate_creator_assets --all --dry-run
```

### Generate 3D Model (via Meshy)

```bash
# Add custom prompt to CREATOR_MODEL_PROMPTS in meshy_creator_model.py first
python3 -m scripts.creator_pipeline.meshy_creator_model --creator john_doe

# List recent Meshy tasks
python3 -m scripts.creator_pipeline.meshy_creator_model --list-tasks
```

---

## Importing into Unreal Engine 5

### Automatic Import

1. Open the UE5 project
2. Go to **Tools > Execute Python Script**
3. Select `EditorPython/fel_import_creator_assets.py`
4. The script will import all found creator assets

### Manual Import

1. Open **Content Browser**
2. Navigate to `/Game/FEL/CreatorAssets/`
3. Import images from `GeneratedAssets/CreatorAssets/`
4. Import models from `GeneratedAssets/CreatorModels/`

### Asset Directory Structure

```
Content/FEL/
├── CreatorAssets/
│   ├── Profiles/         # 512x512 profile images
│   ├── Banners/          # 1920x400 banners
│   ├── Backgrounds/      # Card backgrounds
│   ├── Thumbnails/       # Video thumbnails
│   └── Icons/            # Stat icons, badges
├── CreatorModels/
│   └── AmirSmith/        # Amir's 3D model
├── Videos/
│   ├── MagicReveal/      # Magic reveal videos
│   ├── ElijahBonds/      # Elijah's highlights
│   ├── AmirSmith/        # Amir's highlights
│   └── EricNash/         # Eric's highlights
└── Data/
    └── CreatorProfiles.json
```

---

## C++ Integration

### Access Creator Data in Code

```cpp
#include "FELCreatorManager.h"

// Get the manager
UFELCreatorManager* CM = GetGameInstance()->GetSubsystem<UFELCreatorManager>();

// Get a profile
FCreatorProfile Profile;
if (CM->GetCreatorProfile(TEXT("elijah_bonds"), Profile))
{
    UE_LOG(LogTemp, Log, TEXT("Creator: %s"), *Profile.DisplayName);
}

// Get featured creators
TArray<FCreatorProfile> Featured = CM->GetFeaturedCreators();

// Select a creator
CM->SelectCreator(TEXT("amir_smith"));

// Load 3D model
USkeletalMesh* Model = CM->LoadCreatorModel(TEXT("amir_smith"));
```

### Challenge Integration

```cpp
#include "FELCreatorChallengeManager.h"

// Add to game mode actor
UFELCreatorChallengeManager* Challenges = NewObject<UFELCreatorChallengeManager>(this);
Challenges->ActivateCreatorChallenges(TEXT("elijah_bonds"));

// Report progress
Challenges->IncrementScore(TEXT("eb_dunk_gauntlet"), 1);
Challenges->ReportScore(TEXT("eb_500_shot_challenge"), CurrentShots);
```

---

## Blueprint Integration

### Creator Gallery

1. Create a Blueprint child of `UFELCreatorGalleryWidget`
2. Design the UMG layout in the Widget Designer
3. Bind widgets using the `BindWidget` names from the C++ class
4. Call `InitializeGallery()` to populate

### Creator Profile Page

1. Create a Blueprint child of `UFELCreatorProfileWidget`
2. Design the full profile layout
3. Call `LoadProfile(CreatorID)` to display a creator

### Main Menu Integration

1. Add a "Creators" button to the main menu
2. On click, create and display the Creator Gallery widget
3. The gallery handles navigation to individual profiles

---

## Current Creators

| Creator | Tier | 3D Model | Highlights | Challenges |
|---------|------|----------|------------|------------|
| Elijah Bonds | Featured/Legendary | No | 10 (7 Magic Reveal + 3 Dunks) | 3 |
| Amir Smith | Featured/Holographic | Yes (Meshy) | 3 | 2 |
| Eric Nash | Verified/Premium | No | 3 | 3 |

---

## Troubleshooting

### "CreatorProfiles.json not found"
- Ensure the file is at `Content/FEL/Data/CreatorProfiles.json`
- Run `python3 Tools/add_creator.py --list` to verify

### "Failed to load 3D model"
- Run the import script in UE5 Editor first
- Check that GLB/FBX files exist in `GeneratedAssets/CreatorModels/`

### "API key not set"
- Check `.env` file for `LUMA_API_KEY` and `MESHY_API_KEY`
- The asset generator creates placeholder entries if no key is set

### Adding to the Meshy pipeline
1. Edit `scripts/creator_pipeline/meshy_creator_model.py`
2. Add a new entry to `CREATOR_MODEL_PROMPTS`
3. Run `python3 -m scripts.creator_pipeline.meshy_creator_model --creator new_id`
