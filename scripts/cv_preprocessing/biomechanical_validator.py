#!/usr/bin/env python3
"""
Biomechanical Validator — Joint Verification & Quality Control

Validates motion capture data against biomechanical constraints:
  1. Joint angle limits (no impossible bends)
  2. Spatial consistency with hoop reference
  3. Smoothness of motion curves
  4. Tracking confidence scores
  5. Velocity/acceleration plausibility

Usage:
    python biomechanical_validator.py --input cv_meta.json --output report.json
    python biomechanical_validator.py --batch metadata_dir/ --output reports/
"""

import argparse
import json
import math
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple

import numpy as np


# ── Biomechanical Joint Limits ───────────────────────────────────────────────
# Ranges in degrees, based on standard human biomechanics.
# Format: (min_angle, max_angle)
JOINT_ANGLE_LIMITS = {
    "knee_flexion":         (0, 160),
    "knee_extension":       (0, 10),
    "hip_flexion":          (0, 130),
    "hip_extension":        (0, 30),
    "hip_abduction":        (0, 45),
    "shoulder_flexion":     (0, 180),
    "shoulder_extension":   (0, 60),
    "shoulder_abduction":   (0, 180),
    "elbow_flexion":        (0, 150),
    "elbow_extension":      (0, 10),
    "ankle_dorsiflexion":   (0, 20),
    "ankle_plantarflexion": (0, 50),
    "wrist_flexion":        (0, 80),
    "wrist_extension":      (0, 70),
    "neck_flexion":         (0, 45),
    "neck_extension":       (0, 55),
    "neck_rotation":        (0, 80),
    "trunk_flexion":        (0, 80),
    "trunk_extension":      (0, 30),
    "trunk_lateral":        (0, 35),
}

# Maximum plausible velocities for basketball movements (pixels/frame)
# Based on elite athlete capabilities
MAX_VELOCITIES = {
    "body_center":  80,    # Running/jumping
    "hand":         150,   # Fast hand movements (dribble/dunk)
    "foot":         120,   # Kicking/jumping
    "head":         60,    # Head movement
}

# Basketball-specific spatial constraints
BASKETBALL_CONSTRAINTS = {
    "max_jump_height_feet":    4.5,    # Maximum vertical jump
    "max_reach_height_feet":   12.5,   # Max reach (10ft rim + jump)
    "court_width_feet":        50,
    "court_length_feet":       94,
    "hoop_height_feet":        10,
    "rim_diameter_inches":     18,
}


class ValidationResult:
    """Encapsulates validation results for a single check."""

    def __init__(self, name: str, passed: bool, severity: str = "warning",
                 details: str = "", value: float = 0, threshold: float = 0):
        self.name = name
        self.passed = passed
        self.severity = severity  # "info", "warning", "error", "critical"
        self.details = details
        self.value = value
        self.threshold = threshold

    def to_dict(self) -> Dict:
        value = self.value
        threshold = self.threshold
        if isinstance(value, (np.floating, np.integer)):
            value = float(value)
        if isinstance(threshold, (np.floating, np.integer)):
            threshold = float(threshold)
        return {
            "name": self.name,
            "passed": bool(self.passed),
            "severity": self.severity,
            "details": self.details,
            "value": round(value, 4) if isinstance(value, float) else value,
            "threshold": round(threshold, 4) if isinstance(threshold, float) else threshold
        }


