import SwiftUI

/// Premium console-style cartridge library — primary Arena Modes experience when emulator shell is on.
struct ArcadeLibraryView: View {
    let viewModel: LabViewModel

    @State private var appeared = false
    @State private var showBoot = {
        !ArcadeLibraryPreferences.skipBootSequence
            && !Config.isUITestMode
    }()
    @State private var searchText = ""
    @State private var selectedGenre: ArcadeCartridgeGenre = .all
    @State private var selectedMode: GameMode?
    @State private var pendingMode: GameMode?
    @State private var showNeuralScan = false
    @State private var sessionReadiness: Double = 50
    @State private var gameplayRoute: GameModeId?
    @State private var gameplayLaunchId = UUID()
    @State private var showMatchmaking = false
    @State private var showComingSoonSheet = false
    @State private var comingSoonModeName = ""
    @State private var showKarateCoopLobby = false
    @State private var showDunkPlatform = false
    @State private var karateCoopPlayerCount = 1
    @State private var showTriumphLobby = false

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
    ]

    private var catalogModes: [GameMode] {
        GameModeRegistry.shippingModes.filter { GameModeRegistry.arenaRegistryModeIds.contains($0.id) }
    }

    private var filteredModes: [GameMode] {
        catalogModes.filter { mode in
            let meta = ArcadeCartridgeMetadata.metadata(for: mode)
            let genreMatch = selectedGenre == .all || meta.genre == selectedGenre
            guard genreMatch else { return false }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return true }
            return meta.classicTitle.lowercased().contains(query)
                || mode.name.lowercased().contains(query)
                || mode.subtitle.lowercased().contains(query)
                || meta.systemBadge.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            ArcadeEmulatorChrome {
                libraryContent
            }

            if showBoot {
                NexusSystemBootView {
                    withAnimation(.easeOut(duration: 0.22)) {
                        showBoot = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .background(Theme.deepBlack)
        .navigationDestination(item: $gameplayRoute) { modeId in
            if modeId == .brainBrawl {
                BrainBrawl2DView(
                    viewModel: viewModel,
                    gameMode: GameModeRegistry.mode(for: .brainBrawl),
                    onDismiss: { gameplayRoute = nil }
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
                MatchmakingView(viewModel: viewModel, gameMode: mode) { _, readiness in
                    sessionReadiness = readiness
                    showMatchmaking = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await launchNexusGameplay()
                    }
                }
            }
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
        .onAppear {
            if Config.isUITestMode {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { appeared = true }
            }
        }
    }

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FELSpacing.xl + 4) {
                headerSection
                nexusSprintBanner
                triumphCashTournamentBanner
                premiumSearchBar
                genreFilterRow
                pinnedCartridgeRow
                cartridgeGrid
            }
            .padding(.horizontal, FELSpacing.lg)
            .padding(.bottom, FELSpacing.xxl + 8)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("ArcadeLibraryRoot")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Library")
                .font(FELTypography.title(34))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            Text("\(filteredModes.count) games")
                .font(FELTypography.caption(13))
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1 : 0)
        }
        .padding(.top, 12)
    }

    /// Smoke / accessibility parity with ``GameModeSelectionView`` sprint strip.
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
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GameModeRegistry.nexusSprintModes) { mode in
                        Button {
                            selectCartridge(mode)
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
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var premiumSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search games", text: $searchText)
                .font(FELTypography.body(16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.14),
                                    Color.white.opacity(0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .accessibilityIdentifier("ArcadeLibrarySearch")
    }

    private var genreFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ArcadeCartridgeGenre.allCases) { genre in
                    Button {
                        FELHaptics.modeSelect()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedGenre = genre
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: genre.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(genre.filterLabel)
                                .font(FELTypography.caption(13))
                        }
                        .foregroundStyle(selectedGenre == genre ? .black : .white.opacity(0.88))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    selectedGenre == genre
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [genre.accentColor, genre.accentColor.opacity(0.82)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        : AnyShapeStyle(Color.white.opacity(0.07))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(
                                            selectedGenre == genre
                                                ? Color.clear
                                                : Color.white.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ArcadeGenreFilter_\(genre.rawValue)")
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var pinnedCartridgeRow: some View {
        let favoriteIds = Set(ArcadeLibraryPreferences.loadFavorites())
        let pinnedIds = ArcadeLibraryPreferences.pinnedCartridges()
        let pinnedModes = pinnedIds.compactMap { id in catalogModes.first(where: { $0.id == id }) }

        if !pinnedModes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.brandCyan.opacity(0.85))
                    Text("Recent & Favorites")
                        .font(FELTypography.headline(15))
                        .foregroundStyle(.white.opacity(0.92))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(pinnedModes) { mode in
                            Button {
                                selectCartridge(mode)
                            } label: {
                                ArcadePinnedCartridgeTile(
                                    mode: mode,
                                    isFavorite: favoriteIds.contains(mode.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("ArcadePinned_\(mode.id.rawValue)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var cartridgeGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(Array(filteredModes.enumerated()), id: \.element.id) { index, mode in
                ArcadeCartridgeCard(
                    mode: mode,
                    isFavorite: ArcadeLibraryPreferences.isFavorite(mode.id),
                    onToggleFavorite: {
                        ArcadeLibraryPreferences.toggleFavorite(mode.id)
                    },
                    onLaunch: {
                        selectCartridge(mode)
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .animation(
                    .spring(response: 0.52, dampingFraction: 0.84).delay(Double(index) * 0.035),
                    value: appeared
                )
            }
        }
    }

    private func selectCartridge(_ mode: GameMode) {
        guard mode.isLaunchableInCurrentBuild else {
            comingSoonModeName = ArcadeCartridgeMetadata.metadata(for: mode).classicTitle
            showComingSoonSheet = true
            return
        }
        FELHaptics.modeSelect()
        ArcadeLibraryPreferences.recordCartridgeLaunch(mode.id)
        pendingMode = mode
        if mode.id.isIRLDunkContest {
            showDunkPlatform = true
        } else if mode.id == .karateEndless, !Config.isUITestMode {
            showKarateCoopLobby = true
        } else {
            Task { @MainActor in
                await launchSelectedMode()
            }
        }
    }

    @MainActor
    private func launchSelectedMode() async {
        guard let mode = pendingMode else { return }
        sessionReadiness = viewModel.effectiveMetrics.neuralDrive
        await pushGameplayRoute(mode.id)
    }

    @MainActor
    private func launchNexusGameplay() async {
        guard let mode = pendingMode else { return }
        await pushGameplayRoute(mode.id)
    }

    @MainActor
    private func pushGameplayRoute(_ modeId: GameModeId) async {
        if modeId.isIRLDunkContest {
            gameplayRoute = nil
            gameplayLaunchId = UUID()
            showDunkPlatform = true
            return
        }
        if gameplayRoute == modeId {
            gameplayRoute = nil
            try? await Task.sleep(for: .milliseconds(50))
        }
        gameplayLaunchId = UUID()
        gameplayRoute = modeId
    }

    @MainActor
    private func switchCartridgeDuringPlay(to modeId: GameModeId) async {
        pendingMode = GameModeRegistry.mode(for: modeId)
        ArcadeLibraryPreferences.recordCartridgeLaunch(modeId)
        gameplayRoute = nil
        try? await Task.sleep(for: .milliseconds(80))
        await pushGameplayRoute(modeId)
    }
}

// MARK: - Cartridge tiles

struct ArcadeGenreBadge: View {
    let genre: ArcadeCartridgeGenre

    var body: some View {
        Text(genre.systemBadge)
            .font(FELTypography.caption(10))
            .fontWeight(.semibold)
            .foregroundStyle(genre.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(genre.accentColor.opacity(0.14))
            )
    }
}

struct ArcadeCartridgeCard: View {
    let mode: GameMode
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onLaunch: () -> Void

    @State private var isPressed = false

    private var meta: ArcadeCartridgeMetadata {
        ArcadeCartridgeMetadata.metadata(for: mode)
    }

    var body: some View {
        Button(action: onLaunch) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    mode.accentColor.opacity(0.42),
                                    mode.accentColor.opacity(0.12),
                                    Theme.deepBlack.opacity(0.55),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 112)
                        .overlay {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white.opacity(0.95), mode.accentColor],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: mode.accentColor.opacity(0.45), radius: 10, y: 4)
                        }

                    HStack {
                        ArcadeGenreBadge(genre: meta.genre)
                        Spacer()
                        if meta.isClassicProduction {
                            Text("Classic")
                                .font(FELTypography.caption(9))
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.neonGreen)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Theme.neonGreen.opacity(0.12))
                                )
                        }
                    }
                    .padding(12)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text(meta.classicTitle)
                        .font(FELTypography.headline(15))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .multilineTextAlignment(.leading)

                    Text(meta.tagline)
                        .font(FELTypography.caption(11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(meta.yearStamp)
                            .font(FELTypography.caption(10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button(action: onToggleFavorite) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(isFavorite ? 0.1 : 0.05))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorite ? "Remove favorite" : "Add favorite")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.cardBackground,
                                Theme.slateCard.opacity(0.95),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        mode.accentColor.opacity(isPressed ? 0.38 : 0.18),
                                        Color.white.opacity(0.06),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.22), radius: isPressed ? 6 : 14, y: isPressed ? 2 : 8)
            .scaleEffect(isPressed ? 0.975 : 1)
            .opacity(mode.isLaunchableInCurrentBuild ? 1 : 0.52)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("GameModeCard_\(mode.id.rawValue)")
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(meta.classicTitle), \(meta.systemBadge)")
        .accessibilityHint(mode.isLaunchableInCurrentBuild ? "Double tap to play" : "Not available in this build")
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) { isPressed = pressing }
        }, perform: {})
    }
}

