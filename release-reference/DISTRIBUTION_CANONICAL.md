# Distribution Architecture

## Approved consumer path

1. **Build** — UE **Shipping** cook/stage/archive on macOS; verify cooked payload in `.app`.
2. **Sign / export** — Xcode Organizer **Distribute App** → **App Store Connect**, or CLI **`--export-ipa`** with **`infra/ue5_config/ExportOptions.plist`**.
3. **Upload** — Transporter or Organizer upload; wait for **processing** in App Store Connect.
4. **TestFlight** — internal/external groups; share **ASC links** (not third-party install pages).

## Firebase App Distribution (pre-release / trusted testers)

Complements TestFlight: upload a **signed `.ipa`** to [Firebase App Distribution](https://firebase.google.com/docs/app-distribution) for email-based tester access and optional **Crashlytics** stability on those builds.

- **Fastlane:** `bundle exec fastlane distribute` — see **`fastlane/README.md`** and **`fastlane/.env.example`**.
- **Requires:** `FIREBASE_APP_ID`, `IPA_PATH`, `GOOGLE_APPLICATION_CREDENTIALS` (service account JSON), and **`FIREBASE_TESTER_GROUPS`** and/or **`FIREBASE_TESTERS`**.
- **IPA** must be built on macOS (UE + Xcode) first; this monorepo does not build iOS on Linux CI without a remote Mac runner.

## Release Metadata tracking

Release metadata is tracked in a standardized JSON payload rather than proprietary store/installer feeds:

| Field | Example |
|-------|---------|
| `git_branch` | `setup-healthkit` |
| `git_sha` | output of `git rev-parse HEAD` at build time |
| `bundle_id` | e.g. `com.finalevolutionlab.app` (must match ASC) |
| `marketing_version` / `build_number` | from `Info.plist` / ASC |
| `asc_app_id` | App Store Connect app identifier |
| `testflight_url` | ASC → TestFlight public/internal link |
| `ipa_checksum_sha256` | optional integrity record for internal verification |
| `release_notes` | text |

## Official Website & Link Guidelines

For consumer distribution, the official landing page at **`finalevolutiongroup.com`** is the canonical directory:
- **iOS links**: Must link to the official App Store product page or active TestFlight signup URL. Direct iOS `.ipa` hosting or sideloading links (AltStore, SideStore, custom OTA plist links) are disallowed.
- **Android links (Planned)**: Will link to the official Google Play listing. Optional direct `.apk` downloads may be provided if sideloading is explicitly supported.

## Explicitly out of scope for App Store–aligned releases

- Alternate store **source JSON**, **OTA manifest** pages, **itms-services** links, or **enterprise-only** distribution language in consumer-facing copy.

## Automation stub

CI should **not** guess secrets. Minimum: pass **`APPLE_TEAM_ID`**, **`ASC_API_KEY`** / App Store Connect API key ID + issuer (if using API upload), and **`UPROJECT`** path on the builder.
