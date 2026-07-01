import SwiftUI
import UIKit

// MARK: - Haptic Helpers

private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

private func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
}

// MARK: - Surf Mode

enum SurfMode { case competition, endless }

// MARK: - Wave Type

private enum SurfWaveType {
    case mellow, solid, overhead, barrel, closeout

    var label: String {
        switch self {
        case .mellow:   return "MELLOW"
        case .solid:    return "SOLID"
        case .overhead: return "OVERHEAD"
        case .barrel:   return "BARREL!"
        case .closeout: return "CLOSEOUT"
        }
    }

    var pointMultiplier: Double {
        switch self {
        case .mellow:   return 0.7
        case .solid:    return 1.0
        case .overhead: return 1.4
        case .barrel:   return 2.2
        case .closeout: return 0.0
        }
    }

    var color: Color {
        switch self {
        case .mellow:   return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .solid:    return Color(red: 0.2, green: 0.75, blue: 1.0)
        case .overhead: return Color(red: 0.3, green: 1.0, blue: 0.6)
        case .barrel:   return Color(red: 1.0, green: 0.85, blue: 0.1)
        case .closeout: return Color(red: 1.0, green: 0.35, blue: 0.35)
        }
    }

    var description: String {
        switch self {
        case .mellow:   return "Easy ride · x0.7 pts"
        case .solid:    return "Good wave · x1.0 pts"
        case .overhead: return "Big wave · x1.4 pts"
        case .barrel:   return "Hold center 3s · x2.2 pts"
        case .closeout: return "Duck dive to survive!"
        }
    }

    static func random() -> SurfWaveType {
        let weights: [(SurfWaveType, Int)] = [
            (.mellow, 20), (.solid, 35), (.overhead, 25), (.barrel, 12), (.closeout, 8)
        ]
        let total = weights.reduce(0) { $0 + $1.1 }
        var r = Int.random(in: 0..<total)
        for (type, w) in weights {
            r -= w
            if r < 0 { return type }
        }
        return .solid
    }
}

// MARK: - Phase

private enum SurfingPhase {
    case lobby, ready, paddleIn, riding, trickWindow, barrelRide, duckDive, wipeout, waveResult, heatResult, sessionSummary, result
}

// MARK: - Trick Type

private enum SurfTrick: String, CaseIterable {
    case aerial   = "AERIAL"
    case tube     = "TUBE RIDE"
    case cutback  = "CUTBACK"

    var points: Int {
        switch self {
        case .aerial:  return 8
        case .tube:    return 10
        case .cutback: return 6
        }
    }

    var systemImage: String {
        switch self {
        case .aerial:  return "arrow.up.circle.fill"
        case .tube:    return "arrow.down.circle.fill"
        case .cutback: return "arrow.turn.up.right"
        }
    }

    var swipeHint: String {
        switch self {
        case .aerial:  return "SWIPE UP"
        case .tube:    return "SWIPE DOWN"
        case .cutback: return "SWIPE DIAG"
        }
    }
}

// MARK: - Wave Score

private struct WaveScore: Identifiable {
    let id = UUID()
    let waveNumber: Int
    var rawScore: Double
    var wipeout: Bool
    var finalScore: Double { wipeout ? 0 : rawScore }
}

// MARK: - Canvas Phase

private enum SurfCanvasPhase {
    case normal, tube, aerial, wipeout
}

// MARK: - Surf Wave Drawer

