import SwiftUI
import UIKit

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
    let spikeActive: Bool
    let aceActive: Bool
    let digActive: Bool
    let serveActive: Bool
    let matchPointActive: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                var d = VBDrawer(
                    t: tl.date.timeIntervalSinceReferenceDate,
                    W: size.width, H: size.height,
                    ballPos: ballPosition, ballVisible: ballVisible,
                    touchPhase: touchPhase, inputOpen: inputWindowOpen,
                    rallyState: rallyState, crowd: crowdLevel,
                    spikeActive: spikeActive, aceActive: aceActive,
                    digActive: digActive, serveActive: serveActive,
                    matchPointActive: matchPointActive
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
    let spikeActive: Bool
    let aceActive: Bool
    let digActive: Bool
    let serveActive: Bool
    let matchPointActive: Bool

    // Court geometry
    var cL: CGFloat { W * 0.07 }
    var cR: CGFloat { W * 0.93 }
    var cT: CGFloat { H * 0.15 }
    var cB: CGFloat { H * 0.92 }
    var netY: CGFloat { H * 0.50 }

    var ballCX: CGFloat { ballPos.x * W }
    var ballCY: CGFloat { ballPos.y * H }
    var ballFromNet: CGFloat { abs(ballCY - netY) / (cB - netY) }

    mutating func render(ctx: inout GraphicsContext) {
        drawBeachBackground(&ctx)
        drawSandCourt(&ctx)
        drawNetStructure(&ctx)
        drawPlayerFigures(&ctx)
        if ballVisible { drawVolleyball(&ctx) }
        drawAtmosphereFX(&ctx)
        if inputOpen { drawInputZone(&ctx) }
    }

    // ─── #1–#12: Beach Background ──────────────────────────────────────────────

    private func drawBeachBackground(_ ctx: inout GraphicsContext) {

        // #1 — Ocean water gradient (deep blue to teal), sky portion
        let skyColor1 = Color(red: 0.10, green: 0.35, blue: 0.75)
        let skyColor2 = Color(red: 0.30, green: 0.65, blue: 0.92)
        let skyColor3 = Color(red: 0.60, green: 0.82, blue: 0.96)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.50)),
                 with: .linearGradient(
                    Gradient(colors: [skyColor1, skyColor2, skyColor3]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: H * 0.50)))

        // #2 — Sunset/warm horizon tint that shifts with time
        let horizonShift = CGFloat(0.5 + 0.5 * sin(t * 0.04))
        let horizonColor = Color(
            red: 0.85 * Double(horizonShift) + 0.30,
            green: 0.50 * Double(horizonShift) + 0.30,
            blue: 0.15 * Double(horizonShift) + 0.60
        ).opacity(0.28)
        ctx.fill(Path(CGRect(x: 0, y: H * 0.30, width: W, height: H * 0.22)),
                 with: .linearGradient(
                    Gradient(colors: [Color.clear, horizonColor, Color.clear]),
                    startPoint: CGPoint(x: 0, y: H * 0.30),
                    endPoint: CGPoint(x: 0, y: H * 0.52)))

        // #3 — Sun glow (blurred halo)
        let sunX = W * 0.78; let sunY = H * 0.10
        var sunGlowCtx = ctx
        sunGlowCtx.addFilter(.blur(radius: 22))
        sunGlowCtx.fill(
            Path(ellipseIn: CGRect(x: sunX - 28, y: sunY - 28, width: 56, height: 56)),
            with: .color(Color(red: 1.0, green: 0.92, blue: 0.55).opacity(0.60)))

        // #4 — Sun disc
        ctx.fill(
            Path(ellipseIn: CGRect(x: sunX - 14, y: sunY - 14, width: 28, height: 28)),
            with: .color(Color(red: 1.0, green: 0.97, blue: 0.72)))

        // #5 — Ocean water band (deep blue to teal)
        let oceanTop = H * 0.42; let oceanBot = H * 0.52
        ctx.fill(Path(CGRect(x: 0, y: oceanTop, width: W, height: oceanBot - oceanTop)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.06, green: 0.40, blue: 0.80),
                        Color(red: 0.04, green: 0.28, blue: 0.65)
                    ]),
                    startPoint: CGPoint(x: 0, y: oceanTop),
                    endPoint: CGPoint(x: 0, y: oceanBot)))

        // #6 — Wave line 1 (animated sine, shallow)
        var wave1 = Path()
        wave1.move(to: CGPoint(x: 0, y: H * 0.445))
        for xi in stride(from: CGFloat(0), through: W, by: 6) {
            let wy = H * 0.445 + CGFloat(sin(Double(xi) / 40.0 + t * 1.6)) * 2.8
            wave1.addLine(to: CGPoint(x: xi, y: wy))
        }
        ctx.stroke(wave1, with: .color(Color.white.opacity(0.35)), lineWidth: 1.2)

        // #7 — Wave line 2 (animated sine, mid)
        var wave2 = Path()
        wave2.move(to: CGPoint(x: 0, y: H * 0.458))
        for xi in stride(from: CGFloat(0), through: W, by: 6) {
            let wy = H * 0.458 + CGFloat(sin(Double(xi) / 35.0 + t * 1.9 + 1.2)) * 2.2
            wave2.addLine(to: CGPoint(x: xi, y: wy))
        }
        ctx.stroke(wave2, with: .color(Color.white.opacity(0.25)), lineWidth: 1.0)

        // #8 — Wave line 3 (animated, deeper ocean shimmer)
        var wave3 = Path()
        wave3.move(to: CGPoint(x: 0, y: H * 0.472))
        for xi in stride(from: CGFloat(0), through: W, by: 8) {
            let wy = H * 0.472 + CGFloat(sin(Double(xi) / 50.0 + t * 1.2 + 2.5)) * 1.8
            wave3.addLine(to: CGPoint(x: xi, y: wy))
        }
        ctx.stroke(wave3, with: .color(Color.white.opacity(0.18)), lineWidth: 0.8)

        // #9 — Sandy beach floor (warm tan gradient)
        ctx.fill(Path(CGRect(x: 0, y: H * 0.50, width: W, height: H * 0.50)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.90, green: 0.80, blue: 0.58),
                        Color(red: 0.82, green: 0.70, blue: 0.46),
                        Color(red: 0.76, green: 0.63, blue: 0.40)
                    ]),
                    startPoint: CGPoint(x: 0, y: H * 0.50),
                    endPoint: CGPoint(x: 0, y: H)))

        // #10 — Palm tree silhouette 1 (left side)
        drawPalmSilhouette(&ctx, baseX: W * 0.05, baseY: H * 0.52, scale: 1.0, swayT: t)

        // #11 — Palm tree silhouette 2 (right side)
        drawPalmSilhouette(&ctx, baseX: W * 0.96, baseY: H * 0.52, scale: 0.90, swayT: t + 1.3)

        // #12 — Palm tree silhouette 3 (far right background, smaller)
        drawPalmSilhouette(&ctx, baseX: W * 0.88, baseY: H * 0.50, scale: 0.68, swayT: t + 0.7)

        // Bonus: beach umbrella (pole + canopy arc)
        drawBeachUmbrella(&ctx, x: W * 0.15, y: H * 0.56)

        // Bonus: lifeguard tower silhouette
        drawLifeguardTower(&ctx, x: W * 0.84, y: H * 0.58)
    }

    private func drawPalmSilhouette(_ ctx: inout GraphicsContext, baseX: CGFloat, baseY: CGFloat, scale: CGFloat, swayT: Double) {
        let sway = CGFloat(sin(swayT * 0.65)) * 5 * scale
        var trunk = Path()
        trunk.move(to: CGPoint(x: baseX, y: baseY))
        trunk.addCurve(
            to: CGPoint(x: baseX + sway, y: baseY - 52 * scale),
            control1: CGPoint(x: baseX + sway * 0.3, y: baseY - 18 * scale),
            control2: CGPoint(x: baseX + sway * 0.7, y: baseY - 36 * scale))
        ctx.stroke(trunk, with: .color(Color(red: 0.30, green: 0.18, blue: 0.08).opacity(0.85)), lineWidth: 4.5 * scale)

        let topX = baseX + sway; let topY = baseY - 52 * scale
        let frondAngles: [Double] = [-0.3, -0.7, -1.1, -1.5, -1.9, -2.3, -2.7, 0.1]
        for ang in frondAngles {
            let fs = CGFloat(sin(swayT * 1.2 + ang)) * 5 * scale
            var frond = Path()
            frond.move(to: CGPoint(x: topX, y: topY))
            frond.addQuadCurve(
                to: CGPoint(x: topX + CGFloat(cos(ang)) * 26 * scale + fs, y: topY + CGFloat(sin(ang)) * 15 * scale),
                control: CGPoint(x: topX + CGFloat(cos(ang)) * 13 * scale, y: topY + CGFloat(sin(ang)) * 8 * scale - 7 * scale))
            ctx.stroke(frond, with: .color(Color(red: 0.10, green: 0.40, blue: 0.10).opacity(0.80)), lineWidth: 2.2 * scale)
        }
    }

    private func drawBeachUmbrella(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat) {
        // Pole
        var pole = Path()
        pole.move(to: CGPoint(x: x, y: y)); pole.addLine(to: CGPoint(x: x, y: y - 30))
        ctx.stroke(pole, with: .color(Color(white: 0.75).opacity(0.70)), lineWidth: 2)
        // Canopy arc
        var canopy = Path()
        canopy.move(to: CGPoint(x: x - 22, y: y - 30))
        canopy.addQuadCurve(to: CGPoint(x: x + 22, y: y - 30), control: CGPoint(x: x, y: y - 50))
        ctx.fill(canopy, with: .color(Color(red: 0.92, green: 0.30, blue: 0.15).opacity(0.65)))
        ctx.stroke(canopy, with: .color(Color(red: 0.92, green: 0.30, blue: 0.15).opacity(0.85)), lineWidth: 1.5)
    }

    private func drawLifeguardTower(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat) {
        // Platform
        ctx.fill(Path(CGRect(x: x - 14, y: y - 22, width: 28, height: 12)),
                 with: .color(Color(red: 0.70, green: 0.55, blue: 0.30).opacity(0.75)))
        // Two legs
        for lx in [x - 10, x + 10] {
            var leg = Path()
            leg.move(to: CGPoint(x: lx, y: y - 10)); leg.addLine(to: CGPoint(x: lx, y: y))
            ctx.stroke(leg, with: .color(Color(red: 0.65, green: 0.50, blue: 0.28).opacity(0.75)), lineWidth: 3)
        }
        // Flag
        var flag = Path()
        flag.move(to: CGPoint(x: x, y: y - 22))
        flag.addLine(to: CGPoint(x: x, y: y - 36))
        flag.addLine(to: CGPoint(x: x + 12, y: y - 31))
        flag.addLine(to: CGPoint(x: x, y: y - 26))
        ctx.fill(flag, with: .color(Color.red.opacity(0.75)))
    }

    // ─── #13–#24: Court Structure ───────────────────────────────────────────────

    private func drawSandCourt(_ ctx: inout GraphicsContext) {

        // #13 — Sand court surface (slightly distinct sand shade)
        var court = Path()
        court.move(to: CGPoint(x: cL, y: cT))
        court.addLine(to: CGPoint(x: cR, y: cT))
        court.addLine(to: CGPoint(x: cR, y: cB))
        court.addLine(to: CGPoint(x: cL, y: cB))
        court.closeSubpath()
        ctx.fill(court, with: .color(Color(red: 0.86, green: 0.76, blue: 0.54).opacity(0.55)))

        // #14 — Court boundary lines (white)
        ctx.stroke(court, with: .color(Color.white.opacity(0.80)), lineWidth: 2.0)

        // #15 — Center net line in sand (dashed appearance via short strokes)
        let dashCount = 18
        for di in 0..<dashCount {
            let t0 = CGFloat(di) / CGFloat(dashCount)
            let t1 = CGFloat(di) / CGFloat(dashCount) + 0.04
            let x0 = cL + t0 * (cR - cL)
            let x1 = cL + t1 * (cR - cL)
            var dash = Path()
            dash.move(to: CGPoint(x: x0, y: netY))
            dash.addLine(to: CGPoint(x: x1, y: netY))
            ctx.stroke(dash, with: .color(Color.white.opacity(0.35)), lineWidth: 0.9)
        }

        // #16 — Attack lines (3m lines each side)
        let attackOff = (cB - netY) * 0.36
        var atk1 = Path()
        atk1.move(to: CGPoint(x: cL, y: netY + attackOff)); atk1.addLine(to: CGPoint(x: cR, y: netY + attackOff))
        ctx.stroke(atk1, with: .color(Color.white.opacity(0.50)), lineWidth: 1.3)

        var atk2 = Path()
        atk2.move(to: CGPoint(x: cL, y: netY - attackOff)); atk2.addLine(to: CGPoint(x: cR, y: netY - attackOff))
        ctx.stroke(atk2, with: .color(Color.white.opacity(0.50)), lineWidth: 1.3)

        // #17 — Sand texture dots (randomized positions via deterministic noise)
        for si in stride(from: 0, to: 50, by: 1) {
            let sx = W * CGFloat(si) / 50 + CGFloat(sin(Double(si) * 3.14)) * 9
            let sy = H * 0.55 + CGFloat(cos(Double(si) * 2.71)) * H * 0.14
            let sr: CGFloat = CGFloat(0.7 + sin(Double(si) * 1.1)) * 1.6
            if sx > cL && sx < cR {
                ctx.fill(Path(ellipseIn: CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2)),
                         with: .color(Color(red: 0.65, green: 0.55, blue: 0.35).opacity(0.38)))
            }
        }

        // #18 — Net shadow on sand (blurred rectangle below net)
        var netShadowCtx = ctx
        netShadowCtx.addFilter(.blur(radius: 6))
        netShadowCtx.fill(Path(CGRect(x: cL + 4, y: netY - 2, width: cR - cL - 4, height: 10)),
                          with: .color(Color.black.opacity(0.28)))

        // #19 — Scoreboard post (left side vertical rect)
        let sbPostX = cL - 18
        ctx.fill(Path(CGRect(x: sbPostX - 3, y: cT - 10, width: 6, height: (netY - cT) * 0.5)),
                 with: .color(Color(white: 0.75).opacity(0.60)))

        // #20 — Scoreboard panel
        let sbY = cT - 10
        let sbRect = CGRect(x: sbPostX - 22, y: sbY - 24, width: 44, height: 22)
        ctx.fill(Path(roundedRect: sbRect, cornerRadius: 3),
                 with: .color(Color.black.opacity(0.75)))
        ctx.stroke(Path(roundedRect: sbRect, cornerRadius: 3),
                   with: .color(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.70)), lineWidth: 1.2)

        // #21 — Referee chair silhouette (right side)
        let refX = cR + 16; let refY = netY - 20
        ctx.fill(Path(CGRect(x: refX - 10, y: refY - 18, width: 20, height: 14)),
                 with: .color(Color(white: 0.72).opacity(0.55)))
        // Chair legs
        for lxoff in [-7, 7] {
            var leg = Path()
            leg.move(to: CGPoint(x: refX + CGFloat(lxoff), y: refY - 4))
            leg.addLine(to: CGPoint(x: refX + CGFloat(lxoff), y: refY + 10))
            ctx.stroke(leg, with: .color(Color(white: 0.72).opacity(0.55)), lineWidth: 2.5)
        }
        // Ref figure (silhouette head + body)
        ctx.fill(Path(ellipseIn: CGRect(x: refX - 5, y: refY - 30, width: 10, height: 10)),
                 with: .color(Color(white: 0.25).opacity(0.65)))
        var refBody = Path()
        refBody.move(to: CGPoint(x: refX, y: refY - 20)); refBody.addLine(to: CGPoint(x: refX, y: refY - 8))
        ctx.stroke(refBody, with: .color(Color(white: 0.25).opacity(0.65)), lineWidth: 3.5)

        // #22 — Left side line extension (out-of-bounds indicator)
        var leftSide = Path()
        leftSide.move(to: CGPoint(x: cL, y: cT)); leftSide.addLine(to: CGPoint(x: cL, y: cB))
        ctx.stroke(leftSide, with: .color(Color.white.opacity(0.60)), lineWidth: 2.0)

        // #23 — Right side line extension
        var rightSide = Path()
        rightSide.move(to: CGPoint(x: cR, y: cT)); rightSide.addLine(to: CGPoint(x: cR, y: cB))
        ctx.stroke(rightSide, with: .color(Color.white.opacity(0.60)), lineWidth: 2.0)

        // #24 — Foot marks in sand (small oval depressions near player positions)
        let playerSandX = lerp(ballCX, W * 0.5, 0.35)
        for fmi in -1...1 {
            let fmx = playerSandX + CGFloat(fmi) * 9
            let fmy = cB - 5
            ctx.fill(Path(ellipseIn: CGRect(x: fmx - 4, y: fmy - 2, width: 8, height: 4)),
                     with: .color(Color(red: 0.55, green: 0.44, blue: 0.28).opacity(0.35)))
        }
    }

    // ─── #25–#44: Net Structure ─────────────────────────────────────────────────

    private func drawNetStructure(_ ctx: inout GraphicsContext) {
        let netH: CGFloat = 24
        let postH: CGFloat = netH + 12

        // #25 — Net posts (left pole)
        ctx.fill(Path(CGRect(x: cL - 5, y: netY - postH, width: 8, height: postH + 8)),
                 with: .linearGradient(
                    Gradient(colors: [Color(white: 0.90), Color(white: 0.65)]),
                    startPoint: CGPoint(x: cL - 5, y: netY - postH),
                    endPoint: CGPoint(x: cL + 3, y: netY - postH)))

        // #26 — Net posts (right pole)
        ctx.fill(Path(CGRect(x: cR - 3, y: netY - postH, width: 8, height: postH + 8)),
                 with: .linearGradient(
                    Gradient(colors: [Color(white: 0.90), Color(white: 0.65)]),
                    startPoint: CGPoint(x: cR - 3, y: netY - postH),
                    endPoint: CGPoint(x: cR + 5, y: netY - postH)))

        // #27 — Antenna left (red/white stripes)
        let antX1 = cL + (cR - cL) * 0.28
        for stripe in 0..<6 {
            let sy = netY - netH - 22 + CGFloat(stripe) * 5
            ctx.fill(Path(CGRect(x: antX1 - 2, y: sy, width: 4, height: 4.5)),
                     with: .color(stripe % 2 == 0 ? Color.red.opacity(0.90) : Color.white.opacity(0.90)))
        }

        // #28 — Antenna right (red/white stripes)
        let antX2 = cL + (cR - cL) * 0.72
        for stripe in 0..<6 {
            let sy = netY - netH - 22 + CGFloat(stripe) * 5
            ctx.fill(Path(CGRect(x: antX2 - 2, y: sy, width: 4, height: 4.5)),
                     with: .color(stripe % 2 == 0 ? Color.red.opacity(0.90) : Color.white.opacity(0.90)))
        }

        // #29 — Net mesh vertical cords
        let cols = 26
        for c in 0...cols {
            let mx = cL + CGFloat(c) / CGFloat(cols) * (cR - cL)
            var mc = Path()
            mc.move(to: CGPoint(x: mx, y: netY - netH)); mc.addLine(to: CGPoint(x: mx, y: netY))
            ctx.stroke(mc, with: .color(Color(white: 0.68).opacity(0.38)), lineWidth: 0.55)
        }

        // #30 — Net mesh horizontal cords
        for r in 0..<6 {
            let ry = netY - netH + CGFloat(r) * netH / 5
            var rc = Path()
            rc.move(to: CGPoint(x: cL, y: ry)); rc.addLine(to: CGPoint(x: cR, y: ry))
            ctx.stroke(rc, with: .color(Color(white: 0.68).opacity(0.38)), lineWidth: 0.55)
        }

        // #31 — Net top tape (white band with subtle shadow)
        var tapeShadow = ctx
        tapeShadow.addFilter(.blur(radius: 3))
        tapeShadow.fill(Path(CGRect(x: cL - 3, y: netY - netH - 1, width: cR - cL + 6, height: 7)),
                        with: .color(Color.black.opacity(0.20)))
        ctx.fill(Path(CGRect(x: cL - 4, y: netY - netH - 4, width: cR - cL + 8, height: 6)),
                 with: .color(Color.white.opacity(0.90)))

        // #32 — Net bottom tape (thin white)
        ctx.fill(Path(CGRect(x: cL - 2, y: netY - 2, width: cR - cL + 4, height: 3)),
                 with: .color(Color.white.opacity(0.65)))
    }

    // ─── #33–#52: Player Figures ────────────────────────────────────────────────

    private func drawPlayerFigures(_ ctx: inout GraphicsContext) {
        // Player at bottom (user's player)
        let playerX = lerp(ballCX, W * 0.5, 0.35)
        let playerY = cB + (H - cB) * 0.28
        let playerPose: VBTouchPhase = inputOpen ? touchPhase : .pass
        drawAthleteBottom(&ctx, x: playerX, y: playerY,
                          color: Color(red: 0.10, green: 0.58, blue: 0.20),
                          suitColor: Color(red: 0.08, green: 0.45, blue: 0.75),
                          pose: playerPose, label: "YOU", isBottom: true)

        // Opponent at top
        let oppX = lerp(ballCX, W * 0.5, 0.50)
        let oppY = cT - (cT) * 0.32
        let oppPose: VBTouchPhase = (rallyState == .opponentHitting) ? .spike : .pass
        drawAthleteBottom(&ctx, x: oppX, y: oppY,
                          color: Color(red: 0.90, green: 0.80, blue: 0.65),
                          suitColor: Color(red: 0.78, green: 0.12, blue: 0.12),
                          pose: oppPose, label: "OPP", isBottom: false)

        // #33 — Second player figure (left side, near player, blocking/digging pose)
        let p2x = playerX - 36
        let p2y = playerY + 2
        drawSecondPlayer(&ctx, x: p2x, y: p2y,
                         color: Color(red: 0.10, green: 0.58, blue: 0.20),
                         suitColor: Color(red: 0.08, green: 0.45, blue: 0.75),
                         dig: digActive)

        // #34 — Second opponent figure (top right, slight offset)
        let o2x = oppX + 34
        let o2y = oppY - 2
        drawSecondPlayer(&ctx, x: o2x, y: o2y,
                         color: Color(red: 0.90, green: 0.80, blue: 0.65),
                         suitColor: Color(red: 0.78, green: 0.12, blue: 0.12),
                         dig: rallyState == .opponentDig)
    }

    private func drawAthleteBottom(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat,
                                    color: Color, suitColor: Color,
                                    pose: VBTouchPhase, label: String, isBottom: Bool) {
        let dir: CGFloat = isBottom ? -1 : 1

        // #35 — Player shadow (blurred ellipse on sand)
        var sc = ctx; sc.addFilter(.blur(radius: 5))
        sc.fill(Path(ellipseIn: CGRect(x: x - 16, y: y + 4, width: 32, height: 8)),
                with: .color(Color.black.opacity(0.30)))

        // #36 — Player head
        ctx.fill(Path(ellipseIn: CGRect(x: x - 7, y: y - 8, width: 14, height: 14)),
                 with: .color(color))

        // #37 — Headband / visor
        ctx.fill(Path(CGRect(x: x - 7.5, y: y - 8, width: 15, height: 4)),
                 with: .color(suitColor.opacity(0.85)))

        // #38 — Body (torso)
        var body = Path()
        body.move(to: CGPoint(x: x, y: y + 5))
        body.addLine(to: CGPoint(x: x, y: y + 18))
        ctx.stroke(body, with: .color(suitColor), lineWidth: 5.0)

        // #39 — Swim shorts / beach outfit detail
        ctx.fill(Path(CGRect(x: x - 6, y: y + 14, width: 12, height: 6)),
                 with: .color(suitColor.opacity(0.70)))

        // Arms — pose-specific (#40)
        let armY = y + 10
        switch pose {
        case .pass:
            // #40a — Platform pass arms (forearms flat, together)
            var arms = Path()
            arms.move(to: CGPoint(x: x - 13, y: armY + 8))
            arms.addLine(to: CGPoint(x: x, y: armY + 12))
            arms.addLine(to: CGPoint(x: x + 13, y: armY + 8))
            ctx.stroke(arms, with: .color(color.opacity(0.90)), lineWidth: 2.8)
            // Wrist line
            var wrist = Path()
            wrist.move(to: CGPoint(x: x - 6, y: armY + 11))
            wrist.addLine(to: CGPoint(x: x + 6, y: armY + 11))
            ctx.stroke(wrist, with: .color(color.opacity(0.55)), lineWidth: 1.2)

        case .set:
            // #40b — Overhead set hands (triangle shape above head)
            let bob = CGFloat(sin(t * 9)) * 2
            var arms = Path()
            arms.move(to: CGPoint(x: x - 9, y: armY - 1 + bob))
            arms.addLine(to: CGPoint(x: x, y: armY - 7 + bob))
            arms.addLine(to: CGPoint(x: x + 9, y: armY - 1 + bob))
            ctx.stroke(arms, with: .color(color.opacity(0.90)), lineWidth: 2.8)
            // Setting hands triangle
            var hands = Path()
            hands.move(to: CGPoint(x: x - 5, y: armY - 5 + bob))
            hands.addLine(to: CGPoint(x: x, y: armY - 9 + bob))
            hands.addLine(to: CGPoint(x: x + 5, y: armY - 5 + bob))
            hands.closeSubpath()
            ctx.stroke(hands, with: .color(color.opacity(0.70)), lineWidth: 1.2)

        case .spike:
            // #40c — Jump spike (arms raised, airborne, dominant arm extended high)
            let jump = CGFloat(abs(sin(t * 11))) * -10
            var arms = Path()
            arms.move(to: CGPoint(x: x - 11, y: armY + 5 + jump))
            arms.addLine(to: CGPoint(x: x, y: armY + jump))
            arms.addLine(to: CGPoint(x: x + 12 * dir, y: armY - 11 + jump))
            ctx.stroke(arms, with: .color(color.opacity(0.90)), lineWidth: 2.8)
            // Spike arm extended
            var spikeArm = Path()
            spikeArm.move(to: CGPoint(x: x + 12 * dir, y: armY - 11 + jump))
            spikeArm.addLine(to: CGPoint(x: x + 18 * dir, y: armY - 22 + jump))
            ctx.stroke(spikeArm, with: .color(color.opacity(0.90)), lineWidth: 2.8)
        }

        // #41 — Legs
        let jumpOffset: CGFloat = pose == .spike ? CGFloat(abs(sin(t * 11))) * -7 : 0
        var legs = Path()
        legs.move(to: CGPoint(x: x - 8, y: y + 30 + jumpOffset))
        legs.addLine(to: CGPoint(x: x, y: y + 18 + jumpOffset))
        legs.addLine(to: CGPoint(x: x + 8, y: y + 30 + jumpOffset))
        ctx.stroke(legs, with: .color(suitColor.opacity(0.75)), lineWidth: 3.0)

        // #42 — Shoes/feet (small colored rectangles)
        for side in [-1, 1] {
            let fx = x + CGFloat(side) * 8
            let fy = y + 30 + jumpOffset
            ctx.fill(Path(CGRect(x: fx - 5, y: fy - 2, width: 10, height: 5)),
                     with: .color(Color.white.opacity(0.70)))
        }

        // #43 — Block jump indicator (arms above net line when blocking)
        if pose == .spike && ballCY < netY + 20 {
            var glowBlock = ctx
            glowBlock.addFilter(.blur(radius: 8))
            glowBlock.fill(Path(ellipseIn: CGRect(x: x - 14, y: y - 26, width: 28, height: 12)),
                           with: .color(Color(red: 1.0, green: 0.85, blue: 0.20).opacity(0.35)))
        }

        // #44 — Sand footprint marks near player foot position
        if pose != .spike {
            for fi in 0..<3 {
                let fpx = x + CGFloat(fi - 1) * 8 + CGFloat(sin(Double(fi) * 2.1)) * 3
                let fpy = y + 32
                ctx.fill(Path(ellipseIn: CGRect(x: fpx - 3, y: fpy - 1.5, width: 6, height: 3)),
                         with: .color(Color(red: 0.55, green: 0.42, blue: 0.26).opacity(0.28)))
            }
        }
    }

    private func drawSecondPlayer(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat,
                                   color: Color, suitColor: Color, dig: Bool) {
        // Smaller secondary player silhouette
        var sc = ctx; sc.addFilter(.blur(radius: 3))
        sc.fill(Path(ellipseIn: CGRect(x: x - 11, y: y + 3, width: 22, height: 6)),
                with: .color(Color.black.opacity(0.20)))
        // Head
        ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 6, width: 11, height: 11)),
                 with: .color(color))
        // Body
        var body = Path()
        body.move(to: CGPoint(x: x, y: y + 4)); body.addLine(to: CGPoint(x: x, y: y + 14))
        ctx.stroke(body, with: .color(suitColor), lineWidth: 3.8)
        // Dig arms (bent knees, arms low) or normal
        if dig {
            var dArms = Path()
            dArms.move(to: CGPoint(x: x - 10, y: y + 13))
            dArms.addLine(to: CGPoint(x: x, y: y + 16))
            dArms.addLine(to: CGPoint(x: x + 10, y: y + 13))
            ctx.stroke(dArms, with: .color(color.opacity(0.80)), lineWidth: 2.2)
            // Bent legs
            var legs = Path()
            legs.move(to: CGPoint(x: x - 10, y: y + 26))
            legs.addLine(to: CGPoint(x: x - 4, y: y + 18))
            legs.addLine(to: CGPoint(x: x + 4, y: y + 18))
            legs.addLine(to: CGPoint(x: x + 10, y: y + 26))
            ctx.stroke(legs, with: .color(suitColor.opacity(0.65)), lineWidth: 2.5)
        } else {
            var arms = Path()
            arms.move(to: CGPoint(x: x - 8, y: y + 9)); arms.addLine(to: CGPoint(x: x + 8, y: y + 9))
            ctx.stroke(arms, with: .color(color.opacity(0.80)), lineWidth: 2.2)
            var legs = Path()
            legs.move(to: CGPoint(x: x - 5, y: y + 24))
            legs.addLine(to: CGPoint(x: x, y: y + 14))
            legs.addLine(to: CGPoint(x: x + 5, y: y + 24))
            ctx.stroke(legs, with: .color(suitColor.opacity(0.65)), lineWidth: 2.5)
        }
    }

    // ─── #45–#58: Ball & Play Effects ─────────────────────────────────────────

    private func drawVolleyball(_ ctx: inout GraphicsContext) {
        let bx = ballCX; let by = ballCY

        // #45 — Ball height factor (bigger near net, perspective scaling)
        let heightFactor = max(0, 1.0 - (by - netY) / (cB - netY))
        let r: CGFloat = 9 + heightFactor * 5

        // #46 — Ball air shadow on court (cast shadow below)
        let shadowScale: CGFloat = max(0.25, 1.0 - heightFactor)
        let shadowY = cB - 6
        var sc = ctx; sc.addFilter(.blur(radius: 9 * shadowScale))
        sc.fill(Path(ellipseIn: CGRect(x: bx - 14 * shadowScale, y: shadowY - 4 * shadowScale,
                                       width: 28 * shadowScale, height: 9 * shadowScale)),
                with: .color(Color.black.opacity(0.38 * Double(shadowScale))))

        // #47 — Ball motion trail (serve arc trajectory ghost)
        if serveActive || rallyState == .ballIncoming {
            for ti in 1...5 {
                let tf = CGFloat(ti) / 5.0
                let trailR = r * (1.0 - tf * 0.5)
                let trailX = bx - CGFloat(ti) * 6
                let trailY = by + CGFloat(ti) * 3
                ctx.fill(Path(ellipseIn: CGRect(x: trailX - trailR, y: trailY - trailR,
                                                width: trailR * 2, height: trailR * 2)),
                         with: .color(Color.white.opacity(0.12 * Double(1.0 - tf))))
            }
        }

        // #48 — Glow (blurred halo)
        var glowCtx = ctx; glowCtx.addFilter(.blur(radius: r * 1.2))
        glowCtx.fill(Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
                     with: .color(Color.white.opacity(0.48)))

        // #49 — Ball base (radial gradient sphere illusion)
        ctx.fill(Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(
                    Gradient(colors: [.white, Color(red: 0.92, green: 0.92, blue: 0.96)]),
                    center: CGPoint(x: bx - r * 0.28, y: by - r * 0.28),
                    startRadius: 0, endRadius: r * 1.1))

        // #50 — Panel seam line 1 (vertical arc)
        let panelColor = Color(red: 0.22, green: 0.32, blue: 0.80).opacity(0.52)
        var v1 = Path()
        v1.addArc(center: CGPoint(x: bx, y: by), radius: r - 1.5,
                  startAngle: .degrees(-80), endAngle: .degrees(80), clockwise: false)
        ctx.stroke(v1, with: .color(panelColor), lineWidth: 1.0)

        // #51 — Panel seam line 2 (rotated ~60°)
        var v2 = Path()
        v2.addArc(center: CGPoint(x: bx, y: by), radius: r - 1.5,
                  startAngle: .degrees(40), endAngle: .degrees(200), clockwise: false)
        ctx.stroke(v2, with: .color(panelColor), lineWidth: 1.0)

        // #52 — Panel seam line 3
        var v3 = Path()
        v3.addArc(center: CGPoint(x: bx, y: by), radius: r - 1.5,
                  startAngle: .degrees(160), endAngle: .degrees(320), clockwise: false)
        ctx.stroke(v3, with: .color(panelColor), lineWidth: 1.0)

        // #53 — Ball specular highlight
        ctx.fill(Path(ellipseIn: CGRect(x: bx - r * 0.48, y: by - r * 0.62, width: r * 0.36, height: r * 0.20)),
                 with: .color(Color.white.opacity(0.92)))

        // #54 — Spike smash dust particles (8 dots on contact)
        if spikeActive {
            let dustSeed = Int(t * 4) % 8
            for di in 0..<8 {
                let angle = Double(di + dustSeed) * .pi / 4.0
                let dist = CGFloat(10 + sin(Double(di) + t * 6) * 7)
                let dx = bx + CGFloat(cos(angle)) * dist
                let dy = by + CGFloat(sin(angle)) * dist * 0.5
                let dr: CGFloat = CGFloat(1.5 + abs(sin(Double(di) + t * 5)) * 2.5)
                ctx.fill(Path(ellipseIn: CGRect(x: dx - dr, y: dy - dr, width: dr * 2, height: dr * 2)),
                         with: .color(Color(red: 0.88, green: 0.78, blue: 0.56).opacity(0.65)))
            }
        }

        // #55 — Dig save trail (motion lines on dig)
        if digActive {
            for ti in 1...4 {
                let tf = CGFloat(ti)
                var trail = Path()
                trail.move(to: CGPoint(x: bx - tf * 8, y: by - tf * 5))
                trail.addLine(to: CGPoint(x: bx - tf * 8 + 6, y: by - tf * 5 + 4))
                ctx.stroke(trail, with: .color(Color(red: 0.15, green: 0.85, blue: 0.85).opacity(0.35 / Double(tf))), lineWidth: 1.5)
            }
        }

        // #56 — Serve receive platform arms indicator (arc below ball when pass expected)
        if rallyState == .awaitingPass && inputOpen {
            let arcY = by + r + 10
            var platform = Path()
            platform.addArc(center: CGPoint(x: bx, y: arcY + 5), radius: 14,
                            startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            ctx.stroke(platform, with: .color(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.55)), lineWidth: 2.0)
        }

        // #57 — Setting hands shape (triangle below ball when set active)
        if rallyState == .awaitingSet && inputOpen {
            var setHands = Path()
            let hcx = bx; let hcy = by + r + 8
            setHands.move(to: CGPoint(x: hcx - 10, y: hcy + 8))
            setHands.addLine(to: CGPoint(x: hcx, y: hcy))
            setHands.addLine(to: CGPoint(x: hcx + 10, y: hcy + 8))
            ctx.stroke(setHands, with: .color(Color(red: 0.15, green: 0.85, blue: 0.85).opacity(0.65)), lineWidth: 2.0)
        }

        // #58 — Spike aim indicator (downward arrow glow when spike window open)
        if rallyState == .awaitingSpike && inputOpen {
            var aimGlow = ctx; aimGlow.addFilter(.blur(radius: 6))
            aimGlow.fill(Path(ellipseIn: CGRect(x: bx - 5, y: by + r + 4, width: 10, height: 10)),
                         with: .color(Color.red.opacity(0.50)))
            var aim = Path()
            aim.move(to: CGPoint(x: bx, y: by + r + 4))
            aim.addLine(to: CGPoint(x: bx, y: by + r + 14))
            aim.addLine(to: CGPoint(x: bx - 5, y: by + r + 9))
            aim.move(to: CGPoint(x: bx, y: by + r + 14))
            aim.addLine(to: CGPoint(x: bx + 5, y: by + r + 9))
            ctx.stroke(aim, with: .color(Color.red.opacity(0.80)), lineWidth: 2.0)
        }
    }

    // ─── #59–#86: Atmosphere, Scoring & FX ─────────────────────────────────────

    private func drawAtmosphereFX(_ ctx: inout GraphicsContext) {

        // #59 — Beach crowd silhouettes (15 figures under umbrellas)
        let jerseys: [Color] = [
            Color(red: 0.88, green: 0.20, blue: 0.20),
            Color(red: 0.20, green: 0.55, blue: 0.90),
            Color(red: 0.95, green: 0.82, blue: 0.10),
            Color(red: 0.22, green: 0.68, blue: 0.28),
            Color(red: 0.55, green: 0.18, blue: 0.80)
        ]
        for ci in 0..<15 {
            let fi = Double(ci)
            let cx = W * 0.04 + CGFloat(ci) / 15.0 * W * 0.92
            let isTop = ci % 2 == 0
            let baseY: CGFloat = isTop ? H * 0.12 + CGFloat((ci % 3)) * 8 : H * 0.90 - CGFloat((ci % 3)) * 8
            let wave = CGFloat(sin(t * 1.1 + fi * 1.3)) * 2.5
            let jc = jerseys[ci % jerseys.count]

            // #60 — Wave cheer animation (arms rise on point)
            let armRaise = crowdActive(ci: ci) ? CGFloat(abs(sin(t * 3.0 + fi * 0.8))) * -8 : 0
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: baseY + wave - 10 + armRaise, width: 10, height: 10)),
                     with: .color(jc.opacity(0.60)))
            var cBody = Path()
            cBody.move(to: CGPoint(x: cx, y: baseY + wave))
            cBody.addLine(to: CGPoint(x: cx, y: baseY + wave - 8))
            ctx.stroke(cBody, with: .color(jc.opacity(0.55)), lineWidth: 2.0)
            // Arms
            var cArms = Path()
            cArms.move(to: CGPoint(x: cx - 7, y: baseY + wave - 4 + armRaise * 0.6))
            cArms.addLine(to: CGPoint(x: cx, y: baseY + wave - 5))
            cArms.addLine(to: CGPoint(x: cx + 7, y: baseY + wave - 4 + armRaise * 0.6))
            ctx.stroke(cArms, with: .color(jc.opacity(0.50)), lineWidth: 1.5)
        }

        // #61 — Crowd umbrella accents (small arcs above some crowd members)
        for ui in 0..<5 {
            let ux = W * 0.12 + CGFloat(ui) * W * 0.18
            let uy = H * 0.10
            var umbrella = Path()
            umbrella.addArc(center: CGPoint(x: ux, y: uy + 8), radius: 10,
                            startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
            umbrella.closeSubpath()
            let uColors: [Color] = [Color.red, Color.blue, Color.yellow, Color.green, Color.purple]
            ctx.fill(umbrella, with: .color(uColors[ui % 5].opacity(0.40)))
        }

        // #62 — Scoreboard on post (rendered content indicators)
        let sbPostX = cL - 18; let sbY = cT - 34
        // Score digits as colored blocks (simplified)
        for di in 0..<2 {
            ctx.fill(Path(CGRect(x: sbPostX - 16 + CGFloat(di) * 18, y: sbY + 4, width: 14, height: 12)),
                     with: .color(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.60)))
        }

        // #63 — Set score display (small indicators below main scoreboard)
        let setBarY = cT + 4
        for si in 0..<3 {
            let sbarX = cL + CGFloat(si) * 14
            ctx.fill(Path(CGRect(x: sbarX, y: setBarY, width: 10, height: 4)),
                     with: .color(Color.white.opacity(si == 0 ? 0.75 : 0.25)))
        }

        // #64 — Match point gold border veil (overlay glow when match point)
        if matchPointActive {
            var mpVeil = ctx; mpVeil.addFilter(.blur(radius: 18))
            mpVeil.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                        with: .color(Color(red: 1.0, green: 0.85, blue: 0.15).opacity(0.18)))
            // Gold corner accents
            for (cx2, cy2) in [(0, 0), (W, 0), (0, H), (W, H)] {
                ctx.stroke(Path(CGRect(x: cx2 - 15, y: cy2 - 15, width: 30, height: 30)),
                           with: .color(Color(red: 1.0, green: 0.85, blue: 0.15).opacity(0.65)), lineWidth: 2.5)
            }
        }

        // #65 — Sunset sky gradient shift (dynamic sky color near horizon)
        let skyShift = CGFloat(0.5 + 0.5 * sin(t * 0.05))
        let sunsetOrange = Color(red: 0.95, green: 0.55, blue: 0.15).opacity(Double(skyShift) * 0.18)
        ctx.fill(Path(CGRect(x: 0, y: H * 0.22, width: W, height: H * 0.20)),
                 with: .linearGradient(
                    Gradient(colors: [Color.clear, sunsetOrange, Color.clear]),
                    startPoint: CGPoint(x: 0, y: H * 0.22),
                    endPoint: CGPoint(x: 0, y: H * 0.42)))

        // #66 — Seagull silhouette 1 (passing left to right)
        let gullPhase = fmod(t * 0.28, 1.0)
        let gullX = CGFloat(gullPhase) * (W + 40) - 20
        let gullY = H * 0.08 + CGFloat(sin(t * 0.8)) * 8
        drawSeagull(&ctx, x: gullX, y: gullY, scale: 1.0)

        // #67 — Seagull silhouette 2 (offset phase and height)
        let gullPhase2 = fmod(t * 0.22 + 0.4, 1.0)
        let gullX2 = CGFloat(gullPhase2) * (W + 40) - 20
        let gullY2 = H * 0.12 + CGFloat(sin(t * 0.65 + 1.4)) * 6
        drawSeagull(&ctx, x: gullX2, y: gullY2, scale: 0.78)

        // #68 — Ace wave ring (expanding ring on ace)
        if aceActive {
            let acePulse = CGFloat(fmod(t * 2.5, 1.0))
            let aceR = acePulse * 60
            var aceRing = ctx; aceRing.addFilter(.blur(radius: 3))
            aceRing.stroke(Path(ellipseIn: CGRect(x: ballCX - aceR, y: ballCY - aceR,
                                                   width: aceR * 2, height: aceR * 2)),
                           with: .color(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(1.0 - Double(acePulse))), lineWidth: 2.5)
        }

        // #69 — Spike thunderbolt icon (flash on spike)
        if spikeActive {
            let boltOpacity = CGFloat(abs(sin(t * 12))) * 0.90
            var boltGlow = ctx; boltGlow.addFilter(.blur(radius: 10))
            boltGlow.fill(Path(ellipseIn: CGRect(x: ballCX - 18, y: ballCY - 24, width: 36, height: 36)),
                          with: .color(Color(red: 1.0, green: 0.85, blue: 0.10).opacity(Double(boltOpacity) * 0.60)))
            // Bolt shape
            var bolt = Path()
            bolt.move(to: CGPoint(x: ballCX - 4, y: ballCY - 22))
            bolt.addLine(to: CGPoint(x: ballCX + 6, y: ballCY - 8))
            bolt.addLine(to: CGPoint(x: ballCX, y: ballCY - 8))
            bolt.addLine(to: CGPoint(x: ballCX + 4, y: ballCY + 6))
            bolt.addLine(to: CGPoint(x: ballCX - 8, y: ballCY - 5))
            bolt.addLine(to: CGPoint(x: ballCX - 2, y: ballCY - 5))
            bolt.closeSubpath()
            ctx.fill(bolt, with: .color(Color(red: 1.0, green: 0.92, blue: 0.10).opacity(Double(boltOpacity))))
        }

        // #70 — Sand spray on dive (10 dots radiating)
        if digActive {
            let playerX = lerp(ballCX, W * 0.5, 0.35)
            let playerY = cB - 5
            for si in 0..<10 {
                let angle = Double(si) * .pi / 5.0 - .pi * 0.3
                let frac = CGFloat(fmod(t * 3.0, 1.0))
                let dist = frac * 28 + CGFloat(si) * 2
                let sx = playerX + CGFloat(cos(angle)) * dist
                let sy = playerY - CGFloat(abs(sin(angle))) * dist * 0.4
                let sr: CGFloat = CGFloat(2.5 - frac * 2.0)
                if sr > 0 {
                    ctx.fill(Path(ellipseIn: CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2)),
                             with: .color(Color(red: 0.88, green: 0.78, blue: 0.56).opacity(0.70 * Double(1.0 - frac))))
                }
            }
        }

        // #71 — Game point gold veil (semi-transparent golden overlay)
        if matchPointActive {
            let veilPulse = CGFloat(0.5 + 0.5 * sin(t * 2.5)) * 0.08
            ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                     with: .color(Color(red: 1.0, green: 0.85, blue: 0.15).opacity(Double(veilPulse))))
        }

        // #72 — Crowd jump sequence (hands shoot up on point)
        if crowd > 0.6 {
            for cji in 0..<6 {
                let fi = Double(cji)
                let cjx = W * 0.15 + CGFloat(cji) * W * 0.12
                let jumpAmt = CGFloat(abs(sin(t * 3.5 + fi * 0.9))) * CGFloat(crowd) * 12
                var cjArms = Path()
                cjArms.move(to: CGPoint(x: cjx - 6, y: H * 0.14 - jumpAmt))
                cjArms.addLine(to: CGPoint(x: cjx, y: H * 0.12 - jumpAmt))
                cjArms.addLine(to: CGPoint(x: cjx + 6, y: H * 0.14 - jumpAmt))
                ctx.stroke(cjArms, with: .color(Color.white.opacity(0.40)), lineWidth: 1.8)
            }
        }

        // #73 — Crowd jump sequence repeat (lower crowd row)
        if crowd > 0.5 {
            for cji in 0..<5 {
                let fi = Double(cji)
                let cjx = W * 0.20 + CGFloat(cji) * W * 0.14
                let jumpAmt = CGFloat(abs(sin(t * 2.8 + fi * 1.1 + 2.0))) * CGFloat(crowd) * 10
                var jumpArm = Path()
                jumpArm.move(to: CGPoint(x: cjx - 5, y: H * 0.92 + jumpAmt))
                jumpArm.addLine(to: CGPoint(x: cjx + 5, y: H * 0.92 + jumpAmt))
                ctx.stroke(jumpArm, with: .color(Color.white.opacity(0.35)), lineWidth: 1.5)
            }
        }

        // #74 — Ocean sparkle glints (random twinkle on water surface)
        for gi in 0..<8 {
            let fi = Double(gi)
            let phase = fmod(t * 1.8 + fi * 0.7, 2.0)
            if phase < 1.0 {
                let gx = W * 0.08 + CGFloat(gi) / 8.0 * W * 0.84
                let gy = H * 0.448 + CGFloat(cos(fi * 1.8)) * 4
                let gop = CGFloat(sin(phase * .pi))
                ctx.fill(Path(ellipseIn: CGRect(x: gx - 2, y: gy - 2, width: 4, height: 4)),
                         with: .color(Color.white.opacity(Double(gop) * 0.65)))
            }
        }

        // #75 — Net tension glow line (subtle glow on net top edge under high action)
        if spikeActive || aceActive {
            var netGlow = ctx; netGlow.addFilter(.blur(radius: 4))
            var netLine = Path()
            netLine.move(to: CGPoint(x: cL, y: netY - 23))
            netLine.addLine(to: CGPoint(x: cR, y: netY - 23))
            netGlow.stroke(netLine, with: .color(Color.white.opacity(0.55)), lineWidth: 3)
        }

        // #76 — Ball trajectory arc ghost (dashed arc showing serve path)
        if serveActive {
            let arcMid = CGPoint(x: W * 0.5, y: H * 0.25)
            var arc = Path()
            arc.move(to: CGPoint(x: W * 0.5, y: cB - 20))
            arc.addQuadCurve(to: CGPoint(x: W * 0.5, y: netY - 10), control: arcMid)
            ctx.stroke(arc, with: .color(Color.white.opacity(0.20)), lineWidth: 1.2)
        }

        // #77 — Match point pulsing border (outer rect stroke)
        if matchPointActive {
            let borderPulse = CGFloat(0.5 + 0.5 * sin(t * 4.0)) * 0.85 + 0.15
            ctx.stroke(Path(roundedRect: CGRect(x: 3, y: 3, width: W - 6, height: H - 6), cornerRadius: 14),
                       with: .color(Color(red: 1.0, green: 0.85, blue: 0.15).opacity(Double(borderPulse))), lineWidth: 3.0)
        }

        // #78 — Rally heat shimmer (wavy distortion indicator in high-streak moments)
        if crowd > 0.7 {
            for hi in 0..<4 {
                let hx = W * 0.2 + CGFloat(hi) * W * 0.18
                let hy = H * 0.50
                let hWave = CGFloat(sin(t * 6 + Double(hi) * 1.2)) * 3
                var hLine = Path()
                hLine.move(to: CGPoint(x: hx, y: hy - 12 + hWave))
                hLine.addLine(to: CGPoint(x: hx, y: hy + 12 + hWave))
                ctx.stroke(hLine, with: .color(Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0.15)), lineWidth: 1.0)
            }
        }

        // #79 — Left post base shadow
        var lBaseShadow = ctx; lBaseShadow.addFilter(.blur(radius: 5))
        lBaseShadow.fill(Path(ellipseIn: CGRect(x: cL - 10, y: netY + 4, width: 20, height: 6)),
                         with: .color(Color.black.opacity(0.22)))

        // #80 — Right post base shadow
        var rBaseShadow = ctx; rBaseShadow.addFilter(.blur(radius: 5))
        rBaseShadow.fill(Path(ellipseIn: CGRect(x: cR - 10, y: netY + 4, width: 20, height: 6)),
                         with: .color(Color.black.opacity(0.22)))

        // #81 — Dig save glow (cyan tint around player when dig active)
        if digActive {
            let playerX2 = lerp(ballCX, W * 0.5, 0.35)
            let playerY2 = cB + (H - cB) * 0.28
            var digGlow = ctx; digGlow.addFilter(.blur(radius: 20))
            digGlow.fill(Path(ellipseIn: CGRect(x: playerX2 - 30, y: playerY2 - 20, width: 60, height: 50)),
                         with: .color(Color(red: 0.15, green: 0.85, blue: 0.85).opacity(0.35)))
        }

        // #82 — Spike impact concentric rings
        if spikeActive {
            for ri in 1...3 {
                let rPulse = CGFloat(fmod(t * 3.0 + Double(ri) * 0.25, 1.0))
                let rr = rPulse * CGFloat(ri) * 22
                ctx.stroke(Path(ellipseIn: CGRect(x: ballCX - rr, y: ballCY - rr, width: rr * 2, height: rr * 2)),
                           with: .color(Color.red.opacity(Double(1.0 - rPulse) * 0.45)), lineWidth: 1.5)
            }
        }

        // #83 — Ambient court light (subtle center glow on court)
        var courtLight = ctx; courtLight.addFilter(.blur(radius: 40))
        courtLight.fill(Path(ellipseIn: CGRect(x: W * 0.3, y: netY - 30, width: W * 0.4, height: 60)),
                        with: .color(Color.white.opacity(0.04)))

        // #84 — Crowd energy pulse bar (visible at bottom when crowd is high)
        if crowd > 0.4 {
            let barW = (cR - cL) * CGFloat(crowd)
            let barRect = CGRect(x: cL, y: H - 10, width: barW, height: 4)
            ctx.fill(Path(roundedRect: barRect, cornerRadius: 2),
                     with: .linearGradient(
                        Gradient(colors: [Color(red: 0.98, green: 0.75, blue: 0.14), Color(red: 0.95, green: 0.30, blue: 0.10)]),
                        startPoint: CGPoint(x: cL, y: H - 10),
                        endPoint: CGPoint(x: cL + barW, y: H - 10)))
        }

        // #85 — Ace ring secondary pulse (delayed wave)
        if aceActive {
            let acePulse2 = CGFloat(fmod(t * 2.5 + 0.5, 1.0))
            let aceR2 = acePulse2 * 80
            ctx.stroke(Path(ellipseIn: CGRect(x: ballCX - aceR2, y: ballCY - aceR2,
                                              width: aceR2 * 2, height: aceR2 * 2)),
                       with: .color(Color.white.opacity(Double(1.0 - acePulse2) * 0.35)), lineWidth: 1.5)
        }

        // #86 — Final ambient depth gradient at top (vignette for depth)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.08)),
                 with: .linearGradient(
                    Gradient(colors: [Color.black.opacity(0.25), Color.clear]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: H * 0.08)))
    }

    private func drawSeagull(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
        var gull = Path()
        gull.move(to: CGPoint(x: x - 12 * scale, y: y))
        gull.addQuadCurve(to: CGPoint(x: x, y: y - 5 * scale),
                          control: CGPoint(x: x - 6 * scale, y: y - 8 * scale))
        gull.addQuadCurve(to: CGPoint(x: x + 12 * scale, y: y),
                          control: CGPoint(x: x + 6 * scale, y: y - 8 * scale))
        ctx.stroke(gull, with: .color(Color(white: 0.20).opacity(0.55)), lineWidth: 1.5 * scale)
    }

    private func crowdActive(ci: Int) -> Bool {
        crowd > 0.5 && (ci % 3 == Int(t * 2) % 3)
    }

    // ─── Input Zone ────────────────────────────────────────────────────────────

    private func drawInputZone(_ ctx: inout GraphicsContext) {
        let pulse = CGFloat(sin(t * 8)) * 2.5
        let zoneColor: Color = {
            switch touchPhase {
            case .pass:  return Color(red: 0.98, green: 0.75, blue: 0.14)
            case .set:   return Color(red: 0.15, green: 0.85, blue: 0.85)
            case .spike: return Color.red
            }
        }()
        let zoneRect = CGRect(x: cL - pulse, y: netY + (cB - netY) * 0.15 - pulse,
                               width: cR - cL + pulse * 2,
                               height: (cB - netY) * 0.60 + pulse * 2)
        var gc = ctx; gc.addFilter(.blur(radius: 10))
        gc.fill(Path(roundedRect: zoneRect, cornerRadius: 8),
                with: .color(zoneColor.opacity(0.18)))
        ctx.stroke(Path(roundedRect: zoneRect, cornerRadius: 8),
                   with: .color(zoneColor.opacity(0.80)), lineWidth: 2.0)

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
    @State private var padAimX: CGFloat = 0.5

    // Canvas FX state
    @State private var spikeActive: Bool = false
    @State private var aceActive: Bool = false
    @State private var digActive: Bool = false
    @State private var serveActive: Bool = false
    @State private var matchPointActive: Bool = false

    private let XP_CAP_PER_SESSION = 500
    private let accentColor = Color(red: 0.98, green: 0.75, blue: 0.14)
    private let opponentName = "Kai Nexus"

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(colors: [Color(red: 0.04, green: 0.04, blue: 0.12), Theme.deepBlack],
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
                        crowdLevel: crowdLevel,
                        spikeActive: spikeActive,
                        aceActive: aceActive,
                        digActive: digActive,
                        serveActive: serveActive,
                        matchPointActive: matchPointActive
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

                // Universal ArenaPad controls (GameModeId.usesArenaPad):
                // stick/d-pad aims the spike target, ✕ = pass/set/spike in its window.
                ArenaPadControlBar(accentColor: accentColor, isActive: phase == .playing) { action in
                    handlePadAction(action)
                }
                .padding(.top, 4)

                Spacer()
            }

            if showFeedback {
                Text(feedbackText)
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(feedbackText.contains("ACE") ? accentColor :
                                     (feedbackText.contains("PASS") || feedbackText.contains("SET") ||
                                      feedbackText.contains("SPIKE") || feedbackText.contains("DIG") ?
                                      Color(red: 0.2, green: 0.9, blue: 0.4) : .red))
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
                tapButton(label: "✕ — PASS", color: accentColor)
            case .set:
                tapButton(label: "✕ — SET", color: Theme.brandCyan)
            case .spike:
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.4), lineWidth: 2))
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 18)).foregroundStyle(.red)
                        Text("✕ — SPIKE").font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(.red)
                    }
                }
                .frame(height: 54).padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func tapButton(label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill").font(.system(size: 16))
            Text(label).font(.system(size: 17, weight: .black, design: .monospaced))
        }
        .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 15)
        .background(color).clipShape(.rect(cornerRadius: 14))
        .shadow(color: color.opacity(0.4), radius: 8)
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
        // Haptic: soft on serve
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        serveActive = true
        withAnimation { ball.position = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: 0.18); ball.isVisible = true }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                let landX = CGFloat.random(in: 0.25...0.75)
                withAnimation(.easeInOut(duration: 0.55)) { ball.position = CGPoint(x: landX, y: 0.78) }
                rallyState = .awaitingPass
            }
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                serveActive = false
                openInputWindow()
            }
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
                if inputWindowOpen {
                    inputWindowOpen = false
                    flashFeedback("MISSED!")
                    // Haptic: error on point against
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    opponentWinsPoint()
                }
            }
        }
    }

    /// Universal pad mapping — left stick/d-pad aims the spike target, ✕ = pass/set/spike in its timing window.
    private func handlePadAction(_ action: ArenaPadAction) {
        guard phase == .playing else { return }
        switch action {
        case .leftStick(let v):
            padAimX = min(0.8, max(0.2, 0.5 + CGFloat(v.x) * 0.3))
        case .direction(.left):
            padAimX = max(0.2, padAimX - 0.1)
        case .direction(.right):
            padAimX = min(0.8, padAimX + 0.1)
        case .primary:
            handlePlayerInput()
        default:
            break
        }
    }

    private func handlePlayerInput() {
        guard inputWindowOpen, phase == .playing else { return }
        inputWindowTask?.cancel(); inputWindowOpen = false
        switch touchPhase {
        case .pass:
            // Haptic: medium on successful dig/set
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            flashFeedback("PASS!")
            advanceBall(toY: 0.55); rallyState = .awaitingSet; touchPhase = .set
            Task { try? await Task.sleep(for: .milliseconds(500)); await MainActor.run { openInputWindow() } }
        case .set:
            // Haptic: medium on set
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            flashFeedback("SET!")
            advanceBall(toY: 0.42); rallyState = .awaitingSpike; touchPhase = .spike
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
        // Haptic: heavy on spike kill
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        spikeActive = true
        let spikeX = padAimX
        withAnimation(.easeIn(duration: 0.4)) { ball.position = CGPoint(x: spikeX, y: 0.25) }
        rallyState = .ballCrossing
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                spikeActive = false
                let prq = viewModel.effectiveMetrics.prqScore
                let digChance = 0.3 + (prq / 200.0)
                if Double.random(in: 0...1) < digChance {
                    rallyState = .opponentDig
                    withAnimation(.easeOut(duration: 0.35)) { ball.position = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: 0.18) }
                    flashFeedback("DIG!")
                    // Haptic: medium on successful dig
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    digActive = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        await MainActor.run { digActive = false }
                        try? await Task.sleep(for: .milliseconds(300))
                        await MainActor.run { opponentCounter() }
                    }
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
        // Update match point state
        let scoreDiff = playerScore - opponentScore
        matchPointActive = (timeLeft <= 20 && scoreDiff >= 3) || playerScore >= 15
        // Haptic: rigid on match point / set win
        if matchPointActive {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } else if ace {
            // Haptic: heavy on ace
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        // Haptic: error (success) on ball in / point scored
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if ace {
            aceActive = true
            withAnimation(.spring(response: 0.25)) { showAce = true }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) { showAce = false }
                    aceActive = false
                    scheduleNextRally()
                }
            }
        } else { scheduleNextRally() }
    }

    private func opponentWinsPoint() {
        withAnimation { opponentScore += 1 }
        rallyStreak = 0
        // Haptic: error notification on point against
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        scheduleNextRally()
    }

    private func scheduleNextRally() {
        Task {
            try? await Task.sleep(for: .milliseconds(1000))
            await MainActor.run { guard phase == .playing else { return }; beginRally() }
        }
    }

    private func endMatch() { cancelAllTasks(); GameResultService.saveResult(modeId: "volleyball", userScore: playerScore, opponentScore: opponentScore); withAnimation(.spring(response: 0.4)) { phase = .result } }

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
