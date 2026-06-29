import SwiftUI

struct CourtCarnivalView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @State private var phase: CarnivalPhase = .ready
    @State private var playerScore = 0
    @State private var currentMiniGame = 0
    @State private var miniGameResult: MiniGameResult? = nil
    @State private var timeRemaining = 10
    @State private var tapCount = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var spinAngle: Double = 0
    @State private var spinTask: Task<Void, Never>?
    @State private var showResult = false
    @State private var resultText = ""

    private enum CarnivalPhase { case ready, spinning, playing, result }
    private struct MiniGameResult { let won: Bool; let points: Int; let label: String }

    private let miniGames: [CarnivalGame] = CarnivalGame.all

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.04, blue: 0.18), Color(red: 0.02, green: 0.02, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: gameMode.name,
                    subtitle: "Spin the wheel · 5 mini-games · Win the carnival",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { phase = .spinning; spinWheel() }
                )
            case .spinning:
                spinningBody
            case .playing:
                playingBody
            case .result:
                ResultScreen(
                    winner: playerScore >= 30 ? .p1 : .p2,
                    p1Score: playerScore,
                    p2Score: 50 - playerScore,
                    title: "Court Carnival",
                    accentColor: gameMode.accentColor,
                    prqGain: playerScore >= 30 ? 8 : 2,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "CARNIVAL",
                    modeAttributeValue: Double(playerScore) / 50.0,
                    onReturn: { dismiss() }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { timerTask?.cancel(); spinTask?.cancel() }
    }

    private var spinningBody: some View {
        VStack(spacing: 32) {
            Text("GAME \(currentMiniGame + 1)/\(miniGames.count)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(gameMode.accentColor)
                .tracking(3)

            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let colors: [Color] = [.yellow, .orange, .pink, .green, gameMode.accentColor, .purple]
                    Circle()
                        .trim(from: CGFloat(i) / 6.0, to: CGFloat(i + 1) / 6.0)
                        .stroke(colors[i], lineWidth: 48)
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(spinAngle))
                }
                Circle().fill(Theme.cardBackground).frame(width: 60, height: 60)
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.system(size: 24))
            }
            .animation(.easeOut(duration: 2.0), value: spinAngle)

            Text("SPINNING…").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var playingBody: some View {
        let game = miniGames[currentMiniGame]
        return VStack(spacing: 0) {
            HStack {
                Text("SCORE: \(playerScore)").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(.white)
                Spacer()
                Text("GAME \(currentMiniGame + 1)/\(miniGames.count)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(gameMode.accentColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3).fill(timeRemaining > 4 ? gameMode.accentColor : Color.red)
                        .frame(width: geo.size.width * CGFloat(timeRemaining) / CGFloat(game.timeLimit))
                        .animation(.linear(duration: 1), value: timeRemaining)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(game.color.opacity(0.12)).frame(width: 72, height: 72)
                    Image(systemName: game.icon).font(.system(size: 28, weight: .bold)).foregroundStyle(game.color)
                }
                Text(game.title.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(game.color)
                    .tracking(2)
                Text(game.instruction)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if game.mechanic == .tap {
                    Text("\(tapCount) taps")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(game.color)
                        .contentTransition(.numericText())
                    Text("Target: \(game.target)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground).overlay(RoundedRectangle(cornerRadius: 20).stroke(game.color.opacity(0.2), lineWidth: 1)))
            .padding(.horizontal, 24)

            Spacer()

            if showResult, let res = miniGameResult {
                VStack(spacing: 8) {
                    Text(res.won ? "🏆 +\(res.points) pts" : "✗ Next game…")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(res.won ? .yellow : .red)
                    Text(res.label).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)
            } else if game.mechanic == .tap {
                Button { tapCount += 1 } label: {
                    Text("TAP!")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(game.color)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func spinWheel() {
        let spinDegrees = Double.random(in: 720...1440)
        spinTask = Task {
            await MainActor.run { spinAngle += spinDegrees }
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run { startMiniGame() }
        }
    }

    private func startMiniGame() {
        let game = miniGames[currentMiniGame]
        phase = .playing
        tapCount = 0
        showResult = false
        miniGameResult = nil
        timeRemaining = game.timeLimit
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeRemaining -= 1 }
            }
            await MainActor.run { evaluateMiniGame() }
        }
    }

    private func evaluateMiniGame() {
        timerTask?.cancel()
        let game = miniGames[currentMiniGame]
        let won: Bool
        let pts: Int
        let label: String
        switch game.mechanic {
        case .tap:
            won = tapCount >= game.target
            pts = won ? 10 : 0
            label = won ? "\(tapCount) taps — target met!" : "\(tapCount)/\(game.target) taps"
        case .auto:
            won = Double.random(in: 0...1) < 0.65
            pts = won ? 10 : 0
            label = won ? "Challenge cleared!" : "Close — keep going"
        }
        if won { playerScore += pts }
        miniGameResult = MiniGameResult(won: won, points: pts, label: label)
        showResult = true
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run { advanceMiniGame() }
        }
    }

    private func advanceMiniGame() {
        if currentMiniGame + 1 >= miniGames.count {
            phase = .result
        } else {
            currentMiniGame += 1
            phase = .spinning
            spinWheel()
        }
    }
}

struct CarnivalGame {
    enum Mechanic { case tap, auto }
    let title: String
    let instruction: String
    let icon: String
    let color: Color
    let mechanic: Mechanic
    let timeLimit: Int
    let target: Int

    static let all: [CarnivalGame] = [
        CarnivalGame(title: "Speed Dribble", instruction: "Tap as fast as you can to out-dribble your opponent!", icon: "figure.basketball", color: Color(red: 1, green: 0.6, blue: 0), mechanic: .tap, timeLimit: 8, target: 20),
        CarnivalGame(title: "Sprint Burst", instruction: "Rapid taps — first to 25 reps wins the lane!", icon: "figure.run", color: .green, mechanic: .tap, timeLimit: 10, target: 25),
        CarnivalGame(title: "Jump Timing", instruction: "Nail the timing — the arena is watching!", icon: "arrow.up.circle.fill", color: .cyan, mechanic: .auto, timeLimit: 6, target: 0),
        CarnivalGame(title: "Rally Strike", instruction: "Tap each hit before the ball bounces twice!", icon: "tennis.racket", color: .yellow, mechanic: .tap, timeLimit: 8, target: 18),
        CarnivalGame(title: "Trick Shot", instruction: "The pressure's on — clutch the angle!", icon: "basketball.fill", color: Color(red: 0.95, green: 0.49, blue: 0.15), mechanic: .auto, timeLimit: 5, target: 0),
    ]
}
