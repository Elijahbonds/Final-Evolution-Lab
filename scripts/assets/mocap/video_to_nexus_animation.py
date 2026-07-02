#!/usr/bin/env python3
"""Video → NexusAnimationAsset via local MediaPipe Pose (no accounts/APIs).

The local mocap lane of the dunk pipeline: feed ANY video — AI-generated
(Runway/Pika), filmed dunks, screen recordings — and get a rig-mapped keyframe
asset the app plays. Includes denoising (Savitzky-Golay), visibility gap-fill,
and hip translation with a grounded jump arc.

Usage:
  python3 video_to_nexus_animation.py in.mp4 out.json --id dunk_tomahawk_v1 \
      --title "Tomahawk" --category dunk [--fps-cap 30]
  python3 video_to_nexus_animation.py --selftest   # no video needed

Requires: pip install mediapipe opencv-python numpy scipy
"""
import argparse
import json
import math
import sys
from datetime import datetime, timezone

import numpy as np
from scipy.signal import savgol_filter

# MediaPipe Pose landmark indices (33-point topology)
LM = {
    "nose": 0, "l_shoulder": 11, "r_shoulder": 12, "l_elbow": 13, "r_elbow": 14,
    "l_hip": 23, "r_hip": 24, "l_knee": 25, "r_knee": 26, "l_ankle": 27, "r_ankle": 28,
}

# rig joint → (from landmark(s), to landmark(s), rest direction in rig space)
DOWN, UP = (0.0, -1.0, 0.0), (0.0, 1.0, 0.0)
BONES = {
    "torso": (("l_hip", "r_hip"), ("l_shoulder", "r_shoulder"), UP),
    "head": (("l_shoulder", "r_shoulder"), ("nose",), UP),
    "lArm": (("l_shoulder",), ("l_elbow",), DOWN),
    "rArm": (("r_shoulder",), ("r_elbow",), DOWN),
    "lLeg": (("l_hip",), ("l_knee",), DOWN),
    "rLeg": (("r_hip",), ("r_knee",), DOWN),
    "lShin": (("l_knee",), ("l_ankle",), DOWN),
    "rShin": (("r_knee",), ("r_ankle",), DOWN),
}


def shortest_arc_quat(d0, d1):
    """Quaternion rotating unit vector d0 onto d1 (x,y,z,w)."""
    d0, d1 = np.asarray(d0, float), np.asarray(d1, float)
    n0, n1 = np.linalg.norm(d0), np.linalg.norm(d1)
    if n0 < 1e-8 or n1 < 1e-8:
        return (0.0, 0.0, 0.0, 1.0)
    d0, d1 = d0 / n0, d1 / n1
    c = float(np.dot(d0, d1))
    if c > 1 - 1e-9:
        return (0.0, 0.0, 0.0, 1.0)
    if c < -1 + 1e-9:  # opposite: rotate 180° about any orthogonal axis
        axis = np.cross(d0, (1.0, 0.0, 0.0))
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(d0, (0.0, 0.0, 1.0))
        axis /= np.linalg.norm(axis)
        return (float(axis[0]), float(axis[1]), float(axis[2]), 0.0)
    axis = np.cross(d0, d1)
    s = math.sqrt((1 + c) * 2)
    return (float(axis[0] / s), float(axis[1] / s), float(axis[2] / s), s / 2)


def mid(track, frame, names):
    pts = [track[frame, LM[n]] for n in names]
    return np.mean(pts, axis=0)


def clean_track(track, visibility, fps):
    """Gap-fill low-visibility samples (linear) then Savitzky-Golay smooth."""
    frames, lms, _ = track.shape
    for j in range(lms):
        bad = visibility[:, j] < 0.5
        if bad.all():
            continue
        good_idx = np.where(~bad)[0]
        for axis in range(3):
            track[:, j, axis] = np.interp(np.arange(frames), good_idx,
                                          track[good_idx, j, axis])
    window = max(5, int(fps * 0.2) | 1)  # ~200ms, odd
    if frames > window:
        track = savgol_filter(track, window, 3, axis=0)
    return track


def track_to_asset(track, visibility, fps, meta):
    """(frames, 33, 3) world-landmark track → NexusAnimationAsset dict.

    MediaPipe world coords: meters, Y DOWN. Rig space: Y up → negate Y.
    """
    track = np.asarray(track, float).copy()
    track[:, :, 1] *= -1.0
    track = clean_track(track, np.asarray(visibility, float), fps)

    frames = track.shape[0]
    ground = min(track[0, LM["l_ankle"], 1], track[0, LM["r_ankle"], 1])
    keyframes = []
    for f in range(frames):
        rot, off = {}, {}
        for joint, (frm, to, rest) in BONES.items():
            d = mid(track, f, to) - mid(track, f, frm)
            x, y, z, w = shortest_arc_quat(rest, d)
            rot[joint] = {"x": x, "y": y, "z": z, "w": w}
        # pelvis orientation about vertical from hip line
        hipvec = track[f, LM["r_hip"]] - track[f, LM["l_hip"]]
        x, y, z, w = shortest_arc_quat((1.0, 0.0, 0.0),
                                       (hipvec[0], 0.0, hipvec[2]))
        rot["hip"] = {"x": x, "y": y, "z": z, "w": w}
        pelvis = mid(track, f, ("l_hip", "r_hip"))
        ankle_now = min(track[f, LM["l_ankle"], 1], track[f, LM["r_ankle"], 1])
        off["hip"] = {"x": 0.0, "y": max(0.0, float(ankle_now - ground)), "z": 0.0}
        keyframes.append({"timestamp": round(f / fps, 5),
                          "jointRotations": rot,
                          "translationOffsets": off})
    duration = round(frames / fps, 4)
    return {
        "header": {
            "id": meta["id"], "title": meta["title"],
            "competitionName": meta.get("competition", ""),
            "category": meta.get("category", "dunk"),
            "creatorId": meta.get("creator", "video_mocap"),
            "captureTimestamp": datetime.now(timezone.utc).isoformat(),
            "frameRate": fps, "duration": duration,
            "jointCount": len(BONES) + 1,
        },
        "keyframes": keyframes,
    }


