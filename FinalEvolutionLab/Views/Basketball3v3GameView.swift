import SwiftUI
import UIKit

// MARK: - Types

private enum v3Phase { case ready, playing, result }
private enum v3ShotResult: String { case score = "SCORE!", blocked = "BLOCKED", miss = "MISS", assist = "ASSIST" }
private enum v3Team { case player, opponent }

// MARK: - New Mechanic Enums

/// Court zones for the Hot Zone system
private enum CourtZone: String, CaseIterable {
    case paint      = "IN THE PAINT!"
    case midRange   = "MID-RANGE!"
    case threePoint = "FROM DEEP!"
    case corner3    = "FROM THE CORNER!"

    /// Base shot percentage for each zone
    var baseShotPct: Double {
        switch self {
        case .paint:      return 0.72
        case .midRange:   return 0.45
        case .threePoint: return 0.36
        case .corner3:    return 0.40
        }
    }

    /// Points awarded
    var pointValue: Int {
        switch self {
        case .paint:      return 2
        case .midRange:   return 2
        case .threePoint: return 3
        case .corner3:    return 3
        }
    }
}

/// Teammate positions for AI play calling
private enum CourtPosition: String {
    case wing   = "WING"
    case elbow  = "ELBOW"
    case corner = "CORNER"
    case basket = "BASKET"
    case top    = "TOP OF KEY"
}

/// Named set plays for the CALL PLAY button
private enum SetPlay: String, CaseIterable {
    case pickAndRoll = "PICK & ROLL"
    case spotUp      = "SPOT UP"
    case iso         = "ISO"
}

/// Defensive formations the player can toggle
private enum DefenseMode: String, CaseIterable {
    case zone     = "ZONE"
    case manToMan = "MAN-TO-MAN"
    case press    = "FULL PRESS"

    var icon: String {
        switch self {
        case .zone:     return "shield.lefthalf.filled"
        case .manToMan: return "figure.stand"
        case .press:    return "bolt.fill"
        }
    }

    /// Extra steal chance for press
    var stealBonus: Double {
        switch self {
        case .press: return 0.20
        default:     return 0.0
        }
    }

    /// Extra foul chance for press
    var foulBonus: Double {
        switch self {
        case .press: return 0.15
        default:     return 0.0
        }
    }

    /// Shot percentage multiplier given up to opponent on open looks
    var openShotMultiplier: Double {
        switch self {
        case .zone:     return 1.18   // more open 3s
        case .manToMan: return 1.0
        case .press:    return 0.90   // contested but risky
        }
    }
}

/// Special highlight play types
private enum HighlightType: String {
    case alleyOop    = "ALLEY OOP!"
    case posterDunk  = "POSTER DUNK!"
    case deepThree   = "FROM HALF COURT!"
    case putback     = "PUTBACK SLAM!"
}

// MARK: - 3v3 Court Canvas

private struct Court3v3Canvas: View {
    let possession: v3Team
    let activePasser: Int
    let shotProgress: Double
    let passProgress: Double
    let passFromIdx: Int; let passToIdx: Int
    let playerPoses: [String]; let opponentPoses: [String]
    let rimShake: Double
    let playerScore: Int
    let opponentScore: Int
    let matchClock: Int
    let shotClock: Int
    let lastResult: v3ShotResult?
    let showResultLabel: Bool
    let comboCount: Int

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = Draw3v3(
                    size: size, t: t,
                    possession: possession,
                    activePasser: activePasser,
                    shotProgress: shotProgress,
                    passProgress: passProgress,
                    passFromIdx: passFromIdx,
                    passToIdx: passToIdx,
                    playerPoses: playerPoses,
                    opponentPoses: opponentPoses,
                    rimShake: rimShake,
                    playerScore: playerScore,
                    opponentScore: opponentScore,
                    matchClock: matchClock,
                    shotClock: shotClock,
                    lastResult: lastResult,
                    showResultLabel: showResultLabel,
                    comboCount: comboCount
                )
                d.render(into: &ctx)
            }
        }
    }
}

// MARK: - Draw3v3

private struct Draw3v3 {
    let W: CGFloat, H: CGFloat, t: Double
    let possession: v3Team
    let activePasser: Int
    let shotProgress: Double, passProgress: Double
    let passFromIdx: Int, passToIdx: Int
    let playerPoses: [String], opponentPoses: [String]
    let rimShake: Double
    let playerScore: Int
    let opponentScore: Int
    let matchClock: Int
    let shotClock: Int
    let lastResult: v3ShotResult?
    let showResultLabel: Bool
    let comboCount: Int

    var floorY: CGFloat { H * 0.68 }
    var rimY: CGFloat { H * 0.33 + CGFloat(rimShake) * 5 * CGFloat(sin(t * 48)) }
    var rimX: CGFloat { W * 0.86 }
    var rimL: CGFloat { rimX - 18 }
    var rimR: CGFloat { rimX + 2 }
    var playerXs: [CGFloat] { [W * 0.20, W * 0.08, W * 0.34] }
    var oppXs: [CGFloat] { [W * 0.58, W * 0.70, W * 0.82] }

    init(size: CGSize, t: Double, possession: v3Team, activePasser: Int,
         shotProgress: Double, passProgress: Double, passFromIdx: Int, passToIdx: Int,
         playerPoses: [String], opponentPoses: [String], rimShake: Double,
         playerScore: Int, opponentScore: Int, matchClock: Int, shotClock: Int,
         lastResult: v3ShotResult?, showResultLabel: Bool, comboCount: Int) {
        W = size.width; H = size.height; self.t = t
        self.possession = possession; self.activePasser = activePasser
        self.shotProgress = shotProgress; self.passProgress = passProgress
        self.passFromIdx = passFromIdx; self.passToIdx = passToIdx
        self.playerPoses = playerPoses; self.opponentPoses = opponentPoses
        self.rimShake = rimShake
        self.playerScore = playerScore; self.opponentScore = opponentScore
        self.matchClock = matchClock; self.shotClock = shotClock
        self.lastResult = lastResult; self.showResultLabel = showResultLabel
        self.comboCount = comboCount
    }

    mutating func render(into ctx: inout GraphicsContext) {
        // ── Outdoor Streetball Court ──
        drawOutdoorBackground(ctx: &ctx)
        drawOutdoorCourt(ctx: &ctx)
        drawOutdoorEnvironment(ctx: &ctx)
        // ── Player Figures ──
        drawShadows(ctx: &ctx)
        for i in 0..<3 {
            let pose = i < opponentPoses.count ? opponentPoses[i] : "guard"
            let isFrozen = frozenDefenderIdx == i
            drawFigure(ctx: &ctx, cx: oppXs[i], fy: floorY, pose: pose,
                       color: Color(red: 1.0, green: 0.25, blue: 0.25), flip: true, index: i + 3,
                       isFrozen: isFrozen, isHot: false)
        }
        for i in 0..<3 {
            let pose = i < playerPoses.count ? playerPoses[i] : "idle"
            let isActive = possession == .player && activePasser == i
            let col: Color = isActive
                ? Color(red: 0.10, green: 0.92, blue: 0.45)
                : Color(red: 0.18, green: 0.78, blue: 1.0)
            let playerIsHot = hotPlayer == i
            drawFigure(ctx: &ctx, cx: playerXs[i], fy: floorY, pose: pose, color: col, flip: false, index: i,
                       isFrozen: false, isHot: playerIsHot)
        }
        if isDriving && possession == .player { drawDriveRush(ctx: &ctx) }
        // ── Ball ──
        if passProgress >= 0 { drawPassArc(ctx: &ctx) }
        else if shotProgress >= 0 { drawShotArc(ctx: &ctx) }
        else { drawDribble(ctx: &ctx) }
        drawBallScoring(ctx: &ctx)
        // ── Hype & Atmosphere ──
        drawHypeAtmosphere(ctx: &ctx)
        drawAtmosphere(ctx: &ctx)
    }

    // MARK: - Court Background #1–#10

    private func drawCourtBackground(ctx: inout GraphicsContext) {
        // #1 — Main dark background fill
        ctx.fill(
            Path(CGRect(origin: .zero, size: CGSize(width: W, height: H))),
            with: .color(Color(red: 0.03, green: 0.04, blue: 0.09))
        )

        // #2 — NBA hardwood floor base (warm maple tone)
        ctx.fill(
            Path(CGRect(x: 0, y: floorY, width: W, height: H - floorY)),
            with: .color(Color(red: 0.55, green: 0.32, blue: 0.10))
        )

        // #3 — Floor plank lines (12 horizontal planks simulated as thin dark lines)
        let plankSpacing: CGFloat = (H - floorY) / 13
        for i in 1...12 {
            let py = floorY + CGFloat(i) * plankSpacing
            var plank = Path()
            plank.move(to: CGPoint(x: 0, y: py))
            plank.addLine(to: CGPoint(x: W, y: py))
            ctx.stroke(plank, with: .color(Color(red: 0.32, green: 0.18, blue: 0.05).opacity(0.55)), lineWidth: 0.7)
        }

        // #4 — Full court boundary line
        ctx.stroke(
            Path(CGRect(x: W * 0.01, y: floorY, width: W * 0.98, height: H - floorY - 2)),
            with: .color(Color.white.opacity(0.30)),
            lineWidth: 1.6
        )

        // #5 — Half-court dividing line
        var halfLine = Path()
        halfLine.move(to: CGPoint(x: W * 0.50, y: floorY))
        halfLine.addLine(to: CGPoint(x: W * 0.50, y: H))
        ctx.stroke(halfLine, with: .color(Color.white.opacity(0.22)), lineWidth: 1.2)

        // #6 — Center circle at half-court
        var centerCircle = Path()
        centerCircle.addArc(
            center: CGPoint(x: W * 0.50, y: floorY + (H - floorY) * 0.5),
            radius: W * 0.08,
            startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false
        )
        ctx.stroke(centerCircle, with: .color(Color.white.opacity(0.18)), lineWidth: 1.0)

        // #7 — Paint / key box (right basket)
        ctx.fill(
            Path(CGRect(x: W * 0.66, y: floorY, width: W * 0.32, height: H - floorY)),
            with: .color(Color(red: 0.72, green: 0.18, blue: 0.10).opacity(0.18))
        )
        ctx.stroke(
            Path(CGRect(x: W * 0.66, y: floorY, width: W * 0.32, height: H - floorY - 2)),
            with: .color(Color.white.opacity(0.14)),
            lineWidth: 0.9
        )

        // #8 — 3-point arc (right basket)
        var arc3 = Path()
        arc3.addArc(
            center: CGPoint(x: rimX, y: floorY),
            radius: W * 0.54,
            startAngle: .degrees(175), endAngle: .degrees(265), clockwise: false
        )
        ctx.stroke(arc3, with: .color(Color.white.opacity(0.20)), lineWidth: 1.2)

        // #9 — Free-throw circle
        var ftCircle = Path()
        ftCircle.addArc(
            center: CGPoint(x: W * 0.67, y: floorY),
            radius: W * 0.11,
            startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false
        )
        ctx.stroke(ftCircle, with: .color(Color.white.opacity(0.14)), lineWidth: 0.8)

        // #10 — Backboard + rim + net (right basket)
        drawBasket(ctx: &ctx)
    }

    // MARK: - Basket (called from Court Background as #10)

