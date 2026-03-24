import Foundation

enum BlueprintSourceType: String, Codable, Sendable, CaseIterable {
    case youtube
    case localClip
    case legacyReference
}

struct BlueprintSourceAsset: Codable, Sendable, Identifiable {
    let id: String
    var sourceType: BlueprintSourceType
    var sourceURL: String
    var title: String
    var notes: String
    var importedAt: Date

    static func makeId(url: String) -> String {
        "src::\(url.lowercased())"
    }
}

struct AIVoiceProfile: Codable, Sendable {
    var displayName: String
    var localeIdentifier: String
    var toneStyle: String
    var speakingRate: Double
    var pitchMultiplier: Double

    static let bondsDefault = AIVoiceProfile(
        displayName: "Bonds Voice",
        localeIdentifier: "en-US",
        toneStyle: "confident, technical, motivating",
        speakingRate: 0.47,
        pitchMultiplier: 1.0
    )
}

struct BondsAIModelProfile: Codable, Sendable, Identifiable {
    let id: String
    var modelDisplayName: String
    var ownerDisplayName: String
    var cloneId: String
    var consentForLikeness: Bool
    var consentForVoice: Bool
    var useForFitnessEducationTracks: Bool
    var defaultNarrativeShot: NarrativeCameraShot
    var voiceProfile: AIVoiceProfile
    var createdAt: Date
    var updatedAt: Date

    static func makeId(userId: String) -> String {
        "bonds_ai_model_\(userId)"
    }
}

enum NarrativeCameraShot: String, Codable, Sendable, CaseIterable {
    case midShotTalkingHead
    case wideDemo
    case closeupOverlay
}

struct NarrativeDemoBeat: Codable, Sendable, Identifiable {
    let id: String
    var title: String
    var cameraShot: NarrativeCameraShot
    var narrationText: String
    var demoExerciseIds: [String]
    var sourceAssetIds: [String]
    var estimatedDurationSeconds: Int
}

struct BondsBlueprintProject: Codable, Sendable, Identifiable {
    let id: String
    var title: String
    var track: TrainingTrack
    var equipment: EquipmentType
    var revisionFocus: String
    var sourceAssetIds: [String]
    var beats: [NarrativeDemoBeat]
    var voiceProfile: AIVoiceProfile
    var generatedAt: Date

    static func makeId(track: TrainingTrack, generatedAt: Date = Date()) -> String {
        "bonds_project_\(track.rawValue.lowercased())_\(Int(generatedAt.timeIntervalSince1970))"
    }

    var fullNarrationScript: String {
        beats
            .enumerated()
            .map { idx, beat in
                """
                [Segment \(idx + 1): \(beat.title)]
                \(beat.narrationText)
                """
            }
            .joined(separator: "\n\n")
    }
}

struct BondsAIStudioState: Codable, Sendable {
    var modelProfile: BondsAIModelProfile?
    var sourceAssets: [BlueprintSourceAsset] = []
    var projects: [BondsBlueprintProject] = []
    var activeProjectId: String?

    var activeProject: BondsBlueprintProject? {
        guard let activeProjectId else { return nil }
        return projects.first(where: { $0.id == activeProjectId })
    }
}
