#!/usr/bin/env bash
# Quick sanity check: in-repo Unreal project layout (UNREAL_ONLY.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UE="$ROOT/UnrealStarter/BasketballGame"
ERR=0

fail() { echo "  [FAIL] $1"; ERR=1; }
ok() { echo "  [OK] $1"; }

echo "==> Final Evolution Lab — Unreal project layout ($UE)"

[[ -f "$UE/FinalEvolutionLab.uproject" ]] || fail "Missing FinalEvolutionLab.uproject"
[[ -f "$UE/FinalEvolutionLab.uproject" ]] && ok "FinalEvolutionLab.uproject"

[[ -f "$UE/Source/FinalEvolutionLab/FinalEvolutionLab.Build.cs" ]] || fail "Missing Source/FinalEvolutionLab/FinalEvolutionLab.Build.cs"
[[ -f "$UE/Source/FinalEvolutionLab/FinalEvolutionLab.Build.cs" ]] && ok "FinalEvolutionLab.Build.cs"

[[ -f "$UE/Source/FinalEvolutionLab/FinalEvolutionLab.h" ]] || fail "Missing FinalEvolutionLab.h (module API)"
[[ -f "$UE/Source/FinalEvolutionLab/FinalEvolutionLab.h" ]] && ok "FinalEvolutionLab.h"

[[ -f "$UE/Source/FinalEvolutionLab/FinalEvolutionLab.cpp" ]] || fail "Missing FinalEvolutionLab.cpp (module impl)"
[[ -f "$UE/Source/FinalEvolutionLab/FinalEvolutionLab.cpp" ]] && ok "FinalEvolutionLab.cpp"

[[ -f "$UE/Source/FinalEvolutionLab.Target.cs" ]] || fail "Missing FinalEvolutionLab.Target.cs"
[[ -f "$UE/Source/FinalEvolutionLabEditor.Target.cs" ]] || fail "Missing FinalEvolutionLabEditor.Target.cs"
[[ -f "$UE/Source/FinalEvolutionLab.Target.cs" ]] && ok "FinalEvolutionLab.Target.cs"
[[ -f "$UE/Source/FinalEvolutionLabEditor.Target.cs" ]] && ok "FinalEvolutionLabEditor.Target.cs"

[[ -f "$UE/Source/FinalEvolutionLab/FELBasketballGameMode.cpp" ]] || fail "Missing FELBasketballGameMode.cpp (sources not under Source/FinalEvolutionLab?)"
[[ -f "$UE/Source/FinalEvolutionLab/FELBasketballGameMode.cpp" ]] && ok "Game module sources present"

[[ -f "$UE/Config/DefaultEngine.ini" ]] || fail "Missing Config/DefaultEngine.ini"
[[ -f "$UE/Config/DefaultEngine.ini" ]] && ok "Config/DefaultEngine.ini"

if [[ "$ERR" -ne 0 ]]; then
  echo "==> Layout check FAILED — fix paths above or see UNREAL_ONLY.md"
  exit 1
fi

echo "==> Layout check passed. Next: open FinalEvolutionLab.uproject in UE 5.7, generate IDE project, build FinalEvolutionLabEditor."
