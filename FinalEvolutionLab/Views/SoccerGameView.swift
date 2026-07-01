import SwiftUI
import UIKit

// MARK: - Enums / Data

private enum SoccerPhase { case ready, shooting, result }

private struct SoccerRoundResult {
    let playerScored: Bool
    let aiScored: Bool
    let aimValue: Double
    let power: Double
    let goalieDirection: Int
}

// MARK: - Stadium Goal Canvas

private struct SoccerStadiumCanvas: View {
    let aimValue: Double
    let power: Double
    let shotFired: Bool
    let ballProgress: Double
    let goalieDir: Int
    let goalieDived: Bool
    let playerScored: Bool
    let lastScoreTime: Double
    let crowdExcitement: Double
    let showRedCard: Bool
    let showYellowCard: Bool
    let isTackle: Bool
    let lastTackleTime: Double
    let isRaining: Bool
    let isPenaltyAwarded: Bool
    let isCorner: Bool
    let lastCornerTime: Double

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = SoccerFieldDrawer(
                    size: size, t: t,
                    aimValue: aimValue, power: power,
                    shotFired: shotFired, ballProgress: ballProgress,
                    goalieDir: goalieDir, goalieDived: goalieDived,
                    playerScored: playerScored,
                    lastScoreTime: lastScoreTime,
                    crowdExcitement: crowdExcitement,
                    showRedCard: showRedCard,
                    showYellowCard: showYellowCard,
                    isTackle: isTackle,
                    lastTackleTime: lastTackleTime,
                    isRaining: isRaining,
                    isPenaltyAwarded: isPenaltyAwarded,
                    isCorner: isCorner,
                    lastCornerTime: lastCornerTime
                )
                d.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Soccer Field Drawer

private struct SoccerFieldDrawer {
    let size: CGSize
    let t: Double
    let aimValue: Double
    let power: Double
    let shotFired: Bool
    let ballProgress: Double
    let goalieDir: Int
    let goalieDived: Bool
    let playerScored: Bool
    let lastScoreTime: Double
    let crowdExcitement: Double
    let showRedCard: Bool
    let showYellowCard: Bool
    let isTackle: Bool
    let lastTackleTime: Double
    let isRaining: Bool
    let isPenaltyAwarded: Bool
    let isCorner: Bool
    let lastCornerTime: Double

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var goalLeft: CGFloat  { W * 0.12 }
    var goalRight: CGFloat { W * 0.88 }
    var goalWidth: CGFloat { goalRight - goalLeft }
    var goalTop: CGFloat   { H * 0.20 }
    var goalBot: CGFloat   { H * 0.68 }
    var goalMidY: CGFloat  { (goalTop + goalBot) * 0.5 }
    var penaltySpotY: CGFloat { H * 0.90 }
    var penaltySpotX: CGFloat { W * 0.5 }

    func ballTarget() -> CGPoint {
        let tx = goalLeft + CGFloat((aimValue * 0.5 + 0.5)) * goalWidth
        let ty = goalBot - CGFloat(power / 100.0) * (goalBot - goalTop - 24) - 12
        return CGPoint(x: tx, y: ty)
    }

    mutating func render(ctx: inout GraphicsContext) {
        // MARK: Pitch BG (#1–#12)
        drawPitchStripes(ctx: &ctx)
        drawPitchLines(ctx: &ctx)
        drawCornerArcs(ctx: &ctx)
        drawGoalBox(ctx: &ctx)
        drawGoalNetBackground(ctx: &ctx)
        drawGoalPosts(ctx: &ctx)
        drawCornerFlags(ctx: &ctx)

        // MARK: Stadium (#13–#24)
        drawStadiumSky(ctx: &ctx)
        drawFloodlightTowers(ctx: &ctx)
        drawCrowdTiers(ctx: &ctx)
        drawScoreboardEnd(ctx: &ctx)
        drawSponsorBoards(ctx: &ctx)
        drawTVCameraPlatform(ctx: &ctx)
        drawVARScreenIndicator(ctx: &ctx)

        // MARK: Player figures (#25–#48)
        drawPlayerFigure(ctx: &ctx)
        drawGoalie(ctx: &ctx)
        drawFreeKickWall(ctx: &ctx)

        // MARK: Ball & scoring (#49–#64)
        if !shotFired {
            drawPenaltySpotHighlight(ctx: &ctx)
            drawAimIndicator(ctx: &ctx)
        }
        drawBall(ctx: &ctx)
        if playerScored && lastScoreTime > 0 && t - lastScoreTime < 1.5 {
            drawGoalCelebrationBurst(ctx: &ctx)
            drawNetRipple(ctx: &ctx)
            drawGoalFlash(ctx: &ctx)
        }
        drawOffsideFlag(ctx: &ctx)

        // MARK: Atmosphere (#65–#78)
        drawUltrasSection(ctx: &ctx)
        drawSmokeFlare(ctx: &ctx)
        if isPenaltyAwarded { drawVARCheckFlash(ctx: &ctx) }
        drawExtraTimeBoard(ctx: &ctx)

        // MARK: FX (#79–#88)
        if isRaining { drawRainParticles(ctx: &ctx) }
        if isTackle && t - lastTackleTime < 0.8 { drawMudSplatter(ctx: &ctx) }
        if showRedCard { drawCardFlash(ctx: &ctx, isRed: true) }
        if showYellowCard { drawCardFlash(ctx: &ctx, isRed: false) }
        drawInjuryTimeClock(ctx: &ctx)
        drawCrowdChantWave(ctx: &ctx)
    }

    // ─────────────────────────────────────────────
    // MARK: #1–#12 Pitch BG
    // ─────────────────────────────────────────────

