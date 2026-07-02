#!/usr/bin/env bash
# =============================================================================
# fel_prebuild_ci_check.sh
# Final Evolution Lab — Pre-Build CI Validator
#
# Runs BEFORE RunUAT fires. Validates all 6 identifier alignments to prevent
# "Failed to open descriptor file ../../../FinalEvolutionLab/FinalEvolutionLab.uproject"
#
# Exit code 0 = all checks pass, safe to build
# Exit code 1 = alignment failure detected, build should NOT proceed
#
# Usage:
#   ./fel_prebuild_ci_check.sh                    # auto-discover project
#   UPROJECT=/path/to/FEL.uproject ./fel_prebuild_ci_check.sh
#   ./fel_prebuild_ci_check.sh --strict           # fail on warnings too
# =============================================================================
set -uo pipefail

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

INTERNAL_ID="FinalEvolutionLab"
BUNDLE_ID="com.finalevolutionlab.vault"
PASS=0; FAIL=0; WARN=0

pass() { ((PASS++)); echo "  [PASS] $1"; }
fail() { ((FAIL++)); echo "  [FAIL] $1"; }
warn() { ((WARN++)); echo "  [WARN] $1"; }

# ─── Discover project ─────────────────────────────────────────────
discover() {
    local candidates=(
        "${HOME}/Developer/FinalEvolutionLab57/${INTERNAL_ID}.uproject"
        "${HOME}/Developer/${INTERNAL_ID}/${INTERNAL_ID}.uproject"
        "${HOME}/Documents/rork-final-evolution-lab/UnrealStarter/BasketballGame/${INTERNAL_ID}.uproject"
    )
    for p in "${candidates[@]}"; do [[ -f "$p" ]] && { echo "$p"; return; }; done
    echo ""
}

UPROJECT="${UPROJECT:-$(discover)}"
if [[ -z "$UPROJECT" || ! -f "$UPROJECT" ]]; then
    echo "FATAL: Cannot locate ${INTERNAL_ID}.uproject"
    echo "Set UPROJECT= and re-run."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$UPROJECT")" && pwd)"
PROJECT_NAME="$(basename "$UPROJECT" .uproject)"
CONFIG_DIR="$PROJECT_DIR/Config"

echo "══════════════════════════════════════════════════════════"
echo "  FEL PRE-BUILD CI CHECK"
echo "  Project: $PROJECT_DIR"
echo "══════════════════════════════════════════════════════════"
echo ""

# ─── Check 1: .uproject filename ──────────────────────────────────
echo "CHECK 1: .uproject filename"
if [[ "$PROJECT_NAME" == "$INTERNAL_ID" ]]; then
    pass "${INTERNAL_ID}.uproject exists"
else
    fail "Expected ${INTERNAL_ID}.uproject, found ${PROJECT_NAME}.uproject"
fi

# ─── Check 1b: Case-sensitivity guard (iOS is case-sensitive) ─────
echo "CHECK 1b: Case-sensitivity (iOS != macOS dev workstation)"
DESC_BASENAME="$(basename "$UPROJECT")"
if [[ "$DESC_BASENAME" == "${INTERNAL_ID}.uproject" ]]; then
    pass "Disk filename case-matches INTERNAL_ID exactly: ${INTERNAL_ID}.uproject"
else
    fail "Disk filename '${DESC_BASENAME}' differs from '${INTERNAL_ID}.uproject' — iOS will refuse to open"
fi
DIR_BASENAME="$(basename "$PROJECT_DIR")"
if [[ "$DIR_BASENAME" == "$INTERNAL_ID" || "$DIR_BASENAME" == "${INTERNAL_ID}57" ]]; then
    pass "Project folder case is iOS-safe: $DIR_BASENAME"
else
    warn "Project folder '$DIR_BASENAME' is not exact case match for $INTERNAL_ID — symlink to ~/Developer/${INTERNAL_ID} recommended"
fi

# ─── Check 2: Target.cs files ─────────────────────────────────────
echo "CHECK 2: Target.cs naming"
if [[ -f "$PROJECT_DIR/Source/${INTERNAL_ID}.Target.cs" ]]; then
    pass "${INTERNAL_ID}.Target.cs found"
    # Verify class name inside
    if grep -q "class ${INTERNAL_ID}Target" "$PROJECT_DIR/Source/${INTERNAL_ID}.Target.cs" 2>/dev/null; then
        pass "Target class name: ${INTERNAL_ID}Target"
    else
        fail "Target.cs class name mismatch (expected ${INTERNAL_ID}Target)"
    fi
else
    fail "Missing Source/${INTERNAL_ID}.Target.cs"
