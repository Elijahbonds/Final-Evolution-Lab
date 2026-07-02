#!/usr/bin/env bash
# Physical iPhone validation gate — Phase 10 DoD #9 (compile + manual checklist).
#
# Usage:
#   ./scripts/smoke-ios-device.sh              # full compile gate
#   ./scripts/smoke-ios-device.sh --checklist  # print manual device steps only
#   ./scripts/smoke-ios-device.sh --skip-build # ctest + checklist only
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="FinalEvolutionLab"
SIM_DEST="platform=iOS Simulator,name=iPhone 17 Pro"
DERIVED_DATA="${DERIVED_DATA:-${ROOT}/build/DerivedData-smoke}"
SKIP_BUILD=0
CHECKLIST_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --checklist) CHECKLIST_ONLY=1 ;;
    -h|--help)
      echo "Usage: $0 [--checklist] [--skip-build]"
      exit 0
      ;;
  esac
done

print_checklist() {
  cat <<'EOF'

==> Physical iPhone smoke checklist (manual — DoD #9 partial)

Prerequisites
  [ ] USB iPhone on iOS 16+; trusted + Developer Mode enabled
  [ ] Xcode → Settings → Accounts: Apple ID with team 7KJ6G7HLL4
  [ ] FinalEvolutionLab/GoogleService-Info.plist present (Firebase)
  [ ] Debug run: scheme FinalEvolutionLab, NO -ScreenshotHarness argument

A. Menu navigation (DoD #6)
  1. Launch app → tab shell visible (≤2 taps to Arena)
  2. Arena → Modes → Dunk Contest (P0) and Karate Endless (P1) cards visible
  3. Tap a P2 mode → "Coming Soon" sheet (release config)

B. Dunk Contest touch loop (DoD #3)
  1. Tap Dunk Contest → GamePlayView loads (no crash)
  2. Hold anywhere → release → tap at apex
  3. Center HUD: timing_grade + player_score increment
  4. NEXUS session_state shows active during play

C. Karate Endless combat (DoD #5)
  1. Back → Arena → Karate Endless
  2. Tap Punch / Kick / Block → combo/score updates in HUD
  3. HUD shows wave + HP from mode_state.karate

D. Session end + receipt (DoD #4)
  1. Play one dunk or karate round → tap back / exit gameplay
  2. Xcode → Window → Devices and Simulators → select iPhone
  3. Download container → inspect:
       Library/Application Support/.fel/pending_receipts/*.json
     (or ~/Library/Containers/.../Data/... on simulator)
  4. Relaunch app → foreground upload drains queue (HTTP 2xx when authed)

E. Stability
  1. No crash on session start, HUD poll, or session end
  2. Return to Arena menu; repeat B once

Sign-off
  Tester: ____________   Device: ____________   iOS: ____________
  Date:   ____________   Build: ____________   PASS / FAIL

EOF
}

if [[ "$CHECKLIST_ONLY" -eq 1 ]]; then
  print_checklist
  exit 0
fi

cd "$ROOT"

echo "==> iOS/NEXUS mode registry parity"
python3 scripts/validate_ios_mode_registry.py

echo "==> Headless ctest gate"
./scripts/smoke_gameplay_session.sh --skip-build

if [[ "$SKIP_BUILD" -eq 1 ]]; then
  print_checklist
  echo "==> smoke-ios-device compile gate SKIPPED (--skip-build)"
  exit 0
fi

echo "==> NEXUS iOS static libs"
./scripts/build-nexus-ios.sh
if [[ ! -f "${ROOT}/build-ios/libnexus_gameplay.a" ]]; then
  echo "error: build-ios/libnexus_gameplay.a missing after build-nexus-ios.sh"
  exit 1
fi

echo "==> Simulator compile gate (Debug)"
mkdir -p "$DERIVED_DATA"
AVAIL_GB="$(df -g / | awk 'NR==2 {print $4}')"
if [[ "${AVAIL_GB:-0}" -lt 8 ]]; then
  echo "warning: <8 GB free disk — xcodebuild may fail; free space before archive"
fi

xcodebuild \
  -project "${ROOT}/FinalEvolutionLab.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -derivedDataPath "${DERIVED_DATA}" \
  -destination "${SIM_DEST}" \
  build

echo "==> Simulator compile gate PASS"
print_checklist
echo "==> smoke-ios-device PASS (compile); complete manual checklist on hardware"
