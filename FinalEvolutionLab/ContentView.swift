import SwiftUI

struct ContentView: View {
    @State private var viewModel: LabViewModel
    @State private var selectedTab: AppTab = .lab
    @State private var simpleMode: Bool = UserDefaults.standard.bool(forKey: "simpleMode")
    @State private var showSettings: Bool = false
    @State private var showOnboarding: Bool
    @State private var agentLaunchMode: GameMode?
    @State private var agentLaunchReadiness: Double = 75
    @State private var showAgentLaunchedGame = false
    @State private var showNexusStudio = false
    @State private var router = NexusDeepLinkRouter.shared
    @ObservedObject private var shareCoordinator = SocialShareCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = LabViewModel()
        _viewModel = State(initialValue: model)
        #if targetEnvironment(simulator)
        _showOnboarding = State(initialValue: false)
        _selectedTab = State(initialValue: .social)
        #else
        _showOnboarding = State(initialValue: !model.profile.hasCompletedOnboarding)
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Play", systemImage: "gamecontroller.fill", value: .social) {
                NavigationStack {
                    ArenaHubView(viewModel: viewModel)
                        .accessibilityIdentifier("ArenaHubRoot")
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                brandHeader
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                shardsBadge
                            }
                        }
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
            }

            Tab("Lab", systemImage: "brain.head.profile.fill", value: .lab) {
                NavigationStack {
                    LabView(viewModel: viewModel)
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                brandHeader
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                HStack(spacing: 8) {
                                    settingsButton
                                    shardsBadge
                                }
                            }
                        }
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
            }

            Tab("Vault", systemImage: "lock.shield.fill", value: .vault) {
                NavigationStack {
                    VaultView(viewModel: viewModel)
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                brandHeader
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                settingsButton
                            }
                        }
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
            }

            Tab("Status", systemImage: "gauge.with.dots.needle.67percent", value: .dashboard) {
                NavigationStack {
                    DashboardView(viewModel: viewModel)
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                brandHeader
                            }
                        }
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if FirebaseBootstrap.shouldShowOfflineBanner {
                FELPreviewLabel(text: FELPremiumCopy.Preview.firebaseOfflineNoKey)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.85))
            }
        }
        .accessibilityIdentifier("MainTabBar")
        .tint(Theme.brandBlue)
        .preferredColorScheme(.dark)
        .environment(\.simpleMode, simpleMode)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(simpleMode: $simpleMode, viewModel: viewModel)
        }
        .sheet(item: $shareCoordinator.composerDraft) { draft in
            SocialPostComposerSheet(draft: draft)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { sport, age, goal in
                viewModel.completeOnboarding(sport: sport, age: age, goal: goal)
                showOnboarding = false
            }
        }
        .sheet(item: $router.activeCardLink) { card in
            NexusDeepLinkCardDetailView(card: card, viewModel: viewModel)
        }
        .sheet(item: $router.activeSafariURL) { identifiableURL in
            SafariView(url: identifiableURL.url)
        }
        .sheet(isPresented: $router.activeScanLink) {
            SystemScanView(
                sport: router.prefilledSport ?? viewModel.profile.sport,
                goal: router.prefilledGoal ?? viewModel.profile.goal
            ) { result in
                viewModel.applyScanResult(result)
            }
        }
        .onAppear {
            GameplaySessionReceiptCoordinator.shared.attach(viewModel)
            Task {
                await SessionReceiptUploadService.uploadPendingReceipts()
            }
            #if targetEnvironment(simulator)
            if !viewModel.profile.hasCompletedOnboarding {
                viewModel.completeOnboarding(sport: "Basketball", age: 18, goal: "Jump Higher")
            }
            #endif
            if Config.isUITestMode {
                selectedTab = .social
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await SessionReceiptUploadService.uploadPendingReceipts()
            }
        }
        .onChange(of: NEXUSAgentCoordinator.shared.pendingLaunch?.modeId) { _, modeId in
            guard let modeId,
                  let parsed = GameModeId(rawValue: modeId),
                  let mode = GameModeRegistry.all.first(where: { $0.id == parsed })
            else { return }

            agentLaunchMode = mode
            agentLaunchReadiness = NEXUSAgentCoordinator.shared.pendingLaunchReadiness
            NEXUSAgentCoordinator.shared.pendingLaunch = nil
            selectedTab = .social
            showAgentLaunchedGame = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .nexusAgentLaunchMode)) { notification in
            guard let modeId = notification.userInfo?["mode_id"] as? String,
                  let parsed = GameModeId(rawValue: modeId),
                  let mode = GameModeRegistry.all.first(where: { $0.id == parsed })
            else { return }

            agentLaunchMode = mode
            agentLaunchReadiness = (notification.userInfo?["readiness"] as? Double)
                ?? (notification.userInfo?["readiness"] as? NSNumber)?.doubleValue
                ?? 75
            selectedTab = .social
            showAgentLaunchedGame = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .nexusStudioOpen)) { _ in
            showNexusStudio = true
        }
        .fullScreenCover(isPresented: $showNexusStudio) {
            NavigationStack {
                NexusStudioIDEView()
            }
        }
        .fullScreenCover(isPresented: $showAgentLaunchedGame) {
            if let mode = agentLaunchMode {
                NavigationStack {
                    if mode.id.isIRLDunkContest {
                        DunkMatchmakingView(viewModel: viewModel)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("Close") { showAgentLaunchedGame = false }
                                }
                            }
                    } else {
                        GamePlayView(
                            viewModel: viewModel,
                            gameMode: mode,
                            sessionReadiness: agentLaunchReadiness
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { showAgentLaunchedGame = false }
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            FELOverlayView()
                .padding(.top, 50)
        }
        .overlay {
            FelToastOverlay()
        }
        .onOpenURL { url in
            _ = router.handle(url: url)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.brandBlue)

            Text("FINAL EVOLUTION")
                .font(.system(size: 13, weight: .black))
                .italic()
                .tracking(-0.3)
                .foregroundStyle(.white)

            connectionStatusDot
        }
    }

    @ViewBuilder
    private var connectionStatusDot: some View {
        if NexusAIStudioBootstrap.isConfigured {
            FELConnectionDot(
                color: Theme.neonGreen,
                accessibilityLabel: "AI Studio connected"
            )
        } else if FirebaseBootstrap.connectionStatus == .live {
            FELConnectionDot(
                color: Theme.brandCyan,
                accessibilityLabel: "Firebase live"
            )
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
    }

    private var shardsBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.brandCyan)
            Text("\(viewModel.profile.evolutionShards)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}

nonisolated enum AppTab: String, Sendable {
    case lab
    case training
    case dashboard
    case social
    case agent
    case vault
}
