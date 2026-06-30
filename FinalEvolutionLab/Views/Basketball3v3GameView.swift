import SwiftUI

// MARK: - Types

private enum v3Phase { case ready, playing, result }
private enum v3ShotResult: String { case score = "SCORE!", blocked = "BLOCKED", miss = "MISS", assist = "ASSIST" }
private enum v3Team { case player, opponent }

// MARK: - 3v3 Court Canvas

private struct Court3v3Canvas: View {
    let possession: v3Team
    let activePasser: Int       // 0=YOU, 1=Dre, 2=Kev
    let shotProgress: Double    // -1=none, 0→1=arc
    let passProgress: Double    // -1=none, 0→1=pass arc
    let passFromIdx: Int; let passToIdx: Int
    let playerPoses: [String]; let opponentPoses: [String]
    let rimShake: Double

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = Draw3v3(size: size, t: t, possession: possession,
                                activePasser: activePasser,
                                shotProgress: shotProgress, passProgress: passProgress,
                                passFromIdx: passFromIdx, passToIdx: passToIdx,
                                playerPoses: playerPoses, opponentPoses: opponentPoses,
                                rimShake: rimShake)
                d.render(into: &ctx)
            }
        }
    }
}

private struct Draw3v3 {
    let W: CGFloat, H: CGFloat, t: Double
    let possession: v3Team
    let activePasser: Int
    let shotProgress: Double, passProgress: Double
    let passFromIdx: Int, passToIdx: Int
    let playerPoses: [String], opponentPoses: [String]
    let rimShake: Double

    var floorY: CGFloat { H * 0.70 }
    var rimY: CGFloat { H * 0.35 + CGFloat(rimShake) * 4 * CGFloat(sin(t * 48)) }
    var rimX: CGFloat { W * 0.84 }
    // Player team x positions (index 0=YOU, 1=Dre, 2=Kev)
    var playerXs: [CGFloat] { [W*0.21, W*0.10, W*0.33] }
    // Opponent x positions (spread across right half)
    var oppXs: [CGFloat] { [W*0.60, W*0.70, W*0.80] }

    init(size: CGSize, t: Double, possession: v3Team, activePasser: Int,
         shotProgress: Double, passProgress: Double, passFromIdx: Int, passToIdx: Int,
         playerPoses: [String], opponentPoses: [String], rimShake: Double) {
        W = size.width; H = size.height; self.t = t
        self.possession = possession; self.activePasser = activePasser
        self.shotProgress = shotProgress; self.passProgress = passProgress
        self.passFromIdx = passFromIdx; self.passToIdx = passToIdx
        self.playerPoses = playerPoses; self.opponentPoses = opponentPoses
        self.rimShake = rimShake
    }

    mutating func render(into ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawSpectators(ctx: &ctx)
        drawCourt(ctx: &ctx)
        drawBasket(ctx: &ctx)
        drawShadows(ctx: &ctx)
        // Draw all opponent stick figures
        for i in 0..<3 {
            let pose = i < opponentPoses.count ? opponentPoses[i] : "guard"
            drawFigure(ctx: &ctx, cx: oppXs[i], fy: floorY, pose: pose,
                       color: Color(red:1.0,green:0.25,blue:0.25), flip: true)
        }
        // Draw all player team stick figures
        for i in 0..<3 {
            let pose = i < playerPoses.count ? playerPoses[i] : "idle"
            let isActive = possession == .player && activePasser == i
            let col: Color = isActive
                ? Color(red:0.10,green:0.92,blue:0.45)
                : Color(red:0.18,green:0.78,blue:1.0)
            drawFigure(ctx: &ctx, cx: playerXs[i], fy: floorY, pose: pose, color: col, flip: false)
        }
        // Ball animations
        if passProgress >= 0 { drawPassArc(ctx: &ctx) }
        else if shotProgress >= 0 { drawShotArc(ctx: &ctx) }
        else { drawDribble(ctx: &ctx) }
    }

