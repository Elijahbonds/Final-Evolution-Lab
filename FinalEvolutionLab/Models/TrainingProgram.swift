import Foundation

nonisolated enum EquipmentType: String, Codable, Sendable, CaseIterable, Identifiable {
    case bodyweight = "Bodyweight"
    case movementEducation = "Movement Education"
    case pjfBand = "PJF Band"
    case totalBodyBoard = "Total Body Board"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .bodyweight: "figure.strengthtraining.traditional"
        case .movementEducation: "figure.walk"
        case .pjfBand: "circle.circle"
        case .totalBodyBoard: "rectangle.split.2x2"
        }
    }

    var subtitle: String {
        switch self {
        case .bodyweight: "Full program with gym equipment"
        case .movementEducation: "Sensory education, pressure & rotation"
        case .pjfBand: "Band-focused mobility, power & agility"
        case .totalBodyBoard: "Board-based stability & strength"
        }
    }
}

nonisolated struct TrainingProgram: Codable, Sendable, Identifiable {
    let id: String
    let track: TrainingTrack
    let equipment: EquipmentType
    let weeks: Int
    let days: [TrainingDay]

    var completedDayIds: Set<String> {
        Set(days.filter { $0.isCompleted }.map { $0.id })
    }
}

nonisolated enum TrainingTrack: String, Codable, Sendable, CaseIterable, Identifiable {
    case foundations = "Foundations"
    case flight = "Flight"
    case elite = "Elite"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .foundations: "Build base strength, mobility, and coordination"
        case .flight: "Enhance explosive power and agility"
        case .elite: "Maximize jumping ability and peak strength"
        }
    }

    var icon: String {
        switch self {
        case .foundations: "figure.stand"
        case .flight: "figure.jumprope"
        case .elite: "bolt.fill"
        }
    }

    var difficulty: Exercise.Difficulty {
        switch self {
        case .foundations: .foundation
        case .flight: .flight
        case .elite: .elite
        }
    }
}

nonisolated struct TrainingDay: Codable, Sendable, Identifiable {
    let id: String
    let dayNumber: Int
    let variant: String
    let title: String
    let category: TrainingDayCategory
    let warmUp: [TrainingExercise]
    let mainWork: [TrainingExercise]
    let isGated: Bool
    var isCompleted: Bool
    var completedDate: Date?

    var allExercises: [TrainingExercise] {
        warmUp + mainWork
    }

    var totalExerciseCount: Int {
        allExercises.count
    }
}

nonisolated enum TrainingDayCategory: String, Codable, Sendable {
    case strength = "Strength"
    case recoveryIso = "Recovery + Isos"
    case maxIntent = "Max Intent"
    case recoveryPilates = "Recovery + Pilates"
    case jumpVariations = "Jump Variations"
    case recovery = "Recovery"
    case movementEducation = "Movement Education"
    case plyometrics = "Plyometrics"

    var icon: String {
        switch self {
        case .strength: "dumbbell.fill"
        case .recoveryIso: "heart.circle.fill"
        case .maxIntent: "flame.fill"
        case .recoveryPilates: "figure.yoga"
        case .jumpVariations: "figure.jumprope"
        case .recovery: "leaf.fill"
        case .movementEducation: "figure.walk"
        case .plyometrics: "figure.jumprope"
        }
    }

    var isRecovery: Bool {
        switch self {
        case .recoveryIso, .recoveryPilates, .recovery: true
        default: false
        }
    }

    var isMovementEducation: Bool {
        self == .movementEducation
    }
}

nonisolated struct TrainingExercise: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let sets: Int
    let reps: String
    let restSeconds: Int
    let category: Exercise.ExerciseCategory
    let muscleGroups: [String]
    let cues: String
    let progressionLevel: Int
    let hasLevels: Bool

    var levelLabel: String? {
        guard hasLevels else { return nil }
        switch progressionLevel {
        case 1: return "Level 1"
        case 2: return "Level 2"
        case 3: return "Level 3"
        default: return nil
        }
    }
}

nonisolated struct TrainingProgress: Codable, Sendable {
    var activeTrack: TrainingTrack
    var activeEquipment: EquipmentType
    var completedDayIds: Set<String>
    var currentWeek: Int
    var exerciseLevels: [String: Int]
    var lastWorkoutDate: Date?
    var recoveryGateCleared: Bool
    var totalShardsEarned: Int

    static let initial = TrainingProgress(
        activeTrack: .foundations,
        activeEquipment: .bodyweight,
        completedDayIds: [],
        currentWeek: 1,
        exerciseLevels: [:],
        lastWorkoutDate: nil,
        recoveryGateCleared: true,
        totalShardsEarned: 0
    )

    var daysSinceLastWorkout: Int {
        guard let last = lastWorkoutDate else { return 999 }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 999
    }

    func exerciseLevel(for exerciseId: String) -> Int {
        exerciseLevels[exerciseId] ?? 1
    }

    mutating func advanceLevel(for exerciseId: String) {
        let current = exerciseLevel(for: exerciseId)
        if current < 3 {
            exerciseLevels[exerciseId] = current + 1
        }
    }
}
