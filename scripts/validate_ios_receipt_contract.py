#!/usr/bin/env python3
"""Validate iOS gameplay receipt IDs and score-aware NEXUS teardown."""
from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_MODE_PATH = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
GAMEPLAY_VIEW_PATH = REPO_ROOT / "FinalEvolutionLab" / "Views" / "GamePlayView.swift"
COORDINATOR_PATH = REPO_ROOT / "FinalEvolutionLab" / "Services" / "GameplaySessionReceiptCoordinator.swift"
UPLOAD_SERVICE_PATH = REPO_ROOT / "FinalEvolutionLab" / "Services" / "SessionReceiptUploadService.swift"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def extract_function(source: str, signature: str) -> str | None:
    start = source.find(signature)
    if start == -1:
        return None
    brace = source.find("{", start)
    if brace == -1:
        return None

    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : index]
    return None


def main() -> int:
    game_mode = GAME_MODE_PATH.read_text()
    gameplay_view = GAMEPLAY_VIEW_PATH.read_text()
    coordinator = COORDINATOR_PATH.read_text()
    upload_service = UPLOAD_SERVICE_PATH.read_text()

    if "var nexusReceiptModeId: String" not in game_mode:
        return fail("GameModeId must expose nexusReceiptModeId for backend receipts")
    if 'case "basketball_dunk":' not in game_mode or "return .basketballDunkContest3D" not in game_mode:
        return fail("GameModeId.fromNexusRuntimeModeId must map basketball_dunk back to the 3D dunk app mode")
    if "case .venicePickup: return GameModeId.basketballHeadToHead.rawValue" not in game_mode:
        return fail("venice_pickup must normalize to basketball_h2h for NEXUS/backend receipts")

    if "nexusEngine.stop()" in gameplay_view:
        return fail("GamePlayView must not stop NEXUS sessions with default 0/0 scores")

    on_disappear = re.search(r"\.onDisappear\s*\{(?P<body>.*?)\n\s*\}", gameplay_view, re.DOTALL)
    if not on_disappear:
        return fail("could not locate GamePlayView.onDisappear")
    if "nexusEngine.stop(playerScore: score, opponentScore: opponentScore)" not in on_disappear.group("body"):
        return fail("GamePlayView.onDisappear must pass final scores into nexusEngine.stop")

    finalize_body = extract_function(gameplay_view, "private func finalizeResults()")
    if finalize_body is None:
        return fail("could not locate GamePlayView.finalizeResults")
    if "let receiptModeId = gameMode.id.nexusReceiptModeId" not in finalize_body:
        return fail("finalizeResults must derive receiptModeId from nexusReceiptModeId")
    if "nexusEngine.stop(playerScore: score, opponentScore: opponentScore)" not in finalize_body:
        return fail("finalizeResults must flush the active NEXUS session with final scores before receipt submission")
    if "recordShardLedgerForArenaSession(\n                    gameModeId: receiptModeId" not in finalize_body:
        return fail("shard ledger writes must use canonical receiptModeId")
    if "submitNativeSessionReceipt(" not in finalize_body or "gameModeId: receiptModeId" not in finalize_body:
        return fail("native debug receipts must use canonical receiptModeId")

    if "GameModeId.fromNexusRuntimeModeId(modeStr)" not in coordinator:
        return fail("GameplaySessionReceiptCoordinator must parse canonical NEXUS runtime mode IDs")

    normalized_body = extract_function(upload_service, "static func normalizedReceiptBody")
    if normalized_body is None:
        return fail("could not locate SessionReceiptUploadService.normalizedReceiptBody")
    if "GameModeId.fromNexusRuntimeModeId(modeId)?.nexusReceiptModeId" not in normalized_body:
        return fail("queued receipt normalization must canonicalize aliased mode IDs before POST")
    if "let requestBody = normalizedReceiptBody(from: rawBody)" not in upload_service:
        return fail("uploadReceiptFile must normalize requestBody before POST")
    if "postSessionReceipt(body: requestBody)" not in upload_service:
        return fail("uploadReceiptFile must POST the normalized requestBody")
    if "requestBody: requestBody" not in upload_service:
        return fail("server response ingestion must use the same normalized requestBody")

    print("PASS: iOS gameplay receipt contract uses final scores and canonical NEXUS mode IDs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
