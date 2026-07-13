import SwiftUI

/// Legacy palette, re-pointed at the `FELDesign` tokens (Phase 5 polish):
/// every screen still referencing `Theme` now renders the premium
/// white/cyan/purple system without per-screen edits. New UI should use
/// `FELDesign` directly; these aliases exist for the migration period.
nonisolated struct Theme: Sendable {
    static let brandBlue = FELDesign.Colors.cyan
    static let brandCyan = FELDesign.Colors.cyan
    static let deepBlack = FELDesign.Colors.ink
    static let cardBackground = FELDesign.Colors.surface
    static let cardBorder = FELDesign.Colors.hairlineStrong
    static let surfaceElevated = FELDesign.Colors.surfaceRaised

    // Difficulty ramp: white -> cyan -> purple (premium tiering).
    static let foundationGreen = FELDesign.Colors.textSecondary
    static let flightBlue = FELDesign.Colors.cyan
    static let elitePurple = FELDesign.Colors.purple

    static let neonGreen = FELDesign.Colors.success
    static let slateBackground = FELDesign.Colors.ink
    static let slateCard = FELDesign.Colors.surface
    static let slateMuted = FELDesign.Colors.surfaceRaised

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
