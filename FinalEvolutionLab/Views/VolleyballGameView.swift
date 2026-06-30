import SwiftUI

// MARK: - Supporting Types (preserved)

private enum VBTouchPhase { case pass, set, spike }
private enum VBRallyState {
    case idle, ballIncoming, awaitingPass, awaitingSet, awaitingSpike, ballCrossing, opponentDig, opponentHitting
}
private enum VBPhase { case ready, playing, result }
private struct VBBall {
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var isVisible: Bool = true
}

// MARK: - Beach Court Canvas

private struct VBCourtCanvas: View {
    let ballPosition: CGPoint
    let ballVisible: Bool
    let touchPhase: VBTouchPhase
    let inputWindowOpen: Bool
    let rallyState: VBRallyState
    let crowdLevel: Double

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                var d = VBDrawer(
                    t: tl.date.timeIntervalSinceReferenceDate,
                    W: size.width, H: size.height,
                    ballPos: ballPosition, ballVisible: ballVisible,
                    touchPhase: touchPhase, inputOpen: inputWindowOpen,
                    rallyState: rallyState, crowd: crowdLevel
                )
                d.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Drawer

private struct VBDrawer {
    let t: Double
    let W: CGFloat; let H: CGFloat
    let ballPos: CGPoint; let ballVisible: Bool
    let touchPhase: VBTouchPhase; let inputOpen: Bool
    let rallyState: VBRallyState; let crowd: Double

    // Court geometry
    var cL: CGFloat { W * 0.07 }
    var cR: CGFloat { W * 0.93 }
    var cT: CGFloat { H * 0.15 }
    var cB: CGFloat { H * 0.92 }
    var netY: CGFloat { H * 0.50 }

    var ballCX: CGFloat { ballPos.x * W }
    var ballCY: CGFloat { ballPos.y * H }
    // Normalized distance from net (0=net, 1=baseline)
    var ballFromNet: CGFloat { abs(ballCY - netY) / (cB - netY) }

    mutating func render(ctx: inout GraphicsContext) {
        drawBackground(&ctx)
        drawCrowd(&ctx)
        drawCourt(&ctx)
        drawNet(&ctx)
        drawPlayers(&ctx)
        if ballVisible { drawBall(&ctx) }
        if inputOpen { drawInputZone(&ctx) }
    }

    // ─── Background ────────────────────────────────────────────────────────────

