import SwiftUI
import UIKit

// MARK: - Types

private enum H2HPhase { case difficultySelect, ready, playing, result }
private enum ShotResult: String { case made = "MADE", blocked = "BLOCKED", miss = "MISS" }
private enum H2HPossession { case player, opponent }

private enum TimingResult {
    case perfect, good, early, late, rushed
    var accuracyModifier: Double {
        switch self {
        case .perfect: return 0.15
        case .good:    return 0.0
        case .early:   return -0.15
        case .late:    return -0.15
        case .rushed:  return -0.30
        }
    }
    var label: String {
        switch self {
        case .perfect: return "PERFECT"
        case .good:    return "GOOD"
        case .early:   return "EARLY"
        case .late:    return "LATE"
        case .rushed:  return "RUSHED"
        }
    }
    var color: Color {
        switch self {
        case .perfect: return .green
        case .good:    return .white
        default:       return .yellow
        }
    }
}

private enum AIDifficulty: String, CaseIterable {
    case rookie = "ROOKIE"
    case pro = "PRO"
    case elite = "ELITE"
    case legend = "LEGEND"

    var displayName: String { rawValue }

    var prqRewardRange: String {
        switch self {
        case .rookie: return "+3 PRQ"
        case .pro: return "+8 PRQ"
        case .elite: return "+15 PRQ"
        case .legend: return "+25 PRQ"
        }
    }

    var winRateDescription: String {
        switch self {
        case .rookie: return "Easy"
        case .pro: return "Medium"
        case .elite: return "Hard"
        case .legend: return "Legendary"
        }
    }

    var aiMissDescription: String {
        switch self {
        case .rookie: return "AI misses 50% of shots"
        case .pro: return "AI misses 25% of shots"
        case .elite: return "AI misses 10% of shots"
        case .legend: return "AI misses 5%, defends harder"
        }
    }

    var prqReward: Int {
        switch self {
        case .rookie: return 3
        case .pro: return 8
        case .elite: return 15
        case .legend: return 25
        }
    }

    var cardGradient: [Color] {
        switch self {
        case .rookie: return [Color(red: 0.72, green: 0.45, blue: 0.20), Color(red: 0.50, green: 0.30, blue: 0.10)]
        case .pro: return [Color(red: 0.70, green: 0.70, blue: 0.75), Color(red: 0.45, green: 0.45, blue: 0.52)]
        case .elite: return [Color(red: 0.85, green: 0.70, blue: 0.10), Color(red: 0.60, green: 0.48, blue: 0.05)]
        case .legend: return [Color(red: 0.62, green: 0.18, blue: 0.90), Color(red: 0.38, green: 0.08, blue: 0.62)]
        }
    }

    var badgeColor: Color {
        switch self {
        case .rookie: return Color(red: 0.72, green: 0.45, blue: 0.20)
        case .pro: return Color(red: 0.70, green: 0.70, blue: 0.75)
        case .elite: return Color(red: 0.85, green: 0.70, blue: 0.10)
        case .legend: return Color(red: 0.70, green: 0.20, blue: 0.95)
        }
    }
}

// MARK: - Street Court Canvas

private struct StreetCourtCanvas: View {
    let possession: H2HPossession
    let shotProgress: Double    // 0→1 during shot arc; -1 = idle
    let shotMade: Bool
    let playerPose: String      // "idle","shoot","crossover","drive","defend"
    let opponentPose: String    // "idle","guard","block","shoot"
    let rimShake: Double        // 0 = still, >0 = rim vibrating
    let showConfetti: Bool
    let hotHandActive: Bool
    let posterizeActive: Bool
    let ankleShimmy: Bool
    let dustActive: Bool
    // Shot timing
    let shotTimingActive: Bool
    let shotTimingMeter: CGFloat
    let timingResult: TimingResult?
    let timingFeedbackOpacity: Double
    // Momentum
    let playerMomentum: Int
    let aiMomentum: Int

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = StreetDrawer(
                    size: size, t: t,
                    possession: possession, shotProgress: shotProgress,
                    shotMade: shotMade, playerPose: playerPose,
                    opponentPose: opponentPose, rimShake: rimShake,
                    showConfetti: showConfetti, hotHandActive: hotHandActive,
                    posterizeActive: posterizeActive, ankleShimmy: ankleShimmy,
                    dustActive: dustActive,
                    shotTimingActive: shotTimingActive,
                    shotTimingMeter: shotTimingMeter,
                    timingResult: timingResult,
                    timingFeedbackOpacity: timingFeedbackOpacity,
                    playerMomentum: playerMomentum,
                    aiMomentum: aiMomentum
                )
                d.render(into: &ctx)
            }
        }
    }
}

// MARK: - Street Drawer

private struct StreetDrawer {
    let W: CGFloat, H: CGFloat, t: Double
    let possession: H2HPossession
    let shotProgress: Double
    let shotMade: Bool
    let playerPose: String
    let opponentPose: String
    let rimShake: Double
    let showConfetti: Bool
    let hotHandActive: Bool
    let posterizeActive: Bool
    let ankleShimmy: Bool
    let dustActive: Bool
    let shotTimingActive: Bool
    let shotTimingMeter: CGFloat
    let timingResult: TimingResult?
    let timingFeedbackOpacity: Double
    let playerMomentum: Int
    let aiMomentum: Int

    // Court geometry
    var floorY: CGFloat { H * 0.68 }
    var playerX: CGFloat { W * 0.22 }
    var playerY: CGFloat { floorY }
    var opponentX: CGFloat { W * 0.62 }
    var opponentY: CGFloat { floorY - H * 0.025 }
    var rimX: CGFloat { W * 0.82 }
    var rimY: CGFloat { H * 0.34 + CGFloat(rimShake) * 3 * CGFloat(sin(t * 50)) }
    var bbX: CGFloat { rimX + 4 }

    init(size: CGSize, t: Double, possession: H2HPossession, shotProgress: Double,
         shotMade: Bool, playerPose: String, opponentPose: String, rimShake: Double,
         showConfetti: Bool, hotHandActive: Bool, posterizeActive: Bool,
         ankleShimmy: Bool, dustActive: Bool,
         shotTimingActive: Bool, shotTimingMeter: CGFloat,
         timingResult: TimingResult?, timingFeedbackOpacity: Double,
         playerMomentum: Int, aiMomentum: Int) {
        self.W = size.width; self.H = size.height; self.t = t
        self.possession = possession; self.shotProgress = shotProgress
        self.shotMade = shotMade; self.playerPose = playerPose
        self.opponentPose = opponentPose; self.rimShake = rimShake
        self.showConfetti = showConfetti; self.hotHandActive = hotHandActive
        self.posterizeActive = posterizeActive; self.ankleShimmy = ankleShimmy
        self.dustActive = dustActive
        self.shotTimingActive = shotTimingActive
        self.shotTimingMeter = shotTimingMeter
        self.timingResult = timingResult
        self.timingFeedbackOpacity = timingFeedbackOpacity
        self.playerMomentum = playerMomentum
        self.aiMomentum = aiMomentum
    }

    mutating func render(into ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawBrickWall(ctx: &ctx)
        drawGraffitiTags(ctx: &ctx)
        drawPowerLines(ctx: &ctx)
        drawChainLinkFence(ctx: &ctx)
        drawStreetlights(ctx: &ctx)
        drawCourt(ctx: &ctx)
        drawAsphaltCracks(ctx: &ctx)
        drawPuddleReflection(ctx: &ctx)
        drawTrashCan(ctx: &ctx)
        drawBasket(ctx: &ctx)
        drawSpectators(ctx: &ctx)
        drawGameClock(ctx: &ctx)
        drawScoreSprayPaint(ctx: &ctx)
        drawMomentumIndicators(ctx: &ctx)
        if hotHandActive { drawHotHandAura(ctx: &ctx) }
        if shotProgress >= 0 { drawBallArc(ctx: &ctx) }
        drawPlayerShadow(ctx: &ctx)
        drawStickFigure(ctx: &ctx, cx: opponentX, fy: opponentY, pose: opponentPose,
                        color: Color(red:1.0, green:0.25, blue:0.25), flip: true)
        drawStickFigure(ctx: &ctx, cx: playerX, fy: playerY, pose: playerPose,
                        color: Color(red:0.18, green:0.78, blue:1.0), flip: false)
        drawSweatParticles(ctx: &ctx)
        if shotProgress < 0 { drawDribble(ctx: &ctx) }
        if shotMade && shotProgress < 0 { drawSwishNet(ctx: &ctx) }
        if dustActive { drawCrossoverDust(ctx: &ctx) }
        if ankleShimmy { drawAnkleShimmy(ctx: &ctx) }
        if posterizeActive { drawPosterizeImpact(ctx: &ctx) }
        if showConfetti {
            drawBuzzerVignette(ctx: &ctx)
            drawCrowdConfetti(ctx: &ctx)
        }
        if playerMomentum >= 2 { drawMomentumFlame(ctx: &ctx) }
        if playerMomentum == 3 { drawOnFireBorder(ctx: &ctx) }
        if playerMomentum <= -2 { drawIceColdOverlay(ctx: &ctx) }
        if shotTimingActive { drawShotTimingBar(ctx: &ctx) }
        if timingFeedbackOpacity > 0 { drawTimingFeedback(ctx: &ctx) }
    }

    // MARK: - #1 Sky / Background

