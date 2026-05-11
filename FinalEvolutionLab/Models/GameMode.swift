import SwiftUI

nonisolated enum GameModeId: String, Codable, Sendable, CaseIterable, Identifiable {
    case basketballHeadToHead = "basketball_h2h"
    case basketballDunkContest = "basketball_dunk"
    case basketball3v3 = "basketball_3v3"
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
    /// Matches ``ArenaSettings.json`` / ``FEL_ModeManager.production.json`` (`BP_WhoSceneIt`).
    case whoSceneIt = "who_scene_it"
    /// Venice mini-game mash-up — matches UE ``BP_PartyMode`` / ``court_carnival``.
    case courtCarnival = "court_carnival"

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
    /// Recognition / clip prompts — distinct UX from generic rhythm academy loops.
    case filmQuiz
    /// Board-and-space carnival loop — distinct UX from extreme sports rhythm.
    case partyBoard
}

extension GameModeId {
    var inputScheme: InputScheme {
        switch self {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3, .karate, .karateEndless:
            return .charge
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
        case .gymnastics, .surfing, .skateboarding, .snowboarding, .brainBrawl:
            return .rhythmTap
        case .whoSceneIt:
            return .filmQuiz
        case .courtCarnival:
            return .partyBoard
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
    }

    nonisolated enum MultiplayerType: String, Sendable {
        case realtime
        case turnBased
        case solo
    }

    nonisolated enum ReleaseState: String, Sendable {
        case production
        case preview
    }

    let releaseState: ReleaseState

    init(
        id: GameModeId,
        name: String,
        subtitle: String,
        sport: SportCategory,
        iconName: String,
        accentColor: Color,
        multiplayerType: MultiplayerType,
        environmentName: String,
        hint: String?,
        releaseState: ReleaseState = .production
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.sport = sport
        self.iconName = iconName
        self.accentColor = accentColor
        self.multiplayerType = multiplayerType
        self.environmentName = environmentName
        self.hint = hint
        self.releaseState = releaseState
    }
}

struct GameModeRegistry {
    /// Modes shown in Arena navigation for the current build (preview modes hidden in App Store unless ``Config.showPreviewGameModes``).
    static var shippingModes: [GameMode] {
        if Config.showPreviewGameModes {
            return all
        }
        return all.filter { $0.releaseState == .production }
    }

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
            hint: nil
        ),
        GameMode(
            id: .basketballDunkContest,
            name: "Dunk Contest",
            subtitle: "Venice Beach Showdown",
            sport: .basketball,
            iconName: "figure.highintensity.intervaltraining",
            accentColor: Color(red: 0, green: 0.83, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: nil
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
            hint: nil
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
            hint: nil
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
            hint: nil
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
            hint: nil
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
            hint: nil
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
            hint: nil
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
            hint: nil
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
            hint: nil
        ),
        GameMode(
            id: .brainBrawl,
            name: "Brain Brawl",
            subtitle: "Cognitive Arena",
            sport: .academy,
            iconName: "brain.head.profile",
            accentColor: Color(red: 0.55, green: 0.35, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Neuro Arena",
            hint: nil
        ),
        GameMode(
            id: .whoSceneIt,
            name: "Who Scene It",
            subtitle: "Neuro Arena (Preview)",
            sport: .academy,
            iconName: "theatermasks.fill",
            accentColor: Color(red: 0.45, green: 0.55, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Neuro Arena",
            hint: "Placeholder — matches ArenaSettings / production map",
            releaseState: .preview
        ),
        GameMode(
            id: .courtCarnival,
            name: "Court Carnival",
            subtitle: "Mini-game mash-up · Venice Beach",
            sport: .party,
            iconName: "sparkles.rectangle.stack",
            accentColor: Color(red: 1.0, green: 0.45, blue: 0.65),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "Rotating challenges — matches ArenaSettings / production map"
        ),
    ]

    static func mode(for id: GameModeId) -> GameMode {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    /// Uses ``SaveSystem/loadLastSelectedArenaModeId()`` so Global Arena matchmaking matches an explicit grid selection (GAME-35).
    static func resolvedLastSelectedMode() -> GameMode? {
        guard let raw = SaveSystem.loadLastSelectedArenaModeId(),
              let id = GameModeId(rawValue: raw) else { return nil }
        return mode(for: id)
    }

    static var sportCategories: [GameMode.SportCategory] {
        [.basketball, .combat, .field, .precision, .board, .academy, .party]
    }

    static func modes(for sport: GameMode.SportCategory) -> [GameMode] {
        shippingModes.filter { $0.sport == sport }
    }
}
