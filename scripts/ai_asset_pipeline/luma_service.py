#!/usr/bin/env python3
"""Luma AI — REST API service for image / video generation and 3D asset creation.

Supports:
  * Image generation (text-to-image via Photon model)
  * Video generation (text-to-video, image-to-video via Ray2)
  * Task polling & asset download

The generated images/videos feed the Meshy Image-to-3D pipeline or can be used
directly as environment textures and skyboxes.

Usage (CLI):
  python -m ai_asset_pipeline.luma_service generate_image \
      --prompt "Venice Beach basketball court at golden hour, wide angle" \
      --out ./GeneratedAssets/luma

  python -m ai_asset_pipeline.luma_service generate_video \
      --prompt "Basketball player doing a slam dunk, slow motion" \
      --out ./GeneratedAssets/luma
"""
from __future__ import annotations

import argparse
import json
import logging
import shutil
import sys
import time
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen
from urllib.error import HTTPError

from .config import LumaAIConfig

logger = logging.getLogger("luma_service")


class LumaAIService:
    """Wrapper around the Luma AI Dream Machine API."""

    def __init__(self, cfg: LumaAIConfig | None = None) -> None:
        self.cfg = cfg or LumaAIConfig()
        self.cfg.validate()

    # ------------------------------------------------------------------
    # HTTP helpers
    # ------------------------------------------------------------------

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def _request(self, method: str, path: str, body: dict | None = None) -> Any:
        url = f"{self.cfg.base_url}{path}"
        data = json.dumps(body).encode() if body else None
        req = Request(url, data=data, headers=self._headers(), method=method)
        try:
            with urlopen(req, timeout=60) as resp:
                return json.loads(resp.read().decode())
        except HTTPError as exc:
            err_body = exc.read().decode() if exc.fp else ""
            logger.error("Luma API %s %s → %s: %s", method, path, exc.code, err_body)
            raise

    # ------------------------------------------------------------------
    # Image generation  (Photon model)
    # ------------------------------------------------------------------

    def create_image_generation(self, prompt: str, **kwargs: Any) -> dict:
        """Create an image generation task. Returns the generation object."""
        body: dict[str, Any] = {
            "prompt": prompt,
        }
        if kwargs.get("aspect_ratio"):
            body["aspect_ratio"] = kwargs["aspect_ratio"]  # e.g. "16:9", "1:1"
        if kwargs.get("model"):
            body["model"] = kwargs["model"]  # default: photon-1
        if kwargs.get("style_reference"):
            body["image_ref"] = {"url": kwargs["style_reference"], "weight": kwargs.get("style_weight", 0.5)}
        if kwargs.get("character_reference"):
            body["character_ref"] = {"identity0": {"images": [kwargs["character_reference"]]}}
        resp = self._request("POST", "/generations/image", body)
        gen_id = resp.get("id", "")
        logger.info("Image generation created: %s", gen_id)
        return resp

    def get_image_generation(self, gen_id: str) -> dict:
        return self._request("GET", f"/generations/image/{gen_id}")

    # ------------------------------------------------------------------
    # Video generation  (Ray2 model)
    # ------------------------------------------------------------------

    def create_video_generation(self, prompt: str, **kwargs: Any) -> dict:
        """Create a video generation task."""
        body: dict[str, Any] = {
            "prompt": prompt,
        }
        if kwargs.get("aspect_ratio"):
            body["aspect_ratio"] = kwargs["aspect_ratio"]
        if kwargs.get("model"):
            body["model"] = kwargs["model"]  # ray2, ray1.6
        if kwargs.get("loop"):
            body["loop"] = True
        if kwargs.get("keyframes"):
            body["keyframes"] = kwargs["keyframes"]
        if kwargs.get("image_url"):
            body["keyframes"] = {"frame0": {"type": "image", "url": kwargs["image_url"]}}
        resp = self._request("POST", "/generations", body)
        gen_id = resp.get("id", "")
        logger.info("Video generation created: %s", gen_id)
        return resp

    def get_video_generation(self, gen_id: str) -> dict:
        return self._request("GET", f"/generations/{gen_id}")

    # ------------------------------------------------------------------
    # Polling + download
    # ------------------------------------------------------------------

    def poll_generation(self, gen_id: str, gen_type: str = "video") -> dict:
        """Block until generation reaches completed / failed."""
        endpoint = "/generations/image" if gen_type == "image" else "/generations"
        deadline = time.time() + self.cfg.max_poll_minutes * 60
        while time.time() < deadline:
            gen = self._request("GET", f"{endpoint}/{gen_id}")
            state = gen.get("state", gen.get("status", "unknown"))
            logger.info("  [%s] state=%s", gen_id[:12], state)
            if state == "completed":
                return gen
            if state in ("failed", "error"):
                raise RuntimeError(f"Luma generation {gen_id} failed: {gen.get('failure_reason', gen)}")
            time.sleep(self.cfg.poll_interval_seconds)
        raise TimeoutError(f"Luma generation {gen_id} did not finish in {self.cfg.max_poll_minutes} min")

    def download_asset(self, gen: dict, out_dir: Path, prefix: str = "") -> list[Path]:
        """Download assets from a completed generation into *out_dir*."""
        out_dir.mkdir(parents=True, exist_ok=True)
        downloaded: list[Path] = []
        gen_id = gen.get("id", "unknown")

        # Image generation result
        for img in gen.get("images", []):
            url = img if isinstance(img, str) else img.get("url", "")
            if url:
                ext = "png" if ".png" in url.lower() else "jpg"
                dest = out_dir / f"{prefix}{gen_id}.{ext}"
                logger.info("  Downloading image → %s", dest)
                req = Request(url)
                with urlopen(req, timeout=120) as resp, open(dest, "wb") as f:
                    shutil.copyfileobj(resp, f)
                downloaded.append(dest)

        # Video generation result
        assets = gen.get("assets", {})
        video_url = assets.get("video", "")
        if video_url:
            dest = out_dir / f"{prefix}{gen_id}.mp4"
            logger.info("  Downloading video → %s", dest)
            req = Request(video_url)
            with urlopen(req, timeout=300) as resp, open(dest, "wb") as f:
                shutil.copyfileobj(resp, f)
            downloaded.append(dest)

        # Thumbnail
        thumb = assets.get("thumbnail", gen.get("thumbnail", ""))
        if thumb:
            dest = out_dir / f"{prefix}{gen_id}_thumb.jpg"
            req = Request(thumb)
            with urlopen(req, timeout=30) as resp, open(dest, "wb") as f:
                shutil.copyfileobj(resp, f)
            downloaded.append(dest)

        return downloaded

    # ------------------------------------------------------------------
    # High-level helpers
    # ------------------------------------------------------------------

    def generate_image_full(self, prompt: str, out_dir: Path, **kwargs: Any) -> dict:
        """Create image → poll → download."""
        gen = self.create_image_generation(prompt, **kwargs)
        gen_id = gen.get("id", "")
        result = self.poll_generation(gen_id, gen_type="image")
        files = self.download_asset(result, out_dir, prefix="img_")
        logger.info("Image generation complete. Files: %s", [str(f) for f in files])
        return {"generation": result, "files": [str(f) for f in files]}

    def generate_video_full(self, prompt: str, out_dir: Path, **kwargs: Any) -> dict:
        """Create video → poll → download."""
        gen = self.create_video_generation(prompt, **kwargs)
        gen_id = gen.get("id", "")
        result = self.poll_generation(gen_id, gen_type="video")
        files = self.download_asset(result, out_dir, prefix="vid_")
        logger.info("Video generation complete. Files: %s", [str(f) for f in files])
        return {"generation": result, "files": [str(f) for f in files]}

    def generate_environment_reference(self, prompt: str, out_dir: Path) -> dict:
        """Generate a wide-angle environment image (16:9) suitable for Meshy Image-to-3D."""
        return self.generate_image_full(
            prompt,
            out_dir,
            aspect_ratio="16:9",
        )

    def generate_exercise_reference_video(self, prompt: str, out_dir: Path) -> dict:
        """Generate a reference video of an exercise for DeepMotion motion capture."""
        return self.generate_video_full(
            prompt,
            out_dir,
            aspect_ratio="9:16",  # portrait for exercise demos
        )


