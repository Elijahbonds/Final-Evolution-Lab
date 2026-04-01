import SwiftUI

struct LabView: View {
    let viewModel: LabViewModel

    @State private var appeared = false
    @State private var pulsePhase: CGFloat = 0
    @State private var dunkFlash: Bool = false
    @State private var showCourtExpanded: Bool = false
    @State private var courtLoaded: Bool = false
    @State private var showSystemScan: Bool = false
    @State private var showBiomechanicsDetail: Bool = false
    @State private var showGlobalMatchmaking: Bool = false
    @State private var showCoach: Bool = false
    @State private var showBlueprints: Bool = false
    @State private var showLiveEvents: Bool = false
    @State private var showMarketplace: Bool = false
    @State private var pendingArenaMode: GameMode?
    @State private var sessionReadiness: Double = 50
    @State private var navigateToArenaGame: Bool = false
    @State private var pendingArenaNavigationTask: Task<Void, Never>?
    @State private var courtLoadTask: Task<Void, Never>?
    @State private var freestyleDunk = DunkContestState()
    @State private var freestyleDunkTimer: Task<Void, Never>?
    @State private var freestyleActionMessageTask: Task<Void, Never>?
    @State private var freestyleFlashResetTask: Task<Void, Never>?
    @State private var freestyleRoundResetTask: Task<Void, Never>?
    @State private var freestyleShakeTask: Task<Void, Never>?
    @State private var healthKitConnectTask: Task<Void, Never>?
    @State private var isConnectingHealthKit = false
    @State private var freestyleLastAction: String = ""
    @State private var freestyleJudgeScores: (Int, Int, Int)?
    @State private var freestyleCrowdMessage: String = ""
    @State private var freestyleScreenShake: CGFloat = 0
    @State private var freestyleSceneActionNonce: UInt64 = 0
    @State private var freestyleSceneActionName: String = ""
    @Environment(\.simpleMode) private var simpleMode
    @AppStorage(FELArenaDiagnosticsPreference.userDefaultsKey) private var arenaDiagnosticsOverlayEnabled: Bool = false

