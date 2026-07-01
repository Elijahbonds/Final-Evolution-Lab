import SwiftUI
import UIKit

// MARK: - Supporting Types

private enum TennisPoint: Int, CaseIterable {
    case zero = 0, fifteen = 15, thirty = 30, forty = 40
    var display: String {
        switch self { case .zero: "0"; case .fifteen: "15"; case .thirty: "30"; case .forty: "40" }
    }
    var next: TennisPoint? {
        switch self { case .zero: .fifteen; case .fifteen: .thirty; case .thirty: .forty; case .forty: nil }
    }
}

private enum TennisPhase { case ready, serving, rally, result }
private enum SwipeDir { case left, right, up, none }

private struct TennisBall {
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)  // normalized 0–1
    var fromOpponent: Bool = true
}

// MARK: - Shot Placement Zone (opponent half: 3 deep × 2 wide = 6 zones)

private enum ShotZone: Int, CaseIterable {
    case topLeft = 0, topRight, midLeft, midRight, bottomLeft, bottomRight

    var normalizedTarget: CGPoint {
        switch self {
        case .topLeft:     return CGPoint(x: 0.20, y: 0.14)
        case .topRight:    return CGPoint(x: 0.80, y: 0.14)
        case .midLeft:     return CGPoint(x: 0.20, y: 0.25)
        case .midRight:    return CGPoint(x: 0.80, y: 0.25)
        case .bottomLeft:  return CGPoint(x: 0.20, y: 0.35)
        case .bottomRight: return CGPoint(x: 0.80, y: 0.35)
        }
    }
    var isCorner: Bool { self == .topLeft || self == .topRight }
    var isWide: Bool   { [.topLeft, .topRight, .midLeft, .midRight].contains(self) }
    var isLeft: Bool   { [.topLeft, .midLeft, .bottomLeft].contains(self) }

    static func fromAim(aimX: CGFloat, aimDepth: CGFloat) -> ShotZone {
        let isLeft = aimX < 0.5
        if aimDepth > 0.66 { return isLeft ? .topLeft : .topRight }
        if aimDepth > 0.33 { return isLeft ? .midLeft : .midRight }
        return isLeft ? .bottomLeft : .bottomRight
    }
}

// MARK: - Mini-Court History Dot

private struct ShotLandingDot {
    let normalizedPos: CGPoint
    let isWinner: Bool
}

// MARK: - New: Serve Type

private enum ServeType: String, CaseIterable {
    case flat  = "FLAT"
    case slice = "SLICE"
    case kick  = "KICK"

    var description: String {
        switch self {
        case .flat:  return "Fast · Straight · 70% in"
        case .slice: return "Curves away · 80% in"
        case .kick:  return "Bounces high · 85% in"
        }
    }
    /// Base probability the serve lands in when executed
    var inProbability: Double {
        switch self {
        case .flat:  return 0.70
        case .slice: return 0.80
        case .kick:  return 0.85
        }
    }
    /// Icon representing the serve type
    var icon: String {
        switch self {
        case .flat:  return "bolt.fill"
        case .slice: return "arrow.turn.down.right"
        case .kick:  return "arrow.up.and.down.circle"
        }
    }
    /// Accent colour for the button
    var color: Color {
        switch self {
        case .flat:  return Color(red: 0.95, green: 0.82, blue: 0.15)
        case .slice: return Color(red: 0.30, green: 0.75, blue: 0.95)
        case .kick:  return Color(red: 0.85, green: 0.45, blue: 0.95)
        }
    }
}

// MARK: - New: Shot Type

private enum ShotType: String, CaseIterable {
    case groundstroke = "DRIVE"
    case lob          = "LOB"
    case dropShot     = "DROP"
    case approach     = "APPROACH"

    var icon: String {
        switch self {
        case .groundstroke: return "arrow.right.circle.fill"
        case .lob:          return "arrow.up.circle.fill"
        case .dropShot:     return "arrow.down.circle.fill"
        case .approach:     return "figure.walk"
        }
    }
    var color: Color {
        switch self {
        case .groundstroke: return Color(red: 0.20, green: 0.80, blue: 0.40)
        case .lob:          return Color(red: 0.95, green: 0.65, blue: 0.15)
        case .dropShot:     return Color(red: 0.95, green: 0.35, blue: 0.35)
        case .approach:     return Color(red: 0.45, green: 0.65, blue: 0.95)
        }
    }
    /// Probability of outright winner when used in ideal circumstances
    var winnerProbability: Double {
        switch self {
        case .groundstroke: return 0.18
        case .lob:          return 0.25
        case .dropShot:     return 0.30
        case .approach:     return 0.15
        }
    }
}

// MARK: - Haptics Helper

