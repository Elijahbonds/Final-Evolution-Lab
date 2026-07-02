# BioFuel / nutrition safety contract

This document scopes **Final Evolution Lab** nutrition tooling (BioFuel stripe, meal logging, vision scan, and delivery helpers). It is **not medical nutrition therapy** and does not replace a registered dietitian, physician, or team clinician.

## Scope of practice

- BioFuel provides **macro estimates**, **pattern cues**, and **logging** for self-awareness and training context.
- Automated labels (vision scan, seeded delivery suggestions, cookbook entries) may be **wrong**. Athletes confirm scans before commit; delivery seeds are illustrative until partner APIs are integrated.
- **Allergy and diet filters** use naive substring matching on names/ingredients. They reduce obviously conflicting items but **cannot guarantee** absence of allergens or compliance with medical diets. Athletes with severe allergy or clinical diets must verify labels with the restaurant or clinician.

## Single-meal validation (server)

`POST /api/biofuel/log` rejects out-of-range values. Intended as corrupted-input guardrails, not clinical judgment:

| Field | Approximate per-meal cap |
|-------|---------------------------|
| `calories` | 3,500 kcal |
| `protein_g` | 220 g |
| `carbs_g` | 450 g |
| `fats_g` | 180 g |
| `hydration_ml` | 2,500 ml |

Vision `/scan` clamps model output to the same bands before persisting pending scans.

## Hydration logging

- **`hydration_ml`** on the log payload is the first-class fluids field for a meal (manual, partner sources).
- Vision scans still expose hydration inside **`micros.hydration_ml`** until confirmed.
- Daily hydration consumed totals **prefer top-level `hydration_ml` when present** for an entry; otherwise they use `micros.hydration_ml`, so the same fluid is not counted twice.

## Idempotency (duplicate prevention)

- Logs may include **`client_event_id`** (string, same calendar day scope).
- If the same `client_event_id` already exists in today’s diary for that user, the API returns success with **`deduped: true`** and does not append again.
- DoorDash “Log meal” uses a deterministic idempotency key derived from **intent + dish name + UTC date** so accidental double-taps on the same meal do not stack duplicate entries.

## Delivery matching when filters remove all options

- When allergy/diet tokens filter out every candidate for the current macro window, **`POST /api/biofuel/doordash-search`** returns **`no_safe_matches: true`**, an explanatory **`message`**, and an empty **`matches`** array.
- The client must surface this explicitly instead of an empty silent list.

## Tone and commerce boundaries

- Coach copy stays **supportive** (not punitive).
- Third-party grocery and meal links are **real-world food** commerce, separate from **App Store** digital purchases; surfaces remain user-initiated ordering aids only.
