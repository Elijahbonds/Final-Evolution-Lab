import Foundation
import Observation

nonisolated enum PRQTier: String, Codable, Sendable, CaseIterable {
    case diamond = "DIAMOND"
    case platinum = "PLATINUM"
    case gold = "GOLD"
    case silver = "SILVER"
    case bronze = "BRONZE"
    case unranked = "UNRANKED"

    static func fromPRQ(_ prq: Double) -> PRQTier {
        switch prq {
        case 90...: .diamond
        case 75..<90: .platinum
        case 60..<75: .gold
        case 45..<60: .silver
        case 25..<45: .bronze
        default: .unranked
        }
    }

    var minPRQ: Double {
        switch self {
        case .diamond: 90
        case .platinum: 75
        case .gold: 60
        case .silver: 45
        case .bronze: 25
        case .unranked: 0
        }
    }

    var maxPRQ: Double {
        switch self {
        case .diamond: 100
        case .platinum: 90
        case .gold: 75
        case .silver: 60
        case .bronze: 45
        case .unranked: 25
        }
    }

    var displayIcon: String {
        switch self {
        case .diamond: "diamond.fill"
        case .platinum: "crown.fill"
        case .gold: "medal.fill"
        case .silver: "shield.fill"
        case .bronze: "star.fill"
        case .unranked: "questionmark.circle.fill"
        }
    }
}

@Observable
@MainActor
class GlobalLeaderboardService {
    var globalRankings: [LeaderboardEntry] = []
    var userTier: PRQTier = .unranked
    var userGlobalRank: Int = 0
    /// Sovereign server rank (e.g. Peak Z leaderboard) after a validated 40"+ Bonds Apex sync; 0 = unknown / not synced.
    var sovereignWorldRank: Int = 0
    var isLoading: Bool = false
    var matchmakingState: MatchmakingState = .idle
    var matchmakingPool: [MatchmakingOpponent] = []
    var onlinePlayerCount: Int = Int.random(in: 120...450)
    var recentMatches: [RecentMatchRecord] = []
    var connectionQuality: ConnectionQuality = .good

    /// - Parameter effectivePrq: When non-nil, use for the user's displayed PRQ and tier (e.g. with creator card boost). Keeps social display consistent with Lab/Arena.
    func refreshRankings(userProfile: UserProfile, sampleData: [LeaderboardEntry], effectivePrq: Double? = nil) {
        isLoading = true
        let displayPrq = effectivePrq ?? userProfile.metrics.prqScore
        userTier = PRQTier.fromPRQ(displayPrq)

        var combined = sampleData
        let userEntry = LeaderboardEntry(
            id: userProfile.id,
            athleteName: userProfile.displayName,
            athleteTag: userProfile.athleteTag,
            prqScore: displayPrq,
            evolutionShards: userProfile.evolutionShards,
            rank: 0,
            avatarSystemName: userProfile.avatarSystemName
        )

        if !combined.contains(where: { $0.id == userProfile.id }) {
            combined.append(userEntry)
        }

        let sorted = combined.sorted { $0.prqScore > $1.prqScore }
        globalRankings = sorted.enumerated().map { index, entry in
            LeaderboardEntry(
                id: entry.id,
                athleteName: entry.athleteName,
                athleteTag: entry.athleteTag,
                prqScore: entry.prqScore,
                evolutionShards: entry.evolutionShards,
                rank: index + 1,
                avatarSystemName: entry.avatarSystemName
            )
        }

        userGlobalRank = globalRankings.first(where: { $0.id == userProfile.id })?.rank ?? 0

        matchmakingPool = globalRankings
            .filter { $0.id != userProfile.id }
            .map { entry in
                MatchmakingOpponent(
                    id: entry.id,
                    displayName: entry.athleteName,
                    athleteTag: entry.athleteTag,
                    prqScore: entry.prqScore,
                    tier: PRQTier.fromPRQ(entry.prqScore),
                    avatarSystemName: entry.avatarSystemName,
                    winRate: Double.random(in: 0.3...0.8),
                    totalGames: Int.random(in: 5...200)
                )
            }

        isLoading = false
    }

    func findMatch(userPRQ: Double, preferredTier: PRQTier? = nil) async {
        let tier = preferredTier ?? PRQTier.fromPRQ(userPRQ)
        matchmakingState = .searching(tier)

        try? await Task.sleep(for: .seconds(Double.random(in: 1.5...3.5)))

        let candidates = matchmakingPool.filter { opponent in
            let opponentTier = PRQTier.fromPRQ(opponent.prqScore)
            let prqDiff = abs(opponent.prqScore - userPRQ)
            if let preferred = preferredTier {
                return opponentTier == preferred
            }
            return opponentTier == tier || prqDiff <= 15
        }

        guard let opponent = candidates.randomElement() ?? matchmakingPool.randomElement() else {
            matchmakingState = .failed
            return
        }

        let prqDiff = abs(opponent.prqScore - userPRQ)
        let quality: MatchQuality
        if prqDiff <= 5 {
            quality = .perfect
        } else if prqDiff <= 15 {
            quality = .good
        } else {
            quality = .fair
        }

        matchmakingState = .found(MatchmakingResult(
            opponent: opponent,
            estimatedWaitSeconds: Int.random(in: 2...8),
            matchQuality: quality
        ))
    }

    func cancelMatchmaking() {
        matchmakingState = .idle
    }

    func simulateOnlinePresence() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 8...15)))
                let delta = Int.random(in: -5...8)
                onlinePlayerCount = max(80, onlinePlayerCount + delta)
                connectionQuality = Double.random(in: 0...1) > 0.15 ? .good : .moderate
            }
        }
    }

    func recordMatch(opponent: MatchmakingOpponent, userScore: Int, opponentScore: Int, gameMode: String) {
        let record = RecentMatchRecord(
            id: UUID().uuidString,
            opponentName: opponent.displayName,
            opponentTier: opponent.tier,
            userScore: userScore,
            opponentScore: opponentScore,
            gameMode: gameMode,
            date: Date()
        )
        recentMatches.insert(record, at: 0)
        if recentMatches.count > 20 {
            recentMatches = Array(recentMatches.prefix(20))
        }
    }

    func tierProgress(for prq: Double) -> Double {
        let currentTier = PRQTier.fromPRQ(prq)
        let allTiers = PRQTier.allCases
        guard let currentIndex = allTiers.firstIndex(of: currentTier),
              currentIndex > 0 else { return 1.0 }

        let nextTier = allTiers[currentIndex - 1]
        let range = nextTier.minPRQ - currentTier.minPRQ
        guard range > 0 else { return 1.0 }

        return min(1.0, (prq - currentTier.minPRQ) / range)
    }
}
