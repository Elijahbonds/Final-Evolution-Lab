"""
Procedural Asset Generator — high-quality fallback for OpenArt.ai.

Generates production-grade PBR textures, atmospheric overlays, prop
silhouette cards, and skybox variations using pure Python (Pillow + NumPy).
Every asset is seeded from the prompt text so identical prompts always
produce identical output (deterministic & cacheable).

Asset categories:
  • TEXTURE   – tileable surface textures (concrete, wood, metal, brick …)
  • MATERIAL  – PBR map component (albedo, normal, roughness, metallic, AO)
  • PROP      – scene prop card with alpha (trees, signs, furniture …)
  • ATMOSPHERE – transparent overlay (fog, particles, light rays, dust …)
  • SKYBOX    – equirectangular panoramic sky
  • DETAIL    – small decorative detail (graffiti, sticker, crack, stain …)
  • DECAL     – overlay decal with alpha
"""

import hashlib
import math
import struct
from pathlib import Path
from typing import Optional, Dict, Any, Tuple, List

import numpy as np

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    raise ImportError("Pillow is required: pip install Pillow")

from .openart_api_client import AssetType, TextureMapType

# ---------------------------------------------------------------------------
# Colour palettes per environment theme
# ---------------------------------------------------------------------------

ENVIRONMENT_PALETTES: Dict[str, Dict[str, Any]] = {
    "retro_tokyo_night": {
        "primary": [(255, 50, 80), (0, 200, 255), (255, 180, 0)],
        "secondary": [(30, 15, 45), (50, 25, 60), (20, 10, 30)],
        "accent": [(255, 0, 120), (0, 255, 200)],
        "atmosphere": (30, 15, 60, 180),
        "sky_gradient": [(10, 5, 30), (40, 20, 80), (80, 30, 100)],
        "emissive_strength": 0.8,
    },
    "venice_beach_sunset": {
        "primary": [(255, 140, 50), (255, 200, 100), (200, 100, 60)],
        "secondary": [(80, 60, 40), (120, 90, 60), (60, 45, 30)],
        "accent": [(255, 80, 30), (255, 220, 150)],
        "atmosphere": (255, 180, 100, 80),
        "sky_gradient": [(255, 100, 30), (255, 180, 80), (100, 150, 200)],
        "emissive_strength": 0.3,
    },
    "cyberpunk_gym": {
        "primary": [(0, 255, 255), (255, 0, 180), (120, 0, 255)],
        "secondary": [(20, 20, 30), (30, 30, 45), (15, 15, 25)],
        "accent": [(0, 255, 200), (255, 50, 200)],
        "atmosphere": (0, 100, 150, 120),
        "sky_gradient": [(10, 10, 20), (20, 30, 60), (40, 20, 80)],
        "emissive_strength": 0.9,
    },
    "classic_nba_arena": {
        "primary": [(200, 150, 80), (180, 120, 60), (220, 180, 100)],
        "secondary": [(100, 60, 30), (80, 50, 25), (60, 40, 20)],
        "accent": [(255, 200, 50), (200, 30, 30)],
        "atmosphere": (255, 220, 150, 60),
        "sky_gradient": [(40, 30, 20), (80, 60, 40), (120, 90, 60)],
        "emissive_strength": 0.4,
    },
    "underground_bunker": {
        "primary": [(140, 140, 130), (100, 100, 95), (120, 120, 110)],
        "secondary": [(60, 60, 55), (45, 45, 40), (80, 80, 75)],
        "accent": [(200, 180, 50), (180, 50, 50)],
        "atmosphere": (80, 80, 70, 150),
        "sky_gradient": [(30, 30, 28), (60, 60, 55), (90, 90, 85)],
        "emissive_strength": 0.2,
    },
    "rooftop_cityscape": {
        "primary": [(60, 80, 120), (100, 130, 180), (40, 60, 100)],
        "secondary": [(30, 30, 40), (50, 50, 65), (25, 25, 35)],
        "accent": [(255, 200, 80), (255, 100, 50)],
        "atmosphere": (60, 80, 120, 100),
        "sky_gradient": [(20, 30, 60), (60, 80, 140), (180, 120, 80)],
        "emissive_strength": 0.5,
    },
    "winter_outdoor": {
        "primary": [(200, 210, 220), (180, 190, 200), (220, 230, 240)],
        "secondary": [(100, 110, 120), (80, 90, 100), (60, 70, 80)],
        "accent": [(255, 200, 100), (200, 80, 60)],
        "atmosphere": (200, 210, 230, 120),
        "sky_gradient": [(150, 160, 180), (200, 210, 230), (230, 235, 240)],
        "emissive_strength": 0.2,
    },
    "beach_tropical": {
        "primary": [(0, 200, 180), (100, 220, 200), (255, 240, 200)],
        "secondary": [(200, 180, 140), (180, 160, 120), (220, 200, 160)],
        "accent": [(255, 100, 80), (0, 255, 200)],
        "atmosphere": (100, 220, 255, 60),
        "sky_gradient": [(80, 180, 255), (150, 220, 255), (255, 255, 255)],
        "emissive_strength": 0.1,
    },
    "warehouse_industrial": {
        "primary": [(160, 100, 60), (140, 80, 50), (180, 120, 70)],
        "secondary": [(80, 70, 60), (60, 55, 45), (100, 90, 80)],
        "accent": [(200, 150, 50), (180, 60, 40)],
        "atmosphere": (100, 80, 60, 100),
        "sky_gradient": [(40, 35, 30), (80, 70, 60), (120, 100, 80)],
        "emissive_strength": 0.3,
    },
    "neon_arcade": {
        "primary": [(180, 0, 255), (0, 255, 200), (255, 0, 100)],
        "secondary": [(20, 10, 30), (15, 20, 25), (25, 15, 35)],
        "accent": [(255, 255, 0), (0, 200, 255)],
        "atmosphere": (120, 0, 200, 140),
        "sky_gradient": [(10, 5, 20), (30, 10, 60), (60, 20, 100)],
        "emissive_strength": 0.95,
    },
    "zen_dojo": {
        "primary": [(180, 150, 100), (200, 170, 120), (160, 130, 80)],
        "secondary": [(100, 80, 50), (120, 100, 70), (80, 60, 40)],
        "accent": [(200, 50, 50), (50, 150, 50)],
        "atmosphere": (200, 180, 140, 60),
        "sky_gradient": [(200, 180, 150), (230, 210, 180), (255, 240, 220)],
        "emissive_strength": 0.1,
    },
    "stadium_night_game": {
        "primary": [(50, 140, 50), (40, 120, 40), (60, 160, 60)],
        "secondary": [(30, 30, 30), (50, 50, 50), (70, 70, 70)],
        "accent": [(255, 255, 255), (255, 200, 50)],
        "atmosphere": (100, 200, 100, 80),
        "sky_gradient": [(5, 10, 20), (15, 25, 40), (25, 35, 55)],
        "emissive_strength": 0.6,
    },
}


