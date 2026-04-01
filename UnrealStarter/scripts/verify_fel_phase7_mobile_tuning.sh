#!/usr/bin/env bash
# Phase 7 — Mobile/Luma tuning artifacts present (docs, iOS scalability, Luma presave, SceneKit defaults).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md"
LUA="$ROOT/UnrealStarter/BasketballGame/EditorPython/fel_luma_venue_texture_presave.py"
IOS_SCAL="$ROOT/UnrealStarter/BasketballGame/Config/IOS/DefaultScalability.ini"
GSH="$ROOT/ios/FinalEvolutionLab/Views/GameSceneHostView.swift"
PM="$ROOT/UnrealStarter/BasketballGame/Source/FinalEvolutionLab/UFELPlatformManager.cpp"

for f in "$DOC" "$LUA" "$IOS_SCAL" "$GSH" "$PM"; do
  if [[ ! -f "$f" ]]; then
    echo "verify_fel_phase7_mobile_tuning: missing $f" >&2
    exit 1
  fi
done

grep -q "## 13. Phase 7" "$DOC" || { echo "PACKAGE_AND_TEST Phase 7 section missing"; exit 1; }
grep -q "Luma_Venice_Shop" "$LUA" || { echo "Luma presave script path missing"; exit 1; }
grep -q "\[ScalabilitySettings\]" "$IOS_SCAL" || { echo "IOS DefaultScalability.ini missing scalability block"; exit 1; }
grep -q "applySceneKitPerformanceDefaults" "$GSH" || { echo "GameSceneHostView performance helper missing"; exit 1; }
grep -q "multisampling2X" "$GSH" || { echo "GameSceneHostView 2x MSAA missing"; exit 1; }
grep -q "ApplyIOSLiveSessionLuminancePostProcess" "$PM" || { echo "UFELPlatformManager luminance hook missing"; exit 1; }
grep -q "PollIOSDynamicResolution" "$PM" || { echo "UFELPlatformManager iOS DRS missing"; exit 1; }

echo "verify_fel_phase7_mobile_tuning: OK"
