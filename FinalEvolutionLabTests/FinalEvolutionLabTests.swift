//
//  FinalEvolutionLabTests.swift
//  FinalEvolutionLabTests
//
//  Created by Rork on March 2, 2026.
//

import Testing
@testable import FinalEvolutionLab

struct FinalEvolutionLabTests {

    @Test func bidEscrowStoresAndClearsByListing() async throws {
        var market = CreatorCardMarketplaceState()
        market.setBidEscrowAmount(listingId: "listing_a", bidderId: "u1", amount: 400)
        market.setBidEscrowAmount(listingId: "listing_a", bidderId: "u2", amount: 550)
        market.setBidEscrowAmount(listingId: "listing_b", bidderId: "u1", amount: 220)

        #expect(market.bidEscrowAmount(listingId: "listing_a", bidderId: "u1") == 400)
        #expect(market.bidEscrows(for: "listing_a").count == 2)

        let released = market.clearBidEscrows(for: "listing_a")
        #expect(released["u1"] == 400)
        #expect(released["u2"] == 550)
        #expect(market.bidEscrowAmount(listingId: "listing_a", bidderId: "u1") == 0)
        #expect(market.bidEscrowAmount(listingId: "listing_b", bidderId: "u1") == 220)
    }

    @Test func academyProgressUnlocksPrestigeAndOmni() async throws {
        var progress = AcademyProgressState.initial
        let nodeStem = KnowledgeNode(id: "stem", title: "Stem", track: .stemLogic, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil)
        let nodeHum = KnowledgeNode(id: "hum", title: "Humanities", track: .humanitiesArts, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil)
        let nodeStrat = KnowledgeNode(id: "strat", title: "Strategy", track: .strategyLeadership, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil)

        for i in 0..<20 {
            progress.unlockNode(KnowledgeNode(id: "stem_\(i)", title: nodeStem.title, track: nodeStem.track, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil))
            progress.unlockNode(KnowledgeNode(id: "hum_\(i)", title: nodeHum.title, track: nodeHum.track, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil))
            progress.unlockNode(KnowledgeNode(id: "strat_\(i)", title: nodeStrat.title, track: nodeStrat.track, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil))
        }

        #expect(progress.prestigeUnlockedIds.count == 3)
        #expect(progress.omniEvolutionState.isUnlocked)
    }

    @Test func eventHubRecordsVotingOutcome() async throws {
        var hub = EventHubState()
        let outcome = LiveVotingOutcome(
            eventId: "event_1",
            closedAt: Date(),
            votesCount: 10,
            averageScore: 8.7,
            shardPotDistributed: 500,
            summary: "Voting closed"
        )
        hub.recordVotingOutcome(outcome)

        #expect(hub.voteOutcomeByEvent?["event_1"]?.votesCount == 10)
        #expect(hub.voteOutcomeByEvent?["event_1"]?.shardPotDistributed == 500)
    }

    @Test func cloneProfileFallsBackToDefaultAvatarWhenNoScan() async throws {
        let clone = CloneProfile.makeDefault(from: .guest)
        #expect(clone.avatarConfig.heightScale == AvatarSkinConfig.default.heightScale)
        #expect(clone.avatarConfig.outfitStyle.rawValue == AvatarSkinConfig.default.outfitStyle.rawValue)
        #expect(clone.displayName.contains("Clone"))
    }

    @Test func movementDatabaseResolutionPrefersGeneratedThenLocalThenReference() async throws {
        var db = MovementDatabase()
        let reference = ExerciseDemoAsset(
            id: ExerciseDemoAsset.makeId(exerciseId: "f1", sourceType: .referenceOnly),
            exerciseId: "f1",
            motionAssetId: "ref_f1",
            sourceType: .referenceOnly,
            referenceURL: "https://example.com/ref",
            localClipFilename: nil,
            keyPoseTimestamps: [],
            qualityScore: 0.3,
            retargetVersion: "v1",
            updatedAt: Date()
        )
        let local = ExerciseDemoAsset(
            id: ExerciseDemoAsset.makeId(exerciseId: "f1", sourceType: .localClip),
            exerciseId: "f1",
            motionAssetId: "local_f1",
            sourceType: .localClip,
            referenceURL: nil,
            localClipFilename: "f1.mov",
            keyPoseTimestamps: [],
            qualityScore: 0.8,
            retargetVersion: "v1",
            updatedAt: Date()
        )
        let generated = ExerciseDemoAsset(
            id: ExerciseDemoAsset.makeId(exerciseId: "f1", sourceType: .generatedAnimation),
            exerciseId: "f1",
            motionAssetId: "generated_f1",
            sourceType: .generatedAnimation,
            referenceURL: nil,
            localClipFilename: nil,
            keyPoseTimestamps: [0, 0.5, 1.0],
            qualityScore: 0.9,
            retargetVersion: "v1",
            updatedAt: Date()
        )

        db.upsert(reference)
        db.upsert(local)
        db.upsert(generated)
        #expect(db.bestAsset(for: "f1")?.sourceType == .generatedAnimation)

        db.assets.removeAll(where: { $0.sourceType == .generatedAnimation })
        #expect(db.bestAsset(for: "f1")?.sourceType == .localClip)

        db.assets.removeAll(where: { $0.sourceType == .localClip })
        #expect(db.bestAsset(for: "f1")?.sourceType == .referenceOnly)
    }

