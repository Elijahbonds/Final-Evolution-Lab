#!/usr/bin/env bash
# TestFlight archive helper — NEXUS iOS libs + Release xcodebuild archive.
#
# Usage:
#   ./scripts/archive-ios-testflight.sh              # full archive
#   ./scripts/archive-ios-testflight.sh --dry-run    # preflight + NEXUS libs only
#   ./scripts/archive-ios-testflight.sh --export     # archive + export App Store IPA (Transporter upload)
#   ./scripts/archive-ios-testflight.sh --export-adhoc   # ad-hoc IPA (Firebase / sideload; no ASC app record)
#   ./scripts/archive-ios-testflight.sh --export-only --export-adhoc  # export from existing FEL.xcarchive
#   ./scripts/archive-ios-testflight.sh --preview-firebase  # archive with placeholder plist (V-003 workaround)
#
# Env overrides:
#   ARCHIVE_PATH, DERIVED_DATA, ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 (CI compile only)
#   SKIP_CRASHLYTICS_UPLOAD=1, NEXUS_FIREBASE_DISABLED=1 (explicit Firebase preview archive)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-${ROOT}/build/FEL.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-${ROOT}/build/FEL-export}"
DERIVED_DATA="${DERIVED_DATA:-${ROOT}/build/DerivedData-archive}"
EXPORT_PLIST="${ROOT}/infra/ios/ExportOptions.testflight.plist"
EXPORT_ADHOC_PLIST="${ROOT}/infra/ios/ExportOptions.ad-hoc.plist"
EXPORT_DEV_PLIST="${ROOT}/infra/ios/ExportOptions.development.plist"
SCHEME="FinalEvolutionLab"
TEAM_ID="7KJ6G7HLL4"
BUNDLE_ID="com.finalevolutionlab.app"
PROFILE="FEL_TestFlight_Distribution"
FIREBASE_IPA="${ROOT}/build/FEL-Firebase-Distribution.ipa"
DRY_RUN=0
DO_EXPORT=0
EXPORT_ONLY=0
EXPORT_METHOD="app-store"
PREVIEW_FIREBASE=0

fel_adhoc_udid_count() {
  local ipa="${1:?ipa path}"
  local tmp prov
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  unzip -q "$ipa" -d "$tmp"
  prov="$(find "$tmp"/Payload -name 'embedded.mobileprovision' -print -quit)"
  [[ -n "$prov" ]] || { echo 0; return; }
  security cms -D -i "$prov" 2>/dev/null \
    | plutil -extract ProvisionedDevices json -o - - 2>/dev/null \
    | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null \
    || echo 0
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --export-only) EXPORT_ONLY=1 ;;
    --export) DO_EXPORT=1; EXPORT_METHOD="app-store" ;;
    --export-adhoc) DO_EXPORT=1; EXPORT_METHOD="ad-hoc" ;;
    --export-dev) DO_EXPORT=1; EXPORT_METHOD="development" ;;
    --preview-firebase) PREVIEW_FIREBASE=1 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--export-only] [--export|--export-adhoc|--export-dev] [--preview-firebase]"
      echo ""
      echo "  --export             App Store distribution IPA → build/FEL-export/ (Transporter upload)"
      echo "  --export-adhoc       Ad-hoc IPA for Firebase App Distribution / sideload (no ASC app record)"
      echo "  --export-dev         Development IPA for registered test devices"
      echo "  --export-only        Skip archive; export from existing build/FEL.xcarchive (requires --export*)"
      echo "  --preview-firebase   Allow Release archive with placeholder GoogleService-Info.plist"
      echo "                       (skips Crashlytics upload; Firebase offline at runtime — PREVIEW build)"
      exit 0
      ;;
  esac
done

if [[ "$EXPORT_ONLY" -eq 1 && "$DO_EXPORT" -eq 0 ]]; then
  echo "error: --export-only requires --export, --export-adhoc, or --export-dev"
  exit 1
fi

