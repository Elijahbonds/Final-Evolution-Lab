#!/usr/bin/env bash
# Full path: verify iOS engine payload → RunUAT iOS Development → open generated Xcode workspace.
# Requires: Epic Games Launcher iOS platform for UE 5.7, Xcode, Apple Developer signing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/check_fel_ios_engine.sh"

echo ""
echo "==> Starting iOS Development cook + archive (this can take 20–60+ minutes)..."
bash "${SCRIPT_DIR}/package_fel_ios.sh"

echo ""
echo "==> Launching Xcode..."
bash "${SCRIPT_DIR}/open_fel_ios_xcode.sh"