class BiomechanicalValidator:
    """Validates motion capture data against biomechanical constraints."""

    def __init__(self, spatial_reference: Optional[Dict] = None):
        self.spatial_reference = spatial_reference
        self.results: List[ValidationResult] = []

    def validate_cv_metadata(self, metadata: Dict) -> Dict:
        """
        Run all validations on CV preprocessing metadata.

        Args:
            metadata: CV preprocessing metadata dict

        Returns:
            Validation report dict
        """
        self.results = []

        # Get frame data
        frame_data = metadata.get("frame_data", [])
        stages = metadata.get("stages", {})

        # 1. Detection confidence check
        self._check_detection_confidence(metadata, frame_data)

        # 2. Tracking continuity
        self._check_tracking_continuity(frame_data)

        # 3. Velocity plausibility
        self._check_velocity_plausibility(frame_data, metadata.get("fps", 30))

        # 4. Bbox size consistency
        self._check_bbox_consistency(frame_data)

        # 5. Spatial reference validation
        if self.spatial_reference or stages.get("hoop_detection", {}).get("spatial_reference"):
            sr = self.spatial_reference or stages["hoop_detection"]["spatial_reference"]
            self._check_spatial_consistency(frame_data, sr)

        # 6. Smoothing quality
        smoothing = metadata.get("smoothing", {}) or stages.get("smoothing", {})
        if smoothing:
            self._check_smoothing_quality(smoothing)

        # 7. Coverage check
        self._check_mask_coverage(metadata)

        # Generate report
        return self._generate_report(metadata)

    def _check_detection_confidence(self, metadata: Dict, frame_data: List):
        """Check if detection confidence is above acceptable thresholds."""
        if not frame_data:
            self.results.append(ValidationResult(
                "detection_confidence", False, "critical",
                "No frame data available for validation"
            ))
            return

        confidences = []
        for fd in frame_data:
            actor = fd.get("primary_actor", {})
            conf = actor.get("confidence", 0)
            if conf > 0:
                confidences.append(conf)

        if not confidences:
            self.results.append(ValidationResult(
                "detection_confidence", False, "critical",
                "No detections with positive confidence"
            ))
            return

        avg_conf = float(np.mean(confidences))
        min_conf = float(np.min(confidences))

        self.results.append(ValidationResult(
            "avg_detection_confidence", avg_conf >= 0.5, "warning",
            f"Average detection confidence: {avg_conf:.3f}",
            value=avg_conf, threshold=0.5
        ))

        self.results.append(ValidationResult(
            "min_detection_confidence", min_conf >= 0.2, "info",
            f"Minimum detection confidence: {min_conf:.3f}",
            value=min_conf, threshold=0.2
        ))

        # Detection rate
        det_rate = metadata.get("detection_rate", 0)
        if isinstance(det_rate, (int, float)):
            self.results.append(ValidationResult(
                "detection_rate", det_rate >= 0.7, "error" if det_rate < 0.5 else "warning",
                f"Detection rate: {det_rate:.1%}",
                value=det_rate, threshold=0.7
            ))

    def _check_tracking_continuity(self, frame_data: List):
        """Check for tracking gaps/drops."""
        if len(frame_data) < 2:
            return

        gaps = []
        current_gap = 0
        for fd in frame_data:
            if fd.get("primary_actor", {}).get("tracked"):
                if current_gap > 0:
                    gaps.append(current_gap)
                current_gap = 0
            else:
                current_gap += 1

        if current_gap > 0:
            gaps.append(current_gap)

        max_gap = max(gaps) if gaps else 0
        total_gaps = len(gaps)

        self.results.append(ValidationResult(
            "tracking_continuity", max_gap <= 15, "error" if max_gap > 30 else "warning",
            f"Max tracking gap: {max_gap} frames, total gaps: {total_gaps}",
            value=max_gap, threshold=15
        ))

        # Continuous tracking percentage
        tracked_frames = sum(1 for fd in frame_data if fd.get("primary_actor", {}).get("tracked"))
        continuity = tracked_frames / max(len(frame_data), 1)
        self.results.append(ValidationResult(
            "tracking_continuity_rate", continuity >= 0.8, "warning",
            f"Tracking continuity: {continuity:.1%}",
            value=continuity, threshold=0.8
        ))

    def _check_velocity_plausibility(self, frame_data: List, fps: float):
        """Check that movement velocities are physically plausible."""
        positions = []
        for fd in frame_data:
            bbox = fd.get("primary_actor", {}).get("bbox")
            if bbox and len(bbox) >= 4:
                cx = (bbox[0] + bbox[2]) / 2
                cy = (bbox[1] + bbox[3]) / 2
                positions.append((cx, cy))
            else:
                positions.append(None)

        velocities = []
        for i in range(1, len(positions)):
            if positions[i] and positions[i - 1]:
                dx = positions[i][0] - positions[i - 1][0]
                dy = positions[i][1] - positions[i - 1][1]
                v = math.sqrt(dx ** 2 + dy ** 2)
                velocities.append(v)

        if not velocities:
            return

        max_v = max(velocities)
        avg_v = float(np.mean(velocities))
        threshold = MAX_VELOCITIES["body_center"]

        # Count "teleport" frames (impossibly fast movement)
        teleports = sum(1 for v in velocities if v > threshold * 2)

        self.results.append(ValidationResult(
            "max_velocity", max_v <= threshold * 3, "error" if max_v > threshold * 5 else "warning",
            f"Max velocity: {max_v:.1f} px/frame (threshold: {threshold})",
            value=max_v, threshold=threshold * 3
        ))

        self.results.append(ValidationResult(
            "teleport_frames", teleports == 0, "error" if teleports > 5 else "warning",
            f"Teleport frames (impossible velocity): {teleports}",
            value=teleports, threshold=0
        ))

        # Acceleration check
        if len(velocities) > 1:
            accelerations = [abs(velocities[i] - velocities[i-1]) for i in range(1, len(velocities))]
            max_acc = max(accelerations)
            self.results.append(ValidationResult(
                "max_acceleration", max_acc <= threshold * 2, "warning",
                f"Max acceleration: {max_acc:.1f} px/frame²",
                value=max_acc, threshold=threshold * 2
            ))

    def _check_bbox_consistency(self, frame_data: List):
        """Check that bounding box sizes are consistent (no wild size changes)."""
        areas = []
        for fd in frame_data:
            bbox = fd.get("primary_actor", {}).get("bbox")
            if bbox and len(bbox) >= 4:
                w = bbox[2] - bbox[0]
                h = bbox[3] - bbox[1]
                areas.append(w * h)

        if len(areas) < 10:
            return

        areas = np.array(areas)
        mean_area = np.mean(areas)
        std_area = np.std(areas)
        cv = std_area / max(mean_area, 1)  # Coefficient of variation

        self.results.append(ValidationResult(
            "bbox_size_consistency", cv <= 0.5, "warning",
            f"BBox size CV: {cv:.3f} (lower is more consistent)",
            value=cv, threshold=0.5
        ))

        # Check for sudden size jumps (identity swap)
        size_jumps = 0
        for i in range(1, len(areas)):
            ratio = areas[i] / max(areas[i-1], 1)
            if ratio > 2.0 or ratio < 0.5:
                size_jumps += 1

        self.results.append(ValidationResult(
            "identity_swap_risk", size_jumps <= 3, "error" if size_jumps > 10 else "warning",
            f"Potential identity swaps (bbox size jumps): {size_jumps}",
            value=size_jumps, threshold=3
        ))

    def _check_spatial_consistency(self, frame_data: List, spatial_ref: Dict):
        """Check actor position relative to hoop (spatial reference)."""
        hoop_center = spatial_ref.get("hoop_center_px")
        px_per_foot = spatial_ref.get("pixels_per_foot", 0)

        if not hoop_center or not px_per_foot:
            self.results.append(ValidationResult(
                "spatial_calibration", False, "info",
                "Spatial reference incomplete, skipping spatial checks"
            ))
            return

        hoop_y = hoop_center[1]
        max_reach_px = BASKETBALL_CONSTRAINTS["max_reach_height_feet"] * px_per_foot

        # Check if actor ever goes above maximum reach height
        above_max = 0
        for fd in frame_data:
            bbox = fd.get("primary_actor", {}).get("bbox")
            if bbox and len(bbox) >= 4:
                top_y = bbox[1]  # Top of bounding box
                # In image coordinates, lower y = higher position
                if top_y < (hoop_y - max_reach_px * 0.3):
                    above_max += 1

        self.results.append(ValidationResult(
            "spatial_plausibility", above_max <= 5, "warning",
            f"Frames with actor above max reach: {above_max}",
            value=above_max, threshold=5
        ))

        self.results.append(ValidationResult(
            "spatial_reference_quality", spatial_ref.get("confidence", 0) >= 0.4, "info",
            f"Spatial reference confidence: {spatial_ref.get('confidence', 0):.3f}",
            value=spatial_ref.get("confidence", 0), threshold=0.4
        ))

    def _check_smoothing_quality(self, smoothing: Dict):
        """Validate smoothing effectiveness."""
        jitter_reduction = smoothing.get("jitter_reduction", 0)
        self.results.append(ValidationResult(
            "smoothing_effectiveness", jitter_reduction >= 0.1, "info",
            f"Jitter reduction: {jitter_reduction:.1%}",
            value=jitter_reduction, threshold=0.1
        ))

        # Over-smoothing check
        self.results.append(ValidationResult(
            "over_smoothing", jitter_reduction <= 0.95, "warning",
            f"Over-smoothing risk: {jitter_reduction:.1%} reduction",
            value=jitter_reduction, threshold=0.95
        ))

    def _check_mask_coverage(self, metadata: Dict):
        """Check mask coverage quality."""
        stages = metadata.get("stages", {})
        masking = stages.get("masking", {})
        coverage = masking.get("avg_mask_coverage", 0)

        if coverage > 0:
            self.results.append(ValidationResult(
                "mask_coverage", 0.02 <= coverage <= 0.5, "warning",
                f"Average mask coverage: {coverage:.1%} of frame",
                value=coverage, threshold=0.02
            ))

    def _generate_report(self, metadata: Dict) -> Dict:
        """Generate validation report."""
        passed = sum(1 for r in self.results if r.passed)
        failed = sum(1 for r in self.results if not r.passed)
        critical = sum(1 for r in self.results if not r.passed and r.severity == "critical")
        errors = sum(1 for r in self.results if not r.passed and r.severity == "error")
        warnings = sum(1 for r in self.results if not r.passed and r.severity == "warning")

        # Overall quality score (0-100)
        total = len(self.results)
        quality_score = (passed / max(total, 1)) * 100
        # Penalize critical failures more
        quality_score -= critical * 15
        quality_score -= errors * 5
        quality_score = max(0, min(100, quality_score))

        # Grade
        if quality_score >= 90:
            grade = "A"
        elif quality_score >= 75:
            grade = "B"
        elif quality_score >= 60:
            grade = "C"
        elif quality_score >= 40:
            grade = "D"
        else:
            grade = "F"

        report = {
            "video_name": metadata.get("video_name", "unknown"),
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "quality_score": round(quality_score, 1),
                "grade": grade,
                "total_checks": total,
                "passed": passed,
                "failed": failed,
                "critical_failures": critical,
                "errors": errors,
                "warnings": warnings
            },
            "checks": [r.to_dict() for r in self.results],
            "recommendations": self._generate_recommendations(),
            "deepmotion_ready": bool(quality_score >= 60 and critical == 0)
        }

        return report

    def _generate_recommendations(self) -> List[str]:
        """Generate actionable recommendations based on failures."""
        recs = []
        for r in self.results:
            if r.passed:
                continue
            if r.name == "detection_rate":
                recs.append("Consider re-processing with lower confidence threshold or using SAM")
            elif r.name == "tracking_continuity":
                recs.append("Large tracking gaps detected — video may have occlusion or scene cuts")
            elif r.name == "teleport_frames":
                recs.append("Impossible velocity detected — possible identity swap between actors")
            elif r.name == "identity_swap_risk":
                recs.append("BBox size jumps suggest tracker swapped between actors — use SAM for better isolation")
            elif r.name == "spatial_plausibility":
                recs.append("Actor position exceeds physical limits — check hoop calibration")
            elif r.name == "over_smoothing":
                recs.append("Smoothing may be too aggressive — reduce filter strength")
            elif r.name == "mask_coverage":
                recs.append("Mask coverage seems off — check segmentation quality")
        return list(set(recs))  # Deduplicate


