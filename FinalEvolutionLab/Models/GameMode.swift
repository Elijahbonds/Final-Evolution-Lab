import SwiftUI

nonisolated enum GameModeId: String, Codable, Sendable, CaseIterable, Identifiable {
    case basketballHeadToHead = "basketball_h2h"
    /// Alias for ``basketballHeadToHead`` — NEXUS VenicePickupMode sim.
    case venicePickup = "venice_pickup"
    /// Real-phone recording · Vision pose · WDA/FIBA judges · live H2H matchmaking.
    case basketballDunkContestIRL = "basketball_dunk_irl"
    /// Hybrid Metal/SceneKit in-engine head-to-head dunk contest (NEXUS C++ `DunkContestMode`).
    case basketballDunkContest3D = "basketball_dunk_3d"
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
    /// Module library browser.
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
    /// Recognition / clip prompts — distinct UX from generic rhythm academy loops.
    case filmQuiz
    /// Board-and-space carnival loop — distinct UX from extreme sports rhythm.
    case partyBoard
}

/// Spec §2.1 sprint priority — P0 dunk, P1 karate endless, P2 post-sprint.
nonisolated enum NexusSprintPriority: Int, Sendable {
    case p0 = 0
    case p1 = 1
    case p2 = 2
}

/// NEXUS C++ depth tier — keep in sync with `docs/NEXUS_MODES_CAPABILITY.md`.
nonisolated enum NexusCapabilityTier: String, Sendable {
    case prod
    case sim
    case staging
    case preview
    case nonGame
}

extension GameModeId {
    static let dunkContestModes: Set<GameModeId> = [.basketballDunkContestIRL, .basketballDunkContest3D]

    var isDunkContestMode: Bool { Self.dunkContestModes.contains(self) }
    var isIRLDunkContest: Bool { self == .basketballDunkContestIRL }
    var is3DDunkContest: Bool { self == .basketballDunkContest3D }

    var nexusCapabilityTier: NexusCapabilityTier {
        switch self {
        case .basketballDunkContestIRL, .basketballDunkContest3D, .karateEndless, .basketballHeadToHead, .venicePickup, .courtCarnival,
             .whoSceneIt:
            return .prod
        case .gymnastics, .skateboarding, .snowboarding, .surfing:
            return .prod
        case .brainBrawl:
            return .prod
        case .basketball3v3, .karate, .baseball, .football, .soccer, .golf, .tennis, .volleyball:
            return .sim
        case .marketBrowse:
            return .nonGame
        }
    }

    var nexusSprintPriority: NexusSprintPriority {
        switch self {
        case .basketballDunkContestIRL, .basketballDunkContest3D: return .p0
        case .karateEndless, .basketballHeadToHead, .venicePickup, .courtCarnival: return .p1
        case .gymnastics, .brainBrawl, .skateboarding, .snowboarding, .whoSceneIt: return .p2
        default: return .p2
        }
    }

    /// Mode id sent to NEXUS C++ (`fel.arena.start_session`).
    var nexusRuntimeModeId: String {
        switch self {
        case .venicePickup: return GameModeId.basketballHeadToHead.rawValue
        case .basketballDunkContest3D: return "basketball_dunk"
        default: return rawValue
        }
    }

    /// Playable via NEXUS headless gameplay (full simulators + outcome evaluators).
    var isNexusSprintPlayable: Bool {
        switch self {
        case .marketBrowse:
            return true
        default:
            break
        }
        switch nexusCapabilityTier {
        case .prod, .sim, .staging: return true
        case .preview, .nonGame: return false
        }
    }

    /// Modes scored via C++ `OutcomeSportMode` + `fel.sport.pulse` (see `mode_runtime.cpp`).
    var isNexusOutcomeSportMode: Bool {
        switch self {
        case .basketball3v3, .karate, .baseball, .football, .soccer, .golf, .tennis, .volleyball:
            return true
        default:
            return false
        }
    }

    /// Dedicated board/academy simulators — `GymnasticsMode`, `SkateboardingMode`, etc. (not `fel.sport.pulse`).
    var isNexusBoardAcademyMode: Bool {
        switch self {
        case .gymnastics, .skateboarding, .snowboarding, .surfing:
            return true
        default:
            return false
        }
    }

    /// Honest mesh proxy disclosure for modes that reuse another venue asset.
    var venueMeshProxyNote: String? {
        switch self {
        case .surfing:
            return "Venice surf venue uses Venice beach court mesh until a dedicated surf-break asset ships."
        default:
            return nil
        }
    }

