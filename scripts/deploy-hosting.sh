#!/usr/bin/env bash
# Build and deploy static web surfaces to Firebase Hosting (Classic).
# Replaces former Vercel deploys — see artifacts/coord/vercel_migration_handoff.json
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

TARGET="${1:-fel-dashboard}"
DRY_RUN="${DRY_RUN:-0}"

build_dashboard() {
  echo "▸ Building CRA dashboard (frontend/)…"
  (cd frontend && npm install --legacy-peer-deps && npm run build)
}

build_vite_site() {
  local dir="$1"
  if [[ ! -d "${dir}" ]]; then
    echo "SKIP: ${dir} not present — create the site or pick another target."
    return 1
  fi
  echo "▸ Building Vite site (${dir})…"
  (cd "${dir}" && npm install && npm run build)
}

case "${TARGET}" in
  fel-dashboard)
    build_dashboard
    ;;
  fel-marketing)
    build_vite_site "sites/finalevolutiongroup.com"
    ;;
  fel-legacy-site)
    build_vite_site "sites/final-evolution-main-site"
    ;;
  fel-clinical-gate)
    build_vite_site "web/clinical-gate-react"
    ;;
  fel-web-shell)
    if [[ ! -d "web" ]]; then
      echo "SKIP: web/ not present."
      exit 1
    fi
    echo "▸ Static web shell (web/) — no build step."
    ;;
  all)
    build_dashboard || true
    build_vite_site "sites/finalevolutiongroup.com" || true
    build_vite_site "sites/final-evolution-main-site" || true
    build_vite_site "web/clinical-gate-react" || true
    TARGET="fel-dashboard,fel-marketing,fel-legacy-site,fel-clinical-gate,fel-web-shell"
    ;;
  *)
    echo "Usage: $0 [fel-dashboard|fel-marketing|fel-legacy-site|fel-clinical-gate|fel-web-shell|all]"
    exit 1
    ;;
esac

if ! command -v firebase >/dev/null 2>&1; then
  echo "ERROR: firebase CLI not found. Install: npm i -g firebase-tools && firebase login"
  exit 1
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  echo "▸ Dry run: firebase deploy --dry-run --only hosting:${TARGET}"
  firebase deploy --dry-run --only "hosting:${TARGET}"
else
  echo "▸ Deploying hosting:${TARGET}…"
  firebase deploy --only "hosting:${TARGET}"
fi
