import Foundation

nonisolated struct CurriculumTrack: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let difficulty: Exercise.Difficulty
    let exercises: [Exercise]
    let weekDuration: Int

    var totalExercises: Int { exercises.count }
}

nonisolated struct WorkoutSession: Codable, Sendable, Identifiable {
    let id: String
    let trackId: String
    let date: Date
    let exercisesCompleted: Int
    let totalExercises: Int
    let durationSeconds: Int
    let shardsEarned: Int

    var completionRate: Double {
        guard totalExercises > 0 else { return 0 }
        return Double(exercisesCompleted) / Double(totalExercises)
    }
}
