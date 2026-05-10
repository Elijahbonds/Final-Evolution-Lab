#!/usr/bin/env bash
# Starts Firebase emulators, waits for Firestore, then runs Firestore seed.
# Data Connect (SQL) schema is loaded from ./dataconnect on emulator start; SQL *data* seeds
# are created when you sign in via the app (RegisterSignedInUser) or via Console after deploy.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v firebase >/dev/null 2>&1; then
  echo "ERROR: firebase CLI not found. Install: npm i -g firebase-tools" >&2
  exit 1
fi

echo "Starting emulators (firestore, auth, dataconnect). Run seed in a second terminal:"
echo "  ./scripts/emulator_seed/run_seed.sh"
echo ""
echo "Or use: firebase emulators:exec --only firestore,auth,dataconnect \"./scripts/emulator_seed/run_seed.sh\""
echo ""

firebase emulators:start --only firestore,auth,dataconnect