# ------------------------------------------------------------------
# CLI
# ------------------------------------------------------------------

def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s  %(message)s")
    p = argparse.ArgumentParser(description="Luma AI Dream Machine CLI")
    sub = p.add_subparsers(dest="cmd", required=True)

    gi = sub.add_parser("generate_image", help="Text-to-image")
    gi.add_argument("--prompt", required=True)
    gi.add_argument("--out", required=True, type=Path)
    gi.add_argument("--aspect-ratio", default="16:9")

    gv = sub.add_parser("generate_video", help="Text-to-video")
    gv.add_argument("--prompt", required=True)
    gv.add_argument("--out", required=True, type=Path)
    gv.add_argument("--aspect-ratio", default="16:9")

    env = sub.add_parser("environment", help="Generate environment reference image")
    env.add_argument("--prompt", required=True)
    env.add_argument("--out", required=True, type=Path)

    args = p.parse_args()
    svc = LumaAIService()

    if args.cmd == "generate_image":
        result = svc.generate_image_full(args.prompt, args.out, aspect_ratio=args.aspect_ratio)
        print(json.dumps(result["files"], indent=2))
    elif args.cmd == "generate_video":
        result = svc.generate_video_full(args.prompt, args.out, aspect_ratio=args.aspect_ratio)
        print(json.dumps(result["files"], indent=2))
    elif args.cmd == "environment":
        result = svc.generate_environment_reference(args.prompt, args.out)
        print(json.dumps(result["files"], indent=2))


if __name__ == "__main__":
    main()
