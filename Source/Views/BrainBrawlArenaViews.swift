import SwiftUI

// MARK: - Brain Brawl — academy quiz duel

/// Study-hall / neural lab backdrop for Brain Brawl (replaces generic arena gradient).
struct BrainBrawlAcademyBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.04, blue: 0.12),
                        Color(red: 0.1, green: 0.05, blue: 0.22),
                        Color(red: 0.02, green: 0.02, blue: 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                gridLines(width: w, height: h)

                // Desk-lamp pools
                ForEach(0..<3, id: \.self) { i in
                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.12),
                            accentColor.opacity(0.03),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 100
                    )
                    .frame(width: 160, height: 160)
                    .position(x: w * (0.2 + CGFloat(i) * 0.3), y: h * 0.15)
                }

                LinearGradient(
                    colors: [accentColor.opacity(0.1), .clear, accentColor.opacity(0.06)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    center: .init(x: 0.5, y: 0.45),
                    startRadius: 60,
                    endRadius: 420
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        Path { p in
            let step: CGFloat = 32
            stride(from: 0, through: width, by: step).forEach { x in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: height))
            }
            stride(from: 0, through: height, by: step).forEach { y in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.035), lineWidth: 0.5)
        .allowsHitTesting(false)
    }
}

/// YOU vs opponent link state after commit (CORRECT / RIGHT / WRONG). `opponentLabel` is `"AI"` in solo quiz; `"OPP"` in local Versus.
struct BrainBrawlDuelCanvasView: View {
    let accentColor: Color
    var outcome: DuelOutcome?
    var opponentLabel: String = "AI"

    enum DuelOutcome: Equatable {
        case correct
        case partial
        case wrong
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let midY = h / 2
                ZStack {
                    // Link beam
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    leftBeamColor.opacity(beamOpacity),
                                    centerBeamColor.opacity(beamOpacity * 0.85),
                                    rightBeamColor.opacity(beamOpacity)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * 0.5, height: 4)
                        .position(x: w / 2, y: midY)

                    node(label: "YOU", isActive: youLit, glow: leftGlowColor)
                        .position(x: w * 0.18, y: midY)

                    node(label: opponentLabel, isActive: rightNodeLit, glow: rightGlowColor)
                        .position(x: w * 0.82, y: midY)
                }
                .animation(.easeOut(duration: 0.28), value: outcomeKey)
            }
        }
        .frame(height: 120)
        .accessibilityHidden(true)
    }

    private var outcomeKey: String {
        switch outcome {
        case .correct: return "c"
        case .partial: return "p"
        case .wrong: return "w"
        case .none: return "n"
        }
    }

    private var leftGlowColor: Color {
        switch outcome {
        case .correct: return Theme.foundationGreen
        case .partial: return Color.orange
        case .wrong: return Color.white.opacity(0.25)
        case .none: return accentColor
        }
    }

    private var rightGlowColor: Color {
        switch outcome {
        case .wrong: return Color.red.opacity(0.9)
        case .partial: return Color.orange
        case .correct: return Color.white.opacity(0.2)
        case .none: return accentColor.opacity(0.7)
        }
    }

    private var leftBeamColor: Color {
        switch outcome {
        case .correct: return Theme.foundationGreen
        case .partial: return Color.orange
        case .wrong: return Color.white.opacity(0.2)
        case .none: return accentColor
        }
    }

    private var centerBeamColor: Color {
        switch outcome {
        case .partial: return Color.orange
        default: return Color.white.opacity(0.35)
        }
    }

    private var rightBeamColor: Color {
        switch outcome {
        case .wrong: return Color.red
        case .partial: return Color.orange
        case .correct: return Color.white.opacity(0.2)
        case .none: return accentColor.opacity(0.7)
        }
    }

    private var beamOpacity: Double {
        outcome == nil ? 0.35 : 0.85
    }

    private var youLit: Bool {
        outcome == nil || outcome == .correct || outcome == .partial
    }

    private var rightNodeLit: Bool {
        outcome == nil || outcome == .wrong || outcome == .partial
    }

    private func node(label: String, isActive: Bool, glow: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(glow.opacity(isActive ? 0.45 : 0.12))
                    .frame(width: 44, height: 44)
                    .blur(radius: isActive ? 6 : 2)
                Circle()
                    .strokeBorder(glow.opacity(isActive ? 0.95 : 0.35), lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                Circle()
                    .fill(glow.opacity(isActive ? 0.5 : 0.15))
                    .frame(width: 10, height: 10)
            }
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(isActive ? glow : .secondary)
        }
    }
}
