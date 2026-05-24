# Final Evolution Lab — iOS Shipping and Superapp Distribution

Goal: ship the Unreal-hosted iOS single app through App Store Connect / TestFlight so Superapp can surface and track the release without hosting an install feed.

## Canonical constraints

- Branch from `setup-healthkit`; do not wholesale merge old Cursor, Unity, or Xcode experiment branches.
- Preserve the Unreal-hosted one-app architecture, WKWebView dashboard overlay, `finalevolution://` deep links, HealthKit usage strings, and descriptor-safe cooked payload packaging.
- Use App Store Connect / TestFlight, or an approved Apple enterprise path if one is formally selected.
- Do not add AltStore, SideStore, OTA manifest feeds, sideload install pages, or direct IPA install URLs.

## Superapp inventory

No Superapp-specific CLI, backend endpoint, CI workflow, manifest schema, or install URL contract is defined in this repo.

Minimal in-repo contract for Superapp release tracking:

```json
{
  "app_name": "Final Evolution Lab",
  "platform": "ios",
  "distribution_channel": "app_store_connect_testflight",
  "bundle_id": "com.finalevolutionlab.sovereign",
  "apple_app_id": "",
  "build_number": "",
  "version": "",
  "testflight_public_link": "",
  "app_store_connect_build_url": "",
  "release_notes": "",
  "created_at": ""
}
```

Generate the metadata file after App Store Connect has accepted the build:

```bash
APPLE_APP_ID="1234567890" \
BUILD_NUMBER="42" \
VERSION="1.0.0" \
TESTFLIGHT_PUBLIC_LINK="https://testflight.apple.com/join/..." \
APP_STORE_CONNECT_BUILD_URL="https://appstoreconnect.apple.com/apps/1234567890/testflight/ios" \
RELEASE_NOTES="iOS HealthKit integration build" \
./scripts/write_superapp_release_metadata.sh
```

Default output: `artifacts/superapp/final-evolution-lab-ios-release.json`.

If Superapp later exposes an API, register exactly this JSON payload there; do not replace it with an IPA URL or install manifest unless the approved Apple distribution path requires it.

## Fresh Mac prerequisites

| Tool | Requirement |
|---|---|
| macOS | Xcode-supported macOS on Apple Silicon |
| Xcode | Installed, selected with `xcode-select`, license accepted |
| Unreal Engine | UE 5.7 with iOS target support |
| Apple Developer | Active team with App Store Connect access |
| Project branch | `setup-healthkit` |

Verify:

```bash
git branch --show-current
xcodebuild -version
export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
export IOS_DEVELOPMENT_TEAM="ABCDE12345"
```

Set `UPROJECT` only if auto-discovery does not find the correct Unreal project.

## Build, stage, archive, and export

Run preflight:

```bash
./fel_ue5_ios_shipping_package.sh --verify-only
```

Build and archive:

```bash
./fel_ue5_ios_shipping_package.sh --full-cook --shipping
```

Build, archive, and export an App Store Connect `.ipa`:

```bash
./fel_ue5_ios_shipping_package.sh --full-cook --shipping --export-ipa
```

The export step uses `infra/ue5_config/ExportOptions.plist` with `method=app-store`.

Expected artifacts:

- `.app` under the resolved iOS archive directory and project `Binaries/IOS`.
- Optional `.ipa` at `Binaries/IOS/FinalEvolutionLab.ipa` when `--export-ipa` succeeds.
- A descriptor-safe cooked payload inside the promoted `.app` via `cookeddata/` or `.pak`.

## Upload to App Store Connect

Preferred options:

- Xcode Organizer: open the generated archive and choose App Store Connect distribution.
- Transporter: upload `Binaries/IOS/FinalEvolutionLab.ipa` after `--export-ipa`.
- `xcrun altool` only if your Apple account flow still supports it.

Do not publish or host the `.ipa` for direct user installation.

## Verification

Before upload:

```bash
grep -RInE 'AltStore|SideStore|sideload|itms-services|manifest\.plist|Over[- ]the[- ]air|OTA' . \
  --exclude-dir=.git --exclude-dir=Saved --exclude-dir=Intermediate --exclude-dir=Binaries --exclude-dir=DerivedDataCache
```

Confirm the shipped bundle:

- `CFBundleIdentifier` matches the App Store Connect app record.
- `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` are present when HealthKit is used.
- `finalevolution://` is registered.
- The `.app` contains `cookeddata/` or `.pak`.
- App Store Connect export compliance, privacy nutrition labels, HealthKit declarations, camera usage, and encryption answers are complete.

On device after TestFlight install:

- Launch the app from TestFlight.
- Open the WKWebView dashboard overlay.
- Trigger a `finalevolution://` path.
- Exercise the HealthKit permission path.
- Confirm no descriptor error, grey-screen-only launch, or missing cooked payload issue.

## Release day checklist

1. Checkout `setup-healthkit` and confirm a clean working tree.
2. Run `./fel_ue5_ios_shipping_package.sh --verify-only`.
3. Run `./fel_ue5_ios_shipping_package.sh --full-cook --shipping --export-ipa`.
4. Upload via Xcode Organizer or Transporter to App Store Connect.
5. Wait for processing, answer export compliance and privacy prompts, then enable TestFlight.
6. Generate `artifacts/superapp/final-evolution-lab-ios-release.json` with `scripts/write_superapp_release_metadata.sh`.
7. Register that JSON with Superapp through the agreed human or API step.
8. Install from TestFlight on a real device and smoke test launch, dashboard, deep links, HealthKit, and cooked-content boot.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Missing `Info.plist` or privacy keys | Merge `UnrealIntegration/Config/DefaultEngine.FEL_iOS_URL_scheme.snippet.ini` into the active Unreal config and rebuild. |
| Descriptor error on device | Use the current `fel_ue5_ios_shipping_package.sh`; it promotes the fully staged cooked `.app` and repacks a descriptor-safe IPA. |
| Code signing failure | Set `IOS_DEVELOPMENT_TEAM` to the 10-character Apple team ID or configure Signing & Capabilities in the generated iOS workspace. |
| No Superapp registration step exists | Hand off `artifacts/superapp/final-evolution-lab-ios-release.json` as the minimal release tracking contract. |
