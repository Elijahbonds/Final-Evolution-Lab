import SwiftUI

// MARK: - Academy Arena — gymnastics floor

/// Indoor arena: truss lights, spring-floor wash, crowd darkness. Replaces generic gradient for `.gymnastics`.
struct AcademyArenaGymnasticsBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.03, blue: 0.1),
                        Color(red: 0.08, green: 0.06, blue: 0.18),
                        Color(red: 0.05, green: 0.04, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Side washes (arena LED feel)
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [accentColor.opacity(0.22), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.22)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, accentColor.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.22)
                }

                // Spotlights from ceiling
                ForEach(0..<5, id: \.self) { i in
                    RadialGradient(
                        colors: [
                            Color(red: 1, green: 0.95, blue: 0.75).opacity(0.2),
                            Color(red: 0.85, green: 0.8, blue: 1).opacity(0.06),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 100
                    )
                    .frame(width: 90, height: 140)
                    .position(
                        x: geo.size.width * (0.18 + CGFloat(i) * 0.16),
                        y: geo.size.height * 0.1
                    )
                }

                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.35, blue: 0.62).opacity(0.45),
                            Color(red: 0.08, green: 0.2, blue: 0.45).opacity(0.35),
                            Color.black.opacity(0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.45)
                }

                RadialGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    center: .init(x: 0.5, y: 0.55),
                    startRadius: 60,
                    endRadius: 440
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Floor routine canvas

struct GymnasticsFloorRoutineCanvasView: View {
    let accentColor: Color
    var outcome: RoutineOutcome?

    enum RoutineOutcome {
        case stuck
        case landed
        case deduct
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.28, blue: 0.52),
                            Color(red: 0.08, green: 0.18, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.45), lineWidth: 1)
                )

            floorTapeLines

            gymnastFigure
                .offset(x: gymnastOffsetX, y: gymnastOffsetY)
                .rotationEffect(.degrees(gymnastTilt))
                .animation(.spring(response: 0.42, dampingFraction: outcome == .stuck ? 0.62 : 0.78), value: outcomeKey)

            if outcome == .stuck {
                Text("★")
                    .font(.system(size: 28))
                    .foregroundStyle(.yellow.opacity(0.85))
                    .offset(x: 0, y: -88)
                    .transition(.scale.combined(with: .opacity))
            }

            if outcome == .deduct {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red.opacity(0.55))
                    .offset(x: 72, y: -40)
            }
        }
        .frame(height: 248)
        .accessibilityHidden(true)
    }

    private var outcomeKey: String {
        switch outcome {
        case .stuck: return "s"
        case .landed: return "l"
        case .deduct: return "d"
        case .none: return "n"
        }
    }

    private var gymnastOffsetX: CGFloat {
        switch outcome {
        case .stuck: return 0
        case .landed: return 4
        case .deduct: return -6
        case .none: return 0
        }
    }

    private var gymnastOffsetY: CGFloat {
        switch outcome {
        case .stuck: return -18
        case .landed: return 2
        case .deduct: return 10
        case .none: return 0
        }
    }

    private var gymnastTilt: Double {
        switch outcome {
        case .stuck: return 0
        case .landed: return 2
        case .deduct: return 14
        case .none: return 0
        }
    }

    private var floorTapeLines: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: w * 0.82, height: h * 0.62)
                    .position(x: w / 2, y: h / 2)

                Path { p in
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.42))
                    p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.42))
                }
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        }
    }

    private var gymnastFigure: some View {
        VStack(spacing: 4) {
            // Arms: V for stuck, neutral otherwise
            HStack(spacing: outcome == .stuck ? 28 : 12) {
                Capsule()
                    .fill(Color.white.opacity(0.38))
                    .frame(width: 3, height: outcome == .stuck ? 26 : 18)
                    .rotationEffect(.degrees(outcome == .stuck ? -48 : -25))
                Capsule()
                    .fill(Color.white.opacity(0.38))
                    .frame(width: 3, height: outcome == .stuck ? 26 : 18)
                    .rotationEffect(.degrees(outcome == .stuck ? 48 : 25))
            }
            .offset(y: 4)

            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 20, height: 20)
                .overlay(Circle().fill(accentColor.opacity(0.85)).frame(width: 8, height: 8))

            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.24))
                .frame(width: 28, height: 36)

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4, height: 22)
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4, height: 22)
            }
        }
    }
}
