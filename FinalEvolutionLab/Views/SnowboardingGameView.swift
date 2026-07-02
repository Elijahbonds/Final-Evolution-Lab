import SwiftUI
import UIKit

// MARK: - Phase

private enum SnowPhase {
    case ready, slope, jump, trick, roundResult, result
}

// MARK: - Trick

private struct SnowTrick: Identifiable {
    let id = UUID()
    let name: String
    let points: Int
    let icon: String
}

private let snowTricks: [SnowTrick] = [
    SnowTrick(name: "Grab",   points: 50,  icon: "hand.point.up.left.fill"),
    SnowTrick(name: "Spin",   points: 100, icon: "arrow.clockwise.circle"),
    SnowTrick(name: "Indy",   points: 120, icon: "figure.snowboarding"),
    SnowTrick(name: "Method", points: 140, icon: "star.fill"),
]

// MARK: - Swipe direction

private enum SnowSwipeDir {
    case up, right, left, down
}

// MARK: - Haptics

private func hapticLight() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
private func hapticMedium() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
private func hapticHeavy() {
    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
}
private func hapticRigid() {
    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
}
private func hapticError() {
    UINotificationFeedbackGenerator().notificationOccurred(.error)
}

// MARK: - Snow Slope Drawer

private struct SnowSlopeDrawer {
    let W: CGFloat
    let H: CGFloat
    let speed: Double
    let t: Double
    // State for crowd celebration
    var gatePassActive: Bool = false

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawMountainSkyline(ctx: &ctx)
        drawMountains(ctx: &ctx)
        drawSlope(ctx: &ctx)
        drawSnowParticles(ctx: &ctx)
        drawGates(ctx: &ctx)
        drawCrowd(ctx: &ctx)
        drawBoarderShadow(ctx: &ctx)
        drawBoarder(ctx: &ctx)
        if speed > 35 { drawSpeedLines(ctx: &ctx) }
        drawSpeedGauge(ctx: &ctx)
    }

    private func drawSky(ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.42)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.05, green: 0.10, blue: 0.28),
                        Color(red: 0.18, green: 0.35, blue: 0.60)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: H * 0.42)))
    }

    // Deep blue/purple distant mountain silhouettes at horizon
    private func drawMountainSkyline(ctx: inout GraphicsContext) {
        var far = Path()
        far.move(to: CGPoint(x: 0, y: H * 0.38))
        far.addLine(to: CGPoint(x: W * 0.04, y: H * 0.26))
        far.addLine(to: CGPoint(x: W * 0.12, y: H * 0.34))
        far.addLine(to: CGPoint(x: W * 0.21, y: H * 0.21))
        far.addLine(to: CGPoint(x: W * 0.30, y: H * 0.33))
        far.addLine(to: CGPoint(x: W * 0.42, y: H * 0.17))
        far.addLine(to: CGPoint(x: W * 0.53, y: H * 0.31))
        far.addLine(to: CGPoint(x: W * 0.62, y: H * 0.20))
        far.addLine(to: CGPoint(x: W * 0.73, y: H * 0.34))
        far.addLine(to: CGPoint(x: W * 0.84, y: H * 0.22))
        far.addLine(to: CGPoint(x: W * 0.93, y: H * 0.36))
        far.addLine(to: CGPoint(x: W, y: H * 0.28))
        far.addLine(to: CGPoint(x: W, y: H * 0.42))
        far.addLine(to: CGPoint(x: 0, y: H * 0.42))
        far.closeSubpath()
        ctx.fill(far, with: .color(Color(red: 0.10, green: 0.08, blue: 0.22).opacity(0.82)))

        // Snow caps on distant peaks
        var caps = Path()
        caps.move(to: CGPoint(x: W * 0.38, y: H * 0.17))
        caps.addLine(to: CGPoint(x: W * 0.42, y: H * 0.17))
        caps.addLine(to: CGPoint(x: W * 0.45, y: H * 0.22))
        caps.addLine(to: CGPoint(x: W * 0.39, y: H * 0.22))
        caps.closeSubpath()
        ctx.fill(caps, with: .color(.white.opacity(0.55)))

        var caps2 = Path()
        caps2.move(to: CGPoint(x: W * 0.59, y: H * 0.20))
        caps2.addLine(to: CGPoint(x: W * 0.62, y: H * 0.20))
        caps2.addLine(to: CGPoint(x: W * 0.65, y: H * 0.26))
        caps2.addLine(to: CGPoint(x: W * 0.58, y: H * 0.26))
        caps2.closeSubpath()
        ctx.fill(caps2, with: .color(.white.opacity(0.50)))
    }

    private func drawMountains(ctx: inout GraphicsContext) {
        var m1 = Path()
        m1.move(to: CGPoint(x: 0, y: H * 0.44))
        m1.addLine(to: CGPoint(x: W * 0.08, y: H * 0.24))
        m1.addLine(to: CGPoint(x: W * 0.20, y: H * 0.40))
        m1.addLine(to: CGPoint(x: W * 0.36, y: H * 0.18))
        m1.addLine(to: CGPoint(x: W * 0.50, y: H * 0.40))
        m1.addLine(to: CGPoint(x: W * 0.64, y: H * 0.22))
        m1.addLine(to: CGPoint(x: W * 0.78, y: H * 0.40))
        m1.addLine(to: CGPoint(x: W * 0.90, y: H * 0.26))
        m1.addLine(to: CGPoint(x: W, y: H * 0.40))
        m1.addLine(to: CGPoint(x: W, y: H))
        m1.addLine(to: CGPoint(x: 0, y: H))
        m1.closeSubpath()
        ctx.fill(m1, with: .color(Color(red: 0.86, green: 0.91, blue: 0.97)))

        var m2 = Path()
        m2.move(to: CGPoint(x: 0, y: H * 0.46))
        m2.addLine(to: CGPoint(x: W * 0.14, y: H * 0.32))
        m2.addLine(to: CGPoint(x: W * 0.28, y: H * 0.44))
        m2.addLine(to: CGPoint(x: W * 0.44, y: H * 0.28))
        m2.addLine(to: CGPoint(x: W * 0.56, y: H * 0.44))
        m2.addLine(to: CGPoint(x: W * 0.70, y: H * 0.30))
        m2.addLine(to: CGPoint(x: W * 0.82, y: H * 0.44))
        m2.addLine(to: CGPoint(x: W, y: H * 0.34))
        m2.addLine(to: CGPoint(x: W, y: H))
        m2.addLine(to: CGPoint(x: 0, y: H))
        m2.closeSubpath()
        ctx.fill(m2, with: .color(Color(red: 0.92, green: 0.95, blue: 0.99)))
    }

    private func drawSlope(ctx: inout GraphicsContext) {
        let slopeTop = H * 0.42
        let snowColor = Color(red: 0.94, green: 0.96, blue: 1.0)
        var slope = Path()
        slope.move(to: CGPoint(x: 0, y: slopeTop))
        slope.addLine(to: CGPoint(x: W, y: slopeTop + H * 0.06))
        slope.addLine(to: CGPoint(x: W, y: H))
        slope.addLine(to: CGPoint(x: 0, y: H))
        slope.closeSubpath()
        ctx.fill(slope, with: .linearGradient(
            Gradient(colors: [snowColor, snowColor.opacity(0.80)]),
            startPoint: CGPoint(x: 0, y: slopeTop),
            endPoint: CGPoint(x: 0, y: H)))

        // Perspective lines converging to vanishing point
        let vp = CGPoint(x: W * 0.5, y: slopeTop)
        for i in 0..<6 {
            let endX = W * CGFloat(i) / 5.0
            var tl = Path()
            tl.move(to: vp)
            tl.addLine(to: CGPoint(x: endX, y: H))
            ctx.stroke(tl, with: .color(snowColor.opacity(0.45)), lineWidth: 0.7)
        }

        // Board tracks
        let trackCX = W * 0.50
        for dx in [-7.0, 7.0] as [Double] {
            let tx = trackCX + CGFloat(dx)
            var track = Path()
            track.move(to: CGPoint(x: tx, y: slopeTop + H * 0.02))
            track.addLine(to: CGPoint(x: tx + CGFloat((speed - 50) * 0.45), y: H * 0.88))
            ctx.stroke(track,
                       with: .color(Color(red: 0.65, green: 0.75, blue: 0.90).opacity(0.55)),
                       lineWidth: 1.5)
        }
    }

    // 30 snow particles falling diagonally, driven by t
    private func drawSnowParticles(ctx: inout GraphicsContext) {
        for i in 0..<30 {
            let px = CGFloat(fmod(Double(i) * 73.1 + t * 80, Double(W)))
            let py = CGFloat(fmod(Double(i) * 47.3 + t * 120, Double(H)))
            ctx.fill(
                Circle().path(in: CGRect(x: px - 1.5, y: py - 1.5, width: 3, height: 3)),
                with: .color(.white.opacity(0.55))
            )
        }
    }

    private func drawGates(ctx: inout GraphicsContext) {
        let slopeTop = H * 0.42
        let speedRate = 0.3 + speed / 200.0
        for gi in 0..<4 {
            let gatePhase = fmod(Double(gi) * 0.25 + t * speedRate * 0.4, 1.0)
            let gY = slopeTop + (H - slopeTop) * CGFloat(gatePhase) * 0.92
            let poleH = H * CGFloat(0.04 + gatePhase * 0.12)
            let poleW = CGFloat(2.5 + gatePhase * 3.0)
            let spread = W * CGFloat(0.10 + gatePhase * 0.26)
            let alpha = CGFloat(0.35 + gatePhase * 0.55)
            let gateColor = gi % 2 == 0 ? Color.red : Color.blue

            let lx = W * 0.5 - spread
            let rx = W * 0.5 + spread
            let flagW = spread * 0.38
            let flagH = poleH * 0.30

            // Left pole
            ctx.fill(Path(CGRect(x: lx - poleW / 2, y: gY - poleH, width: poleW, height: poleH)),
                     with: .color(gateColor.opacity(alpha)))
            // Left pole shadow on snow
            ctx.fill(Path(CGRect(x: lx, y: gY - 3, width: poleW * 0.6, height: 3)),
                     with: .color(.black.opacity(0.18 * alpha)))
            // Left flag panel
            ctx.fill(Path(CGRect(x: lx - flagW / 2, y: gY - poleH * 0.80, width: flagW, height: flagH)),
                     with: .color(gateColor.opacity(alpha + 0.2)))
            // Left pole cap
            ctx.fill(Path(ellipseIn: CGRect(x: lx - poleW, y: gY - poleH - 4, width: poleW * 2, height: poleW * 2)),
                     with: .color(gateColor.opacity(alpha + 0.1)))

            // Right pole
            ctx.fill(Path(CGRect(x: rx - poleW / 2, y: gY - poleH, width: poleW, height: poleH)),
                     with: .color(gateColor.opacity(alpha)))
            // Right pole shadow on snow
            ctx.fill(Path(CGRect(x: rx, y: gY - 3, width: poleW * 0.6, height: 3)),
                     with: .color(.black.opacity(0.18 * alpha)))
            // Right flag panel
            ctx.fill(Path(CGRect(x: rx - flagW / 2, y: gY - poleH * 0.80, width: flagW, height: flagH)),
                     with: .color(gateColor.opacity(alpha + 0.2)))
            // Right pole cap
            ctx.fill(Path(ellipseIn: CGRect(x: rx - poleW, y: gY - poleH - 4, width: poleW * 2, height: poleW * 2)),
                     with: .color(gateColor.opacity(alpha + 0.1)))

            // Banner between poles
            var banner = Path()
            banner.move(to: CGPoint(x: lx, y: gY - poleH * 0.75))
            banner.addLine(to: CGPoint(x: rx, y: gY - poleH * 0.75))
            ctx.stroke(banner, with: .color(.white.opacity(alpha * 0.5)), lineWidth: 1)

            // Gate number label (small dot indicator)
            let labelSize = CGFloat(5 + gatePhase * 4)
            ctx.fill(
                Path(ellipseIn: CGRect(x: W * 0.5 - labelSize / 2, y: gY - poleH * 0.75 - labelSize / 2,
                                       width: labelSize, height: labelSize)),
                with: .color(.white.opacity(alpha * 0.85))
            )
        }
    }

    // 8 spectator silhouettes on each side, arms raised on good gate pass
    private func drawCrowd(ctx: inout GraphicsContext) {
        let slopeTop = H * 0.42
        let groundY = H * 0.94
        let armsUp = gatePassActive
        let crowdAlpha: CGFloat = 0.72

        for side in 0..<2 {
            let baseX: CGFloat = side == 0 ? W * 0.04 : W * 0.70
            let spacing: CGFloat = W * 0.033
            for i in 0..<8 {
                let cx = baseX + CGFloat(i) * spacing
                let cy = groundY - CGFloat(i % 3) * H * 0.022
                let scale: CGFloat = 0.55 + CGFloat(i % 3) * 0.08
                let bodyH = H * 0.065 * scale
                let headR = bodyH * 0.25

                // Body silhouette
                ctx.fill(
                    Path(CGRect(x: cx - 3 * scale, y: cy - bodyH, width: 6 * scale, height: bodyH)),
                    with: .color(Color(red: 0.12, green: 0.08, blue: 0.20).opacity(crowdAlpha))
                )
                // Head
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - headR, y: cy - bodyH - headR * 2,
                                           width: headR * 2, height: headR * 2)),
                    with: .color(Color(red: 0.12, green: 0.08, blue: 0.20).opacity(crowdAlpha))
                )
                // Arms — raised if gate pass active, else neutral
                let armY = cy - bodyH * 0.65
                let armLen: CGFloat = armsUp ? bodyH * 0.55 : bodyH * 0.35
                let armAngle: CGFloat = armsUp ? -0.9 : 0.2
                var arms = Path()
                arms.move(to: CGPoint(x: cx - 3 * scale, y: armY))
                arms.addLine(to: CGPoint(x: cx - 3 * scale - CGFloat(cos(armAngle)) * armLen,
                                          y: armY - CGFloat(sin(armAngle)) * armLen))
                arms.move(to: CGPoint(x: cx + 3 * scale, y: armY))
                arms.addLine(to: CGPoint(x: cx + 3 * scale + CGFloat(cos(armAngle)) * armLen,
                                          y: armY - CGFloat(sin(armAngle)) * armLen))
                ctx.stroke(arms,
                           with: .color(Color(red: 0.12, green: 0.08, blue: 0.20).opacity(crowdAlpha)),
                           lineWidth: 1.5 * scale)
            }
        }
    }

    // Ellipse shadow under snowboard on snow surface
    private func drawBoarderShadow(ctx: inout GraphicsContext) {
        let bx = W * 0.50
        let shadowY = H * 0.695
        let shadowW: CGFloat = 44
        let shadowH: CGFloat = 8
        var shadowGC = ctx
        shadowGC.addFilter(.blur(radius: 3))
        shadowGC.fill(
            Path(ellipseIn: CGRect(x: bx - shadowW / 2, y: shadowY, width: shadowW, height: shadowH)),
            with: .color(.black.opacity(0.30))
        )
    }

    private func drawBoarder(ctx: inout GraphicsContext) {
        let bx = W * 0.50, by = H * 0.66
        let lean = CGFloat((speed - 50) * 0.004)
        // Crouch: lower center of mass at higher speeds
        let crouchOffset = CGFloat(speed / 100.0) * 4.0

        var gc = ctx
        gc.translateBy(x: bx, y: by)
        gc.rotate(by: .radians(lean))

        let blue = GraphicsContext.Shading.color(Color(red: 0.40, green: 0.70, blue: 1.0))
        let skin = GraphicsContext.Shading.color(Color(red: 0.88, green: 0.65, blue: 0.44))
        let dark = GraphicsContext.Shading.color(Color(red: 0.08, green: 0.06, blue: 0.12))

        // Board — tinted with jacket color hint
        gc.fill(Path(roundedRect: CGRect(x: -22, y: 4, width: 44, height: 7),
                     cornerSize: CGSize(width: 3, height: 3)),
                with: .color(.white.opacity(0.90)))
        gc.fill(Path(roundedRect: CGRect(x: -22, y: 4, width: 44, height: 2),
                     cornerSize: CGSize(width: 1, height: 1)),
                with: blue)

        // Legs — crouched at high speed
        var legs = Path()
        legs.move(to: CGPoint(x: -6, y: 4))
        legs.addLine(to: CGPoint(x: -3, y: -5 + crouchOffset))
        legs.addLine(to: CGPoint(x: 0, y: -10 + crouchOffset))
        legs.move(to: CGPoint(x: 6, y: 4))
        legs.addLine(to: CGPoint(x: 3, y: -5 + crouchOffset))
        legs.addLine(to: CGPoint(x: 0, y: -10 + crouchOffset))
        gc.stroke(legs, with: blue, lineWidth: 3)

        var torso = Path()
        torso.move(to: CGPoint(x: 0, y: -10 + crouchOffset))
        torso.addLine(to: CGPoint(x: 0, y: -20 + crouchOffset))
        gc.stroke(torso, with: blue, lineWidth: 3)

        // Arms — extended outward for balance at higher speeds
        let armExtend: CGFloat = CGFloat(speed / 100.0) * 5.0
        var arms = Path()
        arms.move(to: CGPoint(x: -12 - armExtend, y: -16 + crouchOffset))
        arms.addLine(to: CGPoint(x: 0, y: -15 + crouchOffset))
        arms.addLine(to: CGPoint(x: 12 + armExtend, y: -16 + crouchOffset))
        gc.stroke(arms, with: skin, lineWidth: 2.5)

        gc.fill(Path(ellipseIn: CGRect(x: -5, y: -29 + crouchOffset, width: 10, height: 10)), with: blue)
        gc.fill(Path(CGRect(x: -5, y: -27 + crouchOffset, width: 10, height: 4)), with: dark)

        // Powder spray arc when carving hard
        if speed > 28 {
            for i in 0..<5 {
                let sa = Double(i) * .pi / 4.0 + .pi * 1.1
                let sp = fmod(t * 3.0 + Double(i) * 0.5, 1.0)
                let sr = CGFloat(6 + sp * 18)
                let spx = CGFloat(cos(sa)) * sr
                let spy = CGFloat(sin(sa)) * sr * 0.45 + 8
                let sdot = CGFloat(1.5 + sp * 2.0)
                gc.fill(Path(ellipseIn: CGRect(x: spx - sdot, y: spy - sdot, width: sdot * 2, height: sdot * 2)),
                        with: .color(.white.opacity(CGFloat(0.5 * speed / 100.0) * CGFloat(1.0 - sp))))
            }
        }
    }

    private func drawSpeedLines(ctx: inout GraphicsContext) {
        let bx = W * 0.50, by = H * 0.66
        let alpha = CGFloat((speed - 35.0) / 65.0) * 0.28
        for i in 0..<8 {
            let angle = Double(i) * .pi / 8.0 + .pi * 0.82
            let len = CGFloat(speed * 0.28)
            var line = Path()
            line.move(to: CGPoint(x: bx, y: by))
            line.addLine(to: CGPoint(x: bx + CGFloat(cos(angle)) * len,
                                      y: by + CGFloat(sin(angle)) * len))
            ctx.stroke(line, with: .color(.white.opacity(alpha)), lineWidth: 0.8)
        }

        // 6 radial speed lines from near-center, length scales with speed
        let cx = W * 0.50, cy = H * 0.55
        let speedFactor = speed / 100.0
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3.0 + t * 0.5
            let lineLen = speedFactor * 60
            var p = Path()
            p.move(to: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: cx + CGFloat(cos(angle) * lineLen),
                                   y: cy + CGFloat(sin(angle) * lineLen)))
            ctx.stroke(p, with: .color(.white.opacity(0.25)), lineWidth: 1.5)
        }
    }

    // Glowing speed gauge arc in bottom corner
    private func drawSpeedGauge(ctx: inout GraphicsContext) {
        let cx = W - 28, cy = H - 28
        let radius: CGFloat = 18
        let lineW: CGFloat = 3.5
        let fillFraction = CGFloat(speed / 100.0)

        // Background arc
        var bgArc = Path()
        bgArc.addArc(center: CGPoint(x: cx, y: cy),
                     radius: radius,
                     startAngle: .degrees(145),
                     endAngle: .degrees(35),
                     clockwise: false)
        ctx.stroke(bgArc, with: .color(.white.opacity(0.15)), lineWidth: lineW)

        // Fill arc (speed proportion)
        if fillFraction > 0 {
            let endDeg = 145.0 + fillFraction * 250.0
            var fillArc = Path()
            fillArc.addArc(center: CGPoint(x: cx, y: cy),
                           radius: radius,
                           startAngle: .degrees(145),
                           endAngle: .degrees(endDeg),
                           clockwise: false)
            let gaugeColor = speed > 70
                ? Color(red: 0.2, green: 1.0, blue: 0.5)
                : Color(red: 0.4, green: 0.7, blue: 1.0)
            ctx.stroke(fillArc, with: .color(gaugeColor.opacity(0.88)), lineWidth: lineW)

            // Glow halo
            var glowGC = ctx
            glowGC.addFilter(.blur(radius: 4))
            glowGC.stroke(fillArc, with: .color(gaugeColor.opacity(0.40)), lineWidth: lineW + 2)
        }

        // Center dot
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)),
            with: .color(.white.opacity(0.70))
        )
    }
}

