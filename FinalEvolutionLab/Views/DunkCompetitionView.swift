import SwiftUI
import AVFoundation

// MARK: - Dunk Type

enum DunkType: String, CaseIterable {
    case windmill      = "WINDMILL"
    case reverse360    = "REVERSE 360"
    case betweenLegs   = "BETWEEN LEGS"
    case cradle        = "CRADLE"
    case tomahawk      = "TOMAHAWK"
    case doublePump    = "DOUBLE PUMP"
    case alleyOop      = "LOFT JAM"

    var comboLength: Int {
        switch self {
        case .alleyOop:    return 3
        case .tomahawk:    return 4
        case .cradle:      return 4
        case .reverse360:  return 4
        case .windmill:    return 5
        case .betweenLegs: return 5
        case .doublePump:  return 5
        }
    }

    var baseDifficulty: Int {
        switch self {
        case .alleyOop:    return 1
        case .tomahawk:    return 2
        case .cradle:      return 2
        case .reverse360:  return 3
        case .windmill:    return 4
        case .betweenLegs: return 5
        case .doublePump:  return 5
        }
    }

    var crowdFactor: CGFloat {
        switch self {
        case .alleyOop:    return 0.60
        case .tomahawk:    return 0.65
        case .cradle:      return 0.70
        case .reverse360:  return 0.75
        case .windmill:    return 0.85
        case .betweenLegs: return 0.95
        case .doublePump:  return 1.00
        }
    }

    var comboSequence: [SwipeDirection] {
        switch self {
        case .windmill:    return [.up, .right, .down, .left, .up]
        case .reverse360:  return [.right, .right, .down, .left]
        case .betweenLegs: return [.down, .right, .up, .left, .right]
        case .alleyOop:    return [.up, .up, .left]
        case .cradle:      return [.left, .down, .right, .up]
        case .tomahawk:    return [.up, .left, .up, .right]
        case .doublePump:  return [.up, .down, .up, .down, .right]
        }
    }

    var icon: String {
        switch self {
        case .windmill:    return "arrow.clockwise.circle.fill"
        case .reverse360:  return "arrow.uturn.backward.circle.fill"
        case .betweenLegs: return "figure.basketball"
        case .alleyOop:    return "arrow.up.circle.fill"
        case .cradle:      return "hand.raised.circle.fill"
        case .tomahawk:    return "bolt.circle.fill"
        case .doublePump:  return "arrow.up.arrow.down.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .windmill:    return "FULL ROTATION"
        case .reverse360:  return "TURN & BURN"
        case .betweenLegs: return "THROUGH THE LEGS"
        case .alleyOop:    return "CATCH & SLAM"
        case .cradle:      return "ROCK THE BABY"
        case .tomahawk:    return "ONE HAND JAM"
        case .doublePump:  return "FAKE & STUFF"
        }
    }
}

// MARK: - Swipe Direction

enum SwipeDirection: String, CaseIterable {
    case up, left, right, down

    var arrow: String {
        switch self {
        case .up:    return "↑"
        case .left:  return "←"
        case .right: return "→"
        case .down:  return "↓"
        }
    }
}

// MARK: - Hit Quality

enum HitQuality {
    case perfect, good, miss

    var color: Color {
        switch self {
        case .perfect: return .green
        case .good:    return .white
        case .miss:    return .red
        }
    }

    var label: String {
        switch self {
        case .perfect: return "PERFECT!"
        case .good:    return "GOOD"
        case .miss:    return "MISS!"
        }
    }

    var scoreMultiplier: CGFloat {
        switch self {
        case .perfect: return 1.0
        case .good:    return 0.65
        case .miss:    return 0.0
        }
    }
}

// Multiplier table for consecutive perfects (index = consecutive count)
private let comboMultipliers: [CGFloat] = [1.0, 1.3, 1.6, 2.0, 2.5]

// MARK: - Particles & Popups

private struct RimSpark: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var alpha: CGFloat
    var size: CGFloat
}

private struct ScorePopup: Identifiable {
    let id = UUID()
    let text: String
    var yOffset: CGFloat
    var opacity: Double
    let xPos: CGFloat
    let color: Color
}

// MARK: - Dunk Phase

private enum DunkPhase: Equatable {
    case dunkSelect
    case approach
    case comboInput
    case rimMoment
    case judgeReveal
    case aiTurn
    case finalResult
}

// MARK: - Judge Score

private struct JudgeScore: Identifiable {
    let id = UUID()
    let judgeIndex: Int
    let score: Double
    var revealed: Bool
}

// MARK: - Lobby Models

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
    case lobby, matched, dunkContest, result
}

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

// MARK: - Dunk Arena Canvas

private struct DunkArenaCanvas: View {
    let runProgress: CGFloat
    let isSlowMo: Bool
    let selectedDunk: DunkType?
    let sparks: [RimSpark]
    let crowdEnergy: CGFloat
    let scorePopups: [ScorePopup]
    let rimGlow: CGFloat
    let playerScore: Double
    let aiScore: Double
    let dunkRound: Int

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let W = size.width
                let H = size.height

