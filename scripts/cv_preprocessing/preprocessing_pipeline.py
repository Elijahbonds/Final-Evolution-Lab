#!/usr/bin/env python3
"""
CV Preprocessing Pipeline Orchestrator — Biomechanical Isolation

Orchestrates the complete CV preprocessing workflow:
  1. Actor Segmentation (YOLOv11/SAM or fallback)
  2. Background Masking (silhouette/masked/greenscreen)
  3. Hoop Detection (spatial reference)
  4. Motion Smoothing (Kalman filter)
  5. Metadata Aggregation

Processes videos from SourceVideos/Instagram/ and outputs to
GeneratedAssets/CVPreprocessed/.

Usage:
    python preprocessing_pipeline.py --all
    python preprocessing_pipeline.py --video 01_dunk_session.mp4
    python preprocessing_pipeline.py --all --use-sam --method combined
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent))

from actor_segmentation import segment_video
from background_masking import create_masked_video
from hoop_detection import detect_hoop_in_video
from motion_smoothing import smooth_tracking_data


class PreprocessingPipeline:
    """Orchestrates the complete CV preprocessing workflow."""

    def __init__(
        self,
        project_root: Optional[str] = None,
        use_sam: bool = False,
        yolo_model: str = "yolo11n.pt",
        smoothing_method: str = "kalman",
        confidence: float = 0.4,
        hoop_sample_rate: int = 5
    ):
        self.project_root = Path(project_root or self._find_project_root())
        self.use_sam = use_sam
        self.yolo_model = yolo_model
        self.smoothing_method = smoothing_method
        self.confidence = confidence
        self.hoop_sample_rate = hoop_sample_rate

        # Directories
        self.source_dir = self.project_root / "SourceVideos" / "Instagram" / "basketball"
        self.output_root = self.project_root / "GeneratedAssets" / "CVPreprocessed"
        self.metadata_dir = self.output_root / "metadata"
        self.reports_dir = self.project_root / "logs"

        # Ensure directories
        self.output_root.mkdir(parents=True, exist_ok=True)
        self.metadata_dir.mkdir(parents=True, exist_ok=True)
        self.reports_dir.mkdir(parents=True, exist_ok=True)

        # Load video metadata
        self.video_metadata = self._load_video_metadata()

    def _find_project_root(self) -> Path:
        """Find project root by looking for known markers."""
        current = Path(__file__).resolve().parent
        for _ in range(5):
            if (current / "SourceVideos").exists() or (current / ".git").exists():
                return current
            current = current.parent
        return Path("/home/ubuntu/rork-final-evolution-lab")

    def _load_video_metadata(self) -> Dict:
        """Load video metadata from SourceVideos."""
        meta_path = self.project_root / "SourceVideos" / "Instagram" / "video_metadata.json"
        if meta_path.exists():
            with open(meta_path) as f:
                return json.load(f)
        return {"videos": []}

    def get_video_list(self) -> List[Path]:
        """Get sorted list of source videos."""
        if not self.source_dir.exists():
            print(f"[WARN] Source directory not found: {self.source_dir}")
            return []
        videos = sorted(self.source_dir.glob("*.mp4"))
        return videos

    def process_single_video(self, video_path: Path, video_idx: int = 0) -> Dict:
        """
        Run full preprocessing pipeline on a single video.

        Returns result dict with all stage outputs.
        """
        video_name = video_path.stem
        video_output = self.output_root / video_name
        video_output.mkdir(parents=True, exist_ok=True)

        result = {
            "video_name": video_name,
            "source_path": str(video_path),
            "output_dir": str(video_output),
            "stages": {},
            "status": "in_progress",
            "start_time": datetime.now().isoformat()
        }

        # Look up metadata for this video
        video_meta = None
        for vm in self.video_metadata.get("videos", []):
            if vm.get("filename") == video_path.name:
                video_meta = vm
                break

        print(f"\n{'='*60}")
        print(f"Processing: {video_name} ({video_idx + 1})")
        print(f"{'='*60}")

        # ── Stage 1: Actor Segmentation ──────────────────────────
        print("\n[STAGE 1/4] Actor Segmentation")
        stage_start = time.time()
        try:
            seg_output = video_output / "segmentation"
            seg_meta = segment_video(
                video_path=str(video_path),
                output_dir=str(seg_output),
                use_sam=self.use_sam,
                yolo_model=self.yolo_model,
                confidence=self.confidence,
                save_preview=True
            )
            result["stages"]["segmentation"] = {
                "status": "success",
                "detection_rate": seg_meta.get("detection_rate", 0),
                "avg_confidence": seg_meta.get("avg_confidence", 0),
                "method": seg_meta.get("detection_method", "unknown"),
                "duration_sec": round(time.time() - stage_start, 2)
            }
        except Exception as e:
            print(f"[ERROR] Segmentation failed: {e}")
            result["stages"]["segmentation"] = {
                "status": "failed", "error": str(e)
            }
            seg_output = None

        # ── Stage 2: Background Masking ──────────────────────────
        print("\n[STAGE 2/4] Background Masking")
        stage_start = time.time()
        try:
            masks_dir = video_output / "segmentation" / "masks"
            mask_output = video_output / "masked"
            if masks_dir.exists():
                mask_meta = create_masked_video(
                    video_path=str(video_path),
                    masks_dir=str(masks_dir),
                    output_dir=str(mask_output),
                    modes=["masked", "silhouette"],
                    feather_radius=3
                )
                result["stages"]["masking"] = {
                    "status": "success",
                    "avg_mask_coverage": mask_meta.get("avg_mask_coverage", 0),
                    "output_videos": mask_meta.get("output_videos", {}),
                    "duration_sec": round(time.time() - stage_start, 2)
                }
            else:
                result["stages"]["masking"] = {
                    "status": "skipped", "reason": "No masks from segmentation"
                }
        except Exception as e:
            print(f"[ERROR] Masking failed: {e}")
            result["stages"]["masking"] = {
                "status": "failed", "error": str(e)
            }

        # ── Stage 3: Hoop Detection ──────────────────────────────
        print("\n[STAGE 3/4] Hoop Detection")
        stage_start = time.time()
        try:
            hoop_output = video_output / "hoop"
            hoop_meta = detect_hoop_in_video(
                video_path=str(video_path),
                output_dir=str(hoop_output),
                sample_rate=self.hoop_sample_rate,
                save_annotated=True
            )
            spatial_ref = hoop_meta.get("spatial_reference")
            result["stages"]["hoop_detection"] = {
                "status": "success" if spatial_ref else "partial",
                "hoop_detected": spatial_ref is not None,
                "spatial_reference": spatial_ref,
                "detection_rate": hoop_meta.get("detection_rate", 0),
                "duration_sec": round(time.time() - stage_start, 2)
            }
        except Exception as e:
            print(f"[ERROR] Hoop detection failed: {e}")
            result["stages"]["hoop_detection"] = {
                "status": "failed", "error": str(e)
            }

        # ── Stage 4: Motion Smoothing ────────────────────────────
        print("\n[STAGE 4/4] Motion Smoothing")
        stage_start = time.time()
        try:
            seg_meta_path = video_output / "segmentation" / f"{video_name}_segmentation_meta.json"
            if seg_meta_path.exists():
                with open(seg_meta_path) as f:
                    seg_data = json.load(f)

                smoothed = smooth_tracking_data(
                    seg_data, method=self.smoothing_method
                )

                smooth_output = video_output / "smoothed"
                smooth_output.mkdir(parents=True, exist_ok=True)
                with open(smooth_output / f"{video_name}_smoothed.json", "w") as f:
                    json.dump(smoothed, f, indent=2)

                sm = smoothed.get("smoothing", {})
                result["stages"]["smoothing"] = {
                    "status": "success",
                    "method": self.smoothing_method,
                    "jitter_original": sm.get("jitter_original", 0),
                    "jitter_smoothed": sm.get("jitter_smoothed", 0),
                    "jitter_reduction": sm.get("jitter_reduction", 0),
                    "duration_sec": round(time.time() - stage_start, 2)
                }
            else:
                result["stages"]["smoothing"] = {
                    "status": "skipped", "reason": "No segmentation metadata"
                }
        except Exception as e:
            print(f"[ERROR] Smoothing failed: {e}")
            result["stages"]["smoothing"] = {
                "status": "failed", "error": str(e)
            }

        # ── Aggregate Metadata ───────────────────────────────────
        result["end_time"] = datetime.now().isoformat()
        result["status"] = self._compute_status(result)

        # Add video-specific metadata
        if video_meta:
            result["movements"] = video_meta.get("movements", [])
            result["deepmotion_priority"] = video_meta.get("deepmotion_priority", 0)
            result["suggested_game_modes"] = video_meta.get("suggested_game_modes", [])

        # DeepMotion recommendation
        result["deepmotion_recommendation"] = self._recommend_deepmotion_input(result)

        # Save individual metadata
        meta_path = self.metadata_dir / f"{video_name}_cv_meta.json"
        with open(meta_path, "w") as f:
            json.dump(result, f, indent=2)

        return result

    def _compute_status(self, result: Dict) -> str:
        """Determine overall processing status."""
        stages = result.get("stages", {})
        statuses = [s.get("status") for s in stages.values()]
        if all(s == "success" for s in statuses):
            return "success"
        elif any(s == "failed" for s in statuses):
            return "partial_failure"
        elif all(s in ("success", "partial") for s in statuses):
            return "success_with_warnings"
        return "unknown"

    def _recommend_deepmotion_input(self, result: Dict) -> Dict:
        """Recommend which video to send to DeepMotion."""
        stages = result.get("stages", {})
        seg = stages.get("segmentation", {})
        mask = stages.get("masking", {})

        # If masking succeeded, use masked video
        if mask.get("status") == "success":
            output_videos = mask.get("output_videos", {})
            if "masked" in output_videos:
                return {
                    "use_preprocessed": True,
                    "recommended_input": output_videos["masked"],
                    "reason": "Masked video removes environmental noise",
                    "detection_rate": seg.get("detection_rate", 0),
                    "confidence": seg.get("avg_confidence", 0)
                }

        # If segmentation had good detection rate, use original with metadata
        if seg.get("detection_rate", 0) > 0.8:
            return {
                "use_preprocessed": False,
                "recommended_input": result.get("source_path", ""),
                "reason": "Good detection but masking unavailable, use original",
                "detection_rate": seg.get("detection_rate", 0)
            }

        return {
            "use_preprocessed": False,
            "recommended_input": result.get("source_path", ""),
            "reason": "Insufficient preprocessing, use original",
            "detection_rate": seg.get("detection_rate", 0)
        }

    def process_all_videos(self) -> Dict:
        """
        Process all source videos through the pipeline.

        Returns aggregate report.
        """
        videos = self.get_video_list()
        if not videos:
            print("[ERROR] No videos found to process")
            return {"error": "No videos found"}

        print(f"\n{'#'*60}")
        print(f"# CV Preprocessing Pipeline — Biomechanical Isolation")
        print(f"# Videos: {len(videos)}")
        print(f"# Method: YOLOv11{'+SAM' if self.use_sam else '+BBox'}")
        print(f"# Smoothing: {self.smoothing_method}")
        print(f"{'#'*60}\n")

        pipeline_start = time.time()
        results = []

        for idx, video in enumerate(videos):
            result = self.process_single_video(video, idx)
            results.append(result)

        # Generate aggregate report
        report = self._generate_report(results, time.time() - pipeline_start)

        # Save report
        report_path = self.reports_dir / "cv_preprocessing_report.json"
        with open(report_path, "w") as f:
            json.dump(report, f, indent=2)

        # Print summary
        self._print_summary(report)

        return report

    def _generate_report(self, results: List[Dict], total_time: float) -> Dict:
        """Generate comprehensive pipeline report."""
        successful = [r for r in results if r["status"] in ("success", "success_with_warnings")]
        failed = [r for r in results if "failure" in r["status"]]

        # Aggregate metrics
        detection_rates = []
        jitter_reductions = []
        hoop_detected_count = 0

        for r in results:
            stages = r.get("stages", {})
            seg = stages.get("segmentation", {})
            if seg.get("detection_rate"):
                detection_rates.append(seg["detection_rate"])
            smooth = stages.get("smoothing", {})
            if smooth.get("jitter_reduction"):
                jitter_reductions.append(smooth["jitter_reduction"])
            hoop = stages.get("hoop_detection", {})
            if hoop.get("hoop_detected"):
                hoop_detected_count += 1

        report = {
            "pipeline": "CV Preprocessing — Biomechanical Isolation",
            "version": "1.0.0",
            "timestamp": datetime.now().isoformat(),
            "configuration": {
                "yolo_model": self.yolo_model,
                "use_sam": self.use_sam,
                "smoothing_method": self.smoothing_method,
                "confidence_threshold": self.confidence,
                "hoop_sample_rate": self.hoop_sample_rate
            },
            "summary": {
                "total_videos": len(results),
                "successful": len(successful),
                "failed": len(failed),
                "total_time_sec": round(total_time, 2),
                "avg_time_per_video_sec": round(total_time / max(len(results), 1), 2),
                "avg_detection_rate": round(float(np.mean(detection_rates)), 4) if detection_rates else 0,
                "avg_jitter_reduction": round(float(np.mean(jitter_reductions)), 4) if jitter_reductions else 0,
                "hoop_detected_count": hoop_detected_count,
                "hoop_detection_rate": hoop_detected_count / max(len(results), 1)
            },
            "per_video": [{
                "video_name": r["video_name"],
                "status": r["status"],
                "stages": r["stages"],
                "deepmotion_recommendation": r.get("deepmotion_recommendation", {}),
                "movements": r.get("movements", [])
            } for r in results],
            "quality_comparison": {
                "raw_vs_preprocessed": {
                    "noise_reduction": "Background actors and environmental elements removed",
                    "tracking_stability": f"{float(np.mean(jitter_reductions))*100:.1f}% jitter reduction" if jitter_reductions else "N/A",
                    "spatial_calibration": f"{hoop_detected_count}/{len(results)} videos have hoop reference",
                    "deepmotion_benefit": "Preprocessed videos reduce hallucination risk in multi-person scenes"
                }
            }
        }

        return report

    def _print_summary(self, report: Dict):
        """Print human-readable summary."""
        s = report["summary"]
        print(f"\n{'='*60}")
        print(f"CV PREPROCESSING PIPELINE — SUMMARY")
        print(f"{'='*60}")
        print(f"  Videos processed:    {s['total_videos']}")
        print(f"  Successful:          {s['successful']}")
        print(f"  Failed:              {s['failed']}")
        print(f"  Total time:          {s['total_time_sec']:.1f}s")
        print(f"  Avg detection rate:  {s['avg_detection_rate']:.1%}")
        print(f"  Avg jitter reduction:{s['avg_jitter_reduction']:.1%}")
        print(f"  Hoop detected:       {s['hoop_detected_count']}/{s['total_videos']}")
        print(f"{'='*60}")

        # Per-video status
        for pv in report["per_video"]:
            status_icon = "✅" if pv["status"] == "success" else "⚠️" if "warning" in pv["status"] else "❌"
            rec = pv.get("deepmotion_recommendation", {})
            use_pp = "→ preprocessed" if rec.get("use_preprocessed") else "→ original"
            print(f"  {status_icon} {pv['video_name']}: {pv['status']} {use_pp}")


def main():
    parser = argparse.ArgumentParser(
        description="CV Preprocessing Pipeline for Biomechanical Isolation"
    )
    parser.add_argument("--all", action="store_true", help="Process all videos")
    parser.add_argument("--video", "-v", help="Process specific video file")
    parser.add_argument("--project-root", help="Project root directory")
    parser.add_argument("--use-sam", action="store_true", help="Use SAM for segmentation")
    parser.add_argument("--yolo-model", default="yolo11n.pt", help="YOLO model")
    parser.add_argument("--method", default="kalman",
                        choices=["kalman", "savgol", "ema", "combined"],
                        help="Smoothing method")
    parser.add_argument("--confidence", type=float, default=0.4)
    parser.add_argument("--hoop-sample-rate", type=int, default=5)
    args = parser.parse_args()

    pipeline = PreprocessingPipeline(
        project_root=args.project_root,
        use_sam=args.use_sam,
        yolo_model=args.yolo_model,
        smoothing_method=args.method,
        confidence=args.confidence,
        hoop_sample_rate=args.hoop_sample_rate
    )

    if args.all:
        pipeline.process_all_videos()
    elif args.video:
        video_path = Path(args.video)
        if not video_path.is_absolute():
            video_path = pipeline.source_dir / video_path
        pipeline.process_single_video(video_path)
    else:
        parser.print_help()
        print("\nUse --all to process all videos or --video to process one.")


if __name__ == "__main__":
    main()
