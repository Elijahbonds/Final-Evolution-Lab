import SwiftUI

// MARK: - Types

private struct DunkStyle: Identifiable {
    let id: String
    let name: String
    let icon: String
    let difficulty: Double
    let swipeHint: String
    let crowdPeak: Double

    static let all: [DunkStyle] = [
        DunkStyle(id: "power_slam",   name: "Power Slam",   icon: "bolt.fill",
                  difficulty: 0.55, swipeHint: "POWER UP",    crowdPeak: 0.75),
        DunkStyle(id: "windmill",     name: "Windmill",     icon: "wind",
                  difficulty: 0.80, swipeHint: "SPIN IT",     crowdPeak: 0.90),
        DunkStyle(id: "three_sixty",  name: "360",          icon: "arrow.trianglehead.2.clockwise.rotate.90",
                  difficulty: 0.85, swipeHint: "FULL SPIN",   crowdPeak: 0.92),
        DunkStyle(id: "tomahawk",     name: "Tomahawk",     icon: "flame.fill",
                  difficulty: 0.70, swipeHint: "SLAM DOWN",   crowdPeak: 0.82),
        DunkStyle(id: "alley_oop",    name: "Alley-Oop",    icon: "person.2.fill",
                  difficulty: 0.75, swipeHint: "CATCH & JAM", crowdPeak: 0.88),
        DunkStyle(id: "reverse",      name: "Reverse",      icon: "arrow.uturn.backward",
                  difficulty: 0.72, swipeHint: "REVERSE IT",  crowdPeak: 0.83),
        DunkStyle(id: "between_legs", name: "Between-Legs", icon: "arrow.down.forward.and.arrow.up.backward",
                  difficulty: 0.90, swipeHint: "THREAD IT",   crowdPeak: 0.96),
    ]
}

private struct RoundResult {
    let round: Int
    let style: DunkStyle
    let j1: Int; let j2: Int; let j3: Int
    let total: Int
    let message: String
    let isPerfect: Bool
    let aiScore: Int
    let playerWon: Bool
}

private enum DunkGamePhase {
    case ready, styleSelect, approach, execution, judgeReveal, roundTransition, result
}

private let TOTAL_ROUNDS = 3

// MARK: - Court Canvas

private struct DunkCourtCanvas: View {
    let phase: DunkGamePhase
    let powerLevel: Double
    let execProgress: Double   // 0→1 dunk arc
    let crowdLevel: Double
    let isPerfect: Bool
    let postDunk: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = CourtDraw(size: size, t: t, phase: phase,
                                  power: powerLevel, exec: execProgress,
                                  crowd: crowdLevel, perfect: isPerfect, postDunk: postDunk)
                d.render(into: &ctx)
            }
        }
    }
}

private struct CourtDraw {
    let size: CGSize; let t: Double
    let phase: DunkGamePhase
    let power: Double; let exec: Double
    let crowd: Double; let perfect: Bool; let postDunk: Bool

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var floorY: CGFloat { H * 0.84 }
    var poleX:  CGFloat { W * 0.80 }
    var bbTopY: CGFloat { H * 0.20 }
    var rimY:   CGFloat { H * 0.48 }
    var rimL:   CGFloat { W * 0.64 }
    var rimR:   CGFloat { W * 0.80 }

    var playerProgress: CGFloat {
        switch phase {
        case .approach:    return CGFloat(power / 100.0) * 0.50
        case .execution:   return 0.50 + CGFloat(exec) * 0.20
        default:           return postDunk ? 0.72 : 0.50
        }
    }
    var playerX: CGFloat { W * (0.10 + playerProgress * 0.70) }

    var jumpH: CGFloat {
        guard phase == .execution else { return 0 }
        // Wind-up crouch (0-0.15), then explosive leap, peak held longer, land fast
        if exec < 0.15 { return -H * 0.025 * CGFloat(exec / 0.15) }  // slight crouch
        let liftExec = (exec - 0.15) / 0.85
        let arc = liftExec < 0.55 ? sin(liftExec / 0.55 * .pi * 0.92) : max(0, sin(liftExec / 0.55 * .pi * 0.92))
        return H * CGFloat(arc) * 0.44  // dramatically higher — console-grade air time
    }
    // Shadow scale grows as player rises
    var shadowScale: CGFloat {
        guard phase == .execution else { return 1.0 }
        let rise = jumpH / (H * 0.44)
        return max(0.3, 1.0 - rise * 0.65)
    }
    var footY: CGFloat { floorY - jumpH }

    mutating func render(into ctx: inout GraphicsContext) {
        drawBg(ctx: &ctx)
        drawCrowd(ctx: &ctx)
        drawFloor(ctx: &ctx)
        drawPlayerShadow(ctx: &ctx)
        drawBasket(ctx: &ctx)
        drawBallTrail(ctx: &ctx)
        drawBall(ctx: &ctx)
        drawPlayer(ctx: &ctx)
        if phase == .execution && exec > 0.80 { drawRimImpact(ctx: &ctx) }
        if perfect && postDunk { drawSparkles(ctx: &ctx) }
    }

    private func drawBg(ctx: inout GraphicsContext) {
        // Deep arena dark — richer blue-black than before
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(Color(red: 0.01, green: 0.03, blue: 0.09)))

        // Dramatic spotlight cones from ceiling corners
        for (cx, cw): (CGFloat, CGFloat) in [(poleX, W * 0.60), (W * 0.22, W * 0.52)] {
            var p = Path()
            p.addEllipse(in: CGRect(x: cx - cw/2, y: -H*0.10, width: cw, height: H*0.82))
            ctx.fill(p, with: .color(Color.white.opacity(0.020 + 0.008 * sin(t * 0.7))))
        }