    // MARK: Sky
    private func drawSky(ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(origin:.zero, size:CGSize(width:W, height:H))),
                 with:.color(Color(red:0.03,green:0.04,blue:0.09)))
        // Two streetlight cones
        for cx in [rimX + 8, W * 0.18] as [CGFloat] {
            var cone = Path()
            cone.move(to: CGPoint(x:cx, y:0))
            cone.addLine(to: CGPoint(x:cx+55, y:floorY))
            cone.addLine(to: CGPoint(x:cx-35, y:floorY))
            cone.closeSubpath()
            ctx.fill(cone, with:.color(Color(red:1.0,green:0.85,blue:0.4).opacity(0.05)))
        }
        // Stars
        for i in 0..<18 {
            let sx = W * CGFloat((i * 139 % 100)) / 100.0
            let sy = H * 0.36 * CGFloat((i * 67 % 100)) / 100.0
            ctx.fill(Path(ellipseIn: CGRect(x:sx-1,y:sy-1,width:2,height:2)),
                     with:.color(Color.white.opacity(0.2 + 0.2*sin(t*0.4+Double(i)))))
        }
    }

    // MARK: Spectators (behind the fence)
    private func drawSpectators(ctx: inout GraphicsContext) {
        let jerseyColors: [Color] = [.green, .blue, .yellow, .red, .white, .orange, .purple]
        for row in 0..<2 {
            let ry = floorY - H * (0.24 - CGFloat(row)*0.06)
            let count = 10 + row * 4
            for i in 0..<count {
                let sx = W * (CGFloat(i) + 0.5) / CGFloat(count)
                let bob = CGFloat(sin(t * 2.0 + Double(i) * 0.6)) * 3.0
                let r: CGFloat = 4.0 + CGFloat(row)
                let jc = jerseyColors[(i * 3 + row * 5) % jerseyColors.count]
                ctx.fill(Path(ellipseIn: CGRect(x:sx-r*0.9, y:ry-bob-r*1.8, width:r*1.8, height:r*1.8)),
                         with:.color(Color(red:0.88,green:0.72,blue:0.58).opacity(0.5)))
                ctx.fill(Path(CGRect(x:sx-r*0.8, y:ry-bob, width:r*1.6, height:r*1.8)),
                         with:.color(jc.opacity(0.4 + Double(row)*0.08)))
            }
        }
    }

    // MARK: Court
    private func drawCourt(ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x:0, y:floorY, width:W, height:H-floorY)),
                 with:.color(Color(red:0.14,green:0.14,blue:0.17)))
        // Floor line
        var fl = Path(); fl.move(to: CGPoint(x:0,y:floorY)); fl.addLine(to: CGPoint(x:W,y:floorY))
        ctx.stroke(fl, with:.color(Color.white.opacity(0.28)), lineWidth:1.8)
        // Painted key
        ctx.fill(Path(CGRect(x:W*0.44, y:floorY, width:W*0.42, height:H*0.28)),
                 with:.color(Color(red:0.10,green:0.55,blue:0.25).opacity(0.18)))
        ctx.stroke(Path(CGRect(x:W*0.44, y:floorY, width:W*0.42, height:H*0.28)),
                   with:.color(Color.white.opacity(0.12)), lineWidth:0.8)
        // 3-point arc
        var arc = Path()
        arc.addArc(center: CGPoint(x:rimX,y:floorY), radius:W*0.52,
                   startAngle:.degrees(180), endAngle:.degrees(270), clockwise:false)
        ctx.stroke(arc, with:.color(Color.white.opacity(0.16)), lineWidth:1.0)
        // Free throw arc
        var ftArc = Path()
        ftArc.addArc(center: CGPoint(x:W*0.65,y:floorY), radius:W*0.11,
                     startAngle:.degrees(180), endAngle:.degrees(360), clockwise:false)
        ctx.stroke(ftArc, with:.color(Color.white.opacity(0.10)), lineWidth:0.7)
        // Floor glow
        ctx.fill(Path(ellipseIn: CGRect(x:rimX-28, y:floorY, width:56, height:12)),
                 with:.color(Color.orange.opacity(0.10)))
    }

    // MARK: Basket
    private func drawBasket(ctx: inout GraphicsContext) {
        let bbX = rimX + 4
        var pole = Path(); pole.move(to: CGPoint(x:bbX+4,y:floorY)); pole.addLine(to: CGPoint(x:bbX+4,y:rimY-52))
        ctx.stroke(pole, with:.color(Color.white.opacity(0.22)), lineWidth:3)
        let bbRect = CGRect(x:bbX, y:rimY-52, width:10, height:44)
        ctx.fill(Path(bbRect), with:.color(Color(red:0.80,green:0.85,blue:0.90).opacity(0.65)))
        ctx.stroke(Path(bbRect), with:.color(Color.white.opacity(0.5)), lineWidth:1)
        ctx.stroke(Path(CGRect(x:bbX-1,y:rimY-34,width:12,height:14)),
                   with:.color(Color.red.opacity(0.5)), lineWidth:1)
        let rl = rimX - 16; let rr = rimX + 2
        var rim = Path(); rim.move(to: CGPoint(x:rl,y:rimY)); rim.addLine(to: CGPoint(x:rr,y:rimY))
        var gc = ctx; gc.addFilter(.shadow(color:Color.orange.opacity(0.8),radius:5))
        gc.stroke(rim, with:.color(Color.orange), lineWidth:4)
        for i in 0...5 {
            let tf = CGFloat(i)/5.0
            let nx = rl+(rr-rl)*tf; let ny = rimY+18*(1+abs(tf-0.5)*0.4)
            var s = Path(); s.move(to:CGPoint(x:nx,y:rimY)); s.addLine(to:CGPoint(x:nx+(0.5-tf)*3,y:ny))
            ctx.stroke(s, with:.color(Color.white.opacity(0.20)), lineWidth:0.8)
        }
    }

    // MARK: Ground shadows
    private func drawShadows(ctx: inout GraphicsContext) {
        for cx in playerXs + oppXs {
            ctx.fill(Path(ellipseIn: CGRect(x:cx-16,y:floorY+2,width:32,height:6)),
                     with:.color(Color.black.opacity(0.28)))
        }
    }

    // MARK: Stick Figure
    private func drawFigure(ctx: inout GraphicsContext, cx: CGFloat, fy: CGFloat,
                             pose: String, color: Color, flip: Bool) {
        let sc: CGFloat = H * 0.0026  // slightly smaller than H2H to fit 3 players
        let m: CGFloat = flip ? -1 : 1
        let headR = sc * 9; let bodyH = sc * 26; let lw: CGFloat = 3.2
        let shoulderY = fy - bodyH - headR*1.8; let hipY = shoulderY + bodyH
        let cycle = t.truncatingRemainder(dividingBy:0.55)/0.55
        let sinC = CGFloat(sin(cycle * .pi * 2))
        let shoeColor = Color(red:0.90,green:0.32,blue:0.08)

        ctx.fill(Path(ellipseIn: CGRect(x:cx-headR,y:shoulderY-headR*1.8,width:headR*2,height:headR*2)),
                 with:.color(Color(red:0.94,green:0.81,blue:0.70)))
        var spine = Path(); spine.move(to:CGPoint(x:cx,y:shoulderY)); spine.addLine(to:CGPoint(x:cx,y:hipY))
        ctx.stroke(spine, with:.color(color), lineWidth:lw)

        func line(_ a: CGPoint, _ b: CGPoint) {
            var p = Path(); p.move(to:a); p.addLine(to:b); ctx.stroke(p, with:.color(color), lineWidth:lw)
        }

        switch pose {
        case "shoot":
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx+m*20,y:shoulderY-16))
            line(CGPoint(x:cx+m*20,y:shoulderY-16), CGPoint(x:cx+m*28,y:shoulderY-32))
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx-m*12,y:shoulderY+14))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*12,y:hipY+16))
            line(CGPoint(x:cx+m*12,y:hipY+16), CGPoint(x:cx+m*9,y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*10,y:hipY+16))
            line(CGPoint(x:cx-m*10,y:hipY+16), CGPoint(x:cx-m*8,y:fy))
            ctx.fill(Path(CGRect(x:cx+m*6,y:fy-5,width:m*12,height:5)), with:.color(shoeColor))
        case "pass":
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx+m*28,y:shoulderY+2))
            line(CGPoint(x:cx+m*28,y:shoulderY+2), CGPoint(x:cx+m*36,y:shoulderY+10))
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx-m*12,y:shoulderY+18))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*10,y:hipY+16))
            line(CGPoint(x:cx+m*10,y:hipY+16), CGPoint(x:cx+m*8,y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*8,y:hipY+14))
            line(CGPoint(x:cx-m*8,y:hipY+14), CGPoint(x:cx-m*6,y:fy))
        case "guard", "defend":
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx+m*24,y:shoulderY+10))
            line(CGPoint(x:cx,y:shoulderY+4), CGPoint(x:cx-m*24,y:shoulderY+10))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*16,y:hipY+16))
            line(CGPoint(x:cx+m*16,y:hipY+16), CGPoint(x:cx+m*12,y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*16,y:hipY+16))
            line(CGPoint(x:cx-m*16,y:hipY+16), CGPoint(x:cx-m*12,y:fy))
        default:
            let bob = CGFloat(sin(t*1.5))*1.2
            line(CGPoint(x:cx,y:shoulderY+4+bob), CGPoint(x:cx+m*16*sinC,y:hipY-4+bob))
            line(CGPoint(x:cx,y:shoulderY+4+bob), CGPoint(x:cx-m*14*sinC,y:shoulderY+16+bob))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx+m*10,y:hipY+16))
            line(CGPoint(x:cx+m*10,y:hipY+16), CGPoint(x:cx+m*8,y:fy))
            line(CGPoint(x:cx,y:hipY), CGPoint(x:cx-m*10,y:hipY+16))
            line(CGPoint(x:cx-m*10,y:hipY+16), CGPoint(x:cx-m*8,y:fy))
            ctx.fill(Path(CGRect(x:cx+m*5,y:fy-5,width:m*11,height:5)), with:.color(shoeColor))
        }
    }

    // MARK: Dribble
    private func drawDribble(ctx: inout GraphicsContext) {
        guard possession == .player else {
            // Opponent has ball — show at middle opponent
            let cx = oppXs[1] - 12; let br: CGFloat = 6
            let bounce = abs(sin(t * .pi / 0.40)) * 16
            let by = floorY - CGFloat(bounce) - 5
            var bc = ctx; bc.addFilter(.shadow(color:Color.orange.opacity(0.4),radius:3))
            bc.fill(Path(ellipseIn:CGRect(x:cx-br,y:by-br,width:br*2,height:br*2)), with:.color(Color.orange))
            return
        }
        let cx = playerXs[activePasser] + 12; let br: CGFloat = 6
        let bounce = abs(sin(t * .pi / 0.40)) * 16
        let by = floorY - CGFloat(bounce) - 5
        var bc = ctx; bc.addFilter(.shadow(color:Color.orange.opacity(0.4),radius:3))
        bc.fill(Path(ellipseIn:CGRect(x:cx-br,y:by-br,width:br*2,height:br*2)), with:.color(Color.orange))
        var seam = Path()
        seam.addArc(center:CGPoint(x:cx,y:by), radius:br*0.75, startAngle:.degrees(-50), endAngle:.degrees(190), clockwise:false)
        ctx.stroke(seam, with:.color(Color.black.opacity(0.28)), lineWidth:0.9)
    }

    // MARK: Pass Arc (between teammates)
    private func drawPassArc(ctx: inout GraphicsContext) {
        guard passFromIdx < playerXs.count, passToIdx < playerXs.count else { return }
        let ep = CGFloat(passProgress)
        let sx = playerXs[passFromIdx] + 12; let sy = floorY - 32
        let ex = playerXs[passToIdx] + 12;   let ey = floorY - 32
        let br: CGFloat = 6
        let bx = sx + (ex-sx)*ep
        let by = sy + (ey-sy)*ep - H*0.10*4*ep*(1-ep)  // low arc for a pass
        // Trail
        for trail in 1...2 {
            let pastEp = max(0, ep - CGFloat(trail)*0.08)
            let tbx = sx+(ex-sx)*pastEp; let tby = sy+(ey-sy)*pastEp - H*0.10*4*pastEp*(1-pastEp)
            ctx.fill(Path(ellipseIn:CGRect(x:tbx-br,y:tby-br,width:br*2,height:br*2)),
                     with:.color(Color.orange.opacity(0.18 - Double(trail)*0.06)))
        }
        var bc = ctx; bc.addFilter(.shadow(color:Color.orange.opacity(0.5),radius:3))
        bc.fill(Path(ellipseIn:CGRect(x:bx-br,y:by-br,width:br*2,height:br*2)), with:.color(Color.orange))
    }

    // MARK: Shot Arc (player to basket)
    private func drawShotArc(ctx: inout GraphicsContext) {
        let ep = CGFloat(shotProgress)
        let sx = playerXs[activePasser] + 12; let sy = floorY - 50
        let ex = (rimX-14+rimX+2)/2; let ey = rimY - 5
        let br: CGFloat = 6.5
        let bx = sx+(ex-sx)*ep
        let by = sy+(ey-sy)*ep - H*0.30*4*ep*(1-ep)

        for trail in 1...3 {
            let pastEp = max(0, ep-CGFloat(trail)*0.07)
            let tbx = sx+(ex-sx)*pastEp; let tby = sy+(ey-sy)*pastEp - H*0.30*4*pastEp*(1-pastEp)
            ctx.fill(Path(ellipseIn:CGRect(x:tbx-br,y:tby-br,width:br*2,height:br*2)),
                     with:.color(Color.orange.opacity(0.20-Double(trail)*0.05)))
        }
        var bc = ctx; bc.addFilter(.shadow(color:Color.orange.opacity(0.6),radius:4))
        bc.fill(Path(ellipseIn:CGRect(x:bx-br,y:by-br,width:br*2,height:br*2)), with:.color(Color.orange))
        var seam = Path()
        seam.addArc(center:CGPoint(x:bx,y:by),radius:br*0.75,startAngle:.degrees(-50),endAngle:.degrees(190),clockwise:false)
        ctx.stroke(seam, with:.color(Color.black.opacity(0.3)), lineWidth:0.9)
        // Rim burst on arrival
        if ep > 0.84 {
            let impF = (ep-0.84)/0.16; let burstR = CGFloat(impF)*22
            var ring = Path(); ring.addEllipse(in:CGRect(x:ex-burstR,y:ey-burstR*0.5,width:burstR*2,height:burstR))
            ctx.stroke(ring, with:.color(Color.orange.opacity(max(0,0.75-impF*0.9))), lineWidth:2)
        }
    }
}

