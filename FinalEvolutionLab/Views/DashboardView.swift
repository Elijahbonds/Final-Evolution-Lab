import SwiftUI
import UIKit

struct DashboardView: View {
    let viewModel: LabViewModel
    @State private var motionHelper = CoreMotionHelper.shared
    @State private var appeared: Bool = false
    @State private var gaugeAnimationProgress: Double = 0
    @State private var showShareToFeed: Bool = false
    @State private var bridgeToastVisible: Bool = false
    @State private var orbRingRotation: Double = 0
    @State private var outerPulse: Double = 0.5
    @State private var particlePhase: Double = 0
#if DEBUG
    @State private var simulateScanBusy: Bool = false
    @State private var simulateScanMessage: String?
#endif

    private var prqScore: Int { Int(viewModel.effectiveMetrics.prqScore) }
    private var prqNormalized: Double { viewModel.effectiveMetrics.prqScore / 100.0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    prqGaugeCard
                    healthKitRow
                    motionStreamCard
                    neuralSyncCard
#if DEBUG
                    simulateSystemScanDebugCard
#endif
                    shareToFeedButton
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.slateBackground)

            if bridgeToastVisible {
                bridgeSyncToast
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showShareToFeed) {
            NavigationStack {
                ShareToFeedView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showShareToFeed = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                gaugeAnimationProgress = prqNormalized
            }
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                orbRingRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                outerPulse = 1.0
            }
        }
        .onChange(of: prqScore) { _, newValue in
            withAnimation(.spring(duration: 0.6)) {
                gaugeAnimationProgress = Double(newValue) / 100.0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felSystemScanBridgeCompleted)) { _ in
            triggerBridgeSyncFeedback()
        }
    }

    private var bridgeSyncToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.neonGreen)
            Text("Scan synced · bridge sent")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Theme.neonGreen.opacity(0.35), lineWidth: 1)
        )
    }

    private func triggerBridgeSyncFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            bridgeToastVisible = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_850_000_000)
            withAnimation(.easeOut(duration: 0.28)) {
                bridgeToastVisible = false
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PERFORMANCE DASHBOARD")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.neonGreen)
                .tracking(4)

            Text("Status")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var prqGaugeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outermost ambient glow ring — pulses with breathing animation
                Circle()
                    .stroke(Theme.neonGreen.opacity(outerPulse * 0.12), lineWidth: 22)
                    .frame(width: 200, height: 200)
                    .blur(radius: 8)

                // Counter-rotating dashed ring (outer)
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [Theme.neonGreen.opacity(0.3), .clear, Theme.neonGreen.opacity(0.2)],
                            center: .center),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                    .frame(width: 196, height: 196)
                    .rotationEffect(.degrees(-orbRingRotation * 0.7))

                // Track ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 12)
                    .frame(width: 180, height: 180)

                // PRQ progress arc
                Circle()
                    .trim(from: 0, to: gaugeAnimationProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.neonGreen.opacity(0.4), Theme.neonGreen, Theme.neonGreen.opacity(0.8)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                // Co-rotating thin inner ring
                Circle()
                    .stroke(Theme.neonGreen.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 162, height: 162)
                    .rotationEffect(.degrees(orbRingRotation))

                // Inner fill
                Circle()
                    .fill(Theme.neonGreen.opacity(0.05))
                    .frame(width: 156, height: 156)

                // Score + label
                VStack(spacing: 4) {
                    Text("\(prqScore)")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .shadow(color: Theme.neonGreen.opacity(0.35), radius: 10)

                    Text("PRQ")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                        .tracking(4)
                }

                // Orbiting energy dot at arc endpoint
                let angle = gaugeAnimationProgress * 360.0 - 90.0
                Circle()
                    .fill(Theme.neonGreen)
                    .frame(width: 10, height: 10)
                    .shadow(color: Theme.neonGreen, radius: 6)
                    .offset(x: 90 * CGFloat(cos(angle * .pi / 180)),
                            y: 90 * CGFloat(sin(angle * .pi / 180)))
            }

            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Circle().fill(tierColor).frame(width: 6, height: 6)
                    Text(viewModel.userPRQTier.rawValue)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(tierColor)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(tierColor.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(tierColor.opacity(0.25), lineWidth: 1))

                Text("\(viewModel.profile.totalWorkouts) sessions")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Theme.slateCard)
                // Subtle diagonal gradient overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [Theme.neonGreen.opacity(0.04), .clear, Theme.neonGreen.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Theme.neonGreen.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: Theme.neonGreen.opacity(0.08), radius: 20, y: 4)
        )
    }

    private var healthKitRow: some View {
        HStack(spacing: 12) {
            healthMetricTile(
                icon: "flame.fill",
                value: String(format: "%.0f", viewModel.healthKit.activeCalories),
                unit: "kcal",
                label: "ACTIVE",
                color: .orange
            )

            healthMetricTile(
                icon: "figure.walk",
                value: "—",
                unit: "steps",
                label: "STEPS",
                color: Theme.neonGreen
            )

            healthMetricTile(
                icon: "heart.fill",
                value: viewModel.healthKit.heartRate > 0 ? String(format: "%.0f", viewModel.healthKit.heartRate) : "—",
                unit: "bpm",
                label: "HR",
                color: .red
            )
        }
    }

    private func healthMetricTile(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }

                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(color.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private var motionStreamCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gyroscope")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.neonGreen)

                Text("BIOMETRIC STREAM")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()

                Circle()
                    .fill(motionHelper.isStreaming ? Theme.neonGreen : Color.gray)
                    .frame(width: 8, height: 8)

                Text(motionHelper.isStreaming ? "LIVE" : "OFF")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(motionHelper.isStreaming ? Theme.neonGreen : .secondary)
            }

            if motionHelper.isStreaming {
                HStack(spacing: 16) {
                    motionAxis(label: "X", value: motionHelper.accelerationX, color: .red)
                    motionAxis(label: "Y", value: motionHelper.accelerationY, color: Theme.neonGreen)
                    motionAxis(label: "Z", value: motionHelper.accelerationZ, color: Theme.brandBlue)
                }
            }

            Button {
                if motionHelper.isStreaming {
                    motionHelper.stopStreaming()
                } else {
                    motionHelper.startStreaming()
                }
            } label: {
                Text(motionHelper.isStreaming ? "STOP STREAM" : "START STREAM")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(motionHelper.isStreaming ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(motionHelper.isStreaming ? Color.white.opacity(0.08) : Theme.neonGreen)
                    .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private func motionAxis(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)

            Text(String(format: "%.2f", value))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private var neuralSyncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)

                Text("NEURAL SYNC")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()

                let unityManager = UnityManager.shared
                Circle()
                    .fill(unityManager.isUnityLoaded ? Theme.neonGreen : .orange)
                    .frame(width: 8, height: 8)

                Text(unityManager.isUnityLoaded ? "LINKED" : "STANDBY")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(unityManager.isUnityLoaded ? Theme.neonGreen : .orange)
            }

            HStack(spacing: 12) {
                syncMetric(label: "Neural Drive", value: String(format: "%.0f", viewModel.effectiveMetrics.neuralDrive), icon: "bolt.fill")
                syncMetric(label: "Readiness", value: String(format: "%.0f", viewModel.effectiveMetrics.readinessScore), icon: "waveform.path.ecg")
                syncMetric(label: "Efficiency", value: String(format: "%.0f", viewModel.effectiveMetrics.efficiencyScore), icon: "gauge.with.dots.needle.33percent")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.brandBlue.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private func syncMetric(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.brandBlue)

            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)

            Text(label.uppercased())
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

