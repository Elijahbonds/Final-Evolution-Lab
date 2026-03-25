import SwiftUI

/// Bonds Bounce 1.0 — zero-friction cold open: DeepMotion probe + Vault integrity during `deleteTheFearLaunchHeartbeat` (~1.2s), then hand off to shell.
struct BondsBounceSplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal = false
    @State private var taglineOpacity: Double = 0
    @State private var brandMarkOpacity: Double = 0

    private let launchHeartbeatSeconds: Double = 1.2

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Theme.deepBlack,
                    Color(red: 0.04, green: 0.06, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.brandBlue.opacity(0.22), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
            .opacity(reveal ? 1 : 0.3)

            VStack(spacing: 22) {
                Text("NEURO-MECHANIC")
                    .font(.system(size: 11, weight: .heavy, design: .default))
                    .tracking(7)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.brandCyan.opacity(0.95), Theme.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(brandMarkOpacity)
                    .blur(radius: brandMarkOpacity > 0.5 ? 0 : 1.2)

                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.brandCyan, Theme.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Theme.brandBlue.opacity(0.45), radius: 24)
                    .scaleEffect(reveal ? 1 : 0.86)
                    .opacity(reveal ? 1 : 0)

                Text("FINAL EVOLUTION LAB")
                    .font(.system(size: 15, weight: .black, design: .default))
                    .tracking(5)
                    .foregroundStyle(.white.opacity(0.92))
                    .opacity(reveal ? 1 : 0)

                Text("Your movement, audited.\nYour readiness, your edge.")
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.white.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 32)
                    .opacity(taglineOpacity)
                    .offset(y: taglineOpacity > 0.5 ? 0 : 12)
            }
        }
        .onAppear {
            if reduceMotion {
                brandMarkOpacity = 1
                reveal = true
                taglineOpacity = 1
                FELHaptics.deleteTheFearLaunchHeartbeat()
                Task {
                    await runLaunchPipeline()
                    await MainActor.run { onFinished() }
                }
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    brandMarkOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.06)) {
                    reveal = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                    FELHaptics.deleteTheFearLaunchHeartbeat()
                }
                withAnimation(.easeOut(duration: 0.55).delay(0.12)) {
                    taglineOpacity = 1
                }
                Task {
                    await runLaunchPipeline()
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            taglineOpacity = 0
                        }
                    }
                    try? await Task.sleep(nanoseconds: 380_000_000)
                    await MainActor.run {
                        onFinished()
                    }
                }
            }
        }
    }

    private func runLaunchPipeline() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    ArenaLaunchPrecache.runAtLaunch()
                    PRQNativeBridge.postMetrics([
                        "felWarmUpForBioSync": 1,
                        "felWarmUpHeartbeatSeconds": launchHeartbeatSeconds
                    ])
                }
            }
            group.addTask {
                _ = await FELDeepMotionHealthCheck.ping()
            }
            group.addTask {
                _ = await FELVaultIntegrityScanner.performScan()
            }
            group.addTask {
                let ns = UInt64(launchHeartbeatSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }
}
