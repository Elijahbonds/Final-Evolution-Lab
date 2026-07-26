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
    var lastSessionReadiness: Double = 50

    var biomechanicsAudit: BiomechanicsAudit?
    var globalLeaderboard = GlobalLeaderboardService()
    var critiqueRequests: [CritiqueRequest] = SaveSystem.loadCritiqueRequests()

    init() {
        self.profile = SaveSystem.loadProfile()
        self.sessions = SaveSystem.loadSessions()

        if let scan = profile.systemScan {
            self.biomechanicsAudit = BiomechanicsAudit.fromScanResult(scan)
        }

        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard)

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
              let catalogCard = CreatorCard.catalog.first(where: { $0.id == card.cardId }) else {
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

    func applyScanResult(_ result: SystemScanResult) {
        profile.systemScan = result
        profile.metrics.prqScore = PRQ.clamp(result.prqScore)
        profile.metrics.verticalPotential = result.verticalEstimateInches
        profile.metrics.readinessScore = max(70, profile.metrics.readinessScore)
        profile.metrics.efficiencyScore = max(70, profile.metrics.efficiencyScore)

        biomechanicsAudit = BiomechanicsAudit.fromScanResult(result)

        SaveSystem.saveProfile(profile)
        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard)
    }

    func applyCreatorCard(_ card: CreatorCard) {
        let alreadyOwned = profile.ownsCard(card.id)
        if !alreadyOwned {
            guard profile.evolutionShards >= card.costShards else { return }
            profile.evolutionShards -= card.costShards
            profile.ownedCardIds.append(card.id)
        }
        profile.activeCreatorCard = CreatorCardState(
            cardId: card.id,
            creatorName: card.creatorName,
            appliedAt: Date(),
            costShards: card.costShards,
            metricsBoost: card.metricsBoost
        )
        SaveSystem.saveProfile(profile)
    }

    func clearCreatorCard() {
        profile.activeCreatorCard = nil
        SaveSystem.saveProfile(profile)
    }

    static let critiqueCostShards = 500

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
