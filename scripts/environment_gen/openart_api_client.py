"""
OpenArt.ai API Client for World Asset Generation.

Provides a unified interface for OpenArt.ai's generative capabilities:
- World/environment generation
- Scene enhancement (props, details, atmosphere)
- Texture/material generation (PBR sets)
- Skybox variations

Falls back to high-quality procedural generation when the API is
unavailable (OpenArt.ai does not yet expose a public REST API).

The procedural fallback uses Pillow + NumPy to create production-grade
PBR textures, atmospheric overlays, prop silhouettes, and skybox
variations tuned to each environment's colour palette.
"""

import os
import json
import hashlib
import urllib.request
import urllib.error
import time
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, Dict, List, Any, Tuple
from enum import Enum

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
except ImportError:
    pass

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

@dataclass
class OpenArtConfig:
    """OpenArt.ai API configuration."""
    api_key: str = field(default_factory=lambda: os.getenv("OPENART_API_KEY", ""))
    base_url: str = "https://openart.ai/api/v1"
    # When public API launches these will be the expected endpoints
    generate_endpoint: str = "/generations"
    enhance_endpoint: str = "/enhance"
    texture_endpoint: str = "/textures"
    workflow_endpoint: str = "/workflows"
    # Generation parameters
    default_width: int = 1024
    default_height: int = 1024
    default_steps: int = 30
    default_cfg_scale: float = 7.5
    default_model: str = "sdxl"  # Expected model identifier
    max_retries: int = 3
    poll_interval: int = 5
    timeout: int = 300  # 5 minutes

    def validate(self) -> bool:
        if not self.api_key:
            print("[INFO] OPENART_API_KEY not set — using procedural fallback")
            return False
        return True


class AssetType(Enum):
    PROP = "prop"
    TEXTURE = "texture"
    MATERIAL = "material"
    ATMOSPHERE = "atmosphere"
    SKYBOX = "skybox"
    DETAIL = "detail"
    DECAL = "decal"


class TextureMapType(Enum):
    ALBEDO = "albedo"
    NORMAL = "normal"
    ROUGHNESS = "roughness"
    METALLIC = "metallic"
    AO = "ao"
    HEIGHT = "height"
    EMISSIVE = "emissive"


# ---------------------------------------------------------------------------
# OpenArt API Client
# ---------------------------------------------------------------------------

