import SwiftUI

// MARK: - Enums

private enum BBallPhase {
    case ready, batting, pitching, inningBreak, result
}

private enum PitchType: String, CaseIterable {
    case fastball = "FASTBALL"
    case curveball = "CURVEBALL"
    case slider = "SLIDER"

    var duration: Double {
        switch self {
        case .fastball:  return 1.4
        case .curveball: return 1.9
        case .slider:    return 1.7
        }
    }

    var speedLabel: String {
        switch self {
        case .fastball:  return "95 MPH"
        case .curveball: return "78 MPH"
        case .slider:    return "84 MPH"
        }
    }

    var curveOffset: CGFloat {
        switch self {
        case .fastball:  return 0
        case .curveball: return 0.10
        case .slider:    return -0.08
        }
    }

    var icon: String {
        switch self {
        case .fastball:  return "bolt.fill"
        case .curveball: return "arrow.turn.down.left"
        case .slider:    return "arrow.turn.down.right"
        }
    }
}

private enum SwingResult {
    case homeRun, basehit, foul, miss, none
}

private let XP_CAP_PER_SESSION = 500
private let INNINGS: Int = 5
private let OUTS_PER_INNING: Int = 3

// MARK: - Stadium Canvas View

private struct StadiumCanvas: View {
    let pitchProgress: Double
    let pitch: PitchType
    let batterPhase: String
    let pitcherPhase: String
    let hitProgress: Double
    let hitType: String
    let lastHitTime: Double
    let isAIBatting: Bool
    let crowdLevel: Double
    let aiBatterPhase: String

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = StadiumDrawer(
                    size: size, t: t,
                    pitchProgress: pitchProgress,
                    pitch: pitch,
                    batterPhase: batterPhase,
                    pitcherPhase: pitcherPhase,
                    hitProgress: hitProgress,
                    hitType: hitType,
                    lastHitTime: lastHitTime,
                    isAIBatting: isAIBatting,
                    crowdLevel: crowdLevel,
                    aiBatterPhase: aiBatterPhase
                )
                d.render(ctx: &ctx)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Stadium Drawer

private struct StadiumDrawer {
    let size: CGSize
    let t: Double
    let pitchProgress: Double
    let pitch: PitchType
    let batterPhase: String
    let pitcherPhase: String
    let hitProgress: Double
    let hitType: String
    let lastHitTime: Double
    let isAIBatting: Bool
    let crowdLevel: Double
    let aiBatterPhase: String

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var floorY: CGFloat { H * 0.70 }
    var batterX: CGFloat { W * 0.73 }
    var pitcherX: CGFloat { W * 0.27 }
    var moundY: CGFloat { floorY - 5 }

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawStands(ctx: &ctx)
        drawField(ctx: &ctx)
        if isAIBatting {
            drawAIPitchingScene(ctx: &ctx)
        } else {
            drawPitcher(ctx: &ctx)
            drawBatter(ctx: &ctx)
            if pitchProgress >= 0 && hitProgress < 0 {
                drawPitchBall(ctx: &ctx)
            }
            if hitProgress >= 0 {
                drawHitBall(ctx: &ctx)
            }
            if lastHitTime > 0 && t - lastHitTime < 0.55 {
                drawHitSparks(ctx: &ctx)
            }
            if pitchProgress >= 0.45 && pitchProgress < 1.0 && hitProgress < 0 {
                drawSwingZoneRing(ctx: &ctx)
            }
        }
    }

    // MARK: Sky

