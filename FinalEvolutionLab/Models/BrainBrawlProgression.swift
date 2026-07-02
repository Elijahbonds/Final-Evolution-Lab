import Foundation

/// Trivia Crack–style category wheel (6 topics, multi-disciplinary — not sports-only).
public enum BrainBrawlCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case science = "science"
    case sports = "sports"
    case entertainment = "entertainment"
    case geography = "geography"
    case history = "history"
    case arts = "arts"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .science: return "Science"
        case .sports: return "Sports"
        case .entertainment: return "Entertainment"
        case .geography: return "Geography"
        case .history: return "History"
        case .arts: return "Arts"
        }
    }

    public var iconName: String {
        switch self {
        case .science: return "atom"
        case .sports: return "sportscourt"
        case .entertainment: return "film"
        case .geography: return "globe.americas"
        case .history: return "building.columns"
        case .arts: return "paintpalette"
        }
    }

    public var wheelColorHex: String {
        switch self {
        case .science: return "00D4FF"
        case .sports: return "FF8C00"
        case .entertainment: return "BF5AF2"
        case .geography: return "30D158"
        case .history: return "FFD60A"
        case .arts: return "FF375F"
        }
    }

    /// Answers needed in a row within one possession to earn a crown for this category.
    public static let crownStreakTarget = 3

    /// Crowns required to win a full match (one per wheel slice).
    public static let crownsToWin = BrainBrawlCategory.allCases.count

    /// Starting lives per combatant (Trivia Crack–style pressure).
    public static let startingLives = 3
}

public struct BrainBrawlCategoryProgress: Codable, Sendable, Equatable {
    public var category: String
    public var xp: Int
    public var correct: Int
    public var total: Int
    public var bestStreak: Int
    public var crownsEarned: Int

    public init(
        category: String,
        xp: Int = 0,
        correct: Int = 0,
        total: Int = 0,
        bestStreak: Int = 0,
        crownsEarned: Int = 0
    ) {
        self.category = category
        self.xp = xp
        self.correct = correct
        self.total = total
        self.bestStreak = bestStreak
        self.crownsEarned = crownsEarned
    }

    public var level: Int {
        BrainBrawlProgression.calculateLevel(forXP: xp)
    }

    public var masteryPercent: Double {
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total)
    }
}

public struct BrainBrawlResult: Sendable, Equatable {
    public var oldLevel: Int
    public var newLevel: Int
    public var category: String
    public var crownsEarnedThisMatch: Int

    public init(oldLevel: Int, newLevel: Int, category: String, crownsEarnedThisMatch: Int = 0) {
        self.oldLevel = oldLevel
        self.newLevel = newLevel
        self.category = category
        self.crownsEarnedThisMatch = crownsEarnedThisMatch
    }
}

public struct BrainBrawlCategoryStat: Sendable, Equatable {
    public var correct: Int
    public var total: Int

    public init(correct: Int, total: Int) {
        self.correct = correct
        self.total = total
    }
}

public struct BrainBrawlMatchSummary: Sendable, Equatable {
    public var playerCrowns: Int
    public var opponentCrowns: Int
    public var playerCorrect: Int
    public var totalQuestions: Int
    public var playerWon: Bool
    public var crownsByCategory: [BrainBrawlCategory: Int]
    public var categoryStats: [BrainBrawlCategory: BrainBrawlCategoryStat]

    public init(
        playerCrowns: Int,
        opponentCrowns: Int,
        playerCorrect: Int,
        totalQuestions: Int,
        playerWon: Bool,
        crownsByCategory: [BrainBrawlCategory: Int],
        categoryStats: [BrainBrawlCategory: BrainBrawlCategoryStat] = [:]
    ) {
        self.playerCrowns = playerCrowns
        self.opponentCrowns = opponentCrowns
        self.playerCorrect = playerCorrect
        self.totalQuestions = totalQuestions
        self.playerWon = playerWon
        self.crownsByCategory = crownsByCategory
        self.categoryStats = categoryStats
    }
}

public struct BrainBrawlProgression: Codable, Sendable {
    public var totalQuestionsAnswered: Int
    public var totalCorrectAnswers: Int
    public var currentStreak: Int
    public var bestStreak: Int
    public var categoryXP: [String: Int]
    public var categoryCorrect: [String: Int]
    public var categoryTotal: [String: Int]
    public var categoryCrowns: [String: Int]
    public var totalCrownsEarned: Int
    public var matchesWon: Int
    public var matchesPlayed: Int
    public var overallXP: Int
    public var lastPlayedDate: Date?

    public init(
        totalQuestionsAnswered: Int = 0,
        totalCorrectAnswers: Int = 0,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        categoryXP: [String: Int] = [:],
        categoryCorrect: [String: Int] = [:],
        categoryTotal: [String: Int] = [:],
        categoryCrowns: [String: Int] = [:],
        totalCrownsEarned: Int = 0,
        matchesWon: Int = 0,
        matchesPlayed: Int = 0,
        overallXP: Int = 0,
        lastPlayedDate: Date? = nil
    ) {
        self.totalQuestionsAnswered = totalQuestionsAnswered
        self.totalCorrectAnswers = totalCorrectAnswers
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.categoryXP = categoryXP
        self.categoryCorrect = categoryCorrect
        self.categoryTotal = categoryTotal
        self.categoryCrowns = categoryCrowns
        self.totalCrownsEarned = totalCrownsEarned
        self.matchesWon = matchesWon
        self.matchesPlayed = matchesPlayed
        self.overallXP = overallXP
        self.lastPlayedDate = lastPlayedDate
    }

    public var overallLevel: Int {
        Self.calculateLevel(forXP: overallXP)
    }