def extract_from_video(path, fps_cap):
    import cv2
    import mediapipe as mp
    pose = mp.solutions.pose.Pose(model_complexity=1, static_image_mode=False)
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        sys.exit(f"cannot open video: {path}")
    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    stride = max(1, round(src_fps / fps_cap))
    frames, vis = [], []
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if i % stride == 0:
            res = pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
            if res.pose_world_landmarks:
                lms = res.pose_world_landmarks.landmark
                frames.append([[l.x, l.y, l.z] for l in lms])
                vis.append([l.visibility for l in lms])
        i += 1
    cap.release()
    if len(frames) < 5:
        sys.exit("fewer than 5 frames with a detected person — not usable")
    return np.array(frames), np.array(vis), src_fps / stride


def synthetic_jump_track(frames=60, fps=30.0):
    """Synth landmark track: standing person doing a 0.5s-flight jump.
    MediaPipe convention: meters, Y DOWN."""
    base = np.zeros((frames, 33, 3))
    Y = {"nose": -1.55, "l_shoulder": -1.35, "r_shoulder": -1.35,
         "l_elbow": -1.05, "r_elbow": -1.05, "l_hip": -0.85, "r_hip": -0.85,
         "l_knee": -0.45, "r_knee": -0.45, "l_ankle": -0.05, "r_ankle": -0.05}
    X = {"nose": 0, "l_shoulder": -0.18, "r_shoulder": 0.18, "l_elbow": -0.25,
         "r_elbow": 0.25, "l_hip": -0.12, "r_hip": 0.12, "l_knee": -0.13,
         "r_knee": 0.13, "l_ankle": -0.13, "r_ankle": 0.13}
    t0, flight = 0.6, 0.5
    for f in range(frames):
        t = f / fps
        h = 0.0
        if t0 <= t <= t0 + flight:
            tt = t - t0
            v0 = 9.81 * flight / 2
            h = v0 * tt - 0.5 * 9.81 * tt * tt
        for name, idx in LM.items():
            base[f, idx] = (X[name], Y[name] - h, 0.0)
    return base, np.ones((frames, 33)), fps


def selftest():
    track, vis, fps = synthetic_jump_track()
    asset = track_to_asset(track, vis, fps,
                           {"id": "selftest_jump", "title": "Selftest"})
    kf = asset["keyframes"]
    assert len(kf) == 60, f"frames {len(kf)}"
    ts = [k["timestamp"] for k in kf]
    assert ts == sorted(ts), "timestamps not monotonic"
    apex = max(k["translationOffsets"]["hip"]["y"] for k in kf)
    expect = 9.81 * 0.5 * 0.5 / 8
    assert abs(apex - expect) < 0.12, f"apex {apex:.3f} vs {expect:.3f}"
    assert kf[0]["translationOffsets"]["hip"]["y"] < 0.02, "must start grounded"
    for k in (kf[0], kf[-1]):
        for q in k["jointRotations"].values():
            n = math.sqrt(q["x"]**2 + q["y"]**2 + q["z"]**2 + q["w"]**2)
            assert abs(n - 1.0) < 1e-6, "quaternion not normalized"
    joints = set(kf[0]["jointRotations"])
    assert joints == set(BONES) | {"hip"}, joints
    print(f"SELFTEST OK: 60 frames, apex {apex:.3f}m (expected ~{expect:.3f}m), "
          f"{len(joints)} rig joints, quats normalized")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video", nargs="?")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--id")
    ap.add_argument("--title", default="Video Motion")
    ap.add_argument("--category", default="dunk")
    ap.add_argument("--creator", default="video_mocap")
    ap.add_argument("--fps-cap", type=float, default=30.0)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        selftest()
        return
    if not (args.video and args.out and args.id):
        ap.error("video, out and --id required (or --selftest)")
    track, vis, fps = extract_from_video(args.video, args.fps_cap)
    asset = track_to_asset(track, vis, fps, vars(args))
    json.dump(asset, open(args.out, "w"), indent=1)
    print(f"OK {args.out}: {len(asset['keyframes'])} frames @ {fps:.1f}fps")


if __name__ == "__main__":
    main()
