"""Unified API client for generative world models.

Supports multiple backends:
  - Stable Video Diffusion (Stability AI)
  - Runway Gen-3 Alpha
  - Luma Dream Machine (Ray2)
  - NVIDIA Gaia (future - pending public API)

The client abstracts the backend differences behind a common interface:
  generate(prompt, **kwargs) -> GenerationResult
"""

import json
import time
import urllib.request
import urllib.error
import urllib.parse
import hashlib
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional, Dict, Any, List
from enum import Enum

from .config import (
    StableVideoDiffusionConfig,
    RunwayConfig,
    LumaDreamMachineConfig,
    GaiaConfig,
    CACHE_DIR,
    GENERATED_ROOT,
    load_all_configs,
    ensure_dirs,
)


class Backend(Enum):
    STABILITY = "stability"
    RUNWAY = "runway"
    LUMA = "luma"
    GAIA = "gaia"


@dataclass
class GenerationResult:
    """Result from any generative world model."""
    prompt_id: str
    prompt: str
    backend: str
    task_id: str
    status: str  # 'pending' | 'processing' | 'completed' | 'failed'
    video_path: Optional[str] = None
    image_path: Optional[str] = None
    thumbnail_path: Optional[str] = None
    duration_seconds: float = 0.0
    resolution: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)
    error: Optional[str] = None


def _prompt_id(prompt: str) -> str:
    """Deterministic ID from prompt text."""
    h = hashlib.sha256(prompt.encode()).hexdigest()[:12]
    slug = prompt[:40].lower().replace(" ", "_").replace(",", "")
    slug = "".join(c for c in slug if c.isalnum() or c == "_")
    return f"{slug}_{h}"


def _http_request(url: str, data: Optional[bytes] = None,
                  headers: Optional[Dict] = None,
                  method: str = "GET") -> Dict:
    """Simple HTTP helper using urllib."""
    headers = headers or {}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = resp.read()
            try:
                return json.loads(body)
            except json.JSONDecodeError:
                return {"raw": body}
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        return {"error": True, "status_code": e.code, "message": error_body}
    except urllib.error.URLError as e:
        return {"error": True, "message": str(e)}


