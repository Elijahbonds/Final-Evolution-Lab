import SwiftUI
import UIKit

// MARK: - Phase

private enum GymnasticsPhase {
    case ready, active, elementFeedback, judging, result
}

// MARK: - Swipe Direction

private enum GymnasticsSwipeDir: String {
    case up      = "↑"
    case down    = "↓"
    case left    = "←"
    case right   = "→"
    case upRight = "↗"
    case upLeft  = "↖"

    var systemImage: String {
        switch self {
        case .up:      return "arrow.up"
        case .down:    return "arrow.down"
        case .left:    return "arrow.left"
        case .right:   return "arrow.right"
        case .upRight: return "arrow.up.right"
        case .upLeft:  return "arrow.up.left"
        }
    }
}

// MARK: - Timing Grade

private enum TimingGrade: String {
    case perfect = "PERFECT"
    case good    = "GOOD"
    case late    = "LATE"
    case miss    = "MISS"

    var points: Int {
        switch self {
        case .perfect: return 10
        case .good:    return 7
        case .late:    return 4
        case .miss:    return 0
        }
    }

    var color: Color {
        switch self {
        case .perfect: return .yellow
        case .good:    return Theme.brandCyan
        case .late:    return Theme.brandBlue
        case .miss:    return .red
        }
    }
}

// MARK: - Gymnastics Element

private struct GymnasticsElement: Identifiable {
    let id = UUID()
    let name: String
    let prompt: String
    let direction: GymnasticsSwipeDir
}

private let kRoutineElements: [GymnasticsElement] = [
    GymnasticsElement(name: "Tumble",   prompt: "TUMBLE",   direction: .upRight),
    GymnasticsElement(name: "Vault",    prompt: "VAULT",    direction: .up),
    GymnasticsElement(name: "Leap",     prompt: "LEAP",     direction: .upLeft),
    GymnasticsElement(name: "Turn",     prompt: "TURN",     direction: .left),
    GymnasticsElement(name: "Jump",     prompt: "JUMP",     direction: .up),
    GymnasticsElement(name: "Dismount", prompt: "DISMOUNT", direction: .right),
]

// MARK: - Element Result

private struct GymElementResult {
    let element: GymnasticsElement
    let grade: TimingGrade
    let rawPoints: Int
    let deduction: Double
    let finalPoints: Double
    let judge1: Double
    let judge2: Double
    let judge3: Double
}

// MARK: - Gymnastics Move Enum

private enum GymnasticsMove {
    case idle, backflip, handstand, split, aerial, cartwheel, pike, walkover
}

// MARK: - Ease helper

private func easeInOut(_ t: Double) -> Double {
    return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
}

// MARK: - GymnasticsArenaCanvas (full AAA arena background, 60fps)

private struct GymnasticsArenaCanvas: View {
    let elementIndex: Int
    let gradeColor: Color
    let showFlash: Bool
    let lastGrade: TimingGrade?
    let timingProgress: Double   // 0→1 over element window

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var drawer = ArenaDrawer(
                    t: t, W: size.width, H: size.height,
                    elementIndex: elementIndex,
                    gradeColor: gradeColor,
                    showFlash: showFlash,
                    lastGrade: lastGrade,
                    timingProgress: timingProgress
                )
                drawer.render(ctx: &ctx)
            }
        }
    }
}

private struct ArenaDrawer {
    let t: Double
    let W: CGFloat
    let H: CGFloat
    let elementIndex: Int
    let gradeColor: Color
    let showFlash: Bool
    let lastGrade: TimingGrade?
    let timingProgress: Double

    var matY: CGFloat { H * 0.62 }
    var matH: CGFloat { H * 0.20 }
    var matX: CGFloat { W * 0.06 }
    var matW: CGFloat { W * 0.88 }
    var cx: CGFloat   { W * 0.50 }
    var cy: CGFloat   { matY - 2 }

    mutating func render(ctx: inout GraphicsContext) {
        drawMuscleBSky(&ctx)        // 1 — California sky + sun
        drawOceanStrip(&ctx)        // 2 — ocean horizon + waves
        drawBoardwalk(&ctx)         // 3 — concrete boardwalk
        drawSandBehindFence(&ctx)   // 4 — beach sand strip
        drawChainLinkFence(&ctx)    // 5 — chain-link backdrop
        drawPalmTrees(&ctx)         // 6 — 3 palm trees with swaying fronds
        drawPerformanceStage(&ctx)  // 7 — outdoor concrete platform + scaffolding
        drawGymnasticsRings(&ctx)   // 8 — iconic Muscle Beach rings apparatus
        drawOutdoorCrowd(&ctx)      // 9 — Venice Beach spectators
        drawVignette(&ctx)          // 10 — edge depth vignette
        drawMatSurface(&ctx)        // 11-15
        drawSpringGrid(&ctx)        // 16-20
        drawGymnast(&ctx)           // 21-50+
        drawScorePopEffects(&ctx)   // 51-60
        if showFlash { drawScreenFlash(&ctx) } // 61
    }