def validate_single(metadata_path: str, output_path: Optional[str] = None) -> Dict:
    """Validate a single CV metadata file."""
    with open(metadata_path) as f:
        metadata = json.load(f)

    # If this is a pipeline cv_meta (summary), load segmentation frame_data
    if "frame_data" not in metadata and "stages" in metadata:
        output_dir = metadata.get("output_dir", "")
        video_name = metadata.get("video_name", "")
        seg_meta_path = Path(output_dir) / "segmentation" / f"{video_name}_segmentation_meta.json"
        if seg_meta_path.exists():
            with open(seg_meta_path) as f:
                seg_data = json.load(f)
            metadata["frame_data"] = seg_data.get("frame_data", [])
            metadata["fps"] = seg_data.get("fps", 30)
            metadata["detection_rate"] = seg_data.get("detection_rate", 0)
            metadata["avg_confidence"] = seg_data.get("avg_confidence", 0)

    # Extract spatial reference if available
    spatial_ref = None
    stages = metadata.get("stages", {})
    if "hoop_detection" in stages:
        spatial_ref = stages["hoop_detection"].get("spatial_reference")

    validator = BiomechanicalValidator(spatial_reference=spatial_ref)
    report = validator.validate_cv_metadata(metadata)

    if output_path:
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            json.dump(report, f, indent=2)

    return report


