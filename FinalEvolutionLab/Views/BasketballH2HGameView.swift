import SwiftUI

// MARK: - Types

private enum H2HPhase { case ready, playing, result }
private enum ShotResult: String { case made = "MADE", blocked = "BLOCKED", miss = "MISS" }
private enum H2HPossession { case player, opponent }

// MARK: - Street Court Canvas

private struct StreetCourtCanvas: View {
    let possession: H2HPossession
    let shotProgress: Double    // 0→1 during shot arc; -1 = idle
    let shotMade: Bool
    let playerPose: String      // "idle","shoot","crossover","drive","defend"
    let opponentPose: String    // "idle","guard","block","shoot"
    let rimShake: Double        // 0 = still, >0 = rim vibrating

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = StreetDrawer(size: size, t: t,
                                     possession: possession, shotProgress: shotProgress,
                                     shotMade: shotMade, playerPose: playerPose,
                                     opponentPose: opponentPose, rimShake: rimShake)
                d.render(into: &ctx)
            }
        }
    }
}

private struct StreetDrawer {
    let W: CGFloat, H: CGFloat, t: Double
    let possession: H2HPossession
    let shotProgress: Double
    let shotMade: Bool
    let playerPose: String
    let opponentPose: String
    let rimShake: Double

    // Court geometry
    var floorY: CGFloat { H * 0.68 }
    var playerX: CGFloat { W * 0.22 }
    var playerY: CGFloat { floorY }
    var opponentX: CGFloat { W * 0.62 }
    var opponentY: CGFloat { floorY - H * 0.025 }  // opponent slightly closer to basket
    var rimX: CGFloat { W * 0.82 }
    var rimY: CGFloat { H * 0.34 + CGFloat(rimShake) * 3 * CGFloat(sin(t * 50)) }
    var bbX: CGFloat { rimX + 4 }

    init(size: CGSize, t: Double, possession: H2HPossession, shotProgress: Double,
         shotMade: Bool, playerPose: String, opponentPose: String, rimShake: Double) {
        self.W = size.width; self.H = size.height; self.t = t
        self.possession = possession; self.shotProgress = shotProgress
        self.shotMade = shotMade; self.playerPose = playerPose
        self.opponentPose = opponentPose; self.rimShake = rimShake
    }

    mutating func render(into ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawSpectators(ctx: &ctx)
        drawFence(ctx: &ctx)
        drawCourt(ctx: &ctx)
        drawBasket(ctx: &ctx)
        if shotProgress >= 0 { drawBallArc(ctx: &ctx) }
        drawPlayerShadow(ctx: &ctx)
        drawStickFigure(ctx: &ctx, cx: opponentX, fy: opponentY, pose: opponentPose,
                        color: Color(red:1.0,green:0.25,blue:0.25), flip: true)
        drawStickFigure(ctx: &ctx, cx: playerX, fy: playerY, pose: playerPose,
                        color: Color(red:0.18,green:0.78,blue:1.0), flip: false)
        if shotProgress < 0 { drawDribble(ctx: &ctx) }
        if shotMade && shotProgress < 0 { drawSwishNet(ctx: &ctx) }
    }

    // MARK: Sky / Background
    private func drawSky(ctx: inout GraphicsContext) {
        // Deep night sky gradient
        ctx.fill(Path(CGRect(origin:.zero, size:CGSize(width:W, height:H))),
                 with:.color(Color(red:0.04,green:0.04,blue:0.10)))

        // Streetlight cone on right (over basket)
        var cone = Path()
        cone.move(to: CGPoint(x:rimX+10, y:0))
        cone.addLine(to: CGPoint(x:rimX+60, y:floorY))
        cone.addLine(to: CGPoint(x:rimX-40, y:floorY))
        cone.closeSubpath()
        ctx.fill(cone, with:.color(Color(red:1.0,green:0.85,blue:0.4).opacity(0.06)))

        // Left ambient light (player side)
        var cone2 = Path()
        cone2.addEllipse(in: CGRect(x:playerX-80, y:0, width:160, height:floorY*0.9))
        ctx.fill(cone2, with:.color(Color(red:0.25,green:0.45,blue:1.0).opacity(0.04)))

        // Stars
        for i in 0..<22 {
            let sx = W * CGFloat((i * 137 % 100)) / 100.0
            let sy = H * 0.35 * CGFloat((i * 71 % 100)) / 100.0
            let starAlpha = 0.2 + 0.25 * sin(t * 0.5 + Double(i))
            ctx.fill(Path(ellipseIn: CGRect(x:sx-1,y:sy-1,width:2,height:2)),
                     with:.color(Color.white.opacity(starAlpha)))
        }
    }

