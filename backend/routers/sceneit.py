"""
FEL OS — Who Scene It (nexus/sceneit-demo)

Scene It!-inspired visual-puzzle trivia with buzz-in risk scoring.

Core fairness contract (server-authoritative):
  - Question order and option order are seeded server-side (64-bit seed).
  - Answer options stay HIDDEN until the requesting player buzzes.
  - Potential score counts DOWN server-side; the buzz locks it.
  - ~4s lock-in window after buzz; wrong buzz LOSES points.
  - Reveal timing (frame-freeze tiles, credit lines) is computed from the
    server clock — clients cannot peek ahead.

Endpoints:
  GET  /api/sceneit/rounds                       — round registry (implemented vs stub)
  GET  /api/sceneit/content/films                — film list + provenance (QA license audit)
  GET  /api/sceneit/stills/{scene_id}.svg        — generated original placeholder still
  GET  /api/creators/{creator_id}                — cached Creator Card deep-dive payload
  GET  /api/creators/{creator_id}/collection     — collection loop stub marker
  GET  /api/music/creator/{creator_id}/tracks    — jukebox tracks (MusicProviderModule seam)
  GET  /api/music/preview/{filename}             — Tier-1 CC0 demo audio (discovery only)
  POST /api/sceneit/match/create                 — seeded match (round_types, num_questions)
  GET  /api/sceneit/match/{id}/state             — per-player view (options gated on buzz)
  POST /api/sceneit/match/{id}/buzz              — lock the countdown potential
  POST /api/sceneit/match/{id}/answer            — resolve inside the lock-in window
  POST /api/sceneit/match/{id}/next              — advance question / finish match
  GET  /api/sceneit/match/{id}/export-replay     — seed + buzz timestamps + answers
"""
import os
import random
import sys
import time
import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel, Field

from lib.match_utils import generate_seed
from lib.music_providers import CC0_AUDIO_DIR, get_music_provider
from lib.sceneit.cards import CardProvider
from lib.sceneit.content import SceneContentModule, get_default_provider
from lib.sceneit.rounds import Question, get_round, list_rounds
from lib.sceneit.scoring import BuzzRiskScoring, ScoringModule
from lib.sceneit.stills import render_still

router = APIRouter(tags=["sceneit"])

_MOCK_DB = os.environ.get("MOCK_DB", "0") == "1" or (
    len(sys.argv) > 0 and "pytest" in sys.argv[0]
)

# Injectable server clock (ms). Tests monkeypatch this for deterministic timing.
def _now_ms() -> int:
    return int(time.monotonic() * 1000)


# ── Match engine (core loop — talks ONLY to module seams) ──────────────────