def _seed_from_prompt(prompt: str) -> int:
    """Deterministic seed from prompt text."""
    return int(hashlib.md5(prompt.encode()).hexdigest()[:8], 16)


def _detect_environment(prompt: str) -> str:
    """Detect environment theme from prompt keywords."""
    prompt_lower = prompt.lower()
    for env_key in ENVIRONMENT_PALETTES:
        keywords = env_key.replace("_", " ").split()
        if any(kw in prompt_lower for kw in keywords):
            return env_key
    # Fallback — try partial matches
    mapping = {
        "tokyo": "retro_tokyo_night", "neon": "neon_arcade",
        "venice": "venice_beach_sunset", "beach": "beach_tropical",
        "cyber": "cyberpunk_gym", "gym": "cyberpunk_gym",
        "arena": "classic_nba_arena", "nba": "classic_nba_arena",
        "bunker": "underground_bunker", "underground": "underground_bunker",
        "rooftop": "rooftop_cityscape", "city": "rooftop_cityscape",
        "winter": "winter_outdoor", "snow": "winter_outdoor",
        "tropical": "beach_tropical", "island": "beach_tropical",
        "warehouse": "warehouse_industrial", "industrial": "warehouse_industrial",
        "arcade": "neon_arcade", "synthwave": "neon_arcade",
        "dojo": "zen_dojo", "zen": "zen_dojo",
        "stadium": "stadium_night_game", "soccer": "stadium_night_game",
    }
    for kw, env in mapping.items():
        if kw in prompt_lower:
            return env
    return "cyberpunk_gym"  # safe default


# ---------------------------------------------------------------------------
# Noise & pattern primitives
# ---------------------------------------------------------------------------

def _perlin_noise_2d(shape: Tuple[int, int], scale: float, seed: int) -> np.ndarray:
    """Simple value noise (fast Perlin-like)."""
    rng = np.random.RandomState(seed)
    h, w = shape
    grid_h = max(2, int(h / scale))
    grid_w = max(2, int(w / scale))
    grid = rng.rand(grid_h + 1, grid_w + 1).astype(np.float32)
    # Bilinear interpolation
    ys = np.linspace(0, grid_h - 1, h, dtype=np.float32)
    xs = np.linspace(0, grid_w - 1, w, dtype=np.float32)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    y1 = np.minimum(y0 + 1, grid_h)
    x1 = np.minimum(x0 + 1, grid_w)
    fy = (ys - y0).reshape(-1, 1)
    fx = (xs - x0).reshape(1, -1)
    top = grid[y0][:, x0] * (1 - fx) + grid[y0][:, x1] * fx
    bot = grid[y1][:, x0] * (1 - fx) + grid[y1][:, x1] * fx
    return top * (1 - fy) + bot * fy


