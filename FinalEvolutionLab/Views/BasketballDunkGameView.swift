import SwiftUI
import UIKit

// MARK: - Types

private struct DunkStyle: Identifiable {
    let id: String
    let name: String
    let icon: String
    let difficulty: Double
    let swipeHint: String
    let crowdPeak: Double

    static let all: [DunkStyle] = [
        DunkStyle(id: "power_slam",   name: "Power Slam",   icon: "bolt.fill",
                  difficulty: 0.55, swipeHint: "POWER UP",    crowdPeak: 0.75),
        DunkStyle(id: "windmill",     name: "Windmill",     icon: "wind",
                  difficulty: 0.80, swipeHint: "SPIN IT",     crowdPeak: 0.90),
        DunkStyle(id: "three_sixty",  name: "360",          icon: "arrow.trianglehead.2.clockwise.rotate.90",
                  difficulty: 0.85, swipeHint: "FULL SPIN",   crowdPeak: 0.92),
        DunkStyle(id: "tomahawk",     name: "Tomahawk",     icon: "flame.fill",
                  difficulty: 0.70, swipeHint: "SLAM DOWN",   crowdPeak: 0.82),
        DunkStyle(id: "alley_oop",    name: "Alley-Oop",    icon: "person.2.fill",
                  difficulty: 0.75, swipeHint: "CATCH & JAM", crowdPeak: 0.88),
        DunkStyle(id: "reverse",      name: "Reverse",      icon: "arrow.uturn.backward",
                  difficulty: 0.72, swipeHint: "REVERSE IT",  crowdPeak: 0.83),
        DunkStyle(id: "between_legs", name: "Between-Legs", icon: "arrow.down.forward.and.arrow.up.backward",
                  difficulty: 0.90, swipeHint: "THREAD IT",   crowdPeak: 0.96),
    ]
}

private struct RoundResult {
    let round: Int
    let style: DunkStyle
    let j1: Int; let j2: Int; let j3: Int
    let total: Int
    let message: String
    let isPerfect: Bool
    let aiScore: Int
    let playerWon: Bool
}

private enum DunkGamePhase {
    case ready, styleSelect, approach, execution, judgeReveal, roundTransition, result
}

private let TOTAL_ROUNDS = 3

// MARK: - Court Canvas

private struct DunkCourtCanvas: View {
    let phase: DunkGamePhase
    let powerLevel: Double
    let execProgress: Double
    let crowdLevel: Double
    let isPerfect: Bool
    let postDunk: Bool
    let selectedStyleName: String
    var isSceneBacked: Bool = false

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = CourtDraw(size: size, t: t, phase: phase,
                                  power: powerLevel, exec: execProgress,
                                  crowd: crowdLevel, perfect: isPerfect,
                                  postDunk: postDunk, styleName: selectedStyleName,
                                  sceneBacked: isSceneBacked)
                d.render(into: &ctx)
            }
        }
    }
}

// MARK: - CourtDraw

private struct CourtDraw {
    let size: CGSize; let t: Double
    let phase: DunkGamePhase
    let power: Double; let exec: Double
    let crowd: Double; let perfect: Bool; let postDunk: Bool
    let styleName: String
    var sceneBacked: Bool = false

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    var floorY: CGFloat { H * 0.82 }
    var poleX:  CGFloat { W * 0.80 }
    var bbTopY: CGFloat { H * 0.18 }
    var rimY:   CGFloat { H * 0.46 }
    var rimL:   CGFloat { W * 0.63 }
    var rimR:   CGFloat { W * 0.79 }

    var playerProgress: CGFloat {
        switch phase {
        case .approach:    return CGFloat(power / 100.0) * 0.50
        case .execution:   return 0.50 + CGFloat(exec) * 0.20
        default:           return postDunk ? 0.72 : 0.50
        }
    }
    var playerX: CGFloat { W * (0.10 + playerProgress * 0.70) }

    var jumpH: CGFloat {
        guard phase == .execution else { return 0 }
        if exec < 0.15 { return -H * 0.025 * CGFloat(exec / 0.15) }
        let liftExec = (exec - 0.15) / 0.85
        let arc = liftExec < 0.55 ? sin(liftExec / 0.55 * .pi * 0.92) : max(0, sin(liftExec / 0.55 * .pi * 0.92))
        return H * CGFloat(arc) * 0.44
    }

    var shadowScale: CGFloat {
        guard phase == .execution else { return 1.0 }
        let rise = jumpH / (H * 0.44)
        return max(0.3, 1.0 - rise * 0.65)
    }
    var footY: CGFloat { floorY - jumpH }

    mutating func render(into ctx: inout GraphicsContext) {
        drawCourtBG(ctx: &ctx)
        drawArena(ctx: &ctx)
        drawPlayerShadow(ctx: &ctx)
        drawBasket(ctx: &ctx)
        drawScoreDisplay(ctx: &ctx)
        drawAtmosphere(ctx: &ctx)
        drawBallTrail(ctx: &ctx)
        drawBall(ctx: &ctx)
        drawPlayer(ctx: &ctx)
        if phase == .execution && exec > 0.78 { drawDunkFX(ctx: &ctx) }
        if perfect && postDunk { drawSparkles(ctx: &ctx) }
    }

    // MARK: - Scene 1: Court BG (#1-#10)

