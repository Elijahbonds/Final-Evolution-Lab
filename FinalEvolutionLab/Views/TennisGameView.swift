import SwiftUI

// MARK: - Supporting Types

private enum TennisPoint: Int, CaseIterable {
    case zero = 0, fifteen = 15, thirty = 30, forty = 40
    var display: String {
        switch self { case .zero: "0"; case .fifteen: "15"; case .thirty: "30"; case .forty: "40" }
    }
    var next: TennisPoint? {
        switch self { case .zero: .fifteen; case .fifteen: .thirty; case .thirty: .forty; case .forty: nil }
    }
}

private enum TennisPhase { case ready, serving, rally, result }
private enum SwipeDir { case left, right, up, none }

private struct TennisBall {
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)  // normalized 0–1
    var fromOpponent: Bool = true
}

// MARK: - Court Canvas

private struct TennisCourtCanvas: View {
    let ballPosition: CGPoint
    let ballScale: CGFloat
    let swipeWindowOpen: Bool
    let isPlayerSide: Bool   // ball is on player's half
    let phase: TennisPhase
    let feedbackText: String
    let showFeedback: Bool
    let crowdLevel: Double

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                var d = TennisDrawer(
                    t: tl.date.timeIntervalSinceReferenceDate,
                    W: size.width, H: size.height,
                    ballPos: ballPosition, ballScale: ballScale,
                    swipeOpen: swipeWindowOpen,
                    playerSide: isPlayerSide,
                    phase: phase, crowd: crowdLevel
                )
                d.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Drawer

private struct TennisDrawer {
    let t: Double
    let W: CGFloat; let H: CGFloat
    let ballPos: CGPoint; let ballScale: CGFloat
    let swipeOpen: Bool
    let playerSide: Bool
    let phase: TennisPhase
    let crowd: Double

    // Court geometry
    var cL: CGFloat { W * 0.06 }   // left sideline
    var cR: CGFloat { W * 0.94 }   // right sideline
    var cT: CGFloat { H * 0.08 }   // opponent baseline (far)
    var cB: CGFloat { H * 0.92 }   // player baseline (near)
    var netY: CGFloat { (cT + cB) * 0.5 }
    var singL: CGFloat { W * 0.14 } // singles left
    var singR: CGFloat { W * 0.86 } // singles right
    var servT: CGFloat { cT + (cB - cT) * 0.30 } // opponent service line
    var servB: CGFloat { cT + (cB - cT) * 0.70 } // player service line

    var ballCX: CGFloat { ballPos.x * W }
    var ballCY: CGFloat { ballPos.y * H }

    mutating func render(ctx: inout GraphicsContext) {
        drawStadium(&ctx)
        drawCourt(&ctx)
        drawNet(&ctx)
        drawPlayers(&ctx)
        if swipeOpen { drawSwipeZone(&ctx) }
        drawBall(&ctx)
    }

    // ─── Stadium ──────────────────────────────────────────────────────────────

    private func drawStadium(_ ctx: inout GraphicsContext) {
        // Dark arena background
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .color(Color(red:0.04,green:0.04,blue:0.06)))

        // Top & bottom stands
        for (standY, standH): (CGFloat, CGFloat) in [(0, cT), (cB, H - cB)] {
            ctx.fill(Path(CGRect(x: 0, y: standY, width: W, height: standH)),
                     with: .color(Color(red:0.08,green:0.08,blue:0.12)))
            // Crowd rows
            let rows = 3
            let jerseys: [Color] = [
                Color(red:0.72,green:0.12,blue:0.12),
                Color(red:0.12,green:0.35,blue:0.72),
                Color(red:0.72,green:0.58,blue:0.12),
                Color(red:0.30,green:0.30,blue:0.30),
                Color(red:0.55,green:0.15,blue:0.55)
            ]
            for row in 0..<rows {
                let ry = standY + standH * CGFloat(row + 1) / CGFloat(rows + 1)
                let cols = 22
                for col in 0..<cols {
                    let jColor = jerseys[(col * 3 + row * 7) % jerseys.count]
                    let waveOff = CGFloat(sin(t * 1.2 + Double(col) * 0.6 + Double(row))) * 1.0
                    let hx = W * CGFloat(col + 1) / CGFloat(cols + 1)
                    let head = Path(ellipseIn: CGRect(x: hx-4, y: ry - 4 + waveOff, width: 8, height: 8))
                    ctx.fill(head, with: .color(jColor.opacity(0.7)))
                }
            }
        }