// MARK: - Snow Slope Canvas

private struct SnowSlopeCanvas: View {
    let speed: Double
    let gatePassActive: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var drawer = SnowSlopeDrawer(W: size.width, H: size.height,
                                             speed: speed, t: t,
                                             gatePassActive: gatePassActive)
                drawer.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Snow Jump Drawer

private struct SnowJumpDrawer {
    let W: CGFloat
    let H: CGFloat
    let jumpHeight: Double
    let isTrickPhase: Bool
    let trickName: String?
    let trickPoints: Int
    let rotationFraction: Double   // 0…1 trick rotation progress
    let judgeScores: [Int]         // revealed scores (0-10 each)
    let t: Double

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawHalfpipeWalls(ctx: &ctx)
        drawMountains(ctx: &ctx)
        drawSnowSpray(ctx: &ctx)
        drawBoarder(ctx: &ctx)
        if isTrickPhase && jumpHeight > 0.25 { drawRotationIndicator(ctx: &ctx) }
        if let name = trickName { drawTrickBanner(ctx: &ctx, name: name) }
        drawJudgePanel(ctx: &ctx)
        drawCrowdReaction(ctx: &ctx)
    }

    private func drawSky(ctx: inout GraphicsContext) {
        // Sky gradient: light blue at horizon → deep blue overhead
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.05, green: 0.10, blue: 0.42),   // deep blue overhead
                        Color(red: 0.30, green: 0.55, blue: 0.88),   // mid sky
                        Color(red: 0.55, green: 0.76, blue: 0.96)    // light blue horizon
                    ]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
        var sunGC = ctx
        sunGC.addFilter(.blur(radius: 20))
        sunGC.fill(Path(ellipseIn: CGRect(x: W * 0.72, y: H * 0.06, width: 32, height: 26)),
                   with: .color(Color(red: 1.0, green: 0.97, blue: 0.80).opacity(0.48)))
    }

    // Halfpipe quarter-pipe walls on left and right
    private func drawHalfpipeWalls(ctx: inout GraphicsContext) {
        let lift = CGFloat(jumpHeight) * H * 0.22
        let groundY = H * 0.84 - lift
        let wallH = H * 0.28
        let wallW = W * 0.12

        // Left wall — curved quarter pipe
        var leftWall = Path()
        leftWall.move(to: CGPoint(x: 0, y: groundY))
        leftWall.addQuadCurve(to: CGPoint(x: wallW, y: groundY - wallH),
                               control: CGPoint(x: 0, y: groundY - wallH))
        leftWall.addLine(to: CGPoint(x: wallW * 0.6, y: groundY - wallH))
        leftWall.addQuadCurve(to: CGPoint(x: 0, y: groundY + H * 0.04),
                               control: CGPoint(x: 0, y: groundY - wallH * 0.7))
        leftWall.closeSubpath()
        ctx.fill(leftWall, with: .linearGradient(
            Gradient(colors: [Color(red: 0.82, green: 0.88, blue: 0.96),
                               Color(red: 0.70, green: 0.78, blue: 0.92)]),
            startPoint: CGPoint(x: 0, y: groundY - wallH),
            endPoint: CGPoint(x: wallW, y: groundY)))
        // Wall shadow gradient
        ctx.fill(leftWall, with: .linearGradient(
            Gradient(colors: [.black.opacity(0.18), .clear]),
            startPoint: CGPoint(x: 0, y: groundY - wallH),
            endPoint: CGPoint(x: wallW, y: groundY)))

        // Right wall
        var rightWall = Path()
        rightWall.move(to: CGPoint(x: W, y: groundY))
        rightWall.addQuadCurve(to: CGPoint(x: W - wallW, y: groundY - wallH),
                                control: CGPoint(x: W, y: groundY - wallH))
        rightWall.addLine(to: CGPoint(x: W - wallW * 0.6, y: groundY - wallH))
        rightWall.addQuadCurve(to: CGPoint(x: W, y: groundY + H * 0.04),
                                control: CGPoint(x: W, y: groundY - wallH * 0.7))
        rightWall.closeSubpath()
        ctx.fill(rightWall, with: .linearGradient(
            Gradient(colors: [Color(red: 0.82, green: 0.88, blue: 0.96),
                               Color(red: 0.70, green: 0.78, blue: 0.92)]),
            startPoint: CGPoint(x: W, y: groundY - wallH),
            endPoint: CGPoint(x: W - wallW, y: groundY)))
        ctx.fill(rightWall, with: .linearGradient(
            Gradient(colors: [.black.opacity(0.18), .clear]),
            startPoint: CGPoint(x: W, y: groundY - wallH),
            endPoint: CGPoint(x: W - wallW, y: groundY)))

        // Lip line on top of each wall
        var leftLip = Path()
        leftLip.move(to: CGPoint(x: 0, y: groundY - wallH))
        leftLip.addLine(to: CGPoint(x: wallW, y: groundY - wallH))
        ctx.stroke(leftLip, with: .color(.white.opacity(0.55)), lineWidth: 1.5)

        var rightLip = Path()
        rightLip.move(to: CGPoint(x: W, y: groundY - wallH))
        rightLip.addLine(to: CGPoint(x: W - wallW, y: groundY - wallH))
        ctx.stroke(rightLip, with: .color(.white.opacity(0.55)), lineWidth: 1.5)
    }

    private func drawMountains(ctx: inout GraphicsContext) {
        let lift = CGFloat(jumpHeight) * H * 0.22
        let groundY = H * 0.84 - lift
        var mPath = Path()
        mPath.move(to: CGPoint(x: 0, y: groundY + H * 0.04))
        mPath.addLine(to: CGPoint(x: W * 0.09, y: groundY - H * 0.20))
        mPath.addLine(to: CGPoint(x: W * 0.22, y: groundY + H * 0.02))
        mPath.addLine(to: CGPoint(x: W * 0.38, y: groundY - H * 0.28))
        mPath.addLine(to: CGPoint(x: W * 0.52, y: groundY + H * 0.02))
        mPath.addLine(to: CGPoint(x: W * 0.66, y: groundY - H * 0.22))
        mPath.addLine(to: CGPoint(x: W * 0.80, y: groundY + H * 0.02))
        mPath.addLine(to: CGPoint(x: W * 0.92, y: groundY - H * 0.14))
        mPath.addLine(to: CGPoint(x: W, y: groundY + H * 0.04))
        mPath.addLine(to: CGPoint(x: W, y: H))
        mPath.addLine(to: CGPoint(x: 0, y: H))
        mPath.closeSubpath()
        ctx.fill(mPath, with: .color(Color(red: 0.88, green: 0.93, blue: 0.98)))
        ctx.fill(mPath, with: .linearGradient(
            Gradient(colors: [Color(red: 0.75, green: 0.85, blue: 0.96).opacity(0.25), .clear]),
            startPoint: CGPoint(x: 0, y: groundY - H * 0.1),
            endPoint: CGPoint(x: W, y: groundY)))
    }

    // 12 snow spray particles kick up when board is near lip
    private func drawSnowSpray(ctx: inout GraphicsContext) {
        let lift = CGFloat(jumpHeight) * H * 0.22
        let groundY = H * 0.84 - lift
        let intensity = CGFloat(jumpHeight)
        // Original 8-particle spray
        for i in 0..<8 {
            let phase = fmod(t * 1.6 + Double(i) * 0.35, 1.0)
            let angle = Double(i) * .pi / 4.0 + .pi * 0.58
            let r = CGFloat(phase * 28)
            let px = W * 0.5 + CGFloat(cos(angle)) * r
            let py = groundY - CGFloat(phase) * H * 0.08
            let dot = CGFloat(2.5 + phase * 4.5)
            ctx.fill(Path(ellipseIn: CGRect(x: px - dot / 2, y: py - dot / 2, width: dot, height: dot)),
                     with: .color(.white.opacity(CGFloat(0.5 * (1.0 - phase)) * intensity)))
        }
        // 4 extra spray particles at lip exit
        for i in 0..<4 {
            let phase = fmod(t * 2.2 + Double(i) * 0.55, 1.0)
            let angle = Double(i) * .pi / 2.5 + .pi * 0.35
            let r = CGFloat(phase * 18)
            let px = W * 0.5 + CGFloat(cos(angle)) * r
            let py = groundY - CGFloat(phase) * H * 0.06
            let dot = CGFloat(1.5 + phase * 3.0)
            ctx.fill(Path(ellipseIn: CGRect(x: px - dot / 2, y: py - dot / 2, width: dot, height: dot)),
                     with: .color(.white.opacity(CGFloat(0.4 * (1.0 - phase)) * intensity)))
        }
    }

    // Arc showing rotation angle during trick
    private func drawRotationIndicator(ctx: inout GraphicsContext) {
        let bY = H * 0.84 - CGFloat(jumpHeight) * H * 0.22 - CGFloat(jumpHeight) * H * 0.52
        let bX = W * 0.5
        let indicatorR: CGFloat = 32
        let rotEnd = rotationFraction * 360.0

        var arcPath = Path()
        arcPath.addArc(center: CGPoint(x: bX, y: bY),
                       radius: indicatorR,
                       startAngle: .degrees(-90),
                       endAngle: .degrees(-90 + rotEnd),
                       clockwise: false)
        ctx.stroke(arcPath, with: .color(Color(red: 0.4, green: 0.9, blue: 1.0).opacity(0.72)), lineWidth: 2)

        // Arrowhead dot at end
        let endAngle = (-90 + rotEnd) * .pi / 180.0
        let dotX = bX + indicatorR * CGFloat(cos(endAngle))
        let dotY = bY + indicatorR * CGFloat(sin(endAngle))
        ctx.fill(
            Path(ellipseIn: CGRect(x: dotX - 3, y: dotY - 3, width: 6, height: 6)),
            with: .color(Color(red: 0.4, green: 0.9, blue: 1.0).opacity(0.88))
        )
    }

    // Trick name banner flashes center screen with glow
    private func drawTrickBanner(ctx: inout GraphicsContext, name: String) {
        // Glow background pill
        let pillW: CGFloat = W * 0.65
        let pillH: CGFloat = H * 0.10
        let pillX = W * 0.175
        let pillY = H * 0.38

        var glowGC = ctx
        glowGC.addFilter(.blur(radius: 12))
        glowGC.fill(
            Path(roundedRect: CGRect(x: pillX, y: pillY, width: pillW, height: pillH),
                 cornerRadius: pillH / 2),
            with: .color(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.60))
        )

        ctx.fill(
            Path(roundedRect: CGRect(x: pillX, y: pillY, width: pillW, height: pillH),
                 cornerRadius: pillH / 2),
            with: .color(Color(red: 0.05, green: 0.10, blue: 0.28).opacity(0.80))
        )
        ctx.stroke(
            Path(roundedRect: CGRect(x: pillX, y: pillY, width: pillW, height: pillH),
                 cornerRadius: pillH / 2),
            with: .color(Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.75)),
            lineWidth: 1.5
        )

        // Trick name text resolved as image
        let label = Text(name.uppercased())
            .font(.system(size: 16, weight: .black, design: .monospaced))
            .foregroundColor(Color(red: 0.85, green: 0.95, blue: 1.0))
        let resolved = ctx.resolve(label)
        let textSize = resolved.measure(in: CGSize(width: pillW, height: pillH))
        ctx.draw(resolved, at: CGPoint(x: pillX + pillW / 2 - textSize.width / 2,
                                        y: pillY + pillH / 2 - textSize.height / 2),
                 anchor: .topLeading)

        // Points sub-label
        let ptsLabel = Text("+\(trickPoints) pts")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.80))
        let ptsResolved = ctx.resolve(ptsLabel)
        let ptsSize = ptsResolved.measure(in: CGSize(width: pillW, height: 20))
        ctx.draw(ptsResolved,
                 at: CGPoint(x: pillX + pillW / 2 - ptsSize.width / 2,
                              y: pillY + pillH - ptsSize.height - 4),
                 anchor: .topLeading)
    }

    // 5 judge score cards at bottom, revealed after landing
    private func drawJudgePanel(ctx: inout GraphicsContext) {
        guard !judgeScores.isEmpty else { return }
        let cardW: CGFloat = W * 0.13
        let cardH: CGFloat = H * 0.085
        let totalPanelW = cardW * 5 + W * 0.025 * 4
        let startX = (W - totalPanelW) / 2
        let cardY = H - cardH - H * 0.03

        for i in 0..<5 {
            let cardX = startX + CGFloat(i) * (cardW + W * 0.025)
            let score = i < judgeScores.count ? judgeScores[i] : 0
            let isPerfect = score >= 9

            // Card background
            ctx.fill(
                Path(roundedRect: CGRect(x: cardX, y: cardY, width: cardW, height: cardH),
                     cornerRadius: 4),
                with: .color(isPerfect
                    ? Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.90)
                    : Color(red: 0.10, green: 0.12, blue: 0.22).opacity(0.88))
            )
            ctx.stroke(
                Path(roundedRect: CGRect(x: cardX, y: cardY, width: cardW, height: cardH),
                     cornerRadius: 4),
                with: .color(isPerfect
                    ? Color(red: 0.4, green: 1.0, blue: 0.6).opacity(0.80)
                    : Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.50)),
                lineWidth: 1
            )

            // Score number
            let scoreLabel = Text("\(score)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(isPerfect ? .black : Color(red: 0.85, green: 0.95, blue: 1.0))
            let sResolved = ctx.resolve(scoreLabel)
            let sSize = sResolved.measure(in: CGSize(width: cardW, height: cardH))
            ctx.draw(sResolved,
                     at: CGPoint(x: cardX + cardW / 2 - sSize.width / 2,
                                  y: cardY + cardH / 2 - sSize.height / 2),
                     anchor: .topLeading)
        }
    }

    // Crowd brightness flares on perfect trick timing
    private func drawCrowdReaction(ctx: inout GraphicsContext) {
        let lift = CGFloat(jumpHeight) * H * 0.22
        let groundY = H * 0.84 - lift
        let flareAlpha = CGFloat(jumpHeight) * 0.35
        guard flareAlpha > 0.05 else { return }

        // Left crowd flare
        var leftFlare = Path()
        leftFlare.addEllipse(in: CGRect(x: -W * 0.05, y: groundY - H * 0.18,
                                         width: W * 0.18, height: H * 0.16))
        var leftGC = ctx
        leftGC.addFilter(.blur(radius: 14))
        leftGC.fill(leftFlare,
                    with: .color(Color(red: 1.0, green: 0.9, blue: 0.3).opacity(flareAlpha)))

        // Right crowd flare
        var rightFlare = Path()
        rightFlare.addEllipse(in: CGRect(x: W * 0.87, y: groundY - H * 0.18,
                                          width: W * 0.18, height: H * 0.16))
        var rightGC = ctx
        rightGC.addFilter(.blur(radius: 14))
        rightGC.fill(rightFlare,
                     with: .color(Color(red: 1.0, green: 0.9, blue: 0.3).opacity(flareAlpha)))
    }

    private func drawBoarder(ctx: inout GraphicsContext) {
        let lift = CGFloat(jumpHeight) * H * 0.22
        let groundY = H * 0.84 - lift
        let bY = groundY - CGFloat(jumpHeight) * H * 0.52
        let bX = W * 0.5

        var spinAngle: Double = 0
        var boardTilt: Double = 0
        let isGrab = trickName == "Grab" || trickName == "Indy"
        if isTrickPhase && jumpHeight > 0.25 {
            if trickName == "Spin" {
                spinAngle = fmod(t * 3.2, .pi * 2.0)
            } else if trickName == "Method" || trickName == "Indy" {
                boardTilt = sin(t * 4.0) * .pi / 4.5
            } else if trickName == "Grab" {
                boardTilt = sin(t * 3.0) * .pi / 6.0
            }
        }

        var shadowGC = ctx
        shadowGC.addFilter(.blur(radius: 5))
        let sS = max(CGFloat(0.18), 1.0 - CGFloat(jumpHeight) * 0.75)
        shadowGC.fill(Path(ellipseIn: CGRect(x: bX - 20 * sS, y: groundY - 1,
                                              width: 40 * sS, height: 7 * sS)),
                      with: .color(.black.opacity(0.4 * sS)))

        var gc = ctx
        gc.translateBy(x: bX, y: bY)
        if spinAngle != 0 { gc.rotate(by: .radians(spinAngle)) }

        let blue = GraphicsContext.Shading.color(Color(red: 0.40, green: 0.70, blue: 1.0))
        let skin = GraphicsContext.Shading.color(Color(red: 0.88, green: 0.65, blue: 0.44))
        let dark = GraphicsContext.Shading.color(Color(red: 0.08, green: 0.06, blue: 0.12))

        var boardGC = gc
        if boardTilt != 0 { boardGC.rotate(by: .radians(boardTilt)) }
        boardGC.fill(Path(roundedRect: CGRect(x: -24, y: 8, width: 48, height: 9),
                          cornerSize: CGSize(width: 4, height: 4)),
                     with: .color(.white.opacity(0.92)))
        boardGC.fill(Path(roundedRect: CGRect(x: -24, y: 8, width: 48, height: 3),
                          cornerSize: CGSize(width: 2, height: 2)), with: blue)

        // Legs — arms extend for grab tricks
        var legs = Path()
        legs.move(to: CGPoint(x: -8, y: 8))
        legs.addLine(to: CGPoint(x: -4, y: -2))
        legs.addLine(to: CGPoint(x: -1, y: -9))
        legs.move(to: CGPoint(x: 8, y: 8))
        legs.addLine(to: CGPoint(x: 4, y: -2))
        legs.addLine(to: CGPoint(x: 1, y: -9))
        gc.stroke(legs, with: blue, lineWidth: 3.5)

        var torso = Path()
        torso.move(to: CGPoint(x: 0, y: -9))
        torso.addLine(to: CGPoint(x: 0, y: -20))
        gc.stroke(torso, with: blue, lineWidth: 3.5)

        // Arms — extended wide for grabs
        let armExtend: CGFloat = isGrab ? 8 : 0
        var arms = Path()
        arms.move(to: CGPoint(x: -15 - armExtend, y: -15))
        arms.addLine(to: CGPoint(x: 0, y: -14))
        arms.addLine(to: CGPoint(x: 15 + armExtend, y: -15))
        gc.stroke(arms, with: skin, lineWidth: 3)

        gc.fill(Path(ellipseIn: CGRect(x: -5.5, y: -30, width: 11, height: 11)), with: blue)
        gc.fill(Path(CGRect(x: -5.5, y: -28, width: 11, height: 4)), with: dark)
    }
}

