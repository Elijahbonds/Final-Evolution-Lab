import SwiftUI

// MARK: - Tennis Score

private enum TennisPoint: Int, CaseIterable {
    case zero = 0, fifteen = 15, thirty = 30, forty = 40

    var display: String {
        switch self {
        case .zero:    return "0"
        case .fifteen: return "15"
        case .thirty:  return "30"
        case .forty:   return "40"
        }
    }

    var next: TennisPoint? {
        switch self {
        case .zero:    return .fifteen
        case .fifteen: return .thirty
        case .thirty:  return .forty
        case .forty:   return nil  // game point
        }
    }
}

// MARK: - Phase

private enum TennisPhase {
    case ready, serving, rally, result
}

// MARK: - Swipe Direction

private enum SwipeDir {
    case left, right, up, none
}

// MARK: - Ball State

private struct TennisBall {
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)   // normalised 0-1
    var targetX: CGFloat = 0.5
    var targetY: CGFloat = 0.5
    var isAnimating: Bool = false
    var fromOpponent: Bool = true
}

// MARK: - TennisGameView

struct TennisGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // MARK: Phase & Timing
    @State private var phase: TennisPhase = .ready
    @State private var timeLeft: Int = 120          // 2-minute match
    @State private var gameTimerTask: Task<Void, Never>? = nil

    // MARK: Scores
    @State private var playerGames: Int = 0
    @State private var opponentGames: Int = 0
    @State private var playerPoints: TennisPoint = .zero
    @State private var opponentPoints: TennisPoint = .zero
    @State private var playerSets: Int = 0
    @State private var opponentSets: Int = 0

    // MARK: Rally State
    @State private var ball: TennisBall = TennisBall()
    @State private var rallyTask: Task<Void, Never>? = nil
    @State private var awaitingSwipe: Bool = false
    @State private var swipeWindowOpen: Bool = false
    @State private var swipeWindowTask: Task<Void, Never>? = nil
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var isServing: Bool = true
    @State private var serveReady: Bool = false
    @State private var serveAnimating: Bool = false
    @State private var ballScale: CGFloat = 1.0
    @State private var ballOpacity: Double = 1.0

    // MARK: Gesture
    @State private var dragStart: CGPoint? = nil

    // MARK: XP / Shards
    private let XP_CAP_PER_SESSION = 500
    @State private var sessionXP: Int = 0

    // MARK: Constants
    private let accentColor = Color(red: 0.85, green: 0.75, blue: 0.1)
    private let courtGreen = Color(red: 0.1, green: 0.48, blue: 0.18)
    private let opponentName = "Kai Nexus"

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.06, blue: 0.02), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Rally Ace",
                    subtitle: "2-Minute Tennis Match · Swipe to return",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startMatch() }
                )

            case .serving:
                servingView

            case .rally:
                rallyView

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
            HStack {
                VStack(spacing: 2) {
                    Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                    Text(playerPoints.display)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(clockString).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(timeLeft <= 20 ? .red : accentColor)
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(i < playerSets ? accentColor : Color.white.opacity(0.12))
                                .frame(width: 7, height: 7)
                        }
                        Text("VS").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(i < opponentSets ? Color.red : Color.white.opacity(0.12))
                                .frame(width: 7, height: 7)
                        }
                    }
                    HStack(spacing: 8) {
                        Text("\(playerGames)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
                        Text("GAMES").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                        Text("\(opponentGames)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.red)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(opponentName.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                    Text(opponentPoints.display)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 24)

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
                // Court background
                RoundedRectangle(cornerRadius: 12)
                    .fill(courtGreen)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))

                // Net
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: geo.size.width - 24, height: 3)
                    .offset(y: 0)

                // Court lines
                Group {
                    // Singles sidelines
                    Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1.5, height: geo.size.height - 16)
                        .offset(x: -(geo.size.width * 0.32))
                    Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1.5, height: geo.size.height - 16)
                        .offset(x: geo.size.width * 0.32)
                    // Service boxes
                    Rectangle().fill(Color.white.opacity(0.3)).frame(width: geo.size.width * 0.65, height: 1)
                        .offset(y: -(geo.size.height * 0.22))
                    Rectangle().fill(Color.white.opacity(0.3)).frame(width: geo.size.width * 0.65, height: 1)
                        .offset(y: geo.size.height * 0.22)
                    // Centre service line
                    Rectangle().fill(Color.white.opacity(0.3)).frame(width: 1, height: geo.size.height * 0.44)
                }

                // Zone labels
                VStack {
                    Text("OPP").font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35)).tracking(2)
                    Spacer()
                    Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35)).tracking(2)
                }
                .padding(.vertical, 10)

                // Ball
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.yellow.opacity(0.6), radius: 4)
                    .scaleEffect(ballScale)
                    .opacity(ballOpacity)
                    .position(
                        x: ball.position.x * geo.size.width,
                        y: ball.position.y * geo.size.height
                    )
                    .animation(.easeInOut(duration: 0.55), value: ball.position)

                // Swipe zone highlight
                if swipeWindowOpen {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentColor.opacity(0.6), lineWidth: 2)
                        .frame(width: geo.size.width * 0.65, height: geo.size.height * 0.28)
                        .offset(y: geo.size.height * 0.3)
                        .transition(.opacity)
                }
            }
        }
        .frame(height: 240)
        .padding(.horizontal, 20)
    }

    // MARK: - Serving View

    private var servingView: some View {
        VStack(spacing: 0) {
            scoreHeader
            Spacer()
            courtView
            Spacer()

            VStack(spacing: 16) {
                Text("SERVE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(4)

                Text("Tap to toss, then swipe up to serve")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if serveReady && !serveAnimating {
                    Button {
                        launchServe()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 16))
                            Text("SERVE")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)
                } else if !serveReady {
                    Button {
                        tossBall()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill").font(.system(size: 16))
                            Text("TOSS")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)
                } else {
                    Text("Tossing…")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Rally View

    private var rallyView: some View {
        ZStack {
            VStack(spacing: 0) {
                scoreHeader
                Spacer()
                courtView
                Spacer()

                VStack(spacing: 12) {
                    if swipeWindowOpen {
                        Text("SWIPE TO RETURN!")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .tracking(2)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Watch the ball…")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 60)
                .animation(.easeInOut(duration: 0.2), value: swipeWindowOpen)
                .padding(.bottom, 20)
            }

            // Invisible gesture overlay — whole screen
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            if dragStart == nil { dragStart = value.startLocation }
                        }
                        .onEnded { value in
                            defer { dragStart = nil }
                            guard swipeWindowOpen else { return }
                            let dir = detectSwipe(from: value.startLocation, to: value.location)
                            handlePlayerSwipe(dir)
                        }
                )

            // Feedback flash
            if showFeedback {
                Text(feedbackText)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(feedbackText == "ACE!" || feedbackText == "WINNER!" ? accentColor : .red)
                    .shadow(color: accentColor.opacity(0.6), radius: 12)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        let playerWon = playerSets > opponentSets || (playerSets == opponentSets && playerGames > opponentGames)
        let isDraw = playerSets == opponentSets && playerGames == opponentGames
        let shards = isDraw ? 25 : (playerWon ? 50 : 15)
        return ResultScreen(
            winner: isDraw ? .draw : (playerWon ? .p1 : .p2),
            p1Score: playerGames,
            p2Score: opponentGames,
            title: "Rally Ace · Tennis",
            accentColor: accentColor,
            prqGain: playerWon ? 12 : (isDraw ? 6 : 2),
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "Rally",
            modeAttributeValue: playerGames > 0 ? Double(playerGames) / Double(max(1, playerGames + opponentGames)) : 0,
            onReturn: {
                viewModel.profile.evolutionShards += shards
                dismiss()
            }
        )
    }

    // MARK: - Clock

    private var clockString: String {
        let m = timeLeft / 60
        let s = timeLeft % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Match Logic

    private func startMatch() {
        ball.position = CGPoint(x: 0.5, y: 0.8)
        isServing = true
        serveReady = false
        serveAnimating = false
        phase = .serving
        startGameTimer()
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

    private func tossBall() {
        serveAnimating = true
        withAnimation(.easeOut(duration: 0.4)) {
            ball.position = CGPoint(x: 0.5, y: 0.62)
            ballScale = 0.8
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                serveAnimating = false
                serveReady = true
                withAnimation(.spring(response: 0.2)) { ballScale = 1.2 }
            }
        }
    }

    private func launchServe() {
        serveReady = false
        serveAnimating = true
        let dir: CGFloat = Bool.random() ? -0.2 : 0.2
        withAnimation(.easeIn(duration: 0.5)) {
            ball.position = CGPoint(x: 0.5 + dir, y: 0.18)
            ballScale = 0.75
        }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                phase = .rally
                beginRally(fromOpponent: false)
            }
        }
    }

    private func beginRally(fromOpponent: Bool) {
        rallyTask?.cancel()
        awaitingSwipe = false
        swipeWindowOpen = false

        rallyTask = Task {
            // Ball travels from opponent side to player side (or vice versa)
            let targetX = CGFloat.random(in: 0.25...0.75)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) {
                    ball.position = fromOpponent
                        ? CGPoint(x: targetX, y: 0.75)
                        : CGPoint(x: targetX, y: 0.22)
                    ballScale = fromOpponent ? 1.0 : 0.7
                }
            }

            if fromOpponent {
                // Ball arriving from opponent — open swipe window after travel
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation { swipeWindowOpen = true }
                    awaitingSwipe = true
                    openSwipeWindow()
                }
            } else {
                // Player served/hit, wait for opponent AI to respond
                let delay = Double.random(in: 0.8...1.4)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await MainActor.run { opponentResponds() }
            }
        }
    }

    private func openSwipeWindow() {
        swipeWindowTask?.cancel()
        swipeWindowTask = Task {
            // 1.5s window
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if awaitingSwipe {
                    // Missed the ball
                    awaitingSwipe = false
                    swipeWindowOpen = false
                    flashFeedback("MISS!")
                    opponentWinsPoint()
                }
            }
        }
    }

    private func handlePlayerSwipe(_ dir: SwipeDir) {
        guard awaitingSwipe else { return }
        awaitingSwipe = false
        swipeWindowOpen = false
        swipeWindowTask?.cancel()

        let isPerfect = dir != .none
        if isPerfect {
            flashFeedback(Bool.random() ? "WINNER!" : "GREAT SHOT!")
            // Ball crosses to opponent
            let shotX = dir == .left ? CGFloat.random(in: 0.15...0.4) : CGFloat.random(in: 0.6...0.85)
            withAnimation(.easeIn(duration: 0.45)) {
                ball.position = CGPoint(x: shotX, y: 0.15)
                ballScale = 0.7
            }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run { beginRally(fromOpponent: false) }
            }
        } else {
            flashFeedback("MISS!")
            opponentWinsPoint()
        }
    }

    private func opponentResponds() {
        let prq = viewModel.effectiveMetrics.prqScore
        let returnChance = 0.45 + (prq / 200.0)   // higher PRQ → harder opponent
        let opponentReturns = Double.random(in: 0...1) < returnChance

        if opponentReturns {
            beginRally(fromOpponent: true)
        } else {
            // Opponent misses
            flashFeedback("ACE!")
            playerWinsPoint()
        }
    }

    private func playerWinsPoint() {
        withAnimation {
            if playerPoints == .forty {
                playerWinsGame()
            } else {
                playerPoints = playerPoints.next ?? .zero
            }
        }
        scheduleNextRallyOrServe(playerServes: false)
    }

    private func opponentWinsPoint() {
        withAnimation {
            if opponentPoints == .forty {
                opponentWinsGame()
            } else {
                opponentPoints = opponentPoints.next ?? .zero
            }
        }
        scheduleNextRallyOrServe(playerServes: true)
    }

    private func playerWinsGame() {
        playerPoints = .zero
        opponentPoints = .zero
        playerGames += 1
        if playerGames >= 6 && playerGames - opponentGames >= 2 {
            playerWinsSet()
        }
    }

    private func opponentWinsGame() {
        playerPoints = .zero
        opponentPoints = .zero
        opponentGames += 1
        if opponentGames >= 6 && opponentGames - playerGames >= 2 {
            opponentWinsSet()
        }
    }

    private func playerWinsSet() {
        playerGames = 0
        opponentGames = 0
        playerSets += 1
        if playerSets >= 2 { endMatch() }
    }

    private func opponentWinsSet() {
        playerGames = 0
        opponentGames = 0
        opponentSets += 1
        if opponentSets >= 2 { endMatch() }
    }

    private func scheduleNextRallyOrServe(playerServes: Bool) {
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run {
                guard phase == .rally || phase == .serving else { return }
                isServing = true
                serveReady = false
                serveAnimating = false
                ball.position = playerServes ? CGPoint(x: 0.5, y: 0.82) : CGPoint(x: 0.5, y: 0.18)
                phase = .serving
            }
        }
    }

    private func endMatch() {
        cancelAllTasks()
        withAnimation(.spring(response: 0.4)) { phase = .result }
    }

    // MARK: - Swipe Detection

    private func detectSwipe(from start: CGPoint, to end: CGPoint) -> SwipeDir {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let threshold: CGFloat = 20
        if abs(dx) > abs(dy) && abs(dx) > threshold {
            return dx < 0 ? .left : .right
        } else if dy < -threshold {
            return .up
        }
        return .none
    }

    // MARK: - Feedback Flash

    private func flashFeedback(_ text: String) {
        feedbackText = text
        withAnimation(.spring(response: 0.2)) { showFeedback = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { showFeedback = false }
            }
        }
    }

    // MARK: - Cleanup

    private func cancelAllTasks() {
        gameTimerTask?.cancel()
        rallyTask?.cancel()
        swipeWindowTask?.cancel()
    }
}
