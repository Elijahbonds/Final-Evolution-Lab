import SwiftUI

// MARK: - Phase

private enum GymnasticsPhase {
    case ready, active, elementFeedback, judging, result
}

// MARK: - Swipe Direction

private enum GymnasticsSwipeDir: String {
    case up      = "↑"
    case down    = "↓"
    case left    = "←"
    case right   = "→"
    case upRight = "↗"
    case upLeft  = "↖"

    var systemImage: String {
        switch self {
        case .up:      return "arrow.up"
        case .down:    return "arrow.down"
        case .left:    return "arrow.left"
        case .right:   return "arrow.right"
        case .upRight: return "arrow.up.right"
        case .upLeft:  return "arrow.up.left"
        }
    }
}

// MARK: - Timing Grade

private enum TimingGrade: String {
    case perfect = "PERFECT"
    case good    = "GOOD"
    case late    = "LATE"
    case miss    = "MISS"

    var points: Int {
        switch self {
        case .perfect: return 10
        case .good:    return 7
        case .late:    return 4
        case .miss:    return 0
        }
    }

    var color: Color {
        switch self {
        case .perfect: return .yellow
        case .good:    return Theme.brandCyan
        case .late:    return Theme.brandBlue
        case .miss:    return .red
        }
    }
}

// MARK: - Gymnastics Element

private struct GymnasticsElement: Identifiable {
    let id = UUID()
    let name: String
    let prompt: String
    let direction: GymnasticsSwipeDir
}

private let kRoutineElements: [GymnasticsElement] = [
    GymnasticsElement(name: "Tumble",   prompt: "TUMBLE",   direction: .upRight),
    GymnasticsElement(name: "Vault",    prompt: "VAULT",    direction: .up),
    GymnasticsElement(name: "Leap",     prompt: "LEAP",     direction: .upLeft),
    GymnasticsElement(name: "Turn",     prompt: "TURN",     direction: .left),
    GymnasticsElement(name: "Jump",     prompt: "JUMP",     direction: .up),
    GymnasticsElement(name: "Dismount", prompt: "DISMOUNT", direction: .right),
]

// MARK: - Element Result

private struct GymElementResult {
    let element: GymnasticsElement
    let grade: TimingGrade
    let rawPoints: Int
    let deduction: Double
    let finalPoints: Double
    let judge1: Double
    let judge2: Double
    let judge3: Double
}

// MARK: - Arena Canvas

private struct GymnasticsArenaCanvas: View {
    let elementIndex: Int
    let gradeColor: Color
    let showFlash: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                var d = GymDrawer(t: tl.date.timeIntervalSinceReferenceDate,
                                  W: size.width, H: size.height,
                                  elementIndex: elementIndex,
                                  gradeColor: gradeColor, showFlash: showFlash)
                d.render(ctx: &ctx)
            }
        }
    }
}

private struct GymDrawer {
    let t: Double
    let W: CGFloat; let H: CGFloat
    let elementIndex: Int
    let gradeColor: Color; let showFlash: Bool

    var matY: CGFloat { H * 0.72 }
    var gx: CGFloat { W * 0.50 }
    var gy: CGFloat { matY - 2 }

    mutating func render(ctx: inout GraphicsContext) {
        drawArenaBG(&ctx)
        drawSpotlights(&ctx)
        drawMat(&ctx)
        drawJudges(&ctx)
        drawGymnast(&ctx)
        if showFlash { drawFlash(&ctx) }
    }