private struct SurfWaveDrawer {
    let W: CGFloat
    let H: CGFloat
    let balance: Double
    let power: Double
    let isTrickWindow: Bool
    let t: Double
    var canvasPhase: SurfCanvasPhase = .normal
    var comboString: [String] = []
    var tubeMultiplier: Int = 1
    var jerseyColor: Color = Color(red: 0.2, green: 0.75, blue: 1.0)

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawHorizonGlow(ctx: &ctx)
        drawOcean(ctx: &ctx)
        drawOceanRipples(ctx: &ctx)
        drawPier(ctx: &ctx)
        drawBeachCrowd(ctx: &ctx)
        drawWaveFace(ctx: &ctx)
        drawWaveCrestFoam(ctx: &ctx)
        drawCrestSpray(ctx: &ctx)
        drawWhitewater(ctx: &ctx)
        drawFoamStripes(ctx: &ctx)
        if canvasPhase == .tube { drawTubeScene(ctx: &ctx) }
        drawSurfer(ctx: &ctx)
        drawSeagulls(ctx: &ctx)
        if !comboString.isEmpty { drawComboString(ctx: &ctx) }
        if isTrickWindow { drawTrickGlow(ctx: &ctx) }
    }

    private func waveGeometry() -> (crestX: CGFloat, crestY: CGFloat, baseX: CGFloat, baseY: CGFloat, waveH: CGFloat) {
        let waveH = H * (0.22 + CGFloat(power) * 0.32)
        let breathe = CGFloat(sin(t * 1.6)) * H * 0.012
        let crestX = W * 0.74
        let crestY = H * 0.38 - waveH + breathe
        let baseX: CGFloat = W * 0.04
        let baseY: CGFloat = H * 0.86
        return (crestX, crestY, baseX, baseY, waveH)
    }

    private func drawSky(ctx: inout GraphicsContext) {
        let horizonY = H * 0.37
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: horizonY)),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.02, green: 0.05, blue: 0.18), location: 0),
                        .init(color: Color(red: 0.04, green: 0.20, blue: 0.38), location: 1)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: horizonY)))
        ctx.fill(Path(CGRect(x: 0, y: horizonY - 8, width: W, height: 16)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.10, green: 0.50, blue: 0.70).opacity(0.30), .clear]),
                    startPoint: CGPoint(x: 0, y: horizonY - 8),
                    endPoint: CGPoint(x: 0, y: horizonY + 8)))
        var sunGC = ctx
        sunGC.addFilter(.blur(radius: 22))
        sunGC.fill(Path(ellipseIn: CGRect(x: W * 0.70 - 18, y: H * 0.04, width: 36, height: 28)),
                   with: .color(Color(red: 1.0, green: 0.95, blue: 0.80).opacity(0.28)))
    }

    private func drawHorizonGlow(ctx: inout GraphicsContext) {
        let horizonY = H * 0.37
        let pulse = CGFloat(0.5 + 0.5 * sin(t * 0.4))
        var glowGC = ctx
        glowGC.addFilter(.blur(radius: 28))
        glowGC.fill(Path(CGRect(x: 0, y: horizonY - 22, width: W, height: 44)),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: Color(red: 1.0, green: 0.55, blue: 0.10)
                                    .opacity(Double(0.12 + pulse * 0.14)), location: 0),
                            .init(color: Color(red: 1.0, green: 0.38, blue: 0.05)
                                    .opacity(Double(0.08 + pulse * 0.10)), location: 0.5),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: horizonY - 22),
                        endPoint: CGPoint(x: 0, y: horizonY + 22)))
    }

    private func drawOcean(ctx: inout GraphicsContext) {
        let horizonY = H * 0.37
        ctx.fill(Path(CGRect(x: 0, y: horizonY, width: W, height: H - horizonY)),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.03, green: 0.22, blue: 0.38), location: 0.0),
                        .init(color: Color(red: 0.04, green: 0.30, blue: 0.42), location: 0.30),
                        .init(color: Color(red: 0.05, green: 0.40, blue: 0.52), location: 0.60),
                        .init(color: Color(red: 0.06, green: 0.50, blue: 0.60), location: 0.80),
                        .init(color: Color(red: 0.02, green: 0.10, blue: 0.22), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: 0, y: horizonY),
                    endPoint: CGPoint(x: 0, y: H)))
        for i in 0..<3 {
            let fi = Double(i)
            let wavePhase = fmod(t * 0.3 + fi * 0.7, 1.0)
            let wx = W * CGFloat(0.1 + fi * 0.28 + wavePhase * 0.14)
            let wy = horizonY + H * CGFloat(0.03 + fi * 0.016)
            let ww = W * CGFloat(0.12 + fi * 0.04)
            var farWave = Path()
            farWave.move(to: CGPoint(x: wx, y: wy))
            farWave.addQuadCurve(to: CGPoint(x: wx + ww, y: wy),
                                  control: CGPoint(x: wx + ww * 0.5, y: wy - H * 0.018))
            ctx.stroke(farWave,
                       with: .color(Color(red: 0.20, green: 0.60, blue: 0.75).opacity(0.30)),
                       lineWidth: 1.5)
        }
    }

    private func drawOceanRipples(ctx: inout GraphicsContext) {
        let (_, _, baseX, baseY, _) = waveGeometry()
        for r in 0..<8 {
            let fr = Double(r)
            let ry = baseY + H * CGFloat(0.04 + fr * 0.018)
            guard ry < H else { continue }
            let phase = fmod(t * 0.8 + fr * 0.3, 2.0 * .pi)
            var ripple = Path()
            let steps = 20
            for s in 0..<steps {
                let x = CGFloat(s) / CGFloat(steps - 1) * baseX * 0.9
                let y = ry + CGFloat(sin(Double(s) * 0.9 + phase)) * H * 0.004
                if s == 0 { ripple.move(to: CGPoint(x: x, y: y)) }
                else { ripple.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(ripple,
                       with: .color(Color(red: 0.35, green: 0.70, blue: 0.90)
                                        .opacity(max(0, 0.14 - fr * 0.01))),
                       lineWidth: 0.8)
        }
    }

    private func drawPier(ctx: inout GraphicsContext) {
        let horizonY = H * 0.37
        let pierBaseY = horizonY + H * 0.04
        let pierTipX = W * 0.60
        let pierEndX = W * 1.0
        let pierTopY = pierBaseY - H * 0.02
        var pier = Path()
        pier.move(to: CGPoint(x: pierTipX, y: pierTopY))
        pier.addLine(to: CGPoint(x: pierEndX, y: pierTopY))
        pier.addLine(to: CGPoint(x: pierEndX, y: pierBaseY + H * 0.012))
        pier.addLine(to: CGPoint(x: pierTipX, y: pierBaseY + H * 0.012))
        pier.closeSubpath()
        ctx.fill(pier, with: .color(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.82)))
        for k in 0..<5 {
            let px = pierTipX + (pierEndX - pierTipX) * CGFloat(k) / 4.0
            var piling = Path()
            piling.move(to: CGPoint(x: px, y: pierBaseY + H * 0.012))
            piling.addLine(to: CGPoint(x: px, y: pierBaseY + H * 0.055))
            ctx.stroke(piling,
                       with: .color(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.75)),
                       lineWidth: 3)
        }
    }

    private func drawBeachCrowd(ctx: inout GraphicsContext) {
        let crowdY = H * 0.90
        let bigMove = power > 0.75
        for k in 0..<15 {
            let fk = Double(k)
            let cx = W * CGFloat(0.04 + fk * 0.061)
            let bobOffset = bigMove ? CGFloat(abs(sin(t * 3.0 + fk * 0.7))) * 5.0 : 0
            let cy = crowdY - bobOffset
            let r = CGFloat(0.5 + fk / 15.0 * 0.3)
            let g = CGFloat(0.3 + 0.2 * sin(fk))
            let b = CGFloat(0.6 + 0.2 * cos(fk))
            let spectatorColor = Color(red: Double(r), green: Double(g), blue: Double(b)).opacity(0.65)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: cy - 5, width: 6, height: 7)),
                     with: .color(spectatorColor))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 2, y: cy - 10, width: 5, height: 5)),
                     with: .color(spectatorColor))
        }
    }

    private func drawWaveFace(ctx: inout GraphicsContext) {
        let (crestX, crestY, baseX, baseY, waveH) = waveGeometry()
        var wavePath = Path()
        wavePath.move(to: CGPoint(x: baseX, y: baseY))
        wavePath.addCurve(
            to: CGPoint(x: crestX, y: crestY),
            control1: CGPoint(x: W * 0.12, y: baseY - waveH * 0.55),
            control2: CGPoint(x: crestX - W * 0.22, y: crestY + waveH * 0.28))
        let curlW = W * 0.07 * CGFloat(power)
        let curlH = H * 0.06 * CGFloat(power)
        wavePath.addCurve(
            to: CGPoint(x: crestX + curlW, y: crestY + curlH),
            control1: CGPoint(x: crestX + W * 0.02, y: crestY - H * 0.03),
            control2: CGPoint(x: crestX + curlW * 0.7, y: crestY + curlH * 0.3))
        wavePath.addLine(to: CGPoint(x: W, y: crestY + curlH))
        wavePath.addLine(to: CGPoint(x: W, y: baseY))
        wavePath.addLine(to: CGPoint(x: baseX, y: baseY))
        wavePath.closeSubpath()
        ctx.fill(wavePath, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.07, green: 0.50, blue: 0.78).opacity(0.95), location: 0.0),
                .init(color: Color(red: 0.04, green: 0.32, blue: 0.58).opacity(0.97), location: 0.45),
                .init(color: Color(red: 0.01, green: 0.14, blue: 0.30), location: 1.0)
            ]),
            startPoint: CGPoint(x: crestX, y: crestY),
            endPoint: CGPoint(x: baseX, y: baseY)))
        var hlGC = ctx
        hlGC.addFilter(.blur(radius: 7))
        var hlPath = Path()
        hlPath.move(to: CGPoint(x: W * 0.22, y: baseY - waveH * 0.40))
        hlPath.addCurve(
            to: CGPoint(x: crestX - W * 0.08, y: crestY + waveH * 0.18),
            control1: CGPoint(x: W * 0.30, y: baseY - waveH * 0.62),
            control2: CGPoint(x: crestX - W * 0.15, y: crestY + waveH * 0.32))
        hlPath.addLine(to: CGPoint(x: crestX - W * 0.04, y: crestY + waveH * 0.18))
        hlPath.addLine(to: CGPoint(x: W * 0.28, y: baseY - waveH * 0.36))
        hlPath.closeSubpath()
        hlGC.fill(hlPath, with: .color(Color(red: 0.55, green: 0.90, blue: 1.0).opacity(0.22)))
        var crestGC = ctx
        crestGC.addFilter(.blur(radius: 12))
        crestGC.fill(
            Path(ellipseIn: CGRect(x: crestX - 22, y: crestY - 8, width: 54, height: 22)),
            with: .color(Color.white.opacity(0.38)))
    }

    private func drawWaveCrestFoam(ctx: inout GraphicsContext) {
        let (crestX, crestY, _, _, _) = waveGeometry()
        for i in 0..<20 {
            let fi = Double(i)
            let fx = crestX - W * 0.12 + W * CGFloat(fi / 20.0) * 0.28
            let fy = crestY + H * 0.005 + CGFloat(sin(fi * 1.3 + t * 2.0)) * H * 0.008
            let fw = W * CGFloat(0.012 + (fi / 20.0) * 0.008)
            var arc = Path()
            arc.move(to: CGPoint(x: fx, y: fy))
            arc.addQuadCurve(to: CGPoint(x: fx + fw, y: fy),
                             control: CGPoint(x: fx + fw * 0.5, y: fy - H * 0.009))
            let foamOpacity = 0.45 + 0.30 * sin(fi * 0.7 + t * 1.5)
            ctx.stroke(arc, with: .color(.white.opacity(foamOpacity)), lineWidth: 1.8)
        }
    }

    private func drawCrestSpray(ctx: inout GraphicsContext) {
        let (crestX, crestY, _, _, _) = waveGeometry()
        guard power > 0.4 else { return }
        for i in 0..<20 {
            let fi = Double(i)
            let spawnX = crestX + CGFloat(i - 10) * 7
            let vx = CGFloat(fi - 10.0) * 1.8
            let vy = -CGFloat(38.0 + fi * 2.5)
            let age = CGFloat(fmod(t * 2.8 + fi * 0.38, 1.0))
            let px = spawnX + vx * age
            let py = crestY + vy * age + 0.5 * 75 * age * age
            let opacity = Double((1.0 - age) * CGFloat(power) * 0.9)
            guard opacity > 0.02 else { continue }
            let r = CGFloat(1.5 + age * 1.0)
            ctx.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(opacity)))
        }
    }

    private func drawWhitewater(ctx: inout GraphicsContext) {
        let (_, _, baseX, baseY, waveH) = waveGeometry()
        let foamH = H * 0.06
        var foamPath = Path()
        foamPath.move(to: CGPoint(x: baseX, y: baseY))
        foamPath.addQuadCurve(
            to: CGPoint(x: W * 0.56, y: baseY),
            control: CGPoint(x: W * 0.28, y: baseY - foamH))
        foamPath.addLine(to: CGPoint(x: W * 0.56, y: H))
        foamPath.addLine(to: CGPoint(x: baseX, y: H))
        foamPath.closeSubpath()
        ctx.fill(foamPath, with: .color(.white.opacity(0.14)))
        let seeds: [(Double, Double)] = [
            (0.07, 0.0), (0.14, 0.35), (0.22, 0.65), (0.30, 0.12),
            (0.38, 0.50), (0.11, 0.80), (0.26, 0.22), (0.45, 0.70)
        ]
        for (bxn, phase) in seeds {
            let animPhase = fmod(t * 0.85 + phase, 1.0)
            let bx = W * CGFloat(bxn) + W * 0.04 * CGFloat(animPhase)
            let by = baseY - H * 0.015 - CGFloat(animPhase) * foamH * 0.8
            let br = CGFloat(1.5 + phase * 2.0)
            let _ = waveH
            ctx.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
                     with: .color(.white.opacity(CGFloat(0.28 + animPhase * 0.22))))
        }
    }

    private func drawFoamStripes(ctx: inout GraphicsContext) {
        let (crestX, crestY, baseX, baseY, _) = waveGeometry()
        for i in 0..<5 {
            let fi = Double(i) / 5.0
            let animT = fmod(t * 0.55 + fi, 1.0)
            let startFrac = CGFloat(animT)
            let lx = baseX + (crestX - baseX) * startFrac * 0.88
            let ly = crestY + (baseY - crestY) * (1.0 - startFrac * 0.78)
            let endLX = lx + W * 0.055
            let endLY = ly - H * 0.018
            var foamLine = Path()
            foamLine.move(to: CGPoint(x: lx, y: ly))
            foamLine.addQuadCurve(
                to: CGPoint(x: endLX, y: endLY),
                control: CGPoint(x: lx + (endLX - lx) * 0.5, y: ly - H * 0.008))
            ctx.stroke(foamLine,
                       with: .color(.white.opacity(CGFloat(0.20 + fi * 0.12))),
                       lineWidth: CGFloat(1.4 + fi * 0.5))
        }
    }

    private func drawTubeScene(ctx: inout GraphicsContext) {
        let (crestX, crestY, baseX, baseY, _) = waveGeometry()
        let tubeX = baseX + (crestX - baseX) * 0.55
        let tubeY = crestY + (baseY - crestY) * 0.38
        let tubeW = W * 0.22
        let tubeH = H * 0.14
        var tubeMouth = Path()
        tubeMouth.addEllipse(in: CGRect(x: tubeX - tubeW * 0.5, y: tubeY - tubeH * 0.5,
                                         width: tubeW, height: tubeH))
        ctx.fill(tubeMouth, with: .color(Color(red: 0.01, green: 0.04, blue: 0.12).opacity(0.75)))
        ctx.stroke(tubeMouth, with: .color(.white.opacity(0.30)), lineWidth: 1.5)
        var tubeGC = ctx
        tubeGC.addFilter(.blur(radius: 16))
        tubeGC.fill(Path(ellipseIn: CGRect(x: tubeX + tubeW * 0.22, y: tubeY - tubeH * 0.28,
                                            width: tubeW * 0.30, height: tubeH * 0.55)),
                    with: .color(.white.opacity(0.55)))
        let wallPulse = CGFloat(abs(sin(t * 2.2))) * H * 0.018
        var wall = Path()
        wall.move(to: CGPoint(x: tubeX - tubeW * 0.5, y: tubeY - tubeH * 0.5))
        wall.addCurve(
            to: CGPoint(x: tubeX + tubeW * 0.5, y: tubeY - tubeH * 0.3 - wallPulse),
            control1: CGPoint(x: tubeX - tubeW * 0.1, y: tubeY - tubeH * 0.85 - wallPulse),
            control2: CGPoint(x: tubeX + tubeW * 0.3, y: tubeY - tubeH * 0.7 - wallPulse * 0.5))
        ctx.stroke(wall, with: .color(.white.opacity(0.35)), lineWidth: 2.5)
        ctx.draw(
            Text("x\(tubeMultiplier) TUBE")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.cyan.opacity(0.9)),
            at: CGPoint(x: tubeX, y: tubeY - tubeH * 0.8),
            anchor: .center)
    }

    private func drawSurfer(ctx: inout GraphicsContext) {
        let (crestX, crestY, baseX, baseY, _) = waveGeometry()
        let faceT: CGFloat = 0.42
        let sx = baseX + (crestX - baseX) * faceT * 0.80
        let sy = crestY + (baseY - crestY) * (1.0 - faceT * 0.72)
        let leanAngle = (balance - 0.5) * .pi / 5.5
        let isAerial = canvasPhase == .aerial
        let isTube = canvasPhase == .tube
        let isBottomTurn = !isTrickWindow && !isAerial && !isTube && power > 0.5
        let trickJump: Double
        switch canvasPhase {
        case .aerial:  trickJump = -abs(sin(t * 5.0)) * 30.0
        case .tube:    trickJump = 6.0
        default:       trickJump = isTrickWindow ? -abs(sin(t * 8.0)) * 14.0 : 0.0
        }
        var shadowGC = ctx
        shadowGC.translateBy(x: sx, y: sy + CGFloat(trickJump))
        shadowGC.addFilter(.blur(radius: 4))
        shadowGC.fill(Path(ellipseIn: CGRect(x: -18, y: 8, width: 36, height: 8)),
                      with: .color(.black.opacity(isAerial ? 0.10 : 0.32)))
        var gc = ctx
        gc.translateBy(x: sx, y: sy + CGFloat(trickJump))
        gc.rotate(by: .radians(leanAngle))
        gc.fill(Path(roundedRect: CGRect(x: -21, y: 4, width: 42, height: 7),
                     cornerRadius: CGSize(width: 3.5, height: 3.5)),
                with: .color(.white.opacity(0.92)))
        gc.fill(Path(roundedRect: CGRect(x: -21, y: 4, width: 42, height: 2),
                     cornerRadius: CGSize(width: 1, height: 1)),
                with: .color(jerseyColor.opacity(0.85)))
        var leash = Path()
        leash.move(to: CGPoint(x: -8, y: 4))
        leash.addQuadCurve(to: CGPoint(x: -21, y: 8),
                           control: CGPoint(x: -15, y: 12))
        gc.stroke(leash, with: .color(.white.opacity(0.40)), lineWidth: 0.8)
        let wetsuit = GraphicsContext.Shading.color(Color(red: 0.06, green: 0.14, blue: 0.32))
        let skin = GraphicsContext.Shading.color(Color(red: 0.88, green: 0.65, blue: 0.44))
        if isTube {
            var legs = Path()
            legs.move(to: CGPoint(x: -6, y: 4)); legs.addLine(to: CGPoint(x: -5, y: -1)); legs.addLine(to: CGPoint(x: -2, y: -4))
            legs.move(to: CGPoint(x: 6, y: 4)); legs.addLine(to: CGPoint(x: 5, y: -1)); legs.addLine(to: CGPoint(x: 2, y: -4))
            gc.stroke(legs, with: wetsuit, lineWidth: 3.0)
            var torso = Path(); torso.move(to: CGPoint(x: 0, y: -4)); torso.addLine(to: CGPoint(x: 0, y: -12))
            gc.stroke(torso, with: wetsuit, lineWidth: 3.0)
            var arms = Path(); arms.move(to: CGPoint(x: -18, y: -8)); arms.addLine(to: CGPoint(x: 0, y: -10)); arms.addLine(to: CGPoint(x: 10, y: -11))
            gc.stroke(arms, with: wetsuit, lineWidth: 2.5)
            gc.fill(Path(ellipseIn: CGRect(x: -4.5, y: -20, width: 9, height: 9)), with: skin)
        } else if isAerial {
            var legs = Path()
            legs.move(to: CGPoint(x: -7, y: 4)); legs.addLine(to: CGPoint(x: -9, y: -2)); legs.addLine(to: CGPoint(x: -6, y: -8))
            legs.move(to: CGPoint(x: 7, y: 4)); legs.addLine(to: CGPoint(x: 9, y: -2)); legs.addLine(to: CGPoint(x: 6, y: -8))
            gc.stroke(legs, with: wetsuit, lineWidth: 3.0)
            var torso = Path(); torso.move(to: CGPoint(x: 0, y: -8)); torso.addLine(to: CGPoint(x: 0, y: -18))
            gc.stroke(torso, with: wetsuit, lineWidth: 3.0)
            var arms = Path(); arms.move(to: CGPoint(x: -10, y: -14)); arms.addLine(to: CGPoint(x: 0, y: -13)); arms.addLine(to: CGPoint(x: 12, y: -8)); arms.addLine(to: CGPoint(x: 14, y: 2))
            gc.stroke(arms, with: wetsuit, lineWidth: 2.5)
            gc.fill(Path(ellipseIn: CGRect(x: -4.5, y: -26, width: 9, height: 9)), with: skin)
        } else if isBottomTurn {
            var legs = Path()
            legs.move(to: CGPoint(x: -7, y: 4)); legs.addLine(to: CGPoint(x: -5, y: -2)); legs.addLine(to: CGPoint(x: -3, y: -6))
            legs.move(to: CGPoint(x: 7, y: 4)); legs.addLine(to: CGPoint(x: 5, y: -2)); legs.addLine(to: CGPoint(x: 3, y: -6))
            gc.stroke(legs, with: wetsuit, lineWidth: 3.0)
            var torso = Path(); torso.move(to: CGPoint(x: 0, y: -6)); torso.addLine(to: CGPoint(x: 3, y: -14))
            gc.stroke(torso, with: wetsuit, lineWidth: 3.0)
            let armSpread: CGFloat = isTrickWindow ? 22 : 16
            var arms = Path(); arms.move(to: CGPoint(x: -armSpread, y: -11)); arms.addLine(to: CGPoint(x: 3, y: -10)); arms.addLine(to: CGPoint(x: armSpread, y: -9))
            gc.stroke(arms, with: wetsuit, lineWidth: 2.5)
            gc.fill(Path(ellipseIn: CGRect(x: -1.5, y: -22, width: 9, height: 9)), with: skin)
        } else {
            var legs = Path()
            legs.move(to: CGPoint(x: -7, y: 4)); legs.addLine(to: CGPoint(x: -4, y: -3)); legs.addLine(to: CGPoint(x: -1, y: -7))
            legs.move(to: CGPoint(x: 7, y: 4)); legs.addLine(to: CGPoint(x: 4, y: -3)); legs.addLine(to: CGPoint(x: 1, y: -7))
            gc.stroke(legs, with: wetsuit, lineWidth: 3.0)
            var torso = Path(); torso.move(to: CGPoint(x: 0, y: -7)); torso.addLine(to: CGPoint(x: 0, y: -17))
            gc.stroke(torso, with: wetsuit, lineWidth: 3.0)
            let armSpread: CGFloat = isTrickWindow ? 17 : 13
            var arms = Path(); arms.move(to: CGPoint(x: -armSpread, y: -13)); arms.addLine(to: CGPoint(x: 0, y: -12)); arms.addLine(to: CGPoint(x: armSpread, y: -13))
            gc.stroke(arms, with: wetsuit, lineWidth: 2.5)
            gc.fill(Path(ellipseIn: CGRect(x: -4.5, y: -25, width: 9, height: 9)), with: skin)
        }
        gc.fill(Path(ellipseIn: CGRect(x: -4, y: -17, width: 8, height: 8)),
                with: .color(jerseyColor.opacity(0.55)))
        if power > 0.35 {
            for si in 0..<5 {
                let sa = Double(si) * .pi / 4.0 - .pi * 0.1
                let sprayPhase = fmod(t * 2.5 + Double(si) * 0.4, 1.0)
                let sr = 8.0 + sprayPhase * 14.0
                let spx = CGFloat(cos(sa) * sr)
                let spy = CGFloat(sin(sa) * sr * 0.38) - CGFloat(sr) * 0.28 + 7
                let sdot = CGFloat(1.5 + sprayPhase * 1.5)
                gc.fill(Path(ellipseIn: CGRect(x: spx - sdot, y: spy - sdot,
                                               width: sdot * 2, height: sdot * 2)),
                        with: .color(.white.opacity(CGFloat(0.5 * power) * CGFloat(1.0 - sprayPhase))))
            }
        }
    }

    private func drawSeagulls(ctx: inout GraphicsContext) {
        for i in 0..<3 {
            let fi = Double(i)
            let bx = CGFloat(fmod(t * (22.0 + fi * 6.0) + fi * 80.0, Double(W) + 80.0)) - 40
            let by = H * CGFloat(0.10 + fi * 0.04) + CGFloat(sin(t * 0.6 + fi * 1.3)) * 6
            var bird = Path()
            bird.move(to: CGPoint(x: bx - 11, y: by + 4))
            bird.addLine(to: CGPoint(x: bx, y: by))
            bird.addLine(to: CGPoint(x: bx + 11, y: by + 4))
            ctx.stroke(bird, with: .color(.white.opacity(0.55)), lineWidth: 1.5)
        }
    }

    private func drawComboString(ctx: inout GraphicsContext) {
        let startX = W - W * 0.05
        for (idx, trick) in comboString.suffix(4).enumerated() {
            let bx = startX - CGFloat(idx) * W * 0.22
            let by = H * 0.92
            guard bx > 0 else { continue }
            var badge = Path()
            badge.addRoundedRect(in: CGRect(x: bx - W * 0.10, y: by - 9,
                                            width: W * 0.20, height: 18),
                                  cornerSize: CGSize(width: 5, height: 5))
            ctx.fill(badge, with: .color(Color.yellow.opacity(0.18)))
            ctx.stroke(badge, with: .color(Color.yellow.opacity(0.45)), lineWidth: 1)
            ctx.draw(
                Text(trick)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.yellow.opacity(0.85)),
                at: CGPoint(x: bx, y: by),
                anchor: .center)
        }
    }

    private func drawTrickGlow(ctx: inout GraphicsContext) {
        let pulse = CGFloat(abs(sin(t * 5.5)))
        var glowGC = ctx
        glowGC.addFilter(.blur(radius: 30))
        glowGC.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                    with: .color(Color.yellow.opacity(0.18 + Double(pulse) * 0.18)))
        ctx.draw(
            Text("TRICK WINDOW")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color.yellow.opacity(0.55 + Double(pulse) * 0.35)),
            at: CGPoint(x: W * 0.5, y: H * 0.07),
            anchor: .center)
    }
}

