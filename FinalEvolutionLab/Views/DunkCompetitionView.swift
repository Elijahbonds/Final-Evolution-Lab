import SwiftUI
import AVFoundation

// MARK: - Models

private struct LobbyPlayer: Identifiable {
    let id: String
    let displayName: String
    let prq: Int
    let wins: Int
    let losses: Int
    let entryFee: CompFee
    let avatarColor: Color
    let city: String
}

private enum CompFee: Equatable {
    case practice
    case shards(Int)
    case cashComingSoon(Int)

    var label: String {
        switch self {
        case .practice:              return "Free Practice"
        case .shards(let n):         return "\(n) shards"
        case .cashComingSoon(let d): return "$\(d) — Coming Soon"
        }
    }

    var shortLabel: String {
        switch self {
        case .practice:              return "FREE"
        case .shards(let n):         return "⟁ \(n)"
        case .cashComingSoon(let d): return "$\(d) 🔒"
        }
    }

    var color: Color {
        switch self {
        case .practice:          return .green
        case .shards:            return Color(red: 0, green: 0.83, blue: 1.0)
        case .cashComingSoon:    return .yellow
        }
    }

    var isLocked: Bool {
        if case .cashComingSoon = self { return true }
        return false
    }
}

private enum CompPhase {
    case lobby, matched, setup, countdown(Int), battle, result
}

private struct CompResult {
    let playerJumps: Int
    let playerMaxHeight: Double
    let opponentJumps: Int
    let opponentMaxHeight: Double
    var playerWon: Bool { playerMaxHeight >= opponentMaxHeight }
    var payout: Int
}

// MARK: - Jump Score Record

private struct JumpRecord: Identifiable {
    let id = UUID()
    let score: Double
    let timestamp: Date
}

// MARK: - Score Popup Particle

private struct ScorePopup: Identifiable {
    let id = UUID()
    let score: Double
    var yOffset: CGFloat
    var opacity: Double
    let xPos: CGFloat
}

// MARK: - Static Lobby Data

private let lobbyPlayers: [LobbyPlayer] = [
    LobbyPlayer(id: "sky", displayName: "SkyWalker_88", prq: 82, wins: 14, losses: 3,
                entryFee: .shards(500), avatarColor: Color(red: 0.1, green: 0.7, blue: 1.0), city: "Compton, CA"),
    LobbyPlayer(id: "highrise", displayName: "HighRise", prq: 71, wins: 8, losses: 5,
                entryFee: .shards(100), avatarColor: .orange, city: "Atlanta, GA"),
    LobbyPlayer(id: "solomac", displayName: "SoloMac", prq: 65, wins: 22, losses: 12,
                entryFee: .practice, avatarColor: .green, city: "Chicago, IL"),
    LobbyPlayer(id: "vertking", displayName: "Vert_King", prq: 90, wins: 31, losses: 4,
                entryFee: .shards(1000), avatarColor: .purple, city: "Houston, TX"),
    LobbyPlayer(id: "breezy", displayName: "BreezyDunk", prq: 58, wins: 5, losses: 8,
                entryFee: .shards(100), avatarColor: Color(red: 0.95, green: 0.49, blue: 0.15), city: "Miami, FL"),
    LobbyPlayer(id: "cooljay", displayName: "CoolJay_NYC", prq: 76, wins: 17, losses: 9,
                entryFee: .shards(500), avatarColor: .cyan, city: "Brooklyn, NY"),
]

// MARK: - Feedback Labels

private let dunkFeedbacks = ["HEAT CHECK!", "HANG TIME!", "NASTY!", "POSTER!", "FILTHY!", "FACIAL!", "WINDMILL!", "BODIED!"]

// MARK: - LobbyCanvas

private struct LobbyCanvas: View {
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let W = size.width
                let H = size.height

                // -- Sky gradient base --
                let skyTop = Color(red: 0.08, green: 0.22, blue: 0.55)
                let skyMid = Color(red: 0.25, green: 0.55, blue: 0.85)
                let skyBot = Color(red: 0.85, green: 0.65, blue: 0.35)
                var skyRect = Path(); skyRect.addRect(CGRect(x: 0, y: 0, width: W, height: H * 0.6))
                ctx.fill(skyRect, with: .linearGradient(
                    Gradient(colors: [skyTop, skyMid, skyBot]),
                    startPoint: CGPoint(x: W/2, y: 0),
                    endPoint: CGPoint(x: W/2, y: H * 0.6)
                ))

                // -- Animated sun --
                let sunY = H * 0.18 + sin(t * 0.15) * 3
                let sunX = W * 0.72
                var sunGlow = ctx
                sunGlow.addFilter(.blur(radius: 18))
                var sunGlowPath = Path(); sunGlowPath.addEllipse(in: CGRect(x: sunX-30, y: sunY-30, width: 60, height: 60))
                sunGlow.fill(sunGlowPath, with: .color(Color(red: 1.0, green: 0.9, blue: 0.5).opacity(0.5)))
                var sunPath = Path(); sunPath.addEllipse(in: CGRect(x: sunX-18, y: sunY-18, width: 36, height: 36))
                ctx.fill(sunPath, with: .color(Color(red: 1.0, green: 0.95, blue: 0.6)))

                // -- Sun rays --
                for i in 0..<8 {
                    let angle = Double(i) * (.pi / 4) + t * 0.08
                    let rx = sunX + cos(angle) * 28
                    let ry = sunY + sin(angle) * 28
                    var rayPath = Path()
                    rayPath.move(to: CGPoint(x: sunX + cos(angle)*20, y: sunY + sin(angle)*20))
                    rayPath.addLine(to: CGPoint(x: rx + cos(angle)*12, y: ry + sin(angle)*12))
                    ctx.stroke(rayPath, with: .color(Color(red: 1.0, green: 0.95, blue: 0.5).opacity(0.4)), lineWidth: 1.5)
                }

                // -- Horizon floor (beach/court) --
                let horizon = H * 0.55
                var floorPath = Path()
                floorPath.addRect(CGRect(x: 0, y: horizon, width: W, height: H - horizon))
                ctx.fill(floorPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.18, green: 0.55, blue: 0.22), Color(red: 0.12, green: 0.38, blue: 0.16)]),
                    startPoint: CGPoint(x: W/2, y: horizon),
                    endPoint: CGPoint(x: W/2, y: H)
                ))

                // -- Court surface --
                var courtPath = Path()
                courtPath.addRect(CGRect(x: W*0.05, y: horizon + H*0.06, width: W*0.9, height: H*0.28))
                ctx.fill(courtPath, with: .color(Color(red: 0.14, green: 0.35, blue: 0.62).opacity(0.85)))

                // -- Court lines --
                ctx.stroke(Path(CGRect(x: W*0.06, y: horizon + H*0.07, width: W*0.88, height: H*0.26)),
                           with: .color(.white.opacity(0.3)), lineWidth: 1.5)
                var centerLine = Path()
                centerLine.move(to: CGPoint(x: W*0.5, y: horizon + H*0.07))
                centerLine.addLine(to: CGPoint(x: W*0.5, y: horizon + H*0.33))
                ctx.stroke(centerLine, with: .color(.white.opacity(0.2)), lineWidth: 1.0)
                var centerCircle = Path()
                centerCircle.addEllipse(in: CGRect(x: W*0.5-28, y: horizon+H*0.12, width: 56, height: 56))
                ctx.stroke(centerCircle, with: .color(.white.opacity(0.2)), lineWidth: 1.0)

                // -- Palm trees (animated sway) --
                drawPalmTree(ctx: ctx, x: W*0.08, y: horizon, swayT: t, scale: 0.9)
                drawPalmTree(ctx: ctx, x: W*0.92, y: horizon, swayT: t + 1.2, scale: 1.0)
                drawPalmTree(ctx: ctx, x: W*0.18, y: horizon + 8, swayT: t + 0.5, scale: 0.7)
                drawPalmTree(ctx: ctx, x: W*0.82, y: horizon + 4, swayT: t + 0.8, scale: 0.75)

                // -- Scoreboard at top --
                var sbBack = Path()
                sbBack.addRoundedRect(in: CGRect(x: W*0.2, y: H*0.03, width: W*0.6, height: H*0.11), cornerSize: CGSize(width: 6, height: 6))
                ctx.fill(sbBack, with: .color(Color.black.opacity(0.7)))
                ctx.stroke(sbBack, with: .color(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.5)), lineWidth: 1.5)

                // -- Moving crowd silhouettes --
                for i in 0..<24 {
                    let fi = Double(i)
                    let crowdX = (CGFloat(i) / 24.0) * W + CGFloat(fmod(t * 8 * (i%2 == 0 ? 1 : -1), W/4))
                    let crowdBaseY = horizon - H*0.04 + CGFloat(sin(t * 2.0 + fi * 0.7)) * 3
                    let crowdH: CGFloat = 22 + CGFloat(i % 4) * 4
                    var headPath = Path()
                    headPath.addEllipse(in: CGRect(x: crowdX-5, y: crowdBaseY-crowdH, width: 10, height: 10))
                    var bodyPath = Path()
                    bodyPath.move(to: CGPoint(x: crowdX, y: crowdBaseY-crowdH+10))
                    bodyPath.addLine(to: CGPoint(x: crowdX, y: crowdBaseY))
                    bodyPath.addLine(to: CGPoint(x: crowdX-6, y: crowdBaseY + 8))
                    bodyPath.move(to: CGPoint(x: crowdX, y: crowdBaseY))
                    bodyPath.addLine(to: CGPoint(x: crowdX+6, y: crowdBaseY + 8))
                    bodyPath.move(to: CGPoint(x: crowdX-7, y: crowdBaseY-crowdH/2))
                    bodyPath.addLine(to: CGPoint(x: crowdX+7, y: crowdBaseY-crowdH/2))
                    let crowdColor = [Color.cyan, Color.orange, Color.yellow, Color.white, Color.purple][i % 5].opacity(0.55)
                    ctx.fill(headPath, with: .color(crowdColor))
                    ctx.stroke(bodyPath, with: .color(crowdColor), lineWidth: 1.2)
                }

                // -- Ocean/water strip behind court --
                var oceanPath = Path()
                oceanPath.addRect(CGRect(x: 0, y: horizon - H*0.04, width: W, height: H*0.05))
                ctx.fill(oceanPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.05, green: 0.5, blue: 0.85).opacity(0.7), Color.clear]),
                    startPoint: CGPoint(x: W/2, y: horizon - H*0.04),
                    endPoint: CGPoint(x: W/2, y: horizon)
                ))

                // -- Wave animation --
                for w in 0..<3 {
                    let waveY = horizon - H*0.025 + CGFloat(w) * 5
                    var wavePath = Path()
                    wavePath.move(to: CGPoint(x: 0, y: waveY))
                    for x in stride(from: 0, through: W, by: 8) {
                        let wy = waveY + CGFloat(sin(Double(x)/30.0 + t*2.0 + Double(w)*1.2)) * 2.5
                        wavePath.addLine(to: CGPoint(x: x, y: wy))
                    }
                    ctx.stroke(wavePath, with: .color(.white.opacity(0.15 + Double(w)*0.05)), lineWidth: 0.8)
                }
            }
        }
    }
}