#if DEBUG
    private var simulateSystemScanDebugCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)

                Text("DEBUG · SYSTEM SCAN")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()
            }

            Text("Writes a mock scan to Firestore and pushes JSON to Unreal + Emergent WebSocket (if configured). Check Xcode console for [NexusBridge].")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

            Button {
                Task {
                    simulateScanBusy = true
                    simulateScanMessage = nil
                    defer { simulateScanBusy = false }
                    do {
                        try await SystemScanFirestoreSync.shared.syncSimulatedDebugScan()
                        simulateScanMessage = nil
                    } catch {
                        simulateScanMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if simulateScanBusy {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(simulateScanBusy ? "SYNCING…" : "SIMULATE SCAN")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.9))
                .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(simulateScanBusy)

            if let simulateScanMessage {
                Text(simulateScanMessage)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(simulateScanMessage.contains("synced") ? Theme.neonGreen : .orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
                )
        )
    }
#endif

    private var shareToFeedButton: some View {
        Button {
            showShareToFeed = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("SHARE TO FEED")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(2)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.neonGreen)
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    private var tierColor: Color {
        switch viewModel.userPRQTier {
        case .diamond: .yellow
        case .platinum: Theme.elitePurple
        case .gold: .orange
        case .silver: Theme.brandBlue
        case .bronze: Theme.neonGreen
        case .unranked: .gray
        }
    }
}