private enum TennisHaptic {
    static func hit()         { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func bounce()      { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func ace()         { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func fault()       { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func doubleFault() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func challenge()   { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func momentum()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}

// MARK: - Court Canvas

private struct TennisCourtCanvas: View {
    let ballPosition: CGPoint
    let ballScale: CGFloat
    let swipeWindowOpen: Bool
    let isPlayerSide: Bool
    let phase: TennisPhase
    let feedbackText: String
    let showFeedback: Bool
    let crowdLevel: Double
    let showAce: Bool
    let showWinner: Bool
    let showFault: Bool
    // Aim system
    var aimReticleNorm: CGPoint = .zero
    var isDragging: Bool = false
    var dragStartNorm: CGPoint = .zero
    var landingDots: [ShotLandingDot] = []
    var targetZone: ShotZone? = nil

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                var d = TennisDrawer(
                    t: tl.date.timeIntervalSinceReferenceDate,
                    W: size.width, H: size.height,
                    ballPos: ballPosition, ballScale: ballScale,
                    swipeOpen: swipeWindowOpen,
                    playerSide: isPlayerSide,
                    phase: phase, crowd: crowdLevel,
                    showAce: showAce, showWinner: showWinner, showFault: showFault,
                    aimReticleNorm: aimReticleNorm, isDragging: isDragging,
                    dragStartNorm: dragStartNorm, landingDots: landingDots,
                    targetZone: targetZone
                )
                d.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Drawer

private struct TennisDrawer {
    let t: Double
    let W: CGFloat; let H: CGFloat
    let ballPos: CGPoint; let ballScale: CGFloat
    let swipeOpen: Bool
    let playerSide: Bool
    let phase: TennisPhase
    let crowd: Double
    let showAce: Bool
    let showWinner: Bool
    let showFault: Bool
    // Aim system
    var aimReticleNorm: CGPoint = .zero
    var isDragging: Bool = false
    var dragStartNorm: CGPoint = .zero
    var landingDots: [ShotLandingDot] = []
    var targetZone: ShotZone? = nil

    // Court geometry
    var cL: CGFloat { W * 0.06 }
    var cR: CGFloat { W * 0.94 }
    var cT: CGFloat { H * 0.08 }
    var cB: CGFloat { H * 0.92 }
    var netY: CGFloat { (cT + cB) * 0.5 }
    var singL: CGFloat { W * 0.14 }
    var singR: CGFloat { W * 0.86 }
    var servT: CGFloat { cT + (cB - cT) * 0.30 }
    var servB: CGFloat { cT + (cB - cT) * 0.70 }

    var ballCX: CGFloat { ballPos.x * W }
    var ballCY: CGFloat { ballPos.y * H }

    // Ball trail history (simulated based on position + time)
    var trailPositions: [CGPoint] {
        var pts: [CGPoint] = []
        for i in 1...5 {
            let dt = Double(i) * 0.04
            let ox = ballCX - CGFloat(sin(t * 4 + Double(i))) * CGFloat(i) * 3
            let oy = ballCY + CGFloat(dt * 80)
            pts.append(CGPoint(x: ox, y: oy))
        }
        return pts
    }

    mutating func render(ctx: inout GraphicsContext) {
        drawCourtBG(&ctx)       // #1–#8
        drawStadium(&ctx)       // #9–#20
        drawBallTrail(&ctx)     // #21–#28
        drawPlayers(&ctx)       // #29–#50
        drawImpactFX(&ctx)      // #51–#62
        drawScoreUI(&ctx)       // #63–#72
        drawAtmosphere(&ctx)    // #73–#84
        drawCourtZones(&ctx)    // 6-zone placement overlay
        drawLandingDots(&ctx)   // mini-court history
        if isDragging { drawAimArrow(&ctx) }
        if swipeOpen { drawSwipeZone(&ctx) }
        drawBall(&ctx)
    }

    // MARK: Court Background (#1–#8)

    private func drawCourtBG(_ ctx: inout GraphicsContext) {
        // #1 Hard-court blue gradient base
        ctx.fill(
            Path(CGRect(x: cL, y: cT, width: cR - cL, height: cB - cT)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.11, green: 0.32, blue: 0.60), location: 0),
                    .init(color: Color(red: 0.08, green: 0.25, blue: 0.52), location: 0.5),
                    .init(color: Color(red: 0.06, green: 0.20, blue: 0.44), location: 1.0),
                ]),
                startPoint: CGPoint(x: W/2, y: cT),
                endPoint: CGPoint(x: W/2, y: cB)
            )
        )

        // #2 Subtle court texture horizontal lines
        let texLines = 22
        for i in 1..<texLines {
            let ty = cT + CGFloat(i) / CGFloat(texLines) * (cB - cT)
            var line = Path()
            line.move(to: CGPoint(x: cL, y: ty))
            line.addLine(to: CGPoint(x: cR, y: ty))
            ctx.stroke(line, with: .color(Color.white.opacity(0.025)), lineWidth: 0.5)
        }

        // #3 Doubles alley tint left
        ctx.fill(
            Path(CGRect(x: cL, y: cT, width: singL - cL, height: cB - cT)),
            with: .color(Color(red: 0.12, green: 0.33, blue: 0.62).opacity(0.40))
        )

        // #4 Doubles alley tint right
        ctx.fill(
            Path(CGRect(x: singR, y: cT, width: cR - singR, height: cB - cT)),
            with: .color(Color(red: 0.12, green: 0.33, blue: 0.62).opacity(0.40))
        )

        // #5 White court baselines
        let lineColor = Color.white.opacity(0.92)
        let lw: CGFloat = 2.0
        stroke(&ctx, from: CGPoint(x: cL, y: cT), to: CGPoint(x: cR, y: cT), color: lineColor, width: lw * 1.5)
        stroke(&ctx, from: CGPoint(x: cL, y: cB), to: CGPoint(x: cR, y: cB), color: lineColor, width: lw * 1.5)

        // #6 Singles + doubles sidelines
        stroke(&ctx, from: CGPoint(x: cL, y: cT), to: CGPoint(x: cL, y: cB), color: lineColor, width: lw)
        stroke(&ctx, from: CGPoint(x: cR, y: cT), to: CGPoint(x: cR, y: cB), color: lineColor, width: lw)
        stroke(&ctx, from: CGPoint(x: singL, y: cT), to: CGPoint(x: singL, y: cB), color: lineColor, width: lw)
        stroke(&ctx, from: CGPoint(x: singR, y: cT), to: CGPoint(x: singR, y: cB), color: lineColor, width: lw)

        // #7 Service lines and center service line
        stroke(&ctx, from: CGPoint(x: singL, y: servT), to: CGPoint(x: singR, y: servT), color: lineColor, width: lw)
        stroke(&ctx, from: CGPoint(x: singL, y: servB), to: CGPoint(x: singR, y: servB), color: lineColor, width: lw)
        stroke(&ctx, from: CGPoint(x: W/2, y: servT), to: CGPoint(x: W/2, y: servB), color: lineColor, width: lw)

        // #8 Center marks on baselines + net post shadows
        for bly in [cT, cB] {
            stroke(&ctx, from: CGPoint(x: W/2 - 5, y: bly), to: CGPoint(x: W/2 + 5, y: bly), color: lineColor, width: lw)
        }
        for px in [cL - 6, cR + 6] {
            var shadowBlur = ctx
            shadowBlur.addFilter(.blur(radius: 6))
            shadowBlur.fill(
                Path(CGRect(x: px - 5, y: netY - 2, width: 10, height: 14)),
                with: .color(Color.black.opacity(0.50))
            )
        }
    }

    // MARK: Stadium (#9–#20)

    private func drawStadium(_ ctx: inout GraphicsContext) {
        // #9 Arena background — dark walls
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.04, green: 0.04, blue: 0.07), location: 0),
                    .init(color: Color(red: 0.06, green: 0.05, blue: 0.10), location: 1.0),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: H)
            )
        )

        // #10 Top stands base
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: cT)),
            with: .color(Color(red: 0.07, green: 0.07, blue: 0.11))
        )

        // #11 Bottom stands base
        ctx.fill(
            Path(CGRect(x: 0, y: cB, width: W, height: H - cB)),
            with: .color(Color(red: 0.07, green: 0.07, blue: 0.11))
        )

        // #12 Side stands left
        ctx.fill(
            Path(CGRect(x: 0, y: cT, width: cL, height: cB - cT)),
            with: .color(Color(red: 0.07, green: 0.07, blue: 0.11))
        )

        // #13 Side stands right
        ctx.fill(
            Path(CGRect(x: cR, y: cT, width: W - cR, height: cB - cT)),
            with: .color(Color(red: 0.07, green: 0.07, blue: 0.11))
        )

        // #14 Tiered crowd — 3 rows top stands
        let jerseys: [Color] = [
            Color(red: 0.72, green: 0.12, blue: 0.12),
            Color(red: 0.12, green: 0.35, blue: 0.72),
            Color(red: 0.72, green: 0.58, blue: 0.12),
            Color(red: 0.30, green: 0.30, blue: 0.30),
            Color(red: 0.55, green: 0.15, blue: 0.55),
            Color(red: 0.15, green: 0.58, blue: 0.35),
        ]
        let standConfigs: [(y: CGFloat, h: CGFloat)] = [(0, cT), (cB, H - cB)]
        for (sIdx, stand) in standConfigs.enumerated() {
            let rows = 3
            for row in 0..<rows {
                let ry = stand.y + stand.h * CGFloat(row + 1) / CGFloat(rows + 1)
                let cols = 30
                for col in 0..<cols {
                    let jColor = jerseys[(col * 3 + row * 7 + sIdx * 5) % jerseys.count]
                    let waveOff = CGFloat(sin(t * 1.2 + Double(col) * 0.6 + Double(row + sIdx * 3))) * 1.2
                    let hx = W * CGFloat(col + 1) / CGFloat(cols + 1)
                    let headR: CGFloat = 4
                    // Head circle
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: hx - headR, y: ry - headR + waveOff, width: headR*2, height: headR*2)),
                        with: .color(jColor.opacity(0.65))
                    )
                    // Body stub
                    var bodySt = Path()
                    bodySt.move(to: CGPoint(x: hx, y: ry + headR + waveOff))
                    bodySt.addLine(to: CGPoint(x: hx, y: ry + headR + 5 + waveOff))
                    ctx.stroke(bodySt, with: .color(jColor.opacity(0.40)), lineWidth: 2.2)
                }
            }
        }

        // #15 Stadium lights — 4 bright corner spots with lens flare halos
        let lightPositions: [(CGFloat, CGFloat)] = [
            (W * 0.05, H * 0.03),
            (W * 0.95, H * 0.03),
            (W * 0.05, H * 0.97),
            (W * 0.95, H * 0.97),
        ]
        for (lIdx, (lx, ly)) in lightPositions.enumerated() {
            let flicker = 1.0 + 0.05 * CGFloat(sin(t * 4.3 + Double(lIdx) * 1.7))
            // Outer halo glow
            var halo = ctx
            halo.addFilter(.blur(radius: 28))
            halo.fill(
                Path(ellipseIn: CGRect(x: lx - 18, y: ly - 18, width: 36, height: 36)),
                with: .color(Color(red: 1.0, green: 0.96, blue: 0.75).opacity(0.55 * flicker))
            )
            // Inner bloom
            var bloom = ctx
            bloom.addFilter(.blur(radius: 8))
            bloom.fill(
                Path(ellipseIn: CGRect(x: lx - 7, y: ly - 7, width: 14, height: 14)),
                with: .color(Color.white.opacity(0.85 * flicker))
            )
            // Lamp core dot
            ctx.fill(
                Path(ellipseIn: CGRect(x: lx - 3, y: ly - 3, width: 6, height: 6)),
                with: .color(Color.white.opacity(0.98))
            )
            // Lens flare horizontal streak
            var flare = ctx
            flare.addFilter(.blur(radius: 2))
            flare.fill(
                Path(CGRect(x: lx - 30, y: ly - 1, width: 60, height: 2)),
                with: .color(Color.white.opacity(0.08 * flicker))
            )
            // Light pole
            var pole = Path()
            let poleBase = lx < W/2 ? CGPoint(x: cL, y: lx < W/2 ? cT : cB)
                                    : CGPoint(x: cR, y: lx < W/2 ? cT : cB)
            pole.move(to: CGPoint(x: lx, y: ly))
            pole.addLine(to: poleBase)
            ctx.stroke(pole, with: .color(Color(white: 0.32).opacity(0.45)), lineWidth: 1.5)
        }

        // #16 Scoreboard on far wall
        let sbW: CGFloat = W * 0.38
        let sbH: CGFloat = cT * 0.62
        let sbX: CGFloat = (W - sbW) / 2
        let sbY: CGFloat = 4
        ctx.fill(
            Path(roundedRect: CGRect(x: sbX, y: sbY, width: sbW, height: sbH), cornerRadius: 5),
            with: .color(Color(red: 0.06, green: 0.06, blue: 0.14))
        )
        ctx.stroke(
            Path(roundedRect: CGRect(x: sbX, y: sbY, width: sbW, height: sbH), cornerRadius: 5),
            with: .color(Color(red: 0.28, green: 0.28, blue: 0.55).opacity(0.6)),
            lineWidth: 1.2
        )
        // LED scan line on scoreboard
        let scanY = sbY + CGFloat(fmod(t * 16, Double(sbH)))
        var scan = Path()
        scan.move(to: CGPoint(x: sbX + 3, y: scanY))
        scan.addLine(to: CGPoint(x: sbX + sbW - 3, y: scanY))
        ctx.stroke(scan, with: .color(Color.white.opacity(0.04)), lineWidth: 1)
        // Scoreboard center divider
        var sbDiv = Path()
        sbDiv.move(to: CGPoint(x: sbX + sbW/2, y: sbY + 3))
        sbDiv.addLine(to: CGPoint(x: sbX + sbW/2, y: sbY + sbH - 3))
        ctx.stroke(sbDiv, with: .color(Color.white.opacity(0.18)), lineWidth: 0.8)

        // #17 Sponsor banners — 4 rectangles with colored fills
        let sponsorData: [(x: CGFloat, color: Color)] = [
            (W * 0.04, Color(red: 0.72, green: 0.08, blue: 0.08)),
            (W * 0.20, Color(red: 0.08, green: 0.28, blue: 0.72)),
            (W * 0.72, Color(red: 0.08, green: 0.60, blue: 0.32)),
            (W * 0.88, Color(red: 0.68, green: 0.52, blue: 0.08)),
        ]
        let spW: CGFloat = W * 0.08
        let spH: CGFloat = cT * 0.45
        let spY: CGFloat = cT - spH - 4
        for (sIdx2, sp) in sponsorData.enumerated() {
            let sway = CGFloat(sin(t * 0.55 + Double(sIdx2) * 1.57)) * 2
            let spX = sp.x - spW / 2 + sway
            // Banner body
            ctx.fill(
                Path(CGRect(x: spX, y: spY, width: spW, height: spH)),
                with: .color(sp.color.opacity(0.80))
            )
            ctx.stroke(
                Path(CGRect(x: spX, y: spY, width: spW, height: spH)),
                with: .color(Color.white.opacity(0.22)),
                lineWidth: 0.7
            )
            // Decorative stripe on banner
            var stripe = Path()
            stripe.move(to: CGPoint(x: spX + 2, y: spY + spH * 0.5))
            stripe.addLine(to: CGPoint(x: spX + spW - 2, y: spY + spH * 0.5))
            ctx.stroke(stripe, with: .color(Color.white.opacity(0.30)), lineWidth: 1.0)
        }

        // #18 Sky / roof gradient (indoor arena)
        var roofGrad = ctx
        roofGrad.addFilter(.blur(radius: 20))
        roofGrad.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H * 0.12)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.08, green: 0.04, blue: 0.18).opacity(0.9),
                    Color.clear,
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: H * 0.12)
            )
        )

        // #19 Net
        drawNet(&ctx)

        // #20 Crowd cheer glow when crowd is high
        if crowd > 0.6 {
            var cheerGlow = ctx
            cheerGlow.addFilter(.blur(radius: 30))
            cheerGlow.fill(
                Path(CGRect(x: 0, y: 0, width: W, height: cT)),
                with: .color(Color(red: 1.0, green: 0.85, blue: 0.3).opacity(crowd * 0.12))
            )
        }
    }

    // MARK: Net Drawing

    private func drawNet(_ ctx: inout GraphicsContext) {
        // Net shadow
        var shadow = ctx
        shadow.addFilter(.blur(radius: 5))
        shadow.fill(
            Path(CGRect(x: cL + 4, y: netY - 3, width: cR - cL - 4, height: 10)),
            with: .color(Color.black.opacity(0.45))
        )
        // Net white tape top
        ctx.fill(
            Path(CGRect(x: cL - 6, y: netY - 6, width: cR - cL + 12, height: 6)),
            with: .color(Color(white: 0.95))
        )
        // Net mesh horizontal lines
        let meshH: CGFloat = 18
        let netLeft = cL - 6; let netRight = cR + 6
        for r in 0..<4 {
            let ry = netY + CGFloat(r + 1) * meshH / 4
            stroke(&ctx, from: CGPoint(x: netLeft, y: ry), to: CGPoint(x: netRight, y: ry),
                   color: Color(white: 0.75).opacity(0.5), width: 0.8)
        }
        // Net mesh vertical lines
        let meshCols = 28
        for c in 0...meshCols {
            let mx = netLeft + CGFloat(c) / CGFloat(meshCols) * (netRight - netLeft)
            stroke(&ctx, from: CGPoint(x: mx, y: netY), to: CGPoint(x: mx, y: netY + meshH),
                   color: Color(white: 0.65).opacity(0.35), width: 0.5)
        }
        // Net posts
        for px in [cL - 6, cR + 6] {
            ctx.fill(
                Path(CGRect(x: px - 4, y: netY - 8, width: 8, height: 28)),
                with: .color(Color(white: 0.80))
            )
        }
        // Center strap
        ctx.fill(
            Path(CGRect(x: W/2 - 3, y: netY - 4, width: 6, height: 22)),
            with: .color(Color(white: 0.75))
        )
    }

    // MARK: Ball Trail (#21–#28)

    private func drawBallTrail(_ ctx: inout GraphicsContext) {
        let bx = ballCX; let by = ballCY
        let r: CGFloat = max(6, 8) * ballScale

        // #21 Ghost trail frame 1
        let t1x = bx - CGFloat(sin(t * 4.0)) * 6
        let t1y = by + 10
        var ghost1 = ctx
        ghost1.addFilter(.blur(radius: 3))
        ghost1.fill(
            Path(ellipseIn: CGRect(x: t1x - r * 0.7, y: t1y - r * 0.7, width: r * 1.4, height: r * 1.4)),
            with: .color(Color(red: 0.95, green: 0.90, blue: 0.20).opacity(0.18))
        )

        // #22 Ghost trail frame 2
        let t2x = bx - CGFloat(sin(t * 4.0)) * 12
        let t2y = by + 20
        var ghost2 = ctx
        ghost2.addFilter(.blur(radius: 4))
        ghost2.fill(
            Path(ellipseIn: CGRect(x: t2x - r * 0.55, y: t2y - r * 0.55, width: r * 1.1, height: r * 1.1)),
            with: .color(Color(red: 0.95, green: 0.90, blue: 0.20).opacity(0.12))
        )

        // #23 Ghost trail frame 3
        let t3x = bx - CGFloat(sin(t * 4.0)) * 18
        let t3y = by + 30
        var ghost3 = ctx
        ghost3.addFilter(.blur(radius: 5))
        ghost3.fill(
            Path(ellipseIn: CGRect(x: t3x - r * 0.40, y: t3y - r * 0.40, width: r * 0.8, height: r * 0.8)),
            with: .color(Color(red: 0.95, green: 0.90, blue: 0.20).opacity(0.08))
        )

        // #24 Ghost trail frame 4
        let t4x = bx - CGFloat(sin(t * 4.0)) * 24
        let t4y = by + 40
        var ghost4 = ctx
        ghost4.addFilter(.blur(radius: 6))
        ghost4.fill(
            Path(ellipseIn: CGRect(x: t4x - r * 0.28, y: t4y - r * 0.28, width: r * 0.56, height: r * 0.56)),
            with: .color(Color(red: 0.95, green: 0.90, blue: 0.20).opacity(0.05))
        )

        // #25 Ghost trail frame 5
        let t5x = bx - CGFloat(sin(t * 4.0)) * 30
        let t5y = by + 50
        var ghost5 = ctx
        ghost5.addFilter(.blur(radius: 7))
        ghost5.fill(
            Path(ellipseIn: CGRect(x: t5x - r * 0.18, y: t5y - r * 0.18, width: r * 0.36, height: r * 0.36)),
            with: .color(Color(red: 0.95, green: 0.90, blue: 0.20).opacity(0.03))
        )

        // #26 Bounce ring on court contact
        if by > cB - 20 && by < cB + 10 {
            let ringPulse = CGFloat(abs(sin(t * 8))) * 8
            var ring = ctx
            ring.addFilter(.blur(radius: 3))
            ring.stroke(
                Path(ellipseIn: CGRect(x: bx - 12 - ringPulse, y: cB - 5, width: 24 + ringPulse * 2, height: 8)),
                with: .color(Color.white.opacity(0.35)),
                lineWidth: 1.5
            )
        }

        // #27 Ball highlight dot (specular)
        ctx.fill(
            Path(ellipseIn: CGRect(x: bx - r * 0.3, y: by - r * 0.55, width: r * 0.35, height: r * 0.25)),
            with: .color(Color.white.opacity(0.60))
        )

        // #28 Motion blur streak behind ball
        var streak = ctx
        streak.addFilter(.blur(radius: 2))
        var streakPath = Path()
        streakPath.move(to: CGPoint(x: bx, y: by))
        streakPath.addLine(to: CGPoint(x: bx - CGFloat(sin(t * 4)) * 16, y: by + 16))
        streak.stroke(streakPath, with: .color(Color(red: 0.95, green: 0.90, blue: 0.20).opacity(0.25)), lineWidth: r * 0.8)
    }

    // MARK: Players (#29–#50)

    private func drawPlayers(_ ctx: inout GraphicsContext) {
        let playerX = lerp(ballCX, W * 0.5, 0.4)
        let playerY = cB + (H - cB) * 0.35
        let isBallClose = ballCY > netY

        // #29–#39 Player figure (YOU)
        drawPlayerFigure(
            &ctx, x: playerX, y: playerY,
            color: Color(red: 0.15, green: 0.65, blue: 0.20),
            facingUp: true, swinging: isBallClose && swipeOpen,
            isPlayer: true
        )

        let oppX = lerp(ballCX, W * 0.5, 0.5)
        let oppY = cT * 0.45
        let isBallFar = ballCY <= netY

        // #40–#50 Opponent figure
        drawPlayerFigure(
            &ctx, x: oppX, y: oppY,
            color: Color(red: 0.80, green: 0.15, blue: 0.15),
            facingUp: false, swinging: isBallFar,
            isPlayer: false
        )
    }

    private func drawPlayerFigure(_ ctx: inout GraphicsContext,
                                   x: CGFloat, y: CGFloat,
                                   color: Color, facingUp: Bool,
                                   swinging: Bool, isPlayer: Bool) {
        let dir: CGFloat = facingUp ? -1 : 1
        let baseNumber = isPlayer ? 29 : 40

        // #29 / #40 Footwork shadow beneath player
        var sc = ctx
        sc.addFilter(.blur(radius: 5))
        sc.fill(
            Path(ellipseIn: CGRect(x: x - 16, y: y - 3, width: 32, height: 9)),
            with: .color(Color.black.opacity(0.40))
        )

        // #30 / #41 Head
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - 6, y: y - 7, width: 12, height: 12)),
            with: .color(Color(red: 0.93, green: 0.80, blue: 0.68))
        )

        // #31 / #42 Neck / hair
        ctx.fill(
            Path(CGRect(x: x - 3, y: y + 5, width: 6, height: 4)),
            with: .color(Color(red: 0.93, green: 0.80, blue: 0.68))
        )

        // #32 / #43 Body torso
        ctx.fill(
            Path(CGRect(x: x - 5, y: y + 4, width: 10, height: 12)),
            with: .color(color.opacity(0.85))
        )

        // #33 / #44 Body outline
        ctx.stroke(
            Path(CGRect(x: x - 5, y: y + 4, width: 10, height: 12)),
            with: .color(color),
            lineWidth: 1.2
        )

        // #34 / #45 Swing arc (animated)
        let swingAngle = swinging ? CGFloat(sin(t * 14)) * 20 : 0
        let racketDir: CGFloat = swinging ? 1.0 : 1.0

        // Arms
        var armPath = Path()
        if swinging {
            armPath.move(to: CGPoint(x: x - 8 * racketDir, y: y + 9))
            armPath.addLine(to: CGPoint(x: x, y: y + 6))
            armPath.addLine(to: CGPoint(x: x + 15 * racketDir, y: y + 4 + swingAngle))
        } else {
            armPath.move(to: CGPoint(x: x - 9, y: y + 10))
            armPath.addLine(to: CGPoint(x: x, y: y + 7))
            armPath.addLine(to: CGPoint(x: x + 9, y: y + 10))
        }
        ctx.stroke(armPath, with: .color(Color(red: 0.93, green: 0.80, blue: 0.68)), lineWidth: 2.2)

        // #35 / #46 Swing arc glow when swinging
        if swinging {
            let arcRad: CGFloat = 18
            let arcCenter = CGPoint(x: x, y: y + 8)
            let arcStart = Angle.degrees(-60 + Double(swingAngle))
            let arcEnd   = Angle.degrees(60 + Double(swingAngle))
            var arcGlow = ctx
            arcGlow.addFilter(.blur(radius: 3))
            var arcPath = Path()
            arcPath.addArc(center: arcCenter, radius: arcRad,
                           startAngle: arcStart, endAngle: arcEnd, clockwise: false)
            arcGlow.stroke(arcPath, with: .color(color.opacity(0.45)), lineWidth: 3)
        }

        // #36 / #47 Racquet handle
        let rGrip = swinging
            ? CGPoint(x: x + 15 * racketDir, y: y + 4 + swingAngle)
            : CGPoint(x: x + 9, y: y + 10)
        let rHead = CGPoint(x: rGrip.x + 10 * racketDir, y: rGrip.y + dir * 10)
        var racket = Path()
        racket.move(to: rGrip)
        racket.addLine(to: rHead)
        ctx.stroke(racket, with: .color(Color(white: 0.72)), lineWidth: 2.0)

        // #37 / #48 Racquet face oval
        ctx.stroke(
            Path(ellipseIn: CGRect(x: rHead.x - 8, y: rHead.y - 9, width: 16, height: 18)),
            with: .color(Color(red: 0.90, green: 0.75, blue: 0.20)),
            lineWidth: 1.5
        )

        // #38 / #49 Racquet strings cross
        let rfX = rHead.x - 8; let rfY = rHead.y - 9
        stroke(&ctx,
               from: CGPoint(x: rfX + 8, y: rfY),
               to: CGPoint(x: rfX + 8, y: rfY + 18),
               color: Color(white: 0.55).opacity(0.50), width: 0.6)
        stroke(&ctx,
               from: CGPoint(x: rfX, y: rfY + 9),
               to: CGPoint(x: rfX + 16, y: rfY + 9),
               color: Color(white: 0.55).opacity(0.50), width: 0.6)

        // #39 / #50 Legs
        var legs = Path()
        let legSpread: CGFloat = swinging ? 10 : 6
        legs.move(to: CGPoint(x: x - legSpread, y: y + 28))
        legs.addLine(to: CGPoint(x: x, y: y + 16))
        legs.addLine(to: CGPoint(x: x + legSpread, y: y + 28))
        ctx.stroke(legs, with: .color(Color(red: 0.20, green: 0.20, blue: 0.55)), lineWidth: 2.5)
        // Shoes
        ctx.fill(Path(ellipseIn: CGRect(x: x - legSpread - 4, y: y + 26, width: 9, height: 5)),
                 with: .color(Color.white.opacity(0.70)))
        ctx.fill(Path(ellipseIn: CGRect(x: x + legSpread - 4, y: y + 26, width: 9, height: 5)),
                 with: .color(Color.white.opacity(0.70)))
    }

    // MARK: Impact FX (#51–#62)

    private func drawImpactFX(_ ctx: inout GraphicsContext) {
        let bx = ballCX; let by = ballCY

        // #51 Hit burst — 8 rays at ball position (when swipe window recently closed)
        if swipeOpen {
            let rayCount = 8
            for i in 0..<rayCount {
                let angle = Double(i) / Double(rayCount) * .pi * 2 + t * 3
                let dx = CGFloat(cos(angle)) * 16
                let dy = CGFloat(sin(angle)) * 16
                var ray = Path()
                ray.move(to: CGPoint(x: bx, y: by))
                ray.addLine(to: CGPoint(x: bx + dx, y: by + dy))
                ctx.stroke(ray, with: .color(Color(red: 1.0, green: 0.95, blue: 0.30).opacity(0.55)), lineWidth: 1.5)
            }
        }

        // #52 Hit burst glow ring
        if swipeOpen {
            var hitGlow = ctx
            hitGlow.addFilter(.blur(radius: 8))
            hitGlow.fill(
                Path(ellipseIn: CGRect(x: bx - 20, y: by - 20, width: 40, height: 40)),
                with: .color(Color(red: 1.0, green: 0.95, blue: 0.30).opacity(0.25))
            )
        }

        // #53 Ace ring — double circle pulse
        if showAce {
            let pulse1 = CGFloat(abs(sin(t * 6))) * 12
            let pulse2 = CGFloat(abs(cos(t * 6))) * 18
            ctx.stroke(
                Path(ellipseIn: CGRect(x: bx - 22 - pulse1, y: by - 22 - pulse1,
                                       width: 44 + pulse1 * 2, height: 44 + pulse1 * 2)),
                with: .color(Color(red: 1.0, green: 0.85, blue: 0.10).opacity(0.80)),
                lineWidth: 2.5
            )
            // #54 Ace outer ring
            ctx.stroke(
                Path(ellipseIn: CGRect(x: bx - 30 - pulse2, y: by - 30 - pulse2,
                                       width: 60 + pulse2 * 2, height: 60 + pulse2 * 2)),
                with: .color(Color(red: 1.0, green: 0.85, blue: 0.10).opacity(0.40)),
                lineWidth: 1.5
            )
        }

        // #55 Chalk dust on serve — near baseline
        if phase == .serving {
            let dustY = cB
            for i in 0..<8 {
                let dustX = W / 2 + CGFloat(i - 4) * 6
                let dustOff = CGFloat(sin(t * 5 + Double(i) * 0.8)) * 3
                var dust = ctx
                dust.addFilter(.blur(radius: 2))
                dust.fill(
                    Path(ellipseIn: CGRect(x: dustX - 3, y: dustY - 4 + dustOff, width: 6, height: 6)),
                    with: .color(Color.white.opacity(0.35))
                )
            }
        }

        // #56 Service box highlight on fault
        if showFault {
            var faultGlow = ctx
            faultGlow.addFilter(.blur(radius: 10))
            faultGlow.fill(
                Path(CGRect(x: singL, y: cT, width: (singR - singL) / 2, height: servT - cT)),
                with: .color(Color.red.opacity(0.30))
            )
        }

        // #57 Service box border flash
        if showFault {
            ctx.stroke(
                Path(CGRect(x: singL, y: cT, width: (singR - singL) / 2, height: servT - cT)),
                with: .color(Color.red.opacity(0.70)),
                lineWidth: 2.0
            )
        }

        // #58 Winner point gold veil
        if showWinner {
            var veil = ctx
            veil.addFilter(.blur(radius: 25))
            veil.fill(
                Path(CGRect(x: 0, y: 0, width: W, height: H)),
                with: .color(Color(red: 1.0, green: 0.85, blue: 0.10).opacity(0.18))
            )
        }

        // #59 Winner flash border
        if showWinner {
            ctx.stroke(
                Path(CGRect(x: 2, y: 2, width: W - 4, height: H - 4)),
                with: .color(Color(red: 1.0, green: 0.85, blue: 0.10).opacity(0.60)),
                lineWidth: 3
            )
        }

        // #60 Ball shadow impact ring at court contact
        if abs(by - cB) < 15 {
            let impactPulse = CGFloat(abs(sin(t * 10))) * 6
            var impRing = ctx
            impRing.addFilter(.blur(radius: 4))
            impRing.stroke(
                Path(ellipseIn: CGRect(x: bx - 14 - impactPulse, y: cB - 3,
                                       width: 28 + impactPulse * 2, height: 8)),
                with: .color(Color.white.opacity(0.40)),
                lineWidth: 1.5
            )
        }

        // #61 Net wobble shake when ball passes near net
        if abs(by - netY) < 20 {
            let wobble = CGFloat(sin(t * 20)) * 2
            var wobblePath = Path()
            wobblePath.move(to: CGPoint(x: cL - 6, y: netY + wobble))
            wobblePath.addLine(to: CGPoint(x: cR + 6, y: netY - wobble))
            ctx.stroke(wobblePath, with: .color(Color.white.opacity(0.40)), lineWidth: 1.5)
        }

        // #62 Court edge vignette
        var vign = ctx
        vign.addFilter(.blur(radius: 18))
        vign.fill(
            Path(CGRect(x: cL, y: cT, width: 20, height: cB - cT)),
            with: .color(Color.black.opacity(0.25))
        )
        vign.fill(
            Path(CGRect(x: cR - 20, y: cT, width: 20, height: cB - cT)),
            with: .color(Color.black.opacity(0.25))
        )
    }

    // MARK: Score UI (#63–#72)

    private func drawScoreUI(_ ctx: inout GraphicsContext) {
        // #63 Set tracker background rectangles
        let setBaseY: CGFloat = cB + (H - cB) * 0.65
        let setBoxW: CGFloat = 22
        let setBoxH: CGFloat = 12
        for i in 0..<3 {
            let bx = W / 2 - 40 + CGFloat(i) * (setBoxW + 4)
            ctx.fill(
                Path(roundedRect: CGRect(x: bx, y: setBaseY, width: setBoxW, height: setBoxH), cornerRadius: 3),
                with: .color(Color(white: 0.15).opacity(0.70))
            )
            ctx.stroke(
                Path(roundedRect: CGRect(x: bx, y: setBaseY, width: setBoxW, height: setBoxH), cornerRadius: 3),
                with: .color(Color(white: 0.35).opacity(0.50)),
                lineWidth: 0.8
            )
        }

        // #64 Set tracker opponent rectangles
        for i in 0..<3 {
            let bx = W / 2 + 8 + CGFloat(i) * (setBoxW + 4)
            ctx.fill(
                Path(roundedRect: CGRect(x: bx, y: setBaseY, width: setBoxW, height: setBoxH), cornerRadius: 3),
                with: .color(Color(white: 0.15).opacity(0.70))
            )
            ctx.stroke(
                Path(roundedRect: CGRect(x: bx, y: setBaseY, width: setBoxW, height: setBoxH), cornerRadius: 3),
                with: .color(Color.red.opacity(0.35)),
                lineWidth: 0.8
            )
        }

        // #65 Serve indicator dot — near player baseline
        let servDotX: CGFloat = singL - 8
        let servDotY: CGFloat = servB + 8
        let servPulse = 1.0 + CGFloat(sin(t * 4)) * 0.2
        var servGlow = ctx
        servGlow.addFilter(.blur(radius: 4))
        servGlow.fill(
            Path(ellipseIn: CGRect(x: servDotX - 5 * servPulse, y: servDotY - 5 * servPulse,
                                   width: 10 * servPulse, height: 10 * servPulse)),
            with: .color(Color(red: 0.85, green: 0.75, blue: 0.10).opacity(0.65))
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: servDotX - 4, y: servDotY - 4, width: 8, height: 8)),
            with: .color(Color(red: 0.85, green: 0.75, blue: 0.10))
        )

        // #66 Game score dots — player side (0/15/30/40 as 4 dots)
        let dotRow1Y: CGFloat = cB + (H - cB) * 0.20
        for i in 0..<4 {
            let dotX = W * 0.30 + CGFloat(i) * 10
            ctx.fill(
                Path(ellipseIn: CGRect(x: dotX - 4, y: dotRow1Y - 4, width: 8, height: 8)),
                with: .color(Color(red: 0.85, green: 0.75, blue: 0.10).opacity(i < 2 ? 0.85 : 0.18))
            )
        }

        // #67 Game score dots — opponent side
        for i in 0..<4 {
            let dotX = W * 0.65 + CGFloat(i) * 10
            ctx.fill(
                Path(ellipseIn: CGRect(x: dotX - 4, y: dotRow1Y - 4, width: 8, height: 8)),
                with: .color(Color.red.opacity(i < 1 ? 0.85 : 0.18))
            )
        }

        // #68 Score panel separator lines
        stroke(&ctx,
               from: CGPoint(x: W * 0.25, y: dotRow1Y),
               to: CGPoint(x: W * 0.40, y: dotRow1Y),
               color: Color(red: 0.85, green: 0.75, blue: 0.10).opacity(0.25), width: 0.8)
        stroke(&ctx,
               from: CGPoint(x: W * 0.60, y: dotRow1Y),
               to: CGPoint(x: W * 0.75, y: dotRow1Y),
               color: Color.red.opacity(0.25), width: 0.8)

        // #69 Tiebreak mode banner (shown when score is close)
        // Always draw subtle tiebreak strip at net level
        var tbBanner = ctx
        tbBanner.addFilter(.blur(radius: 2))
        tbBanner.fill(
            Path(CGRect(x: W * 0.35, y: netY - 12, width: W * 0.30, height: 8)),
            with: .color(Color(red: 0.85, green: 0.75, blue: 0.10).opacity(0.08))
        )

        // #70 Tiebreak border
        ctx.stroke(
            Path(CGRect(x: W * 0.35, y: netY - 12, width: W * 0.30, height: 8)),
            with: .color(Color(red: 0.85, green: 0.75, blue: 0.10).opacity(0.20)),
            lineWidth: 0.8
        )

        // #71 Score panel glow left
        var scoreGlow = ctx
        scoreGlow.addFilter(.blur(radius: 12))
        scoreGlow.fill(
            Path(CGRect(x: 0, y: cB, width: W * 0.35, height: H - cB)),
            with: .color(Color(red: 0.85, green: 0.75, blue: 0.10).opacity(0.06))
        )

        // #72 Score panel glow right
        scoreGlow.fill(
            Path(CGRect(x: W * 0.65, y: cB, width: W * 0.35, height: H - cB)),
            with: .color(Color.red.opacity(0.06))
        )
    }

    // MARK: Atmosphere (#73–#84)

    private func drawAtmosphere(_ ctx: inout GraphicsContext) {
        let bx = ballCX; let by = ballCY

        // #73 Crowd cheer particles on ace/winner — 20 particles
        if showAce || showWinner {
            for i in 0..<20 {
                let angle = Double(i) / 20.0 * .pi * 2 + t * 1.5
                let radius = 40.0 + 30.0 * sin(t * 3 + Double(i) * 0.5)
                let px = W / 2 + CGFloat(cos(angle)) * CGFloat(radius)
                let py = CGFloat(cT * 0.5) + CGFloat(sin(angle)) * CGFloat(radius * 0.5)
                let pColors: [Color] = [.yellow, .orange, Color(red: 1, green: 0.3, blue: 0.3),
                                        .cyan, .green, .white]
                ctx.fill(
                    Path(ellipseIn: CGRect(x: px - 3, y: py - 3, width: 6, height: 6)),
                    with: .color(pColors[i % pColors.count].opacity(0.75))
                )
            }
        }

        // #74 Ball bounce ripple ring
        if abs(by - cB) < 25 {
            let rippleAge = CGFloat(fmod(t * 3, 1.0))
            let rippleR = rippleAge * 30
            ctx.stroke(
                Path(ellipseIn: CGRect(x: bx - rippleR, y: cB - rippleR * 0.35,
                                       width: rippleR * 2, height: rippleR * 0.7)),
                with: .color(Color.white.opacity(0.30 * (1 - rippleAge))),
                lineWidth: 1.5
            )
        }

        // #75 Second ripple ring (offset phase)
        if abs(by - cB) < 25 {
            let rippleAge2 = CGFloat(fmod(t * 3 + 0.5, 1.0))
            let rippleR2 = rippleAge2 * 24
            ctx.stroke(
                Path(ellipseIn: CGRect(x: bx - rippleR2, y: cB - rippleR2 * 0.35,
                                       width: rippleR2 * 2, height: rippleR2 * 0.7)),
                with: .color(Color.white.opacity(0.20 * (1 - rippleAge2))),
                lineWidth: 1.0
            )
        }

        // #76 Player sweat particles (near player)
        let playerX2 = lerp(ballCX, W * 0.5, 0.4)
        let playerY2 = cB + (H - cB) * 0.35
        if swipeOpen {
            for i in 0..<6 {
                let sweatAngle = Double(i) / 6.0 * .pi + t * 4
                let sweatDist = 8.0 + 5.0 * sin(t * 7 + Double(i))
                let sx = playerX2 + CGFloat(cos(sweatAngle)) * CGFloat(sweatDist)
                let sy = playerY2 - 8 + CGFloat(sin(sweatAngle)) * CGFloat(sweatDist * 0.4)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: sx - 2, y: sy - 2, width: 4, height: 4)),
                    with: .color(Color(red: 0.70, green: 0.88, blue: 1.0).opacity(0.55))
                )
            }
        }

        // #77 Opponent sweat particles
        let oppX2 = lerp(ballCX, W * 0.5, 0.5)
        let oppY2 = cT * 0.45
        if !swipeOpen && ballCY < netY {
            for i in 0..<5 {
                let sweatAngle2 = Double(i) / 5.0 * .pi + t * 3.5
                let sweatDist2 = 7.0 + 4.0 * cos(t * 6 + Double(i))
                let sx2 = oppX2 + CGFloat(cos(sweatAngle2)) * CGFloat(sweatDist2)
                let sy2 = oppY2 - 6 + CGFloat(sin(sweatAngle2)) * CGFloat(sweatDist2 * 0.4)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: sx2 - 1.5, y: sy2 - 1.5, width: 3, height: 3)),
                    with: .color(Color(red: 1.0, green: 0.70, blue: 0.70).opacity(0.50))
                )
            }
        }

        // #78 Sun glare stripe at top (outdoor stadium feel)
        var sunGlare = ctx
        sunGlare.addFilter(.blur(radius: 12))
        sunGlare.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: 6)),
            with: .color(Color(red: 1.0, green: 0.98, blue: 0.85).opacity(0.12))
        )

        // #79 Sun lens flare diagonal streak
        sunGlare.fill(
            Path(CGRect(x: W * 0.40, y: 0, width: W * 0.20, height: 3)),
            with: .color(Color.white.opacity(0.06))
        )

        // #80 Ambient court glow (warm light falloff)
        var courtGlow = ctx
        courtGlow.addFilter(.blur(radius: 30))
        courtGlow.fill(
            Path(CGRect(x: cL + 20, y: netY - 20, width: cR - cL - 40, height: 40)),
            with: .color(Color(red: 1.0, green: 0.96, blue: 0.75).opacity(0.08))
        )

        // #81 Net shadow on court surface
        var netShadow = ctx
        netShadow.addFilter(.blur(radius: 4))
        netShadow.fill(
            Path(CGRect(x: cL, y: netY, width: cR - cL, height: 6)),
            with: .color(Color.black.opacity(0.18))
        )

        // #82 Ball air shadow (dynamic shadow projected on court)
        if by > cT && by < cB - 10 {
            let shadowOffY = cB - 8
            let shadowSize = CGFloat(10 + (by - cT) / (cB - cT) * 8)
            var airShadow = ctx
            airShadow.addFilter(.blur(radius: shadowSize * 0.5))
            airShadow.fill(
                Path(ellipseIn: CGRect(x: bx - shadowSize, y: shadowOffY - shadowSize * 0.35,
                                       width: shadowSize * 2, height: shadowSize * 0.7)),
                with: .color(Color.black.opacity(0.28))
            )
        }

        // #83 Atmosphere haze at stands edge
        var haze = ctx
        haze.addFilter(.blur(radius: 16))
        haze.fill(
            Path(CGRect(x: 0, y: cT - 10, width: W, height: 16)),
            with: .color(Color(white: 0.6).opacity(0.06))
        )
        haze.fill(
            Path(CGRect(x: 0, y: cB - 6, width: W, height: 16)),
            with: .color(Color(white: 0.6).opacity(0.06))
        )

        // #84 Final frame vignette darkening corners
        var finalVign = ctx
        finalVign.addFilter(.blur(radius: 35))
        finalVign.fill(
            Path(CGRect(x: 0, y: 0, width: W * 0.18, height: H)),
            with: .color(Color.black.opacity(0.30))
        )
        finalVign.fill(
            Path(CGRect(x: W * 0.82, y: 0, width: W * 0.18, height: H)),
            with: .color(Color.black.opacity(0.30))
        )
        finalVign.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H * 0.12)),
            with: .color(Color.black.opacity(0.25))
        )
        finalVign.fill(
            Path(CGRect(x: 0, y: H * 0.88, width: W, height: H * 0.12)),
            with: .color(Color.black.opacity(0.25))
        )
    }

    // MARK: Swipe Zone

    private func drawSwipeZone(_ ctx: inout GraphicsContext) {
        let pulse = CGFloat(sin(t * 7)) * 3
        let zoneRect = CGRect(x: singL - pulse, y: servB - pulse,
                               width: (singR - singL) + pulse * 2,
                               height: (cB - servB) + pulse * 2)
        var gc = ctx
        gc.addFilter(.blur(radius: 8))
        gc.fill(
            Path(roundedRect: zoneRect, cornerRadius: 6),
            with: .color(Color(red: 0.3, green: 0.85, blue: 0.4).opacity(0.15))
        )
        ctx.stroke(
            Path(roundedRect: zoneRect, cornerRadius: 6),
            with: .color(Color(red: 0.3, green: 0.85, blue: 0.4).opacity(0.75)),
            lineWidth: 2.0
        )
        ctx.draw(
            Text("◆ RETURN ZONE ◆")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.3, green: 0.85, blue: 0.4).opacity(0.9)),
            at: CGPoint(x: W / 2, y: servB - 10), anchor: .center
        )
    }

    // MARK: Court Zones (6-zone opponent placement overlay)

    private func drawCourtZones(_ ctx: inout GraphicsContext) {
        guard swipeOpen || isDragging else { return }
        let halfW = singR - singL
        let halfH = netY - cT
        let zW = halfW / 2
        let zH = halfH / 3

        for zone in ShotZone.allCases {
            let col: Int = zone.isLeft ? 0 : 1
            let row: Int
            switch zone {
            case .topLeft, .topRight:       row = 0
            case .midLeft, .midRight:       row = 1
            case .bottomLeft, .bottomRight: row = 2
            }
            let zx = singL + CGFloat(col) * zW
            let zy = cT + CGFloat(row) * zH
            let zRect = CGRect(x: zx + 2, y: zy + 2, width: zW - 4, height: zH - 4)
            let isTarget = targetZone == zone
            let isCornerZone = zone.isCorner
            let fillColor: Color = isTarget
                ? Color(red: 1.0, green: 0.85, blue: 0.10)
                : Color(red: 0.20, green: 0.70, blue: 1.0)
            let fillOpacity: Double = isTarget ? 0.32 : (isCornerZone ? 0.10 : 0.05)
            var zoneFill = ctx
            if isTarget { zoneFill.addFilter(.blur(radius: 4)) }
            zoneFill.fill(Path(roundedRect: zRect, cornerRadius: 3),
                          with: .color(fillColor.opacity(fillOpacity)))
            ctx.stroke(Path(roundedRect: zRect, cornerRadius: 3),
                       with: .color(fillColor.opacity(isTarget ? 0.80 : 0.25)),
                       lineWidth: isTarget ? 1.8 : 0.8)
            if isCornerZone {
                ctx.draw(
                    Text("⬛").font(.system(size: 6))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.10).opacity(0.55)),
                    at: CGPoint(x: zx + zW / 2, y: zy + zH / 2), anchor: .center
                )
            }
        }
    }

    // MARK: Aim Arrow (dotted direction indicator during drag)

    private func drawAimArrow(_ ctx: inout GraphicsContext) {
        guard isDragging else { return }
        let fromX = dragStartNorm.x * W, fromY = dragStartNorm.y * H
        let toX   = aimReticleNorm.x * W, toY   = aimReticleNorm.y * H
        let dx = toX - fromX, dy = toY - fromY
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 8 else { return }
        let nx = dx / dist, ny = dy / dist
        let dashLen: CGFloat = 8, gapLen: CGFloat = 5, totalDash = dashLen + gapLen
        let steps = Int(dist / totalDash)
        for i in 0..<steps {
            let s = CGFloat(i) * totalDash
            let ex = min(s + dashLen, dist)
            var dash = Path()
            dash.move(to: CGPoint(x: fromX + nx * s, y: fromY + ny * s))
            dash.addLine(to: CGPoint(x: fromX + nx * ex, y: fromY + ny * ex))
            ctx.stroke(dash, with: .color(Color(red: 1.0, green: 0.92, blue: 0.20).opacity(0.80)), lineWidth: 2)
        }
        // Arrowhead
        let aLen: CGFloat = 10, aHalf: CGFloat = 5
        let ax = toX - nx * aLen, ay = toY - ny * aLen
        let px = -ny, py = nx
        var arrow = Path()
        arrow.move(to: CGPoint(x: toX, y: toY))
        arrow.addLine(to: CGPoint(x: ax + px * aHalf, y: ay + py * aHalf))
        arrow.addLine(to: CGPoint(x: ax - px * aHalf, y: ay - py * aHalf))
        arrow.closeSubpath()
        ctx.fill(arrow, with: .color(Color(red: 1.0, green: 0.92, blue: 0.20).opacity(0.90)))
        // Reticle at tip
        var glow = ctx; glow.addFilter(.blur(radius: 6))
        glow.fill(Path(ellipseIn: CGRect(x: toX - 10, y: toY - 10, width: 20, height: 20)),
                  with: .color(Color(red: 1.0, green: 0.92, blue: 0.20).opacity(0.40)))
        ctx.stroke(Path(ellipseIn: CGRect(x: toX - 7, y: toY - 7, width: 14, height: 14)),
                   with: .color(Color(red: 1.0, green: 0.92, blue: 0.20).opacity(0.90)), lineWidth: 1.8)
        stroke(&ctx, from: CGPoint(x: toX - 10, y: toY), to: CGPoint(x: toX - 5, y: toY),
               color: Color.white.opacity(0.75), width: 1.2)
        stroke(&ctx, from: CGPoint(x: toX + 5, y: toY), to: CGPoint(x: toX + 10, y: toY),
               color: Color.white.opacity(0.75), width: 1.2)
        stroke(&ctx, from: CGPoint(x: toX, y: toY - 10), to: CGPoint(x: toX, y: toY - 5),
               color: Color.white.opacity(0.75), width: 1.2)
        stroke(&ctx, from: CGPoint(x: toX, y: toY + 5), to: CGPoint(x: toX, y: toY + 10),
               color: Color.white.opacity(0.75), width: 1.2)
    }

    // MARK: Landing History Dots (mini-court overlay)

    private func drawLandingDots(_ ctx: inout GraphicsContext) {
        guard !landingDots.isEmpty else { return }
        let mcX = W - 58, mcY = H * 0.72
        let mcW: CGFloat = 48, mcH: CGFloat = 56
        ctx.fill(Path(CGRect(x: mcX, y: mcY, width: mcW, height: mcH)),
                 with: .color(Color(red: 0.10, green: 0.25, blue: 0.52).opacity(0.80)))
        ctx.stroke(Path(CGRect(x: mcX, y: mcY, width: mcW, height: mcH)),
                   with: .color(Color.white.opacity(0.30)), lineWidth: 0.8)
        let netLineY = mcY + mcH / 2
        stroke(&ctx, from: CGPoint(x: mcX, y: netLineY), to: CGPoint(x: mcX + mcW, y: netLineY),
               color: Color.white.opacity(0.50), width: 1.0)
        ctx.draw(
            Text("HISTORY").font(.system(size: 5, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.55)),
            at: CGPoint(x: mcX + mcW / 2, y: mcY - 7), anchor: .center
        )
        for dot in landingDots.suffix(8) {
            let dx = mcX + dot.normalizedPos.x * mcW
            let dy = mcY + dot.normalizedPos.y * mcH
            ctx.fill(
                Path(ellipseIn: CGRect(x: dx - 2.5, y: dy - 2.5, width: 5, height: 5)),
                with: .color(dot.isWinner
                             ? Color(red: 1.0, green: 0.85, blue: 0.10).opacity(0.90)
                             : Color(red: 0.30, green: 0.75, blue: 0.40).opacity(0.75))
            )
        }
    }

    // MARK: Ball

    private func drawBall(_ ctx: inout GraphicsContext) {
        let bx = ballCX; let by = ballCY
        let distFromNet = abs(by - netY) / (cB - netY)
        let airH = distFromNet * 0.4
        let r: CGFloat = max(6, (7 + airH * 4)) * ballScale

        // Air shadow on court
        if by > cT && by < cB {
            let shadowY = by + r * CGFloat(1 + airH * 2)
            let shadowR = r * CGFloat(0.5 + airH * 0.8)
            var sc = ctx
            sc.addFilter(.blur(radius: shadowR * 0.7))
            sc.fill(
                Path(ellipseIn: CGRect(x: bx - shadowR, y: shadowY - shadowR * 0.4,
                                       width: shadowR * 2, height: shadowR * 0.8)),
                with: .color(Color.black.opacity(0.45 - airH * 0.2))
            )
        }

        // Glow
        var glowCtx = ctx
        glowCtx.addFilter(.blur(radius: r * 1.2))
        glowCtx.fill(
            Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
            with: .color(Color(red: 0.95, green: 0.90, blue: 0.20).opacity(0.65))
        )

        // Ball body
        ctx.fill(
            Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
            with: .radialGradient(
                Gradient(colors: [Color(red: 0.95, green: 0.90, blue: 0.15),
                                   Color(red: 0.72, green: 0.68, blue: 0.08)]),
                center: CGPoint(x: bx - r * 0.25, y: by - r * 0.25),
                startRadius: 0, endRadius: r * 1.1
            )
        )

        // Seam
        var seam = Path()
        seam.addArc(center: CGPoint(x: bx, y: by), radius: r - 1.5,
                    startAngle: .degrees(-30), endAngle: .degrees(210), clockwise: false)
        ctx.stroke(seam, with: .color(Color(red: 0.50, green: 0.42, blue: 0.05).opacity(0.6)), lineWidth: 1)
    }

    // MARK: Helpers

    private func stroke(_ ctx: inout GraphicsContext, from: CGPoint, to: CGPoint,
                        color: Color, width: CGFloat) {
        var p = Path(); p.move(to: from); p.addLine(to: to)
        ctx.stroke(p, with: .color(color), lineWidth: width)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}

