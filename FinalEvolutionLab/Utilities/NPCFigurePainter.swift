import SwiftUI

// MARK: - NPC Figure Painter
// Shared utility for drawing fully-animated NPC stick figures across all game-mode Canvases.
// All drawing is purely 2D (SwiftUI Canvas / GraphicsContext) – no SceneKit, no UIKit.
// Drop in any Canvas closure; pass a `t` from TimelineView for cyclic animation.

// MARK: - Config types

enum NPCArchetype {
    case forward, guard_, center, defender, goalkeeper, runningBack, wideReceiver
    case karateFighter, bossEnemy, referee, cheerleader, crowdSpectator
}

enum NPCAnimClip {
    case idle, breathe
    case walkSlow, walkNormal
    case run, sprint
    case jumpBall, jumpUp
    case shootRelease, passFling, dribbleBounce
    case defendStance, slidestep, blockArm
    case celebrateFistPump, celebrateJump, celebratePoint
    case stagger, fallDown, getUp
    case attackJab, attackKick, attackHaymaker, counterBlock
    case taunt, tiredness, clap
    case diveSlide, goalieSpread, goalieJump
    case routeRun, tackleForm, blitzCharge
}

struct NPCSkinTone {
    let face: Color
    let accent: Color    // slightly darker for shadows

    static let light   = NPCSkinTone(face: Color(red: 0.96, green: 0.82, blue: 0.70), accent: Color(red: 0.85, green: 0.70, blue: 0.58))
    static let medium  = NPCSkinTone(face: Color(red: 0.82, green: 0.62, blue: 0.44), accent: Color(red: 0.68, green: 0.50, blue: 0.34))
    static let tan     = NPCSkinTone(face: Color(red: 0.70, green: 0.48, blue: 0.32), accent: Color(red: 0.58, green: 0.38, blue: 0.24))
    static let brown   = NPCSkinTone(face: Color(red: 0.48, green: 0.32, blue: 0.20), accent: Color(red: 0.38, green: 0.24, blue: 0.14))
    static let dark    = NPCSkinTone(face: Color(red: 0.28, green: 0.18, blue: 0.12), accent: Color(red: 0.20, green: 0.12, blue: 0.08))

    static func forIndex(_ i: Int) -> NPCSkinTone {
        [light, medium, tan, brown, dark][i % 5]
    }
}

struct NPCConfig {
    var archetype: NPCArchetype = .forward
    var jerseyColor: Color = .blue
    var jerseyNumber: Int = 0
    var skinTone: NPCSkinTone = .medium
    var shoeColor: Color = Color(red: 0.12, green: 0.12, blue: 0.12)
    var hairColor: Color = Color(red: 0.10, green: 0.06, blue: 0.04)
    var scale: CGFloat = 1.0   // multiplied onto the base scale derived from canvas height
    var flipX: Bool = false    // mirror left/right for opposing team
    var shadowOpacity: Double = 0.30
}

// MARK: - The Painter

struct NPCFigurePainter {

    // ── Public entry point ────────────────────────────────────────────────────
    /// Draw one NPC figure.
    /// - Parameters:
    ///   - ctx: mutable GraphicsContext from a SwiftUI Canvas
    ///   - cx: center-X in canvas coordinates
    ///   - baseY: foot-level Y in canvas coordinates
    ///   - canvasH: canvas height (used to derive default scale)
    ///   - clip: animation state
    ///   - config: appearance & archetype
    ///   - t: time from TimelineView (seconds since reference date)
    ///   - phase: extra 0-1 progress override for one-shot clips (e.g. stagger)
    static func draw(
        ctx: inout GraphicsContext,
        cx: CGFloat,
        baseY: CGFloat,
        canvasH: CGFloat,
        clip: NPCAnimClip,
        config: NPCConfig,
        t: Double,
        phase: Double = 0
    ) {
        let sc = canvasH * 0.0026 * config.scale
        let m: CGFloat = config.flipX ? -1 : 1
        let c = config

        // Derived body measurements
        let headR    = sc * 9.5
        let torsoLen = sc * 28
        let upperArmLen = sc * 14
        let foreArmLen  = sc * 12
        let thighLen    = sc * 18
        let shinLen     = sc * 16

        // Key y-anchor points (all above baseY)
        let hipY      = baseY - sc * 4
        let waistY    = hipY - sc * 6
        let shoulderY = waistY - torsoLen
        let neckY     = shoulderY - sc * 4
        let headCY    = neckY - headR

        // ── Ground shadow ────────────────────────────────────────────────────
        drawShadow(ctx: &ctx, cx: cx, baseY: baseY, sc: sc,
                   clip: clip, config: c, t: t)

        // ── Compute joint positions for this clip & time ─────────────────────
        let joints = computeJoints(
            clip: clip, t: t, phase: phase, sc: sc,
            m: m, cx: cx, shoulderY: shoulderY, hipY: hipY,
            upperArmLen: upperArmLen, foreArmLen: foreArmLen,
            thighLen: thighLen, shinLen: shinLen, baseY: baseY
        )

        // ── Draw layers: back limbs → torso → front limbs → head ────────────
        let lw: CGFloat = max(2.8, sc * 1.8)

        // Back limbs (facing camera: right arm & left leg are "back")
        strokeLine(ctx: &ctx, a: joints.shoulderR, b: joints.elbowR, color: c.jerseyColor, lw: lw * 0.9)
        strokeLine(ctx: &ctx, a: joints.elbowR, b: joints.wristR, color: c.jerseyColor, lw: lw * 0.85)
        strokeLine(ctx: &ctx, a: joints.hipL, b: joints.kneeL, color: c.jerseyColor, lw: lw * 0.9)
        strokeLine(ctx: &ctx, a: joints.kneeL, b: joints.ankleL, color: c.jerseyColor, lw: lw * 0.85)
        // Shoe L
        drawShoe(ctx: &ctx, at: joints.ankleL, m: m, sc: sc, color: c.shoeColor, back: true)

        // Torso
        strokeLine(ctx: &ctx, a: joints.shoulderMid, b: joints.hipMid, color: c.jerseyColor, lw: lw * 1.15)

        // Jersey number
        if config.jerseyNumber > 0 {
            let jerseyY = shoulderY + sc * 8
            let numLabel = Text("\(config.jerseyNumber)")
                .font(.system(size: sc * 5.5, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.88))
            let resolved = ctx.resolve(numLabel)
            let sz = resolved.measure(in: CGSize(width: 40, height: 20))
            ctx.draw(resolved, at: CGPoint(x: cx - sz.width / 2, y: jerseyY - sz.height / 2), anchor: .topLeading)
        }

        // Front limbs
        strokeLine(ctx: &ctx, a: joints.shoulderL, b: joints.elbowL, color: c.jerseyColor, lw: lw)
        strokeLine(ctx: &ctx, a: joints.elbowL, b: joints.wristL, color: c.jerseyColor, lw: lw * 0.9)
        strokeLine(ctx: &ctx, a: joints.hipR, b: joints.kneeR, color: c.jerseyColor, lw: lw)
        strokeLine(ctx: &ctx, a: joints.kneeR, b: joints.ankleR, color: c.jerseyColor, lw: lw * 0.9)
        // Shoe R
        drawShoe(ctx: &ctx, at: joints.ankleR, m: m, sc: sc, color: c.shoeColor, back: false)

        // Head
        drawHead(ctx: &ctx, cx: cx + joints.headShift, cy: headCY + joints.headBob,
                 r: headR, sc: sc, config: c, clip: clip, t: t, m: m)

        // Archetype accents (boss glow, referee hat, etc.)
        drawArchetypeAccent(ctx: &ctx, cx: cx, headCY: headCY + joints.headBob,
                            shoulderY: shoulderY, sc: sc, config: c, clip: clip, t: t)
    }

