import Foundation

nonisolated struct GameSessionResult: Codable, Sendable, Identifiable {
    let id: String
    let gameModeId: String
    let date: Date
    let score: Int
    let opponentScore: Int
    let shardsEarned: Int
    let prqBonus: Double
    let isMultiplayer: Bool
    let duration: Int
    /// For round-based modes (golf, baseball, soccer, gymnastics, brainBrawl): number of rounds played.
    let roundsPlayed: Int?

    var didWin: Bool { score > opponentScore }

    /// Display name for UI (e.g. "Head to Head", "Brain Brawl").
    var modeDisplayName: String {
        switch gameModeId {
        case "basketball_h2h": return "Head to Head"
        case "basketball_dunk": return "Dunk Contest"
        case "basketball_3v3": return "3v3 Streetball"
        case "karate": return "Karate"
        case "baseball": return "Home Run Derby"
        case "football": return "Kick Return"
        case "soccer": return "Penalty Shootout"
        case "golf": return "Closest to Pin"
        case "tennis": return "Rally Ace"
        case "volleyball": return "Rally Ace"
        case "gymnastics": return "Gymnastics"
        case "brain_brawl": return "Brain Brawl"
        default: return "Arena"
        }
    }

    /// Short result line for lists: "W 3–1" or "L 2–3".
    var scoreSummary: String {
        "\(didWin ? "W" : "L") \(score)–\(opponentScore)"
    }

    init(id: String, gameModeId: String, date: Date, score: Int, opponentScore: Int, shardsEarned: Int, prqBonus: Double, isMultiplayer: Bool, duration: Int, roundsPlayed: Int? = nil) {
        self.id = id
        self.gameModeId = gameModeId
        self.date = date
        self.score = score
        self.opponentScore = opponentScore
        self.shardsEarned = shardsEarned
        self.prqBonus = prqBonus
        self.isMultiplayer = isMultiplayer
        self.duration = duration
        self.roundsPlayed = roundsPlayed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        gameModeId = try c.decode(String.self, forKey: .gameModeId)
        date = try c.decode(Date.self, forKey: .date)
        score = try c.decode(Int.self, forKey: .score)
        opponentScore = try c.decode(Int.self, forKey: .opponentScore)
        shardsEarned = try c.decode(Int.self, forKey: .shardsEarned)
        prqBonus = try c.decode(Double.self, forKey: .prqBonus)
        isMultiplayer = try c.decode(Bool.self, forKey: .isMultiplayer)
        duration = try c.decode(Int.self, forKey: .duration)
        roundsPlayed = try c.decodeIfPresent(Int.self, forKey: .roundsPlayed)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(gameModeId, forKey: .gameModeId)
        try c.encode(date, forKey: .date)
        try c.encode(score, forKey: .score)
        try c.encode(opponentScore, forKey: .opponentScore)
        try c.encode(shardsEarned, forKey: .shardsEarned)
        try c.encode(prqBonus, forKey: .prqBonus)
        try c.encode(isMultiplayer, forKey: .isMultiplayer)
        try c.encode(duration, forKey: .duration)
        try c.encodeIfPresent(roundsPlayed, forKey: .roundsPlayed)
    }

    private enum CodingKeys: String, CodingKey {
        case id, gameModeId, date, score, opponentScore, shardsEarned, prqBonus, isMultiplayer, duration, roundsPlayed
    }
}
