import SwiftUI

// MARK: - Stadium field night (Kick Return only)

/// Floodlit gridiron: turf, yard chalk, end-zone wash. Replaces generic Arena gradient for `.football`.
struct FootballStadiumFieldBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.04, blue: 0.12),
                        Color(red: 0.04, green: 0.1, blue: 0.18),
                        Color(red: 0.02, green: 0.06, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.22, blue: 0.08),
                                Color(red: 0.04, green: 0.14, blue: 0.06),
                                Color(red: 0.02, green: 0.08, blue: 0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.height * 0.52)

                        // End zone (far)
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.22),
                                accentColor.opacity(0.06),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: geo.size.height * 0.52)
                        .padding(.leading, geo.size.width * 0.62)

                        yardLineCanvas(width: geo.size.width, height: geo.size.height * 0.52)
                    }
                }

                // Lights
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.2),
                        Color(red: 0.9, green: 0.95, blue: 1).opacity(0.06),
                        .clear
                    ],
                    center: .init(x: 0.15, y: 0.12),
                    startRadius: 10,
                    endRadius: 160
                )
                .position(x: geo.size.width * 0.15, y: geo.size.height * 0.12)

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color(red: 0.9, green: 0.95, blue: 1).opacity(0.05),
                        .clear
                    ],
                    center: .init(x: 0.85, y: 0.1),
                    startRadius: 10,
                    endRadius: 150
                )
                .position(x: geo.size.width * 0.85, y: geo.size.height * 0.1)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    center: .center,
                    startRadius: 50,
                    endRadius: 460
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    private func yardLineCanvas(width: CGFloat, height: CGFloat) -> some View {
        Canvas { ctx, size in
            let baseY = size.height * 0.55
            for i in 0..<11 {
                let x = size.width * (0.08 + CGFloat(i) * 0.084)
                var p = Path()
                p.move(to: CGPoint(x: x, y: baseY - size.height * 0.35))
                p.addLine(to: CGPoint(x: x, y: baseY + size.height * 0.08))
                ctx.stroke(p, with: .color(Color.white.opacity(0.14)), lineWidth: 1)
            }
            var mid = Path()
            mid.move(to: CGPoint(x: size.width * 0.5, y: baseY - size.height * 0.32))
            mid.addLine(to: CGPoint(x: size.width * 0.5, y: baseY + size.height * 0.06))
            ctx.stroke(mid, with: .color(Color.white.opacity(0.22)), lineWidth: 1.2)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

// MARK: - Kick return canvas

struct KickReturnCanvasView: View {
    let accentColor: Color
    var outcome: ReturnOutcome?

    enum ReturnOutcome {
        case touchdown
        case yards
        case stopped
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.2, blue: 0.09),
                            Color(red: 0.03, green: 0.12, blue: 0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1)
                )

            fieldTexture

            // Speed streaks on house call
            if outcome == .touchdown {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 40 + CGFloat(i * 12), height: 2)
                        .offset(x: CGFloat(i) * -14 + 20, y: CGFloat(i) * 6 - 30)
                        .rotationEffect(.degrees(-8))
                }
                .allowsHitTesting(false)
            }

            HStack(alignment: .center, spacing: 0) {
                returnerUnit
                    .offset(x: returnerOffsetX, y: returnerOffsetY)
                    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: outcomeKey)

                Spacer()

                defendersCluster
                    .offset(x: defendersOffsetX)
                    .animation(.spring(response: 0.4, dampingFraction: 0.78), value: outcomeKey)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(height: 248)
        .accessibilityHidden(true)
    }

    private var outcomeKey: String {
        switch outcome {
        case .touchdown: return "td"
        case .yards: return "y"
        case .stopped: return "s"
        case .none: return "n"
        }
    }

    private var returnerOffsetX: CGFloat {
        switch outcome {
        case .touchdown: return 72
        case .yards: return 28
        case .stopped: return -8
        case .none: return 0
        }
    }

    private var returnerOffsetY: CGFloat {
        switch outcome {
        case .touchdown: return -6
        case .yards: return -2
        case .stopped: return 4
        case .none: return 0
        }
    }

    private var defendersOffsetX: CGFloat {
        switch outcome {
        case .touchdown: return 40
        case .yards: return 12
        case .stopped: return -28
        case .none: return 0
        }
    }

    private var fieldTexture: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 1, height: h * 0.65)
                        .position(x: w * (0.12 + CGFloat(i) * 0.11), y: h * 0.48)
                }
            }
        }
    }

    private var returnerUnit: some View {
        ZStack(alignment: .center) {
            Capsule()
                .fill(Color.brown.opacity(0.55))
                .frame(width: 22, height: 12)
                .rotationEffect(.degrees(-18))
                .offset(x: 8, y: 8)
            VStack(spacing: 3) {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .overlay(Circle().fill(accentColor.opacity(0.75)).frame(width: 8, height: 8))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 28, height: 34)
            }
        }
    }

    private var defendersCluster: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                VStack(spacing: 2) {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 16, height: 16)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 22, height: 28)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(outcome == .stopped ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
                .offset(y: CGFloat(i) * 4)
            }
        }
    }
}