// MARK: - Set Stats Modal

private struct SetStatsModal: View {
    let setNumber: Int
    let acesCount: Int
    let winnersCount: Int
    let unforcedErrors: Int
    let serveAttempts: Int
    let serveIns: Int
    let onDismiss: () -> Void

    private var servePercent: Int {
        guard serveAttempts > 0 else { return 0 }
        return Int(Double(serveIns) / Double(serveAttempts) * 100)
    }
    private var winnerPercent: Int {
        let total = winnersCount + unforcedErrors
        guard total > 0 else { return 0 }
        return Int(Double(winnersCount) / Double(total) * 100)
    }
    private var mvpRating: Int {
        let total = winnersCount + unforcedErrors
        guard total > 0 else { return 50 }
        return Int(Double(winnersCount) / Double(total) * 100)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("SET \(setNumber) STATS")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.75, blue: 0.1))
                    .tracking(4)

                VStack(spacing: 14) {
                    statRow(label: "ACES", value: "\(acesCount)", color: Color(red: 0.95, green: 0.82, blue: 0.15))
                    statRow(label: "WINNERS", value: "\(winnersCount)", color: Color(red: 0.20, green: 0.80, blue: 0.40))
                    statRow(label: "UNFORCED ERRORS", value: "\(unforcedErrors)", color: Color(red: 0.90, green: 0.30, blue: 0.30))
                    statRow(label: "1ST SERVE %", value: "\(servePercent)%", color: Color(red: 0.45, green: 0.65, blue: 0.95))
                    Divider().background(Color.white.opacity(0.15))
                    statRow(label: "MVP RATING", value: "\(mvpRating)/100", color: Color(red: 0.85, green: 0.75, blue: 0.1))
                }
                .padding(20)
                .background(Color(white: 0.08).clipShape(RoundedRectangle(cornerRadius: 16)))

                Button {
                    onDismiss()
                } label: {
                    Text("CONTINUE")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.85, green: 0.75, blue: 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding(24)
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Momentum Bar

private struct MomentumBar: View {
    let momentum: Double  // 0.0–1.0

    private var isOnARoll: Bool { momentum > 0.75 }
    private var isUnderPressure: Bool { momentum < 0.25 }

    var body: some View {
        VStack(spacing: 4) {
            // Status banner
            if isOnARoll {
                Text("ON A ROLL 🔥")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.10))
                    .tracking(2)
                    .transition(.scale.combined(with: .opacity))
            } else if isUnderPressure {
                Text("UNDER PRESSURE ❄️")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.50, green: 0.80, blue: 1.00))
                    .tracking(2)
                    .transition(.scale.combined(with: .opacity))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.12))
                        .frame(height: 8)

                    // Player (blue) side – fills from left to momentum point
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.20, green: 0.55, blue: 1.00),
                                         Color(red: 0.10, green: 0.35, blue: 0.80)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(momentum), height: 8)

                    // Opponent (red) side – fills from right toward momentum point
                    HStack {
                        Spacer(minLength: geo.size.width * CGFloat(momentum))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.80, green: 0.20, blue: 0.20),
                                             Color(red: 0.95, green: 0.35, blue: 0.35)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(height: 8)
                    }

                    // Center pivot marker
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.70))
                        .frame(width: 2, height: 12)
                        .offset(x: geo.size.width / 2 - 1, y: -2)

                    // Momentum cursor
                    Circle()
                        .fill(isOnARoll ? Color(red: 0.95, green: 0.55, blue: 0.10)
                              : isUnderPressure ? Color(red: 0.50, green: 0.80, blue: 1.00)
                              : Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .offset(x: geo.size.width * CGFloat(momentum) - 6, y: -2)
                }
            }
            .frame(height: 12)

            HStack {
                Text("YOU")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.20, green: 0.55, blue: 1.00))
                Spacer()
                Text("MOMENTUM")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                Text("OPP")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
            }
        }
        .animation(.spring(response: 0.35), value: momentum)
        .padding(.horizontal, 24)
    }
}

