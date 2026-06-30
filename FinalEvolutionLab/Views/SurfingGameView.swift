import SwiftUI

// MARK: - Phase

private enum SurfingPhase {
    case ready, paddleIn, riding, trickWindow, wipeout, waveResult, heatResult, result
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
        case .aerial:  return "SWIPE ↑"
        case .tube:    return "SWIPE ↓"
        case .cutback: return "SWIPE ↗ / ↙"
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

// MARK: - Surf Wave Drawer

private struct SurfWaveDrawer {
    let W: CGFloat
    let H: CGFloat
    let balance: Double
    let power: Double
    let isTrickWindow: Bool
    let t: Double

    mutating func render(ctx: inout GraphicsContext) {
        drawSky(ctx: &ctx)
        drawOcean(ctx: &ctx)
        drawWaveFace(ctx: &ctx)
        drawWhitewater(ctx: &ctx)
        drawFoamStripes(ctx: &ctx)
        drawSurfer(ctx: &ctx)
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

    private func drawOcean(ctx: inout GraphicsContext) {
        let horizonY = H * 0.37
        ctx.fill(Path(CGRect(x: 0, y: horizonY, width: W, height: H - horizonY)),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.03, green: 0.16, blue: 0.32), location: 0),
                        .init(color: Color(red: 0.01, green: 0.07, blue: 0.18), location: 1)
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
                       with: .color(Color(red: 0.15, green: 0.45, blue: 0.65).opacity(0.25)),
                       lineWidth: 1.5)
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

