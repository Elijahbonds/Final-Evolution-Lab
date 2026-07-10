"""
hold_the_flag.py — Court Carnival mini-game "Hold the Flag" (area control).

A king-of-the-hill / area-control round for the Carnival Board. A single
contested hill zone sits on a small grid; players fight to *stand inside it*
for as many ticks as possible while a seeded schedule of "hazard" cells opens
and closes underneath them. Stepping onto an ACTIVE hazard that tick bumps the
player back to where they were and breaks their control streak, so pure
sit-still play is punished when a hazard blooms on your square.

Everything that affects the authoritative outcome derives from the instance
``seed`` via the SAME :func:`lib.carnival._sub_seed` / :func:`lib.carnival._rng`
derivation the sibling mini-games use — there is no ``time`` / ``os.urandom`` /
unseeded ``random`` in any scoring path, so ``same seed + same inputs ->
identical result`` and replays re-derive bit-for-bit.

Input model (mirrors ``maze_chase`` so it is replay-validatable):
``inputs[pid] = [{"tick": int, "move": "up|down|left|right|stay"}]`` — a bare
list of tick-stamped moves, NOT a dict. The player starts at a seeded spawn and
moves one cell per tick, blocked by grid bounds.

Resolve contract (identical to the carnival mini-games):
``{"raw": {pid: float}, "raw_max": float, "detail": {pid: {...}}}``.

Public API (stable names so the lead can register it):
  * ``GAME_ID``
  * :func:`build`   — seeded instance descriptor
  * :func:`resolve` — score submitted tick-moves
  * :func:`ai_inputs` — deterministic synthetic tick-moves for an absent/AI seat
"""
from __future__ import annotations

from typing import Any, Dict, List, Tuple

from lib.carnival import _rng, _sub_seed  # reuse — do NOT reinvent the RNG

# ── Identity ─────────────────────────────────────────────────────────────────

GAME_ID = "hold_the_flag"

# ── Design constants (all echoed into the instance descriptor) ───────────────

HTF_W = 7                       # grid width
HTF_H = 7                       # grid height
HTF_TICKS = 40                  # tick-based like the maze (~15-40s)
HTF_HILL_RADIUS = 1             # Chebyshev radius of the hill zone around centre
HTF_HOLD_PTS = 10               # base points for a tick spent inside the hill
HTF_STREAK_STEP = 5             # extra points per consecutive held tick
HTF_STREAK_CAP = 6             # streak bonus tops out after this many held ticks
HTF_N_HAZARDS = 5              # distinct hazard cells in the seeded schedule
HTF_HAZARD_PERIOD = 6          # a hazard's open/close cycle length in ticks

# Shared move vocabulary (kept local so this module is self-contained; values
# match carnival._MOVES exactly).
_MOVES: Dict[str, Tuple[int, int]] = {
    "up": (0, -1),
    "down": (0, 1),
    "left": (-1, 0),
    "right": (1, 0),
    "stay": (0, 0),
}


# ── Helpers ──────────────────────────────────────────────────────────────────

def _in_hill(x: int, y: int, cx: int, cy: int, radius: int) -> bool:
    """True if ``(x, y)`` lies within the Chebyshev ``radius`` of the centre."""
    return abs(x - cx) <= radius and abs(y - cy) <= radius


def _streak_points(held_streak: int) -> int:
    """Points awarded for a held tick given the *current* streak length.

    ``held_streak`` is the number of consecutive held ticks *including* this
    one (i.e. 1 on the first held tick). Base hold points plus a capped linear
    streak bonus, so sustained control is rewarded but not unbounded::

        pts = HTF_HOLD_PTS + HTF_STREAK_STEP * min(held_streak - 1, HTF_STREAK_CAP)
    """
    bonus_units = min(max(held_streak - 1, 0), HTF_STREAK_CAP)
    return HTF_HOLD_PTS + HTF_STREAK_STEP * bonus_units


