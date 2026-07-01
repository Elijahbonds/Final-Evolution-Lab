import SwiftUI

// MARK: - Carnival Canvas

private struct CarnivalSpinFXCanvas: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let cx = size.width / 2; let cy = size.height / 2
                let R: CGFloat = 94
                let pulse = CGFloat(0.5 + sin(t * 3.0) * 0.3)
                var rimGC = ctx; rimGC.addFilter(.blur(radius: 12))
                rimGC.stroke(Path(ellipseIn: CGRect(x:cx-R,y:cy-R,width:R*2,height:R*2)),
                             with: .color(Color.white.opacity(Double(pulse)*0.50)), lineWidth: 7)
                for i in 0..<8 {
                    let angle = t * 1.8 + Double(i) * .pi / 4.0
                    let px = cx + CGFloat(cos(angle)) * (R + 14)
                    let py = cy + CGFloat(sin(angle)) * (R + 14)
                    let sp = CGFloat(0.5 + sin(t * 4.0 + Double(i)) * 0.5)
                    var gc = ctx; gc.addFilter(.blur(radius: 2))
                    gc.fill(Path(ellipseIn: CGRect(x:px-3,y:py-3,width:6,height:6)),
                            with: .color(Color.yellow.opacity(Double(sp)*0.80)))
                }
            }
        }
    }
}

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
        ctx.fill(Path(CGRect(x:0,y:floorY,width:W,height:H-floorY)),
                 with: .color(Color(red:0.10,green:0.18,blue:0.35)))
        var fl = Path(); fl.move(to: CGPoint(x:0,y:floorY)); fl.addLine(to: CGPoint(x:W,y:floorY))
        ctx.stroke(fl, with: .color(Color.white.opacity(0.22)), lineWidth: 1.5)
        let ballCount = min(3, max(1, tapCount / 7 + 1))
        for b in 0..<ballCount {
            let xp = Double(b) * 0.33
            let bx = W * CGFloat(0.22 + xp * 0.56 + sin(t * 0.8 + xp) * 0.06)
            let rawY = CGFloat(abs(sin(t * 3.5 + Double(b) * 1.4)))
            let by = floorY - 6 - rawY * H * 0.55
            let r: CGFloat = 13
            ctx.fill(Path(ellipseIn: CGRect(x:bx-r,y:by-r,width:r*2,height:r*2)),
                     with: .color(Color(red:1.0,green:0.55,blue:0.0).opacity(0.90)))
            let sw = r * 2 * (1 - rawY * 0.6)
            ctx.fill(Path(ellipseIn: CGRect(x:bx-sw/2,y:floorY-3,width:sw,height:5)),
                     with: .color(Color.black.opacity(Double(0.28 * (1 - rawY * 0.7)))))
        }
        for i in 0..<4 {
            let phase = fmod(t * 2.0 + Double(i) * 0.4, 1.0)
            let lx = W * CGFloat(phase)
            let y = H * CGFloat(0.22 + Double(i) * 0.14)
            var sl = Path(); sl.move(to: CGPoint(x:lx-22,y:y)); sl.addLine(to: CGPoint(x:lx,y:y))
            ctx.stroke(sl, with: .color(Color.orange.opacity(0.18)), lineWidth: 1)
        }
    }

    private func drawSprint(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        let groundY = H * 0.78
        ctx.fill(Path(CGRect(x:0,y:groundY,width:W,height:H-groundY)),
                 with: .color(Color(red:0.55,green:0.28,blue:0.08).opacity(0.35)))
        var gl = Path(); gl.move(to: CGPoint(x:0,y:groundY)); gl.addLine(to: CGPoint(x:W,y:groundY))
        ctx.stroke(gl, with: .color(Color.white.opacity(0.20)), lineWidth: 1)
        for i in 0..<2 {
            let y = H * CGFloat(0.40 + Double(i) * 0.20)
            var ln = Path(); ln.move(to: CGPoint(x:0,y:y)); ln.addLine(to: CGPoint(x:W,y:y))
            ctx.stroke(ln, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
        }
        let runX = W * CGFloat(fmod(t * 0.22, 1.0))
        let cy = groundY - 30
        let stride = CGFloat(sin(t * 6.5))
        var body = Path(); body.move(to: CGPoint(x:runX,y:cy-18)); body.addLine(to: CGPoint(x:runX,y:cy))
        ctx.stroke(body, with: .color(Color.green.opacity(0.90)), lineWidth: 2.5)
        ctx.fill(Path(ellipseIn: CGRect(x:runX-5,y:cy-28,width:10,height:10)),
                 with: .color(Color.green.opacity(0.90)))
        var ll = Path(); ll.move(to: CGPoint(x:runX,y:cy)); ll.addLine(to: CGPoint(x:runX-10*stride,y:cy+18))
        ctx.stroke(ll, with: .color(Color.green.opacity(0.80)), lineWidth: 2)
        var rl = Path(); rl.move(to: CGPoint(x:runX,y:cy)); rl.addLine(to: CGPoint(x:runX+10*stride,y:cy+18))
        ctx.stroke(rl, with: .color(Color.green.opacity(0.80)), lineWidth: 2)
        var la = Path(); la.move(to: CGPoint(x:runX,y:cy-12)); la.addLine(to: CGPoint(x:runX+14*stride,y:cy-2))
        ctx.stroke(la, with: .color(Color.green.opacity(0.70)), lineWidth: 2)
        for i in 0..<5 {
            let llen = CGFloat(18 + i * 9)
            let ly = cy - 18 + CGFloat(i) * 9
            var sl = Path(); sl.move(to: CGPoint(x:runX-llen-5,y:ly)); sl.addLine(to: CGPoint(x:runX-5,y:ly))
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
            gc.stroke(Path(ellipseIn: CGRect(x:cx-r,y:groundY-r*0.35,width:r*2,height:r*0.7)),
                      with: .color(Color.cyan.opacity(alpha*0.8)), lineWidth: 2)
            ctx.stroke(Path(ellipseIn: CGRect(x:cx-r,y:groundY-r*0.35,width:r*2,height:r*0.7)),
                       with: .color(Color.cyan.opacity(alpha*0.28)), lineWidth: 1)
        }
        let jumpH = CGFloat(sin(fmod(t * 1.5, 1.0) * .pi)) * H * 0.50
        let fy = groundY - jumpH - 30
        var jb = Path(); jb.move(to: CGPoint(x:cx,y:fy-18)); jb.addLine(to: CGPoint(x:cx,y:fy))
        ctx.stroke(jb, with: .color(Color.cyan.opacity(0.90)), lineWidth: 2.5)
        ctx.fill(Path(ellipseIn: CGRect(x:cx-5,y:fy-28,width:10,height:10)),
                 with: .color(Color.cyan.opacity(0.90)))
        let ls = jumpH / (H * 0.50) * 14
        var ll = Path(); ll.move(to: CGPoint(x:cx,y:fy)); ll.addLine(to: CGPoint(x:cx-ls,y:fy+18))
        ctx.stroke(ll, with: .color(Color.cyan.opacity(0.80)), lineWidth: 2)
        var rl = Path(); rl.move(to: CGPoint(x:cx,y:fy)); rl.addLine(to: CGPoint(x:cx+ls,y:fy+18))
        ctx.stroke(rl, with: .color(Color.cyan.opacity(0.80)), lineWidth: 2)
        let ss = max(CGFloat(0.18), 1.0 - jumpH / (H * 0.50) * 0.80)
        ctx.fill(Path(ellipseIn: CGRect(x:cx-18*ss,y:groundY-4,width:36*ss,height:8)),
                 with: .color(Color.black.opacity(Double(ss)*0.38)))
    }

    private func drawRally(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        ctx.fill(Path(CGRect(width:W,height:H)), with: .color(Color(red:0.08,green:0.18,blue:0.08)))
        var net = Path(); net.move(to: CGPoint(x:W/2,y:0)); net.addLine(to: CGPoint(x:W/2,y:H))
        ctx.stroke(net, with: .color(Color.white.opacity(0.28)), lineWidth: 1.5)
        let ballT = CGFloat(fmod(t * 1.2, 1.0))
        let bx = W * ballT
        let by = H * 0.50 - CGFloat(sin(ballT * .pi)) * H * 0.35
        var bGC = ctx; bGC.addFilter(.blur(radius: 3))
        bGC.fill(Path(ellipseIn: CGRect(x:bx-8,y:by-8,width:16,height:16)),
                 with: .color(Color.yellow.opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x:bx-5,y:by-5,width:10,height:10)),
                 with: .color(Color.yellow.opacity(0.95)))
        let ry = H * CGFloat(0.50 + sin(t * 1.5) * 0.20)
        ctx.stroke(Path(ellipseIn: CGRect(x:W*0.04,y:ry-14,width:16,height:22)),
                   with: .color(Color.yellow.opacity(0.58)), lineWidth: 2)
        ctx.stroke(Path(ellipseIn: CGRect(x:W*0.88,y:ry-14,width:16,height:22)),
                   with: .color(Color.yellow.opacity(0.58)), lineWidth: 2)
    }

    private func drawTrickShot(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ t: Double) {
        let floorY = H * 0.78
        ctx.fill(Path(CGRect(x:0,y:floorY,width:W,height:H-floorY)),
                 with: .color(Color(red:0.10,green:0.18,blue:0.35)))
        var fl = Path(); fl.move(to: CGPoint(x:0,y:floorY)); fl.addLine(to: CGPoint(x:W,y:floorY))
        ctx.stroke(fl, with: .color(Color.white.opacity(0.22)), lineWidth: 1.5)
        var pole = Path(); pole.move(to: CGPoint(x:W*0.86,y:floorY)); pole.addLine(to: CGPoint(x:W*0.86,y:H*0.20))
        ctx.stroke(pole, with: .color(Color.white.opacity(0.45)), lineWidth: 2)
        ctx.stroke(Path(CGRect(x:W*0.82,y:H*0.20,width:W*0.10,height:H*0.09)),
                   with: .color(Color.white.opacity(0.45)), lineWidth: 1.5)
        ctx.stroke(Path(ellipseIn: CGRect(x:W*0.76,y:H*0.31,width:W*0.09,height:H*0.04)),
                   with: .color(Color.orange.opacity(0.90)), lineWidth: 2)
        let ballT = CGFloat(fmod(t * 0.9, 1.0))
        let bx = W * (0.10 + ballT * 0.72)
        let arcY = floorY - CGFloat(sin(ballT * .pi)) * H * 0.52
        var bGC = ctx; bGC.addFilter(.blur(radius: 3))
        bGC.fill(Path(ellipseIn: CGRect(x:bx-9,y:arcY-9,width:18,height:18)),
                 with: .color(Color.orange.opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x:bx-6,y:arcY-6,width:12,height:12)),
                 with: .color(Color(red:1.0,green:0.55,blue:0.0).opacity(0.95)))
        for i in 1...4 {
            let trailT = max(CGFloat(0), ballT - CGFloat(i) * 0.06)
            let tx = W * (0.10 + trailT * 0.72)
            let ty = floorY - CGFloat(sin(trailT * .pi)) * H * 0.52
            ctx.fill(Path(ellipseIn: CGRect(x:tx-3,y:ty-3,width:6,height:6)),
                     with: .color(Color.orange.opacity(0.40 / Double(i))))
        }
    }
}

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

    private var playingBody: some View {
        let game = miniGames[currentMiniGame]
        return VStack(spacing: 0) {
            HStack {
                Text("SCORE: \(playerScore)").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(.white)
                Spacer()
                Text("GAME \(currentMiniGame + 1)/\(miniGames.count)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(gameMode.accentColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3).fill(timeRemaining > 4 ? gameMode.accentColor : Color.red)
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
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground).overlay(RoundedRectangle(cornerRadius: 20).stroke(game.color.opacity(0.2), lineWidth: 1)))
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            phase = .result
        } else {
            currentMiniGame += 1
            phase = .spinning
            spinWheel()
        }
    }
}

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
        CarnivalGame(title: "Speed Dribble", instruction: "Tap as fast as you can to out-dribble your opponent!", icon: "figure.basketball", color: Color(red: 1, green: 0.6, blue: 0), mechanic: .tap, timeLimit: 8, target: 20),
        CarnivalGame(title: "Sprint Burst", instruction: "Rapid taps — first to 25 reps wins the lane!", icon: "figure.run", color: .green, mechanic: .tap, timeLimit: 10, target: 25),
        CarnivalGame(title: "Jump Timing", instruction: "Nail the timing — the arena is watching!", icon: "arrow.up.circle.fill", color: .cyan, mechanic: .auto, timeLimit: 6, target: 0),
        CarnivalGame(title: "Rally Strike", instruction: "Tap each hit before the ball bounces twice!", icon: "tennis.racket", color: .yellow, mechanic: .tap, timeLimit: 8, target: 18),
        CarnivalGame(title: "Trick Shot", instruction: "The pressure's on — clutch the angle!", icon: "basketball.fill", color: Color(red: 0.95, green: 0.49, blue: 0.15), mechanic: .auto, timeLimit: 5, target: 0),
    ]
}
