import SwiftUI

struct ContentView: View {
    @State private var viewModel = LabViewModel()
    @State private var selectedTab: AppTab = .games
    @AppStorage("simpleMode") private var simpleMode: Bool = false
    @State private var showSettings: Bool = false
    @State private var showOnboarding: Bool = false

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
            if !showSettings && !showOnboarding {
                PRQOverlayView()
                    .padding(.top, 50)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSettings)
        .animation(.easeInOut(duration: 0.2), value: showOnboarding)
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
    case vault
}
