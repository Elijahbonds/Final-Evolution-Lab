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

// MARK: - Skate Park Drawer

private struct SkateDrawer {
    let W: CGFloat
    let H: CGFloat
    let grinding: Bool
    let trickName: String?
    let combo: Int
    let t: Double

    var groundY: CGFloat { H * 0.70 }
    var railSX: CGFloat { W * 0.24 }
    var railEX: CGFloat { W * 0.60 }
    var railSY: CGFloat { H * 0.70 - H * 0.07 }
    var railEY: CGFloat { H * 0.70 - H * 0.17 }

    mutating func render(ctx: inout GraphicsContext) {
        drawBG(ctx: &ctx)
        drawGround(ctx: &ctx)
        drawBox(ctx: &ctx)
        drawRail(ctx: &ctx)
        drawRamp(ctx: &ctx)
        drawSkater(ctx: &ctx)
        if combo >= 2 { drawComboFire(ctx: &ctx) }
    }

    private func drawBG(ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.10, green: 0.06, blue: 0.02),
                        Color(red: 0.04, green: 0.03, blue: 0.01)
                    ]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
        var glowGC = ctx
        glowGC.addFilter(.blur(radius: 32))
        glowGC.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.14)),
                    with: .color(Color(red: 0.95, green: 0.45, blue: 0.12).opacity(0.14)))
    }

    private func drawGround(ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: groundY, width: W, height: H - groundY)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.24, green: 0.21, blue: 0.18),
                        Color(red: 0.12, green: 0.10, blue: 0.09)
                    ]),
                    startPoint: CGPoint(x: 0, y: groundY),
                    endPoint: CGPoint(x: 0, y: H)))
        for i in 0..<4 {
            let sx = W * CGFloat(i + 1) / 5.0
            var seam = Path()
            seam.move(to: CGPoint(x: sx, y: groundY))
            seam.addLine(to: CGPoint(x: sx + W * 0.04, y: H))
            ctx.stroke(seam, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
        }
        // Ground edge highlight
        var edge = Path()
        edge.move(to: CGPoint(x: 0, y: groundY))
        edge.addLine(to: CGPoint(x: W, y: groundY))
        ctx.stroke(edge, with: .color(.white.opacity(0.10)), lineWidth: 1)
    }

    private func drawBox(ctx: inout GraphicsContext) {
        let bL = W * 0.04, bR = W * 0.22
        let bTop = groundY - H * 0.14, bBot = groundY
        let dX = W * 0.025, dY = H * 0.04

        ctx.fill(Path(CGRect(x: bL, y: bTop, width: bR - bL, height: bBot - bTop)),
                 with: .color(Color(red: 0.30, green: 0.27, blue: 0.24)))

        var topFace = Path()
        topFace.move(to: CGPoint(x: bL, y: bTop))
        topFace.addLine(to: CGPoint(x: bL + dX, y: bTop - dY))
        topFace.addLine(to: CGPoint(x: bR + dX, y: bTop - dY))
        topFace.addLine(to: CGPoint(x: bR, y: bTop))
        topFace.closeSubpath()
        ctx.fill(topFace, with: .color(Color(red: 0.42, green: 0.38, blue: 0.34)))

        var rightFace = Path()
        rightFace.move(to: CGPoint(x: bR, y: bTop))
        rightFace.addLine(to: CGPoint(x: bR + dX, y: bTop - dY))
        rightFace.addLine(to: CGPoint(x: bR + dX, y: bBot - dY))
        rightFace.addLine(to: CGPoint(x: bR, y: bBot))
        rightFace.closeSubpath()
        ctx.fill(rightFace, with: .color(Color(red: 0.20, green: 0.18, blue: 0.16)))

        ctx.stroke(Path(CGRect(x: bL, y: bTop, width: bR - bL, height: bBot - bTop)),
                   with: .color(.white.opacity(0.07)), lineWidth: 1)
        // Graffiti accent stripe
        ctx.fill(Path(CGRect(x: bL + (bR - bL) * 0.15, y: bBot - H * 0.06,
                              width: (bR - bL) * 0.5, height: H * 0.03)),
                 with: .color(Color(red: 0.95, green: 0.45, blue: 0.12).opacity(0.25)))
    }

    private func drawRail(ctx: inout GraphicsContext) {
        let shimmer = CGFloat(sin(t * 2.8)) * 0.12 + 0.42
        var railPath = Path()
        railPath.move(to: CGPoint(x: railSX, y: railSY))
        railPath.addLine(to: CGPoint(x: railEX, y: railEY))

        ctx.stroke(railPath,
                   with: .color(Color(red: 0.62, green: 0.62, blue: 0.70).opacity(0.88)),
                   lineWidth: 5)
        ctx.stroke(railPath,
                   with: .color(Color.white.opacity(shimmer)),
                   lineWidth: 1.5)

        for i in 0..<3 {
            let f = CGFloat(i + 1) / 4.0
            let sx = railSX + (railEX - railSX) * f
            let sy = railSY + (railEY - railSY) * f
            var support = Path()
            support.move(to: CGPoint(x: sx, y: sy))
            support.addLine(to: CGPoint(x: sx, y: groundY))
            ctx.stroke(support,
                       with: .color(Color(red: 0.50, green: 0.50, blue: 0.55).opacity(0.55)),
                       lineWidth: 2)
        }

        if grinding {
            var gc = ctx
            gc.addFilter(.blur(radius: 10))
            gc.stroke(railPath,
                      with: .color(Color(red: 0.95, green: 0.45, blue: 0.12).opacity(0.80)),
                      lineWidth: 10)
            // Grind sparks
            for i in 0..<6 {
                let f = Double(i) / 6.0
                let sparkPhase = fmod(t * 4.0 + f, 1.0)
                let sx = railSX + (railEX - railSX) * CGFloat(sparkPhase)
                let sy = railSY + (railEY - railSY) * CGFloat(sparkPhase)
                ctx.fill(Path(ellipseIn: CGRect(x: sx - 2, y: sy - CGFloat(3 + f * 5),
                                                 width: 4, height: 4)),
                         with: .color(Color(red: 1.0, green: 0.85, blue: 0.30).opacity(CGFloat(1.0 - sparkPhase))))
            }
        }
    }

    private func drawRamp(ctx: inout GraphicsContext) {
        let rampL = W * 0.72, rampR = W * 0.97, rampTop = H * 0.18

        var rampPath = Path()
        rampPath.move(to: CGPoint(x: rampL, y: groundY))
        rampPath.addQuadCurve(
            to: CGPoint(x: rampR, y: rampTop),
            control: CGPoint(x: rampL, y: rampTop))
        rampPath.addLine(to: CGPoint(x: rampR, y: groundY))
        rampPath.closeSubpath()

        ctx.fill(rampPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.28, green: 0.25, blue: 0.22),
                Color(red: 0.16, green: 0.14, blue: 0.12)
            ]),
            startPoint: CGPoint(x: rampL, y: rampTop),
            endPoint: CGPoint(x: rampL, y: groundY)))

        // Surface texture lines
        for i in 0..<5 {
            let fi = CGFloat(i) / 4.0
            let ly = rampTop + (groundY - rampTop) * fi * 0.88
            let lx = rampL + (rampR - rampL) * fi * 0.12
            var texLine = Path()
            texLine.move(to: CGPoint(x: lx, y: ly))
            texLine.addLine(to: CGPoint(x: rampR, y: ly + H * 0.02))
            ctx.stroke(texLine, with: .color(.white.opacity(0.04)), lineWidth: 1)
        }

        ctx.stroke(rampPath, with: .color(.white.opacity(0.08)), lineWidth: 1)
        // Coping
        ctx.fill(Path(ellipseIn: CGRect(x: rampR - 6, y: rampTop - 6, width: 12, height: 12)),
                 with: .color(Color(red: 0.58, green: 0.58, blue: 0.64).opacity(0.85)))
    }

    private func drawSkater(ctx: inout GraphicsContext) {
        var px: CGFloat
        var py: CGFloat
        var airborne: Bool = false
        var boardAngle: CGFloat = 0

        if grinding {
            let railT = CGFloat(fmod(t * 0.38, 1.0))
            px = railSX + (railEX - railSX) * railT
            py = railSY + (railEY - railSY) * railT - 14
        } else if trickName != nil {
            let trickT = fmod(t * 3.2, .pi)
            let jumpMag: Double = trickName == "360 Flip" ? 44 : (trickName == "Ollie" ? 28 : 36)
            let jumpH = CGFloat(sin(trickT)) * CGFloat(jumpMag)
            px = W * 0.42
            py = groundY - jumpH
            airborne = true
            if trickName == "Kickflip" || trickName == "Heelflip" || trickName == "360 Flip" {
                boardAngle = CGFloat(fmod(t * 10.0, .pi * 2.0))
            }
        } else {
            let skateT = CGFloat(fmod(t * 0.30, 1.0))
            px = W * 0.08 + skateT * W * 0.55
            py = groundY + CGFloat(sin(t * 9.0)) * 1.5
        }

        drawFigure(ctx: &ctx, cx: px, cy: py, airborne: airborne, boardAngle: boardAngle)
    }

    private func drawFigure(ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
                            airborne: Bool, boardAngle: CGFloat) {
        let accentShading = GraphicsContext.Shading.color(Color(red: 0.95, green: 0.45, blue: 0.12))
        let darkShading = GraphicsContext.Shading.color(Color(red: 0.12, green: 0.10, blue: 0.08))
        let skinShading = GraphicsContext.Shading.color(Color(red: 0.88, green: 0.65, blue: 0.44))

        // Ground shadow
        var shadowGC = ctx
        shadowGC.addFilter(.blur(radius: 5))
        let shadowS = airborne ? max(CGFloat(0.4), 1.0 - (groundY - cy) / 40.0) : CGFloat(1.0)
        shadowGC.fill(Path(ellipseIn: CGRect(x: cx - 18 * shadowS, y: groundY,
                                              width: 36 * shadowS, height: 5 * shadowS)),
                      with: .color(.black.opacity(0.5 * shadowS)))

        var gc = ctx
        gc.translateBy(x: cx, y: cy)

        // Board (possibly spinning)
        var boardGC = gc
        if boardAngle != 0 {
            boardGC.rotate(by: .radians(boardAngle))
        }
        let bw: CGFloat = 28, bh: CGFloat = grinding ? 4 : 6
        boardGC.fill(Path(roundedRect: CGRect(x: -bw / 2, y: 0, width: bw, height: bh),
                          cornerRadius: CGSize(width: 2, height: 2)),
                     with: .color(.white.opacity(0.90)))
        boardGC.fill(Path(roundedRect: CGRect(x: -bw / 2, y: 0, width: bw, height: 2),
                          cornerRadius: CGSize(width: 1, height: 1)),
                     with: accentShading)

        let crouchDelta: CGFloat = grinding ? -4 : (airborne ? -2 : 0)

        var legPath = Path()
        legPath.move(to: CGPoint(x: -7, y: crouchDelta))
        legPath.addLine(to: CGPoint(x: -4, y: -9 + crouchDelta * 0.4))
        legPath.addLine(to: CGPoint(x: -1, y: -14))
        legPath.move(to: CGPoint(x: 7, y: crouchDelta))
        legPath.addLine(to: CGPoint(x: 4, y: -9 + crouchDelta * 0.4))
        legPath.addLine(to: CGPoint(x: 1, y: -14))
        gc.stroke(legPath, with: darkShading, lineWidth: 2.8)

        var torso = Path()
        torso.move(to: CGPoint(x: 0, y: -14))
        torso.addLine(to: CGPoint(x: 0, y: -24))
        gc.stroke(torso, with: accentShading, lineWidth: 3.0)

        let armW: CGFloat = airborne ? 15 : 10
        var armPath = Path()
        armPath.move(to: CGPoint(x: -armW, y: -20))
        armPath.addLine(to: CGPoint(x: 0, y: -19))
        armPath.addLine(to: CGPoint(x: armW, y: -20))
        gc.stroke(armPath, with: skinShading, lineWidth: 2.5)

        gc.fill(Path(ellipseIn: CGRect(x: -5, y: -33, width: 10, height: 10)), with: skinShading)

        // Cap
        var capPath = Path()
        capPath.move(to: CGPoint(x: -6, y: -33))
        capPath.addLine(to: CGPoint(x: 7, y: -33))
        capPath.addLine(to: CGPoint(x: 5, y: -39))
        capPath.addLine(to: CGPoint(x: -4, y: -39))
        capPath.closeSubpath()
        gc.fill(capPath, with: darkShading)
    }

    private func drawComboFire(ctx: inout GraphicsContext) {
        let intensity = min(1.0, Double(combo - 1) / 2.0)
        let pulse = abs(sin(t * 6.0))
        var gc = ctx
        gc.addFilter(.blur(radius: 20))
        var px: CGFloat
        if grinding {
            px = railSX + (railEX - railSX) * CGFloat(fmod(t * 0.38, 1.0))
        } else if trickName != nil {
            px = W * 0.42
        } else {
            px = W * 0.08 + CGFloat(fmod(t * 0.30, 1.0)) * W * 0.55
        }
        gc.fill(Path(ellipseIn: CGRect(x: px - 14, y: groundY - 32, width: 28, height: 36)),
                with: .color(Color(red: 0.95, green: 0.45, blue: 0.12)
                    .opacity(intensity * (0.45 + pulse * 0.30))))
    }
}

