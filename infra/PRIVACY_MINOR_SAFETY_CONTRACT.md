# Privacy & minor safety contract (PRIVACY-09)

Final Evolution Lab treats **athlete identity, PRQ, HealthKit-adjacent signals, nutrition, social surfaces, and coaching** as sensitive. Defaults are **private / fail-closed** unless the product explicitly opts the user in with clear consent boundaries.

## Public athlete discovery (`GET /api/social/athletes`)

- **Explicit opt-in only**: Mongo field **`discovery_opt_in: true`** is required. Missing or `false` users do **not** appear (no implicit discovery for legacy rows).
- **Minors**: For users with a parsable **`date_of_birth`**, if age \< 18 they are **hidden from discovery** unless **`parental_consent_acknowledged`** is true (guardian consent aligned with Settings / Safety flows).
- **PRQ in search results**: **`prq_score`** is returned only when **`include_prq_in_public_athlete_search`** passes server checks. **Minors never receive PRQ** in this list, even if **`profile_public_metrics_opt_in`** is true.

Implementation: `backend/privacy_minors.py`, `backend/server.py` (`search_athletes`).

## Shareable athlete pass (PNG + meta)

- Fetching `/api/system-scan/pass/{user_id}.png` and `/pass-meta/{user_id}` already requires a valid **`pass_share_token`** (query `t=`) unless legacy env bypass is enabled — see `backend/routers/pass_image.py`.
- **Minors without guardian consent** cannot load the public pass (`403`), consistent with token issuance rules.
- **`POST /api/system-scan/pass-share-token`**: Issuance is **blocked** for minors without **`parental_consent_acknowledged`** (cannot mint a share link).
- **HTTP response headers** on the PNG response **must not** echo the raw **`user_id`** (no `X-FEL-User`). PRQ may appear as `X-FEL-PRQ` or `hidden` depending on pass metrics opt-in.
- **Pass image artwork** footer does not print internal user identifiers — site URL only.
- **`pass-meta` JSON** omits the **`user_id`** field from the payload body (callers already scoped the request by path); **`og_image_url_path`** still uses the route shape required to load the image.

## Client (Swift)

- **`AthleteSafetyPolicy`** exposes helpers aligned with backend rules: **`publicAthleteDiscoveryAllowed`**, **`publicAthleteSearchOmitsPRQForMinor`**, **`isMinorProfile`**. Sensitive feeds / SQL mutations continue to use **`assertSensitiveMinorGate`**.

## Field alignment

- Backend Mongo / session user: **`date_of_birth`**, **`parental_consent_acknowledged`**, **`discovery_opt_in`**, **`profile_public_metrics_opt_in`**, **`pass_public_metrics_opt_in`** (pass card PRQ display).
- iOS profile: **`guardianConsentForMinorFeatures`** should stay consistent with backend parental consent when syncing profile from API (future sync layers should map explicitly).

## Related tests

- Integration tests against live deployments may return **zero** athletes until users set **`discovery_opt_in: true`** — this is expected under explicit opt-in.
