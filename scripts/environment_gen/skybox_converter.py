"""Skybox Converter - Transform generated images/videos into 360° skybox formats.

Converts generative model outputs to UE5-compatible formats:
  - Equirectangular panorama (for UE5 sky sphere)
  - Cubemap (6 faces) for dynamic skybox
  - HDR skybox for lighting
  - Video texture (looping MP4 for MediaTexture)
  - 2.5D layered backdrop (parallax layers)

Key insight: Gaia/generative models output 2D video/images.
We use projection techniques to wrap them into 360° environments,
creating the ILLUSION of 3D space while keeping the cost of a 2D texture.
"""

import json
import struct
import math
import os
import subprocess
import shutil
from pathlib import Path
from typing import Optional, Dict, List, Tuple
from dataclasses import dataclass, field

from .config import GENERATED_ROOT, UE5_CONTENT, QUALITY_PRESETS, QualityPreset


@dataclass
class SkyboxOutput:
    """Output paths from skybox conversion."""
    prompt_id: str
    equirect_path: Optional[str] = None
    cubemap_paths: Dict[str, str] = field(default_factory=dict)  # face -> path
    hdr_path: Optional[str] = None
    video_texture_path: Optional[str] = None
    thumbnail_path: Optional[str] = None
    layers: List[str] = field(default_factory=list)  # parallax layers
    format_info: Dict[str, str] = field(default_factory=dict)


