"""Configuration for the Generative Environment Pipeline.

Loads API keys from environment variables or .env file.
Defines model defaults, output paths, and quality presets.
"""

import os
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional, Dict, List

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
except ImportError:
    pass

# ---------------------------------------------------------------------------
# Project paths
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[2]
GENERATED_ROOT = PROJECT_ROOT / "GeneratedAssets" / "Environments"
CACHE_DIR = GENERATED_ROOT / ".cache"
MANIFEST_PATH = GENERATED_ROOT / "environment_manifest.json"
UE5_CONTENT = PROJECT_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Environments"


@dataclass
class StableVideoDiffusionConfig:
    """Stability AI - Stable Video Diffusion."""
    api_key: str = field(default_factory=lambda: os.getenv("STABILITY_API_KEY", ""))
    base_url: str = "https://api.stability.ai/v2beta"
    model: str = "stable-video-diffusion-img2vid-xt-1-1"
    cfg_scale: float = 2.5
    motion_bucket_id: int = 127
    fps: int = 24
    frames: int = 25
    width: int = 1024
    height: int = 576

    def validate(self) -> bool:
        if not self.api_key:
            print("[WARN] STABILITY_API_KEY not set")
            return False
        return True


@dataclass
class RunwayConfig:
    """Runway Gen-3 Alpha / Turbo."""
    api_key: str = field(default_factory=lambda: os.getenv("RUNWAY_API_KEY", ""))
    base_url: str = "https://api.dev.runwayml.com/v1"
    model: str = "gen3a_turbo"
    duration: int = 10  # seconds
    ratio: str = "16:9"
    watermark: bool = False

    def validate(self) -> bool:
        if not self.api_key:
            print("[WARN] RUNWAY_API_KEY not set")
            return False
        return True


@dataclass
class LumaDreamMachineConfig:
    """Luma AI Dream Machine for video generation."""
    api_key: str = field(default_factory=lambda: os.getenv("LUMA_API_KEY", ""))
    base_url: str = "https://api.lumalabs.ai/dream-machine/v1"
    model: str = "ray2"
    aspect_ratio: str = "16:9"
    loop: bool = True

    def validate(self) -> bool:
        if not self.api_key:
            print("[WARN] LUMA_API_KEY not set")
            return False
        return True


@dataclass
class GaiaConfig:
    """NVIDIA Gaia / Cosmos-style world model (future integration)."""
    api_key: str = field(default_factory=lambda: os.getenv("GAIA_API_KEY", ""))
    base_url: str = "https://api.nvidia.com/gaia/v1"  # Placeholder
    model: str = "gaia-1"
    world_size: str = "medium"  # small / medium / large
    output_format: str = "video"  # video / latent

    def validate(self) -> bool:
        if not self.api_key:
            print("[WARN] GAIA_API_KEY not set - Gaia integration pending public API")
            return False
        return True


@dataclass
class QualityPreset:
    """Rendering quality preset for target devices."""
    name: str
    skybox_resolution: int
    video_texture_resolution: int
    cubemap_faces: int
    target_fps: int
    hdr: bool
    compression: str  # 'bc7' | 'astc' | 'etc2'


# Quality presets for different deployment targets
QUALITY_PRESETS: Dict[str, QualityPreset] = {
    "ultra": QualityPreset("ultra", 4096, 2048, 6, 60, True, "bc7"),
    "high": QualityPreset("high", 2048, 1024, 6, 60, True, "bc7"),
    "medium": QualityPreset("medium", 1024, 512, 6, 60, False, "bc7"),
    "mobile": QualityPreset("mobile", 1024, 512, 6, 60, False, "astc"),
    "mobile_low": QualityPreset("mobile_low", 512, 256, 6, 30, False, "etc2"),
}


