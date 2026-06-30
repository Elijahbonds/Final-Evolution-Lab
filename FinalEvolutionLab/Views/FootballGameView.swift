import SwiftUI

// MARK: - Enums

private enum FBPhase {
    case ready, catchRoute, run, touchdown, turnover, result
}

private enum RouteType: String, CaseIterable {
    case slant   = "SLANT"
    case corner  = "CORNER"
    case post    = "POST"
    case fly     = "FLY"
    case out     = "OUT"

    var yards: Int {
        switch self {
        case .slant:  return 5
        case .corner: return 9
        case .post:   return 12
        case .fly:    return 20
        case .out:    return 8
        }
    }

    var windowSeconds: Double {
        switch self {
        case .slant:  return 1.8
        case .corner: return 1.4
        case .post:   return 1.2
        case .fly:    return 1.6
        case .out:    return 1.5
        }
    }
}

private enum DodgeDirection { case left, right, none }

private let XP_CAP_PER_SESSION = 500
private let MAX_DOWNS = 4
private let YARDS_TO_GO_INITIAL = 10
private let TD_YARDS = 100

// MARK: - Football Field Canvas

private struct FootballFieldCanvas: View {
    let phase: FBPhase
    let receiverX: CGFloat
    let receiverY: CGFloat
    let playerPosition: CGFloat
    let defenderPosition: CGFloat
    let runMeter: Double
    let windowOpen: Bool
    let throwProgress: Double
    let throwTargetX: CGFloat
    let throwTargetY: CGFloat
    let qbPose: String
    let currentRoute: RouteType
    let tdFlash: Bool
    let yardsGained: Int
    let crowdExcitement: Double

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = FootballFieldDrawer(
                    size: size, t: t,
                    phase: phase,
                    receiverX: receiverX, receiverY: receiverY,
                    playerPosition: playerPosition, defenderPosition: defenderPosition,
                    runMeter: runMeter,
                    windowOpen: windowOpen,
                    throwProgress: throwProgress,
                    throwTargetX: throwTargetX, throwTargetY: throwTargetY,
                    qbPose: qbPose,
                    currentRoute: currentRoute,
                    tdFlash: tdFlash,
                    yardsGained: yardsGained,
                    crowdExcitement: crowdExcitement
                )
                d.render(ctx: &ctx)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Football Field Drawer

private struct FootballFieldDrawer {
    let size: CGSize
    let t: Double
    let phase: FBPhase
    let receiverX: CGFloat
    let receiverY: CGFloat
    let playerPosition: CGFloat
    let defenderPosition: CGFloat
    let runMeter: Double
    let windowOpen: Bool
    let throwProgress: Double
    let throwTargetX: CGFloat
    let throwTargetY: CGFloat
    let qbPose: String
    let currentRoute: RouteType
    let tdFlash: Bool
    let yardsGained: Int
    let crowdExcitement: Double

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var fieldLeft: CGFloat  { W * 0.06 }
    var fieldRight: CGFloat { W * 0.94 }
    var fieldWidth: CGFloat { fieldRight - fieldLeft }
    var endZoneTop: CGFloat { H * 0.08 }
    var endZoneBot: CGFloat { H * 0.20 }
    var fieldTop: CGFloat   { endZoneBot }
    var fieldBot: CGFloat   { H * 0.82 }
    var fieldHeight: CGFloat { fieldBot - fieldTop }

    func receiverCanvas() -> CGPoint {
        let cx = fieldLeft + receiverX * fieldWidth
        let cy = endZoneTop + receiverY * (fieldBot - endZoneTop)
        return CGPoint(x: cx, y: cy)
    }

    func qbPos() -> CGPoint {
        CGPoint(x: W * 0.5, y: fieldBot - 20)
    }

    func runnerCanvas() -> CGPoint {
        let cx = fieldLeft + playerPosition * fieldWidth
        let cy = fieldBot - CGFloat(runMeter) * (fieldBot - endZoneBot - 10)
        return CGPoint(x: cx, y: cy)
    }

    func defenderCanvas() -> CGPoint {
        let cx = fieldLeft + defenderPosition * fieldWidth
        let runnerY = fieldBot - CGFloat(runMeter) * (fieldBot - endZoneBot - 10)
        return CGPoint(x: cx, y: runnerY + 50)
    }

    mutating func render(ctx: inout GraphicsContext) {
        drawStadiumSky(ctx: &ctx)
        drawSidelines(ctx: &ctx)
        drawEndZone(ctx: &ctx)
        drawFieldTurf(ctx: &ctx)
        drawYardLines(ctx: &ctx)
        drawGoalPosts(ctx: &ctx)

        switch phase {
        case .catchRoute:
            drawRoutePath(ctx: &ctx)
            drawQB(ctx: &ctx)
            drawReceiver(ctx: &ctx)
            if throwProgress >= 0 { drawFootball(ctx: &ctx) }
        case .run:
            drawDefender(ctx: &ctx)
            drawRunner(ctx: &ctx)
        case .touchdown:
            drawTouchdownParticles(ctx: &ctx)
            drawTDRunner(ctx: &ctx)
        case .turnover:
            drawTurnoverRunner(ctx: &ctx)
        default:
            break
        }
    }

    // MARK: Stadium Sky