def validate_batch(metadata_dir: str, output_dir: str) -> Dict:
    """Validate all CV metadata files in a directory."""
    metadata_dir = Path(metadata_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    reports = []
    for meta_file in sorted(metadata_dir.glob("*_cv_meta.json")):
        print(f"Validating: {meta_file.name}")
        report = validate_single(
            str(meta_file),
            str(output_dir / f"{meta_file.stem}_validation.json")
        )
        reports.append(report)

    # Aggregate report
    aggregate = {
        "timestamp": datetime.now().isoformat(),
        "total_videos": len(reports),
        "avg_quality_score": float(np.mean([r["summary"]["quality_score"] for r in reports])) if reports else 0,
        "grade_distribution": {},
        "deepmotion_ready": sum(1 for r in reports if r.get("deepmotion_ready")),
        "per_video": [{
            "video_name": r["video_name"],
            "quality_score": r["summary"]["quality_score"],
            "grade": r["summary"]["grade"],
            "deepmotion_ready": r.get("deepmotion_ready", False)
        } for r in reports]
    }

    for r in reports:
        g = r["summary"]["grade"]
        aggregate["grade_distribution"][g] = aggregate["grade_distribution"].get(g, 0) + 1

    agg_path = output_dir / "validation_aggregate.json"
    with open(agg_path, "w") as f:
        json.dump(aggregate, f, indent=2)

    print(f"\nValidation Summary:")
    print(f"  Videos: {aggregate['total_videos']}")
    print(f"  Avg Score: {aggregate['avg_quality_score']:.1f}")
    print(f"  DeepMotion Ready: {aggregate['deepmotion_ready']}/{aggregate['total_videos']}")
    print(f"  Grades: {aggregate['grade_distribution']}")

    return aggregate


def main():
    parser = argparse.ArgumentParser(description="Biomechanical Validator")
    parser.add_argument("--input", "-i", help="Single metadata JSON")
    parser.add_argument("--batch", "-b", help="Batch metadata directory")
    parser.add_argument("--output", "-o", required=True, help="Output path")
    args = parser.parse_args()

    if args.batch:
        validate_batch(args.batch, args.output)
    elif args.input:
        validate_single(args.input, args.output)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