// MARK: - Serve Type Picker

private struct ServeTypePicker: View {
    @Binding var selected: ServeType

    var body: some View {
        VStack(spacing: 6) {
            Text("SELECT SERVE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)

            HStack(spacing: 10) {
                ForEach(ServeType.allCases, id: \.self) { type in
                    Button {
                        selected = type
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: type.icon)
                                .font(.system(size: 14))
                            Text(type.rawValue)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(selected == type ? .black : type.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected == type ? type.color : type.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(type.color.opacity(selected == type ? 0 : 0.45), lineWidth: 1)
                        )
                    }
                }
            }

            Text(selected.description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .animation(.easeInOut(duration: 0.15), value: selected)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Shot Type Pad

private struct ShotTypePad: View {
    @Binding var selected: ShotType

    var body: some View {
        VStack(spacing: 6) {
            Text("SHOT TYPE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ShotType.allCases, id: \.self) { type in
                    Button {
                        selected = type
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 12))
                            Text(type.rawValue)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(selected == type ? .black : type.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected == type ? type.color : type.color.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(type.color.opacity(selected == type ? 0 : 0.40), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Challenge Overlay

private struct ChallengeReviewOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("VIDEO REVIEW")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(4)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.85, green: 0.75, blue: 0.1)))
                    .scaleEffect(1.5)
                Text("REVIEWING...")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.75, blue: 0.1))
                    .tracking(3)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Tiebreak Banner

private struct TiebreakBanner: View {
    var body: some View {
        Text("⚡ TIEBREAK ⚡")
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundStyle(.black)
            .tracking(4)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(red: 0.95, green: 0.82, blue: 0.15))
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.95, green: 0.82, blue: 0.15).opacity(0.6), radius: 12)
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - TennisGameView

struct TennisGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // MARK: Phase & Timer
    @State private var phase: TennisPhase = .ready
    @State private var timeLeft: Int = 120
    @State private var gameTimerTask: Task<Void, Never>? = nil

    // MARK: Scoring
    @State private var playerGames: Int = 0
    @State private var opponentGames: Int = 0
    @State private var playerPoints: TennisPoint = .zero
    @State private var opponentPoints: TennisPoint = .zero
    @State private var playerSets: Int = 0
    @State private var opponentSets: Int = 0

    // MARK: Tiebreak
    @State private var isTiebreak: Bool = false
    @State private var tiebreakPlayerPoints: Int = 0
    @State private var tiebreakOpponentPoints: Int = 0
    @State private var showTiebreakBanner: Bool = false

    // MARK: Ball & Rally
    @State private var ball: TennisBall = TennisBall()
    @State private var rallyTask: Task<Void, Never>? = nil
    @State private var awaitingSwipe: Bool = false
    @State private var swipeWindowOpen: Bool = false
    @State private var swipeWindowTask: Task<Void, Never>? = nil
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var isServing: Bool = true
    @State private var serveReady: Bool = false
    @State private var serveAnimating: Bool = false
    @State private var ballScale: CGFloat = 1.0
    @State private var ballOpacity: Double = 1.0
    @State private var crowdLevel: Double = 0.30

    // MARK: Canvas FX
    @State private var showAce: Bool = false
    @State private var showWinner: Bool = false
    @State private var showFault: Bool = false

    // MARK: Swipe & Drag
    @State private var dragStart: CGPoint? = nil
    private let XP_CAP_PER_SESSION = 500
    @State private var sessionXP: Int = 0

    // MARK: Drag-to-Aim System
    @State private var aimDirection: CGFloat = 0.5     // 0=crosscourt, 1=down-the-line
    @State private var aimDepth: CGFloat = 0.5         // 0=short, 1=deep
    @State private var shotDragStart: CGPoint = .zero
    @State private var isShotDragging: Bool = false
    @State private var aimReticlePos: CGPoint = CGPoint(x: 0.5, y: 0.25)
    @State private var currentTargetZone: ShotZone? = nil
    @State private var lastOpponentZone: ShotZone? = nil   // tracks where opponent covered last
    @State private var landingDots: [ShotLandingDot] = []
    @State private var showWinnerZoneFlash: Bool = false
    @State private var winnerZoneText: String = ""

    // MARK: Serve System
    @State private var serveType: ServeType = .flat
    @State private var isFirstServe: Bool = true
    @State private var firstServeFaulted: Bool = false

    // MARK: Shot Selection
    @State private var shotSelection: ShotType = .groundstroke
    @State private var showShotPad: Bool = false
    @State private var approachMode: Bool = false  // true after an approach shot — next will be volley

    // MARK: Momentum
    @State private var playerMomentum: Double = 0.5  // 0.0–1.0
    @State private var showMomentumBar: Bool = true

    // MARK: Challenge System
    @State private var challengesRemaining: Int = 1
    @State private var showChallengeReview: Bool = false
    @State private var challengeResultText: String = ""
    @State private var showChallengeResult: Bool = false
    @State private var canChallenge: Bool = false   // only available immediately after a point

    // MARK: Statistics
    @State private var acesCount: Int = 0
    @State private var winnersCount: Int = 0
    @State private var unforcedErrors: Int = 0
    @State private var serveAttempts: Int = 0
    @State private var serveIns: Int = 0
    @State private var setNumber: Int = 1
    @State private var showSetStats: Bool = false

    // Snapshot at set boundary for stats modal
    @State private var lastSetAces: Int = 0
    @State private var lastSetWinners: Int = 0
    @State private var lastSetErrors: Int = 0
    @State private var lastSetServeAttempts: Int = 0
    @State private var lastSetServeIns: Int = 0

    private let accentColor = Color(red: 0.85, green: 0.75, blue: 0.1)
    private let opponentName = "Kai Nexus"

    // MARK: - Momentum Helpers

    /// Effective accuracy bonus/penalty from momentum
    private var momentumAccuracyModifier: Double {
        if playerMomentum > 0.75 { return 0.15 }
        if playerMomentum < 0.25 { return -0.15 }
        return 0.0
    }

    private func addWinnerMomentum() {
        withAnimation(.spring(response: 0.3)) {
            playerMomentum = min(1.0, playerMomentum + 0.12)
        }
    }

    private func addErrorMomentum() {
        withAnimation(.spring(response: 0.3)) {
            playerMomentum = max(0.0, playerMomentum - 0.10)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(colors: [Color(red: 0.04, green: 0.06, blue: 0.02), Theme.deepBlack],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Rally Ace", subtitle: "2-Minute Tennis Match · Swipe to return",
                    countdown: 3, accentColor: accentColor,
                    onComplete: { startMatch() }
                )
            case .serving: servingView
            case .rally:   rallyView
            case .result:  resultView
            }

            // Overlays that appear across phases
            if showChallengeReview {
                ChallengeReviewOverlay()
                    .zIndex(10)
            }

            if showSetStats {
                SetStatsModal(
                    setNumber: setNumber - 1,
                    acesCount: lastSetAces,
                    winnersCount: lastSetWinners,
                    unforcedErrors: lastSetErrors,
                    serveAttempts: lastSetServeAttempts,
                    serveIns: lastSetServeIns
                ) {
                    withAnimation { showSetStats = false }
                }
                .zIndex(9)
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
            HStack {
                VStack(spacing: 2) {
                    Text("YOU").font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Text(isTiebreak ? "\(tiebreakPlayerPoints)" : playerPoints.display)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(.white).contentTransition(.numericText())
                }
                Spacer()
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(clockString).font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(timeLeft <= 20 ? .red : accentColor)
                        if isTiebreak {
                            Text("TB").font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle().fill(i < playerSets ? accentColor : Color.white.opacity(0.12))
                                .frame(width: 7, height: 7)
                        }
                        Text("VS").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                        ForEach(0..<3) { i in
                            Circle().fill(i < opponentSets ? Color.red : Color.white.opacity(0.12))
                                .frame(width: 7, height: 7)
                        }
                    }
                    HStack(spacing: 8) {
                        Text("\(playerGames)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
                        Text("GAMES").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                        Text("\(opponentGames)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.red)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(opponentName.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Text(isTiebreak ? "\(tiebreakOpponentPoints)" : opponentPoints.display)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55)).contentTransition(.numericText())
                }
            }.padding(.horizontal, 24)

            // Momentum bar always visible during rally/serving phases
            if phase == .rally || phase == .serving {
                MomentumBar(momentum: playerMomentum)
                    .padding(.top, 4)
            }

            Rectangle().fill(accentColor.opacity(0.25)).frame(height: 1).padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    // MARK: - Court View

    private var courtCanvas: some View {
        ZStack {
            TennisCourtCanvas(
                ballPosition: ball.position,
                ballScale: ballScale,
                swipeWindowOpen: swipeWindowOpen,
                isPlayerSide: ball.position.y > 0.5,
                phase: phase,
                feedbackText: feedbackText,
                showFeedback: showFeedback,
                crowdLevel: crowdLevel,
                showAce: showAce,
                showWinner: showWinner,
                showFault: showFault,
                aimReticleNorm: aimReticlePos,
                isDragging: isShotDragging,
                dragStartNorm: shotDragStart,
                landingDots: landingDots,
                targetZone: currentTargetZone
            )
            .animation(.easeInOut(duration: 0.55), value: ball.position)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Winner zone flash overlay
            if showWinnerZoneFlash {
                Text(winnerZoneText)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.20, green: 0.90, blue: 0.40))
                    .shadow(color: Color(red: 0.20, green: 0.90, blue: 0.40).opacity(0.7), radius: 10)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            // Tiebreak overlay banner on canvas
            if showTiebreakBanner {
                VStack {
                    TiebreakBanner()
                    Spacer()
                }
                .padding(.top, 12)
                .allowsHitTesting(false)
            }

            if showFeedback {
                Text(feedbackText)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(feedbackText == "ACE!" || feedbackText == "WINNER!" || feedbackText.contains("ROLL")
                                     ? accentColor : feedbackText.contains("PRESSURE") ? Color(red: 0.50, green: 0.80, blue: 1.0) : .red)
                    .shadow(color: accentColor.opacity(0.6), radius: 12)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 280)
        .padding(.horizontal, 16)
    }

    // MARK: - Serving View

    private var servingView: some View {
        VStack(spacing: 0) {
            scoreHeader
            Spacer()
            courtCanvas
            Spacer()

            VStack(spacing: 14) {
                // First vs Second serve label
                HStack(spacing: 8) {
                    Text(firstServeFaulted ? "2ND SERVE" : "1ST SERVE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(firstServeFaulted ? Color.red : accentColor)
                        .tracking(4)
                    if !firstServeFaulted {
                        Text("SERVE").font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor).tracking(4)
                            .hidden()  // balance layout
                    }
                }

                Text("Tap to toss, then serve").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)

                // Serve type picker — always visible before serve
                ServeTypePicker(selected: $serveType)

                if serveReady && !serveAnimating {
                    actionButton(label: "SERVE", icon: "arrow.up.circle.fill") { launchServe() }
                } else if !serveReady {
                    actionButton(label: "TOSS", icon: "hand.tap.fill") { tossBall() }
                } else {
                    Text("Tossing…").font(.system(size: 14, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 36)
        }
    }

    // MARK: - Rally View

    private var rallyView: some View {
        ZStack {
            VStack(spacing: 0) {
                scoreHeader
                Spacer()
                courtCanvas
                Spacer()

                // Aim direction hint during swipe window
                if swipeWindowOpen || isShotDragging {
                    aimDirectionHintView
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                VStack(spacing: 10) {
                    // Shot selection pad visible during rally (before swipe window opens)
                    if !swipeWindowOpen && !isShotDragging && phase == .rally {
                        ShotTypePad(selected: $shotSelection)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Return window prompt
                    if swipeWindowOpen {
                        Text(isShotDragging ? "RELEASE TO SHOOT!" : "DRAG TO AIM · RELEASE!")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(isShotDragging ? Color(red: 1.0, green: 0.92, blue: 0.20) : accentColor)
                            .tracking(2)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(approachMode ? "AT NET — VOLLEY READY" : "Watch the ball…")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(approachMode ? Color(red: 0.45, green: 0.65, blue: 0.95) : .secondary)
                    }

                    // Challenge button — available right after disputed line call
                    if canChallenge && challengesRemaining > 0 {
                        Button {
                            useChallenge()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "video.fill").font(.system(size: 12))
                                Text("CHALLENGE (\(challengesRemaining) left)")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(Color(red: 0.55, green: 0.25, blue: 0.85))
                            .clipShape(Capsule())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(minHeight: 110)
                .animation(.easeInOut(duration: 0.20), value: swipeWindowOpen)
                .animation(.easeInOut(duration: 0.20), value: showShotPad)
                .animation(.easeInOut(duration: 0.20), value: isShotDragging)
                .padding(.bottom, 20)
            }

            // Drag-to-aim gesture — captures whole screen during swipe window
            Color.clear.contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { v in
                            guard swipeWindowOpen else { return }
                            if !isShotDragging {
                                shotDragStart = normalizePoint(v.startLocation)
                                isShotDragging = true
                            }
                            let normCurrent = normalizePoint(v.location)
                            aimReticlePos = normCurrent
                            // Derive aim parameters from drag vector
                            let dx = v.location.x - v.startLocation.x
                            let dy = v.location.y - v.startLocation.y
                            aimDirection = max(0, min(1, 0.5 + dx / 200.0))
                            aimDepth = max(0, min(1, 1.0 - (dy / 120.0))) // drag up = deeper
                            currentTargetZone = ShotZone.fromAim(aimX: aimDirection, aimDepth: aimDepth)
                        }
                        .onEnded { v in
                            let wasDragging = isShotDragging
                            isShotDragging = false
                            shotDragStart = .zero
                            if swipeWindowOpen {
                                if wasDragging {
                                    // Use aim-based shot
                                    handleAimedShot(dx: v.translation.width, dy: v.translation.height)
                                } else {
                                    handlePlayerSwipe(detectSwipe(from: v.startLocation, to: v.location))
                                }
                            }
                            currentTargetZone = nil
                            dragStart = nil
                        }
                )
        }
    }

    // MARK: - Aim Direction Hint View

    private var aimDirectionHintView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AIM").font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(2)
                HStack(spacing: 4) {
                    Text(aimDirection < 0.4 ? "CROSSCOURT ◀" : aimDirection > 0.6 ? "▶ DOWN-THE-LINE" : "CENTER")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.92, blue: 0.20))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("DEPTH").font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(2)
                Text(aimDepth > 0.66 ? "DEEP ↑" : aimDepth < 0.33 ? "SHORT ↓" : "MID")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.92, blue: 0.20))
            }
            if let zone = currentTargetZone {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ZONE").font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Text(zone.isCorner ? "CORNER!" : zone.isWide ? "WIDE" : "CENTRE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(zone.isCorner
                                         ? Color(red: 0.20, green: 0.90, blue: 0.40)
                                         : Color(red: 1.0, green: 0.92, blue: 0.20))
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Theme.cardBackground.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.spring(response: 0.15), value: aimDirection)
        .animation(.spring(response: 0.15), value: aimDepth)
    }

    // MARK: - Result View

    private var resultView: some View {
        let playerWon = playerSets > opponentSets || (playerSets == opponentSets && playerGames > opponentGames)
        let isDraw    = playerSets == opponentSets && playerGames == opponentGames
        let shards    = isDraw ? 25 : (playerWon ? 50 : 15)
        return ResultScreen(
            winner: isDraw ? .draw : (playerWon ? .p1 : .p2),
            p1Score: playerGames, p2Score: opponentGames,
            title: "Rally Ace · Tennis", accentColor: accentColor,
            prqGain: playerWon ? 12 : (isDraw ? 6 : 2),
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "Rally",
            modeAttributeValue: playerGames > 0 ? Double(playerGames) / Double(max(1, playerGames + opponentGames)) : 0,
            onReturn: { viewModel.profile.evolutionShards += shards; dismiss() }
        )
    }

    // MARK: - Reusable button

    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.system(size: 18, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(accentColor).clipShape(.rect(cornerRadius: 14))
        }
        .padding(.horizontal, 40)
    }

    // MARK: - FX Helpers

    private func triggerAce() {
        showAce = true
        TennisHaptic.ace()
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run { showAce = false }
        }
    }

    private func triggerWinner() {
        showWinner = true
        TennisHaptic.hit()
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run { showWinner = false }
        }
    }

    private func triggerFault() {
        showFault = true
        TennisHaptic.fault()
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run { showFault = false }
        }
    }

    // MARK: - Momentum Banner Helpers

    private func checkMomentumBanners() {
        if playerMomentum > 0.75 {
            flashFeedback("ON A ROLL!")
        } else if playerMomentum < 0.25 {
            flashFeedback("UNDER PRESSURE!")
        }
    }

    // MARK: - Challenge System

    private func useChallenge() {
        guard challengesRemaining > 0, !showChallengeReview else { return }
        challengesRemaining -= 1
        canChallenge = false
        TennisHaptic.challenge()

        withAnimation { showChallengeReview = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation { showChallengeReview = false }
                // 50/50 outcome for challenge
                let success = Bool.random()
                if success {
                    challengeResultText = "CALL OVERTURNED — POINT REPLAYED"
                    // Give point back
                    flashFeedback("CHALLENGE!")
                    addWinnerMomentum()
                    scheduleNextRallyOrServe(playerServes: true)
                } else {
                    challengeResultText = "CALL CONFIRMED — POINT STANDS"
                    flashFeedback("OUT!")
                }
                showChallengeResult = true
                Task {
                    try? await Task.sleep(for: .milliseconds(2000))
                    await MainActor.run { showChallengeResult = false }
                }
            }
        }
    }