                // ── VENICE BEACH SKY ──────────────────────────────────────
                // California sky: deep ocean blue fading to warm horizon
                var skyPath = Path()
                skyPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                ctx.fill(skyPath, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.18, green: 0.42, blue: 0.78),
                        Color(red: 0.42, green: 0.70, blue: 0.92),
                        Color(red: 0.78, green: 0.88, blue: 0.96)
                    ]),
                    startPoint: CGPoint(x: W / 2, y: 0),
                    endPoint: CGPoint(x: W / 2, y: H * 0.55)
                ))

                // Sun: warm golden disc upper-left
                let sunX = W * 0.12, sunY = H * 0.10
                var sunGlowCtx = ctx
                sunGlowCtx.addFilter(.blur(radius: 28))
                var sunGlowPath = Path()
                sunGlowPath.addEllipse(in: CGRect(x: sunX - 30, y: sunY - 30, width: 60, height: 60))
                sunGlowCtx.fill(sunGlowPath, with: .color(Color(red: 1.0, green: 0.92, blue: 0.30).opacity(0.75)))
                var sunPath = Path()
                sunPath.addEllipse(in: CGRect(x: sunX - 14, y: sunY - 14, width: 28, height: 28))
                ctx.fill(sunPath, with: .color(Color(red: 1.0, green: 0.94, blue: 0.45)))

                // Ocean strip at horizon
                let horizonY = H * 0.46
                var oceanPath = Path()
                oceanPath.addRect(CGRect(x: 0, y: horizonY, width: W, height: H * 0.06))
                ctx.fill(oceanPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.12, green: 0.48, blue: 0.82), Color(red: 0.25, green: 0.60, blue: 0.88)]),
                    startPoint: CGPoint(x: 0, y: horizonY),
                    endPoint: CGPoint(x: W, y: horizonY)
                ))
                // Ocean shimmer
                for wave in 0..<6 {
                    let wx = W * CGFloat(wave) / 5.0 + CGFloat(sin(t * 1.2 + Double(wave))) * 8
                    var wavePath = Path()
                    wavePath.move(to: CGPoint(x: wx, y: horizonY + 8))
                    wavePath.addCurve(to: CGPoint(x: wx + 30, y: horizonY + 8),
                                      control1: CGPoint(x: wx + 8, y: horizonY + 3),
                                      control2: CGPoint(x: wx + 22, y: horizonY + 3))
                    ctx.stroke(wavePath, with: .color(.white.opacity(0.25)), lineWidth: 0.8)
                }

                // Boardwalk / concrete strip between ocean and court
                let boardwalkY = H * 0.52
                var bwPath = Path()
                bwPath.addRect(CGRect(x: 0, y: boardwalkY, width: W, height: H * 0.04))
                ctx.fill(bwPath, with: .color(Color(red: 0.72, green: 0.68, blue: 0.60)))

                // ── PALM TREES ──────────────────────────────────────────────
                let floorY = H * 0.56
                let palmPositions: [(CGFloat, CGFloat, CGFloat)] = [
                    (W * 0.06, floorY, 1.0),
                    (W * 0.94, floorY, 0.85),
                    (W * 0.88, floorY - 20, 0.7)
                ]
                for (px, py, scale) in palmPositions {
                    // Trunk
                    var trunkPath = Path()
                    let trunkLean = (px < W / 2) ? -8.0 : 8.0
                    trunkPath.move(to: CGPoint(x: px, y: py))
                    trunkPath.addCurve(
                        to: CGPoint(x: px + trunkLean, y: py - 90 * scale),
                        control1: CGPoint(x: px - trunkLean * 0.3, y: py - 30 * scale),
                        control2: CGPoint(x: px + trunkLean * 0.7, y: py - 60 * scale)
                    )
                    ctx.stroke(trunkPath, with: .color(Color(red: 0.55, green: 0.38, blue: 0.18)), lineWidth: CGFloat(6 * scale))
                    // Fronds (5 leaves)
                    let frondBase = CGPoint(x: px + trunkLean, y: py - 90 * scale)
                    let frondSway = CGFloat(sin(t * 1.3 + Double(px))) * 4 * scale
                    for f in 0..<5 {
                        let angle = Double(f) * .pi * 2 / 5 + Double(t) * 0.15
                        let frondLen: CGFloat = 32 * scale
                        var frond = Path()
                        frond.move(to: frondBase)
                        frond.addCurve(
                            to: CGPoint(x: frondBase.x + cos(angle) * frondLen + frondSway,
                                        y: frondBase.y + sin(angle) * frondLen * 0.5),
                            control1: CGPoint(x: frondBase.x + cos(angle) * frondLen * 0.4,
                                              y: frondBase.y - 8),
                            control2: CGPoint(x: frondBase.x + cos(angle) * frondLen * 0.8,
                                              y: frondBase.y + sin(angle) * frondLen * 0.3)
                        )
                        ctx.stroke(frond, with: .color(Color(red: 0.12, green: 0.55, blue: 0.18)), lineWidth: CGFloat(2.5 * scale))
                    }
                }

                // ── VENICE BEACH COLORFUL COURT SURFACE ─────────────────────
                // The famous mural court: colorful geometric sections
                var courtBg = Path()
                courtBg.addRect(CGRect(x: 0, y: floorY, width: W, height: H - floorY))
                ctx.fill(courtBg, with: .color(Color(red: 0.22, green: 0.22, blue: 0.24))) // dark asphalt base

                // Colorful mural panels on court surface (Venice Beach iconic look)
                let panelColors: [Color] = [
                    Color(red: 0.90, green: 0.22, blue: 0.18),  // red
                    Color(red: 0.18, green: 0.45, blue: 0.85),  // blue
                    Color(red: 0.95, green: 0.72, blue: 0.08),  // gold
                    Color(red: 0.15, green: 0.65, blue: 0.30),  // green
                    Color(red: 0.72, green: 0.18, blue: 0.78),  // purple
                    Color(red: 0.95, green: 0.48, blue: 0.10),  // orange
                ]
                let courtH = H - floorY
                let panelW = W / CGFloat(panelColors.count)
                for (i, panelColor) in panelColors.enumerated() {
                    var panel = Path()
                    panel.addRect(CGRect(x: CGFloat(i) * panelW, y: floorY, width: panelW, height: courtH * 0.55))
                    ctx.fill(panel, with: .color(panelColor.opacity(0.30)))
                    // Panel border lines
                    var pBorder = Path()
                    pBorder.addRect(CGRect(x: CGFloat(i) * panelW, y: floorY, width: panelW, height: courtH * 0.55))
                    ctx.stroke(pBorder, with: .color(panelColor.opacity(0.15)), lineWidth: 0.5)
                }

                // Court boundary white line
                var courtLine = Path()
                courtLine.addRect(CGRect(x: W * 0.04, y: floorY + 4, width: W * 0.92, height: courtH * 0.85))
                ctx.stroke(courtLine, with: .color(.white.opacity(0.55)), lineWidth: 1.5)

                // Three-point arc
                var arcPath = Path()
                arcPath.addArc(center: CGPoint(x: W * 0.80, y: floorY + courtH * 0.4),
                               radius: W * 0.22, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                ctx.stroke(arcPath, with: .color(.white.opacity(0.45)), lineWidth: 1.2)

                // Paint / key rectangle
                let paintLeft  = W * 0.62
                let paintRight = W * 0.88
                var paintRect = Path()
                paintRect.addRect(CGRect(x: paintLeft, y: floorY, width: paintRight - paintLeft, height: H - floorY))
                ctx.stroke(paintRect, with: .color(.white.opacity(0.40)), lineWidth: 1.5)
                // Paint fill with slight color
                var paintFill = Path()
                paintFill.addRect(CGRect(x: paintLeft + 1, y: floorY + 1,
                                          width: paintRight - paintLeft - 2, height: H - floorY - 2))
                ctx.fill(paintFill, with: .color(Color(red: 0.18, green: 0.40, blue: 0.82).opacity(0.18)))
                var ftLine = Path()
                ftLine.move(to: CGPoint(x: paintLeft, y: floorY + (H - floorY) * 0.38))
                ftLine.addLine(to: CGPoint(x: paintRight, y: floorY + (H - floorY) * 0.38))
                ctx.stroke(ftLine, with: .color(.white.opacity(0.35)), lineWidth: 1.0)

                // Floor rim glow reflection
                var floorGlow = ctx
                floorGlow.addFilter(.blur(radius: 22))
                var floorGlowPath = Path()
                floorGlowPath.addEllipse(in: CGRect(x: W * 0.40, y: floorY - 10, width: W * 0.5, height: 60))
                floorGlow.fill(floorGlowPath, with: .color(Color(red: 1.0, green: 0.5, blue: 0.1)
                    .opacity(0.20 + Double(rimGlow) * 0.45)))

                // ── VENICE BALL SHOP (boardwalk vendor stall, left side) ────
                let shopX = W * 0.02
                let shopY = boardwalkY - 55
                // Stall awning
                var awningPath = Path()
                awningPath.move(to: CGPoint(x: shopX, y: shopY))
                awningPath.addLine(to: CGPoint(x: shopX + 70, y: shopY))
                awningPath.addLine(to: CGPoint(x: shopX + 65, y: shopY + 14))
                awningPath.addLine(to: CGPoint(x: shopX + 5, y: shopY + 14))
                awningPath.closeSubpath()
                ctx.fill(awningPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.92, green: 0.18, blue: 0.18), Color(red: 0.75, green: 0.10, blue: 0.10)]),
                    startPoint: CGPoint(x: shopX, y: shopY),
                    endPoint: CGPoint(x: shopX + 70, y: shopY)
                ))
                // Awning stripes
                for s in 0..<5 {
                    let sx = shopX + CGFloat(s) * 13
                    var stripe = Path()
                    stripe.move(to: CGPoint(x: sx, y: shopY))
                    stripe.addLine(to: CGPoint(x: sx + 5, y: shopY + 14))
                    ctx.stroke(stripe, with: .color(.white.opacity(0.35)), lineWidth: 2)
                }
                // Awning fringe
                for f in 0..<8 {
                    let fx2 = shopX + 5 + CGFloat(f) * 9
                    let fSway = CGFloat(sin(t * 2.0 + Double(f) * 0.8)) * 2
                    var fringe = Path()
                    fringe.move(to: CGPoint(x: fx2, y: shopY + 14))
                    fringe.addLine(to: CGPoint(x: fx2 + fSway, y: shopY + 22))
                    ctx.stroke(fringe, with: .color(Color(red: 0.92, green: 0.18, blue: 0.18)), lineWidth: 2)
                }
                // Stall counter / table
                var tableTop = Path()
                tableTop.addRoundedRect(in: CGRect(x: shopX, y: shopY + 14, width: 70, height: 8),
                                         cornerSize: CGSize(width: 2, height: 2))
                ctx.fill(tableTop, with: .color(Color(red: 0.55, green: 0.35, blue: 0.15)))
                // Basketballs on display (3 balls)
                for b in 0..<3 {
                    let bx = shopX + 12 + CGFloat(b) * 22
                    let by = shopY + 14 - 9
                    var ballPath = Path()
                    ballPath.addEllipse(in: CGRect(x: bx - 8, y: by - 8, width: 16, height: 16))
                    ctx.fill(ballPath, with: .color(Color(red: 0.90, green: 0.42, blue: 0.08)))
                    // Ball lines
                    var ballLineH = Path()
                    ballLineH.move(to: CGPoint(x: bx - 7, y: by)); ballLineH.addLine(to: CGPoint(x: bx + 7, y: by))
                    ctx.stroke(ballLineH, with: .color(.black.opacity(0.35)), lineWidth: 0.8)
                    var ballLineV = Path()
                    ballLineV.move(to: CGPoint(x: bx, y: by - 7)); ballLineV.addLine(to: CGPoint(x: bx, y: by + 7))
                    ctx.stroke(ballLineV, with: .color(.black.opacity(0.35)), lineWidth: 0.8)
                }
                // Shop sign
                var signPath = Path()
                signPath.addRoundedRect(in: CGRect(x: shopX + 5, y: shopY - 22, width: 60, height: 16),
                                         cornerSize: CGSize(width: 3, height: 3))
                ctx.fill(signPath, with: .color(Color(red: 0.10, green: 0.10, blue: 0.10).opacity(0.85)))
                ctx.stroke(signPath, with: .color(.white.opacity(0.4)), lineWidth: 0.8)

                // Chain-link fence behind basket
                let fenceY = floorY - 80
                for fx in stride(from: W * 0.55, through: W, by: 18.0) {
                    var fenceV = Path()
                    fenceV.move(to: CGPoint(x: fx, y: fenceY))
                    fenceV.addLine(to: CGPoint(x: fx, y: floorY))
                    ctx.stroke(fenceV, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                }
                for fy in stride(from: fenceY, through: floorY, by: 14.0) {
                    var fenceH = Path()
                    fenceH.move(to: CGPoint(x: W * 0.55, y: fy))
                    fenceH.addLine(to: CGPoint(x: W, y: fy))
                    ctx.stroke(fenceH, with: .color(.white.opacity(0.06)), lineWidth: 0.4)
                }

                // ── OUTDOOR CROWD (bystanders around court perimeter) ────────
                let crowdPulse = CGFloat(sin(t * 3.5)) * crowdEnergy * 5
                let crowdColors: [Color] = [.cyan, .orange, .yellow, .white, .purple, .green, .pink, .red]
                // Two rows of spectators on the left side of court
                for row in 0..<2 {
                    let rowY = floorY + 20 + CGFloat(row) * 18
                    for col in 0..<8 {
                        let dotX = W * 0.04 + CGFloat(col) * (W * 0.15 / 8)
                        let jitter = CGFloat(sin(t * 2.5 + Double(col) * 0.7)) * 3 * crowdEnergy
                        let dotY = rowY + jitter + (row == 0 ? crowdPulse * 0.3 : 0)
                        var dotPath = Path()
                        dotPath.addEllipse(in: CGRect(x: dotX - 4, y: dotY - 4, width: 8, height: 8))
                        let c = crowdColors[(col + row * 2) % crowdColors.count]
                        ctx.fill(dotPath, with: .color(c.opacity(0.65 + Double(crowdEnergy) * 0.25)))
                        if crowdEnergy > 0.5 {
                            var armL = Path(); armL.move(to: CGPoint(x: dotX, y: dotY - 4))
                            armL.addLine(to: CGPoint(x: dotX - 6, y: dotY - 11 + jitter * 0.5))
                            var armR = Path(); armR.move(to: CGPoint(x: dotX, y: dotY - 4))
                            armR.addLine(to: CGPoint(x: dotX + 6, y: dotY - 11 + jitter * 0.5))
                            ctx.stroke(armL, with: .color(c.opacity(0.45)), lineWidth: 0.9)
                            ctx.stroke(armR, with: .color(c.opacity(0.45)), lineWidth: 0.9)
                        }
                    }
                }
                // Spectators along baseline (bottom)
                for col in 0..<16 {
                    let dotX = W * 0.08 + CGFloat(col) * (W * 0.84 / 15.0)
                    let jitter = CGFloat(sin(t * 2.0 + Double(col) * 0.5)) * 4 * crowdEnergy
                    let dotY = H - 18 + jitter + crowdPulse * 0.2
                    var dotPath = Path()
                    dotPath.addEllipse(in: CGRect(x: dotX - 5, y: dotY - 5, width: 10, height: 10))
                    let c = crowdColors[col % crowdColors.count]
                    ctx.fill(dotPath, with: .color(c.opacity(0.60 + Double(crowdEnergy) * 0.30)))
                    if crowdEnergy > 0.6 {
                        var armL = Path(); armL.move(to: CGPoint(x: dotX, y: dotY - 5))
                        armL.addLine(to: CGPoint(x: dotX - 7, y: dotY - 14 + jitter * 0.4))
                        var armR = Path(); armR.move(to: CGPoint(x: dotX, y: dotY - 5))
                        armR.addLine(to: CGPoint(x: dotX + 7, y: dotY - 14 + jitter * 0.4))
                        ctx.stroke(armL, with: .color(c.opacity(0.40)), lineWidth: 0.8)
                        ctx.stroke(armR, with: .color(c.opacity(0.40)), lineWidth: 0.8)
                    }
                }

                // ── RIM: orange circle + chain net (zigzag below) ─────────
                let basketX = W * 0.82
                let rimY    = H * 0.30

                // Backboard pole
                var pole = Path()
                pole.move(to: CGPoint(x: basketX + 30, y: floorY))
                pole.addLine(to: CGPoint(x: basketX + 30, y: rimY - 15))
                ctx.stroke(pole, with: .color(Color(red: 0.55, green: 0.55, blue: 0.60)), lineWidth: 5)

                // Backboard: gray rectangle slightly above rim
                var bbPath = Path()
                bbPath.addRoundedRect(in: CGRect(x: basketX - 5, y: rimY - 45, width: 70, height: 45),
                                       cornerSize: CGSize(width: 3, height: 3))
                ctx.fill(bbPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.78, green: 0.80, blue: 0.85),
                                      Color(red: 0.50, green: 0.53, blue: 0.58)]),
                    startPoint: CGPoint(x: basketX, y: rimY - 45),
                    endPoint: CGPoint(x: basketX, y: rimY)
                ))
                ctx.stroke(bbPath, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
                var bbInner = Path()
                bbInner.addRect(CGRect(x: basketX + 8, y: rimY - 38, width: 42, height: 26))
                ctx.stroke(bbInner, with: .color(.white.opacity(0.3)), lineWidth: 1.0)

                // Rim glow halo
                let rimGlowAlpha = Double(rimGlow)
                if rimGlowAlpha > 0 {
                    var rimGlowCtx = ctx
                    rimGlowCtx.addFilter(.blur(radius: 12))
                    var rimGlowPath = Path()
                    rimGlowPath.addEllipse(in: CGRect(x: basketX - 22, y: rimY - 6, width: 50, height: 16))
                    rimGlowCtx.fill(rimGlowPath, with: .color(Color(red: 1.0, green: 0.5, blue: 0.1)
                        .opacity(rimGlowAlpha * 0.8)))
                }
                // Rim: orange circle
                var rimPath = Path()
                rimPath.addEllipse(in: CGRect(x: basketX - 20, y: rimY - 4, width: 46, height: 12))
                ctx.stroke(rimPath, with: .color(Color(red: 1.0, green: 0.45, blue: 0.10)), lineWidth: 3.5)

                // Net (zigzag below rim)
                let netTopL = CGPoint(x: basketX - 20, y: rimY + 4)
                let netTopR = CGPoint(x: basketX + 26, y: rimY + 4)
                let netSway = CGFloat(sin(t * 2.5)) * 3
                let netBot  = CGPoint(x: (netTopL.x + netTopR.x) / 2 + netSway, y: rimY + 38)
                for n in 0..<5 {
                    let tFrac = CGFloat(n) / 4.0
                    var netLine = Path()
                    let nx = netTopL.x + (netTopR.x - netTopL.x) * tFrac
                    netLine.move(to: CGPoint(x: nx, y: rimY + 4))
                    netLine.addLine(to: CGPoint(x: netBot.x - 10 + tFrac * 20, y: netBot.y))
                    ctx.stroke(netLine, with: .color(.white.opacity(0.3)), lineWidth: 0.8)
                }
                for n in 0..<4 {
                    let hFrac = CGFloat(n + 1) / 5.0
                    let lx = netTopL.x + (netBot.x - 10 - netTopL.x) * hFrac
                    let rx = netTopR.x + (netBot.x + 10 - netTopR.x) * hFrac
                    let ny = netTopL.y + (netBot.y - netTopL.y) * hFrac
                    var hNet = Path()
                    hNet.move(to: CGPoint(x: lx, y: ny))
                    hNet.addLine(to: CGPoint(x: rx, y: ny))
                    ctx.stroke(hNet, with: .color(.white.opacity(0.2)), lineWidth: 0.6)
                }

                // ── RIM SPARK PARTICLES (20 sparks radiating outward) ─────
                for spark in sparks {
                    var sparkGlowCtx = ctx
                    sparkGlowCtx.addFilter(.blur(radius: 4))
                    var sparkGlowPath = Path()
                    sparkGlowPath.addEllipse(in: CGRect(x: spark.x - spark.size / 2, y: spark.y - spark.size / 2,
                                                         width: spark.size, height: spark.size))
                    sparkGlowCtx.fill(sparkGlowPath, with: .color(Color.yellow.opacity(Double(spark.alpha) * 0.5)))
                    var sparkPath = Path()
                    sparkPath.addEllipse(in: CGRect(x: spark.x - spark.size / 2, y: spark.y - spark.size / 2,
                                                     width: spark.size, height: spark.size))
                    ctx.fill(sparkPath, with: .color(Color.orange.opacity(Double(spark.alpha))))
                }

                // ── PLAYER RUNNING FIGURE (left to right) ─────────────────
                if runProgress > 0 && runProgress < 1.0 {
                    let playerX = W * 0.05 + (basketX - 50 - W * 0.05) * runProgress
                    let playerFloorY = floorY + 10
                    let runCycle = sin(t * (8 + Double(runProgress) * 6))
                    let lean = runProgress * 8

                    var playerSpot = ctx
                    playerSpot.addFilter(.blur(radius: 30))
                    var spotP = Path()
                    spotP.addEllipse(in: CGRect(x: playerX - 40, y: playerFloorY - 90, width: 80, height: 100))
                    playerSpot.fill(spotP, with: .color(Color(red: 1.0, green: 0.85, blue: 0.5)
                        .opacity(0.20 + Double(runProgress) * 0.15)))

                    let shadowW: CGFloat = 24 - runProgress * 4
                    var shadowPath = Path()
                    shadowPath.addEllipse(in: CGRect(x: playerX - shadowW / 2, y: playerFloorY + 2,
                                                      width: shadowW, height: 5))
                    ctx.fill(shadowPath, with: .color(.black.opacity(0.4)))

                    let bodyH: CGFloat = 40
                    let legSwing = CGFloat(runCycle) * 10

                    var torsoPath = Path()
                    torsoPath.addRoundedRect(
                        in: CGRect(x: playerX - 7 + lean * 0.5, y: playerFloorY - bodyH - 30, width: 14, height: bodyH),
                        cornerSize: CGSize(width: 5, height: 5)
                    )
                    ctx.fill(torsoPath, with: .color(Color(red: 0.0, green: 0.8, blue: 1.0)))

                    var headPath = Path()
                    headPath.addEllipse(in: CGRect(x: playerX - 9 + lean, y: playerFloorY - bodyH - 48,
                                                    width: 18, height: 18))
                    ctx.fill(headPath, with: .color(Color(red: 0.0, green: 0.8, blue: 1.0)))

                    var legL = Path()
                    legL.move(to: CGPoint(x: playerX, y: playerFloorY - 30))
                    legL.addLine(to: CGPoint(x: playerX - 5 - legSwing, y: playerFloorY))
                    ctx.stroke(legL, with: .color(Color(red: 0.0, green: 0.6, blue: 0.9)), lineWidth: 4)

                    var legR = Path()
                    legR.move(to: CGPoint(x: playerX, y: playerFloorY - 30))
                    legR.addLine(to: CGPoint(x: playerX + 5 + legSwing, y: playerFloorY))
                    ctx.stroke(legR, with: .color(Color(red: 0.0, green: 0.6, blue: 0.9)), lineWidth: 4)

                    var armL = Path()
                    armL.move(to: CGPoint(x: playerX - 5, y: playerFloorY - bodyH - 15))
                    armL.addLine(to: CGPoint(x: playerX - 18, y: playerFloorY - bodyH - 15 - legSwing * 0.5))
                    ctx.stroke(armL, with: .color(Color(red: 0.0, green: 0.8, blue: 1.0)), lineWidth: 3)

                    var armR = Path()
                    armR.move(to: CGPoint(x: playerX + 5, y: playerFloorY - bodyH - 15))
                    armR.addLine(to: CGPoint(x: playerX + 18, y: playerFloorY - bodyH - 15 + legSwing * 0.5))
                    ctx.stroke(armR, with: .color(Color(red: 0.0, green: 0.8, blue: 1.0)), lineWidth: 3)
                }

                // ── RIM MOMENT: player frozen mid-air at rim, arms extended, ball overhead
                if runProgress >= 1.0 {
                    let poseX = basketX - 22
                    let poseY = rimY - 20

                    // Warm glow overlay on canvas frame (cinematic)
                    var screenGlow = ctx
                    screenGlow.addFilter(.blur(radius: 55))
                    var screenGlowPath = Path()
                    screenGlowPath.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                    screenGlow.fill(screenGlowPath, with: .color(Color(red: 1.0, green: 0.4, blue: 0.05).opacity(0.28)))

                    var torsoP = Path()
                    torsoP.addRoundedRect(in: CGRect(x: poseX - 8, y: poseY - 40, width: 16, height: 35),
                                          cornerSize: CGSize(width: 5, height: 5))
                    ctx.fill(torsoP, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0)))

                    var headP = Path()
                    headP.addEllipse(in: CGRect(x: poseX - 9, y: poseY - 56, width: 18, height: 18))
                    ctx.fill(headP, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0)))

                    var armLUp = Path()
                    armLUp.move(to: CGPoint(x: poseX - 6, y: poseY - 38))
                    armLUp.addLine(to: CGPoint(x: poseX - 22, y: poseY - 58))
                    ctx.stroke(armLUp, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0)), lineWidth: 4)

                    var armRUp = Path()
                    armRUp.move(to: CGPoint(x: poseX + 6, y: poseY - 38))
                    armRUp.addLine(to: CGPoint(x: poseX + 16, y: poseY - 58))
                    ctx.stroke(armRUp, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0)), lineWidth: 4)

                    var legLDown = Path()
                    legLDown.move(to: CGPoint(x: poseX - 3, y: poseY - 5))
                    legLDown.addLine(to: CGPoint(x: poseX - 18, y: poseY + 18))
                    ctx.stroke(legLDown, with: .color(Color(red: 0.0, green: 0.6, blue: 0.9)), lineWidth: 4)

                    var legRDown = Path()
                    legRDown.move(to: CGPoint(x: poseX + 3, y: poseY - 5))
                    legRDown.addLine(to: CGPoint(x: poseX + 18, y: poseY + 18))
                    ctx.stroke(legRDown, with: .color(Color(red: 0.0, green: 0.6, blue: 0.9)), lineWidth: 4)

                    // Ball above head with orange glow
                    // var glow = ctx; glow.addFilter(.blur(radius: 12))
                    // glow.fill(ballPath, with: .color(.orange.opacity(0.55)))
                    // ctx.fill(ballPath, with: .color(.orange))
                    let ballX = poseX
                    let ballY = poseY - 74
                    var ballGlow = ctx
                    ballGlow.addFilter(.blur(radius: 12))
                    var ballGlowPath = Path()
                    ballGlowPath.addEllipse(in: CGRect(x: ballX - 14, y: ballY - 14, width: 28, height: 28))
                    ballGlow.fill(ballGlowPath, with: .color(Color.orange.opacity(0.55)))
                    var ballPath = Path()
                    ballPath.addEllipse(in: CGRect(x: ballX - 10, y: ballY - 10, width: 20, height: 20))
                    ctx.fill(ballPath, with: .color(Color(red: 0.9, green: 0.42, blue: 0.10)))
                    ctx.stroke(ballPath, with: .color(.black.opacity(0.4)), lineWidth: 1)
                    var seamV = Path()
                    seamV.addArc(center: CGPoint(x: ballX, y: ballY), radius: 9,
                                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                    ctx.stroke(seamV, with: .color(.black.opacity(0.3)), lineWidth: 0.8)
                    var seamH = Path()
                    seamH.move(to: CGPoint(x: ballX - 9, y: ballY))
                    seamH.addLine(to: CGPoint(x: ballX + 9, y: ballY))
                    ctx.stroke(seamH, with: .color(.black.opacity(0.3)), lineWidth: 0.8)
                }

                // ── SCOREBOARD: floating score in upper center ────────────
                var hudBack = Path()
                hudBack.addRoundedRect(in: CGRect(x: W * 0.10, y: H * 0.11, width: W * 0.80, height: 40),
                                        cornerSize: CGSize(width: 8, height: 8))
                ctx.fill(hudBack, with: .color(.black.opacity(0.72)))
                ctx.stroke(hudBack, with: .color(Color.orange.opacity(0.35)), lineWidth: 1)

                ctx.draw(
                    Text(String(format: "YOU: %.1f", playerScore))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.cyan),
                    at: CGPoint(x: W * 0.28, y: H * 0.11 + 20)
                )
                ctx.draw(
                    Text("RND \(dunkRound)/3")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6)),
                    at: CGPoint(x: W * 0.50, y: H * 0.11 + 20)
                )
                ctx.draw(
                    Text(String(format: "AI: %.1f", aiScore))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.10)),
                    at: CGPoint(x: W * 0.73, y: H * 0.11 + 20)
                )

                // ── SCORE POPUPS ──────────────────────────────────────────
                for popup in scorePopups {
                    var pgCtx = ctx
                    pgCtx.addFilter(.blur(radius: 5))
                    pgCtx.draw(
                        Text(popup.text)
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundStyle(popup.color.opacity(popup.opacity * 0.4)),
                        at: CGPoint(x: popup.xPos, y: H * 0.35 + popup.yOffset)
                    )
                    ctx.draw(
                        Text(popup.text)
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundStyle(popup.color.opacity(popup.opacity)),
                        at: CGPoint(x: popup.xPos, y: H * 0.35 + popup.yOffset)
                    )
                }
            }
        }
    }
}

