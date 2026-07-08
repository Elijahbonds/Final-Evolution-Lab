"""
rounds.py — RoundModule seam + registry.

Each round type is a swappable class registered in ROUND_REGISTRY. The core
match loop (routers/sceneit.py) only calls the RoundModule interface, so new
round types drop in via @register_round without touching the loop.

Implemented (demo): invisibles, frame_freeze, credit_roll.
Registered stubs (marked not-implemented): quick_pitch, chrono_order.
"""
import random
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Tuple, Type

from .content import SceneContentModule


class Question:
    """Built server-side per question. Options stay hidden until buzz."""

    def __init__(
        self,
        question_id: str,
        round_type: str,
        prompt: str,
        options: List[Dict[str, str]],       # [{"option_id","label"}] — pre-shuffled
        correct_option_id: str,
        media: Dict[str, Any],               # presentation payload (still url, mask, credits...)
        content_refs: Dict[str, Any],        # film_id / scene_id / creator_id / card_id
        provenance: Dict[str, str],          # source + license (QA-checkable per question)
    ):
        self.question_id = question_id
        self.round_type = round_type
        self.prompt = prompt
        self.options = options
        self.correct_option_id = correct_option_id
        self.media = media
        self.content_refs = content_refs
        self.provenance = provenance

    def public_view(self, revealed: bool) -> Dict[str, Any]:
        """What a client may see. Options only after the requesting player buzzed."""
        view = {
            "question_id": self.question_id,
            "round_type": self.round_type,
            "prompt": self.prompt,
            "media": self.media,
            "provenance": self.provenance,
        }
        if revealed:
            view["options"] = self.options
        return view


class RoundModule(ABC):
    """Swappable round-type seam."""

    round_type: str = "abstract"
    display_name: str = "Abstract Round"
    description: str = ""
    implemented: bool = True

    @abstractmethod
    def build_question(
        self, index: int, scene: Dict[str, Any], content: SceneContentModule, rng: random.Random
    ) -> Question:
        """Build one deterministic question from a scene. `rng` is seeded by the
        match seed + question index; use it for ALL randomness (distractors,
        option shuffle) so replays reproduce exactly."""

    def presentation_at(self, question: Question, elapsed_ms: int) -> Dict[str, Any]:
        """Server-controlled reveal timing: what extra presentation state the
        client gets `elapsed_ms` after the question started (fairness: the
        server, not the client, decides what is visible when)."""
        return {}


ROUND_REGISTRY: Dict[str, Type[RoundModule]] = {}


def register_round(cls: Type[RoundModule]) -> Type[RoundModule]:
    ROUND_REGISTRY[cls.round_type] = cls
    return cls


def get_round(round_type: str) -> RoundModule:
    if round_type not in ROUND_REGISTRY:
        raise KeyError(f"Unknown round type: {round_type!r}")
    return ROUND_REGISTRY[round_type]()


def list_rounds() -> List[Dict[str, Any]]:
    return [
        {
            "round_type": cls.round_type,
            "display_name": cls.display_name,
            "description": cls.description,
            "implemented": cls.implemented,
        }
        for cls in ROUND_REGISTRY.values()
    ]


# ── Shared helpers ─────────────────────────────────────────────────────────

def _film_title_options(
    correct_film_id: str, content: SceneContentModule, rng: random.Random, n: int = 4
) -> Tuple[List[Dict[str, str]], str]:
    """4 film-title options (1 correct + seeded distractors), seeded shuffle."""
    films = sorted(content.films(), key=lambda f: f["film_id"])  # stable base order
    correct = next(f for f in films if f["film_id"] == correct_film_id)
    distractors = [f for f in films if f["film_id"] != correct_film_id]
    picks = rng.sample(distractors, min(n - 1, len(distractors)))
    options = [{"option_id": f["film_id"], "label": f["title"]} for f in [correct] + picks]
    rng.shuffle(options)
    return options, correct_film_id


def _scene_provenance(scene: Dict[str, Any]) -> Dict[str, str]:
    return {"source": scene.get("source", ""), "license": scene.get("license", "")}


def _card_ref(film: Dict[str, Any]) -> Dict[str, Any]:
    """CardModule seam: each question links to a collectible Creator Card."""
    director_id = film.get("director_id")
    return {"creator_id": director_id, "card_id": f"card_{director_id}"}


# ── Implemented rounds ─────────────────────────────────────────────────────

