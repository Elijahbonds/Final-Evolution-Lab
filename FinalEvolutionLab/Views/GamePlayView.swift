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
    @Environment(\.dismiss) private var dismiss

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

    private var maxRounds: Int {
        switch gameMode.id {
        case .golf: 9
        case .tennis: 1
        case .baseball: 10
        case .football: 8
        case .soccer: 5
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

    private var hudBar: some View {
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

                if isTimerBased {
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
        .background(Theme.cardBackground.opacity(0.8))
    }

    private var timeFormatted: String {
        let mins = timeRemaining / 60
        let secs = timeRemaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

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
                            Text("\(combo)x COMBO")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundStyle(combo >= 5 ? Theme.brandCyan : gameMode.accentColor)
                            Text(String(format: "%.1fx", arcadePhysics.comboMultiplier(for: combo)))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(combo >= 5 ? Theme.brandCyan.opacity(0.2) : gameMode.accentColor.opacity(0.15))
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
                        isNeuralBurst: lastActionIsBurst
                    )
                    .padding(.top, 8)
                    Spacer()
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            actionButtons

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

    private var actionButtons: some View {
        HStack(spacing: 10) {
            ForEach(actionsForMode, id: \.self) { action in
                Button {
                    performAction(action)
                } label: {
                    Text(action.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(gameMode.accentColor.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(gameMode.accentColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)
            }
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
        let base = score > opponentScore ? 2.0 : (score == opponentScore ? 0.5 : 0.2)
        return base + (sessionReadiness / 100.0) * 0.5
    }

    private func startGame() {
        withAnimation { isActive = true }
        score = 0
        opponentScore = 0
        combo = 0
        maxCombo = 0
        criticalHits = 0
        roundNumber = 1
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
                if isCritical {
                    criticalHits += 1
                    lastAction = "CRITICAL \(action.uppercased()) +\(finalPoints)"
                } else if arcadePhysics.neuralBurstActive {
                    lastAction = "BURST \(action.uppercased()) +\(finalPoints)"
                } else {
                    lastAction = "\(action.uppercased()) +\(finalPoints)"
                }
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
        } else {
            withAnimation(.spring(response: 0.3)) {
                combo = 0
                lastAction = "MISSED"
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

        if !isTimerBased {
            roundNumber += 1
            if roundNumber > maxRounds {
                endGame()
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { lastAction = "" }
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
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + prqReward)
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