// MARK: - Crowd Meter

private struct CrowdMeterView: View {
    let energy: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            Text("CROWD")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 12, height: 140)

                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [Color.orange, Color.yellow, Color.green],
                        startPoint: .bottom, endPoint: .top
                    ))
                    .frame(width: 10, height: max(2, 138 * energy))
                    .animation(.spring(response: 0.3), value: energy)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    .frame(width: 12, height: 140)
            )

            Text(energyLabel)
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .foregroundStyle(energyColor)
                .multilineTextAlignment(.center)
                .frame(width: 32)
        }
    }

    private var energyLabel: String {
        if energy > 0.95 { return "WILD" }
        if energy > 0.70 { return "HOT" }
        if energy > 0.40 { return "WARM" }
        return "COLD"
    }

    private var energyColor: Color {
        if energy > 0.95 { return .yellow }
        if energy > 0.70 { return .orange }
        if energy > 0.40 { return Color(red: 0.9, green: 0.6, blue: 0.1) }
        return .white.opacity(0.3)
    }
}

// MARK: - Judge Panel

private struct JudgePanelView: View {
    let scores: [JudgeScore]

    var total: Double { scores.filter(\.revealed).map(\.score).reduce(0, +) }
    var allRevealed: Bool { scores.allSatisfy(\.revealed) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ForEach(scores) { judge in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 44, height: 44)
                            Text("J\(judge.judgeIndex + 1)")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.orange.opacity(0.8))
                        }
                        if judge.revealed {
                            Text(String(format: "%.1f", judge.score))
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.20))
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text("—")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        Text("JUDGE \(judge.judgeIndex + 1)")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Score formula: "8.5 + 9.0 + 8.5 = 26.0 / 30"
            if allRevealed && scores.count == 3 {
                let s = scores.map { String(format: "%.1f", $0.score) }
                (
                    Text("\(s[0]) + \(s[1]) + \(s[2]) = ")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                    +
                    Text(String(format: "%.1f / 30", total))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.70))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1))
        )
    }
}