@register_round
class InvisiblesRound(RoundModule):
    """An element is blanked/masked out of a scene still — identify the film."""

    round_type = "invisibles"
    display_name = "Invisibles"
    description = "One element has vanished from the still. Name the film it belongs to."

    def build_question(self, index, scene, content, rng) -> Question:
        film = content.film(scene["film_id"])
        still = scene["still"]
        masked_id = still.get("invisibles_element") or still["elements"][0]["id"]
        masked = next(e for e in still["elements"] if e["id"] == masked_id)
        options, correct = _film_title_options(scene["film_id"], content, rng)
        return Question(
            question_id=f"q{index}_{self.round_type}_{scene['scene_id']}",
            round_type=self.round_type,
            prompt=f"Something is missing from this still — {masked['label']} has gone invisible. Which film is this scene from?",
            options=options,
            correct_option_id=correct,
            media={
                "kind": "still",
                "still_url": f"/api/sceneit/stills/{scene['scene_id']}.svg?mask={masked_id}",
                "masked_element": {"id": masked_id, "label": masked["label"]},
                "scene_description": scene["description"],
            },
            content_refs={"film_id": scene["film_id"], "scene_id": scene["scene_id"], **_card_ref(film)},
            provenance=_scene_provenance(scene),
        )


@register_round
class FrameFreezeRound(RoundModule):
    """A still progressively unmasks tile by tile — identify the film early for max points."""

    round_type = "frame_freeze"
    display_name = "Frame Freeze"
    description = "The frozen frame reveals itself tile by tile. Buzz early, score big."

    REVEAL_STAGES = 5           # 0 (fully covered) .. 4 (nearly clear)
    STAGE_MS = 4_000            # server-controlled: one stage every 4s

    def build_question(self, index, scene, content, rng) -> Question:
        film = content.film(scene["film_id"])
        options, correct = _film_title_options(scene["film_id"], content, rng)
        return Question(
            question_id=f"q{index}_{self.round_type}_{scene['scene_id']}",
            round_type=self.round_type,
            prompt="The frame is unfreezing. Which film is this scene from?",
            options=options,
            correct_option_id=correct,
            media={
                "kind": "still_progressive",
                # reveal stage is appended by presentation_at (server-timed)
                "still_url_template": f"/api/sceneit/stills/{scene['scene_id']}.svg?reveal={{stage}}",
                "reveal_stages": self.REVEAL_STAGES,
                "stage_ms": self.STAGE_MS,
                "scene_description": scene["description"],
            },
            content_refs={"film_id": scene["film_id"], "scene_id": scene["scene_id"], **_card_ref(film)},
            provenance=_scene_provenance(scene),
        )

    def presentation_at(self, question: Question, elapsed_ms: int) -> Dict[str, Any]:
        stage = min(self.REVEAL_STAGES - 1, max(0, int(elapsed_ms) // self.STAGE_MS))
        return {
            "reveal_stage": stage,
            "still_url": question.media["still_url_template"].format(stage=stage),
        }


@register_round
class CreditRollRound(RoundModule):
    """Credits scroll line by line — name the in-universe film they belong to."""

    round_type = "credit_roll"
    display_name = "Credit Roll"
    description = "The credits are rolling. Name the film before the last card."

    LINE_MS = 2_500             # server-controlled: one credit line every 2.5s

    def build_question(self, index, scene, content, rng) -> Question:
        film = content.film(scene["film_id"])
        options, correct = _film_title_options(scene["film_id"], content, rng)
        # Never include the title itself in rolled credits.
        credits = [c for c in film.get("credits", []) if film["title"].lower() not in c.lower()]
        return Question(
            question_id=f"q{index}_{self.round_type}_{film['film_id']}",
            round_type=self.round_type,
            prompt="These credits are rolling for which film?",
            options=options,
            correct_option_id=correct,
            media={
                "kind": "credit_roll",
                "credits": credits,        # full list; server gates visibility via presentation_at
                "line_ms": self.LINE_MS,
            },
            content_refs={"film_id": film["film_id"], **_card_ref(film)},
            provenance={"source": film.get("source", ""), "license": film.get("license", "")},
        )

    def presentation_at(self, question: Question, elapsed_ms: int) -> Dict[str, Any]:
        total = len(question.media["credits"])
        visible = min(total, 1 + int(elapsed_ms) // self.LINE_MS)
        return {"visible_credits": question.media["credits"][:visible], "visible_count": visible}


# ── Registered stubs (P3+: intentionally not implemented in this demo) ────

@register_round
class QuickPitchRound(RoundModule):
    round_type = "quick_pitch"
    display_name = "Quick Pitch"
    description = "STUB — hear a garbled one-line pitch, name the film. Not implemented in this demo."
    implemented = False

    def build_question(self, index, scene, content, rng) -> Question:
        raise NotImplementedError("quick_pitch is a registered stub (see PR notes)")


@register_round
class ChronoOrderRound(RoundModule):
    round_type = "chrono_order"
    display_name = "Chrono-Order"
    description = "STUB — put in-universe films in release order. Not implemented in this demo."
    implemented = False

    def build_question(self, index, scene, content, rng) -> Question:
        raise NotImplementedError("chrono_order is a registered stub (see PR notes)")
