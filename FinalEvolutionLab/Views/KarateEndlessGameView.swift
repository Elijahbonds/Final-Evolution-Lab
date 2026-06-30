import SwiftUI

// MARK: - Phase

private enum EndlessPhase {
    case ready, fighting, waveClear, result
}

// MARK: - Wave Opponent

private struct WaveOpponent: Identifiable {
    let id: UUID = UUID()
    var hp: Double
    let maxHP: Double
    let name: String
    var slideInProgress: Double = 1.0  // 0 = offscreen right, 1 = in position
}

// MARK: - Opponent HP Stack

private struct OpponentHPStack: View {
    let opponents: [WaveOpponent]
    let accentColor: Color

    var body: some View {
        VStack(spacing: 6) {
            ForEach(opponents) { opp in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(opp.name.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                        Spacer()
                        Text("\(Int(opp.hp))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1, opp.hp / opp.maxHP))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: opp.hp)
                        }
                    }
                    .frame(height: 7)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
    }
}

// MARK: - Endless Chakra Meter

private struct EndlessChakraMeter: View {
    let value: Double
    let accentColor: Color

    private var fraction: Double { min(1, value / 100) }
    private var isFull: Bool { value >= 100 }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isFull ? .yellow : accentColor.opacity(0.7))
                Text("CHAKRA")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(isFull ? .yellow : .secondary)
                    .tracking(2)
                Spacer()
                if isFull {
                    Text("DRAGON STRIKE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                }
                Text("\(Int(value))%")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(isFull ? .yellow : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: isFull ? [.yellow, .orange] : [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - Action Label

private struct EndlessActionLabel: View {
    let text: String
    let color: Color
    let visible: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 26, weight: .black, design: .monospaced))
            .italic()
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.7), radius: 14)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1.0 : 0.6)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: visible)
    }
}

// MARK: - Endless Dojo Canvas

private struct EndlessDojoCanvas: View {
    let opponents: [WaveOpponent]
    let playerPose: String
    let opponentPoses: [String]
    let waveNumber: Int
    let dragonActive: Bool
    let accentColor: Color

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = EndlessDojoDrawer(
                    size: size, t: t,
                    opponents: opponents,
                    playerPose: playerPose,
                    opponentPoses: opponentPoses,
                    waveNumber: waveNumber,
                    dragon: dragonActive,
                    accent: accentColor
                )
                d.render(into: &ctx)
            }
        }
    }
}

// MARK: - Stick Pose (mirrored from KarateGameView for endless)

private struct EndlessPose {
    let rElbow: CGPoint; let rWrist: CGPoint
    let lElbow: CGPoint; let lWrist: CGPoint
    let rKnee:  CGPoint; let rAnkle: CGPoint
    let lKnee:  CGPoint; let lAnkle: CGPoint
    let shoulder: CGPoint

    static let idle = EndlessPose(
        rElbow: CGPoint(x:14, y:-52), rWrist: CGPoint(x:18, y:-44),
        lElbow: CGPoint(x:-14, y:-52), lWrist: CGPoint(x:-18, y:-44),
        rKnee:  CGPoint(x:9,  y:-22), rAnkle: CGPoint(x:10, y: 0),
        lKnee:  CGPoint(x:-9, y:-22), lAnkle: CGPoint(x:-10, y: 0),
        shoulder: CGPoint(x:0, y:-58)
    )

    static let punch = EndlessPose(
        rElbow: CGPoint(x:20, y:-54), rWrist: CGPoint(x:40, y:-54),
        lElbow: CGPoint(x:-12, y:-50), lWrist: CGPoint(x:-14, y:-42),
        rKnee:  CGPoint(x:9,  y:-24), rAnkle: CGPoint(x:12, y: 0),
        lKnee:  CGPoint(x:-9, y:-22), lAnkle: CGPoint(x:-14, y: 0),
        shoulder: CGPoint(x:2, y:-58)
    )

    static let kick = EndlessPose(
        rElbow: CGPoint(x:16, y:-56), rWrist: CGPoint(x:22, y:-48),
        lElbow: CGPoint(x:-16, y:-56), lWrist: CGPoint(x:-22, y:-48),
        rKnee:  CGPoint(x:20, y:-30), rAnkle: CGPoint(x:34, y:-18),
        lKnee:  CGPoint(x:-8, y:-20), lAnkle: CGPoint(x:-10, y: 0),
        shoulder: CGPoint(x:0, y:-56)
    )