        // Arena score halo — pulses when dunking
        if phase == .execution {
            let dunkPulse = 0.04 + 0.03 * sin(t * 6.0)
            var halo = Path()
            halo.addEllipse(in: CGRect(x: W*0.35, y: H*0.10, width: W*0.50, height: H*0.70))
            ctx.fill(halo, with: .color(Color(red: 0.0, green: 0.55, blue: 1.0).opacity(dunkPulse)))
        }
    }

    // Team jersey hue cycling for stadium diversity
    private func crowdColor(index: Int, row: Int) -> Color {
        let colors: [Color] = [
            Color(red:0.15,green:0.30,blue:0.90),
            Color(red:0.90,green:0.18,blue:0.18),
            Color(red:0.95,green:0.80,blue:0.10),
            Color(red:0.10,green:0.75,blue:0.35),
            Color(red:0.80,green:0.20,blue:0.80),
        ]
        return colors[(index * 3 + row * 7) % colors.count]
    }

    private func drawCrowd(ctx: inout GraphicsContext) {
        for row in 0..<4 {
            let count = 12 + row * 5
            let rowY  = H * 0.04 + CGFloat(row) * 22
            for i in 0..<count {
                let px  = W * (CGFloat(i) + 0.5) / CGFloat(count)
                let wave = sin(t * 2.5 + Double(i)*0.55 + Double(row)*0.8) * crowd * 10
                let py  = rowY - CGFloat(wave)
                let r: CGFloat = 4.5 + CGFloat(row) * 0.5
                let alpha = (0.15 + crowd * 0.35) * (1.0 - Double(row)*0.16)
                let jColor = crowdColor(index: i, row: row)
                // Head
                ctx.fill(Path(ellipseIn: CGRect(x:px-r*0.85, y:py-r*1.8, width:r*1.7, height:r*1.7)),
                         with: .color(Color(red:0.88,green:0.72,blue:0.58).opacity(alpha * 1.1)))
                // Jersey
                ctx.fill(Path(CGRect(x:px-r*0.8, y:py, width:r*1.6, height:r*2.0)),
                         with: .color(jColor.opacity(alpha)))
                // Arms raised when crowd level high
                if crowd > 0.5 {
                    let armRaise = CGFloat(crowd - 0.5) * 2.0 * CGFloat(wave > 0 ? 1 : 0)
                    for sign: CGFloat in [-1, 1] {
                        var arm = Path()
                        arm.move(to: CGPoint(x: px + sign*r*0.6, y: py))
                        arm.addLine(to: CGPoint(x: px + sign*r*1.6, y: py - r*1.5*armRaise))
                        ctx.stroke(arm, with: .color(jColor.opacity(alpha * 0.8)), lineWidth: 1.2)
                    }
                }
            }
        }
    }

    private func drawFloor(ctx: inout GraphicsContext) {
        var f = Path(); f.move(to: CGPoint(x:0,y:floorY)); f.addLine(to: CGPoint(x:W,y:floorY))
        ctx.stroke(f, with: .color(Color.white.opacity(0.14)), lineWidth: 2)

        // Key (painted lane)
        ctx.fill(Path(CGRect(x:0, y:floorY-H*0.038, width:rimR+10, height:H*0.038)),
                 with: .color(Color(red:0.72,green:0.36,blue:0.10).opacity(0.20)))

        // Floor glow under rim
        var g = Path()
        g.addEllipse(in: CGRect(x:rimL-8, y:floorY, width:(rimR-rimL)+16, height:12))
        ctx.fill(g, with: .color(Color.orange.opacity(0.10)))
    }

    private func drawBasket(ctx: inout GraphicsContext) {
        // Pole
        var pole = Path(); pole.move(to: CGPoint(x:poleX,y:floorY)); pole.addLine(to: CGPoint(x:poleX,y:bbTopY))
        ctx.stroke(pole, with: .color(Color.white.opacity(0.28)), lineWidth: 3.5)

        // Backboard
        let bb = CGRect(x:poleX-6, y:bbTopY, width:12, height:rimY-bbTopY+8)
        ctx.fill(Path(bb), with: .color(Color(red:0.84,green:0.88,blue:0.93).opacity(0.65)))
        ctx.stroke(Path(bb), with: .color(Color.white.opacity(0.55)), lineWidth: 1.5)

        // Target square
        let sq = CGRect(x:poleX-12, y:rimY-22, width:24, height:16)
        ctx.stroke(Path(sq), with: .color(Color.red.opacity(0.45)), lineWidth: 1.5)

        // Rim with glow
        var rim = Path(); rim.move(to: CGPoint(x:rimL,y:rimY)); rim.addLine(to: CGPoint(x:rimR,y:rimY))
        var gc = ctx; gc.addFilter(.shadow(color: Color.orange.opacity(0.7), radius: 6))
        gc.stroke(rim, with: .color(Color.orange), lineWidth: 4)

        // Net
        let nd: CGFloat = 26
        for i in 0...7 {
            let tf = CGFloat(i) / 7.0
            let nx = rimL + (rimR-rimL)*tf
            let ny = rimY + nd*(1 + abs(tf-0.5)*0.35)
            var s = Path(); s.move(to: CGPoint(x:nx,y:rimY)); s.addLine(to: CGPoint(x:nx+(0.5-tf)*5,y:ny))
            ctx.stroke(s, with: .color(Color.white.opacity(0.22)), lineWidth: 1)
        }
        for rung in 1...3 {
            let rf = CGFloat(rung) / 4.0
            let ry = rimY + nd*0.84*rf
            let sh = (rimR-rimL)*0.10*rf
            var r = Path(); r.move(to: CGPoint(x:rimL+sh,y:ry)); r.addLine(to: CGPoint(x:rimR-sh,y:ry))
            ctx.stroke(r, with: .color(Color.white.opacity(0.13)), lineWidth: 0.8)
        }
    }

    private func drawPlayer(ctx: inout GraphicsContext) {
        let px = playerX
        let py = footY
        let lw: CGFloat = 4.0     // thicker limbs = more visible on large canvas
        let headR: CGFloat = 11   // bigger head
        let bodyH: CGFloat = 32

        let cycle = t.truncatingRemainder(dividingBy: 0.48) / 0.48
        let sinC = CGFloat(sin(cycle * .pi * 2))

        let shoulderY = py - bodyH - headR * 1.9
        let hipY      = shoulderY + bodyH

        let bodyColor  = Color(red: 0.10, green: 0.85, blue: 1.0)
        let legColor   = Color(red: 0.15, green: 0.20, blue: 0.95)
        let skinColor  = Color(red: 0.94, green: 0.81, blue: 0.70)
        let shoeColor  = Color(red: 0.92, green: 0.35, blue: 0.08)  // orange Air Jordans

        // Head with glow during dunk
        if phase == .execution {
            var gc = ctx; gc.addFilter(.shadow(color: bodyColor.opacity(0.4), radius: 8))
            gc.fill(Path(ellipseIn: CGRect(x:px-headR, y:shoulderY-headR*1.85, width:headR*2, height:headR*2)),
                    with: .color(skinColor))
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x:px-headR, y:shoulderY-headR*1.85, width:headR*2, height:headR*2)),
                     with: .color(skinColor))
        }

        // Torso
        var spine = Path(); spine.move(to: CGPoint(x:px,y:shoulderY)); spine.addLine(to: CGPoint(x:px,y:hipY))
        ctx.stroke(spine, with: .color(bodyColor), lineWidth: lw)

        if phase == .execution {
            let ep = CGFloat(exec)
            if ep < 0.15 {
                // Wind-up crouch: arms pulled back, knees bent low
                let crouchT = ep / 0.15
                for sign: CGFloat in [1, -1] {
                    // Arms pulled back and down (loading)
                    var arm = Path(); arm.move(to: CGPoint(x:px,y:shoulderY+4))
                    arm.addLine(to: CGPoint(x:px+sign*22, y:shoulderY+18 + 10*crouchT))
                    ctx.stroke(arm, with: .color(bodyColor), lineWidth: lw)
                    // Legs deeply bent
                    var leg = Path(); leg.move(to: CGPoint(x:px,y:hipY))
                    leg.addLine(to: CGPoint(x:px+sign*20, y:hipY+12))
                    leg.addLine(to: CGPoint(x:px+sign*12, y:hipY+22))
                    ctx.stroke(leg, with: .color(legColor), lineWidth: lw)
                    // Shoes
                    ctx.fill(Path(CGRect(x:px+sign*8, y:hipY+20, width:sign*10, height:5)), with: .color(shoeColor))
                }
            } else {
                // Full leap: dominant arm reaches for rim, off-arm trails, legs tucked
                let liftT = (ep - 0.15) / 0.85  // 0→1 across the aerial
                // Dunking arm sweeps up and forward dramatically
                let angle: CGFloat = -.pi * 0.10 - liftT * .pi * 0.75
                let aex = px + cos(angle)*38; let aey = shoulderY + sin(angle)*38
                var arm = Path(); arm.move(to: CGPoint(x:px,y:shoulderY+4)); arm.addLine(to: CGPoint(x:aex,y:aey))
                var gc = ctx; gc.addFilter(.shadow(color: bodyColor.opacity(0.5), radius: 6))
                gc.stroke(arm, with: .color(bodyColor), lineWidth: lw + 1)
                // Off-arm trails behind
                var arm2 = Path(); arm2.move(to: CGPoint(x:px,y:shoulderY+4))
                arm2.addLine(to: CGPoint(x:px-22, y:shoulderY + 22 + liftT*10))
                ctx.stroke(arm2, with: .color(bodyColor), lineWidth: lw)
                // Legs tuck harder as apex approached
                let tuck = min(1.0, liftT * 1.3)
                for sign: CGFloat in [1, -1] {
                    var leg = Path()
                    leg.move(to: CGPoint(x:px,y:hipY))
                    leg.addLine(to: CGPoint(x:px+sign*16, y:hipY + 10 - tuck*18))
                    leg.addLine(to: CGPoint(x:px+sign*8,  y:hipY + 22 - tuck*28))
                    ctx.stroke(leg, with: .color(legColor), lineWidth: lw)
                    // Shoes visible during tuck
                    ctx.fill(Path(CGRect(x:px+sign*5, y:hipY+20-tuck*28, width:sign*10, height:5)),
                             with: .color(shoeColor))
                }
            }
        } else if phase == .approach {
            // Running — faster stride, more exaggerated
            for sign: CGFloat in [1, -1] {
                var arm = Path(); arm.move(to: CGPoint(x:px,y:shoulderY+5))
                arm.addLine(to: CGPoint(x:px+sign*22*sinC, y:shoulderY+22))
                ctx.stroke(arm, with: .color(bodyColor), lineWidth: lw)
                var leg = Path(); leg.move(to: CGPoint(x:px,y:hipY))
                leg.addLine(to: CGPoint(x:px+sign*18*sinC,y:hipY+20))
                leg.addLine(to: CGPoint(x:px+sign*10*sinC, y:py-1))
                ctx.stroke(leg, with: .color(legColor), lineWidth: lw)
                // Running shoe at contact point
                ctx.fill(Path(CGRect(x:px+sign*7*sinC, y:py-5, width:sign*12, height:5)),
                         with: .color(shoeColor))
            }
        } else {
            // Standing idle — slight weight shift
            let idleRock = CGFloat(sin(t * 1.4) * 2)
            for sign: CGFloat in [1, -1] {
                var arm = Path(); arm.move(to: CGPoint(x:px,y:shoulderY+4))
                arm.addLine(to: CGPoint(x:px+sign*18+idleRock, y:hipY-3))
                ctx.stroke(arm, with: .color(bodyColor), lineWidth: lw)
                var leg = Path(); leg.move(to: CGPoint(x:px,y:hipY))
                leg.addLine(to: CGPoint(x:px+sign*8+idleRock*0.5, y:py-1))
                ctx.stroke(leg, with: .color(legColor), lineWidth: lw)
                ctx.fill(Path(CGRect(x:px+sign*5+idleRock*0.5, y:py-5, width:sign*12, height:5)),
                         with: .color(shoeColor))
            }
        }
    }

    private func drawBall(ctx: inout GraphicsContext) {
        let r: CGFloat = 8
        let bx: CGFloat; let by: CGFloat
        switch phase {
        case .approach:
            let bounce = abs(sin(t * .pi / 0.48)) * 14
            bx = playerX + 14; by = footY - CGFloat(bounce) - 10
        case .execution:
            let ep = CGFloat(exec)
            let sx = playerX + 14; let sy = footY - jumpH - 36
            let ex = (rimL + rimR) / 2; let ey = rimY - 6
            bx = sx + (ex-sx)*ep
            by = sy + (ey-sy)*ep - H*0.22*4*ep*(1-ep)
        default:
            bx = postDunk ? (rimL+rimR)/2 : playerX+14
            by = postDunk ? rimY+30       : footY-12
        }
        var bc = ctx; bc.addFilter(.shadow(color: Color.orange.opacity(0.55), radius: 5))
        bc.fill(Path(ellipseIn: CGRect(x:bx-r,y:by-r,width:r*2,height:r*2)), with: .color(Color.orange))
        var seam = Path()
        seam.addArc(center: CGPoint(x:bx,y:by), radius: r*0.76, startAngle: .degrees(-40), endAngle: .degrees(200), clockwise: false)
        ctx.stroke(seam, with: .color(Color.black.opacity(0.28)), lineWidth: 1)
    }

    private func drawSparkles(ctx: inout GraphicsContext) {
        let cx = (rimL+rimR)/2; let cy = rimY - 18
        for i in 0..<20 {
            let angle = Double(i)/20.0 * .pi*2 + t*2.1
            let dist  = 28 + sin(t*3.8 + Double(i))*16
            let sx = cx + CGFloat(cos(angle))*CGFloat(dist)
            let sy = cy + CGFloat(sin(angle))*CGFloat(dist)
            let alpha = 0.6 + 0.4*abs(sin(t*5.0 + Double(i)*0.7))
            let sparkColor: Color = i % 3 == 0 ? .white : (i % 3 == 1 ? .yellow : Color.orange)
            var sc = ctx; sc.addFilter(.shadow(color: sparkColor.opacity(0.6), radius: 5))
            sc.fill(Path(ellipseIn: CGRect(x:sx-3,y:sy-3,width:6,height:6)), with: .color(sparkColor.opacity(alpha)))
        }
    }

    private func drawPlayerShadow(ctx: inout GraphicsContext) {
        let px = playerX
        let sw: CGFloat = 28 * shadowScale
        let sh: CGFloat = 8  * shadowScale
        let shadowAlpha = 0.35 * Double(shadowScale)
        ctx.fill(Path(ellipseIn: CGRect(x: px - sw/2, y: floorY + 2, width: sw, height: sh)),
                 with: .color(Color.black.opacity(shadowAlpha)))
    }

    // Ball motion trail — 4 ghost copies fading behind the ball during execution
    private func drawBallTrail(ctx: inout GraphicsContext) {
        guard phase == .execution, exec > 0.20 else { return }
        let r: CGFloat = 7
        let ex = (rimL + rimR) / 2; let ey = rimY - 6
        for trail in 1...4 {
            let pastExec = max(0.20, exec - Double(trail) * 0.055)
            let pastLift = (pastExec - 0.15) / 0.85
            let pastArc = pastLift < 0.55 ? sin(pastLift / 0.55 * .pi * 0.92) : max(0.0, sin(pastLift / 0.55 * .pi * 0.92))
            let pastJumpH = H * CGFloat(pastArc) * 0.44
            let pastPlayerX = W * (0.10 + (0.50 + CGFloat(pastExec) * 0.20) * 0.70)
            let pastFootY = floorY - pastJumpH
            let sx = pastPlayerX + 14; let sy = pastFootY - pastJumpH - 36
            let ep = CGFloat(pastExec)
            let trailBx = sx + (ex - sx) * ep
            let trailBy = sy + (ey - sy) * ep - H * 0.22 * 4 * ep * (1 - ep)
            let alpha = 0.28 - Double(trail) * 0.055
            ctx.fill(Path(ellipseIn: CGRect(x:trailBx-r,y:trailBy-r,width:r*2,height:r*2)),
                     with: .color(Color.orange.opacity(alpha)))
        }
    }

    // Rim impact burst when ball arrives at the hoop
    private func drawRimImpact(ctx: inout GraphicsContext) {
        let cx = (rimL+rimR)/2; let cy = rimY
        let impactFrac = (exec - 0.80) / 0.20  // 0→1 over final 20% of arc
        let burstR = CGFloat(impactFrac) * 34
        // Expanding ring
        var ring = Path(); ring.addEllipse(in: CGRect(x: cx-burstR, y: cy-burstR*0.5, width: burstR*2, height: burstR))
        ctx.stroke(ring, with: .color(Color.orange.opacity(max(0, 0.8 - impactFrac * 0.9))), lineWidth: 2.5)

        // 8 radial sparks
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4.0
            let sparkLen: CGFloat = burstR * 0.8
            let sx = cx + CGFloat(cos(angle)) * sparkLen
            let sy = cy + CGFloat(sin(angle)) * sparkLen * 0.4
            var spark = Path(); spark.move(to: CGPoint(x: cx, y: cy)); spark.addLine(to: CGPoint(x: sx, y: sy))
            ctx.stroke(spark, with: .color(Color.yellow.opacity(max(0, 0.7 - impactFrac * 0.8))), lineWidth: 1.5)
        }
    }
}