def _download_file(url: str, dest: Path) -> Path:
    """Download a file from URL to local path."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, str(dest))
    return dest


# ===========================================================================
# Stability AI - Stable Video Diffusion
# ===========================================================================
class StabilityClient:
    """Stable Video Diffusion / Stable Image via Stability AI API."""

    def __init__(self, config: Optional[StableVideoDiffusionConfig] = None):
        self.cfg = config or StableVideoDiffusionConfig()

    def generate_image(self, prompt: str, prompt_id: str,
                       width: int = 1024, height: int = 1024,
                       style_preset: str = "cinematic") -> GenerationResult:
        """Generate a base image via Stable Diffusion (text-to-image)."""
        url = f"{self.cfg.base_url}/stable-image/generate/sd3"
        boundary = "----FELBoundary"
        parts = []
        for k, v in [("prompt", prompt), ("output_format", "png"),
                     ("aspect_ratio", "16:9"), ("mode", "text-to-image")]:
            parts.append(
                f"--{boundary}\r\n"
                f"Content-Disposition: form-data; name=\"{k}\"\r\n\r\n"
                f"{v}\r\n"
            )
        parts.append(f"--{boundary}--\r\n")
        body = "".join(parts).encode("utf-8")
        headers = {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "application/json",
        }
        print(f"  [Stability] Generating image for prompt_id={prompt_id}")
        resp = _http_request(url, data=body, headers=headers, method="POST")
        if resp.get("error"):
            return GenerationResult(
                prompt_id=prompt_id, prompt=prompt, backend="stability",
                task_id="", status="failed", error=str(resp.get("message", "Unknown error"))
            )
        # Save image
        out_dir = GENERATED_ROOT / prompt_id
        out_dir.mkdir(parents=True, exist_ok=True)
        img_path = out_dir / "base_image.png"
        if "image" in resp:
            import base64
            img_data = base64.b64decode(resp["image"])
            img_path.write_bytes(img_data)
        return GenerationResult(
            prompt_id=prompt_id, prompt=prompt, backend="stability",
            task_id=resp.get("id", "local"), status="completed",
            image_path=str(img_path), resolution=f"{width}x{height}"
        )

    def image_to_video(self, image_path: str, prompt_id: str) -> GenerationResult:
        """Convert image to video via Stable Video Diffusion."""
        url = f"{self.cfg.base_url}/image-to-video"
        out_dir = GENERATED_ROOT / prompt_id
        out_dir.mkdir(parents=True, exist_ok=True)
        print(f"  [Stability] Image-to-Video for prompt_id={prompt_id}")
        # Build multipart for image upload
        with open(image_path, "rb") as f:
            img_bytes = f.read()
        boundary = "----FELBoundary"
        body = (
            f"--{boundary}\r\n"
            f"Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n"
            f"Content-Type: image/png\r\n\r\n"
        ).encode() + img_bytes + (
            f"\r\n--{boundary}\r\n"
            f"Content-Disposition: form-data; name=\"cfg_scale\"\r\n\r\n"
            f"{self.cfg.cfg_scale}\r\n"
            f"--{boundary}\r\n"
            f"Content-Disposition: form-data; name=\"motion_bucket_id\"\r\n\r\n"
            f"{self.cfg.motion_bucket_id}\r\n"
            f"--{boundary}--\r\n"
        ).encode()
        headers = {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        }
        resp = _http_request(url, data=body, headers=headers, method="POST")
        if resp.get("error"):
            return GenerationResult(
                prompt_id=prompt_id, prompt="", backend="stability",
                task_id="", status="failed", error=str(resp.get("message"))
            )
        task_id = resp.get("id", "")
        return GenerationResult(
            prompt_id=prompt_id, prompt="", backend="stability",
            task_id=task_id, status="processing",
            metadata={"generation_id": task_id}
        )


# ===========================================================================
# Runway Gen-3
# ===========================================================================
class RunwayClient:
    """Runway Gen-3 Alpha text/image-to-video."""

    def __init__(self, config: Optional[RunwayConfig] = None):
        self.cfg = config or RunwayConfig()

    def generate_video(self, prompt: str, prompt_id: str,
                       image_url: Optional[str] = None) -> GenerationResult:
        """Generate a video from text (and optional image reference)."""
        url = f"{self.cfg.base_url}/image_to_video"
        payload: Dict[str, Any] = {
            "model": self.cfg.model,
            "promptText": prompt,
            "duration": self.cfg.duration,
            "ratio": self.cfg.ratio,
            "watermark": self.cfg.watermark,
        }
        if image_url:
            payload["promptImage"] = image_url
        headers = {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "Content-Type": "application/json",
            "X-Runway-Version": "2024-11-06",
        }
        print(f"  [Runway] Generating video for prompt_id={prompt_id}")
        data = json.dumps(payload).encode()
        resp = _http_request(url, data=data, headers=headers, method="POST")
        if resp.get("error"):
            return GenerationResult(
                prompt_id=prompt_id, prompt=prompt, backend="runway",
                task_id="", status="failed", error=str(resp.get("message"))
            )
        task_id = resp.get("id", "")
        return GenerationResult(
            prompt_id=prompt_id, prompt=prompt, backend="runway",
            task_id=task_id, status="processing"
        )

    def poll_status(self, task_id: str, prompt_id: str,
                    max_wait: int = 600, interval: int = 10) -> GenerationResult:
        """Poll Runway task until completion."""
        url = f"{self.cfg.base_url}/tasks/{task_id}"
        headers = {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "X-Runway-Version": "2024-11-06",
        }
        elapsed = 0
        while elapsed < max_wait:
            resp = _http_request(url, headers=headers)
            status = resp.get("status", "UNKNOWN")
            if status == "SUCCEEDED":
                video_url = resp.get("output", [""])[0]
                out_dir = GENERATED_ROOT / prompt_id
                out_dir.mkdir(parents=True, exist_ok=True)
                vid_path = out_dir / "generated_video.mp4"
                if video_url:
                    _download_file(video_url, vid_path)
                return GenerationResult(
                    prompt_id=prompt_id, prompt="", backend="runway",
                    task_id=task_id, status="completed",
                    video_path=str(vid_path)
                )
            elif status == "FAILED":
                return GenerationResult(
                    prompt_id=prompt_id, prompt="", backend="runway",
                    task_id=task_id, status="failed",
                    error=resp.get("failure", "Unknown")
                )
            time.sleep(interval)
            elapsed += interval
        return GenerationResult(
            prompt_id=prompt_id, prompt="", backend="runway",
            task_id=task_id, status="failed", error="Timeout"
        )


# ===========================================================================
# Luma Dream Machine
# ===========================================================================
class LumaClient:
    """Luma AI Dream Machine video generation."""

    def __init__(self, config: Optional[LumaDreamMachineConfig] = None):
        self.cfg = config or LumaDreamMachineConfig()

    def generate_video(self, prompt: str, prompt_id: str,
                       loop: bool = True) -> GenerationResult:
        """Generate a looping video from text."""
        url = f"{self.cfg.base_url}/generations"
        payload = {
            "prompt": prompt,
            "model": self.cfg.model,
            "aspect_ratio": self.cfg.aspect_ratio,
            "loop": loop,
        }
        headers = {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        print(f"  [Luma] Generating video for prompt_id={prompt_id}")
        data = json.dumps(payload).encode()
        resp = _http_request(url, data=data, headers=headers, method="POST")
        if resp.get("error"):
            return GenerationResult(
                prompt_id=prompt_id, prompt=prompt, backend="luma",
                task_id="", status="failed", error=str(resp.get("message"))
            )
        task_id = resp.get("id", "")
        return GenerationResult(
            prompt_id=prompt_id, prompt=prompt, backend="luma",
            task_id=task_id, status="processing"
        )

    def poll_status(self, task_id: str, prompt_id: str,
                    max_wait: int = 600, interval: int = 10) -> GenerationResult:
        """Poll Luma generation until complete."""
        url = f"{self.cfg.base_url}/generations/{task_id}"
        headers = {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "Accept": "application/json",
        }
        elapsed = 0
        while elapsed < max_wait:
            resp = _http_request(url, headers=headers)
            state = resp.get("state", "unknown")
            if state == "completed":
                video_url = resp.get("assets", {}).get("video", "")
                out_dir = GENERATED_ROOT / prompt_id
                out_dir.mkdir(parents=True, exist_ok=True)
                vid_path = out_dir / "generated_video.mp4"
                if video_url:
                    _download_file(video_url, vid_path)
                return GenerationResult(
                    prompt_id=prompt_id, prompt="", backend="luma",
                    task_id=task_id, status="completed",
                    video_path=str(vid_path)
                )
            elif state == "failed":
                return GenerationResult(
                    prompt_id=prompt_id, prompt="", backend="luma",
                    task_id=task_id, status="failed",
                    error=resp.get("failure_reason", "Unknown")
                )
            time.sleep(interval)
            elapsed += interval
        return GenerationResult(
            prompt_id=prompt_id, prompt="", backend="luma",
            task_id=task_id, status="failed", error="Timeout"
        )


# ===========================================================================
# NVIDIA Gaia (future)
# ===========================================================================
class GaiaClient:
    """NVIDIA Gaia world model client (placeholder for future public API).

    Gaia generates interactive 3D world videos from text/image prompts.
    When the public API becomes available, this client will support:
      - Text-to-world video generation
      - Interactive camera control
      - Physics-aware environment synthesis
    """

    def __init__(self, config: Optional[GaiaConfig] = None):
        self.cfg = config or GaiaConfig()
        self._available = False

    def is_available(self) -> bool:
        """Check if Gaia API is accessible."""
        if not self.cfg.validate():
            return False
        resp = _http_request(
            f"{self.cfg.base_url}/health",
            headers={"Authorization": f"Bearer {self.cfg.api_key}"}
        )
        self._available = not resp.get("error", False)
        return self._available

    def generate_world(self, prompt: str, prompt_id: str) -> GenerationResult:
        """Generate world video via Gaia (when available)."""
        if not self._available:
            return GenerationResult(
                prompt_id=prompt_id, prompt=prompt, backend="gaia",
                task_id="", status="failed",
                error="Gaia API not yet publicly available. "
                      "Using fallback backends (Luma/Runway/Stability)."
            )
        url = f"{self.cfg.base_url}/generate"
        payload = {
            "prompt": prompt,
            "model": self.cfg.model,
            "world_size": self.cfg.world_size,
            "output_format": self.cfg.output_format,
        }
        headers = {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "Content-Type": "application/json",
        }
        data = json.dumps(payload).encode()
        resp = _http_request(url, data=data, headers=headers, method="POST")
        task_id = resp.get("id", "")
        return GenerationResult(
            prompt_id=prompt_id, prompt=prompt, backend="gaia",
            task_id=task_id, status="processing"
        )


# ===========================================================================
# Unified client facade
# ===========================================================================
class GenerativeWorldModelClient:
    """Unified facade for all generative world model backends.

    Tries backends in priority order:
      1. Gaia (if available)
      2. Luma Dream Machine
      3. Runway Gen-3
      4. Stability AI

    Falls back automatically if a backend is unavailable.
    """

    BACKEND_PRIORITY = [Backend.GAIA, Backend.LUMA, Backend.RUNWAY, Backend.STABILITY]

    def __init__(self, preferred_backend: Optional[Backend] = None):
        configs = load_all_configs()
        self.stability = StabilityClient(configs["stability"])
        self.runway = RunwayClient(configs["runway"])
        self.luma = LumaClient(configs["luma"])
        self.gaia = GaiaClient(configs["gaia"])
        self.preferred = preferred_backend
        ensure_dirs()

    def _select_backend(self) -> Backend:
        """Select best available backend."""
        if self.preferred:
            return self.preferred
        # Try Gaia first
        if self.gaia.is_available():
            return Backend.GAIA
        # Check API keys
        configs = load_all_configs()
        if configs["luma"].validate():
            return Backend.LUMA
        if configs["runway"].validate():
            return Backend.RUNWAY
        if configs["stability"].validate():
            return Backend.STABILITY
        # Default fallback
        return Backend.LUMA

    def generate(self, prompt: str, prompt_key: Optional[str] = None,
                 loop: bool = True) -> GenerationResult:
        """Generate environment video/image from text prompt.

        Args:
            prompt: Text description of the environment.
            prompt_key: Optional human-readable key (e.g. 'retro_tokyo_night').
            loop: Whether the video should loop seamlessly.

        Returns:
            GenerationResult with paths to generated assets.
        """
        pid = prompt_key or _prompt_id(prompt)
        backend = self._select_backend()
        print(f"[GWM] Using backend: {backend.value} for prompt_id={pid}")

        if backend == Backend.GAIA:
            return self.gaia.generate_world(prompt, pid)
        elif backend == Backend.LUMA:
            return self.luma.generate_video(prompt, pid, loop=loop)
        elif backend == Backend.RUNWAY:
            return self.runway.generate_video(prompt, pid)
        elif backend == Backend.STABILITY:
            result = self.stability.generate_image(prompt, pid)
            if result.status == "completed" and result.image_path:
                vid_result = self.stability.image_to_video(result.image_path, pid)
                vid_result.image_path = result.image_path
                return vid_result
            return result
        else:
            return GenerationResult(
                prompt_id=pid, prompt=prompt, backend="none",
                task_id="", status="failed",
                error="No backend available"
            )

    def generate_batch(self, prompts: Dict[str, str],
                       loop: bool = True) -> Dict[str, GenerationResult]:
        """Generate multiple environments."""
        results = {}
        for key, prompt in prompts.items():
            print(f"\n{'='*60}")
            print(f"Generating: {key}")
            print(f"{'='*60}")
            results[key] = self.generate(prompt, prompt_key=key, loop=loop)
        return results


# ===========================================================================
# CLI
# ===========================================================================
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Generative World Model Client")
    parser.add_argument("--prompt", type=str, help="Text prompt")
    parser.add_argument("--key", type=str, help="Prompt key from presets")
    parser.add_argument("--backend", type=str, choices=["stability", "runway", "luma", "gaia"])
    parser.add_argument("--list-presets", action="store_true")
    args = parser.parse_args()

    from .config import ENVIRONMENT_PROMPTS

    if args.list_presets:
        for k, v in ENVIRONMENT_PROMPTS.items():
            print(f"  {k}: {v[:80]}...")
    else:
        backend = Backend(args.backend) if args.backend else None
        client = GenerativeWorldModelClient(preferred_backend=backend)
        prompt = args.prompt or ENVIRONMENT_PROMPTS.get(args.key, "")
        if not prompt:
            print("Provide --prompt or --key")
        else:
            result = client.generate(prompt, prompt_key=args.key)
            print(f"Result: {result}")
