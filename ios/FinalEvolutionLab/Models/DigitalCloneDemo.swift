import Foundation

enum ExerciseDemoAssetSourceType: String, Codable, Sendable, CaseIterable {
    case referenceOnly
    case localClip
    case generatedAnimation
}

struct ExerciseDemoAsset: Codable, Sendable, Identifiable {
    let id: String
    let exerciseId: String
    var motionAssetId: String
    var sourceType: ExerciseDemoAssetSourceType
    var referenceURL: String?
    var localClipFilename: String?
    var keyPoseTimestamps: [Double]
    var qualityScore: Double
    var retargetVersion: String
    var updatedAt: Date

    static func makeId(exerciseId: String, sourceType: ExerciseDemoAssetSourceType) -> String {
        "\(exerciseId)::\(sourceType.rawValue)"
    }
}

struct CloneProfile: Codable, Sendable, Identifiable {
    let cloneId: String
    var displayName: String
    var avatarConfig: AvatarSkinConfig
    var rigType: String
    var retargetVersion: String
    var createdAt: Date

    var id: String { cloneId }

    static let generic = CloneProfile(
        cloneId: "clone_generic_athlete",
        displayName: "Generic Athlete Clone",
        avatarConfig: .default,
        rigType: "humanoid_v1",
        retargetVersion: DigitalCloneDefaults.retargetVersion,
        createdAt: Date()
    )

    static func makeDefault(from profile: UserProfile) -> CloneProfile {
        let config = profile.systemScan?.avatarConfig ?? .default
        let sanitizedName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = sanitizedName.isEmpty ? "Athlete Clone" : "\(sanitizedName) Clone"
        return CloneProfile(
            cloneId: "clone_\(profile.id)",
            displayName: display,
            avatarConfig: config,
            rigType: "humanoid_v1",
            retargetVersion: DigitalCloneDefaults.retargetVersion,
            createdAt: Date()
        )
    }
}

struct MovementDatabase: Codable, Sendable {
    var assets: [ExerciseDemoAsset] = []
    var requestedRealClipExerciseIds: Set<String> = []
    var migrationVersion: Int = 0
    var lastIngestedAt: Date?

    func assets(for exerciseId: String) -> [ExerciseDemoAsset] {
        assets.filter { $0.exerciseId == exerciseId }
    }

    func asset(for exerciseId: String, sourceType: ExerciseDemoAssetSourceType) -> ExerciseDemoAsset? {
        assets.first(where: { $0.exerciseId == exerciseId && $0.sourceType == sourceType })
    }

    func bestAsset(for exerciseId: String) -> ExerciseDemoAsset? {
        let candidates = assets(for: exerciseId)
        guard !candidates.isEmpty else { return nil }

        let priority: [ExerciseDemoAssetSourceType: Int] = [
            .generatedAnimation: 0,
            .localClip: 1,
            .referenceOnly: 2,
        ]
        return candidates.min(by: { lhs, rhs in
            let leftRank = priority[lhs.sourceType] ?? Int.max
            let rightRank = priority[rhs.sourceType] ?? Int.max
            if leftRank == rightRank {
                return lhs.qualityScore > rhs.qualityScore
            }
            return leftRank < rightRank
        })
    }

    mutating func upsert(_ asset: ExerciseDemoAsset) {
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
        } else {
            assets.append(asset)
        }
    }

    mutating func requestRealClip(for exerciseId: String) {
        requestedRealClipExerciseIds.insert(exerciseId)
    }

    mutating func clearRealClipRequest(for exerciseId: String) {
        requestedRealClipExerciseIds.remove(exerciseId)
    }
}

enum DigitalCloneDefaults {
    static let targetMigrationVersion = 1
    static let retargetVersion = "retarget_v1"
}

enum LegacyExerciseReferenceCatalog {
    // Legacy external links are retained as non-clickable metadata only.
    static let referenceURLs: [String: String] = [
        "f1": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#ScaledPogos",
        "f2": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#BoxJumps",
        "f3": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#SplitSquats",
        "f4": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#AnkleMobility",
        "f5": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#LateralShuffles",
        "fl1": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#DepthJumps",
        "fl2": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#LateralLeaps",
        "fl3": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#BulgarianSplitSquats",
        "fl4": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#HipFlexor",
        "fl5": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#ConeAgility",
        "e1": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#DunkSessions",
        "e2": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#WeightedDepthJumps",
        "e3": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#TrapBarDeadlifts",
        "e4": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#NeuralDriveSprint",
        "e5": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#RecoveryProtocol",
    ]
}