    private func drawCourtBG(ctx: inout GraphicsContext) {
        // #1 Deep arena dark background fill — skipped when CourtSceneView provides the background
        if !sceneBacked {
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(red: 0.01, green: 0.03, blue: 0.09)))
        }

        // #2 NBA hardwood floor base rectangle
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: W, height: H - floorY)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.62, green: 0.38, blue: 0.12),
                        Color(red: 0.44, green: 0.26, blue: 0.08)
                    ]),
                    startPoint: CGPoint(x: W / 2, y: floorY),
                    endPoint: CGPoint(x: W / 2, y: H)
                 ))

        // #3–#12 Ten hardwood floor plank lines
        for i in 0..<10 {
            let py = floorY + CGFloat(i + 1) * ((H - floorY) / 11.0)
            var plank = Path()
            plank.move(to: CGPoint(x: 0, y: py))
            plank.addLine(to: CGPoint(x: W, y: py))
            ctx.stroke(plank, with: .color(Color(red: 0.52, green: 0.30, blue: 0.08).opacity(0.45)), lineWidth: 0.7)
        }
        // (counts as #3 through #12 — 10 plank lines)

        // #13 Center-court logo circle outer ring
        var centerCircle = Path()
        centerCircle.addEllipse(in: CGRect(x: W * 0.38, y: floorY + 4, width: W * 0.24, height: 28))
        ctx.stroke(centerCircle, with: .color(Color.white.opacity(0.18)), lineWidth: 1.5)

        // #14 Center-court logo inner fill
        var centerFill = Path()
        centerFill.addEllipse(in: CGRect(x: W * 0.44, y: floorY + 8, width: W * 0.12, height: 20))
        ctx.fill(centerFill, with: .color(Color(red: 0.15, green: 0.40, blue: 0.85).opacity(0.30)))

        // #15 Painted lane (key) left boundary
        var laneLeft = Path()
        laneLeft.move(to: CGPoint(x: 0, y: floorY))
        laneLeft.addLine(to: CGPoint(x: 0, y: H))
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: rimR + 14, height: H - floorY)),
                 with: .color(Color(red: 0.60, green: 0.30, blue: 0.08).opacity(0.22)))

        // #16 Lane boundary line
        var laneLine = Path()
        laneLine.move(to: CGPoint(x: rimR + 14, y: floorY))
        laneLine.addLine(to: CGPoint(x: rimR + 14, y: H))
        ctx.stroke(laneLine, with: .color(Color.white.opacity(0.18)), lineWidth: 1.2)

        // #17 Free-throw line
        var ftLine = Path()
        ftLine.move(to: CGPoint(x: 0, y: floorY + 10))
        ftLine.addLine(to: CGPoint(x: rimR + 14, y: floorY + 10))
        ctx.stroke(ftLine, with: .color(Color.white.opacity(0.14)), lineWidth: 1.0)

        // #18 Three-point arc on floor
        var threeArc = Path()
        threeArc.addArc(center: CGPoint(x: poleX - 2, y: floorY),
                        radius: W * 0.28,
                        startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        ctx.stroke(threeArc, with: .color(Color.white.opacity(0.12)), lineWidth: 1.0)

        // #19 Baseline (back court line)
        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: floorY))
        baseline.addLine(to: CGPoint(x: W, y: floorY))
        ctx.stroke(baseline, with: .color(Color.white.opacity(0.20)), lineWidth: 1.8)

        // #20 Floor glow under rim
        var rimGlow = Path()
        rimGlow.addEllipse(in: CGRect(x: rimL - 10, y: floorY, width: (rimR - rimL) + 20, height: 14))
        ctx.fill(rimGlow, with: .color(Color.orange.opacity(0.12 + 0.06 * sin(t * 2.0))))

        // #21 Shot clock pole (vertical line on right side)
        var shotClockPole = Path()
        shotClockPole.move(to: CGPoint(x: W * 0.94, y: floorY))
        shotClockPole.addLine(to: CGPoint(x: W * 0.94, y: H * 0.28))
        ctx.stroke(shotClockPole, with: .color(Color.white.opacity(0.20)), lineWidth: 2.5)

        // #22 Shot clock box at top of pole
        var shotBox = Path()
        shotBox.addRoundedRect(in: CGRect(x: W * 0.90, y: H * 0.28, width: W * 0.08, height: H * 0.05),
                               cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(shotBox, with: .color(Color.black.opacity(0.7)))
        ctx.stroke(shotBox, with: .color(Color.orange.opacity(0.6)), lineWidth: 1.0)

        // #23 Shot clock LED digits (static "24")
        var digitL = Path()
        digitL.addRect(CGRect(x: W * 0.912, y: H * 0.293, width: 4, height: 2))
        ctx.fill(digitL, with: .color(Color.orange.opacity(0.80)))

        // #24 Mid-court hash mark
        var hash = Path()
        hash.move(to: CGPoint(x: W * 0.50, y: floorY))
        hash.addLine(to: CGPoint(x: W * 0.50, y: floorY + 8))
        ctx.stroke(hash, with: .color(Color.white.opacity(0.22)), lineWidth: 1.5)
    }

    // MARK: - Scene 2: Arena (#25–#48)

    private func drawArena(ctx: inout GraphicsContext) {
        // #25 Arena ceiling / upper dark band — skipped when 3D scene provides sky
        if !sceneBacked {
            ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.06)),
                     with: .color(Color(red: 0.00, green: 0.01, blue: 0.04)))
        }

        // #26–#30 Six overhead arena light cones
        for li in 0..<6 {
            let lx = W * (CGFloat(li) + 0.5) / 6.0
            let coneW = W * 0.18
            var cone = Path()
            cone.move(to: CGPoint(x: lx, y: 0))
            cone.addLine(to: CGPoint(x: lx - coneW / 2, y: floorY * 0.92))
            cone.addLine(to: CGPoint(x: lx + coneW / 2, y: floorY * 0.92))
            cone.closeSubpath()
            let flicker = 0.025 + 0.010 * sin(t * 3.7 + Double(li) * 1.1)
            ctx.fill(cone, with: .color(Color.white.opacity(flicker)))

            // #31 Light bulb circle at each cone apex
            var bulb = Path()
            bulb.addEllipse(in: CGRect(x: lx - 4, y: -2, width: 8, height: 8))
            var gc = ctx; gc.addFilter(.blur(radius: 4))
            gc.fill(bulb, with: .color(Color.white.opacity(0.55)))
            ctx.fill(bulb, with: .color(Color.white.opacity(0.9)))
        }

        // #32–#38 Crowd background bands and silhouettes — skipped when 3D Venice environment handles these
        if !sceneBacked {
            // #32 Crowd tier 1 background band
            ctx.fill(Path(CGRect(x: 0, y: H * 0.06, width: W, height: H * 0.08)),
                     with: .color(Color(red: 0.04, green: 0.06, blue: 0.14)))

            // #33 Crowd tier 2 background band
            ctx.fill(Path(CGRect(x: 0, y: H * 0.14, width: W, height: H * 0.08)),
                     with: .color(Color(red: 0.05, green: 0.07, blue: 0.16)))

            // #34 Crowd tier 3 background band
            ctx.fill(Path(CGRect(x: 0, y: H * 0.22, width: W, height: H * 0.08)),
                     with: .color(Color(red: 0.06, green: 0.08, blue: 0.18)))

            // #35–#37 Three rows of crowd silhouettes (35+ silhouettes across all rows)
            drawCrowdTier(ctx: &ctx, row: 0, baseY: H * 0.085, count: 16, rowTag: 35)
            drawCrowdTier(ctx: &ctx, row: 1, baseY: H * 0.165, count: 20, rowTag: 36)
            drawCrowdTier(ctx: &ctx, row: 2, baseY: H * 0.255, count: 24, rowTag: 37)

            // #38 Photo flash dots in crowd (random white pops)
            for fi in 0..<12 {
                let flashPhase = sin(t * 4.5 + Double(fi) * 2.1)
                if flashPhase > 0.85 {
                    let fx = W * (CGFloat(fi % 6) + 0.5) / 6.0 + CGFloat(sin(Double(fi) * 3.7)) * W * 0.06
                    let fy = H * 0.06 + CGFloat(fi % 3) * H * 0.09
                    var flash = Path()
                    flash.addEllipse(in: CGRect(x: fx - 4, y: fy - 4, width: 8, height: 8))
                    var gc = ctx; gc.addFilter(.blur(radius: 5))
                    gc.fill(flash, with: .color(Color.white.opacity(0.8)))
                    ctx.fill(flash, with: .color(Color.white.opacity(0.95)))
                }
            }
        }

        // #39 Jumbotron panel (showing competitor name)
        var jumboBG = Path()
        jumboBG.addRoundedRect(in: CGRect(x: W * 0.05, y: H * 0.07, width: W * 0.38, height: H * 0.095),
                               cornerSize: CGSize(width: 5, height: 5))
        ctx.fill(jumboBG, with: .color(Color.black.opacity(0.82)))
        ctx.stroke(jumboBG, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.55)), lineWidth: 1.5)

        // #40 Jumbotron inner screen glow
        var jumbInner = Path()
        jumbInner.addRoundedRect(in: CGRect(x: W * 0.06, y: H * 0.076, width: W * 0.36, height: H * 0.078),
                                 cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(jumbInner, with: .color(Color(red: 0.00, green: 0.20, blue: 0.40).opacity(0.60)))

        // #41 Jumbotron name text bar
        var nameBar = Path()
        nameBar.addRect(CGRect(x: W * 0.065, y: H * 0.116, width: W * 0.35, height: H * 0.025))
        ctx.fill(nameBar, with: .color(Color(red: 0.0, green: 0.55, blue: 1.0).opacity(0.35)))

        // #42 Sideline judges table
        var judgeTable = Path()
        judgeTable.addRoundedRect(in: CGRect(x: W * 0.08, y: floorY - H * 0.032, width: W * 0.40, height: H * 0.032),
                                  cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(judgeTable, with: .color(Color(red: 0.10, green: 0.14, blue: 0.28).opacity(0.85)))
        ctx.stroke(judgeTable, with: .color(Color.white.opacity(0.14)), lineWidth: 0.8)

        // #43 Sponsor board left
        var sponsorL = Path()
        sponsorL.addRect(CGRect(x: W * 0.01, y: floorY - H * 0.05, width: W * 0.06, height: H * 0.038))
        ctx.fill(sponsorL, with: .color(Color(red: 0.80, green: 0.15, blue: 0.10).opacity(0.70)))

        // #44 Sponsor board right
        var sponsorR = Path()
        sponsorR.addRect(CGRect(x: W * 0.93, y: floorY - H * 0.05, width: W * 0.06, height: H * 0.038))
        ctx.fill(sponsorR, with: .color(Color(red: 0.15, green: 0.32, blue: 0.80).opacity(0.70)))

        // #45 Arena score halo pulses during dunk execution
        if phase == .execution {
            let dunkPulse = 0.04 + 0.03 * sin(t * 6.0)
            var halo = Path()
            halo.addEllipse(in: CGRect(x: W * 0.30, y: H * 0.10, width: W * 0.55, height: H * 0.72))
            ctx.fill(halo, with: .color(Color(red: 0.0, green: 0.55, blue: 1.0).opacity(dunkPulse)))
        }

        // #46 Dramatic spotlight cone from upper-left on player
        if phase == .approach || phase == .execution {
            var spot = Path()
            let spotW: CGFloat = W * 0.40
            spot.move(to: CGPoint(x: W * 0.10, y: 0))
            spot.addLine(to: CGPoint(x: playerX - spotW / 2, y: floorY))
            spot.addLine(to: CGPoint(x: playerX + spotW / 2, y: floorY))
            spot.closeSubpath()
            ctx.fill(spot, with: .color(Color.white.opacity(0.018 + 0.008 * sin(t * 0.9))))
        }

        // #47 Spotlight cone from upper-right toward basket
        var spot2 = Path()
        spot2.move(to: CGPoint(x: W * 0.95, y: 0))
        spot2.addLine(to: CGPoint(x: poleX - W * 0.16, y: floorY))
        spot2.addLine(to: CGPoint(x: poleX + W * 0.10, y: floorY))
        spot2.closeSubpath()
        ctx.fill(spot2, with: .color(Color.white.opacity(0.015 + 0.007 * sin(t * 1.1))))

        // #48 Slow-motion vignette edges (dark oval overlay)
        var vignette = Path()
        vignette.addRect(CGRect(origin: .zero, size: size))
        var vigInner = Path()
        vigInner.addEllipse(in: CGRect(x: W * 0.05, y: H * 0.03, width: W * 0.90, height: H * 0.94))
        // Use a blurred dark fill at edges only (simple outer fill, let inner be clear)
        var vc = ctx; vc.addFilter(.blur(radius: 18))
        var vigBorder = Path()
        vigBorder.addRect(CGRect(origin: .zero, size: size))
        // Soften by four corner quadrant fills
        for (cx, cy): (CGFloat, CGFloat) in [(0, 0), (W, 0), (0, H), (W, H)] {
            var corner = Path()
            corner.addEllipse(in: CGRect(x: cx - W * 0.30, y: cy - H * 0.25, width: W * 0.40, height: H * 0.38))
            ctx.fill(corner, with: .color(Color.black.opacity(0.26)))
        }
    }

    // Helper: draw a single crowd tier
    private func drawCrowdTier(ctx: inout GraphicsContext, row: Int, baseY: CGFloat, count: Int, rowTag: Int) {
        for i in 0..<count {
            let px = W * (CGFloat(i) + 0.5) / CGFloat(count)
            let wave = sin(t * 2.5 + Double(i) * 0.55 + Double(row) * 0.8) * crowd * 10
            let py = baseY - CGFloat(wave)
            let r: CGFloat = 4.5 + CGFloat(row) * 0.4
            let alpha = (0.15 + crowd * 0.35) * (1.0 - Double(row) * 0.12)
            let jColor = crowdColor(index: i, row: row)

            var head = Path()
            head.addEllipse(in: CGRect(x: px - r * 0.85, y: py - r * 1.8, width: r * 1.7, height: r * 1.7))
            ctx.fill(head, with: .color(Color(red: 0.88, green: 0.72, blue: 0.58).opacity(alpha * 1.1)))

            var jersey = Path()
            jersey.addRect(CGRect(x: px - r * 0.8, y: py, width: r * 1.6, height: r * 2.0))
            ctx.fill(jersey, with: .color(jColor.opacity(alpha)))

            if crowd > 0.5 {
                let armRaise = CGFloat(crowd - 0.5) * 2.0 * (wave > 0 ? 1 : 0)
                for sign: CGFloat in [-1, 1] {
                    var arm = Path()
                    arm.move(to: CGPoint(x: px + sign * r * 0.6, y: py))
                    arm.addLine(to: CGPoint(x: px + sign * r * 1.6, y: py - r * 1.5 * armRaise))
                    ctx.stroke(arm, with: .color(jColor.opacity(alpha * 0.8)), lineWidth: 1.2)
                }
            }

            // Foam finger silhouette for some fans
            if i % 7 == 0 && crowd > 0.6 {
                let ffx = px + 8
                let ffy = py - r * 3.2
                var foam = Path()
                foam.addRoundedRect(in: CGRect(x: ffx, y: ffy, width: 6, height: 12),
                                    cornerSize: CGSize(width: 2, height: 2))
                ctx.fill(foam, with: .color(Color(red: 0.95, green: 0.80, blue: 0.10).opacity(alpha * 0.85)))
            }
        }
    }

    private func crowdColor(index: Int, row: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.15, green: 0.30, blue: 0.90),
            Color(red: 0.90, green: 0.18, blue: 0.18),
            Color(red: 0.95, green: 0.80, blue: 0.10),
            Color(red: 0.10, green: 0.75, blue: 0.35),
            Color(red: 0.80, green: 0.20, blue: 0.80),
        ]
        return colors[(index * 3 + row * 7) % colors.count]
    }

    // MARK: - Basket Structure (#49–#58)

    private func drawBasket(ctx: inout GraphicsContext) {
        // #49 Pole (vertical support)
        var pole = Path()
        pole.move(to: CGPoint(x: poleX, y: floorY))
        pole.addLine(to: CGPoint(x: poleX, y: bbTopY))
        ctx.stroke(pole, with: .color(Color.white.opacity(0.30)), lineWidth: 3.5)

        // #50 Backboard clear glass rectangle fill
        let bb = CGRect(x: poleX - 6, y: bbTopY, width: 12, height: rimY - bbTopY + 8)
        ctx.fill(Path(bb), with: .color(Color(red: 0.84, green: 0.88, blue: 0.95).opacity(0.60)))

        // #51 Backboard border stroke
        ctx.stroke(Path(bb), with: .color(Color.white.opacity(0.55)), lineWidth: 1.5)

        // #52 Target square (shot guideline box on backboard)
        let sq = CGRect(x: poleX - 13, y: rimY - 24, width: 26, height: 18)
        ctx.stroke(Path(sq), with: .color(Color.red.opacity(0.50)), lineWidth: 1.5)

        // #53 Backboard rattle flash outline when dunk lands
        if phase == .execution && exec > 0.85 {
            let rattleAlpha = sin((exec - 0.85) / 0.15 * .pi) * 0.8
            var rattleGlow = ctx
            rattleGlow.addFilter(.blur(radius: 4))
            rattleGlow.stroke(Path(bb), with: .color(Color.orange.opacity(rattleAlpha)), lineWidth: 4)
            ctx.stroke(Path(bb), with: .color(Color.white.opacity(rattleAlpha * 0.6)), lineWidth: 2)
        }

        // #54 Rim with glow (orange glow filter variant)
        var rim = Path()
        rim.move(to: CGPoint(x: rimL, y: rimY))
        rim.addLine(to: CGPoint(x: rimR, y: rimY))
        var gc = ctx; gc.addFilter(.shadow(color: Color.orange.opacity(0.75), radius: 7))
        gc.stroke(rim, with: .color(Color.orange), lineWidth: 4.5)

        // #55 Rim solid stroke on top
        ctx.stroke(rim, with: .color(Color(red: 0.95, green: 0.55, blue: 0.10)), lineWidth: 3.0)

        // #56–#67 Net: 12 vertical zigzag strands (net sway animation)
        let netDepth: CGFloat = 28
        let swayAmt = postDunk ? CGFloat(sin(t * 8.0) * exp(-max(0, t.truncatingRemainder(dividingBy: 2.0) - 0.1) * 2.5) * 5) : 0
        for i in 0...11 {
            let tf = CGFloat(i) / 11.0
            let nx = rimL + (rimR - rimL) * tf
            let ny = rimY + netDepth * (1 + abs(tf - 0.5) * 0.35)
            var strand = Path()
            strand.move(to: CGPoint(x: nx, y: rimY))
            strand.addLine(to: CGPoint(x: nx + (0.5 - tf) * 5 + swayAmt * (0.5 - tf), y: ny))
            ctx.stroke(strand, with: .color(Color.white.opacity(0.22)), lineWidth: 1.0)
        }

        // #68 Net horizontal rung 1
        var rung1 = Path()
        rung1.move(to: CGPoint(x: rimL + 2, y: rimY + netDepth * 0.28))
        rung1.addLine(to: CGPoint(x: rimR - 2, y: rimY + netDepth * 0.28))
        ctx.stroke(rung1, with: .color(Color.white.opacity(0.14)), lineWidth: 0.8)

        // #69 Net horizontal rung 2
        var rung2 = Path()
        rung2.move(to: CGPoint(x: rimL + 5, y: rimY + netDepth * 0.56))
        rung2.addLine(to: CGPoint(x: rimR - 5, y: rimY + netDepth * 0.56))
        ctx.stroke(rung2, with: .color(Color.white.opacity(0.12)), lineWidth: 0.8)

        // #70 Net horizontal rung 3 (bottom)
        var rung3 = Path()
        rung3.move(to: CGPoint(x: rimL + 8, y: rimY + netDepth * 0.88))
        rung3.addLine(to: CGPoint(x: rimR - 8, y: rimY + netDepth * 0.88))
        ctx.stroke(rung3, with: .color(Color.white.opacity(0.10)), lineWidth: 0.8)
    }

    // MARK: - Player Shadow

    private func drawPlayerShadow(ctx: inout GraphicsContext) {
        let px = playerX
        let sw: CGFloat = 28 * shadowScale
        let sh: CGFloat = 8  * shadowScale
        let shadowAlpha = 0.35 * Double(shadowScale)
        ctx.fill(Path(ellipseIn: CGRect(x: px - sw / 2, y: floorY + 2, width: sw, height: sh)),
                 with: .color(Color.black.opacity(shadowAlpha)))
    }

    // MARK: - Scene 3: Player Figure (#71–#90)

    private func drawPlayer(ctx: inout GraphicsContext) {
        let px = playerX
        let py = footY
        let lw: CGFloat = 4.0
        let headR: CGFloat = 11
        let bodyH: CGFloat = 32

        let cycle = t.truncatingRemainder(dividingBy: 0.48) / 0.48
        let sinC = CGFloat(sin(cycle * .pi * 2))

        let shoulderY = py - bodyH - headR * 1.9
        let hipY      = shoulderY + bodyH

        let bodyColor = Color(red: 0.10, green: 0.85, blue: 1.0)
        let legColor  = Color(red: 0.15, green: 0.20, blue: 0.95)
        let skinColor = Color(red: 0.94, green: 0.81, blue: 0.70)
        let shoeColor = Color(red: 0.92, green: 0.35, blue: 0.08)

        // #71 Jersey body glow halo during execution
        if phase == .execution {
            var halo = Path()
            halo.addEllipse(in: CGRect(x: px - 20, y: shoulderY - headR * 2 - 8,
                                       width: 40, height: bodyH + headR * 4 + 16))
            var gc = ctx; gc.addFilter(.blur(radius: 10))
            gc.fill(halo, with: .color(bodyColor.opacity(0.25)))
        }

        // #72 Head circle (skin tone)
        let headRect = CGRect(x: px - headR, y: shoulderY - headR * 1.85, width: headR * 2, height: headR * 2)
        if phase == .execution {
            var gc = ctx; gc.addFilter(.shadow(color: bodyColor.opacity(0.4), radius: 8))
            gc.fill(Path(ellipseIn: headRect), with: .color(skinColor))
        } else {
            ctx.fill(Path(ellipseIn: headRect), with: .color(skinColor))
        }

        // #73 Head outline stroke
        ctx.stroke(Path(ellipseIn: headRect), with: .color(Color.black.opacity(0.18)), lineWidth: 0.8)

        // #74 Tongue out detail (Jordan-style, only during dunk)
        if phase == .execution, exec > 0.15 {
            let tongueX = px + headR * 0.35
            let tongueY = shoulderY - headR * 0.3
            var tongue = Path()
            tongue.addEllipse(in: CGRect(x: tongueX - 2.5, y: tongueY, width: 5, height: 7))
            ctx.fill(tongue, with: .color(Color(red: 0.90, green: 0.22, blue: 0.22).opacity(0.85)))
        }

        // #75 Torso spine line
        var spine = Path()
        spine.move(to: CGPoint(x: px, y: shoulderY))
        spine.addLine(to: CGPoint(x: px, y: hipY))
        ctx.stroke(spine, with: .color(bodyColor), lineWidth: lw)

        // #76 Jersey number dot (decorative)
        ctx.fill(Path(ellipseIn: CGRect(x: px - 3, y: shoulderY + 8, width: 6, height: 6)),
                 with: .color(Color.white.opacity(0.45)))

        if phase == .execution {
            let ep = CGFloat(exec)
            if ep < 0.15 {
                // Wind-up crouch
                let crouchT = ep / 0.15
                for sign: CGFloat in [1, -1] {
                    // #77 Arm wind-up (both sides)
                    var arm = Path()
                    arm.move(to: CGPoint(x: px, y: shoulderY + 4))
                    arm.addLine(to: CGPoint(x: px + sign * 22, y: shoulderY + 18 + 10 * crouchT))
                    ctx.stroke(arm, with: .color(bodyColor), lineWidth: lw)
                    // #78 Leg crouch (deeply bent)
                    var leg = Path()
                    leg.move(to: CGPoint(x: px, y: hipY))
                    leg.addLine(to: CGPoint(x: px + sign * 20, y: hipY + 12))
                    leg.addLine(to: CGPoint(x: px + sign * 12, y: hipY + 22))
                    ctx.stroke(leg, with: .color(legColor), lineWidth: lw)
                    // #79 Shoe bands (crouch)
                    ctx.fill(Path(CGRect(x: px + sign * 8, y: hipY + 20, width: sign * 10, height: 5)),
                             with: .color(shoeColor))
                    // #80 Shoe sole stripe
                    var sole = Path()
                    sole.addRect(CGRect(x: px + sign * 8, y: hipY + 24, width: sign * 10, height: 2))
                    ctx.fill(sole, with: .color(Color.white.opacity(0.40)))
                }
            } else {
                let liftT = (ep - 0.15) / 0.85
                // #81 Dunking arm swing (dominant, reaches toward rim)
                let angle: CGFloat = -.pi * 0.10 - liftT * .pi * 0.75
                let aex = px + cos(angle) * 40
                let aey = shoulderY + sin(angle) * 40
                var arm = Path()
                arm.move(to: CGPoint(x: px, y: shoulderY + 4))
                arm.addLine(to: CGPoint(x: aex, y: aey))
                var gc = ctx; gc.addFilter(.shadow(color: bodyColor.opacity(0.5), radius: 6))
                gc.stroke(arm, with: .color(bodyColor), lineWidth: lw + 1)
                ctx.stroke(arm, with: .color(bodyColor), lineWidth: lw)

                // #82 Off-arm trailing behind
                var arm2 = Path()
                arm2.move(to: CGPoint(x: px, y: shoulderY + 4))
                arm2.addLine(to: CGPoint(x: px - 24, y: shoulderY + 24 + liftT * 10))
                ctx.stroke(arm2, with: .color(bodyColor), lineWidth: lw)

                // #83 Reach extension dot at palm (ball-grip indicator)
                ctx.fill(Path(ellipseIn: CGRect(x: aex - 4, y: aey - 4, width: 8, height: 8)),
                         with: .color(skinColor.opacity(0.9)))

                let tuck = min(1.0, liftT * 1.3)
                for sign: CGFloat in [1, -1] {
                    // #84 Legs tucked for hangtime
                    var leg = Path()
                    leg.move(to: CGPoint(x: px, y: hipY))
                    leg.addLine(to: CGPoint(x: px + sign * 16, y: hipY + 10 - tuck * 18))
                    leg.addLine(to: CGPoint(x: px + sign * 8,  y: hipY + 22 - tuck * 28))
                    ctx.stroke(leg, with: .color(legColor), lineWidth: lw)
                    // #85 Sneaker color band (tuck)
                    ctx.fill(Path(CGRect(x: px + sign * 5, y: hipY + 20 - tuck * 28, width: sign * 10, height: 5)),
                             with: .color(shoeColor))
                    // #86 Sneaker sole stripe (tuck)
                    ctx.fill(Path(CGRect(x: px + sign * 5, y: hipY + 24 - tuck * 28, width: sign * 10, height: 2)),
                             with: .color(Color.white.opacity(0.38)))
                }
            }
        } else if phase == .approach {
            for sign: CGFloat in [1, -1] {
                // #87 Running arm swing
                var arm = Path()
                arm.move(to: CGPoint(x: px, y: shoulderY + 5))
                arm.addLine(to: CGPoint(x: px + sign * 22 * sinC, y: shoulderY + 22))
                ctx.stroke(arm, with: .color(bodyColor), lineWidth: lw)
                // #88 Running leg stride
                var leg = Path()
                leg.move(to: CGPoint(x: px, y: hipY))
                leg.addLine(to: CGPoint(x: px + sign * 18 * sinC, y: hipY + 20))
                leg.addLine(to: CGPoint(x: px + sign * 10 * sinC, y: py - 1))
                ctx.stroke(leg, with: .color(legColor), lineWidth: lw)
                // #89 Running shoe
                ctx.fill(Path(CGRect(x: px + sign * 7 * sinC, y: py - 5, width: sign * 12, height: 5)),
                         with: .color(shoeColor))
            }
        } else {
            let idleRock = CGFloat(sin(t * 1.4) * 2)
            for sign: CGFloat in [1, -1] {
                // #90 Idle arm
                var arm = Path()
                arm.move(to: CGPoint(x: px, y: shoulderY + 4))
                arm.addLine(to: CGPoint(x: px + sign * 18 + idleRock, y: hipY - 3))
                ctx.stroke(arm, with: .color(bodyColor), lineWidth: lw)
                var leg = Path()
                leg.move(to: CGPoint(x: px, y: hipY))
                leg.addLine(to: CGPoint(x: px + sign * 8 + idleRock * 0.5, y: py - 1))
                ctx.stroke(leg, with: .color(legColor), lineWidth: lw)
                ctx.fill(Path(CGRect(x: px + sign * 5 + idleRock * 0.5, y: py - 5, width: sign * 12, height: 5)),
                         with: .color(shoeColor))
            }
        }
    }

    // MARK: - Scene 4: Dunk FX (#91–#108)

    private func drawDunkFX(ctx: inout GraphicsContext) {
        let cx = (rimL + rimR) / 2
        let cy = rimY
        let impactFrac = CGFloat((exec - 0.78) / 0.22)
        let burstR = impactFrac * 38

        // #91 Takeoff dust burst: 8 particles near player feet
        if exec < 0.90 {
            let dustX = playerX
            let dustY = floorY
            for di in 0..<8 {
                let angle = Double(di) * .pi / 4.0 + t * 0.5
                let dustR = CGFloat(di % 3 + 1) * 1.5
                let dist  = CGFloat(impactFrac) * 22 + CGFloat(di) * 2
                let dx = dustX + CGFloat(cos(angle)) * dist
                let dy = dustY - CGFloat(abs(sin(angle))) * dist * 0.5
                var dust = Path()
                dust.addEllipse(in: CGRect(x: dx - dustR, y: dy - dustR, width: dustR * 2, height: dustR * 2))
                ctx.fill(dust, with: .color(Color(red: 0.80, green: 0.60, blue: 0.30)
                    .opacity(Double(max(0, 1.0 - impactFrac * 1.6) * 0.55))))
            }
        }

        // #92 Hangtime glow ring around player during apex
        if exec > 0.30 && exec < 0.75 {
            let glowR = CGFloat(22 + sin(t * 8.0) * 3)
            var glowRing = Path()
            glowRing.addEllipse(in: CGRect(x: playerX - glowR, y: footY - glowR * 0.6,
                                            width: glowR * 2, height: glowR * 1.2))
            var gc = ctx; gc.addFilter(.blur(radius: 8))
            gc.stroke(glowRing, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.45)), lineWidth: 4)
        }

        // #93 Expanding rim impact ring
        var ring = Path()
        ring.addEllipse(in: CGRect(x: cx - burstR, y: cy - burstR * 0.5, width: burstR * 2, height: burstR))
        ctx.stroke(ring, with: .color(Color.orange.opacity(Double(max(0, 0.85 - impactFrac * 0.9)))), lineWidth: 2.5)

        // #94 Secondary ring (larger, softer)
        var ring2 = Path()
        ring2.addEllipse(in: CGRect(x: cx - burstR * 1.4, y: cy - burstR * 0.7,
                                    width: burstR * 2.8, height: burstR * 1.4))
        var gc2 = ctx; gc2.addFilter(.blur(radius: 3))
        gc2.stroke(ring2, with: .color(Color.orange.opacity(Double(max(0, 0.5 - impactFrac * 0.6)))), lineWidth: 1.5)

        // #95–#98 Four primary rim slam impact rays
        for i in 0..<4 {
            let angle = Double(i) * .pi / 2.0 + .pi / 4.0
            let rayLen = burstR * 1.1
            let rx = cx + CGFloat(cos(angle)) * rayLen
            let ry = cy + CGFloat(sin(angle)) * rayLen * 0.4
            var ray = Path()
            ray.move(to: CGPoint(x: cx, y: cy))
            ray.addLine(to: CGPoint(x: rx, y: ry))
            ctx.stroke(ray, with: .color(Color.yellow.opacity(Double(max(0, 0.75 - impactFrac * 0.85)))),
                       lineWidth: 2.0)
        }

        // #99 Eight radial sparks (thinner secondary rays)
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4.0 + t * 1.2
            let sparkLen = burstR * 0.70
            let sx = cx + CGFloat(cos(angle)) * sparkLen
            let sy = cy + CGFloat(sin(angle)) * sparkLen * 0.4
            var spark = Path()
            spark.move(to: CGPoint(x: cx, y: cy))
            spark.addLine(to: CGPoint(x: sx, y: sy))
            ctx.stroke(spark, with: .color(Color.yellow.opacity(Double(max(0, 0.60 - impactFrac * 0.75)))),
                       lineWidth: 1.2)
        }

        // #100 Rim shake offset visual (jitter the rim glow)
        let shakeX = CGFloat(sin(t * 45.0) * 2.5 * Double(max(0, 1.0 - impactFrac * 2.0)))
        var shakeRim = Path()
        shakeRim.move(to: CGPoint(x: rimL + shakeX, y: rimY))
        shakeRim.addLine(to: CGPoint(x: rimR + shakeX, y: rimY))
        var gc3 = ctx; gc3.addFilter(.blur(radius: 3))
        gc3.stroke(shakeRim, with: .color(Color.white.opacity(0.35 * Double(max(0, 1.0 - impactFrac)))), lineWidth: 5)

        // #101–#112 Twelve crowd photo flashes during rim contact
        if impactFrac > 0.3 {
            for fi in 0..<12 {
                let flashBeat = sin(t * 6.0 + Double(fi) * 1.9)
                if flashBeat > 0.75 {
                    let fx = W * (CGFloat(fi % 6) + 0.5) / 6.0
                    let fy = H * (0.06 + CGFloat(fi % 3) * 0.09)
                    var flash = Path()
                    flash.addEllipse(in: CGRect(x: fx - 5, y: fy - 5, width: 10, height: 10))
                    var gcf = ctx; gcf.addFilter(.blur(radius: 6))
                    gcf.fill(flash, with: .color(Color.white.opacity(0.70)))
                    ctx.fill(flash, with: .color(Color.white.opacity(0.95)))
                }
            }
        }
    }

    // MARK: - Scene 5: Score Display (#113–#122)

    private func drawScoreDisplay(ctx: inout GraphicsContext) {
        guard phase == .judgeReveal || postDunk else { return }

        // #113–#117 Five judge score cards at bottom
        for ji in 0..<5 {
            let cardX = W * (CGFloat(ji) + 0.5) / 5.0 - 14
            let cardY = floorY + 2
            var card = Path()
            card.addRoundedRect(in: CGRect(x: cardX, y: cardY, width: 28, height: 36),
                                cornerSize: CGSize(width: 3, height: 3))
            let isHighlight = ji == 2 && perfect
            ctx.fill(card, with: .color(isHighlight
                ? Color(red: 1.0, green: 0.82, blue: 0.0).opacity(0.82)
                : Color(red: 0.08, green: 0.12, blue: 0.25).opacity(0.88)))
            ctx.stroke(card, with: .color(isHighlight
                ? Color.yellow
                : Color.white.opacity(0.18)), lineWidth: isHighlight ? 1.5 : 0.8)
        }

        // #118 Perfect-10 gold card highlight glow
        if perfect {
            let cx = W * 3.0 / 5.0
            var goldGlow = Path()
            goldGlow.addEllipse(in: CGRect(x: cx - 22, y: floorY - 2, width: 44, height: 44))
            var gc = ctx; gc.addFilter(.blur(radius: 10))
            gc.fill(goldGlow, with: .color(Color.yellow.opacity(0.55)))
        }

        // #119 Crowd reaction meter bar background
        var meterBG = Path()
        meterBG.addRoundedRect(in: CGRect(x: W * 0.08, y: H * 0.895, width: W * 0.84, height: 8),
                               cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(meterBG, with: .color(Color.white.opacity(0.08)))

        // #120 Crowd reaction meter fill
        var meterFill = Path()
        meterFill.addRoundedRect(in: CGRect(x: W * 0.08, y: H * 0.895, width: W * 0.84 * crowd, height: 8),
                                 cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(meterFill, with: .linearGradient(
            Gradient(colors: [Color(red: 0.0, green: 0.55, blue: 1.0),
                              Color(red: 0.0, green: 1.0, blue: 0.80),
                              Color.yellow.opacity(0.9)]),
            startPoint: CGPoint(x: W * 0.08, y: H * 0.90),
            endPoint: CGPoint(x: W * 0.92, y: H * 0.90)
        ))

        // #121 Dunk name banner (glowing pill)
        var bannerPill = Path()
        bannerPill.addRoundedRect(in: CGRect(x: W * 0.25, y: H * 0.870, width: W * 0.50, height: 20), cornerSize: CGSize(width: 10, height: 10))
        var gcBanner = ctx; gcBanner.addFilter(.blur(radius: 6))
        gcBanner.fill(bannerPill, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.40)))
        ctx.fill(bannerPill, with: .color(Color(red: 0.02, green: 0.10, blue: 0.22).opacity(0.78)))
        ctx.stroke(bannerPill, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.45)), lineWidth: 1.0)

        // #122 Announcer voice wave bars (5 bars, animated height)
        for bi in 0..<5 {
            let bx = W * 0.36 + CGFloat(bi) * 10
            let barH = CGFloat(6 + abs(sin(t * 8.0 + Double(bi) * 0.8)) * 8)
            var bar = Path()
            bar.addRect(CGRect(x: bx, y: H * 0.875 - barH / 2, width: 4, height: barH))
            ctx.fill(bar, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.70)))
        }
    }

    // MARK: - Scene 6: Atmosphere (#123–#136)

    private func drawAtmosphere(ctx: inout GraphicsContext) {
        // #123–#162 Forty confetti particles on high score (crowd >= 0.75)
        if crowd >= 0.75 || (perfect && postDunk) {
            for ci in 0..<40 {
                let angle = Double(ci) * 9.0 * (.pi / 180.0) + t * (Double(ci % 3 == 0 ? 1.0 : -0.7))
                let radius = W * 0.40 + CGFloat(sin(t * 1.2 + Double(ci) * 0.4)) * W * 0.20
                let confX = W / 2 + CGFloat(cos(angle)) * radius * 0.80
                let confY = H * 0.50 + CGFloat(sin(angle)) * H * 0.38
                    - CGFloat(fmod(t * 35 + Double(ci) * 8, Double(H * 0.80)))
                let confColors: [Color] = [.red, .yellow, .green, .cyan, .orange, .purple, .white]
                let confColor = confColors[ci % confColors.count]
                let confW: CGFloat = ci % 2 == 0 ? 5 : 3
                let confH: CGFloat = ci % 3 == 0 ? 10 : 6
                var gc = ctx; gc.translateBy(x: confX, y: max(0, confY))
                var conf = Path()
                conf.addRect(CGRect(x: -confW / 2, y: -confH / 2, width: confW, height: confH))
                gc.fill(conf, with: .color(confColor.opacity(0.82)))
            }
        }

        // #163 Wide slow-motion vignette inner glow center during execution
        if phase == .execution {
            var centerGlow = Path()
            centerGlow.addEllipse(in: CGRect(x: W * 0.20, y: H * 0.15, width: W * 0.60, height: H * 0.65))
            var gc = ctx; gc.addFilter(.blur(radius: 20))
            gc.fill(centerGlow, with: .color(Color(red: 0.0, green: 0.40, blue: 0.90).opacity(0.06 + 0.03 * sin(t * 3.0))))
        }

        // #164 Atmospheric rim reflection on floor
        var reflection = Path()
        reflection.addEllipse(in: CGRect(x: rimL - 16, y: floorY + 2, width: (rimR - rimL) + 32, height: 18))
        var gcRef = ctx; gcRef.addFilter(.blur(radius: 5))
        gcRef.fill(reflection, with: .color(Color.orange.opacity(0.14 + 0.06 * sin(t * 1.8))))
    }

    // MARK: - Ball Trail

    private func drawBallTrail(ctx: inout GraphicsContext) {
        guard phase == .execution, exec > 0.20 else { return }
        let r: CGFloat = 7
        let ex = (rimL + rimR) / 2; let ey = rimY - 6
        for trail in 1...4 {
            let pastExec = max(0.20, exec - Double(trail) * 0.055)
            let pastLift = (pastExec - 0.15) / 0.85
            let pastArc = pastLift < 0.55
                ? sin(pastLift / 0.55 * .pi * 0.92)
                : max(0.0, sin(pastLift / 0.55 * .pi * 0.92))
            let pastJumpH = H * CGFloat(pastArc) * 0.44
            let pastPlayerX = W * (0.10 + (0.50 + CGFloat(pastExec) * 0.20) * 0.70)
            let pastFootY = floorY - pastJumpH
            let sx = pastPlayerX + 14; let sy = pastFootY - pastJumpH - 36
            let ep = CGFloat(pastExec)
            let trailBx = sx + (ex - sx) * ep
            let trailBy = sy + (ey - sy) * ep - H * 0.22 * 4 * ep * (1 - ep)
            let alpha = 0.28 - Double(trail) * 0.055
            ctx.fill(Path(ellipseIn: CGRect(x: trailBx - r, y: trailBy - r, width: r * 2, height: r * 2)),
                     with: .color(Color.orange.opacity(alpha)))
        }
    }

    // MARK: - Ball

    private func drawBall(ctx: inout GraphicsContext) {
        let r: CGFloat = 8
        let bx: CGFloat; let by: CGFloat
        switch phase {
        case .approach:
            let bounce = abs(sin(t * .pi / 0.48)) * 14
            bx = playerX + 14; by = footY - CGFloat(bounce) - 10
        case .execution:
            let ep = CGFloat(exec)
            let sx = playerX + 14; let sy = footY - jumpH - 36
            let ex = (rimL + rimR) / 2; let ey = rimY - 6
            bx = sx + (ex - sx) * ep
            by = sy + (ey - sy) * ep - H * 0.22 * 4 * ep * (1 - ep)
        default:
            bx = postDunk ? (rimL + rimR) / 2 : playerX + 14
            by = postDunk ? rimY + 30          : footY - 12
        }
        var bc = ctx; bc.addFilter(.shadow(color: Color.orange.opacity(0.55), radius: 5))
        bc.fill(Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
                with: .color(Color.orange))
        var seam = Path()
        seam.addArc(center: CGPoint(x: bx, y: by), radius: r * 0.76,
                    startAngle: .degrees(-40), endAngle: .degrees(200), clockwise: false)
        ctx.stroke(seam, with: .color(Color.black.opacity(0.28)), lineWidth: 1.0)
    }

    // MARK: - Sparkles (perfect score)

    private func drawSparkles(ctx: inout GraphicsContext) {
        let cx = (rimL + rimR) / 2; let cy = rimY - 18
        for i in 0..<20 {
            let angle = Double(i) / 20.0 * .pi * 2 + t * 2.1
            let dist  = 28 + sin(t * 3.8 + Double(i)) * 16
            let sx = cx + CGFloat(cos(angle)) * CGFloat(dist)
            let sy = cy + CGFloat(sin(angle)) * CGFloat(dist)
            let alpha = 0.6 + 0.4 * abs(sin(t * 5.0 + Double(i) * 0.7))
            let sparkColor: Color = i % 3 == 0 ? .white : (i % 3 == 1 ? .yellow : .orange)
            var sc = ctx; sc.addFilter(.shadow(color: sparkColor.opacity(0.6), radius: 5))
            sc.fill(Path(ellipseIn: CGRect(x: sx - 3, y: sy - 3, width: 6, height: 6)),
                    with: .color(sparkColor.opacity(alpha)))
        }
    }
}

