import SwiftUI

nonisolated enum GameModeId: String, Codable, Sendable, CaseIterable, Identifiable {
    case basketballHeadToHead = "basketball_h2h"
    case basketballDunkContest = "basketball_dunk"
    case basketball3v3 = "basketball_3v3"
    /// IRL competitive mode: HealthKit-tracked real-world dunk contest on regulation rim
    case basketballIRL = "basketball_irl"
    /// Matches backend `karate_h2h` / UE Zen_Dojo
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

nonisolated enum InputScheme: String, Sendable {
    case charge
    case swipe
    case swipeGolf
    case dragTap
    case kickReturn
    case rallyAce
    case penaltyKick
    case rhythmTap
}

/// How the Nexus Engine renders this mode.
nonisolated enum RenderMode: String, Codable, Sendable {
    /// Full 3D Unreal Engine 5.7 video game — Seele + Meshy assets
    case ue3D = "3D_UE5"
    /// 2D canvas battle-of-wits (Brain Brawl) — mirrors Big Brain Academy / Triumph
    case ue2D = "2D"
    /// Real-world IRL match tracked via HealthKit PRQ scanning (no UE level required)
    case irl = "IRL"
}

extension GameModeId {
    /// Nexus Engine render mode for this game mode.
    var renderMode: RenderMode {
        switch self {
        case .brainBrawl:    return .ue2D
        case .basketballIRL: return .irl
        default:             return .ue3D
        }
    }

    /// Meshy.ai 3D asset slot identifier. Used by Seele to wire generated assets.
    var meshyAssetSlotId: String {
        "MESHY_\(rawValue)"
    }

    /// True for modes that track real-world physical performance via HealthKit.
    var isIRLMode: Bool { renderMode == .irl }

    /// True for modes rendered in Unreal Engine (3D or 2D canvas).
    var isUnrealMode: Bool { renderMode != .irl }

    /// Seele Blueprint class name for this mode.
    var nexusEngineClass: String {
        switch self {
        case .basketballHeadToHead:   return "BP_BasketballH2H"
        case .basketballDunkContest:  return "BP_BasketballDunk"
        case .basketball3v3:          return "BP_Basketball3v3"
        case .basketballIRL:          return "BP_BasketballIRL"
        case .karate:                 return "BP_KarateH2H"
        case .karateEndless:          return "BP_KarateEndless"
        case .baseball:               return "BP_Baseball"
        case .football:               return "BP_Football"
        case .soccer:                 return "BP_Soccer"
        case .golf:                   return "BP_Golf"
        case .tennis:                 return "BP_Tennis"
        case .volleyball:             return "BP_Volleyball"
        case .gymnastics:             return "BP_Gymnastics"
        case .surfing:                return "BP_Surfing"
        case .skateboarding:          return "BP_Skateboarding"
        case .snowboarding:           return "BP_Snowboarding"
        case .brainBrawl:             return "BP_BrainBrawl2D"
        case .whoSceneIt:             return "BP_WhoSceneIt"
        case .courtCarnival:          return "BP_CourtCarnival"
        case .marketBrowse:           return "BP_MarketBrowse"
        }
    }

    /// Inspirator game reference — shown on mode card and Get Ready screen.
    var inspirationTag: String {
        switch self {
        case .basketballHeadToHead:   return "NBA Street style"
        case .basketballDunkContest:  return "NBA Live 07 style"
        case .basketball3v3:          return "NBA Street style"
        case .basketballIRL:          return "IRL · HealthKit"
        case .karate:                 return "Storm × Matrix style"
        case .karateEndless:          return "Naruto Storm survival"
        case .baseball:               return "Wii Sports style"
        case .football:               return "NFL Street style"
        case .soccer:                 return "FIFA Street style"
        case .golf:                   return "Wii Sports style"
        case .tennis:                 return "Wii Resort style"
        case .volleyball:             return "Wii Resort style"
        case .gymnastics:             return "Olympics style"
        case .surfing:                return "Wii Resort style"
        case .skateboarding:          return "THPS2 style"
        case .snowboarding:           return "SSX style"
        case .brainBrawl:             return "Big Brain Academy style"
        case .whoSceneIt:             return "Scene It style"
        case .courtCarnival:          return "Mario Party style"
        case .marketBrowse:           return "Sovereign Shop"
        }
    }
}

extension GameModeId {
    var inputScheme: InputScheme {
        switch self {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3, .karate, .karateEndless:
            return .charge
        case .basketballIRL:
            return .rhythmTap
        case .baseball:
            return .swipe
        case .golf:
            return .swipeGolf
        case .volleyball, .tennis:
            return .rallyAce
        case .football:
            return .kickReturn
        case .soccer:
            return .penaltyKick
        case .gymnastics, .surfing, .skateboarding, .snowboarding, .brainBrawl, .whoSceneIt:
            return .rhythmTap
        case .courtCarnival:
            return .dragTap
        case .marketBrowse:
            return .dragTap
        }
    }
}

nonisolated struct GameMode: Sendable, Identifiable {
    let id: GameModeId
    let name: String
    let subtitle: String
    let sport: SportCategory
    let iconName: String
    let accentColor: Color
    let multiplayerType: MultiplayerType
    let environmentName: String
    let hint: String?

    nonisolated enum SportCategory: String, Sendable {
        case basketball = "Basketball"
        case combat = "Combat Sports"
        case field = "Field Sports"
        case precision = "Precision"
        case board = "Board"
        case academy = "Academy"
        case party = "Party"
        case shop = "Shop"
    }

    nonisolated enum MultiplayerType: String, Sendable {
        case realtime
        case turnBased
        case solo
    }
}

struct GameModeRegistry {
    static let all: [GameMode] = [
        GameMode(
            id: .basketballHeadToHead,
            name: "Head to Head",
            subtitle: "1v1 Shootout",
            sport: .basketball,
            iconName: "figure.basketball",
            accentColor: Color(red: 1.0, green: 0.6, blue: 0.0),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "1v1 iso — shot timing window, contest phase. NBA Street rules."
        ),
        GameMode(
            id: .basketballDunkContest,
            name: "Dunk Contest",
            subtitle: "Venice Beach Blue Court",
            sport: .basketball,
            iconName: "figure.highintensity.intervaltraining",
            accentColor: Color(red: 0, green: 0.83, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Blue Court",
            hint: "On the blue court. Select your dunk, hit the timing window, impress the judges — NBA Live 07 style."
        ),
        GameMode(
            id: .basketball3v3,
            name: "3v3 Streetball",
            subtitle: "Run the Court",
            sport: .basketball,
            iconName: "person.3.fill",
            accentColor: Color(red: 0.2, green: 0.8, blue: 0.4),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "Run the court. Three on three. Six avatars, possession, street moves — NBA Street rules."
        ),
        GameMode(
            id: .basketballIRL,
            name: "IRL Dunk Contest",
            subtitle: "Regulation Rim · HealthKit",
            sport: .basketball,
            iconName: "basketball.fill",
            accentColor: Color(red: 1.0, green: 0.4, blue: 0.1),
            multiplayerType: .realtime,
            environmentName: "Regulation Court (IRL)",
            hint: "Compete on a real 10-ft rim. HealthKit tracks your jumps, power, and heart rate."
        ),
        GameMode(
            id: .karate,
            name: "Karate · 1v1",
            subtitle: "Point Sparring",
            sport: .combat,
            iconName: "figure.martial.arts",
            accentColor: Color(red: 1.0, green: 0.2, blue: 0.2),
            multiplayerType: .realtime,
            environmentName: "Dojo Arena",
            hint: "Combo chains, block window, cinematic finishers. Storm × Matrix style."
        ),
        GameMode(
            id: .karateEndless,
            name: "Karate · Endless",
            subtitle: "Survival Waves",
            sport: .combat,
            iconName: "flame.fill",
            accentColor: Color(red: 1.0, green: 0.35, blue: 0.1),
            multiplayerType: .realtime,
            environmentName: "Dojo Arena",
            hint: "Survive the waves. Every five waves a boss. Combo or get overwhelmed."
        ),
        GameMode(
            id: .baseball,
            name: "Home Run Derby",
            subtitle: "Wii-Style Swing",
            sport: .field,
            iconName: "figure.baseball",
            accentColor: Color(red: 0.1, green: 0.5, blue: 0.9),
            multiplayerType: .turnBased,
            environmentName: "Stadium Diamond",
            hint: "Home Run Derby • Swipe or tap"
        ),
        GameMode(
            id: .football,
            name: "Kick Return",
            subtitle: "Sudden Death Breakaway",
            sport: .field,
            iconName: "football.fill",
            accentColor: Color(red: 0.5, green: 0.3, blue: 0.1),
            multiplayerType: .turnBased,
            environmentName: "Stadium Field",
            hint: "Kick Return Sudden Death"
        ),
        GameMode(
            id: .soccer,
            name: "Penalty Shootout",
            subtitle: "Swipe to Score",
            sport: .field,
            iconName: "soccerball",
            accentColor: Color(red: 0.2, green: 0.7, blue: 0.3),
            multiplayerType: .realtime,
            environmentName: "Stadium Pitch",
            hint: "Penalty Shootout • Swipe to shoot"
        ),
        GameMode(
            id: .golf,
            name: "Closest to Pin",
            subtitle: "Wii-Style Swing",
            sport: .precision,
            iconName: "figure.golf",
            accentColor: Color(red: 0.3, green: 0.7, blue: 0.4),
            multiplayerType: .turnBased,
            environmentName: "Golf Green",
            hint: "Closest to the Pin • Wii-style swipe"
        ),
        GameMode(
            id: .tennis,
            name: "Rally Ace",
            subtitle: "Serve & Volley Showdown",
            sport: .precision,
            iconName: "tennis.racket",
            accentColor: Color(red: 0.85, green: 0.75, blue: 0.1),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "Drag to aim, tap to hit. Keep the rally alive — Wii Resort style."
        ),
        GameMode(
            id: .volleyball,
            name: "Rally Ace",
            subtitle: "Drag to Aim, Spike to Win",
            sport: .field,
            iconName: "volleyball.fill",
            accentColor: Color(red: 0.98, green: 0.75, blue: 0.14),
            multiplayerType: .realtime,
            environmentName: "Beach Court",
            hint: "Rally Ace • Drag to aim"
        ),
        GameMode(
            id: .gymnastics,
            name: "Gymnastics",
            subtitle: "Olympic Routines & Tumbling",
            sport: .precision,
            iconName: "figure.gymnastics",
            accentColor: Color(red: 0.39, green: 0.4, blue: 0.95),
            multiplayerType: .turnBased,
            environmentName: "Arena",
            hint: "Rhythm tap the sequence. Nail the dismount window. Judges are watching — Olympics style."
        ),
        GameMode(
            id: .surfing,
            name: "Surfing",
            subtitle: "Line & Balance",
            sport: .board,
            iconName: "water.waves",
            accentColor: Color(red: 0.2, green: 0.75, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Surf",
            hint: "Balance the wave, chain the tricks, score the run — Wii Resort style."
        ),
        GameMode(
            id: .skateboarding,
            name: "Skateboarding",
            subtitle: "Park Lines",
            sport: .board,
            iconName: "skateboard",
            accentColor: Color(red: 0.95, green: 0.45, blue: 0.12),
            multiplayerType: .realtime,
            environmentName: "Skate Park",
            hint: "Two minutes. Score attack. Chain combos, manual into grinds — THPS2 style."
        ),
        GameMode(
            id: .snowboarding,
            name: "Snowboarding",
            subtitle: "Slope Control",
            sport: .board,
            iconName: "snowflake",
            accentColor: Color(red: 0.85, green: 0.9, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Mountain Slope",
            hint: "Hit the halfpipe, grab, spin, boost — SSX style."
        ),
        GameMode(
            id: .brainBrawl,
            name: "Brain Brawl",
            subtitle: "2D Battle of Wits",
            sport: .academy,
            iconName: "brain.head.profile",
            accentColor: Color(red: 0.55, green: 0.35, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Neuro Arena",
            hint: "2D quiz battle — Big Brain Academy × Triumph × Sports Knowledge"
        ),
        GameMode(
            id: .whoSceneIt,
            name: "Who Scene It",
            subtitle: "Sports & Entertainment Trivia",
            sport: .academy,
            iconName: "questionmark.circle.fill",
            accentColor: Color(red: 0.9, green: 0.3, blue: 0.6),
            multiplayerType: .realtime,
            environmentName: "Neuro Arena",
            hint: "Creator Card multimedia clips"
        ),
        GameMode(
            id: .courtCarnival,
            name: "Court Carnival",
            subtitle: "Board-Style Arcade Party",
            sport: .party,
            iconName: "party.popper.fill",
            accentColor: Color(red: 1.0, green: 0.5, blue: 0.0),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "Mini-games across all venues"
        ),
        GameMode(
            id: .marketBrowse,
            name: "Sovereign Shop",
            subtitle: "Browse & Purchase",
            sport: .shop,
            iconName: "storefront.fill",
            accentColor: Color(red: 0.4, green: 0.8, blue: 0.6),
            multiplayerType: .solo,
            environmentName: "Luma Venice Shop",
            hint: nil
        ),
    ]

    static func mode(for id: GameModeId) -> GameMode {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    static var sportCategories: [GameMode.SportCategory] {
        [.basketball, .combat, .field, .precision, .board, .academy, .party, .shop]
    }

    static func modes(for sport: GameMode.SportCategory) -> [GameMode] {
        all.filter { $0.sport == sport }
    }
}
