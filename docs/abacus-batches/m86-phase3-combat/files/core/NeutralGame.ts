// NeutralGame — spacing, frame advantage, and whiff punish.
//
// WHAT COMBAT HAS TODAY
// `FightCore` (M53) is a decent foundation: attacks with startup, range and
// damage; a guard gauge; chi; a 160ms parry window; and `resolveStrike()`
// returning whiff / parried / blocked / guardBreak / hit.
//
// But `'whiff'` COSTS THE ATTACKER NOTHING. There are no recovery frames. Miss
// a heavy from full range and you are immediately ready to act again.
//
// That one absence removes the entire neutral game. If whiffing is free:
//   · spacing is pointless — there is no reward for making them miss
//   · throwing your longest attack constantly is optimal
//   · the winner is whoever mashes fastest, which is why every arcade fighter
//     that skips this feels like a button-mashing contest
//
// So combat currently has no depth to *find*, however good the animations get.
// This is the layer that gives it one.
//
// THE THREE CONCEPTS, WHICH ARE THE WHOLE GENRE
//   FRAME DATA       every attack is startup / active / recovery
//   FRAME ADVANTAGE  after a block, one fighter acts first — and by how much
//   WHIFF PUNISH     recovery is a window where you cannot defend
//
// Master those and you have footsies: hover just outside their range, bait the
// swing, punish the recovery. That is a skill ceiling that rewards reading a
// human, and it is what "better than the benchmark" has to mean here — not
// more combo strings to memorise.
//
// WHY THIS IS ONLY POSSIBLE NOW
// Frame data is measured in FRAMES. Before M83 the update loop ran on
// `engine.getDeltaTime()`, so "13 frames of startup" meant 216ms on a good
// frame and 430ms on a bad one — the same attack was a different move
// depending on your phone. Fixed 60Hz ticks are what make frame data mean
// anything at all. This file is a direct payoff of that batch.

import { Rng } from './Rng';

/** One simulation tick at 60Hz. Frame data is expressed in these. */
export const FRAME_MS = 1000 / 60;

export type Phase = 'idle' | 'startup' | 'active' | 'recovery' | 'blockstun' | 'hitstun';

export interface FrameData {
  /** Frames before the hitbox goes live. Longer = more readable. */
  startup: number;
  /** Frames the hitbox is live. */
  active: number;
  /** Frames after, during which you CANNOT defend. The cost of missing. */
  recovery: number;
  /**
   * Frame advantage when the attack is blocked.
   *
   * Negative means the defender acts first by that many frames — you are
   * "minus on block" and punishable. This single number is what makes an
   * attack safe or unsafe, and it is why a jab and a heavy are different
   * decisions rather than different damage numbers.
   */
  onBlock: number;
  /** Frame advantage on a clean hit. Positive keeps pressure. */
  onHit: number;
  /** Reach in metres. */
  range: number;
}

/**
 * Frame data for the karate set.
 *
 * Tuned to a genre-standard shape, not copied from anything: a fast jab that
 * is plus on block, a mid kick that is roughly neutral, and a heavy that hurts
 * and is deeply unsafe. The relationships matter more than the absolute
 * numbers — jab beats heavy in a scramble, heavy punishes a whiff, and neither
 * is ever the always-correct answer.
 */
export const KARATE_FRAMES: Record<string, FrameData> = {
  jab:     { startup: 4,  active: 2, recovery: 7,  onBlock: 2,  onHit: 5,  range: 1.6 },
  kick:    { startup: 9,  active: 3, recovery: 14, onBlock: -3, onHit: 3,  range: 1.9 },
  heavy:   { startup: 15, active: 3, recovery: 24, onBlock: -12, onHit: 8, range: 1.8 },
  special: { startup: 18, active: 4, recovery: 28, onBlock: -16, onHit: 14, range: 2.2 },
};

/**
 * Staff: longer reach paid for in every other column.
 *
 * The matchup IS the trade. A staff poke outranges a jab, so the unarmed
 * fighter has to get inside — and once inside, the staff's recovery makes it
 * the one being punished. Neither loadout is stronger; they want different
 * distances, which is the only kind of asymmetry worth having.
 */
