#!/usr/bin/env bash
# Final Evolution — PS5 packaging preflight (run on Mac host before / after PlayStation SDK cook).
# Verifies: (1) Sovereign gear PS5 texture lock 4096 / BC7 path, (2) InputLatencyMonitor ≤16.6 ms policy in source,
# (3) optional Mac mini M4 Pro host hint for console-grade responsiveness simulation (120 Hz desktop target).
#
# Usage: ./scripts/ps5_preflight_check.sh
# Exit 0 = all checks PASS; non-zero = FAIL with details.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

echo "==> FEL PS5 Preflight (Premium Tier parity)"
echo "    ROOT=$ROOT"

CFG="${FEL_DEFAULT_GAME_INI:-$ROOT/UnrealStarter/BasketballGame/CONFIG_DefaultGame_FEL.ini}"
STAMP_PY="${FEL_LUMA_STAMP:-$ROOT/UnrealStarter/BasketballGame/EditorPython/fel_luma_venue_texture_presave.py}"
PC_SRC="$ROOT/UnrealStarter/BasketballGame/FELBasketballPlayerController.cpp"

echo ""
echo "--- [1] Sovereign gear texture lock (4096 PS5 Pro / BC7)"
if [[ -f "$CFG" ]] && grep -qE '^[[:space:]]*FEL_VERIFY_SOVEREIGN_GEAR_TEXTURE_PX_PS5_PRO=4096[[:space:]]*$' "$CFG"; then
	echo "    PASS: CONFIG_DefaultGame_FEL.ini contains FEL_VERIFY_SOVEREIGN_GEAR_TEXTURE_PX_PS5_PRO=4096"
else
	echo ""
	echo "CRITICAL: Texture Parity Violation — FEL_VERIFY_SOVEREIGN_GEAR_TEXTURE_PX_PS5_PRO=4096 missing or incorrect in:"
	echo "         $CFG"
	echo "         Console cook would not meet Sovereign BC7 / PS5 Pro parity. Fix before packaging."
	echo ""
	FAIL=1
fi
if [[ -f "$STAMP_PY" ]] && grep -qiE 'ps5|BC7|GNM' "$STAMP_PY"; then
	echo "    PASS: Luma stamp script references PS5/BC7 path"
else
	echo "    WARN: $STAMP_PY missing PS5/BC7 hints — verify EditorPython cook stamps"
fi

echo ""
echo "--- [2] InputLatencyMonitor — <16.6 ms (one frame @ 60 Hz) policy in engine code"
if [[ -f "$PC_SRC" ]] && grep -q 'kOneFrame60Ms' "$PC_SRC" && grep -q 'InputLatencyMonitor_OnCharacterLaunch' "$PC_SRC"; then
	echo "    PASS: FELBasketballPlayerController implements InputLatencyMonitor with 60 Hz frame budget"
	if grep -q '1000.0 / 60.0' "$PC_SRC" || grep -q '16.6' "$PC_SRC"; then
		echo "    PASS: Threshold aligns with ≤16.67 ms (60 Hz)"
	fi
else
	echo "    FAIL: InputLatencyMonitor source not found or incomplete at $PC_SRC"
	FAIL=1
fi

echo ""
echo "--- [3] Host: Mac mini M4 Pro (optional — simulates high-refresh desktop for responsiveness parity)"
if [[ "$(uname -s)" == "Darwin" ]]; then
	CPU_BRAND="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
	echo "    CPU: $CPU_BRAND"
	if echo "$CPU_BRAND" | grep -qi 'M4'; then
		echo "    PASS: Apple M-series host detected (use with Metal + t.MaxFPS 120 in UFELPlatformManager::ApplyMacOrDesktop)"
	else
		echo "    INFO: Not M4 — still valid; use ProMotion/120 Hz display where available for latency sweeps"
	fi
else
	echo "    SKIP: not macOS (run InputLatencyMonitor checks on PS5 devkit when SDK is available)"
fi

echo ""
echo "--- [4] GNM / AGC shader compiler paths (native PS5 cook)"
SDK_ROOT="${PROSPERO_SDK_ROOT:-${SCE_ORBIS_SDK_DIR:-${SN_PS5_SDK:-}}}"
if [[ -n "$SDK_ROOT" ]] && [[ -d "$SDK_ROOT" ]]; then
	echo "    PASS: PlayStation SDK root resolved: $SDK_ROOT"
	FOUND_ANY=0
	while IFS= read -r p; do
		[[ -z "$p" ]] && continue
		echo "    FOUND: $p"
		FOUND_ANY=1
	done < <(find "$SDK_ROOT" -type f \( -iname '*agc*' -o -iname '*gnm*' \) 2>/dev/null | head -12)
	if [[ "$FOUND_ANY" -eq 0 ]]; then
		echo "    WARN: No *agc* / *gnm* filenames under SDK (layout may differ) — confirm GNM/AGC compiler paths in Sony SDK before cook"
	fi
	for guess in \
		"$SDK_ROOT/host_tools/bin" \
		"$SDK_ROOT/host_tools/bin/prospero" \
		"$SDK_ROOT/Prospero/bin"; do
		if [[ -d "$guess" ]]; then
			echo "    HINT: toolchain bin: $guess"
		fi
	done
else
	echo "    WARN: PROSPERO_SDK_ROOT / SCE_ORBIS_SDK_DIR / SN_PS5_SDK unset — cannot verify GNM/AGC compiler binaries on this host"
	echo "         Set SDK env per PlayStation Partners docs before native PS5 shader cook"
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
	echo "==> PS5 PREFLIGHT: PASS (ready for SDK packaging — no architectural blockers)"
	exit 0
else
	echo "==> PS5 PREFLIGHT: FAIL — fix items above before gold PS5 cook"
	exit 1
fi
