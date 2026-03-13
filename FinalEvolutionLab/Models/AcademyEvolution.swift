import Foundation

// MARK: - Academy / Education Core

enum AcademyTrack: String, Codable, Sendable, CaseIterable {
    case stemLogic = "STEM / Logic"
    case humanitiesArts = "Humanities / Arts"
    case strategyLeadership = "Strategy / Leadership"
}

enum MentorId: String, Codable, Sendable, CaseIterable {
    case magnus
    case elara
    case jax
}

struct MentorPersona: Codable, Sendable {
    let id: MentorId
    let displayName: String
    let title: String
    let focusTrack: AcademyTrack
    let accentHex: String
    let perkSummary: String

    static let magnus = MentorPersona(
        id: .magnus,
        displayName: "Magnus",
        title: "Cyborg Engineer",
        focusTrack: .stemLogic,
        accentHex: "#00D4FF",
        perkSummary: "Higher efficiency, lower evolution costs, systems optimization."
    )

    static let elara = MentorPersona(
        id: .elara,
        displayName: "Lady Elara",
        title: "Ethereal Archivist",
        focusTrack: .humanitiesArts,
        accentHex: "#F3C768",
        perkSummary: "Lore unlocks, hidden caches, adaptive hinting."
    )

    static let jax = MentorPersona(
        id: .jax,
        displayName: "Sarge Jax",
        title: "Tactical Veteran",
        focusTrack: .strategyLeadership,
        accentHex: "#B50F2A",
        perkSummary: "Leaderboard pressure, coordinated shard production, team edge."
    )

    static let all: [MentorPersona] = [.magnus, .elara, .jax]
}

struct KnowledgeNode: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let track: AcademyTrack
    let shardUnlockCost: Int
    let prerequisiteNodeIds: [String]
    let grantsBuffKey: String?
}

struct MentalCombineResult: Codable, Sendable {
    let baselineDifficulty: Int
    let reactionBandMs: ClosedRange<Int>
    let recommendedTrack: AcademyTrack
    let confidence: Double
}

// MARK: - Brain Brawl Ruleset

enum MentalDebuffType: String, Codable, Sendable, CaseIterable {
    case staticFog = "Static Fog"
    case timeWarp = "Time Warp"
    case inputScramble = "Input Scramble"
}

struct MentalDebuffRule: Codable, Sendable {
    let type: MentalDebuffType
    let shardCost: Int
    let maxDurationQuestions: Int
}

struct TutorSponsorshipRule: Codable, Sendable {
    let mentorId: MentorId
    let perkDescription: String
}

struct BrainBrawlRulebook: Codable, Sendable {
    let minimumWager: Int
    let maximumWager: Int
    let debuffs: [MentalDebuffRule]
    let sponsorships: [TutorSponsorshipRule]

    static let `default` = BrainBrawlRulebook(
        minimumWager: 25,
        maximumWager: 500,
        debuffs: [
            MentalDebuffRule(type: .staticFog, shardCost: 20, maxDurationQuestions: 3),
            MentalDebuffRule(type: .timeWarp, shardCost: 30, maxDurationQuestions: 2),
            MentalDebuffRule(type: .inputScramble, shardCost: 35, maxDurationQuestions: 2),
        ],
        sponsorships: [
            TutorSponsorshipRule(mentorId: .magnus, perkDescription: "Loss mitigation on failed rounds."),
            TutorSponsorshipRule(mentorId: .elara, perkDescription: "One adaptive hint with reduced score penalty."),
            TutorSponsorshipRule(mentorId: .jax, perkDescription: "Bonus shard yield on ranked wins."),
        ]
    )
}

// MARK: - Prestige / Endgame

enum PrestigeEvolutionId: String, Codable, Sendable, CaseIterable {
    case technomancer
    case loreWalker
    case grandStrategist
}

struct PrestigeEvolution: Codable, Sendable {
    let id: PrestigeEvolutionId
    let mentor: MentorId
    let masteryRequirementPercent: Double
    let ultimatePerk: String

    static let all: [PrestigeEvolution] = [
        PrestigeEvolution(
            id: .technomancer,
            mentor: .magnus,
            masteryRequirementPercent: 1.0,
            ultimatePerk: "Overclock: 15 minutes daily infinite cooldown windows."
        ),
        PrestigeEvolution(
            id: .loreWalker,
            mentor: .elara,
            masteryRequirementPercent: 1.0,
            ultimatePerk: "Chronicle: reveal hidden shortcuts and caches."
        ),
        PrestigeEvolution(
            id: .grandStrategist,
            mentor: .jax,
            masteryRequirementPercent: 1.0,
            ultimatePerk: "Vanguard: passive +15% shard gain for allied players."
        ),
    ]
}

struct OmniEvolutionState: Codable, Sendable {
    var stemMastery: Double
    var humanitiesMastery: Double
    var strategyMastery: Double
    var customChallengeCount: Int
    var passiveTaxShardsEarned: Int

    var isUnlocked: Bool {
        stemMastery >= 1.0 && humanitiesMastery >= 1.0 && strategyMastery >= 1.0
    }
}