        // Left & right stands (narrow strips)
        for (sx, sw): (CGFloat, CGFloat) in [(0, cL), (cR, W - cR)] {
            ctx.fill(Path(CGRect(x: sx, y: cT, width: sw, height: cB - cT)),
                     with: .color(Color(red:0.08,green:0.08,blue:0.12)))
        }

        // Court lights — 4 corner blooms
        for (lx, ly): (CGFloat, CGFloat) in [(W*0.05, H*0.04), (W*0.95, H*0.04),
                                               (W*0.05, H*0.96), (W*0.95, H*0.96)] {
            var bloom = ctx
            bloom.addFilter(.blur(radius: 22))
            bloom.fill(Path(ellipseIn: CGRect(x: lx-10, y: ly-10, width: 20, height: 20)),
                       with: .color(Color(red:1.0,green:0.95,blue:0.75).opacity(0.60)))
            // Pole
            var pole = Path()
            let baseX = lx < W/2 ? cL : cR
            pole.move(to: CGPoint(x: lx, y: ly))
            pole.addLine(to: CGPoint(x: baseX, y: (lx < W/2 ? cT : cB)))
            ctx.stroke(pole, with: .color(Color(white:0.35).opacity(0.5)), lineWidth: 1.5)
        }
    }

    // ─── Court Surface ─────────────────────────────────────────────────────────

    private func drawCourt(_ ctx: inout GraphicsContext) {
        // Main court surface (hard court blue)
        let courtRect = CGRect(x: cL, y: cT, width: cR - cL, height: cB - cT)
        ctx.fill(Path(courtRect), with: .linearGradient(
            Gradient(colors: [Color(red:0.10,green:0.30,blue:0.58),
                               Color(red:0.08,green:0.25,blue:0.52)]),
            startPoint: CGPoint(x: W/2, y: cT), endPoint: CGPoint(x: W/2, y: cB)))

        // Subtle court texture lines (horizontal)
        let texLines = 20
        for i in 1..<texLines {
            let ty = cT + CGFloat(i) / CGFloat(texLines) * (cB - cT)
            var line = Path()
            line.move(to: CGPoint(x: cL, y: ty))
            line.addLine(to: CGPoint(x: cR, y: ty))
            ctx.stroke(line, with: .color(Color(white:1).opacity(0.03)), lineWidth: 0.5)
        }

        // Doubles alleys (slightly lighter tint)
        let alleyColor = Color(red:0.12,green:0.33,blue:0.62).opacity(0.45)
        ctx.fill(Path(CGRect(x: cL, y: cT, width: singL - cL, height: cB - cT)), with: .color(alleyColor))
        ctx.fill(Path(CGRect(x: singR, y: cT, width: cR - singR, height: cB - cT)), with: .color(alleyColor))

        // Court lines
        let lineColor = Color.white.opacity(0.90)
        let lw: CGFloat = 2.0

        // Baselines
        stroke(&ctx, from: CGPoint(x: cL, y: cT), to: CGPoint(x: cR, y: cT), color: lineColor, width: lw*1.5)
        stroke(&ctx, from: CGPoint(x: cL, y: cB), to: CGPoint(x: cR, y: cB), color: lineColor, width: lw*1.5)

        // Sidelines (doubles)
        stroke(&ctx, from: CGPoint(x: cL, y: cT), to: CGPoint(x: cL, y: cB), color: lineColor, width: lw)
        stroke(&ctx, from: CGPoint(x: cR, y: cT), to: CGPoint(x: cR, y: cB), color: lineColor, width: lw)

        // Singles sidelines
        stroke(&ctx, from: CGPoint(x: singL, y: cT), to: CGPoint(x: singL, y: cB), color: lineColor, width: lw)
        stroke(&ctx, from: CGPoint(x: singR, y: cT), to: CGPoint(x: singR, y: cB), color: lineColor, width: lw)

        // Service lines
        stroke(&ctx, from: CGPoint(x: singL, y: servT), to: CGPoint(x: singR, y: servT), color: lineColor, width: lw)
        stroke(&ctx, from: CGPoint(x: singL, y: servB), to: CGPoint(x: singR, y: servB), color: lineColor, width: lw)

        // Center service line
        stroke(&ctx, from: CGPoint(x: W/2, y: servT), to: CGPoint(x: W/2, y: servB), color: lineColor, width: lw)

        // Center marks on baselines
        for bly in [cT, cB] {
            stroke(&ctx, from: CGPoint(x: W/2 - 5, y: bly), to: CGPoint(x: W/2 + 5, y: bly), color: lineColor, width: lw)
        }
    }

