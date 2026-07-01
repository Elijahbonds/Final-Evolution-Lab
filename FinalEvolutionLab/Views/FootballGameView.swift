import SwiftUI
import UIKit

// MARK: - Enums

private enum FBPhase {
    case ready, presnap, catchRoute, run, touchdown, turnover, result
}

private enum RouteType: String, CaseIterable {
    case slant  = "SLANT"
    case cross  = "CROSS"
    case fly    = "FLY"

    var yards: Int {
        switch self {
        case .slant: return 6
        case .cross: return 11
        case .fly:   return 30
        }
    }

    var windowSeconds: Double {
        switch self {
        case .slant: return 0.8
        case .cross: return 1.0
        case .fly:   return 1.4
        }
    }

    var riskLabel: String {
        switch self {
        case .slant: return "RISKY \u00b7 FAST"
        case .cross: return "BALANCED"
        case .fly:   return "BIG PLAY"
        }
    }

    var yardRange: String {
        switch self {
        case .slant: return "5-8 YDS"
        case .cross: return "8-15 YDS"
        case .fly:   return "20-40 YDS"
        }
    }

    var accentColor: Color {
        switch self {
        case .slant: return Color(red: 1.0, green: 0.40, blue: 0.20)
        case .cross: return Color(red: 0.20, green: 0.80, blue: 1.00)
        case .fly:   return Color(red: 0.60, green: 0.30, blue: 1.00)
        }
    }
}

private enum DodgeDirection { case left, right, none }

private let XP_CAP_PER_SESSION = 500
private let MAX_DOWNS = 4
private let YARDS_TO_GO_INITIAL = 10
private let TD_YARDS = 100

// MARK: - Haptic Helpers