// MARK: - Combo Prompt View (shrinking ring countdown)

private struct ComboPromptView: View {
    let direction: SwipeDirection?
    let flashColor: Color?
    let stepIndex: Int
    let totalSteps: Int
    let timeRemaining: CGFloat     // 1.0 → 0.0 over 0.45s
    let consecutivePerfects: Int

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 14) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i < stepIndex ? Color.green
                              : (i == stepIndex ? Color.white : Color.white.opacity(0.2)))
                        .frame(width: 8, height: 8)
                }
            }

            // Consecutive perfect multiplier badge
            if consecutivePerfects > 0 {
                let mult = comboMultipliers[min(consecutivePerfects, comboMultipliers.count - 1)]
                Text(String(format: "x%.1f", mult))
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.yellow)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Capsule())
            }

            if let dir = direction {
                ZStack {
                    // Countdown ring track
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                        .frame(width: 96, height: 96)

                    // Shrinking ring countdown
                    Circle()
                        .trim(from: 0, to: timeRemaining)
                        .stroke(
                            (flashColor ?? Color.white).opacity(0.65),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.05), value: timeRemaining)

                    // Pulse fill
                    Circle()
                        .fill((flashColor ?? Color.white).opacity(0.10))
                        .frame(width: 82, height: 82)
                        .scaleEffect(pulseScale)

                    // Arrow
                    Text(dir.arrow)
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(flashColor ?? Color.white)
                        .scaleEffect(pulseScale)
                }
                .onAppear {
                    pulseScale = 1.0
                    withAnimation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true)) {
                        pulseScale = 1.10
                    }
                }
                .onChange(of: dir) { _ in
                    pulseScale = 1.0
                    withAnimation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true)) {
                        pulseScale = 1.10
                    }
                }

                Text("SWIPE \(dir.rawValue.uppercased())")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(flashColor ?? Color.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Dunk Select Card

private struct DunkSelectCard: View {
    let move: DunkType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                Image(systemName: move.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(isSelected ? Color.black : Color.orange)

                Text(move.rawValue)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isSelected ? .black : .white)
                    .multilineTextAlignment(.center)

                Text(move.description)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < move.baseDifficulty ? "star.fill" : "star")
                            .font(.system(size: 7))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.6) : Color.orange.opacity(0.6))
                    }
                }

                // Combo arrow preview
                HStack(spacing: 3) {
                    ForEach(move.comboSequence.indices, id: \.self) { i in
                        Text(move.comboSequence[i].arrow)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.5))
                    }
                }
            }
            .padding(14)
            .frame(width: 130, height: 185)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.orange : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.yellow : Color.orange.opacity(0.3),
                                    lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(.spring(response: 0.25), value: isSelected)
        }
    }
}

