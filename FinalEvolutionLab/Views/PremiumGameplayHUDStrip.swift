import SwiftUI

/// Thin glass HUD strip — one score line + mode subtitle for premium gameplay chrome.
struct PremiumGameplayHUDStrip: View {
    let scoreLine: String
    let subtitle: String
    let accentColor: Color
    var prqScore: Int? = nil

    @ScaledMetric(relativeTo: .title) private var scoreSize: CGFloat = 28
    @ScaledMetric(relativeTo: .caption) private var subtitleSize: CGFloat = 12

    var body: some View {
        HStack(alignment: .center, spacing: FELSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(scoreLine)
                    .font(FELTypography.title(scoreSize))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .accessibilityIdentifier("PremiumGameplayScoreLine")

                Text(subtitle)
                    .font(FELTypography.caption(subtitleSize))
                    .foregroundStyle(.white.opacity(0.62))
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
                    .accessibilityIdentifier("PremiumGameplayModeSubtitle")
            }

            Spacer(minLength: FELSpacing.xs)

            if let prqScore {
                prqPill(prqScore)
            }
        }
        .padding(.horizontal, FELSpacing.md)
        .padding(.vertical, FELSpacing.sm)
        .background { glassStripBackground }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(accentColor.opacity(0.18))
                .frame(height: 1)
        }
    }

    private var glassStripBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.88))
            LinearGradient(
                colors: [accentColor.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func prqPill(_ score: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accentColor.opacity(0.85))
            Text(FELPremiumCopy.HUD.readiness)
                .font(FELTypography.caption(10))
                .foregroundStyle(.white.opacity(0.72))
            Text("\(score)")
                .font(FELTypography.headline(14))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.55))
                .overlay {
                    Capsule()
                        .strokeBorder(accentColor.opacity(0.22), lineWidth: 1)
                }
        }
        .accessibilityLabel("\(FELPremiumCopy.HUD.readiness) \(score)")
    }
}