    @Test func legacyDemoMigrationBuildsReferenceAndGeneratedAssets() async throws {
        let service = MovementIngestionService()
        let migrated = service.migrateLegacyReferencesIfNeeded(database: MovementDatabase(), cloneProfile: .generic)

        #expect(migrated.migrationVersion == DigitalCloneDefaults.targetMigrationVersion)
        #expect(migrated.asset(for: "f1", sourceType: .referenceOnly) != nil)
        #expect(migrated.asset(for: "f1", sourceType: .generatedAnimation) != nil)
    }

    @Test func vaultVideoResourcesAreNonClickableReferences() async throws {
        #expect(!VaultResources.videos.isEmpty)
        #expect(VaultResources.videos.allSatisfy { !$0.allowsExternalOpen })
        #expect(BlueprintLibrary.blueprints.allSatisfy { !$0.allowsExternalOpen })
    }

    @Test func systemScanBuildsMovementScreeningAndPrescription() async throws {
        let result = await SystemScanAnalysisEngine.analyze(videoURL: nil, sport: "Basketball", goal: "Jump Higher")
        #expect(result.movementScreening != nil)
        guard let screening = result.movementScreening else { return }

        #expect(screening.screenResults.count == MovementScreenKind.allCases.count)
        #expect(screening.screenResults.contains(where: { $0.kind == .fms }))
        #expect(screening.screenResults.contains(where: { $0.kind == .sfma }))
        #expect(screening.screenResults.contains(where: { $0.kind == .fcs }))
        #expect(screening.screenResults.contains(where: { $0.kind == .frc }))
        #expect(result.recommendedTrack == screening.prescription.trainingTrack.rawValue)
    }

    @Test func biomechanicsAuditUsesScreeningSignal() async throws {
        let result = await SystemScanAnalysisEngine.analyze(videoURL: nil, sport: "Soccer", goal: "Get Faster")
        let audit = BiomechanicsAudit.fromScanResult(result)

        #expect(audit.ankleDorsiflexion.value > 0)
        #expect(audit.kneeTracking.value > 0)
        #expect(audit.hipExtension.value > 0)
        #expect(audit.overallGrade == .elite || audit.overallGrade == .primed || audit.overallGrade == .developing || audit.overallGrade == .foundation)
    }

    @Test func bondsBlueprintGeneratorAcceptsYouTubeSources() async throws {
        let generator = BondsBlueprintGenerationService()
        let sources = generator.sanitizeYouTubeSources([
            "https://www.youtube.com/watch?v=abc123xyz",
            "https://youtu.be/qwe987",
            "https://example.com/not-supported"
        ])

        #expect(sources.count == 2)
        #expect(sources.allSatisfy { $0.sourceType == .youtube })
    }

    @Test func bondsBlueprintProjectBuildsMidShotNarrativeBeats() async throws {
        let generator = BondsBlueprintGenerationService()
        let model = generator.defaultModelProfile(from: .guest, cloneProfile: .generic)
        let project = generator.createProject(
            track: .foundations,
            equipment: .movementEducation,
            model: model,
            sourceAssets: [],
            revisionFocus: "landing mechanics and pacing"
        )

        #expect(project.track == .foundations)
        #expect(!project.beats.isEmpty)
        #expect(project.beats.first?.cameraShot == .midShotTalkingHead)
        #expect(project.fullNarrationScript.contains("landing mechanics and pacing"))
    }

}
