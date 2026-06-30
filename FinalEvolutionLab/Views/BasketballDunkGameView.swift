import SwiftUI

// MARK: - Dunk Style Definition

private struct DunkStyle: Identifiable {
    let id: String
    let name: String
    let icon: String
    let difficulty: Double          // 0.5 – 1.0
    let swipeHint: String           // shown during EXECUTION phase
    let crowdPeak: Double           // 0.6 – 1.0, crowd ceiling for this style

    static let all: [DunkStyle] = [
        DunkStyle(id: "power_slam",    name: "Power Slam",    icon: "bolt.fill",
                  difficulty: 0.55, swipeHint: "POWER UP",    crowdPeak: 0.75),
        DunkStyle(id: "windmill",      name: "Windmill",      icon: "wind",
                  difficulty: 0.80, swipeHint: "SPIN IT",     crowdPeak: 0.90),
        DunkStyle(id: "three_sixty",   name: "360",           icon: "arrow.trianglehead.2.clockwise.rotate.90",
                  difficulty: 0.85, swipeHint: "FULL SPIN",   crowdPeak: 0.92),
        DunkStyle(id: "tomahawk",      name: "Tomahawk",      icon: "flame.fill",
                  difficulty: 0.70, swipeHint: "SLAM DOWN",   crowdPeak: 0.82),
        DunkStyle(id: "alley_oop",     name: "Alley-Oop",     icon: "person.2.fill",
                  difficulty: 0.75, swipeHint: "CATCH & JAM", crowdPeak: 0.88),
        DunkStyle(id: "reverse",       name: "Reverse",       icon: "arrow.uturn.backward",
                  difficulty: 0.72, swipeHint: "REVERSE IT",  crowdPeak: 0.83),
        DunkStyle(id: "between_legs",  name: "Between-Legs",  icon: "arrow.down.forward.and.arrow.up.backward",
                  difficulty: 0.90, swipeHint: "THREAD IT",   crowdPeak: 0.96),
    ]
}

// MARK: - Round Result

private struct RoundResult {
    let round: Int
    let style: DunkStyle
    let j1: Int
    let j2: Int
    let j3: Int
    let total: Int
    let message: String
    let isPerfect: Bool
    let aiScore: Int
    let playerWon: Bool
}

// MARK: - Game Phase

private enum DunkGamePhase {
    case ready
    case styleSelect
    case approach
    case execution
    case judgeReveal
    case roundTransition
    case result
}

// MARK: - Constants

private let XP_CAP_PER_SESSION = 500
private let TOTAL_ROUNDS = 3

// MARK: - Main View

