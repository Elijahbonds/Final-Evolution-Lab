import Foundation
import SceneKit
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
        #expect(out.total >= 10 && out.total <= 50)
        #expect(out.j1 + out.j2 + out.j3 >= out.total - 1)
        #expect(!out.message.isEmpty)
    }

    @Test func dunkContestCompletionRound() {
        var state = DunkContestState()
        state.totalRounds = 3
        state.round = 4
        #expect(state.isComplete)
    }

    @Test func wdaScoringIRLAndEngine3DAdapters() {
        let irl = DunkIRLScoringInput(
            jumpHeightInches: 34,
            takeoffAngleDegrees: 78,
            takeoffVelocityFps: 20,
            flightHangTimeSeconds: 0.95,
            ballRotationDegrees: 360,
            trick: .windmill,
            attemptsCount: 1,
            fluidMotionScore: 8.5,
            landingControlScore: 9.0,
            aestheticImpactScore: 8.0
        )
        let irlResult = WDAScoringEngine.shared.scoreIRLDunk(input: irl)
        #expect(irlResult.totalScore >= 20 && irlResult.totalScore <= 50)
        #expect(irlResult.isValid)

        let engine = DunkEngine3DScoringInput(
            jumpHeight: 0.82,
            launchQuality: 0.9,
            landingQuality: 0.88,
            completedRotation: 1.0,
            trick: .threeSixty,
            freestylePoints: 12,
            midAirBranchCount: 2,
            styleLandingSuccess: true,
            modifierScoreMultiplier: 1.3
        )
        let engineResult = WDAScoringEngine.shared.scoreEngine3DDunk(input: engine)
        #expect(engineResult.totalScore >= 20 && engineResult.totalScore <= 50)

        let payload = WDAScoringEngine.adaptEngine3D(
            dunkEvent: ["style": 3, "hang_time": 0.9, "timing_grade": "perfect", "points": 8],
            chargePower: 0.88
        )
        let nexusResult = WDAScoringEngine.shared.scoreEngine3DDunk(input: payload)
        #expect(nexusResult.totalScore > 0)
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

        FELScoreManager.shared.applyClampedPrq(50)
        EmergentRealtimeClient.applyEmergentPayload(
            ["type": "prq_update", "prq": 150, "game_session_id": session],
            type: "prq_update"
        )
        #expect(FELScoreManager.shared.currentPrqScore == 100)

        EmergentRealtimeClient.applyEmergentPayload(
            ["type": "prq_delta", "delta": -500, "game_session_id": session],
            type: "prq_delta"
        )
        #expect(FELScoreManager.shared.currentPrqScore == 0)

        EmergentRealtimeClient.applyEmergentPayload(
            ["type": "prq_set", "value": 42, "game_session_id": session],
            type: "prq_set"
        )
        #expect(FELScoreManager.shared.currentPrqScore == 42)
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

    @Test func scanEnvelopeCommandPlanIncludesFitnessAndFillRegion() {
        let envelope = ScanEnvelope(
            schemaVersion: 1,
            scanId: "test-scan",
            source: .simulated,
            capturedAtEpochMs: 1_700_000_000_000,
            confidence01: 0.72,
            joints: .init(
                leftKneeAngleDeg: 100,
                rightKneeAngleDeg: 104,
                leftShoulderReach01: 0.7,
                rightShoulderReach01: 0.68,
                hipStability01: 0.8
            ),
            motion: .init(
                verticalEstimateInches: 27,
                flightTimeSeconds: 0.55,
                peakAccelG: 1.2
            ),
            frcProxies: .init(mobility01: 0.7, activeRange01: 0.66, control01: 0.75)
        )

        let plan = ScanEnvelopeCommandMapper.commandPlan(for: envelope)
        guard let commands = plan["commands"] as? [[String: Any]] else {
            Issue.record("commands missing")
            return
        }
        #expect(commands.count == 3)
        let names = commands.compactMap { $0["command"] as? String }
        #expect(names.contains("fel.fitness.update"))
        #expect(names.contains("fel.creative.fill_region"))
        #expect(names.contains("fel.generate.arena_from_scan"))

        guard let generative = plan["generative"] as? [String: Any] else {
            Issue.record("generative missing")
            return
        }
        #expect((generative["arena_scale"] as? Double ?? 0) >= 0.85)
        #expect((generative["difficulty_tier"] as? Int ?? -1) >= 0)
    }

    @Test @MainActor func simulatedScanEnvelopeIsDeterministicShape() {
        let envelope = ScanCaptureService.simulatedEnvelope()
        #expect(envelope.schemaVersion == ScanEnvelope.currentSchemaVersion)
        #expect(envelope.source == .simulated)
        #expect(envelope.confidence01 < SystemScanResult.minimumConfidenceForCompetitiveCommit)
    }

    @Test func gameGeneratorAgentToolIsWhitelisted() {
        #expect(NEXUSCursorBridge.isWhitelistedAgentCommandTarget("generate_game"))
        #expect(NEXUSAgentToolName.generateGame.rawValue == "generate_game")
        let chip = NEXUSAgentToolName.quickRunChips.first { $0.tool == .generateGame }
        #expect(chip?.arguments["text"] as? String != nil)
    }

    @Test func gameGeneratorTemplatesMapToRegisteredModes() {
        #expect(NexusGameGeneratorTemplates.all.count == 18)
        for template in NexusGameGeneratorTemplates.all {
            #expect(GameModeRegistry.playableMode(forRegistryId: template.id) != nil)
        }
    }

    @Test func gameGeneratorPlayableModeResolverHandlesAliases() {
        #expect(GameModeRegistry.playableMode(forRegistryId: "venice_pickup")?.id == .basketballHeadToHead)
        #expect(GameModeRegistry.playableMode(forRegistryId: "market_browse")?.id == .marketBrowse)
        #expect(GameModeRegistry.playableMode(forRegistryId: "snowboarding")?.id == .snowboarding)
    }

    @Test func gameGeneratorReadinessMapsDifficulty() {
        #expect(GameModeRegistry.readiness(forGeneratedDifficultyTier: "easy") == 55)
        #expect(GameModeRegistry.readiness(forGeneratedDifficultyTier: "hard") == 88)
    }

    @Test func productionModeIdsMatchNexusRegistryAndValidateScript() {
        #expect(GameModeRegistry.productionModeIds.count == 19)
        let arenaIds = Set(GameModeRegistry.arenaRegistryModeIds.map(\.rawValue))
        for rawId in GameModeRegistry.productionModeIds {
            #expect(GameModeId(rawValue: rawId) != nil)
            #expect(arenaIds.contains(rawId))
            let mode = GameModeRegistry.mode(for: GameModeId(rawValue: rawId)!)
            #expect(mode.releaseState == .production)
            #expect(mode.felPreviewLabel == nil)
        }
        #expect(!GameModeRegistry.productionModeIds.contains("market_browse"))
        #expect(!GameModeRegistry.productionModeIds.contains("venice_pickup"))
    }

    @Test func productionModesHaveArcadeRetroCartridgeTitles() {
        for rawId in GameModeRegistry.productionModeIds {
            let modeId = GameModeId(rawValue: rawId)!
            let mode = GameModeRegistry.mode(for: modeId)
            let meta = ArcadeCartridgeMetadata.metadata(for: mode)
            #expect(meta.classicTitle != mode.name, "Missing retro title for \(rawId)")
            #expect(meta.isClassicProduction)
        }
    }

    @Test func dualDunkContestModesAreDistinctProductionEntries() {
        let irl = GameModeRegistry.mode(for: .basketballDunkContestIRL)
        let threeD = GameModeRegistry.mode(for: .basketballDunkContest3D)
        #expect(irl.releaseState == .production)
        #expect(threeD.releaseState == .production)
        #expect(irl.id.rawValue == "basketball_dunk_irl")
        #expect(threeD.id.rawValue == "basketball_dunk_3d")
        #expect(irl.name == "IRL H2H Dunk Contest")
        #expect(threeD.name == "3D H2H Dunk Contest")
        #expect(irl.hint?.contains("Vision") == true)
        // Hint must describe real mechanics (Metal renderer is stubbed; do not overclaim tech).
        #expect(threeD.hint?.contains("swipe timing") == true)
        #expect(threeD.id.nexusRuntimeModeId == "basketball_dunk")
        #expect(GameModeRegistry.playableMode(forRegistryId: "basketball_dunk")?.id == .basketballDunkContest3D)
    }

    @Test func irlDunkEconomyRequiresServerVerifiedReceipt() {
        #expect(GameModeId(rawValue: "basketball_irl") == nil)
        #expect(GameModeId.basketballDunkContestIRL.rawValue == "basketball_dunk_irl")
        #expect(NexusEconomyAuthority.usesServerAuthoritativeEconomy(modeId: .basketballDunkContestIRL))
        #expect(!NexusEconomyAuthority.allowsLocalEconomyGrant(modeId: .basketballDunkContestIRL, trustLevel: .sessionBound))
        #expect(!NexusEconomyAuthority.allowsLocalEconomyGrant(modeId: .basketballDunkContestIRL, trustLevel: .localPractice))
        #expect(NexusEconomyAuthority.allowsLocalEconomyGrant(modeId: .basketballDunkContestIRL, trustLevel: .serverVerified))
    }

    @Test @MainActor func irlDunkReceiptParsingKeepsRewardsLockedUntilVerified() {
        let payload: [String: Any] = [
            "game_mode_id": GameModeId.basketballDunkContestIRL.rawValue,
            "player_score": 470,
            "opponent_score": 430,
            "duration_seconds": 75,
            "shards_earned": 50,
            "prq_bonus": 3.0,
            "fel_trust_level": "session_bound",
        ]
        guard let fields = GameplaySessionReceiptCoordinator.parseReceiptFields(payload) else {
            Issue.record("IRL receipt payload failed to parse")
            return
        }
        #expect(fields.mode == .basketballDunkContestIRL)
        #expect(fields.trustLevel == .sessionBound)
        #expect(!NexusEconomyAuthority.allowsLocalEconomyGrant(modeId: fields.mode, trustLevel: fields.trustLevel))
    }

    @Test func basketballClusterWinTargetsAlignWithNexusSimulators() {
        #expect(GameModeRules.forMode(.basketballHeadToHead).targetScore == 21)
        #expect(GameModeRules.forMode(.basketball3v3).targetScore == 21)
        #expect(GameModeRules.forMode(.basketballDunkContest3D).roundLimit == 3)
        #expect(GameModeRules.forMode(.basketballDunkContestIRL).roundLimit == 3)
        let carnivalMeta = ArcadeCartridgeMetadata.metadata(for: GameModeRegistry.mode(for: .courtCarnival))
        #expect(carnivalMeta.classicTitle == "Boardwalk Bash")
        let h2hMeta = ArcadeCartridgeMetadata.metadata(for: GameModeRegistry.mode(for: .basketballHeadToHead))
        #expect(h2hMeta.classicTitle == "Venice Showdown '92")
        let pickupAliasMeta = ArcadeCartridgeMetadata.metadata(for: GameModeRegistry.mode(for: .venicePickup))
        #expect(pickupAliasMeta.classicTitle == "Venice Showdown '92")
        #expect(pickupAliasMeta.tagline.contains("Street Pickup"))
        let dunk3DMeta = ArcadeCartridgeMetadata.metadata(for: GameModeRegistry.mode(for: .basketballDunkContest3D))
        #expect(dunk3DMeta.classicTitle == "Slam Jam '94")
        let dunkIRLMeta = ArcadeCartridgeMetadata.metadata(for: GameModeRegistry.mode(for: .basketballDunkContestIRL))
        #expect(dunkIRLMeta.classicTitle == "Slam Cam '94")
        let threeMeta = ArcadeCartridgeMetadata.metadata(for: GameModeRegistry.mode(for: .basketball3v3))
        #expect(threeMeta.classicTitle == "Street Kings 3v3")
    }

    @Test func karateH2HHonestHudAndOutcomeSportRouting() {
        let mode = GameModeRegistry.mode(for: .karate)
        #expect(mode.id.nexusCapabilityTier == .sim)
        #expect(mode.id.isNexusOutcomeSportMode)
        #expect(mode.felHonestTierLabel?.hasPrefix("Practice · ") == true)
        #expect(mode.hint?.contains("Timed strikes") == true)
        let dojoMeta = ArcadeCartridgeMetadata.metadata(for: mode)
        #expect(dojoMeta.classicTitle == "Dojo Duel")
        let scene = GameSceneFactory.buildScene(for: .karate)
        #expect(scene.rootNode.childNode(withName: "fighter1", recursively: true) != nil)
        #expect(scene.rootNode.childNode(withName: "fighter2", recursively: true) != nil)
    }

    @Test func phase6SportsOutcomeHudStatusLines() {
        let baseballHud = NexusHUDSnapshot(
            modeId: "baseball",
            outcomeSportModeId: "baseball",
            outcomeSportPlayerMetric: 4,
            outcomeSportOpponentMetric: 2,
            outcomeSportInning: 3
        )
        #expect(baseballHud.outcomeSportStatusLine == "INN 3 · RUNS 4-2")

        let footballHud = NexusHUDSnapshot(
            modeId: "football",
            playerScore: 14,
            opponentScore: 7,
            outcomeSportModeId: "football",
            outcomeSportPlayerMetric: 2,
            outcomeSportOpponentMetric: 1
        )
        #expect(footballHud.outcomeSportStatusLine == "TD 2-1 · 14-7 PTS")

        let soccerHud = NexusHUDSnapshot(
            modeId: "soccer",
            outcomeSportModeId: "soccer",
            outcomeSportPlayerMetric: 3,
            outcomeSportOpponentMetric: 2,
            outcomeSportWinTarget: 5,
            outcomeSportPenaltyRound: 2
        )
        #expect(soccerHud.outcomeSportStatusLine == "PENALTY R2 · GOALS 3-2 (first to 5)")

        let golfHud = NexusHUDSnapshot(
            modeId: "golf",
            outcomeSportModeId: "golf",
            outcomeSportPlayerMetric: 18,
            outcomeSportHolesPlayed: 4,
            outcomeSportCoursePar: 36
        )
        #expect(golfHud.outcomeSportStatusLine == "HOLE 5/9 · 18/36 STROKES")

        let tennisHud = NexusHUDSnapshot(
            modeId: "tennis",
            outcomeSportModeId: "tennis",
            outcomeSportPlayerMetric: 3,
            outcomeSportOpponentMetric: 2,
            outcomeSportPlayerSets: 1,
            outcomeSportOpponentSets: 0
        )
        #expect(tennisHud.outcomeSportStatusLine == "SETS 1-0 · G 3-2")

        let volleyballHud = NexusHUDSnapshot(
            modeId: "volleyball",
            outcomeSportModeId: "volleyball",
            outcomeSportPlayerMetric: 12,
            outcomeSportOpponentMetric: 10
        )
        #expect(volleyballHud.outcomeSportStatusLine == "RALLY 12-10 (25 win by 2)")
    }

    @Test func phase6SportsUseNonChargeInputSchemes() {
        let sports: [GameModeId] = [.baseball, .football, .soccer, .golf, .tennis, .volleyball]
        for modeId in sports {
            #expect(modeId.inputScheme != .charge, "\(modeId.rawValue) must not use charge PS2 layout")
            #expect(modeId.isNexusOutcomeSportMode)
        }
    }

    @Test func productionModesRetainPrimaryAvatarInHybridOverlay() {
        for rawId in GameModeRegistry.productionModeIds {
            let modeId = GameModeId(rawValue: rawId)!
            // IRL dunk is camera-native (DunkRecordingTrackerView); it has no 3D overlay by design.
            if modeId == .basketballDunkContestIRL { continue }
            let avatarName = GameSceneFactory.primaryGameplayAvatarName(for: modeId)
            let scene = GameSceneFactory.buildGameplayOverlay(for: modeId)
            let player = scene.rootNode.childNode(withName: avatarName, recursively: true)
            #expect(player != nil, "Hybrid overlay missing \(avatarName) for \(rawId)")
            let camera = scene.rootNode.childNode(withName: "mainCamera", recursively: true)
            #expect(camera != nil, "Hybrid overlay missing chase camera for \(rawId)")
        }
    }

    @Test func previewModesExposeHonestGameplayPreviewLabels() {
        let previewModes = GameModeRegistry.all.filter { $0.releaseState == .preview }
        #expect(previewModes.contains { $0.id == .marketBrowse })
        for mode in previewModes {
            #expect(mode.felPreviewLabel?.hasPrefix("Early Access · ") == true)
        }
    }

    @Test func generatedGameSpecParsesAdapterMetadata() {
        let payload: [String: Any] = [
            "mode_id": "basketball_dunk",
            "display_name": "Dunk Contest",
            "venue_token": "Venice_Beach_Court",
            "rules": ["difficulty_tier": "hard"],
            "hud_theme": ["preview_label": "PREVIEW · GENERATED GAME SPEC"],
            "metadata": [
                "adapter": "template_mvp",
                "ai_provider": "template_mvp",
                "generator_tier": "template_ai_studio_partial",
                "ai_studio_attempted": true,
                "ai_studio_fallback_reason": "invalid mode_id from AI Studio",
                "fallback_used": true,
            ],
        ]
        let spec = NexusGameplayEngine.GeneratedGameSpec.from(payload: payload)
        #expect(spec?.adapterDisplayLabel == "Templates + AI hints")
        #expect(spec?.aiProvider == "template_mvp")
        #expect(spec?.geminiFallbackReason == "invalid mode_id from AI Studio")
        #expect(spec?.geminiAttempted == true)
        #expect(spec?.fallbackUsed == true)
        #expect(spec?.registryMode?.id == .basketballDunkContest3D)
    }

    @Test func gameGeneratorTemplatesExposeRegistryVenues() {
        for template in NexusGameGeneratorTemplates.all {
            let mode = NexusGameGeneratorTemplates.registryMode(for: template)
            #expect(mode != nil)
            #expect(!(mode?.environmentName.isEmpty ?? true))
        }
    }

    @Test func generatedGameEntryParsesSandboxJSON() {
        let json: [String: Any] = [
            "spec_id": "game_hard_basketball_dunk_1",
            "mode_id": "basketball_dunk",
            "display_name": "Hard Dunk Contest",
            "venue_token": "venice_beach",
            "rules": ["difficulty_tier": "hard"],
        ]
        let entry = NexusGeneratedGameEntry.parse(
            relativePath: "generated_games/game_hard_basketball_dunk_1.json",
            json: json
        )
        #expect(entry?.modeId == "basketball_dunk")
        #expect(entry?.difficultyTier == "hard")
        #expect(entry?.readinessEstimate == 88)
    }

    @Test func generatedGameReadinessMapsDifficultyTiers() {
        #expect(NexusGeneratedGameEntry.readiness(for: "easy") == 55)
        #expect(NexusGeneratedGameEntry.readiness(for: "normal") == 75)
        #expect(NexusGeneratedGameEntry.readiness(for: "intense") == 95)
    }

    @Test func trainingLabSocialBridgeErrorsAreHonest() {
        let firebase: TrainingLabSocialBridgeError = .firebaseNotConfigured
        #expect(firebase.errorDescription?.contains("PREVIEW") == true)

        let shards: TrainingLabSocialBridgeError = .shardIncreasesRequireServerGrant
        #expect(shards.errorDescription?.contains("server verification") == true)

        let sql: TrainingLabSocialBridgeError = .emptyDataConnectResult
        #expect(sql.errorDescription?.contains("offline") == true)

        let uid: TrainingLabSocialBridgeError = .noFirebaseUid
        #expect(uid.errorDescription?.contains("Sign in") == true)
    }

    @Test func sessionReceiptNormalizationMapsNexusDiskJson() {
        let raw: [String: Any] = [
            "telemetry": ["mode_id": "basketball_dunk", "session_id": "sess-1"],
            "player_score": 42,
            "result_type": "win",
        ]
        let body = SessionReceiptUploadService.normalizedReceiptBody(from: raw)
        #expect(body["mode_id"] as? String == "basketball_dunk")
        #expect(body["score"] as? Int == 42)
        #expect(body["outcome"] as? String == "win")
        #expect(body["completed"] as? Bool == true)
    }

    @Test func sessionReceiptLaneMatchesBackendAuthState() {
        let isPreview = NexusBackendClient.isPreviewLane
        let canPost = NexusBackendClient.canPostSessionReceipts
        let label = NexusBackendClient.sessionReceiptLaneLabel
        let snapshot = SessionReceiptUploadService.queueSnapshot()

        #expect(canPost == (!isPreview && NexusBackendClient.hasUploadAuthCredential))
        #expect(snapshot.canPost == canPost)
        #expect(snapshot.queueDirectory.contains("pending_receipts"))

        if isPreview {
            #expect(canPost == false)
            #expect(label == FELPremiumCopy.Receipt.savedLocally)
        } else if NexusBackendClient.hasUploadAuthCredential {
            #expect(canPost == true)
            #expect(label == FELPremiumCopy.Receipt.backendConnected
                        || label == FELPremiumCopy.Receipt.firebaseConnected)
        } else {
            #expect(canPost == false)
            #expect(label == FELPremiumCopy.Receipt.awaitingAuth)
        }
    }

    @Test func sessionReceiptNormalizationAddsDeviceAndAIStudioMetadata() {
        let body = SessionReceiptUploadService.normalizedReceiptBody(from: ["player_score": 7])
        let telemetry = body["telemetry"] as? [String: Any]
        #expect(telemetry?["device_id"] as? String == NexusDeviceIdentity.anonymousDeviceId)
        if NexusBackendClient.isAIStudioConfigured {
            #expect(telemetry?["ai_provider"] as? String == "ai_studio")
        }
    }

    @Test func nexusDeviceIdentityIsStable() {
        let first = NexusDeviceIdentity.anonymousDeviceId
        let second = NexusDeviceIdentity.anonymousDeviceId
        #expect(first.isEmpty == false)
        #expect(first == second)
    }

    @Test func sessionReceiptNormalizationFillsRequiredBackendFields() {
        let minimal: [String: Any] = ["player_score": 10]
        let body = SessionReceiptUploadService.normalizedReceiptBody(from: minimal)
        #expect(body["score"] as? Int == 10)
        #expect(body["outcome"] as? String == "loss")
        #expect(body["duration_seconds"] as? Int == 60)
        #expect(body["completed"] as? Bool == true)
        #expect(body["mri_score"] as? Double == 50.0)
        #expect(body["telemetry"] as? [String: Any] != nil)
    }

    @Test func sessionReceiptNormalizationCoercesUnknownOutcomeToLoss() {
        let raw: [String: Any] = ["result_type": "forfeit", "player_score": 1]
        let body = SessionReceiptUploadService.normalizedReceiptBody(from: raw)
        #expect(body["outcome"] as? String == "loss")
    }

    @Test func sessionReceiptPostOutcomeSurfacesHonestMessages() {
        let preview = NexusBackendClient.SessionReceiptPostOutcome.previewQueuedLocally
        #expect(preview.userFacingMessage.contains("PREVIEW") == true)
        #expect(preview.keepsReceiptOnDisk == true)

        let auth = NexusBackendClient.SessionReceiptPostOutcome.authUnavailable(reason: "offline")
        #expect(auth.userFacingMessage.contains("backend auth") == true)
        #expect(auth.keepsReceiptOnDisk == true)

        let server = NexusBackendClient.SessionReceiptPostOutcome.serverError(statusCode: 422, detail: "score_out_of_bounds")
        #expect(server.userFacingMessage.contains("422") == true)
        #expect(server.userFacingMessage.contains("score_out_of_bounds") == true)

        let network = NexusBackendClient.SessionReceiptPostOutcome.networkError("timeout")
        #expect(network.userFacingMessage.contains("timeout") == true)
    }

    @Test func sessionReceiptServerErrorDetailParsesFastAPIBody() {
        let detailJSON = #"{"detail":"instant_scoring_session"}"#.data(using: .utf8)!
        #expect(NexusBackendClient.serverErrorDetail(from: detailJSON) == "instant_scoring_session")

        let validationJSON = #"{"detail":[{"msg":"field required","loc":["body","mode_id"]}]}"#.data(using: .utf8)!
        let parsed = NexusBackendClient.serverErrorDetail(from: validationJSON)
        #expect(parsed.contains("field required") == true)
    }

    @Test func sessionReceiptUploadSummaryPreviewLaneIsNotFailure() {
        let previewSummary = SessionReceiptUploadService.UploadSummary(
            attempted: 3,
            succeeded: 0,
            failed: 0,
            skippedPreview: 3,
            authSkipped: 0,
            invalidJSON: 0,
            lastErrorMessage: "PREVIEW build"
        )
        #expect(previewSummary.hadFailures == false)
        #expect(previewSummary.isPreviewLane == true)
        #expect(previewSummary.pendingOnDisk == 3)
    }

    @Test @MainActor func sessionReceiptTrustLevelDefaultsSessionBound() {
        let fields = GameplaySessionReceiptCoordinator.parseReceiptFields([
            "game_mode_id": "basketball_h2h",
            "player_score": 12,
        ])
        #expect(fields?.trustLevel == .sessionBound)
        #expect(GameplaySessionReceiptCoordinator.parseTrustLevel(["fel_trust_level": "server_verified"]) == .serverVerified)
    }

    @Test func sessionReceiptProductionPathDocumentedInConfig() {
        #expect(Config.gameplaySessionReceiptURL.contains("/api/games/session") == true)
        #expect(NexusBackendClient.apiBaseURL.isEmpty == false)
    }

    @Test func aiStudioBootstrapOfflineWithoutEnvKey() {
        NexusAIStudioBootstrap.configureIfNeeded()
        // Unit test process typically has no API key unless scheme env is set.
        if NexusAIStudioBootstrap.isConfigured {
            #expect(NexusAIStudioBootstrap.apiKey()?.isEmpty == false)
            #expect(NexusAIStudioBootstrap.statusLabel.hasPrefix("Connected") == true)
        } else {
            #expect(NexusAIStudioBootstrap.connectionStatus == .offline)
            #expect(NexusAIStudioBootstrap.statusLabel == FELPremiumCopy.AIStudio.offlineStatus)
        }
    }

    @Test func firebaseOfflineBannerRequiresBothLanesOffline() {
        let firebasePreview = FirebaseBootstrap.isPreviewMode
        let aiStudioUp = NexusAIStudioBootstrap.isConfigured
        #expect(FirebaseBootstrap.shouldShowOfflineBanner == (firebasePreview && !aiStudioUp))
    }

    @Test func firebaseAndAIStudioStatusLabelsAreDistinct() {
        // Firebase lane speaks "Cloud sync"; AI Studio lane must not — and both stay distinct.
        #expect(FirebaseBootstrap.statusLabel.contains("Cloud sync") == true)
        #expect(NexusAIStudioBootstrap.statusLabel.contains("Cloud sync") == false)
        #expect(FirebaseBootstrap.statusLabel != NexusAIStudioBootstrap.statusLabel)
    }

    @Test func configDocumentsAIStudioEnvNames() {
        #expect(Config.nexusAIStudioAPIKeyEnvNames.contains("NEXUS_AI_STUDIO_API_KEY") == true)
        #expect(Config.nexusAIStudioAPIKeyEnvNames.contains("NEXUS_AGENT_GEMINI_KEY") == true)
    }

    @Test func premiumViewpointClustersMapPrimaryModeFamilies() {
        #expect(PremiumViewpointConfig.cluster(for: .basketballHeadToHead) == .basketball)
        #expect(PremiumViewpointConfig.cluster(for: .karateEndless) == .dojo)
        #expect(PremiumViewpointConfig.cluster(for: .football) == .stadium)
    }

    @Test func premiumChaseCameraUsesWideFOVNotCramped() {
        let basketball = PremiumViewpointConfig.chaseCamera(for: .basketballHeadToHead)
        let dojo = PremiumViewpointConfig.chaseCamera(for: .karate)
        let stadium = PremiumViewpointConfig.chaseCamera(for: .soccer)
        #expect(basketball.fovNormal >= 52)
        #expect(dojo.fovNormal >= 50)
        #expect(stadium.fovNormal >= 54)
        #expect(basketball.offsetZ > 9)
        #expect(stadium.offsetY > 6.5)
    }

    @Test func hybridOverlayAddsAvatarFillLight() {
        let scene = GameSceneFactory.buildGameplayOverlay(for: .basketballHeadToHead)
        let fill = scene.rootNode.childNode(withName: "avatarFillLight", recursively: false)
        #expect(fill?.light != nil)
        #expect((fill?.light?.intensity ?? 0) >= 1000)
    }

    @Test func hybridOverlayStripsProceduralVenueGeometry() {
        let scene = GameSceneFactory.buildGameplayOverlay(for: .basketballHeadToHead)
        let floorNodes = scene.rootNode.childNodes.filter { $0.geometry is SCNFloor }
        #expect(floorNodes.isEmpty, "Hybrid overlay must not retain procedural SCNFloor")
        let player = scene.rootNode.childNode(withName: "player1", recursively: true)
        #expect(player != nil)
        let ball = scene.rootNode.childNode(withName: "ball", recursively: true)
        #expect(ball != nil)
    }

    @Test func scenekitPathPrefersBundledMeshOverProcedural() {
        let scene = GameSceneFactory.buildScene(for: .karate)
        let hasBundled = scene.rootNode.childNode(withName: "bundledVenueEnvironment", recursively: false) != nil
            || scene.rootNode.childNode(withName: "bundledVenueBackdrop", recursively: false) != nil
        if hasBundled {
            let floorNodes = scene.rootNode.childNodes.filter { $0.geometry is SCNFloor }
            #expect(floorNodes.isEmpty, "Bundled mesh path should strip procedural floor")
        }
    }
}
