#!/usr/bin/env python3
"""
sceneit_replay_validator.py — deterministic Who Scene It replay verification.

Replays exported match JSON (GET /api/sceneit/match/{id}/export-replay) and:
  1. Rebuilds the full question set from metadata.seed + round_types via the
     same RoundModules, verifying question order and correct_option_ids match
     what the server recorded at match time.
  2. Re-computes every buzz resolution (locked potential from buzz elapsed_ms,
     delta from correctness + lock-in window) with BuzzRiskScoring and checks
     each recorded delta and running score_snapshot.
  3. Verifies match_end score equals the replayed accumulation.
  4. Verifies event seq values are strictly increasing.

Exit code 0 = all replays reproduce exactly; non-zero = mismatch/corruption.

Usage:
    python3 backend/tools/sceneit_replay_validator.py artifacts/replays/sceneit_*.json
    python3 backend/tools/sceneit_replay_validator.py --dir artifacts/replays
"""
import argparse
import glob
import json
import os
import random
import sys
from typing import Any, Dict, List

_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _BACKEND_DIR not in sys.path:
    sys.path.insert(0, _BACKEND_DIR)

from lib.sceneit.content import get_default_provider  # noqa: E402
from lib.sceneit.rounds import get_round  # noqa: E402
from lib.sceneit.scoring import BuzzRiskScoring, ScoringConfig  # noqa: E402


def rebuild_questions(seed: int, round_types: List[str], count: int):
    """Mirror of SceneItMatch._build_questions — same seed, same questions."""
    content = get_default_provider()
    order_rng = random.Random(seed)
    scenes = sorted(content.scenes(), key=lambda s: s["scene_id"])
    order_rng.shuffle(scenes)
    questions = []
    for i in range(min(count, len(scenes))):
        module = get_round(round_types[i % len(round_types)])
        q_rng = random.Random((seed << 8) ^ (i * 0x9E3779B1) & 0xFFFFFFFFFFFFFFFF)
        questions.append(module.build_question(i, scenes[i], content, q_rng))
    return questions


def validate_replay(replay: Dict[str, Any]) -> List[str]:
    """Returns a list of human-readable mismatch descriptions (empty = OK)."""
    errors: List[str] = []
    meta = replay.get("metadata") or {}
    match_id = meta.get("match_id", "<unknown>")
    seed = meta.get("seed")
    events = replay.get("events", [])

    if seed is None:
        return [f"{match_id}: metadata.seed missing — replay not reproducible"]

    scoring = BuzzRiskScoring(ScoringConfig(**meta.get("scoring", {}).get("config", {})))

    # 1. Rebuild questions from seed; compare against recorded question_start events
    questions = rebuild_questions(seed, meta.get("round_types", ["invisibles"]),
                                  meta.get("question_count", 0))
    for ev in events:
        if ev.get("type") != "question_start":
            continue
        i = ev.get("question_index", -1)
        if i >= len(questions):
            errors.append(f"{match_id}: question_start index {i} out of rebuilt range")
            continue
        q = questions[i]
        if ev.get("question_id") != q.question_id:
            errors.append(f"{match_id} q{i}: question_id {ev.get('question_id')!r} "
                          f"!= rebuilt {q.question_id!r} (seed drift)")
        if ev.get("correct_option_id") != q.correct_option_id:
            errors.append(f"{match_id} q{i}: correct_option_id mismatch "
                          f"recorded={ev.get('correct_option_id')!r} rebuilt={q.correct_option_id!r}")

    # 2 + 3. Re-resolve every buzz/answer pair and re-accumulate scores
    accumulated: Dict[str, int] = {p: 0 for p in meta.get("players", [])}
    match_end = None
    for ev in events:
        if ev.get("type") == "answer":
            i = ev.get("question_index", -1)
            q = questions[i] if 0 <= i < len(questions) else None
            correct_pick = q is not None and ev.get("option_id") == q.correct_option_id
            res = scoring.resolve(ev["buzz_elapsed_ms"], ev.get("answer_elapsed_ms"), correct_pick)
            if res.potential != ev.get("potential"):
                errors.append(f"{match_id} seq={ev.get('seq')}: potential recorded="
                              f"{ev.get('potential')} recomputed={res.potential}")
            if res.delta != ev.get("delta"):
                errors.append(f"{match_id} seq={ev.get('seq')}: delta recorded="
                              f"{ev.get('delta')} recomputed={res.delta}")
            if res.correct != ev.get("correct"):
                errors.append(f"{match_id} seq={ev.get('seq')}: correctness recorded="
                              f"{ev.get('correct')} recomputed={res.correct}")
            pid = ev.get("player_id", "unknown")
            accumulated[pid] = accumulated.get(pid, 0) + res.delta
            snap = ev.get("score_snapshot", {})
            if snap.get(pid) is not None and snap[pid] != accumulated[pid]:
                errors.append(f"{match_id} seq={ev.get('seq')}: score_snapshot[{pid}]="
                              f"{snap[pid]} but accumulation gives {accumulated[pid]}")
        elif ev.get("type") == "match_end":
            match_end = ev
    if match_end is not None:
        final = match_end.get("score", {})
        for pid, pts in accumulated.items():
            if final.get(pid, 0) != pts:
                errors.append(f"{match_id}: match_end score[{pid}]={final.get(pid)} "
                              f"but replayed accumulation gives {pts}")

    # 4. seq strictly increasing
    seqs = [ev["seq"] for ev in events if "seq" in ev]
    if seqs != sorted(seqs) or len(set(seqs)) != len(seqs):
        errors.append(f"{match_id}: event seq values are not strictly ordered: {seqs}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate exported sceneit replays deterministically")
    parser.add_argument("files", nargs="*", help="Replay JSON files")
    parser.add_argument("--dir", default=None, help="Directory of sceneit replay JSON files")
    args = parser.parse_args()

    files = list(args.files)
    if args.dir:
        files += sorted(glob.glob(os.path.join(args.dir, "*.json")))
    if not files:
        print("No replay files given. Usage: sceneit_replay_validator.py <files...> | --dir <dir>")
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
            meta = replay.get("metadata", {})
            n = len(replay.get("events", []))
            print(f"[ OK ] {path} (match {meta.get('match_id')}, {n} events, seed {meta.get('seed')})")

    print(f"\n{len(files)} replay(s) checked, {total_errors} error(s).")
    return 0 if total_errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
