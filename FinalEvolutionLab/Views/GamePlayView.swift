import SwiftUI
import SceneKit
import UIKit
import QuartzCore

private struct PendingGoldenApexPayload {
    let trick: DirectionalTrick
    let isCritical: Bool
}

struct GamePlayView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode
    let sessionReadiness: Double
    /// When true (screenshot harness only), skips multiplayer lobby + countdown so START MATCH + scene chrome are visible immediately.
    var skipMatchLobbyForScreenshotHarness: Bool = false

    @State private var score: Int = 0
    @State private var opponentScore: Int = 0
    @State private var timeRemaining: Int = 60
    @State private var isActive = false
    @State private var showResults = false
    @State private var gameReady = false
    @State private var roundNumber: Int = 1
    @State private var combo: Int = 0
    @State private var maxCombo: Int = 0
    @State private var criticalHits: Int = 0
    @State private var lastAction: String = ""
    @State private var lastActionIsCritical: Bool = false
    @State private var lastActionIsBurst: Bool = false
    @State private var showFlash = false
    @State private var showCriticalFlash = false
    @State private var showImpactFlash = false
    @State private var multipeerService = MultipeerService()
    @State private var streakTimer: Task<Void, Never>?
    @State private var screenShake: CGFloat = 0
    @State private var showBiomechanicsHUD: Bool = true
    @State private var liveLeakagePenalty: Double = 0
    @State private var leakageFlashJoint: JointType?
    @State private var lastGameplayLeakagePenaltyAt: [JointType: TimeInterval] = [:]

    @State private var matchSessionId = UUID()
    @State private var finalizedMatchSessionId: UUID?
    @State private var delayedOpponentScoreGeneration: UInt64 = 0

    @State private var dunkRound: Int = 1
    @State private var lastJudgeScores: (Int, Int, Int)?
    @State private var crowdMessage: String = ""
    @State private var chakraBar: Double = 0
    @State private var karateHitFlash: Bool = false

    @State private var dunkEngine = DunkContestState()
    @State private var dunkTimerTask: Task<Void, Never>?
    @State private var styleTriggerHeld: Bool = false
    @State private var powerTriggerHeld: Bool = false
    @State private var showComboChain: Bool = false
    @State private var comboChainText: String = ""
    @State private var showStyleLanding: Bool = false
    @State private var styleLandingBonus: Int = 0
    @State private var showRimDistortion: Bool = false

    @State private var golfCharge: Double = 0
    @State private var golfPhase: GolfSwingPhase = .idle
    @State private var aimPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var footballPhase: FootballPhase = .catch
    @State private var runMeter: Double = 0
    @State private var runMeterTimer: Task<Void, Never>?
    @State private var swipeStart: CGPoint?
    @State private var swipeStartTime: Date?
    @State private var golfDragStartY: CGFloat = 0
    @State private var leftStickVector: CGPoint = .zero
    @State private var rightStickVector: CGPoint = .zero
    @State private var lastStickComboFireAt: Double = 0

    @State private var specialMeter: Double = 0
    @State private var isModifierHeld: Bool = false
    @State private var currentTrickDirection: ComboDirection = .neutral
    @State private var lastTrickName: String = ""
    @State private var showTrickText: Bool = false
    @State private var isSlowMo: Bool = false
    @State private var slowMoTimer: Task<Void, Never>?
    @State private var consecutiveWins: Int = 0
    @State private var showPerfectGuard: Bool = false
    @State private var showVanishFlash: Bool = false
    @State private var blockTimestamp: Double = 0

    @State private var defensiveState = DefensiveInputState()
    @State private var lastContestPercent: Int? = nil
    @State private var lastContestLabel: String? = nil
    @State private var lastContestTier: ContestTier? = nil
    @State private var showContestPill: Bool = false
    @State private var defenderSimDistance: Double = 4.0

    @State private var goldenComboEngine = GoldenEraComboEngine()
    @State private var timeScaleManager = TimeScaleManager()
    @State private var matrixState = MatrixStateMachine()
    @State private var activeModifierState: ModifierState = .none
    @State private var lastQTEGrade: QTEGrade? = nil
    @State private var showQTEGrade: Bool = false
    @State private var qteGradeText: String = ""
    @State private var timeScaleUpdateTask: Task<Void, Never>? = nil

    /// Host / join / accept peer — must finish before countdown (GAME-11).
    @State private var matchLobbyComplete: Bool = false
    @State private var playerActionCount: Int = 0
    @State private var lastCommittedTrickDirection: ComboDirection = .up
    @State private var pendingGoldenApex: PendingGoldenApexPayload?
    @State private var apexQTESessionGeneration: UInt64 = 0
    @State private var sessionStartedAt: Date?

    @Environment(\.dismiss) private var dismiss

    private enum GolfSwingPhase { case idle, backswing }
    private enum FootballPhase { case `catch`, run }

    private var isKarate: Bool { gameMode.id == .karate || gameMode.id == .karateEndless }
    private var inputScheme: InputScheme { gameMode.id.inputScheme }

    private var usesAcademyRhythmOverlay: Bool {
        switch inputScheme {
        case .rhythmTap, .filmQuiz, .partyBoard: true
        default: false
        }
    }
    private var supportsTricks: Bool { gameMode.id == .basketballDunkContest || gameMode.id == .basketballHeadToHead || gameMode.id == .basketball3v3 || isKarate }
    private var specialMeterFull: Bool { specialMeter >= 100 }

    private var playerPRQ: Double { viewModel.effectiveMetrics.prqScore }

    private var prqAttributeLabel: String { PRQ.attributeLabel(for: gameMode.id) }
    private var prqAttributeValue: Double { PRQ.attributeValue(prq: playerPRQ, for: gameMode.id) }
    private var prqSuccessChance: Double { PRQ.successChanceFromPRQ(playerPRQ, for: gameMode.id) }

    private var arcadePhysics: ArcadePhysics {
        ArcadePhysics.fromPRQ(
            viewModel.effectiveMetrics.prqScore,
            neuralDrive: viewModel.effectiveMetrics.neuralDrive,
            audit: viewModel.biomechanicsAudit
        )
    }

    private var physicsConfig: GamePhysicsConfig {
        GamePhysicsConfig.forMode(
            gameMode.id,
            prq: viewModel.effectiveMetrics.prqScore,
            audit: viewModel.biomechanicsAudit,
            metrics: viewModel.effectiveMetrics
        )
    }

    private var gameRules: GameModeRules {
        GameModeRules.forMode(gameMode.id)
    }

    private var isTimerBased: Bool {
        gameRules.useMatchCountdown
    }

    private var isDunkContest: Bool {
        gameMode.id == .basketballDunkContest
    }

    private var isBlacktop: Bool {
        gameMode.id == .basketballHeadToHead || gameMode.id == .basketball3v3
    }

    private var isBasketball: Bool {
        gameMode.id == .basketballHeadToHead || gameMode.id == .basketballDunkContest || gameMode.id == .basketball3v3
    }

    private var supportsDefense: Bool {
        gameMode.id == .basketballHeadToHead || gameMode.id == .basketball3v3
    }

    private var targetScore: Int {
        gameRules.targetScore
    }

    private var maxRounds: Int {
        gameRules.roundLimit
    }

    private var participationEligibleForRewards: Bool {
        let minA = gameRules.rewardEligibleMinActions
        return score > 0 || maxCombo >= 2 || criticalHits > 0 || playerActionCount >= minA
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()

            sceneArea
                .ignoresSafeArea(edges: .bottom)
                .offset(x: screenShake)

            VStack(spacing: 0) {
                hudBar
                Spacer()
                controlPanel
            }
            .offset(x: screenShake)

            if showBiomechanicsHUD, let audit = viewModel.biomechanicsAudit {
                LiveBiomechanicsOverlay(
                    audit: audit,
                    isActive: isActive,
                    currentAction: lastAction,
                    onLeakageDetected: { joint, severity in
                        handleLiveLeakage(joint: joint, severity: severity)
                    }
                )
                .allowsHitTesting(false)
            }

            ImpactFlashOverlay(isActive: showFlash, color: gameMode.accentColor, intensity: Double(physicsConfig.impactIntensity))

            if showCriticalFlash {
                LinearGradient(
                    colors: [Theme.brandCyan.opacity(0.3), Theme.elitePurple.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if showImpactFlash {
                RadialGradient(
                    colors: [gameMode.accentColor.opacity(0.4), .clear],
                    center: .bottom,
                    startRadius: 10,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if isKarate && karateHitFlash {
                Color.red.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if isSlowMo {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .overlay(
                        Text("SLOW MOTION")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.top, 60)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    )
            }

            if showPerfectGuard {
                RadialGradient(
                    colors: [Theme.brandCyan.opacity(0.5), Theme.elitePurple.opacity(0.3), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if showVanishFlash {
                Color.white.opacity(0.6)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if showTrickText && !lastTrickName.isEmpty {
                VStack {
                    Spacer()
                    Text(lastTrickName)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [gameMode.accentColor, .white, gameMode.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: gameMode.accentColor.opacity(0.8), radius: 12)
                        .shadow(color: .black, radius: 4)
                        .tracking(3)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            if showResults {
                ResultScreen(
                    winner: {
                        switch VersusMatchOutcome.winnerSide(playerScore: score, opponentScore: opponentScore) {
                        case .playerWins: return .p1
                        case .opponentWins: return .p2
                        case .draw: return .draw
                        }
                    }(),
                    p1Score: score,
                    p2Score: opponentScore,
                    title: gameMode.name,
                    accentColor: gameMode.accentColor,
                    prqGain: prqReward,
                    prqCurrent: playerPRQ,
                    modeAttributeLabel: prqAttributeLabel,
                    modeAttributeValue: prqAttributeValue,
                    onReturn: {
                        finalizeResults()
                        dismiss()
                    }
                )
            }

            if !matchLobbyComplete && !showResults {
                matchLobbyOverlay
            }

            if matchLobbyComplete && !gameReady && !showResults {
                GetReadyScreen(
                    title: gameMode.name,
                    subtitle: gameMode.hint,
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: {
                        gameReady = true
                    }
                )
            }

            if pendingGoldenApex != nil && isActive {
                apexQTETapOverlay
            }

            if isActive && usesAcademyRhythmOverlay {
                academyRhythmOverlay
            }

            if supportsTricks && isActive {
                specialMeterOverlay
            }

            if supportsTricks && isActive {
                trickModifierOverlay
            }

            if showContestPill, let pct = lastContestPercent, let label = lastContestLabel, let tier = lastContestTier {
                contestPillOverlay(percent: pct, label: label, tier: tier)
            }

            if supportsDefense && isActive {
                defensiveControlsOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("EXIT")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                    }
                    .foregroundStyle(gameMode.accentColor)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if multipeerService.pendingInvitationPeerName != nil {
                        Button("Accept") {
                            multipeerService.acceptPendingInvitation()
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                        Button("Decline") {
                            multipeerService.rejectPendingInvitation()
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    }
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showBiomechanicsHUD.toggle()
                        }
                    } label: {
                        Image(systemName: showBiomechanicsHUD ? "figure.run.motion" : "figure.stand")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(showBiomechanicsHUD ? Theme.brandCyan : .secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    NeuralAuraBadge(auraLevel: arcadePhysics.auraLevel)
                    peerStatusBadge
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if skipMatchLobbyForScreenshotHarness {
                matchLobbyComplete = true
                gameReady = true
            }
        }
        .onChange(of: multipeerService.lastReceivedScore) { _, newScore in
            guard multipeerService.isConnected else { return }
            withAnimation(.spring(response: 0.2)) {
                opponentScore = newScore
            }
        }
        .onDisappear {
            matchLobbyComplete = false
            multipeerService.stop()
            gameTimerTask?.cancel()
            streakTimer?.cancel()
            dunkTimerTask?.cancel()
            slowMoTimer?.cancel()
            timeScaleUpdateTask?.cancel()
            runMeterTimer?.cancel()
        }
    }

    // MARK: - HUD Bar

    private var hudBar: some View {
        ZStack {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(gameMode.accentColor)
                            .frame(width: 5, height: 5)
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(gameMode.accentColor.opacity(0.8))
                    }
                    Text("\(score)")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .shadow(color: gameMode.accentColor.opacity(0.3), radius: 8)
                    HStack(spacing: 3) {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 7))
                        Text("\(prqAttributeLabel) \(Int(prqAttributeValue * 100))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(playerPRQ >= PRQ.legendaryThreshold ? .yellow : gameMode.accentColor.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(gameMode.accentColor.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: gameMode.iconName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(gameMode.accentColor)
                    }

                    if isDunkContest {
                        Text("Round \(dunkRound)/3")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                            .shadow(color: .orange.opacity(0.3), radius: 6)
                    } else if isBlacktop {
                        Text("First to \(targetScore)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(gameMode.accentColor)
                    } else if isTimerBased {
                        Text(timeFormatted)
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(timeRemaining <= 10 ? .red : gameMode.accentColor)
                            .contentTransition(.numericText())
                            .shadow(color: (timeRemaining <= 10 ? Color.red : gameMode.accentColor).opacity(0.4), radius: 8)
                    } else {
                        Text("R\(roundNumber)/\(maxRounds)")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(gameMode.accentColor)
                    }

                    if arcadePhysics.neuralBurstActive {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8))
                            Text("1.5x")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(Theme.elitePurple)
                        .shadow(color: Theme.elitePurple.opacity(0.4), radius: 6)
                    }
                }

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("OPP")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(.secondary.opacity(0.4))
                            .frame(width: 5, height: 5)
                    }
                    Text("\(opponentScore)")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if isKarate {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("CHAKRA")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange.opacity(0.9))
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black.opacity(0.5))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, .yellow],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * (chakraBar / 100))
                                        .animation(.spring(response: 0.3), value: chakraBar)
                                }
                            }
                            .frame(width: 80, height: 6)
                            .clipShape(.rect(cornerRadius: 3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(.orange.opacity(0.4), lineWidth: 0.5)
                            )
                        }
                        .padding(.trailing, 20)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(
            ZStack {
                Theme.cardBackground.opacity(0.9)
                LinearGradient(
                    colors: [gameMode.accentColor.opacity(0.04), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [gameMode.accentColor.opacity(0.4), gameMode.accentColor.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
    }

    private var timeFormatted: String {
        let mins = timeRemaining / 60
        let secs = timeRemaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Scene Area

    private var sceneArea: some View {
        ZStack {
            GameSceneHostView(
                gameMode: gameMode.id,
                neuralDrive: viewModel.profile.metrics.neuralDrive,
                leftStickInput: leftStickVector,
                rightStickInput: rightStickVector,
                isMidAir: isDunkContest ? (dunkEngine.phase == .airborne || dunkEngine.phase == .launch) : false,
                isSpecialMove: isSlowMo || showVanishFlash || showPerfectGuard,
                isSlowMotion: isSlowMo
            )
            .clipShape(.rect(cornerRadius: 0))

            if combo > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(isKarate ? "\(combo) HIT COMBO!" : "\(combo)x COMBO")
                                .font(.system(size: isKarate ? 20 : 16, weight: .black, design: .monospaced))
                                .foregroundStyle(isKarate ? .orange : (combo >= 5 ? Theme.brandCyan : gameMode.accentColor))
                                .shadow(color: isKarate ? .orange.opacity(0.6) : .clear, radius: 8)
                            if !isKarate {
                                Text(String(format: "%.1fx", arcadePhysics.comboMultiplier(for: combo)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            isKarate ? .orange.opacity(0.15) :
                            (combo >= 5 ? Theme.brandCyan.opacity(0.2) : gameMode.accentColor.opacity(0.15))
                        )
                        .clipShape(.rect(cornerRadius: 12))
                        .scaleEffect(combo >= 5 ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: combo)
                        .padding(16)
                    }
                }
            }

            if arcadePhysics.neuralBurstActive && isActive {
                VStack {
                    Spacer()
                    HStack {
                        NeuralBurstIndicator(isActive: true)
                            .padding(16)
                        Spacer()
                    }
                }
            }

            if !lastAction.isEmpty {
                VStack {
                    GameActionFeedback(
                        text: lastAction,
                        isCritical: lastActionIsCritical,
                        isNeuralBurst: lastActionIsBurst,
                        isKarate: isKarate
                    )
                    .padding(.top, 8)
                    Spacer()
                }
            }

            if let judges = lastJudgeScores {
                dunkJudgeOverlay(j1: judges.0, j2: judges.1, j3: judges.2)
            }

            if isDunkContest && isActive && dunkEngine.phase != .idle && dunkEngine.phase != .scored {
                dunkPhaseOverlay
            }

            if (inputScheme == .dragTap || inputScheme == .rallyAce || inputScheme == .penaltyKick) && isActive {
                aimCrosshairOverlay
            }

            if (inputScheme == .swipe || inputScheme == .swipeGolf) && isActive {
                gestureOverlay
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Aim Crosshair (Volleyball)

    @State private var aimAreaSize: CGSize = CGSize(width: 1, height: 1)

    private var aimCrosshairOverlay: some View {
        GeometryReader { geo in
            let x = aimPosition.x * geo.size.width
            let y = aimPosition.y * geo.size.height
            Circle()
                .stroke(gameMode.accentColor, lineWidth: 2)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .fill(gameMode.accentColor.opacity(0.2))
                        .frame(width: 12, height: 12)
                )
                .position(x: x, y: y)
                .allowsHitTesting(false)
                .onAppear { aimAreaSize = geo.size }
                .onChange(of: geo.size) { _, newSize in aimAreaSize = newSize }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isActive else { return }
                    let loc = value.location
                    aimPosition = CGPoint(
                        x: max(0, min(1, loc.x / max(1, aimAreaSize.width))),
                        y: max(0, min(1, loc.y / max(1, aimAreaSize.height)))
                    )
                }
        )
    }

    // MARK: - Swipe Gesture Overlay (Baseball / Soccer / Golf)

    private var gestureOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if swipeStart == nil {
                            swipeStart = value.startLocation
                            swipeStartTime = Date()
                            if inputScheme == .swipeGolf {
                                golfDragStartY = value.startLocation.y
                                withAnimation(.spring(response: 0.2)) {
                                    golfPhase = .backswing
                                }
                            }
                        }
                        if inputScheme == .swipeGolf && golfPhase == .backswing {
                            let dy = value.location.y - golfDragStartY
                            if dy > 0 {
                                withAnimation(.spring(response: 0.15)) {
                                    golfCharge = min(1, Double(dy) / 200)
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        guard isActive else {
                            swipeStart = nil
                            swipeStartTime = nil
                            return
                        }
                        if inputScheme == .swipeGolf {
                            if golfPhase == .backswing && golfCharge > 0.05 {
                                handleGolfRelease(golfCharge)
                            }
                            withAnimation { golfPhase = .idle; golfCharge = 0 }
                        } else {
                            let dx = value.location.x - (swipeStart?.x ?? value.startLocation.x)
                            let dy = value.location.y - (swipeStart?.y ?? value.startLocation.y)
                            let dt = max(0.01, Date().timeIntervalSince(swipeStartTime ?? Date()))
                            let speed = sqrt(dx * dx + dy * dy) / dt
                            handleSwipeEnd(dx: Double(dx), dy: Double(dy), speed: speed)
                        }
                        swipeStart = nil
                        swipeStartTime = nil
                    }
            )
    }

    // MARK: - Dunk Judge Overlay

    private func dunkJudgeOverlay(j1: Int, j2: Int, j3: Int) -> some View {
        let total = j1 + j2 + j3
        let isElite = total >= 140
        return VStack(spacing: 8) {
            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    judgeScoreView(label: "Judge 1", score: j1, isElite: isElite)
                    judgeScoreView(label: "Judge 2", score: j2, isElite: isElite)
                    judgeScoreView(label: "Judge 3", score: j3, isElite: isElite)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.6), .yellow.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .orange.opacity(0.2), radius: 20)
                )

                Text("\(total)")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isElite ? [.yellow, .orange, .yellow] : [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: isElite ? .orange.opacity(0.5) : .clear, radius: 16)

                if !crowdMessage.isEmpty {
                    Text(crowdMessage)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(3)
                        .shadow(color: .orange.opacity(0.6), radius: 12)
                }
            }
            .padding(.bottom, 80)
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func judgeScoreView(label: String, score: Int, isElite: Bool) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)
            Text("\(score)")
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: score >= 47 ? [.yellow, .orange] : [.orange, .orange.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: score >= 47 ? .yellow.opacity(0.5) : .clear, radius: 8)
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 8) {
            if inputScheme == .charge {
                PS2GamepadOverlay(
                    onFaceButton: handlePS2FaceButton,
                    onDPad: handlePS2DPad,
                    onLeftStick: handlePS2LeftStick,
                    onRightStick: handlePS2RightStick,
                    onLeftShoulder: handlePS2LeftShoulder,
                    onRightShoulder: handlePS2RightShoulder,
                    accentColor: gameMode.accentColor,
                    isActive: isActive
                )
                .frame(height: 190)
                .padding(.horizontal, 4)

                if isDunkContest {
                    dunkContestActionButtons
                        .padding(.horizontal, 12)
                }
            } else {
                switch inputScheme {
                case .swipe:
                    swipeHintView
                case .swipeGolf:
                    golfControlView
                case .dragTap:
                    volleyballControlView
                case .kickReturn:
                    kickReturnControlView
                case .rallyAce:
                    rallyAceControlView
                case .penaltyKick:
                    penaltyKickControlView
                case .rhythmTap:
                    rhythmTapControlView
                case .filmQuiz:
                    filmQuizControlView
                case .partyBoard:
                    partyBoardControlView
                default:
                    EmptyView()
                }
            }

            if !isActive && !showResults && gameReady {
                Button {
                    startGame()
                } label: {
                    Text("START MATCH")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(gameMode.accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 12)
            }

        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }



    // MARK: - Swipe Hint (Baseball / Soccer)

    private var swipeHintView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(gameMode.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gameMode.id == .baseball ? "SWIPE TO SWING" : "SWIPE TO SHOOT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(gameMode.id == .baseball ? "Tap gently to bunt" : "Speed = power")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(gameMode.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Golf Control

    private var golfControlView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 20))
                    .foregroundStyle(gameMode.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(golfPhase == .backswing ? "RELEASE TO HIT" : "PULL BACK TO SWING")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Drag down for power, release to hit")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(gameMode.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )

            if golfPhase == .backswing {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.5))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.green, golfCharge > 0.7 ? .red : .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * golfCharge)
                            .animation(.spring(response: 0.2), value: golfCharge)
                    }
                }
                .frame(height: 10)
                .clipShape(.rect(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(gameMode.accentColor.opacity(0.4), lineWidth: 0.5)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    // MARK: - Volleyball Control

    private var volleyballControlView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 20))
                    .foregroundStyle(gameMode.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DRAG TO AIM, TAP TO SPIKE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Aim center for best accuracy")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(gameMode.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )

            Button {
                handleVolleyballSpike()
            } label: {
                Text("TAP TO SPIKE")
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(gameMode.accentColor)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(!isActive)
            .opacity(isActive ? 1 : 0.4)
        }
    }

    // MARK: - Kick Return Control

    private var kickReturnControlView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: footballPhase == .catch ? "hand.raised.fill" : "figure.run")
                    .font(.system(size: 20))
                    .foregroundStyle(gameMode.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(footballPhase == .catch ? "TAP TO CATCH THE KICK" : "TAP IN THE GREEN ZONE!")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(footballPhase == .catch ? "First score wins" : "35-70% = breakaway!")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(gameMode.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )

            if footballPhase == .run {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.5))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.3))
                            .frame(width: geo.size.width * 0.35)
                            .offset(x: geo.size.width * 0.35)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        runMeter >= 35 && runMeter <= 70 ? .green : .red,
                                        gameMode.accentColor
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * (runMeter / 100))
                            .animation(.linear(duration: 0.04), value: runMeter)
                    }
                }
                .frame(height: 14)
                .clipShape(.rect(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(gameMode.accentColor.opacity(0.4), lineWidth: 0.5)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Button {
                if footballPhase == .catch {
                    handleCatchTap()
                } else {
                    handleRunTap()
                }
            } label: {
                Text(footballPhase == .catch ? "CATCH" : "BREAK AWAY!")
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(footballPhase == .run && runMeter >= 35 && runMeter <= 70 ? Color.green : gameMode.accentColor)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(!isActive)
            .opacity(isActive ? 1 : 0.4)
        }
    }

    // MARK: - Rally Ace Control (Tennis / Volleyball)

    private var rallyAceControlView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: gameMode.id == .tennis ? "tennis.racket" : "volleyball.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(gameMode.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DRAG TO AIM, TAP TO HIT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(gameMode.id == .tennis ? "Time your returns" : "Spike over the net")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(gameMode.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )

            HStack(spacing: 10) {
                Button {
                    handleRallyHit(type: gameMode.id == .tennis ? "Forehand" : "Bump")
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: gameMode.id == .tennis ? "arrow.right" : "hand.raised.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(gameMode.id == .tennis ? "FOREHAND" : "BUMP")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(gameMode.accentColor)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)

                Button {
                    handleRallyHit(type: gameMode.id == .tennis ? "Backhand" : "Set")
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: gameMode.id == .tennis ? "arrow.left" : "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                        Text(gameMode.id == .tennis ? "BACKHAND" : "SET")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(gameMode.accentColor.opacity(0.25))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.4), lineWidth: 1)
                    )
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)

                Button {
                    handleRallyHit(type: gameMode.id == .tennis ? "Serve" : "Spike")
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: gameMode.id == .tennis ? "arrow.up.right" : "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(gameMode.id == .tennis ? "SERVE" : "SPIKE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(gameMode.accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(gameMode.accentColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)
            }
        }
    }

    // MARK: - Penalty Kick Control

    private var penaltyKickControlView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "soccerball")
                    .font(.system(size: 20))
                    .foregroundStyle(gameMode.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AIM & SHOOT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Drag to aim, tap to kick")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(gameMode.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )

            HStack(spacing: 10) {
                Button {
                    handlePenaltyKick(power: .low)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                        Text("LOW")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(gameMode.accentColor.opacity(0.2))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)

                Button {
                    handlePenaltyKick(power: .mid)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                        Text("MID")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(gameMode.accentColor)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)

                Button {
                    handlePenaltyKick(power: .high)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .bold))
                        Text("HIGH")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(gameMode.accentColor.opacity(0.2))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)
            }
        }
    }

    private enum KickPower { case low, mid, high }

    // MARK: - Rhythm tap (gym + extreme sports)

    private var rhythmTapControlView: some View {
        rhythmTapChrome(
            headerTitle: "TAP TO PERFORM",
            headerSubtitle: "Time your moves for bonus points"
        )
    }

    private var filmQuizControlView: some View {
        rhythmTapChrome(
            headerTitle: "CLIP QUIZ",
            headerSubtitle: "Recognition rounds — not the same loop as Brain Brawl"
        )
    }

    private var partyBoardControlView: some View {
        rhythmTapChrome(
            headerTitle: "BOARD SPACES",
            headerSubtitle: "Party carnival loop — roll the lane, hit events"
        )
    }

    private func rhythmTapChrome(headerTitle: String, headerSubtitle: String) -> some View {
        let actions = actionsForMode
        let icons = rhythmTapIconsForMode(gameMode.id)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: rhythmTapHeaderIcon(gameMode.id))
                    .font(.system(size: 20))
                    .foregroundStyle(gameMode.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(headerSubtitle)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(gameMode.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(gameMode.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )

            HStack(spacing: 10) {
                rhythmTapButton(title: actions.indices.contains(0) ? actions[0] : "—", symbol: icons.indices.contains(0) ? icons[0] : "circle", role: .primary) {
                    if actions.indices.contains(0) { performAction(actions[0]) }
                }
                rhythmTapButton(title: actions.indices.contains(1) ? actions[1] : "—", symbol: icons.indices.contains(1) ? icons[1] : "circle", role: .secondary) {
                    if actions.indices.contains(1) { performAction(actions[1]) }
                }
                rhythmTapButton(title: actions.indices.contains(2) ? actions[2] : "—", symbol: icons.indices.contains(2) ? icons[2] : "circle", role: .tertiary) {
                    if actions.indices.contains(2) { performAction(actions[2]) }
                }
            }
        }
    }

    private enum RhythmTapButtonRole {
        case primary, secondary, tertiary
    }

    @ViewBuilder
    private func rhythmTapButton(title: String, symbol: String, role: RhythmTapButtonRole, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
            }
            .foregroundStyle(foregroundForRhythmRole(role))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundForRhythmRole(role))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(strokeForRhythmRole(role), lineWidth: 1)
            )
        }
        .disabled(!isActive)
        .opacity(isActive ? 1 : 0.4)
    }

    private func foregroundForRhythmRole(_ role: RhythmTapButtonRole) -> Color {
        switch role {
        case .primary: return .black
        case .secondary: return .white
        case .tertiary: return gameMode.accentColor
        }
    }

    private func backgroundForRhythmRole(_ role: RhythmTapButtonRole) -> Color {
        switch role {
        case .primary: return gameMode.accentColor
        case .secondary: return gameMode.accentColor.opacity(0.25)
        case .tertiary: return gameMode.accentColor.opacity(0.12)
        }
    }

    private func strokeForRhythmRole(_ role: RhythmTapButtonRole) -> Color {
        switch role {
        case .primary: return .clear
        case .secondary: return gameMode.accentColor.opacity(0.4)
        case .tertiary: return gameMode.accentColor.opacity(0.3)
        }
    }

    private func rhythmTapHeaderIcon(_ mode: GameModeId) -> String {
        switch mode {
        case .gymnastics: return "figure.gymnastics"
        case .surfing: return "water.waves"
        case .skateboarding: return "figure.skating"
        case .snowboarding: return "snowflake"
        case .brainBrawl: return "brain.head.profile"
        case .whoSceneIt: return "theatermasks.fill"
        case .courtCarnival: return "sparkles.rectangle.stack"
        default: return "figure.mixed.cardio"
        }
    }

    private func rhythmTapIconsForMode(_ mode: GameModeId) -> [String] {
        switch mode {
        case .gymnastics:
            return ["arrow.triangle.2.circlepath", "figure.gymnastics", "sparkles"]
        case .surfing:
            return ["water.waves", "point.topleft.down.to.point.bottomright.fill", "wind"]
        case .skateboarding:
            return ["figure.skating", "square.grid.2x2", "arrow.trianglehead.branch"]
        case .snowboarding:
            return ["snowflake", "arrow.up.circle", "line.diagonal"]
        case .brainBrawl:
            return ["eye.circle", "square.grid.3x3", "shield.lefthalf.filled"]
        case .whoSceneIt:
            return ["theatermasks.fill", "film.fill", "person.fill.questionmark"]
        case .courtCarnival:
            return ["dice.fill", "sparkles", "bolt.fill"]
        default:
            return ["circle", "circle", "circle"]
        }
    }

    private var academyRhythmOverlay: some View {
        let roundLabel: String
        let subtitle: String
        switch gameMode.id {
        case .whoSceneIt:
            roundLabel = "Q\(roundNumber)/\(maxRounds)"
            subtitle = "CLIP"
        case .courtCarnival:
            roundLabel = "S\(roundNumber)/\(maxRounds)"
            subtitle = "BOARD"
        default:
            roundLabel = "R\(roundNumber)/\(maxRounds)"
            subtitle = "ROUTINE"
        }
        return VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text(roundLabel)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(gameMode.accentColor)
                    Text(subtitle)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.5))
                )
                .padding(.trailing, 16)
                .padding(.bottom, 100)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Dunk Contest Controls (Arcade-Tactical)

    private var dunkContestActionButtons: some View {
        VStack(spacing: 10) {
            switch dunkEngine.phase {
            case .idle:
                dunkTrickSelector
                dunkModifierBar
                dunkStartButton
            case .approach:
                dunkSprintChargeView
            case .launch:
                dunkLaunchTimingView
            case .airborne:
                dunkArcadeAirborneControls
            case .landing:
                dunkLandingTimingView
            case .scored:
                EmptyView()
            }
        }
    }

    private var dunkModifierBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.15)) {
                    styleTriggerHeld.toggle()
                    dunkEngine.setModifier(styleTrigger: styleTriggerHeld, powerTrigger: powerTriggerHeld)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "l2.button.roundedbottom.horizontal")
                        .font(.system(size: 11, weight: .bold))
                    Text("STYLE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundStyle(styleTriggerHeld ? .black : .purple)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(styleTriggerHeld ? Color.purple : Color.purple.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                        )
                )
            }

            VStack(spacing: 2) {
                Text(dunkEngine.activeModifier.label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(modifierLabelColor)
                    .tracking(1)
                Text(String(format: "%.1fx", dunkEngine.activeModifier.scoreMultiplier))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(width: 70)

            Button {
                withAnimation(.spring(response: 0.15)) {
                    powerTriggerHeld.toggle()
                    dunkEngine.setModifier(styleTrigger: styleTriggerHeld, powerTrigger: powerTriggerHeld)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "r2.button.roundedbottom.horizontal")
                        .font(.system(size: 11, weight: .bold))
                    Text("POWER")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundStyle(powerTriggerHeld ? .black : .red)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(powerTriggerHeld ? Color.red : Color.red.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var modifierLabelColor: Color {
        switch dunkEngine.activeModifier {
        case .standard: return .white.opacity(0.6)
        case .flashy: return .purple
        case .power: return .red
        case .signature: return .yellow
        }
    }

    private var dunkTrickSelector: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
                Text("SELECT TRICK")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.orange)
                    .tracking(2)
                Spacer()
                Text("R\(dunkEngine.round)/\(dunkEngine.totalRounds)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DunkTrickSlot.allCases, id: \.rawValue) { trick in
                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                dunkEngine.selectedTrick = trick
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: trick.icon)
                                    .font(.system(size: 16, weight: .bold))
                                Text(trick.rawValue)
                                    .font(.system(size: 7, weight: .black, design: .monospaced))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                HStack(spacing: 2) {
                                    ForEach(0..<5, id: \.self) { i in
                                        Circle()
                                            .fill(Double(i) / 5.0 < trick.complexity ? .orange : .white.opacity(0.15))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                            }
                            .foregroundStyle(dunkEngine.selectedTrick == trick ? .black : .white)
                            .frame(width: 72, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(dunkEngine.selectedTrick == trick ? .orange : .orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(dunkEngine.selectedTrick == trick ? .orange : .orange.opacity(0.25), lineWidth: 1.5)
                                    )
                            )
                        }
                        .disabled(!isActive)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private var dunkStartButton: some View {
        Button {
            startDunkApproach()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.run")
                    .font(.system(size: 18, weight: .bold))
                Text("START APPROACH")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.orange, Color(red: 1.0, green: 0.5, blue: 0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .orange.opacity(0.3), radius: 12)
        }
        .disabled(!isActive)
        .opacity(isActive ? 1 : 0.5)
    }

    private var dunkSprintChargeView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("HOLD TO SPRINT")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(1)
                Spacer()
                Text("\(Int(dunkEngine.sprintCharge * 100))%")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.6))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, dunkEngine.sprintCharge > 0.8 ? .orange : .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * dunkEngine.sprintCharge)
                        .animation(.linear(duration: 0.05), value: dunkEngine.sprintCharge)
                }
            }
            .frame(height: 14)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.cyan.opacity(0.4), lineWidth: 1)
            )

            Button {
                releaseDunkSprint()
            } label: {
                Text("RELEASE TO LAUNCH")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var dunkLaunchTimingView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
                Text("TAP TO JUMP")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(1)
                Spacer()
            }

            dunkTimingBar(
                value: dunkEngine.launchTiming,
                greenZone: dunkEngine.launchGreenZone,
                accentColor: .green
            )

            Button {
                confirmDunkLaunch()
            } label: {
                Text("JUMP!")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        dunkEngine.launchGreenZone.contains(dunkEngine.launchTiming)
                            ? Color.green
                            : Color.green.opacity(0.4)
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: .green.opacity(0.3), radius: 8)
            }
        }
    }

    private var dunkArcadeAirborneControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "figure.highintensity.intervaltraining")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.purple)
                Text(dunkEngine.selectedTrick.rawValue)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(1)
                Spacer()
                if dunkEngine.midAirState.branchCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(dunkEngine.midAirState.branchCount)x CHAIN")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.yellow)
                }
                Text("\(Int(dunkEngine.completedRotation * 100))%")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(dunkEngine.completedRotation >= 0.9 ? .green : .purple)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.6))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [.purple, dunkEngine.completedRotation >= 0.9 ? .green : .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(1, dunkEngine.completedRotation))
                        .animation(.linear(duration: 0.05), value: dunkEngine.completedRotation)
                }
            }
            .frame(height: 8)
            .clipShape(.rect(cornerRadius: 5))

            if !dunkEngine.midAirState.trickChainLabel.isEmpty {
                Text(dunkEngine.midAirState.trickChainLabel)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.8))
                    .lineLimit(1)
                    .transition(.opacity)
            }

            HStack(spacing: 6) {
                ForEach(ArcadeFaceButton.allCases, id: \.rawValue) { button in
                    Button {
                        handleArcadeDunkButton(button)
                    } label: {
                        VStack(spacing: 3) {
                            Text(button.symbol)
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(Color(
                                    red: button.displayColor.r,
                                    green: button.displayColor.g,
                                    blue: button.displayColor.b
                                ))
                            Text(button.dunkCategory.uppercased())
                                .font(.system(size: 6, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(
                                    red: button.displayColor.r,
                                    green: button.displayColor.g,
                                    blue: button.displayColor.b
                                ).opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(
                                            red: button.displayColor.r,
                                            green: button.displayColor.g,
                                            blue: button.displayColor.b
                                        ).opacity(0.35), lineWidth: 1.5)
                                )
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                dunkModifierBar
            }

            HStack(spacing: 10) {
                if dunkEngine.styleLandingWindow {
                    Button {
                        handleStyleLanding()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "l1.button.roundedbottom.horizontal")
                                .font(.system(size: 11, weight: .bold))
                            Text("STYLE LAND")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                        }
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
                        .shadow(color: .cyan.opacity(0.4), radius: 8)
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                Button {
                    confirmDunkLanding()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 13, weight: .bold))
                        Text("SLAM!")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 12))
                    .shadow(color: .orange.opacity(0.4), radius: 8)
                }
            }

            if dunkEngine.totalFreestylePoints > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    Text("FREESTYLE: +\(dunkEngine.totalFreestylePoints)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                    if dunkEngine.midAirState.comboMultiplier > 1.0 {
                        Text(String(format: "(%.1fx)", dunkEngine.midAirState.comboMultiplier))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.yellow.opacity(0.7))
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var dunkLandingTimingView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
                Text("STICK THE LANDING!")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(1)
                Spacer()
            }

            dunkTimingBar(
                value: dunkEngine.landingTiming,
                greenZone: dunkEngine.landingGreenZone,
                accentColor: .orange
            )

            Button {
                confirmDunkLanding()
            } label: {
                Text("LAND!")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        dunkEngine.landingGreenZone.contains(dunkEngine.landingTiming)
                            ? Color.orange
                            : Color.orange.opacity(0.4)
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: .orange.opacity(0.3), radius: 8)
            }
        }
    }

    private func dunkTimingBar(value: Double, greenZone: ClosedRange<Double>, accentColor: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
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
        .frame(height: 20)
        .clipShape(.rect(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var dunkPhaseOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Text(dunkPhaseLabel)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(dunkPhaseColor)
                        .tracking(2)
                    if dunkEngine.phase == .airborne {
                        Text(String(format: "HEIGHT: %.0f%%", dunkEngine.jumpHeight * 100))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(dunkPhaseColor.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.trailing, 16)
                .padding(.bottom, 100)
            }
        }
        .allowsHitTesting(false)
    }

    private var dunkPhaseLabel: String {
        switch dunkEngine.phase {
        case .approach: return "SPRINTING"
        case .launch: return "GATHER"
        case .airborne: return "IN THE AIR"
        case .landing: return "LANDING"
        default: return ""
        }
    }

    private var dunkPhaseColor: Color {
        switch dunkEngine.phase {
        case .approach: return .cyan
        case .launch: return .green
        case .airborne: return .purple
        case .landing: return .orange
        default: return .white
        }
    }

    // MARK: - PS2-Style Action Buttons

    private var ps2ActionButtons: some View {
        let actions = actionsForMode
        let ps2Layout = ps2ButtonLayout(for: actions)

        return HStack(spacing: 12) {
            ForEach(Array(ps2Layout.enumerated()), id: \.offset) { index, btn in
                Button {
                    performAction(btn.action)
                } label: {
                    VStack(spacing: 4) {
                        Text(btn.symbol)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(btn.color)
                        Text(btn.action.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(btn.color.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(btn.color.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)
                .accessibilityLabel("\(btn.label) – \(btn.action)")
            }
        }
    }

    private struct PS2Button {
        let symbol: String
        let color: Color
        let label: String
        let action: String
    }

    private func ps2ButtonLayout(for actions: [String]) -> [PS2Button] {
        let ps2Colors: [(String, Color, String)] = [
            ("△", Color(red: 0.3, green: 0.78, blue: 0.47), "Triangle"),
            ("□", Color(red: 0.96, green: 0.44, blue: 0.71), "Square"),
            ("○", Color(red: 0.97, green: 0.44, blue: 0.44), "Circle"),
            ("✕", Color(red: 0.38, green: 0.65, blue: 0.98), "Cross"),
        ]

        return actions.enumerated().map { index, action in
            let ps2 = ps2Colors[index % ps2Colors.count]
            return PS2Button(symbol: ps2.0, color: ps2.1, label: ps2.2, action: action)
        }
    }

    private var actionsForMode: [String] {
        switch gameMode.id {
        case .basketballHeadToHead: ["Shoot", "Drive", "Crossover"]
        case .basketballDunkContest: ["Power Dunk", "360 Dunk", "Windmill"]
        case .basketball3v3: ["Pass", "Shoot", "Drive"]
        case .karate, .karateEndless: ["Punch", "Kick", "Block"]
        case .baseball: ["Swing", "Bunt"]
        case .football: ["Catch", "Break Away"]
        case .soccer: ["Shoot"]
        case .golf: ["Swing"]
        case .tennis: ["Serve", "Volley", "Baseline"]
        case .volleyball: ["Spike"]
        case .gymnastics: ["Tumble", "Vault", "Dismount"]
        case .surfing: ["Snap", "Carve", "Aerial"]
        case .skateboarding: ["Ollie", "Grind", "Kickflip"]
        case .snowboarding: ["Carve", "Jump", "Butter"]
        case .brainBrawl: ["Focus", "Pattern", "Counter"]
        case .whoSceneIt: ["Freeze", "Spot Star", "Recall"]
        case .courtCarnival: ["Mini", "Roll", "Boost"]
        }
    }

    private var matchLobbyOverlay: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("MULTIPLAYER SETUP")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(gameMode.accentColor)
                Text(gameMode.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Session key: \(gameMode.id.rawValue)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                if multipeerService.pendingInvitationPeerName != nil {
                    Text("Incoming invite — use Accept or Decline in the toolbar.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                HStack(spacing: 16) {
                    Button {
                        multipeerService.startHosting(gameId: gameMode.id.rawValue)
                    } label: {
                        Label("HOST", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.brandCyan.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Button {
                        multipeerService.startBrowsing(gameId: gameMode.id.rawValue)
                    } label: {
                        Label("JOIN", systemImage: "magnifyingglass")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Button {
                    withAnimation(.spring(response: 0.35)) { matchLobbyComplete = true }
                } label: {
                    Text("CONTINUE TO COUNTDOWN")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(gameMode.accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .padding(28)
        }
    }

    private var apexQTETapOverlay: some View {
        VStack {
            Spacer()
            Button {
                commitApexQTEResolution()
            } label: {
                Text("APEX — TAP NOW")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Theme.brandCyan, gameMode.accentColor], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: gameMode.accentColor.opacity(0.45), radius: 14)
            }
            .padding(.bottom, 130)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.38).ignoresSafeArea())
    }

    private var peerStatusBadge: some View {
        Group {
            if multipeerService.isConnected {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("P2P")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                    Text("LOCAL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.04))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Rewards Logic

    @available(*, unavailable)
    private var _resultsOverlayRemoved: some View { EmptyView()
    }

    private var rewardsBreakdown: some View {
        VStack(spacing: 6) {
            ForEach(shardRewards, id: \.transaction.rawValue) { reward in
                HStack {
                    Text(reward.transaction.rawValue.replacingOccurrences(of: "game", with: "").uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("+\(reward.amount)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var rewardsRow: some View {
        HStack(spacing: 20) {
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.brandCyan)
                Text("+\(shardsReward)")
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.brandBlue)
                Text(String(format: "+%.1f PRQ", prqReward))
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var shardRewards: [ShardReward] {
        let flags = VersusMatchOutcome.rewardFlags(playerScore: score, opponentScore: opponentScore)
        return ShardReward.forGameResult(
            won: flags.won,
            tied: flags.tied,
            combo: maxCombo,
            criticals: criticalHits,
            participationEligible: participationEligibleForRewards
        )
    }

    private var shardsReward: Int {
        shardRewards.reduce(0) { $0 + $1.amount }
    }

    private var prqReward: Double {
        let flags = VersusMatchOutcome.rewardFlags(playerScore: score, opponentScore: opponentScore)
        return PRQ.rankingSessionPRQ(
            mode: gameMode.id,
            won: flags.won,
            tied: flags.tied,
            combo: maxCombo,
            criticals: criticalHits,
            scoreDifferential: score - opponentScore,
            participationEligible: participationEligibleForRewards,
            sessionReadiness: sessionReadiness
        )
    }

    // MARK: - Game Logic

    private func startGame() {
        matchSessionId = UUID()
        finalizedMatchSessionId = nil
        delayedOpponentScoreGeneration = 0
        lastGameplayLeakagePenaltyAt = [:]
        playerActionCount = 0
        pendingGoldenApex = nil
        lastCommittedTrickDirection = .up
        sessionStartedAt = Date()

        withAnimation { isActive = true }
        score = 0
        opponentScore = 0
        combo = 0
        maxCombo = 0
        criticalHits = 0
        roundNumber = 1
        dunkRound = 1
        lastJudgeScores = nil
        crowdMessage = ""
        dunkEngine = DunkContestState(sessionSeed: GameplaySeed.uint64(from: matchSessionId))
        dunkTimerTask?.cancel()
        dunkTimerTask = nil
        styleTriggerHeld = false
        powerTriggerHeld = false
        showComboChain = false
        comboChainText = ""
        showStyleLanding = false
        styleLandingBonus = 0
        showRimDistortion = false
        chakraBar = 0
        specialMeter = 0
        isModifierHeld = false
        currentTrickDirection = .neutral
        lastTrickName = ""
        showTrickText = false
        isSlowMo = false
        slowMoTimer?.cancel()
        slowMoTimer = nil
        showPerfectGuard = false
        showVanishFlash = false
        showResults = false
        golfCharge = 0
        golfPhase = .idle
        footballPhase = .catch
        runMeter = 0
        runMeterTimer?.cancel()
        runMeterTimer = nil
        swipeStart = nil
        swipeStartTime = nil
        aimPosition = CGPoint(x: 0.5, y: 0.5)
        defensiveState = DefensiveInputState()
        lastContestPercent = nil
        lastContestLabel = nil
        lastContestTier = nil
        showContestPill = false
        defenderSimDistance = 4.0

        goldenComboEngine = GoldenEraComboEngine()
        timeScaleManager = TimeScaleManager()
        matrixState = MatrixStateMachine()
        activeModifierState = .none
        lastQTEGrade = nil
        showQTEGrade = false
        qteGradeText = ""
        timeScaleUpdateTask?.cancel()
        timeScaleUpdateTask = nil

        if isTimerBased {
            timeRemaining = max(1, gameRules.matchDurationSeconds)
            startTimer()
        }
    }

    private func resetGame() {
        withAnimation { showResults = false }
        startGame()
    }

    @State private var gameTimerTask: Task<Void, Never>?

    private func startTimer() {
        gameTimerTask?.cancel()
        gameTimerTask = Task {
            while !Task.isCancelled && isActive && timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, isActive else { return }
                withAnimation(.spring(response: 0.2)) { timeRemaining -= 1 }
                if timeRemaining <= 10 && timeRemaining > 0 {
                    triggerScreenShake(intensity: 0.1)
                }
                if timeRemaining <= 0 {
                    endGame()
                }
            }
        }
    }

    private func performAction(_ action: String) {
        guard isActive else { return }
        playerActionCount += 1

        let physics = leakageAdjustedPhysics
        let modeChance = PRQ.successChanceFromPRQ(playerPRQ, for: gameMode.id)
        let blendedChance = (physics.successChanceBase + modeChance) / 2.0
        let contestedChance = applyContestToShot(baseChance: blendedChance)
        let driveMultiplier = defensiveState.driveSpeedMultiplier
        let effectiveChance = (action == "Drive" || action == "Crossover") ? contestedChance * driveMultiplier : contestedChance
        let success = Double.random(in: 0...1) < effectiveChance
        let isCritical = success && Double.random(in: 0...1) < physics.criticalHitChance
        let basePoints = pointsForAction(action, success: success)
        let finalPoints = success ? physics.adjustedPoints(base: basePoints, combo: combo, isCritical: isCritical) : 0

        if success {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                score += finalPoints
                combo += 1
                maxCombo = max(maxCombo, combo)
                lastActionIsCritical = isCritical
                lastActionIsBurst = arcadePhysics.neuralBurstActive

                if isKarate {
                    lastAction = karateSuccessFeedback(action: action, isCritical: isCritical, points: finalPoints)
                } else if isCritical {
                    criticalHits += 1
                    lastAction = "CRITICAL \(action.uppercased()) +\(finalPoints)"
                } else if arcadePhysics.neuralBurstActive {
                    lastAction = "BURST \(action.uppercased()) +\(finalPoints)"
                } else {
                    lastAction = "\(action.uppercased()) +\(finalPoints)"
                }
            }

            withAnimation(.spring(response: 0.2)) {
                specialMeter = min(100, specialMeter + arcadePhysics.specialMeterGainRate * (isCritical ? 1.5 : 1.0))
            }

            if isKarate {
                withAnimation(.spring(response: 0.2)) {
                    chakraBar = min(100, chakraBar + 25)
                }
                triggerKarateHitFlash()
                triggerScreenShake(intensity: isCritical ? 0.8 : 0.5)
                if isCritical {
                    criticalHits += 1
                    triggerCriticalFlash()
                }
            } else if isCritical {
                triggerCriticalFlash()
                triggerScreenShake(intensity: 0.6)
            } else {
                triggerFlash()
                triggerScreenShake(intensity: Double(physicsConfig.floorShakeAmplitude) * 10)
            }

            triggerImpactFlash()
            resetStreakTimer()
            hapticSuccess(isCritical: isCritical)

        } else {
            withAnimation(.spring(response: 0.3)) {
                combo = 0
                if isKarate {
                    lastAction = karateFailFeedback()
                    chakraBar = max(0, chakraBar - 10)
                } else {
                    lastAction = "MISSED"
                }
                lastActionIsCritical = false
                lastActionIsBurst = false
            }
            hapticFail()
        }

        let dda = prqDDA
        let ddaAggression = dda.scaledAggression(playerScore: score, aiScore: opponentScore)
        let ddaChance = DynamicDifficulty.opponentSuccessChance(
            baseChance: 0.55 * ddaAggression,
            playerScore: score,
            aiScore: opponentScore,
            sessionReadiness: sessionReadiness,
            playerPRQ: playerPRQ
        )
        if !multipeerService.isConnected, Double.random(in: 0...1) < ddaChance {
            delayedOpponentScoreGeneration += 1
            let generation = delayedOpponentScoreGeneration
            let aiDelay = dda.aiReactionSpeed(playerScore: score, aiScore: opponentScore)
            Task {
                try? await Task.sleep(for: .seconds(aiDelay))
                guard isActive, generation == delayedOpponentScoreGeneration else { return }
                withAnimation(.spring(response: 0.25)) {
                    opponentScore += DynamicDifficulty.opponentPoints(
                        playerScore: score,
                        aiScore: opponentScore,
                        maxPoints: DynamicDifficulty.prqScaledOpponentMaxPoints(playerPRQ: playerPRQ, mode: gameMode.id)
                    )
                }
            }
        }

        if multipeerService.isConnected {
            multipeerService.sendAction(action, score: score)
        }

        if isBlacktop && score >= targetScore {
            endGame()
        } else if !isTimerBased && !isDunkContest && !isBlacktop {
            roundNumber += 1
            if roundNumber > maxRounds {
                endGame()
            }
        }

        let clearDelay: Double = isKarate ? 1.5 : 2.0
        Task {
            try? await Task.sleep(for: .seconds(clearDelay))
            guard isActive else { return }
            withAnimation { lastAction = "" }
        }
    }

    // MARK: - Karate Feedback

    private func karateSuccessFeedback(action: String, isCritical: Bool, points: Int) -> String {
        let successStrings = ["IPPON!", "STRIKE!", "COUNTER!", "HIT!", "BURST!", "CRITICAL!"]
        let base = successStrings.randomElement() ?? "HIT!"
        if isCritical {
            return "⚡ \(base) +\(points)"
        }
        return "\(base) +\(points)"
    }

    private func karateFailFeedback() -> String {
        let failStrings = ["BLOCKED!", "MISS!", "SUBSTITUTION!", "DODGED!"]
        return failStrings.randomElement() ?? "BLOCKED!"
    }

    private func triggerKarateHitFlash() {
        withAnimation(.easeOut(duration: 0.05)) { karateHitFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeIn(duration: 0.1)) { karateHitFlash = false }
        }
    }

    // MARK: - Arcade Dunk Button Handler

    private func handleArcadeDunkButton(_ button: ArcadeFaceButton) {
        guard isActive, dunkEngine.phase == .airborne else { return }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
            dunkEngine.processArcadeInput(button: button)
            let trick = dunkEngine.selectedTrick
            lastTrickName = trick.rawValue
            showTrickText = true
            lastAction = "+\(dunkEngine.totalFreestylePoints)"
        }
        triggerFlash()
        triggerScreenShake(intensity: 0.3)
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showTrickText = false; lastTrickName = "" }
        }
    }

    private func handleStyleLanding() {
        guard isActive, dunkEngine.styleLandingWindow else { return }
        let bonus = dunkEngine.attemptStyleLanding()
        if bonus > 0 {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                styleLandingBonus = bonus
                showStyleLanding = true
                lastAction = "STYLE LANDING! +\(bonus)"
            }
            triggerFlash()
            triggerScreenShake(intensity: 0.5)
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                withAnimation { showStyleLanding = false; lastAction = "" }
            }
        }
    }

    // MARK: - Dunk Contest Phase Logic

    private func startDunkApproach() {
        guard isActive, dunkEngine.phase == .idle else { return }
        withAnimation(.spring(response: 0.2)) {
            dunkEngine.startApproach()
            lastAction = "HOLD TO SPRINT!"
        }
        dunkTimerTask?.cancel()
        dunkTimerTask = Task {
            while !Task.isCancelled && dunkEngine.phase == .approach && dunkEngine.isSprintHeld {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.016)) {
                    dunkEngine.sprintCharge = min(1.0, dunkEngine.sprintCharge + 0.016 * dunkEngine.sprintChargeRate)
                }
                if dunkEngine.sprintCharge >= 1.0 {
                    releaseDunkSprint()
                    return
                }
            }
        }
    }

    private func releaseDunkSprint() {
        guard dunkEngine.phase == .approach else { return }
        dunkTimerTask?.cancel()
        withAnimation(.spring(response: 0.2)) {
            dunkEngine.releaseSprint()
        }
        dunkTimerTask = Task {
            while !Task.isCancelled && dunkEngine.phase == .launch {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.016)) {
                    dunkEngine.launchTiming += dunkEngine.launchTimingDirection * dunkEngine.launchTimingSpeed * 0.016
                    if dunkEngine.launchTiming >= 1.0 { dunkEngine.launchTimingDirection = -1 }
                    if dunkEngine.launchTiming <= 0.0 { dunkEngine.launchTimingDirection = 1 }
                    dunkEngine.launchTiming = max(0, min(1, dunkEngine.launchTiming))
                }
            }
        }
    }

    private func confirmDunkLaunch() {
        guard dunkEngine.phase == .launch else { return }
        dunkTimerTask?.cancel()
        let inGreen = dunkEngine.launchGreenZone.contains(dunkEngine.launchTiming)
        if inGreen {
            triggerFlash()
        }
        withAnimation(.spring(response: 0.2)) {
            dunkEngine.confirmLaunch()
            lastAction = inGreen ? "PERFECT LAUNCH!" : "LAUNCHED"
        }
        triggerScreenShake(intensity: inGreen ? 0.4 : 0.2)

        dunkTimerTask = Task {
            while !Task.isCancelled && (dunkEngine.phase == .airborne || dunkEngine.phase == .landing) {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.016)) {
                    dunkEngine.updateAirborne(delta: 0.016)
                }
                if dunkEngine.showApexFreeze && !isSlowMo {
                    triggerSlowMo(duration: 0.8)
                }
                if dunkEngine.phase == .landing && !dunkEngine.styleLandingWindow {
                    break
                }
            }
            if !Task.isCancelled && dunkEngine.phase == .landing {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                if dunkEngine.phase == .landing {
                    confirmDunkLanding()
                }
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation { if lastAction == "PERFECT LAUNCH!" || lastAction == "LAUNCHED" { lastAction = "" } }
        }
    }

    private func confirmDunkLanding() {
        guard dunkEngine.phase == .airborne || dunkEngine.phase == .landing else { return }
        dunkTimerTask?.cancel()
        withAnimation(.spring(response: 0.15)) {
            dunkEngine.confirmLanding()
        }
        executeDunkScoring()
    }

    private func executeDunkScoring() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        var judgeRNG = SplitMix64(seed: GameplaySeed.uint64(from: matchSessionId) &+ UInt64(dunkEngine.round) &+ 0x6A75647F)
        let result = dunkEngine.calculateDunkScore(
            prq: playerPRQ,
            neuralBurst: arcadePhysics.neuralBurstActive,
            judgeRNG: &judgeRNG
        )

        withAnimation(.spring(response: 0.3)) {
            lastJudgeScores = (result.j1, result.j2, result.j3)
            crowdMessage = result.message
            score += result.total
            dunkEngine.roundScores.append((round: dunkEngine.round, score: result.total, message: result.message))
        }

        let impactLevel = dunkEngine.impactIntensity
        triggerScreenShake(intensity: 0.5 + impactLevel * 0.5)
        triggerImpactFlash()
        if result.total >= 138 {
            triggerCriticalFlash()
            triggerSlowMo(duration: 1.5)
        } else if result.total >= 120 {
            triggerFlash()
        }

        if dunkEngine.landingQuality > 0.7 {
            withAnimation(.spring(response: 0.2)) {
                lastTrickName = dunkEngine.selectedTrick.rawValue
                showTrickText = true
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(4.0))
            guard isActive else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                lastJudgeScores = nil
                crowdMessage = ""
                showTrickText = false
                lastTrickName = ""
                lastAction = ""
            }

            try? await Task.sleep(for: .seconds(0.5))
            guard isActive else { return }
            simulateAIDunk()

            try? await Task.sleep(for: .seconds(3.5))
            guard isActive else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                lastJudgeScores = nil
                crowdMessage = ""
                lastAction = ""
            }

            withAnimation(.spring(response: 0.3)) {
                dunkEngine.advanceRound()
                dunkRound = dunkEngine.round
            }
            if dunkEngine.isComplete {
                endGame()
            }
        }
    }

    private func simulateAIDunk() {
        guard !multipeerService.isConnected else { return }
        var rng = SplitMix64(seed: GameplaySeed.aiDunkProfileSeed(matchSeed: GameplaySeed.uint64(from: matchSessionId), round: dunkEngine.round))
        let aiPRQ = 50.0 + Double(rng.next() % 31)
        let aiNormalized = aiPRQ / 100.0
        let dda = prqDDA
        let aggression = dda.scaledAggression(playerScore: score, aiScore: opponentScore)

        let aiHeight = rng.nextDouble(in: 0.4...0.85) * aggression
        let aiExecution = rng.nextDouble(in: 0.5...0.9) * aggression
        let aiTrick = rng.nextDouble(in: 0.5...0.8)

        let rawScore = (aiHeight * 20 + aiTrick * 25 + aiExecution * 20 + 15) * (0.85 + aiNormalized * 0.15)
        let base = min(50, Int(rawScore / 3.0) + 28)
        let spread = max(1, 4)
        let span = UInt64(spread)
        let j1 = min(50, base + Int(rng.next() % span))
        let j2 = min(50, base + Int(rng.next() % span))
        let j3 = min(50, base + Int(rng.next() % span))
        let total = j1 + j2 + j3

        let message: String
        if total >= 140 { message = "AI: LEGENDARY!" }
        else if total >= 130 { message = "AI: ELECTRIFYING!" }
        else if total >= 120 { message = "AI: POWERFUL!" }
        else if total >= 110 { message = "AI: SOLID DUNK" }
        else { message = "AI: NEEDS WORK" }

        withAnimation(.spring(response: 0.3)) {
            opponentScore += total
            lastJudgeScores = (j1, j2, j3)
            crowdMessage = message
            lastAction = "OPPONENT: +\(total)"
        }
        triggerScreenShake(intensity: 0.3)
    }


    private func resetStreakTimer() {
        streakTimer?.cancel()
        streakTimer = Task {
            try? await Task.sleep(for: .seconds(arcadePhysics.comboDecayRate))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3)) {
                combo = 0
            }
        }
    }

    private func triggerCriticalFlash() {
        withAnimation(.easeOut(duration: 0.1)) { showCriticalFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeIn(duration: 0.4)) { showCriticalFlash = false }
        }
    }

    private func triggerImpactFlash() {
        withAnimation(.easeOut(duration: 0.05)) { showImpactFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeIn(duration: 0.2)) { showImpactFlash = false }
        }
    }

    private func triggerScreenShake(intensity: Double) {
        let amplitude = intensity * 4
        Task {
            for _ in 0..<4 {
                withAnimation(.linear(duration: 0.03)) {
                    screenShake = CGFloat.random(in: -amplitude...amplitude)
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
            withAnimation(.spring(response: 0.1)) {
                screenShake = 0
            }
        }
    }

    private func pointsForAction(_ action: String, success: Bool) -> Int {
        guard success else { return 0 }
        switch gameMode.id {
        case .basketballHeadToHead:
            return action == "Shoot" ? 3 : 2
        case .basketballDunkContest:
            switch action {
            case "360 Dunk": return 10
            case "Windmill": return 9
            default: return 7
            }
        case .basketball3v3:
            return action == "Shoot" ? 3 : 2
        case .karate, .karateEndless:
            switch action {
            case "Kick": return 3
            case "Punch": return 1
            default: return 0
            }
        case .baseball:
            return action == "Swing" ? 2 : 1
        case .football:
            return 6
        case .soccer:
            return 1
        case .golf:
            return 1
        case .tennis:
            return action == "Serve" ? 4 : (action == "Volley" ? 3 : 2)
        case .volleyball:
            return 3
        case .gymnastics:
            return action == "Vault" ? 5 : (action == "Tumble" ? 3 : 4)
        case .surfing:
            return action == "Carve" ? 5 : (action == "Snap" ? 3 : 4)
        case .skateboarding:
            return action == "Grind" ? 5 : (action == "Ollie" ? 3 : 4)
        case .snowboarding:
            return action == "Jump" ? 5 : (action == "Carve" ? 3 : 4)
        case .brainBrawl:
            return action == "Pattern" ? 5 : (action == "Focus" ? 3 : 4)
        case .whoSceneIt:
            return action == "Spot Star" ? 6 : (action == "Freeze" ? 3 : 4)
        case .courtCarnival:
            return action == "Mini" ? 4 : (action == "Roll" ? 3 : 2)
        }
    }

    private func handleSceneAction() {
        guard isActive else { return }
        performAction(actionsForMode.first ?? "")
    }

    private func triggerFlash() {
        withAnimation(.easeOut(duration: 0.1)) { showFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeIn(duration: 0.3)) { showFlash = false }
        }
    }

    private func endGame() {
        guard isActive else { return }
        runMeterTimer?.cancel()
        runMeterTimer = nil
        streakTimer?.cancel()
        streakTimer = nil
        dunkTimerTask?.cancel()
        dunkTimerTask = nil
        slowMoTimer?.cancel()
        slowMoTimer = nil
        timeScaleUpdateTask?.cancel()
        timeScaleUpdateTask = nil
        gameTimerTask?.cancel()
        gameTimerTask = nil
        isSlowMo = false
        showTrickText = false
        showComboChain = false
        showContestPill = false
        showPerfectGuard = false
        showVanishFlash = false
        showQTEGrade = false
        lastAction = ""
        lastJudgeScores = nil
        crowdMessage = ""
        withAnimation(.spring(response: 0.4)) {
            isActive = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(response: 0.4)) {
                showResults = true
            }
        }
    }

    // MARK: - Wii-Style Input Handlers

    private func applyOutcomeFromCharge(_ chargeValue: Double) {
        guard isActive else { return }
        playerActionCount += 1
        let physics = leakageAdjustedPhysics
        let modeChance = PRQ.successChanceFromPRQ(playerPRQ, for: gameMode.id)
        let blendedBase = (physics.successChanceBase + modeChance) / 2.0
        let ddaWindow = DynamicDifficulty.scaledSuccessWindow(
            baseWindow: 0.40,
            playerScore: score,
            aiScore: opponentScore,
            targetScore: targetScore,
            mode: gameMode.id
        )
        let sweetSpotLow = max(0.1, 0.35 - (ddaWindow - 0.40))
        let sweetSpotHigh = min(0.95, 0.75 + (ddaWindow - 0.40))
        let inSweetSpot = chargeValue >= sweetSpotLow && chargeValue <= sweetSpotHigh
        let baseChance = inSweetSpot ? blendedBase + 0.15 : blendedBase * chargeValue
        let success = Double.random(in: 0...1) < baseChance
        let action = actionsForMode.first ?? "Action"

        if success {
            let isCritical = Double.random(in: 0...1) < physics.criticalHitChance
            let basePoints = pointsForAction(action, success: true)
            let finalPoints = physics.adjustedPoints(base: basePoints, combo: combo, isCritical: isCritical)

            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                score += finalPoints
                combo += 1
                maxCombo = max(maxCombo, combo)
                lastActionIsCritical = isCritical
                lastActionIsBurst = arcadePhysics.neuralBurstActive
                lastAction = modeFeedbackSuccess(points: finalPoints, isCritical: isCritical)
            }

            if isCritical {
                criticalHits += 1
                triggerCriticalFlash()
                triggerScreenShake(intensity: 0.6)
            } else {
                triggerFlash()
                triggerScreenShake(intensity: Double(physicsConfig.floorShakeAmplitude) * 10)
            }
            triggerImpactFlash()
            resetStreakTimer()
        } else {
            withAnimation(.spring(response: 0.3)) {
                combo = 0
                lastAction = modeFeedbackFail()
                lastActionIsCritical = false
                lastActionIsBurst = false
            }

            if gameMode.id == .football {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard isActive else { return }
                    if !multipeerService.isConnected {
                        withAnimation(.spring(response: 0.25)) { opponentScore += 1 }
                    }
                    endGame()
                }
                return
            }
        }

        if gameMode.id != .football, !multipeerService.isConnected {
            let ddaChance = DynamicDifficulty.opponentSuccessChance(
                baseChance: 0.55,
                playerScore: score,
                aiScore: opponentScore,
                sessionReadiness: sessionReadiness,
                playerPRQ: playerPRQ
            )
            if Double.random(in: 0...1) < ddaChance {
                delayedOpponentScoreGeneration += 1
                let generation = delayedOpponentScoreGeneration
                let aiDelay = Double.random(in: 0.4...0.8)
                Task {
                    try? await Task.sleep(for: .seconds(aiDelay))
                    guard isActive, generation == delayedOpponentScoreGeneration else { return }
                    let aiPoints = DynamicDifficulty.opponentPoints(
                        playerScore: score,
                        aiScore: opponentScore,
                        maxPoints: DynamicDifficulty.prqScaledOpponentMaxPoints(playerPRQ: playerPRQ, mode: gameMode.id, maxPoints: 2)
                    )
                    withAnimation(.spring(response: 0.25)) {
                        opponentScore += aiPoints
                    }
                }
            }
        }

        if multipeerService.isConnected {
            multipeerService.sendAction(action, score: score)
        }

        if !isTimerBased {
            roundNumber += 1
            if roundNumber > maxRounds { endGame() }
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard isActive else { return }
            withAnimation { lastAction = "" }
        }
    }

    private func handleSwipeEnd(dx: Double, dy: Double, speed: Double) {
        guard isActive else { return }
        let charge = min(1, max(0, speed / 600))
        applyOutcomeFromCharge(charge > 0.15 ? charge : 0.1)
    }

    private func handleGolfRelease(_ finalCharge: Double) {
        guard isActive else { return }
        let sweetSpot = abs(finalCharge - 0.65)
        let qualityBonus = sweetSpot < 0.1 ? 0.15 : 0
        applyOutcomeFromCharge(min(0.95, finalCharge + qualityBonus))
    }

    private func handleVolleyballSpike() {
        guard isActive else { return }
        let centerBias = 1.0 - abs(aimPosition.x - 0.5) * 1.2 - abs(aimPosition.y - 0.5) * 0.8
        let timingBonus = Double.random(in: 0...0.1)
        let charge = max(0.2, min(0.9, 0.35 + centerBias * 0.4 + timingBonus))
        applyOutcomeFromCharge(charge)
        withAnimation(.spring(response: 0.15)) {
            aimPosition = CGPoint(x: 0.5, y: 0.5)
        }
    }

    private func handleCatchTap() {
        guard isActive, footballPhase == .catch else { return }
        withAnimation(.spring(response: 0.2)) {
            footballPhase = .run
            runMeter = 0
            lastAction = "CAUGHT! TAP IN THE GREEN ZONE!"
        }
        runMeterTimer?.cancel()
        runMeterTimer = Task {
            while !Task.isCancelled && runMeter < 100 {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled, isActive else { return }
                withAnimation(.linear(duration: 0.04)) {
                    runMeter = min(100, runMeter + 1.0)
                }
            }
            guard !Task.isCancelled, isActive else { return }
            withAnimation(.spring(response: 0.2)) {
                footballPhase = .catch
                lastAction = "TACKLED!"
                lastActionIsCritical = false
                lastActionIsBurst = false
                combo = 0
                runMeter = 0
            }
            triggerScreenShake(intensity: 0.6)
            triggerImpactFlash()
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard isActive else { return }
                if !multipeerService.isConnected {
                    withAnimation(.spring(response: 0.25)) { opponentScore += 1 }
                }
                try? await Task.sleep(for: .seconds(1.0))
                guard isActive else { return }
                withAnimation { lastAction = "" }
                endGame()
            }
        }
    }

    private func handleRunTap() {
        guard isActive, footballPhase == .run else { return }
        runMeterTimer?.cancel()
        runMeterTimer = nil
        let inZone = runMeter >= 35 && runMeter <= 70
        withAnimation(.spring(response: 0.2)) {
            footballPhase = .catch
            runMeter = 0
        }
        applyOutcomeFromCharge(inZone ? 0.65 : 0.15)
    }

    // MARK: - Rally Ace Handler

    private func handleRallyHit(type: String) {
        guard isActive else { return }
        let centerBias = 1.0 - abs(aimPosition.x - 0.5) * 1.5 - abs(aimPosition.y - 0.5) * 1.0
        let typeBonus: Double
        switch type {
        case "Serve", "Spike": typeBonus = 0.15
        case "Forehand", "Bump": typeBonus = 0.1
        default: typeBonus = 0.05
        }
        let charge = max(0.2, min(0.9, 0.3 + centerBias * 0.4 + typeBonus))
        applyOutcomeFromCharge(charge)
    }

    // MARK: - Penalty Kick Handler

    private func handlePenaltyKick(power: KickPower) {
        guard isActive else { return }
        let aimBias = 1.0 - abs(aimPosition.x - 0.5) * 2.0
        let powerBonus: Double
        switch power {
        case .low: powerBonus = 0.12
        case .mid: powerBonus = 0.08
        case .high: powerBonus = 0.15
        }
        let gkSaveChance: Double
        switch power {
        case .low: gkSaveChance = 0.25
        case .mid: gkSaveChance = 0.35
        case .high: gkSaveChance = 0.2
        }
        let edgePlacement = abs(aimPosition.x - 0.5) > 0.3
        let finalSaveReduction = edgePlacement ? gkSaveChance * 0.4 : gkSaveChance
        let charge = max(0.15, min(0.9, 0.35 + aimBias * 0.3 + powerBonus - finalSaveReduction))
        applyOutcomeFromCharge(charge)
    }

    // MARK: - Mode-Specific Feedback

    private func modeFeedbackSuccess(points: Int, isCritical: Bool) -> String {
        let strings: [String]
        switch gameMode.id {
        case .baseball: strings = ["CRACK!", "HOME RUN!", "GONE!"]
        case .golf: strings = ["Nice!", "Close!", "Gimme!"]
        case .football: strings = ["TOUCHDOWN!", "HOUSE!", "GONE!"]
        case .soccer: strings = ["GOAL!", "TOP CORNER!", "NET!"]
        case .volleyball: strings = ["Point!", "Spike!", "Ace!", "Block!"]
        default: return isCritical ? "CRITICAL +\(points)" : "+\(points)"
        }
        let base = strings.randomElement() ?? strings[0]
        return isCritical ? "⚡ \(base) +\(points)" : "\(base) +\(points)"
    }

    private func modeFeedbackFail() -> String {
        let strings: [String]
        switch gameMode.id {
        case .baseball: strings = ["Swing and miss", "Foul", "Pop-up"]
        case .golf: strings = ["Short", "Long", "Lip out"]
        case .football: strings = ["Tackled", "Out of bounds"]
        case .soccer: strings = ["Saved", "Wide", "Over"]
        case .volleyball: strings = ["Out", "Net", "Dig"]
        default: return "MISSED"
        }
        return (strings.randomElement() ?? strings[0]).uppercased()
    }

    private func finalizeResults() {
        if finalizedMatchSessionId == matchSessionId { return }

        CrashReporter.setGameMode(id: gameMode.id.rawValue)
        if shardsReward > 0 {
            viewModel.profile.pendingUnverifiedShardCredits += shardsReward
            Task {
                await TrainingLabSocialBridge.shared.recordShardLedgerForArenaSession(
                    gameModeId: gameMode.id.rawValue,
                    deltaShards: shardsReward,
                    sessionId: matchSessionId.uuidString
                )
            }
        }
#if DEBUG
        viewModel.profile.metrics.prqScore = PRQ.clamp(viewModel.profile.metrics.prqScore + prqReward)
        viewModel.profile.metrics.neuralDrive = min(100, viewModel.profile.metrics.neuralDrive + 3)
#endif

        let elapsedSeconds: Int = {
            if let start = sessionStartedAt {
                let sec = Int(Date().timeIntervalSince(start).rounded())
                return max(1, min(sec, 24 * 3600))
            }
            return isTimerBased ? gameRules.matchDurationSeconds : roundNumber * 5
        }()

        let result = GameSessionResult(
            id: "local:\(matchSessionId.uuidString)",
            gameModeId: gameMode.id.rawValue,
            date: Date(),
            score: score,
            opponentScore: opponentScore,
            shardsEarned: shardsReward,
            prqBonus: prqReward,
            isMultiplayer: multipeerService.isConnected,
            duration: elapsedSeconds,
            verificationSeed: GameplaySeed.uint64(from: matchSessionId),
            trustLevel: .localPractice
        )

        SaveSystem.saveProfile(viewModel.profile)
        SaveSystem.saveGameResult(result)
        viewModel.globalLeaderboard.refreshRankings(userProfile: viewModel.profile, sampleData: SampleData.leaderboard)

        finalizedMatchSessionId = matchSessionId
    }

    private func handleLiveLeakage(joint: JointType, severity: Double) {
        let now = Date().timeIntervalSince1970
        let cooldown: TimeInterval = 1.05
        if let last = lastGameplayLeakagePenaltyAt[joint], now - last < cooldown { return }

        guard isActive, severity > 0.35 else { return }
        lastGameplayLeakagePenaltyAt[joint] = now

        withAnimation(.easeOut(duration: 0.2)) {
            liveLeakagePenalty = min(0.4, liveLeakagePenalty + severity * 0.15)
            leakageFlashJoint = joint
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeIn(duration: 0.5)) {
                liveLeakagePenalty = max(0, liveLeakagePenalty - 0.1)
                leakageFlashJoint = nil
            }
        }
    }

    private var leakageAdjustedPhysics: ArcadePhysics {
        guard liveLeakagePenalty > 0 else { return arcadePhysics }
        let penaltyFactor = 1.0 - liveLeakagePenalty
        return ArcadePhysics(
            hangTimeMultiplier: arcadePhysics.hangTimeMultiplier * penaltyFactor,
            explosiveFirstStep: arcadePhysics.explosiveFirstStep * penaltyFactor,
            comboDecayRate: arcadePhysics.comboDecayRate,
            maxComboMultiplier: arcadePhysics.maxComboMultiplier,
            successChanceBase: arcadePhysics.successChanceBase * penaltyFactor,
            criticalHitChance: arcadePhysics.criticalHitChance * penaltyFactor,
            neuralBurstActive: arcadePhysics.neuralBurstActive,
            neuralBurstMultiplier: arcadePhysics.neuralBurstMultiplier,
            impactIntensity: arcadePhysics.impactIntensity,
            auraLevel: arcadePhysics.auraLevel,
            perfectGuardWindow: arcadePhysics.perfectGuardWindow,
            specialMeterGainRate: arcadePhysics.specialMeterGainRate,
            perimeterDefense: arcadePhysics.perimeterDefense,
            contestBonus: arcadePhysics.contestBonus
        )
    }

    // MARK: - Special Meter Overlay

    private var specialMeterOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: specialMeterFull ? "flame.fill" : "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(specialMeterFull ? .orange : Theme.brandCyan)
                        Text(specialMeterFull ? "SPECIAL READY" : "SPECIAL")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(specialMeterFull ? .orange : Theme.brandCyan.opacity(0.8))
                            .tracking(1)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.6))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: specialMeterFull
                                            ? [.orange, .yellow, .orange]
                                            : [Theme.brandCyan.opacity(0.6), Theme.elitePurple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1, specialMeter / 100))
                                .animation(.spring(response: 0.25), value: specialMeter)
                        }
                    }
                    .frame(width: 100, height: 8)
                    .clipShape(.rect(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(specialMeterFull ? .orange.opacity(0.6) : Theme.brandCyan.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(specialMeterFull ? .orange.opacity(0.3) : .clear, lineWidth: 1)
                        )
                )
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.top, 8)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Trick Modifier Overlay

    private var trickModifierOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    if isModifierHeld {
                        VStack(spacing: 4) {
                            Text("TRICK MODE")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.elitePurple)
                                .tracking(2)
                            HStack(spacing: 12) {
                                trickDirectionButton(.up, label: "\u{25B2}", hint: isKarate ? "Vortex" : "Windmill")
                                trickDirectionButton(.down, label: "\u{25BC}", hint: isKarate ? "Barrage" : "Between")
                                trickDirectionButton(.left, label: "\u{25C0}", hint: isKarate ? "Surge" : "Tomahawk")
                                trickDirectionButton(.right, label: "\u{25B6}", hint: isKarate ? "Phantom" : "360")
                            }
                            if specialMeterFull {
                                Button {
                                    executeSpecialTrick()
                                } label: {
                                    Text(isKarate ? "FINAL GATE" : "GIANT KILLER")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            LinearGradient(
                                                colors: [.orange, .yellow],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.black.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.elitePurple.opacity(0.4), lineWidth: 1)
                                )
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    HStack(spacing: 6) {
                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                isModifierHeld.toggle()
                                activeModifierState = isModifierHeld ? .style : .none
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "l1.button.roundedbottom.horizontal")
                                    .font(.system(size: 12, weight: .bold))
                                Text("STYLE")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(activeModifierState == .style ? .black : Theme.elitePurple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                activeModifierState == .style
                                    ? AnyShapeStyle(Theme.elitePurple)
                                    : AnyShapeStyle(Theme.elitePurple.opacity(0.15))
                            )
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Theme.elitePurple.opacity(0.4), lineWidth: 1))
                        }

                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                if activeModifierState == .power {
                                    activeModifierState = .none
                                    isModifierHeld = false
                                } else {
                                    activeModifierState = .power
                                    isModifierHeld = true
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "r1.button.roundedbottom.horizontal")
                                    .font(.system(size: 12, weight: .bold))
                                Text("POWER")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(activeModifierState == .power ? .black : .orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                activeModifierState == .power
                                    ? AnyShapeStyle(Color.orange)
                                    : AnyShapeStyle(Color.orange.opacity(0.15))
                            )
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
                        }
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, inputScheme == .charge ? 220 : 80)
            }
        }
    }

    private func trickDirectionButton(_ direction: ComboDirection, label: String, hint: String) -> some View {
        Button {
            executeTrickCombo(direction: direction)
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                Text(hint)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(width: 50, height: 44)
            .background(Theme.elitePurple.opacity(0.2))
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.elitePurple.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Trick Execution

    private func executeTrickCombo(direction: ComboDirection) {
        guard isActive, isModifierHeld else { return }
        if direction != .neutral {
            lastCommittedTrickDirection = direction
        }
        let goldenTrick = DirectionalTrick.resolve(direction: direction, modifier: activeModifierState, mode: gameMode.id)
        executeGoldenTrick(goldenTrick)
    }

    private func executeSpecialTrick() {
        guard isActive, specialMeterFull else { return }
        withAnimation(.spring(response: 0.2)) {
            specialMeter = 0
            activeModifierState = .special
        }
        let dir = currentTrickDirection != .neutral ? currentTrickDirection : lastCommittedTrickDirection
        let goldenTrick = DirectionalTrick.resolve(direction: dir, modifier: .special, mode: gameMode.id)
        executeGoldenTrick(goldenTrick)
    }

    private func executeGoldenTrick(_ trick: DirectionalTrick) {
        guard pendingGoldenApex == nil else { return }

        let physics = leakageAdjustedPhysics
        let riskRoll = Double.random(in: 0...1)
        let successThreshold = physics.successChanceBase / trick.riskFactor
        let success = riskRoll < successThreshold
        let isCritical = success && Double.random(in: 0...1) < physics.criticalHitChance

        let now = CACurrentMediaTime()
        matrixState = matrixState.startAction(
            name: trick.name,
            intensity: trick.riskFactor,
            isFinisher: trick.modifier == .special,
            at: now
        )

        if success {
            goldenComboEngine = goldenComboEngine.addTrick(trick, at: now)
            goldenComboEngine = goldenComboEngine.startApexQTE(at: now)
            pendingGoldenApex = PendingGoldenApexPayload(trick: trick, isCritical: isCritical)
            apexQTESessionGeneration += 1
            let generation = apexQTESessionGeneration
            Task {
                try? await Task.sleep(for: .seconds(QTEApexWindow.windowDuration + 0.12))
                guard generation == apexQTESessionGeneration, pendingGoldenApex != nil else { return }
                resolveGoldenApex(withInputTime: nil)
            }
            return
        }

        withAnimation(.spring(response: 0.3)) {
            combo = 0
            lastAction = "CLANK!"
            lastActionIsCritical = false
            lastActionIsBurst = false
            goldenComboEngine = goldenComboEngine.reset()
        }
        triggerScreenShake(intensity: 0.3)
        matrixState = matrixState.toIdle(at: CACurrentMediaTime())

        withAnimation(.spring(response: 0.2)) {
            isModifierHeld = false
            activeModifierState = .none
        }

        Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation { lastAction = "" }
        }
    }

    private func commitApexQTEResolution() {
        guard pendingGoldenApex != nil else { return }
        apexQTESessionGeneration += 1
        resolveGoldenApex(withInputTime: CACurrentMediaTime())
    }

    private func resolveGoldenApex(withInputTime inputTime: CFTimeInterval?) {
        guard let payload = pendingGoldenApex else { return }
        pendingGoldenApex = nil
        let t: CFTimeInterval
        if let inputTime {
            t = inputTime
        } else if let end = goldenComboEngine.apexWindow?.windowEnd {
            t = end + 0.6
        } else {
            t = CACurrentMediaTime()
        }
        goldenComboEngine = goldenComboEngine.resolveApexQTE(inputTime: t)
        let grade = goldenComboEngine.lastQTEGrade ?? .ok
        lastQTEGrade = grade
        finishGoldenTrickScoring(trick: payload.trick, grade: grade, isCritical: payload.isCritical)
    }

    private func finishGoldenTrickScoring(trick: DirectionalTrick, grade: QTEGrade, isCritical: Bool) {
        let physics = leakageAdjustedPhysics

        let stylePoints = goldenComboEngine.finalScore(
            prqNormalized: min(max(playerPRQ / 100.0, 0), 1),
            neuralBurst: arcadePhysics.neuralBurstActive
        )
        let scaledPoints = max(1, stylePoints / max(1, goldenComboEngine.chainLength))
        let finalPoints = physics.adjustedPoints(base: scaledPoints, combo: combo, isCritical: isCritical)

        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            score += finalPoints
            combo += 1
            maxCombo = max(maxCombo, combo)
            lastActionIsCritical = isCritical
            lastActionIsBurst = arcadePhysics.neuralBurstActive
            lastAction = "+\(finalPoints)"
            lastTrickName = trick.displayName
            showTrickText = true
            specialMeter = min(100, specialMeter + physics.specialMeterGainRate)
            qteGradeText = grade.rawValue
            showQTEGrade = true
        }

        let impact = ImpactFXConfig.forImpact(
            modifier: trick.modifier == .special ? .special : activeModifierState,
            qteGrade: grade,
            jumpHeight: Double(physicsConfig.jumpHeight) / 4.0
        )
        triggerScreenShake(intensity: impact.screenShakeIntensity / 14.0)

        if isCritical {
            criticalHits += 1
            triggerCriticalFlash()
        } else {
            triggerFlash()
        }
        triggerImpactFlash()
        resetStreakTimer()

        if grade.triggersSlowMo || trick.modifier == .special {
            triggerMatrixSlowMo(effect: trick.modifier == .special ? .finisher : .slowMo)
        }

        matrixState = matrixState.resolveAction(at: CACurrentMediaTime())

        Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation { showTrickText = false; lastTrickName = ""; showQTEGrade = false }
            matrixState = matrixState.toIdle(at: CACurrentMediaTime())
        }

        withAnimation(.spring(response: 0.2)) {
            isModifierHeld = false
            activeModifierState = .none
        }

        Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation { lastAction = "" }
        }
    }

    // MARK: - Slow-Mo Manager

    private func triggerSlowMo(duration: Double) {
        slowMoTimer?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            isSlowMo = true
        }
        slowMoTimer = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) {
                isSlowMo = false
            }
        }
    }

    private func triggerMatrixSlowMo(effect: TimeScaleManager.TimeEffect) {
        let now = CACurrentMediaTime()
        switch effect {
        case .slowMo:
            timeScaleManager = timeScaleManager.triggerSlowMo(at: now)
        case .finisher:
            timeScaleManager = timeScaleManager.triggerFinisher(at: now)
        case .perfectGuard:
            timeScaleManager = timeScaleManager.triggerPerfectGuard(at: now)
        case .apex:
            timeScaleManager = timeScaleManager.triggerApex(at: now)
        case .none:
            break
        }
        triggerSlowMo(duration: timeScaleManager.isActive ? TimeScaleManager.slowMoDuration : 1.0)
        startTimeScaleUpdates()
    }

    private func startTimeScaleUpdates() {
        timeScaleUpdateTask?.cancel()
        timeScaleUpdateTask = Task {
            while !Task.isCancelled && timeScaleManager.isActive {
                try? await Task.sleep(for: .milliseconds(50))
                timeScaleManager = timeScaleManager.update(at: CACurrentMediaTime())
            }
        }
    }

    private var prqDDA: PRQDrivenDDA {
        PRQDrivenDDA(playerPRQ: playerPRQ, neuralDrive: viewModel.effectiveMetrics.neuralDrive, mode: gameMode.id)
    }

    private func hapticSuccess(isCritical: Bool) {
        let generator = UIImpactFeedbackGenerator(style: isCritical ? .heavy : .medium)
        generator.impactOccurred()
    }

    private func hapticFail() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - PS2 Controller Handlers

    private func handlePS2FaceButton(_ button: PS2FaceButton) {
        guard isActive else { return }
        if isDunkContest {
            switch dunkEngine.phase {
            case .idle:
                startDunkApproach()
            case .approach:
                releaseDunkSprint()
            case .launch:
                confirmDunkLaunch()
            case .airborne:
                switch button {
                case .triangle: handleArcadeDunkButton(.triangle)
                case .square: handleArcadeDunkButton(.square)
                case .circle: handleArcadeDunkButton(.circle)
                case .cross:
                    if dunkEngine.styleLandingWindow {
                        handleStyleLanding()
                    } else {
                        handleArcadeDunkButton(.cross)
                    }
                }
            case .landing:
                confirmDunkLanding()
            case .scored:
                break
            }
            return
        }

        switch button {
        case .triangle:
            performAction("Shoot")
        case .square:
            performAction("Dunk")
        case .circle:
            performAction("Sprint")
        case .cross:
            performAction("Style")
        }
    }

    private func handlePS2DPad(_ direction: PS2DPadDirection) {
        guard isActive else { return }
        let comboDir: ComboDirection
        switch direction {
        case .up: comboDir = .up
        case .down: comboDir = .down
        case .left: comboDir = .left
        case .right: comboDir = .right
        }
        currentTrickDirection = comboDir
        lastCommittedTrickDirection = comboDir
        if inputScheme == .rallyAce || inputScheme == .dragTap || inputScheme == .penaltyKick {
            nudgeAimWithDirection(comboDir)
        }
        if isModifierHeld {
            executeTrickCombo(direction: comboDir)
        }
    }

    private func handlePS2LeftStick(_ vector: CGPoint) {
        guard isActive else { return }
        leftStickVector = vector
        updateDirectionFromStick(vector)

        if inputScheme == .rallyAce || inputScheme == .dragTap || inputScheme == .penaltyKick {
            let sensitivity: CGFloat = 0.025
            let newX = max(0, min(1, aimPosition.x + vector.x * sensitivity))
            let newY = max(0, min(1, aimPosition.y - vector.y * sensitivity))
            aimPosition = CGPoint(x: newX, y: newY)
        }
    }

    private func handlePS2RightStick(_ vector: CGPoint) {
        guard isActive else { return }
        rightStickVector = vector
        updateDirectionFromStick(vector)

        let magnitude = hypot(vector.x, vector.y)
        guard magnitude > 0.88 else { return }
        let now = CACurrentMediaTime()
        guard now - lastStickComboFireAt > 0.18 else { return }
        lastStickComboFireAt = now

        if isModifierHeld {
            executeTrickCombo(direction: currentTrickDirection)
        } else if isDunkContest && dunkEngine.phase == .airborne {
            let mapped = arcadeButton(for: vector)
            handleArcadeDunkButton(mapped)
        }
    }

    private func handlePS2LeftShoulder() {
        guard isActive else { return }
        if isDunkContest {
            styleTriggerHeld.toggle()
            dunkEngine.setModifier(styleTrigger: styleTriggerHeld, powerTrigger: powerTriggerHeld)
            return
        }
        withAnimation(.spring(response: 0.2)) {
            isModifierHeld.toggle()
            activeModifierState = isModifierHeld ? .style : .none
        }
    }

    private func handlePS2RightShoulder() {
        guard isActive else { return }
        if isDunkContest {
            powerTriggerHeld.toggle()
            dunkEngine.setModifier(styleTrigger: styleTriggerHeld, powerTrigger: powerTriggerHeld)
            return
        }
        withAnimation(.spring(response: 0.2)) {
            if activeModifierState == .power {
                activeModifierState = .none
                isModifierHeld = false
            } else {
                activeModifierState = .power
                isModifierHeld = true
            }
        }
    }

    private func updateDirectionFromStick(_ vector: CGPoint) {
        let threshold: CGFloat = 0.28
        guard abs(vector.x) > threshold || abs(vector.y) > threshold else {
            currentTrickDirection = .neutral
            return
        }
        if abs(vector.x) > abs(vector.y) {
            currentTrickDirection = vector.x >= 0 ? .right : .left
        } else {
            currentTrickDirection = vector.y >= 0 ? .up : .down
        }
        lastCommittedTrickDirection = currentTrickDirection
    }

    private func nudgeAimWithDirection(_ direction: ComboDirection) {
        let delta: CGFloat = 0.05
        switch direction {
        case .up:
            aimPosition.y = max(0, aimPosition.y - delta)
        case .down:
            aimPosition.y = min(1, aimPosition.y + delta)
        case .left:
            aimPosition.x = max(0, aimPosition.x - delta)
        case .right:
            aimPosition.x = min(1, aimPosition.x + delta)
        case .neutral:
            break
        }
    }

    private func arcadeButton(for vector: CGPoint) -> ArcadeFaceButton {
        if abs(vector.x) > abs(vector.y) {
            return vector.x >= 0 ? .circle : .square
        }
        return vector.y >= 0 ? .triangle : .cross
    }

    // MARK: - Combat (Block / Counter / Vanish)

    private func handleBlock() {
        guard isActive, isKarate else { return }
        blockTimestamp = CACurrentMediaTime()
    }

    private func resolveCombatOnHit() {
        guard isKarate else { return }
        let impactTime = CACurrentMediaTime()
        let outcome = CombatInputResolver.resolveCombatAction(
            blockPressed: blockTimestamp > 0,
            blockTimestamp: blockTimestamp,
            impactTimestamp: impactTime,
            stickDirection: currentTrickDirection != .neutral ? currentTrickDirection : nil
        )
        blockTimestamp = 0

        switch outcome {
        case .perfectGuard:
            triggerPerfectGuard()
        case .vanishCounter:
            triggerVanishCounter()
        case .standardBlock:
            withAnimation(.spring(response: 0.2)) {
                lastAction = "BLOCKED!"
            }
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation { lastAction = "" }
            }
        case .hit:
            break
        }
    }

    private func triggerPerfectGuard() {
        withAnimation(.easeOut(duration: 0.1)) {
            showPerfectGuard = true
            lastAction = "PERFECT GUARD!"
            specialMeter = min(100, specialMeter + 20)
        }
        triggerMatrixSlowMo(effect: .perfectGuard)
        triggerScreenShake(intensity: 0.4)
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeIn(duration: 0.3)) { showPerfectGuard = false }
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation { lastAction = "" }
        }
    }

    private func triggerVanishCounter() {
        withAnimation(.easeOut(duration: 0.05)) {
            showVanishFlash = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeIn(duration: 0.15)) { showVanishFlash = false }
        }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            lastAction = "VANISH COUNTER!"
            lastTrickName = "SUBSTITUTION!"
            showTrickText = true
            specialMeter = min(100, specialMeter + 30)
        }
        triggerMatrixSlowMo(effect: .finisher)
        triggerScreenShake(intensity: 0.7)

        let physics = leakageAdjustedPhysics
        let counterPoints = physics.adjustedPoints(base: 5, combo: combo, isCritical: true)
        withAnimation(.spring(response: 0.25)) {
            score += counterPoints
            combo += 1
            maxCombo = max(maxCombo, combo)
        }
        triggerCriticalFlash()

        Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation { showTrickText = false; lastTrickName = ""; lastAction = "" }
        }
    }

    // MARK: - Contest Pill Overlay

    private func contestPillOverlay(percent: Int, label: String, tier: ContestTier) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Text("\(percent)%")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(contestTierColor(tier))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .tracking(1)
                        Text("SHOT CONTEST")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(contestTierColor(tier).opacity(0.5), lineWidth: 1.5)
                        )
                        .shadow(color: contestTierColor(tier).opacity(0.3), radius: 12)
                )
                Spacer()
            }
            .padding(.bottom, 140)
        }
        .allowsHitTesting(false)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private func contestTierColor(_ tier: ContestTier) -> Color {
        switch tier {
        case .smothered: return .red
        case .heavy: return .orange
        case .contested: return .yellow
        case .light: return Color(red: 0.6, green: 0.8, blue: 0.3)
        case .open: return .green
        }
    }

    // MARK: - Defensive Controls Overlay

    private var defensiveControlsOverlay: some View {
        VStack {
            Spacer()
            HStack {
                VStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            defensiveState.toggleHandsUp()
                            lastAction = defensiveState.handsUp ? "HANDS UP" : "HANDS DOWN"
                        }
                        simulateDefenderProximity()
                        Task {
                            try? await Task.sleep(for: .seconds(1.0))
                            withAnimation { if lastAction == "HANDS UP" || lastAction == "HANDS DOWN" { lastAction = "" } }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: defensiveState.handsUp ? "hand.raised.fill" : "hand.raised")
                                .font(.system(size: 16, weight: .bold))
                            Text("CONTEST")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(defensiveState.handsUp ? .black : .white)
                        .frame(width: 56, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(defensiveState.handsUp ? gameMode.accentColor : gameMode.accentColor.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(gameMode.accentColor.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }

                    Button {
                        guard !defensiveState.isQuickProtectActive else { return }
                        withAnimation(.spring(response: 0.2)) {
                            defensiveState.activateQuickProtect()
                            lastAction = "QUICK PROTECT"
                        }
                        triggerScreenShake(intensity: 0.2)
                        Task {
                            try? await Task.sleep(for: .seconds(DefensivePhysics.quickProtectDurationSeconds))
                            withAnimation { if lastAction == "QUICK PROTECT" { lastAction = "" } }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: defensiveState.isQuickProtectActive ? "shield.fill" : "shield")
                                .font(.system(size: 16, weight: .bold))
                            Text("PROTECT")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(defensiveState.isQuickProtectActive ? .black : .white)
                        .frame(width: 56, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(defensiveState.isQuickProtectActive ? Theme.brandCyan : Theme.brandCyan.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.brandCyan.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                    .opacity(defensiveState.isQuickProtectActive ? 0.6 : 1.0)

                    if defensiveState.handsUp {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(contestTierColor(defensiveState.contestResult().tier))
                                .frame(width: 5, height: 5)
                            Text("\(Int(defenderSimDistance * 10) / 10)ft")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, inputScheme == .charge ? 180 : 80)
                Spacer()
            }
        }
    }

    // MARK: - Defense Simulation

    private func simulateDefenderProximity() {
        let stick = hypot(leftStickVector.x, leftStickVector.y)
        let lateralScale = DefensivePhysics.lateralQuicknessScale(perimeterDefense: arcadePhysics.perimeterDefense)
        let spacingFeet = max(0.8, min(6.0, 5.2 - stick * 3.2))
        let adjusted = spacingFeet / lateralScale
        withAnimation(.spring(response: 0.3)) {
            defenderSimDistance = max(0.5, min(6.0, adjusted))
            defensiveState.defenderDistance = defenderSimDistance
        }
    }

    private func applyContestToShot(baseChance: Double) -> Double {
        guard supportsDefense, defensiveState.handsUp else { return baseChance }
        let result = defensiveState.contestResult()
        let penalty = DefensivePhysics.contestShotPenalty(percent: result.percent)
        let contestedChance = baseChance * (1.0 - penalty)

        withAnimation(.spring(response: 0.3)) {
            lastContestPercent = result.percent
            lastContestLabel = result.label
            lastContestTier = result.tier
            showContestPill = true
        }

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.3)) {
                showContestPill = false
                lastContestPercent = nil
                lastContestLabel = nil
                lastContestTier = nil
            }
        }

        return contestedChance
    }
}
