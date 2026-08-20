#!/usr/bin/env bash
# Linux-safe iOS/NEXUS preflight.
#
# This does not replace Xcode, signing, simulator, or device validation. It
# catches the cross-surface drift that Linux agents can prove: Swift bridge
# handoff, Swift-to-C++ production mode alignment, and bundled NEXUS assets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> iOS bridge contract"
python3 "${ROOT}/scripts/validate_ios_bridge_contract.py"

echo "==> iOS/NEXUS registry and asset preflight"
python3 - <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path.cwd()
ERRORS: list[str] = []
WARNINGS: list[str] = []


def err(message: str) -> None:
    ERRORS.append(message)


def warn(message: str) -> None:
    WARNINGS.append(message)


def read_text(relative_path: str) -> str:
    path = ROOT / relative_path
    if not path.exists():
        err(f"missing required file: {relative_path}")
        return ""
    return path.read_text()


def quoted_values(block: str) -> list[str]:
    return re.findall(r'"([^"]+)"', block)


def parse_swift_string_array(source: str, name: str) -> list[str]:
    match = re.search(
        rf"static\s+let\s+{re.escape(name)}\s*:\s*\[String\]\s*=\s*\[(?P<body>.*?)\]",
        source,
        re.DOTALL,
    )
    if not match:
        err(f"could not parse Swift array: {name}")
        return []
    return quoted_values(match.group("body"))


def parse_cpp_string_view_array(source: str, name: str) -> list[str]:
    match = re.search(
        rf"{re.escape(name)}\[\]\s*=\s*\{{(?P<body>.*?)\}};",
        source,
        re.DOTALL,
    )
    if not match:
        err(f"could not parse C++ array: {name}")
        return []
    return quoted_values(match.group("body"))


def parse_validate_script_modes(source: str) -> list[str]:
    match = re.search(r"PRODUCTION_MODES=\(\s*(?P<body>.*?)\)", source, re.DOTALL)
    if not match:
        err("could not parse PRODUCTION_MODES from scripts/nexus_validate_production_modes.sh")
        return []
    modes: list[str] = []
    for raw_line in match.group("body").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        modes.extend(line.split())
    return modes


def require_equal_sets(label: str, actual: list[str], expected: list[str]) -> None:
    actual_set = set(actual)
    expected_set = set(expected)
    missing = sorted(expected_set - actual_set)
    extra = sorted(actual_set - expected_set)
    if missing or extra:
        detail = []
        if missing:
            detail.append(f"missing={missing}")
        if extra:
            detail.append(f"extra={extra}")
        err(f"{label} mismatch: {'; '.join(detail)}")


game_mode_source = read_text("FinalEvolutionLab/Models/GameMode.swift")
router_source = read_text("FinalEvolutionLab/Views/GameModeRouter.swift")
arena_header = read_text("app/gameplay/include/nexus/gameplay/arena_mode_registry.h")
arena_source = read_text("app/gameplay/src/arena_mode_registry.cpp")
validate_modes_source = read_text("scripts/nexus_validate_production_modes.sh")

swift_production_modes = parse_swift_string_array(game_mode_source, "productionModeIds")
cpp_production_modes = parse_cpp_string_view_array(arena_header, "kProductionModeIds")
validate_script_modes = parse_validate_script_modes(validate_modes_source)

runtime_aliases = {
    "basketball_dunk_3d": "basketball_dunk",
    "venice_pickup": "basketball_h2h",
}
ios_only_modes = {
    "basketball_dunk_irl",
}
swift_runtime_modes = [
    runtime_aliases.get(mode_id, mode_id)
    for mode_id in swift_production_modes
    if mode_id not in ios_only_modes
]

require_equal_sets("Swift production runtime modes vs C++ production modes", swift_runtime_modes, cpp_production_modes)
require_equal_sets("validate-only script modes vs C++ production modes", validate_script_modes, cpp_production_modes)
if cpp_production_modes and validate_script_modes and cpp_production_modes != validate_script_modes:
    warn("validate-only script mode order differs from C++ kProductionModeIds order")

if 'case .basketballDunkContest3D: return "basketball_dunk"' not in game_mode_source:
    err("Swift 3D dunk mode must map to C++ basketball_dunk runtime id")
if ".basketballDunkContestIRL" not in router_source or "IRLDunkView" not in router_source:
    err("Swift IRL dunk mode must route to IRLDunkView instead of the C++ runtime")

registry_entries = re.findall(
    r'\{\.id = "([^"]+)".*?\.nexusMeshPath = "([^"]+)".*?\.releaseState = ArenaReleaseState::k([A-Za-z]+)',
    arena_source,
    re.DOTALL,
)
mesh_by_mode = {mode_id: mesh_path for mode_id, mesh_path, release in registry_entries if release == "Production"}
for mode_id in cpp_production_modes:
    mesh_path = mesh_by_mode.get(mode_id)
    if not mesh_path:
        err(f"C++ production mode missing mesh path: {mode_id}")
        continue
    if not (ROOT / mesh_path).exists():
        err(f"C++ production mode mesh file missing: {mode_id} -> {mesh_path}")

manifest_path = ROOT / "assets/nexus/manifests/nexus_asset_manifest.json"
if manifest_path.exists():
    manifest = json.loads(manifest_path.read_text())
    venue_mode_ids = {
        mode_id
        for venue in manifest.get("venues", [])
        for mode_id in venue.get("mode_ids", [])
    }
    missing_manifest_modes = sorted(set(cpp_production_modes) - venue_mode_ids)
    if missing_manifest_modes:
        err(f"asset manifest missing production runtime mode ids: {missing_manifest_modes}")
else:
    err("missing NEXUS asset manifest: assets/nexus/manifests/nexus_asset_manifest.json")

mobile_meshes = list((ROOT / "assets/nexus/imported").glob("*_mobile.nexusmesh.json"))
if not mobile_meshes:
    err("no mobile NEXUS mesh sidecars found under assets/nexus/imported")

prebuilt_archives = list((ROOT / "NexusPrebuilt").glob("**/*.a"))
if not prebuilt_archives:
    warn("NexusPrebuilt static libraries are absent in this checkout; macOS/Xcode must run build-nexus-ios.sh before archive")

real_firebase_plist = ROOT / "FinalEvolutionLab/GoogleService-Info.plist"
example_firebase_plist = ROOT / "FinalEvolutionLab/GoogleService-Info.example.plist"
if not real_firebase_plist.exists():
    warn("production GoogleService-Info.plist is absent; TestFlight release requires the real Firebase plist outside git")
if example_firebase_plist.exists() and "REPLACE_ME" in example_firebase_plist.read_text():
    warn("example Firebase plist still contains placeholders; use only for preview/offline lanes")

print(f"Swift production modes: {len(swift_production_modes)}")
print(f"C++ production runtime modes: {len(cpp_production_modes)}")
print(f"Mobile NEXUS mesh sidecars: {len(mobile_meshes)}")

if WARNINGS:
    print("WARNINGS:")
    for message in WARNINGS:
        print(f"  WARN: {message}")

if ERRORS:
    print("FAILURES:", file=sys.stderr)
    for message in ERRORS:
        print(f"  FAIL: {message}", file=sys.stderr)
    sys.exit(1)

print("PASS: iOS/NEXUS Linux preflight")
PY
