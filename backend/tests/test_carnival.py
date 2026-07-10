"""
test_carnival.py — Court Carnival hybrid party-mode determinism & integrity.

Covers:
  * per-mini-game seed determinism (same seed + inputs -> identical scores,
    3 seeds each),
  * cross-game normalization comparability (all games map onto 0..100),
  * board loop integrity (spinner determinism, token economy, catch-up, full
    match reaches `finished` in the configured rounds),
  * HTTP router create -> spin -> submit -> export flow,
  * replay round-trip through tools/replay_validator.validate_carnival_replay.
"""
import os
import sys

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

import types
from unittest.mock import MagicMock, patch


def _stub(name):
    parts = name.split(".")
    for i in range(1, len(parts) + 1):
        pkg = ".".join(parts[:i])
        if pkg not in sys.modules:
            sys.modules[pkg] = types.ModuleType(pkg)
    return sys.modules[name]


_chat = _stub("emergentintegrations.llm.chat")
_chat.LlmChat = MagicMock
_chat.UserMessage = MagicMock
_chat.ImageContent = MagicMock

_motor_patcher = patch("motor.motor_asyncio.AsyncIOMotorClient")
_mock_motor = _motor_patcher.start()
_mock_motor.return_value.__getitem__ = lambda self, n: MagicMock()

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from core import User
from lib import carnival as C
from routers.carnival import router as carnival_router, get_carnival_user, _boards, _events, _meta
from tools.replay_validator import validate_carnival_replay

_SEEDS = [1, 20260707, 0xC0FFEE]


# ══════════════════════════════════════════════════════════════════════════
#  Mini-game seed determinism
# ══════════════════════════════════════════════════════════════════════════

class TestMazeChaseDeterminism:
    def _inputs(self, inst, seed):
        return {
            "p1": C.ai_minigame_inputs("maze_chase", inst, "p1", seed),
            "p2": C.ai_minigame_inputs("maze_chase", inst, "p2", seed),
        }

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_same_seed_inputs_identical_result(self, seed):
        i1 = C.build_minigame("maze_chase", seed, 0)
        i2 = C.build_minigame("maze_chase", seed, 0)
        assert i1 == i2  # instance itself is deterministic
        inp = self._inputs(i1, seed)
        r1 = C.resolve_minigame("maze_chase", i1, inp)
        r2 = C.resolve_minigame("maze_chase", i2, inp)
        assert r1 == r2

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_grid_is_10x10_and_has_power_pellets(self, seed):
        inst = C.build_minigame("maze_chase", seed, 0)
        assert inst["w"] == 10 and inst["h"] == 10
        assert 2 <= len(inst["power_pellets"]) <= 3
        assert len(inst["pellets"]) > 0

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_explicit_moves_reproduce(self, seed):
        inst = C.build_minigame("maze_chase", seed, 0)
        moves = [{"tick": t, "move": "right" if t % 2 else "down"} for t in range(inst["ticks"])]
        r1 = C.resolve_minigame("maze_chase", inst, {"p1": moves})
        r2 = C.resolve_minigame("maze_chase", inst, {"p1": moves})
        assert r1["raw"] == r2["raw"]


class TestTargetBurstDeterminism:
    @pytest.mark.parametrize("seed", _SEEDS)
    def test_same_seed_inputs_identical(self, seed):
        inst = C.build_minigame("target_burst", seed, 0)
        inp = {"p1": C.ai_minigame_inputs("target_burst", inst, "p1", seed)}
        r1 = C.resolve_minigame("target_burst", inst, inp)
        r2 = C.resolve_minigame("target_burst", inst, inp)
        assert r1 == r2

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_latency_normalization_shifts_hit(self, seed):
        inst = C.build_minigame("target_burst", seed, 0)
        tgt = inst["targets"][0]
        centre = tgt["spawn_ms"] + tgt["window_ms"] / 2.0
        # tap 100ms late but report 100ms latency -> corrected to centre -> hit
        inp = {"p1": {"latency_ms": 100.0, "taps": [{"target_id": tgt["id"], "ts_ms": centre + 100.0}]}}
        res = C.resolve_minigame("target_burst", inst, inp)
        assert res["raw"]["p1"] >= C.TB_HIT_PTS  # counted as a hit
        # same tap without latency correction misses the centre bonus peak
        inp2 = {"p1": {"latency_ms": 0.0, "taps": [{"target_id": tgt["id"], "ts_ms": centre}]}}
        res2 = C.resolve_minigame("target_burst", inst, inp2)
        assert res2["raw"]["p1"] == pytest.approx(res["raw"]["p1"], abs=1.0)


