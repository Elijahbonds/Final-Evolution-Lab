import SwiftUI

// MARK: - Phase

private enum H2HPhase {
    case ready, playing, result
}

// MARK: - Shot Result

private enum ShotResult: String {
    case made = "MADE"
    case blocked = "BLOCKED"
    case miss = "MISS"
}

// MARK: - Possession

private enum H2HPossession {
    case player, opponent
}

// MARK: - Main View

struct BasketballH2HGameView: View {
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss

    // Game phase
    @State private var phase: H2HPhase = .ready

    // Scores
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0

    // Shot clock
    @State private var shotClock: Int = 24
    @State private var shotClockTask: Task<Void, Never>? = nil

    // Opponent AI task
    @State private var opponentTask: Task<Void, Never>? = nil

    // Combo
    @State private var comboCount: Int = 0
    @State private var comboMultiplier: Int = 1

    // Input feedback
    @State private var lastShotResult: ShotResult? = nil
    @State private var showShotLabel: Bool = false
    @State private var lastActionLabel: String = ""

    // Possession
    @State private var possession: H2HPossession = .player

    // Shard reward tracking
    @State private var shardsRewarded: Bool = false

    private let winTarget = 21
    private let accentColor = Color(red: 1.0, green: 0.6, blue: 0.0)

    // AI difficulty — scales with PRQ
    private var aiShotChance: Double {
        let prq = viewModel.effectiveMetrics.prqScore
        // PRQ 0 → ~25% chance, PRQ 100 → ~72% chance
        return 0.25 + (prq / 100.0) * 0.47
    }

    private var aiShotDelayLow: Double {
        3.0 + (1 - viewModel.effectiveMetrics.prqScore / 100.0) * 2.0
    }

