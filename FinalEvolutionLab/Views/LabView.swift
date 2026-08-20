import SwiftUI

struct LabView: View {
    let viewModel: LabViewModel

    @State private var appeared = false
    @State private var pulsePhase: CGFloat = 0
    @State private var dunkFlash: Bool = false
    @State private var showCourtExpanded: Bool = false
    @State private var courtLoaded: Bool = false
    @State private var showSystemScan: Bool = false
    @State private var showMoCapStudio: Bool = false
    @State private var showFaceScanStudio: Bool = false
    @State private var showBiomechanicsDetail: Bool = false
    @State private var showCharacterEditor: Bool = false
    @State private var showGlobalMatchmaking: Bool = false
    @State private var showCoach: Bool = false
    @State private var showBlueprints: Bool = false
    @State private var showBodyIQLab: Bool = false
    @State private var showBondsCoachPrescription: Bool = false
    @State private var showCreatorHub: Bool = false
    @State private var pendingArenaMode: GameMode?
    @State private var sessionReadiness: Double = 50
    @State private var navigateToArenaGame: Bool = false
    @State private var showDunkPlatform: Bool = false
    @State private var freestyleDunk = DunkContestState()
    @State private var freestyleDunkTimer: Task<Void, Never>?
    @State private var freestyleLastAction: String = ""
    @State private var freestyleJudgeScores: (Int, Int, Int)?
    @State private var freestyleCrowdMessage: String = ""
    @State private var freestyleScreenShake: CGFloat = 0
    @Environment(\.simpleMode) private var simpleMode

