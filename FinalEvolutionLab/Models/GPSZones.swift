// MARK: - GPS-Enhanced Verticality & Fundraising (Launch Pads, Lures, Ghost Dunker Nodes)

import Foundation
import CoreLocation

nonisolated enum GPSZoneType: String, Codable, Sendable {
    case launchPad
    case lure
    case ghostDunker
}

/// Generic GPS zone for geofencing. Use subtypes for specific behavior.
nonisolated struct GPSZone: Identifiable, Sendable {
    let id: String
    let type: GPSZoneType
    let center: CLLocationCoordinate2D
    let radiusMeters: CLLocationDistance
    let name: String
    var metadata: [String: String]

    func contains(_ location: CLLocation) -> Bool {
        let zoneLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return location.distance(from: zoneLocation) <= radiusMeters
    }
}

/// Zone near a rim/court: higher jumps yield rarer Shard rewards.
nonisolated struct LaunchPadZone: Sendable {
    let zone: GPSZone
    let gymId: String?
    /// Jump height (e.g. inches or normalized 0–1) → Shard amount
    let shardRewardForJumpTier: [Int] // e.g. [10, 25, 50, 100] for tiers
}

/// Sponsor booth Lure: placed with Credits; fans in zone get high-value Shard drop (e.g. once per day).
nonisolated struct LurePlacement: Identifiable, Sendable {
    let id: String
    let sponsorId: String
    let gymId: String
    let zone: GPSZone
    let creditsSpent: Int
    let shardRewardPerVisit: Int
    let activeUntil: Date
    var visitCount: Int

    var isActive: Bool { activeUntil > Date() }
}

/// AR replay node at specific coordinates; AI Tutor engagement for rewards.
nonisolated struct GhostDunkerNode: Identifiable, Sendable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let clipId: String
    let displayName: String
    var aiTutorEnabled: Bool
    let shardRewardOnComplete: Int
}
