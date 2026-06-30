import SwiftUI

// MARK: - Phase

private enum KaratePhase {
    case ready, fight, result
}

// MARK: - Outcome

private enum KarateOutcome {
    case win, draw, loss
}

// MARK: - Health Bar

private struct KarateHealthBar: View {
    let current: Double
    let max: Double
    let color: Color
    let label: String
    let isReversed: Bool

    private var fraction: Double { max > 0 ? min(1, current / max) : 0 }

    var body: some View {
        VStack(alignment: isReversed ? .trailing : .leading, spacing: 4) {
            HStack {
                if isReversed { Spacer() }
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                if !isReversed { Spacer() }
            }
            GeometryReader { geo in
                ZStack(alignment: isReversed ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: isReversed ? .trailing : .leading,
                                endPoint: isReversed ? .leading : .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: fraction)
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - Chakra Meter

private struct KarateChakraMeter: View {
    let value: Double
    let accentColor: Color

    private var fraction: Double { min(1, value / 100) }
    private var isFull: Bool { value >= 100 }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isFull ? .yellow : accentColor.opacity(0.7))
                Text("CHAKRA")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(isFull ? .yellow : .secondary)
                    .tracking(2)
                Spacer()
                if isFull {
                    Text("DRAGON STRIKE READY")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .tracking(1)
                }
                Text("\(Int(value))%")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(isFull ? .yellow : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: isFull ? [.yellow, .orange] : [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - Action Flash Label

private struct KarateActionLabel: View {
    let text: String
    let color: Color
    let visible: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .black, design: .monospaced))
            .italic()
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.7), radius: 14)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1.0 : 0.6)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: visible)
    }
}

// MARK: - Main View

