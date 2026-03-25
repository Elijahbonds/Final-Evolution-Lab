import SwiftUI

// MARK: - Arena dunk contest (2D venue)

/// Night showcase court: rim glow, boards, crowd band, floor sheen — for `ArenaDunkPlayView`.
struct DunkContestVenueBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.05, blue: 0.14),
                        Color(red: 0.08, green: 0.06, blue: 0.2),
                        Color(red: 0.02, green: 0.02, blue: 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Key lights on court
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        accentColor.opacity(0.06),
                        .clear
                    ],
                    center: .init(x: 0.5, y: 0.35),
                    startRadius: 20,
                    endRadius: 220
                )

                // Backboard slash (stadium LED feel)
                VStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.35), accentColor.opacity(0.08)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * 0.35, height: 5)
                        .offset(y: h * 0.12)
                    Spacer()
                }

                // Crowd darkness
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color.clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h * 0.35)
                }

                // Floor wash
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.22).opacity(0.85),
                            Color(red: 0.04, green: 0.05, blue: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h * 0.42)
                }

                RadialGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    center: .init(x: 0.5, y: 0.5),
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

/// Runway + hoop + runner silhouette driven by `DunkContestState` phase (Arena dunk flow).
struct DunkRunwayCanvasView: View {
    let accentColor: Color
    var phase: DunkPhase
    var sprintCharge: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.08, blue: 0.14),
                            Color(red: 0.01, green: 0.05, blue: 0.1)
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
                ZStack {
                    runwayFloor(width: w, height: h)
                    hoopView
                        .position(x: w / 2, y: h * 0.14)

                    if phase == .scored {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundStyle(.yellow.opacity(0.85))
                            .position(x: w / 2, y: h * 0.12)
                    }

                    playerCluster
                        .position(x: w / 2 + runnerXShift(width: w), y: h * runnerYFrac)
                }
                // Animate phase transitions only; sprint charge updates each frame without spring (stays responsive).
                .animation(.spring(response: 0.42, dampingFraction: 0.8), value: phase)
            }
        }
        .frame(height: 200)
        .accessibilityHidden(true)
    }

    /// Fraction from top (0 = top) — larger = lower on screen.
    private var runnerYFrac: CGFloat {
        let charge = CGFloat(min(1, max(0, sprintCharge)))
        switch phase {
        case .idle:
            return 0.82
        case .approach:
            return 0.82 - 0.22 * charge
        case .launch:
            return 0.52
        case .airborne:
            return 0.28
        case .landing:
            return 0.48
        case .scored:
            return 0.32
        }
    }

    private func runnerXShift(width: CGFloat) -> CGFloat {
        switch phase {
        case .airborne: return width * 0.06
        case .scored: return width * 0.04
        default: return 0
        }
    }

    private var hoopView: some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.12))
                .frame(width: 52, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
            Capsule()
                .stroke(accentColor, lineWidth: 2.5)
                .frame(width: 34, height: 10)
                .shadow(color: accentColor.opacity(phase == .scored ? 0.7 : 0.25), radius: phase == .scored ? 12 : 4)
        }
    }

    private func runwayFloor(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Path { p in
                let topW = width * 0.35
                let botW = width * 0.92
                let midX = width / 2
                let topY = height * 0.22
                let botY = height * 0.95
                p.move(to: CGPoint(x: midX - topW / 2, y: topY))
                p.addLine(to: CGPoint(x: midX + topW / 2, y: topY))
                p.addLine(to: CGPoint(x: midX + botW / 2, y: botY))
                p.addLine(to: CGPoint(x: midX - botW / 2, y: botY))
                p.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            Path { p in
                let midX = width / 2
                p.move(to: CGPoint(x: midX, y: height * 0.22))
                p.addLine(to: CGPoint(x: midX, y: height * 0.95))
            }
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var playerCluster: some View {
        let armSpread: Double = {
            switch phase {
            case .airborne, .scored: return 1.15
            case .launch, .landing: return 0.95
            default: return 0.85
            }
        }()
        let bodyTilt: Double = {
            switch phase {
            case .airborne: return -18
            case .scored: return -12
            case .landing: return 8
            default: return 0
            }
        }()
        return ZStack {
            HStack(spacing: CGFloat(14 * armSpread)) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 3, height: 20)
                    .rotationEffect(.degrees(-35))
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 3, height: 20)
                    .rotationEffect(.degrees(35))
            }
            .offset(y: -22)
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 16, height: 16)
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.28))
                .frame(width: 22, height: 30)
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4, height: 22)
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4, height: 22)
            }
            .offset(y: 24)
        }
        .rotationEffect(.degrees(bodyTilt))
    }
}
