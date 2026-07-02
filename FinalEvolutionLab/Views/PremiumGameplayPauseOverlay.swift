import SwiftUI

/// Premium pause sheet — Resume, Change Cartridge, Exit.
struct PremiumGameplayPauseOverlay: View {
    var showsChangeCartridge: Bool
    var accentColor: Color
    var onResume: () -> Void
    var onChangeCartridge: () -> Void
    var onExit: () -> Void
    var onDismissTap: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.15))
                .onTapGesture(perform: onDismissTap)

            VStack(spacing: FELSpacing.lg) {
                Text("Paused")
                    .font(FELTypography.title(24))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: FELSpacing.sm) {
                    pauseRow(
                        title: "Resume",
                        icon: "play.fill",
                        tint: Theme.neonGreen,
                        identifier: "GameplayResumeButton",
                        action: onResume
                    )

                    if showsChangeCartridge {
                        pauseRow(
                            title: "Change Cartridge",
                            icon: "square.grid.2x2.fill",
                            tint: Theme.brandCyan,
                            identifier: "GameplayChangeCartridgeButton",
                            action: onChangeCartridge
                        )
                    }

                    pauseRow(
                        title: "Exit",
                        icon: "rectangle.portrait.and.arrow.right",
                        tint: accentColor,
                        identifier: "GameplayEjectButton",
                        action: onExit
                    )
                }
            }
            .padding(FELSpacing.xl)
            .background {
                RoundedRectangle(cornerRadius: FELSpacing.cardRadiusLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: FELSpacing.cardRadiusLarge, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .padding(.horizontal, FELSpacing.xxl)
        }
        .accessibilityIdentifier("GameplayPauseOverlay")
    }

    private func pauseRow(
        title: String,
        icon: String,
        tint: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: FELSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                Text(title)
                    .font(FELTypography.headline(16))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, FELSpacing.md)
            .padding(.vertical, FELSpacing.sm + 2)
            .background {
                RoundedRectangle(cornerRadius: FELSpacing.chipRadius, style: .continuous)
                    .fill(tint.opacity(0.22))
                    .overlay {
                        RoundedRectangle(cornerRadius: FELSpacing.chipRadius, style: .continuous)
                            .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
