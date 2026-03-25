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
    /// Vertical Velocity Academy — completed module keys (`mod1`…`mod12`). `mod9` = Plyos mastery (Dunk Contest neuro bonus).
    var completedAcademyModuleIds: [String]
    /// Shard marketplace exclusive gear — Unreal soft paths by slot (`jersey`, `shoes`) for `DigitalTwinSkeletalMesh` materials.
    var equippedGearTexturePaths: [String: String]
    /// Pro-Coach Sovereign Invite: coach `CreatorID` locked in on first System Scan when a valid pending code was registered.
    var linkedCoachCreatorId: String?
    /// When `linkedCoachCreatorId` was committed (first scan handoff).
    var coachInviteLinkedAt: Date?
    /// Supabase `auth.users.id` (UUID string) when signed in — used for wallet RLS + Stripe metadata.
    var supabaseUserId: String?

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
    enum CodingKeys: String, CodingKey {
        case id, displayName, athleteTag, metrics, evolutionShards, credits, totalWorkouts, streakDays, joinDate
        case avatarSystemName, blueprintCredits, sport, age, goal, hasCompletedOnboarding, systemScan
        case activeCreatorCard, ownedCardIds, completedAcademyModuleIds, equippedGearTexturePaths
        case linkedCoachCreatorId, coachInviteLinkedAt, supabaseUserId
    }

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
        completedAcademyModuleIds = (try? container.decode([String].self, forKey: .completedAcademyModuleIds)) ?? []
        equippedGearTexturePaths = (try? container.decode([String: String].self, forKey: .equippedGearTexturePaths)) ?? [:]
        linkedCoachCreatorId = try container.decodeIfPresent(String.self, forKey: .linkedCoachCreatorId)
        coachInviteLinkedAt = try container.decodeIfPresent(Date.self, forKey: .coachInviteLinkedAt)
        supabaseUserId = try container.decodeIfPresent(String.self, forKey: .supabaseUserId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(athleteTag, forKey: .athleteTag)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(evolutionShards, forKey: .evolutionShards)
        try container.encode(credits, forKey: .credits)
        try container.encode(totalWorkouts, forKey: .totalWorkouts)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encode(joinDate, forKey: .joinDate)
        try container.encode(avatarSystemName, forKey: .avatarSystemName)
        try container.encode(blueprintCredits, forKey: .blueprintCredits)
        try container.encodeIfPresent(sport, forKey: .sport)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(goal, forKey: .goal)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encodeIfPresent(systemScan, forKey: .systemScan)
        try container.encodeIfPresent(activeCreatorCard, forKey: .activeCreatorCard)
        try container.encode(ownedCardIds, forKey: .ownedCardIds)
        try container.encode(completedAcademyModuleIds, forKey: .completedAcademyModuleIds)
        try container.encode(equippedGearTexturePaths, forKey: .equippedGearTexturePaths)
        try container.encodeIfPresent(linkedCoachCreatorId, forKey: .linkedCoachCreatorId)
        try container.encodeIfPresent(coachInviteLinkedAt, forKey: .coachInviteLinkedAt)
        try container.encodeIfPresent(supabaseUserId, forKey: .supabaseUserId)
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
        ownedCardIds: [],
        completedAcademyModuleIds: [],
        equippedGearTexturePaths: [:],
        linkedCoachCreatorId: nil,
        coachInviteLinkedAt: nil,
        supabaseUserId: nil
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
    /// Capture metadata (120/240 fps) for frame-accurate flight when pose pipeline supplies indices.
    var videoNominalFrameRateHz: Double?
    var toeOffFrameIndex: Int?
    var heelStrikeFrameIndex: Int?
    /// SFMA multi-segmental rotation screen: `false` = fail → Cloud Cortex must prescribe Mod 4 + 90/90 rotation snack.
    var sfmaMultiSegmentalRotationPassed: Bool?

    enum CodingKeys: String, CodingKey {
        case id, date, prqScore, verticalEstimateInches, flightTimeSeconds, movementGrade, notes, recommendedTrack, avatarConfig
        case videoNominalFrameRateHz, toeOffFrameIndex, heelStrikeFrameIndex
        case sfmaMultiSegmentalRotationPassed
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
        videoNominalFrameRateHz: Double? = nil,
        toeOffFrameIndex: Int? = nil,
        heelStrikeFrameIndex: Int? = nil,
        sfmaMultiSegmentalRotationPassed: Bool? = nil
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
        self.videoNominalFrameRateHz = videoNominalFrameRateHz
        self.toeOffFrameIndex = toeOffFrameIndex
        self.heelStrikeFrameIndex = heelStrikeFrameIndex
        self.sfmaMultiSegmentalRotationPassed = sfmaMultiSegmentalRotationPassed
    }

    /// Returns a copy of this result with a new avatar config (e.g. after user customization).
    nonisolated func withAvatarConfig(_ newConfig: AvatarSkinConfig) -> SystemScanResult {
        SystemScanResult(
            id: id,
            date: date,
            prqScore: prqScore,
            verticalEstimateInches: verticalEstimateInches,
            flightTimeSeconds: flightTimeSeconds,
            movementGrade: movementGrade,
            notes: notes,
            recommendedTrack: recommendedTrack,
            avatarConfig: newConfig,
            videoNominalFrameRateHz: videoNominalFrameRateHz,
            toeOffFrameIndex: toeOffFrameIndex,
            heelStrikeFrameIndex: heelStrikeFrameIndex,
            sfmaMultiSegmentalRotationPassed: sfmaMultiSegmentalRotationPassed
        )
    }

    /// Showcase Demo Mode: reuse cached rig/PRQ without re-running analysis (new id + timestamp).
    nonisolated func demoFastTrackClone() -> SystemScanResult {
        let tag = "Demo Fast-Track — cached AvatarRig (no re-scan)."
        var nextNotes = notes
        if !nextNotes.contains(where: { $0 == tag }) {
            nextNotes.append(tag)
        }
        return SystemScanResult(
            id: UUID().uuidString,
            date: Date(),
            prqScore: prqScore,
            verticalEstimateInches: verticalEstimateInches,
            flightTimeSeconds: flightTimeSeconds,
            movementGrade: movementGrade,
            notes: nextNotes,
            recommendedTrack: recommendedTrack,
            avatarConfig: avatarConfig,
            videoNominalFrameRateHz: videoNominalFrameRateHz,
            toeOffFrameIndex: toeOffFrameIndex,
            heelStrikeFrameIndex: heelStrikeFrameIndex,
            sfmaMultiSegmentalRotationPassed: sfmaMultiSegmentalRotationPassed
        )
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
        videoNominalFrameRateHz = try container.decodeIfPresent(Double.self, forKey: .videoNominalFrameRateHz)
        toeOffFrameIndex = try container.decodeIfPresent(Int.self, forKey: .toeOffFrameIndex)
        heelStrikeFrameIndex = try container.decodeIfPresent(Int.self, forKey: .heelStrikeFrameIndex)
        sfmaMultiSegmentalRotationPassed = try container.decodeIfPresent(Bool.self, forKey: .sfmaMultiSegmentalRotationPassed)
    }

    nonisolated func encode(to encoder: Encoder) throws {
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
        try container.encodeIfPresent(videoNominalFrameRateHz, forKey: .videoNominalFrameRateHz)
        try container.encodeIfPresent(toeOffFrameIndex, forKey: .toeOffFrameIndex)
        try container.encodeIfPresent(heelStrikeFrameIndex, forKey: .heelStrikeFrameIndex)
        try container.encodeIfPresent(sfmaMultiSegmentalRotationPassed, forKey: .sfmaMultiSegmentalRotationPassed)
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
