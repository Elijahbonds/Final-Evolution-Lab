import SwiftUI

// MARK: - Phase

private enum EndlessPhase {
    case ready, fighting, waveClear, result
}

// MARK: - Enemy Types

private enum EnemySide { case left, right }
private enum EnemyType { case grappler, striker, rusher }
private enum PowerUpType { case speedBoost, powerStrike, shield, timeSlow }

// MARK: - Wave Opponent (legacy — kept for HP bar UI)

private struct WaveOpponent: Identifiable {
    let id: UUID = UUID()
    var hp: Double
    let maxHP: Double
    let name: String
    var slideInProgress: Double = 1.0  // 0 = offscreen right, 1 = in position
}

// MARK: - Enemy State (new, full-featured)

private struct EnemyState: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat          // 0=left edge, 1=right edge, slides toward 0.5
    var hp: Double          // 1.0 full, 0=dead
    var chargeProgress: Double  // 0→1, at 1.0 the enemy attacks
    var pose: String        // "approach", "attack", "staggered", "dead"
    var side: EnemySide
    var type: EnemyType
    var name: String
    var slideInProgress: Double = 0.0
    var deathTimer: Double = 0.0    // counts up after death for particle FX
    var isAlive: Bool { hp > 0 }
}

// MARK: - Kill Particle

private struct KillParticle {
    var x: CGFloat; var y: CGFloat
    var vx: CGFloat; var vy: CGFloat
    var life: Double        // 0 = dead, 1 = fresh
    var color: Color
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

// MARK: - Endless Dojo Canvas (AAA)

private struct EndlessDojoCanvas: View {
    let enemies: [EnemyState]
    let particles: [KillParticle]
    let playerPose: String
    let waveNumber: Int
    let dragonActive: Bool
    let accentColor: Color
    let playerHP: Double
    let combo: Int
    let killStreak: Int
    let activePowerUp: PowerUpType?
    let hitFlash: Bool
    let blockActive: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var d = EndlessDojoDrawer(
                    size: size, t: t,
                    enemies: enemies,
                    particles: particles,
                    playerPose: playerPose,
                    waveNumber: waveNumber,
                    dragon: dragonActive,
                    accent: accentColor,
                    playerHP: playerHP,
                    combo: combo,
                    killStreak: killStreak,
                    activePowerUp: activePowerUp,
                    hitFlash: hitFlash,
                    blockActive: blockActive
                )
                d.render(into: &ctx)
            }
        }
    }
}

