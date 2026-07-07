"""
match_utils.py — Deterministic seed & judge-offset generation for Nexus matches.
"""
import os
import random

def generate_seed() -> int:
    """Generate a 64-bit integer seed from os.urandom (non-repeating, unpredictable)."""
    return int.from_bytes(os.urandom(8), "big")

def derive_judge_offsets(seed: int, count: int = 3, lo: int = -5, hi: int = 5) -> list[int]:
    """Deterministically derive `count` integer offsets from `seed`."""
    rng = random.Random(seed)
    return [rng.randint(lo, hi) for _ in range(count)]