// MARK: - Surfing Wave Canvas

private struct SurfingWaveCanvas: View {
    let balance: Double
    let power: Double
    let isTrickWindow: Bool
    var canvasPhase: SurfCanvasPhase = .normal
    var comboString: [String] = []
    var tubeMultiplier: Int = 1
    var jerseyColor: Color = Color(red: 0.2, green: 0.75, blue: 1.0)

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var drawer = SurfWaveDrawer(
                    W: size.width, H: size.height,
                    balance: balance, power: power,
                    isTrickWindow: isTrickWindow, t: t,
                    canvasPhase: canvasPhase,
                    comboString: comboString,
                    tubeMultiplier: tubeMultiplier,
                    jerseyColor: jerseyColor)
                drawer.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Paddle Ocean Drawer

private struct PaddleOceanDrawer {
    let W: CGFloat
    let H: CGFloat
    let paddleProgress: Double
    let t: Double

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawOcean(ctx: &ctx)
        drawIncomingWave(ctx: &ctx)
        drawPaddler(ctx: &ctx)
    }

    private func drawSky(ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.40)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.02, green: 0.06, blue: 0.20),
                        Color(red: 0.04, green: 0.22, blue: 0.40)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: H * 0.40)))
    }

    private func drawOcean(ctx: inout GraphicsContext) {
        let horizonY = H * 0.40
        ctx.fill(Path(CGRect(x: 0, y: horizonY, width: W, height: H - horizonY)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.04, green: 0.18, blue: 0.35),
                        Color(red: 0.01, green: 0.08, blue: 0.18)
                    ]),
                    startPoint: CGPoint(x: 0, y: horizonY),
                    endPoint: CGPoint(x: 0, y: H)))
        for i in 0..<4 {
            let fi = Double(i)
            let wavePhase = fmod(t * 0.5 + fi * 0.8, 1.0)
            let wy = H * CGFloat(0.46 + fi * 0.11)
            let wOffset = W * CGFloat(wavePhase) * 0.5 - W * 0.2
            var waveLine = Path()
            let step = W * 0.07
            var xPos = wOffset
            waveLine.move(to: CGPoint(x: xPos, y: wy))
            while xPos < wOffset + W * 1.3 {
                xPos += step
                let sinPhase = Double((xPos - wOffset) / (W * 0.14)) * .pi
                let yOff = CGFloat(sin(sinPhase)) * H * 0.014
                waveLine.addLine(to: CGPoint(x: xPos, y: wy + yOff))
            }
            ctx.stroke(waveLine,
                       with: .color(Color(red: 0.20, green: 0.50, blue: 0.70).opacity(0.28 - fi * 0.04)),
                       lineWidth: 1.2)
        }
    }

    private func drawIncomingWave(ctx: inout GraphicsContext) {
        let swellSize = CGFloat(paddleProgress) * H * 0.30
        let swellX = W * CGFloat(1.0 - paddleProgress * 0.65)
        let swellY = H * 0.50
        guard swellSize > 5 else { return }
        var swellPath = Path()
        swellPath.move(to: CGPoint(x: swellX, y: swellY + swellSize * 0.3))
        swellPath.addCurve(
            to: CGPoint(x: swellX + W * 0.25, y: swellY),
            control1: CGPoint(x: swellX + W * 0.06, y: swellY - swellSize),
            control2: CGPoint(x: swellX + W * 0.18, y: swellY - swellSize * 0.5))
        swellPath.addLine(to: CGPoint(x: W, y: swellY))
        swellPath.addLine(to: CGPoint(x: W, y: H))
        swellPath.addLine(to: CGPoint(x: swellX, y: H))
        swellPath.closeSubpath()
        ctx.fill(swellPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.06, green: 0.42, blue: 0.68).opacity(0.85),
                Color(red: 0.02, green: 0.12, blue: 0.28)
            ]),
            startPoint: CGPoint(x: swellX + W * 0.1, y: swellY - swellSize),
            endPoint: CGPoint(x: swellX + W * 0.1, y: H)))
    }

    private func drawPaddler(ctx: inout GraphicsContext) {
        let px = W * 0.32
        let py = H * 0.62
        let armCycle = fmod(t * 1.8, 2.0 * .pi)
        var gc = ctx
        gc.translateBy(x: px, y: py)
        gc.fill(Path(roundedRect: CGRect(x: -30, y: -4, width: 60, height: 8),
                     cornerRadius: CGSize(width: 4, height: 4)),
                with: .color(.white.opacity(0.90)))
        gc.fill(Path(roundedRect: CGRect(x: -30, y: -4, width: 60, height: 2),
                     cornerRadius: CGSize(width: 1, height: 1)),
                with: .color(Color(red: 0.20, green: 0.75, blue: 1.0).opacity(0.80)))
        let bodyColor = GraphicsContext.Shading.color(Color(red: 0.06, green: 0.14, blue: 0.32))
        let skinColor = GraphicsContext.Shading.color(Color(red: 0.88, green: 0.65, blue: 0.44))
        var body = Path(); body.move(to: CGPoint(x: -20, y: -2)); body.addLine(to: CGPoint(x: 18, y: -2))
        gc.stroke(body, with: bodyColor, lineWidth: 5)
        gc.fill(Path(ellipseIn: CGRect(x: 14, y: -6, width: 10, height: 10)), with: skinColor)
        let leftPhase = armCycle - 0.8
        let rightPhase = armCycle + .pi - 0.8
        var leftArm = Path()
        leftArm.move(to: CGPoint(x: -5, y: -2))
        leftArm.addLine(to: CGPoint(x: -5 + CGFloat(cos(leftPhase)) * 18, y: CGFloat(sin(leftPhase)) * 12 - 2))
        gc.stroke(leftArm, with: bodyColor, lineWidth: 2.5)
        var rightArm = Path()
        rightArm.move(to: CGPoint(x: 8, y: -2))
        rightArm.addLine(to: CGPoint(x: 8 + CGFloat(cos(rightPhase)) * 18, y: CGFloat(sin(rightPhase)) * 12 - 2))
        gc.stroke(rightArm, with: bodyColor, lineWidth: 2.5)
        let splashOp = 0.22 + 0.14 * abs(sin(armCycle))
        gc.fill(Path(ellipseIn: CGRect(x: -14, y: 2, width: 10, height: 4)), with: .color(.white.opacity(splashOp)))
        gc.fill(Path(ellipseIn: CGRect(x: 8, y: 2, width: 10, height: 4)), with: .color(.white.opacity(splashOp)))
    }
}

