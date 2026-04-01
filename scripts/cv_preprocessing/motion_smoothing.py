#!/usr/bin/env python3
"""
Motion Smoothing Module — Biomechanical Isolation Pipeline

Applies Kalman filtering and additional smoothing to tracking data
to reduce jitter and noise in motion capture output. Works on both
raw bbox tracking data and joint-level motion capture coordinates.

Smoothing techniques:
  1. Kalman filter (primary) — predictive smoothing
  2. Savitzky-Golay filter — polynomial smoothing
  3. Exponential moving average — simple temporal smoothing
  4. Median filter — outlier rejection

Usage:
    python motion_smoothing.py --input tracking_data.json --output smoothed/
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np

try:
    from scipy.signal import savgol_filter, medfilt
    from scipy.interpolate import interp1d
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False


class KalmanFilter2D:
    """
    2D Kalman filter for smooth position tracking.

    State: [x, y, vx, vy]
    Measurement: [x, y]
    """

    def __init__(self, process_noise: float = 1e-3, measurement_noise: float = 1e-1):
        # State transition (constant velocity model)
        self.F = np.array([
            [1, 0, 1, 0],
            [0, 1, 0, 1],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ], dtype=np.float64)

        # Measurement matrix
        self.H = np.array([
            [1, 0, 0, 0],
            [0, 1, 0, 0]
        ], dtype=np.float64)

        # Process noise
        self.Q = np.eye(4, dtype=np.float64) * process_noise
        self.Q[2, 2] *= 10  # Higher noise for velocity
        self.Q[3, 3] *= 10

        # Measurement noise
        self.R = np.eye(2, dtype=np.float64) * measurement_noise

        # State estimate and covariance
        self.x = np.zeros(4, dtype=np.float64)
        self.P = np.eye(4, dtype=np.float64) * 100
        self.initialized = False

    def predict(self) -> np.ndarray:
        """Predict next state."""
        self.x = self.F @ self.x
        self.P = self.F @ self.P @ self.F.T + self.Q
        return self.x[:2].copy()

    def update(self, measurement: np.ndarray) -> np.ndarray:
        """Update state with new measurement."""
        if not self.initialized:
            self.x[:2] = measurement
            self.initialized = True
            return measurement.copy()

        # Predict
        self.predict()

        # Update
        y = measurement - self.H @ self.x  # Innovation
        S = self.H @ self.P @ self.H.T + self.R  # Innovation covariance
        K = self.P @ self.H.T @ np.linalg.inv(S)  # Kalman gain

        self.x = self.x + K @ y
        self.P = (np.eye(4) - K @ self.H) @ self.P

        return self.x[:2].copy()

    def get_velocity(self) -> np.ndarray:
        return self.x[2:4].copy()


class JointKalmanSmoother:
    """
    Applies Kalman filtering to all joints in a skeleton.
    """

    def __init__(self, num_joints: int = 25, process_noise: float = 1e-3,
                 measurement_noise: float = 5e-2):
        self.filters = [
            KalmanFilter2D(process_noise, measurement_noise)
            for _ in range(num_joints)
        ]
        self.num_joints = num_joints

    def smooth_frame(
        self, joints: List[Tuple[float, float]]
    ) -> List[Tuple[float, float]]:
        """Smooth one frame of joint positions."""
        smoothed = []
        for i, (x, y) in enumerate(joints):
            if i < self.num_joints:
                pos = self.filters[i].update(np.array([x, y]))
                smoothed.append((float(pos[0]), float(pos[1])))
            else:
                smoothed.append((x, y))
        return smoothed


def kalman_smooth_trajectory(
    positions: List[List[float]],
    process_noise: float = 1e-3,
    measurement_noise: float = 1e-1
) -> List[List[float]]:
    """Apply Kalman filter to a sequence of 2D positions."""
    kf = KalmanFilter2D(process_noise, measurement_noise)
    smoothed = []
    for pos in positions:
        if pos is None or (isinstance(pos, list) and len(pos) < 2):
            smoothed.append(pos)
            continue
        result = kf.update(np.array(pos[:2], dtype=np.float64))
        smoothed.append(result.tolist())
    return smoothed


def savgol_smooth_trajectory(
    positions: List[List[float]],
    window_length: int = 11,
    polyorder: int = 3
) -> List[List[float]]:
    """Apply Savitzky-Golay filter to trajectory."""
    if not HAS_SCIPY:
        print("[WARN] scipy not available, skipping Savitzky-Golay smoothing")
        return positions

    valid_positions = [(i, p) for i, p in enumerate(positions) if p is not None and len(p) >= 2]
    if len(valid_positions) < window_length:
        return positions

    indices, coords = zip(*valid_positions)
    coords = np.array(coords)

    # Ensure odd window length
    wl = min(window_length, len(coords))
    if wl % 2 == 0:
        wl -= 1
    if wl < polyorder + 1:
        return positions

    smoothed_x = savgol_filter(coords[:, 0], wl, polyorder)
    smoothed_y = savgol_filter(coords[:, 1], wl, polyorder)

    result = list(positions)  # Copy
    for idx, sx, sy in zip(indices, smoothed_x, smoothed_y):
        result[idx] = [float(sx), float(sy)]
    return result


def ema_smooth_trajectory(
    positions: List[List[float]],
    alpha: float = 0.3
) -> List[List[float]]:
    """Apply exponential moving average to trajectory."""
    smoothed = []
    prev = None
    for pos in positions:
        if pos is None or len(pos) < 2:
            smoothed.append(pos)
            continue
        if prev is None:
            prev = list(pos)
            smoothed.append(list(pos))
        else:
            sx = alpha * pos[0] + (1 - alpha) * prev[0]
            sy = alpha * pos[1] + (1 - alpha) * prev[1]
            prev = [sx, sy]
            smoothed.append([sx, sy])
    return smoothed


def smooth_tracking_data(
    tracking_data: Dict,
    method: str = "kalman",
    params: Optional[Dict] = None
) -> Dict:
    """
    Smooth all tracked trajectories in the data.

    Args:
        tracking_data: Dict with 'frame_data' containing per-frame tracking
        method: 'kalman', 'savgol', 'ema', or 'combined'
        params: Method-specific parameters
    """
    if params is None:
        params = {}

    frame_data = tracking_data.get("frame_data", [])
    if not frame_data:
        return tracking_data

    # Extract primary actor positions
    positions = []
    for fd in frame_data:
        actor = fd.get("primary_actor", {})
        bbox = actor.get("bbox")
        if bbox and len(bbox) >= 4:
            cx = (bbox[0] + bbox[2]) / 2
            cy = (bbox[1] + bbox[3]) / 2
            positions.append([cx, cy])
        else:
            positions.append(None)

    # Apply smoothing
    if method == "kalman":
        smoothed = kalman_smooth_trajectory(
            positions,
            process_noise=params.get("process_noise", 1e-3),
            measurement_noise=params.get("measurement_noise", 1e-1)
        )
    elif method == "savgol":
        smoothed = savgol_smooth_trajectory(
            positions,
            window_length=params.get("window_length", 11),
            polyorder=params.get("polyorder", 3)
        )
    elif method == "ema":
        smoothed = ema_smooth_trajectory(
            positions,
            alpha=params.get("alpha", 0.3)
        )
    elif method == "combined":
        # Kalman first, then Savitzky-Golay for fine smoothing
        smoothed = kalman_smooth_trajectory(positions)
        smoothed = savgol_smooth_trajectory(smoothed, window_length=7, polyorder=2)
    else:
        smoothed = positions

    # Compute smoothing quality metrics
    orig_valid = [p for p in positions if p is not None]
    smooth_valid = [p for p in smoothed if p is not None and len(p) >= 2]

    jitter_original = _compute_jitter(orig_valid)
    jitter_smoothed = _compute_jitter(smooth_valid)

    # Write back smoothed positions
    result = dict(tracking_data)
    result["frame_data"] = list(frame_data)  # Copy
    for i, (fd, sp) in enumerate(zip(result["frame_data"], smoothed)):
        fd = dict(fd)
        fd["smoothed_position"] = sp
        result["frame_data"][i] = fd

    result["smoothing"] = {
        "method": method,
        "params": params,
        "jitter_original": jitter_original,
        "jitter_smoothed": jitter_smoothed,
        "jitter_reduction": (
            (jitter_original - jitter_smoothed) / max(jitter_original, 1e-6)
        ) if jitter_original > 0 else 0,
        "total_frames": len(positions),
        "valid_frames": len(orig_valid)
    }

    return result


def _compute_jitter(positions: List[List[float]]) -> float:
    """Compute average frame-to-frame displacement (jitter metric)."""
    if len(positions) < 2:
        return 0.0
    diffs = []
    for i in range(1, len(positions)):
        if positions[i] and positions[i - 1]:
            dx = positions[i][0] - positions[i - 1][0]
            dy = positions[i][1] - positions[i - 1][1]
            diffs.append(np.sqrt(dx ** 2 + dy ** 2))
    return float(np.mean(diffs)) if diffs else 0.0


def smooth_segmentation_metadata(
    meta_path: str,
    output_dir: str,
    method: str = "kalman"
) -> Dict:
    """
    Load segmentation metadata, apply smoothing, and save.
    """
    meta_path = Path(meta_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(meta_path) as f:
        data = json.load(f)

    smoothed = smooth_tracking_data(data, method=method)

    out_path = output_dir / f"{meta_path.stem}_smoothed.json"
    with open(out_path, "w") as f:
        json.dump(smoothed, f, indent=2)

    sm = smoothed.get("smoothing", {})
    print(f"[INFO] Smoothing ({method}): jitter {sm.get('jitter_original', 0):.2f} → "
          f"{sm.get('jitter_smoothed', 0):.2f} "
          f"({sm.get('jitter_reduction', 0):.1%} reduction)")

    return smoothed


def main():
    parser = argparse.ArgumentParser(description="Motion Smoothing for Tracking Data")
    parser.add_argument("--input", "-i", required=True, help="Input metadata JSON")
    parser.add_argument("--output", "-o", required=True, help="Output directory")
    parser.add_argument("--method", default="kalman",
                        choices=["kalman", "savgol", "ema", "combined"])
    args = parser.parse_args()

    smooth_segmentation_metadata(args.input, args.output, method=args.method)


if __name__ == "__main__":
    main()
