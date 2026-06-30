import SwiftUI

// MARK: - Phase

private enum BBallPhase {
    case ready, batting, pitching, inningBreak, result
}

// MARK: - Pitch Type

private enum PitchType: String, CaseIterable {
    case fastball = "FASTBALL"
    case curveball = "CURVEBALL"
    case slider = "SLIDER"

    var speed: Double {
        switch self {
        case .fastball:  return 1.6
        case .curveball: return 2.2
        case .slider:    return 1.9
        }
    }

    var curveOffset: CGFloat {
        switch self {
        case .fastball:  return 0
        case .curveball: return -55
        case .slider:    return 45
        }
    }

    var speedLabel: String {
        switch self {
        case .fastball:  return "95 MPH"
        case .curveball: return "78 MPH"
        case .slider:    return "84 MPH"
        }
    }

    var icon: String {
        switch self {
        case .fastball:  return "bolt.fill"
        case .curveball: return "arrow.turn.down.left"
        case .slider:    return "arrow.turn.down.right"
        }
    }
}

// MARK: - Swing Result

private enum SwingResult {
    case homeRun, basehit, foul, miss, none
}

// MARK: - Constants

private let XP_CAP_PER_SESSION = 500
private let INNINGS: Int = 5
private let OUTS_PER_INNING: Int = 3

// MARK: - Main View

