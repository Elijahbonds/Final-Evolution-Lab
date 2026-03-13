import Foundation

struct MovementReferenceManifestEntry: Sendable {
    let exerciseId: String
    let referenceURL: String
}

struct PoseExtractionResult: Sendable {
    let keyPoseTimestamps: [Double]
    let confidence: Double
}

protocol PoseExtractionPipeline: Sendable {
    func extract(referenceURL: String, exerciseId: String) -> PoseExtractionResult?
}

struct MotionRetargetResult: Sendable {
    let motionAssetId: String
    let qualityScore: Double
}

protocol MotionRetargetingPipeline: Sendable {
    func retarget(poses: PoseExtractionResult, cloneProfile: CloneProfile, exerciseId: String) -> MotionRetargetResult?
}

struct StubPoseExtractor: PoseExtractionPipeline {
    func extract(referenceURL: String, exerciseId: String) -> PoseExtractionResult? {
        guard !referenceURL.isEmpty else { return nil }
        // Stubbed extraction for app-runtime safety. Replace with a real pipeline later.
        let keyFrames: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0].map { $0 * inferredCycleSeconds(exerciseId: exerciseId) }
        return PoseExtractionResult(
            keyPoseTimestamps: keyFrames,
            confidence: inferredConfidence(exerciseId: exerciseId)
        )
    }

    private func inferredCycleSeconds(exerciseId: String) -> Double {
        if exerciseId.hasPrefix("e") { return 1.5 }
        if exerciseId.hasPrefix("fl") { return 1.2 }
        return 1.0
    }

    private func inferredConfidence(exerciseId: String) -> Double {
        if exerciseId.hasPrefix("e") { return 0.86 }
        if exerciseId.hasPrefix("fl") { return 0.82 }
        return 0.78
    }
}

struct StubMotionRetargeter: MotionRetargetingPipeline {
    func retarget(poses: PoseExtractionResult, cloneProfile: CloneProfile, exerciseId: String) -> MotionRetargetResult? {
        guard !poses.keyPoseTimestamps.isEmpty else { return nil }
        let quality = min(0.97, max(0.60, poses.confidence + 0.05))
        return MotionRetargetResult(
            motionAssetId: "motion_\(cloneProfile.cloneId)_\(exerciseId)",
            qualityScore: quality
        )
    }
}

struct MovementIngestionService: Sendable {
    var poseExtractor: any PoseExtractionPipeline
    var motionRetargeter: any MotionRetargetingPipeline

    init(
        poseExtractor: any PoseExtractionPipeline = StubPoseExtractor(),
        motionRetargeter: any MotionRetargetingPipeline = StubMotionRetargeter()
    ) {
        self.poseExtractor = poseExtractor
        self.motionRetargeter = motionRetargeter
    }

    func legacyManifest() -> [MovementReferenceManifestEntry] {
        LegacyExerciseReferenceCatalog.referenceURLs.map { key, value in
            MovementReferenceManifestEntry(exerciseId: key, referenceURL: value)
        }
    }

    func migrateLegacyReferencesIfNeeded(
        database: MovementDatabase,
        cloneProfile: CloneProfile
    ) -> MovementDatabase {
        guard database.migrationVersion < DigitalCloneDefaults.targetMigrationVersion else {
            return database
        }
        let migrated = ingest(
            manifest: legacyManifest(),
            cloneProfile: cloneProfile,
            existing: database
        )
        var result = migrated
        result.migrationVersion = DigitalCloneDefaults.targetMigrationVersion
        return result
    }

    func ingest(
        manifest: [MovementReferenceManifestEntry],
        cloneProfile: CloneProfile,
        existing: MovementDatabase
    ) -> MovementDatabase {
        var database = existing
        let now = Date()

        for entry in manifest {
            let referenceAsset = ExerciseDemoAsset(
                id: ExerciseDemoAsset.makeId(exerciseId: entry.exerciseId, sourceType: .referenceOnly),
                exerciseId: entry.exerciseId,
                motionAssetId: "reference_\(entry.exerciseId)",
                sourceType: .referenceOnly,
                referenceURL: entry.referenceURL,
                localClipFilename: nil,
                keyPoseTimestamps: [],
                qualityScore: 0.35,
                retargetVersion: cloneProfile.retargetVersion,
                updatedAt: now
            )
            database.upsert(referenceAsset)

            guard let poseResult = poseExtractor.extract(referenceURL: entry.referenceURL, exerciseId: entry.exerciseId),
                  let retargeted = motionRetargeter.retarget(poses: poseResult, cloneProfile: cloneProfile, exerciseId: entry.exerciseId) else {
                continue
            }

            let generated = ExerciseDemoAsset(
                id: ExerciseDemoAsset.makeId(exerciseId: entry.exerciseId, sourceType: .generatedAnimation),
                exerciseId: entry.exerciseId,
                motionAssetId: retargeted.motionAssetId,
                sourceType: .generatedAnimation,
                referenceURL: entry.referenceURL,
                localClipFilename: nil,
                keyPoseTimestamps: poseResult.keyPoseTimestamps,
                qualityScore: retargeted.qualityScore,
                retargetVersion: cloneProfile.retargetVersion,
                updatedAt: now
            )
            database.upsert(generated)
        }

        database.lastIngestedAt = now
        return database
    }
}