// MARK: - Snow Jump Canvas

private struct SnowJumpCanvas: View {
    let jumpHeight: Double
    let isTrickPhase: Bool
    let trickName: String?
    let trickPoints: Int
    let judgeScores: [Int]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rotFraction = isTrickPhase ? fmod(t * 0.6, 1.0) : 0.0
                var drawer = SnowJumpDrawer(
                    W: size.width, H: size.height,
                    jumpHeight: jumpHeight, isTrickPhase: isTrickPhase,
                    trickName: trickName, trickPoints: trickPoints,
                    rotationFraction: rotFraction,
                    judgeScores: judgeScores,
                    t: t)
                drawer.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - SnowboardingGameView

struct SnowboardingGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    private let totalRounds = 6
    private let slopeDuration: Double = 5.0
    private let xpCapPerSession = 500
    private let accentColor = Color(red: 0.85, green: 0.92, blue: 1.0)
    private let snowBlue = Color(red: 0.4, green: 0.7, blue: 1.0)

    @Environment(\.dismiss) private var dismiss

    @State private var phase: SnowPhase = .ready
    @State private var currentRound = 1
    @State private var slopeTimeLeft: Double = 5.0
    @State private var slopeTimer: Task<Void, Never>? = nil

    @State private var speed: Double = 0
    @State private var tapLeftCount = 0
    @State private var tapRightCount = 0
    @State private var lastGateMissed = false
    @State private var gatePassActive = false

