import SwiftUI

// MARK: - Phase

private enum SkatePhase {
    case ready, running, bail, runTransition, result
}

// MARK: - Trick Definition

private struct SkateTrick: Identifiable {
    let id = UUID()
    let name: String
    let points: Int
    let icon: String
}

private let skateTricks: [SkateTrick] = [
    SkateTrick(name: "Ollie",     points: 50,  icon: "arrow.up"),
    SkateTrick(name: "Kickflip",  points: 100, icon: "arrow.up.right"),
    SkateTrick(name: "Heelflip",  points: 100, icon: "arrow.up.left"),
    SkateTrick(name: "360 Flip",  points: 200, icon: "arrow.up.circle"),
    SkateTrick(name: "Grind",     points: 75,  icon: "minus"),
]

// Grind is index 4 — special hold mechanic
private let grindIndex = 4

// MARK: - Swipe Direction

private enum SwipeDir {
    case up, upRight, upLeft, doubleUp, hold
}

// MARK: - Combo multiplier steps

private let comboMultipliers: [Int] = [1, 2, 3, 5]

private func comboMultiplier(for combo: Int) -> Int {
    let idx = min(combo, comboMultipliers.count - 1)
    return comboMultipliers[idx]
}

// MARK: - SkateboardingGameView

struct SkateboardingGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    private let totalRuns = 3
    private let runDuration: Double = 10
    private let xpCapPerSession = 500
    private let accentColor = Color(red: 0.95, green: 0.45, blue: 0.12)

    @Environment(\.dismiss) private var dismiss

    // Phase
    @State private var phase: SkatePhase = .ready

    // Run state
    @State private var currentRun = 1
    @State private var timeLeft: Double = 10
    @State private var runTimer: Task<Void, Never>? = nil

    // Scoring
    @State private var currentRunScore = 0
    @State private var bestRunScore = 0
    @State private var runScores: [Int] = []

    // Combo
    @State private var comboCount = 0
    @State private var lastTrickIndex: Int? = nil
    @State private var lastTrickTime: Date? = nil

    // Trick display
    @State private var trickPopup: String? = nil
    @State private var trickPopupPoints: Int = 0
    @State private var popupTask: Task<Void, Never>? = nil

    // Grind
    @State private var isGrinding = false
    @State private var grindTask: Task<Void, Never>? = nil

    // Bail
    @State private var showBailFlash = false

    // Swipe detection
    @State private var swipeStartLocation: CGPoint = .zero
    @State private var lastSwipeEnd: Date = .distantPast

    // Result
    @State private var didWin = false
    @State private var shardsEarned = 0

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.04, blue: 0.01), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Skateboarding",
                    subtitle: "3 runs · 10 sec each · Chain combos",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startRun() }
                )

            case .running:
                runningBody

            case .bail:
                bailBody

            case .runTransition:
                runTransitionBody

            case .result:
                ResultScreen(
                    winner: didWin ? .p1 : .p2,
                    p1Score: bestRunScore,
                    p2Score: max(0, bestRunScore - Int.random(in: 50...200)),
                    title: "Skateboarding",
                    accentColor: accentColor,
                    prqGain: didWin ? 12 : 4,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "TRICK",
                    modeAttributeValue: min(1.0, Double(bestRunScore) / 1000.0),
                    onReturn: {
                        applyRewards()
                        dismiss()
                    }
                )
            }

            // Bail flash overlay
            if showBailFlash {
                Color.red.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    runTimer?.cancel()
                    grindTask?.cancel()
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
        .onDisappear {
            runTimer?.cancel()
            grindTask?.cancel()
        }
    }

    // MARK: - Running View

    private var runningBody: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer()

            // Trick popup
            trickPopupView
                .frame(height: 80)

            // Combo chain display
            comboChainView

            Spacer()

            // Skate park visual
            skateParkVisual

            Spacer()

            // Swipe input area
            swipeInputArea
                .padding(.bottom, 32)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            // Run indicator
            VStack(alignment: .leading, spacing: 2) {
                Text("RUN \(currentRun)/\(totalRuns)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(2)
                HStack(spacing: 4) {
                    ForEach(1...totalRuns, id: \.self) { i in
                        let scored = i < currentRun
                        let active = i == currentRun
                        RoundedRectangle(cornerRadius: 2)
                            .fill(scored ? Theme.foundationGreen : (active ? accentColor : Theme.cardBorder))
                            .frame(width: 28, height: 5)
                    }
                }
            }

            Spacer()

            // Timer ring
            ZStack {
                Circle()
                    .stroke(Theme.cardBorder, lineWidth: 3)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(timeLeft / runDuration))
                    .stroke(timeLeft > 4 ? accentColor : .red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timeLeft)
                Text(String(format: "%.0f", timeLeft))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(timeLeft > 4 ? .white : .red)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Best score
            VStack(alignment: .trailing, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(currentRunScore)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder
    private var trickPopupView: some View {
        if let name = trickPopup {
            VStack(spacing: 4) {
                Text(name.uppercased())
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .shadow(color: accentColor.opacity(0.5), radius: 8)
                Text("+\(trickPopupPoints) pts")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            Color.clear
        }
    }

    private var comboChainView: some View {
        HStack(spacing: 8) {
            if comboCount > 0 {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.yellow)

                Text("x\(comboCount) COMBO")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .tracking(1)

                Text("(\(comboMultiplierLabel))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.7))
            }
        }
        .frame(height: 24)
        .animation(.spring(response: 0.3), value: comboCount)
    }

    private var comboMultiplierLabel: String {
        "×\(comboMultiplier(for: comboCount))"
    }

    private var skateParkVisual: some View {
        ZStack {
            // Ground
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.cardBackground)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )

            // Ramp silhouettes
            HStack(spacing: 24) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.3), accentColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 40, height: CGFloat([32, 48, 38][i]))
                }
            }

            // Skater icon
            Image(systemName: "figure.skating")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(accentColor)
                .shadow(color: accentColor.opacity(0.6), radius: 8)
                .scaleEffect(isGrinding ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isGrinding)
        }
        .padding(.horizontal, 24)
    }

    private var swipeInputArea: some View {
        VStack(spacing: 16) {
            // Trick legend
            HStack(spacing: 0) {
                ForEach(skateTricks.prefix(4)) { trick in
                    VStack(spacing: 4) {
                        Image(systemName: trick.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accentColor)
                        Text(trick.name)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(trick.points)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)

            // Main swipe area
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isGrinding ? accentColor.opacity(0.6) : Theme.cardBorder,
                                lineWidth: isGrinding ? 2 : 1
                            )
                    )
                    .frame(height: 100)

                VStack(spacing: 4) {
                    if isGrinding {
                        Text("GRINDING...")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.pulse)
                        Text("HOLD · \(Int(75))pts/sec")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                        Text("SWIPE TO TRICK  ·  HOLD FOR GRIND")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                            .tracking(1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if swipeStartLocation == .zero {
                            swipeStartLocation = value.startLocation
                        }
                        // Start grind on long hold with minimal movement
                        let dist = hypot(value.translation.width, value.translation.height)
                        if dist < 20 && !isGrinding {
                            startGrind()
                        }
                    }
                    .onEnded { value in
                        endGrind()
                        let dx = value.translation.width
                        let dy = value.translation.height
                        let dist = hypot(dx, dy)
                        guard dist > 20 else {
                            swipeStartLocation = .zero
                            return
                        }
                        // Determine direction
                        let dir = swipeDirection(dx: dx, dy: dy)
                        handleSwipe(dir: dir)
                        swipeStartLocation = .zero
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onEnded { _ in
                        startGrind()
                    }
            )

            // Grind button row
            HStack {
                Spacer()
                Button {
                    if isGrinding {
                        endGrind()
                    } else {
                        startGrind()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isGrinding ? "stop.fill" : "minus")
                            .font(.system(size: 12, weight: .bold))
                        Text(isGrinding ? "END GRIND" : "GRIND")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(isGrinding ? .black : accentColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(isGrinding ? accentColor : Theme.cardBackground)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(accentColor.opacity(0.4), lineWidth: 1)
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Bail Screen

    private var bailBody: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
            }

            Text("BAIL!")
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundStyle(.red)
                .italic()

            Text("Same trick twice — lost your combo")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Run \(currentRun) Score: \(currentRunScore) pts")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Run Transition

    private var runTransitionBody: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("RUN \(currentRun - 1) COMPLETE")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)

            Text("\(runScores.last ?? 0)")
                .font(.system(size: 56, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .shadow(color: accentColor.opacity(0.4), radius: 16)

            Text("PTS")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(4)

            if currentRun <= totalRuns {
                Button {
                    startRun()
                } label: {
                    Text("RUN \(currentRun) — GO")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.top, 16)
            }

            // Best score bar
            VStack(spacing: 8) {
                Text("BEST RUN")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(bestRunScore) pts")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.foundationGreen)
            }

            Spacer()
        }
    }

    // MARK: - Swipe Recognition

    private func swipeDirection(dx: CGFloat, dy: CGFloat) -> SwipeDir {
        let angle = atan2(-dy, dx) * 180 / .pi
        // angle: 90 = up, 0 = right, 45 = up-right, 135 = up-left

        // Check if it's a double swipe (second swipe within 0.4s)
        let now = Date()
        let isDouble = now.timeIntervalSince(lastSwipeEnd) < 0.4
        lastSwipeEnd = now

        if isDouble && dy < -30 {
            return .doubleUp
        }

        if abs(angle - 90) < 30 { return .up }
        if angle > 30 && angle < 80 { return .upRight }
        if angle > 100 && angle < 160 { return .upLeft }
        return .up
    }

    // MARK: - Trick Execution

    private func handleSwipe(dir: SwipeDir) {
        guard phase == .running else { return }

        switch dir {
        case .up:
            performTrick(index: 0) // Ollie
        case .upRight:
            performTrick(index: 1) // Kickflip
        case .upLeft:
            performTrick(index: 2) // Heelflip
        case .doubleUp:
            performTrick(index: 3) // 360 Flip
        case .hold:
            startGrind()
        }
    }

    private func performTrick(index: Int) {
        guard phase == .running else { return }

        let trick = skateTricks[index]

        // Bail risk: same trick twice in 2 seconds
        let now = Date()
        if lastTrickIndex == index,
           let last = lastTrickTime,
           now.timeIntervalSince(last) < 2.0 {
            if Double.random(in: 0...1) < 0.40 {
                triggerBail()
                return
            }
        }

        lastTrickIndex = index
        lastTrickTime = now

        // Combo multiplier
        let mult = comboMultiplier(for: comboCount)
        let points = trick.points * mult
        comboCount = min(comboCount + 1, comboMultipliers.count - 1)

        currentRunScore += points
        bestRunScore = max(bestRunScore, currentRunScore)

        showTrickPopup(name: trick.name, points: points)
    }

    private func startGrind() {
        guard phase == .running, !isGrinding else { return }
        isGrinding = true

        grindTask?.cancel()
        grindTask = Task {
            var elapsed: Double = 0
            while !Task.isCancelled && isGrinding && phase == .running {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if isGrinding && phase == .running {
                        let mult = comboMultiplier(for: comboCount)
                        let pts = Int(37.5 * Double(mult)) // 75pts/sec → 37.5 per 0.5s
                        currentRunScore += pts
                        bestRunScore = max(bestRunScore, currentRunScore)
                        elapsed += 0.5
                    }
                }
            }
        }
        showTrickPopup(name: "Grind", points: 0)
    }

    private func endGrind() {
        guard isGrinding else { return }
        isGrinding = false
        grindTask?.cancel()
        grindTask = nil
        // Increment combo
        comboCount = min(comboCount + 1, comboMultipliers.count - 1)
    }

    private func triggerBail() {
        runTimer?.cancel()
        grindTask?.cancel()
        isGrinding = false
        comboCount = 0
        lastTrickIndex = nil

        withAnimation(.spring(response: 0.2)) { showBailFlash = true }
        phase = .bail

        Task {
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run {
                withAnimation { showBailFlash = false }
                finishRun()
            }
        }
    }

    // MARK: - Run Timer

    private func startRun() {
        currentRunScore = 0
        comboCount = 0
        lastTrickIndex = nil
        lastTrickTime = nil
        timeLeft = runDuration
        phase = .running
        trickPopup = nil
        isGrinding = false

        runTimer?.cancel()
        runTimer = Task {
            let tick: Double = 0.1
            while timeLeft > 0 {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    timeLeft = max(0, timeLeft - tick)
                }
            }
            await MainActor.run {
                guard phase == .running else { return }
                finishRun()
            }
        }
    }

    private func finishRun() {
        runTimer?.cancel()
        grindTask?.cancel()
        isGrinding = false

        runScores.append(currentRunScore)
        bestRunScore = max(bestRunScore, currentRunScore)

        if currentRun >= totalRuns {
            // Session complete
            let opponentScore = Int.random(in: 400...700)
            didWin = bestRunScore > opponentScore
            phase = .result
        } else {
            currentRun += 1
            phase = .runTransition
        }
    }

    // MARK: - Popup

    private func showTrickPopup(name: String, points: Int) {
        popupTask?.cancel()
        withAnimation(.spring(response: 0.25)) {
            trickPopup = name
            trickPopupPoints = points
        }
        popupTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    trickPopup = nil
                }
            }
        }
    }

    // MARK: - Rewards

    private func applyRewards() {
        let shards = didWin ? 50 : (bestRunScore > 300 ? 25 : 15)
        shardsEarned = shards
        viewModel.profile.evolutionShards += shards

        let xpGain = min(xpCapPerSession, bestRunScore / 10)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) * 0.01)
    }
}
