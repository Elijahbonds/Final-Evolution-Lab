// captions — every gameplay-relevant sound gets a visual equivalent.
//
// WHY THIS IS NOT OPTIONAL
// Dance and Music are unplayable without hearing. Karate's parry cue, the
// baseball pitch tell, the shot-clock buzzer, the crowd swell before a dunk
// score — all of them carry information a player is expected to act on, and
// all of them are audio-only today. A deaf player is not playing a harder
// version of FEL; they are playing a different, worse game.
//
// THE DESIGN THAT MAKES IT STICK
// A caption is not a subtitle track written afterwards. It is a required
// argument to playing a sound. `playCued()` takes the caption alongside the
// clip, so a sound with no caption is a type error rather than an omission
// nobody notices. That is the only version of this that survives contact with
// twenty-five modes and a deadline.

export type CueImportance =
  /** The player must act on this. Parry windows, snap counts, buzzers. */
  | 'critical'
  /** Feedback on something that already happened. Score, combo, impact. */
  | 'feedback'
  /** Colour. Crowd, ambience, music stings. */
  | 'ambient';

export interface Caption {
  /** Short. It is read at a glance, mid-action. "PARRY NOW", not a sentence. */
  text: string;
  importance: CueImportance;
  /** Screen ms. Critical cues are brief by nature; feedback can linger. */
  durationMs: number;
  /** Optional direction, for cues that come from somewhere. */
  from?: 'left' | 'right' | 'ahead' | 'behind';
  /** Monotonic id so a renderer can key and animate. */
  id: number;
}

export const DEFAULT_DURATION: Record<CueImportance, number> = {
  critical: 900,
  feedback: 1400,
  ambient: 1800,
};

/**
 * How many captions may be on screen at once.
 *
 * Three. A wall of text during play is not an accessibility feature — it is a
 * second thing to fail to read. When it overflows, ambient cues are dropped
 * before feedback, and feedback before critical.
 */
export const MAX_VISIBLE = 3;

const PRIORITY: Record<CueImportance, number> = { critical: 0, feedback: 1, ambient: 2 };

type Listener = (visible: Caption[]) => void;

export class CaptionBus {
  private queue: Caption[] = [];
  private listeners = new Set<Listener>();
  private nextId = 1;
  private enabled = false;
  private now: () => number;
  private expiry = new Map<number, number>();

  /** `now` is injectable so the eviction logic can be tested without waiting. */
  constructor(now: () => number = () => Date.now()) { this.now = now; }

  setEnabled(on: boolean): void {
    this.enabled = on;
    if (!on) { this.queue = []; this.expiry.clear(); this.publish(); }
  }

  isEnabled(): boolean { return this.enabled; }

  /**
   * Show a caption. Returns its id, or null when captions are off.
   *
   * Silently doing nothing when disabled is deliberate: call sites should not
   * branch on the setting, or half of them will forget.
   */
  cue(text: string, importance: CueImportance = 'feedback', from?: Caption['from']): number | null {
    if (!this.enabled) return null;
    const c: Caption = {
      id: this.nextId++,
      text, importance, from,
      durationMs: DEFAULT_DURATION[importance],
    };
    this.expiry.set(c.id, this.now() + c.durationMs);
    this.queue.push(c);
    this.evict();
    this.publish();
    return c.id;
  }

  /** Drop expired captions. Call from the mode's update loop. */
  tick(): void {
    if (!this.enabled) return;
    const t = this.now();
    const before = this.queue.length;
    this.queue = this.queue.filter((c) => (this.expiry.get(c.id) ?? 0) > t);
    if (this.queue.length !== before) {
      for (const [id] of this.expiry) if (!this.queue.some((c) => c.id === id)) this.expiry.delete(id);
      this.publish();
    }
  }

  /**
   * Trim to MAX_VISIBLE, dropping the LEAST important oldest first.
   *
   * A critical cue must never be pushed off screen by crowd noise, which is
   * exactly what a plain FIFO would do at the worst possible moment.
   */
  private evict(): void {
    while (this.queue.length > MAX_VISIBLE) {
      let worst = 0;
      for (let i = 1; i < this.queue.length; i++) {
        const a = this.queue[i];
        const b = this.queue[worst];
        if (PRIORITY[a.importance] > PRIORITY[b.importance]
          || (PRIORITY[a.importance] === PRIORITY[b.importance] && a.id < b.id)) worst = i;
      }
      this.expiry.delete(this.queue[worst].id);
      this.queue.splice(worst, 1);
    }
  }

  visible(): Caption[] {
    return [...this.queue].sort((a, b) => PRIORITY[a.importance] - PRIORITY[b.importance] || a.id - b.id);
  }

  subscribe(fn: Listener): () => void {
    this.listeners.add(fn);
    fn(this.visible());
    return () => this.listeners.delete(fn);
  }

  clear(): void { this.queue = []; this.expiry.clear(); this.publish(); }

  private publish(): void {
    const v = this.visible();
    for (const fn of this.listeners) fn(v);
  }
}

export const captions = new CaptionBus();

/**
 * Play a sound and caption it in one call.
 *
 * The caption is a REQUIRED parameter. That is the whole mechanism: you cannot
 * add a gameplay sound to this codebase without saying what it means, because
 * the compiler will not let you.
 */
export function playCued(
  play: () => void,
  caption: string,
  importance: CueImportance = 'feedback',
  from?: Caption['from'],
): void {
  play();
  captions.cue(caption, importance, from);
}
