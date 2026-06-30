import SwiftUI

// MARK: - Touch Phase

private enum VBTouchPhase {
    case pass, set, spike
}

// MARK: - Rally State

private enum VBRallyState {
    case idle
    case ballIncoming
    case awaitingPass
    case awaitingSet
    case awaitingSpike
    case ballCrossing
    case opponentDig
    case opponentHitting
}

// MARK: - Game Phase

private enum VBPhase {
    case ready, playing, result
}

// MARK: - Ball Arc Position

private struct VBBall {
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)   // normalised 0-1
    var isVisible: Bool = true
}

// MARK: - VolleyballGameView

struct VolleyballGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // MARK: Phase & Timer
    @State private var phase: VBPhase = .ready
    @State private var timeLeft: Int = 90          // 90-second match
    @State private var gameTimerTask: Task<Void, Never>? = nil

    // MARK: Scores & Streaks
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var rallyStreak: Int = 0
    @State private var bestStreak: Int = 0

    // MARK: Rally Logic
    @State private var rallyState: VBRallyState = .idle
    @State private var touchPhase: VBTouchPhase = .pass
    @State private var ball: VBBall = VBBall()
    @State private var rallyTask: Task<Void, Never>? = nil
    @State private var inputWindowTask: Task<Void, Never>? = nil
    @State private var inputWindowOpen: Bool = false

    // MARK: Feedback
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var showAce: Bool = false
    @State private var touchHighlight: VBTouchPhase? = nil

    // MARK: XP / Shards
    private let XP_CAP_PER_SESSION = 500

    // MARK: UI Constants
    private let accentColor = Color(red: 0.98, green: 0.75, blue: 0.14)
    private let sandColor   = Color(red: 0.76, green: 0.63, blue: 0.42)
    private let skyBlue     = Color(red: 0.29, green: 0.64, blue: 0.90)
    private let opponentName = "Kai Nexus"

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.12), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Beach Volleyball",
                    subtitle: "90-Second Match · Pass · Set · Spike",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startMatch() }
                )

            case .playing:
                playingView

            case .result:
                resultView
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
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { cancelAllTasks() }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                // Player score
                VStack(spacing: 2) {
                    Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                    Text("\(playerScore)")
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .shadow(color: accentColor.opacity(0.4), radius: 8)
                }

                Spacer()

                // Clock + streak
                VStack(spacing: 4) {
                    Text(clockString)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(timeLeft <= 15 ? .red : accentColor)
                    if rallyStreak >= 2 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").font(.system(size: 10)).foregroundStyle(.orange)
                            Text("×\(rallyStreak)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    Text("RALLY STREAK")
                        .font(.system(size: 6, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }

                Spacer()

                // Opponent score
                VStack(spacing: 2) {
                    Text(opponentName.uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                    Text("\(opponentScore)")
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 24)
            .animation(.spring(response: 0.3), value: rallyStreak)

            Rectangle()
                .fill(accentColor.opacity(0.25))
                .frame(height: 1)
                .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    // MARK: - Court View

    private var courtView: some View {
        GeometryReader { geo in
            ZStack {
                // Sky gradient (top half)
                LinearGradient(colors: [skyBlue.opacity(0.7), sandColor.opacity(0.2)],
                               startPoint: .top, endPoint: .bottom)
                    .clipShape(.rect(cornerRadius: 12))

                // Sand (bottom half)
                RoundedRectangle(cornerRadius: 12)
                    .fill(sandColor.opacity(0.45))
                    .frame(height: geo.size.height * 0.45)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // Net post left
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3, height: 28)
                    .offset(x: -(geo.size.width * 0.42), y: 0)

                // Net post right
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3, height: 28)
                    .offset(x: geo.size.width * 0.42, y: 0)

                // Net
                Rectangle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: geo.size.width * 0.84, height: 3)

                // Net mesh hint
                ForEach(0..<8) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 1, height: 20)
                        .offset(x: CGFloat(i - 3) * (geo.size.width * 0.84 / 8), y: 0)
                }

                // Court boundary
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Zone labels
                VStack {
                    Text(opponentName.uppercased())
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(2)
                        .padding(.top, 8)
                    Spacer()
                    Text("YOUR SIDE")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(2)
                        .padding(.bottom, 8)
                }

                // Ball
                if ball.isVisible {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .shadow(color: Color.white.opacity(0.6), radius: 5)

                        Circle()
                            .stroke(Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.6), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                    }
                    .position(
                        x: ball.position.x * geo.size.width,
                        y: ball.position.y * geo.size.height
                    )
                    .animation(.easeInOut(duration: 0.5), value: ball.position)
                }
            }
        }
        .frame(height: 220)
        .padding(.horizontal, 20)
    }

    // MARK: - Touch Prompt Row

    private var touchPromptRow: some View {
        HStack(spacing: 0) {
            ForEach([VBTouchPhase.pass, .set, .spike], id: \.self) { tp in
                let isActive = touchPhase == tp && inputWindowOpen
                let isPast = touchPhasePast(tp)

                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(isActive ? accentColor : (isPast ? Theme.foundationGreen.opacity(0.3) : Color.white.opacity(0.05)))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(isActive ? accentColor : (isPast ? Theme.foundationGreen : Color.white.opacity(0.1)), lineWidth: 2)
                            )
                            .scaleEffect(isActive ? 1.12 : 1.0)
                            .animation(.spring(response: 0.25), value: isActive)

                        Image(systemName: touchPhaseIcon(tp))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isActive ? .black : (isPast ? Theme.foundationGreen : .white.opacity(0.35)))
                    }

                    Text(touchPhaseLabel(tp).uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(isActive ? accentColor : .secondary)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Playing View

    private var playingView: some View {
        ZStack {
            VStack(spacing: 0) {
                scoreHeader

                Spacer()

                courtView

                Spacer().frame(height: 20)

                touchPromptRow

                Spacer().frame(height: 16)

                // Action hint
                VStack(spacing: 6) {
                    if inputWindowOpen {
                        actionButton
                    } else {
                        Text(rallyStateHint)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 60)
                .animation(.easeInOut(duration: 0.15), value: inputWindowOpen)

                Spacer()
            }

            // Feedback flash
            if showFeedback {
                Text(feedbackText)
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(feedbackText.contains("ACE") ? accentColor : (feedbackText.contains("DIG") || feedbackText.contains("PASS") || feedbackText.contains("SET") || feedbackText.contains("SPIKE") ? Theme.foundationGreen : .red))
                    .shadow(color: accentColor.opacity(0.5), radius: 12)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            // ACE overlay
            if showAce {
                VStack(spacing: 8) {
                    Text("ACE!")
                        .font(.system(size: 52, weight: .black, design: .monospaced))
                        .italic()
                        .foregroundStyle(accentColor)
                        .shadow(color: accentColor.opacity(0.7), radius: 20)
                    Text("Unreturnable spike!")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Action Button (tap / swipe target)

    private var actionButton: some View {
        Group {
            switch touchPhase {
            case .pass:
                Button {
                    handlePlayerInput()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill").font(.system(size: 16))
                        Text("TAP — PASS")
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(accentColor)
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: accentColor.opacity(0.4), radius: 8)
                }
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))

            case .set:
                Button {
                    handlePlayerInput()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill").font(.system(size: 16))
                        Text("TAP — SET")
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.brandCyan)
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: Theme.brandCyan.opacity(0.4), radius: 8)
                }
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))

            case .spike:
                // Swipe-down gesture area
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.4), lineWidth: 2))
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 18)).foregroundStyle(.red)
                        Text("SWIPE DOWN — SPIKE")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }
                .frame(height: 54)
                .padding(.horizontal, 40)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let dy = value.location.y - value.startLocation.y
                            if dy > 25 { handlePlayerInput() }
                        }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Helper Labels

    private var rallyStateHint: String {
        switch rallyState {
        case .idle:             return "Starting rally…"
        case .ballIncoming:     return "Ball incoming…"
        case .awaitingPass:     return "Get ready to pass!"
        case .awaitingSet:      return "Ball is up — set it!"
        case .awaitingSpike:    return "Position for spike…"
        case .ballCrossing:     return "Ball over the net!"
        case .opponentDig:      return "Opponent digs it!"
        case .opponentHitting:  return "Opponent attacking…"
        }
    }

    private func touchPhaseIcon(_ tp: VBTouchPhase) -> String {
        switch tp {
        case .pass:  return "hand.raised.fill"
        case .set:   return "arrow.up.circle.fill"
        case .spike: return "bolt.fill"
        }
    }

    private func touchPhaseLabel(_ tp: VBTouchPhase) -> String {
        switch tp {
        case .pass:  return "Pass"
        case .set:   return "Set"
        case .spike: return "Spike"
        }
    }

    private func touchPhasePast(_ tp: VBTouchPhase) -> Bool {
        switch tp {
        case .pass:  return touchPhase == .set || touchPhase == .spike
        case .set:   return touchPhase == .spike
        case .spike: return false
        }
    }

    // MARK: - Clock

    private var clockString: String {
        let m = timeLeft / 60
        let s = timeLeft % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Match Logic

    private func startMatch() {
        phase = .playing
        startGameTimer()
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { beginRally() }
        }
    }

    private func startGameTimer() {
        gameTimerTask?.cancel()
        gameTimerTask = Task {
            while timeLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeLeft -= 1 }
            }
            await MainActor.run { endMatch() }
        }
    }

    // MARK: Rally Sequence

    private func beginRally() {
        guard phase == .playing else { return }
        touchPhase = .pass
        rallyState = .ballIncoming
        inputWindowOpen = false

        // Ball starts on opponent side
        withAnimation {
            ball.position = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: 0.18)
            ball.isVisible = true
        }

        Task {
            // Arc ball to player side
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                let landX = CGFloat.random(in: 0.25...0.75)
                withAnimation(.easeInOut(duration: 0.55)) {
                    ball.position = CGPoint(x: landX, y: 0.78)
                }
                rallyState = .awaitingPass
            }

            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                openInputWindow()
            }
        }
    }

    private func openInputWindow() {
        guard phase == .playing else { return }
        inputWindowOpen = true
        inputWindowTask?.cancel()
        inputWindowTask = Task {
            // 1.5s window for each touch
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if inputWindowOpen {
                    inputWindowOpen = false
                    // Missed
                    flashFeedback("MISSED!")
                    opponentWinsPoint()
                }
            }
        }
    }

    private func handlePlayerInput() {
        guard inputWindowOpen, phase == .playing else { return }
        inputWindowTask?.cancel()
        inputWindowOpen = false

        switch touchPhase {
        case .pass:
            flashFeedback("PASS!")
            advanceBall(toY: 0.55)
            rallyState = .awaitingSet
            touchPhase = .set
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run { openInputWindow() }
            }

        case .set:
            flashFeedback("SET!")
            advanceBall(toY: 0.42)
            rallyState = .awaitingSpike
            touchPhase = .spike
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run { openInputWindow() }
            }

        case .spike:
            executSpike()
        }
    }

    private func advanceBall(toY: CGFloat) {
        let x = CGFloat.random(in: 0.3...0.7)
        withAnimation(.easeOut(duration: 0.35)) {
            ball.position = CGPoint(x: x, y: toY)
        }
    }

    private func executSpike() {
        flashFeedback("SPIKE!")
        let spikeX = CGFloat.random(in: 0.2...0.8)

        // Ball arcs over net
        withAnimation(.easeIn(duration: 0.4)) {
            ball.position = CGPoint(x: spikeX, y: 0.25)
        }

        rallyState = .ballCrossing

        Task {
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                let prq = viewModel.effectiveMetrics.prqScore
                let digChance = 0.3 + (prq / 200.0)  // higher PRQ = harder opponent
                let opponentDigs = Double.random(in: 0...1) < digChance

                if opponentDigs {
                    rallyState = .opponentDig
                    withAnimation(.easeOut(duration: 0.35)) {
                        ball.position = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: 0.18)
                    }
                    flashFeedback("DIG!")
                    Task {
                        try? await Task.sleep(for: .milliseconds(800))
                        await MainActor.run { opponentCounter() }
                    }
                } else {
                    // Unreturnable spike — ACE
                    withAnimation(.easeIn(duration: 0.3)) {
                        ball.position = CGPoint(x: spikeX, y: 0.12)
                    }
                    playerScores(ace: true)
                }
            }
        }
    }

    private func opponentCounter() {
        guard phase == .playing else { return }
        rallyState = .opponentHitting

        Task {
            let delay = Double.random(in: 0.5...1.1)
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run {
                guard phase == .playing else { return }
                // Opponent hits back — start a new rally
                beginRally()
            }
        }
    }

    private func playerScores(ace: Bool) {
        withAnimation { playerScore += 1 }
        rallyStreak += 1
        if rallyStreak > bestStreak { bestStreak = rallyStreak }

        if ace {
            withAnimation(.spring(response: 0.25)) { showAce = true }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) { showAce = false }
                    scheduleNextRally()
                }
            }
        } else {
            scheduleNextRally()
        }
    }

    private func opponentWinsPoint() {
        withAnimation { opponentScore += 1 }
        rallyStreak = 0
        scheduleNextRally()
    }

    private func scheduleNextRally() {
        Task {
            try? await Task.sleep(for: .milliseconds(1000))
            await MainActor.run {
                guard phase == .playing else { return }
                beginRally()
            }
        }
    }

    private func endMatch() {
        cancelAllTasks()
        withAnimation(.spring(response: 0.4)) { phase = .result }
    }

    // MARK: - Feedback Flash

    private func flashFeedback(_ text: String) {
        feedbackText = text
        withAnimation(.spring(response: 0.2)) { showFeedback = true }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) { showFeedback = false }
            }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        let playerWon = playerScore > opponentScore
        let isDraw = playerScore == opponentScore
        let shards = isDraw ? 25 : (playerWon ? 50 : 15)
        return ResultScreen(
            winner: isDraw ? .draw : (playerWon ? .p1 : .p2),
            p1Score: playerScore,
            p2Score: opponentScore,
            title: "Beach Volleyball",
            accentColor: accentColor,
            prqGain: playerWon ? 10 : (isDraw ? 5 : 2),
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "Spike",
            modeAttributeValue: playerScore > 0 ? Double(playerScore) / Double(max(1, playerScore + opponentScore)) : 0,
            onReturn: {
                viewModel.profile.evolutionShards += shards
                dismiss()
            }
        )
    }

    // MARK: - Cleanup

    private func cancelAllTasks() {
        gameTimerTask?.cancel()
        rallyTask?.cancel()
        inputWindowTask?.cancel()
    }
}
