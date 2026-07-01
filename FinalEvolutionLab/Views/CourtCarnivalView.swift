import SwiftUI
import UIKit

// MARK: - Carnival Spin FX Canvas

private struct CarnivalSpinFXCanvas: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let cx = size.width / 2; let cy = size.height / 2
                let R: CGFloat = 94
                let pulse = CGFloat(0.5 + sin(t * 3.0) * 0.3)
                var rimGC = ctx; rimGC.addFilter(.blur(radius: 12))
                rimGC.stroke(Path(ellipseIn: CGRect(x: cx-R, y: cy-R, width: R*2, height: R*2)),
                             with: .color(Color.white.opacity(Double(pulse)*0.50)), lineWidth: 7)
                for i in 0..<8 {
                    let angle = t * 1.8 + Double(i) * .pi / 4.0
                    let px = cx + CGFloat(cos(angle)) * (R + 14)
                    let py = cy + CGFloat(sin(angle)) * (R + 14)
                    let sp = CGFloat(0.5 + sin(t * 4.0 + Double(i)) * 0.5)
                    var gc = ctx; gc.addFilter(.blur(radius: 2))
                    gc.fill(Path(ellipseIn: CGRect(x: px-3, y: py-3, width: 6, height: 6)),
                            with: .color(Color.yellow.opacity(Double(sp)*0.80)))
                }
            }
        }
    }
}

// MARK: - Carnival Arena Canvas (80+ ops)