// MARK: - Skate Park Canvas

private struct SkateParkCanvas: View {
    let grinding: Bool
    let trickName: String?
    let combo: Int

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var drawer = SkateDrawer(
                    W: size.width, H: size.height,
                    grinding: grinding, trickName: trickName,
                    combo: combo, t: t)
                drawer.render(ctx: &ctx)
            }
        }
    }
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

    @State private var phase: SkatePhase = .ready
    @State private var currentRun = 1
    @State private var timeLeft: Double = 10
    @State private var runTimer: Task<Void, Never>? = nil

    @State private var currentRunScore = 0
    @State private var bestRunScore = 0
    @State private var runScores: [Int] = []

    @State private var comboCount = 0
    @State private var lastTrickIndex: Int? = nil
    @State private var lastTrickTime: Date? = nil

    @State private var trickPopup: String? = nil
    @State private var trickPopupPoints: Int = 0
    @State private var popupTask: Task<Void, Never>? = nil

    @State private var isGrinding = false
    @State private var grindTask: Task<Void, Never>? = nil

    @State private var showBailFlash = false
    @State private var swipeStartLocation: CGPoint = .zero
    @State private var lastSwipeEnd: Date = .distantPast

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
            case .running:     runningBody
            case .bail:        bailBody
            case .runTransition: runTransitionBody
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
            headerBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer()

            trickPopupView
                .frame(height: 80)

            comboChainView

            Spacer()

            skateParkVisual

            Spacer()

            swipeInputArea
                .padding(.bottom, 32)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RUN \(currentRun)/\(totalRuns)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor).tracking(2)
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

            ZStack {
                Circle().stroke(Theme.cardBorder, lineWidth: 3).frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(timeLeft / runDuration))
                    .stroke(timeLeft > 4 ? accentColor : .red,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timeLeft)
                Text(String(format: "%.0f", timeLeft))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(timeLeft > 4 ? .white : .red)
                    .contentTransition(.numericText())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(2)
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
                Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.yellow)
                Text("x\(comboCount) COMBO")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow).tracking(1)
                Text("(\(comboMultiplierLabel))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.7))
            }
        }
        .frame(height: 24)
        .animation(.spring(response: 0.3), value: comboCount)
    }

    private var comboMultiplierLabel: String { "×\(comboMultiplier(for: comboCount))" }

    private var skateParkVisual: some View {
        SkateParkCanvas(grinding: isGrinding, trickName: trickPopup, combo: comboCount)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 16)
    }

    private var swipeInputArea: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(skateTricks.prefix(4)) { trick in
                    VStack(spacing: 4) {
                        Image(systemName: trick.icon).font(.system(size: 14, weight: .bold)).foregroundStyle(accentColor)
                        Text(trick.name).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        Text("\(trick.points)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
                    }.frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isGrinding ? accentColor.opacity(0.6) : Theme.cardBorder,
                                    lineWidth: isGrinding ? 2 : 1))
                    .frame(height: 100)

                VStack(spacing: 4) {
                    if isGrinding {
                        Text("GRINDING...")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                        Text("HOLD · \(Int(75))pts/sec")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "hand.draw").font(.system(size: 22, weight: .medium)).foregroundStyle(.white.opacity(0.25))
                        Text("SWIPE TO TRICK  ·  HOLD FOR GRIND")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25)).tracking(1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if swipeStartLocation == .zero { swipeStartLocation = value.startLocation }
                        let dist = hypot(value.translation.width, value.translation.height)
                        if dist < 20 && !isGrinding { startGrind() }
                    }
                    .onEnded { value in
                        endGrind()
                        let dx = value.translation.width, dy = value.translation.height
                        let dist = hypot(dx, dy)
                        guard dist > 20 else { swipeStartLocation = .zero; return }
                        let dir = swipeDirection(dx: dx, dy: dy)
                        handleSwipe(dir: dir)
                        swipeStartLocation = .zero
                    }
            )
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in startGrind() })

            HStack {
                Spacer()
                Button {
                    if isGrinding { endGrind() } else { startGrind() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isGrinding ? "stop.fill" : "minus").font(.system(size: 12, weight: .bold))
                        Text(isGrinding ? "END GRIND" : "GRIND").font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(isGrinding ? .black : accentColor)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(isGrinding ? accentColor : Theme.cardBackground)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(accentColor.opacity(0.4), lineWidth: 1))
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
                Circle().fill(Color.red.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44, weight: .bold)).foregroundStyle(.red)
                    .symbolEffect(.pulse)
            }
            Text("BAIL!")
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundStyle(.red).italic()
            Text("Same trick twice — lost your combo")
                .font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Run \(currentRun) Score: \(currentRunScore) pts")
                .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Run Transition

    private var runTransitionBody: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("RUN \(currentRun - 1) COMPLETE")
                .font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(3)
            Text("\(runScores.last ?? 0)")
                .font(.system(size: 56, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor).shadow(color: accentColor.opacity(0.4), radius: 16)
            Text("PTS").font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(4)
            if currentRun <= totalRuns {
                Button { startRun() } label: {
                    Text("RUN \(currentRun) — GO")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(accentColor).clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 40).padding(.top, 16)
            }
            VStack(spacing: 8) {
                Text("BEST RUN").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(bestRunScore) pts").font(.system(size: 20, weight: .black, design: .monospaced)).foregroundStyle(Theme.foundationGreen)
            }
            Spacer()
        }
    }

    // MARK: - Swipe Recognition

    private func swipeDirection(dx: CGFloat, dy: CGFloat) -> SwipeDir {
        let angle = atan2(-dy, dx) * 180 / .pi
        let now = Date()
        let isDouble = now.timeIntervalSince(lastSwipeEnd) < 0.4
        lastSwipeEnd = now
        if isDouble && dy < -30 { return .doubleUp }
        if abs(angle - 90) < 30 { return .up }
        if angle > 30 && angle < 80 { return .upRight }
        if angle > 100 && angle < 160 { return .upLeft }
        return .up
    }

    // MARK: - Trick Execution

    private func handleSwipe(dir: SwipeDir) {
        guard phase == .running else { return }
        switch dir {
        case .up:       performTrick(index: 0)
        case .upRight:  performTrick(index: 1)
        case .upLeft:   performTrick(index: 2)
        case .doubleUp: performTrick(index: 3)
        case .hold:     startGrind()
        }
    }

    private func performTrick(index: Int) {
        guard phase == .running else { return }
        let trick = skateTricks[index]
        let now = Date()
        if lastTrickIndex == index, let last = lastTrickTime, now.timeIntervalSince(last) < 2.0 {
            if Double.random(in: 0...1) < 0.40 { triggerBail(); return }
        }
        lastTrickIndex = index
        lastTrickTime = now
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
            while !Task.isCancelled && isGrinding && phase == .running {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if isGrinding && phase == .running {
                        let mult = comboMultiplier(for: comboCount)
                        let pts = Int(37.5 * Double(mult))
                        currentRunScore += pts
                        bestRunScore = max(bestRunScore, currentRunScore)
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
                await MainActor.run { timeLeft = max(0, timeLeft - tick) }
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
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { trickPopup = nil } }
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
