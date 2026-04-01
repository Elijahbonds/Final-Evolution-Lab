#!/usr/bin/env python3
"""
Background Masking Module — Biomechanical Isolation Pipeline

Creates silhouette/masked videos from segmentation masks, removing
environmental noise (other players, crowd, scoreboards) that can
cause motion capture hallucinations.

Outputs:
  - Masked video (primary actor only, black background)
  - Silhouette video (white actor on black background)
  - Green-screen video (primary actor on green background)

Usage:
    python background_masking.py --input video.mp4 --masks masks/ --output output/
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Optional

import cv2
import numpy as np


def apply_mask_to_frame(
    frame: np.ndarray,
    mask: np.ndarray,
    mode: str = "masked",
    bg_color: tuple = (0, 0, 0),
    feather_radius: int = 3
) -> np.ndarray:
    """
    Apply segmentation mask to a frame.

    Modes:
      - masked: Original pixels for actor, bg_color elsewhere
      - silhouette: White actor on black background
      - greenscreen: Original actor on green background
      - alpha: 4-channel BGRA with transparency
    """
    h, w = frame.shape[:2]

    # Ensure mask matches frame dimensions
    if mask.shape[:2] != (h, w):
        mask = cv2.resize(mask, (w, h), interpolation=cv2.INTER_NEAREST)

    # Feather mask edges for smoother blending
    if feather_radius > 0:
        mask_float = mask.astype(np.float32) / 255.0
        mask_float = cv2.GaussianBlur(mask_float, (feather_radius * 2 + 1, feather_radius * 2 + 1), 0)
        mask_float = np.clip(mask_float, 0, 1)
    else:
        mask_float = mask.astype(np.float32) / 255.0

    if mode == "silhouette":
        result = np.zeros_like(frame)
        result[mask > 127] = (255, 255, 255)
        return result

    elif mode == "greenscreen":
        bg = np.full_like(frame, (0, 255, 0))  # Green
        mask_3ch = np.stack([mask_float] * 3, axis=-1)
        result = (frame * mask_3ch + bg * (1 - mask_3ch)).astype(np.uint8)
        return result

    elif mode == "alpha":
        alpha = (mask_float * 255).astype(np.uint8)
        bgra = cv2.cvtColor(frame, cv2.COLOR_BGR2BGRA)
        bgra[:, :, 3] = alpha
        return bgra

    else:  # masked
        bg = np.full_like(frame, bg_color)
        mask_3ch = np.stack([mask_float] * 3, axis=-1)
        result = (frame * mask_3ch + bg * (1 - mask_3ch)).astype(np.uint8)
        return result


def create_masked_video(
    video_path: str,
    masks_dir: str,
    output_dir: str,
    modes: list = None,
    feather_radius: int = 3
) -> Dict:
    """
    Create masked output videos from segmentation masks.

    Returns metadata dict with output video info.
    """
    if modes is None:
        modes = ["masked", "silhouette", "greenscreen"]

    video_path = Path(video_path)
    masks_dir = Path(masks_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise FileNotFoundError(f"Cannot open: {video_path}")

    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # Create writers for each mode
    writers = {}
    output_paths = {}
    for mode in modes:
        out_path = output_dir / f"{video_path.stem}_{mode}.mp4"
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writers[mode] = cv2.VideoWriter(str(out_path), fourcc, fps, (width, height))
        output_paths[mode] = str(out_path)

    frame_idx = 0
    frames_masked = 0
    mask_coverage_sum = 0.0

    print(f"[INFO] Creating masked videos for {video_path.name} (modes: {modes})")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Load corresponding mask
        mask_path = masks_dir / f"mask_{frame_idx:06d}.png"
        if mask_path.exists():
            mask = cv2.imread(str(mask_path), cv2.IMREAD_GRAYSCALE)
            frames_masked += 1
            mask_coverage_sum += np.count_nonzero(mask) / (height * width)
        else:
            mask = np.zeros((height, width), dtype=np.uint8)

        for mode in modes:
            result = apply_mask_to_frame(frame, mask, mode=mode, feather_radius=feather_radius)
            writers[mode].write(result)

        frame_idx += 1
        if frame_idx % 100 == 0:
            print(f"  Frame {frame_idx}/{total_frames}")

    cap.release()
    for w in writers.values():
        w.release()

    metadata = {
        "source_video": str(video_path),
        "video_name": video_path.stem,
        "total_frames": total_frames,
        "frames_processed": frame_idx,
        "frames_with_mask": frames_masked,
        "avg_mask_coverage": mask_coverage_sum / max(frames_masked, 1),
        "modes_generated": modes,
        "output_videos": output_paths,
        "feather_radius": feather_radius
    }

    meta_path = output_dir / f"{video_path.stem}_masking_meta.json"
    with open(meta_path, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"[INFO] Masked videos created: {list(output_paths.keys())}")
    return metadata


def main():
    parser = argparse.ArgumentParser(description="Background Masking for Biomechanical Isolation")
    parser.add_argument("--input", "-i", required=True, help="Input video path")
    parser.add_argument("--masks", "-m", required=True, help="Masks directory")
    parser.add_argument("--output", "-o", required=True, help="Output directory")
    parser.add_argument("--modes", nargs="+", default=["masked", "silhouette", "greenscreen"],
                        choices=["masked", "silhouette", "greenscreen", "alpha"])
    parser.add_argument("--feather", type=int, default=3, help="Edge feather radius")
    args = parser.parse_args()

    create_masked_video(
        video_path=args.input,
        masks_dir=args.masks,
        output_dir=args.output,
        modes=args.modes,
        feather_radius=args.feather
    )


if __name__ == "__main__":
    main()
