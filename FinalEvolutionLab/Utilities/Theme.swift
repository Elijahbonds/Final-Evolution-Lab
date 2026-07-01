import SwiftUI

nonisolated struct Theme: Sendable {
    static let brandBlue = Color(red: 0, green: 0.83, blue: 1.0)
    static let brandCyan = Color(red: 0, green: 0.95, blue: 0.9)
    static let deepBlack = Color(red: 0.02, green: 0.02, blue: 0.02)
    static let cardBackground = Color(white: 0.08)
    static let cardBorder = Color(white: 0.12)
    static let surfaceElevated = Color(white: 0.1)

    static let foundationGreen = Color.green
    static let flightBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    static let elitePurple = Color(red: 0.6, green: 0.2, blue: 1.0)

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

// MARK: - Color hex convenience

extension Color {
    /// Creates a SwiftUI Color from a 6-character hex string (with or without leading `#`).
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue:  Double(value & 0xFF) / 255
        )
    }
}