    private func drawSky(ctx: inout GraphicsContext) {
        // #1 Dusk/sunset sky gradient — full background
        var skyPath = Path()
        skyPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.fill(skyPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.55, green: 0.22, blue: 0.08),
                Color(red: 0.18, green: 0.08, blue: 0.28),
                Color(red: 0.04, green: 0.04, blue: 0.10)
            ]),
            startPoint: CGPoint(x: W / 2, y: 0),
            endPoint: CGPoint(x: W / 2, y: H * 0.68)
        ))

        // #2 Horizon glow (orange sunset band)
        var horizonGlow = ctx
        horizonGlow.addFilter(.blur(radius: 22))
        var hgPath = Path()
        hgPath.addRect(CGRect(x: 0, y: H * 0.28, width: W, height: H * 0.10))
        horizonGlow.fill(hgPath, with: .color(Color(red: 1.0, green: 0.45, blue: 0.10).opacity(0.35)))

        // #3 Stars in upper sky
        for i in 0..<22 {
            let sx = W * CGFloat((i * 137 % 100)) / 100.0
            let sy = H * 0.30 * CGFloat((i * 71 % 100)) / 100.0
            let starAlpha = 0.15 + 0.25 * sin(t * 0.5 + Double(i))
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - 1, y: sy - 1, width: 2, height: 2)),
                with: .color(Color.white.opacity(starAlpha))
            )
        }

        // #4 Streetlight cone right (over basket)
        var cone = Path()
        cone.move(to: CGPoint(x: rimX + 10, y: H * 0.12))
        cone.addLine(to: CGPoint(x: rimX + 70, y: floorY))
        cone.addLine(to: CGPoint(x: rimX - 50, y: floorY))
        cone.closeSubpath()
        ctx.fill(cone, with: .color(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.07)))

        // #5 Streetlight cone left (player side)
        var cone2 = Path()
        cone2.move(to: CGPoint(x: W * 0.18, y: H * 0.14))
        cone2.addLine(to: CGPoint(x: W * 0.18 + 65, y: floorY))
        cone2.addLine(to: CGPoint(x: W * 0.18 - 55, y: floorY))
        cone2.closeSubpath()
        ctx.fill(cone2, with: .color(Color(red: 0.30, green: 0.50, blue: 1.0).opacity(0.05)))
    }

    // MARK: - #6-#9 Brick Wall

    private func drawBrickWall(ctx: inout GraphicsContext) {
        let wallLeft: CGFloat = 0
        let wallRight: CGFloat = W * 0.12
        let wallTop: CGFloat = floorY - H * 0.40
        let wallBot: CGFloat = floorY

        // #6 Brick wall base fill
        ctx.fill(
            Path(CGRect(x: wallLeft, y: wallTop, width: wallRight - wallLeft, height: wallBot - wallTop)),
            with: .color(Color(red: 0.28, green: 0.16, blue: 0.12).opacity(0.90))
        )

        // #7 Brick rows (horizontal mortar lines)
        let brickH: CGFloat = 10
        var row: CGFloat = wallTop
        while row < wallBot {
            var mortar = Path()
            mortar.move(to: CGPoint(x: wallLeft, y: row))
            mortar.addLine(to: CGPoint(x: wallRight, y: row))
            ctx.stroke(mortar, with: .color(Color(red: 0.18, green: 0.10, blue: 0.08).opacity(0.60)), lineWidth: 1.2)
            row += brickH
        }

        // #8 Brick vertical joints (offset per row)
        var rowIndex = 0
        var rowY: CGFloat = wallTop
        while rowY < wallBot {
            let offset: CGFloat = (rowIndex % 2 == 0) ? 0 : (W * 0.06)
            var colX = wallLeft + offset
            while colX < wallRight {
                var joint = Path()
                joint.move(to: CGPoint(x: colX, y: rowY))
                joint.addLine(to: CGPoint(x: colX, y: rowY + brickH))
                ctx.stroke(joint, with: .color(Color(red: 0.18, green: 0.10, blue: 0.08).opacity(0.55)), lineWidth: 0.8)
                colX += W * 0.12
            }
            rowY += brickH
            rowIndex += 1
        }

        // #9 Wall edge shadow (depth)
        var wallEdge = ctx
        wallEdge.addFilter(.blur(radius: 6))
        var edgePath = Path()
        edgePath.addRect(CGRect(x: wallRight - 8, y: wallTop, width: 8, height: wallBot - wallTop))
        wallEdge.fill(edgePath, with: .color(Color.black.opacity(0.45)))
    }

    // MARK: - #10-#13 Graffiti Tags

    private func drawGraffitiTags(ctx: inout GraphicsContext) {
        // #10 Graffiti tag 1: "NEXUS" — red on brick wall
        let t1X = W * 0.01; let t1Y = floorY - H * 0.38
        let t1W = W * 0.09; let t1H = H * 0.05
        let red = Color(red: 0.9, green: 0.2, blue: 0.2)
        var tag1Glow = ctx
        tag1Glow.addFilter(.blur(radius: 4))
        tag1Glow.fill(Path(CGRect(x: t1X, y: t1Y, width: t1W, height: t1H)), with: .color(red.opacity(0.30)))
        ctx.fill(Path(CGRect(x: t1X, y: t1Y, width: t1W, height: t1H)), with: .color(red.opacity(0.22)))
        // N letter strokes
        var nPath = Path()
        nPath.move(to: CGPoint(x: t1X + 4, y: t1Y + t1H - 3))
        nPath.addLine(to: CGPoint(x: t1X + 4, y: t1Y + 3))
        nPath.addLine(to: CGPoint(x: t1X + t1W - 4, y: t1Y + t1H - 3))
        nPath.addLine(to: CGPoint(x: t1X + t1W - 4, y: t1Y + 3))
        ctx.stroke(nPath, with: .color(red.opacity(0.70)), lineWidth: 1.5)

        // #11 Graffiti tag 2: "RUN IT" — green
        let t2X = W * 0.01; let t2Y = floorY - H * 0.30
        let t2W = W * 0.10; let t2H = H * 0.04
        let grn = Color(red: 0.2, green: 0.8, blue: 0.3)
        var tag2Glow = ctx
        tag2Glow.addFilter(.blur(radius: 4))
        tag2Glow.fill(Path(CGRect(x: t2X, y: t2Y, width: t2W, height: t2H)), with: .color(grn.opacity(0.30)))
        ctx.fill(Path(CGRect(x: t2X, y: t2Y, width: t2W, height: t2H)), with: .color(grn.opacity(0.22)))
        var r2Path = Path()
        r2Path.move(to: CGPoint(x: t2X + 3, y: t2Y + t2H - 2))
        r2Path.addLine(to: CGPoint(x: t2X + 3, y: t2Y + 2))
        r2Path.addLine(to: CGPoint(x: t2X + t2W * 0.4, y: t2Y + t2H * 0.5))
        r2Path.addLine(to: CGPoint(x: t2X + t2W - 3, y: t2Y + t2H - 2))
        ctx.stroke(r2Path, with: .color(grn.opacity(0.65)), lineWidth: 1.5)

        // #12 Graffiti tag 3: "GAME" — blue
        let t3X = W * 0.01; let t3Y = floorY - H * 0.23
        let t3W = W * 0.08; let t3H = H * 0.04
        let blu = Color(red: 0.2, green: 0.5, blue: 1.0)
        var tag3Glow = ctx
        tag3Glow.addFilter(.blur(radius: 4))
        tag3Glow.fill(Path(CGRect(x: t3X, y: t3Y, width: t3W, height: t3H)), with: .color(blu.opacity(0.30)))
        ctx.fill(Path(CGRect(x: t3X, y: t3Y, width: t3W, height: t3H)), with: .color(blu.opacity(0.22)))
        var g3Path = Path()
        g3Path.move(to: CGPoint(x: t3X + t3W - 3, y: t3Y + 3))
        g3Path.addArc(center: CGPoint(x: t3X + t3W * 0.5, y: t3Y + t3H * 0.5),
                      radius: t3W * 0.32, startAngle: .degrees(-60), endAngle: .degrees(200), clockwise: false)
        ctx.stroke(g3Path, with: .color(blu.opacity(0.65)), lineWidth: 1.5)

        // #13 Graffiti tag 4: "1v1" — gold/orange, bottom tag
        let t4X = W * 0.01; let t4Y = floorY - H * 0.15
        let t4W = W * 0.10; let t4H = H * 0.04
        let gld = Color(red: 1.0, green: 0.7, blue: 0.1)
        var tag4Glow = ctx
        tag4Glow.addFilter(.blur(radius: 5))
        tag4Glow.fill(Path(CGRect(x: t4X, y: t4Y, width: t4W, height: t4H)), with: .color(gld.opacity(0.35)))
        ctx.fill(Path(CGRect(x: t4X, y: t4Y, width: t4W, height: t4H)), with: .color(gld.opacity(0.25)))
        // "1v1" stroke marks
        var oPath = Path()
        oPath.move(to: CGPoint(x: t4X + 3, y: t4Y + 2))
        oPath.addLine(to: CGPoint(x: t4X + 3, y: t4Y + t4H - 2))
        oPath.move(to: CGPoint(x: t4X + t4W * 0.45, y: t4Y + 2))
        oPath.addLine(to: CGPoint(x: t4X + t4W * 0.55, y: t4Y + t4H - 2))
        oPath.move(to: CGPoint(x: t4X + t4W - 3, y: t4Y + 2))
        oPath.addLine(to: CGPoint(x: t4X + t4W - 3, y: t4Y + t4H - 2))
        ctx.stroke(oPath, with: .color(gld.opacity(0.70)), lineWidth: 1.5)
    }

    // MARK: - #14 Power Lines

    private func drawPowerLines(ctx: inout GraphicsContext) {
        // #14 Power lines silhouette at top of scene
        let lineY: CGFloat = H * 0.08
        var powerLine = Path()
        powerLine.move(to: CGPoint(x: 0, y: lineY))
        powerLine.addLine(to: CGPoint(x: W, y: lineY + CGFloat(sin(t * 0.3)) * 2))
        ctx.stroke(powerLine, with: .color(Color.black.opacity(0.70)), lineWidth: 1.5)

        // Second power line slightly lower
        var powerLine2 = Path()
        powerLine2.move(to: CGPoint(x: 0, y: lineY + 6))
        powerLine2.addLine(to: CGPoint(x: W, y: lineY + 6 + CGFloat(sin(t * 0.3 + 0.5)) * 2))
        ctx.stroke(powerLine2, with: .color(Color.black.opacity(0.60)), lineWidth: 1.2)

        // Power line poles
        for i in 0..<4 {
            let px = W * CGFloat(i + 1) / 5.0
            var pole = Path()
            pole.move(to: CGPoint(x: px, y: 0))
            pole.addLine(to: CGPoint(x: px, y: lineY + 8))
            ctx.stroke(pole, with: .color(Color.black.opacity(0.55)), lineWidth: 2.5)
            // Crossbar
            var crossbar = Path()
            crossbar.move(to: CGPoint(x: px - 10, y: lineY - 6))
            crossbar.addLine(to: CGPoint(x: px + 10, y: lineY - 6))
            ctx.stroke(crossbar, with: .color(Color.black.opacity(0.50)), lineWidth: 1.5)
        }
    }

    // MARK: - #15-#20 Chain-Link Fence

    private func drawChainLinkFence(ctx: inout GraphicsContext) {
        let fenceTop: CGFloat = floorY - H * 0.32
        let fenceBot: CGFloat = floorY - H * 0.14

        // #15 Fence background tint
        ctx.fill(
            Path(CGRect(x: 0, y: fenceTop, width: W, height: fenceBot - fenceTop)),
            with: .color(Color.white.opacity(0.015))
        )

        // #16 Horizontal fence rails
        for rail in 0..<4 {
            let ry = fenceTop + (fenceBot - fenceTop) * CGFloat(rail) / 3.0
            var railPath = Path()
            railPath.move(to: CGPoint(x: 0, y: ry))
            railPath.addLine(to: CGPoint(x: W, y: ry))
            ctx.stroke(railPath, with: .color(Color.white.opacity(0.06)), lineWidth: 0.7)
        }

        // #17 Chain-link diagonal lines (/) pattern
        let spacing: CGFloat = 12
        var x: CGFloat = 0
        while x < W + spacing {
            var diag = Path()
            diag.move(to: CGPoint(x: x, y: fenceTop))
            diag.addLine(to: CGPoint(x: x - (fenceBot - fenceTop), y: fenceBot))
            ctx.stroke(diag, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
            x += spacing
        }

        // #18 Chain-link diagonal lines (\) pattern
        x = -W
        while x < W + spacing {
            var diag2 = Path()
            diag2.move(to: CGPoint(x: x, y: fenceTop))
            diag2.addLine(to: CGPoint(x: x + (fenceBot - fenceTop), y: fenceBot))
            ctx.stroke(diag2, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
            x += spacing
        }

        // #19 Fence posts
        for i in 0..<8 {
            let px = W * CGFloat(i) / 7.0
            var post = Path()
            post.move(to: CGPoint(x: px, y: fenceTop))
            post.addLine(to: CGPoint(x: px, y: fenceBot))
            ctx.stroke(post, with: .color(Color.white.opacity(0.08)), lineWidth: 1.2)
        }

        // #20 Top fence rail (thicker)
        var topRail = Path()
        topRail.move(to: CGPoint(x: 0, y: fenceTop))
        topRail.addLine(to: CGPoint(x: W, y: fenceTop))
        ctx.stroke(topRail, with: .color(Color.white.opacity(0.12)), lineWidth: 1.5)
    }

    // MARK: - #21-#22 Streetlights

    private func drawStreetlights(ctx: inout GraphicsContext) {
        let lights: [(x: CGFloat, poleH: CGFloat)] = [
            (W * 0.18, H * 0.46),
            (rimX + 10, H * 0.50)
        ]

        for light in lights {
            // #21 Streetlight pole
            var pole = Path()
            pole.move(to: CGPoint(x: light.x, y: floorY))
            pole.addLine(to: CGPoint(x: light.x, y: floorY - light.poleH))
            ctx.stroke(pole, with: .color(Color(red: 0.65, green: 0.65, blue: 0.70).opacity(0.55)), lineWidth: 3)

            // Arm extending right
            var arm = Path()
            arm.move(to: CGPoint(x: light.x, y: floorY - light.poleH))
            arm.addLine(to: CGPoint(x: light.x + 18, y: floorY - light.poleH + 6))
            ctx.stroke(arm, with: .color(Color.white.opacity(0.40)), lineWidth: 2)

            // #22 Glow halo around light bulb
            var glowCtx = ctx
            glowCtx.addFilter(.blur(radius: 14))
            let bulbX = light.x + 18
            let bulbY = floorY - light.poleH + 6
            glowCtx.fill(
                Path(ellipseIn: CGRect(x: bulbX - 16, y: bulbY - 16, width: 32, height: 32)),
                with: .color(Color(red: 1.0, green: 0.92, blue: 0.55).opacity(0.55))
            )
            // Actual bulb
            ctx.fill(
                Path(ellipseIn: CGRect(x: bulbX - 5, y: bulbY - 5, width: 10, height: 10)),
                with: .color(Color(red: 1.0, green: 0.96, blue: 0.80))
            )

            // Secondary inner glow ring (animated flicker)
            let flicker = 0.50 + 0.15 * sin(t * 7.3 + Double(light.x))
            var flickerCtx = ctx
            flickerCtx.addFilter(.blur(radius: 8))
            flickerCtx.fill(
                Path(ellipseIn: CGRect(x: bulbX - 10, y: bulbY - 10, width: 20, height: 20)),
                with: .color(Color(red: 1.0, green: 0.92, blue: 0.55).opacity(flicker))
            )
            // Light fixture housing box
            ctx.fill(
                Path(CGRect(x: bulbX - 7, y: bulbY - 4, width: 14, height: 5)),
                with: .color(Color(red: 0.55, green: 0.55, blue: 0.60).opacity(0.70))
            )
        }
    }

    // MARK: - #23-#29 Court (asphalt half-court)

    private func drawCourt(ctx: inout GraphicsContext) {
        // #23 Asphalt floor fill
        ctx.fill(
            Path(CGRect(x: 0, y: floorY, width: W, height: H - floorY)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.17, green: 0.17, blue: 0.20),
                    Color(red: 0.12, green: 0.12, blue: 0.14)
                ]),
                startPoint: CGPoint(x: W / 2, y: floorY),
                endPoint: CGPoint(x: W / 2, y: H)
            )
        )

        // #24 Floor horizon line
        var fl = Path()
        fl.move(to: CGPoint(x: 0, y: floorY))
        fl.addLine(to: CGPoint(x: W, y: floorY))
        ctx.stroke(fl, with: .color(Color.white.opacity(0.30)), lineWidth: 1.8)

        // #25 Painted lane / key (faded orange)
        ctx.fill(
            Path(CGRect(x: W * 0.46, y: floorY, width: W * 0.38, height: H * 0.30)),
            with: .color(Color(red: 0.80, green: 0.38, blue: 0.08).opacity(0.20))
        )
        ctx.stroke(
            Path(CGRect(x: W * 0.46, y: floorY, width: W * 0.38, height: H * 0.30)),
            with: .color(Color.white.opacity(0.15)), lineWidth: 1
        )

        // #26 3-point arc
        let arcCX = rimX
        var arc = Path()
        arc.addArc(
            center: CGPoint(x: arcCX, y: floorY),
            radius: W * 0.50,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        ctx.stroke(arc, with: .color(Color.white.opacity(0.18)), lineWidth: 1.2)

        // #27 Free throw circle arc
        var ftCircle = Path()
        ftCircle.addArc(
            center: CGPoint(x: W * 0.65, y: floorY),
            radius: W * 0.12,
            startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false
        )
        ctx.stroke(ftCircle, with: .color(Color.white.opacity(0.12)), lineWidth: 0.8)

        // #28 Floor glow under basket
        var glowCtx = ctx
        glowCtx.addFilter(.blur(radius: 8))
        glowCtx.fill(
            Path(ellipseIn: CGRect(x: rimX - 36, y: floorY, width: 72, height: 18)),
            with: .color(Color.orange.opacity(0.18))
        )

        // #29 Center court half-circle (half-court marker)
        var halfCircle = Path()
        halfCircle.addArc(
            center: CGPoint(x: 0, y: floorY),
            radius: W * 0.16,
            startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false
        )
        ctx.stroke(halfCircle, with: .color(Color.white.opacity(0.10)), lineWidth: 0.8)
    }

    // MARK: - #30-#37 Asphalt Cracks

    private func drawAsphaltCracks(ctx: inout GraphicsContext) {
        // 8 crack lines across the asphalt surface
        let cracks: [(sx: CGFloat, sy: CGFloat, ex: CGFloat, ey: CGFloat)] = [
            (W * 0.12, floorY + H * 0.04, W * 0.22, floorY + H * 0.09),  // #30
            (W * 0.22, floorY + H * 0.09, W * 0.18, floorY + H * 0.18),  // #31
            (W * 0.35, floorY + H * 0.02, W * 0.42, floorY + H * 0.07),  // #32
            (W * 0.42, floorY + H * 0.07, W * 0.50, floorY + H * 0.05),  // #33
            (W * 0.55, floorY + H * 0.12, W * 0.65, floorY + H * 0.20),  // #34
            (W * 0.68, floorY + H * 0.03, W * 0.72, floorY + H * 0.10),  // #35
            (W * 0.78, floorY + H * 0.15, W * 0.88, floorY + H * 0.22),  // #36
            (W * 0.15, floorY + H * 0.22, W * 0.08, floorY + H * 0.28),  // #37
        ]

        for crack in cracks {
            var crackPath = Path()
            crackPath.move(to: CGPoint(x: crack.sx, y: crack.sy))
            crackPath.addLine(to: CGPoint(x: crack.ex, y: crack.ey))
            ctx.stroke(crackPath, with: .color(Color.black.opacity(0.38)), lineWidth: 0.8)
            // Branch crack
            let midX = (crack.sx + crack.ex) / 2
            let midY = (crack.sy + crack.ey) / 2
            var branch = Path()
            branch.move(to: CGPoint(x: midX, y: midY))
            branch.addLine(to: CGPoint(x: midX + (crack.ey - crack.sy) * 0.4, y: midY - (crack.ex - crack.sx) * 0.4))
            ctx.stroke(branch, with: .color(Color.black.opacity(0.22)), lineWidth: 0.5)
        }
    }

    // MARK: - #38 Puddle Reflection

    private func drawPuddleReflection(ctx: inout GraphicsContext) {
        // #38 Puddle on asphalt near sideline
        let puddleX = W * 0.08
        let puddleY = floorY + H * 0.10
        let ripple = CGFloat(sin(t * 2.8)) * 1.5

        var puddle = ctx
        puddle.addFilter(.blur(radius: 2))
        puddle.fill(
            Path(ellipseIn: CGRect(x: puddleX - 20, y: puddleY - 5 + ripple, width: 40, height: 10)),
            with: .color(Color(red: 0.55, green: 0.40, blue: 0.22).opacity(0.30))
        )
        // Puddle reflection shimmer
        var shimmer = Path()
        shimmer.move(to: CGPoint(x: puddleX - 12, y: puddleY + ripple))
        shimmer.addLine(to: CGPoint(x: puddleX + 12, y: puddleY + ripple))
        ctx.stroke(shimmer, with: .color(Color.white.opacity(0.12 + 0.08 * sin(t * 4.0))), lineWidth: 1)
    }

    // MARK: - #39-#41 Trash Can

    private func drawTrashCan(ctx: inout GraphicsContext) {
        let tcX = W * 0.93
        let tcY = floorY
        let liftOffset: CGFloat = posterizeActive ? CGFloat(sin(t * 8.0)) * 6 : 0

        // #39 Trash can body
        let canRect = CGRect(x: tcX - 8, y: tcY - 22, width: 16, height: 22)
        ctx.fill(Path(canRect), with: .color(Color(red: 0.35, green: 0.35, blue: 0.38).opacity(0.85)))
        ctx.stroke(Path(canRect), with: .color(Color.white.opacity(0.18)), lineWidth: 0.8)

        // #40 Trash can lid
        let lidY = tcY - 22 - liftOffset
        let lidRect = CGRect(x: tcX - 9, y: lidY - 4, width: 18, height: 4)
        ctx.fill(Path(lidRect), with: .color(Color(red: 0.45, green: 0.45, blue: 0.48).opacity(0.85)))
        ctx.stroke(Path(lidRect), with: .color(Color.white.opacity(0.20)), lineWidth: 0.7)

        // #41 Trash can handle lines
        for i in 0..<3 {
            var line = Path()
            let lineY = tcY - 6 - CGFloat(i) * 5
            line.move(to: CGPoint(x: tcX - 7, y: lineY))
            line.addLine(to: CGPoint(x: tcX + 7, y: lineY))
            ctx.stroke(line, with: .color(Color.white.opacity(0.10)), lineWidth: 0.5)
        }
    }

    // MARK: - #42-#49 Basket

    private func drawBasket(ctx: inout GraphicsContext) {
        // #42 Pole
        var pole = Path()
        pole.move(to: CGPoint(x: bbX + 4, y: floorY))
        pole.addLine(to: CGPoint(x: bbX + 4, y: rimY - 50))
        ctx.stroke(pole, with: .color(Color.white.opacity(0.28)), lineWidth: 3)

        // #43 Chain net pole arm
        var arm = Path()
        arm.move(to: CGPoint(x: bbX + 4, y: rimY - 50))
        arm.addLine(to: CGPoint(x: bbX - 8, y: rimY - 42))
        ctx.stroke(arm, with: .color(Color.white.opacity(0.22)), lineWidth: 2)

        // #44 Backboard glass panel
        let bbRect = CGRect(x: bbX, y: rimY - 50, width: 10, height: 42)
        var boardGlow = ctx
        boardGlow.addFilter(.blur(radius: 4))
        boardGlow.fill(Path(bbRect), with: .color(Color.white.opacity(0.08)))
        ctx.fill(Path(bbRect), with: .color(Color(red: 0.80, green: 0.85, blue: 0.90).opacity(0.68)))
        ctx.stroke(Path(bbRect), with: .color(Color.white.opacity(0.50)), lineWidth: 1)

        // #45 Target square on backboard
        ctx.stroke(
            Path(CGRect(x: bbX - 1, y: rimY - 32, width: 12, height: 14)),
            with: .color(Color.red.opacity(0.55)), lineWidth: 1
        )

        // #46 Rim with orange glow
        let rimL = rimX - 18
        let rimR = rimX + 2
        var rim = Path()
        rim.move(to: CGPoint(x: rimL, y: rimY))
        rim.addLine(to: CGPoint(x: rimR, y: rimY))
        var gc = ctx
        gc.addFilter(.shadow(color: Color.orange.opacity(0.85), radius: 5))
        gc.stroke(rim, with: .color(Color.orange), lineWidth: 4)

        // #47 Net vertical strands (chain/zigzag style)
        for i in 0...5 {
            let tf = CGFloat(i) / 5.0
            let nx = rimL + (rimR - rimL) * tf
            let ny = rimY + 20 * (1 + abs(tf - 0.5) * 0.4)
            var s = Path()
            s.move(to: CGPoint(x: nx, y: rimY))
            s.addLine(to: CGPoint(x: nx + (0.5 - tf) * 4, y: ny))
            ctx.stroke(s, with: .color(Color.white.opacity(0.22)), lineWidth: 0.8)
        }

        // #48 Net cross-rungs
        for rung in 1...2 {
            let rf = CGFloat(rung) / 3.0
            let ry = rimY + 20 * 0.8 * rf
            let sh = (rimR - rimL) * 0.10 * rf
            var r = Path()
            r.move(to: CGPoint(x: rimL + sh, y: ry))
            r.addLine(to: CGPoint(x: rimR - sh, y: ry))
            ctx.stroke(r, with: .color(Color.white.opacity(0.12)), lineWidth: 0.7)
        }

        // #49 Backboard hit flash when shot arrives (ep > 0.85 and not made)
        if shotProgress > 0.85 && !shotMade {
            let flashAlpha = max(0.0, (1.0 - (shotProgress - 0.85) / 0.15) * 0.6)
            var flashCtx = ctx
            flashCtx.addFilter(.blur(radius: 6))
            flashCtx.fill(
                Path(CGRect(x: bbX - 4, y: rimY - 52, width: 20, height: 46)),
                with: .color(Color.white.opacity(flashAlpha))
            )
        }
    }

    // MARK: - #50-#54 Spectators

    private func drawSpectators(ctx: inout GraphicsContext) {
        let row1Y = floorY - H * 0.28
        let row2Y = floorY - H * 0.21
        let jerseyColors: [Color] = [.red, .blue, .yellow, .green, .white, .orange, .purple, .cyan]

        for row in 0..<2 {
            let ry = row == 0 ? row1Y : row2Y
            let count = 10 + row * 2

            for i in 0..<count {
                let sx = W * (CGFloat(i) + 0.5) / CGFloat(count)
                let bob = CGFloat(sin(t * 1.8 + Double(i) * 0.6 + Double(row))) * 3
                let cheer = showConfetti ? CGFloat(sin(t * 4.0 + Double(i))) * 5 : 0
                let r: CGFloat = 4.5 + CGFloat(row) * 0.5
                let jc = jerseyColors[(i * 3 + row) % jerseyColors.count]

                // #50 Spectator heads (skin tone ellipses)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: sx - r * 0.9, y: ry - bob - cheer - r * 1.8, width: r * 1.8, height: r * 1.8)),
                    with: .color(Color(red: 0.88, green: 0.72, blue: 0.58).opacity(0.55))
                )

                // #51 Spectator jersey bodies
                ctx.fill(
                    Path(CGRect(x: sx - r * 0.8, y: ry - bob - cheer, width: r * 1.6, height: r * 1.8)),
                    with: .color(jc.opacity(0.48 + Double(row) * 0.10))
                )

                // #52 Arms raised on confetti
                if showConfetti {
                    var armL = Path()
                    armL.move(to: CGPoint(x: sx - r * 0.8, y: ry - bob - cheer + r * 0.5))
                    armL.addLine(to: CGPoint(x: sx - r * 1.6, y: ry - bob - cheer - r * 0.5))
                    ctx.stroke(armL, with: .color(jc.opacity(0.40)), lineWidth: 1.2)
                    var armR = Path()
                    armR.move(to: CGPoint(x: sx + r * 0.8, y: ry - bob - cheer + r * 0.5))
                    armR.addLine(to: CGPoint(x: sx + r * 1.6, y: ry - bob - cheer - r * 0.5))
                    ctx.stroke(armR, with: .color(jc.opacity(0.40)), lineWidth: 1.2)
                }
            }
        }

        // #53 Fence line behind spectators
        var fenceLine = Path()
        fenceLine.move(to: CGPoint(x: 0, y: row1Y - H * 0.03))
        fenceLine.addLine(to: CGPoint(x: W, y: row1Y - H * 0.03))
        ctx.stroke(fenceLine, with: .color(Color.white.opacity(0.05)), lineWidth: 0.8)

        // #54 Spectator row shadow base
        var rowShadow = ctx
        rowShadow.addFilter(.blur(radius: 4))
        rowShadow.fill(
            Path(CGRect(x: 0, y: row2Y + 6, width: W, height: 6)),
            with: .color(Color.black.opacity(0.25))
        )
    }

    // MARK: - #55 Game Clock Display on Fence

    private func drawGameClock(ctx: inout GraphicsContext) {
        // #55 Score display panel on fence (scoreboard look)
        let sbX = W * 0.38
        let sbY = floorY - H * 0.32
        let sbW: CGFloat = W * 0.24
        let sbH: CGFloat = H * 0.06

        var sbBack = Path()
        sbBack.addRoundedRect(
            in: CGRect(x: sbX, y: sbY, width: sbW, height: sbH),
            cornerSize: CGSize(width: 4, height: 4)
        )
        ctx.fill(sbBack, with: .color(Color.black.opacity(0.70)))
        var sbBorder = ctx
        sbBorder.addFilter(.blur(radius: 2))
        sbBorder.stroke(sbBack, with: .color(Color.orange.opacity(0.45)), lineWidth: 1.5)
        ctx.stroke(sbBack, with: .color(Color.orange.opacity(0.35)), lineWidth: 1.0)

        // Scoreboard decorative divider line
        var divider = Path()
        divider.move(to: CGPoint(x: sbX + sbW * 0.5, y: sbY + 4))
        divider.addLine(to: CGPoint(x: sbX + sbW * 0.5, y: sbY + sbH - 4))
        ctx.stroke(divider, with: .color(Color.orange.opacity(0.25)), lineWidth: 0.8)

        // Corner accent dots on scoreboard
        for corner in [(sbX + 4, sbY + 4), (sbX + sbW - 4, sbY + 4),
                       (sbX + 4, sbY + sbH - 4), (sbX + sbW - 4, sbY + sbH - 4)] as [(CGFloat, CGFloat)] {
            ctx.fill(
                Path(ellipseIn: CGRect(x: corner.0 - 2, y: corner.1 - 2, width: 4, height: 4)),
                with: .color(Color.orange.opacity(0.40))
            )
        }

        // LED-style row of indicator dots across top of scoreboard
        for dot in 0..<6 {
            let dx = sbX + 8 + CGFloat(dot) * ((sbW - 16) / 5)
            let pulsed = 0.3 + 0.4 * sin(t * 2.5 + Double(dot) * 0.8)
            ctx.fill(
                Path(ellipseIn: CGRect(x: dx - 2, y: sbY + 3, width: 4, height: 4)),
                with: .color(Color.orange.opacity(pulsed))
            )
        }
    }

    // MARK: - #56-#57 Score Spray Paint Style Text

    private func drawScoreSprayPaint(ctx: inout GraphicsContext) {
        // #56 Spray-paint score area glow — player side (blue)
        var sprayCtx = ctx
        sprayCtx.addFilter(.blur(radius: 10))
        sprayCtx.fill(
            Path(ellipseIn: CGRect(x: W * 0.10, y: floorY - H * 0.05, width: W * 0.25, height: H * 0.04)),
            with: .color(Color(red: 0.18, green: 0.78, blue: 1.0).opacity(0.14))
        )
        // Secondary spray haze
        sprayCtx.fill(
            Path(ellipseIn: CGRect(x: W * 0.06, y: floorY - H * 0.08, width: W * 0.32, height: H * 0.06)),
            with: .color(Color(red: 0.18, green: 0.78, blue: 1.0).opacity(0.06))
        )

        // #57 Opponent side spray glow — red
        var sprayCtx2 = ctx
        sprayCtx2.addFilter(.blur(radius: 10))
        sprayCtx2.fill(
            Path(ellipseIn: CGRect(x: W * 0.62, y: floorY - H * 0.05, width: W * 0.25, height: H * 0.04)),
            with: .color(Color(red: 1.0, green: 0.25, blue: 0.25).opacity(0.14))
        )
        // Secondary spray haze
        sprayCtx2.fill(
            Path(ellipseIn: CGRect(x: W * 0.58, y: floorY - H * 0.08, width: W * 0.32, height: H * 0.06)),
            with: .color(Color(red: 1.0, green: 0.25, blue: 0.25).opacity(0.06))
        )
    }

    // MARK: - #58 Hot Hand Aura

    private func drawHotHandAura(ctx: inout GraphicsContext) {
        // #58 Pulsing orange glow around player when hot hand active
        let auraRadius: CGFloat = 32 + CGFloat(sin(t * 4.0)) * 8
        var auraCtx = ctx
        auraCtx.addFilter(.blur(radius: 16))
        auraCtx.fill(
            Path(ellipseIn: CGRect(x: playerX - auraRadius, y: playerY - auraRadius * 2.5, width: auraRadius * 2, height: auraRadius * 2.5)),
            with: .color(Color.orange.opacity(0.45 + 0.15 * sin(t * 4.0)))
        )

        // Secondary inner glow
        var innerGlow = ctx
        innerGlow.addFilter(.blur(radius: 6))
        innerGlow.fill(
            Path(ellipseIn: CGRect(x: playerX - 18, y: playerY - 52, width: 36, height: 52)),
            with: .color(Color(red: 1.0, green: 0.65, blue: 0.0).opacity(0.35))
        )
    }

    // MARK: - #59-#64 Ball Arc

    private func drawBallArc(ctx: inout GraphicsContext) {
        let ep = CGFloat(shotProgress)
        let br: CGFloat = 7

        // Start: player hand, End: rim center
        let sx = playerX + 12
        let sy = playerY - 52
        let ex = (rimX - 16 + rimX + 2) / 2
        let ey = rimY - 5

        let bx = sx + (ex - sx) * ep
        let by = sy + (ey - sy) * ep - H * 0.32 * 4 * ep * (1 - ep)

        // #59 Ball trail ghosts
        for trail in 1...3 {
            let pastEp = max(0, ep - CGFloat(trail) * 0.07)
            let tbx = sx + (ex - sx) * pastEp
            let tby = sy + (ey - sy) * pastEp - H * 0.32 * 4 * pastEp * (1 - pastEp)
            ctx.fill(
                Path(ellipseIn: CGRect(x: tbx - br, y: tby - br, width: br * 2, height: br * 2)),
                with: .color(Color.orange.opacity(0.20 - Double(trail) * 0.05))
            )
        }

        // #60 Ball glow
        var ballGlow = ctx
        ballGlow.addFilter(.blur(radius: 6))
        ballGlow.fill(
            Path(ellipseIn: CGRect(x: bx - br - 3, y: by - br - 3, width: (br + 3) * 2, height: (br + 3) * 2)),
            with: .color(Color.orange.opacity(0.35))
        )

        // #61 Main ball body
        ctx.fill(
            Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
            with: .color(Color.orange)
        )

        // #62 Ball rotation seam 1
        var seam = Path()
        seam.addArc(
            center: CGPoint(x: bx, y: by),
            radius: br * 0.75,
            startAngle: .degrees(-50 + Double(ep) * 180),
            endAngle: .degrees(190 + Double(ep) * 180),
            clockwise: false
        )
        ctx.stroke(seam, with: .color(Color.black.opacity(0.35)), lineWidth: 0.9)

        // #63 Ball rotation seam 2 (perpendicular hash marks)
        var seam2 = Path()
        seam2.addArc(
            center: CGPoint(x: bx, y: by),
            radius: br * 0.75,
            startAngle: .degrees(-140 + Double(ep) * 180),
            endAngle: .degrees(100 + Double(ep) * 180),
            clockwise: false
        )
        ctx.stroke(seam2, with: .color(Color.black.opacity(0.25)), lineWidth: 0.9)

        // #64 Impact burst ring when ball approaches rim (ep > 0.85)
        if ep > 0.85 {
            let impactFrac = (ep - 0.85) / 0.15
            let burstR = CGFloat(impactFrac) * 24
            var ring = Path()
            ring.addEllipse(in: CGRect(x: ex - burstR, y: ey - burstR * 0.5, width: burstR * 2, height: burstR))
            ctx.stroke(ring, with: .color(Color.orange.opacity(max(0, 0.85 - impactFrac * 0.9))), lineWidth: 2)
        }

        // #65 Air ball tumble arc indicator (when ball will miss — shotProgress > 0.5)
        if ep > 0.50 && !shotMade {
            let tumbleFrac = (ep - 0.50) / 0.50
            let tx = ex + CGFloat(tumbleFrac) * 20
            let ty = ey + CGFloat(tumbleFrac * tumbleFrac) * 30
            var tumblePath = Path()
            tumblePath.addArc(
                center: CGPoint(x: tx, y: ty),
                radius: br * 0.6,
                startAngle: .degrees(0), endAngle: .degrees(270), clockwise: false
            )
            ctx.stroke(tumblePath, with: .color(Color.orange.opacity(0.20 * (1 - tumbleFrac))), lineWidth: 1)
        }
    }

    // MARK: - #66-#67 Dribble animation

    private func drawDribble(ctx: inout GraphicsContext) {
        let ballR: CGFloat = 7
        let who = possession == .player
        let cx = who ? playerX + 12 : opponentX - 12
        let fy = who ? playerY : opponentY
        let bounce = abs(sin(t * .pi / 0.38)) * 18
        let by = fy - CGFloat(bounce) - 6

        // #66 Dribble ball glow
        var bc = ctx
        bc.addFilter(.shadow(color: Color.orange.opacity(0.45), radius: 4))
        bc.fill(
            Path(ellipseIn: CGRect(x: cx - ballR, y: by - ballR, width: ballR * 2, height: ballR * 2)),
            with: .color(Color.orange)
        )

        // #67 Dribble seam
        var seam = Path()
        seam.addArc(
            center: CGPoint(x: cx, y: by),
            radius: ballR * 0.75,
            startAngle: .degrees(-50), endAngle: .degrees(190), clockwise: false
        )
        ctx.stroke(seam, with: .color(Color.black.opacity(0.28)), lineWidth: 0.9)

        // Bounce shadow on floor
        let shadowScale = CGFloat(bounce) / 18.0
        var bounceShadow = ctx
        bounceShadow.addFilter(.blur(radius: 2))
        bounceShadow.fill(
            Path(ellipseIn: CGRect(x: cx - 9 * shadowScale, y: fy - 2, width: 18 * shadowScale, height: 4)),
            with: .color(Color.black.opacity(0.35 * shadowScale))
        )
    }

    // MARK: - #68 Swish Net animation

    private func drawSwishNet(ctx: inout GraphicsContext) {
        let rimL = rimX - 18
        let rimR2 = rimX + 2
        let swing = CGFloat(sin(t * 6.0)) * 5

        // #68 Animated net swing strands
        for i in 0...5 {
            let tf = CGFloat(i) / 5.0
            let nx = rimL + (rimR2 - rimL) * tf
            let ny = rimY + 20 * (1 + abs(tf - 0.5) * 0.4) + swing * abs(tf - 0.5)
            var s = Path()
            s.move(to: CGPoint(x: nx, y: rimY))
            s.addLine(to: CGPoint(x: nx + (0.5 - tf) * 4 + swing * 0.3, y: ny))
            ctx.stroke(s, with: .color(Color.white.opacity(0.50)), lineWidth: 1)
        }

        // Net bottom ripple
        var bottomRipple = Path()
        bottomRipple.move(to: CGPoint(x: rimL + 2 + swing * 0.5, y: rimY + 18))
        bottomRipple.addLine(to: CGPoint(x: rimR2 - 2 + swing * 0.3, y: rimY + 18))
        ctx.stroke(bottomRipple, with: .color(Color.white.opacity(0.30)), lineWidth: 0.8)
    }

    // MARK: - #69 Ground shadows

    private func drawPlayerShadow(ctx: inout GraphicsContext) {
        // #69 Elliptical ground shadows for both players
        func shadow(_ cx: CGFloat, _ fy: CGFloat) {
            var shadowCtx = ctx
            shadowCtx.addFilter(.blur(radius: 3))
            shadowCtx.fill(
                Path(ellipseIn: CGRect(x: cx - 18, y: fy + 2, width: 36, height: 7)),
                with: .color(Color.black.opacity(0.35))
            )
        }
        shadow(playerX, playerY)
        shadow(opponentX, opponentY)
    }

    // MARK: - #70-#72 Sweat particles

    private func drawSweatParticles(ctx: inout GraphicsContext) {
        // #70 Sweat dots around player (3 particles)
        let sweatOffset1 = CGFloat(sin(t * 3.2)) * 4
        let sweatOffset2 = CGFloat(cos(t * 2.8)) * 3

        // dot 1
        ctx.fill(
            Path(ellipseIn: CGRect(x: playerX + 20 + sweatOffset1, y: playerY - 58, width: 3, height: 3)),
            with: .color(Color(red: 0.6, green: 0.85, blue: 1.0).opacity(0.55))
        )
        // #71 dot 2
        ctx.fill(
            Path(ellipseIn: CGRect(x: playerX - 18 + sweatOffset2, y: playerY - 62, width: 2.5, height: 2.5)),
            with: .color(Color(red: 0.6, green: 0.85, blue: 1.0).opacity(0.45))
        )
        // #72 dot 3
        ctx.fill(
            Path(ellipseIn: CGRect(x: playerX + 10, y: playerY - 72 + sweatOffset1, width: 2, height: 2)),
            with: .color(Color(red: 0.6, green: 0.85, blue: 1.0).opacity(0.35))
        )
    }

    // MARK: - #73-#80 Stick Figures

    private func drawStickFigure(ctx: inout GraphicsContext, cx: CGFloat, fy: CGFloat,
                                  pose: String, color: Color, flip: Bool) {
        let sc: CGFloat = H * 0.0030
        let m: CGFloat = flip ? -1 : 1
        let headR = sc * 9
        let bodyH = sc * 28
        let lw: CGFloat = 3.5

        let shoulderY = fy - bodyH - headR * 1.8
        let hipY = shoulderY + bodyH

        let cycle = t.truncatingRemainder(dividingBy: 0.55) / 0.55
        let sinC = CGFloat(sin(cycle * .pi * 2))

        // #73 Head glow
        var hglow = ctx
        hglow.addFilter(.shadow(color: color.opacity(0.40), radius: 7))
        hglow.fill(
            Path(ellipseIn: CGRect(x: cx - headR, y: shoulderY - headR * 1.8, width: headR * 2, height: headR * 2)),
            with: .color(Color(red: 0.94, green: 0.81, blue: 0.70))
        )

        // #74 Torso / spine line
        var spine = Path()
        spine.move(to: CGPoint(x: cx, y: shoulderY))
        spine.addLine(to: CGPoint(x: cx, y: hipY))
        ctx.stroke(spine, with: .color(color), lineWidth: lw)

        func line(_ a: CGPoint, _ b: CGPoint) {
            var p = Path(); p.move(to: a); p.addLine(to: b)
            ctx.stroke(p, with: .color(color), lineWidth: lw)
        }

        let shoeColor = Color(red: 0.92, green: 0.35, blue: 0.08)

        switch pose {
        case "shoot":
            // #75 Shoot pose: upper arm raise (release arm)
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 22, y: shoulderY - 18))
            line(CGPoint(x: cx + m * 22, y: shoulderY - 18), CGPoint(x: cx + m * 30, y: shoulderY - 34))
            // #76 Shoot pose: off arm guide
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 14, y: shoulderY + 16))
            // #77 Shoot pose: legs push-off
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 14, y: hipY + 16))
            line(CGPoint(x: cx + m * 14, y: hipY + 16), CGPoint(x: cx + m * 10, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 10, y: hipY + 18))
            line(CGPoint(x: cx - m * 10, y: hipY + 18), CGPoint(x: cx - m * 8, y: fy))
            ctx.fill(Path(CGRect(x: cx + m * 7, y: fy - 5, width: m * 14, height: 5)), with: .color(shoeColor))
        case "crossover":
            // #78 Crossover pose: dribble arm low
            let shimmy: CGFloat = ankleShimmy ? CGFloat(sin(t * 12)) * 4 : 0
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 20 + shimmy, y: hipY - 8))
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 18, y: shoulderY + 18))
            // #79 Crossover pose: wide spread legs
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 18 + shimmy, y: hipY + 18))
            line(CGPoint(x: cx + m * 18 + shimmy, y: hipY + 18), CGPoint(x: cx + m * 12 + shimmy, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 14, y: hipY + 16))
            line(CGPoint(x: cx - m * 14, y: hipY + 16), CGPoint(x: cx - m * 10, y: fy))
            ctx.fill(Path(CGRect(x: cx + m * 8 + shimmy, y: fy - 5, width: m * 14, height: 5)), with: .color(shoeColor))
        case "drive":
            // #80 Drive pose: leaning forward aggressively
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 24, y: shoulderY + 10))
            line(CGPoint(x: cx + m * 24, y: shoulderY + 10), CGPoint(x: cx + m * 36, y: shoulderY))
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 12, y: shoulderY + 20))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 22, y: hipY + 14))
            line(CGPoint(x: cx + m * 22, y: hipY + 14), CGPoint(x: cx + m * 28, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 8, y: hipY + 20))
            line(CGPoint(x: cx - m * 8, y: hipY + 20), CGPoint(x: cx - m * 4, y: fy))
            ctx.fill(Path(CGRect(x: cx + m * 22, y: fy - 5, width: m * 14, height: 5)), with: .color(shoeColor))
        case "guard", "defend":
            // #81 (re-numbered) Guard/defend pose: wide stance arms out
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 26, y: shoulderY + 10))
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 26, y: shoulderY + 10))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 18, y: hipY + 16))
            line(CGPoint(x: cx + m * 18, y: hipY + 16), CGPoint(x: cx + m * 14, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 18, y: hipY + 16))
            line(CGPoint(x: cx - m * 18, y: hipY + 16), CGPoint(x: cx - m * 14, y: fy))
            ctx.fill(Path(CGRect(x: cx + m * 10, y: fy - 5, width: m * 14, height: 5)), with: .color(shoeColor))
        case "block":
            // One arm up to block
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 10, y: shoulderY - 28))
            line(CGPoint(x: cx + m * 10, y: shoulderY - 28), CGPoint(x: cx + m * 8, y: shoulderY - 44))
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 16, y: shoulderY + 18))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 10, y: hipY + 18))
            line(CGPoint(x: cx + m * 10, y: hipY + 18), CGPoint(x: cx + m * 8, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 12, y: hipY + 16))
            line(CGPoint(x: cx - m * 12, y: hipY + 16), CGPoint(x: cx - m * 10, y: fy))
        case "post", "screen":
            // Post-up / screen: wide stance, arms forward
            let postLean = CGFloat(sin(t * 2.0)) * 2
            line(CGPoint(x: cx, y: shoulderY + 4 + postLean), CGPoint(x: cx + m * 22, y: hipY - 12))
            line(CGPoint(x: cx, y: shoulderY + 4 + postLean), CGPoint(x: cx - m * 20, y: hipY - 10))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 20, y: hipY + 16))
            line(CGPoint(x: cx + m * 20, y: hipY + 16), CGPoint(x: cx + m * 15, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 20, y: hipY + 16))
            line(CGPoint(x: cx - m * 20, y: hipY + 16), CGPoint(x: cx - m * 15, y: fy))
            ctx.fill(Path(CGRect(x: cx + m * 10, y: fy - 5, width: m * 14, height: 5)), with: .color(shoeColor))
        default:
            // Idle — bob + dribble-ready stance
            let bob = CGFloat(sin(t * 1.6)) * 1.5
            line(CGPoint(x: cx, y: shoulderY + 4 + bob), CGPoint(x: cx + m * 18 * sinC, y: hipY - 6 + bob))
            line(CGPoint(x: cx, y: shoulderY + 4 + bob), CGPoint(x: cx - m * 16 * sinC, y: shoulderY + 18 + bob))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 12, y: hipY + 18))
            line(CGPoint(x: cx + m * 12, y: hipY + 18), CGPoint(x: cx + m * 8, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 10, y: hipY + 16))
            line(CGPoint(x: cx - m * 10, y: hipY + 16), CGPoint(x: cx - m * 8, y: fy))
            ctx.fill(Path(CGRect(x: cx + m * 5, y: fy - 5, width: m * 12, height: 5)), with: .color(shoeColor))
        }
    }

    // MARK: - #82 Crossover dust

    private func drawCrossoverDust(ctx: inout GraphicsContext) {
        // #82 Step-back crossover dust cloud at player feet
        for i in 0..<6 {
            let fi = Double(i)
            let dustX = playerX - 10 + CGFloat(i) * 5 + CGFloat(sin(t * 8 + fi)) * 4
            let dustY = playerY - 2
            let dustR: CGFloat = 3 + CGFloat(i) * 1.5
            let dustAlpha = max(0, 0.45 - Double(i) * 0.07)
            var dustCtx = ctx
            dustCtx.addFilter(.blur(radius: 2))
            dustCtx.fill(
                Path(ellipseIn: CGRect(x: dustX - dustR, y: dustY - dustR * 0.5, width: dustR * 2, height: dustR)),
                with: .color(Color(red: 0.75, green: 0.70, blue: 0.65).opacity(dustAlpha))
            )
        }
    }

    // MARK: - #83 Ankle-breaker shimmy

    private func drawAnkleShimmy(ctx: inout GraphicsContext) {
        // #83 Zigzag shimmy lines radiating from player feet
        let shimFreq = t * 14
        for i in 0..<5 {
            let fi = CGFloat(i)
            var shimPath = Path()
            let startX = playerX - 20 + fi * 10
            shimPath.move(to: CGPoint(x: startX, y: playerY - 4))
            shimPath.addLine(to: CGPoint(x: startX + CGFloat(sin(shimFreq + Double(i))) * 8, y: playerY - 10))
            shimPath.addLine(to: CGPoint(x: startX + CGFloat(cos(shimFreq + Double(i))) * 6, y: playerY - 16))
            ctx.stroke(shimPath, with: .color(Color.yellow.opacity(0.55 - Double(i) * 0.09)), lineWidth: 1.2)
        }
    }

    // MARK: - #84 Posterize impact

    private func drawPosterizeImpact(ctx: inout GraphicsContext) {
        // #84 Red impact ring (outer glow) on posterize
        let impactPulse = CGFloat(sin(t * 8.0)) * 5
        let ringR: CGFloat = 30 + impactPulse
        var ring = Path()
        ring.addEllipse(in: CGRect(x: opponentX - ringR, y: opponentY - ringR, width: ringR * 2, height: ringR * 2))
        var ringCtx = ctx
        ringCtx.addFilter(.blur(radius: 3))
        ringCtx.stroke(ring, with: .color(Color.red.opacity(0.70)), lineWidth: 3)
        // #85 Crisp inner ring
        ctx.stroke(ring, with: .color(Color.red.opacity(0.45)), lineWidth: 2)

        // #86 Star sparks around posterize ring
        for i in 0..<5 {
            let angle = Double(i) * (2 * .pi / 5) + t * 3.0
            let starX = opponentX + CGFloat(cos(angle)) * (ringR + 8)
            let starY = opponentY + CGFloat(sin(angle)) * (ringR + 8)
            var star = Path()
            star.addEllipse(in: CGRect(x: starX - 3, y: starY - 3, width: 6, height: 6))
            ctx.fill(star, with: .color(Color.yellow.opacity(0.75)))
        }
    }

    // MARK: - #87 Buzzer-shot vignette

    private func drawBuzzerVignette(ctx: inout GraphicsContext) {
        // #87 Dark vignette corners on buzzer/win moment
        let vigRadius = min(W, H) * 0.65
        var vigCtx = ctx
        vigCtx.addFilter(.blur(radius: 20))
        // Top-left corner
        vigCtx.fill(
            Path(ellipseIn: CGRect(x: -vigRadius * 0.4, y: -vigRadius * 0.4, width: vigRadius, height: vigRadius)),
            with: .color(Color.black.opacity(0.55))
        )
        // Bottom-right corner
        vigCtx.fill(
            Path(ellipseIn: CGRect(x: W - vigRadius * 0.6, y: H - vigRadius * 0.6, width: vigRadius, height: vigRadius)),
            with: .color(Color.black.opacity(0.55))
        )
    }

    // MARK: - #88-#90 Crowd confetti / win banner particles

    private func drawCrowdConfetti(ctx: inout GraphicsContext) {
        // #88 Confetti background shimmer
        var shimCtx = ctx
        shimCtx.addFilter(.blur(radius: 8))
        shimCtx.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H * 0.5)),
            with: .color(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.08))
        )

        let confettiColors: [Color] = [.red, .yellow, .blue, .green, .white, .orange, .purple, .cyan]
        for i in 0..<20 {
            let fi = Double(i)
            let cx2 = W * CGFloat((i * 73 + 17) % 100) / 100.0
            let fallY = floorY * CGFloat(fmod(t * (0.6 + fi * 0.03) + fi * 0.15, 1.0))
            let confW: CGFloat = 5 + CGFloat(i % 3) * 2
            let confH: CGFloat = 3 + CGFloat(i % 2)
            let rotAngle = t * (1.5 + fi * 0.2)
            let cc = confettiColors[i % confettiColors.count]

            // #89 Each confetti rectangle (copy-transform pattern)
            var gc = ctx
            gc.translateBy(x: cx2, y: fallY)
            gc.rotate(by: .radians(rotAngle))
            gc.fill(
                Path(CGRect(x: -confW / 2, y: -confH / 2, width: confW, height: confH)),
                with: .color(cc.opacity(0.75))
            )
        }

        // #90 Crowd wave arc at spectator level during win
        let waveY = floorY - H * 0.30
        var wavePath = Path()
        wavePath.move(to: CGPoint(x: 0, y: waveY))
        for xi in stride(from: CGFloat(0), through: W, by: 8) {
            let wy = waveY + CGFloat(sin(Double(xi) / 28.0 + t * 3.5)) * 4
            wavePath.addLine(to: CGPoint(x: xi, y: wy))
        }
        ctx.stroke(wavePath, with: .color(Color.white.opacity(0.18)), lineWidth: 1.2)
    }

    // MARK: - Momentum Indicators

    private func drawMomentumIndicators(ctx: inout GraphicsContext) {
        let pipY = floorY - H * 0.02
        let pipSpacing: CGFloat = 8
        let totalPips = 3
        for i in 0..<totalPips {
            let pipX = playerX - CGFloat(totalPips - 1) * pipSpacing / 2 + CGFloat(i) * pipSpacing
            let filled = i < abs(playerMomentum)
            let pipColor: Color = playerMomentum > 0 ? Color.orange : Color(red: 0.30, green: 0.60, blue: 1.0)
            ctx.fill(
                Path(ellipseIn: CGRect(x: pipX - 3, y: pipY - 3, width: 6, height: 6)),
                with: .color(filled ? pipColor.opacity(0.90) : Color.white.opacity(0.15))
            )
        }
    }

    private func drawMomentumFlame(ctx: inout GraphicsContext) {
        let cx = playerX; let cy = floorY - H * 0.06
        let pulse = CGFloat(0.7 + 0.3 * sin(t * 5.0))
        var flameCtx = ctx
        flameCtx.addFilter(.blur(radius: 18))
        flameCtx.fill(
            Path(ellipseIn: CGRect(x: cx - 28 * pulse, y: cy - 28 * pulse, width: 56 * pulse, height: 56 * pulse)),
            with: .color(Color.orange.opacity(0.55))
        )
        var innerCtx = ctx
        innerCtx.addFilter(.blur(radius: 8))
        innerCtx.fill(
            Path(ellipseIn: CGRect(x: cx - 14, y: cy - 20, width: 28, height: 28)),
            with: .color(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.45))
        )
        ctx.draw(Text("🔥").font(.system(size: 14)), at: CGPoint(x: cx, y: cy - 32))
    }

    private func drawOnFireBorder(ctx: inout GraphicsContext) {
        let pulse = CGFloat(0.55 + 0.20 * sin(t * 4.0))
        var borderCtx = ctx
        borderCtx.addFilter(.blur(radius: 12))
        var borderPath = Path(); borderPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
        borderCtx.stroke(borderPath, with: .color(Color.orange.opacity(pulse * 0.70)), lineWidth: 18)
        let fireAlpha = 0.75 + 0.25 * sin(t * 3.5)
        ctx.draw(
            Text("ON FIRE!")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(Color.orange.opacity(fireAlpha)),
            at: CGPoint(x: W * 0.50, y: H * 0.06)
        )
    }

    private func drawIceColdOverlay(ctx: inout GraphicsContext) {
        var coldCtx = ctx
        coldCtx.addFilter(.blur(radius: 10))
        coldCtx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                     with: .color(Color(red: 0.10, green: 0.25, blue: 0.80).opacity(0.12)))
        let iceAlpha = 0.60 + 0.20 * sin(t * 2.0)
        ctx.draw(
            Text("ICE COLD")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(Color(red: 0.55, green: 0.78, blue: 1.0).opacity(iceAlpha)),
            at: CGPoint(x: playerX, y: floorY - H * 0.10)
        )
        var blueCtx = ctx
        blueCtx.addFilter(.blur(radius: 8))
        blueCtx.fill(
            Path(ellipseIn: CGRect(x: playerX - 22, y: floorY - 18, width: 44, height: 14)),
            with: .color(Color(red: 0.20, green: 0.50, blue: 1.0).opacity(0.35))
        )
    }

    // MARK: - Shot Timing Bar

    private func drawShotTimingBar(ctx: inout GraphicsContext) {
        let barW = W * 0.65; let barH: CGFloat = 14
        let barX = (W - barW) / 2; let barY = H * 0.88
        var bgPath = Path()
        bgPath.addRoundedRect(in: CGRect(x: barX, y: barY, width: barW, height: barH),
                              cornerSize: CGSize(width: 6, height: 6))
        ctx.fill(bgPath, with: .color(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92)))
        ctx.stroke(bgPath, with: .color(Color.white.opacity(0.20)), lineWidth: 1)
        // Red zones (outer 20% each side)
        let redZoneW = barW * 0.20
        ctx.fill(Path(CGRect(x: barX, y: barY, width: redZoneW, height: barH)),
                 with: .color(Color.red.opacity(0.65)))
        ctx.fill(Path(CGRect(x: barX + barW - redZoneW, y: barY, width: redZoneW, height: barH)),
                 with: .color(Color.red.opacity(0.65)))
        // Yellow zones (next 15% each side)
        let yellowZoneW = barW * 0.15
        ctx.fill(Path(CGRect(x: barX + redZoneW, y: barY, width: yellowZoneW, height: barH)),
                 with: .color(Color.yellow.opacity(0.55)))
        ctx.fill(Path(CGRect(x: barX + barW - redZoneW - yellowZoneW, y: barY, width: yellowZoneW, height: barH)),
                 with: .color(Color.yellow.opacity(0.55)))
        // Green zone: center 14% (0.43–0.57)
        let greenZoneW = barW * 0.14; let greenZoneX = barX + barW * 0.43
        ctx.fill(Path(CGRect(x: greenZoneX, y: barY, width: greenZoneW, height: barH)),
                 with: .color(Color.green.opacity(0.80)))
        // Needle
        let needleX = barX + shotTimingMeter * barW
        var needle = Path()
        needle.move(to: CGPoint(x: needleX, y: barY - 2))
        needle.addLine(to: CGPoint(x: needleX, y: barY + barH + 2))
        ctx.stroke(needle, with: .color(Color.white.opacity(0.95)), lineWidth: 2.5)
        // "RELEASE" label above bar
        ctx.draw(
            Text("RELEASE").font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.70)),
            at: CGPoint(x: W / 2, y: barY - 10)
        )
    }

    private func drawTimingFeedback(ctx: inout GraphicsContext) {
        guard let result = timingResult else { return }
        let riseY = H * 0.40 - CGFloat(1.0 - timingFeedbackOpacity) * 30
        var textCtx = ctx; textCtx.opacity = timingFeedbackOpacity
        textCtx.draw(
            Text(result.label)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(result.color),
            at: CGPoint(x: (rimX - 18 + rimX + 2) / 2, y: riseY)
        )
    }
}