    // MARK: Spectators
    private func drawSpectators(ctx: inout GraphicsContext) {
        let row1Y = floorY - H * 0.28
        let row2Y = floorY - H * 0.22
        let jerseyColors: [Color] = [.red, .blue, .yellow, .green, .white, .orange]
        for row in 0..<2 {
            let ry = row == 0 ? row1Y : row2Y
            let count = 9 + row * 3
            for i in 0..<count {
                let sx = W * (CGFloat(i) + 0.5) / CGFloat(count)
                let bob = CGFloat(sin(t * 1.8 + Double(i) * 0.6 + Double(row))) * 3
                let r: CGFloat = 4.5 + CGFloat(row) * 0.5
                let jc = jerseyColors[(i * 3 + row) % jerseyColors.count]
                ctx.fill(Path(ellipseIn: CGRect(x:sx-r*0.9, y:ry-bob-r*1.8, width:r*1.8, height:r*1.8)),
                         with:.color(Color(red:0.88,green:0.72,blue:0.58).opacity(0.5)))
                ctx.fill(Path(CGRect(x:sx-r*0.8, y:ry-bob, width:r*1.6, height:r*1.8)),
                         with:.color(jc.opacity(0.45 + Double(row)*0.1)))
            }
        }
    }

    // MARK: Chain-link fence outline
    private func drawFence(ctx: inout GraphicsContext) {
        let fy = floorY - H * 0.15
        var fence = Path(); fence.move(to: CGPoint(x:0, y:fy)); fence.addLine(to: CGPoint(x:W, y:fy))
        ctx.stroke(fence, with:.color(Color.white.opacity(0.05)), lineWidth:0.8)
        // Fence posts
        for i in 0..<8 {
            let px = W * CGFloat(i) / 7.0
            var post = Path(); post.move(to: CGPoint(x:px, y:fy)); post.addLine(to: CGPoint(x:px, y:floorY - H*0.13))
            ctx.stroke(post, with:.color(Color.white.opacity(0.06)), lineWidth:0.5)
        }
    }

    // MARK: Court (asphalt half-court)
    private func drawCourt(ctx: inout GraphicsContext) {
        // Asphalt floor fill
        ctx.fill(Path(CGRect(x:0, y:floorY, width:W, height:H-floorY)),
                 with:.color(Color(red:0.14,green:0.14,blue:0.18)))

        // Floor line
        var fl = Path(); fl.move(to: CGPoint(x:0, y:floorY)); fl.addLine(to: CGPoint(x:W, y:floorY))
        ctx.stroke(fl, with:.color(Color.white.opacity(0.30)), lineWidth:1.8)

        // Key lane (painted orange)
        ctx.fill(Path(CGRect(x:W*0.46, y:floorY, width:W*0.38, height:H*0.30)),
                 with:.color(Color(red:0.80,green:0.38,blue:0.08).opacity(0.18)))
        // Key lane border
        ctx.stroke(Path(CGRect(x:W*0.46, y:floorY, width:W*0.38, height:H*0.30)),
                   with:.color(Color.white.opacity(0.14)), lineWidth:1)

        // 3-point arc — drawn from behind court
        let arcCX = rimX; let arcCY = floorY
        let arcR = W * 0.50
        var arc = Path()
        arc.addArc(center: CGPoint(x:arcCX, y:arcCY), radius:arcR,
                   startAngle:.degrees(180), endAngle:.degrees(270), clockwise:false)
        ctx.stroke(arc, with:.color(Color.white.opacity(0.18)), lineWidth:1.2)

        // Free throw circle
        let ftX = W * 0.65; let ftY = floorY
        var ftCircle = Path()
        ftCircle.addArc(center: CGPoint(x:ftX, y:ftY), radius:W*0.12,
                        startAngle:.degrees(180), endAngle:.degrees(360), clockwise:false)
        ctx.stroke(ftCircle, with:.color(Color.white.opacity(0.12)), lineWidth:0.8)

        // Floor glow under basket
        ctx.fill(Path(ellipseIn: CGRect(x:rimX-30, y:floorY, width:60, height:14)),
                 with:.color(Color.orange.opacity(0.12)))
    }