    // MARK: - Joint positions

    private struct Joints {
        var shoulderMid: CGPoint
        var hipMid:      CGPoint
        var shoulderL:   CGPoint; var elbowL: CGPoint; var wristL: CGPoint
        var shoulderR:   CGPoint; var elbowR: CGPoint; var wristR: CGPoint
        var hipL:        CGPoint; var kneeL:  CGPoint; var ankleL: CGPoint
        var hipR:        CGPoint; var kneeR:  CGPoint; var ankleR: CGPoint
        var headBob:     CGFloat = 0
        var headShift:   CGFloat = 0
    }

    // swiftlint:disable function_parameter_count
    private static func computeJoints(
        clip: NPCAnimClip, t: Double, phase: Double, sc: CGFloat,
        m: CGFloat, cx: CGFloat, shoulderY: CGFloat, hipY: CGFloat,
        upperArmLen: CGFloat, foreArmLen: CGFloat,
        thighLen: CGFloat, shinLen: CGFloat, baseY: CGFloat
    ) -> Joints {

        let rawCycle = t.truncatingRemainder(dividingBy: 0.8) / 0.8
        let sinC = CGFloat(sin(rawCycle * .pi * 2))
        let cosC = CGFloat(cos(rawCycle * .pi * 2))

        // shoulder / hip mid-points (may be tilted per clip)
        let sMid = CGPoint(x: cx, y: shoulderY)
        let hMid = CGPoint(x: cx, y: hipY)

        // Helper: angle-based joint
        func arm(_ base: CGPoint, angle: CGFloat, len: CGFloat) -> CGPoint {
            CGPoint(x: base.x + len * CGFloat(cos(angle)), y: base.y + len * CGFloat(sin(angle)))
        }

        switch clip {

        // ── IDLE / BREATHE ──────────────────────────────────────────────────
        case .idle, .breathe:
            let bob = CGFloat(sin(t * 1.8)) * sc * 0.4
            let rSh = CGPoint(x: cx + m * sc * 8, y: shoulderY + bob)
            let lSh = CGPoint(x: cx - m * sc * 8, y: shoulderY + bob)
            let rElb = CGPoint(x: cx + m * sc * 16, y: shoulderY + sc * 8 + bob)
            let lElb = CGPoint(x: cx - m * sc * 16, y: shoulderY + sc * 10 + bob)
            let rWrist = CGPoint(x: cx + m * sc * 14, y: shoulderY + sc * 16 + bob)
            let lWrist = CGPoint(x: cx - m * sc * 14, y: shoulderY + sc * 18 + bob)
            let rHip = CGPoint(x: cx + m * sc * 6, y: hipY)
            let lHip = CGPoint(x: cx - m * sc * 6, y: hipY)
            let rKnee = CGPoint(x: cx + m * sc * 7, y: hipY + thighLen)
            let lKnee = CGPoint(x: cx - m * sc * 7, y: hipY + thighLen)
            let rAnk  = CGPoint(x: cx + m * sc * 6, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 6, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: lHip, kneeL: lKnee, ankleL: lAnk,
                          hipR: rHip, kneeR: rKnee, ankleR: rAnk,
                          headBob: bob)

        // ── WALK ────────────────────────────────────────────────────────────
        case .walkSlow, .walkNormal:
            let speed = clip == .walkSlow ? 1.0 : 1.8
            let legSwing = CGFloat(sin(t * speed * .pi * 2)) * sc * 9
            let armSwing = -legSwing * 0.6
            let bob = CGFloat(abs(sin(t * speed * .pi * 2))) * sc * 0.6
            let rSh = CGPoint(x: cx + m * sc * 7, y: shoulderY - bob)
            let lSh = CGPoint(x: cx - m * sc * 7, y: shoulderY - bob)
            let rElb = CGPoint(x: cx + m * sc * 14 + armSwing, y: shoulderY + sc * 10 - bob)
            let lElb = CGPoint(x: cx - m * sc * 14 - armSwing, y: shoulderY + sc * 10 - bob)
            let rWrist = CGPoint(x: cx + m * sc * 10 + armSwing * 1.2, y: shoulderY + sc * 20 - bob)
            let lWrist = CGPoint(x: cx - m * sc * 10 - armSwing * 1.2, y: shoulderY + sc * 20 - bob)
            let rKnee = CGPoint(x: cx + m * sc * 6, y: hipY + thighLen - sc * 2 - legSwing * 0.3)
            let lKnee = CGPoint(x: cx - m * sc * 6, y: hipY + thighLen - sc * 2 + legSwing * 0.3)
            let rAnk  = CGPoint(x: cx + m * sc * 5 + legSwing, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 5 - legSwing, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: rWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: lWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY),
                          kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY),
                          kneeR: rKnee, ankleR: rAnk,
                          headBob: -bob)

