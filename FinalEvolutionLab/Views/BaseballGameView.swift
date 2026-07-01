import SwiftUI
import UIKit

// MARK: - Enums

private enum BBallPhase {
    case ready, batting, fielding, pitching, inningBreak, result
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
    let swingResult: SwingResult
    let playerScore: Int
    let aiScore: Int
    let inning: Int
    let outs: Int

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
                    aiBatterPhase: aiBatterPhase,
                    swingResult: swingResult,
                    playerScore: playerScore,
                    aiScore: aiScore,
                    inning: inning,
                    outs: outs
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
    let swingResult: SwingResult
    let playerScore: Int
    let aiScore: Int
    let inning: Int
    let outs: Int

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var floorY: CGFloat { H * 0.70 }
    var batterX: CGFloat { W * 0.73 }
    var pitcherX: CGFloat { W * 0.27 }
    var moundY: CGFloat { floorY - 5 }

    mutating func render(ctx: inout GraphicsContext) {
        // --- Scene layer 1: Ballpark background ---
        drawSkyGradient(ctx: &ctx)
        drawStars(ctx: &ctx)
        drawLightPoles(ctx: &ctx)
        drawOutfieldWall(ctx: &ctx)
        drawWarningTrack(ctx: &ctx)
        drawOutfieldGrass(ctx: &ctx)
        // --- Scene layer 2: Diamond ---
        drawInfieldDirt(ctx: &ctx)
        drawDiamondGeometry(ctx: &ctx)
        // --- Scene layer 3: Stadium furniture ---
        drawStands(ctx: &ctx)
        drawScoreboard(ctx: &ctx)
        drawPressBox(ctx: &ctx)
        drawDugoutOverhangs(ctx: &ctx)
        drawBullpenArea(ctx: &ctx)
        // --- Scene layer 4: Players ---
        if isAIBatting {
            drawAIPitchingScene(ctx: &ctx)
        } else {
            drawFielders(ctx: &ctx)
            drawCatcher(ctx: &ctx)
            drawUmpire(ctx: &ctx)
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
        // --- Scene layer 5: Hit FX ---
        if hitType == "homeRun" && hitProgress >= 0 {
            drawHomeRunFireworks(ctx: &ctx)
        }
        if swingResult == .miss || (batterPhase == "miss") {
            drawStrikeoutVignette(ctx: &ctx)
        }
    }

    // MARK: - BALLPARK BG (#1–#12)

    private func drawSkyGradient(ctx: inout GraphicsContext) {
        // #1 Night sky gradient fill
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.14),
                    Color(red: 0.05, green: 0.09, blue: 0.28),
                    Color(red: 0.08, green: 0.14, blue: 0.38)
                ]),
                startPoint: CGPoint(x: W * 0.5, y: 0),
                endPoint: CGPoint(x: W * 0.5, y: H * 0.42)
            )
        )
        // #2 Sky atmosphere glow near horizon
        var gc2 = ctx; gc2.addFilter(.blur(radius: 40)); gc2.opacity = 0.18
        gc2.fill(
            Path(CGRect(x: 0, y: H * 0.20, width: W, height: H * 0.22)),
            with: .linearGradient(
                Gradient(colors: [.clear, Color(red: 0.20, green: 0.45, blue: 0.90), .clear]),
                startPoint: CGPoint(x: 0, y: H * 0.20),
                endPoint: CGPoint(x: 0, y: H * 0.42)
            )
        )
    }

    private func drawStars(ctx: inout GraphicsContext) {
        // #3 Star field (20 twinkling dots)
        for i in 0..<20 {
            let sx = W * CGFloat((i * 131 + 41) % 97) / 97.0
            let sy = H * 0.01 + H * 0.20 * CGFloat((i * 83 + 19) % 100) / 100.0
            let tw = 0.4 + 0.35 * sin(t * 1.6 + Double(i) * 0.8)
            var gc = ctx; gc.opacity = tw
            gc.fill(Path(ellipseIn: CGRect(x: sx - 1, y: sy - 1, width: 2, height: 2)), with: .color(.white))
        }
        // #4 Bright hero star near center
        let heroX = W * 0.52; let heroY = H * 0.04
        let heroPulse = 0.6 + 0.4 * sin(t * 2.2)
        var gc4 = ctx; gc4.addFilter(.blur(radius: 3)); gc4.opacity = heroPulse * 0.7
        gc4.fill(Path(ellipseIn: CGRect(x: heroX - 4, y: heroY - 4, width: 8, height: 8)), with: .color(.white))
        var gc4b = ctx; gc4b.opacity = heroPulse
        gc4b.fill(Path(ellipseIn: CGRect(x: heroX - 1.5, y: heroY - 1.5, width: 3, height: 3)), with: .color(.white))
    }

    private func drawLightPoles(ctx: inout GraphicsContext) {
        // #5 Light pole glow halos
        for poleX in [W * 0.04, W * 0.30, W * 0.70, W * 0.96] as [CGFloat] {
            var gc = ctx; gc.addFilter(.blur(radius: 22)); gc.opacity = 0.28
            gc.fill(Path(ellipseIn: CGRect(x: poleX - 44, y: -14, width: 88, height: 55)), with: .color(.white))
        }
        // #6 Light pole shafts
        for poleX in [W * 0.04, W * 0.30, W * 0.70, W * 0.96] as [CGFloat] {
            var pole = Path()
            pole.move(to: CGPoint(x: poleX, y: H * 0.28))
            pole.addLine(to: CGPoint(x: poleX, y: H * 0.08))
            ctx.stroke(pole, with: .color(Color(white: 0.55)), lineWidth: 2)
            ctx.fill(Path(CGRect(x: poleX - 10, y: H * 0.07, width: 20, height: 5)), with: .color(Color(white: 0.90)))
            var lGlow = ctx; lGlow.addFilter(.blur(radius: 6)); lGlow.opacity = 0.7
            lGlow.fill(Path(ellipseIn: CGRect(x: poleX - 8, y: H * 0.07, width: 16, height: 6)), with: .color(.white))
        }
        // #7 Field illumination cone from poles
        for poleX in [W * 0.04, W * 0.96] as [CGFloat] {
            var gc7 = ctx; gc7.addFilter(.blur(radius: 30)); gc7.opacity = 0.06
            var cone = Path()
            cone.move(to: CGPoint(x: poleX, y: H * 0.10))
            cone.addLine(to: CGPoint(x: poleX + (poleX < W * 0.5 ? W * 0.45 : -W * 0.45), y: H * 0.72))
            cone.addLine(to: CGPoint(x: poleX + (poleX < W * 0.5 ? W * 0.05 : -W * 0.05), y: H * 0.72))
            cone.closeSubpath()
            gc7.fill(cone, with: .color(.white))
        }
    }

    private func drawOutfieldWall(ctx: inout GraphicsContext) {
        // #8 Outfield wall green base (ivy-covered)
        var wall = Path()
        wall.move(to: CGPoint(x: 0, y: H * 0.32))
        wall.addLine(to: CGPoint(x: W, y: H * 0.32))
        wall.addLine(to: CGPoint(x: W, y: H * 0.32 + 16))
        wall.addLine(to: CGPoint(x: 0, y: H * 0.32 + 16))
        wall.closeSubpath()
        ctx.fill(wall, with: .color(Color(red: 0.08, green: 0.36, blue: 0.10)))
        ctx.stroke(wall, with: .color(Color(red: 0.20, green: 0.55, blue: 0.22)), lineWidth: 1)
        // #9 Advertisement panels on wall
        let adColors: [Color] = [
            Color(red: 0.85, green: 0.15, blue: 0.10),
            Color(red: 0.90, green: 0.72, blue: 0.06),
            Color(red: 0.10, green: 0.30, blue: 0.80)
        ]
        let adWidths: [CGFloat] = [W * 0.18, W * 0.20, W * 0.15]
        var adX: CGFloat = W * 0.05
        for (idx, adW) in adWidths.enumerated() {
            ctx.fill(
                Path(CGRect(x: adX, y: H * 0.32 + 2, width: adW, height: 12)),
                with: .color(adColors[idx % adColors.count].opacity(0.55))
            )
            adX += adW + W * 0.05
        }
        // #10 Distance marker text
        let distText = ctx.resolve(Text("380 FT")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.45)))
        ctx.draw(distText, at: CGPoint(x: W * 0.14, y: H * 0.32 + 8))
        let distText2 = ctx.resolve(Text("410 FT")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.45)))
        ctx.draw(distText2, at: CGPoint(x: W * 0.50, y: H * 0.32 + 8))
    }

    private func drawWarningTrack(ctx: inout GraphicsContext) {
        // #11 Warning track (brown strip near wall)
        ctx.fill(
            Path(CGRect(x: 0, y: H * 0.348, width: W, height: H * 0.025)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.52, green: 0.38, blue: 0.22),
                    Color(red: 0.44, green: 0.30, blue: 0.16)
                ]),
                startPoint: CGPoint(x: 0, y: H * 0.348),
                endPoint: CGPoint(x: 0, y: H * 0.373)
            )
        )
        // #12 Warning track texture lines
        for i in stride(from: 0, through: Int(W), by: 12) {
            var gc12 = ctx; gc12.opacity = 0.12
            var tl = Path()
            tl.move(to: CGPoint(x: CGFloat(i), y: H * 0.348))
            tl.addLine(to: CGPoint(x: CGFloat(i), y: H * 0.373))
            gc12.stroke(tl, with: .color(.black), lineWidth: 0.5)
        }
    }

    private func drawOutfieldGrass(ctx: inout GraphicsContext) {
        // #13 Outfield grass main fill (left sector)
        ctx.fill(
            Path(CGRect(x: 0, y: H * 0.373, width: W * 0.56, height: H - H * 0.373)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.09, green: 0.30, blue: 0.09), Color(red: 0.06, green: 0.20, blue: 0.06)]),
                startPoint: CGPoint(x: 0, y: H * 0.373), endPoint: CGPoint(x: 0, y: H)
            )
        )
        // #14 Mow stripe pattern (alternating lighter/darker bands)
        for s in 0..<7 {
            if s % 2 == 0 {
                ctx.fill(
                    Path(CGRect(x: CGFloat(s) * W * 0.08, y: H * 0.373, width: W * 0.08, height: H - H * 0.373)),
                    with: .color(Color(white: 1).opacity(0.022))
                )
            }
        }
        // #15 Outfield grass right sector
        ctx.fill(
            Path(CGRect(x: W * 0.56, y: H * 0.36, width: W * 0.44, height: H - H * 0.36)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.08, green: 0.26, blue: 0.08), Color(red: 0.05, green: 0.18, blue: 0.05)]),
                startPoint: CGPoint(x: W * 0.56, y: H * 0.36), endPoint: CGPoint(x: W * 0.56, y: H)
            )
        )
    }

    // MARK: - DIAMOND (#13 cont. → #24)

    private func drawInfieldDirt(ctx: inout GraphicsContext) {
        // #16 Infield dirt oval
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
        // #17 Pitcher's mound circle
        ctx.fill(
            Path(ellipseIn: CGRect(x: pitcherX - 22, y: moundY - 5, width: 44, height: 10)),
            with: .color(Color(red: 0.48, green: 0.34, blue: 0.18))
        )
        // #18 Pitcher's rubber (white rectangle on mound)
        ctx.fill(
            Path(CGRect(x: pitcherX - 9, y: moundY - 2.5, width: 18, height: 5)),
            with: .color(.white.opacity(0.85))
        )
    }

    private func drawDiamondGeometry(ctx: inout GraphicsContext) {
        // #19 Home plate pentagon
        var plate = Path()
        plate.move(to: CGPoint(x: batterX - 13, y: floorY - 2))
        plate.addLine(to: CGPoint(x: batterX + 13, y: floorY - 2))
        plate.addLine(to: CGPoint(x: batterX + 13, y: floorY + 5))
        plate.addLine(to: CGPoint(x: batterX, y: floorY + 9))
        plate.addLine(to: CGPoint(x: batterX - 13, y: floorY + 5))
        plate.closeSubpath()
        ctx.fill(plate, with: .color(.white.opacity(0.90)))

        // #20 Three base squares (1st, 2nd, 3rd)
        let basePositions: [(CGFloat, CGFloat)] = [
            (W * 0.90, floorY - 6),
            (W * 0.46, H * 0.47),
            (batterX - 42, floorY - 9)
        ]
        for (bx, by) in basePositions {
            ctx.fill(Path(CGRect(x: bx - 6, y: by - 5, width: 12, height: 9)), with: .color(.white.opacity(0.80)))
        }

        // #21 Batter's box rectangles (left and right)
        var bbLeft = Path()
        bbLeft.addRect(CGRect(x: batterX - 32, y: floorY - 44, width: 22, height: 40))
        var bbRight = Path()
        bbRight.addRect(CGRect(x: batterX + 10, y: floorY - 44, width: 22, height: 40))
        ctx.stroke(bbLeft, with: .color(.white.opacity(0.28)), lineWidth: 1)
        ctx.stroke(bbRight, with: .color(.white.opacity(0.28)), lineWidth: 1)

        // #22 Catcher's box
        var catcherBox = Path()
        catcherBox.addRect(CGRect(x: batterX - 18, y: floorY + 8, width: 36, height: 24))
        ctx.stroke(catcherBox, with: .color(.white.opacity(0.20)), lineWidth: 1)

        // #23 Chalk foul lines to corners
        var fl = Path()
        fl.move(to: CGPoint(x: batterX, y: floorY))
        fl.addLine(to: CGPoint(x: W * 0.02, y: H * 0.34))
        fl.move(to: CGPoint(x: batterX, y: floorY))
        fl.addLine(to: CGPoint(x: W * 0.98, y: H * 0.36))
        ctx.stroke(fl, with: .color(.white.opacity(0.22)), lineWidth: 1.5)

        // #24 Base coach boxes (first and third)
        var coachBox1 = Path()
        coachBox1.addRect(CGRect(x: W * 0.84, y: floorY - 5, width: 14, height: 14))
        var coachBox3 = Path()
        coachBox3.addRect(CGRect(x: batterX - 60, y: floorY - 12, width: 14, height: 14))
        ctx.stroke(coachBox1, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
        ctx.stroke(coachBox3, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
    }

    // MARK: - STADIUM (#25–#36)

    private func drawStands(ctx: inout GraphicsContext) {
        let standTop: CGFloat = H * 0.09
        let standBot: CGFloat = H * 0.30

        // #25 Stadium tier rows background
        for tier in 0..<5 {
            let ty = standTop + CGFloat(tier) * (standBot - standTop) / 5
            let h = (standBot - standTop) / 5 - 1
            ctx.fill(Path(CGRect(x: 0, y: ty, width: W, height: h)),
                     with: .color(Color(white: 0.07 + 0.015 * Double(tier))))
        }

        // #26 Crowd heads and jerseys (3 rows, 20+ per row)
        let jerseys: [Color] = [
            Color(red: 0.14, green: 0.32, blue: 0.72),
            Color(red: 0.72, green: 0.12, blue: 0.12),
            Color(red: 0.94, green: 0.84, blue: 0.18),
            Color(red: 0.82, green: 0.38, blue: 0.04),
            Color(red: 0.18, green: 0.62, blue: 0.22),
            Color(white: 0.88),
        ]
        let cols = 22
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

        // #27 Stadium railing / fascia at bottom of stands
        ctx.fill(Path(CGRect(x: 0, y: standBot, width: W, height: 7)), with: .color(Color(white: 0.04)))

        // #28 Upper deck overhang shadow
        var gc28 = ctx; gc28.addFilter(.blur(radius: 8)); gc28.opacity = 0.35
        gc28.fill(Path(CGRect(x: 0, y: standBot - 4, width: W, height: 10)), with: .color(.black))
    }

    private func drawScoreboard(ctx: inout GraphicsContext) {
        // #29 Scoreboard background panel (top-center)
        let sbX = W * 0.36; let sbY = H * 0.09; let sbW = W * 0.28; let sbH = H * 0.095
        ctx.fill(
            Path(CGRect(x: sbX, y: sbY, width: sbW, height: sbH)),
            with: .color(Color(white: 0.06))
        )
        // #30 Scoreboard border
        var sbBorder = Path()
        sbBorder.addRect(CGRect(x: sbX, y: sbY, width: sbW, height: sbH))
        ctx.stroke(sbBorder, with: .color(Color(red: 0.90, green: 0.72, blue: 0.06).opacity(0.55)), lineWidth: 1.5)

        // #31 Scoreboard inning text
        let innText = ctx.resolve(Text("INN \(inning)")
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.55)))
        ctx.draw(innText, at: CGPoint(x: sbX + sbW * 0.5, y: sbY + sbH * 0.22))

        // #32 Scoreboard score display
        let scoreText = ctx.resolve(Text("\(playerScore)  –  \(aiScore)")
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .foregroundStyle(Color.white))
        ctx.draw(scoreText, at: CGPoint(x: sbX + sbW * 0.5, y: sbY + sbH * 0.57))

        // #33 Scoreboard out indicators
        let outsText = ctx.resolve(Text("OUT \(outs)/3")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.red.opacity(0.75)))
        ctx.draw(outsText, at: CGPoint(x: sbX + sbW * 0.5, y: sbY + sbH * 0.84))
    }

    private func drawPressBox(ctx: inout GraphicsContext) {
        // #34 Press box windows (upper tier center)
        let pbY = H * 0.095
        let pbX = W * 0.40
        let pbW = W * 0.20
        ctx.fill(Path(CGRect(x: pbX, y: pbY - 16, width: pbW, height: 14)),
                 with: .color(Color(white: 0.08)))
        // Press box window panes
        for pane in 0..<5 {
            let px = pbX + 4 + CGFloat(pane) * (pbW - 8) / 5
            let glowA = 0.15 + 0.10 * sin(t * 0.8 + Double(pane) * 1.1)
            var gc34 = ctx; gc34.opacity = glowA
            gc34.fill(Path(CGRect(x: px, y: pbY - 14, width: (pbW - 8) / 5 - 2, height: 10)),
                      with: .color(Color(red: 0.85, green: 0.95, blue: 0.65)))
        }
    }

    private func drawDugoutOverhangs(ctx: inout GraphicsContext) {
        // #35 Dugout overhang silhouettes (both sides)
        var dugLeft = Path()
        dugLeft.move(to: CGPoint(x: 0, y: floorY - 8))
        dugLeft.addLine(to: CGPoint(x: W * 0.12, y: floorY - 8))
        dugLeft.addLine(to: CGPoint(x: W * 0.12, y: floorY + 4))
        dugLeft.addLine(to: CGPoint(x: 0, y: floorY + 4))
        dugLeft.closeSubpath()
        ctx.fill(dugLeft, with: .color(Color(white: 0.05).opacity(0.80)))

        var dugRight = Path()
        dugRight.move(to: CGPoint(x: W, y: floorY - 8))
        dugRight.addLine(to: CGPoint(x: W * 0.88, y: floorY - 8))
        dugRight.addLine(to: CGPoint(x: W * 0.88, y: floorY + 4))
        dugRight.addLine(to: CGPoint(x: W, y: floorY + 4))
        dugRight.closeSubpath()
        ctx.fill(dugRight, with: .color(Color(white: 0.05).opacity(0.80)))

        // Dugout step outlines
        ctx.stroke(
            Path(CGRect(x: 0, y: floorY - 8, width: W * 0.12, height: 12)),
            with: .color(Color(white: 0.20).opacity(0.40)),
            lineWidth: 0.8
        )
        ctx.stroke(
            Path(CGRect(x: W * 0.88, y: floorY - 8, width: W * 0.12, height: 12)),
            with: .color(Color(white: 0.20).opacity(0.40)),
            lineWidth: 0.8
        )
    }

    private func drawBullpenArea(ctx: inout GraphicsContext) {
        // #36 Bullpen area (right field corner)
        var bp = Path()
        bp.addRect(CGRect(x: W * 0.80, y: H * 0.37, width: W * 0.18, height: H * 0.06))
        var gc36 = ctx; gc36.opacity = 0.45
        gc36.fill(bp, with: .color(Color(red: 0.42, green: 0.30, blue: 0.18)))
        ctx.stroke(bp, with: .color(Color(white: 0.25).opacity(0.40)), lineWidth: 0.8)
        let bpText = ctx.resolve(Text("BULLPEN")
            .font(.system(size: 5, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.25)))
        ctx.draw(bpText, at: CGPoint(x: W * 0.89, y: H * 0.40))
    }

    // MARK: - PLAYER FIGURES (#37–#58)

    private func drawFielders(ctx: inout GraphicsContext) {
        // #37 Left fielder silhouette
        let lfX = W * 0.14; let lfY = H * 0.44
        let fieldSkin = Color(red: 0.80, green: 0.63, blue: 0.48)
        let fieldColor = Color(red: 0.14, green: 0.32, blue: 0.72)
        ctx.fill(Path(ellipseIn: CGRect(x: lfX - 4, y: lfY - 22, width: 8, height: 8)), with: .color(fieldSkin.opacity(0.65)))
        var lfBody = Path()
        lfBody.move(to: CGPoint(x: lfX, y: lfY - 14))
        lfBody.addLine(to: CGPoint(x: lfX, y: lfY - 4))
        ctx.stroke(lfBody, with: .color(fieldColor.opacity(0.60)), lineWidth: 2)
        var lfLegs = Path()
        lfLegs.move(to: CGPoint(x: lfX, y: lfY - 4))
        lfLegs.addLine(to: CGPoint(x: lfX - 4, y: lfY + 2))
        lfLegs.move(to: CGPoint(x: lfX, y: lfY - 4))
        lfLegs.addLine(to: CGPoint(x: lfX + 4, y: lfY + 2))
        ctx.stroke(lfLegs, with: .color(fieldColor.opacity(0.60)), lineWidth: 2)

        // #38 Center fielder silhouette
        let cfX = W * 0.35; let cfY = H * 0.40
        ctx.fill(Path(ellipseIn: CGRect(x: cfX - 4, y: cfY - 22, width: 8, height: 8)), with: .color(fieldSkin.opacity(0.65)))
        var cfBody = Path()
        cfBody.move(to: CGPoint(x: cfX, y: cfY - 14))
        cfBody.addLine(to: CGPoint(x: cfX, y: cfY - 4))
        ctx.stroke(cfBody, with: .color(fieldColor.opacity(0.60)), lineWidth: 2)
        var cfLegs = Path()
        cfLegs.move(to: CGPoint(x: cfX, y: cfY - 4))
        cfLegs.addLine(to: CGPoint(x: cfX - 4, y: cfY + 2))
        cfLegs.move(to: CGPoint(x: cfX, y: cfY - 4))
        cfLegs.addLine(to: CGPoint(x: cfX + 4, y: cfY + 2))
        ctx.stroke(cfLegs, with: .color(fieldColor.opacity(0.60)), lineWidth: 2)

        // #39 Right fielder silhouette
        let rfX = W * 0.55; let rfY = H * 0.43
        ctx.fill(Path(ellipseIn: CGRect(x: rfX - 4, y: rfY - 22, width: 8, height: 8)), with: .color(fieldSkin.opacity(0.65)))
        var rfBody = Path()
        rfBody.move(to: CGPoint(x: rfX, y: rfY - 14))
        rfBody.addLine(to: CGPoint(x: rfX, y: rfY - 4))
        ctx.stroke(rfBody, with: .color(fieldColor.opacity(0.60)), lineWidth: 2)
        var rfLegs = Path()
        rfLegs.move(to: CGPoint(x: rfX, y: rfY - 4))
        rfLegs.addLine(to: CGPoint(x: rfX - 4, y: rfY + 2))
        rfLegs.move(to: CGPoint(x: rfX, y: rfY - 4))
        rfLegs.addLine(to: CGPoint(x: rfX + 4, y: rfY + 2))
        ctx.stroke(rfLegs, with: .color(fieldColor.opacity(0.60)), lineWidth: 2)
    }

    private func drawCatcher(ctx: inout GraphicsContext) {
        // #40 Catcher crouch behind plate
        let cx = batterX + 20; let cy = floorY - 4
        let catcherColor = Color(red: 0.14, green: 0.32, blue: 0.72)
        let catcherSkin = Color(red: 0.85, green: 0.68, blue: 0.52)
        // Head with catcher's mask
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: cy - 22, width: 10, height: 10)), with: .color(catcherSkin))
        var mask = Path()
        mask.addRect(CGRect(x: cx - 6, y: cy - 22, width: 12, height: 10))
        ctx.stroke(mask, with: .color(Color(white: 0.30).opacity(0.70)), lineWidth: 1)
        // Crouch body
        var cBody = Path()
        cBody.move(to: CGPoint(x: cx, y: cy - 12))
        cBody.addLine(to: CGPoint(x: cx, y: cy - 3))
        ctx.stroke(cBody, with: .color(catcherColor), lineWidth: 2.5)
        // Crouch legs (knees bent outward)
        var cLegs = Path()
        cLegs.move(to: CGPoint(x: cx, y: cy - 3))
        cLegs.addLine(to: CGPoint(x: cx - 8, y: cy + 5))
        cLegs.move(to: CGPoint(x: cx, y: cy - 3))
        cLegs.addLine(to: CGPoint(x: cx + 5, y: cy + 5))
        ctx.stroke(cLegs, with: .color(catcherColor), lineWidth: 2.5)
        // #41 Catcher mitt (glove)
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 16, y: cy - 12, width: 9, height: 9)), with: .color(Color(red: 0.55, green: 0.35, blue: 0.12)))
    }

    private func drawUmpire(ctx: inout GraphicsContext) {
        // #42 Umpire silhouette behind catcher
        let ux = batterX + 30; let uy = floorY - 6
        let umpColor = Color(white: 0.18)
        ctx.fill(Path(ellipseIn: CGRect(x: ux - 5, y: uy - 25, width: 10, height: 10)), with: .color(Color(white: 0.55)))
        var uBody = Path()
        uBody.move(to: CGPoint(x: ux, y: uy - 15))
        uBody.addLine(to: CGPoint(x: ux, y: uy - 4))
        ctx.stroke(uBody, with: .color(umpColor), lineWidth: 3.5)
        var uArms = Path()
        uArms.move(to: CGPoint(x: ux - 8, y: uy - 12))
        uArms.addLine(to: CGPoint(x: ux + 8, y: uy - 12))
        ctx.stroke(uArms, with: .color(umpColor), lineWidth: 2.5)
        var uLegs = Path()
        uLegs.move(to: CGPoint(x: ux, y: uy - 4))
        uLegs.addLine(to: CGPoint(x: ux - 6, y: uy + 4))
        uLegs.move(to: CGPoint(x: ux, y: uy - 4))
        uLegs.addLine(to: CGPoint(x: ux + 6, y: uy + 4))
        ctx.stroke(uLegs, with: .color(umpColor), lineWidth: 2.5)

        // #43 Ground shadows under players
        ctx.fill(Path(ellipseIn: CGRect(x: pitcherX - 16, y: floorY, width: 32, height: 5)), with: .color(.black.opacity(0.35)))
        ctx.fill(Path(ellipseIn: CGRect(x: batterX - 18, y: floorY, width: 36, height: 5)), with: .color(.black.opacity(0.35)))
        ctx.fill(Path(ellipseIn: CGRect(x: batterX + 14, y: floorY, width: 22, height: 4)), with: .color(.black.opacity(0.25)))
    }

    // MARK: Pitcher (#44–#51)

    private func drawPitcher(ctx: inout GraphicsContext) {
        let x = pitcherX; let y = moundY
        let color = Color(red: 0.14, green: 0.32, blue: 0.72)
        let skin = Color(red: 0.85, green: 0.68, blue: 0.52)
        let r: CGFloat = 7

        switch pitcherPhase {
        case "windup":
            // #44 Pitcher windup — head
            ctx.fill(Path(ellipseIn: CGRect(x: x - r - 2, y: y - 42 - r, width: r*2, height: r*2)), with: .color(skin))
            // Body lean back
            var body = Path(); body.move(to: CGPoint(x: x - 2, y: y - 42)); body.addLine(to: CGPoint(x: x + 3, y: y - 16))
            ctx.stroke(body, with: .color(color), lineWidth: 3)
            // #45 Pitcher throwing arm raised
            var ta = Path(); ta.move(to: CGPoint(x: x, y: y - 30)); ta.addLine(to: CGPoint(x: x + 22, y: y - 42))
            ctx.stroke(ta, with: .color(color), lineWidth: 2.5)
            ctx.fill(Path(ellipseIn: CGRect(x: x + 19, y: y - 47, width: 8, height: 8)),
                     with: .color(Color(red: 0.93, green: 0.86, blue: 0.68)))
            // Glove arm
            var ga = Path(); ga.move(to: CGPoint(x: x, y: y - 30)); ga.addLine(to: CGPoint(x: x - 18, y: y - 26))
            ctx.stroke(ga, with: .color(color), lineWidth: 2.5)
            // #46 Pitcher leg kick
            var legs = Path()
            legs.move(to: CGPoint(x: x + 3, y: y - 16)); legs.addLine(to: CGPoint(x: x + 16, y: y))
            legs.move(to: CGPoint(x: x + 3, y: y - 16)); legs.addLine(to: CGPoint(x: x - 6, y: y - 26))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        case "release":
            // #47 Pitcher release — head
            ctx.fill(Path(ellipseIn: CGRect(x: x - r + 4, y: y - 40 - r, width: r*2, height: r*2)), with: .color(skin))
            var body = Path(); body.move(to: CGPoint(x: x + 4, y: y - 40)); body.addLine(to: CGPoint(x: x - 4, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3)
            // #48 Release arm forward snap
            var ta = Path(); ta.move(to: CGPoint(x: x + 1, y: y - 30)); ta.addLine(to: CGPoint(x: x + 24, y: y - 24))
            ctx.stroke(ta, with: .color(color), lineWidth: 2.5)
            var ga = Path(); ga.move(to: CGPoint(x: x + 1, y: y - 30)); ga.addLine(to: CGPoint(x: x - 16, y: y - 38))
            ctx.stroke(ga, with: .color(color), lineWidth: 2.5)
            var legs = Path()
            legs.move(to: CGPoint(x: x - 4, y: y - 14)); legs.addLine(to: CGPoint(x: x + 18, y: y))
            legs.move(to: CGPoint(x: x - 4, y: y - 14)); legs.addLine(to: CGPoint(x: x - 16, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        case "followthrough":
            // #49 Pitcher follow-through — head
            ctx.fill(Path(ellipseIn: CGRect(x: x - r + 6, y: y - 36 - r, width: r*2, height: r*2)), with: .color(skin))
            var body = Path(); body.move(to: CGPoint(x: x + 6, y: y - 36)); body.addLine(to: CGPoint(x: x - 4, y: y - 14))
            ctx.stroke(body, with: .color(color), lineWidth: 3)
            // #50 Follow-through arm sweep
            var ta = Path(); ta.move(to: CGPoint(x: x + 2, y: y - 27)); ta.addLine(to: CGPoint(x: x + 18, y: y - 14))
            ctx.stroke(ta, with: .color(color), lineWidth: 2.5)
            var ga = Path(); ga.move(to: CGPoint(x: x + 2, y: y - 27)); ga.addLine(to: CGPoint(x: x - 14, y: y - 20))
            ctx.stroke(ga, with: .color(color), lineWidth: 2.5)
            var legs = Path()
            legs.move(to: CGPoint(x: x - 4, y: y - 14)); legs.addLine(to: CGPoint(x: x + 18, y: y))
            legs.move(to: CGPoint(x: x - 4, y: y - 14)); legs.addLine(to: CGPoint(x: x - 16, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 2.5)

        default:
            // #51 Pitcher idle stance (gentle bob)
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

    // MARK: Batter (#52–#58)

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
            // #52 Batter swing — helmet
            helmet(hx: x + 3, hy: y - 46)
            var body = Path(); body.move(to: CGPoint(x: x + 3, y: y - 46)); body.addLine(to: CGPoint(x: x - 5, y: y - 20))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            // #53 Batter arms extended through zone
            var arms = Path(); arms.move(to: CGPoint(x: x - 1, y: y - 35)); arms.addLine(to: CGPoint(x: x - 32, y: y - 31))
            ctx.stroke(arms, with: .color(color), lineWidth: 3)
            // #54 Bat through contact zone
            var bat = Path(); bat.move(to: CGPoint(x: x + 10, y: y - 33)); bat.addLine(to: CGPoint(x: x - 42, y: y - 28))
            ctx.stroke(bat, with: .color(batColor), lineWidth: 5)
            // Bat highlight
            var hl = Path(); hl.move(to: CGPoint(x: x + 6, y: y - 34)); hl.addLine(to: CGPoint(x: x - 38, y: y - 29))
            ctx.stroke(hl, with: .color(Color(white: 0.9).opacity(0.22)), lineWidth: 2)
            var legs = Path()
            legs.move(to: CGPoint(x: x - 5, y: y - 20)); legs.addLine(to: CGPoint(x: x - 12, y: y))
            legs.move(to: CGPoint(x: x - 5, y: y - 20)); legs.addLine(to: CGPoint(x: x + 18, y: y))
            ctx.stroke(legs, with: .color(color), lineWidth: 3)

        case "miss":
            // #55 Batter miss / overswing — helmet
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
            // #56 Batter celebrate jump
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
            // #57 Batter ready — coiled stance (gentle bob)
            let bob = CGFloat(sin(t * 2.0)) * 1.0
            helmet(hx: x, hy: y - 46 + bob)
            var body = Path(); body.move(to: CGPoint(x: x, y: y - 46 + bob)); body.addLine(to: CGPoint(x: x, y: y - 20))
            ctx.stroke(body, with: .color(color), lineWidth: 3.5)
            // Arms coiled back
            var arms = Path()
            arms.move(to: CGPoint(x: x, y: y - 36 + bob)); arms.addLine(to: CGPoint(x: x - 20, y: y - 31 + bob))
            ctx.stroke(arms, with: .color(color), lineWidth: 3)
            var arms2 = Path()
            arms2.move(to: CGPoint(x: x, y: y - 36 + bob)); arms2.addLine(to: CGPoint(x: x + 6, y: y - 31 + bob))
            ctx.stroke(arms2, with: .color(color), lineWidth: 3)
            // #58 Bat held up in ready position
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

    // MARK: - BALL & PLAY (#59–#72)

    private func drawPitchBall(ctx: inout GraphicsContext) {
        guard pitchProgress >= 0 else { return }
        let ep = CGFloat(pitchProgress)
        let sx = pitcherX + 14; let sy = moundY - 22
        let ex = batterX - 12; let ey = floorY - 30
        let curve = pitch.curveOffset * W
        let bx = sx + (ex - sx) * ep + curve * 4 * ep * (1 - ep)
        let by = sy + (ey - sy) * ep
        let ballR = 5 + ep * 3

        // #59 Pitch trail ghost dots (motion blur)
        for g in 1...3 {
            let pep = max(0, ep - CGFloat(g) * 0.07)
            let gx = sx + (ex - sx) * pep + curve * 4 * pep * (1 - pep)
            let gy = sy + (ey - sy) * pep
            var gc = ctx; gc.opacity = Double(0.13 - CGFloat(g) * 0.03)
            gc.fill(Path(ellipseIn: CGRect(x: gx - ballR * 0.7, y: gy - ballR * 0.7, width: ballR * 1.4, height: ballR * 1.4)),
                    with: .color(.white))
        }
        // #60 Pitch ball glow
        var glow = ctx; glow.addFilter(.blur(radius: 7)); glow.opacity = 0.4
        glow.fill(Path(ellipseIn: CGRect(x: bx - 10, y: by - 10, width: 20, height: 20)), with: .color(.white))
        // #61 Pitch ball body
        ctx.fill(
            Path(ellipseIn: CGRect(x: bx - ballR, y: by - ballR, width: ballR * 2, height: ballR * 2)),
            with: .radialGradient(Gradient(colors: [.white, Color(white: 0.82)]),
                                  center: CGPoint(x: bx, y: by), startRadius: 0, endRadius: ballR * 1.5)
        )
        // #62 Seam stitches on ball
        var seam = Path()
        seam.addArc(center: CGPoint(x: bx, y: by), radius: ballR - 1,
                    startAngle: .degrees(20), endAngle: .degrees(75), clockwise: false)
        ctx.stroke(seam, with: .color(Color(red: 0.8, green: 0.1, blue: 0.1).opacity(0.65)), lineWidth: 1)
        // #63 Pitch arc trajectory guide (faint dotted line)
        if ep < 0.3 {
            var arcGuide = Path()
            arcGuide.move(to: CGPoint(x: sx, y: sy))
            arcGuide.addCurve(
                to: CGPoint(x: ex, y: ey),
                control1: CGPoint(x: sx + (ex - sx) * 0.33 + curve * 2, y: sy + (ey - sy) * 0.33),
                control2: CGPoint(x: sx + (ex - sx) * 0.66 + curve * 2, y: sy + (ey - sy) * 0.66)
            )
            var gc63 = ctx; gc63.opacity = 0.10
            gc63.stroke(arcGuide, with: .color(.white), lineWidth: 0.8)
        }
    }

    private func drawHitBall(ctx: inout GraphicsContext) {
        guard hitProgress >= 0 else { return }
        let ep = CGFloat(hitProgress)
        let sx = batterX - 24; let sy = floorY - 32
        let (ex, ey, peakH): (CGFloat, CGFloat, CGFloat) = hitType == "homeRun"
            ? (W * 0.05, H * 0.18, H * 0.58)
            : (W * 0.22, floorY - 15, H * 0.20)
        let bx = sx + (ex - sx) * ep
        let by = sy + (ey - sy) * ep - peakH * 4 * ep * (1 - ep)

        // #64 Hit ball trail
        for g in 1...4 {
            let pep = max(0, ep - CGFloat(g) * 0.05)
            let gx = sx + (ex - sx) * pep
            let gy = sy + (ey - sy) * pep - peakH * 4 * pep * (1 - pep)
            var gc = ctx; gc.opacity = Double(0.10 - CGFloat(g) * 0.02)
            gc.fill(Path(ellipseIn: CGRect(x: gx - 6, y: gy - 6, width: 12, height: 12)), with: .color(.white))
        }
        // #65 Home run ball glow (orange)
        if hitType == "homeRun" {
            var glow = ctx; glow.addFilter(.blur(radius: 16)); glow.opacity = Double(ep) * 0.55
            glow.fill(Path(ellipseIn: CGRect(x: bx - 22, y: by - 22, width: 44, height: 44)), with: .color(.orange))
        }
        // #66 Hit ball body
        ctx.fill(
            Path(ellipseIn: CGRect(x: bx - 7, y: by - 7, width: 14, height: 14)),
            with: .radialGradient(Gradient(colors: [.white, Color(white: 0.82)]),
                                  center: CGPoint(x: bx, y: by), startRadius: 0, endRadius: 9)
        )
        // #67 Home run high arc trajectory ghost path
        if hitType == "homeRun" && ep < 0.5 {
            var arcPath = Path()
            arcPath.move(to: CGPoint(x: sx, y: sy))
            arcPath.addCurve(
                to: CGPoint(x: ex, y: ey),
                control1: CGPoint(x: sx + (ex - sx) * 0.3, y: sy - peakH * 0.8),
                control2: CGPoint(x: sx + (ex - sx) * 0.7, y: sy - peakH * 0.6)
            )
            var gc67 = ctx; gc67.opacity = 0.12
            gc67.stroke(arcPath, with: .color(.orange), lineWidth: 1)
        }
        // #68 Pop-up vertical path indicator
        if hitType == "basehit" && ep < 0.35 {
            var popPath = Path()
            popPath.move(to: CGPoint(x: sx, y: sy))
            popPath.addLine(to: CGPoint(x: sx + 6, y: sy - peakH * 0.4))
            var gc68 = ctx; gc68.opacity = 0.15
            gc68.stroke(popPath, with: .color(.yellow), lineWidth: 0.8)
        }
    }

    // MARK: - HIT FX (#69–#86)

    private func drawHitSparks(ctx: inout GraphicsContext) {
        let frac = (t - lastHitTime) / 0.55
        let alpha = max(0, 1.0 - frac * 1.5)
        guard alpha > 0 else { return }
        let cx = batterX - 24; let cy = floorY - 32

        // #69 Impact ring expanding
        let ringR = CGFloat(frac) * 45
        var ring = Path()
        ring.addEllipse(in: CGRect(x: cx - ringR, y: cy - ringR, width: ringR * 2, height: ringR * 2))
        var rc = ctx; rc.opacity = alpha * 0.55
        rc.stroke(ring, with: .color(Color(red: 1, green: 0.88, blue: 0.15)), lineWidth: 2)

        // #70 Crack impact 8 spark rays
        for i in 0..<8 {
            let angle = Double(i) / 8.0 * .pi * 2
            let len = CGFloat(14 + i % 3 * 7) * (1.0 - CGFloat(frac) * 0.65)
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

        // #71 Secondary finer spark rays (6 more)
        for i in 0..<6 {
            let angle = Double(i) / 6.0 * .pi * 2 + .pi / 6
            let len = CGFloat(8 + i % 2 * 4) * (1.0 - CGFloat(frac) * 0.8)
            let sRadius = CGFloat(frac) * 12
            let spx = cx + CGFloat(cos(angle)) * sRadius
            let spy = cy + CGFloat(sin(angle)) * sRadius
            var spark = Path()
            spark.move(to: CGPoint(x: spx, y: spy))
            spark.addLine(to: CGPoint(x: spx + CGFloat(cos(angle)) * len, y: spy + CGFloat(sin(angle)) * len))
            var sc3 = ctx; sc3.opacity = alpha * 0.40
            sc3.stroke(spark, with: .color(.white), lineWidth: 1)
        }

        // #72 Impact flash core
        let fr = CGFloat(9 * (1.0 - frac * 1.3))
        if fr > 0 {
            var fc = ctx; fc.opacity = alpha
            fc.fill(Path(ellipseIn: CGRect(x: cx - fr, y: cy - fr, width: fr * 2, height: fr * 2)), with: .color(.white))
            // Inner glow
            var fc2 = ctx; fc2.addFilter(.blur(radius: 6)); fc2.opacity = alpha * 0.6
            fc2.fill(Path(ellipseIn: CGRect(x: cx - fr * 1.5, y: cy - fr * 1.5, width: fr * 3, height: fr * 3)), with: .color(Color(red: 1, green: 0.95, blue: 0.5)))
        }
    }

    private func drawHomeRunFireworks(ctx: inout GraphicsContext) {
        guard hitType == "homeRun", hitProgress >= 0 else { return }
        let ep = CGFloat(hitProgress)
        guard ep > 0.3 else { return }
        let fireworkPhase = (ep - 0.3) / 0.7  // 0→1 over second half of trajectory

        // #73 Firework rocket trail 1 (left arc)
        let r1x = W * 0.15 + CGFloat(sin(t * 2.1)) * 6
        let r1y = H * 0.35 - fireworkPhase * H * 0.18
        var rocket1 = Path()
        rocket1.move(to: CGPoint(x: r1x, y: r1y))
        rocket1.addLine(to: CGPoint(x: r1x + 2, y: r1y + 20))
        var gr1 = ctx; gr1.opacity = Double(fireworkPhase) * 0.8
        gr1.stroke(rocket1, with: .color(Color(red: 1, green: 0.6, blue: 0.1)), lineWidth: 2)

        // #74 Firework rocket trail 2 (right arc)
        let r2x = W * 0.25 + CGFloat(cos(t * 1.8)) * 5
        let r2y = H * 0.30 - fireworkPhase * H * 0.15
        var rocket2 = Path()
        rocket2.move(to: CGPoint(x: r2x, y: r2y))
        rocket2.addLine(to: CGPoint(x: r2x - 2, y: r2y + 18))
        var gr2 = ctx; gr2.opacity = Double(fireworkPhase) * 0.75
        gr2.stroke(rocket2, with: .color(Color(red: 1, green: 0.85, blue: 0.1)), lineWidth: 2)

        // #75 Firework burst 1 — star spray (orange)
        if fireworkPhase > 0.5 {
            let bfrac = (fireworkPhase - 0.5) / 0.5
            let burst1cx = W * 0.12; let burst1cy = H * 0.22
            for i in 0..<8 {
                let angle = Double(i) / 8.0 * .pi * 2
                let blen = CGFloat(bfrac) * 28
                var bray = Path()
                bray.move(to: CGPoint(x: burst1cx, y: burst1cy))
                bray.addLine(to: CGPoint(x: burst1cx + CGFloat(cos(angle)) * blen, y: burst1cy + CGFloat(sin(angle)) * blen))
                var gb = ctx; gb.opacity = Double((1.0 - bfrac) * 0.85)
                gb.stroke(bray, with: .color(.orange), lineWidth: 1.5)
            }
            // Burst glow
            var gbg = ctx; gbg.addFilter(.blur(radius: 10)); gbg.opacity = Double((1.0 - bfrac) * 0.5)
            gbg.fill(Path(ellipseIn: CGRect(x: burst1cx - 16, y: burst1cy - 16, width: 32, height: 32)), with: .color(.orange))
        }

        // #76 Firework burst 2 — star spray (gold)
        if fireworkPhase > 0.6 {
            let bfrac = (fireworkPhase - 0.6) / 0.4
            let burst2cx = W * 0.28; let burst2cy = H * 0.18
            for i in 0..<6 {
                let angle = Double(i) / 6.0 * .pi * 2 + 0.3
                let blen = CGFloat(bfrac) * 22
                var bray = Path()
                bray.move(to: CGPoint(x: burst2cx, y: burst2cy))
                bray.addLine(to: CGPoint(x: burst2cx + CGFloat(cos(angle)) * blen, y: burst2cy + CGFloat(sin(angle)) * blen))
                var gb = ctx; gb.opacity = Double((1.0 - bfrac) * 0.80)
                gb.stroke(bray, with: .color(Color(red: 1, green: 0.92, blue: 0.2)), lineWidth: 1.5)
            }
        }

        // #77 Firework burst 3 — white star
        if fireworkPhase > 0.45 {
            let bfrac = (fireworkPhase - 0.45) / 0.55
            let burst3cx = W * 0.20; let burst3cy = H * 0.25
            for i in 0..<10 {
                let angle = Double(i) / 10.0 * .pi * 2
                let blen = CGFloat(bfrac) * 18
                var bray = Path()
                bray.move(to: CGPoint(x: burst3cx, y: burst3cy))
                bray.addLine(to: CGPoint(x: burst3cx + CGFloat(cos(angle)) * blen, y: burst3cy + CGFloat(sin(angle)) * blen))
                var gb = ctx; gb.opacity = Double((1.0 - bfrac) * 0.70)
                gb.stroke(bray, with: .color(.white), lineWidth: 1)
            }
        }

        // #78 Firework rocket trail 3 (center)
        let r3x = W * 0.20
        let r3y = H * 0.32 - fireworkPhase * H * 0.20
        var rocket3 = Path()
        rocket3.move(to: CGPoint(x: r3x, y: r3y))
        rocket3.addLine(to: CGPoint(x: r3x, y: r3y + 16))
        var gr3 = ctx; gr3.opacity = Double(fireworkPhase) * 0.70
        gr3.stroke(rocket3, with: .color(Color(red: 0.8, green: 0.2, blue: 1.0)), lineWidth: 2)

        // #79 Firework burst stars (glitter particles)
        if fireworkPhase > 0.55 {
            let pfrac = (fireworkPhase - 0.55) / 0.45
            for i in 0..<12 {
                let angle = Double(i) / 12.0 * .pi * 2
                let dist = CGFloat(pfrac) * 40
                let px2 = W * 0.20 + CGFloat(cos(angle)) * dist
                let py2 = H * 0.22 + CGFloat(sin(angle)) * dist
                var gc79 = ctx; gc79.opacity = Double((1.0 - pfrac) * 0.60)
                gc79.fill(Path(ellipseIn: CGRect(x: px2 - 2, y: py2 - 2, width: 4, height: 4)), with: .color(.white))
            }
        }

        // #80 Crowd celebration wave (upper tier brightens)
        if fireworkPhase > 0.4 {
            let waveFrac = (fireworkPhase - 0.4) / 0.6
            var gc80 = ctx; gc80.addFilter(.blur(radius: 15)); gc80.opacity = Double(sin(waveFrac * .pi) * 0.25)
            gc80.fill(
                Path(CGRect(x: 0, y: H * 0.09, width: W, height: H * 0.12)),
                with: .color(Color(red: 1, green: 0.85, blue: 0.3))
            )
        }
    }

    private func drawStrikeoutVignette(ctx: inout GraphicsContext) {
        guard batterPhase == "miss" else { return }
        // #81 Strikeout dark vignette edges
        var gc81 = ctx; gc81.addFilter(.blur(radius: 30)); gc81.opacity = 0.55
        var vigPath = Path()
        vigPath.addRect(CGRect(origin: .zero, size: size))
        vigPath.addEllipse(in: CGRect(x: W * 0.1, y: H * 0.1, width: W * 0.8, height: H * 0.8))
        gc81.fill(vigPath, with: .color(.black))

        // #82 Strikeout red tint overlay
        var gc82 = ctx; gc82.opacity = 0.12
        gc82.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.6, green: 0.0, blue: 0.0)))

        // #83 "K" overlay symbol
        let kText = ctx.resolve(Text("K")
            .font(.system(size: 60, weight: .black, design: .monospaced))
            .foregroundStyle(Color.red.opacity(0.35)))
        ctx.draw(kText, at: CGPoint(x: W * 0.50, y: H * 0.48))
    }

    // MARK: Swing Zone Ring (#84–#86)

    private func drawSwingZoneRing(ctx: inout GraphicsContext) {
        let ep = CGFloat(pitchProgress)
        let pulse = 0.45 + 0.28 * CGFloat(sin(t * 6.5))
        let cx = batterX - 12; let cy = floorY - 30

        // #84 Outer swing zone ring (yellow)
        var outer = Path()
        outer.addEllipse(in: CGRect(x: cx - 38, y: cy - 29, width: 76, height: 58))
        var oc = ctx; oc.opacity = Double(0.22 * pulse)
        oc.stroke(outer, with: .color(.yellow), lineWidth: 2)

        // #85 Perfect zone inner ring (green, only during ideal window)
        if ep >= 0.62 && ep <= 0.82 {
            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx - 23, y: cy - 17, width: 46, height: 34))
            var ic = ctx; ic.opacity = Double(0.50 * pulse)
            ic.stroke(inner, with: .color(.green), lineWidth: 2.5)

            // #86 Perfect zone glow shimmer
            var gc86 = ctx; gc86.addFilter(.blur(radius: 8)); gc86.opacity = Double(0.25 * pulse)
            gc86.stroke(inner, with: .color(.green), lineWidth: 6)
        }
    }
}

// MARK: - Haptics Helper

private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

private func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
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
    @State private var balls: Int = 0
    @State private var strikes: Int = 0
    @State private var pitchInZone: Bool = true
    @State private var countBannerText: String = ""
    @State private var showCountBanner: Bool = false
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
    @State private var shakeX: CGFloat = 0
    @State private var shakeY: CGFloat = 0
    @State private var burstParticles: [(id: Int, x: CGFloat, y: CGFloat, angle: Double, distance: CGFloat, opacity: Double, color: Color)] = []
    @State private var burstCounter: Int = 0

    // Fielding state
    @State private var fieldingZone: Int = 0          // 0=LF, 1=CF, 2=RF
    @State private var ballTrajectory: CGFloat = 0    // 0.0→1.0 animation
    @State private var fieldingWindow: Bool = false
    @State private var fieldingSuccess: Bool? = nil
    @State private var isGrounder: Bool = false
    @State private var fieldingTask: Task<Void, Never>? = nil

    private var swingWindowOpen: Bool { pitchProgress >= 0.46 && pitchProgress < 1.0 }
    private let perfectZone: ClosedRange<Double> = 0.62...0.82
    private let goodZone: ClosedRange<Double> = 0.50...0.90

    var body: some View {
        ZStack {
            Group {
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
                case .fielding: fieldingBody
                case .pitching: pitchingBody
                case .inningBreak: inningBreakBody
                case .result:   resultBody
                }
            }
            .offset(x: shakeX, y: shakeY)

            ForEach(burstParticles, id: \.id) { p in
                Circle().fill(p.color).frame(width: 7, height: 7)
                    .offset(x: p.x - UIScreen.main.bounds.width/2 + CGFloat(cos(p.angle)) * p.distance,
                            y: p.y - UIScreen.main.bounds.height/2 + CGFloat(sin(p.angle)) * p.distance)
                    .opacity(p.opacity).blur(radius: 1)
            }
            .allowsHitTesting(false)
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
        .onDisappear { pitchTask?.cancel(); aiAtBatTask?.cancel(); fieldingTask?.cancel() }
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
                Text("\(balls)-\(strikes)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.4, green: 0.85, blue: 0.4))
                    .padding(.top, 1)
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
                crowdLevel: crowdLevel, aiBatterPhase: aiBatterPhase,
                swingResult: swingResult, playerScore: playerScore,
                aiScore: aiScore, inning: inning, outs: outs
            )

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
                crowdLevel: crowdLevel, aiBatterPhase: aiBatterPhase,
                swingResult: .none, playerScore: playerScore,
                aiScore: aiScore, inning: inning, outs: outs
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

    // MARK: Fielding Body

    private var fieldingBody: some View {
        let zoneLabels = ["LF", "CF", "RF"]
        let zoneColors: [Color] = [.green, .mint, .teal]
        return ZStack {
            // Outfield background
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate

                    // Green outfield
                    ctx.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .linearGradient(
                                Gradient(colors: [
                                    Color(red: 0.06, green: 0.28, blue: 0.10),
                                    Color(red: 0.04, green: 0.20, blue: 0.07)
                                ]),
                                startPoint: .init(x: size.width * 0.5, y: 0),
                                endPoint: .init(x: size.width * 0.5, y: size.height)
                             ))

                    // Foul lines
                    var foulPath = Path()
                    foulPath.move(to: CGPoint(x: size.width * 0.5, y: size.height))
                    foulPath.addLine(to: CGPoint(x: size.width * 0.08, y: 0))
                    foulPath.move(to: CGPoint(x: size.width * 0.5, y: size.height))
                    foulPath.addLine(to: CGPoint(x: size.width * 0.92, y: 0))
                    ctx.stroke(foulPath, with: .color(.white.opacity(0.35)), lineWidth: 2)

                    // Grass stripes
                    for i in 0..<8 {
                        let stripeAlpha = i.isMultiple(of: 2) ? 0.05 : 0.0
                        let stripeW = size.width / 8
                        ctx.fill(Path(CGRect(x: CGFloat(i) * stripeW, y: 0,
                                             width: stripeW, height: size.height)),
                                 with: .color(.white.opacity(stripeAlpha)))
                    }

                    // Home plate marker
                    var platePath = Path()
                    platePath.move(to: CGPoint(x: size.width * 0.50, y: size.height - 20))
                    platePath.addLine(to: CGPoint(x: size.width * 0.46, y: size.height - 30))
                    platePath.addLine(to: CGPoint(x: size.width * 0.54, y: size.height - 30))
                    platePath.closeSubpath()
                    ctx.fill(platePath, with: .color(.white.opacity(0.6)))

                    // Fielder zone circles
                    let zoneXs: [CGFloat] = [size.width * 0.18, size.width * 0.50, size.width * 0.82]
                    let zoneY: CGFloat = size.height * 0.30
                    let zoneR: CGFloat = 38

                    for (idx, zx) in zoneXs.enumerated() {
                        let isTarget = idx == fieldingZone
                        let nearBall = ballTrajectory > 0.6 && isTarget
                        let pulse = CGFloat(0.5 + 0.5 * sin(t * 6))
                        let circleRect = CGRect(x: zx - zoneR, y: zoneY - zoneR,
                                                width: zoneR * 2, height: zoneR * 2)

                        // Glow on target when ball is near
                        if nearBall && fieldingWindow {
                            var gc = ctx
                            gc.addFilter(.blur(radius: 14))
                            gc.opacity = Double(0.6 * pulse)
                            gc.fill(Path(ellipseIn: circleRect.insetBy(dx: -8, dy: -8)),
                                    with: .color(.yellow))
                        }

                        // Zone fill
                        let zoneAlpha: CGFloat = isTarget && fieldingWindow ? 0.55 : 0.28
                        ctx.fill(Path(ellipseIn: circleRect),
                                 with: .color(zoneColors[idx].opacity(Double(zoneAlpha))))
                        ctx.stroke(Path(ellipseIn: circleRect),
                                   with: .color(isTarget && fieldingWindow ? .yellow : .white.opacity(0.4)),
                                   lineWidth: isTarget && fieldingWindow ? 2.5 : 1.5)

                        // Zone label
                        ctx.draw(Text(zoneLabels[idx])
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.white),
                                 at: CGPoint(x: zx, y: zoneY + 60))
                    }

                    // Animated ball arc (home plate → target zone)
                    if ballTrajectory > 0 {
                        let prog = ballTrajectory
                        let targetX = zoneXs[fieldingZone]
                        let startX = size.width * 0.50
                        let startY = size.height - 30
                        let endY = size.height * 0.30
                        // Bezier arc
                        let ctrlX = (startX + targetX) * 0.5
                        let ctrlY = size.height * 0.05
                        // Linear interpolation along bezier
                        let bx = (1 - prog) * (1 - prog) * startX
                              + 2 * (1 - prog) * prog * ctrlX
                              + prog * prog * targetX
                        let by = (1 - prog) * (1 - prog) * startY
                              + 2 * (1 - prog) * prog * ctrlY
                              + prog * prog * endY
                        let ballR: CGFloat = isGrounder ? 6 : 8
                        let ballRect = CGRect(x: bx - ballR, y: by - ballR,
                                             width: ballR * 2, height: ballR * 2)
                        // Ball shadow
                        var sc = ctx; sc.addFilter(.blur(radius: 4)); sc.opacity = 0.4
                        sc.fill(Path(ellipseIn: ballRect.offsetBy(dx: 3, dy: 3)),
                                with: .color(.black))
                        // Ball
                        ctx.fill(Path(ellipseIn: ballRect), with: .color(.white))
                        ctx.stroke(Path(ellipseIn: ballRect), with: .color(.red.opacity(0.7)), lineWidth: 1)

                        // Grounder: draw ground bounce effect
                        if isGrounder && prog > 0.4 {
                            var bouncePath = Path()
                            bouncePath.move(to: CGPoint(x: bx - 12, y: by + ballR))
                            bouncePath.addLine(to: CGPoint(x: bx + 12, y: by + ballR))
                            ctx.stroke(bouncePath, with: .color(.yellow.opacity(0.5)), lineWidth: 2)
                        }
                    }

                    // Result overlay
                    if let success = fieldingSuccess {
                        let label = success ? "CAUGHT! OUT!" : (isGrounder ? "GROUNDER — HIT" : "FLY BALL — HIT")
                        let color: Color = success ? .green : .red
                        ctx.draw(Text(label)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(color),
                                 at: CGPoint(x: size.width * 0.5, y: size.height * 0.55))
                    }
                }
            }
            .ignoresSafeArea()

            // HUD overlay
            VStack(spacing: 0) {
                scoreHUD
                Spacer()
                if fieldingWindow && fieldingSuccess == nil {
                    Text(isGrounder ? "GROUNDER — TAP FAST!" : "FLY BALL — TAP TO CATCH")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.6), radius: 8)
                        .padding(.vertical, 8).padding(.horizontal, 18)
                        .background(Color.black.opacity(0.55))
                        .clipShape(.rect(cornerRadius: 10))
                        .transition(.opacity)
                }
                Spacer()
                // Tap zones row
                HStack(spacing: 0) {
                    ForEach(0..<3) { idx in
                        Button {
                            handleFieldingTap(zone: idx)
                        } label: {
                            Text(zoneLabels[idx])
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(zoneColors[idx].opacity(fieldingWindow ? 0.45 : 0.20))
                                .overlay(
                                    Rectangle()
                                        .frame(height: 2)
                                        .foregroundStyle(zoneColors[idx].opacity(0.8)),
                                    alignment: .top
                                )
                        }
                        .disabled(!fieldingWindow || fieldingSuccess != nil)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
            if showCountBanner {
                let isBall = countBannerText.hasPrefix("BALL") || countBannerText.hasPrefix("WALK")
                return (isBall ? Color(red: 0.3, green: 0.85, blue: 0.4) : Color(red: 1.0, green: 0.5, blue: 0.1),
                        countBannerText)
            }
            switch swingResult {
            case .homeRun:  return (.orange, "HOME RUN!")
            case .basehit:  return (.yellow, "BASE HIT")
            case .foul:     return (Color(white: 0.75), "FOUL BALL")
            case .miss:     return (.red, "STRIKEOUT!")
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
        outs = 0; balls = 0; strikes = 0; isTopHalf = true; phase = .batting
        deliverPitch()
    }

    private func deliverPitch() {
        currentPitch = PitchType.allCases.randomElement() ?? .fastball
        // Ball-in-zone probability: 65% strikes, higher with 2 strikes to pressure batter
        let strikeProb = strikes == 2 ? 0.75 : 0.65
        pitchInZone = Double.random(in: 0...1) < strikeProb
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
                if !playerSwung {
                    if pitchInZone {
                        recordCalledStrike()
                    } else {
                        recordBall()
                    }
                }
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
                result = strikes < 2 ? .foul : .miss  // foul on 0-1 strikes, swinging K on 2
            }
        } else {
            result = strikes < 2 ? .foul : .miss
        }
        pitchProgress = -1.0
        recordSwingResult(result)
    }

    private func recordBall() {
        balls += 1
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        countBannerText = balls >= 4 ? "WALK! BALL 4" : "BALL \(balls)"
        swingResult = .none
        showResultBanner = true; showCountBanner = true
        withAnimation(.spring(response: 0.25)) { bannerScale = 1.0 }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            await MainActor.run {
                bannerScale = 0.6; showResultBanner = false; showCountBanner = false
                batterPhase = "ready"; pitcherPhase = "idle"
                if balls >= 4 {
                    // Walk
                    balls = 0; strikes = 0
                    playerScore += 1
                    crowdLevel = min(1.0, crowdLevel + 0.05)
                    countBannerText = "WALK! +1 RUN"
                    withAnimation { showCountBanner = true; showResultBanner = true; bannerScale = 1.0 }
                    Task {
                        try? await Task.sleep(for: .seconds(1.1))
                        await MainActor.run {
                            bannerScale = 0.6; showResultBanner = false; showCountBanner = false; swingResult = .none
                            batterPhase = "ready"; pitcherPhase = "idle"
                            if outs >= OUTS_PER_INNING { endHalfInning() } else { deliverPitch() }
                        }
                    }
                } else {
                    deliverPitch()
                }
            }
        }
    }

    private func recordCalledStrike() {
        strikes += 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        countBannerText = strikes >= 3 ? "STRIKEOUT LOOKING!" : "CALLED STRIKE \(strikes)"
        swingResult = .none
        showResultBanner = true; showCountBanner = true
        withAnimation(.spring(response: 0.25)) { bannerScale = 1.0 }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            await MainActor.run {
                bannerScale = 0.6; showResultBanner = false; showCountBanner = false
                batterPhase = "ready"; pitcherPhase = "idle"
                if strikes >= 3 {
                    balls = 0; strikes = 0
                    batterPhase = "miss"; outs += 1
                    triggerShake(intensity: 3)
                    triggerBurst(color: gameMode.accentColor, count: 12)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    if outs >= OUTS_PER_INNING { endHalfInning() } else { deliverPitch() }
                } else {
                    deliverPitch()
                }
            }
        }
    }

    private func recordSwingResult(_ result: SwingResult) {
        swingResult = result
        showResultBanner = true
        withAnimation(.spring(response: 0.25)) { bannerScale = 1.0 }

        switch result {
        case .homeRun:
            balls = 0; strikes = 0
            batterPhase = "swing"; hitType = "homeRun"
            lastHitTime = Date().timeIntervalSinceReferenceDate
            playerScore += Int.random(in: 1...4)
            crowdLevel = min(1.0, crowdLevel + 0.45)
            triggerShake(intensity: 8)
            triggerBurst(color: .yellow, count: 22)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            startHitBallAnim(steps: 65)
        case .basehit:
            balls = 0; strikes = 0
            batterPhase = "swing"; hitType = "basehit"
            lastHitTime = Date().timeIntervalSinceReferenceDate
            playerScore += 1
            crowdLevel = min(1.0, crowdLevel + 0.12)
            triggerBurst(color: gameMode.accentColor, count: 10)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            startHitBallAnim(steps: 38)
        case .foul:
            // Foul can't increase strikes past 2
            if strikes < 2 { strikes += 1 }
            batterPhase = "swing"
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .miss:
            balls = 0; strikes = 0
            batterPhase = "miss"; outs += 1
            triggerShake(intensity: 3)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .none: break
        }

        let delay: Double = result == .homeRun ? 2.4 : 1.6
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run {
                bannerScale = 0.6; showResultBanner = false; showCountBanner = false; swingResult = .none
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
        balls = 0; strikes = 0
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
                if roll < 0.08 {
                    // Home run — no fielding possible
                    await MainActor.run {
                        aiBatterPhase = "swing"
                        aiResultLabel = "HOME RUN! 💥"
                        aiScore += Int.random(in: 1...2)
                        crowdLevel = min(1.0, crowdLevel + 0.3)
                        withAnimation(.spring(response: 0.25)) { showAIResult = true }
                    }
                    try? await Task.sleep(for: .seconds(1.4))
                    await MainActor.run { withAnimation { showAIResult = false }; aiBatterPhase = "ready" }
                } else if roll < 0.30 {
                    // AI hit — trigger fielding phase; player can field it
                    let grounder = Bool.random()
                    await MainActor.run { aiBatterPhase = "swing" }
                    try? await Task.sleep(for: .seconds(0.3))
                    guard !Task.isCancelled else { return }
                    // Hand off to fielding phase; wait for it to resolve
                    let caught = await triggerFieldingPhase(grounder: grounder)
                    guard !Task.isCancelled else { return }
                    if caught {
                        aiOuts += 1
                        await MainActor.run {
                            aiBatterPhase = "miss"
                            aiResultLabel = "CAUGHT! OUT (\(aiOuts)/3)"
                            withAnimation(.spring(response: 0.25)) { showAIResult = true }
                        }
                    } else {
                        await MainActor.run {
                            aiScore += 1
                            aiBatterPhase = "swing"
                            aiResultLabel = grounder ? "GROUNDER — HIT" : "FLY BALL — HIT"
                            withAnimation(.spring(response: 0.25)) { showAIResult = true }
                        }
                    }
                    try? await Task.sleep(for: .seconds(1.1))
                    await MainActor.run { withAnimation { showAIResult = false }; aiBatterPhase = "ready"; phase = .pitching }
                } else if roll < 0.52 {
                    await MainActor.run {
                        aiBatterPhase = "swing"
                        aiResultLabel = "FOUL BALL"
                        withAnimation(.spring(response: 0.25)) { showAIResult = true }
                    }
                    try? await Task.sleep(for: .seconds(1.1))
                    await MainActor.run { withAnimation { showAIResult = false }; aiBatterPhase = "ready" }
                } else {
                    aiOuts += 1
                    await MainActor.run {
                        aiBatterPhase = "miss"
                        aiResultLabel = "OUT (\(aiOuts)/3)"
                        withAnimation(.spring(response: 0.25)) { showAIResult = true }
                    }
                    try? await Task.sleep(for: .seconds(1.1))
                    await MainActor.run { withAnimation { showAIResult = false }; aiBatterPhase = "ready" }
                }
            }
            await MainActor.run {
                if inning >= INNINGS { phase = .result } else { inning += 1; phase = .inningBreak }
            }
        }
    }

    /// Switch to fielding phase, animate ball to a random zone, wait for player response.
    /// Returns true if player successfully caught the ball.
    private func triggerFieldingPhase(grounder: Bool) async -> Bool {
        let targetZone = Int.random(in: 0...2)
        let window = grounder ? 0.8 : 1.5

        await MainActor.run {
            fieldingZone = targetZone
            ballTrajectory = 0
            fieldingWindow = false
            fieldingSuccess = nil
            isGrounder = grounder
            phase = .fielding
        }

        // Animate ball arc (0→1 over ~0.8s)
        let arcSteps = 48
        for step in 0..<arcSteps {
            try? await Task.sleep(nanoseconds: 16_666_667)
            let prog = CGFloat(step + 1) / CGFloat(arcSteps)
            await MainActor.run { ballTrajectory = prog }
        }

        // Open fielding window
        await MainActor.run { fieldingWindow = true }

        // Wait for tap or timeout
        let tickNs: UInt64 = 50_000_000
        let ticks = Int(window / 0.05)
        for _ in 0..<ticks {
            try? await Task.sleep(nanoseconds: tickNs)
            if await MainActor.run(body: { fieldingSuccess != nil }) { break }
        }

        // Close window if player didn't tap
        let caught = await MainActor.run { () -> Bool in
            if fieldingSuccess == nil {
                fieldingSuccess = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            fieldingWindow = false
            return fieldingSuccess == true
        }

        // Show result briefly then return to pitching
        try? await Task.sleep(for: .seconds(1.1))
        return caught
    }

    private func handleFieldingTap(zone: Int) {
        guard fieldingWindow, fieldingSuccess == nil else { return }
        if zone == fieldingZone {
            fieldingSuccess = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            fieldingSuccess = false
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        fieldingWindow = false
    }

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

    private func grantRewards(winner: ResultScreen.ResultWinner, shards: Int) {
        guard !rewardGranted else { return }
        rewardGranted = true
        GameResultService.saveResult(modeId: "baseball", userScore: playerScore, opponentScore: aiScore)
        viewModel.profile.evolutionShards += shards
        let xpGain = min(XP_CAP_PER_SESSION, shards * 2)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) / 100.0)
    }
}