    // MARK: Basket
    private func drawBasket(ctx: inout GraphicsContext) {
        // Pole
        var pole = Path(); pole.move(to: CGPoint(x:bbX+4, y:floorY)); pole.addLine(to: CGPoint(x:bbX+4, y:rimY-50))
        ctx.stroke(pole, with:.color(Color.white.opacity(0.25)), lineWidth:3)

        // Backboard
        let bbRect = CGRect(x:bbX, y:rimY-50, width:10, height:42)
        ctx.fill(Path(bbRect), with:.color(Color(red:0.80,green:0.85,blue:0.90).opacity(0.65)))
        ctx.stroke(Path(bbRect), with:.color(Color.white.opacity(0.5)), lineWidth:1)
        // Target square
        ctx.stroke(Path(CGRect(x:bbX-1, y:rimY-32, width:12, height:14)),
                   with:.color(Color.red.opacity(0.5)), lineWidth:1)

        // Rim with glow
        let rimL = rimX - 18; let rimR = rimX + 2
        var rim = Path(); rim.move(to: CGPoint(x:rimL, y:rimY)); rim.addLine(to: CGPoint(x:rimR, y:rimY))
        var gc = ctx; gc.addFilter(.shadow(color:Color.orange.opacity(0.8), radius:5))
        gc.stroke(rim, with:.color(Color.orange), lineWidth:4)

        // Net strands
        for i in 0...5 {
            let tf = CGFloat(i) / 5.0
            let nx = rimL + (rimR-rimL)*tf
            let ny = rimY + 20 * (1 + abs(tf-0.5)*0.4)
            var s = Path(); s.move(to: CGPoint(x:nx, y:rimY)); s.addLine(to: CGPoint(x:nx+(0.5-tf)*4, y:ny))
            ctx.stroke(s, with:.color(Color.white.opacity(0.22)), lineWidth:0.8)
        }
        for rung in 1...2 {
            let rf = CGFloat(rung) / 3.0
            let ry = rimY + 20*0.8*rf; let sh = (rimR-rimL)*0.10*rf
            var r = Path(); r.move(to: CGPoint(x:rimL+sh, y:ry)); r.addLine(to: CGPoint(x:rimR-sh, y:ry))
            ctx.stroke(r, with:.color(Color.white.opacity(0.12)), lineWidth:0.7)
        }
    }

    // MARK: Ball Arc
    private func drawBallArc(ctx: inout GraphicsContext) {
        let ep = CGFloat(shotProgress)
        let br: CGFloat = 7
        // Start: player hand, End: rim center
        let sx = playerX + 12; let sy = playerY - 52
        let ex = (rimX - 16 + rimX + 2) / 2; let ey = rimY - 5
        let bx = sx + (ex-sx)*ep
        let by = sy + (ey-sy)*ep - H*0.32*4*ep*(1-ep)  // high parabola

        // Trail (3 ghosts)
        for trail in 1...3 {
            let pastEp = max(0, ep - CGFloat(trail)*0.07)
            let tbx = sx + (ex-sx)*pastEp
            let tby = sy + (ey-sy)*pastEp - H*0.32*4*pastEp*(1-pastEp)
            ctx.fill(Path(ellipseIn: CGRect(x:tbx-br,y:tby-br,width:br*2,height:br*2)),
                     with:.color(Color.orange.opacity(0.20 - Double(trail)*0.05)))
        }

        // Main ball
        var bc = ctx; bc.addFilter(.shadow(color:Color.orange.opacity(0.6), radius:4))
        bc.fill(Path(ellipseIn: CGRect(x:bx-br,y:by-br,width:br*2,height:by*2 - (by-br)*2)),
                with:.color(Color.orange))
        var seam = Path()
        seam.addArc(center: CGPoint(x:bx,y:by), radius:br*0.75,
                    startAngle:.degrees(-50), endAngle:.degrees(190), clockwise:false)
        ctx.stroke(seam, with:.color(Color.black.opacity(0.3)), lineWidth:0.9)

        // Impact burst when ball arrives at rim (ep > 0.85)
        if ep > 0.85 {
            let impactFrac = (ep - 0.85) / 0.15
            let burstR = CGFloat(impactFrac) * 24
            var ring = Path(); ring.addEllipse(in: CGRect(x:ex-burstR, y:ey-burstR*0.5, width:burstR*2, height:burstR))
            ctx.stroke(ring, with:.color(Color.orange.opacity(max(0, 0.8 - impactFrac * 0.9))), lineWidth:2)
        }
    }