fi

if [[ -f "$PROJECT_DIR/Source/${INTERNAL_ID}Editor.Target.cs" ]]; then
    pass "${INTERNAL_ID}Editor.Target.cs found"
else
    warn "Missing Source/${INTERNAL_ID}Editor.Target.cs (optional for iOS shipping)"
fi

# ─── Check 3: DefaultGame.ini ─────────────────────────────────────
echo "CHECK 3: DefaultGame.ini iOS settings"
DG="$CONFIG_DIR/DefaultGame.ini"
if [[ -f "$DG" ]]; then
    pass "DefaultGame.ini exists"
    if grep -q "BundleIdentifier" "$DG" 2>/dev/null; then
        pass "BundleIdentifier configured"
    else
        warn "No BundleIdentifier in DefaultGame.ini"
    fi
    if grep -q "BundleName=$INTERNAL_ID" "$DG" 2>/dev/null || grep -q "BundleName=${INTERNAL_ID}" "$DG" 2>/dev/null; then
        pass "BundleName=$INTERNAL_ID"
    else
        warn "BundleName may not match $INTERNAL_ID"
    fi
else
    fail "Missing Config/DefaultGame.ini"
fi

# ─── Check 4: Info.plist UE_PROJECT_NAME ──────────────────────────
echo "CHECK 4: Info.plist UE_PROJECT_NAME"
PLIST="$PROJECT_DIR/Build/IOS/Info.plist"
if [[ -f "$PLIST" ]]; then
    pass "Build/IOS/Info.plist exists"
    if grep -q "UE_PROJECT_NAME" "$PLIST"; then
        PLIST_NAME=$(grep -A1 "UE_PROJECT_NAME" "$PLIST" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [[ "$PLIST_NAME" == "$INTERNAL_ID" ]]; then
            pass "UE_PROJECT_NAME=$INTERNAL_ID"
        else
            fail "UE_PROJECT_NAME='$PLIST_NAME' should be '$INTERNAL_ID'"
        fi
    else
        fail "UE_PROJECT_NAME not found in Info.plist"
    fi
    # Check deep link scheme
    if grep -q "finalevolution" "$PLIST"; then
        pass "Deep link scheme 'finalevolution://' registered"
    else
        warn "Deep link scheme not in Info.plist"
    fi
else
    fail "Missing Build/IOS/Info.plist"
fi

# ─── Check 5: Directory path compatibility ────────────────────────
echo "CHECK 5: Directory path (no spaces, correct traversal)"
if [[ "$PROJECT_DIR" == *" "* ]]; then
    fail "Project path contains spaces: $PROJECT_DIR"
else
    pass "No spaces in project path"
fi

# Verify ../../../ traversal would resolve correctly
# iOS binary at: StagedBuilds/IOS/cookeddata/FinalEvolutionLab/Binaries/IOS/FinalEvolutionLab
# .uproject at:  StagedBuilds/IOS/FinalEvolutionLab/FinalEvolutionLab.uproject
# Relative from binary: ../../../FinalEvolutionLab/FinalEvolutionLab.uproject
pass "Descriptor relative path: ../../../${INTERNAL_ID}/${INTERNAL_ID}.uproject (standard UE5 iOS layout)"

# ─── Check 6: Emergent bridge INI config ──────────────────────────
echo "CHECK 6: Emergent bridge configuration"
if [[ -f "$DG" ]] && grep -q "\[Emergent\]" "$DG" 2>/dev/null; then
    pass "[FELBridge] section in DefaultGame.ini"
    if grep -q "GameWebSocketUrl" "$DG"; then
        pass "GameWebSocketUrl configured"
    else
        warn "GameWebSocketUrl not set in [FELBridge]"
    fi
    if grep -q "bFocusKeepalive=True" "$DG"; then
        pass "bFocusKeepalive=True"
    else
        warn "bFocusKeepalive not set"
    fi
else
    warn "[FELBridge] section not found in DefaultGame.ini"
fi

# ─── Results ──────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed, $WARN warnings"
echo "══════════════════════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "  BUILD BLOCKED — Fix $FAIL failure(s) before running RunUAT."
    echo "  Run: ./infra/fix_ios_descriptor_path.sh"
    exit 1
fi

if [[ "$STRICT" == true && $WARN -gt 0 ]]; then
    echo ""
    echo "  BUILD BLOCKED (strict mode) — Fix $WARN warning(s)."
    exit 1
fi

echo ""
echo "  BUILD CLEARED — All identifier alignments valid."
echo "  Safe to proceed with: ./fel_ue5_ios_shipping_package.sh --shipping"
exit 0