    private func drawPitchStripes(ctx: inout GraphicsContext) {
        // #1 — base pitch fill
        ctx.fill(
            Path(CGRect(x: 0, y: goalBot, width: W, height: H - goalBot)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.08, green: 0.32, blue: 0.08), Color(red: 0.04, green: 0.18, blue: 0.04)]),
                startPoint: CGPoint(x: W * 0.5, y: goalBot),
                endPoint: CGPoint(x: W * 0.5, y: H)
            )
        )
        // #2 — alternating mow strips (8 strips)
        let stripeCount = 8
        let stripeW = (goalRight - goalLeft) / CGFloat(stripeCount)
        for s in 0..<stripeCount {
            let sx = goalLeft + CGFloat(s) * stripeW
            if s % 2 == 0 {
                ctx.fill(
                    Path(CGRect(x: sx, y: goalBot, width: stripeW, height: H - goalBot)),
                    with: .color(Color(white: 1).opacity(0.04))
                )
            }
        }
        // #3 — perspective darkening near top of pitch
        ctx.fill(
            Path(CGRect(x: 0, y: goalBot, width: W, height: (H - goalBot) * 0.15)),
            with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.22), Color.clear]),
                startPoint: CGPoint(x: W * 0.5, y: goalBot),
                endPoint: CGPoint(x: W * 0.5, y: goalBot + (H - goalBot) * 0.15)
            )
        )
    }

    private func drawPitchLines(ctx: inout GraphicsContext) {
        let lw: CGFloat = 1.5
        let lineColor = Color.white.opacity(0.32)

        // #4 — goal line
        ctx.fill(
            Path(CGRect(x: goalLeft - 4, y: goalBot - 2, width: goalWidth + 8, height: 3)),
            with: .color(.white.opacity(0.65))
        )
        // #5 — penalty area box
        let boxW = W * 0.55; let boxLeft = (W - boxW) / 2
        var boxPath = Path()
        boxPath.move(to: CGPoint(x: boxLeft, y: goalBot))
        boxPath.addLine(to: CGPoint(x: boxLeft, y: H * 0.82))
        boxPath.addLine(to: CGPoint(x: boxLeft + boxW, y: H * 0.82))
        boxPath.addLine(to: CGPoint(x: boxLeft + boxW, y: goalBot))
        ctx.stroke(boxPath, with: .color(lineColor), lineWidth: lw)

        // #6 — goal area (6-yard box)
        let innerBoxW = W * 0.28; let innerLeft = (W - innerBoxW) / 2
        var innerBox = Path()
        innerBox.move(to: CGPoint(x: innerLeft, y: goalBot))
        innerBox.addLine(to: CGPoint(x: innerLeft, y: H * 0.74))
        innerBox.addLine(to: CGPoint(x: innerLeft + innerBoxW, y: H * 0.74))
        innerBox.addLine(to: CGPoint(x: innerLeft + innerBoxW, y: goalBot))
        ctx.stroke(innerBox, with: .color(lineColor), lineWidth: lw)

        // #7 — penalty arc
        var arc = Path()
        arc.addArc(center: CGPoint(x: W * 0.5, y: goalBot),
                   radius: W * 0.16,
                   startAngle: .degrees(22), endAngle: .degrees(158), clockwise: false)
        ctx.stroke(arc, with: .color(lineColor), lineWidth: lw)

        // #8 — center circle (partial, foreshortened at top)
        var circle = Path()
        circle.addArc(center: CGPoint(x: W * 0.5, y: H * 0.99),
                      radius: W * 0.32,
                      startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        ctx.stroke(circle, with: .color(lineColor.opacity(0.5)), lineWidth: lw)
    }

    private func drawCornerArcs(ctx: inout GraphicsContext) {
        // #9 — corner arc marks (4 corners, simplified at bottom)
        let corners: [(CGFloat, CGFloat, Double, Double)] = [
            (goalLeft, goalBot, 270, 360),
            (goalRight, goalBot, 180, 270)
        ]
        for (cx, cy, startDeg, endDeg) in corners {
            var p = Path()
            p.addArc(center: CGPoint(x: cx, y: cy),
                     radius: 12,
                     startAngle: .degrees(startDeg),
                     endAngle: .degrees(endDeg),
                     clockwise: false)
            ctx.stroke(p, with: .color(.white.opacity(0.30)), lineWidth: 1.5)
        }
    }

    private func drawGoalBox(ctx: inout GraphicsContext) {
        // #10 — goal net background fill
        ctx.fill(
            Path(CGRect(x: goalLeft, y: goalTop, width: goalWidth, height: goalBot - goalTop)),
            with: .color(Color(white: 0.04))
        )
    }

    private func drawGoalNetBackground(ctx: inout GraphicsContext) {
        let netColor = Color.white.opacity(0.15)
        let cols = 12; let rows = 7

        // #11 — vertical net strings
        for i in 0...cols {
            let ex = goalLeft + CGFloat(i) * goalWidth / CGFloat(cols)
            var line = Path()
            line.move(to: CGPoint(x: ex, y: goalTop))
            line.addLine(to: CGPoint(x: ex, y: goalBot))
            ctx.stroke(line, with: .color(netColor), lineWidth: 0.8)
        }
        // #12 — horizontal net strings
        for i in 0...rows {
            let ey = goalTop + CGFloat(i) * (goalBot - goalTop) / CGFloat(rows)
            var line = Path()
            line.move(to: CGPoint(x: goalLeft, y: ey))
            line.addLine(to: CGPoint(x: goalRight, y: ey))
            ctx.stroke(line, with: .color(netColor), lineWidth: 0.8)
        }
    }

    private func drawGoalPosts(ctx: inout GraphicsContext) {
        let postColor = Color.white.opacity(0.95)

        // Left post
        var leftPost = Path()
        leftPost.move(to: CGPoint(x: goalLeft, y: goalBot))
        leftPost.addLine(to: CGPoint(x: goalLeft, y: goalTop))
        ctx.stroke(leftPost, with: .color(postColor), lineWidth: 5)

        // Right post
        var rightPost = Path()
        rightPost.move(to: CGPoint(x: goalRight, y: goalBot))
        rightPost.addLine(to: CGPoint(x: goalRight, y: goalTop))
        ctx.stroke(rightPost, with: .color(postColor), lineWidth: 5)

        // Crossbar
        var crossbar = Path()
        crossbar.move(to: CGPoint(x: goalLeft, y: goalTop))
        crossbar.addLine(to: CGPoint(x: goalRight, y: goalTop))
        ctx.stroke(crossbar, with: .color(postColor), lineWidth: 5)

        // Post glow
        var gc = ctx; gc.addFilter(.blur(radius: 5)); gc.opacity = 0.28
        gc.stroke(crossbar, with: .color(.white), lineWidth: 10)
    }

    private func drawCornerFlags(ctx: inout GraphicsContext) {
        // #13 (carried into stadium section) — corner flag poles
        let flagPositions: [(CGFloat, CGFloat)] = [
            (goalLeft - 4, goalBot),
            (goalRight + 4, goalBot)
        ]
        let wave = CGFloat(sin(t * 2.5)) * 3
        for (fx, fy) in flagPositions {
            var pole = Path()
            pole.move(to: CGPoint(x: fx, y: fy))
            pole.addLine(to: CGPoint(x: fx, y: fy - 28))
            ctx.stroke(pole, with: .color(.white.opacity(0.75)), lineWidth: 1.5)
            // Flag triangle
            var flag = Path()
            flag.move(to: CGPoint(x: fx, y: fy - 28))
            flag.addLine(to: CGPoint(x: fx + (fx < W * 0.5 ? 10 : -10) + wave, y: fy - 22))
            flag.addLine(to: CGPoint(x: fx, y: fy - 18))
            flag.closeSubpath()
            ctx.fill(flag, with: .color(Color(red: 0.8, green: 0.1, blue: 0.1)))
        }
    }

    // ─────────────────────────────────────────────
    // MARK: #13–#24 Stadium
    // ─────────────────────────────────────────────

    private func drawStadiumSky(ctx: inout GraphicsContext) {
        // #14 — night sky gradient
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: goalTop + 6)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.20), Color(red: 0.06, green: 0.10, blue: 0.30)]),
                startPoint: CGPoint(x: W * 0.5, y: 0),
                endPoint: CGPoint(x: W * 0.5, y: goalTop + 6)
            )
        )
        // Stars
        for i in 0..<16 {
            let sx = W * CGFloat((i * 113 + 37) % 97) / 97.0
            let sy = H * 0.005 + H * 0.10 * CGFloat((i * 71 + 23) % 100) / 100.0
            let tw = 0.3 + 0.35 * CGFloat(sin(t * 1.4 + Double(i) * 0.8))
            var gc = ctx; gc.opacity = Double(tw)
            gc.fill(Path(ellipseIn: CGRect(x: sx - 1, y: sy - 1, width: 2, height: 2)), with: .color(.white))
        }
    }

    private func drawFloodlightTowers(ctx: inout GraphicsContext) {
        // #15 — 4 floodlight towers
        let towerPositions: [(CGFloat, CGFloat)] = [
            (W * 0.05, H * 0.02),
            (W * 0.95, H * 0.02),
            (W * 0.15, H * 0.01),
            (W * 0.85, H * 0.01)
        ]
        for (tx, ty) in towerPositions {
            // Tower pole
            var pole = Path()
            pole.move(to: CGPoint(x: tx, y: goalTop - 4))
            pole.addLine(to: CGPoint(x: tx, y: ty + 10))
            ctx.stroke(pole, with: .color(Color(white: 0.55)), lineWidth: 2)

            // Light cluster at top
            ctx.fill(Path(CGRect(x: tx - 6, y: ty, width: 12, height: 8)),
                     with: .color(Color(white: 0.75)))

            // #16 — beam cone glow
            var beam = Path()
            beam.move(to: CGPoint(x: tx, y: ty + 8))
            beam.addLine(to: CGPoint(x: tx - 40, y: goalTop))
            beam.addLine(to: CGPoint(x: tx + 40, y: goalTop))
            beam.closeSubpath()
            var bc = ctx; bc.addFilter(.blur(radius: 8)); bc.opacity = 0.12
            bc.fill(beam, with: .color(Color(red: 1.0, green: 0.98, blue: 0.85)))
        }
    }

    private func drawCrowdTiers(ctx: inout GraphicsContext) {
        let standTop: CGFloat = H * 0.01
        let standBot: CGFloat = goalTop - 2
        let jerseys: [Color] = [
            Color(red: 0.12, green: 0.30, blue: 0.72),
            Color(red: 0.72, green: 0.10, blue: 0.12),
            Color(red: 0.90, green: 0.80, blue: 0.15),
            Color(red: 0.80, green: 0.36, blue: 0.04),
            Color(red: 0.15, green: 0.60, blue: 0.20),
            Color(white: 0.85)
        ]
        let tiers = 3
        for tier in 0..<tiers {
            let ty = standTop + CGFloat(tier) * (standBot - standTop) / CGFloat(tiers)
            let h = (standBot - standTop) / CGFloat(tiers) - 1
            // #17 — stand tier background
            ctx.fill(Path(CGRect(x: 0, y: ty, width: W, height: h)),
                     with: .color(Color(white: 0.06 + 0.014 * Double(tier))))
        }

        // #18 — crowd heads (40+ per row, 4 rows)
        let cols = 28
        let rows = 4
        for row in 0..<rows {
            let ry = standTop + CGFloat(row) * (standBot - standTop) / CGFloat(rows) + 2
            let excited = crowdExcitement > 0.4
            let chantPhase = sin(t * 3.0) > 0
            for col in 0..<cols {
                let cx = W * 0.015 + CGFloat(col) * (W * 0.97) / CGFloat(cols - 1)
                let jc = jerseys[(col * 7 + row * 11) % jerseys.count]
                let skin = Color(red: 0.80 + 0.07 * CGFloat((col + row) % 3),
                                 green: 0.60 + 0.06 * CGFloat(col % 3), blue: 0.47)

                // Head
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: ry, width: 6, height: 6)), with: .color(skin))
                // Jersey
                ctx.fill(Path(CGRect(x: cx - 3, y: ry + 6, width: 6, height: 5)),
                         with: .color(jc.opacity(0.82)))
                if excited {
                    // Arms up wave
                    let wave = CGFloat(sin(t * 4.0 + Double(col) * 0.45)) * 2.5
                    var arms = Path()
                    arms.move(to: CGPoint(x: cx - 3, y: ry + 8))
                    arms.addLine(to: CGPoint(x: cx - 8, y: ry + 2 + wave))
                    arms.move(to: CGPoint(x: cx + 3, y: ry + 8))
                    arms.addLine(to: CGPoint(x: cx + 8, y: ry + 2 + wave))
                    ctx.stroke(arms, with: .color(jc.opacity(0.60)), lineWidth: 1.1)
                } else if chantPhase && (col + row) % 3 == 0 {
                    // Seated with scarf
                    var scarf = Path()
                    scarf.move(to: CGPoint(x: cx - 5, y: ry + 7))
                    scarf.addLine(to: CGPoint(x: cx + 5, y: ry + 7))
                    ctx.stroke(scarf, with: .color(Color.white.opacity(0.55)), lineWidth: 1.5)
                }
            }
        }
    }

    private func drawScoreboardEnd(ctx: inout GraphicsContext) {
        // #19 — scoreboard structure
        let sbX: CGFloat = W * 0.74
        let sbY: CGFloat = H * 0.03
        let sbW: CGFloat = W * 0.22
        let sbH: CGFloat = H * 0.12

        ctx.fill(Path(CGRect(x: sbX, y: sbY, width: sbW, height: sbH)),
                 with: .color(Color(white: 0.10)))
        ctx.stroke(Path(CGRect(x: sbX, y: sbY, width: sbW, height: sbH)),
                   with: .color(Color(white: 0.30)), lineWidth: 1)

        // #20 — scoreboard screen (LED style)
        ctx.fill(Path(CGRect(x: sbX + 2, y: sbY + 2, width: sbW - 4, height: sbH - 4)),
                 with: .color(Color(red: 0.05, green: 0.18, blue: 0.05)))

        let scoreText = ctx.resolve(
            Text("0 : 0")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.3))
        )
        ctx.draw(scoreText, at: CGPoint(x: sbX + sbW * 0.5, y: sbY + sbH * 0.45))

        let homeText = ctx.resolve(
            Text("HOME  AWAY")
                .font(.system(size: 5, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.55))
        )
        ctx.draw(homeText, at: CGPoint(x: sbX + sbW * 0.5, y: sbY + sbH * 0.80))
    }

    private func drawSponsorBoards(ctx: inout GraphicsContext) {
        // #21 — sponsor boards along touchline
        let boardY = goalBot - 6
        let boards: [(CGFloat, CGFloat, Color)] = [
            (goalLeft, goalLeft + goalWidth * 0.28, Color(red: 0.0, green: 0.40, blue: 0.80)),
            (goalLeft + goalWidth * 0.30, goalLeft + goalWidth * 0.58, Color(red: 0.80, green: 0.10, blue: 0.10)),
            (goalLeft + goalWidth * 0.60, goalLeft + goalWidth * 0.88, Color(red: 0.90, green: 0.65, blue: 0.0)),
            (goalLeft + goalWidth * 0.90, goalRight, Color(red: 0.10, green: 0.70, blue: 0.20))
        ]
        for (bx1, bx2, bc) in boards {
            ctx.fill(Path(CGRect(x: bx1, y: boardY, width: bx2 - bx1, height: 5)),
                     with: .color(bc.opacity(0.85)))
        }
    }

    private func drawTVCameraPlatform(ctx: inout GraphicsContext) {
        // #22 — TV camera platform on left side
        let camX: CGFloat = W * 0.03
        let camY: CGFloat = H * 0.14

        // Platform base
        ctx.fill(Path(CGRect(x: camX - 5, y: camY, width: 14, height: 6)),
                 with: .color(Color(white: 0.25)))
        // Camera body
        ctx.fill(Path(CGRect(x: camX - 3, y: camY - 5, width: 10, height: 6)),
                 with: .color(Color(white: 0.18)))
        // Lens
        ctx.fill(Path(ellipseIn: CGRect(x: camX + 5, y: camY - 3, width: 5, height: 5)),
                 with: .color(Color(red: 0.05, green: 0.15, blue: 0.40)))
        // #23 — camera red recording dot (blinks)
        let blink = sin(t * 3.0) > 0
        if blink {
            ctx.fill(Path(ellipseIn: CGRect(x: camX, y: camY - 4, width: 3, height: 3)),
                     with: .color(.red))
        }
    }

    private func drawVARScreenIndicator(ctx: inout GraphicsContext) {
        // #24 — VAR screen indicator (small screen top left)
        let vx: CGFloat = W * 0.04
        let vy: CGFloat = H * 0.04
        let vw: CGFloat = W * 0.12
        let vh: CGFloat = H * 0.06

        ctx.fill(Path(CGRect(x: vx, y: vy, width: vw, height: vh)),
                 with: .color(Color(white: 0.08)))
        ctx.stroke(Path(CGRect(x: vx, y: vy, width: vw, height: vh)),
                   with: .color(Color(white: 0.22)), lineWidth: 1)

        let varText = ctx.resolve(
            Text("VAR")
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.85))
        )
        ctx.draw(varText, at: CGPoint(x: vx + vw * 0.5, y: vy + vh * 0.5))
    }

    // ─────────────────────────────────────────────
    // MARK: #25–#48 Player Figures
    // ─────────────────────────────────────────────

    private func drawPlayerFigure(ctx: inout GraphicsContext) {
        // #25 — Player 1 (blue) stick figure near penalty spot
        let pX: CGFloat = penaltySpotX
        let pY: CGFloat = penaltySpotY - 18
        let playerColor = Color(red: 0.15, green: 0.35, blue: 0.85)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)

        // Ground shadow
        // #26 — player shadow
        var gc = ctx; gc.opacity = 0.28
        gc.fill(Path(ellipseIn: CGRect(x: pX - 16, y: penaltySpotY - 4, width: 32, height: 7)),
                with: .color(.black))

        // #27 — head
        ctx.fill(Path(ellipseIn: CGRect(x: pX - 7, y: pY - 16, width: 14, height: 14)),
                 with: .color(skin))

        // #28 — body torso
        var body = Path()
        body.move(to: CGPoint(x: pX, y: pY))
        body.addLine(to: CGPoint(x: pX, y: pY + 22))
        ctx.stroke(body, with: .color(playerColor), lineWidth: 5)

        // #29 — arms
        let armSwing = CGFloat(sin(t * 6.0)) * 5
        var arms = Path()
        arms.move(to: CGPoint(x: pX - 14, y: pY + 8 + armSwing))
        arms.addLine(to: CGPoint(x: pX + 14, y: pY + 8 - armSwing))
        ctx.stroke(arms, with: .color(playerColor), lineWidth: 3.5)

        // #30 — legs (dribble tap animation)
        let legCycle = CGFloat(sin(t * 7.0))
        var legs = Path()
        legs.move(to: CGPoint(x: pX, y: pY + 22))
        legs.addLine(to: CGPoint(x: pX - 10, y: pY + 38 + legCycle * 4))
        legs.move(to: CGPoint(x: pX, y: pY + 22))
        legs.addLine(to: CGPoint(x: pX + 10, y: pY + 38 - legCycle * 4))
        ctx.stroke(legs, with: .color(playerColor), lineWidth: 3.5)

        // #31 — jersey number "10" on chest
        let jerseyNum = ctx.resolve(
            Text("10")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.90))
        )
        ctx.draw(jerseyNum, at: CGPoint(x: pX, y: pY + 12))

        // #32 — opponent player (red) off to side
        let opX: CGFloat = pX - 55
        let opY: CGFloat = pY + 6
        let oppColor = Color(red: 0.82, green: 0.10, blue: 0.12)

        // Opponent shadow
        var oShadow = ctx; oShadow.opacity = 0.22
        oShadow.fill(Path(ellipseIn: CGRect(x: opX - 14, y: penaltySpotY - 2, width: 28, height: 6)),
                     with: .color(.black))

        // #33 — opponent head
        ctx.fill(Path(ellipseIn: CGRect(x: opX - 6, y: opY - 14, width: 12, height: 12)),
                 with: .color(skin))

        // #34 — opponent body
        var oppBody = Path()
        oppBody.move(to: CGPoint(x: opX, y: opY))
        oppBody.addLine(to: CGPoint(x: opX, y: opY + 20))
        ctx.stroke(oppBody, with: .color(oppColor), lineWidth: 4.5)

        // #35 — opponent arms (standing still, watching)
        var oppArms = Path()
        oppArms.move(to: CGPoint(x: opX - 12, y: opY + 7))
        oppArms.addLine(to: CGPoint(x: opX + 12, y: opY + 7))
        ctx.stroke(oppArms, with: .color(oppColor), lineWidth: 3)

        // #36 — opponent legs
        var oppLegs = Path()
        oppLegs.move(to: CGPoint(x: opX, y: opY + 20))
        oppLegs.addLine(to: CGPoint(x: opX - 9, y: opY + 34))
        oppLegs.move(to: CGPoint(x: opX, y: opY + 20))
        oppLegs.addLine(to: CGPoint(x: opX + 9, y: opY + 34))
        ctx.stroke(oppLegs, with: .color(oppColor), lineWidth: 3)

        // #37 — opponent jersey number "9"
        let oppNum = ctx.resolve(
            Text("9")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.88))
        )
        ctx.draw(oppNum, at: CGPoint(x: opX, y: opY + 10))

        // #38 — tackle slide figure (only visible when tackle happens)
        if isTackle {
            let slideAge = t - lastTackleTime
            let slideX = opX + CGFloat(slideAge * 80)
            var slideTackler = Path()
            // Sliding body horizontal
            slideTackler.move(to: CGPoint(x: slideX - 20, y: opY + 25))
            slideTackler.addLine(to: CGPoint(x: slideX + 10, y: opY + 20))
            ctx.stroke(slideTackler, with: .color(oppColor.opacity(0.80)), lineWidth: 5)
            var slideLegs = Path()
            slideLegs.move(to: CGPoint(x: slideX - 20, y: opY + 25))
            slideLegs.addLine(to: CGPoint(x: slideX - 30, y: opY + 20))
            ctx.stroke(slideLegs, with: .color(oppColor.opacity(0.80)), lineWidth: 4)
        }
    }

    private func drawGoalie(ctx: inout GraphicsContext) {
        let gkColor = Color(red: 0.20, green: 0.72, blue: 0.35)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 9

        let baseX = W * 0.5 + (goalieDived ? CGFloat(goalieDir) * goalWidth * 0.38 : 0)
        let baseY = goalMidY + 6

        // #39 — goalkeeper shadow
        var gc = ctx; gc.opacity = 0.25
        gc.fill(Path(ellipseIn: CGRect(x: baseX - 22, y: goalBot - 5, width: 44, height: 8)),
                with: .color(.black))

        if goalieDived && goalieDir != 0 {
            let sign = CGFloat(goalieDir)
            // #40 — diving head
            ctx.fill(Path(ellipseIn: CGRect(x: baseX - r, y: baseY - r, width: r*2, height: r*2)),
                     with: .color(skin))
            // #41 — diving body horizontal
            var body = Path()
            body.move(to: CGPoint(x: baseX, y: baseY))
            body.addLine(to: CGPoint(x: baseX + sign * 30, y: baseY - 8))
            ctx.stroke(body, with: .color(gkColor), lineWidth: 5)
            // #42 — extended arms
            var arms = Path()
            arms.move(to: CGPoint(x: baseX + sign * 10, y: baseY - 8))
            arms.addLine(to: CGPoint(x: baseX + sign * 36, y: baseY - 22))
            arms.move(to: CGPoint(x: baseX + sign * 10, y: baseY - 8))
            arms.addLine(to: CGPoint(x: baseX + sign * 20, y: baseY + 6))
            ctx.stroke(arms, with: .color(gkColor), lineWidth: 3.5)
            // #43 — trailing legs
            var legs = Path()
            legs.move(to: CGPoint(x: baseX, y: baseY))
            legs.addLine(to: CGPoint(x: baseX - sign * 14, y: baseY + 18))
            legs.move(to: CGPoint(x: baseX, y: baseY))
            legs.addLine(to: CGPoint(x: baseX - sign * 6, y: baseY + 22))
            ctx.stroke(legs, with: .color(gkColor), lineWidth: 3)
        } else {
            let bob = CGFloat(sin(t * 2.0)) * 1.5
            // #44 — goalkeeper head (standing)
            ctx.fill(Path(ellipseIn: CGRect(x: baseX - r, y: baseY - 52 - r + bob, width: r*2, height: r*2)),
                     with: .color(skin))
            // #45 — goalkeeper body
            var body = Path()
            body.move(to: CGPoint(x: baseX, y: baseY - 52 + bob))
            body.addLine(to: CGPoint(x: baseX, y: baseY - 20))
            ctx.stroke(body, with: .color(gkColor), lineWidth: 4)
            // #46 — goalkeeper wide arms (ready stance)
            var arms = Path()
            arms.move(to: CGPoint(x: baseX - 30, y: baseY - 40 + bob))
            arms.addLine(to: CGPoint(x: baseX + 30, y: baseY - 40 + bob))
            ctx.stroke(arms, with: .color(gkColor), lineWidth: 3.5)
            // #47 — goalkeeper gloves
            ctx.fill(Path(ellipseIn: CGRect(x: baseX - 35, y: baseY - 46 + bob, width: 9, height: 9)),
                     with: .color(Color(red: 0.85, green: 0.55, blue: 0.10)))
            ctx.fill(Path(ellipseIn: CGRect(x: baseX + 26, y: baseY - 46 + bob, width: 9, height: 9)),
                     with: .color(Color(red: 0.85, green: 0.55, blue: 0.10)))
            // Goalkeeper legs
            var legs = Path()
            legs.move(to: CGPoint(x: baseX, y: baseY - 20))
            legs.addLine(to: CGPoint(x: baseX - 16, y: baseY))
            legs.move(to: CGPoint(x: baseX, y: baseY - 20))
            legs.addLine(to: CGPoint(x: baseX + 16, y: baseY))
            ctx.stroke(legs, with: .color(gkColor), lineWidth: 3)
            // #48 — goalkeeper jersey number "1"
            let numTxt = ctx.resolve(
                Text("1")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.88))
            )
            ctx.draw(numTxt, at: CGPoint(x: baseX, y: baseY - 36 + bob))
        }
    }

    private func drawFreeKickWall(ctx: inout GraphicsContext) {
        // #49 — free kick wall (3 stick figures) — only if penalty awarded
        guard isPenaltyAwarded else { return }
        let wallBaseY = goalBot - 38
        let wallX: CGFloat = W * 0.5
        let wallColor = Color(red: 0.72, green: 0.10, blue: 0.12)
        let skin = Color(red: 0.82, green: 0.65, blue: 0.50)
        for i in 0..<3 {
            let fx = wallX - 22 + CGFloat(i) * 22
            ctx.fill(Path(ellipseIn: CGRect(x: fx - 5, y: wallBaseY - 14, width: 10, height: 10)),
                     with: .color(skin))
            var wBody = Path()
            wBody.move(to: CGPoint(x: fx, y: wallBaseY))
            wBody.addLine(to: CGPoint(x: fx, y: wallBaseY + 18))
            ctx.stroke(wBody, with: .color(wallColor), lineWidth: 4)
            var wArms = Path()
            wArms.move(to: CGPoint(x: fx - 9, y: wallBaseY + 7))
            wArms.addLine(to: CGPoint(x: fx + 9, y: wallBaseY + 7))
            ctx.stroke(wArms, with: .color(wallColor), lineWidth: 2.5)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: #49–#64 Ball & Scoring
    // ─────────────────────────────────────────────

    private func drawPenaltySpotHighlight(ctx: inout GraphicsContext) {
        // #50 — penalty spot circle highlight
        let pulse = 0.45 + 0.30 * CGFloat(sin(t * 4.0))
        var spotGlow = ctx; spotGlow.addFilter(.blur(radius: 6)); spotGlow.opacity = Double(pulse * 0.5)
        spotGlow.fill(
            Path(ellipseIn: CGRect(x: penaltySpotX - 12, y: penaltySpotY - 8, width: 24, height: 16)),
            with: .color(Color.white)
        )
        // Penalty spot dot
        ctx.fill(
            Path(ellipseIn: CGRect(x: penaltySpotX - 4, y: penaltySpotY - 4, width: 8, height: 8)),
            with: .color(.white.opacity(0.72))
        )
    }

    private func drawAimIndicator(ctx: inout GraphicsContext) {
        let tx = goalLeft + CGFloat(aimValue * 0.5 + 0.5) * goalWidth
        let ty = goalBot - CGFloat(power / 100.0) * (goalBot - goalTop - 24) - 12
        let pulse = 0.55 + 0.30 * CGFloat(sin(t * 5.0))

        // #51 — aim crosshair
        var hLine = Path()
        hLine.move(to: CGPoint(x: tx - 12, y: ty))
        hLine.addLine(to: CGPoint(x: tx + 12, y: ty))
        var vLine = Path()
        vLine.move(to: CGPoint(x: tx, y: ty - 12))
        vLine.addLine(to: CGPoint(x: tx, y: ty + 12))
        var ac = ctx; ac.opacity = Double(pulse * 0.85)
        ac.stroke(hLine, with: .color(.green), lineWidth: 1.5)
        ac.stroke(vLine, with: .color(.green), lineWidth: 1.5)

        // #52 — aim ring
        var ring = Path()
        ring.addEllipse(in: CGRect(x: tx - 10, y: ty - 10, width: 20, height: 20))
        var rc = ctx; rc.opacity = Double(pulse * 0.5)
        rc.stroke(ring, with: .color(.green), lineWidth: 1.5)

        // #53 — trajectory dashed line from penalty spot
        var traj = Path()
        traj.move(to: CGPoint(x: penaltySpotX, y: penaltySpotY))
        traj.addLine(to: CGPoint(x: tx, y: ty))
        ctx.stroke(traj, with: .color(.white.opacity(0.08)),
                   style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
    }

    private func drawBall(ctx: inout GraphicsContext) {
        if ballProgress >= 0 && shotFired {
            let ep = CGFloat(ballProgress)
            let target = ballTarget()
            let bx = penaltySpotX + (target.x - penaltySpotX) * ep
            // #54 — ball arc trajectory (parabolic)
            let by = penaltySpotY + (target.y - penaltySpotY) * ep - H * 0.09 * 4 * ep * (1 - ep)
            let ballR = 14 - ep * 8

            // #55 — ball motion trail
            for g in 1...3 {
                let pep = max(0, ep - CGFloat(g) * 0.08)
                let gx = penaltySpotX + (target.x - penaltySpotX) * pep
                let gy = penaltySpotY + (target.y - penaltySpotY) * pep - H * 0.09 * 4 * pep * (1 - pep)
                var gc = ctx; gc.opacity = Double(0.14 - CGFloat(g) * 0.03)
                gc.fill(
                    Path(ellipseIn: CGRect(x: gx - ballR * 0.7, y: gy - ballR * 0.7, width: ballR * 1.4, height: ballR * 1.4)),
                    with: .color(.white)
                )
            }
            // #56 — ball glow blur
            var glow = ctx; glow.addFilter(.blur(radius: 8)); glow.opacity = 0.38
            glow.fill(Path(ellipseIn: CGRect(x: bx - 16, y: by - 16, width: 32, height: 32)),
                      with: .color(.white))
            // #57 — bicycle kick trajectory curve indicator
            if ep < 0.5 {
                let curveAlpha = (0.5 - ep) * 0.6
                var curvePath = Path()
                curvePath.move(to: CGPoint(x: penaltySpotX, y: penaltySpotY))
                curvePath.addQuadCurve(
                    to: CGPoint(x: target.x, y: target.y),
                    control: CGPoint(x: (penaltySpotX + target.x) * 0.5 - 30, y: goalTop - 40)
                )
                var cc = ctx; cc.opacity = curveAlpha
                cc.stroke(curvePath, with: .color(Color.cyan.opacity(0.5)),
                          style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
            }
            drawSoccerBall(ctx: &ctx, x: bx, y: by, r: ballR, spin: ep * 5)
        } else if !shotFired {
            // Stationary ball on penalty spot
            drawSoccerBall(ctx: &ctx, x: penaltySpotX, y: penaltySpotY - 14, r: 14, spin: 0)
        }
    }

    private func drawSoccerBall(ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, spin: CGFloat) {
        // #58 — ball base with radial gradient
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(
                Gradient(colors: [.white, Color(white: 0.82)]),
                center: CGPoint(x: x - r * 0.3, y: y - r * 0.3),
                startRadius: 0, endRadius: r * 1.4
            )
        )
        // #59 — pentagon hexagonal patches (5 around ring)
        for i in 0..<5 {
            let angle = Double(i) / 5.0 * .pi * 2 + Double(spin)
            let px = x + CGFloat(cos(angle)) * r * 0.55
            let py = y + CGFloat(sin(angle)) * r * 0.55
            let pr = r * 0.28
            ctx.fill(
                Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                with: .color(.black.opacity(0.75))
            )
        }
        // #60 — center ball patch
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r * 0.15, y: y - r * 0.15, width: r * 0.30, height: r * 0.30)),
            with: .color(.black.opacity(0.70))
        )
        // #61 — ball specular highlight
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r * 0.45, y: y - r * 0.55, width: r * 0.35, height: r * 0.25)),
            with: .color(.white.opacity(0.55))
        )
    }

    private func drawGoalCelebrationBurst(ctx: inout GraphicsContext) {
        let age = t - lastScoreTime
        let frac = min(age / 1.5, 1.0)
        let alpha = max(0.0, 1.0 - frac * 1.2)
        guard alpha > 0 else { return }

        let target = ballTarget()
        let expandR = CGFloat(frac) * 100

        // #62 — 16-ray gold burst
        for i in 0..<16 {
            let angle = Double(i) / 16.0 * .pi * 2
            let len = expandR * (0.6 + CGFloat(i % 3) * 0.2)
            var ray = Path()
            ray.move(to: CGPoint(x: target.x + CGFloat(cos(angle)) * 10,
                                 y: target.y + CGFloat(sin(angle)) * 8))
            ray.addLine(to: CGPoint(x: target.x + CGFloat(cos(angle)) * len,
                                    y: target.y + CGFloat(sin(angle)) * len * 0.7))
            var rc = ctx; rc.opacity = alpha * 0.8
            rc.stroke(ray, with: .color(Color(red: 1.0, green: 0.85, blue: 0.20)),
                      lineWidth: 2.5 - CGFloat(i % 2) * 1.0)
        }

        // #63 — gold tint glow behind burst
        var goldGlow = ctx; goldGlow.addFilter(.blur(radius: 18)); goldGlow.opacity = alpha * 0.45
        goldGlow.fill(
            Path(ellipseIn: CGRect(x: target.x - 50, y: target.y - 40, width: 100, height: 80)),
            with: .color(Color(red: 1.0, green: 0.80, blue: 0.10))
        )

        // #64 — offside flag indicator (only if NOT a goal... but show cancel if goal)
        // When goal scored, show green "GOAL" flash indicator at top
        let goalFlashAlpha = max(0.0, 1.0 - frac * 3.0)
        if goalFlashAlpha > 0 {
            let goalTxt = ctx.resolve(
                Text("GOAL!")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4).opacity(goalFlashAlpha))
            )
            ctx.draw(goalTxt, at: CGPoint(x: W * 0.5, y: H * 0.12))
        }
    }

    private func drawOffsideFlag(ctx: inout GraphicsContext) {
        // #65 — offside flag (shown when corner/throw-in happens)
        guard isCorner else { return }
        let flagAge = t - lastCornerTime
        guard flagAge < 2.0 else { return }
        let flagAlpha = max(0.0, 1.0 - flagAge / 2.0)
        let flagX: CGFloat = W * 0.88
        let flagY: CGFloat = goalBot - 50 + CGFloat(flagAge * 15)

        var pole = Path()
        pole.move(to: CGPoint(x: flagX, y: flagY))
        pole.addLine(to: CGPoint(x: flagX, y: flagY + 28))
        var fc = ctx; fc.opacity = flagAlpha
        fc.stroke(pole, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
        var flagTriangle = Path()
        flagTriangle.move(to: CGPoint(x: flagX, y: flagY))
        flagTriangle.addLine(to: CGPoint(x: flagX - 14, y: flagY + 8))
        flagTriangle.addLine(to: CGPoint(x: flagX, y: flagY + 14))
        flagTriangle.closeSubpath()
        fc.fill(flagTriangle, with: .color(Color(red: 1.0, green: 0.95, blue: 0.10)))
    }

    // ─────────────────────────────────────────────
    // MARK: #65–#78 Atmosphere
    // ─────────────────────────────────────────────

    private func drawUltrasSection(ctx: inout GraphicsContext) {
        // #66 — ultras scarf waves in top center crowd section
        let scarfY: CGFloat = H * 0.05
        let excited = crowdExcitement > 0.6
        guard excited else { return }
        for i in 0..<12 {
            let sx = W * 0.20 + CGFloat(i) * W * 0.05
            let wave = CGFloat(sin(t * 3.5 + Double(i) * 0.4)) * 5
            var scarf = Path()
            scarf.move(to: CGPoint(x: sx - 8, y: scarfY + wave))
            scarf.addCurve(
                to: CGPoint(x: sx + 8, y: scarfY + wave),
                control1: CGPoint(x: sx - 4, y: scarfY + wave - 5),
                control2: CGPoint(x: sx + 4, y: scarfY + wave + 5)
            )
            let scarfColors: [Color] = [Color(red: 0.12, green: 0.30, blue: 0.72), .white,
                                         Color(red: 0.72, green: 0.10, blue: 0.12)]
            ctx.stroke(scarf, with: .color(scarfColors[i % scarfColors.count].opacity(0.75)), lineWidth: 2.5)
        }
    }

    private func drawSmokeFlare(ctx: inout GraphicsContext) {
        // #67 — smoke flare expanding circles in corner of stands
        let flareActive = crowdExcitement > 0.75
        guard flareActive else { return }
        let flareX: CGFloat = W * 0.08
        let flareY: CGFloat = H * 0.10
        for ring in 0..<4 {
            let phase = (t + Double(ring) * 0.4).truncatingRemainder(dividingBy: 2.0)
            let r = CGFloat(phase) * 30
            let alpha = max(0, 0.5 - phase * 0.25)
            let flareColor = Color(red: 0.9, green: 0.30, blue: 0.10)
            var smoke = ctx; smoke.addFilter(.blur(radius: 4)); smoke.opacity = alpha
            smoke.fill(
                Path(ellipseIn: CGRect(x: flareX - r, y: flareY - r, width: r * 2, height: r * 1.4)),
                with: .color(flareColor)
            )
        }
    }

    private func drawVARCheckFlash(ctx: inout GraphicsContext) {
        // #68 — VAR check indicator flash (blue-white strobe)
        let strobe = sin(t * 8.0) > 0
        if strobe {
            var varFlash = ctx; varFlash.addFilter(.blur(radius: 12)); varFlash.opacity = 0.22
            varFlash.fill(
                Path(CGRect(x: 0, y: 0, width: W, height: H * 0.25)),
                with: .color(Color(red: 0.0, green: 0.8, blue: 1.0))
            )
        }
        // VAR text overlay
        let varOverlay = ctx.resolve(
            Text("VAR CHECK")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(strobe ? 1.0 : 0.5))
        )
        ctx.draw(varOverlay, at: CGPoint(x: W * 0.5, y: H * 0.08))
    }

    private func drawExtraTimeBoard(ctx: inout GraphicsContext) {
        // #69 — extra time board display (bottom right corner of canvas)
        let etX: CGFloat = W * 0.78
        let etY: CGFloat = H * 0.94
        let etW: CGFloat = W * 0.18
        let etH: CGFloat = H * 0.055

        ctx.fill(Path(CGRect(x: etX, y: etY, width: etW, height: etH)),
                 with: .color(Color(red: 0.95, green: 0.90, blue: 0.10).opacity(0.92)))
        ctx.stroke(Path(CGRect(x: etX, y: etY, width: etW, height: etH)),
                   with: .color(.black.opacity(0.5)), lineWidth: 1)

        let etText = ctx.resolve(
            Text("+5")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(Color.black)
        )
        ctx.draw(etText, at: CGPoint(x: etX + etW * 0.5, y: etY + etH * 0.55))
    }

    private func drawNetRipple(ctx: inout GraphicsContext) {
        // #70 — goal net ripple rings
        let age = t - lastScoreTime
        let frac = age / 1.5
        let alpha = max(0, 1.0 - frac * 1.2)
        guard alpha > 0 else { return }

        let target = ballTarget()
        let rippleR = CGFloat(frac) * 80
        var ring = Path()
        ring.addEllipse(in: CGRect(x: target.x - rippleR, y: target.y - rippleR * 0.6,
                                    width: rippleR * 2, height: rippleR * 1.2))
        var rc = ctx; rc.opacity = alpha * 0.55
        rc.stroke(ring, with: .color(.white), lineWidth: 2.2)

        // #71 — 8 net distortion radial sparks
        for i in 0..<8 {
            let angle = Double(i) / 8.0 * .pi * 2
            let len = CGFloat(frac) * 32
            var spark = Path()
            spark.move(to: CGPoint(x: target.x + CGFloat(cos(angle)) * rippleR * 0.4,
                                   y: target.y + CGFloat(sin(angle)) * rippleR * 0.3))
            spark.addLine(to: CGPoint(x: target.x + CGFloat(cos(angle)) * (rippleR * 0.4 + len),
                                      y: target.y + CGFloat(sin(angle)) * (rippleR * 0.3 + len * 0.6)))
            var sc = ctx; sc.opacity = alpha * 0.50
            sc.stroke(spark, with: .color(.white), lineWidth: 1.5)
        }

        // #72 — second outer ripple ring (delayed)
        let ripple2R = CGFloat(max(0, frac - 0.2)) * 110
        var ring2 = Path()
        ring2.addEllipse(in: CGRect(x: target.x - ripple2R, y: target.y - ripple2R * 0.5,
                                     width: ripple2R * 2, height: ripple2R))
        var r2c = ctx; r2c.opacity = alpha * 0.28
        r2c.stroke(ring2, with: .color(Color(red: 1.0, green: 0.90, blue: 0.3)), lineWidth: 1.5)
    }

    private func drawGoalFlash(ctx: inout GraphicsContext) {
        let age = t - lastScoreTime
        let frac = age / 0.35
        let alpha = max(0, 1.0 - frac * 1.5)
        guard alpha > 0 else { return }

        // #73 — goal white flash
        var flash = ctx; flash.addFilter(.blur(radius: 25)); flash.opacity = alpha * 0.60
        flash.fill(Path(CGRect(x: goalLeft, y: goalTop, width: goalWidth, height: goalBot - goalTop)),
                   with: .color(.white))
    }

    // ─────────────────────────────────────────────
    // MARK: #74–#88 FX
    // ─────────────────────────────────────────────

    private func drawRainParticles(ctx: inout GraphicsContext) {
        // #74 — rain drops (30 particles)
        for i in 0..<30 {
            let seed = Double(i * 137 + 23)
            let cx = W * CGFloat((seed * 0.618).truncatingRemainder(dividingBy: 1.0))
            let speed = 0.4 + CGFloat((seed * 0.391).truncatingRemainder(dividingBy: 1.0)) * 0.4
            let yRaw = (t * Double(speed) * 300 + seed * 41).truncatingRemainder(dividingBy: Double(H))
            let cy = CGFloat(yRaw)
            var drop = Path()
            drop.move(to: CGPoint(x: cx, y: cy))
            drop.addLine(to: CGPoint(x: cx + 2, y: cy + 9))
            var rc = ctx; rc.opacity = 0.35
            rc.stroke(drop, with: .color(Color(red: 0.60, green: 0.80, blue: 1.0)), lineWidth: 0.9)
        }
    }

    private func drawMudSplatter(ctx: inout GraphicsContext) {
        // #75 — mud splatter particles on tackle
        let age = t - lastTackleTime
        let splatterX = penaltySpotX - 40
        let splatterY = penaltySpotY
        let spread = CGFloat(age) * 60
        let alpha = max(0.0, 0.8 - age * 1.5)
        guard alpha > 0 else { return }

        for i in 0..<10 {
            let angle = Double(i) / 10.0 * .pi * 2
            let dist = spread * CGFloat(0.4 + Double(i % 3) * 0.3)
            let mx = splatterX + CGFloat(cos(angle)) * dist
            let my = splatterY + CGFloat(sin(angle)) * dist * 0.4
            let mr = 2.5 + CGFloat(i % 3) * 1.5
            var mc = ctx; mc.opacity = alpha
            mc.fill(
                Path(ellipseIn: CGRect(x: mx - mr, y: my - mr * 0.6, width: mr * 2, height: mr * 1.2)),
                with: .color(Color(red: 0.50, green: 0.35, blue: 0.15))
            )
        }
    }

    private func drawCardFlash(ctx: inout GraphicsContext, isRed: Bool) {
        // #76 — red/yellow card flash overlay
        let cardColor: Color = isRed ? Color(red: 0.90, green: 0.10, blue: 0.10) : Color(red: 1.0, green: 0.85, blue: 0.0)
        let strobe = sin(t * 6.0) > 0

        if strobe {
            // #77 — card color screen tint
            var tint = ctx; tint.addFilter(.blur(radius: 15)); tint.opacity = 0.30
            tint.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                      with: .color(cardColor))
        }

        // Card rectangle in top center
        let cardX = W * 0.5 - 14
        let cardY = H * 0.06
        ctx.fill(Path(CGRect(x: cardX, y: cardY, width: 28, height: 40)),
                 with: .color(cardColor.opacity(strobe ? 1.0 : 0.7)))
        ctx.stroke(Path(CGRect(x: cardX, y: cardY, width: 28, height: 40)),
                   with: .color(.black.opacity(0.5)), lineWidth: 1.5)
    }

    private func drawInjuryTimeClock(ctx: inout GraphicsContext) {
        // #78 — injury time clock (top center display)
        let clockX: CGFloat = W * 0.5
        let clockY: CGFloat = H * 0.025
        let minutes = Int(t.truncatingRemainder(dividingBy: 90))
        let seconds = Int((t * 60).truncatingRemainder(dividingBy: 60))

        let timeStr = String(format: "%02d:%02d", minutes, seconds)
        let timeText = ctx.resolve(
            Text(timeStr)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.65))
        )
        ctx.draw(timeText, at: CGPoint(x: clockX, y: clockY))
    }

    private func drawCrowdChantWave(ctx: inout GraphicsContext) {
        // #79 — crowd chant brightness wave (left→right pulse)
        let wavePhase = t * 2.5
        for i in 0..<8 {
            let waveX = W * CGFloat(i) / 8.0
            let brightness = 0.5 + 0.5 * CGFloat(sin(wavePhase - Double(i) * 0.8))
            let alpha = brightness * 0.08 * CGFloat(crowdExcitement)
            ctx.fill(
                Path(CGRect(x: waveX, y: 0, width: W / 8.0, height: goalTop)),
                with: .color(Color.white.opacity(Double(alpha)))
            )
        }

        // #80 — crowd noise rings (circular emanating from stands)
        if crowdExcitement > 0.6 {
            let noisePhase = t.truncatingRemainder(dividingBy: 1.2)
            let noiseR = CGFloat(noisePhase) * W * 0.5
            let noiseAlpha = max(0.0, 0.15 - noisePhase * 0.125)
            var noiseRing = ctx; noiseRing.addFilter(.blur(radius: 3)); noiseRing.opacity = noiseAlpha
            noiseRing.stroke(
                Path(ellipseIn: CGRect(x: W * 0.5 - noiseR, y: H * 0.0 - noiseR * 0.3,
                                        width: noiseR * 2, height: noiseR * 0.8)),
                with: .color(.white),
                lineWidth: 2
            )
        }

        // #81 — stadium atmosphere ambient haze
        var haze = ctx; haze.addFilter(.blur(radius: 20)); haze.opacity = 0.06
        haze.fill(
            Path(CGRect(x: 0, y: goalTop * 0.5, width: W, height: goalTop * 0.6)),
            with: .color(Color(red: 1.0, green: 0.95, blue: 0.80))
        )

        // #82 — floodlight vertical shaft glow (left tower)
        var shaftL = ctx; shaftL.addFilter(.blur(radius: 12)); shaftL.opacity = 0.08
        shaftL.fill(
            Path(CGRect(x: W * 0.04, y: 0, width: 8, height: goalTop)),
            with: .color(.white)
        )

        // #83 — floodlight vertical shaft glow (right tower)
        var shaftR = ctx; shaftR.addFilter(.blur(radius: 12)); shaftR.opacity = 0.08
        shaftR.fill(
            Path(CGRect(x: W * 0.92, y: 0, width: 8, height: goalTop)),
            with: .color(.white)
        )

        // #84 — pitch edge ambient glow from stands
        var edgeGlow = ctx; edgeGlow.addFilter(.blur(radius: 10)); edgeGlow.opacity = 0.07
        edgeGlow.fill(
            Path(CGRect(x: 0, y: goalBot - 4, width: W, height: 10)),
            with: .color(Color(red: 0.30, green: 0.90, blue: 0.30))
        )

        // #85 — grass texture micro-dots near camera
        for dot in 0..<20 {
            let dx = W * 0.05 + W * 0.9 * CGFloat((dot * 73 + 11) % 97) / 97.0
            let dy = goalBot + (H - goalBot) * 0.65 + CGFloat((dot * 41 + 7) % 30)
            var dc = ctx; dc.opacity = 0.12
            dc.fill(Path(ellipseIn: CGRect(x: dx - 1, y: dy - 1, width: 2, height: 2)),
                    with: .color(.white))
        }

        // #86 — corner arc glow highlight
        for (cx, cy) in [(goalLeft, goalBot), (goalRight, goalBot)] {
            var cornerGlow = ctx; cornerGlow.addFilter(.blur(radius: 4)); cornerGlow.opacity = 0.18
            cornerGlow.fill(Path(ellipseIn: CGRect(x: cx - 8, y: cy - 8, width: 16, height: 16)),
                            with: .color(.white))
        }

        // #87 — post base reflection on ground
        for px in [goalLeft, goalRight] {
            var reflect = ctx; reflect.addFilter(.blur(radius: 3)); reflect.opacity = 0.20
            reflect.fill(Path(ellipseIn: CGRect(x: px - 8, y: goalBot - 4, width: 16, height: 6)),
                         with: .color(.white))
        }

        // #88 — night sky distant stadium glow (top edge ambient)
        var skyGlow = ctx; skyGlow.addFilter(.blur(radius: 22)); skyGlow.opacity = 0.10
        skyGlow.fill(
            Path(CGRect(x: W * 0.1, y: 0, width: W * 0.8, height: H * 0.08)),
            with: .color(Color(red: 1.0, green: 0.95, blue: 0.75))
        )
    }
}

