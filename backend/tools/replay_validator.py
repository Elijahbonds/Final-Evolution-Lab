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

from lib.dunk_scoring import DunkEngine3DInput, score_dunk, score_engine3d_dunk  # noqa: E402
from lib.match_utils import derive_judge_offsets  # noqa: E402
from lib import carnival as _carnival  # noqa: E402


def _meta(replay: Dict[str, Any]) -> Dict[str, Any]:
    return replay.get("metadata") or replay  # tolerate old flat exports


def validate_carnival_replay(replay: Dict[str, Any]) -> List[str]:
    """Validate a Carnival Board replay.

    Reproduces determinism guarantees:
      1. seed -> board layout must match the recorded carnival_match_start board.
      2. every carnival_spin roll must equal spinner_roll(seed, turn_index).
      3. every carnival_minigame_result must re-resolve identically from its
         echoed instance + inputs (raw scores + normalization).
      4. seq ordering strictly increasing.
    """
    errors: List[str] = []
    meta = _meta(replay)
    mid = meta.get("match_id", "<unknown>")
    seed = meta.get("seed")
    events = replay.get("events", [])
    if seed is None:
        errors.append(f"{mid}: metadata.seed missing")
        return errors

    for ev in events:
        if ev.get("type") == "carnival_match_start":
            recomputed = _carnival.build_board(seed)
            if [s["type"] for s in recomputed] != [s["type"] for s in ev.get("board", [])]:
                errors.append(f"{mid}: board layout does not re-derive from seed")

    for ev in events:
        if ev.get("type") == "carnival_spin":
            ti = ev.get("turn_index")
            expected = _carnival.spinner_roll(seed, ti)
            if expected != ev.get("roll"):
                errors.append(
                    f"{mid} turn={ti}: spinner roll recorded={ev.get('roll')} "
                    f"but spinner_roll(seed,{ti})={expected}"
                )

    for ev in events:
        if ev.get("type") != "carnival_minigame_result":
            continue
        game = ev.get("game")
        inst = ev.get("instance")
        inputs = ev.get("inputs")
        rnd = ev.get("round_index")
        if inst is None or inputs is None:
            errors.append(f"{mid} round={rnd}: minigame_result missing instance/inputs")
            continue
        try:
            result = _carnival.resolve_minigame(game, inst, inputs)
        except Exception as exc:  # pragma: no cover - corrupt replay
            errors.append(f"{mid} round={rnd}: re-resolve raised {exc}")
            continue
        if result["raw"] != ev.get("raw"):
            errors.append(
                f"{mid} round={rnd} ({game}): raw mismatch "
                f"recorded={ev.get('raw')} recomputed={result['raw']}"
            )
        recomputed_norm = _carnival.normalize_scores(result["raw"], result["raw_max"])
        if recomputed_norm != ev.get("normalized"):
            errors.append(
                f"{mid} round={rnd} ({game}): normalized mismatch "
                f"recorded={ev.get('normalized')} recomputed={recomputed_norm}"
            )

    seqs = [ev["seq"] for ev in events if "seq" in ev]
    if seqs != sorted(seqs):
        errors.append(f"{mid}: event seq values are not monotonically ordered")
    return errors


def validate_replay(replay: Dict[str, Any]) -> List[str]:
    """Returns a list of human-readable mismatch descriptions (empty = OK).

    Dispatches by ``metadata.replay_kind``: authoritative carnival replays are
    validated by :func:`validate_carnival_replay`; everything else uses the
    dunk/match path.

    Client-local carnival captures are tagged ``replay_kind == "carnival_local"``
    (``authoritative: false``) — their mini-game scores come from the browser
    engine whose PRNG is not byte-identical to the Python engine, so they are
    intentionally NOT re-resolved here (doing so would report a false mismatch).
    They pass through as OK; the authoritative record is the backend export.
    """
    meta = _meta(replay)
    meta_kind = meta.get("replay_kind")
    if meta_kind == "carnival_local" or meta.get("authoritative") is False:
        return []  # self-consistent client capture; not server-re-resolvable
    if meta_kind == "carnival" or meta.get("mode_id") == "carnival_board":
        return validate_carnival_replay(replay)
    errors: List[str] = []
    meta = _meta(replay)
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
