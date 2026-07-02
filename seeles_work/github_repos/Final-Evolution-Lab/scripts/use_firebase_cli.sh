#!/usr/bin/env bash
# Homebrew may install multiple Node versions; firebase-tools must use a Node binary
# whose simdjson dylib matches (avoid dyld: libsimdjson.XX.dylib missing).
# Usage (bash): source scripts/use_firebase_cli.sh
# From zsh: bash -c 'source scripts/use_firebase_cli.sh'   (this file is bash; plain zsh `source` may fail with nounset)
set -euo pipefail

pick_node() {
  if [[ -x "/opt/homebrew/opt/node@22/bin/node" ]]; then
    echo "/opt/homebrew/opt/node@22/bin"
    return
  fi
  if [[ -x "/opt/homebrew/bin/node" ]]; then
    echo "/opt/homebrew/bin"
    return
  fi
  echo ""
}

ND="$(pick_node)"
if [[ -z "${ND}" ]]; then
  echo "ERROR: No usable Homebrew node found." >&2
  exit 1
fi
export PATH="${ND}:${PATH}"

if [[ "${BASH_SOURCE[0]-}" != "${0}" ]]; then
  return 0
fi

exec "$@"