// MARK: - Canvas Helper: Palm Tree

private func drawPalmTree(ctx: GraphicsContext, x: CGFloat, y: CGFloat, swayT: Double, scale: CGFloat) {
    let sway = CGFloat(sin(swayT * 0.7)) * 5 * scale
    // Trunk
    var trunk = Path()
    trunk.move(to: CGPoint(x: x, y: y))
    trunk.addCurve(to: CGPoint(x: x + sway, y: y - 55*scale),
                   control1: CGPoint(x: x + sway*0.3, y: y - 20*scale),
                   control2: CGPoint(x: x + sway*0.7, y: y - 40*scale))
    ctx.stroke(trunk, with: .color(Color(red: 0.55, green: 0.38, blue: 0.18)), lineWidth: 5*scale)

    // Fronds
    let topX = x + sway
    let topY = y - 55*scale
    let frondAngles: [Double] = [-0.4, -0.8, -1.2, -1.6, -2.0, -2.4, -2.8, 0.0]
    for angle in frondAngles {
        let frondSway = CGFloat(sin(swayT * 1.3 + angle)) * 6 * scale
        var frond = Path()
        frond.move(to: CGPoint(x: topX, y: topY))
        let ex = topX + CGFloat(cos(angle)) * 28 * scale + frondSway
        let ey = topY + CGFloat(sin(angle)) * 16 * scale
        frond.addQuadCurve(
            to: CGPoint(x: ex, y: ey),
            control: CGPoint(x: topX + CGFloat(cos(angle)) * 14 * scale, y: topY + CGFloat(sin(angle)) * 8 * scale - 8 * scale)
        )
        ctx.stroke(frond, with: .color(Color(red: 0.15, green: 0.62, blue: 0.15).opacity(0.9)), lineWidth: 2.5*scale)
    }

    // Coconuts
    for i in 0..<2 {
        var nut = Path()
        nut.addEllipse(in: CGRect(x: topX - 4*scale + CGFloat(i)*6*scale, y: topY - 2*scale, width: 7*scale, height: 7*scale))
        ctx.fill(nut, with: .color(Color(red: 0.6, green: 0.35, blue: 0.1)))
    }
}

// MARK: - DunkArenaCanvas

private struct DunkArenaCanvas: View {
    let playerScore: Double
    let opponentScore: Double
    let playerJumps: [JumpRecord]
    let jumpProgress: Double          // 0→1→0 arc, driven by active jump
    let isJumping: Bool
    let opponentJumpPhase: Double
    let scorePopups: [ScorePopup]
    let opponentName: String
    let lastFeedback: String

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let W = size.width
                let H = size.height

