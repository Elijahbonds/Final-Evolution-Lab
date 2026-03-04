import SwiftUI
import SceneKit

struct GamePlayView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode
    let sessionReadiness: Double

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

    @State private var dunkRound: Int = 1
    @State private var lastJudgeScores: (Int, Int, Int)?
    @State private var crowdMessage: String = ""
    @State private var chakraBar: Double = 0
    @State private var karateHitFlash: Bool = false

    @State private var golfCharge: Double = 0
    @State private var golfPhase: GolfSwingPhase = .idle
    @State private var aimPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var footballPhase: FootballPhase = .catch
    @State private var runMeter: Double = 0
    @State private var runMeterTimer: Task<Void, Never>?
    @State private var swipeStart: CGPoint?
    @State private var swipeStartTime: Date?
    @State private var golfDragStartY: CGFloat = 0

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

    @Environment(\.dismiss) private var dismiss

    private enum GolfSwingPhase { case idle, backswing }
    private enum FootballPhase { case `catch`, run }

    private var isKarate: Bool { gameMode.id == .karate }
    private var inputScheme: InputScheme { gameMode.id.inputScheme }
    private var supportsTricks: Bool { gameMode.id == .basketballDunkContest || gameMode.id == .basketballHeadToHead || gameMode.id == .basketball3v3 || isKarate }
    private var specialMeterFull: Bool { specialMeter >= 100 }

    private var arcadePhysics: ArcadePhysics {
        ArcadePhysics.fromPRQ(
            viewModel.profile.metrics.prqScore,
            neuralDrive: sessionReadiness,
            audit: viewModel.biomechanicsAudit
        )
    }

    private var physicsConfig: GamePhysicsConfig {
        GamePhysicsConfig.forMode(gameMode.id, prq: viewModel.profile.metrics.prqScore, audit: viewModel.biomechanicsAudit)
    }

    private var isTimerBased: Bool {
        gameMode.multiplayerType == .realtime
    }

    private var isDunkContest: Bool {
        gameMode.id == .basketballDunkContest
    }

    private var isBlacktop: Bool {
        gameMode.id == .basketballHeadToHead || gameMode.id == .basketball3v3
    }

    private var targetScore: Int {
        gameMode.id == .basketball3v3 ? 15 : 21
    }

    private var maxRounds: Int {
        switch gameMode.id {
        case .golf: 9
        case .tennis: 1
        case .baseball: 5
        case .football: 1
        case .soccer: 5
        case .volleyball: 1
        case .gymnastics: 6
        default: 1
        }
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                hudBar
                sceneArea
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
                    winner: score > opponentScore ? .p1 : (score == opponentScore ? .draw : .p2),
                    p1Score: score,
                    p2Score: opponentScore,
                    title: gameMode.name,
                    accentColor: gameMode.accentColor,
                    onReturn: {
                        finalizeResults()
                        dismiss()
                    }
                )
            }

            if !gameReady && !showResults {
                GetReadyScreen(
                    title: gameMode.name,
                    subtitle: gameMode.hint,
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: {
                        gameReady = true
                        startGame()
                    }
                )
            }

            if isActive && inputScheme == .charge {
                PS2GamepadOverlay(
                    onFaceButton: { button in handlePS2FaceButton(button) },
                    onDPad: { direction in handlePS2DPad(direction) },
                    accentColor: gameMode.accentColor,
                    isActive: isActive
                )
            }

            if supportsTricks && isActive {
                specialMeterOverlay
            }

            if supportsTricks && isActive {
                trickModifierOverlay
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
        .onAppear { }
        .onDisappear { multipeerService.stop() }
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
            GameSceneHostView(gameMode: gameMode.id, onAction: handleSceneAction)
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

            if inputScheme == .dragTap && isActive {
                aimCrosshairOverlay
            }

            if (inputScheme == .swipe || inputScheme == .swipeGolf) && isActive {
                gestureOverlay
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Aim Crosshair (Volleyball)

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
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isActive else { return }
                    let geo = value.location
                    aimPosition = CGPoint(
                        x: max(0, min(1, geo.x / max(1, UIScreen.main.bounds.width))),
                        y: max(0, min(1, geo.y / 400))
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
        VStack(spacing: 12) {
            switch inputScheme {
            case .charge:
                if !isActive {
                    ps2ActionButtons
                } else {
                    chargeModeLiveHint
                }
            case .swipe:
                swipeHintView
            case .swipeGolf:
                golfControlView
            case .dragTap:
                volleyballControlView
            case .kickReturn:
                kickReturnControlView
            }

            if !isActive && !showResults {
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
            }

            HStack(spacing: 16) {
                Button {
                    multipeerService.startHosting(gameId: gameMode.id.rawValue)
                } label: {
                    Label("HOST", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.brandCyan.opacity(0.1))
                        .clipShape(Capsule())
                }

                Button {
                    multipeerService.startBrowsing(gameId: gameMode.id.rawValue)
                } label: {
                    Label("JOIN", systemImage: "magnifyingglass")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground.opacity(0.9))
    }

    private var chargeModeLiveHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 18))
                .foregroundStyle(gameMode.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("USE CONTROLLER")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("\u{25B3} Shoot \u{25A1} Drive \u{25CB} Style \u{2715} Jump")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(gameMode.accentColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(gameMode.accentColor.opacity(0.15), lineWidth: 1)
                )
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
        case .karate: ["Punch", "Kick", "Block"]
        case .baseball: ["Swing", "Bunt"]
        case .football: ["Catch", "Break Away"]
        case .soccer: ["Shoot"]
        case .golf: ["Swing"]
        case .tennis: ["Serve", "Volley", "Baseline"]
        case .volleyball: ["Spike"]
        case .gymnastics: ["Tumble", "Vault", "Dismount"]
        }
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

    // MARK: - Results Overlay

    private var resultsOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: score > opponentScore ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 48))
                    .foregroundStyle(score > opponentScore ? .yellow : .secondary)

                Text(score > opponentScore ? "VICTORY" : (score == opponentScore ? "DRAW" : "DEFEAT"))
                    .font(.system(size: 36, weight: .black))
                    .italic()
                    .foregroundStyle(.white)

                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(score)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("YOU")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Text("—")
                        .font(.title)
                        .foregroundStyle(.tertiary)

                    VStack(spacing: 4) {
                        Text("\(opponentScore)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("OPP")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    PRQTierBadge(tier: viewModel.userPRQTier, prq: viewModel.effectiveMetrics.prqScore)

                    if arcadePhysics.neuralBurstActive {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                            Text("BURST BONUS")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(Theme.elitePurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.elitePurple.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                rewardsBreakdown
                rewardsRow

                Button {
                    finalizeResults()
                    dismiss()
                } label: {
                    Text("CLAIM REWARDS")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(gameMode.accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 32)

                Button {
                    resetGame()
                } label: {
                    Text("REMATCH")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(gameMode.accentColor)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(gameMode.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(.black.opacity(0.7))
        .transition(.opacity)
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
        ShardReward.forGameResult(
            won: score > opponentScore,
            tied: score == opponentScore,
            combo: maxCombo,
            criticals: criticalHits
        )
    }

    private var shardsReward: Int {
        shardRewards.reduce(0) { $0 + $1.amount }
    }

    private var prqReward: Double {
        let base = PRQ.matchReward(won: score > opponentScore, tied: score == opponentScore)
        return base + (sessionReadiness / 100.0) * 0.5
    }

    // MARK: - Game Logic

    private func startGame() {
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

        if isTimerBased {
            timeRemaining = 60
            startTimer()
        }
    }

    private func resetGame() {
        withAnimation { showResults = false }
        startGame()
    }

    private func startTimer() {
        Task {
            while isActive && timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard isActive else { return }
                withAnimation { timeRemaining -= 1 }
                if timeRemaining <= 0 {
                    endGame()
                }
            }
        }
    }

    private func performAction(_ action: String) {
        guard isActive else { return }

        let physics = leakageAdjustedPhysics
        let success = Double.random(in: 0...1) < physics.successChanceBase
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

            if isDunkContest {
                handleDunkJudging()
            }
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
        }

        let ddaChance = DynamicDifficulty.opponentSuccessChance(
            baseChance: 0.55,
            playerScore: score,
            aiScore: opponentScore,
            sessionReadiness: sessionReadiness
        )
        if Double.random(in: 0...1) < ddaChance {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation {
                    opponentScore += DynamicDifficulty.opponentPoints(
                        playerScore: score,
                        aiScore: opponentScore,
                        maxPoints: 3
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

    // MARK: - Dunk Contest Judging

    private func handleDunkJudging() {
        let pop = Double(physicsConfig.jumpHeight)
        let isElite = pop > 3.0
        let base = isElite ? 46 : 40
        let spread = isElite ? 5 : 8
        let j1 = min(50, base + Int.random(in: 0..<spread))
        let j2 = min(50, base + Int.random(in: 0..<spread))
        let j3 = min(50, base + Int.random(in: 0..<spread))
        let total = j1 + j2 + j3

        withAnimation(.spring(response: 0.3)) {
            lastJudgeScores = (j1, j2, j3)
            if total >= 145 {
                crowdMessage = "CROWD GOES WILD!"
            } else if total >= 135 {
                crowdMessage = "BOOM!"
            } else {
                crowdMessage = "NICE DUNK!"
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.3)) {
                lastJudgeScores = nil
                crowdMessage = ""
            }
            withAnimation {
                dunkRound = min(3, dunkRound + 1)
            }
            if dunkRound > 3 {
                endGame()
            }
        }
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
        case .karate:
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
        runMeterTimer?.cancel()
        runMeterTimer = nil
        withAnimation(.spring(response: 0.4)) {
            isActive = false
            showResults = true
        }
    }

    // MARK: - Wii-Style Input Handlers

    private func applyOutcomeFromCharge(_ chargeValue: Double) {
        let physics = leakageAdjustedPhysics
        let inSweetSpot = chargeValue >= 0.35 && chargeValue <= 0.75
        let baseChance = inSweetSpot ? physics.successChanceBase + 0.15 : physics.successChanceBase * chargeValue
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
                    withAnimation { opponentScore += 1 }
                    endGame()
                }
                return
            }
        }

        if gameMode.id != .football {
            let ddaChance = DynamicDifficulty.opponentSuccessChance(
                baseChance: 0.55,
                playerScore: score,
                aiScore: opponentScore,
                sessionReadiness: sessionReadiness
            )
            if Double.random(in: 0...1) < ddaChance {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    withAnimation {
                        opponentScore += DynamicDifficulty.opponentPoints(
                            playerScore: score,
                            aiScore: opponentScore,
                            maxPoints: 2
                        )
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
        applyOutcomeFromCharge(finalCharge)
    }

    private func handleVolleyballSpike() {
        guard isActive else { return }
        let centerBias = 1.0 - abs(aimPosition.x - 0.5) * 1.2 - abs(aimPosition.y - 0.5) * 0.8
        let charge = max(0.2, min(0.9, 0.35 + centerBias * 0.4))
        applyOutcomeFromCharge(charge)
    }

    private func handleCatchTap() {
        guard isActive, footballPhase == .catch else { return }
        withAnimation(.spring(response: 0.2)) {
            footballPhase = .run
            runMeter = 0
        }
        runMeterTimer = Task {
            while !Task.isCancelled && runMeter < 100 {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.04)) {
                    runMeter = min(100, runMeter + 2.4)
                }
            }
            if !Task.isCancelled {
                withAnimation { footballPhase = .catch }
                applyOutcomeFromCharge(0)
            }
        }
    }

    private func handleRunTap() {
        guard isActive, footballPhase == .run else { return }
        runMeterTimer?.cancel()
        runMeterTimer = nil
        withAnimation { footballPhase = .catch }
        let inZone = runMeter >= 35 && runMeter <= 70
        applyOutcomeFromCharge(inZone ? 0.65 : 0.15)
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
        viewModel.profile.evolutionShards += shardsReward
        viewModel.profile.metrics.prqScore = PRQ.clamp(viewModel.profile.metrics.prqScore + prqReward)
        viewModel.profile.metrics.neuralDrive = min(100, viewModel.profile.metrics.neuralDrive + 3)

        let result = GameSessionResult(
            id: UUID().uuidString,
            gameModeId: gameMode.id.rawValue,
            date: Date(),
            score: score,
            opponentScore: opponentScore,
            shardsEarned: shardsReward,
            prqBonus: prqReward,
            isMultiplayer: multipeerService.isConnected,
            duration: isTimerBased ? 60 : roundNumber * 5
        )

        SaveSystem.saveProfile(viewModel.profile)
        SaveSystem.saveGameResult(result)
        viewModel.globalLeaderboard.refreshRankings(userProfile: viewModel.profile, sampleData: SampleData.leaderboard)
    }

    private func handleLiveLeakage(joint: JointType, severity: Double) {
        guard isActive, severity > 0.3 else { return }

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
            specialMeterGainRate: arcadePhysics.specialMeterGainRate
        )
    }

    // MARK: - Special Meter Overlay

    private var specialMeterOverlay: some View {
        VStack {
            Spacer()
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
            .padding(.bottom, 8)
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
                                trickDirectionButton(.up, label: "\u{25B2}", hint: isKarate ? "Rasengan" : "Windmill")
                                trickDirectionButton(.down, label: "\u{25BC}", hint: isKarate ? "Barrage" : "Between")
                                trickDirectionButton(.left, label: "\u{25C0}", hint: isKarate ? "Chidori" : "Tomahawk")
                                trickDirectionButton(.right, label: "\u{25B6}", hint: isKarate ? "Shadow" : "360")
                            }
                            if specialMeterFull {
                                Button {
                                    executeSpecialTrick()
                                } label: {
                                    Text(isKarate ? "GATE OF DEATH" : "GIANT KILLER")
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

                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            isModifierHeld.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "l1.button.roundedbottom.horizontal")
                                .font(.system(size: 12, weight: .bold))
                            Text("TRICK")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(isModifierHeld ? .black : Theme.elitePurple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            isModifierHeld
                                ? AnyShapeStyle(Theme.elitePurple)
                                : AnyShapeStyle(Theme.elitePurple.opacity(0.15))
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Theme.elitePurple.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 80)
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
        let trick = TrickCombo.resolve(direction: direction.trickDirection, mode: gameMode.id)
        executeTrick(trick)
    }

    private func executeSpecialTrick() {
        guard isActive, specialMeterFull else { return }
        let specials = TrickCombo.combos(for: gameMode.id).filter { $0.isSpecial }
        guard let trick = specials.first else { return }
        withAnimation(.spring(response: 0.2)) {
            specialMeter = 0
        }
        executeTrick(trick)
        triggerSlowMo(duration: 1.5)
    }

    private func executeTrick(_ trick: TrickCombo) {
        let physics = leakageAdjustedPhysics
        let riskRoll = Double.random(in: 0...1)
        let successThreshold = physics.successChanceBase / trick.riskMultiplier
        let success = riskRoll < successThreshold
        let isCritical = success && Double.random(in: 0...1) < physics.criticalHitChance

        if success {
            let stylePoints = physics.trickStylePoints(for: trick)
            let finalPoints = physics.adjustedPoints(base: stylePoints, combo: combo, isCritical: isCritical)

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
            }

            if isCritical {
                criticalHits += 1
                triggerCriticalFlash()
                triggerScreenShake(intensity: 0.8)
            } else {
                triggerFlash()
                triggerScreenShake(intensity: 0.5)
            }
            triggerImpactFlash()
            resetStreakTimer()

            if trick.isSpecial {
                triggerSlowMo(duration: 1.0)
                triggerScreenShake(intensity: 1.0)
            }

            Task {
                try? await Task.sleep(for: .seconds(2.0))
                withAnimation { showTrickText = false; lastTrickName = "" }
            }
        } else {
            withAnimation(.spring(response: 0.3)) {
                combo = 0
                lastAction = "CLANK!"
                lastActionIsCritical = false
                lastActionIsBurst = false
            }
            triggerScreenShake(intensity: 0.3)
        }

        withAnimation(.spring(response: 0.2)) {
            isModifierHeld = false
        }

        let clearDelay: Double = 2.0
        Task {
            try? await Task.sleep(for: .seconds(clearDelay))
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

    // MARK: - PS2 Controller Handlers

    private func handlePS2FaceButton(_ button: PS2FaceButton) {
        guard isActive else { return }
        switch button {
        case .triangle:
            performAction(actionsForMode.first ?? "Shoot")
        case .square:
            if actionsForMode.count > 1 {
                performAction(actionsForMode[1])
            } else {
                performAction(actionsForMode.first ?? "Drive")
            }
        case .circle:
            if actionsForMode.count > 2 {
                performAction(actionsForMode[2])
            } else {
                if isModifierHeld {
                    executeTrickCombo(direction: currentTrickDirection)
                } else {
                    performAction(actionsForMode.last ?? "Style")
                }
            }
        case .cross:
            if isKarate {
                handleBlock()
            } else {
                performAction(actionsForMode.first ?? "Jump")
            }
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
        if isModifierHeld {
            executeTrickCombo(direction: comboDir)
        }
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
        triggerSlowMo(duration: 1.0)
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
        triggerSlowMo(duration: 1.5)
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
}
