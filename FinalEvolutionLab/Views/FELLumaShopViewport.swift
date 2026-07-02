import SwiftUI

/// Premium-framed Luma Venice shop viewport for Vault, Shard Shop, and Card Marketplace headers.
struct FELLumaShopViewport: View {
    var height: CGFloat = 200
    var caption: String = "Venice Boardwalk"
    var subtitle: String? = "Luma photogrammetry showroom"
    var cornerRadius: CGFloat = 20
    var accent: Color = Theme.brandCyan
    var showScanBadge: Bool = true
    var neuralDrive: Double = 50

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.45), accent.opacity(0.08), Theme.brandBlue.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .shadow(color: accent.opacity(0.12), radius: 16, y: 6)

            ZStack(alignment: .bottomLeading) {
                GameSceneHostView(gameMode: .marketBrowse, neuralDrive: neuralDrive)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    }

                LinearGradient(
                    colors: [.clear, Theme.deepBlack.opacity(0.35), Theme.deepBlack.opacity(0.88)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, Theme.deepBlack.opacity(0.55)],
                    center: .center,
                    startRadius: height * 0.2,
                    endRadius: height * 0.95
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)

                LinearGradient(
                    colors: [Theme.deepBlack.opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.35)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)

                captionBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption). \(subtitle ?? "Three-dimensional shop preview.")")
    }

    private var captionBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if showScanBadge {
                Text("LUMA")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(caption.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(1.2)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "view.3d")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent.opacity(0.7))
        }
    }
}
