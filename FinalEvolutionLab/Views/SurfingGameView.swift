import SwiftUI

// MARK: - Phase

private enum SurfingPhase {
    case ready, paddleIn, riding, trickWindow, wipeout, waveResult, heatResult, result
}

// MARK: - Trick Type

private enum SurfTrick: String, CaseIterable {
    case aerial   = "AERIAL"
    case tube     = "TUBE RIDE"
    case cutback  = "CUTBACK"

    var points: Int {
        switch self {
        case .aerial:  return 8
        case .tube:    return 10
        case .cutback: return 6
        }
    }

    var systemImage: String {
        switch self {
        case .aerial:  return "arrow.up.circle.fill"
        case .tube:    return "arrow.down.circle.fill"
        case .cutback: return "arrow.turn.up.right"
        }
    }

    var swipeHint: String {
        switch self {
        case .aerial:  return "SWIPE ↑"
        case .tube:    return "SWIPE ↓"
        case .cutback: return "SWIPE ↗ / ↙"
        }
    }
}

// MARK: - Wave Score

private struct WaveScore: Identifiable {
    let id = UUID()
    let waveNumber: Int
    var rawScore: Double       // trick points × balance multiplier
    var wipeout: Bool
    var finalScore: Double { wipeout ? 0 : rawScore }
}

// MARK: - SurfingGameView

