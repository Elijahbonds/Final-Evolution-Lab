"""Phase 1 anti-cheat sanity checks."""
from __future__ import annotations

from dataclasses import dataclass

from app.schemas.session_receipt import SessionReceiptIn


@dataclass(frozen=True)
class AntiCheatResult:
    """Validation result."""

    accepted: bool
    reason: str = "accepted"


class AntiCheatValidator:
    """Conservative receipt validator.

    Phase 1 intentionally avoids invasive heuristics. It only blocks impossible
    values that should never leave the client bridge.
    """

    def validate(self, receipt: SessionReceiptIn) -> AntiCheatResult:
        """Validate a receipt before economy calculation."""

        if receipt.score < 0:
            return AntiCheatResult(False, "negative_score")
        if receipt.duration_seconds < 0:
            return AntiCheatResult(False, "negative_duration")
        if receipt.score > 10_000:
            return AntiCheatResult(False, "score_out_of_bounds")
        if receipt.duration_seconds == 0 and receipt.completed and receipt.score > 0:
            return AntiCheatResult(False, "instant_scoring_session")
        return AntiCheatResult(True)


anti_cheat_validator = AntiCheatValidator()