private struct CarnivalArenaCanvas: View {
    let tapCount: Int
    let timeRemaining: Int
    let playerScore: Int
    let phase: CourtCarnivalPhase
    let gameIndex: Int
    let gameWon: Bool
    let gameLost: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width
                let H = size.height
                drawScene(ctx: ctx, W: W, H: H, t: t)
            }
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func drawScene(ctx: GraphicsContext, W: CGFloat, H: CGFloat, t: Double) {
        var ctx = ctx

        // ============================================================
        // CARNIVAL BG (#1–#10)
        // ============================================================

        // #1 — Night sky gradient fill
        var skyPath = Path(); skyPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.fill(skyPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.04, green: 0.02, blue: 0.14),
                Color(red: 0.08, green: 0.04, blue: 0.22),
                Color(red: 0.14, green: 0.06, blue: 0.32)
            ]),
            startPoint: CGPoint(x: W/2, y: 0),
            endPoint: CGPoint(x: W/2, y: H * 0.70)
        ))

        // #2 — Stars: 20 animated twinkle dots
        let starSeeds: [(CGFloat, CGFloat, Double)] = [
            (0.06, 0.04, 0.0), (0.14, 0.09, 1.1), (0.22, 0.03, 2.3), (0.31, 0.07, 0.7),
            (0.42, 0.02, 1.8), (0.55, 0.06, 3.1), (0.63, 0.10, 0.4), (0.71, 0.03, 2.0),
            (0.80, 0.08, 1.5), (0.90, 0.05, 2.8), (0.10, 0.15, 0.9), (0.25, 0.18, 1.6),
            (0.38, 0.13, 2.5), (0.50, 0.17, 0.2), (0.60, 0.11, 1.3), (0.75, 0.16, 2.7),
            (0.85, 0.12, 0.6), (0.93, 0.19, 1.9), (0.04, 0.20, 3.2), (0.47, 0.22, 0.8)
        ]
        for (sx, sy, phase) in starSeeds {
            let alpha = 0.4 + sin(t * 2.2 + phase) * 0.4
            let r: CGFloat = 1.5
            ctx.fill(Path(ellipseIn: CGRect(x: W*sx-r, y: H*sy-r, width: r*2, height: r*2)),
                     with: .color(Color.white.opacity(max(0, alpha))))
        }

        // #3 — Carnival tent peaks: zigzag silhouette across top third
        var tentPath = Path()
        let peakCount = 6
        let peakW = W / CGFloat(peakCount)
        tentPath.move(to: CGPoint(x: 0, y: H * 0.40))
        for i in 0..<peakCount {
            let baseX = CGFloat(i) * peakW
            let tipX = baseX + peakW * 0.5
            let tipY = H * 0.22 - CGFloat(i % 2) * H * 0.04
            tentPath.addLine(to: CGPoint(x: tipX, y: tipY))
            tentPath.addLine(to: CGPoint(x: baseX + peakW, y: H * 0.40))
        }
        tentPath.addLine(to: CGPoint(x: W, y: H))
        tentPath.addLine(to: CGPoint(x: 0, y: H))
        tentPath.closeSubpath()
        ctx.fill(tentPath, with: .color(Color(red: 0.55, green: 0.08, blue: 0.16).opacity(0.85)))

        // #4 — Tent stripe overlay (alternating red/white)
        for i in 0..<peakCount {
            let baseX = CGFloat(i) * peakW
            let tipX = baseX + peakW * 0.5
            let tipY = H * 0.22 - CGFloat(i % 2) * H * 0.04
            var stripe = Path()
            stripe.move(to: CGPoint(x: tipX, y: tipY))
            stripe.addLine(to: CGPoint(x: baseX + peakW * 0.25, y: H * 0.40))
            stripe.addLine(to: CGPoint(x: baseX + peakW * 0.75, y: H * 0.40))
            stripe.closeSubpath()
            let stripeColor = i % 2 == 0
                ? Color(red: 0.95, green: 0.92, blue: 0.88).opacity(0.12)
                : Color(red: 0.85, green: 0.20, blue: 0.20).opacity(0.18)
            ctx.fill(stripe, with: .color(stripeColor))
        }

        // #5 — Ferris wheel outline: 8-spoke circle
        let fwCX = W * 0.82; let fwCY = H * 0.32; let fwR: CGFloat = 38
        var fwGC = ctx; fwGC.addFilter(.blur(radius: 2))
        fwGC.stroke(Path(ellipseIn: CGRect(x: fwCX-fwR, y: fwCY-fwR, width: fwR*2, height: fwR*2)),
                    with: .color(Color(red: 0.9, green: 0.75, blue: 0.2).opacity(0.70)), lineWidth: 2)
        ctx.stroke(Path(ellipseIn: CGRect(x: fwCX-fwR, y: fwCY-fwR, width: fwR*2, height: fwR*2)),
                   with: .color(Color(red: 0.9, green: 0.75, blue: 0.2).opacity(0.90)), lineWidth: 1.5)
        for i in 0..<8 {
            let angle = t * 0.4 + Double(i) * .pi / 4.0
            let sx = fwCX + CGFloat(cos(angle)) * fwR
            let sy = fwCY + CGFloat(sin(angle)) * fwR
            var spoke = Path()
            spoke.move(to: CGPoint(x: fwCX, y: fwCY))
            spoke.addLine(to: CGPoint(x: sx, y: sy))
            ctx.stroke(spoke, with: .color(Color(red: 0.9, green: 0.75, blue: 0.2).opacity(0.55)), lineWidth: 1)
            // gondola dot
            ctx.fill(Path(ellipseIn: CGRect(x: sx-3, y: sy-3, width: 6, height: 6)),
                     with: .color(Color.red.opacity(0.85)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: fwCX-4, y: fwCY-4, width: 8, height: 8)),
                 with: .color(Color.yellow.opacity(0.90)))

        // #6 — String lights across top (20 bulbs on sagging line)
        let sagAmp: CGFloat = 18
        let bulbCount = 20
        var stringPath = Path()
        for i in 0...bulbCount {
            let fx = W * CGFloat(i) / CGFloat(bulbCount)
            let fy = H * 0.06 + sagAmp * CGFloat(sin(Double(i) / Double(bulbCount) * .pi))
            if i == 0 { stringPath.move(to: CGPoint(x: fx, y: fy)) }
            else { stringPath.addLine(to: CGPoint(x: fx, y: fy)) }
        }
        ctx.stroke(stringPath, with: .color(Color.white.opacity(0.25)), lineWidth: 0.8)
        let bulbColors: [Color] = [.yellow, .red, .cyan, .green, .orange, .pink, .yellow, .white,
                                   .purple, .red, .cyan, .yellow, .green, .orange, .pink, .white,
                                   .yellow, .cyan, .red, .green]
        for i in 0..<bulbCount {
            let fx = W * CGFloat(i) / CGFloat(bulbCount)
            let fy = H * 0.06 + sagAmp * CGFloat(sin(Double(i) / Double(bulbCount) * .pi))
            let flash = sin(t * 3.0 + Double(i) * 0.7) > 0
            let bColor = bulbColors[i % bulbColors.count]
            var bGC = ctx; bGC.addFilter(.blur(radius: flash ? 3 : 1))
            bGC.fill(Path(ellipseIn: CGRect(x: fx-3, y: fy-1, width: 6, height: 6)),
                     with: .color(bColor.opacity(flash ? 0.85 : 0.35)))
        }

        // #7 — Ground/grass strip
        var grassPath = Path()
        grassPath.addRect(CGRect(x: 0, y: H * 0.82, width: W, height: H * 0.18))
        ctx.fill(grassPath, with: .linearGradient(
            Gradient(colors: [Color(red: 0.12, green: 0.38, blue: 0.14), Color(red: 0.07, green: 0.22, blue: 0.08)]),
            startPoint: CGPoint(x: W/2, y: H * 0.82),
            endPoint: CGPoint(x: W/2, y: H)
        ))

        // #8 — Ground edge highlight line
        var groundLine = Path()
        groundLine.move(to: CGPoint(x: 0, y: H * 0.82))
        groundLine.addLine(to: CGPoint(x: W, y: H * 0.82))
        ctx.stroke(groundLine, with: .color(Color(red: 0.30, green: 0.70, blue: 0.30).opacity(0.45)), lineWidth: 1.5)

        // #9 — Ticket booth silhouette (left side)
        var boothBase = Path()
        boothBase.addRect(CGRect(x: W * 0.02, y: H * 0.55, width: W * 0.12, height: H * 0.27))
        ctx.fill(boothBase, with: .color(Color(red: 0.20, green: 0.10, blue: 0.35).opacity(0.90)))
        var boothRoof = Path()
        boothRoof.move(to: CGPoint(x: W * 0.00, y: H * 0.55))
        boothRoof.addLine(to: CGPoint(x: W * 0.08, y: H * 0.48))
        boothRoof.addLine(to: CGPoint(x: W * 0.16, y: H * 0.55))
        boothRoof.closeSubpath()
        ctx.fill(boothRoof, with: .color(Color(red: 0.75, green: 0.10, blue: 0.20).opacity(0.90)))
        var boothWindow = Path()
        boothWindow.addRect(CGRect(x: W * 0.04, y: H * 0.60, width: W * 0.08, height: H * 0.08))
        ctx.fill(boothWindow, with: .color(Color(red: 1.0, green: 0.90, blue: 0.60).opacity(0.65)))

        // #10 — Ferris wheel support pole
        var fwPole = Path()
        fwPole.move(to: CGPoint(x: fwCX, y: fwCY + fwR))
        fwPole.addLine(to: CGPoint(x: fwCX, y: H * 0.82))
        ctx.stroke(fwPole, with: .color(Color(red: 0.9, green: 0.75, blue: 0.2).opacity(0.60)), lineWidth: 2.5)

        // ============================================================
        // COURT / GAME AREA (#11–#22)
        // ============================================================

        // #11 — Booth frame background
        var boothFrame = Path()
        boothFrame.addRoundedRect(in: CGRect(x: W * 0.18, y: H * 0.38, width: W * 0.64, height: H * 0.46),
                                  cornerSize: CGSize(width: 8, height: 8))
        ctx.fill(boothFrame, with: .color(Color(red: 0.18, green: 0.08, blue: 0.28).opacity(0.92)))
        ctx.stroke(boothFrame, with: .color(Color(red: 0.85, green: 0.60, blue: 0.10).opacity(0.55)), lineWidth: 2)

        // #12 — Striped awning (alternating color stripes)
        let awningTop = H * 0.38; let awningBot = H * 0.48
        let stripeCount = 8
        let stripeW = W * 0.64 / CGFloat(stripeCount)
        for i in 0..<stripeCount {
            var stripe = Path()
            let sx = W * 0.18 + CGFloat(i) * stripeW
            stripe.addRect(CGRect(x: sx, y: awningTop, width: stripeW, height: awningBot - awningTop))
            let stripeCol = i % 2 == 0
                ? Color(red: 0.85, green: 0.20, blue: 0.20).opacity(0.80)
                : Color(red: 0.95, green: 0.92, blue: 0.88).opacity(0.22)
            ctx.fill(stripe, with: .color(stripeCol))
        }
        // Awning bottom edge
        var awningEdge = Path()
        awningEdge.move(to: CGPoint(x: W * 0.18, y: awningBot))
        awningEdge.addLine(to: CGPoint(x: W * 0.82, y: awningBot))
        ctx.stroke(awningEdge, with: .color(Color(red: 0.85, green: 0.60, blue: 0.10).opacity(0.70)), lineWidth: 2)

        // #13 — Bullseye target: 5 concentric rings
        let tgtCX = W * 0.50; let tgtCY = H * 0.60
        let ringColors: [Color] = [.white, .black, Color(red:0.9,green:0.1,blue:0.1),
                                   .white, Color(red:0.9,green:0.1,blue:0.1)]
        for ri in stride(from: 4, through: 0, by: -1) {
            let rr = CGFloat(ri + 1) * 9.0
            ctx.fill(Path(ellipseIn: CGRect(x: tgtCX-rr, y: tgtCY-rr, width: rr*2, height: rr*2)),
                     with: .color(ringColors[ri].opacity(0.92)))
        }
        // Bullseye center glow
        var bullGC = ctx; bullGC.addFilter(.blur(radius: 4))
        bullGC.fill(Path(ellipseIn: CGRect(x: tgtCX-5, y: tgtCY-5, width: 10, height: 10)),
                    with: .color(Color.yellow.opacity(0.70)))
        ctx.fill(Path(ellipseIn: CGRect(x: tgtCX-3, y: tgtCY-3, width: 6, height: 6)),
                 with: .color(Color.yellow.opacity(0.95)))

        // #14 — Prize shelf silhouette (right side of booth)
        var shelf = Path()
        shelf.addRect(CGRect(x: W * 0.70, y: H * 0.50, width: W * 0.10, height: H * 0.025))
        ctx.fill(shelf, with: .color(Color(red: 0.65, green: 0.45, blue: 0.20).opacity(0.85)))
        // Toy silhouettes on shelf
        for pi in 0..<3 {
            let tx = W * 0.715 + CGFloat(pi) * W * 0.028
            var toy = Path()
            toy.addEllipse(in: CGRect(x: tx-5, y: H*0.465, width: 10, height: 10))
            toy.addRect(CGRect(x: tx-3, y: H*0.475, width: 6, height: 8))
            ctx.fill(toy, with: .color(Color(red: 0.7, green: 0.3, blue: 0.7).opacity(0.75)))
        }

        // #15 — Score board on booth side (left panel)
        var sbPanel = Path()
        sbPanel.addRoundedRect(in: CGRect(x: W * 0.20, y: H * 0.50, width: W * 0.15, height: H * 0.12),
                               cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(sbPanel, with: .color(Color.black.opacity(0.75)))
        ctx.stroke(sbPanel, with: .color(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.50)), lineWidth: 1.5)
        // Score dots on board (10 lights in 2 rows)
        for sbi in 0..<10 {
            let sbx = W * 0.22 + CGFloat(sbi % 5) * W * 0.024
            let sby = H * 0.530 + CGFloat(sbi / 5) * H * 0.040
            let lit = sbi < (playerScore / 5 + 1)
            ctx.fill(Path(ellipseIn: CGRect(x: sbx-3, y: sby-3, width: 6, height: 6)),
                     with: .color(lit ? Color.yellow.opacity(0.90) : Color.gray.opacity(0.30)))
        }

        // #16 — Flashing border lights on booth frame (8 animated dots)
        let borderLightPositions: [(CGFloat, CGFloat)] = [
            (0.18, 0.38), (0.34, 0.38), (0.50, 0.38), (0.66, 0.38),
            (0.82, 0.38), (0.82, 0.61), (0.50, 0.84), (0.18, 0.61)
        ]
        for (bi, (bx, by)) in borderLightPositions.enumerated() {
            let isOn = sin(t * 4.0 + Double(bi) * 0.8) > 0
            let bColor: Color = [.yellow, .red, .cyan, .green, .orange, .pink, .yellow, .red][bi % 8]
            var blGC = ctx; blGC.addFilter(.blur(radius: isOn ? 4 : 1))
            blGC.fill(Path(ellipseIn: CGRect(x: W*bx-4, y: H*by-4, width: 8, height: 8)),
                      with: .color(bColor.opacity(isOn ? 0.90 : 0.20)))
        }

        // #17 — Booth counter / throw line
        var counter = Path()
        counter.addRect(CGRect(x: W * 0.25, y: H * 0.78, width: W * 0.50, height: H * 0.03))
        ctx.fill(counter, with: .color(Color(red: 0.65, green: 0.45, blue: 0.20).opacity(0.80)))
        var counterLine = Path()
        counterLine.move(to: CGPoint(x: W * 0.25, y: H * 0.78))
        counterLine.addLine(to: CGPoint(x: W * 0.75, y: H * 0.78))
        ctx.stroke(counterLine, with: .color(Color.white.opacity(0.35)), lineWidth: 1)

        // #18 — Booth back wall decoration dots
        for di in 0..<5 {
            let dx = W * (0.28 + CGFloat(di) * 0.10)
            let dy = H * 0.55
            let dflash = sin(t * 2.5 + Double(di) * 1.2) > 0.3
            ctx.fill(Path(ellipseIn: CGRect(x: dx-4, y: dy-4, width: 8, height: 8)),
                     with: .color(Color.orange.opacity(dflash ? 0.80 : 0.22)))
        }

        // #19 — Carnival banner text arc decoration (top of booth)
        var bannerBack = Path()
        bannerBack.addRoundedRect(in: CGRect(x: W * 0.30, y: H * 0.39, width: W * 0.40, height: H * 0.06),
                                  cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(bannerBack, with: .color(Color(red: 0.85, green: 0.60, blue: 0.05).opacity(0.85)))
        ctx.stroke(bannerBack, with: .color(Color.white.opacity(0.45)), lineWidth: 1)

        // #20 — Ring toss pegs (3 vertical pegs in booth)
        for pi in 0..<3 {
            let px = W * (0.42 + CGFloat(pi) * 0.06)
            var peg = Path()
            peg.move(to: CGPoint(x: px, y: H * 0.75))
            peg.addLine(to: CGPoint(x: px, y: H * 0.62))
            ctx.stroke(peg, with: .color(Color(red: 0.9, green: 0.75, blue: 0.2).opacity(0.80)), lineWidth: 3)
            ctx.fill(Path(ellipseIn: CGRect(x: px-4, y: H*0.61-4, width: 8, height: 8)),
                     with: .color(Color(red: 0.9, green: 0.75, blue: 0.2).opacity(0.90)))
        }

        // #21 — Booth side banners (left + right vertical strips)
        var leftBanner = Path()
        leftBanner.addRect(CGRect(x: W * 0.18, y: H * 0.48, width: W * 0.04, height: H * 0.32))
        ctx.fill(leftBanner, with: .linearGradient(
            Gradient(colors: [Color(red: 0.85, green: 0.20, blue: 0.20), Color(red: 0.95, green: 0.60, blue: 0.05)]),
            startPoint: CGPoint(x: W * 0.18, y: H * 0.48),
            endPoint: CGPoint(x: W * 0.18, y: H * 0.80)
        ))
        var rightBanner = Path()
        rightBanner.addRect(CGRect(x: W * 0.78, y: H * 0.48, width: W * 0.04, height: H * 0.32))
        ctx.fill(rightBanner, with: .linearGradient(
            Gradient(colors: [Color(red: 0.85, green: 0.20, blue: 0.20), Color(red: 0.95, green: 0.60, blue: 0.05)]),
            startPoint: CGPoint(x: W * 0.78, y: H * 0.48),
            endPoint: CGPoint(x: W * 0.78, y: H * 0.80)
        ))

        // #22 — Ground shadow beneath booth
        var boothShadow = Path()
        boothShadow.addEllipse(in: CGRect(x: W * 0.20, y: H * 0.835, width: W * 0.60, height: H * 0.025))
        var shadowGC = ctx; shadowGC.addFilter(.blur(radius: 8))
        shadowGC.fill(boothShadow, with: .color(Color.black.opacity(0.40)))

        // ============================================================
        // PLAYER CHARACTER (#23–#38)
        // ============================================================

        // #23 — Player body (stick figure at throw line)
        let playerX = W * 0.35; let playerBaseY = H * 0.78
        // Body
        var playerBody = Path()
        playerBody.move(to: CGPoint(x: playerX, y: playerBaseY - 36))
        playerBody.addLine(to: CGPoint(x: playerX, y: playerBaseY - 16))
        ctx.stroke(playerBody, with: .color(Color.white.opacity(0.88)), lineWidth: 2.5)

        // #24 — Player head
        ctx.fill(Path(ellipseIn: CGRect(x: playerX-6, y: playerBaseY-52, width: 12, height: 12)),
                 with: .color(Color.white.opacity(0.90)))

        // #25 — Player legs
        var leftLeg = Path()
        leftLeg.move(to: CGPoint(x: playerX, y: playerBaseY - 16))
        leftLeg.addLine(to: CGPoint(x: playerX - 8, y: playerBaseY))
        ctx.stroke(leftLeg, with: .color(Color.white.opacity(0.85)), lineWidth: 2)
        var rightLeg = Path()
        rightLeg.move(to: CGPoint(x: playerX, y: playerBaseY - 16))
        rightLeg.addLine(to: CGPoint(x: playerX + 8, y: playerBaseY))
        ctx.stroke(rightLeg, with: .color(Color.white.opacity(0.85)), lineWidth: 2)

        // #26 — Throwing arm wind-up (arc path)
        let armPhase = CGFloat(sin(t * 2.5))
        let armEndX = playerX + 22 + armPhase * 12
        let armEndY = playerBaseY - 30 - armPhase * 14
        var throwArm = Path()
        throwArm.move(to: CGPoint(x: playerX, y: playerBaseY - 32))
        throwArm.addQuadCurve(
            to: CGPoint(x: armEndX, y: armEndY),
            control: CGPoint(x: playerX + 28, y: playerBaseY - 50))
        ctx.stroke(throwArm, with: .color(Color.white.opacity(0.85)), lineWidth: 2)

        // #27 — Ball in throwing hand
        var ballGC = ctx; ballGC.addFilter(.blur(radius: 3))
        ballGC.fill(Path(ellipseIn: CGRect(x: armEndX-7, y: armEndY-7, width: 14, height: 14)),
                    with: .color(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x: armEndX-5, y: armEndY-5, width: 10, height: 10)),
                 with: .color(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.95)))

        // #28 — Ball seam lines
        var seam1 = Path()
        seam1.move(to: CGPoint(x: armEndX - 5, y: armEndY))
        seam1.addQuadCurve(to: CGPoint(x: armEndX + 5, y: armEndY),
                           control: CGPoint(x: armEndX, y: armEndY - 4))
        ctx.stroke(seam1, with: .color(Color(red: 0.6, green: 0.2, blue: 0.0).opacity(0.70)), lineWidth: 0.8)

        // #29 — Projectile path arc (dotted)
        let throwProgress = CGFloat(fmod(t * 0.8, 1.0))
        let arcStartX = armEndX; let arcStartY = armEndY
        let arcEndX = tgtCX; let arcEndY = tgtCY
        let arcCtrlX = (arcStartX + arcEndX) / 2; let arcCtrlY = min(arcStartY, arcEndY) - H * 0.18
        for step in 0..<8 {
            let u = CGFloat(step) / 8.0
            let bx2 = (1-u)*(1-u)*arcStartX + 2*(1-u)*u*arcCtrlX + u*u*arcEndX
            let by2 = (1-u)*(1-u)*arcStartY + 2*(1-u)*u*arcCtrlY + u*u*arcEndY
            let alpha = 0.15 + Double(step) * 0.06
            ctx.fill(Path(ellipseIn: CGRect(x: bx2-2, y: by2-2, width: 4, height: 4)),
                     with: .color(Color.white.opacity(alpha)))
        }

        // #30 — In-flight projectile dot
        let projU = throwProgress
        let projX = (1-projU)*(1-projU)*arcStartX + 2*(1-projU)*projU*arcCtrlX + projU*projU*arcEndX
        let projY = (1-projU)*(1-projU)*arcStartY + 2*(1-projU)*projU*arcCtrlY + projU*projU*arcEndY
        var projGC = ctx; projGC.addFilter(.blur(radius: 2))
        projGC.fill(Path(ellipseIn: CGRect(x: projX-6, y: projY-6, width: 12, height: 12)),
                    with: .color(Color.orange.opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x: projX-4, y: projY-4, width: 8, height: 8)),
                 with: .color(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.95)))

        // #31 — Projectile motion trail (4 fading dots)
        for trail in 1...4 {
            let tu = max(0, projU - CGFloat(trail) * 0.07)
            let tx2 = (1-tu)*(1-tu)*arcStartX + 2*(1-tu)*tu*arcCtrlX + tu*tu*arcEndX
            let ty2 = (1-tu)*(1-tu)*arcStartY + 2*(1-tu)*tu*arcCtrlY + tu*tu*arcEndY
            ctx.fill(Path(ellipseIn: CGRect(x: tx2-2, y: ty2-2, width: 4, height: 4)),
                     with: .color(Color.orange.opacity(0.35 / Double(trail))))
        }

        // #32 — Crowd spectator 1 (leftmost, cyan)
        let crowdColors: [Color] = [.cyan, .orange, .yellow, .green, .pink, .purple, .white, .red, .cyan, .yellow]
        do {
            let cx2 = W * 0.04; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 0.0)) * 2.5
            let cH: CGFloat = 16; let cColor = crowdColors[0].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #33 — Crowd spectator 2 (orange)
        do {
            let cx2 = W * 0.13; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 0.65)) * 2.5
            let cH: CGFloat = 19; let cColor = crowdColors[1].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #34 — Crowd spectator 3 (yellow)
        do {
            let cx2 = W * 0.22; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 1.3)) * 2.5
            let cH: CGFloat = 16; let cColor = crowdColors[2].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #35 — Crowd spectator 4 (green)
        do {
            let cx2 = W * 0.31; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 1.95)) * 2.5
            let cH: CGFloat = 19; let cColor = crowdColors[3].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #36 — Crowd spectator 5 (pink)
        do {
            let cx2 = W * 0.40; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 2.6)) * 2.5
            let cH: CGFloat = 16; let cColor = crowdColors[4].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #37 — Crowd spectator 6 (purple, center-right)
        do {
            let cx2 = W * 0.58; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 3.25)) * 2.5
            let cH: CGFloat = 19; let cColor = crowdColors[5].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #38 — Crowd spectator 7 (white)
        do {
            let cx2 = W * 0.67; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 3.9)) * 2.5
            let cH: CGFloat = 16; let cColor = crowdColors[6].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #39 — Crowd spectator 8 (red)
        do {
            let cx2 = W * 0.76; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 4.55)) * 2.5
            let cH: CGFloat = 19; let cColor = crowdColors[7].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #40 — Crowd spectator 9 (cyan, far right)
        do {
            let cx2 = W * 0.85; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 5.20)) * 2.5
            let cH: CGFloat = 16; let cColor = crowdColors[8].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }
        // #41 — Crowd spectator 10 (yellow, rightmost)
        do {
            let cx2 = W * 0.94; let bobY = H * 0.385 + CGFloat(sin(t * 1.8 + 5.85)) * 2.5
            let cH: CGFloat = 19; let cColor = crowdColors[9].opacity(0.55)
            var cHead = Path(); cHead.addEllipse(in: CGRect(x: cx2-4, y: bobY-cH, width: 8, height: 8))
            ctx.fill(cHead, with: .color(cColor))
            var cBody = Path(); cBody.move(to: CGPoint(x: cx2, y: bobY-cH+8)); cBody.addLine(to: CGPoint(x: cx2, y: bobY))
            ctx.stroke(cBody, with: .color(cColor), lineWidth: 1.2)
        }

        // #42 — Vendor passing by (right side silhouette)
        let vendorX = W * CGFloat(fmod(t * 0.12, 1.2) - 0.1)
        let vendorY = H * 0.80
        var vendorBody = Path()
        vendorBody.move(to: CGPoint(x: vendorX, y: vendorY - 32))
        vendorBody.addLine(to: CGPoint(x: vendorX, y: vendorY - 12))
        ctx.stroke(vendorBody, with: .color(Color(red: 0.85, green: 0.65, blue: 0.15).opacity(0.75)), lineWidth: 2)
        ctx.fill(Path(ellipseIn: CGRect(x: vendorX-5, y: vendorY-44, width: 10, height: 10)),
                 with: .color(Color(red: 0.85, green: 0.65, blue: 0.15).opacity(0.80)))
        // Vendor tray
        var vendorTray = Path()
        vendorTray.addRect(CGRect(x: vendorX-10, y: vendorY-30, width: 20, height: 4))
        ctx.fill(vendorTray, with: .color(Color(red: 0.85, green: 0.65, blue: 0.15).opacity(0.65)))

        // ============================================================
        // HIT EFFECTS (#43–#58)
        // ============================================================

        // #43 — Target hit burst: 8-ray star (pulses on beat)
        let hitPulse = CGFloat(0.5 + sin(t * 5.0) * 0.5)
        let hitPhase = gameWon ? 1.0 : hitPulse * 0.3
        var hitGC = ctx; hitGC.addFilter(.blur(radius: 6))
        for ray in 0..<8 {
            let rayAngle = Double(ray) * .pi / 4.0 + t * 2.0
            let rayLen: CGFloat = 22 * CGFloat(hitPhase)
            var rayPath = Path()
            rayPath.move(to: CGPoint(x: tgtCX, y: tgtCY))
            rayPath.addLine(to: CGPoint(x: tgtCX + CGFloat(cos(rayAngle)) * rayLen,
                                        y: tgtCY + CGFloat(sin(rayAngle)) * rayLen))
            hitGC.stroke(rayPath, with: .color(Color.yellow.opacity(Double(hitPhase) * 0.80)), lineWidth: 2)
        }

        // #44 — Ring-smash debris: 6 small rects flying out
        if gameWon {
            for di in 0..<6 {
                let debAngle = Double(di) * .pi / 3.0 + t * 3.0
                let debDist: CGFloat = 28 + CGFloat(fmod(t, 1.0)) * 20
                let debX = tgtCX + CGFloat(cos(debAngle)) * debDist
                let debY = tgtCY + CGFloat(sin(debAngle)) * debDist
                var debRect = Path()
                debRect.addRect(CGRect(x: debX-3, y: debY-2, width: 6, height: 4))
                ctx.fill(debRect, with: .color(Color.white.opacity(0.65)))
            }
        }

        // #45 — Balloon pop circle burst
        let balloonPhase = CGFloat(fmod(t * 1.5, 1.0))
        let bpR = 8 + balloonPhase * 30
        var bpGC = ctx; bpGC.addFilter(.blur(radius: 3))
        bpGC.stroke(Path(ellipseIn: CGRect(x: tgtCX-bpR, y: tgtCY-bpR-H*0.06, width: bpR*2, height: bpR*2)),
                    with: .color(Color.red.opacity(Double((1.0 - balloonPhase)) * 0.60)), lineWidth: 2)
        // Balloon fragments (6 dots)
        for bf in 0..<6 {
            let bfAngle = Double(bf) * .pi / 3.0
            let bfDist = 12 + balloonPhase * 25
            let bfX = tgtCX + CGFloat(cos(bfAngle)) * bfDist
            let bfY = tgtCY - H*0.06 + CGFloat(sin(bfAngle)) * bfDist
            ctx.fill(Path(ellipseIn: CGRect(x: bfX-2, y: bfY-2, width: 4, height: 4)),
                     with: .color(Color.red.opacity(Double(1.0 - balloonPhase) * 0.75)))
        }

        // #46 — Jackpot flash: full-screen gold tint when perfect
        if gameWon && sin(t * 8.0) > 0.5 {
            var jpPath = Path(); jpPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
            var jpGC = ctx; jpGC.addFilter(.blur(radius: 1))
            jpGC.fill(jpPath, with: .color(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.08)))
        }

        // #47 — Coin spray: 12 gold dots
        let coinPhase = CGFloat(fmod(t * 0.7, 1.0))
        for coin in 0..<12 {
            let coinAngle = Double(coin) * (.pi * 2.0 / 12.0) + t
            let coinDist = 18 + coinPhase * 40
            let coinX = W * 0.50 + CGFloat(cos(coinAngle)) * coinDist
            let coinY = H * 0.55 + CGFloat(sin(coinAngle)) * coinDist * 0.5
            let coinAlpha = Double(1.0 - coinPhase) * 0.70
            ctx.fill(Path(ellipseIn: CGRect(x: coinX-3, y: coinY-3, width: 6, height: 6)),
                     with: .color(Color(red: 1.0, green: 0.85, blue: 0.1).opacity(coinAlpha)))
        }

        // #48 — Near-miss wobble ring
        if !gameWon {
            let wobble = CGFloat(sin(t * 12.0)) * 4
            let nmR: CGFloat = 16 + wobble
            var nmGC = ctx; nmGC.addFilter(.blur(radius: 2))
            nmGC.stroke(Path(ellipseIn: CGRect(x: tgtCX-nmR, y: tgtCY-nmR, width: nmR*2, height: nmR*2)),
                        with: .color(Color.orange.opacity(0.55)), lineWidth: 2)
        }

        // #49 — Hit impact flash (concentric burst rings)
        for ringIdx in 0..<3 {
            let rPhase = CGFloat(fmod(t * 2.0 + Double(ringIdx) * 0.33, 1.0))
            let rR: CGFloat = 10 + rPhase * 35
            let rAlpha = Double(1.0 - rPhase) * 0.50
            ctx.stroke(Path(ellipseIn: CGRect(x: tgtCX-rR, y: tgtCY-rR, width: rR*2, height: rR*2)),
                       with: .color(Color.yellow.opacity(rAlpha)), lineWidth: 1.5)
        }

        // #50 — Score bump glow on board when points earned
        if playerScore > 0 {
            var scoreGlowGC = ctx; scoreGlowGC.addFilter(.blur(radius: 10))
            scoreGlowGC.fill(Path(ellipseIn: CGRect(x: W*0.20, y: H*0.50, width: W*0.15, height: H*0.12)),
                             with: .color(Color.yellow.opacity(0.22 + sin(t * 4.0) * 0.10)))
        }

        // #51 — Sparkle burst: 8 star points at bullseye
        let sparkPhase = CGFloat(fmod(t * 3.0, 1.0))
        for sp2 in 0..<8 {
            let spAngle = Double(sp2) * .pi / 4.0 + t * 5.0
            let spDist = 6 + sparkPhase * 16
            let spX = tgtCX + CGFloat(cos(spAngle)) * spDist
            let spY = tgtCY + CGFloat(sin(spAngle)) * spDist
            ctx.fill(Path(ellipseIn: CGRect(x: spX-1.5, y: spY-1.5, width: 3, height: 3)),
                     with: .color(Color.white.opacity(Double(1.0 - sparkPhase) * 0.80)))
        }

        // #52 — Ring-toss ring in-flight
        let rtPhase = CGFloat(fmod(t * 0.6, 1.0))
        let rtX = playerX + (tgtCX - playerX) * rtPhase
        let rtY = playerBaseY - 40 + (tgtCY - (playerBaseY - 40)) * rtPhase - CGFloat(sin(Double(rtPhase) * .pi)) * 30
        ctx.stroke(Path(ellipseIn: CGRect(x: rtX-10, y: rtY-5, width: 20, height: 10)),
                   with: .color(Color(red: 0.9, green: 0.75, blue: 0.2).opacity(0.80)), lineWidth: 2)

        // #53 — Peg-hit bounce sparks (3 dots near pegs)
        for pi2 in 0..<3 {
            let px2 = W * (0.42 + CGFloat(pi2) * 0.06)
            let sparkA = CGFloat(fmod(t * 2.0 + Double(pi2) * 0.5, 1.0))
            let spY2 = H * 0.62 - sparkA * 12
            ctx.fill(Path(ellipseIn: CGRect(x: px2-2, y: spY2-2, width: 4, height: 4)),
                     with: .color(Color.yellow.opacity(Double(1.0 - sparkA) * 0.70)))
        }

        // #54 — Target hit ripple overlay
        let ripplePhase = CGFloat(fmod(t * 1.8, 1.0))
        let rippleR = 5 + ripplePhase * 50
        var rippleGC = ctx; rippleGC.addFilter(.blur(radius: 4))
        rippleGC.stroke(Path(ellipseIn: CGRect(x: tgtCX-rippleR, y: tgtCY-rippleR, width: rippleR*2, height: rippleR*2)),
                        with: .color(Color.white.opacity(Double(1.0 - ripplePhase) * 0.25)), lineWidth: 2)

        // ============================================================
        // PRIZE FX (#55–#68)
        // ============================================================

        // #55 — Stuffed animal prize drop animation (falling rect)
        let dropPhase = CGFloat(fmod(t * 0.5, 1.0))
        let dropY = H * 0.50 + dropPhase * H * 0.20
        var dropToy = Path()
        dropToy.addRoundedRect(in: CGRect(x: W*0.65, y: dropY, width: 16, height: 18),
                               cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(dropToy, with: .color(Color(red: 0.7, green: 0.3, blue: 0.7).opacity(Double(1.0 - dropPhase) * 0.75)))

        // #56 — Confetti burst: 20 colored dots
        let confettiSeeds: [(Double, Double, Double)] = [
            (0.4, 0.5, 0.0), (0.55, 0.45, 0.8), (0.6, 0.6, 1.6), (0.45, 0.65, 2.4),
            (0.5, 0.42, 3.2), (0.38, 0.55, 0.4), (0.62, 0.52, 1.2), (0.48, 0.70, 2.0),
            (0.52, 0.48, 2.8), (0.42, 0.58, 3.6), (0.58, 0.62, 0.6), (0.44, 0.46, 1.4),
            (0.56, 0.66, 2.2), (0.50, 0.56, 3.0), (0.46, 0.64, 3.8), (0.54, 0.44, 0.2),
            (0.40, 0.60, 1.0), (0.60, 0.56, 1.8), (0.48, 0.50, 2.6), (0.52, 0.60, 3.4)
        ]
        let confColors: [Color] = [.yellow, .red, .cyan, .green, .orange, .pink, .white, .purple]
        for (ci2, (cx3, cy3, cphase)) in confettiSeeds.enumerated() {
            let cDrift = CGFloat(fmod(t * 0.8 + cphase, 1.0))
            let cX = W * CGFloat(cx3) + CGFloat(sin(t * 2.0 + cphase)) * 15
            let cY = H * CGFloat(cy3) + cDrift * 20
            ctx.fill(Path(ellipseIn: CGRect(x: cX-3, y: cY-3, width: 6, height: 6)),
                     with: .color(confColors[ci2 % confColors.count].opacity(Double(1.0 - cDrift) * 0.80)))
        }

        // #57 — Win banner unfurl (animated width)
        if gameWon {
            let bannerW = W * 0.50 * CGFloat(min(1.0, fmod(t, 1.5) / 0.8))
            var winBanner = Path()
            winBanner.addRoundedRect(in: CGRect(x: (W - bannerW) / 2, y: H * 0.32, width: bannerW, height: H * 0.07),
                                     cornerSize: CGSize(width: 6, height: 6))
            ctx.fill(winBanner, with: .color(Color(red: 0.85, green: 0.60, blue: 0.05).opacity(0.90)))
            ctx.stroke(winBanner, with: .color(Color.white.opacity(0.70)), lineWidth: 1.5)
        }

        // #58 — Combo multiplier glow (pulsing circle behind score)
        let comboScale = 1.0 + sin(t * 4.0) * 0.12
        let comboR = CGFloat(18 * comboScale)
        var comboGC = ctx; comboGC.addFilter(.blur(radius: 8))
        comboGC.fill(Path(ellipseIn: CGRect(x: W*0.215-comboR, y: H*0.535-comboR, width: comboR*2, height: comboR*2)),
                     with: .color(Color(red: 0.9, green: 0.75, blue: 0.2).opacity(playerScore > 10 ? 0.45 : 0.15)))

        // #59 — Music note particles (♪ dots floating up, 5 particles)
        for ni in 0..<5 {
            let nPhase = CGFloat(fmod(t * 0.7 + Double(ni) * 0.4, 1.0))
            let nX = W * (0.22 + CGFloat(ni) * 0.12)
            let nY = H * 0.80 - nPhase * H * 0.25
            ctx.fill(Path(ellipseIn: CGRect(x: nX-3, y: nY-3, width: 6, height: 6)),
                     with: .color(Color.white.opacity(Double(1.0 - nPhase) * 0.55)))
            var noteStem = Path()
            noteStem.move(to: CGPoint(x: nX+3, y: nY-3))
            noteStem.addLine(to: CGPoint(x: nX+3, y: nY-10))
            ctx.stroke(noteStem, with: .color(Color.white.opacity(Double(1.0 - nPhase) * 0.45)), lineWidth: 1)
        }

        // #60 — Prize sparkle halo (rotating dots around prize shelf)
        for halo in 0..<8 {
            let hAngle = t * 1.5 + Double(halo) * .pi / 4.0
            let hR: CGFloat = 22
            let hX = W * 0.75 + CGFloat(cos(hAngle)) * hR
            let hY = H * 0.49 + CGFloat(sin(hAngle)) * hR * 0.5
            ctx.fill(Path(ellipseIn: CGRect(x: hX-2, y: hY-2, width: 4, height: 4)),
                     with: .color(Color(red: 1.0, green: 0.85, blue: 0.1).opacity(0.60)))
        }

        // #61 — Falling ticket strips (3 animating rects)
        for tk in 0..<3 {
            let tkPhase = CGFloat(fmod(t * 0.4 + Double(tk) * 0.33, 1.0))
            let tkX = W * (0.30 + CGFloat(tk) * 0.20) + CGFloat(sin(t * 1.5 + Double(tk))) * 8
            let tkY = H * 0.35 + tkPhase * H * 0.50
            var ticket = Path()
            ticket.addRect(CGRect(x: tkX-4, y: tkY-8, width: 8, height: 16))
            ctx.fill(ticket, with: .color(Color(red: 1.0, green: 0.90, blue: 0.40).opacity(Double(1.0 - tkPhase) * 0.60)))
        }

        // #62 — Glow halo around entire booth frame
        var frameGlowGC = ctx; frameGlowGC.addFilter(.blur(radius: 14))
        var frameGlowPath = Path()
        frameGlowPath.addRoundedRect(in: CGRect(x: W * 0.18, y: H * 0.38, width: W * 0.64, height: H * 0.46),
                                     cornerSize: CGSize(width: 8, height: 8))
        frameGlowGC.stroke(frameGlowPath,
                           with: .color(Color(red: 0.85, green: 0.60, blue: 0.10).opacity(0.25 + sin(t * 2.0) * 0.10)),
                           lineWidth: 4)

        // #63 — Animated banner fringe (bottom of awning, 8 triangles)
        let fringeCount = 8
        let fringeW = W * 0.64 / CGFloat(fringeCount)
        for fi2 in 0..<fringeCount {
            let fX = W * 0.18 + CGFloat(fi2) * fringeW
            let fSway = CGFloat(sin(t * 2.0 + Double(fi2) * 0.5)) * 3
            var fringe = Path()
            fringe.move(to: CGPoint(x: fX, y: H * 0.48))
            fringe.addLine(to: CGPoint(x: fX + fringeW/2, y: H * 0.48 + 10 + fSway))
            fringe.addLine(to: CGPoint(x: fX + fringeW, y: H * 0.48))
            fringe.closeSubpath()
            let fColor: Color = fi2 % 2 == 0 ? .yellow : .red
            ctx.fill(fringe, with: .color(fColor.opacity(0.80)))
        }

        // #64 — Spotlight cone from top (animated sweep)
        let spotAngle = CGFloat(sin(t * 0.5)) * W * 0.15
        var spotPath = Path()
        spotPath.move(to: CGPoint(x: W * 0.5 + spotAngle, y: 0))
        spotPath.addLine(to: CGPoint(x: W * 0.30 + spotAngle, y: H * 0.45))
        spotPath.addLine(to: CGPoint(x: W * 0.70 + spotAngle, y: H * 0.45))
        spotPath.closeSubpath()
        var spotGC = ctx; spotGC.addFilter(.blur(radius: 20))
        spotGC.fill(spotPath, with: .color(Color.white.opacity(0.06)))

        // #65 — Extra coin shimmer: 6 rotating coins
        for rc in 0..<6 {
            let rcAngle = t * 2.0 + Double(rc) * .pi / 3.0
            let rcR: CGFloat = 38
            let rcX = W * 0.50 + CGFloat(cos(rcAngle)) * rcR
            let rcY = H * 0.55 + CGFloat(sin(rcAngle)) * rcR * 0.4
            let rcAlpha = 0.3 + sin(t * 3.0 + Double(rc)) * 0.2
            ctx.fill(Path(ellipseIn: CGRect(x: rcX-4, y: rcY-4, width: 8, height: 8)),
                     with: .color(Color(red: 1.0, green: 0.85, blue: 0.1).opacity(max(0, rcAlpha))))
        }

        // #66 — Booth back wall pattern (cross-hatch lines)
        for li in 0..<4 {
            let ly = H * (0.50 + CGFloat(li) * 0.055)
            var hline = Path()
            hline.move(to: CGPoint(x: W * 0.22, y: ly))
            hline.addLine(to: CGPoint(x: W * 0.78, y: ly))
            ctx.stroke(hline, with: .color(Color.white.opacity(0.06)), lineWidth: 1)
        }

        // #67 — Animated sparkle at booth corners (4 corners)
        let cornerPositions: [(CGFloat, CGFloat)] = [
            (0.18, 0.38), (0.82, 0.38), (0.18, 0.84), (0.82, 0.84)
        ]
        for (ci3, (cpx, cpy)) in cornerPositions.enumerated() {
            let csStar = CGFloat(0.5 + sin(t * 3.5 + Double(ci3) * 1.2) * 0.5)
            var csGC = ctx; csGC.addFilter(.blur(radius: 3))
            csGC.fill(Path(ellipseIn: CGRect(x: W*cpx-5, y: H*cpy-5, width: 10, height: 10)),
                      with: .color(Color.white.opacity(Double(csStar) * 0.65)))
        }

        // #68 — Ground reflection strip
        var reflectionPath = Path()
        reflectionPath.addRect(CGRect(x: W * 0.18, y: H * 0.84, width: W * 0.64, height: H * 0.02))
        var reflGC = ctx; reflGC.addFilter(.blur(radius: 6))
        reflGC.fill(reflectionPath, with: .color(Color(red: 0.85, green: 0.60, blue: 0.10).opacity(0.25)))

        // ============================================================
        // SCORE / UI ON CANVAS (#69–#84)
        // ============================================================

        // #69 — Ticket count display panel
        var ticketPanel = Path()
        ticketPanel.addRoundedRect(in: CGRect(x: W * 0.05, y: H * 0.06, width: W * 0.28, height: H * 0.10),
                                   cornerSize: CGSize(width: 6, height: 6))
        ctx.fill(ticketPanel, with: .color(Color.black.opacity(0.72)))
        ctx.stroke(ticketPanel, with: .color(Color(red: 1.0, green: 0.85, blue: 0.1).opacity(0.55)), lineWidth: 1.5)

        // #70 — Ticket count glow
        var tickGlowGC = ctx; tickGlowGC.addFilter(.blur(radius: 8))
        tickGlowGC.fill(Path(ellipseIn: CGRect(x: W*0.05, y: H*0.06, width: W*0.28, height: H*0.10)),
                        with: .color(Color(red: 1.0, green: 0.85, blue: 0.1).opacity(0.12)))

        // #71 — Ticket icon dots (3 small circles representing tickets)
        for ti in 0..<3 {
            let tix = W * 0.08 + CGFloat(ti) * W * 0.07
            let tiy = H * 0.11
            ctx.fill(Path(ellipseIn: CGRect(x: tix-4, y: tiy-4, width: 8, height: 8)),
                     with: .color(Color(red: 1.0, green: 0.90, blue: 0.40).opacity(ti < (playerScore / 15 + 1) ? 0.90 : 0.25)))
        }

        // #72 — Shot count tracker (star icons — 5 stars)
        for si in 0..<5 {
            let six = W * 0.67 + CGFloat(si) * W * 0.055
            let siy = H * 0.09
            let filled = si < tapCount / 5
            for ray2 in 0..<5 {
                let rAngle2 = Double(ray2) * .pi * 2 / 5.0 - .pi / 2
                var starPath = Path()
                starPath.move(to: CGPoint(x: six, y: siy))
                starPath.addLine(to: CGPoint(x: six + CGFloat(cos(rAngle2)) * 5, y: siy + CGFloat(sin(rAngle2)) * 5))
                ctx.stroke(starPath, with: .color(filled ? Color.yellow.opacity(0.90) : Color.gray.opacity(0.28)), lineWidth: 1.2)
            }
        }

        // #73 — High score crown indicator (top-center glow)
        if playerScore >= 30 {
            var crownGC = ctx; crownGC.addFilter(.blur(radius: 12))
            crownGC.fill(Path(ellipseIn: CGRect(x: W*0.44, y: H*0.035, width: W*0.12, height: H*0.05)),
                         with: .color(Color(red: 1.0, green: 0.85, blue: 0.1).opacity(0.50)))
            // Crown points (3 triangles)
            for cp in 0..<3 {
                let cpX = W * 0.46 + CGFloat(cp) * W * 0.04
                var crown = Path()
                crown.move(to: CGPoint(x: cpX, y: H * 0.055))
                crown.addLine(to: CGPoint(x: cpX - W * 0.016, y: H * 0.08))
                crown.addLine(to: CGPoint(x: cpX + W * 0.016, y: H * 0.08))
                crown.closeSubpath()
                ctx.fill(crown, with: .color(Color(red: 1.0, green: 0.85, blue: 0.1).opacity(0.90)))
            }
        }

        // #74 — Time remaining arc meter (bottom right corner)
        let arcRadius: CGFloat = 22
        let arcCX = W * 0.91; let arcCY = H * 0.92
        // Background arc
        var bgArc = Path()
        bgArc.addArc(center: CGPoint(x: arcCX, y: arcCY), radius: arcRadius,
                     startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
        ctx.stroke(bgArc, with: .color(Color.white.opacity(0.15)), lineWidth: 4)
        // Fill arc based on time
        let timeFraction = Double(timeRemaining) / 10.0
        let arcEnd = -90 + timeFraction * 360
        var fillArc = Path()
        fillArc.addArc(center: CGPoint(x: arcCX, y: arcCY), radius: arcRadius,
                       startAngle: .degrees(-90), endAngle: .degrees(arcEnd), clockwise: false)
        let arcColor: Color = timeRemaining > 3 ? Color(red: 0.2, green: 0.9, blue: 0.4) : Color.red
        ctx.stroke(fillArc, with: .color(arcColor.opacity(0.85)), lineWidth: 4)
        // Arc glow
        var arcGlowGC = ctx; arcGlowGC.addFilter(.blur(radius: 4))
        arcGlowGC.stroke(fillArc, with: .color(arcColor.opacity(0.45)), lineWidth: 6)

        // #75 — Score font decorations (border around score area)
        var scoreDecor = Path()
        scoreDecor.addRoundedRect(in: CGRect(x: W * 0.35, y: H * 0.04, width: W * 0.30, height: H * 0.09),
                                  cornerSize: CGSize(width: 5, height: 5))
        ctx.stroke(scoreDecor, with: .color(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.40)), lineWidth: 1.5)

        // #76 — Score display dots row (tap progress indicator)
        let tapTarget = 20
        let tapFill = min(tapCount, tapTarget)
        let dotRow = min(tapFill, 10)
        for di2 in 0..<10 {
            let dix = W * 0.37 + CGFloat(di2) * W * 0.026
            let diy = H * 0.085
            ctx.fill(Path(ellipseIn: CGRect(x: dix-3, y: diy-3, width: 6, height: 6)),
                     with: .color(di2 < dotRow ? Color.cyan.opacity(0.90) : Color.gray.opacity(0.22)))
        }

        // #77 — Animated corner flourishes (all 4 corners of the visible game area)
        let flourishCorners: [(CGFloat, CGFloat, Bool, Bool)] = [
            (0.0, 0.0, false, false), (1.0, 0.0, true, false),
            (0.0, 1.0, false, true), (1.0, 1.0, true, true)
        ]
        for (fcx, fcy, flipX, flipY) in flourishCorners {
            let fsw: CGFloat = flipX ? -1 : 1
            let fsh: CGFloat = flipY ? -1 : 1
            let fx2 = W * fcx + (flipX ? -4 : 4)
            let fy2 = H * fcy + (flipY ? -4 : 4)
            var flourish = Path()
            flourish.move(to: CGPoint(x: fx2, y: fy2))
            flourish.addLine(to: CGPoint(x: fx2 + fsw * 18, y: fy2))
            flourish.move(to: CGPoint(x: fx2, y: fy2))
            flourish.addLine(to: CGPoint(x: fx2, y: fy2 + fsh * 18))
            ctx.stroke(flourish, with: .color(Color(red: 0.85, green: 0.60, blue: 0.10).opacity(0.45)), lineWidth: 2)
        }

        // #78 — Vignette overlay (darken edges)
        var vigPath = Path(); vigPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.fill(vigPath, with: .radialGradient(
            Gradient(colors: [Color.clear, Color.black.opacity(0.45)]),
            center: CGPoint(x: W/2, y: H/2),
            startRadius: min(W, H) * 0.3,
            endRadius: max(W, H) * 0.7
        ))

        // #79 — Tap ripple at player location
        let tapRipplePhase = CGFloat(fmod(t * 2.5, 1.0))
        let trR = 8 + tapRipplePhase * 24
        var tapRippleGC = ctx; tapRippleGC.addFilter(.blur(radius: 2))
        tapRippleGC.stroke(Path(ellipseIn: CGRect(x: playerX-trR, y: (playerBaseY-34)-trR, width: trR*2, height: trR*2)),
                           with: .color(Color.white.opacity(Double(1.0 - tapRipplePhase) * 0.30)), lineWidth: 1.5)

        // #80 — Game index indicator dots (top right mini dots)
        for gi2 in 0..<5 {
            let gdX = W * 0.78 + CGFloat(gi2) * W * 0.036
            let gdY = H * 0.025
            ctx.fill(Path(ellipseIn: CGRect(x: gdX-4, y: gdY-4, width: 8, height: 8)),
                     with: .color(gi2 <= gameIndex
                                  ? Color(red: 0.85, green: 0.60, blue: 0.10).opacity(0.90)
                                  : Color.gray.opacity(0.25)))
        }

        // #81 — Animated score value pulse circle (behind score area)
        let pulseSz = CGFloat(1.0 + sin(t * 3.5) * 0.08)
        let pulseR2 = 22 * pulseSz
        var pulseGC = ctx; pulseGC.addFilter(.blur(radius: 10))
        pulseGC.fill(Path(ellipseIn: CGRect(x: W*0.50-pulseR2, y: H*0.07-pulseR2, width: pulseR2*2, height: pulseR2*2)),
                     with: .color(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.15)))

        // #82 — Speed lines behind projectile (motion blur effect)
        for sl in 0..<5 {
            let slFrac = CGFloat(sl) / 5.0
            let slU = projU - slFrac * 0.12
            guard slU > 0 else { continue }
            let slX = (1-slU)*(1-slU)*arcStartX + 2*(1-slU)*slU*arcCtrlX + slU*slU*arcEndX
            let slY = (1-slU)*(1-slU)*arcStartY + 2*(1-slU)*slU*arcCtrlY + slU*slU*arcEndY
            let slAlpha = Double(1.0 - slFrac) * 0.18
            var speedLine = Path()
            speedLine.move(to: CGPoint(x: slX - 10, y: slY))
            speedLine.addLine(to: CGPoint(x: slX + 10, y: slY))
            ctx.stroke(speedLine, with: .color(Color.white.opacity(slAlpha)), lineWidth: 1)
        }

        // #83 — Ambient floating particles (5 small dots drifting)
        for ap in 0..<5 {
            let apPhase = CGFloat(fmod(t * 0.35 + Double(ap) * 0.6, 1.0))
            let apX = W * (0.15 + CGFloat(ap) * 0.18) + CGFloat(sin(t * 0.8 + Double(ap))) * 12
            let apY = H * 0.90 - apPhase * H * 0.65
            ctx.fill(Path(ellipseIn: CGRect(x: apX-2, y: apY-2, width: 4, height: 4)),
                     with: .color(Color.white.opacity(Double(1.0 - apPhase) * 0.28)))
        }

        // #84 — Bottom score ticker strip
        var tickerStrip = Path()
        tickerStrip.addRect(CGRect(x: 0, y: H * 0.955, width: W, height: H * 0.045))
        ctx.fill(tickerStrip, with: .color(Color.black.opacity(0.55)))
        // Ticker dots
        for td in 0..<Int(W / 12) {
            let tdX = CGFloat(td) * 12 + CGFloat(fmod(t * 30, 12))
            ctx.fill(Path(ellipseIn: CGRect(x: tdX-2, y: H*0.97-2, width: 4, height: 4)),
                     with: .color(Color(red: 1.0, green: 0.85, blue: 0.1).opacity(0.28)))
        }
    }
}