// MARK: - Main View

struct BasketballDunkGameView: View {
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss

    private let accent = Theme.brandCyan

    // Haptic generators
    private let impactMed    = UIImpactFeedbackGenerator(style: .medium)
    private let impactHvy    = UIImpactFeedbackGenerator(style: .heavy)
    private let impactRigid  = UIImpactFeedbackGenerator(style: .rigid)
    private let impactSoft   = UIImpactFeedbackGenerator(style: .soft)
    private let notifyGen    = UINotificationFeedbackGenerator()

    @State private var phase: DunkGamePhase = .ready
    @State private var currentRound: Int = 1
    @State private var selectedStyle: DunkStyle = DunkStyle.all[0]

    // Approach
    @State private var powerLevel: Double  = 0.0
    @State private var powerFilling        = false
    @State private var powerTask: Task<Void, Never>?
    @State private var approachReleased    = false
    @State private var approachQuality: Double = 0.0
    @State private var hitSweetSpot        = false

    // Execution
    @State private var swipeDragOffset: CGSize = .zero
    @State private var swipeRegistered    = false
    @State private var executionQuality: Double = 0.0
    @State private var swipeFlash         = false
    @State private var execProgress: Double = 0.0
    @State private var execAnimTask: Task<Void, Never>?
    @State private var postDunk           = false

