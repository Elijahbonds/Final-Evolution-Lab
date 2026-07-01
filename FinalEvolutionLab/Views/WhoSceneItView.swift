import SwiftUI
import UIKit

// MARK: - Scene Canvas

private enum WhoSceneType {
    case basketball, halfpipe, dojo, golf, surf, volleyball, soccer, football, skate, neural

    static func infer(from text: String) -> WhoSceneType {
        if text.contains("court")      { return .basketball }
        if text.contains("halfpipe")   { return .halfpipe }
        if text.contains("Dojo")       { return .dojo }
        if text.contains("Golf") || text.contains("golf") { return .golf }
        if text.contains("ocean") || text.contains("waves") { return .surf }
        if text.contains("volleyball") { return .volleyball }
        if text.contains("pitch") || text.contains("⚽") { return .soccer }
        if text.contains("🏈")         { return .football }
        if text.contains("Skate") || text.contains("skate") { return .skate }
        return .neural
    }
}

private struct WhoSceneCanvas: View {
    let sceneType: WhoSceneType

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width; let H = size.height
                switch sceneType {
                case .basketball: drawBasketball(&ctx, W, H, t)
                case .halfpipe:   drawHalfpipe(&ctx, W, H, t)
                case .dojo:       drawDojo(&ctx, W, H, t)
                case .golf:       drawGolf(&ctx, W, H, t)
                case .surf:       drawSurf(&ctx, W, H, t)
                case .volleyball: drawVolleyball(&ctx, W, H, t)
                case .soccer:     drawSoccer(&ctx, W, H, t)
                case .football:   drawFootball(&ctx, W, H, t)
                case .skate:      drawSkate(&ctx, W, H, t)
                case .neural:     drawNeural(&ctx, W, H, t)
                }
            }
        }
    }

    private func drawBasketball(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H)),
                 with: .color(Color(red:0.9,green:0.35,blue:0.05).opacity(0.55)))
        var ground = Path()
        ground.addRect(CGRect(x: 0, y: H*0.55, width: W, height: H*0.45))
        ctx.fill(ground, with: .color(Color(red:0.05,green:0.12,blue:0.28)))
        var arc = Path()
        arc.addArc(center: CGPoint(x: W*0.5, y: H*0.55), radius: W*0.32,
                   startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        ctx.stroke(arc, with: .color(Color.white.opacity(0.28)), lineWidth: 1.5)
        var lane = Path()
        lane.addRect(CGRect(x: W*0.38, y: H*0.55, width: W*0.24, height: H*0.30))
        ctx.stroke(lane, with: .color(Color.white.opacity(0.18)), lineWidth: 1)
        var pole = Path(); pole.move(to: CGPoint(x: W*0.82, y: H*0.55))
        pole.addLine(to: CGPoint(x: W*0.82, y: H*0.18))
        ctx.stroke(pole, with: .color(Color.white.opacity(0.5)), lineWidth: 2)
        var board = Path()
        board.addRect(CGRect(x: W*0.76, y: H*0.18, width: W*0.12, height: H*0.09))
        ctx.stroke(board, with: .color(Color.white.opacity(0.5)), lineWidth: 1.5)
        var rim = Path()
        rim.addEllipse(in: CGRect(x: W*0.74, y: H*0.30, width: W*0.09, height: H*0.04))
        ctx.stroke(rim, with: .color(Color.orange.opacity(0.9)), lineWidth: 2)
        let sunY = H * CGFloat(0.18 + sin(t * 0.3) * 0.02)
        var sunGC = ctx; sunGC.addFilter(.blur(radius: 9))
        sunGC.fill(Path(ellipseIn: CGRect(x: W*0.12-15, y: sunY-15, width: 30, height: 30)),
                   with: .color(Color.orange.opacity(0.55)))
    }

    private func drawHalfpipe(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H)),
                 with: .color(Color(red:0.22,green:0.48,blue:0.82).opacity(0.45)))
        var snow = Path()
        snow.addRect(CGRect(x: 0, y: H*0.58, width: W, height: H*0.42))
        ctx.fill(snow, with: .color(Color.white.opacity(0.82)))
        var leftWall = Path()
        leftWall.addRect(CGRect(x: W*0.02, y: H*0.08, width: W*0.06, height: H*0.52))
        ctx.fill(leftWall, with: .color(Color.white.opacity(0.62)))
        var rightWall = Path()
        rightWall.addRect(CGRect(x: W*0.92, y: H*0.08, width: W*0.06, height: H*0.52))
        ctx.fill(rightWall, with: .color(Color.white.opacity(0.62)))
        var pipeL = Path()
        pipeL.move(to: CGPoint(x: W*0.06, y: H*0.60))
        pipeL.addQuadCurve(to: CGPoint(x: W*0.30, y: H*0.60),
                           control: CGPoint(x: W*0.18, y: H*1.08))
        ctx.stroke(pipeL, with: .color(Color(red:0.50,green:0.60,blue:0.75)), lineWidth: 3)
        var pipeR = Path()
        pipeR.move(to: CGPoint(x: W*0.70, y: H*0.60))
        pipeR.addQuadCurve(to: CGPoint(x: W*0.94, y: H*0.60),
                           control: CGPoint(x: W*0.82, y: H*1.08))
        ctx.stroke(pipeR, with: .color(Color(red:0.50,green:0.60,blue:0.75)), lineWidth: 3)
        for i in 0..<4 {
            let y = H * CGFloat(0.62 + Double(i) * 0.09)
            var d = Path(); d.move(to: CGPoint(x: W*0.28, y: y))
            d.addLine(to: CGPoint(x: W*0.72, y: y))
            ctx.stroke(d, with: .color(Color(red:0.6,green:0.7,blue:0.85).opacity(0.25)), lineWidth: 1)
        }
    }

    private func drawDojo(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        for i in 0..<6 {
            let y0 = H * CGFloat(i) / 6.0
            ctx.fill(Path(CGRect(x: 0, y: y0, width: W, height: H/6 - 1)),
                     with: .color(Color(red:0.42,green:0.26,blue:0.09).opacity(0.68 - Double(i)*0.05)))
        }
        for i in 0..<20 {
            let x = W * CGFloat(i) / 20.0
            var g = Path(); g.move(to: CGPoint(x: x, y: 0))
            g.addLine(to: CGPoint(x: x + W*0.04, y: H))
            ctx.stroke(g, with: .color(Color(red:0.28,green:0.16,blue:0.04).opacity(0.20)), lineWidth: 0.5)
        }
        let pulse = CGFloat(0.4 + sin(t * 2.5) * 0.3)
        var border = Path()
        border.addRect(CGRect(x: 8, y: 8, width: W-16, height: H-16))
        var neonGC = ctx; neonGC.addFilter(.blur(radius: 5))
        neonGC.stroke(border, with: .color(Color.red.opacity(Double(pulse) * 0.60)), lineWidth: 4)
        ctx.stroke(border, with: .color(Color.red.opacity(Double(pulse) * 0.38)), lineWidth: 1)
        ctx.stroke(Path(ellipseIn: CGRect(x: W/2-18, y: H/2-18, width: 36, height: 36)),
                   with: .color(Color.red.opacity(0.30)), lineWidth: 1.5)
    }

    private func drawGolf(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H*0.52)),
                 with: .color(Color(red:0.60,green:0.85,blue:0.98).opacity(0.45)))
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: H*0.52))
        hill.addCurve(to: CGPoint(x: W, y: H*0.44),
                      control1: CGPoint(x: W*0.30, y: H*0.30),
                      control2: CGPoint(x: W*0.70, y: H*0.60))
        hill.addLine(to: CGPoint(x: W, y: H)); hill.addLine(to: CGPoint(x: 0, y: H))
        ctx.fill(hill, with: .color(Color(red:0.14,green:0.52,blue:0.22).opacity(0.80)))
        let flagY = H * CGFloat(0.40 + sin(t * 1.2) * 0.02)
        var pin = Path(); pin.move(to: CGPoint(x: W*0.65, y: flagY + 32))
        pin.addLine(to: CGPoint(x: W*0.65, y: flagY))
        ctx.stroke(pin, with: .color(Color.white.opacity(0.70)), lineWidth: 1.5)
        var flag = Path()
        flag.addRect(CGRect(x: W*0.65, y: flagY, width: 13, height: 7))
        ctx.fill(flag, with: .color(Color.red.opacity(0.90)))
        ctx.fill(Path(ellipseIn: CGRect(x: W*0.647, y: flagY+30, width: 10, height: 4)),
                 with: .color(Color.black.opacity(0.45)))
    }

    private func drawSurf(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H)),
                 with: .color(Color(red:0.05,green:0.25,blue:0.55).opacity(0.70)))
        for i in 0..<3 {
            let wY = H * CGFloat(0.28 + Double(i) * 0.22)
            let off = CGFloat(sin(t * 0.9 + Double(i) * 1.1)) * 8
            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: wY + off))
            wave.addCurve(to: CGPoint(x: W, y: wY + off),
                          control1: CGPoint(x: W*0.35, y: wY - 20 + off),
                          control2: CGPoint(x: W*0.65, y: wY + 16 + off))
            wave.addLine(to: CGPoint(x: W, y: H)); wave.addLine(to: CGPoint(x: 0, y: H))
            ctx.fill(wave, with: .color(Color(red:0.10,green:0.50,blue:0.90).opacity(0.18 + Double(i)*0.12)))
            var foamGC = ctx; foamGC.addFilter(.blur(radius: 2))
            foamGC.stroke(wave, with: .color(Color.white.opacity(0.22)), lineWidth: 2)
        }
    }

    private func drawVolleyball(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H*0.48)),
                 with: .color(Color(red:0.55,green:0.80,blue:0.98).opacity(0.48)))
        var sand = Path()
        sand.addRect(CGRect(x: 0, y: H*0.48, width: W, height: H*0.52))
        ctx.fill(sand, with: .color(Color(red:0.88,green:0.76,blue:0.48).opacity(0.80)))
        for i in 0..<5 {
            let y = H * CGFloat(0.50 + Double(i) * 0.09)
            var g = Path(); g.move(to: CGPoint(x: 0, y: y))
            g.addLine(to: CGPoint(x: W, y: y + CGFloat(i)*0.4))
            ctx.stroke(g, with: .color(Color(red:0.70,green:0.58,blue:0.35).opacity(0.18)), lineWidth: 0.5)
        }
        var lp = Path(); lp.move(to: CGPoint(x: W*0.32, y: H*0.08))
        lp.addLine(to: CGPoint(x: W*0.32, y: H*0.50))
        ctx.stroke(lp, with: .color(Color.gray.opacity(0.55)), lineWidth: 2.5)
        var rp = Path(); rp.move(to: CGPoint(x: W*0.68, y: H*0.08))
        rp.addLine(to: CGPoint(x: W*0.68, y: H*0.50))
        ctx.stroke(rp, with: .color(Color.gray.opacity(0.55)), lineWidth: 2.5)
        var net = Path(); net.move(to: CGPoint(x: W*0.32, y: H*0.28))
        net.addLine(to: CGPoint(x: W*0.68, y: H*0.28))
        ctx.stroke(net, with: .color(Color.white.opacity(0.70)), lineWidth: 2)
        for i in 1...5 {
            let x = W * (0.32 + CGFloat(i) * 0.06)
            var v = Path(); v.move(to: CGPoint(x: x, y: H*0.08))
            v.addLine(to: CGPoint(x: x, y: H*0.50))
            ctx.stroke(v, with: .color(Color.white.opacity(0.18)), lineWidth: 0.5)
        }
    }

    private func drawSoccer(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H)),
                 with: .color(Color(red:0.05,green:0.22,blue:0.08)))
        for i in 0..<5 {
            ctx.fill(Path(CGRect(x: W * CGFloat(i) * 0.2, y: 0, width: W*0.10, height: H)),
                     with: .color(Color(red:0.08,green:0.28,blue:0.10).opacity(0.50)))
        }
        var cl = Path(); cl.move(to: CGPoint(x: W/2, y: 0))
        cl.addLine(to: CGPoint(x: W/2, y: H))
        ctx.stroke(cl, with: .color(Color.white.opacity(0.22)), lineWidth: 1)
        let pulse = CGFloat(0.6 + sin(t * 1.5) * 0.10)
        ctx.stroke(Path(ellipseIn: CGRect(x: W/2-22, y: H/2-22, width: 44, height: 44)),
                   with: .color(Color.white.opacity(Double(pulse)*0.22)), lineWidth: 1.5)
        ctx.fill(Path(ellipseIn: CGRect(x: W/2-3, y: H/2-3, width: 6, height: 6)),
                 with: .color(Color.white.opacity(0.28)))
        ctx.stroke(Path(CGRect(x: W*0.35, y: H*0.70, width: W*0.30, height: H*0.30)),
                   with: .color(Color.white.opacity(0.18)), lineWidth: 1)
    }

    private func drawFootball(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H)),
                 with: .color(Color(red:0.08,green:0.26,blue:0.08)))
        for i in 0..<10 {
            let x = W * CGFloat(i) / 10.0
            ctx.fill(Path(CGRect(x: x, y: 0, width: W*0.05, height: H)),
                     with: .color(Color(red:0.10,green:0.32,blue:0.10).opacity(0.55)))
            var yl = Path(); yl.move(to: CGPoint(x: x, y: 0))
            yl.addLine(to: CGPoint(x: x, y: H))
            ctx.stroke(yl, with: .color(Color.white.opacity(0.16)), lineWidth: 1)
            let hx = x + W*0.05
            var h = Path()
            h.move(to: CGPoint(x: hx, y: H*0.36)); h.addLine(to: CGPoint(x: hx+8, y: H*0.36))
            h.move(to: CGPoint(x: hx, y: H*0.64)); h.addLine(to: CGPoint(x: hx+8, y: H*0.64))
            ctx.stroke(h, with: .color(Color.white.opacity(0.18)), lineWidth: 1)
        }
        let gY = H * 0.20
        var post = Path()
        post.move(to: CGPoint(x: W*0.92, y: gY+32)); post.addLine(to: CGPoint(x: W*0.92, y: gY))
        post.move(to: CGPoint(x: W*0.82, y: gY+9)); post.addLine(to: CGPoint(x: W*1.00, y: gY+9))
        ctx.stroke(post, with: .color(Color.yellow.opacity(0.58)), lineWidth: 2)
    }

    private func drawSkate(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width: W, height: H)),
                 with: .color(Color(red:0.28,green:0.28,blue:0.30)))
        for i in 0..<9 {
            let y = H * CGFloat(i) / 9.0
            var l = Path(); l.move(to: CGPoint(x: 0, y: y)); l.addLine(to: CGPoint(x: W, y: y))
            ctx.stroke(l, with: .color(Color.black.opacity(0.14)), lineWidth: 0.5)
        }
        let gY = H * 0.68
        var ramp = Path(); ramp.move(to: CGPoint(x: W*0.68, y: gY))
        ramp.addQuadCurve(to: CGPoint(x: W*0.96, y: H*0.14), control: CGPoint(x: W*0.96, y: gY))
        ctx.stroke(ramp, with: .color(Color(red:0.38,green:0.38,blue:0.40)), lineWidth: 3)
        ctx.fill(Path(ellipseIn: CGRect(x: W*0.94, y: H*0.12, width: 8, height: 8)),
                 with: .color(Color.gray.opacity(0.70)))
        ctx.fill(Path(CGRect(x: W*0.08, y: gY-22, width: W*0.34, height: 22)),
                 with: .color(Color(red:0.20,green:0.20,blue:0.22)))
        ctx.fill(Path(CGRect(x: W*0.08, y: gY-4, width: W*0.34, height: 4)),
                 with: .color(Color.orange.opacity(0.50)))
        var rail = Path()
        rail.move(to: CGPoint(x: W*0.12, y: gY-16))
        rail.addLine(to: CGPoint(x: W*0.56, y: gY-28))
        ctx.stroke(rail, with: .color(Color.gray.opacity(0.68)), lineWidth: 3)
        var gl = Path(); gl.move(to: CGPoint(x: 0, y: gY)); gl.addLine(to: CGPoint(x: W, y: gY))
        ctx.stroke(gl, with: .color(Color.black.opacity(0.30)), lineWidth: 1)
    }

    private func drawNeural(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        let nx: [CGFloat] = [0.15,0.75,0.45,0.25,0.65,0.85,0.10,0.55]
        let ny: [CGFloat] = [0.20,0.15,0.50,0.70,0.75,0.55,0.85,0.35]
        let ph: [Double]  = [0,0.8,1.5,0.4,2.1,1.0,1.8,0.3]
        let edges: [(Int,Int)] = [(0,2),(2,1),(2,4),(3,5),(1,5),(0,6),(3,7),(4,7)]
        let acc = Color(red:0.60,green:0.20,blue:0.95)
        var pos = [CGPoint](repeating:.zero, count:8)
        for i in 0..<8 {
            pos[i] = CGPoint(x: nx[i]*W + CGFloat(sin(t*0.8+ph[i]))*W*0.015,
                             y: ny[i]*H + CGFloat(cos(t*0.6+ph[i]))*H*0.015)
        }
        for (a,b) in edges {
            var e = Path(); e.move(to: pos[a]); e.addLine(to: pos[b])
            ctx.stroke(e, with: .color(acc.opacity(0.08)), lineWidth: 1)
        }
        for i in 0..<8 {
            let pulse = CGFloat(0.5 + sin(t + ph[i]) * 0.5)
            let r = 2.5 + pulse * 3
            var gc = ctx; gc.addFilter(.blur(radius: 5))
            gc.fill(Path(ellipseIn: CGRect(x:pos[i].x-r*2,y:pos[i].y-r*2,width:r*4,height:r*4)),
                    with: .color(acc.opacity(Double(pulse)*0.18)))
            ctx.fill(Path(ellipseIn: CGRect(x:pos[i].x-r*0.6,y:pos[i].y-r*0.6,width:r*1.2,height:r*1.2)),
                     with: .color(acc.opacity(Double(pulse)*0.50)))
        }
    }
}

