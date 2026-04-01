#!/usr/bin/env bash
# Phase 10 — Full dual-track STATIC sign-off: Phase 2–8 verify scripts + Phase 10 engineering inventory.
# Does not compile Unreal or run xcodebuild test — use verify_fel_phase9_automation.sh for that.
#
# Usage:
#   bash UnrealStarter/scripts/verify_fel_phase10_dual_track_static.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run() {
	echo "==> $1"
	bash "${SCRIPT_DIR}/$2"
}

run "Phase 2 — venue paths" "verify_fel_phase2_venue_paths.sh"
run "Phase 4 — shell handoff" "verify_fel_phase4_shell.sh"
run "Phase 5 — SceneKit scale" "verify_fel_phase5_scenekit.sh"
run "Phase 6 — arena mode ids" "verify_fel_phase6_arena_modes.sh"
run "Phase 7 — mobile tuning" "verify_fel_phase7_mobile_tuning.sh"
run "Phase 8 — product story" "verify_fel_phase8_product_story.sh"
run "Phase 10 — engineering inventory" "verify_fel_phase10_signoff.sh"

echo "==> Phase 10 dual-track static sign-off complete."
