"""
short_race.py — "Short Race" mini-game for Court Carnival (server-authoritative).

A 3-lane, endless-runner-style obstacle dodge. The player auto-runs forward
over a fixed number of steps; a deterministic-from-seed schedule places
obstacles (and optional coin pickups) on ``(lane, step)`` cells. The only
input is a lane change per step (``left`` / ``right`` / ``stay``), so the whole
round is replay-validatable from tick-stamped moves.

Determinism
-----------
Everything derives from ``seed`` via the SAME derivation used by the rest of
Court Carnival (:func:`lib.carnival._sub_seed` / :func:`lib.carnival._rng`);
there is no ``time`` / ``os.urandom`` / unseeded ``random`` anywhere in the
scoring path, so ``same seed + same inputs -> identical result`` in every
process.

Achievability guarantee
------------------------
Two invariants make a perfect score reachable by a single run:

  * no step ever has all 3 lanes blocked (there is always a safe lane), and
  * coins are placed ONLY on cells lying on a pre-computed obstacle-free
    "reference path" that obeys the ±1-lane-per-step movement limit.

So dodging every obstacle *and* collecting every coin is always possible, and
a perfect input reaches ``raw_max`` (normalizes to 100). See
:func:`_reference_path` for the path construction.

Resolve contract
----------------
:func:`resolve` returns ``{"raw": {pid: float}, "raw_max": float,
"detail": {pid: {...}}}`` exactly like the carnival core mini-games, so it
feeds :func:`lib.carnival.normalize_scores` unchanged.
"""
from __future__ import annotations

from typing import Any, Dict, List

from lib.carnival import _rng, _sub_seed

# ── Identity ─────────────────────────────────────────────────────────────────

GAME_ID = "short_race"

# ── Constants ────────────────────────────────────────────────────────────────

SR_LANES = 3                       # fixed 3-lane track
SR_STEPS = 60                      # forward steps the player auto-runs
SR_SPAWN_LANE = 1                  # start in the centre lane

SR_STEP_PTS = 10                   # points per step survived / cleared
SR_COIN_PTS = 25                   # points per coin collected
SR_CLEAR_BONUS = 200              # one-time bonus for a fully clean run (no hits)
SR_HIT_PENALTY = 5                # points lost per obstacle struck
SR_MAX_HITS = 8                    # too many hits => the run ends early

# Obstacle density: probability a given step spawns obstacles at all, and how
# many lanes they occupy when it does (capped at 2 so a safe lane always exists).
SR_OBSTACLE_CHANCE = 0.55
SR_COIN_CHANCE = 0.30             # chance a step drops a coin on the reference path

_MOVE_DELTA = {"left": -1, "right": 1, "stay": 0}


# ── Reference (guaranteed-safe) path ─────────────────────────────────────────

def _reference_path(seed: int) -> List[int]:
    """A seeded random walk of lanes, one per step, obeying the ±1 movement limit.

    Starts at :data:`SR_SPAWN_LANE` and each step shifts by at most one lane
    (clamped to ``0..SR_LANES-1``). This path is generated FIRST and obstacles
    are then placed only on *other* lanes (see :func:`_obstacle_schedule`), so
    the path is guaranteed obstacle-free AND reachable — the two properties a
    perfect run needs. Coins ride this path, making a raw_max run achievable.
    Depends only on ``seed`` so it is reproducible in build and in verification.
    """
    r = _rng(seed, GAME_ID, "path")
    lane = SR_SPAWN_LANE
    path = [lane]
    for _step in range(1, SR_STEPS):
        lane = max(0, min(SR_LANES - 1, lane + r.choice((-1, 0, 1))))
        path.append(lane)
    return path


