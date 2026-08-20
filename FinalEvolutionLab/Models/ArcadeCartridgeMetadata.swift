import SwiftUI

/// Retro display framing for NEXUS arena modes — registry ids unchanged; copy only.
nonisolated enum ArcadeCartridgeGenre: String, Sendable, CaseIterable, Identifiable {
    case all = "ALL"
    case sport = "SPORT"
    case fight = "FIGHT"
    case brain = "BRAIN"
    case party = "PARTY"

    var id: String { rawValue }

    /// Human-readable filter chip — no internal NEXUS jargon.
    var filterLabel: String {
        switch self {
        case .all: return "All"
        case .sport: return "Sport"
        case .fight: return "Fight"
        case .brain: return "Mind"
        case .party: return "Party"
        }
    }

    var systemBadge: String { filterLabel }

    var accentColor: Color {
        switch self {
        case .all: return Theme.brandCyan
        case .sport: return Color(red: 0.2, green: 0.78, blue: 1.0)
        case .fight: return Color(red: 1.0, green: 0.42, blue: 0.28)
        case .brain: return Color(red: 0.62, green: 0.48, blue: 1.0)
        case .party: return Color(red: 1.0, green: 0.72, blue: 0.22)
        }
    }

    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .sport: return "sportscourt.fill"
        case .fight: return "figure.martial.arts"
        case .brain: return "brain.head.profile.fill"
        case .party: return "party.popper.fill"
        }
    }
}

