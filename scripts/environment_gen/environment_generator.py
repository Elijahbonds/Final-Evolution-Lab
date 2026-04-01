"""Environment Generator - Orchestration script for text-to-environment pipeline.

Full pipeline:
  1. Accept text prompt (or prompt key from presets)
  2. Check cache for existing generation
  3. Send to generative world model API
  4. Poll for completion
  5. Convert output to skybox/cubemap/video texture
  6. Register in environment manifest
  7. Prepare UE5 import data

Usage:
  python -m scripts.environment_gen.environment_generator --prompt-key retro_tokyo_night
  python -m scripts.environment_gen.environment_generator --all
  python -m scripts.environment_gen.environment_generator --prompt "My custom environment..."
"""

import json
import time
import os
import sys
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, field, asdict

from .config import (
    ENVIRONMENT_PROMPTS, GENERATED_ROOT, MANIFEST_PATH,
    UE5_CONTENT, QUALITY_PRESETS, ensure_dirs,
)
from .gaia_api_client import GenerativeWorldModelClient, GenerationResult, Backend
from .skybox_converter import SkyboxConverter, SkyboxOutput


@dataclass
class EnvironmentEntry:
    """Manifest entry for a generated environment."""
    prompt_id: str
    prompt_key: str
    prompt_text: str
    backend_used: str
    status: str  # 'generating' | 'converting' | 'ready' | 'failed'
    created_at: str = ""
    generation_task_id: str = ""
    # Paths
    source_image: Optional[str] = None
    source_video: Optional[str] = None
    equirect_path: Optional[str] = None
    cubemap_dir: Optional[str] = None
    hdr_path: Optional[str] = None
    video_texture_path: Optional[str] = None
    thumbnail_path: Optional[str] = None
    parallax_layers: List[str] = field(default_factory=list)
    # UE5
    ue5_content_path: str = ""
    ue5_material_path: str = ""
    # Quality
    quality_preset: str = "high"
    generation_time_seconds: float = 0.0
    file_size_mb: float = 0.0
    # Metadata
    tags: List[str] = field(default_factory=list)
    aesthetic_style: str = ""
    error: Optional[str] = None


class EnvironmentManifest:
    """Persistent manifest tracking all generated environments."""

    def __init__(self, path: Optional[Path] = None):
        self.path = path or MANIFEST_PATH
        self.entries: Dict[str, EnvironmentEntry] = {}
        self._load()

    def _load(self):
        if self.path.exists():
            data = json.loads(self.path.read_text())
            for key, entry_data in data.get("environments", {}).items():
                self.entries[key] = EnvironmentEntry(**entry_data)
            print(f"  [Manifest] Loaded {len(self.entries)} environments")

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "version": "1.0.0",
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "total_environments": len(self.entries),
            "ready_count": sum(1 for e in self.entries.values() if e.status == "ready"),
            "environments": {k: asdict(v) for k, v in self.entries.items()}
        }
        self.path.write_text(json.dumps(data, indent=2))

    def has(self, prompt_key: str) -> bool:
        entry = self.entries.get(prompt_key)
        if not entry:
            return False
        if entry.status != "ready":
            return False
        # Verify at least one output exists
        for path in [entry.equirect_path, entry.video_texture_path, entry.source_image]:
            if path and os.path.exists(path):
                return True
        return False

    def get(self, prompt_key: str) -> Optional[EnvironmentEntry]:
        return self.entries.get(prompt_key)

    def set(self, prompt_key: str, entry: EnvironmentEntry):
        self.entries[prompt_key] = entry
        self.save()


