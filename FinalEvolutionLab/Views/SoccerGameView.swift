import SwiftUI

// MARK: - Enums / Data

private enum SoccerPhase { case ready, shooting, result }

private struct SoccerRoundResult {
    let playerScored: Bool
    let aiScored: Bool
    let aimValue: Double
    let power: Double
    let goalieDirection: Int
}

// MARK: - Stadium Goal Canvas

private struct SoccerStadiumCanvas: View {
    let aimValue: Double
    let power: Double
    let shotFired: Bool
    let ballProgress: Double
    let goalieDir: Int
    let goalieDived: Bool
    let playerScored: Bool
    let lastScoreTime: Double
    let crowdExcitement: Double

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = SoccerFieldDrawer(
                    size: size, t: t,
                    aimValue: aimValue, power: power,
                    shotFired: shotFired, ballProgress: ballProgress,
                    goalieDir: goalieDir, goalieDived: goalieDived,
                    playerScored: playerScored,
                    lastScoreTime: lastScoreTime,
                    crowdExcitement: crowdExcitement
                )
                d.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Soccer Field Drawer

private struct SoccerFieldDrawer {
    let size: CGSize
    let t: Double
    let aimValue: Double
    let power: Double
    let shotFired: Bool
    let ballProgress: Double
    let goalieDir: Int
    let goalieDived: Bool
    let playerScored: Bool
    let lastScoreTime: Double
    let crowdExcitement: Double

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var goalLeft: CGFloat  { W * 0.12 }
    var goalRight: CGFloat { W * 0.88 }
    var goalWidth: CGFloat { goalRight - goalLeft }
    var goalTop: CGFloat   { H * 0.20 }
    var goalBot: CGFloat   { H * 0.68 }
    var goalMidY: CGFloat  { (goalTop + goalBot) * 0.5 }
    var penaltySpotY: CGFloat { H * 0.90 }
    var penaltySpotX: CGFloat { W * 0.5 }

    func ballTarget() -> CGPoint {
        let tx = goalLeft + CGFloat((aimValue * 0.5 + 0.5)) * goalWidth
        let ty = goalBot - CGFloat(power / 100.0) * (goalBot - goalTop - 24) - 12
        return CGPoint(x: tx, y: ty)
    }

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawStands(ctx: &ctx)
        drawPitch(ctx: &ctx)
        drawNet(ctx: &ctx)
        drawGoalPosts(ctx: &ctx)
        drawGoalie(ctx: &ctx)
        if !shotFired {
            drawAimIndicator(ctx: &ctx)
        }
        drawBall(ctx: &ctx)
        if playerScored && lastScoreTime > 0 && t - lastScoreTime < 1.5 {
            drawNetRipple(ctx: &ctx)
            drawGoalFlash(ctx: &ctx)
        }
    }

    // MARK: Sky