    private var effectiveMetrics: PerformanceMetrics {
        viewModel.effectiveMetrics
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                tierBanner
                scanSection
                biomechanicsSection
                athleteProfileBanner
                globalArenaCard
                courtSection
                neuralDriveCard
                hrvReadinessCard
                metricsGrid
                CreatorCardBoostView(viewModel: viewModel)
                coachAndBlueprintsRow
                liveAndMarketRow
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
            courtLoadTask?.cancel()
            courtLoadTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4)) { courtLoaded = true }
            }
        }
        .sheet(isPresented: $showSystemScan) {
            SystemScanView(
                sport: viewModel.profile.sport,
                goal: viewModel.profile.goal
            ) { result in
                viewModel.applyScanResult(result)
            }
        }
        .sheet(isPresented: $showBiomechanicsDetail) {
            biomechanicsDetailSheet
        }
        .sheet(isPresented: $showGlobalMatchmaking) {
            if let mode = pendingArenaMode {
                MatchmakingView(viewModel: viewModel, gameMode: mode) { opponent, readiness in
                    sessionReadiness = readiness
                    showGlobalMatchmaking = false
                    scheduleArenaNavigation()
                }
            }
        }
        .navigationDestination(isPresented: $navigateToArenaGame) {
            if let mode = pendingArenaMode {
                GamePlayView(viewModel: viewModel, gameMode: mode, sessionReadiness: sessionReadiness)
            }
        }
        .navigationDestination(isPresented: $showCoach) {
            CoachView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showBlueprints) {
            BlueprintsView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showLiveEvents) {
            LiveEventsHubView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showMarketplace) {
            CreatorMarketplaceHubView(viewModel: viewModel)
        }
        .onDisappear {
            pendingArenaNavigationTask?.cancel()
            pendingArenaNavigationTask = nil
            courtLoadTask?.cancel()
            courtLoadTask = nil
            cancelFreestyleTasks()
            healthKitConnectTask?.cancel()
            healthKitConnectTask = nil
            isConnectingHealthKit = false
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Venice beach")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(1)
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
            PRQTierBadge(tier: viewModel.userPRQTier, prq: effectiveMetrics.prqScore)

            Spacer()

            if viewModel.globalLeaderboard.userGlobalRank > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.brandBlue)
                    Text("#\(viewModel.globalLeaderboard.userGlobalRank)")
                        .font(.system(.caption, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                    Text("Global")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
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
                            Text("Joint analysis")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(Theme.brandCyan)
                                .tracking(0.5)

                            if arenaDiagnosticsOverlayEnabled {
                                BiomechanicsOverlayView(audit: audit)
                                    .frame(height: 350)
                                    .clipShape(.rect(cornerRadius: 16))
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Theme.cardBackground)
                                    )
                            } else {
                                Text("Turn on Arena diagnostics in Settings to show the live skeleton overlay.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 24)
                            }
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
            Text("Attribute impact")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(0.5)

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
            pendingArenaMode = GameModeRegistry.all.first
            showGlobalMatchmaking = true
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
                    Text("Global arena")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.green)
                                .frame(width: 5, height: 5)
                            Text("\(viewModel.globalLeaderboard.onlinePlayerCount) online")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.7))
                        }

                        Text("PRQ-based matchmaking")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan.opacity(0.6))
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
    }

    private var courtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Freestyle dunk lab")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.brandBlue)
                    Text("Venice Beach Court · SceneKit preview")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Chain approach → sprint → jump timing → spin → slam. The mini arena mirrors your phase so the runner, camera, and dunks stay in sync.")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

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
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
            }

            ZStack {
                if courtLoaded {
                    GameSceneHostView(
                        gameMode: .basketballDunkContest,
                        neuralDrive: viewModel.profile.metrics.neuralDrive,
                        leftStickInput: freestyleLeftStick,
                        rightStickInput: freestyleRightStick,
                        isMidAir: freestyleDunk.phase == .airborne || freestyleDunk.phase == .launch,
                        isSpecialMove: freestyleDunk.phase == .airborne && (freestyleDunk.isRotating || freestyleDunk.completedRotation >= 0.9),
                        isSlowMotion: false,
                        sceneActionNonce: freestyleSceneActionNonce,
                        sceneActionName: freestyleSceneActionName
                    )
                        .frame(height: showCourtExpanded ? 420 : 280)
                        .clipShape(.rect(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [Theme.brandBlue.opacity(0.35), Theme.brandCyan.opacity(0.2), .clear],
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Neural drive \(Int(viewModel.profile.metrics.neuralDrive))%")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.brandCyan)
                                if freestyleDunk.phase == .approach {
                                    Text("Sprint charge drives the runner forward")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.65))
                                } else if freestyleDunk.phase == .launch {
                                    Text("Tap Jump on the green window")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.green.opacity(0.85))
                                }
                            }
                            .padding(10)
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
                                Text("Loading court")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.brandBlue.opacity(0.6))
                                    .tracking(0.5)
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
                        Text("Start approach")
                            .font(.system(size: 12, weight: .bold))
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
                    Text("Hold to sprint")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
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
                    Text("Release to launch")
                        .font(.system(size: 11, weight: .bold))
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
                    Text("Tap to jump")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
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
                    Text("Jump!")
                        .font(.system(size: 14, weight: .bold))
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
                        bumpFreestyleSceneAction("Style")
                        withAnimation(.spring(response: 0.15)) {
                            freestyleDunk.isRotating.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: freestyleDunk.isRotating ? "arrow.trianglehead.2.clockwise.rotate.90" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(freestyleDunk.isRotating ? "Rotating" : "Spin")
                                .font(.system(size: 10, weight: .bold))
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
                            Text("Slam!")
                                .font(.system(size: 11, weight: .bold))
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
                    Text("Stick the landing!")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
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
                    Text("Land!")
                        .font(.system(size: 14, weight: .bold))
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
                    Text(String(format: "Height: %.0f%%", freestyleDunk.jumpHeight * 100))
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
        case .approach: return "Sprinting"
        case .launch: return "Gather"
        case .airborne: return "In the air"
        case .landing: return "Landing"
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

    /// Drives SceneKit runner movement from the lab dunk state machine (no physical gamepad required).
    private var freestyleLeftStick: CGPoint {
        switch freestyleDunk.phase {
        case .approach:
            return CGPoint(x: 0, y: -CGFloat(min(1, freestyleDunk.sprintCharge * 1.2)))
        case .launch:
            return CGPoint(x: 0, y: -0.9)
        case .airborne:
            let wobble = CGFloat(freestyleDunk.completedRotation * 0.5 - 0.25)
            return CGPoint(x: freestyleDunk.isRotating ? wobble : 0, y: -0.4)
        case .landing:
            return CGPoint(x: 0, y: 0.35)
        default:
            return .zero
        }
    }

    private var freestyleRightStick: CGPoint {
        if freestyleDunk.phase == .airborne, freestyleDunk.isRotating {
            return CGPoint(x: 0.85, y: 0.1)
        }
        return .zero
    }

    private func bumpFreestyleSceneAction(_ name: String) {
        freestyleSceneActionNonce &+= 1
        freestyleSceneActionName = name
    }

    // MARK: - Freestyle Dunk Engine Logic

    private func startFreestyleApproach() {
        guard freestyleDunk.phase == .idle else { return }
        bumpFreestyleSceneAction("Approach")
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
        bumpFreestyleSceneAction("Sprint")
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
        bumpFreestyleSceneAction("Jump")
        freestyleDunkTimer?.cancel()
        let inGreen = freestyleDunk.launchGreenZone.contains(freestyleDunk.launchTiming)
        withAnimation(.spring(response: 0.2)) {
            freestyleDunk.confirmLaunch()
            freestyleLastAction = inGreen ? "Perfect launch!" : "Launched"
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

        freestyleActionMessageTask?.cancel()
        freestyleActionMessageTask = Task {
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            withAnimation {
                if freestyleLastAction == "Perfect launch!" || freestyleLastAction == "Launched" {
                    freestyleLastAction = ""
                }
            }
        }
    }

    private func confirmFreestyleLanding() {
        guard freestyleDunk.phase == .airborne || freestyleDunk.phase == .landing else { return }
        bumpFreestyleSceneAction("Dunk")
        freestyleDunkTimer?.cancel()
        withAnimation(.spring(response: 0.15)) {
            freestyleDunk.confirmLanding()
        }
        executeFreestyleScoring()
    }

    private func executeFreestyleScoring() {
        bumpFreestyleSceneAction("Finish")
        let prq = viewModel.effectiveMetrics.prqScore
        let burst = viewModel.arcadePhysics.neuralBurstActive
        let result = freestyleDunk.calculateDunkScore(prq: prq, neuralBurst: burst)

        withAnimation(.spring(response: 0.3)) {
            freestyleJudgeScores = (result.j1, result.j2, result.j3)
            freestyleCrowdMessage = result.message
        }

        let impactLevel = freestyleDunk.impactIntensity
        triggerFreestyleShake(intensity: 0.5 + impactLevel * 0.5)

        if result.total >= 138 {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { dunkFlash = true }
            freestyleFlashResetTask?.cancel()
            freestyleFlashResetTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dunkFlash = false }
            }
        }

        freestyleRoundResetTask?.cancel()
        freestyleRoundResetTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
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
        freestyleShakeTask?.cancel()
        freestyleShakeTask = Task {
            for _ in 0..<4 {
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.03)) {
                    freestyleScreenShake = CGFloat.random(in: -amplitude...amplitude)
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.1)) {
                freestyleScreenShake = 0
            }
        }
    }

    private func cancelFreestyleTasks() {
        freestyleDunkTimer?.cancel()
        freestyleDunkTimer = nil
        freestyleActionMessageTask?.cancel()
        freestyleActionMessageTask = nil
        freestyleFlashResetTask?.cancel()
        freestyleFlashResetTask = nil
        freestyleRoundResetTask?.cancel()
        freestyleRoundResetTask = nil
        freestyleShakeTask?.cancel()
        freestyleShakeTask = nil
    }

    private func scheduleArenaNavigation() {
        pendingArenaNavigationTask?.cancel()
        pendingArenaNavigationTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                navigateToArenaGame = true
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
                    Text("System scan")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(0.5)

                    Text("Upload a jump video to get your PRQ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Start scan")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
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
                    Text("Scan data")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(0.5)

                    Text(scan.movementGrade)
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    showSystemScan = true
                } label: {
                    Text("Rescan")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(minHeight: 44)
                        .background(Theme.brandCyan.opacity(0.12))
                        .foregroundStyle(Theme.brandCyan)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                ScanStatPill(label: "PRQ", value: String(format: "%.1f", scan.prqScore), color: Theme.brandBlue)
                ScanStatPill(label: "VERTICAL", value: String(format: "%.1f\"", scan.verticalEstimateInches), color: Theme.brandCyan)
                ScanStatPill(label: "FLIGHT", value: String(format: "%.2fs", scan.flightTimeSeconds), color: Theme.elitePurple)
            }

            if let screening = scan.movementScreening {
                HStack(spacing: 8) {
                    ScanStatPill(
                        label: "FMS",
                        value: "\(Int(screening.screenResults.first(where: { $0.kind == .fms })?.totalScore ?? 0))/21",
                        color: Theme.foundationGreen
                    )
                    ScanStatPill(
                        label: "SFMA",
                        value: "\(Int(screening.screenResults.first(where: { $0.kind == .sfma })?.totalScore ?? 0))/15",
                        color: Theme.brandBlue
                    )
                    ScanStatPill(
                        label: "FRC",
                        value: "\(Int(screening.screenResults.first(where: { $0.kind == .frc })?.totalScore ?? 0))/12",
                        color: .orange
                    )
                }

                Text("Path: \(screening.prescription.trainingTrack.rawValue) • \(screening.prescription.equipmentFocus.rawValue)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
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
                    Text(viewModel.profile.sport ?? "")
                        .font(.system(.caption, weight: .semibold))
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
                    Text("Neural readiness")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(0.5)

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
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .tracking(0.3)
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
                            Text("7-day avg")
                                .font(.system(size: 8, weight: .semibold))
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
                        Text("Recovery mode")
                            .font(.system(size: 9, weight: .semibold))
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
                            Text("Auto")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.green.opacity(0.6))
                        }
                    }
                }
            } else {
                Button {
                    guard healthKitConnectTask == nil else { return }
                    isConnectingHealthKit = true
                    healthKitConnectTask = Task {
                        await viewModel.connectHealthKit()
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            isConnectingHealthKit = false
                            healthKitConnectTask = nil
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isConnectingHealthKit {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "heart.text.clipboard")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(isConnectingHealthKit ? "Connecting..." : "Connect Apple Health")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.vertical, 12)
                    .background(Theme.brandCyan)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .disabled(isConnectingHealthKit)

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
                        Text("Coach")
                            .font(.system(size: 10, weight: .bold))
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
                        Text("Blueprints")
                            .font(.system(size: 10, weight: .bold))
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

    private var liveAndMarketRow: some View {
        HStack(spacing: 12) {
            Button {
                showLiveEvents = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.brandCyan.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live events")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Tickets & Fundraising")
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
                                .stroke(Theme.brandCyan.opacity(0.12), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                showMarketplace = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Market")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Packs, Auctions, Bids")
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
                                .stroke(Color.orange.opacity(0.12), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricCard(title: SimpleModeLabels.prqScore(simpleMode), value: String(format: "%.1f", effectiveMetrics.prqScore), icon: "brain.head.profile.fill", color: Theme.brandBlue)
            MetricCard(title: SimpleModeLabels.efficiency(simpleMode), value: String(format: "%.0f%%", effectiveMetrics.efficiencyScore), icon: "bolt.fill", color: .orange)
            MetricCard(title: SimpleModeLabels.readiness(simpleMode), value: String(format: "%.0f%%", effectiveMetrics.readinessScore), icon: "heart.fill", color: .red)
            MetricCard(title: SimpleModeLabels.evolutionShards(simpleMode), value: "\(viewModel.profile.evolutionShards)", icon: "diamond.fill", color: Theme.brandCyan)
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick start")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

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
            Text("Recent activity")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

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
                Text(attribute)
                    .font(.system(size: 10, weight: .semibold))
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
                Text(track.name)
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
                Text(trackName)
                    .font(.system(.caption, weight: .semibold))
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