// MARK: - Stick Pose

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

    // Enemy stances
    static let enemyApproach = EndlessPose(
        rElbow: CGPoint(x:18, y:-50), rWrist: CGPoint(x:28, y:-44),
        lElbow: CGPoint(x:-12, y:-52), lWrist: CGPoint(x:-20, y:-46),
        rKnee:  CGPoint(x:12,  y:-20), rAnkle: CGPoint(x:16, y: 0),
        lKnee:  CGPoint(x:-10, y:-18), lAnkle: CGPoint(x:-14, y: 0),
        shoulder: CGPoint(x:2, y:-56)
    )

    static let enemyAttack = EndlessPose(
        rElbow: CGPoint(x:22, y:-56), rWrist: CGPoint(x:44, y:-56),
        lElbow: CGPoint(x:-10, y:-50), lWrist: CGPoint(x:-12, y:-44),
        rKnee:  CGPoint(x:14,  y:-22), rAnkle: CGPoint(x:18, y: 0),
        lKnee:  CGPoint(x:-10, y:-20), lAnkle: CGPoint(x:-16, y: 0),
        shoulder: CGPoint(x:4, y:-58)
    )

    static let enemyStaggered = EndlessPose(
        rElbow: CGPoint(x:12, y:-40), rWrist: CGPoint(x:8, y:-32),
        lElbow: CGPoint(x:-12, y:-40), lWrist: CGPoint(x:-8, y:-32),
        rKnee:  CGPoint(x:6, y:-16), rAnkle: CGPoint(x:6, y: 0),
        lKnee:  CGPoint(x:-6, y:-16), lAnkle: CGPoint(x:-6, y: 0),
        shoulder: CGPoint(x:-8, y:-46)
    )

    static func forName(_ name: String) -> EndlessPose {
        switch name {
        case "punch":           return .punch
        case "kick":            return .kick
        case "block":           return .block
        case "hit":             return .hit
        case "dragon":          return .dragon
        case "approach":        return .enemyApproach
        case "attack":          return .enemyAttack
        case "staggered":       return .enemyStaggered
        default:                return .idle
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

// MARK: - Dojo Drawer (AAA - Endless)

private struct EndlessDojoDrawer {
    let W: CGFloat, H: CGFloat, t: Double
    let enemies: [EnemyState]
    let particles: [KillParticle]
    let playerPose: String
    let waveNumber: Int
    let dragon: Bool
    let accent: Color
    let playerHP: Double
    let combo: Int
    let killStreak: Int
    let activePowerUp: PowerUpType?
    let hitFlash: Bool
    let blockActive: Bool
    var feetY: CGFloat { H * 0.82 }
    var scale: CGFloat { H * 0.0028 }

    init(size: CGSize, t: Double, enemies: [EnemyState], particles: [KillParticle],
         playerPose: String, waveNumber: Int, dragon: Bool, accent: Color,
         playerHP: Double, combo: Int, killStreak: Int, activePowerUp: PowerUpType?,
         hitFlash: Bool, blockActive: Bool) {
        self.W = size.width; self.H = size.height; self.t = t
        self.enemies = enemies; self.particles = particles
        self.playerPose = playerPose
        self.waveNumber = waveNumber; self.dragon = dragon; self.accent = accent
        self.playerHP = playerHP; self.combo = combo; self.killStreak = killStreak
        self.activePowerUp = activePowerUp; self.hitFlash = hitFlash; self.blockActive = blockActive
    }

    // ── MAIN RENDER ─────────────────────────────────────────────────────────────

    mutating func render(into ctx: inout GraphicsContext) {
        // 1. Background layer
        drawBg(ctx: &ctx)                   // draws #1-#6  (stone floor + neon strips + graffiti)
        drawFloor(ctx: &ctx)                // draws #7-#14 (slab cracks + center line)
        drawCrowdSilhouettes(ctx: &ctx)     // draws #15-#22 (8 spectator silhouettes)
        drawNeonStrips(ctx: &ctx)           // draws #23-#30 (4 neon tubes ceiling/wall)

        // 2. Combo meter (left edge vertical bar)
        drawComboMeter(ctx: &ctx)           // draws #31-#33

        // 3. Wave holographic display
        drawWaveHologram(ctx: &ctx)         // draws #34-#37

        // 4. Dragon aura if active
        if dragon { drawDragonAura(ctx: &ctx) }  // draws #38-#39

        // 5. Shadows
        drawShadows(ctx: &ctx)              // draws #40-#43

        // 6. Player
        let ppv = EndlessPose.forName(playerPose)
        let playerX = W * 0.22
        // Chi aura behind player
        drawChiAura(ctx: &ctx, cx: playerX, hp: playerHP, powerUp: activePowerUp) // #44-#46
        drawFighter(ctx: &ctx, cx: playerX, pose: ppv, color: playerColor(), flip: false, scale: scale * 1.1) // #47-#57
        drawStanceLabel(ctx: &ctx, cx: playerX, pose: playerPose)                 // #58
        if blockActive { drawShieldHex(ctx: &ctx, cx: playerX) }                  // #59-#61

        // 7. Enemies
        drawEnemies(ctx: &ctx)              // draws #62-#80 (up to 3 enemies × multi ops)

        // 8. Kill particles
        drawKillParticles(ctx: &ctx)        // draws #81-#88

        // 9. Kill streak FX
        drawStreakFX(ctx: &ctx)             // draws #89-#92

        // 10. Hit vignette (red edge flash)
        if hitFlash { drawHitVignette(ctx: &ctx) }  // #93-#94

        // 11. Streak overlay text
        drawStreakText(ctx: &ctx)           // #95-#96

        // 12. Boss wave border pulse
        drawBossRing(ctx: &ctx)             // #97-#98

        // 13. Power-up icons floating
        drawPowerUpIcon(ctx: &ctx)          // #99-#101+
    }

    // ── 1. BACKGROUND ───────────────────────────────────────────────────────────

    // Op #1-#6
    private func drawBg(ctx: inout GraphicsContext) {
        // #1 — base dark background gradient
        ctx.fill(
            Path(CGRect(origin: .zero, size: CGSize(width: W, height: H))),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.08),
                    Color(red: 0.02, green: 0.01, blue: 0.03)
                ]),
                startPoint: CGPoint(x: W/2, y: 0),
                endPoint: CGPoint(x: W/2, y: H)
            )
        )

        // #2 — stone slab pattern: 5 vertical dividers
        let panelW = W / 5
        let wallH = feetY
        for i in 0..<5 {
            let px = CGFloat(i) * panelW
            var slab = Path()
            slab.addRect(CGRect(x: px + 1, y: 0, width: panelW - 2, height: wallH))
            ctx.stroke(slab, with: .color(.white.opacity(0.07)), lineWidth: 1)
        }

        // #3 — horizontal wall grid lines
        for row in 1..<6 {
            let gy = wallH / 6.0 * CGFloat(row)
            var hl = Path()
            hl.move(to: CGPoint(x: 0, y: gy))
            hl.addLine(to: CGPoint(x: W, y: gy))
            ctx.stroke(hl, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
        }

        // #4 — crack patterns in stone wall
        let crackSeeds: [(CGFloat, CGFloat)] = [
            (W*0.12, H*0.15), (W*0.45, H*0.25), (W*0.68, H*0.10), (W*0.85, H*0.30)
        ]
        for (cx, cy) in crackSeeds {
            var crack = Path()
            crack.move(to: CGPoint(x: cx, y: cy))
            crack.addLine(to: CGPoint(x: cx + 18, y: cy + 12))
            crack.addLine(to: CGPoint(x: cx + 10, y: cy + 22))
            crack.move(to: CGPoint(x: cx + 18, y: cy + 12))
            crack.addLine(to: CGPoint(x: cx + 28, y: cy + 8))
            ctx.stroke(crack, with: .color(.white.opacity(0.09)), lineWidth: 0.7)
        }

        // #5 — graffiti abstract shapes (urban art tags)
        drawGraffiti(ctx: &ctx)

        // #6 — ambient boss/accent glow tint
        let bossWave = waveNumber >= 5 && waveNumber % 5 == 0
        let glowColor = bossWave ? Color.red : accent
        let glowIntensity = bossWave ? 0.10 : 0.04
        ctx.fill(
            Path(CGRect(origin: .zero, size: CGSize(width: W, height: H))),
            with: .color(glowColor.opacity(glowIntensity + 0.025 * sin(t * 2.1)))
        )
    }

    private func drawGraffiti(ctx: inout GraphicsContext) {
        // Abstract graffiti tag near top-right corner
        let tx: CGFloat = W * 0.75, ty: CGFloat = H * 0.08
        var tag = Path()
        // Large block letter shapes
        tag.addRect(CGRect(x: tx, y: ty, width: 10, height: 18))
        tag.addRect(CGRect(x: tx + 12, y: ty, width: 10, height: 18))
        tag.addEllipse(in: CGRect(x: tx + 24, y: ty + 2, width: 10, height: 14))
        ctx.stroke(tag, with: .color(Color(red: 0.2, green: 0.6, blue: 0.9).opacity(0.22)), lineWidth: 1.5)

        // Small circular graffiti dot clusters
        for dot in 0..<5 {
            let dx = tx + CGFloat(dot) * 8
            let dpth = Path(ellipseIn: CGRect(x: dx, y: ty + 22, width: 4, height: 4))
            ctx.fill(dpth, with: .color(Color(red: 0.8, green: 0.2, blue: 0.6).opacity(0.18)))
        }

        // Second tag left side
        let tx2: CGFloat = W * 0.06, ty2: CGFloat = H * 0.12
        var tag2 = Path()
        tag2.move(to: CGPoint(x: tx2, y: ty2))
        tag2.addLine(to: CGPoint(x: tx2 + 20, y: ty2 - 4))
        tag2.addLine(to: CGPoint(x: tx2 + 16, y: ty2 + 12))
        tag2.addLine(to: CGPoint(x: tx2 + 2, y: ty2 + 14))
        tag2.closeSubpath()
        ctx.stroke(tag2, with: .color(Color(red: 0.9, green: 0.5, blue: 0.1).opacity(0.2)), lineWidth: 1.2)
    }

    // ── 2. FLOOR ─────────────────────────────────────────────────────────────────

    // Op #7-#14
    private func drawFloor(ctx: inout GraphicsContext) {
        let floorY = feetY + 2

        // #7 — dark stone floor fill
        ctx.fill(
            Path(CGRect(x: 0, y: floorY, width: W, height: H - floorY)),
            with: .color(Color(red: 0.08, green: 0.06, blue: 0.10))
        )

        // #8 — floor/wall boundary line
        var floorLine = Path()
        floorLine.move(to: CGPoint(x: 0, y: floorY))
        floorLine.addLine(to: CGPoint(x: W, y: floorY))
        ctx.stroke(floorLine, with: .color(accent.opacity(0.5)), lineWidth: 1.8)

        // #9 — neon reflection on floor (glowing line just below boundary)
        var reflection = Path()
        reflection.move(to: CGPoint(x: 0, y: floorY + 2))
        reflection.addLine(to: CGPoint(x: W, y: floorY + 2))
        ctx.stroke(reflection, with: .color(accent.opacity(0.15 + 0.08 * sin(t * 1.5))), lineWidth: 3)

        // #10 — floor slab horizontal lines
        for i in 1..<5 {
            let my = floorY + CGFloat(i) * (H - floorY) / 5.0
            var ml = Path()
            ml.move(to: CGPoint(x: 0, y: my))
            ml.addLine(to: CGPoint(x: W, y: my))
            ctx.stroke(ml, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
        }

        // #11 — floor slab vertical lines
        for i in 0..<4 {
            let vx = W / 4.0 * CGFloat(i)
            var vl = Path()
            vl.move(to: CGPoint(x: vx, y: floorY))
            vl.addLine(to: CGPoint(x: vx, y: H))
            ctx.stroke(vl, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
        }

        // #12 — floor crack detail
        var floorCrack = Path()
        floorCrack.move(to: CGPoint(x: W * 0.35, y: floorY + 10))
        floorCrack.addLine(to: CGPoint(x: W * 0.42, y: floorY + 20))
        floorCrack.addLine(to: CGPoint(x: W * 0.38, y: floorY + 30))
        ctx.stroke(floorCrack, with: .color(.white.opacity(0.07)), lineWidth: 0.8)

        // #13 — center dividing line
        var cl = Path()
        cl.move(to: CGPoint(x: W/2, y: floorY))
        cl.addLine(to: CGPoint(x: W/2, y: H))
        ctx.stroke(cl, with: .color(accent.opacity(0.18)), lineWidth: 1)

        // #14 — center circle on floor
        let circleR: CGFloat = 28
        let circleRect = CGRect(x: W/2 - circleR, y: floorY + 4, width: circleR*2, height: circleR*1.2)
        ctx.stroke(Path(ellipseIn: circleRect), with: .color(accent.opacity(0.12)), lineWidth: 1)
    }

    // ── 3. CROWD SILHOUETTES ─────────────────────────────────────────────────────

    // Op #15-#22
    private func drawCrowdSilhouettes(ctx: inout GraphicsContext) {
        let crowdY = feetY - H * 0.06
        let baseIntensity = min(1.0, Double(waveNumber) / 10.0)
        // 8 silhouettes spread across background
        let silhouetteXs: [CGFloat] = [
            W*0.03, W*0.13, W*0.25, W*0.38,
            W*0.55, W*0.67, W*0.80, W*0.92
        ]
        for (i, sx) in silhouetteXs.enumerated() {
            let bobOffset = 0.05 * sin(t * 1.8 + Double(i) * 0.9)
            let sy = crowdY + CGFloat(bobOffset) * H
            let sHeight = H * CGFloat(0.06 + 0.015 * Double(i % 3))
            let opacity = 0.12 + 0.12 * baseIntensity + 0.04 * sin(t * 2.2 + Double(i))

            // Head
            let headR: CGFloat = sHeight * 0.18
            let headRect = CGRect(x: sx - headR, y: sy - sHeight - headR*2, width: headR*2, height: headR*2)
            ctx.fill(Path(ellipseIn: headRect), with: .color(.white.opacity(opacity)))

            // Body
            var body = Path()
            body.move(to: CGPoint(x: sx, y: sy - sHeight))
            body.addLine(to: CGPoint(x: sx - sHeight*0.22, y: sy))
            body.addLine(to: CGPoint(x: sx + sHeight*0.22, y: sy))
            body.closeSubpath()
            ctx.fill(body, with: .color(.white.opacity(opacity)))
        }
    }

    // ── 4. NEON STRIPS ──────────────────────────────────────────────────────────

    // Op #23-#30
    private func drawNeonStrips(ctx: inout GraphicsContext) {
        // 4 neon tubes: 2 cyan on ceiling, 2 purple on side walls
        let neonDefs: [(CGPoint, CGPoint, Color, Double)] = [
            // ceiling left
            (CGPoint(x: 0, y: 4), CGPoint(x: W * 0.42, y: 4),
             Color(red: 0.0, green: 0.9, blue: 1.0), 0.0),
            // ceiling right
            (CGPoint(x: W * 0.58, y: 4), CGPoint(x: W, y: 4),
             Color(red: 0.6, green: 0.0, blue: 1.0), 1.1),
            // left wall vertical strip
            (CGPoint(x: 3, y: H * 0.0), CGPoint(x: 3, y: feetY),
             Color(red: 0.0, green: 0.8, blue: 1.0), 2.3),
            // right wall vertical strip
            (CGPoint(x: W - 3, y: H * 0.0), CGPoint(x: W - 3, y: feetY),
             Color(red: 0.7, green: 0.0, blue: 1.0), 3.4)
        ]
        for (start, end, color, phase) in neonDefs {
            let flicker = 0.65 + 0.35 * sin(t * 4.5 + phase)
            var tube = Path()
            tube.move(to: start)
            tube.addLine(to: end)
            // Outer glow
            var glowCtx = ctx
            glowCtx.addFilter(.shadow(color: color.opacity(0.9 * flicker), radius: 8))
            glowCtx.stroke(tube, with: .color(color.opacity(0.7 * flicker)), lineWidth: 3)
            // Core bright line
            ctx.stroke(tube, with: .color(color.opacity(flicker)), lineWidth: 1.5)
        }
    }

    // ── 5. COMBO METER ──────────────────────────────────────────────────────────

    // Op #31-#33
    private func drawComboMeter(ctx: inout GraphicsContext) {
        let meterX: CGFloat = 8
        let meterTop: CGFloat = H * 0.20
        let meterBot: CGFloat = feetY - 10
        let meterH = meterBot - meterTop
        let comboFraction = min(1.0, CGFloat(combo) / 20.0)
        let fillH = meterH * comboFraction

        // #31 — track background
        var track = Path()
        track.addRoundedRect(
            in: CGRect(x: meterX, y: meterTop, width: 8, height: meterH),
            cornerSize: CGSize(width: 4, height: 4)
        )
        ctx.fill(track, with: .color(.white.opacity(0.06)))

        // #32 — fill bar
        if comboFraction > 0 {
            let barColor = combo >= 10 ? Color.red : (combo >= 5 ? Color.orange : Color.cyan)
            var fill = Path()
            fill.addRoundedRect(
                in: CGRect(x: meterX, y: meterBot - fillH, width: 8, height: fillH),
                cornerSize: CGSize(width: 4, height: 4)
            )
            var glowCtx = ctx
            glowCtx.addFilter(.shadow(color: barColor.opacity(0.8), radius: 6))
            glowCtx.fill(fill, with: .color(barColor.opacity(0.9)))
        }

        // #33 — notch markers every 5 combo
        for notch in 1..<4 {
            let ny = meterBot - meterH * CGFloat(notch) / 4.0
            var notchLine = Path()
            notchLine.move(to: CGPoint(x: meterX - 1, y: ny))
            notchLine.addLine(to: CGPoint(x: meterX + 9, y: ny))
            ctx.stroke(notchLine, with: .color(.white.opacity(0.2)), lineWidth: 0.7)
        }
    }

    // ── 6. WAVE HOLOGRAM ────────────────────────────────────────────────────────

    // Op #34-#37
    private func drawWaveHologram(ctx: inout GraphicsContext) {
        let hx = W * 0.78, hy: CGFloat = H * 0.06
        let pulse = 0.7 + 0.3 * sin(t * 3.0)

        // #34 — hologram background rect
        var holoBg = Path()
        holoBg.addRoundedRect(
            in: CGRect(x: hx - 36, y: hy - 12, width: 72, height: 28),
            cornerSize: CGSize(width: 4, height: 4)
        )
        ctx.fill(holoBg, with: .color(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.08 * pulse)))
        ctx.stroke(holoBg, with: .color(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.3 * pulse)), lineWidth: 0.8)

        // #35 — scanline across hologram
        let scanProgress = (t * 0.7).truncatingRemainder(dividingBy: 1.0)
        let scanY = hy - 12 + 28 * scanProgress
        var scanLine = Path()
        scanLine.move(to: CGPoint(x: hx - 36, y: scanY))
        scanLine.addLine(to: CGPoint(x: hx + 36, y: scanY))
        ctx.stroke(scanLine, with: .color(.cyan.opacity(0.3)), lineWidth: 0.5)

        // #36 — "WAVE" label rendered as dots approximation
        var waveLabel = Path()
        waveLabel.addRect(CGRect(x: hx - 33, y: hy - 8, width: 30, height: 6))
        ctx.fill(waveLabel, with: .color(.clear))

        // #37 — wave number digits (3 horizontal bars representing number)
        let digitBars: Int = min(waveNumber, 5)
        for bar in 0..<digitBars {
            let bx = hx - 28 + CGFloat(bar) * 11
            var barPath = Path()
            barPath.addRoundedRect(
                in: CGRect(x: bx, y: hy - 2, width: 8, height: 12),
                cornerSize: CGSize(width: 2, height: 2)
            )
            ctx.fill(barPath, with: .color(Color.cyan.opacity(0.6 * pulse)))
        }
    }

    // ── 7. DRAGON AURA ──────────────────────────────────────────────────────────

    // Op #38-#39
    private func drawDragonAura(ctx: inout GraphicsContext) {
        let cx = W * 0.22, cy = H * 0.55
        // #38 — orbiting dragon energy particles
        for i in 0..<24 {
            let angle = t * 2.2 + Double(i) * (2.0 * .pi / 24.0)
            let r = H * 0.14 + H * 0.04 * sin(t * 3.0 + Double(i))
            let px = cx + CGFloat(cos(angle)) * r
            let py = cy + CGFloat(sin(angle)) * r * 0.6
            let dot = Path(ellipseIn: CGRect(x: px - 3, y: py - 3, width: 6, height: 6))
            ctx.fill(dot, with: .color(Color.yellow.opacity(0.7)))
        }
        // #39 — dragon screen veil
        ctx.fill(
            Path(CGRect(origin: .zero, size: CGSize(width: W, height: H))),
            with: .color(Color.yellow.opacity(0.05 + 0.03 * sin(t * 4)))
        )
    }

    // ── 8. SHADOWS ──────────────────────────────────────────────────────────────

    // Op #40-#43
    private func drawShadows(ctx: inout GraphicsContext) {
        let fy = feetY + 3
        // #40 — player shadow
        let ps = Path(ellipseIn: CGRect(x: W*0.22 - 18, y: fy, width: 36, height: 8))
        ctx.fill(ps, with: .color(.black.opacity(0.4)))

        // #41-#43 — enemy shadows
        let enemyXPositions: [CGFloat] = [W * 0.72, W * 0.58, W * 0.83]
        for (i, enemy) in enemies.enumerated() {
            guard i < enemyXPositions.count, enemy.isAlive else { continue }
            let ex = CGFloat(enemy.x) * W
            let slideX = ex + (1.0 - CGFloat(enemy.slideInProgress)) * W * 0.35
            let s = Path(ellipseIn: CGRect(x: slideX - 16, y: fy, width: 32, height: 6))
            ctx.fill(s, with: .color(.black.opacity(0.3)))
        }
    }

    // ── 9. CHI AURA ─────────────────────────────────────────────────────────────

    // Op #44-#46
    private func drawChiAura(ctx: inout GraphicsContext, cx: CGFloat, hp: Double, powerUp: PowerUpType?) {
        let cy = feetY - scale * 40
        let pulse = 0.6 + 0.4 * sin(t * 2.5)
        let hpFraction = hp / 100.0
        let auraR = scale * 28 + scale * 6 * pulse

        // #44 — outer chi glow ring
        let auraColor: Color = {
            switch powerUp {
            case .speedBoost: return .yellow
            case .powerStrike: return .orange
            case .shield:      return .cyan
            case .timeSlow:    return Color(red: 0.7, green: 0.0, blue: 1.0)
            case nil:          return Color(red: 0.0, green: 0.8, blue: 1.0)
            }
        }()
        let auraRect = CGRect(x: cx - auraR, y: cy - auraR, width: auraR*2, height: auraR*2)
        var glowCtx = ctx
        glowCtx.addFilter(.shadow(color: auraColor.opacity(0.6 * pulse * hpFraction), radius: 16))
        glowCtx.fill(Path(ellipseIn: auraRect), with: .color(auraColor.opacity(0.12 * hpFraction)))

        // #45 — HP-dependent inner ring
        let innerR = auraR * 0.7
        let innerRect = CGRect(x: cx - innerR, y: cy - innerR, width: innerR*2, height: innerR*2)
        ctx.stroke(Path(ellipseIn: innerRect), with: .color(auraColor.opacity(0.25 * hpFraction)), lineWidth: 1.5)

        // #46 — pulsing core dot
        let coreR: CGFloat = scale * 4 * pulse
        let coreRect = CGRect(x: cx - coreR, y: cy - coreR, width: coreR*2, height: coreR*2)
        ctx.fill(Path(ellipseIn: coreRect), with: .color(auraColor.opacity(0.35 * pulse)))
    }

    // ── 10. PLAYER FIGHTER ──────────────────────────────────────────────────────

    // Op #47-#57
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
        let headR = scale * 9

        // #47 — head fill
        let headRect = CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR*2, height: headR*2)
        ctx.fill(Path(ellipseIn: headRect), with: .color(color.opacity(0.9)))

        // #48 — head outline
        ctx.stroke(Path(ellipseIn: headRect), with: .color(color.opacity(0.4)), lineWidth: scale * 0.5)

        func limb(_ a: CGPoint, _ b: CGPoint) {
            var p = Path()
            p.move(to: a); p.addLine(to: b)
            ctx.stroke(p, with: .color(color), lineWidth: scale * 2.4)
        }

        // #49 — torso (shoulder → hip)
        limb(shoulderPt, hipPt)
        // #50 — neck (head → shoulder)
        limb(CGPoint(x: headCenter.x, y: headCenter.y + headR), shoulderPt)
        // #51-#52 — right arm
        limb(shoulderPt, pt(pose.rElbow))
        limb(pt(pose.rElbow), pt(pose.rWrist))
        // #53-#54 — left arm
        limb(shoulderPt, pt(pose.lElbow))
        limb(pt(pose.lElbow), pt(pose.lWrist))
        // #55-#56 — right leg
        limb(hipPt, pt(pose.rKnee))
        limb(pt(pose.rKnee), pt(pose.rAnkle))
        // #57 — left leg (split into 2)
        limb(hipPt, pt(pose.lKnee))
        limb(pt(pose.lKnee), pt(pose.lAnkle))
    }

    // ── 11. STANCE LABEL ────────────────────────────────────────────────────────

    // Op #58
    private func drawStanceLabel(ctx: inout GraphicsContext, cx: CGFloat, pose: String) {
        let labelText: String
        let labelColor: Color
        switch pose {
        case "block":  labelText = "BLOCKING"; labelColor = .cyan
        case "punch":  labelText = "STRIKING"; labelColor = .orange
        case "kick":   labelText = "KICK";     labelColor = .orange
        case "dragon": labelText = "DRAGON";   labelColor = .yellow
        case "hit":    labelText = "HIT!";     labelColor = .red
        default:       labelText = "READY";    labelColor = Color.white.opacity(0.5)
        }
        let labelY = feetY + 16
        var labelRect = Path()
        labelRect.addRect(CGRect(x: cx - 28, y: labelY, width: 56, height: 10))
        ctx.fill(labelRect, with: .color(.clear))

        // Draw label as a colored rectangle approximation (actual text via Canvas text)
        let labelWidth: CGFloat = CGFloat(labelText.count) * 5.5
        var labelBg = Path()
        labelBg.addRoundedRect(
            in: CGRect(x: cx - labelWidth/2 - 4, y: labelY, width: labelWidth + 8, height: 10),
            cornerSize: CGSize(width: 2, height: 2)
        )
        ctx.fill(labelBg, with: .color(labelColor.opacity(0.2)))
        ctx.stroke(labelBg, with: .color(labelColor.opacity(0.5)), lineWidth: 0.5)
    }

    // ── 12. SHIELD HEXAGON ──────────────────────────────────────────────────────

    // Op #59-#61
    private func drawShieldHex(ctx: inout GraphicsContext, cx: CGFloat) {
        let cy = feetY - scale * 40
        let hexR: CGFloat = scale * 32
        let pulse = 0.7 + 0.3 * sin(t * 5.0)

        // #59 — outer hex glow
        var hexOuter = Path()
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3.0 + .pi / 6.0
            let hx = cx + cos(angle) * hexR
            let hy = cy + sin(angle) * hexR * 0.8
            if i == 0 { hexOuter.move(to: CGPoint(x: hx, y: hy)) }
            else { hexOuter.addLine(to: CGPoint(x: hx, y: hy)) }
        }
        hexOuter.closeSubpath()
        var glowCtx = ctx
        glowCtx.addFilter(.shadow(color: Color.cyan.opacity(0.8 * pulse), radius: 12))
        glowCtx.stroke(hexOuter, with: .color(Color.cyan.opacity(0.7 * pulse)), lineWidth: 2)

        // #60 — inner hex fill
        var hexInner = Path()
        let innerR = hexR * 0.82
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3.0 + .pi / 6.0
            let hx = cx + cos(angle) * innerR
            let hy = cy + sin(angle) * innerR * 0.8
            if i == 0 { hexInner.move(to: CGPoint(x: hx, y: hy)) }
            else { hexInner.addLine(to: CGPoint(x: hx, y: hy)) }
        }
        hexInner.closeSubpath()
        ctx.fill(hexInner, with: .color(Color.cyan.opacity(0.08 * pulse)))

        // #61 — hex pattern detail lines (crosshatch inside)
        var cross = Path()
        cross.move(to: CGPoint(x: cx - hexR * 0.5, y: cy))
        cross.addLine(to: CGPoint(x: cx + hexR * 0.5, y: cy))
        cross.move(to: CGPoint(x: cx, y: cy - hexR * 0.4))
        cross.addLine(to: CGPoint(x: cx, y: cy + hexR * 0.4))
        ctx.stroke(cross, with: .color(Color.cyan.opacity(0.2 * pulse)), lineWidth: 0.7)
    }

    // ── 13. ENEMIES ─────────────────────────────────────────────────────────────

    // Op #62-#80 (up to 3 enemies × ~6 ops each + charge rings)
    private func drawEnemies(ctx: inout GraphicsContext) {
        let enemyXPositions: [CGFloat] = [W * 0.72, W * 0.58, W * 0.83]
        let bossWave = waveNumber >= 5 && waveNumber % 5 == 0

        for (i, enemy) in enemies.enumerated() {
            guard i < enemyXPositions.count else { break }
            guard enemy.isAlive || enemy.deathTimer < 0.5 else { continue }

            let baseX = enemyXPositions[i]
            let slideOffset = (1.0 - CGFloat(enemy.slideInProgress)) * W * 0.35
            let sideOffset: CGFloat = enemy.side == .left ? -W * 0.15 : 0
            let ex = baseX + slideOffset + sideOffset

            let isBoss = bossWave && i == 0
            let enemyScale = isBoss ? scale * 1.35 : scale
            let enemyColor: Color = {
                switch enemy.type {
                case .grappler: return Color(red: 0.9, green: 0.2, blue: 0.2)
                case .striker:  return Color(red: 1.0, green: 0.5, blue: 0.1)
                case .rusher:   return Color(red: 0.8, green: 0.1, blue: 0.8)
                }
            }()

            let pose = EndlessPose.forName(enemy.pose)

            // Charge ring (drawn behind enemy)
            if enemy.chargeProgress > 0 && enemy.isAlive {
                drawChargeRing(ctx: &ctx, cx: ex, charge: enemy.chargeProgress)
            }

            // Enemy figure
            if enemy.isAlive {
                drawFighter(ctx: &ctx, cx: ex, pose: pose, color: enemyColor, flip: true, scale: enemyScale)
            }

            // HP bar above enemy head
            if enemy.isAlive {
                drawEnemyHPBar(ctx: &ctx, cx: ex, hp: enemy.hp, enemyScale: enemyScale)
            }
        }
    }

    private func drawChargeRing(ctx: inout GraphicsContext, cx: CGFloat, charge: Double) {
        let cy = feetY - scale * 42
        let ringR: CGFloat = scale * 22
        let chargeColor = Color(red: 1.0, green: 0.3, blue: 0.1)

        // Op: charge ring outer glow
        var ringPath = Path()
        ringPath.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: ringR,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * charge),
            clockwise: false
        )
        var glowCtx = ctx
        glowCtx.addFilter(.shadow(color: chargeColor.opacity(0.8), radius: 8))
        glowCtx.stroke(
            ringPath,
            with: .color(chargeColor.opacity(CGFloat(charge) * 0.9)),
            lineWidth: CGFloat(charge * 4 + 1.5)
        )

        // Op: charge ring track
        var trackPath = Path()
        trackPath.addEllipse(in: CGRect(x: cx - ringR, y: cy - ringR, width: ringR*2, height: ringR*2))
        ctx.stroke(trackPath, with: .color(chargeColor.opacity(0.15)), lineWidth: 1.0)
    }

    private func drawEnemyHPBar(ctx: inout GraphicsContext, cx: CGFloat, hp: Double, enemyScale: CGFloat) {
        let barY = feetY - enemyScale * 88
        let barW: CGFloat = 32
        let fillW = barW * CGFloat(hp)

        var track = Path()
        track.addRect(CGRect(x: cx - barW/2, y: barY, width: barW, height: 4))
        ctx.fill(track, with: .color(.white.opacity(0.1)))

        if fillW > 0 {
            let barColor: Color = hp > 0.6 ? .green : (hp > 0.3 ? .yellow : .red)
            var fill = Path()
            fill.addRect(CGRect(x: cx - barW/2, y: barY, width: fillW, height: 4))
            ctx.fill(fill, with: .color(barColor.opacity(0.85)))
        }
    }

    // ── 14. KILL PARTICLES ──────────────────────────────────────────────────────

    // Op #81-#88
    private func drawKillParticles(ctx: inout GraphicsContext) {
        for particle in particles where particle.life > 0 {
            let r: CGFloat = 3 * CGFloat(particle.life)
            let pr = Path(ellipseIn: CGRect(x: particle.x - r, y: particle.y - r, width: r*2, height: r*2))
            ctx.fill(pr, with: .color(particle.color.opacity(particle.life)))
        }
    }

    // ── 15. STREAK FX ───────────────────────────────────────────────────────────

    // Op #89-#92
    private func drawStreakFX(ctx: inout GraphicsContext) {
        guard killStreak >= 5 else { return }
        let playerX = W * 0.22
        let playerY = feetY - scale * 50

        // #89 — flame particles emanating from player
        for i in 0..<8 {
            let angle = t * 3.0 + Double(i) * (.pi * 2 / 8.0)
            let dist = CGFloat(20 + 15 * sin(t * 2 + Double(i) * 0.7))
            let fx = playerX + cos(angle) * dist
            let fy = playerY + sin(angle) * dist * 0.6
            let fSize: CGFloat = 4 + 2 * sin(t * 4 + Double(i))
            let flameColor: Color = i % 2 == 0 ? .orange : .red
            ctx.fill(
                Path(ellipseIn: CGRect(x: fx - fSize/2, y: fy - fSize/2, width: fSize, height: fSize)),
                with: .color(flameColor.opacity(0.7))
            )
        }

        // #90 — streak glow overlay on player
        let streakR: CGFloat = scale * 35
        let glowRect = CGRect(x: playerX - streakR, y: playerY - streakR, width: streakR*2, height: streakR*2)
        var glowCtx = ctx
        glowCtx.addFilter(.shadow(color: Color.orange.opacity(0.6), radius: 20))
        glowCtx.fill(Path(ellipseIn: glowRect), with: .color(Color.orange.opacity(0.05)))

        if killStreak >= 10 {
            // #91 — pulsing red screen border for UNSTOPPABLE
            let pulse = 0.5 + 0.5 * sin(t * 6.0)
            let borderW: CGFloat = 8 * pulse
            var border = Path()
            border.addRect(CGRect(x: 0, y: 0, width: W, height: borderW))
            border.addRect(CGRect(x: 0, y: H - borderW, width: W, height: borderW))
            border.addRect(CGRect(x: 0, y: 0, width: borderW, height: H))
            border.addRect(CGRect(x: W - borderW, y: 0, width: borderW, height: H))
            ctx.fill(border, with: .color(Color.red.opacity(0.4 * pulse)))

            // #92 — extra outer ring pulse
            let ringR2 = streakR * 1.5
            let ringRect = CGRect(x: playerX - ringR2, y: playerY - ringR2, width: ringR2*2, height: ringR2*2)
            ctx.stroke(Path(ellipseIn: ringRect),
                       with: .color(Color.red.opacity(0.3 * pulse)), lineWidth: 2)
        }
    }

    // ── 16. HIT VIGNETTE ────────────────────────────────────────────────────────

    // Op #93-#94
    private func drawHitVignette(ctx: inout GraphicsContext) {
        // #93 — red edge vignette
        let vigSize: CGFloat = 40
        // top edge
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: vigSize)),
            with: .linearGradient(
                Gradient(colors: [Color.red.opacity(0.45), .clear]),
                startPoint: CGPoint(x: W/2, y: 0), endPoint: CGPoint(x: W/2, y: vigSize)
            )
        )
        // bottom edge
        ctx.fill(
            Path(CGRect(x: 0, y: H - vigSize, width: W, height: vigSize)),
            with: .linearGradient(
                Gradient(colors: [.clear, Color.red.opacity(0.45)]),
                startPoint: CGPoint(x: W/2, y: H - vigSize), endPoint: CGPoint(x: W/2, y: H)
            )
        )
        // #94 — left/right edges
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: vigSize, height: H)),
            with: .linearGradient(
                Gradient(colors: [Color.red.opacity(0.45), .clear]),
                startPoint: CGPoint(x: 0, y: H/2), endPoint: CGPoint(x: vigSize, y: H/2)
            )
        )
        ctx.fill(
            Path(CGRect(x: W - vigSize, y: 0, width: vigSize, height: H)),
            with: .linearGradient(
                Gradient(colors: [.clear, Color.red.opacity(0.45)]),
                startPoint: CGPoint(x: W - vigSize, y: H/2), endPoint: CGPoint(x: W, y: H/2)
            )
        )
    }

    // ── 17. STREAK TEXT BURST ───────────────────────────────────────────────────

    // Op #95-#96
    private func drawStreakText(ctx: inout GraphicsContext) {
        guard killStreak >= 5 else { return }
        let text = killStreak >= 10 ? "UNSTOPPABLE!" : "ON FIRE!"
        let textColor: Color = killStreak >= 10 ? .red : .orange
        let pulse = 0.85 + 0.15 * sin(t * 5.0)
        let textW: CGFloat = CGFloat(text.count) * 9
        let tx = W * 0.22 - textW / 2
        let ty = feetY - scale * 95

        // #95 — text glow background
        var textBg = Path()
        textBg.addRoundedRect(
            in: CGRect(x: tx - 4, y: ty - 4, width: textW + 8, height: 18),
            cornerSize: CGSize(width: 3, height: 3)
        )
        ctx.fill(textBg, with: .color(textColor.opacity(0.15 * pulse)))

        // #96 — text indicator bars (approximating text with colored blocks)
        for ci in 0..<min(text.count, 12) {
            let barX = tx + CGFloat(ci) * 9
            var charBar = Path()
            charBar.addRoundedRect(
                in: CGRect(x: barX, y: ty, width: 7, height: 10),
                cornerSize: CGSize(width: 1, height: 1)
            )
            ctx.fill(charBar, with: .color(textColor.opacity(0.6 * pulse)))
        }
    }

    // ── 18. BOSS RING ───────────────────────────────────────────────────────────

    // Op #97-#98
    private func drawBossRing(ctx: inout GraphicsContext) {
        guard waveNumber >= 5 && waveNumber % 5 == 0 else { return }
        let pulse = 0.4 + 0.6 * sin(t * 3.5)

        // #97 — boss arena border
        var bossRect = Path()
        let inset: CGFloat = 3
        bossRect.addRoundedRect(
            in: CGRect(x: inset, y: inset, width: W - inset*2, height: H - inset*2),
            cornerSize: CGSize(width: 8, height: 8)
        )
        ctx.stroke(bossRect, with: .color(Color.red.opacity(0.4 * pulse)), lineWidth: 2.5)

        // #98 — corner accent markers
        let cornerSize: CGFloat = 16
        let corners: [(CGFloat, CGFloat)] = [(0, 0), (W - cornerSize, 0), (0, H - cornerSize), (W - cornerSize, H - cornerSize)]
        for (cx, cy) in corners {
            var corner = Path()
            corner.addRect(CGRect(x: cx, y: cy, width: cornerSize, height: cornerSize))
            ctx.stroke(corner, with: .color(Color.red.opacity(0.6 * pulse)), lineWidth: 1.5)
        }
    }

    // ── 19. POWER-UP ICON ───────────────────────────────────────────────────────

    // Op #99-#101
    private func drawPowerUpIcon(ctx: inout GraphicsContext) {
        guard let powerUp = activePowerUp else { return }
        let ix: CGFloat = W - 32, iy: CGFloat = H * 0.35
        let pulse = 0.7 + 0.3 * sin(t * 4.0)

        let iconColor: Color
        switch powerUp {
        case .speedBoost:   iconColor = .yellow
        case .powerStrike:  iconColor = .orange
        case .shield:       iconColor = .cyan
        case .timeSlow:     iconColor = Color(red: 0.7, green: 0.0, blue: 1.0)
        }

        // #99 — power-up background glow
        let bgRect = CGRect(x: ix - 16, y: iy - 16, width: 32, height: 32)
        var bgGlowCtx = ctx
        bgGlowCtx.addFilter(.shadow(color: iconColor.opacity(0.9 * pulse), radius: 12))
        bgGlowCtx.fill(Path(ellipseIn: bgRect), with: .color(iconColor.opacity(0.15 * pulse)))

        // #100 — power-up icon shape
        var icon = Path()
        switch powerUp {
        case .speedBoost:
            // Lightning bolt shape
            icon.move(to: CGPoint(x: ix + 4, y: iy - 12))
            icon.addLine(to: CGPoint(x: ix - 2, y: iy - 2))
            icon.addLine(to: CGPoint(x: ix + 2, y: iy - 2))
            icon.addLine(to: CGPoint(x: ix - 4, y: iy + 12))
            icon.addLine(to: CGPoint(x: ix + 2, y: iy + 2))
            icon.addLine(to: CGPoint(x: ix - 2, y: iy + 2))
            icon.closeSubpath()
        case .powerStrike:
            // Fist shape
            icon.addRect(CGRect(x: ix - 6, y: iy - 6, width: 12, height: 10))
            icon.addRect(CGRect(x: ix - 3, y: iy + 4, width: 4, height: 6))
        case .shield:
            // Hexagon
            for j in 0..<6 {
                let a = Double(j) * .pi / 3.0
                let hx = ix + cos(a) * 10
                let hy = iy + sin(a) * 10
                if j == 0 { icon.move(to: CGPoint(x: hx, y: hy)) }
                else { icon.addLine(to: CGPoint(x: hx, y: hy)) }
            }
            icon.closeSubpath()
        case .timeSlow:
            // Clock circle
            icon.addEllipse(in: CGRect(x: ix - 10, y: iy - 10, width: 20, height: 20))
        }
        ctx.fill(icon, with: .color(iconColor.opacity(0.85 * pulse)))

        // #101 — outer ring indicator
        ctx.stroke(
            Path(ellipseIn: CGRect(x: ix - 14, y: iy - 14, width: 28, height: 28)),
            with: .color(iconColor.opacity(0.4 * pulse)),
            lineWidth: 1.2
        )
    }

    // ── HELPERS ─────────────────────────────────────────────────────────────────

    private func playerColor() -> Color {
        switch activePowerUp {
        case .speedBoost:   return .yellow
        case .powerStrike:  return .orange
        case .shield:       return .cyan
        case .timeSlow:     return Color(red: 0.7, green: 0.0, blue: 1.0)
        case nil:           return dragon ? .yellow : Color(red: 0.2, green: 0.8, blue: 1.0)
        }
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

    // Wave & opponents (legacy for HP UI)
    @State private var waveNumber: Int = 1
    @State private var opponents: [WaveOpponent] = []
    @State private var score: Int = 0
    @State private var highScore: Int = 0

    // Enemies (new full-featured)
    @State private var enemies: [EnemyState] = []
    @State private var killStreak: Int = 0
    @State private var activePowerUp: PowerUpType? = nil
    @State private var powerUpTimer: Double = 0
    @State private var killParticles: [KillParticle] = []

    // Combo & chakra
    @State private var combo: Int = 0
    @State private var maxCombo: Int = 0
    @State private var chakra: Double = 0
    @State private var showDragonStrikeButton: Bool = false

    // Poses
    @State private var playerPose: String = "idle"
    @State private var poseResetTasks: [Task<Void, Never>] = []

    // Flashes
    @State private var showCriticalFlash: Bool = false
    @State private var criticalFlashTask: Task<Void, Never>?
    @State private var hitFlash: Bool = false
    @State private var hitFlashTask: Task<Void, Never>?
    @State private var blockActive: Bool = false
    @State private var actionLabel: String = ""
    @State private var actionColor: Color = Theme.brandBlue
    @State private var showActionLabel: Bool = false
    @State private var actionLabelTask: Task<Void, Never>?
    @State private var screenShake: CGFloat = 0
    @State private var showWaveBanner: Bool = false
    @State private var waveBannerTask: Task<Void, Never>?
    @State private var particleTask: Task<Void, Never>?

    // AI
    @State private var aiAttackTask: Task<Void, Never>?
    @State private var lastPlayerActionTime: Date = Date()

    // Shard guard
    @State private var shardsAwarded: Bool = false

    // Haptics
    private let impactMed = UIImpactFeedbackGenerator(style: .medium)
    private let impactHvy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactLgt = UIImpactFeedbackGenerator(style: .light)
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

            actionButtons
                .padding(.horizontal, 16)
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
                if killStreak >= 5 {
                    Text(killStreak >= 10 ? "UNSTOPPABLE" : "ON FIRE!")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(killStreak >= 10 ? .red : .orange)
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
                        .contentTransition(.numericText())
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
                enemies: enemies,
                particles: killParticles,
                playerPose: playerPose,
                waveNumber: waveNumber,
                dragonActive: chakra >= 100,
                accentColor: accentColor,
                playerHP: playerHP,
                combo: combo,
                killStreak: killStreak,
                activePowerUp: activePowerUp,
                hitFlash: hitFlash,
                blockActive: blockActive
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

    // MARK: - Action Buttons (AAA controls)

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // BLOCK — left, large blue
            Button { handleBlock() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("BLOCK")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.brandBlue.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.brandBlue.opacity(0.5), lineWidth: 1)
                        )
                )
            }

            // DODGE — center
            Button { handleDodge() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("DODGE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.elitePurple.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.elitePurple.opacity(0.5), lineWidth: 1)
                        )
                )
            }

            // STRIKE — right, large orange
            Button { handlePunch() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("STRIKE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(colors: [accentColor, accentColor.opacity(0.8)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                )
                .shadow(color: accentColor.opacity(0.4), radius: 8)
            }
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

                // Next wave enemy preview
                let nextCount = min(3, waveNumber)
                HStack(spacing: 8) {
                    Text("NEXT:")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ForEach(0..<nextCount, id: \.self) { _ in
                        Image(systemName: "figure.martial.arts")
                            .font(.system(size: 14))
                            .foregroundStyle(nextIsBoss ? .red : accentColor)
                    }
                }

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

    // MARK: - Game Logic

    private func startGame() {
        spawnWave()
        phase = .fighting
        startGameTimer()
        scheduleAIAttacks()
        startParticleUpdater()
    }

    private func spawnWave() {
        let count = min(3, waveNumber)
        let hpScale = 1.0 + Double(waveNumber - 1) * 0.25
        let baseHP = 60.0 * hpScale * (waveNumber % 5 == 0 ? 1.8 : 1.0)
        var newOpponents: [WaveOpponent] = []
        var newEnemies: [EnemyState] = []

        let enemyTypes: [EnemyType] = [.striker, .grappler, .rusher]
        let enemySides: [EnemySide] = [.right, .right, .left]
        let enemyXs: [CGFloat] = [0.72, 0.58, 0.83]

        for i in 0..<count {
            let name = opponentNamePool[(waveNumber * 3 + i) % opponentNamePool.count]
            newOpponents.append(WaveOpponent(hp: baseHP, maxHP: baseHP, name: name, slideInProgress: 0.0))
            newEnemies.append(EnemyState(
                x: enemyXs[i],
                hp: 1.0,
                chargeProgress: 0.0,
                pose: "approach",
                side: enemySides[i],
                type: enemyTypes[i % enemyTypes.count],
                name: name,
                slideInProgress: 0.0
            ))
        }
        withAnimation { opponents = newOpponents }
        enemies = newEnemies

        // Slide-in animation
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
                        if i < enemies.count {
                            enemies[i].slideInProgress = progress
                        }
                    }
                }
            }
        }

        // Build enemy charge progress
        scheduleEnemyChargeBuildup()
    }

    private func scheduleEnemyChargeBuildup() {
        Task {
            while phase == .fighting || phase == .waveClear {
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    for i in enemies.indices {
                        guard enemies[i].isAlive else { continue }
                        let chargeRate = 0.012 + Double(waveNumber) * 0.003
                        enemies[i].chargeProgress = min(1.0, enemies[i].chargeProgress + chargeRate)
                        if enemies[i].chargeProgress >= 1.0 {
                            enemies[i].chargeProgress = 0.0
                            enemies[i].pose = "attack"
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

    private func startParticleUpdater() {
        particleTask?.cancel()
        particleTask = Task {
            while true {
                try? await Task.sleep(for: .milliseconds(32))
                guard !Task.isCancelled else { return }
                await MainActor.run { updateParticles() }
            }
        }
    }

    private func updateParticles() {
        killParticles = killParticles.compactMap { p in
            var np = p
            np.x += np.vx
            np.y += np.vy
            np.vy += 0.3  // gravity
            np.life -= 0.04
            return np.life > 0 ? np : nil
        }
    }

    private func spawnKillParticles(at x: CGFloat, y: CGFloat) {
        var newParticles: [KillParticle] = []
        for _ in 0..<12 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 2...6)
            let colors: [Color] = [.orange, .red, .yellow, .white]
            newParticles.append(KillParticle(
                x: x, y: y,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed - 3,
                life: 1.0,
                color: colors.randomElement() ?? .orange
            ))
        }
        killParticles.append(contentsOf: newParticles)
    }

    private func aiAttack() {
        guard phase == .fighting else { return }
        let baseDamage = 6.0 + Double(waveNumber - 1) * 1.5 * (waveNumber % 5 == 0 ? 1.5 : 1.0)
        let damage = Double.random(in: baseDamage...(baseDamage + 8))

        if blockActive {
            // Blocked — reduced damage
            playerHP = max(0, playerHP - damage * 0.2)
            showAction(text: "BLOCKED!", color: Theme.brandBlue)
            impactMed.impactOccurred()
        } else {
            playerHP = max(0, playerHP - damage)
            if !enemies.isEmpty {
                enemies[0].pose = "attack"
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    await MainActor.run {
                        if !enemies.isEmpty { enemies[0].pose = "approach" }
                    }
                }
            }
            setPlayerPose("hit", duration: 0.4)
            triggerHitFlash()
            flashScreenShake()
            notif.notificationOccurred(.error)
            combo = 0
        }
        if playerHP <= 0 { endGame() }
    }

    // MARK: - Player Actions

    private func handlePunch() {
        guard phase == .fighting, !enemies.isEmpty else { return }
        let now = Date()
        let isCritical = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now

        let damage: Double = (isCritical ? 10 : 7) + Double(combo) * 1.2
        applyDamageToEnemies(damage: damage / 100.0)

        score += isCritical ? 2 : 1
        combo += 1
        maxCombo = max(maxCombo, combo)
        chakra = min(100, chakra + (isCritical ? 14 : 8))

        setPlayerPose("punch", duration: 0.3)
        if !enemies.isEmpty { enemies[0].pose = "staggered" }
        showAction(text: isCritical ? "CRITICAL PUNCH!" : "PUNCH", color: Theme.brandBlue)
        if isCritical { triggerCriticalFlash() }
        flashScreenShake()
        impactHvy.impactOccurred()
    }

    private func handleKick() {
        guard phase == .fighting, !enemies.isEmpty else { return }
        let now = Date()
        let isCritical = now.timeIntervalSince(lastPlayerActionTime) < 0.3
        lastPlayerActionTime = now

        let damage: Double = (isCritical ? 16 : 11) + Double(combo) * 1.8
        applyDamageToEnemies(damage: damage / 100.0)

        score += isCritical ? 3 : 2
        combo += 1
        maxCombo = max(maxCombo, combo)
        chakra = min(100, chakra + (isCritical ? 18 : 11))

        setPlayerPose("kick", duration: 0.35)
        if !enemies.isEmpty { enemies[0].pose = "staggered" }
        showAction(text: isCritical ? "CRITICAL KICK!" : "KICK", color: accentColor)
        if isCritical { triggerCriticalFlash() }
        flashScreenShake()
        impactHvy.impactOccurred()
    }

    private func handleBlock() {
        guard phase == .fighting else { return }
        combo = 0
        blockActive = true
        playerHP = min(maxPlayerHP, playerHP + 4)
        setPlayerPose("block", duration: 0.5)
        showAction(text: "BLOCK", color: Theme.brandBlue)
        impactMed.impactOccurred()
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { blockActive = false }
        }
    }

    private func handleDodge() {
        guard phase == .fighting else { return }
        setPlayerPose("kick", duration: 0.4)
        showAction(text: "DODGE", color: Theme.elitePurple)
        impactLgt.impactOccurred()
        // Brief invincibility handled via blockActive
        blockActive = true
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run { blockActive = false }
        }
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

        // Apply heavy damage to all enemies
        for i in enemies.indices {
            enemies[i].hp = max(0.0, enemies[i].hp - 0.55)
            if enemies[i].hp <= 0 {
                spawnKillParticles(at: CGFloat(enemies[i].x) * 375, y: 250)
            }
        }

        // Update legacy opponents too
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
        killStreak += enemies.filter { !$0.isAlive }.count
        maxCombo = max(maxCombo, combo)

        setPlayerPose("dragon", duration: 0.8)
        for i in enemies.indices { enemies[i].pose = "staggered" }
        showAction(text: "DRAGON STRIKE!", color: .yellow)
        triggerCriticalFlash()
        flashScreenShake()
        notif.notificationOccurred(.success)

        enemies.removeAll { !$0.isAlive }
        withAnimation { opponents.removeAll { $0.hp <= 0 } }

        if enemies.isEmpty { advanceWave() }
    }

    private func applyDamageToEnemies(damage: Double) {
        guard !enemies.isEmpty else { return }

        // Damage normalized (0-1 scale for EnemyState.hp)
        let newHP = max(0.0, enemies[0].hp - damage)
        let died = newHP <= 0

        // Mirror to legacy opponents
        if !opponents.isEmpty {
            let legacyDamage = damage * opponents[0].maxHP
            let newLegacyHP = max(0, opponents[0].hp - legacyDamage)
            opponents[0] = WaveOpponent(hp: newLegacyHP, maxHP: opponents[0].maxHP,
                                        name: opponents[0].name,
                                        slideInProgress: opponents[0].slideInProgress)
        }

        if died {
            let deadX = CGFloat(enemies[0].x) * 375
            spawnKillParticles(at: deadX, y: 280)
            enemies.removeFirst()
            if !opponents.isEmpty { withAnimation { opponents.removeFirst() } }
            killStreak += 1
        } else {
            enemies[0].hp = newHP
        }

        if enemies.isEmpty { advanceWave() }
    }

    private func advanceWave() {
        guard phase == .fighting else { return }
        aiAttackTask?.cancel()
        phase = .waveClear
        waveNumber += 1
        killStreak = 0  // reset streak between waves

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

    private func triggerHitFlash() {
        withAnimation(.easeOut(duration: 0.05)) { hitFlash = true }
        hitFlashTask?.cancel()
        hitFlashTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(.easeIn(duration: 0.2)) { hitFlash = false } }
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
        GameResultService.saveResult(modeId: "karate_endless", userScore: score)
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
        hitFlashTask?.cancel()
        waveBannerTask?.cancel()
        particleTask?.cancel()
        poseResetTasks.forEach { $0.cancel() }
    }
}