// MARK: - Main View

struct BasketballH2HGameView: View {
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var phase: H2HPhase = .difficultySelect
    @State private var selectedDifficulty: AIDifficulty = .pro
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var shotClock: Int = 24
    @State private var shotClockTask: Task<Void, Never>?
    @State private var opponentTask: Task<Void, Never>?
    @State private var comboCount: Int = 0
    @State private var comboMultiplier: Int = 1
    @State private var lastShotResult: ShotResult?
    @State private var showShotLabel: Bool = false
    @State private var possession: H2HPossession = .player
    @State private var shardsRewarded: Bool = false
    @State private var fakeActive: Bool = false      // true after a successful fake; reduces block chance on next shot

    // Canvas state
    @State private var shotProgress: Double = -1   // -1 = no shot, 0→1 = arc
    @State private var shotMade: Bool = false
    @State private var shotAnimTask: Task<Void, Never>?
    @State private var playerPose: String = "idle"
    @State private var opponentPose: String = "guard"
    @State private var rimShake: Double = 0
    @State private var screenShake: CGFloat = 0

    // Enhanced FX state
    @State private var showConfetti: Bool = false
    @State private var hotHandActive: Bool = false
    @State private var posterizeActive: Bool = false
    @State private var ankleShimmy: Bool = false
    @State private var dustActive: Bool = false

