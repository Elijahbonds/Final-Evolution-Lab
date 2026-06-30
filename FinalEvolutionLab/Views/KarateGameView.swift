import SwiftUI

// MARK: - Pose

private struct StickPose {
    let rElbow: CGPoint; let rWrist: CGPoint
    let lElbow: CGPoint; let lWrist: CGPoint
    let rKnee:  CGPoint; let rAnkle: CGPoint
    let lKnee:  CGPoint; let lAnkle: CGPoint
    let shoulder: CGPoint

    static let idle = StickPose(
        rElbow: CGPoint(x:18,y:-42), rWrist: CGPoint(x:26,y:-26),
        lElbow: CGPoint(x:-18,y:-42), lWrist: CGPoint(x:-26,y:-26),
        rKnee: CGPoint(x:12,y:-20), rAnkle: CGPoint(x:14,y:0),
        lKnee: CGPoint(x:-12,y:-20), lAnkle: CGPoint(x:-14,y:0),
        shoulder: CGPoint(x:0,y:-52))

    static let punch = StickPose(
        rElbow: CGPoint(x:22,y:-50), rWrist: CGPoint(x:42,y:-50),
        lElbow: CGPoint(x:-16,y:-40), lWrist: CGPoint(x:-18,y:-28),
        rKnee: CGPoint(x:14,y:-18), rAnkle: CGPoint(x:18,y:0),
        lKnee: CGPoint(x:-10,y:-22), lAnkle: CGPoint(x:-12,y:0),
        shoulder: CGPoint(x:4,y:-52))

    static let kick = StickPose(
        rElbow: CGPoint(x:16,y:-46), rWrist: CGPoint(x:24,y:-32),
        lElbow: CGPoint(x:-16,y:-46), lWrist: CGPoint(x:-24,y:-32),
        rKnee: CGPoint(x:20,y:-34), rAnkle: CGPoint(x:36,y:-16),
        lKnee: CGPoint(x:-10,y:-22), lAnkle: CGPoint(x:-12,y:0),
        shoulder: CGPoint(x:0,y:-52))

    static let block = StickPose(
        rElbow: CGPoint(x:16,y:-60), rWrist: CGPoint(x:8,y:-72),
        lElbow: CGPoint(x:-16,y:-60), lWrist: CGPoint(x:-8,y:-72),
        rKnee: CGPoint(x:14,y:-18), rAnkle: CGPoint(x:16,y:0),
        lKnee: CGPoint(x:-14,y:-18), lAnkle: CGPoint(x:-16,y:0),
        shoulder: CGPoint(x:0,y:-52))

    static let hit = StickPose(
        rElbow: CGPoint(x:14,y:-36), rWrist: CGPoint(x:10,y:-22),
        lElbow: CGPoint(x:-20,y:-36), lWrist: CGPoint(x:-30,y:-22),
        rKnee: CGPoint(x:10,y:-18), rAnkle: CGPoint(x:8,y:0),
        lKnee: CGPoint(x:-14,y:-18), lAnkle: CGPoint(x:-18,y:0),
        shoulder: CGPoint(x:-6,y:-50))

    static let dragon = StickPose(
        rElbow: CGPoint(x:20,y:-60), rWrist: CGPoint(x:36,y:-78),
        lElbow: CGPoint(x:-20,y:-60), lWrist: CGPoint(x:-36,y:-78),
        rKnee: CGPoint(x:16,y:-26), rAnkle: CGPoint(x:20,y:-2),
        lKnee: CGPoint(x:-16,y:-26), lAnkle: CGPoint(x:-20,y:-2),
        shoulder: CGPoint(x:0,y:-54))

    static func lerp(_ a: StickPose, _ b: StickPose, t: Double) -> StickPose {
        func lp(_ u: CGPoint, _ v: CGPoint) -> CGPoint {
            CGPoint(x: u.x + (v.x-u.x)*t, y: u.y + (v.y-u.y)*t)
        }
        return StickPose(
            rElbow: lp(a.rElbow,b.rElbow), rWrist: lp(a.rWrist,b.rWrist),
            lElbow: lp(a.lElbow,b.lElbow), lWrist: lp(a.lWrist,b.lWrist),
            rKnee: lp(a.rKnee,b.rKnee),   rAnkle: lp(a.rAnkle,b.rAnkle),
            lKnee: lp(a.lKnee,b.lKnee),   lAnkle: lp(a.lAnkle,b.lAnkle),
            shoulder: lp(a.shoulder,b.shoulder))
    }
}

