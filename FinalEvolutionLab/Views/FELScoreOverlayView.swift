import SwiftUI

/// Minimal PRQ badge — top-trailing corner, translucent, non-blocking except tap target.
struct FELScoreOverlayView: View {
    @State private var scoreManager = FELScoreManager.shared
    @State private var showDetail: Bool = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                compactBadge
                    .padding(.trailing, 12)
                    .padding(.top, 6)
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .overlay(alignment: .bottom) {
            if showDetail {
                detailCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var compactBadge: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                showDetail.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(badgeColor.opacity(0.9))

                Text("\(scoreManager.currentPrqScore)")
                    .font(FELTypography.mono(13, weight: .black))
                    .foregroundStyle(.white.opacity(0.92))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.65))
                    .overlay {
                        Capsule()
                            .strokeBorder(badgeColor.opacity(0.28), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(true)
        .accessibilityLabel("\(FELPremiumCopy.HUD.readiness) \(scoreManager.currentPrqScore)")
        .accessibilityHint(FELPremiumCopy.HUD.readinessHint)
    }

    private var detailCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(FELPremiumCopy.HUD.readiness)
                        .font(FELTypography.mono(8, weight: .heavy))
                        .tracking(1.2)
                }
                .foregroundStyle(.secondary)

                Text("\(scoreManager.currentPrqScore)")
                    .font(FELTypography.mono(28, weight: .black))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(scoreManager.prqTier)
                    .font(FELTypography.mono(9, weight: .black))
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(badgeColor.opacity(0.14)))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(badgeColor)
                            .frame(width: geo.size.width * CGFloat(scoreManager.currentPrqScore) / 100.0)
                    }
                }
                .frame(width: 72, height: 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
        .allowsHitTesting(true)
    }

    private var badgeColor: Color {
        switch scoreManager.tierColor {
        case "gold": .yellow
        case "purple": Theme.elitePurple
        case "blue": Theme.brandBlue
        case "green": .green
        default: .gray
        }
    }
}
