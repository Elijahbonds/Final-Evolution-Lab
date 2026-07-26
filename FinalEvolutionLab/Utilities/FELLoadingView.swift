import SwiftUI

/// Branded arena loading veil — shimmer skeleton + FEL spinner (replaces plain "Loading…").
struct FELLoadingView: View {
    var title: String
    var accentColor: Color = Theme.brandCyan
    var showsSkeleton: Bool = true

    @State private var shimmerPhase: CGFloat = -1
    @State private var spin = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.deepBlack.opacity(0.94),
                    accentColor.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: FELSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(accentColor.opacity(0.12), lineWidth: 4)
                        .frame(width: 52, height: 52)

                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            AngularGradient(
                                colors: [accentColor.opacity(0.15), accentColor, accentColor.opacity(0.15)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accentColor)
                        .shadow(color: accentColor.opacity(0.5), radius: 8)
                }

                Text(title.uppercased())
                    .font(FELTypography.mono(10, weight: .black))
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(2)

                if showsSkeleton {
                    skeletonBars
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            spin = true
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.5
            }
        }
    }

    private var skeletonBars: some View {
        VStack(spacing: FELSpacing.xs) {
            skeletonBar(width: 160, height: 10)
            skeletonBar(width: 120, height: 8)
        }
        .padding(.top, FELSpacing.xs)
    }

    private func skeletonBar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color.white.opacity(0.08))
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [.clear, accentColor.opacity(0.35), .clear],
                            startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0.5),
                            endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 0.5)
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))
            }
    }
}
