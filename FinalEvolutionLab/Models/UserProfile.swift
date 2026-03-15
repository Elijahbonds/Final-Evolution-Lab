import Foundation

nonisolated struct UserProfile: Sendable, Identifiable {
    var id: String
    var displayName: String
    var athleteTag: String
    var metrics: PerformanceMetrics
    var evolutionShards: Int
    var credits: Int
    var totalWorkouts: Int
    var streakDays: Int
    var joinDate: Date
    var avatarSystemName: String
    var blueprintCredits: Int

    var sport: String?
    var age: Int?
    var goal: String?
    var hasCompletedOnboarding: Bool
    var systemScan: SystemScanResult?
    var activeCreatorCard: CreatorCardState?
    var ownedCardIds: [String]

    func ownsCard(_ cardId: String) -> Bool {
        ownedCardIds.contains(cardId)
    }

    /// Avatar skin to use everywhere (from system scan or placeholder until scan data is in).
    /// Placeholder is a neutral model lookalike so the main user always has a visible avatar before calibration.
    var effectiveAvatarConfig: AvatarSkinConfig {
        systemScan?.avatarConfig ?? AvatarSkinConfig.placeholder
    }
}

extension UserProfile: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        athleteTag = try container.decode(String.self, forKey: .athleteTag)
        metrics = try container.decode(PerformanceMetrics.self, forKey: .metrics)
        evolutionShards = try container.decode(Int.self, forKey: .evolutionShards)
        credits = (try? container.decode(Int.self, forKey: .credits)) ?? 0
        totalWorkouts = try container.decode(Int.self, forKey: .totalWorkouts)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        joinDate = try container.decode(Date.self, forKey: .joinDate)
        avatarSystemName = try container.decode(String.self, forKey: .avatarSystemName)
        blueprintCredits = try container.decode(Int.self, forKey: .blueprintCredits)
        sport = try container.decodeIfPresent(String.self, forKey: .sport)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        goal = try container.decodeIfPresent(String.self, forKey: .goal)
        hasCompletedOnboarding = (try? container.decode(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        systemScan = try container.decodeIfPresent(SystemScanResult.self, forKey: .systemScan)
        activeCreatorCard = try container.decodeIfPresent(CreatorCardState.self, forKey: .activeCreatorCard)
        ownedCardIds = (try? container.decode([String].self, forKey: .ownedCardIds)) ?? []
    }

    static let guest = UserProfile(
        id: "guest_\(Int.random(in: 1000...9999))",
        displayName: "Guest Athlete",
        athleteTag: "0xGuest",
        metrics: .empty,
        evolutionShards: 0,
        credits: 0,
        totalWorkouts: 0,
        streakDays: 0,
        joinDate: Date(),
        avatarSystemName: "figure.run",
        blueprintCredits: 0,
        sport: nil,
        age: nil,
        goal: nil,
        hasCompletedOnboarding: false,
        systemScan: nil,
        activeCreatorCard: nil,
        ownedCardIds: []
    )
}

nonisolated struct SystemScanResult: Codable, Sendable {
    let id: String
    let date: Date
    let prqScore: Double
    let verticalEstimateInches: Double
    let flightTimeSeconds: Double
    let movementGrade: String
    let notes: [String]
    let recommendedTrack: String
    var avatarConfig: AvatarSkinConfig

    init(id: String, date: Date, prqScore: Double, verticalEstimateInches: Double, flightTimeSeconds: Double, movementGrade: String, notes: [String], recommendedTrack: String, avatarConfig: AvatarSkinConfig = .default) {
        self.id = id
        self.date = date
        self.prqScore = prqScore
        self.verticalEstimateInches = verticalEstimateInches
        self.flightTimeSeconds = flightTimeSeconds
        self.movementGrade = movementGrade
        self.notes = notes
        self.recommendedTrack = recommendedTrack
        self.avatarConfig = avatarConfig
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        prqScore = try container.decode(Double.self, forKey: .prqScore)
        verticalEstimateInches = try container.decode(Double.self, forKey: .verticalEstimateInches)
        flightTimeSeconds = try container.decode(Double.self, forKey: .flightTimeSeconds)
        movementGrade = try container.decode(String.self, forKey: .movementGrade)
        notes = try container.decode([String].self, forKey: .notes)
        recommendedTrack = try container.decode(String.self, forKey: .recommendedTrack)
        avatarConfig = (try? container.decode(AvatarSkinConfig.self, forKey: .avatarConfig)) ?? .default
    }

    /// Default scan for profiles that have not run a system scan yet. Auto-creates a character so the main user always loads with a skin.
    static func defaultForProfile(_ profile: UserProfile) -> SystemScanResult {
        let prq = PRQ.clamp(profile.metrics.prqScore)
        let vertical = min(40, max(18, profile.metrics.verticalPotential * 0.28))
        let flight = 0.48
        let track: String
        switch profile.goal ?? "" {
        case "Jump Higher": track = "Flight"
        case "Get Faster": track = "Foundations"
        case "Build Power": track = "Elite"
        default: track = "Foundations"
        }
        let grade: String
        switch prq {
        case 80...: grade = "ELITE POTENTIAL"
        case 65..<80: grade = "FLIGHT READY"
        case 50..<65: grade = "BUILDING BASE"
        default: grade = "FOUNDATION PHASE"
        }
        let avatarConfig = AvatarSkinConfig.fromScan(prq: prq, vertical: vertical, flight: flight, sport: profile.sport)
        return SystemScanResult(
            id: UUID().uuidString,
            date: Date(),
            prqScore: prq,
            verticalEstimateInches: vertical,
            flightTimeSeconds: flight,
            movementGrade: grade,
            notes: [],
            recommendedTrack: track,
            avatarConfig: avatarConfig
        )
    }
}