                // -------------------------------------------------------
                // SKY GRADIENT
                // -------------------------------------------------------
                var skyPath = Path(); skyPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                ctx.fill(skyPath, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.04, green: 0.14, blue: 0.42),
                        Color(red: 0.1, green: 0.38, blue: 0.72),
                        Color(red: 0.72, green: 0.55, blue: 0.28)
                    ]),
                    startPoint: CGPoint(x: W/2, y: 0),
                    endPoint: CGPoint(x: W/2, y: H*0.55)
                ))

                // -------------------------------------------------------
                // SUN
                // -------------------------------------------------------
                let sunX = W * 0.8
                let sunY = H * 0.12 + CGFloat(sin(t*0.1)) * 2
                var sunBlur = ctx
                sunBlur.addFilter(.blur(radius: 20))
                var sunGlowP = Path(); sunGlowP.addEllipse(in: CGRect(x: sunX-35, y: sunY-35, width: 70, height: 70))
                sunBlur.fill(sunGlowP, with: .color(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.45)))
                var sunP = Path(); sunP.addEllipse(in: CGRect(x: sunX-16, y: sunY-16, width: 32, height: 32))
                ctx.fill(sunP, with: .color(Color(red: 1.0, green: 0.96, blue: 0.7)))

                // -------------------------------------------------------
                // VENICE BEACH OCEAN STRIP
                // -------------------------------------------------------
                let horizonY = H * 0.38
                var oceanPath = Path()
                oceanPath.addRect(CGRect(x: 0, y: horizonY - H*0.06, width: W, height: H*0.07))
                ctx.fill(oceanPath, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.05, green: 0.55, blue: 0.85).opacity(0.8),
                        Color(red: 0.1, green: 0.35, blue: 0.6).opacity(0.6)
                    ]),
                    startPoint: CGPoint(x: W/2, y: horizonY - H*0.06),
                    endPoint: CGPoint(x: W/2, y: horizonY)
                ))

                // Wave lines
                for w in 0..<4 {
                    let wy = horizonY - H*0.04 + CGFloat(w)*4
                    var wavePath = Path()
                    wavePath.move(to: CGPoint(x: 0, y: wy))
                    for x in stride(from: 0, through: W, by: 6) {
                        let waveY = wy + CGFloat(sin(Double(x)/25.0 + t*2.5 + Double(w)*0.9)) * 2.0
                        wavePath.addLine(to: CGPoint(x: x, y: waveY))
                    }
                    ctx.stroke(wavePath, with: .color(.white.opacity(0.12)), lineWidth: 0.7)
                }

                // -------------------------------------------------------
                // COURT FLOOR (perspective)
                // -------------------------------------------------------
                var courtFloor = Path()
                courtFloor.move(to: CGPoint(x: W*0.2, y: horizonY))
                courtFloor.addLine(to: CGPoint(x: W*0.8, y: horizonY))
                courtFloor.addLine(to: CGPoint(x: W, y: H))
                courtFloor.addLine(to: CGPoint(x: 0, y: H))
                courtFloor.closeSubpath()
                ctx.fill(courtFloor, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.16, green: 0.38, blue: 0.65),
                        Color(red: 0.08, green: 0.22, blue: 0.42)
                    ]),
                    startPoint: CGPoint(x: W/2, y: horizonY),
                    endPoint: CGPoint(x: W/2, y: H)
                ))

                // -- Perspective court lines --
                let vanishX = W * 0.5
                let vanishY = horizonY
                for i in 0..<6 {
                    let baseX = W * CGFloat(i) / 5.0
                    var line = Path()
                    line.move(to: CGPoint(x: vanishX, y: vanishY))
                    line.addLine(to: CGPoint(x: baseX, y: H))
                    ctx.stroke(line, with: .color(.white.opacity(0.1)), lineWidth: 0.8)
                }
                // Horizontal depth lines
                for d in 0..<7 {
                    let depthT = CGFloat(d+1) / 8.0
                    let lineY = horizonY + (H - horizonY) * depthT
                    let spreadX = W * 0.2 * depthT
                    var hLine = Path()
                    hLine.move(to: CGPoint(x: W*0.2 + spreadX, y: lineY))
                    hLine.addLine(to: CGPoint(x: W*0.8 + spreadX*0.5, y: lineY))
                    // Actually use correct perspective spread
                    let leftX  = vanishX - (vanishX - 0)  * depthT
                    let rightX = vanishX + (W - vanishX) * depthT
                    var depthLine = Path()
                    depthLine.move(to: CGPoint(x: leftX, y: lineY))
                    depthLine.addLine(to: CGPoint(x: rightX, y: lineY))
                    ctx.stroke(depthLine, with: .color(.white.opacity(0.07 + Double(d)*0.01)), lineWidth: 0.7)
                }

                // Three-point arc (painted on court floor)
                var arcPath = Path()
                arcPath.addArc(center: CGPoint(x: W*0.5, y: H*0.92),
                               radius: H*0.24,
                               startAngle: .degrees(200),
                               endAngle: .degrees(340),
                               clockwise: false)
                ctx.stroke(arcPath, with: .color(.white.opacity(0.15)), lineWidth: 1.2)

                // Key box
                var keyBox = Path()
                keyBox.addRect(CGRect(x: W*0.35, y: H*0.72, width: W*0.3, height: H*0.2))
                ctx.stroke(keyBox, with: .color(.white.opacity(0.12)), lineWidth: 1.0)

                // Center circle on floor
                var cCircle = Path()
                cCircle.addEllipse(in: CGRect(x: W*0.38, y: H*0.78, width: W*0.24, height: H*0.08))
                ctx.stroke(cCircle, with: .color(.white.opacity(0.08)), lineWidth: 0.8)

                // -------------------------------------------------------
                // PALM TREES
                // -------------------------------------------------------
                drawPalmTree(ctx: ctx, x: W*0.05, y: horizonY+4, swayT: t, scale: 1.1)
                drawPalmTree(ctx: ctx, x: W*0.95, y: horizonY+4, swayT: t+1.4, scale: 1.0)
                drawPalmTree(ctx: ctx, x: W*0.14, y: horizonY+10, swayT: t+0.6, scale: 0.75)
                drawPalmTree(ctx: ctx, x: W*0.86, y: horizonY+8, swayT: t+1.0, scale: 0.8)

                // -------------------------------------------------------
                // CROWD PARTICLES (20+ dots pulsing)
                // -------------------------------------------------------
                for i in 0..<28 {
                    let fi = Double(i)
                    let crowdX = (CGFloat(i) / 28.0) * W * 1.1 - W*0.05
                    let crowdBaseY = horizonY - 10 + CGFloat(sin(t*2.4 + fi * 0.55)) * 4
                    let pulseSz: CGFloat = 5 + CGFloat(sin(t*3 + fi)) * 2
                    var crowdDot = Path()
                    crowdDot.addEllipse(in: CGRect(x: crowdX - pulseSz/2, y: crowdBaseY - pulseSz/2,
                                                    width: pulseSz, height: pulseSz))
                    let colors: [Color] = [.cyan, .orange, .yellow, .white, .purple, .green, .pink]
                    ctx.fill(crowdDot, with: .color(colors[i % colors.count].opacity(0.55)))

                    // Little raised-arms silhouette for crowd
                    var arm1 = Path()
                    arm1.move(to: CGPoint(x: crowdX, y: crowdBaseY - pulseSz/2))
                    arm1.addLine(to: CGPoint(x: crowdX - 5, y: crowdBaseY - pulseSz/2 - 7 + CGFloat(sin(t*2+fi))*2))
                    var arm2 = Path()
                    arm2.move(to: CGPoint(x: crowdX, y: crowdBaseY - pulseSz/2))
                    arm2.addLine(to: CGPoint(x: crowdX + 5, y: crowdBaseY - pulseSz/2 - 7 + CGFloat(sin(t*2+fi+1))*2))
                    ctx.stroke(arm1, with: .color(colors[i % colors.count].opacity(0.4)), lineWidth: 0.8)
                    ctx.stroke(arm2, with: .color(colors[i % colors.count].opacity(0.4)), lineWidth: 0.8)
                }

                // -------------------------------------------------------
                // BACKBOARD + RIM (top-right area)
                // -------------------------------------------------------
                let rimX = W * 0.75
                let rimBaseY = H * 0.22
                let netSway = CGFloat(sin(t * 2.2)) * 3

                // Backboard pole
                var poleP = Path()
                poleP.move(to: CGPoint(x: rimX + 20, y: horizonY))
                poleP.addLine(to: CGPoint(x: rimX + 20, y: rimBaseY + 20))
                ctx.stroke(poleP, with: .color(Color(red: 0.55, green: 0.55, blue: 0.6)), lineWidth: 4)

                // Backboard metallic face
                var bbPath = Path()
                bbPath.addRoundedRect(in: CGRect(x: rimX - 22, y: rimBaseY - 22, width: 80, height: 52),
                                       cornerSize: CGSize(width: 3, height: 3))
                ctx.fill(bbPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.82, green: 0.84, blue: 0.88), Color(red: 0.55, green: 0.58, blue: 0.64)]),
                    startPoint: CGPoint(x: rimX, y: rimBaseY-22),
                    endPoint: CGPoint(x: rimX, y: rimBaseY+30)
                ))
                ctx.stroke(bbPath, with: .color(.white.opacity(0.5)), lineWidth: 1.5)

                // Backboard inner box
                var bbInner = Path()
                bbInner.addRect(CGRect(x: rimX - 8, y: rimBaseY - 8, width: 52, height: 30))
                ctx.stroke(bbInner, with: .color(.white.opacity(0.35)), lineWidth: 1.0)

                // Rim (orange)
                var rimPath = Path()
                rimPath.addEllipse(in: CGRect(x: rimX - 20, y: rimBaseY + 28, width: 44, height: 10))
                var rimGlow = ctx
                rimGlow.addFilter(.blur(radius: 5))
                var rimGlowP = Path()
                rimGlowP.addEllipse(in: CGRect(x: rimX - 22, y: rimBaseY + 26, width: 48, height: 14))
                rimGlow.fill(rimGlowP, with: .color(Color(red: 1.0, green: 0.42, blue: 0.1).opacity(0.4)))
                ctx.stroke(rimPath, with: .color(Color(red: 1.0, green: 0.45, blue: 0.1)), lineWidth: 3.5)

                // Net (animated sway)
                let netTopL = CGPoint(x: rimX - 20, y: rimBaseY + 33)
                let netTopR = CGPoint(x: rimX + 24, y: rimBaseY + 33)
                let netBot  = CGPoint(x: rimX + 2 + netSway, y: rimBaseY + 60)
                for n in 0..<5 {
                    let tFrac = CGFloat(n) / 4.0
                    var netLine = Path()
                    let nx = netTopL.x + (netTopR.x - netTopL.x) * tFrac
                    netLine.move(to: CGPoint(x: nx, y: rimBaseY + 33))
                    netLine.addLine(to: CGPoint(x: netBot.x - 8 + tFrac*16, y: netBot.y))
                    ctx.stroke(netLine, with: .color(.white.opacity(0.35)), lineWidth: 0.8)
                }
                for n in 0..<4 {
                    let hFrac = CGFloat(n+1) / 5.0
                    let leftX = netTopL.x + (netBot.x - 8 - netTopL.x) * hFrac
                    let rightX = netTopR.x + (netBot.x + 8 - netTopR.x) * hFrac
                    let netY = netTopL.y + (netBot.y - netTopL.y) * hFrac
                    var netH = Path()
                    netH.move(to: CGPoint(x: leftX, y: netY))
                    netH.addLine(to: CGPoint(x: rightX, y: netY))
                    ctx.stroke(netH, with: .color(.white.opacity(0.25)), lineWidth: 0.6)
                }

                // -------------------------------------------------------
                // JUMP HEIGHT METER (left edge)
                // -------------------------------------------------------
                let meterX: CGFloat = 18
                let meterTop = H * 0.25
                let meterBot = H * 0.85
                let meterH   = meterBot - meterTop

                // Meter background track
                var meterBg = Path()
                meterBg.addRoundedRect(in: CGRect(x: meterX - 6, y: meterTop, width: 12, height: meterH),
                                        cornerSize: CGSize(width: 3, height: 3))
                ctx.fill(meterBg, with: .color(.black.opacity(0.55)))
                ctx.stroke(meterBg, with: .color(.white.opacity(0.2)), lineWidth: 0.8)

                // Meter fill (driven by jumpProgress)
                let meterFill = CGFloat(sin(jumpProgress * .pi))
                if meterFill > 0 {
                    let fillH = meterH * meterFill
                    var meterFillPath = Path()
                    meterFillPath.addRoundedRect(
                        in: CGRect(x: meterX - 5, y: meterBot - fillH, width: 10, height: fillH),
                        cornerSize: CGSize(width: 2, height: 2)
                    )
                    // Glow
                    var mGlow = ctx
                    mGlow.addFilter(.blur(radius: 6))
                    var mGlowPath = Path()
                    mGlowPath.addRoundedRect(
                        in: CGRect(x: meterX - 8, y: meterBot - fillH - 4, width: 16, height: fillH + 8),
                        cornerSize: CGSize(width: 4, height: 4)
                    )
                    mGlow.fill(mGlowPath, with: .color(Color.cyan.opacity(0.45)))
                    ctx.fill(meterFillPath, with: .linearGradient(
                        Gradient(colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.7)]),
                        startPoint: CGPoint(x: meterX, y: meterBot - fillH),
                        endPoint: CGPoint(x: meterX, y: meterBot)
                    ))
                }

                // Meter tick marks
                for tick in 0..<5 {
                    let tickY = meterTop + meterH * CGFloat(tick) / 4.0
                    var tickPath = Path()
                    tickPath.move(to: CGPoint(x: meterX - 9, y: tickY))
                    tickPath.addLine(to: CGPoint(x: meterX + 9, y: tickY))
                    ctx.stroke(tickPath, with: .color(.white.opacity(0.25)), lineWidth: 0.6)
                }

                // "HT" label top of meter
                ctx.draw(Text("HT").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.4)),
                         at: CGPoint(x: meterX, y: meterTop - 8))

                // -------------------------------------------------------
                // PLAYER STICK FIGURE (left side)
                // -------------------------------------------------------
                let playerBaseX = W * 0.28
                let playerFloorY = H * 0.78
                let jumpArc = CGFloat(sin(jumpProgress * .pi))
                let playerY = playerFloorY - jumpArc * H * 0.28

                drawStickFigure(ctx: ctx,
                                x: playerBaseX,
                                floorY: playerFloorY,
                                currentY: playerY,
                                jumpArc: jumpArc,
                                color: Color(red: 0.0, green: 0.9, blue: 1.0),
                                isLeft: true,
                                t: t)

                // Shadow under player
                let shadowAlpha = 0.35 * (1 - Double(jumpArc) * 0.7)
                let shadowW = 22 + jumpArc * (-8)
                var shadowPath = Path()
                shadowPath.addEllipse(in: CGRect(x: playerBaseX - shadowW/2, y: playerFloorY + 2,
                                                  width: shadowW, height: 5))
                ctx.fill(shadowPath, with: .color(.black.opacity(shadowAlpha)))

                // -------------------------------------------------------
                // OPPONENT STICK FIGURE (right side)
                // -------------------------------------------------------
                let oppBaseX = W * 0.68
                let oppFloorY = H * 0.78
                let oppArc = CGFloat(sin(opponentJumpPhase * .pi))
                let oppY = oppFloorY - oppArc * H * 0.28

                drawStickFigure(ctx: ctx,
                                x: oppBaseX,
                                floorY: oppFloorY,
                                currentY: oppY,
                                jumpArc: oppArc,
                                color: Color(red: 1.0, green: 0.38, blue: 0.1),
                                isLeft: false,
                                t: t)

                let oppShadowAlpha = 0.35 * (1 - Double(oppArc) * 0.7)
                let oppShadowW = 22 + oppArc * (-8)
                var oppShadowPath = Path()
                oppShadowPath.addEllipse(in: CGRect(x: oppBaseX - oppShadowW/2, y: oppFloorY + 2,
                                                     width: oppShadowW, height: 5))
                ctx.fill(oppShadowPath, with: .color(.black.opacity(oppShadowAlpha)))

                // -------------------------------------------------------
                // NAME TAGS above figures
                // -------------------------------------------------------
                let playerNameY = playerY - 45
                ctx.draw(
                    Text("YOU")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.cyan),
                    at: CGPoint(x: playerBaseX, y: playerNameY)
                )
                let oppName = String(opponentName.prefix(8)).uppercased()
                ctx.draw(
                    Text(oppName)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.1)),
                    at: CGPoint(x: oppBaseX, y: oppY - 45)
                )

                // -------------------------------------------------------
                // SCORE HUD PANEL (top center)
                // -------------------------------------------------------
                var hudBack = Path()
                hudBack.addRoundedRect(in: CGRect(x: W*0.15, y: 8, width: W*0.7, height: 40),
                                        cornerSize: CGSize(width: 8, height: 8))
                ctx.fill(hudBack, with: .color(.black.opacity(0.65)))
                ctx.stroke(hudBack, with: .color(Color.cyan.opacity(0.4)), lineWidth: 1)

                let playerScoreStr = String(format: "YOU: %.1f/30", playerScore)
                let oppScoreStr    = String(format: "%.1f/30 :%@", opponentScore, opponentName.prefix(6).uppercased())
                ctx.draw(
                    Text(playerScoreStr)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.cyan),
                    at: CGPoint(x: W*0.3, y: 28)
                )
                ctx.draw(
                    Text("VS")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5)),
                    at: CGPoint(x: W*0.5, y: 28)
                )
                ctx.draw(
                    Text(oppScoreStr)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.1)),
                    at: CGPoint(x: W*0.72, y: 28)
                )

                // -------------------------------------------------------
                // FEEDBACK TEXT
                // -------------------------------------------------------
                if !lastFeedback.isEmpty {
                    let feedbackAlpha = 0.8 + sin(t * 4) * 0.2
                    var feedGlow = ctx
                    feedGlow.addFilter(.blur(radius: 10))
                    ctx.draw(
                        Text(lastFeedback)
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.yellow.opacity(feedbackAlpha)),
                        at: CGPoint(x: W*0.5, y: H*0.5)
                    )
                }

                // -------------------------------------------------------
                // SCORE POPUPS (float up from rim)
                // -------------------------------------------------------
                for popup in scorePopups {
                    let glowCtx2 = ctx
                    ctx.draw(
                        Text(String(format: "+%.1f", popup.score))
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.cyan.opacity(popup.opacity)),
                        at: CGPoint(x: popup.xPos, y: rimBaseY + 20 + popup.yOffset)
                    )
                    _ = glowCtx2 // suppress warning
                }

                // -------------------------------------------------------
                // AMBIENT LIGHT FLARE (top-right corner behind rim)
                // -------------------------------------------------------
                var flareCtx = ctx
                flareCtx.addFilter(.blur(radius: 25))
                var flarePath = Path()
                flarePath.addEllipse(in: CGRect(x: W*0.6, y: H*0.05, width: W*0.4, height: H*0.25))
                flareCtx.fill(flarePath, with: .color(Color(red: 1.0, green: 0.9, blue: 0.5).opacity(0.12 + sin(t*0.3)*0.04)))

                // -------------------------------------------------------
                // JUMP STREAK INDICATOR (bottom-left)
                // -------------------------------------------------------
                let jumpCount = playerJumps.count
                ctx.draw(
                    Text("JUMPS: \(jumpCount)/5")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55)),
                    at: CGPoint(x: W*0.17, y: H*0.92)
                )

                // Jump history dots
                for j in 0..<min(5, jumpCount) {
                    let jx = W*0.07 + CGFloat(j)*14
                    let jy = H*0.95
                    let score = j < playerJumps.count ? playerJumps[j].score : 0
                    let dotColor: Color = score >= 9.0 ? .yellow : score >= 7.5 ? .cyan : .green
                    var jDot = Path()
                    jDot.addEllipse(in: CGRect(x: jx-5, y: jy-5, width: 10, height: 10))
                    ctx.fill(jDot, with: .color(dotColor.opacity(0.8)))
                }
                for j in jumpCount..<5 {
                    let jx = W*0.07 + CGFloat(j)*14
                    let jy = H*0.95
                    var jDotEmpty = Path()
                    jDotEmpty.addEllipse(in: CGRect(x: jx-5, y: jy-5, width: 10, height: 10))
                    ctx.stroke(jDotEmpty, with: .color(.white.opacity(0.2)), lineWidth: 1.0)
                }
            }
        }
    }
}