class SceneItMatch:
    def __init__(
        self,
        match_id: str,
        seed: int,
        round_types: List[str],
        num_questions: int,
        players: List[str],
        content: Optional[SceneContentModule] = None,
        scoring: Optional[ScoringModule] = None,
    ):
        self.match_id = match_id
        self.seed = seed
        self.round_types = round_types
        self.players = list(players)
        self.scores: Dict[str, int] = {p: 0 for p in players}
        self.content = content or get_default_provider()
        self.scoring = scoring or BuzzRiskScoring()
        self.status = "active"
        self.events: List[Dict[str, Any]] = []
        self.questions: List[Question] = self._build_questions(num_questions)
        self.current_index = 0
        self.question_started_ms = _now_ms()
        # per-question live state
        self.active_buzz: Optional[Dict[str, Any]] = None   # {player_id, elapsed_ms, potential}
        self.attempted: set = set()                          # players locked out this question
        self.resolved = False
        self.last_result: Optional[Dict[str, Any]] = None
        self.timeline: List[Dict[str, Any]] = []             # per-question reveal timeline
        self._append_event("match_start", {
            "seed": seed, "round_types": round_types,
            "question_count": len(self.questions), "players": list(players),
            "scoring": {"id": self.scoring.scoring_id, "config": self.scoring.config.to_dict()},
        })
        self._append_event("question_start", self._question_meta())

    # -- deterministic construction ------------------------------------------------
    def _build_questions(self, num_questions: int) -> List[Question]:
        order_rng = random.Random(self.seed)
        scenes = sorted(self.content.scenes(), key=lambda s: s["scene_id"])
        order_rng.shuffle(scenes)
        questions: List[Question] = []
        for i in range(min(num_questions, len(scenes))):
            round_type = self.round_types[i % len(self.round_types)]
            module = get_round(round_type)
            q_rng = random.Random((self.seed << 8) ^ (i * 0x9E3779B1) & 0xFFFFFFFFFFFFFFFF)
            questions.append(module.build_question(i, scenes[i], self.content, q_rng))
        return questions

    # -- helpers ---------------------------------------------------------------
    def _append_event(self, etype: str, payload: Dict[str, Any]) -> None:
        self.events.append({"type": etype, "seq": len(self.events), **payload})

    def _question_meta(self) -> Dict[str, Any]:
        q = self.questions[self.current_index]
        return {"question_index": self.current_index, "question_id": q.question_id,
                "round_type": q.round_type, "correct_option_id": q.correct_option_id}

    @property
    def question(self) -> Question:
        return self.questions[self.current_index]

    def elapsed_ms(self) -> int:
        return _now_ms() - self.question_started_ms

    # -- core buzz-in risk loop --------------------------------------------------
    def buzz(self, player_id: str) -> Dict[str, Any]:
        if self.status != "active" or self.resolved:
            raise HTTPException(status_code=409, detail="No open question to buzz on")
        if player_id not in self.scores:
            raise HTTPException(status_code=403, detail="Player not in match")
        if player_id in self.attempted:
            raise HTTPException(status_code=409, detail="Player already attempted this question")
        if self.active_buzz is not None:
            raise HTTPException(status_code=409, detail="Another player holds the buzz")
        elapsed = self.elapsed_ms()
        potential = self.scoring.potential_at(elapsed)
        self.active_buzz = {"player_id": player_id, "elapsed_ms": elapsed, "potential": potential}
        self._append_event("buzz", {"question_index": self.current_index,
                                    "player_id": player_id, "elapsed_ms": elapsed,
                                    "potential": potential})
        return {"locked_potential": potential, "elapsed_ms": elapsed,
                "lock_in_ms": self.scoring.config.lock_in_ms,
                "options": self.question.options}

    def answer(self, player_id: str, option_id: Optional[str]) -> Dict[str, Any]:
        if self.status != "active" or self.resolved:
            raise HTTPException(status_code=409, detail="No open question to answer")
        if self.active_buzz is None or self.active_buzz["player_id"] != player_id:
            raise HTTPException(status_code=409, detail="Player does not hold the buzz")
        elapsed = self.elapsed_ms()
        q = self.question
        correct_pick = option_id == q.correct_option_id
        resolution = self.scoring.resolve(
            self.active_buzz["elapsed_ms"], elapsed if option_id is not None else None, correct_pick
        )
        self.scores[player_id] += resolution.delta
        self.attempted.add(player_id)
        result = {
            "question_index": self.current_index,
            "question_id": q.question_id,
            "player_id": player_id,
            "option_id": option_id,
            "buzz_elapsed_ms": self.active_buzz["elapsed_ms"],
            "answer_elapsed_ms": elapsed if option_id is not None else None,
            "potential": resolution.potential,
            "delta": resolution.delta,
            "correct": resolution.correct,
            "timed_out": resolution.timed_out,
            "score_snapshot": dict(self.scores),
        }
        self._append_event("answer", result)
        self.active_buzz = None
        if resolution.correct or len(self.attempted) >= len(self.players):
            self.resolved = True
            # content_refs (creator card link) only surface AFTER resolution —
            # pre-reveal they would leak the correct film.
            self.last_result = {**result, "correct_option_id": q.correct_option_id,
                                "options": q.options, "content_refs": q.content_refs}
            self.timeline.append({
                "question_index": self.current_index, "round_type": q.round_type,
                "winner": player_id if resolution.correct else None,
                "delta": resolution.delta, "correct_option_id": q.correct_option_id,
            })
            self._append_event("question_result", self.timeline[-1])
        reveal = dict(self.last_result) if self.resolved else None
        return {**result, "question_resolved": self.resolved, "reveal": reveal}

    def next_question(self) -> Dict[str, Any]:
        if self.status != "active":
            raise HTTPException(status_code=409, detail="Match not active")
        if not self.resolved:
            # skipping an unresolved question forfeits it (no score change)
            self.timeline.append({
                "question_index": self.current_index,
                "round_type": self.question.round_type,
                "winner": None, "delta": 0, "skipped": True,
                "correct_option_id": self.question.correct_option_id,
            })
            self._append_event("question_result", self.timeline[-1])
        if self.current_index + 1 >= len(self.questions):
            self.status = "finished"
            self._append_event("match_end", {"score": dict(self.scores)})
            return {"status": "finished", "score": self.scores}
        self.current_index += 1
        self.question_started_ms = _now_ms()
        self.active_buzz = None
        self.attempted = set()
        self.resolved = False
        self.last_result = None
        self._append_event("question_start", self._question_meta())
        return {"status": "active", "question_index": self.current_index}

    # -- per-player view (options gated on buzz) ---------------------------------
    def state_for(self, player_id: Optional[str]) -> Dict[str, Any]:
        elapsed = self.elapsed_ms()
        q = self.question
        module = get_round(q.round_type)
        holds_buzz = bool(self.active_buzz and player_id == self.active_buzz["player_id"])
        revealed = holds_buzz or self.resolved
        view = q.public_view(revealed=revealed)
        view["presentation"] = module.presentation_at(q, elapsed)
        state: Dict[str, Any] = {
            "match_id": self.match_id,
            "status": self.status,
            "question_index": self.current_index,
            "question_count": len(self.questions),
            "elapsed_ms": elapsed,
            "potential": self.scoring.potential_at(elapsed) if not self.resolved else 0,
            "scoring_config": self.scoring.config.to_dict(),
            "scores": dict(self.scores),
            "players": list(self.players),
            "question": view,
            "buzz": None,
            "you_attempted": player_id in self.attempted,
            "resolved": self.resolved,
            "reveal": self.last_result if self.resolved else None,
            "timeline": list(self.timeline),
        }
        if self.active_buzz:
            remaining = self.scoring.config.lock_in_ms - (elapsed - self.active_buzz["elapsed_ms"])
            state["buzz"] = {
                "player_id": self.active_buzz["player_id"],
                "locked_potential": self.active_buzz["potential"],
                "lock_in_remaining_ms": max(0, remaining),
                "you_hold_buzz": holds_buzz,
            }
        return state

    def export_replay(self) -> Dict[str, Any]:
        return {
            "metadata": {
                "match_id": self.match_id,
                "mode_id": "who_scene_it_v2",
                "seed": self.seed,
                "round_types": self.round_types,
                "question_count": len(self.questions),
                "players": list(self.players),
                "status": self.status,
                "scoring": {"id": self.scoring.scoring_id, "config": self.scoring.config.to_dict()},
                "content_provider": self.content.provider_id,
                "export_version": "1.0",
                "event_count": len(self.events),
            },
            "events": list(self.events),
        }