private struct ArcadePinnedCartridgeTile: View {
    let mode: GameMode
    let isFavorite: Bool

    private var meta: ArcadeCartridgeMetadata {
        ArcadeCartridgeMetadata.metadata(for: mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                mode.accentColor.opacity(0.38),
                                mode.accentColor.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 148, height: 88)
                    .overlay {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ArcadeGenreBadge(genre: meta.genre)
                Text(meta.classicTitle)
                    .font(FELTypography.headline(13))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(width: 148, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}

/// In-game quick-switch drawer — compact cartridge picker overlay.
struct ArcadeCartridgeSwitcherOverlay: View {
    let modes: [GameMode]
    let onSelect: (GameMode) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedGenre: ArcadeCartridgeGenre = .all

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    private var filteredModes: [GameMode] {
        modes.filter { mode in
            let meta = ArcadeCartridgeMetadata.metadata(for: mode)
            let genreMatch = selectedGenre == .all || meta.genre == selectedGenre
            guard genreMatch else { return false }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return true }
            return meta.classicTitle.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Switch Game")
                            .font(FELTypography.headline(17))
                            .foregroundStyle(.white)
                        Text("Session stays loaded")
                            .font(FELTypography.caption(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel", action: onDismiss)
                        .font(FELTypography.headline(15))
                        .foregroundStyle(Theme.brandBlue)
                        .accessibilityIdentifier("ArcadeCartridgeSwitcherCancel")
                }
                .padding(.horizontal, 4)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredModes) { mode in
                            ArcadeCartridgeCard(
                                mode: mode,
                                isFavorite: ArcadeLibraryPreferences.isFavorite(mode.id),
                                onToggleFavorite: {
                                    ArcadeLibraryPreferences.toggleFavorite(mode.id)
                                },
                                onLaunch: {
                                    guard mode.isLaunchableInCurrentBuild else { return }
                                    onSelect(mode)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 420)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.deepBlack, Theme.slateBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
        }
        .accessibilityIdentifier("ArcadeCartridgeSwitcher")
    }
}

// Shared sheets — same copy as GameModeSelectionView private types.
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
                Picker("Fighters", selection: $playerCount) {
                    ForEach(1...4, id: \.self) { count in
                        Text("\(count) fighter\(count == 1 ? "" : "s")").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
                Button(action: onLaunch) {
                    Text(FELPremiumCopy.Emulator.startGame)
                        .font(.system(.headline, design: .monospaced, weight: .black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("ArcadeInsertCartridgeButton")
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.deepBlack)
        }
        .presentationDetents([.medium])
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
                Text("\(modeName) is not in the slot yet.")
                    .font(.system(.headline, weight: .black))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .background(Theme.deepBlack)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