    private func drawSurfer(ctx: inout GraphicsContext) {
        let (crestX, crestY, baseX, baseY, _) = waveGeometry()
        let faceT: CGFloat = 0.42
        let sx = baseX + (crestX - baseX) * faceT * 0.80
        let sy = crestY + (baseY - crestY) * (1.0 - faceT * 0.72)
        let leanAngle = (balance - 0.5) * .pi / 5.5
        let trickJump = isTrickWindow ? -abs(sin(t * 8.0)) * 14.0 : 0.0

        var shadowGC = ctx
        shadowGC.translateBy(x: sx, y: sy + CGFloat(trickJump))
        shadowGC.addFilter(.blur(radius: 4))
        shadowGC.fill(Path(ellipseIn: CGRect(x: -18, y: 8, width: 36, height: 8)),
                      with: .color(.black.opacity(0.32)))

        var gc = ctx
        gc.translateBy(x: sx, y: sy + CGFloat(trickJump))
        gc.rotate(by: .radians(leanAngle))

        gc.fill(Path(roundedRect: CGRect(x: -21, y: 4, width: 42, height: 7),
                     cornerRadius: CGSize(width: 3.5, height: 3.5)),
                with: .color(.white.opacity(0.92)))
        gc.fill(Path(roundedRect: CGRect(x: -21, y: 4, width: 42, height: 2),
                     cornerRadius: CGSize(width: 1, height: 1)),
                with: .color(Color(red: 0.20, green: 0.75, blue: 1.0).opacity(0.85)))

        let wetsuit = GraphicsContext.Shading.color(Color(red: 0.06, green: 0.14, blue: 0.32))
        let skin = GraphicsContext.Shading.color(Color(red: 0.88, green: 0.65, blue: 0.44))

        var legs = Path()
        legs.move(to: CGPoint(x: -7, y: 4))
        legs.addLine(to: CGPoint(x: -4, y: -3))
        legs.addLine(to: CGPoint(x: -1, y: -7))
        legs.move(to: CGPoint(x: 7, y: 4))
        legs.addLine(to: CGPoint(x: 4, y: -3))
        legs.addLine(to: CGPoint(x: 1, y: -7))
        gc.stroke(legs, with: wetsuit, lineWidth: 3.0)

        var torso = Path()
        torso.move(to: CGPoint(x: 0, y: -7))
        torso.addLine(to: CGPoint(x: 0, y: -17))
        gc.stroke(torso, with: wetsuit, lineWidth: 3.0)

        let armSpread: CGFloat = isTrickWindow ? 17 : 13
        var arms = Path()
        arms.move(to: CGPoint(x: -armSpread, y: -13))
        arms.addLine(to: CGPoint(x: 0, y: -12))
        arms.addLine(to: CGPoint(x: armSpread, y: -13))
        gc.stroke(arms, with: wetsuit, lineWidth: 2.5)

        gc.fill(Path(ellipseIn: CGRect(x: -4.5, y: -25, width: 9, height: 9)), with: skin)

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

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var drawer = SurfWaveDrawer(
                    W: size.width, H: size.height,
                    balance: balance, power: power,
                    isTrickWindow: isTrickWindow, t: t)
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

        var body = Path()
        body.move(to: CGPoint(x: -20, y: -2))
        body.addLine(to: CGPoint(x: 18, y: -2))
        gc.stroke(body, with: bodyColor, lineWidth: 5)

        gc.fill(Path(ellipseIn: CGRect(x: 14, y: -6, width: 10, height: 10)), with: skinColor)

        let leftPhase = armCycle - 0.8
        let rightPhase = armCycle + .pi - 0.8
        var leftArm = Path()
        leftArm.move(to: CGPoint(x: -5, y: -2))
        leftArm.addLine(to: CGPoint(x: -5 + CGFloat(cos(leftPhase)) * 18,
                                     y: CGFloat(sin(leftPhase)) * 12 - 2))
        gc.stroke(leftArm, with: bodyColor, lineWidth: 2.5)

        var rightArm = Path()
        rightArm.move(to: CGPoint(x: 8, y: -2))
        rightArm.addLine(to: CGPoint(x: 8 + CGFloat(cos(rightPhase)) * 18,
                                      y: CGFloat(sin(rightPhase)) * 12 - 2))
        gc.stroke(rightArm, with: bodyColor, lineWidth: 2.5)

        let splashOp = 0.22 + 0.14 * abs(sin(armCycle))
        gc.fill(Path(ellipseIn: CGRect(x: -14, y: 2, width: 10, height: 4)),
                with: .color(.white.opacity(splashOp)))
        gc.fill(Path(ellipseIn: CGRect(x: 8, y: 2, width: 10, height: 4)),
                with: .color(.white.opacity(splashOp)))
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

    @State private var phase: SurfingPhase = .ready
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

    @State private var waveScores: [WaveScore] = []
    @State private var currentWaveScore: Double = 0
    @State private var currentBalanceMultiplier: Double = 1.0
    @State private var trickAccumulator: Int = 0

    @State private var frozenAIScore: Double = 0
    @State private var rewardApplied: Bool = false

    @State private var paddleProgress: Double = 0.0

    private let accentColor = Color(red: 0.2, green: 0.75, blue: 1.0)
    private let totalWaves = 3

    private var heat1Score: Double {
        let valid = waveScores.sorted(by: { $0.finalScore > $1.finalScore })
        let top2 = valid.prefix(2)
        return top2.reduce(0) { $0 + $1.finalScore }
    }

    private var playerWins: Bool { heat1Score > frozenAIScore }
    private var isDraw: Bool { Int(heat1Score) == Int(frozenAIScore) }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.01, green: 0.06, blue: 0.20), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Surfing",
                    subtitle: "3 waves · Best 2 of 3 · Balance + Trick",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: {
                        frozenAIScore = Double(Int.random(in: 22...42))
                        startPaddleIn()
                    }
                )
            case .paddleIn:    paddleInBody
            case .riding, .trickWindow: ridingBody
            case .wipeout:     wipeoutBody
            case .waveResult:  waveResultBody
            case .heatResult:  heatResultBody
            case .result:
                ResultScreen(
                    winner: playerWins ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: Int(heat1Score),
                    p2Score: Int(frozenAIScore),
                    title: "Surfing",
                    accentColor: accentColor,
                    prqGain: playerWins ? 14 : (isDraw ? 5 : 3),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "Wave Score",
                    modeAttributeValue: min(1.0, heat1Score / 40.0),
                    onReturn: { dismiss() }
                )
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

    // MARK: - Paddle In Body