// MARK: - Lobby Canvas

private struct LobbyCanvas: View {
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let W = size.width
                let H = size.height

                var skyRect = Path()
                skyRect.addRect(CGRect(x: 0, y: 0, width: W, height: H * 0.6))
                ctx.fill(skyRect, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.08, green: 0.22, blue: 0.55),
                        Color(red: 0.25, green: 0.55, blue: 0.85),
                        Color(red: 0.85, green: 0.65, blue: 0.35)
                    ]),
                    startPoint: CGPoint(x: W / 2, y: 0),
                    endPoint: CGPoint(x: W / 2, y: H * 0.6)
                ))

                let sunY = H * 0.18 + sin(t * 0.15) * 3
                let sunX = W * 0.72
                var sunGlow = ctx
                sunGlow.addFilter(.blur(radius: 18))
                var sunGlowPath = Path()
                sunGlowPath.addEllipse(in: CGRect(x: sunX - 30, y: sunY - 30, width: 60, height: 60))
                sunGlow.fill(sunGlowPath, with: .color(Color(red: 1.0, green: 0.9, blue: 0.5).opacity(0.5)))
                var sunPath = Path()
                sunPath.addEllipse(in: CGRect(x: sunX - 18, y: sunY - 18, width: 36, height: 36))
                ctx.fill(sunPath, with: .color(Color(red: 1.0, green: 0.95, blue: 0.6)))

                let horizon = H * 0.55
                var floorPath = Path()
                floorPath.addRect(CGRect(x: 0, y: horizon, width: W, height: H - horizon))
                ctx.fill(floorPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.18, green: 0.55, blue: 0.22),
                                      Color(red: 0.12, green: 0.38, blue: 0.16)]),
                    startPoint: CGPoint(x: W / 2, y: horizon),
                    endPoint: CGPoint(x: W / 2, y: H)
                ))

                for i in 0..<24 {
                    let fi = Double(i)
                    let crowdX = (CGFloat(i) / 24.0) * W +
                        CGFloat(fmod(t * 8 * (i % 2 == 0 ? 1 : -1), W / 4))
                    let crowdBaseY = horizon - H * 0.04 + CGFloat(sin(t * 2.0 + fi * 0.7)) * 3
                    let crowdH: CGFloat = 22 + CGFloat(i % 4) * 4
                    var headPath = Path()
                    headPath.addEllipse(in: CGRect(x: crowdX - 5, y: crowdBaseY - crowdH, width: 10, height: 10))
                    let cc = [Color.cyan, Color.orange, Color.yellow, Color.white, Color.purple][i % 5].opacity(0.55)
                    ctx.fill(headPath, with: .color(cc))
                }
            }
        }
    }
}

// MARK: - Result Canvas

private struct ResultCanvas: View {
    let playerWon: Bool
    let playerScore: Double
    let aiScore: Double

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let W = size.width
                let H = size.height

                var bgP = Path()
                bgP.addRect(CGRect(x: 0, y: 0, width: W, height: H))
                ctx.fill(bgP, with: .color(Color(red: 0.06, green: 0.06, blue: 0.12)))

                // Confetti particle shower
                let confColors: [Color] = [.yellow, .cyan, .orange, .green, .purple, .pink, .white]
                for i in 0..<55 {
                    let fi = Double(i)
                    let seed = fi * 113.7
                    let cx = CGFloat(fmod(seed * 0.617, 1.0)) * W
                    let speed = 0.05 + CGFloat(fmod(seed * 0.3, 0.06))
                    let cy = CGFloat(fmod(CGFloat(t) * speed + CGFloat(fmod(seed * 0.5, 1.0)), 1.1)) * H
                    let sz: CGFloat = 5 + CGFloat(fmod(seed * 0.22, 5))
                    let wobX = cx + CGFloat(sin(t * 1.4 + fi * 0.55)) * 14
                    var confP = Path()
                    confP.addRect(CGRect(x: wobX - sz / 2, y: cy - sz / 2, width: sz, height: sz))
                    ctx.fill(confP, with: .color(confColors[i % confColors.count].opacity(0.75)))
                }

                // Central glow
                var cg = ctx
                cg.addFilter(.blur(radius: 40))
                var cgP = Path()
                cgP.addEllipse(in: CGRect(x: W / 2 - 90, y: H * 0.22 - 90, width: 180, height: 180))
                cg.fill(cgP, with: .color((playerWon ? Color.yellow : Color.red).opacity(0.32)))

                // WIN/LOSS title
                var tg = ctx
                tg.addFilter(.blur(radius: 10))
                tg.draw(
                    Text(playerWon ? "YOU WIN!" : "DEFEATED")
                        .font(.system(size: 52, weight: .black, design: .monospaced))
                        .foregroundStyle((playerWon ? Color.yellow : Color.red).opacity(0.5)),
                    at: CGPoint(x: W / 2, y: H * 0.22)
                )
                ctx.draw(
                    Text(playerWon ? "YOU WIN!" : "DEFEATED")
                        .font(.system(size: 52, weight: .black, design: .monospaced))
                        .foregroundStyle(playerWon ? Color.yellow : Color.red),
                    at: CGPoint(x: W / 2, y: H * 0.22)
                )

                // Winner crown
                if playerWon {
                    let crownX = W / 2
                    let crownY = H * 0.22 - 48
                    var crown = Path()
                    crown.move(to: CGPoint(x: crownX - 22, y: crownY + 14))
                    crown.addLine(to: CGPoint(x: crownX - 22, y: crownY))
                    crown.addLine(to: CGPoint(x: crownX - 10, y: crownY + 10))
                    crown.addLine(to: CGPoint(x: crownX, y: crownY - 6))
                    crown.addLine(to: CGPoint(x: crownX + 10, y: crownY + 10))
                    crown.addLine(to: CGPoint(x: crownX + 22, y: crownY))
                    crown.addLine(to: CGPoint(x: crownX + 22, y: crownY + 14))
                    crown.closeSubpath()
                    ctx.fill(crown, with: .color(Color.yellow.opacity(0.9)))
                    ctx.stroke(crown, with: .color(Color(red: 1.0, green: 0.7, blue: 0.0)), lineWidth: 1.5)
                }

                // Side-by-side score bars
                let barTop = H * 0.34
                let barH: CGFloat = 22
                let maxBar = W * 0.38
                let pFrac = CGFloat(min(1.0, playerScore / 30.0))
                let aFrac = CGFloat(min(1.0, aiScore / 30.0))