class TestRhythmTapDeterminism:
    @pytest.mark.parametrize("seed", _SEEDS)
    def test_same_seed_inputs_identical(self, seed):
        inst = C.build_minigame("rhythm_tap", seed, 0)
        inp = {"p1": C.ai_minigame_inputs("rhythm_tap", inst, "p1", seed)}
        r1 = C.resolve_minigame("rhythm_tap", inst, inp)
        r2 = C.resolve_minigame("rhythm_tap", inst, inp)
        assert r1 == r2

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_perfect_taps_max_score(self, seed):
        inst = C.build_minigame("rhythm_tap", seed, 0)
        # tap exactly on every beat -> all perfect -> raw == raw_max
        inp = {"p1": {"latency_ms": 0.0, "taps": list(inst["beats"])}}
        res = C.resolve_minigame("rhythm_tap", inst, inp)
        assert res["raw"]["p1"] == res["raw_max"]
        assert res["detail"]["p1"]["perfect"] == len(inst["beats"])

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_bpm_in_range(self, seed):
        inst = C.build_minigame("rhythm_tap", seed, 0)
        assert C.RT_BPM_MIN <= inst["bpm"] <= C.RT_BPM_MAX


# ── Second-pass mini-games (registered from lib/minigames/*) ─────────────────

class TestHoldTheFlagDeterminism:
    """Hold the Flag (area control) — bare-list tick-move input, like maze."""

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_instance_is_deterministic(self, seed):
        i1 = C.build_minigame("hold_the_flag", seed, 0)
        i2 = C.build_minigame("hold_the_flag", seed, 0)
        assert i1 == i2
        assert i1["w"] == 7 and i1["h"] == 7
        assert len(i1["hazards"]) >= 1

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_same_seed_inputs_identical_result(self, seed):
        inst = C.build_minigame("hold_the_flag", seed, 0)
        inp = {
            "p1": C.ai_minigame_inputs("hold_the_flag", inst, "p1", seed),
            "p2": C.ai_minigame_inputs("hold_the_flag", inst, "p2", seed),
        }
        r1 = C.resolve_minigame("hold_the_flag", inst, inp)
        r2 = C.resolve_minigame("hold_the_flag", inst, inp)
        assert r1 == r2

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_perfect_hold_reaches_raw_max(self, seed):
        # Walk from the spawn corner onto the hill centre, then hold — the hill
        # zone is guaranteed hazard-free by design, so full control == raw_max.
        inst = C.build_minigame("hold_the_flag", seed, 0)
        cx, cy = inst["hill_center"]
        px, py = inst["spawn"]
        moves = []
        for t in range(inst["ticks"]):
            if px < cx:
                mv = "right"; px += 1
            elif py < cy:
                mv = "down"; py += 1
            else:
                mv = "stay"
            moves.append({"tick": t, "move": mv})
        res = C.resolve_minigame("hold_the_flag", inst, {"perfect": moves})
        assert res["raw"]["perfect"] == res["raw_max"]
        assert C.normalize_scores(res["raw"], res["raw_max"])["perfect"] == 100

    def test_tolerates_empty_and_unknown_moves(self):
        inst = C.build_minigame("hold_the_flag", 5, 0)
        res = C.resolve_minigame("hold_the_flag", inst, {
            "empty": [],
            "junk": [{"tick": 0, "move": "teleport"}, {"tick": 999, "move": "up"}],
        })
        assert set(res["raw"]) == {"empty", "junk"}
        assert all(v >= 0 for v in res["raw"].values())