def _hazard_active(schedule_offset: int, tick: int) -> bool:
    """Whether a hazard with the given seeded phase offset is active at ``tick``.

    Each hazard runs a fixed-period on/off cycle: it is ACTIVE during the first
    half of its cycle (relative to its seeded phase) and dormant in the second
    half. Purely arithmetic on the tick index -> fully deterministic.
    """
    phase = (tick + schedule_offset) % HTF_HAZARD_PERIOD
    return phase < (HTF_HAZARD_PERIOD // 2)


def build(seed: int) -> Dict[str, Any]:
    """Build the deterministic Hold-the-Flag instance descriptor.

    The hill centre is the geometric middle of the grid (guaranteeing the hill
    zone never coincides with a hazard — see below — so a perfect game is
    always achievable and ``raw == raw_max`` is reachable). Hazard cells are a
    seeded sample of grid cells drawn strictly OUTSIDE the hill zone, each with
    a seeded phase offset controlling when it opens/closes.
    """
    cx, cy = HTF_W // 2, HTF_H // 2

    # Spawn on the top-left corner of the hill zone itself, so a perfect line
    # of play can hold from tick 0 (no wasted travel ticks). This is what makes
    # ``raw == raw_max`` reachable and keeps normalization honest (perfect ->
    # 100). It stays interesting because hazards can bloom on hill-edge cells
    # the player would otherwise sit on, forcing repositioning inside the zone.
    spawn = (cx - HTF_HILL_RADIUS, cy - HTF_HILL_RADIUS)

    # Candidate hazard cells: every grid cell that is not inside the hill zone
    # and not the spawn corner, so hazards never sit on the contested centre.
    candidates = [
        (x, y)
        for y in range(HTF_H)
        for x in range(HTF_W)
        if not _in_hill(x, y, cx, cy, HTF_HILL_RADIUS) and (x, y) != spawn
    ]

    r = _rng(seed, GAME_ID, "hazards")
    n = min(HTF_N_HAZARDS, len(candidates))
    cells = sorted(r.sample(candidates, n))
    hazards = [
        {
            "x": x,
            "y": y,
            # seeded phase so hazards don't all blink in lock-step
            "offset": r.randrange(HTF_HAZARD_PERIOD),
        }
        for (x, y) in cells
    ]

    return {
        "game": GAME_ID,
        "seed": seed,
        "w": HTF_W,
        "h": HTF_H,
        "ticks": HTF_TICKS,
        "hill_center": [cx, cy],
        "hill_radius": HTF_HILL_RADIUS,
        "spawn": list(spawn),
        "hazards": hazards,
        "hazard_period": HTF_HAZARD_PERIOD,
        # echoed point constants so replay/normalization needs no import
        "hold_pts": HTF_HOLD_PTS,
        "streak_step": HTF_STREAK_STEP,
        "streak_cap": HTF_STREAK_CAP,
    }


def _raw_max(ticks: int) -> float:
    """Theoretical maximum raw score: every tick held with the built-up streak.

    A perfect game holds from tick 0, so the streak on tick ``t`` (1-indexed as
    ``t + 1`` consecutive holds) yields ``_streak_points(t + 1)``. Summing over
    all ticks gives the ceiling that maps to 100 under ``normalize_scores``::

        raw_max = sum(_streak_points(t + 1) for t in range(ticks))
    """
    return float(sum(_streak_points(t + 1) for t in range(ticks)))


def resolve(instance: Dict[str, Any], inputs: Dict[str, Any]) -> Dict[str, Any]:
    """Resolve a Hold-the-Flag round from tick-stamped move sequences.

    ``inputs`` maps ``player_id -> [{"tick": int, "move": "up|down|..."}]``.
    Each player is simulated independently on their own copy of the grid, so
    the outcome depends only on the seed and that player's moves. Tolerances:

      * a missing / empty move list scores whatever standing still earns;
      * an unknown move string is treated as ``"stay"``;
      * moves with ``tick`` >= ``instance["ticks"]`` (or < 0) are ignored;
      * stepping onto an ACTIVE hazard cell that tick bumps the player back to
        their previous cell and breaks their hold streak for that tick.

    Returns ``{"raw": {pid: float}, "raw_max": float, "detail": {...}}``.
    """
    ticks = int(instance["ticks"])
    cx, cy = instance["hill_center"]
    radius = int(instance["hill_radius"])
    spawn = tuple(instance["spawn"])
    w, h = int(instance["w"]), int(instance["h"])
    hazards = instance["hazards"]

    # Precompute per-tick active hazard cell sets from the seeded schedule.
    active_by_tick: List[set] = []
    for t in range(ticks):
        active = {
            (hz["x"], hz["y"])
            for hz in hazards
            if _hazard_active(int(hz["offset"]), t)
        }
        active_by_tick.append(active)

    raw_max = _raw_max(ticks)
    raw: Dict[str, float] = {}
    detail: Dict[str, Any] = {}

    for pid, moves in inputs.items():
        by_tick: Dict[int, str] = {}
        for m in (moves or []):
            t = int(m.get("tick", -1))
            if 0 <= t < ticks:
                by_tick[t] = m.get("move", "stay")

        px, py = spawn
        score = 0
        held_ticks = 0
        hazard_hits = 0
        streak = 0
        best_streak = 0

        for t in range(ticks):
            move = by_tick.get(t, "stay")
            dx, dy = _MOVES.get(move, (0, 0))  # unknown move -> stay
            nx, ny = px + dx, py + dy
            if not (0 <= nx < w and 0 <= ny < h):
                nx, ny = px, py  # blocked by grid bounds

            if (nx, ny) in active_by_tick[t]:
                # stepping onto a live hazard: bumped back, streak broken
                hazard_hits += 1
                streak = 0
                # player stays where they were (px, py unchanged)
            else:
                px, py = nx, ny
                if _in_hill(px, py, cx, cy, radius):
                    streak += 1
                    held_ticks += 1
                    score += _streak_points(streak)
                    best_streak = max(best_streak, streak)
                else:
                    streak = 0

        raw[pid] = float(score)
        detail[pid] = {
            "held_ticks": held_ticks,
            "hazard_hits": hazard_hits,
            "best_streak": best_streak,
            "ticks": ticks,
        }

    return {"raw": raw, "raw_max": raw_max, "detail": detail}


def ai_inputs(instance: Dict[str, Any], player_id: str, seed: int) -> List[Dict[str, Any]]:
    """Deterministic synthetic tick-moves for an absent/AI seat.

    Strategy: greedily home in on the hill centre (step along the axis with the
    larger remaining gap), then hold once inside. Seeded noise makes the AI
    occasionally wander off the hill or blunder into a live hazard, so it is
    respectable but beatable — a human recorder can win. Purely a function of
    ``seed`` + ``player_id`` (+ the seeded instance), so it replays identically.
    """
    ticks = int(instance["ticks"])
    cx, cy = instance["hill_center"]
    radius = int(instance["hill_radius"])
    w, h = int(instance["w"]), int(instance["h"])
    px, py = tuple(instance["spawn"])
    r = _rng(seed, "ai", GAME_ID, player_id)

    moves: List[Dict[str, Any]] = []
    wander = 0  # remaining ticks committed to a random drift
    for t in range(ticks):
        # Occasionally commit to a multi-tick wander so the AI genuinely leaves
        # the hill (and risks hazards) rather than instantly snapping back — this
        # is what keeps it beatable. ~1-in-8 chance to start a 2-4 tick drift.
        if wander == 0 and r.random() < 0.12:
            wander = r.randint(2, 4)

        if wander > 0:
            move = r.choice(["up", "down", "left", "right"])
            wander -= 1
        else:
            ddx, ddy = cx - px, cy - py
            if abs(ddx) <= radius and abs(ddy) <= radius:
                # inside the hill already: hold, don't over-commit to centre
                move = "stay"
            elif abs(ddx) >= abs(ddy):
                move = "right" if ddx > 0 else "left"
            else:
                move = "down" if ddy > 0 else "up"

        dx, dy = _MOVES[move]
        nx, ny = px + dx, py + dy
        if 0 <= nx < w and 0 <= ny < h:
            px, py = nx, ny  # mirror resolve's bounds clamp for accurate homing
        moves.append({"tick": t, "move": move})

    return moves
