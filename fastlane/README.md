# fastlane — Firebase App Distribution

Use this to upload a **signed `.ipa`** to **Firebase App Distribution** so testers get email invites and in-app updates (Firebase SDK optional for in-app; email link flow works without).

This repo’s iOS game binary is built with **Unreal + Xcode**; fastlane does **not** run UE. Produce the IPA first, then run **`bundle exec fastlane distribute`**.

## One-time Firebase setup

1. **Firebase console** — Create / open project → Add **iOS app** with your real **Bundle ID** (must match the signed IPA).
2. **App ID** — **Project settings** (gear) → **Your apps** → copy **App ID** (looks like `1:123…:ios:abc…`). This is **`FIREBASE_APP_ID`**.
3. **Service account** — **Project settings** → **Service accounts** → **Generate new private key** (JSON), or use Google Cloud IAM:
   - Grant **`Firebase App Distribution Admin`** (or a role that includes App Distribution uploads) on that service account.
4. **Tester groups** — **App Distribution** → **Testers & Groups** → create a group (e.g. `internal-testers`). Use the **group alias** in **`FIREBASE_TESTER_GROUPS`** (comma-separated for multiple).
5. **Crashlytics** (optional) — Add the Crashlytics SDK to the same iOS target for stability metrics on those builds; not configured in this monorepo by default.

## Credentials

**Recommended:** Application Default Credentials via file path:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/your-service-account.json
```

The Fastfile passes this to the plugin as **`service_credentials_file`** when set. Do **not** commit the JSON.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FIREBASE_APP_ID` | Yes | From Firebase iOS app settings |
| `IPA_PATH` | Yes | Absolute path to signed `.ipa` |
| `FIREBASE_TESTER_GROUPS` | Yes* | Comma-separated group aliases |
| `FIREBASE_TESTERS` | Yes* | Comma-separated emails (if not using groups) |
| `FIREBASE_RELEASE_NOTES` | No | Defaults to `Automated build` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Yes | Path to service account JSON |

\* At least one of **`FIREBASE_TESTER_GROUPS`** or **`FIREBASE_TESTERS`** must be set.

Copy **`fastlane/.env.example`** → **`fastlane/.env`** and fill values, **or** export in shell. (Root `.gitignore` already ignores `.env` patterns; keep secrets out of Git.)

## Build the IPA (this repo)

On a Mac with UE 5.7 and Xcode:

```bash
cd /path/to/repo
export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
UPROJECT="/path/to/FinalEvolutionLab.uproject" ./fel_ue5_ios_shipping_package.sh --full-cook --export-ipa
```

That uses **`infra/ue5_config/ExportOptions.plist`** (`app-store` method) for a distribution-style IPA when export succeeds. For **ad-hoc / development** IPA rules, adjust export options in Xcode Organizer instead.

Then set **`IPA_PATH`** to the produced file (often under `Binaries/IOS/` or the script’s archive export folder).

## Upload

```bash
cd /path/to/repo
bundle install --path vendor/bundle

export FIREBASE_APP_ID="1:…:ios:…"
export IPA_PATH="/absolute/path/to/FinalEvolutionLab.ipa"
export FIREBASE_TESTER_GROUPS="internal-testers"
export FIREBASE_RELEASE_NOTES="QA build $(date +%Y-%m-%d)"
export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/key.json"

bundle exec fastlane distribute
```

Aliases: **`bundle exec fastlane distribute_firebase`** (same as **`distribute`**).

## CI (GitHub Actions, etc.)

- Store **`GOOGLE_APPLICATION_CREDENTIALS`** JSON as a **secret**; write to a temp file in the job and export the path.
- Store **`FIREBASE_APP_ID`** as a variable.
- Build IPA on a **macOS** runner (UE/Xcode), then run **`bundle exec fastlane distribute`** with the same env vars.

## After upload

- **Firebase console** → **App Distribution** → **Releases** — confirm the build; testers receive email.
- **App Store / TestFlight** remains the path for public App Store review; Firebase App Distribution is for **pre-release / trusted testers** only.
