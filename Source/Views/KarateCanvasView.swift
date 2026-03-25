import SwiftUI

// MARK: - Full-screen dojo environment (Karate only — separate from Venice / generic Arena)

/// Interior training hall: wood, warm lanterns, shoji-style side light. Used as `environmentGradient` replacement for `.karate`.
struct KarateDojoArenaBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            dojoContent(floorBandHeight: geo.size.height * 0.42)
        }
        .ignoresSafeArea()
    }

    private func dojoContent(floorBandHeight: CGFloat) -> some View {
        ZStack {
            // Deep dojo void
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.03),
                    Color(red: 0.12, green: 0.04, blue: 0.05),
                    Color(red: 0.06, green: 0.03, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ceiling pool light (paper lantern feel)
            RadialGradient(
                colors: [
                    Color(red: 0.45, green: 0.32, blue: 0.22).opacity(0.35),
                    Color(red: 0.25, green: 0.12, blue: 0.1).opacity(0.12),
                    .clear
                ],
                center: .init(x: 0.5, y: 0.12),
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()

            // Side shoji panels (cool rim light)
            HStack(spacing: 0) {
                shojiColumn(edge: .leading)
                Spacer(minLength: 0)
                shojiColumn(edge: .trailing)
            }
            .ignoresSafeArea()

            // Wood grain hint (subtle vertical strokes)
            Canvas { context, size in
                let count = 28
                for i in 0..<count {
                    let x = size.width * (CGFloat(i) + 0.5) / CGFloat(count)
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + CGFloat(i % 3 - 1) * 0.4, y: size.height))
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(0.015 + Double(i % 5) * 0.008)),
                        lineWidth: 0.6
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Floor plane (polished wood toward tatami)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.1, blue: 0.08),
                        Color(red: 0.1, green: 0.05, blue: 0.04),
                        Color.black.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: floorBandHeight)
                .overlay(
                    LinearGradient(
                        colors: [.clear, accentColor.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            .ignoresSafeArea()

            // Corner lanterns
            VStack {
                HStack {
                    lanternGlow
                    Spacer()
                    lanternGlow
                }
                .padding(.horizontal, 36)
                .padding(.top, 100)
                Spacer()
            }
            .allowsHitTesting(false)

            // Vignette
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shojiColumn(edge: HorizontalEdge) -> some View {
        let w: CGFloat = 56
        return HStack {
            if edge == .trailing { Spacer(minLength: 0) }
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.78, blue: 0.65).opacity(0.14),
                    Color(red: 0.4, green: 0.35, blue: 0.32).opacity(0.06)
                ],
                startPoint: edge == .leading ? .leading : .trailing,
                endPoint: edge == .leading ? .trailing : .leading
            )
            .frame(width: w)
            .overlay(
                VStack(spacing: 5) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.25))
                            .frame(height: 2)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            )
            if edge == .leading { Spacer(minLength: 0) }
        }
    }

    private var lanternGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.72, blue: 0.38).opacity(0.45),
                        Color(red: 0.9, green: 0.45, blue: 0.2).opacity(0.15),
                        .clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 36
                )
            )
            .frame(width: 72, height: 72)
            .blur(radius: 6)
    }
}

// MARK: - Tatami bout canvas

/// Dojo shomen + tatami + silhouettes; reacts to strike / block / block window.
struct KarateCanvasView: View {
    let accentColor: Color
    let isStriking: Bool
    let isBlocked: Bool
    /// True while "Block?" resolution is in progress — opponent side tension.
    var blockPhaseActive: Bool = false

    var body: some View {
        ZStack {
            // Shomen (front wall) band
            VStack(spacing: 0) {
                shomenWall
                tatamiArea
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))

            if blockPhaseActive {
                TimelineView(.animation(minimumInterval: 0.05)) { ctx in
                    let pulse = (sin(ctx.date.timeIntervalSinceReferenceDate * 5) + 1) / 2
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.red.opacity(0.35 + 0.25 * pulse), lineWidth: 2)
                }
            }
        }
        .frame(height: 268)
        .accessibilityHidden(true)
    }

    private var shomenWall: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.08, blue: 0.07),
                    Color(red: 0.1, green: 0.05, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Hanging scroll (kakejiku)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.92, green: 0.88, blue: 0.8).opacity(0.12))
                .frame(width: 52, height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
                .overlay(
                    Rectangle()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 28, height: 3)
                        .offset(y: -18)
                )
                .offset(y: 4)

            Text("道場")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.12))
                .offset(y: 52)
        }
        .frame(height: 88)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .frame(height: 1)
        }
    }

    private var tatamiArea: some View {
        ZStack {
            // Tatami grid
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.2, blue: 0.1),
                    Color(red: 0.08, green: 0.14, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
            .padding(.vertical, 18)

            HStack {
                Rectangle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 2)
                Spacer()
                Rectangle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 2)
            }
            .padding(.horizontal, 36)

            HStack {
                fighter(isPlayer: true, isGi: true)
                    .scaleEffect(isStriking ? 1.08 : 1.0)
                    .offset(x: isStriking ? 10 : 0)
                    .animation(.easeOut(duration: 0.12), value: isStriking)

                Spacer()

                fighter(isPlayer: false, isGi: false)
                    .scaleEffect(isBlocked ? 1.06 : 1.0)
                    .overlay(
                        Capsule()
                            .stroke(isBlocked ? Color.red.opacity(0.75) : Color.clear, lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .animation(.easeOut(duration: 0.12), value: isBlocked)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(accentColor.opacity(0.28), lineWidth: 1)
        )
    }

    private func fighter(isPlayer: Bool, isGi: Bool) -> some View {
        let bodyTone = isGi
            ? Color(red: 0.92, green: 0.9, blue: 0.86)
            : Color.white.opacity(0.14)
        let belt = isGi ? Color.black : Color.clear

        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .fill(isPlayer ? accentColor.opacity(0.9) : Color.white.opacity(0.2))
                        .frame(width: 11, height: 11)
                )
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(bodyTone.opacity(isGi ? 0.35 : 0.22))
                    .frame(width: 30, height: 40)
                if isGi {
                    Rectangle()
                        .fill(belt)
                        .frame(width: 32, height: 4)
                        .offset(y: 6)
                }
            }
            HStack(spacing: 5) {
                Capsule()
                    .fill(bodyTone.opacity(0.3))
                    .frame(width: 4, height: 22)
                Capsule()
                    .fill(bodyTone.opacity(0.3))
                    .frame(width: 4, height: 22)
            }
        }
    }
}
