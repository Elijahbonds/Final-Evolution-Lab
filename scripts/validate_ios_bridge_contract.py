#!/usr/bin/env python3
"""Validate the iOS NEXUS bridge mirrors the engine tick ordering."""
from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
BRIDGE_PATH = REPO_ROOT / "FinalEvolutionLab" / "Bridge" / "NexusGameplayBridge.mm"


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

    print("PASS: iOS bridge tick order matches engine contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
