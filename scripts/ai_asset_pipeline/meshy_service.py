#!/usr/bin/env python3
"""Meshy AI — REST API service for 3D model generation.

Supports:
  * Text-to-3D  (preview + refine)
  * Image-to-3D
  * Task polling & asset download

Usage (CLI):
  python -m ai_asset_pipeline.meshy_service text2mesh \
      --prompt "Venice Beach basketball court, photorealistic" \
      --out ./GeneratedAssets/meshy

  python -m ai_asset_pipeline.meshy_service img2mesh \
      --image-url "https://images.pexels.com/photos/18460191/pexels-photo-18460191/free-photo-of-basketball-field-during-sunset.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500" \
      --out ./GeneratedAssets/meshy
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

from .config import MeshyConfig, PipelineConfig

logger = logging.getLogger("meshy_service")


class MeshyService:
    """Thin wrapper around Meshy REST API."""

    def __init__(self, cfg: MeshyConfig | None = None) -> None:
        self.cfg = cfg or MeshyConfig()
        self.cfg.validate()

    # ------------------------------------------------------------------
    # Low-level HTTP helpers
    # ------------------------------------------------------------------

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.cfg.api_key}",
            "Content-Type": "application/json",
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
            logger.error("Meshy API %s %s → %s: %s", method, path, exc.code, err_body)
            raise

    # ------------------------------------------------------------------
    # Text-to-3D
    # ------------------------------------------------------------------

    def create_text_to_3d_preview(self, prompt: str, **kwargs: Any) -> str:
        """Create a Text-to-3D *preview* task. Returns task id."""
        body: dict[str, Any] = {
            "mode": "preview",
            "prompt": prompt,
            "ai_model": kwargs.get("ai_model", self.cfg.default_ai_model),
            "topology": kwargs.get("topology", self.cfg.default_topology),
            "target_polycount": kwargs.get("target_polycount", self.cfg.default_target_polycount),
            "target_formats": kwargs.get("target_formats", self.cfg.default_target_formats),
        }
        if kwargs.get("symmetry_mode"):
            body["symmetry_mode"] = kwargs["symmetry_mode"]
        resp = self._request("POST", "/openapi/v2/text-to-3d", body)
        task_id = resp.get("result", resp.get("id", ""))
        logger.info("Text-to-3D preview created: %s", task_id)
        return task_id

    def create_text_to_3d_refine(self, preview_task_id: str, enable_pbr: bool = True) -> str:
        """Create a Text-to-3D *refine* task from a completed preview."""
        body = {
            "mode": "refine",
            "preview_task_id": preview_task_id,
            "enable_pbr": enable_pbr,
        }
        resp = self._request("POST", "/openapi/v2/text-to-3d", body)
        task_id = resp.get("result", resp.get("id", ""))
        logger.info("Text-to-3D refine created: %s (from preview %s)", task_id, preview_task_id)
        return task_id

    def get_text_to_3d_task(self, task_id: str) -> dict:
        return self._request("GET", f"/openapi/v2/text-to-3d/{task_id}")

    # ------------------------------------------------------------------
    # Image-to-3D
    # ------------------------------------------------------------------

    def create_image_to_3d(self, image_url: str, **kwargs: Any) -> str:
        """Create an Image-to-3D task. Returns task id."""
        body: dict[str, Any] = {
            "image_url": image_url,
            "ai_model": kwargs.get("ai_model", self.cfg.default_ai_model),
            "topology": kwargs.get("topology", self.cfg.default_topology),
            "target_polycount": kwargs.get("target_polycount", self.cfg.default_target_polycount),
            "target_formats": kwargs.get("target_formats", self.cfg.default_target_formats),
            "should_texture": kwargs.get("should_texture", True),
            "enable_pbr": kwargs.get("enable_pbr", True),
        }
        if kwargs.get("texture_prompt"):
            body["texture_prompt"] = kwargs["texture_prompt"]
        resp = self._request("POST", "/openapi/v1/image-to-3d", body)
        task_id = resp.get("result", resp.get("id", ""))
        logger.info("Image-to-3D created: %s", task_id)
        return task_id

    def get_image_to_3d_task(self, task_id: str) -> dict:
        return self._request("GET", f"/openapi/v1/image-to-3d/{task_id}")

    # ------------------------------------------------------------------
    # Polling + download
    # ------------------------------------------------------------------

    def poll_task(self, task_id: str, endpoint: str = "text-to-3d", api_version: str = "v2") -> dict:
        """Block until task reaches SUCCEEDED / FAILED."""
        deadline = time.time() + self.cfg.max_poll_minutes * 60
        while time.time() < deadline:
            task = self._request("GET", f"/openapi/{api_version}/{endpoint}/{task_id}")
            status = task.get("status", "UNKNOWN")
            progress = task.get("progress", 0)
            logger.info("  [%s] status=%s progress=%d%%", task_id[:12], status, progress)
            if status == "SUCCEEDED":
                return task
            if status in ("FAILED", "CANCELED"):
                raise RuntimeError(f"Meshy task {task_id} {status}: {task.get('task_error', {})}")
            time.sleep(self.cfg.poll_interval_seconds)
        raise TimeoutError(f"Meshy task {task_id} did not finish in {self.cfg.max_poll_minutes} min")

    def download_model(self, task: dict, out_dir: Path) -> list[Path]:
        """Download model files from a SUCCEEDED task into *out_dir*."""
        out_dir.mkdir(parents=True, exist_ok=True)
        downloaded: list[Path] = []
        model_urls: dict = task.get("model_urls", {})
        task_id = task.get("id", "unknown")
        for fmt, url in model_urls.items():
            if not url:
                continue
            dest = out_dir / f"{task_id}.{fmt}"
            logger.info("  Downloading %s → %s", fmt, dest)
            req = Request(url)
            with urlopen(req, timeout=120) as resp, open(dest, "wb") as f:
                shutil.copyfileobj(resp, f)
            downloaded.append(dest)
        # Thumbnail
        thumb_url = task.get("thumbnail_url", "")
        if thumb_url:
            dest = out_dir / f"{task_id}_thumb.png"
            req = Request(thumb_url)
            with urlopen(req, timeout=30) as resp, open(dest, "wb") as f:
                shutil.copyfileobj(resp, f)
            downloaded.append(dest)
        return downloaded

    # ------------------------------------------------------------------
    # High-level helpers
    # ------------------------------------------------------------------

    def text_to_3d_full(self, prompt: str, out_dir: Path, enable_pbr: bool = True, **kwargs: Any) -> dict:
        """Run Text-to-3D end-to-end: preview → poll → refine → poll → download."""
        preview_id = self.create_text_to_3d_preview(prompt, **kwargs)
        logger.info("Polling preview %s …", preview_id)
        self.poll_task(preview_id, endpoint="text-to-3d", api_version="v2")

        refine_id = self.create_text_to_3d_refine(preview_id, enable_pbr=enable_pbr)
        logger.info("Polling refine %s …", refine_id)
        task = self.poll_task(refine_id, endpoint="text-to-3d", api_version="v2")

        files = self.download_model(task, out_dir)
        logger.info("Text-to-3D complete. Files: %s", [str(f) for f in files])
        return {"task": task, "files": [str(f) for f in files]}

    def image_to_3d_full(self, image_url: str, out_dir: Path, **kwargs: Any) -> dict:
        """Run Image-to-3D end-to-end: create → poll → download."""
        task_id = self.create_image_to_3d(image_url, **kwargs)
        logger.info("Polling Image-to-3D %s …", task_id)
        task = self.poll_task(task_id, endpoint="image-to-3d", api_version="v1")
        files = self.download_model(task, out_dir)
        logger.info("Image-to-3D complete. Files: %s", [str(f) for f in files])
        return {"task": task, "files": [str(f) for f in files]}

    def get_balance(self) -> dict:
        return self._request("GET", "/openapi/v1/balance")


# ------------------------------------------------------------------
# CLI
# ------------------------------------------------------------------

def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s  %(message)s")
    p = argparse.ArgumentParser(description="Meshy AI 3D generation CLI")
    sub = p.add_subparsers(dest="cmd", required=True)

    t = sub.add_parser("text2mesh", help="Text-to-3D (preview + refine)")
    t.add_argument("--prompt", required=True)
    t.add_argument("--out", required=True, type=Path)
    t.add_argument("--no-pbr", action="store_true")

    i = sub.add_parser("img2mesh", help="Image-to-3D")
    i.add_argument("--image-url", required=True)
    i.add_argument("--out", required=True, type=Path)

    sub.add_parser("balance", help="Print credit balance")

    args = p.parse_args()
    svc = MeshyService()

    if args.cmd == "text2mesh":
        result = svc.text_to_3d_full(args.prompt, args.out, enable_pbr=not args.no_pbr)
        print(json.dumps(result["files"], indent=2))
    elif args.cmd == "img2mesh":
        result = svc.image_to_3d_full(args.image_url, args.out)
        print(json.dumps(result["files"], indent=2))
    elif args.cmd == "balance":
        print(json.dumps(svc.get_balance(), indent=2))


if __name__ == "__main__":
    main()
