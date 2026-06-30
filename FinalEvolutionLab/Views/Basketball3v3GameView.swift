import SwiftUI

// MARK: - Phase

private enum v3Phase {
    case ready, playing, result
}

// MARK: - 3v3 Action

private enum v3Action: String {
    case shoot = "SHOOT"
    case passLeft = "PASS LEFT"
    case passRight = "PASS RIGHT"
}

// MARK: - Shot Result

private enum v3ShotResult: String {
    case score = "SCORE!"
    case blocked = "BLOCKED"
    case miss = "MISS"
    case assist = "ASSIST"
}

// MARK: - Possession Team

private enum v3Team {
    case player, opponent
}

// MARK: - Main View

struct Basketball3v3GameView: View {
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss

    // Phase
    @State private var phase: v3Phase = .ready

    // Scores
    @State private var playerTeamScore: Int = 0
    @State private var opponentTeamScore: Int = 0

    // Match clock: 120 seconds (2 minutes)
    @State private var matchClock: Int = 120
    @State private var matchClockTask: Task<Void, Never>? = nil

    // Shot clock
    @State private var shotClock: Int = 24
    @State private var shotClockTask: Task<Void, Never>? = nil

    // Opponent AI task
    @State private var opponentTask: Task<Void, Never>? = nil

    // Combo
    @State private var comboCount: Int = 0
    @State private var comboMultiplier: Int = 1

    // Feedback
    @State private var lastResult: v3ShotResult? = nil
    @State private var showResultLabel: Bool = false
    @State private var lastActionLabel: String = ""
    @State private var lastPasser: String = ""

    // Possession
    @State private var possession: v3Team = .player

    // Active passer (who has the ball on player team)
    @State private var activePasser: Int = 0   // 0 = YOU, 1 = Left AI, 2 = Right AI

    // Shard reward tracking
    @State private var shardsRewarded: Bool = false

    private let targetScore = 15
    private let accentColor = Color(red: 0.2, green: 0.8, blue: 0.4)

    private let teammateNames = ["Dre", "Kev"]
    private let opponentNames = ["Ghost", "Blaze", "Icy"]

    // AI difficulty scales with PRQ
    private var aiShotChance: Double {
        let prq = viewModel.effectiveMetrics.prqScore
        return 0.28 + (prq / 100.0) * 0.42
    }

    private var aiAttackDelayLow: Double {
        2.5 + (1 - viewModel.effectiveMetrics.prqScore / 100.0) * 2.0
    }