    // MARK: Dribble animation (when player has ball, no shot in progress)
    private func drawDribble(ctx: inout GraphicsContext) {
        let ballR: CGFloat = 7
        let who = possession == .player
        let cx = who ? playerX + 12 : opponentX - 12
        let fy = who ? playerY : opponentY
        let bounce = abs(sin(t * .pi / 0.38)) * 18
        let by = fy - CGFloat(bounce) - 6
        var bc = ctx; bc.addFilter(.shadow(color:Color.orange.opacity(0.4), radius:3))
        bc.fill(Path(ellipseIn: CGRect(x:cx-ballR, y:by-ballR, width:ballR*2, height:ballR*2)),
                with:.color(Color.orange))
        var seam = Path()
        seam.addArc(center: CGPoint(x:cx,y:by), radius:ballR*0.75,
                    startAngle:.degrees(-50), endAngle:.degrees(190), clockwise:false)
        ctx.stroke(seam, with:.color(Color.black.opacity(0.28)), lineWidth:0.9)
    }

    // MARK: Swish net animation (after made basket)
    private func drawSwishNet(ctx: inout GraphicsContext) {
        let rimL = rimX - 18; let rimR2 = rimX + 2
        let swing = CGFloat(sin(t * 6.0)) * 5
        for i in 0...5 {
            let tf = CGFloat(i) / 5.0
            let nx = rimL + (rimR2-rimL)*tf
            let ny = rimY + 20*(1 + abs(tf-0.5)*0.4) + swing*abs(tf-0.5)
            var s = Path(); s.move(to: CGPoint(x:nx, y:rimY)); s.addLine(to: CGPoint(x:nx+(0.5-tf)*4+swing*0.3, y:ny))
            ctx.stroke(s, with:.color(Color.white.opacity(0.45)), lineWidth:1)
        }
    }

    // MARK: Ground shadows
    private func drawPlayerShadow(ctx: inout GraphicsContext) {
        func shadow(_ cx: CGFloat, _ fy: CGFloat) {
            ctx.fill(Path(ellipseIn: CGRect(x:cx-18, y:fy+2, width:36, height:7)),
                     with:.color(Color.black.opacity(0.30)))
        }
        shadow(playerX, playerY); shadow(opponentX, opponentY)
    }

    // MARK: Stick Figure
    private func drawStickFigure(ctx: inout GraphicsContext, cx: CGFloat, fy: CGFloat,
                                  pose: String, color: Color, flip: Bool) {
        let sc: CGFloat = H * 0.0030  // scale relative to canvas
        let m: CGFloat = flip ? -1 : 1
        let headR = sc * 9
        let bodyH = sc * 28
        let lw: CGFloat = 3.5

        let shoulderY = fy - bodyH - headR * 1.8
        let hipY = shoulderY + bodyH

        // Running cycle
        let cycle = t.truncatingRemainder(dividingBy: 0.55) / 0.55
        let sinC = CGFloat(sin(cycle * .pi * 2))

        // Head
        var hglow = ctx; hglow.addFilter(.shadow(color: color.opacity(0.35), radius: 6))
        hglow.fill(Path(ellipseIn: CGRect(x:cx-headR, y:shoulderY-headR*1.8, width:headR*2, height:headR*2)),
                   with:.color(Color(red:0.94,green:0.81,blue:0.70)))

        // Torso
        var spine = Path(); spine.move(to: CGPoint(x:cx, y:shoulderY)); spine.addLine(to: CGPoint(x:cx, y:hipY))
        ctx.stroke(spine, with:.color(color), lineWidth:lw)

        func line(_ a: CGPoint, _ b: CGPoint) {
            var p = Path(); p.move(to:a); p.addLine(to:b)
            ctx.stroke(p, with:.color(color), lineWidth:lw)
        }

        let shoeColor = Color(red:0.92,green:0.35,blue:0.08)

        switch pose {
        case "shoot":
            // Arms raised overhead releasing ball
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx+m*22, y:shoulderY-18))
            line(CGPoint(x:cx+m*22,y:shoulderY-18), CGPoint(x:cx+m*30, y:shoulderY-34))
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx-m*14, y:shoulderY+16))
            // Legs — push-off stance
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*14, y:hipY+16))
            line(CGPoint(x:cx+m*14,y:hipY+16), CGPoint(x:cx+m*10, y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*10, y:hipY+18))
            line(CGPoint(x:cx-m*10,y:hipY+18), CGPoint(x:cx-m*8, y:fy))
            ctx.fill(Path(CGRect(x:cx+m*7, y:fy-5, width:m*14, height:5)), with:.color(shoeColor))
        case "crossover":
            // Low dribble stance, body turned
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx+m*20, y:hipY-8))
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx-m*18, y:shoulderY+18))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*18, y:hipY+18))
            line(CGPoint(x:cx+m*18,y:hipY+18), CGPoint(x:cx+m*12, y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*14, y:hipY+16))
            line(CGPoint(x:cx-m*14,y:hipY+16), CGPoint(x:cx-m*10, y:fy))
            ctx.fill(Path(CGRect(x:cx+m*8, y:fy-5, width:m*14, height:5)), with:.color(shoeColor))
        case "drive":
            // Leaning forward aggressively
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx+m*24, y:shoulderY+10))
            line(CGPoint(x:cx+m*24,y:shoulderY+10), CGPoint(x:cx+m*36, y:shoulderY))
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx-m*12, y:shoulderY+20))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*22, y:hipY+14))
            line(CGPoint(x:cx+m*22,y:hipY+14), CGPoint(x:cx+m*28, y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*8, y:hipY+20))
            line(CGPoint(x:cx-m*8,y:hipY+20), CGPoint(x:cx-m*4, y:fy))
            ctx.fill(Path(CGRect(x:cx+m*22, y:fy-5, width:m*14, height:5)), with:.color(shoeColor))
        case "guard", "defend":
            // Wide defensive stance — arms out
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx+m*26, y:shoulderY+10))
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx-m*26, y:shoulderY+10))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*18, y:hipY+16))
            line(CGPoint(x:cx+m*18,y:hipY+16), CGPoint(x:cx+m*14, y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*18, y:hipY+16))
            line(CGPoint(x:cx-m*18,y:hipY+16), CGPoint(x:cx-m*14, y:fy))
            ctx.fill(Path(CGRect(x:cx+m*10, y:fy-5, width:m*14, height:5)), with:.color(shoeColor))
        case "block":
            // One arm raised to block
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx+m*10, y:shoulderY-28))
            line(CGPoint(x:cx+m*10,y:shoulderY-28), CGPoint(x:cx+m*8, y:shoulderY-44))
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx-m*16, y:shoulderY+18))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*10, y:hipY+18))
            line(CGPoint(x:cx+m*10,y:hipY+18), CGPoint(x:cx+m*8, y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*12, y:hipY+16))
            line(CGPoint(x:cx-m*12,y:hipY+16), CGPoint(x:cx-m*10, y:fy))
        default:
            // Idle — slight bob dribble ready stance
            let bob = CGFloat(sin(t * 1.6)) * 1.5
            line(CGPoint(x:cx,y:shoulderY+4+bob), CGPoint(x:cx+m*18*sinC, y:hipY-6+bob))
            line(CGPoint(x:cx,y:shoulderY+4+bob), CGPoint(x:cx-m*16*sinC, y:shoulderY+18+bob))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*12, y:hipY+18))
            line(CGPoint(x:cx+m*12,y:hipY+18), CGPoint(x:cx+m*8, y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*10, y:hipY+16))
            line(CGPoint(x:cx-m*10,y:hipY+16), CGPoint(x:cx-m*8, y:fy))
            ctx.fill(Path(CGRect(x:cx+m*5, y:fy-5, width:m*12, height:5)), with:.color(shoeColor))
        }
    }
}

