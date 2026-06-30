import SwiftUI

// MARK: - Phase

private enum SoccerPhase {
    case ready, shooting, result
}

// MARK: - Round Result

private struct SoccerRoundResult {
    let playerScored: Bool
    let aiScored: Bool
    let aimValue: Double      // -1.0 to 1.0
    let power: Double         // 0–100
    let goalieDirection: Int  // -1 left, 0 center, 1 right
}

// MARK: - SoccerGameView

struct SoccerGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // MARK: Game state
    @State private var phase: SoccerPhase = .ready
    @State private var currentRound: Int = 1
    @State private var playerGoals: Int = 0
    @State private var aiGoals: Int = 0
    @State private var roundResults: [SoccerRoundResult] = []
    @State private var isSuddenDeath: Bool = false

    // MARK: Shooting state
    @State private var aimValue: Double = 0.0          // -1 left → +1 right
    @State private var isDragging: Bool = false
    @State private var isHoldingShoot: Bool = false
    @State private var power: Double = 0.0             // 0–100
    @State private var powerDirection: Double = 1.0    // oscillation direction
    @State private var powerTimer: Task<Void, Never>? = nil

    // MARK: Round feedback
    @State private var showRoundFeedback: Bool = false
    @State private var roundFeedbackText: String = ""
    @State private var roundFeedbackColor: Color = .white
    @State private var lastGoalieDir: Int = 0
    @State private var ballAnimOffset: CGSize = .zero
    @State private var ballVisible: Bool = true
    @State private var shotFired: Bool = false

    // MARK: Rewards
    private let XP_CAP: Int = 500
    private let WIN_SHARDS = 50
    private let DRAW_SHARDS = 25
    private let LOSS_SHARDS = 15

    private let accentColor = Color(red: 0.2, green: 0.7, blue: 0.3)

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.1, blue: 0.04), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Penalty Shootout",
                    subtitle: isSuddenDeath ? "SUDDEN DEATH" : "5-Round Shootout · Aim & Fire",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { phase = .shooting }
                )

            case .shooting:
                shootingBody

            case .result:
                let playerWon = playerGoals > aiGoals
                let isDraw = playerGoals == aiGoals
                ResultScreen(
                    winner: playerWon ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: playerGoals,
                    p2Score: aiGoals,
                    title: "Penalty Shootout",
                    accentColor: accentColor,
                    prqGain: playerWon ? 12 : (isDraw ? 5 : 2),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "Goals",
                    modeAttributeValue: Double(playerGoals) / Double(max(currentRound, 1)),
                    onReturn: { dismiss() }
                )
                .onAppear { grantShards(playerWon: playerWon, isDraw: isDraw) }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    powerTimer?.cancel()
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
        .onDisappear { powerTimer?.cancel() }
    }

    // MARK: - Shooting Body

    private var shootingBody: some View {
        VStack(spacing: 0) {
            scoreHeader
                .padding(.top, 8)

            Spacer()

            goalVisual
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            if showRoundFeedback {
                Text(roundFeedbackText)
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(roundFeedbackColor)
                    .shadow(color: roundFeedbackColor.opacity(0.6), radius: 16)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 56)
            }

            aimSliderSection
                .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            powerSection
                .padding(.horizontal, 24)

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Spacer()
                scoreLabel(value: playerGoals, label: "YOU", color: accentColor)
                Text("—")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                scoreLabel(value: aiGoals, label: "OPP", color: .secondary)
                Spacer()
            }

            Text(isSuddenDeath ? "SUDDEN DEATH" : "ROUND \(currentRound) OF 5")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(isSuddenDeath ? .red : accentColor.opacity(0.8))
                .tracking(3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }

    private func scoreLabel(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 44, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))
                .tracking(1)
        }
    }

    // MARK: - Goal Visual

    private var goalVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.1, green: 0.35, blue: 0.15).opacity(0.6))
                .frame(height: 140)

            GoalFrameShape()
                .stroke(Color.white.opacity(0.9), lineWidth: 3)
                .frame(height: 90)
                .padding(.horizontal, 40)

            GoalNetLines()
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                .frame(height: 80)
                .padding(.horizontal, 44)

            SoccerGoalkeeperView(direction: lastGoalieDir, dived: shotFired)
                .frame(width: 40, height: 40)
                .offset(y: -8)

            if !shotFired {
                GeometryReader { geo in
                    Circle()
                        .fill(accentColor.opacity(0.7))
                        .frame(width: 16, height: 16)
                        .shadow(color: accentColor, radius: 6)
                        .position(
                            x: geo.size.width / 2 + CGFloat(aimValue) * (geo.size.width / 2 - 28),
                            y: geo.size.height / 2
                        )
                        .animation(.interactiveSpring(response: 0.15), value: aimValue)
                }
                .frame(height: 90)
                .padding(.horizontal, 40)
            }

            if ballVisible {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(white: 0.65)],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 14
                        )
                    )
                    .frame(width: 24, height: 24)
                    .offset(ballAnimOffset)
                    .animation(.easeOut(duration: 0.35), value: ballAnimOffset)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Aim Slider

    private var aimSliderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AIM")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.cardBackground)
                        .frame(height: 8)
                        .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))

                    let thumbX = geo.size.width / 2 + CGFloat(aimValue) * (geo.size.width / 2 - 14)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, Theme.brandCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .shadow(color: accentColor.opacity(0.5), radius: 8)
                        .position(x: thumbX, y: geo.size.height / 2)
                        .animation(.interactiveSpring(response: 0.15), value: aimValue)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard !shotFired else { return }
                            isDragging = true
                            let raw = (v.location.x / geo.size.width) * 2.0 - 1.0
                            aimValue = max(-1.0, min(1.0, raw))
                        }
                        .onEnded { _ in isDragging = false }
                )
            }
            .frame(height: 28)

            HStack {
                Text("LEFT")
                Spacer()
                Text("CENTER")
                Spacer()
                Text("RIGHT")
            }
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }

    // MARK: - Power Section

    private var powerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("POWER")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.cardBackground)
                            .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: powerGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * CGFloat(power / 100)))
                            .animation(.linear(duration: 0.05), value: power)
                    }
                }
                .frame(height: 12)

                Text("\(Int(power))%")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 40, alignment: .trailing)
            }

            Text("Hold & release to set power, then tap SHOOT")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Shoot button
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        shotFired
                            ? AnyShapeStyle(Color.gray.opacity(0.2))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [accentColor, Theme.brandCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: shotFired ? .clear : accentColor.opacity(0.4), radius: 12)

                Text(shotFired ? "•••" : "SHOOT")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(shotFired ? Color.white.opacity(0.3) : .black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !shotFired, !isHoldingShoot else { return }
                        isHoldingShoot = true
                        startPowerOscillation()
                    }
                    .onEnded { _ in
                        guard !shotFired else { return }
                        isHoldingShoot = false
                        powerTimer?.cancel()
                        powerTimer = nil
                        fireShot()
                    }
            )
            .disabled(shotFired)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }

    private var powerGradient: [Color] {
        if power < 40 { return [Theme.brandCyan, accentColor] }
        if power < 70 { return [accentColor, .yellow] }
        return [.yellow, .orange, .red]
    }

    // MARK: - Game Logic

    private func startPowerOscillation() {
        powerTimer?.cancel()
        power = 0
        powerDirection = 1.0
        powerTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(28))
                if Task.isCancelled { break }
                await MainActor.run {
                    power += powerDirection * 2.5
                    if power >= 100 { power = 100; powerDirection = -1 }
                    if power <= 0  { power = 0;   powerDirection =  1 }
                }
            }
        }
    }

    private func fireShot() {
        let finalAim = aimValue
        let finalPower = power
        let prq = viewModel.effectiveMetrics.prqScore

        // Goalkeeper AI: higher player PRQ = better AI
        let accuracy = 0.45 + (prq / 100.0) * 0.3
        let goaliePrediction: Double = Double.random(in: 0...1) < accuracy
            ? finalAim
            : Double.random(in: -1...1)
        let goalieDir: Int = goaliePrediction < -0.2 ? -1 : (goaliePrediction > 0.2 ? 1 : 0)
        lastGoalieDir = goalieDir

        // Coverage window shrinks with higher PRQ (harder to beat better keeper)
        let coverageWidth = 0.48 - (prq / 100.0) * 0.1
        let goalieCovers = abs(finalAim - Double(goalieDir) * 0.6) < coverageWidth
        let playerScored = !goalieCovers && finalPower > 20

        // AI scores with slight randomness
        let aiScoreChance = 0.55 + (prq / 100.0) * 0.1
        let aiScored = Double.random(in: 0...1) < aiScoreChance

        shotFired = true
        let targetY: CGFloat = playerScored ? -55 : -30
        ballAnimOffset = CGSize(
            width: CGFloat(finalAim) * 80,
            height: targetY
        )

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                if playerScored { playerGoals += 1 }
                if aiScored     { aiGoals += 1 }
                roundResults.append(SoccerRoundResult(
                    playerScored: playerScored, aiScored: aiScored,
                    aimValue: finalAim, power: finalPower, goalieDirection: goalieDir
                ))
                withAnimation(.spring(response: 0.2)) {
                    roundFeedbackText = playerScored ? "GOAL!" : "SAVED!"
                    roundFeedbackColor = playerScored ? accentColor : .red
                    showRoundFeedback = true
                }
            }

            try? await Task.sleep(for: .milliseconds(1100))
            await MainActor.run {
                withAnimation { showRoundFeedback = false }
                advanceRound()
            }
        }
    }

    private func advanceRound() {
        if isSuddenDeath {
            // In sudden death one round decides it
            if playerGoals != aiGoals {
                phase = .result
            } else {
                // Still tied: another sudden death round
                resetRoundState()
                phase = .ready
            }
            return
        }

        if currentRound >= 5 {
            if playerGoals == aiGoals {
                isSuddenDeath = true
                currentRound = 1
                resetRoundState()
                phase = .ready
            } else {
                phase = .result
            }
        } else {
            currentRound += 1
            resetRoundState()
        }
    }

    private func resetRoundState() {
        aimValue = 0
        power = 0
        powerDirection = 1
        isHoldingShoot = false
        shotFired = false
        ballAnimOffset = .zero
        ballVisible = true
        lastGoalieDir = 0
        showRoundFeedback = false
    }

    private func grantShards(playerWon: Bool, isDraw: Bool) {
        let earned = playerWon ? WIN_SHARDS : (isDraw ? DRAW_SHARDS : LOSS_SHARDS)
        viewModel.profile.evolutionShards += min(earned, XP_CAP)
    }
}

