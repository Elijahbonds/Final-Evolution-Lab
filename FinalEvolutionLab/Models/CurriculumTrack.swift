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

nonisolated enum LessonDifficulty: String, Codable, Sendable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
}

nonisolated struct QuizQuestion: Codable, Sendable, Identifiable {
    let id: UUID
    let questionText: String
    let options: [String]  // Always exactly 4 options
    let correctAnswerIndex: Int  // 0-3
    let explanation: String

    init(questionText: String, options: [String], correctAnswerIndex: Int, explanation: String) {
        precondition(options.count == 4, "QuizQuestion must have exactly 4 options")
        precondition(correctAnswerIndex >= 0 && correctAnswerIndex < 4, "correctAnswerIndex must be 0-3")
        self.id = UUID()
        self.questionText = questionText
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
    }
}

nonisolated struct LessonContent: Codable, Sendable {
    let videoURLPlaceholder: String
    let keyPoints: [String]  // 3-5 key learning points
    let estimatedMinutes: Int

    init(videoURLPlaceholder: String, keyPoints: [String], estimatedMinutes: Int) {
        self.videoURLPlaceholder = videoURLPlaceholder
        self.keyPoints = keyPoints
        self.estimatedMinutes = estimatedMinutes
    }

    var formattedDuration: String {
        "\(estimatedMinutes) min"
    }
}
