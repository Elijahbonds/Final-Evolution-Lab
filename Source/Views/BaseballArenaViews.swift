import SwiftUI

// MARK: - Stadium night (Home Run Derby only)

/// Night game under lights: field glow, stands silhouette, sky. Replaces generic Arena gradient for `.baseball`.
struct BaseballStadiumArenaBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Sky
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.04, blue: 0.14),
                        Color(red: 0.04, green: 0.08, blue: 0.22),
                        Color(red: 0.03, green: 0.05, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Stadium bowl (dark stands)
                VStack {
                    Spacer()
                    RadialGradient(
                        colors: [
                            Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.9),
                            Color.black.opacity(0.85)
                        ],
                        center: .init(x: 0.5, y: 1.15),
                        startRadius: 40,
                        endRadius: min(geo.size.width, geo.size.height) * 0.95
                    )
                    .frame(height: geo.size.height * 0.55)
                }

                // Field lights (four towers)
                stadiumLight(at: CGPoint(x: 0.12, y: 0.14), in: geo.size)
                stadiumLight(at: CGPoint(x: 0.88, y: 0.14), in: geo.size)
                stadiumLight(at: CGPoint(x: 0.22, y: 0.22), in: geo.size)
                stadiumLight(at: CGPoint(x: 0.78, y: 0.22), in: geo.size)

                // Infield wash (from plate POV)
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.22, blue: 0.1).opacity(0.55),
                            Color(red: 0.02, green: 0.12, blue: 0.06).opacity(0.4),
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.38)
                }

                // Fence arc hint
                Canvas { ctx, size in
                    var arc = Path()
                    arc.addArc(
                        center: CGPoint(x: size.width * 0.5, y: size.height * 0.92),
                        radius: size.width * 0.48,
                        startAngle: .degrees(200),
                        endAngle: .degrees(340),
                        clockwise: false
                    )
                    ctx.stroke(arc, with: .color(Color.white.opacity(0.08)), lineWidth: 1.5)
                }
                .allowsHitTesting(false)

                // Accent rim
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, accentColor.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 120)
                }

                RadialGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    center: .center,
                    startRadius: 60,
                    endRadius: 480
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    private func stadiumLight(at unit: CGPoint, in size: CGSize) -> some View {
        let x = unit.x * size.width
        let y = unit.y * size.height
        return ZStack {
            RadialGradient(
                colors: [
                    Color(red: 1, green: 0.95, blue: 0.75).opacity(0.35),
                    Color(red: 0.9, green: 0.85, blue: 0.5).opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: 90
            )
            .frame(width: 140, height: 200)
            .blur(radius: 4)
            .position(x: x, y: y)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Derby canvas (pitch → swing feedback)

struct BaseballDerbyCanvasView: View {
    let accentColor: Color
    let showPitchPhase: Bool
    /// Derived from `commitFeedback` vs mode labels; drives ball / batter motion.
    var swingOutcome: SwingOutcome?

    enum SwingOutcome {
        case homeRun
        case contact
        case out
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.18, blue: 0.08),
                            Color(red: 0.02, green: 0.1, blue: 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.35), lineWidth: 1)
                )

            // Foul lines + plate
            fieldMarkings

            // Pitcher mound
            Circle()
                .fill(Color(red: 0.55, green: 0.38, blue: 0.22).opacity(0.5))
                .frame(width: 36, height: 18)
                .offset(x: 0, y: -42)

            // Flying ball (pitch or result)
            baseballOrb
                .offset(ballOffset)
                .animation(.easeOut(duration: showPitchPhase ? 0.45 : 0.55), value: showPitchPhase)
                .animation(.spring(response: 0.4, dampingFraction: 0.72), value: swingOutcomeKey)

            HStack(alignment: .bottom, spacing: 0) {
                batter
                    .offset(x: batterShift.width, y: batterShift.height)
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: swingOutcomeKey)
                Spacer()
            }
            .padding(.leading, 28)
            .padding(.bottom, 14)
        }
        .frame(height: 248)
        .accessibilityHidden(true)
    }

    private var swingOutcomeKey: String {
        switch swingOutcome {
        case .homeRun: return "hr"
        case .contact: return "c"
        case .out: return "o"
        case .none: return "n"
        }
    }

    private var ballOffset: CGSize {
        if showPitchPhase {
            return CGSize(width: 0, height: 28)
        }
        switch swingOutcome {
        case .homeRun:
            return CGSize(width: 40, height: -100)
        case .contact:
            return CGSize(width: 55, height: -20)
        case .out:
            return CGSize(width: -30, height: 8)
        case .none:
            return CGSize(width: 0, height: -36)
        }
    }

    private var batterShift: CGSize {
        switch swingOutcome {
        case .homeRun, .contact:
            return CGSize(width: 8, height: -4)
        case .out:
            return CGSize(width: -4, height: 2)
        case .none:
            return .zero
        }
    }

    private var baseballOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white,
                        Color(red: 0.95, green: 0.3, blue: 0.15).opacity(0.95)
                    ],
                    center: .init(x: 0.35, y: 0.35),
                    startRadius: 0,
                    endRadius: 10
                )
            )
            .frame(width: 14, height: 14)
            .shadow(color: swingOutcome == .homeRun ? accentColor.opacity(0.6) : .clear, radius: swingOutcome == .homeRun ? 12 : 0)
    }

    private var fieldMarkings: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.88))
                    p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.55))
                }
                .stroke(Color.white.opacity(0.12), lineWidth: 1)

                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.88))
                    p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.55))
                }
                .stroke(Color.white.opacity(0.12), lineWidth: 1)

                // Home plate
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 16, height: 4)
                    .rotationEffect(.degrees(0))
                    .position(x: w * 0.22, y: h * 0.82)
            }
        }
    }

    private var batter: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.12))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .fill(accentColor.opacity(0.85))
                        .frame(width: 9, height: 9)
                )
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.2))
                .frame(width: 26, height: 36)
            // Bat
            Capsule()
                .fill(Color(red: 0.45, green: 0.3, blue: 0.15))
                .frame(width: 5, height: 44)
                .rotationEffect(.degrees(swingOutcome == nil ? -25 : (swingOutcome == .out ? -8 : -55)))
                .offset(x: 16, y: -12)
        }
    }
}