_matches: Dict[str, SceneItMatch] = {}
_cards = CardProvider()


# ── Schemas ────────────────────────────────────────────────────────────────

class CreateSceneItMatch(BaseModel):
    players: List[str] = Field(default_factory=lambda: ["player_1"])
    round_types: List[str] = Field(default_factory=lambda: ["invisibles"])
    num_questions: int = 6
    # Deterministic replays/tests only — honored solely under MOCK_DB=1.
    seed: Optional[int] = None


class BuzzRequest(BaseModel):
    player_id: str


class AnswerRequest(BaseModel):
    player_id: str
    option_id: Optional[str] = None  # None = give up / timed out client-side


# ── Round registry + content QA endpoints ─────────────────────────────────

@router.get("/api/sceneit/rounds")
async def sceneit_rounds() -> Dict[str, Any]:
    return {"rounds": list_rounds()}


@router.get("/api/sceneit/content/films")
async def sceneit_films() -> Dict[str, Any]:
    """QA license audit view: every item's source + license, no answers leaked."""
    content = get_default_provider()
    return {
        "provider": content.provider_id,
        "films": [
            {"film_id": f["film_id"], "title": f["title"], "year": f["year"],
             "source": f["source"], "license": f["license"],
             "scene_count": len(f.get("scenes", []))}
            for f in content.films()
        ],
    }


@router.get("/api/sceneit/stills/{scene_id}.svg")
async def sceneit_still(scene_id: str, mask: Optional[str] = None,
                        reveal: Optional[int] = None) -> Response:
    content = get_default_provider()
    scene = next((s for s in content.scenes() if s["scene_id"] == scene_id), None)
    if scene is None:
        raise HTTPException(status_code=404, detail="Scene not found")
    svg = render_still(scene, mask=mask, reveal=reveal)
    return Response(content=svg, media_type="image/svg+xml",
                    headers={"Cache-Control": "public, max-age=3600"})


# ── Creator metadata (CardModule seam) ─────────────────────────────────────

