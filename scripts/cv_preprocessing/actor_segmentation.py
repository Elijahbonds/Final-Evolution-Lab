#!/usr/bin/env python3
"""
Actor Segmentation Module — Biomechanical Isolation Pipeline

Uses YOLOv11 (ultralytics) for person detection and optional SAM
(Segment Anything Model) for pixel-precise masks. The primary actor
(@elijahbonds) is identified via largest-bbox or center-frame heuristic
and tracked across frames with a simple IoU tracker.

Usage:
    python actor_segmentation.py --input video.mp4 --output masks/
    python actor_segmentation.py --input video.mp4 --output masks/ --use-sam
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Dict, Tuple, Optional

import cv2
import numpy as np

try:
    from ultralytics import YOLO
    HAS_YOLO = True
except ImportError:
    HAS_YOLO = False

try:
    from segment_anything import sam_model_registry, SamPredictor
    HAS_SAM = True
except ImportError:
    HAS_SAM = False


class IoUTracker:
    """Simple IoU-based single-object tracker across frames."""

    def __init__(self, iou_threshold: float = 0.3):
        self.iou_threshold = iou_threshold
        self.last_box: Optional[np.ndarray] = None
        self.frames_lost = 0
        self.max_lost = 10

    @staticmethod
    def _iou(box_a: np.ndarray, box_b: np.ndarray) -> float:
        x1 = max(box_a[0], box_b[0])
        y1 = max(box_a[1], box_b[1])
        x2 = min(box_a[2], box_b[2])
        y2 = min(box_a[3], box_b[3])
        inter = max(0, x2 - x1) * max(0, y2 - y1)
        area_a = (box_a[2] - box_a[0]) * (box_a[3] - box_a[1])
        area_b = (box_b[2] - box_b[0]) * (box_b[3] - box_b[1])
        union = area_a + area_b - inter
        return inter / union if union > 0 else 0.0

    def update(self, detections: List[np.ndarray]) -> Optional[int]:
        """Return index of best-matching detection, or None."""
        if not detections:
            self.frames_lost += 1
            return None

        if self.last_box is None:
            # First frame — pick largest detection (primary actor heuristic)
            areas = [(d[2] - d[0]) * (d[3] - d[1]) for d in detections]
            best_idx = int(np.argmax(areas))
            self.last_box = detections[best_idx]
            self.frames_lost = 0
            return best_idx

        ious = [self._iou(self.last_box, d) for d in detections]
        best_idx = int(np.argmax(ious))
        if ious[best_idx] >= self.iou_threshold:
            self.last_box = detections[best_idx]
            self.frames_lost = 0
            return best_idx

        # Fallback: pick closest center
        last_cx = (self.last_box[0] + self.last_box[2]) / 2
        last_cy = (self.last_box[1] + self.last_box[3]) / 2
        dists = []
        for d in detections:
            cx = (d[0] + d[2]) / 2
            cy = (d[1] + d[3]) / 2
            dists.append((cx - last_cx) ** 2 + (cy - last_cy) ** 2)
        best_idx = int(np.argmin(dists))
        self.last_box = detections[best_idx]
        self.frames_lost = 0
        return best_idx


def detect_persons_yolo(model, frame: np.ndarray, conf: float = 0.4) -> List[Dict]:
    """Run YOLOv11 person detection on a single frame."""
    results = model(frame, conf=conf, classes=[0], verbose=False)  # class 0 = person
    detections = []
    for r in results:
        for box in r.boxes:
            xyxy = box.xyxy[0].cpu().numpy()
            detections.append({
                "bbox": xyxy.tolist(),
                "confidence": float(box.conf[0]),
                "class": "person"
            })
    return detections


def get_sam_mask(predictor, frame: np.ndarray, bbox: List[float]) -> np.ndarray:
    """Get pixel-precise mask from SAM given a bounding box prompt."""
    predictor.set_image(frame)
    box_np = np.array(bbox)
    masks, scores, _ = predictor.predict(
        point_coords=None,
        point_labels=None,
        box=box_np[None, :],
        multimask_output=False
    )
    return masks[0]  # Binary mask H×W


def generate_bbox_mask(frame_shape: Tuple[int, int], bbox: List[float],
                       padding: float = 0.05) -> np.ndarray:
    """Generate a rectangular mask from bounding box with padding."""
    h, w = frame_shape[:2]
    x1, y1, x2, y2 = bbox
    pad_x = (x2 - x1) * padding
    pad_y = (y2 - y1) * padding
    x1 = max(0, int(x1 - pad_x))
    y1 = max(0, int(y1 - pad_y))
    x2 = min(w, int(x2 + pad_x))
    y2 = min(h, int(y2 + pad_y))
    mask = np.zeros((h, w), dtype=np.uint8)
    mask[y1:y2, x1:x2] = 255
    return mask


def segment_video(
    video_path: str,
    output_dir: str,
    use_sam: bool = False,
    yolo_model: str = "yolo11n.pt",
    sam_checkpoint: str = "sam_vit_h_4b8939.pth",
    sam_model_type: str = "vit_h",
    confidence: float = 0.4,
    save_preview: bool = True
) -> Dict:
    """
    Segment the primary actor from a video.

    Returns metadata dict with per-frame detection info.
    """
    video_path = Path(video_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if not HAS_YOLO:
        print("[WARN] ultralytics not installed — using OpenCV fallback")
        return _fallback_segmentation(video_path, output_dir)

    # Load models
    print(f"[INFO] Loading YOLOv11 model: {yolo_model}")
    model = YOLO(yolo_model)

    sam_predictor = None
    if use_sam and HAS_SAM:
        print(f"[INFO] Loading SAM model: {sam_model_type}")
        sam = sam_model_registry[sam_model_type](checkpoint=sam_checkpoint)
        sam_predictor = SamPredictor(sam)

    # Open video
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise FileNotFoundError(f"Cannot open video: {video_path}")

    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # Output paths
    masks_dir = output_dir / "masks"
    masks_dir.mkdir(exist_ok=True)

    tracker = IoUTracker(iou_threshold=0.3)
    frame_metadata = []
    frame_idx = 0

    # Preview video writer
    preview_writer = None
    if save_preview:
        preview_path = output_dir / f"{video_path.stem}_segmented_preview.mp4"
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        preview_writer = cv2.VideoWriter(str(preview_path), fourcc, fps, (width, height))

    print(f"[INFO] Processing {total_frames} frames from {video_path.name}")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Detect persons
        detections = detect_persons_yolo(model, frame, conf=confidence)
        bboxes = [np.array(d["bbox"]) for d in detections]

        # Track primary actor
        primary_idx = tracker.update(bboxes)

        mask = np.zeros((height, width), dtype=np.uint8)
        primary_det = None

        if primary_idx is not None and primary_idx < len(detections):
            primary_det = detections[primary_idx]
            bbox = primary_det["bbox"]

            if sam_predictor is not None:
                mask = get_sam_mask(sam_predictor, frame, bbox).astype(np.uint8) * 255
            else:
                mask = generate_bbox_mask((height, width), bbox, padding=0.08)

        # Save mask
        mask_path = masks_dir / f"mask_{frame_idx:06d}.png"
        cv2.imwrite(str(mask_path), mask)

        # Preview: overlay mask
        if preview_writer is not None:
            overlay = frame.copy()
            overlay[mask == 0] = (overlay[mask == 0] * 0.3).astype(np.uint8)
            if primary_det:
                b = [int(x) for x in primary_det["bbox"]]
                cv2.rectangle(overlay, (b[0], b[1]), (b[2], b[3]), (0, 255, 0), 2)
                cv2.putText(overlay, f"Primary Actor ({primary_det['confidence']:.2f})",
                            (b[0], b[1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            preview_writer.write(overlay)

        # Metadata
        frame_metadata.append({
            "frame": frame_idx,
            "timestamp": frame_idx / fps if fps > 0 else 0,
            "num_persons_detected": len(detections),
            "primary_actor": {
                "bbox": primary_det["bbox"] if primary_det else None,
                "confidence": primary_det["confidence"] if primary_det else 0,
                "tracked": primary_idx is not None
            },
            "all_detections": detections
        })

        frame_idx += 1
        if frame_idx % 100 == 0:
            print(f"  Frame {frame_idx}/{total_frames}")

    cap.release()
    if preview_writer:
        preview_writer.release()

    # Summary metadata
    metadata = {
        "source_video": str(video_path),
        "video_name": video_path.stem,
        "resolution": {"width": width, "height": height},
        "fps": fps,
        "total_frames": total_frames,
        "frames_processed": frame_idx,
        "detection_method": "YOLOv11" + ("+SAM" if sam_predictor else "+BBox"),
        "tracking_method": "IoU",
        "avg_confidence": float(np.mean([
            fm["primary_actor"]["confidence"] for fm in frame_metadata
            if fm["primary_actor"]["confidence"] > 0
        ])) if frame_metadata else 0,
        "frames_with_detection": sum(
            1 for fm in frame_metadata if fm["primary_actor"]["tracked"]
        ),
        "detection_rate": sum(
            1 for fm in frame_metadata if fm["primary_actor"]["tracked"]
        ) / max(frame_idx, 1),
        "frame_data": frame_metadata
    }

    meta_path = output_dir / f"{video_path.stem}_segmentation_meta.json"
    with open(meta_path, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"[INFO] Segmentation complete: {frame_idx} frames, "
          f"detection rate: {metadata['detection_rate']:.1%}")

    return metadata


def _fallback_segmentation(video_path: Path, output_dir: Path) -> Dict:
    """OpenCV-only fallback using background subtraction."""
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise FileNotFoundError(f"Cannot open: {video_path}")

    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    masks_dir = output_dir / "masks"
    masks_dir.mkdir(exist_ok=True)

    bg_sub = cv2.createBackgroundSubtractorMOG2(
        history=500, varThreshold=50, detectShadows=True
    )
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))

    frame_metadata = []
    frame_idx = 0

    print(f"[INFO] Fallback segmentation (MOG2) for {video_path.name}")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        fg_mask = bg_sub.apply(frame)
        # Remove shadows (value 127) and noise
        _, fg_mask = cv2.threshold(fg_mask, 200, 255, cv2.THRESH_BINARY)
        fg_mask = cv2.morphologyEx(fg_mask, cv2.MORPH_CLOSE, kernel, iterations=2)
        fg_mask = cv2.morphologyEx(fg_mask, cv2.MORPH_OPEN, kernel, iterations=1)

        # Find largest contour as primary actor
        contours, _ = cv2.findContours(fg_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        mask = np.zeros((height, width), dtype=np.uint8)
        bbox = None
        if contours:
            largest = max(contours, key=cv2.contourArea)
            if cv2.contourArea(largest) > 500:
                cv2.drawContours(mask, [largest], -1, 255, -1)
                x, y, w_b, h_b = cv2.boundingRect(largest)
                bbox = [x, y, x + w_b, y + h_b]

        mask_path = masks_dir / f"mask_{frame_idx:06d}.png"
        cv2.imwrite(str(mask_path), mask)

        frame_metadata.append({
            "frame": frame_idx,
            "timestamp": frame_idx / fps if fps > 0 else 0,
            "num_persons_detected": 1 if bbox else 0,
            "primary_actor": {
                "bbox": bbox,
                "confidence": 0.5 if bbox else 0,
                "tracked": bbox is not None
            },
            "all_detections": [{"bbox": bbox, "confidence": 0.5, "class": "person"}] if bbox else []
        })

        frame_idx += 1
        if frame_idx % 100 == 0:
            print(f"  Frame {frame_idx}/{total_frames}")

    cap.release()

    metadata = {
        "source_video": str(video_path),
        "video_name": video_path.stem,
        "resolution": {"width": width, "height": height},
        "fps": fps,
        "total_frames": total_frames,
        "frames_processed": frame_idx,
        "detection_method": "OpenCV_MOG2_Fallback",
        "tracking_method": "LargestContour",
        "avg_confidence": 0.5,
        "frames_with_detection": sum(
            1 for fm in frame_metadata if fm["primary_actor"]["tracked"]
        ),
        "detection_rate": sum(
            1 for fm in frame_metadata if fm["primary_actor"]["tracked"]
        ) / max(frame_idx, 1),
        "frame_data": frame_metadata
    }

    meta_path = output_dir / f"{video_path.stem}_segmentation_meta.json"
    with open(meta_path, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"[INFO] Fallback segmentation complete: {frame_idx} frames")
    return metadata


def main():
    parser = argparse.ArgumentParser(description="Actor Segmentation for Biomechanical Isolation")
    parser.add_argument("--input", "-i", required=True, help="Input video path")
    parser.add_argument("--output", "-o", required=True, help="Output directory")
    parser.add_argument("--use-sam", action="store_true", help="Use SAM for pixel-precise masks")
    parser.add_argument("--yolo-model", default="yolo11n.pt", help="YOLO model weight file")
    parser.add_argument("--confidence", type=float, default=0.4, help="Detection confidence threshold")
    parser.add_argument("--no-preview", action="store_true", help="Skip preview video")
    args = parser.parse_args()

    segment_video(
        video_path=args.input,
        output_dir=args.output,
        use_sam=args.use_sam,
        yolo_model=args.yolo_model,
        confidence=args.confidence,
        save_preview=not args.no_preview
    )


if __name__ == "__main__":
    main()