    // MARK: 1 — Muscle Beach California sky gradient + sun glow
    private func drawMuscleBSky(_ ctx: inout GraphicsContext) {
        // Sky: warm California blue from top to horizon
        let horizonY = H * 0.38
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: horizonY)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.25, green: 0.52, blue: 0.85), location: 0),
                    .init(color: Color(red: 0.65, green: 0.82, blue: 0.95), location: 1.0),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: horizonY)
            )
        )
        // Below horizon — concrete/ground zone fills rest of bg
        ctx.fill(
            Path(CGRect(x: 0, y: horizonY, width: W, height: H - horizonY)),
            with: .color(Color(red: 0.78, green: 0.76, blue: 0.72))
        )
        // Sun glow in upper-right corner
        var sunGlow = ctx
        sunGlow.addFilter(.blur(radius: 38))
        sunGlow.fill(
            Path(ellipseIn: CGRect(x: W * 0.72, y: -18, width: 90, height: 90)),
            with: .color(Color(red: 1.0, green: 0.78, blue: 0.30).opacity(0.72))
        )
        // Crisp sun disc
        var sunDisc = ctx
        sunDisc.addFilter(.blur(radius: 5))
        sunDisc.fill(
            Path(ellipseIn: CGRect(x: W * 0.82, y: 6, width: 36, height: 36)),
            with: .color(Color(red: 1.0, green: 0.95, blue: 0.70).opacity(0.90))
        )
    }

    // MARK: 2 — Ocean strip at horizon with wave shimmer
    private func drawOceanStrip(_ ctx: inout GraphicsContext) {
        let horizonY = H * 0.38
        let oceanH: CGFloat = H * 0.055
        // Flat ocean fill
        ctx.fill(
            Path(CGRect(x: 0, y: horizonY, width: W, height: oceanH)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.35, green: 0.62, blue: 0.88),
                    Color(red: 0.42, green: 0.68, blue: 0.90),
                ]),
                startPoint: CGPoint(x: 0, y: horizonY),
                endPoint: CGPoint(x: 0, y: horizonY + oceanH)
            )
        )
        // Wave shimmer lines
        let waveCount = 5
        for i in 0..<waveCount {
            let phase = Double(i) * 0.9
            let wy = horizonY + oceanH * CGFloat(i + 1) / CGFloat(waveCount + 1)
            var wave = Path()
            let steps = 24
            for s in 0...steps {
                let wx = W * CGFloat(s) / CGFloat(steps)
                let amp: CGFloat = 2.0
                let wOffset = CGFloat(sin(t * 0.7 + phase + Double(s) * 0.55)) * amp
                if s == 0 {
                    wave.move(to: CGPoint(x: wx, y: wy + wOffset))
                } else {
                    wave.addLine(to: CGPoint(x: wx, y: wy + wOffset))
                }
            }
            ctx.stroke(wave, with: .color(Color.white.opacity(0.22)), lineWidth: 0.8)
        }
    }

    // MARK: 3 — Boardwalk concrete strip below ocean
    private func drawBoardwalk(_ ctx: inout GraphicsContext) {
        let boardwalkY = H * 0.435
        let boardwalkH: CGFloat = H * 0.06
        ctx.fill(
            Path(CGRect(x: 0, y: boardwalkY, width: W, height: boardwalkH)),
            with: .color(Color(red: 0.78, green: 0.76, blue: 0.72))
        )
        // Concrete seam lines
        for i in 0..<5 {
            let sy = boardwalkY + boardwalkH * CGFloat(i) / 4.0
            var seam = Path()
            seam.move(to: CGPoint(x: 0, y: sy))
            seam.addLine(to: CGPoint(x: W, y: sy))
            ctx.stroke(seam, with: .color(Color(red: 0.65, green: 0.63, blue: 0.60).opacity(0.45)), lineWidth: 0.6)
        }
    }

    // MARK: 4 — Sand/beach visible behind fence in distance
    private func drawSandBehindFence(_ ctx: inout GraphicsContext) {
        let sandY = H * 0.435
        let sandH: CGFloat = H * 0.055
        ctx.fill(
            Path(CGRect(x: 0, y: sandY, width: W, height: sandH)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.82, green: 0.76, blue: 0.60),
                    Color(red: 0.76, green: 0.70, blue: 0.55),
                ]),
                startPoint: CGPoint(x: 0, y: sandY),
                endPoint: CGPoint(x: 0, y: sandY + sandH)
            )
        )
    }

    // MARK: 5 — Chain-link fence backdrop
    private func drawChainLinkFence(_ ctx: inout GraphicsContext) {
        let fenceTop: CGFloat = H * 0.30
        let fenceBot: CGFloat = H * 0.50
        let fenceH = fenceBot - fenceTop
        // Fence background tint
        ctx.fill(
            Path(CGRect(x: 0, y: fenceTop, width: W, height: fenceH)),
            with: .color(Color(red: 0.32, green: 0.33, blue: 0.34).opacity(0.18))
        )
        // Vertical wire lines
        let cellW: CGFloat = 14
        let colCount = Int(W / cellW) + 1
        for c in 0..<colCount {
            let fx = CGFloat(c) * cellW
            var vline = Path()
            vline.move(to: CGPoint(x: fx, y: fenceTop))
            vline.addLine(to: CGPoint(x: fx, y: fenceBot))
            ctx.stroke(vline, with: .color(Color(red: 0.45, green: 0.46, blue: 0.47).opacity(0.30)), lineWidth: 0.5)
        }
        // Horizontal wire lines
        let cellH: CGFloat = 12
        let rowCount = Int(fenceH / cellH) + 1
        for r in 0..<rowCount {
            let fy = fenceTop + CGFloat(r) * cellH
            var hline = Path()
            hline.move(to: CGPoint(x: 0, y: fy))
            hline.addLine(to: CGPoint(x: W, y: fy))
            ctx.stroke(hline, with: .color(Color(red: 0.45, green: 0.46, blue: 0.47).opacity(0.25)), lineWidth: 0.5)
        }
        // Top fence rail
        ctx.fill(
            Path(CGRect(x: 0, y: fenceTop - 2, width: W, height: 4)),
            with: .color(Color(red: 0.50, green: 0.50, blue: 0.52).opacity(0.70))
        )
        // Bottom fence rail
        ctx.fill(
            Path(CGRect(x: 0, y: fenceBot - 2, width: W, height: 4)),
            with: .color(Color(red: 0.50, green: 0.50, blue: 0.52).opacity(0.70))
        )
    }

    // MARK: 6 — Palm trees: 2 left side, 1 right
    private func drawPalmTrees(_ ctx: inout GraphicsContext) {
        let trunkColor  = Color(red: 0.38, green: 0.26, blue: 0.14)
        let frondColor  = Color(red: 0.22, green: 0.55, blue: 0.20)
        let treeData: [(baseX: CGFloat, baseY: CGFloat, tilt: CGFloat, idx: Int)] = [
            (W * 0.04, H * 0.62, -0.12, 0),
            (W * 0.14, H * 0.60, 0.08,  1),
            (W * 0.90, H * 0.61, 0.10,  2),
        ]
        for tree in treeData {
            let sway = CGFloat(sin(t * 0.9 + Double(tree.idx) * 1.4)) * 3.0 * (.pi / 180)
            let totalAngle = tree.tilt + sway

            // Draw segmented trunk
            let trunkH: CGFloat = H * 0.25
            let segments = 8
            var prevX = tree.baseX
            var prevY = tree.baseY
            for seg in 0..<segments {
                let progress = CGFloat(seg + 1) / CGFloat(segments)
                let segSway = CGFloat(sin(t * 0.9 + Double(tree.idx) * 1.4 + Double(seg) * 0.3)) * 1.5 * (.pi / 180) * progress
                let angle = totalAngle + segSway - (.pi / 2)
                let segLen = trunkH / CGFloat(segments)
                let nextX = prevX + cos(angle) * segLen
                let nextY = prevY + sin(angle) * segLen
                let segW = 6.0 * (1.0 - progress * 0.4)
                var seg_path = Path()
                seg_path.move(to: CGPoint(x: prevX, y: prevY))
                seg_path.addLine(to: CGPoint(x: nextX, y: nextY))
                ctx.stroke(seg_path, with: .color(trunkColor.opacity(0.90)), lineWidth: segW)
                // Trunk ring marks
                if seg % 2 == 1 {
                    ctx.stroke(seg_path, with: .color(Color(red: 0.28, green: 0.18, blue: 0.08).opacity(0.40)), lineWidth: segW * 0.4)
                }
                prevX = nextX
                prevY = nextY
            }

            let tipX = prevX
            let tipY = prevY

            // Draw palm fronds radiating from tip
            let frondAngles: [CGFloat] = [-1.4, -0.9, -0.4, 0.1, 0.6, 1.1, 1.6, -1.9]
            for (fi, baseAngle) in frondAngles.enumerated() {
                let frondSway = CGFloat(sin(t * 0.9 + Double(tree.idx) * 1.4 + Double(fi) * 0.7)) * 3.0 * (.pi / 180)
                let angle = baseAngle + frondSway + totalAngle
                let frondLen: CGFloat = 26
                let midX = tipX + cos(angle) * frondLen * 0.55
                let midY = tipY + sin(angle) * frondLen * 0.55
                let endX = tipX + cos(angle) * frondLen
                let endY = tipY + sin(angle + 0.3) * frondLen  // slight droop
                var frond = Path()
                frond.move(to: CGPoint(x: tipX, y: tipY))
                frond.addQuadCurve(to: CGPoint(x: endX, y: endY), control: CGPoint(x: midX, y: midY))
                let frondOpacity = 0.75 + 0.15 * CGFloat(sin(Double(fi) * 0.8))
                ctx.stroke(frond, with: .color(frondColor.opacity(frondOpacity)), lineWidth: 2.2)
            }
            // Coconut dot cluster at tip
            var gc2 = ctx
            gc2.addFilter(.blur(radius: 2))
            gc2.fill(
                Path(ellipseIn: CGRect(x: tipX - 4, y: tipY - 4, width: 8, height: 8)),
                with: .color(Color(red: 0.48, green: 0.34, blue: 0.16).opacity(0.80))
            )
        }
    }

    // MARK: 7 — Performance stage: concrete base + metal pipe scaffolding frame
    private func drawPerformanceStage(_ ctx: inout GraphicsContext) {
        // Stage base platform — sits just above mat area
        let stageY = matY + matH - 4
        let stageH: CGFloat = H * 0.032
        let stageX = matX - 8
        let stageW = matW + 16
        // Stage shadow
        var stageShadow = ctx
        stageShadow.addFilter(.blur(radius: 8))
        stageShadow.fill(
            Path(CGRect(x: stageX + 6, y: stageY + 6, width: stageW, height: stageH)),
            with: .color(Color.black.opacity(0.35))
        )
        // Platform surface
        ctx.fill(
            Path(CGRect(x: stageX, y: stageY, width: stageW, height: stageH)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.60, green: 0.59, blue: 0.57),
                    Color(red: 0.52, green: 0.51, blue: 0.49),
                ]),
                startPoint: CGPoint(x: stageX, y: stageY),
                endPoint: CGPoint(x: stageX, y: stageY + stageH)
            )
        )
        ctx.stroke(
            Path(CGRect(x: stageX, y: stageY, width: stageW, height: stageH)),
            with: .color(Color(red: 0.40, green: 0.40, blue: 0.38).opacity(0.60)),
            lineWidth: 1.2
        )
        // Platform edge highlight
        var edgeLine = Path()
        edgeLine.move(to: CGPoint(x: stageX, y: stageY))
        edgeLine.addLine(to: CGPoint(x: stageX + stageW, y: stageY))
        ctx.stroke(edgeLine, with: .color(Color.white.opacity(0.25)), lineWidth: 1.0)

        // Metal pipe scaffolding frame above stage (two uprights + crossbar)
        let pipeColor = Color(red: 0.55, green: 0.56, blue: 0.58)
        let frameH: CGFloat = H * 0.16
        let leftPost  = stageX + stageW * 0.12
        let rightPost = stageX + stageW * 0.88
        let frameTopY = stageY - frameH

        // Left upright
        var leftUpright = Path()
        leftUpright.move(to: CGPoint(x: leftPost, y: stageY))
        leftUpright.addLine(to: CGPoint(x: leftPost, y: frameTopY))
        ctx.stroke(leftUpright, with: .color(pipeColor.opacity(0.80)), lineWidth: 4)

        // Right upright
        var rightUpright = Path()
        rightUpright.move(to: CGPoint(x: rightPost, y: stageY))
        rightUpright.addLine(to: CGPoint(x: rightPost, y: frameTopY))
        ctx.stroke(rightUpright, with: .color(pipeColor.opacity(0.80)), lineWidth: 4)

        // Top crossbar
        var crossbar = Path()
        crossbar.move(to: CGPoint(x: leftPost - 4, y: frameTopY))
        crossbar.addLine(to: CGPoint(x: rightPost + 4, y: frameTopY))
        ctx.stroke(crossbar, with: .color(pipeColor.opacity(0.85)), lineWidth: 5)

        // Pipe joint caps
        ctx.fill(Path(ellipseIn: CGRect(x: leftPost - 5, y: frameTopY - 5, width: 10, height: 10)), with: .color(pipeColor))
        ctx.fill(Path(ellipseIn: CGRect(x: rightPost - 5, y: frameTopY - 5, width: 10, height: 10)), with: .color(pipeColor))

        // Diagonal braces
        var brace1 = Path()
        brace1.move(to: CGPoint(x: leftPost, y: stageY))
        brace1.addLine(to: CGPoint(x: leftPost + 18, y: frameTopY + frameH * 0.3))
        ctx.stroke(brace1, with: .color(pipeColor.opacity(0.55)), lineWidth: 2)

        var brace2 = Path()
        brace2.move(to: CGPoint(x: rightPost, y: stageY))
        brace2.addLine(to: CGPoint(x: rightPost - 18, y: frameTopY + frameH * 0.3))
        ctx.stroke(brace2, with: .color(pipeColor.opacity(0.55)), lineWidth: 2)
    }

    // MARK: 8 — Gymnastics rings apparatus (iconic Muscle Beach rings)
    private func drawGymnasticsRings(_ ctx: inout GraphicsContext) {
        // Overhead bar from which rings hang
        let barY: CGFloat = matY - H * 0.165
        let barLeftX  = cx - 55
        let barRightX = cx + 55
        let barColor = Color(red: 0.50, green: 0.51, blue: 0.53)

        // Bar
        ctx.fill(
            Path(CGRect(x: barLeftX - 4, y: barY - 4, width: (barRightX - barLeftX) + 8, height: 8)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.62, green: 0.63, blue: 0.65),
                    Color(red: 0.42, green: 0.43, blue: 0.45),
                ]),
                startPoint: CGPoint(x: 0, y: barY - 4),
                endPoint: CGPoint(x: 0, y: barY + 4)
            )
        )

        // Two rings hanging from bar
        let ringPositions: [CGFloat] = [cx - 30, cx + 30]
        let ropeDropY: CGFloat = H * 0.08
        let ringRadius: CGFloat = 10
        let ringColor = Color(red: 0.62, green: 0.50, blue: 0.32)  // wooden/leather rings

        for (ri, rx) in ringPositions.enumerated() {
            // Gentle swing sway on rings
            let swingPhase = CGFloat(sin(t * 0.6 + Double(ri) * 1.2)) * 3.0
            let ringX = rx + swingPhase

            // Rope/strap from bar to ring top
            var rope = Path()
            rope.move(to: CGPoint(x: rx, y: barY + 4))
            rope.addLine(to: CGPoint(x: ringX, y: barY + ropeDropY - ringRadius))
            ctx.stroke(rope, with: .color(Color(red: 0.70, green: 0.65, blue: 0.55).opacity(0.85)), lineWidth: 1.8)

            // Ring circle
            let ringRect = CGRect(
                x: ringX - ringRadius,
                y: barY + ropeDropY - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            )
            // Ring glow
            var ringGlow = ctx
            ringGlow.addFilter(.blur(radius: 3))
            ringGlow.stroke(
                Path(ellipseIn: ringRect),
                with: .color(ringColor.opacity(0.45)),
                lineWidth: 5
            )
            // Ring body
            ctx.stroke(
                Path(ellipseIn: ringRect),
                with: .color(ringColor),
                lineWidth: 3.5
            )
            // Ring highlight
            ctx.stroke(
                Path(ellipseIn: CGRect(
                    x: ringRect.minX + 2, y: ringRect.minY + 1,
                    width: ringRadius * 2 - 4, height: ringRadius - 2
                )),
                with: .color(Color.white.opacity(0.25)),
                lineWidth: 1.0
            )
        }

        // Small anchor brackets on bar
        let barColor2 = Color(red: 0.42, green: 0.43, blue: 0.45)
        for rx in ringPositions {
            ctx.fill(
                Path(CGRect(x: rx - 4, y: barY - 5, width: 8, height: 10)),
                with: .color(barColor2.opacity(0.70))
            )
        }
        _ = barColor  // suppress unused warning
    }

    // MARK: 9 — Outdoor Venice Beach spectators along sides
    private func drawOutdoorCrowd(_ ctx: inout GraphicsContext) {
        // Bleacher-style rows on left and right flanks only (beach casual)
        let rowConfigs: [(xStart: CGFloat, xEnd: CGFloat, y: CGFloat, count: Int, scale: CGFloat)] = [
            (0,         W * 0.18, H * 0.52, 7,  1.0),
            (0,         W * 0.14, H * 0.58, 6,  0.9),
            (W * 0.82,  W,        H * 0.52, 7,  1.0),
            (W * 0.86,  W,        H * 0.58, 6,  0.9),
        ]
        // Venice Beach bright casual colors
        let beachColors: [Color] = [
            Color(red: 0.95, green: 0.35, blue: 0.20),  // coral red
            Color(red: 0.20, green: 0.70, blue: 0.85),  // aqua
            Color(red: 0.98, green: 0.82, blue: 0.10),  // sun yellow
            Color(red: 0.45, green: 0.85, blue: 0.45),  // lime green
            Color(red: 0.85, green: 0.45, blue: 0.85),  // hot pink
            Color(red: 1.00, green: 0.60, blue: 0.20),  // orange
            Color(red: 0.40, green: 0.55, blue: 0.90),  // blue
        ]
        for (rowIdx, row) in rowConfigs.enumerated() {
            for col in 0..<row.count {
                let xRange = row.xEnd - row.xStart
                let figX = row.xStart + xRange * CGFloat(col + 1) / CGFloat(row.count + 1)
                let bob = CGFloat(sin(t * 0.85 + Double(col) * 0.6 + Double(rowIdx) * 1.3)) * 1.5 * row.scale
                let pulseMult: CGFloat = showFlash ? 1.5 : 1.0
                let r = 4.0 * row.scale * pulseMult
                let figY = row.y + bob
                let fc = beachColors[(col * 3 + rowIdx * 5) % beachColors.count]
                // Head (skin tone)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: figX - r, y: figY - r, width: r*2, height: r*2)),
                    with: .color(Color(red: 0.88, green: 0.74, blue: 0.60).opacity(0.80))
                )
                // Colorful shirt body
                var shirt = Path()
                shirt.move(to: CGPoint(x: figX, y: figY + r))
                shirt.addLine(to: CGPoint(x: figX, y: figY + r + 6 * row.scale))
                ctx.stroke(shirt, with: .color(fc.opacity(0.70)), lineWidth: 3.5 * row.scale)
                // Arms spread slightly
                var armL = Path()
                armL.move(to: CGPoint(x: figX, y: figY + r + 2 * row.scale))
                armL.addLine(to: CGPoint(x: figX - r * 1.2, y: figY + r + 4 * row.scale))
                ctx.stroke(armL, with: .color(fc.opacity(0.55)), lineWidth: 1.8 * row.scale)
                var armR = Path()
                armR.move(to: CGPoint(x: figX, y: figY + r + 2 * row.scale))
                armR.addLine(to: CGPoint(x: figX + r * 1.2, y: figY + r + 4 * row.scale))
                ctx.stroke(armR, with: .color(fc.opacity(0.55)), lineWidth: 1.8 * row.scale)
            }
        }
    }

    // MARK: 10 — Edge vignette for outdoor depth
    private func drawVignette(_ ctx: inout GraphicsContext) {
        var vign = ctx
        vign.addFilter(.blur(radius: 35))
        vign.fill(
            Path(CGRect(x: 0, y: 0, width: W * 0.22, height: H)),
            with: .color(Color.black.opacity(0.28))
        )
        vign.fill(
            Path(CGRect(x: W * 0.78, y: 0, width: W * 0.22, height: H)),
            with: .color(Color.black.opacity(0.28))
        )
        // Bottom vignette
        vign.fill(
            Path(CGRect(x: 0, y: H * 0.80, width: W, height: H * 0.20)),
            with: .color(Color.black.opacity(0.20))
        )
    }

    // MARK: 23-27 — Mat surface with shadow + border
    private func drawMatSurface(_ ctx: inout GraphicsContext) {
        // Drop shadow beneath mat
        var shadow = ctx
        shadow.addFilter(.blur(radius: 10))
        shadow.fill(
            Path(CGRect(x: matX + 8, y: matY + 10, width: matW, height: matH)),
            with: .color(Color.black.opacity(0.50))
        )

        // Mat fill (spring floor is white with slight blue tint for competition)
        ctx.fill(
            Path(CGRect(x: matX, y: matY, width: matW, height: matH)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.93, green: 0.94, blue: 0.98), location: 0),
                    .init(color: Color(red: 0.88, green: 0.90, blue: 0.96), location: 1),
                ]),
                startPoint: CGPoint(x: matX, y: matY),
                endPoint: CGPoint(x: matX, y: matY + matH)
            )
        )

        // Blue competition boundary border
        ctx.stroke(
            Path(CGRect(x: matX, y: matY, width: matW, height: matH)),
            with: .color(Color(red: 0.10, green: 0.25, blue: 0.72).opacity(0.85)),
            lineWidth: 3
        )

        // Inner boundary (safety line 1m inside)
        let inset: CGFloat = W * 0.04
        ctx.stroke(
            Path(CGRect(x: matX + inset, y: matY + inset * 0.5, width: matW - inset*2, height: matH - inset)),
            with: .color(Color(red: 0.10, green: 0.25, blue: 0.72).opacity(0.30)),
            lineWidth: 1
        )

        // Corner markers (thick L-shapes at each corner)
        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (matX, matY, 1, 1),
            (matX + matW, matY, -1, 1),
            (matX, matY + matH, 1, -1),
            (matX + matW, matY + matH, -1, -1),
        ]
        for (cx2, cy2, sx, sy) in corners {
            var L = Path()
            L.move(to: CGPoint(x: cx2 + sx * 16, y: cy2))
            L.addLine(to: CGPoint(x: cx2, y: cy2))
            L.addLine(to: CGPoint(x: cx2, y: cy2 + sy * 16))
            ctx.stroke(L, with: .color(Color(red: 0.10, green: 0.25, blue: 0.72).opacity(0.85)), lineWidth: 3)
        }
    }

    // MARK: 28-32 — Spring floor texture grid
    private func drawSpringGrid(_ ctx: inout GraphicsContext) {
        let gridColor = Color(red: 0.65, green: 0.68, blue: 0.82).opacity(0.18)
        let cols = 12
        let rows = 4

        // Vertical grid lines
        for i in 1..<cols {
            let gx2 = matX + matW * CGFloat(i) / CGFloat(cols)
            var vl = Path()
            vl.move(to: CGPoint(x: gx2, y: matY))
            vl.addLine(to: CGPoint(x: gx2, y: matY + matH))
            ctx.stroke(vl, with: .color(gridColor), lineWidth: 0.6)
        }

        // Horizontal grid lines
        for i in 1..<rows {
            let gy2 = matY + matH * CGFloat(i) / CGFloat(rows)
            var hl = Path()
            hl.move(to: CGPoint(x: matX, y: gy2))
            hl.addLine(to: CGPoint(x: matX + matW, y: gy2))
            ctx.stroke(hl, with: .color(gridColor), lineWidth: 0.6)
        }

        // Diagonal accent lines (spring floor characteristic)
        for i in 0..<6 {
            let dx = matW * CGFloat(i) / 5.0
            var diag = Path()
            diag.move(to: CGPoint(x: matX + dx, y: matY))
            diag.addLine(to: CGPoint(x: matX + dx + matH * 0.15, y: matY + matH))
            ctx.stroke(diag, with: .color(gridColor.opacity(0.6)), lineWidth: 0.4)
        }

        // Center cross marker
        var centerCross = Path()
        centerCross.move(to: CGPoint(x: cx - 10, y: matY + matH * 0.5))
        centerCross.addLine(to: CGPoint(x: cx + 10, y: matY + matH * 0.5))
        centerCross.move(to: CGPoint(x: cx, y: matY + matH * 0.5 - 10))
        centerCross.addLine(to: CGPoint(x: cx, y: matY + matH * 0.5 + 10))
        ctx.stroke(centerCross, with: .color(Color(red: 0.10, green: 0.25, blue: 0.72).opacity(0.40)), lineWidth: 1.2)
    }

    // MARK: 33+ — Gymnast stick figure with element-specific animation
    private mutating func drawGymnast(_ ctx: inout GraphicsContext) {
        let period: Double
        let move: GymnasticsMove
        switch elementIndex {
        case 0: period = 2.2; move = .backflip
        case 1: period = 2.0; move = .handstand
        case 2: period = 1.8; move = .aerial
        case 3: period = 1.0; move = .walkover
        case 4: period = 1.5; move = .split
        default: period = 2.0; move = .cartwheel
        }

        let rawP = fmod(t, period) / period
        let p = rawP // 0→1 looped phase

        let leotard = Color(red: 0.32, green: 0.35, blue: 0.92)
        let skin    = Color(red: 0.92, green: 0.78, blue: 0.65)

        // Glow aura for PERFECT
        if lastGrade == .perfect {
            let auraFade = min(1.0, max(0.0, 1.0 - fmod(t, 2.0)))
            var aura = ctx
            aura.addFilter(.blur(radius: 18))
            aura.fill(
                Path(ellipseIn: CGRect(x: cx - 38, y: cy - 60, width: 76, height: 76)),
                with: .color(Color.cyan.opacity(0.45 * CGFloat(auraFade)))
            )
        }

        // Red flash aura for MISS
        if lastGrade == .miss {
            let missFade = min(1.0, max(0.0, 1.0 - fmod(t, 1.5)))
            var missAura = ctx
            missAura.addFilter(.blur(radius: 14))
            missAura.fill(
                Path(ellipseIn: CGRect(x: cx - 30, y: cy - 50, width: 60, height: 60)),
                with: .color(Color.red.opacity(0.55 * CGFloat(missFade)))
            )
        }

        switch move {
        case .backflip:  drawBackflip(&ctx, p: p, leotard: leotard, skin: skin)
        case .handstand: drawHandstand(&ctx, p: p, leotard: leotard, skin: skin)
        case .aerial:    drawAerial(&ctx, p: p, leotard: leotard, skin: skin)
        case .walkover:  drawWalkover(&ctx, p: p, leotard: leotard, skin: skin)
        case .split:     drawSplit(&ctx, p: p, leotard: leotard, skin: skin)
        case .cartwheel: drawCartwheel(&ctx, p: p, leotard: leotard, skin: skin)
        default:         drawIdleStand(&ctx, cx: cx, cy: cy, leotard: leotard, skin: skin)
        }
    }

    // MARK: — Backflip: full 360° rotation while airborne
    private func drawBackflip(_ ctx: inout GraphicsContext, p: Double, leotard: Color, skin: Color) {
        // Run phase (0→0.3), jump+flip phase (0.3→0.85), land (0.85→1)
        let figX = cx - 60 + CGFloat(p) * 120
        let jumpH: CGFloat = p > 0.30 && p < 0.88 ? CGFloat(sin((p - 0.30) / 0.58 * .pi)) * 70 : 0
        let rotation: Double = p > 0.32 && p < 0.86 ? (p - 0.32) / 0.54 * 2.0 * .pi : 0
        let figY = cy - jumpH

        drawFigureCore(
            &ctx, cx: figX, cy: figY, matY: matY, rotation: rotation,
            leotard: leotard, skin: skin,
            armAngle: p > 0.32 && p < 0.86 ? 0.1 : 1.3,
            legAngle: p > 0.32 && p < 0.86 ? 0.05 : 0.7,
            isTucked: p > 0.35 && p < 0.80
        )
    }

    // MARK: — Handstand: figure inverted with arms down, legs up
    private func drawHandstand(_ ctx: inout GraphicsContext, p: Double, leotard: Color, skin: Color) {
        // Phase up into handstand (0→0.3), hold (0.3→0.75), come down (0.75→1)
        let invertT: Double
        if p < 0.30 {
            invertT = easeInOut(p / 0.30)
        } else if p < 0.75 {
            invertT = 1.0
        } else {
            invertT = easeInOut(1.0 - (p - 0.75) / 0.25)
        }
        let rotation = .pi * invertT
        let wobble = invertT > 0.9 ? CGFloat(sin(t * 4.5)) * 4.0 * CGFloat(invertT) : 0

        drawFigureCore(
            &ctx, cx: cx + wobble, cy: cy, matY: matY, rotation: rotation,
            leotard: leotard, skin: skin,
            armAngle: 0.05, legAngle: 0.04, isTucked: false
        )
    }

    // MARK: — Aerial: horizontal body like eagle, arms spread
    private func drawAerial(_ ctx: inout GraphicsContext, p: Double, leotard: Color, skin: Color) {
        let runX = cx - 50 + CGFloat(p) * 100
        let jumpH: CGFloat = p > 0.25 && p < 0.80 ? CGFloat(sin((p - 0.25) / 0.55 * .pi)) * 62 : 0
        // Aerial: body goes horizontal (-pi/2 rotation), arms wide
        let horizontalT = p > 0.30 && p < 0.75 ? easeInOut((p - 0.30) / 0.45) : (p >= 0.75 ? easeInOut(1.0 - (p - 0.75) / 0.25) : 0.0)
        let rotation = -(Double.pi / 2.0) * horizontalT

        drawFigureCore(
            &ctx, cx: runX, cy: cy - jumpH, matY: matY, rotation: rotation,
            leotard: leotard, skin: skin,
            armAngle: 1.8 * CGFloat(horizontalT) + 0.4 * CGFloat(1 - horizontalT),
            legAngle: 0.6,
            isTucked: false
        )
    }

    // MARK: — Walkover: cartwheel-adjacent side rotation
    private func drawWalkover(_ ctx: inout GraphicsContext, p: Double, leotard: Color, skin: Color) {
        let rotation = p * 2.0 * .pi
        let walkX = cx + CGFloat(sin(p * 2 * .pi)) * 28
        let walkH: CGFloat = CGFloat(abs(sin(p * .pi))) * 22
        drawFigureCore(
            &ctx, cx: walkX, cy: cy - walkH, matY: matY, rotation: rotation,
            leotard: leotard, skin: skin,
            armAngle: 1.2, legAngle: 0.8, isTucked: false
        )
    }

    // MARK: — Split: legs spread wide horizontal, torso upright
    private func drawSplit(_ ctx: inout GraphicsContext, p: Double, leotard: Color, skin: Color) {
        let jumpH: CGFloat = p > 0.20 && p < 0.80 ? CGFloat(sin((p - 0.20) / 0.60 * .pi)) * 55 : 0
        // Leg spread peaks at jump apex
        let spreadT = p > 0.20 && p < 0.80 ? easeInOut((p - 0.20) / 0.60) : 0.0
        let sineSpread = sin(spreadT * .pi)  // bell curve: 0→1→0
        let legAng = CGFloat(sineSpread) * 1.8 + 0.2

        drawFigureCore(
            &ctx, cx: cx, cy: cy - jumpH, matY: matY, rotation: 0,
            leotard: leotard, skin: skin,
            armAngle: 1.4, legAngle: legAng,
            isTucked: false
        )
    }

    // MARK: — Cartwheel: body rotates 90° sideways
    private func drawCartwheel(_ ctx: inout GraphicsContext, p: Double, leotard: Color, skin: Color) {
        let cartwheelX = cx - 55 + CGFloat(p) * 110
        let rotation = p * 2.0 * .pi
        let liftH: CGFloat = CGFloat(sin(p * .pi)) * 40

        drawFigureCore(
            &ctx, cx: cartwheelX, cy: cy - liftH, matY: matY, rotation: rotation,
            leotard: leotard, skin: skin,
            armAngle: 1.1, legAngle: 1.0, isTucked: false
        )
    }

    // MARK: — Idle standing pose
    private func drawIdleStand(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat, leotard: Color, skin: Color) {
        let bob = CGFloat(sin(t * 1.5)) * 1.5
        drawFigureCore(
            &ctx, cx: cx, cy: cy + bob, matY: matY, rotation: 0,
            leotard: leotard, skin: skin,
            armAngle: 0.4, legAngle: 0.3, isTucked: false
        )
    }

    // MARK: — Core figure renderer (head + torso + arms + legs)
    private func drawFigureCore(
        _ ctx: inout GraphicsContext,
        cx: CGFloat, cy: CGFloat, matY: CGFloat,
        rotation: Double,
        leotard: Color, skin: Color,
        armAngle: CGFloat, legAngle: CGFloat,
        isTucked: Bool
    ) {
        // Ground shadow
        let shadowOpacity = max(0, 0.40 - (matY - cy) / 180)
        var sc = ctx
        sc.addFilter(.blur(radius: 6))
        sc.fill(
            Path(ellipseIn: CGRect(x: cx - 14, y: matY - 4, width: 28, height: 7)),
            with: .color(Color.black.opacity(shadowOpacity))
        )

        // Save state by translating to center
        var gc = ctx
        gc.translateBy(x: cx, y: cy)
        gc.rotate(by: .radians(rotation))

        let scale: CGFloat = 1.0

        // HEAD (circle)
        gc.fill(
            Path(ellipseIn: CGRect(x: -5 * scale, y: -38 * scale, width: 10 * scale, height: 10 * scale)),
            with: .color(skin)
        )
        // Hair top
        gc.fill(
            Path(ellipseIn: CGRect(x: -5 * scale, y: -40 * scale, width: 10 * scale, height: 6 * scale)),
            with: .color(Color(red: 0.25, green: 0.18, blue: 0.12))
        )

        // NECK
        var neck = Path()
        neck.move(to: CGPoint(x: 0, y: -28 * scale))
        neck.addLine(to: CGPoint(x: 0, y: -26 * scale))
        gc.stroke(neck, with: .color(skin), lineWidth: 2.5 * scale)

        // TORSO (leotard body)
        var torso = Path()
        torso.move(to: CGPoint(x: 0, y: -27 * scale))
        torso.addLine(to: CGPoint(x: 0, y: -10 * scale))
        gc.stroke(torso, with: .color(leotard), lineWidth: 5 * scale)

        // Leotard detail lines
        var detail = Path()
        detail.move(to: CGPoint(x: -3 * scale, y: -24 * scale))
        detail.addLine(to: CGPoint(x: 3 * scale, y: -24 * scale))
        gc.stroke(detail, with: .color(Color.white.opacity(0.35)), lineWidth: 1)

        // ARMS
        let aOff = armAngle * 18 * scale
        var leftArm = Path()
        leftArm.move(to: CGPoint(x: 0, y: -23 * scale))
        leftArm.addLine(to: CGPoint(x: -aOff, y: -18 * scale))
        // Forearm bend
        leftArm.addLine(to: CGPoint(x: -aOff * 1.3, y: -11 * scale))
        gc.stroke(leftArm, with: .color(skin), lineWidth: 2.5 * scale)

        var rightArm = Path()
        rightArm.move(to: CGPoint(x: 0, y: -23 * scale))
        rightArm.addLine(to: CGPoint(x: aOff, y: -18 * scale))
        rightArm.addLine(to: CGPoint(x: aOff * 1.3, y: -11 * scale))
        gc.stroke(rightArm, with: .color(skin), lineWidth: 2.5 * scale)

        // Hand dots
        gc.fill(Path(ellipseIn: CGRect(x: -aOff * 1.3 - 2, y: -13 * scale, width: 4, height: 4)), with: .color(skin))
        gc.fill(Path(ellipseIn: CGRect(x: aOff * 1.3 - 2, y: -13 * scale, width: 4, height: 4)), with: .color(skin))

        // HIPS
        var hips = Path()
        hips.move(to: CGPoint(x: -5 * scale, y: -10 * scale))
        hips.addLine(to: CGPoint(x: 5 * scale, y: -10 * scale))
        gc.stroke(hips, with: .color(leotard), lineWidth: 3 * scale)

        // LEGS
        if isTucked {
            // Tucked position: knees pulled to chest
            var leftLeg = Path()
            leftLeg.move(to: CGPoint(x: -3 * scale, y: -10 * scale))
            leftLeg.addLine(to: CGPoint(x: -10 * scale, y: 0))
            leftLeg.addLine(to: CGPoint(x: -6 * scale, y: 8 * scale))
            gc.stroke(leftLeg, with: .color(leotard), lineWidth: 3 * scale)

            var rightLeg = Path()
            rightLeg.move(to: CGPoint(x: 3 * scale, y: -10 * scale))
            rightLeg.addLine(to: CGPoint(x: 10 * scale, y: 0))
            rightLeg.addLine(to: CGPoint(x: 6 * scale, y: 8 * scale))
            gc.stroke(rightLeg, with: .color(leotard), lineWidth: 3 * scale)
        } else {
            let lOff = legAngle * 14 * scale
            var leftLeg = Path()
            leftLeg.move(to: CGPoint(x: -2 * scale, y: -10 * scale))
            leftLeg.addLine(to: CGPoint(x: -lOff, y: 6 * scale))
            leftLeg.addLine(to: CGPoint(x: -lOff * 1.1, y: 20 * scale))
            gc.stroke(leftLeg, with: .color(leotard), lineWidth: 3 * scale)

            var rightLeg = Path()
            rightLeg.move(to: CGPoint(x: 2 * scale, y: -10 * scale))
            rightLeg.addLine(to: CGPoint(x: lOff, y: 6 * scale))
            rightLeg.addLine(to: CGPoint(x: lOff * 1.1, y: 20 * scale))
            gc.stroke(rightLeg, with: .color(leotard), lineWidth: 3 * scale)

            // Foot dots
            gc.fill(Path(ellipseIn: CGRect(x: -lOff * 1.1 - 2.5, y: 18 * scale, width: 5, height: 5)), with: .color(skin))
            gc.fill(Path(ellipseIn: CGRect(x: lOff * 1.1 - 2.5, y: 18 * scale, width: 5, height: 5)), with: .color(skin))
        }
    }

    // MARK: 61-70 — Score pop effects / particle trails
    private func drawScorePopEffects(_ ctx: inout GraphicsContext) {
        guard let grade = lastGrade else { return }
        let popAge = fmod(t, 1.2) / 1.2  // 0→1 then loops
        guard popAge < 0.85 else { return }

        let fadeAlpha = CGFloat(1.0 - popAge * 1.2)

        // Grade glow on mat center
        if grade == .perfect || grade == .good {
            var glow = ctx
            glow.addFilter(.blur(radius: 22))
            let glowColor = grade == .perfect ? Color.yellow : Color.cyan
            glow.fill(
                Path(ellipseIn: CGRect(x: cx - 40, y: cy - 30, width: 80, height: 60)),
                with: .color(glowColor.opacity(0.28 * fadeAlpha))
            )
        }

        // Particle sparks radiating out (8 particles for PERFECT)
        if grade == .perfect {
            let particleCount = 8
            for i in 0..<particleCount {
                let angle = Double(i) / Double(particleCount) * 2 * .pi
                let dist = CGFloat(popAge) * 70
                let px = cx + CGFloat(cos(angle)) * dist
                let py = cy - 20 + CGFloat(sin(angle)) * dist * 0.7
                let pr = 3.5 * (1 - CGFloat(popAge))
                ctx.fill(
                    Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr*2, height: pr*2)),
                    with: .color(Color.yellow.opacity(0.9 * fadeAlpha))
                )
                // Spark trail
                var trail = Path()
                let trailDist = max(0, dist - 12)
                trail.move(to: CGPoint(x: cx + CGFloat(cos(angle)) * trailDist, y: cy - 20 + CGFloat(sin(angle)) * trailDist * 0.7))
                trail.addLine(to: CGPoint(x: px, y: py))
                ctx.stroke(trail, with: .color(Color.yellow.opacity(0.5 * fadeAlpha)), lineWidth: 1.2)
            }
        }

        // GOOD: 4 cyan particles
        if grade == .good {
            for i in 0..<4 {
                let angle = Double(i) / 4.0 * 2 * .pi + Double.pi / 4
                let dist = CGFloat(popAge) * 50
                let px = cx + CGFloat(cos(angle)) * dist
                let py = cy - 20 + CGFloat(sin(angle)) * dist * 0.7
                let pr = 3.0 * (1 - CGFloat(popAge))
                ctx.fill(
                    Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr*2, height: pr*2)),
                    with: .color(Color.cyan.opacity(0.85 * fadeAlpha))
                )
            }
        }
    }

    // MARK: 71 — Full-screen flash on grade
    private func drawScreenFlash(_ ctx: inout GraphicsContext) {
        var gc = ctx
        gc.addFilter(.blur(radius: 22))
        gc.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H)),
            with: .color(gradeColor.opacity(0.28))
        )
    }
}

