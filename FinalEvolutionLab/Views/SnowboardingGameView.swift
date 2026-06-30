import SwiftUI

// MARK: - Phase

private enum SnowPhase {
    case ready, slope, jump, trick, roundResult, result
}

// MARK: - Trick

private struct SnowTrick: Identifiable {
    let id = UUID()
    let name: String
    let points: Int
    let icon: String
}

private let snowTricks: [SnowTrick] = [
    SnowTrick(name: "Grab",   points: 50,  icon: "hand.point.up.left.fill"),
    SnowTrick(name: "Spin",   points: 100, icon: "arrow.clockwise.circle"),
    SnowTrick(name: "Indy",   points: 120, icon: "figure.snowboarding"),
    SnowTrick(name: "Method", points: 140, icon: "star.fill"),
]

// MARK: - Swipe direction

private enum SnowSwipeDir {
    case up, right, left, down
}

// MARK: - SnowboardingGameView

struct SnowboardingGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    private let totalRounds = 6
    private let slopeDuration: Double = 5.0
    private let xpCapPerSession = 500
    private let accentColor = Color(red: 0.85, green: 0.92, blue: 1.0)
    private let snowBlue = Color(red: 0.4, green: 0.7, blue: 1.0)

    @Environment(\.dismiss) private var dismiss

    // Phase
    @State private var phase: SnowPhase = .ready

    // Round state
    @State private var currentRound = 1
    @State private var slopeTimeLeft: Double = 5.0
    @State private var slopeTimer: Task<Void, Never>? = nil

    // Speed
    @State private var speed: Double = 0        // 0–100
    @State private var tapLeftCount = 0
    @State private var tapRightCount = 0
    @State private var lastGateMissed = false

    // Jump / Air phase
    @State private var airTime: Double = 0       // derived from speed
    @State private var airTimeLeft: Double = 0
    @State private var jumpHeight: Double = 0
    @State private var airTimer: Task<Void, Never>? = nil

    // Trick during air
    @State private var roundTrickPoints = 0
    @State private var roundTrickNames: [String] = []
    @State private var trickDoneThisAir = false

    // Session score
    @State private var totalScore = 0
    @State private var roundScores: [Int] = []

    // Trick popup
    @State private var trickPopup: String? = nil
    @State private var trickPopupPoints: Int = 0
    @State private var popupTask: Task<Void, Never>? = nil

    // Swipe detection
    @State private var swipeStart: CGPoint = .zero
    @State private var activeSwipeCount = 0

    // Result
    @State private var didWin = false
    @State private var shardsEarned = 0

    // Gate penalty flash
    @State private var showGatePenalty = false

    // Pulsing jump height visual
    @State private var jumpPulse = false

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            slopeGradientBg.ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Snowboarding",
                    subtitle: "6 jumps · Gain speed · Nail tricks in the air",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startSlope() }
                )

            case .slope:
                slopeBody

            case .jump, .trick:
                jumpBody

            case .roundResult:
                roundResultBody

            case .result:
                ResultScreen(
                    winner: didWin ? .p1 : .p2,
                    p1Score: totalScore,
                    p2Score: max(0, totalScore - Int.random(in: 100...300)),
                    title: "Snowboarding",
                    accentColor: accentColor,
                    prqGain: didWin ? 14 : 5,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "STYLE",
                    modeAttributeValue: min(1.0, Double(totalScore) / 2000.0),
                    onReturn: {
                        applyRewards()
                        dismiss()
                    }
                )
            }

            // Gate penalty flash
            if showGatePenalty {
                Color.red.opacity(0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    slopeTimer?.cancel()
                    airTimer?.cancel()
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
            slopeTimer?.cancel()
            airTimer?.cancel()
        }
    }

    // MARK: - Background

    private var slopeGradientBg: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.18),
                Color(red: 0.08, green: 0.12, blue: 0.22),
                Theme.deepBlack
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Slope Phase View

    private var slopeBody: some View {
        VStack(spacing: 0) {
            slopeHeader
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer()

            // Slope visual
            slopeVisual

            Spacer()

            // Speed meter
            speedMeterView
                .padding(.horizontal, 24)

            // Tap buttons
            tapButtonRow
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
    }

    private var slopeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("JUMP \(currentRound)/\(totalRounds)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(2)
                HStack(spacing: 3) {
                    ForEach(1...totalRounds, id: \.self) { i in
                        Circle()
                            .fill(i < currentRound ? Theme.foundationGreen :
                                  (i == currentRound ? accentColor : Theme.cardBorder))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            Spacer()

            // Slope timer
            ZStack {
                Circle()
                    .stroke(Theme.cardBorder, lineWidth: 3)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(slopeTimeLeft / slopeDuration))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: slopeTimeLeft)
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("TOTAL")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(totalScore)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
    }

    private var slopeVisual: some View {
        ZStack {
            // Snow slope
            Path { p in
                p.move(to: CGPoint(x: 0, y: 20))
                p.addLine(to: CGPoint(x: 340, y: 100))
                p.addLine(to: CGPoint(x: 340, y: 140))
                p.addLine(to: CGPoint(x: 0, y: 140))
                p.closeSubpath()
            }
            .fill(LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: 340, height: 140)

            // Gates on slope
            HStack(spacing: 60) {
                ForEach(0..<4) { i in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(i % 2 == 0 ? Color.red.opacity(0.8) : Color.blue.opacity(0.8))
                            .frame(width: 4, height: 32)
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 4, height: 8)
                    }
                }
            }
            .offset(y: 10)

            // Snowboarder
            Image(systemName: "figure.snowboarding")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(snowBlue)
                .shadow(color: snowBlue.opacity(0.5), radius: 8)
                .offset(x: CGFloat(-100 + speed * 0.6), y: 0)
                .animation(.spring(response: 0.3), value: speed)

            // Ramp at the end
            Path { p in
                p.move(to: CGPoint(x: 300, y: 100))
                p.addQuadCurve(
                    to: CGPoint(x: 340, y: 20),
                    control: CGPoint(x: 340, y: 100)
                )
                p.addLine(to: CGPoint(x: 340, y: 100))
                p.closeSubpath()
            }
            .fill(accentColor.opacity(0.25))
            .frame(width: 340, height: 140)

            Text("RAMP")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor.opacity(0.6))
                .tracking(1)
                .offset(x: 130, y: 20)
        }
        .frame(height: 140)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var speedMeterView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "speedometer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accentColor)
                Text("SPEED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(2)
                Spacer()
                Text("\(Int(speed))%")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            // Speed bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.cardBorder)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: speedBarColors(speed: speed),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(speed / 100), height: 12)
                        .animation(.spring(response: 0.2), value: speed)
                }
            }
            .frame(height: 12)

            // Gate miss indicator
            if lastGateMissed {
                Text("GATE MISSED — \u{2212}20% SPEED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 16)
    }

    private func speedBarColors(speed: Double) -> [Color] {
        if speed < 40 { return [snowBlue.opacity(0.5), snowBlue] }
        if speed < 70 { return [snowBlue, accentColor] }
        return [accentColor, Theme.foundationGreen, accentColor]
    }

    private var tapButtonRow: some View {
        HStack(spacing: 20) {
            // Left tap
            Button {
                tapLeft()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .black))
                    Text("L")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(snowBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(snowBlue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Center hint
            VStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)
                    .symbolEffect(.pulse)
                Text("TAP FAST")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text("TO GAIN SPEED")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }

            // Right tap
            Button {
                tapRight()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .black))
                    Text("R")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(snowBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(snowBlue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Jump / Air Phase View

    private var jumpBody: some View {
        VStack(spacing: 0) {
            // Jump header
            jumpHeader
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer()

            // Jump height visual
            jumpHeightVisual

            Spacer()

            // Trick popup
            jumpTrickPopup
                .frame(height: 80)

            // Trick buttons (during air)
            if phase == .trick {
                trickButtonGrid
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            } else {
                // Launching animation
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(accentColor)
                        .symbolEffect(.pulse)
                    Text("LAUNCHING...")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .tracking(2)
                }
                .padding(.bottom, 60)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dir = swipeDirectionFromDrag(dx: value.translation.width, dy: value.translation.height)
                    handleAirTrick(dir: dir)
                }
        )
    }

    private var jumpHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("JUMP \(currentRound)/\(totalRounds)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(2)
                Text("SPEED: \(Int(speed))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(snowBlue)
            }

            Spacer()

            // Air time remaining
            ZStack {
                Circle()
                    .stroke(Theme.cardBorder, lineWidth: 3)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: airTime > 0 ? CGFloat(airTimeLeft / airTime) : 0)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: airTimeLeft)
                Text(String(format: "%.1f", airTimeLeft))
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("ROUND")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(roundTrickPoints)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
            }
        }
    }

    private var jumpHeightVisual: some View {
        HStack(alignment: .bottom, spacing: 20) {
            // Height indicator bar
            VStack(spacing: 8) {
                Text("HEIGHT")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.cardBorder)
                        .frame(width: 16, height: 160)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, snowBlue],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 16, height: 160 * CGFloat(jumpHeight))
                        .animation(.spring(response: 0.5), value: jumpHeight)
                }
            }

            // Snowboarder jumping
            ZStack {
                // Shadow
                Ellipse()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 80, height: 12)
                    .offset(y: 80)

                // Snow spray particles
                ForEach(0..<5) { i in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: CGFloat.random(in: 4...10))
                        .offset(
                            x: CGFloat.random(in: -30...30),
                            y: CGFloat.random(in: 40...80)
                        )
                }

                // Boarder
                Image(systemName: "figure.snowboarding")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(snowBlue)
                    .shadow(color: accentColor.opacity(0.5), radius: 12)
                    .offset(y: -CGFloat(jumpHeight * 80))
                    .rotationEffect(.degrees(jumpHeight > 0.5 ? -30 : 0))
                    .animation(.spring(response: 0.6), value: jumpHeight)
                    .scaleEffect(jumpPulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: jumpPulse)
            }
            .frame(width: 160, height: 200)
            .onAppear { jumpPulse = true }

            // Trick list for this round
            VStack(alignment: .leading, spacing: 6) {
                Text("TRICKS")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                ForEach(roundTrickNames.prefix(4), id: \.self) { name in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.foundationGreen)
                            .frame(width: 5, height: 5)
                        Text(name)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentColor)
                    }
                }
                if roundTrickNames.isEmpty {
                    Text("None yet")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(width: 70)
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var jumpTrickPopup: some View {
        if let name = trickPopup {
            VStack(spacing: 4) {
                Text(name.uppercased())
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .shadow(color: accentColor.opacity(0.6), radius: 8)
                Text("+\(trickPopupPoints) pts")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            Color.clear
        }
    }

    private var trickButtonGrid: some View {
        VStack(spacing: 12) {
            Text("SWIPE OR TAP A TRICK")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(snowTricks) { trick in
                    Button {
                        performSnowTrick(trick)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: trick.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(accentColor)
                            Text(trick.name.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("+\(trick.points)")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(accentColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(accentColor.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(trickDoneThisAir)
                    .opacity(trickDoneThisAir ? 0.4 : 1.0)
                }
            }
        }
    }

    // MARK: - Round Result

    private var roundResultBody: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("JUMP \(currentRound - 1) SCORE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)

            Text("\(roundScores.last ?? 0)")
                .font(.system(size: 60, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .shadow(color: accentColor.opacity(0.4), radius: 16)

            Text("PTS")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(4)

            // Tricks summary
            if !roundTrickNames.isEmpty {
                HStack(spacing: 8) {
                    ForEach(roundTrickNames.prefix(4), id: \.self) { name in
                        Text(name)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(accentColor)
                            .clipShape(.capsule)
                    }
                }
            }

            VStack(spacing: 6) {
                Text("TOTAL SO FAR")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(totalScore) pts")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.foundationGreen)
            }
            .padding(.top, 8)

            if currentRound <= totalRounds {
                Button {
                    startSlope()
                } label: {
                    Text("JUMP \(currentRound) — RIDE")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
            }

            Spacer()
        }
    }

    // MARK: - Logic: Slope

    private func startSlope() {
        speed = 0
        tapLeftCount = 0
        tapRightCount = 0
        lastGateMissed = false
        slopeTimeLeft = slopeDuration
        roundTrickPoints = 0
        roundTrickNames = []
        trickDoneThisAir = false
        phase = .slope

        slopeTimer?.cancel()
        slopeTimer = Task {
            let tick: Double = 0.05
            while slopeTimeLeft > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    slopeTimeLeft = max(0, slopeTimeLeft - tick)
                    // Natural deceleration
                    speed = max(0, speed - 0.15)
                    // Random gate check
                    if Int.random(in: 0...200) == 0 {
                        missGate()
                    }
                }
            }
            await MainActor.run {
                guard phase == .slope else { return }
                launchJump()
            }
        }
    }

    private func tapLeft() {
        guard phase == .slope else { return }
        tapLeftCount += 1
        speed = min(100, speed + Double.random(in: 2.5...4.5))
    }

    private func tapRight() {
        guard phase == .slope else { return }
        tapRightCount += 1
        speed = min(100, speed + Double.random(in: 2.5...4.5))
    }

    private func missGate() {
        lastGateMissed = true
        speed = max(0, speed - 20)
        withAnimation { showGatePenalty = true }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                withAnimation { showGatePenalty = false }
                lastGateMissed = false
            }
        }
    }

    // MARK: - Logic: Jump

    private func launchJump() {
        slopeTimer?.cancel()

        // Air time scales with speed: 1s at 0%, 4s at 100%
        airTime = 1.0 + (speed / 100.0) * 3.0
        airTimeLeft = airTime
        jumpHeight = speed / 100.0
        phase = .jump

        // After 0.6s show trick panel
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                guard phase == .jump else { return }
                phase = .trick
            }
        }

        // Count down air time
        airTimer?.cancel()
        airTimer = Task {
            let tick: Double = 0.05
            while airTimeLeft > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    airTimeLeft = max(0, airTimeLeft - tick)
                    // Height arc
                    let progress = 1.0 - (airTimeLeft / airTime)
                    jumpHeight = sin(progress * .pi) * (speed / 100.0)
                }
            }
            await MainActor.run {
                guard phase == .jump || phase == .trick else { return }
                landJump()
            }
        }
    }

    private func landJump() {
        airTimer?.cancel()
        jumpHeight = 0

        roundScores.append(roundTrickPoints)
        totalScore += roundTrickPoints

        if currentRound >= totalRounds {
            // Final result
            let opponentScore = Int.random(in: 600...1200)
            didWin = totalScore > opponentScore
            phase = .result
        } else {
            currentRound += 1
            phase = .roundResult
        }
    }

    // MARK: - Logic: Tricks

    private func swipeDirectionFromDrag(dx: CGFloat, dy: CGFloat) -> SnowSwipeDir {
        let angle = atan2(-dy, dx) * 180 / .pi
        if angle > 45 && angle < 135 { return .up }
        if angle > -45 && angle < 45 { return .right }
        if angle < -45 && angle > -135 { return .left }
        return .down
    }

    private func handleAirTrick(dir: SnowSwipeDir) {
        guard phase == .trick else { return }
        switch dir {
        case .up:    performSnowTrick(snowTricks[2]) // Indy
        case .right: performSnowTrick(snowTricks[1]) // Spin
        case .left:  performSnowTrick(snowTricks[0]) // Grab
        case .down:  performSnowTrick(snowTricks[3]) // Method
        }
    }

    private func performSnowTrick(_ trick: SnowTrick) {
        guard (phase == .jump || phase == .trick) && !trickDoneThisAir else { return }

        // Allow multiple tricks in longer air — reset trickDoneThisAir after 0.8s
        trickDoneThisAir = true

        roundTrickPoints += trick.points
        roundTrickNames.append(trick.name)

        showTrickPopup(name: trick.name, points: trick.points)

        // Allow another trick after brief delay if still in air
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run {
                if phase == .trick {
                    trickDoneThisAir = false
                }
            }
        }
    }

    // MARK: - Trick popup

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
        let opponentThreshold = 800
        let shards = totalScore > opponentThreshold ? 50 : (totalScore > 400 ? 25 : 15)
        shardsEarned = shards
        viewModel.profile.evolutionShards += shards

        let xpGain = min(xpCapPerSession, totalScore / 10)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) * 0.01)
    }
}