// MARK: - Goal Frame Shape

private struct GoalFrameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

// MARK: - Goal Net Lines

private struct GoalNetLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cols = 6
        let rows = 4
        for i in 0...cols {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(cols)
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for i in 0...rows {
            let y = rect.minY + rect.height * CGFloat(i) / CGFloat(rows)
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

// MARK: - Goalkeeper View

private struct SoccerGoalkeeperView: View {
    let direction: Int   // -1, 0, 1
    let dived: Bool

    var diveOffsetX: CGFloat {
        guard dived else { return 0 }
        return CGFloat(direction) * 44
    }

    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.2, green: 0.4, blue: 0.85))
                .frame(width: 22, height: 30)
            // Head
            Circle()
                .fill(Color(red: 0.85, green: 0.65, blue: 0.45))
                .frame(width: 14, height: 14)
                .offset(y: -20)
            // Arms
            if dived {
                Capsule()
                    .fill(Color(red: 0.2, green: 0.4, blue: 0.85))
                    .frame(width: 44, height: 6)
                    .rotationEffect(.degrees(Double(direction) * -15))
            } else {
                HStack(spacing: 18) {
                    Capsule()
                        .fill(Color(red: 0.2, green: 0.4, blue: 0.85))
                        .frame(width: 12, height: 6)
                    Capsule()
                        .fill(Color(red: 0.2, green: 0.4, blue: 0.85))
                        .frame(width: 12, height: 6)
                }
                .offset(y: -4)
            }
        }
        .offset(x: diveOffsetX)
        .animation(.easeOut(duration: 0.22), value: dived)
        .animation(.easeOut(duration: 0.22), value: direction)
    }
}
