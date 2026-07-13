/**
 * Bonds Bounce Blueprint curriculum progress tracker.
 */
export class SkillLabSystem {
  /**
   * Creates the Skill Lab tracker.
   */
  constructor() {
    this.reset();
  }

  /**
   * Records a drill attempt.
   *
   * @param {{ drillId: string, score: number, completedAt?: number|string }} attempt
   * @returns {{ attempts: number, bestScore: number, mastered: boolean }}
   */
  recordAttempt({ drillId, score, completedAt = Date.now() }) {
    if (!drillId) {
      return {
        attempts: 0,
        bestScore: 0,
        mastered: false,
      };
    }

    const safeScore = Number.isFinite(score) ? score : 0;
    const attempts = this.curriculum.get(drillId) || [];

    attempts.push({
      score: safeScore,
      completedAt,
    });

    this.curriculum.set(drillId, attempts);
    return this.getProgress(drillId);
  }

  /**
   * Returns progress for a single drill.
   *
   * @param {string} drillId
   * @returns {{ attempts: number, bestScore: number, mastered: boolean }}
   */
  getProgress(drillId) {
    const attempts = this.curriculum.get(drillId) || [];
    const bestScore = attempts.reduce((best, attempt) => Math.max(best, attempt.score), 0);

    return {
      attempts: attempts.length,
      bestScore,
      mastered: bestScore >= 90 || (attempts.length >= 3 && bestScore >= 80),
    };
  }

  /**
   * Returns curriculum-wide drill status.
   *
   * @returns {Array<{ drillId: string, attempts: number, bestScore: number, mastered: boolean }>}
   */
  getCurriculumStatus() {
    return Array.from(this.curriculum.keys())
      .sort()
      .map((drillId) => ({
        drillId,
        ...this.getProgress(drillId),
      }));
  }

  /**
   * Resets all Skill Lab progress.
   *
   * @returns {void}
   */
  reset() {
    this.curriculum = new Map();
  }
}

// TODO: sync curriculum progress to Abacus backend when online

export default SkillLabSystem;