    // Shot timing mechanic
    @State private var shotTimingMeter: CGFloat = 0
    @State private var shotTimingActive: Bool = false
    @State private var timingResult: TimingResult? = nil
    @State private var timingFeedbackOpacity: Double = 0
    @State private var shotTimingTask: Task<Void, Never>?
    @State private var autoFireTask: Task<Void, Never>?

    // Momentum / hot-cold system
    @State private var playerMomentum: Int = 0    // -3 to +3
    @State private var playerStreak: Int = 0
    @State private var aiMomentum: Int = 0

    // Floating shot result feedback
    @State private var feedbackText: String = ""
    @State private var feedbackColor: Color = .white
    @State private var feedbackY: CGFloat = 0
    @State private var feedbackOpacity: Double = 0
    @State private var feedbackTask: Task<Void, Never>?

    // Screen shake & particle burst FX
    @State private var shakeX: CGFloat = 0
    @State private var shakeY: CGFloat = 0
    @State private var burstParticles: [(id: Int, x: CGFloat, y: CGFloat, angle: Double, distance: CGFloat, opacity: Double, color: Color)] = []
    @State private var burstCounter: Int = 0

    // Haptics
    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let impactMed    = UIImpactFeedbackGenerator(style: .medium)
    private let impactHvy    = UIImpactFeedbackGenerator(style: .heavy)
    private let impactRigid  = UIImpactFeedbackGenerator(style: .rigid)
    private let impactSoft   = UIImpactFeedbackGenerator(style: .soft)
    private let notif        = UINotificationFeedbackGenerator()

