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

// MARK: - Snow Slope Drawer

private struct SnowSlopeDrawer {
    let W: CGFloat
    let H: CGFloat
    let speed: Double
    let t: Double

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawMountains(ctx: &ctx)
        drawSlope(ctx: &ctx)
        drawGates(ctx: &ctx)
        drawBoarder(ctx: &ctx)
        if speed > 35 { drawSpeedLines(ctx: &ctx) }
    }

    private func drawSky(ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.42)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.05, green: 0.10, blue: 0.28),
                        Color(red: 0.18, green: 0.35, blue: 0.60)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: H * 0.42)))
    }

    private func drawMountains(ctx: inout GraphicsContext) {
        var m1 = Path()
        m1.move(to: CGPoint(x: 0, y: H * 0.44))
        m1.addLine(to: CGPoint(x: W * 0.08, y: H * 0.24))
        m1.addLine(to: CGPoint(x: W * 0.20, y: H * 0.40))
        m1.addLine(to: CGPoint(x: W * 0.36, y: H * 0.18))
        m1.addLine(to: CGPoint(x: W * 0.50, y: H * 0.40))
        m1.addLine(to: CGPoint(x: W * 0.64, y: H * 0.22))
        m1.addLine(to: CGPoint(x: W * 0.78, y: H * 0.40))
        m1.addLine(to: CGPoint(x: W * 0.90, y: H * 0.26))
        m1.addLine(to: CGPoint(x: W, y: H * 0.40))
        m1.addLine(to: CGPoint(x: W, y: H))
        m1.addLine(to: CGPoint(x: 0, y: H))
        m1.closeSubpath()
        ctx.fill(m1, with: .color(Color(red: 0.86, green: 0.91, blue: 0.97)))

        var m2 = Path()
        m2.move(to: CGPoint(x: 0, y: H * 0.46))
        m2.addLine(to: CGPoint(x: W * 0.14, y: H * 0.32))
        m2.addLine(to: CGPoint(x: W * 0.28, y: H * 0.44))
        m2.addLine(to: CGPoint(x: W * 0.44, y: H * 0.28))
        m2.addLine(to: CGPoint(x: W * 0.56, y: H * 0.44))
        m2.addLine(to: CGPoint(x: W * 0.70, y: H * 0.30))
        m2.addLine(to: CGPoint(x: W * 0.82, y: H * 0.44))
        m2.addLine(to: CGPoint(x: W, y: H * 0.34))
        m2.addLine(to: CGPoint(x: W, y: H))
        m2.addLine(to: CGPoint(x: 0, y: H))
        m2.closeSubpath()
        ctx.fill(m2, with: .color(Color(red: 0.92, green: 0.95, blue: 0.99)))
    }

    private func drawSlope(ctx: inout GraphicsContext) {
        let slopeTop = H * 0.42
        let snowColor = Color(red: 0.94, green: 0.96, blue: 1.0)
        var slope = Path()
        slope.move(to: CGPoint(x: 0, y: slopeTop))
        slope.addLine(to: CGPoint(x: W, y: slopeTop + H * 0.06))
        slope.addLine(to: CGPoint(x: W, y: H))
        slope.addLine(to: CGPoint(x: 0, y: H))
        slope.closeSubpath()
        ctx.fill(slope, with: .linearGradient(
            Gradient(colors: [snowColor, snowColor.opacity(0.80)]),
            startPoint: CGPoint(x: 0, y: slopeTop),
            endPoint: CGPoint(x: 0, y: H)))

        // Perspective lines converging to vanishing point
        let vp = CGPoint(x: W * 0.5, y: slopeTop)
        for i in 0..<6 {
            let endX = W * CGFloat(i) / 5.0
            var tl = Path()
            tl.move(to: vp)
            tl.addLine(to: CGPoint(x: endX, y: H))
            ctx.stroke(tl, with: .color(snowColor.opacity(0.45)), lineWidth: 0.7)
        }

        // Board tracks
        let trackCX = W * 0.50
        for dx in [-7.0, 7.0] as [Double] {
            let tx = trackCX + CGFloat(dx)
            var track = Path()
            track.move(to: CGPoint(x: tx, y: slopeTop + H * 0.02))
            track.addLine(to: CGPoint(x: tx + CGFloat((speed - 50) * 0.45), y: H * 0.88))
            ctx.stroke(track,
                       with: .color(Color(red: 0.65, green: 0.75, blue: 0.90).opacity(0.55)),
                       lineWidth: 1.5)
        }
    }

    private func drawGates(ctx: inout GraphicsContext) {
        let slopeTop = H * 0.42
        let speedRate = 0.3 + speed / 200.0
        for gi in 0..<4 {
            let gatePhase = fmod(Double(gi) * 0.25 + t * speedRate * 0.4, 1.0)
            let gY = slopeTop + (H - slopeTop) * CGFloat(gatePhase) * 0.92
            let poleH = H * CGFloat(0.04 + gatePhase * 0.12)
            let poleW = CGFloat(2.5 + gatePhase * 3.0)
            let spread = W * CGFloat(0.10 + gatePhase * 0.26)
            let alpha = CGFloat(0.35 + gatePhase * 0.55)
            let gateColor = gi % 2 == 0 ? Color.red : Color.blue

            let lx = W * 0.5 - spread
            let rx = W * 0.5 + spread
            // Left pole
            ctx.fill(Path(CGRect(x: lx - poleW / 2, y: gY - poleH, width: poleW, height: poleH)),
                     with: .color(gateColor.opacity(alpha)))
            ctx.fill(Path(ellipseIn: CGRect(x: lx - poleW, y: gY - poleH - 4, width: poleW * 2, height: poleW * 2)),
                     with: .color(gateColor.opacity(alpha + 0.1)))
            // Right pole
            ctx.fill(Path(CGRect(x: rx - poleW / 2, y: gY - poleH, width: poleW, height: poleH)),
                     with: .color(gateColor.opacity(alpha)))
            ctx.fill(Path(ellipseIn: CGRect(x: rx - poleW, y: gY - poleH - 4, width: poleW * 2, height: poleW * 2)),
                     with: .color(gateColor.opacity(alpha + 0.1)))
            // Banner
            var banner = Path()
            banner.move(to: CGPoint(x: lx, y: gY - poleH * 0.75))
            banner.addLine(to: CGPoint(x: rx, y: gY - poleH * 0.75))
            ctx.stroke(banner, with: .color(.white.opacity(alpha * 0.5)), lineWidth: 1)
        }
    }

    private func drawBoarder(ctx: inout GraphicsContext) {
        let bx = W * 0.50, by = H * 0.66
        let lean = CGFloat((speed - 50) * 0.004)

        var gc = ctx
        gc.translateBy(x: bx, y: by)
        gc.rotate(by: .radians(lean))

        let blue = GraphicsContext.Shading.color(Color(red: 0.40, green: 0.70, blue: 1.0))
        let skin = GraphicsContext.Shading.color(Color(red: 0.88, green: 0.65, blue: 0.44))
        let dark = GraphicsContext.Shading.color(Color(red: 0.08, green: 0.06, blue: 0.12))

        gc.fill(Path(roundedRect: CGRect(x: -22, y: 4, width: 44, height: 7),
                     cornerRadius: CGSize(width: 3, height: 3)),
                with: .color(.white.opacity(0.90)))
        gc.fill(Path(roundedRect: CGRect(x: -22, y: 4, width: 44, height: 2),
                     cornerRadius: CGSize(width: 1, height: 1)),
                with: blue)

        var legs = Path()
        legs.move(to: CGPoint(x: -6, y: 4))
        legs.addLine(to: CGPoint(x: -3, y: -5))
        legs.addLine(to: CGPoint(x: 0, y: -10))
        legs.move(to: CGPoint(x: 6, y: 4))
        legs.addLine(to: CGPoint(x: 3, y: -5))
        legs.addLine(to: CGPoint(x: 0, y: -10))
        gc.stroke(legs, with: blue, lineWidth: 3)

        var torso = Path()
        torso.move(to: CGPoint(x: 0, y: -10))
        torso.addLine(to: CGPoint(x: 0, y: -20))
        gc.stroke(torso, with: blue, lineWidth: 3)

        var arms = Path()
        arms.move(to: CGPoint(x: -12, y: -16))
        arms.addLine(to: CGPoint(x: 0, y: -15))
        arms.addLine(to: CGPoint(x: 12, y: -16))
        gc.stroke(arms, with: skin, lineWidth: 2.5)

        gc.fill(Path(ellipseIn: CGRect(x: -5, y: -29, width: 10, height: 10)), with: blue)
        gc.fill(Path(CGRect(x: -5, y: -27, width: 10, height: 4)), with: dark)

        if speed > 28 {
            for i in 0..<5 {
                let sa = Double(i) * .pi / 4.0 + .pi * 1.1
                let sp = fmod(t * 3.0 + Double(i) * 0.5, 1.0)
                let sr = CGFloat(6 + sp * 18)
                let spx = CGFloat(cos(sa)) * sr
                let spy = CGFloat(sin(sa)) * sr * 0.45 + 8
                let sdot = CGFloat(1.5 + sp * 2.0)
                gc.fill(Path(ellipseIn: CGRect(x: spx - sdot, y: spy - sdot, width: sdot * 2, height: sdot * 2)),
                        with: .color(.white.opacity(CGFloat(0.5 * speed / 100.0) * CGFloat(1.0 - sp))))
            }
        }
    }

    private func drawSpeedLines(ctx: inout GraphicsContext) {
        let bx = W * 0.50, by = H * 0.66
        let alpha = CGFloat((speed - 35.0) / 65.0) * 0.28
        for i in 0..<8 {
            let angle = Double(i) * .pi / 8.0 + .pi * 0.82
            let len = CGFloat(speed * 0.28)
            var line = Path()
            line.move(to: CGPoint(x: bx, y: by))
            line.addLine(to: CGPoint(x: bx + CGFloat(cos(angle)) * len,
                                      y: by + CGFloat(sin(angle)) * len))
            ctx.stroke(line, with: .color(.white.opacity(alpha)), lineWidth: 0.8)
        }
    }
}

