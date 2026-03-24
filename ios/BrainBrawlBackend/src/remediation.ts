import { DifficultyContext } from "./types";

export class RemediationEngine {
  /**
   * Dynamic remediation:
   * - Lower difficulty when failure rate climbs.
   * - Raise difficulty for high success + fast response.
   * - Always clamp to 1..10.
   */
  nextDifficulty(context: DifficultyContext): number {
    let next = context.currentDifficulty;

    if (context.recentFailureRate >= 0.45) {
      next -= 1;
    } else if (context.recentFailureRate <= 0.15 && context.averageResponseMs < 3500) {
      next += 1;
    }

    if (context.averageResponseMs > 10_000) {
      next -= 1;
    }

    return Math.min(10, Math.max(1, next));
  }
}
