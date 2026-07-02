import Foundation

/// Authority tier for gameplay receipts — ranked PRQ and economy grants require ``serverVerified`` outside DEBUG practice (GAME-33 / Phase 5).
nonisolated enum GameSessionTrustLevel: String, Codable, Sendable {
    /// Swift fallback / practice shell — PRQ effects DEBUG-only.
    case localPractice
    /// Authenticated UE/Emergent transport without cryptographic server receipt — history OK; no ranked PRQ in Release.
    case sessionBound
    /// Backend-signed or explicitly trusted completion — may affect ranked PRQ and shard ledger policy.
    case serverVerified
}

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
    /// Deterministic gameplay seed for dunk judges / AI sim replay (GAME-29). Server-verified receipts should supersede local history.
    let verificationSeed: UInt64?
    /// Receipt authority — absent in legacy JSON decodes as ``localPractice``.
    let trustLevel: GameSessionTrustLevel

    var didWin: Bool {
        VersusMatchOutcome.playerWins(playerScore: score, opponentScore: opponentScore)
    }

    enum CodingKeys: String, CodingKey {
        case id, gameModeId, date, score, opponentScore, shardsEarned, prqBonus, isMultiplayer, duration, verificationSeed, trustLevel
    }

    init(
        id: String,
        gameModeId: String,
        date: Date,
        score: Int,
        opponentScore: Int,
        shardsEarned: Int,
        prqBonus: Double,
        isMultiplayer: Bool,
        duration: Int,
        verificationSeed: UInt64? = nil,
        trustLevel: GameSessionTrustLevel = .localPractice
    ) {
        self.id = id
        self.gameModeId = gameModeId
        self.date = date
        self.score = score
        self.opponentScore = opponentScore
        self.shardsEarned = shardsEarned
        self.prqBonus = prqBonus
        self.isMultiplayer = isMultiplayer
        self.duration = duration
        self.verificationSeed = verificationSeed
        self.trustLevel = trustLevel
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
        verificationSeed = try c.decodeIfPresent(UInt64.self, forKey: .verificationSeed)
        trustLevel = try c.decodeIfPresent(GameSessionTrustLevel.self, forKey: .trustLevel) ?? .localPractice
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
        try c.encodeIfPresent(verificationSeed, forKey: .verificationSeed)
        try c.encode(trustLevel, forKey: .trustLevel)
    }
}
