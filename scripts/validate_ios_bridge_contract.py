#!/usr/bin/env python3
"""Validate the iOS NEXUS bridge mirrors the engine tick ordering."""
from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
BRIDGE_PATH = REPO_ROOT / "FinalEvolutionLab" / "Bridge" / "NexusGameplayBridge.mm"
GAMEPLAY_VIEW_PATH = REPO_ROOT / "FinalEvolutionLab" / "Views" / "GamePlayView.swift"
ENGINE_PATH = REPO_ROOT / "FinalEvolutionLab" / "Services" / "NexusGameplayEngine.swift"


def require_contains(source: str, needle: str, label: str) -> bool:
    if needle in source:
        return True
    print(f"FAIL: missing {label}: {needle}", file=sys.stderr)
    return False


def main() -> int:
    source = BRIDGE_PATH.read_text()
    match = re.search(
        r"void\s+nexus_gameplay_session_tick\s*\([^)]*\)\s*\{(?P<body>.*?)\n\}",
        source,
        re.DOTALL,
    )
    if not match:
        print(f"FAIL: could not find nexus_gameplay_session_tick in {BRIDGE_PATH}", file=sys.stderr)
        return 1

    body = match.group("body")
    physics_step = body.find("session->physicsWorld.step(deltaSeconds);")
    gameplay_update = body.find("session->application.update(deltaSeconds, session->physicsWorld, {});")
    if physics_step == -1 or gameplay_update == -1:
        print("FAIL: bridge tick must call physicsWorld.step and application.update", file=sys.stderr)
        return 1
    if physics_step > gameplay_update:
        print(
            "FAIL: bridge tick must step physics before gameplay update "
            "to match engine/core/src/engine.cpp",
            file=sys.stderr,
        )
        return 1

    view_source = GAMEPLAY_VIEW_PATH.read_text()
    engine_source = ENGINE_PATH.read_text()
    checks = [
        require_contains(
            view_source,
            "private var usesNexusScoreAuthority",
            "Swift score-authority gate",
        ),
        require_contains(
            view_source,
            ".onChange(of: nexusEngine.hud)",
            "HUD-to-Swift score authority binding",
        ),
        require_contains(
            view_source,
            "nexusEngine.syncScores(player: score, opponent: opponentScore)",
            "Swift-to-NEXUS score sync",
        ),
        require_contains(
            view_source,
            "nexusEngine.stop(playerScore: score, opponentScore: opponentScore, skipScoreSync: skipScoreSync)",
            "session end with real scores",
        ),
        require_contains(
            view_source,
            "routeNexusAction(action: action, success: success",
            "gameplay action routing to NEXUS",
        ),
        require_contains(
            view_source,
            "nexusEngine.dunkChargeBegin()",
            "dunk charge begin bridge command",
        ),
        require_contains(
            view_source,
            "nexusEngine.dunkChargeRelease(power:",
            "dunk charge release bridge command",
        ),
        require_contains(
            view_source,
            "nexusEngine.dunkApexTap()",
            "dunk apex tap bridge command",
        ),
        require_contains(
            engine_source,
            "\"command\": \"fel.bridge.broadcast_map_loaded\"",
            "map-loaded bridge broadcast",
        ),
        require_contains(
            engine_source,
            "nexus_gameplay_session_final_scores_json(session)",
            "final scores bridge wrapper",
        ),
    ]
    if not all(checks):
        return 1

    stop_match = re.search(
        r"func\s+stop\s*\([^)]*\)\s*\{(?P<body>.*?)\n    \}",
        engine_source,
        re.DOTALL,
    )
    if not stop_match:
        print(f"FAIL: could not find stop() in {ENGINE_PATH}", file=sys.stderr)
        return 1
    stop_body = stop_match.group("body")
    score_sync = stop_body.find("syncScores(player: playerScore, opponent: opponentScore)")
    session_inactive = stop_body.find("sessionActive = false")
    if score_sync == -1:
        print("FAIL: stop() must sync final Swift scores before end_arena", file=sys.stderr)
        return 1
    if session_inactive != -1 and session_inactive < score_sync:
        print("FAIL: stop() marks session inactive before final score sync", file=sys.stderr)
        return 1

    flush_match = re.search(
        r"char\*\s+nexus_gameplay_session_flush_receipts\s*\([^)]*\)\s*\{(?P<body>.*?)\n\}",
        source,
        re.DOTALL,
    )
    if not flush_match:
        print(f"FAIL: could not find nexus_gameplay_session_flush_receipts in {BRIDGE_PATH}", file=sys.stderr)
        return 1
    flush_body = flush_match.group("body")
    flush_checks = [
        require_contains(flush_body, '{"persist_to_disk", true}', "iOS receipt disk persistence"),
        require_contains(flush_body, '{"http_enabled", false}', "iOS C++ receipt HTTP disabled"),
        require_contains(flush_body, '{"use_stub_http", false}', "iOS C++ receipt stub transport disabled"),
    ]
    if not all(flush_checks):
        return 1

    print("PASS: iOS bridge tick, receipt flush, and Swift gameplay handoff match engine contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
