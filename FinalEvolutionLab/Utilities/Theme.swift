import SwiftUI

nonisolated struct Theme: Sendable {
    static let brandBlue = Color(red: 0, green: 0.83, blue: 1.0)
    static let brandCyan = Color(red: 0, green: 0.95, blue: 0.9)
    static let deepBlack = Color(red: 0.02, green: 0.02, blue: 0.02)
    static let cardBackground = Color(white: 0.09)
    static let cardBorder = Color(white: 0.14)
    static let surfaceElevated = Color(white: 0.12)

    /// Primary text on dark backgrounds
    static let textPrimary = Color.white
    /// Secondary labels and captions
    static let textSecondary = Color(white: 0.65)
    /// Tertiary hints and placeholders
    static let textTertiary = Color(white: 0.45)

    static let foundationGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    static let flightBlue = Color(red: 0.2, green: 0.55, blue: 1.0)
    static let elitePurple = Color(red: 0.65, green: 0.25, blue: 1.0)

    static let neonGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    static let slateBackground = Color(red: 0.06, green: 0.07, blue: 0.08)
    static let slateCard = Color(red: 0.09, green: 0.1, blue: 0.11)
    static let slateMuted = Color(red: 0.14, green: 0.15, blue: 0.16)

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
