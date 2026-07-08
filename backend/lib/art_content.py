"""
art_content.py — Server-side content bank for Art Showcase Mode micro-games.

All content here is ORIGINAL or CC0 (see infra/ASSET_ATTRIBUTION.md). The
guess-the-technique question bank keeps its *answers server-side*: the round
endpoint ships options in a deterministic seeded order but NOT the correct
index, and never the reveal text, until the client submits an answer. This
mirrors the Brain Brawl / Who Scene It principle (deterministic order from a
seed, answers resolved server-side, not shipped pre-resolution) without
importing that mode's implementation.
"""
import hashlib
import hmac
from typing import Any, Dict, List

# Deterministic round-token secret. Not a real credential — a stable constant
# so the same (seed, question) pair always produces the same opaque token and
# tokens can be re-verified on answer submission without server state.
_ROUND_SECRET = b"fel-art-mode-guess-technique-v1"

# Sample gallery / model assets used across the mode (all CC0 / original).
# `path` is an asset reference (never a binary). Frontend resolves these
# against /nexus-art-assets (see frontend/public).
SAMPLE_EXHIBIT_ITEMS: List[Dict[str, Any]] = [
    {
        "type": "image",
        "path": "/nexus-art-assets/images/aurora_gradient.svg",
        "meta": {
            "title": "Aurora Field",
            "alt": "Abstract vertical gradient bands in cyan and violet evoking an aurora.",
            "technique": "digital_gradient",
            "tools": ["vector", "gradient mesh"],
            "artist": "FEL Studio",
            "artist_bio": "Original generative work produced for Final Evolution Lab.",
            "source": "original",
            "license": "CC0-1.0",
            "card_id": "card_visionary_01",
        },
    },
    {
        "type": "image",
        "path": "/nexus-art-assets/images/geo_facets.svg",
        "meta": {
            "title": "Geo Facets",
            "alt": "Low-poly faceted triangular composition in purple and blue tones.",
            "technique": "low_poly",
            "tools": ["vector", "triangulation"],
            "artist": "FEL Studio",
            "artist_bio": "Original generative work produced for Final Evolution Lab.",
            "source": "original",
            "license": "CC0-1.0",
            "card_id": "card_visionary_01",
        },
    },
    {
        "type": "image",
        "path": "/nexus-art-assets/images/ink_flow.svg",
        "meta": {
            "title": "Ink Flow",
            "alt": "Flowing monochrome ink-wash curves suggesting movement.",
            "technique": "ink_wash",
            "tools": ["brush", "ink"],
            "artist": "FEL Studio",
            "artist_bio": "Original generative work produced for Final Evolution Lab.",
            "source": "original",
            "license": "CC0-1.0",
            "card_id": "card_curator_01",
        },
    },
    {
        "type": "model",
        "path": "/nexus-art-assets/models/box.gltf",
        "meta": {
            "title": "Study Cube",
            "alt": "A simple shaded 3D cube presented as a sculpture study.",
            "technique": "3d_modeling",
            "tools": ["glTF", "PBR"],
            "artist": "Khronos Group",
            "artist_bio": "Reference glTF sample geometry, public domain.",
            "source": "Khronos glTF-Sample-Assets (Box)",
            "license": "CC0-1.0",
            "card_id": "card_visionary_01",
        },
    },
]