preflight() {
  echo "==> Preflight"
  command -v cmake >/dev/null || { echo "error: cmake not found"; exit 1; }
  command -v xcodebuild >/dev/null || { echo "error: xcodebuild not found"; exit 1; }

  local avail_gb
  avail_gb="$(df -g / | awk 'NR==2 {print $4}')"
  if [[ "${avail_gb:-0}" -lt 12 ]]; then
    echo "warning: <12 GB free disk — archive/export may fail (≥15 GB recommended)"
  fi

  local plist="${ROOT}/FinalEvolutionLab/GoogleService-Info.plist"
  local example="${ROOT}/FinalEvolutionLab/GoogleService-Info.example.plist"

  if [[ ! -f "$plist" ]]; then
    if [[ "${ALLOW_GOOGLE_SERVICE_PLACEHOLDER:-}" == "1" ]] && [[ -f "$example" ]]; then
      cp "$example" "$plist"
      echo "warning: Copied GoogleService-Info.example.plist → GoogleService-Info.plist (ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1)"
      PREVIEW_FIREBASE=1
    elif [[ "$PREVIEW_FIREBASE" -eq 1 ]] && [[ -f "$example" ]]; then
      cp "$example" "$plist"
      echo "warning: Copied GoogleService-Info.example.plist → GoogleService-Info.plist (--preview-firebase)"
    else
      echo "error: Missing ${plist} — copy from Firebase Console, run ./scripts/fetch-firebase-ios-plist.sh, or use --preview-firebase"
      exit 1
    fi
  fi

  if bash "${ROOT}/scripts/lib/firebase-plist-check.sh" is-placeholder "$plist"; then
    if [[ "$PREVIEW_FIREBASE" -eq 1 ]] || [[ "${ALLOW_GOOGLE_SERVICE_PLACEHOLDER:-}" == "1" ]]; then
      export SKIP_CRASHLYTICS_UPLOAD=1
      echo "warning: PREVIEW Firebase plist on disk — Crashlytics upload skipped; Auth/Firestore offline at runtime"
      echo "         Label: PREVIEW · FIREBASE OFFLINE (see FirebaseBootstrap.isPreviewMode)"
      echo "         Full Firebase: Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt"
    else
      echo "error: GoogleService-Info.plist is placeholder — not valid for production TestFlight"
      echo "       Workaround: $0 --preview-firebase   (internal signed archive / PREVIEW runtime)"
      echo "       Full fix: download real plist (checklist or ./scripts/fetch-firebase-ios-plist.sh)"
      exit 1
    fi
  else
    if ! bash "${ROOT}/scripts/lib/firebase-plist-check.sh" validate-bundle-id "$plist" "$BUNDLE_ID"; then
      echo "error: GoogleService-Info.plist BUNDLE_ID must match Xcode (${BUNDLE_ID})"
      echo "       Re-download from Firebase Console for com.finalevolutionlab.app (not FinalEvoLab)"
      exit 1
    fi
  fi

  echo "    team:        ${TEAM_ID}"
  echo "    bundle:      ${BUNDLE_ID}"
  echo "    profile:     ${PROFILE} (Release manual signing)"
  echo "    archive:     ${ARCHIVE_PATH}"
  if [[ "${SKIP_CRASHLYTICS_UPLOAD:-}" == "1" ]]; then
    echo "    firebase:    PREVIEW (Crashlytics upload skipped)"
  fi
}

cd "$ROOT"
preflight

if [[ "$EXPORT_ONLY" -eq 1 ]]; then
  if [[ ! -d "${ARCHIVE_PATH}" ]]; then
    echo "error: --export-only but archive missing: ${ARCHIVE_PATH}"
    echo "       Run: $0 --preview-firebase   # or full archive without --export-only"
    exit 1
  fi
  echo "==> Export-only (skipping archive rebuild)"
  echo "    archive: ${ARCHIVE_PATH}"
else
  echo "==> Build NEXUS iOS static libraries"
  ./scripts/build-nexus-ios.sh
  if [[ ! -f "${ROOT}/build-ios/libnexus_gameplay.a" ]]; then
    echo "error: build-ios/libnexus_gameplay.a missing"
    exit 1
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "==> Dry-run complete (NEXUS libs + preflight OK)"
    if [[ "${SKIP_CRASHLYTICS_UPLOAD:-}" == "1" ]]; then
      echo "    PREVIEW Firebase path OK — use --preview-firebase for Release archive without real plist"
    fi
    echo "    Next: $0 --preview-firebase   # or with real plist: $0"
    exit 0
  fi

  mkdir -p "$(dirname "$ARCHIVE_PATH")" "$DERIVED_DATA" "${ROOT}/build/ios"

  echo "==> xcodebuild archive (Release, generic iOS)"
  xcodebuild \
    -project "${ROOT}/FinalEvolutionLab.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "${ARCHIVE_PATH}" \
    -derivedDataPath "${DERIVED_DATA}" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    SKIP_CRASHLYTICS_UPLOAD="${SKIP_CRASHLYTICS_UPLOAD:-0}" \
    archive

  echo "==> Archive ready: ${ARCHIVE_PATH}"
  if [[ "${SKIP_CRASHLYTICS_UPLOAD:-}" == "1" ]]; then
    echo "    PREVIEW · FIREBASE OFFLINE — not a production Firebase TestFlight build"
    echo "    Replace plist per Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt before live Auth/Firestore ship"
  fi