export const STAFF_FRAMES: Record<string, FrameData> = {
  jab:     { startup: 7,  active: 2, recovery: 12, onBlock: -1, onHit: 4,  range: 2.6 },
  kick:    { startup: 12, active: 3, recovery: 18, onBlock: -6, onHit: 2,  range: 2.8 },
  heavy:   { startup: 19, active: 4, recovery: 28, onBlock: -15, onHit: 9, range: 2.6 },
  special: { startup: 22, active: 4, recovery: 32, onBlock: -18, onHit: 15, range: 3.0 },
};

export interface AttackState {
  phase: Phase;
  /** Frames left in the current phase. */
  framesLeft: number;
  /** Which attack, while not idle. */
  attackId: string | null;
  /** Frames of advantage owed to this fighter. Positive = acts sooner. */
  advantage: number;
}

export const IDLE_STATE: AttackState = {
  phase: 'idle', framesLeft: 0, attackId: null, advantage: 0,
};

/** Begin an attack. Returns the new state, or null if not actionable. */
export function startAttack(s: AttackState, attackId: string, fd: FrameData): AttackState | null {
  if (!canAct(s)) return null;
  return { phase: 'startup', framesLeft: fd.startup, attackId, advantage: 0 };
}

/** Can this fighter act right now? */
export function canAct(s: AttackState): boolean {
  return s.phase === 'idle' && s.advantage >= 0;
}

/**
 * Is this fighter open to a punish?
 *
 * Recovery and hitstun both count. Blockstun does NOT: you are stuck but not
 * vulnerable, and conflating the two is what makes blocking feel useless.
 */
export function isPunishable(s: AttackState): boolean {
  return s.phase === 'recovery' || s.phase === 'hitstun' || s.advantage < 0;
}

/**
 * Frames of guaranteed punish available against this fighter.
 *
 * A punish "lands" only if your startup fits inside it. That is the whole
 * decision: a jab punishes almost anything, a heavy punishes only a big
 * mistake — and choosing wrong means you whiff and get punished back.
 */
export function punishWindow(s: AttackState): number {
  if (s.phase === 'recovery' || s.phase === 'hitstun') return s.framesLeft + Math.max(0, -s.advantage);
  if (s.advantage < 0) return -s.advantage;
  return 0;
}

/** Would this attack actually land as a punish? */
export function punishLands(window: number, fd: FrameData): boolean {
  return window >= fd.startup;
}

/**
 * Advance one FIXED tick.
 *
 * `onActive` fires on the first frame the hitbox goes live, so the caller does
 * the hit detection exactly once — not every frame it is live, which is how
 * an attack ends up hitting three times.
 */
export function tickAttack(s: AttackState, onActive?: (attackId: string) => void): AttackState {
  if (s.advantage < 0) {
    const adv = s.advantage + 1;
    return { ...s, advantage: adv, phase: adv >= 0 ? 'idle' : s.phase };
  }
  if (s.phase === 'idle') return s;

  const left = s.framesLeft - 1;
  if (left > 0) return { ...s, framesLeft: left };

  switch (s.phase) {
    case 'startup': {
      if (s.attackId && onActive) onActive(s.attackId);
      return { ...s, phase: 'active', framesLeft: 0 };
    }
    case 'active':
    case 'blockstun':
    case 'hitstun':
    case 'recovery':
      return { ...IDLE_STATE };
    default:
      return { ...IDLE_STATE };
  }
}

/** Move an attack from active into recovery — the caller does this once the
 *  active frames have been resolved into an outcome. */
export function enterRecovery(s: AttackState, fd: FrameData): AttackState {
  return { ...s, phase: 'recovery', framesLeft: fd.recovery };
}

export type Outcome = 'whiff' | 'blocked' | 'hit' | 'parried';

export interface Exchange {
  attacker: AttackState;
  defender: AttackState;
  /** Plain-language read on who is now favoured. Debuggable systems get fixed. */
  summary: string;
}

/**
 * Resolve an attack into frame advantage for both fighters.
 *
 * This is where the whole model becomes real: the same attack leaves you safe,
 * punishable, or dead depending on what the defender did about it.
 */