// MARK: - Snow Slope Canvas

private struct SnowSlopeCanvas: View {
    let speed: Double

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var drawer = SnowSlopeDrawer(W: size.width, H: size.height, speed: speed, t: t)
                drawer.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Snow Jump Drawer

private struct SnowJumpDrawer {
    let W: CGFloat
    let H: CGFloat
    let jumpHeight: Double
    let isTrickPhase: Bool
    let trickName: String?
    let t: Double

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawMountains(ctx: &ctx)
        drawSpray(ctx: &ctx)
        drawBoarder(ctx: &ctx)
    }

    private func drawSky(ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.30, green: 0.55, blue: 0.88),
                        Color(red: 0.55, green: 0.76, blue: 0.96)
                    ]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
        var sunGC = ctx
        sunGC.addFilter(.blur(radius: 20))
        sunGC.fill(Path(ellipseIn: CGRect(x: W * 0.72, y: H * 0.06, width: 32, height: 26)),
                   with: .color(Color(red: 1.0, green: 0.97, blue: 0.80).opacity(0.48)))
    }

    private func drawMountains(ctx: inout GraphicsContext) {
        let lift = CGFloat(jumpHeight) * H * 0.22
        let groundY = H * 0.84 - lift
        var mPath = Path()
        mPath.move(to: CGPoint(x: 0, y: groundY + H * 0.04))
        mPath.addLine(to: CGPoint(x: W * 0.09, y: groundY - H * 0.20))
        mPath.addLine(to: CGPoint(x: W * 0.22, y: groundY + H * 0.02))
        mPath.addLine(to: CGPoint(x: W * 0.38, y: groundY - H * 0.28))
        mPath.addLine(to: CGPoint(x: W * 0.52, y: groundY + H * 0.02))
        mPath.addLine(to: CGPoint(x: W * 0.66, y: groundY - H * 0.22))
        mPath.addLine(to: CGPoint(x: W * 0.80, y: groundY + H * 0.02))
        mPath.addLine(to: CGPoint(x: W * 0.92, y: groundY - H * 0.14))
        mPath.addLine(to: CGPoint(x: W, y: groundY + H * 0.04))
        mPath.addLine(to: CGPoint(x: W, y: H))
        mPath.addLine(to: CGPoint(x: 0, y: H))
        mPath.closeSubpath()
        ctx.fill(mPath, with: .color(Color(red: 0.88, green: 0.93, blue: 0.98)))
        ctx.fill(mPath, with: .linearGradient(
            Gradient(colors: [Color(red: 0.75, green: 0.85, blue: 0.96).opacity(0.25), .clear]),
            startPoint: CGPoint(x: 0, y: groundY - H * 0.1),
            endPoint: CGPoint(x: W, y: groundY)))
    }

    private func drawSpray(ctx: inout GraphicsContext) {
        let lift = CGFloat(jumpHeight) * H * 0.22
        let groundY = H * 0.84 - lift
        let intensity = CGFloat(jumpHeight)
        for i in 0..<8 {
            let phase = fmod(t * 1.6 + Double(i) * 0.35, 1.0)
            let angle = Double(i) * .pi / 4.0 + .pi * 0.58
            let r = CGFloat(phase * 28)
            let px = W * 0.5 + CGFloat(cos(angle)) * r
            let py = groundY - CGFloat(phase) * H * 0.08
            let dot = CGFloat(2.5 + phase * 4.5)
            ctx.fill(Path(ellipseIn: CGRect(x: px - dot / 2, y: py - dot / 2, width: dot, height: dot)),
                     with: .color(.white.opacity(CGFloat(0.5 * (1.0 - phase)) * intensity)))
        }
    }

    private func drawBoarder(ctx: inout GraphicsContext) {
        let lift = CGFloat(jumpHeight) * H * 0.22
        let groundY = H * 0.84 - lift
        let bY = groundY - CGFloat(jumpHeight) * H * 0.52
        let bX = W * 0.5

        var spinAngle: Double = 0
        var boardTilt: Double = 0
        if isTrickPhase && jumpHeight > 0.25 {
            if trickName == "Spin" {
                spinAngle = fmod(t * 3.2, .pi * 2.0)
            } else if trickName == "Method" || trickName == "Indy" {
                boardTilt = sin(t * 4.0) * .pi / 4.5
            } else if trickName == "Grab" {
                boardTilt = sin(t * 3.0) * .pi / 6.0
            }
        }

        var shadowGC = ctx
        shadowGC.addFilter(.blur(radius: 5))
        let sS = max(CGFloat(0.18), 1.0 - CGFloat(jumpHeight) * 0.75)
        shadowGC.fill(Path(ellipseIn: CGRect(x: bX - 20 * sS, y: groundY - 1,
                                              width: 40 * sS, height: 7 * sS)),
                      with: .color(.black.opacity(0.4 * sS)))

        var gc = ctx
        gc.translateBy(x: bX, y: bY)
        if spinAngle != 0 { gc.rotate(by: .radians(spinAngle)) }

        let blue = GraphicsContext.Shading.color(Color(red: 0.40, green: 0.70, blue: 1.0))
        let skin = GraphicsContext.Shading.color(Color(red: 0.88, green: 0.65, blue: 0.44))
        let dark = GraphicsContext.Shading.color(Color(red: 0.08, green: 0.06, blue: 0.12))

        var boardGC = gc
        if boardTilt != 0 { boardGC.rotate(by: .radians(boardTilt)) }
        boardGC.fill(Path(roundedRect: CGRect(x: -24, y: 8, width: 48, height: 9),
                          cornerRadius: CGSize(width: 4, height: 4)),
                     with: .color(.white.opacity(0.92)))
        boardGC.fill(Path(roundedRect: CGRect(x: -24, y: 8, width: 48, height: 3),
                          cornerRadius: CGSize(width: 2, height: 2)), with: blue)

        var legs = Path()
        legs.move(to: CGPoint(x: -8, y: 8))
        legs.addLine(to: CGPoint(x: -4, y: -2))
        legs.addLine(to: CGPoint(x: -1, y: -9))
        legs.move(to: CGPoint(x: 8, y: 8))
        legs.addLine(to: CGPoint(x: 4, y: -2))
        legs.addLine(to: CGPoint(x: 1, y: -9))
        gc.stroke(legs, with: blue, lineWidth: 3.5)

        var torso = Path()
        torso.move(to: CGPoint(x: 0, y: -9))
        torso.addLine(to: CGPoint(x: 0, y: -20))
        gc.stroke(torso, with: blue, lineWidth: 3.5)

        var arms = Path()
        arms.move(to: CGPoint(x: -15, y: -15))
        arms.addLine(to: CGPoint(x: 0, y: -14))
        arms.addLine(to: CGPoint(x: 15, y: -15))
        gc.stroke(arms, with: skin, lineWidth: 3)

        gc.fill(Path(ellipseIn: CGRect(x: -5.5, y: -30, width: 11, height: 11)), with: blue)
        gc.fill(Path(CGRect(x: -5.5, y: -28, width: 11, height: 4)), with: dark)
    }
}

