# NEXUS Asset Spec — mobile budgets & naming conventions

Sprint 1 (`nexus/asset-pipeline`). Complements
`docs/architecture/NEXUS_Asset_Pipeline.md` (mesh import pipeline) — this doc
covers **textures, atlases, particle sheets, and per-tier budgets** for the
NEXUS mobile renderer. Target: **60 FPS** on all tiers.

## Device tiers

| Tier | Reference device | Frame budget | Notes |
|------|------------------|--------------|-------|
| `mobile-low` | iPhone SE 2 / A13 | 16.6 ms | reduced particle counts, no bloom |
| `mobile-mid` | iPhone 12 / A14 | 16.6 ms | baseline ship target (matches mesh spec) |
| `mobile-high` | iPhone 15 Pro+ / M-class | 16.6 ms (120 Hz opportunistic) | full post stack |

## Mesh budgets (existing — do not change here)

Source of truth: `docs/architecture/NEXUS_Asset_Pipeline.md` §Mobile LOD
strategy and `scripts/nexus_mobile_mesh_gate.sh`.

| Stage | Verts | Tris |
|-------|-------|------|
| Default venues | ≤ 50,000 | ≤ 80,000 |
| Zen Dojo | ≤ 40,000 | ≤ 60,000 |
| **Total on-screen ceiling** | — | **≤ 130,000** (venue + characters + props) |

## Texture budgets (this spec)

| Asset class | mobile-low | mobile-mid | mobile-high | Format priority |
|-------------|-----------|-----------|------------|-----------------|
| Environment diffuse (`tex_env_*_d`) | 1024² | 2048² | 2048² | ASTC 6x6 → ETC2 → PNG |
| Environment normal (`tex_env_*_n`) | 512² | 1024² | 2048² | ASTC 6x6 → PNG |
| Character (`tex_chr_*`) | 1024² | 1024² | 2048² | ASTC 6x6 → PNG |
| UI / HUD (`ui_*`) | 1024² atlas | 2048² atlas | 2048² atlas | PNG (crisp) / ASTC 4x4 |
| FX atlas (`fx_*`) | 1024² | 2048² | 2048² | ASTC 6x6 → PNG |
| Particle flipbook (`*_sheet`) | 256² | 512² | 512² | ASTC 8x8 → PNG |

Hard limits enforced by `scripts/assets/validate_assets.py`:

* All texture dimensions **power of two**, max **2048** per side.
* Single PNG file ≤ **4 MiB**; atlas manifest UVs within [0, 1].
* Mip chains complete down to 1×1 (descriptor-checked).
* Particle sheets: frame grid must cover declared frame count; frame size POT.

Texture RAM ceiling per scene (steady state, compressed): **≤ 96 MiB** on
mobile-mid (about half of the iPhone 12 comfortable GPU working set, leaving
room for meshes, render targets, and the OS).

## Particle / VFX budgets

| Metric | mobile-low | mobile-mid | mobile-high |
|--------|-----------|-----------|------------|
| Live particles per scene | 512 | 2,048 | 8,192 |
| Particle draw calls (batched sheets) | ≤ 4 | ≤ 8 | ≤ 12 |
| Flipbook frames per sheet | ≤ 16 | ≤ 25 | ≤ 64 |

## Naming conventions

```
tex_<domain>_<name>_<map>.png     e.g. tex_env_court_d.png  (d|n|r|ao|e)
spr_<domain>_<name>.png           e.g. spr_fx_ball.png
<name>_sheet.png / .sheet.json    particle flipbooks (paired)
<name>.atlas.json + <name>.png    packed atlases (paired)
<asset_id>_mobile.nexusmesh.json  meshes (existing convention — unchanged)
```

Domains: `env` (venues), `chr` (characters), `fx` (effects), `ui` (HUD/menus).
Lowercase snake_case only; no spaces or unicode in asset filenames.

## Directory layout

```
assets/nexus/samples/      committed, deterministic samples (gen_samples.py)
assets/nexus/generated/    pipeline outputs — gitignored except samples' outputs
assets/nexus/imported/     mesh pipeline outputs (existing)
assets/nexus/source/       raw drops (gitignored, existing)
```

## Pipeline entry points

| Script | Purpose |
|--------|---------|
| `scripts/assets/gen_samples.py` | regenerate deterministic sample sprites/textures |
| `scripts/assets/atlas_gen.py` | pack sprites into a POT atlas + UV manifest |
| `scripts/assets/mipmap_gen.py` | full Lanczos mip chain + descriptor per texture |
| `scripts/assets/compress_textures.py` | ASTC via `astcenc` if installed; honest `.todo.json` placeholders otherwise (ETC2 always deferred descriptor for now) |
| `scripts/assets/particle_sheet_gen.py` | procedural puff/spark/ring flipbooks for GPU particles |
| `scripts/assets/validate_assets.py` | enforce this spec (formats, sizes, budgets, naming, pairing) |

CI/local one-liner:

```bash
python3 scripts/assets/gen_samples.py --output assets/nexus/samples
python3 scripts/assets/atlas_gen.py --input assets/nexus/samples/sprites --output assets/nexus/generated/atlas/fx_atlas
python3 scripts/assets/mipmap_gen.py --input assets/nexus/samples/textures --output assets/nexus/generated/mips
python3 scripts/assets/compress_textures.py --input assets/nexus/samples/textures --output assets/nexus/generated/compressed
python3 scripts/assets/particle_sheet_gen.py --output assets/nexus/generated/particles
python3 scripts/assets/validate_assets.py --root assets/nexus --tier mobile-mid
```
