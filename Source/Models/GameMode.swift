import SwiftUI

nonisolated enum GameModeId: String, Codable, Sendable, CaseIterable, Identifiable {
    case basketballHeadToHead = "basketball_h2h"
    case basketballDunkContest = "basketball_dunk"
    case basketball3v3 = "basketball_3v3"
    case karate = "karate"
    case baseball = "baseball"
    case football = "football"
    case soccer = "soccer"
    case golf = "golf"
    case tennis = "tennis"
    case volleyball = "volleyball"
    case gymnastics = "gymnastics"
    case brainBrawl = "brain_brawl"

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

extension GameModeId {
    var inputScheme: InputScheme {
        switch self {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3, .karate:
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
        case .gymnastics:
            return .rhythmTap
        case .brainBrawl:
            return .rhythmTap
        }
    }

    /// Environment-specific copy and theming for Arena play (each mode built out in its venue).
    var environmentActionTitle: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "SHOOT!"
        case .basketballDunkContest: return "DUNK!"
        case .karate: return "STRIKE!"
        case .baseball: return "SWING!"
        case .football: return "RUN!"
        case .soccer: return "SHOOT!"
        case .golf: return "SWING!"
        case .tennis: return "RALLY!"
        case .volleyball: return "SPIKE!"
        case .gymnastics: return "STICK!"
        case .brainBrawl: return "ANSWER!"
        }
    }

    /// e.g. "Round", "Point", "Hole", "Question", "Bout", "At-bat", "Penalty"
    var environmentRoundLabel: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3, .basketballDunkContest: return "Round"
        case .karate: return "Bout"
        case .baseball: return "At-bat"
        case .football: return "Drive"
        case .soccer: return "Penalty"
        case .golf: return "Hole"
        case .tennis, .volleyball: return "Point"
        case .gymnastics: return "Routine"
        case .brainBrawl: return "Question"
        }
    }

    /// Opponent label in play (e.g. "OPP", "CPU", "AI")
    var environmentOpponentLabel: String {
        switch self {
        case .karate: return "OPP"
        default: return "OPP"
        }
    }

    /// Number of rounds/points/holes etc. per match in Arena. Tuned per sport (e.g. first-to-3, best-of-5).
    var environmentRoundCount: Int {
        switch self {
        case .brainBrawl: return 5
        case .golf: return 3
        case .soccer: return 5
        case .tennis, .volleyball: return 5
        case .karate, .football: return 5
        default: return 3
        }
    }

    /// Secondary color for environment gradient (e.g. darker tint).
    var environmentSecondaryColor: Color {
        switch self {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3: return Color(red: 0.1, green: 0.4, blue: 0.5)
        case .karate: return Color(red: 0.4, green: 0.05, blue: 0.05)
        case .baseball: return Color(red: 0.05, green: 0.25, blue: 0.45)
        case .football: return Color(red: 0.25, green: 0.15, blue: 0.05)
        case .soccer: return Color(red: 0.05, green: 0.4, blue: 0.15)
        case .golf: return Color(red: 0.1, green: 0.35, blue: 0.2)
        case .tennis: return Color(red: 0.4, green: 0.35, blue: 0.05)
        case .volleyball: return Color(red: 0.5, green: 0.35, blue: 0.05)
        case .gymnastics: return Color(red: 0.2, green: 0.15, blue: 0.5)
        case .brainBrawl: return Color(red: 0.3, green: 0.15, blue: 0.5)
        }
    }

    /// Short style tag for presentation (no third-party product names).
    var inspirationTag: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "Street hoops"
        case .basketballDunkContest: return "Dunk contest"
        case .karate: return "Point sparring"
        case .baseball, .golf: return "Arcade swing"
        case .football: return "Kick return"
        case .soccer: return "Penalty shootout"
        case .tennis, .volleyball: return "Beach rally"
        case .gymnastics: return "Routines & tumbling"
        case .brainBrawl: return "Curriculum quiz"
        }
    }

    /// One-line atmosphere for the play screen (e.g. "Sun, boards, and street rules.")
    var environmentAtmosphere: String {
        switch self {
        case .basketballHeadToHead: return "Sun, boards, and street rules."
        case .basketball3v3: return "Run the court. Three on three."
        case .basketballDunkContest: return "Sprint, gather, fly—face buttons for style."
        case .karate: return "Respect. Control. One clean point at a time."
        case .baseball: return "Clear the fences. Derby rules."
        case .football: return "One return. No second chances."
        case .soccer: return "You vs the keeper. Penalty pressure."
        case .golf: return "Closest to the pin. One swing per hole."
        case .tennis: return "Serve, rally, finish. Beach court intensity."
        case .volleyball: return "Sand, sun, and no mercy at the net."
        case .gymnastics: return "Stick the landing. Form is everything."
        case .brainBrawl: return "Your curriculum. AI opponent. First to answer wins."
        }
    }

    /// Short line for Get Ready screen (instructional). Arena = tap to commit, no timing bar; outcome from PRQ.
    var getReadySubtitle: String {
        switch self {
        case .basketballDunkContest: return "Sprint → Gather → Fly. Face buttons for finishers."
        case .basketballHeadToHead, .basketball3v3, .karate, .baseball, .football, .soccer, .golf, .tennis, .volleyball, .gymnastics:
            return "Press ✕ or tap to commit. Outcome from your PRQ."
        case .brainBrawl:
            return "Tap to lock your answer. First correct wins the question."
        }
    }

    /// Arena commit hint (no timing bar): one press = one commit.
    var arenaCommitHint: String {
        switch self {
        case .basketballDunkContest: return "Sprint → Gather → Fly. Face buttons for finishers."
        case .brainBrawl: return "Tap to lock answer. First correct wins."
        default: return "Press ✕ (Cross) or tap to commit. Outcome from PRQ (0.62–0.90)."
        }
    }

    /// Display name for the opponent in this environment (e.g. "Keeper", "Dojo Master").
    var opponentDisplayName: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "OPP"
        case .basketballDunkContest: return "JUDGES"
        case .karate: return "OPP"
        case .baseball: return "PITCHER"
        case .football: return "SPECIAL TEAMS"
        case .soccer: return "KEEPER"
        case .golf: return "FIELD"
        case .tennis: return "OPP"
        case .volleyball: return "NET"
        case .gymnastics: return "JUDGES"
        case .brainBrawl: return "OPP"
        }
    }

    /// Two- to three-sentence environment description for the play screen.
    var environmentDescription: String {
        switch self {
        case .basketballHeadToHead:
            return "Venice Beach half-court. One basket, one ball, first to score wins the round. Hand up to contest; your Court IQ drives the outcome."
        case .basketballDunkContest:
            return "The same iconic court, dunk contest rules. Sprint from the wing, hit the gather zone, then fly—face buttons pick your finisher. Hang Time is your edge."
        case .basketball3v3:
            return "Street rules, three on three. Every possession counts. Contest with hands up; Court IQ and timing decide who gets the bucket."
        case .karate:
            return "Point sparring in the dojo. One clean strike lands the bout. Control distance and timing; Fight IQ beats raw aggression."
        case .baseball:
            return "Home Run Derby at the stadium. You get one swing per at-bat. Clear the fence and you win the round; Bat Speed shapes your odds."
        case .football:
            return "Kick return, sudden death. One return—break it or get stopped. Burst Speed and vision; no second chances."
        case .soccer:
            return "Penalty shootout. You vs the keeper, one kick per round. Placement and composure; Shot Accuracy vs the save."
        case .golf:
            return "Closest to the pin. One swing per hole. Wind and lie are factored into your Swing Precision—get close to win the hole."
        case .tennis:
            return "Beach court rally. Serve, rally, put the point away. Rally Control and placement beat the opponent across the net."
        case .volleyball:
            return "Beach volleyball, rally scoring. Serve, receive, set, spike. Spike Power and timing through the block decide the point."
        case .gymnastics:
            return "Olympic-style routine. Execute, stick the landing. Form Score and consistency beat the judges."
        case .brainBrawl:
            return "Curriculum-based quiz vs AI. Same questions, first correct answer wins the question. Brain Speed and recall decide the round."
        }
    }

    /// In-round commit feedback (perfect / good / miss) — high-quality, sport-specific copy.
    var commitFeedbackPerfect: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "BUCKET!"
        case .basketballDunkContest: return "SLAM!"
        case .karate: return "STRIKE!"
        case .baseball: return "GONE!"
        case .football: return "HOUSE!"
        case .soccer: return "GOAL!"
        case .golf: return "TAP-IN!"
        case .tennis: return "ACE!"
        case .volleyball: return "KILL!"
        case .gymnastics: return "STUCK!"
        case .brainBrawl: return "CORRECT!"
        }
    }

    var commitFeedbackGood: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "GOOD"
        case .basketballDunkContest: return "NICE"
        case .karate: return "POINT"
        case .baseball: return "CONTACT"
        case .football: return "YARDS"
        case .soccer: return "ON TARGET"
        case .golf: return "GREEN"
        case .tennis: return "IN"
        case .volleyball: return "POINT"
        case .gymnastics: return "LANDED"
        case .brainBrawl: return "RIGHT"
        }
    }

    var commitFeedbackMiss: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "MISS"
        case .basketballDunkContest: return "OFF"
        case .karate: return "BLOCKED"
        case .baseball: return "OUT"
        case .football: return "STOPPED"
        case .soccer: return "SAVED"
        case .golf: return "WIDE"
        case .tennis: return "OUT"
        case .volleyball: return "BLOCKED"
        case .gymnastics: return "DEDUCT"
        case .brainBrawl: return "WRONG"
        }
    }

    /// Legacy: Arena uses no charge bar (tap to commit). Kept for any future mode that might use charge.
    var chargeBarTitle: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "PRESS ✕ TO SHOOT"
        case .basketballDunkContest: return "PRESS ✕ TO DUNK"
        case .karate: return "PRESS ✕ TO STRIKE"
        case .baseball: return "PRESS ✕ TO SWING"
        case .football: return "PRESS ✕ TO BREAK"
        case .soccer: return "PRESS ✕ TO SHOOT"
        case .golf: return "PRESS ✕ TO SWING"
        case .tennis: return "PRESS ✕ TO RALLY"
        case .volleyball: return "PRESS ✕ TO SPIKE"
        case .gymnastics: return "PRESS ✕ TO STICK"
        case .brainBrawl: return "TAP TO LOCK ANSWER"
        }
    }
}

