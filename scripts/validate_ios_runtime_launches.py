#!/usr/bin/env python3
"""Guard iOS launch surfaces against raw mode-id parsing drift."""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_SNIPPETS = {
    "FinalEvolutionLab/ContentView.swift": [
        "GameModeRegistry.playableMode(forRegistryId: modeId)",
    ],
    "FinalEvolutionLab/Services/NEXUSAgentService.swift": [
        "GameModeRegistry.playableMode(forRegistryId: modeId)",
        '"mode_id": mode.id.rawValue',
        '"requested_mode_id": modeId',
    ],
    "FinalEvolutionLab/Views/NexusStudio/NexusStudioRunPanelView.swift": [
        "GameModeRegistry.playableMode(forRegistryId: spec.modeId)",
        "GameModeRegistry.playableMode(forRegistryId: entry.modeId)",
    ],
    "FinalEvolutionLab/Views/NexusGameGeneratorView.swift": [
        "GameModeRegistry.playableMode(forRegistryId: rawModeId)",
        "GameModeRegistry.launchModeId(forRegistryId: spec.modeId)",
    ],
    "FinalEvolutionLab/Services/GameplaySessionReceiptCoordinator.swift": [
        "GameModeRegistry.launchModeId(forRegistryId: modeStr)",
    ],
}

FORBIDDEN_SNIPPETS = {
    "FinalEvolutionLab/ContentView.swift": [
        "GameModeId(rawValue: modeId)",
    ],
    "FinalEvolutionLab/Services/NEXUSAgentService.swift": [
        "GameModeId(rawValue: modeId)",
    ],
    "FinalEvolutionLab/Views/NexusStudio/NexusStudioRunPanelView.swift": [
        "GameModeId(rawValue: spec.modeId)",
        "GameModeId(rawValue: entry.modeId)",
    ],
    "FinalEvolutionLab/Views/NexusGameGeneratorView.swift": [
        "GameModeId(rawValue: rawModeId)",
        "GameModeId(rawValue: spec.modeId)",
    ],
    "FinalEvolutionLab/Services/GameplaySessionReceiptCoordinator.swift": [
        "GameModeId(rawValue: modeStr)",
    ],
}


def main() -> int:
    errors: list[str] = []

    game_mode_source = (REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift").read_text()
    if 'case .basketballDunkContestIRL, .basketballDunkContest3D: return "basketball_dunk"' not in game_mode_source:
        errors.append("GameModeId.nexusRuntimeModeId must map both split dunk ids to basketball_dunk")

    for relative, snippets in REQUIRED_SNIPPETS.items():
        source = (REPO_ROOT / relative).read_text()
        for snippet in snippets:
            if snippet not in source:
                errors.append(f"{relative} missing required resolver usage: {snippet}")

    for relative, snippets in FORBIDDEN_SNIPPETS.items():
        source = (REPO_ROOT / relative).read_text()
        for snippet in snippets:
            if snippet in source:
                errors.append(f"{relative} still uses raw launch parsing: {snippet}")

    if errors:
        print("iOS runtime launch validation FAILED")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("iOS runtime launch validation PASSED")
    print(f"  Checked {len(REQUIRED_SNIPPETS)} launch/receipt surfaces plus GameMode aliases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
