import Foundation

nonisolated struct UserProfile: Sendable, Identifiable {
    var id: String
    var displayName: String
    var athleteTag: String
    var metrics: PerformanceMetrics
    var evolutionShards: Int
    /// Shards credited locally from arena/coach flows until a server ledger grant exists (GAME-43 / GAME-46).
    var pendingUnverifiedShardCredits: Int
    /// Pending creator royalty shards
    var pendingRoyaltyShards: Int
    var totalWorkouts: Int
    var streakDays: Int
    var joinDate: Date
    var avatarSystemName: String
    var blueprintCredits: Int

    var sport: String?
    var age: Int?
    var goal: String?
    /// Parent/guardian acknowledgment for athletes under 18 — gates public feed, HealthKit connect, and paid coach critique flows (MINORS-01).
    var guardianConsentForMinorFeatures: Bool
    var hasCompletedOnboarding: Bool
    var systemScan: SystemScanResult?
    var activeCreatorCard: CreatorCardState?
    var ownedCardIds: [String]
    var ownedCosmetics: [String]
    var avatarConfig: AvatarSkinConfig
    var brainBrawlProgression: BrainBrawlProgression?
    var academicProgress: AcademicProgress?
    var competitionAnimations: [NexusAnimationAsset]
    var mintedCreatorCards: [MintedCreatorCard]
    var activeSignatureAnimationId: String?
    var pendingShardRoyalties: Int
    var totalRoyaltySales: Int
    var totalRoyaltyEarnings: Int

    func ownsCard(_ cardId: String) -> Bool {
        ownedCardIds.contains(cardId)
    }

    func ownsCosmetic(_ cosmeticId: String) -> Bool {
        ownedCosmetics.contains(cosmeticId)
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
        pendingUnverifiedShardCredits = (try? container.decode(Int.self, forKey: .pendingUnverifiedShardCredits)) ?? 0
        pendingRoyaltyShards = (try? container.decode(Int.self, forKey: .pendingRoyaltyShards)) ?? 0
        totalWorkouts = try container.decode(Int.self, forKey: .totalWorkouts)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        joinDate = try container.decode(Date.self, forKey: .joinDate)
        avatarSystemName = try container.decode(String.self, forKey: .avatarSystemName)
        blueprintCredits = try container.decode(Int.self, forKey: .blueprintCredits)
        sport = try container.decodeIfPresent(String.self, forKey: .sport)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        goal = try container.decodeIfPresent(String.self, forKey: .goal)
        guardianConsentForMinorFeatures = (try? container.decode(Bool.self, forKey: .guardianConsentForMinorFeatures)) ?? false
        hasCompletedOnboarding = (try? container.decode(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        systemScan = try container.decodeIfPresent(SystemScanResult.self, forKey: .systemScan)
        activeCreatorCard = try container.decodeIfPresent(CreatorCardState.self, forKey: .activeCreatorCard)
        ownedCardIds = (try? container.decode([String].self, forKey: .ownedCardIds)) ?? []
        ownedCosmetics = (try? container.decode([String].self, forKey: .ownedCosmetics)) ?? []
        avatarConfig = (try? container.decode(AvatarSkinConfig.self, forKey: .avatarConfig)) ?? systemScan?.avatarConfig ?? .default
        brainBrawlProgression = try container.decodeIfPresent(BrainBrawlProgression.self, forKey: .brainBrawlProgression)
        academicProgress = try container.decodeIfPresent(AcademicProgress.self, forKey: .academicProgress)
        competitionAnimations = (try? container.decode([NexusAnimationAsset].self, forKey: .competitionAnimations)) ?? []
        mintedCreatorCards = (try? container.decode([MintedCreatorCard].self, forKey: .mintedCreatorCards)) ?? []
        activeSignatureAnimationId = try container.decodeIfPresent(String.self, forKey: .activeSignatureAnimationId)
        pendingShardRoyalties = (try? container.decode(Int.self, forKey: .pendingShardRoyalties)) ?? 0
        totalRoyaltySales = (try? container.decode(Int.self, forKey: .totalRoyaltySales)) ?? 0
        totalRoyaltyEarnings = (try? container.decode(Int.self, forKey: .totalRoyaltyEarnings)) ?? 0
    }

    static let guest = UserProfile(
        id: "guest_\(Int.random(in: 1000...9999))",
        displayName: "Guest Athlete",
        athleteTag: "0xGuest",
        metrics: .empty,
        evolutionShards: 0,
        pendingUnverifiedShardCredits: 0,
        pendingRoyaltyShards: 0,
        totalWorkouts: 0,
        streakDays: 0,
        joinDate: Date(),
        avatarSystemName: "figure.run",
        blueprintCredits: 0,
        sport: nil as String?,
        age: nil as Int?,
        goal: nil as String?,
        guardianConsentForMinorFeatures: false,
        hasCompletedOnboarding: false,
        systemScan: nil as SystemScanResult?,
        activeCreatorCard: nil as CreatorCardState?,
        ownedCardIds: [] as [String],
        ownedCosmetics: [] as [String],
        avatarConfig: AvatarSkinConfig.default,
        brainBrawlProgression: nil as BrainBrawlProgression?,
        academicProgress: nil as AcademicProgress?,
        competitionAnimations: [] as [NexusAnimationAsset],
        mintedCreatorCards: [] as [MintedCreatorCard],
        activeSignatureAnimationId: nil as String?,
        pendingShardRoyalties: 0,
        totalRoyaltySales: 0,
        totalRoyaltyEarnings: 0
    )
}

nonisolated enum SystemScanSource: String, Codable, Sendable {
    /// Random goal-band demo (`SystemScanView`); does not measure pose or performance.
    case demoSynthetic = "demo_synthetic"
    /// Trusted capture (pose / mesh / verified lab instrument). Required for competitive PRQ commits.
    case measured = "measured"
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
    /// Where the numbers came from — drives profile / feed / SQL eligibility (SCAN-49 / SCAN-51).
    var source: SystemScanSource
    /// 0…1; measured pipeline must clear ``minimumConfidenceForCompetitiveCommit`` to affect ranked state.
    var confidence01: Double

    /// Minimum confidence required before a measured scan may update competitive PRQ, SQL peak, or Lab feed.
    static let minimumConfidenceForCompetitiveCommit: Double = 0.72

    /// Body IQ / kinetic-leakage prescriptions, athlete-specific coaching claims, and arcade joint modifiers from scan — **never** from demo synthetic bands.
    var supportsBiomechanicalPrescription: Bool {
        source == .measured && confidence01 >= Self.minimumConfidenceForCompetitiveCommit
    }

    /// True only for verified instrument/pose pipelines — never for ``demoSynthetic``.
    var commitsCompetitiveMetrics: Bool {
        supportsBiomechanicalPrescription
    }

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
        source: SystemScanSource = .demoSynthetic,
        confidence01: Double = 0
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
        self.source = source
        self.confidence01 = confidence01
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, prqScore, verticalEstimateInches, flightTimeSeconds, movementGrade, notes, recommendedTrack, avatarConfig, source, confidence01
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
        source = (try? container.decode(SystemScanSource.self, forKey: .source)) ?? .demoSynthetic
        confidence01 = (try? container.decode(Double.self, forKey: .confidence01)) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(prqScore, forKey: .prqScore)
        try container.encode(verticalEstimateInches, forKey: .verticalEstimateInches)
        try container.encode(flightTimeSeconds, forKey: .flightTimeSeconds)
        try container.encode(movementGrade, forKey: .movementGrade)
        try container.encode(notes, forKey: .notes)
        try container.encode(recommendedTrack, forKey: .recommendedTrack)
        try container.encode(avatarConfig, forKey: .avatarConfig)
        try container.encode(source, forKey: .source)
        try container.encode(confidence01, forKey: .confidence01)
    }
}

nonisolated enum AvatarHairstyle: String, Codable, Sendable, CaseIterable {
    case buzzcut = "Buzzcut"
    case dreadlocks = "Dreadlocks"
    case mohawk = "Mohawk"
    case undercut = "Undercut"
    case ponytail = "Ponytail"
    case none = "None"
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
    var hairstyle: AvatarHairstyle

    static let `default` = AvatarSkinConfig(
        heightScale: 1.0,
        weightScale: 1.0,
        limbLength: 1.0,
        skinTone: .cyan,
        outfitStyle: .standard,
        auraColorR: 0,
        auraColorG: 0.83,
        auraColorB: 1.0,
        trailIntensity: 0.3,
        hairstyle: .none
    )

    private enum CodingKeys: String, CodingKey {
        case heightScale, weightScale, limbLength, skinTone, outfitStyle, auraColorR, auraColorG, auraColorB, trailIntensity, hairstyle
    }

    nonisolated init(
        heightScale: Double,
        weightScale: Double,
        limbLength: Double,
        skinTone: AvatarSkinTone,
        outfitStyle: AvatarOutfitStyle,
        auraColorR: Double,
        auraColorG: Double,
        auraColorB: Double,
        trailIntensity: Double,
        hairstyle: AvatarHairstyle = .none
    ) {
        self.heightScale = heightScale
        self.weightScale = weightScale
        self.limbLength = limbLength
        self.skinTone = skinTone
        self.outfitStyle = outfitStyle
        self.auraColorR = auraColorR
        self.auraColorG = auraColorG
        self.auraColorB = auraColorB
        self.trailIntensity = trailIntensity
        self.hairstyle = hairstyle
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        heightScale = (try? container.decode(Double.self, forKey: .heightScale)) ?? 1.0
        weightScale = (try? container.decode(Double.self, forKey: .weightScale)) ?? 1.0
        limbLength = (try? container.decode(Double.self, forKey: .limbLength)) ?? 1.0
        skinTone = (try? container.decode(AvatarSkinTone.self, forKey: .skinTone)) ?? .cyan
        outfitStyle = (try? container.decode(AvatarOutfitStyle.self, forKey: .outfitStyle)) ?? .standard
        auraColorR = (try? container.decode(Double.self, forKey: .auraColorR)) ?? 0.0
        auraColorG = (try? container.decode(Double.self, forKey: .auraColorG)) ?? 0.83
        auraColorB = (try? container.decode(Double.self, forKey: .auraColorB)) ?? 1.0
        trailIntensity = (try? container.decode(Double.self, forKey: .trailIntensity)) ?? 0.3
        hairstyle = (try? container.decode(AvatarHairstyle.self, forKey: .hairstyle)) ?? .none
    }

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
            trailIntensity: 0.2 + normalizedPRQ * 0.6,
            hairstyle: .none
        )
    }
}

nonisolated enum AvatarSkinTone: String, Codable, Sendable, CaseIterable {
    case cyan
    case blue
    case green
    case elitePurple
    case orange
}

nonisolated enum AvatarOutfitStyle: String, Codable, Sendable, CaseIterable {
    case standard
    case developing
    case flight
    case elite
    case neon
    case shadow
    case chrome
    case gold
}

nonisolated struct CreatorCardState: Codable, Sendable {
    let cardId: String
    let creatorName: String
    let appliedAt: Date
    let costShards: Int
    let metricsBoost: PerformanceMetrics
}