// MARK: - Paddle Ocean Canvas

private struct PaddleOceanCanvas: View {
    let paddleProgress: Double

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var drawer = PaddleOceanDrawer(
                    W: size.width, H: size.height,
                    paddleProgress: paddleProgress, t: t)
                drawer.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - SurfingGameView

struct SurfingGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: SurfingPhase = .lobby
    @State private var surfMode: SurfMode = .competition
    @State private var waveNumber: Int = 1

    @State private var wavePower: Double = 0.0
    @State private var balanceMeter: Double = 0.5
    @State private var balanceOffCenterTime: Double = 0
    @State private var wipeoutTriggered: Bool = false

    @State private var trickWindowOpen: Bool = false
    @State private var trickWindowTimeLeft: Double = 4.0
    @State private var performedTrick: SurfTrick? = nil
    @State private var showTrickFlash: Bool = false
    @State private var trickFlashText: String = ""

    @State private var heatClock: Double = 20.0
    @State private var waveTimer: Task<Void, Never>?
    @State private var balanceDriftTimer: Task<Void, Never>?
    @State private var wavePowerTimer: Task<Void, Never>?
    @State private var barrelTimer: Task<Void, Never>?
    @State private var endlessWaveTask: Task<Void, Never>?

    @State private var waveScores: [WaveScore] = []
    @State private var currentWaveScore: Double = 0
    @State private var currentBalanceMultiplier: Double = 1.0
    @State private var trickAccumulator: Int = 0