class EnvironmentGenerator:
    """Orchestrates the full environment generation pipeline."""

    def __init__(self, quality: str = "high",
                 preferred_backend: Optional[Backend] = None,
                 dry_run: bool = False):
        self.quality = quality
        self.dry_run = dry_run
        self.client = GenerativeWorldModelClient(preferred_backend=preferred_backend)
        self.converter = SkyboxConverter(quality=quality)
        self.manifest = EnvironmentManifest()
        ensure_dirs()

    def generate_environment(self, prompt_key: str,
                             prompt_text: Optional[str] = None,
                             force: bool = False) -> EnvironmentEntry:
        """Generate a single environment from prompt.

        Args:
            prompt_key: Key identifying the environment (e.g. 'retro_tokyo_night').
            prompt_text: Optional custom prompt text. Uses preset if not provided.
            force: Force regeneration even if cached.

        Returns:
            EnvironmentEntry with generation results.
        """
        # Resolve prompt
        prompt = prompt_text or ENVIRONMENT_PROMPTS.get(prompt_key, "")
        if not prompt:
            print(f"  [ERROR] No prompt found for key: {prompt_key}")
            return EnvironmentEntry(
                prompt_id=prompt_key, prompt_key=prompt_key,
                prompt_text="", backend_used="none",
                status="failed", error=f"Unknown prompt key: {prompt_key}"
            )

        # Check cache
        if not force and self.manifest.has(prompt_key):
            print(f"  [Cache] Environment '{prompt_key}' already generated, skipping")
            return self.manifest.get(prompt_key)

        print(f"\n{'='*70}")
        print(f"  GENERATING ENVIRONMENT: {prompt_key}")
        print(f"  Prompt: {prompt[:100]}...")
        print(f"  Quality: {self.quality} | Dry Run: {self.dry_run}")
        print(f"{'='*70}")

        start_time = time.time()

        # Create entry
        entry = EnvironmentEntry(
            prompt_id=prompt_key,
            prompt_key=prompt_key,
            prompt_text=prompt,
            backend_used="",
            status="generating",
            created_at=datetime.now(timezone.utc).isoformat(),
            quality_preset=self.quality,
            tags=self._extract_tags(prompt),
            aesthetic_style=self._detect_style(prompt),
            ue5_content_path=f"/Game/FEL/Environments/Generated/{prompt_key}",
            ue5_material_path=f"/Game/FEL/Environments/Generated/{prompt_key}/M_{prompt_key}",
        )

        if self.dry_run:
            entry.status = "dry_run"
            entry.backend_used = "dry_run"
            self.manifest.set(prompt_key, entry)
            print(f"  [DRY RUN] Would generate environment for: {prompt_key}")
            return entry

        # --- Phase 1: Generate via world model API ---
        print(f"\n  Phase 1: Generative World Model")
        gen_result = self.client.generate(prompt, prompt_key=prompt_key)
        entry.backend_used = gen_result.backend
        entry.generation_task_id = gen_result.task_id

        if gen_result.status == "failed":
            entry.status = "failed"
            entry.error = gen_result.error
            self.manifest.set(prompt_key, entry)
            print(f"  [FAILED] Generation failed: {gen_result.error}")
            return entry

        # If processing, poll for completion
        if gen_result.status == "processing" and gen_result.task_id:
            print(f"  Polling for completion (task={gen_result.task_id})...")
            if gen_result.backend == "luma":
                gen_result = self.client.luma.poll_status(
                    gen_result.task_id, prompt_key
                )
            elif gen_result.backend == "runway":
                gen_result = self.client.runway.poll_status(
                    gen_result.task_id, prompt_key
                )

        if gen_result.image_path:
            entry.source_image = gen_result.image_path
        if gen_result.video_path:
            entry.source_video = gen_result.video_path

        # --- Phase 2: Convert to skybox formats ---
        print(f"\n  Phase 2: Skybox Conversion")
        entry.status = "converting"
        self.manifest.set(prompt_key, entry)

        skybox = self.converter.convert(
            prompt_key,
            source_image=entry.source_image,
            source_video=entry.source_video
        )

        entry.equirect_path = skybox.equirect_path
        entry.cubemap_dir = str(GENERATED_ROOT / prompt_key / "skybox" / "cubemap")
        entry.hdr_path = skybox.hdr_path
        entry.video_texture_path = skybox.video_texture_path
        entry.thumbnail_path = skybox.thumbnail_path
        entry.parallax_layers = skybox.layers

        # --- Phase 3: Finalize ---
        elapsed = time.time() - start_time
        entry.generation_time_seconds = round(elapsed, 2)
        entry.file_size_mb = self._calc_size(prompt_key)
        entry.status = "ready"
        self.manifest.set(prompt_key, entry)

        print(f"\n  ✅ Environment '{prompt_key}' ready in {elapsed:.1f}s")
        print(f"     UE5 Path: {entry.ue5_content_path}")
        print(f"     Size: {entry.file_size_mb:.1f} MB")

        return entry

    def generate_all_presets(self, force: bool = False) -> Dict[str, EnvironmentEntry]:
        """Generate all preset environments."""
        results = {}
        total = len(ENVIRONMENT_PROMPTS)
        for i, (key, prompt) in enumerate(ENVIRONMENT_PROMPTS.items(), 1):
            print(f"\n[{i}/{total}] Processing: {key}")
            results[key] = self.generate_environment(key, prompt, force=force)
        return results

    def generate_custom(self, prompt: str, key: Optional[str] = None,
                        force: bool = False) -> EnvironmentEntry:
        """Generate from a custom prompt not in presets."""
        import hashlib
        if not key:
            h = hashlib.sha256(prompt.encode()).hexdigest()[:8]
            key = f"custom_{h}"
        return self.generate_environment(key, prompt_text=prompt, force=force)

    def swap_environment(self, current_id: str, new_id: str) -> Dict[str, Any]:
        """Prepare data for runtime environment swap in UE5.

        Returns a JSON command payload that the PixelStreaming bridge
        will forward to the UE5 game server.
        """
        new_env = self.manifest.get(new_id)
        if not new_env or new_env.status != "ready":
            return {"success": False, "error": f"Environment {new_id} not ready"}

        return {
            "success": True,
            "command": "SwapEnvironment",
            "payload": {
                "previous_id": current_id,
                "new_id": new_id,
                "ue5_content_path": new_env.ue5_content_path,
                "equirect_texture": new_env.equirect_path,
                "video_texture": new_env.video_texture_path,
                "cubemap_dir": new_env.cubemap_dir,
                "parallax_layers": new_env.parallax_layers,
                "quality_preset": new_env.quality_preset,
            }
        }

    def get_environment_gallery(self) -> List[Dict[str, Any]]:
        """Get gallery data for all ready environments."""
        gallery = []
        for key, entry in self.manifest.entries.items():
            if entry.status == "ready":
                gallery.append({
                    "id": key,
                    "name": key.replace("_", " ").title(),
                    "prompt": entry.prompt_text[:100],
                    "thumbnail": entry.thumbnail_path,
                    "style": entry.aesthetic_style,
                    "tags": entry.tags,
                    "created_at": entry.created_at,
                })
        return gallery

    def _extract_tags(self, prompt: str) -> List[str]:
        """Extract searchable tags from prompt."""
        keywords = [
            "neon", "retro", "cyberpunk", "sunset", "night", "urban",
            "beach", "indoor", "outdoor", "stadium", "street", "rooftop",
            "winter", "tropical", "industrial", "zen", "arcade", "gym",
            "basketball", "soccer", "boxing", "dojo", "warehouse",
            "cinematic", "gritty", "nba", "graffiti", "holographic",
        ]
        prompt_lower = prompt.lower()
        return [k for k in keywords if k in prompt_lower]

    def _detect_style(self, prompt: str) -> str:
        """Detect aesthetic style from prompt."""
        prompt_lower = prompt.lower()
        if "cyberpunk" in prompt_lower or "neon" in prompt_lower:
            return "cyberpunk"
        if "retro" in prompt_lower or "90s" in prompt_lower or "2006" in prompt_lower:
            return "retro"
        if "zen" in prompt_lower or "minimalist" in prompt_lower:
            return "zen"
        if "industrial" in prompt_lower or "warehouse" in prompt_lower:
            return "industrial"
        if "tropical" in prompt_lower or "beach" in prompt_lower:
            return "tropical"
        if "arcade" in prompt_lower or "synthwave" in prompt_lower:
            return "synthwave"
        return "cinematic"

    def _calc_size(self, prompt_id: str) -> float:
        """Calculate total file size of generated environment."""
        env_dir = GENERATED_ROOT / prompt_id
        if not env_dir.exists():
            return 0.0
        total = sum(f.stat().st_size for f in env_dir.rglob("*") if f.is_file())
        return round(total / (1024 * 1024), 2)


