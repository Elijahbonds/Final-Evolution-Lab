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
    {
        "type": "image",
        "path": "/nexus-art-assets/images/stipple_orb.svg",
        "meta": {
            "title": "Stipple Orb",
            "alt": "Pointillist orb built from cyan and violet dots, densest at a glowing focal point and fading into darkness.",
            "technique": "stippling",
            "tools": ["vector", "pointillism"],
            "artist": "FEL Studio",
            "artist_bio": "Original generative work produced for Final Evolution Lab.",
            "source": "original",
            "license": "CC0-1.0",
            "card_id": "card_visionary_01",
        },
    },
    {
        "type": "image",
        "path": "/nexus-art-assets/images/crosshatch_sphere.svg",
        "meta": {
            "title": "Cross-Hatch Sphere",
            "alt": "A sphere modeled with pen-style cross-hatching, building from single strokes in the light to dense overlapping cyan and violet cross-hatch in shadow.",
            "technique": "cross_hatching",
            "tools": ["vector", "line work"],
            "artist": "FEL Studio",
            "artist_bio": "Original generative work produced for Final Evolution Lab.",
            "source": "original",
            "license": "CC0-1.0",
            "card_id": "card_curator_01",
        },
    },
    {
        "type": "image",
        "path": "/nexus-art-assets/images/chiaroscuro_study.svg",
        "meta": {
            "title": "Chiaroscuro Study",
            "alt": "A value study of a rounded form lit by a single cyan key light dissolving through tonal bands into deep shadow, with a faint violet bounce light.",
            "technique": "chiaroscuro",
            "tools": ["vector", "value study"],
            "artist": "FEL Studio",
            "artist_bio": "Original generative work produced for Final Evolution Lab.",
            "source": "original",
            "license": "CC0-1.0",
            "card_id": "card_visionary_01",
        },
    },
    {
        "type": "model",
        "path": "/nexus-art-assets/models/facet_gem.gltf",
        "meta": {
            "title": "Facet Gem",
            "alt": "A faceted cyan octahedral gem shaded as a low-poly 3D sculpture.",
            "technique": "low_poly_3d",
            "tools": ["glTF", "PBR", "flat shading"],
            "artist": "FEL Studio",
            "artist_bio": "Original CC0 geometry authored procedurally for Final Evolution Lab.",
            "source": "original",
            "license": "CC0-1.0",
            "card_id": "card_visionary_01",
        },
    },
    {
        "type": "model",
        "path": "/nexus-art-assets/models/aurora_prism.gltf",
        "meta": {
            "title": "Aurora Prism",
            "alt": "A violet hexagonal bipyramid prism rendered as a faceted 3D crystal.",
            "technique": "low_poly_3d",
            "tools": ["glTF", "PBR", "flat shading"],
            "artist": "FEL Studio",
            "artist_bio": "Original CC0 geometry authored procedurally for Final Evolution Lab.",
            "source": "original",
            "license": "CC0-1.0",
            "card_id": "card_curator_01",
        },
    },
]

# Guess-the-technique question bank. `correct` is the id of the correct
# technique; it is NEVER shipped to the client in the round payload.
#
# Each question carries a `category` (composition | color | rendering |
# mark_making | media_3d) and a `difficulty` (easy | medium | hard) so rounds
# can be filtered/scaffolded. These fields are metadata for round building;
# `correct` and `lesson` remain server-side-only.
TECHNIQUE_CATEGORIES = ("composition", "color", "rendering", "mark_making", "media_3d")
TECHNIQUE_DIFFICULTIES = ("easy", "medium", "hard")

