"""
stills.py — deterministic original placeholder scene stills (SVG).

Every still is generated from the scene's palette + integer seed in the
MOCK_DATADUMP, so the art is 100% original, byte-reproducible, and a few KB
(hard rule: mock assets < 1MB). Cinematic letterbox framing baked in.

PLACEHOLDER NOTICE (flagged in the PR): these abstract stills are stand-ins.
Elijah will replace them with Meshy-generated stills at design sign-off; the
swap point is exactly this module (same URL contract, new renderer).

Modes:
  - full render                      -> render_still(scene)
  - invisibles mask (element voided) -> render_still(scene, mask="el_x")
  - frame-freeze progressive reveal  -> render_still(scene, reveal=0..4)
"""
import random
from typing import Any, Dict, Optional

W, H = 700, 420
LETTERBOX = 34  # top/bottom cinematic bars


def _shape_svg(el: Dict[str, Any], stroke: str, fill: str) -> str:
    """Abstract, clearly-original geometry per element 'shape' hint."""
    x, y, w, h = el["x"], el["y"], el["w"], el["h"]
    cx, cy = x + w / 2, y + h / 2
    shape = el.get("shape", "circle")
    if shape == "circle":
        return f'<circle cx="{cx}" cy="{cy}" r="{min(w, h) / 2}" fill="{fill}" opacity="0.9"/>'
    if shape == "hoop":
        return (
            f'<rect x="{x + w * 0.4}" y="{y}" width="{w * 0.14}" height="{h}" fill="{fill}" opacity="0.85"/>'
            f'<ellipse cx="{cx}" cy="{y + h * 0.25}" rx="{w * 0.5}" ry="{h * 0.12}" fill="none" stroke="{stroke}" stroke-width="6"/>'
        )
    if shape == "figure":
        return (
            f'<circle cx="{cx}" cy="{y + h * 0.15}" r="{h * 0.14}" fill="{fill}"/>'
            f'<path d="M {cx} {y + h * 0.3} L {x + w * 0.2} {y + h} M {cx} {y + h * 0.3} L {x + w * 0.85} {y + h * 0.9} M {cx} {y + h * 0.3} L {cx} {y + h * 0.65}" stroke="{fill}" stroke-width="8" stroke-linecap="round" fill="none"/>'
        )
    if shape in ("line", "beam"):
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h / 2}" fill="{fill}" opacity="0.9"/>'
    if shape in ("wave", "bigwave"):
        return f'<path d="M {x} {y + h} Q {x + w * 0.25} {y} {x + w * 0.5} {y + h * 0.6} T {x + w} {y + h * 0.3} L {x + w} {y + h} Z" fill="{fill}" opacity="0.8"/>'
    # generic abstract block for everything else (pier, crowd, sign, dust, ramp,
    # board, piece, door, lantern, duel, diagram, court, bench, gull, bass,
    # barbell, stringlights, boards, chalkcircle, feet, crack, light...)
    return (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{fill}" opacity="0.55"/>'
        f'<rect x="{x + 8}" y="{y + 8}" width="{max(4, w - 16)}" height="{max(4, h - 16)}" rx="8" fill="none" stroke="{stroke}" stroke-width="3" opacity="0.9"/>'
    )


def render_still(
    scene: Dict[str, Any],
    mask: Optional[str] = None,
    reveal: Optional[int] = None,
    reveal_stages: int = 5,
) -> str:
    """Render a scene still as SVG text. Deterministic per (scene, mask, reveal)."""
    still = scene["still"]
    palette = still["palette"]
    rng = random.Random(still["seed"])
    bg, accent, hi, mid = palette[0], palette[1], palette[2], palette[3]

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',
        f'<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{bg}"/><stop offset="0.65" stop-color="{mid}"/>'
        f'<stop offset="1" stop-color="{bg}"/></linearGradient></defs>',
        f'<rect width="{W}" height="{H}" fill="url(#sky)"/>',
    ]
    # ambient original texture: seeded scatter of glow dots
    for _ in range(26):
        px, py = rng.randint(0, W), rng.randint(LETTERBOX, H - LETTERBOX)
        r = rng.choice([1, 1, 2, 3])
        parts.append(f'<circle cx="{px}" cy="{py}" r="{r}" fill="{hi}" opacity="0.{rng.randint(1, 4)}"/>')

    for el in still["elements"]:
        if mask and el["id"] == mask:
            # Invisibles: the element is blanked — leave a dashed void.
            parts.append(
                f'<rect x="{el["x"]}" y="{el["y"]}" width="{el["w"]}" height="{el["h"]}" rx="12" '
                f'fill="{bg}" stroke="{hi}" stroke-width="3" stroke-dasharray="10 8" opacity="0.95"/>'
                f'<text x="{el["x"] + el["w"] / 2}" y="{el["y"] + el["h"] / 2}" fill="{hi}" opacity="0.5" '
                f'font-family="monospace" font-size="26" text-anchor="middle" dominant-baseline="middle">?</text>'
            )
            continue
        parts.append(_shape_svg(el, hi, accent))

    # Frame Freeze: cover with seeded-order tiles, remove per reveal stage.
    if reveal is not None:
        cols, rows = 7, 4
        tiles = [(c, r) for r in range(rows) for c in range(cols)]
        tile_rng = random.Random(still["seed"] ^ 0xF8EE2E)
        tile_rng.shuffle(tiles)
        stage = max(0, min(reveal_stages - 1, int(reveal)))
        covered = tiles[: int(len(tiles) * (1 - stage / (reveal_stages - 1))) ] if reveal_stages > 1 else tiles
        tw, th = W / cols, H / rows
        for (c, r) in covered:
            parts.append(
                f'<rect x="{c * tw:.1f}" y="{r * th:.1f}" width="{tw + 0.5:.1f}" height="{th + 0.5:.1f}" fill="{bg}"/>'
                f'<rect x="{c * tw + 2:.1f}" y="{r * th + 2:.1f}" width="{tw - 4:.1f}" height="{th - 4:.1f}" fill="{mid}" opacity="0.35"/>'
            )

    # cinematic letterbox bars
    parts.append(f'<rect x="0" y="0" width="{W}" height="{LETTERBOX}" fill="#000"/>')
    parts.append(f'<rect x="0" y="{H - LETTERBOX}" width="{W}" height="{LETTERBOX}" fill="#000"/>')
    parts.append(
        f'<text x="12" y="{H - 12}" fill="{hi}" opacity="0.55" font-family="monospace" font-size="11">'
        f'FEL ORIGINAL PLACEHOLDER — {scene["scene_id"]}</text>'
    )
    parts.append("</svg>")
    return "".join(parts)