    private var paddleInBody: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("WAVE \(waveNumber)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .tracking(4)

            Text("PADDLING OUT")
                .font(.system(size: 28, weight: .black))
                .italic()
                .foregroundStyle(.white)

            PaddleOceanCanvas(paddleProgress: paddleProgress)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(accentColor.opacity(0.20), lineWidth: 1))
                .padding(.horizontal, 20)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Theme.brandCyan, accentColor],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, CGFloat(paddleProgress) * (UIScreen.main.bounds.width - 80)), height: 14)
                    .animation(.easeInOut(duration: 0.1), value: paddleProgress)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Riding Body

    private var ridingBody: some View {
        VStack(spacing: 0) {
            ridingHUD
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer()

            ZStack(alignment: .topLeading) {
                Group {
                    if phase == .trickWindow {
                        trickWindowPanel
                    } else {
                        ridingStatusPanel
                    }
                }
                wavePowerMeter
                    .padding(.leading, 16)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 16)

            Spacer()

            balanceIndicator
                .padding(.top, 4)

            balanceControlRow
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .padding(.top, 14)
        }
        .overlay(trickFlashOverlay)
        .gesture(
            DragGesture(minimumDistance: 22)
                .onEnded { val in
                    if phase == .trickWindow { handleTrickSwipe(val.translation) }
                }
        )
    }

    // MARK: - Riding HUD

    private var ridingHUD: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("WAVE \(waveNumber) / \(totalWaves)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(1)
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                        .frame(width: 46, height: 46)
                    Circle()
                        .trim(from: 0, to: CGFloat(heatClock / 20.0))
                        .stroke(heatClock > 8 ? accentColor : .red,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 46, height: 46)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: heatClock)
                    Text(String(format: "%.0f", heatClock))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(heatClock > 8 ? .white : .red)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("WAVE SCORE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(1)
                Text(String(format: "%.1f", currentWaveScore))
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("HEAT TOTAL")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary).tracking(1)
                Text(String(format: "%.1f", heat1Score))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
                HStack(spacing: 3) {
                    ForEach(0..<totalWaves, id: \.self) { i in
                        let ws = i < waveScores.count ? waveScores[i] : nil
                        Circle()
                            .fill(ws == nil
                                  ? (i == waveNumber - 1 ? accentColor.opacity(0.5) : Color.white.opacity(0.1))
                                  : (ws!.wipeout ? .red : accentColor))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }

    // MARK: - Wave Power Meter

    private var wavePowerMeter: some View {
        VStack(spacing: 6) {
            Text("WAVE")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7)).tracking(1)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 22, height: 140)
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(
                        colors: wavePower > 0.8 ? [.yellow, accentColor] : [accentColor.opacity(0.5), accentColor],
                        startPoint: .bottom, endPoint: .top))
                    .frame(width: 22, height: max(4, 140 * CGFloat(wavePower)))
                    .animation(.linear(duration: 0.1), value: wavePower)
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accentColor.opacity(0.3), lineWidth: 1))
            Text("\(Int(wavePower * 100))%")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(wavePower > 0.8 ? .yellow : accentColor)
        }
    }

    // MARK: - Riding Status Panel

    private var ridingStatusPanel: some View {
        ZStack {
            SurfingWaveCanvas(balance: balanceMeter, power: wavePower, isTrickWindow: false)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            Color.black.opacity(0.16)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            VStack(spacing: 10) {
                Spacer()
                Text("RIDING THE WAVE")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .tracking(3)
                    .shadow(color: accentColor.opacity(0.7), radius: 10)
                if wavePower > 0.75 {
                    Text("◆ TRICK WINDOW OPENING ◆")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .tracking(2)
                        .shadow(color: .yellow.opacity(0.6), radius: 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
                Spacer()
            }
            .padding(20)
            RoundedRectangle(cornerRadius: 20).stroke(accentColor.opacity(0.25), lineWidth: 1)
        }
        .frame(height: 200)
    }

    // MARK: - Trick Window Panel

    private var trickWindowPanel: some View {
        ZStack {
            SurfingWaveCanvas(balance: balanceMeter, power: wavePower, isTrickWindow: true)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            Color.black.opacity(0.52)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(trickWindowTimeLeft / 4.0))
                        .stroke(
                            trickWindowTimeLeft > 2 ? Color.yellow : Color.orange,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: trickWindowTimeLeft)
                    Text(String(format: "%.1f", trickWindowTimeLeft))
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                }

                Text("TRICK WINDOW!")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .tracking(3)
                    .shadow(color: .yellow.opacity(0.5), radius: 10)

                VStack(spacing: 5) {
                    ForEach(SurfTrick.allCases, id: \.self) { trick in
                        HStack(spacing: 10) {
                            Image(systemName: trick.systemImage)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(accentColor)
                                .frame(width: 20)
                            Text("\(trick.swipeHint) — \(trick.rawValue)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("+\(trick.points) pts")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.22), lineWidth: 1)))
            }
            .padding(14)

            RoundedRectangle(cornerRadius: 20).stroke(Color.yellow.opacity(0.40), lineWidth: 1)
        }
        .frame(height: 200)
    }

    // MARK: - Balance Indicator

    private var balanceIndicator: some View {
        VStack(spacing: 8) {
            Text("BALANCE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(2)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 200, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                HStack {
                    Rectangle().fill(Color.red.opacity(0.15)).frame(width: 30, height: 18).cornerRadius(6)
                    Spacer()
                    Rectangle().fill(Color.red.opacity(0.15)).frame(width: 30, height: 18).cornerRadius(6)
                }
                .frame(width: 200)
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 2, height: 18)
                Circle()
                    .fill(
                        balanceMeter < 0.2 || balanceMeter > 0.8
                            ? Color.red
                            : (abs(balanceMeter - 0.5) < 0.1 ? Theme.foundationGreen : accentColor)
                    )
                    .frame(width: 20, height: 20)
                    .shadow(
                        color: (abs(balanceMeter - 0.5) < 0.1 ? Theme.foundationGreen : accentColor).opacity(0.5),
                        radius: 8)
                    .offset(x: (CGFloat(balanceMeter) - 0.5) * 180)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: balanceMeter)
            }
            .frame(width: 200)

            if balanceMeter < 0.2 || balanceMeter > 0.8 {
                Text("LEAN BACK TO CENTER!")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.red).tracking(1)
            } else if abs(balanceMeter - 0.5) < 0.1 {
                Text("PERFECT BALANCE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.foundationGreen).tracking(1)
            }
        }
    }

    // MARK: - Balance Controls

    private var balanceControlRow: some View {
        HStack(spacing: 16) {
            Button { adjustBalance(delta: -0.12) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
                        .frame(height: 72)
                    VStack(spacing: 5) {
                        Image(systemName: "arrow.left.circle.fill").font(.system(size: 26, weight: .bold))
                        Text("LEAN LEFT").font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1)
                    }.foregroundStyle(accentColor)
                }
            }.buttonStyle(.plain)

            Button { adjustBalance(delta: 0.12) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
                        .frame(height: 72)
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
                    Text(trickFlashText)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.7), radius: 20)
                    Text("TRICK SCORED!")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.7))
                        .tracking(3)
                }
                .allowsHitTesting(false)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.5), value: showTrickFlash)
    }

    // MARK: - Wipeout Body

    private var wipeoutBody: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(Color.red.opacity(0.1)).frame(width: 110, height: 110)
                Image(systemName: "water.waves.slash")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.red)
            }
            Text("WIPEOUT!")
                .font(.system(size: 38, weight: .black)).italic()
                .foregroundStyle(.red)
                .shadow(color: .red.opacity(0.4), radius: 20)
            Text("Lost balance for too long")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            Text("WAVE \(waveNumber) — 0.0 pts")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(.red).tracking(2)
            Spacer()
        }
    }

    // MARK: - Wave Result Body

    private var waveResultBody: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("WAVE \(waveNumber) COMPLETE")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor).tracking(3)
            ZStack {
                Circle().fill(accentColor.opacity(0.1)).frame(width: 110, height: 110)
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(.yellow)
                    Text(String(format: "%.1f", waveScores.last?.finalScore ?? 0))
                        .font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(.white)
                }
            }
            VStack(spacing: 10) {
                if let ws = waveScores.last {
                    scoreRow(label: "TRICK POINTS", value: String(format: "%.0f", Double(trickAccumulator)))
                    scoreRow(label: "BALANCE MULTIPLIER", value: String(format: "×%.2f", currentBalanceMultiplier))
                    Divider().background(Theme.cardBorder)
                    scoreRow(label: "WAVE SCORE", value: String(format: "%.1f", ws.finalScore), highlight: true)
                }
                scoreRow(label: "HEAT RUNNING TOTAL", value: String(format: "%.1f", heat1Score))
                if waveNumber < totalWaves {
                    scoreRow(label: "WAVES REMAINING", value: "\(totalWaves - waveNumber)")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
            )
            .padding(.horizontal, 28)
            HStack(spacing: 10) {
                ForEach(waveScores) { ws in
                    VStack(spacing: 3) {
                        Circle().fill(ws.wipeout ? Color.red : accentColor).frame(width: 14, height: 14)
                        Text(ws.wipeout ? "W/O" : String(format: "%.1f", ws.finalScore))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(ws.wipeout ? .red : .white)
                    }
                }
                if waveScores.count < totalWaves {
                    ForEach(waveScores.count..<totalWaves, id: \.self) { _ in
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 14, height: 14)
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
            Text("HEAT FINAL")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor).tracking(3)
            VStack(spacing: 8) {
                ForEach(waveScores) { ws in
                    HStack {
                        Text("WAVE \(ws.waveNumber)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        if ws.wipeout {
                            Text("WIPEOUT").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.red)
                        } else {
                            Text(String(format: "%.1f", ws.finalScore))
                                .font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                    )
                }
                Divider().background(Theme.cardBorder).padding(.vertical, 4)
                HStack {
                    Text("BEST 2 OF 3")
                        .font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                    Spacer()
                    Text(String(format: "%.1f", heat1Score))
                        .font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(.white)
                }.padding(.horizontal, 4)
                HStack {
                    Text("AI SCORE")
                        .font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                    Spacer()
                    Text(String(format: "%.1f", frozenAIScore))
                        .font(.system(size: 20, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }.padding(.horizontal, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1))
            )
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func scoreRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(1)
            Spacer()
            Text(value)
                .font(.system(size: highlight ? 20 : 14, weight: .black, design: .monospaced))
                .foregroundStyle(highlight ? accentColor : .white)
        }
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
        wavePower = 0
        balanceMeter = 0.5
        balanceOffCenterTime = 0
        wipeoutTriggered = false
        heatClock = 20.0
        currentWaveScore = 0
        currentBalanceMultiplier = 1.0
        trickAccumulator = 0
        trickWindowOpen = false
        performedTrick = nil
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
                    if wavePower >= 0.8 && !trickWindowOpen && !wipeoutTriggered {
                        openTrickWindow()
                    }
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
                    guard phase == .riding || phase == .trickWindow else { return }
                    let drift = Double.random(in: -0.04...0.04)
                    balanceMeter = max(0, min(1, balanceMeter + drift))
                    let dist = abs(balanceMeter - 0.5)
                    currentBalanceMultiplier = dist < 0.1 ? 1.5 : (dist < 0.25 ? 1.0 : 0.5)
                    if balanceMeter < 0.12 || balanceMeter > 0.88 {
                        balanceOffCenterTime += 0.15
                        if balanceOffCenterTime >= 2.0 && !wipeoutTriggered {
                            wipeoutTriggered = true
                            endWave(wipeout: true)
                        }
                    } else {
                        balanceOffCenterTime = max(0, balanceOffCenterTime - 0.1)
                    }
                }
            }
        }
    }

    private func openTrickWindow() {
        trickWindowOpen = true
        trickWindowTimeLeft = 4.0
        phase = .trickWindow
        Task {
            for i in 0..<40 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run { trickWindowTimeLeft = max(0, 4.0 - Double(i + 1) * 0.1) }
            }
            await MainActor.run {
                if phase == .trickWindow { trickWindowOpen = false; phase = .riding }
            }
        }
    }

    private func handleTrickSwipe(_ translation: CGSize) {
        guard phase == .trickWindow, !wipeoutTriggered else { return }
        let dx = translation.width, dy = translation.height
        let ax = abs(dx), ay = abs(dy)
        let trick: SurfTrick
        if ay > ax * 1.8 {
            trick = dy < 0 ? .aerial : .tube
        } else {
            trick = .cutback
        }
        performedTrick = trick
        trickAccumulator += trick.points
        currentWaveScore = Double(trickAccumulator) * currentBalanceMultiplier
        trickFlashText = "\(trick.rawValue)  +\(trick.points)"
        withAnimation(.spring(response: 0.2)) { showTrickFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run { withAnimation { showTrickFlash = false } }
        }
        trickWindowOpen = false
        phase = .riding
    }

    private func adjustBalance(delta: Double) {
        guard phase == .riding || phase == .trickWindow else { return }
        balanceMeter = max(0, min(1, balanceMeter + delta))
    }

    private func endWave(wipeout: Bool) {
        cancelAllTimers()
        let finalScore = wipeout ? 0 : max(0, Double(trickAccumulator) * currentBalanceMultiplier)
        currentWaveScore = finalScore
        let ws = WaveScore(waveNumber: waveNumber, rawScore: finalScore, wipeout: wipeout)
        waveScores.append(ws)
        if wipeout {
            phase = .wipeout
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                await MainActor.run { advanceWave() }
            }
        } else {
            phase = .waveResult
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                await MainActor.run { advanceWave() }
            }
        }
    }

    private func advanceWave() {
        if waveNumber >= totalWaves { finishHeat() } else { waveNumber += 1; startPaddleIn() }
    }

    private func finishHeat() {
        if !rewardApplied {
            rewardApplied = true
            let shards = playerWins ? 50 : (isDraw ? 25 : 15)
            viewModel.profile.evolutionShards += shards
        }
        phase = .heatResult
        Task {
            try? await Task.sleep(for: .seconds(3.0))
            await MainActor.run { phase = .result }
        }
    }

    private func cancelAllTimers() {
        waveTimer?.cancel()
        wavePowerTimer?.cancel()
        balanceDriftTimer?.cancel()
    }
}
