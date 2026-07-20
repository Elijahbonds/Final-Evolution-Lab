// King of the Court — rules wrapper over the 3v3/court core. Win = hold the
// court; opponents escalate per defense; one loss ends the run; streak is the
// score. No new assets: it re-parameterizes the existing opponent AI.

import {
  KOTC_ESCALATION, KOTC_CROWN_STREAK, KOTC_CROWN_MASTERY_BONUS, type KotcTier,
} from '../shared/progressionContracts';

export interface CourtGameHooks {
  /** Re-parameterize the existing opponent squad before a game. */
  applyOpponentProfile(p: { speedMul: number; accuracyMul: number; label: string }): void;
  /** Play one first-to-N game; resolves with whether the PLAYER won. */
  playGame(targetScore: number): Promise<{ playerWon: boolean; playerPts: number; oppPts: number }>;
  setHud(update: Record<string, string | number>): void;
  banner(text: string): void;
}

export interface KotcResult {
  outcome: string;                       // 'KOTC_STREAK_N'
  score: number;
  stats: Record<string, number>;
}

const GAME_TARGET = 11;                  // short games keep runs tense

export async function runKingOfTheCourt(hooks: CourtGameHooks): Promise<KotcResult> {
  let streak = 0;
  let totalPts = 0;
  let crowned = false;

  for (;;) {
    const tier: KotcTier = KOTC_ESCALATION[Math.min(streak, KOTC_ESCALATION.length - 1)];
    hooks.applyOpponentProfile({
      speedMul: tier.speedMul, accuracyMul: tier.accuracyMul, label: tier.note,
    });
    hooks.setHud({
      streak: `👑 ${streak}`,
      challengers: tier.note.toUpperCase(),
      hint: streak === 0 ? 'Take the court' : 'Hold the court',
    });

    const game = await hooks.playGame(GAME_TARGET);
    totalPts += game.playerPts;

    if (!game.playerWon) {
      hooks.banner(streak > 0 ? `DETHRONED · HELD IT ${streak}` : 'COURT LOST');
      break;
    }

    streak++;
    hooks.banner(streak === 1 ? 'COURT IS YOURS' : `STILL THE KING · ${streak}`);
    if (streak === KOTC_CROWN_STREAK && !crowned) {
      crowned = true;
      hooks.banner('👑 CROWNED — LEGENDS INBOUND');
    }
  }

  return {
    outcome: `KOTC_STREAK_${streak}`,
    score: streak * 100 + totalPts,
    stats: {
      kotcStreak: streak,
      totalPts,
      crowned: crowned ? 1 : 0,
      // server: on crowned=1, grantMasteryBonus(ctx,'threev3',KOTC_CROWN_MASTERY_BONUS)
      crownBonusPoints: crowned ? KOTC_CROWN_MASTERY_BONUS : 0,
    },
  };
}

// WIRING: add a "KING OF THE COURT" entry on the 3v3 mode card. The 3v3
// ModeDefinition exposes the four hooks (applyOpponentProfile maps onto its
// existing AI difficulty params; playGame runs its normal loop to 11).
// Result flows through the normal SessionResult sink — crown bonus is minted
// server-side off stats.crowned, never client-side.
