import SwiftUI

struct DashboardView: View {
    let viewModel: LabViewModel
    @State private var motionHelper = CoreMotionHelper.shared
    @State private var appeared: Bool = false
    @State private var gaugeAnimationProgress: Double = 0
    @State private var showShareToFeed: Bool = false
    @State private var showRecoveryLab: Bool = false

    private var prqScore: Int { Int(viewModel.effectiveMetrics.prqScore) }
    private var prqNormalized: Double { viewModel.effectiveMetrics.prqScore / 100.0 }
    private var avatarConfig: AvatarSkinConfig { viewModel.profile.effectiveAvatarConfig }
    private var lastScan: SystemScanResult? { viewModel.profile.systemScan }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                athleteHubCard
                if viewModel.sessions.isEmpty && viewModel.gameResults.isEmpty {
                    emptyStateCard
                }
                prqGaugeCard
                healthKitRow
                recoveryLabButton
                motionStreamCard
                neuralSyncCard
                shareToFeedButton
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.slateBackground)
        .sheet(isPresented: $showRecoveryLab) {
            RecoveryLabView(viewModel: viewModel)
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
                            .accessibilityLabel("Close")
                            .accessibilityHint("Closes share to feed")
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
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PERFORMANCE DASHBOARD")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.neonGreen)
                    .tracking(4)

                Text("Status")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 12)
            evolutionShardCounterChip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var evolutionShardCounterChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.brandCyan)
            Text("\(viewModel.profile.evolutionShards)")
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(Capsule().strokeBorder(Theme.brandCyan.opacity(0.25), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Evolution shards, \(viewModel.profile.evolutionShards)")
    }

    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Theme.neonGreen.opacity(0.5))
            Text("No activity yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text("Complete a workout in Train or play a round in the Lab to see your stats here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.neonGreen.opacity(0.12), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No activity yet. Complete a workout in Train or play a round in the Lab to see your stats here.")
    }

    /// Phase 2: Athlete hub summary – avatar + key readiness metrics from latest scan.
    private var athleteHubCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            Color(
                                red: avatarConfig.auraColorR,
                                green: avatarConfig.auraColorG,
                                blue: avatarConfig.auraColorB
                            ).opacity(0.2)
                        )
                        .frame(width: 76, height: 76)

                    Image(systemName: "figure.stand")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(
                            Color(
                                red: avatarConfig.auraColorR,
                                green: avatarConfig.auraColorG,
                                blue: avatarConfig.auraColorB
                            )
                        )
                        .scaleEffect(
                            x: avatarConfig.weightScale,
                            y: avatarConfig.heightScale
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.profile.displayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text(viewModel.profile.athleteTag)
                        .font(.system(.caption, design: .monospaced, weight: .regular))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        metricChip(
                            label: "PRQ",
                            value: String(prqScore)
                        )
                        if let scan = lastScan {
                            metricChip(
                                label: "VERT",
                                value: String(format: "%.1f\"", scan.verticalEstimateInches)
                            )
                            metricChip(
                                label: "FLIGHT",
                                value: String(format: "%.2fs", scan.flightTimeSeconds)
                            )
                        }
                    }
                }
                Spacer()
            }

            if let scan = lastScan {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.neonGreen)
                    Text("Last system scan: ")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(scan.movementGrade)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk.arrival")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("No system scan yet. Run a scan in the Lab to calibrate.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            Color(
                                red: avatarConfig.auraColorR,
                                green: avatarConfig.auraColorG,
                                blue: avatarConfig.auraColorB
                            ).opacity(0.18),
                            lineWidth: 1
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Athlete hub. \(viewModel.profile.displayName), PRQ \(prqScore)." + (lastScan != nil ? " System scan loaded." : " No system scan yet."))
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
                    .font(.system(size: 11, weight: .black, design: .monospaced))
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

    private func metricChip(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
    }

    private var recoveryLabButton: some View {
        Button {
            showRecoveryLab = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recovery Lab")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Readiness, audit-based suggestions, neural decompression")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recovery Lab")
        .accessibilityHint("Readiness, suggestions, neural decompression")
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
