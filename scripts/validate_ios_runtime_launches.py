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


def router_dispatches_dedicated_surfaces(content: str) -> bool:
    """The shared router must keep camera/non-game/2D modes out of GamePlayView."""
    irl_guard = content.find("gameMode.id.isIRLDunkContest")
    irl_view = content.find("IRLDunkView(viewModel: viewModel, gameMode: gameMode)", irl_guard)
    market_guard = content.find("gameMode.id == .marketBrowse", irl_view)
    market_view = content.find("MarketBrowseView(viewModel: viewModel)", market_guard)
    brain_guard = content.find("gameMode.id == .brainBrawl", market_view)
    brain_view = content.find("BrainBrawl2DView(", brain_guard)
    gameplay_view = content.find("GamePlayView(", brain_view)
    return (
        irl_guard >= 0
        and irl_view > irl_guard
        and market_guard >= 0
        and market_view > market_guard
        and brain_guard >= 0
        and brain_view > brain_guard
        and gameplay_view > brain_view
    )


def main() -> int:
    failures: list[str] = []

    game_mode = read("FinalEvolutionLab/Models/GameMode.swift")
    content_view = read("FinalEvolutionLab/ContentView.swift")
    agent_service = read("FinalEvolutionLab/Services/NEXUSAgentService.swift")
    arcade_preferences = read("FinalEvolutionLab/Services/ArcadeLibraryPreferences.swift")
    receipt_coordinator = read("FinalEvolutionLab/Services/GameplaySessionReceiptCoordinator.swift")
    game_mode_router = read("FinalEvolutionLab/Views/GameModeRouter.swift")
    dashboard_view = read("FinalEvolutionLab/Views/DashboardView.swift")
    lab_view = read("FinalEvolutionLab/Views/LabView.swift")
    generator_view = read("FinalEvolutionLab/Views/NexusGameGeneratorView.swift")
    selection_view = read("FinalEvolutionLab/Views/GameModeSelectionView.swift")
    arcade_view = read("FinalEvolutionLab/Views/ArcadeLibraryView.swift")
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
        "guard let modeId = playableModeId(forRegistryId: rawId)" in game_mode,
        "mode-manager payload ingest accepts canonical runtime ids",
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
        "GameModeRouter(" in content_view and "sessionReadiness: agentLaunchReadiness" in content_view,
        "app-level agent launches use canonical GameModeRouter",
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
        router_dispatches_dedicated_surfaces(game_mode_router),
        "GameModeRouter dispatches IRL camera, market module, and Brain Brawl 2D before 3D gameplay",
        failures,
    )
    require(
        "GameModeRouter(" in generator_view and "generatorHudTheme: lastGeneratorHudTheme" in generator_view,
        "game generator gameplay route uses canonical GameModeRouter with generated HUD theme",
        failures,
    )
    require(
        "GameModeRouter(" in selection_view,
        "mode selection gameplay route uses canonical GameModeRouter",
        failures,
    )
    require(
        "GameModeRouter(" in arcade_view,
        "arcade library gameplay route uses canonical GameModeRouter",
        failures,
    )
    require(
        "GameModeRouter(" in dashboard_view and "sessionReadiness: sessionReadiness" in dashboard_view,
        "Dashboard quick-launch uses canonical GameModeRouter",
        failures,
    )
    require(
        "GameModeRouter(" in lab_view and "sessionReadiness: sessionReadiness" in lab_view,
        "Lab Global Arena uses canonical GameModeRouter",
        failures,
    )
    require(
        "GameModeRegistry.playableModeId(forRegistryId: modeStr)" in receipt_coordinator,
        "verified receipt ingestion resolves canonical runtime ids",
        failures,
    )
    require(
        "GameModeId(rawValue: modeStr)" not in receipt_coordinator,
        "verified receipt ingestion no longer drops canonical runtime ids",
        failures,
    )
    require(
        "let id = playableModeId(forRegistryId: raw)" in game_mode,
        "last selected Global Arena mode resolves registry aliases",
        failures,
    )
    require(
        "GameModeRegistry.playableModeId(forRegistryId: $0)" in arcade_preferences,
        "arcade recents/favorites decode registry aliases",
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