    private func drawBasket(ctx: inout GraphicsContext) {
        let bbX = rimX + 5
        // Pole
        var pole = Path()
        pole.move(to: CGPoint(x: bbX + 4, y: floorY))
        pole.addLine(to: CGPoint(x: bbX + 4, y: rimY - 55))
        ctx.stroke(pole, with: .color(Color.white.opacity(0.25)), lineWidth: 3.5)

        // Backboard
        let bbRect = CGRect(x: bbX, y: rimY - 56, width: 11, height: 48)
        ctx.fill(Path(bbRect), with: .color(Color(red: 0.82, green: 0.88, blue: 0.94).opacity(0.70)))
        ctx.stroke(Path(bbRect), with: .color(Color.white.opacity(0.55)), lineWidth: 1.0)

        // Square target on backboard
        ctx.stroke(
            Path(CGRect(x: bbX - 1, y: rimY - 37, width: 13, height: 15)),
            with: .color(Color.red.opacity(0.55)), lineWidth: 1.0
        )

        // Rim with glow
        var rim = Path()
        rim.move(to: CGPoint(x: rimL, y: rimY))
        rim.addLine(to: CGPoint(x: rimR, y: rimY))
        var gc = ctx; gc.addFilter(.shadow(color: Color.orange.opacity(0.85), radius: 6))
        gc.stroke(rim, with: .color(Color.orange), lineWidth: 4.5)

        // Net strings (6 lines)
        for i in 0...5 {
            let tf = CGFloat(i) / 5.0
            let nx = rimL + (rimR - rimL) * tf
            let sway = CGFloat(sin(t * 3.5 + Double(i) * 0.8)) * 1.5
            let ny = rimY + 20 * (1 + abs(tf - 0.5) * 0.4) + sway
            var s = Path()
            s.move(to: CGPoint(x: nx, y: rimY))
            s.addLine(to: CGPoint(x: nx + (0.5 - tf) * 4, y: ny))
            ctx.stroke(s, with: .color(Color.white.opacity(0.22)), lineWidth: 0.9)
        }
    }

    // MARK: - Arena #11–#22