// MARK: - Dojo Canvas

private struct KarateDojo: View {
    let playerPoseName: String    // "idle","punch","kick","block","hit","dragon"
    let opponentPoseName: String
    let crowdAlpha: Double
    let dragonActive: Bool
    var lastHitTime: Double = 0   // absolute time of most recent player hit landing
    var lastHitType: String = ""  // "punch" | "kick" | "dragon"

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = DojoDrawer(size: size, t: t,
                                   playerPose: playerPoseName, opponentPose: opponentPoseName,
                                   crowd: crowdAlpha, dragon: dragonActive,
                                   lastHitTime: lastHitTime, lastHitType: lastHitType)
                d.render(into: &ctx)
            }
        }
    }
}

private struct DojoDrawer {
    let size: CGSize; let t: Double
    let playerPose: String; let opponentPose: String
    let crowd: Double; let dragon: Bool
    let lastHitTime: Double; let lastHitType: String

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var floorY: CGFloat { H * 0.84 }

    mutating func render(into ctx: inout GraphicsContext) {
        drawBg(ctx: &ctx)
        drawFloor(ctx: &ctx)
        drawLanterns(ctx: &ctx)
        if dragon { drawDragonAura(ctx: &ctx) }
        drawFighter(ctx: &ctx, cx: W*0.25, pose: pose(for: playerPose), color: Color(red:0.15,green:0.75,blue:1.0), flip: false)
        drawFighter(ctx: &ctx, cx: W*0.75, pose: pose(for: opponentPose), color: Color(red:1.0,green:0.22,blue:0.22), flip: true)
        drawShadows(ctx: &ctx)
        // Hit sparks at impact point — fires for 0.45s after any landing hit
        let timeSinceHit = t - lastHitTime
        if timeSinceHit < 0.45 && lastHitTime > 0 {
            drawHitSparks(ctx: &ctx, timeSince: timeSinceHit)
        }
    }

    private func pose(for name: String) -> StickPose {
        switch name {
        case "punch":  return StickPose.punch
        case "kick":   return StickPose.kick
        case "block":  return StickPose.block
        case "hit":    return StickPose.hit
        case "dragon": return StickPose.dragon
        default:       return StickPose.idle
        }
    }

    private func drawBg(ctx: inout GraphicsContext) {
        // Gradient sky
        ctx.fill(Path(CGRect(origin:.zero,size:size)), with:.color(Color(red:0.06,green:0.01,blue:0.01)))

        // Shoji screen panels (background wall)
        let panelW: CGFloat = W/5
        for i in 0..<5 {
            let px = CGFloat(i)*panelW
            let panelRect = CGRect(x:px+2, y:H*0.08, width:panelW-4, height:H*0.62)
            ctx.fill(Path(panelRect), with:.color(Color(red:0.10,green:0.06,blue:0.04).opacity(0.85)))
            ctx.stroke(Path(panelRect), with:.color(Color.white.opacity(0.06)), lineWidth:1)
            // Grid lines inside panel
            let cols = 3; let rows = 5
            for c in 1..<cols {
                let gx = px + panelW*CGFloat(c)/CGFloat(cols)
                var gp = Path(); gp.move(to: CGPoint(x:gx,y:H*0.08)); gp.addLine(to: CGPoint(x:gx,y:H*0.70))
                ctx.stroke(gp, with:.color(Color.white.opacity(0.04)), lineWidth:0.5)
            }
            for r in 1..<rows {
                let gy = H*0.08 + (H*0.62)*CGFloat(r)/CGFloat(rows)
                var gp = Path(); gp.move(to: CGPoint(x:px+2,y:gy)); gp.addLine(to: CGPoint(x:px+panelW-2,y:gy))
                ctx.stroke(gp, with:.color(Color.white.opacity(0.04)), lineWidth:0.5)
            }
        }

        // Ambient red glow center (arena energy)
        var glow = Path()
        glow.addEllipse(in: CGRect(x:W*0.25,y:H*0.30,width:W*0.50,height:H*0.45))
        ctx.fill(glow, with:.color(Color(red:0.6,green:0.05,blue:0.0).opacity(0.08)))
    }

