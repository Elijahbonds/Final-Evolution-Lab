import SwiftUI

/// Arena: built-out venues; each venue groups game modes. Tap a mode → Get Ready → Play → Result.
struct ArenaView: View {
    let viewModel: LabViewModel
    @Binding var selectedTab: AppTab

    @State private var selectedMode: GameMode?
    @State private var showLocalPlayLobby = false
    @State private var localPlayMode: GameMode?
    @State private var localPlayIsHost = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                localPlaySection
                ForEach(GameModeRegistry.arenaVenues) { venue in
                    venueSection(venue)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Theme.deepBlack)
        .fullScreenCover(item: $selectedMode) { mode in
            ArenaGameFlowView(
                mode: mode,
                viewModel: viewModel,
                multipeer: nil,
                isLocalHost: false,
                onDismiss: { selectedMode = nil }
            )
        }
        .fullScreenCover(isPresented: $showLocalPlayLobby) {
            LocalPlayLobbyView(
                multipeer: viewModel.multipeerService,
                onStartGame: { mode, isHost in
                    localPlayMode = mode
                    localPlayIsHost = isHost
                    showLocalPlayLobby = false
                },
                onDismiss: { showLocalPlayLobby = false }
            )
        }
        .fullScreenCover(item: $localPlayMode) { mode in
            ArenaGameFlowView(
                mode: mode,
                viewModel: viewModel,
                multipeer: viewModel.multipeerService,
                isLocalHost: localPlayIsHost,
                onDismiss: {
                    viewModel.multipeerService.stop()
                    localPlayMode = nil
                }
            )
        }
        .onAppear {
            if let id = viewModel.preselectedArenaModeId {
                selectedMode = GameModeRegistry.mode(for: id)
                viewModel.preselectedArenaModeId = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ARENAS")
                .font(.system(size: 28, weight: .black))
                .italic()
                .tracking(2)
                .foregroundStyle(.white)
            Text("Choose a venue, then a mode. Get Ready → Play → Result.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var localPlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.brandCyan)
                Text("Local Play")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
            }
            Text("Play with someone on the same Wi‑Fi.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Button {
                showLocalPlayLobby = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                    Text("Host or Join Game")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.brandCyan)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Local Play: Host or Join Game")
            .accessibilityHint("Opens lobby to play with a nearby device on same Wi‑Fi")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func venueSection(_ venue: GameModeRegistry.ArenaVenue) -> some View {
        let modes = GameModeRegistry.modes(for: venue)
        if !modes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                venueHeaderCard(venue)
                VStack(spacing: 10) {
                    ForEach(modes, id: \.id.id) { mode in
                        modeRow(mode: mode, venueAccent: venue.accentColor)
                    }
                }
            }
        }
    }

