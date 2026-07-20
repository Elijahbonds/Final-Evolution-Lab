// SKATE vs. Ghost — client match logic. Player B watches the challenger's
// ghost land each trick (deterministic replay), then must match it. Miss = a
// letter. Five letters = loss; survive the line = win.

import {
  NEXT_LETTER, type GhostRun, type GhostTrick, type SkateLetters,
} from '../shared/progressionContracts';

export interface SkateModeHooks {
  /** Replay the challenger's ghost performing ONE trick (recorded transforms). */
  playGhostTrick(trick: GhostTrick): Promise<void>;
  /** Let the live player attempt the same trick; resolve landed?  */
  playerAttempt(trick: GhostTrick): Promise<{ landed: boolean }>;
  setHud(update: Record<string, string | number>): void;
  banner(text: string): void;
}

export interface SkateApi {
  reportAttempt(matchId: string, trickIdx: number, landed: boolean): Promise<{
    opponentLetters: SkateLetters; state: 'active' | 'complete'; winnerId?: string;
  }>;
}

export interface SkateMatchOutcome {
  outcome: 'SKATE_WIN' | 'SKATE_LOSS';
  score: number;
  stats: Record<string, number>;
}

export async function playSkateMatch(
  hooks: SkateModeHooks,
  api: SkateApi,
  matchId: string,
  ghost: GhostRun,
  myUserId: string,
): Promise<SkateMatchOutcome> {
  let letters: SkateLetters = '';
  let landedCount = 0;

  hooks.setHud({ letters: '·····', trick: `1/${ghost.tricks.length}` });

  for (let i = 0; i < ghost.tricks.length; i++) {
    const trick = ghost.tricks[i];
    hooks.setHud({ trick: `${i + 1}/${ghost.tricks.length}` });

    // 1) Watch the ghost set the trick
    hooks.banner('WATCH THE LINE');
    await hooks.playGhostTrick(trick);

    // 2) Match it
    hooks.banner('YOUR TURN — MATCH IT');
    const { landed } = await hooks.playerAttempt(trick);
    if (landed) landedCount++;
    else {
      letters = NEXT_LETTER[letters];
      hooks.banner(`LETTER! ${letters.padEnd(5, '·')}`);
    }
    hooks.setHud({ letters: letters.padEnd(5, '·') });

    // 3) Server is authoritative on match state (anti-tamper + async sync)
    const server = await api.reportAttempt(matchId, i, landed);
    letters = server.opponentLetters;
    if (server.state === 'complete') {
      const won = server.winnerId === myUserId;
      hooks.banner(won ? 'LINE SURVIVED — YOU WIN' : 'S·K·A·T·E — LETTERED OUT');
      return {
        outcome: won ? 'SKATE_WIN' : 'SKATE_LOSS',
        score: landedCount * trickAvg(ghost) + (won ? 500 : 0),
        stats: { tricksLanded: landedCount, tricksSet: ghost.tricks.length, letters: letters.length },
      };
    }
  }

  // Defensive: server decides completion; reaching here means it already did.
  return {
    outcome: 'SKATE_WIN',
    score: landedCount * trickAvg(ghost) + 500,
    stats: { tricksLanded: landedCount, tricksSet: ghost.tricks.length, letters: letters.length },
  };
}

const trickAvg = (g: GhostRun): number =>
  Math.round(g.tricks.reduce((s, t) => s + t.scoreValue, 0) / Math.max(g.tricks.length, 1));

// RECORDING SIDE (challenger): during a normal Skate Run, "SET A LINE" mode
// captures up to 12 landed tricks as GhostTrick[] (+ optional input stream for
// full-motion replay) → POST /api/ghosts → createChallenge → share the link
// through the existing CHALLENGE A FRIEND flow.