def _run_ffmpeg(args: List[str], check: bool = True) -> bool:
    """Run ffmpeg command, return success."""
    cmd = ["ffmpeg", "-y"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if check and result.returncode != 0:
            print(f"  [ffmpeg] Error: {result.stderr[:500]}")
            return False
        return True
    except FileNotFoundError:
        print("  [WARN] ffmpeg not found - install with: sudo apt install ffmpeg")
        return False
    except subprocess.TimeoutExpired:
        print("  [WARN] ffmpeg timeout")
        return False


def _run_imagemagick(args: List[str]) -> bool:
    """Run ImageMagick convert command."""
    cmd = ["convert"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        return result.returncode == 0
    except FileNotFoundError:
        print("  [WARN] ImageMagick not found - install with: sudo apt install imagemagick")
        return False


class SkyboxConverter:
    """Convert generated images/videos to UE5-compatible skybox formats."""

    # Cubemap face names matching UE5 convention
    CUBEMAP_FACES = ["PosX", "NegX", "PosY", "NegY", "PosZ", "NegZ"]

    def __init__(self, quality: str = "high"):
        self.preset: QualityPreset = QUALITY_PRESETS.get(quality, QUALITY_PRESETS["high"])

    def convert(self, prompt_id: str,
                source_image: Optional[str] = None,
                source_video: Optional[str] = None) -> SkyboxOutput:
        """Full conversion pipeline for a generated environment.

        Args:
            prompt_id: Environment identifier.
            source_image: Path to generated panoramic image.
            source_video: Path to generated video.

        Returns:
            SkyboxOutput with all converted asset paths.
        """
        out_dir = GENERATED_ROOT / prompt_id / "skybox"
        out_dir.mkdir(parents=True, exist_ok=True)
        output = SkyboxOutput(prompt_id=prompt_id)

        print(f"  [Skybox] Converting {prompt_id} (preset={self.preset.name})")

        # 1. Create equirectangular panorama from source image
        if source_image and os.path.exists(source_image):
            equirect = self._create_equirectangular(source_image, out_dir)
            if equirect:
                output.equirect_path = str(equirect)

            # 2. Generate cubemap from equirectangular
            if output.equirect_path:
                cubemap = self._create_cubemap(output.equirect_path, out_dir)
                output.cubemap_paths = cubemap

            # 3. Create HDR version
            if output.equirect_path:
                hdr = self._create_hdr(output.equirect_path, out_dir)
                if hdr:
                    output.hdr_path = str(hdr)

            # 4. Create parallax layers for 2.5D effect
            layers = self._create_parallax_layers(source_image, out_dir)
            output.layers = layers

            # 5. Create thumbnail
            thumb = self._create_thumbnail(source_image, out_dir)
            if thumb:
                output.thumbnail_path = str(thumb)

        # 6. Process video texture
        if source_video and os.path.exists(source_video):
            vid_tex = self._create_video_texture(source_video, out_dir)
            if vid_tex:
                output.video_texture_path = str(vid_tex)

        output.format_info = {
            "quality_preset": self.preset.name,
            "skybox_resolution": str(self.preset.skybox_resolution),
            "video_resolution": str(self.preset.video_texture_resolution),
            "hdr": str(self.preset.hdr),
            "compression": self.preset.compression,
        }

        # Save conversion metadata
        meta_path = out_dir / "conversion_meta.json"
        meta_path.write_text(json.dumps({
            "prompt_id": prompt_id,
            "equirect": output.equirect_path,
            "cubemap": output.cubemap_paths,
            "hdr": output.hdr_path,
            "video_texture": output.video_texture_path,
            "layers": output.layers,
            "format_info": output.format_info,
        }, indent=2))

        return output

    def _create_equirectangular(self, image_path: str, out_dir: Path) -> Optional[Path]:
        """Create equirectangular projection from source image.

        Takes a 16:9 or panoramic image and maps it to equirectangular
        format suitable for UE5 sky sphere projection.
        """
        res = self.preset.skybox_resolution
        out_path = out_dir / f"equirect_{res}x{res // 2}.png"
        print(f"    Creating equirectangular {res}x{res // 2}")

        # Use ffmpeg to resize and pad to equirectangular aspect ratio (2:1)
        success = _run_ffmpeg([
            "-i", image_path,
            "-vf", f"scale={res}:{res // 2}:force_original_aspect_ratio=decrease,"
                   f"pad={res}:{res // 2}:(ow-iw)/2:(oh-ih)/2:color=black",
            "-q:v", "2",
            str(out_path)
        ])
        return out_path if success and out_path.exists() else None

    def _create_cubemap(self, equirect_path: str, out_dir: Path) -> Dict[str, str]:
        """Split equirectangular image into 6 cubemap faces.

        Uses ffmpeg's v360 filter for proper projection.
        """
        face_size = self.preset.skybox_resolution // 4
        cubemap = {}
        cubemap_dir = out_dir / "cubemap"
        cubemap_dir.mkdir(exist_ok=True)

        print(f"    Creating cubemap faces ({face_size}x{face_size})")

        # Map face names to rotation parameters for v360
        face_rotations = {
            "PosX": "rpy=0:90:0",    # Right
            "NegX": "rpy=0:-90:0",   # Left
            "PosY": "rpy=90:0:0",    # Up
            "NegY": "rpy=-90:0:0",   # Down
            "PosZ": "rpy=0:0:0",     # Front
            "NegZ": "rpy=0:180:0",   # Back
        }

        for face, rotation in face_rotations.items():
            face_path = cubemap_dir / f"{face}.png"
            success = _run_ffmpeg([
                "-i", equirect_path,
                "-vf", f"v360=equirect:flat:h_fov=90:v_fov=90:{rotation}:"
                       f"w={face_size}:h={face_size}",
                "-q:v", "2",
                str(face_path)
            ])
            if success and face_path.exists():
                cubemap[face] = str(face_path)

        return cubemap

    def _create_hdr(self, equirect_path: str, out_dir: Path) -> Optional[Path]:
        """Create HDR version of skybox for UE5 lighting.

        Converts the LDR panorama to a pseudo-HDR by expanding dynamic range.
        For production, use actual HDR captures or AI upscaling.
        """
        hdr_path = out_dir / "skybox.hdr"
        print(f"    Creating HDR skybox")

        if not self.preset.hdr:
            print(f"    Skipping HDR (preset={self.preset.name} has hdr=False)")
            return None

        # Use ImageMagick to create a basic HDR-like EXR
        # In production, use proper HDRI generation
        exr_path = out_dir / "skybox.exr"
        success = _run_imagemagick([
            equirect_path,
            "-colorspace", "RGB",
            "-evaluate", "multiply", "1.5",  # Boost for pseudo-HDR
            str(exr_path)
        ])
        if success and exr_path.exists():
            return exr_path

        # Fallback: copy the equirect as-is
        shutil.copy2(equirect_path, out_dir / "skybox_ldr.png")
        return out_dir / "skybox_ldr.png"

    def _create_parallax_layers(self, image_path: str, out_dir: Path) -> List[str]:
        """Create parallax depth layers for 2.5D backdrop effect.

        Splits the environment image into foreground/midground/background
        layers that scroll at different rates for depth illusion.

        This is the key optimization for mobile performance:
        instead of a full 3D environment, we render 2-4 textured planes
        at different distances from the camera.
        """
        layers_dir = out_dir / "layers"
        layers_dir.mkdir(exist_ok=True)
        layer_paths = []

        print(f"    Creating 2.5D parallax layers")

        # Layer definitions (name, crop_region, parallax_speed)
        layer_defs = [
            ("sky_bg", "0:0:100:40", 0.1),       # Top 40% - sky/far background
            ("mid_bg", "0:20:100:70", 0.3),       # Middle section
            ("foreground", "0:50:100:100", 0.7),  # Bottom 50% - ground/near
        ]

        for name, crop_pct, speed in layer_defs:
            layer_path = layers_dir / f"{name}.png"
            # Parse crop percentages
            parts = crop_pct.split(":")
            x, y, w, h = int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])

            res = self.preset.skybox_resolution
            crop_str = (
                f"crop=w=iw*{(w - x) / 100}:h=ih*{(h - y) / 100}:"
                f"x=iw*{x / 100}:y=ih*{y / 100}"
            )
            success = _run_ffmpeg([
                "-i", image_path,
                "-vf", f"{crop_str},scale={res}:-2",
                "-q:v", "2",
                str(layer_path)
            ])
            if success and layer_path.exists():
                layer_paths.append(str(layer_path))

        # Write layer metadata
        layer_meta = layers_dir / "layers.json"
        layer_meta.write_text(json.dumps({
            "layers": [
                {"name": d[0], "path": str(layers_dir / f"{d[0]}.png"),
                 "parallax_speed": d[2], "depth_order": i}
                for i, d in enumerate(layer_defs)
            ]
        }, indent=2))

        return layer_paths

    def _create_video_texture(self, video_path: str, out_dir: Path) -> Optional[Path]:
        """Optimize video for UE5 MediaTexture playback.

        Requirements:
          - H.264 for broad compatibility
          - Resolution matching preset
          - Seamless loop if possible
          - Constant bitrate for streaming
        """
        res = self.preset.video_texture_resolution
        out_path = out_dir / f"video_texture_{res}p.mp4"
        print(f"    Creating video texture ({res}p)")

        success = _run_ffmpeg([
            "-i", video_path,
            "-vf", f"scale={res * 16 // 9}:{res}",
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "18",
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            "-an",  # No audio for texture
            str(out_path)
        ])
        return out_path if success and out_path.exists() else None

    def _create_thumbnail(self, image_path: str, out_dir: Path) -> Optional[Path]:
        """Create thumbnail for UI gallery."""
        thumb_path = out_dir / "thumbnail.jpg"
        success = _run_ffmpeg([
            "-i", image_path,
            "-vf", "scale=512:288",
            "-q:v", "5",
            str(thumb_path)
        ])
        return thumb_path if success and thumb_path.exists() else None

    def batch_convert(self, environments: Dict[str, Dict]) -> Dict[str, SkyboxOutput]:
        """Convert multiple environments.

        Args:
            environments: dict of prompt_id -> {"image": path, "video": path}
        """
        results = {}
        for pid, sources in environments.items():
            results[pid] = self.convert(
                pid,
                source_image=sources.get("image"),
                source_video=sources.get("video")
            )
        return results


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Skybox Converter")
    parser.add_argument("--prompt-id", required=True)
    parser.add_argument("--image", type=str)
    parser.add_argument("--video", type=str)
    parser.add_argument("--quality", default="high", choices=QUALITY_PRESETS.keys())
    args = parser.parse_args()

    converter = SkyboxConverter(quality=args.quality)
    result = converter.convert(args.prompt_id, source_image=args.image, source_video=args.video)
    print(f"Output: {result}")
