from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


PlayerId = str
MatchId = str


class TutorPersona(str, Enum):
    MAGNUS = "magnus"
    ELARA = "elara"
    JAX = "jax"


class SabotageType(str, Enum):
    STATIC_FOG = "static_fog"
    TIME_WARP = "time_warp"
    INPUT_SCRAMBLE = "input_scramble"


SABOTAGE_COST: dict[SabotageType, int] = {
    SabotageType.STATIC_FOG: 20,
    SabotageType.TIME_WARP: 30,
    SabotageType.INPUT_SCRAMBLE: 35,
}


SABOTAGE_ANSWER_DURATION: dict[SabotageType, int] = {
    SabotageType.STATIC_FOG: 3,
    SabotageType.TIME_WARP: 2,
    SabotageType.INPUT_SCRAMBLE: 2,
}


class MatchStatus(str, Enum):
    PENDING_OPPONENT = "pending_opponent"
    ACTIVE = "active"
    FINALIZED = "finalized"
    CANCELLED = "cancelled"


@dataclass(slots=True)
class MatchPlayerState:
    player_id: PlayerId
    tutor: TutorPersona
    wager: int
    score: int = 0
    correct: int = 0
    wrong: int = 0
    answers: int = 0
    total_response_ms: int = 0
    hint_charges: int = 0
    anti_cheat_flags: list[str] = field(default_factory=list)
    forfeited: bool = False


@dataclass(slots=True)
class DebuffState:
    type: SabotageType
    source_player_id: PlayerId
    target_player_id: PlayerId
    remaining_answers: int
    applied_at: int


@dataclass(slots=True)
class SabotageLogEntry:
    type: SabotageType
    source_player_id: PlayerId
    target_player_id: PlayerId
    spent: int
    timestamp: int


@dataclass(slots=True)
class BrainBrawlMatch:
    id: MatchId
    challenger_id: PlayerId
    challenge_id: str
    status: MatchStatus
    wager_amount: int
    escrow_pool: int
    created_at: int
    players: dict[PlayerId, MatchPlayerState]
    active_debuffs: list[DebuffState] = field(default_factory=list)
    sabotage_log: list[SabotageLogEntry] = field(default_factory=list)
    opponent_id: PlayerId | None = None
    started_at: int | None = None
    ended_at: int | None = None
    winner_id: PlayerId | None = None


@dataclass(slots=True)
class CreateMatchInput:
    challenger_id: PlayerId
    challenge_id: str
    wager_amount: int
    tutor: TutorPersona


@dataclass(slots=True)
class AcceptMatchInput:
    match_id: MatchId
    opponent_id: PlayerId
    tutor: TutorPersona


@dataclass(slots=True)
class PurchaseSabotageInput:
    match_id: MatchId
    source_player_id: PlayerId
    target_player_id: PlayerId
    type: SabotageType


@dataclass(slots=True)
class AnswerInput:
    match_id: MatchId
    player_id: PlayerId
    question_id: str
    is_correct: bool
    response_ms: int
    used_hint: bool = False
    has_interaction_proof: bool = False


@dataclass(slots=True)
class DifficultyContext:
    current_difficulty: int  # 1..10
    recent_failure_rate: float  # 0..1
    average_response_ms: float
