import SwiftUI

@Observable
@MainActor
class TrainingViewModel {
    var progress: TrainingProgress
    var activeProgram: TrainingProgram
    var activeDayWorkout: TrainingDay?
    var completedExerciseIds: Set<String> = []
    var isWorkoutActive: Bool = false
    var workoutTimer: Int = 0

    private let labViewModel: LabViewModel

    init(labViewModel: LabViewModel) {
        self.labViewModel = labViewModel
        self.progress = SaveSystem.loadTrainingProgress()
        self.activeProgram = TrainingProgramData.program(for: progress.activeTrack)
    }

    var currentTrack: TrainingTrack {
        progress.activeTrack
    }

    var availableDays: [TrainingDay] {
        activeProgram.days
    }

    var completedDays: [TrainingDay] {
        activeProgram.days.filter { progress.completedDayIds.contains($0.id) }
    }

    var nextAvailableDay: TrainingDay? {
        activeProgram.days.first { !progress.completedDayIds.contains($0.id) && canAccessDay($0) }
    }

    var overallProgress: Double {
        guard !activeProgram.days.isEmpty else { return 0 }
        return Double(completedDays.count) / Double(activeProgram.days.count)
    }

    var recoveryGateStatus: String {
        if progress.recoveryGateCleared {
            return "CLEARED"
        }
        return "COMPLETE RECOVERY"
    }

    func canAccessDay(_ day: TrainingDay) -> Bool {
        guard day.isGated else { return true }
        let recoveryDays = activeProgram.days.filter { $0.category.isRecovery }
        let completedRecovery = recoveryDays.filter { progress.completedDayIds.contains($0.id) }
        let lastStrengthCompleted = activeProgram.days
            .filter { $0.category == .strength }
            .filter { progress.completedDayIds.contains($0.id) }
            .last

        if lastStrengthCompleted != nil && completedRecovery.isEmpty {
            return false
        }

        return progress.recoveryGateCleared
    }

    func switchTrack(to track: TrainingTrack) {
        progress.activeTrack = track
        activeProgram = TrainingProgramData.program(for: track)
        SaveSystem.saveTrainingProgress(progress)
    }

    func startDay(_ day: TrainingDay) {
        activeDayWorkout = day
        completedExerciseIds.removeAll()
        isWorkoutActive = true
        workoutTimer = 0
    }

    func completeExercise(_ exercise: TrainingExercise) {
        completedExerciseIds.insert(exercise.id)
        labViewModel.profile.metrics.neuralDrive = min(100, labViewModel.profile.metrics.neuralDrive + 1.5)

        if exercise.hasLevels {
            let current = progress.exerciseLevel(for: exercise.id)
            if completedExerciseIds.filter({ $0.hasPrefix(exercise.id) }).count >= 3 && current < 3 {
                progress.advanceLevel(for: exercise.id)
            }
        }

        SaveSystem.saveProfile(labViewModel.profile)
    }

    func finishDay() {
        guard let day = activeDayWorkout else { return }

        progress.completedDayIds.insert(day.id)
        progress.lastWorkoutDate = Date()

        if day.category.isRecovery {
            progress.recoveryGateCleared = true
        } else if day.category == .maxIntent || day.category == .jumpVariations {
            progress.recoveryGateCleared = false
        }

        let completedCount = completedExerciseIds.count
        let totalCount = day.totalExerciseCount
        let completionRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0

        let baseShard = 25
        let bonusShards = Int(completionRate * 50)
        let totalShards = baseShard + bonusShards

        progress.totalShardsEarned += totalShards
        labViewModel.profile.evolutionShards += totalShards
        labViewModel.profile.totalWorkouts += 1
        labViewModel.profile.metrics.prqScore = PRQ.clamp(labViewModel.profile.metrics.prqScore + Double(completedCount) * 0.3)
        labViewModel.profile.metrics.verticalPotential = min(100, labViewModel.profile.metrics.verticalPotential + Double(completedCount) * 0.5)

        let session = WorkoutSession(
            id: UUID().uuidString,
            trackId: activeProgram.id,
            date: Date(),
            exercisesCompleted: completedCount,
            totalExercises: totalCount,
            durationSeconds: workoutTimer,
            shardsEarned: totalShards
        )
        labViewModel.sessions.append(session)

        NotificationCenter.default.post(
            name: NSNotification.Name("RorkScoreUpdated"),
            object: nil,
            userInfo: ["score": Int(labViewModel.profile.metrics.prqScore)]
        )

        SaveSystem.saveProfile(labViewModel.profile)
        SaveSystem.saveSessions(labViewModel.sessions)
        SaveSystem.saveTrainingProgress(progress)

        activeDayWorkout = nil
        completedExerciseIds.removeAll()
        isWorkoutActive = false
        workoutTimer = 0
    }

    func exerciseLevel(for exerciseId: String) -> Int {
        progress.exerciseLevel(for: exerciseId)
    }

    func dayIsCompleted(_ day: TrainingDay) -> Bool {
        progress.completedDayIds.contains(day.id)
    }
}