def _fbm(shape: Tuple[int, int], octaves: int, seed: int, base_scale: float = 64.0) -> np.ndarray:
    """Fractional Brownian Motion — layered noise."""
    result = np.zeros(shape, dtype=np.float32)
    amplitude = 1.0
    total_amp = 0.0
    for i in range(octaves):
        result += amplitude * _perlin_noise_2d(shape, base_scale / (2 ** i), seed + i * 1000)
        total_amp += amplitude
        amplitude *= 0.5
    return result / total_amp


def _voronoi(shape: Tuple[int, int], num_cells: int, seed: int) -> np.ndarray:
    """Voronoi/Worley noise pattern."""
    rng = np.random.RandomState(seed)
    h, w = shape
    points = rng.rand(num_cells, 2) * np.array([h, w])
    ys, xs = np.mgrid[0:h, 0:w]
    coords = np.stack([ys, xs], axis=-1).astype(np.float32)
    min_dist = np.full(shape, float("inf"), dtype=np.float32)
    for p in points:
        dist = np.sqrt(np.sum((coords - p) ** 2, axis=-1))
        min_dist = np.minimum(min_dist, dist)
    max_val = min_dist.max()
    return min_dist / max_val if max_val > 0 else min_dist


# ---------------------------------------------------------------------------
# Procedural Asset Generator
# ---------------------------------------------------------------------------