struct SurfingGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // Phase state
    @State private var phase: SurfingPhase = .ready
    @State private var waveNumber: Int = 1

    // Wave / balance mechanics
    @State private var wavePower: Double = 0.0        // 0–1, fills then peaks
    @State private var balanceMeter: Double = 0.5     // 0–1 (0.5 = center)
    @State private var balanceOffCenterTime: Double = 0
    @State private var wipeoutTriggered: Bool = false

    // Trick window
    @State private var trickWindowOpen: Bool = false
    @State private var trickWindowTimeLeft: Double = 4.0
    @State private var performedTrick: SurfTrick? = nil
    @State private var showTrickFlash: Bool = false
    @State private var trickFlashText: String = ""

    // Timers
    @State private var heatClock: Double = 20.0       // seconds per wave
    @State private var waveTimer: Task<Void, Never>?
    @State private var balanceDriftTimer: Task<Void, Never>?
    @State private var wavePowerTimer: Task<Void, Never>?

    // Scoring
    @State private var waveScores: [WaveScore] = []
    @State private var currentWaveScore: Double = 0
    @State private var currentBalanceMultiplier: Double = 1.0
    @State private var trickAccumulator: Int = 0
    @State private var showCurrentWavePts: Bool = false

    // AI & reward
    @State private var frozenAIScore: Double = 0
    @State private var rewardApplied: Bool = false

    // Paddle-in animation
    @State private var paddleProgress: Double = 0.0

    private let accentColor = Color(red: 0.2, green: 0.75, blue: 1.0)
    private let totalWaves = 3

    // Best 2 of 3 scoring
    private var heat1Score: Double {
        let valid = waveScores.sorted(by: { $0.finalScore > $1.finalScore })
        let top2 = valid.prefix(2)
        return top2.reduce(0) { $0 + $1.finalScore }
    }

    private var playerWins: Bool { heat1Score > frozenAIScore }
    private var isDraw: Bool { Int(heat1Score) == Int(frozenAIScore) }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.01, green: 0.06, blue: 0.20), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Surfing",
                    subtitle: "3 waves · Best 2 of 3 · Balance + Trick",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: {
                        frozenAIScore = Double(Int.random(in: 22...42))
                        startPaddleIn()
                    }
                )

            case .paddleIn:
                paddleInBody

            case .riding, .trickWindow:
                ridingBody

            case .wipeout:
                wipeoutBody

            case .waveResult:
                waveResultBody

            case .heatResult:
                heatResultBody

            case .result:
                ResultScreen(
                    winner: playerWins ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: Int(heat1Score),
                    p2Score: Int(frozenAIScore),
                    title: "Surfing",
                    accentColor: accentColor,
                    prqGain: playerWins ? 14 : (isDraw ? 5 : 3),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "Wave Score",
                    modeAttributeValue: min(1.0, heat1Score / 40.0),
                    onReturn: { dismiss() }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { cancelAllTimers(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { cancelAllTimers() }
    }

    // MARK: - Paddle In Body

    private var paddleInBody: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("WAVE \(waveNumber)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .tracking(4)

            Text("PADDLING OUT")
                .font(.system(size: 28, weight: .black))
                .italic()
                .foregroundStyle(.white)

            // Wave approach indicator
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Theme.brandCyan, accentColor],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, CGFloat(paddleProgress) * (UIScreen.main.bounds.width - 80)), height: 16)
                    .animation(.easeInOut(duration: 0.1), value: paddleProgress)
            }
            .padding(.horizontal, 40)

            Image(systemName: "water.waves")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [accentColor, Theme.brandCyan], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.variableColor.iterative, options: .speed(1.2))

            Spacer()
        }
    }

    // MARK: - Riding Body

    private var ridingBody: some View {
        VStack(spacing: 0) {
            // Top HUD
            ridingHUD
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer()

            // Center area: wave power + balance
            HStack(alignment: .center, spacing: 20) {
                // Wave power meter (vertical, left side)
                wavePowerMeter
                    .padding(.leading, 24)

                Spacer()

                // Main riding area
                VStack(spacing: 20) {
                    if phase == .trickWindow {
                        trickWindowPanel
                    } else {
                        ridingStatusPanel
                    }

                    // Balance indicator
                    balanceIndicator
                }
                .padding(.trailing, 20)
            }

            Spacer()

            // Balance control buttons
            balanceControlRow
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .overlay(trickFlashOverlay)
        .gesture(
            DragGesture(minimumDistance: 22)
                .onEnded { val in
                    if phase == .trickWindow { handleTrickSwipe(val.translation) }
                }
        )
    }

    // MARK: - Riding HUD

    private var ridingHUD: some View {
        HStack(spacing: 0) {
            // Wave number + heat clock
            VStack(alignment: .leading, spacing: 3) {
                Text("WAVE \(waveNumber) / \(totalWaves)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(1)
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                        .frame(width: 46, height: 46)
                    Circle()
                        .trim(from: 0, to: CGFloat(heatClock / 20.0))
                        .stroke(heatClock > 8 ? accentColor : .red,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 46, height: 46)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: heatClock)
                    Text(String(format: "%.0f", heatClock))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(heatClock > 8 ? .white : .red)
                }
            }

            Spacer()

            // Current wave score
            VStack(spacing: 2) {
                Text("WAVE SCORE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(1)
                Text(String(format: "%.1f", currentWaveScore))
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Running heat total
            VStack(alignment: .trailing, spacing: 2) {
                Text("HEAT TOTAL")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(1)
                Text(String(format: "%.1f", heat1Score))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
                HStack(spacing: 3) {
                    ForEach(0..<totalWaves, id: \.self) { i in
                        let ws = i < waveScores.count ? waveScores[i] : nil
                        Circle()
                            .fill(ws == nil
                                  ? (i == waveNumber - 1 ? accentColor.opacity(0.5) : Color.white.opacity(0.1))
                                  : (ws!.wipeout ? .red : accentColor))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }

    // MARK: - Wave Power Meter

    private var wavePowerMeter: some View {
        VStack(spacing: 8) {
            Text("WAVE")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(1)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 24, height: 160)
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: wavePower > 0.8
                                ? [.yellow, accentColor]
                                : [accentColor.opacity(0.5), accentColor],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .frame(width: 24, height: max(4, 160 * CGFloat(wavePower)))
                    .animation(.linear(duration: 0.1), value: wavePower)
            }
            Text("\(Int(wavePower * 100))%")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(wavePower > 0.8 ? .yellow : accentColor)
        }
    }

    // MARK: - Balance Indicator

    private var balanceIndicator: some View {
        VStack(spacing: 8) {
            Text("BALANCE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(2)
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 200, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Danger zone indicators
                HStack {
                    Rectangle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 30, height: 18)
                        .cornerRadius(6)
                    Spacer()
                    Rectangle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 30, height: 18)
                        .cornerRadius(6)
                }
                .frame(width: 200)

                // Center mark
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 2, height: 18)

                // Balance indicator ball
                Circle()
                    .fill(
                        balanceMeter < 0.2 || balanceMeter > 0.8
                            ? Color.red
                            : (abs(balanceMeter - 0.5) < 0.1 ? Theme.foundationGreen : accentColor)
                    )
                    .frame(width: 20, height: 20)
                    .shadow(
                        color: (abs(balanceMeter - 0.5) < 0.1 ? Theme.foundationGreen : accentColor).opacity(0.5),
                        radius: 8
                    )
                    .offset(x: (CGFloat(balanceMeter) - 0.5) * 180)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: balanceMeter)
            }
            .frame(width: 200)

            if balanceMeter < 0.2 || balanceMeter > 0.8 {
                Text("LEAN BACK TO CENTER!")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.red)
                    .tracking(1)
            } else if abs(balanceMeter - 0.5) < 0.1 {
                Text("PERFECT BALANCE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.foundationGreen)
                    .tracking(1)
            }
        }
    }

    // MARK: - Riding Status Panel

    private var ridingStatusPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: "water.waves")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [accentColor, Theme.brandCyan], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.variableColor.iterative, options: .speed(1.0))

            Text("RIDING")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .tracking(4)

            if wavePower > 0.75 {
                Text("TRICK WINDOW OPENING...")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .tracking(2)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }

    // MARK: - Trick Window Panel

    private var trickWindowPanel: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .trim(from: 0, to: CGFloat(trickWindowTimeLeft / 4.0))
                    .stroke(
                        trickWindowTimeLeft > 2 ? .yellow : .orange,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: trickWindowTimeLeft)
                Text(String(format: "%.1f", trickWindowTimeLeft))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
            }

            Text("TRICK WINDOW!")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(.yellow)
                .tracking(3)
                .shadow(color: .yellow.opacity(0.5), radius: 10)

            VStack(spacing: 6) {
                ForEach(SurfTrick.allCases, id: \.self) { trick in
                    HStack(spacing: 10) {
                        Image(systemName: trick.systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accentColor)
                            .frame(width: 20)
                        Text("\(trick.swipeHint) — \(trick.rawValue)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text("+\(trick.points) pts")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Balance Controls

    private var balanceControlRow: some View {
        HStack(spacing: 16) {
            // Left tap
            Button {
                adjustBalance(delta: -0.12)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
                        .frame(height: 72)
                    VStack(spacing: 5) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                        Text("LEAN LEFT")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(accentColor)
                }
            }
            .buttonStyle(.plain)

            // Right tap
            Button {
                adjustBalance(delta: 0.12)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
                        .frame(height: 72)
                    VStack(spacing: 5) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                        Text("LEAN RIGHT")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(accentColor)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Trick Flash Overlay

    private var trickFlashOverlay: some View {
        Group {
            if showTrickFlash {
                VStack(spacing: 4) {
                    Text(trickFlashText)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.7), radius: 20)
                    Text("TRICK SCORED!")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.7))
                        .tracking(3)
                }
                .allowsHitTesting(false)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.5), value: showTrickFlash)
    }

    // MARK: - Wipeout Body

    private var wipeoutBody: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(Color.red.opacity(0.1)).frame(width: 110, height: 110)
                Image(systemName: "water.waves.slash")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.red)
            }

            Text("WIPEOUT!")
                .font(.system(size: 38, weight: .black)).italic()
                .foregroundStyle(.red)
                .shadow(color: .red.opacity(0.4), radius: 20)

            Text("Lost balance for too long")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            Text("WAVE \(waveNumber) — 0.0 pts")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(.red)
                .tracking(2)
            Spacer()
        }
    }

    // MARK: - Wave Result Body

    private var waveResultBody: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("WAVE \(waveNumber) COMPLETE")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .tracking(3)

            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 110, height: 110)
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", waveScores.last?.finalScore ?? 0))
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            // Score summary
            VStack(spacing: 10) {
                if let ws = waveScores.last {
                    scoreRow(label: "TRICK POINTS", value: String(format: "%.0f", Double(trickAccumulator)))
                    scoreRow(label: "BALANCE MULTIPLIER", value: String(format: "×%.2f", currentBalanceMultiplier))
                    Divider().background(Theme.cardBorder)
                    scoreRow(label: "WAVE SCORE", value: String(format: "%.1f", ws.finalScore), highlight: true)
                }
                scoreRow(label: "HEAT RUNNING TOTAL", value: String(format: "%.1f", heat1Score))
                if waveNumber < totalWaves {
                    scoreRow(label: "WAVES REMAINING", value: "\(totalWaves - waveNumber)")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
            )
            .padding(.horizontal, 28)

            // Wave dots
            HStack(spacing: 10) {
                ForEach(waveScores) { ws in
                    VStack(spacing: 3) {
                        Circle()
                            .fill(ws.wipeout ? Color.red : accentColor)
                            .frame(width: 14, height: 14)
                        Text(ws.wipeout ? "W/O" : String(format: "%.1f", ws.finalScore))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(ws.wipeout ? .red : .white)
                    }
                }
                if waveScores.count < totalWaves {
                    ForEach(waveScores.count..<totalWaves, id: \.self) { _ in
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 14, height: 14)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Heat Result Body (after all 3 waves, brief summary)

    private var heatResultBody: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("HEAT FINAL")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor).tracking(3)

            VStack(spacing: 8) {
                ForEach(waveScores) { ws in
                    HStack {
                        Text("WAVE \(ws.waveNumber)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if ws.wipeout {
                            Text("WIPEOUT")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.red)
                        } else {
                            Text(String(format: "%.1f", ws.finalScore))
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                    )
                }

                Divider().background(Theme.cardBorder).padding(.vertical, 4)

                HStack {
                    Text("BEST 2 OF 3")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Spacer()
                    Text(String(format: "%.1f", heat1Score))
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 4)

                HStack {
                    Text("AI SCORE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Spacer()
                    Text(String(format: "%.1f", frozenAIScore))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1))
            )
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func scoreRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(1)
            Spacer()
            Text(value)
                .font(.system(size: highlight ? 20 : 14, weight: .black, design: .monospaced))
                .foregroundStyle(highlight ? accentColor : .white)
        }
    }

    // MARK: - Logic

    private func startPaddleIn() {
        phase = .paddleIn
        paddleProgress = 0
        Task {
            for i in 0..<20 {
                try? await Task.sleep(for: .milliseconds(80))
                await MainActor.run { paddleProgress = Double(i + 1) / 20.0 }
            }
            await MainActor.run { beginWave() }
        }
    }

    private func beginWave() {
        wavePower = 0
        balanceMeter = 0.5
        balanceOffCenterTime = 0
        wipeoutTriggered = false
        heatClock = 20.0
        currentWaveScore = 0
        currentBalanceMultiplier = 1.0
        trickAccumulator = 0
        trickWindowOpen = false
        performedTrick = nil
        phase = .riding

        startWavePowerTimer()
        startHeatClock()
        startBalanceDrift()
    }

    private func startWavePowerTimer() {
        wavePowerTimer?.cancel()
        wavePowerTimer = Task {
            // Wave power rises to peak over ~8 seconds
            for i in 0..<80 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    wavePower = min(1.0, Double(i + 1) / 80.0)
                    // Open trick window at peak
                    if wavePower >= 0.8 && !trickWindowOpen && !wipeoutTriggered {
                        openTrickWindow()
                    }
                }
            }
        }
    }

    private func startHeatClock() {
        waveTimer?.cancel()
        waveTimer = Task {
            for i in 0..<200 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    heatClock = max(0, 20.0 - Double(i + 1) * 0.1)
                    if heatClock <= 0 { endWave(wipeout: false) }
                }
            }
        }
    }

    private func startBalanceDrift() {
        balanceDriftTimer?.cancel()
        balanceDriftTimer = Task {
            while true {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(150))
                await MainActor.run {
                    guard phase == .riding || phase == .trickWindow else { return }
                    // Random drift
                    let drift = Double.random(in: -0.04...0.04)
                    balanceMeter = max(0, min(1, balanceMeter + drift))

                    // Balance multiplier: centered = 1.5×, off = 0.5×
                    let dist = abs(balanceMeter - 0.5)
                    currentBalanceMultiplier = dist < 0.1 ? 1.5 : (dist < 0.25 ? 1.0 : 0.5)

                    // Wipeout condition: > 2 seconds off center
                    if balanceMeter < 0.12 || balanceMeter > 0.88 {
                        balanceOffCenterTime += 0.15
                        if balanceOffCenterTime >= 2.0 && !wipeoutTriggered {
                            wipeoutTriggered = true
                            endWave(wipeout: true)
                        }
                    } else {
                        balanceOffCenterTime = max(0, balanceOffCenterTime - 0.1)
                    }
                }
            }
        }
    }

    private func openTrickWindow() {
        trickWindowOpen = true
        trickWindowTimeLeft = 4.0
        phase = .trickWindow

        Task {
            for i in 0..<40 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    trickWindowTimeLeft = max(0, 4.0 - Double(i + 1) * 0.1)
                }
            }
            await MainActor.run {
                // Window closed without trick — return to riding
                if phase == .trickWindow {
                    trickWindowOpen = false
                    phase = .riding
                }
            }
        }
    }

    private func handleTrickSwipe(_ translation: CGSize) {
        guard phase == .trickWindow, !wipeoutTriggered else { return }
        let dx = translation.width, dy = translation.height
        let ax = abs(dx), ay = abs(dy)

        let trick: SurfTrick
        if ay > ax * 1.8 {
            trick = dy < 0 ? .aerial : .tube
        } else {
            trick = .cutback
        }

        performedTrick = trick
        trickAccumulator += trick.points
        currentWaveScore = Double(trickAccumulator) * currentBalanceMultiplier

        trickFlashText = "\(trick.rawValue)  +\(trick.points)"
        withAnimation(.spring(response: 0.2)) { showTrickFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run { withAnimation { showTrickFlash = false } }
        }

        trickWindowOpen = false
        phase = .riding
    }

    private func adjustBalance(delta: Double) {
        guard phase == .riding || phase == .trickWindow else { return }
        balanceMeter = max(0, min(1, balanceMeter + delta))
    }

    private func endWave(wipeout: Bool) {
        cancelAllTimers()

        let finalScore = wipeout ? 0 : max(0, Double(trickAccumulator) * currentBalanceMultiplier)
        currentWaveScore = finalScore

        let ws = WaveScore(waveNumber: waveNumber, rawScore: finalScore, wipeout: wipeout)
        waveScores.append(ws)

        if wipeout {
            phase = .wipeout
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                await MainActor.run { advanceWave() }
            }
        } else {
            phase = .waveResult
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                await MainActor.run { advanceWave() }
            }
        }
    }

    private func advanceWave() {
        if waveNumber >= totalWaves {
            finishHeat()
        } else {
            waveNumber += 1
            startPaddleIn()
        }
    }

    private func finishHeat() {
        if !rewardApplied {
            rewardApplied = true
            let shards = playerWins ? 50 : (isDraw ? 25 : 15)
            viewModel.profile.evolutionShards += shards
        }
        phase = .heatResult
        Task {
            try? await Task.sleep(for: .seconds(3.0))
            await MainActor.run { phase = .result }
        }
    }

    private func cancelAllTimers() {
        waveTimer?.cancel()
        wavePowerTimer?.cancel()
        balanceDriftTimer?.cancel()
    }
}
