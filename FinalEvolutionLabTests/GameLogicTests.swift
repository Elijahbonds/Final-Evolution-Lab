import Testing
@testable import FinalEvolutionLab

struct GameLogicTests {

    @Test func rankingPrqIsZeroOnLossWithoutParticipation() {
        let noPlay = PRQ.rankingSessionPRQ(
            mode: .basketballHeadToHead,
            won: false,
            tied: false,
            combo: 0,
            criticals: 0,
            scoreDifferential: -5,
            participationEligible: false,
            sessionReadiness: 100
        )
        #expect(noPlay == 0)
    }

    @Test func versusMatchOutcomeRewards() {
        let w = VersusMatchOutcome.rewardFlags(playerScore: 10, opponentScore: 7)
        #expect(w.won == true && w.tied == false)

        let t = VersusMatchOutcome.rewardFlags(playerScore: 5, opponentScore: 5)
        #expect(t.won == false && t.tied == true)

        let l = VersusMatchOutcome.rewardFlags(playerScore: 3, opponentScore: 9)
        #expect(l.won == false && l.tied == false)
    }

    @Test func versusWinnerSideMapsToResultFlow() {
        #expect(VersusMatchOutcome.winnerSide(playerScore: 2, opponentScore: 1) == .playerWins)
        #expect(VersusMatchOutcome.winnerSide(playerScore: 0, opponentScore: 4) == .opponentWins)
        #expect(VersusMatchOutcome.winnerSide(playerScore: 7, opponentScore: 7) == .draw)
    }

    @Test func dunkScoringDeterministicRolls() {
        var state = DunkContestState()
        state.phase = .scored
        state.selectedTrick = .tomahawk
        state.sprintCharge = 1.0
        state.launchTiming = 0.55
        state.launchGreenZone = 0.4...0.7
        state.landingTiming = 0.5
        state.landingGreenZone = 0.35...0.65
        state.rotationAmount = state.rotationTarget
        state.styleLandingSuccess = false
        state.totalFreestylePoints = 0
        state.midAirState.reset()

        let out = DunkContestScoring.calculate(
            jumpHeight: state.jumpHeight,
            launchQuality: state.launchQuality,
            landingQuality: state.landingQuality,
            completedRotation: state.completedRotation,
            selectedTrick: state.selectedTrick,
            trickHistory: state.trickHistory,
            totalFreestylePoints: state.totalFreestylePoints,
            midAirBranchCount: state.midAirState.branchCount,
            activeModifier: state.activeModifier,
            styleLandingSuccess: state.styleLandingSuccess,
            prq: 50,
            neuralBurst: false,
            judgeOffsets: (0, 0, 0)
        )
        #expect(out.j1 == out.j2 && out.j2 == out.j3)
        #expect(out.total == out.j1 * 3)
        #expect(!out.message.isEmpty)
    }

    @Test func dunkContestCompletionRound() {
        var state = DunkContestState()
        state.totalRounds = 3
        state.round = 4
        #expect(state.isComplete)
    }

    @Test func dynamicDifficultyAggressionBounds() {
        #expect(DynamicDifficulty.aggression(playerScore: 100, aiScore: 0) == DynamicDifficulty.maxAggression)
        #expect(DynamicDifficulty.aggression(playerScore: 0, aiScore: 100) == DynamicDifficulty.minAggression)
    }

    @Test func rubberBandNeutralAtEqualProgress() {
        #expect(DynamicDifficulty.rubberBandFactor(playerScore: 5, aiScore: 5, targetScore: 10) == 1.0)
    }

    @Test func prqScaledOpponentMaxPointsBasketball() {
        let low = DynamicDifficulty.prqScaledOpponentMaxPoints(playerPRQ: 0, mode: .basketballHeadToHead, maxPoints: 3)
        let high = DynamicDifficulty.prqScaledOpponentMaxPoints(playerPRQ: 100, mode: .basketballHeadToHead, maxPoints: 3)
        #expect(high >= low)
        #expect(low >= 1)
    }

    @Test @MainActor
    func emergentPayloadClampsPrq() {
        let session = "unit-test-emergent-session"
        EmergentRealtimeTrust.bindTrustedGameplaySession(id: session)
        defer { EmergentRealtimeTrust.clearTrustedGameplaySession() }

        RorkScoreManager.shared.applyClampedPrq(50)
        EmergentRealtimeClient.applyEmergentPayload(
            ["type": "prq_update", "prq": 150, "game_session_id": session],
            type: "prq_update"
        )
        #expect(RorkScoreManager.shared.currentPrqScore == 100)

        EmergentRealtimeClient.applyEmergentPayload(
            ["type": "prq_delta", "delta": -500, "game_session_id": session],
            type: "prq_delta"
        )
        #expect(RorkScoreManager.shared.currentPrqScore == 0)

        EmergentRealtimeClient.applyEmergentPayload(
            ["type": "prq_set", "value": 42, "game_session_id": session],
            type: "prq_set"
        )
        #expect(RorkScoreManager.shared.currentPrqScore == 42)
    }

    @Test @MainActor
    func emergentFelGameResultPreparesShareDraft() {
        let session = "unit-test-emergent-session-share"
        EmergentRealtimeTrust.bindTrustedGameplaySession(id: session)
        defer { EmergentRealtimeTrust.clearTrustedGameplaySession() }

        SocialShareCoordinator.shared.dismissComposer()
        EmergentRealtimeClient.applyEmergentPayload(
            [
                "type": "fel_game_result",
                "gameModeId": "dunk_contest",
                "score": 88,
                "clipUrl": "https://example.com/clip.mp4",
                "game_session_id": session,
            ],
            type: "fel_game_result"
        )
        let draft = SocialShareCoordinator.shared.composerDraft
        #expect(draft != nil)
        #expect(draft?.gameModeId == "dunk_contest")
        #expect(draft?.trainingScore == 88)
        #expect(draft?.clipUrl == "https://example.com/clip.mp4")
        SocialShareCoordinator.shared.dismissComposer()
    }
}