    private func drawArena(ctx: inout GraphicsContext) {
        // #11 — Dark arena ceiling / upper wall gradient
        var ceilRect = Path()
        ceilRect.addRect(CGRect(x: 0, y: 0, width: W, height: floorY))
        ctx.fill(ceilRect, with: .color(Color(red: 0.04, green: 0.05, blue: 0.12)))

        // #12 — Arena spotlight cone beams (8 beams from ceiling)
        let beamPositions: [CGFloat] = [0.06, 0.17, 0.29, 0.40, 0.52, 0.63, 0.75, 0.88]
        let beamTargets: [CGFloat] = [0.15, 0.30, 0.10, 0.50, 0.70, 0.85, 0.60, 0.90]
        for (idx, bx) in beamPositions.enumerated() {
            let tx = W * beamTargets[idx]
            let flicker = 0.03 + 0.02 * sin(t * 2.3 + Double(idx) * 1.1)
            var beam = Path()
            beam.move(to: CGPoint(x: W * bx, y: 0))
            beam.addLine(to: CGPoint(x: tx + 40, y: floorY))
            beam.addLine(to: CGPoint(x: tx - 40, y: floorY))
            beam.closeSubpath()
            ctx.fill(beam, with: .color(Color(red: 1.0, green: 0.95, blue: 0.75).opacity(flicker)))
        }

        // #13 — Crowd tier 1 (back row, smallest)
        let jerseyColors: [Color] = [.green, .blue, .yellow, .red, .white, .orange, .purple, .cyan, .pink]
        let tier1Y = floorY - H * 0.30
        for i in 0..<28 {
            let sx = W * (CGFloat(i) + 0.5) / 28.0
            let bob = CGFloat(sin(t * 1.8 + Double(i) * 0.55)) * 2.0
            let r: CGFloat = 3.2
            let jc = jerseyColors[(i * 3) % jerseyColors.count]
            // Head
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - r * 0.9, y: tier1Y - bob - r * 1.8, width: r * 1.8, height: r * 1.8)),
                with: .color(Color(red: 0.85, green: 0.70, blue: 0.55).opacity(0.45))
            )
            // Body
            ctx.fill(
                Path(CGRect(x: sx - r * 0.8, y: tier1Y - bob, width: r * 1.6, height: r * 1.8)),
                with: .color(jc.opacity(0.38))
            )
        }

        // #14 — Crowd tier 2
        let tier2Y = floorY - H * 0.22
        for i in 0..<22 {
            let sx = W * (CGFloat(i) + 0.5) / 22.0
            let bob = CGFloat(sin(t * 2.1 + Double(i) * 0.65)) * 2.8
            let r: CGFloat = 3.8
            let jc = jerseyColors[(i * 5 + 2) % jerseyColors.count]
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - r, y: tier2Y - bob - r * 1.9, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.88, green: 0.72, blue: 0.58).opacity(0.50))
            )
            ctx.fill(
                Path(CGRect(x: sx - r * 0.9, y: tier2Y - bob, width: r * 1.8, height: r * 2.0)),
                with: .color(jc.opacity(0.42))
            )
        }

        // #15 — Crowd tier 3
        let tier3Y = floorY - H * 0.14
        for i in 0..<16 {
            let sx = W * (CGFloat(i) + 0.5) / 16.0
            let bob = CGFloat(sin(t * 2.4 + Double(i) * 0.75)) * 3.5
            let r: CGFloat = 4.5
            let jc = jerseyColors[(i * 7 + 4) % jerseyColors.count]
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - r, y: tier3Y - bob - r * 2.0, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.90, green: 0.75, blue: 0.60).opacity(0.55))
            )
            ctx.fill(
                Path(CGRect(x: sx - r, y: tier3Y - bob, width: r * 2, height: r * 2.2)),
                with: .color(jc.opacity(0.48))
            )
        }

        // #16 — Crowd tier 4 (floor level, courtside)
        let tier4Y = floorY - H * 0.06
        for i in 0..<12 {
            let sx = W * (CGFloat(i) + 0.5) / 12.0
            let bob = CGFloat(sin(t * 2.8 + Double(i) * 0.9)) * 4.0
            let r: CGFloat = 5.5
            let jc = jerseyColors[(i * 11 + 6) % jerseyColors.count]
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - r, y: tier4Y - bob - r * 2.1, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.92, green: 0.78, blue: 0.62).opacity(0.60))
            )
            ctx.fill(
                Path(CGRect(x: sx - r, y: tier4Y - bob, width: r * 2, height: r * 2.4)),
                with: .color(jc.opacity(0.52))
            )
        }

        // #17 — Jumbotron on ceiling (shows live score)
        let jtW: CGFloat = W * 0.32
        let jtH: CGFloat = H * 0.10
        let jtX: CGFloat = W * 0.34
        let jtY: CGFloat = H * 0.01
        ctx.fill(
            Path(CGRect(x: jtX, y: jtY, width: jtW, height: jtH)),
            with: .color(Color(red: 0.08, green: 0.08, blue: 0.14))
        )
        ctx.stroke(
            Path(CGRect(x: jtX, y: jtY, width: jtW, height: jtH)),
            with: .color(Color(red: 0.90, green: 0.60, blue: 0.10).opacity(0.60)),
            lineWidth: 1.5
        )
        // Jumbotron inner LED glow
        var jtGlow = ctx
        jtGlow.addFilter(.blur(radius: 4))
        jtGlow.fill(
            Path(CGRect(x: jtX + 2, y: jtY + 2, width: jtW - 4, height: jtH - 4)),
            with: .color(Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.12))
        )

        // #18 — Team bench areas (left side = player team, right side = opponent team)
        // Left bench
        ctx.fill(
            Path(CGRect(x: W * 0.00, y: floorY - H * 0.07, width: W * 0.06, height: H * 0.07)),
            with: .color(Color(red: 0.10, green: 0.55, blue: 0.25).opacity(0.20))
        )
        ctx.stroke(
            Path(CGRect(x: W * 0.00, y: floorY - H * 0.07, width: W * 0.06, height: H * 0.07)),
            with: .color(Color(red: 0.10, green: 0.92, blue: 0.45).opacity(0.30)),
            lineWidth: 0.8
        )
        // Right bench
        ctx.fill(
            Path(CGRect(x: W * 0.94, y: floorY - H * 0.07, width: W * 0.06, height: H * 0.07)),
            with: .color(Color(red: 0.55, green: 0.10, blue: 0.10).opacity(0.20))
        )
        ctx.stroke(
            Path(CGRect(x: W * 0.94, y: floorY - H * 0.07, width: W * 0.06, height: H * 0.07)),
            with: .color(Color(red: 1.0, green: 0.25, blue: 0.25).opacity(0.30)),
            lineWidth: 0.8
        )

        // #19 — Advertising boards at baseline (bottom of canvas)
        let adColors: [Color] = [
            Color(red: 0.85, green: 0.20, blue: 0.10),
            Color(red: 0.10, green: 0.50, blue: 0.90),
            Color(red: 0.95, green: 0.75, blue: 0.05),
            Color(red: 0.10, green: 0.75, blue: 0.35),
            Color(red: 0.60, green: 0.10, blue: 0.85)
        ]
        let adW: CGFloat = W / CGFloat(adColors.count)
        for (idx, adC) in adColors.enumerated() {
            let adX = CGFloat(idx) * adW
            ctx.fill(
                Path(CGRect(x: adX + 1, y: H - 14, width: adW - 2, height: 13)),
                with: .color(adC.opacity(0.55))
            )
        }

        // #20 — Shot clock display board (above paint, right side)
        let scW: CGFloat = 28
        let scX: CGFloat = rimX - scW / 2
        let scY: CGFloat = rimY - 80
        let scWarning = shotClock <= 5
        ctx.fill(
            Path(CGRect(x: scX, y: scY, width: scW, height: 18)),
            with: .color(scWarning
                ? Color(red: 0.80, green: 0.10, blue: 0.05)
                : Color(red: 0.08, green: 0.08, blue: 0.14))
        )
        ctx.stroke(
            Path(CGRect(x: scX, y: scY, width: scW, height: 18)),
            with: .color(Color.white.opacity(0.25)),
            lineWidth: 0.8
        )

        // #21 — Arena floor sheen / gloss line across the wood
        var sheen = Path()
        sheen.move(to: CGPoint(x: 0, y: floorY + 3))
        sheen.addLine(to: CGPoint(x: W, y: floorY + 3))
        ctx.stroke(sheen, with: .color(Color.white.opacity(0.18)), lineWidth: 2.5)

        // #22 — Upper arena ambient glow (simulates overhead lighting)
        var arenaGlow = ctx
        arenaGlow.addFilter(.blur(radius: 22))
        var glowShape = Path()
        glowShape.addEllipse(in: CGRect(x: W * 0.25, y: -H * 0.05, width: W * 0.50, height: H * 0.25))
        arenaGlow.fill(glowShape, with: .color(Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.08)))
    }

    // MARK: - Ground shadows (#23)

    private func drawShadows(ctx: inout GraphicsContext) {
        // #23 — Player + opponent foot shadows
        for cx in playerXs + oppXs {
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 18, y: floorY + 2, width: 36, height: 7)),
                with: .color(Color.black.opacity(0.32))
            )
        }
    }

    // MARK: - Stick Figures #24–#50

    private func drawFigure(ctx: inout GraphicsContext, cx: CGFloat, fy: CGFloat,
                             pose: String, color: Color, flip: Bool, index: Int) {
        let sc: CGFloat = H * 0.0028
        let m: CGFloat = flip ? -1 : 1
        let headR = sc * 9
        let bodyH = sc * 26
        let lw: CGFloat = 3.4
        let shoulderY = fy - bodyH - headR * 1.8
        let hipY = shoulderY + bodyH
        let cycle = t.truncatingRemainder(dividingBy: 0.55) / 0.55
        let sinC = CGFloat(sin(cycle * .pi * 2))
        let shoeColor = Color(red: 0.90, green: 0.32, blue: 0.08)
        let skinColor = Color(red: 0.94, green: 0.81, blue: 0.70)

        // #24 — Head (all figures share this operation)
        let headY = shoulderY - headR * 1.8
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - headR, y: headY, width: headR * 2, height: headR * 2)),
            with: .color(skinColor)
        )

        // #25 — Jersey number on torso (team color block)
        ctx.fill(
            Path(CGRect(x: cx - sc * 6, y: shoulderY + 2, width: sc * 12, height: bodyH * 0.55)),
            with: .color(color.opacity(0.70))
        )

        // #26 — Spine line
        var spine = Path()
        spine.move(to: CGPoint(x: cx, y: shoulderY))
        spine.addLine(to: CGPoint(x: cx, y: hipY))
        ctx.stroke(spine, with: .color(color), lineWidth: lw)

        func line(_ a: CGPoint, _ b: CGPoint) {
            var p = Path(); p.move(to: a); p.addLine(to: b)
            ctx.stroke(p, with: .color(color), lineWidth: lw)
        }

        switch pose {
        case "shoot":
            // #27 — Shoot pose: upper arm segment
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 20, y: shoulderY - 18))
            // #28 — Shoot pose: forearm / release extension
            line(CGPoint(x: cx + m * 20, y: shoulderY - 18), CGPoint(x: cx + m * 30, y: shoulderY - 34))
            // #29 — Shoot pose: off-arm pullback
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 14, y: shoulderY + 16))
            // #30 — Shoot pose: right thigh
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 13, y: hipY + 18))
            // #31 — Shoot pose: right shin
            line(CGPoint(x: cx + m * 13, y: hipY + 18), CGPoint(x: cx + m * 10, y: fy))
            // #32 — Shoot pose: left thigh
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 11, y: hipY + 18))
            // #33 — Shoot pose: left shin
            line(CGPoint(x: cx - m * 11, y: hipY + 18), CGPoint(x: cx - m * 9, y: fy))
            // #34 — Shoot pose: shoes fill
            ctx.fill(Path(CGRect(x: cx + m * 5, y: fy - 6, width: m * 14, height: 6)), with: .color(shoeColor))
        case "pass":
            // #35 — Pass pose: upper passing arm
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 30, y: shoulderY + 2))
            // #36 — Pass pose: wrist snap / release
            line(CGPoint(x: cx + m * 30, y: shoulderY + 2), CGPoint(x: cx + m * 40, y: shoulderY + 12))
            // #37 — Pass pose: off-arm counterbalance
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 14, y: shoulderY + 20))
            // #38 — Pass pose: right thigh
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 11, y: hipY + 18))
            // #39 — Pass pose: right shin
            line(CGPoint(x: cx + m * 11, y: hipY + 18), CGPoint(x: cx + m * 9, y: fy))
            // #40 — Pass pose: left thigh
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 9, y: hipY + 16))
            // #41 — Pass pose: left shin
            line(CGPoint(x: cx - m * 9, y: hipY + 16), CGPoint(x: cx - m * 7, y: fy))
        case "guard", "defend":
            // #42 — Defend pose: right arm spread
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 26, y: shoulderY + 12))
            // #43 — Defend pose: left arm spread
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 26, y: shoulderY + 12))
            // #44 — Defend pose: right thigh (wide stance)
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 18, y: hipY + 18))
            // #45a — Defend pose: right shin
            line(CGPoint(x: cx + m * 18, y: hipY + 18), CGPoint(x: cx + m * 14, y: fy))
            // #45b — Defend pose: left thigh
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 18, y: hipY + 18))
            // #45c — Defend pose: left shin
            line(CGPoint(x: cx - m * 18, y: hipY + 18), CGPoint(x: cx - m * 14, y: fy))
            // Defender glow aura
            var gcDef = ctx
            gcDef.addFilter(.blur(radius: 2))
            gcDef.fill(
                Path(ellipseIn: CGRect(x: cx - sc * 20, y: shoulderY, width: sc * 40, height: sc * 14)),
                with: .color(Color.red.opacity(0.12))
            )
        case "pick":
            // Pick / screen — arms crossed on chest
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx + m * 12, y: shoulderY + 14))
            line(CGPoint(x: cx, y: shoulderY + 4), CGPoint(x: cx - m * 12, y: shoulderY + 14))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 8, y: hipY + 18))
            line(CGPoint(x: cx + m * 8, y: hipY + 18), CGPoint(x: cx + m * 6, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 8, y: hipY + 18))
            line(CGPoint(x: cx - m * 8, y: hipY + 18), CGPoint(x: cx - m * 6, y: fy))
            // Screen indicator box
            ctx.stroke(
                Path(CGRect(x: cx - sc * 10, y: shoulderY - 4, width: sc * 20, height: bodyH + 8)),
                with: .color(Color.yellow.opacity(0.35)),
                lineWidth: 1.2
            )
        default:
            // Idle / dribble walk cycle
            let bob = CGFloat(sin(t * 1.5)) * 1.2
            line(CGPoint(x: cx, y: shoulderY + 4 + bob), CGPoint(x: cx + m * 18 * sinC, y: hipY - 4 + bob))
            line(CGPoint(x: cx, y: shoulderY + 4 + bob), CGPoint(x: cx - m * 15 * sinC, y: shoulderY + 18 + bob))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx + m * 11, y: hipY + 18))
            line(CGPoint(x: cx + m * 11, y: hipY + 18), CGPoint(x: cx + m * 9, y: fy))
            line(CGPoint(x: cx, y: hipY), CGPoint(x: cx - m * 11, y: hipY + 18))
            line(CGPoint(x: cx - m * 11, y: hipY + 18), CGPoint(x: cx - m * 9, y: fy))
            ctx.fill(
                Path(CGRect(x: cx + m * 6, y: fy - 6, width: m * 12, height: 6)),
                with: .color(shoeColor)
            )
        }

        // #46 — Active player glow halo
        if !flip && index == activePasser && possession == .player {
            var gc = ctx
            gc.addFilter(.blur(radius: 8))
            gc.fill(
                Path(ellipseIn: CGRect(x: cx - 24, y: headY - 10, width: 48, height: headR * 2 + 20)),
                with: .color(color.opacity(0.45))
            )
        }

        // #47 — Hot hand streak glow (combo >= 3)
        if !flip && comboCount >= 3 {
            var gcHot = ctx
            gcHot.addFilter(.blur(radius: 6))
            let hotIntensity = min(1.0, Double(comboCount) / 8.0)
            gcHot.fill(
                Path(ellipseIn: CGRect(x: cx - 18, y: shoulderY - 10, width: 36, height: bodyH + 20)),
                with: .color(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(hotIntensity * 0.50))
            )
        }
    }

    // MARK: - Ball & Scoring #48–#64

    private func drawBallScoring(ctx: inout GraphicsContext) {
        // #48 — Dribble ball bounce shadow (see drawDribble for ball fill #49)
        // Ball ops #49–#50 are inline in drawDribble / drawPassArc / drawShotArc

        // #51 — 3-pointer star burst (12 stars) when result is score
        if showResultLabel, let result = lastResult, result == .score {
            let burstCx = W * 0.5
            let burstCy = H * 0.35
            for i in 0..<12 {
                let angle = Double(i) / 12.0 * .pi * 2 + t * 2.0
                let radius = CGFloat(30 + 18 * sin(t * 4 + Double(i)))
                let sx = burstCx + CGFloat(cos(angle)) * radius
                let sy = burstCy + CGFloat(sin(angle)) * radius * 0.55
                let starSize: CGFloat = 4.5
                ctx.fill(
                    Path(ellipseIn: CGRect(x: sx - starSize / 2, y: sy - starSize / 2, width: starSize, height: starSize)),
                    with: .color(Color.yellow.opacity(0.75 + 0.25 * sin(t * 5 + Double(i))))
                )
            }
        }

        // #52 — Shot clock warning flash (red overlay when <= 5 seconds)
        if shotClock <= 5 && shotClock > 0 {
            let pulse = CGFloat(0.5 + 0.5 * sin(t * 6.0))
            ctx.fill(
                Path(CGRect(x: 0, y: 0, width: W, height: H)),
                with: .color(Color.red.opacity(Double(pulse) * 0.04))
            )
        }

        // #53 — Rim hit ring expansion on basket
        if rimShake > 0.4 {
            let impF = rimShake
            let burstR = CGFloat(impF) * 25
            var ring = Path()
            ring.addEllipse(in: CGRect(x: (rimL + rimR) / 2 - burstR, y: rimY - burstR * 0.5,
                                       width: burstR * 2, height: burstR))
            ctx.stroke(ring, with: .color(Color.orange.opacity(max(0, impF * 0.7))), lineWidth: 2.2)
        }

        // #54 — Screen-shake dust cloud on dunk (rimShake > 0.8)
        if rimShake > 0.8 {
            for i in 0..<5 {
                let dx = CGFloat(i - 2) * 14
                let dustY = floorY + 4
                var gc = ctx
                gc.addFilter(.blur(radius: 4))
                gc.fill(
                    Path(ellipseIn: CGRect(x: (rimL + rimR) / 2 + dx - 8, y: dustY, width: 16, height: 6)),
                    with: .color(Color.white.opacity(rimShake * 0.15))
                )
            }
        }

        // #55 — Net sway lines on made basket (swish animation)
        if shotProgress > 0.80 || (rimShake > 0.3 && shotProgress < 0) {
            let netCx = (rimL + rimR) / 2
            let swayAmt = CGFloat(sin(t * 8.0)) * 3.0 * CGFloat(rimShake > 0 ? rimShake : 0.3)
            for i in 0...4 {
                let tf = CGFloat(i) / 4.0
                let nx = rimL + (rimR - rimL) * tf
                var ns = Path()
                ns.move(to: CGPoint(x: nx, y: rimY))
                ns.addLine(to: CGPoint(x: nx + swayAmt * (tf - 0.5) * 2 + (netCx - nx) * 0.1, y: rimY + 18))
                ctx.stroke(ns, with: .color(Color.white.opacity(0.35)), lineWidth: 1.1)
            }
        }

        // #56 — Bezier shot-arc ghost path (faint trajectory line)
        if shotProgress >= 0 {
            let sx = playerXs[activePasser] + 12
            let sy = floorY - 52
            let ex = (rimL + rimR) / 2
            let ey = rimY - 5
            let cp = CGPoint(x: (sx + ex) / 2, y: sy - H * 0.22)
            var arcPath = Path()
            arcPath.move(to: CGPoint(x: sx, y: sy))
            arcPath.addQuadCurve(to: CGPoint(x: ex, y: ey), control: cp)
            ctx.stroke(arcPath, with: .color(Color.orange.opacity(0.12)), lineWidth: 1.2)
        }

        // #57 — Pass arc ghost path
        if passProgress >= 0 && passFromIdx < playerXs.count && passToIdx < playerXs.count {
            let sx = playerXs[passFromIdx] + 12
            let sy = floorY - 34
            let exP = playerXs[passToIdx] + 12
            let ey = floorY - 34
            let cp = CGPoint(x: (sx + exP) / 2, y: sy - H * 0.08)
            var passPath = Path()
            passPath.move(to: CGPoint(x: sx, y: sy))
            passPath.addQuadCurve(to: CGPoint(x: exP, y: ey), control: cp)
            ctx.stroke(passPath, with: .color(Color(red: 0.18, green: 0.78, blue: 1.0).opacity(0.15)), lineWidth: 1.0)
        }

        // #58 — Floor court glow beneath basket
        var gcFloor = ctx
        gcFloor.addFilter(.blur(radius: 6))
        gcFloor.fill(
            Path(ellipseIn: CGRect(x: rimX - 32, y: floorY - 2, width: 64, height: 14)),
            with: .color(Color.orange.opacity(0.14))
        )

        // #59 — Block flash (red burst when blocked)
        if showResultLabel, let result = lastResult, result == .blocked {
            var gcBlock = ctx
            gcBlock.addFilter(.blur(radius: 10))
            gcBlock.fill(
                Path(ellipseIn: CGRect(x: W * 0.55, y: floorY - 70, width: 70, height: 55)),
                with: .color(Color.red.opacity(0.50))
            )
        }

        // #60 — Free-throw lane glow when player is active
        if possession == .player {
            var gcFT = ctx
            gcFT.addFilter(.blur(radius: 8))
            gcFT.fill(
                Path(CGRect(x: W * 0.66, y: floorY, width: W * 0.32, height: (H - floorY) * 0.5)),
                with: .color(Color(red: 0.10, green: 0.92, blue: 0.45).opacity(0.06))
            )
        }

        // #61 — Dribble bounce shadow on floor
        if possession == .player && shotProgress < 0 && passProgress < 0 {
            let cx = playerXs[activePasser] + 12
            let bounce = abs(sin(t * .pi / 0.40)) * 16
            let shadowAlpha = 0.25 - (bounce / 16) * 0.18
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 8 + CGFloat(bounce) * 0.3,
                                       y: floorY + 2,
                                       width: 16 - CGFloat(bounce) * 0.5,
                                       height: 5)),
                with: .color(Color.black.opacity(shadowAlpha))
            )
        }

        // #62 — "Hot hand" flame trail on active player (combo >= 2)
        if comboCount >= 2 && possession == .player {
            let cx = playerXs[activePasser] + 12
            let flameColors: [Color] = [.yellow, .orange, Color(red: 1.0, green: 0.3, blue: 0.0)]
            for (fi, fc) in flameColors.enumerated() {
                let fy2 = floorY - CGFloat(fi) * 12 - 20
                var gcFlame = ctx
                gcFlame.addFilter(.blur(radius: 3))
                gcFlame.fill(
                    Path(ellipseIn: CGRect(x: cx - 7, y: fy2 - 6, width: 14, height: 12)),
                    with: .color(fc.opacity(0.35 - Double(fi) * 0.08))
                )
            }
        }

        // #63 — Half-court line highlight when transitioning possession
        if possession == .opponent {
            var gcHalf = ctx
            gcHalf.addFilter(.blur(radius: 3))
            var halfHL = Path()
            halfHL.move(to: CGPoint(x: W * 0.50, y: floorY))
            halfHL.addLine(to: CGPoint(x: W * 0.50, y: H))
            gcHalf.stroke(halfHL, with: .color(Color.red.opacity(0.18)), lineWidth: 2.5)
        }

        // #64 — Timeout huddle indicator (low match clock)
        if matchClock <= 20 && matchClock > 0 {
            let pulseA = CGFloat(0.5 + 0.5 * sin(t * 4.0))
            var gc64 = ctx
            gc64.addFilter(.blur(radius: 5))
            gc64.fill(
                Path(ellipseIn: CGRect(x: W * 0.10, y: floorY - H * 0.12, width: W * 0.15, height: H * 0.10)),
                with: .color(Color(red: 0.10, green: 0.92, blue: 0.45).opacity(Double(pulseA) * 0.30))
            )
        }
    }

    // MARK: - Dribble

    private func drawDribble(ctx: inout GraphicsContext) {
        guard possession == .player else {
            let cx = oppXs[1] - 12; let br: CGFloat = 6.5
            let bounce = abs(sin(t * .pi / 0.40)) * 16
            let by = floorY - CGFloat(bounce) - 5
            var bc = ctx; bc.addFilter(.shadow(color: Color.orange.opacity(0.45), radius: 3))
            bc.fill(Path(ellipseIn: CGRect(x: cx - br, y: by - br, width: br * 2, height: br * 2)),
                    with: .color(Color.orange))
            return
        }
        let cx = playerXs[activePasser] + 12; let br: CGFloat = 6.5
        let bounce = abs(sin(t * .pi / 0.40)) * 16
        let by = floorY - CGFloat(bounce) - 5
        var bc = ctx; bc.addFilter(.shadow(color: Color.orange.opacity(0.45), radius: 3))
        bc.fill(Path(ellipseIn: CGRect(x: cx - br, y: by - br, width: br * 2, height: br * 2)),
                with: .color(Color.orange))
        // Ball seam
        var seam = Path()
        seam.addArc(center: CGPoint(x: cx, y: by), radius: br * 0.72,
                    startAngle: .degrees(-50), endAngle: .degrees(190), clockwise: false)
        ctx.stroke(seam, with: .color(Color.black.opacity(0.28)), lineWidth: 0.9)
    }

    // MARK: - Pass Arc

    private func drawPassArc(ctx: inout GraphicsContext) {
        guard passFromIdx < playerXs.count, passToIdx < playerXs.count else { return }
        let ep = CGFloat(passProgress)
        let sx = playerXs[passFromIdx] + 12; let sy = floorY - 34
        let exP = playerXs[passToIdx] + 12; let ey = floorY - 34
        let br: CGFloat = 6.5
        let bx = sx + (exP - sx) * ep
        let by = sy + (ey - sy) * ep - H * 0.09 * 4 * ep * (1 - ep)
        // Trail
        for trail in 1...3 {
            let pastEp = max(0, ep - CGFloat(trail) * 0.08)
            let tbx = sx + (exP - sx) * pastEp
            let tby = sy + (ey - sy) * pastEp - H * 0.09 * 4 * pastEp * (1 - pastEp)
            ctx.fill(Path(ellipseIn: CGRect(x: tbx - br, y: tby - br, width: br * 2, height: br * 2)),
                     with: .color(Color.orange.opacity(0.20 - Double(trail) * 0.05)))
        }
        var bc = ctx; bc.addFilter(.shadow(color: Color.orange.opacity(0.55), radius: 3))
        bc.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
                with: .color(Color.orange))
    }

    // MARK: - Shot Arc

    private func drawShotArc(ctx: inout GraphicsContext) {
        let ep = CGFloat(shotProgress)
        let sx = playerXs[activePasser] + 12; let sy = floorY - 52
        let ex = (rimL + rimR) / 2; let ey = rimY - 5
        let br: CGFloat = 7.0
        let bx = sx + (ex - sx) * ep
        let by = sy + (ey - sy) * ep - H * 0.28 * 4 * ep * (1 - ep)

        for trail in 1...4 {
            let pastEp = max(0, ep - CGFloat(trail) * 0.07)
            let tbx = sx + (ex - sx) * pastEp
            let tby = sy + (ey - sy) * pastEp - H * 0.28 * 4 * pastEp * (1 - pastEp)
            ctx.fill(Path(ellipseIn: CGRect(x: tbx - br, y: tby - br, width: br * 2, height: br * 2)),
                     with: .color(Color.orange.opacity(0.22 - Double(trail) * 0.04)))
        }
        var bc = ctx; bc.addFilter(.shadow(color: Color.orange.opacity(0.65), radius: 5))
        bc.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
                with: .color(Color.orange))
        var seam = Path()
        seam.addArc(center: CGPoint(x: bx, y: by), radius: br * 0.72,
                    startAngle: .degrees(-50), endAngle: .degrees(190), clockwise: false)
        ctx.stroke(seam, with: .color(Color.black.opacity(0.30)), lineWidth: 0.9)

        // Rim burst on arrival
        if ep > 0.82 {
            let impF = (ep - 0.82) / 0.18
            let burstR = CGFloat(impF) * 24
            var ring = Path()
            ring.addEllipse(in: CGRect(x: ex - burstR, y: ey - burstR * 0.5,
                                       width: burstR * 2, height: burstR))
            ctx.stroke(ring, with: .color(Color.orange.opacity(max(0, 0.80 - impF * 0.95))), lineWidth: 2.2)
        }
    }

    // MARK: - Atmosphere #65–#80

    private func drawAtmosphere(ctx: inout GraphicsContext) {
        // #65 — Crowd confetti particle burst on score
        if showResultLabel, let result = lastResult, result == .score || result == .assist {
            let confettiColors: [Color] = [.red, .blue, .yellow, .green, .white, .orange, .purple, .cyan, .pink]
            for i in 0..<30 {
                let angle = Double(i) / 30.0 * .pi * 2 + t * 1.5
                let speed = 40.0 + Double(i % 7) * 12.0
                let elapsed = t.truncatingRemainder(dividingBy: 0.8) / 0.8
                let cx = W * 0.5 + CGFloat(cos(angle) * speed * elapsed)
                let cy = H * 0.30 + CGFloat(sin(angle) * speed * 0.6 * elapsed) + CGFloat(elapsed * elapsed) * 30
                let cc = confettiColors[i % confettiColors.count]
                let sz: CGFloat = 4.0 + CGFloat(i % 3) * 1.5
                ctx.fill(
                    Path(CGRect(x: cx - sz / 2, y: cy - sz / 3, width: sz, height: sz * 0.5)),
                    with: .color(cc.opacity(max(0, 1.0 - elapsed)))
                )
            }
        }

        // #66 — Buzzer-beater gold vignette edge (match clock <= 10)
        if matchClock <= 10 && matchClock > 0 {
            let pulseV = CGFloat(0.5 + 0.5 * sin(t * 5.0))
            // Top edge
            var gcV = ctx; gcV.addFilter(.blur(radius: 12))
            gcV.fill(
                Path(CGRect(x: 0, y: 0, width: W, height: H * 0.08)),
                with: .color(Color(red: 1.0, green: 0.80, blue: 0.0).opacity(Double(pulseV) * 0.25))
            )
            // Bottom edge
            gcV.fill(
                Path(CGRect(x: 0, y: H - H * 0.08, width: W, height: H * 0.08)),
                with: .color(Color(red: 1.0, green: 0.80, blue: 0.0).opacity(Double(pulseV) * 0.25))
            )
            // Left edge
            gcV.fill(
                Path(CGRect(x: 0, y: 0, width: W * 0.06, height: H)),
                with: .color(Color(red: 1.0, green: 0.80, blue: 0.0).opacity(Double(pulseV) * 0.20))
            )
            // Right edge
            gcV.fill(
                Path(CGRect(x: W - W * 0.06, y: 0, width: W * 0.06, height: H)),
                with: .color(Color(red: 1.0, green: 0.80, blue: 0.0).opacity(Double(pulseV) * 0.20))
            )
        }

        // #67 — Streak indicator arrow above hot player
        if comboCount >= 3 && possession == .player {
            let cx = playerXs[activePasser] + 12
            let sc2: CGFloat = H * 0.0028
            let headR = sc2 * 9
            let bodyH = sc2 * 26
            let shoulderY = floorY - bodyH - headR * 1.8
            let arrowY = shoulderY - headR * 2.5 - 12
            let bounce = CGFloat(sin(t * 3.0)) * 3.0
            var arrow = Path()
            arrow.move(to: CGPoint(x: cx, y: arrowY - 10 + bounce))
            arrow.addLine(to: CGPoint(x: cx - 7, y: arrowY + 2 + bounce))
            arrow.addLine(to: CGPoint(x: cx - 3, y: arrowY + 2 + bounce))
            arrow.addLine(to: CGPoint(x: cx - 3, y: arrowY + 10 + bounce))
            arrow.addLine(to: CGPoint(x: cx + 3, y: arrowY + 10 + bounce))
            arrow.addLine(to: CGPoint(x: cx + 3, y: arrowY + 2 + bounce))
            arrow.addLine(to: CGPoint(x: cx + 7, y: arrowY + 2 + bounce))
            arrow.closeSubpath()
            var gcArrow = ctx; gcArrow.addFilter(.blur(radius: 2))
            gcArrow.fill(arrow, with: .color(Color.yellow.opacity(0.65)))
            ctx.fill(arrow, with: .color(Color(red: 1.0, green: 0.85, blue: 0.0)))
        }

        // #68 — Ambient court floor reflection
        var gcRef = ctx; gcRef.addFilter(.blur(radius: 10))
        gcRef.fill(
            Path(CGRect(x: 0, y: floorY, width: W, height: 18)),
            with: .color(Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.07))
        )

        // #69 — Possession arrow indicator (floating above active player)
        if possession == .player {
            let cx = playerXs[activePasser]
            var dotGlow = ctx; dotGlow.addFilter(.blur(radius: 3))
            dotGlow.fill(
                Path(ellipseIn: CGRect(x: cx - 8, y: floorY - 10, width: 16, height: 6)),
                with: .color(Color(red: 0.10, green: 0.92, blue: 0.45).opacity(0.60))
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 4, y: floorY - 8, width: 8, height: 4)),
                with: .color(Color(red: 0.10, green: 0.92, blue: 0.45))
            )
        }

        // #70 — Arena upper-wall advertising LED strip
        var stripL = Path()
        stripL.move(to: CGPoint(x: 0, y: floorY - H * 0.31))
        stripL.addLine(to: CGPoint(x: W, y: floorY - H * 0.31))
        ctx.stroke(stripL, with: .color(Color(red: 0.90, green: 0.60, blue: 0.10).opacity(0.22)), lineWidth: 1.5)

        // #71 — Fan wave hands (raised arms above crowd heads)
        if showResultLabel, let result = lastResult, (result == .score || result == .assist) {
            for i in 0..<14 {
                let fx = W * (CGFloat(i) + 0.5) / 14.0
                let fy3 = floorY - H * 0.20
                let wave = CGFloat(sin(t * 3.0 + Double(i) * 0.4)) * 5.0
                var arm = Path()
                arm.move(to: CGPoint(x: fx - 3, y: fy3 + wave))
                arm.addLine(to: CGPoint(x: fx, y: fy3 - 10 + wave))
                arm.addLine(to: CGPoint(x: fx + 3, y: fy3 + wave))
                ctx.stroke(arm, with: .color(Color.white.opacity(0.35)), lineWidth: 1.0)
            }
        }

        // #72 — Opponent danger indicator when opponent has possession
        if possession == .opponent {
            var gcDanger = ctx; gcDanger.addFilter(.blur(radius: 14))
            gcDanger.fill(
                Path(CGRect(x: W * 0.45, y: 0, width: W * 0.55, height: H)),
                with: .color(Color.red.opacity(0.05))
            )
        }

        // #73 — Player team side highlight glow when player has possession
        if possession == .player {
            var gcP = ctx; gcP.addFilter(.blur(radius: 14))
            gcP.fill(
                Path(CGRect(x: 0, y: 0, width: W * 0.50, height: H)),
                with: .color(Color(red: 0.10, green: 0.92, blue: 0.45).opacity(0.03))
            )
        }

        // #74 — Shot clock last-second strobe effect
        if shotClock == 1 {
            let strobe = CGFloat(0.5 + 0.5 * sin(t * 12.0))
            ctx.fill(
                Path(CGRect(x: 0, y: 0, width: W, height: H)),
                with: .color(Color.red.opacity(Double(strobe) * 0.06))
            )
        }

        // #75 — Center-circle ambient pulse
        var gcCC = ctx; gcCC.addFilter(.blur(radius: 8))
        let ccPulse = CGFloat(0.3 + 0.15 * sin(t * 1.2))
        gcCC.fill(
            Path(ellipseIn: CGRect(x: W * 0.43, y: floorY + (H - floorY) * 0.30,
                                   width: W * 0.14, height: W * 0.14 * 0.5)),
            with: .color(Color.white.opacity(Double(ccPulse) * 0.08))
        )

        // #76 — Assist flash (cyan glow between passer and catcher during pass)
        if passProgress >= 0 && passFromIdx < playerXs.count && passToIdx < playerXs.count {
            let midX = (playerXs[passFromIdx] + playerXs[passToIdx]) / 2 + 12
            var gcAssist = ctx; gcAssist.addFilter(.blur(radius: 8))
            gcAssist.fill(
                Path(ellipseIn: CGRect(x: midX - 20, y: floorY - 55, width: 40, height: 28)),
                with: .color(Color(red: 0.18, green: 0.78, blue: 1.0).opacity(0.35))
            )
        }

        // #77 — Backboard flash on rim hit
        if rimShake > 0.3 {
            var gcBB = ctx; gcBB.addFilter(.blur(radius: 3))
            gcBB.fill(
                Path(CGRect(x: rimX + 3, y: rimY - 58, width: 13, height: 50)),
                with: .color(Color.orange.opacity(rimShake * 0.45))
            )
        }

        // #78 — Match result overlay pulse (just before result screen)
        if matchClock == 0 {
            var gcEnd = ctx; gcEnd.addFilter(.blur(radius: 18))
            gcEnd.fill(
                Path(CGRect(x: 0, y: 0, width: W, height: H)),
                with: .color(Color.white.opacity(0.12))
            )
        }

        // #79 — Ceiling ambient bounce light from court
        var gcCeiling = ctx; gcCeiling.addFilter(.blur(radius: 20))
        gcCeiling.fill(
            Path(ellipseIn: CGRect(x: W * 0.15, y: 0, width: W * 0.70, height: H * 0.10)),
            with: .color(Color(red: 0.55, green: 0.32, blue: 0.10).opacity(0.06))
        )

        // #80 — Overall canvas vignette (dark edges for depth)
        var gcVig = ctx; gcVig.addFilter(.blur(radius: 30))
        // Top vignette
        gcVig.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H * 0.15)),
            with: .color(Color.black.opacity(0.35))
        )
        // Bottom vignette
        gcVig.fill(
            Path(CGRect(x: 0, y: H * 0.85, width: W, height: H * 0.15)),
            with: .color(Color.black.opacity(0.35))
        )
        // Left vignette
        gcVig.fill(
            Path(CGRect(x: 0, y: 0, width: W * 0.12, height: H)),
            with: .color(Color.black.opacity(0.30))
        )
        // Right vignette
        gcVig.fill(
            Path(CGRect(x: W * 0.88, y: 0, width: W * 0.12, height: H)),
            with: .color(Color.black.opacity(0.30))
        )
    }
}

