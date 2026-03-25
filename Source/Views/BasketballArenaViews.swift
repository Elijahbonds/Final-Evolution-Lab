import SwiftUI

// MARK: - Venice Beach street hoops (H2H / 3v3)

/// Sunset sky, ocean band, sand, palm silhouettes — replaces the generic gradient for `.basketballHeadToHead` and `.basketball3v3`.
struct VeniceBeachHoopsArenaBackground: View {
    var accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.22, blue: 0.38),
                        Color(red: 0.95, green: 0.45, blue: 0.28),
                        Color(red: 1, green: 0.72, blue: 0.38),
                        Color(red: 0.55, green: 0.75, blue: 0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Sun disc
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1, green: 0.92, blue: 0.55).opacity(0.85),
                                Color(red: 1, green: 0.65, blue: 0.35).opacity(0.35),
                                .clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 90
                        )
                    )
                    .frame(width: 120, height: 120)
                    .position(x: geo.size.width * 0.72, y: h * 0.22)
                    .allowsHitTesting(false)

                // Ocean
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.35, blue: 0.48),
                            Color(red: 0.02, green: 0.18, blue: 0.32)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h * 0.28)
                }

                // Sand / boardwalk wash
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.7, blue: 0.48).opacity(0.35),
                            Color(red: 0.35, green: 0.28, blue: 0.2).opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h * 0.14)
                }

                // Palm silhouettes
                ZStack {
                    palmCluster(trunkHeight: h * 0.22)
                        .position(x: geo.size.width * 0.1, y: h * 0.36)
                    palmCluster(trunkHeight: h * 0.18)
                        .position(x: geo.size.width * 0.9, y: h * 0.38)
                }
                .allowsHitTesting(false)

                // Accent wash (hoops energy)
                LinearGradient(
                    colors: [accentColor.opacity(0.12), .clear, accentColor.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    center: .init(x: 0.5, y: 0.55),
                    startRadius: 80,
                    endRadius: 420
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    private func palmCluster(trunkHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Color(red: 0.08, green: 0.06, blue: 0.05).opacity(0.65))
                .frame(width: 5, height: trunkHeight)
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 0.06, green: 0.12, blue: 0.08).opacity(0.55))
                    .frame(width: 3, height: trunkHeight * 0.45)
                    .rotationEffect(.degrees(-32 + Double(i) * 16))
                    .offset(x: CGFloat(i - 2) * 6, y: -trunkHeight * 0.35)
            }
        }
    }
}