export function resolveExchange(
  attackerState: AttackState, defenderState: AttackState, fd: FrameData, outcome: Outcome,
): Exchange {
  switch (outcome) {
    case 'whiff':
      // THE POINT OF THE WHOLE FILE. Missing puts you in recovery, and every
      // recovery frame is a frame the opponent can act and you cannot.
      return {
        attacker: enterRecovery(attackerState, fd),
        defender: defenderState,
        summary: `whiffed — ${fd.recovery} frames of recovery, fully punishable`,
      };

    case 'blocked':
      // Both fighters are locked; who is free FIRST is `onBlock`.
      return {
        attacker: fd.onBlock < 0
          ? { ...IDLE_STATE, advantage: fd.onBlock }
          : { ...IDLE_STATE, advantage: 0 },
        defender: fd.onBlock < 0
          ? { ...IDLE_STATE }
          : { phase: 'blockstun', framesLeft: fd.onBlock, attackId: null, advantage: 0 },
        summary: fd.onBlock < 0
          ? `blocked and ${Math.abs(fd.onBlock)} frames minus — the defender can punish`
          : `blocked but +${fd.onBlock} — the attacker keeps pressure`,
      };

    case 'hit':
      return {
        attacker: { ...IDLE_STATE },
        defender: { phase: 'hitstun', framesLeft: fd.onHit, attackId: null, advantage: 0 },
        summary: `hit for +${fd.onHit}`,
      };

    case 'parried':
      // A parry is the biggest swing in the game and it should be: it beats a
      // block outright, which is what stops blocking being the safe default.
      return {
        attacker: { ...IDLE_STATE, advantage: -(fd.recovery + 12) },
        defender: { ...IDLE_STATE },
        summary: `PARRIED — ${fd.recovery + 12} frames of guaranteed punish`,
      };
  }
}

// ── spacing ──────────────────────────────────────────────────────────────

export type SpacingZone = 'out' | 'tip' | 'threat' | 'inside';

/**
 * Where the fighters stand relative to each other's reach.
 *
 *   'out'     nobody can touch anybody
 *   'tip'     YOU can reach, they cannot          ← where a good player lives
 *   'threat'  both can reach
 *   'inside'  they reach you, you are too close for your longest tools
 *
 * `'tip'` is the whole game. Sitting there means every attack they throw
 * whiffs, and every whiff is a punish. A player who understands this beats one
 * who is faster, which is the mark of a real fighting game.
 */
export function spacingZone(distance: number, myReach: number, theirReach: number): SpacingZone {
  const inMine = distance <= myReach;
  const inTheirs = distance <= theirReach;
  if (!inMine && !inTheirs) return 'out';
  if (inMine && !inTheirs) return 'tip';
  if (inMine && inTheirs) return distance < theirReach * 0.6 ? 'inside' : 'threat';
  return 'inside';
}

/** The distance to hold: just inside your reach, just outside theirs. Returns
 *  null when you have no reach advantage and no such distance exists. */
export function idealSpacing(myReach: number, theirReach: number): number | null {
  if (myReach <= theirReach) return null;
  return (myReach + theirReach) / 2;
}

/** Reach of the longest tool in a set. */
export function maxReach(frames: Record<string, FrameData>): number {
  return Math.max(...Object.values(frames).map((f) => f.range));
}

// ── the rival ────────────────────────────────────────────────────────────

export interface NeutralBrainConfig {
  /** 0..1 — how well it plays neutral. From DDA. */
  skill: number;
  /** Frames before it can react to a change. From `dda.aiReactionSpeed()`. */
  reactionFrames: number;
  /** 0..1 — how willing it is to commit. */
  aggression: number;
}

export interface NeutralInput {
  distance: number;
  /** The opponent's current state — what the AI can observe. */
  opponent: AttackState;
  self: AttackState;
}

export interface NeutralDecision {
  /** -1 back off, 0 hold, +1 close. */
  approach: number;
  attack: string | null;
  block: boolean;
  reason: string;
}

