// GameModeId — extracted from GameMode.swift.
//
// GameMode itself needs SwiftUI (`accentColor: Color`), but GameModeId is a
// plain String enum with no UI dependency. Co-locating them made every file
// that references a mode id — ArcadePhysics among them — transitively
// SwiftUI-dependent, which put the physics core out of reach of any
// non-Apple type-check. Splitting the file is the whole fix.
//
// Xcode picks this up automatically: FinalEvolutionLab is a synchronized
// root group, so new files need no project edit.

import Foundation

nonisolated enum GameModeId: String, Codable, Sendable, CaseIterable, Identifiable {
    case basketballHeadToHead = "basketball_h2h"
    case basketballDunkContest = "basketball_dunk"
    case basketball3v3 = "basketball_3v3"
    /// IRL competitive mode: HealthKit-tracked real-world dunk contest on regulation rim
    case basketballIRL = "basketball_irl"
    case karate = "karate_h2h"
    case karateEndless = "karate_endless"
    case baseball = "baseball"
    case football = "football"
    case soccer = "soccer"
    case golf = "golf"
    case tennis = "tennis"
    case volleyball = "volleyball"
    case gymnastics = "gymnastics"
    case surfing = "surfing"
    case skateboarding = "skateboarding"
    case snowboarding = "snowboarding"
    case brainBrawl = "brain_brawl"
    case whoSceneIt = "who_scene_it"
    case courtCarnival = "court_carnival"
    case marketBrowse = "market_browse"

    var id: String { rawValue }
}
