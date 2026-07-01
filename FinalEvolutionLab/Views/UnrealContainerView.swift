import SwiftUI

// MARK: - NexusContainerView

/// Full-screen Nexus scene container.
///
/// Presents the active NexusScene from NexusRenderer when one is loaded,
/// a boot-progress indicator during engine startup, or a placeholder when
/// no scene is active. Replaces the former Unreal embedded-framework container.
struct NexusContainerView: View {
    @State private var renderer = NexusRenderer.shared
    @State private var engine   = NexusEngine.shared

    var body: some View {
        ZStack {
            if let scene = renderer.activeScene {
                NexusSceneView(
                    scene: scene,
                    physics: renderer.playerPhysics
                )
                .ignoresSafeArea()

                dismissButton
            } else if case .ready = engine.bootState {
                nexusStandbyPlaceholder
            } else {
                bootProgressView
            }
        }
    }

    // MARK: - Sub-views

    private var bootProgressView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.brandCyan.opacity(0.06))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .tint(Theme.brandCyan)
                    .scaleEffect(1.4)
            }

            VStack(spacing: 6) {
                Text("NEXUS ENGINE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(4)
                Text(engine.bootState.displayLabel.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: engine.bootState.displayLabel)
            }

            healthDots
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.deepBlack)
    }

    private var healthDots: some View {
        HStack(spacing: 10) {
            dot("Firebase",   ready: engine.firestoreReady)
            dot("HealthKit",  ready: engine.healthKitAuthorized)
            dot("Renderer",   ready: engine.nexusEngineReady)
            dot("Arena Net",  ready: engine.emergentConnected)
        }
    }

    private func dot(_ label: String, ready: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(ready ? Theme.neonGreen : Color.white.opacity(0.12))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var nexusStandbyPlaceholder: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.brandCyan.opacity(0.08))
                    .frame(width: 120, height: 120)
                Circle()
                    .strokeBorder(Theme.brandCyan.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)
                Image(systemName: "atom")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Theme.brandCyan)
            }

            VStack(spacing: 6) {
                Text("NEXUS ENGINE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(4)

                Text("Ready — launch a game mode to load a scene")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                healthRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.deepBlack)
    }

    private var healthRow: some View {
        HStack(spacing: 6) {
            let health = engine.overallHealth
            Image(systemName: health == .optimal ? "checkmark.circle.fill" : health == .degraded ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(health == .optimal ? Theme.neonGreen : health == .degraded ? .orange : .red)
            Text(health == .optimal ? "OPTIMAL" : health == .degraded ? "DEGRADED" : "OFFLINE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(health == .optimal ? Theme.neonGreen : health == .degraded ? .orange : .red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }

    private var dismissButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        NexusEngine.shared.endSession()
                    }
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
            Spacer()
        }
    }
}

// MARK: - Backward-compat alias

typealias UnrealContainerView = NexusContainerView