// MARK: - SwipeArrowCanvas (timing ring + arrow prompt)

private struct SwipeArrowCanvas: View {
    let direction: GymnasticsSwipeDir
    let timeLeft: Double
    let maxTime: Double
    let lastGrade: TimingGrade?

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = ArrowDrawer(
                    t: t, W: size.width, H: size.height,
                    direction: direction,
                    timeLeft: timeLeft, maxTime: maxTime,
                    lastGrade: lastGrade
                )
                d.render(ctx: &ctx)
            }
        }
    }
}

private struct ArrowDrawer {
    let t: Double
    let W: CGFloat
    let H: CGFloat
    let direction: GymnasticsSwipeDir
    let timeLeft: Double
    let maxTime: Double
    let lastGrade: TimingGrade?

    var cx: CGFloat { W / 2 }
    var cy: CGFloat { H / 2 }

    mutating func render(ctx: inout GraphicsContext) {
        drawTimingRings(&ctx)
        drawDirectionArrow(&ctx)
        if let grade = lastGrade { drawGradeFeedback(&ctx, grade: grade) }
    }

    // Outer ring shrinks inward as time runs out
    private func drawTimingRings(_ ctx: inout GraphicsContext) {
        let progress = CGFloat(timeLeft / maxTime)  // 1→0
        let outerR: CGFloat = 52
        let innerR: CGFloat = 30
        // Current ring position interpolated
        let currentR = innerR + (outerR - innerR) * progress

        // Background track
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx - outerR, y: cy - outerR, width: outerR*2, height: outerR*2)),
            with: .color(Color.white.opacity(0.08)),
            lineWidth: 3
        )

        // Perfect window highlight (inner zone glow)
        var pZone = ctx
        pZone.addFilter(.blur(radius: 4))
        pZone.stroke(
            Path(ellipseIn: CGRect(x: cx - innerR, y: cy - innerR, width: innerR*2, height: innerR*2)),
            with: .color(Color.yellow.opacity(0.30)),
            lineWidth: 5
        )

        // Moving timing ring
        let ringColor: Color
        if progress > 0.70 {
            ringColor = Color(red: 0.35, green: 0.38, blue: 0.95)  // early — blue
        } else if progress > 0.40 {
            ringColor = Color.orange                                 // GOOD window
        } else if progress > 0.15 {
            ringColor = Color.yellow                                 // PERFECT window
        } else {
            ringColor = Color.red                                    // LATE
        }

        // Pulsing glow on timing ring
        let pulse = 1.0 + 0.08 * CGFloat(sin(t * 8.0))
        var glow = ctx
        glow.addFilter(.blur(radius: 5))
        glow.stroke(
            Path(ellipseIn: CGRect(x: cx - currentR * pulse, y: cy - currentR * pulse,
                                   width: currentR * pulse * 2, height: currentR * pulse * 2)),
            with: .color(ringColor.opacity(0.55)),
            lineWidth: 4
        )

        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx - currentR, y: cy - currentR, width: currentR*2, height: currentR*2)),
            with: .color(ringColor),
            lineWidth: 2.5
        )
    }

    // Direction arrow with glow
    private func drawDirectionArrow(_ ctx: inout GraphicsContext) {
        let progress = CGFloat(timeLeft / maxTime)
        let arrowGlow: Color = progress < 0.20 ? .yellow : Color(red: 0.35, green: 0.38, blue: 0.95)

        // Arrow glow halo
        var halo = ctx
        halo.addFilter(.blur(radius: 10))
        halo.fill(
            Path(ellipseIn: CGRect(x: cx - 14, y: cy - 14, width: 28, height: 28)),
            with: .color(arrowGlow.opacity(0.40))
        )

        // Draw arrow shape based on direction
        let arrowPath = makeArrowPath(dir: direction, cx: cx, cy: cy, size: 20)
        ctx.fill(arrowPath, with: .color(Color.white))
        ctx.stroke(arrowPath, with: .color(arrowGlow.opacity(0.7)), lineWidth: 1.2)
    }

    private func makeArrowPath(dir: GymnasticsSwipeDir, cx: CGFloat, cy: CGFloat, size: CGFloat) -> Path {
        var angle: Double
        switch dir {
        case .up:      angle = -.pi / 2
        case .down:    angle = .pi / 2
        case .left:    angle = .pi
        case .right:   angle = 0
        case .upRight: angle = -.pi / 4
        case .upLeft:  angle = -.pi * 3 / 4
        }
        var p = Path()
        // Arrow head points in direction
        let tip = CGPoint(x: cx + CGFloat(cos(angle)) * size, y: cy + CGFloat(sin(angle)) * size)
        let left = CGPoint(x: cx + CGFloat(cos(angle + .pi * 0.75)) * size * 0.7,
                           y: cy + CGFloat(sin(angle + .pi * 0.75)) * size * 0.7)
        let right = CGPoint(x: cx + CGFloat(cos(angle - .pi * 0.75)) * size * 0.7,
                            y: cy + CGFloat(sin(angle - .pi * 0.75)) * size * 0.7)
        let tail = CGPoint(x: cx + CGFloat(cos(angle + .pi)) * size * 0.4,
                           y: cy + CGFloat(sin(angle + .pi)) * size * 0.4)
        p.move(to: tip)
        p.addLine(to: left)
        p.addLine(to: CGPoint(x: (left.x + tail.x) / 2, y: (left.y + tail.y) / 2))
        p.addLine(to: tail)
        p.addLine(to: CGPoint(x: (right.x + tail.x) / 2, y: (right.y + tail.y) / 2))
        p.addLine(to: right)
        p.closeSubpath()
        return p
    }

    private func drawGradeFeedback(_ ctx: inout GraphicsContext, grade: TimingGrade) {
        let age = fmod(t, 1.0)
        guard age < 0.7 else { return }
        let fade = CGFloat(1.0 - age / 0.7)
        let riseY = CGFloat(age) * 30

        // Grade ring burst
        var burst = ctx
        burst.addFilter(.blur(radius: 8))
        burst.stroke(
            Path(ellipseIn: CGRect(x: cx - 35 - age * 20, y: cy - 35 - age * 20,
                                   width: (70 + CGFloat(age) * 40), height: (70 + CGFloat(age) * 40))),
            with: .color(grade.color.opacity(0.5 * fade)),
            lineWidth: 3
        )
        _ = riseY  // suppress unused warning
    }
}