struct BasketballDunkGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // MARK: Phase
    @State private var phase: DunkGamePhase = .ready
    @State private var currentRound: Int = 1

    // MARK: Style Selection
    @State private var selectedStyle: DunkStyle = DunkStyle.all[0]

    // MARK: Approach (Power Bar)
    @State private var powerLevel: Double = 0.0         // 0–100
    @State private var powerFilling: Bool = false
    @State private var powerTask: Task<Void, Never>?
    @State private var approachReleased: Bool = false
    @State private var approachQuality: Double = 0.0    // 0–1; how close to 78-90%

    // MARK: Execution (Swipe)
    @State private var swipeDragOffset: CGSize = .zero
    @State private var swipeRegistered: Bool = false
    @State private var executionQuality: Double = 0.0   // 0–1
    @State private var swipeFlash: Bool = false

    // MARK: Judge Scoring
    @State private var judgeScoresRevealed: [Bool] = [false, false, false]
    @State private var judgeRevealTask: Task<Void, Never>?
    @State private var currentJ1: Int = 0
    @State private var currentJ2: Int = 0
    @State private var currentJ3: Int = 0
    @State private var currentMessage: String = ""
    @State private var isPerfect: Bool = false
    @State private var perfectFlash: Bool = false

    // MARK: Crowd
    @State private var crowdLevel: Double = 0.0         // 0–1, animated

    // MARK: Score Tracking
    @State private var playerRoundScores: [RoundResult] = []
    @State private var aiRoundScores: [Int] = []
    @State private var playerTotal: Int = 0
    @State private var aiTotal: Int = 0

    // MARK: Shard Award
    @State private var shardsAwarded: Bool = false

    // accent from GameMode (brandCyan for dunk contest)
    private var accent: Color { gameMode.accentColor }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.06, blue: 0.12), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Dunk Contest",
                    subtitle: "3 rounds · Select style · Impress the judges",
                    countdown: 3,
                    accentColor: accent,
                    onComplete: { phase = .styleSelect }
                )

            case .styleSelect:
                styleSelectScreen

            case .approach:
                approachScreen

            case .execution:
                executionScreen

            case .judgeReveal:
                judgeRevealScreen

            case .roundTransition:
                roundTransitionOverlay

            case .result:
                resultScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    powerTask?.cancel()
                    judgeRevealTask?.cancel()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("EXIT")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                    }
                    .foregroundStyle(accent)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear {
            powerTask?.cancel()
            judgeRevealTask?.cancel()
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        HStack(spacing: 16) {
            scorePill(label: "YOU", value: "\(playerTotal)", color: accent)
            Spacer()
            Text("ROUND \(currentRound) / \(TOTAL_ROUNDS)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)
            Spacer()
            scorePill(label: "KAI NEXUS", value: "\(aiTotal)", color: .red)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func scorePill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 0.5))
        )
    }

    // MARK: - Style Select Screen

    private var styleSelectScreen: some View {
        VStack(spacing: 0) {
            scoreHeader
                .padding(.top, 12)

            Spacer().frame(height: 20)

            Text("SELECT YOUR DUNK")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .tracking(4)

            Text("Round \(currentRound)")
                .font(.system(size: 28, weight: .black))
                .italic()
                .foregroundStyle(.white)
                .padding(.top, 4)

            Spacer().frame(height: 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DunkStyle.all) { style in
                        dunkStyleCard(style: style, isSelected: selectedStyle.id == style.id)
                            .onTapGesture { selectedStyle = style }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            Spacer().frame(height: 24)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: selectedStyle.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedStyle.name.uppercased())
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        difficultyBar(difficulty: selectedStyle.difficulty)
                            .frame(width: 120)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EXECUTION CUE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                        Text(selectedStyle.swipeHint)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(accent)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 0.5))
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                withAnimation { phase = .approach }
                resetApproach()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "figure.highintensity.intervaltraining")
                    Text("APPROACH THE RIM")
                }
                .font(.system(.subheadline, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(accent)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: accent.opacity(0.35), radius: 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func dunkStyleCard(style: DunkStyle, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? accent.opacity(0.18) : Color.white.opacity(0.04))
                    .frame(width: 54, height: 54)
                Circle()
                    .strokeBorder(isSelected ? accent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 0.5)
                    .frame(width: 54, height: 54)
                Image(systemName: style.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? accent : .white.opacity(0.4))
            }
            Text(style.name)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(isSelected ? accent : .white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(width: 72)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 84)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? accent.opacity(0.06) : Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? accent.opacity(0.3) : Theme.cardBorder, lineWidth: 1))
        )
        .animation(.spring(response: 0.2), value: isSelected)
    }

    private func difficultyBar(difficulty: Double) -> some View {
        HStack(spacing: 4) {
            Text("DIFF")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                    Capsule()
                        .fill(difficultyColor(difficulty))
                        .frame(width: geo.size.width * difficulty, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func difficultyColor(_ d: Double) -> Color {
        if d >= 0.85 { return .red }
        if d >= 0.70 { return .orange }
        return Theme.foundationGreen
    }

    // MARK: - Approach Screen

    private var approachScreen: some View {
        VStack(spacing: 0) {
            scoreHeader.padding(.top, 12)
            Spacer()

            styleTag(style: selectedStyle)
            Spacer().frame(height: 24)

            Text("HOLD TO BUILD POWER")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accent.opacity(0.8))
                .tracking(3)

            Text("Release in the sweet spot")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer().frame(height: 32)

            // Power Bar
            GeometryReader { geo in
                let barW = geo.size.width - 48
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 52)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: powerBarColors(powerLevel),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barW * CGFloat(powerLevel / 100.0), height: 52)
                        .animation(.linear(duration: 0.05), value: powerLevel)

                    // Sweet spot zone (78–90%)
                    let zoneStart = barW * 0.78
                    let zoneW = barW * 0.12
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.22))
                        .frame(width: zoneW, height: 52)
                        .offset(x: zoneStart)
                    Text("SWEET SPOT")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(0.9))
                        .offset(x: zoneStart + 4, y: -4)
                        .frame(maxHeight: .infinity, alignment: .center)

                    HStack {
                        Spacer()
                        Text(String(format: "%.0f%%", powerLevel))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.trailing, 16)
                    }
                }
                .frame(height: 52)
                .padding(.horizontal, 24)
            }
            .frame(height: 52)

            Spacer().frame(height: 48)

            // Hold/Release button
            ZStack {
                Circle()
                    .fill(powerFilling ? accent.opacity(0.15) : Color.white.opacity(0.05))
                    .frame(width: 130, height: 130)
                Circle()
                    .strokeBorder(powerFilling ? accent : Color.white.opacity(0.18), lineWidth: 3)
                    .frame(width: 130, height: 130)
                    .scaleEffect(powerFilling ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: powerFilling)

                VStack(spacing: 6) {
                    Image(systemName: powerFilling ? "hand.raised.fill" : "hand.tap.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(powerFilling ? accent : .white.opacity(0.5))
                    Text(powerFilling ? "RELEASE!" : "HOLD")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(powerFilling ? accent : .white.opacity(0.5))
                        .tracking(2)
                }
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !powerFilling && !approachReleased { startCharge() }
                    }
                    .onEnded { _ in releasePower() }
            )

            Spacer()
        }
    }

    // MARK: - Execution Screen

    private var executionScreen: some View {
        VStack(spacing: 0) {
            scoreHeader.padding(.top, 12)
            Spacer()

            styleTag(style: selectedStyle)
            Spacer().frame(height: 20)

            Text(selectedStyle.swipeHint)
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.5), radius: 18)
                .scaleEffect(swipeFlash ? 1.1 : 1.0)
                .animation(.spring(response: 0.2), value: swipeFlash)

            Text("SWIPE TO EXECUTE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)
                .padding(.top, 8)

            Spacer().frame(height: 36)

            // Swipe target zone
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(accent.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(accent.opacity(swipeRegistered ? 0.7 : 0.2), lineWidth: 2)
                    )
                    .frame(width: 230, height: 230)
                    .scaleEffect(swipeRegistered ? 1.04 : 1.0)
                    .animation(.spring(response: 0.25), value: swipeRegistered)

                VStack(spacing: 14) {
                    Image(systemName: swipeRegistered ? "checkmark.circle.fill" : selectedStyle.icon)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(swipeRegistered ? .green : accent.opacity(0.75))

                    Text(swipeRegistered ? "EXECUTED!" : "SWIPE HERE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(swipeRegistered ? .green : accent.opacity(0.6))
                        .tracking(2)
                }

                if !swipeRegistered {
                    Circle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 38, height: 38)
                        .offset(swipeDragOffset)
                        .animation(.interactiveSpring(), value: swipeDragOffset)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard !swipeRegistered else { return }
                        swipeDragOffset = value.translation
                    }
                    .onEnded { value in
                        guard !swipeRegistered else { return }
                        registerSwipe(translation: value.translation)
                    }
            )

            Spacer().frame(height: 28)

            HStack(spacing: 10) {
                Text("POWER")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                miniBar(value: approachQuality, color: accent)
                    .frame(width: 100)
                Text(String(format: "%.0f%%", approachQuality * 100))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }

    // MARK: - Judge Reveal Screen

    private var judgeRevealScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreHeader.padding(.top, 16)

                if isPerfect && perfectFlash {
                    Text("PERFECT EXECUTION")
                        .font(.system(size: 19, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.7), radius: 20)
                        .tracking(3)
                        .transition(.scale.combined(with: .opacity))
                }

                styleTag(style: selectedStyle)

                // Crowd meter
                VStack(spacing: 6) {
                    HStack {
                        Text("CROWD ENERGY")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(crowdLabel)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(accent)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06)).frame(height: 10)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.brandBlue, accent, .yellow.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * crowdLevel, height: 10)
                                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: crowdLevel)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.horizontal, 24)

                // Judge panels
                VStack(spacing: 12) {
                    Text("JUDGE SCORES")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(3)

                    HStack(spacing: 12) {
                        judgeCard(label: "JUDGE 1", score: currentJ1,
                                  revealed: safeRevealedState(0))
                        judgeCard(label: "JUDGE 2", score: currentJ2,
                                  revealed: safeRevealedState(1))
                        judgeCard(label: "JUDGE 3", score: currentJ3,
                                  revealed: safeRevealedState(2))
                    }
                    .padding(.horizontal, 20)
                }

                // Round total (after all revealed)
                if judgeScoresRevealed.allSatisfy({ $0 }) {
                    let roundTotal = currentJ1 + currentJ2 + currentJ3
                    VStack(spacing: 6) {
                        Text("\(roundTotal)")
                            .font(.system(size: 60, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: accent.opacity(0.4), radius: 16)
                            .contentTransition(.numericText())

                        Text(currentMessage)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(accent)
                            .tracking(2)

                        Text("ROUND \(currentRound) SCORE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(2)
                    }
                    .padding(.vertical, 8)
                    .transition(.scale.combined(with: .opacity))

                    if let lastAI = aiRoundScores.last {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                            Text("KAI NEXUS scored \(lastAI) this round")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }

                // Round history
                if !playerRoundScores.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SCOREBOARD")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(2)
                            .padding(.leading, 4)

                        ForEach(playerRoundScores, id: \.round) { r in
                            roundHistoryRow(result: r)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
        }
    }

    private func safeRevealedState(_ index: Int) -> Bool {
        guard judgeScoresRevealed.indices.contains(index) else { return false }
        return judgeScoresRevealed[index]
    }

    private var crowdLabel: String {
        if crowdLevel >= 0.9 { return "ON FIRE" }
        if crowdLevel >= 0.75 { return "ELECTRIC" }
        if crowdLevel >= 0.60 { return "HYPED" }
        if crowdLevel >= 0.40 { return "BUILDING" }
        return "WARMING UP"
    }

    private func judgeCard(label: String, score: Int, revealed: Bool) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(revealed ? accent.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(revealed ? accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .frame(height: 72)

                if revealed {
                    Text("\(score)")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                } else {
                    Text("?")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.12))
                }
            }

            if revealed {
                miniBar(value: Double(score) / 10.0, color: judgeScoreColor(score))
            } else {
                miniBar(value: 0, color: accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func judgeScoreColor(_ score: Int) -> Color {
        if score >= 9 { return .yellow }
        if score >= 7 { return Theme.brandCyan }
        if score >= 5 { return .green }
        return .red
    }

    private func roundHistoryRow(result: RoundResult) -> some View {
        HStack(spacing: 10) {
            Text("R\(result.round)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .frame(width: 24)

            Image(systemName: result.style.icon)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20)

            Text(result.style.name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Text("\(result.j1)+\(result.j2)+\(result.j3)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("\(result.total)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 36)

            Image(systemName: result.playerWon ? "arrow.up.circle.fill" : "arrow.down.circle")
                .font(.system(size: 12))
                .foregroundStyle(result.playerWon ? .green : .red)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 0.5))
        )
    }

    // MARK: - Round Transition

    private var roundTransitionOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea().background(.ultraThinMaterial.opacity(0.4))

            VStack(spacing: 16) {
                if let last = playerRoundScores.last {
                    Text(last.playerWon ? "ROUND WON" : "ROUND LOST")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(last.playerWon ? .green : .red)
                        .tracking(3)
                }

                Text("ROUND \(currentRound) of \(TOTAL_ROUNDS)")
                    .font(.system(size: 34, weight: .black))
                    .italic()
                    .foregroundStyle(.white)

                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text("\(playerTotal)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(accent)
                        Text("YOU")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text("VS")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    VStack(spacing: 2) {
                        Text("\(aiTotal)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(.red)
                        Text("KAI")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    withAnimation { phase = .styleSelect }
                } label: {
                    Text("CONTINUE")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(accent)
                        .clipShape(.rect(cornerRadius: 14))
                        .shadow(color: accent.opacity(0.3), radius: 10)
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        let winner: ResultScreen.ResultWinner = {
            if playerTotal > aiTotal { return .p1 }
            if playerTotal < aiTotal { return .p2 }
            return .draw
        }()

        return ResultScreen(
            winner: winner,
            p1Score: playerTotal,
            p2Score: aiTotal,
            title: "Dunk Contest",
            accentColor: accent,
            prqGain: PRQ.modeReward(
                mode: .basketballDunkContest,
                won: playerTotal > aiTotal,
                tied: playerTotal == aiTotal,
                combo: playerRoundScores.filter(\.playerWon).count,
                criticals: playerRoundScores.filter(\.isPerfect).count,
                scoreDifferential: max(0, playerTotal - aiTotal)
            ),
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: PRQ.attributeLabel(for: .basketballDunkContest),
            modeAttributeValue: PRQ.attributeValue(prq: viewModel.effectiveMetrics.prqScore, for: .basketballDunkContest),
            onReturn: {
                awardShards(winner: winner)
                dismiss()
            }
        )
    }

    // MARK: - Shared Sub-Views

    private func styleTag(style: DunkStyle) -> some View {
        HStack(spacing: 8) {
            Image(systemName: style.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
            Text(style.name.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .tracking(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(accent.opacity(0.08))
                .overlay(Capsule().stroke(accent.opacity(0.2), lineWidth: 1))
        )
    }

    private func miniBar(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06)).frame(height: 4)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, value)), height: 4)
                    .animation(.spring(response: 0.4), value: value)
            }
        }
        .frame(height: 4)
    }

    private func powerBarColors(_ level: Double) -> [Color] {
        if level >= 78 { return [Theme.foundationGreen, .green, .yellow] }
        if level >= 55 { return [Theme.brandBlue, accent] }
        return [.white.opacity(0.3), .white.opacity(0.55)]
    }

    // MARK: - Game Logic

    private func resetApproach() {
        powerLevel = 0
        approachReleased = false
        powerFilling = false
    }

    private func startCharge() {
        guard !powerFilling, !approachReleased else { return }
        powerFilling = true
        powerTask?.cancel()
        powerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard powerFilling else { return }
                    powerLevel = min(100, powerLevel + 1.6)
                    if powerLevel >= 100 { releasePower() }
                }
            }
        }
    }

    private func releasePower() {
        guard !approachReleased else { return }
        approachReleased = true
        powerFilling = false
        powerTask?.cancel()

        // Quality: perfect at 78–90%, degrades outside
        let p = powerLevel
        let quality: Double
        switch p {
        case 78...90:
            quality = 1.0
        case 65..<78:
            quality = 0.7 + (p - 65) / 13.0 * 0.3
        case 90..<100:
            quality = 1.0 - (p - 90) / 10.0 * 0.4
        case 40..<65:
            quality = 0.3 + (p - 40) / 25.0 * 0.4
        default:
            quality = max(0.1, p / 100.0 * 0.3)
        }
        approachQuality = quality

        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await MainActor.run {
                swipeRegistered = false
                swipeDragOffset = .zero
                executionQuality = 0
                phase = .execution
            }
        }
    }

    private func registerSwipe(translation: CGSize) {
        guard !swipeRegistered else { return }

        let mag = sqrt(translation.width * translation.width + translation.height * translation.height)
        let magQ = min(1.0, mag / 160.0)
        let directionQ = swipeDirectionQuality(style: selectedStyle, translation: translation)
        executionQuality = magQ * 0.4 + directionQ * 0.6

        swipeRegistered = true
        swipeFlash = true
        swipeDragOffset = .zero

        Task {
            try? await Task.sleep(for: .milliseconds(180))
            await MainActor.run { swipeFlash = false }
            try? await Task.sleep(for: .milliseconds(480))
            await MainActor.run { scoreRound() }
        }
    }

    private func swipeDirectionQuality(style: DunkStyle, translation: CGSize) -> Double {
        let tx = translation.width
        let ty = translation.height
        let total = abs(tx) + abs(ty) + 1

        switch style.id {
        case "power_slam", "tomahawk", "alley_oop":
            return max(0, -ty) / total          // upward
        case "windmill", "three_sixty":
            return abs(tx) / total              // lateral / circular
        case "reverse":
            return max(0, ty) / total           // downward
        case "between_legs":
            return min(1.0, sqrt(tx * tx + ty * ty) / 130.0)
        default:
            return 0.6
        }
    }

    private func scoreRound() {
        let combinedQ = approachQuality * 0.45 + executionQuality * 0.55
        let styleDiff = selectedStyle.difficulty

        let perfect = approachQuality >= 0.92 && executionQuality >= 0.88
        isPerfect = perfect

        let prqBoost = min(1.0, viewModel.effectiveMetrics.prqScore / 100.0)
        let rawBase = 4.0 + combinedQ * 4.0 * styleDiff + prqBoost * 1.0
        let base = min(10, max(1, Int(rawBase.rounded())))

        // Perfect bonus: +1 per judge
        let perfBonus = perfect ? 1 : 0
        let j1 = min(10, base + perfBonus + Int.random(in: 0...1))
        let j2 = min(10, base + perfBonus + Int.random(in: 0...1))
        let j3 = min(10, base + perfBonus + Int.random(in: 0...1))
        let roundTotal = j1 + j2 + j3

        let msg: String
        if perfect           { msg = "PERFECT EXECUTION" }
        else if roundTotal >= 27 { msg = "LEGENDARY!" }
        else if roundTotal >= 23 { msg = "CROWD GOES WILD!" }
        else if roundTotal >= 19 { msg = "POWERFUL!" }
        else if roundTotal >= 15 { msg = "SOLID DUNK" }
        else                     { msg = "NEEDS WORK" }

        // AI competitor: base 18–27 out of 30
        let aiScore = Int.random(in: 18...27)
        let playerWon = roundTotal > aiScore

        currentJ1 = j1
        currentJ2 = j2
        currentJ3 = j3
        currentMessage = msg

        let result = RoundResult(
            round: currentRound,
            style: selectedStyle,
            j1: j1, j2: j2, j3: j3,
            total: roundTotal,
            message: msg,
            isPerfect: perfect,
            aiScore: aiScore,
            playerWon: playerWon
        )
        playerRoundScores.append(result)
        aiRoundScores.append(aiScore)
        playerTotal += roundTotal
        aiTotal += aiScore

        judgeScoresRevealed = [false, false, false]
        crowdLevel = 0
        phase = .judgeReveal

        if perfect {
            withAnimation(.spring(response: 0.3)) { perfectFlash = true }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run { withAnimation { perfectFlash = false } }
            }
        }

        startJudgeReveal(combinedQ: combinedQ, styleDiff: styleDiff)
    }

    private func startJudgeReveal(combinedQ: Double, styleDiff: Double) {
        judgeRevealTask?.cancel()
        judgeRevealTask = Task {
            for i in 0..<3 {
                try? await Task.sleep(for: .milliseconds(600 + Int64(i) * 420))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        judgeScoresRevealed[i] = true
                    }
                }
            }
            // Animate crowd after all scores appear
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                let target = min(1.0, (combinedQ * 0.6 + styleDiff * 0.4) * selectedStyle.crowdPeak)
                withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
                    crowdLevel = target
                }
            }
            // Auto-advance after 4.2 s
            try? await Task.sleep(for: .seconds(4.2))
            guard !Task.isCancelled else { return }
            await MainActor.run { advanceAfterReveal() }
        }
    }

    private func advanceAfterReveal() {
        if currentRound >= TOTAL_ROUNDS {
            phase = .result
        } else {
            currentRound += 1
            phase = .roundTransition
        }
    }

    private func awardShards(winner: ResultScreen.ResultWinner) {
        guard !shardsAwarded else { return }
        shardsAwarded = true
        let shards: Int
        switch winner {
        case .p1:   shards = 50
        case .draw: shards = 25
        case .p2:   shards = 15
        }
        viewModel.profile.evolutionShards += shards
    }
}