    // Judge
    @State private var judgeScoresRevealed: [Bool] = [false, false, false]
    @State private var judgeRevealTask: Task<Void, Never>?
    @State private var currentJ1 = 0; @State private var currentJ2 = 0; @State private var currentJ3 = 0
    @State private var currentMessage = ""; @State private var isPerfect = false
    @State private var perfectFlash   = false

    // Crowd & scoring
    @State private var crowdLevel: Double = 0.0
    @State private var playerRoundScores: [RoundResult] = []
    @State private var aiRoundScores: [Int]  = []
    @State private var playerTotal: Int = 0; @State private var aiTotal: Int = 0
    @State private var shardsAwarded = false

    // Shake & burst effects
    @State private var shakeX: CGFloat = 0
    @State private var shakeY: CGFloat = 0
    @State private var burstParticles: [(id: Int, x: CGFloat, y: CGFloat, angle: Double, distance: CGFloat, opacity: Double, color: Color)] = []
    @State private var burstCounter: Int = 0

    // MARK: - CourtSceneView backing properties

    private let veniceMovementSig = MovementSignature(
        style: .explosive,
        jumpApex: 0.92,
        hangTimeFactor: 1.25,
        firstStepBurst: 0.80,
        limbEmission: 0.65,
        trailColor: Color(red: 0.0, green: 0.85, blue: 1.0)
    )