    private var effectiveMetrics: PerformanceMetrics {
        viewModel.effectiveMetrics
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                tierBanner
                scanSection
                mocapStudioEntry
                faceScanStudioEntry
                biomechanicsSection
                bodyIQEducationEntry
                creatorHubEntry
                athleteProfileBanner
                globalArenaCard
                courtSection
                neuralDriveCard
                hrvReadinessCard
                metricsGrid
                CreatorCardBoostView(viewModel: viewModel)
                coachAndBlueprintsRow
                parentalOverviewSection
                quickStartSection
                recentActivitySection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.spring(response: 0.4)) { courtLoaded = true }
            }
        }
        .onDisappear {
            freestyleDunkTimer?.cancel()
            freestyleDunkTimer = nil
        }
        .sheet(isPresented: $showSystemScan) {
            SystemScanView(
                sport: viewModel.profile.sport,
                goal: viewModel.profile.goal
            ) { result in
                viewModel.applyScanResult(result)
            }
        }
        .sheet(isPresented: $showMoCapStudio) {
            NexusMoCapStudioView(viewModel: viewModel)
        }
        .sheet(isPresented: $showFaceScanStudio) {
            NexusFaceScanView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCharacterEditor) {
            SystemScanCharacterEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $showBiomechanicsDetail) {
            biomechanicsDetailSheet
        }
        .sheet(isPresented: $showGlobalMatchmaking) {
            if let mode = pendingArenaMode {
                MatchmakingView(viewModel: viewModel, gameMode: mode) { opponent, readiness in
                    sessionReadiness = readiness
                    showGlobalMatchmaking = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        if mode.id.isIRLDunkContest {
                            showDunkPlatform = true
                        } else {
                            navigateToArenaGame = true
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToArenaGame) {
            if let mode = pendingArenaMode {
                if mode.id.isIRLDunkContest {
                    DunkMatchmakingView(viewModel: viewModel)
                } else {
                    GamePlayView(viewModel: viewModel, gameMode: mode, sessionReadiness: sessionReadiness)
                }
            }
        }
        .fullScreenCover(isPresented: $showDunkPlatform) {
            NavigationStack {
                DunkMatchmakingView(viewModel: viewModel)
            }
        }
        .navigationDestination(isPresented: $showCoach) {
            CoachView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showBlueprints) {
            BlueprintsView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showBodyIQLab) {
            BodyIQEducationLabView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showCreatorHub) {
            NexusCreatorHubView(viewModel: viewModel)
        }
        .sheet(isPresented: $showBondsCoachPrescription) {
            NavigationStack {
                BondsStandardCoachView()
            }
            .presentationBackground(Theme.deepBlack)
        }
        .onChange(of: viewModel.biomechanicsAudit?.auditDate) { _, _ in
            guard let audit = viewModel.biomechanicsAudit else { return }
            // Bonds Standard targets hip chain mechanics — do not tie this sheet to core/IAP routing inferred from PRQ-only proxies.
            let hasHipLeakage = audit.kineticLeakageZones.contains { $0.joint == .hip }
            guard hasHipLeakage else { return }
            let ts = audit.auditDate.timeIntervalSince1970
            let key = "fel_bonds_coach_prompted_\(Int(ts))"
            guard !UserDefaults.standard.bool(forKey: key) else { return }
            UserDefaults.standard.set(true, forKey: key)
            showBondsCoachPrescription = true
        }
    }

    private var mocapStudioEntry: some View {
        Button {
            showMoCapStudio = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("3D MOCAP STUDIO")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.white)
                        FELPreviewLabel(text: "BETA")
                    }
                    Text("Markerless 3D motion capture · Real-time retargeting")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.45), Theme.brandBlue.opacity(0.25)],
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

    private var faceScanStudioEntry: some View {
        Button {
            showFaceScanStudio = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "faceid")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("FACE SCAN STUDIO")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.white)
                        FELPreviewLabel(text: "LIVE LINK")
                    }
                    Text("Markerless 3D face scan · Real-time facial expression tracking")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.45), Theme.brandBlue.opacity(0.25)],
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

    private var bodyIQEducationEntry: some View {
        Button {
            showBodyIQLab = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.elitePurple.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "figure.flexibility")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.elitePurple)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("BODY IQ LAB")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.white)
                        FELPreviewLabel(text: FELPremiumCopy.Preview.education)
                    }
                    Text("Movement Snacks · Bonds Standard prescriptions")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.elitePurple.opacity(0.45), Theme.brandCyan.opacity(0.25)],
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

    private var creatorHubEntry: some View {
        Button {
            showCreatorHub = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("MOCAP CREATOR HUB")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.white)
                        FELPreviewLabel(text: "MINTING")
                    }
                    Text("Mint custom cards · Track shard royalties")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.45), Theme.elitePurple.opacity(0.25)],
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VENICE BEACH")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            Text("Lab")
                .font(.system(size: 52, weight: .black, design: .default))
                .italic()
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.brandBlue)
                    .frame(width: 8, height: 8)
                    .symbolEffect(.pulse)

                Text(SimpleModeLabels.neuralEngine(simpleMode))
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Theme.brandBlue.opacity(0.8))

                Spacer()

                NeuralAuraBadge(auraLevel: viewModel.arcadePhysics.auraLevel)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var tierBanner: some View {
        HStack(spacing: 12) {
            PRQTierBadge(tier: viewModel.userPRQTier, prq: viewModel.competitivePRQScore)

            Spacer()

            if viewModel.globalLeaderboard.userGlobalRank > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.brandBlue)
                    Text("#\(viewModel.globalLeaderboard.userGlobalRank)")
                        .font(.system(.caption, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                    Text("GLOBAL")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
                .clipShape(.rect(cornerRadius: 8))
            }

            if viewModel.arcadePhysics.neuralBurstActive {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.elitePurple)
                    Text("1.5x")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.elitePurple)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.elitePurple.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var biomechanicsSection: some View {
        if let audit = viewModel.biomechanicsAudit {
            Button {
                showBiomechanicsDetail = true
            } label: {
                BiomechanicsDashboardCard(audit: audit)
            }
            .buttonStyle(.plain)
        }
    }

    private var biomechanicsDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let audit = viewModel.biomechanicsAudit {
                        BiomechanicsDashboardCard(audit: audit)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("JOINT ANALYSIS")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.brandCyan)
                                .tracking(2)

                            BiomechanicsOverlayView(audit: audit)
                                .frame(height: 350)
                                .clipShape(.rect(cornerRadius: 16))
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Theme.cardBackground)
                                )
                        }

                        attributeImpactSection(audit: audit)
                    }
                }
                .padding()
            }
            .background(Theme.deepBlack)
            .navigationTitle("Biomechanics Audit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showBiomechanicsDetail = false }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
    }

    private func attributeImpactSection(audit: BiomechanicsAudit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ATTRIBUTE IMPACT")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(2)

            VStack(spacing: 8) {
                AttributeImpactRow(
                    attribute: "Explosive First Step",
                    joint: "Ankle",
                    status: audit.ankleDorsiflexion.status,
                    modifier: audit.ankleDorsiflexion.status == .deficit ? "0.7x" : (audit.ankleDorsiflexion.status == .moderate ? "0.85x" : "1.0x")
                )
                AttributeImpactRow(
                    attribute: "Success Chance",
                    joint: "Knee",
                    status: audit.kneeTracking.status,
                    modifier: audit.kneeTracking.status == .deficit ? "0.75x" : (audit.kneeTracking.status == .moderate ? "0.88x" : "1.0x")
                )
                AttributeImpactRow(
                    attribute: "Hang Time",
                    joint: "Hip",
                    status: audit.hipExtension.status,
                    modifier: audit.hipExtension.status == .deficit ? "0.7x" : (audit.hipExtension.status == .moderate ? "0.85x" : "1.0x")
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandBlue.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var globalArenaCard: some View {
        Button {
            guard let mode = GameModeRegistry.resolvedLastSelectedMode() else { return }
            pendingArenaMode = mode
            if mode.id.isIRLDunkContest {
                showDunkPlatform = true
            } else {
                showGlobalMatchmaking = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: "globe")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .symbolEffect(.pulse)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("GLOBAL ARENA")
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.white)

                    if let last = GameModeRegistry.resolvedLastSelectedMode() {
                        HStack(spacing: 8) {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 5, height: 5)
                                Text("\(viewModel.globalLeaderboard.onlinePlayerCount) online")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.green.opacity(0.7))
                            }

                            Text(last.name.uppercased())
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan.opacity(0.6))
                        }
                    } else {
                        Text("Choose a mode in Arena tab first")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.orange.opacity(0.85))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
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

    private var courtSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FREESTYLE DUNK PRACTICE")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandBlue)
                        .tracking(2)

                    Text("Venice Beach Court")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    NeuralAuraBadge(auraLevel: viewModel.arcadePhysics.auraLevel)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showCourtExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: showCourtExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.brandBlue)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
            }

            ZStack {
                if courtLoaded {
                    GameSceneHostView(gameMode: .basketballDunkContest3D, neuralDrive: viewModel.profile.metrics.neuralDrive)
                        .frame(height: showCourtExpanded ? 420 : 280)
                        .clipShape(.rect(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [Theme.brandBlue.opacity(0.3), Theme.brandCyan.opacity(0.15), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .overlay(alignment: .topTrailing) {
                            freestyleDunkPhaseIndicator
                        }
                        .overlay(alignment: .bottom) {
                            freestyleScoringOverlay
                        }
                        .overlay(alignment: .topLeading) {
                            Text("NEURAL DRIVE \(Int(viewModel.profile.metrics.neuralDrive))%")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                                .padding(8)
                        }
                        .overlay(alignment: .bottom) {
                            Text("HOLD X TO GATHER")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.bottom, 40)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.cardBackground)
                        .frame(height: 280)
                        .overlay {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(Theme.brandBlue)
                                Text("LOADING COURT")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.brandBlue.opacity(0.6))
                                    .tracking(2)
                            }
                        }
                }

                if dunkFlash {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            RadialGradient(
                                colors: [Theme.brandCyan.opacity(0.2), Theme.brandBlue.opacity(0.08), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 200
                            )
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .offset(x: freestyleScreenShake)

            freestyleDunkControls
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandBlue.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Freestyle Dunk Engine Controls

    @ViewBuilder
    private var freestyleDunkControls: some View {
        switch freestyleDunk.phase {
        case .idle:
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(DunkTrickSlot.allCases, id: \.rawValue) { trick in
                            Button {
                                withAnimation(.spring(response: 0.2)) {
                                    freestyleDunk.selectedTrick = trick
                                }
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: trick.icon)
                                        .font(.system(size: 13, weight: .bold))
                                    Text(trick.rawValue)
                                        .font(.system(size: 6, weight: .black, design: .monospaced))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                    HStack(spacing: 1) {
                                        ForEach(0..<5, id: \.self) { i in
                                            Circle()
                                                .fill(Double(i) / 5.0 < trick.complexity ? .orange : .white.opacity(0.15))
                                                .frame(width: 3, height: 3)
                                        }
                                    }
                                }
                                .foregroundStyle(freestyleDunk.selectedTrick == trick ? .black : .white)
                                .frame(width: 60, height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(freestyleDunk.selectedTrick == trick ? .orange : .orange.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(freestyleDunk.selectedTrick == trick ? .orange : .orange.opacity(0.25), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)

                Button {
                    startFreestyleApproach()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 14, weight: .bold))
                        Text("START APPROACH")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [.orange, Color(red: 1.0, green: 0.5, blue: 0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: .orange.opacity(0.3), radius: 8)
                }
            }

        case .approach:
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("HOLD TO SPRINT")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(1)
                    Spacer()
                    Text("\(Int(freestyleDunk.sprintCharge * 100))%")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.black.opacity(0.6))
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, freestyleDunk.sprintCharge > 0.8 ? .orange : .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * freestyleDunk.sprintCharge)
                            .animation(.linear(duration: 0.05), value: freestyleDunk.sprintCharge)
                    }
                }
                .frame(height: 12)
                .clipShape(.rect(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.cyan.opacity(0.4), lineWidth: 1)
                )

                Button {
                    releaseFreestyleSprint()
                } label: {
                    Text("RELEASE TO LAUNCH")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(.rect(cornerRadius: 12))
                }
            }

        case .launch:
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                    Text("TAP TO JUMP")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(1)
                    Spacer()
                }

                freestyleTimingBar(
                    value: freestyleDunk.launchTiming,
                    greenZone: freestyleDunk.launchGreenZone,
                    accentColor: .green
                )

                Button {
                    confirmFreestyleLaunch()
                } label: {
                    Text("JUMP!")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            freestyleDunk.launchGreenZone.contains(freestyleDunk.launchTiming)
                                ? Color.green
                                : Color.green.opacity(0.4)
                        )
                        .clipShape(.rect(cornerRadius: 12))
                        .shadow(color: .green.opacity(0.3), radius: 6)
                }
            }

        case .airborne:
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.highintensity.intervaltraining")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.purple)
                    Text(freestyleDunk.selectedTrick.rawValue)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(1)
                    Spacer()
                    Text("\(Int(freestyleDunk.completedRotation * 100))%")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(freestyleDunk.completedRotation >= 0.9 ? .green : .purple)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.black.opacity(0.6))
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, freestyleDunk.completedRotation >= 0.9 ? .green : .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(1, freestyleDunk.completedRotation))
                            .animation(.linear(duration: 0.05), value: freestyleDunk.completedRotation)
                    }
                }
                .frame(height: 8)
                .clipShape(.rect(cornerRadius: 5))

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.15)) {
                            freestyleDunk.isRotating.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: freestyleDunk.isRotating ? "arrow.trianglehead.2.clockwise.rotate.90" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(freestyleDunk.isRotating ? "ROTATING" : "SPIN")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(freestyleDunk.isRotating ? .black : .purple)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            freestyleDunk.isRotating ? AnyShapeStyle(Color.purple) : AnyShapeStyle(Color.purple.opacity(0.15))
                        )
                        .clipShape(.rect(cornerRadius: 10))
                    }

                    Button {
                        confirmFreestyleLanding()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.system(size: 12, weight: .bold))
                            Text("SLAM!")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(color: .orange.opacity(0.4), radius: 6)
                    }
                }
            }

        case .landing:
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("STICK THE LANDING!")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(1)
                    Spacer()
                }

                freestyleTimingBar(
                    value: freestyleDunk.landingTiming,
                    greenZone: freestyleDunk.landingGreenZone,
                    accentColor: .orange
                )

                Button {
                    confirmFreestyleLanding()
                } label: {
                    Text("LAND!")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            freestyleDunk.landingGreenZone.contains(freestyleDunk.landingTiming)
                                ? Color.orange
                                : Color.orange.opacity(0.4)
                        )
                        .clipShape(.rect(cornerRadius: 12))
                        .shadow(color: .orange.opacity(0.3), radius: 6)
                }
            }

        case .scored:
            EmptyView()
        }
    }

    private func freestyleTimingBar(value: Double, greenZone: ClosedRange<Double>, accentColor: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.6))

                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor.opacity(0.25))
                    .frame(
                        width: geo.size.width * (greenZone.upperBound - greenZone.lowerBound)
                    )
                    .offset(x: geo.size.width * greenZone.lowerBound)

                RoundedRectangle(cornerRadius: 2)
                    .fill(greenZone.contains(value) ? accentColor : .red)
                    .frame(width: 4)
                    .offset(x: geo.size.width * value - 2)
                    .animation(.linear(duration: 0.03), value: value)
            }
        }
        .frame(height: 16)
        .clipShape(.rect(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var freestyleDunkPhaseIndicator: some View {
        if freestyleDunk.phase != .idle && freestyleDunk.phase != .scored {
            VStack(spacing: 4) {
                Text(freestylePhaseLabel)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(freestylePhaseColor)
                    .tracking(1)
                if freestyleDunk.phase == .airborne {
                    Text(String(format: "HEIGHT: %.0f%%", freestyleDunk.jumpHeight * 100))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(freestylePhaseColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(10)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var freestyleScoringOverlay: some View {
        if let scores = freestyleJudgeScores {
            VStack(spacing: 4) {
                if !freestyleCrowdMessage.isEmpty {
                    Text(freestyleCrowdMessage)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(1)
                }
                HStack(spacing: 12) {
                    ForEach([scores.0, scores.1, scores.2], id: \.self) { s in
                        Text("\(s)")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.orange.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.orange.opacity(0.4), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.75))
            )
            .padding(.bottom, 10)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var freestylePhaseLabel: String {
        switch freestyleDunk.phase {
        case .approach: return "SPRINTING"
        case .launch: return "GATHER"
        case .airborne: return "IN THE AIR"
        case .landing: return "LANDING"
        default: return ""
        }
    }

    private var freestylePhaseColor: Color {
        switch freestyleDunk.phase {
        case .approach: return .cyan
        case .launch: return .green
        case .airborne: return .purple
        case .landing: return .orange
        default: return .white
        }
    }

    // MARK: - Freestyle Dunk Engine Logic

    private func startFreestyleApproach() {
        guard freestyleDunk.phase == .idle else { return }
        withAnimation(.spring(response: 0.2)) {
            freestyleDunk.startApproach()
        }
        freestyleDunkTimer?.cancel()
        freestyleDunkTimer = Task {
            while !Task.isCancelled && freestyleDunk.phase == .approach && freestyleDunk.isSprintHeld {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.016)) {
                    freestyleDunk.sprintCharge = min(1.0, freestyleDunk.sprintCharge + 0.016 * freestyleDunk.sprintChargeRate)
                }
                if freestyleDunk.sprintCharge >= 1.0 {
                    releaseFreestyleSprint()
                    return
                }
            }
        }
    }

    private func releaseFreestyleSprint() {
        guard freestyleDunk.phase == .approach else { return }
        freestyleDunkTimer?.cancel()
        withAnimation(.spring(response: 0.2)) {
            freestyleDunk.releaseSprint()
        }
        freestyleDunkTimer = Task {
            while !Task.isCancelled && freestyleDunk.phase == .launch {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.016)) {
                    freestyleDunk.launchTiming += freestyleDunk.launchTimingDirection * freestyleDunk.launchTimingSpeed * 0.016
                    if freestyleDunk.launchTiming >= 1.0 { freestyleDunk.launchTimingDirection = -1 }
                    if freestyleDunk.launchTiming <= 0.0 { freestyleDunk.launchTimingDirection = 1 }
                    freestyleDunk.launchTiming = max(0, min(1, freestyleDunk.launchTiming))
                }
            }
        }
    }

    private func confirmFreestyleLaunch() {
        guard freestyleDunk.phase == .launch else { return }
        freestyleDunkTimer?.cancel()
        let inGreen = freestyleDunk.launchGreenZone.contains(freestyleDunk.launchTiming)
        withAnimation(.spring(response: 0.2)) {
            freestyleDunk.confirmLaunch()
            freestyleLastAction = inGreen ? "PERFECT LAUNCH!" : "LAUNCHED"
        }
        triggerFreestyleShake(intensity: inGreen ? 0.4 : 0.2)

        freestyleDunkTimer = Task {
            while !Task.isCancelled && (freestyleDunk.phase == .airborne || freestyleDunk.phase == .landing) {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.016)) {
                    freestyleDunk.updateAirborne(delta: 0.016)
                }
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation {
                if freestyleLastAction == "PERFECT LAUNCH!" || freestyleLastAction == "LAUNCHED" {
                    freestyleLastAction = ""
                }
            }
        }
    }

    private func confirmFreestyleLanding() {
        guard freestyleDunk.phase == .airborne || freestyleDunk.phase == .landing else { return }
        freestyleDunkTimer?.cancel()
        withAnimation(.spring(response: 0.15)) {
            freestyleDunk.confirmLanding()
        }
        executeFreestyleScoring()
    }

    private func executeFreestyleScoring() {
        let prq = viewModel.effectiveMetrics.prqScore
        let burst = viewModel.arcadePhysics.neuralBurstActive
        var judgeRNG = SplitMix64(seed: freestyleDunk.sessionSeed &+ UInt64(freestyleDunk.round) &+ 0x6A75647F)
        let result = freestyleDunk.calculateDunkScore(prq: prq, neuralBurst: burst, judgeRNG: &judgeRNG)

        withAnimation(.spring(response: 0.3)) {
            freestyleJudgeScores = (result.j1, result.j2, result.j3)
            freestyleCrowdMessage = result.message
        }

        let impactLevel = freestyleDunk.impactIntensity
        triggerFreestyleShake(intensity: 0.5 + impactLevel * 0.5)

        if result.total >= 138 {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { dunkFlash = true }
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dunkFlash = false }
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.3)) {
                freestyleJudgeScores = nil
                freestyleCrowdMessage = ""
                freestyleLastAction = ""
            }
            withAnimation(.spring(response: 0.3)) {
                freestyleDunk.advanceRound()
                freestyleDunk.round = 1
                freestyleDunk.totalRounds = 999
            }
        }
    }

    private func triggerFreestyleShake(intensity: Double) {
        let amplitude = intensity * 3
        Task {
            for _ in 0..<4 {
                withAnimation(.linear(duration: 0.03)) {
                    freestyleScreenShake = CGFloat.random(in: -amplitude...amplitude)
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
            withAnimation(.spring(response: 0.1)) {
                freestyleScreenShake = 0
            }
        }
    }

    @ViewBuilder
    private var scanSection: some View {
        if let scan = viewModel.profile.systemScan {
            scanDataDashboard(scan)
        } else {
            scanPromptCard
        }
    }

    private var scanPromptCard: some View {
        Button {
            showSystemScan = true
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.08))
                        .frame(width: 72, height: 72)

                    Image(systemName: "figure.basketball")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .symbolEffect(.pulse)
                }

                VStack(spacing: 6) {
                    Text("SYSTEM SCAN")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(3)

                    Text("Upload a jump video to get your PRQ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("START SCAN")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.brandCyan)
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Theme.brandCyan.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func scanDataDashboard(_ scan: SystemScanResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SCAN DATA")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)

                    if !scan.commitsCompetitiveMetrics {
                        Text("Preview PRQ — not applied to ranked PRQ or Body IQ prescriptions")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }

                    Text(scan.movementGrade)
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showCharacterEditor = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                            Text("CUSTOMIZE")
                        }
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.brandBlue.opacity(0.12))
                        .foregroundStyle(Theme.brandBlue)
                        .clipShape(Capsule())
                    }

                    Button {
                        showSystemScan = true
                    } label: {
                        Text("RESCAN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.brandCyan.opacity(0.12))
                            .foregroundStyle(Theme.brandCyan)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 10) {
                ScanStatPill(label: "PRQ", value: String(format: "%.1f", scan.prqScore), color: Theme.brandBlue)
                ScanStatPill(label: "VERTICAL", value: String(format: "%.1f\"", scan.verticalEstimateInches), color: Theme.brandCyan)
                ScanStatPill(label: "FLIGHT", value: String(format: "%.2fs", scan.flightTimeSeconds), color: Theme.elitePurple)
            }

            if let firstNote = scan.notes.first {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.brandBlue)
                        .padding(.top, 2)

                    Text(firstNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 9))
                Text(scan.date, style: .relative)
                    .font(.system(size: 10, design: .monospaced))
                Text("Recommended: \(scan.recommendedTrack)")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var athleteProfileBanner: some View {
        if viewModel.profile.sport != nil {
            HStack(spacing: 12) {
                Image(systemName: sportIcon(viewModel.profile.sport ?? ""))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)
                    .frame(width: 40, height: 40)
                    .background(Theme.brandBlue.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.profile.sport?.uppercased() ?? "")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        if let age = viewModel.profile.age {
                            Text("Age \(age)")
                        }
                        if let goal = viewModel.profile.goal {
                            Text(goal)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
            )
        }
    }

    private func sportIcon(_ sport: String) -> String {
        switch sport {
        case "Basketball": "basketball.fill"
        case "Football": "football.fill"
        case "Soccer": "soccerball"
        case "Baseball": "baseball.fill"
        case "Track & Field": "figure.run"
        case "Volleyball": "volleyball.fill"
        case "Gymnastics": "figure.gymnastics"
        case "Combat Sports": "figure.martial.arts"
        case "Golf": "figure.golf"
        default: "sportscourt.fill"
        }
    }

    private var neuralDriveCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SimpleModeLabels.neuralDrive(simpleMode))
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandBlue)
                        .tracking(2)

                    Text("\(Int(effectiveMetrics.neuralDrive))%")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                NeuralDriveOrb(value: effectiveMetrics.neuralDrive)
                    .frame(width: 80, height: 80)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.brandBlue, Theme.brandCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(effectiveMetrics.neuralDrive, 100) / 100)
                        .shadow(color: Theme.brandBlue.opacity(0.5), radius: 8)
                }
            }
            .frame(height: 6)

            if viewModel.arcadePhysics.neuralBurstActive {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.elitePurple)
                    Text("NEURAL BURST ACTIVE — 1.5x SCORING")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.elitePurple)
                        .tracking(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.elitePurple.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandBlue.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var hrvReadinessCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEURAL READINESS")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)

                    Text(viewModel.healthKit.neuralReadinessGrade.rawValue)
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(hrvGradeColor)
                }

                Spacer()

                if viewModel.healthKit.isAuthorized {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f", viewModel.healthKit.neuralReadinessScore))
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        HStack(spacing: 3) {
                            Image(systemName: viewModel.healthKit.dailyTrend.icon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(trendColor)
                            Text("NRS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .tracking(2)
                        }
                    }
                }
            }

            if viewModel.healthKit.isAuthorized {
                HStack(spacing: 10) {
                    HRVStatPill(
                        label: "HRV",
                        value: viewModel.healthKit.hrvValue > 0 ? String(format: "%.0fms", viewModel.healthKit.hrvValue) : "--",
                        icon: "waveform.path.ecg",
                        color: Theme.brandCyan
                    )
                    HRVStatPill(
                        label: "RHR",
                        value: viewModel.healthKit.restingHeartRate > 0 ? String(format: "%.0f", viewModel.healthKit.restingHeartRate) : "--",
                        icon: "heart.fill",
                        color: .red
                    )
                    HRVStatPill(
                        label: "BUFF",
                        value: viewModel.healthKit.arcadePhysicsBuff.isRecoveryMode ? "REST" : String(format: "%.2fx", viewModel.healthKit.arcadePhysicsBuff.speedMultiplier),
                        icon: "bolt.fill",
                        color: viewModel.healthKit.arcadePhysicsBuff.isRecoveryMode ? .orange : Theme.elitePurple
                    )
                }

                if viewModel.healthKit.weeklyHRVAverage > 0 {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("7D AVG")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Text(String(format: "%.0fms", viewModel.healthKit.weeklyHRVAverage))
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: viewModel.healthKit.dailyTrend.icon)
                                .font(.system(size: 9, weight: .bold))
                            Text(viewModel.healthKit.dailyTrend.rawValue)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(trendColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(trendColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                if viewModel.healthKit.arcadePhysicsBuff.isRecoveryMode {
                    HStack(spacing: 6) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 10))
                        Text("RECOVERY MODE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                        if viewModel.healthKit.recoveryEstimateHours > 0 {
                            Text("~\(Int(viewModel.healthKit.recoveryEstimateHours))h")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    if let syncDate = viewModel.healthKit.lastSyncDate {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8))
                            Text(syncDate, style: .relative)
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if viewModel.healthKit.autoRefreshEnabled {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.green)
                                .frame(width: 4, height: 4)
                            Text("AUTO")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.6))
                        }
                    }
                }
            } else {
                Button {
                    Task { await viewModel.connectHealthKit() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.clipboard")
                            .font(.system(size: 12, weight: .bold))
                        Text("CONNECT APPLE HEALTH")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.brandCyan)
                    .clipShape(.rect(cornerRadius: 12))
                }

                Text("Sync HRV & Heart Rate for automated Neural Drive")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var trendColor: Color {
        switch viewModel.healthKit.dailyTrend {
        case .improving: .green
        case .stable: Theme.brandCyan
        case .declining: .orange
        }
    }

    private var hrvGradeColor: Color {
        switch viewModel.healthKit.neuralReadinessGrade {
        case .elite: Theme.elitePurple
        case .primed: Theme.brandBlue
        case .ready: Theme.foundationGreen
        case .recovering: .orange
        }
    }

    private var coachAndBlueprintsRow: some View {
        HStack(spacing: 12) {
            Button {
                showCoach = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.brandBlue.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.brandBlue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("COACH")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("Exercises & Critiques")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.brandBlue.opacity(0.12), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                showBlueprints = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.elitePurple.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "map.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.elitePurple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BLUEPRINTS")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("Plans & Guides")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.elitePurple.opacity(0.12), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricCard(title: simpleMode ? SimpleModeLabels.prqScore(simpleMode) : "RANKED PRQ", value: String(format: "%.1f", viewModel.competitivePRQScore), icon: "brain.head.profile.fill", color: Theme.brandBlue)
            MetricCard(title: SimpleModeLabels.efficiency(simpleMode), value: String(format: "%.0f%%", effectiveMetrics.efficiencyScore), icon: "bolt.fill", color: .orange)
            MetricCard(title: SimpleModeLabels.readiness(simpleMode), value: String(format: "%.0f%%", effectiveMetrics.readinessScore), icon: "heart.fill", color: .red)
            MetricCard(title: SimpleModeLabels.evolutionShards(simpleMode), value: "\(viewModel.profile.evolutionShards)", icon: "diamond.fill", color: Theme.brandCyan)
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK START")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            ForEach(viewModel.tracks) { track in
                Button {
                    viewModel.selectedTrack = track
                } label: {
                    TrackQuickStartRow(track: track)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var parentalOverviewSection: some View {
        ParentalOverviewCard(
            prqScore: viewModel.profile.metrics.prqScore,
            readinessScore: viewModel.profile.metrics.readinessScore,
            evolutionShards: viewModel.profile.evolutionShards
        )
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ACTIVITY")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            if viewModel.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.brandBlue.opacity(0.4))
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Start a track to begin your evolution")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(viewModel.sessions.suffix(3).reversed()) { session in
                    SessionRow(session: session, tracks: viewModel.tracks)
                }
            }
        }
    }
}

struct AttributeImpactRow: View {
    let attribute: String
    let joint: String
    let status: JointStatus
    let modifier: String

    private var statusColor: Color {
        switch status {
        case .optimal: Theme.brandCyan
        case .moderate: .orange
        case .deficit: .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(attribute.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("\(joint) → \(status.label)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(modifier)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(statusColor.opacity(0.04))
        )
    }
}

struct TrackQuickStartRow: View {
    let track: CurriculumTrack

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.difficultyColor(track.difficulty).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: trackIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.difficultyColor(track.difficulty))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name.uppercased())
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.white)

                Text(track.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private var trackIcon: String {
        switch track.difficulty {
        case .foundation: "1.circle.fill"
        case .flight: "2.circle.fill"
        case .elite: "3.circle.fill"
        }
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    let tracks: [CurriculumTrack]

    private var trackName: String {
        tracks.first(where: { $0.id == session.trackId })?.name ?? "Workout"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trackName.uppercased())
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(session.exercisesCompleted)/\(session.totalExercises) exercises")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(session.shardsEarned)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)

                Text(session.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
    }
}