    public static func calculateLevel(forXP xp: Int) -> Int {
        (xp / 1000) + 1
    }

    public static func xpProgress(forXP xp: Int) -> Double {
        Double(xp % 1000) / 1000.0
    }

    public func levelForCategory(_ category: BrainBrawlCategory) -> Int {
        Self.calculateLevel(forXP: categoryXP[category.rawValue] ?? 0)
    }

    public func xpProgressForCategory(_ category: BrainBrawlCategory) -> Double {
        Self.xpProgress(forXP: categoryXP[category.rawValue] ?? 0)
    }

    public func correctRatioForCategory(_ category: BrainBrawlCategory) -> Double {
        let total = categoryTotal[category.rawValue] ?? 0
        guard total > 0 else { return 0.0 }
        return Double(categoryCorrect[category.rawValue] ?? 0) / Double(total)
    }

    public func crownsForCategory(_ category: BrainBrawlCategory) -> Int {
        categoryCrowns[category.rawValue] ?? 0
    }

    public var overallCorrectRatio: Double {
        guard totalQuestionsAnswered > 0 else { return 0.0 }
        return Double(totalCorrectAnswers) / Double(totalQuestionsAnswered)
    }

    public var categoryProgress: [String: BrainBrawlCategoryProgress] {
        let merged = Set(categoryXP.keys)
            .union(categoryCorrect.keys)
            .union(categoryTotal.keys)
            .union(categoryCrowns.keys)
        return Dictionary(uniqueKeysWithValues: merged.map { key in
            (key, BrainBrawlCategoryProgress(
                category: key,
                xp: categoryXP[key] ?? 0,
                correct: categoryCorrect[key] ?? 0,
                total: categoryTotal[key] ?? 0,
                bestStreak: bestStreak,
                crownsEarned: categoryCrowns[key] ?? 0
            ))
        })
    }

    /// Records a full Trivia Crack–style H2H match outcome.
    @discardableResult
    public mutating func addMatchResult(
        summary: BrainBrawlMatchSummary,
        xpGained: Int,
        streak: Int
    ) -> BrainBrawlResult {
        let priorXP = overallXP
        let oldLevel = Self.calculateLevel(forXP: priorXP)

        totalQuestionsAnswered += summary.totalQuestions
        totalCorrectAnswers += summary.playerCorrect
        matchesPlayed += 1
        if summary.playerWon { matchesWon += 1 }

        for (category, crownCount) in summary.crownsByCategory where crownCount > 0 {
            categoryCrowns[category.rawValue, default: 0] += crownCount
            totalCrownsEarned += crownCount
        }

        for (category, stats) in summary.categoryStats {
            categoryTotal[category.rawValue, default: 0] += stats.total
            categoryCorrect[category.rawValue, default: 0] += stats.correct
            let catXP = stats.correct * 25 + (summary.crownsByCategory[category].map { $0 * 50 } ?? 0)
            categoryXP[category.rawValue, default: 0] += catXP
        }

        categoryXP["overall", default: 0] += xpGained
        overallXP += xpGained
        currentStreak = streak
        if streak > bestStreak { bestStreak = streak }
        lastPlayedDate = Date()

        let newLevel = Self.calculateLevel(forXP: overallXP)
        return BrainBrawlResult(
            oldLevel: oldLevel,
            newLevel: newLevel,
            category: "overall",
            crownsEarnedThisMatch: summary.playerCrowns
        )
    }

    /// Per-question telemetry during a match.
    public mutating func recordAnswer(category: BrainBrawlCategory, isCorrect: Bool, xpGained: Int) {
        totalQuestionsAnswered += 1
        categoryTotal[category.rawValue, default: 0] += 1

        if isCorrect {
            totalCorrectAnswers += 1
            categoryCorrect[category.rawValue, default: 0] += 1
            currentStreak += 1
            if currentStreak > bestStreak { bestStreak = currentStreak }
        } else {
            currentStreak = 0
        }

        categoryXP[category.rawValue, default: 0] += xpGained
        overallXP += xpGained
        lastPlayedDate = Date()
    }

    /// Legacy adapter for single-category drill flows.
    @discardableResult
    public mutating func addResult(
        category: String,
        xpGained: Int,
        correct: Int,
        total: Int,
        streak: Int
    ) -> BrainBrawlResult {
        let resolved = BrainBrawlCategory(rawValue: category)
            ?? Self.legacyCategoryMap[category]
            ?? .science
        let key = resolved.rawValue
        let priorXP = categoryXP[key] ?? 0
        let oldLevel = Self.calculateLevel(forXP: priorXP)

        totalQuestionsAnswered += total
        totalCorrectAnswers += correct
        categoryTotal[key, default: 0] += total
        categoryCorrect[key, default: 0] += correct
        categoryXP[key, default: 0] += xpGained
        overallXP += xpGained
        currentStreak = streak
        if streak > bestStreak { bestStreak = streak }
        lastPlayedDate = Date()

        let newLevel = Self.calculateLevel(forXP: categoryXP[key] ?? 0)
        return BrainBrawlResult(
            oldLevel: oldLevel,
            newLevel: newLevel,
            category: key,
            crownsEarnedThisMatch: 0
        )
    }

    private static let legacyCategoryMap: [String: BrainBrawlCategory] = [
        "Sports IQ": .sports,
        "sports_iq": .sports,
        "Body IQ": .science,
        "body_iq": .science,
        "STEM": .science,
        "stem": .science,
        "Common Core": .arts,
        "common_core": .arts,
        "College Prep": .history,
        "college_prep": .history,
        "Applied Kinesiology": .sports,
        "applied_kinesiology": .sports
    ]

    public static let `default` = BrainBrawlProgression()
}
