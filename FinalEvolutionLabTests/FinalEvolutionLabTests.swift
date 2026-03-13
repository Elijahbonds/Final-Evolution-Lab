//
//  FinalEvolutionLabTests.swift
//  FinalEvolutionLabTests
//
//  Created by Rork on March 2, 2026.
//

import Testing
@testable import FinalEvolutionLab

struct FinalEvolutionLabTests {

    @Test func bidEscrowStoresAndClearsByListing() async throws {
        var market = CreatorCardMarketplaceState()
        market.setBidEscrowAmount(listingId: "listing_a", bidderId: "u1", amount: 400)
        market.setBidEscrowAmount(listingId: "listing_a", bidderId: "u2", amount: 550)
        market.setBidEscrowAmount(listingId: "listing_b", bidderId: "u1", amount: 220)

        #expect(market.bidEscrowAmount(listingId: "listing_a", bidderId: "u1") == 400)
        #expect(market.bidEscrows(for: "listing_a").count == 2)

        let released = market.clearBidEscrows(for: "listing_a")
        #expect(released["u1"] == 400)
        #expect(released["u2"] == 550)
        #expect(market.bidEscrowAmount(listingId: "listing_a", bidderId: "u1") == 0)
        #expect(market.bidEscrowAmount(listingId: "listing_b", bidderId: "u1") == 220)
    }

    @Test func academyProgressUnlocksPrestigeAndOmni() async throws {
        var progress = AcademyProgressState.initial
        let nodeStem = KnowledgeNode(id: "stem", title: "Stem", track: .stemLogic, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil)
        let nodeHum = KnowledgeNode(id: "hum", title: "Humanities", track: .humanitiesArts, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil)
        let nodeStrat = KnowledgeNode(id: "strat", title: "Strategy", track: .strategyLeadership, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil)

        for i in 0..<20 {
            progress.unlockNode(KnowledgeNode(id: "stem_\(i)", title: nodeStem.title, track: nodeStem.track, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil))
            progress.unlockNode(KnowledgeNode(id: "hum_\(i)", title: nodeHum.title, track: nodeHum.track, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil))
            progress.unlockNode(KnowledgeNode(id: "strat_\(i)", title: nodeStrat.title, track: nodeStrat.track, shardUnlockCost: 1, prerequisiteNodeIds: [], grantsBuffKey: nil))
        }

        #expect(progress.prestigeUnlockedIds.count == 3)
        #expect(progress.omniEvolutionState.isUnlocked)
    }

    @Test func eventHubRecordsVotingOutcome() async throws {
        var hub = EventHubState()
        let outcome = LiveVotingOutcome(
            eventId: "event_1",
            closedAt: Date(),
            votesCount: 10,
            averageScore: 8.7,
            shardPotDistributed: 500,
            summary: "Voting closed"
        )
        hub.recordVotingOutcome(outcome)

        #expect(hub.voteOutcomeByEvent?["event_1"]?.votesCount == 10)
        #expect(hub.voteOutcomeByEvent?["event_1"]?.shardPotDistributed == 500)
    }

}
