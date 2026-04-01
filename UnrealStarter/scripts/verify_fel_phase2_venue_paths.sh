#!/usr/bin/env bash
# Phase 2 — Static validation: Luma/Venice shop paths, MapsToCook, and JSON agree with C++ venue constants.
# Does not replace opening Unreal Editor (PIE, import Luma mesh, scale shell) — see DOCS/FEL_PHASE2_UNREAL_LUMA_VENICE_LOCK.md
#
# Usage (repo root):
#   bash UnrealStarter/scripts/verify_fel_phase2_venue_paths.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME="$(cd "${SCRIPT_DIR}/../BasketballGame" && pwd)"
fail() { echo "verify_fel_phase2_venue_paths: $*" >&2; exit 1; }

must_contain() {
	local file="$1"
	local needle="$2"
	local label="$3"
grep -qF "${needle}" "${file}" || fail "${label}: missing '${needle}' in ${file}"
}

echo "==> Phase 2 — venue path consistency (repo)"

must_contain "${GAME}/Source/FinalEvolutionLab/FELDigitalTwinVenuePaths.h" \
	'/Game/FEL/Venues/Luma_Venice_Shop.Luma_Venice_Shop' \
	'FELDigitalTwinVenuePaths::LumaVeniceShop'

must_contain "${GAME}/Source/FinalEvolutionLab/FELDigitalTwinVenuePaths.h" \
	'/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach' \
	'FELDigitalTwinVenuePaths::VeniceBeachArena'

must_contain "${GAME}/Config/DefaultGame.ini" \
	'+MapsToCook=(FilePath="/Game/FEL/Venues/VeniceBeach/VeniceBeach")' \
	'MapsToCook VeniceBeach'

must_contain "${GAME}/Config/DefaultGame.ini" \
	'+MapsToCook=(FilePath="/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop")' \
	'MapsToCook Luma_Venice_Shop'

must_contain "${GAME}/Content/FEL/Config/ArenaSettings.json" \
	'"unrealOpenLevelPackage": "/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop.Luma_Venice_Shop"' \
	'ArenaSettings market_browse → Luma shop'

must_contain "${GAME}/Content/FEL/Config/ArenaSettings.json" \
	'"unrealOpenLevelPackage": "/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach"' \
	'ArenaSettings basketball → VeniceBeach'

echo "==> Phase 2 static checks passed (editor import + PIE still required locally)."