    @State private var frozenAIScore: Double = 0
    @State private var rewardApplied: Bool = false
    @State private var paddleProgress: Double = 0.0

    @State private var currentCanvasPhase: SurfCanvasPhase = .normal
    @State private var comboTricks: [String] = []
    @State private var tubeMultiplier: Int = 1
    @State private var wasInPerfectBalance: Bool = false
    @State private var judgeScores: [Double] = []
    @State private var showJudgePanel: Bool = false

    @State private var currentWaveType: SurfWaveType = .solid
    @State private var showWaveTypeBanner: Bool = false
    @State private var barrelHoldTime: Double = 0
    @State private var barrelSuccess: Bool = false
    @State private var showBarrelBonus: Bool = false
    @State private var duckDiveCompleted: Bool = false
    @State private var wipeoutCount: Int = 0
    @State private var endlessWaveCount: Int = 0
    @State private var sessionBestWave: Int = 0
    @State private var totalScore: Int = 0
    @State private var endlessWaveInterval: Double = 10.0

    private let accentColor = Color(red: 0.2, green: 0.75, blue: 1.0)
    private let totalWaves = 3
    private let maxWipeouts = 10

    private var personalBest: Int { UserDefaults.standard.integer(forKey: "surfing_endless_pb") }
    private func setPersonalBest(_ value: Int) { UserDefaults.standard.set(value, forKey: "surfing_endless_pb") }