                // YOU bar (centre leftward)
                var youBarPath = Path()
                youBarPath.addRoundedRect(
                    in: CGRect(x: W * 0.5 - maxBar * pFrac - 4, y: barTop, width: maxBar * pFrac, height: barH),
                    cornerSize: CGSize(width: 4, height: 4)
                )
                ctx.fill(youBarPath, with: .linearGradient(
                    Gradient(colors: [Color.cyan.opacity(0.4), Color.cyan]),
                    startPoint: CGPoint(x: W * 0.5 - maxBar * pFrac, y: barTop),
                    endPoint: CGPoint(x: W * 0.5, y: barTop)
                ))
                ctx.draw(
                    Text(String(format: "YOU  %.1f", playerScore))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.cyan),
                    at: CGPoint(x: W * 0.5 - maxBar * pFrac / 2 - 4, y: barTop + barH / 2)
                )

                // AI bar (centre rightward)
                var aiBarPath = Path()
                aiBarPath.addRoundedRect(
                    in: CGRect(x: W * 0.5 + 4, y: barTop, width: maxBar * aFrac, height: barH),
                    cornerSize: CGSize(width: 4, height: 4)
                )
                ctx.fill(aiBarPath, with: .linearGradient(
                    Gradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.1),
                                      Color(red: 1.0, green: 0.5, blue: 0.1).opacity(0.4)]),
                    startPoint: CGPoint(x: W * 0.5, y: barTop),
                    endPoint: CGPoint(x: W * 0.5 + maxBar * aFrac, y: barTop)
                ))
                ctx.draw(
                    Text(String(format: "%.1f  AI", aiScore))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.1)),
                    at: CGPoint(x: W * 0.5 + maxBar * aFrac / 2 + 4, y: barTop + barH / 2)
                )

                // Center divider line
                var divLine = Path()
                divLine.move(to: CGPoint(x: W * 0.5, y: barTop - 4))
                divLine.addLine(to: CGPoint(x: W * 0.5, y: barTop + barH + 4))
                ctx.stroke(divLine, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Spinning stars for win
                if playerWon {
                    for corner in [(W * 0.12, H * 0.10), (W * 0.88, H * 0.10)] {
                        let cx = corner.0, cy = corner.1
                        let spin = t * 0.9
                        var star = Path()
                        for pt in 0..<5 {
                            let angle = Double(pt) * (.pi * 2 / 5) - .pi / 2 + spin
                            let innerAngle = angle + .pi / 5
                            let r: CGFloat = 16, ir: CGFloat = 8
                            if pt == 0 {
                                star.move(to: CGPoint(x: cx + CGFloat(cos(angle)) * r,
                                                       y: cy + CGFloat(sin(angle)) * r))
                            } else {
                                star.addLine(to: CGPoint(x: cx + CGFloat(cos(angle)) * r,
                                                          y: cy + CGFloat(sin(angle)) * r))
                            }
                            star.addLine(to: CGPoint(x: cx + CGFloat(cos(innerAngle)) * ir,
                                                      y: cy + CGFloat(sin(innerAngle)) * ir))
                        }
                        star.closeSubpath()
                        ctx.fill(star, with: .color(Color.yellow.opacity(0.7)))
                    }
                }
            }
        }
    }
}

// MARK: - Arena Erupts Overlay

private struct ArenaEruptsOverlay: View {
    var body: some View {
        VStack {
            Spacer().frame(height: 72)
            VStack(spacing: 6) {
                Text("THE ARENA ERUPTS")
                    .font(.system(size: 21, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.yellow)
                    .shadow(color: Color.yellow.opacity(0.9), radius: 14)
                Text("CROWD AT MAX ENERGY!")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.orange.opacity(0.85))
                    .tracking(2)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .background(Color.black.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.55), lineWidth: 2))
            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Main View

struct DunkCompetitionView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    // Top-level phase
    @State private var compPhase: CompPhase = .lobby
    @State private var selectedOpponent: LobbyPlayer? = nil
    @State private var selectedFee: CompFee = .practice
    @State private var showCashAlert: Bool = false

    // Dunk contest state
    @State private var dunkPhase: DunkPhase = .dunkSelect
    @State private var selectedDunk: DunkType? = nil
    @State private var dunkRound: Int = 1

    // Scores
    @State private var playerTotalScore: Double = 0
    @State private var aiTotalScore: Double = 0
    @State private var roundScores: [Double] = []
    @State private var aiRoundScores: [Double] = []
    @State private var aiTargetTotal: Double = 0

    // Approach animation
    @State private var runProgress: CGFloat = 0
    @State private var approachTask: Task<Void, Never>? = nil
    @State private var isSlowMo: Bool = false

    // Combo system
    @State private var comboStep: Int = 0
    @State private var comboHits: [HitQuality] = []
    @State private var currentPromptTime: Date = Date()
    @State private var comboFlashColor: Color? = nil
    @State private var comboFlashLabel: String = ""
    @State private var comboTask: Task<Void, Never>? = nil
    @State private var comboExpired: Bool = false
    @State private var swipeGestureEnabled: Bool = false
    @State private var consecutivePerfects: Int = 0
    @State private var promptTimeRemaining: CGFloat = 1.0
    @State private var ringTask: Task<Void, Never>? = nil

    // Rim moment
    @State private var rimMomentTask: Task<Void, Never>? = nil
    @State private var rimGlow: CGFloat = 0
    @State private var sparks: [RimSpark] = []
    @State private var sparkAnimTask: Task<Void, Never>? = nil

    // Crowd energy
    @State private var crowdEnergy: CGFloat = 0.3
    @State private var showArenaErupts: Bool = false

    // Judge panel
    @State private var judgeScores: [JudgeScore] = []
    @State private var judgeRevealTask: Task<Void, Never>? = nil
    @State private var dunkRoundScore: Double = 0

    // Score popups
    @State private var scorePopups: [ScorePopup] = []

    // Hit feedback flash
    @State private var hitFeedbackText: String = ""
    @State private var hitFeedbackColor: Color = .white
    @State private var hitFeedbackScale: CGFloat = 0.5
    @State private var hitFeedbackOpacity: Double = 0

    private let arenaBackground = Color(red: 0.18, green: 0.42, blue: 0.78) // Venice Beach sky

    var body: some View {
        ZStack {
            arenaBackground.ignoresSafeArea()

            switch compPhase {
            case .lobby:
                lobbyBody
            case .matched:
                matchedBody
            case .dunkContest:
                dunkContestBody
            case .result:
                resultBody
            }
        }
        .alert("Cash Mode Coming Soon", isPresented: $showCashAlert) {
            Button("Got It", role: .cancel) {}
        } message: {
            Text("Real-money competition powered by Apple Pay is in development.")
        }
        .onDisappear {
            approachTask?.cancel()
            comboTask?.cancel()
            rimMomentTask?.cancel()
            sparkAnimTask?.cancel()
            judgeRevealTask?.cancel()
            ringTask?.cancel()
        }
    }

    // MARK: - Lobby Phase

    private var lobbyBody: some View {
        ZStack {
            LobbyCanvas().ignoresSafeArea().opacity(0.45)
            LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DUNK COMPETITION")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.orange)
                            .tracking(3)
                        Text("Legendary Dunk Contest")
                            .font(.system(size: 28, weight: .black))
                            .italic()
                            .foregroundStyle(.white)
                        Text("Pick your dunk, nail the combo, earn the crowd. 3 dunks, 3 judges, highest total wins.")
                            .font(.system(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach([CompFee.practice, .shards(100), .shards(500), .cashComingSoon(5)],
                                    id: \.label) { fee in
                                feeChip(fee)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    HStack(spacing: 12) {
                        Button { enterQueue() } label: {
                            Label("JOIN CONTEST", systemImage: "trophy.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .clipShape(.rect(cornerRadius: 14))
                        }
                        Button { enterQueue() } label: {
                            Label("QUICK MATCH", systemImage: "bolt.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Color.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1))
                                .clipShape(.rect(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("LIVE LOBBY")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .tracking(2)
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("\(lobbyPlayers.count) online")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 10) {
                            ForEach(lobbyPlayers) { player in lobbyRow(player) }
                        }
                        .padding(.horizontal, 20)
                    }
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
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selectedFee == fee ? fee.color : fee.color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(fee.isLocked ? Color.white.opacity(0.1) : fee.color.opacity(0.3), lineWidth: 1))
                .clipShape(Capsule())
                .opacity(fee.isLocked ? 0.5 : 1.0)
        }
    }

    private func lobbyRow(_ player: LobbyPlayer) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(player.avatarColor.opacity(0.15)).frame(width: 44, height: 44)
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
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.orange)
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

    // MARK: - Matched Phase

    private var matchedBody: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("MATCH FOUND")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Color.orange).tracking(4)

            HStack(spacing: 24) {
                playerPod(name: "YOU", sub: "Challenger", color: Color.cyan)
                Text("VS")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                playerPod(name: selectedOpponent?.displayName ?? "Opponent",
                          sub: "PRQ \(selectedOpponent?.prq ?? 72)",
                          color: selectedOpponent?.avatarColor ?? .orange)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 6) {
                Text("Entry Fee: \(selectedFee.label)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(selectedFee.color)
                Text("3 dunks · Judge panel scoring · Highest total wins")
                    .font(.system(.caption)).foregroundStyle(.secondary)
            }

            Button { beginDunkContest() } label: {
                Text("LET'S DUNK")
                    .font(.system(.subheadline, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button { compPhase = .lobby } label: {
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
                Circle().fill(color.opacity(0.15)).frame(width: 64, height: 64)
                Text(String(name.prefix(2)).uppercased())
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }
            Text(name).font(.system(size: 11, weight: .black)).foregroundStyle(.white).lineLimit(1)
            Text(sub).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Dunk Contest Body

    private var dunkContestBody: some View {
        ZStack {
            DunkArenaCanvas(
                runProgress: runProgress,
                isSlowMo: isSlowMo,
                selectedDunk: selectedDunk,
                sparks: sparks,
                crowdEnergy: crowdEnergy,
                scorePopups: scorePopups,
                rimGlow: rimGlow,
                playerScore: playerTotalScore,
                aiScore: aiTotalScore,
                dunkRound: dunkRound
            )
            .ignoresSafeArea()

            // Crowd meter on right edge
            VStack {
                Spacer().frame(height: 120)
                CrowdMeterView(energy: crowdEnergy)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)

            // "THE ARENA ERUPTS" overlay + confetti
            if showArenaErupts {
                ArenaEruptsOverlay()
            }

            // Hit feedback flash
            if hitFeedbackOpacity > 0 {
                Text(hitFeedbackText)
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .foregroundStyle(hitFeedbackColor)
                    .scaleEffect(hitFeedbackScale)
                    .opacity(hitFeedbackOpacity)
                    .shadow(color: hitFeedbackColor.opacity(0.6), radius: 12)
                    .allowsHitTesting(false)
            }

            // Phase overlays
            switch dunkPhase {
            case .dunkSelect:  dunkSelectOverlay
            case .approach:    approachOverlay
            case .comboInput:  comboInputOverlay
            case .rimMoment:   rimMomentOverlay
            case .judgeReveal: judgeRevealOverlay
            case .aiTurn:      aiTurnOverlay
            case .finalResult: EmptyView()
            }
        }
    }

    // MARK: - Dunk Select Overlay

    private var dunkSelectOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("ROUND \(dunkRound) OF 3")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.orange.opacity(0.7))
                        .tracking(3)
                    Text("CHOOSE YOUR DUNK")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(DunkType.allCases, id: \.rawValue) { move in
                            DunkSelectCard(
                                move: move,
                                isSelected: selectedDunk == move,
                                onSelect: { selectedDunk = move }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    guard selectedDunk != nil else { return }
                    startApproach()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.run")
                        Text(selectedDunk != nil ? "START APPROACH" : "SELECT A DUNK")
                    }
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(selectedDunk != nil ? .black : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedDunk != nil ? Color.orange : Color.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                .disabled(selectedDunk == nil)
            }
            .padding(.vertical, 24)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: - Approach Overlay

    private var approachOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                if let dunk = selectedDunk {
                    Text(dunk.rawValue)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.orange)
                    Text("GET READY FOR THE COMBO...")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial.opacity(0.6))
        }
    }

    // MARK: - Combo Input Overlay

    private var comboInputOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                if let dunk = selectedDunk, comboStep < dunk.comboSequence.count {
                    ComboPromptView(
                        direction: dunk.comboSequence[comboStep],
                        flashColor: comboFlashColor,
                        stepIndex: comboStep,
                        totalSteps: dunk.comboSequence.count,
                        timeRemaining: promptTimeRemaining,
                        consecutivePerfects: consecutivePerfects
                    )
                }

                if !comboFlashLabel.isEmpty {
                    Text(comboFlashLabel)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(comboFlashColor ?? .white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.85))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard swipeGestureEnabled else { return }
                    handleSwipe(value)
                }
        )
    }

    // MARK: - Rim Moment Overlay

    private var rimMomentOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                if let dunk = selectedDunk {
                    Text(dunk.rawValue)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.orange)
                        .shadow(color: Color.orange.opacity(0.8), radius: 10)

                    let perfects = comboHits.filter { $0 == .perfect }.count
                    let goods    = comboHits.filter { $0 == .good }.count
                    let misses   = comboHits.filter { $0 == .miss }.count
                    HStack(spacing: 12) {
                        comboHitBadge("\(perfects) PERFECT", color: .green)
                        comboHitBadge("\(goods) GOOD", color: .white)
                        comboHitBadge("\(misses) MISS", color: .red)
                    }
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial.opacity(0.75))
        }
    }

