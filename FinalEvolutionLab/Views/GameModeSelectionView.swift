import SwiftUI

struct GameModeSelectionView: View {
    let viewModel: LabViewModel
    @State private var appeared = false
    @State private var selectedMode: GameMode?
    @State private var showNeuralScan = false
    @State private var pendingMode: GameMode?
    @State private var sessionReadiness: Double = 50
    @State private var gameplayRoute: GameModeId?
    /// Bumped on every push so EXIT → relaunch recreates ``GamePlayView`` even for the same mode.
    @State private var gameplayLaunchId = UUID()
    @State private var showMatchmaking = false
    @State private var showComingSoonSheet = false
    @State private var comingSoonModeName = ""
    @State private var showKarateCoopLobby = false
    @State private var karateCoopPlayerCount = 1
    @State private var showDunkPlatform = false
    @State private var showTriumphLobby = false
    /// Presents the Venice Ball Shop creator-economy storefront.
    @State private var showCreatorShop = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FELSpacing.xxl) {
                headerSection
                creatorShopBanner
                nexusSprintBanner
                globalMatchmakingBanner
                triumphCashTournamentBanner

                ForEach(GameModeRegistry.sportCategories, id: \.rawValue) { category in
                    sportSection(category)
                }
            }
            .padding(.horizontal, FELSpacing.md)
            .padding(.bottom, FELSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .navigationDestination(isPresented: $showCreatorShop) {
            ShopModeView(viewModel: viewModel)
        }
        .navigationDestination(item: $gameplayRoute) { modeId in
            if modeId == .brainBrawl {
                // Pure SwiftUI Kahoot-style quiz — no GamePlayView/SceneKit shell.
                BrainBrawlView(
                    viewModel: viewModel,
                    gameMode: GameModeRegistry.mode(for: .brainBrawl),
                    onExit: { gameplayRoute = nil }
                )
                .id(gameplayLaunchId)
            } else if let mode = GameModeRegistry.all.first(where: { $0.id == modeId }) {
                GamePlayView(
                    viewModel: viewModel,
                    gameMode: mode,
                    sessionReadiness: sessionReadiness
                )
                .id(gameplayLaunchId)
            }
        }
        .fullScreenCover(isPresented: $showNeuralScan) {
            NeuralReadinessScanView { readiness in
                sessionReadiness = readiness
                viewModel.profile.metrics.neuralDrive = min(100, readiness)
                SaveSystem.saveProfile(viewModel.profile)
                showNeuralScan = false
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    await launchNexusGameplay()
                }
            }
        }
        .sheet(isPresented: $showMatchmaking) {
            if let mode = pendingMode {
                MatchmakingView(viewModel: viewModel, gameMode: mode) { opponent, readiness in
                    sessionReadiness = readiness
                    showMatchmaking = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await launchNexusGameplay()
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
        }
        .sheet(isPresented: $showComingSoonSheet) {
            ComingSoonModeSheet(modeName: comingSoonModeName) {
                showComingSoonSheet = false
            }
        }
        .sheet(isPresented: $showKarateCoopLobby) {
            KarateCoopLobbySheet(playerCount: $karateCoopPlayerCount) {
                showKarateCoopLobby = false
                Task { @MainActor in
                    await launchSelectedMode()
                }
            }
        }
        .fullScreenCover(isPresented: $showDunkPlatform) {
            NavigationStack {
                DunkMatchmakingView(viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $showTriumphLobby) {
            TriumphTournamentLobbyView(viewModel: viewModel)
        }
    }

    /// Prominent entry into the Venice Ball Shop creator-economy storefront.
    private var creatorShopBanner: some View {
        Button {
            FELHaptics.modeSelect()
            showCreatorShop = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.brandCyan, Theme.elitePurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("SHOP")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)
                    Text("Creator Store")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                    Text("Cards, critiques & the creator economy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.4), Theme.elitePurple.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("CreatorShopBanner")
        .accessibilityLabel("Creator Store shop")
        .accessibilityHint("Opens the Venice Ball Shop creator economy storefront")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var nexusSprintBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                Text(FELPremiumCopy.Emulator.featuredModes)
                    .font(.system(.caption2, design: .monospaced, weight: .black))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                Spacer()
                Text("\(GameModeRegistry.nexusSprintModes.count) \(FELPremiumCopy.Emulator.modesAvailable.lowercased())")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GameModeRegistry.nexusSprintModes) { mode in
                        Button {
                            FELHaptics.modeSelect()
                            SaveSystem.saveLastSelectedArenaModeId(mode.id.rawValue)
                            pendingMode = mode
                            Task { @MainActor in
                                await launchSelectedMode()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.nexusSprintPriorityLabel)
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(mode.accentColor)
                                Text(mode.name)
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .frame(width: 108, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(mode.accentColor.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(mode.accentColor.opacity(0.35), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("NexusSprintMode_\(mode.id.rawValue)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("\(mode.name), \(mode.nexusSprintPriorityLabel.lowercased()) priority")
                        .accessibilityHint("Double tap to launch \(mode.name)")
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SELECT MODE")
                .font(FELTypography.overline())
                .foregroundStyle(Theme.brandBlue)
                .tracking(4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            Text("Arena")
                .font(FELTypography.display())
                .italic()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

            HStack(spacing: 8) {
                FELPreviewLabel(text: FELPremiumCopy.Preview.arena)

                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.brandCyan)
                    Text("\(GameModeRegistry.nexusSprintModes.count)")
                        .font(.system(.caption, design: .monospaced, weight: .black))
                        .foregroundStyle(Theme.brandCyan)
                    Text(FELPremiumCopy.Emulator.modesAvailable)
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Circle()
                    .fill(.tertiary)
                    .frame(width: 3, height: 3)

                HStack(spacing: 4) {
                    Text("\(GameModeRegistry.catalogModes.count)")
                        .font(.system(.caption, design: .monospaced, weight: .black))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("MODES")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var globalMatchmakingBanner: some View {
        Button {
            guard let mode = GameModeRegistry.resolvedLastSelectedMode() else { return }
            pendingMode = mode
            showMatchmaking = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .symbolEffect(.pulse)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("GLOBAL ARENA")
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.white)

                    if let last = GameModeRegistry.resolvedLastSelectedMode() {
                        Text("Matchmaking · \(last.name)")
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(Theme.brandCyan.opacity(0.7))
                    } else {
                        Text("Pick any mode card below first")
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(.orange.opacity(0.85))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.brandCyan)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.brandCyan.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(GameModeRegistry.resolvedLastSelectedMode() == nil)
        .opacity(GameModeRegistry.resolvedLastSelectedMode() == nil ? 0.55 : 1)
    }

    private var triumphCashTournamentBanner: some View {
        Button {
            showTriumphLobby = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("COMPETITIVE CASH ARENA")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.white)
                        FELPreviewLabel(text: "CASH")
                    }

                    Text("Wager real cash on Head-to-Head matches")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(Theme.brandCyan.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.brandCyan)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.4), Theme.elitePurple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func sportSection(_ category: GameMode.SportCategory) -> some View {
        let modes = GameModeRegistry.modes(for: category)
        let index = GameModeRegistry.sportCategories.firstIndex(of: category) ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(modes.first?.accentColor.opacity(0.3) ?? Theme.brandBlue.opacity(0.3))
                    .frame(width: 6, height: 6)

                Text(category.rawValue.uppercased())
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(3)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(modes.enumerated()), id: \.element.id) { modeIndex, mode in
                    GameModeCard(mode: mode) {
                        guard mode.isLaunchableInCurrentBuild else {
                            comingSoonModeName = mode.name
                            showComingSoonSheet = true
                            return
                        }
                        FELHaptics.modeSelect()
                        SaveSystem.saveLastSelectedArenaModeId(mode.id.rawValue)
                        pendingMode = mode
                        if mode.id.isIRLDunkContest {
                            showDunkPlatform = true
                        } else if mode.id == .karateEndless {
                            showKarateCoopLobby = true
                        } else {
                            Task { @MainActor in
                                await launchSelectedMode()
                            }
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.5).delay(Double(index) * 0.1 + Double(modeIndex) * 0.06),
                        value: appeared
                    )
                }
            }
        }
    }

    @MainActor
    private func launchSelectedMode() async {
        guard let mode = pendingMode else { return }
        sessionReadiness = viewModel.effectiveMetrics.neuralDrive
        await pushGameplayRoute(mode.id)
    }

    /// NEXUS-only launch — SceneKit + ``NexusGameplayEngine`` in ``GamePlayView`` (UE embed archived).
    @MainActor
    private func launchNexusGameplay() async {
        guard let mode = pendingMode else { return }
        await pushGameplayRoute(mode.id)
    }

    /// Clears ``navigationDestination`` before re-push so EXIT → same mode re-entry works (SwiftUI item routing).
    @MainActor
    private func pushGameplayRoute(_ modeId: GameModeId) async {
        if gameplayRoute == modeId {
            gameplayRoute = nil
            try? await Task.sleep(for: .milliseconds(50))
        }
        gameplayLaunchId = UUID()
        gameplayRoute = modeId
    }
}

struct GameModeCard: View {
    let mode: GameMode
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var shimmer = false

    var body: some View {
        // Premium card: icon, name, one metadata line. Flat surface, hairline
        // stroke that turns accent on press — no gradient layers, no glow.
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
                HStack {
                    Image(systemName: mode.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(mode.accentColor)
                        .frame(width: 40, height: 40)
                        .background(FELDesign.Colors.surfaceRaised)
                        .clipShape(Circle())

                    Spacer()

                    multiplayerBadge
                }

                Text(mode.name.uppercased())
                    .font(FELDesign.Typography.label)
                    .tracking(0.4)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                    .lineLimit(1)

                Text(mode.environmentName)
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
                    .lineLimit(1)
            }
            .padding(FELDesign.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FELDesign.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                    .stroke(
                        isPressed ? mode.accentColor : FELDesign.Colors.hairline,
                        lineWidth: FELDesign.Stroke.hairline
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1)
            .opacity(mode.isLaunchableInCurrentBuild ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
        .accessibilityLabel(modeAccessibilityLabel)
        .accessibilityHint(mode.isLaunchableInCurrentBuild ? "Double tap to play \(mode.name)" : "Preview mode — not available in this build")
        .accessibilityAddTraits(mode.isLaunchableInCurrentBuild ? .isButton : .isStaticText)
        .accessibilityIdentifier("GameModeCard_\(mode.id.rawValue)")
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isPressed = pressing }
        }, perform: {})
    }

    private var modeAccessibilityLabel: String {
        var parts = [mode.name, mode.subtitle, mode.environmentName, mode.nexusCapabilityTier.rawValue.uppercased()]
        if !mode.isLaunchableInCurrentBuild {
            parts.append("Not available in this build")
        }
        return parts.joined(separator: ", ")
    }

    private var nexusTierBadge: some View {
        let (label, color): (String, Color) = {
            switch mode.nexusCapabilityTier {
            case .prod:
                if Config.appRuntimeEnvironment == .staging { return ("STAGING", Theme.brandCyan) }
                return ("PROD", Theme.neonGreen)
            case .sim:
                return ("SIM", Theme.brandCyan)
            case .staging:
                return ("STAGING", .orange)
            case .preview:
                return ("PREVIEW", .orange)
            case .nonGame:
                return ("MODULE", Color.gray)
            }
        }()

        return Text(label)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var comingSoonBadge: some View {
        Text("SOON")
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.12))
            .clipShape(Capsule())
    }

    private var multiplayerBadge: some View {
        Group {
            switch mode.multiplayerType {
            case .realtime:
                let rules = GameModeRules.forMode(mode.id)
                HStack(spacing: 3) {
                    Image(systemName: rules.useMatchCountdown ? "timer" : "person.fill")
                        .font(.system(size: 7))
                    Text(rules.useMatchCountdown ? "TIMED" : "LOCAL")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(rules.useMatchCountdown ? Theme.brandCyan : Color.white.opacity(0.65))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((rules.useMatchCountdown ? Theme.brandCyan : Color.white).opacity(0.1))
                .clipShape(Capsule())
            case .turnBased:
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 7))
                    Text("TURNS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            case .solo:
                EmptyView()
            case .localCoop:
                HStack(spacing: 3) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 7))
                    Text("LOCAL CO-OP")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }
}

extension GameMode: Hashable {
    nonisolated static func == (lhs: GameMode, rhs: GameMode) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct KarateCoopLobbySheet: View {
    @Binding var playerCount: Int
    let onLaunch: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("DOJO BREACH")
                    .font(.system(.title3, design: .monospaced, weight: .black))
                    .foregroundStyle(.orange)

                Text("LOCAL CO-OP · 1–4 PLAYERS")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("Shared-screen wave survival. More fighters scale breach intensity. Online multiplayer is not implemented in this build.")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)

                Picker("Fighters", selection: $playerCount) {
                    ForEach(1...4, id: \.self) { count in
                        Text("\(count) fighter\(count == 1 ? "" : "s")").tag(count)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                Button(action: onLaunch) {
                    Text("ENTER DOJO")
                        .font(.system(.headline, design: .monospaced, weight: .black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.deepBlack)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct ComingSoonModeSheet: View {
    let modeName: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "hourglass")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.top, 24)

                Text("\(modeName) ships post-sprint.")
                    .font(.system(.headline, weight: .black))
                    .multilineTextAlignment(.center)

                Text("Play Dunk Contest, Karate Endless, H2H, or Court Carnival today.")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.deepBlack)
            .navigationTitle("Coming Soon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