    private func drawStadiumSky(ctx: inout GraphicsContext) {
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.15), Color(red: 0.05, green: 0.08, blue: 0.02)]),
                startPoint: CGPoint(x: W * 0.5, y: 0),
                endPoint: CGPoint(x: W * 0.5, y: H)
            )
        )
        // Corner light blooms
        for cx in [W * 0.04, W * 0.96] {
            for cy in [H * 0.04, H * 0.88] {
                var gc = ctx; gc.addFilter(.blur(radius: 28)); gc.opacity = 0.25
                gc.fill(Path(ellipseIn: CGRect(x: cx - 50, y: cy - 40, width: 100, height: 80)), with: .color(.white))
            }
        }
        // Light poles at corners
        for (px, py) in [(W * 0.04, H * 0.04), (W * 0.96, H * 0.04), (W * 0.04, H * 0.88), (W * 0.96, H * 0.88)] {
            var pole = Path()
            pole.move(to: CGPoint(x: px, y: py + 30))
            pole.addLine(to: CGPoint(x: px, y: py))
            ctx.stroke(pole, with: .color(Color(white: 0.6)), lineWidth: 2)
            ctx.fill(Path(CGRect(x: px - 8, y: py - 4, width: 16, height: 4)), with: .color(Color(white: 0.85)))
        }
    }

    // MARK: Sidelines / Crowd

    private func drawSidelines(ctx: inout GraphicsContext) {
        let sideW: CGFloat = fieldLeft
        let jerseys: [Color] = [
            Color(red: 0.10, green: 0.35, blue: 0.75), Color(red: 0.75, green: 0.10, blue: 0.10),
            Color(red: 0.92, green: 0.82, blue: 0.15), Color(red: 0.82, green: 0.38, blue: 0.04),
            Color(white: 0.88)
        ]

        for side in [fieldLeft - sideW, fieldRight] {
            ctx.fill(
                Path(CGRect(x: side, y: fieldTop, width: sideW, height: fieldHeight)),
                with: .color(Color(white: 0.06))
            )
            let excited = crowdExcitement > 0.5
            let rows = 5; let figH = fieldHeight / CGFloat(rows)
            for row in 0..<rows {
                let ry = fieldTop + CGFloat(row) * figH + 4
                let count = Int(sideW / 10)
                for col in 0..<count {
                    let cx = (side < fieldLeft / 2) ? (side + CGFloat(col) * 10 + 5) : (side + CGFloat(col) * 10 + 5)
                    let jc = jerseys[(col * 3 + row * 7) % jerseys.count]
                    let skin = Color(red: 0.82 + 0.06 * CGFloat((col + row) % 3),
                                     green: 0.62 + 0.06 * CGFloat(col % 3), blue: 0.50)
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: ry, width: 6, height: 6)), with: .color(skin))
                    ctx.fill(Path(CGRect(x: cx - 3, y: ry + 6, width: 6, height: 5)), with: .color(jc.opacity(0.8)))
                    if excited {
                        let wave = CGFloat(sin(t * 3.5 + Double(col) * 0.7 + Double(row) * 1.2)) * 2
                        var arms = Path()
                        arms.move(to: CGPoint(x: cx - 3, y: ry + 8))
                        arms.addLine(to: CGPoint(x: cx - 7, y: ry + 3 + wave))
                        arms.move(to: CGPoint(x: cx + 3, y: ry + 8))
                        arms.addLine(to: CGPoint(x: cx + 7, y: ry + 3 + wave))
                        ctx.stroke(arms, with: .color(jc.opacity(0.65)), lineWidth: 1.2)
                    }
                }
            }
        }

        // Sideline white out-of-bounds lines
        ctx.fill(Path(CGRect(x: fieldLeft - 2, y: fieldTop, width: 2, height: fieldHeight)),
                 with: .color(.white.opacity(0.5)))
        ctx.fill(Path(CGRect(x: fieldRight, y: fieldTop, width: 2, height: fieldHeight)),
                 with: .color(.white.opacity(0.5)))
    }

    // MARK: End Zone

    private func drawEndZone(ctx: inout GraphicsContext) {
        ctx.fill(
            Path(CGRect(x: fieldLeft, y: endZoneTop, width: fieldWidth, height: endZoneBot - endZoneTop)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.10, green: 0.30, blue: 0.10), Color(red: 0.06, green: 0.24, blue: 0.06)]),
                startPoint: CGPoint(x: W * 0.5, y: endZoneTop),
                endPoint: CGPoint(x: W * 0.5, y: endZoneBot)
            )
        )
        // Diagonal stripes in end zone
        for i in 0..<8 {
            let ox = fieldLeft + CGFloat(i) * fieldWidth / 7
            var stripe = Path()
            stripe.move(to: CGPoint(x: ox, y: endZoneTop))
            stripe.addLine(to: CGPoint(x: ox + 20, y: endZoneBot))
            ctx.stroke(stripe, with: .color(.white.opacity(0.06)), lineWidth: 3)
        }
        // END ZONE text
        let ezText = ctx.resolve(Text("END ZONE")
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.35)))
        ctx.draw(ezText, at: CGPoint(x: W * 0.5, y: (endZoneTop + endZoneBot) / 2))

        // End zone boundary
        ctx.fill(Path(CGRect(x: fieldLeft, y: endZoneBot - 3, width: fieldWidth, height: 3)),
                 with: .color(.white.opacity(0.7)))
    }

    // MARK: Field Turf

    private func drawFieldTurf(ctx: inout GraphicsContext) {
        ctx.fill(
            Path(CGRect(x: fieldLeft, y: fieldTop, width: fieldWidth, height: fieldHeight)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.08, green: 0.28, blue: 0.08), Color(red: 0.06, green: 0.22, blue: 0.06)]),
                startPoint: CGPoint(x: W * 0.5, y: fieldTop),
                endPoint: CGPoint(x: W * 0.5, y: fieldBot)
            )
        )
        // Alternating grass stripes
        let stripes = 10
        for i in 0..<stripes {
            if i % 2 == 0 {
                let sy = fieldTop + CGFloat(i) * fieldHeight / CGFloat(stripes)
                let sh = fieldHeight / CGFloat(stripes)
                ctx.fill(Path(CGRect(x: fieldLeft, y: sy, width: fieldWidth, height: sh)),
                         with: .color(Color(white: 1).opacity(0.015)))
            }
        }
    }

    // MARK: Yard Lines

    private func drawYardLines(ctx: inout GraphicsContext) {
        let tenYardLines = 9  // 10, 20, 30, 40, 50, 40, 30, 20, 10 from end zone down
        let spacing = fieldHeight / CGFloat(tenYardLines + 1)
        let yardNumbers = [10, 20, 30, 40, 50, 40, 30, 20, 10]

        for i in 1...tenYardLines {
            let y = fieldTop + CGFloat(i) * spacing
            // Full yard line
            var line = Path()
            line.move(to: CGPoint(x: fieldLeft, y: y))
            line.addLine(to: CGPoint(x: fieldRight, y: y))
            ctx.stroke(line, with: .color(.white.opacity(0.30)), lineWidth: 1.5)

            // Yard number
            let numText = ctx.resolve(Text("\(yardNumbers[i - 1])")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35)))
            ctx.draw(numText, at: CGPoint(x: fieldLeft + 14, y: y))
            ctx.draw(numText, at: CGPoint(x: fieldRight - 14, y: y))

            // Hash marks
            let hashW: CGFloat = 12
            let hashSpacing = fieldWidth * 0.35
            var hash = Path()
            hash.move(to: CGPoint(x: W * 0.5 - hashSpacing - hashW, y: y))
            hash.addLine(to: CGPoint(x: W * 0.5 - hashSpacing, y: y))
            hash.move(to: CGPoint(x: W * 0.5 + hashSpacing, y: y))
            hash.addLine(to: CGPoint(x: W * 0.5 + hashSpacing + hashW, y: y))
            ctx.stroke(hash, with: .color(.white.opacity(0.25)), lineWidth: 1)

            // 5-yard dashes
            if i < tenYardLines {
                let midY = y + spacing * 0.5
                var mid = Path()
                mid.move(to: CGPoint(x: fieldLeft, y: midY))
                mid.addLine(to: CGPoint(x: fieldLeft + 8, y: midY))
                mid.move(to: CGPoint(x: fieldRight - 8, y: midY))
                mid.addLine(to: CGPoint(x: fieldRight, y: midY))
                ctx.stroke(mid, with: .color(.white.opacity(0.15)), lineWidth: 1)
            }
        }

        // Line of scrimmage glow
        let losYCanvas = fieldBot - 20
        var los = Path()
        los.move(to: CGPoint(x: fieldLeft, y: losYCanvas))
        los.addLine(to: CGPoint(x: fieldRight, y: losYCanvas))
        var losCtx = ctx; losCtx.addFilter(.blur(radius: 4)); losCtx.opacity = 0.55
        losCtx.stroke(los, with: .color(Color(red: 0.8, green: 0.8, blue: 0.0)), lineWidth: 3)
        ctx.stroke(los, with: .color(Color(red: 0.9, green: 0.9, blue: 0.0).opacity(0.7)), lineWidth: 1)
    }

    // MARK: Goal Posts

    private func drawGoalPosts(ctx: inout GraphicsContext) {
        let cx = W * 0.5
        let base = endZoneTop + 4
        let poleH: CGFloat = 18
        let crossH: CGFloat = 8
        let postW: CGFloat = 30
        // Upright pole
        var pole = Path()
        pole.move(to: CGPoint(x: cx, y: base + poleH + crossH))
        pole.addLine(to: CGPoint(x: cx, y: base))
        ctx.stroke(pole, with: .color(.yellow.opacity(0.85)), lineWidth: 3)
        // Cross bar
        var cross = Path()
        cross.move(to: CGPoint(x: cx, y: base + poleH))
        cross.addLine(to: CGPoint(x: cx, y: base + poleH))
        ctx.stroke(cross, with: .color(.yellow.opacity(0.85)), lineWidth: 2)
        // Two uprights
        var uprights = Path()
        uprights.move(to: CGPoint(x: cx - postW, y: base + poleH))
        uprights.addLine(to: CGPoint(x: cx - postW, y: base))
        uprights.move(to: CGPoint(x: cx + postW, y: base + poleH))
        uprights.addLine(to: CGPoint(x: cx + postW, y: base))
        ctx.stroke(uprights, with: .color(.yellow.opacity(0.85)), lineWidth: 2)
        // Cross bar connecting uprights
        var crossBar = Path()
        crossBar.move(to: CGPoint(x: cx - postW, y: base + poleH))
        crossBar.addLine(to: CGPoint(x: cx + postW, y: base + poleH))
        ctx.stroke(crossBar, with: .color(.yellow.opacity(0.85)), lineWidth: 2)
        // Glow
        var glow = ctx; glow.addFilter(.blur(radius: 6)); glow.opacity = 0.30
        glow.stroke(crossBar, with: .color(.yellow), lineWidth: 6)
    }

    // MARK: Route Path

    private func drawRoutePath(ctx: inout GraphicsContext) {
        let start = qbPos()
        let routeEnd = receiverCanvas()

        // Trail (dashed)
        var path = Path()
        path.move(to: start)
        let steps = 20
        for i in 1...steps {
            let ep = CGFloat(i) / CGFloat(steps)
            let px = start.x + (routeEnd.x - start.x) * ep
            let py = start.y + (routeEnd.y - start.y) * ep
            if i % 2 == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(Color(red: 0.2, green: 0.8, blue: 1.0).opacity(0.25)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Window indicator circle at route end
        if windowOpen {
            let pulse = 0.6 + 0.3 * CGFloat(sin(t * 8.0))
            var winCirc = Path()
            winCirc.addEllipse(in: CGRect(x: routeEnd.x - 22, y: routeEnd.y - 22, width: 44, height: 44))
            var wc = ctx; wc.opacity = Double(pulse)
            wc.stroke(winCirc, with: .color(.green), lineWidth: 2.5)
            // Inner pulse
            var inner = Path()
            inner.addEllipse(in: CGRect(x: routeEnd.x - 14, y: routeEnd.y - 14, width: 28, height: 28))
            var ic = ctx; ic.opacity = Double(pulse * 0.5)
            ic.stroke(inner, with: .color(.green), lineWidth: 2)
        }
    }

    // MARK: QB

    private func drawQB(ctx: inout GraphicsContext) {
        let p = qbPos()
        let x = p.x; let y = p.y
        let color = Color(red: 0.20, green: 0.65, blue: 0.20)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let helmetColor = Color(red: 0.12, green: 0.45, blue: 0.12)
        let r: CGFloat = 8

        switch qbPose {
        case "windup":
            // Weight shifted back, ball raised
            ctx.fill(Path(ellipseIn: CGRect(x: x - r - 2, y: y - 38 - r, width: r*2, height: r*2)), with: .color(skin))
            // Helmet
            var helm = Path()
            helm.addArc(center: CGPoint(x: x - 2, y: y - 38), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            helm.addLine(to: CGPoint(x: x - 2 - r - 4, y: y - 38))
            ctx.fill(helm, with: .color(helmetColor))
            var body = Path(); body.move(to: CGPoint(x: x - 2, y: y - 38)); body.addLine(to: CGPoint(x: x + 3, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            // Arm cocked back with ball
            var arm = Path(); arm.move(to: CGPoint(x: x, y: y - 28)); arm.addLine(to: CGPoint(x: x + 20, y: y - 40))
            ctx.stroke(arm, with: .color(color), lineWidth: 3)
            // Football in hand
            drawFootballAt(ctx: &ctx, x: x + 22, y: y - 43, angle: 0.8, r: 5)
            var legs = Path()
            legs.move(to: CGPoint(x: x + 3, y: y - 14)); legs.addLine(to: CGPoint(x: x + 14, y: y))
            legs.move(to: CGPoint(x: x + 3, y: y - 14)); legs.addLine(to: CGPoint(x: x - 10, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        case "throw":
            // Arm fully extended forward
            ctx.fill(Path(ellipseIn: CGRect(x: x - r + 4, y: y - 40 - r, width: r*2, height: r*2)), with: .color(skin))
            var helm = Path()
            helm.addArc(center: CGPoint(x: x + 4, y: y - 40), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            helm.addLine(to: CGPoint(x: x + 4 - r - 4, y: y - 40))
            ctx.fill(helm, with: .color(helmetColor))
            var body = Path(); body.move(to: CGPoint(x: x + 4, y: y - 40)); body.addLine(to: CGPoint(x: x - 3, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            var throwArm = Path(); throwArm.move(to: CGPoint(x: x + 1, y: y - 30)); throwArm.addLine(to: CGPoint(x: x - 20, y: y - 40))
            ctx.stroke(throwArm, with: .color(color), lineWidth: 3)
            var legs = Path()
            legs.move(to: CGPoint(x: x - 3, y: y - 14)); legs.addLine(to: CGPoint(x: x + 16, y: y))
            legs.move(to: CGPoint(x: x - 3, y: y - 14)); legs.addLine(to: CGPoint(x: x - 14, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        default: // idle
            let bob = CGFloat(sin(t * 1.5)) * 1.0
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - 38 - r + bob, width: r*2, height: r*2)), with: .color(skin))
            var helm = Path()
            helm.addArc(center: CGPoint(x: x, y: y - 38 + bob), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            helm.addLine(to: CGPoint(x: x - r - 4, y: y - 38 + bob))
            ctx.fill(helm, with: .color(helmetColor))
            var body = Path(); body.move(to: CGPoint(x: x, y: y - 38 + bob)); body.addLine(to: CGPoint(x: x, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            var arms = Path(); arms.move(to: CGPoint(x: x - 14, y: y - 28 + bob)); arms.addLine(to: CGPoint(x: x + 14, y: y - 28 + bob))
            ctx.stroke(arms, with: .color(color), lineWidth: 3)
            // Hold ball low
            drawFootballAt(ctx: &ctx, x: x + 4, y: y - 22, angle: 0.3, r: 5)
            var legs = Path()
            legs.move(to: CGPoint(x: x, y: y - 14)); legs.addLine(to: CGPoint(x: x - 12, y: y))
            legs.move(to: CGPoint(x: x, y: y - 14)); legs.addLine(to: CGPoint(x: x + 12, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)
        }
    }

    // MARK: Receiver

    private func drawReceiver(ctx: inout GraphicsContext) {
        let p = receiverCanvas()
        let x = p.x; let y = p.y
        let color = Color(red: 0.14, green: 0.32, blue: 0.72)
        let helmetColor = Color(red: 0.10, green: 0.24, blue: 0.58)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 7.5
        let stride = CGFloat(sin(t * 8.0)) * 8

        // Running animation
        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - 38 - r, width: r*2, height: r*2)), with: .color(skin))
        var helm = Path()
        helm.addArc(center: CGPoint(x: x, y: y - 38), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        helm.addLine(to: CGPoint(x: x - r - 3, y: y - 38))
        ctx.fill(helm, with: .color(helmetColor))

        var body = Path(); body.move(to: CGPoint(x: x, y: y - 38)); body.addLine(to: CGPoint(x: x, y: y - 14))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)

        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 29)); arms.addLine(to: CGPoint(x: x - 14, y: y - 22 - stride * 0.4))
        arms.move(to: CGPoint(x: x, y: y - 29)); arms.addLine(to: CGPoint(x: x + 14, y: y - 22 + stride * 0.4))
        ctx.stroke(arms, with: .color(color), lineWidth: 2.5)

        var legs = Path()
        legs.move(to: CGPoint(x: x, y: y - 14)); legs.addLine(to: CGPoint(x: x - 10, y: y + stride))
        legs.move(to: CGPoint(x: x, y: y - 14)); legs.addLine(to: CGPoint(x: x + 10, y: y - stride))
        ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        // Jersey number "88"
        let numText = ctx.resolve(Text("88")
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.8)))
        ctx.draw(numText, at: CGPoint(x: x, y: y - 24))

        // Ground shadow
        ctx.fill(Path(ellipseIn: CGRect(x: x - 12, y: y, width: 24, height: 5)), with: .color(.black.opacity(0.30)))
    }

    // MARK: Thrown Football

    private func drawFootball(ctx: inout GraphicsContext) {
        guard throwProgress >= 0 else { return }
        let ep = CGFloat(throwProgress)
        let start = qbPos()
        let endX = fieldLeft + throwTargetX * fieldWidth
        let endY = endZoneTop + throwTargetY * (fieldBot - endZoneTop)
        let dist = sqrt(pow(endX - start.x, 2) + pow(endY - start.y, 2))
        let peakH = min(dist * 0.40, H * 0.18)

        let bx = start.x + (endX - start.x) * ep
        let by = start.y + (endY - start.y) * ep - peakH * 4 * ep * (1 - ep)
        let angle = atan2(endY - start.y, endX - start.x) + (1 - ep) * (-0.5)

        // Trail
        for g in 1...3 {
            let pep = max(0, ep - CGFloat(g) * 0.06)
            let gx = start.x + (endX - start.x) * pep
            let gy = start.y + (endY - start.y) * pep - peakH * 4 * pep * (1 - pep)
            var gc = ctx; gc.opacity = Double(0.12 - CGFloat(g) * 0.03)
            gc.fill(Path(ellipseIn: CGRect(x: gx - 5, y: gy - 3, width: 10, height: 6)), with: .color(.white))
        }
        // Glow
        var glow = ctx; glow.addFilter(.blur(radius: 6)); glow.opacity = 0.35
        glow.fill(Path(ellipseIn: CGRect(x: bx - 8, y: by - 8, width: 16, height: 16)), with: .color(.white))
        // Football shape (rotating)
        drawFootballAt(ctx: &ctx, x: bx, y: by, angle: angle, r: 7)
    }

    private func drawFootballAt(ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, angle: CGFloat, r: CGFloat) {
        let rW = r * 1.7; let rH = r
        var gc = ctx
        gc.translateBy(x: x, y: y)
        gc.rotate(by: .radians(Double(angle)))
        gc.fill(Path(ellipseIn: CGRect(x: -rW, y: -rH, width: rW * 2, height: rH * 2)),
                with: .color(Color(red: 0.55, green: 0.30, blue: 0.08)))
        // Laces
        var lace = Path()
        lace.move(to: CGPoint(x: -3, y: -rH + 2))
        lace.addLine(to: CGPoint(x: 3, y: -rH + 2))
        gc.stroke(lace, with: .color(.white.opacity(0.7)), lineWidth: 1.5)
    }

    // MARK: Runner

    private func drawRunner(ctx: inout GraphicsContext) {
        let p = runnerCanvas()
        let x = p.x; let y = p.y
        let color = Color(red: 0.20, green: 0.65, blue: 0.20)
        let helmetColor = Color(red: 0.12, green: 0.45, blue: 0.12)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 8
        let stride = CGFloat(sin(t * 9.0)) * 9

        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - 40 - r, width: r*2, height: r*2)), with: .color(skin))
        var helm = Path()
        helm.addArc(center: CGPoint(x: x, y: y - 40), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        helm.addLine(to: CGPoint(x: x - r - 3, y: y - 40))
        ctx.fill(helm, with: .color(helmetColor))

        var body = Path(); body.move(to: CGPoint(x: x, y: y - 40)); body.addLine(to: CGPoint(x: x, y: y - 16))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)

        // Ball tucked under arm
        drawFootballAt(ctx: &ctx, x: x + 10, y: y - 26, angle: 0.2, r: 5)

        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 30)); arms.addLine(to: CGPoint(x: x - 16, y: y - 22 + stride * 0.5))
        ctx.stroke(arms, with: .color(color), lineWidth: 2.5)

        var legs = Path()
        legs.move(to: CGPoint(x: x, y: y - 16)); legs.addLine(to: CGPoint(x: x - 12, y: y + stride))
        legs.move(to: CGPoint(x: x, y: y - 16)); legs.addLine(to: CGPoint(x: x + 12, y: y - stride))
        ctx.stroke(legs, with: .color(color), lineWidth: 3)

        let numText = ctx.resolve(Text("21")
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.8)))
        ctx.draw(numText, at: CGPoint(x: x, y: y - 28))

        ctx.fill(Path(ellipseIn: CGRect(x: x - 14, y: y, width: 28, height: 5)), with: .color(.black.opacity(0.30)))
    }

    // MARK: Defender

    private func drawDefender(ctx: inout GraphicsContext) {
        let p = defenderCanvas()
        let x = p.x; let y = p.y
        let color = Color(red: 0.75, green: 0.12, blue: 0.12)
        let helmetColor = Color(red: 0.58, green: 0.08, blue: 0.08)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 7.5
        let stride = CGFloat(sin(t * 9.0 + 1.0)) * 8

        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - 38 - r, width: r*2, height: r*2)), with: .color(skin))
        var helm = Path()
        helm.addArc(center: CGPoint(x: x, y: y - 38), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        helm.addLine(to: CGPoint(x: x - r - 3, y: y - 38))
        ctx.fill(helm, with: .color(helmetColor))

        var body = Path(); body.move(to: CGPoint(x: x, y: y - 38)); body.addLine(to: CGPoint(x: x, y: y - 14))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)

        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 28)); arms.addLine(to: CGPoint(x: x - 16, y: y - 20 - stride * 0.4))
        arms.move(to: CGPoint(x: x, y: y - 28)); arms.addLine(to: CGPoint(x: x + 16, y: y - 20 + stride * 0.4))
        ctx.stroke(arms, with: .color(color), lineWidth: 2.5)

        var legs = Path()
        legs.move(to: CGPoint(x: x, y: y - 14)); legs.addLine(to: CGPoint(x: x - 11, y: y + stride))
        legs.move(to: CGPoint(x: x, y: y - 14)); legs.addLine(to: CGPoint(x: x + 11, y: y - stride))
        ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        ctx.fill(Path(ellipseIn: CGRect(x: x - 12, y: y, width: 24, height: 5)), with: .color(.black.opacity(0.25)))
    }

    // MARK: Touchdown Celebration

    private func drawTouchdownParticles(ctx: inout GraphicsContext) {
        guard tdFlash else { return }
        let particleCount = 60
        let seed: Double = floor(t * 0.5)
        for i in 0..<particleCount {
            let angle = Double(i) / Double(particleCount) * .pi * 2 + seed * 0.3
            let speed = Double(i % 5 + 3) * 28.0
            let age = fmod(t + Double(i) * 0.08, 2.0)
            let dist = CGFloat(age * speed)
            let px = W * 0.5 + CGFloat(cos(angle)) * dist
            let py = H * 0.4 + CGFloat(sin(angle)) * dist - CGFloat(age * age * 40)
            let particleAlpha = max(0, 1.0 - age * 0.7)
            let colors: [Color] = [.yellow, .orange, .white, Color(red: 0.2, green: 0.8, blue: 1), .green]
            let c = colors[i % colors.count]
            let pR: CGFloat = 4 + CGFloat(i % 4) * 2
            var pc = ctx; pc.opacity = particleAlpha
            pc.fill(Path(ellipseIn: CGRect(x: px - pR, y: py - pR, width: pR * 2, height: pR * 2)), with: .color(c))
        }

        // TD glow burst
        var burst = ctx; burst.addFilter(.blur(radius: 30)); burst.opacity = 0.5
        burst.fill(Path(ellipseIn: CGRect(x: W * 0.2, y: H * 0.2, width: W * 0.6, height: H * 0.4)), with: .color(.yellow))
    }

    private func drawTDRunner(ctx: inout GraphicsContext) {
        // Player celebrating in end zone
        let x = W * 0.5; let y = endZoneBot - 30
        let color = Color(red: 0.20, green: 0.65, blue: 0.20)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 8
        let jump = CGFloat(max(0, sin(t * 5.0))) * 14

        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - 50 - r - jump, width: r*2, height: r*2)), with: .color(skin))
        var body = Path(); body.move(to: CGPoint(x: x, y: y - 50 - jump)); body.addLine(to: CGPoint(x: x, y: y - 22 - jump))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)
        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 40 - jump)); arms.addLine(to: CGPoint(x: x - 26, y: y - 56 - jump))
        arms.move(to: CGPoint(x: x, y: y - 40 - jump)); arms.addLine(to: CGPoint(x: x + 26, y: y - 56 - jump))
        ctx.stroke(arms, with: .color(color), lineWidth: 3)
        var legs = Path()
        legs.move(to: CGPoint(x: x, y: y - 22 - jump)); legs.addLine(to: CGPoint(x: x - 12, y: y - jump))
        legs.move(to: CGPoint(x: x, y: y - 22 - jump)); legs.addLine(to: CGPoint(x: x + 12, y: y - jump))
        ctx.stroke(legs, with: .color(color), lineWidth: 3)
    }

    private func drawTurnoverRunner(ctx: inout GraphicsContext) {
        let x = W * 0.5; let y = fieldBot - 60
        let color = Color(red: 0.20, green: 0.65, blue: 0.20)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 8
        // Head down, slumped
        ctx.fill(Path(ellipseIn: CGRect(x: x - r - 4, y: y - 34 - r, width: r*2, height: r*2)), with: .color(skin))
        var body = Path(); body.move(to: CGPoint(x: x - 4, y: y - 34)); body.addLine(to: CGPoint(x: x + 4, y: y - 14))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)
        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 26)); arms.addLine(to: CGPoint(x: x - 16, y: y - 16))
        arms.move(to: CGPoint(x: x, y: y - 26)); arms.addLine(to: CGPoint(x: x + 16, y: y - 16))
        ctx.stroke(arms, with: .color(color), lineWidth: 2.5)
        var legs = Path()
        legs.move(to: CGPoint(x: x + 4, y: y - 14)); legs.addLine(to: CGPoint(x: x - 8, y: y))
        legs.move(to: CGPoint(x: x + 4, y: y - 14)); legs.addLine(to: CGPoint(x: x + 16, y: y))
        ctx.stroke(legs, with: .color(color), lineWidth: 2.5)
    }
}

