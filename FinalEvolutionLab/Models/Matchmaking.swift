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
}

nonisolated enum CritiqueStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case rated
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

nonisolated struct MatchmakingConfig: Sendable {
    let modeId: String
    let playersPerTeam: Int
    let teamsCount: Int
    let isSolo: Bool

    var totalPlayers: Int { playersPerTeam * teamsCount }

    // Static library of canonical runtime mode configs. Swift-only aliases are
    // normalized in config(for:) so launch cards and matchmaking agree.
    static let allConfigs: [String: MatchmakingConfig] = [
        "basketball_h2h": MatchmakingConfig(modeId: "basketball_h2h", playersPerTeam: 1, teamsCount: 2, isSolo: false),
        "basketball_dunk": MatchmakingConfig(modeId: "basketball_dunk", playersPerTeam: 1, teamsCount: 4, isSolo: false),
        "basketball_3v3": MatchmakingConfig(modeId: "basketball_3v3", playersPerTeam: 3, teamsCount: 2, isSolo: false),
        "karate_h2h": MatchmakingConfig(modeId: "karate_h2h", playersPerTeam: 1, teamsCount: 2, isSolo: false),
        "karate_endless": MatchmakingConfig(modeId: "karate_endless", playersPerTeam: 1, teamsCount: 1, isSolo: true),
        "baseball": MatchmakingConfig(modeId: "baseball", playersPerTeam: 1, teamsCount: 1, isSolo: true),
        "football": MatchmakingConfig(modeId: "football", playersPerTeam: 11, teamsCount: 2, isSolo: false),
        "soccer": MatchmakingConfig(modeId: "soccer", playersPerTeam: 5, teamsCount: 2, isSolo: false),
        "golf": MatchmakingConfig(modeId: "golf", playersPerTeam: 1, teamsCount: 1, isSolo: true),
        "tennis": MatchmakingConfig(modeId: "tennis", playersPerTeam: 2, teamsCount: 2, isSolo: false),
        "volleyball": MatchmakingConfig(modeId: "volleyball", playersPerTeam: 6, teamsCount: 2, isSolo: false),
        "surfing": MatchmakingConfig(modeId: "surfing", playersPerTeam: 1, teamsCount: 1, isSolo: true),
        "skateboarding": MatchmakingConfig(modeId: "skateboarding", playersPerTeam: 1, teamsCount: 1, isSolo: true),
        "snowboarding": MatchmakingConfig(modeId: "snowboarding", playersPerTeam: 1, teamsCount: 1, isSolo: true),
        "gymnastics": MatchmakingConfig(modeId: "gymnastics", playersPerTeam: 1, teamsCount: 1, isSolo: true),
        "brain_brawl": MatchmakingConfig(modeId: "brain_brawl", playersPerTeam: 1, teamsCount: 4, isSolo: false),
        "who_scene_it": MatchmakingConfig(modeId: "who_scene_it", playersPerTeam: 1, teamsCount: 4, isSolo: false),
        "court_carnival": MatchmakingConfig(modeId: "court_carnival", playersPerTeam: 1, teamsCount: 4, isSolo: false),
    ]

    static func config(for modeId: String) -> MatchmakingConfig? {
        allConfigs[canonicalModeId(for: modeId)]
    }

    private static func canonicalModeId(for modeId: String) -> String {
        switch modeId {
        case "venice_pickup":
            return "basketball_h2h"
        case "basketball_dunk_3d", "basketball_dunk_irl":
            return "basketball_dunk"
        default:
            return modeId
        }
    }
}

nonisolated struct MatchmakingPool: Sendable {
    let config: MatchmakingConfig
    let basePRQ: Double
    let queueTimeEstimate: TimeInterval

    var prqBracketRange: ClosedRange<Double> {
        max(0, basePRQ - 15)...min(100, basePRQ + 15)
    }

    func isEligible(playerPRQ: Double) -> Bool {
        prqBracketRange.contains(playerPRQ)
    }
}