// MARK: - Canvas Helper: Stick Figure

private func drawStickFigure(
    ctx: GraphicsContext,
    x: CGFloat,
    floorY: CGFloat,
    currentY: CGFloat,
    jumpArc: CGFloat,
    color: Color,
    isLeft: Bool,
    t: Double
) {
    let headR: CGFloat = 9
    let torsoLen: CGFloat = 26
    let armLen: CGFloat  = 18
    let legLen: CGFloat  = 22

    // Glow effect
    var glowCtx = ctx
    glowCtx.addFilter(.blur(radius: 7))

    // Y is the feet position; figure drawn upward from feet
    let feetY = currentY
    let torsoTop = feetY - legLen - torsoLen
    let headY = torsoTop - headR

    // Arms angle changes when jumping
    let armAngle: CGFloat = jumpArc > 0.3 ? -0.8 : CGFloat(sin(t * 1.2)) * 0.3
    let legSpread: CGFloat = jumpArc > 0.3 ? 12 : 6

    // Glow body
    var glowHead = Path(); glowHead.addEllipse(in: CGRect(x: x-headR-2, y: headY-headR-2, width: (headR+2)*2, height: (headR+2)*2))
    glowCtx.fill(glowHead, with: .color(color.opacity(0.25)))

    // Head
    var headPath = Path(); headPath.addEllipse(in: CGRect(x: x-headR, y: headY-headR, width: headR*2, height: headR*2))
    ctx.fill(headPath, with: .color(color.opacity(0.9)))

    // Torso
    var torso = Path()
    torso.move(to: CGPoint(x: x, y: headY + headR))
    torso.addLine(to: CGPoint(x: x, y: feetY - legLen))
    ctx.stroke(torso, with: .color(color), lineWidth: 2.5)

    // Arms (raised when jumping)
    let armDir: CGFloat = isLeft ? 1 : -1
    var leftArm = Path()
    leftArm.move(to: CGPoint(x: x, y: torsoTop + 8))
    leftArm.addLine(to: CGPoint(x: x - armLen * cos(armAngle + 0.3),
                                 y: torsoTop + 8 - armLen * sin(armAngle + 0.3) * armDir))
    ctx.stroke(leftArm, with: .color(color), lineWidth: 2.0)

    var rightArm = Path()
    rightArm.move(to: CGPoint(x: x, y: torsoTop + 8))
    rightArm.addLine(to: CGPoint(x: x + armLen * cos(armAngle + 0.3),
                                  y: torsoTop + 8 - armLen * sin(armAngle + 0.3) * armDir))
    ctx.stroke(rightArm, with: .color(color), lineWidth: 2.0)

    // Legs (spread when jumping)
    var leftLeg = Path()
    leftLeg.move(to: CGPoint(x: x, y: feetY - legLen))
    leftLeg.addLine(to: CGPoint(x: x - legSpread, y: feetY))
    ctx.stroke(leftLeg, with: .color(color), lineWidth: 2.0)

    var rightLeg = Path()
    rightLeg.move(to: CGPoint(x: x, y: feetY - legLen))
    rightLeg.addLine(to: CGPoint(x: x + legSpread, y: feetY))
    ctx.stroke(rightLeg, with: .color(color), lineWidth: 2.0)

    // Shoes
    var lShoe = Path()
    lShoe.addEllipse(in: CGRect(x: x-legSpread-5, y: feetY-3, width: 12, height: 5))
    ctx.fill(lShoe, with: .color(color.opacity(0.7)))
    var rShoe = Path()
    rShoe.addEllipse(in: CGRect(x: x+legSpread-7, y: feetY-3, width: 12, height: 5))
    ctx.fill(rShoe, with: .color(color.opacity(0.7)))

    // Ball in right hand if jumping
    if jumpArc > 0.3 {
        let ballX = x + armLen * cos(armAngle + 0.3) + 6
        let ballY = torsoTop + 8 - armLen * sin(armAngle + 0.3) * armDir - 6
        var ballPath = Path()
        ballPath.addEllipse(in: CGRect(x: ballX-7, y: ballY-7, width: 14, height: 14))
        ctx.fill(ballPath, with: .color(Color(red: 0.9, green: 0.42, blue: 0.1)))
        ctx.stroke(ballPath, with: .color(.black.opacity(0.5)), lineWidth: 0.8)
        // Ball seam lines
        var seamH = Path()
        seamH.addArc(center: CGPoint(x: ballX, y: ballY), radius: 6, startAngle: .degrees(-30), endAngle: .degrees(210), clockwise: false)
        ctx.stroke(seamH, with: .color(.black.opacity(0.3)), lineWidth: 0.6)
    }
}