    private func drawBackground(_ ctx: inout GraphicsContext) {
        // Sky gradient
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.48)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red:0.25,green:0.60,blue:0.95),
                                      Color(red:0.55,green:0.80,blue:0.98)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: H * 0.48)))

        // Sun
        let sunX = W * 0.78; let sunY = H * 0.10
        var glowCtx = ctx; glowCtx.addFilter(.blur(radius: 18))
        glowCtx.fill(Path(ellipseIn: CGRect(x: sunX-20, y: sunY-20, width: 40, height: 40)),
                     with: .color(Color(red:1.0,green:0.94,blue:0.60).opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x: sunX-13, y: sunY-13, width: 26, height: 26)),
                 with: .color(Color(red:1.0,green:0.95,blue:0.65)))

        // Ocean band
        ctx.fill(Path(CGRect(x: 0, y: H * 0.42, width: W, height: H * 0.06)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red:0.18,green:0.55,blue:0.82),
                                      Color(red:0.12,green:0.42,blue:0.72)]),
                    startPoint: CGPoint(x: 0, y: H * 0.42),
                    endPoint: CGPoint(x: 0, y: H * 0.48)))
        // Ocean wave shimmer
        for wi in 0..<5 {
            let wavePhase = fmod(t * 0.8 + Double(wi) * 0.6, 1.0)
            let wx = CGFloat(wavePhase) * W
            var wave = Path()
            wave.move(to: CGPoint(x: wx - 20, y: H * 0.44))
            wave.addQuadCurve(to: CGPoint(x: wx + 20, y: H * 0.44),
                               control: CGPoint(x: wx, y: H * 0.43))
            ctx.stroke(wave, with: .color(.white.opacity(0.30)), lineWidth: 1.0)
        }

        // Sand
        ctx.fill(Path(CGRect(x: 0, y: H * 0.48, width: W, height: H * 0.52)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red:0.88,green:0.78,blue:0.56),
                                      Color(red:0.82,green:0.70,blue:0.48)]),
                    startPoint: CGPoint(x: 0, y: H * 0.48),
                    endPoint: CGPoint(x: 0, y: H)))

        // Sand texture dots
        for si in stride(from: 0, to: 40, by: 1) {
            let sx = W * CGFloat(si) / 40 + CGFloat(sin(Double(si) * 3.1)) * 8
            let sy = H * 0.55 + CGFloat(cos(Double(si) * 2.3)) * H * 0.12
            let sr: CGFloat = CGFloat(0.8 + sin(Double(si))) * 1.5
            ctx.fill(Path(ellipseIn: CGRect(x: sx-sr, y: sy-sr, width: sr*2, height: sr*2)),
                     with: .color(Color(red:0.72,green:0.62,blue:0.40).opacity(0.4)))
        }
    }

    // ─── Crowd ─────────────────────────────────────────────────────────────────

    private func drawCrowd(_ ctx: inout GraphicsContext) {
        let jerseys: [Color] = [
            Color(red:0.80,green:0.15,blue:0.15),
            Color(red:0.15,green:0.50,blue:0.85),
            Color(red:0.95,green:0.82,blue:0.10),
            Color(red:0.20,green:0.65,blue:0.25),
            Color(red:0.50,green:0.15,blue:0.75)
        ]
        // Left side crowd
        for row in 0..<2 {
            for col in 0..<5 {
                let cx = W * 0.03 + CGFloat(col) * W * 0.006
                let cy = H * 0.22 + CGFloat(row) * 20 + CGFloat(col) * 6
                let jColor = jerseys[(col * 2 + row * 3) % jerseys.count]
                let wave = CGFloat(sin(t * 1.0 + Double(col) * 1.2 + Double(row))) * 1.5
                ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: cy - 5 + wave, width: 10, height: 10)),
                         with: .color(jColor.opacity(0.65)))
            }
        }
        // Right side crowd
        for row in 0..<2 {
            for col in 0..<5 {
                let cx = W * 0.97 - CGFloat(col) * W * 0.006
                let cy = H * 0.22 + CGFloat(row) * 20 + CGFloat(col) * 6
                let jColor = jerseys[(col * 3 + row * 2 + 1) % jerseys.count]
                let wave = CGFloat(sin(t * 1.0 + Double(col) * 1.4 + Double(row) + 1.5)) * 1.5
                ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: cy - 5 + wave, width: 10, height: 10)),
                         with: .color(jColor.opacity(0.65)))
            }
        }
    }

    // ─── Court ─────────────────────────────────────────────────────────────────

    private func drawCourt(_ ctx: inout GraphicsContext) {
        // Court surface (slightly different sand shade)
        var court = Path()
        court.move(to: CGPoint(x: cL, y: cT))
        court.addLine(to: CGPoint(x: cR, y: cT))
        court.addLine(to: CGPoint(x: cR, y: cB))
        court.addLine(to: CGPoint(x: cL, y: cB))
        court.closeSubpath()
        ctx.fill(court, with: .color(Color(red:0.84,green:0.74,blue:0.52).opacity(0.60)))

        // Court lines
        let lineColor = Color.white.opacity(0.85)
        let lw: CGFloat = 1.8
        // Boundary
        ctx.stroke(court, with: .color(lineColor), lineWidth: lw)
        // Center line (net line)
        stroke(&ctx, from: CGPoint(x: cL, y: netY), to: CGPoint(x: cR, y: netY),
               color: lineColor.opacity(0.4), width: 0.8)

        // Attack lines (3m lines) — 9ft from net each side
        let attackOff = (cB - netY) * 0.36
        stroke(&ctx, from: CGPoint(x: cL, y: netY + attackOff), to: CGPoint(x: cR, y: netY + attackOff),
               color: lineColor.opacity(0.55), width: 1.2)
        stroke(&ctx, from: CGPoint(x: cL, y: netY - attackOff), to: CGPoint(x: cR, y: netY - attackOff),
               color: lineColor.opacity(0.55), width: 1.2)
    }

    // ─── Net ───────────────────────────────────────────────────────────────────

    private func drawNet(_ ctx: inout GraphicsContext) {
        let netH: CGFloat = 22
        let postH: CGFloat = netH + 10

        // Net shadow
        var sc = ctx; sc.addFilter(.blur(radius: 5))
        sc.fill(Path(CGRect(x: cL + 5, y: netY - 3, width: cR - cL - 5, height: 8)),
                with: .color(.black.opacity(0.30)))

        // Net posts
        for px in [cL - 4, cR + 4] {
            ctx.fill(Path(CGRect(x: px - 3.5, y: netY - postH, width: 7, height: postH + 6)),
                     with: .color(Color(white: 0.85)))
        }

        // Antenna (striped poles above net)
        for (ax, phase): (CGFloat, Double) in [(cL + (cR-cL)*0.28, 0), (cL + (cR-cL)*0.72, .pi)] {
            for stripe in 0..<5 {
                let sy = netY - netH - 18 + CGFloat(stripe) * 5
                ctx.fill(Path(CGRect(x: ax - 2, y: sy, width: 4, height: 4.5)),
                         with: .color(stripe % 2 == 0 ? Color.red : .white))
            }
            _ = phase // used to offset
        }

        // Net mesh
        let cols = 24
        for c in 0...cols {
            let mx = cL + CGFloat(c) / CGFloat(cols) * (cR - cL)
            stroke(&ctx, from: CGPoint(x: mx, y: netY - netH), to: CGPoint(x: mx, y: netY),
                   color: Color(white:0.70).opacity(0.4), width: 0.6)
        }
        for r in 0..<5 {
            let ry = netY - netH + CGFloat(r) * netH / 4
            stroke(&ctx, from: CGPoint(x: cL, y: ry), to: CGPoint(x: cR, y: ry),
                   color: Color(white:0.70).opacity(0.4), width: 0.6)
        }

        // Top tape (white band)
        ctx.fill(Path(CGRect(x: cL - 4, y: netY - netH - 3, width: cR - cL + 8, height: 5)),
                 with: .color(.white.opacity(0.92)))
    }

    // ─── Players ───────────────────────────────────────────────────────────────

    private func drawPlayers(_ ctx: inout GraphicsContext) {
        // Player at bottom — tracks ball x, pose based on touchPhase
        let playerX = lerp(ballCX, W * 0.5, 0.35)
        let playerY = cB + (H - cB) * 0.30
        drawPlayer(&ctx, x: playerX, y: playerY,
                   color: Color(red:0.15,green:0.60,blue:0.20),
                   pose: inputOpen ? touchPhase : .pass,
                   label: "YOU", facingUp: true)

        // Opponent at top — tracks ball x
        let oppX = lerp(ballCX, W * 0.5, 0.5)
        let oppY = cT - (cT) * 0.35
        let oppPose: VBTouchPhase = (rallyState == .opponentHitting) ? .spike : .pass
        drawPlayer(&ctx, x: oppX, y: oppY,
                   color: Color(red:0.78,green:0.12,blue:0.12),
                   pose: oppPose, label: "OPP", facingUp: false)
    }

    private func drawPlayer(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat,
                             color: Color, pose: VBTouchPhase, label: String, facingUp: Bool) {
        let dir: CGFloat = facingUp ? -1 : 1

        // Shadow
        var sc = ctx; sc.addFilter(.blur(radius: 4))
        sc.fill(Path(ellipseIn: CGRect(x: x-14, y: y + 2, width: 28, height: 7)),
                with: .color(.black.opacity(0.28)))

        // Head
        ctx.fill(Path(ellipseIn: CGRect(x: x-6, y: y-7, width: 12, height: 12)),
                 with: .color(Color(red:0.94,green:0.81,blue:0.68)))

        // Headband
        ctx.fill(Path(CGRect(x: x-6.5, y: y-7, width: 13, height: 3.5)),
                 with: .color(color.opacity(0.8)))

        // Body
        var body = Path()
        body.move(to: CGPoint(x: x, y: y + 3))
        body.addLine(to: CGPoint(x: x, y: y + 16))
        ctx.stroke(body, with: .color(color), lineWidth: 4.5)

        // Arms based on pose
        let armY = y + 8
        switch pose {
        case .pass:
            // Arms out in front-low (platform/forearm pass)
            var arms = Path()
            arms.move(to: CGPoint(x: x - 12, y: armY + 6))
            arms.addLine(to: CGPoint(x: x, y: armY + 10))
            arms.addLine(to: CGPoint(x: x + 12, y: armY + 6))
            ctx.stroke(arms, with: .color(Color(red:0.94,green:0.81,blue:0.68)), lineWidth: 2.5)

        case .set:
            // Arms overhead (overhead set)
            let bob = CGFloat(sin(t * 8)) * 2
            var arms = Path()
            arms.move(to: CGPoint(x: x - 8, y: armY - 2 + bob))
            arms.addLine(to: CGPoint(x: x, y: armY - 6 + bob))
            arms.addLine(to: CGPoint(x: x + 8, y: armY - 2 + bob))
            ctx.stroke(arms, with: .color(Color(red:0.94,green:0.81,blue:0.68)), lineWidth: 2.5)

        case .spike:
            // Jump + arm raised to spike
            let jump = CGFloat(abs(sin(t * 12))) * -8
            var arms = Path()
            arms.move(to: CGPoint(x: x - 10, y: armY + 4 + jump))
            arms.addLine(to: CGPoint(x: x, y: armY + jump))
            arms.addLine(to: CGPoint(x: x + 10 * dir, y: armY - 10 + jump))
            ctx.stroke(arms, with: .color(Color(red:0.94,green:0.81,blue:0.68)), lineWidth: 2.5)
            // Spike arm extended high
            var spike = Path()
            spike.move(to: CGPoint(x: x + 10 * dir, y: armY - 10 + jump))
            spike.addLine(to: CGPoint(x: x + 14 * dir, y: armY - 20 + jump))
            ctx.stroke(spike, with: .color(Color(red:0.94,green:0.81,blue:0.68)), lineWidth: 2.5)
        }

        // Legs
        let jumpOffset: CGFloat = pose == .spike ? CGFloat(abs(sin(t * 12))) * -6 : 0
        var legs = Path()
        legs.move(to: CGPoint(x: x - 7, y: y + 28 + jumpOffset))
        legs.addLine(to: CGPoint(x: x, y: y + 16 + jumpOffset))
        legs.addLine(to: CGPoint(x: x + 7, y: y + 28 + jumpOffset))
        ctx.stroke(legs, with: .color(Color(red:0.20,green:0.22,blue:0.60)), lineWidth: 2.8)
    }

    // ─── Input Zone ────────────────────────────────────────────────────────────

    private func drawInputZone(_ ctx: inout GraphicsContext) {
        let pulse = CGFloat(sin(t * 8)) * 2.5
        // Zone color based on touch phase
        let zoneColor: Color = {
            switch touchPhase {
            case .pass:  return Color(red:0.98,green:0.75,blue:0.14)
            case .set:   return Color(red:0.15,green:0.85,blue:0.85)
            case .spike: return Color.red
            }
        }()
        let zoneRect = CGRect(x: cL - pulse, y: netY + (cB - netY) * 0.15 - pulse,
                               width: cR - cL + pulse * 2,
                               height: (cB - netY) * 0.60 + pulse * 2)
        // Glow fill
        var gc = ctx; gc.addFilter(.blur(radius: 10))
        gc.fill(Path(roundedRect: zoneRect, cornerRadius: 8),
                with: .color(zoneColor.opacity(0.18)))
        // Border
        ctx.stroke(Path(roundedRect: zoneRect, cornerRadius: 8),
                   with: .color(zoneColor.opacity(0.80)), lineWidth: 2.0)

        // Label
        let label: String = {
            switch touchPhase {
            case .pass:  return "◆ TAP TO PASS ◆"
            case .set:   return "◆ TAP TO SET ◆"
            case .spike: return "▼ SWIPE DOWN TO SPIKE ▼"
            }
        }()
        ctx.draw(
            Text(label).font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(zoneColor.opacity(0.90)),
            at: CGPoint(x: W / 2, y: netY + (cB - netY) * 0.15 - 10), anchor: .center
        )
    }

    // ─── Ball ─────────────────────────────────────────────────────────────────

    private func drawBall(_ ctx: inout GraphicsContext) {
        let bx = ballCX; let by = ballCY
        // Ball "height" above ground — approximated by distance from near baseline
        let heightFactor = max(0, 1.0 - (by - netY) / (cB - netY))  // 1 near net, 0 at baseline
        let r: CGFloat = 8 + heightFactor * 5  // bigger when higher

        // Air shadow on court (slightly behind ball in x, below in y)
        let shadowScale: CGFloat = max(0.3, 1.0 - heightFactor)
        let shadowY = cB - 8
        var sc = ctx; sc.addFilter(.blur(radius: 8 * shadowScale))
        sc.fill(Path(ellipseIn: CGRect(x: bx - 12 * shadowScale, y: shadowY - 4 * shadowScale,
                                       width: 24 * shadowScale, height: 8 * shadowScale)),
                with: .color(.black.opacity(0.40 * Double(shadowScale))))

        // Glow
        var glowCtx = ctx; glowCtx.addFilter(.blur(radius: r * 1.1))
        glowCtx.fill(Path(ellipseIn: CGRect(x: bx-r, y: by-r, width: r*2, height: r*2)),
                     with: .color(Color.white.opacity(0.50)))

        // Ball base
        ctx.fill(Path(ellipseIn: CGRect(x: bx-r, y: by-r, width: r*2, height: r*2)),
                 with: .radialGradient(
                    Gradient(colors: [.white, Color(red:0.92,green:0.92,blue:0.96)]),
                    center: CGPoint(x: bx - r*0.3, y: by - r*0.3),
                    startRadius: 0, endRadius: r * 1.1))

        // Panel seam lines (volleyball panels)
        let panelColor = Color(red:0.25,green:0.35,blue:0.80).opacity(0.55)
        // Vertical seam
        var v = Path()
        v.addArc(center: CGPoint(x: bx, y: by), radius: r - 1.5,
                 startAngle: .degrees(-80), endAngle: .degrees(80), clockwise: false)
        ctx.stroke(v, with: .color(panelColor), lineWidth: 1.0)
        // Second seam (rotated ~60°)
        var v2 = Path()
        v2.addArc(center: CGPoint(x: bx, y: by), radius: r - 1.5,
                  startAngle: .degrees(40), endAngle: .degrees(200), clockwise: false)
        ctx.stroke(v2, with: .color(panelColor), lineWidth: 1.0)
        // Third seam
        var v3 = Path()
        v3.addArc(center: CGPoint(x: bx, y: by), radius: r - 1.5,
                  startAngle: .degrees(160), endAngle: .degrees(320), clockwise: false)
        ctx.stroke(v3, with: .color(panelColor), lineWidth: 1.0)

        // Specular highlight
        ctx.fill(Path(ellipseIn: CGRect(x: bx - r*0.45, y: by - r*0.60, width: r*0.38, height: r*0.22)),
                 with: .color(.white.opacity(0.92)))
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    private func stroke(_ ctx: inout GraphicsContext, from: CGPoint, to: CGPoint,
                        color: Color, width: CGFloat) {
        var p = Path(); p.move(to: from); p.addLine(to: to)
        ctx.stroke(p, with: .color(color), lineWidth: width)
    }
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}

