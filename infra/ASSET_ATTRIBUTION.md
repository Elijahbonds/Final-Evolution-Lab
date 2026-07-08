# Asset Attribution — Art Showcase Mode

All assets shipped for the Art Showcase Mode (`nexus/art-mode-core`) are
**original works** or **CC0 / public-domain**. No real film stills, celebrity
likenesses, or copyrighted artwork are used, per the IP constraint.

| Asset | Path | Type | Source | License |
|---|---|---|---|---|
| Aurora Field | `frontend/public/nexus-art-assets/images/aurora_gradient.svg` | image (SVG) | Original — FEL Studio | CC0-1.0 |
| Geo Facets | `frontend/public/nexus-art-assets/images/geo_facets.svg` | image (SVG) | Original — FEL Studio | CC0-1.0 |
| Ink Flow | `frontend/public/nexus-art-assets/images/ink_flow.svg` | image (SVG) | Original — FEL Studio | CC0-1.0 |
| Stipple Orb | `frontend/public/nexus-art-assets/images/stipple_orb.svg` | image (SVG) | Original — FEL Studio (pointillism/stippling study) | CC0-1.0 |
| Cross-Hatch Sphere | `frontend/public/nexus-art-assets/images/crosshatch_sphere.svg` | image (SVG) | Original — FEL Studio (cross-hatching study) | CC0-1.0 |
| Chiaroscuro Study | `frontend/public/nexus-art-assets/images/chiaroscuro_study.svg` | image (SVG) | Original — FEL Studio (value/chiaroscuro study) | CC0-1.0 |
| Study Cube | `frontend/public/nexus-art-assets/models/box.gltf` | 3D (glTF 2.0) | Khronos glTF `Box` sample geometry, regenerated with an original PBR material (data-URI embedded, 648-byte buffer, <1 KB total) | CC0-1.0 |
| Facet Gem | `frontend/public/nexus-art-assets/models/facet_gem.gltf` | 3D (glTF 2.0) | Original — FEL Studio; procedurally-authored cyan octahedron (8 tris, flat normals, embedded 624-byte buffer, <1 KB total) | CC0-1.0 |
| Aurora Prism | `frontend/public/nexus-art-assets/models/aurora_prism.gltf` | 3D (glTF 2.0) | Original — FEL Studio; procedurally-authored violet hexagonal bipyramid (12 tris, flat normals, embedded 936-byte buffer, <1 KB total) | CC0-1.0 |

## Notes

- SVG images are authored inline (vector), so no raster binaries ship. Each
  carries a `role="img"` + `aria-label` for accessibility, and `alt`/`license`/
  `source` metadata is served by `GET /api/art/sample-exhibit`.
- The glTF models are all single-mesh, single-primitive, indexed
  POSITION+NORMAL geometry with one `pbrMetallicRoughness` material and an
  embedded base64 buffer (`data:` URI). No external buffer/texture files; each
  is well under 1 MB (and the 5 MB binary limit). `box.gltf` uses the Khronos
  `Box` topology; `facet_gem.gltf` and `aurora_prism.gltf` are original
  procedurally-generated convex solids with flat (per-face) normals, verified
  to render in the dependency-free `frontend/src/lib/gltfViewer.js` without any
  viewer changes.
- Guess-the-technique question content in `backend/lib/art_content.py` is
  original educational text written for FEL. The bank covers composition,
  color/value, mark-making, rendering, and 3D categories across easy/medium/
  hard difficulty. Correct answers and lessons are never shipped in the round
  payload — only an opaque HMAC `answer_token` the client echoes back on
  submission for integrity verification.