    var inputScheme: InputScheme {
        switch self {
        case .basketballHeadToHead, .venicePickup, .basketballDunkContestIRL, .basketballDunkContest3D, .basketball3v3, .karate, .karateEndless:
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
    }

    nonisolated enum MultiplayerType: String, Sendable {
        case realtime
        case turnBased
        case solo
        /// Shared-screen local co-op — not online netcode.
        case localCoop
    }

    nonisolated enum ReleaseState: String, Sendable {
        case production
        case preview
    }

    let releaseState: ReleaseState
    let capabilityTier: NexusCapabilityTier

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
        releaseState: ReleaseState = .production,
        capabilityTier: NexusCapabilityTier? = nil
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
        self.capabilityTier = capabilityTier ?? id.nexusCapabilityTier
        self.releaseState = releaseState
    }
}

extension GameMode {
    var nexusSprintPriority: NexusSprintPriority { id.nexusSprintPriority }
    var isNexusSprintPlayable: Bool { id.isNexusSprintPlayable }
    var nexusCapabilityTier: NexusCapabilityTier { capabilityTier }

    var nexusSprintPriorityLabel: String {
        switch nexusSprintPriority {
        case .p0: return "P0"
        case .p1: return "P1"
        case .p2: return "P2"
        }
    }

    /// SceneKit shell + NEXUS session — preview/staging tiers need ``Config.showPreviewGameModes`` in Release.
    var isLaunchableInCurrentBuild: Bool {
        switch nexusCapabilityTier {
        case .prod, .sim, .staging:
            return true
        case .preview, .nonGame:
            return Config.showPreviewGameModes
        }
    }

    /// Honest toolbar badge — nil for canonical production modes (`releaseState == .production`).
    var felPreviewLabel: String? {
        guard releaseState == .preview else { return nil }
        return FELPremiumCopy.Tier.earlyAccess(name)
    }

    /// Gameplay HUD honesty — practice/early-access tiers for non-prod modes; nil for prod ship modes.
    var felHonestTierLabel: String? {
        if let preview = felPreviewLabel { return preview }
        switch nexusCapabilityTier {
        case .prod:
            if Config.appRuntimeEnvironment == .staging {
                return FELPremiumCopy.Tier.beta(name)
            }
            return nil
        case .sim:
            return FELPremiumCopy.Tier.practice(name)
        case .staging:
            return FELPremiumCopy.Tier.beta(name)
        case .preview:
            return FELPremiumCopy.Tier.earlyAccess(name)
        case .nonGame:
            return FELPremiumCopy.Tier.library(name)
        }
    }
}

struct GameModeRegistry {
    /// Canonical production mode ids — keep in sync with `arena_mode_registry.h` and `scripts/nexus_validate_production_modes.sh`.
    static let productionModeIds: [String] = [
        "basketball_h2h", "basketball_dunk_irl", "basketball_dunk_3d", "basketball_3v3", "court_carnival",
        "karate_h2h", "karate_endless",
        "baseball", "football", "soccer", "golf", "tennis", "volleyball",
        "gymnastics", "surfing", "skateboarding", "snowboarding",
        "brain_brawl", "who_scene_it",
    ]

    /// Every playable arena mode — full lineup ships available; per-mode capability
    /// badges (prod/sim/staging) stay honest via ``GameModeId/nexusCapabilityTier``.
    static let nexusSprintModeIds: Set<GameModeId> = Set(GameModeId.allCases).subtracting([.marketBrowse])

    /// All 20 mode IDs from `arena_mode_registry.cpp` — keep in sync when adding modes.
    static let arenaRegistryModeIds: [GameModeId] = [
        .basketballHeadToHead, .basketballDunkContestIRL, .basketballDunkContest3D, .basketball3v3,
        .karate, .karateEndless,
        .baseball, .football, .soccer, .golf, .tennis, .volleyball,
        .gymnastics, .surfing, .skateboarding, .snowboarding,
        .brainBrawl, .whoSceneIt, .courtCarnival, .marketBrowse,
    ]

