#!/usr/bin/env bash
# scripts/fel_final_preflight_check.sh — Unreal/iOS Release Preflight Checks
#
# Scans and validates that the workspace is fully re-baselined on Unreal Engine 5.7
# and prepared for App Store release, meeting all shipping safety guidelines.
#
# Usage:
#   ./scripts/fel_final_preflight_check.sh
#   ./scripts/fel_final_preflight_check.sh --ue-app-path /path/to/cooked/FinalEvolutionLab.app

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0
fail() {
  echo -e "FAIL: $*" >&2
  failures=$((failures + 1))
}
pass() {
  echo -e "OK:   $*"
}

UE_APP_PATH=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --ue-app-path)
      UE_APP_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

echo "== FEL Unreal Engine 5.7 Final Preflight Check =="
echo "Working directory: $ROOT"
echo

# ─── 1. Scan for Legacy Bundle IDs ──────────────────────────────────────────
echo "Checking for legacy bundle ID occurrences..."
legacy_ids=(
  Final-Evolution-x-Unreal
  com.finalevolutionlab.vault
)
for id in "${legacy_ids[@]}"; do
  matches=$(grep -rni "$id" "$ROOT" \
    --exclude-dir=".git" \
    --exclude-dir=".config" \
    --exclude-dir=".home" \
    --exclude-dir="node_modules" \
    --exclude-dir="DerivedData" \
    --exclude-dir="build" \
    --exclude="fel_final_preflight_check.sh" \
    --exclude="implementation_plan.md" \
    --exclude="walkthrough.md" \
    --exclude="task.md" 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    fail "Found legacy bundle ID '$id' in the following files:\n$matches"
  else
    pass "No occurrences of legacy bundle ID '$id' found"
  fi
done
echo

# ─── 2. Verify Canonical Bundle ID in Configs ──────────────────────────────
echo "Verifying canonical bundle ID 'com.finalevolutionlab.app' is configured..."
config_files=(
  "FinalEvolutionLab.xcodeproj/project.pbxproj"
  "fastlane/Appfile"
  ".github/workflows/fel-prebuild-ci.yml"
  "infra/fel_prebuild_ci_check.sh"
  "scripts/write_release_metadata.sh"
  "infra/SHIPPING.md"
  "scripts/ios_archive.sh"
  "infra/FIREBASE_IOS_SDK.md"
)
for file in "${config_files[@]}"; do
  if [[ -f "$ROOT/$file" ]]; then
    if grep -q "com.finalevolutionlab.app" "$ROOT/$file"; then
      pass "Verified in $file"
    else
      fail "Bundle ID 'com.finalevolutionlab.app' is NOT configured in $file"
    fi
  else
    fail "Configuration file missing: $file"
  fi
done
echo

# ─── 3. Verify Unity Deprecation / Unreal Engine 5.7 Priority ───────────────
echo "Verifying shipping priorities in documentation..."
if [[ -f "$ROOT/SHIPPING_ARCHITECTURE.md" ]]; then
  if grep -q "Unreal Engine 5.7" "$ROOT/SHIPPING_ARCHITECTURE.md" && grep -q "Unity" "$ROOT/SHIPPING_ARCHITECTURE.md"; then
    if grep -q "Unity 6.*reference/prototype" "$ROOT/SHIPPING_ARCHITECTURE.md" || grep -q "Unity.*reference-only" "$ROOT/SHIPPING_ARCHITECTURE.md"; then
      pass "SHIPPING_ARCHITECTURE.md correctly prioritizes Unreal Engine 5.7"
    else
      fail "SHIPPING_ARCHITECTURE.md has ambiguous shipping definitions"
    fi
  else
    fail "SHIPPING_ARCHITECTURE.md does not reference Unreal Engine 5.7 and Unity properly"
  fi
else
  fail "SHIPPING_ARCHITECTURE.md not found"
fi

if [[ -f "$ROOT/infra/SHIPPING.md" ]]; then
  if grep -qi "Unreal" "$ROOT/infra/SHIPPING.md" && grep -q "Unity" "$ROOT/infra/SHIPPING.md"; then
    if grep -q "Unity 6 (Reference/Prototype): reference/prototype track only" "$ROOT/infra/SHIPPING.md" || grep -q "Unity is reference-only" "$ROOT/infra/SHIPPING.md" || grep -q "Unity.*reference/prototype" "$ROOT/infra/SHIPPING.md"; then
      pass "infra/SHIPPING.md correctly prioritizes Unreal Engine 5.7"
    else
      fail "infra/SHIPPING.md has ambiguous shipping definitions"
    fi
  else
    fail "infra/SHIPPING.md does not reference Unreal and Unity properly"
  fi
else
  fail "infra/SHIPPING.md not found"
fi

# Guard against any active production claims for Unity in other markdown files
for f in $(find "$ROOT" -maxdepth 3 -name "*.md" -not -path "*/.git/*" -not -path "*/.home/*" -not -path "*/.config/*"); do
  if grep -ni "Unity.*production.*shipping" "$f" | grep -v "not" | grep -q "."; then
    fail "Active Unity production shipping target claim found in $f"
  fi
done
echo

# ─── 4. Verify Plist Privacy Description Keys ──────────────────────────────
echo "Verifying Info.plist privacy description keys..."
privacy_keys=(
  NSCameraUsageDescription
  NSMotionUsageDescription
  NSHealthShareUsageDescription
  NSHealthUpdateUsageDescription
  NSPhotoLibraryUsageDescription
)
for key in "${privacy_keys[@]}"; do
  if grep -q "$key" "$ROOT/FinalEvolutionLab.xcodeproj/project.pbxproj" || \
     ( [[ -f "$ROOT/UnrealIntegration/Config/DefaultEngine.FEL_iOS_URL_scheme.snippet.ini" ]] && grep -q "$key" "$ROOT/UnrealIntegration/Config/DefaultEngine.FEL_iOS_URL_scheme.snippet.ini" ); then
    pass "Privacy key '$key' is defined"
  else
    fail "Privacy key '$key' is missing from project settings or snippets"
  fi
done
echo

# ─── 5. Verify Deep Links Scheme ───────────────────────────────────────────
echo "Verifying URL scheme registration..."
if [[ -f "$ROOT/UnrealIntegration/Config/DefaultEngine.FEL_iOS_URL_scheme.snippet.ini" ]]; then
  if grep -q "finalevolution" "$ROOT/UnrealIntegration/Config/DefaultEngine.FEL_iOS_URL_scheme.snippet.ini"; then
    pass "Deep link scheme 'finalevolution://' snippet registered"
  else
    fail "Deep link scheme 'finalevolution://' not found in config snippet"
  fi
else
  fail "Missing snippet: UnrealIntegration/Config/DefaultEngine.FEL_iOS_URL_scheme.snippet.ini"
fi
echo

# ─── 6. Verify Unreal Cooked Payload Structure (Optional) ──────────────────
if [[ -n "$UE_APP_PATH" ]]; then
  echo "Checking UE cooked payload structure..."
  if [[ ! -d "$UE_APP_PATH" ]]; then
    fail "UE .app path '$UE_APP_PATH' does not exist or is not a directory."
  else
    # Check for cookeddata/ or .pak files
    if find "$UE_APP_PATH" -type d -name "cookeddata" | grep -q "." || find "$UE_APP_PATH" -type f -name "*.pak" | grep -q "."; then
      pass "UE .app cooked payload structure verified (cookeddata/ or .pak found)"
    else
      fail "UE .app cooked payload structure invalid: neither 'cookeddata/' directory nor '.pak' files found under $UE_APP_PATH"
    fi
  fi
  echo
fi

if [[ "$failures" -gt 0 ]]; then
  echo "== Preflight check: FAILED ($failures issue(s)) ==" >&2
  exit 1
fi

echo "== Preflight check: PASS =="
exit 0