// MARK: - Game Show Stage Canvas

private struct GameShowStageCanvas: View {
    let timeRemaining: Int
    let totalTime: Int
    let playerScore: Int
    let opponentScore: Int
    let showCorrect: Bool
    let showWrong: Bool
    let currentRound: Int
    let totalRounds: Int
    let streakCount: Int

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width
                let H = size.height

                // ============================================================
                // SCENE 1: GAME SHOW STAGE BACKGROUND  (#1 – #12)
                // ============================================================

                // #1 Deep purple stage gradient fill
                var stageBg = Path()
                stageBg.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                ctx.fill(stageBg, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.10, green: 0.02, blue: 0.22),
                        Color(red: 0.18, green: 0.04, blue: 0.35),
                        Color(red: 0.06, green: 0.02, blue: 0.14)
                    ]),
                    startPoint: CGPoint(x: W/2, y: 0),
                    endPoint: CGPoint(x: W/2, y: H)
                ))

                // #2 Star field backdrop (20 stars)
                for i in 0..<20 {
                    let fi = Double(i)
                    let seed = fi * 137.5
                    let sx = CGFloat(fmod(seed * 0.618, 1.0)) * W
                    let sy = CGFloat(fmod(seed * 0.382, 1.0)) * H * 0.7
                    let twinkle = CGFloat(0.3 + sin(t * 1.5 + fi * 0.9) * 0.25)
                    var starDot = Path()
                    starDot.addEllipse(in: CGRect(x: sx - 1.5, y: sy - 1.5, width: 3, height: 3))
                    ctx.fill(starDot, with: .color(Color.white.opacity(Double(twinkle))))
                }

                // #3 Spotlight beam 1 (top-left cone)
                var spot1 = Path()
                spot1.move(to: CGPoint(x: W * 0.15, y: 0))
                spot1.addLine(to: CGPoint(x: W * 0.02, y: H * 0.55))
                spot1.addLine(to: CGPoint(x: W * 0.28, y: H * 0.55))
                spot1.closeSubpath()
                var spot1GC = ctx; spot1GC.addFilter(.blur(radius: 10))
                spot1GC.fill(spot1, with: .color(Color(red: 1.0, green: 0.95, blue: 0.7).opacity(0.08 + sin(t * 0.7) * 0.03)))

                // #4 Spotlight beam 2 (top-right cone)
                var spot2 = Path()
                spot2.move(to: CGPoint(x: W * 0.85, y: 0))
                spot2.addLine(to: CGPoint(x: W * 0.72, y: H * 0.55))
                spot2.addLine(to: CGPoint(x: W * 0.98, y: H * 0.55))
                spot2.closeSubpath()
                var spot2GC = ctx; spot2GC.addFilter(.blur(radius: 10))
                spot2GC.fill(spot2, with: .color(Color(red: 1.0, green: 0.95, blue: 0.7).opacity(0.08 + sin(t * 0.9 + 1.2) * 0.03)))

                // #5 Spotlight beam 3 (top-center-left)
                var spot3 = Path()
                spot3.move(to: CGPoint(x: W * 0.38, y: 0))
                spot3.addLine(to: CGPoint(x: W * 0.28, y: H * 0.55))
                spot3.addLine(to: CGPoint(x: W * 0.48, y: H * 0.55))
                spot3.closeSubpath()
                var spot3GC = ctx; spot3GC.addFilter(.blur(radius: 8))
                spot3GC.fill(spot3, with: .color(Color.cyan.opacity(0.06 + sin(t * 0.5) * 0.02)))

                // #6 Spotlight beam 4 (top-center-right)
                var spot4 = Path()
                spot4.move(to: CGPoint(x: W * 0.62, y: 0))
                spot4.addLine(to: CGPoint(x: W * 0.52, y: H * 0.55))
                spot4.addLine(to: CGPoint(x: W * 0.72, y: H * 0.55))
                spot4.closeSubpath()
                var spot4GC = ctx; spot4GC.addFilter(.blur(radius: 8))
                spot4GC.fill(spot4, with: .color(Color.cyan.opacity(0.06 + sin(t * 0.6 + 0.8) * 0.02)))

                // #7 Neon sign arch at top (glowing arc)
                var archPath = Path()
                archPath.addArc(center: CGPoint(x: W/2, y: H * 0.02),
                                radius: W * 0.42,
                                startAngle: .degrees(10),
                                endAngle: .degrees(170),
                                clockwise: false)
                let archPulse = 0.7 + sin(t * 1.8) * 0.3
                var archGC = ctx; archGC.addFilter(.blur(radius: 5))
                archGC.stroke(archPath, with: .color(Color(red: 1.0, green: 0.2, blue: 0.8).opacity(archPulse * 0.6)), lineWidth: 6)
                ctx.stroke(archPath, with: .color(Color(red: 1.0, green: 0.4, blue: 0.9).opacity(archPulse * 0.9)), lineWidth: 2)

                // #8 Neon sign arch secondary glow
                var archPath2 = Path()
                archPath2.addArc(center: CGPoint(x: W/2, y: H * 0.02),
                                 radius: W * 0.40,
                                 startAngle: .degrees(12),
                                 endAngle: .degrees(168),
                                 clockwise: false)
                ctx.stroke(archPath2, with: .color(Color.white.opacity(archPulse * 0.15)), lineWidth: 1)

                // #9 Stage floor base rect
                var floorRect = Path()
                floorRect.addRect(CGRect(x: 0, y: H * 0.62, width: W, height: H * 0.38))
                ctx.fill(floorRect, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.14, green: 0.06, blue: 0.28),
                        Color(red: 0.08, green: 0.03, blue: 0.16)
                    ]),
                    startPoint: CGPoint(x: W/2, y: H * 0.62),
                    endPoint: CGPoint(x: W/2, y: H)
                ))

                // #10 Stage floor reflection highlight
                var floorHighlight = Path()
                floorHighlight.addRect(CGRect(x: 0, y: H * 0.62, width: W, height: 2))
                ctx.fill(floorHighlight, with: .color(Color(red: 0.8, green: 0.4, blue: 1.0).opacity(0.5)))

                // #11 Left curtain drape silhouette
                var curtainL = Path()
                curtainL.move(to: CGPoint(x: 0, y: 0))
                curtainL.addLine(to: CGPoint(x: W * 0.12, y: 0))
                curtainL.addCurve(to: CGPoint(x: W * 0.08, y: H * 0.62),
                                  control1: CGPoint(x: W * 0.18, y: H * 0.3),
                                  control2: CGPoint(x: W * 0.06, y: H * 0.48))
                curtainL.addLine(to: CGPoint(x: 0, y: H * 0.62))
                curtainL.closeSubpath()
                ctx.fill(curtainL, with: .color(Color(red: 0.55, green: 0.05, blue: 0.12).opacity(0.85)))

                // #12 Right curtain drape silhouette
                var curtainR = Path()
                curtainR.move(to: CGPoint(x: W, y: 0))
                curtainR.addLine(to: CGPoint(x: W * 0.88, y: 0))
                curtainR.addCurve(to: CGPoint(x: W * 0.92, y: H * 0.62),
                                  control1: CGPoint(x: W * 0.82, y: H * 0.3),
                                  control2: CGPoint(x: W * 0.94, y: H * 0.48))
                curtainR.addLine(to: CGPoint(x: W, y: H * 0.62))
                curtainR.closeSubpath()
                ctx.fill(curtainR, with: .color(Color(red: 0.55, green: 0.05, blue: 0.12).opacity(0.85)))

                // ============================================================
                // SCENE 2: PODIUM AREA  (#13 – #24)
                // ============================================================

                // #13 Left contestant podium rectangle
                var podiumL = Path()
                podiumL.addRect(CGRect(x: W * 0.06, y: H * 0.55, width: W * 0.22, height: H * 0.12))
                ctx.fill(podiumL, with: .color(Color(red: 0.18, green: 0.08, blue: 0.38)))

                // #14 Left podium neon trim (glow)
                var podiumLTrim = Path()
                podiumLTrim.addRect(CGRect(x: W * 0.06, y: H * 0.55, width: W * 0.22, height: H * 0.12))
                var podiumLGC = ctx; podiumLGC.addFilter(.blur(radius: 4))
                podiumLGC.stroke(podiumLTrim, with: .color(Color.cyan.opacity(0.7)), lineWidth: 3)
                ctx.stroke(podiumLTrim, with: .color(Color.cyan.opacity(0.9)), lineWidth: 1.2)

                // #15 Right contestant podium rectangle
                var podiumR = Path()
                podiumR.addRect(CGRect(x: W * 0.72, y: H * 0.55, width: W * 0.22, height: H * 0.12))
                ctx.fill(podiumR, with: .color(Color(red: 0.18, green: 0.08, blue: 0.38)))

                // #16 Right podium neon trim
                var podiumRTrim = Path()
                podiumRTrim.addRect(CGRect(x: W * 0.72, y: H * 0.55, width: W * 0.22, height: H * 0.12))
                var podiumRGC = ctx; podiumRGC.addFilter(.blur(radius: 4))
                podiumRGC.stroke(podiumRTrim, with: .color(Color.orange.opacity(0.7)), lineWidth: 3)
                ctx.stroke(podiumRTrim, with: .color(Color.orange.opacity(0.9)), lineWidth: 1.2)

                // #17 Left buzzer button glow (red circle on podium)
                let buzzerPulse = 0.6 + sin(t * 2.2) * 0.4
                var buzzerL = Path()
                buzzerL.addEllipse(in: CGRect(x: W * 0.155, y: H * 0.578, width: 18, height: 18))
                var buzzerLGC = ctx; buzzerLGC.addFilter(.blur(radius: 6))
                buzzerLGC.fill(buzzerL, with: .color(Color.red.opacity(buzzerPulse * 0.7)))
                ctx.fill(buzzerL, with: .color(Color.red.opacity(0.9)))

                // #18 Right buzzer button glow
                var buzzerR = Path()
                buzzerR.addEllipse(in: CGRect(x: W * 0.825, y: H * 0.578, width: 18, height: 18))
                var buzzerRGC = ctx; buzzerRGC.addFilter(.blur(radius: 6))
                buzzerRGC.fill(buzzerR, with: .color(Color.red.opacity(buzzerPulse * 0.7)))
                ctx.fill(buzzerR, with: .color(Color.red.opacity(0.9)))

                // #19 Score display on left podium face
                ctx.draw(
                    Text("\(playerScore)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.cyan),
                    at: CGPoint(x: W * 0.17, y: H * 0.595)
                )

                // #20 Score display on right podium face
                ctx.draw(
                    Text("\(opponentScore)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.orange),
                    at: CGPoint(x: W * 0.83, y: H * 0.595)
                )

                // #21 Host podium (center, taller)
                var hostPodium = Path()
                hostPodium.addRect(CGRect(x: W * 0.38, y: H * 0.50, width: W * 0.24, height: H * 0.17))
                ctx.fill(hostPodium, with: .color(Color(red: 0.22, green: 0.10, blue: 0.42)))
                var hostGC = ctx; hostGC.addFilter(.blur(radius: 5))
                hostGC.stroke(hostPodium, with: .color(Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.8)), lineWidth: 4)
                ctx.stroke(hostPodium, with: .color(Color(red: 1.0, green: 0.9, blue: 0.3).opacity(0.9)), lineWidth: 1.5)

                // #22 Microphone silhouette on host podium
                var micHead = Path()
                micHead.addEllipse(in: CGRect(x: W * 0.490, y: H * 0.510, width: 10, height: 14))
                ctx.fill(micHead, with: .color(Color.white.opacity(0.7)))
                var micStand = Path()
                micStand.move(to: CGPoint(x: W * 0.495, y: H * 0.524))
                micStand.addLine(to: CGPoint(x: W * 0.495, y: H * 0.540))
                micStand.move(to: CGPoint(x: W * 0.486, y: H * 0.540))
                micStand.addLine(to: CGPoint(x: W * 0.504, y: H * 0.540))
                ctx.stroke(micStand, with: .color(Color.white.opacity(0.6)), lineWidth: 1.5)

                // #23 Question board behind host (rect)
                var qBoard = Path()
                qBoard.addRoundedRect(
                    in: CGRect(x: W * 0.30, y: H * 0.12, width: W * 0.40, height: H * 0.22),
                    cornerSize: CGSize(width: 6, height: 6)
                )
                ctx.fill(qBoard, with: .color(Color(red: 0.08, green: 0.04, blue: 0.20)))
                var qBoardGC = ctx; qBoardGC.addFilter(.blur(radius: 3))
                qBoardGC.stroke(qBoard, with: .color(Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.8)), lineWidth: 3)
                ctx.stroke(qBoard, with: .color(Color(red: 0.7, green: 0.3, blue: 1.0).opacity(0.9)), lineWidth: 1)

                // #24 Question board inner lines (hint rows)
                for row in 0..<3 {
                    let ry = H * (0.16 + Double(row) * 0.055)
                    var rowLine = Path()
                    rowLine.addRect(CGRect(x: W * 0.34, y: ry, width: W * 0.32, height: 4))
                    ctx.fill(rowLine, with: .color(Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.35)))
                }

                // ============================================================
                // SCENE 3: QUESTION REVEAL  (#25 – #38)
                // ============================================================

                // #25 Film strip border left edge (sprocket holes)
                var filmStripL = Path()
                filmStripL.addRect(CGRect(x: W * 0.12, y: H * 0.24, width: 12, height: H * 0.26))
                ctx.fill(filmStripL, with: .color(Color.black.opacity(0.6)))
                for hole in 0..<6 {
                    var holeP = Path()
                    holeP.addRoundedRect(
                        in: CGRect(x: W * 0.122, y: H * 0.254 + CGFloat(hole) * (H * 0.26 / 6.5), width: 8, height: 6),
                        cornerSize: CGSize(width: 2, height: 2)
                    )
                    ctx.fill(holeP, with: .color(Color(red: 0.3, green: 0.3, blue: 0.35)))
                }

                // #26 Film strip border right edge (sprocket holes)
                var filmStripR = Path()
                filmStripR.addRect(CGRect(x: W * 0.868, y: H * 0.24, width: 12, height: H * 0.26))
                ctx.fill(filmStripR, with: .color(Color.black.opacity(0.6)))
                for hole in 0..<6 {
                    var holeP = Path()
                    holeP.addRoundedRect(
                        in: CGRect(x: W * 0.870, y: H * 0.254 + CGFloat(hole) * (H * 0.26 / 6.5), width: 8, height: 6),
                        cornerSize: CGSize(width: 2, height: 2)
                    )
                    ctx.fill(holeP, with: .color(Color(red: 0.3, green: 0.3, blue: 0.35)))
                }

                // #27 Clue image placeholder rect
                var cluePlaceholder = Path()
                cluePlaceholder.addRoundedRect(
                    in: CGRect(x: W * 0.15, y: H * 0.245, width: W * 0.70, height: H * 0.245),
                    cornerSize: CGSize(width: 8, height: 8)
                )
                ctx.fill(cluePlaceholder, with: .color(Color(red: 0.05, green: 0.03, blue: 0.12).opacity(0.85)))
                ctx.stroke(cluePlaceholder, with: .color(Color(red: 0.5, green: 0.2, blue: 0.9).opacity(0.4)), lineWidth: 1)

                // #28 Scan-line effect on clue area (every 4px horizontal line)
                for scanLine in stride(from: 0, through: Int(H * 0.245), by: 4) {
                    var sl = Path()
                    sl.addRect(CGRect(x: W * 0.15, y: H * 0.245 + CGFloat(scanLine), width: W * 0.70, height: 1))
                    ctx.fill(sl, with: .color(Color.black.opacity(0.12)))
                }

                // #29 Reveal animation — descending white line uncovering answer
                let revealY = H * 0.245 + H * 0.245 * CGFloat(fmod(t * 0.18, 1.0))
                var revealLine = Path()
                revealLine.addRect(CGRect(x: W * 0.15, y: revealY, width: W * 0.70, height: 1.5))
                var revealGC = ctx; revealGC.addFilter(.blur(radius: 3))
                revealGC.fill(revealLine, with: .color(Color.white.opacity(0.6)))
                ctx.fill(revealLine, with: .color(Color.white.opacity(0.5)))

                // #30 Category badge background
                var categoryBadge = Path()
                categoryBadge.addRoundedRect(
                    in: CGRect(x: W * 0.28, y: H * 0.248, width: W * 0.22, height: 18),
                    cornerSize: CGSize(width: 9, height: 9)
                )
                ctx.fill(categoryBadge, with: .color(Color(red: 0.7, green: 0.1, blue: 0.4)))

                // #31 Category badge glow
                var categoryGC = ctx; categoryGC.addFilter(.blur(radius: 4))
                categoryGC.fill(categoryBadge, with: .color(Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.5)))

                // #32 Category label text
                ctx.draw(
                    Text("SPORTS")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white),
                    at: CGPoint(x: W * 0.39, y: H * 0.257)
                )

                // #33 Point value badge background
                var pointsBadge = Path()
                pointsBadge.addRoundedRect(
                    in: CGRect(x: W * 0.52, y: H * 0.248, width: W * 0.20, height: 18),
                    cornerSize: CGSize(width: 9, height: 9)
                )
                ctx.fill(pointsBadge, with: .color(Color(red: 0.1, green: 0.4, blue: 0.7)))

                // #34 Point value glow
                var pointsGC = ctx; pointsGC.addFilter(.blur(radius: 4))
                pointsGC.fill(pointsBadge, with: .color(Color.cyan.opacity(0.5)))

                // #35 Points value label
                ctx.draw(
                    Text("10 PTS")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white),
                    at: CGPoint(x: W * 0.62, y: H * 0.257)
                )

                // #36 Film strip top border line
                var filmTop = Path()
                filmTop.addRect(CGRect(x: W * 0.12, y: H * 0.240, width: W * 0.76, height: 3))
                ctx.fill(filmTop, with: .color(Color.black.opacity(0.7)))

                // #37 Film strip bottom border line
                var filmBot = Path()
                filmBot.addRect(CGRect(x: W * 0.12, y: H * 0.487, width: W * 0.76, height: 3))
                ctx.fill(filmBot, with: .color(Color.black.opacity(0.7)))

                // #38 Inner clue frame glow border
                var innerClue = Path()
                innerClue.addRoundedRect(
                    in: CGRect(x: W * 0.17, y: H * 0.258, width: W * 0.66, height: H * 0.22),
                    cornerSize: CGSize(width: 5, height: 5)
                )
                var innerGC = ctx; innerGC.addFilter(.blur(radius: 2))
                innerGC.stroke(innerClue, with: .color(Color(red: 0.8, green: 0.4, blue: 1.0).opacity(0.3)), lineWidth: 2)

                // ============================================================
                // SCENE 4: AUDIENCE  (#39 – #50)
                // ============================================================

                // #39 Audience section background
                var audienceBg = Path()
                audienceBg.addRect(CGRect(x: 0, y: H * 0.62, width: W, height: H * 0.15))
                ctx.fill(audienceBg, with: .color(Color(red: 0.06, green: 0.02, blue: 0.14).opacity(0.9)))

                // #40 Row 1 audience silhouettes (back row, 8 people)
                for i in 0..<8 {
                    let ax = W * (0.05 + CGFloat(i) * 0.125)
                    let ay = H * 0.625
                    var head = Path()
                    head.addEllipse(in: CGRect(x: ax - 4, y: ay - 10, width: 8, height: 8))
                    var body1 = Path()
                    body1.addRect(CGRect(x: ax - 5, y: ay - 2, width: 10, height: 10))
                    let rowColors: [Color] = [.cyan, .purple, .orange, .pink, .yellow, .green, .white, .red]
                    ctx.fill(head, with: .color(rowColors[i % rowColors.count].opacity(0.45)))
                    ctx.fill(body1, with: .color(rowColors[i % rowColors.count].opacity(0.3)))
                }

                // #41 Row 2 audience silhouettes (mid row, 9 people)
                for i in 0..<9 {
                    let ax = W * (0.02 + CGFloat(i) * 0.115)
                    let ay = H * 0.645
                    var head = Path()
                    head.addEllipse(in: CGRect(x: ax - 4, y: ay - 10, width: 8, height: 8))
                    var body2 = Path()
                    body2.addRect(CGRect(x: ax - 5, y: ay - 2, width: 10, height: 10))
                    let rowColors: [Color] = [.orange, .white, .cyan, .yellow, .purple, .pink, .green, .red, .blue]
                    ctx.fill(head, with: .color(rowColors[i % rowColors.count].opacity(0.45)))
                    ctx.fill(body2, with: .color(rowColors[i % rowColors.count].opacity(0.3)))
                }

                // #42 Row 3 audience silhouettes (front row, 8 people)
                for i in 0..<8 {
                    let ax = W * (0.06 + CGFloat(i) * 0.125)
                    let ay = H * 0.665
                    var head = Path()
                    head.addEllipse(in: CGRect(x: ax - 4, y: ay - 10, width: 8, height: 8))
                    var body3 = Path()
                    body3.addRect(CGRect(x: ax - 5, y: ay - 2, width: 10, height: 10))
                    let rowColors: [Color] = [.yellow, .green, .pink, .cyan, .orange, .white, .purple, .red]
                    ctx.fill(head, with: .color(rowColors[i % rowColors.count].opacity(0.50)))
                    ctx.fill(body3, with: .color(rowColors[i % rowColors.count].opacity(0.35)))
                }

                // #43 Applause wave animation — arms raised in rolling sequence
                for i in 0..<8 {
                    let fi = Double(i)
                    let ax = W * (0.05 + CGFloat(i) * 0.125)
                    let ay = H * 0.625
                    let wavePhase = sin(t * 3.0 + fi * 0.7)
                    let armRaise = CGFloat(max(0, wavePhase)) * 8
                    var armL = Path()
                    armL.move(to: CGPoint(x: ax - 4, y: ay - 4))
                    armL.addLine(to: CGPoint(x: ax - 9, y: ay - 4 - armRaise))
                    var armR = Path()
                    armR.move(to: CGPoint(x: ax + 4, y: ay - 4))
                    armR.addLine(to: CGPoint(x: ax + 9, y: ay - 4 - armRaise))
                    ctx.stroke(armL, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
                    ctx.stroke(armR, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
                }

                // #44 Camera flash dots (8 white pops)
                for i in 0..<8 {
                    let fi = Double(i)
                    let flashSeed = fi * 73.1
                    let fx = CGFloat(fmod(flashSeed * 0.73, 1.0)) * W
                    let fy = H * 0.625 + CGFloat(fmod(flashSeed * 0.29, 1.0)) * H * 0.04
                    let flashPhase = fmod(t * 2.5 + fi * 0.8, 3.0)
                    let flashAlpha = flashPhase < 0.3 ? flashPhase / 0.3 : max(0, 1.0 - (flashPhase - 0.3) / 0.5)
                    if flashAlpha > 0.05 {
                        var flash = Path()
                        flash.addEllipse(in: CGRect(x: fx - 3, y: fy - 3, width: 6, height: 6))
                        var flashGC = ctx; flashGC.addFilter(.blur(radius: 5))
                        flashGC.fill(flash, with: .color(Color.white.opacity(flashAlpha * 0.8)))
                        ctx.fill(flash, with: .color(Color.white.opacity(flashAlpha)))
                    }
                }

                // #45 Production crew silhouette left side
                var crewBodyL = Path()
                crewBodyL.move(to: CGPoint(x: W * 0.04, y: H * 0.62))
                crewBodyL.addLine(to: CGPoint(x: W * 0.04, y: H * 0.52))
                crewBodyL.addLine(to: CGPoint(x: W * 0.07, y: H * 0.52))
                crewBodyL.addLine(to: CGPoint(x: W * 0.07, y: H * 0.62))
                ctx.fill(crewBodyL, with: .color(Color.black.opacity(0.7)))
                var crewHeadL = Path()
                crewHeadL.addEllipse(in: CGRect(x: W * 0.033, y: H * 0.50, width: 10, height: 10))
                ctx.fill(crewHeadL, with: .color(Color.black.opacity(0.7)))

                // #46 Production crew camera on tripod (left)
                var camBody = Path()
                camBody.addRect(CGRect(x: W * 0.01, y: H * 0.535, width: 14, height: 9))
                ctx.fill(camBody, with: .color(Color(red: 0.2, green: 0.2, blue: 0.25).opacity(0.8)))
                var camLens = Path()
                camLens.addEllipse(in: CGRect(x: W * 0.008, y: H * 0.538, width: 6, height: 6))
                ctx.fill(camLens, with: .color(Color(red: 0.1, green: 0.3, blue: 0.5).opacity(0.9)))

                // #47 Production crew silhouette right side
                var crewBodyR = Path()
                crewBodyR.move(to: CGPoint(x: W * 0.93, y: H * 0.62))
                crewBodyR.addLine(to: CGPoint(x: W * 0.93, y: H * 0.52))
                crewBodyR.addLine(to: CGPoint(x: W * 0.96, y: H * 0.52))
                crewBodyR.addLine(to: CGPoint(x: W * 0.96, y: H * 0.62))
                ctx.fill(crewBodyR, with: .color(Color.black.opacity(0.7)))
                var crewHeadR = Path()
                crewHeadR.addEllipse(in: CGRect(x: W * 0.935, y: H * 0.50, width: 10, height: 10))
                ctx.fill(crewHeadR, with: .color(Color.black.opacity(0.7)))

                // #48 Audience glow overlay strip
                var audienceGlow = Path()
                audienceGlow.addRect(CGRect(x: 0, y: H * 0.610, width: W, height: 6))
                var audienceGlowGC = ctx; audienceGlowGC.addFilter(.blur(radius: 4))
                audienceGlowGC.fill(audienceGlow, with: .color(Color(red: 0.8, green: 0.3, blue: 1.0).opacity(0.4)))

                // #49 Audience excitement dots (random pops above crowd)
                for i in 0..<5 {
                    let fi = Double(i)
                    let popX = W * CGFloat(0.1 + fi * 0.2)
                    let popPhase = fmod(t * 1.8 + fi * 1.1, 2.5)
                    let popY = H * 0.61 - CGFloat(max(0, 1.0 - popPhase / 1.2)) * 12
                    let popAlpha = popPhase < 1.2 ? (1.0 - popPhase / 1.2) : 0
                    if popAlpha > 0.05 {
                        var excite = Path()
                        excite.addEllipse(in: CGRect(x: popX - 3, y: popY - 3, width: 6, height: 6))
                        ctx.fill(excite, with: .color(Color.yellow.opacity(popAlpha * 0.8)))
                    }
                }

                // #50 Stage divider line between audience and stage
                var stageDivider = Path()
                stageDivider.addRect(CGRect(x: 0, y: H * 0.618, width: W, height: 2))
                var dividerGC = ctx; dividerGC.addFilter(.blur(radius: 3))
                dividerGC.fill(stageDivider, with: .color(Color(red: 1.0, green: 0.5, blue: 0.8).opacity(0.6)))
                ctx.fill(stageDivider, with: .color(Color(red: 1.0, green: 0.7, blue: 0.9).opacity(0.5)))

                // ============================================================
                // SCENE 5: ANSWER FX  (#51 – #66)
                // ============================================================

                // #51 Correct answer burst — 12-ray green star (visible only on correct)
                if showCorrect {
                    let burstCX = W * 0.5
                    let burstCY = H * 0.5
                    for ray in 0..<12 {
                        let angle = Double(ray) * (.pi * 2 / 12)
                        let rLen: CGFloat = ray % 2 == 0 ? 28 : 16
                        var rayP = Path()
                        rayP.move(to: CGPoint(x: burstCX, y: burstCY))
                        rayP.addLine(to: CGPoint(x: burstCX + CGFloat(cos(angle)) * rLen,
                                                 y: burstCY + CGFloat(sin(angle)) * rLen))
                        var rayGC = ctx; rayGC.addFilter(.blur(radius: 3))
                        rayGC.stroke(rayP, with: .color(Color.green.opacity(0.7)), lineWidth: 3)
                        ctx.stroke(rayP, with: .color(Color.green.opacity(0.9)), lineWidth: 1.5)
                    }
                }

                // #52 Correct answer center circle glow
                if showCorrect {
                    var correctCircle = Path()
                    correctCircle.addEllipse(in: CGRect(x: W * 0.5 - 18, y: H * 0.5 - 18, width: 36, height: 36))
                    var correctGC = ctx; correctGC.addFilter(.blur(radius: 10))
                    correctGC.fill(correctCircle, with: .color(Color.green.opacity(0.7)))
                    ctx.fill(correctCircle, with: .color(Color.green.opacity(0.35)))
                }

                // #53 Wrong answer — red X left stroke
                if showWrong {
                    var xLeft = Path()
                    xLeft.move(to: CGPoint(x: W * 0.5 - 20, y: H * 0.5 - 20))
                    xLeft.addLine(to: CGPoint(x: W * 0.5 + 20, y: H * 0.5 + 20))
                    var xLeftGC = ctx; xLeftGC.addFilter(.blur(radius: 5))
                    xLeftGC.stroke(xLeft, with: .color(Color.red.opacity(0.8)), lineWidth: 6)
                    ctx.stroke(xLeft, with: .color(Color.red.opacity(0.9)), lineWidth: 3)
                }

                // #54 Wrong answer — red X right stroke
                if showWrong {
                    var xRight = Path()
                    xRight.move(to: CGPoint(x: W * 0.5 + 20, y: H * 0.5 - 20))
                    xRight.addLine(to: CGPoint(x: W * 0.5 - 20, y: H * 0.5 + 20))
                    ctx.stroke(xRight, with: .color(Color.red.opacity(0.9)), lineWidth: 3)
                }

                // #55 Wrong answer — dark vignette overlay
                if showWrong {
                    var vigPath = Path()
                    vigPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                    ctx.fill(vigPath, with: .color(Color.red.opacity(0.12)))
                }

                // #56 Streak fire particles (8 small flames rising) when streak >= 2
                if streakCount >= 2 {
                    for f in 0..<8 {
                        let ff = Double(f)
                        let fx = W * (0.38 + CGFloat(f) * 0.036)
                        let risePhase = fmod(t * 1.4 + ff * 0.35, 1.0)
                        let fy = H * 0.68 - CGFloat(risePhase) * 18
                        let fAlpha = 1.0 - risePhase
                        var flame = Path()
                        flame.addEllipse(in: CGRect(x: fx - 3, y: fy - 5, width: 6, height: 10))
                        var flameGC = ctx; flameGC.addFilter(.blur(radius: 3))
                        flameGC.fill(flame, with: .color(Color(red: 1.0, green: 0.5, blue: 0.1).opacity(fAlpha * 0.7)))
                        ctx.fill(flame, with: .color(Color(red: 1.0, green: 0.7, blue: 0.2).opacity(fAlpha * 0.9)))
                    }
                }

                // #57 Streak flame tips (lighter top)
                if streakCount >= 2 {
                    for f in 0..<8 {
                        let ff = Double(f)
                        let fx = W * (0.38 + CGFloat(f) * 0.036)
                        let risePhase = fmod(t * 1.4 + ff * 0.35 + 0.5, 1.0)
                        let fy = H * 0.68 - CGFloat(risePhase) * 18 - 5
                        let fAlpha = (1.0 - risePhase) * 0.7
                        var flameTip = Path()
                        flameTip.addEllipse(in: CGRect(x: fx - 2, y: fy - 3, width: 4, height: 6))
                        ctx.fill(flameTip, with: .color(Color.yellow.opacity(fAlpha)))
                    }
                }

                // #58 Time warning pulse — red border blink when <= 5s
                if timeRemaining <= 5 && timeRemaining > 0 {
                    let warnPulse = 0.5 + sin(t * 6.0) * 0.5
                    var warnBorder = Path()
                    warnBorder.addRect(CGRect(x: 3, y: 3, width: W - 6, height: H - 6))
                    var warnGC = ctx; warnGC.addFilter(.blur(radius: 8))
                    warnGC.stroke(warnBorder, with: .color(Color.red.opacity(warnPulse * 0.7)), lineWidth: 8)
                    ctx.stroke(warnBorder, with: .color(Color.red.opacity(warnPulse * 0.5)), lineWidth: 2)
                }

                // #59 Time warning inner glow
                if timeRemaining <= 5 && timeRemaining > 0 {
                    let warnPulse = 0.5 + sin(t * 6.0) * 0.5
                    var warnInner = Path()
                    warnInner.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                    ctx.fill(warnInner, with: .color(Color.red.opacity(warnPulse * 0.06)))
                }

                // #60 Double points lightning bolt (center top, visible on round 3+ bonus)
                if currentRound >= 3 {
                    let boltCX = W * 0.5
                    let boltTop = H * 0.04
                    let boltPulse = 0.6 + sin(t * 3.0) * 0.4
                    var bolt = Path()
                    bolt.move(to: CGPoint(x: boltCX - 5, y: boltTop))
                    bolt.addLine(to: CGPoint(x: boltCX + 2, y: boltTop + 10))
                    bolt.addLine(to: CGPoint(x: boltCX - 3, y: boltTop + 10))
                    bolt.addLine(to: CGPoint(x: boltCX + 5, y: boltTop + 22))
                    bolt.addLine(to: CGPoint(x: boltCX - 1, y: boltTop + 12))
                    bolt.addLine(to: CGPoint(x: boltCX + 4, y: boltTop + 12))
                    bolt.closeSubpath()
                    var boltGC = ctx; boltGC.addFilter(.blur(radius: 5))
                    boltGC.fill(bolt, with: .color(Color.yellow.opacity(boltPulse * 0.8)))
                    ctx.fill(bolt, with: .color(Color(red: 1.0, green: 0.95, blue: 0.1).opacity(boltPulse * 0.95)))
                }

                // #61 Lightning bolt secondary glow ring
                if currentRound >= 3 {
                    let boltPulse = 0.6 + sin(t * 3.0) * 0.4
                    var boltRing = Path()
                    boltRing.addEllipse(in: CGRect(x: W * 0.5 - 12, y: H * 0.04, width: 24, height: 24))
                    var boltRingGC = ctx; boltRingGC.addFilter(.blur(radius: 8))
                    boltRingGC.stroke(boltRing, with: .color(Color.yellow.opacity(boltPulse * 0.5)), lineWidth: 4)
                }

                // #62 Confetti burst — 20 colored dots on correct + last round
                if showCorrect && currentRound >= totalRounds - 1 {
                    let confColors: [Color] = [.yellow, .cyan, .orange, .pink, .green, .purple, .white, .red, .blue, .mint]
                    for ci in 0..<20 {
                        let fi2 = Double(ci)
                        let angle2 = fi2 * (.pi * 2 / 20) + t * 0.5
                        let radius2 = 30.0 + fi2 * 2.5 + sin(t * 2 + fi2) * 8
                        let cx = W * 0.5 + CGFloat(cos(angle2)) * CGFloat(radius2)
                        let cy = H * 0.5 + CGFloat(sin(angle2)) * CGFloat(radius2)
                        var confDot = Path()
                        confDot.addEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))
                        ctx.fill(confDot, with: .color(confColors[ci % confColors.count].opacity(0.85)))
                    }
                }

                // #63 Confetti square shapes (alternate shapes)
                if showCorrect && currentRound >= totalRounds - 1 {
                    let confColors: [Color] = [.yellow, .cyan, .orange, .pink, .green, .purple]
                    for ci in 0..<10 {
                        let fi2 = Double(ci)
                        let angle2 = fi2 * (.pi / 5) + t * 0.7 + .pi / 10
                        let radius2 = 42.0 + fi2 * 2 + sin(t * 1.5 + fi2) * 6
                        let cx = W * 0.5 + CGFloat(cos(angle2)) * CGFloat(radius2)
                        let cy = H * 0.5 + CGFloat(sin(angle2)) * CGFloat(radius2)
                        var confSquare = Path()
                        confSquare.addRect(CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))
                        ctx.fill(confSquare, with: .color(confColors[ci % confColors.count].opacity(0.80)))
                    }
                }

                // #64 Correct answer outer burst ring
                if showCorrect {
                    let ringPulse = fmod(t * 1.5, 1.0)
                    let ringR2 = 25 + CGFloat(ringPulse) * 35
                    var burstRing = Path()
                    burstRing.addEllipse(in: CGRect(x: W * 0.5 - ringR2, y: H * 0.5 - ringR2,
                                                    width: ringR2 * 2, height: ringR2 * 2))
                    ctx.stroke(burstRing, with: .color(Color.green.opacity((1.0 - ringPulse) * 0.8)), lineWidth: 2)
                }

                // #65 Wrong answer vignette corners
                if showWrong {
                    for corner in 0..<4 {
                        let cx2 = corner % 2 == 0 ? CGFloat(0) : W
                        let cy2 = corner < 2 ? CGFloat(0) : H
                        var vignette = Path()
                        vignette.addEllipse(in: CGRect(x: cx2 - 40, y: cy2 - 40, width: 80, height: 80))
                        var vigGC = ctx; vigGC.addFilter(.blur(radius: 18))
                        vigGC.fill(vignette, with: .color(Color.red.opacity(0.35)))
                    }
                }

                // #66 Answer FX ambient shimmer (always on)
                let shimmer = 0.3 + sin(t * 4.5) * 0.1
                var shimmerLine = Path()
                shimmerLine.addRect(CGRect(x: 0, y: H * 0.49, width: W, height: 1))
                ctx.fill(shimmerLine, with: .color(Color.white.opacity(shimmer * 0.15)))

                // ============================================================
                // SCENE 6: SCORE / UI ON CANVAS  (#67 – #80)
                // ============================================================

                // #67 Leaderboard side panel background (left)
                var leaderBg = Path()
                leaderBg.addRoundedRect(
                    in: CGRect(x: W * 0.005, y: H * 0.32, width: W * 0.115, height: H * 0.18),
                    cornerSize: CGSize(width: 5, height: 5)
                )
                ctx.fill(leaderBg, with: .color(Color.black.opacity(0.55)))
                ctx.stroke(leaderBg, with: .color(Color.white.opacity(0.08)), lineWidth: 0.5)

                // #68 Leaderboard score bar 1 (player)
                let bar1W = W * 0.08 * CGFloat(min(1.0, Double(playerScore) / 100.0))
                var bar1 = Path()
                bar1.addRoundedRect(in: CGRect(x: W * 0.01, y: H * 0.340, width: bar1W, height: 5),
                                    cornerSize: CGSize(width: 2, height: 2))
                ctx.fill(bar1, with: .color(Color.cyan.opacity(0.85)))

                // #69 Leaderboard score bar 2 (opponent)
                let bar2W = W * 0.08 * CGFloat(min(1.0, Double(opponentScore) / 100.0))
                var bar2 = Path()
                bar2.addRoundedRect(in: CGRect(x: W * 0.01, y: H * 0.355, width: bar2W, height: 5),
                                    cornerSize: CGSize(width: 2, height: 2))
                ctx.fill(bar2, with: .color(Color.orange.opacity(0.85)))

                // #70 Leaderboard score bar 3 (ghost / best)
                let bar3W = W * 0.08 * CGFloat(0.65)
                var bar3 = Path()
                bar3.addRoundedRect(in: CGRect(x: W * 0.01, y: H * 0.370, width: bar3W, height: 5),
                                    cornerSize: CGSize(width: 2, height: 2))
                ctx.fill(bar3, with: .color(Color.white.opacity(0.25)))

                // #71 Time bar draining across top
                let timeFraction = CGFloat(timeRemaining) / CGFloat(max(1, totalTime))
                var timeBarBg = Path()
                timeBarBg.addRoundedRect(in: CGRect(x: W * 0.14, y: H * 0.003, width: W * 0.72, height: 5),
                                         cornerSize: CGSize(width: 2, height: 2))
                ctx.fill(timeBarBg, with: .color(Color.white.opacity(0.08)))
                var timeBarFill = Path()
                timeBarFill.addRoundedRect(
                    in: CGRect(x: W * 0.14, y: H * 0.003, width: W * 0.72 * timeFraction, height: 5),
                    cornerSize: CGSize(width: 2, height: 2)
                )
                let timeBarColor: Color = timeRemaining > 8 ? Color(red: 0.2, green: 0.8, blue: 1.0) : Color.red
                ctx.fill(timeBarFill, with: .color(timeBarColor.opacity(0.85)))

                // #72 Time bar glow
                var timeBarGC = ctx; timeBarGC.addFilter(.blur(radius: 3))
                timeBarGC.fill(timeBarFill, with: .color(timeBarColor.opacity(0.5)))

                // #73 Round indicator circles (filled / unfilled)
                for r in 0..<totalRounds {
                    let rX = W * (0.5 - CGFloat(totalRounds - 1) * 0.035 + CGFloat(r) * 0.07)
                    let rY = H * 0.008
                    var roundDot = Path()
                    roundDot.addEllipse(in: CGRect(x: rX - 4, y: rY, width: 8, height: 8))
                    if r < currentRound {
                        ctx.fill(roundDot, with: .color(Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.9)))
                    } else if r == currentRound {
                        var activeGC = ctx; activeGC.addFilter(.blur(radius: 4))
                        activeGC.fill(roundDot, with: .color(Color.white.opacity(0.6)))
                        ctx.fill(roundDot, with: .color(Color.white.opacity(0.9)))
                    } else {
                        ctx.stroke(roundDot, with: .color(Color.white.opacity(0.25)), lineWidth: 1)
                    }
                }

                // #74 Lifeline icon 1 (left — hint phone)
                var lifeIcon1 = Path()
                lifeIcon1.addRoundedRect(in: CGRect(x: W * 0.005, y: H * 0.525, width: 20, height: 20),
                                         cornerSize: CGSize(width: 4, height: 4))
                ctx.fill(lifeIcon1, with: .color(Color(red: 0.15, green: 0.08, blue: 0.30).opacity(0.9)))
                ctx.stroke(lifeIcon1, with: .color(Color.cyan.opacity(0.5)), lineWidth: 1)
                ctx.draw(
                    Text("?")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.cyan.opacity(0.8)),
                    at: CGPoint(x: W * 0.018, y: H * 0.535)
                )

                // #75 Lifeline icon 2 (second — 50/50)
                var lifeIcon2 = Path()
                lifeIcon2.addRoundedRect(in: CGRect(x: W * 0.005, y: H * 0.550, width: 20, height: 20),
                                         cornerSize: CGSize(width: 4, height: 4))
                ctx.fill(lifeIcon2, with: .color(Color(red: 0.15, green: 0.08, blue: 0.30).opacity(0.9)))
                ctx.stroke(lifeIcon2, with: .color(Color.yellow.opacity(0.5)), lineWidth: 1)
                ctx.draw(
                    Text("½")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.yellow.opacity(0.8)),
                    at: CGPoint(x: W * 0.018, y: H * 0.560)
                )

                // #76 Lifeline icon 3 (third — skip)
                var lifeIcon3 = Path()
                lifeIcon3.addRoundedRect(in: CGRect(x: W * 0.005, y: H * 0.575, width: 20, height: 20),
                                         cornerSize: CGSize(width: 4, height: 4))
                ctx.fill(lifeIcon3, with: .color(Color(red: 0.15, green: 0.08, blue: 0.30).opacity(0.9)))
                ctx.stroke(lifeIcon3, with: .color(Color.orange.opacity(0.5)), lineWidth: 1)
                ctx.draw(
                    Text("»")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.orange.opacity(0.8)),
                    at: CGPoint(x: W * 0.018, y: H * 0.585)
                )

                // #77 Jackpot meter bar background (right side)
                var jackpotBg = Path()
                jackpotBg.addRoundedRect(
                    in: CGRect(x: W * 0.94, y: H * 0.32, width: 14, height: H * 0.25),
                    cornerSize: CGSize(width: 3, height: 3)
                )
                ctx.fill(jackpotBg, with: .color(Color.black.opacity(0.6)))
                ctx.stroke(jackpotBg, with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)

                // #78 Jackpot meter fill (rising based on score)
                let jackpotFrac = CGFloat(min(1.0, Double(playerScore) / 80.0))
                let jackpotH = H * 0.25 * jackpotFrac
                var jackpotFill = Path()
                jackpotFill.addRoundedRect(
                    in: CGRect(x: W * 0.941, y: H * 0.32 + H * 0.25 - jackpotH, width: 12, height: jackpotH),
                    cornerSize: CGSize(width: 2, height: 2)
                )
                let jackpotColor = jackpotFrac > 0.7 ? Color.yellow : jackpotFrac > 0.4 ? Color.orange : Color(red: 0.4, green: 0.2, blue: 0.8)
                ctx.fill(jackpotFill, with: .color(jackpotColor.opacity(0.85)))

                // #79 Jackpot meter glow
                if jackpotFrac > 0.5 {
                    var jackpotGC = ctx; jackpotGC.addFilter(.blur(radius: 5))
                    jackpotGC.fill(jackpotFill, with: .color(jackpotColor.opacity(0.5)))
                }

                // #80 Jackpot label at top of meter
                ctx.draw(
                    Text("JP")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(jackpotColor.opacity(0.85)),
                    at: CGPoint(x: W * 0.948, y: H * 0.316)
                )
            }
        }
    }
}