    static var nexusSprintModes: [GameMode] {
        // Filter the ordered registry (Set iteration order is nondeterministic per process).
        all.filter { nexusSprintModeIds.contains($0.id) }
            .sorted { $0.nexusSprintPriority.rawValue < $1.nexusSprintPriority.rawValue }
    }

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
            multiplayerType: .solo,
            environmentName: "Venice Beach Court",
            hint: "Venice pickup · throw-catch to 21 · solo vs ghost"
        ),
        GameMode(
            id: .venicePickup,
            name: "Venice Pickup",
            subtitle: "Throw-Catch H2H",
            sport: .basketball,
            iconName: "figure.basketball",
            accentColor: Color(red: 1.0, green: 0.55, blue: 0.15),
            multiplayerType: .solo,
            environmentName: "Venice Beach Court",
            hint: "Venice pickup · throw-catch to 21 · solo vs ghost",
            releaseState: .production
        ),
        GameMode(
            id: .basketballDunkContestIRL,
            name: "IRL H2H Dunk Contest",
            subtitle: "Regulation 10-ft Rim · Camera",
            sport: .basketball,
            iconName: "camera.viewfinder",
            accentColor: Color(red: 1.0, green: 0.35, blue: 0.2),
            multiplayerType: .realtime,
            environmentName: "Regulation Court (IRL)",
            hint: "Real court · phone camera · Vision pose · WDA/FIBA judges · not a video game scene",
            releaseState: .production
        ),
        GameMode(
            id: .basketballDunkContest3D,
            name: "3D H2H Dunk Contest",
            subtitle: "Venice Beach Blue Court",
            sport: .basketball,
            iconName: "sportscourt.fill",
            accentColor: Color(red: 0, green: 0.83, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Blue Court",
            hint: "On the blue court · dunk catalog · swipe timing · 3-judge panel · crowd momentum",
            releaseState: .production
        ),
        GameMode(
            id: .basketball3v3,
            name: "3v3 Streetball",
            subtitle: "Run the Court",
            sport: .basketball,
            iconName: "person.3.fill",
            accentColor: Color(red: 0.2, green: 0.8, blue: 0.4),
            multiplayerType: .solo,
            environmentName: "Venice Beach Court",
            hint: "Practice mode · first to 21 · vs AI opponent"
        ),
        GameMode(
            id: .karate,
            name: "Karate · 1v1",
            subtitle: "HP Sparring · Dojo",
            sport: .combat,
            iconName: "figure.martial.arts",
            accentColor: Color(red: 1.0, green: 0.2, blue: 0.2),
            multiplayerType: .realtime,
            environmentName: "Zen Dojo",
            hint: "Timed strikes · watch your health bar · first to zero loses"
        ),
        GameMode(
            id: .karateEndless,
            name: "Karate: Dojo Breach",
            subtitle: "Co-op Wave Survival",
            sport: .combat,
            iconName: "flame.fill",
            accentColor: Color(red: 1.0, green: 0.35, blue: 0.1),
            multiplayerType: .localCoop,
            environmentName: "Dojo Arena",
            hint: "LOCAL CO-OP · 1–4 players · survive 10 waves",
            releaseState: .production
        ),
        GameMode(
            id: .baseball,
            name: "Home Run Derby",
            subtitle: "Arcade Swing",
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
            subtitle: "Gridiron Breakaway",
            sport: .field,
            iconName: "football.fill",
            accentColor: Color(red: 0.5, green: 0.3, blue: 0.1),
            multiplayerType: .turnBased,
            environmentName: "Gridiron Stadium",
            hint: "First to 3 touchdowns wins · time your catch and run"
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
            subtitle: "Swipe to Pin",
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
            environmentName: "Tennis Court",
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
            environmentName: "Gymnastics Floor",
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
            hint: "Carve the line · balance through every set"
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
            subtitle: "Acting & Film Drills",
            sport: .academy,
            iconName: "theatermasks.fill",
            accentColor: Color(red: 0.45, green: 0.55, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Neuro Arena",
            hint: "Load Creator Scene Cards to practice monologues, dialogue cues, and camera angles.",
            releaseState: .production
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
            hint: "Hit the pads · roll the dice · stack mini-game wins",
            releaseState: .production
        ),
        GameMode(
            id: .marketBrowse,
            name: "Market Browse",
            subtitle: "Shop & collectibles",
            sport: .academy,
            iconName: "cart.fill",
            accentColor: Color.blue,
            multiplayerType: .solo,
            environmentName: "Luma Venice Shop",
            hint: "Browse the vault · scan venues · shop collectibles",
            releaseState: .preview
        ),
    ]

    static func mode(for id: GameModeId) -> GameMode {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    /// Resolves C++ registry mode ids (including aliases) to a launchable ``GameMode``.
    static func playableMode(forRegistryId raw: String) -> GameMode? {
        switch raw {
        case "venice_pickup":
            return mode(for: .basketballHeadToHead)
        case "basketball_dunk":
            return mode(for: .basketballDunkContest3D)
        case "market_browse", "module_library", "vault_shop":
            return mode(for: .marketBrowse)
        default:
            break
        }
        guard let id = GameModeId(rawValue: raw) else { return nil }
        return all.first(where: { $0.id == id })
    }

    /// Session readiness derived from generated spec difficulty tier.
    static func readiness(forGeneratedDifficultyTier tier: String) -> Double {
        NexusGeneratedGameEntry.readiness(for: tier)
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
        catalogModes.filter { $0.sport == sport }
    }

    /// All 20 arena modes — always listed in the mode picker with honest prod/staging/preview badges.
    static var catalogModes: [GameMode] {
        all.filter { arenaRegistryModeIds.contains($0.id) }
    }

    /// Ingests a `FELModeManagerPayload` to dynamically update or filter shipping game modes.
    static func loadFromPayload(_ payload: FELModeManagerPayload) -> [GameMode] {
        var loaded: [GameMode] = []
        for (rawId, entry) in payload.modeManager.modeRegistry {
            guard let modeId = GameModeId(rawValue: rawId) else { continue }
            let baseMode = all.first(where: { $0.id == modeId })
            let releaseState: GameMode.ReleaseState = entry.status == "production" ? .production : .preview
            
            let mode = GameMode(
                id: modeId,
                name: baseMode?.name ?? rawId.replacingOccurrences(of: "_", with: " ").capitalized,
                subtitle: baseMode?.subtitle ?? "NEXUS Arena Mode",
                sport: baseMode?.sport ?? .basketball,
                iconName: baseMode?.iconName ?? "gamecontroller",
                accentColor: baseMode?.accentColor ?? .orange,
                multiplayerType: baseMode?.multiplayerType ?? .realtime,
                environmentName: baseMode?.environmentName ?? "Arena",
                hint: baseMode?.hint,
                releaseState: releaseState,
                capabilityTier: baseMode?.capabilityTier ?? modeId.nexusCapabilityTier
            )
            loaded.append(mode)
        }
        return loaded
    }
}

// MARK: - Legacy mode-manager JSON (vault/remote config compat — NEXUS registry is source of truth for ship)

struct ModeRegistryEntry: Codable, Sendable {
    let map: String
    let gamemodeClass: String
    let binary: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case map
        case gamemodeClass = "gamemode_class"
        case binary
        case status
    }
}

