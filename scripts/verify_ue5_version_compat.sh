#!/bin/bash
# verify_ue5_version_compat.sh - Check UE5 Target.cs files for version compatibility
# Ensures all Target.cs files use UE 5.4 compatible settings

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

echo "=== UE 5.4 Version Compatibility Check ==="
echo "Project: $PROJECT_ROOT"
echo ""

# Check for incompatible version references
echo "Checking for incompatible BuildSettingsVersion..."
if grep -rn "BuildSettingsVersion\.V[6-9]" "$PROJECT_ROOT" --include="*.cs" 2>/dev/null; then
    echo "  ❌ FAIL: Found BuildSettingsVersion higher than V5 (incompatible with UE 5.4)"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✅ PASS: No incompatible BuildSettingsVersion found"
fi

echo ""
echo "Checking for incompatible EngineIncludeOrderVersion..."
if grep -rn "EngineIncludeOrderVersion\.Unreal5_[5-9]" "$PROJECT_ROOT" --include="*.cs" 2>/dev/null; then
    echo "  ❌ FAIL: Found EngineIncludeOrderVersion higher than Unreal5_4 (incompatible with UE 5.4)"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✅ PASS: No incompatible EngineIncludeOrderVersion found"
fi

echo ""
echo "Verifying Target.cs files exist and use correct settings..."
for TARGET_FILE in $(find "$PROJECT_ROOT" -name "*.Target.cs" -type f); do
    REL_PATH="${TARGET_FILE#$PROJECT_ROOT/}"
    echo "  Checking: $REL_PATH"
    
    if grep -q "BuildSettingsVersion\.V5" "$TARGET_FILE"; then
        echo "    ✅ BuildSettingsVersion.V5"
    elif grep -q "BuildSettingsVersion\." "$TARGET_FILE"; then
        echo "    ❌ Wrong BuildSettingsVersion"
        ERRORS=$((ERRORS + 1))
    else
        echo "    ⚠️  No BuildSettingsVersion found"
    fi
    
    if grep -q "EngineIncludeOrderVersion\.Unreal5_4" "$TARGET_FILE"; then
        echo "    ✅ EngineIncludeOrderVersion.Unreal5_4"
    elif grep -q "EngineIncludeOrderVersion\." "$TARGET_FILE"; then
        echo "    ❌ Wrong EngineIncludeOrderVersion"
        ERRORS=$((ERRORS + 1))
    else
        echo "    ⚠️  No EngineIncludeOrderVersion found"
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "=== ✅ ALL CHECKS PASSED - Project is UE 5.4 compatible ==="
else
    echo "=== ❌ $ERRORS ERROR(S) FOUND - Fix version settings for UE 5.4 ==="
    exit 1
fi
