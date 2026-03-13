import SwiftUI

struct CommandCenterView: View {
    let viewModel: LabViewModel

    @State private var showDashboard = false
    @State private var showArenaModes = false
    @State private var showLiveEvents = false
    @State private var showMarketplace = false
    @State private var showCoach = false
    @State private var pendingQuickPlayMode: GameMode?
    @State private var navigateToQuickPlay = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                commandGrid
                quickPlaySection
                gameplaySystemsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .navigationDestination(isPresented: $showDashboard) {
            DashboardView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showArenaModes) {
            GameModeSelectionView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showLiveEvents) {
            LiveEventsHubView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showMarketplace) {
            CreatorMarketplaceHubView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showCoach) {
            CoachView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $navigateToQuickPlay) {
            if let mode = pendingQuickPlayMode {
                GamePlayView(
                    viewModel: viewModel,
                    gameMode: mode,
                    sessionReadiness: max(50, viewModel.profile.metrics.readinessScore)
                )
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ALL SCREENS")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(4)

            Text("Command")
                .font(.system(size: 50, weight: .black))
                .italic()
                .foregroundStyle(.white)

            Text("Build, test, and play every major feature")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var commandGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            commandCard(
                title: "DASHBOARD",
                subtitle: "Status / profile analytics",
                icon: "waveform.path.ecg.rectangle",
                color: Theme.brandBlue
            ) { showDashboard = true }

            commandCard(
                title: "ARENA MODES",
                subtitle: "All game modes + matchmaking",
                icon: "trophy.fill",
                color: .orange
            ) { showArenaModes = true }

            commandCard(
                title: "LIVE EVENTS",
                subtitle: "Tickets, fundraising, voting",
                icon: "ticket.fill",
                color: Theme.brandCyan
            ) { showLiveEvents = true }

            commandCard(
                title: "MARKETPLACE",
                subtitle: "Packs, inventory, auctions",
                icon: "hammer.fill",
                color: .orange
            ) { showMarketplace = true }

            commandCard(
                title: "COACH PORTAL",
                subtitle: "Exercises and critiques",
                icon: "figure.strengthtraining.traditional",
                color: Theme.foundationGreen
            ) { showCoach = true }

            commandCard(
                title: "PROFILE VAULT",
                subtitle: "Wallets, armory, stats",
                icon: "person.crop.circle.fill",
                color: Theme.elitePurple
            ) { showDashboard = true }
        }
    }

    private var quickPlaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("QUICK PLAY")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GameModeRegistry.all.prefix(10), id: \.id) { mode in
                        Button {
                            pendingQuickPlayMode = mode
                            navigateToQuickPlay = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.name.uppercased())
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(mode.subtitle)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Image(systemName: mode.iconName)
                                        .font(.system(size: 8))
                                    Text(mode.environmentName)
                                        .font(.system(size: 8, design: .monospaced))
                                }
                                .foregroundStyle(mode.accentColor.opacity(0.85))
                            }
                            .padding(10)
                            .frame(width: 190, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(mode.accentColor.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var gameplaySystemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("SYSTEM SNAPSHOT")
            HStack(spacing: 10) {
                snapshotPill(label: "MODES", value: "\(GameModeRegistry.all.count)", icon: "gamecontroller.fill", color: Theme.brandBlue)
                snapshotPill(label: "EVENTS", value: "\(viewModel.upcomingLiveEvents.count)", icon: "ticket.fill", color: Theme.brandCyan)
                snapshotPill(label: "LISTINGS", value: "\(viewModel.activeAuctionListings.count)", icon: "hammer.fill", color: .orange)
            }
            HStack(spacing: 10) {
                snapshotPill(label: "TICKETS", value: "\(viewModel.armoryTickets.count)", icon: "qrcode", color: .green)
                snapshotPill(label: "SHARDS", value: "\(viewModel.profile.evolutionShards)", icon: "diamond.fill", color: Theme.brandCyan)
                snapshotPill(label: "CREDITS", value: "\(viewModel.profile.premiumCredits)", icon: "creditcard.fill", color: Theme.brandBlue)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private func commandCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.2), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.tertiary)
            .tracking(2)
    }

    private func snapshotPill(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
    }
}
