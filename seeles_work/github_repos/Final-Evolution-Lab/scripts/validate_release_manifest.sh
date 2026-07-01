#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "ERROR: $*" 1>&2
  exit 1
}

echo "== Final Evolution Lab: Release manifest validation =="

# 1) Firebase plist (must exist for Release builds)
PLIST_PATH="${ROOT_DIR}/FinalEvolutionLab/GoogleService-Info.plist"
if [[ ! -f "${PLIST_PATH}" ]]; then
  echo "WARN: Missing GoogleService-Info.plist at ${PLIST_PATH}"
  echo "      Release builds will fail due to Xcode build gate."
else
  echo "OK: GoogleService-Info.plist present"
fi

# 2) Data Connect config must not contain placeholder instance ID
DC_YAML="${ROOT_DIR}/dataconnect/dataconnect.yaml"
if [[ ! -f "${DC_YAML}" ]]; then
  fail "Missing ${DC_YAML}"
fi

if /usr/bin/grep -q "YOUR_CLOUD_SQL_INSTANCE_ID" "${DC_YAML}"; then
  echo "WARN: dataconnect.yaml still contains placeholder instanceId."
  echo "      Set it from Firebase Console → Data Connect → Cloud SQL instance ID."
else
  echo "OK: dataconnect.yaml instanceId looks set"
fi

# 3) Regenerate SDK (ensures schema + operations compile)
if command -v firebase >/dev/null 2>&1; then
  echo "OK: Firebase CLI found: $(firebase --version)"
  echo "Running: firebase dataconnect:sdk:generate"
  (cd "${ROOT_DIR}" && firebase dataconnect:sdk:generate >/dev/null)
  echo "OK: Data Connect SDK generation succeeded"
else
  echo "WARN: Firebase CLI not found; skipping SDK generation validation."
fi

echo
echo "Next deploy commands:"
echo "  - Firestore rules: firebase deploy --only firestore:rules"
echo "  - Data Connect (service): firebase deploy --only dataconnect:elijahbonds"
echo "  - Data Connect (schema only): firebase deploy --only dataconnect:elijahbonds:schema"
echo
echo "== Validation complete =="