fi

if [[ "$DO_EXPORT" -eq 1 ]]; then
  case "$EXPORT_METHOD" in
    app-store)
      export_plist="$EXPORT_PLIST"
      export_label="App Store distribution (TestFlight / Transporter)"
      ;;
    ad-hoc)
      export_plist="$EXPORT_ADHOC_PLIST"
      export_label="Ad-hoc (Firebase App Distribution / sideload)"
      EXPORT_PATH="${EXPORT_PATH}-adhoc"
      ;;
    development)
      export_plist="$EXPORT_DEV_PLIST"
      export_label="Development (registered devices)"
      EXPORT_PATH="${EXPORT_PATH}-dev"
      ;;
    *)
      echo "error: unknown export method ${EXPORT_METHOD}"
      exit 1
      ;;
  esac
  if [[ ! -f "$export_plist" ]]; then
    echo "error: missing ${export_plist}"
    exit 1
  fi
  rm -rf "${EXPORT_PATH}"
  mkdir -p "${EXPORT_PATH}"
  export_log="${ROOT}/build/export-${EXPORT_METHOD}.log"
  echo "==> xcodebuild -exportArchive (${export_label})"
  echo "    plist: ${export_plist}"
  if ! xcodebuild \
    -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${export_plist}" \
    -allowProvisioningUpdates \
    2>&1 | tee "${export_log}"; then
    echo ""
    echo "error: exportArchive failed — full log: ${export_log}"
    if grep -q "missingApp(bundleId:" "${export_log}" 2>/dev/null \
      || grep -q "Error Downloading App Information" "${export_log}" 2>/dev/null; then
      echo ""
      echo "Likely cause: no App Store Connect app record for ${BUNDLE_ID}."
      echo "  Fix: create the app in App Store Connect (see Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt)"
      echo "  Workaround: $0 --export-adhoc   (signed IPA without ASC app record)"
    elif [[ "$EXPORT_METHOD" == "ad-hoc" ]] && grep -qiE 'no profiles|No profiles|Provisioning profile|does not include|not found' "${export_log}" 2>/dev/null; then
      echo ""
      echo "Likely cause: ad-hoc profile missing or tester UDID not registered."
      echo "  Fix: developer.apple.com → Devices → register tester UDIDs"
      echo "       Re-run: $0 --export-only --export-adhoc --preview-firebase"
      echo "  Checklist: Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt § UDID registration"
    fi
    exit 1
  fi
  ipa_path="$(find "${EXPORT_PATH}" -maxdepth 1 -name '*.ipa' -print -quit)"
  echo "==> Export ready: ${EXPORT_PATH}"
  if [[ -n "$ipa_path" ]]; then
    echo "    IPA: ${ipa_path}"
    if [[ "$EXPORT_METHOD" == "ad-hoc" ]]; then
      udid_count="$(fel_adhoc_udid_count "$ipa_path")"
      cp -f "$ipa_path" "${FIREBASE_IPA}"
      echo "    Firebase IPA: ${FIREBASE_IPA} (canonical copy)"
      echo "    Ad-hoc UDIDs in profile: ${udid_count}"
      if [[ "${udid_count:-0}" -eq 0 ]]; then
        echo "warning: no UDIDs in ad-hoc profile — testers cannot install until devices are registered"
        echo "         developer.apple.com → Devices → + → re-export with --export-only --export-adhoc"
      fi
      echo "    Upload: https://console.firebase.google.com/project/final-evolution-lab/appdistribution/app/ios:com.finalevolutionlab.app/releases"
      echo "    Use app: Final Evolution Lab (NOT legacy FEL / FinalEvoLab)"
    fi
  fi
  if [[ "$EXPORT_METHOD" == "app-store" ]]; then
    echo "    Upload: Transporter.app or Xcode Organizer → Distribute App → App Store Connect"
    echo "    Requires ASC app record for ${BUNDLE_ID} (checklist § App Store Connect)"
  fi
else
  echo "    Upload via Xcode Organizer → Distribute App → TestFlight"
  echo "    Or re-run: $0 --export | --export-adhoc | --export-dev"
  echo "    Export-only: $0 --export-only --export-adhoc --preview-firebase"
fi