// MARK: - Mini-Game Canvas (per-game animated scene)

private struct CarnivalGameCanvas: View {
    let game: CarnivalGame
    let tapCount: Int

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width; let H = size.height
                switch game.icon {
                case "figure.basketball": drawDribble(&ctx, W, H, t)
                case "figure.run":        drawSprint(&ctx, W, H, t)
                case "arrow.up.circle.fill": drawJump(&ctx, W, H, t)
                case "tennis.racket":     drawRally(&ctx, W, H, t)
                default:                  drawTrickShot(&ctx, W, H, t)
                }
            }
        }
    }

    private func drawDribble(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        let floorY = H * 0.82
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: W, height: H-floorY)),
                 with: .color(Color(red: 0.10, green: 0.18, blue: 0.35)))
        var fl = Path(); fl.move(to: CGPoint(x: 0, y: floorY)); fl.addLine(to: CGPoint(x: W, y: floorY))
        ctx.stroke(fl, with: .color(Color.white.opacity(0.22)), lineWidth: 1.5)
        let ballCount = min(3, max(1, tapCount / 7 + 1))
        for b in 0..<ballCount {
            let xp = Double(b) * 0.33
            let bx = W * CGFloat(0.22 + xp * 0.56 + sin(t * 0.8 + xp) * 0.06)
            let rawY = CGFloat(abs(sin(t * 3.5 + Double(b) * 1.4)))
            let by = floorY - 6 - rawY * H * 0.55
            let r: CGFloat = 13
            ctx.fill(Path(ellipseIn: CGRect(x: bx-r, y: by-r, width: r*2, height: r*2)),
                     with: .color(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.90)))
            let sw = r * 2 * (1 - rawY * 0.6)
            ctx.fill(Path(ellipseIn: CGRect(x: bx-sw/2, y: floorY-3, width: sw, height: 5)),
                     with: .color(Color.black.opacity(Double(0.28 * (1 - rawY * 0.7)))))
        }
        for i in 0..<4 {
            let phase = fmod(t * 2.0 + Double(i) * 0.4, 1.0)
            let lx = W * CGFloat(phase)
            let y = H * CGFloat(0.22 + Double(i) * 0.14)
            var sl = Path(); sl.move(to: CGPoint(x: lx-22, y: y)); sl.addLine(to: CGPoint(x: lx, y: y))
            ctx.stroke(sl, with: .color(Color.orange.opacity(0.18)), lineWidth: 1)
        }
    }

    private func drawSprint(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        let groundY = H * 0.78
        ctx.fill(Path(CGRect(x: 0, y: groundY, width: W, height: H-groundY)),
                 with: .color(Color(red: 0.55, green: 0.28, blue: 0.08).opacity(0.35)))
        var gl = Path(); gl.move(to: CGPoint(x: 0, y: groundY)); gl.addLine(to: CGPoint(x: W, y: groundY))
        ctx.stroke(gl, with: .color(Color.white.opacity(0.20)), lineWidth: 1)
        for i in 0..<2 {
            let y = H * CGFloat(0.40 + Double(i) * 0.20)
            var ln = Path(); ln.move(to: CGPoint(x: 0, y: y)); ln.addLine(to: CGPoint(x: W, y: y))
            ctx.stroke(ln, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
        }
        let runX = W * CGFloat(fmod(t * 0.22, 1.0))
        let cy = groundY - 30
        let stride = CGFloat(sin(t * 6.5))
        var body = Path(); body.move(to: CGPoint(x: runX, y: cy-18)); body.addLine(to: CGPoint(x: runX, y: cy))
        ctx.stroke(body, with: .color(Color.green.opacity(0.90)), lineWidth: 2.5)
        ctx.fill(Path(ellipseIn: CGRect(x: runX-5, y: cy-28, width: 10, height: 10)),
                 with: .color(Color.green.opacity(0.90)))
        var ll = Path(); ll.move(to: CGPoint(x: runX, y: cy)); ll.addLine(to: CGPoint(x: runX-10*stride, y: cy+18))
        ctx.stroke(ll, with: .color(Color.green.opacity(0.80)), lineWidth: 2)
        var rl = Path(); rl.move(to: CGPoint(x: runX, y: cy)); rl.addLine(to: CGPoint(x: runX+10*stride, y: cy+18))
        ctx.stroke(rl, with: .color(Color.green.opacity(0.80)), lineWidth: 2)
        var la = Path(); la.move(to: CGPoint(x: runX, y: cy-12)); la.addLine(to: CGPoint(x: runX+14*stride, y: cy-2))
        ctx.stroke(la, with: .color(Color.green.opacity(0.70)), lineWidth: 2)
        for i in 0..<5 {
            let llen = CGFloat(18 + i * 9)
            let ly = cy - 18 + CGFloat(i) * 9
            var sl = Path(); sl.move(to: CGPoint(x: runX-llen-5, y: ly)); sl.addLine(to: CGPoint(x: runX-5, y: ly))
            ctx.stroke(sl, with: .color(Color.green.opacity(0.07 + Double(5-i)*0.04)), lineWidth: 1.5)
        }
    }

    private func drawJump(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        let groundY = H * 0.80; let cx = W / 2
        for i in 0..<4 {
            let phase = fmod(t * 1.2 + Double(i) * 0.4, 1.0)
            let r = 15 + CGFloat(phase) * 55
            let alpha = (1.0 - phase) * 0.42
            var gc = ctx; gc.addFilter(.blur(radius: 4))
            gc.stroke(Path(ellipseIn: CGRect(x: cx-r, y: groundY-r*0.35, width: r*2, height: r*0.7)),
                      with: .color(Color.cyan.opacity(alpha*0.8)), lineWidth: 2)
            ctx.stroke(Path(ellipseIn: CGRect(x: cx-r, y: groundY-r*0.35, width: r*2, height: r*0.7)),
                       with: .color(Color.cyan.opacity(alpha*0.28)), lineWidth: 1)
        }
        let jumpH = CGFloat(sin(fmod(t * 1.5, 1.0) * .pi)) * H * 0.50
        let fy = groundY - jumpH - 30
        var jb = Path(); jb.move(to: CGPoint(x: cx, y: fy-18)); jb.addLine(to: CGPoint(x: cx, y: fy))
        ctx.stroke(jb, with: .color(Color.cyan.opacity(0.90)), lineWidth: 2.5)
        ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: fy-28, width: 10, height: 10)),
                 with: .color(Color.cyan.opacity(0.90)))
        let ls = jumpH / (H * 0.50) * 14
        var ll = Path(); ll.move(to: CGPoint(x: cx, y: fy)); ll.addLine(to: CGPoint(x: cx-ls, y: fy+18))
        ctx.stroke(ll, with: .color(Color.cyan.opacity(0.80)), lineWidth: 2)
        var rl = Path(); rl.move(to: CGPoint(x: cx, y: fy)); rl.addLine(to: CGPoint(x: cx+ls, y: fy+18))
        ctx.stroke(rl, with: .color(Color.cyan.opacity(0.80)), lineWidth: 2)
        let ss = max(CGFloat(0.18), 1.0 - jumpH / (H * 0.50) * 0.80)
        ctx.fill(Path(ellipseIn: CGRect(x: cx-18*ss, y: groundY-4, width: 36*ss, height: 8)),
                 with: .color(Color.black.opacity(Double(ss)*0.38)))
    }

    private func drawRally(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H)), with: .color(Color(red: 0.08, green: 0.18, blue: 0.08)))
        var net = Path(); net.move(to: CGPoint(x: W/2, y: 0)); net.addLine(to: CGPoint(x: W/2, y: H))
        ctx.stroke(net, with: .color(Color.white.opacity(0.28)), lineWidth: 1.5)
        let ballT = CGFloat(fmod(t * 1.2, 1.0))
        let bx = W * ballT
        let by = H * 0.50 - CGFloat(sin(ballT * .pi)) * H * 0.35
        var bGC = ctx; bGC.addFilter(.blur(radius: 3))
        bGC.fill(Path(ellipseIn: CGRect(x: bx-8, y: by-8, width: 16, height: 16)),
                 with: .color(Color.yellow.opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x: bx-5, y: by-5, width: 10, height: 10)),
                 with: .color(Color.yellow.opacity(0.95)))
        let ry = H * CGFloat(0.50 + sin(t * 1.5) * 0.20)
        ctx.stroke(Path(ellipseIn: CGRect(x: W*0.04, y: ry-14, width: 16, height: 22)),
                   with: .color(Color.yellow.opacity(0.58)), lineWidth: 2)
        ctx.stroke(Path(ellipseIn: CGRect(x: W*0.88, y: ry-14, width: 16, height: 22)),
                   with: .color(Color.yellow.opacity(0.58)), lineWidth: 2)
    }

    private func drawTrickShot(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        let floorY = H * 0.78
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: W, height: H-floorY)),
                 with: .color(Color(red: 0.10, green: 0.18, blue: 0.35)))
        var fl = Path(); fl.move(to: CGPoint(x: 0, y: floorY)); fl.addLine(to: CGPoint(x: W, y: floorY))
        ctx.stroke(fl, with: .color(Color.white.opacity(0.22)), lineWidth: 1.5)
        var pole = Path(); pole.move(to: CGPoint(x: W*0.86, y: floorY)); pole.addLine(to: CGPoint(x: W*0.86, y: H*0.20))
        ctx.stroke(pole, with: .color(Color.white.opacity(0.45)), lineWidth: 2)
        ctx.stroke(Path(CGRect(x: W*0.82, y: H*0.20, width: W*0.10, height: H*0.09)),
                   with: .color(Color.white.opacity(0.45)), lineWidth: 1.5)
        ctx.stroke(Path(ellipseIn: CGRect(x: W*0.76, y: H*0.31, width: W*0.09, height: H*0.04)),
                   with: .color(Color.orange.opacity(0.90)), lineWidth: 2)
        let ballT = CGFloat(fmod(t * 0.9, 1.0))
        let bx = W * (0.10 + ballT * 0.72)
        let arcY = floorY - CGFloat(sin(ballT * .pi)) * H * 0.52
        var bGC = ctx; bGC.addFilter(.blur(radius: 3))
        bGC.fill(Path(ellipseIn: CGRect(x: bx-9, y: arcY-9, width: 18, height: 18)),
                 with: .color(Color.orange.opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x: bx-6, y: arcY-6, width: 12, height: 12)),
                 with: .color(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.95)))
        for i in 1...4 {
            let trailT = max(CGFloat(0), ballT - CGFloat(i) * 0.06)
            let tx = W * (0.10 + trailT * 0.72)
            let ty = floorY - CGFloat(sin(trailT * .pi)) * H * 0.52
            ctx.fill(Path(ellipseIn: CGRect(x: tx-3, y: ty-3, width: 6, height: 6)),
                     with: .color(Color.orange.opacity(0.40 / Double(i))))
        }
    }
}

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