nonisolated struct AvatarSkinConfig: Codable, Sendable {
    var heightScale: Double
    var weightScale: Double
    var limbLength: Double
    var skinTone: AvatarSkinTone
    var outfitStyle: AvatarOutfitStyle
    var auraColorR: Double
    var auraColorG: Double
    var auraColorB: Double
    var trailIntensity: Double

    static let `default` = AvatarSkinConfig(
        heightScale: 1.0,
        weightScale: 1.0,
        limbLength: 1.0,
        skinTone: .cyan,
        outfitStyle: .standard,
        auraColorR: 0,
        auraColorG: 0.83,
        auraColorB: 1.0,
        trailIntensity: 0.3
    )

    /// Neutral model lookalike shown until system scan data is available. Same rig as post-scan avatar, distinct silver/grey aura.
    static let placeholder = AvatarSkinConfig(
        heightScale: 1.0,
        weightScale: 1.0,
        limbLength: 1.0,
        skinTone: .cyan,
        outfitStyle: .standard,
        auraColorR: 0.52,
        auraColorG: 0.54,
        auraColorB: 0.58,
        trailIntensity: 0.2
    )

    static func fromScan(prq: Double, vertical: Double, flight: Double, sport: String?) -> AvatarSkinConfig {
        let normalizedPRQ = min(max(prq / 100.0, 0), 1)
        let heightBonus = min(0.15, vertical / 200.0)
        let flightBonus = min(0.1, flight * 0.15)

        let tone: AvatarSkinTone
        let outfit: AvatarOutfitStyle
        let auraR: Double
        let auraG: Double
        let auraB: Double

        switch prq {
        case 80...:
            tone = .elitePurple
            outfit = .elite
            auraR = 0.6; auraG = 0.2; auraB = 1.0
        case 65..<80:
            tone = .cyan
            outfit = .flight
            auraR = 0; auraG = 0.95; auraB = 0.9
        case 50..<65:
            tone = .blue
            outfit = .developing
            auraR = 0; auraG = 0.83; auraB = 1.0
        default:
            tone = .green
            outfit = .standard
            auraR = 0.2; auraG = 1.0; auraB = 0.4
        }

        let sportWeightBias: Double
        switch sport ?? "" {
        case "Basketball", "Volleyball": sportWeightBias = 0.95
        case "Football": sportWeightBias = 1.1
        case "Gymnastics": sportWeightBias = 0.88
        default: sportWeightBias = 1.0
        }

        return AvatarSkinConfig(
            heightScale: 1.0 + heightBonus,
            weightScale: sportWeightBias,
            limbLength: 1.0 + flightBonus,
            skinTone: tone,
            outfitStyle: outfit,
            auraColorR: auraR,
            auraColorG: auraG,
            auraColorB: auraB,
            trailIntensity: 0.2 + normalizedPRQ * 0.6
        )
    }
}

nonisolated enum AvatarSkinTone: String, Codable, Sendable {
    case cyan
    case blue
    case green
    case elitePurple
    case orange
}

nonisolated enum AvatarOutfitStyle: String, Codable, Sendable {
    case standard
    case developing
    case flight
    case elite
}

nonisolated struct CreatorCardState: Codable, Sendable {
    let cardId: String
    let creatorName: String
    let appliedAt: Date
    let costShards: Int
    let metricsBoost: PerformanceMetrics
    /// When the next weekly Shard tax is due to keep buffs active (Spatial Sports Economy).
    var nextTaxDue: Date?
    /// Weekly tax in Shards; nil means use app default.
    var weeklyTaxShards: Int?
}