class OpenArtAPIClient:
    """
    Client for OpenArt.ai generative asset creation.

    When ``api_key`` is set and the API is reachable the client calls the
    OpenArt REST endpoints.  Otherwise it seamlessly falls back to the
    built-in ``ProceduralAssetGenerator`` which produces tileable PBR
    textures, atmospheric overlays, prop cards, and skybox variants using
    pure Python (Pillow + NumPy).
    """

    def __init__(self, config: Optional[OpenArtConfig] = None):
        self.config = config or OpenArtConfig()
        self.api_available = self.config.validate() and self._check_api()
        self._session_headers = {
            "Authorization": f"Bearer {self.config.api_key}",
            "Content-Type": "application/json",
            "User-Agent": "FinalEvolutionLab/1.0",
        }

    # ------------------------------------------------------------------
    # API connectivity
    # ------------------------------------------------------------------

    def _check_api(self) -> bool:
        """Probe the OpenArt API for availability."""
        if not self.config.api_key:
            return False
        try:
            req = urllib.request.Request(
                f"{self.config.base_url}/health",
                headers=self._session_headers,
                method="GET",
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                return resp.status == 200
        except Exception:
            print("[INFO] OpenArt API not reachable — procedural fallback active")
            return False

    # ------------------------------------------------------------------
    # Public generation methods
    # ------------------------------------------------------------------

    def generate_world_asset(
        self,
        prompt: str,
        asset_type: AssetType,
        output_path: Path,
        width: int = 0,
        height: int = 0,
        extra_params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Generate a single world asset (texture, prop card, etc.).

        Returns a dict with ``status``, ``file_path``, ``asset_type``,
        and ``metadata``.
        """
        width = width or self.config.default_width
        height = height or self.config.default_height
        output_path.parent.mkdir(parents=True, exist_ok=True)

        if self.api_available:
            return self._api_generate(prompt, asset_type, output_path, width, height, extra_params)
        return self._procedural_generate(prompt, asset_type, output_path, width, height, extra_params)

    def generate_pbr_material_set(
        self,
        prompt: str,
        output_dir: Path,
        resolution: int = 1024,
        maps: Optional[List[TextureMapType]] = None,
    ) -> Dict[str, Any]:
        """
        Generate a complete PBR material set (albedo, normal, roughness, metallic, AO).
        """
        maps = maps or [
            TextureMapType.ALBEDO,
            TextureMapType.NORMAL,
            TextureMapType.ROUGHNESS,
            TextureMapType.METALLIC,
            TextureMapType.AO,
        ]
        output_dir.mkdir(parents=True, exist_ok=True)
        results = {}
        for map_type in maps:
            file_path = output_dir / f"{map_type.value}.png"
            result = self.generate_world_asset(
                prompt=f"{prompt}, {map_type.value} map, PBR material, tileable seamless",
                asset_type=AssetType.MATERIAL,
                output_path=file_path,
                width=resolution,
                height=resolution,
                extra_params={"map_type": map_type.value},
            )
            results[map_type.value] = result
        return {"status": "completed", "maps": results, "output_dir": str(output_dir)}

    def generate_skybox_variation(
        self,
        prompt: str,
        output_path: Path,
        width: int = 2048,
        height: int = 1024,
    ) -> Dict[str, Any]:
        """Generate an equirectangular skybox variation."""
        return self.generate_world_asset(
            prompt=f"{prompt}, equirectangular panoramic HDR skybox, seamless 360 degree",
            asset_type=AssetType.SKYBOX,
            output_path=output_path,
            width=width,
            height=height,
        )

    def generate_atmosphere_overlay(
        self,
        prompt: str,
        output_path: Path,
        width: int = 1024,
        height: int = 1024,
    ) -> Dict[str, Any]:
        """Generate atmospheric overlay (fog, particles, light rays)."""
        return self.generate_world_asset(
            prompt=f"{prompt}, atmospheric overlay effect, transparent background, VFX",
            asset_type=AssetType.ATMOSPHERE,
            output_path=output_path,
            width=width,
            height=height,
            extra_params={"transparent": True},
        )

    # ------------------------------------------------------------------
    # API-based generation (when OpenArt API is available)
    # ------------------------------------------------------------------

    def _api_generate(
        self,
        prompt: str,
        asset_type: AssetType,
        output_path: Path,
        width: int,
        height: int,
        extra_params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Submit generation request to OpenArt API."""
        payload = {
            "prompt": prompt,
            "negative_prompt": "blurry, low quality, watermark, text, logo",
            "width": width,
            "height": height,
            "steps": self.config.default_steps,
            "cfg_scale": self.config.default_cfg_scale,
            "model": self.config.default_model,
            "asset_type": asset_type.value,
            **(extra_params or {}),
        }
        data = json.dumps(payload).encode()
        req = urllib.request.Request(
            f"{self.config.base_url}{self.config.generate_endpoint}",
            data=data,
            headers=self._session_headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self.config.timeout) as resp:
                result = json.loads(resp.read().decode())
            task_id = result.get("id") or result.get("task_id")
            if task_id:
                return self._poll_and_download(task_id, output_path, asset_type)
            # Direct URL response
            image_url = result.get("url") or result.get("output", {}).get("url")
            if image_url:
                self._download_file(image_url, output_path)
                return {"status": "completed", "file_path": str(output_path), "asset_type": asset_type.value}
        except Exception as e:
            print(f"[WARN] OpenArt API error: {e} — falling back to procedural")
            return self._procedural_generate(prompt, asset_type, output_path, width, height, extra_params)
        return {"status": "error", "message": "Unknown API response format"}

    def _poll_and_download(self, task_id: str, output_path: Path, asset_type: AssetType) -> Dict[str, Any]:
        """Poll task status and download when complete."""
        elapsed = 0
        while elapsed < self.config.timeout:
            try:
                req = urllib.request.Request(
                    f"{self.config.base_url}{self.config.generate_endpoint}/{task_id}",
                    headers=self._session_headers,
                    method="GET",
                )
                with urllib.request.urlopen(req, timeout=30) as resp:
                    result = json.loads(resp.read().decode())
                status = result.get("status", "").lower()
                if status in ("completed", "succeeded", "done"):
                    url = result.get("url") or result.get("output", {}).get("url")
                    if url:
                        self._download_file(url, output_path)
                        return {"status": "completed", "file_path": str(output_path), "asset_type": asset_type.value, "task_id": task_id}
                elif status in ("failed", "error"):
                    return {"status": "error", "message": result.get("error", "Generation failed"), "task_id": task_id}
            except Exception:
                pass
            time.sleep(self.config.poll_interval)
            elapsed += self.config.poll_interval
        return {"status": "timeout", "task_id": task_id}

    def _download_file(self, url: str, path: Path):
        req = urllib.request.Request(url, headers={"User-Agent": "FinalEvolutionLab/1.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            path.write_bytes(resp.read())

    # ------------------------------------------------------------------
    # Procedural fallback
    # ------------------------------------------------------------------

    def _procedural_generate(
        self,
        prompt: str,
        asset_type: AssetType,
        output_path: Path,
        width: int,
        height: int,
        extra_params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Delegate to ProceduralAssetGenerator."""
        from .procedural_asset_generator import ProceduralAssetGenerator
        gen = ProceduralAssetGenerator()
        return gen.generate(prompt, asset_type, output_path, width, height, extra_params)
