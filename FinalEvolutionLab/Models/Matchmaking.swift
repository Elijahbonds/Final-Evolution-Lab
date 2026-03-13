import Foundation

nonisolated struct MatchmakingOpponent: Identifiable, Sendable {
    let id: String
    let displayName: String
    let athleteTag: String
    let prqScore: Double
    let tier: PRQTier
    let avatarSystemName: String
    let winRate: Double
    let totalGames: Int
}

nonisolated struct MatchmakingResult: Sendable {
    let opponent: MatchmakingOpponent
    let estimatedWaitSeconds: Int
    let matchQuality: MatchQuality
}

nonisolated enum MatchQuality: String, Sendable {
    case perfect = "PERFECT"
    case good = "GOOD"
    case fair = "FAIR"

    var color: String {
        switch self {
        case .perfect: "brandCyan"
        case .good: "brandBlue"
        case .fair: "orange"
        }
    }
}

nonisolated enum MatchmakingState: Sendable {
    case idle
    case searching(PRQTier)
    case found(MatchmakingResult)
    case failed
}

nonisolated struct CritiqueRequest: Codable, Sendable, Identifiable {
    let id: String
    let athleteId: String
    var athleteName: String = ""
    var scanId: String = ""
    let exerciseName: String
    var notes: String = ""
    let requestDate: Date
    let shardsCost: Int
    var status: CritiqueStatus
    var coachResponse: CritiqueResponse?

    var isReviewable: Bool {
        status == .completed && coachResponse != nil
    }

    // Legacy key name retained for backward compatibility with persisted data.
    var creditsCost: Int { shardsCost }
}

nonisolated enum CritiqueStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case rated
    case cancelled
    case disputed
}

nonisolated struct CritiqueResponse: Codable, Sendable {
    var coachId: String = ""
    let coachName: String
    let responseDate: Date
    let textFeedback: String
    var drawingAnnotations: [DrawingAnnotation] = []
    let overallGrade: String
    let focusAreas: [String]
}

nonisolated struct DrawingAnnotation: Codable, Sendable, Identifiable {
    var id: String = UUID().uuidString
    var points: [AnnotationPoint] = []
    var color: String = "red"
    var lineWidth: Double = 3
    var label: String?
}

nonisolated struct AnnotationPoint: Codable, Sendable {
    let x: Double
    let y: Double
}

nonisolated struct RecentMatchRecord: Identifiable, Sendable {
    let id: String
    let opponentName: String
    let opponentTier: PRQTier
    let userScore: Int
    let opponentScore: Int
    let gameMode: String
    let date: Date

    var didWin: Bool { userScore > opponentScore }
}

nonisolated enum ConnectionQuality: String, Sendable {
    case excellent = "EXCELLENT"
    case good = "GOOD"
    case moderate = "MODERATE"
    case poor = "POOR"

    var icon: String {
        switch self {
        case .excellent: "wifi"
        case .good: "wifi"
        case .moderate: "wifi.exclamationmark"
        case .poor: "wifi.slash"
        }
    }
}