struct KarateGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // Phase
    @State private var phase: KaratePhase = .ready

    // Timer
    @State private var timeLeft: Int = 90
    @State private var gameTimerTask: Task<Void, Never>?

    // Health
    @State private var playerHP: Double = 100
    @State private var opponentHP: Double = 100
    private let maxHP: Double = 100

    // Scores & combo
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var combo: Int = 0
    @State private var maxCombo: Int = 0

    // Chakra
    @State private var chakra: Double = 0
    @State private var showDragonStrikeButton: Bool = false

    // UI Flashes
    @State private var showFightFlash: Bool = false
    @State private var showCriticalFlash: Bool = false
    @State private var criticalFlashTask: Task<Void, Never>?
    @State private var actionLabel: String = ""
    @State private var actionColor: Color = Theme.brandBlue
    @State private var showActionLabel: Bool = false
    @State private var actionLabelTask: Task<Void, Never>?
    @State private var screenShake: CGFloat = 0

    // AI
    @State private var aiAttackTask: Task<Void, Never>?
    @State private var lastPlayerActionTime: Date = Date()

    // Outcome
    @State private var outcome: KarateOutcome = .loss
    @State private var shardsAwarded: Bool = false

    private let accentColor = Color(red: 1.0, green: 0.2, blue: 0.2)
    private let opponentName = "Ryu Nexus"

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.01, blue: 0.01), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            if showCriticalFlash {
                Color.yellow.opacity(0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Karate · 1v1",
                    subtitle: "90-Second Match · Beat the Opponent",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startFight() }
                )

            case .fight:
                fightBody
                    .offset(x: screenShake)

            case .result:
                ResultScreen(
                    winner: outcome == .win ? .p1 : (outcome == .draw ? .draw : .p2),
                    p1Score: playerScore,
                    p2Score: opponentScore,
                    title: "Karate · 1v1",
                    accentColor: accentColor,
                    prqGain: outcome == .win ? 10 : (outcome == .draw ? 5 : 2),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "COMBO",
                    modeAttributeValue: min(1.0, Double(maxCombo) / 10.0),
                    onReturn: { dismiss() }
                )
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

    // MARK: - Fight Body

    private var fightBody: some View {
        VStack(spacing: 0) {
            hudSection
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Divider().background(Theme.cardBorder)

            arenaSection

            Divider().background(Theme.cardBorder)

            controlsHint
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
    }

    // MARK: - HUD

    private var hudSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                KarateHealthBar(
                    current: playerHP,
                    max: maxHP,
                    color: Theme.brandBlue,
                    label: "YOU",
                    isReversed: false
                )
                .frame(maxWidth: .infinity)

                ZStack {
                    Circle()
                        .stroke(
                            timeLeft <= 15 ? Color.red.opacity(0.5) : accentColor.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 48, height: 48)
                    Text("\(timeLeft)")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(timeLeft <= 15 ? .red : .white)
                        .contentTransition(.numericText())
                }
                .frame(width: 48)

                KarateHealthBar(
                    current: opponentHP,
                    max: maxHP,
                    color: accentColor,
                    label: opponentName.uppercased(),
                    isReversed: true
                )
                .frame(maxWidth: .infinity)
            }

            HStack {
                Text("\(playerScore)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue)
                Spacer()
                if combo >= 2 {
                    Text("×\(combo) COMBO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                Text("\(opponentScore)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
            }

            KarateChakraMeter(value: chakra, accentColor: accentColor)
                .onChange(of: chakra) { _, newVal in
                    showDragonStrikeButton = newVal >= 100
                }
        }
    }

    // MARK: - Arena

    private var arenaSection: some View {
        ZStack {
            RadialGradient(
                colors: [accentColor.opacity(0.04), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 200
            )
            .allowsHitTesting(false)

            if showFightFlash {
                Text("FIGHT!")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .italic()
                    .foregroundStyle(accentColor)
                    .shadow(color: accentColor.opacity(0.8), radius: 20)
                    .transition(.scale.combined(with: .opacity))
            }

            KarateActionLabel(text: actionLabel, color: actionColor, visible: showActionLabel)

            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom, spacing: 0) {
                    Image(systemName: "figure.martial.arts")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.brandBlue, Theme.brandCyan],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: Theme.brandBlue.opacity(0.4), radius: 10)

                    Spacer()

                    Image(systemName: "figure.martial.arts")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.6)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: accentColor.opacity(0.4), radius: 10)
                        .scaleEffect(x: -1, y: 1)
                }
                .padding(.horizontal, 40)
                Spacer()
            }

            if showDragonStrikeButton {
                VStack {
                    Spacer()
                    Button { triggerDragonStrike() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("DRAGON STRIKE")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .tracking(2)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(.rect(cornerRadius: 14))
                        .shadow(color: .yellow.opacity(0.5), radius: 16)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dy = value.translation.height
                    let dx = value.translation.width
                    if abs(dy) > abs(dx) && dy < -40 {
                        handleBlock()
                    }
                }
        )
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    let screenWidth = UIScreen.main.bounds.width
                    if value.location.x < screenWidth / 2 {
                        handlePunch()
                    } else {
                        handleKick()
                    }
                }
        )
        .onLongPressGesture(minimumDuration: 0.3) {
            handleStance()
        }
    }

    // MARK: - Controls Hint

    private var controlsHint: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.brandBlue)
                Text("← PUNCH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.foundationGreen)
                Text("↑ BLOCK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "rectangle.and.hand.point.up.left.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.elitePurple)
                Text("HOLD STANCE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(accentColor)
                Text("KICK →")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Game Logic

    private func startFight() {
        phase = .fight
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { showFightFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run { withAnimation { showFightFlash = false } }
        }
        startGameTimer()
        scheduleAIAttack()
    }

    private func startGameTimer() {
        gameTimerTask?.cancel()
        gameTimerTask = Task {
            while timeLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeLeft -= 1 }
            }
            await MainActor.run { endGame() }
        }
    }

    private func scheduleAIAttack() {
        aiAttackTask?.cancel()
        aiAttackTask = Task {
            while true {
                let delay = Double.random(in: 2.0...4.0)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await MainActor.run { aiAttack() }
            }
        }
    }

    private func aiAttack() {
        guard phase == .fight else { return }
        let damage = Double.random(in: 8...18)
        playerHP = max(0, playerHP - damage)
        opponentScore += 1
        flashScreenShake()
        if playerHP <= 0 { endGame(ko: true, playerKO: true) }
    }

    // MARK: - Player Actions

    private func handlePunch() {
        guard phase == .fight else { return }
        let now = Date()
        let isCritical = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now

        let damage: Double = (isCritical ? 12 : 8) + Double(combo) * 1.5
        opponentHP = max(0, opponentHP - damage)
        playerScore += isCritical ? 2 : 1
        combo += 1
        maxCombo = max(maxCombo, combo)
        chakra = min(100, chakra + (isCritical ? 15 : 8))

        showAction(text: isCritical ? "CRITICAL PUNCH!" : "PUNCH", color: Theme.brandBlue)
        if isCritical { triggerCriticalFlash() }
        flashScreenShake()
        if opponentHP <= 0 { endGame(ko: true, playerKO: false) }
    }

    private func handleKick() {
        guard phase == .fight else { return }
        let now = Date()
        let isCritical = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now

        let damage: Double = (isCritical ? 18 : 12) + Double(combo) * 2.0
        opponentHP = max(0, opponentHP - damage)
        playerScore += isCritical ? 3 : 2
        combo += 1
        maxCombo = max(maxCombo, combo)
        chakra = min(100, chakra + (isCritical ? 20 : 12))

        showAction(text: isCritical ? "CRITICAL KICK!" : "KICK", color: accentColor)
        if isCritical { triggerCriticalFlash() }
        flashScreenShake()
        if opponentHP <= 0 { endGame(ko: true, playerKO: false) }
    }

    private func handleBlock() {
        guard phase == .fight else { return }
        combo = 0
        playerHP = min(maxHP, playerHP + 5)
        showAction(text: "BLOCK", color: Theme.foundationGreen)
    }

    private func handleStance() {
        guard phase == .fight else { return }
        chakra = min(100, chakra + 10)
        showAction(text: "STANCE", color: Theme.elitePurple)
    }

    private func triggerDragonStrike() {
        guard phase == .fight, chakra >= 100 else { return }
        chakra = 0
        showDragonStrikeButton = false

        opponentHP = max(0, opponentHP - 45)
        playerScore += 10
        combo += 3
        maxCombo = max(maxCombo, combo)

        showAction(text: "DRAGON STRIKE!", color: .yellow)
        triggerCriticalFlash()
        flashScreenShake()
        if opponentHP <= 0 { endGame(ko: true, playerKO: false) }
    }

    // MARK: - FX

    private func showAction(text: String, color: Color) {
        actionLabel = text
        actionColor = color
        withAnimation { showActionLabel = true }
        actionLabelTask?.cancel()
        actionLabelTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { showActionLabel = false }
                if combo > 0 { combo -= 1 }
            }
        }
    }

    private func triggerCriticalFlash() {
        withAnimation(.easeOut(duration: 0.08)) { showCriticalFlash = true }
        criticalFlashTask?.cancel()
        criticalFlashTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(.easeIn(duration: 0.25)) { showCriticalFlash = false } }
        }
    }

    private func flashScreenShake() {
        withAnimation(.easeOut(duration: 0.06)) { screenShake = 8 }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run { withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { screenShake = 0 } }
        }
    }

    // MARK: - End Game

    private func endGame(ko: Bool = false, playerKO: Bool = false) {
        guard phase == .fight else { return }
        cancelAllTasks()

        if playerKO {
            outcome = .loss
            showAction(text: "KO!", color: .red)
        } else if ko {
            outcome = .win
            showAction(text: "KO!", color: .yellow)
        } else if playerHP > opponentHP {
            outcome = .win
            showAction(text: "TIME!", color: accentColor)
        } else if playerHP < opponentHP {
            outcome = .loss
            showAction(text: "TIME!", color: .red)
        } else {
            outcome = .draw
            showAction(text: "DRAW!", color: .white)
        }

        awardShards()

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { withAnimation { phase = .result } }
        }
    }

    private func awardShards() {
        guard !shardsAwarded else { return }
        shardsAwarded = true
        let shards: Int
        switch outcome {
        case .win:  shards = 50
        case .draw: shards = 25
        case .loss: shards = 15
        }
        viewModel.profile.evolutionShards += shards
        SaveSystem.saveProfile(viewModel.profile)
    }

    private func cancelAllTasks() {
        gameTimerTask?.cancel()
        aiAttackTask?.cancel()
        actionLabelTask?.cancel()
        criticalFlashTask?.cancel()
    }
}