    private var aiAttackDelayHigh: Double {
        aiAttackDelayLow + 1.8
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.0, green: 0.06, blue: 0.02), Theme.deepBlack],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "3v3 Streetball",
                    subtitle: "2-min match · First to 15 wins",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startGame() }
                )

            case .playing:
                playingBody

            case .result:
                resultScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    cancelAllTasks()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("EXIT")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                    }
                    .foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { cancelAllTasks() }
    }

    // MARK: - Playing Body

    private var playingBody: some View {
        VStack(spacing: 0) {
            clockHeader
                .padding(.horizontal, 20)
                .padding(.top, 8)

            scoreBoard
                .padding(.horizontal, 20)
                .padding(.top, 6)

            courtZone
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            comboRow
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            inputPanel
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Clock Header

    private var clockHeader: some View {
        HStack(spacing: 12) {
            // Match clock
            VStack(spacing: 1) {
                Text("MATCH")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text(formattedClock)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(matchClock <= 20 ? .red : .white)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Possession indicator
            HStack(spacing: 6) {
                if possession == .player {
                    Image(systemName: "arrowtriangle.right.fill")
                        .foregroundStyle(accentColor)
                } else {
                    Image(systemName: "arrowtriangle.left.fill")
                        .foregroundStyle(.red)
                }
                Text(possession == .player ? "YOUR TEAM" : "OPPONENTS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(possession == .player ? accentColor : .red)
            }

            Spacer()

            // Shot clock
            VStack(spacing: 1) {
                Text("SHOT")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(shotClock)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(shotClock <= 5 ? .red : .white)
                    .contentTransition(.numericText())
            }
        }
    }

    private var formattedClock: String {
        let m = matchClock / 60
        let s = matchClock % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Score Board

    private var scoreBoard: some View {
        HStack(spacing: 16) {
            // Player team
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR TEAM")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(2)
                Text("\(playerTeamScore)")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { idx in
                        let name = idx == 0 ? "YOU" : teammateNames[idx - 1]
                        let isActive = possession == .player && activePasser == idx
                        Text(name)
                            .font(.system(size: 9, weight: isActive ? .black : .medium, design: .monospaced))
                            .foregroundStyle(isActive ? accentColor : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(isActive ? accentColor.opacity(0.15) : Color.clear)
                            .clipShape(.rect(cornerRadius: 6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            VStack(spacing: 2) {
                Text("\u{2014}")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text("TO 15")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }

            // Opponent team
            VStack(alignment: .trailing, spacing: 4) {
                Text("OPPONENTS")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(opponentTeamScore)")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .contentTransition(.numericText())
                HStack(spacing: 6) {
                    ForEach(opponentNames, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }

    // MARK: - Court Zone

    private var courtZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            // Court arc visuals
            Circle()
                .stroke(accentColor.opacity(0.06), lineWidth: 2)
                .frame(width: 200, height: 200)

            Circle()
                .stroke(accentColor.opacity(0.12), lineWidth: 1.5)
                .frame(width: 90, height: 90)

            VStack(spacing: 10) {
                // Team avatar row
                HStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { idx in
                        let name = idx == 0 ? "YOU" : teammateNames[idx - 1]
                        let isActive = possession == .player && activePasser == idx
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(isActive ? accentColor.opacity(0.25) : Color.white.opacity(0.06))
                                    .frame(width: 40, height: 40)
                                Image(systemName: idx == 0 ? "figure.basketball" : "figure.walk")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(isActive ? accentColor : .secondary)
                            }
                            Text(name)
                                .font(.system(size: 8, weight: isActive ? .black : .medium, design: .monospaced))
                                .foregroundStyle(isActive ? accentColor : .secondary)
                        }
                    }
                }

                // Feedback label
                if showResultLabel, let result = lastResult {
                    VStack(spacing: 2) {
                        Text(result.rawValue)
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                result == .score || result == .assist
                                    ? accentColor
                                    : (result == .blocked ? .red : .secondary)
                            )
                        if !lastPasser.isEmpty && result == .assist {
                            Text("ASSIST: \(lastPasser)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(accentColor.opacity(0.7))
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: showResultLabel)
                } else if !lastActionLabel.isEmpty {
                    Text(lastActionLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                }

                // Opponent team row
                HStack(spacing: 16) {
                    ForEach(opponentNames, id: \.self) { name in
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(possession == .opponent ? 0.2 : 0.06))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(possession == .opponent ? .red : Color.red.opacity(0.3))
                            }
                            Text(name)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Combo Row

    private var comboRow: some View {
        Group {
            if comboCount >= 2 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor)
                    Text("x\(comboMultiplier) HOT STREAK")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                    Text("(\(comboCount) makes)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accentColor.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accentColor.opacity(0.3), lineWidth: 1))
                .clipShape(.rect(cornerRadius: 10))
                .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accentColor.opacity(0.4))
                    Text("TAP SHOOT · SWIPE ← PASS LEFT · SWIPE → PASS RIGHT")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }
            }
        }
        .frame(height: 32)
        .animation(.spring(response: 0.3), value: comboCount)
    }

    // MARK: - Input Panel

    private var inputPanel: some View {
        VStack(spacing: 12) {
            // Shoot button
            Button {
                guard phase == .playing, possession == .player else { return }
                playerShoot()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "basketball.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("SHOOT")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    possession == .player && phase == .playing
                        ? LinearGradient(colors: [accentColor, accentColor.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: possession == .player ? accentColor.opacity(0.35) : .clear, radius: 12)
            }
            .disabled(possession != .player || phase != .playing)

            // Pass buttons
            HStack(spacing: 12) {
                Button {
                    guard phase == .playing, possession == .player else { return }
                    playerPass(to: 1, direction: "LEFT")
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("PASS \(teammateNames[0])")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(possession == .player ? accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor.opacity(possession == .player ? 0.08 : 0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(possession == .player ? 0.25 : 0.08), lineWidth: 1))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(possession != .player || phase != .playing)

                Button {
                    guard phase == .playing, possession == .player else { return }
                    playerPass(to: 2, direction: "RIGHT")
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                        Text("PASS \(teammateNames[1])")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(possession == .player ? accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor.opacity(possession == .player ? 0.08 : 0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(possession == .player ? 0.25 : 0.08), lineWidth: 1))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(possession != .player || phase != .playing)
            }
        }
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        let playerWon = playerTeamScore > opponentTeamScore
        let didTie = playerTeamScore == opponentTeamScore
        let winner: ResultScreen.ResultWinner = didTie ? .draw : (playerWon ? .p1 : .p2)
        let prqGain = PRQ.modeReward(
            mode: .basketball3v3,
            won: playerWon,
            tied: didTie,
            combo: comboCount,
            criticals: comboCount / 3,
            scoreDifferential: playerTeamScore - opponentTeamScore
        )
        return ResultScreen(
            winner: winner,
            p1Score: playerTeamScore,
            p2Score: opponentTeamScore,
            title: "3v3 Streetball",
            accentColor: accentColor,
            prqGain: prqGain,
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "Court IQ",
            modeAttributeValue: PRQ.attributeValue(prq: viewModel.effectiveMetrics.prqScore, for: .basketball3v3),
            onReturn: {
                if !shardsRewarded {
                    let shards = playerWon ? 50 : (didTie ? 25 : 15)
                    viewModel.profile.evolutionShards += shards
                    SaveSystem.saveProfile(viewModel.profile)
                    shardsRewarded = true
                }
                dismiss()
            }
        )
    }

    // MARK: - Game Logic

    private func startGame() {
        playerTeamScore = 0
        opponentTeamScore = 0
        comboCount = 0
        comboMultiplier = 1
        possession = .player
        activePasser = 0
        matchClock = 120
        shotClock = 24
        showResultLabel = false
        lastActionLabel = ""
        lastPasser = ""
        shardsRewarded = false
        phase = .playing
        startMatchClock()
        resetShotClock()
        scheduleOpponentAttack()
    }

    // Player shoots
    private func playerShoot() {
        guard phase == .playing, possession == .player else { return }
        shotClockTask?.cancel()

        let prq = viewModel.effectiveMetrics.prqScore
        let baseChance = 0.42 + (prq / 100.0) * 0.32
        let hitChance = min(0.85, baseChance + Double(comboCount) * 0.015)
        let made = Double.random(in: 0...1) < hitChance

        let passer = activePasser

        if made {
            comboCount += 1
            comboMultiplier = min(4, 1 + comboCount / 3)
            let pts = 2 * comboMultiplier
            withAnimation(.spring(response: 0.3)) {
                playerTeamScore = min(playerTeamScore + pts, 99)
            }
            if passer != 0 {
                lastPasser = teammateNames[passer - 1]
                flashResult(.assist)
            } else {
                lastPasser = ""
                flashResult(.score)
            }
        } else {
            comboCount = 0
            comboMultiplier = 1
            lastPasser = ""
            flashResult(.miss)
        }

        // Turnover after shot
        possession = .opponent
        activePasser = 0
        resetShotClock()
        lastActionLabel = ""

        if playerTeamScore >= targetScore {
            endGame()
            return
        }

        scheduleOpponentAttack()
    }

    // Player passes to teammate
    private func playerPass(to teammate: Int, direction: String) {
        guard phase == .playing, possession == .player else { return }
        lastActionLabel = "PASS \(direction)"
        let succeeded = Double.random(in: 0...1) < 0.78
        if succeeded {
            activePasser = teammate
            lastActionLabel = "\(teammateNames[teammate - 1]) has the ball"
            // AI teammate will shoot after short delay
            scheduleTeammateShot(from: teammate)
        } else {
            // Turnover / stolen
            flashResult(.blocked)
            possession = .opponent
            activePasser = 0
            comboCount = 0
            comboMultiplier = 1
            resetShotClock()
            scheduleOpponentAttack()
        }
    }

    // AI teammate shoots after receiving a pass
    private func scheduleTeammateShot(from teammate: Int) {
        Task {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 800...1400)))
            await MainActor.run {
                guard phase == .playing, possession == .player, activePasser == teammate else { return }
                let made = Double.random(in: 0...1) < 0.52
                if made {
                    comboCount += 1
                    comboMultiplier = min(4, 1 + comboCount / 3)
                    let pts = 2 * comboMultiplier
                    withAnimation(.spring(response: 0.3)) {
                        playerTeamScore = min(playerTeamScore + pts, 99)
                    }
                    lastPasser = teammateNames[teammate - 1]
                    flashResult(.assist)
                } else {
                    flashResult(.miss)
                }
                possession = .opponent
                activePasser = 0
                resetShotClock()
                lastActionLabel = ""

                if playerTeamScore >= targetScore {
                    endGame()
                    return
                }
                scheduleOpponentAttack()
            }
        }
    }

    private func flashResult(_ result: v3ShotResult) {
        lastResult = result
        withAnimation(.spring(response: 0.2)) { showResultLabel = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { showResultLabel = false }
            }
        }
    }

    // Opponent AI attack
    private func scheduleOpponentAttack() {
        opponentTask?.cancel()
        guard phase == .playing else { return }
        let delay = Double.random(in: aiAttackDelayLow...aiAttackDelayHigh)
        opponentTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase == .playing else { return }
                let made = Double.random(in: 0...1) < aiShotChance
                if made {
                    withAnimation(.spring(response: 0.3)) {
                        opponentTeamScore = min(opponentTeamScore + 2, 99)
                    }
                }
                possession = .player
                activePasser = 0
                resetShotClock()
                lastActionLabel = ""

                if opponentTeamScore >= targetScore {
                    endGame()
                }
            }
        }
    }

    // Match clock (2-minute countdown)
    private func startMatchClock() {
        matchClockTask?.cancel()
        matchClockTask = Task {
            while matchClock > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { matchClock -= 1 }
            }
            await MainActor.run { timeExpired() }
        }
    }

    private func timeExpired() {
        guard phase == .playing else { return }
        endGame()
    }

    // Shot clock
    private func resetShotClock() {
        shotClockTask?.cancel()
        shotClock = 24
        shotClockTask = Task {
            while shotClock > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { shotClock -= 1 }
            }
            await MainActor.run { shotClockViolation() }
        }
    }

    private func shotClockViolation() {
        guard phase == .playing else { return }
        if possession == .player {
            comboCount = 0
            comboMultiplier = 1
            possession = .opponent
            activePasser = 0
            scheduleOpponentAttack()
        } else {
            possession = .player
            activePasser = 0
        }
        resetShotClock()
    }

    private func endGame() {
        cancelAllTasks()
        withAnimation(.spring(response: 0.4)) {
            phase = .result
        }
    }

    private func cancelAllTasks() {
        matchClockTask?.cancel()
        shotClockTask?.cancel()
        opponentTask?.cancel()
        matchClockTask = nil
        shotClockTask = nil
        opponentTask = nil
    }
}
