import SwiftUI

// MARK: - Phase

private enum EndlessPhase {
    case ready, fighting, waveClear, result
}

// MARK: - Wave Opponent

private struct WaveOpponent: Identifiable {
    let id: UUID = UUID()
    var hp: Double
    let maxHP: Double
    let name: String
}

// MARK: - Opponent HP Stack

private struct OpponentHPStack: View {
    let opponents: [WaveOpponent]
    let accentColor: Color

    var body: some View {
        VStack(spacing: 6) {
            ForEach(opponents) { opp in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(opp.name.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                        Spacer()
                        Text("\(Int(opp.hp))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1, opp.hp / opp.maxHP))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: opp.hp)
                        }
                    }
                    .frame(height: 7)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
    }
}

// MARK: - Endless Chakra Meter

private struct EndlessChakraMeter: View {
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
                    Text("DRAGON STRIKE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
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
                                startPoint: .leading, endPoint: .trailing
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

// MARK: - Action Label

private struct EndlessActionLabel: View {
    let text: String
    let color: Color
    let visible: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 26, weight: .black, design: .monospaced))
            .italic()
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.7), radius: 14)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1.0 : 0.6)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: visible)
    }
}

// MARK: - Main View

struct KarateEndlessGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // Phase
    @State private var phase: EndlessPhase = .ready

    // Time — 4 minutes survival
    @State private var timeLeft: Int = 240
    @State private var gameTimerTask: Task<Void, Never>?

    // Player
    @State private var playerHP: Double = 100
    private let maxPlayerHP: Double = 100

    // Wave & opponents
    @State private var waveNumber: Int = 1
    @State private var opponents: [WaveOpponent] = []
    @State private var score: Int = 0
    @State private var highScore: Int = 0

    // Combo & chakra
    @State private var combo: Int = 0
    @State private var maxCombo: Int = 0
    @State private var chakra: Double = 0
    @State private var showDragonStrikeButton: Bool = false

    // Flashes
    @State private var showCriticalFlash: Bool = false
    @State private var criticalFlashTask: Task<Void, Never>?
    @State private var actionLabel: String = ""
    @State private var actionColor: Color = Theme.brandBlue
    @State private var showActionLabel: Bool = false
    @State private var actionLabelTask: Task<Void, Never>?
    @State private var screenShake: CGFloat = 0
    @State private var showWaveBanner: Bool = false
    @State private var waveBannerTask: Task<Void, Never>?

    // AI
    @State private var aiAttackTask: Task<Void, Never>?
    @State private var lastPlayerActionTime: Date = Date()

    // Shard guard
    @State private var shardsAwarded: Bool = false

    private let accentColor = Color(red: 1.0, green: 0.35, blue: 0.1)
    private let highScoreKey = "karate_endless_high_score"

    // Wave opponent names pool
    private let opponentNamePool = ["Ryu", "Ken", "Akuma", "Sagat", "Guile", "Blanka", "Zangief", "Dhalsim"]

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.04, blue: 0.01), Theme.deepBlack],
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
                    title: "Karate · Endless",
                    subtitle: "4-Minute Survival · Wave Attack",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startGame() }
                )

            case .fighting:
                fightingBody
                    .offset(x: screenShake)

            case .waveClear:
                waveClearBanner

            case .result:
                resultBody
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
        .onAppear { highScore = UserDefaults.standard.integer(forKey: highScoreKey) }
        .onDisappear { cancelAllTasks() }
    }

    // MARK: - Fighting Body

    private var fightingBody: some View {
        VStack(spacing: 0) {
            topHUD
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)

            Divider().background(Theme.cardBorder)

            arenaSection

            Divider().background(Theme.cardBorder)

            controlsHint
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Top HUD

    private var topHUD: some View {
        VStack(spacing: 10) {
            // Wave number + timer + score row
            HStack(alignment: .center, spacing: 12) {
                // Wave badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                    VStack(spacing: 1) {
                        Text("WAVE")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor.opacity(0.8))
                            .tracking(1)
                        Text("\(waveNumber)")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }

                // Player HP bar
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("YOU")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        Spacer()
                        Text("\(Int(playerHP))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [Theme.brandBlue, Theme.brandCyan], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * min(1, playerHP / maxPlayerHP))
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: playerHP)
                        }
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .frame(maxWidth: .infinity)

                // Timer
                ZStack {
                    Circle()
                        .stroke(
                            timeLeft <= 30 ? Color.red.opacity(0.5) : accentColor.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 48, height: 48)
                    VStack(spacing: 0) {
                        Text("\(timeLeft / 60):\(String(format: "%02d", timeLeft % 60))")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(timeLeft <= 30 ? .red : .white)
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 48)
            }

            // Score row
            HStack {
                Text("SCORE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(score)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer()
                if combo >= 2 {
                    Text("×\(combo) COMBO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("BEST")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Text("\(highScore)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(score > highScore ? .yellow : .secondary)
                }
            }

            // Opponent HP bars
            if !opponents.isEmpty {
                OpponentHPStack(opponents: opponents, accentColor: accentColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Chakra meter
            EndlessChakraMeter(value: chakra, accentColor: accentColor)
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

            EndlessActionLabel(text: actionLabel, color: actionColor, visible: showActionLabel)

            // Fighter icons scaled to opponent count
            HStack(alignment: .bottom, spacing: 0) {
                Image(systemName: "figure.martial.arts")
                    .font(.system(size: 68, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.brandBlue, Theme.brandCyan],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: Theme.brandBlue.opacity(0.4), radius: 10)

                Spacer()

                ForEach(opponents) { opp in
                    Image(systemName: "figure.martial.arts")
                        .font(.system(size: CGFloat(56 - opponents.count * 4), weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.6)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: accentColor.opacity(0.3), radius: 8)
                        .scaleEffect(x: -1, y: 1)
                        .offset(x: CGFloat(opponents.firstIndex(where: { $0.id == opp.id }) ?? 0) * 12)
                }
            }
            .padding(.horizontal, 40)

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
                    if abs(dy) > abs(dx) && dy < -40 { handleBlock() }
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

    // MARK: - Wave Clear Banner

    private var waveClearBanner: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, accentColor], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 20)

                Text("WAVE \(waveNumber - 1) CLEAR!")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .italic()
                    .foregroundStyle(.white)

                Text("WAVE \(waveNumber) INCOMING")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(2)

                Text("SCORE: \(score)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Result Body (custom for high score)

    private var resultBody: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            RadialGradient(
                colors: [accentColor.opacity(0.12), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 350
            ).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("KARATE · ENDLESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(4)

                Image(systemName: "flame.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [accentColor, .yellow], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: accentColor.opacity(0.5), radius: 20)

                Text("SURVIVED")
                    .font(.system(size: 36, weight: .black))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(.white)

                Text("WAVE \(waveNumber)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)

                // Score card
                HStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("SCORE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentColor.opacity(0.7))
                        Text("\(score)")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    Rectangle()
                        .fill(Theme.cardBorder)
                        .frame(width: 1, height: 50)

                    VStack(spacing: 6) {
                        Text("BEST")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(highScore)")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(score >= highScore ? .yellow : .white.opacity(0.4))
                        if score > highScore {
                            Text("NEW RECORD!")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(accentColor.opacity(0.15), lineWidth: 1)
                        )
                )

                // Max combo row
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text("MAX COMBO: \(maxCombo)x")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Button { dismiss() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("CLAIM & EXIT")
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.8)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: accentColor.opacity(0.3), radius: 12)
                }
                .padding(.top, 8)

                Spacer()
            }
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

    private func startGame() {
        spawnWave()
        phase = .fighting
        startGameTimer()
        scheduleAIAttacks()
    }

    private func spawnWave() {
        let count = min(3, waveNumber)
        let hpScale = 1.0 + Double(waveNumber - 1) * 0.25
        let baseHP = 60.0 * hpScale
        var newOpponents: [WaveOpponent] = []
        for i in 0..<count {
            let name = opponentNamePool[(waveNumber * 3 + i) % opponentNamePool.count]
            newOpponents.append(WaveOpponent(hp: baseHP, maxHP: baseHP, name: name))
        }
        withAnimation { opponents = newOpponents }
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

    private func scheduleAIAttacks() {
        aiAttackTask?.cancel()
        aiAttackTask = Task {
            while true {
                // Attacks get faster each wave
                let baseDelay = max(1.0, 3.5 - Double(waveNumber) * 0.3)
                let delay = Double.random(in: baseDelay...(baseDelay + 1.5))
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await MainActor.run { aiAttack() }
            }
        }
    }

    private func aiAttack() {
        guard phase == .fighting else { return }
        // Damage scales with wave
        let baseDamage = 6.0 + Double(waveNumber - 1) * 1.5
        let damage = Double.random(in: baseDamage...(baseDamage + 8))
        playerHP = max(0, playerHP - damage)
        flashScreenShake()
        if playerHP <= 0 { endGame() }
    }

    // MARK: - Player Actions

    private func handlePunch() {
        guard phase == .fighting, !opponents.isEmpty else { return }
        let now = Date()
        let isCritical = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now

        let damage: Double = (isCritical ? 10 : 7) + Double(combo) * 1.2
        applyDamageToOpponents(damage: damage)

        score += isCritical ? 2 : 1
        combo += 1
        maxCombo = max(maxCombo, combo)
        chakra = min(100, chakra + (isCritical ? 14 : 8))

        showAction(text: isCritical ? "CRITICAL PUNCH!" : "PUNCH", color: Theme.brandBlue)
        if isCritical { triggerCriticalFlash() }
        flashScreenShake()
    }

    private func handleKick() {
        guard phase == .fighting, !opponents.isEmpty else { return }
        let now = Date()
        let isCritical = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now

        let damage: Double = (isCritical ? 16 : 11) + Double(combo) * 1.8
        applyDamageToOpponents(damage: damage)

        score += isCritical ? 3 : 2
        combo += 1
        maxCombo = max(maxCombo, combo)
        chakra = min(100, chakra + (isCritical ? 18 : 11))

        showAction(text: isCritical ? "CRITICAL KICK!" : "KICK", color: accentColor)
        if isCritical { triggerCriticalFlash() }
        flashScreenShake()
    }

    private func handleBlock() {
        guard phase == .fighting else { return }
        combo = 0
        playerHP = min(maxPlayerHP, playerHP + 4)
        showAction(text: "BLOCK", color: Theme.foundationGreen)
    }

    private func handleStance() {
        guard phase == .fighting else { return }
        chakra = min(100, chakra + 10)
        showAction(text: "STANCE", color: Theme.elitePurple)
    }

    private func triggerDragonStrike() {
        guard phase == .fighting, chakra >= 100 else { return }
        chakra = 0
        showDragonStrikeButton = false

        // Dragon strike hits ALL opponents
        for i in opponents.indices {
            opponents[i] = WaveOpponent(
                hp: max(0, opponents[i].hp - 55),
                maxHP: opponents[i].maxHP,
                name: opponents[i].name
            )
        }
        score += 15
        combo += 3
        maxCombo = max(maxCombo, combo)

        showAction(text: "DRAGON STRIKE!", color: .yellow)
        triggerCriticalFlash()
        flashScreenShake()

        // Remove defeated opponents
        withAnimation { opponents.removeAll { $0.hp <= 0 } }
        if opponents.isEmpty { advanceWave() }
    }

    private func applyDamageToOpponents(damage: Double) {
        guard !opponents.isEmpty else { return }
        // Always hit the first alive opponent
        var updated = opponents
        let newHP = max(0, updated[0].hp - damage)
        updated[0] = WaveOpponent(hp: newHP, maxHP: updated[0].maxHP, name: updated[0].name)

        if newHP <= 0 {
            updated.removeFirst()
        }
        withAnimation { opponents = updated }

        if opponents.isEmpty { advanceWave() }
    }

    private func advanceWave() {
        guard phase == .fighting else { return }
        aiAttackTask?.cancel()
        phase = .waveClear
        waveNumber += 1

        waveBannerTask?.cancel()
        waveBannerTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                phase = .fighting
                playerHP = min(maxPlayerHP, playerHP + 15) // partial heal between waves
                spawnWave()
                scheduleAIAttacks()
            }
        }
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
        withAnimation(.easeOut(duration: 0.06)) { screenShake = 7 }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run { withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { screenShake = 0 } }
        }
    }

    // MARK: - End Game

    private func endGame() {
        guard phase == .fighting || phase == .waveClear else { return }
        cancelAllTasks()
        awardShards()
        saveHighScore()
        withAnimation { phase = .result }
    }

    private func awardShards() {
        guard !shardsAwarded else { return }
        shardsAwarded = true
        // Shards based on score and waves
        let baseShards = score > 0 ? 15 : 15
        let waveBonus = (waveNumber - 1) * 5
        let shards = min(50, baseShards + waveBonus)
        viewModel.profile.evolutionShards += shards
        SaveSystem.saveProfile(viewModel.profile)
    }

    private func saveHighScore() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(score, forKey: highScoreKey)
        }
    }

    private func cancelAllTasks() {
        gameTimerTask?.cancel()
        aiAttackTask?.cancel()
        actionLabelTask?.cancel()
        criticalFlashTask?.cancel()
        waveBannerTask?.cancel()
    }
}