// MARK: - GymnasticsGameView

struct GymnasticsGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: GymnasticsPhase = .ready
    @State private var currentElementIndex: Int = 0
    @State private var elementResults: [GymElementResult] = []

    @State private var timeLeft: Double = 2.0
    @State private var elementTimer: Task<Void, Never>?

    @State private var swipeStartTime: Date = .now
    @State private var didSwipeThisElement: Bool = false

    @State private var showGradeFlash: Bool = false
    @State private var gradeFlashText: String = ""
    @State private var gradeFlashColor: Color = .white
    @State private var lastGrade: TimingGrade? = nil
    @State private var shakeX: CGFloat = 0
    @State private var shakeY: CGFloat = 0
    @State private var burstParticles: [(id: Int, x: CGFloat, y: CGFloat, angle: Double, distance: CGFloat, opacity: Double, color: Color)] = []
    @State private var burstCounter: Int = 0

    @State private var judgeScoresVisible: [Bool] = [false, false, false]
    @State private var currentJudgeScores: (Double, Double, Double) = (0, 0, 0)
    @State private var showJudgePanel: Bool = false

    @State private var difficultyMeter: Double = 0.72
    @State private var executionBar: Double = 0.0
    @State private var artisticImpression: Double = 0.0

    @State private var frozenAIScore: Double = 46.0
    @State private var rewardApplied: Bool = false

    // MARK: - Live AI Rival State
    @State private var aiRoutineProgress: Int = 0
    @State private var aiElementResults: [Int] = []           // 10 / 7 / 0 per element
    @State private var aiCurrentScore: Int = 0
    @State private var aiPerforming: Bool = false
    @State private var aiElementFlash: Color = .clear
    @State private var showAiFlash: Bool = false
    @State private var aiGradeText: String = ""
    @State private var aiScorePopText: String = ""
    @State private var showAIScorePop: Bool = false
    @State private var aiTimerTask: Task<Void, Never>? = nil
    @State private var preDeterminedAIResults: [Int] = []     // pre-rolled 65%/25%/10%
    @State private var showFinalJudgment: Bool = false

    private let accentColor = Color(red: 0.39, green: 0.4, blue: 0.95)
    private let totalElements = kRoutineElements.count

    private var totalScore: Double { elementResults.reduce(0) { $0 + $1.finalPoints } }
    private var playerWins: Bool { totalScore > Double(aiCurrentScore) }
    private var isDraw: Bool { Int(totalScore) == aiCurrentScore }

    // MARK: Haptics

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
            for idx in 0..<burstParticles.count {
                if burstParticles[idx].id >= id * 100 {
                    burstParticles[idx].distance = CGFloat.random(in: 50...110)
                    burstParticles[idx].opacity = 0
                }
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            await MainActor.run { burstParticles.removeAll { $0.id >= id * 100 } }
        }
    }

    private func hapticPerfect() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    private func hapticGood() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    private func hapticLate() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    private func hapticMiss() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.02, blue: 0.18), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Particle burst overlay
            ForEach(burstParticles, id: \.id) { p in
                Circle().fill(p.color).frame(width: 7, height: 7)
                    .offset(x: p.x - UIScreen.main.bounds.width/2 + CGFloat(cos(p.angle)) * p.distance,
                            y: p.y - UIScreen.main.bounds.height/2 + CGFloat(sin(p.angle)) * p.distance)
                    .opacity(p.opacity).blur(radius: 1)
            }
            .allowsHitTesting(false)

            Group { switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Gymnastics",
                    subtitle: "6 elements · Swipe on cue · Judges watching",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: {
                        frozenAIScore = Double(Int.random(in: 38...54))
                        preDeterminedAIResults = (0..<totalElements).map { _ -> Int in
                            let r = Double.random(in: 0..<1)
                            if r < 0.65 { return 10 }
                            else if r < 0.90 { return 7 }
                            else { return 0 }
                        }
                        aiRoutineProgress = 0
                        aiCurrentScore = 0
                        aiElementResults = []
                        aiPerforming = true
                        startAITimer()
                        phase = .active
                        startElement()
                    }
                )

            case .active:
                activeBody

            case .elementFeedback:
                feedbackBody

            case .judging:
                judgingBody

            case .result:
                ZStack {
                    ResultScreen(
                        winner: playerWins ? .p1 : (isDraw ? .draw : .p2),
                        p1Score: Int(totalScore),
                        p2Score: aiCurrentScore,
                        title: "Gymnastics",
                        accentColor: accentColor,
                        prqGain: playerWins ? 12 : (isDraw ? 5 : 3),
                        prqCurrent: viewModel.effectiveMetrics.prqScore,
                        modeAttributeLabel: "Execution",
                        modeAttributeValue: executionBar,
                        onReturn: { dismiss() }
                    )
                    if showFinalJudgment {
                        finalJudgmentOverlay
                    }
                }
            } }
            .offset(x: shakeX, y: shakeY)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { elementTimer?.cancel(); aiTimerTask?.cancel(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { elementTimer?.cancel(); aiTimerTask?.cancel() }
    }

    // MARK: - Active Body

    private var activeBody: some View {
        ZStack {
            // Full-canvas arena as background
            if currentElementIndex < kRoutineElements.count {
                GymnasticsArenaCanvas(
                    elementIndex: currentElementIndex,
                    gradeColor: gradeFlashColor,
                    showFlash: showGradeFlash,
                    lastGrade: lastGrade,
                    timingProgress: timeLeft / 2.0
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                dualScoreHUD
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                arenaHUD
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                Spacer()

                if currentElementIndex < kRoutineElements.count {
                    elementOverlayCard(element: kRoutineElements[currentElementIndex])
                }

                Spacer()

                if showJudgePanel {
                    judgePanelRow
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                swipeZone
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
            .overlay(gradeFlashOverlay)
        }
    }

    // MARK: - Arena HUD (top bar over full-canvas)

    private var arenaHUD: some View {
        HStack(spacing: 0) {
            // Routine title + progress
            VStack(alignment: .leading, spacing: 2) {
                Text("FLOOR EXERCISE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(1.5)
                Text("\(min(currentElementIndex + 1, totalElements)) / \(totalElements)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Element dots
            HStack(spacing: 6) {
                ForEach(0..<totalElements, id: \.self) { i in
                    Circle()
                        .fill(i < currentElementIndex
                              ? accentColor
                              : (i == currentElementIndex ? accentColor.opacity(0.60) : Color.white.opacity(0.12)))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentElementIndex)
                }
            }

            Spacer()

            // Score panel
            VStack(alignment: .trailing, spacing: 1) {
                Text("TOTAL")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
                    .tracking(1)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", totalScore))
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("/ 60")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    // MARK: - Element Overlay Card (floating above canvas)

    private func elementOverlayCard(element: GymnasticsElement) -> some View {
        HStack(spacing: 20) {
            // Timer ring + arrow in SwipeArrowCanvas
            SwipeArrowCanvas(
                direction: element.direction,
                timeLeft: timeLeft,
                maxTime: 2.0,
                lastGrade: lastGrade
            )
            .frame(width: 110, height: 110)

            // Element prompt text
            VStack(alignment: .leading, spacing: 10) {
                Text(element.prompt)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(3)
                    .shadow(color: accentColor.opacity(0.6), radius: 12)

                // Timing countdown bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.10))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(timeLeft > 1.0 ? accentColor : .red)
                            .frame(width: geo.size.width * CGFloat(timeLeft / 2.0))
                            .animation(.linear(duration: 0.1), value: timeLeft)
                    }
                }
                .frame(height: 5)

                Text("SWIPE \(element.direction.rawValue)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.85))
                    .tracking(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.60))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(accentColor.opacity(0.28), lineWidth: 1.2))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Judge Panel

    private var judgePanelRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                singleJudgeChip(index: i)
            }
        }
        .padding(.bottom, 12)
    }

    private func singleJudgeChip(index: Int) -> some View {
        let scores = [currentJudgeScores.0, currentJudgeScores.1, currentJudgeScores.2]
        let s = scores[index]
        return VStack(spacing: 3) {
            Text("JUDGE \(index + 1)")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
            Text(String(format: "%.1f", s))
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(s >= 8 ? .yellow : (s >= 5 ? accentColor : Color.white.opacity(0.5)))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.65))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        )
        .scaleEffect(judgeScoresVisible[index] ? 1.0 : 0.4)
        .opacity(judgeScoresVisible[index] ? 1.0 : 0.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.6).delay(Double(index) * 0.14), value: judgeScoresVisible[index])
    }

    // MARK: - Swipe Zone

    private var swipeZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .frame(height: 96)
            VStack(spacing: 5) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(accentColor.opacity(0.50))
                Text("SWIPE HERE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { _ in
                    if !didSwipeThisElement {
                        didSwipeThisElement = true
                        swipeStartTime = .now
                    }
                }
                .onEnded { val in
                    guard phase == .active else { return }
                    handleSwipe(translation: val.translation)
                }
        )
    }

    // MARK: - Grade Flash Overlay

    private var gradeFlashOverlay: some View {
        Group {
            if showGradeFlash {
                VStack(spacing: 6) {
                    Text(gradeFlashText)
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundStyle(gradeFlashColor)
                        .shadow(color: gradeFlashColor.opacity(0.7), radius: 22)
                    if let grade = lastGrade {
                        Text("+\(grade.points)")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.2))
                            .shadow(color: Color.yellow.opacity(0.5), radius: 10)
                    }
                }
                .allowsHitTesting(false)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: showGradeFlash)
    }

    // MARK: - Feedback Body

    private var feedbackBody: some View {
        ZStack {
            // Keep arena as background even in feedback
            if currentElementIndex > 0 {
                GymnasticsArenaCanvas(
                    elementIndex: max(0, currentElementIndex - 1),
                    gradeColor: gradeFlashColor,
                    showFlash: false,
                    lastGrade: lastGrade,
                    timingProgress: 0
                )
                .ignoresSafeArea()
                .opacity(0.5)
            }

            VStack(spacing: 0) {
                arenaHUD
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
                if let last = elementResults.last {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(last.grade.color.opacity(0.15))
                                .frame(width: 120, height: 120)
                            Circle()
                                .stroke(last.grade.color.opacity(0.30), lineWidth: 2)
                                .frame(width: 120, height: 120)
                            VStack(spacing: 3) {
                                Text(last.grade.rawValue)
                                    .font(.system(size: 17, weight: .black, design: .monospaced))
                                    .foregroundStyle(last.grade.color)
                                Text(String(format: "+%.1f", last.finalPoints))
                                    .font(.system(size: 36, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text(last.element.name.uppercased())
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(3)

                        if last.deduction > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                                Text(last.grade == .miss ? "FALL  −1.0 deduction" : "WOBBLE  −0.5 deduction")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                            )
                        }

                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { i in singleJudgeChip(index: i) }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Judging Body

    private var judgingBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("FINAL SCORES")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(3)
                    .padding(.top, 20)

                Image(systemName: "figure.gymnastics")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [accentColor, Theme.brandCyan], startPoint: .top, endPoint: .bottom)
                    )
                    .symbolEffect(.pulse)

                // Score breakdown
                VStack(spacing: 14) {
                    barRow(label: "DIFFICULTY", value: difficultyMeter * 10, maxVal: 10, barColor: accentColor)
                    barRow(label: "EXECUTION",  value: executionBar * 10,   maxVal: 10, barColor: Theme.brandCyan)
                    barRow(label: "ARTISTIC",   value: artisticImpression * 10, maxVal: 10, barColor: .yellow)

                    Divider().background(Theme.cardBorder).padding(.vertical, 4)

                    HStack {
                        Text("YOUR TOTAL")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(2)
                        Spacer()
                        Text(String(format: "%.1f", totalScore))
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 4)

                    HStack {
                        Text("ARIA SCORE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.orange.opacity(0.7)).tracking(2)
                        Spacer()
                        Text("\(aiCurrentScore)")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.orange.opacity(0.85))
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 4)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1))
                )
                .padding(.horizontal, 24)

                // Element history
                VStack(alignment: .leading, spacing: 8) {
                    Text("ELEMENT BREAKDOWN")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                        .padding(.horizontal, 4)
                    ForEach(elementResults.indices, id: \.self) { i in
                        let r = elementResults[i]
                        HStack {
                            Text(r.element.name.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text(r.grade.rawValue)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(r.grade.color)
                            Text(String(format: "+%.1f", r.finalPoints))
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.cardBackground)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func barRow(label: String, value: Double, maxVal: Double, barColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(1)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(min(value / maxVal, 1.0)), height: 6)
                        .animation(.easeOut(duration: 0.7), value: value)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Dual Score HUD

    private var dualScoreHUD: some View {
        HStack(spacing: 0) {
            // YOU panel
            VStack(spacing: 1) {
                Text("YOU")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .tracking(2)
                Text(String(format: "%.0f", totalScore))
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: Int(totalScore))
                // element progress dots
                HStack(spacing: 4) {
                    ForEach(0..<totalElements, id: \.self) { i in
                        Circle()
                            .fill(i < elementResults.count
                                  ? (elementResults[i].grade == .miss ? Color.red : accentColor)
                                  : Color.white.opacity(0.12))
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.25), lineWidth: 1))
            )

            // VS divider
            Text("VS")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.30))
                .padding(.horizontal, 8)

            // ARIA (AI) panel
            ZStack {
                VStack(spacing: 1) {
                    Text("ARIA")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.orange.opacity(0.85))
                        .tracking(2)
                    Text("\(aiCurrentScore)")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: aiCurrentScore)
                    // AI element progress dots
                    HStack(spacing: 4) {
                        ForEach(0..<totalElements, id: \.self) { i in
                            Circle()
                                .fill(i < aiElementResults.count
                                      ? (aiElementResults[i] == 0 ? Color.red : Color.orange)
                                      : Color.white.opacity(0.12))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(showAiFlash ? aiElementFlash.opacity(0.18) : Color.orange.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                            showAiFlash ? aiElementFlash.opacity(0.60) : Color.orange.opacity(0.22),
                            lineWidth: showAiFlash ? 1.8 : 1))
                        .animation(.easeOut(duration: 0.25), value: showAiFlash)
                )

                // AI score pop text
                if showAIScorePop {
                    Text(aiScorePopText)
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(aiElementFlash)
                        .shadow(color: aiElementFlash.opacity(0.6), radius: 8)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // AI grade text flash
                if showAiFlash {
                    VStack(spacing: 0) {
                        Spacer()
                        Text(aiGradeText)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(aiElementFlash)
                            .padding(.bottom, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Final Judgment Overlay

    private var finalJudgmentOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 20) {
                // Crown for winner
                let youWin = Int(totalScore) > aiCurrentScore
                let drawGame = Int(totalScore) == aiCurrentScore

                Text("FINAL JUDGMENT")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(3)
                    .padding(.top, 20)

                // Crown icon
                Image(systemName: drawGame ? "equal.circle.fill" : "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(drawGame ? Color.gray : Color.yellow)
                    .shadow(color: (drawGame ? Color.gray : Color.yellow).opacity(0.6), radius: 14)
                    .symbolEffect(.bounce, value: showFinalJudgment)

                // Side-by-side score bars
                HStack(spacing: 16) {
                    // Player bar
                    VStack(spacing: 8) {
                        Text("YOU")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(youWin && !drawGame ? accentColor : .white.opacity(0.7))
                            .tracking(2)
                        Text(String(format: "%.0f", totalScore))
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .foregroundStyle(youWin && !drawGame ? accentColor : .white)

                        let maxScore = max(totalScore, Double(aiCurrentScore), 1)
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.08))
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(youWin && !drawGame
                                          ? LinearGradient(colors: [accentColor, Theme.brandCyan], startPoint: .bottom, endPoint: .top)
                                          : LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.3)], startPoint: .bottom, endPoint: .top))
                                    .frame(height: geo.size.height * CGFloat(totalScore / maxScore))
                                    .animation(.easeOut(duration: 1.2), value: showFinalJudgment)
                            }
                        }
                        .frame(height: 100)

                        if youWin && !drawGame {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // AI bar
                    VStack(spacing: 8) {
                        Text("ARIA")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(!youWin && !drawGame ? Color.orange : .white.opacity(0.7))
                            .tracking(2)
                        Text("\(aiCurrentScore)")
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .foregroundStyle(!youWin && !drawGame ? Color.orange : .white)

                        let maxScore = max(totalScore, Double(aiCurrentScore), 1)
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.08))
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(!youWin && !drawGame
                                          ? LinearGradient(colors: [Color.orange, Color.red], startPoint: .bottom, endPoint: .top)
                                          : LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.3)], startPoint: .bottom, endPoint: .top))
                                    .frame(height: geo.size.height * CGFloat(Double(aiCurrentScore) / maxScore))
                                    .animation(.easeOut(duration: 1.2).delay(0.1), value: showFinalJudgment)
                            }
                        }
                        .frame(height: 100)

                        if !youWin && !drawGame {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 32)

                // ARIA element breakdown
                VStack(alignment: .leading, spacing: 6) {
                    Text("ARIA's ROUTINE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                    HStack(spacing: 8) {
                        ForEach(aiElementResults.indices, id: \.self) { i in
                            let pts = aiElementResults[i]
                            VStack(spacing: 3) {
                                Text(i < kRoutineElements.count ? String(kRoutineElements[i].name.prefix(3)).uppercased() : "???")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("+\(pts)")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(pts == 10 ? .yellow : (pts == 7 ? accentColor : .red))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)

                Button {
                    withAnimation { showFinalJudgment = false }
                } label: {
                    Text("CONTINUE")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(accentColor.opacity(0.85))
                        )
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.04, green: 0.02, blue: 0.18).opacity(0.95))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
            .padding(20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.4), value: showFinalJudgment)
    }

    // MARK: - Logic

    private func startElement() {
        guard currentElementIndex < kRoutineElements.count else { finishRoutine(); return }
        timeLeft = 2.0
        showJudgePanel = false
        judgeScoresVisible = [false, false, false]
        didSwipeThisElement = false
        lastGrade = nil
        phase = .active
        runElementTimer()
    }

    private func runElementTimer() {
        elementTimer?.cancel()
        elementTimer = Task {
            let tickMs = 100
            let totalTicks = 20
            for tick in 0..<totalTicks {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(tickMs))
                await MainActor.run {
                    timeLeft = max(0, 2.0 - Double(tick + 1) * 0.1)
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if phase == .active {
                    commitResult(grade: .miss)
                }
            }
        }
    }

    private func handleSwipe(translation: CGSize) {
        guard phase == .active else { return }
        elementTimer?.cancel()
        let elapsed = Date.now.timeIntervalSince(swipeStartTime)
        let detected = resolveDirection(translation)
        guard currentElementIndex < kRoutineElements.count else { return }
        let expected = kRoutineElements[currentElementIndex].direction

        if detected == expected {
            let grade: TimingGrade = elapsed < 0.5 ? .perfect : (elapsed < 1.2 ? .good : .late)
            commitResult(grade: grade)
        } else {
            commitResult(grade: .miss)
        }
    }

    private func resolveDirection(_ t: CGSize) -> GymnasticsSwipeDir {
        let dx = t.width, dy = t.height
        let ax = abs(dx), ay = abs(dy)
        if ax > ay * 1.8 { return dx > 0 ? .right : .left }
        if ay > ax * 1.8 { return dy < 0 ? .up : .down }
        if dx > 0 { return dy < 0 ? .upRight : .upRight }
        return .upLeft
    }

    private func commitResult(grade: TimingGrade) {
        guard currentElementIndex < kRoutineElements.count else { return }
        let element = kRoutineElements[currentElementIndex]
        let rawPts = grade.points
        let deduction: Double = grade == .miss ? 1.0 : (grade == .late ? 0.5 : 0.0)
        let finalPts = max(0, Double(rawPts) - deduction)

        // Haptic feedback + screen shake + particle burst
        switch grade {
        case .perfect:
            hapticPerfect()
            triggerShake(intensity: 10)
            triggerBurst(color: .yellow, count: 20)
        case .good:
            hapticGood()
            triggerShake(intensity: 5)
            triggerBurst(color: accentColor, count: 10)
        case .late:
            hapticLate()
            triggerShake(intensity: 3)
        case .miss:
            hapticMiss()
            triggerShake(intensity: 12)
        }

        // Judge score generation
        let spread = Double(rawPts)
        let j1 = max(0, min(10, spread * 0.9  - deduction + Double.random(in: -0.5...0.5)))
        let j2 = max(0, min(10, spread * 0.95 - deduction + Double.random(in: -0.4...0.4)))
        let j3 = max(0, min(10, spread * 0.85 - deduction + Double.random(in: -0.6...0.6)))

        let result = GymElementResult(
            element: element,
            grade: grade,
            rawPoints: rawPts,
            deduction: deduction,
            finalPoints: finalPts,
            judge1: j1, judge2: j2, judge3: j3
        )
        elementResults.append(result)
        currentJudgeScores = (j1, j2, j3)
        lastGrade = grade

        // Grade flash
        gradeFlashText = grade.rawValue
        gradeFlashColor = grade.color
        withAnimation(.spring(response: 0.2)) { showGradeFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            await MainActor.run { withAnimation { showGradeFlash = false } }
        }

        // Show judge chips
        withAnimation(.spring(response: 0.3)) { showJudgePanel = true }
        for i in 0..<3 {
            Task {
                try? await Task.sleep(for: .milliseconds(180 + 140 * i))
                await MainActor.run { withAnimation { judgeScoresVisible[i] = true } }
            }
        }

        phase = .elementFeedback

        Task {
            try? await Task.sleep(for: .seconds(1.9))
            await MainActor.run {
                currentElementIndex += 1
                if currentElementIndex < totalElements { startElement() } else { finishRoutine() }
            }
        }
    }

    // MARK: - AI Timer

    private func startAITimer() {
        aiTimerTask?.cancel()
        aiTimerTask = Task {
            for _ in 0..<totalElements {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(2500))
                guard !Task.isCancelled else { return }
                await MainActor.run { advanceAIElement() }
            }
        }
    }

    private func advanceAIElement() {
        guard aiRoutineProgress < preDeterminedAIResults.count else { return }
        let pts = preDeterminedAIResults[aiRoutineProgress]
        aiElementResults.append(pts)
        aiCurrentScore += pts
        aiRoutineProgress += 1

        if pts == 10 {
            aiElementFlash = .yellow
            aiGradeText = "PERFECT"
            aiScorePopText = "+10"
        } else if pts == 7 {
            aiElementFlash = Theme.brandCyan
            aiGradeText = "GOOD"
            aiScorePopText = "+7"
        } else {
            aiElementFlash = .red
            aiGradeText = "WOBBLE"
            aiScorePopText = "+0 WOBBLE"
        }

        withAnimation(.spring(response: 0.2)) {
            showAiFlash = true
            showAIScorePop = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            await MainActor.run {
                withAnimation { showAiFlash = false; showAIScorePop = false }
            }
        }
    }

    private func finishRoutine() {
        aiTimerTask?.cancel()
        // Fill remaining AI elements if player's routine ended before AI finished
        while aiRoutineProgress < preDeterminedAIResults.count {
            advanceAIElement()
        }

        let totalPossible = Double(totalElements * 10)
        executionBar = min(1.0, max(0, totalScore / totalPossible))
        artisticImpression = min(1.0, (totalScore / totalPossible) * 0.85 + Double.random(in: 0.05...0.15))
        phase = .judging

        if !rewardApplied {
            rewardApplied = true
            let shards = playerWins ? 50 : (isDraw ? 25 : 15)
            viewModel.profile.evolutionShards += shards
        }
        GameResultService.saveResult(modeId: "gymnastics", userScore: Int(totalScore), opponentScore: aiCurrentScore)

        Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run {
                withAnimation { showFinalJudgment = true }
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            await MainActor.run { phase = .result }
        }
    }
}