def _obstacle_schedule(seed: int, path: List[int]) -> Dict[int, set]:
    """Seeded obstacle layout: ``{step: {lane, ...}}`` that always spares ``path``.

    Step 0 is always clear (spawn step). For each later step we roll whether
    obstacles appear and, if so, occupy 1 or 2 lanes chosen ONLY from the lanes
    the reference path does not occupy. Because ``path[step]`` is always left
    open, no step blocks all 3 lanes and the reference lane is always both safe
    and reachable — so a perfect run is always possible.
    """
    r = _rng(seed, GAME_ID, "obstacles")
    schedule: Dict[int, set] = {}
    for step in range(1, SR_STEPS):
        if r.random() >= SR_OBSTACLE_CHANCE:
            continue
        avoid = path[step]
        others = [l for l in range(SR_LANES) if l != avoid]   # 2 lanes
        count = r.randint(1, len(others))                     # 1 or 2, never 3
        lanes = r.sample(others, count)
        schedule[step] = set(lanes)
    return schedule


# ── Build ────────────────────────────────────────────────────────────────────

def build(seed: int) -> Dict[str, Any]:
    """Build the deterministic Short Race instance descriptor.

    Returns a fully seeded, JSON-friendly instance: the obstacle schedule, the
    coin schedule (placed only on a guaranteed-dodgeable reference path), the
    point constants, and the spawn lane.
    """
    path = _reference_path(seed)
    obstacles_by_step = _obstacle_schedule(seed, path)

    # Coins ride the reference path so a single perfect run can grab them all
    # while still dodging every obstacle. Never on the spawn step.
    r = _rng(seed, GAME_ID, "coins")
    coins: List[Dict[str, int]] = []
    for step in range(1, SR_STEPS):
        if r.random() < SR_COIN_CHANCE:
            coins.append({"step": step, "lane": path[step]})

    obstacles = [
        {"step": step, "lane": lane}
        for step in sorted(obstacles_by_step)
        for lane in sorted(obstacles_by_step[step])
    ]

    return {
        "game": GAME_ID,
        "seed": seed,
        "lanes": SR_LANES,
        "steps": SR_STEPS,
        "spawn_lane": SR_SPAWN_LANE,
        "obstacles": obstacles,
        "coins": coins,
        "step_pts": SR_STEP_PTS,
        "coin_pts": SR_COIN_PTS,
        "clear_bonus": SR_CLEAR_BONUS,
        "hit_penalty": SR_HIT_PENALTY,
        "max_hits": SR_MAX_HITS,
    }


def _raw_max(instance: Dict[str, Any]) -> float:
    """Theoretical maximum raw score for a seeded instance.

    All steps cleared cleanly + every coin collected + the clean-run bonus.
    A perfect run (dodge everything, grab every coin, zero hits) reaches this
    exactly, so it normalizes to 100.
    """
    steps = instance["steps"]
    n_coins = len(instance["coins"])
    return float(
        steps * instance["step_pts"]
        + n_coins * instance["coin_pts"]
        + instance["clear_bonus"]
    )


# ── Resolve ──────────────────────────────────────────────────────────────────