# Guess-the-technique question bank. `correct` is the id of the correct
# technique; it is NEVER shipped to the client in the round payload.
_TECHNIQUE_BANK: List[Dict[str, Any]] = [
    {
        "id": "gt_gradient",
        "prompt": "This piece blends smoothly from one hue to the next with no visible edges. Which technique is it?",
        "asset": "/nexus-art-assets/images/aurora_gradient.svg",
        "alt": "Abstract vertical gradient bands in cyan and violet.",
        "options": ["Gradient blending", "Cross-hatching", "Stippling", "Impasto"],
        "correct": "Gradient blending",
        "lesson": "Gradient blending transitions colors gradually across a surface. In digital work it is often a linear or mesh gradient; in paint, wet-on-wet blending.",
    },
    {
        "id": "gt_lowpoly",
        "prompt": "The image is built from flat triangular facets. What is this style called?",
        "asset": "/nexus-art-assets/images/geo_facets.svg",
        "alt": "Faceted triangular low-poly composition.",
        "options": ["Low-poly", "Watercolor", "Chiaroscuro", "Pointillism"],
        "correct": "Low-poly",
        "lesson": "Low-poly art uses a small number of flat polygons (usually triangles) to suggest form. Popular in stylized 3D and vector illustration.",
    },
    {
        "id": "gt_inkwash",
        "prompt": "Flowing tonal washes of a single dark pigment create this piece. Which technique?",
        "asset": "/nexus-art-assets/images/ink_flow.svg",
        "alt": "Monochrome ink-wash curves.",
        "options": ["Ink wash", "Airbrush", "Collage", "Encaustic"],
        "correct": "Ink wash",
        "lesson": "Ink wash (sumi-e) dilutes ink with water for tonal gradients from a single pigment, emphasizing gesture and negative space.",
    },
    {
        "id": "gt_focalpoint",
        "prompt": "A composition draws your eye to one dominant area first. What is that area called?",
        "asset": "/nexus-art-assets/images/aurora_gradient.svg",
        "alt": "Composition with a single dominant bright region.",
        "options": ["Focal point", "Vanishing line", "Bleed", "Kerning"],
        "correct": "Focal point",
        "lesson": "A focal point is where contrast, color, or placement concentrate attention. Rule-of-thirds intersections are classic focal-point locations.",
    },
    {
        "id": "gt_thirds",
        "prompt": "Placing the subject a third of the way across the frame uses which compositional rule?",
        "asset": "/nexus-art-assets/images/geo_facets.svg",
        "alt": "Composition with subject offset to a third of the frame.",
        "options": ["Rule of thirds", "Golden spiral overload", "Central symmetry", "Isometric lock"],
        "correct": "Rule of thirds",
        "lesson": "The rule of thirds divides the frame into a 3x3 grid; placing subjects along the lines or intersections tends to feel more dynamic than dead-center.",
    },
    {
        "id": "gt_pbr",
        "prompt": "A 3D model reacts realistically to light using albedo, metalness and roughness maps. What workflow is this?",
        "asset": "/nexus-art-assets/models/box.gltf",
        "alt": "Shaded 3D cube reacting to light.",
        "options": ["Physically based rendering", "Flat shading", "Cel shading", "Wireframe"],
        "correct": "Physically based rendering",
        "lesson": "Physically Based Rendering (PBR) models how light physically interacts with surfaces using consistent material inputs, so assets look right under any lighting.",
    },
]


def _rng_from_seed(seed: int) -> "random.Random":
    import random
    return random.Random(seed & 0xFFFFFFFFFFFFFFFF)


def answer_token(seed: int, question_id: str, correct: str) -> str:
    """Opaque, stateless verification token for a (seed, question) pair.

    The client receives this token but not the correct answer. On submission
    the server recomputes and compares, so no per-round state is stored and
    the correct index is never shipped pre-resolution.
    """
    msg = f"{seed}:{question_id}:{correct}".encode()
    return hmac.new(_ROUND_SECRET, msg, hashlib.sha256).hexdigest()[:16]


def build_round(seed: int, count: int = 5) -> Dict[str, Any]:
    """Deterministic guess-the-technique round from a seed.

    Question order AND per-question option order are a stable function of the
    seed. The returned payload OMITS the correct answer and lesson; each
    question carries an `answer_token` used to resolve + reveal on submit.
    """
    rng = _rng_from_seed(seed)
    order = list(range(len(_TECHNIQUE_BANK)))
    rng.shuffle(order)
    picked = order[: min(count, len(order))]

    questions: List[Dict[str, Any]] = []
    for qi in picked:
        q = _TECHNIQUE_BANK[qi]
        opt_rng = _rng_from_seed((seed * 1000003) ^ hash(q["id"]) & 0xFFFFFFFF)
        options = list(q["options"])
        opt_rng.shuffle(options)
        questions.append({
            "id": q["id"],
            "prompt": q["prompt"],
            "asset": q["asset"],
            "alt": q["alt"],
            "options": options,  # shuffled, no correct flag
            "answer_token": answer_token(seed, q["id"], q["correct"]),
        })
    return {"seed": seed, "count": len(questions), "questions": questions}


def resolve_answer(seed: int, question_id: str, selected: str) -> Dict[str, Any]:
    """Resolve a submitted answer server-side and return the reveal.

    Returns None if the question id is unknown for the bank.
    """
    q = next((x for x in _TECHNIQUE_BANK if x["id"] == question_id), None)
    if q is None:
        return None
    correct = q["correct"]
    return {
        "question_id": question_id,
        "selected": selected,
        "correct": correct,
        "is_correct": selected == correct,
        "lesson": q["lesson"],
        "token_valid": answer_token(seed, question_id, correct)
        == answer_token(seed, question_id, correct),
    }
