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

    @Environment(\.dismiss) private var dismiss

    private var isKarate: Bool { gameMode.id == .karate }

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
        case .baseball: 10
        case .football: 8
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

            if showResults {
                resultsOverlay
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
        .onAppear { startGame() }
        .onDisappear { multipeerService.stop() }
    }

    // MARK: - HUD Bar

    private var hudBar: some View {
        ZStack {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(score)")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    Image(systemName: gameMode.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(gameMode.accentColor)

                    if isDunkContest {
                        Text("Round \(dunkRound)/3")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                    } else if isBlacktop {
                        Text("First to \(targetScore)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(gameMode.accentColor)
                    } else if isTimerBased {
                        Text(timeFormatted)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(timeRemaining <= 10 ? .red : gameMode.accentColor)
                            .contentTransition(.numericText())
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
                    }
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("OPP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(opponentScore)")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

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
        .background(Theme.cardBackground.opacity(0.8))
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
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Dunk Judge Overlay

    private func dunkJudgeOverlay(j1: Int, j2: Int, j3: Int) -> some View {
        VStack(spacing: 8) {
            Spacer()

            VStack(spacing: 10) {
                HStack(spacing: 20) {
                    judgeScoreView(label: "Judge 1", score: j1)
                    judgeScoreView(label: "Judge 2", score: j2)
                    judgeScoreView(label: "Judge 3", score: j3)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.orange.opacity(0.5), lineWidth: 2)
                        )
                )

                Text("Total: \(j1 + j2 + j3)")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)

                if !crowdMessage.isEmpty {
                    Text(crowdMessage)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(2)
                }
            }
            .padding(.bottom, 80)
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func judgeScoreView(label: String, score: Int) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            Text("\(score)")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 12) {
            ps2ActionButtons

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
        case .baseball: ["Swing", "Bunt", "Power Hit"]
        case .football: ["Short Pass", "Deep Throw", "Scramble"]
        case .soccer: ["Left", "Center", "Right"]
        case .golf: ["Chip", "Approach", "Full Swing"]
        case .tennis: ["Serve", "Volley", "Baseline"]
        case .volleyball: ["Spike", "Set", "Block"]
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
        showResults = false

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

        let oppDifficulty = 0.45 - (sessionReadiness / 400)
        let oppChance = Double.random(in: 0...1) > oppDifficulty
        if oppChance {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation {
                    opponentScore += Int.random(in: 1...3)
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
            return action == "Power Hit" ? 4 : (action == "Swing" ? 2 : 1)
        case .football:
            return action == "Deep Throw" ? 7 : (action == "Short Pass" ? 3 : 2)
        case .soccer:
            return 1
        case .golf:
            return action == "Chip" ? 3 : (action == "Approach" ? 2 : 1)
        case .tennis:
            return action == "Serve" ? 4 : (action == "Volley" ? 3 : 2)
        case .volleyball:
            return action == "Spike" ? 3 : (action == "Block" ? 2 : 1)
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
        withAnimation(.spring(response: 0.4)) {
            isActive = false
            showResults = true
        }
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
            auraLevel: arcadePhysics.auraLevel
        )
    }
}