        // ── RUN ─────────────────────────────────────────────────────────────
        case .run, .sprint, .routeRun, .blitzCharge:
            let speed = (clip == .sprint || clip == .blitzCharge) ? 3.2 : 2.4
            let ls = CGFloat(sin(t * speed)) * sc * 14
            let as_ = -ls * 0.7
            let lean: CGFloat = m * sc * 3
            let bob = CGFloat(abs(sin(t * speed))) * sc * 1.0
            let rSh = CGPoint(x: cx + m * sc * 6 + lean, y: shoulderY - bob)
            let lSh = CGPoint(x: cx - m * sc * 6 + lean, y: shoulderY - bob)
            let rElb = CGPoint(x: cx + m * sc * 16 + as_, y: shoulderY + sc * 6 - bob)
            let lElb = CGPoint(x: cx - m * sc * 16 - as_, y: shoulderY + sc * 6 - bob)
            let rWrist = CGPoint(x: cx + m * sc * 12 + as_ * 1.4, y: shoulderY + sc * 14 - bob)
            let lWrist = CGPoint(x: cx - m * sc * 12 - as_ * 1.4, y: shoulderY + sc * 14 - bob)
            let rKneeX  = cx + m * sc * 8 + ls * 0.5
            let lKneeX  = cx - m * sc * 8 - ls * 0.5
            let rKneeY  = hipY + thighLen * 0.75 - abs(ls) * 0.4
            let lKneeY  = hipY + thighLen * 0.75 - abs(ls) * 0.4
            let rAnk  = CGPoint(x: cx + m * sc * 6 + ls, y: baseY - max(0, ls * 0.3))
            let lAnk  = CGPoint(x: cx - m * sc * 6 - ls, y: baseY - max(0, -ls * 0.3))
            return Joints(shoulderMid: CGPoint(x: cx + lean, y: shoulderY),
                          hipMid: CGPoint(x: cx + lean, y: hipY),
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY),
                          kneeL: CGPoint(x: lKneeX, y: lKneeY), ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY),
                          kneeR: CGPoint(x: rKneeX, y: rKneeY), ankleR: rAnk,
                          headBob: -bob, headShift: lean)

        // ── SHOOT RELEASE ────────────────────────────────────────────────────
        case .shootRelease, .jumpBall, .jumpUp:
            let liftFrac = CGFloat(clip == .jumpBall ? (sin(t * 2.0) * 0.5 + 0.5) : phase)
            let liftY = liftFrac * sc * 24
            let rSh = CGPoint(x: cx + m * sc * 7, y: shoulderY - liftY)
            let lSh = CGPoint(x: cx - m * sc * 7, y: shoulderY - liftY)
            let rElb = CGPoint(x: cx + m * sc * 18, y: shoulderY - sc * 18 - liftY)
            let lElb = CGPoint(x: cx - m * sc * 8, y: shoulderY + sc * 6 - liftY)
            let rWrist = CGPoint(x: cx + m * sc * 24, y: shoulderY - sc * 32 - liftY)
            let lWrist = CGPoint(x: cx - m * sc * 10, y: shoulderY + sc * 14 - liftY)
            let rKnee = CGPoint(x: cx + m * sc * 10, y: hipY + thighLen * 0.6)
            let lKnee = CGPoint(x: cx - m * sc * 10, y: hipY + thighLen * 0.6)
            let rAnk  = CGPoint(x: cx + m * sc * 8, y: baseY - liftY * 0.8)
            let lAnk  = CGPoint(x: cx - m * sc * 8, y: baseY - liftY * 0.8)
            return Joints(shoulderMid: CGPoint(x: cx, y: shoulderY - liftY * 0.5),
                          hipMid: CGPoint(x: cx, y: hipY - liftY * 0.3),
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY), kneeR: rKnee, ankleR: rAnk,
                          headBob: -liftY * 0.3)

        // ── PASS ─────────────────────────────────────────────────────────────
        case .passFling:
            let wind = CGFloat(phase) // 0 = windup, 1 = full release
            let rSh = CGPoint(x: cx + m * sc * 8, y: shoulderY)
            let lSh = CGPoint(x: cx - m * sc * 8, y: shoulderY)
            let rElb = CGPoint(x: cx + m * sc * 20, y: shoulderY - sc * 10 * wind)
            let rWrist = CGPoint(x: cx + m * sc * 34 * wind, y: shoulderY + sc * 4)
            let lElb = CGPoint(x: cx - m * sc * 12, y: shoulderY + sc * 16)
            let lWrist = CGPoint(x: cx - m * sc * 14, y: shoulderY + sc * 26)
            let rKnee = CGPoint(x: cx + m * sc * 14, y: hipY + thighLen * 0.7)
            let lKnee = CGPoint(x: cx - m * sc * 8, y: hipY + thighLen * 0.9)
            let rAnk  = CGPoint(x: cx + m * sc * 14, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 6, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY), kneeR: rKnee, ankleR: rAnk)

        // ── DEFEND STANCE ────────────────────────────────────────────────────
        case .defendStance, .blockArm:
            let sway = CGFloat(sin(t * 2.2)) * sc * 2
            let rSh = CGPoint(x: cx + m * sc * 14 + sway, y: shoulderY + sc * 2)
            let lSh = CGPoint(x: cx - m * sc * 14 + sway, y: shoulderY + sc * 2)
            let rElb = CGPoint(x: cx + m * sc * 24 + sway, y: shoulderY + sc * 12)
            let lElb = CGPoint(x: cx - m * sc * 24 + sway, y: shoulderY + sc * 12)
            let rWrist = CGPoint(x: cx + m * sc * 28 + sway, y: shoulderY + sc * 8)
            let lWrist = CGPoint(x: cx - m * sc * 28 + sway, y: shoulderY + sc * 8)
            let rKnee = CGPoint(x: cx + m * sc * 16, y: hipY + thighLen * 0.75)
            let lKnee = CGPoint(x: cx - m * sc * 16, y: hipY + thighLen * 0.75)
            let rAnk  = CGPoint(x: cx + m * sc * 14, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 14, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 10, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 10, y: hipY), kneeR: rKnee, ankleR: rAnk)

        // ── SLIDESTEP ────────────────────────────────────────────────────────
        case .slidestep:
            let slidePhase = CGFloat(sin(t * 3.0))
            let rSh = CGPoint(x: cx + m * sc * 16, y: shoulderY + sc * 4)
            let lSh = CGPoint(x: cx - m * sc * 16, y: shoulderY + sc * 4)
            let rElb = CGPoint(x: cx + m * sc * 26, y: shoulderY + sc * 12 + slidePhase * sc * 2)
            let lElb = CGPoint(x: cx - m * sc * 26, y: shoulderY + sc * 12 - slidePhase * sc * 2)
            let rWrist = rElb; let lWrist = lElb
            let rKnee = CGPoint(x: cx + m * sc * 18, y: hipY + thighLen * 0.7 + slidePhase * sc * 2)
            let lKnee = CGPoint(x: cx - m * sc * 18, y: hipY + thighLen * 0.7 - slidePhase * sc * 2)
            let rAnk  = CGPoint(x: cx + m * sc * 16, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 16, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 12, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 12, y: hipY), kneeR: rKnee, ankleR: rAnk)

        // ── CELEBRATE ────────────────────────────────────────────────────────
        case .celebrateFistPump, .celebrateJump, .celebratePoint:
            let bounce = CGFloat(abs(sin(t * 4.0))) * sc * 3
            let rSh = CGPoint(x: cx + m * sc * 8, y: shoulderY - bounce)
            let lSh = CGPoint(x: cx - m * sc * 8, y: shoulderY - bounce)
            let rElb = CGPoint(x: cx + m * sc * 14, y: shoulderY - sc * 18 - bounce)
            let lElb: CGPoint
            let rWrist = CGPoint(x: cx + m * sc * 12, y: shoulderY - sc * 32 - bounce)
            let lWrist: CGPoint
            if clip == .celebratePoint {
                lElb   = CGPoint(x: cx - m * sc * 6, y: shoulderY - sc * 14 - bounce)
                lWrist = CGPoint(x: cx - m * sc * 4 + m * sc * 20, y: shoulderY - sc * 22 - bounce)
            } else {
                lElb   = CGPoint(x: cx - m * sc * 14, y: shoulderY - sc * 18 - bounce)
                lWrist = CGPoint(x: cx - m * sc * 12, y: shoulderY - sc * 32 - bounce)
            }
            let rKnee = CGPoint(x: cx + m * sc * 8, y: hipY + thighLen * 0.65)
            let lKnee = CGPoint(x: cx - m * sc * 8, y: hipY + thighLen * 0.65)
            let rAnk  = CGPoint(x: cx + m * sc * 6, y: baseY - bounce * 1.2)
            let lAnk  = CGPoint(x: cx - m * sc * 6, y: baseY - bounce * 1.2)
            return Joints(shoulderMid: CGPoint(x: cx, y: shoulderY - bounce * 0.4),
                          hipMid: CGPoint(x: cx, y: hipY - bounce * 0.3),
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY), kneeR: rKnee, ankleR: rAnk,
                          headBob: -bounce * 0.5)

        // ── STAGGER / FALL ───────────────────────────────────────────────────
        case .stagger, .fallDown, .getUp:
            let tilt: CGFloat = clip == .fallDown ? m * sc * 12 : m * sc * 6
            let rSh = CGPoint(x: cx + m * sc * 4 + tilt * 0.3, y: shoulderY + sc * 6)
            let lSh = CGPoint(x: cx - m * sc * 4 + tilt * 0.3, y: shoulderY + sc * 6)
            let rElb = CGPoint(x: cx + m * sc * 8 + tilt, y: shoulderY + sc * 16)
            let lElb = CGPoint(x: cx - m * sc * 8 + tilt, y: shoulderY + sc * 16)
            let rWrist = CGPoint(x: cx + m * sc * 6 + tilt * 1.2, y: shoulderY + sc * 24)
            let lWrist = CGPoint(x: cx - m * sc * 6 + tilt * 1.2, y: shoulderY + sc * 24)
            let rKnee = CGPoint(x: cx + m * sc * 4, y: hipY + thighLen)
            let lKnee = CGPoint(x: cx - m * sc * 4, y: hipY + thighLen)
            let rAnk  = CGPoint(x: cx + m * sc * 3, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 3, y: baseY)
            return Joints(shoulderMid: CGPoint(x: cx + tilt * 0.2, y: shoulderY + sc * 4),
                          hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 5, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 5, y: hipY), kneeR: rKnee, ankleR: rAnk,
                          headShift: tilt * 0.35)

        // ── ATTACK (Karate) ──────────────────────────────────────────────────
        case .attackJab:
            let ext = CGFloat(phase) // 0 = ready, 1 = full extension
            let rSh = CGPoint(x: cx + m * sc * 6, y: shoulderY)
            let lSh = CGPoint(x: cx - m * sc * 6, y: shoulderY)
            let rElb = CGPoint(x: cx + m * sc * (10 + 14 * ext), y: shoulderY - sc * 2)
            let rWrist = CGPoint(x: cx + m * sc * (14 + 26 * ext), y: shoulderY - sc * 4)
            let lElb = CGPoint(x: cx - m * sc * 12, y: shoulderY + sc * 8)
            let lWrist = CGPoint(x: cx - m * sc * 10, y: shoulderY + sc * 16)
            let rKnee = CGPoint(x: cx + m * sc * 12, y: hipY + thighLen * 0.7)
            let lKnee = CGPoint(x: cx - m * sc * 8, y: hipY + thighLen)
            let rAnk  = CGPoint(x: cx + m * sc * 14, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 6, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY), kneeR: rKnee, ankleR: rAnk)

        case .attackKick:
            let kickPhase = CGFloat(phase)
            let rSh = CGPoint(x: cx + m * sc * 8, y: shoulderY)
            let lSh = CGPoint(x: cx - m * sc * 8, y: shoulderY)
            let rElb = CGPoint(x: cx + m * sc * 16, y: shoulderY + sc * 12)
            let lElb = CGPoint(x: cx - m * sc * 16, y: shoulderY + sc * 12)
            let rWrist = CGPoint(x: cx + m * sc * 14, y: shoulderY + sc * 24)
            let lWrist = CGPoint(x: cx - m * sc * 14, y: shoulderY + sc * 24)
            let kickHeight = kickPhase * sc * 28
            let rKnee = CGPoint(x: cx + m * sc * (8 + 12 * kickPhase), y: hipY + thighLen * 0.5 - kickHeight * 0.4)
            let rAnk  = CGPoint(x: cx + m * sc * (12 + 20 * kickPhase), y: hipY + thighLen - kickHeight)
            let lKnee = CGPoint(x: cx - m * sc * 6, y: hipY + thighLen * 0.9)
            let lAnk  = CGPoint(x: cx - m * sc * 5, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 5, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 5, y: hipY), kneeR: rKnee, ankleR: rAnk)

        case .attackHaymaker:
            let ws = CGFloat(sin(t * 4.0)) * 0.5 + 0.5
            let rSh = CGPoint(x: cx + m * sc * 10, y: shoulderY - sc * 4)
            let lSh = CGPoint(x: cx - m * sc * 10, y: shoulderY - sc * 4)
            let rElb = CGPoint(x: cx + m * sc * 22, y: shoulderY - sc * 16)
            let rWrist = CGPoint(x: cx + m * sc * 28 * ws, y: shoulderY - sc * 28 * ws)
            let lElb = CGPoint(x: cx - m * sc * 12, y: shoulderY + sc * 8)
            let lWrist = CGPoint(x: cx - m * sc * 8, y: shoulderY + sc * 18)
            let rKnee = CGPoint(x: cx + m * sc * 14, y: hipY + thighLen * 0.7)
            let lKnee = CGPoint(x: cx - m * sc * 10, y: hipY + thighLen * 0.85)
            let rAnk  = CGPoint(x: cx + m * sc * 12, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 8, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 7, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 7, y: hipY), kneeR: rKnee, ankleR: rAnk)

        case .counterBlock:
            let rSh = CGPoint(x: cx + m * sc * 6, y: shoulderY)
            let lSh = CGPoint(x: cx - m * sc * 6, y: shoulderY)
            let rElb = CGPoint(x: cx + m * sc * 10, y: shoulderY - sc * 18)
            let rWrist = CGPoint(x: cx + m * sc * 8, y: shoulderY - sc * 32)
            let lElb = CGPoint(x: cx - m * sc * 10, y: shoulderY - sc * 18)
            let lWrist = CGPoint(x: cx - m * sc * 8, y: shoulderY - sc * 32)
            let rKnee = CGPoint(x: cx + m * sc * 8, y: hipY + thighLen * 0.75)
            let lKnee = CGPoint(x: cx - m * sc * 8, y: hipY + thighLen * 0.75)
            let rAnk  = CGPoint(x: cx + m * sc * 6, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 6, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY), kneeR: rKnee, ankleR: rAnk)

        // ── TAUNT / TIRED / CLAP ─────────────────────────────────────────────
        case .taunt:
            let wave = CGFloat(sin(t * 5.0)) * sc * 4
            let rSh = CGPoint(x: cx + m * sc * 8, y: shoulderY)
            let lSh = CGPoint(x: cx - m * sc * 8, y: shoulderY)
            let rElb = CGPoint(x: cx + m * sc * 16, y: shoulderY - sc * 10)
            let rWrist = CGPoint(x: cx + m * sc * 12, y: shoulderY - sc * 24 + wave)
            let lElb = CGPoint(x: cx - m * sc * 14, y: shoulderY + sc * 6)
            let lWrist = CGPoint(x: cx - m * sc * 12, y: shoulderY + sc * 18)
            let rKnee = CGPoint(x: cx + m * sc * 7, y: hipY + thighLen)
            let lKnee = CGPoint(x: cx - m * sc * 7, y: hipY + thighLen)
            let rAnk  = CGPoint(x: cx + m * sc * 6, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 6, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY), kneeR: rKnee, ankleR: rAnk)

        case .tiredness:
            let hunch = sc * 5
            let rSh = CGPoint(x: cx + m * sc * 6, y: shoulderY + hunch)
            let lSh = CGPoint(x: cx - m * sc * 6, y: shoulderY + hunch)
            let rElb = CGPoint(x: cx + m * sc * 14, y: shoulderY + sc * 14 + hunch)
            let lElb = CGPoint(x: cx - m * sc * 14, y: shoulderY + sc * 14 + hunch)
            let rWrist = CGPoint(x: cx + m * sc * 10, y: shoulderY + sc * 24 + hunch)
            let lWrist = CGPoint(x: cx - m * sc * 10, y: shoulderY + sc * 24 + hunch)
            let rKnee = CGPoint(x: cx + m * sc * 10, y: hipY + thighLen * 0.8)
            let lKnee = CGPoint(x: cx - m * sc * 10, y: hipY + thighLen * 0.8)
            let rAnk  = CGPoint(x: cx + m * sc * 8, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 8, y: baseY)
            return Joints(shoulderMid: CGPoint(x: cx, y: shoulderY + hunch * 0.5),
                          hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 8, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 8, y: hipY), kneeR: rKnee, ankleR: rAnk,
                          headBob: hunch * 0.4)

        case .clap:
            let clapPhase = CGFloat(abs(sin(t * 5.0)))
            let clapX = cx + CGFloat(sin(t * 5.0)) * sc * 4
            let rSh = CGPoint(x: cx + m * sc * 7, y: shoulderY)
            let lSh = CGPoint(x: cx - m * sc * 7, y: shoulderY)
            let rElb = CGPoint(x: clapX + m * sc * 6, y: shoulderY + sc * 10)
            let lElb = CGPoint(x: clapX - m * sc * 6, y: shoulderY + sc * 10)
            let rWrist = CGPoint(x: clapX + sc * 2 * clapPhase, y: shoulderY + sc * 20)
            let lWrist = CGPoint(x: clapX - sc * 2 * clapPhase, y: shoulderY + sc * 20)
            let rKnee = CGPoint(x: cx + m * sc * 7, y: hipY + thighLen)
            let lKnee = CGPoint(x: cx - m * sc * 7, y: hipY + thighLen)
            let rAnk  = CGPoint(x: cx + m * sc * 6, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 6, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY), kneeR: rKnee, ankleR: rAnk)

        // ── GOALKEEPER ───────────────────────────────────────────────────────
        case .goalieSpread:
            let sway = CGFloat(sin(t * 1.4)) * sc * 4
            let rSh = CGPoint(x: cx + m * sc * 18 + sway, y: shoulderY + sc * 2)
            let lSh = CGPoint(x: cx - m * sc * 18 + sway, y: shoulderY + sc * 2)
            let rElb = CGPoint(x: cx + m * sc * 28 + sway, y: shoulderY + sc * 10)
            let lElb = CGPoint(x: cx - m * sc * 28 + sway, y: shoulderY + sc * 10)
            let rWrist = CGPoint(x: cx + m * sc * 32 + sway, y: shoulderY + sc * 6)
            let lWrist = CGPoint(x: cx - m * sc * 32 + sway, y: shoulderY + sc * 6)
            let rKnee = CGPoint(x: cx + m * sc * 18, y: hipY + thighLen * 0.7)
            let lKnee = CGPoint(x: cx - m * sc * 18, y: hipY + thighLen * 0.7)
            let rAnk  = CGPoint(x: cx + m * sc * 16, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 16, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 12, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 12, y: hipY), kneeR: rKnee, ankleR: rAnk)

        case .goalieJump:
            let leap = CGFloat(phase) * sc * 28
            let rSh = CGPoint(x: cx + m * sc * 18, y: shoulderY - leap)
            let lSh = CGPoint(x: cx - m * sc * 18, y: shoulderY - leap)
            let rElb = CGPoint(x: cx + m * sc * 28, y: shoulderY - leap - sc * 8)
            let lElb = CGPoint(x: cx - m * sc * 28, y: shoulderY - leap - sc * 8)
            let rWrist = CGPoint(x: cx + m * sc * 34, y: shoulderY - leap - sc * 18)
            let lWrist = CGPoint(x: cx - m * sc * 34, y: shoulderY - leap - sc * 18)
            let rKnee = CGPoint(x: cx + m * sc * 10, y: hipY + thighLen * 0.6 - leap * 0.7)
            let lKnee = CGPoint(x: cx - m * sc * 10, y: hipY + thighLen * 0.6 - leap * 0.7)
            let rAnk  = CGPoint(x: cx + m * sc * 8, y: baseY - leap * 0.9)
            let lAnk  = CGPoint(x: cx - m * sc * 8, y: baseY - leap * 0.9)
            return Joints(shoulderMid: CGPoint(x: cx, y: shoulderY - leap * 0.5),
                          hipMid: CGPoint(x: cx, y: hipY - leap * 0.4),
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 8, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 8, y: hipY), kneeR: rKnee, ankleR: rAnk,
                          headBob: -leap * 0.4)

        // ── DIVE SLIDE ───────────────────────────────────────────────────────
        case .diveSlide, .tackleForm:
            let rSh = CGPoint(x: cx + m * sc * 22, y: shoulderY + sc * 4)
            let lSh = CGPoint(x: cx - m * sc * 4, y: shoulderY + sc * 4)
            let rElb = CGPoint(x: cx + m * sc * 32, y: shoulderY + sc * 2)
            let rWrist = CGPoint(x: cx + m * sc * 40, y: shoulderY - sc * 4)
            let lElb = CGPoint(x: cx - m * sc * 6, y: shoulderY + sc * 18)
            let lWrist = CGPoint(x: cx - m * sc * 4, y: shoulderY + sc * 30)
            // Sliding legs nearly horizontal
            let rKnee = CGPoint(x: cx + m * sc * 14, y: hipY + thighLen * 0.5)
            let lKnee = CGPoint(x: cx - m * sc * 8, y: hipY + thighLen * 0.6)
            let rAnk  = CGPoint(x: cx + m * sc * 22, y: hipY + thighLen)
            let lAnk  = CGPoint(x: cx - m * sc * 4, y: hipY + thighLen)
            return Joints(shoulderMid: CGPoint(x: cx + m * sc * 8, y: shoulderY + sc * 4),
                          hipMid: CGPoint(x: cx, y: hipY + sc * 8),
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 5, y: hipY + sc * 8),
                          kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 5, y: hipY + sc * 8),
                          kneeR: rKnee, ankleR: rAnk,
                          headShift: m * sc * 14)

        // ── DRIBBLE ──────────────────────────────────────────────────────────
        case .dribbleBounce:
            let dribPhase = CGFloat(sin(t * 5.0))
            let bob = CGFloat(abs(sin(t * 5.0))) * sc * 0.8
            let rSh = CGPoint(x: cx + m * sc * 7, y: shoulderY - bob)
            let lSh = CGPoint(x: cx - m * sc * 7, y: shoulderY - bob)
            let rElb = CGPoint(x: cx + m * sc * 16, y: shoulderY + sc * 10 - bob + dribPhase * sc * 4)
            let rWrist = CGPoint(x: cx + m * sc * 14, y: shoulderY + sc * 24 - bob + dribPhase * sc * 8)
            let lElb = CGPoint(x: cx - m * sc * 16, y: shoulderY + sc * 8 - bob)
            let lWrist = CGPoint(x: cx - m * sc * 12, y: shoulderY + sc * 18 - bob)
            let rKnee = CGPoint(x: cx + m * sc * 9, y: hipY + thighLen * 0.8)
            let lKnee = CGPoint(x: cx - m * sc * 9, y: hipY + thighLen * 0.8)
            let rAnk  = CGPoint(x: cx + m * sc * 7, y: baseY)
            let lAnk  = CGPoint(x: cx - m * sc * 7, y: baseY)
            return Joints(shoulderMid: sMid, hipMid: hMid,
                          shoulderL: lSh, elbowL: lElb, wristL: lWrist,
                          shoulderR: rSh, elbowR: rElb, wristR: rWrist,
                          hipL: CGPoint(x: cx - m * sc * 6, y: hipY), kneeL: lKnee, ankleL: lAnk,
                          hipR: CGPoint(x: cx + m * sc * 6, y: hipY), kneeR: rKnee, ankleR: rAnk,
                          headBob: -bob * 0.3)
        }
    }
    // swiftlint:enable function_parameter_count

    // MARK: - Sub-renderers

    private static func drawShadow(
        ctx: inout GraphicsContext,
        cx: CGFloat, baseY: CGFloat, sc: CGFloat,
        clip: NPCAnimClip, config: NPCConfig, t: Double
    ) {
        guard config.shadowOpacity > 0 else { return }
        let isMidAir = (clip == .jumpUp || clip == .jumpBall || clip == .goalieJump || clip == .diveSlide)
        let shadowScale: CGFloat = isMidAir ? 0.5 : 1.0
        var gc = ctx
        gc.addFilter(.blur(radius: sc * 1.5))
        gc.fill(
            Path(ellipseIn: CGRect(
                x: cx - sc * 14 * shadowScale,
                y: baseY - sc * 2,
                width: sc * 28 * shadowScale,
                height: sc * 4)),
            with: .color(Color.black.opacity(config.shadowOpacity * Double(shadowScale)))
        )
    }

    private static func drawHead(
        ctx: inout GraphicsContext,
        cx: CGFloat, cy: CGFloat, r: CGFloat, sc: CGFloat,
        config: NPCConfig, clip: NPCAnimClip, t: Double, m: CGFloat
    ) {
        // Head fill
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - r, y: cy, width: r * 2, height: r * 2)),
            with: .color(config.skinTone.face)
        )
        // Hair / helmet overlay
        let headTop = Path(CGRect(x: cx - r * 0.88, y: cy, width: r * 1.76, height: r * 0.7))
        ctx.fill(headTop, with: .color(config.hairColor.opacity(0.85)))

        // Eyes (tiny dots)
        let eyeY = cy + r * 0.55
        let eyeOff = r * 0.32
        ctx.fill(Path(ellipseIn: CGRect(x: cx + m * eyeOff - 1, y: eyeY - 1, width: 2.2, height: 2.2)),
                 with: .color(.white.opacity(0.9)))
        ctx.fill(Path(ellipseIn: CGRect(x: cx - m * eyeOff - 1, y: eyeY - 1, width: 2.2, height: 2.2)),
                 with: .color(.white.opacity(0.9)))
        ctx.fill(Path(ellipseIn: CGRect(x: cx + m * eyeOff - 0.7, y: eyeY - 0.7, width: 1.4, height: 1.4)),
                 with: .color(Color(red: 0.08, green: 0.04, blue: 0.04)))
        ctx.fill(Path(ellipseIn: CGRect(x: cx - m * eyeOff - 0.7, y: eyeY - 0.7, width: 1.4, height: 1.4)),
                 with: .color(Color(red: 0.08, green: 0.04, blue: 0.04)))

        // Expression mouth
        let mouthY = cy + r * 1.1
        var mouth = Path()
        if clip == .celebrateFistPump || clip == .celebrateJump || clip == .celebratePoint {
            // Happy open
            mouth.move(to: CGPoint(x: cx - r * 0.22, y: mouthY - 0.5))
            mouth.addQuadCurve(to: CGPoint(x: cx + r * 0.22, y: mouthY - 0.5),
                                control: CGPoint(x: cx, y: mouthY + r * 0.2))
        } else if clip == .stagger || clip == .fallDown {
            // Pain squiggle
            mouth.move(to: CGPoint(x: cx - r * 0.18, y: mouthY))
            mouth.addLine(to: CGPoint(x: cx, y: mouthY - 2))
            mouth.addLine(to: CGPoint(x: cx + r * 0.18, y: mouthY))
        } else {
            // Neutral
            mouth.move(to: CGPoint(x: cx - r * 0.2, y: mouthY))
            mouth.addLine(to: CGPoint(x: cx + r * 0.2, y: mouthY))
        }
        ctx.stroke(mouth, with: .color(config.skinTone.accent.opacity(0.8)), lineWidth: 1)
    }

    private static func drawShoe(
        ctx: inout GraphicsContext,
        at ankle: CGPoint, m: CGFloat, sc: CGFloat,
        color: Color, back: Bool
    ) {
        let shoeW = sc * 9
        let shoeH = sc * 3.5
        let ox = ankle.x + m * sc * 2
        ctx.fill(
            Path(roundedRect: CGRect(x: ox - shoeW / 2, y: ankle.y - shoeH, width: shoeW, height: shoeH),
                 cornerRadius: shoeH * 0.4),
            with: .color(color.opacity(back ? 0.75 : 1.0))
        )
    }

    private static func drawArchetypeAccent(
        ctx: inout GraphicsContext,
        cx: CGFloat, headCY: CGFloat, shoulderY: CGFloat,
        sc: CGFloat, config: NPCConfig, clip: NPCAnimClip, t: Double
    ) {
        switch config.archetype {
        case .bossEnemy:
            // Pulsing red aura
            var gc = ctx
            gc.addFilter(.blur(radius: sc * 6))
            gc.fill(
                Path(ellipseIn: CGRect(x: cx - sc * 22, y: headCY - sc * 4,
                                       width: sc * 44, height: sc * 80)),
                with: .color(Color.red.opacity(0.18 + 0.06 * sin(t * 2.5)))
            )
        case .referee:
            // Whistle on chest
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx + sc * 2, y: shoulderY + sc * 8, width: sc * 4, height: sc * 3)),
                with: .color(Color(red: 0.9, green: 0.7, blue: 0.1))
            )
        case .cheerleader:
            // Pom-pom dots
            for side: CGFloat in [-1, 1] {
                for i in 0..<5 {
                    let angle = Double(i) / 5 * .pi * 2 + t * 3
                    let pr = sc * 8
                    let px = cx + side * sc * 24 + CGFloat(cos(angle)) * pr * 0.4
                    let py = shoulderY + sc * 16 + CGFloat(sin(angle)) * pr * 0.4
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - sc * 1.5, y: py - sc * 1.5, width: sc * 3, height: sc * 3)),
                        with: .color(config.jerseyColor.opacity(0.80))
                    )
                }
            }
        case .crowdSpectator:
            // Phone/camera flash
            let flash = CGFloat(abs(sin(t * 0.8 + Double(cx) * 0.1))) > 0.92
            if flash {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - sc * 4, y: headCY - sc * 12, width: sc * 8, height: sc * 6)),
                    with: .color(Color.white.opacity(0.60))
                )
            }
        default:
            break
        }
    }

    private static func strokeLine(
        ctx: inout GraphicsContext,
        a: CGPoint, b: CGPoint,
        color: Color, lw: CGFloat
    ) {
        var p = Path()
        p.move(to: a); p.addLine(to: b)
        ctx.stroke(p, with: .color(color), lineWidth: lw)
    }
}