    private func drawArenaBG(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red:0.04,green:0.02,blue:0.18),
                                      Color(red:0.08,green:0.04,blue:0.22)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
        // Audience tiers
        let jerseys: [Color] = [Color(red:0.72,green:0.12,blue:0.12),
                                 Color(red:0.12,green:0.35,blue:0.72),
                                 Color(red:0.55,green:0.45,blue:0.10),
                                 Color(red:0.25,green:0.25,blue:0.28)]
        for row in 0..<3 {
            let ry = H * CGFloat(0.08 + Double(row) * 0.10)
            let cols = 28
            for col in 0..<cols {
                let cx = W * CGFloat(col + 1) / CGFloat(cols + 1)
                let jc = jerseys[(col * 3 + row * 5) % jerseys.count]
                let wave = CGFloat(sin(t * 0.9 + Double(col) * 0.5 + Double(row))) * 1.2
                ctx.fill(Path(ellipseIn: CGRect(x: cx-4, y: ry + wave - 4, width: 8, height: 8)),
                         with: .color(jc.opacity(0.55)))
            }
        }
    }

    private func drawSpotlights(_ ctx: inout GraphicsContext) {
        let lightPositions: [(CGFloat, CGFloat)] = [(W*0.2,0),(W*0.4,0),(W*0.6,0),(W*0.8,0)]
        for (lx, _) in lightPositions {
            // Cone
            var cone = Path()
            cone.move(to: CGPoint(x: lx, y: 0))
            cone.addLine(to: CGPoint(x: gx - 28, y: matY))
            cone.addLine(to: CGPoint(x: gx + 28, y: matY))
            cone.closeSubpath()
            var gc = ctx; gc.addFilter(.blur(radius: 16))
            gc.fill(cone, with: .color(Color(red:1,green:0.97,blue:0.82).opacity(0.06)))
            // Light source bloom
            var bloom = ctx; bloom.addFilter(.blur(radius: 8))
            bloom.fill(Path(ellipseIn: CGRect(x: lx-5, y: -4, width: 10, height: 10)),
                       with: .color(Color(red:1,green:0.97,blue:0.82).opacity(0.50)))
        }
    }

    private func drawMat(_ ctx: inout GraphicsContext) {
        // Mat shadow
        var sc = ctx; sc.addFilter(.blur(radius: 8))
        sc.fill(Path(CGRect(x: W*0.08+6, y: matY+6, width: W*0.84, height: H*0.22)),
                with: .color(.black.opacity(0.40)))
        // Mat surface
        ctx.fill(Path(CGRect(x: W*0.08, y: matY, width: W*0.84, height: H*0.22)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red:0.12,green:0.14,blue:0.48),
                                      Color(red:0.10,green:0.11,blue:0.38)]),
                    startPoint: CGPoint(x: W*0.08, y: matY),
                    endPoint: CGPoint(x: W*0.08, y: matY + H*0.22)))
        // Mat border lines
        ctx.stroke(Path(CGRect(x: W*0.08, y: matY, width: W*0.84, height: H*0.22)),
                   with: .color(Color(red:0.45,green:0.48,blue:0.88).opacity(0.7)), lineWidth: 2)
        // Center cross
        var cross = Path()
        cross.move(to: CGPoint(x: W*0.5, y: matY)); cross.addLine(to: CGPoint(x: W*0.5, y: matY + H*0.22))
        cross.move(to: CGPoint(x: W*0.08, y: matY + H*0.11)); cross.addLine(to: CGPoint(x: W*0.92, y: matY + H*0.11))
        ctx.stroke(cross, with: .color(Color(red:0.45,green:0.48,blue:0.88).opacity(0.25)), lineWidth: 0.8)
    }

    private func drawJudges(_ ctx: inout GraphicsContext) {
        let tableY = matY + H * 0.26
        // Table
        ctx.fill(Path(CGRect(x: W*0.18, y: tableY, width: W*0.64, height: 14)),
                 with: .color(Color(red:0.18,green:0.16,blue:0.30)))
        // 3 judges
        for j in 0..<3 {
            let jx = W * CGFloat(0.28 + Double(j) * 0.22)
            let jy = tableY - 12
            ctx.fill(Path(ellipseIn: CGRect(x: jx-5, y: jy-5, width: 10, height: 10)),
                     with: .color(Color(red:0.65,green:0.55,blue:0.45)))
            var body = Path()
            body.move(to: CGPoint(x: jx, y: jy+4)); body.addLine(to: CGPoint(x: jx, y: jy+12))
            ctx.stroke(body, with: .color(Color(red:0.22,green:0.20,blue:0.35)), lineWidth: 4)
        }
    }

    private func drawGymnast(_ ctx: inout GraphicsContext) {
        let period: Double
        switch elementIndex {
        case 0: period = 2.2  // Tumble
        case 1: period = 2.0  // Vault
        case 2: period = 1.8  // Leap
        case 3: period = 1.0  // Turn
        case 4: period = 1.5  // Jump
        default: period = 2.0 // Dismount
        }
        let p = fmod(t, period) / period  // 0→1 animation phase

        let leotard = Color(red:0.38,green:0.40,blue:0.95)
        let skin    = Color(red:0.94,green:0.81,blue:0.68)

        switch elementIndex {
        case 0: drawTumble(&ctx, p: p, leotard: leotard, skin: skin)
        case 1: drawVault(&ctx, p: p, leotard: leotard, skin: skin)
        case 2: drawLeap(&ctx, p: p, leotard: leotard, skin: skin)
        case 3: drawTurn(&ctx, p: p, leotard: leotard, skin: skin)
        case 4: drawJump(&ctx, p: p, leotard: leotard, skin: skin)
        default: drawDismount(&ctx, p: p, leotard: leotard, skin: skin)
        }
    }

    // -- Element Animations --

    private func drawTumble(_ ctx: inout GraphicsContext, p: Double,
                             leotard: Color, skin: Color) {
        // Run left→right → flip
        let runX = gx - 70 + CGFloat(p) * 140
        let jumpH = p > 0.4 && p < 0.85 ? CGFloat(sin((p - 0.4) / 0.45 * .pi)) * 55 : 0
        let rot = p > 0.45 ? (p - 0.45) / 0.4 * 2 * .pi : 0
        let cy = gy - jumpH
        drawFigure(&ctx, cx: runX, cy: cy, rotation: rot, leotard: leotard, skin: skin,
                   armSpread: p > 0.45 && p < 0.85 ? 0.0 : 1.0, legSpread: p > 0.45 && p < 0.85 ? 0.0 : 0.8)
    }

    private func drawVault(_ ctx: inout GraphicsContext, p: Double,
                            leotard: Color, skin: Color) {
        let vx = gx - 60 + CGFloat(p) * 120
        let jumpH = p > 0.3 && p < 0.9 ? CGFloat(sin((p - 0.3) / 0.6 * .pi)) * 60 : 0
        let rot = p > 0.4 && p < 0.8 ? CGFloat((p - 0.4) / 0.4 * .pi) : 0
        drawFigure(&ctx, cx: vx, cy: gy - jumpH, rotation: Double(rot), leotard: leotard, skin: skin,
                   armSpread: p < 0.3 || p > 0.85 ? 1.0 : 0.2, legSpread: p > 0.4 && p < 0.8 ? 0.1 : 0.8)
    }

    private func drawLeap(_ ctx: inout GraphicsContext, p: Double,
                           leotard: Color, skin: Color) {
        let jumpH = CGFloat(sin(p * .pi)) * 52
        let legSprd = CGFloat(sin(p * .pi)) * 1.5
        let lx = gx - 40 + CGFloat(p) * 80
        drawFigure(&ctx, cx: lx, cy: gy - jumpH, rotation: 0, leotard: leotard, skin: skin,
                   armSpread: 1.8, legSpread: legSprd)
    }

    private func drawTurn(_ ctx: inout GraphicsContext, p: Double,
                           leotard: Color, skin: Color) {
        // Spinning in place — arm one side, leg raised
        let spinAngle = p * 2 * .pi
        let armAngle = CGFloat(spinAngle)
        let raiseY: CGFloat = -16
        let shadow = ctx
        _ = shadow
        drawFigure(&ctx, cx: gx, cy: gy, rotation: 0, leotard: leotard, skin: skin,
                   armSpread: 1.0 + CGFloat(cos(spinAngle)) * 0.5, legSpread: 0.4)
        // Raised leg indicator
        var leg = Path()
        leg.move(to: CGPoint(x: gx, y: gy + 14))
        leg.addLine(to: CGPoint(x: gx + CGFloat(cos(spinAngle + .pi/2)) * 20,
                                 y: gy + raiseY + CGFloat(sin(spinAngle + .pi/2)) * 10))
        ctx.stroke(leg, with: .color(leotard), lineWidth: 2.5)
    }

    private func drawJump(_ ctx: inout GraphicsContext, p: Double,
                           leotard: Color, skin: Color) {
        let jumpH = CGFloat(sin(p * .pi)) * 48
        let tuck = p > 0.35 && p < 0.75 ? CGFloat(sin((p - 0.35) / 0.4 * .pi)) : 0
        drawFigure(&ctx, cx: gx, cy: gy - jumpH, rotation: 0, leotard: leotard, skin: skin,
                   armSpread: 1.4, legSpread: tuck * 0.4 + 0.3)
    }

    private func drawDismount(_ ctx: inout GraphicsContext, p: Double,
                               leotard: Color, skin: Color) {
        let lx = gx + (CGFloat(p) - 0.5) * 100
        let jumpH = p > 0.15 && p < 0.85 ? CGFloat(sin((p - 0.15) / 0.7 * .pi)) * 58 : 0
        let rot = p > 0.2 && p < 0.8 ? (p - 0.2) / 0.6 * 1.5 * .pi : 0
        drawFigure(&ctx, cx: lx, cy: gy - jumpH, rotation: rot, leotard: leotard, skin: skin,
                   armSpread: p < 0.3 || p > 0.75 ? 0.8 : 0.1, legSpread: 0.3)
    }

    private func drawFigure(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
                             rotation: Double, leotard: Color, skin: Color,
                             armSpread: CGFloat, legSpread: CGFloat) {
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: .radians(rotation))

        // Shadow on mat
        var sc = ctx; sc.addFilter(.blur(radius: 5))
        sc.fill(Path(ellipseIn: CGRect(x: -12, y: matY - cy - 2, width: 24, height: 6)),
                with: .color(.black.opacity(max(0, 0.35 - (cy - gy) / 120))))

        // Head
        ctx.fill(Path(ellipseIn: CGRect(x: -5, y: -34, width: 10, height: 10)), with: .color(skin))

        // Torso
        var torso = Path(); torso.move(to: CGPoint(x: 0, y: -24)); torso.addLine(to: CGPoint(x: 0, y: -8))
        ctx.stroke(torso, with: .color(leotard), lineWidth: 4)

        // Arms
        let aOff = armSpread * 14
        var arms = Path()
        arms.move(to: CGPoint(x: -aOff, y: -20)); arms.addLine(to: CGPoint(x: 0, y: -20))
        arms.addLine(to: CGPoint(x: aOff, y: -20))
        ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)

        // Legs
        let lOff = legSpread * 12
        var legs = Path()
        legs.move(to: CGPoint(x: -lOff, y: 10)); legs.addLine(to: CGPoint(x: 0, y: -8))
        legs.addLine(to: CGPoint(x: lOff, y: 10))
        ctx.stroke(legs, with: .color(leotard), lineWidth: 2.8)

        ctx.rotate(by: .radians(-rotation))
        ctx.translateBy(x: -cx, y: -cy)
    }

    private func drawFlash(_ ctx: inout GraphicsContext) {
        var gc = ctx; gc.addFilter(.blur(radius: 20))
        gc.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                with: .color(gradeColor.opacity(0.25)))
    }
}