struct ModeManagerConfig: Codable, Sendable {
    let `class`: String
    let totalModes: Int
    let productionModes: Int
    let modeRegistry: [String: ModeRegistryEntry]

    enum CodingKeys: String, CodingKey {
        case `class`
        case totalModes = "total_modes"
        case productionModes = "production_modes"
        case modeRegistry = "mode_registry"
    }
}

struct PRQCalculatorConfig: Codable, Sendable {
    let `class`: String
    let source: String
    let scalingFormula: String
    let weights: [String: Double]
    let updateTrigger: String
    let decayRatePerDay: Double
    let boostOnStreak: Bool

    enum CodingKeys: String, CodingKey {
        case `class`
        case source
        case scalingFormula = "scaling_formula"
        case weights
        case updateTrigger = "update_trigger"
        case decayRatePerDay = "decay_rate_per_day"
        case boostOnStreak = "boost_on_streak"
    }
}

struct BridgeSubsystemConfig: Codable, Sendable {
    let `class`: String
    let handshakeIdentifier: String
    let projectUuid: String
    let expectedBinarySignatures: [String]

    enum CodingKeys: String, CodingKey {
        case `class`
        case handshakeIdentifier = "handshake_identifier"
        case projectUuid = "project_uuid"
        case expectedBinarySignatures = "expected_binary_signatures"
    }
}

struct FELModeManagerPayload: Codable, Sendable {
    let cookedRuntimeNote: String
    let project: String
    let uproject: String
    let engine: String
    let localRepo: String
    let buildTarget: String
    let buildTargetLinux: String
    let modeManager: ModeManagerConfig
    let prqCalculator: PRQCalculatorConfig
    let bridgeSubsystem: BridgeSubsystemConfig

    enum CodingKeys: String, CodingKey {
        case cookedRuntimeNote = "cooked_runtime_note"
        case project
        case uproject
        case engine
        case localRepo = "local_repo"
        case buildTarget = "build_target"
        case buildTargetLinux = "build_target_linux"
        case modeManager = "mode_manager"
        case prqCalculator = "prq_calculator"
        case bridgeSubsystem = "bridge_subsystem"
    }
}
