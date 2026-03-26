#!/usr/bin/env bash
# Phase 9 — Upload Mac Gold Master DMG to Supabase `sovereign-assets/mac/<filename>`.
# Object path must match sites/final-evolution-main-site/src/constants/downloads.ts and Netlify redirects.
#
# Prerequisites:
#   export SUPABASE_URL="https://<project>.supabase.co"
#   export SUPABASE_SERVICE_ROLE_KEY="<service_role>"   # local/CI only — never commit
#
# Usage (from repo root):
#   ./scripts/upload_gold_master_mac_dmg.sh
#   ./scripts/upload_gold_master_mac_dmg.sh /path/to/SovereignLab_1.0_Gold.dmg
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_DMG="${ROOT}/UnrealStarter/BasketballGame/Saved/Archive/GoldMaster_Mac_Shipping/SovereignLab_1.0_Gold.dmg"
FILE="${1:-$DEFAULT_DMG}"

export FEL_STORAGE_PREFIX=mac
exec "${ROOT}/scripts/upload_to_supabase_storage.sh" "${FILE}"