    static let block = EndlessPose(
        rElbow: CGPoint(x:10, y:-66), rWrist: CGPoint(x:8, y:-76),
        lElbow: CGPoint(x:-10, y:-66), lWrist: CGPoint(x:-8, y:-76),
        rKnee:  CGPoint(x:8,  y:-20), rAnkle: CGPoint(x:10, y: 0),
        lKnee:  CGPoint(x:-8, y:-20), lAnkle: CGPoint(x:-10, y: 0),
        shoulder: CGPoint(x:0, y:-60)
    )

    static let hit = EndlessPose(
        rElbow: CGPoint(x:8,  y:-44), rWrist: CGPoint(x:6,  y:-36),
        lElbow: CGPoint(x:-8, y:-44), lWrist: CGPoint(x:-6, y:-36),
        rKnee:  CGPoint(x:7,  y:-18), rAnkle: CGPoint(x:8,  y: 0),
        lKnee:  CGPoint(x:-7, y:-18), lAnkle: CGPoint(x:-8, y: 0),
        shoulder: CGPoint(x:-6, y:-50)
    )

    static let dragon = EndlessPose(
        rElbow: CGPoint(x:24, y:-70), rWrist: CGPoint(x:36, y:-80),
        lElbow: CGPoint(x:-24, y:-70), lWrist: CGPoint(x:-36, y:-80),
        rKnee:  CGPoint(x:10, y:-26), rAnkle: CGPoint(x:14, y: 0),
        lKnee:  CGPoint(x:-10, y:-26), lAnkle: CGPoint(x:-14, y: 0),
        shoulder: CGPoint(x:0, y:-62)
    )

    static func forName(_ name: String) -> EndlessPose {
        switch name {
        case "punch":  return .punch
        case "kick":   return .kick
        case "block":  return .block
        case "hit":    return .hit
        case "dragon": return .dragon
        default:       return .idle
        }
    }

    static func lerp(_ a: EndlessPose, _ b: EndlessPose, t: Double) -> EndlessPose {
        func lp(_ pa: CGPoint, _ pb: CGPoint) -> CGPoint {
            CGPoint(x: pa.x + (pb.x - pa.x) * t, y: pa.y + (pb.y - pa.y) * t)
        }
        return EndlessPose(
            rElbow: lp(a.rElbow, b.rElbow), rWrist: lp(a.rWrist, b.rWrist),
            lElbow: lp(a.lElbow, b.lElbow), lWrist: lp(a.lWrist, b.lWrist),
            rKnee: lp(a.rKnee, b.rKnee), rAnkle: lp(a.rAnkle, b.rAnkle),
            lKnee: lp(a.lKnee, b.lKnee), lAnkle: lp(a.lAnkle, b.lAnkle),
            shoulder: lp(a.shoulder, b.shoulder)
        )
    }
}

// MARK: - Dojo Drawer (Endless)

private struct EndlessDojoDrawer {
    let W: CGFloat, H: CGFloat, t: Double
    let opponents: [WaveOpponent]
    let playerPose: String
    let opponentPoses: [String]
    let waveNumber: Int
    let dragon: Bool
    let accent: Color
    var feetY: CGFloat { H * 0.82 }
    var scale: CGFloat { H * 0.0028 }

    init(size: CGSize, t: Double, opponents: [WaveOpponent], playerPose: String,
         opponentPoses: [String], waveNumber: Int, dragon: Bool, accent: Color) {
        self.W = size.width; self.H = size.height; self.t = t
        self.opponents = opponents; self.playerPose = playerPose
        self.opponentPoses = opponentPoses; self.waveNumber = waveNumber
        self.dragon = dragon; self.accent = accent
    }

