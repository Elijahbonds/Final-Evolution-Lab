import SwiftUI

// MARK: - Penalty shootout (Arena + local solo wrapper)

/// Night stadium: floodlights, stands, pitch wash. Used for `.soccer` in `GenericArenaPlayView` and behind `PenaltyKickView`.
struct PenaltyStadiumArenaBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.04, blue: 0.12),
                        Color(red: 0.06, green: 0.08, blue: 0.2),
                        Color(red: 0.04, green: 0.12, blue: 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Stand tiers (silhouette)
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.35),
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: h * 0.42)
                }

                // Floodlight beams
                ForEach(0..<4, id: \.self) { i in
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 140
                    )
                    .frame(width: 100, height: 200)
                    .position(x: w * (0.15 + CGFloat(i) * 0.23), y: h * 0.12)
                }

                // Pitch foreground
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.42, blue: 0.22),
                            Color(red: 0.05, green: 0.28, blue: 0.14),
                            Color(red: 0.02, green: 0.14, blue: 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h * 0.38)
                }

                LinearGradient(
                    colors: [accentColor.opacity(0.15), .clear, accentColor.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    center: .init(x: 0.5, y: 0.45),
                    startRadius: 60,
                    endRadius: 400
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

/// Commit / PRQ feedback canvas: goal, keeper, ball states for GOAL! / ON TARGET / SAVED.
struct PenaltySpotCanvasView: View {
    let accentColor: Color
    var outcome: PenaltyOutcome?

    enum PenaltyOutcome: Equatable {
        case goal
        case onTarget
        case saved
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.38, blue: 0.2),
                            Color(red: 0.04, green: 0.22, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .bottom) {
                    // Penalty spot
                    Ellipse()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        .frame(width: 28, height: 10)
                        .position(x: w / 2, y: h * 0.88)

                    goalFrame(width: w * 0.72, centerX: w / 2, topY: h * 0.18)

                    keeperFigure
                        .position(x: w * keeperXFrac, y: h * 0.36)

                    ballMark
                        .position(x: w * ballXFrac, y: h * ballYFrac)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.72), value: outcomeKey)
        }
        .frame(height: 248)
        .accessibilityHidden(true)
    }

    private var outcomeKey: String {
        switch outcome {
        case .goal: return "g"
        case .onTarget: return "t"
        case .saved: return "s"
        case .none: return "n"
        }
    }

    private var keeperXFrac: CGFloat {
        switch outcome {
        case .goal: return 0.32
        case .onTarget: return 0.58
        case .saved: return 0.5
        case .none: return 0.5
        }
    }

    private var ballXFrac: CGFloat {
        switch outcome {
        case .goal: return 0.72
        case .onTarget: return 0.62
        case .saved: return 0.48
        case .none: return 0.5
        }
    }

    private var ballYFrac: CGFloat {
        switch outcome {
        case .goal: return 0.28
        case .onTarget: return 0.34
        case .saved: return 0.38
        case .none: return 0.82
        }
    }

    private func goalFrame(width: CGFloat, centerX: CGFloat, topY: CGFloat) -> some View {
        let gh = width * 0.38
        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
            Path { p in
                stride(from: 0, to: width, by: 14).forEach { dx in
                    p.move(to: CGPoint(x: dx, y: 0))
                    p.addLine(to: CGPoint(x: dx + 6, y: gh))
                }
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .frame(width: width, height: gh)
        .position(x: centerX, y: topY)
    }

    private var keeperFigure: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 22, height: 8)
                .offset(y: -28)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.3))
                .frame(width: 20, height: 32)
            HStack(spacing: 10) {
                Capsule().fill(Color.white.opacity(0.28)).frame(width: 4, height: 18)
                Capsule().fill(Color.white.opacity(0.28)).frame(width: 4, height: 18)
            }
            .offset(y: 22)
        }
        .rotationEffect(.degrees(outcome == .saved ? -12 : (outcome == .goal ? 18 : 8)))
    }

    private var ballMark: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white, Color.white.opacity(0.85)],
                    center: .init(x: 0.35, y: 0.35),
                    startRadius: 1,
                    endRadius: 9
                )
            )
            .frame(width: outcome == nil ? 12 : 14, height: outcome == nil ? 12 : 14)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
    }
}
