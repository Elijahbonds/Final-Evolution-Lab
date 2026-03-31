import { AntiCheatEngine } from "./antiCheat";
import { RemediationEngine } from "./remediation";
import {
  AcceptMatchInput,
  AnswerInput,
  BrainBrawlMatch,
  CreateMatchInput,
  DebuffState,
  MatchPlayerState,
  MatchStatus,
  PurchaseSabotageInput,
  SABOTAGE_ANSWER_DURATION,
  SABOTAGE_COST,
  SabotageType,
  TutorPersona,
} from "./types";
import { InMemoryShardWallet } from "./wallet";

interface MatchHolds {
  challengerHoldId: string;
  opponentHoldId?: string;
}

export class BrainBrawlService {
  private readonly wallet = new InMemoryShardWallet();
  private readonly antiCheat = new AntiCheatEngine();
  private readonly remediation = new RemediationEngine();

  private readonly matches = new Map<string, BrainBrawlMatch>();
  private readonly holdsByMatch = new Map<string, MatchHolds>();
  private matchCounter = 1;

  seedBalance(playerId: string, shards: number): void {
    this.wallet.setBalance(playerId, shards);
  }

  getBalance(playerId: string): number {
    return this.wallet.getBalance(playerId);
  }

  getMatch(matchId: string): BrainBrawlMatch | undefined {
    return this.matches.get(matchId);
  }

  createMatch(input: CreateMatchInput): BrainBrawlMatch {
    if (input.wagerAmount <= 0) {
      throw new Error("Wager amount must be greater than zero.");
    }

    const holdId = this.wallet.reserve(input.challengerId, input.wagerAmount);
    const matchId = `match_${this.matchCounter++}`;

    const challengerState: MatchPlayerState = {
      playerId: input.challengerId,
      tutor: input.tutor,
      wager: input.wagerAmount,
      score: 0,
      correct: 0,
      wrong: 0,
      answers: 0,
      totalResponseMs: 0,
      hintCharges: input.tutor === TutorPersona.Elara ? 1 : 0,
      antiCheatFlags: [],
      forfeited: false,
    };

    const match: BrainBrawlMatch = {
      id: matchId,
      challengerId: input.challengerId,
      challengeId: input.challengeId,
      status: MatchStatus.PendingOpponent,
      wagerAmount: input.wagerAmount,
      escrowPool: 0,
      createdAt: Date.now(),
      players: {
        [input.challengerId]: challengerState,
      },
      activeDebuffs: [],
      sabotageLog: [],
    };

    this.matches.set(matchId, match);
    this.holdsByMatch.set(matchId, { challengerHoldId: holdId });
    return match;
  }

  acceptMatch(input: AcceptMatchInput): BrainBrawlMatch {
    const match = this.requireMatch(input.matchId);
    if (match.status !== MatchStatus.PendingOpponent) {
      throw new Error("Match is not waiting for an opponent.");
    }
    if (input.opponentId === match.challengerId) {
      throw new Error("Challenger cannot join as opponent.");
    }

    const holds = this.requireHolds(match.id);
    holds.opponentHoldId = this.wallet.reserve(input.opponentId, match.wagerAmount);

    match.opponentId = input.opponentId;
    match.players[input.opponentId] = {
      playerId: input.opponentId,
      tutor: input.tutor,
      wager: match.wagerAmount,
      score: 0,
      correct: 0,
      wrong: 0,
      answers: 0,
      totalResponseMs: 0,
      hintCharges: input.tutor === TutorPersona.Elara ? 1 : 0,
      antiCheatFlags: [],
      forfeited: false,
    };

    // Move both reserved wagers into escrow once both players are locked.
    const challengerContribution = this.wallet.capture(holds.challengerHoldId);
    const opponentContribution = this.wallet.capture(holds.opponentHoldId);
    match.escrowPool = challengerContribution + opponentContribution;
    match.status = MatchStatus.Active;
    match.startedAt = Date.now();

    return match;
  }

  cancelPendingMatch(matchId: string): BrainBrawlMatch {
    const match = this.requireMatch(matchId);
    if (match.status !== MatchStatus.PendingOpponent) {
      throw new Error("Only pending matches can be cancelled.");
    }

    const holds = this.requireHolds(matchId);
    this.wallet.release(holds.challengerHoldId);
    this.holdsByMatch.delete(matchId);

    match.status = MatchStatus.Cancelled;
    match.endedAt = Date.now();
    return match;
  }

  purchaseSabotage(input: PurchaseSabotageInput): BrainBrawlMatch {
    const match = this.requireActiveMatch(input.matchId);
    this.assertPlayerInMatch(match, input.sourcePlayerId);
    this.assertPlayerInMatch(match, input.targetPlayerId);

    if (input.sourcePlayerId === input.targetPlayerId) {
      throw new Error("Sabotage target must be the opponent.");
    }

    const cost = SABOTAGE_COST[input.type];
    this.wallet.debit(input.sourcePlayerId, cost);

    const debuff: DebuffState = {
      type: input.type,
      sourcePlayerId: input.sourcePlayerId,
      targetPlayerId: input.targetPlayerId,
      remainingAnswers: SABOTAGE_ANSWER_DURATION[input.type],
      appliedAt: Date.now(),
    };

    match.activeDebuffs.push(debuff);
    match.sabotageLog.push({
      type: input.type,
      sourcePlayerId: input.sourcePlayerId,
      targetPlayerId: input.targetPlayerId,
      spent: cost,
      timestamp: Date.now(),
    });

    return match;
  }