/**
 * A rival that plays neutral.
 *
 * Distinct from `FightCore.RivalFightBrain`, which circles, blocks on a random
 * roll, and attacks on a cooldown whenever you are in range. That brain has no
 * concept of whiff punish, so it cannot be outspaced and it cannot outspace
 * you — the only lever it has is speed.
 *
 * This one:
 *   · holds `idealSpacing()` where its reach beats yours
 *   · PUNISHES recovery with an attack whose startup actually fits
 *   · bakes the reaction delay in, so a whiff at the edge of its vision is
 *     genuinely safe for you
 *   · uses an injected Rng, so a round replays exactly
 *
 * The old brain called `Math.random()` four times a frame. No round could be
 * replayed, no ghost reproduced, no Cash Arena result audited.
 */
export class NeutralBrain {
  private rng: Rng;
  private cfg: NeutralBrainConfig;
  private frames: Record<string, FrameData>;
  private reactionDebt = 0;
  private lastOpponentPhase: Phase = 'idle';

  constructor(rng: Rng, cfg: NeutralBrainConfig, frames = KARATE_FRAMES) {
    this.rng = rng;
    this.cfg = cfg;
    this.frames = frames;
  }

  configure(cfg: Partial<NeutralBrainConfig>): void { this.cfg = { ...this.cfg, ...cfg }; }

  /** One FIXED tick. */
  decide(input: NeutralInput, opponentFrames = KARATE_FRAMES): NeutralDecision {
    const hold: NeutralDecision = { approach: 0, attack: null, block: false, reason: 'holding' };
    if (!canAct(input.self)) return { ...hold, reason: `busy (${input.self.phase})` };

    if (input.opponent.phase !== this.lastOpponentPhase) {
      this.lastOpponentPhase = input.opponent.phase;
      this.reactionDebt = this.cfg.reactionFrames;
    }
    if (this.reactionDebt > 0) {
      this.reactionDebt--;
      return { ...hold, reason: 'reacting' };
    }

    const myReach = maxReach(this.frames);
    const theirReach = maxReach(opponentFrames);

    // 1. PUNISH. The highest-value decision in the game, so it is checked
    //    first — and only with an attack whose startup genuinely fits the
    //    window, because a punish that whiffs is a free punish for them.
    const window = punishWindow(input.opponent);
    if (window > 0 && this.rng.chance(this.cfg.skill)) {
      const best = Object.entries(this.frames)
        .filter(([, f]) => punishLands(window, f) && input.distance <= f.range)
        .sort((a, b) => b[1].onHit - a[1].onHit)[0];
      if (best) {
        return { approach: 0, attack: best[0], block: false,
          reason: `punishing ${window} frames with ${best[0]}` };
      }
      // In range to punish but too far to reach: close, do not swing.
      if (window > 8) return { approach: 1, attack: null, block: false, reason: 'closing to punish' };
    }

    // 2. BLOCK a startup it can see. Blocking is not free — being minus on
    //    block is the price — so it is not the default answer.
    if (input.opponent.phase === 'startup' && input.distance <= theirReach + 0.3) {
      if (this.rng.chance(this.cfg.skill * 0.85)) {
        return { approach: 0, attack: null, block: true, reason: 'blocking the startup' };
      }
    }

    // 3. SPACING. Hold the tip where it has a reach advantage.
    const zone = spacingZone(input.distance, myReach, theirReach);
    const ideal = idealSpacing(myReach, theirReach);

    if (zone === 'tip' && ideal !== null) {
      // Free hit from a range they cannot answer — the reward for outspacing.
      const poke = Object.entries(this.frames)
        .filter(([, f]) => input.distance <= f.range)
        .sort((a, b) => a[1].startup - b[1].startup)[0];
      if (poke && this.rng.chance(this.cfg.aggression)) {
        return { approach: 0, attack: poke[0], block: false, reason: 'poking from the tip' };
      }
      return { approach: 0, attack: null, block: false, reason: 'holding the tip' };
    }

    if (zone === 'out') {
      return { approach: 1, attack: null, block: false, reason: 'closing distance' };
    }

    if (zone === 'inside') {
      // Too close for its long tools. A low-skill brain swings anyway; a
      // high-skill one backs out to where it wins.
      if (ideal !== null && this.rng.chance(this.cfg.skill)) {
        return { approach: -1, attack: null, block: false, reason: 'backing out to its range' };
      }
      const fast = Object.entries(this.frames).sort((a, b) => a[1].startup - b[1].startup)[0];
      return { approach: 0, attack: fast[0], block: false, reason: 'scrambling inside' };
    }

    // 4. THREAT — both can reach. Commit or wait, weighted by aggression.
    if (this.rng.chance(this.cfg.aggression * 0.5)) {
      const options = Object.entries(this.frames).filter(([, f]) => input.distance <= f.range);
      const pick = options[this.rng.int(0, Math.max(0, options.length - 1))];
      if (pick) return { approach: 0, attack: pick[0], block: false, reason: 'committing in threat range' };
    }
    return { approach: ideal !== null && input.distance < ideal ? -1 : 0, attack: null, block: false,
      reason: 'waiting in threat range' };
  }