    private func drawFloor(ctx: inout GraphicsContext) {
        // Tatami mat — horizontal lines
        for i in 0..<6 {
            let fy = floorY + CGFloat(i)*4
            var p = Path(); p.move(to: CGPoint(x:0,y:fy)); p.addLine(to: CGPoint(x:W,y:fy))
            ctx.stroke(p, with:.color(Color(red:0.55,green:0.42,blue:0.20).opacity(0.18+(Double(i)*0.03))), lineWidth:1.5)
        }
        // Tatami vertical dividers
        for i in 1..<5 {
            let fx = W * CGFloat(i) / 5.0
            var p = Path(); p.move(to: CGPoint(x:fx,y:floorY)); p.addLine(to: CGPoint(x:fx,y:floorY+20))
            ctx.stroke(p, with:.color(Color(red:0.55,green:0.42,blue:0.20).opacity(0.12)), lineWidth:1)
        }
        // Main floor line
        var fl = Path(); fl.move(to: CGPoint(x:0,y:floorY)); fl.addLine(to: CGPoint(x:W,y:floorY))
        ctx.stroke(fl, with:.color(Color(red:0.55,green:0.42,blue:0.20).opacity(0.5)), lineWidth:2)
        // Center line
        var cl = Path(); cl.move(to: CGPoint(x:W/2,y:floorY)); cl.addLine(to: CGPoint(x:W/2,y:floorY+12))
        ctx.stroke(cl, with:.color(Color.white.opacity(0.12)), lineWidth:1)
    }

    private func drawLanterns(ctx: inout GraphicsContext) {
        let positions: [(CGFloat, CGFloat)] = [(W*0.15,H*0.06),(W*0.50,H*0.04),(W*0.85,H*0.06)]
        for (lx, ly) in positions {
            let flicker = 0.85 + sin(t*3.7 + Double(lx))*0.15
            // String
            var str = Path(); str.move(to: CGPoint(x:lx,y:0)); str.addLine(to: CGPoint(x:lx,y:ly))
            ctx.stroke(str, with:.color(Color.white.opacity(0.15)), lineWidth:0.8)
            // Lantern body
            let lw: CGFloat = 18; let lh: CGFloat = 26
            let lr = CGRect(x:lx-lw/2,y:ly,width:lw,height:lh)
            ctx.fill(Path(roundedRect:lr,cornerRadius:4), with:.color(Color(red:1.0,green:0.18,blue:0.05).opacity(0.75*flicker)))
            // Glow
            var gc = ctx; gc.addFilter(.shadow(color:Color.red.opacity(0.4*flicker),radius:8))
            gc.fill(Path(roundedRect:lr,cornerRadius:4), with:.color(Color(red:1.0,green:0.3,blue:0.1).opacity(0.2*flicker)))
            // Rim lines
            for r in [ly+4, ly+lh/2, ly+lh-4] as [CGFloat] {
                var rp = Path(); rp.move(to: CGPoint(x:lx-lw/2+1,y:r)); rp.addLine(to: CGPoint(x:lx+lw/2-1,y:r))
                ctx.stroke(rp, with:.color(Color.white.opacity(0.15)), lineWidth:0.8)
            }
        }
    }

    private func drawDragonAura(ctx: inout GraphicsContext) {
        // Particle burst around player during dragon strike
        let cx = W*0.25; let cy = floorY - 60
        for i in 0..<20 {
            let angle = Double(i)/20.0 * .pi*2 + t*3.0
            let dist  = 30 + sin(t*5.0+Double(i)*0.8)*20
            let px = cx + CGFloat(cos(angle))*CGFloat(dist)
            let py = cy + CGFloat(sin(angle))*CGFloat(dist)
            let alpha = 0.4 + 0.6*abs(sin(t*6.0+Double(i)*0.5))
            var sc = ctx; sc.addFilter(.shadow(color:Color.yellow.opacity(0.6),radius:6))
            sc.fill(Path(ellipseIn:CGRect(x:px-3,y:py-3,width:6,height:6)), with:.color(Color.yellow.opacity(alpha)))
        }
        // Screen veil
        ctx.fill(Path(CGRect(origin:.zero,size:size)), with:.color(Color.yellow.opacity(0.04)))
    }

