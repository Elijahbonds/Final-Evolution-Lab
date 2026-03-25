import SwiftUI
import Combine
import GameController

/// Simplified Arena dunk flow: sprint → launch → airborne → landing, reusing DunkContestState.
/// Single-round contest that returns a score and judge message to the Arena shell.
struct ArenaDunkPlayView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let onExit: () -> Void
    let onGameEnd: (Int, Int, Int, Double) -> Void

    @EnvironmentObject private var unrealRuntime: UFELUnrealOverlayRuntime

    @State private var dunk = DunkContestState()
    @State private var lastUpdateTime: CFTimeInterval = CACurrentMediaTime()
    @State private var isHoldingSprint: Bool = false
    @State private var showingResultAlert: Bool = false
    @State private var lastScoreSummary: (total: Int, message: String)?
    /// DualSense: L2 hold mirrors sprint; R2 confirms gather jump when a physical controller is connected.
    @State private var lastLeftTriggerEngaged = false
    @State private var lastRightTriggerEngaged = false

    private var accentColor: Color { mode.accentColor }

    var body: some View {
        ZStack {
            if !unrealRuntime.bIsUnrealReady {
                DunkContestVenueBackground(accentColor: accentColor)
            }

            VStack(spacing: 24) {
                header
                if unrealRuntime.bIsUnrealReady {
                    Color.clear.frame(height: 120)
                } else {
                    DunkRunwayCanvasView(
                        accentColor: accentColor,
                        phase: dunk.phase,
                        sprintCharge: dunk.sprintCharge
                    )
                }
                phaseLabel
                if !unrealRuntime.bIsUnrealReady {
                    sprintBar
                    launchBar
                    landingBar
                }
                Spacer(minLength: 0)
                primaryButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            configureForArena()
            lastUpdateTime = CACurrentMediaTime()
        }
        .onDisappear {
            isHoldingSprint = false
        }
        .onPhysicalControllerCross(down: handleCrossDown, up: handleCrossUp)
        .overlay(alignment: .topLeading) {
            exitButton
        }
        .overlay(alignment: .bottom) {
            if !ControllerDiscoveryService.shared.hasPhysicalController {
                PS2GamepadOverlay(
                    onFaceButton: handleFaceButton(_:),
                    onDPad: { _ in },
                    onLeftStick: { _ in },
                    onRightStick: { _ in },
                    onCrossDown: handleCrossDown,
                    onCrossUp: handleCrossUp,
                    accentColor: accentColor,
                    isActive: true,
                    mobileOptimized: true
                )
                .allowsHitTesting(true)
            }
        }
        .onReceive(
            Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
        ) { date in
            let now = date.timeIntervalSinceReferenceDate
            let delta = now - lastUpdateTime
            lastUpdateTime = now
            update(delta: max(0, delta))
        }
        .alert("Dunk Result", isPresented: $showingResultAlert) {
            Button("Continue") {
                finishAndReport()
            }
        } message: {
            if let summary = lastScoreSummary {
                Text("\(summary.message)\nTotal: \(summary.total)")
            }
        }
    }

    private var header: some View {
        HStack {
            Text(mode.environmentName.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor.opacity(0.9))
            Spacer()
            Text("DUNK CONTEST")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var phaseLabel: some View {
        let text: String
        switch dunk.phase {
        case .idle:
            text = "READY • HOLD ✕ TO SPRINT"
        case .approach:
            text = "SPRINT • RELEASE ✕ TO GATHER"
        case .launch:
            text = "GATHER • TAP ✕ TO JUMP"
        case .airborne:
            text = "FLY • TAP FACE BUTTONS FOR STYLE"
        case .landing:
            text = "LAND • TAP ✕ TO STICK"
        case .scored:
            text = "SCORED"
        }
        return Text(text)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
    }

    private var sprintBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPRINT")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(4, geo.size.width * CGFloat(min(1, dunk.sprintCharge))))
                }
            }
            .frame(height: 10)
        }
    }

    private var launchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GATHER")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            GeometryReader { geo in
                let t = CGFloat(dunk.launchTiming)
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: geo.size.width * t, alignment: .leading)
                    let center = (dunk.launchGreenZone.lowerBound + dunk.launchGreenZone.upperBound) / 2
                    let width = dunk.launchGreenZone.upperBound - dunk.launchGreenZone.lowerBound
                    let x = geo.size.width * CGFloat(center)
                    let w = geo.size.width * CGFloat(width)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green.opacity(0.8), lineWidth: 2)
                        .frame(width: max(8, w), height: 12)
                        .position(x: x, y: geo.size.height / 2)
                }
            }
            .frame(height: 14)
        }
    }

    private var landingBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LANDING")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            GeometryReader { geo in
                let t = CGFloat(dunk.landingTiming)
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.cyan.opacity(0.6))
                        .frame(width: geo.size.width * t, alignment: .leading)
                    let center = (dunk.landingGreenZone.lowerBound + dunk.landingGreenZone.upperBound) / 2
                    let width = dunk.landingGreenZone.upperBound - dunk.landingGreenZone.lowerBound
                    let x = geo.size.width * CGFloat(center)
                    let w = geo.size.width * CGFloat(width)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green.opacity(0.8), lineWidth: 2)
                        .frame(width: max(8, w), height: 12)
                        .position(x: x, y: geo.size.height / 2)
                }
            }
            .frame(height: 14)
        }
    }

    private var primaryButton: some View {
        Button {
            handleCrossTap()
        } label: {
            Text(buttonTitle)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(2)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(accentColor)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(buttonTitle)
        .accessibilityHint("Use controller Cross or tap")
    }

    private var buttonTitle: String {
        switch dunk.phase {
        case .idle, .approach:
            return "HOLD ✕ TO SPRINT"
        case .launch:
            return "TAP ✕ TO JUMP"
        case .airborne:
            return "TAP FACE BUTTONS FOR STYLE"
        case .landing:
            return "TAP ✕ TO STICK LANDING"
        case .scored:
            return "VIEW RESULT"
        }
    }

    private var exitButton: some View {
        Button {
            onExit()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("EXIT")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.secondary)
            .padding(8)
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.leading, 16)
    }

    private func configureForArena() {
        dunk.totalRounds = 1
        dunk.round = 1
        dunk.phase = .idle
        // Arena variant: slightly slower meters and wider green zones so dunks are consistently achievable
        // on both touch and controller without feeling punishing.
        dunk.launchGreenZone = 0.35...0.75
        dunk.landingGreenZone = 0.3...0.7
        dunk.launchTimingSpeed = 1.4
        dunk.landingTimingSpeed = 1.5
    }

    private func handleCrossDown() {
        switch dunk.phase {
        case .idle:
            dunk.startApproach()
            isHoldingSprint = true
        case .approach:
            isHoldingSprint = true
        default:
            break
        }
    }

    private func handleCrossUp() {
        switch dunk.phase {
        case .approach:
            dunk.releaseSprint()
            isHoldingSprint = false
        default:
            isHoldingSprint = false
        }
    }

    private func handleCrossTap() {
        switch dunk.phase {
        case .idle:
            handleCrossDown()
        case .launch:
            dunk.confirmLaunch()
        case .airborne:
            // Simple style landing trigger on button instead of separate input.
            _ = dunk.attemptStyleLanding()
        case .landing:
            dunk.confirmLanding()
            scoreAndShowResult()
        case .scored:
            showingResultAlert = true
        case .approach:
            break
        }
    }

    private func handleFaceButton(_ button: PS2FaceButton) {
        guard dunk.phase == .airborne else { return }
        // Map face buttons to simple tricks by category.
        let slot: DunkTrickSlot
        switch button {
        case .square: slot = .windmill
        case .triangle: slot = .betweenLegs
        case .circle: slot = .tomahawk
        case .cross: slot = .freeThrowLine
        }
        dunk.selectedTrick = slot
    }

    private func update(delta: Double) {
        pollDualSenseTriggers()
        if isHoldingSprint, dunk.phase == .approach {
            dunk.sprintCharge = min(1.0, dunk.sprintCharge + dunk.sprintChargeRate * delta * 0.6)
        }
        dunk.updateAirborne(delta: delta)
    }

    private func pollDualSenseTriggers() {
        guard ControllerDiscoveryService.shared.hasPhysicalController,
              let pad = GCController.controllers().first?.extendedGamepad
        else {
            lastLeftTriggerEngaged = false
            lastRightTriggerEngaged = false
            return
        }

        let leftOn = pad.leftTrigger.value > 0.22
        if leftOn {
            if dunk.phase == .idle { handleCrossDown() }
            if dunk.phase == .approach { isHoldingSprint = true }
        } else if lastLeftTriggerEngaged, dunk.phase == .approach {
            handleCrossUp()
        }
        lastLeftTriggerEngaged = leftOn

        let rightOn = pad.rightTrigger.value > 0.45
        if rightOn, !lastRightTriggerEngaged, dunk.phase == .launch {
            dunk.confirmLaunch()
        }
        lastRightTriggerEngaged = rightOn
    }

    private func scoreAndShowResult() {
        let result = dunk.calculateDunkScore(
            prq: viewModel.effectiveMetrics.prqScore,
            neuralBurst: false,
            academyPlyosNeuroMultiplier: viewModel.academyPlyosMasteryNeuroMultiplier
        )
        dunk.totalScore = result.total
        dunk.roundScores = [(round: 1, score: result.total, message: result.message)]
        dunk.phase = .scored
        lastScoreSummary = (total: result.total, message: result.message)
        showingResultAlert = true
    }

    private func finishAndReport() {
        let playerScore = dunk.totalScore
        let aiScore = Int.random(in: max(40, playerScore - 10)...max(playerScore, playerScore + 10))
        let won = playerScore >= aiScore
        let tied = playerScore == aiScore
        let diff = playerScore - aiScore
        let prqGain = PRQ.modeReward(
            mode: mode.id,
            won: won,
            tied: tied,
            combo: 0,
            criticals: 0,
            scoreDifferential: diff
        )
        let baseShards = 10
        let shards = max(8, min(40, baseShards + (won ? 8 : 0) + max(0, diff)))
        onGameEnd(playerScore, aiScore, shards, prqGain)
    }
}

