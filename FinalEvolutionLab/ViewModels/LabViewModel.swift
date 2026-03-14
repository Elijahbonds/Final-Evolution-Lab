import SwiftUI

@Observable
@MainActor
class LabViewModel {
    var profile: UserProfile
    var tracks: [CurriculumTrack] = SampleData.tracks
    var sessions: [WorkoutSession] = []
    var leaderboard: [LeaderboardEntry] = SampleData.leaderboard
    var selectedTrack: CurriculumTrack?
    var activeExercise: Exercise?
    var isWorkoutActive: Bool = false
    var workoutTimer: Int = 0
    var completedExerciseIds: Set<String> = []

    var neuralDrivePhase: Double = 0
    var healthKit = HealthKitService()
    var coachEconomy: CoachEconomy = SaveSystem.loadCoachEconomy()
    var gameResults: [GameSessionResult] = SaveSystem.loadGameResults()
    var creatorMarketplace: CreatorCardMarketplaceState = SaveSystem.loadCreatorMarketplace()
    var eventHub: EventHubState = SaveSystem.loadEventHub()
    var academyProgress: AcademyProgressState = SaveSystem.loadAcademyProgress()
    var cloneProfile: CloneProfile = .generic
    var movementDatabase: MovementDatabase = SaveSystem.loadMovementDatabase()
    var bondsAIStudio: BondsAIStudioState = SaveSystem.loadBondsAIStudio()
    var lastSessionReadiness: Double = 50

    var biomechanicsAudit: BiomechanicsAudit?
    var globalLeaderboard = GlobalLeaderboardService()
    var critiqueRequests: [CritiqueRequest] = SaveSystem.loadCritiqueRequests()
    private let liveVotingSocket = LiveVotingSocketService()
    private let movementIngestionService = MovementIngestionService()
    private let bondsBlueprintGenerator = BondsBlueprintGenerationService()
    private let narrationSpeechService = NarrationSpeechService()

    init() {
        self.profile = SaveSystem.loadProfile()
        self.sessions = SaveSystem.loadSessions()
        self.cloneProfile = SaveSystem.loadCloneProfile() ?? CloneProfile.makeDefault(from: profile)
        self.movementDatabase = SaveSystem.loadMovementDatabase()
        self.bondsAIStudio = SaveSystem.loadBondsAIStudio()
        seedEventHubIfNeeded()
        seedDigitalClonePipelineIfNeeded()
        seedBondsAIStudioIfNeeded()

        if let scan = profile.systemScan {
            self.biomechanicsAudit = BiomechanicsAudit.fromScanResult(scan)
        }

        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard)

        Task {
            await hydrateFromCloudSnapshotIfAvailable()
        }