nonisolated struct ArcadeCartridgeMetadata: Sendable {
    let modeId: GameModeId
    let classicTitle: String
    let tagline: String
    let genre: ArcadeCartridgeGenre
    let yearStamp: String

    var systemBadge: String { genre.systemBadge }

    var isClassicProduction: Bool {
        GameModeRegistry.productionModeIds.contains(modeId.rawValue)
            || modeId == .venicePickup
    }

    static func metadata(for mode: GameMode) -> ArcadeCartridgeMetadata {
        catalog[mode.id] ?? ArcadeCartridgeMetadata(
            modeId: mode.id,
            classicTitle: mode.name,
            tagline: mode.subtitle,
            genre: genre(for: mode.sport),
            yearStamp: "'24"
        )
    }

    static func genre(for sport: GameMode.SportCategory) -> ArcadeCartridgeGenre {
        switch sport {
        case .basketball, .field, .precision, .board:
            return .sport
        case .combat:
            return .fight
        case .academy:
            return .brain
        case .party:
            return .party
        }
    }

    /// Display-only classic names — keep in sync with ``GameModeRegistry.productionModeIds``.
    private static let catalog: [GameModeId: ArcadeCartridgeMetadata] = [
        .basketballHeadToHead: ArcadeCartridgeMetadata(
            modeId: .basketballHeadToHead,
            classicTitle: "Venice Showdown '92",
            tagline: "1v1 Shootout",
            genre: .sport,
            yearStamp: "'92"
        ),
        .venicePickup: ArcadeCartridgeMetadata(
            modeId: .venicePickup,
            classicTitle: "Venice Showdown '92",
            tagline: "Street Pickup · Every Catch Counts",
            genre: .sport,
            yearStamp: "'92"
        ),
        .basketballDunkContestIRL: ArcadeCartridgeMetadata(
            modeId: .basketballDunkContestIRL,
            classicTitle: "Slam Cam '94",
            tagline: "IRL H2H · Camera · WDA Judges",
            genre: .sport,
            yearStamp: "'94"
        ),
        .basketballDunkContest3D: ArcadeCartridgeMetadata(
            modeId: .basketballDunkContest3D,
            classicTitle: "Slam Jam '94",
            tagline: "3D Court · Metal H2H Showdown",
            genre: .sport,
            yearStamp: "'94"
        ),
        .basketball3v3: ArcadeCartridgeMetadata(
            modeId: .basketball3v3,
            classicTitle: "Street Kings 3v3",
            tagline: "Run the Court · Own the Block",
            genre: .sport,
            yearStamp: "'95"
        ),
        .karate: ArcadeCartridgeMetadata(
            modeId: .karate,
            classicTitle: "Dojo Duel",
            tagline: "Honor · Focus · Finish Them",
            genre: .fight,
            yearStamp: "'91"
        ),
        .karateEndless: ArcadeCartridgeMetadata(
            modeId: .karateEndless,
            classicTitle: "Dojo Breach Co-op",
            tagline: "Hold the Line · Survive the Wave",
            genre: .fight,
            yearStamp: "'96"
        ),
        .baseball: ArcadeCartridgeMetadata(
            modeId: .baseball,
            classicTitle: "Derby Night",
            tagline: "Swing for the Fences",
            genre: .sport,
            yearStamp: "'97"
        ),
        .football: ArcadeCartridgeMetadata(
            modeId: .football,
            classicTitle: "Gridiron Rush",
            tagline: "Breakaway · First to Three",
            genre: .sport,
            yearStamp: "'98"
        ),
        .soccer: ArcadeCartridgeMetadata(
            modeId: .soccer,
            classicTitle: "Penalty Wars",
            tagline: "Nerves of Steel · Top Corner Only",
            genre: .sport,
            yearStamp: "'99"
        ),
        .golf: ArcadeCartridgeMetadata(
            modeId: .golf,
            classicTitle: "Pin Hunter",
            tagline: "Read the Green · Stick the Pin",
            genre: .sport,
            yearStamp: "'00"
        ),
        .tennis: ArcadeCartridgeMetadata(
            modeId: .tennis,
            classicTitle: "Ace Rally",
            tagline: "Serve · Volley · Dominate",
            genre: .sport,
            yearStamp: "'01"
        ),
        .volleyball: ArcadeCartridgeMetadata(
            modeId: .volleyball,
            classicTitle: "Spike Beach",
            tagline: "Set · Spike · Shut Them Down",
            genre: .sport,
            yearStamp: "'02"
        ),
        .gymnastics: ArcadeCartridgeMetadata(
            modeId: .gymnastics,
            classicTitle: "Floor Master",
            tagline: "Stick the Landing · Own the Floor",
            genre: .sport,
            yearStamp: "'04"
        ),
        .surfing: ArcadeCartridgeMetadata(
            modeId: .surfing,
            classicTitle: "Wave Rider",
            tagline: "Carve · Balance · Ride Out",
            genre: .sport,
            yearStamp: "'05"
        ),
        .skateboarding: ArcadeCartridgeMetadata(
            modeId: .skateboarding,
            classicTitle: "Park Lines '99",
            tagline: "Lines · Combos · No Bails",
            genre: .sport,
            yearStamp: "'99"
        ),
        .snowboarding: ArcadeCartridgeMetadata(
            modeId: .snowboarding,
            classicTitle: "Slope Drift",
            tagline: "Carve Hard · Land Clean",
            genre: .sport,
            yearStamp: "'06"
        ),
        .brainBrawl: ArcadeCartridgeMetadata(
            modeId: .brainBrawl,
            classicTitle: "Neuro Arena",
            tagline: "Think Fast · Outsmart the Arena",
            genre: .brain,
            yearStamp: "'12"
        ),
        .whoSceneIt: ArcadeCartridgeMetadata(
            modeId: .whoSceneIt,
            classicTitle: "Scene Stealer",
            tagline: "Perform · Express · Master the Scene",
            genre: .brain,
            yearStamp: "'26"
        ),
        .courtCarnival: ArcadeCartridgeMetadata(
            modeId: .courtCarnival,
            classicTitle: "Boardwalk Bash",
            tagline: "Pads · Dice · Boardwalk Chaos",
            genre: .party,
            yearStamp: "'08"
        ),
        .marketBrowse: ArcadeCartridgeMetadata(
            modeId: .marketBrowse,
            classicTitle: "Module Shop",
            tagline: "Curated Venues · Collectibles",
            genre: .brain,
            yearStamp: "'24"
        ),
        .movementLab: ArcadeCartridgeMetadata(
            modeId: .movementLab,
            classicTitle: "Movement Lab",
            tagline: "Learn · Balance · Breathe",
            genre: .brain,
            yearStamp: "'26"
        ),
    ]
}
