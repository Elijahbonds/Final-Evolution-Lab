import SwiftUI

struct Theme {
    static let brandBlue = Color(red: 0, green: 0.83, blue: 1.0)
    static let brandCyan = Color(red: 0, green: 0.95, blue: 0.9)
    static let deepBlack = Color(red: 0.02, green: 0.02, blue: 0.02)
    static let cardBackground = Color(white: 0.08)
    static let cardBorder = Color(white: 0.12)
    static let surfaceElevated = Color(white: 0.1)

    static let foundationGreen = Color.green
    static let flightBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    static let elitePurple = Color(red: 0.6, green: 0.2, blue: 1.0)

    static func difficultyColor(_ difficulty: Exercise.Difficulty) -> Color {
        switch difficulty {
        case .foundation: foundationGreen
        case .flight: flightBlue
        case .elite: elitePurple
        }
    }

    static let meshGradient = MeshGradient(
        width: 3, height: 3,
        points: [
            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
            [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
        ],
        colors: [
            .black, Color(red: 0, green: 0.1, blue: 0.15), .black,
            Color(red: 0, green: 0.05, blue: 0.1), Color(red: 0, green: 0.15, blue: 0.25), Color(red: 0.05, green: 0, blue: 0.1),
            .black, Color(red: 0, green: 0.08, blue: 0.12), .black
        ]
    )
}
