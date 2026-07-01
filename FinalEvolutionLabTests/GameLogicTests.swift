import Testing
@testable import FinalEvolutionLab

struct GameLogicTests {

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
        RorkScoreManager.shared.applyClampedPrq(50)
        EmergentRealtimeClient.applyEmergentPayload(["type": "prq_update", "prq": 150], type: "prq_update")
        #expect(RorkScoreManager.shared.currentPrqScore == 100)

        EmergentRealtimeClient.applyEmergentPayload(["type": "prq_delta", "delta": -500], type: "prq_delta")
        #expect(RorkScoreManager.shared.currentPrqScore == 0)

        EmergentRealtimeClient.applyEmergentPayload(["type": "prq_set", "value": 42], type: "prq_set")
        #expect(RorkScoreManager.shared.currentPrqScore == 42)
    }

    @Test @MainActor
    func emergentFelGameResultPreparesShareDraft() {
        SocialShareCoordinator.shared.dismissComposer()
        EmergentRealtimeClient.applyEmergentPayload(
            [
                "type": "fel_game_result",
                "gameModeId": "dunk_contest",
                "score": 88,
                "clipUrl": "https://example.com/clip.mp4",
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

    // MARK: - Shard Economy Tests

    @Test("ShardEarningRule.matchWin rewards 50 shards")
    func shardEarningRuleMatchWin() {
        #expect(ShardEarningRule.matchWin.shardReward == 50)
    }

    @Test("ShardEarningRule.matchTie rewards 25 shards")
    func shardEarningRuleMatchTie() {
        #expect(ShardEarningRule.matchTie.shardReward == 25)
    }

    @Test("ShardEarningRule.dailyStreak rewards 20 shards")
    func shardEarningRuleDailyStreak() {
        #expect(ShardEarningRule.dailyStreak.shardReward == 20)
    }

    @Test("ShardEarningRule.prqMilestone rewards 100 shards")
    func shardEarningRulePrqMilestone() {
        #expect(ShardEarningRule.prqMilestone.shardReward == 100)
    }

    @Test("ShardLedger balance equals sum of recorded entries")
    func shardLedgerBalanceIsSumOfEntries() {
        var ledger = ShardLedger()
        ledger.recordEarning(rule: .matchWin)     // 50
        ledger.recordEarning(rule: .dailyStreak)  // 20
        #expect(ledger.balance == 70)
    }

    // MARK: - Vault Slot Tests

    @Test("VaultSlotType.bronze has unlock cost of 100")
    func vaultSlotTypeBronzeUnlockCost() {
        #expect(VaultSlotType.bronze.unlockCost == 100)
    }

    @Test("VaultSlotType.platinum has cooldown of 24 hours")
    func vaultSlotTypePlatinumCooldownHours() {
        #expect(VaultSlotType.platinum.cooldownHours == 24.0)
    }

    // MARK: - Card Rarity Tests

    @Test("CardRarity.common has drop rate of 0.10")
    func cardRarityCommonDropRate() {
        #expect(CardRarity.common.dropRate == 0.10)
    }

    @Test("CardRarity.legendary has nil shardCost — non-purchasable")
    func cardRarityLegendaryShardCostIsNil() {
        #expect(CardRarity.legendary.shardCost == nil)
    }

    // MARK: - PRQTier Tests

    @Test("PRQTier.tier(for: 90) returns .elite")
    func prqTierFor90IsElite() {
        #expect(PRQTier.tier(for: 90) == .elite)
    }

    @Test("PRQTier.tier(for: 89) returns .primed")
    func prqTierFor89IsPrimed() {
        #expect(PRQTier.tier(for: 89) == .primed)
    }

    @Test("PRQTier.tier(for: 39) returns .depleted")
    func prqTierFor39IsDepleted() {
        #expect(PRQTier.tier(for: 39) == .depleted)
    }

    @Test("PRQTier.elite speedMultiplier is 1.25")
    func prqTierEliteSpeedMultiplier() {
        #expect(PRQTier.elite.speedMultiplier == 1.25)
    }

    @Test("PRQTier.depleted speedMultiplier is 0.65")
    func prqTierDepletedSpeedMultiplier() {
        #expect(PRQTier.depleted.speedMultiplier == 0.65)
    }

    // MARK: - ComboChain Tests

    @Test("ComboChain multiplier after 2 tricks is approximately 1.21 (1.1^2)")
    func comboChainMultiplierAfterTwoTricks() {
        var chain = ComboChain()
        chain.recordTrick(at: 0.0)
        chain.recordTrick(at: 1.0)
        let expected = pow(1.1, 2.0)  // 1.21
        #expect(abs(chain.multiplier - expected) < 0.0001)
    }

    @Test("ComboChain multiplier is capped at 5.0 regardless of chain length")
    func comboChainMultiplierCappedAtFive() {
        var chain = ComboChain()
        // 50 consecutive tricks well within 3s window
        for i in 0..<50 {
            chain.recordTrick(at: Double(i) * 0.5)
        }
        #expect(chain.multiplier <= 5.0)
        #expect(chain.multiplier == 5.0)
    }

    // MARK: - MovementEfficiencyScore Tests

    @Test("MovementEfficiencyScore.overallEfficiency is average of all 6 component scores")
    func movementEfficiencyScoreOverallIsAverage() {
        let score = MovementEfficiencyScore(
            kneeTracking: 80,
            hipAlignment: 90,
            coreEngagement: 70,
            shoulderPosition: 85,
            ankleStability: 75,
            headPosition: 60
        )
        let expected = (80.0 + 90.0 + 70.0 + 85.0 + 75.0 + 60.0) / 6.0
        #expect(abs(score.overallEfficiency - expected) < 0.0001)
    }

    // MARK: - MovementSnackLibrary Tests

    @Test("MovementSnackLibrary.all contains at least 12 snacks")
    func movementSnackLibraryHasAtLeast12Entries() {
        #expect(MovementSnackLibrary.all.count >= 12)
    }

    // MARK: - PeriodizationBlock Tests

    @Test("PeriodizationBlock.block(forWeek: 4) returns .deload")
    func periodizationBlockWeek4IsDeload() {
        #expect(PeriodizationBlock.block(forWeek: 4) == .deload)
    }

    @Test("PeriodizationBlock.block(forWeek: 1) returns .accumulation")
    func periodizationBlockWeek1IsAccumulation() {
        #expect(PeriodizationBlock.block(forWeek: 1) == .accumulation)
    }
}