    // ─── Net ───────────────────────────────────────────────────────────────────

    private func drawNet(_ ctx: inout GraphicsContext) {
        // Net shadow
        var shadow = ctx
        shadow.addFilter(.blur(radius: 5))
        shadow.fill(Path(CGRect(x: cL + 4, y: netY - 3, width: cR - cL - 4, height: 10)),
                    with: .color(.black.opacity(0.45)))

        // Net band top (white tape)
        ctx.fill(Path(CGRect(x: cL - 6, y: netY - 6, width: cR - cL + 12, height: 6)),
                 with: .color(Color(white: 0.95)))

        // Net mesh (horizontal and vertical lines)
        let meshH = CGFloat(18)
        let netLeft = cL - 6; let netRight = cR + 6
        for r in 0..<4 {
            let ry = netY + CGFloat(r + 1) * meshH / 4
            stroke(&ctx, from: CGPoint(x: netLeft, y: ry), to: CGPoint(x: netRight, y: ry),
                   color: Color(white:0.75).opacity(0.5), width: 0.8)
        }
        let meshCols = 28
        for c in 0...meshCols {
            let mx = netLeft + CGFloat(c) / CGFloat(meshCols) * (netRight - netLeft)
            stroke(&ctx, from: CGPoint(x: mx, y: netY), to: CGPoint(x: mx, y: netY + meshH),
                   color: Color(white:0.65).opacity(0.35), width: 0.5)
        }

        // Net posts
        for px in [cL - 6, cR + 6] {
            ctx.fill(Path(CGRect(x: px - 4, y: netY - 8, width: 8, height: 28)),
                     with: .color(Color(white:0.80)))
        }

        // Net center strap (slightly lower)
        ctx.fill(Path(CGRect(x: W/2 - 3, y: netY - 4, width: 6, height: 22)),
                 with: .color(Color(white:0.75)))
    }

    // ─── Players ───────────────────────────────────────────────────────────────

    private func drawPlayers(_ ctx: inout GraphicsContext) {
        // Player at bottom: tracks ball x, ready vs returning
        let playerX = lerp(ballCX, W * 0.5, 0.4)
        let playerY = cB + (H - cB) * 0.35
        let isBallClose = ballCY > netY  // ball on player side

        drawPlayer(&ctx, x: playerX, y: playerY,
                   color: Color(red:0.15,green:0.65,blue:0.20),
                   facingUp: true, swinging: isBallClose && swipeOpen,
                   label: "YOU")

        // Opponent at top: tracks ball x
        let oppX = lerp(ballCX, W * 0.5, 0.5)
        let oppY = cT * 0.45
        let isBallFar = ballCY <= netY

        drawPlayer(&ctx, x: oppX, y: oppY,
                   color: Color(red:0.80,green:0.15,blue:0.15),
                   facingUp: false, swinging: isBallFar,
                   label: "OPP")
    }