// MARK: - CountdownCanvas

private struct CountdownCanvas: View {
    let number: Int

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let W = size.width
                let H = size.height

                // Sky background
                var bgPath = Path(); bgPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                ctx.fill(bgPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.04, green: 0.04, blue: 0.18), Color(red: 0.08, green: 0.15, blue: 0.35)]),
                    startPoint: CGPoint(x: W/2, y: 0),
                    endPoint: CGPoint(x: W/2, y: H)
                ))

                // Pulsing ring
                let ringPhase = fmod(t * 2.0, 1.0)
                let ringR: CGFloat = 80 + CGFloat(ringPhase) * 60
                let ringAlpha = 1.0 - ringPhase
                var ring = Path()
                ring.addEllipse(in: CGRect(x: W/2-ringR, y: H/2-ringR, width: ringR*2, height: ringR*2))
                ctx.stroke(ring, with: .color(Color.cyan.opacity(ringAlpha * 0.7)), lineWidth: 3)

                // Second ring offset
                let ring2Phase = fmod(t * 2.0 + 0.5, 1.0)
                let ring2R: CGFloat = 80 + CGFloat(ring2Phase) * 60
                var ring2 = Path()
                ring2.addEllipse(in: CGRect(x: W/2-ring2R, y: H/2-ring2R, width: ring2R*2, height: ring2R*2))
                ctx.stroke(ring2, with: .color(Color(red: 1.0, green: 0.38, blue: 0.1).opacity((1-ring2Phase)*0.5)), lineWidth: 2)

                // Glowing center circle
                var centerGlow = ctx
                centerGlow.addFilter(.blur(radius: 22))
                var centerP = Path()
                centerP.addEllipse(in: CGRect(x: W/2-45, y: H/2-45, width: 90, height: 90))
                centerGlow.fill(centerP, with: .color(Color.cyan.opacity(0.3 + sin(t*3)*0.1)))

                // Countdown number glow
                var numGlow = ctx
                numGlow.addFilter(.blur(radius: 14))
                numGlow.draw(
                    Text("\(number)")
                        .font(.system(size: 110, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.cyan.opacity(0.4)),
                    at: CGPoint(x: W/2, y: H/2)
                )

                // Countdown number solid
                ctx.draw(
                    Text("\(number)")
                        .font(.system(size: 110, weight: .black, design: .monospaced))
                        .foregroundStyle(.white),
                    at: CGPoint(x: W/2, y: H/2)
                )

                // "GET READY" label
                ctx.draw(
                    Text("GET READY")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.1).opacity(0.9)),
                    at: CGPoint(x: W/2, y: H/2 - 90)
                )

                // "JUMP ON THE RIM" label
                ctx.draw(
                    Text("JUMP ON THE RIM")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4 + sin(t*2.5)*0.2)),
                    at: CGPoint(x: W/2, y: H/2 + 85)
                )

                // Corner spark effects
                for corner in 0..<4 {
                    let cx = corner % 2 == 0 ? CGFloat(30) : W-30
                    let cy = corner < 2 ? CGFloat(30) : H-30
                    for spark in 0..<5 {
                        let sa = Double(spark) * (.pi * 2 / 5) + t * 2
                        let sr = 10 + CGFloat(sin(t*3 + Double(spark))) * 5
                        var sparkP = Path()
                        sparkP.addEllipse(in: CGRect(x: cx + CGFloat(cos(sa))*sr - 2, y: cy + CGFloat(sin(sa))*sr - 2, width: 4, height: 4))
                        ctx.fill(sparkP, with: .color(Color.cyan.opacity(0.5)))
                    }
                }
            }
        }
    }
}

// MARK: - ResultCanvas

private struct ResultCanvas: View {
    let playerWon: Bool
    let playerScore: Double
    let opponentScore: Double
    let payout: Int

