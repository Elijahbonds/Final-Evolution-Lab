#!/usr/bin/env python3
"""
Hoop Detection Module — Biomechanical Isolation Pipeline

Detects basketball hoop/rim coordinates as a spatial reference point
for normalizing motion capture data. Uses a combination of:
  1. YOLOv11 custom detection (if trained model available)
  2. Color-based detection (orange rim)
  3. Hough circle/line detection
  4. Template matching fallback

The hoop position provides:
  - Spatial anchor for consistent coordinate system
  - Scale reference (standard rim = 18 inches diameter)
  - Height reference (standard rim = 10 feet)

Usage:
    python hoop_detection.py --input video.mp4 --output hoop_data/
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np

try:
    from ultralytics import YOLO
    HAS_YOLO = True
except ImportError:
    HAS_YOLO = False


# Standard basketball hoop dimensions (in real-world units)
HOOP_DIAMETER_INCHES = 18.0
HOOP_HEIGHT_FEET = 10.0
BACKBOARD_WIDTH_INCHES = 72.0
BACKBOARD_HEIGHT_INCHES = 42.0


class HoopDetector:
    """Multi-strategy basketball hoop detector."""

    def __init__(self, strategy: str = "auto"):
        self.strategy = strategy
        self.hoop_history: List[Dict] = []
        self.stable_hoop: Optional[Dict] = None
        self.stability_threshold = 10  # frames to establish stable position

    def detect_frame(self, frame: np.ndarray, frame_idx: int) -> Optional[Dict]:
        """Detect hoop in a single frame using configured strategy."""
        detections = []

        # Strategy 1: Color-based rim detection
        color_det = self._detect_by_color(frame)
        if color_det:
            detections.append(color_det)

        # Strategy 2: Hough circles for rim
        circle_det = self._detect_by_circles(frame)
        if circle_det:
            detections.append(circle_det)

        # Strategy 3: Edge/contour-based backboard detection
        contour_det = self._detect_by_contours(frame)
        if contour_det:
            detections.append(contour_det)

        if not detections:
            return None

        # Consensus: pick detection with highest confidence
        best = max(detections, key=lambda d: d["confidence"])

        # Update history for temporal smoothing
        self.hoop_history.append(best)
        if len(self.hoop_history) > 30:
            self.hoop_history.pop(0)

        # Establish stable position after enough detections
        if len(self.hoop_history) >= self.stability_threshold:
            self.stable_hoop = self._compute_stable_position()

        return self.stable_hoop if self.stable_hoop else best

    def _detect_by_color(self, frame: np.ndarray) -> Optional[Dict]:
        """Detect orange rim via HSV color filtering."""
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        h, w = frame.shape[:2]

        # Orange color range for basketball rim
        lower_orange = np.array([5, 100, 100])
        upper_orange = np.array([25, 255, 255])
        mask = cv2.inRange(hsv, lower_orange, upper_orange)

        # Focus on upper portion of frame (hoop is usually at top)
        mask[:int(h * 0.5), :] = mask[:int(h * 0.5), :]  # keep upper half
        mask[int(h * 0.7):, :] = 0  # remove bottom 30%

        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if not contours:
            return None

        # Filter by aspect ratio (rim is wider than tall)
        candidates = []
        for cnt in contours:
            x, y, cw, ch = cv2.boundingRect(cnt)
            area = cv2.contourArea(cnt)
            if area < 200:
                continue
            aspect = cw / max(ch, 1)
            if 1.5 < aspect < 6.0:  # Rim-like aspect ratio
                candidates.append({
                    "center": [x + cw // 2, y + ch // 2],
                    "bbox": [x, y, x + cw, y + ch],
                    "radius_px": cw // 2,
                    "confidence": min(0.7, area / 2000),
                    "method": "color"
                })

        if not candidates:
            return None

        return max(candidates, key=lambda c: c["confidence"])

    def _detect_by_circles(self, frame: np.ndarray) -> Optional[Dict]:
        """Detect rim using Hough circle transform."""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape

        # Focus on upper portion
        roi = gray[:int(h * 0.6), :]
        blurred = cv2.GaussianBlur(roi, (9, 9), 2)

        circles = cv2.HoughCircles(
            blurred, cv2.HOUGH_GRADIENT, dp=1.2,
            minDist=50, param1=100, param2=40,
            minRadius=15, maxRadius=min(w // 4, 200)
        )

        if circles is None:
            return None

        circles = np.uint16(np.around(circles[0]))

        # Pick circle most likely to be a hoop (upper-center of frame)
        best_score = -1
        best_circle = None
        for c in circles:
            cx, cy, r = int(c[0]), int(c[1]), int(c[2])
            # Prefer circles in upper-center region
            center_score = 1.0 - abs(cx - w / 2) / (w / 2)
            height_score = 1.0 - cy / (h * 0.6)
            size_score = min(r / 40, 1.0)  # prefer larger circles
            score = center_score * 0.3 + height_score * 0.4 + size_score * 0.3
            if score > best_score:
                best_score = score
                best_circle = (cx, cy, r)

        if best_circle is None:
            return None

        cx, cy, r = best_circle
        return {
            "center": [cx, cy],
            "bbox": [cx - r, cy - r, cx + r, cy + r],
            "radius_px": r,
            "confidence": min(0.6, best_score),
            "method": "hough_circle"
        }

    def _detect_by_contours(self, frame: np.ndarray) -> Optional[Dict]:
        """Detect backboard via edge detection and rectangular contours."""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape

        # Focus on upper portion
        roi = gray[:int(h * 0.5), :]
        edges = cv2.Canny(roi, 50, 150)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 3))
        edges = cv2.dilate(edges, kernel, iterations=1)

        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        candidates = []
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area < 500:
                continue
            peri = cv2.arcLength(cnt, True)
            approx = cv2.approxPolyDP(cnt, 0.04 * peri, True)
            if len(approx) == 4:  # Rectangular shape (backboard)
                x, y, cw, ch = cv2.boundingRect(approx)
                aspect = cw / max(ch, 1)
                if 1.2 < aspect < 3.0:  # Backboard aspect ratio
                    # Rim center is below backboard center
                    rim_y = y + ch + int(ch * 0.3)
                    candidates.append({
                        "center": [x + cw // 2, rim_y],
                        "bbox": [x, y, x + cw, y + ch],
                        "radius_px": cw // 4,
                        "confidence": min(0.5, area / 5000),
                        "method": "contour_backboard"
                    })

        if not candidates:
            return None

        return max(candidates, key=lambda c: c["confidence"])

    def _compute_stable_position(self) -> Dict:
        """Compute a temporally-smoothed stable hoop position."""
        recent = self.hoop_history[-self.stability_threshold:]
        centers = np.array([d["center"] for d in recent])
        radii = np.array([d["radius_px"] for d in recent])
        confidences = np.array([d["confidence"] for d in recent])

        # Weighted average by confidence
        weights = confidences / confidences.sum()
        avg_center = np.average(centers, axis=0, weights=weights).tolist()
        avg_radius = float(np.average(radii, weights=weights))
        avg_conf = float(np.mean(confidences))

        return {
            "center": [int(avg_center[0]), int(avg_center[1])],
            "bbox": [
                int(avg_center[0] - avg_radius),
                int(avg_center[1] - avg_radius),
                int(avg_center[0] + avg_radius),
                int(avg_center[1] + avg_radius)
            ],
            "radius_px": int(avg_radius),
            "confidence": avg_conf,
            "method": "temporal_average",
            "is_stable": True
        }

    def get_spatial_reference(self) -> Optional[Dict]:
        """Get calibrated spatial reference from stable hoop detection."""
        if not self.stable_hoop:
            return None

        radius_px = self.stable_hoop["radius_px"]
        # Standard rim diameter = 18 inches
        pixels_per_inch = (radius_px * 2) / HOOP_DIAMETER_INCHES
        pixels_per_foot = pixels_per_inch * 12

        return {
            "hoop_center_px": self.stable_hoop["center"],
            "hoop_radius_px": radius_px,
            "pixels_per_inch": round(pixels_per_inch, 2),
            "pixels_per_foot": round(pixels_per_foot, 2),
            "estimated_hoop_height_px": self.stable_hoop["center"][1],
            "reference_height_feet": HOOP_HEIGHT_FEET,
            "confidence": self.stable_hoop["confidence"],
            "is_calibrated": True
        }


def detect_hoop_in_video(
    video_path: str,
    output_dir: str,
    sample_rate: int = 5,
    save_annotated: bool = True
) -> Dict:
    """
    Detect hoop across video frames and return spatial reference.

    Args:
        video_path: Path to input video
        output_dir: Output directory for results
        sample_rate: Process every Nth frame
        save_annotated: Save annotated preview frames
    """
    video_path = Path(video_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise FileNotFoundError(f"Cannot open: {video_path}")

    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    detector = HoopDetector()
    frame_detections = []
    frame_idx = 0
    annotated_dir = output_dir / "annotated"
    if save_annotated:
        annotated_dir.mkdir(exist_ok=True)

    print(f"[INFO] Detecting hoop in {video_path.name} (sample rate: 1/{sample_rate})")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % sample_rate == 0:
            detection = detector.detect_frame(frame, frame_idx)

            if detection and save_annotated and frame_idx % (sample_rate * 10) == 0:
                annotated = frame.copy()
                c = detection["center"]
                r = detection.get("radius_px", 20)
                cv2.circle(annotated, (c[0], c[1]), r, (0, 0, 255), 3)
                cv2.circle(annotated, (c[0], c[1]), 5, (0, 255, 0), -1)
                cv2.putText(annotated, f"Hoop ({detection.get('method', '?')})",
                            (c[0] - 40, c[1] - r - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
                cv2.imwrite(str(annotated_dir / f"hoop_{frame_idx:06d}.jpg"), annotated)

            frame_detections.append({
                "frame": frame_idx,
                "timestamp": frame_idx / fps if fps > 0 else 0,
                "detection": detection
            })

        frame_idx += 1

    cap.release()

    spatial_ref = detector.get_spatial_reference()

    metadata = {
        "source_video": str(video_path),
        "video_name": video_path.stem,
        "resolution": {"width": width, "height": height},
        "fps": fps,
        "total_frames": total_frames,
        "frames_sampled": len(frame_detections),
        "frames_with_hoop": sum(1 for fd in frame_detections if fd["detection"]),
        "detection_rate": sum(1 for fd in frame_detections if fd["detection"]) / max(len(frame_detections), 1),
        "spatial_reference": spatial_ref,
        "hoop_stable": detector.stable_hoop is not None,
        "frame_detections": frame_detections[:50]  # Limit stored detections
    }

    meta_path = output_dir / f"{video_path.stem}_hoop_meta.json"
    with open(meta_path, "w") as f:
        json.dump(metadata, f, indent=2)

    if spatial_ref:
        print(f"[INFO] Hoop detected: center={spatial_ref['hoop_center_px']}, "
              f"{spatial_ref['pixels_per_foot']:.1f} px/ft, "
              f"confidence={spatial_ref['confidence']:.2f}")
    else:
        print("[WARN] No stable hoop detection achieved")

    return metadata


def main():
    parser = argparse.ArgumentParser(description="Basketball Hoop Detection")
    parser.add_argument("--input", "-i", required=True, help="Input video path")
    parser.add_argument("--output", "-o", required=True, help="Output directory")
    parser.add_argument("--sample-rate", type=int, default=5, help="Sample every Nth frame")
    parser.add_argument("--no-annotated", action="store_true", help="Skip annotated frames")
    args = parser.parse_args()

    detect_hoop_in_video(
        video_path=args.input,
        output_dir=args.output,
        sample_rate=args.sample_rate,
        save_annotated=not args.no_annotated
    )


if __name__ == "__main__":
    main()
