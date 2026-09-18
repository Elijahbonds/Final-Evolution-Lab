#!/usr/bin/env python3
"""Validate Swift launch paths that bridge C++ registry ids to iOS game modes."""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
ERRORS: list[str] = []


def text(path: str) -> str:
    return (ROOT / path).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        ERRORS.append(message)


def contains(path: str, needle: str) -> bool:
    return needle in text(path)


def main() -> int:
    game_mode = text("FinalEvolutionLab/Models/GameMode.swift")
    agent_service = text("FinalEvolutionLab/Services/NEXUSAgentService.swift")
    content_view = text("FinalEvolutionLab/ContentView.swift")
    generator_view = text("FinalEvolutionLab/Views/NexusGameGeneratorView.swift")
    studio_panel = text("FinalEvolutionLab/Views/NexusStudio/NexusStudioRunPanelView.swift")
    receipt_coordinator = text("FinalEvolutionLab/Services/GameplaySessionReceiptCoordinator.swift")
    native_bridge = text("FinalEvolutionLab/Services/FELNativeSwiftBridge.swift")

    require(
        'case "basketball_dunk":\n            return mode(for: .basketballDunkContest3D)' in game_mode,
        "GameModeRegistry must resolve C++ basketball_dunk to Swift basketball_dunk_3d",
    )
    require(
        re.search(r"case \.brainBrawl:\s*return \.prod", game_mode) is not None,
        "Brain Brawl must stay production-tier in Swift to match the C++ registry",
    )

    require(
        "GameModeRegistry.playableMode(forRegistryId: modeId)" in agent_service,
        "NEXUSAgentService.launchMode must resolve registry aliases before navigation",
    )
    require(
        "guard let parsed = GameModeId(rawValue: modeId)" not in agent_service,
        "NEXUSAgentService.launchMode must not reject C++ registry aliases",
    )
    require(
        '"registry_mode_id": modeId' in agent_service,
        "Agent launch payload should preserve the requested registry id",
    )

    require(
        content_view.count("GameModeRegistry.playableMode(forRegistryId: modeId)") >= 2,
        "ContentView agent launch listeners must resolve registry aliases",
    )
    require(
        "if mode.id.isIRLDunkContest {\n                        DunkMatchmakingView(viewModel: viewModel)" in content_view,
        "Agent-launched IRL dunk must route to DunkMatchmakingView",
    )

    require(
        "guard let mode = GameModeRegistry.playableMode(forRegistryId: rawModeId)" in generator_view,
        "NexusGameGeneratorView must launch generated C++ registry aliases",
    )
    require(
        "guard let modeId = GameModeId(rawValue: rawModeId)" not in generator_view,
        "NexusGameGeneratorView must not require generated ids to be Swift raw values",
    )

    require(
        studio_panel.count("GameModeRegistry.playableMode(forRegistryId:") >= 4,
        "NexusStudioRunPanelView must resolve generated C++ registry aliases",
    )
    require(
        "let parsed = GameModeId(rawValue: entry.modeId)" not in studio_panel,
        "NexusStudioRunPanelView generated specs must not reject C++ registry aliases",
    )

    require(
        "GameModeRegistry.playableMode(forRegistryId: modeStr)?.id" in receipt_coordinator,
        "GameplaySessionReceiptCoordinator must persist receipts with registry alias ids",
    )

    for mode_id in ("basketball_dunk", "basketball_dunk_3d", "basketball_dunk_irl"):
        require(
            f'"{mode_id}":' in native_bridge,
            f"FELNativeSwiftBridge missing venue token for {mode_id}",
        )

    if ERRORS:
        print("iOS runtime launch validation failed:")
        for error in ERRORS:
            print(f" - {error}")
        return 1

    print("iOS runtime launch validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
