// MARK: - Spatial Stadium Gym: Territory, Teams, Brain Barriers, Live Raids

import Foundation
import CoreLocation

/// A physical venue (stadium/gym) with an optional GPS region.
nonisolated struct SpatialGym: Identifiable, Sendable {
    let id: String
    let name: String
    let venueType: VenueType
    var controllingTeamId: String?
    var lastControlFlipAt: Date?
    /// Optional center for territory / proximity
    var coordinate: CLLocationCoordinate2D?

    nonisolated enum VenueType: String, Codable, Sendable {
        case stadium
        case arena
        case court
        case popup
    }
}

nonisolated struct StadiumTeam: Identifiable, Sendable {
    let id: String
    let name: String
    let colorHex: String
    var memberIds: [String]
    var totalContribution: Int

    static let magnus = StadiumTeam(id: "team_magnus", name: "Team Magnus", colorHex: "00D4FF", memberIds: [], totalContribution: 0)
    static let jax = StadiumTeam(id: "team_jax", name: "Team Jax", colorHex: "FF6B35", memberIds: [], totalContribution: 0)
}

/// Territory control state for one gym: which team leads, contribution scores.
nonisolated struct TerritoryControl: Sendable {
    let gymId: String
    var controllingTeamId: String?
    var teamAScore: Int
    var teamBScore: Int
    var contributionByUserId: [String: Int]

    mutating func addContribution(userId: String, teamId: String, amount: Int) {
        if teamId == StadiumTeam.magnus.id { teamAScore += amount }
        else if teamId == StadiumTeam.jax.id { teamBScore += amount }
        contributionByUserId[userId, default: 0] += amount
        // Flip control when one team exceeds the other (caller can set controllingTeamId)
    }
}

/// Quiz-based "barrier" to challenge a rival gym. Study Sessions improve defense.
nonisolated struct BrainBarrier: Identifiable, Sendable {
    let id: String
    let gymId: String
    let quizSetId: String
    var difficulty: Int // 1–5
    var defenseStrength: Double // 0.0–1.0; Study Sessions can increase this
    var studySessionCount: Int
}

/// Live Raid Boss triggered by a notable in-event performance (e.g. dunk).
nonisolated struct RaidBoss: Identifiable, Sendable {
    let id: String
    let eventId: String
    let athleteId: String?
    let triggerType: RaidTriggerType
    let startedAt: Date
    let endsAt: Date
    let totalHealth: Int
    var currentHealth: Int
    var participantIds: [String]
    var isDefeated: Bool { currentHealth <= 0 }

    nonisolated enum RaidTriggerType: String, Codable, Sendable {
        case dunk
        case milestone
        case special
    }
}

nonisolated struct RaidReward: Sendable {
    let shards: Int
    let eventCardId: String?
    let participantId: String
}
