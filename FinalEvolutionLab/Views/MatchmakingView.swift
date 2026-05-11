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
    @State private var sessionReadiness: Double = 0
    @State private var showRecentMatches = false
    /// When non-nil, neural scan is for accepting this match (GAME-34).
    @State private var matchPendingReadiness: MatchmakingResult?

    private var userTier: PRQTier {
        PRQTier.fromPRQ(viewModel.competitivePRQScore)
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
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRecentMatches) {
            recentMatchesSheet
        }
        .onAppear {
            viewModel.globalLeaderboard.simulateOnlinePresence()
        }
        .onDisappear {
            viewModel.globalLeaderboard.cancelMatchmaking()
            viewModel.globalLeaderboard.stopOnlinePresenceSimulation()
        }
        .fullScreenCover(isPresented: $showNeuralScan, onDismiss: {
            if matchPendingReadiness != nil {
                matchPendingReadiness = nil
            }
        }) {
            if let pending = matchPendingReadiness {
                NeuralReadinessScanView { readiness in
                    sessionReadiness = readiness
                    matchPendingReadiness = nil
                    showNeuralScan = false
                    onMatchFound(pending.opponent, readiness)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                    .symbolEffect(.pulse, isActive: searchingPhase)

                Text("GLOBAL MATCHMAKING")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(3)
            }

            Text(gameMode.name.uppercased())
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("\(viewModel.globalLeaderboard.onlinePlayerCount) ONLINE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.8))
                }

                HStack(spacing: 4) {
                    Image(systemName: viewModel.globalLeaderboard.connectionQuality.icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(viewModel.globalLeaderboard.connectionQuality == .good ? Theme.brandCyan : .orange)
                    Text(viewModel.globalLeaderboard.connectionQuality.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(viewModel.globalLeaderboard.connectionQuality == .good ? Theme.brandCyan.opacity(0.7) : .orange.opacity(0.7))
                }

                if !viewModel.globalLeaderboard.recentMatches.isEmpty {
                    Button {
                        showRecentMatches = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 9))
                            Text("HISTORY")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
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

                PRQTierBadge(tier: userTier, prq: viewModel.competitivePRQScore)
            }

            VStack(spacing: 8) {
                Text("FIND OPPONENT")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text("Match by PRQ tier for balanced competition")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("TIER FILTER")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(2)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        TierChip(label: "ANY", isSelected: selectedTier == nil) {
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
                        userPRQ: viewModel.competitivePRQScore,
                        preferredTier: selectedTier
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("SEARCH")
                }
                .font(.system(.subheadline, design: .monospaced, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
                Text("SEARCHING...")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text("Looking for \(tier.rawValue) opponents")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan.opacity(0.7))

                Text("Scanning \(viewModel.globalLeaderboard.onlinePlayerCount) active players")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("CANCEL")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
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

                    Text("YOU")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.0f", viewModel.competitivePRQScore))
                        .font(.system(.headline, design: .monospaced, weight: .black))
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

                    Text(result.opponent.displayName.prefix(8).uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.0f", result.opponent.prqScore))
                        .font(.system(.headline, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 12) {
                StatPill(label: "TIER", value: result.opponent.tier.rawValue)
                StatPill(label: "WIN RATE", value: String(format: "%.0f%%", result.opponent.winRate * 100))
                StatPill(label: "GAMES", value: "\(result.opponent.totalGames)")
            }

            Button {
                matchPendingReadiness = result
                showNeuralScan = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("ACCEPT & CALIBRATE")
                }
                .font(.system(.subheadline, design: .monospaced, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.brandCyan)
                .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("FIND ANOTHER")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
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

            Text("NO OPPONENTS FOUND")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)

            Text("Try a different tier or check back later")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("TRY AGAIN")
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Theme.brandBlue)
                    .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var bottomControls: some View {
        Button {
            dismiss()
        } label: {
            Text("BACK TO ARENA")
                .font(.system(.caption, design: .monospaced, weight: .bold))
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
                                Text("vs \(record.opponentName.uppercased())")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)

                                Text("\(record.userScore) — \(record.opponentScore)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(record.opponentTier.rawValue)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(tierColor(record.opponentTier))

                                Text(record.date, style: .relative)
                                    .font(.system(size: 8, design: .monospaced))
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
            .font(.system(size: 8, weight: .black, design: .monospaced))
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
                .font(.system(.caption, design: .monospaced, weight: .black))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }
}
