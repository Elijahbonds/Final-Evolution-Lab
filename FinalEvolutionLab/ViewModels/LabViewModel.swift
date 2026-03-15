import SwiftUI

@Observable
@MainActor
class LabViewModel {
    var profile: UserProfile
    var tracks: [CurriculumTrack] = SampleData.tracks
    var sessions: [WorkoutSession] = []
    var leaderboard: [LeaderboardEntry] = SampleData.leaderboard
    var selectedTrack: CurriculumTrack?
    /// When set, Training tab will switch to this track on next appear (used by Lab Quick Start).
    var preselectedTrack: TrainingTrack?
    /// When set, Arena tab will open this mode on next appear (e.g. Brain Brawl from Games dashboard).
    var preselectedArenaModeId: GameModeId?
    var activeExercise: Exercise?
    var isWorkoutActive: Bool = false
    var workoutTimer: Int = 0
    var completedExerciseIds: Set<String> = []

    var neuralDrivePhase: Double = 0
    var healthKit = HealthKitService()
    var coachEconomy: CoachEconomy = SaveSystem.loadCoachEconomy()
    var gameResults: [GameSessionResult] = SaveSystem.loadGameResults()
    var lastSessionReadiness: Double = 50

    var biomechanicsAudit: BiomechanicsAudit?
    var globalLeaderboard = GlobalLeaderboardService()
    var critiqueRequests: [CritiqueRequest] = SaveSystem.loadCritiqueRequests()
    var multipeerService = MultipeerService()

    init() {
        self.profile = SaveSystem.loadProfile()
        self.sessions = SaveSystem.loadSessions()

        if profile.systemScan == nil {
            applyScanResult(SystemScanResult.defaultForProfile(profile))
        }

        if let scan = profile.systemScan {
            self.biomechanicsAudit = BiomechanicsAudit.fromScanResult(scan)
        }

        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard, effectivePrq: effectiveMetrics.prqScore)