    private var aiShotDelayHigh: Double {
        aiShotDelayLow + 1.5
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.04, blue: 0.0), Theme.deepBlack],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Street 1v1",
                    subtitle: "First to 21 wins · Street rules",
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
            scoreHeader
                .padding(.horizontal, 20)
                .padding(.top, 8)

            shotClockBar
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

    // MARK: - Score Header

    private var scoreHeader: some View {
        HStack(alignment: .top) {
            // Player score
            VStack(spacing: 2) {
                Text("YOU")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(2)
                Text("\(playerScore)")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Possession + target
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    if possession == .player {
                        Image(systemName: "arrowtriangle.right.fill")
                            .foregroundStyle(accentColor)
                    } else {
                        Image(systemName: "arrowtriangle.left.fill")
                            .foregroundStyle(.red)
                    }
                    Text(possession == .player ? "YOUR BALL" : "OPP BALL")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(possession == .player ? accentColor : .red)
                }
                Text("TO 21")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)

            // Opponent score
            VStack(spacing: 2) {
                Text("OPP")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(opponentScore)")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Shot Clock Bar

    private var shotClockBar: some View {
        GeometryReader { geo in
            HStack(spacing: 10) {
                Text("SHOT")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                    .frame(width: 32)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    let barWidth = max(0, geo.size.width - 72)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(shotClock > 8 ? accentColor : .red)
                        .frame(width: CGFloat(shotClock) / 24.0 * barWidth, height: 6)
                        .animation(.linear(duration: 0.5), value: shotClock)
                }

                Text("\(shotClock)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(shotClock > 8 ? .white : .red)
                    .contentTransition(.numericText())
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .frame(height: 22)
    }

    // MARK: - Court Zone

    private var courtZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            // Arc visuals
            Circle()
                .stroke(accentColor.opacity(0.08), lineWidth: 2)
                .frame(width: 180, height: 180)

            Circle()
                .stroke(accentColor.opacity(0.15), lineWidth: 1.5)
                .frame(width: 80, height: 80)

            VStack(spacing: 10) {
                // Hoop icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "figure.basketball")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(accentColor)
                }

                if showShotLabel, let result = lastShotResult {
                    Text(result.rawValue)
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(result == .made ? accentColor : (result == .blocked ? .red : .secondary))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: showShotLabel)
                }

                if !lastActionLabel.isEmpty {
                    Text(lastActionLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(2)
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
                        .foregroundStyle(.orange)
                    Text("x\(comboMultiplier) COMBO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("(\(comboCount) makes)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .clipShape(.rect(cornerRadius: 10))
                .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "basketball.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accentColor.opacity(0.4))
                    Text("TAP SHOOT · SWIPE ← CROSSOVER · SWIPE ↗ DRIVE")
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
                playerAttemptShoot()
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
                        ? LinearGradient(colors: [accentColor, accentColor.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: possession == .player ? accentColor.opacity(0.35) : .clear, radius: 12)
            }
            .disabled(possession != .player || phase != .playing)

            // Move buttons
            HStack(spacing: 12) {
                Button {
                    guard phase == .playing, possession == .player else { return }
                    playerAttemptMove(action: "CROSSOVER")
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 14, weight: .bold))
                        Text("CROSSOVER")
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
                    playerAttemptMove(action: "DRIVE")
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 14, weight: .bold))
                        Text("DRIVE")
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
        let playerWon = playerScore >= winTarget
        let didTie = !playerWon && opponentScore < winTarget
        let winner: ResultScreen.ResultWinner = playerWon ? .p1 : (didTie ? .draw : .p2)
        let prqGain = PRQ.modeReward(
            mode: .basketballHeadToHead,
            won: playerWon,
            tied: didTie,
            combo: comboCount,
            criticals: comboCount / 3,
            scoreDifferential: playerScore - opponentScore
        )
        return ResultScreen(
            winner: winner,
            p1Score: playerScore,
            p2Score: opponentScore,
            title: "Street 1v1",
            accentColor: accentColor,
            prqGain: prqGain,
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "Court IQ",
            modeAttributeValue: PRQ.attributeValue(prq: viewModel.effectiveMetrics.prqScore, for: .basketballHeadToHead),
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
        playerScore = 0
        opponentScore = 0
        comboCount = 0
        comboMultiplier = 1
        possession = .player
        lastShotResult = nil
        showShotLabel = false
        lastActionLabel = ""
        shardsRewarded = false
        phase = .playing
        resetShotClock()
        scheduleOpponentShot()
    }

    // Player shoot attempt
    private func playerAttemptShoot() {
        guard phase == .playing, possession == .player else { return }
        shotClockTask?.cancel()
        lastActionLabel = "SHOOT"

        let prq = viewModel.effectiveMetrics.prqScore
        let baseChance = 0.45 + (prq / 100.0) * 0.30
        let hitChance = min(0.85, baseChance + Double(comboCount) * 0.02)
        let made = Double.random(in: 0...1) < hitChance

        if made {
            comboCount += 1
            comboMultiplier = min(4, 1 + comboCount / 3)
            let pts = 2 * comboMultiplier
            withAnimation(.spring(response: 0.3)) {
                playerScore = min(playerScore + pts, 99)
            }
            flashShotResult(.made)
        } else {
            comboCount = 0
            comboMultiplier = 1
            flashShotResult(.miss)
        }

        // Turnover
        possession = .opponent
        resetShotClock()

        if playerScore >= winTarget {
            endGame()
            return
        }

        scheduleOpponentShot()
    }

    private func playerAttemptMove(action: String) {
        guard phase == .playing, possession == .player else { return }
        lastActionLabel = action
        let succeeded = Double.random(in: 0...1) < 0.65
        if succeeded {
            lastActionLabel = "\(action) ✓"
            // Successful move keeps possession — slight combo bump
        } else {
            flashShotResult(.blocked)
            possession = .opponent
            comboCount = 0
            comboMultiplier = 1
            resetShotClock()
            scheduleOpponentShot()
        }
    }

    private func flashShotResult(_ result: ShotResult) {
        lastShotResult = result
        withAnimation(.spring(response: 0.2)) { showShotLabel = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { showShotLabel = false }
            }
        }
    }

    // Opponent AI
    private func scheduleOpponentShot() {
        opponentTask?.cancel()
        guard phase == .playing else { return }
        let delay = Double.random(in: aiShotDelayLow...aiShotDelayHigh)
        opponentTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase == .playing else { return }
                let made = Double.random(in: 0...1) < aiShotChance
                if made {
                    withAnimation(.spring(response: 0.3)) {
                        opponentScore = min(opponentScore + 2, 99)
                    }
                }
                possession = .player
                resetShotClock()

                if opponentScore >= winTarget {
                    endGame()
                }
            }
        }
    }

    // Shot clock countdown
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
            scheduleOpponentShot()
        } else {
            possession = .player
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
        shotClockTask?.cancel()
        opponentTask?.cancel()
        shotClockTask = nil
        opponentTask = nil
    }
}
