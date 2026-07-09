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
    /// HUD theme from NEXUS Game Generator customizer — flows into live gameplay chrome.
    var generatorHudTheme: NexusGeneratorHudTheme? = nil
    /// When true (screenshot harness only), skips multiplayer lobby + countdown so START MATCH + scene chrome are visible immediately.
    var skipMatchLobbyForScreenshotHarness: Bool = false

    @State private var score: Int = 0
    @State private var opponentScore: Int = 0
    /// Last-seen 3v3 controller team totals, so onAI3v3Score adds deltas (not a
    /// max/sum hybrid) and composes with the player's manual-tap scoring.
    @State private var ai3v3BlueSeen: Int = 0
    @State private var ai3v3RedSeen: Int = 0
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
    @State private var judgeRollUpReveal: Bool = false
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

    @State private var goldenComboEngine = SignatureComboEngine()
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
    @State private var sceneViewportReady = false
    @State private var nexusEngine = NexusGameplayEngine()

    // MARK: - Who Scene It (Film Quiz) State
    @State private var selectedFilmChoice: Int? = nil
    @State private var filmQuestionTimer: Double = 8.0
    @State private var filmTimerTask: Task<Void, Never>? = nil
    @State private var filmQuestionFeedback: String = ""
    @State private var filmShowExplanation: Bool = false
    @State private var skeletonJointsTime: Double = 0.0
    @State private var skeletonAnimationTask: Task<Void, Never>? = nil

    // MARK: - Court Carnival (Party Board) State
    @State private var courtCarnivalBoardSpace: Int = 0
    @State private var courtCarnivalDiceFace: Int = 1
    @State private var courtCarnivalRollingActive: Bool = false
    @State private var courtCarnivalRollAngle: Double = 0.0
    @State private var courtCarnivalEvent: CarnivalEvent? = nil
    @State private var courtCarnivalTapCount: Int = 0
    @State private var courtCarnivalTapGoal: Int = 20
    @State private var courtCarnivalTapTimer: Double = 5.0
    @State private var courtCarnivalSelectedBranch: Int? = nil
    @State private var courtCarnivalDuelTarget: Int = 0
    @State private var courtCarnivalDuelPlayerRoll: Int? = nil
    @State private var courtCarnivalDuelOpponentRoll: Int? = nil
    @State private var courtCarnivalTapTimerTask: Task<Void, Never>? = nil

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
    private var supportsTricks: Bool { gameMode.id.is3DDunkContest || gameMode.id == .basketballHeadToHead || gameMode.id == .basketball3v3 || isKarate }
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

    /// Generator customizer overrides mode accent when present.
    private var effectiveHudAccent: Color {
        generatorHudTheme?.accentColor ?? gameMode.accentColor
    }

    private var effectiveHudPrimary: Color {
        generatorHudTheme?.primaryColor ?? gameMode.accentColor
    }

    private var generatorHudBadge: String? {
        guard let theme = generatorHudTheme, !theme.badgeLabel.isEmpty else { return nil }
        return theme.badgeLabel.uppercased()
    }

    private var isTimerBased: Bool {
        gameRules.useMatchCountdown
    }

    private var isDunkContest: Bool {
        gameMode.id.is3DDunkContest
    }

    private var isBlacktop: Bool {
        gameMode.id == .basketballHeadToHead || gameMode.id == .basketball3v3
    }

    private var isBasketball: Bool {
        gameMode.id == .basketballHeadToHead || gameMode.id.is3DDunkContest || gameMode.id == .basketball3v3
    }

    /// Modes that run the dribble-vs-walk possession system in the scene host
    /// (mirror of GameSceneHostView.isBasketballPossessionMode). Jumpshot /
    /// crossover clip-swaps only make sense in these.
    private var isBasketballPossession: Bool {
        switch gameMode.id {
        case .basketballHeadToHead, .venicePickup, .basketball3v3, .basketballDunkContest3D:
            return true
        default:
            return false
        }
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

    /// Shared controller state (Phase 2 input layer) — one instance per session.
    @State private var felPad = FELGamepadState()

    /// Charge modes always show the pad; 3D avatar sports gain it too so the
    /// stick drives movement (GameSceneHostView MovementBounds) alongside
    /// their sport-specific bottom controls.
    private var usesGamepadOverlay: Bool {
        if inputScheme == .charge { return true }
        switch gameMode.id {
        case .tennis, .volleyball, .soccer, .football, .skateboarding,
             .snowboarding, .surfing, .gymnastics, .courtCarnival:
            return true
        default:
            return false
        }
    }

    /// One-shot karate strike playback signal (see GameSceneHostView).
    @State private var karateStrikeNonce = 0
    @State private var karateStrikeAsset: FELBundledAsset?

    /// One-shot basketball crossover / jumpshot playback signals (see
    /// GameSceneHostView). Bumped when the matching action fires in a basketball
    /// possession mode; the scene host swaps in the baked dribble-crossover /
    /// jumpshot clip once, then reverts to dribble/locomotion.
    @State private var basketballCrossoverNonce = 0
    @State private var basketballJumpShotNonce = 0
    /// Which baked dunk clip the dunk contest plays next (alternates between the
    /// two retargeted power dunks for variety; see setDunkClipActive).
    @State private var basketballDunkClipAsset: FELBundledAsset = .elijahDunk

    /// One-shot per-sport action playback signal (see SportActionAnimationLibrary
    /// / GameSceneHostView.playSportAction). Bumped when a covered sport's action
    /// fires; the scene host prefers a bundled full-body Action_ clip and falls
    /// back to the procedural arm-swing.
    @State private var sportActionNonce = 0
    @State private var sportActionLabel = ""

    // MARK: - Karate Excellence: combo / opponent AI / waves
    @State private var karateCombo = KarateComboTracker()
    @State private var recentStrikeButtons: [ArenaPadFaceButton] = []
    @State private var comboExpiryTask: Task<Void, Never>?
    /// Opponent (fighter2) animation event bridge.
    @State private var karateOpponentEventNonce = 0
    @State private var karateOpponentEvent: KarateOpponentEvent?
    /// Impact hitstop + contact-burst bridge.
    @State private var karateHitstopNonce = 0
    @State private var karateHitstopCritical = false
    /// Local deterministic opponent AI (1v1 + each endless opponent).
    @State private var opponentAI: KarateOpponentAI?
    @State private var opponentHP: Int = 0
    @State private var opponentMaxHP: Int = 0
    @State private var opponentAITask: Task<Void, Never>?
    @State private var pendingOpponentAttack: KarateOpponentAI.Attack?
    /// Local survival-wave engine (karateEndless).
    @State private var waveEngine: KarateEndlessWaveEngine?
    @State private var waveTickTask: Task<Void, Never>?
    @State private var showWaveClear = false
    @State private var karateVictory = false
    /// 1v1 player HP (endless uses `waveEngine.playerHP`). KO drives match end.
    static let karatePlayerMaxHP = 100
    @State private var karatePlayerHP: Int = karatePlayerMaxHP
    /// Set true when the player is defeated (1v1 loss / endless defeat) so the
    /// results screen shows the KO outcome instead of the score winner.
    @State private var karateDefeat = false
    /// Range gate: updated by the scene host when a strike fires — true only if
    /// the opponent is within reach, so a whiffed (out-of-range) strike deals
    /// no damage. Defaults true so early frames / harness resolve fail-soft.
    @State private var karateInStrikeRange = true

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()

            sceneArea
                .ignoresSafeArea(edges: .bottom)
                .offset(x: screenShake)

            VStack(spacing: 0) {
                hudBar
                gameplayHonestyStrip
                Spacer()
                controlPanel
            }
            .offset(x: screenShake)

            // Shared controller overlay (Phase 2 input layer): full-screen for
            // charge modes AND every mode with a free-moving 3D avatar — the
            // scene host honors per-mode MovementBounds, so the left stick /
            // D-pad drive the player and face buttons fire mode actions.
            // Works in portrait and landscape (edge-anchored, reflows).
            if usesGamepadOverlay {
                FELGamepadView(state: felPad, isActive: isActive)
                    .offset(x: screenShake)
                    .onAppear { configureFELPadBridge() }
                    .onChange(of: felPad.leftStick) { _, vector in
                        handlePS2LeftStick(vector)
                    }
                    .onChange(of: felPad.rightStick) { _, vector in
                        handlePS2RightStick(vector)
                    }
            }

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
                    colors: [FELDesign.Colors.cyan.opacity(0.3), FELDesign.Colors.purple.opacity(0.2)],
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
                        FELMicroLabel(text: "Slow Motion", color: FELDesign.Colors.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.top, 60)
                            .padding(.leading, FELDesign.Space.md)
                            .allowsHitTesting(false)
                    )
            }

            if showPerfectGuard {
                RadialGradient(
                    colors: [FELDesign.Colors.cyan.opacity(0.5), FELDesign.Colors.purple.opacity(0.3), .clear],
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
                        .font(FELDesign.Typography.title)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                        .shadow(color: .black.opacity(0.6), radius: 4)
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
                        // Karate is decided by KO, not score. Endless is always a
                        // "defeat" run (you play until you fall) — the score is
                        // the achievement; a wave-survival finish still reads as
                        // p1 unless the player was KO'd.
                        if isKarate {
                            if karateDefeat { return .p2 }
                            if karateVictory { return .p1 }
                            // Timer/exit with no KO: fall back to remaining HP.
                            let oppFrac = opponentAI?.hpFraction ?? 0
                            let playerFrac = gameMode.id == .karateEndless
                                ? (waveEngine?.playerHPFraction ?? 1)
                                : Double(karatePlayerHP) / Double(Self.karatePlayerMaxHP)
                            if playerFrac > oppFrac { return .p1 }
                            if oppFrac > playerFrac { return .p2 }
                            return .draw
                        }
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
                    HStack(spacing: FELDesign.Space.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("EXIT")
                            .font(FELDesign.Typography.micro)
                            .tracking(FELDesign.Typography.microTracking)
                    }
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                }
                .accessibilityIdentifier("GameplayExitButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if multipeerService.pendingInvitationPeerName != nil {
                        Button("Accept") {
                            multipeerService.acceptPendingInvitation()
                        }
                        .font(FELDesign.Typography.micro)
                        .foregroundStyle(FELDesign.Colors.success)
                        Button("Decline") {
                            multipeerService.rejectPendingInvitation()
                        }
                        .font(FELDesign.Typography.micro)
                        .foregroundStyle(FELDesign.Colors.danger)
                    }
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showBiomechanicsHUD.toggle()
                        }
                    } label: {
                        Image(systemName: showBiomechanicsHUD ? "figure.run.motion" : "figure.stand")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(showBiomechanicsHUD ? FELDesign.Colors.cyan : FELDesign.Colors.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(FELDesign.Colors.surfaceRaised)
                            .clipShape(Circle())
                    }
                    // (NeuralAuraBadge removed from the live toolbar — a pulsing
                    // "aura level" sim readout that cluttered the top-right corner.
                    // Aura still drives effects mechanically; no persistent badge.)
                    peerStatusBadge
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            sceneViewportReady = false
            nexusEngine.start(modeId: gameMode.id.nexusRuntimeModeId, readiness: sessionReadiness)
            FELSoundscapeEngine.shared.start(for: gameMode.id)
            FELHaptics.prepare()
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
        .onChange(of: nexusEngine.hud.karateWave) { oldWave, newWave in
            if gameMode.id == .karateEndless, newWave > oldWave, oldWave > 0 {
                FELGameplayEventBus.postWaveCompleted()
            }
        }
        .onDisappear {
            sceneViewportReady = false
            nexusEngine.stop()
            FELSoundscapeEngine.shared.stop()
            matchLobbyComplete = false
            multipeerService.stop()
            gameTimerTask?.cancel()
            streakTimer?.cancel()
            dunkTimerTask?.cancel()
            slowMoTimer?.cancel()
            timeScaleUpdateTask?.cancel()
            runMeterTimer?.cancel()
            skeletonAnimationTask?.cancel()
            filmTimerTask?.cancel()
            courtCarnivalTapTimerTask?.cancel()
        }
    }

    // MARK: - HUD Honesty

    private var gameplayHonestyStrip: some View {
        VStack(spacing: FELDesign.Space.xxs) {
            HStack(spacing: FELDesign.Space.xs) {
                FELMicroLabel(text: gameMode.subtitle, color: FELDesign.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("GameplayModeSubtitle")
                Spacer(minLength: 0)
                if let tier = gameMode.felHonestTierLabel {
                    FELPreviewLabel(text: tier)
                        .accessibilityIdentifier("GameplayHonestTierLabel")
                }
            }
            if let proxyNote = gameMode.id.venueMeshProxyNote {
                HStack(spacing: FELDesign.Space.xxs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9, weight: .semibold))
                    Text(proxyNote)
                        .font(.system(size: 9, weight: .medium))
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("GameplayVenueProxyNote")
            }
        }
        .padding(.horizontal, FELDesign.Space.md)
        .padding(.bottom, FELDesign.Space.xs)
    }

    // MARK: - HUD Bar

    private var hudBar: some View {
        ZStack {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    HStack(spacing: FELDesign.Space.xxs) {
                        Circle()
                            .fill(effectiveHudPrimary)
                            .frame(width: 5, height: 5)
                        FELMicroLabel(text: "You", color: FELDesign.Colors.textSecondary)
                    }
                    if let badge = generatorHudBadge {
                        Text(badge)
                            .font(FELDesign.Typography.micro)
                            .tracking(FELDesign.Typography.microTracking)
                            .foregroundStyle(effectiveHudAccent)
                            .padding(.horizontal, FELDesign.Space.xs)
                            .padding(.vertical, 2)
                            .background(effectiveHudAccent.opacity(0.12))
                            .clipShape(Capsule())
                            .accessibilityIdentifier("GeneratorHudBadgeLabel")
                    }
                    Text("\(score)")
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                        .contentTransition(.numericText())
                    // (PRQ "IQ" attribute label removed — sim chrome that
                    // cluttered the live HUD; PRQ still shows on results/lab.)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: FELDesign.Space.xxs) {
                    ZStack {
                        Circle()
                            .fill(FELDesign.Colors.surfaceRaised)
                            .frame(width: 36, height: 36)
                        Image(systemName: gameMode.iconName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }

                    if isDunkContest {
                        Text("Round \(dunkRound)/3")
                            .font(FELDesign.Typography.stat)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                    } else if isBlacktop {
                        Text("First to \(targetScore)")
                            .font(FELDesign.Typography.stat)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                    } else if isTimerBased {
                        Text(timeFormatted)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(timeRemaining <= 10 ? FELDesign.Colors.danger : FELDesign.Colors.textPrimary)
                            .contentTransition(.numericText())
                    } else {
                        Text("R\(roundNumber)/\(maxRounds)")
                            .font(FELDesign.Typography.stat)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                    }

                    // (Neural-burst + "NEXUS <phase> x" multiplier chrome removed
                    // from the live HUD — sim readouts that cluttered the top bar.
                    // The burst still applies mechanically; a brief on-activation
                    // flash conveys it without a persistent readout.)
                }

                VStack(alignment: .trailing, spacing: FELDesign.Space.xxs) {
                    HStack(spacing: FELDesign.Space.xxs) {
                        FELMicroLabel(text: "Opp", color: FELDesign.Colors.textTertiary)
                        Circle()
                            .fill(FELDesign.Colors.textTertiary)
                            .frame(width: 5, height: 5)
                    }
                    Text("\(opponentScore)")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, FELDesign.Space.md)
            .padding(.vertical, FELDesign.Space.md)

            if isKarate {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            FELMicroLabel(text: "Chakra", color: FELDesign.Colors.textTertiary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black.opacity(0.5))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(FELDesign.Colors.cyan)
                                        .frame(width: geo.size.width * (chakraBar / 100))
                                        .animation(.spring(response: 0.3), value: chakraBar)
                                }
                            }
                            .frame(width: 80, height: 6)
                            .clipShape(.rect(cornerRadius: 3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                            )
                        }
                        .padding(.trailing, FELDesign.Space.md)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(FELDesign.Colors.surface.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FELDesign.Colors.hairline)
                .frame(height: FELDesign.Stroke.hairline)
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
                useNexus3DEngine: Config.useNexus3DGameplay,
                neuralDrive: viewModel.profile.metrics.neuralDrive,
                scenicCameraAngle: ScenicCameraAngle.defaultForMode(gameMode.id),
                onViewportReady: { sceneViewportReady = true },
                leftStickInput: leftStickVector,
                rightStickInput: rightStickVector,
                isMidAir: isDunkContest ? (dunkEngine.phase == .airborne || dunkEngine.phase == .launch) : false,
                isSpecialMove: isSlowMo || showVanishFlash || showPerfectGuard,
                isSlowMotion: isSlowMo,
                avatarAppearance: GameplayAvatarAppearance.fromProfile(viewModel.profile),
                karateStrikeNonce: karateStrikeNonce,
                karateStrikeAsset: karateStrikeAsset,
                karateOpponentEventNonce: karateOpponentEventNonce,
                karateOpponentEvent: karateOpponentEvent,
                karateHitstopNonce: karateHitstopNonce,
                karateHitstopCritical: karateHitstopCritical,
                basketballCrossoverNonce: basketballCrossoverNonce,
                basketballJumpShotNonce: basketballJumpShotNonce,
                basketballDunkClipAsset: basketballDunkClipAsset,
                sportActionNonce: sportActionNonce,
                sportActionLabel: sportActionLabel,
                onKarateStrike: { inRange in karateInStrikeRange = inRange },
                onAI3v3Score: { isPlayerTeam, teamTotal in
                    // The on-court AI scored (never blue1 — the human's makes go
                    // through performAction). teamTotal is the controller's
                    // cumulative team score; add the DELTA since we last saw it so
                    // it composes additively with the player's own manual taps
                    // instead of a max/sum hybrid (P2). Blue teammates (blue2/
                    // blue3) assist the player's side → player score; red → the
                    // scoreboard opponent. Both feed the target-21 / countdown end.
                    guard isActive else { return }
                    withAnimation(.spring(response: 0.25)) {
                        if isPlayerTeam {
                            let delta = max(0, teamTotal - ai3v3BlueSeen)
                            ai3v3BlueSeen = teamTotal
                            score += delta
                        } else {
                            let delta = max(0, teamTotal - ai3v3RedSeen)
                            ai3v3RedSeen = teamTotal
                            opponentScore += delta
                        }
                    }
                    if isBlacktop && gameRules.usesTargetScoreWin {
                        if score >= targetScore || opponentScore >= targetScore { endGame() }
                    }
                }
            )
            .clipShape(.rect(cornerRadius: 0))

            if !sceneViewportReady {
                sceneViewportLoadingOverlay
            }

            if isKarate {
                karateCombatOverlay
            }

            if combo > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: FELDesign.Space.xxs) {
                            Text(isKarate ? "\(combo) HIT COMBO!" : "\(combo)x COMBO")
                                .font(FELDesign.Typography.stat)
                                .foregroundStyle(comboColor)
                            Group {
                                if isKarate {
                                    Text(karateComboSubtitle)
                                } else {
                                    Text(String(format: "%.1fx", arcadePhysics.comboMultiplier(for: combo)))
                                }
                            }
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(combo >= 8 ? FELDesign.Colors.purple : FELDesign.Colors.textSecondary)
                        }
                        .padding(.horizontal, FELDesign.Space.md)
                        .padding(.vertical, FELDesign.Space.xs)
                        .background(FELDesign.Colors.surface.opacity(0.85))
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                                .stroke(combo >= 5 ? FELDesign.Colors.glow(comboColor, 0.55) : FELDesign.Colors.hairline,
                                        lineWidth: combo >= 5 ? FELDesign.Stroke.accent : FELDesign.Stroke.hairline)
                        )
                        .shadow(color: combo >= 5 ? FELDesign.Colors.glow(comboColor, 0.6) : .clear,
                                radius: combo >= 8 ? 12 : 6)
                        .scaleEffect(1.0 + min(CGFloat(combo), 12) * 0.02)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: combo)
                        .padding(FELDesign.Space.md)
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
                VStack {
                    Spacer()
                    JudgeScoreRollUp(
                        judges: [judges.0, judges.1, judges.2],
                        maxPerJudge: 17,
                        accent: FELDesign.Colors.cyan,
                        eliteTotalThreshold: 42,
                        message: crowdMessage,
                        reveal: $judgeRollUpReveal
                    )
                    .padding(.bottom, 80)
                }
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
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

    private var sceneViewportLoadingOverlay: some View {
        ZStack {
            FELDesign.Colors.ink.opacity(0.92)
            VStack(spacing: FELDesign.Space.sm) {
                ProgressView()
                    .tint(FELDesign.Colors.cyan)
                Text("Loading \(gameMode.name) arena…")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
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
    // Judge reveal is rendered by the reusable JudgeScoreRollUp component
    // (FELJudgeScoreRollUp.swift), driven by `judgeRollUpReveal`.

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 8) {
            if inputScheme == .charge {
                // Pad input now comes from the full-screen FELGamepadView
                // overlay (see body); only mode-specific quick actions remain.
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
                    if let tier = gameMode.felHonestTierLabel {
                        FELPreviewLabel(text: tier)
                            .padding(.top, 2)
                    }
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

    // MARK: - Film Quiz & Court Carnival Polish Views
    
    private var filmQuizControlView: some View {
        let questionIndex = min(roundNumber - 1, 5)
        let question = FilmQuestion.filmQuestions[questionIndex]
        let hasAnswered = selectedFilmChoice != nil
        
        return VStack(spacing: 12) {
            // Biomechanical Canvas
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "figure.run.motion")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.brandCyan)
                    Text("NEURAL ANALYZER: \(question.animationType.rawValue.uppercased())")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                BiomechanicalSkeletonView(animationType: question.animationType, time: skeletonJointsTime)
                    .frame(height: 155)
                    .background(Color.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.5), Theme.brandBlue.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, 8)
            }
            .background(Theme.cardBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.brandCyan.opacity(0.8), .clear, Theme.brandBlue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Theme.brandCyan.opacity(0.15), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 12)
            
            // Shrinking Timer bar
            if !hasAnswered {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.brandCyan, Theme.brandBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(filmQuestionTimer / 8.0))
                            .shadow(color: Theme.brandCyan.opacity(0.6), radius: 4, x: 0, y: 0)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 16)
                .animation(.linear(duration: 0.05), value: filmQuestionTimer)
            }
            
            // Question Card
            VStack(alignment: .leading, spacing: 10) {
                Text("QUESTION \(roundNumber) OF 6")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(gameMode.accentColor)
                
                Text(question.question)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !filmQuestionFeedback.isEmpty {
                    Text(filmQuestionFeedback)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(filmQuestionFeedback.contains("CORRECT") ? Theme.neonGreen : .red)
                        .shadow(color: (filmQuestionFeedback.contains("CORRECT") ? Theme.neonGreen : .red).opacity(0.4), radius: 8)
                        .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.cardBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [gameMode.accentColor.opacity(0.7), .clear, gameMode.accentColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: gameMode.accentColor.opacity(0.15), radius: 8, x: 0, y: 3)
            .padding(.horizontal, 12)
            
            // Choices with Premium Polish
            VStack(spacing: 8) {
                ForEach(0..<4) { idx in
                    let isSelected = selectedFilmChoice == idx
                    let isCorrect = idx == question.correctIndex
                    let textColor: Color = {
                        if hasAnswered {
                            if isCorrect {
                                return Theme.neonGreen
                            } else if isSelected {
                                return .red
                            } else {
                                return .white.opacity(0.4)
                            }
                        } else {
                            return .white
                        }
                    }()
                    let buttonBg: Color = {
                        if hasAnswered {
                            if isCorrect {
                                return Theme.neonGreen.opacity(0.08)
                            } else if isSelected {
                                return Color.red.opacity(0.08)
                            } else {
                                return Theme.surfaceElevated.opacity(0.25)
                            }
                        } else {
                            return Theme.surfaceElevated.opacity(0.6)
                        }
                    }()
                    let buttonStroke: Color = {
                        if hasAnswered {
                            if isCorrect {
                                return Theme.neonGreen.opacity(0.4)
                            } else if isSelected {
                                return Color.red.opacity(0.4)
                            } else {
                                return Color.white.opacity(0.03)
                            }
                        } else {
                            return Color.white.opacity(0.08)
                        }
                    }()
                    
                    Button {
                        selectFilmChoice(idx)
                    } label: {
                        HStack {
                            Text(question.choices[idx])
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(textColor)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if hasAnswered {
                                if isCorrect {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.neonGreen)
                                        .font(.system(size: 14))
                                } else if isSelected {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.system(size: 14))
                                } else {
                                    Circle()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                                        .frame(width: 14, height: 14)
                                }
                            } else {
                                Circle()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(buttonBg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(buttonStroke, lineWidth: 1)
                                )
                        )
                    }
                    .disabled(hasAnswered)
                    .scaleEffect(isSelected ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3), value: selectedFilmChoice)
                }
            }
            .padding(.horizontal, 12)
            
            // Conditional Explanation & Continue view below choices
            if filmShowExplanation {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EXPLANATION")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(question.explanation)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Theme.surfaceElevated.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    
                    Button {
                        resolveFilmQuestionNext()
                    } label: {
                        Text("CONTINUE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(gameMode.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: gameMode.accentColor.opacity(0.4), radius: 8)
                    }
                }
                .padding(.horizontal, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.bottom, 30)
    }

    private var partyBoardControlView: some View {
        VStack(spacing: 12) {
            // Horizontal path tiles track
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 12))
                        .foregroundStyle(gameMode.accentColor)
                    Text("VENICE CARNIVAL ROADMAP")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("SPACE \(courtCarnivalBoardSpace)/15")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(gameMode.accentColor)
                }
                .padding(.horizontal, 8)
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(BoardTile.boardTiles) { tile in
                                let isCurrent = courtCarnivalBoardSpace == tile.id
                                let tileColor = carnivalTileColor(tile.type)
                                let tileBgGradient = isCurrent
                                    ? LinearGradient(colors: [gameMode.accentColor, gameMode.accentColor.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Theme.surfaceElevated.opacity(0.75), Theme.cardBackground.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                let tileStrokeColor = isCurrent ? Color.white : tileColor.opacity(0.35)
                                let tileStrokeWidth: CGFloat = isCurrent ? 2 : 1
                                let tileShadowColor = isCurrent ? gameMode.accentColor.opacity(0.6) : tileColor.opacity(0.15)
                                let tileShadowRadius: CGFloat = isCurrent ? 10 : 4
                                
                                VStack(spacing: 4) {
                                    Image(systemName: carnivalTileIcon(tile.type))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(isCurrent ? .black : tileColor)
                                        .shadow(color: isCurrent ? .clear : tileColor.opacity(0.4), radius: isCurrent ? 0 : 3)
                                    Text(tile.type.rawValue)
                                        .font(.system(size: 6, weight: .black, design: .monospaced))
                                        .foregroundStyle(isCurrent ? .black : .white.opacity(0.7))
                                    Text(tile.name)
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(isCurrent ? .black.opacity(0.9) : .white.opacity(0.8))
                                        .lineLimit(1)
                                }
                                .frame(width: 72, height: 78)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(tileBgGradient)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(tileStrokeColor, lineWidth: tileStrokeWidth)
                                        )
                                        .shadow(color: tileShadowColor, radius: tileShadowRadius)
                                )
                                .scaleEffect(isCurrent ? 1.06 : 0.96)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: courtCarnivalBoardSpace)
                                .id(tile.id)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: courtCarnivalBoardSpace) { _, newSpace in
                        withAnimation(.spring(response: 0.35)) {
                            proxy.scrollTo(newSpace, anchor: .center)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(courtCarnivalBoardSpace, anchor: .center)
                    }
                }
            }
            .padding(10)
            .background(Theme.cardBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(colors: [gameMode.accentColor.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.5
                    )
            )
            .padding(.horizontal, 12)
            
            // Dice Roll & Event card display area
            if let activeEvent = courtCarnivalEvent {
                let currentTileType = carnivalTileType(activeEvent)
                let eventColor = carnivalTileColor(currentTileType)
                
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: carnivalTileIcon(currentTileType))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(eventColor)
                        Text(carnivalEventTitle(activeEvent).uppercased())
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    
                    carnivalEventCardBody(activeEvent)
                }
                .padding(14)
                .background(Theme.cardBackground.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(colors: [eventColor.opacity(0.8), eventColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                )
                .shadow(color: eventColor.opacity(0.35), radius: 14, x: 0, y: 4)
                .padding(.horizontal, 12)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            } else {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CNS QUANTUM DICE")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("Roll to traverse the Venice Beach circuit")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    
                    ZStack {
                        // Futuristic Mesh Backdrop
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.meshGradient)
                            .frame(width: 85, height: 85)
                            .blur(radius: 0.5)
                        
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 85, height: 85)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        LinearGradient(
                                            colors: [gameMode.accentColor, gameMode.accentColor.opacity(0.2), Theme.brandCyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2.5
                                    )
                            )
                            .shadow(color: gameMode.accentColor.opacity(0.75), radius: 15, x: 0, y: 0)
                            .rotation3DEffect(
                                .degrees(courtCarnivalRollAngle),
                                axis: (x: 1.0, y: 1.0, z: 0.5)
                            )
                        
                        Text("\(courtCarnivalDiceFace)")
                            .font(.system(size: 38, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: gameMode.accentColor, radius: 8)
                            .shadow(color: Theme.brandCyan, radius: 2)
                            .scaleEffect(courtCarnivalRollingActive ? 0.85 : 1.15)
                            .animation(.spring(response: 0.2), value: courtCarnivalDiceFace)
                    }
                    .frame(height: 100)
                    
                    Button {
                        rollQuantumDice()
                    } label: {
                        Text(courtCarnivalRollingActive ? "ROLLING QUANTUM STATES..." : "ROLL QUANTUM DICE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(courtCarnivalRollingActive ? .white.opacity(0.4) : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(courtCarnivalRollingActive ? Color.white.opacity(0.08) : gameMode.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: courtCarnivalRollingActive ? .clear : gameMode.accentColor.opacity(0.4), radius: 8)
                    }
                    .disabled(courtCarnivalRollingActive)
                }
                .padding(14)
                .background(Theme.cardBackground.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(colors: [gameMode.accentColor.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
                .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 30)
    }

    // MARK: - Film Quiz & Court Carnival Helper Actions

    private func startSkeletonAnimation() {
        skeletonAnimationTask?.cancel()
        skeletonAnimationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
                guard !Task.isCancelled else { return }
                skeletonJointsTime += 0.015
                if skeletonJointsTime > 1.0 {
                    skeletonJointsTime = 0.0
                }
            }
        }
    }

    private func startQuestionTimer() {
        filmQuestionTimer = 8.0
        filmTimerTask?.cancel()
        filmTimerTask = Task {
            let start = Date()
            while !Task.isCancelled && filmQuestionTimer > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                let elapsed = Date().timeIntervalSince(start)
                let remaining = max(0, 8.0 - elapsed)
                filmQuestionTimer = remaining
                if remaining <= 0 {
                    handleExpiredQuestion()
                }
            }
        }
    }

    private func handleExpiredQuestion() {
        guard selectedFilmChoice == nil else { return }
        selectedFilmChoice = -1
        filmQuestionFeedback = "TIME EXPIRED!"
        filmShowExplanation = true
        hapticFail()
    }

    private func selectFilmChoice(_ index: Int) {
        guard selectedFilmChoice == nil else { return }
        filmTimerTask?.cancel()
        filmTimerTask = nil
        
        selectedFilmChoice = index
        FELGameplayEventBus.postBuzzIn()
        let question = FilmQuestion.filmQuestions[min(roundNumber - 1, 5)]
        let isCorrect = index == question.correctIndex
        
        if isCorrect {
            filmQuestionFeedback = "CORRECT!"
            hapticSuccess(isCritical: false)
        } else {
            filmQuestionFeedback = "INCORRECT"
            hapticFail()
        }
        filmShowExplanation = true
    }

    private func resolveFilmQuestionNext() {
        filmTimerTask?.cancel()
        filmTimerTask = nil
        
        let question = FilmQuestion.filmQuestions[min(roundNumber - 1, 5)]
        let isCorrect = selectedFilmChoice == question.correctIndex
        
        filmShowExplanation = false
        selectedFilmChoice = nil
        filmQuestionFeedback = ""
        
        performAction(isCorrect ? "Correct: \(question.animationType.rawValue)" : "Incorrect: \(question.animationType.rawValue)")
        
        if roundNumber <= maxRounds {
            startQuestionTimer()
        }
    }

    private func rollQuantumDice() {
        guard !courtCarnivalRollingActive && courtCarnivalEvent == nil else { return }
        courtCarnivalRollingActive = true
        courtCarnivalRollAngle = 0.0
        
        Task {
            for _ in 0..<12 {
                try? await Task.sleep(for: .milliseconds(80))
                courtCarnivalDiceFace = Int.random(in: 1...6)
                withAnimation(.linear(duration: 0.08)) {
                    courtCarnivalRollAngle += 90.0
                }
            }
            
            let roll = Int.random(in: 1...6)
            courtCarnivalDiceFace = roll
            courtCarnivalRollingActive = false
            
            for _ in 0..<roll {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.spring(response: 0.25)) {
                    courtCarnivalBoardSpace = (courtCarnivalBoardSpace + 1) % 16
                }
            }
            
            triggerCarnivalEvent(for: courtCarnivalBoardSpace)
        }
    }

    private func triggerCarnivalEvent(for space: Int) {
        let tile = BoardTile.boardTiles[space]
        withAnimation(.spring(response: 0.4)) {
            switch tile.type {
            case .start, .grandPortal:
                courtCarnivalEvent = nil
                performAction("Landed on \(tile.name)")
            case .neuralBoost:
                courtCarnivalEvent = .neuralBoost
                courtCarnivalSelectedBranch = nil
            case .sponsorHub:
                courtCarnivalEvent = .sponsorHub
            case .biomechanicalPit:
                courtCarnivalEvent = .biomechanicalPit
                courtCarnivalTapCount = 0
                courtCarnivalTapGoal = Int.random(in: 15...25)
                startCarnivalTapTimer()
            case .cnsDuel:
                courtCarnivalEvent = .cnsDuel
                courtCarnivalDuelTarget = Int.random(in: 3...6)
                courtCarnivalDuelPlayerRoll = nil
                courtCarnivalDuelOpponentRoll = nil
            }
        }
    }

    private func startCarnivalTapTimer() {
        courtCarnivalTapTimer = 5.0
        courtCarnivalTapTimerTask?.cancel()
        courtCarnivalTapTimerTask = Task {
            let start = Date()
            while !Task.isCancelled && courtCarnivalTapTimer > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                let elapsed = Date().timeIntervalSince(start)
                let remaining = max(0, 5.0 - elapsed)
                courtCarnivalTapTimer = remaining
                
                if courtCarnivalTapCount >= courtCarnivalTapGoal {
                    break
                }
                
                if remaining <= 0 {
                    hapticFail()
                }
            }
        }
    }

    private func rollDuelDice() {
        hapticSuccess(isCritical: false)
        courtCarnivalDuelPlayerRoll = Int.random(in: 1...6)
    }

    private func resolveCarnivalEvent(action: String) {
        courtCarnivalTapTimerTask?.cancel()
        courtCarnivalTapTimerTask = nil
        
        performAction(action)
        
        courtCarnivalEvent = nil
        courtCarnivalSelectedBranch = nil
        courtCarnivalDuelPlayerRoll = nil
        courtCarnivalDuelOpponentRoll = nil
        courtCarnivalTapCount = 0
    }

    private func carnivalTileIcon(_ type: BoardTile.TileType) -> String {
        switch type {
        case .start: return "play.circle.fill"
        case .neuralBoost: return "bolt.fill"
        case .sponsorHub: return "dollarsign.circle.fill"
        case .biomechanicalPit: return "exclamationmark.triangle.fill"
        case .cnsDuel: return "shield.fill"
        case .grandPortal: return "sparkles.rectangle.stack.fill"
        }
    }

    private func carnivalTileColor(_ type: BoardTile.TileType) -> Color {
        switch type {
        case .start, .grandPortal: return .white
        case .neuralBoost: return Theme.brandCyan
        case .sponsorHub: return .yellow
        case .biomechanicalPit: return .orange
        case .cnsDuel: return Theme.elitePurple
        }
    }

    private func carnivalTileType(_ event: CarnivalEvent) -> BoardTile.TileType {
        switch event {
        case .neuralBoost: return .neuralBoost
        case .sponsorHub: return .sponsorHub
        case .biomechanicalPit: return .biomechanicalPit
        case .cnsDuel: return .cnsDuel
        }
    }

    private func carnivalEventTitle(_ event: CarnivalEvent) -> String {
        switch event {
        case .neuralBoost: return "Synaptic Choice"
        case .sponsorHub: return "Kinetic Endorsement"
        case .biomechanicalPit: return "Biomechanical Pit Escape"
        case .cnsDuel: return "CNS Duel Roll-Off"
        }
    }

    @ViewBuilder
    private func carnivalEventCardBody(_ event: CarnivalEvent) -> some View {
        switch event {
        case .neuralBoost:
            if let selected = courtCarnivalSelectedBranch {
                VStack(spacing: 12) {
                    Text(selected == 0 ? "VELOCITY FOCUS OPTIMIZED!" : (selected == -1 ? "VELOCITY BOOST OVERLOAD!" : "RECOVERY PATH CHOSEN!"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(selected == -1 ? .red : Theme.neonGreen)
                    
                    Text(selected == 0 
                         ? "High acceleration vectors deployed. Neural sync locked (+300 pts)." 
                         : (selected == -1 ? "Rotational velocity exceeded neural drive capabilities. Overload fault (-50 pts)." : "Kinetic absorption stabilizers active. Safety margin guaranteed (+120 pts)."))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        resolveCarnivalEvent(action: selected == 0 ? "Neural Boost Success" : (selected == -1 ? "Neural Boost Fail" : "Neural Boost Safe"))
                    } label: {
                        Text("CONTINUE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(gameMode.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Text("Select a synaptic pathway boost configuration:")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 4)
                    
                    Button {
                        let success = Double.random(in: 0...1) < 0.6
                        withAnimation {
                            courtCarnivalSelectedBranch = success ? 0 : -1
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("BRANCH A: VELOCITY FOCUS (High Risk)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                            Text("60% chance for +300 pts. 40% chance for -50 pts.")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Theme.surfaceElevated.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Button {
                        withAnimation {
                            courtCarnivalSelectedBranch = 2
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("BRANCH B: RECOVERY COIL (Safe)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.yellow)
                            Text("100% chance for +120 pts.")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Theme.surfaceElevated.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
        case .biomechanicalPit:
            let isDone = courtCarnivalTapCount >= courtCarnivalTapGoal
            let isFailed = courtCarnivalTapTimer <= 0 && !isDone
            
            VStack(spacing: 12) {
                if isDone {
                    Text("PIT ESCAPED SUCCESSFULLY!")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                    Text("You balanced all kinetic joints in time (+250 pts).")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Button {
                        resolveCarnivalEvent(action: "Biomechanical Pit Success")
                    } label: {
                        Text("CONTINUE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(gameMode.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else if isFailed {
                    Text("LOAD OVERLOAD! ESCAPE FAILED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                    Text("Hips collapsed under excessive load. Try again next round.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Button {
                        resolveCarnivalEvent(action: "Biomechanical Pit Fail")
                    } label: {
                        Text("CONTINUE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(gameMode.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Rapidly tap the kinetic drive to clear the load!")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.8))
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.brandCyan)
                                    .frame(width: geo.size.width * CGFloat(Double(courtCarnivalTapCount) / Double(courtCarnivalTapGoal)))
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text("Taps: \(courtCarnivalTapCount)/\(courtCarnivalTapGoal)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                            Spacer()
                            Text(String(format: "Time: %.1fs", courtCarnivalTapTimer))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(courtCarnivalTapTimer < 2.0 ? .red : .yellow)
                        }
                        
                        Button {
                            courtCarnivalTapCount += 1
                            hapticSuccess(isCritical: false)
                            if courtCarnivalTapCount >= courtCarnivalTapGoal {
                                courtCarnivalTapTimerTask?.cancel()
                                courtCarnivalTapTimerTask = nil
                            }
                        } label: {
                            Text("ESCAPE!")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                                .frame(width: 80, height: 40)
                                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.brandCyan))
                                .shadow(color: Theme.brandCyan.opacity(0.6), radius: 10)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
        case .sponsorHub:
            let pointsMultiplier = max(1, combo)
            let awarded = 150 * pointsMultiplier
            
            VStack(spacing: 12) {
                Text("NEURAL ENDORSEMENT CLAIMS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                
                VStack(spacing: 4) {
                    Text("Base Reward: +150 Points")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Combo Multiplier: x\(combo)")
                        .font(.system(size: 10))
                        .foregroundStyle(combo > 1 ? Theme.brandCyan : .secondary)
                    Text("Total Claim: +\(awarded) Points")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                }
                
                Button {
                    resolveCarnivalEvent(action: "Sponsor Hub \(awarded)")
                } label: {
                    Text("CLAIM REWARD")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.yellow.opacity(0.4), radius: 8)
                }
            }
            
        case .cnsDuel:
            if let playerRoll = courtCarnivalDuelPlayerRoll {
                let opponentRoll = courtCarnivalDuelTarget
                let outcome = duelOutcome(player: playerRoll, opponent: opponentRoll)
                
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        VStack {
                            Text("YOU")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                            Text("\(playerRoll)")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(outcome.color)
                        }
                        Text("VS")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.secondary)
                        VStack {
                            Text("SHADOW")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                            Text("\(opponentRoll)")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Theme.surfaceElevated.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Text(outcome.text)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(outcome.color)
                    
                    Button {
                        resolveCarnivalEvent(action: outcome.action)
                    } label: {
                        Text("CONTINUE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(gameMode.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("AI Shadow target roll: \(courtCarnivalDuelTarget)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Button {
                        rollDuelDice()
                    } label: {
                        Text("ROLL DUEL DICE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.elitePurple)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Theme.elitePurple.opacity(0.4), radius: 8)
                    }
                }
            }
        }
    }

    private func duelOutcome(player: Int, opponent: Int) -> (text: String, color: Color, action: String) {
        if player > opponent {
            return ("VICTORY! SHADOW OUT-ROLLED (+300 pts)", Theme.neonGreen, "CNS Duel Win")
        } else if player == opponent {
            return ("TIE! SHARED COGNITIVE BALANCE (+100 pts)", .yellow, "CNS Duel Tie")
        } else {
            return ("DEFEAT! SHADOW DOMINATED (0 pts)", .red, "CNS Duel Lose")
        }
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
                HStack(spacing: FELDesign.Space.xxs) {
                    Image(systemName: "l2.button.roundedbottom.horizontal")
                        .font(.system(size: 11, weight: .bold))
                    Text("STYLE")
                        .font(FELDesign.Typography.micro)
                        .tracking(FELDesign.Typography.microTracking)
                }
                .foregroundStyle(styleTriggerHeld ? FELDesign.Colors.ink : FELDesign.Colors.purple)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                        .fill(styleTriggerHeld ? FELDesign.Colors.purple : FELDesign.Colors.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                .stroke(styleTriggerHeld ? FELDesign.Colors.purple : FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                        )
                )
            }

            VStack(spacing: 2) {
                FELMicroLabel(text: dunkEngine.activeModifier.label, color: modifierLabelColor)
                Text(String(format: "%.1fx", dunkEngine.activeModifier.scoreMultiplier))
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }
            .frame(width: 70)

            Button {
                withAnimation(.spring(response: 0.15)) {
                    powerTriggerHeld.toggle()
                    dunkEngine.setModifier(styleTrigger: styleTriggerHeld, powerTrigger: powerTriggerHeld)
                }
            } label: {
                HStack(spacing: FELDesign.Space.xxs) {
                    Image(systemName: "r2.button.roundedbottom.horizontal")
                        .font(.system(size: 11, weight: .bold))
                    Text("POWER")
                        .font(FELDesign.Typography.micro)
                        .tracking(FELDesign.Typography.microTracking)
                }
                .foregroundStyle(powerTriggerHeld ? FELDesign.Colors.ink : FELDesign.Colors.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                        .fill(powerTriggerHeld ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                .stroke(powerTriggerHeld ? FELDesign.Colors.cyan : FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                        )
                )
            }
        }
    }

    private var modifierLabelColor: Color {
        switch dunkEngine.activeModifier {
        case .standard: return FELDesign.Colors.textSecondary
        case .flashy: return FELDesign.Colors.purple
        case .power: return FELDesign.Colors.cyan
        case .signature: return FELDesign.Colors.purple
        }
    }

    private var dunkTrickSelector: some View {
        VStack(spacing: 8) {
            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FELDesign.Colors.textTertiary)
                FELMicroLabel(text: "Select Trick", color: FELDesign.Colors.textSecondary)
                Spacer()
                Text("R\(dunkEngine.round)/\(dunkEngine.totalRounds)")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DunkTrickSlot.allCases, id: \.rawValue) { trick in
                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                dunkEngine.selectedTrick = trick
                            }
                        } label: {
                            VStack(spacing: FELDesign.Space.xxs) {
                                Image(systemName: trick.icon)
                                    .font(.system(size: 16, weight: .bold))
                                Text(trick.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                HStack(spacing: 2) {
                                    ForEach(0..<5, id: \.self) { i in
                                        Circle()
                                            .fill(Double(i) / 5.0 < trick.complexity
                                                ? (dunkEngine.selectedTrick == trick ? FELDesign.Colors.ink : FELDesign.Colors.cyan)
                                                : (dunkEngine.selectedTrick == trick ? FELDesign.Colors.ink.opacity(0.3) : FELDesign.Colors.hairline))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                            }
                            .foregroundStyle(dunkEngine.selectedTrick == trick ? FELDesign.Colors.ink : FELDesign.Colors.textPrimary)
                            .frame(width: 72, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                                    .fill(dunkEngine.selectedTrick == trick ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                                            .stroke(dunkEngine.selectedTrick == trick ? FELDesign.Colors.cyan : FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
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
                    .font(FELDesign.Typography.label)
            }
            .foregroundStyle(FELDesign.Colors.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(FELDesign.Colors.cyan)
            .clipShape(.rect(cornerRadius: FELDesign.Radius.lg))
        }
        .disabled(!isActive)
        .opacity(isActive ? 1 : 0.5)
    }

    private var dunkSprintChargeView: some View {
        VStack(spacing: 10) {
            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FELDesign.Colors.cyan)
                FELMicroLabel(text: "Hold to Sprint", color: FELDesign.Colors.textPrimary)
                Spacer()
                Text("\(Int(dunkEngine.sprintCharge * 100))%")
                    .font(FELDesign.Typography.stat)
                    .foregroundStyle(FELDesign.Colors.cyan)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.6))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(dunkEngine.sprintCharge > 0.8 ? FELDesign.Colors.purple : FELDesign.Colors.cyan)
                        .frame(width: geo.size.width * dunkEngine.sprintCharge)
                        .animation(.linear(duration: 0.05), value: dunkEngine.sprintCharge)
                }
            }
            .frame(height: 14)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
            )

            Button {
                releaseDunkSprint()
            } label: {
                Text("RELEASE TO LAUNCH")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FELDesign.Colors.cyan)
                    .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
            }
        }
    }

    private var dunkLaunchTimingView: some View {
        VStack(spacing: 10) {
            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FELDesign.Colors.success)
                FELMicroLabel(text: "Tap to Jump", color: FELDesign.Colors.textPrimary)
                Spacer()
            }

            dunkTimingBar(
                value: dunkEngine.launchTiming,
                greenZone: dunkEngine.launchGreenZone,
                accentColor: FELDesign.Colors.success
            )

            Button {
                confirmDunkLaunch()
            } label: {
                Text("JUMP!")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        dunkEngine.launchGreenZone.contains(dunkEngine.launchTiming)
                            ? FELDesign.Colors.cyan
                            : FELDesign.Colors.glow(FELDesign.Colors.cyan, 0.4)
                    )
                    .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
            }
        }
    }

    private var dunkArcadeAirborneControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "figure.highintensity.intervaltraining")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FELDesign.Colors.purple)
                FELMicroLabel(text: dunkEngine.selectedTrick.rawValue, color: FELDesign.Colors.textPrimary)
                Spacer()
                if dunkEngine.midAirState.branchCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(dunkEngine.midAirState.branchCount)x CHAIN")
                            .font(FELDesign.Typography.statSmall)
                    }
                    .foregroundStyle(FELDesign.Colors.purple)
                }
                Text("\(Int(dunkEngine.completedRotation * 100))%")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(dunkEngine.completedRotation >= 0.9 ? FELDesign.Colors.success : FELDesign.Colors.textPrimary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.6))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(dunkEngine.completedRotation >= 0.9 ? FELDesign.Colors.success : FELDesign.Colors.purple)
                        .frame(width: geo.size.width * min(1, dunkEngine.completedRotation))
                        .animation(.linear(duration: 0.05), value: dunkEngine.completedRotation)
                }
            }
            .frame(height: 8)
            .clipShape(.rect(cornerRadius: 5))

            if !dunkEngine.midAirState.trickChainLabel.isEmpty {
                Text(dunkEngine.midAirState.trickChainLabel)
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.cyan)
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
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(FELDesign.Colors.textSecondary)
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
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: "l1.button.roundedbottom.horizontal")
                                .font(.system(size: 11, weight: .bold))
                            Text("STYLE LAND")
                                .font(FELDesign.Typography.micro)
                                .tracking(FELDesign.Typography.microTracking)
                        }
                        .foregroundStyle(FELDesign.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FELDesign.Colors.purple)
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                Button {
                    confirmDunkLanding()
                } label: {
                    HStack(spacing: FELDesign.Space.xxs) {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 13, weight: .bold))
                        Text("SLAM!")
                            .font(FELDesign.Typography.micro)
                            .tracking(FELDesign.Typography.microTracking)
                    }
                    .foregroundStyle(FELDesign.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(FELDesign.Colors.cyan)
                    .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
                }
            }

            if dunkEngine.totalFreestylePoints > 0 {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(FELDesign.Colors.purple)
                    Text("FREESTYLE: +\(dunkEngine.totalFreestylePoints)")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.purple)
                    if dunkEngine.midAirState.comboMultiplier > 1.0 {
                        Text(String(format: "(%.1fx)", dunkEngine.midAirState.comboMultiplier))
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var dunkLandingTimingView: some View {
        VStack(spacing: 10) {
            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FELDesign.Colors.cyan)
                FELMicroLabel(text: "Stick the Landing", color: FELDesign.Colors.textPrimary)
                Spacer()
            }

            dunkTimingBar(
                value: dunkEngine.landingTiming,
                greenZone: dunkEngine.landingGreenZone,
                accentColor: FELDesign.Colors.success
            )

            Button {
                confirmDunkLanding()
            } label: {
                Text("LAND!")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        dunkEngine.landingGreenZone.contains(dunkEngine.landingTiming)
                            ? FELDesign.Colors.cyan
                            : FELDesign.Colors.glow(FELDesign.Colors.cyan, 0.4)
                    )
                    .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
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
                    .fill(greenZone.contains(value) ? accentColor : FELDesign.Colors.danger)
                    .frame(width: 4)
                    .offset(x: geo.size.width * value - 2)
                    .animation(.linear(duration: 0.03), value: value)
            }
        }
        .frame(height: 20)
        .clipShape(.rect(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
        )
    }

    private var dunkPhaseOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: dunkPhaseLabel, color: dunkPhaseColor)
                    if dunkEngine.phase == .airborne {
                        Text(String(format: "HEIGHT: %.0f%%", dunkEngine.jumpHeight * 100))
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }
                }
                .padding(FELDesign.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                        .fill(.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                        )
                )
                .padding(.trailing, FELDesign.Space.md)
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
        case .approach: return FELDesign.Colors.cyan
        case .launch: return FELDesign.Colors.success
        case .airborne: return FELDesign.Colors.purple
        case .landing: return FELDesign.Colors.cyan
        default: return FELDesign.Colors.textPrimary
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
        case .basketballHeadToHead, .venicePickup: ["Shoot", "Drive", "Crossover"]
        case .basketballDunkContest3D, .basketballDunkContestIRL: ["Power Dunk", "360 Dunk", "Windmill"]
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
        case .courtCarnival: ["Pad Hit", "Dice Roll", "Mini Win"]
        case .marketBrowse: ["Browse", "Scan", "Vault"]
        }
    }

    private var matchLobbyOverlay: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: FELDesign.Space.lg) {
                FELMicroLabel(text: "Multiplayer Setup", color: FELDesign.Colors.textSecondary)
                Text(gameMode.name)
                    .font(FELDesign.Typography.heading)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                Text("Session key: \(gameMode.id.rawValue)")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
                if multipeerService.pendingInvitationPeerName != nil {
                    Text("Incoming invite — use Accept or Decline in the toolbar.")
                        .font(FELDesign.Typography.caption)
                        .foregroundStyle(FELDesign.Colors.cyan)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                HStack(spacing: FELDesign.Space.md) {
                    Button {
                        multipeerService.startHosting(gameId: gameMode.id.rawValue)
                    } label: {
                        Label("HOST", systemImage: "antenna.radiowaves.left.and.right")
                            .font(FELDesign.Typography.micro)
                            .foregroundStyle(FELDesign.Colors.cyan)
                            .padding(.horizontal, FELDesign.Space.md)
                            .padding(.vertical, FELDesign.Space.xs)
                            .background(FELDesign.Colors.surfaceRaised)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline))
                    }
                    Button {
                        multipeerService.startBrowsing(gameId: gameMode.id.rawValue)
                    } label: {
                        Label("JOIN", systemImage: "magnifyingglass")
                            .font(FELDesign.Typography.micro)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                            .padding(.horizontal, FELDesign.Space.md)
                            .padding(.vertical, FELDesign.Space.xs)
                            .background(FELDesign.Colors.surfaceRaised)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline))
                    }
                }
                Button {
                    withAnimation(.spring(response: 0.35)) { matchLobbyComplete = true }
                } label: {
                    Text("CONTINUE TO COUNTDOWN")
                        .font(FELDesign.Typography.label)
                        .foregroundStyle(FELDesign.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FELDesign.Space.md)
                        .background(FELDesign.Colors.cyan)
                        .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
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
        ai3v3BlueSeen = 0
        ai3v3RedSeen = 0
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

        goldenComboEngine = SignatureComboEngine()
        timeScaleManager = TimeScaleManager()
        matrixState = MatrixStateMachine()
        activeModifierState = .none
        lastQTEGrade = nil
        timeScaleUpdateTask?.cancel()
        timeScaleUpdateTask = nil

        skeletonAnimationTask?.cancel()
        skeletonAnimationTask = nil
        filmTimerTask?.cancel()
        filmTimerTask = nil
        courtCarnivalTapTimerTask?.cancel()
        courtCarnivalTapTimerTask = nil

        if gameMode.id == .whoSceneIt {
            selectedFilmChoice = nil
            filmQuestionTimer = 8.0
            filmQuestionFeedback = ""
            filmShowExplanation = false
            skeletonJointsTime = 0.0
            startSkeletonAnimation()
            startQuestionTimer()
        } else if gameMode.id == .courtCarnival {
            courtCarnivalBoardSpace = 0
            courtCarnivalDiceFace = 1
            courtCarnivalRollingActive = false
            courtCarnivalRollAngle = 0.0
            courtCarnivalEvent = nil
            courtCarnivalTapCount = 0
            courtCarnivalSelectedBranch = nil
            courtCarnivalDuelPlayerRoll = nil
            courtCarnivalDuelOpponentRoll = nil
        }

        if isTimerBased {
            timeRemaining = max(1, gameRules.matchDurationSeconds)
            startTimer()
        }

        // Karate Excellence: reset combo/opponent/wave state and spin up the
        // deterministic opponent AI (+ local wave engine for endless).
        karateCombo.reset()
        recentStrikeButtons.removeAll()
        comboExpiryTask?.cancel(); comboExpiryTask = nil
        opponentAITask?.cancel(); opponentAITask = nil
        waveTickTask?.cancel(); waveTickTask = nil
        showWaveClear = false
        karateVictory = false
        karateDefeat = false
        karatePlayerHP = Self.karatePlayerMaxHP
        karateInStrikeRange = true
        opponentAI = nil
        opponentHP = 0
        opponentMaxHP = 0
        pendingOpponentAttack = nil
        if isKarate {
            if gameMode.id == .karateEndless {
                waveEngine = KarateEndlessWaveEngine()
                startKarateWaveTick()
            } else {
                waveEngine = nil
            }
            spawnKarateOpponent()
        } else {
            waveEngine = nil
        }
    }

    private func startKarateWaveTick() {
        waveTickTask?.cancel()
        waveTickTask = Task { @MainActor in
            var lastWave = waveEngine?.wave ?? 1
            while !Task.isCancelled, isActive {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, isActive else { return }
                waveEngine?.tickSecond()
                if let w = waveEngine {
                    if w.isOver { handlePlayerDefeated(); return }
                    // Intermission just ended → new wave began → spawn its first
                    // opponent.
                    if w.wave != lastWave {
                        lastWave = w.wave
                        if opponentAI == nil { spawnKarateOpponent() }
                    }
                }
            }
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

        // Karate never uses the generic score/DDA path — it's a KO fight loop.
        // A tap-anywhere on the scene throws a quick jab; face buttons route
        // through performKarateStrike directly. Guarding this here also stops
        // the DDA opponent-score generation below from firing for karate.
        if isKarate {
            performKarateStrike(.square)
            return
        }

        // Basketball possession modes: fire the matching baked clip on the scene
        // host. Shoot swaps in the JumpShot one-shot (releasing the ball);
        // Crossover swaps in the DribbleCrossover clip. Fail-soft: the host
        // no-ops if the clip is missing. This only drives visuals — scoring below
        // is unchanged.
        if isBasketballPossession {
            switch action {
            case "Shoot": basketballJumpShotNonce += 1
            case "Crossover": basketballCrossoverNonce += 1
            default: break
            }
        }

        // Per-sport action: drive the scene host's action animation, which
        // prefers a bundled full-body Action_<mode>_<action>.usdz clip and falls
        // back to the procedural arm-swing. Only fire for modes the registry
        // covers (golf/tennis/baseball/soccer/volleyball/football).
        if SportActionAnimationLibrary.modeToken(for: gameMode.id) != nil {
            sportActionLabel = action
            sportActionNonce += 1
        }

        playerActionCount += 1

        let physics = leakageAdjustedPhysics
        let modeChance = PRQ.successChanceFromPRQ(playerPRQ, for: gameMode.id)
        let blendedChance = (physics.successChanceBase + modeChance) / 2.0
        let contestedChance = applyContestToShot(baseChance: blendedChance)
        let driveMultiplier = defensiveState.driveSpeedMultiplier
        let effectiveChance = (action == "Drive" || action == "Crossover") ? contestedChance * driveMultiplier : contestedChance
        var success = Double.random(in: 0...1) < effectiveChance
        if gameMode.id == .whoSceneIt {
            if action.contains("Correct") {
                success = true
            } else if action.contains("Incorrect") || action.contains("Expired") {
                success = false
            }
        } else if gameMode.id == .courtCarnival {
            if action.contains("Success") || action.contains("Win") || action.contains("Tie") || action.contains("Boost") || action.contains("Hub") {
                success = true
            } else if action.contains("Fail") || action.contains("Lose") {
                success = false
            }
        }
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

                // Karate never reaches here (it returns early above and runs
                // its own KO fight loop in resolveKarateStrike).
                if isCritical {
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

            if isCritical {
                triggerCriticalFlash()
                triggerScreenShake(intensity: 0.6)
            } else {
                triggerFlash()
                triggerScreenShake(intensity: Double(physicsConfig.floorShakeAmplitude) * 10)
            }

            triggerImpactFlash()
            resetStreakTimer()
            hapticSuccess(isCritical: isCritical)
            FELGameplayEventBus.postScored()
            FELSoundscapeEngine.shared.triggerCheer(intensity: isCritical ? 1.0 : 0.65)
            FELSoundscapeEngine.shared.combo = combo

        } else {
            withAnimation(.spring(response: 0.3)) {
                combo = 0
                lastAction = "MISSED"
                lastActionIsCritical = false
                lastActionIsBurst = false
            }
            if gameMode.id == .soccer {
                FELGameplayEventBus.postPenalty()
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
                // Symmetric target-score end: the AI can now actually WIN by
                // reaching 21 (blacktop h2h/3v3). Previously only the player's
                // score could trigger the target end, so the ghost could never
                // close out a match — it only inflated the results comparison.
                if isBlacktop && gameRules.usesTargetScoreWin && opponentScore >= targetScore {
                    endGame()
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

    // MARK: - Karate Excellence HUD

    /// White → cyan → gold color ramp by combo depth.
    private var comboColor: Color {
        if combo >= 8 { return Color(red: 1.0, green: 0.82, blue: 0.25) }   // gold
        if combo >= 5 { return FELDesign.Colors.cyan }
        return FELDesign.Colors.textPrimary
    }

    private var karateComboSubtitle: String {
        let label = karateCombo.tierLabel
        let mult = String(format: "%.2fx", karateCombo.multiplier)
        return label.isEmpty ? mult : "\(label)  \(mult)"
    }

    /// Opponent HP bar (1v1) or wave/score/HP survival HUD (endless), plus the
    /// between-round "WAVE CLEARED" beat and victory/defeat banner.
    @ViewBuilder
    private var karateCombatOverlay: some View {
        VStack(spacing: 6) {
            if gameMode.id == .karateEndless, let wave = waveEngine {
                HStack(spacing: 10) {
                    karateChip("WAVE", "\(wave.wave)")
                    karateChip("SCORE", "\(wave.score)")
                    karateChip("TIME", timeString(wave.elapsedSeconds))
                    Spacer()
                }
                karateHPBar(label: "YOU", fraction: wave.playerHPFraction,
                            color: FELDesign.Colors.cyan)
            } else {
                // 1v1: player HP bar (KO ends the match).
                karateHPBar(label: "YOU",
                            fraction: Double(karatePlayerHP) / Double(Self.karatePlayerMaxHP),
                            color: FELDesign.Colors.cyan)
            }
            if let ai = opponentAI, opponentMaxHP > 0, !ai.isDefeated || gameMode.id == .karate {
                karateHPBar(label: gameMode.id == .karateEndless ? "ENEMY" : "OPPONENT",
                            fraction: ai.hpFraction,
                            color: Color(red: 1.0, green: 0.4, blue: 0.3))
            }
            Spacer()
        }
        .padding(.horizontal, FELDesign.Space.md)
        .padding(.top, 56)
        .allowsHitTesting(false)

        if showWaveClear {
            VStack {
                Spacer()
                Text(karateVictory ? "SURVIVED!" : "WAVE \(waveEngine?.lastClearedWave ?? 0) CLEARED")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.25))
                    .shadow(color: FELDesign.Colors.glow(FELDesign.Colors.cyan, 0.7), radius: 16)
                    .scaleEffect(showWaveClear ? 1.0 : 0.6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: showWaveClear)
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }

    private func karateChip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(FELDesign.Colors.textSecondary)
            Text(value)
                .font(FELDesign.Typography.stat)
                .foregroundStyle(FELDesign.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(FELDesign.Colors.surface.opacity(0.8))
        .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
    }

    private func karateHPBar(label: String, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(FELDesign.Colors.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(max(0, min(1, fraction)))))
                        .shadow(color: FELDesign.Colors.glow(color, 0.6), radius: 4)
                        .animation(.spring(response: 0.35), value: fraction)
                }
            }
            .frame(height: 7)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
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

    // MARK: - Karate combat resolution

    /// Base contact damage per strike button before combo/critical scaling.
    private func karateStrikeDamage(for button: ArenaPadFaceButton) -> Int {
        switch button {
        case .square: return 7    // jab — fast, light
        case .circle: return 10   // hook
        case .cross: return 13    // uppercut
        case .triangle: return 15 // roundhouse — heavy, slow
        }
    }

    /// Resolve a player strike. Always plays feedback/combo; applies damage to
    /// the opponent HP only when the strike CONNECTS — the opponent is within
    /// reach (range gate) and is not guarding. A whiffed or guarded strike
    /// keeps the combo alive visually but deals no HP damage. On a killing hit
    /// it routes to KO / wave-clear via handleOpponentDefeated.
    private func resolveKarateStrike(button: ArenaPadFaceButton, isCritical: Bool, basePoints: Int) {
        let now = CACurrentMediaTime()
        let count = karateCombo.register(at: now)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            combo = count
            maxCombo = max(maxCombo, combo)
        }
        scheduleComboExpiry()

        // Impact hitstop + contact burst + hit flash + shake.
        karateHitstopCritical = isCritical
        karateHitstopNonce += 1
        triggerKarateHitFlash()
        triggerScreenShake(intensity: isCritical ? 1.6 : 1.15)
        if isCritical {
            criticalHits += 1
            triggerCriticalFlash()
        }
        hapticSuccess(isCritical: isCritical)
        FELSoundscapeEngine.shared.triggerCheer(intensity: isCritical ? 1.0 : 0.65)
        FELSoundscapeEngine.shared.combo = combo

        // Chakra / special meter gains (secondary meter).
        withAnimation(.spring(response: 0.15)) {
            chakraBar = min(100, chakraBar + 22)
        }
        withAnimation(.spring(response: 0.2)) {
            specialMeter = min(100, specialMeter + arcadePhysics.specialMeterGainRate * (isCritical ? 1.5 : 1.0))
        }

        // Connection check: out of range → whiff (no damage, no score).
        guard karateInStrikeRange, var ai = opponentAI, !ai.isDefeated else {
            withAnimation { lastAction = "WHIFF!" }
            return
        }
        // Opponent guarding → chip nothing, show GUARDED.
        if ai.isBlocking {
            withAnimation { lastAction = "GUARDED!" }
            return
        }

        // Landed hit — score + damage.
        let scored = Int((Double(basePoints + (isCritical ? 3 : 1)) * karateCombo.multiplier).rounded())
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            score += max(1, scored)
            lastAction = karateSuccessFeedback(action: "STRIKE", isCritical: isCritical, points: max(1, scored))
        }

        let dmgBase = karateStrikeDamage(for: button) + (isCritical ? 8 : 0)
        let dmg = Int((Double(dmgBase) * karateCombo.multiplier).rounded())
        ai.takeDamage(dmg, now: now)
        opponentAI = ai
        opponentHP = ai.hp
        // Opponent visual stagger.
        karateOpponentEvent = .stagger
        karateOpponentEventNonce += 1
        FELGameplayEventBus.postScored()

        // Named-combo flourish (only on landed hits).
        if let named = KarateNamedCombo.detect(in: recentStrikeButtons) {
            score += named.bonusPoints
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                comboChainText = "\(named.displayName) +\(named.bonusPoints)"
                showComboChain = true
            }
            recentStrikeButtons.removeAll()
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                withAnimation { showComboChain = false }
            }
        }

        if gameMode.id == .karateEndless {
            waveEngine?.registerPlayerHit(basePoints: basePoints, comboMultiplier: karateCombo.multiplier)
            if let w = waveEngine { score = w.score }
        }

        if ai.isDefeated {
            handleOpponentDefeated()
        }
    }

    private func scheduleComboExpiry() {
        comboExpiryTask?.cancel()
        comboExpiryTask = Task {
            try? await Task.sleep(for: .seconds(KarateComboTracker.comboResetWindow + 0.05))
            guard !Task.isCancelled else { return }
            if karateCombo.tickExpiry(now: CACurrentMediaTime()) {
                withAnimation(.easeOut(duration: 0.3)) { combo = 0 }
            }
        }
    }

    private func handleOpponentDefeated() {
        if gameMode.id == .karateEndless {
            let cleared = waveEngine?.registerOpponentDefeated() ?? false
            if let w = waveEngine {
                score = w.score
                opponentHP = 0
            }
            if cleared {
                // Intermission beat: the wave tick advances the wave and the
                // next opponent spawns when combat resumes (see wave tick).
                opponentAITask?.cancel(); opponentAITask = nil
                opponentAI = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { showWaveClear = true }
                Task {
                    try? await Task.sleep(for: .seconds(2.2))
                    withAnimation { showWaveClear = false }
                }
            } else {
                // Next opponent in the same wave.
                Task {
                    try? await Task.sleep(for: .milliseconds(550))
                    if isActive, !(waveEngine?.isOver ?? true) { spawnKarateOpponent() }
                }
            }
        } else {
            // 1v1 victory.
            karateVictory = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                showWaveClear = true
                lastAction = "K.O.!"
            }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                endGame()
            }
        }
    }

    // MARK: - Karate opponent AI + waves lifecycle

    /// Build a fresh opponent for the current mode/wave and start (or restart)
    /// the deterministic AI tick loop.
    private func spawnKarateOpponent() {
        let seedBase = GameplaySeed.uint64(from: matchSessionId)
        let difficulty: KarateOpponentAI.Difficulty
        let waveSalt: UInt64
        if gameMode.id == .karateEndless, let w = waveEngine {
            difficulty = w.currentDifficulty
            waveSalt = UInt64(w.wave) &* 0x9E37 &+ UInt64(w.opponentsClearedThisWave)
        } else {
            difficulty = .normal
            waveSalt = 0x1F2E
        }
        let ai = KarateOpponentAI(difficulty: difficulty, seed: seedBase &+ waveSalt &+ 0xA1)
        opponentAI = ai
        opponentMaxHP = ai.maxHP
        opponentHP = ai.hp
        startKarateOpponentTick()
    }

    private func startKarateOpponentTick() {
        opponentAITask?.cancel()
        opponentAITask = Task { @MainActor in
            var lastIntent: KarateOpponentAI.Intent = .idle
            while !Task.isCancelled, isActive {
                if var ai = opponentAI, !ai.isDefeated {
                    let now = CACurrentMediaTime()
                    let intent = ai.tick(now: now)
                    opponentAI = ai
                    if intent != lastIntent {
                        applyOpponentIntent(intent)
                        lastIntent = intent
                    }
                }
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    /// Translate an AI intent into scene events + player-side consequences.
    private func applyOpponentIntent(_ intent: KarateOpponentAI.Intent) {
        switch intent {
        case .idle:
            break
        case .telegraph(let attack, _):
            pendingOpponentAttack = attack
            karateOpponentEvent = .telegraph(duration: 0.4)
            karateOpponentEventNonce += 1
        case .strike(let attack):
            karateOpponentEvent = .strike(attack.asset)
            karateOpponentEventNonce += 1
            resolveOpponentAttack(attack)
            pendingOpponentAttack = nil
        case .block:
            karateOpponentEvent = .guard(duration: 0.5)
            karateOpponentEventNonce += 1
        case .stagger:
            break   // stagger visual already fired from resolveKarateHit
        }
    }

    /// The opponent's strike resolves: if the player is guarding (block held in
    /// the perfect-guard window) it's blocked/countered via the existing combat
    /// resolver; otherwise the player takes damage.
    private func resolveOpponentAttack(_ attack: KarateOpponentAI.Attack) {
        guard isActive, isKarate else { return }
        let guarding = blockTimestamp > 0
        if guarding {
            resolveCombatOnHit()   // perfect-guard / vanish-counter / block path
            return
        }
        // Unblocked hit on the player.
        triggerScreenShake(intensity: 0.5)
        combo = 0
        karateCombo.reset()
        hapticFail()
        withAnimation(.spring(response: 0.25)) { lastAction = "HIT! -\(attack.damage)" }
        if gameMode.id == .karateEndless {
            waveEngine?.registerPlayerDamage(attack.damage)
            if let w = waveEngine, w.isOver {
                handlePlayerDefeated()
            }
        } else {
            // 1v1: deplete the player HP bar; KO ends the match as a loss.
            withAnimation(.spring(response: 0.35)) {
                karatePlayerHP = max(0, karatePlayerHP - attack.damage)
            }
            if karatePlayerHP <= 0 {
                handlePlayerDefeated()
            }
        }
    }

    /// Player KO'd (1v1 loss or endless defeat): stop the fight and route to the
    /// results overlay with the defeat outcome.
    private func handlePlayerDefeated() {
        guard isActive else { return }
        karateDefeat = true
        karateVictory = false
        opponentAITask?.cancel(); opponentAITask = nil
        waveTickTask?.cancel(); waveTickTask = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            lastAction = "K.O."
        }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            endGame()
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

    /// Maps a dunk trick to one of the two retargeted power-dunk clips so the
    /// dunk contest varies its full-body animation. Two-handed power jams use the
    /// ElijahDunkPower capture; the rest keep the original ElijahDunk. Both wire
    /// through the same setDunkClipActive path (never cloned skinned nodes).
    private func dunkClipAsset(for trick: DunkTrickSlot) -> FELBundledAsset {
        switch trick {
        case .tomahawk, .reverseJam, .doubleClutch:
            return .elijahDunkPower
        default:
            return .elijahDunk
        }
    }

    private func confirmDunkLaunch() {
        guard dunkEngine.phase == .launch else { return }
        dunkTimerTask?.cancel()
        // Pick which baked power-dunk clip this launch plays, for visual variety.
        // Two-handed power tricks use the ElijahDunkPower capture; the rest use
        // the original ElijahDunk. Set BEFORE the phase flips to launch/airborne
        // (which drives isMidAir → setDunkClipActive in the scene host).
        basketballDunkClipAsset = dunkClipAsset(for: dunkEngine.selectedTrick)
        let inGreen = dunkEngine.launchGreenZone.contains(dunkEngine.launchTiming)
        if inGreen {
            triggerFlash()
        }
        withAnimation(.spring(response: 0.2)) {
            dunkEngine.confirmLaunch()
            lastAction = inGreen ? "PERFECT LAUNCH!" : "LAUNCHED"
        }
        triggerScreenShake(intensity: inGreen ? 0.4 : 0.2)
        FELGameplayEventBus.postScored()

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

        judgeRollUpReveal = false
        withAnimation(.spring(response: 0.3)) {
            lastJudgeScores = (result.j1, result.j2, result.j3)
            crowdMessage = result.message
            score += result.total
            dunkEngine.roundScores.append((round: dunkEngine.round, score: result.total, message: result.message))
        }
        // Kick off the staggered count-up reveal on the next runloop tick so
        // the component sees reveal flip false -> true.
        DispatchQueue.main.async { judgeRollUpReveal = true }

        let impactLevel = dunkEngine.impactIntensity
        triggerScreenShake(intensity: 0.5 + impactLevel * 0.5)
        triggerImpactFlash()
        FELGameplayEventBus.postScored()
        FELSoundscapeEngine.shared.triggerCheer(intensity: result.total >= 138 ? 1.0 : 0.75)
        if result.total >= 45 {
            triggerCriticalFlash()
            triggerSlowMo(duration: 1.5)
        } else if result.total >= 38 {
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
        let aiTrickRoll = rng.nextDouble(in: 0.5...0.8)

        let input = DunkEngine3DScoringInput(
            jumpHeight: aiHeight,
            launchQuality: aiExecution,
            landingQuality: aiExecution * 0.95,
            completedRotation: aiTrickRoll,
            trick: aiTrickRoll > 0.75 ? .windmill : .rimGrazer,
            modifierScoreMultiplier: 0.85 + aiNormalized * 0.15
        )
        let wda = WDAScoringEngine.shared.scoreEngine3DDunk(input: input)
        let panel = wda.judgePanelScores
        let total = Int(wda.totalScore.rounded(.toNearestOrAwayFromZero))

        withAnimation(.spring(response: 0.3)) {
            opponentScore += total
            lastJudgeScores = (panel.j1, panel.j2, panel.j3)
            crowdMessage = "AI: \(wda.wdaCrowdMessage)"
            lastAction = "OPPONENT: +\(total)"
        }
        judgeRollUpReveal = false
        DispatchQueue.main.async { judgeRollUpReveal = true }
        triggerScreenShake(intensity: 0.3)
        FELGameplayEventBus.postOpponentScored()
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
        case .basketballHeadToHead, .venicePickup:
            return action == "Shoot" ? 3 : 2
        case .basketballDunkContest3D, .basketballDunkContestIRL:
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
            if action.contains("Correct") {
                return 150
            }
            return 0
        case .courtCarnival:
            if action.contains("Boost") {
                return action.contains("Success") ? 300 : 120
            } else if action.contains("Pit") {
                return 250
            } else if action.contains("Sponsor") {
                return 150
            } else if action.contains("Duel") {
                return action.contains("Win") ? 300 : (action.contains("Tie") ? 100 : 0)
            }
            return 50
        case .marketBrowse:
            return 10
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
        opponentAITask?.cancel()
        opponentAITask = nil
        waveTickTask?.cancel()
        waveTickTask = nil
        comboExpiryTask?.cancel()
        comboExpiryTask = nil
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

    // MARK: - Arcade Swing Input Handlers

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

        // Drive the per-sport action animation for registry-covered modes
        // (golf/tennis/baseball/soccer/volleyball/football). The gesture handlers
        // route through here, so this is the single place that fires the swing/
        // serve/spike/kick clip — GameSceneHostView.playSportAction prefers a
        // bundled Action_<mode>_<action>.usdz and fails soft to the procedural
        // arm-swing. Previously only performAction() bumped this, so through
        // normal gesture play the action animation never triggered.
        if SportActionAnimationLibrary.modeToken(for: gameMode.id) != nil {
            sportActionLabel = action
            sportActionNonce += 1
        }

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
            hapticSuccess(isCritical: isCritical)
            FELGameplayEventBus.postScored()
            FELSoundscapeEngine.shared.triggerCheer(intensity: isCritical ? 1.0 : 0.65)
            FELSoundscapeEngine.shared.combo = combo
        } else {
            withAnimation(.spring(response: 0.3)) {
                combo = 0
                lastAction = modeFeedbackFail()
                lastActionIsCritical = false
                lastActionIsBurst = false
            }
            hapticFail()
            if gameMode.id == .soccer || gameMode.id == .volleyball {
                FELGameplayEventBus.postPenalty()
                FELSoundscapeEngine.shared.triggerGasp(intensity: 0.7)
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
                    FELGameplayEventBus.postOpponentScored()
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
        case .tennis: strings = ["ACE!", "WINNER!", "RALLY!", "VOLLEY!"]
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
        case .tennis: strings = ["Out", "Net", "Fault"]
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

#if DEBUG
        Task {
            await GameplaySessionReceiptCoordinator.shared.submitNativeSessionReceipt(
                matchSessionId: matchSessionId,
                gameModeId: gameMode.id.rawValue,
                playerScore: score,
                opponentScore: opponentScore,
                durationSeconds: elapsedSeconds,
                comboCount: maxCombo,
                criticalCount: criticalHits,
                pacingScore: min(100, max(0, Int(sessionReadiness.rounded())))
            )
        }
#endif

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
                    HStack(spacing: FELDesign.Space.xxs) {
                        Image(systemName: specialMeterFull ? "flame.fill" : "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(specialMeterFull ? FELDesign.Colors.purple : FELDesign.Colors.cyan)
                        FELMicroLabel(
                            text: specialMeterFull ? "Special Ready" : "Special",
                            color: specialMeterFull ? FELDesign.Colors.purple : FELDesign.Colors.textSecondary
                        )
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.6))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(specialMeterFull ? FELDesign.Colors.purple : FELDesign.Colors.cyan)
                                .frame(width: geo.size.width * min(1, specialMeter / 100))
                                .animation(.spring(response: 0.25), value: specialMeter)
                        }
                    }
                    .frame(width: 100, height: 8)
                    .clipShape(.rect(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(specialMeterFull ? FELDesign.Colors.glow(FELDesign.Colors.purple, 0.5) : FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                    )
                }
                .padding(FELDesign.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                        .fill(.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                .stroke(specialMeterFull ? FELDesign.Colors.glow(FELDesign.Colors.purple, 0.3) : .clear, lineWidth: FELDesign.Stroke.hairline)
                        )
                )
                Spacer()
            }
            .padding(.leading, FELDesign.Space.md)
            .padding(.top, FELDesign.Space.xs)
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
                        VStack(spacing: FELDesign.Space.xxs) {
                            FELMicroLabel(text: "Trick Mode", color: FELDesign.Colors.purple)
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
                                        .font(FELDesign.Typography.micro)
                                        .tracking(FELDesign.Typography.microTracking)
                                        .foregroundStyle(FELDesign.Colors.ink)
                                        .padding(.horizontal, FELDesign.Space.sm)
                                        .padding(.vertical, FELDesign.Space.xxs)
                                        .background(FELDesign.Colors.purple)
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
                            HStack(spacing: FELDesign.Space.xxs) {
                                Image(systemName: "l1.button.roundedbottom.horizontal")
                                    .font(.system(size: 12, weight: .bold))
                                Text("STYLE")
                                    .font(FELDesign.Typography.micro)
                                    .tracking(FELDesign.Typography.microTracking)
                            }
                            .foregroundStyle(activeModifierState == .style ? FELDesign.Colors.ink : FELDesign.Colors.purple)
                            .padding(.horizontal, FELDesign.Space.sm)
                            .padding(.vertical, FELDesign.Space.xs)
                            .background(
                                activeModifierState == .style
                                    ? AnyShapeStyle(FELDesign.Colors.purple)
                                    : AnyShapeStyle(FELDesign.Colors.surfaceRaised.opacity(0.8))
                            )
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(activeModifierState == .style ? FELDesign.Colors.purple : FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline))
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
                            HStack(spacing: FELDesign.Space.xxs) {
                                Image(systemName: "r1.button.roundedbottom.horizontal")
                                    .font(.system(size: 12, weight: .bold))
                                Text("POWER")
                                    .font(FELDesign.Typography.micro)
                                    .tracking(FELDesign.Typography.microTracking)
                            }
                            .foregroundStyle(activeModifierState == .power ? FELDesign.Colors.ink : FELDesign.Colors.cyan)
                            .padding(.horizontal, FELDesign.Space.sm)
                            .padding(.vertical, FELDesign.Space.xs)
                            .background(
                                activeModifierState == .power
                                    ? AnyShapeStyle(FELDesign.Colors.cyan)
                                    : AnyShapeStyle(FELDesign.Colors.surfaceRaised.opacity(0.8))
                            )
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(activeModifierState == .power ? FELDesign.Colors.cyan : FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline))
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
                    .font(.system(size: 8, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(FELDesign.Colors.textPrimary)
            .frame(width: 50, height: 44)
            .background(FELDesign.Colors.surfaceRaised.opacity(0.8))
            .clipShape(.rect(cornerRadius: FELDesign.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                    .stroke(FELDesign.Colors.glow(FELDesign.Colors.purple, 0.3), lineWidth: FELDesign.Stroke.hairline)
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

        // Animate the avatar on a landed trick (board/precision extreme modes).
        // The trick system previously fired only screen FX, so the on-court
        // avatar never visibly performed the trick — the "idle-only" complaint.
        // Routes through the same sport-action seam: a bundled Action_ clip if it
        // ships, else the procedural full-body pulse (registered in modeToken).
        if SportActionAnimationLibrary.modeToken(for: gameMode.id) != nil {
            sportActionLabel = trick.name
            sportActionNonce += 1
        }

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

    private func handleArenaPadFaceButton(_ button: ArenaPadFaceButton) {
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

        if isKarate {
            // Karate is a real fight loop — the face buttons ONLY fire strikes,
            // never the basketball performAction("Dunk"/"Shoot"/…) fall-through
            // below. Damage is applied on connect (range + opponent not
            // guarding) inside performKarateStrike.
            performKarateStrike(button)
            return
        }

        // Non-basketball pad modes: route face buttons to the mode's REAL action
        // handler instead of bleeding into the basketball performAction("Shoot"/
        // "Dunk"/…) fall-through below. These modes show FELGamepadView
        // (usesGamepadOverlay) but are ball/board sports — a face press must fire
        // the sport action, not a basketball verb.
        if routeFaceButtonToModeAction(button) { return }

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

    /// Maps a pad face button to the current mode's real action for the modes
    /// that show the shared gamepad but are NOT basketball/karate/dunk. Returns
    /// true when it handled the press (caller must then `return`), false to let
    /// the basketball fall-through run (basketball family modes). Keeps every
    /// pad mode's face buttons firing the correct sport action — no bleed-through.
    private func routeFaceButtonToModeAction(_ button: ArenaPadFaceButton) -> Bool {
        switch gameMode.id {
        case .tennis:
            let type: String
            switch button {
            case .triangle: type = "Serve"
            case .square:   type = "Forehand"
            case .circle:   type = "Volley"
            case .cross:    type = "Baseline"
            }
            handleRallyHit(type: type)
            return true
        case .volleyball:
            // Aim already tracked via stick/drag; any face button spikes.
            handleVolleyballSpike()
            return true
        case .soccer:
            let power: KickPower
            switch button {
            case .triangle: power = .high
            case .cross:    power = .low
            default:        power = .mid
            }
            handlePenaltyKick(power: power)
            return true
        case .football:
            // Phase-aware: catch the kick, then tap-in-zone to break away.
            if footballPhase == .catch {
                handleCatchTap()
            } else {
                handleRunTap()
            }
            return true
        case .skateboarding, .snowboarding, .surfing, .gymnastics:
            // Board/precision rhythm modes: a face button performs the mode's
            // primary/secondary/tertiary action (same set the on-screen rhythm
            // buttons use), routing through performAction so the round advances
            // and the sport-action clip fires. Cross = special/first action.
            let actions = actionsForMode
            let idx: Int
            switch button {
            case .square:   idx = 0
            case .circle:   idx = 1
            case .triangle: idx = 2
            case .cross:    idx = 0
            }
            if actions.indices.contains(idx) { performAction(actions[idx]) }
            return true
        case .courtCarnival:
            // Party board: a face button rolls the quantum dice when idle. It
            // does NOT fire performAction directly — the board flow is
            // roll → land on tile → event card resolves via its own button →
            // performAction (round advance). Calling performAction here would
            // double-advance the 5-round loop and end the match early (the bug
            // the audit flagged from the basketball fall-through). When an event
            // is active the dice is guarded, so the press is a safe no-op and
            // the player resolves the event on its dedicated card.
            rollQuantumDice()
            return true
        default:
            // Basketball family (h2h/3v3/dunk) — let the caller's basketball
            // fall-through handle Shoot/Dunk/Sprint/Style.
            return false
        }
    }

    /// Maps a face button to a karate strike: plays the clip, records the input
    /// for named-combo detection, then resolves the hit (damage on connect).
    /// This replaces the basketball performAction fall-through for karate so a
    /// strike is deterministic (it lands if in range and the opponent isn't
    /// guarding) rather than a random shot-success roll.
    private func performKarateStrike(_ button: ArenaPadFaceButton) {
        guard isActive, isKarate else { return }
        let strike: FELBundledAsset
        switch button {
        case .square: strike = .elijahStrikeJab
        case .circle: strike = .elijahStrikeHook
        case .triangle: strike = .elijahStrikeRoundhouse
        case .cross: strike = .elijahStrikeUppercut
        }
        // Fire the visual clip; the scene host reports connect range back via
        // onKarateStrike (updates karateInStrikeRange before we resolve).
        karateStrikeAsset = strike
        karateStrikeNonce += 1
        // Record the input for named-combo detection (tail of last 6).
        recentStrikeButtons.append(button)
        if recentStrikeButtons.count > 6 { recentStrikeButtons.removeFirst() }

        playerActionCount += 1
        let physics = leakageAdjustedPhysics
        let isCritical = Double.random(in: 0...1) < physics.criticalHitChance
        let basePoints = pointsForAction("Strike", success: true)
        resolveKarateStrike(button: button, isCritical: isCritical, basePoints: basePoints)
    }

    private func handlePS2DPad(_ direction: ArenaPadDPadDirection) {
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
        // Karate: the left shoulder is GUARD. Arms the perfect-guard window so an
        // incoming opponent strike is blocked/countered (see resolveOpponentAttack
        // → resolveCombatOnHit). The window auto-expires in CombatInputResolver.
        if isKarate {
            handleBlock()
            withAnimation(.spring(response: 0.15)) { lastAction = "GUARD" }
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

    /// Routes shared-gamepad events into the existing mode handlers.
    /// L2/R2 mirror L1/R1 (style/power modifiers) until modes gain
    /// trigger-specific actions.
    private func configureFELPadBridge() {
        felPad.onEvent = { event in
            switch event {
            case .buttonDown(let button):
                if let face = button.legacyFaceButton {
                    handleArenaPadFaceButton(face)
                } else if button == .l1 || button == .l2 {
                    handlePS2LeftShoulder()
                } else if button == .r1 || button == .r2 {
                    handlePS2RightShoulder()
                }
            case .dpadDown(let direction):
                handlePS2DPad(direction.legacyDirection)
            case .buttonUp, .dpadUp:
                break
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
        FELGameplayEventBus.postKarateBlock()
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
                HStack(spacing: FELDesign.Space.xs) {
                    Text("\(percent)%")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(contestTierColor(tier))
                    VStack(alignment: .leading, spacing: 1) {
                        FELMicroLabel(text: label, color: FELDesign.Colors.textPrimary)
                        FELMicroLabel(text: "Shot Contest")
                    }
                }
                .padding(.horizontal, FELDesign.Space.md)
                .padding(.vertical, FELDesign.Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                                .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                        )
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
        case .smothered: return FELDesign.Colors.danger
        case .heavy: return FELDesign.Colors.danger.opacity(0.75)
        case .contested: return FELDesign.Colors.textSecondary
        case .light: return FELDesign.Colors.success.opacity(0.75)
        case .open: return FELDesign.Colors.success
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
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(0.8)
                        }
                        .foregroundStyle(defensiveState.handsUp ? FELDesign.Colors.ink : FELDesign.Colors.textPrimary)
                        .frame(width: 56, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                                .fill(defensiveState.handsUp ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                                        .stroke(defensiveState.handsUp ? FELDesign.Colors.cyan : FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
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
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(0.8)
                        }
                        .foregroundStyle(defensiveState.isQuickProtectActive ? FELDesign.Colors.ink : FELDesign.Colors.textPrimary)
                        .frame(width: 56, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                                .fill(defensiveState.isQuickProtectActive ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                                        .stroke(defensiveState.isQuickProtectActive ? FELDesign.Colors.cyan : FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
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
                                .font(FELDesign.Typography.statSmall)
                                .foregroundStyle(FELDesign.Colors.textSecondary)
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

// MARK: - Film Quiz and Court Carnival Supporting Models & Views

enum SkeletonAnimationType: String, CaseIterable, Sendable {
    case sprint = "sprint"
    case highJump = "high jump"
    case pitching = "pitching"
    case golfSwing = "golf swing"
    case squat = "squat"
    case pushUp = "push up"
}

struct FilmQuestion: Identifiable, Sendable {
    let id = UUID()
    let question: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
    let animationType: SkeletonAnimationType
    
    static let filmQuestions: [FilmQuestion] = [
        FilmQuestion(
            question: "Identify the primary source of biomechanical power loss during the transition phase of this sprint start.",
            choices: [
                "Premature hip extension limiting horizontal force vectors",
                "Excessive knee flexion on the support leg (amortization)",
                "Lack of trunk lean resulting in vertical deceleration",
                "Improper wrist extension diminishing rear-arm drive"
            ],
            correctIndex: 0,
            explanation: "Extending the hips too early forces the body upright, changing horizontal force vectors to vertical, which significantly reduces early acceleration efficiency.",
            animationType: .sprint
        ),
        FilmQuestion(
            question: "In this High Jump Fosbury Flop, what biomechanical principle maximizes the height cleared over the crossbar?",
            choices: [
                "Positioning the center of mass below the physical crossbar",
                "Increasing the vertical velocity at take-off via arm flexion",
                "Achieving maximum trunk extension to stiffen the spine",
                "Using the trailing leg as a counterweight to lower the hips"
            ],
            correctIndex: 0,
            explanation: "By arching the back over the bar, the athlete positions their center of mass below the bar, requiring less work and vertical lift to clear it.",
            animationType: .highJump
        ),
        FilmQuestion(
            question: "Observe this baseball pitch sequence. What is the main driver of force transmission from the lower to upper extremities?",
            choices: [
                "Proximal-to-distal sequential acceleration of body segments",
                "Maximum concentric contraction of the forearm flexors",
                "Isometric bracing of the lead knee joint on release",
                "Passive stretch-shortening cycle of the pectoral muscles"
            ],
            correctIndex: 0,
            explanation: "The kinetic chain works sequentially from the ground up: hips rotate, torso follows, shoulder rotates, and finally the arm whips forward.",
            animationType: .pitching
        ),
        FilmQuestion(
            question: "During this golf swing, which angle is critical to maintain for optimal energy transfer ('lag') during the downswing transition?",
            choices: [
                "The angle between the lead forearm and the club shaft",
                "The angle of the rear elbow joint relative to the thorax",
                "The lateral tilt of the spine relative to the vertical axis",
                "The flexion angle of the lead knee at ball impact"
            ],
            correctIndex: 0,
            explanation: "Maintaining the wrist angle (lag) between the lead forearm and the club shaft stores elastic energy, releasing it at the last microsecond for maximum speed.",
            animationType: .golfSwing
        ),
        FilmQuestion(
            question: "Analyze the squat biomechanics shown. Which joint alignment error indicates poor knee tracking and potential ACL strain?",
            choices: [
                "Medial knee collapse (valgus deviation) relative to the foot",
                "Anterior translation of the patella beyond the toe line",
                "Excessive flexion of the lumbar spine (butt wink)",
                "External rotation of the hips during the ascent phase"
            ],
            correctIndex: 0,
            explanation: "Dynamic valgus (knees caving inward) increases lateral shear forces on the ACL and indicates weak hip abductors and external rotators.",
            animationType: .squat
        ),
        FilmQuestion(
            question: "In this push-up execution, which structural adjustment optimizes mechanical advantage and minimizes anterior shoulder stress?",
            choices: [
                "Positioning hands slightly wider than shoulders, elbows at 45°",
                "Flaring elbows to 90° to target the clavicular head of pectorals",
                "Allowing the hips to sag to reduce lumbar flexion work",
                "Placing hands near the pelvic girdle to shift load downwards"
            ],
            correctIndex: 0,
            explanation: "Keeping hands slightly wider than shoulders and elbows tucked to 45° optimizes chest recruitment while shielding the rotator cuff and anterior capsule.",
            animationType: .pushUp
        )
    ]
}

struct BiomechanicalSkeletonView: View {
    let animationType: SkeletonAnimationType
    let time: Double
    
    private let bones: [(from: Joint, to: Joint)] = [
        (.head, .neck),
        (.neck, .spine),
        (.spine, .pelvis),
        (.neck, .leftShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.neck, .rightShoulder),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.pelvis, .leftHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.pelvis, .rightHip),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]
    
    enum Joint: String, CaseIterable {
        case head, neck, spine, pelvis
        case leftShoulder, leftElbow, leftWrist
        case rightShoulder, rightElbow, rightWrist
        case leftHip, leftKnee, leftAnkle
        case rightHip, rightKnee, rightAnkle
    }
    
    var body: some View {
        GeometryReader { geo in
            let joints = computeJoints(in: geo.size)
            
            ZStack {
                // Background grid lines to look like a high-tech lab UI
                Path { path in
                    let cols = 8
                    let rows = 5
                    for i in 1..<cols {
                        let x = CGFloat(i) * geo.size.width / CGFloat(cols)
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for i in 1..<rows {
                        let y = CGFloat(i) * geo.size.height / CGFloat(rows)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                
                // Draw bones with gradients / glow
                ForEach(0..<bones.count, id: \.self) { idx in
                    let bone = bones[idx]
                    if let start = joints[bone.from], let end = joints[bone.to] {
                        Path { path in
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Theme.brandCyan, Theme.brandBlue.opacity(0.8)],
                                startPoint: .init(x: start.x / geo.size.width, y: start.y / geo.size.height),
                                endPoint: .init(x: end.x / geo.size.width, y: end.y / geo.size.height)
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .shadow(color: Theme.brandCyan.opacity(0.4), radius: 3)
                    }
                }
                
                // Draw joints as glowing neon dots
                ForEach(Joint.allCases, id: \.self) { joint in
                    if let pt = joints[joint] {
                        Circle()
                            .fill(joint == .head ? Theme.neonGreen : Theme.brandCyan)
                            .frame(width: joint == .head ? 10 : 7, height: joint == .head ? 10 : 7)
                            .position(pt)
                            .shadow(color: (joint == .head ? Theme.neonGreen : Theme.brandCyan).opacity(0.8), radius: 6)
                    }
                }
            }
        }
    }
    
    private func computeJoints(in size: CGSize) -> [Joint: CGPoint] {
        var joints: [Joint: CGPoint] = [:]
        
        let cx = size.width / 2.0
        let cy = size.height / 2.0
        let t = time
        
        switch animationType {
        case .sprint:
            let bounce = sin(t * 4 * .pi) * 6
            let hipX = cx - 20
            let hipY = cy + 10 + bounce
            
            joints[.pelvis] = CGPoint(x: hipX, y: hipY)
            joints[.spine] = CGPoint(x: hipX + 5, y: hipY - 25)
            joints[.neck] = CGPoint(x: hipX + 8, y: hipY - 45)
            joints[.head] = CGPoint(x: hipX + 12, y: hipY - 58)
            
            let phaseL = t * 2 * .pi
            let phaseR = phaseL + .pi
            
            let lHipAngle = sin(phaseL) * 0.5
            let lKneeAngle = (sin(phaseL - 1.0) + 1.0) * 0.6
            
            let lHipX = hipX - 5
            let lHipY = hipY + 5
            joints[.leftHip] = CGPoint(x: lHipX, y: lHipY)
            
            let lKneeX = lHipX + sin(lHipAngle + 0.2) * 30
            let lKneeY = lHipY + cos(lHipAngle + 0.2) * 30
            joints[.leftKnee] = CGPoint(x: lKneeX, y: lKneeY)
            
            joints[.leftAnkle] = CGPoint(x: lKneeX + sin(lHipAngle - lKneeAngle + 0.4) * 28,
                                         y: lKneeY + cos(lHipAngle - lKneeAngle + 0.4) * 28)
            
            let rHipAngle = sin(phaseR) * 0.5
            let rKneeAngle = (sin(phaseR - 1.0) + 1.0) * 0.6
            
            let rHipX = hipX + 5
            let rHipY = hipY + 5
            joints[.rightHip] = CGPoint(x: rHipX, y: rHipY)
            
            let rKneeX = rHipX + sin(rHipAngle + 0.2) * 30
            let rKneeY = rHipY + cos(rHipAngle + 0.2) * 30
            joints[.rightKnee] = CGPoint(x: rKneeX, y: rKneeY)
            
            joints[.rightAnkle] = CGPoint(x: rKneeX + sin(rHipAngle - rKneeAngle + 0.4) * 28,
                                          y: rKneeY + cos(rHipAngle - rKneeAngle + 0.4) * 28)
            
            let shL = hipX + 3
            let shY = hipY - 40
            joints[.leftShoulder] = CGPoint(x: shL, y: shY)
            joints[.rightShoulder] = CGPoint(x: shL + 8, y: shY)
            
            let lArmAngle = sin(phaseR) * 0.6
            let lElbAngle = (sin(phaseR - 0.5) + 1.0) * 0.5
            let lElbX = shL + sin(lArmAngle) * 22
            let lElbY = shY + cos(lArmAngle) * 22
            joints[.leftElbow] = CGPoint(x: lElbX, y: lElbY)
            joints[.leftWrist] = CGPoint(x: lElbX + sin(lArmAngle + lElbAngle) * 18,
                                         y: lElbY + cos(lArmAngle + lElbAngle) * 18)
            
            let rArmAngle = sin(phaseL) * 0.6
            let rElbAngle = (sin(phaseL - 0.5) + 1.0) * 0.5
            let rElbX = (shL + 8) + sin(rArmAngle) * 22
            let rElbY = shY + cos(rArmAngle) * 22
            joints[.rightElbow] = CGPoint(x: rElbX, y: rElbY)
            joints[.rightWrist] = CGPoint(x: rElbX + sin(rArmAngle + rElbAngle) * 18,
                                          y: rElbY + cos(rArmAngle + rElbAngle) * 18)
            
        case .highJump:
            let barX = cx
            let barY = cy - 20
            
            var x: CGFloat = 0.0
            var y: CGFloat = 0.0
            var angle: CGFloat = 0.0
            
            if t < 0.3 {
                let progress = t / 0.3
                x = cx - 80 + progress * 40
                y = cy + 30 - sin(progress * .pi * 2) * 5
                angle = -0.2
            } else if t < 0.5 {
                let progress = (t - 0.3) / 0.2
                x = cx - 40 + progress * 30
                y = cy + 30 - progress * 45
                angle = -0.2 + progress * 1.5
            } else if t < 0.8 {
                let progress = (t - 0.5) / 0.3
                x = cx - 10 + progress * 30
                y = barY - 15 + pow(progress - 0.5, 2) * 40
                angle = 1.3 + progress * 1.2
            } else {
                let progress = (t - 0.8) / 0.2
                x = cx + 20 + progress * 20
                y = cy + 25 + pow(progress - 0.5, 2) * 10
                angle = 2.5
            }
            
            let hipX = x
            let hipY = y
            joints[.pelvis] = CGPoint(x: hipX, y: hipY)
            
            let isArched = (t >= 0.5 && t < 0.8)
            let spineAngle = angle + (isArched ? 0.4 : 0.0)
            
            let spineX = hipX - cos(angle) * 20
            let spineY = hipY - sin(angle) * 20
            joints[.spine] = CGPoint(x: spineX, y: spineY)
            
            let neckX = spineX - cos(spineAngle) * 15
            let neckY = spineY - sin(spineAngle) * 15
            joints[.neck] = CGPoint(x: neckX, y: neckY)
            
            joints[.head] = CGPoint(x: neckX - cos(spineAngle + 0.2) * 12,
                                     y: neckY - sin(spineAngle + 0.2) * 12)
            
            joints[.leftShoulder] = CGPoint(x: neckX - 4, y: neckY - 2)
            joints[.rightShoulder] = CGPoint(x: neckX + 4, y: neckY + 2)
            
            joints[.leftElbow] = CGPoint(x: neckX - cos(angle + 0.8) * 18, y: neckY - sin(angle + 0.8) * 18)
            joints[.leftWrist] = CGPoint(x: joints[.leftElbow]!.x - cos(angle + 1.2) * 15, y: joints[.leftElbow]!.y - sin(angle + 1.2) * 15)
            joints[.rightElbow] = CGPoint(x: neckX - cos(angle + 1.0) * 18, y: neckY - sin(angle + 1.0) * 18)
            joints[.rightWrist] = CGPoint(x: joints[.rightElbow]!.x - cos(angle + 1.4) * 15, y: joints[.rightElbow]!.y - sin(angle + 1.4) * 15)
            
            let lHipX = hipX - 3
            let lHipY = hipY + 3
            joints[.leftHip] = CGPoint(x: lHipX, y: lHipY)
            joints[.rightHip] = CGPoint(x: hipX + 3, y: hipY - 3)
            
            let kneeAngle = angle - (isArched ? 0.8 : 0.2)
            joints[.leftKnee] = CGPoint(x: lHipX + cos(kneeAngle) * 25, y: lHipY + sin(kneeAngle) * 25)
            joints[.leftAnkle] = CGPoint(x: joints[.leftKnee]!.x + cos(kneeAngle + 0.6) * 22, y: joints[.leftKnee]!.y + sin(kneeAngle + 0.6) * 22)
            
            joints[.rightKnee] = CGPoint(x: hipX + 3 + cos(kneeAngle - 0.2) * 25, y: hipY - 3 + sin(kneeAngle - 0.2) * 25)
            joints[.rightAnkle] = CGPoint(x: joints[.rightKnee]!.x + cos(kneeAngle + 0.4) * 22, y: joints[.rightKnee]!.y + sin(kneeAngle + 0.4) * 22)
            
        case .pitching:
            let x: CGFloat = cx - 20
            let y: CGFloat = cy + 15
            
            let hipX: CGFloat
            let hipY: CGFloat
            
            if t < 0.4 {
                hipX = x
                hipY = y
            } else if t < 0.6 {
                let progress = (t - 0.4) / 0.2
                hipX = x + progress * 35
                hipY = y + progress * 5
            } else {
                let progress = (t - 0.6) / 0.4
                hipX = x + 35 + progress * 10
                hipY = y + 5 + progress * 2
            }
            
            joints[.pelvis] = CGPoint(x: hipX, y: hipY)
            joints[.spine] = CGPoint(x: hipX - 2, y: hipY - 25)
            joints[.neck] = CGPoint(x: hipX + 2, y: hipY - 45)
            joints[.head] = CGPoint(x: hipX + 5, y: hipY - 58)
            joints[.leftShoulder] = CGPoint(x: hipX - 5, y: hipY - 45)
            joints[.rightShoulder] = CGPoint(x: hipX + 8, y: hipY - 45)
            
            let lHipX = hipX - 4
            let lHipY = hipY + 4
            joints[.leftHip] = CGPoint(x: lHipX, y: lHipY)
            
            if t < 0.4 {
                joints[.leftKnee] = CGPoint(x: lHipX, y: lHipY + 25)
                joints[.leftAnkle] = CGPoint(x: lHipX, y: lHipY + 48)
            } else {
                let progress = (t - 0.4) / 0.6
                let kneeX = lHipX + progress * 25
                let kneeY = lHipY + 20 + progress * 5
                joints[.leftKnee] = CGPoint(x: kneeX, y: kneeY)
                joints[.leftAnkle] = CGPoint(x: kneeX + progress * 15, y: kneeY + 23 - progress * 5)
            }
            
            let rHipX = hipX + 4
            let rHipY = hipY + 4
            joints[.rightHip] = CGPoint(x: rHipX, y: rHipY)
            
            if t < 0.2 {
                joints[.rightKnee] = CGPoint(x: rHipX + 3, y: rHipY + 25)
                joints[.rightAnkle] = CGPoint(x: rHipX + 3, y: rHipY + 48)
            } else if t < 0.4 {
                let progress = (t - 0.2) / 0.2
                let kneeX = rHipX - progress * 12
                let kneeY = rHipY - progress * 12
                joints[.rightKnee] = CGPoint(x: kneeX, y: kneeY)
                joints[.rightAnkle] = CGPoint(x: kneeX, y: kneeY + 22)
            } else if t < 0.6 {
                let progress = (t - 0.4) / 0.2
                let kneeX = rHipX - 12 + progress * 15
                let kneeY = rHipY - 12 + progress * 25
                joints[.rightKnee] = CGPoint(x: kneeX, y: kneeY)
                joints[.rightAnkle] = CGPoint(x: kneeX - 8, y: kneeY + 20)
            } else {
                let progress = (t - 0.6) / 0.4
                let kneeX = rHipX + 3 - progress * 20
                let kneeY = rHipY + 13 - progress * 10
                joints[.rightKnee] = CGPoint(x: kneeX, y: kneeY)
                joints[.rightAnkle] = CGPoint(x: kneeX - 10, y: kneeY - 5 + progress * 12)
            }
            
            let lSh = joints[.leftShoulder]!
            let rSh = joints[.rightShoulder]!
            
            if t < 0.4 {
                joints[.leftElbow] = CGPoint(x: lSh.x - 8, y: lSh.y + 12)
                joints[.leftWrist] = CGPoint(x: lSh.x, y: lSh.y + 18)
                joints[.rightElbow] = CGPoint(x: rSh.x + 8, y: rSh.y + 12)
                joints[.rightWrist] = CGPoint(x: rSh.x, y: rSh.y + 18)
            } else if t < 0.6 {
                let progress = (t - 0.4) / 0.2
                joints[.leftElbow] = CGPoint(x: lSh.x - 15, y: lSh.y + 5)
                joints[.leftWrist] = CGPoint(x: lSh.x - 22, y: lSh.y - 5)
                joints[.rightElbow] = CGPoint(x: rSh.x - progress * 15, y: rSh.y - progress * 8)
                joints[.rightWrist] = CGPoint(x: rSh.x - 10 - progress * 12, y: rSh.y - 18 - progress * 12)
            } else if t < 0.75 {
                let progress = (t - 0.6) / 0.15
                joints[.leftElbow] = CGPoint(x: lSh.x - 10, y: lSh.y + 15)
                joints[.leftWrist] = CGPoint(x: lSh.x - 8, y: lSh.y + 25)
                let elbX = rSh.x + progress * 12
                let elbY = rSh.y - 12 + progress * 5
                joints[.rightElbow] = CGPoint(x: elbX, y: elbY)
                joints[.rightWrist] = CGPoint(x: elbX + progress * 22, y: elbY - 10 + progress * 20)
            } else {
                let progress = (t - 0.75) / 0.25
                joints[.leftElbow] = CGPoint(x: lSh.x - 5, y: lSh.y + 20)
                joints[.leftWrist] = CGPoint(x: lSh.x - 2, y: lSh.y + 25)
                let elbX = rSh.x + 12 - progress * 18
                let elbY = rSh.y - 7 + progress * 22
                joints[.rightElbow] = CGPoint(x: elbX, y: elbY)
                joints[.rightWrist] = CGPoint(x: elbX - 8, y: elbY + 12)
            }
            
        case .golfSwing:
            let hipX = cx
            let hipY = cy + 20
            joints[.pelvis] = CGPoint(x: hipX, y: hipY)
            
            joints[.spine] = CGPoint(x: hipX, y: hipY - 25)
            joints[.neck] = CGPoint(x: hipX, y: hipY - 45)
            joints[.head] = CGPoint(x: hipX, y: hipY - 57)
            
            joints[.leftHip] = CGPoint(x: hipX - 6, y: hipY + 2)
            joints[.rightHip] = CGPoint(x: hipX + 6, y: hipY + 2)
            
            joints[.leftKnee] = CGPoint(x: hipX - 8, y: hipY + 25)
            joints[.leftAnkle] = CGPoint(x: hipX - 8, y: hipY + 48)
            joints[.rightKnee] = CGPoint(x: hipX + 8, y: hipY + 25)
            joints[.rightAnkle] = CGPoint(x: hipX + 8, y: hipY + 48)
            
            let lSh = CGPoint(x: hipX - 8, y: hipY - 43)
            let rSh = CGPoint(x: hipX + 8, y: hipY - 43)
            joints[.leftShoulder] = lSh
            joints[.rightShoulder] = rSh
            
            let rot: CGFloat
            if t < 0.3 {
                rot = -(t / 0.3) * 1.1
            } else if t < 0.4 {
                let progress = (t - 0.3) / 0.1
                rot = -1.1 + progress * 1.1
            } else if t < 0.5 {
                let progress = (t - 0.4) / 0.1
                rot = progress * 0.4
            } else {
                let progress = min(1.0, (t - 0.5) / 0.3)
                rot = 0.4 + progress * 1.2
            }
            
            let cosR = cos(rot)
            let sinR = sin(rot)
            
            let handLength: CGFloat = 22
            let handsX = hipX + sinR * handLength
            let handsY = hipY - 20 + cosR * handLength
            
            joints[.leftElbow] = CGPoint(x: lSh.x + sinR * 12 - 4 * cosR, y: lSh.y + cosR * 12 + 4 * sinR)
            joints[.rightElbow] = CGPoint(x: rSh.x + sinR * 12 + 4 * cosR, y: rSh.y + cosR * 12 - 4 * sinR)
            
            joints[.leftWrist] = CGPoint(x: handsX - 2, y: handsY)
            joints[.rightWrist] = CGPoint(x: handsX + 2, y: handsY)
            
        case .squat:
            var pct: Double = 0.0
            if t < 0.1 {
                pct = 0.0
            } else if t < 0.5 {
                pct = (t - 0.1) / 0.4
            } else if t < 0.6 {
                pct = 1.0
            } else if t < 0.9 {
                pct = 1.0 - (t - 0.6) / 0.3
            } else {
                pct = 0.0
            }
            
            let hipX = cx
            let depth: CGFloat = CGFloat(pct) * 28
            let hipY = cy + 10 + depth
            
            joints[.pelvis] = CGPoint(x: hipX, y: hipY)
            joints[.spine] = CGPoint(x: hipX, y: hipY - 25)
            joints[.neck] = CGPoint(x: hipX, y: hipY - 45)
            joints[.head] = CGPoint(x: hipX, y: hipY - 57)
            
            joints[.leftShoulder] = CGPoint(x: hipX - 8, y: hipY - 43)
            joints[.rightShoulder] = CGPoint(x: hipX + 8, y: hipY - 43)
            
            let armSpread: CGFloat = CGFloat(pct) * 15
            joints[.leftElbow] = CGPoint(x: hipX - 18, y: hipY - 38 + depth/3)
            joints[.leftWrist] = CGPoint(x: hipX - 28 - armSpread, y: hipY - 35)
            joints[.rightElbow] = CGPoint(x: hipX + 18, y: hipY - 38 + depth/3)
            joints[.rightWrist] = CGPoint(x: hipX + 28 + armSpread, y: hipY - 35)
            
            joints[.leftHip] = CGPoint(x: hipX - 6, y: hipY + 2)
            joints[.rightHip] = CGPoint(x: hipX + 6, y: hipY + 2)
            
            let ankL = CGPoint(x: hipX - 12, y: cy + 45)
            let ankR = CGPoint(x: hipX + 12, y: cy + 45)
            joints[.leftAnkle] = ankL
            joints[.rightAnkle] = ankR
            
            let kneeOut: CGFloat = CGFloat(pct) * 8
            joints[.leftKnee] = CGPoint(x: hipX - 15 - kneeOut, y: hipY + 16 + depth/2)
            joints[.rightKnee] = CGPoint(x: hipX + 15 + kneeOut, y: hipY + 16 + depth/2)
            
        case .pushUp:
            var pct: Double = 0.0
            if t < 0.1 {
                pct = 0.0
            } else if t < 0.5 {
                pct = (t - 0.1) / 0.4
            } else if t < 0.6 {
                pct = 1.0
            } else if t < 0.9 {
                pct = 1.0 - (t - 0.6) / 0.3
            } else {
                pct = 0.0
            }
            
            let plankAngle: CGFloat = -0.15
            let cosP = cos(plankAngle)
            let sinP = sin(plankAngle)
            
            let floorDist: CGFloat = 16.0 - CGFloat(pct) * 12.0
            let originY = cy + 22 + floorDist
            let originX = cx - 35
            
            let toesX = originX
            let toesY = originY - toesX * sinP
            joints[.leftAnkle] = CGPoint(x: toesX, y: toesY)
            joints[.rightAnkle] = CGPoint(x: toesX, y: toesY - 2)
            
            let hipX = toesX + 30 * cosP
            let hipY = toesY + 30 * sinP
            joints[.pelvis] = CGPoint(x: hipX, y: hipY)
            joints[.leftHip] = CGPoint(x: hipX, y: hipY + 2)
            joints[.rightHip] = CGPoint(x: hipX, y: hipY - 2)
            
            joints[.leftKnee] = CGPoint(x: toesX + 15 * cosP, y: toesY + 15 * sinP + 1)
            joints[.rightKnee] = CGPoint(x: toesX + 15 * cosP, y: toesY + 15 * sinP - 1)
            
            let shX = hipX + 30 * cosP
            let shY = hipY + 30 * sinP
            joints[.spine] = CGPoint(x: hipX + 15 * cosP, y: hipY + 15 * sinP)
            joints[.neck] = CGPoint(x: shX, y: shY)
            joints[.leftShoulder] = CGPoint(x: shX, y: shY + 3)
            joints[.rightShoulder] = CGPoint(x: shX, y: shY - 3)
            
            joints[.head] = CGPoint(x: shX + 10 * cosP, y: shY + 10 * sinP)
            
            let handsX = shX
            let handsY = cy + 28
            joints[.leftWrist] = CGPoint(x: handsX, y: handsY)
            joints[.rightWrist] = CGPoint(x: handsX, y: handsY - 3)
            
            let bendX = handsX - 8 - CGFloat(pct) * 6
            let bendY = (shY + handsY) / 2.0 - 5 + CGFloat(pct) * 4
            joints[.leftElbow] = CGPoint(x: bendX, y: bendY)
            joints[.rightElbow] = CGPoint(x: bendX, y: bendY - 3)
        }
        
        return joints
    }
}

enum CarnivalEvent: CaseIterable, Sendable {
    case neuralBoost
    case sponsorHub
    case biomechanicalPit
    case cnsDuel
}

struct BoardTile: Identifiable, Sendable {
    let id: Int
    let name: String
    let type: TileType
    
    enum TileType: String, CaseIterable, Sendable {
        case start = "START"
        case neuralBoost = "BOOST"
        case sponsorHub = "SPONSOR"
        case biomechanicalPit = "PIT"
        case cnsDuel = "DUEL"
        case grandPortal = "PORTAL"
    }
    
    static let boardTiles: [BoardTile] = [
        BoardTile(id: 0, name: "Neural Sandbox", type: .start),
        BoardTile(id: 1, name: "Motor Cortex", type: .neuralBoost),
        BoardTile(id: 2, name: "Muscle Milk Hub", type: .sponsorHub),
        BoardTile(id: 3, name: "Spinal Decel", type: .biomechanicalPit),
        BoardTile(id: 4, name: "Reflex Arena", type: .cnsDuel),
        BoardTile(id: 5, name: "Gatorade Zone", type: .sponsorHub),
        BoardTile(id: 6, name: "Velocity Wave", type: .neuralBoost),
        BoardTile(id: 7, name: "Red Bull Station", type: .sponsorHub),
        BoardTile(id: 8, name: "Knee Instability", type: .biomechanicalPit),
        BoardTile(id: 9, name: "Synapse Bridge", type: .neuralBoost),
        BoardTile(id: 10, name: "Cerebellar Arena", type: .cnsDuel),
        BoardTile(id: 11, name: "Nike Lab", type: .sponsorHub),
        BoardTile(id: 12, name: "Ankle Sprain Trap", type: .biomechanicalPit),
        BoardTile(id: 13, name: "Hyper Drive", type: .neuralBoost),
        BoardTile(id: 14, name: "Quantum Duel", type: .cnsDuel),
        BoardTile(id: 15, name: "Grand Portal", type: .grandPortal)
    ]
}