    mutating func render(into ctx: inout GraphicsContext) {
        drawBg(ctx: &ctx)
        drawFloor(ctx: &ctx)
        drawLanterns(ctx: &ctx)
        if dragon { drawDragonAura(ctx: &ctx) }
        drawShadows(ctx: &ctx)
        // Player at left side
        let playerPoseVal = EndlessPose.forName(playerPose)
        drawFighter(ctx: &ctx, cx: W * 0.22, pose: playerPoseVal, color: .cyan, flip: false, scale: scale * 1.1)
        // Opponents at staggered right positions
        let oppXPositions: [CGFloat] = [W * 0.72, W * 0.60, W * 0.84]
        let isBossWave = waveNumber >= 5 && waveNumber % 5 == 0
        for (i, opp) in opponents.enumerated() {
            guard i < oppXPositions.count else { break }
            let slideX = oppXPositions[i] + (1.0 - CGFloat(opp.slideInProgress)) * W * 0.4
            let poseName = i < opponentPoses.count ? opponentPoses[i] : "idle"
            let pose = EndlessPose.forName(poseName)
            let isBoss = isBossWave && i == 0
            let oppScale = isBoss ? scale * 1.35 : scale
            let color: Color = isBoss ? .red : accent
            drawFighter(ctx: &ctx, cx: slideX, pose: pose, color: color, flip: true, scale: oppScale)
        }
    }

