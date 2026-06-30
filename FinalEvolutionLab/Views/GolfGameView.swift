import SwiftUI

// MARK: - Supporting Types

private enum GolfPhase { case ready, aiming, result }

private struct GolfHoleResult {
    let hole: Int; let strokes: Int; let scoreName: String; let scoreVsPar: Int
}

private enum GolfObstacle: String {
    case sandTrap = "Sand Trap", water = "Water"
    var strokePenalty: Int { self == .water ? 2 : 1 }
}

private struct GolfObstacleLayout: Identifiable {
    let id = UUID()
    let type: GolfObstacle
    let position: CGPoint   // normalized 0–1, origin bottom-left
    let size: CGSize        // normalized
}

private enum ShotState { case idle, aiming, draggingBack, ballFlying, landed }

// MARK: - Canvas View

private struct GolfCourseCanvas: View {
    let ballX: Double;      let ballY: Double
    let ballProgress: Double
    let ballStartX: Double; let ballStartY: Double
    let ballEndX: Double;   let ballEndY: Double
    let holePosition: CGPoint
    let obstacles: [GolfObstacleLayout]
    let aimAngle: Double;   let pullDistance: CGFloat
    let shotState: ShotState; let golferPose: String
    let crowdExcitement: Double

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                var d = GolfDrawer(
                    t: tl.date.timeIntervalSinceReferenceDate, size: size,
                    ballX: ballX, ballY: ballY, ballProgress: ballProgress,
                    ballStartX: ballStartX, ballStartY: ballStartY,
                    ballEndX: ballEndX, ballEndY: ballEndY,
                    holePosition: holePosition, obstacles: obstacles,
                    aimAngle: aimAngle, pullDistance: pullDistance,
                    shotState: shotState, golferPose: golferPose,
                    crowdExcitement: crowdExcitement
                )
                d.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Drawer

private struct GolfDrawer {
    let t: Double
    let W: CGFloat; let H: CGFloat
    let ballX: Double;      let ballY: Double;  let ballProgress: Double
    let ballStartX: Double; let ballStartY: Double
    let ballEndX: Double;   let ballEndY: Double
    let holePosition: CGPoint
    let obstacles: [GolfObstacleLayout]
    let aimAngle: Double;   let pullDistance: CGFloat
    let shotState: ShotState; let golferPose: String
    let crowdExcitement: Double

    init(t: Double, size: CGSize,
         ballX: Double, ballY: Double, ballProgress: Double,
         ballStartX: Double, ballStartY: Double,
         ballEndX: Double, ballEndY: Double,
         holePosition: CGPoint, obstacles: [GolfObstacleLayout],
         aimAngle: Double, pullDistance: CGFloat,
         shotState: ShotState, golferPose: String, crowdExcitement: Double) {
        self.t = t; W = size.width; H = size.height
        self.ballX = ballX; self.ballY = ballY; self.ballProgress = ballProgress
        self.ballStartX = ballStartX; self.ballStartY = ballStartY
        self.ballEndX = ballEndX; self.ballEndY = ballEndY
        self.holePosition = holePosition; self.obstacles = obstacles
        self.aimAngle = aimAngle; self.pullDistance = pullDistance
        self.shotState = shotState; self.golferPose = golferPose
        self.crowdExcitement = crowdExcitement
    }

    // Coord helpers: normalized (0–1, origin bottom-left) → canvas (origin top-left)
    func nx(_ n: Double) -> CGFloat { CGFloat(n) * W }
    func ny(_ n: Double) -> CGFloat { (1.0 - CGFloat(n)) * H }

    var hx: CGFloat { CGFloat(holePosition.x) * W }
    var hy: CGFloat { (1.0 - CGFloat(holePosition.y)) * H }
    var ballCX: CGFloat { nx(ballX) }
    var ballCY: CGFloat { ny(ballY) }

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(&ctx)
        drawTrees(&ctx)
        drawFairway(&ctx)
        drawObstacles(&ctx)
        drawGreen(&ctx)
        drawFlag(&ctx)
        if shotState != .ballFlying { drawAimLine(&ctx) }
        if ballProgress >= 0 { drawTrail(&ctx) }
        drawBall(&ctx)
        if ballProgress < 0.3 || ballProgress < 0 { drawGolfer(&ctx) }
    }

