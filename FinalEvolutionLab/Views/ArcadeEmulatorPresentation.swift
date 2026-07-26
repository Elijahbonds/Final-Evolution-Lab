import SwiftUI

/// Short, skippable boot — premium console launcher splash.
struct NexusSystemBootView: View {
    let onComplete: () -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.92
    @State private var subtitleOpacity: Double = 0
    @State private var didFinish = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.deepBlack,
                    Color(red: 0.04, green: 0.06, blue: 0.1),
                    Theme.deepBlack,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.brandCyan.opacity(0.28),
                                Theme.brandBlue.opacity(0.14),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.82)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(color: Theme.brandCyan.opacity(0.22), radius: 16, y: 6)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("Library")
                    .font(FELTypography.headline(20))
                    .foregroundStyle(.white.opacity(0.92))
                    .opacity(subtitleOpacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finishBoot() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.38)) {
                logoOpacity = 1
                logoScale = 1
            }
            withAnimation(.easeOut(duration: 0.32).delay(0.18)) {
                subtitleOpacity = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(720))
                finishBoot()
            }
        }
        .accessibilityLabel("Arcade library boot")
        .accessibilityHint("Double tap to skip")
    }

    private func finishBoot() {
        guard !didFinish else { return }
        didFinish = true
        ArcadeLibraryPreferences.skipBootSequence = true
        onComplete()
    }
}

/// Subtle CRT scanlines — toggle in Settings (default on).
struct CRTScanlineOverlay: View {
    var opacity: Double = 0.08

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let lineSpacing: CGFloat = 3
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.black.opacity(opacity)))
                    y += lineSpacing
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Wraps emulator surfaces with ambient gradient and optional CRT tint.
struct ArcadeEmulatorChrome<Content: View>: View {
    @AppStorage(Config.crtScanlineDefaultsKey) private var crtScanlinesEnabled = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.deepBlack,
                    Color(red: 0.03, green: 0.05, blue: 0.08),
                    Theme.slateBackground,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Theme.brandCyan.opacity(0.06),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            content()
            if crtScanlinesEnabled {
                CRTScanlineOverlay(opacity: 0.05)
            }
        }
    }
}
