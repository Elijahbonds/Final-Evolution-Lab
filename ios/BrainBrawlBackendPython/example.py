from brain_brawl import (
    AcceptMatchInput,
    AnswerInput,
    BrainBrawlService,
    CreateMatchInput,
    PurchaseSabotageInput,
    SabotageType,
    TutorPersona,
)


def main() -> None:
    service = BrainBrawlService()

    service.seed_balance("p1", 500)
    service.seed_balance("p2", 500)

    match = service.create_match(
        CreateMatchInput(
            challenger_id="p1",
            challenge_id="logic_rapid_01",
            wager_amount=100,
            tutor=TutorPersona.MAGNUS,
        )
    )

    service.accept_match(
        AcceptMatchInput(
            match_id=match.id,
            opponent_id="p2",
            tutor=TutorPersona.ELARA,
        )
    )

    service.purchase_sabotage(
        PurchaseSabotageInput(
            match_id=match.id,
            source_player_id="p1",
            target_player_id="p2",
            type=SabotageType.TIME_WARP,
        )
    )

    service.record_answer(
        AnswerInput(
            match_id=match.id,
            player_id="p1",
            question_id="q1",
            is_correct=True,
            response_ms=1500,
            has_interaction_proof=True,
        )
    )

    service.record_answer(
        AnswerInput(
            match_id=match.id,
            player_id="p2",
            question_id="q1",
            is_correct=True,
            response_ms=5200,
            has_interaction_proof=True,
        )
    )

    finalized = service.finalize_by_score(match.id)
    print("Winner:", finalized.winner_id)
    print("P1 shards:", service.get_balance("p1"))
    print("P2 shards:", service.get_balance("p2"))


if __name__ == "__main__":
    main()
