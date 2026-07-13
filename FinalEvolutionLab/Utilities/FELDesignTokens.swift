import SwiftUI

/// FEL design tokens — the single source of truth for the premium visual language:
/// dark, high-contrast, large type, white/cyan/purple. New UI is built exclusively
/// from these tokens; legacy screens migrate off `Theme` during the polish pass.
nonisolated enum FELDesign {

    // MARK: - Color

    enum Colors {
        // Surfaces (dark ramp)
        static let ink = Color(hex: "050505")!
        static let surface = Color(hex: "101014")!
        static let surfaceRaised = Color(hex: "16161C")!
        static let hairline = Color.white.opacity(0.10)
        static let hairlineStrong = Color.white.opacity(0.16)

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.64)
        static let textTertiary = Color.white.opacity(0.40)

        // Accents — cyan is THE accent; purple is reserved for elite/special moments.
        static let cyan = Color(hex: "00D4FF")!
        static let purple = Color(hex: "9933FF")!

        // Signal colors, used sparingly (state, never decoration)
        static let danger = Color(hex: "FF4D5E")!
        static let success = Color(hex: "34E1B0")!

        /// Soft glow tint for pressed/active accent elements.
        static func glow(_ color: Color, _ opacity: Double = 0.35) -> Color {
            color.opacity(opacity)
        }
    }

    // MARK: - Typography (SF Pro; one scale, two families)

    enum Typography {
        static let display = Font.system(size: 34, weight: .heavy)
        static let title = Font.system(size: 28, weight: .bold)
        static let heading = Font.system(size: 22, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let label = Font.system(size: 15, weight: .semibold)
        static let caption = Font.system(size: 13, weight: .medium)
        /// Uppercase micro-labels; pair with `FELDesign.Typography.microTracking`.
        static let micro = Font.system(size: 11, weight: .semibold)
        static let microTracking: CGFloat = 1.6

        /// Live numeric readouts (scores, timers, telemetry).
        static let statLarge = Font.system(size: 28, weight: .bold, design: .monospaced)
        static let stat = Font.system(size: 15, weight: .semibold, design: .monospaced)
        static let statSmall = Font.system(size: 11, weight: .medium, design: .monospaced)
    }

    // MARK: - Spacing (8pt grid)

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Shape

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let accent: CGFloat = 2
    }
}

// MARK: - Components

/// Standard card container: raised surface, hairline border, `Radius.lg`.
struct FELCardModifier: ViewModifier {
    var padding: CGFloat = FELDesign.Space.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FELDesign.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                    .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
            )
    }
}

/// Primary action: cyan capsule, ink text, no gradient noise.
struct FELPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FELDesign.Typography.label)
            .foregroundStyle(FELDesign.Colors.ink)
            .padding(.horizontal, FELDesign.Space.lg)
            .padding(.vertical, FELDesign.Space.sm)
            .background(FELDesign.Colors.cyan)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Secondary action: hairline capsule on dark surface.
struct FELGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FELDesign.Typography.label)
            .foregroundStyle(FELDesign.Colors.textPrimary)
            .padding(.horizontal, FELDesign.Space.lg)
            .padding(.vertical, FELDesign.Space.sm)
            .background(FELDesign.Colors.surfaceRaised.opacity(configuration.isPressed ? 1 : 0.6))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline))
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Uppercase micro section label ("CONTROLLER TEST", "ROUND 2").
struct FELMicroLabel: View {
    let text: String
    var color: Color = FELDesign.Colors.textTertiary

    var body: some View {
        Text(text.uppercased())
            .font(FELDesign.Typography.micro)
            .tracking(FELDesign.Typography.microTracking)
            .foregroundStyle(color)
    }
}

extension View {
    func felCard(padding: CGFloat = FELDesign.Space.md) -> some View {
        modifier(FELCardModifier(padding: padding))
    }
}
