export type PlayerId = string;
export type MatchId = string;

export enum TutorPersona {
  Magnus = "magnus",
  Elara = "elara",
  Jax = "jax",
}

export enum SabotageType {
  StaticFog = "static_fog",
  TimeWarp = "time_warp",
  InputScramble = "input_scramble",
}

export const SABOTAGE_COST: Record<SabotageType, number> = {
  [SabotageType.StaticFog]: 20,
  [SabotageType.TimeWarp]: 30,
  [SabotageType.InputScramble]: 35,
};

export const SABOTAGE_ANSWER_DURATION: Record<SabotageType, number> = {
  [SabotageType.StaticFog]: 3,
  [SabotageType.TimeWarp]: 2,
  [SabotageType.InputScramble]: 2,
};

export interface MatchPlayerState {
  playerId: PlayerId;
  tutor: TutorPersona;
  wager: number;
  score: number;
  correct: number;
  wrong: number;
  answers: number;
  totalResponseMs: number;
  hintCharges: number;
  antiCheatFlags: string[];
  forfeited: boolean;
}

export interface DebuffState {
  type: SabotageType;
  sourcePlayerId: PlayerId;
  targetPlayerId: PlayerId;
  remainingAnswers: number;
  appliedAt: number;
}

export enum MatchStatus {
  PendingOpponent = "pending_opponent",
  Active = "active",
  Finalized = "finalized",
  Cancelled = "cancelled",
}

export interface BrainBrawlMatch {
  id: MatchId;
  challengerId: PlayerId;
  opponentId?: PlayerId;
  challengeId: string;
  status: MatchStatus;
  wagerAmount: number;
  escrowPool: number;
  createdAt: number;
  startedAt?: number;
  endedAt?: number;
  winnerId?: PlayerId;
  players: Record<PlayerId, MatchPlayerState>;
  activeDebuffs: DebuffState[];
  sabotageLog: Array<{
    type: SabotageType;
    sourcePlayerId: PlayerId;
    targetPlayerId: PlayerId;
    spent: number;
    timestamp: number;
  }>;
}

export interface CreateMatchInput {
  challengerId: PlayerId;
  challengeId: string;
  wagerAmount: number;
  tutor: TutorPersona;
}

export interface AcceptMatchInput {
  matchId: MatchId;
  opponentId: PlayerId;
  tutor: TutorPersona;
}

export interface PurchaseSabotageInput {
  matchId: MatchId;
  sourcePlayerId: PlayerId;
  targetPlayerId: PlayerId;
  type: SabotageType;
}

export interface AnswerInput {
  matchId: MatchId;
  playerId: PlayerId;
  questionId: string;
  isCorrect: boolean;
  responseMs: number;
  usedHint?: boolean;
  hasInteractionProof?: boolean;
}

export interface DifficultyContext {
  currentDifficulty: number; // 1..10
  recentFailureRate: number; // 0..1
  averageResponseMs: number;
}
