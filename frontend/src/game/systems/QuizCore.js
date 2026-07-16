/**
 * QuizCore — mode-agnostic timed multiple-choice engine (rhythm/UI archetype).
 *
 * Question banks are DATA (see game/data/); the core handles shuffling,
 * per-question countdowns, streak/multiplier scoring, and result tallies.
 * Speed matters: answering faster earns more of the question's points.
 * Deterministic option: pass `rng` for seeded shuffles (replay honesty).
 */
export class QuizCore {
  /**
   * @param {{ questions: Array<{ q: string, options: string[], answer: number, points?: number }>,
   *           questionTimeMs?: number, streakStep?: number, maxMultiplier?: number,
   *           rng?: () => number, now?: () => number }} opts
   */
  constructor({ questions, questionTimeMs = 12000, streakStep = 0.25, maxMultiplier = 3, rng, now } = {}) {
    this._rng = rng ?? Math.random;
    this._now = now ?? (() => (typeof performance !== 'undefined' ? performance.now() : Date.now()));
    this.questionTimeMs = questionTimeMs;
    this.streakStep = streakStep;
    this.maxMultiplier = maxMultiplier;
    this._deck = this._shuffle([...(questions ?? [])]);
    this.index = -1;
    this.current = null;
    this._askedAt = 0;
    this.score = 0;
    this.streak = 0;
    this.stats = { correct: 0, wrong: 0, timeout: 0 };
    this.finished = false;
  }

  _shuffle(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(this._rng() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  get multiplier() {
    return Math.min(this.maxMultiplier, 1 + this.streak * this.streakStep);
  }

  /** Advance to the next question (null when the deck is done). */
  next() {
    this.index += 1;
    if (this.index >= this._deck.length) {
      this.current = null;
      this.finished = true;
      return null;
    }
    this.current = this._deck[this.index];
    this._askedAt = this._now();
    return this.current;
  }

  /** Remaining ms on the current question (0 = expired). */
  remainingMs() {
    if (!this.current) return 0;
    return Math.max(0, this.questionTimeMs - (this._now() - this._askedAt));
  }

  /** Call when the timer hits zero without an answer. */
  timeout() {
    if (!this.current) return { result: 'done' };
    this.stats.timeout += 1;
    this.streak = 0;
    return { result: 'timeout', correctIndex: this.current.answer };
  }

  /**
   * @param {number} optionIndex
   * @returns {{ result: 'correct'|'wrong'|'done', earned?: number, correctIndex?: number }}
   */
  answer(optionIndex) {
    if (!this.current) return { result: 'done' };
    const q = this.current;
    if (optionIndex === q.answer) {
      const speedFactor = 0.5 + 0.5 * (this.remainingMs() / this.questionTimeMs); // 0.5..1
      const earned = Math.round((q.points ?? 100) * this.multiplier * speedFactor);
      this.score += earned;
      this.streak += 1;
      this.stats.correct += 1;
      return { result: 'correct', earned, correctIndex: q.answer };
    }
    this.streak = 0;
    this.stats.wrong += 1;
    return { result: 'wrong', correctIndex: q.answer };
  }
}

export default QuizCore;
