import Foundation

struct LeaderboardEntry: Codable, Sendable, Identifiable {
    let id: String
    let athleteName: String
    let athleteTag: String
    let prqScore: Double
    let evolutionShards: Int
    let rank: Int
    let avatarSystemName: String
}