// MARK: - Main View

struct Basketball3v3GameView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var phase: v3Phase = .ready
    @State private var playerTeamScore: Int = 0
    @State private var opponentTeamScore: Int = 0
    @State private var matchClock: Int = 120
    @State private var matchClockTask: Task<Void, Never>?
    @State private var shotClock: Int = 24
    @State private var shotClockTask: Task<Void, Never>?
    @State private var opponentTask: Task<Void, Never>?
    @State private var comboCount: Int = 0
    @State private var comboMultiplier: Int = 1
    @State private var lastResult: v3ShotResult?
    @State private var showResultLabel: Bool = false
    @State private var lastPasser: String = ""
    @State private var possession: v3Team = .player
    @State private var activePasser: Int = 0
    @State private var shardsRewarded: Bool = false

    // Canvas state
    @State private var shotProgress: Double = -1
    @State private var passProgress: Double = -1
    @State private var passFromIdx: Int = 0
    @State private var passToIdx: Int = 1
    @State private var shotAnimTask: Task<Void, Never>?
    @State private var passAnimTask: Task<Void, Never>?
    @State private var playerPoses: [String] = ["idle", "idle", "idle"]
    @State private var opponentPoses: [String] = ["guard", "guard", "guard"]
    @State private var rimShake: Double = 0
    @State private var screenShake: CGFloat = 0

    // ── Hot Zone System ──────────────────────────────────────────────────
    @State private var playerHotZone: CourtZone = .midRange
    @State private var isHot: Bool = false
    @State private var consecutiveMakesInZone: Int = 0
    @State private var zoneAnnouncerText: String = ""
    @State private var showZoneAnnouncer: Bool = false

    // ── Teammate AI Play Calling ──────────────────────────────────────────
    @State private var teammate1Position: CourtPosition = .wing
    @State private var teammate2Position: CourtPosition = .elbow
    @State private var activeSetPlay: SetPlay? = nil
    @State private var showTeammateOpen: Bool = false
    @State private var teammateOpenText: String = "TEAMMATE OPEN!"
    @State private var playCallCooldown: Bool = false
    @State private var currentPlayIndex: Int = 0

    // ── Defensive Intensity ───────────────────────────────────────────────
    @State private var defenseMode: DefenseMode = .manToMan

    // ── Fatigue & Substitution ────────────────────────────────────────────
    @State private var teamFatigue: Double = 1.0
    @State private var isSubbing: Bool = false
    @State private var subAnimProgress: Double = 0.0
    @State private var subTask: Task<Void, Never>? = nil

    // ── Shot Clock Pressure ───────────────────────────────────────────────
    @State private var shotClockHapticTask: Task<Void, Never>? = nil

    // ── Highlight Plays ───────────────────────────────────────────────────
    @State private var lastHighlight: HighlightType? = nil
    @State private var showHighlight: Bool = false
    @State private var highlightSlowMo: Bool = false

    // Haptic generators
    private let impactHvy   = UIImpactFeedbackGenerator(style: .heavy)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let impactMed   = UIImpactFeedbackGenerator(style: .medium)
    private let impactSoft  = UIImpactFeedbackGenerator(style: .soft)
    private let notif       = UINotificationFeedbackGenerator()

    private let targetScore = 15
    private let accentColor = Color(red: 0.2, green: 0.8, blue: 0.4)
    private let teammateNames = ["Dre", "Kev"]
    private let opponentNames = ["Ghost", "Blaze", "Icy"]

    private var aiShotChance: Double { 0.28 + (viewModel.effectiveMetrics.prqScore / 100) * 0.42 }
    private var aiDelayLow: Double { 2.5 + (1 - viewModel.effectiveMetrics.prqScore / 100) * 2.0 }
    private var aiDelayHigh: Double { aiDelayLow + 1.8 }
    private var formattedClock: String {
        String(format: "%d:%02d", matchClock / 60, matchClock % 60)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.09).ignoresSafeArea()
            switch phase {
            case .ready:
                GetReadyScreen(title: "3v3 Streetball", subtitle: "2-min match · First to 15 wins",
                               countdown: 3, accentColor: accentColor, onComplete: { startGame() })
            case .playing:
                playingBody.offset(x: screenShake)
            case .result:
                resultScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { cancelAllTasks(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { cancelAllTasks() }
    }

    // MARK: - Playing Body

    private var playingBody: some View {
        VStack(spacing: 0) {
            clockHeader.padding(.horizontal, 20).padding(.top, 8)
            scoreBoard.padding(.horizontal, 20).padding(.top, 6)
            fatigueBar.padding(.horizontal, 20).padding(.top, 4)

            Court3v3Canvas(
                possession: possession,
                activePasser: activePasser,
                shotProgress: shotProgress,
                passProgress: passProgress,
                passFromIdx: passFromIdx,
                passToIdx: passToIdx,
                playerPoses: playerPoses,
                opponentPoses: opponentPoses,
                rimShake: rimShake,
                playerScore: playerTeamScore,
                opponentScore: opponentTeamScore,
                matchClock: matchClock,
                shotClock: shotClock,
                lastResult: lastResult,
                showResultLabel: showResultLabel,
                comboCount: comboCount
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16).padding(.vertical, 6)
            .overlay(alignment: .center) {
                ZStack {
                    // Result label
                    if showResultLabel, let result = lastResult {
                        VStack(spacing: 3) {
                            Text(result.rawValue)
                                .font(.system(size: 28, weight: .black, design: .monospaced)).italic()
                                .foregroundStyle(result == .score || result == .assist
                                    ? accentColor
                                    : (result == .blocked ? .red : .secondary))
                                .shadow(color: (result == .score ? accentColor : .red).opacity(0.6), radius: 14)
                            if !lastPasser.isEmpty && result == .assist {
                                Text("ASSIST: \(lastPasser)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(accentColor.opacity(0.8))
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .opacity))
                        .animation(.spring(response: 0.22, dampingFraction: 0.55), value: showResultLabel)
                    }

                    // Zone announcer
                    if showZoneAnnouncer {
                        Text(zoneAnnouncerText)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 1.0, green: 0.88, blue: 0.20))
                            .shadow(color: Color.orange.opacity(0.7), radius: 8)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color.black.opacity(0.55).cornerRadius(8))
                            .offset(y: 48)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                    removal: .opacity))
                    }

                    // Teammate open flash
                    if showTeammateOpen {
                        Text(teammateOpenText)
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.18, green: 0.78, blue: 1.0))
                            .shadow(color: Color.cyan.opacity(0.8), radius: 10)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color.black.opacity(0.60).cornerRadius(9))
                            .offset(y: -60)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }

                    // Highlight play vignette + text
                    if showHighlight, let hl = lastHighlight {
                        ZStack {
                            // Slow-mo dark vignette
                            Color.black.opacity(0.38)
                                .ignoresSafeArea()
                                .transition(.opacity)

                            VStack(spacing: 6) {
                                Text(hl.rawValue)
                                    .font(.system(size: 32, weight: .black, design: .monospaced)).italic()
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.82, blue: 0.0), .orange],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.orange.opacity(0.90), radius: 18)
                                Text("HIGHLIGHT PLAY")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.65)).tracking(3)
                            }
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                        }
                    }

                    // Substitution overlay
                    if isSubbing {
                        VStack(spacing: 6) {
                            Text("SUBSTITUTION IN PROGRESS")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white).tracking(2)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.20)).frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(accentColor)
                                        .frame(width: geo.size.width * subAnimProgress, height: 8)
                                }
                            }.frame(height: 8).frame(maxWidth: 180)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Color.black.opacity(0.72).cornerRadius(12))
                        .offset(y: 80)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.22, dampingFraction: 0.55), value: showResultLabel)
                .animation(.spring(response: 0.22, dampingFraction: 0.55), value: showZoneAnnouncer)
                .animation(.spring(response: 0.25, dampingFraction: 0.60), value: showTeammateOpen)
                .animation(.spring(response: 0.28, dampingFraction: 0.55), value: showHighlight)
                .animation(.spring(response: 0.30, dampingFraction: 0.65), value: isSubbing)
            }

            comboRow.padding(.horizontal, 20).padding(.bottom, 4)
            hotZoneRow.padding(.horizontal, 20).padding(.bottom, 4)
            inputPanel.padding(.horizontal, 20).padding(.bottom, 4)
            advancedControlsRow.padding(.horizontal, 20).padding(.bottom, 4)
            defenseModeRow.padding(.horizontal, 20).padding(.bottom, 16)
        }
    }

    // MARK: - Clock Header

    private var clockHeader: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text("MATCH").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text(formattedClock).font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(matchClock <= 20 ? .red : .white).contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: possession == .player ? "arrowtriangle.right.fill" : "arrowtriangle.left.fill")
                    .foregroundStyle(possession == .player ? accentColor : .red)
                Text(possession == .player ? "YOUR TEAM" : "OPPONENTS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(possession == .player ? accentColor : .red)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("SHOT").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(shotClock)").font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(shotClock <= 5 ? .red : .white).contentTransition(.numericText())
            }
        }
    }

    // MARK: - Score Board

    private var scoreBoard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR TEAM").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(accentColor).tracking(2)
                Text("\(playerTeamScore)").font(.system(size: 44, weight: .black, design: .monospaced)).foregroundStyle(.white).contentTransition(.numericText())
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { idx in
                        let name = idx == 0 ? "YOU" : teammateNames[idx - 1]
                        let isActive = possession == .player && activePasser == idx
                        Text(name).font(.system(size: 9, weight: isActive ? .black : .medium, design: .monospaced))
                            .foregroundStyle(isActive ? accentColor : .secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(isActive ? accentColor.opacity(0.15) : Color.clear)
                            .clipShape(.rect(cornerRadius: 5))
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                Text("–").font(.system(size: 20, weight: .bold)).foregroundStyle(.tertiary)
                Text("TO 15").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text("OPPONENTS").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary).tracking(2)
                Text("\(opponentTeamScore)").font(.system(size: 44, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.45)).contentTransition(.numericText())
                HStack(spacing: 6) {
                    ForEach(opponentNames, id: \.self) { name in
                        Text(name).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1)))
    }

    // MARK: - Combo Row

    private var comboRow: some View {
        Group {
            if comboCount >= 2 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(accentColor)
                    Text("x\(comboMultiplier) HOT STREAK").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(accentColor)
                    Text("(\(comboCount) makes)").font(.system(size: 9, design: .monospaced)).foregroundStyle(accentColor.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(accentColor.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accentColor.opacity(0.3), lineWidth: 1))
                .clipShape(.rect(cornerRadius: 10)).transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill").font(.system(size: 11)).foregroundStyle(accentColor.opacity(0.4))
                    Text("SHOOT · PASS DRE · PASS KEV").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).tracking(1)
                }
            }
        }
        .frame(height: 32).animation(.spring(response: 0.3), value: comboCount)
    }

    // MARK: - Fatigue Bar

    private var fatigueBar: some View {
        HStack(spacing: 8) {
            Text("STAMINA").font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(2)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(teamFatigue > 0.5
                              ? LinearGradient(colors: [accentColor, accentColor.opacity(0.7)],
                                               startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [.orange, .red],
                                               startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(teamFatigue), height: 6)
                        .animation(.linear(duration: 0.4), value: teamFatigue)
                }
            }.frame(height: 6)
            Text("\(Int(teamFatigue * 100))%")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(teamFatigue < 0.5 ? .orange : accentColor)
                .frame(width: 34, alignment: .trailing)
            if teamFatigue < 0.5 {
                Text("LOW").font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.red).tracking(1)
                    .transition(.opacity)
            }
        }
        .frame(height: 14)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(teamFatigue < 0.5 ? Color.red.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 0.8)))
        .animation(.easeInOut(duration: 0.3), value: teamFatigue < 0.5)
    }

    // MARK: - Hot Zone Row

    private var hotZoneRow: some View {
        HStack(spacing: 8) {
            // Zone indicator
            HStack(spacing: 5) {
                Image(systemName: isHot ? "flame.fill" : "mappin.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(isHot ? .orange : .secondary)
                Text(playerHotZone.rawValue)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(isHot ? .orange : .secondary)
                    .lineLimit(1)
                if isHot {
                    Text("+15%").font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.orange.opacity(0.8))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15).cornerRadius(4))
                }
            }
            Spacer()
            // Consecutive makes dots
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { dot in
                    Circle()
                        .fill(dot < consecutiveMakesInZone
                              ? (isHot ? Color.orange : accentColor)
                              : Color.white.opacity(0.15))
                        .frame(width: 7, height: 7)
                        .shadow(color: dot < consecutiveMakesInZone ? accentColor.opacity(0.6) : .clear, radius: 3)
                }
            }
            Text("HOT ZONE").font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(isHot ? Color.orange.opacity(0.08) : Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(isHot ? Color.orange.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 0.8)))
        .animation(.spring(response: 0.3), value: isHot)
    }

    // MARK: - Advanced Controls Row (CALL PLAY + SUB)

    private var advancedControlsRow: some View {
        let active = possession == .player && phase == .playing && shotProgress < 0 && passProgress < 0
        return HStack(spacing: 10) {
            // CALL PLAY button
            Button {
                guard active && !playCallCooldown else { return }
                callPlay()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "megaphone.fill").font(.system(size: 11, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("CALL PLAY").font(.system(size: 9, weight: .black, design: .monospaced))
                        Text(nextPlayName).font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(active && !playCallCooldown ? Color(red: 1.0, green: 0.82, blue: 0.0) : .secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(active && !playCallCooldown
                              ? Color(red: 1.0, green: 0.82, blue: 0.0).opacity(0.10)
                              : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(active && !playCallCooldown
                                    ? Color(red: 1.0, green: 0.82, blue: 0.0).opacity(0.30)
                                    : Color.white.opacity(0.08), lineWidth: 1))
                )
            }.disabled(!active || playCallCooldown)

            // SUB button
            Button {
                guard phase == .playing, !isSubbing else { return }
                performSubstitution()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 11, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SUB").font(.system(size: 9, weight: .black, design: .monospaced))
                        Text(isSubbing ? "IN PROGRESS" : "\(Int(teamFatigue * 100))% STAMINA")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(!isSubbing ? accentColor : .secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(!isSubbing ? accentColor.opacity(0.08) : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(!isSubbing ? accentColor.opacity(0.28) : Color.white.opacity(0.08), lineWidth: 1))
                )
            }.disabled(isSubbing || phase != .playing)
        }
    }

    // MARK: - Defense Mode Row

    private var defenseModeRow: some View {
        VStack(spacing: 4) {
            Text("DEFENSE").font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(3).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                ForEach(DefenseMode.allCases, id: \.self) { mode in
                    Button {
                        guard phase == .playing else { return }
                        withAnimation(.spring(response: 0.25)) { defenseMode = mode }
                        impactMed.impactOccurred()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon).font(.system(size: 9, weight: .bold))
                            Text(mode.rawValue).font(.system(size: 8, weight: .black, design: .monospaced))
                                .lineLimit(1)
                        }
                        .foregroundStyle(defenseMode == mode ? .black : (mode == .press ? .red : accentColor))
                        .padding(.horizontal, 8).padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(defenseMode == mode
                                      ? (mode == .press ? Color.red : accentColor)
                                      : Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .stroke(defenseMode == mode
                                            ? .clear
                                            : (mode == .press ? Color.red.opacity(0.25) : accentColor.opacity(0.18)),
                                            lineWidth: 0.8))
                        )
                    }
                }
            }
            // Defense description
            HStack(spacing: 4) {
                Image(systemName: "info.circle").font(.system(size: 9))
                Text(defenseModeDescription).font(.system(size: 8, design: .monospaced))
            }
            .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.8)))
    }

    private var defenseModeDescription: String {
        switch defenseMode {
        case .zone:     return "Covers paint, gives open 3s"
        case .manToMan: return "Balanced — mirrors every player"
        case .press:    return "HIGH RISK: +20% steal, +15% foul"
        }
    }

    // MARK: - Input Panel

    private var inputPanel: some View {
        let active = possession == .player && phase == .playing && shotProgress < 0 && passProgress < 0
        return VStack(spacing: 12) {
            Button {
                guard active else { return }
                playerShoot()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "basketball.fill").font(.system(size: 18, weight: .bold))
                    Text("SHOOT").font(.system(size: 18, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(active
                    ? LinearGradient(colors: [accentColor, accentColor.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: active ? accentColor.opacity(0.35) : .clear, radius: 12)
            }.disabled(!active)

            HStack(spacing: 12) {
                Button { guard active else { return }; playerPass(to: 1) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left").font(.system(size: 14, weight: .bold))
                        Text("PASS \(teammateNames[0])").font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(active ? accentColor : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(accentColor.opacity(active ? 0.08 : 0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(active ? 0.25 : 0.08), lineWidth: 1))
                    .clipShape(.rect(cornerRadius: 14))
                }.disabled(!active)

                Button { guard active else { return }; playerPass(to: 2) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                        Text("PASS \(teammateNames[1])").font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(active ? accentColor : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(accentColor.opacity(active ? 0.08 : 0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(active ? 0.25 : 0.08), lineWidth: 1))
                    .clipShape(.rect(cornerRadius: 14))
                }.disabled(!active)
            }
        }
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        let playerWon = playerTeamScore > opponentTeamScore
        let didTie = playerTeamScore == opponentTeamScore
        let winner: ResultScreen.ResultWinner = didTie ? .draw : (playerWon ? .p1 : .p2)
        let prqGain = PRQ.modeReward(mode: .basketball3v3, won: playerWon, tied: didTie,
                                     combo: comboCount, criticals: comboCount / 3,
                                     scoreDifferential: playerTeamScore - opponentTeamScore)
        return ResultScreen(winner: winner, p1Score: playerTeamScore, p2Score: opponentTeamScore,
                            title: "3v3 Streetball", accentColor: accentColor, prqGain: prqGain,
                            prqCurrent: viewModel.effectiveMetrics.prqScore,
                            modeAttributeLabel: "Court IQ",
                            modeAttributeValue: PRQ.attributeValue(prq: viewModel.effectiveMetrics.prqScore, for: .basketball3v3)) {
            if !shardsRewarded {
                viewModel.profile.evolutionShards += playerWon ? 50 : (didTie ? 25 : 15)
                SaveSystem.saveProfile(viewModel.profile); shardsRewarded = true
            }
            dismiss()
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        playerTeamScore = 0; opponentTeamScore = 0; comboCount = 0; comboMultiplier = 1
        possession = .player; activePasser = 0; matchClock = 120; shotClock = 24
        showResultLabel = false; lastPasser = ""
        shotProgress = -1; passProgress = -1; rimShake = 0
        playerPoses = ["idle", "idle", "idle"]; opponentPoses = ["guard", "guard", "guard"]
        shardsRewarded = false

        // Reset new mechanics
        playerHotZone = .midRange; isHot = false; consecutiveMakesInZone = 0
        zoneAnnouncerText = ""; showZoneAnnouncer = false
        teammate1Position = .wing; teammate2Position = .elbow
        activeSetPlay = nil; showTeammateOpen = false; playCallCooldown = false
        defenseMode = .manToMan
        teamFatigue = 1.0; isSubbing = false; subAnimProgress = 0.0
        lastHighlight = nil; showHighlight = false; highlightSlowMo = false

        phase = .playing
        startMatchClock(); resetShotClock(); scheduleOpponentAttack()
    }

    private func playerShoot() {
        guard phase == .playing, possession == .player, shotProgress < 0, passProgress < 0 else { return }
        shotClockTask?.cancel()
        let passer = activePasser
        playerPoses[passer] = "shoot"
        impactMed.impactOccurred()

        // ── Determine zone from activePasser position ──
        let zone = activeShootingZone(for: passer)
        playerHotZone = zone

        // ── Build shot % from zone base, hot zone bonus, fatigue, shot-clock pressure ──
        var hitChance = zone.baseShotPct
        // PRQ skill modifier
        hitChance += (viewModel.effectiveMetrics.prqScore / 100) * 0.22
        // Combo hot-hand bonus
        hitChance += Double(comboCount) * 0.012
        // Hot zone +15%
        if isHot { hitChance += 0.15 }
        // Fatigue penalty
        if teamFatigue < 0.5 { hitChance -= 0.10 }
        // Shot clock pressure: <3 seconds left — contested, -20%
        if shotClock <= 3 { hitChance -= 0.20 }
        hitChance = min(0.88, max(0.12, hitChance))

        let made = Double.random(in: 0...1) < hitChance
        let is3pt = zone == .threePoint || zone == .corner3

        shotAnimTask?.cancel()
        shotAnimTask = Task {
            await MainActor.run { shotProgress = 0 }
            let steps = 32
            for step in 0..<steps {
                try? await Task.sleep(for: .milliseconds(15))
                guard !Task.isCancelled else { return }
                await MainActor.run { shotProgress = Double(step + 1) / Double(steps) }
            }
            await MainActor.run {
                shotProgress = -1; playerPoses[passer] = "idle"
                if made {
                    // Hot zone tracking
                    consecutiveMakesInZone += 1
                    if consecutiveMakesInZone >= 3 && !isHot {
                        isHot = true
                        flashZoneAnnouncer("ON FIRE FROM \(zone.rawValue)")
                    } else {
                        flashZoneAnnouncer(zone.rawValue)
                    }

                    comboCount += 1; comboMultiplier = min(4, 1 + comboCount / 3)
                    let pts = zone.pointValue * comboMultiplier
                    withAnimation(.spring(response: 0.3)) { playerTeamScore = min(playerTeamScore + pts, 99) }
                    lastPasser = passer != 0 ? teammateNames[passer - 1] : ""
                    flashResult(passer != 0 ? .assist : .score)
                    triggerRimShake(1.0)
                    drainFatigue(amount: 0.01)

                    // Highlight play check
                    checkForHighlight(zone: zone, momentumCheck: false)

                    if is3pt {
                        impactRigid.impactOccurred()
                    } else {
                        impactHvy.impactOccurred()
                    }
                } else {
                    // Miss resets zone streak
                    consecutiveMakesInZone = 0; isHot = false
                    comboCount = 0; comboMultiplier = 1; lastPasser = ""; flashResult(.miss)
                    triggerRimShake(0.5); impactMed.impactOccurred()
                    drainFatigue(amount: 0.005)
                }
                possession = .opponent; activePasser = 0; resetShotClock()
                if playerTeamScore >= targetScore { endGame(); return }
                scheduleOpponentAttack()
            }
        }
    }

    private func playerPass(to teammate: Int) {
        guard phase == .playing, possession == .player, shotProgress < 0, passProgress < 0 else { return }
        let from = activePasser
        playerPoses[from] = "pass"
        passFromIdx = from; passToIdx = teammate
        impactMed.impactOccurred()

        let succeeded = Double.random(in: 0...1) < 0.78

        passAnimTask?.cancel()
        passAnimTask = Task {
            await MainActor.run { passProgress = 0 }
            for step in 0..<22 {
                try? await Task.sleep(for: .milliseconds(12))
                guard !Task.isCancelled else { return }
                await MainActor.run { passProgress = Double(step + 1) / 22.0 }
            }
            await MainActor.run {
                passProgress = -1; playerPoses[from] = "idle"
                if succeeded {
                    activePasser = teammate
                    playerPoses[teammate] = "idle"
                    scheduleTeammateShot(from: teammate)
                } else {
                    flashResult(.blocked)
                    // Haptic: .medium on defensive block
                    impactMed.impactOccurred()
                    possession = .opponent; activePasser = 0; comboCount = 0; comboMultiplier = 1
                    resetShotClock(); scheduleOpponentAttack()
                }
            }
        }
    }

    private func scheduleTeammateShot(from teammate: Int) {
        Task {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 800...1400)))
            await MainActor.run {
                guard phase == .playing, possession == .player, activePasser == teammate else { return }
                let made = Double.random(in: 0...1) < 0.52
                playerPoses[teammate] = "shoot"

                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await MainActor.run {
                        playerPoses[teammate] = "idle"
                        if made {
                            comboCount += 1; comboMultiplier = min(4, 1 + comboCount / 3)
                            withAnimation(.spring(response: 0.3)) { playerTeamScore = min(playerTeamScore + 2 * comboMultiplier, 99) }
                            lastPasser = teammateNames[teammate - 1]; flashResult(.assist)
                            triggerRimShake(0.8)
                            // Haptic: .heavy on made basket
                            impactHvy.impactOccurred()
                        } else {
                            flashResult(.miss)
                        }
                        possession = .opponent; activePasser = 0; resetShotClock()
                        if playerTeamScore >= targetScore { endGame(); return }
                        scheduleOpponentAttack()
                    }
                }
            }
        }
    }

    private func flashResult(_ result: v3ShotResult) {
        lastResult = result
        withAnimation(.spring(response: 0.2)) { showResultLabel = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { showResultLabel = false } }
        }
    }

    private func triggerRimShake(_ intensity: Double) {
        rimShake = intensity
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run { withAnimation(.spring(response: 0.3)) { rimShake = 0 } }
        }
    }

    private func scheduleOpponentAttack() {
        opponentTask?.cancel()
        guard phase == .playing else { return }
        let delay = Double.random(in: aiDelayLow...aiDelayHigh)
        opponentTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard phase == .playing else { return }

                // Defense mode: press gives steal bonus
                if defenseMode == .press {
                    let stealRoll = Double.random(in: 0...1)
                    if stealRoll < defenseMode.stealBonus {
                        // Steal! Possession flips to player immediately
                        flashZoneAnnouncer("STEAL!")
                        impactRigid.impactOccurred()
                        possession = .player; activePasser = 0; resetShotClock()
                        return
                    }
                    // Press foul chance
                    let foulRoll = Double.random(in: 0...1)
                    if foulRoll < defenseMode.foulBonus {
                        // Foul — opponent gets easy points
                        flashZoneAnnouncer("FOUL CALLED!")
                        impactSoft.impactOccurred()
                        withAnimation(.spring(response: 0.3)) { opponentTeamScore = min(opponentTeamScore + 1, 99) }
                        possession = .player; activePasser = 0; resetShotClock()
                        if opponentTeamScore >= targetScore { endGame() }
                        return
                    }
                }

                opponentPoses = ["guard", "shoot", "guard"]

                // Fatigue penalty on defense
                var effectiveShotChance = aiShotChance * defenseMode.openShotMultiplier
                if teamFatigue < 0.5 { effectiveShotChance *= 1.15 }   // tired defense gives up more
                effectiveShotChance = min(0.80, effectiveShotChance)

                let made = Double.random(in: 0...1) < effectiveShotChance
                if made {
                    withAnimation(.spring(response: 0.3)) { opponentTeamScore = min(opponentTeamScore + 2, 99) }
                    triggerRimShake(0.6); flashScreenShakeFX()
                    impactSoft.impactOccurred()
                    drainFatigue(amount: 0.008)
                } else {
                    impactMed.impactOccurred()
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    await MainActor.run { opponentPoses = ["guard", "guard", "guard"] }
                }
                possession = .player; activePasser = 0; resetShotClock()
                if opponentTeamScore >= targetScore { endGame() }
            }
        }
    }

    private func startMatchClock() {
        matchClockTask?.cancel()
        matchClockTask = Task {
            while matchClock > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { matchClock -= 1 }
            }
            await MainActor.run {
                if phase == .playing {
                    // Haptic: .error on buzzer / end of quarter
                    notif.notificationOccurred(.error)
                    endGame()
                }
            }
        }
    }

    private func resetShotClock() {
        shotClockTask?.cancel(); shotClockHapticTask?.cancel()
        shotClock = 24
        shotClockTask = Task {
            while shotClock > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    shotClock -= 1
                    // Shot clock pressure: flash haptic every second at ≤5
                    if shotClock <= 5 && shotClock > 0 && possession == .player {
                        impactMed.impactOccurred()
                    }
                }
            }
            await MainActor.run {
                guard phase == .playing else { return }
                if possession == .player {
                    // Shot clock violation — turnover + error haptic
                    notif.notificationOccurred(.error)
                    flashZoneAnnouncer("SHOT CLOCK VIOLATION!")
                    comboCount = 0; comboMultiplier = 1
                    consecutiveMakesInZone = 0; isHot = false
                    possession = .opponent; activePasser = 0
                    drainFatigue(amount: 0.02)   // violation costs fatigue
                    scheduleOpponentAttack()
                } else {
                    possession = .player; activePasser = 0
                }
                resetShotClock()
            }
        }
    }

    private func flashScreenShakeFX() {
        withAnimation(.easeOut(duration: 0.06)) { screenShake = 5 }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run { withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { screenShake = 0 } }
        }
    }

    private func endGame() {
        cancelAllTasks()
        GameResultService.saveResult(modeId: "basketball_3v3", userScore: playerTeamScore, opponentScore: opponentTeamScore)
        withAnimation(.spring(response: 0.4)) { phase = .result }
    }

    // MARK: - Hot Zone Helpers

    /// Map active passer index to a court zone (simple heuristic based on who has the ball)
    private func activeShootingZone(for passerIndex: Int) -> CourtZone {
        // Player (index 0) tends to shoot mid-range or 3s
        // Teammate 1 (index 1) tends to paint / elbow
        // Teammate 2 (index 2) is the corner specialist
        switch passerIndex {
        case 0:
            let roll = Double.random(in: 0...1)
            if roll < 0.30 { return .paint }
            else if roll < 0.60 { return .midRange }
            else { return .threePoint }
        case 1:
            let roll = Double.random(in: 0...1)
            if roll < 0.50 { return .paint }
            else { return .midRange }
        case 2:
            let roll = Double.random(in: 0...1)
            if roll < 0.55 { return .corner3 }
            else { return .threePoint }
        default:
            return .midRange
        }
    }

    /// Flash the zone announcer label for 1.6 seconds
    private func flashZoneAnnouncer(_ text: String) {
        zoneAnnouncerText = text
        withAnimation(.spring(response: 0.2)) { showZoneAnnouncer = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            await MainActor.run { withAnimation(.easeOut(duration: 0.4)) { showZoneAnnouncer = false } }
        }
    }

    // MARK: - Fatigue System

    /// Drain team fatigue, clamped to 0
    private func drainFatigue(amount: Double) {
        teamFatigue = max(0.0, teamFatigue - amount)
    }

    /// Perform a substitution: 10s animation, fatigue restores to 0.85
    private func performSubstitution() {
        guard !isSubbing, phase == .playing else { return }
        isSubbing = true; subAnimProgress = 0.0
        impactMed.impactOccurred()
        subTask?.cancel()
        subTask = Task {
            // Animate sub progress over 10 seconds
            for tick in 1...20 {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await MainActor.run { subAnimProgress = Double(tick) / 20.0 }
            }
            await MainActor.run {
                teamFatigue = 0.85
                isSubbing = false; subAnimProgress = 0.0
                flashZoneAnnouncer("FRESH LEGS!")
                impactHvy.impactOccurred()
            }
        }
    }

    // MARK: - Set Play / Teammate AI

    /// Cycle through set plays and execute the next one
    private func callPlay() {
        guard !playCallCooldown, phase == .playing, possession == .player,
              shotProgress < 0, passProgress < 0 else { return }
        let plays = SetPlay.allCases
        activeSetPlay = plays[currentPlayIndex % plays.count]
        currentPlayIndex += 1
        playCallCooldown = true
        guard let play = activeSetPlay else { return }
        impactMed.impactOccurred()
        executeSetPlay(play)
        // Cooldown: 4 seconds between plays
        Task {
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run { playCallCooldown = false }
        }
    }

    private func executeSetPlay(_ play: SetPlay) {
        switch play {
        case .pickAndRoll:
            executePickAndRoll()
        case .spotUp:
            executeSpotUp()
        case .iso:
            executeISO()
        }
    }

    private func executePickAndRoll() {
        // Teammate 1 sets pick, then rolls to basket
        teammate1Position = .elbow
        playerPoses[1] = "pick"
        flashZoneAnnouncer("PICK SET!")
        drainFatigue(amount: 0.015)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            await MainActor.run {
                guard phase == .playing else { return }
                // Roll to basket — 40% open layup
                teammate1Position = .basket
                playerPoses[1] = "shoot"
                let momentum = Double(comboCount) * 0.08
                let alleyOopChance = 0.15
                let openLayupChance = min(0.70, 0.40 + momentum)
                let roll = Double.random(in: 0...1)

                if roll < alleyOopChance && momentum > 0.0 {
                    // Alley oop!
                    triggerHighlight(.alleyOop)
                    withAnimation(.spring(response: 0.3)) { playerTeamScore = min(playerTeamScore + 2 * comboMultiplier, 99) }
                    comboCount += 1; comboMultiplier = min(4, 1 + comboCount / 3)
                    lastPasser = teammateNames[0]; flashResult(.assist)
                    triggerRimShake(1.0); impactHvy.impactOccurred()
                    possession = .opponent; activePasser = 0; resetShotClock()
                    if playerTeamScore >= targetScore { endGame(); return }
                    scheduleOpponentAttack()
                } else if roll < alleyOopChance + openLayupChance {
                    // Regular open layup
                    showTeammateOpenFlash()
                    withAnimation(.spring(response: 0.3)) { playerTeamScore = min(playerTeamScore + 2 * comboMultiplier, 99) }
                    comboCount += 1; comboMultiplier = min(4, 1 + comboCount / 3)
                    lastPasser = teammateNames[0]; flashResult(.assist)
                    triggerRimShake(0.9); impactHvy.impactOccurred()
                    possession = .opponent; activePasser = 0; resetShotClock()
                    if playerTeamScore >= targetScore { endGame(); return }
                    scheduleOpponentAttack()
                } else {
                    flashResult(.miss)
                    possession = .opponent; activePasser = 0; resetShotClock()
                    scheduleOpponentAttack()
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    await MainActor.run { playerPoses[1] = "idle"; teammate1Position = .wing }
                }
            }
        }
    }

    private func executeSpotUp() {
        // Teammate 2 relocates to corner, gets open 3
        teammate2Position = .corner
        playerPoses[2] = "idle"
        showTeammateOpenFlash()
        drainFatigue(amount: 0.01)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                guard phase == .playing else { return }
                playerPoses[2] = "shoot"
                // 50% open corner 3 if good timing
                let timingBonus: Double = shotClock > 10 ? 0.10 : 0.0
                let made = Double.random(in: 0...1) < (0.50 + timingBonus + (isHot ? 0.10 : 0.0))
                if made {
                    withAnimation(.spring(response: 0.3)) { playerTeamScore = min(playerTeamScore + 3 * comboMultiplier, 99) }
                    comboCount += 1; comboMultiplier = min(4, 1 + comboCount / 3)
                    consecutiveMakesInZone += 1
                    lastPasser = teammateNames[1]; flashResult(.assist)
                    flashZoneAnnouncer(CourtZone.corner3.rawValue)
                    triggerRimShake(1.0); impactRigid.impactOccurred()
                } else {
                    flashResult(.miss); consecutiveMakesInZone = 0; isHot = false
                }
                possession = .opponent; activePasser = 0; resetShotClock()
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    await MainActor.run { playerPoses[2] = "idle"; teammate2Position = .elbow }
                }
                if playerTeamScore >= targetScore { endGame(); return }
                scheduleOpponentAttack()
            }
        }
    }

    private func executeISO() {
        // Clear out — player goes 1-on-1 based on momentum
        teammate1Position = .wing; teammate2Position = .wing
        flashZoneAnnouncer("ISO! GO TO WORK!")
        drainFatigue(amount: 0.02)
        // Momentum-based: more combos = better ISO chance
        let momentumBonus = min(0.25, Double(comboCount) * 0.06)
        let isoChance = min(0.75, 0.38 + momentumBonus + (viewModel.effectiveMetrics.prqScore / 100) * 0.20)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                guard phase == .playing else { return }
                playerPoses[activePasser] = "shoot"
                let made = Double.random(in: 0...1) < isoChance
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await MainActor.run {
                        playerPoses[activePasser] = "idle"
                        if made {
                            // Check for poster dunk on ISO
                            if Double(comboCount) > 2 && Double.random(in: 0...1) < 0.18 {
                                triggerHighlight(.posterDunk)
                            }
                            comboCount += 1; comboMultiplier = min(4, 1 + comboCount / 3)
                            withAnimation(.spring(response: 0.3)) { playerTeamScore = min(playerTeamScore + 2 * comboMultiplier, 99) }
                            flashResult(.score); triggerRimShake(1.0); impactHvy.impactOccurred()
                        } else {
                            comboCount = 0; comboMultiplier = 1
                            flashResult(.miss); impactMed.impactOccurred()
                        }
                        possession = .opponent; activePasser = 0; resetShotClock()
                        if playerTeamScore >= targetScore { endGame(); return }
                        scheduleOpponentAttack()
                    }
                }
            }
        }
    }

    // "TEAMMATE OPEN!" banner flash
    private func showTeammateOpenFlash() {
        teammateOpenText = "TEAMMATE OPEN!"
        withAnimation(.spring(response: 0.2)) { showTeammateOpen = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { showTeammateOpen = false } }
        }
    }

    // MARK: - Highlight Plays

    private func checkForHighlight(zone: CourtZone, momentumCheck: Bool) {
        let momentum = Double(comboCount)
        // Deep three from logo area (low probability random)
        if zone == .threePoint && Double.random(in: 0...1) < 0.08 {
            triggerHighlight(.deepThree); return
        }
        // Putback on rebound situation (after a miss + fast response)
        if zone == .paint && Double.random(in: 0...1) < 0.10 {
            triggerHighlight(.putback); return
        }
        _ = momentum
        _ = momentumCheck
    }

    private func triggerHighlight(_ type: HighlightType) {
        lastHighlight = type
        highlightSlowMo = true
        showHighlight = true
        impactHvy.impactOccurred()
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            await MainActor.run { impactHvy.impactOccurred() }
        }
        // Slow-mo vignette for 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) {
                    showHighlight = false; highlightSlowMo = false
                }
            }
        }
    }

    // MARK: - Computed helpers for the play button label

    private var nextPlayName: String {
        SetPlay.allCases[currentPlayIndex % SetPlay.allCases.count].rawValue
    }

    // MARK: - cancelAllTasks

    private func cancelAllTasks() {
        shotClockTask?.cancel(); opponentTask?.cancel()
        matchClockTask?.cancel(); shotAnimTask?.cancel(); passAnimTask?.cancel()
        shotClockTask = nil; opponentTask = nil; matchClockTask = nil
        shotAnimTask = nil; passAnimTask = nil
        // Cancel new mechanic tasks
        subTask?.cancel(); subTask = nil
        shotClockHapticTask?.cancel(); shotClockHapticTask = nil
    }
}
