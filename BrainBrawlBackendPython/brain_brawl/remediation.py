from __future__ import annotations

from .types import DifficultyContext


class RemediationEngine:
    def next_difficulty(self, context: DifficultyContext) -> int:
        """
        Dynamic remediation:
        - Decrease difficulty if failures are high.
        - Increase difficulty when performance is strong and fast.
        - Clamp difficulty to 1..10.
        """
        next_value = context.current_difficulty

        if context.recent_failure_rate >= 0.45:
            next_value -= 1
        elif context.recent_failure_rate <= 0.15 and context.average_response_ms < 3500:
            next_value += 1

        if context.average_response_ms > 10_000:
            next_value -= 1

        return min(10, max(1, next_value))
