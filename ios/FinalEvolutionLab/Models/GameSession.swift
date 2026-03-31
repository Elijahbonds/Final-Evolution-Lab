import Foundation

struct GameSessionResult: Codable, Sendable, Identifiable {
    let id: String
    let gameModeId: String
    let date: Date
    let score: Int
    let opponentScore: Int
    let shardsEarned: Int
    let prqBonus: Double
    let isMultiplayer: Bool
    let duration: Int

    var didWin: Bool { score > opponentScore }
}
