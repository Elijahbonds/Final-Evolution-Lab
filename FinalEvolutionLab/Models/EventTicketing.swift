import Foundation

nonisolated enum EventTicketTier: String, Codable, Sendable, CaseIterable {
    case generalAdmission
    case vipFrontRow
    case virtual

    var displayName: String {
        switch self {
        case .generalAdmission: return "General Admission"
        case .vipFrontRow: return "VIP Front Row"
        case .virtual: return "Virtual Pass"
        }
    }
}

nonisolated enum LiveEventKind: String, Codable, Sendable {
    case dunkShow
    case teamClinic
    case fundraiser
}

nonisolated struct EventTicket: Identifiable, Codable, Sendable {
    let id: String
    let eventId: String
    let ownerUserId: String
    let tier: EventTicketTier
    let priceInCredits: Int
    let priceInShards: Int
    let shardBonusValue: Int
    let qrPayload: String
    let purchasedAt: Date
    var checkedInAt: Date?
    var referralSourceUserId: String?
    var containsGoldenTicket: Bool
}

nonisolated struct LiveEvent: Identifiable, Codable, Sendable {
    let id: String
    let kind: LiveEventKind
    let title: String
    let description: String
    let startsAt: Date
    let endsAt: Date
    let venueName: String
    let teamId: String?
    let headlinerCreatorId: String?
    let headlinerCreatorName: String?
    let isStreamEnabled: Bool
    let ticketInventoryCap: Int?
}

nonisolated struct EventTicketPricing: Codable, Sendable {
    let eventId: String
    let tier: EventTicketTier
    let priceInCredits: Int
    let priceInShards: Int
    let shardBonusValue: Int
}

nonisolated struct TeamProfile: Identifiable, Codable, Sendable {
    let id: String
    var teamName: String
    var city: String
    var memberNames: [String]
}

nonisolated enum FundraisingMilestoneRewardType: String, Codable, Sendable {
    case practiceJerseySkin
    case dunkShowUnlock
    case patronCreatorCard
}

nonisolated struct FundraisingMilestoneReward: Codable, Sendable {
    let thresholdPercent: Int
    let rewardType: FundraisingMilestoneRewardType
    let rewardId: String
    let description: String
}

nonisolated struct FundraisingGoal: Identifiable, Codable, Sendable {
    let id: String
    let teamId: String
    let title: String
    let description: String
    let goalCredits: Int
    var currentCredits: Int
    let startDate: Date
    let endDate: Date
    let milestoneRewards: [FundraisingMilestoneReward]
    var unlockedRewardIds: [String]

    var percentComplete: Int {
        guard goalCredits > 0 else { return 0 }
        return min(100, Int((Double(currentCredits) / Double(goalCredits)) * 100.0))
    }
}

nonisolated struct FundraisingContribution: Identifiable, Codable, Sendable {
    let id: String
    let goalId: String
    let teamId: String
    let contributorUserId: String
    let creditsAmount: Int
    let source: ContributionSource
    let createdAt: Date

    nonisolated enum ContributionSource: String, Codable, Sendable {
        case ticketPurchase
        case directDonation
    }
}

nonisolated struct LiveVote: Identifiable, Codable, Sendable {
    let id: String
    let eventId: String
    let voterUserId: String
    let score: Int
    let submittedAt: Date
}

nonisolated struct LiveVotingSession: Codable, Sendable {
    let eventId: String
    var isOpen: Bool
    var votes: [LiveVote]
    var participantRewardedUserIds: [String]
}

nonisolated struct EventHubState: Codable, Sendable {
    var events: [LiveEvent] = []
    var ticketPricing: [EventTicketPricing] = []
    var tickets: [EventTicket] = []
    var teams: [TeamProfile] = []
    var fundraisingGoals: [FundraisingGoal] = []
    var contributions: [FundraisingContribution] = []
    var votingSessions: [LiveVotingSession] = []
    var referralShardRewardsByUser: [String: Int] = [:]
    var participationShardRewardsByUser: [String: Int] = [:]
    var donorShardMultiplierBpsByUser: [String: Int] = [:]
    var hypeTrainCheckpointByEvent: [String: Int] = [:]
    var goldenTicketWinners: [String: String] = [:] // ticketId -> reward summary

    var voteSocketChannelByEvent: [String: String] = [:] // eventId -> simulated websocket room id

    mutating func ensureVotingSocket(for eventId: String) -> String {
        if let existing = voteSocketChannelByEvent[eventId] { return existing }
        let roomId = "vote-room-\(eventId)"
        voteSocketChannelByEvent[eventId] = roomId
        return roomId
    }

    func ticketHolders(for eventId: String) -> [String] {
        Array(Set(tickets.filter { $0.eventId == eventId }.map(\.ownerUserId)))
    }

    func userHasTicket(userId: String, eventId: String) -> Bool {
        tickets.contains { $0.ownerUserId == userId && $0.eventId == eventId }
    }

    func currentTicketSalesCount(for eventId: String) -> Int {
        tickets.filter { $0.eventId == eventId }.count
    }

    func topContributorUserId(for goalId: String) -> String? {
        let grouped = Dictionary(grouping: contributions.filter { $0.goalId == goalId }, by: \.contributorUserId)
        return grouped.max(by: { lhs, rhs in
            lhs.value.reduce(0, { $0 + $1.creditsAmount }) < rhs.value.reduce(0, { $0 + $1.creditsAmount })
        })?.key
    }
}