        if healthKit.isAuthorized {
            Task {
                await healthKit.fetchLatestData()
                applyHealthKitData()
            }
        }
    }

    var allExercises: [Exercise] {
        tracks.flatMap(\.exercises)
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

    /// Program(): Recommends training track from PRQ, Pop Force, and biomechanics audit (deficiency-driven prescription).
    var recommendedTrackFromAudit: TrainingTrack? {
        let prq = profile.metrics.prqScore
        let popForce = profile.metrics.popForce
        let audit = biomechanicsAudit
        let leakage = audit?.leakagePercentage ?? 0
        if prq < 50 || leakage > 50 || popForce < 35 {
            return .foundations
        }
        if prq < 65 || audit?.overallGrade == .developing || popForce < 55 {
            return .flight
        }
        return .elite
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

        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard, effectivePrq: effectiveMetrics.prqScore)
    }

    // MARK: - Fuel the Freeway (Photo-to-Shard nutrition)
    /// When true, Fuel UI shows "Congestion Alert" — roadblock on CNS Freeway; Movement Snack clears it.
    var hasCongestionAlert: Bool = false

    func applyMealLogRewards(structuralRepair: Bool, fascialElasticity: Bool, signalVelocity: Bool, congestionCleared: Bool) {
        let rewards = ShardReward.forMealLog(
            structuralRepair: structuralRepair,
            fascialElasticity: fascialElasticity,
            signalVelocity: signalVelocity,
            hadCongestionCleared: congestionCleared
        )
        let total = rewards.reduce(0) { $0 + $1.amount }
        profile.evolutionShards += total
        SaveSystem.saveProfile(profile)
    }

    func setCongestionAlert(_ value: Bool) {
        hasCongestionAlert = value
    }

    /// User completed a Movement Snack; clear congestion and award shards if applicable.
    func clearCongestion() {
        hasCongestionAlert = false
    }

    var effectiveMetrics: PerformanceMetrics {
        let basePrq = PRQ.clamp(profile.metrics.prqScore)
        guard let card = profile.activeCreatorCard,
              let catalogCard = CreatorCard.catalog.first(where: { $0.id == card.cardId }) else {
            return PerformanceMetrics(
                efficiencyScore: profile.metrics.efficiencyScore,
                prqScore: basePrq,
                readinessScore: profile.metrics.readinessScore,
                verticalPotential: profile.metrics.verticalPotential,
                neuralDrive: profile.metrics.neuralDrive,
                popForce: profile.metrics.popForce,
                currentOutfit: profile.metrics.currentOutfit
            )
        }
        let boost = catalogCard.metricsBoost
        return PerformanceMetrics(
            efficiencyScore: min(100, profile.metrics.efficiencyScore + boost.efficiencyScore),
            prqScore: PRQ.clamp(min(100, basePrq + boost.prqScore)),
            readinessScore: min(100, profile.metrics.readinessScore + boost.readinessScore),
            verticalPotential: min(100, profile.metrics.verticalPotential + boost.verticalPotential),
            neuralDrive: min(100, profile.metrics.neuralDrive + boost.neuralDrive),
            popForce: min(100, profile.metrics.popForce + boost.popForce),
            currentOutfit: boost.currentOutfit
        )
    }

    func applyScanResult(_ result: SystemScanResult) {
        profile.systemScan = result
        profile.metrics.prqScore = PRQ.clamp(result.prqScore)
        profile.metrics.verticalPotential = result.verticalEstimateInches
        profile.metrics.readinessScore = max(70, profile.metrics.readinessScore)
        let derivedPop = Self.derivePopForceFromScan(
            flightTimeSeconds: result.flightTimeSeconds,
            verticalInches: result.verticalEstimateInches,
            prq: result.prqScore
        )
        profile.metrics.popForce = derivedPop
        profile.metrics.efficiencyScore = max(70, min(100, profile.metrics.efficiencyScore * 0.6 + derivedPop * 0.4))

        biomechanicsAudit = BiomechanicsAudit.fromScanResult(result)

        SaveSystem.saveProfile(profile)
        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard, effectivePrq: effectiveMetrics.prqScore)
    }

    /// Derives Pop Force (RFD/GRF proxy) from scan: flight time = reactivity, vertical = output.
    static func derivePopForceFromScan(flightTimeSeconds: Double, verticalInches: Double, prq: Double) -> Double {
        let flightComponent = min(50, flightTimeSeconds * 80)
        let verticalComponent = min(40, verticalInches * 1.25)
        let prqComponent = prq * 0.1
        return PRQ.clamp(flightComponent + verticalComponent + prqComponent)
    }

    var arcadePhysics: ArcadePhysics {
        ArcadePhysics.fromPRQ(effectiveMetrics.prqScore, neuralDrive: effectiveMetrics.neuralDrive, audit: biomechanicsAudit)
    }

    var activeMovementSignature: MovementSignature {
        guard let card = profile.activeCreatorCard,
              let catalogCard = CreatorCard.catalog.first(where: { $0.id == card.cardId }) else {
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


    func applyCreatorCard(_ card: CreatorCard) {
        let alreadyOwned = profile.ownsCard(card.id)
        if !alreadyOwned {
            guard profile.evolutionShards >= card.costShards else { return }
            profile.evolutionShards -= card.costShards
            profile.ownedCardIds.append(card.id)
        }
        let oneWeekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        profile.activeCreatorCard = CreatorCardState(
            cardId: card.id,
            creatorName: card.creatorName,
            appliedAt: Date(),
            costShards: card.costShards,
            metricsBoost: card.metricsBoost,
            nextTaxDue: oneWeekFromNow,
            weeklyTaxShards: Self.weeklyCardTaxShards
        )
        SaveSystem.saveProfile(profile)
    }

    func clearCreatorCard() {
        profile.activeCreatorCard = nil
        SaveSystem.saveProfile(profile)
    }

    static let critiqueCostShards = 500
    /// Weekly Shard tax to keep equipped Creator Card buffs active (Spatial Sports Economy).
    static let weeklyCardTaxShards = 25

    func requestCritique(exerciseName: String, notes: String) -> Bool {
        let cost = Self.critiqueCostShards
        guard profile.evolutionShards >= cost else { return false }
        profile.evolutionShards -= cost

        let request = CritiqueRequest(
            id: UUID().uuidString,
            athleteId: profile.id,
            exerciseName: exerciseName,
            notes: notes,
            requestDate: Date(),
            shardsCost: cost,
            status: .pending,
            coachResponse: nil
        )
        critiqueRequests.append(request)

        coachEconomy.completeCritique(shards: cost, critiqueId: request.id)

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCoachEconomy(coachEconomy)
        return true
    }

    func reviewCritique(requestId: String, rating: Double) {
        guard let index = critiqueRequests.firstIndex(where: { $0.id == requestId && $0.status == .completed }) else { return }
        critiqueRequests[index].status = .rated

        coachEconomy.releaseCritique(critiqueId: requestId, athleteRating: rating)

        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCoachEconomy(coachEconomy)
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
        SaveSystem.saveCritiqueRequests(critiqueRequests)
    }
}