    private func drawPlayer(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat,
                             color: Color, facingUp: Bool, swinging: Bool, label: String) {
        let dir: CGFloat = facingUp ? -1 : 1   // arm/racket direction

        // Shadow
        var sc = ctx; sc.addFilter(.blur(radius: 4))
        sc.fill(Path(ellipseIn: CGRect(x: x-14, y: y-4, width: 28, height: 8)),
                with: .color(.black.opacity(0.35)))

        // Head
        ctx.fill(Path(ellipseIn: CGRect(x: x-6, y: y-6, width: 12, height: 12)),
                 with: .color(Color(red:0.93,green:0.80,blue:0.68)))

        // Body
        var body = Path()
        body.move(to: CGPoint(x: x, y: y + 4))
        body.addLine(to: CGPoint(x: x, y: y + 16))
        ctx.stroke(body, with: .color(color), lineWidth: 4)

        // Arms + racket
        let armY = y + 8
        let racketDir: CGFloat = swinging ? (Bool.random() ? 1 : -1) : 1
        let swingAngle = swinging ? CGFloat(sin(t * 14)) * 18 : 0

        var armPath = Path()
        if swinging {
            // Swing: arm extended with follow-through
            armPath.move(to: CGPoint(x: x - 8 * racketDir, y: armY + 2))
            armPath.addLine(to: CGPoint(x: x, y: armY - 2))
            armPath.addLine(to: CGPoint(x: x + 14 * racketDir, y: armY - 6 + swingAngle))
        } else {
            // Ready: arm slightly raised
            armPath.move(to: CGPoint(x: x - 9, y: armY + 4))
            armPath.addLine(to: CGPoint(x: x, y: armY))
            armPath.addLine(to: CGPoint(x: x + 9, y: armY + 4))
        }
        ctx.stroke(armPath, with: .color(Color(red:0.93,green:0.80,blue:0.68)), lineWidth: 2.2)

        // Racket
        let rGrip = CGPoint(x: x + 14 * racketDir, y: armY - 6 + swingAngle)
        let rHead = CGPoint(x: rGrip.x + 10 * racketDir, y: rGrip.y + dir * 10)
        var racket = Path()
        racket.move(to: rGrip); racket.addLine(to: rHead)
        ctx.stroke(racket, with: .color(Color(white:0.7)), lineWidth: 1.5)
        // Racket face (oval)
        ctx.stroke(Path(ellipseIn: CGRect(x: rHead.x - 7, y: rHead.y - 8, width: 14, height: 16)),
                   with: .color(Color(red:0.90,green:0.75,blue:0.20)), lineWidth: 1.5)

        // Legs
        var legs = Path()
        let legSpread: CGFloat = swinging ? 9 : 6
        legs.move(to: CGPoint(x: x - legSpread, y: y + 28))
        legs.addLine(to: CGPoint(x: x, y: y + 16))
        legs.addLine(to: CGPoint(x: x + legSpread, y: y + 28))
        ctx.stroke(legs, with: .color(Color(red:0.20,green:0.20,blue:0.55)), lineWidth: 2.5)
    }

    // ─── Swipe Zone ────────────────────────────────────────────────────────────

    private func drawSwipeZone(_ ctx: inout GraphicsContext) {
        let pulse = CGFloat(sin(t * 7)) * 3
        let zoneRect = CGRect(x: singL - pulse, y: servB - pulse,
                               width: (singR - singL) + pulse * 2,
                               height: (cB - servB) + pulse * 2)
        // Filled glow
        var gc = ctx; gc.addFilter(.blur(radius: 8))
        gc.fill(Path(roundedRect: zoneRect, cornerRadius: 6),
                with: .color(Color(red:0.3,green:0.85,blue:0.4).opacity(0.15)))
        // Border
        ctx.stroke(Path(roundedRect: zoneRect, cornerRadius: 6),
                   with: .color(Color(red:0.3,green:0.85,blue:0.4).opacity(0.75)), lineWidth: 2.0)

        // "RETURN ZONE" text
        ctx.draw(
            Text("◆ RETURN ZONE ◆")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red:0.3,green:0.85,blue:0.4).opacity(0.9)),
            at: CGPoint(x: W / 2, y: servB - 10), anchor: .center
        )
    }

    // ─── Ball ─────────────────────────────────────────────────────────────────

    private func drawBall(_ ctx: inout GraphicsContext) {
        let bx = ballCX; let by = ballCY
        // Height illusion: ball "height" based on distance from net
        let distFromNet = abs(by - netY) / (cB - netY)
        let airH = distFromNet * 0.4  // 0 at net, up to 0.4 at baseline
        let r: CGFloat = max(6, (7 + airH * 4)) * ballScale

        // Air shadow on court (only when ball is on court)
        if by > cT && by < cB {
            let shadowY = by + r * CGFloat(1 + airH * 2)
            let shadowR = r * CGFloat(0.5 + airH * 0.8)
            var sc = ctx; sc.addFilter(.blur(radius: shadowR * 0.7))
            sc.fill(Path(ellipseIn: CGRect(x: bx - shadowR, y: shadowY - shadowR * 0.4,
                                           width: shadowR * 2, height: shadowR * 0.8)),
                    with: .color(.black.opacity(0.45 - airH * 0.2)))
        }

        // Glow
        var glowCtx = ctx
        glowCtx.addFilter(.blur(radius: r * 1.2))
        glowCtx.fill(Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r*2, height: r*2)),
                     with: .color(Color(red:0.95,green:0.90,blue:0.20).opacity(0.65)))

        // Ball body
        ctx.fill(Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r*2, height: r*2)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red:0.95,green:0.90,blue:0.15),
                                      Color(red:0.72,green:0.68,blue:0.08)]),
                    center: CGPoint(x: bx - r*0.25, y: by - r*0.25),
                    startRadius: 0, endRadius: r * 1.1))

        // Seam
        var seam = Path()
        seam.addArc(center: CGPoint(x: bx, y: by), radius: r - 1.5,
                    startAngle: .degrees(-30), endAngle: .degrees(210), clockwise: false)
        ctx.stroke(seam, with: .color(Color(red:0.50,green:0.42,blue:0.05).opacity(0.6)), lineWidth: 1)
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    private func stroke(_ ctx: inout GraphicsContext, from: CGPoint, to: CGPoint,
                        color: Color, width: CGFloat) {
        var p = Path(); p.move(to: from); p.addLine(to: to)
        ctx.stroke(p, with: .color(color), lineWidth: width)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}

