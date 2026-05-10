#!/usr/bin/env bash
set -euo pipefail

OUT="${SUPERAPP_RELEASE_METADATA_OUT:-artifacts/superapp/final-evolution-lab-ios-release.json}"
APP_NAME="${APP_NAME:-Final Evolution Lab}"
PLATFORM="${PLATFORM:-ios}"
DISTRIBUTION_CHANNEL="${DISTRIBUTION_CHANNEL:-app_store_connect_testflight}"
BUNDLE_ID="${BUNDLE_ID:-com.finalevolutionlab.sovereign}"
APPLE_APP_ID="${APPLE_APP_ID:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
VERSION="${VERSION:-}"
TESTFLIGHT_PUBLIC_LINK="${TESTFLIGHT_PUBLIC_LINK:-}"
APP_STORE_CONNECT_BUILD_URL="${APP_STORE_CONNECT_BUILD_URL:-}"
RELEASE_NOTES="${RELEASE_NOTES:-}"
CREATED_AT="${CREATED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

if [[ -z "$APPLE_APP_ID" || -z "$BUILD_NUMBER" || -z "$VERSION" ]]; then
  echo "ERROR: APPLE_APP_ID, BUILD_NUMBER, and VERSION are required." >&2
  exit 1
fi

case "$DISTRIBUTION_CHANNEL" in
  app_store_connect_testflight|approved_enterprise) ;;
  *)
    echo "ERROR: DISTRIBUTION_CHANNEL must be app_store_connect_testflight or approved_enterprise." >&2
    exit 1
    ;;
esac

case "$TESTFLIGHT_PUBLIC_LINK" in
  ""|https://testflight.apple.com/join/*) ;;
  *)
    echo "ERROR: TESTFLIGHT_PUBLIC_LINK must be a TestFlight public link when provided." >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$OUT")"

export APP_NAME
export PLATFORM
export DISTRIBUTION_CHANNEL
export BUNDLE_ID
export APPLE_APP_ID
export BUILD_NUMBER
export VERSION
export TESTFLIGHT_PUBLIC_LINK
export APP_STORE_CONNECT_BUILD_URL
export RELEASE_NOTES
export CREATED_AT

python3 - "$OUT" <<'PY'
import json
import os
import sys

out = sys.argv[1]
payload = {
    "app_name": os.environ["APP_NAME"],
    "platform": os.environ["PLATFORM"],
    "distribution_channel": os.environ["DISTRIBUTION_CHANNEL"],
    "bundle_id": os.environ["BUNDLE_ID"],
    "apple_app_id": os.environ["APPLE_APP_ID"],
    "build_number": os.environ["BUILD_NUMBER"],
    "version": os.environ["VERSION"],
    "testflight_public_link": os.environ["TESTFLIGHT_PUBLIC_LINK"],
    "app_store_connect_build_url": os.environ["APP_STORE_CONNECT_BUILD_URL"],
    "release_notes": os.environ["RELEASE_NOTES"],
    "created_at": os.environ["CREATED_AT"],
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
    f.write("\n")
PY

echo "Wrote Superapp release metadata: $OUT"