    private func drawSky(_ ctx: inout GraphicsContext) {
        let skyH = H * 0.08
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: skyH)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red:0.38,green:0.65,blue:0.88),
                                      Color(red:0.55,green:0.78,blue:0.92)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: skyH)))

        // Clouds
        for i in 0..<3 {
            let cx = W * CGFloat(0.2 + Double(i) * 0.3) + CGFloat(sin(t * 0.04 + Double(i))) * 8
            let cy = skyH * 0.45
            for j in 0..<4 {
                let dx = CGFloat(j - 1) * 14
                let dy = CGFloat(j % 2) * -5
                let r: CGFloat = j == 1 || j == 2 ? 10 : 7
                let cloud = Path(ellipseIn: CGRect(x: cx + dx - r, y: cy + dy - r, width: r*2, height: r*2))
                ctx.fill(cloud, with: .color(.white.opacity(0.82)))
            }
        }
    }

    private func drawTrees(_ ctx: inout GraphicsContext) {
        let treeBase = H * 0.08
        let treeH = H * 0.10
        // Left-side trees
        for i in 0..<7 {
            let tx = W * 0.04 + CGFloat(i) * W * 0.035
            let th = treeH * CGFloat(0.75 + sin(Double(i) * 2.1) * 0.25)
            let sway = CGFloat(sin(t * 0.6 + Double(i) * 1.4)) * 1.5
            // Trunk
            var trunk = Path()
            trunk.move(to: CGPoint(x: tx + sway, y: treeBase + th))
            trunk.addLine(to: CGPoint(x: tx + sway, y: treeBase + th * 0.65))
            ctx.stroke(trunk, with: .color(Color(red:0.35,green:0.22,blue:0.10)), lineWidth: 2.5)
            // Canopy
            let canopy = Path(ellipseIn: CGRect(x: tx + sway - 11, y: treeBase, width: 22, height: th * 0.7))
            ctx.fill(canopy, with: .color(Color(red:0.10,green:0.28,blue:0.12)))
        }
        // Right-side trees
        for i in 0..<7 {
            let tx = W * 0.96 - CGFloat(i) * W * 0.035
            let th = treeH * CGFloat(0.75 + sin(Double(i) * 1.9 + 0.7) * 0.25)
            let sway = CGFloat(sin(t * 0.6 + Double(i) * 1.6 + 2.0)) * 1.5
            var trunk = Path()
            trunk.move(to: CGPoint(x: tx + sway, y: treeBase + th))
            trunk.addLine(to: CGPoint(x: tx + sway, y: treeBase + th * 0.65))
            ctx.stroke(trunk, with: .color(Color(red:0.35,green:0.22,blue:0.10)), lineWidth: 2.5)
            let canopy = Path(ellipseIn: CGRect(x: tx + sway - 11, y: treeBase, width: 22, height: th * 0.7))
            ctx.fill(canopy, with: .color(Color(red:0.10,green:0.28,blue:0.12)))
        }
    }

    private func drawFairway(_ ctx: inout GraphicsContext) {
        let top = H * 0.16
        // Rough (dark green base)
        ctx.fill(Path(CGRect(x: 0, y: top, width: W, height: H - top)),
                 with: .color(Color(red:0.08,green:0.22,blue:0.10)))

        // Perspective fairway trapezoid: narrow at top (far), wide at bottom (near)
        let topL = CGPoint(x: W * 0.28, y: top)
        let topR = CGPoint(x: W * 0.72, y: top)
        let botL = CGPoint(x: W * 0.04, y: H)
        let botR = CGPoint(x: W * 0.96, y: H)

        var fw = Path()
        fw.move(to: topL); fw.addLine(to: topR)
        fw.addLine(to: botR); fw.addLine(to: botL)
        fw.closeSubpath()
        ctx.fill(fw, with: .color(Color(red:0.16,green:0.40,blue:0.17)))

        // Mowing stripes
        let stripes = 18
        for i in 0..<stripes {
            if i % 2 == 0 { continue }
            let t0 = CGFloat(i) / CGFloat(stripes)
            let t1 = CGFloat(i + 1) / CGFloat(stripes)
            let y0 = top + t0 * (H - top)
            let y1 = top + t1 * (H - top)
            let x0l = lerp(topL.x, botL.x, t0); let x0r = lerp(topR.x, botR.x, t0)
            let x1l = lerp(topL.x, botL.x, t1); let x1r = lerp(topR.x, botR.x, t1)
            var stripe = Path()
            stripe.move(to: CGPoint(x: x0l, y: y0)); stripe.addLine(to: CGPoint(x: x0r, y: y0))
            stripe.addLine(to: CGPoint(x: x1r, y: y1)); stripe.addLine(to: CGPoint(x: x1l, y: y1))
            stripe.closeSubpath()
            ctx.fill(stripe, with: .color(Color(red:0.18,green:0.44,blue:0.19).opacity(0.55)))
        }
    }

    private func drawObstacles(_ ctx: inout GraphicsContext) {
        for obs in obstacles {
            let ox = nx(obs.position.x)
            let oy = ny(obs.position.y)
            let ow = CGFloat(obs.size.width) * W
            let oh = CGFloat(obs.size.height) * H

            if obs.type == .sandTrap {
                let rect = CGRect(x: ox - ow/2, y: oy - oh/2, width: ow, height: oh)
                ctx.fill(Path(ellipseIn: rect), with: .color(Color(red:0.88,green:0.80,blue:0.52)))
                // Texture stippling
                for di in 0..<14 {
                    let angle = Double(di) * .pi * 2 / 14
                    let r = ow * 0.33
                    let dx = ox + r * CGFloat(cos(angle)) * 0.9
                    let dy = oy + (oh / ow) * r * CGFloat(sin(angle))
                    ctx.fill(Path(ellipseIn: CGRect(x: dx-1.5, y: dy-1.5, width: 3, height: 3)),
                             with: .color(Color(red:0.70,green:0.62,blue:0.36).opacity(0.7)))
                }
                // "S" label
                ctx.draw(Text("S").font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red:0.50,green:0.40,blue:0.15)),
                         at: CGPoint(x: ox, y: oy), anchor: .center)
            } else {
                // Water with animated shimmer
                let rect = CGRect(x: ox - ow/2, y: oy - oh/2, width: ow, height: oh)
                ctx.fill(Path(ellipseIn: rect), with: .linearGradient(
                    Gradient(colors: [Color(red:0.18,green:0.48,blue:0.88),
                                      Color(red:0.10,green:0.30,blue:0.70)]),
                    startPoint: CGPoint(x: ox - ow/2, y: oy),
                    endPoint: CGPoint(x: ox + ow/2, y: oy)))
                for si in 0..<4 {
                    let phase = fmod(t * 1.2 + Double(si) * 0.7, 1.0)
                    let sx = ox - ow * 0.35 + CGFloat(phase) * ow * 0.7
                    var shimmer = Path()
                    shimmer.move(to: CGPoint(x: sx - 6, y: oy - oh * 0.12))
                    shimmer.addQuadCurve(to: CGPoint(x: sx + 6, y: oy + oh * 0.12),
                                         control: CGPoint(x: sx + 3, y: oy))
                    ctx.stroke(shimmer, with: .color(.white.opacity(0.38)), lineWidth: 1.2)
                }
                ctx.draw(Text("W").font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8)),
                         at: CGPoint(x: ox, y: oy), anchor: .center)
            }
        }
    }

    private func drawGreen(_ ctx: inout GraphicsContext) {
        let gr: CGFloat = 48
        // Fringe
        ctx.fill(Path(ellipseIn: CGRect(x: hx-gr-10, y: hy-gr-10, width: (gr+10)*2, height: (gr+10)*2)),
                 with: .color(Color(red:0.18,green:0.50,blue:0.20)))
        // Green surface
        ctx.fill(Path(ellipseIn: CGRect(x: hx-gr, y: hy-gr, width: gr*2, height: gr*2)),
                 with: .color(Color(red:0.22,green:0.62,blue:0.25)))
        // Contour rings
        for ri in [0.75, 0.50, 0.25] as [CGFloat] {
            let rr = gr * ri
            ctx.stroke(Path(ellipseIn: CGRect(x: hx-rr, y: hy-rr, width: rr*2, height: rr*2)),
                       with: .color(Color(red:0.20,green:0.56,blue:0.22).opacity(0.45)), lineWidth: 0.6)
        }
        // Cup shadow glow
        var gc = ctx
        gc.addFilter(.blur(radius: 4))
        gc.fill(Path(ellipseIn: CGRect(x: hx-8, y: hy-4, width: 16, height: 10)),
                with: .color(.black.opacity(0.55)))
        // Cup
        ctx.fill(Path(ellipseIn: CGRect(x: hx-6, y: hy-5, width: 12, height: 10)),
                 with: .color(.black.opacity(0.90)))
    }

    private func drawFlag(_ ctx: inout GraphicsContext) {
        let poleH: CGFloat = 36
        let poleBase = CGPoint(x: hx, y: hy - 5)
        let poleTop  = CGPoint(x: hx, y: hy - 5 - poleH)

        // Pole shadow
        var shadowPole = Path()
        shadowPole.move(to: CGPoint(x: poleBase.x + 2, y: poleBase.y + 2))
        shadowPole.addLine(to: CGPoint(x: poleTop.x + 2, y: poleTop.y + 2))
        ctx.stroke(shadowPole, with: .color(.black.opacity(0.25)), lineWidth: 2)

        // Pole
        var pole = Path()
        pole.move(to: poleBase); pole.addLine(to: poleTop)
        ctx.stroke(pole, with: .color(Color(white: 0.92)), lineWidth: 1.8)

        // Waving flag
        let wave = CGFloat(sin(t * 3.8)) * 5
        let wave2 = CGFloat(sin(t * 3.8 + 1.2)) * 3
        var flag = Path()
        flag.move(to: poleTop)
        flag.addCurve(
            to:       CGPoint(x: poleTop.x + 18, y: poleTop.y + 10 + wave),
            control1: CGPoint(x: poleTop.x + 6,  y: poleTop.y - 1 + wave2),
            control2: CGPoint(x: poleTop.x + 14, y: poleTop.y + 4 + wave)
        )
        flag.addLine(to: CGPoint(x: poleTop.x, y: poleTop.y + 12))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(Color(red:0.10,green:0.72,blue:0.32)))
        ctx.stroke(flag, with: .color(Color(red:0.08,green:0.55,blue:0.25)), lineWidth: 0.5)
    }

    private func drawAimLine(_ ctx: inout GraphicsContext) {
        guard shotState == .idle || shotState == .draggingBack else { return }
        let power = min(1.0, Double(pullDistance) / 80.0)
        guard power > 0.02 else { return }

        let radians = aimAngle * .pi / 180.0
        let dist = CGFloat(power * 0.55) * W
        let ex = ballCX + dist * CGFloat(sin(radians))
        let ey = ballCY - dist * CGFloat(cos(radians))
        let peakH: CGFloat = CGFloat(power) * 70

        // Dashed arc (draw every other segment)
        let segs = 14
        for i in 0..<segs {
            if i % 2 == 1 { continue }
            let t0 = CGFloat(i) / CGFloat(segs)
            let t1 = CGFloat(i + 1) / CGFloat(segs)
            let ax = ballCX + (ex - ballCX) * t0
            let ay = ballCY + (ey - ballCY) * t0 - peakH * 4 * t0 * (1 - t0)
            let bxp = ballCX + (ex - ballCX) * t1
            let byp = ballCY + (ey - ballCY) * t1 - peakH * 4 * t1 * (1 - t1)
            var seg = Path()
            seg.move(to: CGPoint(x: ax, y: ay)); seg.addLine(to: CGPoint(x: bxp, y: byp))
            ctx.stroke(seg, with: .color(Color(red:0.3,green:0.85,blue:0.4).opacity(0.75)), lineWidth: 1.8)
        }

        // Target ring (pulse)
        let pulse = CGFloat(sin(t * 5)) * 2
        let ring = Path(ellipseIn: CGRect(x: ex - 10 - pulse, y: ey - 10 - pulse,
                                          width: (10 + pulse) * 2, height: (10 + pulse) * 2))
        ctx.stroke(ring, with: .color(Color(red:0.3,green:0.85,blue:0.4).opacity(0.55)), lineWidth: 1.5)
    }

    private func drawTrail(_ ctx: inout GraphicsContext) {
        guard ballProgress >= 0 else { return }
        let sx = nx(ballStartX); let sy = ny(ballStartY)
        let ex = nx(ballEndX);   let ey = ny(ballEndY)
        let peakH: CGFloat = 85
        for g in 1...4 {
            let gep = CGFloat(max(0, ballProgress - Double(g) * 0.06))
            let tx = sx + (ex - sx) * gep
            let ty = sy + (ey - sy) * gep - peakH * 4 * gep * (1 - gep)
            let r: CGFloat = CGFloat(5 - g) * 0.9
            let alpha = (1.0 - Double(g) * 0.22) * 0.55
            ctx.fill(Path(ellipseIn: CGRect(x: tx - r, y: ty - r, width: r*2, height: r*2)),
                     with: .color(.white.opacity(alpha)))
        }
    }

    private func drawBall(_ ctx: inout GraphicsContext) {
        let bxPos: CGFloat
        let byPos: CGFloat
        if ballProgress >= 0 {
            let ep = CGFloat(ballProgress)
            let sx = nx(ballStartX); let sy = ny(ballStartY)
            let ex = nx(ballEndX);   let ey = ny(ballEndY)
            let peakH: CGFloat = 85
            bxPos = sx + (ex - sx) * ep
            byPos = sy + (ey - sy) * ep - peakH * 4 * ep * (1 - ep)
        } else {
            bxPos = ballCX; byPos = ballCY
        }

        let r: CGFloat = ballProgress >= 0 ? max(4, 8 - CGFloat(ballProgress) * 3.5) : 8

        // Drop shadow
        var gc = ctx
        gc.addFilter(.blur(radius: r * 0.6))
        gc.fill(Path(ellipseIn: CGRect(x: bxPos - r * 0.9, y: byPos + r * 0.4,
                                       width: r * 1.8, height: r * 0.7)),
                with: .color(.black.opacity(0.28)))

        // Ball body
        ctx.fill(Path(ellipseIn: CGRect(x: bxPos-r, y: byPos-r, width: r*2, height: r*2)),
                 with: .radialGradient(
                    Gradient(colors: [.white, Color(white:0.78)]),
                    center: CGPoint(x: bxPos - r * 0.3, y: byPos - r * 0.3),
                    startRadius: 0, endRadius: r * 1.2))

        // Dimple seam
        var seam = Path()
        seam.addArc(center: CGPoint(x: bxPos, y: byPos), radius: r - 2,
                    startAngle: .degrees(30), endAngle: .degrees(150), clockwise: false)
        ctx.stroke(seam, with: .color(Color(white:0.55).opacity(0.45)), lineWidth: 0.8)

        // Specular
        ctx.fill(Path(ellipseIn: CGRect(x: bxPos - r*0.5, y: byPos - r*0.65, width: r*0.4, height: r*0.25)),
                 with: .color(.white.opacity(0.9)))
    }

    private func drawGolfer(_ ctx: inout GraphicsContext) {
        // Golfer stands behind the ball (higher canvas Y = further from hole)
        let gx = ballCX
        let headY  = ballCY + 10
        let waistY = ballCY + 22
        let feetY  = ballCY + 34

        let jersey = Color(red: 0.92, green: 0.75, blue: 0.25)
        let skin   = Color(red: 0.94, green: 0.80, blue: 0.68)
        let pants  = Color(red: 0.20, green: 0.22, blue: 0.50)
        let club   = Color(white: 0.65)

        // Hat
        let hatBrim = Path(ellipseIn: CGRect(x: gx-7, y: headY-8, width: 14, height: 5))
        ctx.fill(hatBrim, with: .color(Color(red:0.15,green:0.50,blue:0.20)))
        let hatTop = Path(ellipseIn: CGRect(x: gx-4.5, y: headY-14, width: 9, height: 8))
        ctx.fill(hatTop, with: .color(Color(red:0.12,green:0.42,blue:0.16)))

        // Head
        ctx.fill(Path(ellipseIn: CGRect(x: gx-5.5, y: headY-5.5, width: 11, height: 11)), with: .color(skin))

        // Body
        var body = Path()
        body.move(to: CGPoint(x: gx, y: headY + 4))
        body.addLine(to: CGPoint(x: gx, y: waistY))
        ctx.stroke(body, with: .color(jersey), lineWidth: 4)

        // Arms + club
        switch pose {
        case "backswing":
            var arms = Path()
            arms.move(to: CGPoint(x: gx - 9, y: headY + 12))
            arms.addLine(to: CGPoint(x: gx, y: headY + 7))
            arms.addLine(to: CGPoint(x: gx + 8, y: headY + 4))
            arms.addLine(to: CGPoint(x: gx + 13, y: headY - 6))
            ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)
            var cl = Path()
            cl.move(to: CGPoint(x: gx + 13, y: headY - 6))
            cl.addLine(to: CGPoint(x: gx + 20, y: headY - 14))
            ctx.stroke(cl, with: .color(club), lineWidth: 1.6)

        case "impact":
            var arms = Path()
            arms.move(to: CGPoint(x: gx + 10, y: headY + 8))
            arms.addLine(to: CGPoint(x: gx, y: headY + 6))
            arms.addLine(to: CGPoint(x: gx - 11, y: headY + 9))
            ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)
            var cl = Path()
            cl.move(to: CGPoint(x: gx - 11, y: headY + 9))
            cl.addLine(to: CGPoint(x: gx - 18, y: headY + 7))
            ctx.stroke(cl, with: .color(club), lineWidth: 1.6)
            // Impact spark
            for sp in 0..<6 {
                let a = Double(sp) * .pi / 3
                let sr: CGFloat = 6
                var spark = Path()
                spark.move(to: CGPoint(x: gx - 19, y: headY + 7))
                spark.addLine(to: CGPoint(x: gx - 19 + sr * CGFloat(cos(a)),
                                           y: headY + 7 + sr * CGFloat(sin(a))))
                ctx.stroke(spark, with: .color(Color(red:1,green:0.85,blue:0.2).opacity(0.8)), lineWidth: 1)
            }

        case "followthrough":
            var arms = Path()
            arms.move(to: CGPoint(x: gx + 8, y: headY + 12))
            arms.addLine(to: CGPoint(x: gx, y: headY + 7))
            arms.addLine(to: CGPoint(x: gx - 8, y: headY + 3))
            arms.addLine(to: CGPoint(x: gx - 14, y: headY - 7))
            ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)
            var cl = Path()
            cl.move(to: CGPoint(x: gx - 14, y: headY - 7))
            cl.addLine(to: CGPoint(x: gx - 20, y: headY - 16))
            ctx.stroke(cl, with: .color(club), lineWidth: 1.6)

        default: // address
            var arms = Path()
            arms.move(to: CGPoint(x: gx - 9, y: headY + 10))
            arms.addLine(to: CGPoint(x: gx, y: headY + 7))
            arms.addLine(to: CGPoint(x: gx + 9, y: headY + 10))
            ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)
            var cl = Path()
            cl.move(to: CGPoint(x: gx - 9, y: headY + 10))
            cl.addLine(to: CGPoint(x: gx - 10, y: ballCY + 4))
            cl.addLine(to: CGPoint(x: gx - 6, y: ballCY + 4))
            ctx.stroke(cl, with: .color(club), lineWidth: 1.6)
        }

        // Legs
        var legs = Path()
        legs.move(to: CGPoint(x: gx - 6, y: feetY))
        legs.addLine(to: CGPoint(x: gx, y: waistY))
        legs.addLine(to: CGPoint(x: gx + 6, y: feetY))
        ctx.stroke(legs, with: .color(pants), lineWidth: 2.8)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}

