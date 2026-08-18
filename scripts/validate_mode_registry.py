#!/usr/bin/env python3
"""Validate NEXUS mode registry alignment across backend, iOS, UE metadata, and gates."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent

PRODUCTION_REGISTRY_MODES = [
    "basketball_h2h",
    "basketball_dunk",
    "basketball_dunk_3d",
    "basketball_dunk_irl",
    "basketball_3v3",
    "karate_h2h",
    "karate_endless",
    "baseball",
    "football",
    "soccer",
    "golf",
    "tennis",
    "volleyball",
    "surfing",
    "gymnastics",
    "skateboarding",
    "snowboarding",
    "brain_brawl",
    "who_scene_it",
    "court_carnival",
]
RUNTIME_PRODUCTION_MODES = [
    mode
    for mode in PRODUCTION_REGISTRY_MODES
    if mode not in {"basketball_dunk_3d", "basketball_dunk_irl"}
]
SWIFT_PRODUCTION_MODES = [
    mode for mode in PRODUCTION_REGISTRY_MODES if mode != "basketball_dunk"
]
NON_GAME_MODULES = ["market_browse"]
PREVIEW_MODES = ["movement_lab"]

errors: list[str] = []
warnings: list[str] = []
duplicate_keys: dict[Path, list[str]] = {}


def err(message: str) -> None:
    errors.append(message)


def warn(message: str) -> None:
    warnings.append(message)


def strict_object_pairs(path: Path):
    def hook(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        obj: dict[str, Any] = {}
        seen: set[str] = set()
        for key, value in pairs:
            if key in seen:
                duplicate_keys.setdefault(path, []).append(key)
            seen.add(key)
            obj[key] = value
        return obj

    return hook


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(), object_pairs_hook=strict_object_pairs(path))


def parse_fel_play_map(path: Path) -> dict[str, str]:
    play_map: dict[str, str] = {}
    seen: set[str] = set()
    in_section = False
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped == "[FELPlayMap]":
            in_section = True
            continue
        if in_section and stripped.startswith("["):
            break
        if not in_section or not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = key.strip()
        if key in seen:
            err(f"Duplicate FELPlayMap entry: {key}")
        seen.add(key)
        play_map[key] = value.strip()
    return play_map


def parse_shell_array(path: Path, variable_name: str) -> list[str]:
    text = path.read_text()
    match = re.search(rf"{re.escape(variable_name)}=\((.*?)\)", text, re.DOTALL)
    if not match:
        err(f"{path} missing {variable_name} array")
        return []
    body = re.sub(r"#.*", "", match.group(1))
    return re.findall(r"[A-Za-z0-9_]+", body)


def parse_swift_string_array(path: Path, symbol_name: str) -> list[str]:
    text = path.read_text()
    match = re.search(rf"{re.escape(symbol_name)}:\s*\[String\]\s*=\s*\[(.*?)\]", text, re.DOTALL)
    if not match:
        err(f"{path} missing {symbol_name} array")
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def require_equal_set(name: str, actual: list[str] | set[str], expected: list[str] | set[str]) -> None:
    actual_set = set(actual)
    expected_set = set(expected)
    missing = sorted(expected_set - actual_set)
    extra = sorted(actual_set - expected_set)
    if missing or extra:
        err(f"{name} mismatch; missing={missing}, extra={extra}")
    else:
        print(f"  ok: {name} ({len(expected_set)})")


def validate_backend_registry() -> dict[str, Any]:
    path = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
    payload = load_json(path)
    manager = payload.get("mode_manager", {})
    registry = manager.get("mode_registry", {})

    declared_total = manager.get("total_modes")
    declared_production = manager.get("production_modes")
    actual_total = len(registry)
    actual_production = sum(1 for entry in registry.values() if entry.get("status") == "production")
    if declared_total != actual_total:
        err(f"ModeManager total_modes={declared_total}, actual={actual_total}")
    if declared_production != actual_production:
        err(f"ModeManager production_modes={declared_production}, actual={actual_production}")
    if actual_production != len(PRODUCTION_REGISTRY_MODES):
        err(f"Expected {len(PRODUCTION_REGISTRY_MODES)} production modes, found {actual_production}")

    require_equal_set(
        "backend production registry",
        [mode for mode, entry in registry.items() if entry.get("status") == "production"],
        PRODUCTION_REGISTRY_MODES,
    )
    require_equal_set(
        "backend non-game registry",
        [mode for mode, entry in registry.items() if entry.get("status") == "non-game-module"],
        NON_GAME_MODULES,
    )
    require_equal_set(
        "backend preview registry",
        [mode for mode, entry in registry.items() if entry.get("status") == "preview"],
        PREVIEW_MODES,
    )
    return registry


def validate_ue_maps() -> None:
    path = REPO_ROOT / "backend" / "ue_mode_maps.json"
    mode_map = load_json(path).get("mode_to_unreal_map", {})
    required = PRODUCTION_REGISTRY_MODES + NON_GAME_MODULES
    for mode in required:
        if mode not in mode_map:
            err(f"ue_mode_maps missing {mode}")
        elif mode == "basketball_dunk_irl":
            if mode_map[mode] is not None:
                err("basketball_dunk_irl must keep a null UE map")
        elif not mode_map[mode]:
            err(f"ue_mode_maps has empty map for {mode}")
    print(f"  ok: UE mode maps checked ({len(required)})")


def validate_fel_play_map() -> None:
    path = REPO_ROOT / "infra" / "ue5_config" / "DefaultGame.ini"
    play_map = parse_fel_play_map(path)
    required = [mode for mode in PRODUCTION_REGISTRY_MODES + NON_GAME_MODULES if mode != "basketball_dunk_irl"]
    for mode in required:
        value = play_map.get(mode)
        if not value:
            err(f"FELPlayMap missing {mode}")
        elif "/Venues/" not in value:
            err(f"FELPlayMap {mode} does not use /Venues/: {value}")
    print(f"  ok: FELPlayMap checked ({len(required)})")


def validate_venue_registry() -> None:
    path = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Config" / "FEL_VenueRegistry.production.json"
    payload = load_json(path)
    modes = {mode["id"]: mode for mode in payload.get("modes", [])}
    venues = {venue["venueKey"] for venue in payload.get("venues", [])}
    required = [mode for mode in PRODUCTION_REGISTRY_MODES + NON_GAME_MODULES if mode != "basketball_dunk_irl"]
    for mode in required:
        entry = modes.get(mode)
        if not entry:
            err(f"VenueRegistry missing mode {mode}")
            continue
        if entry.get("venueKey") not in venues:
            err(f"VenueRegistry {mode} references unknown venue {entry.get('venueKey')}")
    print(f"  ok: VenueRegistry checked ({len(required)})")


def validate_arena_settings() -> None:
    path = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json"
    modes = load_json(path).get("modes", {})
    required = [mode for mode in PRODUCTION_REGISTRY_MODES + NON_GAME_MODULES if mode != "basketball_dunk_irl"]
    for mode in required:
        arena_mode = "basketball_dunk" if mode == "basketball_dunk_3d" else mode
        config = modes.get(arena_mode)
        if not config:
            err(f"ArenaSettings missing {mode}")
            continue
        if not config.get("unrealOpenLevelPackage") or not config.get("modeDisplayName"):
            err(f"ArenaSettings {mode} missing level package or display name")
    print(f"  ok: ArenaSettings checked ({len(required)})")


def validate_swift_registry() -> None:
    path = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
    production_ids = parse_swift_string_array(path, "productionModeIds")
    require_equal_set("Swift productionModeIds", production_ids, SWIFT_PRODUCTION_MODES)
    text = path.read_text()
    if "case .brainBrawl:\n            return .prod" not in text:
        err("GameModeId.brainBrawl must use NexusCapabilityTier.prod")


def validate_gate_script() -> None:
    path = REPO_ROOT / "scripts" / "nexus_validate_production_modes.sh"
    production_modes = parse_shell_array(path, "PRODUCTION_MODES")
    require_equal_set("runtime production gate modes", production_modes, RUNTIME_PRODUCTION_MODES)


def validate_duplicates() -> None:
    for path, keys in duplicate_keys.items():
        err(f"Duplicate JSON keys in {path.relative_to(REPO_ROOT)}: {sorted(set(keys))}")


def main() -> int:
    print("NEXUS mode registry validation")
    validate_backend_registry()
    validate_ue_maps()
    validate_fel_play_map()
    validate_venue_registry()
    validate_arena_settings()
    validate_swift_registry()
    validate_gate_script()
    validate_duplicates()

    if warnings:
        print("\nWarnings:")
        for message in warnings:
            print(f"  - {message}")
    if errors:
        print("\nErrors:")
        for message in errors:
            print(f"  - {message}")
        return 1
    print("\nPASS: NEXUS mode registry is aligned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
