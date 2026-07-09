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
            VStack(spacing: FELDesign.Space.lg) {
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
                // Freestyle Dunk Practice slot removed per direction — the dunk
                // gameplay lives in the Play tab's 3D Dunk Contest mode only.
                neuralDriveCard
                hrvReadinessCard
                metricsGrid
                CreatorCardBoostView(viewModel: viewModel)
                coachAndBlueprintsRow
                parentalOverviewSection
                quickStartSection
                recentActivitySection
            }
            .padding(.horizontal, FELDesign.Space.md)
            .padding(.bottom, FELDesign.Space.xl)
        }
        .scrollIndicators(.hidden)
        .background(FELDesign.Colors.ink)
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
                        navigateToArenaGame = true
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToArenaGame) {
            if let mode = pendingArenaMode {
                FELModeLauncherView(viewModel: viewModel, gameMode: mode, sessionReadiness: sessionReadiness)
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
            .presentationBackground(FELDesign.Colors.ink)
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

    // MARK: - Studio Entry Rows

    /// Shared compact entry row for lab studios — one accent, one container, low element count.
    private func studioEntryRow(
        icon: String,
        title: String,
        badge: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: FELDesign.Space.sm) {
                ZStack {
                    Circle()
                        .fill(FELDesign.Colors.cyan.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(FELDesign.Typography.body.weight(.semibold))
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    HStack(spacing: FELDesign.Space.xs) {
                        Text(title)
                            .font(FELDesign.Typography.label)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                        FELPreviewLabel(text: badge)
                    }
                    Text(subtitle)
                        .font(FELDesign.Typography.caption)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
            }
            .felCard()
        }
        .buttonStyle(.plain)
    }

    private var mocapStudioEntry: some View {
        studioEntryRow(
            icon: "figure.walk.motion",
            title: "3D MOCAP STUDIO",
            badge: "BETA",
            subtitle: "Markerless 3D motion capture · Real-time retargeting"
        ) {
            showMoCapStudio = true
        }
    }

    private var faceScanStudioEntry: some View {
        studioEntryRow(
            icon: "faceid",
            title: "FACE SCAN STUDIO",
            badge: "LIVE LINK",
            subtitle: "Markerless 3D face scan · Real-time facial expression tracking"
        ) {
            showFaceScanStudio = true
        }
    }

    private var bodyIQEducationEntry: some View {
        studioEntryRow(
            icon: "figure.flexibility",
            title: "BODY IQ LAB",
            badge: FELPremiumCopy.Preview.education,
            subtitle: "Movement Snacks · Bonds Standard prescriptions"
        ) {
            showBodyIQLab = true
        }
    }

    private var creatorHubEntry: some View {
        studioEntryRow(
            icon: "video.badge.plus",
            title: "MOCAP CREATOR HUB",
            badge: "MINTING",
            subtitle: "Mint custom cards · Track shard royalties"
        ) {
            showCreatorHub = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
            FELMicroLabel(text: "Venice Beach", color: FELDesign.Colors.cyan)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            Text("Lab")
                .font(FELDesign.Typography.display)
                .foregroundStyle(FELDesign.Colors.textPrimary)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

            HStack(spacing: FELDesign.Space.xs) {
                Circle()
                    .fill(FELDesign.Colors.cyan)
                    .frame(width: 6, height: 6)

                Text(SimpleModeLabels.neuralEngine(simpleMode))
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.textSecondary)

                Spacer()

                NeuralAuraBadge(auraLevel: viewModel.arcadePhysics.auraLevel)
            }
            .padding(.top, FELDesign.Space.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, FELDesign.Space.xs)
    }

    private var tierBanner: some View {
        HStack(spacing: FELDesign.Space.sm) {
            PRQTierBadge(tier: viewModel.userPRQTier, prq: viewModel.competitivePRQScore)

            Spacer()

            if viewModel.globalLeaderboard.userGlobalRank > 0 {
                HStack(spacing: FELDesign.Space.xxs) {
                    Image(systemName: "globe")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.cyan)
                    Text("#\(viewModel.globalLeaderboard.userGlobalRank)")
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                    FELMicroLabel(text: "Global")
                }
                .padding(.horizontal, FELDesign.Space.sm)
                .padding(.vertical, FELDesign.Space.xxs)
                .background(FELDesign.Colors.surfaceRaised)
                .clipShape(.rect(cornerRadius: FELDesign.Radius.sm))
            }

            if viewModel.arcadePhysics.neuralBurstActive {
                HStack(spacing: FELDesign.Space.xxs) {
                    Image(systemName: "bolt.fill")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.cyan)
                    Text("1.5x")
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
                .padding(.horizontal, FELDesign.Space.xs)
                .padding(.vertical, FELDesign.Space.xxs)
                .background(FELDesign.Colors.cyan.opacity(0.10))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Biomechanics

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
                VStack(spacing: FELDesign.Space.lg) {
                    if let audit = viewModel.biomechanicsAudit {
                        BiomechanicsDashboardCard(audit: audit)

                        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
                            FELMicroLabel(text: "Joint Analysis", color: FELDesign.Colors.cyan)

                            BiomechanicsOverlayView(audit: audit)
                                .frame(height: 350)
                                .clipShape(.rect(cornerRadius: FELDesign.Radius.lg))
                                .background(
                                    RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                                        .fill(FELDesign.Colors.surface)
                                )
                        }

                        attributeImpactSection(audit: audit)
                    }
                }
                .padding(FELDesign.Space.md)
            }
            .background(FELDesign.Colors.ink)
            .navigationTitle("Biomechanics Audit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showBiomechanicsDetail = false }
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(FELDesign.Colors.ink)
    }

    private func attributeImpactSection(audit: BiomechanicsAudit) -> some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Attribute Impact", color: FELDesign.Colors.cyan)

            VStack(spacing: FELDesign.Space.xs) {
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
        .felCard()
    }

    // MARK: - Global Arena

    private var globalArenaCard: some View {
        Button {
            guard let mode = GameModeRegistry.resolvedLastSelectedMode() else { return }
            pendingArenaMode = mode
            showGlobalMatchmaking = true
        } label: {
            HStack(spacing: FELDesign.Space.sm) {
                ZStack {
                    Circle()
                        .fill(FELDesign.Colors.cyan.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "globe")
                        .font(FELDesign.Typography.body.weight(.semibold))
                        .foregroundStyle(FELDesign.Colors.cyan)
                }

                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    Text("GLOBAL ARENA")
                        .font(FELDesign.Typography.label)
                        .foregroundStyle(FELDesign.Colors.textPrimary)

                    if let last = GameModeRegistry.resolvedLastSelectedMode() {
                        HStack(spacing: FELDesign.Space.xs) {
                            HStack(spacing: FELDesign.Space.xxs) {
                                Circle()
                                    .fill(FELDesign.Colors.success)
                                    .frame(width: 5, height: 5)
                                Text("\(viewModel.globalLeaderboard.onlinePlayerCount) online")
                                    .font(FELDesign.Typography.statSmall)
                                    .foregroundStyle(FELDesign.Colors.textSecondary)
                            }

                            Text(last.name.uppercased())
                                .font(FELDesign.Typography.statSmall)
                                .foregroundStyle(FELDesign.Colors.textTertiary)
                        }
                    } else {
                        Text("Choose a mode in Arena tab first")
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.cyan)
            }
            .felCard()
        }
        .buttonStyle(.plain)
        .disabled(GameModeRegistry.resolvedLastSelectedMode() == nil)
        .opacity(GameModeRegistry.resolvedLastSelectedMode() == nil ? 0.55 : 1)
    }

    // MARK: - Court

    private var courtSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: "Freestyle Dunk Practice", color: FELDesign.Colors.cyan)

                    Text("Venice Beach Court")
                        .font(FELDesign.Typography.caption)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                }

                Spacer()

                HStack(spacing: FELDesign.Space.xs) {
                    NeuralAuraBadge(auraLevel: viewModel.arcadePhysics.auraLevel)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showCourtExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: showCourtExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(FELDesign.Typography.caption.weight(.semibold))
                            .foregroundStyle(FELDesign.Colors.cyan)
                            .padding(FELDesign.Space.xs)
                            .background(FELDesign.Colors.surfaceRaised)
                            .clipShape(Circle())
                    }
                }
            }

            ZStack {
                if courtLoaded {
                    GameSceneHostView(gameMode: .basketballDunkContest3D, neuralDrive: viewModel.profile.metrics.neuralDrive)
                        .frame(height: showCourtExpanded ? 420 : 280)
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                                .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                        )
                        .overlay(alignment: .topTrailing) {
                            freestyleDunkPhaseIndicator
                        }
                        .overlay(alignment: .bottom) {
                            freestyleScoringOverlay
                        }
                        .overlay(alignment: .topLeading) {
                            Text("NEURAL DRIVE \(Int(viewModel.profile.metrics.neuralDrive))%")
                                .font(FELDesign.Typography.statSmall)
                                .foregroundStyle(FELDesign.Colors.cyan)
                                .padding(FELDesign.Space.xs)
                        }
                        .overlay(alignment: .bottom) {
                            Text("HOLD X TO GATHER")
                                .font(FELDesign.Typography.statSmall)
                                .foregroundStyle(FELDesign.Colors.textSecondary)
                                .padding(.bottom, FELDesign.Space.xl + FELDesign.Space.xs)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                        .fill(FELDesign.Colors.surfaceRaised)
                        .frame(height: 280)
                        .overlay {
                            VStack(spacing: FELDesign.Space.sm) {
                                ProgressView()
                                    .tint(FELDesign.Colors.cyan)
                                FELMicroLabel(text: "Loading Court")
                            }
                        }
                }

                if dunkFlash {
                    RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                        .fill(FELDesign.Colors.glow(FELDesign.Colors.cyan, 0.15))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .offset(x: freestyleScreenShake)

            freestyleDunkControls
        }
        .felCard()
    }

    // MARK: - Freestyle Dunk Engine Controls

    @ViewBuilder
    private var freestyleDunkControls: some View {
        switch freestyleDunk.phase {
        case .idle:
            VStack(spacing: FELDesign.Space.xs) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FELDesign.Space.xs) {
                        ForEach(DunkTrickSlot.allCases, id: \.rawValue) { trick in
                            Button {
                                withAnimation(.spring(response: 0.2)) {
                                    freestyleDunk.selectedTrick = trick
                                }
                            } label: {
                                VStack(spacing: FELDesign.Space.xxs) {
                                    Image(systemName: trick.icon)
                                        .font(FELDesign.Typography.caption.weight(.semibold))
                                    Text(trick.rawValue)
                                        .font(FELDesign.Typography.statSmall)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                    HStack(spacing: 1) {
                                        ForEach(0..<5, id: \.self) { i in
                                            Circle()
                                                .fill(Double(i) / 5.0 < trick.complexity ? FELDesign.Colors.cyan : FELDesign.Colors.hairline)
                                                .frame(width: 3, height: 3)
                                        }
                                    }
                                }
                                .foregroundStyle(freestyleDunk.selectedTrick == trick ? FELDesign.Colors.ink : FELDesign.Colors.textPrimary)
                                .frame(width: 64, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                        .fill(freestyleDunk.selectedTrick == trick ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                                .stroke(freestyleDunk.selectedTrick == trick ? FELDesign.Colors.cyan : FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
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
                    HStack(spacing: FELDesign.Space.xs) {
                        Image(systemName: "figure.run")
                            .font(FELDesign.Typography.label)
                        Text("START APPROACH")
                            .font(FELDesign.Typography.label)
                    }
                    .foregroundStyle(FELDesign.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(FELDesign.Colors.cyan)
                    .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
                }
            }

        case .approach:
            VStack(spacing: FELDesign.Space.xs) {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "bolt.fill")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.cyan)
                    FELMicroLabel(text: "Hold to Sprint", color: FELDesign.Colors.textPrimary)
                    Spacer()
                    Text("\(Int(freestyleDunk.sprintCharge * 100))%")
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.cyan)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm / 2)
                            .fill(FELDesign.Colors.ink)
                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm / 2)
                            .fill(FELDesign.Colors.cyan)
                            .frame(width: geo.size.width * freestyleDunk.sprintCharge)
                            .animation(.linear(duration: 0.05), value: freestyleDunk.sprintCharge)
                    }
                }
                .frame(height: 12)
                .clipShape(.rect(cornerRadius: FELDesign.Radius.sm / 2))
                .overlay(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.sm / 2)
                        .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                )

                Button {
                    releaseFreestyleSprint()
                } label: {
                    Text("RELEASE TO LAUNCH")
                        .font(FELDesign.Typography.label)
                        .foregroundStyle(FELDesign.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(FELDesign.Colors.cyan)
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
                }
            }

        case .launch:
            VStack(spacing: FELDesign.Space.xs) {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.success)
                    FELMicroLabel(text: "Tap to Jump", color: FELDesign.Colors.textPrimary)
                    Spacer()
                }

                freestyleTimingBar(
                    value: freestyleDunk.launchTiming,
                    greenZone: freestyleDunk.launchGreenZone,
                    accentColor: FELDesign.Colors.success
                )

                Button {
                    confirmFreestyleLaunch()
                } label: {
                    Text("JUMP!")
                        .font(FELDesign.Typography.label)
                        .foregroundStyle(FELDesign.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            freestyleDunk.launchGreenZone.contains(freestyleDunk.launchTiming)
                                ? FELDesign.Colors.success
                                : FELDesign.Colors.success.opacity(0.4)
                        )
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
                }
            }

        case .airborne:
            VStack(spacing: FELDesign.Space.xs) {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "figure.highintensity.intervaltraining")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.cyan)
                    FELMicroLabel(text: freestyleDunk.selectedTrick.rawValue, color: FELDesign.Colors.textPrimary)
                    Spacer()
                    Text("\(Int(freestyleDunk.completedRotation * 100))%")
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(freestyleDunk.completedRotation >= 0.9 ? FELDesign.Colors.success : FELDesign.Colors.cyan)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm / 2)
                            .fill(FELDesign.Colors.ink)
                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm / 2)
                            .fill(freestyleDunk.completedRotation >= 0.9 ? FELDesign.Colors.success : FELDesign.Colors.cyan)
                            .frame(width: geo.size.width * min(1, freestyleDunk.completedRotation))
                            .animation(.linear(duration: 0.05), value: freestyleDunk.completedRotation)
                    }
                }
                .frame(height: 8)
                .clipShape(.rect(cornerRadius: FELDesign.Radius.sm / 2))

                HStack(spacing: FELDesign.Space.xs) {
                    Button {
                        withAnimation(.spring(response: 0.15)) {
                            freestyleDunk.isRotating.toggle()
                        }
                    } label: {
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: freestyleDunk.isRotating ? "arrow.trianglehead.2.clockwise.rotate.90" : "play.fill")
                                .font(FELDesign.Typography.caption.weight(.semibold))
                            Text(freestyleDunk.isRotating ? "ROTATING" : "SPIN")
                                .font(FELDesign.Typography.caption)
                        }
                        .foregroundStyle(freestyleDunk.isRotating ? FELDesign.Colors.ink : FELDesign.Colors.cyan)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            freestyleDunk.isRotating ? AnyShapeStyle(FELDesign.Colors.cyan) : AnyShapeStyle(FELDesign.Colors.cyan.opacity(0.15))
                        )
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.sm))
                    }

                    Button {
                        confirmFreestyleLanding()
                    } label: {
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(FELDesign.Typography.caption.weight(.semibold))
                            Text("SLAM!")
                                .font(FELDesign.Typography.caption)
                        }
                        .foregroundStyle(FELDesign.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(FELDesign.Colors.cyan)
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.sm))
                    }
                }
            }

        case .landing:
            VStack(spacing: FELDesign.Space.xs) {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.success)
                    FELMicroLabel(text: "Stick the Landing!", color: FELDesign.Colors.textPrimary)
                    Spacer()
                }

                freestyleTimingBar(
                    value: freestyleDunk.landingTiming,
                    greenZone: freestyleDunk.landingGreenZone,
                    accentColor: FELDesign.Colors.success
                )

                Button {
                    confirmFreestyleLanding()
                } label: {
                    Text("LAND!")
                        .font(FELDesign.Typography.label)
                        .foregroundStyle(FELDesign.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            freestyleDunk.landingGreenZone.contains(freestyleDunk.landingTiming)
                                ? FELDesign.Colors.success
                                : FELDesign.Colors.success.opacity(0.4)
                        )
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
                }
            }

        case .scored:
            EmptyView()
        }
    }

    private func freestyleTimingBar(value: Double, greenZone: ClosedRange<Double>, accentColor: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: FELDesign.Radius.sm / 2)
                    .fill(FELDesign.Colors.ink)

                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor.opacity(0.25))
                    .frame(
                        width: geo.size.width * (greenZone.upperBound - greenZone.lowerBound)
                    )
                    .offset(x: geo.size.width * greenZone.lowerBound)

                RoundedRectangle(cornerRadius: 2)
                    .fill(greenZone.contains(value) ? accentColor : FELDesign.Colors.danger)
                    .frame(width: 4)
                    .offset(x: geo.size.width * value - 2)
                    .animation(.linear(duration: 0.03), value: value)
            }
        }
        .frame(height: 16)
        .clipShape(.rect(cornerRadius: FELDesign.Radius.sm / 2))
        .overlay(
            RoundedRectangle(cornerRadius: FELDesign.Radius.sm / 2)
                .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
        )
    }

    @ViewBuilder
    private var freestyleDunkPhaseIndicator: some View {
        if freestyleDunk.phase != .idle && freestyleDunk.phase != .scored {
            VStack(spacing: FELDesign.Space.xxs) {
                Text(freestylePhaseLabel)
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(freestylePhaseColor)
                    .tracking(1)
                if freestyleDunk.phase == .airborne {
                    Text(String(format: "HEIGHT: %.0f%%", freestyleDunk.jumpHeight * 100))
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                }
            }
            .padding(FELDesign.Space.xs)
            .background(
                RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                    .fill(FELDesign.Colors.ink.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                            .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                    )
            )
            .padding(FELDesign.Space.sm)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var freestyleScoringOverlay: some View {
        if let scores = freestyleJudgeScores {
            VStack(spacing: FELDesign.Space.xxs) {
                if !freestyleCrowdMessage.isEmpty {
                    Text(freestyleCrowdMessage)
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.cyan)
                        .tracking(1)
                }
                HStack(spacing: FELDesign.Space.sm) {
                    ForEach([scores.0, scores.1, scores.2], id: \.self) { s in
                        Text("\(s)")
                            .font(FELDesign.Typography.stat)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                    .fill(FELDesign.Colors.surfaceRaised)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                            .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                                    )
                            )
                    }
                }
            }
            .padding(FELDesign.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                    .fill(FELDesign.Colors.ink.opacity(0.75))
            )
            .padding(.bottom, FELDesign.Space.sm)
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
        case .approach: return FELDesign.Colors.cyan
        case .launch: return FELDesign.Colors.success
        case .airborne: return FELDesign.Colors.cyan
        case .landing: return FELDesign.Colors.success
        default: return FELDesign.Colors.textPrimary
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

    // MARK: - System Scan

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
            VStack(spacing: FELDesign.Space.md) {
                ZStack {
                    Circle()
                        .fill(FELDesign.Colors.cyan.opacity(0.08))
                        .frame(width: 64, height: 64)

                    Image(systemName: "figure.basketball")
                        .font(FELDesign.Typography.title)
                        .foregroundStyle(FELDesign.Colors.cyan)
                }

                VStack(spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: "System Scan", color: FELDesign.Colors.cyan)

                    Text("Upload a jump video to get your PRQ")
                        .font(FELDesign.Typography.body)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                }

                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "video.badge.plus")
                        .font(FELDesign.Typography.caption.weight(.semibold))
                    Text("START SCAN")
                        .font(FELDesign.Typography.label)
                }
                .foregroundStyle(FELDesign.Colors.ink)
                .padding(.horizontal, FELDesign.Space.lg)
                .padding(.vertical, FELDesign.Space.sm)
                .background(FELDesign.Colors.cyan)
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .felCard(padding: FELDesign.Space.lg)
        }
        .buttonStyle(.plain)
    }

    private func scanDataDashboard(_ scan: SystemScanResult) -> some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: "Scan Data", color: FELDesign.Colors.cyan)

                    if !scan.commitsCompetitiveMetrics {
                        Text("Preview PRQ — not applied to ranked PRQ or Body IQ prescriptions")
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textTertiary)
                    }

                    Text(scan.movementGrade)
                        .font(FELDesign.Typography.heading)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                }

                Spacer()

                HStack(spacing: FELDesign.Space.xs) {
                    Button {
                        showCharacterEditor = true
                    } label: {
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                            Text("CUSTOMIZE")
                        }
                        .font(FELDesign.Typography.statSmall)
                        .padding(.horizontal, FELDesign.Space.sm)
                        .padding(.vertical, FELDesign.Space.xxs)
                        .background(FELDesign.Colors.surfaceRaised)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline))
                    }

                    Button {
                        showSystemScan = true
                    } label: {
                        Text("RESCAN")
                            .font(FELDesign.Typography.statSmall)
                            .padding(.horizontal, FELDesign.Space.sm)
                            .padding(.vertical, FELDesign.Space.xxs)
                            .background(FELDesign.Colors.cyan.opacity(0.12))
                            .foregroundStyle(FELDesign.Colors.cyan)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: FELDesign.Space.sm) {
                ScanStatPill(label: "PRQ", value: String(format: "%.1f", scan.prqScore), color: FELDesign.Colors.cyan)
                ScanStatPill(label: "VERTICAL", value: String(format: "%.1f\"", scan.verticalEstimateInches), color: FELDesign.Colors.cyan)
                ScanStatPill(label: "FLIGHT", value: String(format: "%.2fs", scan.flightTimeSeconds), color: FELDesign.Colors.cyan)
            }

            if let firstNote = scan.notes.first {
                HStack(alignment: .top, spacing: FELDesign.Space.xs) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(FELDesign.Typography.caption)
                        .foregroundStyle(FELDesign.Colors.cyan)
                        .padding(.top, 2)

                    Text(firstNote)
                        .font(FELDesign.Typography.caption)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "clock.fill")
                    .font(FELDesign.Typography.statSmall)
                Text(scan.date, style: .relative)
                    .font(FELDesign.Typography.statSmall)
                Text("Recommended: \(scan.recommendedTrack)")
                    .font(FELDesign.Typography.statSmall)
            }
            .foregroundStyle(FELDesign.Colors.textTertiary)
        }
        .felCard()
    }

    // MARK: - Athlete Profile

    @ViewBuilder
    private var athleteProfileBanner: some View {
        if viewModel.profile.sport != nil {
            HStack(spacing: FELDesign.Space.sm) {
                Image(systemName: sportIcon(viewModel.profile.sport ?? ""))
                    .font(FELDesign.Typography.body.weight(.semibold))
                    .foregroundStyle(FELDesign.Colors.cyan)
                    .frame(width: 40, height: 40)
                    .background(FELDesign.Colors.cyan.opacity(0.10))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    Text(viewModel.profile.sport?.uppercased() ?? "")
                        .font(FELDesign.Typography.label)
                        .foregroundStyle(FELDesign.Colors.textPrimary)

                    HStack(spacing: FELDesign.Space.xs) {
                        if let age = viewModel.profile.age {
                            Text("Age \(age)")
                        }
                        if let goal = viewModel.profile.goal {
                            Text(goal)
                        }
                    }
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                }

                Spacer()
            }
            .felCard(padding: FELDesign.Space.sm)
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

    // MARK: - Neural Drive

    private var neuralDriveCard: some View {
        VStack(spacing: FELDesign.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: SimpleModeLabels.neuralDrive(simpleMode), color: FELDesign.Colors.cyan)

                    Text("\(Int(effectiveMetrics.neuralDrive))%")
                        .font(FELDesign.Typography.display)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                }

                Spacer()

                NeuralDriveOrb(value: effectiveMetrics.neuralDrive)
                    .frame(width: 80, height: 80)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FELDesign.Colors.surfaceRaised)

                    Capsule()
                        .fill(FELDesign.Colors.cyan)
                        .frame(width: geo.size.width * min(effectiveMetrics.neuralDrive, 100) / 100)
                }
            }
            .frame(height: 6)

            if viewModel.arcadePhysics.neuralBurstActive {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "bolt.fill")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.cyan)
                    Text("NEURAL BURST ACTIVE — 1.5x SCORING")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.cyan)
                        .tracking(1)
                }
                .padding(.horizontal, FELDesign.Space.sm)
                .padding(.vertical, FELDesign.Space.xxs)
                .background(FELDesign.Colors.cyan.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .felCard(padding: FELDesign.Space.lg)
    }

    // MARK: - HRV Readiness

    private var hrvReadinessCard: some View {
        VStack(spacing: FELDesign.Space.sm) {
            HStack {
                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: "Neural Readiness", color: FELDesign.Colors.cyan)

                    Text(viewModel.healthKit.neuralReadinessGrade.rawValue)
                        .font(FELDesign.Typography.heading)
                        .foregroundStyle(hrvGradeColor)
                }

                Spacer()

                if viewModel.healthKit.isAuthorized {
                    VStack(alignment: .trailing, spacing: FELDesign.Space.xxs) {
                        Text(String(format: "%.0f", viewModel.healthKit.neuralReadinessScore))
                            .font(FELDesign.Typography.statLarge)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: viewModel.healthKit.dailyTrend.icon)
                                .font(FELDesign.Typography.statSmall)
                                .foregroundStyle(trendColor)
                            FELMicroLabel(text: "NRS")
                        }
                    }
                }
            }

            if viewModel.healthKit.isAuthorized {
                HStack(spacing: FELDesign.Space.sm) {
                    HRVStatPill(
                        label: "HRV",
                        value: viewModel.healthKit.hrvValue > 0 ? String(format: "%.0fms", viewModel.healthKit.hrvValue) : "--",
                        icon: "waveform.path.ecg",
                        color: FELDesign.Colors.cyan
                    )
                    HRVStatPill(
                        label: "RHR",
                        value: viewModel.healthKit.restingHeartRate > 0 ? String(format: "%.0f", viewModel.healthKit.restingHeartRate) : "--",
                        icon: "heart.fill",
                        color: FELDesign.Colors.cyan
                    )
                    HRVStatPill(
                        label: "BUFF",
                        value: viewModel.healthKit.arcadePhysicsBuff.isRecoveryMode ? "REST" : String(format: "%.2fx", viewModel.healthKit.arcadePhysicsBuff.speedMultiplier),
                        icon: "bolt.fill",
                        color: viewModel.healthKit.arcadePhysicsBuff.isRecoveryMode ? FELDesign.Colors.danger : FELDesign.Colors.cyan
                    )
                }

                if viewModel.healthKit.weeklyHRVAverage > 0 {
                    HStack(spacing: FELDesign.Space.sm) {
                        HStack(spacing: FELDesign.Space.xxs) {
                            FELMicroLabel(text: "7D Avg")
                            Text(String(format: "%.0fms", viewModel.healthKit.weeklyHRVAverage))
                                .font(FELDesign.Typography.statSmall)
                                .foregroundStyle(FELDesign.Colors.textPrimary)
                        }

                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: viewModel.healthKit.dailyTrend.icon)
                                .font(FELDesign.Typography.statSmall)
                            Text(viewModel.healthKit.dailyTrend.rawValue)
                                .font(FELDesign.Typography.statSmall)
                        }
                        .foregroundStyle(trendColor)
                        .padding(.horizontal, FELDesign.Space.xs)
                        .padding(.vertical, FELDesign.Space.xxs)
                        .background(trendColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                if viewModel.healthKit.arcadePhysicsBuff.isRecoveryMode {
                    HStack(spacing: FELDesign.Space.xs) {
                        Image(systemName: "bed.double.fill")
                            .font(FELDesign.Typography.statSmall)
                        Text("RECOVERY MODE")
                            .font(FELDesign.Typography.statSmall)
                        if viewModel.healthKit.recoveryEstimateHours > 0 {
                            Text("~\(Int(viewModel.healthKit.recoveryEstimateHours))h")
                                .font(FELDesign.Typography.statSmall)
                        }
                    }
                    .foregroundStyle(FELDesign.Colors.danger)
                    .padding(.horizontal, FELDesign.Space.sm)
                    .padding(.vertical, FELDesign.Space.xxs)
                    .background(FELDesign.Colors.danger.opacity(0.08))
                    .clipShape(Capsule())
                }

                HStack(spacing: FELDesign.Space.xs) {
                    if let syncDate = viewModel.healthKit.lastSyncDate {
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(FELDesign.Typography.statSmall)
                            Text(syncDate, style: .relative)
                                .font(FELDesign.Typography.statSmall)
                        }
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                    }

                    Spacer()

                    if viewModel.healthKit.autoRefreshEnabled {
                        HStack(spacing: FELDesign.Space.xxs) {
                            Circle()
                                .fill(FELDesign.Colors.success)
                                .frame(width: 4, height: 4)
                            FELMicroLabel(text: "Auto")
                        }
                    }
                }
            } else {
                Button {
                    Task { await viewModel.connectHealthKit() }
                } label: {
                    HStack(spacing: FELDesign.Space.xs) {
                        Image(systemName: "heart.text.clipboard")
                            .font(FELDesign.Typography.caption.weight(.semibold))
                        Text("CONNECT APPLE HEALTH")
                            .font(FELDesign.Typography.label)
                    }
                    .foregroundStyle(FELDesign.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FELDesign.Space.sm)
                    .background(FELDesign.Colors.cyan)
                    .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
                }

                Text("Sync HRV & Heart Rate for automated Neural Drive")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
            }
        }
        .felCard()
    }

    private var trendColor: Color {
        switch viewModel.healthKit.dailyTrend {
        case .improving: FELDesign.Colors.success
        case .stable: FELDesign.Colors.cyan
        case .declining: FELDesign.Colors.danger
        }
    }

    private var hrvGradeColor: Color {
        switch viewModel.healthKit.neuralReadinessGrade {
        case .elite: FELDesign.Colors.purple
        case .primed: FELDesign.Colors.cyan
        case .ready: FELDesign.Colors.success
        case .recovering: FELDesign.Colors.danger
        }
    }

    // MARK: - Coach & Blueprints

    private var coachAndBlueprintsRow: some View {
        HStack(spacing: FELDesign.Space.sm) {
            Button {
                showCoach = true
            } label: {
                HStack(spacing: FELDesign.Space.sm) {
                    ZStack {
                        Circle()
                            .fill(FELDesign.Colors.cyan.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(FELDesign.Typography.label)
                            .foregroundStyle(FELDesign.Colors.cyan)
                    }
                    VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                        Text("COACH")
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                        Text("Exercises & Critiques")
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                }
                .felCard(padding: FELDesign.Space.sm)
            }
            .buttonStyle(.plain)

            Button {
                showBlueprints = true
            } label: {
                HStack(spacing: FELDesign.Space.sm) {
                    ZStack {
                        Circle()
                            .fill(FELDesign.Colors.cyan.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "map.fill")
                            .font(FELDesign.Typography.label)
                            .foregroundStyle(FELDesign.Colors.cyan)
                    }
                    VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                        Text("BLUEPRINTS")
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                        Text("Plans & Guides")
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                }
                .felCard(padding: FELDesign.Space.sm)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Metrics & Lists

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: FELDesign.Space.sm), GridItem(.flexible(), spacing: FELDesign.Space.sm)], spacing: FELDesign.Space.sm) {
            MetricCard(title: simpleMode ? SimpleModeLabels.prqScore(simpleMode) : "RANKED PRQ", value: String(format: "%.1f", viewModel.competitivePRQScore), icon: "brain.head.profile.fill", color: FELDesign.Colors.cyan)
            MetricCard(title: SimpleModeLabels.efficiency(simpleMode), value: String(format: "%.0f%%", effectiveMetrics.efficiencyScore), icon: "bolt.fill", color: FELDesign.Colors.cyan)
            MetricCard(title: SimpleModeLabels.readiness(simpleMode), value: String(format: "%.0f%%", effectiveMetrics.readinessScore), icon: "heart.fill", color: FELDesign.Colors.cyan)
            MetricCard(title: SimpleModeLabels.evolutionShards(simpleMode), value: "\(viewModel.profile.evolutionShards)", icon: "diamond.fill", color: FELDesign.Colors.cyan)
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Quick Start")

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
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Recent Activity")

            if viewModel.sessions.isEmpty {
                VStack(spacing: FELDesign.Space.sm) {
                    Image(systemName: "figure.run.circle")
                        .font(FELDesign.Typography.display)
                        .foregroundStyle(FELDesign.Colors.cyan.opacity(0.4))
                    Text("No workouts yet")
                        .font(FELDesign.Typography.body)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                    Text("Start a track to begin your evolution")
                        .font(FELDesign.Typography.caption)
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FELDesign.Space.xl)
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
        case .optimal: FELDesign.Colors.success
        case .moderate: FELDesign.Colors.textSecondary
        case .deficit: FELDesign.Colors.danger
        }
    }

    var body: some View {
        HStack(spacing: FELDesign.Space.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                Text(attribute.uppercased())
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                Text("\(joint) → \(status.label)")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }

            Spacer()

            Text(modifier)
                .font(FELDesign.Typography.stat)
                .foregroundStyle(statusColor)
        }
        .padding(FELDesign.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                .fill(FELDesign.Colors.surfaceRaised)
        )
    }
}

struct TrackQuickStartRow: View {
    let track: CurriculumTrack

    var body: some View {
        HStack(spacing: FELDesign.Space.sm) {
            ZStack {
                Circle()
                    .fill(FELDesign.Colors.cyan.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: trackIcon)
                    .font(FELDesign.Typography.body.weight(.semibold))
                    .foregroundStyle(FELDesign.Colors.cyan)
            }

            VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                Text(track.name.uppercased())
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.textPrimary)

                Text(track.subtitle)
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)
        }
        .felCard(padding: FELDesign.Space.sm)
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
        HStack(spacing: FELDesign.Space.sm) {
            VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                Text(trackName.uppercased())
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.textPrimary)

                Text("\(session.exercisesCompleted)/\(session.totalExercises) exercises")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: FELDesign.Space.xxs) {
                Text("+\(session.shardsEarned)")
                    .font(FELDesign.Typography.stat)
                    .foregroundStyle(FELDesign.Colors.cyan)

                Text(session.date, style: .relative)
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
            }
        }
        .felCard(padding: FELDesign.Space.sm)
    }
}