    // MARK: Background — shoji wall panels
    private func drawBg(ctx: inout GraphicsContext) {
        let bg = Path(CGRect(origin: .zero, size: CGSize(width: W, height: H)))
        let bgGrad = LinearGradient(colors: [Color(red:0.06,green:0.02,blue:0.01), Color(red:0.02,green:0.01,blue:0.0)],
                                    startPoint: .top, endPoint: .bottom)
        ctx.fill(bg, with: .linearGradient(Gradient(colors: [Color(red:0.06,green:0.02,blue:0.01), Color(red:0.02,green:0.01,blue:0.0)]),
                                           startPoint: CGPoint(x: W/2, y: 0), endPoint: CGPoint(x: W/2, y: H)))

        // Shoji panels
        let panelW = W / 5
        let panelH = H * 0.70
        for i in 0..<5 {
            let px = CGFloat(i) * panelW
            var border = Path()
            border.addRect(CGRect(x: px+1, y: 0, width: panelW-2, height: panelH))
            ctx.stroke(border, with: .color(.white.opacity(0.06)), lineWidth: 1)
            // Horizontal grid lines inside panel
            for row in 1..<5 {
                let gy = panelH / 5.0 * CGFloat(row)
                var hLine = Path()
                hLine.move(to: CGPoint(x: px+4, y: gy))
                hLine.addLine(to: CGPoint(x: px + panelW - 4, y: gy))
                ctx.stroke(hLine, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
            }
        }

        // Ambient accent glow — tints redder for boss waves
        let bossWave = waveNumber >= 5 && waveNumber % 5 == 0
        let glowColor = bossWave ? Color.red : accent
        let glowIntensity = bossWave ? 0.10 : 0.05
        ctx.fill(Path(CGRect(origin: .zero, size: CGSize(width: W, height: H))),
                 with: .color(glowColor.opacity(glowIntensity + 0.02 * sin(t * 2.1))))
    }

    // MARK: Floor — tatami
    private func drawFloor(ctx: inout GraphicsContext) {
        let floorY = feetY + 2
        // Tatami fill
        let tatami = Path(CGRect(x: 0, y: floorY, width: W, height: H - floorY))
        ctx.fill(tatami, with: .color(Color(red: 0.10, green: 0.08, blue: 0.04)))

        // Floor line
        var floorLine = Path()
        floorLine.move(to: CGPoint(x: 0, y: floorY))
        floorLine.addLine(to: CGPoint(x: W, y: floorY))
        ctx.stroke(floorLine, with: .color(accent.opacity(0.4)), lineWidth: 1.5)

        // Tatami mat lines
        for i in 1..<6 {
            let my = floorY + CGFloat(i) * (H - floorY) / 6.0
            var ml = Path(); ml.move(to: CGPoint(x: 0, y: my)); ml.addLine(to: CGPoint(x: W, y: my))
            ctx.stroke(ml, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
        }
        for i in 0..<4 {
            let vx = W / 4.0 * CGFloat(i)
            var vl = Path(); vl.move(to: CGPoint(x: vx, y: floorY)); vl.addLine(to: CGPoint(x: vx, y: H))
            ctx.stroke(vl, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
        }

        // Center line
        var cl = Path(); cl.move(to: CGPoint(x: W/2, y: floorY)); cl.addLine(to: CGPoint(x: W/2, y: H))
        ctx.stroke(cl, with: .color(accent.opacity(0.15)), lineWidth: 1)
    }

    // MARK: Lanterns
    private func drawLanterns(ctx: inout GraphicsContext) {
        let positions: [CGFloat] = [W * 0.15, W * 0.50, W * 0.85]
        for (i, lx) in positions.enumerated() {
            let flicker = 0.7 + 0.3 * sin(t * 3.7 + Double(i) * 1.3)
            let ly: CGFloat = H * 0.10

            // Cord from ceiling
            var cord = Path(); cord.move(to: CGPoint(x: lx, y: 0)); cord.addLine(to: CGPoint(x: lx, y: ly))
            ctx.stroke(cord, with: .color(.white.opacity(0.2)), lineWidth: 1)

            // Lantern body
            let lRect = CGRect(x: lx - 8, y: ly, width: 16, height: 22)
            var glow = ctx
            glow.addFilter(.shadow(color: accent.opacity(0.8 * flicker), radius: 14))
            glow.fill(Path(ellipseIn: CGRect(x: lx-8, y: ly, width: 16, height: 22)),
                      with: .color(accent.opacity(0.9 * flicker)))
            ctx.fill(Path(ellipseIn: lRect), with: .color(Color(red:1.0, green:0.85, blue:0.4).opacity(0.9 * flicker)))

            // Lantern lines
            for li in 1..<4 {
                let lineY = ly + CGFloat(li) * 22.0 / 4.0
                var ll = Path()
                ll.move(to: CGPoint(x: lx - 8, y: lineY))
                ll.addLine(to: CGPoint(x: lx + 8, y: lineY))
                ctx.stroke(ll, with: .color(.black.opacity(0.4)), lineWidth: 0.7)
            }
        }
    }

    // MARK: Dragon Aura
    private func drawDragonAura(ctx: inout GraphicsContext) {
        let cx = W * 0.22, cy = H * 0.55
        for i in 0..<24 {
            let angle = t * 2.2 + Double(i) * (2.0 * .pi / 24.0)
            let r = H * 0.14 + H * 0.04 * sin(t * 3.0 + Double(i))
            let px = cx + CGFloat(cos(angle)) * r
            let py = cy + CGFloat(sin(angle)) * r * 0.6
            let dot = Path(ellipseIn: CGRect(x: px - 3, y: py - 3, width: 6, height: 6))
            ctx.fill(dot, with: .color(Color.yellow.opacity(0.7)))
        }
        // Screen veil
        ctx.fill(Path(CGRect(origin: .zero, size: CGSize(width: W, height: H))),
                 with: .color(Color.yellow.opacity(0.05 + 0.03 * sin(t * 4))))
    }

    // MARK: Shadows under fighters
    private func drawShadows(ctx: inout GraphicsContext) {
        let fy = feetY + 3
        func shadow(_ cx: CGFloat) {
            let s = Path(ellipseIn: CGRect(x: cx - 16, y: fy, width: 32, height: 6))
            ctx.fill(s, with: .color(.black.opacity(0.35)))
        }
        shadow(W * 0.22)
        let oppXPositions: [CGFloat] = [W * 0.72, W * 0.60, W * 0.84]
        for (i, opp) in opponents.enumerated() {
            guard i < oppXPositions.count else { break }
            let slideX = oppXPositions[i] + (1.0 - CGFloat(opp.slideInProgress)) * W * 0.4
            shadow(slideX)
        }
    }

    // MARK: Fighter
    private func drawFighter(ctx: inout GraphicsContext, cx: CGFloat, pose: EndlessPose,
                              color: Color, flip: Bool, scale: CGFloat) {
        let mirror: CGFloat = flip ? -1 : 1
        let fy = feetY

        func pt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: cx + p.x * scale * mirror, y: fy + p.y * scale)
        }

        let headCenter = pt(CGPoint(x: 0, y: -72))
        let hipPt = pt(CGPoint(x: 0, y: 0))
        let shoulderPt = pt(pose.shoulder)

        // Head
        let headR = scale * 9
        let headRect = CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR*2, height: headR*2)
        ctx.fill(Path(ellipseIn: headRect), with: .color(color.opacity(0.9)))

        func line(_ a: CGPoint, _ b: CGPoint) {
            var p = Path()
            p.move(to: a); p.addLine(to: b)
            ctx.stroke(p, with: .color(color), lineWidth: scale * 2.4)
        }

        // Torso (shoulder → hip)
        line(shoulderPt, hipPt)
        // Neck (head → shoulder)
        line(CGPoint(x: headCenter.x, y: headCenter.y + headR), shoulderPt)
        // Right arm
        line(shoulderPt, pt(pose.rElbow))
        line(pt(pose.rElbow), pt(pose.rWrist))
        // Left arm
        line(shoulderPt, pt(pose.lElbow))
        line(pt(pose.lElbow), pt(pose.lWrist))
        // Right leg
        line(hipPt, pt(pose.rKnee))
        line(pt(pose.rKnee), pt(pose.rAnkle))
        // Left leg
        line(hipPt, pt(pose.lKnee))
        line(pt(pose.lKnee), pt(pose.lAnkle))
    }
}