    @State private var particles: [(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, color: Color, size: CGFloat)] = []

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let W = size.width
                let H = size.height

                // Background
                var bgP = Path(); bgP.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                ctx.fill(bgP, with: .linearGradient(
                    Gradient(colors: playerWon
                        ? [Color(red: 0.05, green: 0.18, blue: 0.05), Color(red: 0.02, green: 0.08, blue: 0.02)]
                        : [Color(red: 0.18, green: 0.04, blue: 0.04), Color(red: 0.08, green: 0.02, blue: 0.02)]),
                    startPoint: CGPoint(x: W/2, y: 0),
                    endPoint: CGPoint(x: W/2, y: H)
                ))

                // Grid lines (stylized)
                for i in 0..<12 {
                    let gx = W * CGFloat(i) / 11.0
                    var gLine = Path()
                    gLine.move(to: CGPoint(x: gx, y: 0))
                    gLine.addLine(to: CGPoint(x: gx, y: H))
                    ctx.stroke(gLine, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
                }
                for i in 0..<16 {
                    let gy = H * CGFloat(i) / 15.0
                    var gLine = Path()
                    gLine.move(to: CGPoint(x: 0, y: gy))
                    gLine.addLine(to: CGPoint(x: W, y: gy))
                    ctx.stroke(gLine, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
                }

                // Confetti particles (40 dots raining down)
                let confettiColors: [Color] = [.yellow, .cyan, .orange, .green, .purple, .pink, .white, .red]
                for i in 0..<40 {
                    let fi = Double(i)
                    let seed = fi * 127.3
                    let confX = CGFloat(fmod(seed * 0.7173, 1.0)) * W
                    let fallSpeed = 0.06 + CGFloat(fmod(seed * 0.3, 0.08))
                    let confY = CGFloat(fmod(CGFloat(t) * fallSpeed + CGFloat(fmod(seed * 0.5, 1.0)), 1.1)) * H
                    let confSize: CGFloat = 5 + CGFloat(fmod(seed * 0.23, 5))
                    let confColor = confettiColors[i % confettiColors.count]
                    let wobbleX = confX + CGFloat(sin(t * 1.5 + fi * 0.6)) * 12

                    var confP = Path()
                    // Mix of squares and circles
                    if i % 3 == 0 {
                        confP.addRect(CGRect(x: wobbleX - confSize/2, y: confY - confSize/2, width: confSize, height: confSize))
                    } else if i % 3 == 1 {
                        confP.addEllipse(in: CGRect(x: wobbleX - confSize/2, y: confY - confSize/2, width: confSize, height: confSize))
                    } else {
                        // Diamond shape
                        confP.move(to: CGPoint(x: wobbleX, y: confY - confSize/2))
                        confP.addLine(to: CGPoint(x: wobbleX + confSize/2, y: confY))
                        confP.addLine(to: CGPoint(x: wobbleX, y: confY + confSize/2))
                        confP.addLine(to: CGPoint(x: wobbleX - confSize/2, y: confY))
                        confP.closeSubpath()
                    }
                    ctx.fill(confP, with: .color(confColor.opacity(0.8)))
                }

                // Central glow
                var centerGlow = ctx
                centerGlow.addFilter(.blur(radius: 35))
                var centerGP = Path()
                centerGP.addEllipse(in: CGRect(x: W/2-80, y: H*0.3-80, width: 160, height: 160))
                centerGlow.fill(centerGP, with: .color((playerWon ? Color.yellow : Color.red).opacity(0.35)))

                // "YOU WIN" / "DEFEATED" title glow
                var titleGlow = ctx
                titleGlow.addFilter(.blur(radius: 12))
                titleGlow.draw(
                    Text(playerWon ? "YOU WIN" : "DEFEATED")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle((playerWon ? Color.yellow : Color.red).opacity(0.5)),
                    at: CGPoint(x: W/2, y: H * 0.3)
                )
                ctx.draw(
                    Text(playerWon ? "YOU WIN" : "DEFEATED")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle(playerWon ? Color.yellow : Color.red),
                    at: CGPoint(x: W/2, y: H * 0.3)
                )

                // "IRL DUNK RESULT" subtitle
                ctx.draw(
                    Text("IRL DUNK RESULT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5)),
                    at: CGPoint(x: W/2, y: H * 0.3 + 45)
                )

                // Score comparison bars
                let barTop = H * 0.48
                let barMaxW = W * 0.35
                let maxSc = max(playerScore, opponentScore, 10.0)

                // Player bar
                let pBarW = barMaxW * CGFloat(playerScore / maxSc)
                var pBar = Path()
                pBar.addRoundedRect(in: CGRect(x: W*0.08, y: barTop, width: pBarW, height: 18), cornerSize: CGSize(width: 4, height: 4))
                ctx.fill(pBar, with: .linearGradient(
                    Gradient(colors: [Color.cyan, Color(red: 0.0, green: 0.8, blue: 1.0)]),
                    startPoint: CGPoint(x: W*0.08, y: barTop),
                    endPoint: CGPoint(x: W*0.08 + pBarW, y: barTop)
                ))
                ctx.draw(
                    Text(String(format: "YOU  %.1f", playerScore))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white),
                    at: CGPoint(x: W*0.08 + pBarW/2, y: barTop + 9)
                )

                // Opp bar
                let oBarW = barMaxW * CGFloat(opponentScore / maxSc)
                var oBar = Path()
                oBar.addRoundedRect(in: CGRect(x: W*0.08, y: barTop + 30, width: oBarW, height: 18), cornerSize: CGSize(width: 4, height: 4))
                ctx.fill(oBar, with: .linearGradient(
                    Gradient(colors: [Color(red: 1.0, green: 0.38, blue: 0.1), Color(red: 1.0, green: 0.6, blue: 0.2)]),
                    startPoint: CGPoint(x: W*0.08, y: barTop + 30),
                    endPoint: CGPoint(x: W*0.08 + oBarW, y: barTop + 30)
                ))
                ctx.draw(
                    Text(String(format: "OPP  %.1f", opponentScore))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white),
                    at: CGPoint(x: W*0.08 + oBarW/2, y: barTop + 39)
                )

                // Payout text (if won)
                if playerWon && payout > 0 {
                    var payoutGlow = ctx
                    payoutGlow.addFilter(.blur(radius: 8))
                    payoutGlow.draw(
                        Text("+\(payout) SHARDS")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.green.opacity(0.5)),
                        at: CGPoint(x: W/2, y: H * 0.62)
                    )
                    ctx.draw(
                        Text("+\(payout) SHARDS")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.green),
                        at: CGPoint(x: W/2, y: H * 0.62)
                    )
                }

                // Corner trophy icons drawn as paths
                if playerWon {
                    for corner in [(W*0.1, H*0.1), (W*0.9, H*0.1), (W*0.1, H*0.9), (W*0.9, H*0.9)] {
                        let cx = corner.0, cy = corner.1
                        let spinAngle = t * 0.8 + cx/100
                        var star = Path()
                        for pt in 0..<5 {
                            let angle = Double(pt) * (.pi * 2 / 5) - .pi/2 + spinAngle
                            let r: CGFloat = pt == 0 ? 14 : 7
                            let px = cx + CGFloat(cos(angle)) * r
                            let py = cy + CGFloat(sin(angle)) * r
                            if pt == 0 { star.move(to: CGPoint(x: px, y: py)) }
                            else { star.addLine(to: CGPoint(x: px, y: py)) }
                            // Inner point
                            let innerAngle = angle + .pi/5
                            star.addLine(to: CGPoint(x: cx + CGFloat(cos(innerAngle))*7, y: cy + CGFloat(sin(innerAngle))*7))
                        }
                        star.closeSubpath()
                        ctx.fill(star, with: .color(Color.yellow.opacity(0.55)))
                    }
                }
            }
        }
    }
}

// MARK: - Main View