    private func comboHitBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Judge Reveal Overlay

    private var judgeRevealOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Text("JUDGE SCORES")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.orange.opacity(0.7))
                    .tracking(4)

                JudgePanelView(scores: judgeScores)
                    .padding(.horizontal, 20)

                if judgeScores.allSatisfy(\.revealed) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f / 30", dunkRoundScore))
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.20))
                            .shadow(color: Color.yellow.opacity(0.6), radius: 8)

                        Text(roundScoreLabel(dunkRoundScore))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.orange)
                            .tracking(2)
                    }
                    .transition(.scale.combined(with: .opacity))

                    Button { proceedAfterJudges() } label: {
                        Text(dunkRound < 3 ? "NEXT ROUND →" : "SEE FINAL RESULT")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .clipShape(.rect(cornerRadius: 14))
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 20)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .animation(.spring(response: 0.35), value: judgeScores.map(\.revealed))
    }

    // MARK: - AI Turn Overlay

    private var aiTurnOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Text("AI OPPONENT DUNKING...")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.1))
                    .tracking(2)

                ProgressView().tint(Color.orange).scaleEffect(1.4)

                if !aiRoundScores.isEmpty, let lastAI = aiRoundScores.last {
                    Text(String(format: "AI scored %.1f this round", lastAI))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial.opacity(0.85))
        }
    }

    // MARK: - Result Body

    private var resultBody: some View {
        ZStack {
            ResultCanvas(
                playerWon: playerTotalScore >= aiTotalScore,
                playerScore: playerTotalScore,
                aiScore: aiTotalScore
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 300)

                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Text("ROUND BREAKDOWN")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(3)

                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { i in
                                VStack(spacing: 4) {
                                    Text("RND \(i + 1)")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(i < roundScores.count ? String(format: "%.1f", roundScores[i]) : "—")
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                    Text(i < aiRoundScores.count ? String(format: "%.1f", aiRoundScores[i]) : "—")
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.1))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .clipShape(.rect(cornerRadius: 10))
                            }
                        }

                        HStack {
                            Text("YOU")
                                .font(.system(size: 8, design: .monospaced)).foregroundStyle(.cyan)
                            Spacer()
                            Text("AI")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.1))
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.60))
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 20)

                    Button { dismiss() } label: {
                        Text("BACK TO LOBBY")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: - Game Flow

    private func enterQueue() {
        if selectedOpponent == nil { selectedOpponent = lobbyPlayers.randomElement() }
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.2...2.5)))
            await MainActor.run { compPhase = .matched }
        }
    }

    private func beginDunkContest() {
        // AI rival pre-set totals: 23–28 / 30
        aiTargetTotal = Double.random(in: 23...28)
        playerTotalScore = 0
        aiTotalScore = 0
        roundScores = []
        aiRoundScores = []
        dunkRound = 1
        crowdEnergy = 0.3
        selectedDunk = nil
        dunkPhase = .dunkSelect
        compPhase = .dunkContest
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Approach Phase

    private func startApproach() {
        guard let dunk = selectedDunk else { return }
        dunkPhase = .approach
        runProgress = 0
        isSlowMo = false
        comboHits = []
        comboStep = 0
        consecutivePerfects = 0
        comboFlashColor = nil
        comboFlashLabel = ""
        rimGlow = 0
        sparks = []

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        approachTask?.cancel()
        approachTask = Task {
            // runProgress animates 0→1 over 1.5 seconds
            // Combo input zone activates at runProgress == 0.55
            let normalDuration: Double = 1.5
            let normalSteps = 90
            for i in 0...normalSteps {
                guard !Task.isCancelled else { return }
                let p = CGFloat(i) / CGFloat(normalSteps) * 0.85
                await MainActor.run { runProgress = p }
                try? await Task.sleep(for: .milliseconds(Int(normalDuration / Double(normalSteps) * 1000)))

                if p >= 0.55 && dunkPhase == .approach {
                    await MainActor.run {
                        dunkPhase = .comboInput
                        beginComboSequence(dunk: dunk)
                    }
                    break
                }
            }
        }
    }

    // MARK: - Combo System

    private func beginComboSequence(dunk: DunkType) {
        comboStep = 0
        consecutivePerfects = 0
        comboExpired = false
        swipeGestureEnabled = true
        comboFlashColor = nil
        comboFlashLabel = ""
        comboTask?.cancel()
        scheduleNextComboPrompt(dunk: dunk)
    }

    private func scheduleNextComboPrompt(dunk: DunkType) {
        guard comboStep < dunk.comboSequence.count else {
            swipeGestureEnabled = false
            finishCombo(dunk: dunk)
            return
        }

        currentPromptTime = Date()
        comboFlashColor = nil
        comboFlashLabel = ""
        promptTimeRemaining = 1.0

        // Shrinking ring: animates from 1.0 → 0.0 over the 0.45s window
        ringTask?.cancel()
        ringTask = Task {
            let steps = 30
            for s in 0...steps {
                guard !Task.isCancelled else { return }
                let remaining = 1.0 - CGFloat(s) / CGFloat(steps)
                await MainActor.run { promptTimeRemaining = remaining }
                try? await Task.sleep(for: .milliseconds(15))
            }
        }

        // Each prompt shows for 0.45 seconds with a shrinking ring countdown
        comboTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if comboStep < dunk.comboSequence.count && !comboExpired {
                    registerHit(quality: .miss, dunk: dunk)
                }
            }
        }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        guard let dunk = selectedDunk, comboStep < dunk.comboSequence.count else { return }

        let dx = value.translation.width
        let dy = value.translation.height
        let direction: SwipeDirection = abs(dx) > abs(dy)
            ? (dx > 0 ? .right : .left)
            : (dy > 0 ? .down : .up)

        let expected = dunk.comboSequence[comboStep]
        let elapsed = Date().timeIntervalSince(currentPromptTime)

        let quality: HitQuality
        if direction == expected {
            // Within 0.15s of center → PERFECT; within 0.30s → GOOD
            quality = elapsed <= 0.15 ? .perfect : .good
        } else {
            quality = .miss
        }

        comboTask?.cancel()
        ringTask?.cancel()
        registerHit(quality: quality, dunk: dunk)
    }

    private func registerHit(quality: HitQuality, dunk: DunkType) {
        comboHits.append(quality)
        comboFlashColor = quality.color
        comboFlashLabel = quality.label

        // Track consecutive perfects for multiplier boost
        if quality == .perfect {
            consecutivePerfects += 1
        } else {
            consecutivePerfects = 0
        }

        // Haptics
        switch quality {
        case .perfect: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .good:    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .miss:    UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        showHitFeedback(text: quality.label, color: quality.color)
        comboStep += 1

        if comboStep < dunk.comboSequence.count && quality != .miss {
            scheduleNextComboPrompt(dunk: dunk)
        } else if quality == .miss {
            // Chain breaks — fill remaining steps as misses
            Task {
                for _ in comboStep..<dunk.comboSequence.count {
                    await MainActor.run { comboHits.append(.miss) }
                    try? await Task.sleep(for: .milliseconds(80))
                }
                await MainActor.run {
                    comboStep = dunk.comboSequence.count
                    consecutivePerfects = 0
                    swipeGestureEnabled = false
                    finishCombo(dunk: dunk)
                }
            }
        } else if comboStep >= dunk.comboSequence.count {
            swipeGestureEnabled = false
            finishCombo(dunk: dunk)
        }
    }

    private func finishCombo(dunk: DunkType) {
        dunkPhase = .rimMoment
        isSlowMo = true

        approachTask?.cancel()
        approachTask = Task {
            // At runProgress >= 0.85: speed drops to 0.25x (slow-motion)
            // 0.85 → 1.0 over ~0.9s (0.25x speed)
            let slowSteps = 54
            for i in 0...slowSteps {
                guard !Task.isCancelled else { return }
                let p: CGFloat = 0.85 + CGFloat(i) / CGFloat(slowSteps) * 0.15
                await MainActor.run { runProgress = p }
                try? await Task.sleep(for: .milliseconds(16))
            }
            await MainActor.run { runProgress = 1.0 }

            // Orange particle burst from rim (20 sparks radiating outward)
            await MainActor.run { triggerRimSparks() }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

            // Hold 0.9 seconds before result
            try? await Task.sleep(for: .milliseconds(900))

            await MainActor.run {
                let score = calculateDunkScore(dunk: dunk)
                dunkRoundScore = score
                playerTotalScore += score
                roundScores.append(score)
                showJudgeReveal(score: score)
                addScorePopup(score: score)

                // Crowd energy fills with combo quality
                // Perfect 5-combo = full bar instantly; partial = partial fill
                let energyGain = (score / 30.0) * Double(dunk.crowdFactor) * 0.65
                crowdEnergy = min(1.0, crowdEnergy + energyGain)
                // When bar hits 100%: "THE ARENA ERUPTS"
                if crowdEnergy >= 1.0 {
                    triggerArenaErupts()
                }
            }
        }
    }

    // MARK: - Scoring
    // combo_score(0-5) + difficulty(0-3) + crowd(0-2) = max 10.0 per judge

    private func calculateDunkScore(dunk: DunkType) -> Double {
        var comboQuality: Double = 0
        var runningPerfects = 0

        for hit in comboHits {
            // Multipliers: 1.0 / 1.3 / 1.6 / 2.0 / 2.5 for each consecutive perfect
            let multIdx = min(runningPerfects, comboMultipliers.count - 1)
            comboQuality += Double(hit.scoreMultiplier) * Double(comboMultipliers[multIdx])
            if hit == .perfect { runningPerfects += 1 } else { runningPerfects = 0 }
        }

        // Normalize against max possible with all perfects
        var maxQuality: Double = 0
        for i in 0..<dunk.comboSequence.count {
            maxQuality += Double(comboMultipliers[min(i, comboMultipliers.count - 1)])
        }
        let comboNorm = maxQuality > 0 ? min(1.0, comboQuality / maxQuality) : 0

        let comboPoints = comboNorm * 5.0
        let diffPoints  = Double(dunk.baseDifficulty) / 5.0 * 3.0
        let crowdPoints = Double(crowdEnergy) * 2.0

        return min(30.0, max(0, comboPoints + diffPoints + crowdPoints))
    }

    // MARK: - Judge Reveal
    // After each dunk: 3 judge cards at bottom animate in
    // Scores appear one at a time with 0.4s delay (build suspense)

    private func showJudgeReveal(score: Double) {
        let perJudge = score / 3.0
        let j1 = max(0, min(10, perJudge + Double.random(in: -0.5...0.5)))
        let j2 = max(0, min(10, perJudge + Double.random(in: -0.5...0.5)))
        let j3 = max(0, min(10, score - j1 - j2 + Double.random(in: -0.3...0.3)))

        judgeScores = [
            JudgeScore(judgeIndex: 0, score: round(j1 * 10) / 10, revealed: false),
            JudgeScore(judgeIndex: 1, score: round(j2 * 10) / 10, revealed: false),
            JudgeScore(judgeIndex: 2, score: round(j3 * 10) / 10, revealed: false)
        ]
        dunkPhase = .judgeReveal

        judgeRevealTask?.cancel()
        judgeRevealTask = Task {
            for i in 0..<3 {
                // 0.4s delay between each reveal for suspense
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    judgeScores[i].revealed = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }

    private func proceedAfterJudges() {
        dunkPhase = .aiTurn
        runAITurn()
    }

    // MARK: - AI Turn (3 dunks, pre-set totals 23–28/30)

    private func runAITurn() {
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }

            let aiRoundScore: Double
            if dunkRound == 3 {
                let remaining = aiTargetTotal - aiTotalScore
                aiRoundScore = max(0, min(30, remaining + Double.random(in: -1...1)))
            } else {
                aiRoundScore = aiTargetTotal / 3.0 + Double.random(in: -1.5...1.5)
            }

            await MainActor.run {
                aiTotalScore += aiRoundScore
                aiRoundScores.append(aiRoundScore)

                if dunkRound < 3 {
                    dunkRound += 1
                    selectedDunk = nil
                    dunkPhase = .dunkSelect
                    crowdEnergy = max(0.1, crowdEnergy - 0.15)
                } else {
                    finalizeDunkContest()
                }
            }
        }
    }

    // MARK: - Final Result

    private func finalizeDunkContest() {
        let won = playerTotalScore >= aiTotalScore

        if won {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if case .shards(let n) = selectedFee {
                viewModel.profile.evolutionShards += n * 2
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        GameResultService.saveResult(
            modeId: "dunk_competition",
            userScore: Int(playerTotalScore),
            opponentScore: Int(aiTotalScore)
        )

        compPhase = .result
    }

    // MARK: - Rim Sparks (20 sparks radiating outward)

    private func triggerRimSparks() {
        let basketX = UIScreen.main.bounds.width * 0.82
        let rimY    = UIScreen.main.bounds.height * 0.30

        sparks = (0..<20).map { _ in
            let angle = Double.random(in: 0...(Double.pi * 2))
            let speed = CGFloat.random(in: 1.8...4.8)
            return RimSpark(
                x: basketX,
                y: rimY,
                vx: CGFloat(cos(angle)) * speed,
                vy: CGFloat(sin(angle)) * speed - 2,
                alpha: 1.0,
                size: CGFloat.random(in: 3...8)
            )
        }
        rimGlow = 1.0

        sparkAnimTask?.cancel()
        sparkAnimTask = Task {
            for _ in 0..<48 {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .milliseconds(16))
                await MainActor.run {
                    sparks = sparks.compactMap { s in
                        var ns = s
                        ns.x     += s.vx
                        ns.y     += s.vy
                        ns.vy    += 0.15
                        ns.alpha -= 0.035
                        ns.size  -= 0.07
                        return ns.alpha > 0 ? ns : nil
                    }
                    rimGlow = max(0, rimGlow - 0.045)
                }
            }
            await MainActor.run { sparks = []; rimGlow = 0 }
        }
    }

    // MARK: - Arena Erupts

    private func triggerArenaErupts() {
        showArenaErupts = true
        Task {
            try? await Task.sleep(for: .seconds(2.8))
            await MainActor.run { showArenaErupts = false }
        }
    }

    // MARK: - Hit Feedback Flash

    private func showHitFeedback(text: String, color: Color) {
        hitFeedbackText    = text
        hitFeedbackColor   = color
        hitFeedbackScale   = 0.5
        hitFeedbackOpacity = 1.0
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            hitFeedbackScale = 1.1
        }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    hitFeedbackOpacity = 0
                    hitFeedbackScale   = 1.3
                }
            }
        }
    }

    // MARK: - Score Popup

    private func addScorePopup(score: Double) {
        let popup = ScorePopup(text: String(format: "%.1f pts", score),
                               yOffset: 0, opacity: 1.0,
                               xPos: CGFloat.random(in: 140...220), color: .yellow)
        scorePopups.append(popup)
        Task {
            for step in 0..<40 {
                guard !Task.isCancelled else { break }
                let progress = Double(step) / 40.0
                await MainActor.run {
                    if let idx = scorePopups.firstIndex(where: { $0.id == popup.id }) {
                        scorePopups[idx] = ScorePopup(
                            text: popup.text,
                            yOffset: CGFloat(-progress * 70),
                            opacity: 1.0 - progress,
                            xPos: popup.xPos,
                            color: popup.color
                        )
                    }
                }
                try? await Task.sleep(for: .milliseconds(20))
            }
            await MainActor.run { scorePopups.removeAll { $0.id == popup.id } }
        }
    }

    // MARK: - Utility

    private func roundScoreLabel(_ score: Double) -> String {
        if score >= 27 { return "LEGENDARY!" }
        if score >= 23 { return "OUTSTANDING" }
        if score >= 18 { return "SOLID DUNK" }
        if score >= 12 { return "DECENT" }
        return "KEEP WORKING"
    }
}
