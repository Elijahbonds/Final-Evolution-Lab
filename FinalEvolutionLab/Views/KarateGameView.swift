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
    var playerRoundsWon: Int = 0
    var aiRoundsWon: Int = 0
    var superMeter: CGFloat = 0
    var roundTimeRemaining: Double = 30.0

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
                                   roundNumber: roundNumber,
                                   playerRoundsWon: playerRoundsWon,
                                   aiRoundsWon: aiRoundsWon,
                                   superMeter: superMeter,
                                   roundTimeRemaining: roundTimeRemaining)
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
    let playerRoundsWon: Int
    let aiRoundsWon: Int
    let superMeter: CGFloat
    let roundTimeRemaining: Double

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var floorY: CGFloat { H * 0.84 }

    mutating func render(into ctx: inout GraphicsContext) {
        // ---- Layer 1: Deep background ----
        drawBg(ctx: &ctx)
        // ---- Layer 2: Ancient cedar trees, shimenawa rope, torii gate ----
        drawWalls(ctx: &ctx)
        // ---- Layer 3: Forest canopy light shafts + mist ----
        drawLightShafts(ctx: &ctx)
        // ---- Layer 4: Stone toro lanterns ----
        drawTournamentBracket(ctx: &ctx)
        // ---- Layer 5: Shrine visitor silhouettes ----
        drawCrowd(ctx: &ctx)
        // ---- Layer 6: Mossy stone path floor ----
        drawFloor(ctx: &ctx)
        // ---- Layer 7: Hanging red chochin lanterns ----
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
        // ---- Layer 12: Round timer arc ----
        drawRoundTimerArc(ctx: &ctx)
        // ---- Layer 13: HP bar canvas elements ----
        drawCanvasHPBars(ctx: &ctx)
        // ---- Layer 14: Round indicator circles ----
        drawRoundIndicators(ctx: &ctx)
        // ---- Layer 15: Super meter bar ----
        drawSuperMeterBar(ctx: &ctx)
        // ---- Layer 16: Hit impact effects ----
        let timeSinceHit = t - lastHitTime
        if timeSinceHit < 0.55 && lastHitTime > 0 {
            drawImpactRing(ctx: &ctx, timeSince: timeSinceHit)
            drawScreenVignette(ctx: &ctx, timeSince: timeSinceHit)
            drawHitSparks(ctx: &ctx, timeSince: timeSinceHit)
        }
        // ---- Layer 17: Combo multiplier display ----
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

    // MARK: - Background (Shimogamo Jinja shrine — outdoor forest setting)

    private func drawBg(ctx: inout GraphicsContext) {
        // [DRAW 1] Forest canopy sky — deep green overhead
        ctx.fill(Path(CGRect(origin:.zero, size:size)),
                 with:.color(Color(red:0.12,green:0.28,blue:0.14)))

        // [DRAW 2] Upper canopy gradient — darker at top, lighter mid-zone
        var canopyGrad = Path()
        canopyGrad.addRect(CGRect(x:0, y:0, width:W, height:H*0.72))
        ctx.fill(canopyGrad,
                 with:.linearGradient(
                    Gradient(colors:[Color(red:0.06,green:0.15,blue:0.08),
                                     Color(red:0.15,green:0.35,blue:0.18),
                                     Color(red:0.18,green:0.40,blue:0.20)]),
                    startPoint: CGPoint(x:W/2, y:0),
                    endPoint: CGPoint(x:W/2, y:H*0.72)))

        // [DRAW 3] Dappled sky light patches — cyan glimpses through canopy (random-seeded ellipses)
        let skySpots: [(CGFloat,CGFloat,CGFloat,CGFloat)] = [
            (W*0.22, H*0.03, W*0.09, H*0.06),
            (W*0.50, H*0.01, W*0.12, H*0.05),
            (W*0.74, H*0.04, W*0.08, H*0.05),
            (W*0.35, H*0.07, W*0.06, H*0.04),
            (W*0.60, H*0.08, W*0.07, H*0.04),
            (W*0.12, H*0.09, W*0.05, H*0.03),
            (W*0.86, H*0.07, W*0.06, H*0.035),
        ]
        for (sx, sy, sw, sh) in skySpots {
            var sky = Path()
            sky.addEllipse(in: CGRect(x:sx, y:sy, width:sw, height:sh))
            var gc = ctx; gc.addFilter(.blur(radius: 5))
            gc.fill(sky, with:.color(Color(red:0.55,green:0.82,blue:0.90).opacity(0.28)))
        }

        // [DRAW 4] Mid-zone ambient green glow — forest air
        var midGlow = Path()
        midGlow.addEllipse(in: CGRect(x:W*0.10, y:H*0.15, width:W*0.80, height:H*0.55))
        var mgCtx = ctx; mgCtx.addFilter(.blur(radius: 14))
        mgCtx.fill(midGlow, with:.color(Color(red:0.20,green:0.48,blue:0.22).opacity(0.18)))
    }

    // MARK: - Ancient Cedar Trees, Torii Gate & Shimenawa (Shimogamo Jinja)

    private func drawWalls(ctx: inout GraphicsContext) {
        // [DRAW 5] Left and right cedar tree clusters — tall dark trunks leaning slightly inward
        let treeData: [(cx: CGFloat, lean: CGFloat, trunkW: CGFloat, trunkH: CGFloat)] = [
            (W*0.04,  1.5, W*0.028, H*0.70),
            (W*0.11, -0.5, W*0.022, H*0.65),
            (W*0.07,  2.0, W*0.018, H*0.62),
            (W*0.96, -1.5, W*0.028, H*0.70),
            (W*0.89,  0.5, W*0.022, H*0.65),
            (W*0.93, -2.0, W*0.018, H*0.62),
        ]
        for td in treeData {
            let topX = td.cx + td.lean
            var trunk = Path()
            trunk.move(to: CGPoint(x: td.cx - td.trunkW/2, y: floorY))
            trunk.addLine(to: CGPoint(x: td.cx + td.trunkW/2, y: floorY))
            trunk.addLine(to: CGPoint(x: topX + td.trunkW/3, y: floorY - td.trunkH))
            trunk.addLine(to: CGPoint(x: topX - td.trunkW/3, y: floorY - td.trunkH))
            trunk.closeSubpath()
            ctx.fill(trunk, with:.color(Color(red:0.22,green:0.16,blue:0.10)))

            // [DRAW 6] Bark texture lines on trunk
            for bi in 0..<4 {
                let by = floorY - td.trunkH * CGFloat(bi+1) / 5.0
                let bxLeft = topX - td.trunkW/3 - 2
                var bark = Path()
                bark.move(to: CGPoint(x:bxLeft, y:by))
                bark.addLine(to: CGPoint(x:bxLeft + td.trunkW*0.6, y:by + CGFloat(bi)*1.2))
                ctx.stroke(bark, with:.color(Color(red:0.12,green:0.08,blue:0.04).opacity(0.35)), lineWidth:0.8)
            }

            // [DRAW 7] Heavy foliage masses — large blurred green ellipses at top
            let foliageY = floorY - td.trunkH - H*0.06
            for fi in 0..<3 {
                let fScale: CGFloat = [1.0, 0.75, 0.55][fi]
                let fOffY: CGFloat = [0, H*0.04, H*0.08][fi]
                var foliage = Path()
                foliage.addEllipse(in: CGRect(
                    x: topX - W*0.12*fScale,
                    y: foliageY + fOffY,
                    width: W*0.24*fScale,
                    height: H*0.18*fScale))
                var fc = ctx; fc.addFilter(.blur(radius: 6.0 * fScale))
                let greenTone = Color(red: 0.08+fScale*0.08, green: 0.22+fScale*0.12, blue: 0.08+fScale*0.04)
                fc.fill(foliage, with:.color(greenTone.opacity(0.88)))
            }
        }

        // [DRAW 8] Shimenawa rope — thick braided rope across upper area with slight sag
        let ropeY = H * 0.115
        var rope = Path()
        rope.move(to: CGPoint(x:0, y:ropeY))
        rope.addQuadCurve(to: CGPoint(x:W, y:ropeY),
                          control: CGPoint(x:W/2, y:ropeY + H*0.025))
        ctx.stroke(rope, with:.color(Color(red:0.55,green:0.42,blue:0.28).opacity(0.75)), lineWidth:5)
        ctx.stroke(rope, with:.color(Color(red:0.30,green:0.20,blue:0.10).opacity(0.35)), lineWidth:2)

        // [DRAW 9] Shide (zig-zag white paper strips) hanging from shimenawa
        let shidePositions: [CGFloat] = [W*0.18, W*0.30, W*0.42, W*0.50, W*0.58, W*0.70, W*0.82]
        for shX in shidePositions {
            let shideLen: CGFloat = H * 0.055
            var shide = Path()
            shide.move(to: CGPoint(x:shX, y:ropeY + 2))
            let zigW: CGFloat = 5
            for s in 0..<6 {
                let sy = ropeY + 2 + shideLen * CGFloat(s+1) / 6.0
                let sx = shX + (s % 2 == 0 ? zigW : -zigW)
                shide.addLine(to: CGPoint(x:sx, y:sy))
            }
            ctx.stroke(shide, with:.color(Color.white.opacity(0.65)), lineWidth:1.8)
        }

        // [DRAW 10] Torii gate — classic vermillion red gate in background center
        let toriiCX = W * 0.50
        let toriiBaseY = floorY - H * 0.02
        let toriiH = H * 0.52
        let toriiW = W * 0.38
        let postW: CGFloat = W * 0.022
        let toriiColor = Color(red:0.82,green:0.18,blue:0.12)

        // Left post
        var lPost = Path()
        lPost.addRect(CGRect(x: toriiCX - toriiW/2, y: toriiBaseY - toriiH, width: postW, height: toriiH))
        ctx.fill(lPost, with:.color(toriiColor.opacity(0.88)))
        // Right post
        var rPost = Path()
        rPost.addRect(CGRect(x: toriiCX + toriiW/2 - postW, y: toriiBaseY - toriiH, width: postW, height: toriiH))
        ctx.fill(rPost, with:.color(toriiColor.opacity(0.88)))

        // Upper kasagi beam (top curved beam)
        let kasagiY = toriiBaseY - toriiH
        var kasagi = Path()
        kasagi.move(to: CGPoint(x: toriiCX - toriiW/2 - W*0.02, y: kasagiY + H*0.014))
        kasagi.addQuadCurve(
            to: CGPoint(x: toriiCX + toriiW/2 + W*0.02, y: kasagiY + H*0.014),
            control: CGPoint(x: toriiCX, y: kasagiY - H*0.008))
        ctx.stroke(kasagi, with:.color(toriiColor.opacity(0.88)), lineWidth: H*0.022)

        // Lower nuki cross-beam
        let nukiY = toriiBaseY - toriiH * 0.72
        var nuki = Path()
        nuki.addRect(CGRect(x: toriiCX - toriiW/2 + postW*0.5,
                             y: nukiY, width: toriiW - postW, height: H*0.016))
        ctx.fill(nuki, with:.color(toriiColor.opacity(0.82)))

        // [DRAW 11] Torii kasagi shadow/depth
        var kasagiShadow = Path()
        kasagiShadow.addRect(CGRect(x: toriiCX - toriiW/2 - W*0.015,
                                    y: kasagiY + H*0.012,
                                    width: toriiW + W*0.030, height: H*0.012))
        ctx.fill(kasagiShadow, with:.color(Color(red:0.30,green:0.04,blue:0.02).opacity(0.45)))
    }

    // MARK: - Forest Canopy Light Shafts & Atmospheric Mist

    private func drawLightShafts(ctx: inout GraphicsContext) {
        // [DRAW 12] Forest canopy light shafts — soft golden beams, subtle opacity 0.04-0.08
        let shaftDefs: [(topX: CGFloat, topW: CGFloat, botX: CGFloat, botW: CGFloat)] = [
            (W*0.18, W*0.04, W*0.22, W*0.08),
            (W*0.30, W*0.03, W*0.32, W*0.06),
            (W*0.44, W*0.05, W*0.40, W*0.10),
            (W*0.56, W*0.04, W*0.60, W*0.09),
            (W*0.68, W*0.03, W*0.66, W*0.07),
            (W*0.80, W*0.04, W*0.78, W*0.09),
        ]
        for (idx, sd) in shaftDefs.enumerated() {
            let alpha = 0.04 + 0.04 * sin(t * 0.4 + Double(idx) * 0.9)
            var shaft = Path()
            shaft.move(to: CGPoint(x: sd.topX - sd.topW/2, y: 0))
            shaft.addLine(to: CGPoint(x: sd.topX + sd.topW/2, y: 0))
            shaft.addLine(to: CGPoint(x: sd.botX + sd.botW/2, y: floorY))
            shaft.addLine(to: CGPoint(x: sd.botX - sd.botW/2, y: floorY))
            shaft.closeSubpath()
            var sc = ctx; sc.addFilter(.blur(radius: 3))
            sc.fill(shaft, with:.color(Color(red:0.95,green:0.88,blue:0.60).opacity(alpha)))
        }

        // [DRAW 13] Floating forest spore/pollen particles (replace indoor dust)
        let sporeAreaTop: CGFloat = H * 0.12
        let sporeAreaH = floorY - sporeAreaTop
        for i in 0..<24 {
            let drift = CGFloat(sin(t * 0.18 + Double(i) * 0.77)) * W * 0.04
            let px = W * CGFloat(i % 8) / 8.0 + W * 0.06 + drift
            let rawFrac = (t * 8.0 + Double(i) * 5.6)
            let py = sporeAreaTop + CGFloat(rawFrac.truncatingRemainder(dividingBy: Double(sporeAreaH)))
            var spore = Path()
            spore.addEllipse(in: CGRect(x:px-1.2, y:py-1.2, width:2.4, height:2.4))
            let sporeAlpha = 0.18 + 0.14 * sin(t * 0.9 + Double(i) * 1.3)
            ctx.fill(spore, with:.color(Color(red:0.88,green:0.95,blue:0.70).opacity(sporeAlpha)))
        }

        // [DRAW 14] Atmospheric mist near ground — thin fog strip at floor level, opacity 0.12
        var fog = Path()
        fog.addRect(CGRect(x:0, y:floorY - H*0.04, width:W, height:H*0.06))
        var fogCtx = ctx; fogCtx.addFilter(.blur(radius: 8))
        fogCtx.fill(fog, with:.color(Color.white.opacity(0.12)))
    }

    // MARK: - Stone Toro Lanterns (replaces tournament bracket)

    private func drawTournamentBracket(ctx: inout GraphicsContext) {
        // [DRAW 19] Stone toro lanterns flanking the fight area (2 lanterns)
        let stoneLanternDefs: [(cx: CGFloat, baseY: CGFloat)] = [
            (W*0.06, floorY),
            (W*0.94, floorY),
        ]
        for (idx, ld) in stoneLanternDefs.enumerated() {
            let cx = ld.cx
            let baseY = ld.baseY
            let flicker = 0.75 + 0.25 * sin(t * 2.8 + Double(idx) * 1.7)

            // Ground plinth (base stone)
            let plinthW: CGFloat = W * 0.048
            let plinthH: CGFloat = H * 0.032
            var plinth = Path()
            plinth.addRect(CGRect(x:cx - plinthW/2, y:baseY - plinthH, width:plinthW, height:plinthH))
            ctx.fill(plinth, with:.color(Color(red:0.55,green:0.53,blue:0.50)))
            ctx.stroke(plinth, with:.color(Color(red:0.35,green:0.33,blue:0.30).opacity(0.6)), lineWidth:0.8)

            // Cylindrical shaft
            let shaftW: CGFloat = W * 0.028
            let shaftH: CGFloat = H * 0.10
            var shaft = Path()
            shaft.addRect(CGRect(x:cx - shaftW/2, y:baseY - plinthH - shaftH, width:shaftW, height:shaftH))
            ctx.fill(shaft, with:.color(Color(red:0.52,green:0.50,blue:0.47)))
            ctx.stroke(shaft, with:.color(Color(red:0.35,green:0.33,blue:0.30).opacity(0.5)), lineWidth:0.7)

            // [DRAW 20] Lantern body (hibukuro — fire chamber) with warm amber glow
            let bodyW: CGFloat = W * 0.040
            let bodyH: CGFloat = H * 0.065
            let bodyY = baseY - plinthH - shaftH - bodyH
            var body = Path()
            body.addRect(CGRect(x:cx - bodyW/2, y:bodyY, width:bodyW, height:bodyH))
            ctx.fill(body, with:.color(Color(red:0.55,green:0.53,blue:0.50)))
            ctx.stroke(body, with:.color(Color(red:0.35,green:0.33,blue:0.30).opacity(0.65)), lineWidth:0.9)

            // Lantern window opening with amber glow
            let winW: CGFloat = bodyW * 0.55
            let winH: CGFloat = bodyH * 0.45
            let winRect = CGRect(x:cx - winW/2, y:bodyY + bodyH*0.25, width:winW, height:winH)
            var winPath = Path(); winPath.addRect(winRect)
            var gwCtx = ctx; gwCtx.addFilter(.blur(radius: 5))
            gwCtx.fill(winPath, with:.color(Color(red:0.95,green:0.68,blue:0.25).opacity(0.55 * flicker)))
            ctx.fill(winPath, with:.color(Color(red:0.95,green:0.68,blue:0.25).opacity(0.35 * flicker)))

            // [DRAW 21] Top cap (kasagishi)
            let capW: CGFloat = W * 0.054
            let capH: CGFloat = H * 0.022
            let capY = bodyY - capH
            var cap = Path()
            cap.move(to: CGPoint(x:cx - capW/2, y:capY + capH))
            cap.addLine(to: CGPoint(x:cx + capW/2, y:capY + capH))
            cap.addLine(to: CGPoint(x:cx + capW*0.35, y:capY))
            cap.addLine(to: CGPoint(x:cx - capW*0.35, y:capY))
            cap.closeSubpath()
            ctx.fill(cap, with:.color(Color(red:0.52,green:0.50,blue:0.46)))
            ctx.stroke(cap, with:.color(Color(red:0.35,green:0.33,blue:0.30).opacity(0.55)), lineWidth:0.8)

            // Ambient glow pool on ground from stone lantern
            var glowPool = Path()
            glowPool.addEllipse(in: CGRect(x:cx - bodyW, y:baseY - plinthH*0.5, width:bodyW*2, height:H*0.02))
            var gpCtx = ctx; gpCtx.addFilter(.blur(radius: 6))
            gpCtx.fill(glowPool, with:.color(Color(red:0.95,green:0.75,blue:0.35).opacity(0.18 * flicker)))
        }
    }

    // MARK: - Shrine Visitor Silhouettes (replaces indoor crowd)

    private func drawCrowd(ctx: inout GraphicsContext) {
        // [DRAW 22] Visitor depth band behind silhouettes
        var visitorBand = Path()
        visitorBand.addRect(CGRect(x:0, y:floorY-H*0.17, width:W, height:H*0.07))
        ctx.fill(visitorBand, with:.color(Color(red:0.06,green:0.12,blue:0.06).opacity(0.28 * crowd)))

        // Shrine visitor silhouettes in dark kimono — positioned on both sides only
        let leftVisitors: [CGFloat]  = [W*0.04, W*0.10, W*0.16]
        let rightVisitors: [CGFloat] = [W*0.84, W*0.90, W*0.96]
        let visitorXs = leftVisitors + rightVisitors
        let kimonoColors: [Color] = [
            Color(red:0.10,green:0.08,blue:0.08),
            Color(red:0.14,green:0.10,blue:0.06),
            Color(red:0.08,green:0.10,blue:0.12),
        ]
        let visitorH: CGFloat = H * 0.11
        let visitorBaseY = floorY - H * 0.015

        // [DRAW 23] Shrine visitor silhouettes (6 figures in dark kimono)
        for (idx, vx) in visitorXs.enumerated() {
            let col = kimonoColors[idx % kimonoColors.count]
            let swayAmp: CGFloat = comboCount >= 3 ? 2.0 : 0.8
            let swayFreq = 1.8 + Double(idx) * 0.22
            let sway = CGFloat(sin(t * swayFreq + Double(idx) * 0.9)) * swayAmp

            // Kimono body — wide rectangular silhouette
            let bodyW: CGFloat = W * 0.028
            var vBody = Path()
            vBody.addRect(CGRect(x:vx - bodyW/2 + sway*0.3,
                                 y:visitorBaseY - visitorH,
                                 width:bodyW, height:visitorH * 0.80))
            ctx.fill(vBody, with:.color(col.opacity(0.78 * crowd)))

            // Head
            var vHead = Path()
            vHead.addEllipse(in: CGRect(x:vx - 4.5 + sway*0.3,
                                        y:visitorBaseY - visitorH - 8,
                                        width:9, height:9))
            ctx.fill(vHead, with:.color(col.opacity(0.80 * crowd)))

            // [DRAW 24] Bowing gesture on high combo
            if comboCount >= 4 {
                let bowAng = CGFloat(sin(t * 2.2 + Double(idx) * 0.5)) * 0.35 + 0.2
                let armLen: CGFloat = 12
                let armX = vx + armLen * bowAng
                let armY = (visitorBaseY - visitorH) + visitorH * 0.25 + armLen * bowAng * 0.7
                var arm = Path()
                arm.move(to: CGPoint(x:vx + sway*0.3, y:visitorBaseY - visitorH + visitorH*0.25))
                arm.addLine(to: CGPoint(x:armX + sway*0.3, y:armY))
                ctx.stroke(arm, with:.color(col.opacity(0.55 * crowd)), lineWidth:2.5)
            }
        }

        // [DRAW 25] Shrine lantern ambient warm glow near visitor area
        var shrineAmbient = Path()
        shrineAmbient.addRect(CGRect(x:0, y:floorY-H*0.10, width:W, height:H*0.035))
        let glowIntensity = 0.025 + min(0.06, Double(comboCount) * 0.01)
        ctx.fill(shrineAmbient, with:.color(Color(red:0.75,green:0.55,blue:0.20).opacity(glowIntensity * crowd)))
    }

    // MARK: - Mossy Stone Path Floor (replaces wood planks)

    private func drawFloor(ctx: inout GraphicsContext) {
        // [DRAW 26] Stone path base — ancient weathered stone color
        var floorBase = Path()
        floorBase.addRect(CGRect(x:0, y:floorY, width:W, height:H-floorY))
        ctx.fill(floorBase, with:.color(Color(red:0.38,green:0.36,blue:0.32)))

        // [DRAW 27] Stone slab divisions — horizontal seam lines
        for i in 0..<8 {
            let fy = floorY + CGFloat(i) * (H - floorY) / 8.0
            var seam = Path()
            seam.move(to: CGPoint(x:0, y:fy))
            seam.addLine(to: CGPoint(x:W, y:fy))
            let alpha = 0.14 + Double(i) * 0.03
            ctx.stroke(seam, with:.color(Color(red:0.25,green:0.23,blue:0.20).opacity(alpha)), lineWidth:1.5)
        }

        // [DRAW 28] Stone slab vertical cracks (offset flagstone pattern)
        let crackOffsets: [(CGFloat, CGFloat, CGFloat)] = [
            (W*0.15, floorY, floorY + (H-floorY)*0.5),
            (W*0.35, floorY + (H-floorY)*0.25, floorY + (H-floorY)*0.75),
            (W*0.55, floorY, floorY + (H-floorY)*0.5),
            (W*0.72, floorY + (H-floorY)*0.25, floorY + (H-floorY)*0.75),
            (W*0.88, floorY, floorY + (H-floorY)*0.6),
        ]
        for (crackX, y0, y1) in crackOffsets {
            var crack = Path()
            crack.move(to: CGPoint(x:crackX, y:y0))
            crack.addLine(to: CGPoint(x:crackX + 3, y:y1))
            ctx.stroke(crack, with:.color(Color(red:0.22,green:0.20,blue:0.17).opacity(0.22)), lineWidth:0.9)
        }

        // [DRAW 29] Moss patches — organic irregular shapes on stone
        let mossPatches: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (W*0.05, floorY + H*0.01, W*0.06, H*0.015),
            (W*0.18, floorY + H*0.008, W*0.04, H*0.012),
            (W*0.40, floorY + H*0.006, W*0.05, H*0.014),
            (W*0.62, floorY + H*0.010, W*0.04, H*0.013),
            (W*0.78, floorY + H*0.005, W*0.06, H*0.015),
            (W*0.92, floorY + H*0.009, W*0.04, H*0.012),
            (W*0.28, floorY + H*0.020, W*0.05, H*0.012),
            (W*0.52, floorY + H*0.018, W*0.04, H*0.011),
            (W*0.70, floorY + H*0.022, W*0.05, H*0.013),
        ]
        for (mx, my, mw, mh) in mossPatches {
            var moss = Path()
            moss.addEllipse(in: CGRect(x:mx, y:my, width:mw, height:mh))
            var mc = ctx; mc.addFilter(.blur(radius: 2))
            mc.fill(moss, with:.color(Color(red:0.22,green:0.35,blue:0.20).opacity(0.72)))
        }

        // [DRAW 30] Stone surface wetness gloss — subtle highlight at top of floor
        var highlight = Path()
        highlight.addRect(CGRect(x:0, y:floorY, width:W, height:5))
        ctx.fill(highlight, with:.linearGradient(
            Gradient(colors:[Color(red:0.65,green:0.62,blue:0.55).opacity(0.22), .clear]),
            startPoint: CGPoint(x:0, y:floorY),
            endPoint: CGPoint(x:0, y:floorY+5)))

        // [DRAW 31] Stone path edge line
        var fl = Path()
        fl.move(to: CGPoint(x:0, y:floorY))
        fl.addLine(to: CGPoint(x:W, y:floorY))
        ctx.stroke(fl, with:.color(Color(red:0.28,green:0.26,blue:0.22).opacity(0.55)), lineWidth:2)

        // [DRAW 32] Shrine center stone marker — subtle carved circle on path
        var centerMark = Path()
        centerMark.addEllipse(in: CGRect(x:W*0.30, y:floorY-3, width:W*0.40, height:9))
        ctx.stroke(centerMark, with:.color(Color(red:0.30,green:0.28,blue:0.24).opacity(0.22)), lineWidth:1)
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

    // MARK: - Round Timer Arc

    private func drawRoundTimerArc(ctx: inout GraphicsContext) {
        let arcCX = W / 2
        let arcCY = H * 0.038
        let arcR: CGFloat = 18

        // [DRAW 60] Timer arc background ring
        var bgRing = Path()
        bgRing.addEllipse(in: CGRect(x:arcCX-arcR, y:arcCY-arcR, width:arcR*2, height:arcR*2))
        ctx.stroke(bgRing, with:.color(Color.white.opacity(0.10)), lineWidth:3)

        // [DRAW 61] Timer arc fill — shrinks as time runs out
        let timerFrac = CGFloat(max(0, roundTimeRemaining / 30.0))
        if timerFrac > 0 {
            var timerArc = Path()
            timerArc.addArc(center: CGPoint(x:arcCX, y:arcCY),
                            radius: arcR,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + Double(timerFrac) * 360.0),
                            clockwise: false)
            let timerColor: Color = timerFrac < 0.25 ? Color.red : (timerFrac < 0.5 ? Color.orange : Color.white)
            ctx.stroke(timerArc, with:.color(timerColor.opacity(0.85)), lineWidth:3)
        }

        // [DRAW 62] Round number label inside arc
        var roundCtx = ctx
        roundCtx.draw(Text("R\(roundNumber)").font(.system(size:9, weight:.black, design:.monospaced)).foregroundColor(Color.white.opacity(0.85)),
                      at: CGPoint(x:arcCX, y:arcCY), anchor:.center)

        // [DRAW 63] Low-time pulse ring
        if timerFrac < 0.3 {
            let pulsing = 0.5 + 0.5*sin(t * 4.0)
            var pulseRing = Path()
            pulseRing.addEllipse(in: CGRect(x:arcCX-arcR-3, y:arcCY-arcR-3, width:(arcR+3)*2, height:(arcR+3)*2))
            ctx.stroke(pulseRing, with:.color(Color.red.opacity(0.25 * pulsing)), lineWidth:1.5)
        }
    }

    // MARK: - Round Indicator Circles

    private func drawRoundIndicators(ctx: inout GraphicsContext) {
        let circleR: CGFloat = 5
        let circleY = H * 0.072
        let gap: CGFloat = 14

        // Player circles (left of timer)
        let playerStartX = W/2 - 48 - gap
        for i in 0..<3 {
            let cx = playerStartX - CGFloat(2 - i) * gap
            let won = i < playerRoundsWon
            var circle = Path()
            circle.addEllipse(in: CGRect(x:cx-circleR, y:circleY-circleR, width:circleR*2, height:circleR*2))
            if won {
                ctx.fill(circle, with:.color(Color(red:0.15,green:0.85,blue:1.0).opacity(0.90)))
            } else {
                ctx.stroke(circle, with:.color(Color(red:0.15,green:0.85,blue:1.0).opacity(0.40)), lineWidth:1.2)
            }
        }

        // AI circles (right of timer)
        let aiStartX = W/2 + 48 + gap
        for i in 0..<3 {
            let cx = aiStartX + CGFloat(i) * gap
            let won = i < aiRoundsWon
            var circle = Path()
            circle.addEllipse(in: CGRect(x:cx-circleR, y:circleY-circleR, width:circleR*2, height:circleR*2))
            if won {
                ctx.fill(circle, with:.color(Color(red:1.0,green:0.22,blue:0.22).opacity(0.90)))
            } else {
                ctx.stroke(circle, with:.color(Color(red:1.0,green:0.22,blue:0.22).opacity(0.40)), lineWidth:1.2)
            }
        }
    }

    // MARK: - Super Meter Bar

    private func drawSuperMeterBar(ctx: inout GraphicsContext) {
        let barY = H * 0.088
        let barH: CGFloat = 4
        let barW: CGFloat = W * 0.36
        let barX: CGFloat = (W - barW) / 2

        var bgTrack = Path()
        bgTrack.addRoundedRect(in: CGRect(x:barX, y:barY, width:barW, height:barH),
                               cornerSize: CGSize(width:2, height:2))
        ctx.fill(bgTrack, with:.color(Color.white.opacity(0.07)))

        if superMeter > 0 {
            var fill = Path()
            fill.addRoundedRect(in: CGRect(x:barX, y:barY, width:barW*superMeter, height:barH),
                                cornerSize: CGSize(width:2, height:2))
            let superColor: Color = superMeter >= 1.0 ? Color.yellow : Color(red:0.8, green:0.4, blue:1.0)
            ctx.fill(fill, with:.linearGradient(
                Gradient(colors:[superColor.opacity(0.9), superColor.opacity(0.6)]),
                startPoint: CGPoint(x:barX, y:barY),
                endPoint: CGPoint(x:barX+barW, y:barY)))

            if superMeter >= 1.0 {
                let pulse = 0.5 + 0.5*sin(t * 5.0)
                var glowCtx = ctx
                glowCtx.addFilter(.shadow(color:Color.yellow.opacity(0.7*pulse), radius:6))
                glowCtx.fill(fill, with:.color(Color.yellow.opacity(0.2)))
            }
        }

        var superLblCtx = ctx
        superLblCtx.opacity = superMeter >= 1.0 ? 1.0 : 0.45
        let labelColor: Color = superMeter >= 1.0 ? Color.yellow : Color.white
        superLblCtx.draw(Text("SUPER").font(.system(size:5.5, weight:.black, design:.monospaced)).foregroundColor(labelColor),
                         at: CGPoint(x:W/2, y:barY + barH + 5), anchor:.center)
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

private enum KaratePhase { case ready, roundAnnounce, fight, roundEnd, result }
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

// MARK: - Super Meter View

private struct SuperMeterView: View {
    let value: CGFloat  // 0→1
    private var isFull: Bool { value >= 1.0 }

    var body: some View {
        HStack(spacing:6) {
            Image(systemName:"bolt.fill").font(.system(size:10,weight:.bold))
                .foregroundStyle(isFull ? .yellow : Color(red:0.8,green:0.4,blue:1.0).opacity(0.8))
            Text("SUPER").font(.system(size:9,weight:.black,design:.monospaced))
                .foregroundStyle(isFull ? .yellow : .secondary).tracking(2)
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    RoundedRectangle(cornerRadius:3).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius:3)
                        .fill(LinearGradient(
                            colors: isFull ? [.yellow,.orange] : [Color(red:0.8,green:0.4,blue:1.0), Color(red:0.5,green:0.2,blue:0.9)],
                            startPoint:.leading, endPoint:.trailing))
                        .frame(width:geo.size.width*value)
                        .animation(.spring(response:0.3,dampingFraction:0.8),value:value)
                }
            }.frame(height:6).clipShape(RoundedRectangle(cornerRadius:3))
            if isFull {
                Text("READY").font(.system(size:9,weight:.black,design:.monospaced))
                    .foregroundStyle(.yellow).tracking(1)
            } else {
                Text("\(Int(value*100))%").font(.system(size:9,weight:.black,design:.monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Round Indicator Row

private struct RoundIndicatorRow: View {
    let playerWins: Int
    let aiWins: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing:0) {
            HStack(spacing:5) {
                ForEach(0..<3, id:\.self) { i in
                    Circle()
                        .fill(i < playerWins ? Theme.brandBlue : Color.white.opacity(0.15))
                        .frame(width:8, height:8)
                        .overlay(Circle().stroke(Theme.brandBlue.opacity(0.5), lineWidth:1))
                }
            }
            Spacer()
            Text("ROUNDS").font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.secondary).tracking(2)
            Spacer()
            HStack(spacing:5) {
                ForEach(0..<3, id:\.self) { i in
                    Circle()
                        .fill(i < aiWins ? accentColor : Color.white.opacity(0.15))
                        .frame(width:8, height:8)
                        .overlay(Circle().stroke(accentColor.opacity(0.5), lineWidth:1))
                }
            }
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
    @State private var gameTimerTask: Task<Void, Never>?

    // Round structure
    @State private var currentRound: Int = 1
    @State private var playerRoundsWon: Int = 0
    @State private var aiRoundsWon: Int = 0
    @State private var roundTimeRemaining: Double = 30.0
    @State private var roundActive: Bool = false
    @State private var showRoundAnnounce: Bool = false
    @State private var roundAnnounceText: String = ""
    @State private var superMeter: CGFloat = 0     // 0→1, carries between rounds
    @State private var superHoldTask: Task<Void, Never>?

    // Momentum buffs
    @State private var playerDamageBuff: Double = 1.0
    @State private var isDominant: Bool = false

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
                GetReadyScreen(title:"Karate · 1v1", subtitle:"Best of 3 Rounds · 30s Each · Beat the Opponent",
                               countdown:3, accentColor:accentColor, onComplete:{ startRound() })
            case .roundAnnounce:
                roundAnnounceOverlay
            case .fight:
                fightBody.offset(x:screenShake)
            case .roundEnd:
                roundEndOverlay
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

    // MARK: - Round Announce Overlay

    private var roundAnnounceOverlay: some View {
        ZStack {
            Color(red:0.06,green:0.01,blue:0.01).ignoresSafeArea()
            VStack(spacing:16) {
                Text(roundAnnounceText)
                    .font(.system(size:48, weight:.black, design:.monospaced)).italic()
                    .foregroundStyle(accentColor)
                    .shadow(color:accentColor.opacity(0.7), radius:20)
                if isDominant {
                    Text("DOMINANT +10% DMG")
                        .font(.system(size:13, weight:.black, design:.monospaced))
                        .foregroundStyle(.yellow).tracking(2)
                } else if playerDamageBuff > 1.0 {
                    Text("MOMENTUM +5% DMG")
                        .font(.system(size:13, weight:.black, design:.monospaced))
                        .foregroundStyle(Theme.foundationGreen).tracking(2)
                }
                RoundIndicatorRow(playerWins:playerRoundsWon, aiWins:aiRoundsWon, accentColor:accentColor)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Round End Overlay

    private var roundEndOverlay: some View {
        ZStack {
            Color(red:0.06,green:0.01,blue:0.01).ignoresSafeArea()
            VStack(spacing:16) {
                Text(roundAnnounceText)
                    .font(.system(size:36, weight:.black, design:.monospaced)).italic()
                    .foregroundStyle(accentColor)
                    .shadow(color:accentColor.opacity(0.7), radius:16)
                RoundIndicatorRow(playerWins:playerRoundsWon, aiWins:aiRoundsWon, accentColor:accentColor)
                    .padding(.horizontal, 40)
                Text("Round \(currentRound) of 3")
                    .font(.system(size:12, weight:.black, design:.monospaced))
                    .foregroundStyle(.secondary).tracking(2)
            }
        }
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
        VStack(spacing:8) {
            RoundIndicatorRow(playerWins:playerRoundsWon, aiWins:aiRoundsWon, accentColor:accentColor)
            HStack(spacing:12) {
                KarateHealthBar(current:playerHP,max:maxHP,color:Theme.brandBlue,label:"YOU",isReversed:false).frame(maxWidth:.infinity)
                ZStack {
                    Circle().stroke(roundTimeRemaining <= 8 ? Color.red.opacity(0.5) : accentColor.opacity(0.3),lineWidth:2).frame(width:48,height:48)
                    Circle()
                        .trim(from: 0, to: CGFloat(roundTimeRemaining / 30.0))
                        .stroke(roundTimeRemaining <= 8 ? Color.red : accentColor,
                                style: StrokeStyle(lineWidth:2, lineCap:.round))
                        .frame(width:48,height:48).rotationEffect(.degrees(-90))
                        .animation(.linear(duration:0.1), value:roundTimeRemaining)
                    VStack(spacing:0) {
                        Text("\(Int(roundTimeRemaining))").font(.system(size:14,weight:.black,design:.monospaced))
                            .foregroundStyle(roundTimeRemaining <= 8 ? .red : .white)
                        Text("R\(currentRound)").font(.system(size:8,weight:.black,design:.monospaced))
                            .foregroundStyle(.secondary)
                    }
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
            SuperMeterView(value:superMeter)
            ChakraMeter(value:chakra, accentColor:accentColor)
                .onChange(of:chakra) { _,v in showDragonStrikeButton = v >= 100 }
            if isDominant {
                Text("⚡ DOMINANT — +10% DAMAGE").font(.system(size:9,weight:.black,design:.monospaced))
                    .foregroundStyle(.yellow).tracking(1)
            } else if playerDamageBuff > 1.0 {
                Text("↑ MOMENTUM — +5% DAMAGE").font(.system(size:9,weight:.black,design:.monospaced))
                    .foregroundStyle(Theme.foundationGreen).tracking(1)
            }
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
                       roundNumber:currentRound,
                       playerRoundsWon:playerRoundsWon,
                       aiRoundsWon:aiRoundsWon,
                       superMeter:superMeter,
                       roundTimeRemaining:roundTimeRemaining)

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

            if superMeter >= 1.0 {
                VStack { Spacer()
                    Text("▶ HOLD FOR SUPER STRIKE")
                        .font(.system(size:10, weight:.black, design:.monospaced))
                        .foregroundStyle(.yellow).tracking(2)
                        .shadow(color:.yellow.opacity(0.7), radius:8)
                        .padding(.bottom, showDragonStrikeButton ? 60 : 16)
                }
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
        .onLongPressGesture(minimumDuration:0.5) { handleSuperRelease() }
    }

    // MARK: - Controls Hint

    private var controlsHint: some View {
        HStack(spacing:0) {
            controlHint(icon:"hand.tap.fill",label:"← PUNCH",color:Theme.brandBlue)
            Spacer()
            controlHint(icon:"arrow.up",label:"↑ BLOCK",color:Theme.foundationGreen)
            Spacer()
            controlHint(icon:"bolt.fill",label:"HOLD·SUPER",color:.yellow)
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

    // MARK: - Round Flow

    private func startRound() {
        playerHP = maxHP
        opponentHP = maxHP
        roundTimeRemaining = 30.0
        combo = 0; comboCount = 0
        chakra = 0; showDragonStrikeButton = false

        roundAnnounceText = "ROUND \(currentRound)"
        phase = .roundAnnounce

        Task {
            try? await Task.sleep(for:.milliseconds(1200))
            await MainActor.run { roundAnnounceText = "FIGHT!" }
            try? await Task.sleep(for:.milliseconds(800))
            await MainActor.run {
                phase = .fight
                roundActive = true
                withAnimation(.spring(response:0.3,dampingFraction:0.5)) { showFightFlash = true }
            }
            try? await Task.sleep(for:.milliseconds(1200))
            await MainActor.run { withAnimation { showFightFlash = false } }
            startRoundTimer()
            scheduleAIAttack()
        }
    }

    private func startRoundTimer() {
        gameTimerTask?.cancel()
        gameTimerTask = Task {
            let tick: Double = 0.1
            while roundTimeRemaining > 0 {
                try? await Task.sleep(for:.milliseconds(100))
                guard !Task.isCancelled else { return }
                await MainActor.run { roundTimeRemaining = max(0, roundTimeRemaining - tick) }
            }
            await MainActor.run {
                guard roundActive else { return }
                endRound(ko: false, playerKO: false)
            }
        }
    }

    private func endRound(ko: Bool, playerKO: Bool) {
        guard roundActive else { return }
        roundActive = false
        gameTimerTask?.cancel()
        aiAttackTask?.cancel()

        let playerWon: Bool
        if ko { playerWon = !playerKO } else { playerWon = playerHP > opponentHP }
        let isDraw = !ko && playerHP == opponentHP

        if playerWon {
            playerRoundsWon += 1
            roundAnnounceText = ko ? "KO! YOU WIN ROUND \(currentRound)" : "ROUND \(currentRound) — YOU WIN!"
            showAction(text: ko ? "KO!" : "ROUND WIN!", color: Theme.brandBlue)
        } else if isDraw {
            roundAnnounceText = "ROUND \(currentRound) — DRAW"
            showAction(text:"DRAW",color:.white)
        } else {
            aiRoundsWon += 1
            roundAnnounceText = playerKO ? "KO! OPPONENT WINS ROUND \(currentRound)" : "ROUND \(currentRound) — OPPONENT WINS"
            showAction(text: playerKO ? "KO!" : "ROUND LOST", color: accentColor)
        }

        updateMomentumBuff()
        phase = .roundEnd

        Task {
            try? await Task.sleep(for:.milliseconds(2000))
            await MainActor.run { advanceAfterRound() }
        }
    }

    private func updateMomentumBuff() {
        if playerRoundsWon == 1 && aiRoundsWon == 0 {
            playerDamageBuff = 1.05; isDominant = false
        }
        if playerRoundsWon >= 2 && aiRoundsWon == 0 {
            playerDamageBuff = 1.10; isDominant = true
        }
        if aiRoundsWon >= playerRoundsWon {
            playerDamageBuff = 1.0; isDominant = false
        }
    }

    private func advanceAfterRound() {
        if playerRoundsWon >= 2 || aiRoundsWon >= 2 || currentRound >= 3 {
            endMatch()
        } else {
            currentRound += 1
            startRound()
        }
    }

    private func endMatch() {
        cancelAllTasks()
        outcome = playerRoundsWon > aiRoundsWon ? .win : (playerRoundsWon == aiRoundsWon ? .draw : .loss)
        awardShards()
        Task {
            try? await Task.sleep(for:.seconds(0.5))
            await MainActor.run { withAnimation { phase = .result } }
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
        guard phase == .fight, roundActive else { return }
        let dmg = Double.random(in:8...18)
        playerHP = max(0,playerHP-dmg)
        opponentScore += 1
        setPose("hit", for: "player", duration: 0.4)
        setPose("punch", for: "opponent", duration: 0.35)
        flashScreenShake()
        impactMed.impactOccurred()
        if playerHP <= 0 { endRound(ko:true,playerKO:true) }
    }

    // MARK: - Player Actions

    private func handlePunch() {
        guard phase == .fight, roundActive else { return }
        let now = Date(); let isCrit = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now
        let baseDmg: Double = (isCrit ? 12 : 8) + Double(combo)*1.5
        let dmg = baseDmg * playerDamageBuff
        opponentHP = max(0,opponentHP-dmg)
        playerScore += isCrit ? 2 : 1; combo += 1; maxCombo = max(maxCombo,combo)
        comboCount = combo
        superMeter = min(1.0, superMeter + 0.15)
        chakra = min(100,chakra+(isCrit ? 15 : 8))
        showAction(text:isCrit ? "CRITICAL PUNCH!" : "PUNCH", color:Theme.brandBlue)
        setPose("punch", for:"player", duration:0.35)
        setPose("hit", for:"opponent", duration:0.35)
        lastHitTime = Date().timeIntervalSinceReferenceDate; lastHitType = "punch"
        if isCrit { triggerCritFlash() }
        flashScreenShake()
        impactMed.impactOccurred()
        if opponentHP <= 0 { endRound(ko:true,playerKO:false) }
    }

    private func handleKick() {
        guard phase == .fight, roundActive else { return }
        let now = Date(); let isCrit = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now
        let baseDmg: Double = (isCrit ? 18 : 12) + Double(combo)*2.0
        let dmg = baseDmg * playerDamageBuff
        opponentHP = max(0,opponentHP-dmg)
        playerScore += isCrit ? 3 : 2; combo += 1; maxCombo = max(maxCombo,combo)
        comboCount = combo
        superMeter = min(1.0, superMeter + 0.15)
        chakra = min(100,chakra+(isCrit ? 20 : 12))
        showAction(text:isCrit ? "CRITICAL KICK!" : "KICK", color:accentColor)
        setPose("kick", for:"player", duration:0.40)
        setPose("hit", for:"opponent", duration:0.40)
        lastHitTime = Date().timeIntervalSinceReferenceDate; lastHitType = "kick"
        if isCrit { triggerCritFlash() }
        flashScreenShake()
        impactHvy.impactOccurred()
        if opponentHP <= 0 { endRound(ko:true,playerKO:false) }
    }

    private func handleBlock() {
        guard phase == .fight, roundActive else { return }
        combo = 0; comboCount = 0; playerHP = min(maxHP,playerHP+5)
        showAction(text:"BLOCK", color:Theme.foundationGreen)
        setPose("block", for:"player", duration:0.5)
        impactMed.impactOccurred()
    }

    private func handleSuperRelease() {
        guard phase == .fight, roundActive, superMeter >= 1.0 else { return }
        superMeter = 0
        let baseDmg: Double = (35 + Double(combo)*3.0) * playerDamageBuff
        opponentHP = max(0, opponentHP - baseDmg)
        playerScore += 8; combo += 2; maxCombo = max(maxCombo, combo); comboCount = combo
        chakra = min(100, chakra + 20)
        showAction(text:"SUPER STRIKE!", color:.yellow)
        setPose("dragon", for:"player", duration:0.7)
        setPose("hit", for:"opponent", duration:0.6)
        lastHitTime = Date().timeIntervalSinceReferenceDate; lastHitType = "dragon"
        triggerCritFlash(); flashScreenShake()
        notif.notificationOccurred(.success)
        if opponentHP <= 0 { endRound(ko:true,playerKO:false) }
    }

    private func triggerDragonStrike() {
        guard phase == .fight, chakra >= 100, roundActive else { return }
        chakra = 0; showDragonStrikeButton = false
        let baseDmg: Double = 45 * playerDamageBuff
        opponentHP = max(0,opponentHP-baseDmg)
        playerScore += 10; combo += 3; maxCombo = max(maxCombo,combo); comboCount = combo
        showAction(text:"DRAGON STRIKE!", color:.yellow)
        setPose("dragon", for:"player", duration:0.8)
        setPose("hit", for:"opponent", duration:0.6)
        lastHitTime = Date().timeIntervalSinceReferenceDate; lastHitType = "dragon"
        triggerCritFlash(); flashScreenShake()
        notif.notificationOccurred(.success)
        if opponentHP <= 0 { endRound(ko:true,playerKO:false) }
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

    // MARK: - Award Shards

    private func awardShards() {
        guard !shardsAwarded else { return }
        shardsAwarded = true
        GameResultService.saveResult(modeId: "karate", userScore: playerScore, opponentScore: opponentScore)
        viewModel.profile.evolutionShards += outcome == .win ? 50 : outcome == .draw ? 25 : 15
        SaveSystem.saveProfile(viewModel.profile)
    }

    private func cancelAllTasks() {
        gameTimerTask?.cancel(); aiAttackTask?.cancel()
        actionLabelTask?.cancel(); critFlashTask?.cancel()
        poseResetTask?.cancel(); superHoldTask?.cancel()
    }
}