struct BaseballGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // Game state
    @State private var phase: BBallPhase = .ready
    @State private var inning: Int = 1
    @State private var isTopHalf: Bool = true  // true = player bats, false = AI bats
    @State private var playerScore: Int = 0
    @State private var aiScore: Int = 0
    @State private var outs: Int = 0
    @State private var currentPitch: PitchType = .fastball
    @State private var swingResult: SwingResult = .none
    @State private var resultLabel: String = ""
    @State private var showResultBanner: Bool = false
    @State private var rewardGranted: Bool = false

    // Pitch animation
    @State private var pitchBallY: CGFloat = 0.05    // 0=top, 1=bottom (relative)
    @State private var pitchBallX: CGFloat = 0.5
    @State private var pitchAnimating: Bool = false
    @State private var pitchTask: Task<Void, Never>? = nil
    @State private var swingWindowOpen: Bool = false
    @State private var zoneHighlight: Bool = false
    @State private var playerSwung: Bool = false

    // AI batting (pitching half)
    @State private var aiAtBatTask: Task<Void, Never>? = nil
    @State private var aiResultLabel: String = ""
    @State private var showAIResult: Bool = false

    // Effects
    @State private var screenShake: CGFloat = 0
    @State private var bannerScale: CGFloat = 0.6

    // Geometry constants
    private let plateY: CGFloat = 0.82
    private let perfectZone: ClosedRange<CGFloat> = 0.70...0.80
    private let goodZone: ClosedRange<CGFloat> = 0.60...0.90
    private let swingZone: ClosedRange<CGFloat> = 0.55...0.92

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.05, blue: 0.15), Theme.deepBlack],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Home Run Derby",
                    subtitle: "5 Innings · Swing for the fences",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { startInning() }
                )
            case .batting:
                battingBody
            case .pitching:
                pitchingBody
            case .inningBreak:
                inningBreakBody
            case .result:
                resultBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    pitchTask?.cancel()
                    aiAtBatTask?.cancel()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear {
            pitchTask?.cancel()
            aiAtBatTask?.cancel()
        }
    }

    // MARK: - HUD

    private var scoreHUD: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("HOME · YOU")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(gameMode.accentColor)
                    .tracking(1)
                Text("\(playerScore)")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("INN \(inning)/\(INNINGS)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(2)
                Text(isTopHalf ? "TOP" : "BTM")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(isTopHalf ? gameMode.accentColor : .red)

                // Out dots
                HStack(spacing: 5) {
                    ForEach(0..<OUTS_PER_INNING, id: \.self) { i in
                        Circle()
                            .fill(i < outs ? Color.red : Color.white.opacity(0.15))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 2)
            }

            VStack(spacing: 2) {
                Text("AWAY · OPP")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.8))
                    .tracking(1)
                Text("\(aiScore)")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Theme.cardBackground)
    }

    // MARK: - Batting Body (Player hits)

    private var battingBody: some View {
        GeometryReader { geo in
            ZStack {
                // Diamond field sketch
                fieldSketch(geo: geo)

                // Zone indicator rings at plate
                if swingWindowOpen {
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(zoneHighlight ? 0.7 : 0.25), lineWidth: 3)
                            .frame(width: 80, height: 80)
                        Circle()
                            .stroke(Color.yellow.opacity(zoneHighlight ? 0.5 : 0.15), lineWidth: 2)
                            .frame(width: 130, height: 130)
                    }
                    .position(x: geo.size.width * 0.5, y: geo.size.height * plateY)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: zoneHighlight)
                }

                // Pitch ball
                if pitchAnimating || playerSwung {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, Color(white: 0.85)],
                                center: .center,
                                startRadius: 1,
                                endRadius: 10
                            )
                        )
                        .frame(width: 22, height: 22)
                        .shadow(color: .white.opacity(0.6), radius: 6)
                        .position(
                            x: geo.size.width * pitchBallX,
                            y: geo.size.height * pitchBallY
                        )
                }

                // HUD overlay at top
                VStack(spacing: 0) {
                    scoreHUD

                    // Pitch type label
                    HStack(spacing: 6) {
                        Image(systemName: currentPitch.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(currentPitch.rawValue)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(currentPitch.speedLabel)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(gameMode.accentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(Theme.cardBackground.opacity(0.8))
                    .clipShape(.rect(cornerRadius: 10))
                    .padding(.top, 8)

                    Spacer()

                    // Swing result banner
                    if showResultBanner {
                        resultBanner
                            .scaleEffect(bannerScale)
                            .padding(.bottom, 100)
                    }

                    Spacer()

                    // Swing instruction
                    if !playerSwung && pitchAnimating {
                        Text("TAP OR SWIPE TO SWING")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(2)
                            .padding(.bottom, 24)
                    } else if !pitchAnimating && !playerSwung {
                        Text("GET READY…")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .tracking(2)
                            .padding(.bottom, 24)
                    }
                }
                .frame(width: geo.size.width)

                // Shake overlay
                if screenShake > 0 {
                    Color.clear
                }
            }
            .offset(x: screenShake > 0 ? CGFloat.random(in: -screenShake...screenShake) : 0)
            .gesture(
                TapGesture()
                    .onEnded { _ in handleSwing() }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { _ in handleSwing() }
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func fieldSketch(geo: GeometryProxy) -> some View {
        let cx = geo.size.width * 0.5
        let plateYPt = geo.size.height * plateY + 12
        let scale = min(geo.size.width, geo.size.height) * 0.35

        ZStack {
            // Infield diamond
            Path { p in
                p.move(to: CGPoint(x: cx, y: plateYPt))
                p.addLine(to: CGPoint(x: cx + scale * 0.5, y: plateYPt - scale * 0.5))
                p.addLine(to: CGPoint(x: cx, y: plateYPt - scale))
                p.addLine(to: CGPoint(x: cx - scale * 0.5, y: plateYPt - scale * 0.5))
                p.closeSubpath()
            }
            .stroke(Color.white.opacity(0.07), lineWidth: 1.5)

            // Foul lines
            Path { p in
                p.move(to: CGPoint(x: cx, y: plateYPt))
                p.addLine(to: CGPoint(x: cx - geo.size.width * 0.45, y: geo.size.height * 0.1))
            }
            .stroke(Color.white.opacity(0.05), lineWidth: 1)
            Path { p in
                p.move(to: CGPoint(x: cx, y: plateYPt))
                p.addLine(to: CGPoint(x: cx + geo.size.width * 0.45, y: geo.size.height * 0.1))
            }
            .stroke(Color.white.opacity(0.05), lineWidth: 1)

            // Home plate
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 28, height: 18)
                .position(x: cx, y: plateYPt)
        }
    }

    // MARK: - Pitching Body (AI batting, player pitches)

    private var pitchingBody: some View {
        VStack(spacing: 0) {
            scoreHUD

            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "figure.baseball")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(Color.red.opacity(0.6))
                    .symbolEffect(.pulse)

                Text("AI BATTING")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(3)

                if showAIResult {
                    Text(aiResultLabel)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(aiResultColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Spacer()
        }
    }

    private var aiResultColor: Color {
        if aiResultLabel.contains("HOME RUN") { return .orange }
        if aiResultLabel.contains("HIT") { return .yellow }
        if aiResultLabel.contains("OUT") { return .green }
        return .secondary
    }

    // MARK: - Inning Break Body

    private var inningBreakBody: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "baseball.fill")
                .font(.system(size: 48))
                .foregroundStyle(gameMode.accentColor)

            Text(inning > INNINGS ? "FINAL" : "END OF INNING \(inning - 1)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(playerScore)")
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("YOU")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(gameMode.accentColor)
                }
                Text("–")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.tertiary)
                VStack(spacing: 4) {
                    Text("\(aiScore)")
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("OPP")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if inning <= INNINGS {
                Button {
                    startInning()
                } label: {
                    Text("INNING \(inning) →")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(gameMode.accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
            Spacer()
        }
    }

    // MARK: - Result Banner

    private var resultBanner: some View {
        let (color, text): (Color, String) = {
            switch swingResult {
            case .homeRun:  return (Color.orange, "HOME RUN!")
            case .basehit:  return (Color.yellow, "BASE HIT")
            case .foul:     return (Color.white.opacity(0.7), "FOUL")
            case .miss:     return (Color.red, "STRIKE")
            case .none:     return (.clear, "")
            }
        }()

        return Text(text)
            .font(.system(size: 28, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.5), radius: 12)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1.5)
                    )
            )
    }

    // MARK: - Result Body

    private var resultBody: some View {
        let winner: ResultScreen.ResultWinner = playerScore > aiScore ? .p1 : (playerScore < aiScore ? .p2 : .draw)
        let shardsEarned: Int = winner == .p1 ? 50 : (winner == .draw ? 25 : 15)
        return ResultScreen(
            winner: winner,
            p1Score: playerScore,
            p2Score: aiScore,
            title: "Home Run Derby",
            accentColor: gameMode.accentColor,
            prqGain: winner == .p1 ? 12 : 3,
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "BATTING",
            modeAttributeValue: playerScore > 0 ? min(1.0, Double(playerScore) / Double(playerScore + aiScore + 1)) : 0.1,
            onReturn: { dismiss() }
        )
        .onAppear { grantRewards(winner: winner, shards: shardsEarned) }
    }

    // MARK: - Logic

    private func startInning() {
        outs = 0
        isTopHalf = true
        phase = .batting
        deliverPitch()
    }

    private func deliverPitch() {
        currentPitch = PitchType.allCases.randomElement() ?? .fastball
        pitchBallY = 0.07
        pitchBallX = 0.5
        playerSwung = false
        swingWindowOpen = false
        zoneHighlight = false
        showResultBanner = false
        pitchAnimating = true

        let duration = currentPitch.speed
        let curveX = currentPitch.curveOffset

        pitchTask?.cancel()
        pitchTask = Task {
            // Open swing window at 55% travel
            try? await Task.sleep(for: .seconds(duration * 0.45))
            guard !Task.isCancelled else { return }
            await MainActor.run { swingWindowOpen = true; zoneHighlight = true }

            // Ball reaches plate area
            try? await Task.sleep(for: .seconds(duration * 0.55))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if !playerSwung {
                    // Automatic miss
                    recordSwingResult(.miss)
                }
                pitchAnimating = false
                swingWindowOpen = false
                zoneHighlight = false
            }
        }

        // Animate ball from top to bottom with curve
        withAnimation(.easeIn(duration: duration)) {
            pitchBallY = plateY + 0.04
            pitchBallX = 0.5 + curveX / UIScreen.main.bounds.width
        }
    }

    private func handleSwing() {
        guard pitchAnimating, !playerSwung else { return }
        playerSwung = true
        pitchTask?.cancel()

        let ballY = pitchBallY
        let result: SwingResult
        if swingWindowOpen {
            if perfectZone.contains(ballY) {
                result = Double.random(in: 0...1) < 0.35 ? .homeRun : .basehit
            } else if goodZone.contains(ballY) {
                result = .basehit
            } else {
                result = .foul
            }
        } else {
            result = swingWindowOpen ? .miss : .foul
        }

        recordSwingResult(result)
        pitchAnimating = false
    }

    private func recordSwingResult(_ result: SwingResult) {
        swingResult = result
        showResultBanner = true

        withAnimation(.spring(response: 0.25)) { bannerScale = 1.0 }

        var runsScored = 0
        var outNow = false

        switch result {
        case .homeRun:
            runsScored = Int.random(in: 1...4)
            triggerShake(intensity: 6)
        case .basehit:
            runsScored = 1
        case .foul:
            // Foul = strike unless 2 outs already on strike 2
            if outs >= OUTS_PER_INNING - 1 {
                // No strikeout on foul
            } else {
                // foul is just a "stay alive" — no out increment here
            }
        case .miss:
            outNow = true
        case .none:
            break
        }

        if runsScored > 0 { playerScore += runsScored }

        if outNow {
            outs += 1
            triggerShake(intensity: 3)
        }

        Task {
            try? await Task.sleep(for: .seconds(result == .homeRun ? 2.0 : 1.4))
            await MainActor.run {
                bannerScale = 0.6
                showResultBanner = false
                swingResult = .none

                if outs >= OUTS_PER_INNING {
                    endHalfInning()
                } else {
                    deliverPitch()
                }
            }
        }
    }

    private func endHalfInning() {
        if isTopHalf {
            // Switch to AI batting
            isTopHalf = false
            outs = 0
            phase = .pitching
            runAIAtBat()
        } else {
            // End of full inning
            if inning >= INNINGS {
                phase = .result
            } else {
                inning += 1
                phase = .inningBreak
            }
        }
    }

    private func runAIAtBat() {
        aiAtBatTask?.cancel()
        aiAtBatTask = Task {
            var aiOuts = 0
            while aiOuts < OUTS_PER_INNING {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(Double.random(in: 1.2...2.0)))
                guard !Task.isCancelled else { return }

                let roll = Double.random(in: 0...1)
                let label: String
                if roll < 0.08 {
                    label = "HOME RUN! 💥"
                    await MainActor.run { aiScore += Int.random(in: 1...2) }
                } else if roll < 0.28 {
                    label = "BASE HIT"
                    await MainActor.run { aiScore += 1 }
                } else if roll < 0.55 {
                    label = "FOUL BALL"
                    // foul, no out change
                } else {
                    label = "OUT (\(aiOuts + 1)/3)"
                    aiOuts += 1
                }

                await MainActor.run {
                    aiResultLabel = label
                    withAnimation(.spring(response: 0.25)) { showAIResult = true }
                }
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    withAnimation { showAIResult = false }
                }
            }

            await MainActor.run {
                if inning >= INNINGS {
                    phase = .result
                } else {
                    inning += 1
                    phase = .inningBreak
                }
            }
        }
    }

    private func triggerShake(intensity: CGFloat) {
        screenShake = intensity
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run { screenShake = 0 }
        }
    }

    private func grantRewards(winner: ResultScreen.ResultWinner, shards: Int) {
        guard !rewardGranted else { return }
        rewardGranted = true
        viewModel.profile.evolutionShards += shards
        let xpGain = min(XP_CAP_PER_SESSION, shards * 2)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) / 100.0)
    }
}