  recordAnswer(input: AnswerInput): BrainBrawlMatch {
    const match = this.requireActiveMatch(input.matchId);
    this.assertPlayerInMatch(match, input.playerId);

    const player = match.players[input.playerId];
    if (player.forfeited) {
      throw new Error("Player is forfeited and cannot answer.");
    }

    const antiCheat = this.antiCheat.inspectAnswer(
      {
        responseMs: input.responseMs,
        hasInteractionProof: input.hasInteractionProof ?? false,
      },
      player.antiCheatFlags
    );

    player.antiCheatFlags.push(...antiCheat.flags);
    if (antiCheat.autoForfeit) {
      player.forfeited = true;
      player.score -= 200;
      return match;
    }

    let effectiveCorrect = input.isCorrect;
    const debuffs = this.getDebuffsForPlayer(match, input.playerId);

    for (const debuff of debuffs) {
      if (debuff.type === SabotageType.TimeWarp && input.responseMs > 4000) {
        effectiveCorrect = false;
      }
      if (debuff.type === SabotageType.InputScramble && player.answers % 2 === 0) {
        effectiveCorrect = false;
      }
    }

    let delta = effectiveCorrect ? 100 : -25;

    if (debuffs.some((d) => d.type === SabotageType.StaticFog) && effectiveCorrect) {
      delta = Math.floor(delta * 0.8);
    }

    if (input.usedHint && player.hintCharges > 0) {
      player.hintCharges -= 1;
      delta = Math.floor(delta * 0.9); // Hint trades slight score efficiency.
    }

    player.score += delta;
    player.answers += 1;
    player.totalResponseMs += input.responseMs;
    if (effectiveCorrect) {
      player.correct += 1;
    } else {
      player.wrong += 1;
    }

    this.consumeDebuffsForPlayer(match, input.playerId);
    return match;
  }

  finalizeByScore(matchId: string): BrainBrawlMatch {
    const match = this.requireActiveMatch(matchId);
    const [first, second] = Object.values(match.players);

    const winner =
      first.forfeited && !second.forfeited
        ? second
        : second.forfeited && !first.forfeited
          ? first
          : first.score >= second.score
            ? first
            : second;

    return this.finalize(matchId, winner.playerId);
  }

  finalize(matchId: string, winnerId: string): BrainBrawlMatch {
    const match = this.requireActiveMatch(matchId);
    this.assertPlayerInMatch(match, winnerId);

    const loserId = Object.keys(match.players).find((id) => id !== winnerId);
    if (!loserId) {
      throw new Error("Cannot determine loser.");
    }

    const winner = match.players[winnerId];
    const loser = match.players[loserId];

    // Settle wager escrow first.
    this.wallet.credit(winnerId, match.escrowPool);

    // Tutor sponsorship modifiers.
    if (loser.tutor === TutorPersona.Magnus) {
      // Magnus safety net: partial shard-loss mitigation.
      this.wallet.credit(loserId, Math.floor(match.wagerAmount * 0.2));
    }

    if (winner.tutor === TutorPersona.Jax) {
      // Jax strategic edge: extra shard gain for competitive wins.
      this.wallet.credit(winnerId, Math.floor(match.wagerAmount * 0.05));
    }

    // Example remediation output hook (consumer can persist this signal).
    const failureRate = winner.answers === 0 ? 0 : winner.wrong / winner.answers;
    const avgMs = winner.answers === 0 ? 5000 : winner.totalResponseMs / winner.answers;
    this.remediation.nextDifficulty({
      currentDifficulty: 5,
      recentFailureRate: failureRate,
      averageResponseMs: avgMs,
    });

    match.status = MatchStatus.Finalized;
    match.winnerId = winnerId;
    match.endedAt = Date.now();
    return match;
  }

  private getDebuffsForPlayer(match: BrainBrawlMatch, playerId: string): DebuffState[] {
    return match.activeDebuffs.filter((d) => d.targetPlayerId === playerId && d.remainingAnswers > 0);
  }

  private consumeDebuffsForPlayer(match: BrainBrawlMatch, playerId: string): void {
    for (const debuff of match.activeDebuffs) {
      if (debuff.targetPlayerId === playerId && debuff.remainingAnswers > 0) {
        debuff.remainingAnswers -= 1;
      }
    }

    match.activeDebuffs = match.activeDebuffs.filter((d) => d.remainingAnswers > 0);
  }

  private requireMatch(matchId: string): BrainBrawlMatch {
    const match = this.matches.get(matchId);
    if (!match) {
      throw new Error("Match not found.");
    }
    return match;
  }

  private requireActiveMatch(matchId: string): BrainBrawlMatch {
    const match = this.requireMatch(matchId);
    if (match.status !== MatchStatus.Active) {
      throw new Error("Match is not active.");
    }
    return match;
  }

  private requireHolds(matchId: string): MatchHolds {
    const holds = this.holdsByMatch.get(matchId);
    if (!holds) {
      throw new Error("Match hold state missing.");
    }
    return holds;
  }

  private assertPlayerInMatch(match: BrainBrawlMatch, playerId: string): void {
    if (!match.players[playerId]) {
      throw new Error("Player is not part of this match.");
    }
  }
}