    private func venueHeaderCard(_ venue: GameModeRegistry.ArenaVenue) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [venue.accentColor.opacity(0.35), venue.accentColor.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(venue.accentColor.opacity(0.4), lineWidth: 1)
                    )
                Image(systemName: venue.iconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(venue.accentColor)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(venue.name)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Text(venue.tagline)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(venue.accentColor.opacity(0.95))
                Text(venue.atmosphere)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(venue.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func modeRow(mode: GameMode, venueAccent: Color) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mode.accentColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: mode.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(mode.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(mode.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(mode.accentColor.opacity(0.9))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(mode.accentColor.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Arena Game Flow (Get Ready → Play → Result)

private enum ArenaFlowPhase {
    case getReady
    case playing
    case result
}

private struct ArenaGameFlowView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let multipeer: MultipeerService?
    let isLocalHost: Bool
    let onDismiss: () -> Void

    @State private var phase: ArenaFlowPhase = .getReady
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var shardsEarned: Int = 0
    @State private var prqGain: Double = 0
    @State private var gameResult: GameSessionResult?

    private var prqCurrent: Double { viewModel.effectiveMetrics.prqScore }
    private var isLocalPlay: Bool { multipeer != nil }

    var body: some View {
        Group {
            switch phase {
            case .getReady:
                GetReadyScreen(
                    title: isLocalPlay ? "\(mode.name) · Local" : mode.name,
                    subtitle: mode.id.getReadySubtitle,
                    accentColor: mode.accentColor,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.35)) { phase = .playing }
                    }
                )
                .overlay(alignment: .topLeading) {
                    exitButton
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .playing:
                Group {
                    if mode.id == .brainBrawl && multipeer == nil {
                        BrainBrawlPlayView(
                            mode: mode,
                            viewModel: viewModel,
                            multipeer: nil,
                            isLocalHost: false,
                            onExit: onDismiss,
                            onGameEnd: { p1, p2, shards, prq in
                                playerScore = p1
                                opponentScore = p2
                                shardsEarned = shards
                                prqGain = prq
                                let result = GameSessionResult(
                                    id: UUID().uuidString,
                                    gameModeId: mode.id.rawValue,
                                    date: Date(),
                                    score: p1,
                                    opponentScore: p2,
                                    shardsEarned: shards,
                                    prqBonus: prq,
                                    isMultiplayer: false,
                                    duration: 0,
                                    roundsPlayed: mode.id.environmentRoundCount
                                )
                                SaveSystem.saveGameResult(result)
                                viewModel.gameResults.append(result)
                                viewModel.profile.evolutionShards += shards
                                SaveSystem.saveProfile(viewModel.profile)
                                gameResult = result
                                withAnimation(.easeInOut(duration: 0.4)) { phase = .result }
                            }
                        )
                    } else {
                        GenericArenaPlayView(
                            mode: mode,
                            viewModel: viewModel,
                            multipeer: multipeer,
                            isLocalHost: isLocalHost,
                            onExit: onDismiss,
                            onGameEnd: { p1, p2, shards, prq in
                                playerScore = p1
                                opponentScore = p2
                                shardsEarned = shards
                                prqGain = prq
                                let result = GameSessionResult(
                                    id: UUID().uuidString,
                                    gameModeId: mode.id.rawValue,
                                    date: Date(),
                                    score: p1,
                                    opponentScore: p2,
                                    shardsEarned: shards,
                                    prqBonus: prq,
                                    isMultiplayer: isLocalPlay,
                                    duration: 0,
                                    roundsPlayed: mode.id.environmentRoundCount
                                )
                                SaveSystem.saveGameResult(result)
                                viewModel.gameResults.append(result)
                                viewModel.profile.evolutionShards += shards
                                SaveSystem.saveProfile(viewModel.profile)
                                gameResult = result
                                withAnimation(.easeInOut(duration: 0.4)) { phase = .result }
                            }
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .result:
                ResultScreen(
                    winner: playerScore > opponentScore ? .p1 : (playerScore < opponentScore ? .p2 : .draw),
                    p1Score: playerScore,
                    p2Score: opponentScore,
                    title: mode.name,
                    accentColor: mode.accentColor,
                    shardsEarned: shardsEarned,
                    prqGain: prqGain,
                    prqCurrent: prqCurrent + prqGain,
                    modeAttributeLabel: PRQ.attributeLabel(for: mode.id),
                    modeAttributeValue: PRQ.attributeValue(prq: prqCurrent + prqGain, for: mode.id),
                    returnButtonTitle: "BACK TO ARENA",
                    onReturn: onDismiss
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.32), value: phase)
        .statusBarHidden(phase != .result)
    }

    private var exitButton: some View {
        Button {
            onDismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.6))
                .padding(20)
        }
        .accessibilityLabel("Exit game")
    }
}

// MARK: - Generic Play: skill-based timing meter + PRQ. Handheld-console feel—your tap timing decides the round.
// Arena play uses gradient background + UI only (no 3D scene). Lab dunk uses RealityKitDunkView for full 3D court.

private struct GenericArenaPlayView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let multipeer: MultipeerService?
    let isLocalHost: Bool
    let onExit: () -> Void
    let onGameEnd: (Int, Int, Int, Double) -> Void

    private var totalRounds: Int { mode.id.environmentRoundCount }
    private var isLocalPlay: Bool { multipeer != nil }
    /// I am P1 (host) in local play; P2 (joiner) waits for P1 then goes.
    private var iAmP1: Bool { isLocalHost }

    @State private var round: Int = 1
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var roundResult: (p1: Int, p2: Int)?
    @State private var showingRoundResult: Bool = false
    @State private var actionButtonPressed: Bool = false

    @State private var actionMeterTask: Task<Void, Never>?
    @State private var commitFeedback: String? = nil

    /// Local play: my timing this round (0–100); opponent's when received.
    @State private var myTimingThisRound: Int? = nil
    @State private var opponentTimingThisRound: Int? = nil
    @State private var waitingForOpponent: Bool = false

    /// Console-standard: charge and release. Hold Cross to charge, release to fire.
    @State private var isCharging: Bool = false
    @State private var chargeProgress: Double = 0
    @State private var chargeTask: Task<Void, Never>?
    private let chargeRatePerSecond: Double = 1.0
    private let chargeMaxTime: Double = 1.2

    private var roundLabel: String { mode.id.environmentRoundLabel }
    private var actionTitle: String { mode.id.environmentActionTitle }
    private var oppLabel: String { mode.id.opponentDisplayName }

    var body: some View {
        ZStack {
            environmentGradient
            VStack(spacing: 24) {
                environmentHeader
                roundIndicator
                scoreRow
                Spacer()
                if let feedback = commitFeedback {
                    Text(feedback)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                        .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                        .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                } else if isLocalPlay && waitingForOpponent {
                    Text("Waiting for \(oppLabel)...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else if isCharging {
                    chargeBarSection
                } else {
                    controllerHintSection
                }
                actionButton
            }
            .animation(.easeInOut(duration: 0.25), value: commitFeedback != nil)
            .animation(.easeInOut(duration: 0.2), value: isCharging)
            .padding(.bottom, 8)
            if ControllerDiscoveryService.shared.hasPhysicalController {
                controllerConnectedPill
            } else {
                PS2GamepadOverlay(
                    onFaceButton: handleArenaFaceButton(_:),
                    onDPad: { _ in },
                    onLeftStick: { _ in },
                    onRightStick: { _ in },
                    onCrossDown: canTapAction ? { startCharge() } : nil,
                    onCrossUp: { endChargeAndCommit() },
                    accentColor: mode.accentColor,
                    isActive: canTapAction,
                    mobileOptimized: true
                )
                .allowsHitTesting(canTapAction)
            }
        }
        .onChange(of: multipeer?.lastReceivedMessage ?? "") { _, _ in
            guard let mp = multipeer, mp.lastReceivedRound == round else { return }
            if iAmP1 && mp.lastReceivedAction == "P2" {
                opponentTimingThisRound = mp.lastReceivedScore
                applyLocalPlayResult()
            } else if !iAmP1 && mp.lastReceivedAction == "P1" {
                opponentTimingThisRound = mp.lastReceivedScore
            }
        }
        .alert("\(roundLabel) \(round)", isPresented: $showingRoundResult) {
            Button("Next") {
                nextRound()
            }
        } message: {
            if let r = roundResult {
                Text(alertMessage(p1: r.p1, p2: r.p2))
            }
        }
        .onDisappear {
            actionMeterTask?.cancel()
        }
        .onPhysicalControllerCross(down: { startCharge() }, up: { endChargeAndCommit() })
    }

    private var environmentGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    mode.accentColor.opacity(0.18),
                    mode.id.environmentSecondaryColor.opacity(0.25),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            Color.black.opacity(0.4)
                .ignoresSafeArea()
        }
    }

    /// Shown when a physical controller is connected so virtual overlay is hidden (emulator-style handoff).
    private var controllerConnectedPill: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 12))
                Text(ControllerDiscoveryService.shared.controllerName ?? "Controller")
                    .font(.system(size: 11, weight: .semibold))
                Text("connected")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .padding(.bottom, 24)
        }
        .allowsHitTesting(false)
    }

    private var environmentHeader: some View {
        HStack {
            Button {
                onExit()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("EXIT")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(mode.environmentName)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(mode.accentColor)
                Text(mode.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var roundIndicator: some View {
        HStack(spacing: 6) {
            Text("\(roundLabel)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.5))
            Text("\(round)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("OF \(totalRounds)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .contentTransition(.numericText())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: round)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(roundLabel) \(round) of \(totalRounds)")
    }

    private var scoreRow: some View {
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                Text("\(playerScore)")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: playerScore)
                Text("YOU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(mode.accentColor)
            }
            Text("\u{2014}")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.tertiary)
            VStack(spacing: 4) {
                Text("\(opponentScore)")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: opponentScore)
                Text(oppLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score: you \(playerScore), \(oppLabel) \(opponentScore)")
    }

    /// Console-standard: hold ✕ to charge, release to fire. Or tap action button to fire at full charge.
    private var controllerHintSection: some View {
        VStack(spacing: 10) {
            Text(mode.id.environmentAtmosphere)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(mode.accentColor.opacity(0.9))
                .multilineTextAlignment(.center)
            Text("Hold ✕ (Cross) to charge, release to \(actionTitle)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(mode.accentColor)
                .tracking(1)
            Text(mode.id.environmentDescription)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hold Cross to charge, release to \(actionTitle). \(mode.id.environmentDescription)")
    }

    private var chargeBarSection: some View {
        VStack(spacing: 8) {
            Text(mode.id.chargeBarTitle)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(mode.accentColor)
                .tracking(2)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.5))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(mode.accentColor)
                        .frame(width: geo.size.width * chargeProgress)
                        .animation(.easeOut(duration: 0.06), value: chargeProgress)
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.id.chargeBarTitle). \(Int(chargeProgress * 100)) percent.")
        .accessibilityValue("\(Int(chargeProgress * 100))%")
    }

    private func handleArenaFaceButton(_ button: PS2FaceButton) {
        guard button == .cross else { return }
        if isCharging {
            endChargeAndCommit()
        } else {
            startCharge()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { endChargeAndCommit() }
        }
    }

    private func startCharge() {
        guard canTapAction, !isCharging else { return }
        chargeTask?.cancel()
        chargeProgress = 0
        isCharging = true
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        chargeTask = Task { @MainActor in
            let start = CACurrentMediaTime()
            while !Task.isCancelled && isCharging {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                let elapsed = CACurrentMediaTime() - start
                chargeProgress = min(1.0, elapsed / chargeMaxTime)
            }
        }
    }

    private func endChargeAndCommit() {
        guard canTapAction else { return }
        chargeTask?.cancel()
        chargeTask = nil
        let captured = chargeProgress
        isCharging = false
        chargeProgress = 0
        commitWithChargeLevel(captured)
    }

    private var canTapAction: Bool {
        if !isLocalPlay { return !showingRoundResult }
        if waitingForOpponent { return false }
        if iAmP1 { return true }
        return opponentTimingThisRound != nil
    }

    private var actionButton: some View {
        Button {
            guard canTapAction else { return }
            withAnimation(.easeOut(duration: 0.08)) { actionButtonPressed = true }
            #if !targetEnvironment(simulator)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.1)) { actionButtonPressed = false }
                commitWithChargeLevel(1.0)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 18, weight: .semibold))
                Text(buttonActionTitle)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(2)
            }
            .foregroundStyle(canTapAction ? .black : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(buttonBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: mode.accentColor.opacity(0.4), radius: 12)
            .scaleEffect(actionButtonPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!canTapAction)
        .accessibilityLabel(actionTitle)
        .accessibilityHint("Commits the action for this round; use controller ✕ or tap")
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    private var buttonActionTitle: String {
        if isLocalPlay && !iAmP1 && opponentTimingThisRound == nil { return "Wait for P1..." }
        return actionTitle
    }

    private var buttonBackgroundColor: Color {
        if !canTapAction { return mode.accentColor.opacity(0.5) }
        return mode.accentColor
    }

    /// Console-standard: charge level 0...1 (0 = quick release, 1 = full charge). Base quality from PRQ, scaled by charge.
    private func controllerCommitQuality(chargeLevel: Double) -> Double {
        let prq = viewModel.effectiveMetrics.prqScore
        let normalized = min(100, max(0, prq)) / 100.0
        let base = 0.58 + normalized * 0.28
        let chargeFactor = 0.35 + 0.65 * chargeLevel
        return min(0.95, base * chargeFactor)
    }

    private func commitWithChargeLevel(_ chargeLevel: Double) {
        guard canTapAction else { return }
        chargeTask?.cancel()
        chargeTask = nil
        isCharging = false
        actionMeterTask?.cancel()
        actionMeterTask = nil
        let timingQuality = controllerCommitQuality(chargeLevel: chargeLevel)
        let perfect = mode.id.commitFeedbackPerfect
        let good = mode.id.commitFeedbackGood
        let miss = mode.id.commitFeedbackMiss
        let feedback = timingQuality >= 0.88 ? perfect : (timingQuality >= 0.72 ? good : miss)
        withAnimation(.spring(response: 0.2)) { commitFeedback = feedback }
        #if !targetEnvironment(simulator)
        if feedback == perfect { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
        else if feedback == good { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        else { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        #endif
        if isLocalPlay, let mp = multipeer {
            let timingHundred = Int(min(100, max(0, timingQuality * 100)))
            myTimingThisRound = timingHundred
            let role = iAmP1 ? "P1" : "P2"
            mp.sendAction(role, score: timingHundred, round: round)
            if iAmP1 {
                waitingForOpponent = true
            } else {
                applyLocalPlayResult()
            }
        } else {
            scoreRound(timingQuality: timingQuality)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(720))
            withAnimation(.easeOut(duration: 0.2)) { commitFeedback = nil }
        }
    }

    private func applyLocalPlayResult() {
        guard let myTiming = myTimingThisRound,
              let oppTiming = opponentTimingThisRound else { return }
        let p1Timing = iAmP1 ? myTiming : oppTiming
        let p2Timing = iAmP1 ? oppTiming : myTiming
        let p1WinsRound = p1Timing > p2Timing
        let p1Points = p1WinsRound ? 1 : 0
        let p2Points = 1 - p1Points
        roundResult = (p1Points, p2Points)
        playerScore += p1Points
        opponentScore += p2Points
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.25)) { showingRoundResult = true }
        }
    }

    private func alertMessage(p1: Int, p2: Int) -> String {
        let won = p1 > p2
        switch mode.id {
        case .basketballHeadToHead, .basketball3v3:
            return won ? "Bucket. You \(p1), \(oppLabel) \(p2)." : "Missed. You \(p1), \(oppLabel) \(p2)."
        case .basketballDunkContest:
            return won ? "Dunk counted. Judges favor you this round." : "No score. Judges went the other way."
        case .karate:
            return won ? "Clean strike. You landed the point." : "Point to opponent. You took the hit."
        case .baseball:
            return won ? "Gone! You cleared the fence." : "Out. Pitcher got you this at-bat."
        case .football:
            return won ? "House call. You broke it." : "Stopped. Special teams held."
        case .soccer:
            return won ? "Goal! Keeper couldn’t reach it." : "Saved. Keeper read you."
        case .golf:
            return won ? "Closer. You won the hole." : "Opponent closer. You lost the hole."
        case .tennis:
            return won ? "Point yours. You \(p1), \(oppLabel) \(p2)." : "Point to opponent. You \(p1), \(oppLabel) \(p2)."
        case .volleyball:
            return won ? "Kill. You \(p1), \(oppLabel) \(p2)." : "Blocked. You \(p1), \(oppLabel) \(p2)."
        case .gymnastics:
            return won ? "Stuck. Judges gave you the routine." : "Deduction. Judges favored opponent."
        case .brainBrawl:
            return won ? "Correct! You got it first." : "AI answered first this time."
        }
    }

    /// Skill-based: timingQuality 1 = perfect (green), 0.1 = miss. PRQ nudges outcome; timing dominates (handheld-console feel).
    private func scoreRound(timingQuality: Double = 0.5) {
        let prq = viewModel.effectiveMetrics.prqScore
        let baseChance = PRQ.successChanceFromPRQ(prq, for: mode.id)
        let skillFactor = 0.28 + 0.72 * timingQuality
        var chance = min(0.94, baseChance * skillFactor + (1 - skillFactor) * 0.15)
        let isClutch = (round == totalRounds && playerScore == opponentScore)
        if isClutch { chance = min(0.94, chance + 0.05) }
        let p1WinsRound = Double.random(in: 0..<1) < chance
        let p1Points = p1WinsRound ? 1 : 0
        let p2Points = 1 - p1Points
        roundResult = (p1Points, p2Points)
        playerScore += p1Points
        opponentScore += p2Points
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.25)) { showingRoundResult = true }
        }
    }

    private func nextRound() {
        roundResult = nil
        commitFeedback = nil
        myTimingThisRound = nil
        opponentTimingThisRound = nil
        waitingForOpponent = false
        chargeTask?.cancel()
        chargeTask = nil
        isCharging = false
        chargeProgress = 0
        if round >= totalRounds {
            finishGame()
        } else {
            round += 1
        }
    }

    private func finishGame() {
        let prq = viewModel.effectiveMetrics.prqScore
        let won = playerScore > opponentScore
        let tied = playerScore == opponentScore
        let diff = playerScore - opponentScore
        let gain = PRQ.modeReward(mode: mode.id, won: won, tied: tied, combo: 0, criticals: 0, scoreDifferential: diff)
        let baseShards = 6 + totalRounds * 2
        let shards = max(8, min(40, baseShards + (playerScore * 3) + (won ? 12 : 0) + (diff > 0 ? diff * 2 : 0)))
        onGameEnd(playerScore, opponentScore, shards, gain)
    }
}

// MARK: - Environment copy (GameModeId) used by GenericArenaPlayView
// Round labels, action titles, round counts, and secondary colors are on GameModeId in GameMode.swift.
