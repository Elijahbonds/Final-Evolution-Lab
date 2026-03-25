import SwiftUI

// MARK: - Beach tennis (Rally Ace only)

/// Sun + Pacific wash + court strip. Replaces generic Arena gradient for `.tennis`.
struct BeachTennisCourtBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.5, green: 0.78, blue: 0.95),
                        Color(red: 0.35, green: 0.65, blue: 0.88),
                        Color(red: 0.25, green: 0.5, blue: 0.75)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )

                // Sun
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1, green: 0.98, blue: 0.85).opacity(0.55),
                                Color(red: 1, green: 0.92, blue: 0.5).opacity(0.15),
                                .clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 90
                        )
                    )
                    .frame(width: 120, height: 120)
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.14)
                    .allowsHitTesting(false)

                // Ocean horizon
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.45, blue: 0.62),
                            Color(red: 0.08, green: 0.32, blue: 0.48),
                            Color(red: 0.04, green: 0.2, blue: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.28)
                }

                // Sand band under court
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.86, blue: 0.72).opacity(0.35),
                            Color(red: 0.75, green: 0.65, blue: 0.48).opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.22)
                }

                LinearGradient(
                    colors: [.clear, accentColor.opacity(0.1), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.25)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 420
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Rally canvas

struct RallyAceCanvasView: View {
    let accentColor: Color
    var outcome: RallyOutcome?

    enum RallyOutcome {
        case ace
        case inCourt
        case outWide
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.42, blue: 0.28),
                            Color(red: 0.08, green: 0.28, blue: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.45), lineWidth: 1)
                )

            courtLines

            // Net
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 24)

            tennisBall
                .offset(ballOffset)
                .animation(.spring(response: 0.42, dampingFraction: 0.68), value: outcomeKey)

            HStack {
                playerFigure(isSelf: true)
                    .offset(x: playerNudge)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: outcomeKey)
                Spacer()
                playerFigure(isSelf: false)
                    .offset(x: opponentNudge)
                    .animation(.spring(response: 0.38, dampingFraction: 0.72), value: outcomeKey)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .frame(height: 248)
        .accessibilityHidden(true)
    }

    private var outcomeKey: String {
        switch outcome {
        case .ace: return "a"
        case .inCourt: return "i"
        case .outWide: return "o"
        case .none: return "n"
        }
    }

    private var ballOffset: CGSize {
        switch outcome {
        case .ace:
            return CGSize(width: 55, height: -55)
        case .inCourt:
            return CGSize(width: 18, height: 22)
        case .outWide:
            return CGSize(width: 72, height: -8)
        case .none:
            return CGSize(width: -42, height: 8)
        }
    }

    private var playerNudge: CGFloat {
        switch outcome {
        case .ace, .inCourt: return 4
        case .outWide: return -2
        case .none: return 0
        }
    }

    private var opponentNudge: CGFloat {
        switch outcome {
        case .ace: return 18
        case .inCourt: return -6
        case .outWide: return 4
        case .none: return 0
        }
    }

    private var courtLines: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: w * 0.88, height: h * 0.72)
                    .position(x: w / 2, y: h / 2)

                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.18))
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.82))
                }
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

                Path { p in
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.5))
                    p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.5))
                }
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
        }
    }

    private var tennisBall: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.98, green: 0.95, blue: 0.2),
                        Color(red: 0.75, green: 0.72, blue: 0.05)
                    ],
                    center: .init(x: 0.35, y: 0.35),
                    startRadius: 0,
                    endRadius: 8
                )
            )
            .frame(width: 13, height: 13)
            .shadow(color: outcome == .ace ? accentColor.opacity(0.5) : .clear, radius: 10)
    }

    private func playerFigure(isSelf: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .fill(isSelf ? accentColor.opacity(0.85) : Color.white.opacity(0.25))
                        .frame(width: 8, height: 8)
                )
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.22))
                .frame(width: 24, height: 32)
            // Racket hint
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 4, height: 26)
                .rotationEffect(.degrees(isSelf ? -35 : 35))
                .offset(x: isSelf ? 14 : -14, y: -10)
        }
    }
}