    private func drawSky(ctx: inout GraphicsContext) {
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.18), Color(red: 0.06, green: 0.10, blue: 0.30)]),
                startPoint: CGPoint(x: W * 0.5, y: 0),
                endPoint: CGPoint(x: W * 0.5, y: H * 0.38)
            )
        )
        for i in 0..<20 {
            let sx = W * CGFloat((i * 131 + 41) % 97) / 97.0
            let sy = H * 0.01 + H * 0.20 * CGFloat((i * 83 + 19) % 100) / 100.0
            let tw = 0.4 + 0.35 * sin(t * 1.6 + Double(i) * 0.8)
            var gc = ctx; gc.opacity = tw
            gc.fill(Path(ellipseIn: CGRect(x: sx - 1, y: sy - 1, width: 2, height: 2)), with: .color(.white))
        }
        for poleX in [W * 0.04, W * 0.30, W * 0.70, W * 0.96] {
            var gc = ctx; gc.addFilter(.blur(radius: 22)); gc.opacity = 0.28
            gc.fill(Path(ellipseIn: CGRect(x: poleX - 44, y: -14, width: 88, height: 55)), with: .color(.white))
        }
        for poleX in [W * 0.04, W * 0.30, W * 0.70, W * 0.96] {
            var pole = Path()
            pole.move(to: CGPoint(x: poleX, y: H * 0.28))
            pole.addLine(to: CGPoint(x: poleX, y: H * 0.08))
            ctx.stroke(pole, with: .color(Color(white: 0.55)), lineWidth: 2)
            ctx.fill(Path(CGRect(x: poleX - 10, y: H * 0.07, width: 20, height: 5)), with: .color(Color(white: 0.90)))
            var lGlow = ctx; lGlow.addFilter(.blur(radius: 6)); lGlow.opacity = 0.7
            lGlow.fill(Path(ellipseIn: CGRect(x: poleX - 8, y: H * 0.07, width: 16, height: 6)), with: .color(.white))
        }
    }

    // MARK: Stands

    private func drawStands(ctx: inout GraphicsContext) {
        let standTop: CGFloat = H * 0.09
        let standBot: CGFloat = H * 0.30
        for tier in 0..<5 {
            let ty = standTop + CGFloat(tier) * (standBot - standTop) / 5
            let h = (standBot - standTop) / 5 - 1
            ctx.fill(Path(CGRect(x: 0, y: ty, width: W, height: h)),
                     with: .color(Color(white: 0.07 + 0.015 * Double(tier))))
        }
        let jerseys: [Color] = [
            Color(red: 0.14, green: 0.32, blue: 0.72), Color(red: 0.72, green: 0.12, blue: 0.12),
            Color(red: 0.94, green: 0.84, blue: 0.18), Color(red: 0.82, green: 0.38, blue: 0.04),
            Color(red: 0.18, green: 0.62, blue: 0.22), Color(white: 0.88),
        ]
        let cols = 20
        for row in 0..<4 {
            let ry = standTop + CGFloat(row) * (standBot - standTop) / 5.0 + 2
            let excited = crowdLevel > 0.55 && row <= 1
            for col in 0..<cols {
                let cx = W * 0.02 + CGFloat(col) * (W * 0.96) / CGFloat(cols - 1)
                let jc = jerseys[(col * 7 + row * 11) % jerseys.count]
                let skin = Color(red: 0.82 + 0.06 * CGFloat((col + row) % 3),
                                 green: 0.62 + 0.06 * CGFloat((col * 2 + row) % 3),
                                 blue: 0.50)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 3.5, y: ry, width: 7, height: 7)), with: .color(skin))
                ctx.fill(Path(CGRect(x: cx - 4, y: ry + 7, width: 8, height: 6)), with: .color(jc.opacity(0.85)))
                if excited {
                    let wave = CGFloat(sin(t * 3.5 + Double(col) * 0.6)) * 2.5
                    var arms = Path()
                    arms.move(to: CGPoint(x: cx - 4, y: ry + 9))
                    arms.addLine(to: CGPoint(x: cx - 10, y: ry + 3 + wave))
                    arms.move(to: CGPoint(x: cx + 4, y: ry + 9))
                    arms.addLine(to: CGPoint(x: cx + 10, y: ry + 3 + wave))
                    ctx.stroke(arms, with: .color(jc.opacity(0.7)), lineWidth: 1.5)
                }
            }
        }
        ctx.fill(Path(CGRect(x: 0, y: standBot, width: W, height: 7)), with: .color(Color(white: 0.04)))
    }

    // MARK: Field

    private func drawField(ctx: inout GraphicsContext) {
        let fieldTop: CGFloat = H * 0.32
        ctx.fill(
            Path(CGRect(x: 0, y: fieldTop, width: W * 0.56, height: H - fieldTop)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.09, green: 0.30, blue: 0.09), Color(red: 0.06, green: 0.20, blue: 0.06)]),
                startPoint: CGPoint(x: 0, y: fieldTop), endPoint: CGPoint(x: 0, y: H)
            )
        )
        for s in 0..<6 {
            if s % 2 == 0 {
                ctx.fill(Path(CGRect(x: CGFloat(s) * W * 0.09, y: fieldTop, width: W * 0.09, height: H - fieldTop)),
                         with: .color(Color(white: 1).opacity(0.018)))
            }
        }
        ctx.fill(
            Path(CGRect(x: W * 0.56, y: H * 0.36, width: W * 0.44, height: H - H * 0.36)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.08, green: 0.26, blue: 0.08), Color(red: 0.05, green: 0.18, blue: 0.05)]),
                startPoint: CGPoint(x: W * 0.56, y: H * 0.36), endPoint: CGPoint(x: W * 0.56, y: H)
            )
        )
        // Outfield wall
        var wall = Path()
        wall.move(to: CGPoint(x: 0, y: H * 0.32))
        wall.addLine(to: CGPoint(x: W * 0.52, y: H * 0.32))
        wall.addLine(to: CGPoint(x: W * 0.52, y: H * 0.32 + 14))
        wall.addLine(to: CGPoint(x: 0, y: H * 0.32 + 14))
        wall.closeSubpath()
        ctx.fill(wall, with: .color(Color(red: 0.08, green: 0.36, blue: 0.10)))
        ctx.stroke(wall, with: .color(Color(red: 0.20, green: 0.55, blue: 0.22)), lineWidth: 1)
        let distText = ctx.resolve(Text("380 FT")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.45)))
        ctx.draw(distText, at: CGPoint(x: W * 0.14, y: H * 0.32 + 7))

        // Infield dirt
        var dirt = Path()
        dirt.move(to: CGPoint(x: batterX - 22, y: floorY + 4))
        dirt.addLine(to: CGPoint(x: batterX + 20, y: floorY + 4))
        dirt.addLine(to: CGPoint(x: pitcherX + 90, y: H * 0.42))
        dirt.addLine(to: CGPoint(x: pitcherX - 90, y: H * 0.42))
        dirt.closeSubpath()
        ctx.fill(dirt, with: .linearGradient(
            Gradient(colors: [Color(red: 0.50, green: 0.35, blue: 0.20), Color(red: 0.38, green: 0.26, blue: 0.14)]),
            startPoint: CGPoint(x: pitcherX, y: H * 0.42), endPoint: CGPoint(x: pitcherX, y: floorY + 4)
        ))
        ctx.fill(Path(ellipseIn: CGRect(x: pitcherX - 22, y: moundY - 5, width: 44, height: 10)),
                 with: .color(Color(red: 0.48, green: 0.34, blue: 0.18)))
        ctx.fill(Path(CGRect(x: pitcherX - 9, y: moundY - 2.5, width: 18, height: 5)),
                 with: .color(.white.opacity(0.85)))

        // Home plate
        var plate = Path()
        plate.move(to: CGPoint(x: batterX - 13, y: floorY - 2))
        plate.addLine(to: CGPoint(x: batterX + 13, y: floorY - 2))
        plate.addLine(to: CGPoint(x: batterX + 13, y: floorY + 5))
        plate.addLine(to: CGPoint(x: batterX, y: floorY + 9))
        plate.addLine(to: CGPoint(x: batterX - 13, y: floorY + 5))
        plate.closeSubpath()
        ctx.fill(plate, with: .color(.white.opacity(0.90)))

        // Bases
        for (bx, by) in [(W * 0.90, floorY - 6), (W * 0.46, H * 0.47), (batterX - 42, floorY - 9)] {
            ctx.fill(Path(CGRect(x: bx - 6, y: by - 5, width: 12, height: 9)), with: .color(.white.opacity(0.80)))
        }
        // Foul lines
        var fl = Path()
        fl.move(to: CGPoint(x: batterX, y: floorY))
        fl.addLine(to: CGPoint(x: W * 0.02, y: H * 0.32))
        fl.move(to: CGPoint(x: batterX, y: floorY))
        fl.addLine(to: CGPoint(x: W * 0.98, y: H * 0.36))
        ctx.stroke(fl, with: .color(.white.opacity(0.22)), lineWidth: 1.5)
        // Ground shadows
        ctx.fill(Path(ellipseIn: CGRect(x: pitcherX - 16, y: floorY, width: 32, height: 5)), with: .color(.black.opacity(0.35)))
        ctx.fill(Path(ellipseIn: CGRect(x: batterX - 18, y: floorY, width: 36, height: 5)), with: .color(.black.opacity(0.35)))
    }

    // MARK: Pitcher

    private func drawPitcher(ctx: inout GraphicsContext) {
        let x = pitcherX; let y = moundY
        let color = Color(red: 0.14, green: 0.32, blue: 0.72)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 7

        switch pitcherPhase {
        case "windup":
            ctx.fill(Path(ellipseIn: CGRect(x: x - r - 2, y: y - 42 - r, width: r*2, height: r*2)), with: .color(skin))
            var body = Path(); body.move(to: CGPoint(x: x - 2, y: y - 42)); body.addLine(to: CGPoint(x: x + 3, y: y - 16))
            ctx.stroke(body, with: .color(color), lineWidth: 3)
            var ta = Path(); ta.move(to: CGPoint(x: x, y: y - 30)); ta.addLine(to: CGPoint(x: x + 22, y: y - 42))
            ctx.stroke(ta, with: .color(color), lineWidth: 2.5)
            ctx.fill(Path(ellipseIn: CGRect(x: x + 19, y: y - 47, width: 8, height: 8)),
                     with: .color(Color(red: 0.93, green: 0.86, blue: 0.68)))
            var ga = Path(); ga.move(to: CGPoint(x: x, y: y - 30)); ga.addLine(to: CGPoint(x: x - 18, y: y - 26))
            ctx.stroke(ga, with: .color(color), lineWidth: 2.5)
            var legs = Path()
            legs.move(to: CGPoint(x: x + 3, y: y - 16)); legs.addLine(to: CGPoint(x: x + 16, y: y))
            legs.move(to: CGPoint(x: x + 3, y: y - 16)); legs.addLine(to: CGPoint(x: x - 6, y: y - 26))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        case "release":
            ctx.fill(Path(ellipseIn: CGRect(x: x - r + 4, y: y - 40 - r, width: r*2, height: r*2)), with: .color(skin))
            var body = Path(); body.move(to: CGPoint(x: x + 4, y: y - 40)); body.addLine(to: CGPoint(x: x - 4, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3)
            var ta = Path(); ta.move(to: CGPoint(x: x + 1, y: y - 30)); ta.addLine(to: CGPoint(x: x + 24, y: y - 24))
            ctx.stroke(ta, with: .color(color), lineWidth: 2.5)
            var ga = Path(); ga.move(to: CGPoint(x: x + 1, y: y - 30)); ga.addLine(to: CGPoint(x: x - 16, y: y - 38))
            ctx.stroke(ga, with: .color(color), lineWidth: 2.5)
            var legs = Path()
            legs.move(to: CGPoint(x: x - 4, y: y - 14)); legs.addLine(to: CGPoint(x: x + 18, y: y))
            legs.move(to: CGPoint(x: x - 4, y: y - 14)); legs.addLine(to: CGPoint(x: x - 16, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        case "followthrough":
            ctx.fill(Path(ellipseIn: CGRect(x: x - r + 6, y: y - 36 - r, width: r*2, height: r*2)), with: .color(skin))
            var body = Path(); body.move(to: CGPoint(x: x + 6, y: y - 36)); body.addLine(to: CGPoint(x: x - 4, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3)
            var ta = Path(); ta.move(to: CGPoint(x: x + 2, y: y - 27)); ta.addLine(to: CGPoint(x: x + 18, y: y - 14))
            ctx.stroke(ta, with: .color(color), lineWidth: 2.5)
            var ga = Path(); ga.move(to: CGPoint(x: x + 2, y: y - 27)); ga.addLine(to: CGPoint(x: x - 14, y: y - 20))
            ctx.stroke(ga, with: .color(color), lineWidth: 2.5)
            var legs = Path()
            legs.move(to: CGPoint(x: x - 4, y: y - 14)); legs.addLine(to: CGPoint(x: x + 18, y: y))
            legs.move(to: CGPoint(x: x - 4, y: y - 14)); legs.addLine(to: CGPoint(x: x - 16, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        default:
            let bob = CGFloat(sin(t * 1.4)) * 1.5
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - 38 - r + bob, width: r*2, height: r*2)), with: .color(skin))
            var body = Path(); body.move(to: CGPoint(x: x, y: y - 38 + bob)); body.addLine(to: CGPoint(x: x, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3)
            var arms = Path(); arms.move(to: CGPoint(x: x - 16, y: y - 28 + bob)); arms.addLine(to: CGPoint(x: x + 16, y: y - 28 + bob))
            ctx.stroke(arms, with: .color(color), lineWidth: 2.5)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 20, y: y - 32 + bob, width: 7, height: 7)),
                     with: .color(Color(red: 0.93, green: 0.86, blue: 0.68)))
            var legs = Path()
            legs.move(to: CGPoint(x: x, y: y - 14)); legs.addLine(to: CGPoint(x: x - 11, y: y))
            legs.move(to: CGPoint(x: x, y: y - 14)); legs.addLine(to: CGPoint(x: x + 11, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)
        }
    }

    // MARK: Batter

    private func drawBatter(ctx: inout GraphicsContext) {
        let x = batterX; let y = floorY
        let color = Color(red: 0.82, green: 0.18, blue: 0.14)
        let helmetColor = Color(red: 0.65, green: 0.12, blue: 0.10)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let batColor = Color(red: 0.42, green: 0.26, blue: 0.10)
        let r: CGFloat = 8.5

        func helmet(hx: CGFloat, hy: CGFloat) {
            ctx.fill(Path(ellipseIn: CGRect(x: hx - r, y: hy - r, width: r*2, height: r*2)), with: .color(skin))
            var h = Path()
            h.addArc(center: CGPoint(x: hx, y: hy), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            h.addLine(to: CGPoint(x: hx - r - 5, y: hy))
            ctx.fill(h, with: .color(helmetColor))
        }

        switch batterPhase {
        case "swing":
            helmet(hx: x + 3, hy: y - 46)
            var body = Path(); body.move(to: CGPoint(x: x + 3, y: y - 46)); body.addLine(to: CGPoint(x: x - 5, y: y - 20))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            var arms = Path(); arms.move(to: CGPoint(x: x - 1, y: y - 35)); arms.addLine(to: CGPoint(x: x - 32, y: y - 31))
            ctx.stroke(arms, with: .color(color), lineWidth: 3)
            var bat = Path(); bat.move(to: CGPoint(x: x + 10, y: y - 33)); bat.addLine(to: CGPoint(x: x - 42, y: y - 28))
            ctx.stroke(bat, with: .color(batColor), lineWidth: 5)
            var hl = Path(); hl.move(to: CGPoint(x: x + 6, y: y - 34)); hl.addLine(to: CGPoint(x: x - 38, y: y - 29))
            ctx.stroke(hl, with: .color(Color(white: 0.9).opacity(0.22)), lineWidth: 2)
            var legs = Path()
            legs.move(to: CGPoint(x: x - 5, y: y - 20)); legs.addLine(to: CGPoint(x: x - 12, y: y))
            legs.move(to: CGPoint(x: x - 5, y: y - 20)); legs.addLine(to: CGPoint(x: x + 18, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 3)

        case "miss":
            helmet(hx: x - 5, hy: y - 44)
            var body = Path(); body.move(to: CGPoint(x: x - 5, y: y - 44)); body.addLine(to: CGPoint(x: x + 8, y: y - 20))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            var arms = Path(); arms.move(to: CGPoint(x: x + 2, y: y - 33)); arms.addLine(to: CGPoint(x: x - 24, y: y - 20))
            ctx.stroke(arms, with: .color(color), lineWidth: 3)
            var bat = Path(); bat.move(to: CGPoint(x: x + 6, y: y - 31)); bat.addLine(to: CGPoint(x: x - 24, y: y - 14))
            ctx.stroke(bat, with: .color(batColor), lineWidth: 5)
            var legs = Path()
            legs.move(to: CGPoint(x: x + 8, y: y - 20)); legs.addLine(to: CGPoint(x: x - 10, y: y))
            legs.move(to: CGPoint(x: x + 8, y: y - 20)); legs.addLine(to: CGPoint(x: x + 20, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 3)

        case "celebrate":
            let jump = CGFloat(max(0, sin(t * 5.5))) * 10
            helmet(hx: x, hy: y - 50 - jump)
            var body = Path(); body.move(to: CGPoint(x: x, y: y - 50 - jump)); body.addLine(to: CGPoint(x: x, y: y - 22 - jump))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            var arms = Path()
            arms.move(to: CGPoint(x: x, y: y - 40 - jump)); arms.addLine(to: CGPoint(x: x - 24, y: y - 54 - jump))
            arms.move(to: CGPoint(x: x, y: y - 40 - jump)); arms.addLine(to: CGPoint(x: x + 24, y: y - 54 - jump))
            ctx.stroke(arms, with: .color(color), lineWidth: 3)
            var legs = Path()
            legs.move(to: CGPoint(x: x, y: y - 22 - jump)); legs.addLine(to: CGPoint(x: x - 12, y: y - jump))
            legs.move(to: CGPoint(x: x, y: y - 22 - jump)); legs.addLine(to: CGPoint(x: x + 12, y: y - jump))
            ctx.stroke(legs, with: .color(color), lineWidth: 3)

        default:
            let bob = CGFloat(sin(t * 2.0)) * 1.0
            helmet(hx: x, hy: y - 46 + bob)
            var body = Path(); body.move(to: CGPoint(x: x, y: y - 46 + bob)); body.addLine(to: CGPoint(x: x, y: y - 20))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            var arms = Path()
            arms.move(to: CGPoint(x: x, y: y - 36 + bob)); arms.addLine(to: CGPoint(x: x - 20, y: y - 31 + bob))
            ctx.stroke(arms, with: .color(color), lineWidth: 3)
            var arms2 = Path()
            arms2.move(to: CGPoint(x: x, y: y - 36 + bob)); arms2.addLine(to: CGPoint(x: x + 6, y: y - 31 + bob))
            ctx.stroke(arms2, with: .color(color), lineWidth: 3)
            var bat = Path(); bat.move(to: CGPoint(x: x - 18, y: y - 31 + bob)); bat.addLine(to: CGPoint(x: x + 8, y: y - 58 + bob))
            ctx.stroke(bat, with: .color(batColor), lineWidth: 5)
            var hl = Path(); hl.move(to: CGPoint(x: x - 10, y: y - 42 + bob)); hl.addLine(to: CGPoint(x: x + 6, y: y - 58 + bob))
            ctx.stroke(hl, with: .color(Color(white: 0.9).opacity(0.22)), lineWidth: 2)
            var legs = Path()
            legs.move(to: CGPoint(x: x, y: y - 20)); legs.addLine(to: CGPoint(x: x - 16, y: y))
            legs.move(to: CGPoint(x: x, y: y - 20)); legs.addLine(to: CGPoint(x: x + 16, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 3)
        }
    }

    // MARK: AI Pitching Scene

    private func drawAIPitchingScene(ctx: inout GraphicsContext) {
        let aiBatterColor = Color(red: 0.72, green: 0.12, blue: 0.12)
        let playerPitcherColor = Color(red: 0.14, green: 0.32, blue: 0.72)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let bx = pitcherX; let by = moundY
        let px = batterX; let py = floorY
        let r: CGFloat = 7.5

        let bob = CGFloat(sin(t * 1.8)) * 1.2
        switch aiBatterPhase {
        case "swing":
            ctx.fill(Path(ellipseIn: CGRect(x: bx - r + 3, y: by - 44 - r, width: r*2, height: r*2)), with: .color(skin))
            var body = Path(); body.move(to: CGPoint(x: bx + 3, y: by - 44)); body.addLine(to: CGPoint(x: bx - 3, y: by - 18))
            ctx.stroke(body, with: .color(aiBatterColor), lineWidth: 3.5)
            var arms = Path(); arms.move(to: CGPoint(x: bx, y: by - 33)); arms.addLine(to: CGPoint(x: bx + 30, y: by - 29))
            ctx.stroke(arms, with: .color(aiBatterColor), lineWidth: 3)
            var bat = Path(); bat.move(to: CGPoint(x: bx - 10, y: by - 31)); bat.addLine(to: CGPoint(x: bx + 40, y: by - 26))
            ctx.stroke(bat, with: .color(Color(red: 0.42, green: 0.26, blue: 0.10)), lineWidth: 5)
            var legs = Path()
            legs.move(to: CGPoint(x: bx - 3, y: by - 18)); legs.addLine(to: CGPoint(x: bx + 14, y: by))
            legs.move(to: CGPoint(x: bx - 3, y: by - 18)); legs.addLine(to: CGPoint(x: bx - 14, y: by))
            ctx.stroke(legs, with: .color(aiBatterColor), lineWidth: 3)
        default:
            ctx.fill(Path(ellipseIn: CGRect(x: bx - r, y: by - 44 - r + bob, width: r*2, height: r*2)), with: .color(skin))
            var body = Path(); body.move(to: CGPoint(x: bx, y: by - 44 + bob)); body.addLine(to: CGPoint(x: bx, y: by - 18))
            ctx.stroke(body, with: .color(aiBatterColor), lineWidth: 3.5)
            var arms = Path()
            arms.move(to: CGPoint(x: bx, y: by - 34 + bob)); arms.addLine(to: CGPoint(x: bx + 18, y: by - 29 + bob))
            arms.move(to: CGPoint(x: bx, y: by - 34 + bob)); arms.addLine(to: CGPoint(x: bx - 6, y: by - 29 + bob))
            ctx.stroke(arms, with: .color(aiBatterColor), lineWidth: 3)
            var bat = Path(); bat.move(to: CGPoint(x: bx + 16, y: by - 29 + bob)); bat.addLine(to: CGPoint(x: bx - 8, y: by - 56 + bob))
            ctx.stroke(bat, with: .color(Color(red: 0.42, green: 0.26, blue: 0.10)), lineWidth: 5)
            var legs = Path()
            legs.move(to: CGPoint(x: bx, y: by - 18)); legs.addLine(to: CGPoint(x: bx - 14, y: by))
            legs.move(to: CGPoint(x: bx, y: by - 18)); legs.addLine(to: CGPoint(x: bx + 14, y: by))
            ctx.stroke(legs, with: .color(aiBatterColor), lineWidth: 3)
        }

        // Player pitcher (right side, faces left)
        let pBob = CGFloat(sin(t * 1.2)) * 1.0
        ctx.fill(Path(ellipseIn: CGRect(x: px - r, y: py - 40 - r + pBob, width: r*2, height: r*2)), with: .color(skin))
        var pBody = Path(); pBody.move(to: CGPoint(x: px, y: py - 40 + pBob)); pBody.addLine(to: CGPoint(x: px, y: py - 16))
        ctx.stroke(pBody, with: .color(playerPitcherColor), lineWidth: 3)
        var pArms = Path()
        pArms.move(to: CGPoint(x: px - 16, y: py - 30 + pBob)); pArms.addLine(to: CGPoint(x: px + 16, y: py - 30 + pBob))
        ctx.stroke(pArms, with: .color(playerPitcherColor), lineWidth: 2.5)
        ctx.fill(Path(ellipseIn: CGRect(x: px + 12, y: py - 34 + pBob, width: 7, height: 7)),
                 with: .color(Color(red: 0.93, green: 0.86, blue: 0.68)))
        var pLegs = Path()
        pLegs.move(to: CGPoint(x: px, y: py - 16)); pLegs.addLine(to: CGPoint(x: px - 12, y: py))
        pLegs.move(to: CGPoint(x: px, y: py - 16)); pLegs.addLine(to: CGPoint(x: px + 12, y: py))
        ctx.stroke(pLegs, with: .color(playerPitcherColor), lineWidth: 2.5)
    }

    // MARK: Pitch Ball

    private func drawPitchBall(ctx: inout GraphicsContext) {
        guard pitchProgress >= 0 else { return }
        let ep = CGFloat(pitchProgress)
        let sx = pitcherX + 14; let sy = moundY - 22
        let ex = batterX - 12; let ey = floorY - 30
        let curve = pitch.curveOffset * W
        let bx = sx + (ex - sx) * ep + curve * 4 * ep * (1 - ep)
        let by = sy + (ey - sy) * ep
        let ballR = 5 + ep * 3

        for g in 1...3 {
            let pep = max(0, ep - CGFloat(g) * 0.07)
            let gx = sx + (ex - sx) * pep + curve * 4 * pep * (1 - pep)
            let gy = sy + (ey - sy) * pep
            var gc = ctx; gc.opacity = Double(0.13 - CGFloat(g) * 0.03)
            gc.fill(Path(ellipseIn: CGRect(x: gx - ballR * 0.7, y: gy - ballR * 0.7, width: ballR * 1.4, height: ballR * 1.4)),
                    with: .color(.white))
        }
        var glow = ctx; glow.addFilter(.blur(radius: 7)); glow.opacity = 0.4
        glow.fill(Path(ellipseIn: CGRect(x: bx - 10, y: by - 10, width: 20, height: 20)), with: .color(.white))
        ctx.fill(
            Path(ellipseIn: CGRect(x: bx - ballR, y: by - ballR, width: ballR * 2, height: ballR * 2)),
            with: .radialGradient(Gradient(colors: [.white, Color(white: 0.82)]),
                                  center: CGPoint(x: bx, y: by), startRadius: 0, endRadius: ballR * 1.5)
        )
        var seam = Path()
        seam.addArc(center: CGPoint(x: bx, y: by), radius: ballR - 1,
                    startAngle: .degrees(20), endAngle: .degrees(75), clockwise: false)
        ctx.stroke(seam, with: .color(Color(red: 0.8, green: 0.1, blue: 0.1).opacity(0.65)), lineWidth: 1)
    }

    // MARK: Hit Ball Arc

    private func drawHitBall(ctx: inout GraphicsContext) {
        guard hitProgress >= 0 else { return }
        let ep = CGFloat(hitProgress)
        let sx = batterX - 24; let sy = floorY - 32
        let (ex, ey, peakH): (CGFloat, CGFloat, CGFloat) = hitType == "homeRun"
            ? (W * 0.05, H * 0.18, H * 0.58)
            : (W * 0.22, floorY - 15, H * 0.20)
        let bx = sx + (ex - sx) * ep
        let by = sy + (ey - sy) * ep - peakH * 4 * ep * (1 - ep)

        for g in 1...4 {
            let pep = max(0, ep - CGFloat(g) * 0.05)
            let gx = sx + (ex - sx) * pep
            let gy = sy + (ey - sy) * pep - peakH * 4 * pep * (1 - pep)
            var gc = ctx; gc.opacity = Double(0.10 - CGFloat(g) * 0.02)
            gc.fill(Path(ellipseIn: CGRect(x: gx - 6, y: gy - 6, width: 12, height: 12)), with: .color(.white))
        }
        if hitType == "homeRun" {
            var glow = ctx; glow.addFilter(.blur(radius: 16)); glow.opacity = Double(ep) * 0.55
            glow.fill(Path(ellipseIn: CGRect(x: bx - 22, y: by - 22, width: 44, height: 44)), with: .color(.orange))
        }
        ctx.fill(
            Path(ellipseIn: CGRect(x: bx - 7, y: by - 7, width: 14, height: 14)),
            with: .radialGradient(Gradient(colors: [.white, Color(white: 0.82)]),
                                  center: CGPoint(x: bx, y: by), startRadius: 0, endRadius: 9)
        )
    }

    // MARK: Hit Sparks

    private func drawHitSparks(ctx: inout GraphicsContext) {
        let frac = (t - lastHitTime) / 0.55
        let alpha = max(0, 1.0 - frac * 1.5)
        guard alpha > 0 else { return }
        let cx = batterX - 24; let cy = floorY - 32

        let ringR = CGFloat(frac) * 45
        var ring = Path()
        ring.addEllipse(in: CGRect(x: cx - ringR, y: cy - ringR, width: ringR * 2, height: ringR * 2))
        var rc = ctx; rc.opacity = alpha * 0.55
        rc.stroke(ring, with: .color(Color(red: 1, green: 0.88, blue: 0.15)), lineWidth: 2)

        for i in 0..<14 {
            let angle = Double(i) / 14.0 * .pi * 2
            let len = CGFloat(12 + i % 3 * 6) * (1.0 - CGFloat(frac) * 0.65)
            let sRadius = CGFloat(frac) * 18
            let spx = cx + CGFloat(cos(angle)) * sRadius
            let spy = cy + CGFloat(sin(angle)) * sRadius
            var spark = Path()
            spark.move(to: CGPoint(x: spx, y: spy))
            spark.addLine(to: CGPoint(x: spx + CGFloat(cos(angle)) * len, y: spy + CGFloat(sin(angle)) * len))
            let sc: Color = i % 3 == 0 ? .white : (i % 3 == 1 ? Color(red: 1, green: 0.86, blue: 0.1) : Color(red: 1, green: 0.5, blue: 0.1))
            var sc2 = ctx; sc2.opacity = alpha * (i % 2 == 0 ? 0.9 : 0.5)
            sc2.stroke(spark, with: .color(sc), lineWidth: 1.5)
        }
        let fr = CGFloat(9 * (1.0 - frac * 1.3))
        if fr > 0 {
            var fc = ctx; fc.opacity = alpha
            fc.fill(Path(ellipseIn: CGRect(x: cx - fr, y: cy - fr, width: fr * 2, height: fr * 2)), with: .color(.white))
        }
    }

    // MARK: Swing Zone Ring

    private func drawSwingZoneRing(ctx: inout GraphicsContext) {
        let ep = CGFloat(pitchProgress)
        let pulse = 0.45 + 0.28 * CGFloat(sin(t * 6.5))
        let cx = batterX - 12; let cy = floorY - 30
        var outer = Path()
        outer.addEllipse(in: CGRect(x: cx - 38, y: cy - 29, width: 76, height: 58))
        var oc = ctx; oc.opacity = Double(0.22 * pulse)
        oc.stroke(outer, with: .color(.yellow), lineWidth: 2)
        if ep >= 0.62 && ep <= 0.82 {
            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx - 23, y: cy - 17, width: 46, height: 34))
            var ic = ctx; ic.opacity = Double(0.50 * pulse)
            ic.stroke(inner, with: .color(.green), lineWidth: 2.5)
        }
    }
}

// MARK: - Main View

struct BaseballGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: BBallPhase = .ready
    @State private var inning: Int = 1
    @State private var isTopHalf: Bool = true
    @State private var playerScore: Int = 0
    @State private var aiScore: Int = 0
    @State private var outs: Int = 0
    @State private var currentPitch: PitchType = .fastball
    @State private var swingResult: SwingResult = .none
    @State private var showResultBanner: Bool = false
    @State private var rewardGranted: Bool = false

    // Canvas state
    @State private var pitchProgress: Double = -1.0
    @State private var batterPhase: String = "ready"
    @State private var pitcherPhase: String = "idle"
    @State private var hitProgress: Double = -1.0
    @State private var hitType: String = ""
    @State private var lastHitTime: Double = 0
    @State private var crowdLevel: Double = 0.30
    @State private var aiBatterPhase: String = "ready"

    // Control
    @State private var pitchTask: Task<Void, Never>? = nil
    @State private var playerSwung: Bool = false
    @State private var aiAtBatTask: Task<Void, Never>? = nil
    @State private var aiResultLabel: String = ""
    @State private var showAIResult: Bool = false
    @State private var screenShake: CGFloat = 0
    @State private var bannerScale: CGFloat = 0.6

    private var swingWindowOpen: Bool { pitchProgress >= 0.46 && pitchProgress < 1.0 }
    private let perfectZone: ClosedRange<Double> = 0.62...0.82
    private let goodZone: ClosedRange<Double> = 0.50...0.90

    var body: some View {
        ZStack {
            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Home Run Derby",
                    subtitle: "5 Innings · Swing for the fences",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { startInning() }
                )
                .background(Color(red: 0.03, green: 0.04, blue: 0.18).ignoresSafeArea())
            case .batting:  battingBody
            case .pitching: pitchingBody
            case .inningBreak: inningBreakBody
            case .result:   resultBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { pitchTask?.cancel(); aiAtBatTask?.cancel(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { pitchTask?.cancel(); aiAtBatTask?.cancel() }
    }

    // MARK: HUD

    private var scoreHUD: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("HOME · YOU").font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(gameMode.accentColor).tracking(1)
                Text("\(playerScore)").font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(.white).contentTransition(.numericText())
            }.frame(maxWidth: .infinity)
            VStack(spacing: 4) {
                Text("INN \(inning)/\(INNINGS)").font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5)).tracking(2)
                Text(isTopHalf ? "TOP" : "BTM").font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(isTopHalf ? gameMode.accentColor : .red)
                HStack(spacing: 5) {
                    ForEach(0..<OUTS_PER_INNING, id: \.self) { i in
                        Circle().fill(i < outs ? Color.red : Color.white.opacity(0.15)).frame(width: 10, height: 10)
                    }
                }.padding(.top, 2)
            }
            VStack(spacing: 2) {
                Text("AWAY · OPP").font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.8)).tracking(1)
                Text("\(aiScore)").font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5)).contentTransition(.numericText())
            }.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: Batting Body

    private var battingBody: some View {
        ZStack {
            StadiumCanvas(
                pitchProgress: pitchProgress, pitch: currentPitch,
                batterPhase: batterPhase, pitcherPhase: pitcherPhase,
                hitProgress: hitProgress, hitType: hitType,
                lastHitTime: lastHitTime, isAIBatting: false,
                crowdLevel: crowdLevel, aiBatterPhase: aiBatterPhase
            )
            .offset(x: screenShake > 0 ? CGFloat.random(in: -screenShake...screenShake) : 0)

            VStack(spacing: 0) {
                scoreHUD
                HStack(spacing: 6) {
                    Image(systemName: currentPitch.icon).font(.system(size: 11, weight: .bold))
                    Text(currentPitch.rawValue).font(.system(size: 10, weight: .black, design: .monospaced))
                    Text("·").foregroundStyle(.secondary)
                    Text(currentPitch.speedLabel).font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(gameMode.accentColor)
                .padding(.vertical, 6).padding(.horizontal, 14)
                .background(Color.black.opacity(0.55)).clipShape(.rect(cornerRadius: 10))
                .padding(.top, 6)
                Spacer()
                if showResultBanner {
                    resultBanner.scaleEffect(bannerScale).padding(.bottom, 90)
                }
                Spacer()
                if !playerSwung && pitchProgress >= 0 {
                    Text("TAP OR SWIPE TO SWING")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(swingWindowOpen ? 0.85 : 0.35)).tracking(2)
                        .shadow(color: swingWindowOpen ? .green.opacity(0.6) : .clear, radius: 8)
                        .padding(.bottom, 22)
                        .animation(.easeInOut(duration: 0.25), value: swingWindowOpen)
                } else if pitchProgress < 0 && !playerSwung {
                    Text("GET READY…").font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3)).tracking(2).padding(.bottom, 22)
                }
            }
        }
        .gesture(TapGesture().onEnded { _ in handleSwing() })
        .simultaneousGesture(DragGesture(minimumDistance: 18).onEnded { _ in handleSwing() })
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Pitching Body

    private var pitchingBody: some View {
        ZStack {
            StadiumCanvas(
                pitchProgress: -1, pitch: .fastball,
                batterPhase: "ready", pitcherPhase: "idle",
                hitProgress: -1, hitType: "",
                lastHitTime: 0, isAIBatting: true,
                crowdLevel: crowdLevel, aiBatterPhase: aiBatterPhase
            )
            VStack(spacing: 0) {
                scoreHUD
                Spacer()
                if showAIResult {
                    Text(aiResultLabel)
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(aiResultColor)
                        .shadow(color: aiResultColor.opacity(0.5), radius: 10)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color.black.opacity(0.55)).clipShape(.rect(cornerRadius: 14))
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                Text("AI BATTING").font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3)).tracking(3).padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var aiResultColor: Color {
        if aiResultLabel.contains("HOME RUN") { return .orange }
        if aiResultLabel.contains("HIT") { return .yellow }
        if aiResultLabel.contains("OUT") { return .green }
        return .secondary
    }

    // MARK: Inning Break

    private var inningBreakBody: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.18).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "baseball.fill").font(.system(size: 48)).foregroundStyle(gameMode.accentColor)
                Text(inning > INNINGS ? "FINAL" : "END OF INNING \(inning - 1)")
                    .font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(3)
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(playerScore)").font(.system(size: 40, weight: .black, design: .monospaced)).foregroundStyle(.white)
                        Text("YOU").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(gameMode.accentColor)
                    }
                    Text("–").font(.system(size: 28, weight: .bold)).foregroundStyle(.tertiary)
                    VStack(spacing: 4) {
                        Text("\(aiScore)").font(.system(size: 40, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                        Text("OPP").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                if inning <= INNINGS {
                    Button { startInning() } label: {
                        Text("INNING \(inning) →").font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.black).padding(.horizontal, 32).padding(.vertical, 14)
                            .background(gameMode.accentColor).clipShape(.rect(cornerRadius: 14))
                    }.padding(.top, 8)
                }
                Spacer()
            }
        }
    }

    // MARK: Result Banner

    private var resultBanner: some View {
        let (color, text): (Color, String) = {
            switch swingResult {
            case .homeRun:  return (.orange, "HOME RUN!")
            case .basehit:  return (.yellow, "BASE HIT")
            case .foul:     return (Color(white: 0.75), "FOUL BALL")
            case .miss:     return (.red, "STRIKE")
            case .none:     return (.clear, "")
            }
        }()
        return Text(text)
            .font(.system(size: 30, weight: .black, design: .monospaced))
            .foregroundStyle(color).shadow(color: color.opacity(0.6), radius: 14)
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.35), lineWidth: 1.5)))
    }

    // MARK: Result Body

    private var resultBody: some View {
        let winner: ResultScreen.ResultWinner = playerScore > aiScore ? .p1 : (playerScore < aiScore ? .p2 : .draw)
        let shardsEarned: Int = winner == .p1 ? 50 : (winner == .draw ? 25 : 15)
        return ResultScreen(
            winner: winner, p1Score: playerScore, p2Score: aiScore,
            title: "Home Run Derby", accentColor: gameMode.accentColor,
            prqGain: winner == .p1 ? 12 : 3,
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "BATTING",
            modeAttributeValue: playerScore > 0 ? min(1.0, Double(playerScore) / Double(playerScore + aiScore + 1)) : 0.1,
            onReturn: { dismiss() }
        )
        .onAppear { grantRewards(winner: winner, shards: shardsEarned) }
    }

    // MARK: Logic

    private func startInning() {
        outs = 0; isTopHalf = true; phase = .batting
        deliverPitch()
    }

    private func deliverPitch() {
        currentPitch = PitchType.allCases.randomElement() ?? .fastball
        pitchProgress = -1.0; hitProgress = -1.0; hitType = ""
        playerSwung = false; showResultBanner = false
        batterPhase = "ready"; pitcherPhase = "windup"; bannerScale = 0.6

        let stepNs: UInt64 = 16_000_000
        let pitchSteps = Int(currentPitch.duration * 1000 / 16)

        pitchTask?.cancel()
        pitchTask = Task {
            for _ in 0..<22 {
                try? await Task.sleep(nanoseconds: stepNs)
                guard !Task.isCancelled else { return }
            }
            await MainActor.run { pitcherPhase = "release"; pitchProgress = 0 }
            for step in 0..<pitchSteps {
                try? await Task.sleep(nanoseconds: stepNs)
                guard !Task.isCancelled else { return }
                let prog = Double(step + 1) / Double(pitchSteps)
                await MainActor.run {
                    pitchProgress = prog
                    if prog > 0.52 { pitcherPhase = "followthrough" }
                }
            }
            await MainActor.run {
                if !playerSwung { recordSwingResult(.miss) }
                pitchProgress = -1.0
            }
        }
    }

    private func handleSwing() {
        guard pitchProgress >= 0, !playerSwung else { return }
        playerSwung = true
        pitchTask?.cancel()
        let ep = pitchProgress
        let result: SwingResult
        if swingWindowOpen {
            if perfectZone.contains(ep) {
                result = Double.random(in: 0...1) < 0.35 ? .homeRun : .basehit
            } else if goodZone.contains(ep) {
                result = .basehit
            } else {
                result = .foul
            }
        } else {
            result = .foul
        }
        pitchProgress = -1.0
        recordSwingResult(result)
    }

    private func recordSwingResult(_ result: SwingResult) {
        swingResult = result
        showResultBanner = true
        withAnimation(.spring(response: 0.25)) { bannerScale = 1.0 }

        switch result {
        case .homeRun:
            batterPhase = "swing"; hitType = "homeRun"
            lastHitTime = Date().timeIntervalSinceReferenceDate
            playerScore += Int.random(in: 1...4)
            crowdLevel = min(1.0, crowdLevel + 0.45)
            triggerShake(intensity: 8)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            startHitBallAnim(steps: 65)
        case .basehit:
            batterPhase = "swing"; hitType = "basehit"
            lastHitTime = Date().timeIntervalSinceReferenceDate
            playerScore += 1
            crowdLevel = min(1.0, crowdLevel + 0.12)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            startHitBallAnim(steps: 38)
        case .foul:
            batterPhase = "swing"
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .miss:
            batterPhase = "miss"; outs += 1
            triggerShake(intensity: 3)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .none: break
        }

        let delay: Double = result == .homeRun ? 2.4 : 1.6
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run {
                bannerScale = 0.6; showResultBanner = false; swingResult = .none
                batterPhase = "ready"; pitcherPhase = "idle"; hitProgress = -1
                if outs >= OUTS_PER_INNING { endHalfInning() }
                else { deliverPitch() }
            }
        }
    }

    private func startHitBallAnim(steps: Int) {
        hitProgress = 0
        Task {
            for step in 0..<steps {
                try? await Task.sleep(nanoseconds: 18_000_000)
                await MainActor.run { hitProgress = Double(step + 1) / Double(steps) }
            }
            await MainActor.run { hitProgress = -1 }
        }
    }

    private func endHalfInning() {
        if isTopHalf {
            isTopHalf = false; outs = 0; phase = .pitching; runAIAtBat()
        } else {
            if inning >= INNINGS { phase = .result } else { inning += 1; phase = .inningBreak }
        }
    }

    private func runAIAtBat() {
        aiAtBatTask?.cancel()
        aiAtBatTask = Task {
            var aiOuts = 0
            while aiOuts < OUTS_PER_INNING {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(Double.random(in: 1.1...1.8)))
                guard !Task.isCancelled else { return }
                let roll = Double.random(in: 0...1)
                let label: String
                if roll < 0.08 {
                    label = "HOME RUN! 💥"
                    await MainActor.run { aiScore += Int.random(in: 1...2); aiBatterPhase = "swing" }
                } else if roll < 0.30 {
                    label = "BASE HIT"
                    await MainActor.run { aiScore += 1; aiBatterPhase = "swing" }
                } else if roll < 0.52 {
                    label = "FOUL BALL"
                    await MainActor.run { aiBatterPhase = "swing" }
                } else {
                    label = "OUT (\(aiOuts + 1)/3)"
                    aiOuts += 1
                    await MainActor.run { aiBatterPhase = "miss" }
                }
                await MainActor.run {
                    aiResultLabel = label
                    withAnimation(.spring(response: 0.25)) { showAIResult = true }
                }
                try? await Task.sleep(for: .seconds(1.1))
                await MainActor.run { withAnimation { showAIResult = false }; aiBatterPhase = "ready" }
            }
            await MainActor.run {
                if inning >= INNINGS { phase = .result } else { inning += 1; phase = .inningBreak }
            }
        }
    }

    private func triggerShake(intensity: CGFloat) {
        screenShake = intensity
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            await MainActor.run { screenShake = 0 }
        }
    }

    private func grantRewards(winner: ResultScreen.ResultWinner, shards: Int) {
        guard !rewardGranted else { return }
        rewardGranted = true
        viewModel.profile.evolutionShards += shards
        let xpGain = min(XP_CAP_PER_SESSION, shards * 2)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) / 100.0)
    }
}