// MARK: - Snow Jump Canvas

private struct SnowJumpCanvas: View {
    let jumpHeight: Double
    let isTrickPhase: Bool
    let trickName: String?

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var drawer = SnowJumpDrawer(
                    W: size.width, H: size.height,
                    jumpHeight: jumpHeight, isTrickPhase: isTrickPhase,
                    trickName: trickName, t: t)
                drawer.render(ctx: &ctx)
            }
        }
    }
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

    @State private var phase: SnowPhase = .ready
    @State private var currentRound = 1
    @State private var slopeTimeLeft: Double = 5.0
    @State private var slopeTimer: Task<Void, Never>? = nil

    @State private var speed: Double = 0
    @State private var tapLeftCount = 0
    @State private var tapRightCount = 0
    @State private var lastGateMissed = false

    @State private var airTime: Double = 0
    @State private var airTimeLeft: Double = 0
    @State private var jumpHeight: Double = 0
    @State private var airTimer: Task<Void, Never>? = nil

    @State private var roundTrickPoints = 0
    @State private var roundTrickNames: [String] = []
    @State private var trickDoneThisAir = false

    @State private var totalScore = 0
    @State private var roundScores: [Int] = []

    @State private var trickPopup: String? = nil
    @State private var trickPopupPoints: Int = 0
    @State private var popupTask: Task<Void, Never>? = nil

    @State private var swipeStart: CGPoint = .zero
    @State private var activeSwipeCount = 0

    @State private var didWin = false
    @State private var shardsEarned = 0

    @State private var showGatePenalty = false

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
            case .slope:              slopeBody
            case .jump, .trick:       jumpBody
            case .roundResult:        roundResultBody
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

            if showGatePenalty {
                Color.red.opacity(0.18).ignoresSafeArea().allowsHitTesting(false).transition(.opacity)
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
        .onDisappear { slopeTimer?.cancel(); airTimer?.cancel() }
    }

    // MARK: - Background

    private var slopeGradientBg: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.12, blue: 0.22), Theme.deepBlack],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Slope Phase View

    private var slopeBody: some View {
        VStack(spacing: 0) {
            slopeHeader.padding(.horizontal, 20).padding(.top, 12)
            Spacer()
            slopeVisual
            Spacer()
            speedMeterView.padding(.horizontal, 24)
            tapButtonRow.padding(.horizontal, 20).padding(.bottom, 32)
        }
    }

    private var slopeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("JUMP \(currentRound)/\(totalRounds)")
                    .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
                HStack(spacing: 3) {
                    ForEach(1...totalRounds, id: \.self) { i in
                        Circle()
                            .fill(i < currentRound ? Theme.foundationGreen : (i == currentRound ? accentColor : Theme.cardBorder))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            Spacer()
            ZStack {
                Circle().stroke(Theme.cardBorder, lineWidth: 3).frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(slopeTimeLeft / slopeDuration))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: slopeTimeLeft)
                Image(systemName: "timer").font(.system(size: 14, weight: .bold)).foregroundStyle(accentColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("TOTAL").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(totalScore)").font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(.white).contentTransition(.numericText())
            }
        }
    }

    private var slopeVisual: some View {
        SnowSlopeCanvas(speed: speed)
            .frame(height: 160)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 16)
    }

    private var speedMeterView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "speedometer").font(.system(size: 11, weight: .bold)).foregroundStyle(accentColor)
                Text("SPEED").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
                Spacer()
                Text("\(Int(speed))%").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(.white).contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.cardBorder).frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: speedBarColors(speed: speed), startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(speed / 100), height: 12)
                        .animation(.spring(response: 0.2), value: speed)
                }
            }
            .frame(height: 12)
            if lastGateMissed {
                Text("GATE MISSED — \u{2212}20% SPEED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.red).transition(.opacity)
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
            Button { tapLeft() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 24, weight: .black))
                    Text("L").font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(snowBlue).frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Theme.cardBackground).clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(snowBlue.opacity(0.3), lineWidth: 1))
            }.buttonStyle(.plain)

            VStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(accentColor).symbolEffect(.pulse)
                Text("TAP FAST").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                Text("TO GAIN SPEED").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
            }

            Button { tapRight() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "chevron.right").font(.system(size: 24, weight: .black))
                    Text("R").font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(snowBlue).frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Theme.cardBackground).clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(snowBlue.opacity(0.3), lineWidth: 1))
            }.buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Jump / Air Phase View

    private var jumpBody: some View {
        VStack(spacing: 0) {
            jumpHeader.padding(.horizontal, 20).padding(.top, 12)
            Spacer()
            jumpHeightVisual
            Spacer()
            jumpTrickPopup.frame(height: 80)
            if phase == .trick {
                trickButtonGrid.padding(.horizontal, 20).padding(.bottom, 32)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 36, weight: .bold)).foregroundStyle(accentColor).symbolEffect(.pulse)
                    Text("LAUNCHING...").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
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
                Text("JUMP \(currentRound)/\(totalRounds)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
                Text("SPEED: \(Int(speed))%").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(snowBlue)
            }
            Spacer()
            ZStack {
                Circle().stroke(Theme.cardBorder, lineWidth: 3).frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: airTime > 0 ? CGFloat(airTimeLeft / airTime) : 0)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: airTimeLeft)
                Text(String(format: "%.1f", airTimeLeft)).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("ROUND").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(roundTrickPoints)").font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(accentColor).contentTransition(.numericText())
            }
        }
    }

    private var jumpHeightVisual: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(spacing: 8) {
                Text("HEIGHT").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.cardBorder).frame(width: 16, height: 160)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [accentColor, snowBlue], startPoint: .bottom, endPoint: .top))
                        .frame(width: 16, height: 160 * CGFloat(jumpHeight))
                        .animation(.spring(response: 0.5), value: jumpHeight)
                }
            }

            SnowJumpCanvas(jumpHeight: jumpHeight, isTrickPhase: phase == .trick, trickName: trickPopup)
                .frame(width: 160, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("TRICKS").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                ForEach(roundTrickNames.prefix(4), id: \.self) { name in
                    HStack(spacing: 4) {
                        Circle().fill(Theme.foundationGreen).frame(width: 5, height: 5)
                        Text(name).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(accentColor)
                    }
                }
                if roundTrickNames.isEmpty {
                    Text("None yet").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
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
                Text(name.uppercased()).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(accentColor).shadow(color: accentColor.opacity(0.6), radius: 8)
                Text("+\(trickPopupPoints) pts").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            Color.clear
        }
    }

    private var trickButtonGrid: some View {
        VStack(spacing: 12) {
            Text("SWIPE OR TAP A TRICK").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(snowTricks) { trick in
                    Button { performSnowTrick(trick) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: trick.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(accentColor)
                            Text(trick.name.uppercased()).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.white)
                            Text("+\(trick.points)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.cardBackground).clipShape(.rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain).disabled(trickDoneThisAir).opacity(trickDoneThisAir ? 0.4 : 1.0)
                }
            }
        }
    }

    // MARK: - Round Result

    private var roundResultBody: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("JUMP \(currentRound - 1) SCORE").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(3)
            Text("\(roundScores.last ?? 0)").font(.system(size: 60, weight: .black, design: .monospaced)).foregroundStyle(accentColor).shadow(color: accentColor.opacity(0.4), radius: 16)
            Text("PTS").font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(4)
            if !roundTrickNames.isEmpty {
                HStack(spacing: 8) {
                    ForEach(roundTrickNames.prefix(4), id: \.self) { name in
                        Text(name).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.black)
                            .padding(.horizontal, 10).padding(.vertical, 5).background(accentColor).clipShape(.capsule)
                    }
                }
            }
            VStack(spacing: 6) {
                Text("TOTAL SO FAR").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(totalScore) pts").font(.system(size: 24, weight: .black, design: .monospaced)).foregroundStyle(Theme.foundationGreen)
            }
            .padding(.top, 8)
            if currentRound <= totalRounds {
                Button { startSlope() } label: {
                    Text("JUMP \(currentRound) — RIDE")
                        .font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16).background(accentColor).clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 40).padding(.top, 12)
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
                    speed = max(0, speed - 0.15)
                    if Int.random(in: 0...200) == 0 { missGate() }
                }
            }
            await MainActor.run { guard phase == .slope else { return }; launchJump() }
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
            await MainActor.run { withAnimation { showGatePenalty = false }; lastGateMissed = false }
        }
    }

    // MARK: - Logic: Jump

    private func launchJump() {
        slopeTimer?.cancel()
        airTime = 1.0 + (speed / 100.0) * 3.0
        airTimeLeft = airTime
        jumpHeight = speed / 100.0
        phase = .jump
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { guard phase == .jump else { return }; phase = .trick }
        }
        airTimer?.cancel()
        airTimer = Task {
            let tick: Double = 0.05
            while airTimeLeft > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    airTimeLeft = max(0, airTimeLeft - tick)
                    let progress = 1.0 - (airTimeLeft / airTime)
                    jumpHeight = sin(progress * .pi) * (speed / 100.0)
                }
            }
            await MainActor.run { guard phase == .jump || phase == .trick else { return }; landJump() }
        }
    }

    private func landJump() {
        airTimer?.cancel()
        jumpHeight = 0
        roundScores.append(roundTrickPoints)
        totalScore += roundTrickPoints
        if currentRound >= totalRounds {
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
        case .up:    performSnowTrick(snowTricks[2])
        case .right: performSnowTrick(snowTricks[1])
        case .left:  performSnowTrick(snowTricks[0])
        case .down:  performSnowTrick(snowTricks[3])
        }
    }

    private func performSnowTrick(_ trick: SnowTrick) {
        guard (phase == .jump || phase == .trick) && !trickDoneThisAir else { return }
        trickDoneThisAir = true
        roundTrickPoints += trick.points
        roundTrickNames.append(trick.name)
        showTrickPopup(name: trick.name, points: trick.points)
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run { if phase == .trick { trickDoneThisAir = false } }
        }
    }

    // MARK: - Trick popup

    private func showTrickPopup(name: String, points: Int) {
        popupTask?.cancel()
        withAnimation(.spring(response: 0.25)) { trickPopup = name; trickPopupPoints = points }
        popupTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { trickPopup = nil } }
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
