#!/usr/bin/env python3
"""DeepMotion — wrapper bridging the existing pipeline scripts into the unified service API.

This module re-exports the existing DeepMotion Animate 3D pipeline
(scripts/deepmotion_animate3d_pipeline.py) and adds convenience methods
that match the MeshyService / LumaAIService interface.

Usage:
  from ai_asset_pipeline.deepmotion_service import DeepMotionService
  svc = DeepMotionService()
  result = svc.process_video("clip.mp4", out_dir=Path("./out"), formats=["fbx","bvh"])
"""
from __future__ import annotations

import json
import logging
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from .config import DeepMotionConfig, ROOT_DIR

logger = logging.getLogger("deepmotion_service")

PIPELINE_SCRIPT = ROOT_DIR / "scripts" / "deepmotion_animate3d_pipeline.py"


class DeepMotionService:
    """Unified wrapper for the existing DeepMotion Animate 3D pipeline."""

    def __init__(self, cfg: DeepMotionConfig | None = None) -> None:
        self.cfg = cfg or DeepMotionConfig()
        self.cfg.validate()

    def _env(self) -> dict[str, str]:
        env = os.environ.copy()
        env["DEEPMOTION_CLIENT_ID"] = self.cfg.client_id
        env["DEEPMOTION_CLIENT_SECRET"] = self.cfg.client_secret
        env["DEEPMOTION_API_SERVER_URL"] = self.cfg.api_server_url
        return env

    def _run_pipeline(self, args: list[str]) -> int:
        cmd = [sys.executable, str(PIPELINE_SCRIPT)] + args
        logger.info("Running: %s", " ".join(cmd))
        return subprocess.call(cmd, cwd=str(ROOT_DIR), env=self._env())

    def get_balance(self) -> str:
        """Print the current API credit balance."""
        import io
        from contextlib import redirect_stdout
        buf = io.StringIO()
        cmd = [sys.executable, str(PIPELINE_SCRIPT), "balance"]
        result = subprocess.run(cmd, cwd=str(ROOT_DIR), env=self._env(),
                                capture_output=True, text=True, timeout=30)
        return result.stdout.strip()

    def process_video(
        self,
        video_path: str | Path,
        out_dir: str | Path,
        model_id: str = "",
        formats: list[str] | None = None,
        track_face: bool = True,
        track_hand: bool = True,
    ) -> dict[str, Any]:
        """Run single-person motion capture on a video file."""
        video_path = Path(video_path).resolve()
        out_dir = Path(out_dir).resolve()
        out_dir.mkdir(parents=True, exist_ok=True)

        args = ["single", "--video", str(video_path), "--out", str(out_dir)]
        if model_id:
            args.extend(["--model-id", model_id])
        fmts = ",".join(formats or ["fbx", "bvh"])
        args.extend(["--formats", fmts])
        args.extend(["--track-face", str(int(track_face))])
        args.extend(["--track-hand", str(int(track_hand))])

        rc = self._run_pipeline(args)
        files = [str(f) for f in out_dir.iterdir() if f.is_file()]
        return {"return_code": rc, "output_dir": str(out_dir), "files": files}

    def process_video_multiperson(
        self,
        video_path: str | Path,
        out_dir: str | Path,
        model_ids: list[str] | None = None,
        formats: list[str] | None = None,
    ) -> dict[str, Any]:
        """Run multi-person motion capture."""
        video_path = Path(video_path).resolve()
        out_dir = Path(out_dir).resolve()
        out_dir.mkdir(parents=True, exist_ok=True)

        args = ["multiperson", "--video", str(video_path), "--out", str(out_dir)]
        if model_ids:
            args.extend(["--models", ",".join(model_ids)])
        fmts = ",".join(formats or ["fbx", "bvh"])
        args.extend(["--formats", fmts])

        rc = self._run_pipeline(args)
        files = [str(f) for f in out_dir.iterdir() if f.is_file()]
        return {"return_code": rc, "output_dir": str(out_dir), "files": files}