  reset(): void { this.reactionDebt = 0; this.lastOpponentPhase = 'idle'; }
}

/**
 * Fraction of the DDA's reaction delay that applies to combat perception.
 *
 * THIS CONSTANT EXISTS BECAUSE OF A REAL BUG, CAUGHT BY TEST.
 *
 * `dda.aiReactionSpeed()` returns 0.5–0.8s. Used directly that is 31–44 frames
 * — LONGER than the 24 frames a whiffed heavy opens. Wiring the two systems
 * together naively produced a rival that could never punish anything at any
 * PRQ, which silently deletes the entire mechanic this file exists to add.
 *
 * The two numbers are measuring different things. DDA's delay is a DECISION
 * latency for basketball-scale actions — where to move, whether to contest.
 * Combat needs a PERCEPTION latency: how fast you see a wind-up. Human visual
 * reaction is ~200ms at best and ~270ms untrained, so 0.35× maps the DDA range
 * onto 11–16 frames. Both sit inside a heavy's recovery, so both tiers CAN
 * punish — the legend just does it more reliably, because `skill` gates the
 * attempt separately.
 */
export const COMBAT_REACTION_FACTOR = 0.35;
/** Floor and ceiling in frames. 6 frames (100ms) is faster than any human;
 *  30 (500ms) is slower than any opponent worth fighting. */
export const MIN_REACTION_FRAMES = 6;
export const MAX_REACTION_FRAMES = 30;

/** Build a rival from the DDA. PRQ decides how well it plays neutral. */
export function rivalFor(
  rng: Rng,
  dda: { prqNormalized: number; aiReactionSpeed(p: number, a: number): number; aiBlockChance(p: number, a: number): number },
  frames = KARATE_FRAMES,
  playerScore = 0,
  aiScore = 0,
): NeutralBrain {
  const raw = dda.aiReactionSpeed(playerScore, aiScore) * 60 * COMBAT_REACTION_FACTOR;
  return new NeutralBrain(rng, {
    skill: 0.3 + dda.prqNormalized * 0.5,
    reactionFrames: Math.round(Math.min(MAX_REACTION_FRAMES, Math.max(MIN_REACTION_FRAMES, raw))),
    aggression: 0.25 + dda.aiBlockChance(playerScore, aiScore),
  }, frames);
}

/**
 * A one-line coaching read, for the HUD after a round.
 *
 * Combat's depth is invisible until someone names it. A player who loses to
 * spacing without being told they were outspaced concludes the game is unfair
 * and stops — which is the difference between a deep game and a frustrating
 * one.
 */
export function coachingNote(stats: {
  whiffs: number; punishesTaken: number; blocked: number; landed: number;
}): string | null {
  const total = stats.whiffs + stats.landed + stats.blocked;
  if (total < 6) return null;
  if (stats.whiffs / total > 0.4) {
    return 'You are swinging from too far out. Every miss is free damage for them — '
      + 'walk to the edge of your range first.';
  }
  if (stats.punishesTaken > 3) {
    return 'Your heavy is deeply unsafe when blocked. Use it to punish their mistakes, '
      + 'not to start an exchange.';
  }
  if (stats.blocked / total > 0.6) {
    return 'They are reading your attacks. Bait with a step-in, then punish what they throw.';
  }
  return null;
}