class TestShortRaceDeterminism:
    """Short Race (3-lane obstacle dodge) — bare-list tick-move input."""

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_instance_is_deterministic(self, seed):
        i1 = C.build_minigame("short_race", seed, 0)
        i2 = C.build_minigame("short_race", seed, 0)
        assert i1 == i2
        assert i1["lanes"] == 3

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_never_all_lanes_blocked(self, seed):
        # A perfect run must always be possible: no step blocks all 3 lanes.
        inst = C.build_minigame("short_race", seed, 0)
        by_step = {}
        for o in inst["obstacles"]:
            by_step.setdefault(o["step"], set()).add(o["lane"])
        assert all(len(lanes) < inst["lanes"] for lanes in by_step.values())

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_same_seed_inputs_identical_result(self, seed):
        inst = C.build_minigame("short_race", seed, 0)
        inp = {
            "p1": C.ai_minigame_inputs("short_race", inst, "p1", seed),
            "p2": C.ai_minigame_inputs("short_race", inst, "p2", seed),
        }
        r1 = C.resolve_minigame("short_race", inst, inp)
        r2 = C.resolve_minigame("short_race", inst, inp)
        assert r1 == r2

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_perfect_dodge_reaches_raw_max(self, seed):
        # The module guarantees a perfect run exists: obstacles and coins are
        # laid out around a seeded obstacle-free reference path. Following that
        # exact reference path dodges everything and grabs every coin -> raw_max.
        from lib.minigames import short_race as SR
        inst = C.build_minigame("short_race", seed, 0)
        path = SR._reference_path(inst["seed"])  # instance sub-seed drives layout
        lane = inst["spawn_lane"]
        moves = []
        for step in range(1, inst["steps"]):
            target = path[step]
            mv = "left" if target < lane else ("right" if target > lane else "stay")
            lane = max(0, min(2, lane + {"left": -1, "right": 1, "stay": 0}[mv]))
            moves.append({"tick": step, "move": mv})
        res = C.resolve_minigame("short_race", inst, {"perfect": moves})
        assert res["raw"]["perfect"] == res["raw_max"]
        assert C.normalize_scores(res["raw"], res["raw_max"])["perfect"] == 100
        assert res["detail"]["perfect"]["clean_run"] is True

    def test_tolerates_empty_and_unknown_moves(self):
        inst = C.build_minigame("short_race", 5, 0)
        res = C.resolve_minigame("short_race", inst, {
            "empty": [],
            "junk": [{"tick": 1, "move": "jump"}, {"bad": "shape"}],
        })
        assert set(res["raw"]) == {"empty", "junk"}


class TestNewGamesInRotationAndReplay:
    """The two new games must appear in the seeded rotation and replay-validate."""

    def test_both_new_games_are_registered(self):
        assert "hold_the_flag" in C.MINIGAMES
        assert "short_race" in C.MINIGAMES
        assert "hold_the_flag" in C._BUILDERS and "hold_the_flag" in C._RESOLVERS
        assert "short_race" in C._BUILDERS and "short_race" in C._RESOLVERS

    def test_pick_minigame_can_select_new_games(self):
        picks = {C.pick_minigame(s, r) for s in range(200) for r in range(8)}
        assert "hold_the_flag" in picks
        assert "short_race" in picks


# ══════════════════════════════════════════════════════════════════════════
#  Normalization comparability
# ══════════════════════════════════════════════════════════════════════════

