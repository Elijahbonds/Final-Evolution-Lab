# Distribution + Superapp

## Approved consumer path

1. **Build** — UE **Shipping** cook/stage/archive on macOS; verify cooked payload in `.app`.
2. **Sign / export** — Xcode Organizer **Distribute App** → **App Store Connect**, or CLI **`--export-ipa`** with **`infra/ue5_config/ExportOptions.plist`**.
3. **Upload** — Transporter or Organizer upload; wait for **processing** in App Store Connect.
4. **TestFlight** — internal/external groups; share **ASC links** (not third-party install pages).

## What “Superapp” should store (suggested contract)

Fill these in your Superapp database or release ticket tool:

| Field | Example |
|-------|---------|
| `git_branch` | `setup-healthkit` |
| `git_sha` | output of `git rev-parse HEAD` at build time |
| `bundle_id` | e.g. `com.finalevolutionlab.finaldev` (must match ASC) |
| `marketing_version` / `build_number` | from `Info.plist` / ASC |
| `asc_app_id` | App Store Connect app identifier |
| `testflight_url` | ASC → TestFlight public/internal link |
| `ipa_checksum_sha256` | optional integrity record for internal mirrors |
| `release_notes` | text |

## Explicitly out of scope for App Store–aligned releases

- Alternate store **source JSON**, **OTA manifest** pages, **itms-services** links, or **enterprise-only** distribution language in consumer-facing copy.

## Automation stub

CI should **not** guess secrets. Minimum: pass **`APPLE_TEAM_ID`**, **`ASC_API_KEY`** / App Store Connect API key ID + issuer (if using API upload), and **`UPROJECT`** path on the builder.
