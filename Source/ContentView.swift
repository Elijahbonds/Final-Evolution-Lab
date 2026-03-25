import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = LabViewModel()
    @State private var selectedTab: AppTab = .games
    @AppStorage("simpleMode") private var simpleMode: Bool = false
    @State private var showSettings: Bool = false
    @State private var showOnboarding: Bool = false
    @AppStorage("felHasAcceptedMedicalDisclaimer") private var hasAcceptedMedicalDisclaimer = false
    @AppStorage("felHasSeenDeleteTheFearSplash") private var hasSeenDeleteTheFearSplash = false
    @AppStorage("felHasCompletedFirstLaunchSystemScan") private var hasCompletedFirstLaunchSystemScan = false
    @State private var showFirstLaunchSystemScan = false
    @State private var showEvolutionShareSheet = false
    @State private var evolutionShareImage: UIImage?
    @State private var showUnrealShardMarketplace = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Games", systemImage: "gamecontroller.fill", value: .games) {
                NavigationStack {
                    EmulatorDashboardView(selectedTab: $selectedTab, viewModel: viewModel)
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

            Tab("Lab", systemImage: "brain.head.profile.fill", value: .lab) {
                NavigationStack {
                    LabView(viewModel: viewModel, selectedTab: $selectedTab)
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

            Tab("Arena", systemImage: "sportscourt.fill", value: .arena) {
                NavigationStack {
                    ArenaView(viewModel: viewModel, selectedTab: $selectedTab)
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

            Tab("Train", systemImage: "figure.highintensity.intervaltraining", value: .training) {
                NavigationStack {
                    TrainingHubView(labViewModel: viewModel)
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

            Tab("Fuel", systemImage: "flask.fill", value: .fuel) {
                NavigationStack {
                    FuelHubView(viewModel: viewModel)
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

            Tab("Status", systemImage: "gauge.with.dots.needle.67percent", value: .dashboard) {
                NavigationStack {
                    DashboardView(viewModel: viewModel)
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

            Tab("Film", systemImage: "film.stack.fill", value: .filmVault) {
                NavigationStack {
                    FilmVaultView(viewModel: viewModel)
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

            Tab("Stream", systemImage: "dot.radiowaves.left.and.right", value: .evolutionStream) {
                NavigationStack {
                    EvolutionStreamChannelView(viewModel: viewModel)
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

            Tab("Profile", systemImage: "person.crop.circle.fill", value: .vault) {
                NavigationStack {
                    VaultView(viewModel: viewModel)
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
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await FELSupabaseWalletSync.shared.refreshAthleteProfileLink(athleteId: viewModel.profile.id)
                }
            }
        }
        .tint(Theme.brandBlue)
        .preferredColorScheme(.dark)
        .environment(\.simpleMode, simpleMode)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(simpleMode: $simpleMode, viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { sport, age, goal in
                viewModel.completeOnboarding(sport: sport, age: age, goal: goal)
                showOnboarding = false
            }
        }
        .onAppear {
            runPostDisclaimerGatesIfNeeded()
        }
        .onChange(of: hasAcceptedMedicalDisclaimer) { _, accepted in
            if accepted {
                runPostDisclaimerGatesIfNeeded()
            }
        }
        .overlay(alignment: .topTrailing) {
            if hasAcceptedMedicalDisclaimer && !showSettings && !showOnboarding && !showFirstLaunchSystemScan {
                PRQOverlayView()
                    .padding(.top, 50)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSettings)
        .animation(.easeInOut(duration: 0.2), value: showOnboarding)
        .overlay {
            if hasAcceptedMedicalDisclaimer && !hasSeenDeleteTheFearSplash {
                BondsBounceSplashView {
                    hasSeenDeleteTheFearSplash = true
                    if !hasCompletedFirstLaunchSystemScan {
                        showFirstLaunchSystemScan = true
                    } else {
                        presentOnboardingIfNeeded()
                    }
                }
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .overlay {
            if !hasAcceptedMedicalDisclaimer {
                MedicalDisclaimerView {
                    hasAcceptedMedicalDisclaimer = true
                }
                .transition(.opacity)
                .zIndex(1100)
            }
        }
        .fullScreenCover(isPresented: $showFirstLaunchSystemScan) {
            SystemScanView(
                sport: viewModel.profile.sport ?? "Basketball",
                goal: viewModel.profile.goal ?? "Jump Higher",
                profileForDemoFastTrack: viewModel.profile
            ) { result in
                viewModel.applyScanResult(result)
                if UFELCreatorInviteService.shared.applyPendingInviteOnFirstScanCompletion(profile: &viewModel.profile) {
                    SaveSystem.saveProfile(viewModel.profile)
                }
                hasCompletedFirstLaunchSystemScan = true
                showFirstLaunchSystemScan = false
                UserDefaults.standard.set(true, forKey: PRQManager.pendingTwinBirthCinematicKey)
                PRQManager.shared.sync(from: viewModel)
                FELBirthReadinessWriter.notifyTwinBirth()
                presentOnboardingIfNeeded()
            } onOpenAcademyModule: { moduleId in
                viewModel.preselectedAcademyModuleId = moduleId
                selectedTab = .games
                showFirstLaunchSystemScan = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felShareEvolutionFromUnreal)) { _ in
            evolutionShareImage = AthleteEvolutionShareRenderer.renderImage(viewModel: viewModel)
            showEvolutionShareSheet = true
        }
        .sheet(isPresented: $showEvolutionShareSheet, onDismiss: { evolutionShareImage = nil }) {
            if let evolutionShareImage {
                ActivityShareSheet(items: [evolutionShareImage])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felUnrealUINotificationFeedback)) { note in
            let k = (note.userInfo?["kind"] as? NSNumber)?.intValue ?? 0
            FELHaptics.unrealUINotificationFeedback(kind: k)
        }
        .onReceive(NotificationCenter.default.publisher(for: .felPenultimateStrideRhythm)) { note in
            let raw = (note.userInfo?["phase"] as? NSNumber)?.intValue ?? 0
            let phase = FELPenultimateStridePhase.clamped(raw)
            FELHaptics.pushPenultimateStrideClinical(phase: phase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .felCoachPerformanceSnapshot)) { note in
            if let json = note.userInfo?["json"] as? String {
                FELCoachPerformanceSnapshot.cacheFromNotification(json)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felUniversalSyncExport)) { note in
            if let b64 = note.userInfo?["base64"] as? String {
                FELUniversalSyncBridge.cacheFromNotification(b64)
            }
        }
        .sheet(isPresented: $showUnrealShardMarketplace) {
            UFELShardMarketplaceView(viewModel: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .felUnrealShardMarketplaceRequest)) { _ in
            showUnrealShardMarketplace = true
        }
    }

    private func runPostDisclaimerGatesIfNeeded() {
        guard hasAcceptedMedicalDisclaimer else { return }
        #if targetEnvironment(simulator)
        if !hasCompletedFirstLaunchSystemScan {
            hasSeenDeleteTheFearSplash = true
            hasCompletedFirstLaunchSystemScan = true
        }
        #endif
        if hasSeenDeleteTheFearSplash && !hasCompletedFirstLaunchSystemScan {
            showFirstLaunchSystemScan = true
        }
        if hasCompletedFirstLaunchSystemScan {
            presentOnboardingIfNeeded()
        }
    }

    private func presentOnboardingIfNeeded() {
        guard hasCompletedFirstLaunchSystemScan else { return }
        #if targetEnvironment(simulator)
        if !viewModel.profile.hasCompletedOnboarding {
            viewModel.completeOnboarding(sport: "Basketball", age: 18, goal: "Jump Higher")
        }
        #else
        if !viewModel.profile.hasCompletedOnboarding {
            showOnboarding = true
        }
        #endif
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
        .accessibilityLabel("Settings")
        .accessibilityHint("Opens app settings")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Evolution shards, \(viewModel.profile.evolutionShards)")
    }
}

nonisolated enum AppTab: String, Sendable {
    case games
    case lab
    case arena
    case training
    case fuel
    case dashboard
    case filmVault
    case evolutionStream
    case vault
}