    private let winTarget = 21
    private let accentColor = Color(red: 1.0, green: 0.60, blue: 0.0)

    private var aiShotAccuracy: Double {
        switch selectedDifficulty {
        case .rookie: return 0.45
        case .pro:    return 0.65
        case .elite:  return 0.80
        case .legend: return 0.92
        }
    }

    private var aiResponseDelay: Double {
        switch selectedDifficulty {
        case .rookie: return 1.8
        case .pro:    return 1.2
        case .elite:  return 0.7
        case .legend: return 0.3
        }
    }

    private var aiDefenseStrength: Double {
        switch selectedDifficulty {
        case .rookie: return 0.2
        case .pro:    return 0.45
        case .elite:  return 0.70
        case .legend: return 0.90
        }
    }

    private var aiDelayLow: Double { aiResponseDelay }
    private var aiDelayHigh: Double { aiResponseDelay + 1.0 }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.10).ignoresSafeArea()

            ForEach(burstParticles, id: \.id) { p in
                Circle().fill(p.color).frame(width: 7, height: 7)
                    .offset(x: p.x - UIScreen.main.bounds.width/2 + CGFloat(cos(p.angle)) * p.distance,
                            y: p.y - UIScreen.main.bounds.height/2 + CGFloat(sin(p.angle)) * p.distance)
                    .opacity(p.opacity).blur(radius: 1)
            }
            .allowsHitTesting(false)

            Group {
                switch phase {
                case .difficultySelect:
                    difficultySelectScreen
                case .ready:
                    GetReadyScreen(
                        title: "Street 1v1",
                        subtitle: "First to 21 · Your court, your rules",
                        countdown: 3,
                        accentColor: accentColor,
                        onComplete: { startGame() }
                    )
                case .playing:
                    playingBody
                case .result:
                    resultScreen
                }
            }
            .offset(x: shakeX, y: shakeY)
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

    // MARK: - Difficulty Select Screen

    private var difficultySelectScreen: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)

            Text("CHOOSE DIFFICULTY")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.70))

            Text("STREET 1v1")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .padding(.top, 4)

            Spacer().frame(height: 28)

            // 2x2 grid of difficulty cards
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    difficultyCard(.rookie)
                    difficultyCard(.pro)
                }
                HStack(spacing: 14) {
                    difficultyCard(.elite)
                    difficultyCard(.legend)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // FIND MATCH button
            Button {
                withAnimation(.spring(response: 0.35)) { phase = .ready }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "basketball.fill").font(.system(size: 16, weight: .bold))
                    Text("FIND MATCH").font(.system(size: 17, weight: .black, design: .monospaced))
                    Text("·  \(selectedDifficulty.prqRewardRange)").font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: [accentColor, accentColor.opacity(0.80)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: accentColor.opacity(0.40), radius: 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
    }

    @ViewBuilder
    private func difficultyCard(_ difficulty: AIDifficulty) -> some View {
        let isSelected = selectedDifficulty == difficulty
        Button {
            withAnimation(.spring(response: 0.25)) { selectedDifficulty = difficulty }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(difficulty.displayName)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(difficulty.prqRewardRange)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text(difficulty.winRateDescription)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.80))

                Divider()
                    .background(Color.white.opacity(0.25))

                Text(difficulty.aiMissDescription)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: difficulty.cardGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white.opacity(0.75) : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: isSelected ? difficulty.badgeColor.opacity(0.45) : .clear, radius: 10)
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playing Body

    private var playingBody: some View {
        VStack(spacing: 0) {
            scoreHeader
                .padding(.horizontal, 20)
                .padding(.top, 8)

            shotClockBar
                .padding(.horizontal, 20)
                .padding(.top, 6)

            // Canvas court — fills most of screen
            ZStack {
                StreetCourtCanvas(
                    possession: possession,
                    shotProgress: shotProgress,
                    shotMade: shotMade,
                    playerPose: playerPose,
                    opponentPose: opponentPose,
                    rimShake: rimShake,
                    showConfetti: showConfetti,
                    hotHandActive: hotHandActive,
                    posterizeActive: posterizeActive,
                    ankleShimmy: ankleShimmy,
                    dustActive: dustActive,
                    shotTimingActive: shotTimingActive,
                    shotTimingMeter: shotTimingMeter,
                    timingResult: timingResult,
                    timingFeedbackOpacity: timingFeedbackOpacity,
                    playerMomentum: playerMomentum,
                    aiMomentum: aiMomentum
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Floating shot result popup (rises from basket, fades out)
                if feedbackOpacity > 0 {
                    Text(feedbackText)
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(feedbackColor)
                        .shadow(color: feedbackColor.opacity(0.70), radius: 12)
                        .offset(y: feedbackY)
                        .opacity(feedbackOpacity)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .overlay(alignment: .topTrailing) {
                Text(selectedDifficulty.rawValue)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(selectedDifficulty.badgeColor.opacity(0.88))
                    )
                    .padding(.top, 20)
                    .padding(.trailing, 28)
            }
            .overlay(alignment: .center) {
                if showShotLabel, let result = lastShotResult {
                    Text(result.rawValue)
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .italic()
                        .foregroundStyle(
                            result == .made ? accentColor : (result == .blocked ? .red : .secondary)
                        )
                        .shadow(
                            color: (result == .made ? accentColor : .red).opacity(0.7),
                            radius: 16
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(response: 0.22, dampingFraction: 0.5), value: showShotLabel)
                }
            }

            comboRow
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            inputPanel
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        HStack(alignment: .top) {
            VStack(spacing: 2) {
                Text("YOU")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(2)
                Text("\(playerScore)")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }.frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: possession == .player ? "arrowtriangle.right.fill" : "arrowtriangle.left.fill")
                        .foregroundStyle(possession == .player ? accentColor : .red)
                    Text(possession == .player ? "YOUR BALL" : "OPP BALL")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(possession == .player ? accentColor : .red)
                }
                Text("TO 21")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }.frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("OPP")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(opponentScore)")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .contentTransition(.numericText())
            }.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Shot Clock Bar

    private var shotClockBar: some View {
        GeometryReader { geo in
            HStack(spacing: 10) {
                Text("SHOT")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                    .frame(width: 32)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    let bw = max(0, geo.size.width - 72)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(shotClock > 8 ? accentColor : .red)
                        .frame(width: CGFloat(shotClock) / 24.0 * bw, height: 6)
                        .animation(.linear(duration: 0.5), value: shotClock)
                }
                Text("\(shotClock)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(shotClock > 8 ? .white : .red)
                    .contentTransition(.numericText())
                    .frame(width: 24, alignment: .trailing)
            }
        }.frame(height: 22)
    }

    // MARK: - Combo Row

    private var comboRow: some View {
        Group {
            if comboCount >= 2 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("x\(comboMultiplier) COMBO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("(\(comboCount) makes)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.orange.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .clipShape(.rect(cornerRadius: 10))
                .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "basketball.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accentColor.opacity(0.4))
                    Text("TAP SHOOT · CROSSOVER · DRIVE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }
            }
        }
        .frame(height: 32)
        .animation(.spring(response: 0.3), value: comboCount)
    }

    // MARK: - Input Panel

    private var inputPanel: some View {
        VStack(spacing: 12) {
            if shotTimingActive {
                // RELEASE button: shown while timing meter oscillates
                Button { releaseShot() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.point.up.left.fill").font(.system(size: 18, weight: .bold))
                        Text("RELEASE").font(.system(size: 18, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [Color.green, Color.green.opacity(0.75)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: Color.green.opacity(0.50), radius: 14)
                }
            } else {
                Button {
                    guard phase == .playing, possession == .player, shotProgress < 0 else { return }
                    playerAttemptShoot()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "basketball.fill").font(.system(size: 18, weight: .bold))
                        Text("SHOOT").font(.system(size: 18, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        possession == .player && phase == .playing && shotProgress < 0
                            ? LinearGradient(colors: [accentColor, accentColor.opacity(0.75)],
                                             startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                                             startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: possession == .player ? accentColor.opacity(0.35) : .clear, radius: 12)
                }
                .disabled(possession != .player || phase != .playing || shotProgress >= 0)
            }

            HStack(spacing: 12) {
                actionButton(label: "CROSSOVER", icon: "arrow.left.and.right") {
                    playerAttemptMove(action: "CROSSOVER")
                }
                actionButton(label: "DRIVE", icon: "figure.run") {
                    playerAttemptMove(action: "DRIVE")
                }
                if selectedDifficulty == .elite || selectedDifficulty == .legend {
                    actionButton(label: "FAKE", icon: "hand.raised.fingers.spread") {
                        playerAttemptFake()
                    }
                }
            }
        }
    }

    private func playerAttemptFake() {
        guard phase == .playing, possession == .player, shotProgress < 0 else { return }
        impactLight.impactOccurred()
        playerPose = "crossover"
        dustActive = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                playerPose = "idle"
                dustActive = false
                fakeActive = true   // AI commits; next shot has reduced block chance
            }
        }
    }

    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
                Text(label).font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .foregroundStyle(possession == .player ? accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accentColor.opacity(possession == .player ? 0.08 : 0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accentColor.opacity(possession == .player ? 0.25 : 0.08), lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(possession != .player || phase != .playing || shotProgress >= 0)
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        let playerWon = playerScore >= winTarget
        let didTie = !playerWon && opponentScore < winTarget
        let winner: ResultScreen.ResultWinner = playerWon ? .p1 : (didTie ? .draw : .p2)
        let prqGain = playerWon ? selectedDifficulty.prqReward : PRQ.modeReward(
            mode: .basketballHeadToHead, won: playerWon, tied: didTie,
            combo: comboCount, criticals: comboCount / 3,
            scoreDifferential: playerScore - opponentScore
        )
        return ResultScreen(
            winner: winner,
            p1Score: playerScore,
            p2Score: opponentScore,
            title: "Street 1v1",
            accentColor: accentColor,
            prqGain: prqGain,
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "Court IQ",
            modeAttributeValue: PRQ.attributeValue(
                prq: viewModel.effectiveMetrics.prqScore,
                for: .basketballHeadToHead
            )
        ) {
            if !shardsRewarded {
                viewModel.profile.evolutionShards += playerWon ? 50 : (didTie ? 25 : 15)
                SaveSystem.saveProfile(viewModel.profile)
                shardsRewarded = true
            }
            dismiss()
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        playerScore = 0; opponentScore = 0; comboCount = 0; comboMultiplier = 1
        possession = .player; lastShotResult = nil; showShotLabel = false
        shotMade = false; shotProgress = -1; shardsRewarded = false
        playerPose = "idle"; opponentPose = "guard"
        showConfetti = false; hotHandActive = false
        posterizeActive = false; ankleShimmy = false; dustActive = false
        fakeActive = false
        // Reset shot timing
        shotTimingMeter = 0; shotTimingActive = false; timingResult = nil; timingFeedbackOpacity = 0
        // Reset momentum / streak
        playerMomentum = 0; playerStreak = 0; aiMomentum = 0
        // Reset floating feedback
        feedbackOpacity = 0; feedbackText = ""; feedbackY = 0
        phase = .playing
        resetShotClock()
        scheduleOpponentShot()
    }

    private func playerAttemptShoot() {
        guard phase == .playing, possession == .player, shotProgress < 0 else { return }
        // If timing meter is already active, treat as RELEASE tap
        if shotTimingActive { releaseShot(); return }
        shotClockTask?.cancel()

        // Defense block check for Elite / Legend tiers
        if (selectedDifficulty == .elite || selectedDifficulty == .legend) {
            let effectiveDefense = fakeActive ? aiDefenseStrength * 0.15 : aiDefenseStrength
            fakeActive = false
            let isBlocked = Double.random(in: 0...1) < effectiveDefense
            if isBlocked {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                playerPose = "idle"; opponentPose = "block"
                flashShotResult(.blocked)
                comboCount = 0; comboMultiplier = 1; hotHandActive = false
                updatePlayerMomentum(made: false)
                triggerShake(intensity: 6)
                showFloatingFeedback(text: "BLOCKED", color: .red)
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await MainActor.run {
                        opponentPose = "guard"; possession = .opponent
                        resetShotClock(); scheduleOpponentShot()
                    }
                }
                return
            }
        }

        fakeActive = false; playerPose = "shoot"; opponentPose = "block"
        impactMed.impactOccurred()

        // Activate shot timing meter
        shotTimingActive = true; timingResult = nil; timingFeedbackOpacity = 0

        // Animate timing needle oscillating
        shotTimingTask?.cancel()
        shotTimingTask = Task {
            let startTime = Date.now
            while !Task.isCancelled {
                let elapsed = Date.now.timeIntervalSince(startTime)
                let raw = sin(elapsed * Double.pi * 1.5)
                let mapped = CGFloat((raw + 1.0) / 2.0)
                await MainActor.run { shotTimingMeter = mapped }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }

        // Auto-fire after 1.8s
        autoFireTask?.cancel()
        autoFireTask = Task {
            try? await Task.sleep(for: .milliseconds(1800))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard shotTimingActive else { return }
                let autoTiming: TimingResult = shotTimingMeter < 0.20 || shotTimingMeter > 0.80 ? .rushed : .late
                resolveShot(timing: autoTiming)
            }
        }
    }

    private func releaseShot() {
        guard shotTimingActive else { return }
        let m = Double(shotTimingMeter)
        let timing: TimingResult
        if m >= 0.43 && m <= 0.57 { timing = .perfect }
        else if (m >= 0.30 && m < 0.43) || (m > 0.57 && m <= 0.70) { timing = .good }
        else if m < 0.30 { timing = .early }
        else { timing = .late }
        resolveShot(timing: timing)
    }

    private func resolveShot(timing: TimingResult) {
        shotTimingTask?.cancel(); autoFireTask?.cancel()
        shotTimingActive = false; timingResult = timing

        let prq = viewModel.effectiveMetrics.prqScore
        let momentumBonus = Double(playerMomentum) * 0.05
        let baseHit = min(0.85, 0.45 + (prq / 100) * 0.30 + Double(comboCount) * 0.02
                          + timing.accuracyModifier + momentumBonus)
        let made = Double.random(in: 0...1) < max(0.05, baseHit)
        let isDunk = made && Double.random(in: 0...1) < 0.25
        let isAnd1 = made && Double.random(in: 0...1) < 0.12

        // Show timing result in canvas (fades after 0.7s)
        timingFeedbackOpacity = 1.0
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { timingFeedbackOpacity = 0 } }
        }

        shotAnimTask?.cancel()
        shotAnimTask = Task {
            await MainActor.run { shotProgress = 0 }
            let steps = 36
            for step in 0..<steps {
                try? await Task.sleep(for: .milliseconds(14))
                guard !Task.isCancelled else { return }
                await MainActor.run { shotProgress = Double(step + 1) / Double(steps) }
            }
            await MainActor.run {
                shotProgress = -1; shotMade = made
                playerPose = "idle"; opponentPose = "guard"

                if made {
                    comboCount += 1; comboMultiplier = min(4, 1 + comboCount / 3)
                    updatePlayerMomentum(made: true)
                    let pts = 2 * comboMultiplier
                    withAnimation(.spring(response: 0.3)) { playerScore = min(playerScore + pts, 99) }
                    flashShotResult(.made); triggerRimShake(intensity: 1.0)

                    if timing == .perfect {
                        showFloatingFeedback(text: "BUCKETS", color: .orange)
                    } else {
                        showFloatingFeedback(text: "+\(pts)", color: .white)
                    }
                    // HE'S COOKING after exactly 3 straight makes
                    if playerStreak == 3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            showFloatingFeedback(text: "HE'S COOKING", color: Color(red: 1.0, green: 0.55, blue: 0.0))
                        }
                    }

                    if isDunk || isAnd1 {
                        // Special move / dunk
                        triggerShake(intensity: 18)
                        triggerBurst(color: .yellow, count: 20)
                        impactHvy.impactOccurred(); posterizeActive = true; showConfetti = true
                        Task {
                            try? await Task.sleep(for: .milliseconds(1200))
                            await MainActor.run { posterizeActive = false; showConfetti = false }
                        }
                    } else if playerScore >= winTarget - 2 {
                        // Near match-winning bucket
                        triggerShake(intensity: 14)
                        triggerBurst(color: accentColor, count: 16)
                        impactRigid.impactOccurred(); showConfetti = true
                        Task {
                            try? await Task.sleep(for: .milliseconds(1500))
                            await MainActor.run { showConfetti = false }
                        }
                    } else {
                        // Normal make
                        triggerShake(intensity: 14)
                        triggerBurst(color: accentColor, count: 16)
                        notif.notificationOccurred(.success)
                    }
                    if comboCount >= 3 { hotHandActive = true }
                } else {
                    comboCount = 0; comboMultiplier = 1; hotHandActive = false
                    updatePlayerMomentum(made: false)
                    flashShotResult(.miss); triggerRimShake(intensity: 0.5)
                    impactSoft.impactOccurred()
                    showFloatingFeedback(text: timing.label, color: timing.color)
                }

                possession = .opponent; resetShotClock()
                if playerScore >= winTarget {
                    // Match-winning basket
                    triggerShake(intensity: 20)
                    triggerBurst(color: accentColor, count: 24)
                    endGame(); return
                }
                scheduleOpponentShot()
            }
        }
    }

    private func updatePlayerMomentum(made: Bool) {
        if made {
            playerStreak += 1
            if playerStreak >= 2 { playerMomentum = min(3, playerMomentum + 1) }
        } else {
            playerStreak = 0
            playerMomentum = max(-3, playerMomentum - 1)
        }
    }

    private func showFloatingFeedback(text: String, color: Color) {
        feedbackTask?.cancel()
        feedbackText = text; feedbackColor = color; feedbackY = 0; feedbackOpacity = 1.0
        feedbackTask = Task {
            let steps = 24
            for i in 0..<steps {
                try? await Task.sleep(for: .milliseconds(33))
                guard !Task.isCancelled else { return }
                let progress = Double(i + 1) / Double(steps)
                await MainActor.run {
                    feedbackY = CGFloat(-progress * 40)
                    feedbackOpacity = max(0, 1.0 - progress * 1.2)
                }
            }
            await MainActor.run { feedbackOpacity = 0 }
        }
    }

    private func playerAttemptMove(action: String) {
        guard phase == .playing, possession == .player, shotProgress < 0 else { return }
        let isCrossover = action == "CROSSOVER"
        playerPose = isCrossover ? "crossover" : "drive"

        if isCrossover {
            // Haptic: medium on crossover / step-back
            impactMed.impactOccurred()
            dustActive = true
            let doShimmy = Double.random(in: 0...1) < 0.40
            if doShimmy { ankleShimmy = true }
        } else {
            impactMed.impactOccurred()
            dustActive = true
        }

        let succeeded = Double.random(in: 0...1) < 0.65

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                playerPose = "idle"
                dustActive = false
                ankleShimmy = false
                if !succeeded {
                    flashShotResult(.blocked)
                    // Haptic: soft on turnover
                    impactSoft.impactOccurred()
                    triggerShake(intensity: 6)
                    possession = .opponent; comboCount = 0; comboMultiplier = 1
                    hotHandActive = false
                    opponentPose = "guard"; resetShotClock(); scheduleOpponentShot()
                }
            }
        }
    }

    private func flashShotResult(_ result: ShotResult) {
        lastShotResult = result
        withAnimation(.spring(response: 0.2)) { showShotLabel = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { showShotLabel = false }
            }
        }
    }

    private func triggerRimShake(intensity: Double) {
        rimShake = intensity
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) { rimShake = 0 }
            }
        }
    }

    private func scheduleOpponentShot() {
        opponentTask?.cancel()
        guard phase == .playing else { return }
        let delay = Double.random(in: aiDelayLow...aiDelayHigh)
        opponentTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase == .playing else { return }
                opponentPose = "shoot"
                let made = Double.random(in: 0...1) < aiShotAccuracy
                if made {
                    withAnimation(.spring(response: 0.3)) { opponentScore = min(opponentScore + 2, 99) }
                    triggerRimShake(intensity: 0.6)
                    triggerShake(intensity: 8)
                    flashScreenShakeFX()
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    await MainActor.run { opponentPose = "guard" }
                }
                possession = .player; resetShotClock()
                if opponentScore >= winTarget {
                    // Haptic: error on losing / game over
                    notif.notificationOccurred(.error)
                    endGame()
                }
            }
        }
    }

    private func resetShotClock() {
        shotClockTask?.cancel(); shotClock = 24
        shotClockTask = Task {
            while shotClock > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { shotClock -= 1 }
            }
            await MainActor.run { shotClockViolation() }
        }
    }

    private func shotClockViolation() {
        guard phase == .playing else { return }
        if possession == .player {
            comboCount = 0; comboMultiplier = 1
            hotHandActive = false
            possession = .opponent
            scheduleOpponentShot()
        } else {
            possession = .player
        }
        resetShotClock()
    }

    private func flashScreenShakeFX() {
        withAnimation(.easeOut(duration: 0.06)) { screenShake = 5 }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { screenShake = 0 }
            }
        }
    }

    private func endGame() {
        cancelAllTasks()
        let playerWon = playerScore >= winTarget
        let prqDelta = playerWon ? selectedDifficulty.prqReward : 0
        GameResultService.saveResult(modeId: "basketball_h2h", userScore: playerScore, opponentScore: opponentScore, prqDelta: prqDelta)
        withAnimation(.spring(response: 0.4)) { phase = .result }
    }

    private func cancelAllTasks() {
        shotClockTask?.cancel(); opponentTask?.cancel()
        shotAnimTask?.cancel(); shotTimingTask?.cancel()
        autoFireTask?.cancel(); feedbackTask?.cancel()
        shotClockTask = nil; opponentTask = nil; shotAnimTask = nil
        shotTimingTask = nil; autoFireTask = nil; feedbackTask = nil
    }

    // MARK: - Screen Shake & Particle Burst

    private func triggerShake(intensity: CGFloat = 8) {
        let i = intensity
        withAnimation(.interpolatingSpring(stiffness: 700, damping: 8)) {
            shakeX = CGFloat.random(in: -i...i); shakeY = CGFloat.random(in: -i...i)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run {
                withAnimation(.interpolatingSpring(stiffness: 700, damping: 10)) {
                    shakeX = CGFloat.random(in: -i*0.5...i*0.5); shakeY = CGFloat.random(in: -i*0.5...i*0.5)
                }
            }
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run { withAnimation(.spring(response: 0.15)) { shakeX = 0; shakeY = 0 } }
        }
    }

    private func triggerBurst(color: Color, count: Int = 14) {
        let id = burstCounter; burstCounter += 1
        let cx = UIScreen.main.bounds.width / 2
        let cy = UIScreen.main.bounds.height / 2
        let particles = (0..<count).map { i -> (id: Int, x: CGFloat, y: CGFloat, angle: Double, distance: CGFloat, opacity: Double, color: Color) in
            let angle = Double(i) / Double(count) * 2 * .pi + Double.random(in: -0.3...0.3)
            return (id: id * 100 + i, x: cx, y: cy, angle: angle, distance: 0, opacity: 1.0, color: color)
        }
        burstParticles.append(contentsOf: particles)
        withAnimation(.easeOut(duration: 0.65)) {
            for i in 0..<burstParticles.count {
                if burstParticles[i].id >= id * 100 {
                    burstParticles[i].distance = CGFloat.random(in: 50...100)
                    burstParticles[i].opacity = 0
                }
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            await MainActor.run { burstParticles.removeAll { $0.id >= id * 100 } }
        }
    }
}
