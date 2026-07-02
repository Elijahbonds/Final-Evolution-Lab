#!/usr/bin/env bash
# Linux/cloud NEXUS quality gate: registry + descriptor validation + headless gameplay.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ -z "${CC:-}" ]] && command -v gcc >/dev/null 2>&1; then
  export CC=gcc
fi
if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX=g++
fi

run() {
  echo "==> $*"
  "$@"
}

run python3 scripts/validate_mode_registry.py
run python3 scripts/validate_ios_runtime_launches.py
run python3 scripts/validate_ios_descriptor.py
run python3 scripts/smoke_test_modes.py

if [[ "${NEXUS_SKIP_COOKED_PAYLOAD_VALIDATE:-}" != "1" ]]; then
  run python3 scripts/validate_cooked_payload.py
else
  echo "==> skipped cooked payload validation (NEXUS_SKIP_COOKED_PAYLOAD_VALIDATE=1)"
fi

run ./scripts/nexus_gameplay_regression.sh

echo "==> nexus_headless_gate PASS"