    private var heat1Score: Double {
        waveScores.sorted { $0.finalScore > $1.finalScore }.prefix(2).reduce(0) { $0 + $1.finalScore }
    }
    private var playerWins: Bool { heat1Score > frozenAIScore }
    private var isDraw: Bool { Int(heat1Score) == Int(frozenAIScore) }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(colors: [Color(red: 0.01, green: 0.06, blue: 0.20), Theme.deepBlack],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            switch phase {
            case .lobby:          lobbyBody
            case .ready:
                GetReadyScreen(
                    title: "Surfing",
                    subtitle: surfMode == .competition ? "3 waves - Best 2 of 3 - Balance + Trick" : "Endless waves - 10 wipeouts ends session",
                    countdown: 3, accentColor: accentColor,
                    onComplete: {
                        if surfMode == .competition { frozenAIScore = Double(Int.random(in: 22...42)) }
                        startPaddleIn()
                    })
            case .paddleIn:       paddleInBody
            case .riding, .trickWindow: ridingBody
            case .barrelRide:     barrelRideBody
            case .duckDive:       duckDiveBody
            case .wipeout:        wipeoutBody
            case .waveResult:     waveResultBody
            case .heatResult:     heatResultBody
            case .sessionSummary: sessionSummaryBody
            case .result:
                ResultScreen(
                    winner: playerWins ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: Int(heat1Score), p2Score: Int(frozenAIScore),
                    title: "Surfing", accentColor: accentColor,
                    prqGain: playerWins ? 14 : (isDraw ? 5 : 3),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "Wave Score", modeAttributeValue: min(1.0, heat1Score / 40.0),
                    onReturn: { dismiss() })
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { cancelAllTimers(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { cancelAllTimers() }
    }

    // MARK: - Lobby

    private var lobbyBody: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 6) {
                Text("SURFING").font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor).tracking(5)
                Text("Choose Mode").font(.system(size: 30, weight: .black)).foregroundStyle(.white)
            }
            VStack(spacing: 16) {
                Button {
                    surfMode = .competition; phase = .ready
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "flag.checkered.2.crossed").font(.system(size: 22, weight: .bold)).foregroundStyle(accentColor)
                            Text("COMPETITION vs RIVAL").font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(accentColor.opacity(0.6))
                        }
                        Text("3 waves - Best 2 count - Beat the AI scorer")
                            .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(accentColor.opacity(0.30), lineWidth: 1)))
                }.buttonStyle(.plain)

                Button {
                    surfMode = .endless
                    wipeoutCount = 0; endlessWaveCount = 0; sessionBestWave = 0; totalScore = 0
                    phase = .ready
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "infinity.circle.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.yellow)
                            Text("ENDLESS WAVES").font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.yellow.opacity(0.6))
                        }
                        Text("Waves every 8-12s - Survive 10 wipeouts - Chase PB")
                            .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                        Label("PB: \(personalBest) pts", systemImage: "trophy.fill")
                            .font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.yellow.opacity(0.8))
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.yellow.opacity(0.30), lineWidth: 1)))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    // MARK: - Paddle In

    private var paddleInBody: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(surfMode == .endless ? "WAVE \(endlessWaveCount + 1)" : "WAVE \(waveNumber)")
                .font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(4)
            Text("PADDLING OUT").font(.system(size: 28, weight: .black)).italic().foregroundStyle(.white)
            PaddleOceanCanvas(paddleProgress: paddleProgress)
                .frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(accentColor.opacity(0.20), lineWidth: 1))
                .padding(.horizontal, 20)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)).frame(height: 14)
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Theme.brandCyan, accentColor], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, CGFloat(paddleProgress) * (UIScreen.main.bounds.width - 80)), height: 14)
                    .animation(.easeInOut(duration: 0.1), value: paddleProgress)
            }.padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Riding Body

    private var ridingBody: some View {
        VStack(spacing: 0) {
            ridingHUD.padding(.horizontal, 20).padding(.top, 8)
            Spacer()
            ZStack(alignment: .topLeading) {
                Group {
                    if phase == .trickWindow { trickWindowPanel } else { ridingStatusPanel }
                }
                wavePowerMeter.padding(.leading, 16).padding(.top, 10)
            }.padding(.horizontal, 16)
            if showWaveTypeBanner {
                HStack(spacing: 8) {
                    Text(currentWaveType.label).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(currentWaveType.color)
                    Text(currentWaveType.description).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(currentWaveType.color.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(currentWaveType.color.opacity(0.35), lineWidth: 1)))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
            balanceIndicator.padding(.top, 4)
            balanceControlRow.padding(.horizontal, 24).padding(.bottom, 32).padding(.top, 14)
        }
        .overlay(trickFlashOverlay)
        .gesture(DragGesture(minimumDistance: 22).onEnded { val in
            if phase == .trickWindow { handleTrickSwipe(val.translation) }
        })
    }

    // MARK: - Barrel Ride Body

    private var barrelRideBody: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("BARREL RIDE!").font(.system(size: 32, weight: .black)).italic()
                .foregroundStyle(.yellow).shadow(color: .yellow.opacity(0.5), radius: 20)
            Text("Hold center within 0.15 for 3 seconds")
                .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 6).frame(width: 100, height: 100)
                Circle().trim(from: 0, to: CGFloat(barrelHoldTime / 3.0))
                    .stroke(barrelHoldTime >= 3.0 ? Color.green : Color.yellow,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: barrelHoldTime)
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", barrelHoldTime))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(barrelHoldTime >= 3.0 ? .green : .yellow)
                    Text("/ 3.0s").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                }
            }
            balanceIndicator.padding(.top, 4)
            balanceControlRow.padding(.horizontal, 24).padding(.bottom, 32).padding(.top, 8)
            Spacer()
        }
        .overlay(
            Group {
                if showBarrelBonus {
                    VStack(spacing: 4) {
                        Text("BARREL MADE!").font(.system(size: 38, weight: .black, design: .monospaced))
                            .foregroundStyle(.yellow).shadow(color: .yellow.opacity(0.8), radius: 24)
                        Text("x2.2 BONUS!").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(.yellow.opacity(0.8))
                    }
                    .allowsHitTesting(false).transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.5), value: showBarrelBonus)
        )
    }

    // MARK: - Duck Dive Body

    private var duckDiveBody: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(Color.orange.opacity(0.12)).frame(width: 110, height: 110)
                Image(systemName: "arrow.down.to.line.circle.fill").font(.system(size: 52, weight: .bold)).foregroundStyle(.orange)
            }
            Text("CLOSEOUT!").font(.system(size: 34, weight: .black)).italic()
                .foregroundStyle(.orange).shadow(color: .orange.opacity(0.4), radius: 20)
            Text("Duck dive — wave passes safely")
                .font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
            Button { completeDuckDive() } label: {
                Text("DUCK DIVE!").font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.black).padding(.horizontal, 40).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange))
            }.buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Riding HUD

    private var ridingHUD: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                if surfMode == .endless {
                    Text("WAVE \(endlessWaveCount + 1)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(1)
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundStyle(.red)
                        Text("\(wipeoutCount)/\(maxWipeouts)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.red)
                    }
                } else {
                    Text("WAVE \(waveNumber) / \(totalWaves)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(1)
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 3).frame(width: 46, height: 46)
                        Circle().trim(from: 0, to: CGFloat(heatClock / 20.0))
                            .stroke(heatClock > 8 ? accentColor : .red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 46, height: 46).rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: heatClock)
                        Text(String(format: "%.0f", heatClock)).font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(heatClock > 8 ? .white : .red)
                    }
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text("WAVE SCORE").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                Text(String(format: "%.1f", currentWaveScore)).font(.system(size: 28, weight: .black, design: .monospaced)).foregroundStyle(.white).contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if surfMode == .endless {
                    Text("TOTAL").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                    Text("\(totalScore)").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(.yellow).contentTransition(.numericText())
                    Text("BEST \(sessionBestWave)").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(1)
                } else {
                    Text("HEAT TOTAL").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                    Text(String(format: "%.1f", heat1Score)).font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(accentColor).contentTransition(.numericText())
                    HStack(spacing: 3) {
                        ForEach(0..<totalWaves, id: \.self) { i in
                            let ws = i < waveScores.count ? waveScores[i] : nil
                            Circle().fill(ws == nil ? (i == waveNumber - 1 ? accentColor.opacity(0.5) : Color.white.opacity(0.1)) : (ws!.wipeout ? .red : accentColor)).frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1)))
    }

    // MARK: - Wave Power Meter

    private var wavePowerMeter: some View {
        VStack(spacing: 6) {
            Text("WAVE").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).tracking(1)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.45)).frame(width: 22, height: 140)
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: wavePower > 0.8 ? [.yellow, accentColor] : [accentColor.opacity(0.5), accentColor], startPoint: .bottom, endPoint: .top))
                    .frame(width: 22, height: max(4, 140 * CGFloat(wavePower))).animation(.linear(duration: 0.1), value: wavePower)
            }.overlay(RoundedRectangle(cornerRadius: 6).stroke(accentColor.opacity(0.3), lineWidth: 1))
            Text("\(Int(wavePower * 100))%").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(wavePower > 0.8 ? .yellow : accentColor)
        }
    }

    // MARK: - Riding Status Panel

    private var ridingStatusPanel: some View {
        ZStack {
            SurfingWaveCanvas(balance: balanceMeter, power: wavePower, isTrickWindow: false,
                              canvasPhase: currentCanvasPhase, comboString: comboTricks, tubeMultiplier: tubeMultiplier)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            Color.black.opacity(0.16).clipShape(RoundedRectangle(cornerRadius: 20))
            VStack(spacing: 10) {
                Spacer()
                Text("RIDING THE WAVE").font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor).tracking(3).shadow(color: accentColor.opacity(0.7), radius: 10)
                if wavePower > 0.75 {
                    Text("TRICK WINDOW OPENING").font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow).tracking(2).shadow(color: .yellow.opacity(0.6), radius: 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
                Spacer()
            }.padding(20)
            RoundedRectangle(cornerRadius: 20).stroke(accentColor.opacity(0.25), lineWidth: 1)
        }.frame(height: 200)
    }

    // MARK: - Trick Window Panel

    private var trickWindowPanel: some View {
        ZStack {
            SurfingWaveCanvas(balance: balanceMeter, power: wavePower, isTrickWindow: true,
                              canvasPhase: currentCanvasPhase, comboString: comboTricks, tubeMultiplier: tubeMultiplier)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            Color.black.opacity(0.52).clipShape(RoundedRectangle(cornerRadius: 20))
            VStack(spacing: 12) {
                ZStack {
                    Circle().trim(from: 0, to: CGFloat(trickWindowTimeLeft / 4.0))
                        .stroke(trickWindowTimeLeft > 2 ? Color.yellow : Color.orange,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60).rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: trickWindowTimeLeft)
                    Text(String(format: "%.1f", trickWindowTimeLeft)).font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(.yellow)
                }
                Text("TRICK WINDOW!").font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow).tracking(3).shadow(color: .yellow.opacity(0.5), radius: 10)
                VStack(spacing: 5) {
                    ForEach(SurfTrick.allCases, id: \.self) { trick in
                        HStack(spacing: 10) {
                            Image(systemName: trick.systemImage).font(.system(size: 13, weight: .bold)).foregroundStyle(accentColor).frame(width: 20)
                            Text("\(trick.swipeHint) - \(trick.rawValue)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("+\(trick.points) pts").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.yellow)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.22), lineWidth: 1)))
            }.padding(14)
            RoundedRectangle(cornerRadius: 20).stroke(Color.yellow.opacity(0.40), lineWidth: 1)
        }.frame(height: 200)
    }

    // MARK: - Balance Indicator

    private var balanceIndicator: some View {
        VStack(spacing: 8) {
            Text("BALANCE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)).frame(width: 200, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                HStack {
                    Rectangle().fill(Color.red.opacity(0.15)).frame(width: 30, height: 18).cornerRadius(6)
                    Spacer()
                    Rectangle().fill(Color.red.opacity(0.15)).frame(width: 30, height: 18).cornerRadius(6)
                }.frame(width: 200)
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 2, height: 18)
                if phase == .barrelRide {
                    RoundedRectangle(cornerRadius: 3).fill(Color.yellow.opacity(0.25)).frame(width: 54, height: 18)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                }
                Circle().fill(balanceMeter < 0.2 || balanceMeter > 0.8 ? Color.red : (abs(balanceMeter - 0.5) < 0.1 ? Theme.foundationGreen : accentColor))
                    .frame(width: 20, height: 20)
                    .shadow(color: (abs(balanceMeter - 0.5) < 0.1 ? Theme.foundationGreen : accentColor).opacity(0.5), radius: 8)
                    .offset(x: (CGFloat(balanceMeter) - 0.5) * 180)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: balanceMeter)
            }.frame(width: 200)
            if phase == .barrelRide {
                Text(abs(balanceMeter - 0.5) < 0.15 ? "IN THE BARREL!" : "CENTER UP!")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(abs(balanceMeter - 0.5) < 0.15 ? .yellow : .orange).tracking(1)
            } else if balanceMeter < 0.2 || balanceMeter > 0.8 {
                Text("LEAN BACK TO CENTER!").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.red).tracking(1)
            } else if abs(balanceMeter - 0.5) < 0.1 {
                Text("PERFECT BALANCE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(Theme.foundationGreen).tracking(1)
            }
        }
    }

    // MARK: - Balance Controls

    private var balanceControlRow: some View {
        HStack(spacing: 16) {
            Button { adjustBalance(delta: -0.12) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1)).frame(height: 72)
                    VStack(spacing: 5) {
                        Image(systemName: "arrow.left.circle.fill").font(.system(size: 26, weight: .bold))
                        Text("LEAN LEFT").font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1)
                    }.foregroundStyle(accentColor)
                }
            }.buttonStyle(.plain)
            Button { adjustBalance(delta: 0.12) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1)).frame(height: 72)
                    VStack(spacing: 5) {
                        Image(systemName: "arrow.right.circle.fill").font(.system(size: 26, weight: .bold))
                        Text("LEAN RIGHT").font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1)
                    }.foregroundStyle(accentColor)
                }
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Trick Flash Overlay

    private var trickFlashOverlay: some View {
        Group {
            if showTrickFlash {
                VStack(spacing: 4) {
                    Text(trickFlashText).font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow).shadow(color: .yellow.opacity(0.7), radius: 20)
                    Text("TRICK SCORED!").font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.7)).tracking(3)
                }
                .allowsHitTesting(false).transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }.animation(.spring(response: 0.22, dampingFraction: 0.5), value: showTrickFlash)
    }

    // MARK: - Wipeout Body

    private var wipeoutBody: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(Color.red.opacity(0.1)).frame(width: 110, height: 110)
                Image(systemName: "water.waves.slash").font(.system(size: 52, weight: .bold)).foregroundStyle(.red)
            }
            Text("WIPEOUT!").font(.system(size: 38, weight: .black)).italic().foregroundStyle(.red).shadow(color: .red.opacity(0.4), radius: 20)
            if surfMode == .endless {
                Text("\(wipeoutCount) of \(maxWipeouts) wipeouts used")
                    .font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
            } else {
                Text("Lost balance for too long").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                Text("WAVE \(waveNumber) - 0.0 pts").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(.red).tracking(2)
            }
            Spacer()
        }
    }

    // MARK: - Wave Result Body

    private var waveResultBody: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(surfMode == .endless ? "WAVE \(endlessWaveCount) COMPLETE" : "WAVE \(waveNumber) COMPLETE")
                .font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(3)
            ZStack {
                Circle().fill(accentColor.opacity(0.1)).frame(width: 110, height: 110)
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 28, weight: .bold)).foregroundStyle(.yellow)
                    Text(String(format: "%.1f", waveScores.last?.finalScore ?? 0))
                        .font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(.white)
                }
            }
            if showJudgePanel && !judgeScores.isEmpty {
                HStack(spacing: 12) {
                    ForEach(judgeScores.indices, id: \.self) { idx in
                        VStack(spacing: 4) {
                            Text("JUDGE \(idx + 1)").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                            Text(String(format: "%.1f", judgeScores[idx])).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(.yellow).contentTransition(.numericText())
                        }
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.28), lineWidth: 1)))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.6).delay(Double(idx) * 0.28), value: showJudgePanel)
                    }
                }
            }
            VStack(spacing: 10) {
                if let ws = waveScores.last {
                    scoreRow(label: "TRICK POINTS", value: String(format: "%.0f", Double(trickAccumulator)))
                    scoreRow(label: "BALANCE MULTIPLIER", value: String(format: "x%.2f", currentBalanceMultiplier))
                    if surfMode == .endless {
                        scoreRow(label: "WAVE TYPE BONUS", value: "x\(String(format: "%.1f", currentWaveType.pointMultiplier))")
                    }
                    Divider().background(Theme.cardBorder)
                    scoreRow(label: "WAVE SCORE", value: String(format: "%.1f", ws.finalScore), highlight: true)
                }
                if surfMode == .endless {
                    scoreRow(label: "SESSION TOTAL", value: "\(totalScore)")
                    scoreRow(label: "BEST WAVE", value: "\(sessionBestWave)")
                } else {
                    scoreRow(label: "HEAT RUNNING TOTAL", value: String(format: "%.1f", heat1Score))
                    if waveNumber < totalWaves { scoreRow(label: "WAVES REMAINING", value: "\(totalWaves - waveNumber)") }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1)))
            .padding(.horizontal, 28)
            if surfMode == .competition {
                HStack(spacing: 10) {
                    ForEach(waveScores) { ws in
                        VStack(spacing: 3) {
                            Circle().fill(ws.wipeout ? Color.red : accentColor).frame(width: 14, height: 14)
                            Text(ws.wipeout ? "W/O" : String(format: "%.1f", ws.finalScore))
                                .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(ws.wipeout ? .red : .white)
                        }
                    }
                    if waveScores.count < totalWaves {
                        ForEach(waveScores.count..<totalWaves, id: \.self) { _ in
                            Circle().fill(Color.white.opacity(0.1)).frame(width: 14, height: 14)
                        }
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Heat Result Body

    private var heatResultBody: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("HEAT FINAL").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(3)
            VStack(spacing: 8) {
                ForEach(waveScores) { ws in
                    HStack {
                        Text("WAVE \(ws.waveNumber)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        if ws.wipeout {
                            Text("WIPEOUT").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.red)
                        } else {
                            Text(String(format: "%.1f", ws.finalScore)).font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1)))
                }
                Divider().background(Theme.cardBorder).padding(.vertical, 4)
                HStack {
                    Text("BEST 2 OF 3").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                    Spacer()
                    Text(String(format: "%.1f", heat1Score)).font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(.white)
                }.padding(.horizontal, 4)
                HStack {
                    Text("AI SCORE").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                    Spacer()
                    Text(String(format: "%.1f", frozenAIScore)).font(.system(size: 20, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }.padding(.horizontal, 4)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1)))
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    // MARK: - Session Summary Body

    private var sessionSummaryBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("SESSION COMPLETE").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(4)
                    Text("Endless Waves").font(.system(size: 28, weight: .black)).foregroundStyle(.white)
                }.padding(.top, 32)
                VStack(spacing: 14) {
                    HStack {
                        statBlock(label: "TOTAL SCORE", value: "\(totalScore)", color: .yellow)
                        Spacer()
                        statBlock(label: "WAVES SURFED", value: "\(endlessWaveCount)", color: accentColor)
                        Spacer()
                        statBlock(label: "BEST WAVE", value: "\(sessionBestWave)", color: Theme.foundationGreen)
                    }
                    Divider().background(Theme.cardBorder)
                    HStack {
                        statBlock(label: "WIPEOUTS", value: "\(wipeoutCount)", color: .red)
                        Spacer()
                        statBlock(label: "PERSONAL BEST", value: "\(personalBest)", color: .yellow)
                        Spacer()
                        statBlock(label: "PB STATUS", value: totalScore >= personalBest && personalBest > 0 && totalScore == personalBest ? "MATCHED" : (totalScore > personalBest ? "NEW!" : "-"), color: totalScore > personalBest ? .green : .white.opacity(0.4))
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1)))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("LEADERBOARD").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(3)
                    let mockEntries = buildLeaderboard()
                    ForEach(mockEntries.indices, id: \.self) { idx in
                        let entry = mockEntries[idx]
                        HStack(spacing: 12) {
                            Text("#\(idx + 1)").font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(idx == 0 ? .yellow : .white.opacity(0.5)).frame(width: 30, alignment: .leading)
                            Text(entry.name).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(entry.isPlayer ? accentColor : .white)
                            Spacer()
                            Text("\(entry.score)").font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(entry.isPlayer ? accentColor : .white)
                            if entry.isPlayer { Image(systemName: "person.fill").font(.system(size: 10)).foregroundStyle(accentColor) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(entry.isPlayer ? accentColor.opacity(0.10) : Theme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(entry.isPlayer ? accentColor.opacity(0.30) : Theme.cardBorder, lineWidth: 1)))
                    }
                }.padding(.horizontal, 20)

                Button { phase = .lobby } label: {
                    Text("BACK TO LOBBY").font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 16).fill(accentColor))
                }.buttonStyle(.plain).padding(.horizontal, 24).padding(.bottom, 40)
            }
        }
    }

    // MARK: - Helpers

    private func scoreRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
            Spacer()
            Text(value).font(.system(size: highlight ? 20 : 14, weight: .black, design: .monospaced)).foregroundStyle(highlight ? accentColor : .white)
        }
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
        }
    }

    private struct LeaderboardEntry { let name: String; let score: Int; let isPlayer: Bool }

    private func buildLeaderboard() -> [LeaderboardEntry] {
        let names = ["Kai Nexus", "Sol Rivera", "Mara Blue", "Jay Crest"]
        let scores = names.map { _ in Int.random(in: max(10, totalScore - 60)...max(totalScore + 80, 100)) }
        var entries = zip(names, scores).map { LeaderboardEntry(name: $0.0, score: $0.1, isPlayer: false) }
        entries.append(LeaderboardEntry(name: "YOU", score: totalScore, isPlayer: true))
        return Array(entries.sorted { $0.score > $1.score }.prefix(5))
    }

    // MARK: - Logic

    private func startPaddleIn() {
        phase = .paddleIn
        paddleProgress = 0
        Task {
            for i in 0..<20 {
                try? await Task.sleep(for: .milliseconds(80))
                await MainActor.run { paddleProgress = Double(i + 1) / 20.0 }
            }
            await MainActor.run { beginWave() }
        }
    }

    private func beginWave() {
        currentWaveType = surfMode == .endless ? SurfWaveType.random() : .solid
        if surfMode == .endless && currentWaveType == .closeout {
            phase = .duckDive; return
        }
        wavePower = 0; balanceMeter = 0.5; balanceOffCenterTime = 0; wipeoutTriggered = false
        heatClock = 20.0; currentWaveScore = 0; currentBalanceMultiplier = 1.0; trickAccumulator = 0
        trickWindowOpen = false; performedTrick = nil; comboTricks = []; tubeMultiplier = 1
        currentCanvasPhase = .normal; wasInPerfectBalance = false; judgeScores = []; showJudgePanel = false
        barrelHoldTime = 0; barrelSuccess = false; showBarrelBonus = false; duckDiveCompleted = false
        if surfMode == .endless {
            withAnimation { showWaveTypeBanner = true }
            Task {
                try? await Task.sleep(for: .milliseconds(2200))
                await MainActor.run { withAnimation { showWaveTypeBanner = false } }
            }
        }
        if surfMode == .endless && currentWaveType == .barrel {
            phase = .barrelRide
            startBarrelChallenge()
            startBalanceDrift()
            return
        }
        phase = .riding
        startWavePowerTimer()
        startHeatClock()
        startBalanceDrift()
    }

    private func startWavePowerTimer() {
        wavePowerTimer?.cancel()
        wavePowerTimer = Task {
            for i in 0..<80 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    wavePower = min(1.0, Double(i + 1) / 80.0)
                    if wavePower >= 0.8 && !trickWindowOpen && !wipeoutTriggered { openTrickWindow() }
                }
            }
        }
    }

    private func startHeatClock() {
        waveTimer?.cancel()
        waveTimer = Task {
            for i in 0..<200 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    heatClock = max(0, 20.0 - Double(i + 1) * 0.1)
                    if heatClock <= 0 { endWave(wipeout: false) }
                }
            }
        }
    }

    private func startBalanceDrift() {
        balanceDriftTimer?.cancel()
        balanceDriftTimer = Task {
            while true {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(150))
                await MainActor.run {
                    guard phase == .riding || phase == .trickWindow || phase == .barrelRide else { return }
                    let drift = Double.random(in: -0.04...0.04)
                    balanceMeter = max(0, min(1, balanceMeter + drift))
                    let dist = abs(balanceMeter - 0.5)
                    currentBalanceMultiplier = dist < 0.1 ? 1.5 : (dist < 0.25 ? 1.0 : 0.5)
                    let isNowPerfect = dist < 0.1
                    if isNowPerfect && !wasInPerfectBalance { hapticImpact(.soft) }
                    wasInPerfectBalance = isNowPerfect
                    if phase == .barrelRide {
                        if dist < 0.15 {
                            barrelHoldTime += 0.15
                            if barrelHoldTime >= 3.0 && !barrelSuccess { barrelSuccess = true; completeBarrel() }
                        } else if dist > 0.35 && !wipeoutTriggered {
                            wipeoutTriggered = true; endWave(wipeout: true)
                        }
                        return
                    }
                    if balanceMeter < 0.12 || balanceMeter > 0.88 {
                        balanceOffCenterTime += 0.15
                        if balanceOffCenterTime >= 2.0 && !wipeoutTriggered { wipeoutTriggered = true; endWave(wipeout: true) }
                    } else {
                        balanceOffCenterTime = max(0, balanceOffCenterTime - 0.1)
                    }
                }
            }
        }
    }

    private func startBarrelChallenge() {
        barrelTimer?.cancel()
        barrelHoldTime = 0; barrelSuccess = false
        barrelTimer = Task {
            for _ in 0..<100 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
            }
            await MainActor.run {
                if !barrelSuccess && !wipeoutTriggered && phase == .barrelRide {
                    wipeoutTriggered = true; endWave(wipeout: true)
                }
            }
        }
    }

    private func completeBarrel() {
        cancelAllTimers()
        hapticNotification(.success); hapticImpact(.heavy)
        let finalScore = Double(Int.random(in: 12...18)) * currentWaveType.pointMultiplier
        currentWaveScore = finalScore
        withAnimation { showBarrelBonus = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            await MainActor.run { showBarrelBonus = false; endWave(wipeout: false, overrideScore: finalScore) }
        }
    }

    private func completeDuckDive() {
        duckDiveCompleted = true; hapticImpact(.medium)
        if surfMode == .endless { endlessWaveCount += 1; scheduleNextEndlessWave() } else { advanceWave() }
    }

    private func openTrickWindow() {
        trickWindowOpen = true; trickWindowTimeLeft = 4.0; phase = .trickWindow
        hapticImpact(.soft)
        Task {
            for i in 0..<40 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run { trickWindowTimeLeft = max(0, 4.0 - Double(i + 1) * 0.1) }
            }
            await MainActor.run { if phase == .trickWindow { trickWindowOpen = false; phase = .riding } }
        }
    }

    private func handleTrickSwipe(_ translation: CGSize) {
        guard phase == .trickWindow, !wipeoutTriggered else { return }
        let dx = translation.width, dy = translation.height
        let ax = abs(dx), ay = abs(dy)
        let trick: SurfTrick = ay > ax * 1.8 ? (dy < 0 ? .aerial : .tube) : .cutback
        performedTrick = trick; trickAccumulator += trick.points
        currentWaveScore = Double(trickAccumulator) * currentBalanceMultiplier
        switch trick {
        case .aerial:
            hapticImpact(.heavy); currentCanvasPhase = .aerial
            Task { try? await Task.sleep(for: .milliseconds(600)); await MainActor.run { hapticImpact(.heavy); currentCanvasPhase = .normal } }
        case .tube:
            hapticImpact(.rigid); currentCanvasPhase = .tube; tubeMultiplier = min(3, tubeMultiplier + 1)
            Task { try? await Task.sleep(for: .milliseconds(1200)); await MainActor.run { currentCanvasPhase = .normal } }
        case .cutback:
            hapticImpact(.medium); currentCanvasPhase = .normal
        }
        hapticImpact(.light)
        comboTricks.append(trick.rawValue)
        trickFlashText = "\(trick.rawValue)  +\(trick.points)"
        withAnimation(.spring(response: 0.2)) { showTrickFlash = true }
        Task { try? await Task.sleep(for: .milliseconds(900)); await MainActor.run { withAnimation { showTrickFlash = false } } }
        trickWindowOpen = false; phase = .riding
    }

    private func adjustBalance(delta: Double) {
        guard phase == .riding || phase == .trickWindow || phase == .barrelRide else { return }
        balanceMeter = max(0, min(1, balanceMeter + delta))
    }

    private func endWave(wipeout: Bool, overrideScore: Double? = nil) {
        cancelAllTimers()
        let finalScore: Double
        if let ov = overrideScore { finalScore = ov }
        else if wipeout { finalScore = 0 }
        else {
            let base = max(0, Double(trickAccumulator) * currentBalanceMultiplier)
            finalScore = surfMode == .endless ? base * currentWaveType.pointMultiplier : base
        }
        currentWaveScore = finalScore
        if surfMode == .endless {
            let waveInt = Int(finalScore)
            if !wipeout { totalScore += waveInt; if waveInt > sessionBestWave { sessionBestWave = waveInt }; endlessWaveCount += 1 }
            else { wipeoutCount += 1 }
        }
        let ws = WaveScore(waveNumber: surfMode == .endless ? endlessWaveCount : waveNumber, rawScore: finalScore, wipeout: wipeout)
        waveScores.append(ws)
        if wipeout {
            hapticNotification(.error); hapticImpact(.heavy); currentCanvasPhase = .wipeout; phase = .wipeout
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                await MainActor.run {
                    if surfMode == .endless { if wipeoutCount >= maxWipeouts { finishEndlessSession() } else { scheduleNextEndlessWave() } }
                    else { advanceWave() }
                }
            }
        } else {
            hapticImpact(.light)
            let j1 = finalScore * Double.random(in: 0.85...1.05)
            let j2 = finalScore * Double.random(in: 0.80...1.00)
            let j3 = finalScore * Double.random(in: 0.88...1.08)
            judgeScores = [min(10, j1 / 3.0), min(10, j2 / 3.0), min(10, j3 / 3.0)]
            showJudgePanel = true; currentCanvasPhase = .normal; phase = .waveResult
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                await MainActor.run { showJudgePanel = false; if surfMode == .endless { scheduleNextEndlessWave() } else { advanceWave() } }
            }
        }
    }

    private func scheduleNextEndlessWave() {
        endlessWaveInterval = Double.random(in: 8...12)
        endlessWaveTask?.cancel()
        endlessWaveTask = Task {
            try? await Task.sleep(for: .seconds(endlessWaveInterval))
            await MainActor.run { guard phase == .waveResult || phase == .wipeout else { return }; startPaddleIn() }
        }
    }

    private func advanceWave() {
        if waveNumber >= totalWaves { finishHeat() } else { waveNumber += 1; startPaddleIn() }
    }

    private func finishHeat() {
        if !rewardApplied {
            rewardApplied = true
            viewModel.profile.evolutionShards += playerWins ? 50 : (isDraw ? 25 : 15)
        }
        GameResultService.saveResult(modeId: "surfing", userScore: Int(heat1Score))
        phase = .heatResult
        Task { try? await Task.sleep(for: .seconds(3.0)); await MainActor.run { phase = .result } }
    }

    private func finishEndlessSession() {
        cancelAllTimers()
        if totalScore > personalBest { setPersonalBest(totalScore) }
        GameResultService.saveResult(modeId: "surfing", userScore: totalScore)
        phase = .sessionSummary
    }

    private func cancelAllTimers() {
        waveTimer?.cancel(); wavePowerTimer?.cancel(); balanceDriftTimer?.cancel()
        barrelTimer?.cancel(); endlessWaveTask?.cancel()
    }
}