    // MARK: - Tiebreak Logic

    private var tiebreakScoreDisplay: String {
        "\(tiebreakPlayerPoints)–\(tiebreakOpponentPoints)"
    }

    private func enterTiebreak() {
        isTiebreak = true
        tiebreakPlayerPoints = 0
        tiebreakOpponentPoints = 0
        withAnimation(.spring(response: 0.3)) { showTiebreakBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { withAnimation { showTiebreakBanner = false } }
        }
        flashFeedback("TIEBREAK!")
    }

    private func tiebreakPlayerWinsPoint() {
        withAnimation { tiebreakPlayerPoints += 1 }
        checkTiebreakWin()
    }

    private func tiebreakOpponentWinsPoint() {
        withAnimation { tiebreakOpponentPoints += 1 }
        checkTiebreakWin()
    }

    private func checkTiebreakWin() {
        let pp = tiebreakPlayerPoints; let op = tiebreakOpponentPoints
        if pp >= 7 && pp - op >= 2 {
            isTiebreak = false
            playerWinsSet()
        } else if op >= 7 && op - pp >= 2 {
            isTiebreak = false
            opponentWinsSet()
        } else {
            scheduleNextRallyOrServe(playerServes: tiebreakPlayerPoints % 2 == 0)
        }
    }

