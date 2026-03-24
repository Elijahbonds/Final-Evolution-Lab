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
    @State private var showQuickStartOptions = false
    @State private var showNeuralScan = false
    @State private var quickPlayNavigationTask: Task<Void, Never>?
    @State private var quickPlayReadiness: Double = 50
    @State private var academyWager: Int = BrainBrawlRulebook.default.minimumWager
    @State private var academyTrack: AcademyTrack = .stemLogic
    @State private var academyStatusMessage: String?
    @State private var academyStatusIsError: Bool = false
    @State private var pendingAcademyConfirmation: AcademyActionConfirmation?
    @State private var bondsSourceInput: String = ""
    @State private var bondsRevisionFocus: String = "improved sequencing, cue clarity, and safer landing mechanics"
    @State private var bondsStatusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                commandGrid
                quickPlaySection
                academyControlsSection
                bondsAIStudioSection
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
                    sessionReadiness: quickPlayReadiness
                )
            }
        }
        .fullScreenCover(isPresented: $showNeuralScan) {
            NeuralReadinessScanView { readiness in
                quickPlayReadiness = readiness
                viewModel.profile.metrics.neuralDrive = min(100, readiness)
                viewModel.profile.metrics.readinessScore = readiness
                SaveSystem.saveProfile(viewModel.profile)
                showNeuralScan = false
                scheduleQuickPlayNavigation()
            }
        }
        .confirmationDialog("Start \(pendingQuickPlayMode?.name ?? "Mode")", isPresented: $showQuickStartOptions, titleVisibility: .visible) {
            Button("Quick Start") {
                quickPlayReadiness = max(50, viewModel.profile.metrics.readinessScore)
                navigateToQuickPlay = true
            }
            Button("Scan & Calibrate") {
                showNeuralScan = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Quick Start uses your latest readiness profile. Scan & Calibrate runs a fresh readiness scan.")
        }
        .alert(item: $pendingAcademyConfirmation) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .default(Text(action.confirmButton)) {
                    performAcademyAction(action)
                },
                secondaryButton: .cancel()
            )
        }
        .onDisappear {
            quickPlayNavigationTask?.cancel()
            quickPlayNavigationTask = nil
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
                            showQuickStartOptions = true
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

    private var bondsAIStudioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Bonds AI studio")

            let activeProject = viewModel.activeBondsBlueprintProject
            let modelName = viewModel.bondsAIStudio.modelProfile?.modelDisplayName ?? "Bonds AI Coach"
            VStack(alignment: .leading, spacing: 4) {
                Text(modelName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text("Sources: \(viewModel.bondsAIStudio.sourceAssets.count) • Projects: \(viewModel.bondsAIStudio.projects.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let activeProject {
                    Text("Active project: \(activeProject.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.brandCyan)
                }
            }

            HStack(spacing: 8) {
                TextField("Paste YouTube source URL", text: $bondsSourceInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.05))
                    )

                Button {
                    let inserted = viewModel.ingestYouTubeBlueprintSources([bondsSourceInput])
                    if inserted > 0 {
                        bondsStatusMessage = "Added YouTube source."
                        bondsSourceInput = ""
                    } else {
                        bondsStatusMessage = "No valid YouTube URL detected."
                    }
                } label: {
                    Text("Add")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Theme.brandBlue)
                        .clipShape(.rect(cornerRadius: 10))
                }
            }

            TextField("Revision focus", text: $bondsRevisionFocus)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )

            HStack(spacing: 8) {
                bondsTrackButton("Foundations", track: .foundations)
                bondsTrackButton("Flight", track: .flight)
                bondsTrackButton("Elite", track: .elite)
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.speakActiveBondsNarration()
                    bondsStatusMessage = "Narration playback started."
                } label: {
                    Text("Play narration")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Theme.foundationGreen)
                        .clipShape(.rect(cornerRadius: 10))
                }

                Button {
                    viewModel.stopActiveBondsNarration()
                    bondsStatusMessage = "Narration playback stopped."
                } label: {
                    Text("Stop")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(.orange)
                        .clipShape(.rect(cornerRadius: 10))
                }
            }

            if let bondsStatusMessage {
                Text(bondsStatusMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.brandCyan)
            }

            if let preview = activeProject?.beats.first?.narrationText {
                Text(preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
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
                        let canUnlock = canUnlockAcademyNode(node)
                        Button {
                            guard !unlocked else {
                                academyStatusIsError = false
                                academyStatusMessage = "\(node.title) is already unlocked."
                                return
                            }
                            guard canUnlock else {
                                academyStatusIsError = true
                                academyStatusMessage = academyUnlockFailureMessage(for: node)
                                return
                            }
                            pendingAcademyConfirmation = .unlock(
                                nodeId: node.id,
                                nodeTitle: node.title,
                                shardCost: node.shardUnlockCost
                            )
                        } label: {
                            Text(unlocked ? "Unlocked: \(node.title)" : "Unlock \(node.title) • \(node.shardUnlockCost)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(unlocked ? .black : .white)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .background(unlocked ? Theme.foundationGreen : (canUnlock ? Color.white.opacity(0.06) : Color.white.opacity(0.02)))
                                .clipShape(Capsule())
                        }
                        .disabled(unlocked)
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

                HStack(spacing: 8) {
                    Text("Wager: \(academyWager)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Stepper("Wager", value: $academyWager, in: BrainBrawlRulebook.default.minimumWager...BrainBrawlRulebook.default.maximumWager, step: 25)
                        .labelsHidden()
                }
                    .accessibilityLabel("Brain Brawl wager")
                    .accessibilityValue("\(academyWager) shards")
            }

            HStack(spacing: 8) {
                Button {
                    guard canRunBrainBrawlWin else {
                        academyStatusIsError = true
                        academyStatusMessage = "Not enough shards for this wager + sabotage."
                        return
                    }
                    let sabotageCost = BrainBrawlRulebook.default.debuffs.first(where: { $0.type == .timeWarp })?.shardCost ?? 0
                    pendingAcademyConfirmation = .brainBrawlWin(track: academyTrack, wager: academyWager, sabotageCost: sabotageCost)
                } label: {
                    Text("Simulate win")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Theme.foundationGreen)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .disabled(!canRunBrainBrawlWin)

                Button {
                    guard canRunBrainBrawlLoss else {
                        academyStatusIsError = true
                        academyStatusMessage = "Not enough shards for this wager."
                        return
                    }
                    pendingAcademyConfirmation = .brainBrawlLoss(track: academyTrack, wager: academyWager)
                } label: {
                    Text("Simulate loss")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(.orange)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .disabled(!canRunBrainBrawlLoss)
            }

            if let academyStatusMessage {
                Text(academyStatusMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(academyStatusIsError ? .orange : Theme.brandCyan)
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

    private func bondsTrackButton(_ title: String, track: TrainingTrack) -> some View {
        Button {
            let project = viewModel.generateBondsBlueprintProject(
                track: track,
                equipment: .movementEducation,
                revisionFocus: bondsRevisionFocus
            )
            bondsStatusMessage = project == nil ? "Unable to generate project." : "Generated \(title) project."
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Theme.brandBlue)
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var canRunBrainBrawlLoss: Bool {
        viewModel.profile.evolutionShards >= academyWager
    }

    private var canRunBrainBrawlWin: Bool {
        let sabotageCost = BrainBrawlRulebook.default.debuffs.first(where: { $0.type == .timeWarp })?.shardCost ?? 0
        return viewModel.profile.evolutionShards >= academyWager + sabotageCost
    }

    private func canUnlockAcademyNode(_ node: KnowledgeNode) -> Bool {
        let hasPrereqs = node.prerequisiteNodeIds.allSatisfy { viewModel.academyProgress.unlockedKnowledgeNodeIds.contains($0) }
        let hasShards = viewModel.profile.evolutionShards >= node.shardUnlockCost
        return hasPrereqs && hasShards
    }

    private func academyUnlockFailureMessage(for node: KnowledgeNode) -> String {
        let hasPrereqs = node.prerequisiteNodeIds.allSatisfy { viewModel.academyProgress.unlockedKnowledgeNodeIds.contains($0) }
        if !hasPrereqs {
            return "Prerequisites not met for \(node.title)."
        }
        if viewModel.profile.evolutionShards < node.shardUnlockCost {
            return "Not enough shards to unlock \(node.title)."
        }
        return "Unable to unlock \(node.title)."
    }

    private func scheduleQuickPlayNavigation() {
        quickPlayNavigationTask?.cancel()
        quickPlayNavigationTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                navigateToQuickPlay = true
            }
        }
    }

    private func performAcademyAction(_ action: AcademyActionConfirmation) {
        switch action {
        case let .unlock(nodeId, nodeTitle, _):
            let ok = viewModel.unlockAcademyKnowledgeNode(nodeId: nodeId)
            academyStatusIsError = !ok
            academyStatusMessage = ok ? "Unlocked \(nodeTitle)." : "Unable to unlock \(nodeTitle)."
        case let .brainBrawlWin(track, wager, _):
            let ok = viewModel.resolveBrainBrawlMatch(track: track, wager: wager, didWin: true, sabotage: .timeWarp)
            academyStatusIsError = !ok
            academyStatusMessage = ok ? "Simulated win completed." : "Not enough shards for this wager + sabotage."
        case let .brainBrawlLoss(track, wager):
            let ok = viewModel.resolveBrainBrawlMatch(track: track, wager: wager, didWin: false, sabotage: nil)
            academyStatusIsError = !ok
            academyStatusMessage = ok ? "Simulated loss completed." : "Not enough shards for this wager."
        }
    }
}

private enum AcademyActionConfirmation: Identifiable {
    case unlock(nodeId: String, nodeTitle: String, shardCost: Int)
    case brainBrawlWin(track: AcademyTrack, wager: Int, sabotageCost: Int)
    case brainBrawlLoss(track: AcademyTrack, wager: Int)

    var id: String {
        switch self {
        case let .unlock(nodeId, _, shardCost):
            return "unlock-\(nodeId)-\(shardCost)"
        case let .brainBrawlWin(track, wager, sabotageCost):
            return "bb-win-\(track.rawValue)-\(wager)-\(sabotageCost)"
        case let .brainBrawlLoss(track, wager):
            return "bb-loss-\(track.rawValue)-\(wager)"
        }
    }

    var title: String {
        switch self {
        case let .unlock(_, nodeTitle, _):
            return "Unlock \(nodeTitle)?"
        case .brainBrawlWin:
            return "Simulate Brain Brawl win?"
        case .brainBrawlLoss:
            return "Simulate Brain Brawl loss?"
        }
    }

    var message: String {
        switch self {
        case let .unlock(_, _, shardCost):
            return "This spends \(shardCost) shards."
        case let .brainBrawlWin(_, wager, sabotageCost):
            return "This spends \(wager + sabotageCost) shards (\(wager) wager + \(sabotageCost) sabotage)."
        case let .brainBrawlLoss(_, wager):
            return "This spends \(wager) shards."
        }
    }

    var confirmButton: String {
        switch self {
        case .unlock:
            return "Unlock"
        case .brainBrawlWin:
            return "Simulate Win"
        case .brainBrawlLoss:
            return "Simulate Loss"
        }
    }
}