// MARK: - Main View

struct Basketball3v3GameView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var phase: v3Phase = .ready
    @State private var playerTeamScore: Int = 0
    @State private var opponentTeamScore: Int = 0
    @State private var matchClock: Int = 120
    @State private var matchClockTask: Task<Void, Never>?
    @State private var shotClock: Int = 24
    @State private var shotClockTask: Task<Void, Never>?
    @State private var opponentTask: Task<Void, Never>?
    @State private var comboCount: Int = 0
    @State private var comboMultiplier: Int = 1
    @State private var lastResult: v3ShotResult?
    @State private var showResultLabel: Bool = false
    @State private var lastPasser: String = ""
    @State private var possession: v3Team = .player
    @State private var activePasser: Int = 0
    @State private var shardsRewarded: Bool = false

    // Canvas state
    @State private var shotProgress: Double = -1
    @State private var passProgress: Double = -1
    @State private var passFromIdx: Int = 0
    @State private var passToIdx: Int = 1
    @State private var shotAnimTask: Task<Void, Never>?
    @State private var passAnimTask: Task<Void, Never>?
    @State private var playerPoses: [String] = ["idle","idle","idle"]
    @State private var opponentPoses: [String] = ["guard","guard","guard"]
    @State private var rimShake: Double = 0
    @State private var screenShake: CGFloat = 0

    private let impactMed = UIImpactFeedbackGenerator(style:.medium)
    private let impactHvy = UIImpactFeedbackGenerator(style:.heavy)
    private let notif = UINotificationFeedbackGenerator()

    private let targetScore = 15
    private let accentColor = Color(red:0.2,green:0.8,blue:0.4)
    private let teammateNames = ["Dre","Kev"]
    private let opponentNames = ["Ghost","Blaze","Icy"]

    private var aiShotChance: Double { 0.28 + (viewModel.effectiveMetrics.prqScore/100)*0.42 }
    private var aiDelayLow: Double { 2.5 + (1-viewModel.effectiveMetrics.prqScore/100)*2.0 }
    private var aiDelayHigh: Double { aiDelayLow + 1.8 }
    private var formattedClock: String {
        String(format:"%d:%02d", matchClock/60, matchClock%60)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red:0.03,green:0.04,blue:0.09).ignoresSafeArea()
            switch phase {
            case .ready:
                GetReadyScreen(title:"3v3 Streetball", subtitle:"2-min match · First to 15 wins",
                               countdown:3, accentColor:accentColor, onComplete:{ startGame() })
            case .playing:
                playingBody.offset(x:screenShake)
            case .result:
                resultScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement:.topBarLeading) {
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
        VStack(spacing:0) {
            clockHeader.padding(.horizontal,20).padding(.top,8)
            scoreBoard.padding(.horizontal,20).padding(.top,6)

            // Canvas court (main visual)
            Court3v3Canvas(
                possession: possession, activePasser: activePasser,
                shotProgress: shotProgress, passProgress: passProgress,
                passFromIdx: passFromIdx, passToIdx: passToIdx,
                playerPoses: playerPoses, opponentPoses: opponentPoses,
                rimShake: rimShake
            )
            .frame(maxWidth:.infinity, maxHeight:.infinity)
            .clipShape(RoundedRectangle(cornerRadius:16))
            .padding(.horizontal,16).padding(.vertical,6)
            .overlay(alignment:.center) {
                if showResultLabel, let result = lastResult {
                    VStack(spacing:3) {
                        Text(result.rawValue)
                            .font(.system(size:28,weight:.black,design:.monospaced)).italic()
                            .foregroundStyle(result == .score || result == .assist ? accentColor : (result == .blocked ? .red : .secondary))
                            .shadow(color:(result == .score ? accentColor : .red).opacity(0.6), radius:14)
                        if !lastPasser.isEmpty && result == .assist {
                            Text("ASSIST: \(lastPasser)")
                                .font(.system(size:9,weight:.bold,design:.monospaced)).foregroundStyle(accentColor.opacity(0.8))
                        }
                    }
                    .transition(.asymmetric(insertion:.scale(scale:0.5).combined(with:.opacity),removal:.opacity))
                    .animation(.spring(response:0.22,dampingFraction:0.55), value:showResultLabel)
                }
            }

            comboRow.padding(.horizontal,20).padding(.bottom,6)
            inputPanel.padding(.horizontal,20).padding(.bottom,28)
        }
    }

    // MARK: - Clock Header

    private var clockHeader: some View {
        HStack(spacing:12) {
            VStack(spacing:1) {
                Text("MATCH").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2)
                Text(formattedClock).font(.system(size:22,weight:.black,design:.monospaced))
                    .foregroundStyle(matchClock <= 20 ? .red : .white).contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing:6) {
                Image(systemName: possession == .player ? "arrowtriangle.right.fill" : "arrowtriangle.left.fill")
                    .foregroundStyle(possession == .player ? accentColor : .red)
                Text(possession == .player ? "YOUR TEAM" : "OPPONENTS")
                    .font(.system(size:9,weight:.black,design:.monospaced))
                    .foregroundStyle(possession == .player ? accentColor : .red)
            }
            Spacer()
            VStack(spacing:1) {
                Text("SHOT").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(shotClock)").font(.system(size:22,weight:.black,design:.monospaced))
                    .foregroundStyle(shotClock <= 5 ? .red : .white).contentTransition(.numericText())
            }
        }
    }

    // MARK: - Score Board

    private var scoreBoard: some View {
        HStack(spacing:16) {
            VStack(alignment:.leading, spacing:4) {
                Text("YOUR TEAM").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(accentColor).tracking(2)
                Text("\(playerTeamScore)").font(.system(size:44,weight:.black,design:.monospaced)).foregroundStyle(.white).contentTransition(.numericText())
                HStack(spacing:6) {
                    ForEach(0..<3, id:\.self) { idx in
                        let name = idx == 0 ? "YOU" : teammateNames[idx-1]
                        let isActive = possession == .player && activePasser == idx
                        Text(name).font(.system(size:9,weight:isActive ? .black : .medium,design:.monospaced))
                            .foregroundStyle(isActive ? accentColor : .secondary)
                            .padding(.horizontal,5).padding(.vertical,2)
                            .background(isActive ? accentColor.opacity(0.15) : Color.clear)
                            .clipShape(.rect(cornerRadius:5))
                    }
                }
            }.frame(maxWidth:.infinity, alignment:.leading)

            VStack(spacing:2) {
                Text("–").font(.system(size:20,weight:.bold)).foregroundStyle(.tertiary)
                Text("TO 15").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(1)
            }

            VStack(alignment:.trailing, spacing:4) {
                Text("OPPONENTS").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(opponentTeamScore)").font(.system(size:44,weight:.black,design:.monospaced)).foregroundStyle(.white.opacity(0.45)).contentTransition(.numericText())
                HStack(spacing:6) {
                    ForEach(opponentNames, id:\.self) { name in
                        Text(name).font(.system(size:9,weight:.medium,design:.monospaced)).foregroundStyle(.secondary)
                            .padding(.horizontal,5).padding(.vertical,2)
                    }
                }
            }.frame(maxWidth:.infinity, alignment:.trailing)
        }
        .padding(.horizontal,14).padding(.vertical,9)
        .background(RoundedRectangle(cornerRadius:14).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius:14).stroke(Theme.cardBorder,lineWidth:1)))
    }

    // MARK: - Combo Row

    private var comboRow: some View {
        Group {
            if comboCount >= 2 {
                HStack(spacing:6) {
                    Image(systemName:"flame.fill").font(.system(size:12)).foregroundStyle(accentColor)
                    Text("x\(comboMultiplier) HOT STREAK").font(.system(size:11,weight:.black,design:.monospaced)).foregroundStyle(accentColor)
                    Text("(\(comboCount) makes)").font(.system(size:9,design:.monospaced)).foregroundStyle(accentColor.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal,12).padding(.vertical,6)
                .background(accentColor.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius:10).stroke(accentColor.opacity(0.3),lineWidth:1))
                .clipShape(.rect(cornerRadius:10)).transition(.scale.combined(with:.opacity))
            } else {
                HStack(spacing:4) {
                    Image(systemName:"person.3.fill").font(.system(size:11)).foregroundStyle(accentColor.opacity(0.4))
                    Text("SHOOT · PASS DRE · PASS KEV").font(.system(size:8,weight:.bold,design:.monospaced)).foregroundStyle(.secondary).tracking(1)
                }
            }
        }
        .frame(height:32).animation(.spring(response:0.3), value:comboCount)
    }

    // MARK: - Input Panel

    private var inputPanel: some View {
        let active = possession == .player && phase == .playing && shotProgress < 0 && passProgress < 0
        return VStack(spacing:12) {
            Button {
                guard active else { return }
                playerShoot()
            } label: {
                HStack(spacing:10) {
                    Image(systemName:"basketball.fill").font(.system(size:18,weight:.bold))
                    Text("SHOOT").font(.system(size:18,weight:.black,design:.monospaced))
                }
                .foregroundStyle(.black).frame(maxWidth:.infinity).padding(.vertical,18)
                .background(active
                    ? LinearGradient(colors:[accentColor,accentColor.opacity(0.75)],startPoint:.top,endPoint:.bottom)
                    : LinearGradient(colors:[Color.white.opacity(0.15),Color.white.opacity(0.08)],startPoint:.top,endPoint:.bottom))
                .clipShape(.rect(cornerRadius:16))
                .shadow(color:active ? accentColor.opacity(0.35) : .clear, radius:12)
            }.disabled(!active)

            HStack(spacing:12) {
                Button { guard active else { return }; playerPass(to:1) } label: {
                    VStack(spacing:4) {
                        Image(systemName:"arrow.left").font(.system(size:14,weight:.bold))
                        Text("PASS \(teammateNames[0])").font(.system(size:10,weight:.black,design:.monospaced))
                    }
                    .foregroundStyle(active ? accentColor : .secondary)
                    .frame(maxWidth:.infinity).padding(.vertical,14)
                    .background(accentColor.opacity(active ? 0.08 : 0.03))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(accentColor.opacity(active ? 0.25 : 0.08),lineWidth:1))
                    .clipShape(.rect(cornerRadius:14))
                }.disabled(!active)

                Button { guard active else { return }; playerPass(to:2) } label: {
                    VStack(spacing:4) {
                        Image(systemName:"arrow.right").font(.system(size:14,weight:.bold))
                        Text("PASS \(teammateNames[1])").font(.system(size:10,weight:.black,design:.monospaced))
                    }
                    .foregroundStyle(active ? accentColor : .secondary)
                    .frame(maxWidth:.infinity).padding(.vertical,14)
                    .background(accentColor.opacity(active ? 0.08 : 0.03))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(accentColor.opacity(active ? 0.25 : 0.08),lineWidth:1))
                    .clipShape(.rect(cornerRadius:14))
                }.disabled(!active)
            }
        }
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        let playerWon = playerTeamScore > opponentTeamScore
        let didTie = playerTeamScore == opponentTeamScore
        let winner: ResultScreen.ResultWinner = didTie ? .draw : (playerWon ? .p1 : .p2)
        let prqGain = PRQ.modeReward(mode:.basketball3v3, won:playerWon, tied:didTie,
                                      combo:comboCount, criticals:comboCount/3,
                                      scoreDifferential:playerTeamScore-opponentTeamScore)
        return ResultScreen(winner:winner, p1Score:playerTeamScore, p2Score:opponentTeamScore,
                            title:"3v3 Streetball", accentColor:accentColor, prqGain:prqGain,
                            prqCurrent:viewModel.effectiveMetrics.prqScore,
                            modeAttributeLabel:"Court IQ",
                            modeAttributeValue:PRQ.attributeValue(prq:viewModel.effectiveMetrics.prqScore,for:.basketball3v3)) {
            if !shardsRewarded {
                viewModel.profile.evolutionShards += playerWon ? 50 : (didTie ? 25 : 15)
                SaveSystem.saveProfile(viewModel.profile); shardsRewarded = true
            }
            dismiss()
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        playerTeamScore = 0; opponentTeamScore = 0; comboCount = 0; comboMultiplier = 1
        possession = .player; activePasser = 0; matchClock = 120; shotClock = 24
        showResultLabel = false; lastPasser = ""
        shotProgress = -1; passProgress = -1; rimShake = 0
        playerPoses = ["idle","idle","idle"]; opponentPoses = ["guard","guard","guard"]
        shardsRewarded = false; phase = .playing
        startMatchClock(); resetShotClock(); scheduleOpponentAttack()
    }

    private func playerShoot() {
        guard phase == .playing, possession == .player, shotProgress < 0, passProgress < 0 else { return }
        shotClockTask?.cancel()
        let passer = activePasser
        playerPoses[passer] = "shoot"
        impactMed.impactOccurred()

        let hitChance = min(0.85, 0.42 + (viewModel.effectiveMetrics.prqScore/100)*0.32 + Double(comboCount)*0.015)
        let made = Double.random(in:0...1) < hitChance

        shotAnimTask?.cancel()
        shotAnimTask = Task {
            await MainActor.run { shotProgress = 0 }
            for step in 0..<32 {
                try? await Task.sleep(for:.milliseconds(15))
                guard !Task.isCancelled else { return }
                await MainActor.run { shotProgress = Double(step+1)/32.0 }
            }
            await MainActor.run {
                shotProgress = -1; playerPoses[passer] = "idle"
                if made {
                    comboCount += 1; comboMultiplier = min(4,1+comboCount/3)
                    let pts = 2 * comboMultiplier
                    withAnimation(.spring(response:0.3)) { playerTeamScore = min(playerTeamScore+pts,99) }
                    lastPasser = passer != 0 ? teammateNames[passer-1] : ""
                    flashResult(passer != 0 ? .assist : .score)
                    triggerRimShake(1.0); notif.notificationOccurred(.success); impactHvy.impactOccurred()
                } else {
                    comboCount = 0; comboMultiplier = 1; lastPasser = ""; flashResult(.miss)
                    triggerRimShake(0.5); impactMed.impactOccurred()
                }
                possession = .opponent; activePasser = 0; resetShotClock()
                if playerTeamScore >= targetScore { endGame(); return }
                scheduleOpponentAttack()
            }
        }
    }

    private func playerPass(to teammate: Int) {
        guard phase == .playing, possession == .player, shotProgress < 0, passProgress < 0 else { return }
        let from = activePasser
        playerPoses[from] = "pass"
        passFromIdx = from; passToIdx = teammate
        impactMed.impactOccurred()

        let succeeded = Double.random(in:0...1) < 0.78

        passAnimTask?.cancel()
        passAnimTask = Task {
            await MainActor.run { passProgress = 0 }
            for step in 0..<22 {
                try? await Task.sleep(for:.milliseconds(12))
                guard !Task.isCancelled else { return }
                await MainActor.run { passProgress = Double(step+1)/22.0 }
            }
            await MainActor.run {
                passProgress = -1; playerPoses[from] = "idle"
                if succeeded {
                    activePasser = teammate
                    playerPoses[teammate] = "idle"
                    scheduleTeammateShot(from: teammate)
                } else {
                    flashResult(.blocked)
                    possession = .opponent; activePasser = 0; comboCount = 0; comboMultiplier = 1
                    resetShotClock(); scheduleOpponentAttack()
                }
            }
        }
    }

    private func scheduleTeammateShot(from teammate: Int) {
        Task {
            try? await Task.sleep(for:.milliseconds(Int.random(in:800...1400)))
            await MainActor.run {
                guard phase == .playing, possession == .player, activePasser == teammate else { return }
                let made = Double.random(in:0...1) < 0.52
                playerPoses[teammate] = "shoot"

                Task {
                    try? await Task.sleep(for:.milliseconds(500))
                    await MainActor.run {
                        playerPoses[teammate] = "idle"
                        if made {
                            comboCount += 1; comboMultiplier = min(4,1+comboCount/3)
                            withAnimation(.spring(response:0.3)) { playerTeamScore = min(playerTeamScore+2*comboMultiplier,99) }
                            lastPasser = teammateNames[teammate-1]; flashResult(.assist)
                            triggerRimShake(0.8)
                        } else { flashResult(.miss) }
                        possession = .opponent; activePasser = 0; resetShotClock()
                        if playerTeamScore >= targetScore { endGame(); return }
                        scheduleOpponentAttack()
                    }
                }
            }
        }
    }

    private func flashResult(_ result: v3ShotResult) {
        lastResult = result
        withAnimation(.spring(response:0.2)) { showResultLabel = true }
        Task {
            try? await Task.sleep(for:.milliseconds(900))
            await MainActor.run { withAnimation(.easeOut(duration:0.3)) { showResultLabel = false } }
        }
    }

    private func triggerRimShake(_ intensity: Double) {
        rimShake = intensity
        Task {
            try? await Task.sleep(for:.milliseconds(500))
            await MainActor.run { withAnimation(.spring(response:0.3)) { rimShake = 0 } }
        }
    }

    private func scheduleOpponentAttack() {
        opponentTask?.cancel()
        guard phase == .playing else { return }
        let delay = Double.random(in:aiDelayLow...aiDelayHigh)
        opponentTask = Task {
            try? await Task.sleep(for:.seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase == .playing else { return }
                opponentPoses = ["guard","shoot","guard"]
                let made = Double.random(in:0...1) < aiShotChance
                if made {
                    withAnimation(.spring(response:0.3)) { opponentTeamScore = min(opponentTeamScore+2,99) }
                    triggerRimShake(0.6); flashScreenShakeFX()
                }
                Task {
                    try? await Task.sleep(for:.milliseconds(400))
                    await MainActor.run { opponentPoses = ["guard","guard","guard"] }
                }
                possession = .player; activePasser = 0; resetShotClock()
                if opponentTeamScore >= targetScore { endGame() }
            }
        }
    }

    private func startMatchClock() {
        matchClockTask?.cancel()
        matchClockTask = Task {
            while matchClock > 0 {
                try? await Task.sleep(for:.seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { matchClock -= 1 }
            }
            await MainActor.run { if phase == .playing { endGame() } }
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
            await MainActor.run {
                guard phase == .playing else { return }
                if possession == .player { comboCount = 0; comboMultiplier = 1; possession = .opponent; activePasser = 0; scheduleOpponentAttack() }
                else { possession = .player; activePasser = 0 }
                resetShotClock()
            }
        }
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
        matchClockTask?.cancel(); shotAnimTask?.cancel(); passAnimTask?.cancel()
        shotClockTask = nil; opponentTask = nil; matchClockTask = nil
        shotAnimTask = nil; passAnimTask = nil
    }
}
