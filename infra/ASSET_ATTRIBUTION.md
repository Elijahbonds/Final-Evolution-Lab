# Asset Attribution — Art Showcase Mode

All assets shipped for the Art Showcase Mode (`nexus/art-mode-core`) are
**original works** or **CC0 / public-domain**. No real film stills, celebrity
likenesses, or copyrighted artwork are used, per the IP constraint.

| Asset | Path | Type | Source | License |
|---|---|---|---|---|
| Aurora Field | `frontend/public/nexus-art-assets/images/aurora_gradient.svg` | image (SVG) | Original — FEL Studio | CC0-1.0 |
| Geo Facets | `frontend/public/nexus-art-assets/images/geo_facets.svg` | image (SVG) | Original — FEL Studio | CC0-1.0 |
| Ink Flow | `frontend/public/nexus-art-assets/images/ink_flow.svg` | image (SVG) | Original — FEL Studio | CC0-1.0 |
| Study Cube | `frontend/public/nexus-art-assets/models/box.gltf` | 3D (glTF 2.0) | Khronos glTF `Box` sample geometry, regenerated with an original PBR material (data-URI embedded, 648-byte buffer, <1 KB total) | CC0-1.0 |

## Notes

- SVG images are authored inline (vector), so no raster binaries ship. Each
  carries a `role="img"` + `aria-label` for accessibility, and `alt`/`license`/
  `source` metadata is served by `GET /api/art/sample-exhibit`.
- The glTF model is a standard axis-aligned unit cube using the Khronos `Box`
  topology, re-serialized with an embedded base64 buffer and an original cyan
  PBR material. No external buffer/texture files; total size well under 1 MB
  (and under the 5 MB binary limit).
- Guess-the-technique question content in `backend/lib/art_content.py` is
  original educational text written for FEL.