class TestNormalization:
    def test_full_score_maps_to_100_across_games(self):
        # Game-agnostic: every registered mini-game's resolver reports the
        # theoretical raw_max for its seeded instance, so a full raw score must
        # normalize to 100 and a zero to 0 — regardless of how many games are
        # registered. (Adding a game must not require touching this test.)
        for game in C.MINIGAMES:
            inst = C.build_minigame(game, 42, 0)
            # any resolve on this instance exposes the instance's raw_max
            probe = C.resolve_minigame(game, inst, {})
            raw_max = probe["raw_max"]
            assert raw_max > 0, f"{game} raw_max should be positive"
            norm = C.normalize_scores({"a": raw_max, "b": 0.0}, raw_max)
            assert norm["a"] == 100, f"{game} full score should map to 100"
            assert norm["b"] == 0, f"{game} zero should map to 0"

    def test_normalization_is_monotonic(self):
        norm = C.normalize_scores({"a": 25, "b": 50, "c": 75}, 100)
        assert norm["a"] < norm["b"] < norm["c"]

    def test_zero_raw_max_is_safe(self):
        assert C.normalize_scores({"a": 5}, 0) == {"a": 0}


# ══════════════════════════════════════════════════════════════════════════
#  Catch-up mechanic
# ══════════════════════════════════════════════════════════════════════════

class TestCatchup:
    def test_leader_gets_no_bonus(self):
        assert C.catchup_multiplier(100, 100) == 1.0

    def test_trailing_gets_bonus_capped(self):
        assert C.catchup_multiplier(90, 100) == pytest.approx(1.2)   # 10 gap * 2%
        assert C.catchup_multiplier(0, 1000) == pytest.approx(1.5)   # capped +50%

    def test_bigger_deficit_never_smaller_bonus(self):
        prev = 1.0
        for gap in range(0, 60, 5):
            m = C.catchup_multiplier(100 - gap, 100)
            assert m >= prev
            prev = m


# ══════════════════════════════════════════════════════════════════════════
#  Board loop integrity
# ══════════════════════════════════════════════════════════════════════════

class TestBoardLoop:
    def _run_full(self, seed, rounds=8):
        b = C.CarnivalBoard.create(seed, [{"player_id": "p1"}, {"player_id": "p2"}], rounds=rounds)
        b.spin_and_advance()
        guard = 0
        while b.status == "active" and guard < 2000:
            if b.pending_minigame:
                b.submit_minigame({})
            else:
                b.spin_and_advance()
            guard += 1
        return b

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_full_match_finishes(self, seed):
        b = self._run_full(seed)
        assert b.status == "finished"
        assert b.round_index == 8

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_match_is_fully_deterministic(self, seed):
        a = self._run_full(seed)
        b = self._run_full(seed)
        assert [(p.player_id, p.total()) for p in a.players] == \
               [(p.player_id, p.total()) for p in b.players]

    def test_board_is_24_spaces_with_minigames(self):
        board = C.build_board(123)
        assert len(board) == C.BOARD_SIZE
        assert any(s["type"] == "MINIGAME" for s in board)
        assert board[0]["type"] == "PRIZE"

    def test_spinner_deterministic(self):
        rolls_a = [C.spinner_roll(555, i) for i in range(10)]
        rolls_b = [C.spinner_roll(555, i) for i in range(10)]
        assert rolls_a == rolls_b
        assert all(1 <= r <= 10 for r in rolls_a)

    def test_ai_fill_reaches_two_players(self):
        b = C.CarnivalBoard.create(9, [{"player_id": "solo"}])
        assert len(b.players) >= 2
        assert any(p.is_ai for p in b.players)

    def test_players_have_distinct_shapes(self):
        b = C.CarnivalBoard.create(9, [{"player_id": f"p{i}"} for i in range(4)])
        shapes = [p.shape for p in b.players]
        assert len(set(shapes)) == len(shapes)  # colorblind-distinguishable


# ══════════════════════════════════════════════════════════════════════════
#  HTTP router + replay round-trip
# ══════════════════════════════════════════════════════════════════════════

_app = FastAPI()
_app.include_router(carnival_router)
_USER = User(user_id="carn_user", email="c@fellab.io", name="Carn User")