_TECHNIQUE_BANK: List[Dict[str, Any]] = [
    # ── mark_making ────────────────────────────────────────────────────────
    {
        "id": "gt_gradient",
        "category": "color",
        "difficulty": "easy",
        "prompt": "This piece blends smoothly from one hue to the next with no visible edges. Which technique is it?",
        "asset": "/nexus-art-assets/images/aurora_gradient.svg",
        "alt": "Abstract vertical gradient bands in cyan and violet.",
        "options": ["Gradient blending", "Cross-hatching", "Stippling", "Impasto"],
        "correct": "Gradient blending",
        "lesson": "Gradient blending transitions colors gradually across a surface. In digital work it is often a linear or mesh gradient; in paint, wet-on-wet blending. Smooth gradients are how atmosphere, skies, and soft form-shading read as continuous rather than banded.",
    },
    {
        "id": "gt_lowpoly",
        "category": "media_3d",
        "difficulty": "easy",
        "prompt": "The image is built from flat triangular facets. What is this style called?",
        "asset": "/nexus-art-assets/images/geo_facets.svg",
        "alt": "Faceted triangular low-poly composition.",
        "options": ["Low-poly", "Watercolor", "Chiaroscuro", "Pointillism"],
        "correct": "Low-poly",
        "lesson": "Low-poly art uses a small number of flat polygons (usually triangles) to suggest form. Popular in stylized 3D and vector illustration, it trades surface detail for a crisp, geometric read and cheap rendering.",
    },
    {
        "id": "gt_inkwash",
        "category": "mark_making",
        "difficulty": "medium",
        "prompt": "Flowing tonal washes of a single dark pigment create this piece. Which technique?",
        "asset": "/nexus-art-assets/images/ink_flow.svg",
        "alt": "Monochrome ink-wash curves.",
        "options": ["Ink wash", "Airbrush", "Collage", "Encaustic"],
        "correct": "Ink wash",
        "lesson": "Ink wash (sumi-e) dilutes ink with water for tonal gradients from a single pigment, emphasizing gesture, spontaneity, and negative space. The amount of water loaded on the brush controls value in a single confident stroke.",
    },
    {
        "id": "gt_focalpoint",
        "category": "composition",
        "difficulty": "easy",
        "prompt": "A composition draws your eye to one dominant area first. What is that area called?",
        "asset": "/nexus-art-assets/images/aurora_gradient.svg",
        "alt": "Composition with a single dominant bright region.",
        "options": ["Focal point", "Vanishing line", "Bleed", "Kerning"],
        "correct": "Focal point",
        "lesson": "A focal point is where contrast, color, detail, or placement concentrate attention. Rule-of-thirds intersections are classic focal-point locations; artists steer the eye there with converging lines and value contrast.",
    },
    {
        "id": "gt_thirds",
        "category": "composition",
        "difficulty": "easy",
        "prompt": "Placing the subject a third of the way across the frame uses which compositional rule?",
        "asset": "/nexus-art-assets/images/geo_facets.svg",
        "alt": "Composition with subject offset to a third of the frame.",
        "options": ["Rule of thirds", "Golden spiral overload", "Central symmetry", "Isometric lock"],
        "correct": "Rule of thirds",
        "lesson": "The rule of thirds divides the frame into a 3x3 grid; placing subjects along the lines or intersections tends to feel more dynamic than dead-center. It is a fast approximation of the golden ratio for balanced tension.",
    },
    {
        "id": "gt_pbr",
        "category": "media_3d",
        "difficulty": "hard",
        "prompt": "A 3D model reacts realistically to light using albedo, metalness and roughness maps. What workflow is this?",
        "asset": "/nexus-art-assets/models/box.gltf",
        "alt": "Shaded 3D cube reacting to light.",
        "options": ["Physically based rendering", "Flat shading", "Cel shading", "Wireframe"],
        "correct": "Physically based rendering",
        "lesson": "Physically Based Rendering (PBR) models how light physically interacts with surfaces using consistent, measurable material inputs (albedo, metalness, roughness), so assets look correct under any lighting environment rather than only the one they were tuned in.",
    },
    # ── mark_making (new) ──────────────────────────────────────────────────
    {
        "id": "gt_stippling",
        "category": "mark_making",
        "difficulty": "medium",
        "prompt": "Value and form here are built entirely from thousands of tiny dots. What is this technique?",
        "asset": "/nexus-art-assets/images/stipple_orb.svg",
        "alt": "Orb rendered from dense-to-sparse dots.",
        "options": ["Stippling", "Hatching", "Scumbling", "Glazing"],
        "correct": "Stippling",
        "lesson": "Stippling builds tone from the density of individual dots — closer dots read darker, sparser dots lighter. It is common in pen-and-ink and scientific illustration for its precise, gradual value control.",
    },
    {
        "id": "gt_crosshatch",
        "category": "mark_making",
        "difficulty": "medium",
        "prompt": "Overlapping sets of parallel lines at different angles build the shadows here. Which technique?",
        "asset": "/nexus-art-assets/images/crosshatch_sphere.svg",
        "alt": "Sphere shaded with layered cross-hatching.",
        "options": ["Cross-hatching", "Stippling", "Dry brush", "Sgraffito"],
        "correct": "Cross-hatching",
        "lesson": "Cross-hatching layers parallel line sets at differing angles; the more layers overlap, the darker the value. It gives ink and engraving their characteristic tonal range without any actual gray ink.",
    },
    {
        "id": "gt_pointillism",
        "category": "color",
        "difficulty": "hard",
        "prompt": "Small distinct dots of pure color are placed so the eye optically mixes them into new hues. What movement/technique is this?",
        "asset": "/nexus-art-assets/images/stipple_orb.svg",
        "alt": "Field of pure cyan and violet dots blending optically.",
        "options": ["Pointillism", "Impressionism", "Fauvism", "Tenebrism"],
        "correct": "Pointillism",
        "lesson": "Pointillism (Seurat, Signac) relies on optical mixing: adjacent dots of unmixed color blend in the viewer's eye, producing luminous results a pre-mixed pigment cannot. It is the fine-art cousin of the halftone dot.",
    },
    # ── color / value ──────────────────────────────────────────────────────
    {
        "id": "gt_chiaroscuro",
        "category": "color",
        "difficulty": "hard",
        "prompt": "Strong contrast between a single light source and deep shadow models the form dramatically. What is this called?",
        "asset": "/nexus-art-assets/images/chiaroscuro_study.svg",
        "alt": "Rounded form lit by one key light fading into deep shadow.",
        "options": ["Chiaroscuro", "Grisaille", "Alla prima", "Pointillism"],
        "correct": "Chiaroscuro",
        "lesson": "Chiaroscuro (Italian for 'light-dark') uses strong value contrast to model three-dimensional form and set a dramatic mood. Caravaggio pushed it toward tenebrism, where shadow swallows most of the frame.",
    },
    {
        "id": "gt_complementary",
        "category": "color",
        "difficulty": "medium",
        "prompt": "Two hues sitting opposite each other on the color wheel are paired for maximum vibrancy. What are they called?",
        "asset": "/nexus-art-assets/images/aurora_gradient.svg",
        "alt": "Cyan and warm accents set against each other.",
        "options": ["Complementary colors", "Analogous colors", "Monochrome", "Tetradic overload"],
        "correct": "Complementary colors",
        "lesson": "Complementary colors sit opposite on the color wheel (e.g., blue/orange). Placed next to each other they intensify; mixed together they neutralize toward gray — the basis of controlled, vibrant palettes.",
    },
    {
        "id": "gt_valuegroups",
        "category": "color",
        "difficulty": "hard",
        "prompt": "A drawing reads clearly because its lights, midtones, and darks are organized into a few clean masses. What principle is this?",
        "asset": "/nexus-art-assets/images/chiaroscuro_study.svg",
        "alt": "Form simplified into a few clean value masses.",
        "options": ["Value grouping", "Kerning", "Vanishing point", "Bleed"],
        "correct": "Value grouping",
        "lesson": "Value grouping (notan) simplifies a scene into a small number of connected light and dark shapes. Strong value organization is what lets an image read instantly at thumbnail size, before any detail.",
    },
    # ── composition ────────────────────────────────────────────────────────
    {
        "id": "gt_leadingline",
        "category": "composition",
        "difficulty": "medium",
        "prompt": "Elements in the scene form a line that guides the viewer's eye toward the subject. What is this device?",
        "asset": "/nexus-art-assets/images/geo_facets.svg",
        "alt": "Facets forming a path toward the subject.",
        "options": ["Leading lines", "Rule of odds", "Color temperature", "Chroma key"],
        "correct": "Leading lines",
        "lesson": "Leading lines are real or implied lines (roads, gazes, edges) that route the viewer's eye through the frame toward the focal point. They add depth and intentional pacing to a composition.",
    },
    {
        "id": "gt_negativespace",
        "category": "composition",
        "difficulty": "medium",
        "prompt": "The empty area around and between subjects is used as an active, shaping element. What is that area called?",
        "asset": "/nexus-art-assets/images/ink_flow.svg",
        "alt": "Ink forms defined as much by the empty space around them.",
        "options": ["Negative space", "Bleed area", "Safe margin", "Gutter"],
        "correct": "Negative space",
        "lesson": "Negative space is the space around and between subjects. Treating it as an active shape (not leftover emptiness) improves balance, legibility, and elegance — central to logo design and sumi-e alike.",
    },
    # ── rendering / 3D ─────────────────────────────────────────────────────
    {
        "id": "gt_celshading",
        "category": "rendering",
        "difficulty": "medium",
        "prompt": "A 3D model is shaded in flat bands of color with hard edges to mimic hand-drawn animation. What technique is this?",
        "asset": "/nexus-art-assets/models/facet_gem.gltf",
        "alt": "Faceted gem shaded in flat cartoon-like bands.",
        "options": ["Cel shading", "Physically based rendering", "Ambient occlusion", "Subsurface scattering"],
        "correct": "Cel shading",
        "lesson": "Cel shading (toon shading) quantizes lighting into a few flat bands and often adds outlines, giving 3D a hand-drawn, comic-book look. It is a deliberate non-photorealistic (NPR) rendering choice.",
    },
    {
        "id": "gt_ao",
        "category": "rendering",
        "difficulty": "hard",
        "prompt": "Soft contact shadows gather in crevices and where surfaces meet, grounding an object. What effect approximates this?",
        "asset": "/nexus-art-assets/models/aurora_prism.gltf",
        "alt": "Prism with soft shadowing in its inner angles.",
        "options": ["Ambient occlusion", "Specular bloom", "Chromatic aberration", "Vignette"],
        "correct": "Ambient occlusion",
        "lesson": "Ambient occlusion darkens areas where ambient light is blocked — inner corners, crevices, contact points. It adds cheap, convincing depth and 'weight' without simulating full global illumination.",
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


def bank_size(category: str = None, difficulty: str = None) -> int:
    """How many questions match the given filters (for tests / UI hints)."""
    return len(_filter_bank(category, difficulty))


def _filter_bank(category: str = None, difficulty: str = None) -> List[int]:
    """Indices into _TECHNIQUE_BANK matching the (optional) filters, in
    stable bank order. Unknown filter values simply match nothing."""
    out = []
    for i, q in enumerate(_TECHNIQUE_BANK):
        if category and q.get("category") != category:
            continue
        if difficulty and q.get("difficulty") != difficulty:
            continue
        out.append(i)
    return out


def build_round(
    seed: int,
    count: int = 5,
    category: str = None,
    difficulty: str = None,
) -> Dict[str, Any]:
    """Deterministic guess-the-technique round from a seed.

    Question order AND per-question option order are a stable function of the
    seed (and the optional category/difficulty filters). The returned payload
    OMITS the correct answer and lesson; each question carries an
    `answer_token` used to resolve + reveal on submit. `category`/`difficulty`
    are surfaced per question (metadata, not the answer) so the UI can badge
    them and offer filtered rounds.
    """
    rng = _rng_from_seed(seed)
    pool = _filter_bank(category, difficulty)
    rng.shuffle(pool)
    picked = pool[: min(count, len(pool))]

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
            "category": q.get("category"),
            "difficulty": q.get("difficulty"),
            "options": options,  # shuffled, no correct flag
            "answer_token": answer_token(seed, q["id"], q["correct"]),
        })
    return {
        "seed": seed,
        "count": len(questions),
        "category": category,
        "difficulty": difficulty,
        "questions": questions,
    }


def resolve_answer(
    seed: int,
    question_id: str,
    selected: str,
    token: str = None,
) -> Dict[str, Any]:
    """Resolve a submitted answer server-side and return the reveal.

    Returns None if the question id is unknown for the bank.

    If the client echoes back the `answer_token` it received in the round
    payload, `token_valid` reflects a real HMAC re-verification: the token is
    recomputed from (seed, question_id, correct) and compared in constant time
    to the submitted one. A mismatched or absent token yields token_valid=False
    but does NOT block resolution (the correct answer is still authoritative
    server-side) — the flag is an integrity signal, not an auth gate.
    """
    q = next((x for x in _TECHNIQUE_BANK if x["id"] == question_id), None)
    if q is None:
        return None
    correct = q["correct"]
    expected_token = answer_token(seed, question_id, correct)
    token_valid = token is not None and hmac.compare_digest(token, expected_token)
    return {
        "question_id": question_id,
        "selected": selected,
        "correct": correct,
        "is_correct": selected == correct,
        "lesson": q["lesson"],
        "category": q.get("category"),
        "difficulty": q.get("difficulty"),
        "token_valid": token_valid,
    }