// MARK: - GolfGameView

struct GolfGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // MARK: Game state
    @State private var phase: GolfPhase = .ready
    @State private var currentHole: Int = 1
    @State private var currentStrokes: Int = 0
    @State private var totalStrokes: Int = 0
    @State private var holeResults: [GolfHoleResult] = []
    @State private var ballOnGreen: Bool = false
    @State private var shotState: ShotState = .idle

    // MARK: Shot mechanic
    @State private var aimAngle: Double = 0.0
    @State private var pullDistance: CGFloat = 0.0
    @State private var dragStartLocation: CGPoint = .zero

    // MARK: Ball position (normalized 0–1, origin bottom-left)
    @State private var ballX: Double = 0.5
    @State private var ballY: Double = 0.1

    // MARK: Ball animation arc
    @State private var ballProgress: Double = -1.0
    @State private var ballStartX: Double = 0.5
    @State private var ballStartY: Double = 0.1
    @State private var ballEndX: Double = 0.5
    @State private var ballEndY: Double = 0.5

    // MARK: Golfer
    @State private var golferPose: String = "address"

    // MARK: Hole layout
    @State private var holePosition: CGPoint = CGPoint(x: 0.5, y: 0.88)
    @State private var obstacles: [GolfObstacleLayout] = []

    // MARK: Feedback
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var penaltyText: String = ""
    @State private var showPenalty: Bool = false
    @State private var crowdExcitement: Double = 0.20

    // MARK: Hole transition
    @State private var showHoleCard: Bool = false
    @State private var holeCardText: String = ""
    @State private var holeCardColor: Color = .white

    // MARK: Rewards
    @State private var rewardGranted: Bool = false
    private let aiTotalStrokes: Int = Int.random(in: 27...45)
    private let XP_CAP = 500
    private let WIN_SHARDS = 50; private let DRAW_SHARDS = 25; private let LOSS_SHARDS = 15
    private let accentColor = Color(red: 0.3, green: 0.7, blue: 0.4)
    private let parPerHole = 3
    private var totalPar: Int { parPerHole * 9 }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(colors: [Color(red:0.02,green:0.08,blue:0.03), Theme.deepBlack],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Golf · Closest to Pin",
                    subtitle: "9 Holes · Par 3 Each · Drag to Aim & Shoot",
                    countdown: 3, accentColor: accentColor,
                    onComplete: { startHole() }
                )

            case .aiming:
                VStack(spacing: 0) {
                    holeHeader.padding(.top, 8)

                    ZStack {
                        GolfCourseCanvas(
                            ballX: ballX, ballY: ballY,
                            ballProgress: ballProgress,
                            ballStartX: ballStartX, ballStartY: ballStartY,
                            ballEndX: ballEndX, ballEndY: ballEndY,
                            holePosition: holePosition,
                            obstacles: obstacles,
                            aimAngle: aimAngle, pullDistance: pullDistance,
                            shotState: shotState, golferPose: golferPose,
                            crowdExcitement: crowdExcitement
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in onDragChanged(v) }
                                .onEnded   { v in onDragEnded(v) }
                        )

                        if showFeedback {
                            Text(feedbackText)
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .shadow(color: accentColor.opacity(0.7), radius: 14)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                        if showPenalty { penaltyOverlay }
                        if showHoleCard { holeCardOverlay }
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    controlPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                }

            case .result:
                let playerWon = totalStrokes < aiTotalStrokes
                let isDraw    = totalStrokes == aiTotalStrokes
                let scoreVsPar = totalStrokes - totalPar
                ResultScreen(
                    winner: playerWon ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: totalStrokes, p2Score: aiTotalStrokes,
                    title: "Golf · 9 Holes", accentColor: accentColor,
                    prqGain: playerWon ? 10 : (isDraw ? 4 : 2),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: scoreVsPar <= 0 ? "Under Par" : "Over Par",
                    modeAttributeValue: max(0, 1.0 - Double(abs(scoreVsPar)) / 18.0),
                    onReturn: { dismiss() }
                )
                .onAppear { grantShards(playerWon: playerWon, isDraw: isDraw) }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Hole Header

    private var holeHeader: some View {
        HStack(spacing: 12) {
            statCell(label: "HOLE",  value: "\(currentHole)")
            divider
            statCell(label: "PAR",   value: "\(parPerHole)", color: accentColor)
            divider
            statCell(label: "SHOTS", value: "\(currentStrokes)")
            divider
            let svp = totalStrokes - (holeResults.count * parPerHole)
            statCell(label: "TOTAL",
                     value: svp == 0 ? "E" : (svp > 0 ? "+\(svp)" : "\(svp)"),
                     color: svp < 0 ? accentColor : (svp == 0 ? .white : .red))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1)))
        .padding(.horizontal, 16)
    }

    private func statCell(label: String, value: String, color: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(2)
            Text(value).font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }.frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.cardBorder).frame(width: 1, height: 36)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("DIRECTION")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    ZStack {
                        Circle().fill(Theme.cardBackground).frame(width: 52, height: 52)
                            .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
                        Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold))
                            .foregroundStyle(accentColor)
                            .rotationEffect(.degrees(aimAngle))
                            .animation(.interactiveSpring(response: 0.15), value: aimAngle)
                    }
                }

                VStack(spacing: 4) {
                    Text("POWER")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.cardBackground)
                                .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Theme.brandCyan, accentColor, .yellow],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(0, geo.size.width * powerRatio))
                                .animation(.interactiveSpring(response: 0.1), value: pullDistance)
                        }
                    }.frame(height: 14)
                    Text("\(Int(powerRatio * 100))%")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1)))

            HStack {
                Image(systemName: "hand.draw.fill").font(.system(size: 10)).foregroundStyle(accentColor)
                Text("Drag to rotate aim · Pull back & release to shoot")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }

            if !holeResults.isEmpty { holeScoreSummary }
        }
    }

    private var powerRatio: CGFloat { min(1.0, pullDistance / 80.0) }

    // MARK: - Hole Score Summary

    private var holeScoreSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(holeResults, id: \.hole) { r in
                    VStack(spacing: 2) {
                        Text("H\(r.hole)").font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(r.strokes)").font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(scoreSymbol(r.scoreVsPar))
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(scoreColor(r.scoreVsPar))
                    }
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.cardBackground.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(scoreColor(r.scoreVsPar).opacity(0.4), lineWidth: 1)))
                }
            }.padding(.horizontal, 4)
        }
    }

    private func scoreSymbol(_ vsPar: Int) -> String {
        switch vsPar { case ..<(-1): "🦅"; case -1: "B"; case 0: "="; case 1: "+"; default: "++" }
    }
    private func scoreColor(_ vsPar: Int) -> Color {
        switch vsPar { case ..<0: accentColor; case 0: .white; case 1: .orange; default: .red }
    }

    // MARK: - Overlays

    private var penaltyOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 28)).foregroundStyle(.orange)
            Text(penaltyText).font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white).multilineTextAlignment(.center)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.5), lineWidth: 1)))
        .shadow(color: .black.opacity(0.4), radius: 20)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private var holeCardOverlay: some View {
        VStack(spacing: 12) {
            Text("HOLE \(holeResults.last?.hole ?? currentHole) COMPLETE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(3)
            Text(holeCardText).font(.system(size: 32, weight: .black)).italic()
                .foregroundStyle(holeCardColor).shadow(color: holeCardColor.opacity(0.5), radius: 16)
            if let last = holeResults.last {
                Text("\(last.strokes) strokes · Par \(parPerHole)")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground.opacity(0.95))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(holeCardColor.opacity(0.3), lineWidth: 1)))
        .shadow(color: .black.opacity(0.5), radius: 24)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    // MARK: - Drag Gesture

    private func onDragChanged(_ v: DragGesture.Value) {
        guard shotState == .idle || shotState == .aiming || shotState == .draggingBack else { return }
        if shotState == .idle {
            dragStartLocation = v.startLocation
            shotState = .aiming
        }
        let dx = v.location.x - dragStartLocation.x
        let dy = v.location.y - dragStartLocation.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist > 8 {
            shotState = .draggingBack
            aimAngle  = atan2(dx, -dy) * 180.0 / .pi
            pullDistance = min(80, dist * 0.7)
        }
    }

    private func onDragEnded(_ v: DragGesture.Value) {
        guard shotState == .draggingBack || shotState == .aiming else {
            shotState = .idle; return
        }
        let power = Double(pullDistance / 80.0)
        fireShot(power: power)
    }

    // MARK: - Shot Logic

    private func fireShot(power: Double) {
        guard shotState != .ballFlying, !ballOnGreen else { return }
        shotState = .ballFlying
        currentStrokes += 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let radians = aimAngle * .pi / 180.0
        let dist = 0.55 * power
        let newBallX = clamp(ballX + sin(radians) * dist, 0.05, 0.95)
        let newBallY = clamp(ballY + cos(radians) * dist, 0.05, 0.95)

        let hitObstacle = obstacles.first { obs in
            let oL = obs.position.x - obs.size.width  / 2
            let oR = obs.position.x + obs.size.width  / 2
            let oB = obs.position.y - obs.size.height / 2
            let oT = obs.position.y + obs.size.height / 2
            return newBallX >= oL && newBallX <= oR && newBallY >= oB && newBallY <= oT
        }

        ballStartX = ballX; ballStartY = ballY
        ballEndX   = newBallX; ballEndY = newBallY
        ballProgress = 0
        golferPose = "backswing"

        Task {
            try? await Task.sleep(nanoseconds: 40_000_000)
            await MainActor.run { golferPose = "impact" }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

            let steps = 30
            for step in 0..<steps {
                try? await Task.sleep(nanoseconds: 14_000_000)
                await MainActor.run { ballProgress = Double(step + 1) / Double(steps) }
            }

            await MainActor.run {
                ballProgress = -1
                golferPose = "followthrough"
                if let obs = hitObstacle {
                    applyObstaclePenalty(obs)
                } else {
                    ballX = newBallX; ballY = newBallY
                    checkIfHoled()
                }
                pullDistance = 0
                shotState = .idle
            }

            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run { golferPose = "address" }
        }
    }

    private func applyObstaclePenalty(_ obs: GolfObstacleLayout) {
        currentStrokes += obs.type.strokePenalty
        if obs.type == .water {
            penaltyText = "Water Hazard!\n+\(obs.type.strokePenalty) Strokes · Ball Reset"
        } else {
            ballX = ballEndX; ballY = ballEndY
            penaltyText = "Sand Trap!\n+\(obs.type.strokePenalty) Stroke"
        }
        withAnimation(.spring(response: 0.3)) { showPenalty = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            await MainActor.run { withAnimation { showPenalty = false } }
        }
    }

    private func checkIfHoled() {
        let dx = ballX - Double(holePosition.x)
        let dy = ballY - Double(holePosition.y)
        let dist = sqrt(dx * dx + dy * dy)

        if dist < 0.10 {
            ballOnGreen = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            recordHole()
        } else if currentStrokes >= parPerHole + 3 {
            ballOnGreen = true
            recordHole()
        }
    }

    private func recordHole() {
        let scoreVsPar = currentStrokes - parPerHole
        let (name, color): (String, Color) = {
            switch scoreVsPar {
            case ..<(-1): return ("Eagle",        accentColor)
            case -1:      return ("Birdie",        Theme.brandCyan)
            case 0:       return ("Par",           .white)
            case 1:       return ("Bogey",         .orange)
            default:      return ("Double Bogey",  .red)
            }
        }()

        holeResults.append(GolfHoleResult(hole: currentHole, strokes: currentStrokes,
                                          scoreName: name, scoreVsPar: scoreVsPar))
        totalStrokes += currentStrokes
        holeCardText = name; holeCardColor = color
        if scoreVsPar < 0 { crowdExcitement = min(1.0, crowdExcitement + 0.3) }

        withAnimation(.spring(response: 0.3)) { showHoleCard = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            await MainActor.run {
                withAnimation { showHoleCard = false }
                if currentHole < 9 { advanceHole() } else { phase = .result }
            }
        }
    }

    private func advanceHole() {
        currentHole += 1; currentStrokes = 0; ballOnGreen = false
        ballX = 0.5; ballY = 0.1; ballProgress = -1
        aimAngle = 0; pullDistance = 0; shotState = .idle
        golferPose = "address"
        generateHoleLayout()
    }

    private func startHole() { phase = .aiming; generateHoleLayout() }

    private func generateHoleLayout() {
        holePosition = CGPoint(x: Double.random(in: 0.25...0.75),
                               y: Double.random(in: 0.72...0.88))
        var newObs: [GolfObstacleLayout] = []
        let count = Int.random(in: 2...3)
        let types: [GolfObstacle] = count > 2 ? [.sandTrap, .water, .sandTrap] : [.sandTrap, .water]
        for (i, t) in types.prefix(count).enumerated() {
            newObs.append(GolfObstacleLayout(
                type: t,
                position: CGPoint(x: Double.random(in: 0.25...0.75),
                                  y: 0.30 + Double(i) * 0.18 + Double.random(in: -0.05...0.05)),
                size: CGSize(width: Double.random(in: 0.15...0.22),
                             height: Double.random(in: 0.08...0.12))
            ))
        }
        obstacles = newObs
    }

    // MARK: - Rewards

    private func grantShards(playerWon: Bool, isDraw: Bool) {
        guard !rewardGranted else { return }
        rewardGranted = true
        let earned = playerWon ? WIN_SHARDS : (isDraw ? DRAW_SHARDS : LOSS_SHARDS)
        viewModel.profile.evolutionShards += min(earned, XP_CAP)
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { max(lo, min(hi, v)) }
}
