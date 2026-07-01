#!/usr/bin/env bash
# Pre-flight: plist, Data Connect config, Unreal embed path, codegen, optional firebase deploy dry-run.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# Prevent permission issues on user config directory when running under sandbox/restrictive CI
export XDG_CONFIG_HOME="${ROOT}/.config"
export HOME="${ROOT}/.home"

FAIL=0

warn() { echo "WARN: $*"; }
err() { echo "ERROR: $*" >&2; FAIL=1; }

echo "=== verify_production_readiness.sh ==="

PLIST="${ROOT}/FinalEvolutionLab/GoogleService-Info.plist"
if [[ ! -f "${PLIST}" ]]; then
  err "Missing ${PLIST} — Release builds fail; production Firebase features disabled in Debug without it."
else
  echo "OK: GoogleService-Info.plist present"
fi

UE_FW="${ROOT}/FinalEvolutionLab/EmbeddedFrameworks/UnrealFramework.framework"
if [[ -d "${UE_FW}" ]]; then
  echo "OK: UnrealFramework.framework present at EmbeddedFrameworks"
else
  warn "UnrealFramework.framework not at ${UE_FW} (optional until UE export)"
fi

DC="${ROOT}/dataconnect/dataconnect.yaml"
if [[ ! -f "${DC}" ]]; then
  err "Missing dataconnect/dataconnect.yaml"
else
  if grep -q 'YOUR_CLOUD_SQL_INSTANCE_ID' "${DC}"; then
    err "dataconnect.yaml still has placeholder YOUR_CLOUD_SQL_INSTANCE_ID — cloud deploy blocked."
  else
    echo "OK: dataconnect.yaml instanceId does not look like placeholder"
  fi
fi

if command -v firebase >/dev/null 2>&1; then
  echo "OK: firebase CLI $(firebase --version)"
  echo "Running dataconnect SDK generation…"
  firebase dataconnect:sdk:generate >/dev/null
  echo "OK: firebase dataconnect:sdk:generate"
  if firebase projects:list >/dev/null 2>&1; then
    echo "Running deploy dry-run (rules + dataconnect service)…"
    if firebase deploy --dry-run --only firestore:rules,dataconnect:elijahbonds 2>/dev/null; then
      echo "OK: firebase deploy --dry-run succeeded"
    else
      warn "firebase deploy --dry-run failed (login, project, or APIs). Run: firebase login && firebase use <project>"
    fi
  else
    warn "Not logged in to Firebase CLI — skipping deploy dry-run"
  fi
else
  warn "firebase CLI not installed — skipping codegen/deploy checks"
fi

if [[ "${FAIL}" -ne 0 ]]; then
  echo ""
  echo "Finished with errors — fix items above before live deploy."
  exit 1
fi

echo ""
echo "=== All automated checks passed ==="
echo "Live deploy (after firebase use <project>):"
echo "  firebase deploy --only firestore:rules,dataconnect:elijahbonds"
echo "  ./scripts/deploy-hosting.sh fel-dashboard   # static CRA dashboard → Firebase Hosting"