// MARK: - Main View

struct BasketballDunkGameView: View {
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss

    private let accent = Theme.brandCyan
    private let impactMed  = UIImpactFeedbackGenerator(style: .medium)
    private let impactHvy  = UIImpactFeedbackGenerator(style: .heavy)

    @State private var phase: DunkGamePhase = .ready
    @State private var currentRound: Int = 1
    @State private var selectedStyle: DunkStyle = DunkStyle.all[0]

    // Approach
    @State private var powerLevel: Double  = 0.0
    @State private var powerFilling        = false
    @State private var powerTask: Task<Void, Never>?
    @State private var approachReleased    = false
    @State private var approachQuality: Double = 0.0
    @State private var hitSweetSpot        = false

    // Execution
    @State private var swipeDragOffset: CGSize = .zero
    @State private var swipeRegistered    = false
    @State private var executionQuality: Double = 0.0
    @State private var swipeFlash         = false
    @State private var execProgress: Double = 0.0
    @State private var execAnimTask: Task<Void, Never>?
    @State private var postDunk           = false

    // Judge
    @State private var judgeScoresRevealed: [Bool] = [false, false, false]
    @State private var judgeRevealTask: Task<Void, Never>?
    @State private var currentJ1 = 0; @State private var currentJ2 = 0; @State private var currentJ3 = 0
    @State private var currentMessage = ""; @State private var isPerfect = false
    @State private var perfectFlash   = false

