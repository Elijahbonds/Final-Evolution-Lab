"""Centralised configuration for all AI asset-generation APIs.

API keys are loaded from environment variables (never hard-coded).
Optional: ``python-dotenv`` reads from ``.env`` at repo root.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]  # repo root

# Try loading .env automatically
try:
    from dotenv import load_dotenv
    load_dotenv(ROOT_DIR / ".env")
except ImportError:
    pass


@dataclass
class DeepMotionConfig:
    client_id: str = field(default_factory=lambda: os.environ.get("DEEPMOTION_CLIENT_ID", ""))
    client_secret: str = field(default_factory=lambda: os.environ.get("DEEPMOTION_CLIENT_SECRET", ""))
    api_server_url: str = field(default_factory=lambda: os.environ.get("DEEPMOTION_API_SERVER_URL", "https://service.deepmotion.com"))

    def validate(self) -> None:
        if not self.client_id or not self.client_secret:
            raise EnvironmentError(
                "Missing DEEPMOTION_CLIENT_ID / DEEPMOTION_CLIENT_SECRET. "
                "See scripts/deepmotion_animate3d.env.example"
            )


@dataclass
class MeshyConfig:
    api_key: str = field(default_factory=lambda: os.environ.get("MESHY_API_KEY", ""))
    base_url: str = "https://api.meshy.ai"
    default_ai_model: str = "latest"  # meshy-6 alias
    default_topology: str = "triangle"
    default_target_polycount: int = 30000
    default_target_formats: list[str] = field(default_factory=lambda: ["glb", "fbx"])
    poll_interval_seconds: float = 5.0
    max_poll_minutes: float = 30.0

    def validate(self) -> None:
        if not self.api_key:
            raise EnvironmentError(
                "Missing MESHY_API_KEY. Obtain from https://www.meshy.ai/api "
                "and set the environment variable."
            )


@dataclass
class LumaAIConfig:
    api_key: str = field(default_factory=lambda: os.environ.get("LUMA_API_KEY", ""))
    base_url: str = "https://api.lumalabs.ai/dream-machine/v1"
    poll_interval_seconds: float = 5.0
    max_poll_minutes: float = 30.0

    def validate(self) -> None:
        if not self.api_key:
            raise EnvironmentError(
                "Missing LUMA_API_KEY. Obtain from https://lumalabs.ai/dream-machine/api "
                "and set the environment variable."
            )


@dataclass
class PipelineConfig:
    """Paths and common settings shared across services."""
    output_root: Path = field(default_factory=lambda: ROOT_DIR / "GeneratedAssets")
    cache_dir: Path = field(default_factory=lambda: ROOT_DIR / "GeneratedAssets" / ".cache")
    unreal_content_dir: Path = field(
        default_factory=lambda: ROOT_DIR / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Generated"
    )
    exercise_catalog_path: Path = field(
        default_factory=lambda: ROOT_DIR / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ExerciseCatalog.json"
    )
    manifest_path: Path = field(default_factory=lambda: ROOT_DIR / "GeneratedAssets" / "asset_manifest.json")

    def ensure_dirs(self) -> None:
        self.output_root.mkdir(parents=True, exist_ok=True)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.unreal_content_dir.mkdir(parents=True, exist_ok=True)
        (self.output_root / "deepmotion").mkdir(exist_ok=True)
        (self.output_root / "meshy").mkdir(exist_ok=True)
        (self.output_root / "luma").mkdir(exist_ok=True)


def load_all_configs() -> tuple[DeepMotionConfig, MeshyConfig, LumaAIConfig, PipelineConfig]:
    return DeepMotionConfig(), MeshyConfig(), LumaAIConfig(), PipelineConfig()