class ProceduralAssetGenerator:
    """Generates world assets procedurally using Pillow and NumPy."""

    def generate(
        self,
        prompt: str,
        asset_type: AssetType,
        output_path: Path,
        width: int,
        height: int,
        extra_params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Route to the appropriate generator based on asset type."""
        seed = _seed_from_prompt(prompt)
        env_key = _detect_environment(prompt)
        palette = ENVIRONMENT_PALETTES.get(env_key, ENVIRONMENT_PALETTES["cyberpunk_gym"])
        extra_params = extra_params or {}

        generators = {
            AssetType.TEXTURE: self._gen_texture,
            AssetType.MATERIAL: self._gen_material_map,
            AssetType.PROP: self._gen_prop,
            AssetType.ATMOSPHERE: self._gen_atmosphere,
            AssetType.SKYBOX: self._gen_skybox,
            AssetType.DETAIL: self._gen_detail,
            AssetType.DECAL: self._gen_decal,
        }
        gen_fn = generators.get(asset_type, self._gen_texture)
        img = gen_fn(width, height, seed, palette, prompt, extra_params)
        img.save(str(output_path), "PNG", optimize=True)
        return {
            "status": "completed",
            "file_path": str(output_path),
            "asset_type": asset_type.value,
            "source": "procedural",
            "environment": env_key,
            "seed": seed,
            "width": width,
            "height": height,
        }

    # ------------------------------------------------------------------
    # Texture generation
    # ------------------------------------------------------------------

    def _gen_texture(
        self, w: int, h: int, seed: int,
        palette: Dict, prompt: str, params: Dict,
    ) -> Image.Image:
        """Generate a tileable surface texture."""
        base = _fbm((h, w), 6, seed, 128.0)
        detail = _fbm((h, w), 4, seed + 100, 32.0)
        combined = 0.7 * base + 0.3 * detail
        combined = np.clip(combined, 0, 1)

        # Determine surface type from prompt
        prompt_lower = prompt.lower()
        if any(k in prompt_lower for k in ["concrete", "cement", "bunker"]):
            colors = palette["secondary"]
        elif any(k in prompt_lower for k in ["brick", "wall"]):
            colors = palette["primary"]
            combined = self._add_brick_pattern(combined, w, h, seed)
        elif any(k in prompt_lower for k in ["wood", "floor", "tatami"]):
            colors = palette["primary"]
            combined = self._add_wood_grain(combined, w, h, seed)
        elif any(k in prompt_lower for k in ["metal", "steel", "chrome"]):
            colors = palette["secondary"]
            combined = self._add_metal_scratches(combined, w, h, seed)
        else:
            colors = palette["primary"]

        img = self._colorize(combined, colors, seed)
        return img

    def _add_brick_pattern(self, noise: np.ndarray, w: int, h: int, seed: int) -> np.ndarray:
        """Overlay a brick pattern on noise."""
        brick_h, brick_w = max(1, h // 16), max(1, w // 8)
        result = noise.copy()
        for y in range(0, h, brick_h):
            offset = (brick_w // 2) if (y // brick_h) % 2 else 0
            for x in range(0, w, brick_w):
                bx = (x + offset) % w
                # Mortar lines
                if y % brick_h < 2 or bx % brick_w < 2:
                    result[y, x] *= 0.6
        return result

    def _add_wood_grain(self, noise: np.ndarray, w: int, h: int, seed: int) -> np.ndarray:
        """Add wood grain lines."""
        xs = np.linspace(0, 20 * np.pi, w)
        grain = 0.5 + 0.5 * np.sin(xs + noise * 8)
        return 0.6 * noise + 0.4 * grain

    def _add_metal_scratches(self, noise: np.ndarray, w: int, h: int, seed: int) -> np.ndarray:
        """Add metal scratch marks."""
        rng = np.random.RandomState(seed + 500)
        scratches = np.zeros((h, w), dtype=np.float32)
        for _ in range(20):
            y = rng.randint(0, h)
            length = rng.randint(w // 4, w)
            x_start = rng.randint(0, w)
            for dx in range(length):
                x = (x_start + dx) % w
                scratches[y, x] = 0.3
                if y + 1 < h:
                    scratches[y + 1, x] = 0.15
        return np.clip(noise + scratches, 0, 1)

    # ------------------------------------------------------------------
    # PBR Material Maps
    # ------------------------------------------------------------------

    def _gen_material_map(
        self, w: int, h: int, seed: int,
        palette: Dict, prompt: str, params: Dict,
    ) -> Image.Image:
        """Generate a specific PBR map component."""
        map_type = params.get("map_type", "albedo")
        if map_type == "albedo":
            return self._gen_texture(w, h, seed, palette, prompt, params)
        elif map_type == "normal":
            return self._gen_normal_map(w, h, seed)
        elif map_type == "roughness":
            return self._gen_roughness_map(w, h, seed, prompt)
        elif map_type == "metallic":
            return self._gen_metallic_map(w, h, seed, prompt)
        elif map_type == "ao":
            return self._gen_ao_map(w, h, seed)
        elif map_type == "height":
            return self._gen_height_map(w, h, seed)
        elif map_type == "emissive":
            return self._gen_emissive_map(w, h, seed, palette)
        return self._gen_texture(w, h, seed, palette, prompt, params)

    def _gen_normal_map(self, w: int, h: int, seed: int) -> Image.Image:
        """Generate a normal map from height noise."""
        height = _fbm((h, w), 5, seed + 200, 64.0)
        # Sobel-like gradients
        dx = np.zeros_like(height)
        dy = np.zeros_like(height)
        dx[:, 1:] = height[:, 1:] - height[:, :-1]
        dy[1:, :] = height[1:, :] - height[:-1, :]
        # Normal map: R=dx, G=dy, B=up
        strength = 2.0
        nx = np.clip(-dx * strength * 0.5 + 0.5, 0, 1)
        ny = np.clip(-dy * strength * 0.5 + 0.5, 0, 1)
        nz = np.ones_like(height) * 0.9
        normal = np.stack([nx, ny, nz], axis=-1)
        normal = (normal * 255).astype(np.uint8)
        return Image.fromarray(normal, "RGB")

    def _gen_roughness_map(self, w: int, h: int, seed: int, prompt: str) -> Image.Image:
        """Generate roughness map."""
        base = _fbm((h, w), 4, seed + 300, 48.0)
        prompt_lower = prompt.lower()
        if any(k in prompt_lower for k in ["metal", "chrome", "glass"]):
            base = base * 0.3 + 0.1  # Smooth/shiny
        elif any(k in prompt_lower for k in ["concrete", "rough", "brick"]):
            base = base * 0.4 + 0.5  # Rough
        else:
            base = base * 0.3 + 0.35  # Medium
        gray = (np.clip(base, 0, 1) * 255).astype(np.uint8)
        return Image.fromarray(gray, "L").convert("RGB")

    def _gen_metallic_map(self, w: int, h: int, seed: int, prompt: str) -> Image.Image:
        """Generate metallic map."""
        prompt_lower = prompt.lower()
        if any(k in prompt_lower for k in ["metal", "chrome", "steel"]):
            base = _fbm((h, w), 3, seed + 400, 64.0) * 0.3 + 0.7
        else:
            base = _fbm((h, w), 3, seed + 400, 64.0) * 0.15
        gray = (np.clip(base, 0, 1) * 255).astype(np.uint8)
        return Image.fromarray(gray, "L").convert("RGB")

    def _gen_ao_map(self, w: int, h: int, seed: int) -> Image.Image:
        """Generate ambient occlusion map."""
        base = _fbm((h, w), 5, seed + 500, 80.0)
        ao = base * 0.3 + 0.7  # Mostly white with dark crevices
        gray = (np.clip(ao, 0, 1) * 255).astype(np.uint8)
        return Image.fromarray(gray, "L").convert("RGB")

    def _gen_height_map(self, w: int, h: int, seed: int) -> Image.Image:
        """Generate height/displacement map."""
        base = _fbm((h, w), 6, seed + 600, 64.0)
        gray = (np.clip(base, 0, 1) * 255).astype(np.uint8)
        return Image.fromarray(gray, "L").convert("RGB")

    def _gen_emissive_map(self, w: int, h: int, seed: int, palette: Dict) -> Image.Image:
        """Generate emissive map (neon signs, lights)."""
        strength = palette.get("emissive_strength", 0.5)
        img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
        draw = ImageDraw.Draw(img)
        rng = np.random.RandomState(seed + 700)

        if strength > 0.5:
            # Strong emissive — neon lines and spots
            accent_colors = palette.get("accent", [(255, 0, 255)])
            for _ in range(int(15 * strength)):
                color = accent_colors[rng.randint(len(accent_colors))]
                x1, y1 = rng.randint(0, w), rng.randint(0, h)
                x2, y2 = x1 + rng.randint(-w // 3, w // 3), y1 + rng.randint(-h // 3, h // 3)
                lw = rng.randint(2, 6)
                draw.line([(x1, y1), (x2, y2)], fill=(*color, 200), width=lw)
            # Glow spots
            for _ in range(int(10 * strength)):
                color = accent_colors[rng.randint(len(accent_colors))]
                cx, cy = rng.randint(0, w), rng.randint(0, h)
                r = rng.randint(10, 40)
                draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*color, 150))
            img = img.filter(ImageFilter.GaussianBlur(radius=4))
        else:
            # Subtle emissive
            base = np.zeros((h, w, 4), dtype=np.uint8)
            base[:, :, 3] = 255
            accent = palette.get("accent", [(255, 200, 50)])[0]
            for _ in range(5):
                cx, cy = rng.randint(0, w), rng.randint(0, h)
                r = rng.randint(5, 20)
                for dy in range(-r, r + 1):
                    for dx in range(-r, r + 1):
                        py, px = (cy + dy) % h, (cx + dx) % w
                        d = math.sqrt(dx * dx + dy * dy)
                        if d < r:
                            alpha = int(255 * (1 - d / r) * strength)
                            base[py, px] = [accent[0], accent[1], accent[2], alpha]
            img = Image.fromarray(base, "RGBA")

        return img.convert("RGB")

    # ------------------------------------------------------------------
    # Prop generation
    # ------------------------------------------------------------------

    def _gen_prop(
        self, w: int, h: int, seed: int,
        palette: Dict, prompt: str, params: Dict,
    ) -> Image.Image:
        """Generate a prop silhouette card with alpha."""
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        rng = np.random.RandomState(seed)
        prompt_lower = prompt.lower()

        primary = palette["primary"][0]
        secondary = palette["secondary"][0]

        if any(k in prompt_lower for k in ["tree", "palm"]):
            self._draw_tree(draw, w, h, rng, primary, secondary)
        elif any(k in prompt_lower for k in ["sign", "neon"]):
            self._draw_sign(draw, w, h, rng, palette)
        elif any(k in prompt_lower for k in ["bench", "seat"]):
            self._draw_bench(draw, w, h, rng, secondary)
        elif any(k in prompt_lower for k in ["lamp", "light", "post"]):
            self._draw_lamp(draw, w, h, rng, palette)
        elif any(k in prompt_lower for k in ["barrel", "crate", "box"]):
            self._draw_crate(draw, w, h, rng, secondary)
        elif any(k in prompt_lower for k in ["fence", "railing"]):
            self._draw_fence(draw, w, h, rng, secondary)
        elif any(k in prompt_lower for k in ["hoop", "basket", "ring"]):
            self._draw_hoop(draw, w, h, rng, palette)
        elif any(k in prompt_lower for k in ["speaker", "amp"]):
            self._draw_speaker(draw, w, h, rng, secondary)
        else:
            # Generic rectangular prop
            self._draw_generic_prop(draw, w, h, rng, palette)

        return img

    def _draw_tree(self, draw, w, h, rng, leaf_color, trunk_color):
        trunk_w = w // 12
        trunk_x = w // 2 - trunk_w // 2
        draw.rectangle([trunk_x, h // 3, trunk_x + trunk_w, h], fill=(*trunk_color, 220))
        # Canopy
        for i in range(5):
            cx = w // 2 + rng.randint(-w // 8, w // 8)
            cy = h // 4 + rng.randint(-h // 8, h // 8)
            rx, ry = w // 4 + rng.randint(-20, 20), h // 5 + rng.randint(-10, 10)
            shade = tuple(max(0, c + rng.randint(-30, 30)) for c in leaf_color)
            draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(*shade, 200))

    def _draw_sign(self, draw, w, h, rng, palette):
        accent = palette["accent"][0]
        # Sign body
        margin = w // 6
        draw.rectangle([margin, h // 4, w - margin, h * 3 // 4], fill=(40, 40, 50, 230), outline=(*accent, 255), width=3)
        # Neon text lines
        for i in range(3):
            y = h // 4 + (i + 1) * (h // 8)
            x1 = margin + 20
            x2 = w - margin - 20 - rng.randint(0, w // 4)
            color = palette["accent"][rng.randint(len(palette["accent"]))]
            draw.line([(x1, y), (x2, y)], fill=(*color, 220), width=4)
        # Post
        post_x = w // 2
        draw.rectangle([post_x - 4, h * 3 // 4, post_x + 4, h], fill=(80, 80, 80, 200))

    def _draw_bench(self, draw, w, h, rng, color):
        seat_y = h * 2 // 3
        draw.rectangle([w // 6, seat_y, w * 5 // 6, seat_y + h // 12], fill=(*color, 220))
        # Legs
        for x in [w // 4, w * 3 // 4]:
            draw.rectangle([x - 5, seat_y, x + 5, h - 10], fill=(*color, 200))
        # Back
        draw.rectangle([w // 6, seat_y - h // 6, w * 5 // 6, seat_y], fill=(*color, 180))

    def _draw_lamp(self, draw, w, h, rng, palette):
        accent = palette["accent"][0]
        post_x = w // 2
        draw.rectangle([post_x - 4, h // 6, post_x + 4, h], fill=(100, 100, 100, 220))
        # Light fixture
        draw.ellipse([post_x - 20, h // 6 - 20, post_x + 20, h // 6 + 20], fill=(*accent, 200))
        # Glow
        for r in range(40, 10, -5):
            alpha = 30 + (40 - r) * 3
            draw.ellipse([post_x - r, h // 6 - r, post_x + r, h // 6 + r], fill=(*accent, min(alpha, 255)))

    def _draw_crate(self, draw, w, h, rng, color):
        margin = w // 4
        draw.rectangle([margin, h // 3, w - margin, h - 10], fill=(*color, 220), outline=(60, 50, 40, 255), width=2)
        # Cross braces
        draw.line([(margin, h // 3), (w - margin, h - 10)], fill=(80, 70, 60, 180), width=2)
        draw.line([(w - margin, h // 3), (margin, h - 10)], fill=(80, 70, 60, 180), width=2)

    def _draw_fence(self, draw, w, h, rng, color):
        post_spacing = w // 8
        for x in range(0, w, post_spacing):
            draw.rectangle([x, h // 4, x + 4, h], fill=(*color, 200))
        # Rails
        for y_frac in [0.3, 0.5, 0.7]:
            y = int(h * y_frac)
            draw.line([(0, y), (w, y)], fill=(*color, 180), width=3)

    def _draw_hoop(self, draw, w, h, rng, palette):
        accent = palette["accent"][0]
        # Backboard
        bw, bh = w // 3, h // 4
        bx = w // 2 - bw // 2
        by = h // 6
        draw.rectangle([bx, by, bx + bw, by + bh], fill=(255, 255, 255, 200), outline=(200, 200, 200, 255), width=2)
        # Rim
        rim_y = by + bh
        draw.ellipse([w // 2 - 30, rim_y, w // 2 + 30, rim_y + 15], outline=(*accent, 255), width=3)
        # Net lines
        for i in range(6):
            x = w // 2 - 25 + i * 10
            draw.line([(x, rim_y + 10), (x + rng.randint(-5, 5), rim_y + 60)], fill=(255, 255, 255, 150), width=1)
        # Pole
        draw.rectangle([w // 2 - 5, by, w // 2 + 5, h], fill=(120, 120, 120, 220))

    def _draw_speaker(self, draw, w, h, rng, color):
        margin = w // 4
        draw.rectangle([margin, h // 4, w - margin, h * 3 // 4], fill=(*color, 220), outline=(40, 40, 40, 255), width=2)
        # Speaker cones
        for cy_frac in [0.4, 0.6]:
            cy = int(h * cy_frac)
            draw.ellipse([w // 2 - 30, cy - 30, w // 2 + 30, cy + 30], fill=(30, 30, 30, 220), outline=(60, 60, 60, 200), width=2)
            draw.ellipse([w // 2 - 10, cy - 10, w // 2 + 10, cy + 10], fill=(50, 50, 50, 220))

    def _draw_generic_prop(self, draw, w, h, rng, palette):
        color = palette["primary"][rng.randint(len(palette["primary"]))]
        margin = w // 5
        top = h // 4
        draw.rectangle([margin, top, w - margin, h - 10], fill=(*color, 200), outline=(*palette["secondary"][0], 255), width=2)

    # ------------------------------------------------------------------
    # Atmosphere overlays
    # ------------------------------------------------------------------

    def _gen_atmosphere(
        self, w: int, h: int, seed: int,
        palette: Dict, prompt: str, params: Dict,
    ) -> Image.Image:
        """Generate atmospheric overlay (fog, particles, dust, light rays)."""
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        prompt_lower = prompt.lower()
        rng = np.random.RandomState(seed)
        atm_color = palette.get("atmosphere", (100, 100, 100, 120))

        if any(k in prompt_lower for k in ["fog", "mist", "haze"]):
            img = self._gen_fog(w, h, seed, atm_color)
        elif any(k in prompt_lower for k in ["particle", "dust", "snow"]):
            img = self._gen_particles(w, h, seed, palette, prompt_lower)
        elif any(k in prompt_lower for k in ["ray", "light", "beam", "god"]):
            img = self._gen_light_rays(w, h, seed, palette)
        elif any(k in prompt_lower for k in ["rain", "drizzle"]):
            img = self._gen_rain(w, h, seed)
        elif any(k in prompt_lower for k in ["smoke", "steam"]):
            img = self._gen_fog(w, h, seed, (*atm_color[:3], min(atm_color[3] + 40, 255)))
        else:
            # Default: subtle atmospheric haze
            img = self._gen_fog(w, h, seed, atm_color)
        return img

    def _gen_fog(self, w: int, h: int, seed: int, color: Tuple) -> Image.Image:
        noise = _fbm((h, w), 5, seed + 800, 128.0)
        r, g, b, base_a = color
        alpha = (noise * base_a).astype(np.uint8)
        arr = np.zeros((h, w, 4), dtype=np.uint8)
        arr[:, :, 0] = r
        arr[:, :, 1] = g
        arr[:, :, 2] = b
        arr[:, :, 3] = alpha
        img = Image.fromarray(arr, "RGBA")
        return img.filter(ImageFilter.GaussianBlur(radius=8))

    def _gen_particles(self, w: int, h: int, seed: int, palette: Dict, prompt_lower: str) -> Image.Image:
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        rng = np.random.RandomState(seed + 900)
        is_snow = "snow" in prompt_lower
        count = 300 if is_snow else 150
        for _ in range(count):
            x, y = rng.randint(0, w), rng.randint(0, h)
            size = rng.randint(1, 4) if is_snow else rng.randint(1, 3)
            alpha = rng.randint(80, 220)
            if is_snow:
                draw.ellipse([x, y, x + size, y + size], fill=(255, 255, 255, alpha))
            else:
                color = palette["primary"][rng.randint(len(palette["primary"]))]
                draw.ellipse([x, y, x + size, y + size], fill=(*color, alpha))
        return img.filter(ImageFilter.GaussianBlur(radius=1))

    def _gen_light_rays(self, w: int, h: int, seed: int, palette: Dict) -> Image.Image:
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        rng = np.random.RandomState(seed + 1000)
        accent = palette["accent"][0]
        source_x = rng.randint(w // 4, w * 3 // 4)
        for i in range(12):
            angle = (i / 12.0) * np.pi + rng.uniform(-0.1, 0.1)
            length = h * rng.uniform(0.5, 1.0)
            end_x = source_x + int(length * np.cos(angle))
            end_y = int(length * np.sin(angle))
            ray_width = rng.randint(5, 25)
            alpha = rng.randint(20, 80)
            draw.line([(source_x, 0), (end_x, end_y)], fill=(*accent, alpha), width=ray_width)
        return img.filter(ImageFilter.GaussianBlur(radius=6))

    def _gen_rain(self, w: int, h: int, seed: int) -> Image.Image:
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        rng = np.random.RandomState(seed + 1100)
        for _ in range(400):
            x = rng.randint(0, w)
            y = rng.randint(0, h)
            length = rng.randint(10, 30)
            alpha = rng.randint(40, 120)
            draw.line([(x, y), (x - 2, y + length)], fill=(180, 200, 220, alpha), width=1)
        return img.filter(ImageFilter.GaussianBlur(radius=0.5))

    # ------------------------------------------------------------------
    # Skybox generation
    # ------------------------------------------------------------------

    def _gen_skybox(
        self, w: int, h: int, seed: int,
        palette: Dict, prompt: str, params: Dict,
    ) -> Image.Image:
        """Generate equirectangular panoramic skybox."""
        sky_colors = palette.get("sky_gradient", [(20, 30, 60), (60, 80, 140), (180, 120, 80)])
        arr = np.zeros((h, w, 3), dtype=np.uint8)

        # Sky gradient (top to bottom)
        for y in range(h):
            t = y / max(h - 1, 1)
            if t < 0.5:
                t2 = t / 0.5
                c = self._lerp_color(sky_colors[0], sky_colors[1], t2)
            else:
                t2 = (t - 0.5) / 0.5
                c = self._lerp_color(sky_colors[1], sky_colors[-1], t2)
            arr[y, :] = c

        # Add cloud noise
        clouds = _fbm((h, w), 5, seed + 1200, 200.0)
        cloud_mask = (clouds > 0.55).astype(np.float32)
        cloud_mask *= (clouds - 0.55) / 0.45
        for c in range(3):
            arr[:, :, c] = np.clip(
                arr[:, :, c].astype(np.float32) + cloud_mask * 80, 0, 255
            ).astype(np.uint8)

        # Stars for night scenes
        if palette.get("emissive_strength", 0) > 0.4:
            rng = np.random.RandomState(seed + 1300)
            star_count = 200
            for _ in range(star_count):
                sx, sy = rng.randint(0, w), rng.randint(0, h // 2)
                brightness = rng.randint(150, 255)
                size = rng.choice([1, 1, 1, 2])
                for dy in range(size):
                    for dx in range(size):
                        py, px = min(sy + dy, h - 1), min(sx + dx, w - 1)
                        arr[py, px] = [brightness, brightness, brightness]

        # Atmospheric haze at horizon
        haze = palette.get("atmosphere", (100, 100, 100, 80))
        horizon_band = h // 3
        for y in range(h // 2 - horizon_band // 2, h // 2 + horizon_band // 2):
            t = 1.0 - abs(y - h // 2) / (horizon_band // 2)
            alpha = t * haze[3] / 255.0 * 0.4
            for c in range(3):
                arr[y, :, c] = np.clip(
                    arr[y, :, c].astype(np.float32) * (1 - alpha) + haze[c] * alpha,
                    0, 255
                ).astype(np.uint8)

        return Image.fromarray(arr, "RGB")

    # ------------------------------------------------------------------
    # Detail & Decal generation
    # ------------------------------------------------------------------

    def _gen_detail(
        self, w: int, h: int, seed: int,
        palette: Dict, prompt: str, params: Dict,
    ) -> Image.Image:
        """Generate small decorative details (graffiti, cracks, stains)."""
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        rng = np.random.RandomState(seed + 1400)
        prompt_lower = prompt.lower()

        if "graffiti" in prompt_lower or "tag" in prompt_lower:
            colors = palette["accent"] + palette["primary"]
            for _ in range(8):
                color = colors[rng.randint(len(colors))]
                points = [(rng.randint(0, w), rng.randint(0, h)) for _ in range(6)]
                for j in range(len(points) - 1):
                    draw.line([points[j], points[j + 1]], fill=(*color, rng.randint(150, 255)), width=rng.randint(3, 8))
        elif "crack" in prompt_lower:
            for _ in range(5):
                x, y = rng.randint(0, w), rng.randint(0, h)
                for _ in range(20):
                    nx = x + rng.randint(-10, 10)
                    ny = y + rng.randint(2, 8)
                    draw.line([(x, y), (nx, ny)], fill=(40, 40, 40, 180), width=rng.choice([1, 1, 2]))
                    x, y = nx, min(ny, h - 1)
        else:
            # Generic stain / mark
            for _ in range(3):
                cx, cy = rng.randint(0, w), rng.randint(0, h)
                r = rng.randint(20, 80)
                color = palette["secondary"][0]
                draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*color, 60))

        return img

    def _gen_decal(
        self, w: int, h: int, seed: int,
        palette: Dict, prompt: str, params: Dict,
    ) -> Image.Image:
        """Generate overlay decal with alpha."""
        return self._gen_detail(w, h, seed + 50, palette, prompt, params)

    # ------------------------------------------------------------------
    # Utilities
    # ------------------------------------------------------------------

    def _colorize(self, noise: np.ndarray, colors: List[Tuple], seed: int) -> Image.Image:
        """Map 0-1 noise to a color palette."""
        h, w = noise.shape
        arr = np.zeros((h, w, 3), dtype=np.uint8)
        n_colors = len(colors)
        for y in range(h):
            for x in range(w):
                t = noise[y, x] * (n_colors - 1)
                idx = min(int(t), n_colors - 2)
                frac = t - idx
                c = self._lerp_color(colors[idx], colors[idx + 1], frac)
                arr[y, x] = c
        return Image.fromarray(arr, "RGB")

    @staticmethod
    def _lerp_color(c1: Tuple, c2: Tuple, t: float) -> Tuple:
        return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
