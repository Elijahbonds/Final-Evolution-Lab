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
            FELDesign.Colors.ink.ignoresSafeArea()

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

    private var connectionColor: Color {
        viewModel.globalLeaderboard.connectionQuality == .good
            ? FELDesign.Colors.success
            : FELDesign.Colors.danger
    }

    private var header: some View {
        VStack(spacing: FELDesign.Space.xs) {
            FELPreviewLabel(text: FELPremiumCopy.Preview.matchmakingStub)

            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "globe")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.cyan)
                    .symbolEffect(.pulse, isActive: searchingPhase)

                FELMicroLabel(text: "Global Matchmaking", color: FELDesign.Colors.cyan)
            }

            Text(gameMode.name.uppercased())
                .font(FELDesign.Typography.heading)
                .foregroundStyle(FELDesign.Colors.textPrimary)

            HStack(spacing: FELDesign.Space.md) {
                HStack(spacing: FELDesign.Space.xxs) {
                    Circle()
                        .fill(FELDesign.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("\(viewModel.globalLeaderboard.onlinePlayerCount) ONLINE")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                }

                HStack(spacing: FELDesign.Space.xxs) {
                    Image(systemName: viewModel.globalLeaderboard.connectionQuality.icon)
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(connectionColor)
                    Text(viewModel.globalLeaderboard.connectionQuality.rawValue)
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                }

                if !viewModel.globalLeaderboard.recentMatches.isEmpty {
                    Button {
                        showRecentMatches = true
                    } label: {
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(FELDesign.Typography.statSmall)
                            Text("HISTORY")
                                .font(FELDesign.Typography.statSmall)
                        }
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.top, FELDesign.Space.lg)
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
        VStack(spacing: FELDesign.Space.lg) {
            PRQTierBadge(tier: userTier, prq: viewModel.competitivePRQScore)

            VStack(spacing: FELDesign.Space.xs) {
                Text("FIND OPPONENT")
                    .font(FELDesign.Typography.title)
                    .foregroundStyle(FELDesign.Colors.textPrimary)

                Text("Match by PRQ tier for balanced competition")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
                FELMicroLabel(text: "Tier Filter")

                ScrollView(.horizontal) {
                    HStack(spacing: FELDesign.Space.xs) {
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
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "magnifyingglass")
                    Text("SEARCH")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(FELPrimaryButtonStyle())
            .padding(.horizontal, FELDesign.Space.xl)
        }
    }

    private func searchingState(tier: PRQTier) -> some View {
        VStack(spacing: FELDesign.Space.lg) {
            ZStack {
                ForEach(0..<4, id: \.self) { ring in
                    Circle()
                        .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
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
                    .foregroundStyle(FELDesign.Colors.cyan)
                    .symbolEffect(.variableColor.iterative, isActive: true)
            }

            VStack(spacing: FELDesign.Space.xs) {
                Text("SEARCHING…")
                    .font(FELDesign.Typography.heading)
                    .foregroundStyle(FELDesign.Colors.textPrimary)

                Text("Looking for \(tier.rawValue) opponents")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)

                Text("Scanning \(viewModel.globalLeaderboard.onlinePlayerCount) active players")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
            }

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("CANCEL")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }
        }
        .onAppear {
            withAnimation { searchingPhase = true }
        }
    }

    private func foundState(result: MatchmakingResult) -> some View {
        VStack(spacing: FELDesign.Space.lg) {
            HStack(spacing: FELDesign.Space.lg) {
                VStack(spacing: FELDesign.Space.xs) {
                    ZStack {
                        Circle()
                            .fill(FELDesign.Colors.surfaceRaised)
                            .frame(width: 64, height: 64)
                            .overlay(Circle().stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline))

                        Image(systemName: viewModel.profile.avatarSystemName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(FELDesign.Colors.cyan)
                    }

                    FELMicroLabel(text: "You")

                    Text(String(format: "%.0f", viewModel.competitivePRQScore))
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                }

                VStack(spacing: FELDesign.Space.xxs) {
                    Text("VS")
                        .font(FELDesign.Typography.heading)
                        .foregroundStyle(FELDesign.Colors.cyan)

                    matchQualityBadge(result.matchQuality)
                }

                VStack(spacing: FELDesign.Space.xs) {
                    ZStack {
                        Circle()
                            .fill(FELDesign.Colors.surfaceRaised)
                            .frame(width: 64, height: 64)
                            .overlay(Circle().stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline))

                        Image(systemName: result.opponent.avatarSystemName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                    }

                    FELMicroLabel(text: String(result.opponent.displayName.prefix(8)))

                    Text(String(format: "%.0f", result.opponent.prqScore))
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                }
            }

            HStack(spacing: FELDesign.Space.sm) {
                StatPill(label: "TIER", value: result.opponent.tier.rawValue)
                StatPill(label: "WIN RATE", value: String(format: "%.0f%%", result.opponent.winRate * 100))
                StatPill(label: "GAMES", value: "\(result.opponent.totalGames)")
            }

            Button {
                matchPendingReadiness = result
                showNeuralScan = true
            } label: {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "bolt.fill")
                    Text("ACCEPT & CALIBRATE")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(FELPrimaryButtonStyle())
            .padding(.horizontal, FELDesign.Space.xl)

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("FIND ANOTHER")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }
        }
        .sensoryFeedback(.success, trigger: true)
    }

    private var failedState: some View {
        VStack(spacing: FELDesign.Space.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(FELDesign.Colors.textSecondary)

            Text("NO OPPONENTS FOUND")
                .font(FELDesign.Typography.heading)
                .foregroundStyle(FELDesign.Colors.textPrimary)

            Text("Try a different tier or check back later")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textSecondary)

            Button {
                viewModel.globalLeaderboard.cancelMatchmaking()
            } label: {
                Text("TRY AGAIN")
            }
            .buttonStyle(FELPrimaryButtonStyle())
        }
    }

    private var bottomControls: some View {
        Button {
            dismiss()
        } label: {
            Text("BACK TO ARENA")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)
        }
        .padding(.bottom, FELDesign.Space.lg)
    }

    private var recentMatchesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FELDesign.Space.xs) {
                    ForEach(viewModel.globalLeaderboard.recentMatches) { record in
                        HStack(spacing: FELDesign.Space.sm) {
                            Circle()
                                .fill(FELDesign.Colors.surfaceRaised)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: record.didWin ? "trophy.fill" : "flag.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(record.didWin ? FELDesign.Colors.success : FELDesign.Colors.danger)
                                )

                            VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                                Text("vs \(record.opponentName.uppercased())")
                                    .font(FELDesign.Typography.caption)
                                    .foregroundStyle(FELDesign.Colors.textPrimary)

                                Text("\(record.userScore) — \(record.opponentScore)")
                                    .font(FELDesign.Typography.statSmall)
                                    .foregroundStyle(FELDesign.Colors.textSecondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: FELDesign.Space.xxs) {
                                FELMicroLabel(text: record.opponentTier.rawValue, color: tierColor(record.opponentTier))

                                Text(record.date, style: .relative)
                                    .font(FELDesign.Typography.statSmall)
                                    .foregroundStyle(FELDesign.Colors.textTertiary)
                            }
                        }
                        .felCard(padding: FELDesign.Space.sm)
                    }
                }
                .padding()
            }
            .background(FELDesign.Colors.ink)
            .navigationTitle("Match History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showRecentMatches = false }
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(FELDesign.Colors.ink)
    }

    private func matchQualityBadge(_ quality: MatchQuality) -> some View {
        let color: Color = switch quality {
        case .perfect: FELDesign.Colors.cyan
        case .good: FELDesign.Colors.textSecondary
        case .fair: FELDesign.Colors.textTertiary
        }

        return FELMicroLabel(text: quality.rawValue, color: color)
            .padding(.horizontal, FELDesign.Space.xs)
            .padding(.vertical, FELDesign.Space.xxs)
            .background(FELDesign.Colors.surfaceRaised)
            .clipShape(Capsule())
    }

    private func tierColor(_ tier: PRQTier) -> Color {
        switch tier {
        case .diamond: FELDesign.Colors.purple
        case .platinum, .gold: FELDesign.Colors.textPrimary
        case .silver, .bronze: FELDesign.Colors.textSecondary
        case .unranked: FELDesign.Colors.textTertiary
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: FELDesign.Space.xxs) {
            Text(value)
                .font(FELDesign.Typography.stat)
                .foregroundStyle(FELDesign.Colors.textPrimary)
            FELMicroLabel(text: label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FELDesign.Space.sm)
        .background(FELDesign.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
        )
    }
}
