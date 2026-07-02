#!/usr/bin/env bash
# Run after `firebase emulators:start` is accepting connections (Firestore on 8085 by default).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}/scripts/emulator_seed"
if [[ ! -d node_modules ]]; then
  echo "Installing emulator seed dependencies (npm install)…"
  npm install --silent
fi
export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8085}"
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-demo-fel-local}"
node ./seed_firestore.mjs