        if healthKit.isAuthorized {
            Task {
                await healthKit.fetchLatestData()
                applyHealthKitData()
            }
        }
    }

    private func hydrateFromCloudSnapshotIfAvailable() async {
        await SaveSystem.refreshFromCloudIfAvailable()

        profile = SaveSystem.loadProfile()
        sessions = SaveSystem.loadSessions()
        coachEconomy = SaveSystem.loadCoachEconomy()
        gameResults = SaveSystem.loadGameResults()
        critiqueRequests = SaveSystem.loadCritiqueRequests()
        creatorMarketplace = SaveSystem.loadCreatorMarketplace()
        eventHub = SaveSystem.loadEventHub()
        academyProgress = SaveSystem.loadAcademyProgress()
        cloneProfile = SaveSystem.loadCloneProfile() ?? CloneProfile.makeDefault(from: profile)
        movementDatabase = SaveSystem.loadMovementDatabase()
        bondsAIStudio = SaveSystem.loadBondsAIStudio()

        if let scan = profile.systemScan {
            biomechanicsAudit = BiomechanicsAudit.fromScanResult(scan)
        } else {
            biomechanicsAudit = nil
        }

        seedEventHubIfNeeded()
        seedDigitalClonePipelineIfNeeded()
        seedBondsAIStudioIfNeeded()

        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard)
    }

    private func seedEventHubIfNeeded() {
        if eventHub.events.isEmpty {
            eventHub = EventTicketingSeedData.makeInitialState()
            SaveSystem.saveEventHub(eventHub)
        }
    }

    private func seedDigitalClonePipelineIfNeeded() {
        var didMutate = false

        if cloneProfile.cloneId == CloneProfile.generic.cloneId && !profile.id.hasPrefix("guest_") {
            cloneProfile = CloneProfile.makeDefault(from: profile)
            didMutate = true
        }

        let migrated = movementIngestionService.migrateLegacyReferencesIfNeeded(
            database: movementDatabase,
            cloneProfile: cloneProfile
        )
        if migrated.migrationVersion != movementDatabase.migrationVersion ||
            migrated.assets.count != movementDatabase.assets.count ||
            migrated.lastIngestedAt != movementDatabase.lastIngestedAt {
            movementDatabase = migrated
            didMutate = true
        }

        if didMutate {
            SaveSystem.saveCloneProfile(cloneProfile)
            SaveSystem.saveMovementDatabase(movementDatabase)
        }
    }

    private func seedBondsAIStudioIfNeeded() {
        var didMutate = false
        if bondsAIStudio.modelProfile == nil {
            bondsAIStudio.modelProfile = bondsBlueprintGenerator.defaultModelProfile(from: profile, cloneProfile: cloneProfile)
            didMutate = true
        }

        let curatedYouTubeSources = bondsBlueprintGenerator.curatedBondsBounceSourceAssets()
        for source in curatedYouTubeSources where !bondsAIStudio.sourceAssets.contains(where: { $0.id == source.id }) {
            bondsAIStudio.sourceAssets.append(source)
            didMutate = true
        }

        if bondsAIStudio.projects.isEmpty,
           let model = bondsAIStudio.modelProfile {
            let legacySourceAssets = LegacyExerciseReferenceCatalog.referenceURLs.map { key, value in
                BlueprintSourceAsset(
                    id: BlueprintSourceAsset.makeId(url: value),
                    sourceType: .legacyReference,
                    sourceURL: value,
                    title: "Legacy Source \(key)",
                    notes: "Migrated source for blueprint recreation",
                    importedAt: Date()
                )
            }
            for source in legacySourceAssets where !bondsAIStudio.sourceAssets.contains(where: { $0.id == source.id }) {
                bondsAIStudio.sourceAssets.append(source)
            }
            let sourceAssets = bondsAIStudio.sourceAssets
            let project = bondsBlueprintGenerator.createProject(
                track: .foundations,
                equipment: .movementEducation,
                model: model,
                sourceAssets: sourceAssets,
                revisionFocus: "better sequencing, cue clarity, and safe landing mechanics"
            )
            bondsAIStudio.projects = [project]
            bondsAIStudio.activeProjectId = project.id
            didMutate = true
        }

        if didMutate {
            SaveSystem.saveBondsAIStudio(bondsAIStudio)
        }
    }

    var allExercises: [Exercise] {
        tracks.flatMap(\.exercises)
    }

    var ownedCreatorAssets: [CreatorCardAsset] {
        creatorMarketplace.inventory.filter { $0.ownerId == profile.id }
    }

    var activeAuctionListings: [CreatorCardAuctionListing] {
        creatorMarketplace.activeListings.filter { $0.status == .active }
    }

    var upcomingLiveEvents: [LiveEvent] {
        eventHub.events
            .filter { $0.endsAt > Date() }
            .sorted(by: { $0.startsAt < $1.startsAt })
    }

    var armoryTickets: [EventTicket] {
        eventHub.tickets
            .filter { $0.ownerUserId == profile.id }
            .sorted(by: { $0.purchasedAt > $1.purchasedAt })
    }

    var activeFundraisingGoals: [FundraisingGoal] {
        eventHub.fundraisingGoals
            .filter { $0.endDate > Date() }
            .sorted(by: { $0.endDate < $1.endDate })
    }

    func topDonors(for goalId: String, limit: Int = 10) -> [(userId: String, credits: Int)] {
        let grouped = Dictionary(grouping: eventHub.contributions.filter { $0.goalId == goalId }, by: \.contributorUserId)
        return grouped
            .map { ($0.key, $0.value.reduce(0, { $0 + $1.creditsAmount })) }
            .sorted(by: { $0.1 > $1.1 })
            .prefix(max(1, limit))
            .map { (userId: $0.0, credits: $0.1) }
    }

    @discardableResult
    func requestRealExerciseClip(exerciseId: String) -> Bool {
        guard allExercises.contains(where: { $0.id == exerciseId }) else { return false }
        movementDatabase.requestRealClip(for: exerciseId)
        SaveSystem.saveMovementDatabase(movementDatabase)
        return true
    }

    @discardableResult
    func attachLocalRealExerciseClip(exerciseId: String, localFilename: String, qualityScore: Double = 0.92) -> Bool {
        guard allExercises.contains(where: { $0.id == exerciseId }), !localFilename.isEmpty else { return false }
        let localAsset = ExerciseDemoAsset(
            id: ExerciseDemoAsset.makeId(exerciseId: exerciseId, sourceType: .localClip),
            exerciseId: exerciseId,
            motionAssetId: "local_clip_\(exerciseId)",
            sourceType: .localClip,
            referenceURL: LegacyExerciseReferenceCatalog.referenceURLs[exerciseId],
            localClipFilename: localFilename,
            keyPoseTimestamps: [],
            qualityScore: min(1.0, max(0.0, qualityScore)),
            retargetVersion: cloneProfile.retargetVersion,
            updatedAt: Date()
        )
        movementDatabase.upsert(localAsset)
        movementDatabase.clearRealClipRequest(for: exerciseId)
        SaveSystem.saveMovementDatabase(movementDatabase)
        return true
    }

    @discardableResult
    func ingestYouTubeBlueprintSources(_ urls: [String]) -> Int {
        let incoming = bondsBlueprintGenerator.sanitizeYouTubeSources(urls)
        guard !incoming.isEmpty else { return 0 }

        var insertedCount = 0
        for source in incoming {
            if !bondsAIStudio.sourceAssets.contains(where: { $0.id == source.id }) {
                bondsAIStudio.sourceAssets.append(source)
                insertedCount += 1
            }
        }
        if insertedCount > 0 {
            SaveSystem.saveBondsAIStudio(bondsAIStudio)
        }
        return insertedCount
    }

    func configureBondsAIModel(
        modelDisplayName: String? = nil,
        voiceDisplayName: String? = nil,
        localeIdentifier: String? = nil,
        toneStyle: String? = nil,
        speakingRate: Double? = nil,
        pitchMultiplier: Double? = nil,
        useForFitnessEducationTracks: Bool = true
    ) {
        var model = bondsAIStudio.modelProfile ?? bondsBlueprintGenerator.defaultModelProfile(from: profile, cloneProfile: cloneProfile)
        if let modelDisplayName, !modelDisplayName.isEmpty {
            model.modelDisplayName = modelDisplayName
        }
        if let voiceDisplayName, !voiceDisplayName.isEmpty {
            model.voiceProfile.displayName = voiceDisplayName
        }
        if let localeIdentifier, !localeIdentifier.isEmpty {
            model.voiceProfile.localeIdentifier = localeIdentifier
        }
        if let toneStyle, !toneStyle.isEmpty {
            model.voiceProfile.toneStyle = toneStyle
        }
        if let speakingRate {
            model.voiceProfile.speakingRate = min(0.65, max(0.35, speakingRate))
        }
        if let pitchMultiplier {
            model.voiceProfile.pitchMultiplier = min(1.35, max(0.75, pitchMultiplier))
        }
        model.useForFitnessEducationTracks = useForFitnessEducationTracks
        model.updatedAt = Date()

        bondsAIStudio.modelProfile = model
        SaveSystem.saveBondsAIStudio(bondsAIStudio)
    }

    @discardableResult
    func generateBondsBlueprintProject(
        track: TrainingTrack,
        equipment: EquipmentType = .movementEducation,
        revisionFocus: String = "improved mechanics, clearer cues, and smoother pacing"
    ) -> BondsBlueprintProject? {
        guard let model = bondsAIStudio.modelProfile else { return nil }
        let project = bondsBlueprintGenerator.createProject(
            track: track,
            equipment: equipment,
            model: model,
            sourceAssets: bondsAIStudio.sourceAssets,
            revisionFocus: revisionFocus
        )

        if let existingIndex = bondsAIStudio.projects.firstIndex(where: { $0.id == project.id }) {
            bondsAIStudio.projects[existingIndex] = project
        } else {
            bondsAIStudio.projects.append(project)
        }
        bondsAIStudio.activeProjectId = project.id
        SaveSystem.saveBondsAIStudio(bondsAIStudio)
        return project
    }

    func activateBondsProject(projectId: String) {
        guard bondsAIStudio.projects.contains(where: { $0.id == projectId }) else { return }
        bondsAIStudio.activeProjectId = projectId
        SaveSystem.saveBondsAIStudio(bondsAIStudio)
    }

    var activeBondsBlueprintProject: BondsBlueprintProject? {
        bondsAIStudio.activeProject
    }

    var activeBondsNarrationScript: String {
        activeBondsBlueprintProject?.fullNarrationScript ?? ""
    }

    func speakActiveBondsNarration() {
        guard let model = bondsAIStudio.modelProfile else { return }
        narrationSpeechService.speak(
            script: activeBondsNarrationScript,
            voiceProfile: model.voiceProfile
        )
    }

    func stopActiveBondsNarration() {
        narrationSpeechService.stopSpeaking()
    }

    var academyMasteryAverage: Double {
        let values = AcademyTrack.allCases.map { academyProgress.masteryByTrack[$0] ?? 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var unlockedPrestigeCount: Int {
        academyProgress.prestigeUnlockedIds.count
    }

    func selectMentor(_ mentor: MentorId) {
        academyProgress.selectedMentor = mentor
        SaveSystem.saveAcademyProgress(academyProgress)
    }

    @discardableResult
    func unlockAcademyKnowledgeNode(nodeId: String) -> Bool {
        guard let node = AcademyKnowledgeCatalog.starterNodes.first(where: { $0.id == nodeId }) else { return false }
        guard !academyProgress.unlockedKnowledgeNodeIds.contains(node.id) else { return false }
        guard node.prerequisiteNodeIds.allSatisfy({ academyProgress.unlockedKnowledgeNodeIds.contains($0) }) else { return false }
        guard profile.evolutionShards >= node.shardUnlockCost else { return false }

        profile.evolutionShards -= node.shardUnlockCost
        academyProgress.unlockNode(node)
        SaveSystem.saveProfile(profile)
        SaveSystem.saveAcademyProgress(academyProgress)
        return true
    }

    @discardableResult
    func resolveBrainBrawlMatch(track: AcademyTrack, wager: Int, didWin: Bool, sabotage: MentalDebuffType? = nil) -> Bool {
        let rules = BrainBrawlRulebook.default
        guard wager >= rules.minimumWager, wager <= rules.maximumWager else { return false }
        let sabotageCost = rules.debuffs.first(where: { $0.type == sabotage })?.shardCost ?? 0
        let totalCost = wager + sabotageCost
        guard profile.evolutionShards >= totalCost else { return false }

        profile.evolutionShards -= totalCost
        if didWin {
            // Winner receives their stake plus mirrored opponent stake.
            var payout = wager * 2
            if academyProgress.selectedMentor == .jax {
                payout += max(1, wager / 10)
            }
            profile.evolutionShards += payout
        }

        academyProgress.applyBrainBrawlResult(track: track, wager: wager, didWin: didWin, sabotageCost: sabotageCost)
        SaveSystem.saveProfile(profile)
        SaveSystem.saveAcademyProgress(academyProgress)
        return true
    }

    var todaysSessions: [WorkoutSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.date) }
    }

    var weeklyShards: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.shardsEarned }
    }

    func completeExercise(_ exercise: Exercise) {
        completedExerciseIds.insert(exercise.id)
        profile.metrics.neuralDrive = min(100, profile.metrics.neuralDrive + 2.5)
        profile.metrics.verticalPotential = min(100, profile.metrics.verticalPotential + 1.5)
        SaveSystem.saveProfile(profile)
    }

    func finishWorkout(for track: CurriculumTrack) {
        let completed = track.exercises.filter { completedExerciseIds.contains($0.id) }.count
        let rewards = ShardReward.forWorkout(exercisesCompleted: completed, trackDifficulty: track.difficulty)
        let totalShards = rewards.reduce(0) { $0 + $1.amount }
        let session = WorkoutSession(
            id: UUID().uuidString,
            trackId: track.id,
            date: Date(),
            exercisesCompleted: completed,
            totalExercises: track.totalExercises,
            durationSeconds: workoutTimer,
            shardsEarned: totalShards
        )
        sessions.append(session)
        profile.totalWorkouts += 1
        profile.evolutionShards += session.shardsEarned
        profile.metrics.prqScore = PRQ.clamp(profile.metrics.prqScore + Double(completed) * 0.5)
        profile.metrics.efficiencyScore = min(100, session.completionRate * 100)
        profile.metrics.verticalPotential = min(100, profile.metrics.verticalPotential + Double(completed) * 0.8)

        updateStreak()
        if profile.streakDays > 0 && profile.streakDays % 7 == 0 {
            profile.evolutionShards += 50
        }

        SaveSystem.saveProfile(profile)
        SaveSystem.saveSessions(sessions)

        isWorkoutActive = false
        workoutTimer = 0
        completedExerciseIds.removeAll()

        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard)
    }

    var effectiveMetrics: PerformanceMetrics {
        guard let card = profile.activeCreatorCard,
              let catalogCard = CreatorCard.catalog.first(where: { $0.id == card.cardId }),
              activeCreatorCardUtilityEnabled else {
            return profile.metrics
        }
        let boost = catalogCard.metricsBoost
        return PerformanceMetrics(
            efficiencyScore: min(100, profile.metrics.efficiencyScore + boost.efficiencyScore),
            prqScore: min(100, profile.metrics.prqScore + boost.prqScore),
            readinessScore: min(100, profile.metrics.readinessScore + boost.readinessScore),
            verticalPotential: min(100, profile.metrics.verticalPotential + boost.verticalPotential),
            neuralDrive: min(100, profile.metrics.neuralDrive + boost.neuralDrive),
            currentOutfit: boost.currentOutfit
        )
    }

    var arcadePhysics: ArcadePhysics {
        ArcadePhysics.fromPRQ(effectiveMetrics.prqScore, neuralDrive: effectiveMetrics.neuralDrive, audit: biomechanicsAudit)
    }

    var activeMovementSignature: MovementSignature {
        guard let card = profile.activeCreatorCard,
              let catalogCard = CreatorCard.catalog.first(where: { $0.id == card.cardId }),
              activeCreatorCardUtilityEnabled else {
            return MovementSignature(
                style: .standard,
                jumpApex: 1.0,
                hangTimeFactor: 1.0,
                firstStepBurst: 1.0,
                limbEmission: 0.3,
                trailColor: Theme.brandBlue
            )
        }
        return catalogCard.movementSignature
    }

    var userPRQTier: PRQTier {
        PRQTier.fromPRQ(effectiveMetrics.prqScore)
    }

    var totalGameWins: Int {
        gameResults.filter { $0.didWin }.count
    }

    var winRate: Double {
        guard !gameResults.isEmpty else { return 0 }
        return Double(totalGameWins) / Double(gameResults.count) * 100
    }

    func connectHealthKit() async {
        await healthKit.requestAuthorization()
        if healthKit.isAuthorized {
            await healthKit.fetchLatestData()
            applyHealthKitData()
        }
    }

    func refreshHealthData() async {
        guard healthKit.isAuthorized else { return }
        await healthKit.fetchLatestData()
        applyHealthKitData()
    }

    private func applyHealthKitData() {
        if healthKit.restingHeartRate > 0 {
            profile.metrics.readinessScore = calculateReadiness(rhr: healthKit.restingHeartRate)
        }

        let buff = healthKit.arcadePhysicsBuff
        if healthKit.hrvValue > 0 || healthKit.restingHeartRate > 0 {
            profile.metrics.neuralDrive = min(100, buff.neuralDriveOverride)
        }

        SaveSystem.saveProfile(profile)
    }

    private func calculateReadiness(rhr: Double) -> Double {
        let baseline: Double = 60
        let deviation = abs(rhr - baseline)
        return max(0, min(100, 100 - deviation * 2))
    }

    var healthKitBuff: ArcadePhysicsBuff {
        healthKit.arcadePhysicsBuff
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastSession = sessions.dropLast().last
        if let lastDate = lastSession?.date {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween <= 1 {
                profile.streakDays += 1
            } else {
                profile.streakDays = 1
            }
        } else {
            profile.streakDays = 1
        }
    }

    func completeOnboarding(sport: String, age: Int, goal: String) {
        profile.sport = sport
        profile.age = age
        profile.goal = goal
        profile.hasCompletedOnboarding = true
        SaveSystem.saveProfile(profile)
    }

    func applyScanResult(_ result: SystemScanResult) {
        profile.systemScan = result
        profile.metrics.prqScore = PRQ.clamp(result.prqScore)
        profile.metrics.verticalPotential = result.verticalEstimateInches
        profile.metrics.readinessScore = max(70, profile.metrics.readinessScore)
        profile.metrics.efficiencyScore = max(70, profile.metrics.efficiencyScore)
        cloneProfile.avatarConfig = result.avatarConfig

        biomechanicsAudit = BiomechanicsAudit.fromScanResult(result)

        if let prescription = result.movementScreening?.prescription {
            var trainingProgress = SaveSystem.loadTrainingProgress()
            trainingProgress.activeTrack = prescription.trainingTrack
            trainingProgress.activeEquipment = prescription.equipmentFocus
            SaveSystem.saveTrainingProgress(trainingProgress)

            if let mappedTrack = tracks.first(where: { track in
                switch prescription.trainingTrack {
                case .foundations: return track.difficulty == .foundation
                case .flight: return track.difficulty == .flight
                case .elite: return track.difficulty == .elite
                }
            }) {
                selectedTrack = mappedTrack
            }
        }

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCloneProfile(cloneProfile)
        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard)
    }

    func ticketPricing(for eventId: String, tier: EventTicketTier) -> EventTicketPricing? {
        eventHub.ticketPricing.first(where: { $0.eventId == eventId && $0.tier == tier })
    }

    func referralLink(for eventId: String) -> String {
        "fel://events/\(eventId)?ref=\(profile.id)"
    }

    @discardableResult
    func purchaseEventTicket(eventId: String, tier: EventTicketTier, referralSourceUserId: String? = nil) -> EventTicket? {
        guard let event = eventHub.events.first(where: { $0.id == eventId }),
              let pricing = ticketPricing(for: eventId, tier: tier) else { return nil }

        if let cap = event.ticketInventoryCap, eventHub.currentTicketSalesCount(for: eventId) >= cap {
            return nil
        }

        let hasDiscountPerk = hasCreatorCardTicketDiscount(for: event)
        let creditsToCharge = DualCurrencyReservoir.applyTicketDiscount(credits: pricing.priceInCredits, hasCreatorCardDiscount: hasDiscountPerk)
        let shardsToCharge = pricing.priceInShards
        guard profile.premiumCredits >= creditsToCharge, profile.evolutionShards >= shardsToCharge else { return nil }

        profile.premiumCredits -= creditsToCharge
        profile.evolutionShards -= shardsToCharge

        var shardBonus = pricing.shardBonusValue + DualCurrencyReservoir.ticketShardRebate(creditsSpent: creditsToCharge)
        let donorMultiplierBps = eventHub.donorShardMultiplierBpsByUser[profile.id] ?? 0
        if donorMultiplierBps > 0 {
            shardBonus += shardBonus * donorMultiplierBps / 10_000
        }
        profile.evolutionShards += shardBonus

        let nextTicketNumber = eventHub.currentTicketSalesCount(for: eventId) + 1
        let isGoldenTicket = nextTicketNumber % 100 == 0

        let ticketId = UUID().uuidString
        let ticket = EventTicket(
            id: ticketId,
            eventId: eventId,
            ownerUserId: profile.id,
            tier: tier,
            priceInCredits: creditsToCharge,
            priceInShards: shardsToCharge,
            shardBonusValue: shardBonus,
            qrPayload: EventTicketingDefaults.qrPayload(eventId: eventId, ticketId: ticketId, ownerUserId: profile.id),
            purchasedAt: Date(),
            checkedInAt: nil,
            referralSourceUserId: referralSourceUserId,
            containsGoldenTicket: isGoldenTicket
        )
        eventHub.tickets.append(ticket)
        if tier == .vipFrontRow {
            grantVipPerks(for: event)
        }

        if let referralSourceUserId, !referralSourceUserId.isEmpty, referralSourceUserId != profile.id {
            let referralBonus = DualCurrencyReservoir.referralShardBonus(baseShardBonus: shardBonus)
            eventHub.referralShardRewardsByUser[referralSourceUserId, default: 0] += referralBonus
        }

        if let teamId = event.teamId, creditsToCharge > 0 {
            applyFundraisingContribution(
                teamId: teamId,
                creditsAmount: creditsToCharge,
                source: .ticketPurchase
            )
        }

        applyHypeTrainIfNeeded(eventId: eventId)

        if isGoldenTicket {
            awardGoldenTicketReward(for: ticket)
        }

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        SaveSystem.saveEventHub(eventHub)
        return ticket
    }

    func donateToFundraisingGoal(goalId: String, creditsAmount: Int) -> Bool {
        guard creditsAmount > 0,
              profile.premiumCredits >= creditsAmount,
              let goal = eventHub.fundraisingGoals.first(where: { $0.id == goalId }) else { return false }

        profile.premiumCredits -= creditsAmount
        applyFundraisingContribution(teamId: goal.teamId, creditsAmount: creditsAmount, source: .directDonation)
        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        SaveSystem.saveEventHub(eventHub)
        return true
    }

    @discardableResult
    func claimReferralShardRewards() -> Int {
        let claimable = eventHub.referralShardRewardsByUser[profile.id] ?? 0
        guard claimable > 0 else { return 0 }
        profile.evolutionShards += claimable
        eventHub.referralShardRewardsByUser[profile.id] = 0
        SaveSystem.saveProfile(profile)
        SaveSystem.saveEventHub(eventHub)
        return claimable
    }

    @discardableResult
    func checkInTicket(ticketId: String) -> Bool {
        guard let ticketIndex = eventHub.tickets.firstIndex(where: {
            $0.id == ticketId && $0.ownerUserId == profile.id
        }) else { return false }
        guard eventHub.tickets[ticketIndex].checkedInAt == nil else { return false }
        guard let event = eventHub.events.first(where: { $0.id == eventHub.tickets[ticketIndex].eventId }) else { return false }
        let now = Date()
        guard event.startsAt <= now, event.endsAt >= now else { return false }

        eventHub.tickets[ticketIndex].checkedInAt = Date()
        profile.evolutionShards += 75
        eventHub.participationShardRewardsByUser[profile.id, default: 0] += 75
        SaveSystem.saveProfile(profile)
        SaveSystem.saveEventHub(eventHub)
        return true
    }

    func openLiveVoting(eventId: String) {
        let index: Int
        if let existing = eventHub.votingSessions.firstIndex(where: { $0.eventId == eventId }) {
            index = existing
        } else {
            eventHub.votingSessions.append(LiveVotingSession(eventId: eventId, isOpen: false, votes: [], participantRewardedUserIds: []))
            index = eventHub.votingSessions.count - 1
        }
        eventHub.votingSessions[index].isOpen = true
        _ = eventHub.ensureVotingSocket(for: eventId)
        SaveSystem.saveEventHub(eventHub)
    }

    @discardableResult
    func closeLiveVoting(eventId: String) -> String? {
        guard let index = eventHub.votingSessions.firstIndex(where: { $0.eventId == eventId }) else { return nil }
        eventHub.votingSessions[index].isOpen = false
        let summary = resolveLiveVotingOutcome(eventId: eventId)
        SaveSystem.saveEventHub(eventHub)
        SaveSystem.saveProfile(profile)
        liveVotingSocket.close(eventId: eventId)
        return summary
    }

    func connectLiveVotingSocket(eventId: String) -> AsyncStream<LiveVote> {
        _ = eventHub.ensureVotingSocket(for: eventId)
        SaveSystem.saveEventHub(eventHub)
        return liveVotingSocket.connect(eventId: eventId)
    }

    @discardableResult
    func submitLiveVote(eventId: String, score: Int) -> Bool {
        guard (1...10).contains(score),
              eventHub.userHasTicket(userId: profile.id, eventId: eventId),
              let sessionIndex = eventHub.votingSessions.firstIndex(where: { $0.eventId == eventId }),
              eventHub.votingSessions[sessionIndex].isOpen else { return false }

        if eventHub.votingSessions[sessionIndex].votes.contains(where: { $0.voterUserId == profile.id }) {
            return false
        }

        let vote = LiveVote(
            id: UUID().uuidString,
            eventId: eventId,
            voterUserId: profile.id,
            score: score,
            submittedAt: Date()
        )
        eventHub.votingSessions[sessionIndex].votes.append(vote)

        if !eventHub.votingSessions[sessionIndex].participantRewardedUserIds.contains(profile.id) {
            profile.evolutionShards += 35
            eventHub.votingSessions[sessionIndex].participantRewardedUserIds.append(profile.id)
            eventHub.participationShardRewardsByUser[profile.id, default: 0] += 35
        }

        SaveSystem.saveProfile(profile)
        SaveSystem.saveEventHub(eventHub)
        liveVotingSocket.publish(vote: vote)
        return true
    }

    private func resolveLiveVotingOutcome(eventId: String) -> String? {
        if let existing = eventHub.voteOutcomeByEvent?[eventId] {
            return existing.summary
        }
        guard let sessionIndex = eventHub.votingSessions.firstIndex(where: { $0.eventId == eventId }) else { return nil }
        let votes = eventHub.votingSessions[sessionIndex].votes

        let votesCount = votes.count
        let average = votesCount == 0 ? 0 : (Double(votes.reduce(0, { $0 + $1.score })) / Double(votesCount))
        let uniqueVoters = Set(votes.map(\.voterUserId))
        let pot = votesCount == 0 ? 0 : max(250, votesCount * 50)
        let perVoterReward = uniqueVoters.isEmpty ? 0 : (pot / uniqueVoters.count)

        if perVoterReward > 0, uniqueVoters.contains(profile.id) {
            profile.evolutionShards += perVoterReward
            eventHub.participationShardRewardsByUser[profile.id, default: 0] += perVoterReward
        }

        let summary: String
        if votesCount == 0 {
            summary = "Voting closed: no votes recorded"
        } else {
            summary = "Voting closed: avg \(String(format: "%.1f", average)), pot \(pot) shards"
        }

        eventHub.recordVotingOutcome(
            LiveVotingOutcome(
                eventId: eventId,
                closedAt: Date(),
                votesCount: votesCount,
                averageScore: average,
                shardPotDistributed: pot,
                summary: summary
            )
        )
        return summary
    }

    private func hasCreatorCardTicketDiscount(for event: LiveEvent) -> Bool {
        guard let headlinerId = event.headlinerCreatorId ?? event.headlinerCreatorName?.lowercased(),
              !headlinerId.isEmpty else { return false }
        return CreatorCard.catalog.contains { card in
            profile.ownsCard(card.id) &&
                (card.creatorId == headlinerId ||
                 card.creatorName.lowercased() == headlinerId.lowercased())
        }
    }

    private func applyFundraisingContribution(teamId: String, creditsAmount: Int, source: FundraisingContribution.ContributionSource) {
        guard let goalIndex = eventHub.fundraisingGoals.firstIndex(where: { $0.teamId == teamId && $0.endDate > Date() }) else { return }
        eventHub.fundraisingGoals[goalIndex].currentCredits += creditsAmount
        eventHub.contributions.append(
            FundraisingContribution(
                id: UUID().uuidString,
                goalId: eventHub.fundraisingGoals[goalIndex].id,
                teamId: teamId,
                contributorUserId: profile.id,
                creditsAmount: creditsAmount,
                source: source,
                createdAt: Date()
            )
        )
        unlockFundraisingRewardsIfNeeded(goalIndex: goalIndex)
    }

    private func unlockFundraisingRewardsIfNeeded(goalIndex: Int) {
        let percent = eventHub.fundraisingGoals[goalIndex].percentComplete
        let goal = eventHub.fundraisingGoals[goalIndex]
        for reward in eventHub.fundraisingGoals[goalIndex].milestoneRewards where
            reward.thresholdPercent <= percent &&
            !eventHub.fundraisingGoals[goalIndex].unlockedRewardIds.contains(reward.rewardId) {
            eventHub.fundraisingGoals[goalIndex].unlockedRewardIds.append(reward.rewardId)

            switch reward.rewardType {
            case .practiceJerseySkin:
                profile.blueprintCredits += 25
                profile.unlockedCosmeticRewardIds.append(reward.rewardId)
                if let teamIndex = eventHub.teams.firstIndex(where: { $0.id == goal.teamId }) {
                    if !eventHub.teams[teamIndex].unlockedCosmeticRewardIds.contains(reward.rewardId) {
                        eventHub.teams[teamIndex].unlockedCosmeticRewardIds.append(reward.rewardId)
                    }
                }
            case .dunkShowUnlock:
                if let teamIndex = eventHub.teams.firstIndex(where: { $0.id == goal.teamId }) {
                    if !eventHub.teams[teamIndex].unlockedEventRewardIds.contains(reward.rewardId) {
                        eventHub.teams[teamIndex].unlockedEventRewardIds.append(reward.rewardId)
                    }
                }
                createUnlockedDunkEventIfNeeded(goal: goal, rewardId: reward.rewardId)
            case .patronCreatorCard:
                if let topDonor = eventHub.topContributorUserId(for: eventHub.fundraisingGoals[goalIndex].id) {
                    eventHub.donorShardMultiplierBpsByUser[topDonor] =
                        max(eventHub.donorShardMultiplierBpsByUser[topDonor] ?? 0, 500)
                    if eventHub.patronCardOwnerByGoalId == nil {
                        eventHub.patronCardOwnerByGoalId = [:]
                    }
                    if eventHub.patronCardOwnerByGoalId?[goal.id] == nil {
                        eventHub.patronCardOwnerByGoalId?[goal.id] = topDonor
                        if topDonor == profile.id {
                            mintPatronRewardCard(goalId: goal.id)
                        }
                    }
                }
            }
        }
    }

    private func createUnlockedDunkEventIfNeeded(goal: FundraisingGoal, rewardId: String) {
        let unlockedEventId = "event_unlock_\(goal.teamId)_\(rewardId)"
        guard !eventHub.events.contains(where: { $0.id == unlockedEventId }) else { return }

        let start = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .hour, value: 3, to: start) ?? start.addingTimeInterval(10_800)
        let event = LiveEvent(
            id: unlockedEventId,
            kind: .dunkShow,
            title: "Unlocked Team Dunk Show",
            description: "Community-funded showcase unlocked by team milestone completion.",
            startsAt: start,
            endsAt: end,
            venueName: "Unlocked Local Court",
            teamId: goal.teamId,
            headlinerCreatorId: "coach_v",
            headlinerCreatorName: "Coach V",
            isStreamEnabled: true,
            ticketInventoryCap: 750
        )
        eventHub.events.append(event)
        eventHub.ticketPricing.append(
            contentsOf: [
                EventTicketPricing(eventId: event.id, tier: .generalAdmission, priceInCredits: 1000, priceInShards: 0, shardBonusValue: 300),
                EventTicketPricing(eventId: event.id, tier: .vipFrontRow, priceInCredits: 1800, priceInShards: 150, shardBonusValue: 650),
                EventTicketPricing(eventId: event.id, tier: .virtual, priceInCredits: 0, priceInShards: 350, shardBonusValue: 200),
            ]
        )
        eventHub.votingSessions.append(
            LiveVotingSession(eventId: event.id, isOpen: false, votes: [], participantRewardedUserIds: [])
        )
    }

    private func mintPatronRewardCard(goalId: String) {
        guard let template = CreatorCard.catalog.first else { return }
        let alreadyMinted = creatorMarketplace.inventory.contains(where: {
            $0.ownerId == profile.id &&
            $0.source == .reward &&
            $0.signatureYear == Calendar.current.component(.year, from: Date()) &&
            $0.signedByCreatorId == "patron_\(goalId)"
        })
        guard !alreadyMinted else { return }

        let asset = CreatorCardAsset(
            id: UUID().uuidString,
            templateCardId: template.id,
            ownerId: profile.id,
            rarity: .signature,
            acquiredAt: Date(),
            source: .reward,
            maintenanceExpiresAt: Date().addingTimeInterval(Double(14 * 24 * 3600)),
            totalMaintenanceShardsPaid: 0,
            isLockedInAuction: false,
            signedByCreatorId: "patron_\(goalId)",
            signatureYear: Calendar.current.component(.year, from: Date()),
            signatureSerial: 1
        )
        creatorMarketplace.inventory.append(asset)
        if !profile.ownsCard(template.id) {
            profile.ownedCardIds.append(template.id)
        }
    }

    private func applyHypeTrainIfNeeded(eventId: String) {
        let soldCount = eventHub.currentTicketSalesCount(for: eventId)
        let latestCheckpoint = soldCount / 10
        let previousCheckpoint = eventHub.hypeTrainCheckpointByEvent[eventId] ?? 0
        guard latestCheckpoint > previousCheckpoint else { return }

        eventHub.hypeTrainCheckpointByEvent[eventId] = latestCheckpoint

        // In single-user local mode, apply to the active user if they hold a ticket.
        if eventHub.userHasTicket(userId: profile.id, eventId: eventId) {
            let checkpointGain = latestCheckpoint - previousCheckpoint
            let shardReward = checkpointGain * 75
            profile.evolutionShards += shardReward
            eventHub.participationShardRewardsByUser[profile.id, default: 0] += shardReward
        }
    }

    private func awardGoldenTicketReward(for ticket: EventTicket) {
        profile.evolutionShards += 2_500
        eventHub.goldenTicketWinners[ticket.id] = "Legendary Shard Pack (+2500)"

        guard let template = CreatorCard.catalog.randomElement() else { return }
        let bonusAsset = CreatorCardAsset(
            id: UUID().uuidString,
            templateCardId: template.id,
            ownerId: profile.id,
            rarity: .legendary,
            acquiredAt: Date(),
            source: .reward,
            maintenanceExpiresAt: Date().addingTimeInterval(Double(72 * 3600)),
            totalMaintenanceShardsPaid: 0,
            isLockedInAuction: false,
            signedByCreatorId: nil,
            signatureYear: nil,
            signatureSerial: nil
        )
        creatorMarketplace.inventory.append(bonusAsset)
        if !profile.ownsCard(template.id) {
            profile.ownedCardIds.append(template.id)
        }
    }

    private func grantVipPerks(for event: LiveEvent) {
        guard let headlinerId = event.headlinerCreatorId ?? event.headlinerCreatorName?.lowercased(),
              let template = CreatorCard.catalog.first(where: {
                  $0.creatorId == headlinerId || $0.creatorName.lowercased() == headlinerId.lowercased()
              }) else { return }

        let vipAsset = CreatorCardAsset(
            id: UUID().uuidString,
            templateCardId: template.id,
            ownerId: profile.id,
            rarity: .epic,
            acquiredAt: Date(),
            source: .reward,
            maintenanceExpiresAt: Date().addingTimeInterval(Double(7 * 24 * 3600)),
            totalMaintenanceShardsPaid: 0,
            isLockedInAuction: false,
            signedByCreatorId: nil,
            signatureYear: nil,
            signatureSerial: nil
        )
        creatorMarketplace.inventory.append(vipAsset)
        if !profile.ownsCard(template.id) {
            profile.ownedCardIds.append(template.id)
        }
    }

    static let creatorPackCostShards = 300
    static let defaultAuctionDurationHours = 24
    static let defaultCardMaintenanceHours = 24 * 7
    static let critiqueCostCredits = 500
    static let critiqueEngagementShardBonus = 50
    static let critiqueCostShards = critiqueCostCredits // legacy alias

    func applyCreatorCard(_ card: CreatorCard) {
        let alreadyOwned = profile.ownsCard(card.id)
        let ownedAssetId = ensureOwnedAsset(for: card, alreadyOwned: alreadyOwned)
        guard let ownedAssetId else { return }

        profile.activeCreatorCard = CreatorCardState(
            cardId: card.id,
            creatorName: card.creatorName,
            appliedAt: Date(),
            assetInstanceId: ownedAssetId,
            costShards: card.costCredits, // legacy persisted key
            metricsBoost: card.metricsBoost
        )
        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
    }

    func equipOwnedCreatorCardAsset(assetId: String) -> Bool {
        guard let asset = creatorMarketplace.inventory.first(where: { $0.id == assetId && $0.ownerId == profile.id }),
              let card = CreatorCard.catalog.first(where: { $0.id == asset.templateCardId }) else { return false }

        profile.activeCreatorCard = CreatorCardState(
            cardId: card.id,
            creatorName: card.creatorName,
            appliedAt: Date(),
            assetInstanceId: asset.id,
            costShards: card.costCredits,
            metricsBoost: card.metricsBoost
        )
        SaveSystem.saveProfile(profile)
        return true
    }

    func clearCreatorCard() {
        profile.activeCreatorCard = nil
        SaveSystem.saveProfile(profile)
    }

    private var activeCreatorCardUtilityEnabled: Bool {
        guard let active = profile.activeCreatorCard else { return false }
        guard profile.evolutionShards > 0 else { return false }
        guard let assetId = active.assetInstanceId,
              let asset = creatorMarketplace.inventory.first(where: { $0.id == assetId && $0.ownerId == profile.id }) else {
            return true // Legacy cards without inventory instances remain usable while shards > 0.
        }
        return asset.utilityActive(now: Date(), currentShardBalance: profile.evolutionShards)
    }

    private func ensureOwnedAsset(for card: CreatorCard, alreadyOwned: Bool) -> String? {
        if !alreadyOwned {
            guard profile.premiumCredits >= card.costCredits else { return nil }
            profile.premiumCredits -= card.costCredits
            profile.ownedCardIds.append(card.id)
        }

        if let existing = creatorMarketplace.inventory.first(where: {
            $0.ownerId == profile.id && $0.templateCardId == card.id && !$0.isLockedInAuction
        }) {
            return existing.id
        }

        let asset = CreatorCardAsset(
            id: UUID().uuidString,
            templateCardId: card.id,
            ownerId: profile.id,
            rarity: .uncommon,
            acquiredAt: Date(),
            source: .directPurchase,
            maintenanceExpiresAt: Date().addingTimeInterval(Double(24 * 3600)),
            totalMaintenanceShardsPaid: 0,
            isLockedInAuction: false,
            signedByCreatorId: nil,
            signatureYear: nil,
            signatureSerial: nil
        )
        creatorMarketplace.inventory.append(asset)
        return asset.id
    }

    func requestCritique(exerciseName: String, notes: String) -> Bool {
        let cost = Self.critiqueCostCredits
        guard profile.premiumCredits >= cost else { return false }
        profile.premiumCredits -= cost
        profile.evolutionShards += Self.critiqueEngagementShardBonus

        let request = CritiqueRequest(
            id: UUID().uuidString,
            athleteId: profile.id,
            exerciseName: exerciseName,
            notes: notes,
            requestDate: Date(),
            shardsCost: cost, // legacy field; interpreted as credits
            status: .pending,
            coachResponse: nil
        )
        critiqueRequests.append(request)

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCritiqueRequests(critiqueRequests)
        return true
    }

    func requestCritiqueUsingShardBridge(exerciseName: String, notes: String, shardCost: Int = 500) -> Bool {
        let payoutCredits = Self.critiqueCostCredits
        guard shardCost > 0,
              profile.evolutionShards >= shardCost else { return false }

        let requestId = UUID().uuidString
        guard creatorMarketplace.reserveServicePoolCredits(requestId: requestId, credits: payoutCredits) else {
            return false
        }

        profile.evolutionShards -= shardCost
        creatorMarketplace.shardBurnedByServiceBridge += shardCost

        let request = CritiqueRequest(
            id: requestId,
            athleteId: profile.id,
            exerciseName: exerciseName,
            notes: notes,
            requestDate: Date(),
            shardsCost: shardCost,
            status: .pending,
            coachResponse: nil
        )
        critiqueRequests.append(request)

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return true
    }

    func reviewCritique(requestId: String, rating: Double) {
        guard let index = critiqueRequests.firstIndex(where: { $0.id == requestId && $0.status == .completed }) else { return }
        critiqueRequests[index].status = .rated

        coachEconomy.releaseCritique(critiqueId: requestId, athleteRating: rating)
        _ = creatorMarketplace.settleReservedServiceCredits(requestId: requestId)

        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCoachEconomy(coachEconomy)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
    }

    func simulateCoachResponse(requestId: String) {
        guard let index = critiqueRequests.firstIndex(where: { $0.id == requestId && $0.status == .pending }) else { return }
        critiqueRequests[index].status = .completed
        critiqueRequests[index].coachResponse = CritiqueResponse(
            coachName: "Coach V",
            responseDate: Date(),
            textFeedback: "Good intent on the load phase. Focus on maintaining ankle stiffness through ground contact. Your hip extension timing is slightly delayed — drill single-leg hip bridges before your next jump session.",
            overallGrade: "DEVELOPING",
            focusAreas: ["Ankle Stiffness", "Hip Extension", "Ground Contact"]
        )
        let heldCredits = creatorMarketplace.serviceFundingReservations[requestId] ?? critiqueRequests[index].creditsCost
        coachEconomy.completeCritique(credits: heldCredits, critiqueId: requestId)
        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCoachEconomy(coachEconomy)
    }

    @discardableResult
    func cancelPendingCritique(requestId: String) -> Bool {
        guard let index = critiqueRequests.firstIndex(where: {
            $0.id == requestId && ($0.status == .pending || $0.status == .inProgress)
        }) else { return false }
        critiqueRequests[index].status = .cancelled
        _ = creatorMarketplace.releaseReservedServiceCredits(requestId: requestId)
        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return true
    }

    @discardableResult
    func disputeCompletedCritique(requestId: String) -> Bool {
        guard let index = critiqueRequests.firstIndex(where: {
            $0.id == requestId && ($0.status == .completed || $0.status == .rated)
        }) else { return false }
        critiqueRequests[index].status = .disputed
        coachEconomy.markCritiqueDisputed(critiqueId: requestId)
        _ = creatorMarketplace.releaseReservedServiceCredits(requestId: requestId)
        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCoachEconomy(coachEconomy)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return true
    }

    func openCreatorPacks(count: Int = 1, odds: CreatorPackOdds = .myTeamStyle) -> [CreatorCardAsset] {
        let pulls = max(1, count)
        let totalCost = pulls * Self.creatorPackCostShards
        guard profile.evolutionShards >= totalCost, !CreatorCard.catalog.isEmpty else { return [] }

        profile.evolutionShards -= totalCost
        creatorMarketplace.shardBurnedByPackPulls += totalCost

        var pulledAssets: [CreatorCardAsset] = []
        for _ in 0..<pulls {
            guard let template = CreatorCard.catalog.randomElement() else { continue }
            let rarity = odds.rollRarity()
            let asset = CreatorCardAsset(
                id: UUID().uuidString,
                templateCardId: template.id,
                ownerId: profile.id,
                rarity: rarity,
                acquiredAt: Date(),
                source: .creatorPack,
                maintenanceExpiresAt: Date().addingTimeInterval(Double(24 * 3600)),
                totalMaintenanceShardsPaid: 0,
                isLockedInAuction: false,
                signedByCreatorId: nil,
                signatureYear: nil,
                signatureSerial: nil
            )
            creatorMarketplace.inventory.append(asset)
            if !profile.ownsCard(template.id) {
                profile.ownedCardIds.append(template.id)
            }
            pulledAssets.append(asset)
        }

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return pulledAssets
    }

    func signCardAsSignature(assetId: String, creatorId: String, year: Int = Calendar.current.component(.year, from: Date())) -> Bool {
        guard let index = creatorMarketplace.inventory.firstIndex(where: {
            $0.id == assetId && $0.ownerId == profile.id && !$0.isLockedInAuction
        }) else { return false }

        let mintedCount = creatorMarketplace.signatureMintCount(creatorId: creatorId, year: year)
        guard mintedCount < DualCurrencyReservoir.signatureAnnualCap else { return false }

        let serial = creatorMarketplace.recordSignatureMint(creatorId: creatorId, year: year)
        creatorMarketplace.inventory[index].rarity = .signature
        creatorMarketplace.inventory[index].signedByCreatorId = creatorId
        creatorMarketplace.inventory[index].signatureYear = year
        creatorMarketplace.inventory[index].signatureSerial = serial
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return true
    }

    func signCardAsSignature(assetId: String, year: Int = Calendar.current.component(.year, from: Date())) -> Bool {
        guard let asset = creatorMarketplace.inventory.first(where: { $0.id == assetId && $0.ownerId == profile.id }),
              let template = CreatorCard.catalog.first(where: { $0.id == asset.templateCardId }) else { return false }
        return signCardAsSignature(assetId: assetId, creatorId: template.creatorId, year: year)
    }

    func activateCardMaintenance(assetId: String, hours: Int = Self.defaultCardMaintenanceHours) -> Bool {
        guard let index = creatorMarketplace.inventory.firstIndex(where: {
            $0.id == assetId && $0.ownerId == profile.id
        }) else { return false }

        let durationHours = max(1, hours)
        let cost = max(1, creatorMarketplace.inventory[index].rarity.maintenanceShardFeePerHour * durationHours)
        guard profile.evolutionShards >= cost else { return false }

        profile.evolutionShards -= cost
        creatorMarketplace.shardBurnedByMaintenance += cost
        creatorMarketplace.inventory[index].totalMaintenanceShardsPaid += cost

        let now = Date()
        let base = max(now, creatorMarketplace.inventory[index].maintenanceExpiresAt ?? now)
        creatorMarketplace.inventory[index].maintenanceExpiresAt =
            Calendar.current.date(byAdding: .hour, value: durationHours, to: base) ??
            base.addingTimeInterval(Double(durationHours) * 3600)

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return true
    }

    func listOwnedCardForAuction(assetId: String, startingBidShards: Int, buyNowShards: Int?, durationHours: Int = Self.defaultAuctionDurationHours) -> Bool {
        guard startingBidShards > 0 else { return false }
        if let buyNowShards, buyNowShards <= startingBidShards { return false }
        guard let assetIndex = creatorMarketplace.inventory.firstIndex(where: {
            $0.id == assetId && $0.ownerId == profile.id && !$0.isLockedInAuction
        }) else { return false }
        guard !creatorMarketplace.activeListings.contains(where: { $0.assetId == assetId && $0.status == .active }) else { return false }

        let duration = max(1, durationHours)
        let listing = CreatorCardAuctionListing(
            id: UUID().uuidString,
            assetId: assetId,
            templateCardId: creatorMarketplace.inventory[assetIndex].templateCardId,
            sellerId: profile.id,
            listedAt: Date(),
            endsAt: Calendar.current.date(byAdding: .hour, value: duration, to: Date()) ?? Date().addingTimeInterval(Double(duration) * 3600),
            startingBidShards: startingBidShards,
            buyNowShards: buyNowShards,
            highestBid: nil,
            status: .active
        )

        creatorMarketplace.inventory[assetIndex].isLockedInAuction = true
        creatorMarketplace.activeListings.append(listing)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return true
    }

    func placeBidOnListing(listingId: String, bidAmountShards: Int) -> Bool {
        guard let index = creatorMarketplace.activeListings.firstIndex(where: { $0.id == listingId }) else { return false }
        guard creatorMarketplace.activeListings[index].isActive(now: Date()) else { return false }
        guard creatorMarketplace.activeListings[index].sellerId != profile.id else { return false }

        let currentBid = creatorMarketplace.activeListings[index].currentBidShards
        guard bidAmountShards > currentBid else { return false }

        let reserved = creatorMarketplace.bidEscrowAmount(listingId: listingId, bidderId: profile.id)
        let additionalToReserve = max(0, bidAmountShards - reserved)
        guard profile.evolutionShards >= additionalToReserve else { return false }

        // Prompt's bid constraint interpreted as available + reserved must exceed current high bid.
        guard (profile.evolutionShards + reserved) > currentBid else { return false }

        profile.evolutionShards -= additionalToReserve
        creatorMarketplace.setBidEscrowAmount(listingId: listingId, bidderId: profile.id, amount: bidAmountShards)

        creatorMarketplace.activeListings[index].highestBid = CreatorCardBid(
            bidderId: profile.id,
            amountShards: bidAmountShards,
            placedAt: Date()
        )
        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return true
    }

    func buyNowListing(listingId: String) -> Bool {
        guard let index = creatorMarketplace.activeListings.firstIndex(where: { $0.id == listingId }) else { return false }
        let listing = creatorMarketplace.activeListings[index]
        guard listing.isActive(now: Date()),
              listing.sellerId != profile.id,
              let buyNow = listing.buyNowShards else { return false }

        let reserved = creatorMarketplace.bidEscrowAmount(listingId: listing.id, bidderId: profile.id)
        let additionalRequired = max(0, buyNow - reserved)
        guard profile.evolutionShards >= additionalRequired else { return false }

        let success = finalizeAuctionSale(listingIndex: index, buyerId: profile.id, salePriceShards: buyNow)
        if success {
            SaveSystem.saveProfile(profile)
            SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        }
        return success
    }

    func settleExpiredAuctionListings() {
        let now = Date()
        let listingIds = creatorMarketplace.activeListings.filter { $0.status == .active && $0.endsAt <= now }.map(\.id)

        for listingId in listingIds {
            guard let index = creatorMarketplace.activeListings.firstIndex(where: { $0.id == listingId }) else { continue }
            let listing = creatorMarketplace.activeListings[index]

            if let winningBid = listing.highestBid {
                let sold = finalizeAuctionSale(listingIndex: index, buyerId: winningBid.bidderId, salePriceShards: winningBid.amountShards)
                if !sold, let failedIndex = creatorMarketplace.activeListings.firstIndex(where: { $0.id == listingId }) {
                    creatorMarketplace.activeListings[failedIndex].status = .expired
                    refundLocalEscrow(forListingId: listingId)
                    unlockAssetForListing(at: failedIndex)
                    creatorMarketplace.activeListings.remove(at: failedIndex)
                }
            } else {
                creatorMarketplace.activeListings[index].status = .cancelled
                refundLocalEscrow(forListingId: listingId)
                unlockAssetForListing(at: index)
                creatorMarketplace.activeListings.remove(at: index)
            }
        }

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
    }

    func seedMarketplaceDemoLiquidityIfNeeded() {
        let hasExternalListings = creatorMarketplace.activeListings.contains(where: { $0.sellerId != profile.id && $0.status == .active })
        guard !hasExternalListings else { return }
        guard !CreatorCard.catalog.isEmpty else { return }

        let templates = Array(CreatorCard.catalog.prefix(3))
        for (idx, template) in templates.enumerated() {
            let npcOwnerId = "npc_trader_\(idx + 1)"
            let rarity: CreatorCardRarity = idx == 0 ? .rare : (idx == 1 ? .epic : .legendary)
            let asset = CreatorCardAsset(
                id: UUID().uuidString,
                templateCardId: template.id,
                ownerId: npcOwnerId,
                rarity: rarity,
                acquiredAt: Date(),
                source: .reward,
                maintenanceExpiresAt: Date().addingTimeInterval(Double(48 * 3600)),
                totalMaintenanceShardsPaid: 0,
                isLockedInAuction: true,
                signedByCreatorId: nil,
                signatureYear: nil,
                signatureSerial: nil
            )
            creatorMarketplace.inventory.append(asset)

            let baseBid: Int
            switch rarity {
            case .rare: baseBid = 2000
            case .epic: baseBid = 3600
            case .legendary: baseBid = 6200
            default: baseBid = 1500
            }

            let listing = CreatorCardAuctionListing(
                id: UUID().uuidString,
                assetId: asset.id,
                templateCardId: template.id,
                sellerId: npcOwnerId,
                listedAt: Date(),
                endsAt: Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date().addingTimeInterval(Double(24 * 3600)),
                startingBidShards: baseBid,
                buyNowShards: baseBid * 2,
                highestBid: nil,
                status: .active
            )
            creatorMarketplace.activeListings.append(listing)
        }

        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
    }

    private func unlockAssetForListing(at listingIndex: Int) {
        let assetId = creatorMarketplace.activeListings[listingIndex].assetId
        if let assetIndex = creatorMarketplace.inventory.firstIndex(where: { $0.id == assetId }) {
            creatorMarketplace.inventory[assetIndex].isLockedInAuction = false
        }
    }

    private func refundLocalEscrow(forListingId listingId: String) {
        let released = creatorMarketplace.clearBidEscrows(for: listingId)
        if let localRefund = released[profile.id], localRefund > 0 {
            profile.evolutionShards += localRefund
        }
    }

    private func finalizeAuctionSale(listingIndex: Int, buyerId: String, salePriceShards: Int) -> Bool {
        guard listingIndex >= 0, listingIndex < creatorMarketplace.activeListings.count, salePriceShards > 0 else { return false }
        let listing = creatorMarketplace.activeListings[listingIndex]
        guard let assetIndex = creatorMarketplace.inventory.firstIndex(where: { $0.id == listing.assetId }) else { return false }

        let escrows = creatorMarketplace.bidEscrows(for: listing.id)
        let localEscrow = escrows[profile.id] ?? 0
        if buyerId == profile.id {
            let additionalNeeded = max(0, salePriceShards - localEscrow)
            guard profile.evolutionShards >= additionalNeeded else { return false }
            profile.evolutionShards -= additionalNeeded
            if localEscrow > salePriceShards {
                profile.evolutionShards += (localEscrow - salePriceShards)
            }
        } else if localEscrow > 0 {
            profile.evolutionShards += localEscrow
        }
        _ = creatorMarketplace.clearBidEscrows(for: listing.id)

        let taxShards = DualCurrencyReservoir.auctionTaxShards(for: salePriceShards)
        let sellerNetShards = max(0, salePriceShards - taxShards)

        creatorMarketplace.inventory[assetIndex].ownerId = buyerId
        creatorMarketplace.inventory[assetIndex].isLockedInAuction = false
        if listing.sellerId == profile.id {
            profile.evolutionShards += sellerNetShards
            if profile.activeCreatorCard?.assetInstanceId == listing.assetId && buyerId != profile.id {
                profile.activeCreatorCard = nil
            }
        }

        var royaltyCreditsPaid = 0
        if let signedCreatorId = creatorMarketplace.inventory[assetIndex].signedByCreatorId {
            let royaltyCredits = DualCurrencyReservoir.signatureRoyaltyCredits(fromSaleShards: salePriceShards)
            if royaltyCredits > 0 && creatorMarketplace.servicePoolAvailableCredits >= royaltyCredits {
                creatorMarketplace.servicePoolAvailableCredits -= royaltyCredits
                creatorMarketplace.addRoyaltyCredits(creatorId: signedCreatorId, credits: royaltyCredits)
                if signedCreatorId == profile.id {
                    profile.creatorCredits += royaltyCredits
                }
                royaltyCreditsPaid = royaltyCredits
            }
        }

        creatorMarketplace.shardBurnedByAuctionTax += taxShards
        creatorMarketplace.activeListings.remove(at: listingIndex)
        creatorMarketplace.salesHistory.append(
            CreatorCardAuctionSale(
                id: UUID().uuidString,
                listingId: listing.id,
                assetId: listing.assetId,
                templateCardId: listing.templateCardId,
                sellerId: listing.sellerId,
                buyerId: buyerId,
                salePriceShards: salePriceShards,
                burnedTaxShards: taxShards,
                sellerNetShards: sellerNetShards,
                royaltyCreditsPaid: royaltyCreditsPaid,
                soldAt: Date()
            )
        )
        return true
    }

    @discardableResult
    func withdrawCreatorCredits() -> Int {
        let claimed = coachEconomy.claimEarnings()
        profile.creatorCredits += claimed
        SaveSystem.saveCoachEconomy(coachEconomy)
        SaveSystem.saveProfile(profile)
        return claimed
    }

    @discardableResult
    func claimSignatureRoyaltyCredits(creatorId: String) -> Int {
        let claimed = creatorMarketplace.claimRoyaltyCredits(creatorId: creatorId)
        guard claimed > 0 else { return 0 }
        profile.creatorCredits += claimed
        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return claimed
    }

    var myClaimableRoyaltyCredits: Int {
        creatorAliasesForCurrentUser()
            .reduce(0) { $0 + (creatorMarketplace.royaltyCreditsByCreatorId[$1] ?? 0) }
    }

    @discardableResult
    func claimMySignatureRoyaltyCredits() -> Int {
        let aliases = creatorAliasesForCurrentUser()
        var totalClaimed = 0
        for alias in aliases {
            totalClaimed += creatorMarketplace.claimRoyaltyCredits(creatorId: alias)
        }
        guard totalClaimed > 0 else { return 0 }
        profile.creatorCredits += totalClaimed
        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return totalClaimed
    }

    func purchaseCredits(_ credits: Int) {
        guard credits > 0 else { return }
        profile.premiumCredits += credits
        SaveSystem.saveProfile(profile)
    }

    func buyShardsUsingCredits(creditsToSpend: Int) -> Bool {
        guard creditsToSpend > 0, profile.premiumCredits >= creditsToSpend else { return false }
        profile.premiumCredits -= creditsToSpend
        profile.evolutionShards += DualCurrencyReservoir.shardsFromCredits(creditsToSpend)

        let funded = DualCurrencyReservoir.servicePoolFundingCredits(fromShardConversionCredits: creditsToSpend)
        creatorMarketplace.fundServicePool(credits: funded)

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCreatorMarketplace(creatorMarketplace)
        return true
    }

    private func creatorAliasesForCurrentUser() -> [String] {
        let normalizedDisplayName = profile.displayName
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "_" }
            .reduce(into: "") { partial, char in
                if char == "_" && partial.last == "_" { return }
                partial.append(char)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return Array(Set([profile.id, normalizedDisplayName]))
    }
}