// MARK: - Phase & Types

enum CourtCarnivalPhase { case ready, spinning, playing, result }

// MARK: - CourtCarnivalView

struct CourtCarnivalView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @State private var phase: CarnivalPhase = .ready
    @State private var playerScore = 0
    @State private var currentMiniGame = 0
    @State private var miniGameResult: MiniGameResult? = nil
    @State private var timeRemaining = 10
    @State private var tapCount = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var spinAngle: Double = 0
    @State private var spinTask: Task<Void, Never>?
    @State private var showResult = false
    @State private var resultText = ""

    private enum CarnivalPhase { case ready, spinning, playing, result }
    private struct MiniGameResult { let won: Bool; let points: Int; let label: String }

    private let miniGames: [CarnivalGame] = CarnivalGame.all

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.04, blue: 0.18), Color(red: 0.02, green: 0.02, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: gameMode.name,
                    subtitle: "Spin the wheel · 5 mini-games · Win the carnival",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { phase = .spinning; spinWheel() }
                )
            case .spinning:
                spinningBody
            case .playing:
                playingBody
            case .result:
                ResultScreen(
                    winner: playerScore >= 30 ? .p1 : .p2,
                    p1Score: playerScore,
                    p2Score: 50 - playerScore,
                    title: "Court Carnival",
                    accentColor: gameMode.accentColor,
                    prqGain: playerScore >= 30 ? 8 : 2,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "CARNIVAL",
                    modeAttributeValue: Double(playerScore) / 50.0,
                    onReturn: { dismiss() }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { timerTask?.cancel(); spinTask?.cancel() }
    }

    // MARK: - Spinning Body

    private var spinningBody: some View {
        VStack(spacing: 32) {
            Text("GAME \(currentMiniGame + 1)/\(miniGames.count)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(gameMode.accentColor)
                .tracking(3)

            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let colors: [Color] = [.yellow, .orange, .pink, .green, gameMode.accentColor, .purple]
                    Circle()
                        .trim(from: CGFloat(i) / 6.0, to: CGFloat(i + 1) / 6.0)
                        .stroke(colors[i], lineWidth: 48)
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(spinAngle))
                }
                Circle().fill(Theme.cardBackground).frame(width: 60, height: 60)
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.system(size: 24))
                CarnivalSpinFXCanvas()
                    .frame(width: 240, height: 240)
                    .allowsHitTesting(false)
            }
            .animation(.easeOut(duration: 2.0), value: spinAngle)

            Text("SPINNING…").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Playing Body

    private var playingBody: some View {
        let game = miniGames[currentMiniGame]
        let gameWon = miniGameResult?.won ?? false
        let gameLost = miniGameResult.map { !$0.won } ?? false
        return ZStack {
            // Full-screen carnival arena canvas
            CarnivalArenaCanvas(
                tapCount: tapCount,
                timeRemaining: timeRemaining,
                playerScore: playerScore,
                phase: .playing,
                gameIndex: currentMiniGame,
                gameWon: gameWon,
                gameLost: gameLost
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // HUD row
                HStack {
                    Text("SCORE: \(playerScore)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("GAME \(currentMiniGame + 1)/\(miniGames.count)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(gameMode.accentColor)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(timeRemaining > 4 ? gameMode.accentColor : Color.red)
                            .frame(width: geo.size.width * CGFloat(timeRemaining) / CGFloat(game.timeLimit))
                            .animation(.linear(duration: 1), value: timeRemaining)
                    }
                }
                .frame(height: 5)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 16) {
                    CarnivalGameCanvas(game: game, tapCount: tapCount)
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(game.title.uppercased())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(game.color)
                        .tracking(2)
                    Text(game.instruction)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if game.mechanic == .tap {
                        Text("\(tapCount) taps")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(game.color)
                            .contentTransition(.numericText())
                        Text("Target: \(game.target)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.cardBackground.opacity(0.88))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(game.color.opacity(0.2), lineWidth: 1))
                )
                .padding(.horizontal, 24)

                Spacer()

                if showResult, let res = miniGameResult {
                    VStack(spacing: 8) {
                        Text(res.won ? "🏆 +\(res.points) pts" : "✗ Next game…")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(res.won ? .yellow : .red)
                        Text(res.label).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                } else if game.mechanic == .tap {
                    Button {
                        tapCount += 1
                        hapticSoft() // #haptic-tap: soft each tap
                    } label: {
                        Text("TAP!")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(game.color)
                            .clipShape(.rect(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Game Logic (unchanged)

    private func spinWheel() {
        let spinDegrees = Double.random(in: 720...1440)
        spinTask = Task {
            await MainActor.run { spinAngle += spinDegrees }
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run { startMiniGame() }
        }
    }

    private func startMiniGame() {
        let game = miniGames[currentMiniGame]
        phase = .playing
        tapCount = 0
        showResult = false
        miniGameResult = nil
        timeRemaining = game.timeLimit
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeRemaining -= 1 }
            }
            await MainActor.run { evaluateMiniGame() }
        }
    }

    private func evaluateMiniGame() {
        timerTask?.cancel()
        let game = miniGames[currentMiniGame]
        let won: Bool
        let pts: Int
        let label: String
        switch game.mechanic {
        case .tap:
            won = tapCount >= game.target
            pts = won ? 10 : 0
            label = won ? "\(tapCount) taps — target met!" : "\(tapCount)/\(game.target) taps"
        case .auto:
            won = Double.random(in: 0...1) < 0.65
            pts = won ? 10 : 0
            label = won ? "Challenge cleared!" : "Close — keep going"
        }

        // Haptics based on outcome
        if won {
            if pts >= 10 && tapCount > game.target + 5 {
                hapticRigid()   // jackpot / perfect score
            } else {
                hapticHeavy()   // bullseye / regular win
            }
        } else if tapCount > 0 && tapCount >= game.target - 3 {
            hapticSoft()        // near-miss
        } else {
            hapticError()       // miss / game over
        }

        if won { playerScore += pts }
        miniGameResult = MiniGameResult(won: won, points: pts, label: label)
        showResult = true
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run { advanceMiniGame() }
        }
    }

    private func advanceMiniGame() {
        if currentMiniGame + 1 >= miniGames.count {
            // Final result haptic
            if playerScore >= 30 {
                hapticRigid()
            } else {
                hapticMedium()
            }
            GameResultService.saveResult(modeId: "court_carnival", userScore: playerScore)
            phase = .result
        } else {
            currentMiniGame += 1
            phase = .spinning
            spinWheel()
        }
    }
}

// MARK: - CarnivalGame Model

struct CarnivalGame {
    enum Mechanic { case tap, auto }
    let title: String
    let instruction: String
    let icon: String
    let color: Color
    let mechanic: Mechanic
    let timeLimit: Int
    let target: Int

    static let all: [CarnivalGame] = [
        CarnivalGame(title: "Speed Dribble",
                     instruction: "Tap as fast as you can to out-dribble your opponent!",
                     icon: "figure.basketball", color: Color(red: 1, green: 0.6, blue: 0),
                     mechanic: .tap, timeLimit: 8, target: 20),
        CarnivalGame(title: "Sprint Burst",
                     instruction: "Rapid taps — first to 25 reps wins the lane!",
                     icon: "figure.run", color: .green,
                     mechanic: .tap, timeLimit: 10, target: 25),
        CarnivalGame(title: "Jump Timing",
                     instruction: "Nail the timing — the arena is watching!",
                     icon: "arrow.up.circle.fill", color: .cyan,
                     mechanic: .auto, timeLimit: 6, target: 0),
        CarnivalGame(title: "Rally Strike",
                     instruction: "Tap each hit before the ball bounces twice!",
                     icon: "tennis.racket", color: .yellow,
                     mechanic: .tap, timeLimit: 8, target: 18),
        CarnivalGame(title: "Trick Shot",
                     instruction: "The pressure's on — clutch the angle!",
                     icon: "basketball.fill", color: Color(red: 0.95, green: 0.49, blue: 0.15),
                     mechanic: .auto, timeLimit: 5, target: 0),
    ]
}