// MARK: - GymnasticsGameView

struct GymnasticsGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: GymnasticsPhase = .ready
    @State private var currentElementIndex: Int = 0
    @State private var elementResults: [GymElementResult] = []

    @State private var timeLeft: Double = 2.0
    @State private var elementTimer: Task<Void, Never>?

    @State private var swipeStartTime: Date = .now
    @State private var didSwipeThisElement: Bool = false

    @State private var showGradeFlash: Bool = false
    @State private var gradeFlashText: String = ""
    @State private var gradeFlashColor: Color = .white

    @State private var judgeScoresVisible: [Bool] = [false, false, false]
    @State private var currentJudgeScores: (Double, Double, Double) = (0, 0, 0)
    @State private var showJudgePanel: Bool = false

    @State private var difficultyMeter: Double = 0.72
    @State private var executionBar: Double = 0.0
    @State private var artisticImpression: Double = 0.0

    @State private var frozenAIScore: Double = 46.0
    @State private var rewardApplied: Bool = false

    private let accentColor = Color(red: 0.39, green: 0.4, blue: 0.95)
    private let totalElements = kRoutineElements.count

    private var totalScore: Double { elementResults.reduce(0) { $0 + $1.finalPoints } }
    private var playerWins: Bool { totalScore > frozenAIScore }
    private var isDraw: Bool { Int(totalScore) == Int(frozenAIScore) }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.02, blue: 0.18), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Gymnastics",
                    subtitle: "6 elements · Swipe on cue · Judges watching",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: {
                        frozenAIScore = Double(Int.random(in: 38...54))
                        phase = .active
                        startElement()
                    }
                )

            case .active:
                activeBody

            case .elementFeedback:
                feedbackBody

            case .judging:
                judgingBody

            case .result:
                ResultScreen(
                    winner: playerWins ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: Int(totalScore),
                    p2Score: Int(frozenAIScore),
                    title: "Gymnastics",
                    accentColor: accentColor,
                    prqGain: playerWins ? 12 : (isDraw ? 5 : 3),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "Execution",
                    modeAttributeValue: executionBar,
                    onReturn: { dismiss() }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { elementTimer?.cancel(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { elementTimer?.cancel() }
    }

    // MARK: - Active Body

    private var activeBody: some View {
        VStack(spacing: 0) {
            topHUD
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer()

            if currentElementIndex < kRoutineElements.count {
                elementPromptCard(element: kRoutineElements[currentElementIndex])
            }

            Spacer()

            if showJudgePanel {
                judgePanelRow
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            swipeZone
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
        .overlay(gradeFlashOverlay)
    }

    // MARK: - Top HUD

    private var topHUD: some View {
        HStack(spacing: 0) {
            // Difficulty
            VStack(alignment: .leading, spacing: 3) {
                Text("DIFFICULTY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(width: 76, height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(accentColor).frame(width: 76 * difficultyMeter, height: 6)
                }
                Text(String(format: "%.1f", difficultyMeter * 10))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
            }

            Spacer()

            // Progress dots
            VStack(spacing: 4) {
                Text("ELEMENT")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                HStack(spacing: 5) {
                    ForEach(0..<totalElements, id: \.self) { i in
                        Circle()
                            .fill(i < currentElementIndex
                                  ? accentColor
                                  : (i == currentElementIndex ? accentColor.opacity(0.55) : Color.white.opacity(0.1)))
                            .frame(width: 9, height: 9)
                            .animation(.spring(response: 0.3), value: currentElementIndex)
                    }
                }
                Text("\(min(currentElementIndex + 1, totalElements)) / \(totalElements)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 3) {
                Text("SCORE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text(String(format: "%.1f", totalScore))
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("/ 60.0")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
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

    // MARK: - Element Prompt Card

    private func elementPromptCard(element: GymnasticsElement) -> some View {
        ZStack {
            // Canvas arena background
            GymnasticsArenaCanvas(
                elementIndex: currentElementIndex,
                gradeColor: gradeFlashColor,
                showFlash: showGradeFlash
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))

            // Dark overlay for legibility
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.38))

            // UI content
            VStack(spacing: 16) {
                // Timer ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 5)
                        .frame(width: 78, height: 78)
                    Circle()
                        .trim(from: 0, to: CGFloat(timeLeft / 2.0))
                        .stroke(timeLeft > 1.0 ? accentColor : .red,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 78, height: 78)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: timeLeft)
                    Text(String(format: "%.1f", timeLeft))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(timeLeft > 1.0 ? .white : .red)
                        .contentTransition(.numericText())
                }

                // Name + arrow
                VStack(spacing: 8) {
                    Text(element.prompt)
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(4)
                        .shadow(color: accentColor.opacity(0.5), radius: 14)

                    Image(systemName: element.direction.systemImage)
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: [accentColor, Theme.brandCyan],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: accentColor.opacity(0.5), radius: 20)
                        .symbolEffect(.pulse, options: .speed(1.5))
                }

                Text("SWIPE \(element.direction.rawValue) NOW")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .tracking(3)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 30)
        }
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(accentColor.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    // MARK: - Judge Panel

    private var judgePanelRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                singleJudgeChip(index: i)
            }
        }
        .padding(.bottom, 12)
    }

    private func singleJudgeChip(index: Int) -> some View {
        let scores = [currentJudgeScores.0, currentJudgeScores.1, currentJudgeScores.2]
        let s = scores[index]
        return VStack(spacing: 3) {
            Text("JUDGE \(index + 1)")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
            Text(String(format: "%.1f", s))
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(s >= 8 ? .yellow : (s >= 5 ? accentColor : Color.white.opacity(0.5)))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        )
        .scaleEffect(judgeScoresVisible[index] ? 1.0 : 0.4)
        .opacity(judgeScoresVisible[index] ? 1.0 : 0.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.6).delay(Double(index) * 0.14), value: judgeScoresVisible[index])
    }

    // MARK: - Swipe Zone

    private var swipeZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))
                .frame(height: 96)
            VStack(spacing: 5) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(accentColor.opacity(0.45))
                Text("SWIPE HERE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { val in
                    if !didSwipeThisElement {
                        didSwipeThisElement = true
                        swipeStartTime = .now
                    }
                }
                .onEnded { val in
                    guard phase == .active else { return }
                    handleSwipe(translation: val.translation)
                }
        )
    }

    // MARK: - Grade Flash

    private var gradeFlashOverlay: some View {
        Group {
            if showGradeFlash {
                Text(gradeFlashText)
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(gradeFlashColor)
                    .shadow(color: gradeFlashColor.opacity(0.6), radius: 20)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: showGradeFlash)
    }

    // MARK: - Feedback Body

    private var feedbackBody: some View {
        VStack(spacing: 0) {
            topHUD
                .padding(.horizontal, 20)
                .padding(.top, 8)
            Spacer()
            if let last = elementResults.last {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(last.grade.color.opacity(0.12))
                            .frame(width: 110, height: 110)
                        VStack(spacing: 3) {
                            Text(last.grade.rawValue)
                                .font(.system(size: 19, weight: .black, design: .monospaced))
                                .foregroundStyle(last.grade.color)
                            Text(String(format: "+%.1f", last.finalPoints))
                                .font(.system(size: 34, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }

                    Text(last.element.name.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(3)

                    if last.deduction > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                            Text(last.grade == .miss ? "FALL  −1.0 deduction" : "WOBBLE  −0.5 deduction")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                        )
                    }

                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in singleJudgeChip(index: i) }
                    }
                    .padding(.horizontal, 20)
                }
            }
            Spacer()
        }
    }

    // MARK: - Judging Body

    private var judgingBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("FINAL SCORES")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(3)
                    .padding(.top, 20)

                Image(systemName: "figure.gymnastics")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [accentColor, Theme.brandCyan], startPoint: .top, endPoint: .bottom)
                    )
                    .symbolEffect(.pulse)

                // Breakdown bars
                VStack(spacing: 14) {
                    barRow(label: "DIFFICULTY", value: difficultyMeter * 10, maxVal: 10, barColor: accentColor)
                    barRow(label: "EXECUTION",  value: executionBar * 10,   maxVal: 10, barColor: Theme.brandCyan)
                    barRow(label: "ARTISTIC",   value: artisticImpression * 10, maxVal: 10, barColor: .yellow)

                    Divider().background(Theme.cardBorder).padding(.vertical, 4)

                    HStack {
                        Text("YOUR TOTAL")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(2)
                        Spacer()
                        Text(String(format: "%.1f", totalScore))
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 4)

                    HStack {
                        Text("AI SCORE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(2)
                        Spacer()
                        Text(String(format: "%.0f.0", frozenAIScore))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 4)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1))
                )
                .padding(.horizontal, 24)

                // Element history
                VStack(alignment: .leading, spacing: 8) {
                    Text("ELEMENT BREAKDOWN")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                        .padding(.horizontal, 4)
                    ForEach(elementResults.indices, id: \.self) { i in
                        let r = elementResults[i]
                        HStack {
                            Text(r.element.name.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text(r.grade.rawValue)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(r.grade.color)
                            Text(String(format: "+%.1f", r.finalPoints))
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.cardBackground)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func barRow(label: String, value: Double, maxVal: Double, barColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(1)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(min(value / maxVal, 1.0)), height: 6)
                        .animation(.easeOut(duration: 0.7), value: value)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Logic

    private func startElement() {
        guard currentElementIndex < kRoutineElements.count else { finishRoutine(); return }
        timeLeft = 2.0
        showJudgePanel = false
        judgeScoresVisible = [false, false, false]
        didSwipeThisElement = false
        phase = .active
        runElementTimer()
    }

    private func runElementTimer() {
        elementTimer?.cancel()
        elementTimer = Task {
            let tickMs = 100
            let totalTicks = 20
            for tick in 0..<totalTicks {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(tickMs))
                await MainActor.run {
                    timeLeft = max(0, 2.0 - Double(tick + 1) * 0.1)
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if phase == .active {
                    commitResult(grade: .miss)
                }
            }
        }
    }

    private func handleSwipe(translation: CGSize) {
        guard phase == .active else { return }
        elementTimer?.cancel()
        let elapsed = Date.now.timeIntervalSince(swipeStartTime)
        let detected = resolveDirection(translation)
        guard currentElementIndex < kRoutineElements.count else { return }
        let expected = kRoutineElements[currentElementIndex].direction

        if detected == expected {
            let grade: TimingGrade = elapsed < 0.5 ? .perfect : (elapsed < 1.2 ? .good : .late)
            commitResult(grade: grade)
        } else {
            commitResult(grade: .miss)
        }
    }

    private func resolveDirection(_ t: CGSize) -> GymnasticsSwipeDir {
        let dx = t.width, dy = t.height
        let ax = abs(dx), ay = abs(dy)
        if ax > ay * 1.8 { return dx > 0 ? .right : .left }
        if ay > ax * 1.8 { return dy < 0 ? .up : .down }
        if dx > 0 { return dy < 0 ? .upRight : .upRight }
        return .upLeft
    }

    private func commitResult(grade: TimingGrade) {
        guard currentElementIndex < kRoutineElements.count else { return }
        let element = kRoutineElements[currentElementIndex]
        let rawPts = grade.points
        let deduction: Double = grade == .miss ? 1.0 : (grade == .late ? 0.5 : 0.0)
        let finalPts = max(0, Double(rawPts) - deduction)

        // Judge score generation
        let spread = Double(rawPts)
        let j1 = max(0, min(10, spread * 0.9  - deduction + Double.random(in: -0.5...0.5)))
        let j2 = max(0, min(10, spread * 0.95 - deduction + Double.random(in: -0.4...0.4)))
        let j3 = max(0, min(10, spread * 0.85 - deduction + Double.random(in: -0.6...0.6)))

        let result = GymElementResult(
            element: element,
            grade: grade,
            rawPoints: rawPts,
            deduction: deduction,
            finalPoints: finalPts,
            judge1: j1, judge2: j2, judge3: j3
        )
        elementResults.append(result)

        currentJudgeScores = (j1, j2, j3)

        // Grade flash
        gradeFlashText = grade.rawValue
        gradeFlashColor = grade.color
        withAnimation(.spring(response: 0.2)) { showGradeFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            await MainActor.run { withAnimation { showGradeFlash = false } }
        }

        // Show judge chips
        withAnimation(.spring(response: 0.3)) { showJudgePanel = true }
        for i in 0..<3 {
            Task {
                try? await Task.sleep(for: .milliseconds(180 + 140 * i))
                await MainActor.run { withAnimation { judgeScoresVisible[i] = true } }
            }
        }

        phase = .elementFeedback

        Task {
            try? await Task.sleep(for: .seconds(1.9))
            await MainActor.run {
                currentElementIndex += 1
                if currentElementIndex < totalElements { startElement() } else { finishRoutine() }
            }
        }
    }

    private func finishRoutine() {
        let totalPossible = Double(totalElements * 10)
        executionBar = min(1.0, max(0, totalScore / totalPossible))
        artisticImpression = min(1.0, (totalScore / totalPossible) * 0.85 + Double.random(in: 0.05...0.15))
        phase = .judging

        if !rewardApplied {
            rewardApplied = true
            let shards = playerWins ? 50 : (isDraw ? 25 : 15)
            viewModel.profile.evolutionShards += shards
        }

        Task {
            try? await Task.sleep(for: .seconds(3.2))
            await MainActor.run { phase = .result }
        }
    }
}