// MARK: - TennisGameView

struct TennisGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: TennisPhase = .ready
    @State private var timeLeft: Int = 120
    @State private var gameTimerTask: Task<Void, Never>? = nil

    @State private var playerGames: Int = 0
    @State private var opponentGames: Int = 0
    @State private var playerPoints: TennisPoint = .zero
    @State private var opponentPoints: TennisPoint = .zero
    @State private var playerSets: Int = 0
    @State private var opponentSets: Int = 0

    @State private var ball: TennisBall = TennisBall()
    @State private var rallyTask: Task<Void, Never>? = nil
    @State private var awaitingSwipe: Bool = false
    @State private var swipeWindowOpen: Bool = false
    @State private var swipeWindowTask: Task<Void, Never>? = nil
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var isServing: Bool = true
    @State private var serveReady: Bool = false
    @State private var serveAnimating: Bool = false
    @State private var ballScale: CGFloat = 1.0
    @State private var ballOpacity: Double = 1.0
    @State private var crowdLevel: Double = 0.30

    @State private var dragStart: CGPoint? = nil
    private let XP_CAP_PER_SESSION = 500
    @State private var sessionXP: Int = 0

    private let accentColor = Color(red: 0.85, green: 0.75, blue: 0.1)
    private let opponentName = "Kai Nexus"

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(colors: [Color(red:0.04,green:0.06,blue:0.02), Theme.deepBlack],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Rally Ace", subtitle: "2-Minute Tennis Match · Swipe to return",
                    countdown: 3, accentColor: accentColor,
                    onComplete: { startMatch() }
                )
            case .serving: servingView
            case .rally:   rallyView
            case .result:  resultView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { cancelAllTasks(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { cancelAllTasks() }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(spacing: 2) {
                    Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Text(playerPoints.display)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(.white).contentTransition(.numericText())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(clockString).font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(timeLeft <= 20 ? .red : accentColor)
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle().fill(i < playerSets ? accentColor : Color.white.opacity(0.12))
                                .frame(width: 7, height: 7)
                        }
                        Text("VS").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                        ForEach(0..<3) { i in
                            Circle().fill(i < opponentSets ? Color.red : Color.white.opacity(0.12))
                                .frame(width: 7, height: 7)
                        }
                    }
                    HStack(spacing: 8) {
                        Text("\(playerGames)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
                        Text("GAMES").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                        Text("\(opponentGames)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.red)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(opponentName.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Text(opponentPoints.display)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55)).contentTransition(.numericText())
                }
            }.padding(.horizontal, 24)
            Rectangle().fill(accentColor.opacity(0.25)).frame(height: 1).padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    // MARK: - Court View

    private var courtCanvas: some View {
        ZStack {
            TennisCourtCanvas(
                ballPosition: ball.position,
                ballScale: ballScale,
                swipeWindowOpen: swipeWindowOpen,
                isPlayerSide: ball.position.y > 0.5,
                phase: phase,
                feedbackText: feedbackText,
                showFeedback: showFeedback,
                crowdLevel: crowdLevel
            )
            .animation(.easeInOut(duration: 0.55), value: ball.position)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if showFeedback {
                Text(feedbackText)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(feedbackText == "ACE!" || feedbackText == "WINNER!" ? accentColor : .red)
                    .shadow(color: accentColor.opacity(0.6), radius: 12)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 280)
        .padding(.horizontal, 16)
    }

    // MARK: - Serving View

    private var servingView: some View {
        VStack(spacing: 0) {
            scoreHeader
            Spacer()
            courtCanvas
            Spacer()
            VStack(spacing: 16) {
                Text("SERVE").font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor).tracking(4)
                Text("Tap to toss, then serve").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                if serveReady && !serveAnimating {
                    actionButton(label: "SERVE", icon: "arrow.up.circle.fill") { launchServe() }
                } else if !serveReady {
                    actionButton(label: "TOSS", icon: "hand.tap.fill") { tossBall() }
                } else {
                    Text("Tossing…").font(.system(size: 14, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Rally View

    private var rallyView: some View {
        ZStack {
            VStack(spacing: 0) {
                scoreHeader
                Spacer()
                courtCanvas
                Spacer()
                VStack(spacing: 12) {
                    if swipeWindowOpen {
                        Text("SWIPE TO RETURN!")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor).tracking(2)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Watch the ball…").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 60)
                .animation(.easeInOut(duration: 0.2), value: swipeWindowOpen)
                .padding(.bottom, 20)
            }
            Color.clear.contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { v in if dragStart == nil { dragStart = v.startLocation } }
                        .onEnded { v in
                            defer { dragStart = nil }
                            guard swipeWindowOpen else { return }
                            handlePlayerSwipe(detectSwipe(from: v.startLocation, to: v.location))
                        }
                )
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        let playerWon = playerSets > opponentSets || (playerSets == opponentSets && playerGames > opponentGames)
        let isDraw    = playerSets == opponentSets && playerGames == opponentGames
        let shards    = isDraw ? 25 : (playerWon ? 50 : 15)
        return ResultScreen(
            winner: isDraw ? .draw : (playerWon ? .p1 : .p2),
            p1Score: playerGames, p2Score: opponentGames,
            title: "Rally Ace · Tennis", accentColor: accentColor,
            prqGain: playerWon ? 12 : (isDraw ? 6 : 2),
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "Rally",
            modeAttributeValue: playerGames > 0 ? Double(playerGames) / Double(max(1, playerGames + opponentGames)) : 0,
            onReturn: { viewModel.profile.evolutionShards += shards; dismiss() }
        )
    }

    // MARK: - Reusable button

    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.system(size: 18, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(accentColor).clipShape(.rect(cornerRadius: 14))
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private var clockString: String { String(format: "%d:%02d", timeLeft / 60, timeLeft % 60) }

    private func startMatch() {
        ball.position = CGPoint(x: 0.5, y: 0.8)
        isServing = true; serveReady = false; serveAnimating = false
        phase = .serving; startGameTimer()
    }

    private func startGameTimer() {
        gameTimerTask?.cancel()
        gameTimerTask = Task {
            while timeLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeLeft -= 1 }
            }
            await MainActor.run { endMatch() }
        }
    }

    private func tossBall() {
        serveAnimating = true
        withAnimation(.easeOut(duration: 0.4)) { ball.position = CGPoint(x: 0.5, y: 0.62); ballScale = 0.8 }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run { serveAnimating = false; serveReady = true; withAnimation(.spring(response: 0.2)) { ballScale = 1.2 } }
        }
    }

    private func launchServe() {
        serveReady = false; serveAnimating = true
        let dir: CGFloat = Bool.random() ? -0.2 : 0.2
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeIn(duration: 0.5)) { ball.position = CGPoint(x: 0.5 + dir, y: 0.18); ballScale = 0.75 }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { phase = .rally; beginRally(fromOpponent: false) }
        }
    }

    private func beginRally(fromOpponent: Bool) {
        rallyTask?.cancel(); awaitingSwipe = false; swipeWindowOpen = false
        rallyTask = Task {
            let targetX = CGFloat.random(in: 0.25...0.75)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) {
                    ball.position = fromOpponent ? CGPoint(x: targetX, y: 0.75) : CGPoint(x: targetX, y: 0.22)
                    ballScale = fromOpponent ? 1.0 : 0.7
                }
            }
            if fromOpponent {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await MainActor.run { withAnimation { swipeWindowOpen = true }; awaitingSwipe = true; openSwipeWindow() }
            } else {
                let delay = Double.random(in: 0.8...1.4)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await MainActor.run { opponentResponds() }
            }
        }
    }

    private func openSwipeWindow() {
        swipeWindowTask?.cancel()
        swipeWindowTask = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if awaitingSwipe { awaitingSwipe = false; swipeWindowOpen = false; flashFeedback("MISS!"); opponentWinsPoint() }
            }
        }
    }

    private func handlePlayerSwipe(_ dir: SwipeDir) {
        guard awaitingSwipe else { return }
        awaitingSwipe = false; swipeWindowOpen = false; swipeWindowTask?.cancel()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if dir != .none {
            flashFeedback(Bool.random() ? "WINNER!" : "GREAT SHOT!")
            crowdLevel = min(1.0, crowdLevel + 0.15)
            let shotX = dir == .left ? CGFloat.random(in: 0.15...0.4) : CGFloat.random(in: 0.6...0.85)
            withAnimation(.easeIn(duration: 0.45)) { ball.position = CGPoint(x: shotX, y: 0.15); ballScale = 0.7 }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run { beginRally(fromOpponent: false) }
            }
        } else {
            flashFeedback("MISS!"); opponentWinsPoint()
        }
    }

    private func opponentResponds() {
        let prq = viewModel.effectiveMetrics.prqScore
        let returnChance = 0.45 + (prq / 200.0)
        if Double.random(in: 0...1) < returnChance { beginRally(fromOpponent: true) }
        else { flashFeedback("ACE!"); playerWinsPoint() }
    }

    private func playerWinsPoint() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation {
            if playerPoints == .forty { playerWinsGame() }
            else { playerPoints = playerPoints.next ?? .zero }
        }
        scheduleNextRallyOrServe(playerServes: false)
    }

    private func opponentWinsPoint() {
        withAnimation {
            if opponentPoints == .forty { opponentWinsGame() }
            else { opponentPoints = opponentPoints.next ?? .zero }
        }
        scheduleNextRallyOrServe(playerServes: true)
    }

    private func playerWinsGame() {
        playerPoints = .zero; opponentPoints = .zero; playerGames += 1
        if playerGames >= 6 && playerGames - opponentGames >= 2 { playerWinsSet() }
    }

    private func opponentWinsGame() {
        playerPoints = .zero; opponentPoints = .zero; opponentGames += 1
        if opponentGames >= 6 && opponentGames - playerGames >= 2 { opponentWinsSet() }
    }

    private func playerWinsSet() {
        playerGames = 0; opponentGames = 0; playerSets += 1
        if playerSets >= 2 { endMatch() }
    }

    private func opponentWinsSet() {
        playerGames = 0; opponentGames = 0; opponentSets += 1
        if opponentSets >= 2 { endMatch() }
    }

    private func scheduleNextRallyOrServe(playerServes: Bool) {
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run {
                guard phase == .rally || phase == .serving else { return }
                isServing = true; serveReady = false; serveAnimating = false
                ball.position = playerServes ? CGPoint(x: 0.5, y: 0.82) : CGPoint(x: 0.5, y: 0.18)
                phase = .serving
            }
        }
    }

    private func endMatch() { cancelAllTasks(); withAnimation(.spring(response: 0.4)) { phase = .result } }

    private func detectSwipe(from start: CGPoint, to end: CGPoint) -> SwipeDir {
        let dx = end.x - start.x; let dy = end.y - start.y
        let threshold: CGFloat = 20
        if abs(dx) > abs(dy) && abs(dx) > threshold { return dx < 0 ? .left : .right }
        else if dy < -threshold { return .up }
        return .none
    }

    private func flashFeedback(_ text: String) {
        feedbackText = text
        withAnimation(.spring(response: 0.2)) { showFeedback = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { showFeedback = false } }
        }
    }

    private func cancelAllTasks() { gameTimerTask?.cancel(); rallyTask?.cancel(); swipeWindowTask?.cancel() }
}
