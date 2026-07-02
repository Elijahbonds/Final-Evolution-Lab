# FEL OS Bio-Fuel — Image Integration Testing Playbook

## TEST AGENT PROMPT – IMAGE INTEGRATION RULES

You are the Test Agent responsible for validating image integrations for the FEL OS Bio-Fuel scanner (`POST /api/biofuel/scan`).

Follow these rules exactly. Do not overcomplicate.

### Image Handling Rules
- Always use base64-encoded images for all tests and requests.
- Accepted formats: **JPEG, PNG, WEBP only**.
- Do **not** use SVG, BMP, HEIC, or other formats.
- Do **not** upload blank, solid-color, or uniform-variance images.
- Every image must contain real visual features — such as objects, edges, textures, or shadows.
- If the image is not PNG/JPEG/WEBP, transcode it to PNG or JPEG before upload.
  - **Fix Example:** If you read a `.jpg` but the content is actually PNG after conversion or compression — this is invalid. Always re-detect and update the MIME after transformations.
- If the image is animated (e.g., GIF, APNG, WEBP animation), extract the first frame only.
- Resize large images to reasonable bounds (avoid oversized payloads).

### Model selection
- The endpoint accepts `model` in the body — must be one of: `gemini-2.5-flash`, `gpt-5.2`.
- Default to `gemini-2.5-flash` if unset (athlete-pickable in UI).

### Expected response shape (NASM-CNC schema)
```json
{
  "scan_id": "scan_<uuid>",
  "model": "gemini-2.5-flash",
  "label": "Grilled chicken bowl with brown rice",
  "calories": 612,
  "protein_g": 48,
  "carbs_g": 64,
  "fats_g": 18,
  "micros": {
    "collagen_g": 0.0,
    "omega3_mg": 240,
    "magnesium_mg": 88,
    "sodium_mg": 720,
    "hydration_ml": 240
  },
  "athletic_intent": "post_dunk_recovery",
  "nutri_shards_awarded": 12,
  "scanned_at": "2026-...Z"
}
```

### Test images (real food, not synthetic)
- Use a small JPEG (≤200 KB) of an actual meal — supplied via fixtures or fetched once and cached.
- Do not generate procedural noise images for vision testing.