    private func drawSky(ctx: inout GraphicsContext) {
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H * 0.55)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.22), Color(red: 0.06, green: 0.10, blue: 0.28)]),
                startPoint: CGPoint(x: W * 0.5, y: 0),
                endPoint: CGPoint(x: W * 0.5, y: H * 0.55)
            )
        )
        // Stars
        for i in 0..<14 {
            let sx = W * CGFloat((i * 113 + 37) % 97) / 97.0
            let sy = H * 0.01 + H * 0.14 * CGFloat((i * 71 + 23) % 100) / 100.0
            let tw = 0.3 + 0.3 * sin(t * 1.5 + Double(i) * 0.9)
            var gc = ctx; gc.opacity = tw
            gc.fill(Path(ellipseIn: CGRect(x: sx - 1, y: sy - 1, width: 2, height: 2)), with: .color(.white))
        }
        // Light blooms
        for lx in [W * 0.04, W * 0.96] {
            var gc = ctx; gc.addFilter(.blur(radius: 20)); gc.opacity = 0.30
            gc.fill(Path(ellipseIn: CGRect(x: lx - 40, y: -12, width: 80, height: 50)), with: .color(.white))
        }
    }

    // MARK: Stands

    private func drawStands(ctx: inout GraphicsContext) {
        let standTop: CGFloat = H * 0.02
        let standBot: CGFloat = goalTop - 2
        let jerseys: [Color] = [
            Color(red: 0.12, green: 0.30, blue: 0.72), Color(red: 0.72, green: 0.10, blue: 0.12),
            Color(red: 0.90, green: 0.80, blue: 0.15), Color(red: 0.80, green: 0.36, blue: 0.04),
            Color(red: 0.15, green: 0.60, blue: 0.20), Color(white: 0.85)
        ]
        let tiers = 4
        for tier in 0..<tiers {
            let ty = standTop + CGFloat(tier) * (standBot - standTop) / CGFloat(tiers)
            let h = (standBot - standTop) / CGFloat(tiers) - 1
            ctx.fill(Path(CGRect(x: 0, y: ty, width: W, height: h)),
                     with: .color(Color(white: 0.07 + 0.012 * Double(tier))))
        }
        let cols = 22
        for row in 0..<4 {
            let ry = standTop + CGFloat(row) * (standBot - standTop) / 4 + 1
            let excited = crowdExcitement > 0.5
            for col in 0..<cols {
                let cx = W * 0.01 + CGFloat(col) * (W * 0.98) / CGFloat(cols - 1)
                let jc = jerseys[(col * 7 + row * 11) % jerseys.count]
                let skin = Color(red: 0.80 + 0.07 * CGFloat((col + row) % 3),
                                 green: 0.60 + 0.07 * CGFloat(col % 3), blue: 0.48)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: ry, width: 6, height: 6)), with: .color(skin))
                ctx.fill(Path(CGRect(x: cx - 3, y: ry + 6, width: 6, height: 5)), with: .color(jc.opacity(0.85)))
                if excited {
                    let wave = CGFloat(sin(t * 4.0 + Double(col) * 0.5)) * 2
                    var arms = Path()
                    arms.move(to: CGPoint(x: cx - 3, y: ry + 8))
                    arms.addLine(to: CGPoint(x: cx - 8, y: ry + 2 + wave))
                    arms.move(to: CGPoint(x: cx + 3, y: ry + 8))
                    arms.addLine(to: CGPoint(x: cx + 8, y: ry + 2 + wave))
                    ctx.stroke(arms, with: .color(jc.opacity(0.65)), lineWidth: 1.2)
                }
            }
        }
    }

    // MARK: Pitch

    private func drawPitch(ctx: inout GraphicsContext) {
        // Ground from goal line to viewer
        ctx.fill(
            Path(CGRect(x: 0, y: goalBot, width: W, height: H - goalBot)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.08, green: 0.30, blue: 0.08), Color(red: 0.04, green: 0.18, blue: 0.04)]),
                startPoint: CGPoint(x: W * 0.5, y: goalBot),
                endPoint: CGPoint(x: W * 0.5, y: H)
            )
        )
        // Grass stripes
        for s in 0..<5 {
            if s % 2 == 0 {
                let sx = CGFloat(s) * W / 5
                ctx.fill(Path(CGRect(x: sx, y: goalBot, width: W / 5, height: H - goalBot)),
                         with: .color(Color(white: 1).opacity(0.018)))
            }
        }
        // Penalty area box
        let boxW = W * 0.55; let boxLeft = (W - boxW) / 2
        var boxPath = Path()
        boxPath.move(to: CGPoint(x: boxLeft, y: goalBot))
        boxPath.addLine(to: CGPoint(x: boxLeft, y: H * 0.80))
        boxPath.addLine(to: CGPoint(x: boxLeft + boxW, y: H * 0.80))
        boxPath.addLine(to: CGPoint(x: boxLeft + boxW, y: goalBot))
        ctx.stroke(boxPath, with: .color(.white.opacity(0.30)), lineWidth: 1.5)
        // Penalty arc
        var arc = Path()
        arc.addArc(center: CGPoint(x: W * 0.5, y: goalBot),
                   radius: W * 0.16, startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
        ctx.stroke(arc, with: .color(.white.opacity(0.20)), lineWidth: 1)
        // Penalty spot
        ctx.fill(Path(ellipseIn: CGRect(x: penaltySpotX - 4, y: penaltySpotY - 4, width: 8, height: 8)),
                 with: .color(.white.opacity(0.70)))
        // Goal line
        ctx.fill(Path(CGRect(x: goalLeft - 4, y: goalBot - 2, width: goalWidth + 8, height: 3)),
                 with: .color(.white.opacity(0.6)))
    }

    // MARK: Net

    private func drawNet(ctx: inout GraphicsContext) {
        let netColor = Color.white.opacity(0.18)
        let cols = 10; let rows = 6
        // Vertical net strings
        for i in 0...cols {
            let ex = goalLeft + CGFloat(i) * goalWidth / CGFloat(cols)
            var line = Path()
            line.move(to: CGPoint(x: ex, y: goalTop))
            line.addLine(to: CGPoint(x: ex, y: goalBot))
            ctx.stroke(line, with: .color(netColor), lineWidth: 1)
        }
        // Horizontal net strings
        for i in 0...rows {
            let ey = goalTop + CGFloat(i) * (goalBot - goalTop) / CGFloat(rows)
            var line = Path()
            line.move(to: CGPoint(x: goalLeft, y: ey))
            line.addLine(to: CGPoint(x: goalRight, y: ey))
            ctx.stroke(line, with: .color(netColor), lineWidth: 1)
        }
        // Back net fill
        ctx.fill(Path(CGRect(x: goalLeft, y: goalTop, width: goalWidth, height: goalBot - goalTop)),
                 with: .color(Color(white: 0.04)))
    }

    // MARK: Goal Posts

    private func drawGoalPosts(ctx: inout GraphicsContext) {
        let postColor = Color.white.opacity(0.95)
        // Left post
        var leftPost = Path()
        leftPost.move(to: CGPoint(x: goalLeft, y: goalBot))
        leftPost.addLine(to: CGPoint(x: goalLeft, y: goalTop))
        ctx.stroke(leftPost, with: .color(postColor), lineWidth: 5)
        // Right post
        var rightPost = Path()
        rightPost.move(to: CGPoint(x: goalRight, y: goalBot))
        rightPost.addLine(to: CGPoint(x: goalRight, y: goalTop))
        ctx.stroke(rightPost, with: .color(postColor), lineWidth: 5)
        // Crossbar
        var crossbar = Path()
        crossbar.move(to: CGPoint(x: goalLeft, y: goalTop))
        crossbar.addLine(to: CGPoint(x: goalRight, y: goalTop))
        ctx.stroke(crossbar, with: .color(postColor), lineWidth: 5)
        // Post glow
        var glow = ctx; glow.addFilter(.blur(radius: 5)); glow.opacity = 0.25
        glow.stroke(crossbar, with: .color(.white), lineWidth: 10)
    }

    // MARK: Goalie

    private func drawGoalie(ctx: inout GraphicsContext) {
        let gkColor = Color(red: 0.20, green: 0.40, blue: 0.85)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 9

        let baseX = W * 0.5 + (goalieDived ? CGFloat(goalieDir) * goalWidth * 0.38 : 0)
        let baseY = goalMidY + 8

        if goalieDived && goalieDir != 0 {
            // Diving: body horizontal, arms extended
            let sign = CGFloat(goalieDir)
            ctx.fill(Path(ellipseIn: CGRect(x: baseX - r, y: baseY - r, width: r*2, height: r*2)), with: .color(skin))
            // Horizontal body
            var body = Path()
            body.move(to: CGPoint(x: baseX, y: baseY))
            body.addLine(to: CGPoint(x: baseX + sign * 28, y: baseY - 8))
            ctx.stroke(body, with: .color(gkColor), lineWidth: 5)
            // Extended arms
            var arms = Path()
            arms.move(to: CGPoint(x: baseX + sign * 10, y: baseY - 8))
            arms.addLine(to: CGPoint(x: baseX + sign * 34, y: baseY - 20))
            arms.move(to: CGPoint(x: baseX + sign * 10, y: baseY - 8))
            arms.addLine(to: CGPoint(x: baseX + sign * 20, y: baseY + 6))
            ctx.stroke(arms, with: .color(gkColor), lineWidth: 3.5)
            // Legs trailing
            var legs = Path()
            legs.move(to: CGPoint(x: baseX, y: baseY))
            legs.addLine(to: CGPoint(x: baseX - sign * 14, y: baseY + 16))
            legs.move(to: CGPoint(x: baseX, y: baseY))
            legs.addLine(to: CGPoint(x: baseX - sign * 6, y: baseY + 20))
            ctx.stroke(legs, with: .color(gkColor), lineWidth: 3)
        } else {
            // Standing ready: arms spread wide
            let bob = CGFloat(sin(t * 2.0)) * 1.5
            ctx.fill(Path(ellipseIn: CGRect(x: baseX - r, y: baseY - 50 - r + bob, width: r*2, height: r*2)), with: .color(skin))
            var body = Path()
            body.move(to: CGPoint(x: baseX, y: baseY - 50 + bob))
            body.addLine(to: CGPoint(x: baseX, y: baseY - 20))
            ctx.stroke(body, with: .color(gkColor), lineWidth: 4)
            // Wide arms (ready position)
            var arms = Path()
            arms.move(to: CGPoint(x: baseX - 28, y: baseY - 40 + bob))
            arms.addLine(to: CGPoint(x: baseX + 28, y: baseY - 40 + bob))
            ctx.stroke(arms, with: .color(gkColor), lineWidth: 3.5)
            // Gloves (circles at arm ends)
            ctx.fill(Path(ellipseIn: CGRect(x: baseX - 33, y: baseY - 44 + bob, width: 8, height: 8)),
                     with: .color(Color(red: 0.85, green: 0.55, blue: 0.10)))
            ctx.fill(Path(ellipseIn: CGRect(x: baseX + 25, y: baseY - 44 + bob, width: 8, height: 8)),
                     with: .color(Color(red: 0.85, green: 0.55, blue: 0.10)))
            // Legs
            var legs = Path()
            legs.move(to: CGPoint(x: baseX, y: baseY - 20))
            legs.addLine(to: CGPoint(x: baseX - 16, y: baseY))
            legs.move(to: CGPoint(x: baseX, y: baseY - 20))
            legs.addLine(to: CGPoint(x: baseX + 16, y: baseY))
            ctx.stroke(legs, with: .color(gkColor), lineWidth: 3)
            // Jersey number
            let numTxt = ctx.resolve(Text("1")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.85)))
            ctx.draw(numTxt, at: CGPoint(x: baseX, y: baseY - 34 + bob))
        }

        // Ground shadow
        ctx.fill(Path(ellipseIn: CGRect(x: baseX - 20, y: goalBot - 4, width: 40, height: 6)),
                 with: .color(.black.opacity(0.30)))
    }

    // MARK: Aim Indicator

    private func drawAimIndicator(ctx: inout GraphicsContext) {
        let tx = goalLeft + CGFloat(aimValue * 0.5 + 0.5) * goalWidth
        let ty = goalBot - CGFloat(power / 100.0) * (goalBot - goalTop - 24) - 12
        let pulse = 0.55 + 0.30 * CGFloat(sin(t * 5.0))

        // Target crosshair in goal
        var hLine = Path()
        hLine.move(to: CGPoint(x: tx - 12, y: ty))
        hLine.addLine(to: CGPoint(x: tx + 12, y: ty))
        var vLine = Path()
        vLine.move(to: CGPoint(x: tx, y: ty - 12))
        vLine.addLine(to: CGPoint(x: tx, y: ty + 12))
        var ac = ctx; ac.opacity = Double(pulse * 0.85)
        ac.stroke(hLine, with: .color(.green), lineWidth: 1.5)
        ac.stroke(vLine, with: .color(.green), lineWidth: 1.5)

        // Aim ring
        var ring = Path()
        ring.addEllipse(in: CGRect(x: tx - 10, y: ty - 10, width: 20, height: 20))
        var rc = ctx; rc.opacity = Double(pulse * 0.5)
        rc.stroke(ring, with: .color(.green), lineWidth: 1.5)

        // Trajectory line from penalty spot to aim point
        var traj = Path()
        traj.move(to: CGPoint(x: penaltySpotX, y: penaltySpotY))
        traj.addLine(to: CGPoint(x: tx, y: ty))
        ctx.stroke(traj, with: .color(.white.opacity(0.08)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
    }

    // MARK: Ball

    private func drawBall(ctx: inout GraphicsContext) {
        if ballProgress >= 0 && shotFired {
            // Animated shot
            let ep = CGFloat(ballProgress)
            let target = ballTarget()
            let bx = penaltySpotX + (target.x - penaltySpotX) * ep
            let by = penaltySpotY + (target.y - penaltySpotY) * ep - H * 0.08 * 4 * ep * (1 - ep)
            // Ball shrinks as it travels toward goal (perspective)
            let ballR = 14 - ep * 8

            // Trail
            for g in 1...3 {
                let pep = max(0, ep - CGFloat(g) * 0.08)
                let gx = penaltySpotX + (target.x - penaltySpotX) * pep
                let gy = penaltySpotY + (target.y - penaltySpotY) * pep - H * 0.08 * 4 * pep * (1 - pep)
                var gc = ctx; gc.opacity = Double(0.14 - CGFloat(g) * 0.03)
                gc.fill(Path(ellipseIn: CGRect(x: gx - ballR * 0.7, y: gy - ballR * 0.7, width: ballR * 1.4, height: ballR * 1.4)),
                        with: .color(.white))
            }
            // Glow
            var glow = ctx; glow.addFilter(.blur(radius: 8)); glow.opacity = 0.35
            glow.fill(Path(ellipseIn: CGRect(x: bx - 16, y: by - 16, width: 32, height: 32)), with: .color(.white))
            // Ball
            drawSoccerBall(ctx: &ctx, x: bx, y: by, r: ballR, spin: ep * 5)
        } else if !shotFired {
            // Stationary ball on penalty spot
            drawSoccerBall(ctx: &ctx, x: penaltySpotX, y: penaltySpotY - 14, r: 14, spin: 0)
        }
    }

    private func drawSoccerBall(ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, spin: CGFloat) {
        // White ball base
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(Gradient(colors: [.white, Color(white: 0.85)]),
                                  center: CGPoint(x: x - r * 0.3, y: y - r * 0.3),
                                  startRadius: 0, endRadius: r * 1.4)
        )
        // Pentagon patches (simplified hexagonal pattern)
        for i in 0..<5 {
            let angle = Double(i) / 5.0 * .pi * 2 + Double(spin)
            let px = x + CGFloat(cos(angle)) * r * 0.55
            let py = y + CGFloat(sin(angle)) * r * 0.55
            let pr = r * 0.28
            ctx.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                     with: .color(.black.opacity(0.75)))
        }
        // Center patch
        ctx.fill(Path(ellipseIn: CGRect(x: x - r * 0.15, y: y - r * 0.15, width: r * 0.30, height: r * 0.30)),
                 with: .color(.black.opacity(0.7)))
        // Highlight
        ctx.fill(Path(ellipseIn: CGRect(x: x - r * 0.45, y: y - r * 0.55, width: r * 0.35, height: r * 0.25)),
                 with: .color(.white.opacity(0.55)))
    }

    // MARK: Net Ripple (on goal)

    private func drawNetRipple(ctx: inout GraphicsContext) {
        let age = t - lastScoreTime
        let frac = age / 1.5
        let alpha = max(0, 1.0 - frac * 1.2)
        guard alpha > 0 else { return }

        let target = ballTarget()
        let rippleR = CGFloat(frac) * 80
        var ring = Path()
        ring.addEllipse(in: CGRect(x: target.x - rippleR, y: target.y - rippleR * 0.6,
                                    width: rippleR * 2, height: rippleR * 1.2))
        var rc = ctx; rc.opacity = alpha * 0.55
        rc.stroke(ring, with: .color(.white), lineWidth: 2)

        // 8 net distortion lines radiating outward
        for i in 0..<8 {
            let angle = Double(i) / 8.0 * .pi * 2
            let len = CGFloat(frac) * 30
            var spark = Path()
            spark.move(to: CGPoint(x: target.x + CGFloat(cos(angle)) * rippleR * 0.4,
                                   y: target.y + CGFloat(sin(angle)) * rippleR * 0.3))
            spark.addLine(to: CGPoint(x: target.x + CGFloat(cos(angle)) * (rippleR * 0.4 + len),
                                      y: target.y + CGFloat(sin(angle)) * (rippleR * 0.3 + len * 0.6)))
            var sc = ctx; sc.opacity = alpha * 0.5
            sc.stroke(spark, with: .color(.white), lineWidth: 1.5)
        }
    }

    private func drawGoalFlash(ctx: inout GraphicsContext) {
        let age = t - lastScoreTime
        let frac = age / 0.35
        let alpha = max(0, 1.0 - frac * 1.5)
        guard alpha > 0 else { return }

        var flash = ctx; flash.addFilter(.blur(radius: 25)); flash.opacity = alpha * 0.6
        flash.fill(Path(CGRect(x: goalLeft, y: goalTop, width: goalWidth, height: goalBot - goalTop)),
                   with: .color(.white))
    }
}