// MARK: - VolleyballGameView

struct VolleyballGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: VBPhase = .ready
    @State private var timeLeft: Int = 90
    @State private var gameTimerTask: Task<Void, Never>? = nil

    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var rallyStreak: Int = 0
    @State private var bestStreak: Int = 0

    @State private var rallyState: VBRallyState = .idle
    @State private var touchPhase: VBTouchPhase = .pass
    @State private var ball: VBBall = VBBall()
    @State private var rallyTask: Task<Void, Never>? = nil
    @State private var inputWindowTask: Task<Void, Never>? = nil
    @State private var inputWindowOpen: Bool = false
    @State private var crowdLevel: Double = 0.30

    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var showAce: Bool = false
    @State private var touchHighlight: VBTouchPhase? = nil

    private let XP_CAP_PER_SESSION = 500
    private let accentColor = Color(red: 0.98, green: 0.75, blue: 0.14)
    private let opponentName = "Kai Nexus"

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(colors: [Color(red:0.04,green:0.04,blue:0.12), Theme.deepBlack],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Beach Volleyball", subtitle: "90-Second Match · Pass · Set · Spike",
                    countdown: 3, accentColor: accentColor, onComplete: { startMatch() }
                )
            case .playing: playingView
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
            HStack(alignment: .top) {
                VStack(spacing: 2) {
                    Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Text("\(playerScore)").font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundStyle(.white).contentTransition(.numericText())
                        .shadow(color: accentColor.opacity(0.4), radius: 8)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text(clockString).font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(timeLeft <= 15 ? .red : accentColor)
                    if rallyStreak >= 2 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").font(.system(size: 10)).foregroundStyle(.orange)
                            Text("×\(rallyStreak)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.orange)
                        }.transition(.scale.combined(with: .opacity))
                    }
                    Text("RALLY STREAK").font(.system(size: 6, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(1)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(opponentName.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Text("\(opponentScore)").font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.45)).contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 24)
            .animation(.spring(response: 0.3), value: rallyStreak)
            Rectangle().fill(accentColor.opacity(0.25)).frame(height: 1).padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    // MARK: - Playing View

    private var playingView: some View {
        ZStack {
            VStack(spacing: 0) {
                scoreHeader
                Spacer()

                ZStack {
                    VBCourtCanvas(
                        ballPosition: ball.position,
                        ballVisible: ball.isVisible,
                        touchPhase: touchPhase,
                        inputWindowOpen: inputWindowOpen,
                        rallyState: rallyState,
                        crowdLevel: crowdLevel
                    )
                    .animation(.easeInOut(duration: 0.5), value: ball.position)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .frame(height: 260)
                .padding(.horizontal, 16)

                Spacer().frame(height: 18)
                touchPromptRow
                Spacer().frame(height: 14)

                VStack(spacing: 6) {
                    if inputWindowOpen { actionButton } else {
                        Text(rallyStateHint).font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .frame(height: 60)
                .animation(.easeInOut(duration: 0.15), value: inputWindowOpen)
                Spacer()
            }

            if showFeedback {
                Text(feedbackText)
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(feedbackText.contains("ACE") ? accentColor :
                                     (feedbackText.contains("PASS") || feedbackText.contains("SET") ||
                                      feedbackText.contains("SPIKE") || feedbackText.contains("DIG") ?
                                      Color(red:0.2,green:0.9,blue:0.4) : .red))
                    .shadow(color: accentColor.opacity(0.5), radius: 12)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if showAce {
                VStack(spacing: 8) {
                    Text("ACE!").font(.system(size: 52, weight: .black, design: .monospaced)).italic()
                        .foregroundStyle(accentColor).shadow(color: accentColor.opacity(0.7), radius: 20)
                    Text("Unreturnable spike!").font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Touch Prompt Row

    private var touchPromptRow: some View {
        HStack(spacing: 0) {
            ForEach([VBTouchPhase.pass, .set, .spike], id: \.self) { tp in
                let isActive = touchPhase == tp && inputWindowOpen
                let isPast = touchPhasePast(tp)
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(isActive ? accentColor : (isPast ? Theme.foundationGreen.opacity(0.3) : Color.white.opacity(0.05)))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(isActive ? accentColor : (isPast ? Theme.foundationGreen : Color.white.opacity(0.1)), lineWidth: 2))
                            .scaleEffect(isActive ? 1.12 : 1.0)
                            .animation(.spring(response: 0.25), value: isActive)
                        Image(systemName: touchPhaseIcon(tp)).font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isActive ? .black : (isPast ? Theme.foundationGreen : .white.opacity(0.35)))
                    }
                    Text(touchPhaseLabel(tp).uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(isActive ? accentColor : .secondary).tracking(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            switch touchPhase {
            case .pass:
                tapButton(label: "TAP — PASS", color: accentColor)
            case .set:
                tapButton(label: "TAP — SET", color: Theme.brandCyan)
            case .spike:
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.4), lineWidth: 2))
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 18)).foregroundStyle(.red)
                        Text("SWIPE DOWN — SPIKE").font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(.red)
                    }
                }
                .frame(height: 54).padding(.horizontal, 40)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 20).onEnded { v in
                    if v.location.y - v.startLocation.y > 25 { handlePlayerInput() }
                })
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func tapButton(label: String, color: Color) -> some View {
        Button { handlePlayerInput() } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill").font(.system(size: 16))
                Text(label).font(.system(size: 17, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(color).clipShape(.rect(cornerRadius: 14))
            .shadow(color: color.opacity(0.4), radius: 8)
        }
        .padding(.horizontal, 40)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Helper Labels

    private var rallyStateHint: String {
        switch rallyState {
        case .idle:            return "Starting rally…"
        case .ballIncoming:    return "Ball incoming…"
        case .awaitingPass:    return "Get ready to pass!"
        case .awaitingSet:     return "Ball is up — set it!"
        case .awaitingSpike:   return "Position for spike…"
        case .ballCrossing:    return "Ball over the net!"
        case .opponentDig:     return "Opponent digs it!"
        case .opponentHitting: return "Opponent attacking…"
        }
    }

    private func touchPhaseIcon(_ tp: VBTouchPhase) -> String {
        switch tp { case .pass: "hand.raised.fill"; case .set: "arrow.up.circle.fill"; case .spike: "bolt.fill" }
    }
    private func touchPhaseLabel(_ tp: VBTouchPhase) -> String {
        switch tp { case .pass: "Pass"; case .set: "Set"; case .spike: "Spike" }
    }
    private func touchPhasePast(_ tp: VBTouchPhase) -> Bool {
        switch tp { case .pass: touchPhase == .set || touchPhase == .spike; case .set: touchPhase == .spike; case .spike: false }
    }
    private var clockString: String { String(format: "%d:%02d", timeLeft / 60, timeLeft % 60) }

    // MARK: - Match Logic (preserved)

    private func startMatch() {
        phase = .playing; startGameTimer()
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { beginRally() }
        }
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

    private func beginRally() {
        guard phase == .playing else { return }
        touchPhase = .pass; rallyState = .ballIncoming; inputWindowOpen = false
        withAnimation { ball.position = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: 0.18); ball.isVisible = true }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                let landX = CGFloat.random(in: 0.25...0.75)
                withAnimation(.easeInOut(duration: 0.55)) { ball.position = CGPoint(x: landX, y: 0.78) }
                rallyState = .awaitingPass
            }
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run { openInputWindow() }
        }
    }

    private func openInputWindow() {
        guard phase == .playing else { return }
        inputWindowOpen = true
        inputWindowTask?.cancel()
        inputWindowTask = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if inputWindowOpen { inputWindowOpen = false; flashFeedback("MISSED!"); opponentWinsPoint() }
            }
        }
    }

    private func handlePlayerInput() {
        guard inputWindowOpen, phase == .playing else { return }
        inputWindowTask?.cancel(); inputWindowOpen = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch touchPhase {
        case .pass:
            flashFeedback("PASS!"); advanceBall(toY: 0.55); rallyState = .awaitingSet; touchPhase = .set
            Task { try? await Task.sleep(for: .milliseconds(500)); await MainActor.run { openInputWindow() } }
        case .set:
            flashFeedback("SET!"); advanceBall(toY: 0.42); rallyState = .awaitingSpike; touchPhase = .spike
            Task { try? await Task.sleep(for: .milliseconds(500)); await MainActor.run { openInputWindow() } }
        case .spike:
            executeSpike()
        }
    }

    private func advanceBall(toY: CGFloat) {
        let x = CGFloat.random(in: 0.3...0.7)
        withAnimation(.easeOut(duration: 0.35)) { ball.position = CGPoint(x: x, y: toY) }
    }

    private func executeSpike() {
        flashFeedback("SPIKE!")
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let spikeX = CGFloat.random(in: 0.2...0.8)
        withAnimation(.easeIn(duration: 0.4)) { ball.position = CGPoint(x: spikeX, y: 0.25) }
        rallyState = .ballCrossing
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                let prq = viewModel.effectiveMetrics.prqScore
                let digChance = 0.3 + (prq / 200.0)
                if Double.random(in: 0...1) < digChance {
                    rallyState = .opponentDig
                    withAnimation(.easeOut(duration: 0.35)) { ball.position = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: 0.18) }
                    flashFeedback("DIG!")
                    Task { try? await Task.sleep(for: .milliseconds(800)); await MainActor.run { opponentCounter() } }
                } else {
                    withAnimation(.easeIn(duration: 0.3)) { ball.position = CGPoint(x: spikeX, y: 0.12) }
                    playerScores(ace: true)
                }
            }
        }
    }

    private func opponentCounter() {
        guard phase == .playing else { return }
        rallyState = .opponentHitting
        Task {
            let delay = Double.random(in: 0.5...1.1)
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run { guard phase == .playing else { return }; beginRally() }
        }
    }

    private func playerScores(ace: Bool) {
        withAnimation { playerScore += 1 }
        rallyStreak += 1; if rallyStreak > bestStreak { bestStreak = rallyStreak }
        crowdLevel = min(1.0, crowdLevel + 0.15)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if ace {
            withAnimation(.spring(response: 0.25)) { showAce = true }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run { withAnimation(.easeOut(duration: 0.4)) { showAce = false }; scheduleNextRally() }
            }
        } else { scheduleNextRally() }
    }

    private func opponentWinsPoint() {
        withAnimation { opponentScore += 1 }
        rallyStreak = 0; scheduleNextRally()
    }

    private func scheduleNextRally() {
        Task {
            try? await Task.sleep(for: .milliseconds(1000))
            await MainActor.run { guard phase == .playing else { return }; beginRally() }
        }
    }

    private func endMatch() { cancelAllTasks(); withAnimation(.spring(response: 0.4)) { phase = .result } }

    private func flashFeedback(_ text: String) {
        feedbackText = text
        withAnimation(.spring(response: 0.2)) { showFeedback = true }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run { withAnimation(.easeOut(duration: 0.25)) { showFeedback = false } }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        let playerWon = playerScore > opponentScore
        let isDraw = playerScore == opponentScore
        let shards = isDraw ? 25 : (playerWon ? 50 : 15)
        return ResultScreen(
            winner: isDraw ? .draw : (playerWon ? .p1 : .p2),
            p1Score: playerScore, p2Score: opponentScore,
            title: "Beach Volleyball", accentColor: accentColor,
            prqGain: playerWon ? 10 : (isDraw ? 5 : 2),
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "Spike",
            modeAttributeValue: playerScore > 0 ? Double(playerScore) / Double(max(1, playerScore + opponentScore)) : 0,
            onReturn: { viewModel.profile.evolutionShards += shards; dismiss() }
        )
    }

    private func cancelAllTasks() { gameTimerTask?.cancel(); rallyTask?.cancel(); inputWindowTask?.cancel() }
}