    // MARK: - Helpers

    private var clockString: String { String(format: "%d:%02d", timeLeft / 60, timeLeft % 60) }

    private func startMatch() {
        ball.position = CGPoint(x: 0.5, y: 0.8)
        isServing = true; serveReady = false; serveAnimating = false
        firstServeFaulted = false
        phase = .serving; startGameTimer()
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

    private func tossBall() {
        serveAnimating = true
        withAnimation(.easeOut(duration: 0.4)) {
            ball.position = CGPoint(x: 0.5, y: 0.62)
            ballScale = 0.8
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                serveAnimating = false
                serveReady = true
                withAnimation(.spring(response: 0.2)) { ballScale = 1.2 }
            }
        }
    }

    private func launchServe() {
        serveReady = false; serveAnimating = true
        serveAttempts += 1

        // Determine if serve lands in based on serve type probability
        let inProb = serveType.inProbability + momentumAccuracyModifier * 0.5
        let landedIn = Double.random(in: 0...1) < inProb

        let dir: CGFloat = Bool.random() ? -0.2 : 0.2
        TennisHaptic.bounce()

        // Ball arc varies by serve type
        let arcY: CGFloat
        switch serveType {
        case .flat:  arcY = 0.16   // fast, low arc
        case .slice: arcY = 0.20   // mid arc, curves
        case .kick:  arcY = 0.25   // higher bounce
        }

        withAnimation(.easeIn(duration: 0.5)) {
            ball.position = CGPoint(x: 0.5 + dir, y: arcY)
            ballScale = 0.75
        }

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                if landedIn {
                    serveIns += 1
                    firstServeFaulted = false
                    isFirstServe = true
                    phase = .rally
                    beginRally(fromOpponent: false)
                } else {
                    triggerFault()
                    if firstServeFaulted {
                        // Double fault
                        flashFeedback("DOUBLE FAULT!")
                        TennisHaptic.doubleFault()
                        unforcedErrors += 1
                        addErrorMomentum()
                        firstServeFaulted = false
                        isFirstServe = true
                        opponentWinsPoint()
                    } else {
                        // First fault — choose serve type for second serve
                        flashFeedback("FAULT!")
                        firstServeFaulted = true
                        serveReady = false; serveAnimating = false
                        // Reset ball position for second serve
                        withAnimation(.easeOut(duration: 0.3)) {
                            ball.position = CGPoint(x: 0.5, y: 0.8)
                            ballScale = 1.0
                        }
                    }
                }
            }
        }
    }

    private func beginRally(fromOpponent: Bool) {
        rallyTask?.cancel(); awaitingSwipe = false; swipeWindowOpen = false
        canChallenge = false
        rallyTask = Task {
            let targetX = CGFloat.random(in: 0.25...0.75)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) {
                    ball.position = fromOpponent ? CGPoint(x: targetX, y: 0.75) : CGPoint(x: targetX, y: 0.22)
                    ballScale = fromOpponent ? 1.0 : 0.7
                }
            }
            TennisHaptic.bounce()
            if fromOpponent {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation { swipeWindowOpen = true }
                    awaitingSwipe = true
                    openSwipeWindow()
                }
            } else {
                let delay = Double.random(in: 0.8...1.4)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await MainActor.run { opponentResponds() }
            }
        }
    }

    private func openSwipeWindow() {
        swipeWindowTask?.cancel()
        swipeWindowTask = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if awaitingSwipe {
                    awaitingSwipe = false
                    swipeWindowOpen = false
                    flashFeedback("MISS!")
                    triggerFault()
                    unforcedErrors += 1
                    addErrorMomentum()
                    canChallenge = true
                    opponentWinsPoint()
                }
            }
        }
    }

    private func handlePlayerSwipe(_ dir: SwipeDir) {
        guard awaitingSwipe else { return }
        awaitingSwipe = false; swipeWindowOpen = false; swipeWindowTask?.cancel()
        TennisHaptic.hit()

        if dir != .none {
            // Resolve shot based on selected shot type and momentum
            resolveShot(direction: dir)
        } else {
            flashFeedback("MISS!")
            triggerFault()
            unforcedErrors += 1
            addErrorMomentum()
            canChallenge = true
            opponentWinsPoint()
        }
    }

    // MARK: - Drag-to-Aim Handlers

    private func normalizePoint(_ p: CGPoint) -> CGPoint {
        // Normalize screen point to 0–1 based on approximate canvas rect
        // Canvas is at y≈160 with height 280 in a ~375pt wide screen
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        return CGPoint(x: max(0, min(1, p.x / screenW)),
                       y: max(0, min(1, p.y / screenH)))
    }

    private func handleAimedShot(dx: CGFloat, dy: CGFloat) {
        guard awaitingSwipe else { return }
        awaitingSwipe = false
        swipeWindowOpen = false
        swipeWindowTask?.cancel()

        // Determine base swipe direction from total drag
        let swipeDir: SwipeDir
        if abs(dx) > abs(dy) { swipeDir = dx < 0 ? .left : .right }
        else if dy < -20    { swipeDir = .up }
        else                { swipeDir = .none }

        guard swipeDir != .none else {
            flashFeedback("MISS!")
            triggerFault()
            unforcedErrors += 1
            addErrorMomentum()
            canChallenge = true
            opponentWinsPoint()
            return
        }

        TennisHaptic.hit()
        resolveShotWithAim(direction: swipeDir, zone: currentTargetZone)
    }

    // MARK: - Shot Resolution

    private func resolveShot(direction: SwipeDir) {
        resolveShotWithAim(direction: direction, zone: nil)
    }

    private func resolveShotWithAim(direction: SwipeDir, zone: ShotZone?) {
        let baseWinnerProb = shotSelection.winnerProbability + momentumAccuracyModifier
        let clampedProb = max(0.05, min(0.90, baseWinnerProb))

        // Use aimed zone target if available, otherwise fallback to swipe direction
        let targetPos: CGPoint
        if let zone = zone {
            targetPos = zone.normalizedTarget
        } else {
            let shotX = direction == .left ? CGFloat.random(in: 0.15...0.4) : CGFloat.random(in: 0.6...0.85)
            targetPos = CGPoint(x: shotX, y: 0.15)
        }

        // Placement bonuses
        var placementBonus: Double = 0
        var placementLabel: String? = nil
        if let zone = zone {
            if zone.isCorner {
                placementBonus = 0.12
                placementLabel = "WINNER ZONE!"
            } else if zone.isWide {
                placementBonus = 0.06
                // If opponent is on opposite side, opening is bigger
                if let lastZone = lastOpponentZone, lastZone.isLeft != zone.isLeft {
                    placementBonus += 0.10
                    placementLabel = "PASSING SHOT!"
                }
            }
        }

        // Perfect crosscourt + perfect timing → ACE attempt
        let isPerfectCrosscourt = zone == .topLeft || zone == .topRight
        let isPerfectTiming = shotSelection == .groundstroke && momentumAccuracyModifier > 0
        let aceAttempt = isPerfectCrosscourt && isPerfectTiming

        // Landing dot for mini-court
        var dotIsWinner = false

        switch shotSelection {

        case .groundstroke:
            crowdLevel = min(1.0, crowdLevel + 0.08)
            let finalProb = clampedProb + placementBonus
            let isWinner = Double.random(in: 0...1) < finalProb
            if isWinner {
                dotIsWinner = true
                let label = aceAttempt ? "ACE!" : (placementLabel ?? "WINNER!")
                flashFeedback(label)
                if aceAttempt { triggerAce(); acesCount += 1 } else { triggerWinner() }
                winnersCount += 1
                addWinnerMomentum()
                checkMomentumBanners()
                crowdLevel = min(1.0, crowdLevel + 0.15)
                animateBallShot(to: targetPos)
                if let label = placementLabel { flashWinnerZone(label) }
                awardPlayerPoint()
            } else {
                flashFeedback("GREAT SHOT!")
                animateBallShot(to: targetPos)
                // Opponent covers aimed zone — track for next rally
                lastOpponentZone = zone
                continueRally()
            }
            approachMode = false

        case .lob:
            let opponentMissesLob = Double.random(in: 0...1) < (0.25 + momentumAccuracyModifier * 0.5 + placementBonus)
            crowdLevel = min(1.0, crowdLevel + 0.10)
            if opponentMissesLob {
                dotIsWinner = true
                flashFeedback("LOB WINNER!")
                triggerWinner(); winnersCount += 1
                addWinnerMomentum(); checkMomentumBanners()
                animateBallShot(to: CGPoint(x: targetPos.x, y: 0.10))
                awardPlayerPoint()
            } else {
                flashFeedback("GREAT LOB!")
                animateBallShot(to: CGPoint(x: targetPos.x, y: 0.12))
                lastOpponentZone = zone
                continueRally()
            }
            approachMode = false

        case .dropShot:
            let dropWins = Double.random(in: 0...1) < (0.30 + momentumAccuracyModifier * 0.5 + placementBonus)
            crowdLevel = min(1.0, crowdLevel + 0.12)
            if dropWins {
                dotIsWinner = true
                flashFeedback("DROP SHOT!")
                triggerWinner(); winnersCount += 1
                addWinnerMomentum(); checkMomentumBanners()
                animateBallShot(to: CGPoint(x: targetPos.x, y: 0.32))
                awardPlayerPoint()
            } else {
                flashFeedback("TRICKY DROP!")
                animateBallShot(to: CGPoint(x: targetPos.x, y: 0.30))
                lastOpponentZone = zone
                continueRally()
            }
            approachMode = false

        case .approach:
            flashFeedback("APPROACHING NET!")
            crowdLevel = min(1.0, crowdLevel + 0.05)
            animateBallShot(to: CGPoint(x: targetPos.x, y: 0.30))
            approachMode = true
            lastOpponentZone = zone
            continueRally()
        }

        // Record landing dot for mini-court history
        if let zone = zone {
            let dot = ShotLandingDot(normalizedPos: zone.normalizedTarget, isWinner: dotIsWinner)
            landingDots.append(dot)
            if landingDots.count > 20 { landingDots.removeFirst() }
        }
    }

    private func flashWinnerZone(_ text: String) {
        winnerZoneText = text
        withAnimation(.spring(response: 0.2)) { showWinnerZoneFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { showWinnerZoneFlash = false } }
        }
    }

    // MARK: - Helpers for shot resolution

    private func animateBallShot(to position: CGPoint) {
        withAnimation(.easeIn(duration: 0.45)) {
            ball.position = position
            ballScale = 0.7
        }
    }

    private func awardPlayerPoint() {
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { playerWinsPoint() }
        }
    }

    private func continueRally() {
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { beginRally(fromOpponent: false) }
        }
    }

    // MARK: - Opponent AI

    private func opponentResponds() {
        let prq = viewModel.effectiveMetrics.prqScore
        // Opponent is more accurate when player is under pressure
        let opponentBoost = playerMomentum < 0.25 ? 0.15 : 0.0
        let returnChance = 0.45 + (prq / 200.0) + opponentBoost

        if Double.random(in: 0...1) < returnChance {
            beginRally(fromOpponent: true)
        } else {
            flashFeedback("ACE!")
            triggerAce()
            acesCount += 1
            winnersCount += 1
            addWinnerMomentum()
            checkMomentumBanners()
            playerWinsPoint()
        }
    }

    // MARK: - Point / Game / Set Logic

    private func playerWinsPoint() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        canChallenge = false
        if isTiebreak {
            tiebreakPlayerWinsPoint()
            return
        }
        withAnimation {
            if playerPoints == .forty { playerWinsGame() }
            else { playerPoints = playerPoints.next ?? .zero }
        }
        scheduleNextRallyOrServe(playerServes: false)
    }

    private func opponentWinsPoint() {
        canChallenge = false
        if isTiebreak {
            tiebreakOpponentWinsPoint()
            return
        }
        withAnimation {
            if opponentPoints == .forty {
                TennisHaptic.doubleFault()
                opponentWinsGame()
            } else {
                opponentPoints = opponentPoints.next ?? .zero
            }
        }
        scheduleNextRallyOrServe(playerServes: true)
    }

    private func playerWinsGame() {
        playerPoints = .zero; opponentPoints = .zero; playerGames += 1
        checkForTiebreak()
        if !isTiebreak {
            if playerGames >= 6 && playerGames - opponentGames >= 2 { playerWinsSet() }
        }
    }

    private func opponentWinsGame() {
        playerPoints = .zero; opponentPoints = .zero; opponentGames += 1
        checkForTiebreak()
        if !isTiebreak {
            if opponentGames >= 6 && opponentGames - playerGames >= 2 { opponentWinsSet() }
        }
    }

    /// Check and trigger tiebreak when both players reach 6 games
    private func checkForTiebreak() {
        if playerGames == 6 && opponentGames == 6 && !isTiebreak {
            enterTiebreak()
        }
    }

    private func playerWinsSet() {
        captureSetStats()
        playerGames = 0; opponentGames = 0; playerSets += 1
        setNumber += 1
        showSetStatsModal()
        if playerSets >= 2 {
            Task {
                try? await Task.sleep(for: .milliseconds(2200))
                await MainActor.run { endMatch() }
            }
        }
    }

    private func opponentWinsSet() {
        captureSetStats()
        playerGames = 0; opponentGames = 0; opponentSets += 1
        setNumber += 1
        showSetStatsModal()
        if opponentSets >= 2 {
            Task {
                try? await Task.sleep(for: .milliseconds(2200))
                await MainActor.run { endMatch() }
            }
        }
    }

    // MARK: - Set Stats

    private func captureSetStats() {
        lastSetAces = acesCount
        lastSetWinners = winnersCount
        lastSetErrors = unforcedErrors
        lastSetServeAttempts = serveAttempts
        lastSetServeIns = serveIns
        // Reset rolling stats for next set
        acesCount = 0; winnersCount = 0; unforcedErrors = 0
        serveAttempts = 0; serveIns = 0
    }

    private func showSetStatsModal() {
        withAnimation(.spring(response: 0.35)) { showSetStats = true }
    }

    // MARK: - Scheduling

    private func scheduleNextRallyOrServe(playerServes: Bool) {
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run {
                guard phase == .rally || phase == .serving else { return }
                isServing = true
                serveReady = false
                serveAnimating = false
                firstServeFaulted = false
                approachMode = false
                ball.position = playerServes ? CGPoint(x: 0.5, y: 0.82) : CGPoint(x: 0.5, y: 0.18)
                phase = .serving
            }
        }
    }

    private func endMatch() {
        cancelAllTasks()
        let won = playerSets > opponentSets || (playerSets == opponentSets && playerGames > opponentGames)
        GameResultService.saveResult(
            modeId: "tennis",
            userScore: playerGames,
            opponentScore: opponentGames,
            prqDelta: won ? 12 : 2
        )
        withAnimation(.spring(response: 0.4)) { phase = .result }
    }

    private func detectSwipe(from start: CGPoint, to end: CGPoint) -> SwipeDir {
        let dx = end.x - start.x; let dy = end.y - start.y
        let threshold: CGFloat = 20
        if abs(dx) > abs(dy) && abs(dx) > threshold { return dx < 0 ? .left : .right }
        else if dy < -threshold { return .up }
        return .none
    }

    private func flashFeedback(_ text: String) {
        feedbackText = text
        withAnimation(.spring(response: 0.2)) { showFeedback = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { showFeedback = false } }
        }
    }

    private func cancelAllTasks() { gameTimerTask?.cancel(); rallyTask?.cancel(); swipeWindowTask?.cancel() }
}