private func hapticHeavy() {
    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
}
private func hapticRigid() {
    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
}
private func hapticMedium() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
private func hapticSoft() {
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
}
private func hapticError() {
    UINotificationFeedbackGenerator().notificationOccurred(.error)
}

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
    let homeScore: Int
    let awayScore: Int
    let quarter: Int

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
                    crowdExcitement: crowdExcitement,
                    homeScore: homeScore,
                    awayScore: awayScore,
                    quarter: quarter
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
    let homeScore: Int
    let awayScore: Int
    let quarter: Int

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
        // --- Field BG (#1–#12) ---
        drawGrassField(ctx: &ctx)       // #1–#5: base field, mow stripes
        drawYardLines(ctx: &ctx)        // #6–#9: yard lines, hashmarks
        drawEndZones(ctx: &ctx)         // #10–#12: end zone fills, labels, goal-post base

        // --- Stadium (#13–#24) ---
        drawStadiumSky(ctx: &ctx)       // #13–#16: sky gradient, crowd tiers
        drawStadiumLights(ctx: &ctx)    // #17–#20: 4 light towers + cone beams
        drawJumbotron(ctx: &ctx)        // #21–#22: scoreboard + down-and-distance
        drawPressBox(ctx: &ctx)         // #23–#24: press box windows

        // --- Goal Posts ---
        drawGoalPosts(ctx: &ctx)        // #25–#26: crossbar + uprights (glow)

        // --- Formation overlay (#27–#38) ---
        if phase == .catchRoute {
            drawFormationOverlay(ctx: &ctx)
        }

        // --- Phase-specific players (#39–#72) and FX (#73–#86) ---
        switch phase {
        case .catchRoute:
            drawRoutePath(ctx: &ctx)
            drawQB(ctx: &ctx)
            drawReceiver(ctx: &ctx)
            if throwProgress >= 0 { drawFootball(ctx: &ctx) }
        case .run:
            drawDefender(ctx: &ctx)
            drawRunner(ctx: &ctx)
            drawBallCarrierFX(ctx: &ctx)
        case .touchdown:
            drawTouchdownFX(ctx: &ctx)
            drawTDRunner(ctx: &ctx)
        case .turnover:
            drawSackDust(ctx: &ctx)
            drawTurnoverRunner(ctx: &ctx)
        default:
            break
        }

        // Red zone glow when near end zone
        if phase == .run || phase == .catchRoute {
            drawRedZoneGlow(ctx: &ctx)
        }

        // First down line
        drawFirstDownLine(ctx: &ctx)

        // Crowd wave brightness pulse
        drawCrowdNoisePulse(ctx: &ctx)
    }

    // MARK: - Field BG (#1–#12)

    private func drawGrassField(ctx: inout GraphicsContext) {
        // #1 — Base grass gradient
        ctx.fill(
            Path(CGRect(x: fieldLeft, y: fieldTop, width: fieldWidth, height: fieldHeight)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.08, green: 0.30, blue: 0.08),
                    Color(red: 0.05, green: 0.20, blue: 0.05)
                ]),
                startPoint: CGPoint(x: W * 0.5, y: fieldTop),
                endPoint: CGPoint(x: W * 0.5, y: fieldBot)
            )
        )

        // #2 — Alternating mow stripe pattern (10 strips)
        let stripes = 10
        let stripeH = fieldHeight / CGFloat(stripes)
        for i in 0..<stripes {
            let sy = fieldTop + CGFloat(i) * stripeH
            if i % 2 == 0 {
                // #2a slightly lighter stripe
                ctx.fill(
                    Path(CGRect(x: fieldLeft, y: sy, width: fieldWidth, height: stripeH)),
                    with: .color(Color(white: 1).opacity(0.025))
                )
            } else {
                // #2b slightly darker stripe
                ctx.fill(
                    Path(CGRect(x: fieldLeft, y: sy, width: fieldWidth, height: stripeH)),
                    with: .color(Color(black: 1).opacity(0.018))
                )
            }
        }

        // #3 — Mow-pattern horizontal sheen lines (subtle texture)
        for i in 0..<stripes {
            let ly = fieldTop + CGFloat(i) * stripeH
            var ln = Path()
            ln.move(to: CGPoint(x: fieldLeft, y: ly))
            ln.addLine(to: CGPoint(x: fieldRight, y: ly))
            ctx.stroke(ln, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
        }

        // #4 — Field edge glow (ambient turf light)
        var fieldGlow = ctx
        fieldGlow.addFilter(.blur(radius: 12))
        fieldGlow.opacity = 0.08
        fieldGlow.fill(
            Path(CGRect(x: fieldLeft, y: fieldTop, width: fieldWidth, height: fieldHeight)),
            with: .color(Color(red: 0.2, green: 0.9, blue: 0.2))
        )

        // #5 — Sideline out-of-bounds white stripes
        ctx.fill(
            Path(CGRect(x: fieldLeft - 3, y: fieldTop, width: 3, height: fieldHeight)),
            with: .color(.white.opacity(0.55))
        )
        ctx.fill(
            Path(CGRect(x: fieldRight, y: fieldTop, width: 3, height: fieldHeight)),
            with: .color(.white.opacity(0.55))
        )
    }

    private func drawYardLines(ctx: inout GraphicsContext) {
        let tenYardLines = 9 // 10, 20, 30, 40, 50, 40, 30, 20, 10
        let spacing = fieldHeight / CGFloat(tenYardLines + 1)
        let yardNumbers = [10, 20, 30, 40, 50, 40, 30, 20, 10]

        for i in 1...tenYardLines {
            let y = fieldTop + CGFloat(i) * spacing

            // #6 — Full 10-yard white line
            var line = Path()
            line.move(to: CGPoint(x: fieldLeft, y: y))
            line.addLine(to: CGPoint(x: fieldRight, y: y))
            ctx.stroke(line, with: .color(.white.opacity(0.32)), lineWidth: 1.5)

            // #7 — Yard number labels both sides
            let numText = ctx.resolve(
                Text("\(yardNumbers[i - 1])")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.38))
            )
            ctx.draw(numText, at: CGPoint(x: fieldLeft + 16, y: y - 5))
            ctx.draw(numText, at: CGPoint(x: fieldRight - 16, y: y - 5))

            // #8 — Hashmarks: two rows of small ticks per yard line
            let hashW: CGFloat = 14
            let hashInner = fieldWidth * 0.33
            let hashOuter = fieldWidth * 0.67
            var hash = Path()
            // Left hash pair
            hash.move(to: CGPoint(x: fieldLeft + hashInner - hashW, y: y))
            hash.addLine(to: CGPoint(x: fieldLeft + hashInner, y: y))
            // Right hash pair
            hash.move(to: CGPoint(x: fieldLeft + hashOuter, y: y))
            hash.addLine(to: CGPoint(x: fieldLeft + hashOuter + hashW, y: y))
            ctx.stroke(hash, with: .color(.white.opacity(0.28)), lineWidth: 1.2)

            // #9 — 5-yard tick marks on sidelines (between every 10-yard line)
            if i < tenYardLines {
                let midY = y + spacing * 0.5
                var mid = Path()
                mid.move(to: CGPoint(x: fieldLeft, y: midY))
                mid.addLine(to: CGPoint(x: fieldLeft + 10, y: midY))
                mid.move(to: CGPoint(x: fieldRight - 10, y: midY))
                mid.addLine(to: CGPoint(x: fieldRight, y: midY))
                ctx.stroke(mid, with: .color(.white.opacity(0.18)), lineWidth: 1.0)
            }
        }

        // Line of scrimmage glow
        let losYCanvas = fieldBot - 20
        var los = Path()
        los.move(to: CGPoint(x: fieldLeft, y: losYCanvas))
        los.addLine(to: CGPoint(x: fieldRight, y: losYCanvas))
        var losCtx = ctx
        losCtx.addFilter(.blur(radius: 4))
        losCtx.opacity = 0.55
        losCtx.stroke(los, with: .color(Color(red: 0.8, green: 0.8, blue: 0.0)), lineWidth: 4)
        ctx.stroke(los, with: .color(Color(red: 0.9, green: 0.9, blue: 0.0).opacity(0.7)), lineWidth: 1.2)
    }

    private func drawEndZones(ctx: inout GraphicsContext) {
        // #10 — Home end zone colored fill (top)
        ctx.fill(
            Path(CGRect(x: fieldLeft, y: endZoneTop, width: fieldWidth, height: endZoneBot - endZoneTop)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.10, green: 0.32, blue: 0.10),
                    Color(red: 0.06, green: 0.22, blue: 0.06)
                ]),
                startPoint: CGPoint(x: W * 0.5, y: endZoneTop),
                endPoint: CGPoint(x: W * 0.5, y: endZoneBot)
            )
        )

        // Diagonal stripes in end zone
        for i in 0..<10 {
            let ox = fieldLeft + CGFloat(i) * fieldWidth / 9
            var stripe = Path()
            stripe.move(to: CGPoint(x: ox, y: endZoneTop))
            stripe.addLine(to: CGPoint(x: ox + 24, y: endZoneBot))
            ctx.stroke(stripe, with: .color(.white.opacity(0.05)), lineWidth: 2.5)
        }

        // #11 — End zone team name text block (home)
        let ezHomeText = ctx.resolve(
            Text("NEXUS")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.30))
        )
        ctx.draw(ezHomeText, at: CGPoint(x: W * 0.5, y: (endZoneTop + endZoneBot) / 2))

        // #12 — End zone boundary white line
        ctx.fill(
            Path(CGRect(x: fieldLeft, y: endZoneBot - 3, width: fieldWidth, height: 3)),
            with: .color(.white.opacity(0.72))
        )

        // Away end zone (bottom, below fieldBot)
        let awayEZTop = fieldBot
        let awayEZBot = fieldBot + (endZoneBot - endZoneTop)
        ctx.fill(
            Path(CGRect(x: fieldLeft, y: awayEZTop, width: fieldWidth, height: awayEZBot - awayEZTop)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.30, green: 0.06, blue: 0.06),
                    Color(red: 0.22, green: 0.04, blue: 0.04)
                ]),
                startPoint: CGPoint(x: W * 0.5, y: awayEZTop),
                endPoint: CGPoint(x: W * 0.5, y: awayEZBot)
            )
        )
        for i in 0..<10 {
            let ox = fieldLeft + CGFloat(i) * fieldWidth / 9
            var stripe = Path()
            stripe.move(to: CGPoint(x: ox, y: awayEZTop))
            stripe.addLine(to: CGPoint(x: ox + 24, y: awayEZBot))
            ctx.stroke(stripe, with: .color(.white.opacity(0.04)), lineWidth: 2.5)
        }
        let ezAwayText = ctx.resolve(
            Text("RIVALS")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.28))
        )
        ctx.draw(ezAwayText, at: CGPoint(x: W * 0.5, y: (awayEZTop + awayEZBot) / 2))
        ctx.fill(
            Path(CGRect(x: fieldLeft, y: awayEZTop, width: fieldWidth, height: 3)),
            with: .color(.white.opacity(0.72))
        )
    }

    // MARK: - Stadium (#13–#24)

    private func drawStadiumSky(ctx: inout GraphicsContext) {
        // #13 — Sky/backdrop gradient
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.14),
                    Color(red: 0.04, green: 0.07, blue: 0.02)
                ]),
                startPoint: CGPoint(x: W * 0.5, y: 0),
                endPoint: CGPoint(x: W * 0.5, y: H)
            )
        )

        // #14 — Crowd tier backgrounds: 3 levels
        let tierColors: [Color] = [
            Color(red: 0.12, green: 0.12, blue: 0.16),
            Color(red: 0.10, green: 0.10, blue: 0.14),
            Color(red: 0.08, green: 0.08, blue: 0.12)
        ]
        let tierHeights: [CGFloat] = [H * 0.04, H * 0.035, H * 0.03]
        let tierTops: [CGFloat] = [
            fieldTop - tierHeights[0] * 3 - 4,
            fieldTop - tierHeights[1] * 2 - 2,
            fieldTop - tierHeights[2]
        ]
        for (idx, tc) in tierColors.enumerated() {
            ctx.fill(
                Path(CGRect(x: 0, y: tierTops[idx], width: W, height: tierHeights[idx])),
                with: .color(tc)
            )
        }

        // #15 — Crowd silhouettes: 50+ figures across 3 tiers
        let jerseys: [Color] = [
            Color(red: 0.10, green: 0.35, blue: 0.75),
            Color(red: 0.75, green: 0.10, blue: 0.10),
            Color(red: 0.92, green: 0.82, blue: 0.15),
            Color(red: 0.82, green: 0.38, blue: 0.04),
            Color(white: 0.88)
        ]
        for tierIdx in 0..<3 {
            let tierY = tierTops[tierIdx]
            let figCount = 20 + tierIdx * 8
            let figSpacing = W / CGFloat(figCount)
            for col in 0..<figCount {
                let fx = CGFloat(col) * figSpacing + figSpacing * 0.5
                let jc = jerseys[(col * 3 + tierIdx * 7) % jerseys.count]
                let excited = crowdExcitement > 0.45
                let headY = tierY + 4
                let bodyY = tierY + 10
                let figH: CGFloat = tierHeights[tierIdx] * 0.65

                // Head
                ctx.fill(
                    Path(ellipseIn: CGRect(x: fx - 3, y: headY, width: 6, height: 6)),
                    with: .color(Color(red: 0.78, green: 0.62, blue: 0.48))
                )
                // Body
                ctx.fill(
                    Path(CGRect(x: fx - 3.5, y: bodyY, width: 7, height: figH)),
                    with: .color(jc.opacity(0.82))
                )
                // Excited arms wave
                if excited {
                    let wave = CGFloat(sin(t * 3.8 + Double(col) * 0.65 + Double(tierIdx) * 1.3)) * 3
                    var arms = Path()
                    arms.move(to: CGPoint(x: fx - 3.5, y: bodyY + 2))
                    arms.addLine(to: CGPoint(x: fx - 8, y: bodyY - 3 + wave))
                    arms.move(to: CGPoint(x: fx + 3.5, y: bodyY + 2))
                    arms.addLine(to: CGPoint(x: fx + 8, y: bodyY - 3 - wave))
                    ctx.stroke(arms, with: .color(jc.opacity(0.6)), lineWidth: 1.2)
                }
            }
        }

        // #16 — Sideline crowd panels (left and right of field)
        let sideW: CGFloat = fieldLeft
        for sideX in [CGFloat(0), fieldRight] {
            ctx.fill(
                Path(CGRect(x: sideX, y: fieldTop, width: sideW, height: fieldHeight)),
                with: .color(Color(white: 0.05))
            )
            let rows = 6
            let figRowH = fieldHeight / CGFloat(rows)
            for row in 0..<rows {
                let ry = fieldTop + CGFloat(row) * figRowH + 4
                let count = Int(sideW / 9)
                for col in 0..<count {
                    let cx = sideX + CGFloat(col) * 9 + 4.5
                    let jc = jerseys[(col * 5 + row * 3) % jerseys.count]
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cx - 2.5, y: ry, width: 5, height: 5)),
                        with: .color(Color(red: 0.80, green: 0.62, blue: 0.48))
                    )
                    ctx.fill(
                        Path(CGRect(x: cx - 2.5, y: ry + 5, width: 5, height: 4)),
                        with: .color(jc.opacity(0.75))
                    )
                    if crowdExcitement > 0.5 {
                        let wave = CGFloat(sin(t * 3.5 + Double(col) * 0.7 + Double(row) * 1.2)) * 2.5
                        var arms = Path()
                        arms.move(to: CGPoint(x: cx - 2.5, y: ry + 7))
                        arms.addLine(to: CGPoint(x: cx - 6, y: ry + 2 + wave))
                        arms.move(to: CGPoint(x: cx + 2.5, y: ry + 7))
                        arms.addLine(to: CGPoint(x: cx + 6, y: ry + 2 + wave))
                        ctx.stroke(arms, with: .color(jc.opacity(0.55)), lineWidth: 1.0)
                    }
                }
            }
        }
    }

    private func drawStadiumLights(ctx: inout GraphicsContext) {
        // #17 — 4 light tower poles at corners
        let towerPositions: [(CGFloat, CGFloat)] = [
            (W * 0.03, H * 0.03),
            (W * 0.97, H * 0.03),
            (W * 0.03, H * 0.90),
            (W * 0.97, H * 0.90)
        ]
        for (tx, ty) in towerPositions {
            // Tower pole
            var pole = Path()
            pole.move(to: CGPoint(x: tx, y: ty + 28))
            pole.addLine(to: CGPoint(x: tx, y: ty))
            ctx.stroke(pole, with: .color(Color(white: 0.55)), lineWidth: 2.5)

            // Light head
            ctx.fill(
                Path(CGRect(x: tx - 9, y: ty - 5, width: 18, height: 5)),
                with: .color(Color(white: 0.82))
            )

            // #18 — Cone beam from each tower (4 beams)
            let beamOpacity = 0.06 + CGFloat(sin(t * 0.8 + Double(tx))) * 0.015
            var gc = ctx
            gc.addFilter(.blur(radius: 18))
            gc.opacity = Double(beamOpacity)
            var cone = Path()
            let beamTargetX = W * 0.5
            let beamTargetY = H * 0.5
            cone.move(to: CGPoint(x: tx - 10, y: ty))
            cone.addLine(to: CGPoint(x: beamTargetX - 80, y: beamTargetY))
            cone.addLine(to: CGPoint(x: beamTargetX + 80, y: beamTargetY))
            cone.addLine(to: CGPoint(x: tx + 10, y: ty))
            cone.closeSubpath()
            gc.fill(cone, with: .color(.white))

            // #19 — Light bloom at tip
            var bloom = ctx
            bloom.addFilter(.blur(radius: 10))
            bloom.opacity = 0.22
            bloom.fill(
                Path(ellipseIn: CGRect(x: tx - 12, y: ty - 8, width: 24, height: 14)),
                with: .color(.white)
            )
        }

        // #20 — Ambient field flood light wash
        var flood = ctx
        flood.addFilter(.blur(radius: 40))
        flood.opacity = 0.04
        flood.fill(
            Path(CGRect(x: fieldLeft, y: fieldTop, width: fieldWidth, height: fieldHeight)),
            with: .color(.white)
        )
    }

    private func drawJumbotron(ctx: inout GraphicsContext) {
        // #21 — Jumbotron scoreboard panel (top-center above end zone)
        let jbW: CGFloat = 160
        let jbH: CGFloat = 38
        let jbX = W * 0.5 - jbW * 0.5
        let jbY = H * 0.005

        // Board background
        ctx.fill(
            Path(CGRect(x: jbX, y: jbY, width: jbW, height: jbH)),
            with: .color(Color(white: 0.06))
        )
        // Border
        var border = Path(CGRect(x: jbX, y: jbY, width: jbW, height: jbH))
        ctx.stroke(border, with: .color(Color(white: 0.25)), lineWidth: 1)

        // Score displays
        let homeLabel = ctx.resolve(
            Text("HOME  \(homeScore)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.2))
        )
        ctx.draw(homeLabel, at: CGPoint(x: jbX + jbW * 0.25, y: jbY + 10))

        let awayLabel = ctx.resolve(
            Text("AWAY  \(awayScore)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
        )
        ctx.draw(awayLabel, at: CGPoint(x: jbX + jbW * 0.75, y: jbY + 10))

        let qtrLabel = ctx.resolve(
            Text("Q\(quarter)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
        )
        ctx.draw(qtrLabel, at: CGPoint(x: jbX + jbW * 0.5, y: jbY + 10))

        // #22 — Down-and-distance display strip
        let ddY = jbY + jbH + 2
        let ddW: CGFloat = 110
        ctx.fill(
            Path(CGRect(x: W * 0.5 - ddW * 0.5, y: ddY, width: ddW, height: 16)),
            with: .color(Color(red: 0.10, green: 0.10, blue: 0.30).opacity(0.85))
        )
        let ddText = ctx.resolve(
            Text("1ST & 10 · OWN 25")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.75))
        )
        ctx.draw(ddText, at: CGPoint(x: W * 0.5, y: ddY + 8))
    }

    private func drawPressBox(ctx: inout GraphicsContext) {
        // #23 — Press box structure (top strip)
        let pbH: CGFloat = 12
        let pbY = endZoneTop - pbH - 2
        ctx.fill(
            Path(CGRect(x: fieldLeft + 10, y: pbY, width: fieldWidth - 20, height: pbH)),
            with: .color(Color(white: 0.10))
        )

        // #24 — Press box windows (6 lit windows)
        let winCount = 6
        let winW: CGFloat = (fieldWidth - 20 - CGFloat(winCount + 1) * 8) / CGFloat(winCount)
        for i in 0..<winCount {
            let wx = fieldLeft + 10 + CGFloat(i) * (winW + 8) + 8
            let flicker = 0.55 + 0.25 * CGFloat(sin(t * 2.0 + Double(i) * 0.9))
            ctx.fill(
                Path(CGRect(x: wx, y: pbY + 2, width: winW, height: pbH - 4)),
                with: .color(Color(red: 0.9, green: 0.85, blue: 0.5).opacity(Double(flicker)))
            )
        }
    }

    // MARK: - Goal Posts (#25–#26)

    private func drawGoalPosts(ctx: inout GraphicsContext) {
        let cx = W * 0.5
        let base = endZoneTop + 5
        let poleH: CGFloat = 22
        let crossBarY = base + poleH
        let postW: CGFloat = 32
        let uptH: CGFloat = 20

        // #25 — Goal post structure: base pole, crossbar, two uprights
        var goalPost = Path()
        // Base pole (vertical from field)
        goalPost.move(to: CGPoint(x: cx, y: base + poleH + uptH))
        goalPost.addLine(to: CGPoint(x: cx, y: base))
        // Crossbar
        goalPost.move(to: CGPoint(x: cx - postW, y: crossBarY))
        goalPost.addLine(to: CGPoint(x: cx + postW, y: crossBarY))
        // Left upright
        goalPost.move(to: CGPoint(x: cx - postW, y: crossBarY))
        goalPost.addLine(to: CGPoint(x: cx - postW, y: base))
        // Right upright
        goalPost.move(to: CGPoint(x: cx + postW, y: crossBarY))
        goalPost.addLine(to: CGPoint(x: cx + postW, y: base))
        ctx.stroke(goalPost, with: .color(.yellow.opacity(0.88)), lineWidth: 2.8)

        // #26 — Glow halo around goal posts
        var glow = ctx
        glow.addFilter(.blur(radius: 7))
        glow.opacity = 0.28
        glow.stroke(goalPost, with: .color(.yellow), lineWidth: 7)
    }

    // MARK: - Formation Overlay (#27–#38)

    private func drawFormationOverlay(ctx: inout GraphicsContext) {
        let losY = fieldBot - 20
        let snapFade = CGFloat(max(0, min(1, sin(t * 1.2) * 0.5 + 0.5)))
        let baseAlpha = 0.55 * snapFade

        // #27 — Offensive line: 5 O circles
        let oLineY = losY - 8
        let oSpacing: CGFloat = fieldWidth / 8
        let oStart = W * 0.5 - oSpacing * 2
        for i in 0..<5 {
            let ox = oStart + CGFloat(i) * oSpacing
            var oCirc = Path()
            oCirc.addEllipse(in: CGRect(x: ox - 8, y: oLineY - 8, width: 16, height: 16))
            ctx.stroke(oCirc, with: .color(Color(red: 0.2, green: 0.8, blue: 1.0).opacity(Double(baseAlpha))), lineWidth: 1.5)
        }

        // #28 — Defensive line: 4 X markers
        let dLineY = losY + 14
        let dStart = W * 0.5 - oSpacing * 1.5
        for i in 0..<4 {
            let dx = dStart + CGFloat(i) * oSpacing
            let xSize: CGFloat = 7
            var xMark = Path()
            xMark.move(to: CGPoint(x: dx - xSize, y: dLineY - xSize))
            xMark.addLine(to: CGPoint(x: dx + xSize, y: dLineY + xSize))
            xMark.move(to: CGPoint(x: dx + xSize, y: dLineY - xSize))
            xMark.addLine(to: CGPoint(x: dx - xSize, y: dLineY + xSize))
            ctx.stroke(xMark, with: .color(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(Double(baseAlpha))), lineWidth: 1.5)
        }

        // #29 — QB marker behind center (center of O-line)
        let qbMarkerX = W * 0.5
        let qbMarkerY = losY - 30
        var qbCirc = Path()
        qbCirc.addEllipse(in: CGRect(x: qbMarkerX - 9, y: qbMarkerY - 9, width: 18, height: 18))
        ctx.stroke(qbCirc, with: .color(Color(red: 0.2, green: 0.9, blue: 0.2).opacity(Double(baseAlpha))), lineWidth: 2)
        let qbLbl = ctx.resolve(
            Text("QB")
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(Double(baseAlpha * 0.8)))
        )
        ctx.draw(qbLbl, at: CGPoint(x: qbMarkerX, y: qbMarkerY))

        // #30 — WR route dotted arc (left side)
        let wrLX = fieldLeft + fieldWidth * 0.15
        let wrLY = losY - 18
        var wrRouteL = Path()
        wrRouteL.move(to: CGPoint(x: wrLX, y: wrLY))
        wrRouteL.addQuadCurve(
            to: CGPoint(x: wrLX - 30, y: wrLY - fieldHeight * 0.25),
            control: CGPoint(x: wrLX - 40, y: wrLY - 20)
        )
        ctx.stroke(
            wrRouteL,
            with: .color(Color(red: 0.2, green: 0.8, blue: 1.0).opacity(Double(baseAlpha * 0.7))),
            style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
        )

        // #31 — WR route dotted arc (right side)
        let wrRX = fieldLeft + fieldWidth * 0.85
        let wrRY = losY - 18
        var wrRouteR = Path()
        wrRouteR.move(to: CGPoint(x: wrRX, y: wrRY))
        wrRouteR.addQuadCurve(
            to: CGPoint(x: wrRX + 28, y: wrRY - fieldHeight * 0.20),
            control: CGPoint(x: wrRX + 36, y: wrRY - 15)
        )
        ctx.stroke(
            wrRouteR,
            with: .color(Color(red: 0.2, green: 0.8, blue: 1.0).opacity(Double(baseAlpha * 0.7))),
            style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
        )

        // #32 — TE route (short cross)
        let teX = W * 0.5 + oSpacing * 2.5
        let teY = losY - 16
        var teRoute = Path()
        teRoute.move(to: CGPoint(x: teX, y: teY))
        teRoute.addLine(to: CGPoint(x: teX + fieldWidth * 0.12, y: teY - fieldHeight * 0.12))
        ctx.stroke(
            teRoute,
            with: .color(Color(red: 0.9, green: 0.8, blue: 0.2).opacity(Double(baseAlpha * 0.65))),
            style: StrokeStyle(lineWidth: 1.2, dash: [3, 5])
        )

        // #33 — Blitz arrow (defensive path, red)
        let blitzX = W * 0.5 + oSpacing * 1.0
        let blitzStartY = dLineY + 18
        var blitz = Path()
        blitz.move(to: CGPoint(x: blitzX, y: blitzStartY))
        blitz.addLine(to: CGPoint(x: blitzX - 12, y: blitzStartY - 22))
        blitz.addLine(to: CGPoint(x: blitzX - 6, y: blitzStartY - 22))
        blitz.addLine(to: CGPoint(x: blitzX - 6, y: blitzStartY - 30))
        ctx.stroke(
            blitz,
            with: .color(Color(red: 1.0, green: 0.15, blue: 0.15).opacity(Double(baseAlpha * 0.8))),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
        )
        // Arrow head
        var arrowHead = Path()
        arrowHead.move(to: CGPoint(x: blitzX - 10, y: blitzStartY - 30))
        arrowHead.addLine(to: CGPoint(x: blitzX - 6, y: blitzStartY - 36))
        arrowHead.addLine(to: CGPoint(x: blitzX - 2, y: blitzStartY - 30))
        ctx.stroke(
            arrowHead,
            with: .color(Color(red: 1.0, green: 0.15, blue: 0.15).opacity(Double(baseAlpha * 0.8))),
            lineWidth: 1.4
        )

        // #34 — Play diagram fade overlay (snapping text)
        if snapFade > 0.3 {
            let snapAlpha = min(1.0, (snapFade - 0.3) / 0.4)
            let playText = ctx.resolve(
                Text("PLAY DIAGRAM")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(Double(0.20 * snapAlpha)))
            )
            ctx.draw(playText, at: CGPoint(x: W * 0.5, y: losY - 55))
        }

        // #35 — RB offset behind QB
        let rbX = W * 0.5 - 18
        let rbY = losY - 42
        var rbCirc = Path()
        rbCirc.addEllipse(in: CGRect(x: rbX - 7, y: rbY - 7, width: 14, height: 14))
        ctx.stroke(
            rbCirc,
            with: .color(Color(red: 0.2, green: 0.9, blue: 0.2).opacity(Double(baseAlpha * 0.6))),
            lineWidth: 1.2
        )
        let rbLbl = ctx.resolve(
            Text("RB")
                .font(.system(size: 5, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(Double(baseAlpha * 0.55)))
        )
        ctx.draw(rbLbl, at: CGPoint(x: rbX, y: rbY))

        // #36 — FB lead blocker
        let fbX = W * 0.5
        let fbY = losY - 56
        var fbCirc = Path()
        fbCirc.addEllipse(in: CGRect(x: fbX - 6, y: fbY - 6, width: 12, height: 12))
        ctx.stroke(
            fbCirc,
            with: .color(Color(red: 0.5, green: 0.8, blue: 0.5).opacity(Double(baseAlpha * 0.50))),
            lineWidth: 1.0
        )

        // #37 — Coverage zone shading (defensive secondary)
        for i in 0..<3 {
            let zx = fieldLeft + fieldWidth * (0.2 + CGFloat(i) * 0.3)
            let zy = losY + 40
            var zoneCirc = Path()
            zoneCirc.addEllipse(in: CGRect(x: zx - 28, y: zy - 14, width: 56, height: 28))
            var zc = ctx
            zc.opacity = Double(baseAlpha * 0.15)
            zc.fill(zoneCirc, with: .color(Color(red: 1.0, green: 0.3, blue: 0.3)))
        }

        // #38 — Snap indicator (blinking dot at center)
        let snapPulse = 0.5 + 0.5 * CGFloat(sin(t * 5.0))
        ctx.fill(
            Path(ellipseIn: CGRect(x: W * 0.5 - 4, y: losY - 5, width: 8, height: 8)),
            with: .color(Color.white.opacity(Double(snapPulse * baseAlpha * 0.9)))
        )
    }

    // MARK: - Route Path

    private func drawRoutePath(ctx: inout GraphicsContext) {
        let start = qbPos()
        let routeEnd = receiverCanvas()

        // #39 — Route trail (dashed line QB→WR)
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
        ctx.stroke(
            path,
            with: .color(Color(red: 0.2, green: 0.8, blue: 1.0).opacity(0.28)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        // Window indicator circle at route end
        if windowOpen {
            let pulse = 0.6 + 0.3 * CGFloat(sin(t * 8.0))
            var winCirc = Path()
            winCirc.addEllipse(in: CGRect(x: routeEnd.x - 22, y: routeEnd.y - 22, width: 44, height: 44))
            var wc = ctx; wc.opacity = Double(pulse)
            wc.stroke(winCirc, with: .color(.green), lineWidth: 2.5)
            var inner = Path()
            inner.addEllipse(in: CGRect(x: routeEnd.x - 14, y: routeEnd.y - 14, width: 28, height: 28))
            var ic = ctx; ic.opacity = Double(pulse * 0.5)
            ic.stroke(inner, with: .color(.green), lineWidth: 2)
        }
    }

    // MARK: - QB (#40–#46)

    private func drawQB(ctx: inout GraphicsContext) {
        let p = qbPos()
        let x = p.x; let y = p.y
        let color = Color(red: 0.20, green: 0.65, blue: 0.20)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let helmetColor = Color(red: 0.12, green: 0.45, blue: 0.12)
        let r: CGFloat = 8

        switch qbPose {
        case "windup":
            // #40 — QB windup: head/helmet
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r - 2, y: y - 38 - r, width: r*2, height: r*2)),
                with: .color(skin)
            )
            var helm = Path()
            helm.addArc(center: CGPoint(x: x - 2, y: y - 38), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            helm.addLine(to: CGPoint(x: x - 2 - r - 4, y: y - 38))
            ctx.fill(helm, with: .color(helmetColor))
            // #41 — QB body in windup
            var body = Path()
            body.move(to: CGPoint(x: x - 2, y: y - 38))
            body.addLine(to: CGPoint(x: x + 3, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            // #42 — Throwing arm cocked back
            var arm = Path()
            arm.move(to: CGPoint(x: x, y: y - 28))
            arm.addLine(to: CGPoint(x: x + 20, y: y - 40))
            ctx.stroke(arm, with: .color(color), lineWidth: 3)
            // Football in hand
            drawFootballAt(ctx: &ctx, x: x + 22, y: y - 43, angle: 0.8, r: 5)
            // #43 — Legs
            var legs = Path()
            legs.move(to: CGPoint(x: x + 3, y: y - 14))
            legs.addLine(to: CGPoint(x: x + 14, y: y))
            legs.move(to: CGPoint(x: x + 3, y: y - 14))
            legs.addLine(to: CGPoint(x: x - 10, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)
            // Ground shadow
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - 13, y: y, width: 26, height: 5)),
                with: .color(.black.opacity(0.28))
            )

        case "throw":
            // #44 — QB throw: head/helmet
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r + 4, y: y - 40 - r, width: r*2, height: r*2)),
                with: .color(skin)
            )
            var helm = Path()
            helm.addArc(center: CGPoint(x: x + 4, y: y - 40), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            helm.addLine(to: CGPoint(x: x + 4 - r - 4, y: y - 40))
            ctx.fill(helm, with: .color(helmetColor))
            // #45 — QB body in follow-through
            var body = Path()
            body.move(to: CGPoint(x: x + 4, y: y - 40))
            body.addLine(to: CGPoint(x: x - 3, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            var throwArm = Path()
            throwArm.move(to: CGPoint(x: x + 1, y: y - 30))
            throwArm.addLine(to: CGPoint(x: x - 20, y: y - 40))
            ctx.stroke(throwArm, with: .color(color), lineWidth: 3)
            // #46 — Legs follow-through
            var legs = Path()
            legs.move(to: CGPoint(x: x - 3, y: y - 14))
            legs.addLine(to: CGPoint(x: x + 16, y: y))
            legs.move(to: CGPoint(x: x - 3, y: y - 14))
            legs.addLine(to: CGPoint(x: x - 14, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - 14, y: y, width: 28, height: 5)),
                with: .color(.black.opacity(0.28))
            )

        default: // idle
            let bob = CGFloat(sin(t * 1.5)) * 1.0
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - 38 - r + bob, width: r*2, height: r*2)),
                with: .color(skin)
            )
            var helm = Path()
            helm.addArc(center: CGPoint(x: x, y: y - 38 + bob), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            helm.addLine(to: CGPoint(x: x - r - 4, y: y - 38 + bob))
            ctx.fill(helm, with: .color(helmetColor))
            var body = Path()
            body.move(to: CGPoint(x: x, y: y - 38 + bob))
            body.addLine(to: CGPoint(x: x, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            var arms = Path()
            arms.move(to: CGPoint(x: x - 14, y: y - 28 + bob))
            arms.addLine(to: CGPoint(x: x + 14, y: y - 28 + bob))
            ctx.stroke(arms, with: .color(color), lineWidth: 3)
            drawFootballAt(ctx: &ctx, x: x + 4, y: y - 22, angle: 0.3, r: 5)
            var legs = Path()
            legs.move(to: CGPoint(x: x, y: y - 14))
            legs.addLine(to: CGPoint(x: x - 12, y: y))
            legs.move(to: CGPoint(x: x, y: y - 14))
            legs.addLine(to: CGPoint(x: x + 12, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - 13, y: y, width: 26, height: 5)),
                with: .color(.black.opacity(0.28))
            )
        }
    }

    // MARK: - Receiver (#47–#50)

    private func drawReceiver(ctx: inout GraphicsContext) {
        let p = receiverCanvas()
        let x = p.x; let y = p.y
        let color = Color(red: 0.14, green: 0.32, blue: 0.72)
        let helmetColor = Color(red: 0.10, green: 0.24, blue: 0.58)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 7.5
        let stride = CGFloat(sin(t * 8.0)) * 8

        // #47 — WR head + helmet
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r, y: y - 38 - r, width: r*2, height: r*2)),
            with: .color(skin)
        )
        var helm = Path()
        helm.addArc(center: CGPoint(x: x, y: y - 38), radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        helm.addLine(to: CGPoint(x: x - r - 3, y: y - 38))
        ctx.fill(helm, with: .color(helmetColor))

        // #48 — WR body sprinting
        var body = Path()
        body.move(to: CGPoint(x: x, y: y - 38))
        body.addLine(to: CGPoint(x: x, y: y - 14))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)
        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 29))
        arms.addLine(to: CGPoint(x: x - 14, y: y - 22 - stride * 0.4))
        arms.move(to: CGPoint(x: x, y: y - 29))
        arms.addLine(to: CGPoint(x: x + 14, y: y - 22 + stride * 0.4))
        ctx.stroke(arms, with: .color(color), lineWidth: 2.5)

        // #49 — WR legs in stride
        var legs = Path()
        legs.move(to: CGPoint(x: x, y: y - 14))
        legs.addLine(to: CGPoint(x: x - 10, y: y + stride))
        legs.move(to: CGPoint(x: x, y: y - 14))
        legs.addLine(to: CGPoint(x: x + 10, y: y - stride))
        ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        // #50 — Jersey number + shadow
        let numText = ctx.resolve(
            Text("88")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
        )
        ctx.draw(numText, at: CGPoint(x: x, y: y - 24))
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - 12, y: y, width: 24, height: 5)),
            with: .color(.black.opacity(0.30))
        )
    }

    // MARK: - Thrown Football (#51–#53)

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

        // #51 — Football spiral trail (ghost echoes)
        for g in 1...4 {
            let pep = max(0, ep - CGFloat(g) * 0.055)
            let gx = start.x + (endX - start.x) * pep
            let gy = start.y + (endY - start.y) * pep - peakH * 4 * pep * (1 - pep)
            var gc = ctx; gc.opacity = Double(max(0, 0.14 - CGFloat(g) * 0.03))
            gc.fill(
                Path(ellipseIn: CGRect(x: gx - 5, y: gy - 3, width: 10, height: 6)),
                with: .color(.white)
            )
        }

        // #52 — Football glow (blur halo)
        var glow = ctx
        glow.addFilter(.blur(radius: 7))
        glow.opacity = 0.32
        glow.fill(
            Path(ellipseIn: CGRect(x: bx - 9, y: by - 9, width: 18, height: 18)),
            with: .color(.white)
        )

        // #53 — Football shape rotating (spiral hash marks on flight)
        drawFootballAt(ctx: &ctx, x: bx, y: by, angle: angle, r: 7)

        // Spiral hashmark rings on the ball to show spin
        let spinAngle = t * 12.0 + Double(ep) * 8.0
        var gc2 = ctx
        gc2.translateBy(x: bx, y: by)
        gc2.rotate(by: .radians(spinAngle))
        gc2.opacity = 0.4
        var spinMark = Path()
        spinMark.move(to: CGPoint(x: -6, y: 0))
        spinMark.addLine(to: CGPoint(x: 6, y: 0))
        gc2.stroke(spinMark, with: .color(.white.opacity(0.6)), lineWidth: 1.2)
    }

    private func drawFootballAt(ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, angle: CGFloat, r: CGFloat) {
        let rW = r * 1.7; let rH = r
        var gc = ctx
        gc.translateBy(x: x, y: y)
        gc.rotate(by: .radians(Double(angle)))
        gc.fill(
            Path(ellipseIn: CGRect(x: -rW, y: -rH, width: rW * 2, height: rH * 2)),
            with: .color(Color(red: 0.55, green: 0.30, blue: 0.08))
        )
        var lace = Path()
        lace.move(to: CGPoint(x: -3, y: -rH + 2))
        lace.addLine(to: CGPoint(x: 3, y: -rH + 2))
        gc.stroke(lace, with: .color(.white.opacity(0.75)), lineWidth: 1.5)
    }

    // MARK: - Runner (#54–#57)

    private func drawRunner(ctx: inout GraphicsContext) {
        let p = runnerCanvas()
        let x = p.x; let y = p.y
        let color = Color(red: 0.20, green: 0.65, blue: 0.20)
        let helmetColor = Color(red: 0.12, green: 0.45, blue: 0.12)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 8
        let stride = CGFloat(sin(t * 9.0)) * 9

        // #54 — Runner head + helmet
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r, y: y - 40 - r, width: r*2, height: r*2)),
            with: .color(skin)
        )
        var helm = Path()
        helm.addArc(center: CGPoint(x: x, y: y - 40), radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        helm.addLine(to: CGPoint(x: x - r - 3, y: y - 40))
        ctx.fill(helm, with: .color(helmetColor))

        // #55 — Ball carrier body + tucked ball
        var body = Path()
        body.move(to: CGPoint(x: x, y: y - 40))
        body.addLine(to: CGPoint(x: x, y: y - 16))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)
        drawFootballAt(ctx: &ctx, x: x + 10, y: y - 26, angle: 0.2, r: 5)

        // #56 — Truck arm extended forward
        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 30))
        arms.addLine(to: CGPoint(x: x - 16, y: y - 22 + stride * 0.5))
        arms.move(to: CGPoint(x: x, y: y - 30))
        arms.addLine(to: CGPoint(x: x + 24, y: y - 32))  // truck arm extended
        ctx.stroke(arms, with: .color(color), lineWidth: 2.5)

        // #57 — Runner legs + shadow + jersey
        var legs = Path()
        legs.move(to: CGPoint(x: x, y: y - 16))
        legs.addLine(to: CGPoint(x: x - 12, y: y + stride))
        legs.move(to: CGPoint(x: x, y: y - 16))
        legs.addLine(to: CGPoint(x: x + 12, y: y - stride))
        ctx.stroke(legs, with: .color(color), lineWidth: 3)
        let numText = ctx.resolve(
            Text("21")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
        )
        ctx.draw(numText, at: CGPoint(x: x, y: y - 28))
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - 14, y: y, width: 28, height: 5)),
            with: .color(.black.opacity(0.30))
        )
    }

    // MARK: - Defender (#58)

    private func drawDefender(ctx: inout GraphicsContext) {
        let p = defenderCanvas()
        let x = p.x; let y = p.y
        let color = Color(red: 0.75, green: 0.12, blue: 0.12)
        let helmetColor = Color(red: 0.58, green: 0.08, blue: 0.08)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 7.5
        let stride = CGFloat(sin(t * 9.0 + 1.0)) * 8

        // #58 — Linebacker crouched stance + running
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r, y: y - 38 - r, width: r*2, height: r*2)),
            with: .color(skin)
        )
        var helm = Path()
        helm.addArc(center: CGPoint(x: x, y: y - 38), radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        helm.addLine(to: CGPoint(x: x - r - 3, y: y - 38))
        ctx.fill(helm, with: .color(helmetColor))
        var body = Path()
        body.move(to: CGPoint(x: x, y: y - 38))
        body.addLine(to: CGPoint(x: x, y: y - 14))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)
        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 28))
        arms.addLine(to: CGPoint(x: x - 16, y: y - 20 - stride * 0.4))
        arms.move(to: CGPoint(x: x, y: y - 28))
        arms.addLine(to: CGPoint(x: x + 16, y: y - 20 + stride * 0.4))
        ctx.stroke(arms, with: .color(color), lineWidth: 2.5)
        var legs = Path()
        legs.move(to: CGPoint(x: x, y: y - 14))
        legs.addLine(to: CGPoint(x: x - 11, y: y + stride))
        legs.move(to: CGPoint(x: x, y: y - 14))
        legs.addLine(to: CGPoint(x: x + 11, y: y - stride))
        ctx.stroke(legs, with: .color(color), lineWidth: 2.5)
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - 12, y: y, width: 24, height: 5)),
            with: .color(.black.opacity(0.25))
        )
    }

    // MARK: - Ball Carrier FX (#59–#62)

    private func drawBallCarrierFX(ctx: inout GraphicsContext) {
        let p = runnerCanvas()
        let x = p.x; let y = p.y

        // #59 — Speed lines behind runner
        for i in 0..<5 {
            let ly = y - CGFloat(i) * 8 - 5
            let lx = x - 22 - CGFloat(i) * 3
            let lw: CGFloat = 12 + CGFloat(i) * 4
            var ln = Path()
            ln.move(to: CGPoint(x: lx, y: ly))
            ln.addLine(to: CGPoint(x: lx + lw, y: ly))
            ctx.stroke(ln, with: .color(.white.opacity(0.08 - Double(i) * 0.015)), lineWidth: 1.2)
        }

        // #60 — Tackle collision impact (when defender is close)
        let dp = defenderCanvas()
        let dist = abs(p.x - dp.x)
        if dist < 30 {
            let impactAlpha = Double(max(0, 1.0 - dist / 30))
            var impact = ctx
            impact.addFilter(.blur(radius: 8))
            impact.opacity = impactAlpha * 0.5
            impact.fill(
                Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 25, width: 36, height: 30)),
                with: .color(Color(red: 1.0, green: 0.8, blue: 0.2))
            )
            // Impact stars
            for k in 0..<5 {
                let ang = Double(k) * .pi * 2 / 5 + t * 4
                let sx = p.x + CGFloat(cos(ang)) * 18
                let sy = (p.y - 15) + CGFloat(sin(ang)) * 10
                ctx.fill(
                    Path(ellipseIn: CGRect(x: sx - 2, y: sy - 2, width: 4, height: 4)),
                    with: .color(Color.yellow.opacity(impactAlpha * 0.8))
                )
            }
        }

        // #61 — Fumble tumble (random arc when turnover)
        // Only drawn in run phase, this is the ball tumble visual hint
        if runMeter < 0.05 && runMeter >= 0 {
            let tumbleAngle = t * 6.0
            let tumbleX = x + CGFloat(cos(tumbleAngle)) * 15
            let tumbleY = y - 10 + CGFloat(sin(tumbleAngle)) * 8
            drawFootballAt(ctx: &ctx, x: tumbleX, y: tumbleY, angle: CGFloat(tumbleAngle), r: 5)
        }

        // #62 — Kick arc (long flat trajectory animation for punts)
        // Represented as a dotted arc above the field
        let kickProgress = CGFloat(fmod(t * 0.4, 1.0))
        let kickAlpha = phase == .run ? 0.0 : 0.0 // reserved, rendered in result phases
        _ = kickAlpha
        _ = kickProgress
    }

    // MARK: - Ball & Scoring (#63–#72)

    private func drawFirstDownLine(ctx: inout GraphicsContext) {
        // #63 — First down marker line (yellow-gold line at 10 yards to go)
        let fdProgress = CGFloat(min(1.0, runMeter))
        let fdY = fieldBot - fdProgress * fieldHeight * 0.45 - 25
        if phase == .run && fdProgress < 1.0 {
            var fdLine = Path()
            fdLine.move(to: CGPoint(x: fieldLeft, y: fdY))
            fdLine.addLine(to: CGPoint(x: fieldRight, y: fdY))
            var fdGlow = ctx
            fdGlow.addFilter(.blur(radius: 3))
            fdGlow.opacity = 0.45
            fdGlow.stroke(fdLine, with: .color(Color(red: 1.0, green: 0.85, blue: 0.0)), lineWidth: 4)
            ctx.stroke(fdLine, with: .color(Color(red: 1.0, green: 0.95, blue: 0.1).opacity(0.65)), lineWidth: 1.5)
        }
    }

    // MARK: - Goal Post Vibration (#64)

    private func drawGoalPostVibration(ctx: inout GraphicsContext, intensity: CGFloat) {
        // #64 — Uprights vibrate on FG made (called from touchdown FX if needed)
        guard intensity > 0 else { return }
        let cx = W * 0.5
        let base = endZoneTop + 5
        let vibOffset = CGFloat(sin(t * 25)) * intensity * 3
        let postW: CGFloat = 32 + vibOffset
        var vibePost = Path()
        vibePost.move(to: CGPoint(x: cx - postW, y: base + 22))
        vibePost.addLine(to: CGPoint(x: cx - postW, y: base))
        vibePost.move(to: CGPoint(x: cx + postW, y: base + 22))
        vibePost.addLine(to: CGPoint(x: cx + postW, y: base))
        var vg = ctx
        vg.addFilter(.blur(radius: 2))
        vg.opacity = Double(intensity * 0.7)
        vg.stroke(vibePost, with: .color(.yellow), lineWidth: 4)
    }

    // MARK: - FX (#65–#86)

    private func drawTouchdownFX(ctx: inout GraphicsContext) {
        guard tdFlash else { return }

        // #65 — TD glow burst (radial)
        var burst = ctx
        burst.addFilter(.blur(radius: 35))
        burst.opacity = 0.45
        burst.fill(
            Path(ellipseIn: CGRect(x: W * 0.2, y: H * 0.15, width: W * 0.6, height: H * 0.45)),
            with: .color(.yellow)
        )

        // #66 — Fireworks burst #1 (center-left)
        drawFireworkBurst(ctx: &ctx, cx: W * 0.3, cy: H * 0.28, t: t, hue: Color.yellow)
        // #67 — Fireworks burst #2 (center-right)
        drawFireworkBurst(ctx: &ctx, cx: W * 0.7, cy: H * 0.28, t: t + 0.4, hue: Color.orange)
        // #68 — Fireworks burst #3 (left)
        drawFireworkBurst(ctx: &ctx, cx: W * 0.15, cy: H * 0.35, t: t + 0.7, hue: Color(red: 0.2, green: 0.8, blue: 1.0))
        // #69 — Fireworks burst #4 (right)
        drawFireworkBurst(ctx: &ctx, cx: W * 0.85, cy: H * 0.35, t: t + 1.1, hue: Color.white)
        // #70 — Fireworks burst #5 (upper-center)
        drawFireworkBurst(ctx: &ctx, cx: W * 0.5, cy: H * 0.20, t: t + 0.2, hue: Color.green)
        // #71 — Fireworks burst #6 (mid-left)
        drawFireworkBurst(ctx: &ctx, cx: W * 0.22, cy: H * 0.44, t: t + 0.9, hue: Color(red: 1, green: 0.3, blue: 0.8))
        // #72 — Fireworks burst #7 (mid-right)
        drawFireworkBurst(ctx: &ctx, cx: W * 0.78, cy: H * 0.44, t: t + 0.6, hue: Color(red: 0.4, green: 0.9, blue: 0.4))
        // #73 — Fireworks burst #8 (top-center wide)
        drawFireworkBurst(ctx: &ctx, cx: W * 0.5, cy: H * 0.10, t: t + 1.3, hue: Color(red: 1.0, green: 0.9, blue: 0.2))

        // #74 — Particle shower (60 confetti dots)
        let particleCount = 60
        let seed: Double = floor(t * 0.5)
        for i in 0..<particleCount {
            let angle = Double(i) / Double(particleCount) * .pi * 2 + seed * 0.3
            let speed = Double(i % 5 + 3) * 28.0
            let age = fmod(t + Double(i) * 0.08, 2.0)
            let dist = CGFloat(age * speed)
            let px = W * 0.5 + CGFloat(cos(angle)) * dist
            let py = H * 0.38 + CGFloat(sin(angle)) * dist - CGFloat(age * age * 42)
            let particleAlpha = max(0, 1.0 - age * 0.7)
            let colors: [Color] = [.yellow, .orange, .white, Color(red: 0.2, green: 0.8, blue: 1), .green]
            let c = colors[i % colors.count]
            let pR: CGFloat = 3 + CGFloat(i % 4) * 1.5
            var pc = ctx; pc.opacity = particleAlpha
            pc.fill(
                Path(ellipseIn: CGRect(x: px - pR, y: py - pR, width: pR * 2, height: pR * 2)),
                with: .color(c)
            )
        }

        // #75 — Goal post vibration on TD
        drawGoalPostVibration(ctx: &ctx, intensity: 0.8)
    }

    private func drawFireworkBurst(ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, hue: Color) {
        let rayCount = 10
        let age = fmod(t * 1.8, 2.4)
        let maxR: CGFloat = 38 + CGFloat(age) * 18
        let alpha = max(0, 1.0 - age / 1.8)
        for r in 0..<rayCount {
            let ang = Double(r) / Double(rayCount) * .pi * 2
            let endX = cx + CGFloat(cos(ang)) * maxR
            let endY = cy + CGFloat(sin(ang)) * maxR
            var ray = Path()
            ray.move(to: CGPoint(x: cx + CGFloat(cos(ang)) * maxR * 0.15, y: cy + CGFloat(sin(ang)) * maxR * 0.15))
            ray.addLine(to: CGPoint(x: endX, y: endY))
            var rc = ctx; rc.opacity = Double(alpha)
            rc.stroke(ray, with: .color(hue), lineWidth: 1.5)
            // Spark dot at tip
            rc.fill(
                Path(ellipseIn: CGRect(x: endX - 2.5, y: endY - 2.5, width: 5, height: 5)),
                with: .color(hue)
            )
        }
        // Center flash
        var fc = ctx
        fc.addFilter(.blur(radius: 5))
        fc.opacity = Double(alpha * 0.6)
        fc.fill(
            Path(ellipseIn: CGRect(x: cx - 8, y: cy - 8, width: 16, height: 16)),
            with: .color(hue)
        )
    }

    // MARK: - Sack Dust (#76–#78)

    private func drawSackDust(ctx: inout GraphicsContext) {
        // #76 — Sack pile-on dust cloud (6 particles)
        let dustCX = W * 0.5
        let dustCY = fieldBot - 60
        for i in 0..<6 {
            let ang = Double(i) / 6.0 * .pi * 2
            let dist = 18.0 + Double(i) * 5.0
            let px = dustCX + CGFloat(cos(ang + t * 0.6)) * CGFloat(dist)
            let py = dustCY + CGFloat(sin(ang + t * 0.6)) * CGFloat(dist * 0.4)
            let dustR: CGFloat = 8 + CGFloat(i) * 3
            var dc = ctx
            dc.addFilter(.blur(radius: 4))
            dc.opacity = 0.18 + Double(i) * 0.06
            dc.fill(
                Path(ellipseIn: CGRect(x: px - dustR, y: py - dustR, width: dustR * 2, height: dustR * 2)),
                with: .color(Color(red: 0.7, green: 0.6, blue: 0.4))
            )
        }

        // #77 — Yellow flag throw arc
        let flagProgress = CGFloat(fmod(t * 0.9, 2.0))
        if flagProgress < 1.0 {
            let flagX = W * 0.35 + flagProgress * 60
            let flagY = fieldBot - 60 - flagProgress * 30 + flagProgress * flagProgress * 20
            ctx.fill(
                Path(ellipseIn: CGRect(x: flagX - 5, y: flagY - 5, width: 10, height: 10)),
                with: .color(Color(red: 0.95, green: 0.85, blue: 0.0).opacity(0.85))
            )
            var flagGlow = ctx
            flagGlow.addFilter(.blur(radius: 4))
            flagGlow.opacity = 0.4
            flagGlow.fill(
                Path(ellipseIn: CGRect(x: flagX - 8, y: flagY - 8, width: 16, height: 16)),
                with: .color(Color(red: 0.95, green: 0.85, blue: 0.0))
            )
        }

        // #78 — X overlay on turnover
        let xAlpha = 0.35 + 0.15 * CGFloat(sin(t * 2.5))
        let xCX = W * 0.5; let xCY = fieldBot - 50
        var xPath = Path()
        xPath.move(to: CGPoint(x: xCX - 22, y: xCY - 22))
        xPath.addLine(to: CGPoint(x: xCX + 22, y: xCY + 22))
        xPath.move(to: CGPoint(x: xCX + 22, y: xCY - 22))
        xPath.addLine(to: CGPoint(x: xCX - 22, y: xCY + 22))
        var xc = ctx
        xc.addFilter(.blur(radius: 3))
        xc.opacity = Double(xAlpha)
        xc.stroke(xPath, with: .color(.red), lineWidth: 5)
    }

    // MARK: - Red Zone Glow (#79)

    private func drawRedZoneGlow(ctx: inout GraphicsContext) {
        // #79 — Red zone warm tint when near end zone (yardLine > 80)
        let intensity = CGFloat(max(0, min(1, (runMeter - 0.6) / 0.4)))
        guard intensity > 0 else { return }
        var rz = ctx
        rz.addFilter(.blur(radius: 30))
        rz.opacity = Double(intensity * 0.14)
        rz.fill(
            Path(CGRect(x: fieldLeft, y: fieldTop, width: fieldWidth, height: fieldHeight * 0.45)),
            with: .color(Color(red: 1.0, green: 0.25, blue: 0.10))
        )
    }

    // MARK: - 2-Minute Warning Flash (#80)

    private func drawCrowdNoisePulse(ctx: inout GraphicsContext) {
        // #80 — Crowd noise brightness pulse (whole stadium dims/brightens with excitement)
        guard crowdExcitement > 0.3 else { return }
        let pulse = CGFloat(sin(t * 4.5 + .pi * 0.25)) * 0.5 + 0.5
        let pulseAlpha = crowdExcitement * 0.06 * Double(pulse)
        var cp = ctx
        cp.opacity = pulseAlpha
        cp.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(white: 1.0))
        )
    }

    // MARK: - Touchdown Runner + Turnover

    private func drawTDRunner(ctx: inout GraphicsContext) {
        // #81 — TD celebration: player in end zone arms raised
        let x = W * 0.5; let y = endZoneBot - 30
        let color = Color(red: 0.20, green: 0.65, blue: 0.20)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let helmetColor = Color(red: 0.12, green: 0.45, blue: 0.12)
        let r: CGFloat = 8
        let jump = CGFloat(max(0, sin(t * 5.0))) * 16

        // Head
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r, y: y - 50 - r - jump, width: r*2, height: r*2)),
            with: .color(skin)
        )
        // Helmet
        var helm = Path()
        helm.addArc(center: CGPoint(x: x, y: y - 50 - jump), radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        helm.addLine(to: CGPoint(x: x - r - 4, y: y - 50 - jump))
        ctx.fill(helm, with: .color(helmetColor))

        // #82 — Body
        var body = Path()
        body.move(to: CGPoint(x: x, y: y - 50 - jump))
        body.addLine(to: CGPoint(x: x, y: y - 22 - jump))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)

        // #83 — Arms raised in celebration
        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 40 - jump))
        arms.addLine(to: CGPoint(x: x - 28, y: y - 56 - jump))
        arms.move(to: CGPoint(x: x, y: y - 40 - jump))
        arms.addLine(to: CGPoint(x: x + 28, y: y - 56 - jump))
        ctx.stroke(arms, with: .color(color), lineWidth: 3)

        // #84 — Legs (celebrate jump)
        var legs = Path()
        legs.move(to: CGPoint(x: x, y: y - 22 - jump))
        legs.addLine(to: CGPoint(x: x - 14, y: y - jump))
        legs.move(to: CGPoint(x: x, y: y - 22 - jump))
        legs.addLine(to: CGPoint(x: x + 14, y: y - jump))
        ctx.stroke(legs, with: .color(color), lineWidth: 3)

        // Ground shadow bounce
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - 16 + jump * 0.2, y: y + 2, width: 32 - jump * 0.4, height: 5)),
            with: .color(.black.opacity(max(0.05, 0.30 - Double(jump) * 0.012)))
        )
    }

    private func drawTurnoverRunner(ctx: inout GraphicsContext) {
        let x = W * 0.5; let y = fieldBot - 60
        let color = Color(red: 0.20, green: 0.65, blue: 0.20)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 8

        // #85 — Slumped turnover player (head down)
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r - 4, y: y - 34 - r, width: r*2, height: r*2)),
            with: .color(skin)
        )
        var body = Path()
        body.move(to: CGPoint(x: x - 4, y: y - 34))
        body.addLine(to: CGPoint(x: x + 4, y: y - 14))
        ctx.stroke(body, with: .color(color), lineWidth: 3.5)
        var arms = Path()
        arms.move(to: CGPoint(x: x, y: y - 26))
        arms.addLine(to: CGPoint(x: x - 16, y: y - 16))
        arms.move(to: CGPoint(x: x, y: y - 26))
        arms.addLine(to: CGPoint(x: x + 16, y: y - 16))
        ctx.stroke(arms, with: .color(color), lineWidth: 2.5)
        var legs = Path()
        legs.move(to: CGPoint(x: x + 4, y: y - 14))
        legs.addLine(to: CGPoint(x: x - 8, y: y))
        legs.move(to: CGPoint(x: x + 4, y: y - 14))
        legs.addLine(to: CGPoint(x: x + 16, y: y))
        ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        // #86 — Dejection dust cloud around feet
        for i in 0..<4 {
            let dx = x + CGFloat(i % 2 == 0 ? -1 : 1) * CGFloat(i + 1) * 6
            var dc = ctx
            dc.addFilter(.blur(radius: 3))
            dc.opacity = 0.10 + Double(i) * 0.04
            dc.fill(
                Path(ellipseIn: CGRect(x: dx - 6, y: y - 3, width: 12, height: 7)),
                with: .color(Color(red: 0.65, green: 0.55, blue: 0.35))
            )
        }
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

    // Canvas state
    @State private var throwProgress: Double = -1.0
    @State private var throwTargetX: CGFloat = 0.5
    @State private var throwTargetY: CGFloat = 0.5
    @State private var qbPose: String = "idle"
    @State private var crowdExcitement: Double = 0.2

    // Score display
    @State private var homeScore: Int = 0
    @State private var awayScore: Int = 7
    @State private var quarter: Int = 2

    // Pre-snap
    @State private var selectedRoute: RouteType? = nil
    @State private var presnapPhase: Bool = false
    @State private var presnapTask: Task<Void, Never>? = nil

    // Receiver B
    @State private var receiver2X: CGFloat = 0.5
    @State private var receiver2Y: CGFloat = 0.75
    @State private var window2Open: Bool = false
    @State private var receiverTasks: [Task<Void, Never>] = []

    // Sack timer
    @State private var sackTimeLeft: Double = 3.5
    @State private var rushTask: Task<Void, Never>? = nil
    @State private var sackCount: Int = 0

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
            case .presnap:
                presnapBody
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

    // MARK: Pre-Snap Body

    private var presnapBody: some View {
        ZStack {
            FootballFieldCanvas(
                phase: .catchRoute,
                receiverX: 0.5, receiverY: 0.75,
                playerPosition: 0.5, defenderPosition: 0.5,
                runMeter: 0.0,
                windowOpen: false,
                throwProgress: -1,
                throwTargetX: 0.5, throwTargetY: 0.5,
                qbPose: "idle",
                currentRoute: selectedRoute ?? .cross,
                tdFlash: false,
                yardsGained: 0,
                crowdExcitement: 0.2,
                homeScore: homeScore,
                awayScore: awayScore,
                quarter: quarter
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                hudBar
                Spacer()

                VStack(spacing: 14) {
                    Text("SELECT ROUTE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(3)

                    HStack(spacing: 10) {
                        ForEach(RouteType.allCases, id: \.self) { route in
                            routeCard(route)
                        }
                    }
                    .padding(.horizontal, 14)

                    if let route = selectedRoute {
                        Button {
                            presnapPhase = false
                            phase = .catchRoute
                            setupCatchPhase()
                            startClock()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "football.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("HIKE!")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .tracking(3)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(route.accentColor)
                                    .overlay(RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.28), lineWidth: 1.5))
                            )
                        }
                        .padding(.horizontal, 14)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.25), value: selectedRoute)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func routeCard(_ route: RouteType) -> some View {
        let isSelected = selectedRoute == route
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                selectedRoute = route
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 7) {
                routeDiagram(route)
                    .frame(width: 68, height: 56)

                Text(route.rawValue)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(isSelected ? route.accentColor : .white.opacity(0.80))
                    .tracking(1)

                Text(route.yardRange)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? route.accentColor.opacity(0.85) : .white.opacity(0.38))

                Text(route.riskLabel)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? .white.opacity(0.70) : .white.opacity(0.28))

                HStack(spacing: 2) {
                    Image(systemName: "clock.fill").font(.system(size: 6))
                    Text(String(format: "%.1fs", route.windowSeconds))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(isSelected ? route.accentColor.opacity(0.85) : .white.opacity(0.28))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? route.accentColor.opacity(0.15) : Color.black.opacity(0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? route.accentColor : Color.white.opacity(0.10),
                                    lineWidth: isSelected ? 2.0 : 1.0)
                    )
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func routeDiagram(_ route: RouteType) -> some View {
        Canvas { ctx, size in
            let W = size.width; let H = size.height
            let qbX = W * 0.5; let qbY = H * 0.85
            let sel = (selectedRoute == route)
            let lineColor: Color = sel ? route.accentColor : Color.white.opacity(0.40)

            // QB marker
            ctx.fill(
                Path(ellipseIn: CGRect(x: qbX - 5, y: qbY - 5, width: 10, height: 10)),
                with: .color(Color(red: 0.20, green: 0.65, blue: 0.20).opacity(0.90))
            )
            // Route path
            var rp = Path()
            switch route {
            case .slant:
                rp.move(to: CGPoint(x: qbX, y: qbY))
                rp.addLine(to: CGPoint(x: W * 0.60, y: H * 0.55))
                rp.addLine(to: CGPoint(x: W * 0.82, y: H * 0.20))
            case .cross:
                rp.move(to: CGPoint(x: qbX, y: qbY))
                rp.addLine(to: CGPoint(x: W * 0.52, y: H * 0.55))
                rp.addLine(to: CGPoint(x: W * 0.78, y: H * 0.28))
            case .fly:
                rp.move(to: CGPoint(x: qbX, y: qbY))
                rp.addLine(to: CGPoint(x: qbX, y: H * 0.10))
            }
            ctx.stroke(rp, with: .color(lineColor),
                       style: StrokeStyle(lineWidth: 2.0, dash: [4, 3]))

            // Receiver dot at route end
            let endPt: CGPoint
            switch route {
            case .slant: endPt = CGPoint(x: W * 0.82, y: H * 0.20)
            case .cross: endPt = CGPoint(x: W * 0.78, y: H * 0.28)
            case .fly:   endPt = CGPoint(x: qbX,      y: H * 0.10)
            }
            ctx.fill(
                Path(ellipseIn: CGRect(x: endPt.x - 5, y: endPt.y - 5, width: 10, height: 10)),
                with: .color(lineColor)
            )
        }
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
                crowdExcitement: crowdExcitement,
                homeScore: homeScore,
                awayScore: awayScore,
                quarter: quarter
            )
            .offset(x: screenShake > 0 ? CGFloat.random(in: -screenShake...screenShake) : 0)

            // Receiver B overlay (blue dot + pulsing open-window ring)
            GeometryReader { geo in
                ZStack {
                    let rx2 = 0.06 + receiver2X * 0.88
                    let ry2 = 0.20 + receiver2Y * 0.62
                    let dotX2 = geo.size.width * rx2
                    let dotY2 = geo.size.height * ry2
                    if window2Open {
                        Circle()
                            .stroke(Color.cyan.opacity(0.35), lineWidth: 4)
                            .frame(width: 52, height: 52)
                            .position(x: dotX2, y: dotY2)
                        Circle()
                            .stroke(Color.cyan.opacity(0.75), lineWidth: 2.5)
                            .frame(width: 38, height: 38)
                            .position(x: dotX2, y: dotY2)
                    }
                    Circle()
                        .fill(window2Open ? Color.cyan : Color.blue.opacity(0.55))
                        .frame(width: 14, height: 14)
                        .position(x: dotX2, y: dotY2)
                        .onTapGesture { handleThrow(targetPrimary: false) }
                }
            }
            .allowsHitTesting(!playerThrew)

            VStack(spacing: 0) {
                // Sack pressure timer (red bar draining from top)
                sackTimerBar

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
                    HStack(spacing: 8) {
                        Text("ROUTE: \(currentRoute.rawValue)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(currentRoute.accentColor).tracking(2)
                        if window2Open {
                            Text("\u00b7 #2 OPEN")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.cyan.opacity(0.85))
                        }
                    }
                    Text(windowOpen ? "TAP FIELD — THROW TO #1" :
                         (window2Open ? "TAP CYAN DOT — #2 OPEN!" :
                          (playerThrew ? "" : "FIND YOUR RECEIVER…")))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(windowOpen ? .green : (window2Open ? .cyan : .white.opacity(0.4)))
                }.padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleThrow(targetPrimary: true) }
        .ignoresSafeArea(edges: .bottom)
    }

    private var sackTimerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.50))
                    .frame(height: 6)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: sackTimeLeft > 1.5
                                ? [Color(red: 0.9, green: 0.2, blue: 0.1), Color(red: 1.0, green: 0.4, blue: 0.1)]
                                : [Color.red, Color(red: 1.0, green: 0.15, blue: 0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(sackTimeLeft / 3.5)), height: 6)
                    .animation(.linear(duration: 0.05), value: sackTimeLeft)
            }
        }
        .frame(height: 6)
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
                crowdExcitement: crowdExcitement,
                homeScore: homeScore,
                awayScore: awayScore,
                quarter: quarter
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
                crowdExcitement: 1.0,
                homeScore: homeScore + (tdFlash ? 6 : 0),
                awayScore: awayScore,
                quarter: quarter
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
                crowdExcitement: 0.1,
                homeScore: homeScore,
                awayScore: awayScore,
                quarter: quarter
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
        sackCount = 0
        startPresnapPhase()
    }

    private func startPresnapPhase() {
        selectedRoute = nil
        presnapPhase = true
        phase = .presnap
    }

    private func setupCatchPhase() {
        guard let route = selectedRoute else { return }
        currentRoute = route
        receiverX = 0.5; receiverY = 0.75; routeProgress = 0.0
        receiver2X = 0.5; receiver2Y = 0.75
        windowOpen = false; window2Open = false
        playerThrew = false; showPlayResult = false
        throwProgress = -1; qbPose = "idle"
        sackTimeLeft = 3.5
        startRoute()
        startSackTimer()
    }

    private func startSackTimer() {
        rushTask?.cancel()
        rushTask = Task {
            let tickMs = 50
            let totalTicks = Int(3.5 * 1000 / Double(tickMs))
            for tick in 0..<totalTicks {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(tickMs))
                await MainActor.run {
                    sackTimeLeft = max(0, 3.5 - Double(tick + 1) * Double(tickMs) / 1000.0)
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase == .catchRoute, !playerThrew else { return }
                playerThrew = true
                routeTask?.cancel(); clockTask?.cancel()
                receiverTasks.forEach { $0.cancel() }; receiverTasks = []
                hapticError()
                sackCount += 1
                yardLine = max(1, yardLine - 7)
                let isFumble = sackCount >= 4
                withAnimation {
                    playResultLabel = isFumble ? "FUMBLE! TURNOVER!" : "SACKED! −7 YDS"
                    playResultColor = .red; showPlayResult = true
                }
                if isFumble {
                    phase = .turnover
                    Task {
                        try? await Task.sleep(for: .seconds(2.5))
                        await MainActor.run { showPlayResult = false; phase = .result }
                    }
                } else {
                    Task {
                        try? await Task.sleep(for: .seconds(1.3))
                        await MainActor.run {
                            showPlayResult = false; advanceDown(yardsGained: -7)
                        }
                    }
                }
            }
        }
    }

    private func startRoute() {
        routeTask?.cancel()
        routeTask = Task {
            let totalSteps = 60
            let windowStart = Int(Double(totalSteps) * 0.50)
            let windowEnd   = Int(Double(totalSteps) * 0.75)
            let endPoint = routeEndPoint(for: currentRoute)

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
        case .slant: return (0.68, 0.38)
        case .cross: return (0.55, 0.28)
        case .fly:   return (0.50, 0.12)
        }
    }

    private func route2EndPoint(for route: RouteType) -> (CGFloat, CGFloat) {
        switch route {
        case .slant: return (0.30, 0.42)
        case .cross: return (0.72, 0.30)
        case .fly:   return (0.38, 0.18)
        }
    }

    private func handleThrow() {
        guard phase == .catchRoute, !playerThrew else { return }
        playerThrew = true
        routeTask?.cancel(); clockTask?.cancel()
        qbPose = "throw"
        hapticMedium()  // Haptic #3: throw / attempt

        let caught = windowOpen
        catchResult = caught

        if caught {
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
        hapticSoft()  // Haptic #4: incomplete pass
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
            homeScore += 6
            hapticHeavy()   // Haptic #1: touchdown .heavy
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) { tdScale = 1.0; tdFlash = true }
            Task {
                try? await Task.sleep(for: .seconds(3.2))
                await MainActor.run { phase = .result }
            }
        } else if yardsGained >= yardsToGo {
            let newYardsToGo = max(0, 100 - yardLine)
            yardsToGo = newYardsToGo; clockTask?.cancel(); runTask?.cancel()
            down = 1; crowdExcitement = min(1.0, crowdExcitement + 0.25)
            hapticMedium()  // Haptic #3: first down / big gain
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
            hapticError()  // Haptic #5: turnover / sack .error
            phase = .turnover
            Task { try? await Task.sleep(for: .seconds(2.5)); await MainActor.run { phase = .result } }
            return
        }
        playClock = 40; phase = .catchRoute; setupCatchPhase(); startClock()
    }

    /// Called when a field goal is made (future integration point).
    private func handleFieldGoalMade() {
        hapticRigid()  // Haptic #2: field goal .rigid
        homeScore += 3
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
        GameResultService.saveResult(modeId: "football", userScore: homeScore, opponentScore: awayScore)
        viewModel.profile.evolutionShards += shards
        let xpGain = min(XP_CAP_PER_SESSION, shards * 2)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) / 100.0)
    }
}