@router.get("/api/creators/{creator_id}")
async def get_creator(creator_id: str) -> Dict[str, Any]:
    """Cached Creator Card deep-dive: bio, timeline, top works, lesson stub."""
    card = _cards.card(creator_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Creator not found")
    return card


@router.get("/api/creators/{creator_id}/collection")
async def get_creator_collection(creator_id: str, player_id: str = "anonymous") -> Dict[str, Any]:
    return _cards.collection_for(player_id)


# ── Jukebox (MusicProviderModule seam) ─────────────────────────────────────
# DISCOVERY ONLY: playback is deliberately decoupled from match state — no
# points, unlocks, or penalties may ever hinge on listening (Spotify developer
# policy prohibits games/gameplay-coupled playback; see lib/music_providers.py).

@router.get("/api/music/creator/{creator_id}/tracks")
async def get_creator_tracks(creator_id: str, provider: str = "mock_cc0") -> Dict[str, Any]:
    """Resolve a creator's MUSIC card section through the music provider seam."""
    card = _cards.card(creator_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Creator not found")
    try:
        music_provider = get_music_provider(provider)
    except KeyError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    track_refs = card.get("sections", {}).get("music", [])
    return {
        "creator_id": creator_id,
        "creator_name": card["name"],
        "provider": music_provider.provider_id,
        "branding": music_provider.provider_branding(),
        "tracks": music_provider.get_creator_tracks(creator_id, track_refs),
    }


@router.get("/api/music/preview/{filename}")
async def music_preview(filename: str) -> FileResponse:
    """Serve a Tier-1 CC0 demo clip. Whitelisted to the checked-in CC0 pack;
    higher-tier providers embed from their own hosts (audio is never proxied)."""
    safe = os.path.basename(filename)
    path = os.path.join(CC0_AUDIO_DIR, safe)
    if safe != filename or not os.path.isfile(path) or not safe.endswith((".ogg", ".m4a")):
        raise HTTPException(status_code=404, detail="Unknown preview clip")
    media_type = "audio/ogg" if safe.endswith(".ogg") else "audio/mp4"
    return FileResponse(path, media_type=media_type,
                        headers={"Cache-Control": "public, max-age=3600"})


# ── Match lifecycle ────────────────────────────────────────────────────────

@router.post("/api/sceneit/match/create")
async def create_sceneit_match(body: CreateSceneItMatch) -> Dict[str, Any]:
    for rt in body.round_types:
        rounds = {r["round_type"]: r for r in list_rounds()}
        if rt not in rounds:
            raise HTTPException(status_code=422, detail=f"Unknown round type {rt!r}")
        if not rounds[rt]["implemented"]:
            raise HTTPException(status_code=422, detail=f"Round type {rt!r} is a stub (not implemented)")
    if not body.players:
        raise HTTPException(status_code=422, detail="At least one player required")
    seed = body.seed if (body.seed is not None and _MOCK_DB) else generate_seed()
    match_id = str(uuid.uuid4())[:12]
    match = SceneItMatch(
        match_id=match_id, seed=seed, round_types=body.round_types,
        num_questions=body.num_questions, players=body.players,
    )
    _matches[match_id] = match
    return {"match_id": match_id, "seed": seed, "status": match.status,
            "question_count": len(match.questions),
            "scoring_config": match.scoring.config.to_dict()}


def _get_match(match_id: str) -> SceneItMatch:
    match = _matches.get(match_id)
    if match is None:
        raise HTTPException(status_code=404, detail="Match not found")
    return match


@router.get("/api/sceneit/match/{match_id}/state")
async def sceneit_state(match_id: str, player_id: Optional[str] = None) -> Dict[str, Any]:
    return _get_match(match_id).state_for(player_id)


@router.post("/api/sceneit/match/{match_id}/buzz")
async def sceneit_buzz(match_id: str, body: BuzzRequest) -> Dict[str, Any]:
    return _get_match(match_id).buzz(body.player_id)


@router.post("/api/sceneit/match/{match_id}/answer")
async def sceneit_answer(match_id: str, body: AnswerRequest) -> Dict[str, Any]:
    return _get_match(match_id).answer(body.player_id, body.option_id)


@router.post("/api/sceneit/match/{match_id}/next")
async def sceneit_next(match_id: str) -> Dict[str, Any]:
    return _get_match(match_id).next_question()


@router.get("/api/sceneit/match/{match_id}/export-replay")
async def sceneit_export_replay(match_id: str) -> Dict[str, Any]:
    return _get_match(match_id).export_replay()