    @State private var airTime: Double = 0
    @State private var airTimeLeft: Double = 0
    @State private var jumpHeight: Double = 0
    @State private var airTimer: Task<Void, Never>? = nil

    @State private var roundTrickPoints = 0
    @State private var roundTrickNames: [String] = []
    @State private var trickDoneThisAir = false

    @State private var totalScore = 0
    @State private var roundScores: [Int] = []

    @State private var trickPopup: String? = nil
    @State private var trickPopupPoints: Int = 0
    @State private var popupTask: Task<Void, Never>? = nil

    @State private var swipeStart: CGPoint = .zero
    @State private var activeSwipeCount = 0

    @State private var didWin = false
    @State private var shardsEarned = 0

    @State private var showGatePenalty = false

    // Judge scores revealed after each jump
    @State private var judgeScores: [Int] = []

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            slopeGradientBg.ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Snowboarding",
                    subtitle: "6 jumps · Gain speed · Nail tricks in the air",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startSlope() }
                )
            case .slope:              slopeBody
            case .jump, .trick:       jumpBody
            case .roundResult:        roundResultBody
            case .result:
                ResultScreen(
                    winner: didWin ? .p1 : .p2,
                    p1Score: totalScore,
                    p2Score: max(0, totalScore - Int.random(in: 100...300)),
                    title: "Snowboarding",
                    accentColor: accentColor,
                    prqGain: didWin ? 14 : 5,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "STYLE",
                    modeAttributeValue: min(1.0, Double(totalScore) / 2000.0),
                    onReturn: {
                        applyRewards()
                        dismiss()
                    }
                )
            }

            if showGatePenalty {
                Color.red.opacity(0.18).ignoresSafeArea().allowsHitTesting(false).transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    slopeTimer?.cancel()
                    airTimer?.cancel()
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
        .onDisappear { slopeTimer?.cancel(); airTimer?.cancel() }
    }

    // MARK: - Background

    private var slopeGradientBg: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.12, blue: 0.22), Theme.deepBlack],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Slope Phase View

    private var slopeBody: some View {
        VStack(spacing: 0) {
            slopeHeader.padding(.horizontal, 20).padding(.top, 12)
            Spacer()
            slopeVisual
            Spacer()
            speedMeterView.padding(.horizontal, 24)
            tapButtonRow.padding(.horizontal, 20).padding(.bottom, 32)
        }
    }

    private var slopeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("JUMP \(currentRound)/\(totalRounds)")
                    .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
                HStack(spacing: 3) {
                    ForEach(1...totalRounds, id: \.self) { i in
                        Circle()
                            .fill(i < currentRound ? Theme.foundationGreen : (i == currentRound ? accentColor : Theme.cardBorder))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            Spacer()
            ZStack {
                Circle().stroke(Theme.cardBorder, lineWidth: 3).frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(slopeTimeLeft / slopeDuration))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: slopeTimeLeft)
                Image(systemName: "timer").font(.system(size: 14, weight: .bold)).foregroundStyle(accentColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("TOTAL").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(totalScore)").font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(.white).contentTransition(.numericText())
            }
        }
    }

    private var slopeVisual: some View {
        SnowSlopeCanvas(speed: speed, gatePassActive: gatePassActive)
            .frame(height: 160)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 16)
    }

    private var speedMeterView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "speedometer").font(.system(size: 11, weight: .bold)).foregroundStyle(accentColor)
                Text("SPEED").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
                Spacer()
                Text("\(Int(speed))%").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(.white).contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.cardBorder).frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: speedBarColors(speed: speed), startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(speed / 100), height: 12)
                        .animation(.spring(response: 0.2), value: speed)
                }
            }
            .frame(height: 12)
            if lastGateMissed {
                Text("GATE MISSED — \u{2212}20% SPEED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.red).transition(.opacity)
            }
        }
        .padding(.bottom, 16)
    }

    private func speedBarColors(speed: Double) -> [Color] {
        if speed < 40 { return [snowBlue.opacity(0.5), snowBlue] }
        if speed < 70 { return [snowBlue, accentColor] }
        return [accentColor, Theme.foundationGreen, accentColor]
    }

    private var tapButtonRow: some View {
        HStack(spacing: 20) {
            Button { tapLeft() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 24, weight: .black))
                    Text("L").font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(snowBlue).frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Theme.cardBackground).clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(snowBlue.opacity(0.3), lineWidth: 1))
            }.buttonStyle(.plain)

            VStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(accentColor).symbolEffect(.pulse)
                Text("TAP FAST").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                Text("TO GAIN SPEED").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
            }

            Button { tapRight() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "chevron.right").font(.system(size: 24, weight: .black))
                    Text("R").font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(snowBlue).frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Theme.cardBackground).clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(snowBlue.opacity(0.3), lineWidth: 1))
            }.buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Jump / Air Phase View

    private var jumpBody: some View {
        VStack(spacing: 0) {
            jumpHeader.padding(.horizontal, 20).padding(.top, 12)
            Spacer()
            jumpHeightVisual
            Spacer()
            jumpTrickPopup.frame(height: 80)
            if phase == .trick {
                trickButtonGrid.padding(.horizontal, 20).padding(.bottom, 32)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 36, weight: .bold)).foregroundStyle(accentColor).symbolEffect(.pulse)
                    Text("LAUNCHING...").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
                }
                .padding(.bottom, 60)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dir = swipeDirectionFromDrag(dx: value.translation.width, dy: value.translation.height)
                    handleAirTrick(dir: dir)
                }
        )
    }

    private var jumpHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("JUMP \(currentRound)/\(totalRounds)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
                Text("SPEED: \(Int(speed))%").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(snowBlue)
            }
            Spacer()
            ZStack {
                Circle().stroke(Theme.cardBorder, lineWidth: 3).frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: airTime > 0 ? CGFloat(airTimeLeft / airTime) : 0)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: airTimeLeft)
                Text(String(format: "%.1f", airTimeLeft)).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("ROUND").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(roundTrickPoints)").font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(accentColor).contentTransition(.numericText())
            }
        }
    }

    private var jumpHeightVisual: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(spacing: 8) {
                Text("HEIGHT").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.cardBorder).frame(width: 16, height: 160)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [accentColor, snowBlue], startPoint: .bottom, endPoint: .top))
                        .frame(width: 16, height: 160 * CGFloat(jumpHeight))
                        .animation(.spring(response: 0.5), value: jumpHeight)
                }
            }

            SnowJumpCanvas(jumpHeight: jumpHeight,
                           isTrickPhase: phase == .trick,
                           trickName: trickPopup,
                           trickPoints: trickPopupPoints,
                           judgeScores: judgeScores)
                .frame(width: 160, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("TRICKS").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                ForEach(roundTrickNames.prefix(4), id: \.self) { name in
                    HStack(spacing: 4) {
                        Circle().fill(Theme.foundationGreen).frame(width: 5, height: 5)
                        Text(name).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(accentColor)
                    }
                }
                if roundTrickNames.isEmpty {
                    Text("None yet").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(width: 70)
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var jumpTrickPopup: some View {
        if let name = trickPopup {
            VStack(spacing: 4) {
                Text(name.uppercased()).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(accentColor).shadow(color: accentColor.opacity(0.6), radius: 8)
                Text("+\(trickPopupPoints) pts").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            Color.clear
        }
    }

    private var trickButtonGrid: some View {
        VStack(spacing: 12) {
            Text("SWIPE OR TAP A TRICK").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(snowTricks) { trick in
                    Button { performSnowTrick(trick) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: trick.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(accentColor)
                            Text(trick.name.uppercased()).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.white)
                            Text("+\(trick.points)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.cardBackground).clipShape(.rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain).disabled(trickDoneThisAir).opacity(trickDoneThisAir ? 0.4 : 1.0)
                }
            }
        }
    }

    // MARK: - Round Result

    private var roundResultBody: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("JUMP \(currentRound - 1) SCORE").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(3)
            Text("\(roundScores.last ?? 0)").font(.system(size: 60, weight: .black, design: .monospaced)).foregroundStyle(accentColor).shadow(color: accentColor.opacity(0.4), radius: 16)
            Text("PTS").font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(4)
            if !roundTrickNames.isEmpty {
                HStack(spacing: 8) {
                    ForEach(roundTrickNames.prefix(4), id: \.self) { name in
                        Text(name).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.black)
                            .padding(.horizontal, 10).padding(.vertical, 5).background(accentColor).clipShape(.capsule)
                    }
                }
            }
            VStack(spacing: 6) {
                Text("TOTAL SO FAR").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(totalScore) pts").font(.system(size: 24, weight: .black, design: .monospaced)).foregroundStyle(Theme.foundationGreen)
            }
            .padding(.top, 8)
            if currentRound <= totalRounds {
                Button { startSlope() } label: {
                    Text("JUMP \(currentRound) — RIDE")
                        .font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16).background(accentColor).clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 40).padding(.top, 12)
            }
            Spacer()
        }
    }

    // MARK: - Logic: Slope

    private func startSlope() {
        speed = 0
        tapLeftCount = 0
        tapRightCount = 0
        lastGateMissed = false
        gatePassActive = false
        judgeScores = []
        slopeTimeLeft = slopeDuration
        roundTrickPoints = 0
        roundTrickNames = []
        trickDoneThisAir = false
        phase = .slope
        slopeTimer?.cancel()
        slopeTimer = Task {
            let tick: Double = 0.05
            while slopeTimeLeft > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    slopeTimeLeft = max(0, slopeTimeLeft - tick)
                    speed = max(0, speed - 0.15)
                    if Int.random(in: 0...200) == 0 { missGate() }
                    // Gate pass event (random, ~every 1s at normal speed)
                    if Int.random(in: 0...100) == 0 { passGate() }
                }
            }
            await MainActor.run { guard phase == .slope else { return }; launchJump() }
        }
    }

    private func tapLeft() {
        guard phase == .slope else { return }
        tapLeftCount += 1
        speed = min(100, speed + Double.random(in: 2.5...4.5))
        // Speed boost haptic when crossing 70% threshold
        if speed >= 70 && speed - Double.random(in: 2.5...4.5) < 70 {
            hapticRigid()
        }
    }

    private func tapRight() {
        guard phase == .slope else { return }
        tapRightCount += 1
        speed = min(100, speed + Double.random(in: 2.5...4.5))
        // Speed boost haptic when crossing 70% threshold
        if speed >= 70 && speed - Double.random(in: 2.5...4.5) < 70 {
            hapticRigid()
        }
    }

    private func passGate() {
        // Gate pass haptic — light impact
        hapticLight()
        gatePassActive = true
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run { gatePassActive = false }
        }
        // Speed bonus for clean gate
        if speed < 95 {
            speed = min(100, speed + 5.0)
            hapticRigid()
        }
    }

    private func missGate() {
        lastGateMissed = true
        speed = max(0, speed - 20)
        withAnimation { showGatePenalty = true }
        // Crash/wipeout haptics
        hapticError()
        hapticHeavy()
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { withAnimation { showGatePenalty = false }; lastGateMissed = false }
        }
    }

    // MARK: - Logic: Jump

    private func launchJump() {
        slopeTimer?.cancel()
        airTime = 1.0 + (speed / 100.0) * 3.0
        airTimeLeft = airTime
        jumpHeight = speed / 100.0
        phase = .jump
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                guard phase == .jump else { return }
                phase = .trick
                // Trick execution at peak jump — medium haptic
                hapticMedium()
            }
        }
        airTimer?.cancel()
        airTimer = Task {
            let tick: Double = 0.05
            while airTimeLeft > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    airTimeLeft = max(0, airTimeLeft - tick)
                    let progress = 1.0 - (airTimeLeft / airTime)
                    jumpHeight = sin(progress * .pi) * (speed / 100.0)
                }
            }
            await MainActor.run { guard phase == .jump || phase == .trick else { return }; landJump() }
        }
    }

    private func landJump() {
        airTimer?.cancel()
        jumpHeight = 0
        // Trick landing haptic — heavy impact
        hapticHeavy()

        // Generate judge scores based on round trick points
        let baseScore = min(10, max(1, roundTrickPoints / 20))
        judgeScores = (0..<5).map { _ in max(1, min(10, baseScore + Int.random(in: -1...2))) }

        roundScores.append(roundTrickPoints)
        totalScore += roundTrickPoints
        if currentRound >= totalRounds {
            let opponentScore = Int.random(in: 600...1200)
            didWin = totalScore > opponentScore
            GameResultService.saveResult(modeId: "snowboarding", userScore: totalScore)
            phase = .result
        } else {
            currentRound += 1
            phase = .roundResult
        }
    }

    // MARK: - Logic: Tricks

    private func swipeDirectionFromDrag(dx: CGFloat, dy: CGFloat) -> SnowSwipeDir {
        let angle = atan2(-dy, dx) * 180 / .pi
        if angle > 45 && angle < 135 { return .up }
        if angle > -45 && angle < 45 { return .right }
        if angle < -45 && angle > -135 { return .left }
        return .down
    }

    private func handleAirTrick(dir: SnowSwipeDir) {
        guard phase == .trick else { return }
        switch dir {
        case .up:    performSnowTrick(snowTricks[2])
        case .right: performSnowTrick(snowTricks[1])
        case .left:  performSnowTrick(snowTricks[0])
        case .down:  performSnowTrick(snowTricks[3])
        }
    }

    private func performSnowTrick(_ trick: SnowTrick) {
        guard (phase == .jump || phase == .trick) && !trickDoneThisAir else { return }
        trickDoneThisAir = true
        roundTrickPoints += trick.points
        roundTrickNames.append(trick.name)
        // Trick execution haptic — medium
        hapticMedium()
        showTrickPopup(name: trick.name, points: trick.points)
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run { if phase == .trick { trickDoneThisAir = false } }
        }
    }

    // MARK: - Trick popup

    private func showTrickPopup(name: String, points: Int) {
        popupTask?.cancel()
        withAnimation(.spring(response: 0.25)) { trickPopup = name; trickPopupPoints = points }
        popupTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { trickPopup = nil } }
        }
    }

    // MARK: - Rewards

    private func applyRewards() {
        let opponentThreshold = 800
        let shards = totalScore > opponentThreshold ? 50 : (totalScore > 400 ? 25 : 15)
        shardsEarned = shards
        viewModel.profile.evolutionShards += shards
        let xpGain = min(xpCapPerSession, totalScore / 10)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) * 0.01)
    }
}
