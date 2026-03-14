import SwiftUI

struct MatchmakingView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode
    let onMatchFound: (MatchmakingOpponent, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchingPhase: Bool = false
    @State private var pulseRing: CGFloat = 0
    @State private var selectedTier: PRQTier?
    @State private var showNeuralScan = false
    @State private var sessionReadiness: Double = 50
    @State private var showRecentMatches = false
    @State private var pendingCalibrateOpponent: MatchmakingOpponent?

    private var userTier: PRQTier {
        PRQTier.fromPRQ(viewModel.effectiveMetrics.prqScore)
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            Theme.meshGradient.opacity(0.3).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                centerContent
                Spacer()
                bottomControls
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showNeuralScan) {
            NeuralReadinessScanView { readiness in
                sessionReadiness = readiness
                showNeuralScan = false
                if let pendingCalibrateOpponent {
                    onMatchFound(pendingCalibrateOpponent, readiness)
                    self.pendingCalibrateOpponent = nil
                }
            }
        }
        .sheet(isPresented: $showRecentMatches) {
            recentMatchesSheet
        }
        .onAppear {
            viewModel.globalLeaderboard.simulateOnlinePresence()
        }
        .onDisappear {
            viewModel.globalLeaderboard.cancelMatchmaking()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                    .symbolEffect(.pulse, isActive: searchingPhase)

                Text("Global matchmaking")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
            }

            Text(gameMode.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("\(viewModel.globalLeaderboard.onlinePlayerCount) online")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green.opacity(0.8))
                }

                HStack(spacing: 4) {
                    Image(systemName: viewModel.globalLeaderboard.connectionQuality.icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(viewModel.globalLeaderboard.connectionQuality == .good ? Theme.brandCyan : .orange)
                    Text(viewModel.globalLeaderboard.connectionQuality.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(viewModel.globalLeaderboard.connectionQuality == .good ? Theme.brandCyan.opacity(0.7) : .orange.opacity(0.7))
                }

                if !viewModel.globalLeaderboard.recentMatches.isEmpty {
                    Button {
                        showRecentMatches = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 9))
                            Text("History")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 20)
    }

    private var centerContent: some View {
        Group {
            switch viewModel.globalLeaderboard.matchmakingState {
            case .idle:
                idleState
            case .searching(let tier):
                searchingState(tier: tier)
            case .found(let result):
                foundState(result: result)
            case .failed:
                failedState
            }
        }
    }

    private var idleState: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(Theme.brandCyan.opacity(0.08 + Double(ring) * 0.04), lineWidth: 1)
                        .frame(width: CGFloat(100 + ring * 40), height: CGFloat(100 + ring * 40))
                }

                PRQTierBadge(tier: userTier, prq: viewModel.effectiveMetrics.prqScore)
            }

            VStack(spacing: 8) {
                Text("Find opponent")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text("Match by PRQ tier for balanced competition")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tier filter")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        TierChip(label: "Any", isSelected: selectedTier == nil) {
                            selectedTier = nil
                        }

                        ForEach(PRQTier.allCases, id: \.rawValue) { tier in
                            TierChip(
                                label: tier.rawValue,
                                icon: tier.displayIcon,
                                color: tierColor(tier),
                                isSelected: selectedTier == tier
                            ) {
                                selectedTier = selectedTier == tier ? nil : tier
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }

            Button {
                Task {
                    await viewModel.globalLeaderboard.findMatch(
                        userPRQ: viewModel.effectiveMetrics.prqScore,
                        preferredTier: selectedTier
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Theme.brandCyan)
                .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
        }
    }

    private func searchingState(tier: PRQTier) -> some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<4, id: \.self) { ring in
                    Circle()
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1.5)
                        .frame(width: CGFloat(60 + ring * 30), height: CGFloat(60 + ring * 30))
                        .scaleEffect(searchingPhase ? 1.2 : 0.9)
                        .opacity(searchingPhase ? 0.2 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(ring) * 0.2),
                            value: searchingPhase
                        )
                }

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                    .symbolEffect(.variableColor.iterative, isActive: true)
            }

            VStack(spacing: 8) {
                Text("Searching...")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("Looking for \(tier.rawValue) opponents")
                    .font(.caption)
                    .foregroundStyle(Theme.brandCyan.opacity(0.7))

                Text("Scanning \(viewModel.globalLeaderboard.onlinePlayerCount) active players")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("Cancel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            withAnimation { searchingPhase = true }
        }
    }

    private func foundState(result: MatchmakingResult) -> some View {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.brandBlue.opacity(0.1))
                            .frame(width: 64, height: 64)

                        Image(systemName: viewModel.profile.avatarSystemName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.brandBlue)
                    }

                    Text("You")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.0f", viewModel.effectiveMetrics.prqScore))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Text("VS")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Theme.brandCyan)

                    matchQualityBadge(result.matchQuality)
                }

                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 64, height: 64)

                        Image(systemName: result.opponent.avatarSystemName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.red)
                    }

                    Text(String(result.opponent.displayName.prefix(8)))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.0f", result.opponent.prqScore))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 12) {
                StatPill(label: "Tier", value: result.opponent.tier.rawValue)
                StatPill(label: "Win rate", value: String(format: "%.0f%%", result.opponent.winRate * 100))
                StatPill(label: "Games", value: "\(result.opponent.totalGames)")
            }

            Button {
                let readiness = max(50, viewModel.profile.metrics.readinessScore)
                onMatchFound(result.opponent, readiness)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Accept & play")
                }
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Theme.brandCyan)
                .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button {
                pendingCalibrateOpponent = result.opponent
                showNeuralScan = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                    Text("Scan & calibrate")
                }
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(Theme.brandCyan)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Theme.brandCyan.opacity(0.1))
                .clipShape(.rect(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("Find another")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .sensoryFeedback(.success, trigger: true)
    }

    private var failedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No opponents found")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("Try a different tier or check back later")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("Try again")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .frame(minHeight: 44)
                    .background(Theme.brandBlue)
                    .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var bottomControls: some View {
        Button {
            dismiss()
        } label: {
            Text("Back to arena")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 20)
    }

    private var recentMatchesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.globalLeaderboard.recentMatches) { record in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(record.didWin ? Theme.brandCyan.opacity(0.15) : Color.red.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: record.didWin ? "trophy.fill" : "flag.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(record.didWin ? Theme.brandCyan : .red)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("vs \(record.opponentName)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)

                                Text("\(record.userScore) — \(record.opponentScore)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(record.opponentTier.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(tierColor(record.opponentTier))

                                Text(record.date, style: .relative)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Theme.deepBlack)
            .navigationTitle("Match History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showRecentMatches = false }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.deepBlack)
    }

    private func matchQualityBadge(_ quality: MatchQuality) -> some View {
        let color: Color = switch quality {
        case .perfect: Theme.brandCyan
        case .good: Theme.brandBlue
        case .fair: .orange
        }

        return Text(quality.rawValue)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func tierColor(_ tier: PRQTier) -> Color {
        switch tier {
        case .diamond: Theme.brandCyan
        case .platinum: Color(white: 0.85)
        case .gold: .yellow
        case .silver: Color(white: 0.7)
        case .bronze: Color(red: 0.8, green: 0.5, blue: 0.2)
        case .unranked: .gray
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }
}