def generate_quality_report(manifest: EnvironmentManifest) -> Dict[str, Any]:
    """Generate a quality report comparing all environments."""
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_environments": len(manifest.entries),
        "ready": sum(1 for e in manifest.entries.values() if e.status == "ready"),
        "failed": sum(1 for e in manifest.entries.values() if e.status == "failed"),
        "by_style": {},
        "by_backend": {},
        "performance": {
            "avg_generation_time": 0,
            "avg_file_size_mb": 0,
            "total_storage_mb": 0,
        },
        "environments": [],
    }

    gen_times = []
    file_sizes = []

    for key, entry in manifest.entries.items():
        # Group by style
        style = entry.aesthetic_style or "unknown"
        report["by_style"].setdefault(style, [])
        report["by_style"][style].append(key)

        # Group by backend
        backend = entry.backend_used or "unknown"
        report["by_backend"].setdefault(backend, [])
        report["by_backend"][backend].append(key)

        if entry.generation_time_seconds > 0:
            gen_times.append(entry.generation_time_seconds)
        if entry.file_size_mb > 0:
            file_sizes.append(entry.file_size_mb)

        report["environments"].append({
            "id": key,
            "status": entry.status,
            "style": style,
            "backend": backend,
            "generation_time": entry.generation_time_seconds,
            "file_size_mb": entry.file_size_mb,
            "has_equirect": entry.equirect_path is not None,
            "has_cubemap": entry.cubemap_dir is not None,
            "has_video_texture": entry.video_texture_path is not None,
            "has_parallax_layers": len(entry.parallax_layers) > 0,
            "tags": entry.tags,
        })

    if gen_times:
        report["performance"]["avg_generation_time"] = round(
            sum(gen_times) / len(gen_times), 2
        )
    if file_sizes:
        report["performance"]["avg_file_size_mb"] = round(
            sum(file_sizes) / len(file_sizes), 2
        )
        report["performance"]["total_storage_mb"] = round(sum(file_sizes), 2)

    return report


