from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True)
class AntiCheatResult:
    flags: list[str]
    auto_forfeit: bool


class AntiCheatEngine:
    TOO_FAST_MS = 350
    TOO_SLOW_MS = 45_000
    MAX_FLAGS_BEFORE_FORFEIT = 4

    def inspect_answer(
        self,
        *,
        response_ms: int,
        has_interaction_proof: bool,
        prior_flags: list[str],
    ) -> AntiCheatResult:
        flags: list[str] = []

        if response_ms < self.TOO_FAST_MS:
            flags.append("response_too_fast")

        if response_ms > self.TOO_SLOW_MS:
            flags.append("response_too_slow")

        if not has_interaction_proof:
            flags.append("missing_interaction_proof")

        total_flags = len(prior_flags) + len(flags)
        return AntiCheatResult(
            flags=flags,
            auto_forfeit=total_flags >= self.MAX_FLAGS_BEFORE_FORFEIT,
        )