// MARK: - Convenience: draw a row of crowd spectators

extension NPCFigurePainter {
    /// Draw N crowd spectators in a horizontal band.
    static func drawCrowdRow(
        ctx: inout GraphicsContext,
        startX: CGFloat, endX: CGFloat,
        baseY: CGFloat, canvasH: CGFloat,
        count: Int, t: Double,
        teamColor: Color, scale: CGFloat = 0.55,
        seed: Int = 0
    ) {
        let spacing = (endX - startX) / CGFloat(max(1, count - 1))
        for i in 0..<count {
            let cx = startX + CGFloat(i) * spacing
            // Offset t so each spectator is out of phase
            let localT = t + Double(i + seed) * 0.37
            // Alternate between clap and idle
            let clip: NPCAnimClip = (Int(t * 0.5 + Double(i)) % 3 == 0) ? .clap : .idle
            var cfg = NPCConfig(
                archetype: .crowdSpectator,
                jerseyColor: (i + seed) % 2 == 0 ? teamColor : teamColor.opacity(0.5),
                skinTone: .forIndex(i + seed),
                scale: scale,
                shadowOpacity: 0
            )
            cfg.hairColor = NPCSkinTone.forIndex((i * 3 + seed) % 5).accent
            draw(ctx: &ctx, cx: cx, baseY: baseY, canvasH: canvasH,
                 clip: clip, config: cfg, t: localT)
        }
    }
}
