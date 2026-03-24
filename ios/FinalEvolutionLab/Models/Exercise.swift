import Foundation

struct Exercise: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let difficulty: Difficulty
    let muscleGroups: [String]
    let demoDescription: String
    let sets: Int
    let reps: String
    let restSeconds: Int

    enum ExerciseCategory: String, Codable, Sendable, CaseIterable {
        case plyometric = "Plyometric"
        case strength = "Strength"
        case mobility = "Mobility"
        case agility = "Agility"
        case recovery = "Recovery"

        var systemImage: String {
            switch self {
            case .plyometric: "figure.jumprope"
            case .strength: "dumbbell.fill"
            case .mobility: "figure.flexibility"
            case .agility: "figure.run"
            case .recovery: "heart.circle.fill"
            }
        }
    }

    enum Difficulty: String, Codable, Sendable, CaseIterable {
        case foundation = "Foundation"
        case flight = "Flight"
        case elite = "Elite"

        var sortOrder: Int {
            switch self {
            case .foundation: 0
            case .flight: 1
            case .elite: 2
            }
        }
    }
}
