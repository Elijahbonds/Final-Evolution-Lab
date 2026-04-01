"""Asset manifest & caching — avoids re-generating assets that already exist.

The manifest is a JSON file mapping asset_key → generation metadata:
  {
    "squat_form_animation": {
      "service": "deepmotion",
      "task_id": "abc123",
      "status": "completed",
      "created_at": "2026-04-01T...",
      "files": ["GeneratedAssets/deepmotion/squat_form/mocap.fbx"],
      "params": { ... }
    }
  }
"""
from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

logger = logging.getLogger("asset_cache")


class AssetManifest:
    """Thread-safe-ish read/write of the JSON manifest file."""

    def __init__(self, manifest_path: Path) -> None:
        self.path = manifest_path
        self._data: dict[str, Any] = {}
        self._load()

    def _load(self) -> None:
        if self.path.is_file():
            try:
                self._data = json.loads(self.path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                logger.warning("Corrupt manifest %s — starting fresh", self.path)
                self._data = {}
        else:
            self._data = {}

    def _save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self._data, indent=2, default=str), encoding="utf-8")

    def has(self, key: str) -> bool:
        entry = self._data.get(key)
        if not entry:
            return False
        # Check files still exist
        for fp in entry.get("files", []):
            if not Path(fp).is_file():
                return False
        return entry.get("status") == "completed"

    def get(self, key: str) -> dict | None:
        return self._data.get(key)

    def set(
        self,
        key: str,
        *,
        service: str,
        task_id: str = "",
        status: str = "completed",
        files: list[str] | None = None,
        params: dict | None = None,
    ) -> None:
        self._data[key] = {
            "service": service,
            "task_id": task_id,
            "status": status,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "files": files or [],
            "params": params or {},
        }
        self._save()

    def remove(self, key: str) -> None:
        self._data.pop(key, None)
        self._save()

    def keys(self) -> list[str]:
        return list(self._data.keys())

    def summary(self) -> str:
        total = len(self._data)
        completed = sum(1 for v in self._data.values() if v.get("status") == "completed")
        return f"Manifest: {completed}/{total} assets completed"
