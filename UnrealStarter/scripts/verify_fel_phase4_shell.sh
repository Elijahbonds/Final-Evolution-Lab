#!/usr/bin/env bash
# Phase 4 — Repo check: Swift shell handoff symbols exist (Settings + preference + onOpenURL).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "verify_fel_phase4_shell: $*" >&2; exit 1; }

must_have() {
	grep -qF "$2" "$1" || fail "missing in $1: $2"
}

IOS="${ROOT}/ios/FinalEvolutionLab"
must_have "${IOS}/Models/FELArenaRuntimePreference.swift" "felArenaRuntimePreference"
must_have "${IOS}/Views/SettingsSheet.swift" "Arena experience"
must_have "${IOS}/Views/GamePlayView.swift" "unrealArenaHandoffBanner"
must_have "${IOS}/FinalEvolutionLabApp.swift" "applyIfHandled"
must_have "${ROOT}/UnrealStarter/RUN_UNREAL_ON_IPHONE_XCODE.md" "FELNativeBridge"

echo "verify_fel_phase4_shell: OK"