    private func drawFighter(ctx: inout GraphicsContext, cx: CGFloat, pose: StickPose, color: Color, flip: Bool) {
        let scale: CGFloat = 1.0
        let feetY = floorY - 2
        let mirror: CGFloat = flip ? -1 : 1

        func pt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: cx + p.x * scale * mirror, y: feetY + p.y * scale)
        }
        func line(_ a: CGPoint, _ b: CGPoint, w: CGFloat = 3.5) {
            var p = Path(); p.move(to: pt(a)); p.addLine(to: pt(b))
            ctx.stroke(p, with:.color(color), lineWidth:w)
        }

        let hip = CGPoint.zero
        let headCenter = CGPoint(x: pose.shoulder.x, y: pose.shoulder.y - 10)
        let headR: CGFloat = 9 * scale

        // Head
        var hc = ctx; hc.addFilter(.shadow(color:color.opacity(0.4),radius:4))
        hc.fill(Path(ellipseIn:CGRect(x:pt(headCenter).x-headR, y:pt(headCenter).y-headR, width:headR*2,height:headR*2)), with:.color(color))

        // Torso
        line(pose.shoulder, hip)
        // Arms
        line(pose.shoulder, pose.rElbow)
        line(pose.rElbow,   pose.rWrist)
        line(pose.shoulder, pose.lElbow)
        line(pose.lElbow,   pose.lWrist)
        // Legs
        line(hip,        pose.rKnee)
        line(pose.rKnee, pose.rAnkle)
        line(hip,        pose.lKnee)
        line(pose.lKnee, pose.lAnkle)
    }

    private func drawShadows(ctx: inout GraphicsContext) {
        for cx in [W*0.25, W*0.75] as [CGFloat] {
            var s = Path()
            s.addEllipse(in:CGRect(x:cx-22,y:floorY+2,width:44,height:8))
            ctx.fill(s, with:.color(Color.black.opacity(0.25)))
        }
    }

    // Console-grade hit sparks — burst of colored particles at point of impact
    private func drawHitSparks(ctx: inout GraphicsContext, timeSince: Double) {
        let frac = timeSince / 0.45   // 0→1 as sparks die
        let alpha = max(0, 1.0 - frac * 1.3)
        let cx: CGFloat = W * 0.62   // impact zone just left of opponent
        let cy: CGFloat = floorY - H * 0.30

        // Spark color by hit type
        let sparkColor: Color = lastHitType == "kick" ? Color(red:1.0,green:0.45,blue:0.0) :
                                lastHitType == "dragon" ? Color.yellow :
                                Color(red:0.2,green:0.7,blue:1.0)

        // Expanding ring
        let ringR = CGFloat(frac) * 40
        var ring = Path(); ring.addEllipse(in: CGRect(x:cx-ringR, y:cy-ringR*0.6, width:ringR*2, height:ringR*1.2))
        ctx.stroke(ring, with:.color(sparkColor.opacity(alpha * 0.8)), lineWidth:2.0)

        // 10 radial sparks shooting outward
        let sparkCount = lastHitType == "dragon" ? 16 : 10
        for i in 0..<sparkCount {
            let angle = Double(i) / Double(sparkCount) * .pi * 2
            let sparkDist = CGFloat(frac) * 38
            let sx = cx + CGFloat(cos(angle)) * sparkDist
            let sy = cy + CGFloat(sin(angle)) * sparkDist * 0.55
            var sp = Path(); sp.move(to: CGPoint(x:cx, y:cy)); sp.addLine(to: CGPoint(x:sx, y:sy))
            ctx.stroke(sp, with:.color(sparkColor.opacity(alpha * 0.9)), lineWidth:1.8)
            // Spark dot at tip
            var dot = ctx; dot.addFilter(.shadow(color: sparkColor.opacity(0.7), radius: 4))
            dot.fill(Path(ellipseIn: CGRect(x:sx-2.5,y:sy-2.5,width:5,height:5)),
                     with:.color(sparkColor.opacity(alpha)))
        }

        // Central flash
        let flashR = CGFloat(max(0, 1.0 - frac * 2.5)) * 18
        if flashR > 0 {
            var gc = ctx; gc.addFilter(.shadow(color: sparkColor.opacity(0.9), radius: 10))
            gc.fill(Path(ellipseIn: CGRect(x:cx-flashR,y:cy-flashR,width:flashR*2,height:flashR*2)),
                    with:.color(Color.white.opacity(alpha * 1.4)))
        }
    }
}

// MARK: - Phases & Outcome