// MARK: - Main View

struct SoccerGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: SoccerPhase = .ready
    @State private var currentRound: Int = 1
    @State private var playerGoals: Int = 0
    @State private var aiGoals: Int = 0
    @State private var roundResults: [SoccerRoundResult] = []
    @State private var isSuddenDeath: Bool = false

    @State private var aimValue: Double = 0.0
    @State private var isDragging: Bool = false
    @State private var isHoldingShoot: Bool = false
    @State private var power: Double = 0.0
    @State private var powerDirection: Double = 1.0
    @State private var powerTimer: Task<Void, Never>? = nil

    @State private var showRoundFeedback: Bool = false
    @State private var roundFeedbackText: String = ""
    @State private var roundFeedbackColor: Color = .white
    @State private var lastGoalieDir: Int = 0
    @State private var shotFired: Bool = false

    // Canvas state
    @State private var ballProgress: Double = -1.0
    @State private var goalieDived: Bool = false
    @State private var playerScored: Bool = false
    @State private var lastScoreTime: Double = 0
    @State private var crowdExcitement: Double = 0.30

    private let XP_CAP: Int = 500
    private let WIN_SHARDS = 50
    private let DRAW_SHARDS = 25
    private let LOSS_SHARDS = 15
    private let accentColor = Color(red: 0.2, green: 0.7, blue: 0.3)

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.06, blue: 0.02).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Penalty Shootout",
                    subtitle: isSuddenDeath ? "SUDDEN DEATH" : "5-Round Shootout · Aim & Fire",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { phase = .shooting }
                )
                .background(Color(red: 0.02, green: 0.06, blue: 0.02).ignoresSafeArea())

            case .shooting:
                shootingBody

            case .result:
                let playerWon = playerGoals > aiGoals
                let isDraw = playerGoals == aiGoals
                ResultScreen(
                    winner: playerWon ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: playerGoals, p2Score: aiGoals,
                    title: "Penalty Shootout", accentColor: accentColor,
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
                Button { powerTimer?.cancel(); dismiss() } label: {
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

    // MARK: Shooting Body

    private var shootingBody: some View {
        VStack(spacing: 0) {
            scoreHeader.padding(.top, 8)

            // Stadium goal canvas — expanded for full immersion
            SoccerStadiumCanvas(
                aimValue: aimValue, power: power,
                shotFired: shotFired, ballProgress: ballProgress,
                goalieDir: lastGoalieDir, goalieDived: goalieDived,
                playerScored: playerScored,
                lastScoreTime: lastScoreTime,
                crowdExcitement: crowdExcitement
            )
            .frame(height: 260)
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Round feedback
            ZStack {
                if showRoundFeedback {
                    Text(roundFeedbackText)
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundStyle(roundFeedbackColor)
                        .shadow(color: roundFeedbackColor.opacity(0.6), radius: 16)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(height: 52)
            .padding(.top, 4)

            aimSliderSection.padding(.horizontal, 16).padding(.top, 4)

            Spacer().frame(height: 10)

            powerSection.padding(.horizontal, 16)

            Spacer().frame(height: 24)
        }
    }

    // MARK: Score Header

    private var scoreHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 2) {
                    Text("\(playerGoals)").font(.system(size: 40, weight: .black, design: .monospaced)).foregroundStyle(.white)
                    Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(1)
                }
                Text("—").font(.system(size: 28, weight: .bold, design: .monospaced)).foregroundStyle(.tertiary).padding(.horizontal, 16)
                VStack(spacing: 2) {
                    Text("\(aiGoals)").font(.system(size: 40, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    Text("OPP").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                }
                Spacer()
            }
            Text(isSuddenDeath ? "SUDDEN DEATH" : "ROUND \(currentRound) OF 5")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(isSuddenDeath ? .red : accentColor.opacity(0.8)).tracking(3)
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background(.ultraThinMaterial).clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: Aim Slider

    private var aimSliderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AIM").font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(3)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.12)).frame(height: 8)
                        .overlay(Capsule().stroke(Color(white: 0.20), lineWidth: 1))
                    let thumbX = geo.size.width / 2 + CGFloat(aimValue) * (geo.size.width / 2 - 14)
                    Circle()
                        .fill(LinearGradient(colors: [accentColor, Color(red: 0.2, green: 0.8, blue: 1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                        .shadow(color: accentColor.opacity(0.5), radius: 8)
                        .position(x: thumbX, y: geo.size.height / 2)
                        .animation(.interactiveSpring(response: 0.15), value: aimValue)
                }
                .gesture(DragGesture(minimumDistance: 0)
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
                Text("LEFT"); Spacer(); Text("CENTER"); Spacer(); Text("RIGHT")
            }
            .font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.08))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.16), lineWidth: 1)))
    }

    // MARK: Power Section

    private var powerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("POWER").font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(2)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.12)).overlay(Capsule().stroke(Color(white: 0.18), lineWidth: 1))
                        Capsule()
                            .fill(LinearGradient(colors: powerGradient, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * CGFloat(power / 100)))
                            .animation(.linear(duration: 0.05), value: power)
                    }
                }.frame(height: 12)
                Text("\(Int(power))%").font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white).frame(width: 40, alignment: .trailing)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(shotFired
                        ? AnyShapeStyle(Color.gray.opacity(0.2))
                        : AnyShapeStyle(LinearGradient(colors: [accentColor, Color(red: 0.2, green: 0.8, blue: 1)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .shadow(color: shotFired ? .clear : accentColor.opacity(0.4), radius: 12)
                Text(shotFired ? "•••" : "SHOOT")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(shotFired ? Color.white.opacity(0.3) : .black)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !shotFired, !isHoldingShoot else { return }
                    isHoldingShoot = true; startPowerOscillation()
                }
                .onEnded { _ in
                    guard !shotFired else { return }
                    isHoldingShoot = false; powerTimer?.cancel(); powerTimer = nil; fireShot()
                }
            )
            .disabled(shotFired)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.08))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.16), lineWidth: 1)))
    }

    private var powerGradient: [Color] {
        if power < 40 { return [Color(red: 0.2, green: 0.8, blue: 1), accentColor] }
        if power < 70 { return [accentColor, .yellow] }
        return [.yellow, .orange, .red]
    }

    // MARK: Logic

    private func startPowerOscillation() {
        powerTimer?.cancel(); power = 0; powerDirection = 1.0
        powerTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(28))
                if Task.isCancelled { break }
                await MainActor.run {
                    power += powerDirection * 2.5
                    if power >= 100 { power = 100; powerDirection = -1 }
                    if power <= 0   { power = 0;   powerDirection =  1 }
                }
            }
        }
    }

    private func fireShot() {
        let finalAim = aimValue
        let finalPower = power
        let prq = viewModel.effectiveMetrics.prqScore
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let accuracy = 0.45 + (prq / 100.0) * 0.30
        let goaliePrediction: Double = Double.random(in: 0...1) < accuracy
            ? finalAim : Double.random(in: -1...1)
        let gDir: Int = goaliePrediction < -0.2 ? -1 : (goaliePrediction > 0.2 ? 1 : 0)
        lastGoalieDir = gDir

        let coverageWidth = 0.48 - (prq / 100.0) * 0.10
        let goalieCovers = abs(finalAim - Double(gDir) * 0.6) < coverageWidth
        let scored = !goalieCovers && finalPower > 20

        let aiScoreChance = 0.55 + (prq / 100.0) * 0.10
        let aiScored = Double.random(in: 0...1) < aiScoreChance

        shotFired = true
        playerScored = false

        // Animate ball arc
        ballProgress = 0
        Task {
            for step in 0..<30 {
                try? await Task.sleep(nanoseconds: 14_000_000)
                await MainActor.run { ballProgress = Double(step + 1) / 30.0 }
            }
            await MainActor.run {
                ballProgress = -1
                goalieDived = true  // goalie dives at impact
                if scored {
                    playerScored = true
                    playerGoals += 1
                    lastScoreTime = Date().timeIntervalSinceReferenceDate
                    crowdExcitement = min(1.0, crowdExcitement + 0.35)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
                if aiScored { aiGoals += 1 }
                roundResults.append(SoccerRoundResult(
                    playerScored: scored, aiScored: aiScored,
                    aimValue: finalAim, power: finalPower, goalieDirection: gDir
                ))
                withAnimation(.spring(response: 0.2)) {
                    roundFeedbackText = scored ? "GOAL!" : "SAVED!"
                    roundFeedbackColor = scored ? accentColor : .red
                    showRoundFeedback = true
                }
            }

            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run {
                withAnimation { showRoundFeedback = false }
                advanceRound()
            }
        }
    }

    private func advanceRound() {
        if isSuddenDeath {
            if playerGoals != aiGoals { phase = .result }
            else { resetRoundState(); phase = .ready }
            return
        }
        if currentRound >= 5 {
            if playerGoals == aiGoals {
                isSuddenDeath = true; currentRound = 1; resetRoundState(); phase = .ready
            } else { phase = .result }
        } else {
            currentRound += 1; resetRoundState()
        }
    }

    private func resetRoundState() {
        aimValue = 0; power = 0; powerDirection = 1
        isHoldingShoot = false; shotFired = false
        ballProgress = -1; goalieDived = false; playerScored = false
        lastGoalieDir = 0; showRoundFeedback = false
    }

    private func grantShards(playerWon: Bool, isDraw: Bool) {
        let earned = playerWon ? WIN_SHARDS : (isDraw ? DRAW_SHARDS : LOSS_SHARDS)
        viewModel.profile.evolutionShards += min(earned, XP_CAP)
    }
}
