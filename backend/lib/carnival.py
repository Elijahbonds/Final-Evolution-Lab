"""
carnival.py — Court Carnival hybrid party-mode core (server-authoritative).

A Mario-Party-style board meta-game ("Carnival Board") that drops players
into short deterministic arena mini-games. EVERYTHING that affects the
authoritative outcome derives from ``match.seed`` (plus a turn/round index)
via :class:`random.Random` — there is no ``time``/``os.urandom``/``Math.random``
in any scoring path, so ``same seed + same inputs -> identical result``.

Contents
--------
* Board meta:      :class:`CarnivalBoard`, spinner, token economy, catch-up.
* Mini-game engines (deterministic, resolved from submitted inputs):
    - :func:`maze_chase_build`   / :func:`maze_chase_resolve`
    - :func:`target_burst_build` / :func:`target_burst_resolve`
    - :func:`rhythm_tap_build`   / :func:`rhythm_tap_resolve`
* Normalization: every mini-game returns a per-player raw score which is
  mapped to a comparable 0..100 "normalized token" value so games contribute
  on equal footing to the board economy (see :func:`normalize_scores`).

The board router (:mod:`routers.carnival`) is a thin HTTP/replay shell over
this module; keeping the logic here makes it unit-testable in isolation and
replayable by ``tools/replay_validator.py``.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from random import Random
from typing import Any, Dict, List, Optional, Sequence, Tuple

# ── Constants ───────────────────────────────────────────────────────────────

BOARD_SIZE = 24                     # spaces on the ring board
DEFAULT_ROUNDS = 8                  # mini-game rounds per match (brief: 6-8)
MINIGAME_EVERY_NTH = 3             # trigger a mini-game every Nth advance too
SPACE_TYPES = ("PRIZE", "MINIGAME", "TRAP", "SHOP", "CREATOR_STAND")

MINIGAMES = ("maze_chase", "target_burst", "rhythm_tap", "hold_the_flag", "short_race")

# Space-type token/coin effects on landing (deterministic, board-meta only).
SPACE_EFFECTS: Dict[str, Dict[str, int]] = {
    "PRIZE": {"coins": 3, "tokens": 0},
    "MINIGAME": {"coins": 0, "tokens": 0},   # triggers a mini-game instead
    "TRAP": {"coins": -2, "tokens": 0},
    "SHOP": {"coins": -1, "tokens": 1},       # buy 1 token for 1 coin
    "CREATOR_STAND": {"coins": 1, "tokens": 0},  # Creator Card tie-in seam
}


# ── Deterministic RNG helpers ───────────────────────────────────────────────

def _sub_seed(seed: int, *tags: Any) -> int:
    """Derive a stable child seed from ``seed`` and arbitrary string tags.

    Uses BLAKE2b so the derivation is portable and independent of Python's
    hash randomization — critical for cross-process replay reproducibility.
    """
    h = hashlib.blake2b(digest_size=8)
    h.update(str(seed).encode())
    for t in tags:
        h.update(b"|")
        h.update(str(t).encode())
    return int.from_bytes(h.digest(), "big")


def _rng(seed: int, *tags: Any) -> Random:
    return Random(_sub_seed(seed, *tags))


def spinner_roll(seed: int, turn_index: int, faces: int = 10) -> int:
    """Deterministic spinner value in ``1..faces`` from seed + turn index.

    No ``Math.random`` / wall-clock: identical inputs always yield the same
    roll, which is what makes the whole board replayable.
    """
    return _rng(seed, "spin", turn_index).randint(1, faces)


# ── Board layout ────────────────────────────────────────────────────────────

def build_board(seed: int, size: int = BOARD_SIZE) -> List[Dict[str, Any]]:
    """Deterministically type each of ``size`` ring spaces.

    Layout rules (seeded but constrained for good pacing):
      * every 4th space is a guaranteed MINIGAME (predictable pacing),
      * space 0 is the START (typed PRIZE so nobody starts in a trap),
      * remaining spaces are weighted-random typed from the seed.
    """
    r = _rng(seed, "board")
    weights = [
        ("PRIZE", 5),
        ("TRAP", 4),
        ("SHOP", 3),
        ("CREATOR_STAND", 2),
        ("MINIGAME", 3),
    ]
    pool: List[str] = []
    for name, w in weights:
        pool.extend([name] * w)

    spaces: List[Dict[str, Any]] = []
    for i in range(size):
        if i == 0:
            t = "PRIZE"
        elif i % 4 == 0:
            t = "MINIGAME"
        else:
            t = pool[r.randrange(len(pool))]
        spaces.append({"index": i, "type": t})
    return spaces


# ── Player / board state ────────────────────────────────────────────────────

@dataclass
class CarnivalPlayer:
    player_id: str
    display_name: str
    is_ai: bool = False
    shape: str = "circle"          # colorblind-safe indicator: shape + color
    color: str = "#00D4FF"
    position: int = 0              # board space index
    coins: int = 5                 # starting stake
    tokens: int = 0                # normalized mini-game currency
    minigame_score: int = 0        # cumulative normalized token contribution

    def total(self) -> int:
        """Standings metric = coins + tokens (both matter to victory)."""
        return self.coins + self.tokens


# Distinct shape+color pairs so indicators are distinguishable without color.
PLAYER_SKINS: List[Tuple[str, str]] = [
    ("circle", "#00D4FF"),   # cyan
    ("square", "#9933FF"),   # purple
    ("triangle", "#FFC400"), # amber
    ("diamond", "#00E676"),  # green
]


# ── Catch-up / comeback multiplier ──────────────────────────────────────────

def catchup_multiplier(player_total: int, leader_total: int) -> float:
    """Trailing-player bonus multiplier applied to normalized mini-game tokens.

    Formula (documented for design sign-off):

        gap   = max(0, leader_total - player_total)
        mult  = 1.0 + min(0.5, 0.02 * gap)

    i.e. +2% tokens per point of deficit, capped at +50%. The leader (gap 0)
    always gets exactly 1.0 (no bonus). Deterministic and monotonic — a bigger
    deficit never yields a smaller bonus. Chosen so comebacks are possible but
    a dominant lead still usually holds; tunable after playtest.
    """
    gap = max(0, leader_total - player_total)
    return 1.0 + min(0.5, 0.02 * gap)


# ── Score normalization (comparability across mini-games) ────────────────────

# Each mini-game reports a raw score plus the max raw score achievable for its
# seeded instance; we map raw -> 0..100 tokens so every game contributes on the
# same scale to the board economy.
NORMALIZED_MAX = 100


def normalize_scores(raw: Dict[str, float], raw_max: float) -> Dict[str, int]:
    """Map per-player raw scores onto ``0..NORMALIZED_MAX`` integer tokens.

    ``raw_max`` is the theoretical maximum raw score for that seeded instance
    (e.g. all pellets eaten, all targets hit). If ``raw_max <= 0`` everyone
    scores 0. Uses round-half-up via ``+0.5`` floor to stay deterministic.
    """
    if raw_max <= 0:
        return {pid: 0 for pid in raw}
    out: Dict[str, int] = {}
    for pid, val in raw.items():
        frac = max(0.0, min(1.0, val / raw_max))
        out[pid] = int(frac * NORMALIZED_MAX + 0.5)
    return out


# ════════════════════════════════════════════════════════════════════════════
#  MINI-GAME 1 — MAZE CHASE
# ════════════════════════════════════════════════════════════════════════════
#
#  10x10 grid maze from seed; pellets + 2-3 power pellets placed by seed.
#  Players move on grid ticks; a deterministic chaser AI pursues. Scoring =
#  pellets eaten (+power pellets) + survival ticks. Server resolves purely
#  from submitted tick-stamped move sequences.

MAZE_W = 10
MAZE_H = 10
MAZE_TICKS = 40                    # ~15-40s of grid ticks
MAZE_PELLET_PTS = 10
MAZE_POWER_PTS = 50
MAZE_SURVIVE_PTS = 2               # per tick survived
MAZE_POWER_DURATION = 6           # ticks the chaser is frightened/edible

_MOVES = {
    "up": (0, -1),
    "down": (0, 1),
    "left": (-1, 0),
    "right": (1, 0),
    "stay": (0, 0),
}


def _maze_walls(seed: int) -> List[List[int]]:
    """Generate a 10x10 wall grid (1=wall, 0=open) from seed.

    Border is always open (players wrap the ring interior); interior walls are
    seeded but we guarantee a connected open field by carving a spanning set:
    start all-open, sprinkle walls, then knock out any wall that would fully
    enclose a cell (cheap connectivity guard for a small fixed grid).
    """
    r = _rng(seed, "maze", "walls")
    grid = [[0] * MAZE_W for _ in range(MAZE_H)]
    # sprinkle ~18% interior walls
    for y in range(1, MAZE_H - 1):
        for x in range(1, MAZE_W - 1):
            if r.random() < 0.18:
                grid[y][x] = 1
    # connectivity guard: no cell fully boxed in on all 4 sides
    for y in range(1, MAZE_H - 1):
        for x in range(1, MAZE_W - 1):
            if grid[y][x] == 1:
                continue
            blocked = sum(
                grid[y + dy][x + dx]
                for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0))
            )
            if blocked == 4:
                # open the neighbour toward the maze centre
                grid[y][x - 1 if x > MAZE_W // 2 else x + 1] = 0
    return grid


def _maze_open_cells(walls: List[List[int]]) -> List[Tuple[int, int]]:
    return [
        (x, y)
        for y in range(MAZE_H)
        for x in range(MAZE_W)
        if walls[y][x] == 0
    ]


def maze_chase_build(seed: int) -> Dict[str, Any]:
    """Build the deterministic Maze Chase instance descriptor."""
    walls = _maze_walls(seed)
    opens = _maze_open_cells(walls)
    r = _rng(seed, "maze", "layout")

    # Pellets on every open cell except spawn corners; power pellets are a
    # seeded subset of size 2-3.
    spawn = (1, 1)
    chaser_spawn = (MAZE_W - 2, MAZE_H - 2)
    pellet_cells = [c for c in opens if c not in (spawn, chaser_spawn)]
    n_power = r.randint(2, 3)
    power_cells = sorted(r.sample(pellet_cells, min(n_power, len(pellet_cells))))
    power_set = set(power_cells)

    return {
        "game": "maze_chase",
        "seed": seed,
        "w": MAZE_W,
        "h": MAZE_H,
        "ticks": MAZE_TICKS,
        "walls": walls,
        "spawn": list(spawn),
        "chaser_spawn": list(chaser_spawn),
        "pellets": [list(c) for c in pellet_cells],
        "power_pellets": [list(c) for c in sorted(power_set)],
        "pellet_pts": MAZE_PELLET_PTS,
        "power_pts": MAZE_POWER_PTS,
        "survive_pts": MAZE_SURVIVE_PTS,
    }


def _maze_can_move(walls: List[List[int]], x: int, y: int) -> bool:
    return 0 <= x < MAZE_W and 0 <= y < MAZE_H and walls[y][x] == 0


def _chaser_step(walls, cx, cy, px, py, frightened, rng) -> Tuple[int, int]:
    """Deterministic greedy chaser: minimise Manhattan distance to player.

    When frightened (player ate a power pellet) it flees instead. Ties are
    broken by a seeded rng draw so behaviour is reproducible but not trivially
    exploitable. No wall-clock, no global random.
    """
    best: List[Tuple[int, int]] = []
    best_metric: Optional[int] = None
    options = []
    for name in ("up", "down", "left", "right"):
        dx, dy = _MOVES[name]
        nx, ny = cx + dx, cy + dy
        if _maze_can_move(walls, nx, ny):
            options.append((nx, ny))
    if not options:
        return cx, cy
    for nx, ny in options:
        dist = abs(nx - px) + abs(ny - py)
        metric = -dist if frightened else dist   # flee -> maximise distance
        if best_metric is None or metric < best_metric:
            best_metric = metric
            best = [(nx, ny)]
        elif metric == best_metric:
            best.append((nx, ny))
    return best[rng.randrange(len(best))]


def maze_chase_resolve(
    instance: Dict[str, Any],
    inputs: Dict[str, List[Dict[str, Any]]],
) -> Dict[str, Any]:
    """Resolve a Maze Chase round from tick-stamped move sequences.

    ``inputs`` maps ``player_id -> [{"tick": int, "move": "up|down|..."}]``.
    Each player is simulated independently against their own copy of the maze
    and a shared-seed chaser, so the result depends only on ``instance.seed``
    and the submitted moves (same in -> same out).

    Returns ``{"raw": {pid: score}, "raw_max": float, "detail": {...}}``.
    """
    walls = instance["walls"]
    seed = instance["seed"]
    all_pellets = {tuple(c) for c in instance["pellets"]}
    power = {tuple(c) for c in instance["power_pellets"]}
    ticks = instance["ticks"]
    spawn = tuple(instance["spawn"])
    chaser_spawn = tuple(instance["chaser_spawn"])
    raw_max = (
        len(all_pellets) * MAZE_PELLET_PTS
        + len(power) * MAZE_POWER_PTS
        + ticks * MAZE_SURVIVE_PTS
    )

    raw: Dict[str, float] = {}
    detail: Dict[str, Any] = {}
    for pid, moves in inputs.items():
        by_tick = {int(m["tick"]): m.get("move", "stay") for m in moves}
        px, py = spawn
        cx, cy = chaser_spawn
        eaten = set()
        eaten_power = set()
        score = 0
        survived = 0
        frightened = 0
        chaser_rng = _rng(seed, "maze", "chaser", pid)
        caught_tick: Optional[int] = None
        for t in range(ticks):
            move = by_tick.get(t, "stay")
            dx, dy = _MOVES.get(move, (0, 0))
            nx, ny = px + dx, py + dy
            if _maze_can_move(walls, nx, ny):
                px, py = nx, ny
            cell = (px, py)
            if cell in all_pellets and cell not in eaten:
                eaten.add(cell)
                score += MAZE_PELLET_PTS
            if cell in power and cell not in eaten_power:
                eaten_power.add(cell)
                score += MAZE_POWER_PTS
                frightened = MAZE_POWER_DURATION
            # chaser moves after player
            cx, cy = _chaser_step(walls, cx, cy, px, py, frightened > 0, chaser_rng)
            if frightened > 0:
                frightened -= 1
            if (cx, cy) == (px, py):
                if frightened > 0:
                    # eat the frightened chaser: bonus + respawn it
                    score += MAZE_POWER_PTS
                    cx, cy = chaser_spawn
                else:
                    caught_tick = t
                    break
            survived += 1
            score += MAZE_SURVIVE_PTS
        raw[pid] = float(score)
        detail[pid] = {
            "pellets_eaten": len(eaten),
            "power_eaten": len(eaten_power),
            "survived_ticks": survived,
            "caught_tick": caught_tick,
        }
    return {"raw": raw, "raw_max": float(raw_max), "detail": detail}


# ════════════════════════════════════════════════════════════════════════════
#  MINI-GAME 2 — TARGET BURST
# ════════════════════════════════════════════════════════════════════════════
#
#  Deterministic target spawn schedule from seed (position + open window).
#  Players submit tap events {target_id, ts}; server scores hits within the
#  window, latency-normalized (client reports its own measured latency, which
#  is subtracted from tap ts before window comparison — buzzer-style).

TB_TARGETS = 12
TB_DURATION_MS = 20_000
TB_WINDOW_MS = 900                 # window a target stays hittable
TB_HIT_PTS = 100
TB_ACCURACY_BONUS = 50            # scaled by how centred in the window the tap is


def target_burst_build(seed: int) -> Dict[str, Any]:
    """Deterministic schedule of targets: id, x, y (0..1), spawn_ms, window_ms."""
    r = _rng(seed, "target_burst")
    targets = []
    # spread spawns across the duration with seeded jitter
    slot = TB_DURATION_MS / TB_TARGETS
    for i in range(TB_TARGETS):
        base = int(i * slot)
        jitter = r.randint(0, max(1, int(slot * 0.4)))
        targets.append({
            "id": i,
            "x": round(r.random(), 4),
            "y": round(r.random(), 4),
            "spawn_ms": base + jitter,
            "window_ms": TB_WINDOW_MS,
        })
    return {
        "game": "target_burst",
        "seed": seed,
        "duration_ms": TB_DURATION_MS,
        "targets": targets,
        "hit_pts": TB_HIT_PTS,
        "accuracy_bonus": TB_ACCURACY_BONUS,
    }


def target_burst_resolve(
    instance: Dict[str, Any],
    inputs: Dict[str, Dict[str, Any]],
) -> Dict[str, Any]:
    """Resolve Target Burst.

    ``inputs`` maps ``player_id -> {"latency_ms": float,
    "taps": [{"target_id": int, "ts_ms": float}, ...]}``.
    Each tap's timestamp is latency-corrected (``ts - latency``) then checked
    against the target's open window; the closer to the window centre, the
    larger the accuracy bonus. One scoring hit per target.
    """
    targets = {t["id"]: t for t in instance["targets"]}
    raw_max = float(len(targets) * (TB_HIT_PTS + TB_ACCURACY_BONUS))
    raw: Dict[str, float] = {}
    detail: Dict[str, Any] = {}
    for pid, data in inputs.items():
        latency = float(data.get("latency_ms", 0.0))
        taps = sorted(data.get("taps", []), key=lambda x: x.get("ts_ms", 0))
        hit_targets = set()
        score = 0.0
        hits = 0
        for tap in taps:
            tid = tap.get("target_id")
            if tid not in targets or tid in hit_targets:
                continue
            tgt = targets[tid]
            corrected = float(tap.get("ts_ms", 0)) - latency
            open_ms = tgt["spawn_ms"]
            close_ms = open_ms + tgt["window_ms"]
            if open_ms <= corrected <= close_ms:
                hit_targets.add(tid)
                hits += 1
                centre = open_ms + tgt["window_ms"] / 2.0
                # 1.0 at centre -> 0.0 at edges
                closeness = 1.0 - abs(corrected - centre) / (tgt["window_ms"] / 2.0)
                closeness = max(0.0, min(1.0, closeness))
                score += TB_HIT_PTS + TB_ACCURACY_BONUS * closeness
        raw[pid] = round(score, 4)
        detail[pid] = {"hits": hits, "targets": len(targets)}
    return {"raw": raw, "raw_max": raw_max, "detail": detail}


# ════════════════════════════════════════════════════════════════════════════
#  MINI-GAME 3 — RHYTHM TAP
# ════════════════════════════════════════════════════════════════════════════
#
#  Beatmap generated deterministically from seed (BPM + pattern rules). Client
#  records hit timestamps; server normalizes by measured latency and scores
#  timing windows: perfect / good / miss.

RT_BPM_MIN = 90
RT_BPM_MAX = 140
RT_BEATS = 24
RT_PERFECT_MS = 45
RT_GOOD_MS = 110
RT_PERFECT_PTS = 100
RT_GOOD_PTS = 50
RT_MISS_PTS = 0


def rhythm_tap_build(seed: int) -> Dict[str, Any]:
    """Deterministic beatmap: BPM + a list of beat times (ms).

    Pattern rule: a straight quarter-note pulse at the chosen BPM, with a
    seeded subset of beats "doubled" (eighth-note flourish) for texture.
    """
    r = _rng(seed, "rhythm")
    bpm = r.randint(RT_BPM_MIN, RT_BPM_MAX)
    beat_ms = 60_000.0 / bpm
    beats: List[float] = []
    t = 1000.0  # 1s lead-in
    for i in range(RT_BEATS):
        beats.append(round(t, 3))
        # seeded flourish: sometimes insert an eighth-note between beats
        if r.random() < 0.25:
            beats.append(round(t + beat_ms / 2.0, 3))
        t += beat_ms
    beats = sorted(beats)
    return {
        "game": "rhythm_tap",
        "seed": seed,
        "bpm": bpm,
        "beat_ms": round(beat_ms, 3),
        "beats": beats,
        "perfect_ms": RT_PERFECT_MS,
        "good_ms": RT_GOOD_MS,
        "perfect_pts": RT_PERFECT_PTS,
        "good_pts": RT_GOOD_PTS,
    }


def rhythm_tap_resolve(
    instance: Dict[str, Any],
    inputs: Dict[str, Dict[str, Any]],
) -> Dict[str, Any]:
    """Resolve Rhythm Tap.

    ``inputs`` maps ``player_id -> {"latency_ms": float,
    "taps": [ts_ms, ...]}``. Each tap is latency-corrected and matched to the
    nearest unused beat; timing error decides perfect/good/miss.
    """
    beats = instance["beats"]
    raw_max = float(len(beats) * RT_PERFECT_PTS)
    raw: Dict[str, float] = {}
    detail: Dict[str, Any] = {}
    for pid, data in inputs.items():
        latency = float(data.get("latency_ms", 0.0))
        taps = sorted(float(t) - latency for t in data.get("taps", []))
        used = [False] * len(beats)
        perfect = good = miss = 0
        score = 0
        for tap in taps:
            # nearest unused beat
            best_idx = -1
            best_err = None
            for i, b in enumerate(beats):
                if used[i]:
                    continue
                err = abs(tap - b)
                if best_err is None or err < best_err:
                    best_err = err
                    best_idx = i
            if best_idx < 0 or best_err is None:
                continue
            if best_err <= RT_PERFECT_MS:
                used[best_idx] = True
                perfect += 1
                score += RT_PERFECT_PTS
            elif best_err <= RT_GOOD_MS:
                used[best_idx] = True
                good += 1
                score += RT_GOOD_PTS
            else:
                miss += 1
        raw[pid] = float(score)
        detail[pid] = {
            "perfect": perfect,
            "good": good,
            "miss": miss,
            "beats": len(beats),
        }
    return {"raw": raw, "raw_max": raw_max, "detail": detail}


# ── Mini-game dispatch table ─────────────────────────────────────────────────
#
# The two second-pass mini-games (hold_the_flag, short_race) live in their own
# self-contained modules under ``lib/minigames/``. They import ``_rng`` /
# ``_sub_seed`` from THIS module, so they are imported here — after those
# helpers are defined — to avoid a circular import at module top. Each exposes
# the stable ``build`` / ``resolve`` / ``ai_inputs`` contract, so they slot into
# the same dispatch/registry the core three use.
from lib.minigames import hold_the_flag as _hold_the_flag  # noqa: E402
from lib.minigames import short_race as _short_race        # noqa: E402

_BUILDERS = {
    "maze_chase": maze_chase_build,
    "target_burst": target_burst_build,
    "rhythm_tap": rhythm_tap_build,
    "hold_the_flag": _hold_the_flag.build,
    "short_race": _short_race.build,
}
_RESOLVERS = {
    "maze_chase": maze_chase_resolve,
    "target_burst": target_burst_resolve,
    "rhythm_tap": rhythm_tap_resolve,
    "hold_the_flag": _hold_the_flag.resolve,
    "short_race": _short_race.resolve,
}

# AI/synthetic-input dispatch for the module-based mini-games (the core three
# are handled inline in :func:`ai_minigame_inputs`).
_AI_INPUTS = {
    "hold_the_flag": _hold_the_flag.ai_inputs,
    "short_race": _short_race.ai_inputs,
}


def build_minigame(game: str, seed: int, round_index: int) -> Dict[str, Any]:
    """Build a seeded instance of ``game`` for a given round.

    The per-round sub-seed keeps successive rounds of the same game distinct
    while remaining fully derived from the match seed.
    """
    if game not in _BUILDERS:
        raise ValueError(f"unknown mini-game {game!r}")
    sub = _sub_seed(seed, "round", round_index, game)
    inst = _BUILDERS[game](sub)
    inst["round_index"] = round_index
    inst["match_seed"] = seed
    return inst


def resolve_minigame(
    game: str, instance: Dict[str, Any], inputs: Dict[str, Any]
) -> Dict[str, Any]:
    if game not in _RESOLVERS:
        raise ValueError(f"unknown mini-game {game!r}")
    return _RESOLVERS[game](instance, inputs)


def pick_minigame(seed: int, round_index: int) -> str:
    """Deterministically choose which mini-game a round runs."""
    return MINIGAMES[_rng(seed, "pick", round_index).randrange(len(MINIGAMES))]


# ── Applying a resolved mini-game to board standings ─────────────────────────

def award_minigame_tokens(
    players: Sequence[CarnivalPlayer],
    normalized: Dict[str, int],
) -> Dict[str, Dict[str, Any]]:
    """Convert normalized mini-game scores into board tokens with catch-up.

    Returns a per-player award breakdown: base normalized value, the catch-up
    multiplier applied, and the final awarded tokens (rounded). Mutates the
    players' ``tokens`` / ``minigame_score``.
    """
    leader_total = max((p.total() for p in players), default=0)
    awards: Dict[str, Dict[str, Any]] = {}
    for p in players:
        base = normalized.get(p.player_id, 0)
        mult = catchup_multiplier(p.total(), leader_total)
        final = int(base * mult + 0.5)
        p.tokens += final
        p.minigame_score += final
        awards[p.player_id] = {
            "base": base,
            "catchup_mult": round(mult, 3),
            "awarded": final,
        }
    return awards


# ── Board state machine ──────────────────────────────────────────────────────

@dataclass
class CarnivalBoard:
    """Server-authoritative Carnival Board match state (pure, no I/O)."""

    seed: int
    players: List[CarnivalPlayer]
    board: List[Dict[str, Any]]
    rounds: int = DEFAULT_ROUNDS
    turn_index: int = 0            # increments every spin/advance
    round_index: int = 0          # increments every completed mini-game
    active_player: int = 0        # index into players
    status: str = "active"        # active | finished
    pending_minigame: Optional[Dict[str, Any]] = None
    history: List[Dict[str, Any]] = field(default_factory=list)

    # ── construction ────────────────────────────────────────────────────────
    @classmethod
    def create(
        cls,
        seed: int,
        player_specs: Sequence[Dict[str, Any]],
        rounds: int = DEFAULT_ROUNDS,
        max_players: int = 4,
    ) -> "CarnivalBoard":
        """Build a match; AI-fill absent seats up to 2 players minimum."""
        specs = list(player_specs)[:max_players]
        players: List[CarnivalPlayer] = []
        for i, spec in enumerate(specs):
            shape, color = PLAYER_SKINS[i % len(PLAYER_SKINS)]
            players.append(CarnivalPlayer(
                player_id=spec["player_id"],
                display_name=spec.get("display_name", spec["player_id"]),
                is_ai=bool(spec.get("is_ai", False)),
                shape=shape,
                color=color,
            ))
        # AI fill-in to reach a minimum of 2 seated players
        i = len(players)
        while len(players) < 2:
            shape, color = PLAYER_SKINS[i % len(PLAYER_SKINS)]
            players.append(CarnivalPlayer(
                player_id=f"ai_{i}",
                display_name=f"CPU {i}",
                is_ai=True,
                shape=shape,
                color=color,
            ))
            i += 1
        board = build_board(seed)
        return cls(seed=seed, players=players, board=board, rounds=max(1, rounds))

    # ── queries ──────────────────────────────────────────────────────────────
    def leader(self) -> CarnivalPlayer:
        return max(self.players, key=lambda p: (p.total(), -self.players.index(p)))

    def standings(self) -> List[Dict[str, Any]]:
        ranked = sorted(self.players, key=lambda p: p.total(), reverse=True)
        return [
            {
                "rank": i + 1,
                "player_id": p.player_id,
                "display_name": p.display_name,
                "is_ai": p.is_ai,
                "coins": p.coins,
                "tokens": p.tokens,
                "total": p.total(),
                "position": p.position,
                "shape": p.shape,
                "color": p.color,
            }
            for i, p in enumerate(ranked)
        ]

    # ── advance / spin ────────────────────────────────────────────────────────
    def spin_and_advance(self) -> Dict[str, Any]:
        """Advance the active player by a seeded spinner roll and apply landing.

        Returns an event dict describing the outcome. If the player lands on a
        MINIGAME space (or it's every Nth turn), a mini-game is queued in
        ``pending_minigame`` and must be resolved via :meth:`submit_minigame`.
        """
        if self.status != "active":
            return {"type": "carnival_noop", "reason": "match_finished"}
        if self.pending_minigame is not None:
            return {"type": "carnival_noop", "reason": "minigame_pending"}

        p = self.players[self.active_player]
        roll = spinner_roll(self.seed, self.turn_index)
        old_pos = p.position
        p.position = (p.position + roll) % len(self.board)
        space = self.board[p.position]
        effect = dict(SPACE_EFFECTS.get(space["type"], {}))
        p.coins = max(0, p.coins + effect.get("coins", 0))
        p.tokens = max(0, p.tokens + effect.get("tokens", 0))

        event: Dict[str, Any] = {
            "type": "carnival_spin",
            "turn_index": self.turn_index,
            "player_id": p.player_id,
            "roll": roll,
            "from": old_pos,
            "to": p.position,
            "space_type": space["type"],
            "coins": p.coins,
            "tokens": p.tokens,
        }

        trigger = space["type"] == "MINIGAME" or (
            self.turn_index > 0 and self.turn_index % MINIGAME_EVERY_NTH == 0
        )
        self.turn_index += 1
        if trigger and self.round_index < self.rounds:
            game = pick_minigame(self.seed, self.round_index)
            inst = build_minigame(game, self.seed, self.round_index)
            self.pending_minigame = {"game": game, "instance": inst}
            event["minigame"] = game
            event["minigame_round"] = self.round_index

        # rotate to next player
        self.active_player = (self.active_player + 1) % len(self.players)
        self.history.append(event)
        return event

    # ── mini-game resolution ──────────────────────────────────────────────────
    def submit_minigame(self, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """Resolve the pending mini-game from all players' submitted inputs.

        Absent players (or AI) are auto-scored from a seeded synthetic input so
        a solo recorder still gets a full competitive round (see
        :func:`ai_minigame_inputs`). Returns a ``carnival_minigame_result``
        event and clears ``pending_minigame``; advances ``round_index`` and may
        finish the match.
        """
        if self.pending_minigame is None:
            return {"type": "carnival_noop", "reason": "no_pending_minigame"}
        game = self.pending_minigame["game"]
        inst = self.pending_minigame["instance"]

        # fill AI / absent players with deterministic synthetic inputs
        full_inputs = dict(inputs)
        for p in self.players:
            if p.player_id not in full_inputs:
                full_inputs[p.player_id] = ai_minigame_inputs(
                    game, inst, p.player_id, self.seed
                )

        result = resolve_minigame(game, inst, full_inputs)
        normalized = normalize_scores(result["raw"], result["raw_max"])
        awards = award_minigame_tokens(self.players, normalized)

        self.pending_minigame = None
        self.round_index += 1
        if self.round_index >= self.rounds:
            self.status = "finished"

        event = {
            "type": "carnival_minigame_result",
            "game": game,
            "round_index": self.round_index - 1,
            "instance": inst,          # echoed so replay can re-resolve
            "inputs": full_inputs,     # all inputs (human + seeded AI fill)
            "raw": result["raw"],
            "raw_max": result["raw_max"],
            "normalized": normalized,
            "awards": awards,
            "detail": result.get("detail", {}),
            "status": self.status,
        }
        self.history.append(event)
        return event


# ── Deterministic AI / synthetic inputs (for solo recording & fill-in) ───────

def ai_minigame_inputs(
    game: str, instance: Dict[str, Any], player_id: str, seed: int
) -> Dict[str, Any]:
    """Generate seeded synthetic inputs for an absent/AI player.

    Purely deterministic (seed + player_id), so an AI-filled match replays
    identically. Skill is tuned per game to be respectable but beatable so a
    human recorder can win an exciting match.
    """
    if game in _AI_INPUTS:
        # module-based mini-games own their deterministic AI generation
        return _AI_INPUTS[game](instance, player_id, seed)
    r = _rng(seed, "ai", game, player_id)
    if game == "maze_chase":
        # greedy-ish walk toward nearest pellet with seeded exploration
        moves = []
        for t in range(instance["ticks"]):
            moves.append({
                "tick": t,
                "move": r.choice(["up", "down", "left", "right"]),
            })
        return moves
    if game == "target_burst":
        taps = []
        for tgt in instance["targets"]:
            if r.random() < 0.7:  # AI hits ~70% of targets
                offset = r.uniform(0, tgt["window_ms"])
                taps.append({
                    "target_id": tgt["id"],
                    "ts_ms": tgt["spawn_ms"] + offset,
                })
        return {"latency_ms": 0.0, "taps": taps}
    if game == "rhythm_tap":
        taps = []
        for b in instance["beats"]:
            if r.random() < 0.75:  # AI lands ~75% of beats
                jitter = r.uniform(-RT_GOOD_MS, RT_GOOD_MS)
                taps.append(b + jitter)
        return {"latency_ms": 0.0, "taps": taps}
    return {}