    // Crowd & scoring
    @State private var crowdLevel: Double = 0.0
    @State private var playerRoundScores: [RoundResult] = []
    @State private var aiRoundScores: [Int]  = []
    @State private var playerTotal: Int = 0; @State private var aiTotal: Int = 0
    @State private var shardsAwarded = false

    var body: some View {
        ZStack {
            Color(red:0.02,green:0.06,blue:0.12).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(title:"Dunk Contest", subtitle:"3 rounds · Select style · Impress the judges",
                               countdown:3, accentColor:accent, onComplete:{ phase = .styleSelect })
            case .styleSelect:    styleSelectScreen
            case .approach:       approachScreen
            case .execution:      executionScreen
            case .judgeReveal:    judgeRevealScreen
            case .roundTransition: roundTransitionOverlay
            case .result:         resultScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { powerTask?.cancel(); execAnimTask?.cancel(); judgeRevealTask?.cancel(); dismiss() } label: {
                    HStack(spacing:4) {
                        Image(systemName:"chevron.left").font(.system(size:14,weight:.bold))
                        Text("EXIT").font(.system(.caption,design:.monospaced,weight:.bold))
                    }.foregroundStyle(accent)
                }
            }
        }
        .toolbarColorScheme(.dark, for:.navigationBar)
        .onDisappear { powerTask?.cancel(); execAnimTask?.cancel(); judgeRevealTask?.cancel() }
    }

    // MARK: - Court canvas (shared across phases)

    private var courtCanvas: some View {
        DunkCourtCanvas(phase: phase, powerLevel: powerLevel, execProgress: execProgress,
                        crowdLevel: crowdLevel, isPerfect: isPerfect, postDunk: postDunk)
            .frame(height: phase == .execution ? 260 : 220)  // bigger during the actual dunk
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius:16).stroke(accent.opacity(0.14), lineWidth:1))
            .animation(.easeInOut(duration: 0.3), value: phase == .execution)
    }

    // MARK: - Score header

    private var scoreHeader: some View {
        HStack(spacing:16) {
            scorePill(label:"YOU", value:"\(playerTotal)", color:accent)
            Spacer()
            Text("ROUND \(currentRound) / \(TOTAL_ROUNDS)")
                .font(.system(size:10,weight:.black,design:.monospaced)).foregroundStyle(.white.opacity(0.45)).tracking(2)
            Spacer()
            scorePill(label:"KAI NEXUS", value:"\(aiTotal)", color:.red)
        }.padding(.horizontal,20).padding(.top,4)
    }

    private func scorePill(label:String, value:String, color:Color) -> some View {
        VStack(spacing:3) {
            Text(value).font(.system(size:24,weight:.black,design:.monospaced)).foregroundStyle(color).contentTransition(.numericText())
            Text(label).font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(1)
        }
        .padding(.horizontal,16).padding(.vertical,8)
        .background(RoundedRectangle(cornerRadius:12).fill(color.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.15),lineWidth:0.5)))
    }

    // MARK: - Style Select

    private var styleSelectScreen: some View {
        VStack(spacing:0) {
            scoreHeader.padding(.top,12)
            Spacer().frame(height:16)
            Text("SELECT YOUR DUNK").font(.system(size:12,weight:.black,design:.monospaced)).foregroundStyle(accent).tracking(4)
            Text("Round \(currentRound)").font(.system(size:28,weight:.black)).italic().foregroundStyle(.white).padding(.top,4)
            Spacer().frame(height:14)
            ScrollView(.horizontal, showsIndicators:false) {
                HStack(spacing:12) {
                    ForEach(DunkStyle.all) { s in
                        dunkCard(s, selected: selectedStyle.id == s.id).onTapGesture { selectedStyle = s }
                    }
                }.padding(.horizontal,20).padding(.vertical,8)
            }
            Spacer().frame(height:16)
            selectedStyleDetail.padding(.horizontal,20)
            Spacer()
            Button { withAnimation { phase = .approach }; resetApproach() } label: {
                HStack(spacing:10) {
                    Image(systemName:"figure.highintensity.intervaltraining")
                    Text("APPROACH THE RIM")
                }.font(.system(.subheadline,weight:.black)).foregroundStyle(.black)
                    .frame(maxWidth:.infinity).padding(.vertical,18).background(accent).clipShape(.rect(cornerRadius:16))
                    .shadow(color:accent.opacity(0.35),radius:12)
            }.padding(.horizontal,24).padding(.bottom,32)
        }
    }

    private func dunkCard(_ style: DunkStyle, selected: Bool) -> some View {
        VStack(spacing:8) {
            ZStack {
                Circle().fill(selected ? accent.opacity(0.18) : Color.white.opacity(0.04)).frame(width:54,height:54)
                Circle().strokeBorder(selected ? accent : Color.white.opacity(0.08), lineWidth: selected ? 2 : 0.5).frame(width:54,height:54)
                Image(systemName:style.icon).font(.system(size:20,weight:.bold)).foregroundStyle(selected ? accent : .white.opacity(0.4))
            }
            Text(style.name).font(.system(size:9,weight:.black,design:.monospaced))
                .foregroundStyle(selected ? accent : .white.opacity(0.5))
                .multilineTextAlignment(.center).frame(width:72).lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(width:84).padding(.vertical,12)
        .background(RoundedRectangle(cornerRadius:16).fill(selected ? accent.opacity(0.06) : Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius:16).stroke(selected ? accent.opacity(0.3) : Theme.cardBorder,lineWidth:1)))
        .animation(.spring(response:0.2),value:selected)
    }

    private var selectedStyleDetail: some View {
        HStack(spacing:10) {
            ZStack {
                Circle().fill(accent.opacity(0.12)).frame(width:52,height:52)
                Image(systemName:selectedStyle.icon).font(.system(size:22,weight:.bold)).foregroundStyle(accent)
            }
            VStack(alignment:.leading,spacing:4) {
                Text(selectedStyle.name.uppercased()).font(.system(size:14,weight:.black,design:.monospaced)).foregroundStyle(.white)
                diffBar(difficulty:selectedStyle.difficulty).frame(width:120)
            }
            Spacer()
            VStack(alignment:.trailing,spacing:2) {
                Text("CUE").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(1)
                Text(selectedStyle.swipeHint).font(.system(size:13,weight:.black,design:.monospaced)).foregroundStyle(accent)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius:16).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius:16).stroke(Theme.cardBorder,lineWidth:0.5)))
    }

    // MARK: - Approach

    private var approachScreen: some View {
        VStack(spacing:0) {
            scoreHeader.padding(.top,12)
            courtCanvas.padding(.horizontal,20).padding(.top,10)
            styleTag.padding(.top,12)
            Text("HOLD TO BUILD POWER").font(.system(size:11,weight:.black,design:.monospaced))
                .foregroundStyle(accent.opacity(0.8)).tracking(3).padding(.top,14)
            Text("Release in the sweet spot (78–90%)").font(.system(size:10,design:.monospaced))
                .foregroundStyle(.secondary).padding(.top,3)
            Spacer().frame(height:20)
            powerBarView.padding(.horizontal,24)
            Spacer().frame(height:28)
            holdButton
            Spacer()
        }
    }

    private var powerBarView: some View {
        GeometryReader { geo in
            let bw = geo.size.width
            ZStack(alignment:.leading) {
                RoundedRectangle(cornerRadius:8).fill(Color.white.opacity(0.06)).frame(height:52)
                RoundedRectangle(cornerRadius:8)
                    .fill(LinearGradient(colors:powerBarColors(powerLevel),startPoint:.leading,endPoint:.trailing))
                    .frame(width:bw * CGFloat(powerLevel/100.0),height:52)
                    .animation(.linear(duration:0.05),value:powerLevel)
                // Sweet spot
                let zs = bw * 0.78; let zw = bw * 0.12
                RoundedRectangle(cornerRadius:4).fill(Color.green.opacity(0.22)).frame(width:zw,height:52).offset(x:zs)
                Text("●").font(.system(size:6,weight:.black)).foregroundStyle(Color.green.opacity(0.9))
                    .offset(x:zs+3,y:0).frame(maxHeight:.infinity,alignment:.center)
                Text("SWEET SPOT").font(.system(size:6,weight:.black,design:.monospaced)).foregroundStyle(Color.green.opacity(0.8))
                    .offset(x:zs+10,y:0).frame(maxHeight:.infinity,alignment:.center)
                HStack { Spacer(); Text(String(format:"%.0f%%",powerLevel))
                    .font(.system(size:22,weight:.black,design:.monospaced)).foregroundStyle(.white).padding(.trailing,14) }
            }.frame(height:52)
        }.frame(height:52)
    }

    private var holdButton: some View {
        ZStack {
            Circle().fill(powerFilling ? accent.opacity(0.15) : Color.white.opacity(0.05)).frame(width:130,height:130)
            Circle().strokeBorder(powerFilling ? accent : Color.white.opacity(0.18),lineWidth:3).frame(width:130,height:130)
                .scaleEffect(powerFilling ? 1.06 : 1.0)
                .animation(.easeInOut(duration:0.45).repeatForever(autoreverses:true),value:powerFilling)
            VStack(spacing:6) {
                Image(systemName:powerFilling ? "hand.raised.fill" : "hand.tap.fill")
                    .font(.system(size:30,weight:.bold)).foregroundStyle(powerFilling ? accent : .white.opacity(0.5))
                Text(powerFilling ? "RELEASE!" : "HOLD").font(.system(size:10,weight:.black,design:.monospaced))
                    .foregroundStyle(powerFilling ? accent : .white.opacity(0.5)).tracking(2)
            }
        }
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance:0)
            .onChanged { _ in if !powerFilling && !approachReleased { startCharge() } }
            .onEnded   { _ in releasePower() })
    }

    // MARK: - Execution

    private var executionScreen: some View {
        VStack(spacing:0) {
            scoreHeader.padding(.top,12)
            courtCanvas.padding(.horizontal,20).padding(.top,10)
            styleTag.padding(.top,12)
            Text(selectedStyle.swipeHint).font(.system(size:28,weight:.black,design:.monospaced))
                .foregroundStyle(accent).shadow(color:accent.opacity(0.5),radius:16)
                .scaleEffect(swipeFlash ? 1.1 : 1.0).animation(.spring(response:0.2),value:swipeFlash).padding(.top,10)
            Text("SWIPE TO EXECUTE").font(.system(size:10,weight:.bold,design:.monospaced))
                .foregroundStyle(.secondary).tracking(3).padding(.top,6)
            Spacer().frame(height:24)
            // Swipe zone
            ZStack {
                RoundedRectangle(cornerRadius:24).fill(accent.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius:24).strokeBorder(accent.opacity(swipeRegistered ? 0.7 : 0.2),lineWidth:2))
                    .frame(width:200,height:120)
                    .scaleEffect(swipeRegistered ? 1.04 : 1.0).animation(.spring(response:0.25),value:swipeRegistered)
                VStack(spacing:10) {
                    Image(systemName:swipeRegistered ? "checkmark.circle.fill" : selectedStyle.icon)
                        .font(.system(size:40,weight:.bold)).foregroundStyle(swipeRegistered ? .green : accent.opacity(0.75))
                    Text(swipeRegistered ? "EXECUTED!" : "SWIPE HERE").font(.system(size:11,weight:.black,design:.monospaced))
                        .foregroundStyle(swipeRegistered ? .green : accent.opacity(0.6)).tracking(2)
                }
                if !swipeRegistered {
                    Circle().fill(accent.opacity(0.22)).frame(width:36,height:36)
                        .offset(swipeDragOffset).animation(.interactiveSpring(),value:swipeDragOffset)
                }
            }
            .gesture(DragGesture(minimumDistance:12)
                .onChanged { v in guard !swipeRegistered else { return }; swipeDragOffset = v.translation }
                .onEnded   { v in guard !swipeRegistered else { return }; registerSwipe(translation:v.translation) })
            Spacer()
        }
    }

    // MARK: - Judge Reveal

    private var judgeRevealScreen: some View {
        ScrollView {
            VStack(spacing:18) {
                scoreHeader.padding(.top,14)
                if isPerfect && perfectFlash {
                    Text("PERFECT EXECUTION")
                        .font(.system(size:19,weight:.black,design:.monospaced)).foregroundStyle(.yellow)
                        .shadow(color:.yellow.opacity(0.7),radius:20).tracking(3).transition(.scale.combined(with:.opacity))
                }
                courtCanvas.padding(.horizontal,20)
                crowdMeter.padding(.horizontal,24)
                judgeCards.padding(.horizontal,20)
                if judgeScoresRevealed.allSatisfy({$0}) {
                    roundTotalBlock
                    if let last = aiRoundScores.last {
                        HStack(spacing:6) {
                            Image(systemName:"person.fill").font(.system(size:10)).foregroundStyle(.red)
                            Text("KAI NEXUS scored \(last) this round").font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                if !playerRoundScores.isEmpty { scoreboard }
                Spacer(minLength:40)
            }
        }
    }

    private var crowdMeter: some View {
        VStack(spacing:6) {
            HStack { Text("CROWD ENERGY").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(.secondary)
                Spacer(); Text(crowdLabel).font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(accent) }
            GeometryReader { g in
                ZStack(alignment:.leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height:10)
                    Capsule().fill(LinearGradient(colors:[Theme.brandBlue,accent,.yellow.opacity(0.9)],startPoint:.leading,endPoint:.trailing))
                        .frame(width:g.size.width*crowdLevel,height:10).animation(.spring(response:0.7,dampingFraction:0.6),value:crowdLevel)
                }
            }.frame(height:10)
        }
    }

    private var crowdLabel: String {
        if crowdLevel >= 0.9 { return "ON FIRE" }
        if crowdLevel >= 0.75 { return "ELECTRIC" }
        if crowdLevel >= 0.60 { return "HYPED" }
        if crowdLevel >= 0.40 { return "BUILDING" }
        return "WARMING UP"
    }

    private var judgeCards: some View {
        VStack(spacing:10) {
            Text("JUDGE SCORES").font(.system(size:10,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(3)
            HStack(spacing:12) {
                judgeCard(label:"JUDGE 1", score:currentJ1, revealed:safeRevealed(0))
                judgeCard(label:"JUDGE 2", score:currentJ2, revealed:safeRevealed(1))
                judgeCard(label:"JUDGE 3", score:currentJ3, revealed:safeRevealed(2))
            }
        }
    }

    private func judgeCard(label:String, score:Int, revealed:Bool) -> some View {
        VStack(spacing:8) {
            Text(label).font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(1)
            ZStack {
                RoundedRectangle(cornerRadius:14).fill(revealed ? accent.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(revealed ? accent.opacity(0.3) : Color.white.opacity(0.06),lineWidth:1))
                    .frame(height:72)
                if revealed {
                    Text("\(score)").font(.system(size:38,weight:.black,design:.monospaced)).foregroundStyle(.white)
                        .transition(.scale(scale:0.3).combined(with:.opacity))
                } else {
                    Text("?").font(.system(size:38,weight:.black,design:.monospaced)).foregroundStyle(.white.opacity(0.10))
                }
            }
            miniBar(value:revealed ? Double(score)/10.0 : 0, color:revealed ? judgeScoreColor(score) : accent)
        }.frame(maxWidth:.infinity)
    }

    private func judgeScoreColor(_ s:Int)->Color {
        if s >= 9 { return .yellow }; if s >= 7 { return Theme.brandCyan }; if s >= 5 { return .green }; return .red
    }

    private var roundTotalBlock: some View {
        let total = currentJ1+currentJ2+currentJ3
        return VStack(spacing:6) {
            Text("\(total)").font(.system(size:60,weight:.black,design:.monospaced)).foregroundStyle(.white)
                .shadow(color:accent.opacity(0.4),radius:16).contentTransition(.numericText())
            Text(currentMessage).font(.system(size:14,weight:.black,design:.monospaced)).foregroundStyle(accent).tracking(2)
            Text("ROUND \(currentRound) SCORE").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2)
        }.padding(.vertical,8).transition(.scale.combined(with:.opacity))
    }

    private var scoreboard: some View {
        VStack(alignment:.leading,spacing:6) {
            Text("SCOREBOARD").font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2).padding(.leading,4)
            ForEach(playerRoundScores,id:\.round) { r in
                HStack(spacing:10) {
                    Text("R\(r.round)").font(.system(size:10,weight:.black,design:.monospaced)).foregroundStyle(accent).frame(width:24)
                    Image(systemName:r.style.icon).font(.system(size:12)).foregroundStyle(.white.opacity(0.6)).frame(width:20)
                    Text(r.style.name).font(.system(size:10,design:.monospaced)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(r.j1)+\(r.j2)+\(r.j3)").font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary)
                    Text("\(r.total)").font(.system(size:14,weight:.black,design:.monospaced)).foregroundStyle(.white).frame(width:36)
                    Image(systemName:r.playerWon ? "arrow.up.circle.fill" : "arrow.down.circle").font(.system(size:12))
                        .foregroundStyle(r.playerWon ? .green : .red)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius:12).fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius:12).stroke(Theme.cardBorder,lineWidth:0.5)))
            }
        }.padding(.horizontal,20)
    }

    // MARK: - Round Transition

    private var roundTransitionOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing:16) {
                if let last = playerRoundScores.last {
                    Text(last.playerWon ? "ROUND WON" : "ROUND LOST")
                        .font(.system(size:10,weight:.black,design:.monospaced))
                        .foregroundStyle(last.playerWon ? .green : .red).tracking(3)
                }
                Text("ROUND \(currentRound) of \(TOTAL_ROUNDS)").font(.system(size:34,weight:.black)).italic().foregroundStyle(.white)
                HStack(spacing:20) {
                    VStack(spacing:2) {
                        Text("\(playerTotal)").font(.system(size:28,weight:.black,design:.monospaced)).foregroundStyle(accent)
                        Text("YOU").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary)
                    }
                    Text("VS").font(.system(size:13,weight:.black,design:.monospaced)).foregroundStyle(.secondary)
                    VStack(spacing:2) {
                        Text("\(aiTotal)").font(.system(size:28,weight:.black,design:.monospaced)).foregroundStyle(.red)
                        Text("KAI").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary)
                    }
                }
                Button { withAnimation { phase = .styleSelect } } label: {
                    Text("CONTINUE").font(.system(.subheadline,design:.monospaced,weight:.black)).foregroundStyle(.black)
                        .padding(.horizontal,36).padding(.vertical,14).background(accent).clipShape(.rect(cornerRadius:14))
                        .shadow(color:accent.opacity(0.3),radius:10)
                }.padding(.top,12)
            }
        }
    }

    // MARK: - Result

    private var resultScreen: some View {
        let winner: ResultScreen.ResultWinner = playerTotal > aiTotal ? .p1 : playerTotal < aiTotal ? .p2 : .draw
        return ResultScreen(
            winner: winner, p1Score: playerTotal, p2Score: aiTotal, title: "Dunk Contest", accentColor: accent,
            prqGain: PRQ.modeReward(mode:.basketballDunkContest, won:playerTotal>aiTotal, tied:playerTotal==aiTotal,
                                    combo:playerRoundScores.filter(\.playerWon).count, criticals:playerRoundScores.filter(\.isPerfect).count,
                                    scoreDifferential:max(0,playerTotal-aiTotal)),
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: PRQ.attributeLabel(for:.basketballDunkContest),
            modeAttributeValue: PRQ.attributeValue(prq:viewModel.effectiveMetrics.prqScore, for:.basketballDunkContest),
            onReturn: { awardShards(winner:winner); dismiss() }
        )
    }

    // MARK: - Shared sub-views

    private var styleTag: some View {
        HStack(spacing:8) {
            Image(systemName:selectedStyle.icon).font(.system(size:13,weight:.bold)).foregroundStyle(accent)
            Text(selectedStyle.name.uppercased()).font(.system(size:11,weight:.black,design:.monospaced)).foregroundStyle(accent).tracking(2)
        }
        .padding(.horizontal,14).padding(.vertical,7)
        .background(Capsule().fill(accent.opacity(0.08)).overlay(Capsule().stroke(accent.opacity(0.2),lineWidth:1)))
    }

    private func miniBar(value:Double, color:Color) -> some View {
        GeometryReader { g in
            ZStack(alignment:.leading) {
                Capsule().fill(Color.white.opacity(0.06)).frame(height:4)
                Capsule().fill(color).frame(width:g.size.width*max(0,min(1,value)),height:4).animation(.spring(response:0.4),value:value)
            }
        }.frame(height:4)
    }

    private func diffBar(difficulty:Double) -> some View {
        HStack(spacing:4) {
            Text("DIFF").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary)
            GeometryReader { g in
                ZStack(alignment:.leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height:4)
                    Capsule().fill(difficulty >= 0.85 ? Color.red : difficulty >= 0.70 ? Color.orange : Theme.foundationGreen)
                        .frame(width:g.size.width*difficulty,height:4)
                }
            }.frame(height:4)
        }
    }

    private func powerBarColors(_ level:Double) -> [Color] {
        if level >= 78 { return [Theme.foundationGreen,.green,.yellow] }
        if level >= 55 { return [Theme.brandBlue,accent] }
        return [.white.opacity(0.3),.white.opacity(0.55)]
    }

    private func safeRevealed(_ i:Int)->Bool { judgeScoresRevealed.indices.contains(i) && judgeScoresRevealed[i] }

    // MARK: - Logic

    private func resetApproach() {
        powerLevel = 0; approachReleased = false; powerFilling = false
        execProgress = 0; postDunk = false; swipeRegistered = false; swipeDragOffset = .zero
    }

    private func startCharge() {
        guard !powerFilling, !approachReleased else { return }
        powerFilling = true
        powerTask?.cancel()
        powerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for:.milliseconds(16))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard powerFilling else { return }
                    let prevInZone = powerLevel >= 78 && powerLevel <= 90
                    powerLevel = min(100, powerLevel + 1.6)
                    let nowInZone = powerLevel >= 78 && powerLevel <= 90
                    if !prevInZone && nowInZone { impactMed.impactOccurred() }
                    if powerLevel >= 100 { releasePower() }
                }
            }
        }
    }

    private func releasePower() {
        guard !approachReleased else { return }
        approachReleased = true; powerFilling = false; powerTask?.cancel()
        impactMed.impactOccurred()
        let p = powerLevel
        let quality: Double
        switch p {
        case 78...90:  quality = 1.0
        case 65..<78:  quality = 0.7 + (p-65)/13.0*0.3
        case 90..<100: quality = 1.0 - (p-90)/10.0*0.4
        case 40..<65:  quality = 0.3 + (p-40)/25.0*0.4
        default:       quality = max(0.1, p/100.0*0.3)
        }
        approachQuality = quality
        Task {
            try? await Task.sleep(for:.milliseconds(180))
            await MainActor.run { swipeRegistered = false; swipeDragOffset = .zero; executionQuality = 0; execProgress = 0; phase = .execution }
        }
    }

    private func registerSwipe(translation:CGSize) {
        guard !swipeRegistered else { return }
        let mag = sqrt(translation.width*translation.width + translation.height*translation.height)
        let magQ = min(1.0, mag/160.0)
        let dirQ = swipeDirectionQuality(style:selectedStyle, translation:translation)
        executionQuality = magQ*0.4 + dirQ*0.6
        swipeRegistered = true; swipeFlash = true; swipeDragOffset = .zero
        impactHvy.impactOccurred()
        Task { try? await Task.sleep(for:.milliseconds(180)); await MainActor.run { swipeFlash = false } }
        // Animate dunk arc then score
        execAnimTask?.cancel()
        execAnimTask = Task {
            let steps = 48
            for step in 0..<steps {
                try? await Task.sleep(for:.milliseconds(16))
                guard !Task.isCancelled else { return }
                await MainActor.run { execProgress = Double(step+1)/Double(steps) }
            }
            await MainActor.run { postDunk = true; scoreRound() }
        }
    }

    private func swipeDirectionQuality(style:DunkStyle, translation:CGSize)->Double {
        let tx = translation.width; let ty = translation.height
        let total = abs(tx)+abs(ty)+1
        switch style.id {
        case "power_slam","tomahawk","alley_oop": return max(0,-ty)/total
        case "windmill","three_sixty":            return abs(tx)/total
        case "reverse":                           return max(0,ty)/total
        case "between_legs":                      return min(1.0,sqrt(tx*tx+ty*ty)/130.0)
        default:                                  return 0.6
        }
    }

    private func scoreRound() {
        let combinedQ = approachQuality*0.45 + executionQuality*0.55
        let diff      = selectedStyle.difficulty
        let perfect   = approachQuality >= 0.92 && executionQuality >= 0.88
        isPerfect = perfect
        if perfect { impactHvy.impactOccurred() }

        let prqBoost = min(1.0, viewModel.effectiveMetrics.prqScore/100.0)
        let rawBase  = 4.0 + combinedQ*4.0*diff + prqBoost*1.0
        let base     = min(10, max(1, Int(rawBase.rounded())))
        let pb = perfect ? 1 : 0
        let j1 = min(10,base+pb+Int.random(in:0...1))
        let j2 = min(10,base+pb+Int.random(in:0...1))
        let j3 = min(10,base+pb+Int.random(in:0...1))
        let total = j1+j2+j3

        let msg: String
        if perfect            { msg = "PERFECT EXECUTION" }
        else if total >= 27   { msg = "LEGENDARY!" }
        else if total >= 23   { msg = "CROWD GOES WILD!" }
        else if total >= 19   { msg = "POWERFUL!" }
        else if total >= 15   { msg = "SOLID DUNK" }
        else                  { msg = "NEEDS WORK" }

        let aiScore   = Int.random(in:18...27)
        let playerWon = total > aiScore
        currentJ1 = j1; currentJ2 = j2; currentJ3 = j3; currentMessage = msg
        playerRoundScores.append(RoundResult(round:currentRound,style:selectedStyle,j1:j1,j2:j2,j3:j3,
                                             total:total,message:msg,isPerfect:perfect,aiScore:aiScore,playerWon:playerWon))
        aiRoundScores.append(aiScore)
        playerTotal += total; aiTotal += aiScore
        judgeScoresRevealed = [false,false,false]; crowdLevel = 0
        phase = .judgeReveal

        if perfect { withAnimation(.spring(response:0.3)) { perfectFlash = true }
            Task { try? await Task.sleep(for:.seconds(1.5)); await MainActor.run { withAnimation { perfectFlash = false } } }
        }
        startJudgeReveal(combinedQ:combinedQ, styleDiff:diff)
    }

    private func startJudgeReveal(combinedQ:Double, styleDiff:Double) {
        judgeRevealTask?.cancel()
        judgeRevealTask = Task {
            for i in 0..<3 {
                try? await Task.sleep(for:.milliseconds(600 + Int64(i)*420))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response:0.3,dampingFraction:0.6)) { judgeScoresRevealed[i] = true }
                    impactMed.impactOccurred()
                }
            }
            try? await Task.sleep(for:.milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                let target = min(1.0,(combinedQ*0.6+styleDiff*0.4)*selectedStyle.crowdPeak)
                withAnimation(.spring(response:0.8,dampingFraction:0.5)) { crowdLevel = target }
            }
            try? await Task.sleep(for:.seconds(4.2))
            guard !Task.isCancelled else { return }
            await MainActor.run { advanceAfterReveal() }
        }
    }

    private func advanceAfterReveal() {
        if currentRound >= TOTAL_ROUNDS { phase = .result } else { currentRound += 1; phase = .roundTransition }
    }

    private func awardShards(winner:ResultScreen.ResultWinner) {
        guard !shardsAwarded else { return }
        shardsAwarded = true
        viewModel.profile.evolutionShards += winner == .p1 ? 50 : winner == .draw ? 25 : 15
    }
}
