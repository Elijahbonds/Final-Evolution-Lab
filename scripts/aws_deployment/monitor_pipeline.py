#!/usr/bin/env python3
"""
Pipeline Monitor — Real-time build monitoring with alerts

Monitors the FEL pipeline execution on local or remote GPU instance,
providing real-time status updates, ETA calculations, and alerts.

Usage:
    python monitor_pipeline.py                     # Local monitoring
    python monitor_pipeline.py --remote 54.1.2.3   # Remote GPU monitoring
    python monitor_pipeline.py --dashboard          # Continuous dashboard mode
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Optional


class PipelineMonitor:
    """Monitors FEL pipeline execution and provides status updates."""

    PIPELINE_STAGES = [
        {"name": "CV Preprocessing", "key": "cv_preprocessing", "weight": 15,
         "indicator_file": "logs/cv_preprocessing_report.json"},
        {"name": "Biomechanical Validation", "key": "validation", "weight": 5,
         "indicator_file": "logs/validation_aggregate.json"},
        {"name": "UE5 Installation", "key": "ue5_install", "weight": 25,
         "indicator_file": ".ue5_env"},
        {"name": "Asset Import", "key": "asset_import", "weight": 10,
         "indicator_file": "GeneratedAssets/pipeline_report.json"},
        {"name": "Linux Server Cook", "key": "linux_cook", "weight": 25,
         "indicator_file": "Builds/LinuxServer/FinalEvolutionLab"},
        {"name": "iOS Cook", "key": "ios_cook", "weight": 15,
         "indicator_file": "Builds/iOS/FinalEvolutionLab.ipa"},
        {"name": "iOS App Build", "key": "ios_build", "weight": 5,
         "indicator_file": "Builds/iOS/ExportOptions_AppStore.plist"},
    ]

    def __init__(self, project_root: str = None, remote_host: str = None,
                 ssh_key: str = None):
        self.project_root = Path(project_root or "/home/ubuntu/rork-final-evolution-lab")
        self.remote_host = remote_host
        self.ssh_key = ssh_key or str(Path.home() / ".ssh/fel-gpu-key.pem")
        self.start_time = None

    def _check_file(self, rel_path: str) -> bool:
        """Check if a file exists (locally or remotely)."""
        if self.remote_host:
            try:
                cmd = f"ssh -i {self.ssh_key} -o ConnectTimeout=5 ubuntu@{self.remote_host} 'test -f {self.project_root}/{rel_path} && echo YES || echo NO'"
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
                return "YES" in result.stdout
            except Exception:
                return False
        else:
            return (self.project_root / rel_path).exists()

    def _read_json(self, rel_path: str) -> Optional[Dict]:
        """Read JSON file locally or remotely."""
        if self.remote_host:
            try:
                cmd = f"ssh -i {self.ssh_key} ubuntu@{self.remote_host} 'cat {self.project_root}/{rel_path}'"
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
                return json.loads(result.stdout) if result.returncode == 0 else None
            except Exception:
                return None
        else:
            path = self.project_root / rel_path
            if path.exists():
                return json.loads(path.read_text())
            return None

    def get_status(self) -> Dict:
        """Get current pipeline status."""
        status = {
            "timestamp": datetime.now().isoformat(),
            "host": self.remote_host or "local",
            "stages": [],
            "overall_progress": 0
        }

        total_weight = sum(s["weight"] for s in self.PIPELINE_STAGES)
        completed_weight = 0

        for stage in self.PIPELINE_STAGES:
            completed = self._check_file(stage["indicator_file"])
            stage_status = {
                "name": stage["name"],
                "key": stage["key"],
                "completed": completed,
                "weight": stage["weight"]
            }

            # Get extra details for specific stages
            if completed and stage["key"] == "cv_preprocessing":
                report = self._read_json(stage["indicator_file"])
                if report:
                    summary = report.get("summary", {})
                    stage_status["details"] = {
                        "videos_processed": summary.get("total_videos", 0),
                        "successful": summary.get("successful", 0),
                        "detection_rate": summary.get("avg_detection_rate", 0)
                    }

            if completed:
                completed_weight += stage["weight"]

            status["stages"].append(stage_status)

        status["overall_progress"] = round(completed_weight / total_weight * 100, 1)

        # Estimate remaining time
        if self.start_time and 0 < status["overall_progress"] < 100:
            elapsed = (datetime.now() - self.start_time).total_seconds()
            rate = status["overall_progress"] / elapsed
            remaining = (100 - status["overall_progress"]) / rate
            status["eta_minutes"] = round(remaining / 60, 1)
            status["eta_completion"] = (
                datetime.now() + timedelta(seconds=remaining)
            ).strftime("%H:%M:%S")

        return status

    def print_dashboard(self, status: Dict):
        """Print formatted dashboard."""
        # Clear screen in dashboard mode
        print("\033[2J\033[H", end="")

        print("\n" + "=" * 60)
        print("  FINAL EVOLUTION LAB — Pipeline Monitor")
        print(f"  {status['timestamp']}  |  Host: {status['host']}")
        print("=" * 60)

        progress = status["overall_progress"]
        bar_width = 40
        filled = int(bar_width * progress / 100)
        bar = "█" * filled + "░" * (bar_width - filled)
        print(f"\n  Progress: [{bar}] {progress:.1f}%")

        if "eta_minutes" in status:
            print(f"  ETA: ~{status['eta_minutes']:.0f} min (at {status['eta_completion']})")

        print("\n  Stages:")
        for stage in status["stages"]:
            icon = "✅" if stage["completed"] else "⏳"
            details = ""
            if "details" in stage:
                d = stage["details"]
                details = f" ({d.get('videos_processed', '')} videos, {d.get('detection_rate', 0):.0%} det)"
            print(f"    {icon} {stage['name']}{details}")

        print("\n" + "=" * 60)

    def run_dashboard(self, interval: int = 30):
        """Run continuous monitoring dashboard."""
        self.start_time = datetime.now()
        print(f"Starting pipeline monitor (refresh every {interval}s)...")
        print("Press Ctrl+C to stop.\n")

        try:
            while True:
                status = self.get_status()
                self.print_dashboard(status)

                if status["overall_progress"] >= 100:
                    print("\n  🎉 PIPELINE COMPLETE!")
                    self._send_alert("FEL Pipeline Complete!",
                                     "All build stages finished successfully.")
                    break

                time.sleep(interval)
        except KeyboardInterrupt:
            print("\nMonitor stopped.")

    def _send_alert(self, title: str, message: str):
        """Send completion alert (extensible: email, Slack, etc)."""
        alert = {
            "title": title,
            "message": message,
            "timestamp": datetime.now().isoformat(),
            "host": self.remote_host or "local"
        }

        # Save alert log
        alert_path = self.project_root / "logs" / "pipeline_alerts.json"
        alerts = []
        if alert_path.exists():
            try:
                alerts = json.loads(alert_path.read_text())
            except Exception:
                pass
        alerts.append(alert)
        alert_path.parent.mkdir(parents=True, exist_ok=True)
        alert_path.write_text(json.dumps(alerts, indent=2))

        print(f"\n  🔔 ALERT: {title}")
        print(f"     {message}")


def main():
    parser = argparse.ArgumentParser(description="FEL Pipeline Monitor")
    parser.add_argument("--remote", help="Remote GPU instance IP")
    parser.add_argument("--ssh-key", help="SSH key path")
    parser.add_argument("--project-root", help="Project root path")
    parser.add_argument("--dashboard", action="store_true", help="Continuous dashboard")
    parser.add_argument("--interval", type=int, default=30, help="Dashboard refresh interval")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    args = parser.parse_args()

    monitor = PipelineMonitor(
        project_root=args.project_root,
        remote_host=args.remote,
        ssh_key=args.ssh_key
    )

    if args.dashboard:
        monitor.run_dashboard(interval=args.interval)
    else:
        status = monitor.get_status()
        if args.json:
            print(json.dumps(status, indent=2))
        else:
            monitor.print_dashboard(status)


if __name__ == "__main__":
    main()
