#!/usr/bin/env python3
"""Validate Swift launch routing for canonical NEXUS runtime mode ids.

The Linux Cloud VM cannot build SwiftUI/iOS targets, so this gate statically
checks the routing seams that commonly break generated and agent-launched games.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent


def read(relative_path: str) -> str:
    return (REPO_ROOT / relative_path).read_text()


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        failures.append(message)
        print(f"FAIL: {message}")


def contains_alias_return(content: str, aliases: tuple[str, ...], target: str) -> bool:
    case_pattern = r"case\s+" + r"\s*,\s*".join(re.escape(f'"{alias}"') for alias in aliases) + r"\s*:"
    return_pattern = re.escape(f"return .{target}")
    return re.search(case_pattern + r"\s*" + return_pattern, content, re.MULTILINE) is not None


def main() -> int:
    failures: list[str] = []

    game_mode = read("FinalEvolutionLab/Models/GameMode.swift")
    content_view = read("FinalEvolutionLab/ContentView.swift")
    agent_service = read("FinalEvolutionLab/Services/NEXUSAgentService.swift")
    generator_view = read("FinalEvolutionLab/Views/NexusGameGeneratorView.swift")
    studio_run = read("FinalEvolutionLab/Views/NexusStudio/NexusStudioRunPanelView.swift")

    require(
        "static func playableModeId(forRegistryId raw: String) -> GameModeId?" in game_mode,
        "GameModeRegistry exposes a canonical runtime-id resolver",
        failures,
    )
    require(
        contains_alias_return(
            game_mode,
            ("basketball_dunk", "basketball_dunk_contest", "dunk_competition"),
            "basketballDunkContest3D",
        ),
        "canonical dunk aliases resolve to the 3D dunk route",
        failures,
    )
    require(
        contains_alias_return(game_mode, ("karate_kata",), "karateEndless"),
        "legacy karate_kata resolves to karate endless",
        failures,
    )
    require(
        contains_alias_return(game_mode, ("market_browse", "module_library", "vault_shop"), "marketBrowse"),
        "non-game module aliases resolve to market browse",
        failures,
    )

    require(
        content_view.count("GameModeRegistry.playableMode(forRegistryId: modeId)") >= 2,
        "app-level agent notifications resolve registry ids before presentation",
        failures,
    )
    require(
        "GameModeId(rawValue: modeId)" not in content_view,
        "app-level agent notifications no longer require exact Swift enum raw values",
        failures,
    )
    require(
        "IRLDunkView(viewModel: viewModel, gameMode: mode)" in content_view
        and "MarketBrowseView(viewModel: viewModel)" in content_view,
        "external launches respect IRL camera and non-game market routes",
        failures,
    )

    require(
        "GameModeRegistry.playableMode(forRegistryId: modeId)" in agent_service,
        "agent launch tool accepts canonical registry ids",
        failures,
    )
    require(
        '"requested_mode_id": modeId' in agent_service
        and '"nexus_runtime_mode_id": mode.id.nexusRuntimeModeId' in agent_service,
        "agent launch payload records requested and resolved runtime ids",
        failures,
    )

    require(
        "GameModeRegistry.playableModeId(forRegistryId: rawModeId)" in generator_view,
        "game generator routes canonical generated ids",
        failures,
    )
    require(
        "GameModeId(rawValue: rawModeId)" not in generator_view,
        "game generator no longer drops canonical generated ids before launch",
        failures,
    )
    require(
        "GameModeRegistry.playableModeId(forRegistryId: spec.modeId)" in generator_view,
        "game generator opens Studio Run with resolved Swift route",
        failures,
    )

    require(
        "GameModeRegistry.playableModeId(forRegistryId: spec.modeId)" in studio_run
        and "GameModeRegistry.playableModeId(forRegistryId: entry.modeId)" in studio_run,
        "Studio Run resolves generated spec ids for selection and play",
        failures,
    )
    require(
        "GameModeId(rawValue: spec.modeId)" not in studio_run
        and "GameModeId(rawValue: entry.modeId)" not in studio_run,
        "Studio Run no longer requires generated ids to be exact Swift enum raw values",
        failures,
    )

    if failures:
        print(f"\n{len(failures)} iOS runtime launch validation failure(s)")
        return 1

    print("\nAll iOS runtime launch validations passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