nonisolated struct GameMode: Sendable, Identifiable, Hashable {
    let id: GameModeId
    let name: String
    let subtitle: String
    let sport: SportCategory
    let iconName: String
    let accentColor: Color
    let multiplayerType: MultiplayerType
    let environmentName: String
    let hint: String?

    nonisolated static func == (lhs: GameMode, rhs: GameMode) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

    nonisolated enum SportCategory: String, Sendable {
        case basketball = "Basketball"
        case combat = "Combat Sports"
        case field = "Field Sports"
        case precision = "Precision"
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
            hint: "Hands up = contest shot • Right stick = defender distance"
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
            hint: "Sprint → Gather → Fly → Face buttons for style"
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
            hint: "Hands up = contest • Right stick = defender distance"
        ),
        GameMode(
            id: .karate,
            name: "Karate",
            subtitle: "Point Sparring",
            sport: .combat,
            iconName: "figure.martial.arts",
            accentColor: Color(red: 1.0, green: 0.2, blue: 0.2),
            multiplayerType: .realtime,
            environmentName: "Dojo Arena",
            hint: "Stick combos for style • Block with right stick"
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
            hint: "Serve, Forehand, Backhand • Aim with drag"
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
            hint: "Tumble, Vault, Dismount • Time for bonus"
        ),
        GameMode(
            id: .brainBrawl,
            name: "Brain Brawl",
            subtitle: "Curriculum Quiz vs AI",
            sport: .precision,
            iconName: "brain.head.profile",
            accentColor: Color(red: 0.6, green: 0.35, blue: 0.9),
            multiplayerType: .turnBased,
            environmentName: "Arena",
            hint: "Answer curriculum questions vs AI. Your path, your quiz."
        ),
    ]

    static func mode(for id: GameModeId) -> GameMode {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    static var sportCategories: [GameMode.SportCategory] {
        [.basketball, .combat, .field, .precision]
    }

    static func modes(for sport: GameMode.SportCategory) -> [GameMode] {
        all.filter { $0.sport == sport }
    }

    // MARK: - Arena Venues (built-out arenas; modes grouped by environment)

    struct ArenaVenue: Sendable, Identifiable {
        let id: String
        let name: String
        let tagline: String
        let iconName: String
        let accentColor: Color
        /// Matches GameMode.environmentName for grouping
        let environmentName: String
        /// One-line atmosphere (e.g. "Sun and street rules.")
        var atmosphere: String { venueAtmosphere }
        /// Extended description for venue card or detail.
        var longDescription: String { venueLongDescription }

        private var venueAtmosphere: String {
            switch id {
            case "venice_beach": return "Sun, boards, and the Pacific breeze."
            case "dojo": return "Tatami, respect, one point at a time."
            case "stadium_diamond": return "Fences, crowd, and the long ball."
            case "stadium_field": return "Kick coverage and open grass."
            case "stadium_pitch": return "Twelve yards. You and the keeper."
            case "golf_green": return "Green, wind, and one clean swing."
            case "beach_court": return "Sand, sun, and no mercy at the net."
            case "arena": return "Routines, questions, and the podium."
            default: return "Compete. Adapt. Evolve."
            }
        }

        private var venueLongDescription: String {
            switch id {
            case "venice_beach":
                return "Outdoor courts by the Pacific. Half-court head-to-head, 3v3 runs, and the legendary dunk contest. Chain nets, concrete, and street rules. Your Court IQ and Hang Time drive every possession."
            case "dojo":
                return "Traditional dojo for point sparring. Controlled contact, clean strikes, and respect. Distance and timing beat raw power. Fight IQ decides each bout."
            case "stadium_diamond":
                return "Pro stadium diamond. Home Run Derby rules: one swing per at-bat. Clear the fence to win the round. Bat Speed and timing against the pitcher."
            case "stadium_field":
                return "Full stadium field for kick return. Sudden death—one return. Special teams vs your burst. Break it for the win; get stopped and it’s over. Burst Speed is everything."
            case "stadium_pitch":
                return "Penalty shootout at the pitch. You vs the keeper, one kick per round. Placement and composure under pressure. Shot Accuracy decides who blinks first."
            case "golf_green":
                return "Par-3 style closest-to-the-pin. One swing per hole. Wind and lie factor into your result. Swing Precision and calm win the hole."
            case "beach_court":
                return "Beach volleyball court. Rally scoring, sun, and sand. Serve, receive, set, spike. Spike Power and timing through the block decide every point."
            case "arena":
                return "Academy Arena hosts gymnastics routines and Brain Brawl. Stick the landing for Form Score; outthink the AI for Brain Speed. One routine or one question at a time."
            default:
                return "Compete in this arena. Your readiness and skill decide the outcome."
            }
        }
    }

    static let arenaVenues: [ArenaVenue] = [
        ArenaVenue(id: "venice_beach", name: "Venice Beach Court", tagline: "Outdoor hoops & beach tennis", iconName: "sportscourt.fill", accentColor: Color(red: 0, green: 0.83, blue: 1.0), environmentName: "Venice Beach Court"),
        ArenaVenue(id: "dojo", name: "Dojo Arena", tagline: "Point sparring & combat", iconName: "figure.martial.arts", accentColor: Color(red: 1.0, green: 0.2, blue: 0.2), environmentName: "Dojo Arena"),
        ArenaVenue(id: "stadium_diamond", name: "Stadium Diamond", tagline: "Home run derby", iconName: "figure.baseball", accentColor: Color(red: 0.1, green: 0.5, blue: 0.9), environmentName: "Stadium Diamond"),
        ArenaVenue(id: "stadium_field", name: "Stadium Field", tagline: "Kick return sudden death", iconName: "football.fill", accentColor: Color(red: 0.5, green: 0.3, blue: 0.1), environmentName: "Stadium Field"),
        ArenaVenue(id: "stadium_pitch", name: "Stadium Pitch", tagline: "Penalty shootout", iconName: "soccerball", accentColor: Color(red: 0.2, green: 0.7, blue: 0.3), environmentName: "Stadium Pitch"),
        ArenaVenue(id: "golf_green", name: "Golf Green", tagline: "Closest to the pin", iconName: "figure.golf", accentColor: Color(red: 0.3, green: 0.7, blue: 0.4), environmentName: "Golf Green"),
        ArenaVenue(id: "beach_court", name: "Beach Court", tagline: "Rally ace volleyball", iconName: "volleyball.fill", accentColor: Color(red: 0.98, green: 0.75, blue: 0.14), environmentName: "Beach Court"),
        ArenaVenue(id: "arena", name: "Academy Arena", tagline: "Gymnastics & Brain Brawl", iconName: "figure.gymnastics", accentColor: Color(red: 0.5, green: 0.4, blue: 0.95), environmentName: "Arena"),
    ]

    static func modes(for venue: ArenaVenue) -> [GameMode] {
        all.filter { $0.environmentName == venue.environmentName }
    }
}