// MARK: - Main View

struct FootballGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // Game state
    @State private var phase: FBPhase = .ready
    @State private var down: Int = 1
    @State private var yardsToGo: Int = YARDS_TO_GO_INITIAL
    @State private var yardLine: Int = 25
    @State private var playClock: Int = 40
    @State private var rewardGranted: Bool = false

    // Catch phase
    @State private var currentRoute: RouteType = .slant
    @State private var receiverX: CGFloat = 0.5
    @State private var receiverY: CGFloat = 0.5
    @State private var routeProgress: CGFloat = 0.0
    @State private var routeTask: Task<Void, Never>? = nil
    @State private var windowOpen: Bool = false
    @State private var playerThrew: Bool = false
    @State private var catchResult: Bool = false

    // Run phase
    @State private var runMeter: Double = 0.0
    @State private var defenderPosition: CGFloat = 0.3
    @State private var playerPosition: CGFloat = 0.5
    @State private var runTask: Task<Void, Never>? = nil
    @State private var yardsGained: Int = 0
    @State private var dodgeLabel: String = ""
    @State private var showDodgeLabel: Bool = false
    @State private var jukeCount: Int = 0

    // Clock
    @State private var clockTask: Task<Void, Never>? = nil

    // Canvas state (new)
    @State private var throwProgress: Double = -1.0
    @State private var throwTargetX: CGFloat = 0.5
    @State private var throwTargetY: CGFloat = 0.5
    @State private var qbPose: String = "idle"
    @State private var crowdExcitement: Double = 0.2

    // Effects
    @State private var tdFlash: Bool = false
    @State private var tdScale: CGFloat = 0.5
    @State private var screenShake: CGFloat = 0
    @State private var showPlayResult: Bool = false
    @State private var playResultLabel: String = ""
    @State private var playResultColor: Color = .white

    var body: some View {
        ZStack {
            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Kick Return",
                    subtitle: "4 Downs · Reach the end zone",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { startDrive() }
                )
                .background(Color(red: 0.03, green: 0.05, blue: 0.02).ignoresSafeArea())
            case .catchRoute:
                catchBody
            case .run:
                runBody
            case .touchdown:
                touchdownBody
            case .turnover:
                turnoverBody
            case .result:
                resultBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { cancelAllTasks(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { cancelAllTasks() }
    }

    // MARK: HUD

    private var hudBar: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(downLabel).font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(.white)
                Text(distanceLabel).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(gameMode.accentColor)
            }.frame(maxWidth: .infinity)
            VStack(spacing: 2) {
                Text("OWN \(yardLine)").font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white).contentTransition(.numericText())
                Text("YARD LINE").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
            }.frame(maxWidth: .infinity)
            VStack(spacing: 2) {
                Text("\(playClock)").font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(playClock <= 10 ? .red : .white).contentTransition(.numericText())
                Text("CLOCK").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
            }.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var downLabel: String {
        switch down { case 1: return "1ST"; case 2: return "2ND"; case 3: return "3RD"; case 4: return "4TH"; default: return "\(down)TH" }
    }
    private var distanceLabel: String { yardLine >= 90 ? "& GOAL" : "& \(yardsToGo)" }

    // MARK: Catch Body

    private var catchBody: some View {
        ZStack {
            FootballFieldCanvas(
                phase: phase,
                receiverX: receiverX, receiverY: receiverY,
                playerPosition: playerPosition, defenderPosition: defenderPosition,
                runMeter: runMeter,
                windowOpen: windowOpen,
                throwProgress: throwProgress,
                throwTargetX: throwTargetX, throwTargetY: throwTargetY,
                qbPose: qbPose,
                currentRoute: currentRoute,
                tdFlash: tdFlash,
                yardsGained: yardsGained,
                crowdExcitement: crowdExcitement
            )
            .offset(x: screenShake > 0 ? CGFloat.random(in: -screenShake...screenShake) : 0)

            VStack(spacing: 0) {
                hudBar
                Spacer()
                if showPlayResult {
                    Text(playResultLabel)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(playResultColor)
                        .shadow(color: playResultColor.opacity(0.4), radius: 10)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(playResultColor.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(playResultColor.opacity(0.3), lineWidth: 1)))
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                VStack(spacing: 6) {
                    Text("ROUTE: \(currentRoute.rawValue)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(gameMode.accentColor).tracking(2)
                    Text(windowOpen ? "TAP TO THROW!" : (playerThrew ? "" : "WATCH THE ROUTE…"))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(windowOpen ? .green : .white.opacity(0.4))
                }.padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleThrow() }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Run Body

    private var runBody: some View {
        ZStack {
            FootballFieldCanvas(
                phase: phase,
                receiverX: receiverX, receiverY: receiverY,
                playerPosition: playerPosition, defenderPosition: defenderPosition,
                runMeter: runMeter,
                windowOpen: false,
                throwProgress: -1,
                throwTargetX: 0.5, throwTargetY: 0.5,
                qbPose: "idle",
                currentRoute: currentRoute,
                tdFlash: false,
                yardsGained: yardsGained,
                crowdExcitement: crowdExcitement
            )
            .offset(x: screenShake > 0 ? CGFloat.random(in: -screenShake...screenShake) : 0)

            VStack(spacing: 0) {
                hudBar
                Spacer()
                if showDodgeLabel {
                    Text(dodgeLabel)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                }
                if showPlayResult {
                    Text(playResultLabel)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(playResultColor)
                        .shadow(color: playResultColor.opacity(0.4), radius: 10)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(playResultColor.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(playResultColor.opacity(0.3), lineWidth: 1)))
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                progressBar
                VStack(spacing: 6) {
                    Text("SWIPE LEFT/RIGHT TO JUKE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35)).tracking(2)
                    Text("TAP TO SPRINT")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25)).tracking(2)
                }.padding(.bottom, 30)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 25).onEnded { val in
            if val.translation.width < -30 { handleDodge(.left) }
            else if val.translation.width > 30 { handleDodge(.right) }
        })
        .onTapGesture { advanceRun(yards: 1) }
        .ignoresSafeArea(edges: .bottom)
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            Text("\(yardsGained) YDS GAINED")
                .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)).frame(height: 12)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 1), Color(red: 0.2, green: 0.65, blue: 0.2)],
                                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * CGFloat(runMeter)), height: 12)
                        .animation(.spring(response: 0.3), value: runMeter)
                }
                .frame(height: 12)
            }.padding(.horizontal, 20)
            Text(yardsToGo > 0 ? "NEED \(yardsToGo) MORE YDS" : "FIRST DOWN!")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(yardsToGo <= 0 ? .green : .secondary)
        }.padding(.bottom, 14)
    }

    // MARK: Touchdown Body

    private var touchdownBody: some View {
        ZStack {
            FootballFieldCanvas(
                phase: .touchdown,
                receiverX: 0.5, receiverY: 0.15,
                playerPosition: 0.5, defenderPosition: 0.5,
                runMeter: 1.0,
                windowOpen: false,
                throwProgress: -1,
                throwTargetX: 0.5, throwTargetY: 0.5,
                qbPose: "idle",
                currentRoute: .fly,
                tdFlash: tdFlash,
                yardsGained: yardsGained,
                crowdExcitement: 1.0
            )
            VStack(spacing: 24) {
                Spacer()
                if tdFlash {
                    Text("TOUCHDOWN!")
                        .font(.system(size: 44, weight: .black)).italic().tracking(4)
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .yellow.opacity(0.7), radius: 24)
                        .scaleEffect(tdScale)
                    HStack(spacing: 8) {
                        Image(systemName: "football.fill").foregroundStyle(.orange)
                        Text("6 POINTS").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(.white)
                    }
                }
                Spacer()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Turnover Body

    private var turnoverBody: some View {
        ZStack {
            FootballFieldCanvas(
                phase: .turnover,
                receiverX: 0.5, receiverY: 0.75,
                playerPosition: 0.5, defenderPosition: 0.5,
                runMeter: runMeter,
                windowOpen: false,
                throwProgress: -1,
                throwTargetX: 0.5, throwTargetY: 0.5,
                qbPose: "idle",
                currentRoute: currentRoute,
                tdFlash: false,
                yardsGained: yardsGained,
                crowdExcitement: 0.1
            )
            VStack(spacing: 24) {
                Spacer()
                Text("TURNOVER ON DOWNS")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.red).tracking(2)
                    .shadow(color: .red.opacity(0.4), radius: 10)
                Text("Stopped on \(downLabel) down")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Result Body

    private var resultBody: some View {
        let didScore = yardLine >= 100
        let winner: ResultScreen.ResultWinner = didScore ? .p1 : .p2
        let shards: Int = winner == .p1 ? 50 : 15
        return ResultScreen(
            winner: winner, p1Score: didScore ? 6 : 0, p2Score: didScore ? 0 : 7,
            title: "Kick Return", accentColor: gameMode.accentColor,
            prqGain: winner == .p1 ? 14 : 3,
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "YARDS",
            modeAttributeValue: min(1.0, Double(yardLine) / 100.0),
            onReturn: { dismiss() }
        )
        .onAppear { grantRewards(shards: shards) }
    }

    // MARK: Logic

    private func startDrive() {
        down = 1; yardsToGo = YARDS_TO_GO_INITIAL; yardLine = 25; playClock = 40
        phase = .catchRoute; setupCatchPhase(); startClock()
    }

    private func setupCatchPhase() {
        currentRoute = RouteType.allCases.randomElement() ?? .slant
        receiverX = 0.5; receiverY = 0.75; routeProgress = 0.0
        windowOpen = false; playerThrew = false; showPlayResult = false
        throwProgress = -1; qbPose = "idle"
        startRoute()
    }

    private func startRoute() {
        routeTask?.cancel()
        routeTask = Task {
            let totalSteps = 60
            let windowStart = Int(Double(totalSteps) * 0.50)
            let windowEnd   = Int(Double(totalSteps) * 0.75)
            let endPoint = routeEndPoint(for: currentRoute)

            // QB windup before route completion
            await MainActor.run { qbPose = "idle" }

            for step in 0...totalSteps {
                guard !Task.isCancelled else { return }
                let ep = CGFloat(step) / CGFloat(totalSteps)
                let nx = 0.5 + (endPoint.0 - 0.5) * ep
                let ny = 0.75 + (endPoint.1 - 0.75) * ep
                let isWindow = (step >= windowStart && step <= windowEnd)
                await MainActor.run {
                    receiverX = nx; receiverY = ny; routeProgress = ep
                    windowOpen = isWindow
                    if isWindow && !playerThrew { qbPose = "windup" }
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
            await MainActor.run {
                if !playerThrew { handleIncompletionOrSack() }
            }
        }
    }

    private func routeEndPoint(for route: RouteType) -> (CGFloat, CGFloat) {
        switch route {
        case .slant:   return (0.65, 0.35)
        case .corner:  return (0.75, 0.25)
        case .post:    return (0.5, 0.2)
        case .fly:     return (0.5, 0.1)
        case .out:     return (0.8, 0.5)
        }
    }

    private func handleThrow() {
        guard phase == .catchRoute, !playerThrew else { return }
        playerThrew = true
        routeTask?.cancel(); clockTask?.cancel()
        qbPose = "throw"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let caught = windowOpen
        catchResult = caught

        if caught {
            // Animate the throw
            throwTargetX = receiverX; throwTargetY = receiverY
            throwProgress = 0
            Task {
                for step in 0..<28 {
                    try? await Task.sleep(nanoseconds: 14_000_000)
                    await MainActor.run { throwProgress = Double(step + 1) / 28.0 }
                }
                await MainActor.run { throwProgress = -1 }
            }

            let gained = currentRoute.yards
            yardsGained = 0; runMeter = 0.0
            defenderPosition = Double.random(in: 0.3...0.7)
            playerPosition = 0.5; jukeCount = 0
            crowdExcitement = min(1.0, crowdExcitement + 0.15)

            withAnimation {
                playResultLabel = "CAUGHT! +\(gained) YDS"
                playResultColor = Color(red: 0.2, green: 0.8, blue: 1.0)
                showPlayResult = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                await MainActor.run {
                    showPlayResult = false; phase = .run; startRunPhase(yards: gained)
                }
            }
        } else {
            handleIncompletionOrSack()
        }
    }

    private func handleIncompletionOrSack() {
        clockTask?.cancel(); qbPose = "idle"
        withAnimation {
            playResultLabel = "INCOMPLETE"
            playResultColor = .red; showPlayResult = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run { showPlayResult = false; advanceDown(yardsGained: 0) }
        }
    }

    private func startRunPhase(yards: Int) {
        playClock = 40; startClock()
        runTask?.cancel()
        runTask = Task {
            while !Task.isCancelled && phase == .run {
                try? await Task.sleep(for: .milliseconds(380))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    let diff = playerPosition - defenderPosition
                    defenderPosition += diff * 0.14
                }
            }
        }
    }

    private func handleDodge(_ direction: DodgeDirection) {
        guard phase == .run else { return }
        let move: CGFloat = direction == .left ? -0.18 : 0.18
        playerPosition = max(0.1, min(0.9, playerPosition + move))
        jukeCount += 1
        let labels = ["JUKE!", "SPIN MOVE!", "STIFF ARM!", "HURDLE!", "CUTBACK!"]
        dodgeLabel = labels[jukeCount % labels.count]
        withAnimation(.spring(response: 0.2)) { showDodgeLabel = true }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { withAnimation { showDodgeLabel = false } }
        }
        advanceRun(yards: 3)
    }

    private func advanceRun(yards: Int) {
        guard phase == .run else { return }
        yardsGained += yards; yardLine = min(100, yardLine + yards)
        let needed = yardsToGo > 0 ? yardsToGo : 0
        runMeter = min(1.0, Double(yardsGained) / Double(max(needed, 5)))

        if yardLine >= 100 {
            clockTask?.cancel(); runTask?.cancel()
            phase = .touchdown; crowdExcitement = 1.0
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) { tdScale = 1.0; tdFlash = true }
            Task {
                try? await Task.sleep(for: .seconds(3.2))
                await MainActor.run { phase = .result }
            }
        } else if yardsGained >= yardsToGo {
            let newYardsToGo = max(0, 100 - yardLine)
            yardsToGo = newYardsToGo; clockTask?.cancel(); runTask?.cancel()
            down = 1; crowdExcitement = min(1.0, crowdExcitement + 0.25)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation {
                playResultLabel = "FIRST DOWN!"; playResultColor = Color(red: 0.2, green: 0.8, blue: 1.0); showPlayResult = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run {
                    showPlayResult = false; phase = .catchRoute; setupCatchPhase(); startClock()
                }
            }
        }
    }

    private func advanceDown(yardsGained yards: Int) {
        yardLine += yards; yardsToGo = max(0, yardsToGo - yards)
        if yardsToGo <= 0 { down = 1; yardsToGo = min(YARDS_TO_GO_INITIAL, 100 - yardLine) }
        else { down += 1 }
        if down > MAX_DOWNS {
            phase = .turnover
            Task { try? await Task.sleep(for: .seconds(2.5)); await MainActor.run { phase = .result } }
            return
        }
        playClock = 40; phase = .catchRoute; setupCatchPhase(); startClock()
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task {
            while playClock > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { playClock -= 1 }
            }
            await MainActor.run {
                if phase == .catchRoute { handleIncompletionOrSack() }
            }
        }
    }

    private func cancelAllTasks() {
        routeTask?.cancel(); runTask?.cancel(); clockTask?.cancel()
    }

    private func grantRewards(shards: Int) {
        guard !rewardGranted else { return }
        rewardGranted = true
        viewModel.profile.evolutionShards += shards
        let xpGain = min(XP_CAP_PER_SESSION, shards * 2)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) / 100.0)
    }
}
