#!/usr/bin/env python3
"""Validate iOS GameplayView -> NEXUS score-authority wiring.

Linux CI cannot compile the Swift/iOS target, so this script guards the
cross-language receipt contract that previously regressed silently.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BRIDGE_HEADER = REPO_ROOT / "FinalEvolutionLab" / "Bridge" / "NexusGameplayBridge.h"
BRIDGE_IMPL = REPO_ROOT / "FinalEvolutionLab" / "Bridge" / "NexusGameplayBridge.mm"
ENGINE_SWIFT = REPO_ROOT / "FinalEvolutionLab" / "Services" / "NexusGameplayEngine.swift"
GAMEPLAY_VIEW = REPO_ROOT / "FinalEvolutionLab" / "Views" / "GamePlayView.swift"


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def function_body(source: str, name: str) -> str:
    match = re.search(rf"\bfunc\s+{re.escape(name)}\b[^\{{]*\{{", source)
    if not match:
        return ""
    depth = 0
    for index in range(match.end() - 1, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[match.end() : index]
    return ""


def main() -> int:
    errors: list[str] = []
    header = BRIDGE_HEADER.read_text()
    bridge = BRIDGE_IMPL.read_text()
    engine = ENGINE_SWIFT.read_text()
    gameplay = GAMEPLAY_VIEW.read_text()

    require(
        "nexus_gameplay_session_end_arena_with_authority" in header,
        "bridge header must expose explicit score-authority end helper",
        errors,
    )
    require(
        '"use_live_scores", useLiveScores' in bridge,
        "Obj-C++ bridge must pass caller-selected useLiveScores into fel.arena.end_session",
        errors,
    )
    require(
        '"use_live_scores", true' not in bridge,
        "Obj-C++ bridge must not hardcode use_live_scores=true",
        errors,
    )
    require(
        "nexus_gameplay_session_end_arena_with_authority" in engine,
        "Swift bridge wrapper must call the explicit score-authority helper",
        errors,
    )
    require(
        "static func endArena(\n        _ session: NexusGameplayHandle?,\n        playerScore: Float,\n        opponentScore: Float,\n        useLiveScores: Bool = false" in engine,
        "Swift bridge endArena wrapper should default to Swift-visible score authority",
        errors,
    )

    stop_body = function_body(engine, "stop")
    sync_index = stop_body.find("syncScores(player: playerScore, opponent: opponentScore)")
    inactive_index = stop_body.find("sessionActive = false")
    require(sync_index != -1, "NexusGameplayEngine.stop must sync Swift scores when requested", errors)
    require(inactive_index != -1, "NexusGameplayEngine.stop must deactivate the session", errors)
    require(
        sync_index != -1 and inactive_index != -1 and sync_index < inactive_index,
        "NexusGameplayEngine.stop must sync scores before setting sessionActive=false",
        errors,
    )
    require(
        "useLiveScores: Bool = false" in engine,
        "NexusGameplayEngine.stop should default to Swift-visible score authority",
        errors,
    )

    require(
        "useLiveScores: usesNexusScoreAuthority" in gameplay,
        "GamePlayView must end sessions with an explicit score-authority choice",
        errors,
    )
    require(
        "private func routeNexusAction" in gameplay,
        "GamePlayView must route Swift UI actions into NEXUS fel.* helpers",
        errors,
    )
    for required_call in (
        "nexusEngine.sportPulse",
        "nexusEngine.boardAcademyAction",
        "nexusEngine.brainAnswer",
        "nexusEngine.sceneAnswer",
        "nexusEngine.pickupAction",
        "nexusEngine.carnivalTriggerPad",
        "nexusEngine.karateAction",
        "nexusEngine.dunkChargeBegin",
        "nexusEngine.dunkChargeRelease",
        "nexusEngine.dunkApexTap",
    ):
        require(required_call in gameplay, f"GamePlayView missing {required_call} routing", errors)

    print("iOS gameplay authority validation")
    print(f"  bridge_header={BRIDGE_HEADER.relative_to(REPO_ROOT)}")
    print(f"  bridge_impl={BRIDGE_IMPL.relative_to(REPO_ROOT)}")
    print(f"  engine_swift={ENGINE_SWIFT.relative_to(REPO_ROOT)}")
    print(f"  gameplay_view={GAMEPLAY_VIEW.relative_to(REPO_ROOT)}")

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("All iOS gameplay authority assertions passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
