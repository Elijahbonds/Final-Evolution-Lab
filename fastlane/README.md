# fastlane — Firebase App Distribution

## Google credentials (required for `distribute_firebase`)

Use a **service account JSON** with permission to use **Firebase App Distribution** (see Firebase console → Project settings → Service accounts).

In the same shell where you run fastlane:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/your-service-account.json
```

Replace `/absolute/path/to/your-service-account.json` with the real path (for example `~/secrets/fel-firebase-adminsdk.json`). Do **not** commit that file; keep it outside the repo or in a secrets manager.

Then set the lane variables and run:

```bash
export FIREBASE_APP_ID="1:123456789:ios:abcdef"
export IPA_PATH="/absolute/path/to/FinalEvolutionLab.ipa"
export FIREBASE_TESTER_GROUPS="internal-qa"
export FIREBASE_RELEASE_NOTES="Build notes"

cd /path/to/rork-final-evolution-lab
bundle exec fastlane distribute_firebase
```

## Bundler

```bash
bundle install --path vendor/bundle
bundle exec fastlane ...
```