    private var sceneAuraLevel: AuraLevel {
        switch phase {
        case .approach:    return .active
        case .execution:   return isPerfect ? .maxIntent : .primed
        case .judgeReveal: return perfectFlash ? .maxIntent : .active
        default:           return .baseline
        }
    }

    private var sceneDunkPhase: DunkPhase {
        switch phase {
        case .ready, .styleSelect, .roundTransition, .result: return .idle
        case .approach:   return powerLevel > 3 ? .approach : .idle
        case .execution:
            if execProgress < 0.30 { return .launch }
            if execProgress < 0.82 { return .airborne }
            return .landing
        case .judgeReveal: return .scored
        }
    }

    private var sceneTrick: DunkTrickSlot {
        switch selectedStyle.id {
        case "windmill":     return .windmill
        case "three_sixty":  return .threeSixty
        case "tomahawk":     return .tomahawk
        case "between_legs": return .betweenLegs
        case "reverse":      return .reverseJam
        case "alley_oop":    return .reverseJam
        default:             return .tomahawk
        }
    }

    var body: some View {
        ZStack {
            // 3D Venice beach environment as the full backdrop
            CourtSceneView(
                neuralDrive: min(1.0, viewModel.effectiveMetrics.prqScore / 100.0),
                verticalPotential: min(1.0, 0.55 + viewModel.effectiveMetrics.prqScore / 200.0),
                auraLevel: sceneAuraLevel,
                movementSignature: veniceMovementSig,
                onDunkTriggered: { },
                dunkPhase: sceneDunkPhase,
                selectedTrick: sceneTrick,
                sprintCharge: powerLevel / 100.0,
                jumpHeight: phase == .execution ? execProgress : 0,
                rotationProgress: phase == .execution ? max(0, (execProgress - 0.30) / 0.70) : 0
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Dark tint to keep 2D gameplay UI readable over the 3D scene
            Color.black.opacity(0.40).ignoresSafeArea()

            Group {
                switch phase {
                case .ready:
                    GetReadyScreen(title: "Dunk Contest", subtitle: "3 rounds · Select style · Impress the judges",
                                   countdown: 3, accentColor: accent, onComplete: { phase = .styleSelect })
                case .styleSelect:    styleSelectScreen
                case .approach:       approachScreen
                case .execution:      executionScreen
                case .judgeReveal:    judgeRevealScreen
                case .roundTransition: roundTransitionOverlay
                case .result:         resultScreen
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
                Button {
                    powerTask?.cancel()
                    execAnimTask?.cancel()
                    judgeRevealTask?.cancel()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accent)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear {
            powerTask?.cancel()
            execAnimTask?.cancel()
            judgeRevealTask?.cancel()
        }
    }

    // MARK: - Court canvas (shared across phases)

    private var courtCanvas: some View {
        DunkCourtCanvas(phase: phase, powerLevel: powerLevel, execProgress: execProgress,
                        crowdLevel: crowdLevel, isPerfect: isPerfect, postDunk: postDunk,
                        selectedStyleName: selectedStyle.name, isSceneBacked: true)
            .frame(height: phase == .execution ? 280 : 240)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.14), lineWidth: 1))
            .animation(.easeInOut(duration: 0.3), value: phase == .execution)
    }

    // MARK: - Score header

    private var scoreHeader: some View {
        HStack(spacing: 16) {
            scorePill(label: "YOU", value: "\(playerTotal)", color: accent)
            Spacer()
            Text("ROUND \(currentRound) / \(TOTAL_ROUNDS)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(2)
            Spacer()
            scorePill(label: "KAI NEXUS", value: "\(aiTotal)", color: .red)
        }.padding(.horizontal, 20).padding(.top, 4)
    }

    private func scorePill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 0.5)))
    }

    // MARK: - Style Select

    private var styleSelectScreen: some View {
        VStack(spacing: 0) {
            scoreHeader.padding(.top, 12)
            Spacer().frame(height: 16)
            Text("SELECT YOUR DUNK")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(accent).tracking(4)
            Text("Round \(currentRound)")
                .font(.system(size: 28, weight: .black)).italic().foregroundStyle(.white).padding(.top, 4)
            Spacer().frame(height: 14)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DunkStyle.all) { s in
                        dunkCard(s, selected: selectedStyle.id == s.id).onTapGesture { selectedStyle = s }
                    }
                }.padding(.horizontal, 20).padding(.vertical, 8)
            }
            Spacer().frame(height: 16)
            selectedStyleDetail.padding(.horizontal, 20)
            Spacer()
            Button {
                withAnimation { phase = .approach }
                resetApproach()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "figure.highintensity.intervaltraining")
                    Text("APPROACH THE RIM")
                }
                .font(.system(.subheadline, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(accent)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: accent.opacity(0.35), radius: 12)
            }.padding(.horizontal, 24).padding(.bottom, 32)
        }
    }

    private func dunkCard(_ style: DunkStyle, selected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(selected ? accent.opacity(0.18) : Color.white.opacity(0.04))
                    .frame(width: 54, height: 54)
                Circle()
                    .strokeBorder(selected ? accent : Color.white.opacity(0.08),
                                  lineWidth: selected ? 2 : 0.5)
                    .frame(width: 54, height: 54)
                Image(systemName: style.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(selected ? accent : .white.opacity(0.4))
            }
            Text(style.name)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(selected ? accent : .white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(width: 72)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 84).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(selected ? accent.opacity(0.06) : Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? accent.opacity(0.3) : Theme.cardBorder, lineWidth: 1)))
        .animation(.spring(response: 0.2), value: selected)
    }

    private var selectedStyleDetail: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(accent.opacity(0.12)).frame(width: 52, height: 52)
                Image(systemName: selectedStyle.icon)
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedStyle.name.uppercased())
                    .font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(.white)
                diffBar(difficulty: selectedStyle.difficulty).frame(width: 120)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("CUE").font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(1)
                Text(selectedStyle.swipeHint)
                    .font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(accent)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 0.5)))
    }

    // MARK: - Approach

    private var approachScreen: some View {
        VStack(spacing: 0) {
            scoreHeader.padding(.top, 12)
            courtCanvas.padding(.horizontal, 20).padding(.top, 10)
            styleTag.padding(.top, 12)
            Text("HOLD TO BUILD POWER")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accent.opacity(0.8)).tracking(3).padding(.top, 14)
            Text("Release in the sweet spot (78–90%)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary).padding(.top, 3)
            Spacer().frame(height: 20)
            powerBarView.padding(.horizontal, 24)
            Spacer().frame(height: 28)
            holdButton
            Spacer()
        }
    }

    private var powerBarView: some View {
        GeometryReader { geo in
            let bw = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)).frame(height: 52)
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: powerBarColors(powerLevel),
                                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: bw * CGFloat(powerLevel / 100.0), height: 52)
                    .animation(.linear(duration: 0.05), value: powerLevel)
                let zs = bw * 0.78; let zw = bw * 0.12
                RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.22))
                    .frame(width: zw, height: 52).offset(x: zs)
                Text("●").font(.system(size: 6, weight: .black)).foregroundStyle(Color.green.opacity(0.9))
                    .offset(x: zs + 3, y: 0).frame(maxHeight: .infinity, alignment: .center)
                Text("SWEET SPOT")
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.green.opacity(0.8))
                    .offset(x: zs + 10, y: 0).frame(maxHeight: .infinity, alignment: .center)
                HStack {
                    Spacer()
                    Text(String(format: "%.0f%%", powerLevel))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.white).padding(.trailing, 14)
                }
            }.frame(height: 52)
        }.frame(height: 52)
    }

    private var holdButton: some View {
        ZStack {
            Circle()
                .fill(powerFilling ? accent.opacity(0.15) : Color.white.opacity(0.05))
                .frame(width: 130, height: 130)
            Circle()
                .strokeBorder(powerFilling ? accent : Color.white.opacity(0.18), lineWidth: 3)
                .frame(width: 130, height: 130)
                .scaleEffect(powerFilling ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: powerFilling)
            VStack(spacing: 6) {
                Image(systemName: powerFilling ? "hand.raised.fill" : "hand.tap.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(powerFilling ? accent : .white.opacity(0.5))
                Text(powerFilling ? "RELEASE!" : "HOLD")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(powerFilling ? accent : .white.opacity(0.5)).tracking(2)
            }
        }
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !powerFilling && !approachReleased { startCharge() } }
            .onEnded   { _ in releasePower() })
    }

    // MARK: - Execution

    private var executionScreen: some View {
        VStack(spacing: 0) {
            scoreHeader.padding(.top, 12)
            courtCanvas.padding(.horizontal, 20).padding(.top, 10)
            styleTag.padding(.top, 12)
            Text(selectedStyle.swipeHint)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.5), radius: 16)
                .scaleEffect(swipeFlash ? 1.1 : 1.0)
                .animation(.spring(response: 0.2), value: swipeFlash)
                .padding(.top, 10)
            Text("SWIPE TO EXECUTE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary).tracking(3).padding(.top, 6)
            Spacer().frame(height: 24)
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(accent.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(accent.opacity(swipeRegistered ? 0.7 : 0.2), lineWidth: 2))
                    .frame(width: 200, height: 120)
                    .scaleEffect(swipeRegistered ? 1.04 : 1.0)
                    .animation(.spring(response: 0.25), value: swipeRegistered)
                VStack(spacing: 10) {
                    Image(systemName: swipeRegistered ? "checkmark.circle.fill" : selectedStyle.icon)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(swipeRegistered ? .green : accent.opacity(0.75))
                    Text(swipeRegistered ? "EXECUTED!" : "SWIPE HERE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(swipeRegistered ? .green : accent.opacity(0.6)).tracking(2)
                }
                if !swipeRegistered {
                    Circle().fill(accent.opacity(0.22)).frame(width: 36, height: 36)
                        .offset(swipeDragOffset)
                        .animation(.interactiveSpring(), value: swipeDragOffset)
                }
            }
            .gesture(DragGesture(minimumDistance: 12)
                .onChanged { v in guard !swipeRegistered else { return }; swipeDragOffset = v.translation }
                .onEnded   { v in guard !swipeRegistered else { return }; registerSwipe(translation: v.translation) })
            Spacer()
        }
    }

    // MARK: - Judge Reveal

    private var judgeRevealScreen: some View {
        ScrollView {
            VStack(spacing: 18) {
                scoreHeader.padding(.top, 14)
                if isPerfect && perfectFlash {
                    Text("PERFECT EXECUTION")
                        .font(.system(size: 19, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.7), radius: 20)
                        .tracking(3)
                        .transition(.scale.combined(with: .opacity))
                }
                courtCanvas.padding(.horizontal, 20)
                crowdMeter.padding(.horizontal, 24)
                judgeCards.padding(.horizontal, 20)
                if judgeScoresRevealed.allSatisfy({ $0 }) {
                    roundTotalBlock
                    if let last = aiRoundScores.last {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill").font(.system(size: 10)).foregroundStyle(.red)
                            Text("KAI NEXUS scored \(last) this round")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                if !playerRoundScores.isEmpty { scoreboard }
                Spacer(minLength: 40)
            }
        }
    }

    private var crowdMeter: some View {
        VStack(spacing: 6) {
            HStack {
                Text("CROWD ENERGY")
                    .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text(crowdLabel)
                    .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accent)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 10)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.brandBlue, accent, .yellow.opacity(0.9)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * crowdLevel, height: 10)
                        .animation(.spring(response: 0.7, dampingFraction: 0.6), value: crowdLevel)
                }
            }.frame(height: 10)
        }
    }

    private var crowdLabel: String {
        if crowdLevel >= 0.9 { return "ON FIRE" }
        if crowdLevel >= 0.75 { return "ELECTRIC" }
        if crowdLevel >= 0.60 { return "HYPED" }
        if crowdLevel >= 0.40 { return "BUILDING" }
        return "WARMING UP"
    }

    private var judgeCards: some View {
        VStack(spacing: 10) {
            Text("JUDGE SCORES")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(3)
            HStack(spacing: 12) {
                judgeCard(label: "JUDGE 1", score: currentJ1, revealed: safeRevealed(0))
                judgeCard(label: "JUDGE 2", score: currentJ2, revealed: safeRevealed(1))
                judgeCard(label: "JUDGE 3", score: currentJ3, revealed: safeRevealed(2))
            }
        }
    }

    private func judgeCard(label: String, score: Int, revealed: Bool) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(1)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(revealed ? accent.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(revealed ? accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1))
                    .frame(height: 72)
                if revealed {
                    Text("\(score)")
                        .font(.system(size: 38, weight: .black, design: .monospaced)).foregroundStyle(.white)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                } else {
                    Text("?")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.10))
                }
            }
            miniBar(value: revealed ? Double(score) / 10.0 : 0,
                    color: revealed ? judgeScoreColor(score) : accent)
        }.frame(maxWidth: .infinity)
    }

    private func judgeScoreColor(_ s: Int) -> Color {
        if s >= 9 { return .yellow }
        if s >= 7 { return Theme.brandCyan }
        if s >= 5 { return .green }
        return .red
    }

    private var roundTotalBlock: some View {
        let total = currentJ1 + currentJ2 + currentJ3
        return VStack(spacing: 6) {
            Text("\(total)")
                .font(.system(size: 60, weight: .black, design: .monospaced)).foregroundStyle(.white)
                .shadow(color: accent.opacity(0.4), radius: 16)
                .contentTransition(.numericText())
            Text(currentMessage)
                .font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(accent).tracking(2)
            Text("ROUND \(currentRound) SCORE")
                .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
        }.padding(.vertical, 8).transition(.scale.combined(with: .opacity))
    }

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SCOREBOARD")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(2).padding(.leading, 4)
            ForEach(playerRoundScores, id: \.round) { r in
                HStack(spacing: 10) {
                    Text("R\(r.round)")
                        .font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(accent).frame(width: 24)
                    Image(systemName: r.style.icon).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).frame(width: 20)
                    Text(r.style.name).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(r.j1)+\(r.j2)+\(r.j3)")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    Text("\(r.total)")
                        .font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(.white).frame(width: 36)
                    Image(systemName: r.playerWon ? "arrow.up.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(r.playerWon ? .green : .red)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 0.5)))
            }
        }.padding(.horizontal, 20)
    }

    // MARK: - Round Transition

    private var roundTransitionOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 16) {
                if let last = playerRoundScores.last {
                    Text(last.playerWon ? "ROUND WON" : "ROUND LOST")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(last.playerWon ? .green : .red).tracking(3)
                }
                Text("ROUND \(currentRound) of \(TOTAL_ROUNDS)")
                    .font(.system(size: 34, weight: .black)).italic().foregroundStyle(.white)
                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text("\(playerTotal)")
                            .font(.system(size: 28, weight: .black, design: .monospaced)).foregroundStyle(accent)
                        Text("YOU")
                            .font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Text("VS").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                    VStack(spacing: 2) {
                        Text("\(aiTotal)")
                            .font(.system(size: 28, weight: .black, design: .monospaced)).foregroundStyle(.red)
                        Text("KAI")
                            .font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                Button { withAnimation { phase = .styleSelect } } label: {
                    Text("CONTINUE")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 36).padding(.vertical, 14)
                        .background(accent).clipShape(.rect(cornerRadius: 14))
                        .shadow(color: accent.opacity(0.3), radius: 10)
                }.padding(.top, 12)
            }
        }
    }

    // MARK: - Result

    private var resultScreen: some View {
        let winner: ResultScreen.ResultWinner = playerTotal > aiTotal ? .p1 : playerTotal < aiTotal ? .p2 : .draw
        return ResultScreen(
            winner: winner, p1Score: playerTotal, p2Score: aiTotal, title: "Dunk Contest", accentColor: accent,
            prqGain: PRQ.modeReward(mode: .basketballDunkContest3D, won: playerTotal > aiTotal,
                                    tied: playerTotal == aiTotal,
                                    combo: playerRoundScores.filter(\.playerWon).count,
                                    criticals: playerRoundScores.filter(\.isPerfect).count,
                                    scoreDifferential: max(0, playerTotal - aiTotal)),
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: PRQ.attributeLabel(for: .basketballDunkContest3D),
            modeAttributeValue: PRQ.attributeValue(prq: viewModel.effectiveMetrics.prqScore,
                                                   for: .basketballDunkContest3D),
            onReturn: { awardShards(winner: winner); dismiss() }
        )
    }

    // MARK: - Shared sub-views

    private var styleTag: some View {
        HStack(spacing: 8) {
            Image(systemName: selectedStyle.icon).font(.system(size: 13, weight: .bold)).foregroundStyle(accent)
            Text(selectedStyle.name.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accent).tracking(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Capsule().fill(accent.opacity(0.08)).overlay(Capsule().stroke(accent.opacity(0.2), lineWidth: 1)))
    }

    private func miniBar(value: Double, color: Color) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06)).frame(height: 4)
                Capsule().fill(color)
                    .frame(width: g.size.width * max(0, min(1, value)), height: 4)
                    .animation(.spring(response: 0.4), value: value)
            }
        }.frame(height: 4)
    }

    private func diffBar(difficulty: Double) -> some View {
        HStack(spacing: 4) {
            Text("DIFF").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                    Capsule()
                        .fill(difficulty >= 0.85 ? Color.red : difficulty >= 0.70 ? Color.orange : Theme.foundationGreen)
                        .frame(width: g.size.width * difficulty, height: 4)
                }
            }.frame(height: 4)
        }
    }

    private func powerBarColors(_ level: Double) -> [Color] {
        if level >= 78 { return [Theme.foundationGreen, .green, .yellow] }
        if level >= 55 { return [Theme.brandBlue, accent] }
        return [.white.opacity(0.3), .white.opacity(0.55)]
    }

    private func safeRevealed(_ i: Int) -> Bool {
        judgeScoresRevealed.indices.contains(i) && judgeScoresRevealed[i]
    }

    // MARK: - Logic

    private func resetApproach() {
        powerLevel = 0; approachReleased = false; powerFilling = false
        execProgress = 0; postDunk = false; swipeRegistered = false; swipeDragOffset = .zero
    }

    private func startCharge() {
        guard !powerFilling, !approachReleased else { return }
        powerFilling = true
        // Haptic 3: medium on takeoff / charge start
        impactMed.impactOccurred()
        powerTask?.cancel()
        powerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard powerFilling else { return }
                    let prevInZone = powerLevel >= 78 && powerLevel <= 90
                    powerLevel = min(100, powerLevel + 1.6)
                    let nowInZone = powerLevel >= 78 && powerLevel <= 90
                    if !prevInZone && nowInZone { impactMed.impactOccurred() }
                    if powerLevel >= 100 { releasePower() }
                }
            }
        }
    }

    private func releasePower() {
        guard !approachReleased else { return }
        approachReleased = true; powerFilling = false; powerTask?.cancel()
        // Haptic 4: soft on landing / release
        impactSoft.impactOccurred()
        let p = powerLevel
        let quality: Double
        switch p {
        case 78...90:  quality = 1.0
        case 65..<78:  quality = 0.7 + (p - 65) / 13.0 * 0.3
        case 90..<100: quality = 1.0 - (p - 90) / 10.0 * 0.4
        case 40..<65:  quality = 0.3 + (p - 40) / 25.0 * 0.4
        default:       quality = max(0.1, p / 100.0 * 0.3)
        }
        approachQuality = quality
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            await MainActor.run {
                swipeRegistered = false; swipeDragOffset = .zero
                executionQuality = 0; execProgress = 0; phase = .execution
            }
        }
    }

    private func registerSwipe(translation: CGSize) {
        guard !swipeRegistered else { return }
        let mag = sqrt(translation.width * translation.width + translation.height * translation.height)
        let magQ = min(1.0, mag / 160.0)
        let dirQ = swipeDirectionQuality(style: selectedStyle, translation: translation)
        executionQuality = magQ * 0.4 + dirQ * 0.6
        swipeRegistered = true; swipeFlash = true; swipeDragOffset = .zero
        // Haptic 1: heavy on rim contact / dunk execution
        impactHvy.impactOccurred()
        Task { try? await Task.sleep(for: .milliseconds(180)); await MainActor.run { swipeFlash = false } }
        execAnimTask?.cancel()
        execAnimTask = Task {
            let steps = 48
            for step in 0..<steps {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                await MainActor.run { execProgress = Double(step + 1) / Double(steps) }
                // Haptic 4: second soft haptic as player lands (last 10%)
                if step == 43 {
                    await MainActor.run { impactSoft.impactOccurred() }
                }
            }
            await MainActor.run {
                postDunk = true
                triggerShake(intensity: 14)
                triggerBurst(color: accent, count: 14)
                scoreRound()
            }
        }
    }

    private func swipeDirectionQuality(style: DunkStyle, translation: CGSize) -> Double {
        let tx = translation.width; let ty = translation.height
        let total = abs(tx) + abs(ty) + 1
        switch style.id {
        case "power_slam", "tomahawk", "alley_oop": return max(0, -ty) / total
        case "windmill", "three_sixty":             return abs(tx) / total
        case "reverse":                             return max(0, ty) / total
        case "between_legs":                        return min(1.0, sqrt(tx * tx + ty * ty) / 130.0)
        default:                                    return 0.6
        }
    }

    private func scoreRound() {
        let combinedQ = approachQuality * 0.45 + executionQuality * 0.55
        let diff      = selectedStyle.difficulty
        let perfect   = approachQuality >= 0.92 && executionQuality >= 0.88
        isPerfect = perfect

        if perfect {
            // Haptic 2: rigid on perfect score (10)
            impactRigid.impactOccurred()
            triggerShake(intensity: 20)
            triggerBurst(color: .yellow, count: 20)
        }

        let prqBoost = min(1.0, viewModel.effectiveMetrics.prqScore / 100.0)
        let rawBase  = 4.0 + combinedQ * 4.0 * diff + prqBoost * 1.0
        let base     = min(10, max(1, Int(rawBase.rounded())))
        let pb = perfect ? 1 : 0
        let j1 = min(10, base + pb + Int.random(in: 0...1))
        let j2 = min(10, base + pb + Int.random(in: 0...1))
        let j3 = min(10, base + pb + Int.random(in: 0...1))
        let total = j1 + j2 + j3

        let msg: String
        if perfect          { msg = "PERFECT EXECUTION" }
        else if total >= 27 { msg = "LEGENDARY!" }
        else if total >= 23 { msg = "CROWD GOES WILD!" }
        else if total >= 19 { msg = "POWERFUL!" }
        else if total >= 15 { msg = "SOLID DUNK" }
        else                { msg = "NEEDS WORK" }

        // Haptic 5: error notification on failed dunk / very low score (miss)
        if total < 15 {
            notifyGen.notificationOccurred(.error)
        }

        let aiScore   = Int.random(in: 18...27)
        let playerWon = total > aiScore
        currentJ1 = j1; currentJ2 = j2; currentJ3 = j3; currentMessage = msg
        playerRoundScores.append(RoundResult(round: currentRound, style: selectedStyle,
                                             j1: j1, j2: j2, j3: j3, total: total,
                                             message: msg, isPerfect: perfect,
                                             aiScore: aiScore, playerWon: playerWon))
        aiRoundScores.append(aiScore)
        playerTotal += total; aiTotal += aiScore
        judgeScoresRevealed = [false, false, false]; crowdLevel = 0
        phase = .judgeReveal

        if perfect {
            withAnimation(.spring(response: 0.3)) { perfectFlash = true }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run { withAnimation { perfectFlash = false } }
            }
        }
        startJudgeReveal(combinedQ: combinedQ, styleDiff: diff)
    }

    private func startJudgeReveal(combinedQ: Double, styleDiff: Double) {
        judgeRevealTask?.cancel()
        judgeRevealTask = Task {
            for i in 0..<3 {
                try? await Task.sleep(for: .milliseconds(600 + Int64(i) * 420))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        judgeScoresRevealed[i] = true
                    }
                    impactMed.impactOccurred()
                }
            }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                let target = min(1.0, (combinedQ * 0.6 + styleDiff * 0.4) * selectedStyle.crowdPeak)
                withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) { crowdLevel = target }
            }
            try? await Task.sleep(for: .seconds(4.2))
            guard !Task.isCancelled else { return }
            await MainActor.run { advanceAfterReveal() }
        }
    }

    private func advanceAfterReveal() {
        if currentRound >= TOTAL_ROUNDS {
            GameResultService.saveResult(modeId: "basketball_dunk", userScore: playerTotal)
            phase = .result
        } else { currentRound += 1; phase = .roundTransition }
    }

    private func awardShards(winner: ResultScreen.ResultWinner) {
        guard !shardsAwarded else { return }
        shardsAwarded = true
        viewModel.profile.evolutionShards += winner == .p1 ? 50 : winner == .draw ? 25 : 15
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
}
