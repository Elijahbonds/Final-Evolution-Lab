# Education & certificate integrity contract

Backend routes under **`/api/education`** and **`/api/brain-brawl/session/*`** implement anti-shortcut and anti-replay behaviors described here. Pair with **`infra/SYSTEM_SCAN_ACCURACY_CONTRACT.md`** for PRQ gates.

## Kinesiology final assessment (`/education/kinesiology/final-assessment/submit`)

- Grading runs **after** validating answers shape and expiration.
- **`kin_final_sessions`** is updated with **`used: false`** in the filter — **exactly one** concurrent submit can succeed (`modified_count == 1`). A losing racer receives **409** (`attempt already submitted`).
- **`final_verified_receipt`** is issued **only** when the attempt passes the server-graded threshold — never fabricated from legacy **`final_passed`** alone.

### Legacy state

- Auto-upgrade from **`final_passed`** → **`final_verified_receipt`** was **removed**. Users who only had an old “passed” flag without a verified attempt must **re-pass** the server-proctored final or remain ineligible for certification until they do.

## Bio-Digital modules (`/education/bio-digital/begin-module` → `complete-module`)

- **`begin-module`** stores **`issued_at`** (UTC) on the completion receipt document.
- **`complete-module`** rejects completion until **`now - issued_at ≥ BIO_DIGITAL_MIN_ACTIVE_SECONDS`** (default **3s** in code; production deployments should set **`FEL_BIO_DIGITAL_MIN_ACTIVE_SECONDS`** to **45–120**).
- Receipt consumption uses **`_id` + `used: false`** so double-complete races return **409**.

## Brain Brawl quiz (`POST /api/brain-brawl/session/submit`)

- Score and XP are computed server-side from stored question metadata.
- **`brain_brawl_quiz_sessions`** flips **`submitted: false → true`** in a **single** update including **`xp_awarded`**. If **`modified_count ≠ 1`**, the handler returns **409** and **does not** increment user XP or insert a duplicate **`brain_brawl_sessions`** row.

## Certificates (`/education/kinesiology/certify`)

- Still requires **`final_passed`**, **`final_verified_receipt`**, coursework, Bio-Digital modules, and verified competitive PRQ per **`_build_kinesiology_eligibility`**.

## Operator checklist

| Concern | Setting |
|---------|---------|
| Bio-Digital minimum dwell | **`FEL_BIO_DIGITAL_MIN_ACTIVE_SECONDS`** (e.g. `60` in prod) |
| Integration tests | Allow default **3s** sleep after **begin** before **complete**, or lower env for CI |