// MARK: - Haptic Helpers

private func hapticBuzzerCorrect() {
    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
}

private func hapticBonusJackpot() {
    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
}

private func hapticTimeWarning() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}

private func hapticLifeline() {
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
}

private func hapticWrongAnswer() {
    UINotificationFeedbackGenerator().notificationOccurred(.error)
}

// MARK: - Main Game View

struct WhoSceneItView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @State private var phase: WhoPhase = .ready
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var currentIndex = 0
    @State private var timeRemaining = 20
    @State private var selectedAnswer: Int? = nil
    @State private var showAnswer = false
    @State private var showCreatorSpotlight = false
    @State private var timerTask: Task<Void, Never>?
    @State private var streakCount = 0
    @State private var timeWarningFired = false

    private enum WhoPhase { case ready, playing, result }
    private var questions: [WhoQuestion] { WhoSceneItQuestions.all }
    private var current: WhoQuestion { questions[min(currentIndex, questions.count - 1)] }

    private var activeCreatorCard: CreatorCard? {
        guard let state = viewModel.profile.activeCreatorCard else { return nil }
        return CreatorCard.catalog.first(where: { $0.id == state.cardId })
    }

    // Derived answer feedback state
    private var showCorrect: Bool {
        showAnswer && selectedAnswer == current.correctIndex
    }
    private var showWrong: Bool {
        showAnswer && selectedAnswer != nil && selectedAnswer != current.correctIndex
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()

            // Full-screen game show stage canvas background
            GameShowStageCanvas(
                timeRemaining: timeRemaining,
                totalTime: 20,
                playerScore: playerScore,
                opponentScore: opponentScore,
                showCorrect: showCorrect,
                showWrong: showWrong,
                currentRound: currentIndex,
                totalRounds: questions.count,
                streakCount: streakCount
            )
            .ignoresSafeArea()
            .opacity(phase == .playing ? 1.0 : 0.4)

            // Dark overlay for readability
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.03, blue: 0.02).opacity(0.35),
                         Color(red: 0.02, green: 0.02, blue: 0.06).opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: gameMode.name,
                    subtitle: "Sports & creator trivia · Spot the scene",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { startGame() }
                )
            case .playing:
                playingBody
            case .result:
                ResultScreen(
                    winner: playerScore > opponentScore ? .p1 : (opponentScore > playerScore ? .p2 : .draw),
                    p1Score: playerScore,
                    p2Score: opponentScore,
                    title: "Who Scene It",
                    accentColor: gameMode.accentColor,
                    prqGain: playerScore > opponentScore ? 10 : 2,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "IQ",
                    modeAttributeValue: Double(playerScore) / Double(max(1, questions.count * 10)),
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
            ToolbarItem(placement: .topBarTrailing) {
                if let card = activeCreatorCard {
                    Button { showCreatorSpotlight = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: card.iconName).font(.system(size: 10, weight: .bold))
                            Text(card.creatorName.uppercased()).font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(card.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(card.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showCreatorSpotlight) {
            if let card = activeCreatorCard {
                CreatorCardShowcaseView(card: card)
            }
        }
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - Playing Body

    private var playingBody: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(gameMode.accentColor.opacity(0.8))
                    Text("\(playerScore)").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundStyle(.white)
                }
                Spacer()
                Text("Q \(currentIndex + 1)/\(questions.count)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(gameMode.accentColor)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("OPP").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                    Text("\(opponentScore)").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(timeRemaining > 8 ? gameMode.accentColor : Color.red)
                        .frame(width: geo.size.width * CGFloat(timeRemaining) / 20)
                        .animation(.linear(duration: 1), value: timeRemaining)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()

            if let card = activeCreatorCard, current.featureCreatorCard {
                creatorHighlightCard(card: card)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            questionArea
                .padding(.horizontal, 20)

            Spacer()

            answersGrid
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .onChange(of: timeRemaining) { _, newValue in
            // Haptic: time warning at 5 seconds
            if newValue == 5 && !timeWarningFired {
                timeWarningFired = true
                hapticTimeWarning()
            }
        }
    }

    private func creatorHighlightCard(card: CreatorCard) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(card.accentColor.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: card.iconName).font(.system(size: 14, weight: .bold)).foregroundStyle(card.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("CREATOR CARD ACTIVE").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(card.accentColor)
                Text(card.showcaseTagline).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button {
                hapticLifeline()
                showCreatorSpotlight = true
            } label: {
                Text("VIEW IP").font(.system(size: 8, weight: .black, design: .monospaced))
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(card.accentColor.opacity(0.15))
                    .foregroundStyle(card.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(card.accentColor.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 12).stroke(card.accentColor.opacity(0.18), lineWidth: 0.5)))
    }

    private var questionArea: some View {
        VStack(spacing: 12) {
            ZStack {
                // Base scene canvas
                WhoSceneCanvas(sceneType: WhoSceneType.infer(from: current.sceneDescription))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Difficulty-based reveal overlays
                sceneRevealOverlay

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.42))
                Text(current.sceneDescription)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(gameMode.accentColor.opacity(0.90))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .frame(height: 80)
            Text(current.question)
                .font(.system(.title3, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var sceneRevealOverlay: some View {
        switch currentDifficulty {
        case .easy:
            EmptyView()

        case .medium:
            // Edge vignette fading out from center over sceneRevealProgress
            GeometryReader { geo in
                let edgeAlpha = max(0.0, 0.85 * (1.0 - sceneRevealProgress))
                Canvas { ctx, size in
                    var edge = Path()
                    edge.addRect(CGRect(origin: .zero, size: size))
                    ctx.fill(edge, with: .radialGradient(
                        Gradient(colors: [
                            Color.black.opacity(0),
                            Color.black.opacity(edgeAlpha)
                        ]),
                        center: CGPoint(x: size.width / 2, y: size.height / 2),
                        startRadius: size.width * 0.2,
                        endRadius: size.width * 0.7
                    ))
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

        case .hard:
            // Dark overlay with circular spotlight cutout at center
            GeometryReader { geo in
                let W = geo.size.width
                let H = geo.size.height
                ZStack {
                    // Dark background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.82))
                    // Spotlight circle reveal via blendMode mask
                    Circle()
                        .fill(Color.black)
                        .frame(width: min(W, H) * 0.76, height: min(W, H) * 0.76)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .allowsHitTesting(false)
            }

        case .expert:
            // Only center band visible — covers top/bottom/side strips
            GeometryReader { geo in
                Canvas { ctx, size in
                    let H = size.height
                    // Top cover
                    ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: H * 0.28)),
                             with: .color(Color.black.opacity(0.92)))
                    // Bottom cover
                    ctx.fill(Path(CGRect(x: 0, y: H * 0.72, width: size.width, height: H * 0.28)),
                             with: .color(Color.black.opacity(0.92)))
                    // Left cover
                    ctx.fill(Path(CGRect(x: 0, y: H * 0.28, width: size.width * 0.15, height: H * 0.44)),
                             with: .color(Color.black.opacity(0.92)))
                    // Right cover
                    ctx.fill(Path(CGRect(x: size.width * 0.85, y: H * 0.28, width: size.width * 0.15, height: H * 0.44)),
                             with: .color(Color.black.opacity(0.92)))
                    // Expert frame
                    var frame = Path()
                    frame.addRoundedRect(
                        in: CGRect(x: size.width * 0.15, y: H * 0.28, width: size.width * 0.70, height: H * 0.44),
                        cornerSize: CGSize(width: 4, height: 4)
                    )
                    ctx.stroke(frame, with: .color(Color.red.opacity(0.6)), lineWidth: 1.5)
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Computed UI Helpers

    private var timerBarColor: Color {
        let total = max(1, Int(roundTimeLimit))
        let fraction = Double(timeRemaining) / Double(total)
        if fraction > 0.5 { return gameMode.accentColor }
        if fraction > 0.25 { return .orange }
        return .red
    }

    private var streakMultiplierView: some View {
        HStack(spacing: 6) {
            let iconName: String = streakMultiplier >= 5 ? "crown.fill" : "flame.fill"
            let iconColor: Color = streakMultiplier >= 5 ? .yellow : .orange
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(iconColor)
                .shadow(color: iconColor, radius: 4)
            if streakMultiplier >= 3 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.yellow)
                    .shadow(color: .yellow, radius: 4)
            }
            Text("\(streakMultiplier)x STREAK")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(iconColor)
            Text("(\(streakCount) in a row)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.10))
        .clipShape(Capsule())
    }

    // MARK: - Overlay Views

    private var roundBadgeOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Circle()
                    .stroke(currentDifficulty.color, lineWidth: 3)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("\(currentRound)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(currentDifficulty.color)
                    )
                Text("ROUND \(currentRound) — \(currentDifficulty.label)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(currentDifficulty.color.opacity(0.6), lineWidth: 2)
                    )
            )
            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var difficultyTransitionOverlay: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("LEVEL UP")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(difficultyTransitionLabel)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(currentDifficulty.color)
                Text(currentDifficulty.description)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }

    private var quickStrikeOverlay: some View {
        VStack {
            Spacer()
            Text("+500 QUICK STRIKE!")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(.yellow)
                .shadow(color: .yellow, radius: 8)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 120)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var answersGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(current.answers.indices, id: \.self) { idx in
                answerButton(index: idx)
            }
        }
    }

    private func answerButton(index: Int) -> some View {
        let isSelected = selectedAnswer == index
        let isCorrect = index == current.correctIndex
        let bg: Color = showAnswer
            ? (isCorrect ? Color.green.opacity(0.18) : (isSelected ? Color.red.opacity(0.15) : Color.white.opacity(0.03)))
            : (isSelected ? gameMode.accentColor.opacity(0.18) : Color.white.opacity(0.05))
        let border: Color = showAnswer
            ? (isCorrect ? .green : (isSelected ? .red : Color.white.opacity(0.06)))
            : (isSelected ? gameMode.accentColor : Color.white.opacity(0.08))

        return Button {
            guard selectedAnswer == nil else { return }
            selectedAnswer = index
            handleAnswer(index: index)
        } label: {
            Text(current.answers[index])
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 12).fill(bg))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(selectedAnswer != nil)
    }

    // MARK: - Game Logic

    private func startGame() {
        playerScore = 0; opponentScore = 0; currentIndex = 0
        streakCount = 0
        phase = .playing
        beginQuestion()
    }

    private func beginQuestion() {
        timeRemaining = 20; selectedAnswer = nil; showAnswer = false
        timeWarningFired = false
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeRemaining -= 1 }
            }
            await MainActor.run {
                // Haptic: time out = wrong answer haptic
                hapticWrongAnswer()
                showAnswer = true
                streakCount = 0
                Task { try? await Task.sleep(for: .milliseconds(1200)); await MainActor.run { advance() } }
            }
        }
        Task {
            let delay = Double.random(in: 5...17)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, phase == .playing else { return }
            await MainActor.run {
                if Double.random(in: 0...1) < 0.55 { opponentScore += 10 }
            }
        }
    }

    private func handleAnswer(index: Int) {
        timerTask?.cancel()
        showAnswer = true
        let isCorrect = index == current.correctIndex
        if isCorrect {
            // Haptic: buzzer press / correct answer = .heavy
            hapticBuzzerCorrect()
            playerScore += 10 + max(0, timeRemaining - 5)
            streakCount += 1
            // Haptic: bonus/jackpot round win = .rigid (on long streak or high round)
            if streakCount >= 3 || currentIndex >= questions.count - 1 {
                hapticBonusJackpot()
            }
        } else {
            // Haptic: wrong answer = error notification
            hapticWrongAnswer()
            streakCount = 0
        }
        Task { try? await Task.sleep(for: .milliseconds(1400)); await MainActor.run { advance() } }
    }

    private func advance() {
        if currentIndex + 1 >= questions.count {
            GameResultService.saveResult(modeId: "who_scene_it", userScore: playerScore)
            phase = .result
        } else { currentIndex += 1; beginQuestion() }
    }
}

// MARK: - Data Models

struct WhoQuestion {
    let sceneDescription: String
    let question: String
    let answers: [String]
    let correctIndex: Int
    var featureCreatorCard: Bool = false
}

enum WhoSceneItQuestions {
    static let all: [WhoQuestion] = [
        WhoQuestion(sceneDescription: "🏀 Venice Beach · Blue outdoor court · Sunset", question: "Which city is the birthplace of streetball culture?", answers: ["New York", "Los Angeles", "Chicago", "Houston"], correctIndex: 1),
        WhoQuestion(sceneDescription: "🎿 Mountain halfpipe · Fresh powder · Clear sky", question: "Who invented the modern halfpipe in snowboarding?", answers: ["Shaun White", "Tom Sims & Mike Chantry", "Travis Rice", "Mark McMorris"], correctIndex: 1),
        WhoQuestion(sceneDescription: "🥋 Dojo · Wooden floor · Neon lights", question: "In karate, what does 'kiai' refer to?", answers: ["A defensive stance", "An energy shout", "A tournament format", "A throwing technique"], correctIndex: 1),
        WhoQuestion(sceneDescription: "⛳ Golf green · Coastal course · Morning mist", question: "What is an eagle in golf?", answers: ["1 over par", "1 under par", "2 under par", "Hole in one"], correctIndex: 2),
        WhoQuestion(sceneDescription: "🏄 Venice Beach ocean · Head-high waves · Midday", question: "What surfing move involves rotating 360° in the air?", answers: ["Cutback", "Aerial 360", "Bottom turn", "Floater"], correctIndex: 1, featureCreatorCard: true),
        WhoQuestion(sceneDescription: "🏐 Beach volleyball · Sand court · Crowd watching", question: "How many sets in a standard beach volleyball match?", answers: ["2", "3", "4", "5"], correctIndex: 1),
        WhoQuestion(sceneDescription: "⚽ Stadium pitch · Night match · Floodlights", question: "What is a 'brace' in football/soccer?", answers: ["A yellow card", "A player scoring twice", "A defensive formation", "An overtime period"], correctIndex: 1),
        WhoQuestion(sceneDescription: "🏈 Stadium field · Friday night lights", question: "How many yards for a first down in American football?", answers: ["5", "8", "10", "15"], correctIndex: 2),
        WhoQuestion(sceneDescription: "🎿 Skate park · Concrete ramps · Street setting", question: "What is an 'ollie' in skateboarding?", answers: ["A grind trick", "A jump without hands", "A rail slide", "A foot flip"], correctIndex: 1, featureCreatorCard: true),
        WhoQuestion(sceneDescription: "🧠 Neural Arena · Two podiums · Tense atmosphere", question: "What does HRV measure in athlete recovery?", answers: ["Heart rate variability", "Hydration levels", "High rep volume", "Hip rotation velocity"], correctIndex: 0),
    ]
}
