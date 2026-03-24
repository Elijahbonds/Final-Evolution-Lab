import Foundation

struct AcademyProgressState: Codable, Sendable {
    var selectedMentor: MentorId? = nil
    var unlockedKnowledgeNodeIds: Set<String> = []
    var masteryByTrack: [AcademyTrack: Double] = [
        .stemLogic: 0,
        .humanitiesArts: 0,
        .strategyLeadership: 0,
    ]
    var prestigeUnlockedIds: Set<PrestigeEvolutionId> = []
    var omniEvolutionState: OmniEvolutionState = OmniEvolutionState(
        stemMastery: 0,
        humanitiesMastery: 0,
        strategyMastery: 0,
        customChallengeCount: 0,
        passiveTaxShardsEarned: 0
    )
    var totalBrainBrawlMatches: Int = 0
    var totalBrainBrawlWageredShards: Int = 0
    var totalBrainBrawlWonShards: Int = 0
    var sabotageShardsSpent: Int = 0

    static let initial = AcademyProgressState()

    mutating func unlockNode(_ node: KnowledgeNode) {
        unlockedKnowledgeNodeIds.insert(node.id)
        let boost = masteryByTrack[node.track] ?? 0
        masteryByTrack[node.track] = min(1.0, boost + 0.05)
        syncOmniMastery()
        refreshPrestigeUnlocks()
    }

    mutating func applyBrainBrawlResult(track: AcademyTrack, wager: Int, didWin: Bool, sabotageCost: Int = 0) {
        let normalizedWager = max(0, wager)
        let normalizedSabotage = max(0, sabotageCost)

        totalBrainBrawlMatches += 1
        totalBrainBrawlWageredShards += normalizedWager
        sabotageShardsSpent += normalizedSabotage
        if didWin {
            totalBrainBrawlWonShards += normalizedWager
        }

        let current = masteryByTrack[track] ?? 0
        let delta = didWin ? 0.03 : 0.01
        masteryByTrack[track] = min(1.0, current + delta)
        syncOmniMastery()
        refreshPrestigeUnlocks()
    }

    mutating func addPassiveTaxShards(_ shards: Int) {
        omniEvolutionState.passiveTaxShardsEarned += max(0, shards)
    }

    private mutating func syncOmniMastery() {
        omniEvolutionState.stemMastery = masteryByTrack[.stemLogic] ?? 0
        omniEvolutionState.humanitiesMastery = masteryByTrack[.humanitiesArts] ?? 0
        omniEvolutionState.strategyMastery = masteryByTrack[.strategyLeadership] ?? 0
    }

    private mutating func refreshPrestigeUnlocks() {
        for prestige in PrestigeEvolution.all {
            let trackMastery: Double
            switch prestige.mentor {
            case .magnus:
                trackMastery = masteryByTrack[.stemLogic] ?? 0
            case .elara:
                trackMastery = masteryByTrack[.humanitiesArts] ?? 0
            case .jax:
                trackMastery = masteryByTrack[.strategyLeadership] ?? 0
            }

            if trackMastery >= prestige.masteryRequirementPercent {
                prestigeUnlockedIds.insert(prestige.id)
            }
        }
    }
}

enum AcademyKnowledgeCatalog {
    static let starterNodes: [KnowledgeNode] = [
        KnowledgeNode(
            id: "node_stem_reaction_math",
            title: "Reaction Math",
            track: .stemLogic,
            shardUnlockCost: 120,
            prerequisiteNodeIds: [],
            grantsBuffKey: "brain_brawl_reaction_window"
        ),
        KnowledgeNode(
            id: "node_humanities_pattern_story",
            title: "Pattern Storycraft",
            track: .humanitiesArts,
            shardUnlockCost: 120,
            prerequisiteNodeIds: [],
            grantsBuffKey: "adaptive_hint_discount"
        ),
        KnowledgeNode(
            id: "node_strategy_call_read",
            title: "Call & Read",
            track: .strategyLeadership,
            shardUnlockCost: 140,
            prerequisiteNodeIds: [],
            grantsBuffKey: "team_shard_bonus"
        ),
    ]
}
