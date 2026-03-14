import SwiftUI

struct CommandCenterView: View {
    let viewModel: LabViewModel

    @State private var showDashboard = false
    @State private var showArenaModes = false
    @State private var showLiveEvents = false
    @State private var showMarketplace = false
    @State private var showCoach = false
    @State private var showVault = false
    @State private var pendingQuickPlayMode: GameMode?
    @State private var navigateToQuickPlay = false
    @State private var academyWager: Int = BrainBrawlRulebook.default.minimumWager
    @State private var academyTrack: AcademyTrack = .stemLogic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                commandGrid
                quickPlaySection
                academyControlsSection
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
        .navigationDestination(isPresented: $showVault) {
            VaultView(viewModel: viewModel)
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
            Text("Command center")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brandBlue)

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
                title: "Dashboard",
                subtitle: "Status / profile analytics",
                icon: "waveform.path.ecg.rectangle",
                color: Theme.brandBlue
            ) { showDashboard = true }

            commandCard(
                title: "Arena modes",
                subtitle: "All game modes + matchmaking",
                icon: "trophy.fill",
                color: .orange
            ) { showArenaModes = true }

            commandCard(
                title: "Live events",
                subtitle: "Tickets, fundraising, voting",
                icon: "ticket.fill",
                color: Theme.brandCyan
            ) { showLiveEvents = true }

            commandCard(
                title: "Marketplace",
                subtitle: "Packs, inventory, auctions",
                icon: "hammer.fill",
                color: .orange
            ) { showMarketplace = true }

            commandCard(
                title: "Coach portal",
                subtitle: "Exercises and critiques",
                icon: "figure.strengthtraining.traditional",
                color: Theme.foundationGreen
            ) { showCoach = true }

            commandCard(
                title: "Profile vault",
                subtitle: "Wallets, armory, stats",
                icon: "person.crop.circle.fill",
                color: Theme.elitePurple
            ) { showVault = true }
        }
    }

    private var quickPlaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Quick play")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GameModeRegistry.all, id: \.id) { mode in
                        Button {
                            pendingQuickPlayMode = mode
                            navigateToQuickPlay = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(mode.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Image(systemName: mode.iconName)
                                        .font(.system(size: 10))
                                    Text(mode.environmentName)
                                        .font(.system(size: 11, weight: .medium))
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
            sectionLabel("System snapshot")
            HStack(spacing: 10) {
                snapshotPill(label: "Modes", value: "\(GameModeRegistry.all.count)", icon: "gamecontroller.fill", color: Theme.brandBlue)
                snapshotPill(label: "Events", value: "\(viewModel.upcomingLiveEvents.count)", icon: "ticket.fill", color: Theme.brandCyan)
                snapshotPill(label: "Listings", value: "\(viewModel.activeAuctionListings.count)", icon: "hammer.fill", color: .orange)
            }
            HStack(spacing: 10) {
                snapshotPill(label: "Tickets", value: "\(viewModel.armoryTickets.count)", icon: "qrcode", color: .green)
                snapshotPill(label: "Shards", value: "\(viewModel.profile.evolutionShards)", icon: "diamond.fill", color: Theme.brandCyan)
                snapshotPill(label: "Credits", value: "\(viewModel.profile.premiumCredits)", icon: "creditcard.fill", color: Theme.brandBlue)
            }
            HStack(spacing: 10) {
                snapshotPill(
                    label: "Academy",
                    value: "\(Int(viewModel.academyMasteryAverage * 100))%",
                    icon: "brain.head.profile",
                    color: Theme.elitePurple
                )
                snapshotPill(
                    label: "Prestige",
                    value: "\(viewModel.unlockedPrestigeCount)",
                    icon: "sparkles",
                    color: .yellow
                )
                snapshotPill(
                    label: "Omni",
                    value: viewModel.academyProgress.omniEvolutionState.isUnlocked ? "Unlocked" : "Locked",
                    icon: "infinity.circle.fill",
                    color: Theme.foundationGreen
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var academyControlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Academy / Brain Brawl")

            HStack(spacing: 8) {
                ForEach(MentorId.allCases, id: \.self) { mentor in
                    Button {
                        viewModel.selectMentor(mentor)
                    } label: {
                        Text(mentor.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(viewModel.academyProgress.selectedMentor == mentor ? .black : .white)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 44)
                            .background(viewModel.academyProgress.selectedMentor == mentor ? Theme.brandBlue : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AcademyKnowledgeCatalog.starterNodes, id: \.id) { node in
                        let unlocked = viewModel.academyProgress.unlockedKnowledgeNodeIds.contains(node.id)
                        Button {
                            _ = viewModel.unlockAcademyKnowledgeNode(nodeId: node.id)
                        } label: {
                            Text(unlocked ? "Unlocked: \(node.title)" : "Unlock \(node.title) • \(node.shardUnlockCost)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(unlocked ? .black : .white)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .background(unlocked ? Theme.foundationGreen : Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack {
                Picker("Academy track", selection: $academyTrack) {
                    ForEach(AcademyTrack.allCases, id: \.self) { track in
                        Text(track.rawValue).tag(track)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11))

                Spacer()

                Stepper("Wager \(academyWager)", value: $academyWager, in: BrainBrawlRulebook.default.minimumWager...BrainBrawlRulebook.default.maximumWager, step: 25)
                    .labelsHidden()
                    .accessibilityLabel("Brain Brawl wager")
                    .accessibilityValue("\(academyWager) shards")
            }

            HStack(spacing: 8) {
                Button {
                    _ = viewModel.resolveBrainBrawlMatch(track: academyTrack, wager: academyWager, didWin: true, sabotage: .timeWarp)
                } label: {
                    Text("Simulate win")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Theme.foundationGreen)
                        .clipShape(.rect(cornerRadius: 10))
                }

                Button {
                    _ = viewModel.resolveBrainBrawlMatch(track: academyTrack, wager: academyWager, didWin: false, sabotage: nil)
                } label: {
                    Text("Simulate loss")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(.orange)
                        .clipShape(.rect(cornerRadius: 10))
                }
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10))
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private func snapshotPill(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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