private enum KaratePhase { case ready, fight, result }
private enum KarateOutcome { case win, draw, loss }

// MARK: - Health Bar

private struct KarateHealthBar: View {
    let current: Double; let max: Double; let color: Color; let label: String; let isReversed: Bool
    private var fraction: Double { max > 0 ? min(1,current/max) : 0 }

    var body: some View {
        VStack(alignment: isReversed ? .trailing : .leading, spacing:4) {
            HStack { if isReversed { Spacer() }
                Text(label).font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2)
                if !isReversed { Spacer() }
            }
            GeometryReader { geo in
                ZStack(alignment: isReversed ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius:4).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius:4)
                        .fill(LinearGradient(colors:[color,color.opacity(0.7)],startPoint: isReversed ? .trailing : .leading,endPoint: isReversed ? .leading : .trailing))
                        .frame(width:geo.size.width*fraction)
                        .animation(.spring(response:0.35,dampingFraction:0.7),value:fraction)
                }
            }.frame(height:10).clipShape(RoundedRectangle(cornerRadius:4))
        }
    }
}

// MARK: - Chakra Meter

private struct ChakraMeter: View {
    let value: Double; let accentColor: Color
    private var fraction: Double { min(1,value/100) }
    private var isFull: Bool { value >= 100 }

    var body: some View {
        VStack(spacing:3) {
            HStack(spacing:6) {
                Image(systemName:"flame.fill").font(.system(size:10,weight:.bold)).foregroundStyle(isFull ? .yellow : accentColor.opacity(0.7))
                Text("CHAKRA").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(isFull ? .yellow : .secondary).tracking(2)
                Spacer()
                if isFull { Text("DRAGON STRIKE READY").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(.yellow).tracking(1) }
                Text("\(Int(value))%").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(isFull ? .yellow : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    RoundedRectangle(cornerRadius:4).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius:4)
                        .fill(LinearGradient(colors:isFull ? [.yellow,.orange] : [accentColor,accentColor.opacity(0.7)],startPoint:.leading,endPoint:.trailing))
                        .frame(width:geo.size.width*fraction)
                        .animation(.spring(response:0.3,dampingFraction:0.8),value:fraction)
                }
            }.frame(height:8).clipShape(RoundedRectangle(cornerRadius:4))
        }
    }
}

// MARK: - Main View

struct KarateGameView: View {
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss

    private let accentColor  = Color(red:1.0,green:0.2,blue:0.2)
    private let opponentName = "Ryu Nexus"
    private let impactMed    = UIImpactFeedbackGenerator(style:.medium)
    private let impactHvy    = UIImpactFeedbackGenerator(style:.heavy)
    private let notif        = UINotificationFeedbackGenerator()

    @State private var phase: KaratePhase = .ready
    @State private var timeLeft: Int = 90
    @State private var gameTimerTask: Task<Void, Never>?

    @State private var playerHP: Double = 100
    @State private var opponentHP: Double = 100
    private let maxHP: Double = 100

    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var combo: Int = 0
    @State private var maxCombo: Int = 0
    @State private var chakra: Double = 0
    @State private var showDragonStrikeButton: Bool = false

    // Visual
    @State private var playerPose: String = "idle"
    @State private var opponentPose: String = "idle"
    @State private var showFightFlash: Bool = false
    @State private var showCriticalFlash: Bool = false
    @State private var critFlashTask: Task<Void, Never>?
    @State private var actionLabel: String = ""
    @State private var actionColor: Color = Theme.brandBlue
    @State private var showActionLabel: Bool = false
    @State private var actionLabelTask: Task<Void, Never>?
    @State private var screenShake: CGFloat = 0
    @State private var poseResetTask: Task<Void, Never>?
    // Hit spark timing (absolute time reference)
    @State private var lastHitTime: Double = 0
    @State private var lastHitType: String = ""

    // AI
    @State private var aiAttackTask: Task<Void, Never>?
    @State private var lastPlayerActionTime: Date = Date()
    @State private var outcome: KarateOutcome = .loss
    @State private var shardsAwarded: Bool = false