def _client():
    _app.dependency_overrides[get_carnival_user] = lambda: _USER
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear():
    _boards.clear()
    _events.clear()
    _meta.clear()
    yield
    _boards.clear()
    _events.clear()
    _meta.clear()


def _drive_full_match(client, mid):
    """Spin + auto-submit mini-games until the match finishes."""
    guard = 0
    while guard < 500:
        state = client.get(f"/api/carnival/{mid}").json()
        if state["status"] == "finished":
            break
        if state["pending_minigame"]:
            client.post(f"/api/carnival/{mid}/minigame/submit", json={"inputs": {}})
        else:
            client.post(f"/api/carnival/{mid}/spin")
        guard += 1


class TestRouter:
    def test_create_recording_match_fills_ai(self):
        c = _client()
        resp = c.post("/api/carnival/create", json={"recording": True, "seed": 777})
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["players"]) == 4
        assert data["recording"] is True
        assert data["seed"] == 777

    def test_full_recorded_match_and_replay_validates(self):
        c = _client()
        mid = c.post("/api/carnival/create", json={"recording": True, "seed": 2024}).json()["match_id"]
        _drive_full_match(c, mid)
        state = c.get(f"/api/carnival/{mid}").json()
        assert state["status"] == "finished"

        replay = c.get(f"/api/carnival/{mid}/export-replay").json()
        assert replay["metadata"]["replay_kind"] == "carnival"
        errors = validate_carnival_replay(replay)
        assert errors == [], f"replay validation failed: {errors}"

    def test_export_has_minigame_and_spin_events(self):
        c = _client()
        mid = c.post("/api/carnival/create", json={"recording": True, "seed": 55}).json()["match_id"]
        _drive_full_match(c, mid)
        replay = c.get(f"/api/carnival/{mid}/export-replay").json()
        types_ = {e["type"] for e in replay["events"]}
        assert "carnival_match_start" in types_
        assert "carnival_spin" in types_
        assert "carnival_minigame_result" in types_
        assert "carnival_match_end" in types_

    def test_highlights_endpoint(self):
        c = _client()
        mid = c.post("/api/carnival/create", json={"recording": True, "seed": 88}).json()["match_id"]
        _drive_full_match(c, mid)
        hl = c.get(f"/api/carnival/{mid}/highlights").json()
        assert "highlights" in hl and "final_standings" in hl
        assert len(hl["final_standings"]) == 4

    def test_local_client_replay_is_not_re_resolved(self):
        # A client-local capture (JS-engine scores, not byte-identical to the
        # Python engine) is tagged carnival_local / authoritative:false, so the
        # validator passes it through instead of reporting a false mismatch.
        from tools.replay_validator import validate_replay
        c = _client()
        mid = c.post("/api/carnival/create", json={"recording": True, "seed": 3}).json()["match_id"]
        _drive_full_match(c, mid)
        replay = c.get(f"/api/carnival/{mid}/export-replay").json()
        # simulate a client-local export: relabel + corrupt a score
        replay["metadata"]["replay_kind"] = "carnival_local"
        replay["metadata"]["authoritative"] = False
        for ev in replay["events"]:
            if ev["type"] == "carnival_minigame_result":
                ev["raw"] = {k: -1 for k in ev["raw"]}
                break
        assert validate_replay(replay) == []  # not re-resolved, so no error

    def test_replay_tamper_is_detected(self):
        c = _client()
        mid = c.post("/api/carnival/create", json={"recording": True, "seed": 12}).json()["match_id"]
        _drive_full_match(c, mid)
        replay = c.get(f"/api/carnival/{mid}/export-replay").json()
        for ev in replay["events"]:
            if ev["type"] == "carnival_minigame_result":
                ev["normalized"] = {k: 999 for k in ev["normalized"]}
                break
        errors = validate_carnival_replay(replay)
        assert errors, "tampered normalized scores should be caught"
