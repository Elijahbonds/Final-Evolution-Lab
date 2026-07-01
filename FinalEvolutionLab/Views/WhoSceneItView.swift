import SwiftUI

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

    private enum WhoPhase { case ready, playing, result }
    private var questions: [WhoQuestion] { WhoSceneItQuestions.all }
    private var current: WhoQuestion { questions[min(currentIndex, questions.count - 1)] }

    private var activeCreatorCard: CreatorCard? {
        guard let state = viewModel.profile.activeCreatorCard else { return nil }
        return CreatorCard.catalog.first(where: { $0.id == state.cardId })
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.03, blue: 0.02), Color(red: 0.02, green: 0.02, blue: 0.06)],
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
            Button { showCreatorSpotlight = true } label: {
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
                WhoSceneCanvas(sceneType: WhoSceneType.infer(from: current.sceneDescription))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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
        let bg: Color = showAnswer ? (isCorrect ? Color.green.opacity(0.18) : (isSelected ? Color.red.opacity(0.15) : Color.white.opacity(0.03))) : (isSelected ? gameMode.accentColor.opacity(0.18) : Color.white.opacity(0.05))
        let border: Color = showAnswer ? (isCorrect ? .green : (isSelected ? .red : Color.white.opacity(0.06))) : (isSelected ? gameMode.accentColor : Color.white.opacity(0.08))

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

    private func startGame() {
        playerScore = 0; opponentScore = 0; currentIndex = 0
        phase = .playing
        beginQuestion()
    }

    private func beginQuestion() {
        timeRemaining = 20; selectedAnswer = nil; showAnswer = false
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeRemaining -= 1 }
            }
            await MainActor.run {
                showAnswer = true
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
        timerTask?.cancel(); showAnswer = true
        UIImpactFeedbackGenerator(style: index == current.correctIndex ? .heavy : .medium).impactOccurred()
        if index == current.correctIndex { playerScore += 10 + max(0, timeRemaining - 5) }
        Task { try? await Task.sleep(for: .milliseconds(1400)); await MainActor.run { advance() } }
    }

    private func advance() {
        if currentIndex + 1 >= questions.count { phase = .result }
        else { currentIndex += 1; beginQuestion() }
    }
}

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