// MARK: - Main View

struct SoccerGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: SoccerPhase = .ready
    @State private var currentRound: Int = 1
    @State private var playerGoals: Int = 0
    @State private var aiGoals: Int = 0
    @State private var roundResults: [SoccerRoundResult] = []
    @State private var isSuddenDeath: Bool = false

    @State private var aimValue: Double = 0.0
    @State private var isDragging: Bool = false
    @State private var isHoldingShoot: Bool = false
    @State private var power: Double = 0.0
    @State private var powerDirection: Double = 1.0
    @State private var powerTimer: Task<Void, Never>? = nil

    @State private var showRoundFeedback: Bool = false
    @State private var roundFeedbackText: String = ""
    @State private var roundFeedbackColor: Color = .white
    @State private var lastGoalieDir: Int = 0
    @State private var shotFired: Bool = false

    // Canvas state
    @State private var ballProgress: Double = -1.0
    @State private var goalieDived: Bool = false
    @State private var playerScored: Bool = false
    @State private var lastScoreTime: Double = 0
    @State private var crowdExcitement: Double = 0.30

    // FX state
    @State private var showRedCard: Bool = false
    @State private var showYellowCard: Bool = false
    @State private var isTackle: Bool = false
    @State private var lastTackleTime: Double = 0
    @State private var isRaining: Bool = false
    @State private var isPenaltyAwarded: Bool = false
    @State private var isCorner: Bool = false
    @State private var lastCornerTime: Double = 0

    // MARK: — AI Difficulty Scaling
    @State private var aiDifficulty: Double = 0.3
    @State private var consecutivePlayerGoals: Int = 0
    @State private var consecutiveAIGoals: Int = 0

    // MARK: — Stamina System
    @State private var playerStamina: Double = 1.0
    @State private var staminaTimer: Task<Void, Never>? = nil
    @State private var sprintBoosted: Bool = false
    @State private var sprintBoostActive: Bool = false

    // MARK: — Shot Power Timing
    @State private var shotPowerMeter: Double = 0.0
    @State private var shotPowerFilling: Bool = false
    @State private var shotPowerTimer: Task<Void, Never>? = nil
    @State private var releasePower: Double = 0.0
    @State private var showReleaseButton: Bool = false

    // MARK: — Set Piece / Power-Ups
    @State private var hasPowerShot: Bool = false
    @State private var hasGoldenGlove: Bool = false
    @State private var powerUpMessage: String = ""
    @State private var showPowerUpMessage: Bool = false

    // MARK: — Match Phases
    @State private var isExtraTime: Bool = false
    @State private var isSuddenDeathGoal: Bool = false
    @State private var yellowCardCount: Int = 0
    @State private var redCardGiven: Bool = false
    @State private var varCheckActive: Bool = false
    @State private var varCheckMessage: String = ""
    @State private var varCheckTask: Task<Void, Never>? = nil

    // MARK: — Progression Stats
    @State private var shotsAttempted: Int = 0
    @State private var shotsMade: Int = 0
    @State private var possessionTicks: Int = 0
    @State private var totalTicks: Int = 0
    @State private var possessionTimer: Task<Void, Never>? = nil
    @State private var manOfTheMatch: Bool = false

    private let XP_CAP: Int = 500
    private let WIN_SHARDS = 50
    private let DRAW_SHARDS = 25
    private let LOSS_SHARDS = 15
    private let accentColor = Color(red: 0.2, green: 0.7, blue: 0.3)

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.06, blue: 0.02).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Penalty Shootout",
                    subtitle: isSuddenDeath ? "SUDDEN DEATH" : "5-Round Shootout · Aim & Fire",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { phase = .shooting }
                )
                .background(Color(red: 0.02, green: 0.06, blue: 0.02).ignoresSafeArea())

            case .shooting:
                shootingBody

            case .result:
                let playerWon = playerGoals > aiGoals
                let isDraw = playerGoals == aiGoals
                let isMotm = playerGoals >= 3 && aiGoals <= 1
                VStack(spacing: 0) {
                    // Post-match stats banner
                    postMatchBanner(isMotm: isMotm)
                        .padding(.horizontal, 16).padding(.top, 16)
                    ResultScreen(
                        winner: playerWon ? .p1 : (isDraw ? .draw : .p2),
                        p1Score: playerGoals, p2Score: aiGoals,
                        title: "Penalty Shootout", accentColor: accentColor,
                        prqGain: playerWon ? 12 : (isDraw ? 5 : 2),
                        prqCurrent: viewModel.effectiveMetrics.prqScore,
                        modeAttributeLabel: "Accuracy",
                        modeAttributeValue: shotsAttempted > 0
                            ? Double(shotsMade) / Double(shotsAttempted)
                            : 0.0,
                        onReturn: { dismiss() }
                    )
                }
                .onAppear { grantShards(playerWon: playerWon, isDraw: isDraw) }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { powerTimer?.cancel(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { powerTimer?.cancel() }
    }

    // MARK: Shooting Body

    private var shootingBody: some View {
        VStack(spacing: 0) {
            // Difficulty + possession row
            HStack {
                difficultyBadge
                Spacer()
                possessionDisplay
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            scoreHeader.padding(.top, 4)

            SoccerStadiumCanvas(
                aimValue: aimValue, power: power,
                shotFired: shotFired, ballProgress: ballProgress,
                goalieDir: lastGoalieDir, goalieDived: goalieDived,
                playerScored: playerScored,
                lastScoreTime: lastScoreTime,
                crowdExcitement: crowdExcitement,
                showRedCard: showRedCard,
                showYellowCard: showYellowCard,
                isTackle: isTackle,
                lastTackleTime: lastTackleTime,
                isRaining: isRaining,
                isPenaltyAwarded: isPenaltyAwarded,
                isCorner: isCorner,
                lastCornerTime: lastCornerTime
            )
            .frame(height: 240)
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .overlay(alignment: .top) {
                if varCheckActive {
                    varCheckOverlay
                        .padding(.top, 20)
                }
            }

            // Round feedback / power-up message
            ZStack {
                if showRoundFeedback {
                    Text(roundFeedbackText)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(roundFeedbackColor)
                        .shadow(color: roundFeedbackColor.opacity(0.6), radius: 16)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else if showPowerUpMessage {
                    Text(powerUpMessage)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.1))
                        .shadow(color: Color.orange.opacity(0.7), radius: 10)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(height: 46)
            .padding(.top, 2)

            // Shot power timing meter (shown when filling)
            if showReleaseButton {
                shotTimingSection.padding(.horizontal, 16).padding(.top, 2)
            } else {
                aimSliderSection.padding(.horizontal, 16).padding(.top, 2)
                Spacer().frame(height: 6)
                powerSection.padding(.horizontal, 16)
            }

            // Stamina bar
            staminaBarSection.padding(.horizontal, 16).padding(.top, 6)

            // Power-up buttons row
            if hasPowerShot || hasGoldenGlove {
                powerUpButtonsRow.padding(.horizontal, 16).padding(.top, 4)
            }

            Spacer().frame(height: 14)
        }
        .onAppear { startStaminaRecovery(); startPossessionTimer() }
        .onDisappear { staminaTimer?.cancel(); possessionTimer?.cancel() }
    }

    // MARK: — Difficulty Badge

    private var difficultyLabel: String {
        switch aiDifficulty {
        case ..<0.35: return "EASY"
        case ..<0.60: return "MEDIUM"
        case ..<0.82: return "HARD"
        default:      return "ELITE"
        }
    }

    private var difficultyColor: Color {
        switch aiDifficulty {
        case ..<0.35: return Color(red: 0.2, green: 0.85, blue: 0.3)
        case ..<0.60: return Color(red: 0.95, green: 0.80, blue: 0.1)
        case ..<0.82: return Color(red: 1.0, green: 0.50, blue: 0.1)
        default:      return Color(red: 0.95, green: 0.15, blue: 0.15)
        }
    }

    private var difficultyBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(difficultyColor)
                .frame(width: 6, height: 6)
            Text(difficultyLabel)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(difficultyColor)
                .tracking(2)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(difficultyColor.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(difficultyColor.opacity(0.35), lineWidth: 1))
    }

    // MARK: — Possession Display

    private var possessionPercent: Int {
        guard totalTicks > 0 else { return 50 }
        return Int(Double(possessionTicks) / Double(totalTicks) * 100)
    }

    private var possessionDisplay: some View {
        HStack(spacing: 4) {
            Text("POSS")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
            Text("\(possessionPercent)%")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.16), lineWidth: 1))
    }

    // MARK: — VAR Check Overlay

    private var varCheckOverlay: some View {
        HStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.7)
                .tint(Color(red: 0.0, green: 0.9, blue: 1.0))
            Text("VAR CHECKING...")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.5), lineWidth: 1))
    }

    // MARK: — Shot Timing Section

    private var shotTimingSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SHOT POWER — TAP RELEASE IN THE ZONE!")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(1)
                Spacer()
                Text("\(Int(shotPowerMeter))%")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(shotTimingColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule().fill(Color(white: 0.12))
                        .overlay(Capsule().stroke(Color(white: 0.20), lineWidth: 1))
                    // Perfect zone (70–90%)
                    let zoneStart = geo.size.width * 0.70
                    let zoneWidth = geo.size.width * 0.20
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.22))
                        .frame(width: zoneWidth)
                        .offset(x: zoneStart)
                    // Fill bar
                    Capsule()
                        .fill(LinearGradient(
                            colors: shotPowerGradient,
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(shotPowerMeter / 100.0))
                        .animation(.linear(duration: 0.03), value: shotPowerMeter)
                    // Zone label
                    Text("PERFECT")
                        .font(.system(size: 6, weight: .black, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.7))
                        .offset(x: zoneStart + 2, y: -10)
                }
            }
            .frame(height: 16)

            // Release button
            Button {
                guard showReleaseButton else { return }
                triggerRelease()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 0.9, green: 0.2, blue: 0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: Color.orange.opacity(0.5), radius: 10)
                    Text("RELEASE!")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity).frame(height: 48)
            }
            .disabled(shotFired)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.08))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.16), lineWidth: 1)))
    }

    private var shotTimingColor: Color {
        let m = shotPowerMeter
        if m >= 70 && m <= 90 { return .green }
        if m > 90 { return .red }
        return .yellow
    }

    private var shotPowerGradient: [Color] {
        let m = shotPowerMeter
        if m < 50 { return [Color(red: 0.2, green: 0.8, blue: 1.0), accentColor] }
        if m < 70 { return [accentColor, .yellow] }
        if m <= 90 { return [.yellow, .green] }
        return [.green, .orange, .red]
    }

    // MARK: — Stamina Bar

    private var staminaColor: Color {
        if playerStamina > 0.6 { return .green }
        if playerStamina > 0.3 { return .yellow }
        return .red
    }

    private var staminaBarSection: some View {
        HStack(spacing: 8) {
            Text("STAMINA")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(2)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.10))
                        .overlay(Capsule().stroke(Color(white: 0.18), lineWidth: 1))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [staminaColor.opacity(0.9), staminaColor],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(playerStamina))
                        .animation(.linear(duration: 0.1), value: playerStamina)
                }
            }
            .frame(height: 8)
            if playerStamina < 0.3 {
                Text("LOW!")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
            // Sprint button
            Button {
                guard !shotFired, playerStamina >= 0.2 else { return }
                activateSprint()
            } label: {
                Text(sprintBoostActive ? "SPRINT ✓" : "SPRINT")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(sprintBoostActive ? .green : (playerStamina < 0.2 ? .gray : .orange))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                        sprintBoostActive ? Color.green.opacity(0.5) : Color.orange.opacity(0.3),
                        lineWidth: 1))
            }
            .disabled(shotFired || playerStamina < 0.2 || sprintBoostActive)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.06))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.14), lineWidth: 1)))
    }

    // MARK: — Power-Up Buttons Row

    private var powerUpButtonsRow: some View {
        HStack(spacing: 10) {
            if hasPowerShot {
                Button { usePowerShot() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("POWER SHOT")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.85, blue: 0.1), .orange],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: Color.orange.opacity(0.5), radius: 8)
                }
                .disabled(shotFired)
            }
            if hasGoldenGlove {
                Button { useGoldenGlove() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
                        Text("GOLDEN GLOVE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(LinearGradient(
                        colors: [Color(red: 0.9, green: 0.75, blue: 0.2), Color(red: 0.7, green: 0.55, blue: 0.1)],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: Color.yellow.opacity(0.5), radius: 8)
                }
            }
            Spacer()
        }
    }

    // MARK: Score Header

    private var scoreHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 2) {
                    Text("\(playerGoals)").font(.system(size: 40, weight: .black, design: .monospaced)).foregroundStyle(.white)
                    Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(1)
                }
                Text("—").font(.system(size: 28, weight: .bold, design: .monospaced)).foregroundStyle(.tertiary).padding(.horizontal, 16)
                VStack(spacing: 2) {
                    Text("\(aiGoals)").font(.system(size: 40, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    Text("OPP").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                }
                Spacer()
            }
            Text(isSuddenDeath
                    ? (isExtraTime ? "EXTRA TIME · SUDDEN DEATH" : "SUDDEN DEATH")
                    : "ROUND \(currentRound) OF 5")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(isSuddenDeath ? .red : accentColor.opacity(0.8)).tracking(3)
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background(.ultraThinMaterial).clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: Aim Slider

    private var aimSliderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AIM").font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(3)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.12)).frame(height: 8)
                        .overlay(Capsule().stroke(Color(white: 0.20), lineWidth: 1))
                    let thumbX = geo.size.width / 2 + CGFloat(aimValue) * (geo.size.width / 2 - 14)
                    Circle()
                        .fill(LinearGradient(colors: [accentColor, Color(red: 0.2, green: 0.8, blue: 1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                        .shadow(color: accentColor.opacity(0.5), radius: 8)
                        .position(x: thumbX, y: geo.size.height / 2)
                        .animation(.interactiveSpring(response: 0.15), value: aimValue)
                }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard !shotFired else { return }
                        isDragging = true
                        let raw = (v.location.x / geo.size.width) * 2.0 - 1.0
                        aimValue = max(-1.0, min(1.0, raw))
                    }
                    .onEnded { _ in isDragging = false }
                )
            }
            .frame(height: 28)
            HStack {
                Text("LEFT"); Spacer(); Text("CENTER"); Spacer(); Text("RIGHT")
            }
            .font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.08))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.16), lineWidth: 1)))
    }

    // MARK: Power Section

    private var powerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("POWER").font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(2)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.12)).overlay(Capsule().stroke(Color(white: 0.18), lineWidth: 1))
                        Capsule()
                            .fill(LinearGradient(colors: powerGradient, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * CGFloat(power / 100)))
                            .animation(.linear(duration: 0.05), value: power)
                    }
                }.frame(height: 12)
                Text("\(Int(power))%").font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white).frame(width: 40, alignment: .trailing)
            }
            // Low-stamina dim overlay hint
            let staminaDimmed = playerStamina < 0.3
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(shotFired
                        ? AnyShapeStyle(Color.gray.opacity(0.2))
                        : staminaDimmed
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.orange.opacity(0.55), Color.red.opacity(0.45)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(LinearGradient(
                                colors: [accentColor, Color(red: 0.2, green: 0.8, blue: 1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .shadow(color: shotFired ? .clear : (staminaDimmed ? Color.orange.opacity(0.3) : accentColor.opacity(0.4)), radius: 12)
                VStack(spacing: 2) {
                    Text(shotFired ? "•••" : "SHOOT")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(shotFired ? Color.white.opacity(0.3) : .black)
                    if staminaDimmed && !shotFired {
                        Text("LOW STAMINA")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !shotFired, !showReleaseButton else { return }
                beginShotPowerTiming()
            }
            .disabled(shotFired || showReleaseButton)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.08))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.16), lineWidth: 1)))
    }

    private var powerGradient: [Color] {
        if power < 40 { return [Color(red: 0.2, green: 0.8, blue: 1), accentColor] }
        if power < 70 { return [accentColor, .yellow] }
        return [.yellow, .orange, .red]
    }

    // MARK: — Post-Match Banner

    @ViewBuilder
    private func postMatchBanner(isMotm: Bool) -> some View {
        let acc = shotsAttempted > 0
            ? Int(Double(shotsMade) / Double(shotsAttempted) * 100)
            : 0
        VStack(spacing: 6) {
            if isMotm {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 12))
                    }
                    Text("MAN OF THE MATCH")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.1))
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 12))
                    }
                }
                .padding(.vertical, 4)
            }
            HStack(spacing: 20) {
                statPill(label: "ACCURACY", value: "\(acc)%")
                statPill(label: "SHOTS", value: "\(shotsMade)/\(shotsAttempted)")
                statPill(label: "POSSESSION", value: "\(possessionPercent)%")
                if redCardGiven {
                    statPill(label: "RED CARD", value: "⚠️")
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            isMotm ? Color.yellow.opacity(0.5) : Color(white: 0.20),
            lineWidth: 1))
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
    }

    // MARK: Logic

    private func startPowerOscillation() {
        powerTimer?.cancel(); power = 0; powerDirection = 1.0
        powerTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(28))
                if Task.isCancelled { break }
                await MainActor.run {
                    power += powerDirection * 2.5
                    if power >= 100 { power = 100; powerDirection = -1 }
                    if power <= 0   { power = 0;   powerDirection =  1 }
                }
            }
        }
    }

    // MARK: — Stamina System

    private func startStaminaRecovery() {
        staminaTimer?.cancel()
        staminaTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { break }
                await MainActor.run {
                    // Passive recovery: 0.005 per second = 0.001 per 200ms tick
                    if playerStamina < 1.0 {
                        playerStamina = min(1.0, playerStamina + 0.001)
                    }
                }
            }
        }
    }

    private func drainStamina(by amount: Double) {
        playerStamina = max(0.0, playerStamina - amount)
    }

    private func activateSprint() {
        guard !sprintBoostActive, playerStamina >= 0.2 else { return }
        drainStamina(by: 0.2)
        sprintBoostActive = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Sprint effect lasts for one shot (reset after shot fires)
    }

    // MARK: — Shot Power Timing

    /// Called when user taps SHOOT — starts the 1.5-second power meter fill
    private func beginShotPowerTiming() {
        guard !shotFired, !showReleaseButton else { return }
        shotPowerMeter = 0.0
        shotPowerFilling = true
        showReleaseButton = true
        drainStamina(by: 0.04)

        let fillDuration: Double = 1.5
        let tickMs: Int = 20
        let totalTicks = Int(fillDuration * 1000 / Double(tickMs))
        let incrementPerTick = 100.0 / Double(totalTicks)

        shotPowerTimer?.cancel()
        shotPowerTimer = Task {
            for _ in 0..<totalTicks {
                try? await Task.sleep(nanoseconds: UInt64(tickMs) * 1_000_000)
                if Task.isCancelled { break }
                await MainActor.run {
                    shotPowerMeter = min(100.0, shotPowerMeter + incrementPerTick)
                }
            }
            // Auto-fire at max if player hasn't released
            await MainActor.run {
                if showReleaseButton && !shotFired {
                    triggerRelease()
                }
            }
        }
    }

    /// Called when user taps RELEASE button
    private func triggerRelease() {
        shotPowerTimer?.cancel()
        releasePower = shotPowerMeter
        showReleaseButton = false
        shotPowerFilling = false
        power = releasePower
        fireShot(withReleasePower: releasePower)
    }

    // MARK: — Set Piece Power-Ups

    private func usePowerShot() {
        guard hasPowerShot, !shotFired else { return }
        hasPowerShot = false
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        // Guaranteed goal — set high power and center aim
        power = 95.0
        releasePower = 90.0
        fireShot(withReleasePower: 90.0, guaranteedGoal: true)
    }

    private func useGoldenGlove() {
        guard hasGoldenGlove else { return }
        hasGoldenGlove = false
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        // Golden Glove activates: next AI shot is blocked (handled in advanceRound)
        withAnimation {
            powerUpMessage = "GOLDEN GLOVE ACTIVATED!\nNext AI shot blocked!"
            showPowerUpMessage = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run { withAnimation { showPowerUpMessage = false } }
        }
    }

    private func awardPowerUp(message: String) {
        withAnimation {
            powerUpMessage = message
            showPowerUpMessage = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { withAnimation { showPowerUpMessage = false } }
        }
    }

    // MARK: — VAR Check

    private func runVARCheck(onComplete: @escaping () -> Void) {
        varCheckActive = true
        varCheckTask?.cancel()
        varCheckTask = Task {
            try? await Task.sleep(for: .seconds(3.0))
            await MainActor.run {
                varCheckActive = false
                onComplete()
            }
        }
    }

    // MARK: — Possession Ticker

    private func startPossessionTimer() {
        possessionTimer?.cancel()
        possessionTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                if Task.isCancelled { break }
                await MainActor.run {
                    totalTicks += 1
                    // Player has possession when NOT in shooting animation
                    if !shotFired { possessionTicks += 1 }
                }
            }
        }
    }

    // MARK: — Core Shot Logic

    private func fireShot(withReleasePower rp: Double? = nil, guaranteedGoal: Bool = false) {
        let finalAim = aimValue
        let finalPower = rp ?? power
        let prq = viewModel.effectiveMetrics.prqScore

        // Stamina penalty: if low stamina, reduce effective power
        let staminaMultiplier: Double = playerStamina < 0.3 ? 0.7 : 1.0
        let adjustedPower = finalPower * staminaMultiplier

        // Sprint boost: +40% success chance for one shot
        let sprintBonus: Double = sprintBoostActive ? 0.40 : 0.0
        sprintBoostActive = false // consume sprint

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        shotsAttempted += 1

        let accuracy = 0.45 + (prq / 100.0) * 0.30 + sprintBonus
        let goaliePrediction: Double = Double.random(in: 0...1) < accuracy
            ? finalAim : Double.random(in: -1...1)
        let gDir: Int = goaliePrediction < -0.2 ? -1 : (goaliePrediction > 0.2 ? 1 : 0)
        lastGoalieDir = gDir

        // Release power accuracy modifier: 70–90% = full accuracy, outside = reduced
        let releaseAccMod: Double
        if finalPower >= 70 && finalPower <= 90 {
            releaseAccMod = 1.0
        } else if finalPower > 90 {
            releaseAccMod = max(0.4, 1.0 - (finalPower - 90) / 100.0 * 2.0)
        } else {
            releaseAccMod = max(0.3, finalPower / 70.0)
        }

        // Goalie save probability = aiDifficulty * (1 - releasePower / 100)
        let goalieSaveProb = aiDifficulty * (1.0 - finalPower / 100.0)
        let coverageWidth = (0.48 - (prq / 100.0) * 0.10) * (1.0 + goalieSaveProb * 0.3)
        let goalieCovers = !guaranteedGoal &&
            (abs(finalAim - Double(gDir) * 0.6) < coverageWidth * releaseAccMod ||
             Double.random(in: 0...1) < goalieSaveProb)
        let scored = guaranteedGoal || (!goalieCovers && adjustedPower > 20)

        // AI shoot chance scales with difficulty
        // At difficulty 0.3 = 15%; at 1.0 = 55%
        let aiShootChance = 0.15 + (aiDifficulty - 0.3) / 0.7 * 0.40
        // If golden glove is NOT active, AI can score
        let aiScoreRoll = Double.random(in: 0...1)
        let aiScored = !hasGoldenGlove && aiScoreRoll < aiShootChance

        // Red-card AI advantage: +1 difficulty offset
        let extraAIDifficulty: Double = redCardGiven ? 0.1 : 0.0
        _ = extraAIDifficulty // applied above through aiDifficulty state

        let tackleProbability = Double.random(in: 0...1)
        let cornerProbability = Double.random(in: 0...1)

        // Check if this is a close call for VAR
        let isCloseCall = !guaranteedGoal && abs(finalAim - Double(gDir) * 0.6) < coverageWidth * 1.3
            && Double.random(in: 0...1) < 0.25

        shotFired = true
        playerScored = false
        isPenaltyAwarded = false
        isCorner = false
        isTackle = false

        ballProgress = 0
        Task {
            // If close call, do VAR check first
            if isCloseCall {
                await MainActor.run {
                    varCheckActive = true
                }
                try? await Task.sleep(for: .seconds(3.0))
                await MainActor.run { varCheckActive = false }
            }

            for step in 0..<30 {
                try? await Task.sleep(nanoseconds: 14_000_000)
                await MainActor.run { ballProgress = Double(step + 1) / 30.0 }
            }
            await MainActor.run {
                ballProgress = -1
                goalieDived = true

                if scored {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    playerScored = true
                    playerGoals += 1
                    shotsMade += 1
                    lastScoreTime = Date().timeIntervalSinceReferenceDate
                    crowdExcitement = min(1.0, crowdExcitement + 0.35)

                    // Update consecutive goal streaks
                    consecutivePlayerGoals += 1
                    consecutiveAIGoals = 0

                    // AI difficulty scaling: harder after each player goal
                    aiDifficulty = min(1.0, aiDifficulty + 0.08)

                    // Set piece: 3 consecutive player goals = POWER SHOT
                    if consecutivePlayerGoals >= 3 && !hasPowerShot {
                        hasPowerShot = true
                        consecutivePlayerGoals = 0
                        awardPowerUp("POWER SHOT UNLOCKED!\n3 goals in a row!")
                    }
                } else if goalieCovers && tackleProbability < 0.4 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isTackle = true
                    lastTackleTime = Date().timeIntervalSinceReferenceDate
                    consecutivePlayerGoals = 0
                } else if !scored && cornerProbability < 0.30 {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    isCorner = true
                    lastCornerTime = Date().timeIntervalSinceReferenceDate
                    consecutivePlayerGoals = 0
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    consecutivePlayerGoals = 0
                }

                if aiScored {
                    aiGoals += 1
                    consecutiveAIGoals += 1
                    consecutivePlayerGoals = 0

                    // Set piece: 3 consecutive conceded = GOLDEN GLOVE
                    if consecutiveAIGoals >= 3 && !hasGoldenGlove {
                        hasGoldenGlove = true
                        consecutiveAIGoals = 0
                        awardPowerUp("GOLDEN GLOVE EARNED!\n3 goals conceded!")
                    }

                    // Yellow card accumulation
                    if Double.random(in: 0...1) < 0.15 {
                        yellowCardCount += 1
                        showYellowCard = true
                        if yellowCardCount >= 2 && !redCardGiven {
                            // Red card = +AI advantage
                            redCardGiven = true
                            showRedCard = true
                            aiDifficulty = min(1.0, aiDifficulty + 0.1)
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                } else {
                    consecutiveAIGoals = 0
                }

                roundResults.append(SoccerRoundResult(
                    playerScored: scored, aiScored: aiScored,
                    aimValue: finalAim, power: finalPower, goalieDirection: gDir
                ))
                withAnimation(.spring(response: 0.2)) {
                    roundFeedbackText = scored ? (guaranteedGoal ? "POWER GOAL!" : "GOAL!") : "SAVED!"
                    roundFeedbackColor = scored ? accentColor : .red
                    showRoundFeedback = true
                }
            }

            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run {
                withAnimation { showRoundFeedback = false }
                advanceRound()
            }
        }
    }

    /// Trigger penalty-awarded haptic (rigid) — called when penalty event occurs
    private func triggerPenaltyHaptic() {
        // HAPTIC 4: Rigid on penalty/free kick awarded
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        isPenaltyAwarded = true
    }

    /// Trigger red card/own goal haptic (error notification) — called on red card event
    private func triggerRedCardHaptic() {
        // HAPTIC 5: Error on red card / own goal
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        showRedCard = true
    }

    private func advanceRound() {
        if isSuddenDeath {
            if playerGoals != aiGoals {
                GameResultService.saveResult(modeId: "soccer", userScore: playerGoals, opponentScore: aiGoals)
                phase = .result
            }
            else { resetRoundState(); phase = .ready }
            return
        }
        if currentRound >= 5 {
            if playerGoals == aiGoals {
                // Extra time / sudden death
                isSuddenDeath = true
                isExtraTime = true
                currentRound = 1
                resetRoundState()
                phase = .ready
            } else {
                // Check MAN OF THE MATCH
                manOfTheMatch = playerGoals >= 3 && aiGoals <= 1
                GameResultService.saveResult(modeId: "soccer", userScore: playerGoals, opponentScore: aiGoals)
                phase = .result
            }
        } else {
            currentRound += 1; resetRoundState()
        }
    }

    private func resetRoundState() {
        aimValue = 0; power = 0; powerDirection = 1
        isHoldingShoot = false; shotFired = false
        ballProgress = -1; goalieDived = false; playerScored = false
        lastGoalieDir = 0; showRoundFeedback = false
        showRedCard = false; showYellowCard = false
        isTackle = false; isCorner = false; isPenaltyAwarded = false
        shotPowerMeter = 0; showReleaseButton = false; shotPowerFilling = false
        shotPowerTimer?.cancel(); shotPowerTimer = nil
        releasePower = 0
    }

    private func grantShards(playerWon: Bool, isDraw: Bool) {
        let earned = playerWon ? WIN_SHARDS : (isDraw ? DRAW_SHARDS : LOSS_SHARDS)
        viewModel.profile.evolutionShards += min(earned, XP_CAP)
    }
}
