import SwiftUI

struct DashboardView: View {
    let viewModel: LabViewModel
    @State private var motionHelper = CoreMotionHelper.shared
    @State private var appeared: Bool = false
    @State private var gaugeAnimationProgress: Double = 0
    @State private var showShareToFeed: Bool = false

    private var prqScore: Int { Int(viewModel.effectiveMetrics.prqScore) }
    private var prqNormalized: Double { viewModel.effectiveMetrics.prqScore / 100.0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                prqGaugeCard
                healthKitRow
                motionStreamCard
                neuralSyncCard
                shareToFeedButton
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.slateBackground)
        .sheet(isPresented: $showShareToFeed) {
            NavigationStack {
                ShareToFeedView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showShareToFeed = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
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
        }
        .onChange(of: prqScore) { _, newValue in
            withAnimation(.spring(duration: 0.6)) {
                gaugeAnimationProgress = Double(newValue) / 100.0
            }
        }
        .onDisappear {
            if motionHelper.isStreaming {
                motionHelper.stopStreaming()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Performance dashboard")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Theme.neonGreen)
                .tracking(1)

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
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 12)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: gaugeAnimationProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.neonGreen.opacity(0.4), Theme.neonGreen, Theme.neonGreen.opacity(0.8)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Theme.neonGreen.opacity(0.05))
                    .frame(width: 156, height: 156)

                VStack(spacing: 4) {
                    Text("\(prqScore)")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text("PRQ")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                        .tracking(4)
                }
            }

            HStack(spacing: 12) {
                Text(viewModel.userPRQTier.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tierColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(tierColor.opacity(0.12))
                    .clipShape(Capsule())

                Text("\(viewModel.profile.totalWorkouts) sessions")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Theme.neonGreen.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var healthKitRow: some View {
        HStack(spacing: 12) {
            healthMetricTile(
                icon: "flame.fill",
                value: String(format: "%.0f", viewModel.healthKit.activeCalories),
                unit: "kcal",
                label: "Active",
                color: .orange
            )

            healthMetricTile(
                icon: "figure.walk",
                value: viewModel.healthKit.isAuthorized ? String(format: "%.0f", viewModel.healthKit.stepCount) : "—",
                unit: "steps",
                label: "Steps",
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
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
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

                Text("Biometric stream")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                Circle()
                    .fill(motionHelper.isStreaming ? Theme.neonGreen : Color.gray)
                    .frame(width: 8, height: 8)

                Text(motionHelper.isStreaming ? "Live" : "Off")
                    .font(.system(size: 9, weight: .semibold))
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
                Text(motionHelper.isStreaming ? "Stop stream" : "Start stream")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(motionHelper.isStreaming ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
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

                Text("Neural sync")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                let unityManager = UnityManager.shared
                Circle()
                    .fill(unityManager.isUnityLoaded ? Theme.neonGreen : .orange)
                    .frame(width: 8, height: 8)

                Text(unityManager.isUnityLoaded ? "Linked" : "Standby")
                    .font(.system(size: 9, weight: .semibold))
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

            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
    }

    private var shareToFeedButton: some View {
        Button {
            showShareToFeed = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Share to feed")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
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
