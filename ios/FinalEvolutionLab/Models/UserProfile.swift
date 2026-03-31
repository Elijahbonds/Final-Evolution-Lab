import Foundation

struct UserProfile: Sendable, Identifiable {
    var id: String
    var displayName: String
    var athleteTag: String
    var metrics: PerformanceMetrics
    var evolutionShards: Int
    var premiumCredits: Int
    var creatorCredits: Int
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
    var unlockedCosmeticRewardIds: [String]

    func ownsCard(_ cardId: String) -> Bool {
        ownedCardIds.contains(cardId)
    }
}

extension UserProfile: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        athleteTag = try container.decode(String.self, forKey: .athleteTag)
        metrics = try container.decode(PerformanceMetrics.self, forKey: .metrics)
        evolutionShards = try container.decode(Int.self, forKey: .evolutionShards)
        premiumCredits = (try? container.decode(Int.self, forKey: .premiumCredits)) ?? 0
        creatorCredits = (try? container.decode(Int.self, forKey: .creatorCredits)) ?? 0
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
        unlockedCosmeticRewardIds = (try? container.decode([String].self, forKey: .unlockedCosmeticRewardIds)) ?? []
    }

    static let guest = UserProfile(
        id: "guest_\(Int.random(in: 1000...9999))",
        displayName: "Guest Athlete",
        athleteTag: "0xGuest",
        metrics: .empty,
        evolutionShards: 0,
        premiumCredits: 0,
        creatorCredits: 0,
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
        ownedCardIds: [],
        unlockedCosmeticRewardIds: []
    )
}

struct SystemScanResult: Codable, Sendable {
    let id: String
    let date: Date
    let prqScore: Double
    let verticalEstimateInches: Double
    let flightTimeSeconds: Double
    let movementGrade: String
    let notes: [String]
    let recommendedTrack: String
    var avatarConfig: AvatarSkinConfig
    var movementScreening: MovementScreeningReport?

    init(
        id: String,
        date: Date,
        prqScore: Double,
        verticalEstimateInches: Double,
        flightTimeSeconds: Double,
        movementGrade: String,
        notes: [String],
        recommendedTrack: String,
        avatarConfig: AvatarSkinConfig = .default,
        movementScreening: MovementScreeningReport? = nil
    ) {
        self.id = id
        self.date = date
        self.prqScore = prqScore
        self.verticalEstimateInches = verticalEstimateInches
        self.flightTimeSeconds = flightTimeSeconds
        self.movementGrade = movementGrade
        self.notes = notes
        self.recommendedTrack = recommendedTrack
        self.avatarConfig = avatarConfig
        self.movementScreening = movementScreening
    }

    init(from decoder: Decoder) throws {
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
        movementScreening = try container.decodeIfPresent(MovementScreeningReport.self, forKey: .movementScreening)
    }
}

struct AvatarSkinConfig: Codable, Sendable {
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

    static func fromScan(prq: Double, vertical: Double, flight: Double, sport: String?) -> AvatarSkinConfig {
        let normalizedPRQ = min(max(prq / 100.0, 0), 1)
        let normalizedVertical = min(max(vertical / 45.0, 0), 1)
        let normalizedFlight = min(max(flight / 1.2, 0), 1)

        let heightBonus = min(0.18, normalizedVertical * 0.18)
        let flightBonus = min(0.14, normalizedFlight * 0.14)

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
        let limbBonus: Double
        switch sport ?? "" {
        case "Basketball", "Volleyball":
            sportWeightBias = 0.95
            limbBonus = 0.04
        case "Football":
            sportWeightBias = 1.1
            limbBonus = 0
        case "Gymnastics":
            sportWeightBias = 0.88
            limbBonus = -0.03
        case "Soccer", "Tennis":
            sportWeightBias = 0.98
            limbBonus = 0.02
        case "Baseball", "Golf":
            sportWeightBias = 1.02
            limbBonus = 0.01
        default:
            sportWeightBias = 1.0
            limbBonus = 0
        }

        return AvatarSkinConfig(
            heightScale: 1.0 + heightBonus,
            weightScale: sportWeightBias,
            limbLength: 1.0 + flightBonus + limbBonus,
            skinTone: tone,
            outfitStyle: outfit,
            auraColorR: auraR,
            auraColorG: auraG,
            auraColorB: auraB,
            trailIntensity: 0.2 + normalizedPRQ * 0.6
        )
    }
}

enum AvatarArchetype: String, Codable, Sendable {
    case highFlyer = "High Flyer"
    case powerDriver = "Power Driver"
    case agileCreator = "Agile Creator"
    case balancedAthlete = "Balanced Athlete"
}

extension SystemScanResult {
    var irlAvatarArchetype: AvatarArchetype {
        if verticalEstimateInches >= 34 && flightTimeSeconds >= 0.75 {
            return .highFlyer
        }
        if prqScore >= 72 && movementGrade.uppercased().contains("A") {
            return .agileCreator
        }
        if notes.joined(separator: " ").localizedCaseInsensitiveContains("power") {
            return .powerDriver
        }
        return .balancedAthlete
    }
}

enum AvatarSkinTone: String, Codable, Sendable {
    case cyan
    case blue
    case green
    case elitePurple
    case orange
}

enum AvatarOutfitStyle: String, Codable, Sendable {
    case standard
    case developing
    case flight
    case elite
}

struct CreatorCardState: Codable, Sendable {
    let cardId: String
    let creatorName: String
    let appliedAt: Date
    let assetInstanceId: String?
    let costShards: Int
    let metricsBoost: PerformanceMetrics

    var costCredits: Int { costShards } // Legacy key alias.
}
