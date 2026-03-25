import Foundation

/// Unreal `session_results.json` → `academy_progress` (snake_case keys from `FELSessionExport`).
nonisolated struct AcademyProgressPayload: Codable, Sendable {
    let completedModuleIds: [String]
    let evolutionShardsEarned: Int

    enum CodingKeys: String, CodingKey {
        case completedModuleIds = "completed_module_ids"
        case evolutionShardsEarned = "evolution_shards_earned"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completedModuleIds = (try c.decodeIfPresent([String].self, forKey: .completedModuleIds)) ?? []
        if let i = try c.decodeIfPresent(Int.self, forKey: .evolutionShardsEarned) {
            evolutionShardsEarned = i
        } else if let d = try c.decodeIfPresent(Double.self, forKey: .evolutionShardsEarned) {
            evolutionShardsEarned = Int(d.rounded())
        } else {
            evolutionShardsEarned = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(completedModuleIds, forKey: .completedModuleIds)
        try c.encode(evolutionShardsEarned, forKey: .evolutionShardsEarned)
    }
}

/// Nested `arena_result` from Unreal `FELSessionExport` (economy + replay flags).
nonisolated struct ArenaResultPayload: Codable, Sendable {
    let finalScore: Int
    let newPrqEstimate: Double
    let evolutionShardsEarned: Int
    let perfectTimingCount: Int
    let bestMomentReplayAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case finalScore = "final_score"
        case newPrqEstimate = "new_prq_estimate"
        case evolutionShardsEarned = "evolution_shards_earned"
        case perfectTimingCount = "perfect_timing_count"
        case bestMomentReplayAvailable = "best_moment_replay_available"
    }
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
    /// For round-based modes (golf, baseball, soccer, gymnastics, brainBrawl): number of rounds played.
    let roundsPlayed: Int?

    /// Unreal `session_results.json` optional fields (Brain Brawl / neuro bridge).
    let neuroPerformance: Double?
    let mentalSharpness: Double?
    let xpEarned: Int?
    let brainBrawlBoostCount: Int?

    /// Unreal `session_results.json` — sport-specific mastery (see `FELSportMastery` / `masteryMetric`).
    let masteryScore: Double?
    let masteryMetric: String?

    /// Unreal Lab / Academy terminal — module keys + shard grant for Swift profile merge.
    let academyProgress: AcademyProgressPayload?

    /// Unreal `arena_result` — explicit score / PRQ / shards + Perfect replay availability.
    let arenaResult: ArenaResultPayload?

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
        roundsPlayed: Int? = nil,
        neuroPerformance: Double? = nil,
        mentalSharpness: Double? = nil,
        xpEarned: Int? = nil,
        brainBrawlBoostCount: Int? = nil,
        masteryScore: Double? = nil,
        masteryMetric: String? = nil,
        academyProgress: AcademyProgressPayload? = nil,
        arenaResult: ArenaResultPayload? = nil
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
        self.roundsPlayed = roundsPlayed
        self.neuroPerformance = neuroPerformance
        self.mentalSharpness = mentalSharpness
        self.xpEarned = xpEarned
        self.brainBrawlBoostCount = brainBrawlBoostCount
        self.masteryScore = masteryScore
        self.masteryMetric = masteryMetric
        self.academyProgress = academyProgress
        self.arenaResult = arenaResult
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
        neuroPerformance = try c.decodeIfPresent(Double.self, forKey: .neuroPerformance)
        mentalSharpness = try c.decodeIfPresent(Double.self, forKey: .mentalSharpness)
        if let xi = try c.decodeIfPresent(Int.self, forKey: .xpEarned) {
            xpEarned = xi
        } else if let xd = try c.decodeIfPresent(Double.self, forKey: .xpEarned) {
            xpEarned = Int(xd.rounded())
        } else {
            xpEarned = nil
        }
        if let bi = try c.decodeIfPresent(Int.self, forKey: .brainBrawlBoostCount) {
            brainBrawlBoostCount = bi
        } else if let bd = try c.decodeIfPresent(Double.self, forKey: .brainBrawlBoostCount) {
            brainBrawlBoostCount = Int(bd.rounded())
        } else {
            brainBrawlBoostCount = nil
        }
        masteryScore = try c.decodeIfPresent(Double.self, forKey: .masteryScore)
        masteryMetric = try c.decodeIfPresent(String.self, forKey: .masteryMetric)
        academyProgress = try c.decodeIfPresent(AcademyProgressPayload.self, forKey: .academyProgress)
        arenaResult = try c.decodeIfPresent(ArenaResultPayload.self, forKey: .arenaResult)
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
        try c.encodeIfPresent(neuroPerformance, forKey: .neuroPerformance)
        try c.encodeIfPresent(mentalSharpness, forKey: .mentalSharpness)
        try c.encodeIfPresent(xpEarned, forKey: .xpEarned)
        try c.encodeIfPresent(brainBrawlBoostCount, forKey: .brainBrawlBoostCount)
        try c.encodeIfPresent(masteryScore, forKey: .masteryScore)
        try c.encodeIfPresent(masteryMetric, forKey: .masteryMetric)
        try c.encodeIfPresent(academyProgress, forKey: .academyProgress)
        try c.encodeIfPresent(arenaResult, forKey: .arenaResult)
    }

    private enum CodingKeys: String, CodingKey {
        case id, gameModeId, date, score, opponentScore, shardsEarned, prqBonus, isMultiplayer, duration, roundsPlayed
        case neuroPerformance, mentalSharpness, xpEarned, brainBrawlBoostCount
        case masteryScore, masteryMetric
        case academyProgress = "academy_progress"
        case arenaResult = "arena_result"
    }
}