def resolve(
    instance: Dict[str, Any],
    inputs: Dict[str, List[Dict[str, Any]]],
) -> Dict[str, Any]:
    """Resolve a Short Race round from tick-stamped lane-change sequences.

    ``inputs`` maps ``player_id -> [{"tick": int, "move": "left|right|stay"}]``.
    Each player is simulated independently against the shared seeded track. At
    each step the player occupies a lane: an obstacle there is a hit
    (``-hit_penalty``, no step points), a coin there is ``+coin_pts``, an empty
    cell awards ``step_pts``. A clean run (zero hits) that reaches the finish
    earns ``clear_bonus``. Accumulating ``max_hits`` ends the run early.

    Tolerant by contract: missing/empty moves keep the player in the spawn
    lane, unknown move strings are treated as ``stay``, and out-of-range ticks
    are ignored.

    Returns ``{"raw": {pid: score}, "raw_max": float, "detail": {...}}``.
    """
    steps = instance["steps"]
    lanes = instance["lanes"]
    spawn = instance["spawn_lane"]
    step_pts = instance["step_pts"]
    coin_pts = instance["coin_pts"]
    clear_bonus = instance["clear_bonus"]
    hit_penalty = instance["hit_penalty"]
    max_hits = instance["max_hits"]

    obstacle_set = {(o["step"], o["lane"]) for o in instance["obstacles"]}
    coin_set = {(c["step"], c["lane"]) for c in instance["coins"]}
    raw_max = _raw_max(instance)

    raw: Dict[str, float] = {}
    detail: Dict[str, Any] = {}
    for pid, moves in inputs.items():
        # index tick-stamped moves; out-of-range ticks are simply never read
        by_tick: Dict[int, str] = {}
        for m in moves or []:
            try:
                by_tick[int(m["tick"])] = m.get("move", "stay")
            except (TypeError, ValueError, KeyError):
                continue

        lane = spawn
        score = 0
        hits = 0
        coins_got = 0
        steps_cleared = 0
        finished = False
        for step in range(steps):
            if step > 0:  # spawn step has no movement applied
                move = by_tick.get(step, "stay")
                lane = max(0, min(lanes - 1, lane + _MOVE_DELTA.get(move, 0)))
            cell = (step, lane)
            if cell in obstacle_set:
                hits += 1
                score -= hit_penalty
                if hits >= max_hits:
                    break
            else:
                score += step_pts
                steps_cleared += 1
                if cell in coin_set:
                    coins_got += 1
                    score += coin_pts
        else:
            finished = True

        if finished and hits == 0:
            score += clear_bonus

        raw[pid] = float(score)
        detail[pid] = {
            "steps_cleared": steps_cleared,
            "coins_collected": coins_got,
            "hits": hits,
            "finished": finished,
            "clean_run": finished and hits == 0,
        }
    return {"raw": raw, "raw_max": raw_max, "detail": detail}


# ── Deterministic AI / synthetic inputs ──────────────────────────────────────

def ai_inputs(instance: Dict[str, Any], player_id: str, seed: int) -> List[Dict[str, Any]]:
    """Generate seeded synthetic lane-change moves for an absent/AI player.

    Respectable but beatable: the AI greedily steers toward a safe reachable
    lane each step (dodging most obstacles), but with a seeded chance it
    "fumbles" and picks a random reachable lane instead — so it occasionally
    eats an obstacle and a sharp human can outscore it. Fully deterministic in
    ``seed`` + ``player_id``, so an AI-filled match replays identically.

    Returns a bare list of ``{"tick": int, "move": str}`` (matching the
    :func:`resolve` input shape), one entry per non-spawn step.
    """
    r = _rng(seed, GAME_ID, "ai", player_id)
    lanes = instance["lanes"]
    steps = instance["steps"]
    obstacles_by_step: Dict[int, set] = {}
    for o in instance["obstacles"]:
        obstacles_by_step.setdefault(o["step"], set()).add(o["lane"])
    coins_by_step: Dict[int, int] = {c["step"]: c["lane"] for c in instance["coins"]}

    moves: List[Dict[str, Any]] = []
    lane = instance["spawn_lane"]
    for step in range(1, steps):
        reachable = sorted({max(0, min(lanes - 1, lane + d)) for d in (-1, 0, 1)})
        blocked = obstacles_by_step.get(step, set())
        safe = [c for c in reachable if c not in blocked]
        pool = safe or reachable

        # prefer a reachable+safe lane that also has a coin, else any safe lane
        want = coins_by_step.get(step)
        if want is not None and want in pool:
            target = want
        elif r.random() < 0.15:      # seeded fumble: pick any reachable lane
            target = reachable[r.randrange(len(reachable))]
        else:
            target = pool[r.randrange(len(pool))]

        if target < lane:
            move = "left"
        elif target > lane:
            move = "right"
        else:
            move = "stay"
        lane = max(0, min(lanes - 1, lane + _MOVE_DELTA[move]))
        moves.append({"tick": step, "move": move})
    return moves
