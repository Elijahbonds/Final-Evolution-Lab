// Teardown — run cleanup exactly once, in reverse order, even when a step
// throws.
//
// This exists because of a specific failure mode. The M26/M29 harness tore
// down as a flat sequence:
//
//     scene.dispose();
//     engine.dispose();          // ← never runs if scene.dispose() throws
//
// A single throw anywhere in that list strands everything after it. The most
// expensive resource — the WebGL context — is disposed LAST, so it is the one
// most likely to be stranded. That is exactly the leak that forces a page
// refresh between games.
//
// Reverse order matters too: things are torn down in the opposite order they
// were built, so nothing is ever disposed while something that depends on it
// is still live.

export interface TeardownStep {
  label: string;
  fn: () => void;
}

export class Teardown {
  private steps: TeardownStep[] = [];
  private done = false;
  /** Everything that threw, for reporting. */
  public readonly failures: Array<{ label: string; error: unknown }> = [];

  /** Register cleanup for something you just created. */
  add(label: string, fn: () => void): void {
    if (this.done) {
      // Registering after teardown means the caller created a resource during
      // or after disposal. Rather than silently leak it, clean it up now.
      console.warn(`[FEL-TEARDOWN] "${label}" registered after teardown — disposing immediately`);
      try { fn(); } catch (e) { this.failures.push({ label, error: e }); }
      return;
    }
    this.steps.push({ label, fn });
  }

  get disposed(): boolean { return this.done; }
  get size(): number { return this.steps.length; }

  /**
   * Run every step in reverse. Idempotent — a second call is a no-op, because
   * double-dispose is the other half of this bug (React 18 StrictMode invokes
   * cleanup twice on purpose).
   */
  run(): void {
    if (this.done) return;
    this.done = true;
    for (let i = this.steps.length - 1; i >= 0; i--) {
      const s = this.steps[i];
      try {
        s.fn();
      } catch (e) {
        // Keep going. One broken disposer must never strand the rest — that
        // is the entire reason this class exists.
        this.failures.push({ label: s.label, error: e });
        console.error(`[FEL-TEARDOWN] "${s.label}" threw during dispose:`, e);
      }
    }
    this.steps = [];
    if (this.failures.length) {
      console.warn(`[FEL-TEARDOWN] completed with ${this.failures.length} failed step(s): `
        + this.failures.map((f) => f.label).join(', ')
        + ' — later steps still ran.');
    }
  }
}

/**
 * How many WebGL contexts this page has live.
 *
 * Browsers cap these (Chrome ~16, Safari ~8) and silently kill or refuse
 * beyond the cap — a black canvas with no exception, which is invisible until
 * someone thinks to look. A leak of one per route change reaches the cap in
 * under a minute of normal play, and only a full page reload frees them.
 *
 * Exported on `window.__FEL_ENGINES__` so it can be read from a console, a
 * smoke test, or the agent bridge without instrumenting anything.
 */
export const engineCount = {
  live: 0,
  created: 0,
  peak: 0,
  open(): void {
    this.live++; this.created++;
    if (this.live > this.peak) this.peak = this.live;
    if (this.live > 2) {
      console.warn(`[FEL-ENGINE] ${this.live} WebGL contexts live (created ${this.created}). `
        + 'More than 2 means a previous mode was not disposed. Browsers cap this at '
        + '~8-16 and then fail silently, which presents as "the game will not load '
        + 'until I refresh".');
    }
    this.publish();
  },
  close(): void {
    this.live = Math.max(0, this.live - 1);
    this.publish();
  },
  publish(): void {
    if (typeof window !== 'undefined') {
      (window as unknown as Record<string, unknown>).__FEL_ENGINES__ =
        { live: this.live, created: this.created, peak: this.peak };
    }
  },
};
