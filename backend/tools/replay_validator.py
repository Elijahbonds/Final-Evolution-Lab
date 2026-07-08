#!/usr/bin/env python3
"""
replay_validator.py — Deterministic replay verification (Agent 4).

Replays exported match JSON (from GET /api/matches/{id}/export-replay) and
re-computes every server-scored dunk from the raw inputs echoed in each
`dunk_result` event, using the seed/judge_offsets in the replay metadata.
Also re-derives judge_offsets from the seed and re-accumulates score_events
to verify the recorded final score.

Exit code 0 = all replays reproduce exactly; non-zero = mismatch/corruption.

Usage:
    python3 backend/tools/replay_validator.py artifacts/replays/replay_*.json
    python3 backend/tools/replay_validator.py --dir artifacts/replays
"""
import argparse
import glob
import json
import os
import sys
from typing import Any, Dict, List

_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _BACKEND_DIR not in sys.path:
    sys.path.insert(0, _BACKEND_DIR)

from lib.brainbrawl import is_brainbrawl_replay, validate_brainbrawl_replay  # noqa: E402
from lib.dunk_scoring import DunkEngine3DInput, score_dunk, score_engine3d_dunk  # noqa: E402
from lib.match_utils import derive_judge_offsets  # noqa: E402


def _meta(replay: Dict[str, Any]) -> Dict[str, Any]:
    return replay.get("metadata") or replay  # tolerate old flat exports


def validate_replay(replay: Dict[str, Any]) -> List[str]:
    """Returns a list of human-readable mismatch descriptions (empty = OK)."""
    errors: List[str] = []
    meta = _meta(replay)

    # Brain Brawl rounds (nexus/brainbrawl-demo): re-derive question order from
    # the seed and re-score every answer from its echoed original inputs.
    if is_brainbrawl_replay(meta):
        return validate_brainbrawl_replay(replay)
    match_id = meta.get("match_id", "<unknown>")
    seed = meta.get("seed")
    judge_offsets = meta.get("judge_offsets") or []
    events = replay.get("events", [])

    # 1. Seed -> judge_offsets must be re-derivable
    if seed is None:
        errors.append(f"{match_id}: metadata.seed missing")
    elif judge_offsets and derive_judge_offsets(seed) != list(judge_offsets):
        errors.append(
            f"{match_id}: judge_offsets {judge_offsets} do not match "
            f"derive_judge_offsets(seed)={derive_judge_offsets(seed)}"
        )

    # 2. Re-compute every dunk_result from its echoed inputs
    for ev in events:
        if ev.get("type") != "dunk_result":
            continue
        inputs = ev.get("inputs") or {}
        recorded = (ev.get("j1"), ev.get("j2"), ev.get("j3"), ev.get("total"), ev.get("message"))
        ev_offsets = ev.get("judge_offsets", judge_offsets)
        if "engine3d" in inputs:
            result = score_engine3d_dunk(DunkEngine3DInput(**inputs["engine3d"]), ev_offsets)
        elif "approach_quality" in inputs:
            result = score_dunk(
                approach_quality=max(0.0, min(1.0, inputs["approach_quality"])),
                execution_quality=max(0.0, min(1.0, inputs["execution_quality"])),
                style_difficulty=max(0.0, min(1.0, inputs.get("style_difficulty", 0.5))),
                judge_offsets=ev_offsets,
            )
        else:
            errors.append(f"{match_id} seq={ev.get('seq')}: dunk_result has no replayable inputs")
            continue
        recomputed = (result.j1, result.j2, result.j3, result.total, result.message)
        if recomputed != recorded:
            errors.append(
                f"{match_id} seq={ev.get('seq')}: dunk mismatch "
                f"recorded={recorded} recomputed={recomputed}"
            )

    # 3. Re-accumulate score_events and compare with final match_end score
    accumulated: Dict[str, int] = {}
    match_end = None
    for ev in events:
        if ev.get("type") == "score_event":
            pid = ev.get("player_id") or "unknown"
            accumulated[pid] = accumulated.get(pid, 0) + int(ev.get("points", 0))
            snap = ev.get("score_snapshot")
            if snap is not None and snap.get(pid) is not None and snap[pid] != accumulated[pid]:
                errors.append(
                    f"{match_id} seq={ev.get('seq')}: score_snapshot[{pid}]={snap[pid]} "
                    f"but accumulation gives {accumulated[pid]}"
                )
        elif ev.get("type") == "match_end":
            match_end = ev
    if match_end is not None:
        final = match_end.get("score", {})
        for pid, pts in accumulated.items():
            if final.get(pid, 0) != pts:
                errors.append(
                    f"{match_id}: match_end score[{pid}]={final.get(pid)} "
                    f"but replayed accumulation gives {pts}"
                )

    # 4. seq ordering must be strictly increasing
    seqs = [ev["seq"] for ev in events if "seq" in ev]
    if seqs != sorted(seqs):
        errors.append(f"{match_id}: event seq values are not monotonically ordered: {seqs}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate exported match replays deterministically")
    parser.add_argument("files", nargs="*", help="Replay JSON files")
    parser.add_argument("--dir", default=None, help="Directory of replay_*.json files")
    args = parser.parse_args()

    files = list(args.files)
    if args.dir:
        files += sorted(glob.glob(os.path.join(args.dir, "*.json")))
    if not files:
        print("No replay files given. Usage: replay_validator.py <files...> | --dir <dir>")
        return 2

    total_errors = 0
    for path in files:
        try:
            with open(path) as f:
                replay = json.load(f)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"[FAIL] {path}: unreadable ({exc})")
            total_errors += 1
            continue
        errors = validate_replay(replay)
        if errors:
            total_errors += len(errors)
            print(f"[FAIL] {path}")
            for e in errors:
                print(f"       - {e}")
        else:
            meta = _meta(replay)
            n = len(replay.get("events", []))
            print(f"[ OK ] {path} (match {meta.get('match_id')}, {n} events, seed {meta.get('seed')})")

    print(f"\n{len(files)} replay(s) checked, {total_errors} error(s).")
    return 0 if total_errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