struct DunkCompetitionView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var healthKit = HealthKitService()

    // Phase + matchmaking
    @State private var phase: CompPhase = .lobby
    @State private var selectedFee: CompFee = .practice
    @State private var selectedOpponent: LobbyPlayer? = nil
    @State private var countdownVal: Int = 3
    @State private var battleTime: Int = 180
    @State private var timerTask: Task<Void, Never>? = nil

    // Battle state
    @State private var jumpRecords: [JumpRecord] = []
    @State private var maxHeight: Double = 0
    @State private var lastHeight: String = ""
    @State private var jumpFlash: Bool = false
    @State private var jumpProgress: Double = 0      // 0→1→0 for arc
    @State private var jumpAnimTask: Task<Void, Never>? = nil
    @State private var isJumping: Bool = false
    @State private var playerScore: Double = 0       // sum of best 3 scores
    @State private var jumpCount: Int = 0

    // Opponent
    @State private var opponentJumps: Int = 0
    @State private var opponentMax: Double = 0
    @State private var opponentScore: Double = 0
    @State private var opponentJumpPhase: Double = 0
    @State private var opponentJumpTask: Task<Void, Never>? = nil
    @State private var opponentUpdateTask: Task<Void, Never>? = nil

    // Score popups
    @State private var scorePopups: [ScorePopup] = []
    @State private var lastFeedback: String = ""
    @State private var feedbackTask: Task<Void, Never>? = nil

    // Result
    @State private var result: CompResult? = nil
    @State private var showCashAlert: Bool = false
    @State private var lobbyRefreshTick: Int = 0

    private let accentColor = Color(red: 1.0, green: 0.3, blue: 0.1)

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()

            switch phase {
            case .lobby:
                lobbyBody
            case .matched:
                matchedBody
            case .setup:
                setupBody
            case .countdown(let n):
                countdownPhaseBody(n)
            case .battle:
                battleBody
            case .result:
                if let r = result { resultBody(r) }
            }
        }
        .alert("Cash Mode Coming Soon", isPresented: $showCashAlert) {
            Button("Got It", role: .cancel) {}
        } message: {
            Text("Real-money competition powered by Apple Pay is in development. Use shards to compete now and earn your spot on the leaderboard.")
        }
        .onDisappear {
            timerTask?.cancel()
            opponentUpdateTask?.cancel()
            opponentJumpTask?.cancel()
            jumpAnimTask?.cancel()
            feedbackTask?.cancel()
            healthKit.stopJumpTracking()
        }
    }

    // MARK: - Lobby Phase

    private var lobbyBody: some View {
        ZStack {
            // Animated lobby canvas background
            LobbyCanvas()
                .ignoresSafeArea()
                .opacity(0.45)

            // Dark overlay for readability
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.8)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IRL DUNK COMPETITION")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .tracking(3)
                        Text("1v1 · Set up at a hoop · Make money")
                            .font(.system(size: 28, weight: .black))
                            .italic()
                            .foregroundStyle(.white)
                        Text("Battle someone live in the queue or challenge a player directly. HealthKit tracks your jump height. Highest max wins.")
                            .font(.system(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Entry Fee Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("YOUR ENTRY FEE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(2)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach([CompFee.practice, .shards(100), .shards(500), .shards(1000), .cashComingSoon(5), .cashComingSoon(20)], id: \.label) { fee in
                                    feeChip(fee)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Queue Controls
                    HStack(spacing: 12) {
                        Button { enterQueue() } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "list.number")
                                    .font(.system(size: 20, weight: .bold))
                                Text("JOIN QUEUE")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accentColor)
                            .clipShape(.rect(cornerRadius: 14))
                        }

                        Button { enterQueue() } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 20, weight: .bold))
                                Text("QUICK MATCH")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accentColor.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.3), lineWidth: 1))
                            .clipShape(.rect(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)

                    // Live Lobby
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("LIVE LOBBY")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .tracking(2)
                            Circle().fill(.green).frame(width: 6, height: 6).symbolEffect(.pulse)
                            Text("\(lobbyPlayers.count) online")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 10) {
                            ForEach(lobbyPlayers) { player in
                                lobbyRow(player)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    howItWorksCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func feeChip(_ fee: CompFee) -> some View {
        Button {
            if fee.isLocked { showCashAlert = true; return }
            selectedFee = fee
        } label: {
            Text(fee.shortLabel)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(selectedFee == fee ? .black : (fee.isLocked ? .secondary : fee.color))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedFee == fee ? fee.color : fee.color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(fee.isLocked ? Color.white.opacity(0.1) : fee.color.opacity(0.3), lineWidth: 1))
                .clipShape(Capsule())
                .opacity(fee.isLocked ? 0.5 : 1.0)
        }
    }

    private func lobbyRow(_ player: LobbyPlayer) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(player.avatarColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(player.displayName.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(player.avatarColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(player.displayName)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text("PRQ \(player.prq)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text("\(player.wins)W \(player.losses)L")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text(player.city)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(player.entryFee.shortLabel)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(player.entryFee.color)

                Button {
                    if player.entryFee.isLocked { showCashAlert = true; return }
                    selectedOpponent = player
                    enterQueue()
                } label: {
                    Text("CHALLENGE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW IT WORKS")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)

            ForEach(Array(zip(
                ["1", "2", "3", "4"],
                [
                    ("camera.fill", "Set up your phone on a tripod facing a regulation 10-ft rim"),
                    ("heart.fill", "Enable HealthKit — it tracks every jump height automatically"),
                    ("timer", "3-minute window · Both players jump as many times as possible"),
                    ("trophy.fill", "Highest max vertical wins the entry fee pot"),
                ]
            )), id: \.0) { num, item in
                HStack(alignment: .top, spacing: 14) {
                    Text(num)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .frame(width: 20)
                    Image(systemName: item.0)
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor.opacity(0.7))
                        .frame(width: 18)
                    Text(item.1)
                        .font(.system(.caption))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - Matched Phase

    private var matchedBody: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("MATCH FOUND")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .tracking(4)

            HStack(spacing: 24) {
                playerPod(name: "YOU",
                          sub: "PRQ \(Int(viewModel.effectiveMetrics.prqScore))",
                          color: accentColor)
                Text("VS")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                playerPod(name: selectedOpponent?.displayName ?? "Opponent",
                          sub: "PRQ \(selectedOpponent?.prq ?? 70)",
                          color: selectedOpponent?.avatarColor ?? .red)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 6) {
                Text("Entry Fee: \(selectedFee.label)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(selectedFee.color)
                Text("Highest max jump in 3 minutes wins")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }

            Button { phase = .setup } label: {
                Text("ACCEPT & SETUP")
                    .font(.system(.subheadline, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button { phase = .lobby } label: {
                Text("Decline")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func playerPod(name: String, sub: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 64, height: 64)
                Text(String(name.prefix(2)).uppercased())
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }
            Text(name)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Setup Phase

    private var setupBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("SETUP REQUIRED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .tracking(3)
                        .padding(.top, 32)
                    Text("Proctored Session")
                        .font(.system(size: 28, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                }

                setupSteps

                HStack(spacing: 10) {
                    Image(systemName: healthKit.isAuthorized ? "checkmark.circle.fill" : "heart.fill")
                        .foregroundStyle(healthKit.isAuthorized ? .green : .red)
                    Text(healthKit.isAuthorized
                         ? "HealthKit connected — jumps will be tracked automatically"
                         : "HealthKit required for verified competition")
                        .font(.system(.caption))
                        .foregroundStyle(healthKit.isAuthorized ? .green : .red)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill((healthKit.isAuthorized ? Color.green : Color.red).opacity(0.08)))
                .padding(.horizontal, 20)

                if !healthKit.isAuthorized {
                    Button { Task { await healthKit.requestAuthorization() } } label: {
                        Text("CONNECT HEALTHKIT")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(accentColor)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                }

                Button { beginCountdown() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                        Text(healthKit.isAuthorized ? "I'M SET UP — START" : "START (Simulation Mode)")
                    }
                    .font(.system(.subheadline, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(healthKit.isAuthorized ? accentColor : Color.white.opacity(0.25))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var setupSteps: some View {
        VStack(spacing: 12) {
            ForEach(Array(zip(
                ["01", "02", "03", "04"],
                [
                    ("iphone.and.arrow.forward", "Place your phone on a tripod angled to capture your full vertical leap"),
                    ("figure.basketball", "Position yourself under a regulation 10-foot rim"),
                    ("camera.on.rectangle.fill", "Make sure your full body is in frame from feet to peak jump"),
                    ("checkmark.shield.fill", "Both players confirm ready — competition starts simultaneously"),
                ]
            )), id: \.0) { num, item in
                HStack(alignment: .top, spacing: 14) {
                    Text(num)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .frame(width: 24)
                    Image(systemName: item.0)
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                        .frame(width: 24)
                    Text(item.1)
                        .font(.system(.subheadline))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.1), lineWidth: 1)))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Countdown Phase

    private func countdownPhaseBody(_ n: Int) -> some View {
        ZStack {
            CountdownCanvas(number: n)
                .ignoresSafeArea()
        }
    }

    // MARK: - Battle Phase

    private var battleBody: some View {
        ZStack(alignment: .bottom) {
            // Full-screen canvas arena
            DunkArenaCanvas(
                playerScore: playerScore,
                opponentScore: opponentScore,
                playerJumps: jumpRecords,
                jumpProgress: jumpProgress,
                isJumping: isJumping,
                opponentJumpPhase: opponentJumpPhase,
                scorePopups: scorePopups,
                opponentName: selectedOpponent?.displayName ?? "Opponent",
                lastFeedback: lastFeedback
            )
            .ignoresSafeArea()

            // Overlay HUD at bottom
            VStack(spacing: 0) {
                Spacer()

                // Timer + scoreboard bar
                HStack {
                    VStack(spacing: 2) {
                        Text("TIME")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(timeFormatted)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(battleTime <= 30 ? .red : .white)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("YOUR MAX")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f\"", maxHeight))
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("JUMPS")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(jumpRecords.count)/5")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.85))

                // JUMP button
                Button {
                    recordJump()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isJumping ? accentColor.opacity(0.4) : accentColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.3), lineWidth: 1.5)
                            )

                        VStack(spacing: 4) {
                            Text(isJumping ? "IN AIR..." : "JUMP")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(isJumping ? .white.opacity(0.6) : .white)
                            if !lastHeight.isEmpty {
                                Text(lastHeight)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    .frame(height: 72)
                    .padding(.horizontal, 24)
                }
                .disabled(isJumping || jumpRecords.count >= 5)
                .padding(.top, 8)

                if healthKit.isAuthorized {
                    Text("HealthKit is counting your real jumps")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                Button { endBattle() } label: {
                    Text("END EARLY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Result Phase

    private func resultBody(_ r: CompResult) -> some View {
        ZStack {
            ResultCanvas(
                playerWon: r.playerWon,
                playerScore: r.playerMaxHeight,
                opponentScore: r.opponentMaxHeight,
                payout: r.payout
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 0)
                        .padding(.top, 280)

                    if r.playerWon {
                        HStack(spacing: 8) {
                            Image(systemName: "diamond.fill")
                                .foregroundStyle(Theme.brandCyan)
                            Text("+\(r.payout) shards earned")
                                .font(.system(.headline, design: .monospaced, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.3), lineWidth: 1)))
                        .padding(.horizontal, 20)
                    }

                    HStack(spacing: 16) {
                        compStat("YOUR MAX", value: String(format: "%.1f\"", r.playerMaxHeight), icon: "arrow.up.circle.fill", color: accentColor)
                        compStat("JUMPS", value: "\(r.playerJumps)", icon: "figure.basketball", color: .cyan)
                        compStat("THEIR MAX", value: String(format: "%.1f\"", r.opponentMaxHeight), icon: "person.fill", color: selectedOpponent?.avatarColor ?? .red)
                    }
                    .padding(.horizontal, 20)

                    Button { dismiss() } label: {
                        Text("BACK TO LOBBY")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(accentColor)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func compStat(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 20, weight: .black, design: .monospaced)).foregroundStyle(.white)
            Text(label).font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.06)))
    }

    // MARK: - Helpers

    private var timeFormatted: String {
        let m = battleTime / 60
        let s = battleTime % 60
        return String(format: "%d:%02d", m, s)
    }

    private func enterQueue() {
        if selectedOpponent == nil {
            selectedOpponent = lobbyPlayers.randomElement()
        }
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.5...3.0)))
            await MainActor.run { phase = .matched }
        }
    }

    private func beginCountdown() {
        countdownVal = 3
        phase = .countdown(3)
        // Haptic on countdown start
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run {
                    countdownVal = i
                    phase = .countdown(i)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run { startBattle() }
        }
    }

    private func startBattle() {
        jumpRecords = []
        maxHeight = 0
        playerScore = 0
        opponentJumps = 0
        opponentMax = 0
        opponentScore = 0
        battleTime = 180
        lastFeedback = ""
        scorePopups = []
        phase = .battle

        // Haptic — battle start
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Main countdown timer
        timerTask = Task {
            while battleTime > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { battleTime -= 1 }
            }
            await MainActor.run { endBattle() }
        }

        // HealthKit real jump tracking
        if healthKit.isAuthorized {
            healthKit.startJumpTracking { h in
                Task { @MainActor in
                    guard jumpRecords.count < 5 else { return }
                    let score = min(10.0, max(6.0, h / 4.5))
                    let record = JumpRecord(score: score, timestamp: Date())
                    jumpRecords.append(record)
                    jumpCount = jumpRecords.count
                    maxHeight = max(maxHeight, h)
                    lastHeight = String(format: "%.1f\"", h)
                    playerScore = computePlayerScore()
                    triggerJumpAnimation()
                    addScorePopup(score: score)
                    showFeedback()
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
        }

        // Simulated opponent
        opponentUpdateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 4...9)))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    opponentJumps += 1
                    let h = Double.random(in: 18...42)
                    opponentMax = max(opponentMax, h)
                    opponentScore = min(30.0, opponentScore + Double.random(in: 6.0...10.0))
                    triggerOpponentJump()
                }
            }
        }
    }

    private func computePlayerScore() -> Double {
        let scores = jumpRecords.map { $0.score }.sorted(by: >)
        let best3 = Array(scores.prefix(3))
        return best3.reduce(0, +)
    }

    private func triggerJumpAnimation() {
        guard !isJumping else { return }
        isJumping = true
        jumpAnimTask?.cancel()
        jumpAnimTask = Task {
            let steps = 60
            for i in 0...steps {
                guard !Task.isCancelled else { break }
                let progress = Double(i) / Double(steps)
                await MainActor.run { jumpProgress = progress }
                try? await Task.sleep(for: .milliseconds(16))
            }
            await MainActor.run {
                jumpProgress = 0
                isJumping = false
            }
        }
    }

    private func triggerOpponentJump() {
        opponentJumpTask?.cancel()
        opponentJumpTask = Task {
            let steps = 60
            for i in 0...steps {
                guard !Task.isCancelled else { break }
                let progress = Double(i) / Double(steps)
                await MainActor.run { opponentJumpPhase = progress }
                try? await Task.sleep(for: .milliseconds(16))
            }
            await MainActor.run { opponentJumpPhase = 0 }
        }
    }

    private func addScorePopup(score: Double) {
        let popup = ScorePopup(score: score, yOffset: 0, opacity: 1.0, xPos: CGFloat.random(in: 180...240))
        scorePopups.append(popup)

        // Animate popup upward and fade
        Task {
            for step in 0..<40 {
                guard !Task.isCancelled else { break }
                let t = Double(step) / 40.0
                await MainActor.run {
                    if let idx = scorePopups.firstIndex(where: { $0.id == popup.id }) {
                        scorePopups[idx] = ScorePopup(
                            score: popup.score,
                            yOffset: CGFloat(-t * 60),
                            opacity: 1.0 - t,
                            xPos: popup.xPos
                        )
                    }
                }
                try? await Task.sleep(for: .milliseconds(20))
            }
            await MainActor.run {
                scorePopups.removeAll { $0.id == popup.id }
            }
        }
    }

    private func showFeedback() {
        lastFeedback = dunkFeedbacks.randomElement() ?? "NASTY!"
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run { lastFeedback = "" }
        }
    }

    private func recordJump() {
        guard !isJumping, jumpRecords.count < 5 else { return }

        // Haptic — jump
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        let h = Double.random(in: 20...46)
        let score = min(10.0, max(6.0, h / 4.5))
        let record = JumpRecord(score: score, timestamp: Date())
        jumpRecords.append(record)
        jumpCount = jumpRecords.count
        maxHeight = max(maxHeight, h)
        lastHeight = String(format: "%.1f\"", h)
        playerScore = computePlayerScore()
        triggerJumpAnimation()
        addScorePopup(score: score)
        showFeedback()

        // Extra haptic feedback for high score
        if score >= 9.5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }

    private func endBattle() {
        timerTask?.cancel()
        opponentUpdateTask?.cancel()
        opponentJumpTask?.cancel()
        jumpAnimTask?.cancel()
        feedbackTask?.cancel()
        healthKit.stopJumpTracking()

        // Haptic — end
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        let won = playerScore >= opponentScore
        let payout: Int
        switch selectedFee {
        case .practice:          payout = 0
        case .shards(let n):     payout = won ? n * 2 : 0
        case .cashComingSoon:    payout = 0
        }
        if won && payout > 0 {
            viewModel.profile.evolutionShards += payout
        }
        result = CompResult(
            playerJumps: jumpRecords.count,
            playerMaxHeight: maxHeight,
            opponentJumps: opponentJumps,
            opponentMaxHeight: opponentMax,
            payout: payout
        )
        GameResultService.saveResult(modeId: "dunk_competition", userScore: Int(playerScore))
        phase = .result
    }
}