# ===========================================================================
# CLI
# ===========================================================================
def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="FEL Environment Generator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Generate specific preset:
    python -m scripts.environment_gen.environment_generator --prompt-key retro_tokyo_night

  Generate all presets:
    python -m scripts.environment_gen.environment_generator --all

  Custom prompt:
    python -m scripts.environment_gen.environment_generator --prompt "My custom scene..."

  Dry run (no API calls):
    python -m scripts.environment_gen.environment_generator --all --dry-run

  Force regeneration:
    python -m scripts.environment_gen.environment_generator --prompt-key venice_beach_sunset --force
"""
    )
    parser.add_argument("--prompt-key", type=str, help="Preset prompt key")
    parser.add_argument("--prompt", type=str, help="Custom prompt text")
    parser.add_argument("--all", action="store_true", help="Generate all presets")
    parser.add_argument("--force", action="store_true", help="Force regeneration")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--quality", default="high", choices=QUALITY_PRESETS.keys())
    parser.add_argument("--backend", type=str, choices=["stability", "runway", "luma", "gaia"])
    parser.add_argument("--report", action="store_true", help="Generate quality report")
    parser.add_argument("--gallery", action="store_true", help="Print environment gallery")
    parser.add_argument("--list", action="store_true", help="List available presets")
    args = parser.parse_args()

    if args.list:
        print("\nAvailable environment presets:")
        for key, prompt in ENVIRONMENT_PROMPTS.items():
            print(f"  {key}:")
            print(f"    {prompt[:100]}...")
        return

    backend = Backend(args.backend) if args.backend else None
    gen = EnvironmentGenerator(
        quality=args.quality,
        preferred_backend=backend,
        dry_run=args.dry_run
    )

    if args.report:
        report = generate_quality_report(gen.manifest)
        report_path = GENERATED_ROOT / "quality_report.json"
        report_path.write_text(json.dumps(report, indent=2))
        print(f"Quality report saved to {report_path}")
        return

    if args.gallery:
        gallery = gen.get_environment_gallery()
        print(json.dumps(gallery, indent=2))
        return

    if args.all:
        results = gen.generate_all_presets(force=args.force)
    elif args.prompt_key:
        results = {args.prompt_key: gen.generate_environment(
            args.prompt_key, force=args.force
        )}
    elif args.prompt:
        entry = gen.generate_custom(args.prompt, force=args.force)
        results = {entry.prompt_key: entry}
    else:
        parser.print_help()
        return

    # Print summary
    print(f"\n{'='*70}")
    print("GENERATION SUMMARY")
    print(f"{'='*70}")
    ready = sum(1 for e in results.values() if e.status in ("ready", "dry_run"))
    failed = sum(1 for e in results.values() if e.status == "failed")
    print(f"  Ready:  {ready}")
    print(f"  Failed: {failed}")
    print(f"  Total:  {len(results)}")

    # Generate quality report
    report = generate_quality_report(gen.manifest)
    report_path = GENERATED_ROOT / "quality_report.json"
    report_path.write_text(json.dumps(report, indent=2))
    print(f"\n  Quality report: {report_path}")


if __name__ == "__main__":
    main()
