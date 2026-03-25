import SwiftUI

// MARK: - Closest-to-pin (Arena + solo wrapper)

/// Open links: soft sky, tree line, rolling fairway. Used for `.golf` in `GenericArenaPlayView` and behind `GolfSwingView`.
struct GolfLinksArenaBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.62, blue: 0.88),
                        Color(red: 0.75, green: 0.82, blue: 0.92),
                        Color(red: 0.92, green: 0.88, blue: 0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Tree line
                VStack {
                    Spacer()
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(0..<18, id: \.self) { i in
                            Capsule()
                                .fill(Color(red: 0.12, green: 0.22, blue: 0.12).opacity(0.55))
                                .frame(width: 5, height: CGFloat(16 + (i % 5) * 8))
                                .offset(y: CGFloat((i % 3) * 4))
                        }
                    }
                    .frame(height: h * 0.12)
                    .offset(y: -h * 0.28)
                }
                .allowsHitTesting(false)

                // Fairway roll
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.48, blue: 0.26),
                            Color(red: 0.1, green: 0.32, blue: 0.16),
                            Color(red: 0.05, green: 0.18, blue: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h * 0.52)
                }

                // Light stripes (mower hint)
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(0..<12, id: \.self) { i in
                            Rectangle()
                                .fill(Color.white.opacity(i % 2 == 0 ? 0.04 : 0))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: h * 0.4)
                }

                LinearGradient(
                    colors: [accentColor.opacity(0.12), .clear, accentColor.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.35)],
                    center: .init(x: 0.5, y: 0.55),
                    startRadius: 80,
                    endRadius: 400
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

/// Green, pin, and ball position for TAP-IN! / GREEN / WIDE.
struct ClosestToPinCanvasView: View {
    let accentColor: Color
    var outcome: HoleOutcome?

    enum HoleOutcome: Equatable {
        case tapIn
        case onGreen
        case wide
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.38, blue: 0.2),
                            Color(red: 0.06, green: 0.22, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.38), lineWidth: 1)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    // Rough hints at sides
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.28, blue: 0.12).opacity(0.45), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: w * 0.18)
                        Spacer()
                        LinearGradient(
                            colors: [.clear, Color(red: 0.35, green: 0.28, blue: 0.12).opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: w * 0.18)
                    }

                    // Putting green
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.35, green: 0.72, blue: 0.38),
                                    Color(red: 0.15, green: 0.45, blue: 0.22)
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 95
                            )
                        )
                        .frame(width: w * 0.72, height: h * 0.42)
                        .position(x: w / 2, y: h * 0.34)

                    pinAndCup(centerX: w / 2, cupY: h * 0.32)

                    golfBall
                        .position(x: w * ballXFrac, y: h * ballYFrac)
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: outcomeKey)
            }
        }
        .frame(height: 248)
        .accessibilityHidden(true)
    }

    private var outcomeKey: String {
        switch outcome {
        case .tapIn: return "t"
        case .onGreen: return "g"
        case .wide: return "w"
        case .none: return "n"
        }
    }

    private var ballXFrac: CGFloat {
        switch outcome {
        case .tapIn: return 0.5
        case .onGreen: return 0.56
        case .wide: return 0.22
        case .none: return 0.5
        }
    }

    private var ballYFrac: CGFloat {
        switch outcome {
        case .tapIn: return 0.34
        case .onGreen: return 0.42
        case .wide: return 0.72
        case .none: return 0.86
        }
    }

    private func pinAndCup(centerX: CGFloat, cupY: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 2, height: 36)
            Path { p in
                p.move(to: CGPoint(x: 0, y: -32))
                p.addLine(to: CGPoint(x: 14, y: -24))
                p.addLine(to: CGPoint(x: 0, y: -20))
            }
            .fill(accentColor.opacity(0.9))
            .offset(x: 1, y: 0)
            Circle()
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                .frame(width: 22, height: 22)
                .offset(y: 14)
        }
        .position(x: centerX, y: cupY)
    }

    private var golfBall: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white, Color.white.opacity(0.88)],
                    center: .init(x: 0.35, y: 0.35),
                    startRadius: 1,
                    endRadius: 8
                )
            )
            .frame(width: outcome == nil ? 11 : 13, height: outcome == nil ? 11 : 13)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
    }
}
