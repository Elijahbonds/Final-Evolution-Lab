from __future__ import annotations

import time
from dataclasses import dataclass

from .anti_cheat import AntiCheatEngine
from .remediation import RemediationEngine
from .types import (
    AcceptMatchInput,
    AnswerInput,
    BrainBrawlMatch,
    CreateMatchInput,
    DebuffState,
    DifficultyContext,
    MatchPlayerState,
    MatchStatus,
    PurchaseSabotageInput,
    SABOTAGE_ANSWER_DURATION,
    SABOTAGE_COST,
    SabotageLogEntry,
    SabotageType,
    TutorPersona,
)
from .wallet import InMemoryShardWallet


@dataclass(slots=True)
class MatchHolds:
    challenger_hold_id: str
    opponent_hold_id: str | None = None


class BrainBrawlService:
    def __init__(self) -> None:
        self._wallet = InMemoryShardWallet()
        self._anti_cheat = AntiCheatEngine()
        self._remediation = RemediationEngine()
        self._matches: dict[str, BrainBrawlMatch] = {}
        self._holds_by_match: dict[str, MatchHolds] = {}
        self._match_counter = 1

    def seed_balance(self, player_id: str, shards: int) -> None:
        self._wallet.set_balance(player_id, shards)

    def get_balance(self, player_id: str) -> int:
        return self._wallet.get_balance(player_id)

    def get_match(self, match_id: str) -> BrainBrawlMatch | None:
        return self._matches.get(match_id)

    def create_match(self, input_data: CreateMatchInput) -> BrainBrawlMatch:
        if input_data.wager_amount <= 0:
            raise ValueError("Wager amount must be greater than zero.")

        hold_id = self._wallet.reserve(input_data.challenger_id, input_data.wager_amount)
        match_id = f"match_{self._match_counter}"
        self._match_counter += 1

        challenger_state = MatchPlayerState(
            player_id=input_data.challenger_id,
            tutor=input_data.tutor,
            wager=input_data.wager_amount,
            hint_charges=1 if input_data.tutor == TutorPersona.ELARA else 0,
        )

        match = BrainBrawlMatch(
            id=match_id,
            challenger_id=input_data.challenger_id,
            challenge_id=input_data.challenge_id,
            status=MatchStatus.PENDING_OPPONENT,
            wager_amount=input_data.wager_amount,
            escrow_pool=0,
            created_at=self._now_ms(),
            players={input_data.challenger_id: challenger_state},
        )

        self._matches[match_id] = match
        self._holds_by_match[match_id] = MatchHolds(challenger_hold_id=hold_id)
        return match

    def accept_match(self, input_data: AcceptMatchInput) -> BrainBrawlMatch:
        match = self._require_match(input_data.match_id)
        if match.status != MatchStatus.PENDING_OPPONENT:
            raise ValueError("Match is not waiting for an opponent.")
        if input_data.opponent_id == match.challenger_id:
            raise ValueError("Challenger cannot join as opponent.")

        holds = self._require_holds(match.id)
        holds.opponent_hold_id = self._wallet.reserve(input_data.opponent_id, match.wager_amount)

        match.opponent_id = input_data.opponent_id
        match.players[input_data.opponent_id] = MatchPlayerState(
            player_id=input_data.opponent_id,
            tutor=input_data.tutor,
            wager=match.wager_amount,
            hint_charges=1 if input_data.tutor == TutorPersona.ELARA else 0,
        )

        challenger_contribution = self._wallet.capture(holds.challenger_hold_id)
        if holds.opponent_hold_id is None:
            raise RuntimeError("Opponent hold missing.")
        opponent_contribution = self._wallet.capture(holds.opponent_hold_id)

        match.escrow_pool = challenger_contribution + opponent_contribution
        match.status = MatchStatus.ACTIVE
        match.started_at = self._now_ms()
        return match

    def cancel_pending_match(self, match_id: str) -> BrainBrawlMatch:
        match = self._require_match(match_id)
        if match.status != MatchStatus.PENDING_OPPONENT:
            raise ValueError("Only pending matches can be cancelled.")

        holds = self._require_holds(match_id)
        self._wallet.release(holds.challenger_hold_id)
        self._holds_by_match.pop(match_id, None)

        match.status = MatchStatus.CANCELLED
        match.ended_at = self._now_ms()
        return match

    def purchase_sabotage(self, input_data: PurchaseSabotageInput) -> BrainBrawlMatch:
        match = self._require_active_match(input_data.match_id)
        self._assert_player_in_match(match, input_data.source_player_id)
        self._assert_player_in_match(match, input_data.target_player_id)

        if input_data.source_player_id == input_data.target_player_id:
            raise ValueError("Sabotage target must be the opponent.")

        cost = SABOTAGE_COST[input_data.type]
        self._wallet.debit(input_data.source_player_id, cost)

        debuff = DebuffState(
            type=input_data.type,
            source_player_id=input_data.source_player_id,
            target_player_id=input_data.target_player_id,
            remaining_answers=SABOTAGE_ANSWER_DURATION[input_data.type],
            applied_at=self._now_ms(),
        )
        match.active_debuffs.append(debuff)
        match.sabotage_log.append(
            SabotageLogEntry(
                type=input_data.type,
                source_player_id=input_data.source_player_id,
                target_player_id=input_data.target_player_id,
                spent=cost,
                timestamp=self._now_ms(),
            )
        )
        return match

    def record_answer(self, input_data: AnswerInput) -> BrainBrawlMatch:
        match = self._require_active_match(input_data.match_id)
        self._assert_player_in_match(match, input_data.player_id)

        player = match.players[input_data.player_id]
        if player.forfeited:
            raise ValueError("Player is forfeited and cannot answer.")

        anti_cheat_result = self._anti_cheat.inspect_answer(
            response_ms=input_data.response_ms,
            has_interaction_proof=input_data.has_interaction_proof,
            prior_flags=player.anti_cheat_flags,
        )

        player.anti_cheat_flags.extend(anti_cheat_result.flags)
        if anti_cheat_result.auto_forfeit:
            player.forfeited = True
            player.score -= 200
            return match

        effective_correct = input_data.is_correct
        debuffs = self._get_debuffs_for_player(match, input_data.player_id)

        for debuff in debuffs:
            if debuff.type == SabotageType.TIME_WARP and input_data.response_ms > 4000:
                effective_correct = False
            if debuff.type == SabotageType.INPUT_SCRAMBLE and player.answers % 2 == 0:
                effective_correct = False

        delta = 100 if effective_correct else -25

        if any(d.type == SabotageType.STATIC_FOG for d in debuffs) and effective_correct:
            delta = int(delta * 0.8)

        if input_data.used_hint and player.hint_charges > 0:
            player.hint_charges -= 1
            delta = int(delta * 0.9)

        player.score += delta
        player.answers += 1
        player.total_response_ms += input_data.response_ms
        if effective_correct:
            player.correct += 1
        else:
            player.wrong += 1

        self._consume_debuffs_for_player(match, input_data.player_id)
        return match

    def finalize_by_score(self, match_id: str) -> BrainBrawlMatch:
        match = self._require_active_match(match_id)
        players = list(match.players.values())
        if len(players) != 2:
            raise RuntimeError("Brain Brawl requires exactly two players.")

        first, second = players
        if first.forfeited and not second.forfeited:
            winner = second
        elif second.forfeited and not first.forfeited:
            winner = first
        else:
            winner = first if first.score >= second.score else second

        return self.finalize(match_id, winner.player_id)

    def finalize(self, match_id: str, winner_id: str) -> BrainBrawlMatch:
        match = self._require_active_match(match_id)
        self._assert_player_in_match(match, winner_id)

        loser_id = next((pid for pid in match.players.keys() if pid != winner_id), None)
        if loser_id is None:
            raise RuntimeError("Cannot determine loser.")

        winner = match.players[winner_id]
        loser = match.players[loser_id]

        self._wallet.credit(winner_id, match.escrow_pool)

        if loser.tutor == TutorPersona.MAGNUS:
            self._wallet.credit(loser_id, int(match.wager_amount * 0.2))

        if winner.tutor == TutorPersona.JAX:
            self._wallet.credit(winner_id, int(match.wager_amount * 0.05))

        failure_rate = 0 if winner.answers == 0 else winner.wrong / winner.answers
        average_ms = 5000 if winner.answers == 0 else winner.total_response_ms / winner.answers
        _ = self._remediation.next_difficulty(
            DifficultyContext(
                current_difficulty=5,
                recent_failure_rate=failure_rate,
                average_response_ms=average_ms,
            )
        )

        match.status = MatchStatus.FINALIZED
        match.winner_id = winner_id
        match.ended_at = self._now_ms()
        return match

    def _get_debuffs_for_player(self, match: BrainBrawlMatch, player_id: str) -> list[DebuffState]:
        return [
            debuff
            for debuff in match.active_debuffs
            if debuff.target_player_id == player_id and debuff.remaining_answers > 0
        ]

    def _consume_debuffs_for_player(self, match: BrainBrawlMatch, player_id: str) -> None:
        for debuff in match.active_debuffs:
            if debuff.target_player_id == player_id and debuff.remaining_answers > 0:
                debuff.remaining_answers -= 1

        match.active_debuffs = [d for d in match.active_debuffs if d.remaining_answers > 0]

    def _require_match(self, match_id: str) -> BrainBrawlMatch:
        match = self._matches.get(match_id)
        if match is None:
            raise ValueError("Match not found.")
        return match

    def _require_active_match(self, match_id: str) -> BrainBrawlMatch:
        match = self._require_match(match_id)
        if match.status != MatchStatus.ACTIVE:
            raise ValueError("Match is not active.")
        return match

    def _require_holds(self, match_id: str) -> MatchHolds:
        holds = self._holds_by_match.get(match_id)
        if holds is None:
            raise RuntimeError("Match hold state missing.")
        return holds

    @staticmethod
    def _assert_player_in_match(match: BrainBrawlMatch, player_id: str) -> None:
        if player_id not in match.players:
            raise ValueError("Player is not part of this match.")

    @staticmethod
    def _now_ms() -> int:
        return int(time.time() * 1000)