// MARK: - Main View

struct KarateEndlessGameView: View {
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss

    // Phase
    @State private var phase: EndlessPhase = .ready

    // Time — 4 minutes survival
    @State private var timeLeft: Int = 240
    @State private var gameTimerTask: Task<Void, Never>?

    // Player
    @State private var playerHP: Double = 100
    private let maxPlayerHP: Double = 100

    // Wave & opponents
    @State private var waveNumber: Int = 1
    @State private var opponents: [WaveOpponent] = []
    @State private var score: Int = 0
    @State private var highScore: Int = 0

    // Combo & chakra
    @State private var combo: Int = 0
    @State private var maxCombo: Int = 0
    @State private var chakra: Double = 0
    @State private var showDragonStrikeButton: Bool = false

    // Poses
    @State private var playerPose: String = "idle"
    @State private var opponentPoses: [String] = ["idle", "idle", "idle"]
    @State private var poseResetTasks: [Task<Void, Never>] = []

    // Flashes
    @State private var showCriticalFlash: Bool = false
    @State private var criticalFlashTask: Task<Void, Never>?
    @State private var actionLabel: String = ""
    @State private var actionColor: Color = Theme.brandBlue
    @State private var showActionLabel: Bool = false
    @State private var actionLabelTask: Task<Void, Never>?
    @State private var screenShake: CGFloat = 0
    @State private var showWaveBanner: Bool = false
    @State private var waveBannerTask: Task<Void, Never>?

    // AI
    @State private var aiAttackTask: Task<Void, Never>?
    @State private var lastPlayerActionTime: Date = Date()

    // Shard guard
    @State private var shardsAwarded: Bool = false

    // Haptics
    private let impactMed = UIImpactFeedbackGenerator(style: .medium)
    private let impactHvy = UIImpactFeedbackGenerator(style: .heavy)
    private let notif = UINotificationFeedbackGenerator()

    private let accentColor = Color(red: 1.0, green: 0.35, blue: 0.1)
    private let highScoreKey = "karate_endless_high_score"

    private let opponentNamePool = ["Ryu", "Ken", "Akuma", "Sagat", "Guile", "Blanka", "Zangief", "Dhalsim"]

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()

            if showCriticalFlash {
                Color.yellow.opacity(0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Karate · Endless",
                    subtitle: "4-Minute Survival · Wave Attack",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startGame() }
                )

            case .fighting:
                fightingBody
                    .offset(x: screenShake)

            case .waveClear:
                waveClearBanner

