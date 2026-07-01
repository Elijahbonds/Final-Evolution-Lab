import SwiftUI

struct ContentView: View {
    @State private var viewModel = LabViewModel()
    @State private var selectedTab: AppTab = .lab
    @State private var simpleMode: Bool = UserDefaults.standard.bool(forKey: "simpleMode")
    @State private var showSettings: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var showSceneEditor: Bool = false
    @State private var editorScene: NexusScene = NexusScene.default(for: .basketballHeadToHead, prq: 75)
    @ObservedObject private var shareCoordinator = SocialShareCoordinator.shared

    var body: some View {
        TabView(selection: $selectedTab) {
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
                                shardsBadge
                            }
                        }
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
            }

            Tab("Arena", systemImage: "trophy.fill", value: .social) {
                NavigationStack {
                    ArenaHubView(viewModel: viewModel)
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                brandHeader
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                HStack(spacing: 8) {
                                    sceneEditorButton
                                    shardsBadge
                                }
                            }
                        }
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
                .sheet(isPresented: $showSceneEditor) {
                    NexusEditorView(scene: $editorScene)
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
                                settingsButton
                            }
                        }
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
            }
        }
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
        .onAppear {
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
        .overlay(alignment: .topTrailing) {
            FELOverlayView()
                .padding(.top, 50)
        }
        .overlay {
            FelToastOverlay()
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
        }
    }

    private var sceneEditorButton: some View {
        Button {
            showSceneEditor = true
        } label: {
            Image(systemName: "atom")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.brandCyan)
                .frame(width: 32, height: 32)
                .background(Theme.brandCyan.opacity(0.08))
                .clipShape(Circle())
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
    case vault
}