    var body: some View {
        ZStack {
            Color(red:0.06,green:0.01,blue:0.01).ignoresSafeArea()
            if showCriticalFlash { Color.yellow.opacity(0.16).ignoresSafeArea().allowsHitTesting(false) }

            switch phase {
            case .ready:
                GetReadyScreen(title:"Karate · 1v1", subtitle:"90-Second Match · Beat the Opponent",
                               countdown:3, accentColor:accentColor, onComplete:{ startFight() })
            case .fight:
                fightBody.offset(x:screenShake)
            case .result:
                ResultScreen(winner:outcome == .win ? .p1 : (outcome == .draw ? .draw : .p2),
                             p1Score:playerScore, p2Score:opponentScore, title:"Karate · 1v1", accentColor:accentColor,
                             prqGain:outcome == .win ? 10 : (outcome == .draw ? 5 : 2),
                             prqCurrent:viewModel.effectiveMetrics.prqScore, modeAttributeLabel:"COMBO",
                             modeAttributeValue:min(1.0,Double(maxCombo)/10.0), onReturn:{ dismiss() })
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

    // MARK: - Fight Body

    private var fightBody: some View {
        VStack(spacing:0) {
            hudSection.padding(.horizontal,20).padding(.top,8).padding(.bottom,10)
            Divider().background(Theme.cardBorder)
            arenaSection
            Divider().background(Theme.cardBorder)
            controlsHint.padding(.horizontal,20).padding(.vertical,10)
        }
    }

    // MARK: - HUD

    private var hudSection: some View {
        VStack(spacing:10) {
            HStack(spacing:12) {
                KarateHealthBar(current:playerHP,max:maxHP,color:Theme.brandBlue,label:"YOU",isReversed:false).frame(maxWidth:.infinity)
                ZStack {
                    Circle().stroke(timeLeft <= 15 ? Color.red.opacity(0.5) : accentColor.opacity(0.3),lineWidth:2).frame(width:48,height:48)
                    Text("\(timeLeft)").font(.system(size:18,weight:.black,design:.monospaced))
                        .foregroundStyle(timeLeft <= 15 ? .red : .white).contentTransition(.numericText())
                }.frame(width:48)
                KarateHealthBar(current:opponentHP,max:maxHP,color:accentColor,label:opponentName.uppercased(),isReversed:true).frame(maxWidth:.infinity)
            }
            HStack {
                Text("\(playerScore)").font(.system(size:22,weight:.black,design:.monospaced)).foregroundStyle(Theme.brandBlue)
                Spacer()
                if combo >= 2 {
                    Text("×\(combo) COMBO").font(.system(size:11,weight:.black,design:.monospaced)).foregroundStyle(.yellow)
                        .transition(.scale.combined(with:.opacity))
                }
                Spacer()
                Text("\(opponentScore)").font(.system(size:22,weight:.black,design:.monospaced)).foregroundStyle(accentColor)
            }
            ChakraMeter(value:chakra, accentColor:accentColor)
                .onChange(of:chakra) { _,v in showDragonStrikeButton = v >= 100 }
        }
    }

    // MARK: - Arena

    private var arenaSection: some View {
        ZStack {
            KarateDojo(playerPoseName:playerPose, opponentPoseName:opponentPose,
                       crowdAlpha:min(1.0,(Double(playerScore)+Double(opponentScore))*0.04),
                       dragonActive:chakra >= 100 && showDragonStrikeButton,
                       lastHitTime:lastHitTime, lastHitType:lastHitType)

            if showFightFlash {
                Text("FIGHT!").font(.system(size:52,weight:.black,design:.monospaced)).italic()
                    .foregroundStyle(accentColor).shadow(color:accentColor.opacity(0.8),radius:20)
                    .transition(.scale.combined(with:.opacity))
            }

            if showActionLabel {
                Text(actionLabel).font(.system(size:28,weight:.black,design:.monospaced)).italic()
                    .foregroundStyle(actionColor).shadow(color:actionColor.opacity(0.7),radius:14)
                    .transition(.scale(scale:0.6).combined(with:.opacity))
            }

            if showDragonStrikeButton {
                VStack { Spacer()
                    Button { triggerDragonStrike() } label: {
                        HStack(spacing:8) {
                            Image(systemName:"flame.fill").font(.system(size:14,weight:.bold))
                            Text("DRAGON STRIKE").font(.system(size:14,weight:.black,design:.monospaced)).tracking(2)
                        }
                        .foregroundStyle(.black).padding(.horizontal,24).padding(.vertical,12)
                        .background(LinearGradient(colors:[.yellow,.orange],startPoint:.leading,endPoint:.trailing))
                        .clipShape(.rect(cornerRadius:14)).shadow(color:.yellow.opacity(0.5),radius:16)
                    }.padding(.bottom,20)
                }
            }
        }
        .frame(maxWidth:.infinity,maxHeight:.infinity)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance:20)
            .onEnded { v in if abs(v.translation.height) > abs(v.translation.width) && v.translation.height < -40 { handleBlock() } })
        .simultaneousGesture(SpatialTapGesture()
            .onEnded { v in let sw = UIScreen.main.bounds.width
                if v.location.x < sw/2 { handlePunch() } else { handleKick() } })
        .onLongPressGesture(minimumDuration:0.3) { handleStance() }
    }

    // MARK: - Controls Hint

    private var controlsHint: some View {
        HStack(spacing:0) {
            controlHint(icon:"hand.tap.fill",label:"← PUNCH",color:Theme.brandBlue)
            Spacer()
            controlHint(icon:"arrow.up",label:"↑ BLOCK",color:Theme.foundationGreen)
            Spacer()
            controlHint(icon:"rectangle.and.hand.point.up.left.fill",label:"HOLD STANCE",color:Theme.elitePurple)
            Spacer()
            controlHint(icon:"hand.tap.fill",label:"KICK →",color:accentColor)
        }
    }

    private func controlHint(icon:String,label:String,color:Color) -> some View {
        VStack(spacing:2) {
            Image(systemName:icon).font(.system(size:12)).foregroundStyle(color)
            Text(label).font(.system(size:9,weight:.bold,design:.monospaced)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Logic

    private func startFight() {
        phase = .fight
        withAnimation(.spring(response:0.3,dampingFraction:0.5)) { showFightFlash = true }
        Task { try? await Task.sleep(for:.milliseconds(1200)); await MainActor.run { withAnimation { showFightFlash = false } } }
        startGameTimer()
        scheduleAIAttack()
    }

    private func startGameTimer() {
        gameTimerTask?.cancel()
        gameTimerTask = Task {
            while timeLeft > 0 {
                try? await Task.sleep(for:.seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeLeft -= 1 }
            }
            await MainActor.run { endGame() }
        }
    }

    private func scheduleAIAttack() {
        aiAttackTask?.cancel()
        aiAttackTask = Task {
            while true {
                let delay = Double.random(in:2.0...4.0)
                try? await Task.sleep(for:.seconds(delay))
                guard !Task.isCancelled else { return }
                await MainActor.run { aiAttack() }
            }
        }
    }

    private func aiAttack() {
        guard phase == .fight else { return }
        let dmg = Double.random(in:8...18)
        playerHP = max(0,playerHP-dmg)
        opponentScore += 1
        setPose("hit", for: "player", duration: 0.4)
        setPose("punch", for: "opponent", duration: 0.35)
        flashScreenShake()
        impactMed.impactOccurred()
        if playerHP <= 0 { endGame(ko:true,playerKO:true) }
    }

    // MARK: - Player Actions

    private func handlePunch() {
        guard phase == .fight else { return }
        let now = Date(); let isCrit = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now
        let dmg: Double = (isCrit ? 12 : 8) + Double(combo)*1.5
        opponentHP = max(0,opponentHP-dmg)
        playerScore += isCrit ? 2 : 1; combo += 1; maxCombo = max(maxCombo,combo)
        chakra = min(100,chakra+(isCrit ? 15 : 8))
        showAction(text:isCrit ? "CRITICAL PUNCH!" : "PUNCH", color:Theme.brandBlue)
        setPose("punch", for:"player", duration:0.35)
        setPose("hit", for:"opponent", duration:0.35)
        lastHitTime = Date().timeIntervalSinceReferenceDate; lastHitType = "punch"
        if isCrit { triggerCritFlash() }
        flashScreenShake()
        impactMed.impactOccurred()
        if opponentHP <= 0 { endGame(ko:true,playerKO:false) }
    }

    private func handleKick() {
        guard phase == .fight else { return }
        let now = Date(); let isCrit = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now
        let dmg: Double = (isCrit ? 18 : 12) + Double(combo)*2.0
        opponentHP = max(0,opponentHP-dmg)
        playerScore += isCrit ? 3 : 2; combo += 1; maxCombo = max(maxCombo,combo)
        chakra = min(100,chakra+(isCrit ? 20 : 12))
        showAction(text:isCrit ? "CRITICAL KICK!" : "KICK", color:accentColor)
        setPose("kick", for:"player", duration:0.40)
        setPose("hit", for:"opponent", duration:0.40)
        lastHitTime = Date().timeIntervalSinceReferenceDate; lastHitType = "kick"
        if isCrit { triggerCritFlash() }
        flashScreenShake()
        impactHvy.impactOccurred()
        if opponentHP <= 0 { endGame(ko:true,playerKO:false) }
    }

    private func handleBlock() {
        guard phase == .fight else { return }
        combo = 0; playerHP = min(maxHP,playerHP+5)
        showAction(text:"BLOCK", color:Theme.foundationGreen)
        setPose("block", for:"player", duration:0.5)
        impactMed.impactOccurred()
    }

    private func handleStance() {
        guard phase == .fight else { return }
        chakra = min(100,chakra+10)
        showAction(text:"STANCE", color:Theme.elitePurple)
    }

    private func triggerDragonStrike() {
        guard phase == .fight, chakra >= 100 else { return }
        chakra = 0; showDragonStrikeButton = false
        opponentHP = max(0,opponentHP-45)
        playerScore += 10; combo += 3; maxCombo = max(maxCombo,combo)
        showAction(text:"DRAGON STRIKE!", color:.yellow)
        setPose("dragon", for:"player", duration:0.8)
        setPose("hit", for:"opponent", duration:0.6)
        lastHitTime = Date().timeIntervalSinceReferenceDate; lastHitType = "dragon"
        triggerCritFlash(); flashScreenShake()
        notif.notificationOccurred(.success)
        if opponentHP <= 0 { endGame(ko:true,playerKO:false) }
    }

    // MARK: - Pose Helper

    private func setPose(_ pose: String, for target: String, duration: Double) {
        poseResetTask?.cancel()
        if target == "player" { playerPose = pose } else { opponentPose = pose }
        poseResetTask = Task {
            try? await Task.sleep(for:.seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if target == "player" { playerPose = "idle" } else { opponentPose = "idle" }
            }
        }
    }

    // MARK: - FX

    private func showAction(text:String, color:Color) {
        actionLabel = text; actionColor = color
        withAnimation { showActionLabel = true }
        actionLabelTask?.cancel()
        actionLabelTask = Task {
            try? await Task.sleep(for:.milliseconds(900))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { showActionLabel = false }; if combo > 0 { combo -= 1 } }
        }
    }

    private func triggerCritFlash() {
        withAnimation(.easeOut(duration:0.08)) { showCriticalFlash = true }
        critFlashTask?.cancel()
        critFlashTask = Task {
            try? await Task.sleep(for:.milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(.easeIn(duration:0.25)) { showCriticalFlash = false } }
        }
    }

    private func flashScreenShake() {
        withAnimation(.easeOut(duration:0.06)) { screenShake = 8 }
        Task {
            try? await Task.sleep(for:.milliseconds(80))
            await MainActor.run { withAnimation(.spring(response:0.2,dampingFraction:0.4)) { screenShake = 0 } }
        }
    }

    // MARK: - End Game

    private func endGame(ko:Bool = false, playerKO:Bool = false) {
        guard phase == .fight else { return }
        cancelAllTasks()
        if playerKO      { outcome = .loss; showAction(text:"KO!",color:.red) }
        else if ko        { outcome = .win;  showAction(text:"KO!",color:.yellow) }
        else if playerHP > opponentHP { outcome = .win;  showAction(text:"TIME!",color:accentColor) }
        else if playerHP < opponentHP { outcome = .loss; showAction(text:"TIME!",color:.red) }
        else              { outcome = .draw; showAction(text:"DRAW!",color:.white) }
        awardShards()
        Task { try? await Task.sleep(for:.seconds(1.5)); await MainActor.run { withAnimation { phase = .result } } }
    }

    private func awardShards() {
        guard !shardsAwarded else { return }
        shardsAwarded = true
        viewModel.profile.evolutionShards += outcome == .win ? 50 : outcome == .draw ? 25 : 15
        SaveSystem.saveProfile(viewModel.profile)
    }

    private func cancelAllTasks() {
        gameTimerTask?.cancel(); aiAttackTask?.cancel()
        actionLabelTask?.cancel(); critFlashTask?.cancel(); poseResetTask?.cancel()
    }
}