            case .result:
                resultBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    cancelAllTasks()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("EXIT")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                    }
                    .foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { highScore = UserDefaults.standard.integer(forKey: highScoreKey) }
        .onDisappear { cancelAllTasks() }
    }

    // MARK: - Fighting Body

    private var fightingBody: some View {
        VStack(spacing: 0) {
            topHUD
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)

            Divider().background(Theme.cardBorder)

            arenaSection

            Divider().background(Theme.cardBorder)

            controlsHint
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Top HUD

    private var topHUD: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                // Wave badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(waveNumber % 5 == 0 ? 0.30 : 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(waveNumber % 5 == 0 ? Color.red.opacity(0.7) : accentColor.opacity(0.3), lineWidth: 1)
                        )
                    VStack(spacing: 1) {
                        Text(waveNumber % 5 == 0 ? "BOSS" : "WAVE")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(waveNumber % 5 == 0 ? .red : accentColor.opacity(0.8))
                            .tracking(1)
                        Text("\(waveNumber)")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(waveNumber % 5 == 0 ? .red : accentColor)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }

                // Player HP bar
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("YOU")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        Spacer()
                        Text("\(Int(playerHP))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [Theme.brandBlue, Theme.brandCyan], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * min(1, playerHP / maxPlayerHP))
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: playerHP)
                        }
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .frame(maxWidth: .infinity)

                // Timer
                ZStack {
                    Circle()
                        .stroke(
                            timeLeft <= 30 ? Color.red.opacity(0.5) : accentColor.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 48, height: 48)
                    Text("\(timeLeft / 60):\(String(format: "%02d", timeLeft % 60))")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(timeLeft <= 30 ? .red : .white)
                        .contentTransition(.numericText())
                }
                .frame(width: 48)
            }

            // Score row
            HStack {
                Text("SCORE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(score)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer()
                if combo >= 2 {
                    Text("×\(combo) COMBO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("BEST")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Text("\(highScore)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(score > highScore ? .yellow : .secondary)
                }
            }

            if !opponents.isEmpty {
                OpponentHPStack(opponents: opponents, accentColor: accentColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            EndlessChakraMeter(value: chakra, accentColor: accentColor)
                .onChange(of: chakra) { _, newVal in
                    showDragonStrikeButton = newVal >= 100
                }
        }
    }

    // MARK: - Arena (Canvas)

    private var arenaSection: some View {
        ZStack {
            EndlessDojoCanvas(
                opponents: opponents,
                playerPose: playerPose,
                opponentPoses: opponentPoses,
                waveNumber: waveNumber,
                dragonActive: chakra >= 100,
                accentColor: accentColor
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            EndlessActionLabel(text: actionLabel, color: actionColor, visible: showActionLabel)

            if showDragonStrikeButton {
                VStack {
                    Spacer()
                    Button { triggerDragonStrike() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("DRAGON STRIKE")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .tracking(2)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(.rect(cornerRadius: 14))
                        .shadow(color: .yellow.opacity(0.5), radius: 16)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dy = value.translation.height
                    let dx = value.translation.width
                    if abs(dy) > abs(dx) && dy < -40 { handleBlock() }
                }
        )
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    let screenWidth = UIScreen.main.bounds.width
                    if value.location.x < screenWidth / 2 {
                        handlePunch()
                    } else {
                        handleKick()
                    }
                }
        )
        .onLongPressGesture(minimumDuration: 0.3) {
            handleStance()
        }
    }

    // MARK: - Wave Clear Banner

    private var waveClearBanner: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, accentColor], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 20)

                Text("WAVE \(waveNumber - 1) CLEAR!")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .italic()
                    .foregroundStyle(.white)

                let nextIsBoss = waveNumber % 5 == 0
                Text(nextIsBoss ? "BOSS WAVE \(waveNumber) INCOMING" : "WAVE \(waveNumber) INCOMING")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(nextIsBoss ? .red : accentColor)
                    .tracking(2)

                Text("SCORE: \(score)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Result Body

    private var resultBody: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            RadialGradient(
                colors: [accentColor.opacity(0.12), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 350
            ).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("KARATE · ENDLESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(4)

                Image(systemName: "flame.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [accentColor, .yellow], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: accentColor.opacity(0.5), radius: 20)

                Text("SURVIVED")
                    .font(.system(size: 36, weight: .black))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(.white)

                Text("WAVE \(waveNumber)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)

                HStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("SCORE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentColor.opacity(0.7))
                        Text("\(score)")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    Rectangle()
                        .fill(Theme.cardBorder)
                        .frame(width: 1, height: 50)

                    VStack(spacing: 6) {
                        Text("BEST")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(highScore)")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(score >= highScore ? .yellow : .white.opacity(0.4))
                        if score > highScore {
                            Text("NEW RECORD!")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(accentColor.opacity(0.15), lineWidth: 1)
                        )
                )

                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text("MAX COMBO: \(maxCombo)x")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Button { dismiss() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("CLAIM & EXIT")
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.8)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: accentColor.opacity(0.3), radius: 12)
                }
                .padding(.top, 8)

                Spacer()
            }
        }
    }

    // MARK: - Controls Hint

    private var controlsHint: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.brandBlue)
                Text("← PUNCH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.foundationGreen)
                Text("↑ BLOCK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "rectangle.and.hand.point.up.left.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.elitePurple)
                Text("HOLD STANCE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(accentColor)
                Text("KICK →")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        spawnWave()
        phase = .fighting
        startGameTimer()
        scheduleAIAttacks()
    }

    private func spawnWave() {
        let count = min(3, waveNumber)
        let hpScale = 1.0 + Double(waveNumber - 1) * 0.25
        let baseHP = 60.0 * hpScale * (waveNumber % 5 == 0 ? 1.8 : 1.0)  // boss waves have more HP
        var newOpponents: [WaveOpponent] = []
        for i in 0..<count {
            let name = opponentNamePool[(waveNumber * 3 + i) % opponentNamePool.count]
            newOpponents.append(WaveOpponent(hp: baseHP, maxHP: baseHP, name: name, slideInProgress: 0.0))
        }
        withAnimation { opponents = newOpponents }
        opponentPoses = Array(repeating: "idle", count: count)

        // Slide-in animation for each opponent
        for i in 0..<newOpponents.count {
            let delay = Double(i) * 0.15
            Task {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                let steps = 20
                for step in 0..<steps {
                    try? await Task.sleep(for: .milliseconds(16))
                    let progress = Double(step + 1) / Double(steps)
                    await MainActor.run {
                        if i < opponents.count {
                            opponents[i].slideInProgress = progress
                        }
                    }
                }
            }
        }
    }

    private func startGameTimer() {
        gameTimerTask?.cancel()
        gameTimerTask = Task {
            while timeLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeLeft -= 1 }
            }
            await MainActor.run { endGame() }
        }
    }

    private func scheduleAIAttacks() {
        aiAttackTask?.cancel()
        aiAttackTask = Task {
            while true {
                let baseDelay = max(1.0, 3.5 - Double(waveNumber) * 0.3)
                let delay = Double.random(in: baseDelay...(baseDelay + 1.5))
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await MainActor.run { aiAttack() }
            }
        }
    }

    private func aiAttack() {
        guard phase == .fighting else { return }
        let baseDamage = 6.0 + Double(waveNumber - 1) * 1.5 * (waveNumber % 5 == 0 ? 1.5 : 1.0)
        let damage = Double.random(in: baseDamage...(baseDamage + 8))
        playerHP = max(0, playerHP - damage)
        // Set first living opponent to punch pose, set player to hit
        if !opponents.isEmpty {
            setOpponentPose("punch", index: 0, duration: 0.35)
        }
        setPlayerPose("hit", duration: 0.4)
        flashScreenShake()
        impactHvy.impactOccurred()
        if playerHP <= 0 { endGame() }
    }

    // MARK: - Player Actions

    private func handlePunch() {
        guard phase == .fighting, !opponents.isEmpty else { return }
        let now = Date()
        let isCritical = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now

        let damage: Double = (isCritical ? 10 : 7) + Double(combo) * 1.2
        applyDamageToOpponents(damage: damage)

        score += isCritical ? 2 : 1
        combo += 1
        maxCombo = max(maxCombo, combo)
        chakra = min(100, chakra + (isCritical ? 14 : 8))

        setPlayerPose("punch", duration: 0.3)
        if !opponents.isEmpty { setOpponentPose("hit", index: 0, duration: 0.35) }
        showAction(text: isCritical ? "CRITICAL PUNCH!" : "PUNCH", color: Theme.brandBlue)
        if isCritical { triggerCriticalFlash() }
        flashScreenShake()
        impactMed.impactOccurred()
    }

    private func handleKick() {
        guard phase == .fighting, !opponents.isEmpty else { return }
        let now = Date()
        let isCritical = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now

        let damage: Double = (isCritical ? 16 : 11) + Double(combo) * 1.8
        applyDamageToOpponents(damage: damage)

        score += isCritical ? 3 : 2
        combo += 1
        maxCombo = max(maxCombo, combo)
        chakra = min(100, chakra + (isCritical ? 18 : 11))

        setPlayerPose("kick", duration: 0.35)
        if !opponents.isEmpty { setOpponentPose("hit", index: 0, duration: 0.4) }
        showAction(text: isCritical ? "CRITICAL KICK!" : "KICK", color: accentColor)
        if isCritical { triggerCriticalFlash() }
        flashScreenShake()
        impactHvy.impactOccurred()
    }

    private func handleBlock() {
        guard phase == .fighting else { return }
        combo = 0
        playerHP = min(maxPlayerHP, playerHP + 4)
        setPlayerPose("block", duration: 0.5)
        showAction(text: "BLOCK", color: Theme.foundationGreen)
        impactMed.impactOccurred()
    }

    private func handleStance() {
        guard phase == .fighting else { return }
        chakra = min(100, chakra + 10)
        setPlayerPose("dragon", duration: 0.6)
        showAction(text: "STANCE", color: Theme.elitePurple)
        impactMed.impactOccurred()
    }

    private func triggerDragonStrike() {
        guard phase == .fighting, chakra >= 100 else { return }
        chakra = 0
        showDragonStrikeButton = false

        for i in opponents.indices {
            opponents[i] = WaveOpponent(
                hp: max(0, opponents[i].hp - 55),
                maxHP: opponents[i].maxHP,
                name: opponents[i].name,
                slideInProgress: opponents[i].slideInProgress
            )
        }
        score += 15
        combo += 3
        maxCombo = max(maxCombo, combo)

        setPlayerPose("dragon", duration: 0.8)
        for i in 0..<opponents.count { setOpponentPose("hit", index: i, duration: 0.6) }
        showAction(text: "DRAGON STRIKE!", color: .yellow)
        triggerCriticalFlash()
        flashScreenShake()
        notif.notificationOccurred(.success)

        withAnimation { opponents.removeAll { $0.hp <= 0 } }
        opponentPoses = Array(repeating: "idle", count: opponents.count)
        if opponents.isEmpty { advanceWave() }
    }

    private func applyDamageToOpponents(damage: Double) {
        guard !opponents.isEmpty else { return }
        var updated = opponents
        let newHP = max(0, updated[0].hp - damage)
        updated[0] = WaveOpponent(hp: newHP, maxHP: updated[0].maxHP, name: updated[0].name,
                                  slideInProgress: updated[0].slideInProgress)

        if newHP <= 0 {
            updated.removeFirst()
            if !opponentPoses.isEmpty { opponentPoses.removeFirst() }
        }
        withAnimation { opponents = updated }

        if opponents.isEmpty { advanceWave() }
    }

    private func advanceWave() {
        guard phase == .fighting else { return }
        aiAttackTask?.cancel()
        phase = .waveClear
        waveNumber += 1

        waveBannerTask?.cancel()
        waveBannerTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                phase = .fighting
                playerHP = min(maxPlayerHP, playerHP + 15)
                spawnWave()
                scheduleAIAttacks()
            }
        }
    }

    // MARK: - Pose Helpers

    private func setPlayerPose(_ pose: String, duration: Double) {
        playerPose = pose
        Task {
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
            await MainActor.run { playerPose = "idle" }
        }
    }

    private func setOpponentPose(_ pose: String, index: Int, duration: Double) {
        guard index < opponentPoses.count else { return }
        opponentPoses[index] = pose
        Task {
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
            await MainActor.run {
                if index < opponentPoses.count { opponentPoses[index] = "idle" }
            }
        }
    }

    // MARK: - FX

    private func showAction(text: String, color: Color) {
        actionLabel = text
        actionColor = color
        withAnimation { showActionLabel = true }
        actionLabelTask?.cancel()
        actionLabelTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { showActionLabel = false }
                if combo > 0 { combo -= 1 }
            }
        }
    }

    private func triggerCriticalFlash() {
        withAnimation(.easeOut(duration: 0.08)) { showCriticalFlash = true }
        criticalFlashTask?.cancel()
        criticalFlashTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(.easeIn(duration: 0.25)) { showCriticalFlash = false } }
        }
    }

    private func flashScreenShake() {
        withAnimation(.easeOut(duration: 0.06)) { screenShake = 7 }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run { withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { screenShake = 0 } }
        }
    }

    // MARK: - End Game

    private func endGame() {
        guard phase == .fighting || phase == .waveClear else { return }
        cancelAllTasks()
        awardShards()
        saveHighScore()
        withAnimation { phase = .result }
    }

    private func awardShards() {
        guard !shardsAwarded else { return }
        shardsAwarded = true
        let waveBonus = (waveNumber - 1) * 5
        let shards = min(50, 15 + waveBonus)
        viewModel.profile.evolutionShards += shards
        SaveSystem.saveProfile(viewModel.profile)
    }

    private func saveHighScore() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(score, forKey: highScoreKey)
        }
    }

    private func cancelAllTasks() {
        gameTimerTask?.cancel()
        aiAttackTask?.cancel()
        actionLabelTask?.cancel()
        criticalFlashTask?.cancel()
        waveBannerTask?.cancel()
        poseResetTasks.forEach { $0.cancel() }
    }
}
