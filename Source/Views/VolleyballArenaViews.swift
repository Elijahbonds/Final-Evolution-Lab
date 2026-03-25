import SwiftUI

// MARK: - Beach volleyball (Rally Ace — Beach Court only)

/// Sand-forward coast: brighter than tennis, net poles hint. Replaces generic gradient for `.volleyball`.
struct BeachVolleyballArenaBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.82, blue: 0.98),
                        Color(red: 0.42, green: 0.72, blue: 0.9),
                        Color(red: 0.88, green: 0.78, blue: 0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1, green: 0.97, blue: 0.75).opacity(0.5),
                                Color(red: 1, green: 0.88, blue: 0.4).opacity(0.12),
                                .clear
                            ],
                            center: .center,
                            startRadius: 6,
                            endRadius: 85
                        )
                    )
                    .frame(width: 110, height: 110)
                    .position(x: geo.size.width * 0.18, y: geo.size.height * 0.12)
                    .allowsHitTesting(false)

                // Net poles (distant)
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 3, height: geo.size.height * 0.35)
                        .offset(y: geo.size.height * 0.08)
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 3, height: geo.size.height * 0.35)
                        .offset(y: geo.size.height * 0.08)
                }
                .padding(.horizontal, geo.size.width * 0.22)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.55, blue: 0.72),
                            Color(red: 0.1, green: 0.38, blue: 0.52)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.22)
                }

                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.86, blue: 0.62),
                            Color(red: 0.82, green: 0.68, blue: 0.42).opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.38)
                }

                // Sand speckle (subtle)
                Canvas { ctx, size in
                    for i in 0..<40 {
                        let x = CGFloat((i * 47 + 13) % max(1, Int(size.width)))
                        let y = CGFloat((i * 71 + 29) % max(1, Int(size.height)))
                        var dot = Path()
                        dot.addEllipse(in: CGRect(x: x, y: y, width: 1.2, height: 1.2))
                        ctx.fill(dot, with: .color(Color.brown.opacity(0.06)))
                    }
                }
                .allowsHitTesting(false)

                LinearGradient(
                    colors: [.clear, accentColor.opacity(0.14), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.22)],
                    center: .center,
                    startRadius: 70,
                    endRadius: 400
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Rally canvas (spike / point / block)

struct BeachVolleyballRallyCanvasView: View {
    let accentColor: Color
    var outcome: SpikeOutcome?

    enum SpikeOutcome {
        case kill
        case point
        case blocked
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.82, blue: 0.52),
                            Color(red: 0.78, green: 0.62, blue: 0.38)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.5), lineWidth: 1)
                )

            // Court lines on sand
            courtBoundary

            netView

            volleyballOrb
                .offset(ballOffset)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: outcomeKey)

            HStack(alignment: .bottom) {
                playerAtNet(isSelf: true, armsUp: outcome == .blocked)
                    .offset(x: selfShiftX, y: selfShiftY)
                    .animation(.spring(response: 0.34, dampingFraction: 0.76), value: outcomeKey)
                Spacer()
                playerAtNet(isSelf: false, armsUp: outcome == .kill || outcome == .point)
                    .offset(x: oppShiftX, y: oppShiftY)
                    .animation(.spring(response: 0.36, dampingFraction: 0.74), value: outcomeKey)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)

            if outcome == .blocked {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.red.opacity(0.4), lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 248)
        .accessibilityHidden(true)
    }

    private var outcomeKey: String {
        switch outcome {
        case .kill: return "k"
        case .point: return "p"
        case .blocked: return "b"
        case .none: return "n"
        }
    }

    private var ballOffset: CGSize {
        switch outcome {
        case .kill:
            return CGSize(width: 38, height: 52)
        case .point:
            return CGSize(width: 28, height: 38)
        case .blocked:
            return CGSize(width: -32, height: -18)
        case .none:
            return CGSize(width: -8, height: -35)
        }
    }

    private var selfShiftX: CGFloat {
        outcome == .blocked ? -6 : 0
    }

    private var selfShiftY: CGFloat {
        outcome == .blocked ? 4 : 0
    }

    private var oppShiftX: CGFloat {
        switch outcome {
        case .kill: return 10
        case .point: return 4
        case .blocked: return -4
        case .none: return 0
        }
    }

    private var oppShiftY: CGFloat {
        switch outcome {
        case .kill: return 12
        case .point: return 6
        case .blocked: return -2
        case .none: return 0
        }
    }

    private var courtBoundary: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.white.opacity(0.35), lineWidth: 1)
            .padding(20)
    }

    private var netView: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .frame(height: 168)
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(height: 5)
                .frame(maxWidth: 200)
                .offset(y: -78)
        }
        .padding(.bottom, 20)
    }

    private var volleyballOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white,
                        Color(red: 0.95, green: 0.55, blue: 0.1),
                        Color(red: 0.2, green: 0.25, blue: 0.75)
                    ],
                    center: .init(x: 0.4, y: 0.35),
                    startRadius: 0,
                    endRadius: 9
                )
            )
            .frame(width: 15, height: 15)
            .shadow(color: outcome == .kill ? accentColor.opacity(0.55) : .clear, radius: 12)
    }

    private func playerAtNet(isSelf: Bool, armsUp: Bool) -> some View {
        VStack(spacing: 3) {
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .fill(isSelf ? accentColor.opacity(0.9) : Color.white.opacity(0.3))
                        .frame(width: 7, height: 7)
                )
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.24))
                .frame(width: 22, height: 28)
            HStack(spacing: 3) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 3, height: armsUp ? 22 : 14)
                    .rotationEffect(.degrees(armsUp ? (isSelf ? -55 : 55) : (isSelf ? -20 : 20)))
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 3, height: armsUp ? 22 : 14)
                    .rotationEffect(.degrees(armsUp ? (isSelf ? 55 : -55) : (isSelf ? 20 : -20)))
            }
            .offset(y: -8)
        }
    }
}