enum EventTicketingDefaults {
    static func qrPayload(eventId: String, ticketId: String, ownerUserId: String) -> String {
        "fel://ticket/\(eventId)/\(ticketId)?owner=\(ownerUserId)"
    }
}

enum EventTicketingSeedData {
    static func makeInitialState(now: Date = Date()) -> EventHubState {
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let weekAndHalfFromNow = Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        let twoWeeksAndBitFromNow = Calendar.current.date(byAdding: .day, value: 16, to: now) ?? now

        let team = TeamProfile(
            id: "team_rim_reapers",
            teamName: "Rim Reapers",
            city: "Phoenix",
            memberNames: ["Eli", "Nova", "Coach V"]
        )
        let goal = FundraisingGoal(
            id: "goal_rim_reapers_2026",
            teamId: team.id,
            title: "Summer Dunk Tour Bus",
            description: "Fund regional dunk showcases and school clinics.",
            goalCredits: 25_000,
            currentCredits: 0,
            startDate: now,
            endDate: twoWeeksAndBitFromNow,
            milestoneRewards: [
                FundraisingMilestoneReward(
                    thresholdPercent: 50,
                    rewardType: .practiceJerseySkin,
                    rewardId: "jersey_reapers_practice",
                    description: "Practice Jersey Skin for all team members"
                ),
                FundraisingMilestoneReward(
                    thresholdPercent: 100,
                    rewardType: .dunkShowUnlock,
                    rewardId: "unlock_local_court_show",
                    description: "Dunk Show Event unlocked at local court"
                ),
                FundraisingMilestoneReward(
                    thresholdPercent: 100,
                    rewardType: .patronCreatorCard,
                    rewardId: "patron_card_rim_reapers",
                    description: "Top donor receives Patron Creator Card multiplier"
                ),
            ],
            unlockedRewardIds: []
        )

        let showEvent = LiveEvent(
            id: "event_dunk_night_001",
            kind: .dunkShow,
            title: "Neon Flight Dunk Show",
            description: "Live dunk finals with fan-voted bonus pot.",
            startsAt: weekFromNow,
            endsAt: weekAndHalfFromNow,
            venueName: "Downtown Skycourt",
            teamId: team.id,
            headlinerCreatorId: "coach_v",
            headlinerCreatorName: "Coach V",
            isStreamEnabled: true,
            ticketInventoryCap: 5_000
        )

        let clinicEvent = LiveEvent(
            id: "event_team_clinic_001",
            kind: .teamClinic,
            title: "Elite Team Flight Clinic",
            description: "In-person jump clinic and launch mechanics workshop.",
            startsAt: twoWeeksFromNow,
            endsAt: twoWeeksAndBitFromNow,
            venueName: "Rise Performance Lab",
            teamId: team.id,
            headlinerCreatorId: "bonds_bounce",
            headlinerCreatorName: "Bonds Bounce",
            isStreamEnabled: false,
            ticketInventoryCap: 250
        )

        let pricing: [EventTicketPricing] = [
            EventTicketPricing(eventId: showEvent.id, tier: .generalAdmission, priceInCredits: 2_000, priceInShards: 0, shardBonusValue: 500),
            EventTicketPricing(eventId: showEvent.id, tier: .vipFrontRow, priceInCredits: 3_500, priceInShards: 300, shardBonusValue: 1_000),
            EventTicketPricing(eventId: showEvent.id, tier: .virtual, priceInCredits: 0, priceInShards: 600, shardBonusValue: 350),
            EventTicketPricing(eventId: clinicEvent.id, tier: .generalAdmission, priceInCredits: 1_500, priceInShards: 0, shardBonusValue: 400),
            EventTicketPricing(eventId: clinicEvent.id, tier: .vipFrontRow, priceInCredits: 2_800, priceInShards: 200, shardBonusValue: 750),
            EventTicketPricing(eventId: clinicEvent.id, tier: .virtual, priceInCredits: 0, priceInShards: 500, shardBonusValue: 300),
        ]

        return EventHubState(
            events: [showEvent, clinicEvent],
            ticketPricing: pricing,
            tickets: [],
            teams: [team],
            fundraisingGoals: [goal],
            contributions: [],
            votingSessions: [
                LiveVotingSession(eventId: showEvent.id, isOpen: false, votes: [], participantRewardedUserIds: []),
            ]
        )
    }
}