// MARK: - Main View

struct BasketballH2HGameView: View {
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var phase: H2HPhase = .ready
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var shotClock: Int = 24
    @State private var shotClockTask: Task<Void, Never>?
    @State private var opponentTask: Task<Void, Never>?
    @State private var comboCount: Int = 0
    @State private var comboMultiplier: Int = 1
    @State private var lastShotResult: ShotResult?
    @State private var showShotLabel: Bool = false
    @State private var possession: H2HPossession = .player
    @State private var shardsRewarded: Bool = false

    // Canvas state
    @State private var shotProgress: Double = -1   // -1 = no shot, 0→1 = arc
    @State private var shotMade: Bool = false
    @State private var shotAnimTask: Task<Void, Never>?
    @State private var playerPose: String = "idle"
    @State private var opponentPose: String = "guard"
    @State private var rimShake: Double = 0
    @State private var screenShake: CGFloat = 0

    // Haptics
    private let impactMed = UIImpactFeedbackGenerator(style: .medium)
    private let impactHvy = UIImpactFeedbackGenerator(style: .heavy)
    private let notif = UINotificationFeedbackGenerator()

    private let winTarget = 21
    private let accentColor = Color(red: 1.0, green: 0.60, blue: 0.0)

    private var aiShotChance: Double {
        0.25 + (viewModel.effectiveMetrics.prqScore / 100.0) * 0.47
    }
    private var aiDelayLow: Double { 3.0 + (1 - viewModel.effectiveMetrics.prqScore/100)*2.0 }
    private var aiDelayHigh: Double { aiDelayLow + 1.5 }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red:0.04,green:0.04,blue:0.10).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(title:"Street 1v1", subtitle:"First to 21 · Your court, your rules",
                               countdown:3, accentColor:accentColor, onComplete:{ startGame() })
            case .playing:
                playingBody.offset(x: screenShake)
            case .result:
                resultScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { cancelAllTasks(); dismiss() } label: {
                    HStack(spacing:4) {
                        Image(systemName:"chevron.left").font(.system(size:14,weight:.bold))
                        Text("EXIT").font(.system(.caption,design:.monospaced,weight:.bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for:.navigationBar)
        .onDisappear { cancelAllTasks() }
    }

    // MARK: - Playing Body

    private var playingBody: some View {
        VStack(spacing: 0) {
            scoreHeader
                .padding(.horizontal, 20)
                .padding(.top, 8)

            shotClockBar
                .padding(.horizontal, 20)
                .padding(.top, 6)

            // Canvas court — fills most of screen
            StreetCourtCanvas(
                possession: possession,
                shotProgress: shotProgress,
                shotMade: shotMade,
                playerPose: playerPose,
                opponentPose: opponentPose,
                rimShake: rimShake
            )
            .frame(maxWidth:.infinity, maxHeight:.infinity)
            .clipShape(RoundedRectangle(cornerRadius:16))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .overlay(alignment:.center) {
                if showShotLabel, let result = lastShotResult {
                    Text(result.rawValue)
                        .font(.system(size:30,weight:.black,design:.monospaced))
                        .italic()
                        .foregroundStyle(result == .made ? accentColor : (result == .blocked ? .red : .secondary))
                        .shadow(color:(result == .made ? accentColor : .red).opacity(0.7), radius:16)
                        .transition(.asymmetric(insertion:.scale(scale:0.5).combined(with:.opacity),
                                                removal:.opacity))
                        .animation(.spring(response:0.22, dampingFraction:0.5), value:showShotLabel)
                }
            }

            comboRow
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            inputPanel
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        HStack(alignment: .top) {
            VStack(spacing:2) {
                Text("YOU").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(accentColor).tracking(2)
                Text("\(playerScore)").font(.system(size:52,weight:.black,design:.monospaced)).foregroundStyle(.white).contentTransition(.numericText())
            }.frame(maxWidth:.infinity, alignment:.leading)

            VStack(spacing:4) {
                HStack(spacing:6) {
                    Image(systemName: possession == .player ? "arrowtriangle.right.fill" : "arrowtriangle.left.fill")
                        .foregroundStyle(possession == .player ? accentColor : .red)
                    Text(possession == .player ? "YOUR BALL" : "OPP BALL")
                        .font(.system(size:9,weight:.black,design:.monospaced))
                        .foregroundStyle(possession == .player ? accentColor : .red)
                }
                Text("TO 21").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(1)
            }.frame(maxWidth:.infinity)

            VStack(spacing:2) {
                Text("OPP").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(opponentScore)").font(.system(size:52,weight:.black,design:.monospaced)).foregroundStyle(.white.opacity(0.45)).contentTransition(.numericText())
            }.frame(maxWidth:.infinity, alignment:.trailing)
        }
    }

    // MARK: - Shot Clock Bar

    private var shotClockBar: some View {
        GeometryReader { geo in
            HStack(spacing:10) {
                Text("SHOT").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2).frame(width:32)
                ZStack(alignment:.leading) {
                    RoundedRectangle(cornerRadius:3).fill(Color.white.opacity(0.08)).frame(height:6)
                    let bw = max(0, geo.size.width - 72)
                    RoundedRectangle(cornerRadius:3)
                        .fill(shotClock > 8 ? accentColor : .red)
                        .frame(width:CGFloat(shotClock)/24.0*bw, height:6)
                        .animation(.linear(duration:0.5), value:shotClock)
                }
                Text("\(shotClock)").font(.system(size:13,weight:.black,design:.monospaced))
                    .foregroundStyle(shotClock > 8 ? .white : .red).contentTransition(.numericText()).frame(width:24,alignment:.trailing)
            }
        }.frame(height:22)
    }

    // MARK: - Combo Row

    private var comboRow: some View {
        Group {
            if comboCount >= 2 {
                HStack(spacing:6) {
                    Image(systemName:"flame.fill").font(.system(size:12)).foregroundStyle(.orange)
                    Text("x\(comboMultiplier) COMBO").font(.system(size:11,weight:.black,design:.monospaced)).foregroundStyle(.orange)
                    Text("(\(comboCount) makes)").font(.system(size:9,design:.monospaced)).foregroundStyle(.orange.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal,12).padding(.vertical,6)
                .background(Color.orange.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius:10).stroke(Color.orange.opacity(0.3),lineWidth:1))
                .clipShape(.rect(cornerRadius:10))
                .transition(.scale.combined(with:.opacity))
            } else {
                HStack(spacing:4) {
                    Image(systemName:"basketball.fill").font(.system(size:11)).foregroundStyle(accentColor.opacity(0.4))
                    Text("TAP SHOOT · CROSSOVER · DRIVE").font(.system(size:8,weight:.bold,design:.monospaced)).foregroundStyle(.secondary).tracking(1)
                }
            }
        }
        .frame(height:32)
        .animation(.spring(response:0.3), value:comboCount)
    }

    // MARK: - Input Panel

    private var inputPanel: some View {
        VStack(spacing:12) {
            Button {
                guard phase == .playing, possession == .player, shotProgress < 0 else { return }
                playerAttemptShoot()
            } label: {
                HStack(spacing:10) {
                    Image(systemName:"basketball.fill").font(.system(size:18,weight:.bold))
                    Text("SHOOT").font(.system(size:18,weight:.black,design:.monospaced))
                }
                .foregroundStyle(.black).frame(maxWidth:.infinity).padding(.vertical,18)
                .background(possession == .player && phase == .playing && shotProgress < 0
                    ? LinearGradient(colors:[accentColor,accentColor.opacity(0.75)],startPoint:.top,endPoint:.bottom)
                    : LinearGradient(colors:[Color.white.opacity(0.15),Color.white.opacity(0.08)],startPoint:.top,endPoint:.bottom))
                .clipShape(.rect(cornerRadius:16))
                .shadow(color:possession == .player ? accentColor.opacity(0.35) : .clear, radius:12)
            }
            .disabled(possession != .player || phase != .playing || shotProgress >= 0)

            HStack(spacing:12) {
                actionButton(label:"CROSSOVER", icon:"arrow.left.and.right") { playerAttemptMove(action:"CROSSOVER") }
                actionButton(label:"DRIVE", icon:"figure.run") { playerAttemptMove(action:"DRIVE") }
            }
        }
    }

    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing:4) {
                Image(systemName:icon).font(.system(size:14,weight:.bold))
                Text(label).font(.system(size:10,weight:.black,design:.monospaced))
            }
            .foregroundStyle(possession == .player ? accentColor : .secondary)
            .frame(maxWidth:.infinity).padding(.vertical,14)
            .background(accentColor.opacity(possession == .player ? 0.08 : 0.03))
            .overlay(RoundedRectangle(cornerRadius:14).stroke(accentColor.opacity(possession == .player ? 0.25 : 0.08),lineWidth:1))
            .clipShape(.rect(cornerRadius:14))
        }
        .disabled(possession != .player || phase != .playing || shotProgress >= 0)
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        let playerWon = playerScore >= winTarget
        let didTie = !playerWon && opponentScore < winTarget
        let winner: ResultScreen.ResultWinner = playerWon ? .p1 : (didTie ? .draw : .p2)
        let prqGain = PRQ.modeReward(mode:.basketballHeadToHead, won:playerWon, tied:didTie,
                                      combo:comboCount, criticals:comboCount/3,
                                      scoreDifferential:playerScore-opponentScore)
        return ResultScreen(winner:winner, p1Score:playerScore, p2Score:opponentScore,
                            title:"Street 1v1", accentColor:accentColor, prqGain:prqGain,
                            prqCurrent:viewModel.effectiveMetrics.prqScore,
                            modeAttributeLabel:"Court IQ",
                            modeAttributeValue:PRQ.attributeValue(prq:viewModel.effectiveMetrics.prqScore,
                                                                   for:.basketballHeadToHead)) {
            if !shardsRewarded {
                viewModel.profile.evolutionShards += playerWon ? 50 : (didTie ? 25 : 15)
                SaveSystem.saveProfile(viewModel.profile)
                shardsRewarded = true
            }
            dismiss()
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        playerScore = 0; opponentScore = 0; comboCount = 0; comboMultiplier = 1
        possession = .player; lastShotResult = nil; showShotLabel = false
        shotMade = false; shotProgress = -1; shardsRewarded = false
        playerPose = "idle"; opponentPose = "guard"
        phase = .playing
        resetShotClock()
        scheduleOpponentShot()
    }

    private func playerAttemptShoot() {
        guard phase == .playing, possession == .player, shotProgress < 0 else { return }
        shotClockTask?.cancel()
        playerPose = "shoot"
        opponentPose = "block"
        impactMed.impactOccurred()

        let prq = viewModel.effectiveMetrics.prqScore
        let hitChance = min(0.85, 0.45 + (prq/100)*0.30 + Double(comboCount)*0.02)
        let made = Double.random(in:0...1) < hitChance

        // Animate shot arc then resolve
        shotAnimTask?.cancel()
        shotAnimTask = Task {
            // Run arc: 36 steps at 14ms = ~500ms flight
            await MainActor.run { shotProgress = 0 }
            let steps = 36
            for step in 0..<steps {
                try? await Task.sleep(for:.milliseconds(14))
                guard !Task.isCancelled else { return }
                await MainActor.run { shotProgress = Double(step+1)/Double(steps) }
            }
            await MainActor.run {
                shotProgress = -1
                shotMade = made
                playerPose = "idle"
                opponentPose = "guard"

                if made {
                    comboCount += 1; comboMultiplier = min(4, 1 + comboCount/3)
                    let pts = 2 * comboMultiplier
                    withAnimation(.spring(response:0.3)) { playerScore = min(playerScore+pts,99) }
                    flashShotResult(.made)
                    triggerRimShake(intensity: 1.0)
                    notif.notificationOccurred(.success)
                    impactHvy.impactOccurred()
                } else {
                    comboCount = 0; comboMultiplier = 1
                    flashShotResult(.miss)
                    triggerRimShake(intensity: 0.5)
                    impactMed.impactOccurred()
                }

                possession = .opponent; resetShotClock()
                if playerScore >= winTarget { endGame(); return }
                scheduleOpponentShot()
            }
        }
    }

    private func playerAttemptMove(action: String) {
        guard phase == .playing, possession == .player, shotProgress < 0 else { return }
        playerPose = action == "CROSSOVER" ? "crossover" : "drive"
        impactMed.impactOccurred()
        let succeeded = Double.random(in:0...1) < 0.65

        Task {
            try? await Task.sleep(for:.milliseconds(400))
            await MainActor.run {
                playerPose = "idle"
                if !succeeded {
                    flashShotResult(.blocked)
                    possession = .opponent; comboCount = 0; comboMultiplier = 1
                    opponentPose = "guard"; resetShotClock(); scheduleOpponentShot()
                }
            }
        }
    }

    private func flashShotResult(_ result: ShotResult) {
        lastShotResult = result
        withAnimation(.spring(response:0.2)) { showShotLabel = true }
        Task {
            try? await Task.sleep(for:.milliseconds(900))
            await MainActor.run { withAnimation(.easeOut(duration:0.3)) { showShotLabel = false } }
        }
    }

    private func triggerRimShake(intensity: Double) {
        rimShake = intensity
        Task {
            try? await Task.sleep(for:.milliseconds(500))
            await MainActor.run { withAnimation(.spring(response:0.3)) { rimShake = 0 } }
        }
    }

    private func scheduleOpponentShot() {
        opponentTask?.cancel()
        guard phase == .playing else { return }
        let delay = Double.random(in:aiDelayLow...aiDelayHigh)
        opponentTask = Task {
            try? await Task.sleep(for:.seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase == .playing else { return }
                opponentPose = "shoot"
                let made = Double.random(in:0...1) < aiShotChance
                if made {
                    withAnimation(.spring(response:0.3)) { opponentScore = min(opponentScore+2,99) }
                    triggerRimShake(intensity: 0.6)
                    flashScreenShakeFX()
                }
                Task {
                    try? await Task.sleep(for:.milliseconds(350))
                    await MainActor.run { opponentPose = "guard" }
                }
                possession = .player; resetShotClock()
                if opponentScore >= winTarget { endGame() }
            }
        }
    }

    private func resetShotClock() {
        shotClockTask?.cancel(); shotClock = 24
        shotClockTask = Task {
            while shotClock > 0 {
                try? await Task.sleep(for:.seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { shotClock -= 1 }
            }
            await MainActor.run { shotClockViolation() }
        }
    }

    private func shotClockViolation() {
        guard phase == .playing else { return }
        if possession == .player { comboCount = 0; comboMultiplier = 1; possession = .opponent; scheduleOpponentShot() }
        else { possession = .player }
        resetShotClock()
    }

    private func flashScreenShakeFX() {
        withAnimation(.easeOut(duration:0.06)) { screenShake = 5 }
        Task {
            try? await Task.sleep(for:.milliseconds(80))
            await MainActor.run { withAnimation(.spring(response:0.2,dampingFraction:0.4)) { screenShake = 0 } }
        }
    }

    private func endGame() {
        cancelAllTasks()
        withAnimation(.spring(response:0.4)) { phase = .result }
    }

    private func cancelAllTasks() {
        shotClockTask?.cancel(); opponentTask?.cancel()
        shotAnimTask?.cancel()
        shotClockTask = nil; opponentTask = nil; shotAnimTask = nil
    }
}
