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
    var comboCount: Int = 0
    var playerHP: Double = 100
    var opponentHP: Double = 100
    var roundNumber: Int = 1

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = DojoDrawer(size: size, t: t,
                                   playerPose: playerPoseName, opponentPose: opponentPoseName,
                                   crowd: crowdAlpha, dragon: dragonActive,
                                   lastHitTime: lastHitTime, lastHitType: lastHitType,
                                   comboCount: comboCount,
                                   playerHP: playerHP, opponentHP: opponentHP,
                                   roundNumber: roundNumber)
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
    let comboCount: Int
    let playerHP: Double; let opponentHP: Double
    let roundNumber: Int

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var floorY: CGFloat { H * 0.84 }

    mutating func render(into ctx: inout GraphicsContext) {
        // ---- Layer 1: Deep background ----
        drawBg(ctx: &ctx)
        // ---- Layer 2: Stone walls & kanji banners ----
        drawWalls(ctx: &ctx)
        // ---- Layer 3: Window light shafts + dust ----
        drawLightShafts(ctx: &ctx)
        // ---- Layer 4: Tournament bracket panel ----
        drawTournamentBracket(ctx: &ctx)
        // ---- Layer 5: Crowd silhouettes ----
        drawCrowd(ctx: &ctx)
        // ---- Layer 6: Wood plank floor ----
        drawFloor(ctx: &ctx)
        // ---- Layer 7: Hanging paper lanterns ----
        drawLanterns(ctx: &ctx)
        // ---- Layer 8: Dragon effects (under fighters) ----
        if dragon {
            drawDragonFloorEnergy(ctx: &ctx)
            drawDragonAura(ctx: &ctx)
        }
        // ---- Layer 9: Fighters ----
        drawFighter(ctx: &ctx, cx: W*0.25, pose: pose(for: playerPose), color: Color(red:0.15,green:0.75,blue:1.0), flip: false)
        drawFighter(ctx: &ctx, cx: W*0.75, pose: pose(for: opponentPose), color: Color(red:1.0,green:0.22,blue:0.22), flip: true)
        // ---- Layer 10: Dragon eye glow over fighters ----
        if dragon { drawDragonEyes(ctx: &ctx) }
        // ---- Layer 11: Ground shadows ----
        drawShadows(ctx: &ctx)
        // ---- Layer 12: Match timer arc ----
        drawMatchTimerArc(ctx: &ctx)
        // ---- Layer 13: HP bar canvas elements ----
        drawCanvasHPBars(ctx: &ctx)
        // ---- Layer 14: Hit impact effects ----
        let timeSinceHit = t - lastHitTime
        if timeSinceHit < 0.55 && lastHitTime > 0 {
            drawImpactRing(ctx: &ctx, timeSince: timeSinceHit)
            drawScreenVignette(ctx: &ctx, timeSince: timeSinceHit)
            drawHitSparks(ctx: &ctx, timeSince: timeSinceHit)
        }
        // ---- Layer 15: Combo multiplier display ----
        if comboCount >= 2 { drawComboDisplay(ctx: &ctx) }
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

    // MARK: - Background

    private func drawBg(ctx: inout GraphicsContext) {
        // [DRAW 1] Deep background fill
        ctx.fill(Path(CGRect(origin:.zero,size:size)),
                 with:.color(Color(red:0.04,green:0.01,blue:0.01)))

        // [DRAW 2] Upper atmospheric gradient
        var upperGrad = Path()
        upperGrad.addRect(CGRect(x:0, y:0, width:W, height:H*0.55))
        ctx.fill(upperGrad,
                 with:.linearGradient(
                    Gradient(colors:[Color(red:0.08,green:0.02,blue:0.02),
                                     Color(red:0.04,green:0.01,blue:0.01)]),
                    startPoint: CGPoint(x:W/2,y:0),
                    endPoint: CGPoint(x:W/2,y:H*0.55)))

        // [DRAW 3] Center arena glow
        var glow = Path()
        glow.addEllipse(in: CGRect(x:W*0.15,y:H*0.18,width:W*0.70,height:H*0.55))
        ctx.fill(glow, with:.color(Color(red:0.55,green:0.04,blue:0.0).opacity(0.09)))

        // [DRAW 4] Secondary blue tint for arena depth
        var glow2 = Path()
        glow2.addEllipse(in: CGRect(x:W*0.30,y:H*0.25,width:W*0.40,height:H*0.38))
        ctx.fill(glow2, with:.color(Color(red:0.0,green:0.05,blue:0.18).opacity(0.07)))
    }

    // MARK: - Stone Walls & Kanji

    private func drawWalls(ctx: inout GraphicsContext) {
        // [DRAW 5] Back wall stone base
        var wallRect = Path()
        wallRect.addRect(CGRect(x:0, y:H*0.05, width:W, height:H*0.68))
        ctx.fill(wallRect, with:.color(Color(red:0.09,green:0.06,blue:0.05)))

        // [DRAW 6] Stone horizontal mortar lines (5 rows)
        for row in 0..<6 {
            let gy = H*0.05 + H*0.68 * CGFloat(row) / 6.0
            var mortar = Path()
            mortar.move(to: CGPoint(x:0, y:gy))
            mortar.addLine(to: CGPoint(x:W, y:gy))
            ctx.stroke(mortar, with:.color(Color(red:0.04,green:0.02,blue:0.02).opacity(0.7)), lineWidth:1.5)
        }

        // [DRAW 7] Stone vertical mortar lines (offset per row for realistic masonry)
        for row in 0..<6 {
            let rowY = H*0.05 + H*0.68 * CGFloat(row) / 6.0
            let nextY = rowY + H*0.68/6.0
            let offset: CGFloat = row % 2 == 0 ? 0 : W*0.075
            let cols = 7
            for col in 0...cols {
                let gx = offset + W * CGFloat(col) / CGFloat(cols)
                var vLine = Path()
                vLine.move(to: CGPoint(x:gx, y:rowY))
                vLine.addLine(to: CGPoint(x:gx, y:nextY))
                ctx.stroke(vLine, with:.color(Color(red:0.03,green:0.01,blue:0.01).opacity(0.65)), lineWidth:1)
            }
        }

        // [DRAW 8] Stone surface texture — subtle noise dots (16 patches)
        for i in 0..<16 {
            let sx = W * CGFloat(i % 4) / 4.0 + W * 0.05
            let sy = H*0.10 + H * CGFloat(i / 4) / 8.0
            var patch = Path()
            patch.addEllipse(in: CGRect(x:sx, y:sy, width:W*0.18, height:H*0.04))
            let pAlpha = 0.025 + 0.02 * sin(Double(i)*1.3)
            ctx.fill(patch, with:.color(Color(red:0.15,green:0.10,blue:0.08).opacity(pAlpha)))
        }

        // [DRAW 9] Left kanji banner
        let bannerW: CGFloat = W * 0.07
        let bannerH: CGFloat = H * 0.30
        let lBX = W * 0.08
        var lBanner = Path()
        lBanner.addRect(CGRect(x:lBX, y:H*0.10, width:bannerW, height:bannerH))
        ctx.fill(lBanner, with:.color(Color(red:0.55,green:0.04,blue:0.04).opacity(0.82)))
        ctx.stroke(lBanner, with:.color(Color(red:0.85,green:0.65,blue:0.30).opacity(0.45)), lineWidth:1.2)
        // Kanji "道" (way/path) as text symbol
        var kanjiCtx1 = ctx
        kanjiCtx1.opacity = 0.75
        kanjiCtx1.draw(Text("道").font(.system(size:bannerW*0.78)).foregroundColor(Color(red:0.95,green:0.85,blue:0.55)),
                       at: CGPoint(x:lBX + bannerW/2, y:H*0.10 + bannerH*0.30),
                       anchor: .center)
        kanjiCtx1.draw(Text("武").font(.system(size:bannerW*0.75)).foregroundColor(Color(red:0.95,green:0.85,blue:0.55)),
                       at: CGPoint(x:lBX + bannerW/2, y:H*0.10 + bannerH*0.65),
                       anchor: .center)

        // [DRAW 10] Right kanji banner
        let rBX = W * 0.85
        var rBanner = Path()
        rBanner.addRect(CGRect(x:rBX, y:H*0.10, width:bannerW, height:bannerH))
        ctx.fill(rBanner, with:.color(Color(red:0.04,green:0.12,blue:0.55).opacity(0.82)))
        ctx.stroke(rBanner, with:.color(Color(red:0.30,green:0.65,blue:0.85).opacity(0.45)), lineWidth:1.2)
        var kanjiCtx2 = ctx
        kanjiCtx2.opacity = 0.75
        kanjiCtx2.draw(Text("龍").font(.system(size:bannerW*0.78)).foregroundColor(Color(red:0.55,green:0.85,blue:0.95)),
                       at: CGPoint(x:rBX + bannerW/2, y:H*0.10 + bannerH*0.30),
                       anchor: .center)
        kanjiCtx2.draw(Text("魂").font(.system(size:bannerW*0.75)).foregroundColor(Color(red:0.55,green:0.85,blue:0.95)),
                       at: CGPoint(x:rBX + bannerW/2, y:H*0.10 + bannerH*0.65),
                       anchor: .center)

        // [DRAW 11] Shoji panel grid overlay (background wall detail)
        let panelW: CGFloat = W/5
        for i in 0..<5 {
            let px = CGFloat(i)*panelW
            let panelRect = CGRect(x:px+3, y:H*0.09, width:panelW-6, height:H*0.60)
            ctx.fill(Path(panelRect), with:.color(Color(red:0.11,green:0.07,blue:0.05).opacity(0.50)))
            ctx.stroke(Path(panelRect), with:.color(Color.white.opacity(0.04)), lineWidth:0.8)
            let cols = 3; let rows = 5
            for c in 1..<cols {
                let gx = px + panelW*CGFloat(c)/CGFloat(cols)
                var gp = Path()
                gp.move(to: CGPoint(x:gx,y:H*0.09))
                gp.addLine(to: CGPoint(x:gx,y:H*0.69))
                ctx.stroke(gp, with:.color(Color.white.opacity(0.025)), lineWidth:0.5)
            }
            for r in 1..<rows {
                let gy = H*0.09 + (H*0.60)*CGFloat(r)/CGFloat(rows)
                var gp = Path()
                gp.move(to: CGPoint(x:px+3,y:gy))
                gp.addLine(to: CGPoint(x:px+panelW-3,y:gy))
                ctx.stroke(gp, with:.color(Color.white.opacity(0.025)), lineWidth:0.5)
            }
        }
    }

    // MARK: - Light Shafts

    private func drawLightShafts(ctx: inout GraphicsContext) {
        // [DRAW 12] Left window frame
        let lWinX: CGFloat = W * 0.03
        let winTop: CGFloat = H * 0.12
        let winW: CGFloat = W * 0.10
        let winH: CGFloat = H * 0.32
        var lWinFrame = Path()
        lWinFrame.addRect(CGRect(x:lWinX, y:winTop, width:winW, height:winH))
        ctx.fill(lWinFrame, with:.color(Color(red:0.45,green:0.38,blue:0.22).opacity(0.25)))
        ctx.stroke(lWinFrame, with:.color(Color(red:0.7,green:0.55,blue:0.30).opacity(0.5)), lineWidth:2)

        // [DRAW 13] Right window frame
        let rWinX: CGFloat = W * 0.87
        var rWinFrame = Path()
        rWinFrame.addRect(CGRect(x:rWinX, y:winTop, width:winW, height:winH))
        ctx.fill(rWinFrame, with:.color(Color(red:0.45,green:0.38,blue:0.22).opacity(0.25)))
        ctx.stroke(rWinFrame, with:.color(Color(red:0.7,green:0.55,blue:0.30).opacity(0.5)), lineWidth:2)

        // [DRAW 14] Left light shaft beam
        let lShaftCX = lWinX + winW / 2
        var lShaft = Path()
        lShaft.move(to: CGPoint(x:lShaftCX - winW*0.4, y:winTop))
        lShaft.addLine(to: CGPoint(x:lShaftCX + winW*0.4, y:winTop))
        lShaft.addLine(to: CGPoint(x:lShaftCX + winW*1.6, y:floorY))
        lShaft.addLine(to: CGPoint(x:lShaftCX - winW*1.0, y:floorY))
        lShaft.closeSubpath()
        ctx.fill(lShaft, with:.color(Color(red:1.0,green:0.95,blue:0.80).opacity(0.055)))

        // [DRAW 15] Right light shaft beam
        let rShaftCX = rWinX + winW / 2
        var rShaft = Path()
        rShaft.move(to: CGPoint(x:rShaftCX - winW*0.4, y:winTop))
        rShaft.addLine(to: CGPoint(x:rShaftCX + winW*0.4, y:winTop))
        rShaft.addLine(to: CGPoint(x:rShaftCX + winW*1.0, y:floorY))
        rShaft.addLine(to: CGPoint(x:rShaftCX - winW*1.6, y:floorY))
        rShaft.closeSubpath()
        ctx.fill(rShaft, with:.color(Color(red:1.0,green:0.95,blue:0.80).opacity(0.055)))

        // [DRAW 16] Dust particles in left shaft (20 particles)
        let shaftHeight = floorY - winTop
        for i in 0..<20 {
            let px = lShaftCX + CGFloat(sin(t * 0.3 + Double(i) * 0.8)) * 14
            let rawFrac = t * 18.0 + Double(i) * 7.3
            let py = winTop + CGFloat(rawFrac.truncatingRemainder(dividingBy: Double(shaftHeight)))
            var dust = Path()
            dust.addEllipse(in: CGRect(x:px-1, y:py-1, width:2, height:2))
            ctx.fill(dust, with:.color(Color.white.opacity(0.28 + 0.12*sin(t*1.1+Double(i)))))
        }

        // [DRAW 17] Dust particles in right shaft (20 particles)
        for i in 0..<20 {
            let px = rShaftCX + CGFloat(sin(t * 0.25 + Double(i) * 1.1)) * 14
            let rawFrac = t * 15.0 + Double(i) * 6.8
            let py = winTop + CGFloat(rawFrac.truncatingRemainder(dividingBy: Double(shaftHeight)))
            var dust = Path()
            dust.addEllipse(in: CGRect(x:px-1, y:py-1, width:2, height:2))
            ctx.fill(dust, with:.color(Color.white.opacity(0.25 + 0.12*sin(t*0.9+Double(i)*1.2))))
        }

        // [DRAW 18] Window horizontal dividers (cross bars)
        let midY = winTop + winH / 2
        for lx in [lWinX, rWinX] {
            var crossH = Path()
            crossH.move(to: CGPoint(x:lx, y:midY))
            crossH.addLine(to: CGPoint(x:lx+winW, y:midY))
            ctx.stroke(crossH, with:.color(Color(red:0.7,green:0.55,blue:0.30).opacity(0.5)), lineWidth:1.5)
            let midX = lx + winW/2
            var crossV = Path()
            crossV.move(to: CGPoint(x:midX, y:winTop))
            crossV.addLine(to: CGPoint(x:midX, y:winTop+winH))
            ctx.stroke(crossV, with:.color(Color(red:0.7,green:0.55,blue:0.30).opacity(0.5)), lineWidth:1.5)
        }
    }

    // MARK: - Tournament Bracket Panel

    private func drawTournamentBracket(ctx: inout GraphicsContext) {
        // [DRAW 19] Bracket panel background (far left wall)
        let bpX: CGFloat = W * 0.015
        let bpY: CGFloat = H * 0.48
        let bpW: CGFloat = W * 0.065
        let bpH: CGFloat = H * 0.22
        var bPanel = Path()
        bPanel.addRoundedRect(in: CGRect(x:bpX, y:bpY, width:bpW, height:bpH), cornerSize: CGSize(width:3,height:3))
        ctx.fill(bPanel, with:.color(Color(red:0.06,green:0.05,blue:0.10).opacity(0.88)))
        ctx.stroke(bPanel, with:.color(Color(red:0.40,green:0.30,blue:0.65).opacity(0.50)), lineWidth:1)

        // [DRAW 20] Bracket header label
        var bracketCtx = ctx
        bracketCtx.opacity = 0.65
        bracketCtx.draw(Text("BRACKET").font(.system(size:5.5, weight:.black, design:.monospaced)).foregroundColor(Color(red:0.70,green:0.60,blue:0.95)),
                        at: CGPoint(x:bpX+bpW/2, y:bpY+5), anchor:.center)

        // [DRAW 21] Bracket lines (simplified tournament tree)
        let lineColor = Color(red:0.50,green:0.45,blue:0.80).opacity(0.45)
        let leftX = bpX + bpW*0.18
        let rightX = bpX + bpW*0.82
        let topRow: CGFloat = bpY + 18
        let botRow: CGFloat = bpY + bpH - 18
        let midRow: CGFloat = (topRow + botRow) / 2.0
        // Left bracket arm
        var bLine1 = Path()
        bLine1.move(to: CGPoint(x:leftX, y:topRow))
        bLine1.addLine(to: CGPoint(x:leftX, y:botRow))
        ctx.stroke(bLine1, with:.color(lineColor), lineWidth:1)
        // Right bracket arm
        var bLine2 = Path()
        bLine2.move(to: CGPoint(x:rightX, y:topRow))
        bLine2.addLine(to: CGPoint(x:rightX, y:botRow))
        ctx.stroke(bLine2, with:.color(lineColor), lineWidth:1)
        // Center connector
        var bLine3 = Path()
        bLine3.move(to: CGPoint(x:leftX, y:midRow))
        bLine3.addLine(to: CGPoint(x:rightX, y:midRow))
        ctx.stroke(bLine3, with:.color(lineColor), lineWidth:1)
        // Round number indicator
        var bDot = Path()
        bDot.addEllipse(in: CGRect(x:bpX+bpW/2-3, y:midRow-3, width:6, height:6))
        ctx.fill(bDot, with:.color(Color.yellow.opacity(0.65)))
    }

    // MARK: - Crowd Silhouettes

    private func drawCrowd(ctx: inout GraphicsContext) {
        // [DRAW 22] Crowd base band
        var crowdBase = Path()
        crowdBase.addRect(CGRect(x:0, y:floorY-H*0.19, width:W, height:H*0.08))
        ctx.fill(crowdBase, with:.color(Color.black.opacity(0.22 * crowd)))

        // 18 crowd spectator silhouettes
        let spectatorXPositions: [CGFloat] = [
            W*0.03, W*0.09, W*0.15, W*0.21, W*0.27,
            W*0.33, W*0.39, W*0.46, W*0.53, W*0.60,
            W*0.66, W*0.72, W*0.78, W*0.84, W*0.88,
            W*0.92, W*0.96, W*0.99
        ]
        let spectatorHeights: [CGFloat] = [
            22, 26, 20, 28, 23, 25, 21, 27, 24, 26,
            22, 28, 20, 25, 23, 26, 21, 24
        ]
        let baseY = floorY - H * 0.135

        // [DRAW 23] Spectator bodies (18 seated silhouettes)
        for (idx, sx) in spectatorXPositions.enumerated() {
            let sh = spectatorHeights[idx]
            // Crowd bounce based on combo
            let bounceAmp: CGFloat = comboCount >= 5 ? 3.5 : (comboCount >= 2 ? 1.5 : 0.5)
            let bounceFreq = 2.5 + Double(idx) * 0.18
            let bounceY = CGFloat(sin(t * bounceFreq + Double(idx) * 0.6)) * bounceAmp
            let headY = baseY - sh + bounceY
            // Head
            var head = Path()
            head.addEllipse(in: CGRect(x:sx-4, y:headY-5, width:9, height:9))
            ctx.fill(head, with:.color(Color.black.opacity(0.62 * crowd)))
            // Body
            var body = Path()
            body.addRect(CGRect(x:sx-5, y:headY+4, width:10, height:sh*0.55))
            ctx.fill(body, with:.color(Color.black.opacity(0.55 * crowd)))
        }

        // [DRAW 24] High-combo crowd arm waves (5+ combo)
        if comboCount >= 5 {
            for (idx, sx) in spectatorXPositions.enumerated() {
                let sh = spectatorHeights[idx]
                let bounceFreq = 2.5 + Double(idx) * 0.18
                let armAngle = sin(t * bounceFreq * 1.2 + Double(idx) * 0.4)
                let armBaseY = baseY - sh
                let armTipY = armBaseY - 10 - CGFloat(armAngle) * 8
                let armTipX = sx + CGFloat(armAngle) * 6
                var armPath = Path()
                armPath.move(to: CGPoint(x:sx, y:armBaseY))
                armPath.addLine(to: CGPoint(x:armTipX, y:armTipY))
                ctx.stroke(armPath, with:.color(Color.black.opacity(0.5 * crowd)), lineWidth:2)
            }
        }

        // [DRAW 25] Crowd ambient glow (excitement reflected light on floor edge)
        var crowdGlow = Path()
        crowdGlow.addRect(CGRect(x:0, y:floorY-H*0.14, width:W, height:H*0.04))
        let glowIntensity = 0.03 + min(0.08, Double(comboCount) * 0.012)
        ctx.fill(crowdGlow, with:.color(Color(red:0.8,green:0.6,blue:0.2).opacity(glowIntensity * crowd)))
    }

    // MARK: - Wood Plank Floor

    private func drawFloor(ctx: inout GraphicsContext) {
        // [DRAW 26] Floor base (dark wood)
        var floorBase = Path()
        floorBase.addRect(CGRect(x:0, y:floorY, width:W, height:H-floorY))
        ctx.fill(floorBase, with:.color(Color(red:0.14,green:0.08,blue:0.04)))

        // [DRAW 27] Wood plank grain lines (horizontal, 12 planks)
        for i in 0..<12 {
            let fy = floorY + CGFloat(i) * (H - floorY) / 12.0
            var plank = Path()
            plank.move(to: CGPoint(x:0, y:fy))
            plank.addLine(to: CGPoint(x:W, y:fy))
            let alpha = 0.12 + Double(i) * 0.04
            ctx.stroke(plank, with:.color(Color(red:0.45,green:0.28,blue:0.12).opacity(alpha)), lineWidth:1.2)
        }

        // [DRAW 28] Plank vertical grain texture lines (16 subtle streaks)
        for i in 0..<16 {
            let gx = W * CGFloat(i) / 16.0 + CGFloat(sin(Double(i)*2.1)) * 4
            var grain = Path()
            grain.move(to: CGPoint(x:gx, y:floorY))
            grain.addLine(to: CGPoint(x:gx + CGFloat(sin(Double(i)*1.7))*8, y:H))
            ctx.stroke(grain, with:.color(Color(red:0.35,green:0.20,blue:0.08).opacity(0.08)), lineWidth:0.7)
        }

        // [DRAW 29] Floor highlight reflection strip
        var highlight = Path()
        highlight.addRect(CGRect(x:0, y:floorY, width:W, height:4))
        ctx.fill(highlight, with:.linearGradient(
            Gradient(colors:[Color(red:0.80,green:0.65,blue:0.40).opacity(0.18), .clear]),
            startPoint: CGPoint(x:0, y:floorY),
            endPoint: CGPoint(x:0, y:floorY+4)))

        // [DRAW 30] Main floor border line
        var fl = Path()
        fl.move(to: CGPoint(x:0,y:floorY))
        fl.addLine(to: CGPoint(x:W,y:floorY))
        ctx.stroke(fl, with:.color(Color(red:0.65,green:0.48,blue:0.22).opacity(0.55)), lineWidth:2)

        // [DRAW 31] Center match line
        var cl = Path()
        cl.move(to: CGPoint(x:W/2,y:floorY))
        cl.addLine(to: CGPoint(x:W/2,y:floorY+18))
        ctx.stroke(cl, with:.color(Color.white.opacity(0.15)), lineWidth:1.2)

        // [DRAW 32] Fight zone circle outline on floor
        var fightCircle = Path()
        fightCircle.addEllipse(in: CGRect(x:W*0.25, y:floorY-4, width:W*0.50, height:10))
        ctx.stroke(fightCircle, with:.color(Color(red:0.75,green:0.55,blue:0.25).opacity(0.18)), lineWidth:1)
    }

    // MARK: - Lanterns

    private func drawLanterns(ctx: inout GraphicsContext) {
        let positions: [(CGFloat, CGFloat)] = [
            (W*0.18, H*0.055),
            (W*0.38, H*0.038),
            (W*0.62, H*0.038),
            (W*0.82, H*0.055)
        ]
        for (idx, (lx, ly)) in positions.enumerated() {
            let swayAmp: CGFloat = 3.0
            let swayFreq = 1.2 + Double(idx) * 0.25
            let sway = CGFloat(sin(t * swayFreq + Double(idx) * 1.1)) * swayAmp
            let lxS = lx + sway
            let flicker = 0.82 + sin(t * 3.4 + Double(lx)) * 0.18

            // [DRAW 33] Lantern string (each of 4)
            var str = Path()
            str.move(to: CGPoint(x:lxS, y:0))
            str.addLine(to: CGPoint(x:lxS, y:ly))
            ctx.stroke(str, with:.color(Color(red:0.6,green:0.5,blue:0.35).opacity(0.22)), lineWidth:0.8)

            // [DRAW 34] Lantern glow halo
            let lw: CGFloat = 18; let lh: CGFloat = 26
            let lr = CGRect(x:lxS-lw/2, y:ly, width:lw, height:lh)
            var glowCtx = ctx
            glowCtx.addFilter(.shadow(color:Color(red:1.0,green:0.20,blue:0.05).opacity(0.45*flicker), radius:10))
            glowCtx.fill(Path(roundedRect:lr, cornerRadius:5),
                         with:.color(Color(red:1.0,green:0.22,blue:0.06).opacity(0.20*flicker)))

            // [DRAW 35] Lantern body
            ctx.fill(Path(roundedRect:lr, cornerRadius:5),
                     with:.color(Color(red:0.90,green:0.14,blue:0.04).opacity(0.78*flicker)))

            // [DRAW 36] Lantern rib lines (top/mid/bot)
            for rOff in [ly+4, ly+lh/2, ly+lh-4] as [CGFloat] {
                var rp = Path()
                rp.move(to: CGPoint(x:lxS-lw/2+1, y:rOff))
                rp.addLine(to: CGPoint(x:lxS+lw/2-1, y:rOff))
                ctx.stroke(rp, with:.color(Color(red:1.0,green:0.80,blue:0.55).opacity(0.20)), lineWidth:0.9)
            }

            // [DRAW 37] Lantern inner light core
            var core = Path()
            core.addEllipse(in: CGRect(x:lxS-4, y:ly+lh/2-4, width:8, height:8))
            ctx.fill(core, with:.color(Color(red:1.0,green:0.95,blue:0.70).opacity(0.35*flicker)))
        }
    }

    // MARK: - Dragon Floor Energy

    private func drawDragonFloorEnergy(ctx: inout GraphicsContext) {
        let cx = W*0.25; let fy = floorY

        // [DRAW 38] Floor crackling ground lines (12 rays radiating from stance)
        for i in 0..<12 {
            let angle = Double(i) / 12.0 * .pi * 2
            let dist = 35.0 + sin(t * 7.0 + Double(i) * 0.5) * 12.0
            let ex = cx + CGFloat(cos(angle)) * CGFloat(dist)
            let ey = fy + CGFloat(sin(angle * 0.5)) * 6
            var ray = Path()
            ray.move(to: CGPoint(x:cx, y:fy))
            ray.addLine(to: CGPoint(x:ex, y:ey))
            let rayAlpha = 0.5 + 0.5 * sin(t * 8.0 + Double(i))
            ctx.stroke(ray, with:.color(Color(red:0.0,green:0.85,blue:1.0).opacity(rayAlpha * 0.65)), lineWidth:1.2)
        }

        // [DRAW 39] Floor energy pulse ring (expanding)
        let pulseR = CGFloat(10 + sin(t * 5.0) * 8)
        var pulseRing = Path()
        pulseRing.addEllipse(in: CGRect(x:cx-pulseR, y:fy-pulseR*0.3, width:pulseR*2, height:pulseR*0.6))
        ctx.stroke(pulseRing, with:.color(Color(red:0.3,green:1.0,blue:0.9).opacity(0.55)), lineWidth:1.5)

        // [DRAW 40] Air distortion shimmer (animated sine displacement overlay)
        for i in 0..<8 {
            let shimmerX = cx - 45 + CGFloat(i) * 12
            let shimmerAmp = CGFloat(sin(t * 9.0 + Double(i) * 0.7)) * 4
            var shimmer = Path()
            shimmer.move(to: CGPoint(x:shimmerX, y:fy-80))
            shimmer.addLine(to: CGPoint(x:shimmerX + shimmerAmp, y:fy-50))
            shimmer.addLine(to: CGPoint(x:shimmerX - shimmerAmp, y:fy-20))
            ctx.stroke(shimmer, with:.color(Color(red:0.5,green:1.0,blue:0.95).opacity(0.12)), lineWidth:1)
        }
    }

    // MARK: - Dragon Aura

    private func drawDragonAura(ctx: inout GraphicsContext) {
        let positions: [CGFloat] = [W*0.25, W*0.75]
        for fighterX in positions {
            let cy = floorY - 60

            // [DRAW 41] Outer chi aura layer (cyan)
            for i in 0..<20 {
                let angle = Double(i)/20.0 * .pi*2 + t*2.8
                let dist  = 34 + sin(t*5.0+Double(i)*0.7)*18
                let px = fighterX + CGFloat(cos(angle))*CGFloat(dist)
                let py = cy + CGFloat(sin(angle))*CGFloat(dist)*0.55
                let alpha = 0.35 + 0.55*abs(sin(t*5.5+Double(i)*0.5))
                var sc = ctx
                sc.addFilter(.shadow(color:Color(red:0.0,green:0.9,blue:1.0).opacity(0.55), radius:5))
                sc.fill(Path(ellipseIn:CGRect(x:px-3,y:py-3,width:6,height:6)),
                        with:.color(Color(red:0.0,green:0.9,blue:1.0).opacity(alpha)))
            }

            // [DRAW 42] Middle chi aura layer (purple)
            for i in 0..<14 {
                let angle = Double(i)/14.0 * .pi*2 - t*3.5
                let dist  = 20 + sin(t*6.0+Double(i)*0.9)*10
                let px = fighterX + CGFloat(cos(angle))*CGFloat(dist)
                let py = cy + CGFloat(sin(angle))*CGFloat(dist)*0.5
                let alpha = 0.30 + 0.50*abs(sin(t*7.0+Double(i)*0.6))
                var pc = ctx
                pc.addFilter(.shadow(color:Color(red:0.6,green:0.0,blue:1.0).opacity(0.5), radius:4))
                pc.fill(Path(ellipseIn:CGRect(x:px-2,y:py-2,width:4,height:4)),
                        with:.color(Color(red:0.7,green:0.0,blue:1.0).opacity(alpha)))
            }

            // [DRAW 43] Inner glow halo (bright white-cyan core)
            var innerHalo = ctx
            innerHalo.addFilter(.shadow(color:Color(red:0.5,green:1.0,blue:1.0).opacity(0.6), radius:14))
            innerHalo.fill(Path(ellipseIn:CGRect(x:fighterX-16, y:cy-24, width:32, height:48)),
                           with:.color(Color(red:0.8,green:1.0,blue:1.0).opacity(0.06)))
        }

        // [DRAW 44] Dragon mode screen veil (subtle blue-cyan tint)
        ctx.fill(Path(CGRect(origin:.zero,size:size)),
                 with:.color(Color(red:0.0,green:0.12,blue:0.22).opacity(0.06)))
    }

    // MARK: - Dragon Eye Glow

    private func drawDragonEyes(ctx: inout GraphicsContext) {
        let fighterData: [(CGFloat, Bool)] = [(W*0.25, false), (W*0.75, true)]
        for (fighterX, flip) in fighterData {
            let mirror: CGFloat = flip ? -1 : 1
            let feetY = floorY - 2
            let shoulderPt = CGPoint(x: fighterX + StickPose.dragon.shoulder.x * mirror,
                                     y: feetY + StickPose.dragon.shoulder.y)
            let eyeY = shoulderPt.y - 10
            let eyeGlow = 0.7 + 0.3 * sin(t * 8.0 + (flip ? 1.0 : 0.0))

            // [DRAW 45] Left eye glow dot
            var lEye = ctx
            lEye.addFilter(.shadow(color:Color(red:0.0,green:1.0,blue:0.9).opacity(0.9), radius:5))
            lEye.fill(Path(ellipseIn:CGRect(x:shoulderPt.x - 5*mirror - 1.5, y:eyeY-1.5, width:3, height:3)),
                      with:.color(Color(red:0.4,green:1.0,blue:0.95).opacity(eyeGlow)))

            // [DRAW 46] Right eye glow dot
            var rEye = ctx
            rEye.addFilter(.shadow(color:Color(red:0.0,green:1.0,blue:0.9).opacity(0.9), radius:5))
            rEye.fill(Path(ellipseIn:CGRect(x:shoulderPt.x + 2*mirror - 1.5, y:eyeY-1.5, width:3, height:3)),
                      with:.color(Color(red:0.4,green:1.0,blue:0.95).opacity(eyeGlow)))
        }
    }

    // MARK: - Fighter

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

        // [DRAW 47] Fighter head (with glow shadow)
        var hc = ctx
        hc.addFilter(.shadow(color:color.opacity(0.45),radius:5))
        hc.fill(Path(ellipseIn:CGRect(x:pt(headCenter).x-headR, y:pt(headCenter).y-headR, width:headR*2,height:headR*2)),
                with:.color(color))

        // [DRAW 48] Torso
        line(pose.shoulder, hip)

        // [DRAW 49] Right upper arm
        line(pose.shoulder, pose.rElbow)
        // [DRAW 50] Right forearm
        line(pose.rElbow,   pose.rWrist)
        // [DRAW 51] Left upper arm
        line(pose.shoulder, pose.lElbow)
        // [DRAW 52] Left forearm
        line(pose.lElbow,   pose.lWrist)
        // [DRAW 53] Right thigh
        line(hip,        pose.rKnee)
        // [DRAW 54] Right shin
        line(pose.rKnee, pose.rAnkle)
        // [DRAW 55] Left thigh
        line(hip,        pose.lKnee)
        // [DRAW 56] Left shin
        line(pose.lKnee, pose.lAnkle)

        // [DRAW 57] Wrist/fist dots
        var lFist = Path()
        lFist.addEllipse(in: CGRect(x:pt(pose.rWrist).x-3, y:pt(pose.rWrist).y-3, width:6, height:6))
        ctx.fill(lFist, with:.color(color.opacity(0.85)))
        var rFist = Path()
        rFist.addEllipse(in: CGRect(x:pt(pose.lWrist).x-3, y:pt(pose.lWrist).y-3, width:6, height:6))
        ctx.fill(rFist, with:.color(color.opacity(0.85)))

        // [DRAW 58] Foot dots
        var lFoot = Path()
        lFoot.addEllipse(in: CGRect(x:pt(pose.rAnkle).x-3, y:pt(pose.rAnkle).y-2, width:6, height:4))
        ctx.fill(lFoot, with:.color(color.opacity(0.7)))
        var rFoot = Path()
        rFoot.addEllipse(in: CGRect(x:pt(pose.lAnkle).x-3, y:pt(pose.lAnkle).y-2, width:6, height:4))
        ctx.fill(rFoot, with:.color(color.opacity(0.7)))
    }

    // MARK: - Shadows

    private func drawShadows(ctx: inout GraphicsContext) {
        for cx in [W*0.25, W*0.75] as [CGFloat] {
            // [DRAW 59] Ground shadow ellipses
            var s = Path()
            s.addEllipse(in:CGRect(x:cx-24,y:floorY+2,width:48,height:9))
            ctx.fill(s, with:.color(Color.black.opacity(0.30)))
        }
    }

    // MARK: - Match Timer Arc

    private func drawMatchTimerArc(ctx: inout GraphicsContext) {
        let arcCX = W / 2
        let arcCY = H * 0.038
        let arcR: CGFloat = 16

        // [DRAW 60] Timer arc background ring
        var bgRing = Path()
        bgRing.addEllipse(in: CGRect(x:arcCX-arcR, y:arcCY-arcR, width:arcR*2, height:arcR*2))
        ctx.stroke(bgRing, with:.color(Color.white.opacity(0.10)), lineWidth:3)

        // [DRAW 61] Timer arc progress (animated pulse ring)
        let pulsing = 0.6 + 0.4*sin(t * 2.5)
        var pulseRing2 = Path()
        pulseRing2.addEllipse(in: CGRect(x:arcCX-arcR-2, y:arcCY-arcR-2, width:(arcR+2)*2, height:(arcR+2)*2))
        ctx.stroke(pulseRing2, with:.color(Color(red:1.0,green:0.22,blue:0.22).opacity(0.18 * pulsing)), lineWidth:1)

        // [DRAW 62] Round indicator dot
        var roundDot = Path()
        roundDot.addEllipse(in: CGRect(x:arcCX-3, y:arcCY-3, width:6, height:6))
        ctx.fill(roundDot, with:.color(Color(red:1.0,green:0.80,blue:0.20).opacity(0.80)))
    }

    // MARK: - Canvas HP Bars

    private func drawCanvasHPBars(ctx: inout GraphicsContext) {
        let barH: CGFloat = 7
        let barW: CGFloat = W * 0.28
        let barY: CGFloat = H * 0.015
        let playerFrac = CGFloat(max(0, min(1, playerHP / 100.0)))
        let oppFrac    = CGFloat(max(0, min(1, opponentHP / 100.0)))

        // [DRAW 63] Player HP bar background
        var pBarBg = Path()
        pBarBg.addRoundedRect(in: CGRect(x:W*0.04, y:barY, width:barW, height:barH),
                              cornerSize: CGSize(width:3, height:3))
        ctx.fill(pBarBg, with:.color(Color.white.opacity(0.07)))

        // [DRAW 64] Player HP bar fill (cyan gradient depletes left-to-right)
        if playerFrac > 0 {
            var pBarFill = Path()
            pBarFill.addRoundedRect(in: CGRect(x:W*0.04, y:barY, width:barW*playerFrac, height:barH),
                                    cornerSize: CGSize(width:3, height:3))
            ctx.fill(pBarFill, with:.linearGradient(
                Gradient(colors:[Color(red:0.15,green:0.85,blue:1.0), Color(red:0.05,green:0.45,blue:0.65)]),
                startPoint: CGPoint(x:W*0.04, y:barY),
                endPoint: CGPoint(x:W*0.04+barW, y:barY)))
        }

        // [DRAW 65] Player HP low-health pulse glow
        if playerHP < 25 {
            let pulseA = 0.35 + 0.35*sin(t * 6.0)
            var pGlow = ctx
            pGlow.addFilter(.shadow(color:Color(red:0.15,green:0.85,blue:1.0).opacity(pulseA), radius:8))
            var gRect = Path()
            gRect.addRoundedRect(in: CGRect(x:W*0.04, y:barY, width:barW*playerFrac, height:barH),
                                 cornerSize: CGSize(width:3, height:3))
            pGlow.fill(gRect, with:.color(Color(red:0.15,green:0.85,blue:1.0).opacity(0.15)))
        }

        // [DRAW 66] Opponent HP bar background
        let oppBarRight = W * 0.96
        let oppBarLeft  = oppBarRight - barW
        var oBarBg = Path()
        oBarBg.addRoundedRect(in: CGRect(x:oppBarLeft, y:barY, width:barW, height:barH),
                              cornerSize: CGSize(width:3, height:3))
        ctx.fill(oBarBg, with:.color(Color.white.opacity(0.07)))

        // [DRAW 67] Opponent HP bar fill (red gradient depletes right-to-left)
        if oppFrac > 0 {
            var oBarFill = Path()
            let fillLeft = oppBarRight - barW * oppFrac
            oBarFill.addRoundedRect(in: CGRect(x:fillLeft, y:barY, width:barW*oppFrac, height:barH),
                                    cornerSize: CGSize(width:3, height:3))
            ctx.fill(oBarFill, with:.linearGradient(
                Gradient(colors:[Color(red:0.65,green:0.05,blue:0.05), Color(red:1.0,green:0.22,blue:0.22)]),
                startPoint: CGPoint(x:fillLeft, y:barY),
                endPoint: CGPoint(x:oppBarRight, y:barY)))
        }

        // [DRAW 68] Opponent HP low-health pulse glow
        if opponentHP < 25 {
            let pulseA = 0.35 + 0.35*sin(t * 6.0 + .pi)
            var oGlow = ctx
            oGlow.addFilter(.shadow(color:Color(red:1.0,green:0.22,blue:0.22).opacity(pulseA), radius:8))
            let fillLeft = oppBarRight - barW * oppFrac
            var gRect = Path()
            gRect.addRoundedRect(in: CGRect(x:fillLeft, y:barY, width:barW*oppFrac, height:barH),
                                 cornerSize: CGSize(width:3, height:3))
            oGlow.fill(gRect, with:.color(Color(red:1.0,green:0.22,blue:0.22).opacity(0.15)))
        }

        // [DRAW 69] Player KI energy circular gauge
        let kiR: CGFloat = 7
        let kiX = W * 0.04 + barW / 2
        let kiY = barY + barH + kiR + 3
        var kiBg = Path()
        kiBg.addEllipse(in: CGRect(x:kiX-kiR, y:kiY-kiR, width:kiR*2, height:kiR*2))
        ctx.stroke(kiBg, with:.color(Color.white.opacity(0.12)), lineWidth:2)

        // [DRAW 70] Opponent KI energy circular gauge
        let okiX = oppBarLeft + barW / 2
        var okiBg = Path()
        okiBg.addEllipse(in: CGRect(x:okiX-kiR, y:kiY-kiR, width:kiR*2, height:kiR*2))
        ctx.stroke(okiBg, with:.color(Color.white.opacity(0.12)), lineWidth:2)
    }

    // MARK: - Impact Ring

    private func drawImpactRing(ctx: inout GraphicsContext, timeSince: Double) {
        let frac = min(1.0, timeSince / 0.55)
        let eased = 1.0 - pow(1.0-frac, 2.5)  // ease-out
        let alpha = max(0, 1.0 - frac * 1.4)
        let cx: CGFloat = W * 0.62
        let cy: CGFloat = floorY - H * 0.30

        let sparkColor: Color = lastHitType == "kick"   ? Color(red:1.0,green:0.45,blue:0.0) :
                                lastHitType == "dragon" ? Color.yellow :
                                Color(red:0.2,green:0.7,blue:1.0)

        // [DRAW 71] Primary expanding impact ring
        let ringR = CGFloat(eased) * 42
        var ring = Path()
        ring.addEllipse(in: CGRect(x:cx-ringR, y:cy-ringR*0.6, width:ringR*2, height:ringR*1.2))
        ctx.stroke(ring, with:.color(sparkColor.opacity(alpha * 0.85)), lineWidth:2.5)

        // [DRAW 72] Secondary outer ring (slightly delayed)
        let ring2R = CGFloat(max(0, eased - 0.15)) * 58
        if ring2R > 0 {
            var ring2 = Path()
            ring2.addEllipse(in: CGRect(x:cx-ring2R, y:cy-ring2R*0.55, width:ring2R*2, height:ring2R*1.1))
            ctx.stroke(ring2, with:.color(sparkColor.opacity(alpha * 0.45)), lineWidth:1.2)
        }

        // [DRAW 73] White inner flash ring
        let flashFrac = max(0, 1.0 - frac * 2.8)
        if flashFrac > 0 {
            var flashRing = Path()
            let fr = CGFloat(flashFrac) * 20
            flashRing.addEllipse(in: CGRect(x:cx-fr, y:cy-fr*0.6, width:fr*2, height:fr*1.2))
            var glowCtx = ctx
            glowCtx.addFilter(.shadow(color:Color.white.opacity(0.8), radius:6))
            glowCtx.stroke(flashRing, with:.color(Color.white.opacity(flashFrac)), lineWidth:3)
        }
    }

    // MARK: - Screen Vignette

    private func drawScreenVignette(ctx: inout GraphicsContext, timeSince: Double) {
        let frac = min(1.0, timeSince / 0.55)
        let flashAlpha = max(0, 1.0 - frac * 2.2)
        guard flashAlpha > 0.01 else { return }

        let hitColor: Color = lastHitType == "dragon" ? .yellow :
                              Color(red:1.0, green:0.12, blue:0.12)  // red vignette on hit

        // [DRAW 74] Screen edge vignette flash (even-odd fill: outer rect minus inner ellipse)
        var vignette = Path()
        vignette.addRect(CGRect(origin:.zero, size:size))
        vignette.addEllipse(in: CGRect(x:W*0.08, y:H*0.08, width:W*0.84, height:H*0.84))
        ctx.fill(vignette, with:.color(hitColor.opacity(flashAlpha * 0.32)))
    }

    // MARK: - Hit Sparks

    private func drawHitSparks(ctx: inout GraphicsContext, timeSince: Double) {
        let frac = timeSince / 0.55
        let alpha = max(0, 1.0 - frac * 1.4)
        let cx: CGFloat = W * 0.62
        let cy: CGFloat = floorY - H * 0.30

        let sparkColor: Color = lastHitType == "kick"   ? Color(red:1.0,green:0.45,blue:0.0) :
                                lastHitType == "dragon" ? Color.yellow :
                                Color(red:0.2,green:0.7,blue:1.0)

        // [DRAW 75] Radial sparks shooting outward
        let sparkCount = lastHitType == "dragon" ? 16 : 10
        for i in 0..<sparkCount {
            let angle = Double(i) / Double(sparkCount) * .pi * 2
            let sparkDist = CGFloat(frac) * 42
            let sx = cx + CGFloat(cos(angle)) * sparkDist
            let sy = cy + CGFloat(sin(angle)) * sparkDist * 0.55
            var sp = Path()
            sp.move(to: CGPoint(x:cx, y:cy))
            sp.addLine(to: CGPoint(x:sx, y:sy))
            ctx.stroke(sp, with:.color(sparkColor.opacity(alpha * 0.90)), lineWidth:1.8)
            // [DRAW 76] Spark tip dot
            var dot = ctx
            dot.addFilter(.shadow(color: sparkColor.opacity(0.70), radius: 4))
            dot.fill(Path(ellipseIn: CGRect(x:sx-2.5,y:sy-2.5,width:5,height:5)),
                     with:.color(sparkColor.opacity(alpha)))
        }

        // [DRAW 77] 8 additional secondary spark streaks (diagonal)
        for i in 0..<8 {
            let angle2 = Double(i) / 8.0 * .pi * 2 + 0.39
            let dist2 = CGFloat(frac) * 24
            let s2x = cx + CGFloat(cos(angle2)) * dist2
            let s2y = cy + CGFloat(sin(angle2)) * dist2 * 0.6
            var sp2 = Path()
            sp2.move(to: CGPoint(x:cx, y:cy))
            sp2.addLine(to: CGPoint(x:s2x, y:s2y))
            ctx.stroke(sp2, with:.color(Color.white.opacity(alpha * 0.45)), lineWidth:1)
        }

        // [DRAW 78] Central flash burst
        let flashR = CGFloat(max(0, 1.0 - frac * 2.8)) * 20
        if flashR > 0 {
            var gc = ctx
            gc.addFilter(.shadow(color: sparkColor.opacity(0.90), radius:12))
            gc.fill(Path(ellipseIn: CGRect(x:cx-flashR,y:cy-flashR,width:flashR*2,height:flashR*2)),
                    with:.color(Color.white.opacity(min(1.5,alpha * 1.6))))
        }

        // [DRAW 79] Impact smoke puff (grey expanding circle, delayed)
        let smokeFrac = max(0, frac - 0.15)
        if smokeFrac > 0 && smokeFrac < 0.8 {
            let smokeR = CGFloat(smokeFrac) * 30
            var smoke = Path()
            smoke.addEllipse(in: CGRect(x:cx-smokeR, y:cy-smokeR*0.5, width:smokeR*2, height:smokeR))
            ctx.fill(smoke, with:.color(Color(white:0.7).opacity(max(0, (0.8-smokeFrac)) * 0.12)))
        }
    }

    // MARK: - Combo Display

    private func drawComboDisplay(ctx: inout GraphicsContext) {
        // [DRAW 80] Combo multiplier text in canvas (bottom center area)
        let comboY = floorY + (H - floorY) * 0.45
        let comboText = "×\(comboCount) COMBO"
        let comboScale = 1.0 + 0.08 * sin(t * 8.0)
        let comboAlpha = min(1.0, 0.7 + 0.3 * sin(t * 5.0))

        var comboCtx = ctx
        comboCtx.opacity = comboAlpha * comboScale
        comboCtx.draw(Text(comboText)
            .font(.system(size:16, weight:.black, design:.monospaced))
            .foregroundColor(comboCount >= 5 ? Color.yellow : Color(red:0.95,green:0.85,blue:0.20)),
                      at: CGPoint(x:W/2, y:comboY),
                      anchor:.center)

        // [DRAW 81] Combo glow underline
        if comboCount >= 3 {
            let lineW: CGFloat = CGFloat(min(comboCount, 10)) * 8
            var comboLine = Path()
            comboLine.move(to: CGPoint(x:W/2 - lineW/2, y:comboY + 11))
            comboLine.addLine(to: CGPoint(x:W/2 + lineW/2, y:comboY + 11))
            ctx.stroke(comboLine,
                       with:.color(Color.yellow.opacity(0.55 * comboAlpha)),
                       lineWidth:2)
        }

        // [DRAW 82] High combo spark burst (5+)
        if comboCount >= 5 {
            for i in 0..<6 {
                let ang = Double(i)/6.0 * .pi*2 + t*4.0
                let dist: CGFloat = 22 + CGFloat(sin(t*7.0+Double(i)*1.2))*6
                let spX = W/2 + CGFloat(cos(ang))*dist
                let spY = comboY + CGFloat(sin(ang))*dist*0.4
                var sPart = Path()
                sPart.addEllipse(in: CGRect(x:spX-2, y:spY-2, width:4, height:4))
                ctx.fill(sPart, with:.color(Color.yellow.opacity(0.60 * comboAlpha)))
            }
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
    // Enhanced canvas state
    @State private var comboCount: Int = 0
    @State private var roundNumber: Int = 1

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
                       lastHitTime:lastHitTime, lastHitType:lastHitType,
                       comboCount:comboCount,
                       playerHP:playerHP, opponentHP:opponentHP,
                       roundNumber:roundNumber)

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
        comboCount = combo
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
        comboCount = combo
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
        combo = 0; comboCount = 0; playerHP = min(maxHP,playerHP+5)
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
        playerScore += 10; combo += 3; maxCombo = max(maxCombo,combo); comboCount = combo
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
            await MainActor.run { withAnimation { showActionLabel = false }; if combo > 0 { combo -= 1; comboCount = combo } }
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
        GameResultService.saveResult(modeId: "karate", userScore: playerScore, opponentScore: opponentScore)
        viewModel.profile.evolutionShards += outcome == .win ? 50 : outcome == .draw ? 25 : 15
        SaveSystem.saveProfile(viewModel.profile)
    }

    private func cancelAllTasks() {
        gameTimerTask?.cancel(); aiAttackTask?.cancel()
        actionLabelTask?.cancel(); critFlashTask?.cancel(); poseResetTask?.cancel()
    }
}