# ---------------------------------------------------------------------------
# Prompt templates
# ---------------------------------------------------------------------------
ENVIRONMENT_PROMPTS: Dict[str, str] = {
    "retro_tokyo_night": (
        "Retro 2006 NBA Street style basketball court in Tokyo at night, "
        "neon puddles reflecting street lights, graffiti walls, "
        "urban gritty aesthetic, cinematic lighting, "
        "wide angle panoramic view, seamless 360 degree environment"
    ),
    "venice_beach_sunset": (
        "Venice Beach basketball court at golden hour sunset, "
        "palm trees silhouetted against orange sky, graffiti walls, "
        "skateboard ramp in background, California coastal vibe, "
        "warm cinematic lighting, panoramic 360 degree view"
    ),
    "cyberpunk_gym": (
        "Futuristic cyberpunk training gym interior, neon lights in cyan and magenta, "
        "holographic displays showing player stats, dark moody atmosphere, "
        "chrome and glass surfaces, rain visible through windows, "
        "high tech aesthetic, panoramic 360 degree environment"
    ),
    "classic_nba_arena": (
        "Classic 1990s NBA basketball arena, wooden court with team logos, "
        "packed stadium crowd, overhead jumbotron, "
        "dramatic spotlight lighting, nostalgic retro sports aesthetic, "
        "panoramic 360 degree view from center court"
    ),
    "underground_bunker": (
        "Underground concrete training bunker, industrial lighting, "
        "heavy bags and speed bags, chalk dust in the air, "
        "military aesthetic with motivational graffiti, "
        "gritty atmosphere, panoramic 360 view"
    ),
    "rooftop_cityscape": (
        "Rooftop basketball court above a megacity skyline at dusk, "
        "skyscrapers with lit windows stretching to horizon, "
        "chain-link fence around court, helicopter in distance, "
        "dramatic clouds and city lights, panoramic 360 degree"
    ),
    "winter_outdoor": (
        "Outdoor basketball court in winter, light snow falling, "
        "frost on metal hoops, breath visible in cold air, "
        "bare trees and overcast sky, street lamps with warm glow, "
        "moody cinematic winter atmosphere, 360 panoramic"
    ),
    "beach_tropical": (
        "Tropical beach volleyball and basketball court on white sand, "
        "crystal clear turquoise water, palm trees swaying, "
        "bright sunny day with fluffy clouds, "
        "paradise island aesthetic, panoramic 360 degree"
    ),
    "warehouse_industrial": (
        "Converted warehouse gym space, exposed brick walls, "
        "industrial steel beams, concrete floors with painted lines, "
        "hanging cage lights, boxing ring in corner, "
        "raw urban fitness aesthetic, panoramic 360"
    ),
    "neon_arcade": (
        "Retro 80s neon arcade aesthetic sports court, "
        "glowing grid floor like Tron, synthwave color palette, "
        "purple and cyan neon tubes, pixel art decorations, "
        "vaporwave atmosphere, panoramic 360 degree environment"
    ),
    "zen_dojo": (
        "Traditional Japanese zen dojo training hall, "
        "tatami mats, wooden beams, paper screens with warm backlight, "
        "bonsai trees, calligraphy on walls, "
        "serene minimalist aesthetic, panoramic 360 view"
    ),
    "stadium_night_game": (
        "Professional soccer stadium during a night game, "
        "bright floodlights illuminating pristine green pitch, "
        "packed crowd with banners and flares, "
        "electric atmosphere, wide panoramic 360 degree"
    ),
}


def load_all_configs():
    """Load all generative model configurations."""
    return {
        "stability": StableVideoDiffusionConfig(),
        "runway": RunwayConfig(),
        "luma": LumaDreamMachineConfig(),
        "gaia": GaiaConfig(),
    }


def ensure_dirs():
    """Create output directories."""
    for d in [GENERATED_ROOT, CACHE_DIR, UE5_CONTENT]:
        d.mkdir(parents=True, exist_ok=True)
    return GENERATED_ROOT
