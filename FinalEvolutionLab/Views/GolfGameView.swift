import SwiftUI
import UIKit

// MARK: - Supporting Types

private enum GolfPhase { case ready, aiming, result }

private struct GolfHoleResult {
    let hole: Int; let strokes: Int; let scoreName: String; let scoreVsPar: Int
}

private enum GolfObstacle: String {
    case sandTrap = "Sand Trap", water = "Water"
    var strokePenalty: Int { self == .water ? 2 : 1 }
}

private struct GolfObstacleLayout: Identifiable {
    let id = UUID()
    let type: GolfObstacle
    let position: CGPoint   // normalized 0–1, origin bottom-left
    let size: CGSize        // normalized
}

private enum ShotState { case idle, aiming, draggingBack, ballFlying, landed }

private enum ShotType { case driver, iron, wedge, putt }

// MARK: - GolfClub (14 clubs with real yardages)

private enum GolfClub: String, CaseIterable, Identifiable {
    case driver  = "DRIVER"
    case threeWood = "3 WOOD"
    case fiveWood  = "5 WOOD"
    case fourIron  = "4 IRON"
    case fiveIron  = "5 IRON"
    case sixIron   = "6 IRON"
    case sevenIron = "7 IRON"
    case eightIron = "8 IRON"
    case nineIron  = "9 IRON"
    case pitchingWedge = "PW"
    case sandWedge     = "SW"
    case lobWedge      = "LW"
    case putter        = "PUTTER"
    case hybridFour    = "4 HYB"

    var id: String { rawValue }

    // Base yardage (mid-range of typical amateur distances)
    var baseYardage: Int {
        switch self {
        case .driver:        return 270
        case .threeWood:     return 245
        case .fiveWood:      return 225
        case .hybridFour:    return 205
        case .fourIron:      return 195
        case .fiveIron:      return 183
        case .sixIron:       return 170
        case .sevenIron:     return 157
        case .eightIron:     return 143
        case .nineIron:      return 128
        case .pitchingWedge: return 110
        case .sandWedge:     return  85
        case .lobWedge:      return  60
        case .putter:        return  15
        }
    }

    // Launch angle in degrees (higher = more loft)
    var launchAngle: Double {
        switch self {
        case .driver:        return 12
        case .threeWood:     return 14
        case .fiveWood:      return 16
        case .hybridFour:    return 18
        case .fourIron:      return 20
        case .fiveIron:      return 22
        case .sixIron:       return 25
        case .sevenIron:     return 28
        case .eightIron:     return 31
        case .nineIron:      return 34
        case .pitchingWedge: return 38
        case .sandWedge:     return 44
        case .lobWedge:      return 52
        case .putter:        return  2
        }
    }

    // Spin rate (rpm – higher = more stopping power)
    var spinRate: Int {
        switch self {
        case .driver:        return 2700
        case .threeWood:     return 3200
        case .fiveWood:      return 3600
        case .hybridFour:    return 4000
        case .fourIron:      return 4400
        case .fiveIron:      return 4800
        case .sixIron:       return 5200
        case .sevenIron:     return 5700
        case .eightIron:     return 6200
        case .nineIron:      return 6800
        case .pitchingWedge: return 7800
        case .sandWedge:     return 8500
        case .lobWedge:      return 9200
        case .putter:        return  500
        }
    }

    // Mishit penalty: how much extra scatter on off-center hits (0–1)
    var mishitPenalty: Double {
        switch self {
        case .driver:        return 0.18
        case .threeWood:     return 0.15
        case .fiveWood:      return 0.13
        case .hybridFour:    return 0.11
        case .fourIron:      return 0.12
        case .fiveIron:      return 0.11
        case .sixIron:       return 0.10
        case .sevenIron:     return 0.09
        case .eightIron:     return 0.08
        case .nineIron:      return 0.08
        case .pitchingWedge: return 0.07
        case .sandWedge:     return 0.09
        case .lobWedge:      return 0.11
        case .putter:        return 0.04
        }
    }

    // Whether this club qualifies for spin control UI
    var supportsSpinControl: Bool {
        switch self {
        case .fourIron, .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron,
             .pitchingWedge, .sandWedge, .lobWedge:
            return true
        default:
            return false
        }
    }

    // Whether this club is a putter variant
    var isPutter: Bool { self == .putter }

    // Short display name for buttons
    var shortName: String {
        switch self {
        case .driver:        return "DR"
        case .threeWood:     return "3W"
        case .fiveWood:      return "5W"
        case .hybridFour:    return "4H"
        case .fourIron:      return "4I"
        case .fiveIron:      return "5I"
        case .sixIron:       return "6I"
        case .sevenIron:     return "7I"
        case .eightIron:     return "8I"
        case .nineIron:      return "9I"
        case .pitchingWedge: return "PW"
        case .sandWedge:     return "SW"
        case .lobWedge:      return "LW"
        case .putter:        return "PT"
        }
    }

    // Distance range string for display
    var distanceRange: String {
        switch self {
        case .driver:        return "250–300y"
        case .threeWood:     return "230–260y"
        case .fiveWood:      return "210–240y"
        case .hybridFour:    return "195–215y"
        case .fourIron:      return "185–205y"
        case .fiveIron:      return "173–193y"
        case .sixIron:       return "160–180y"
        case .sevenIron:     return "147–167y"
        case .eightIron:     return "133–153y"
        case .nineIron:      return "118–138y"
        case .pitchingWedge: return "100–120y"
        case .sandWedge:     return " 75– 95y"
        case .lobWedge:      return " 50– 70y"
        case .putter:        return "  5– 25y"
        }
    }

    // Best club recommendation given a yardage to hole
    static func recommended(forYards yards: Int) -> GolfClub {
        let target = yards
        return GolfClub.allCases.min(by: { abs($0.baseYardage - target) < abs($1.baseYardage - target) }) ?? .sevenIron
    }
}

// MARK: - Shot Shape

private enum ShotShape: String, CaseIterable {
    case straight = "STRAIGHT"
    case draw     = "DRAW"
    case fade     = "FADE"

    var icon: String {
        switch self {
        case .straight: return "arrow.up"
        case .draw:     return "arrow.up.left"
        case .fade:     return "arrow.up.right"
        }
    }

    // Lateral drift multiplier (positive = right drift, negative = left)
    var lateralBias: Double {
        switch self {
        case .straight: return  0.0
        case .draw:     return -0.06  // curves right-to-left
        case .fade:     return  0.06  // curves left-to-right
        }
    }

    // Distance multiplier
    var distanceMultiplier: Double {
        switch self {
        case .straight: return 1.00
        case .draw:     return 1.07   // extra 5–15y and more roll
        case .fade:     return 0.96   // slight distance loss for control
        }
    }

    var description: String {
        switch self {
        case .straight: return "Neutral trajectory"
        case .draw:     return "+5–15y · More roll"
        case .fade:     return "Max control · -4%"
        }
    }
}

// MARK: - Spin Control

private enum Spin: String, CaseIterable {
    case neutral   = "NEUTRAL"
    case backspin  = "BACK"
    case topspin   = "TOP"

    var icon: String {
        switch self {
        case .neutral:  return "circle"
        case .backspin: return "arrow.down.circle"
        case .topspin:  return "arrow.up.circle"
        }
    }

    // Roll-out modifier after landing (negative = check-back, positive = run-out yards)
    var rollModifier: Double {
        switch self {
        case .neutral:  return  0.0
        case .backspin: return -0.04  // ball checks back
        case .topspin:  return  0.06  // ball runs 10–20y
        }
    }

    var description: String {
        switch self {
        case .neutral:  return "Normal roll"
        case .backspin: return "Checks back (pro)"
        case .topspin:  return "Runs out 10–20y"
        }
    }
}

// MARK: - Course Hole Definition

private struct CourseHole {
    let number: Int
    let par: Int
    let yardage: Int
    let description: String
    let difficulty: String   // "Easy" / "Medium" / "Hard"
}

private let courseCard: [CourseHole] = [
    CourseHole(number: 1, par: 4, yardage: 385, description: "Dogleg right · Bunker left",         difficulty: "Medium"),
    CourseHole(number: 2, par: 3, yardage: 165, description: "Elevated tee · Wind in face",         difficulty: "Medium"),
    CourseHole(number: 3, par: 5, yardage: 520, description: "Long par 5 · Water right",            difficulty: "Hard"),
    CourseHole(number: 4, par: 4, yardage: 410, description: "Narrow fairway · Bunker both sides",  difficulty: "Hard"),
    CourseHole(number: 5, par: 3, yardage: 140, description: "Island green · Short carry",          difficulty: "Hard"),
    CourseHole(number: 6, par: 5, yardage: 480, description: "Reachable par 5 · Tailwind hole",    difficulty: "Easy"),
    CourseHole(number: 7, par: 4, yardage: 360, description: "Risk/reward · Cut corner",            difficulty: "Medium"),
    CourseHole(number: 8, par: 3, yardage: 190, description: "Long par 3 · Bunker front",           difficulty: "Hard"),
    CourseHole(number: 9, par: 4, yardage: 375, description: "Finishing hole · Water left",         difficulty: "Medium"),
]

// MARK: - Green Slope Data

private struct GreenSlopeArrow: Identifiable {
    let id = UUID()
    let position: CGPoint   // normalized 0–1 within green area
    let angle: Double       // direction the ball will break (degrees)
    let strength: Double    // 0–1
}

// MARK: - Haptic Helpers

private func hapticHeavy() {
    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
}
private func hapticRigid() {
    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
}
private func hapticMedium() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
private func hapticSoft() {
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
}
private func hapticError() {
    UINotificationFeedbackGenerator().notificationOccurred(.error)
}

// MARK: - Canvas View

private struct GolfCourseCanvas: View {
    let ballX: Double;      let ballY: Double
    let ballProgress: Double
    let ballStartX: Double; let ballStartY: Double
    let ballEndX: Double;   let ballEndY: Double
    let holePosition: CGPoint
    let obstacles: [GolfObstacleLayout]
    let aimAngle: Double;   let pullDistance: CGFloat
    let shotState: ShotState; let golferPose: String
    let crowdExcitement: Double
    let currentHole: Int
    let currentStrokes: Int
    let totalStrokes: Int
    let parPerHole: Int
    let holeResults: [GolfHoleResult]
    let windAngle: Double
    let windSpeed: Double
    let showImpactFX: Bool
    let impactFXType: String
    let shotTypeLabel: String

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                var d = GolfDrawer(
                    t: tl.date.timeIntervalSinceReferenceDate, size: size,
                    ballX: ballX, ballY: ballY, ballProgress: ballProgress,
                    ballStartX: ballStartX, ballStartY: ballStartY,
                    ballEndX: ballEndX, ballEndY: ballEndY,
                    holePosition: holePosition, obstacles: obstacles,
                    aimAngle: aimAngle, pullDistance: pullDistance,
                    shotState: shotState, golferPose: golferPose,
                    crowdExcitement: crowdExcitement,
                    currentHole: currentHole, currentStrokes: currentStrokes,
                    totalStrokes: totalStrokes, parPerHole: parPerHole,
                    holeResults: holeResults,
                    windAngle: windAngle, windSpeed: windSpeed,
                    showImpactFX: showImpactFX, impactFXType: impactFXType,
                    shotTypeLabel: shotTypeLabel
                )
                d.render(ctx: &ctx)
            }
        }
    }
}

// MARK: - Drawer

private struct GolfDrawer {
    let t: Double
    let W: CGFloat; let H: CGFloat
    let ballX: Double;      let ballY: Double;  let ballProgress: Double
    let ballStartX: Double; let ballStartY: Double
    let ballEndX: Double;   let ballEndY: Double
    let holePosition: CGPoint
    let obstacles: [GolfObstacleLayout]
    let aimAngle: Double;   let pullDistance: CGFloat
    let shotState: ShotState; let golferPose: String
    let crowdExcitement: Double
    let currentHole: Int
    let currentStrokes: Int
    let totalStrokes: Int
    let parPerHole: Int
    let holeResults: [GolfHoleResult]
    let windAngle: Double
    let windSpeed: Double
    let showImpactFX: Bool
    let impactFXType: String
    let shotTypeLabel: String

    init(t: Double, size: CGSize,
         ballX: Double, ballY: Double, ballProgress: Double,
         ballStartX: Double, ballStartY: Double,
         ballEndX: Double, ballEndY: Double,
         holePosition: CGPoint, obstacles: [GolfObstacleLayout],
         aimAngle: Double, pullDistance: CGFloat,
         shotState: ShotState, golferPose: String, crowdExcitement: Double,
         currentHole: Int, currentStrokes: Int, totalStrokes: Int, parPerHole: Int,
         holeResults: [GolfHoleResult],
         windAngle: Double, windSpeed: Double,
         showImpactFX: Bool, impactFXType: String, shotTypeLabel: String) {
        self.t = t; W = size.width; H = size.height
        self.ballX = ballX; self.ballY = ballY; self.ballProgress = ballProgress
        self.ballStartX = ballStartX; self.ballStartY = ballStartY
        self.ballEndX = ballEndX; self.ballEndY = ballEndY
        self.holePosition = holePosition; self.obstacles = obstacles
        self.aimAngle = aimAngle; self.pullDistance = pullDistance
        self.shotState = shotState; self.golferPose = golferPose
        self.crowdExcitement = crowdExcitement
        self.currentHole = currentHole; self.currentStrokes = currentStrokes
        self.totalStrokes = totalStrokes; self.parPerHole = parPerHole
        self.holeResults = holeResults
        self.windAngle = windAngle; self.windSpeed = windSpeed
        self.showImpactFX = showImpactFX; self.impactFXType = impactFXType
        self.shotTypeLabel = shotTypeLabel
    }

    // Coord helpers: normalized (0–1, origin bottom-left) → canvas (origin top-left)
    func nx(_ n: Double) -> CGFloat { CGFloat(n) * W }
    func ny(_ n: Double) -> CGFloat { (1.0 - CGFloat(n)) * H }

    var hx: CGFloat { CGFloat(holePosition.x) * W }
    var hy: CGFloat { (1.0 - CGFloat(holePosition.y)) * H }
    var ballCX: CGFloat { nx(ballX) }
    var ballCY: CGFloat { ny(ballY) }

    // Current ball canvas position during flight or at rest
    var currentBallPos: (CGFloat, CGFloat) {
        if ballProgress >= 0 {
            let ep = CGFloat(ballProgress)
            let sx = nx(ballStartX); let sy = ny(ballStartY)
            let ex = nx(ballEndX);   let ey = ny(ballEndY)
            let peakH: CGFloat = 85
            let bx = sx + (ex - sx) * ep
            let by = sy + (ey - sy) * ep - peakH * 4 * ep * (1 - ep)
            return (bx, by)
        }
        return (ballCX, ballCY)
    }

    mutating func render(ctx: inout GraphicsContext) {
        // ── Scene 1: Course BG ──
        drawSkyGradient(&ctx)          // #1–#6
        drawMountainRange(&ctx)        // #7–#8
        drawFairwayHills(&ctx)         // #9–#10
        drawFescueStrips(&ctx)         // #11
        drawTrees(&ctx)                // #12

        // ── Scene 2: Obstacles & Green ──
        drawWaterHazard(&ctx)          // #13
        drawSandTrap(&ctx)             // #14
        drawFairway(&ctx)              // #15–#16
        drawGreen(&ctx)                // #17–#20

        // ── Scene 3: Hole Layout mini-map ──
        drawMiniMap(&ctx)              // #21–#28

        // ── Scene 4: Flag / pin ──
        drawFlag(&ctx)                 // #29–#31

        // ── Scene 5: Putt line & landing ring ──
        drawPuttLine(&ctx)             // #32
        drawLandingRing(&ctx)          // #33

        // ── Scene 6: Aim arc ──
        if shotState != .ballFlying { drawAimLine(&ctx) } // #34–#35

        // ── Scene 7: Ball trail ──
        if ballProgress >= 0 { drawTrail(&ctx) } // #36–#43

        // ── Scene 8: Wind drift arrow & apex ──
        if shotState == .ballFlying { drawWindDrift(&ctx) } // #44
        if shotState == .ballFlying { drawApexIndicator(&ctx) } // #45

        // ── Scene 9: Ball ──
        drawBall(&ctx)                 // #46–#50

        // ── Scene 10: Golfer & caddie ──
        if ballProgress < 0.3 || ballProgress < 0 {
            drawCaddie(&ctx)           // #51–#53
            drawGolfer(&ctx)           // #54–#65
        }

        // ── Scene 11: Impact FX ──
        if showImpactFX { drawImpactFX(&ctx) } // #66–#76

        // ── Scene 12: Score / UI on canvas ──
        drawScorecardPanel(&ctx)       // #77–#80
        drawWindDial(&ctx)             // #81–#82
        drawClubDisplay(&ctx)          // #83
        drawDistanceRing(&ctx)         // #84
    }

    // MARK: - #1–#6 Sky Gradient (morning light)

    private func drawSkyGradient(_ ctx: inout GraphicsContext) {
        let skyH = H * 0.32

        // #1 Sky base gradient — pale blue at top to warm orange at horizon
        var skyPath = Path()
        skyPath.addRect(CGRect(x: 0, y: 0, width: W, height: skyH))
        ctx.fill(skyPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.52, green: 0.76, blue: 0.92),
                Color(red: 0.75, green: 0.88, blue: 0.96),
                Color(red: 0.99, green: 0.82, blue: 0.56),
                Color(red: 0.98, green: 0.65, blue: 0.30)
            ]),
            startPoint: CGPoint(x: W / 2, y: 0),
            endPoint: CGPoint(x: W / 2, y: skyH)
        ))

        // #2 Morning sun glow (blurred halo)
        let sunX = W * 0.78
        let sunY = skyH * 0.38 + CGFloat(sin(t * 0.08)) * 2
        var sunGlow = ctx
        sunGlow.addFilter(.blur(radius: 22))
        var sunGlowPath = Path()
        sunGlowPath.addEllipse(in: CGRect(x: sunX - 36, y: sunY - 36, width: 72, height: 72))
        sunGlow.fill(sunGlowPath, with: .color(Color(red: 1.0, green: 0.88, blue: 0.45).opacity(0.55)))

        // #3 Sun disc
        var sunDisc = Path()
        sunDisc.addEllipse(in: CGRect(x: sunX - 16, y: sunY - 16, width: 32, height: 32))
        ctx.fill(sunDisc, with: .color(Color(red: 1.0, green: 0.94, blue: 0.65)))

        // #4 Sun rays
        for i in 0..<8 {
            let angle = Double(i) * (.pi / 4.0) + t * 0.06
            var rayPath = Path()
            rayPath.move(to: CGPoint(x: sunX + CGFloat(cos(angle)) * 18, y: sunY + CGFloat(sin(angle)) * 18))
            rayPath.addLine(to: CGPoint(x: sunX + CGFloat(cos(angle)) * 28, y: sunY + CGFloat(sin(angle)) * 28))
            ctx.stroke(rayPath, with: .color(Color(red: 1.0, green: 0.90, blue: 0.50).opacity(0.45)), lineWidth: 1.5)
        }

        // #5 Cloud row 1 (animated drift)
        let cloudColors: [Color] = [.white.opacity(0.88), .white.opacity(0.76), .white.opacity(0.70)]
        for i in 0..<3 {
            let cx = W * CGFloat(0.12 + Double(i) * 0.32) + CGFloat(fmod(t * 3.0 + Double(i) * 40.0, W + 60)) - 30
            let cy = skyH * CGFloat(0.22 + Double(i % 2) * 0.12)
            for j in 0..<5 {
                let dx = CGFloat(j - 2) * 14
                let dy = CGFloat(j % 2 == 0 ? 0 : -6)
                let r: CGFloat = j == 2 ? 13 : (j == 1 || j == 3 ? 10 : 7)
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: cx + dx - r, y: cy + dy - r, width: r * 2, height: r * 2))
                ctx.fill(cloud, with: .color(cloudColors[i % 3]))
            }
        }

        // #6 Horizon haze
        var hazePath = Path()
        hazePath.addRect(CGRect(x: 0, y: skyH - 18, width: W, height: 18))
        ctx.fill(hazePath, with: .linearGradient(
            Gradient(colors: [Color.clear, Color(red: 0.98, green: 0.72, blue: 0.45).opacity(0.35)]),
            startPoint: CGPoint(x: W / 2, y: skyH - 18),
            endPoint: CGPoint(x: W / 2, y: skyH)
        ))
    }

    // MARK: - #7–#8 Mountain Range at horizon

    private func drawMountainRange(_ ctx: inout GraphicsContext) {
        let baseY = H * 0.32

        // #7 Far mountains (lighter, hazy)
        let farMtnData: [(CGFloat, CGFloat, CGFloat)] = [
            (W * 0.05, baseY + 2, W * 0.25),
            (W * 0.22, baseY - 12, W * 0.18),
            (W * 0.40, baseY - 6, W * 0.22),
            (W * 0.62, baseY - 18, W * 0.20),
            (W * 0.80, baseY - 8, W * 0.24),
            (W * 0.95, baseY + 4, W * 0.16)
        ]
        for (px, peakY, width) in farMtnData {
            var mtn = Path()
            mtn.move(to: CGPoint(x: px - width / 2, y: baseY))
            mtn.addLine(to: CGPoint(x: px, y: peakY))
            mtn.addLine(to: CGPoint(x: px + width / 2, y: baseY))
            mtn.closeSubpath()
            ctx.fill(mtn, with: .color(Color(red: 0.60, green: 0.70, blue: 0.75).opacity(0.55)))
        }

        // #8 Near mountain ridge (darker, solid)
        var nearRidge = Path()
        nearRidge.move(to: CGPoint(x: 0, y: baseY))
        let ridgePoints: [(CGFloat, CGFloat)] = [
            (W * 0.08, baseY - 5),
            (W * 0.18, baseY - 20),
            (W * 0.28, baseY - 10),
            (W * 0.38, baseY - 28),
            (W * 0.50, baseY - 16),
            (W * 0.62, baseY - 30),
            (W * 0.72, baseY - 12),
            (W * 0.82, baseY - 22),
            (W * 0.92, baseY - 8),
            (W, baseY - 4)
        ]
        for pt in ridgePoints { nearRidge.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        nearRidge.addLine(to: CGPoint(x: W, y: baseY))
        nearRidge.addLine(to: CGPoint(x: 0, y: baseY))
        nearRidge.closeSubpath()
        ctx.fill(nearRidge, with: .color(Color(red: 0.25, green: 0.38, blue: 0.30).opacity(0.80)))
    }

    // MARK: - #9–#10 Rolling Fairway Hills

    private func drawFairwayHills(_ ctx: inout GraphicsContext) {
        let hillBase = H * 0.34

        // #9 Left green hill
        var leftHill = Path()
        leftHill.move(to: CGPoint(x: -10, y: hillBase + 30))
        leftHill.addCurve(
            to: CGPoint(x: W * 0.48, y: hillBase + 30),
            control1: CGPoint(x: W * 0.10, y: hillBase - 20),
            control2: CGPoint(x: W * 0.32, y: hillBase - 30)
        )
        leftHill.addLine(to: CGPoint(x: W * 0.48, y: H))
        leftHill.addLine(to: CGPoint(x: -10, y: H))
        leftHill.closeSubpath()
        ctx.fill(leftHill, with: .color(Color(red: 0.12, green: 0.32, blue: 0.14)))

        // #10 Right undulating hill
        var rightHill = Path()
        rightHill.move(to: CGPoint(x: W * 0.52, y: hillBase + 30))
        rightHill.addCurve(
            to: CGPoint(x: W + 10, y: hillBase + 30),
            control1: CGPoint(x: W * 0.68, y: hillBase - 25),
            control2: CGPoint(x: W * 0.88, y: hillBase - 15)
        )
        rightHill.addLine(to: CGPoint(x: W + 10, y: H))
        rightHill.addLine(to: CGPoint(x: W * 0.52, y: H))
        rightHill.closeSubpath()
        ctx.fill(rightHill, with: .color(Color(red: 0.12, green: 0.32, blue: 0.14)))
    }

    // MARK: - #11 Rough/Fescue strips

    private func drawFescueStrips(_ ctx: inout GraphicsContext) {
        // #11 Fescue rough fringe strips along left and right edges of fairway
        let topFairway = H * 0.36
        let roughW: CGFloat = W * 0.07
        // Left rough
        var leftRough = Path()
        leftRough.addRect(CGRect(x: 0, y: topFairway, width: roughW, height: H - topFairway))
        ctx.fill(leftRough, with: .color(Color(red: 0.09, green: 0.25, blue: 0.11)))
        // Right rough
        var rightRough = Path()
        rightRough.addRect(CGRect(x: W - roughW, y: topFairway, width: roughW, height: H - topFairway))
        ctx.fill(rightRough, with: .color(Color(red: 0.09, green: 0.25, blue: 0.11)))

        // Fescue grass tufts along edges
        for i in 0..<20 {
            let frac = CGFloat(i) / 19.0
            let yPos = topFairway + frac * (H - topFairway - 20)
            let phase = sin(t * 1.2 + Double(i) * 0.9)
            // Left tufts
            for j in 0..<4 {
                let bx = W * 0.065 * CGFloat(j) / 3.0 + 2
                var tuft = Path()
                tuft.move(to: CGPoint(x: bx, y: yPos))
                tuft.addLine(to: CGPoint(x: bx + CGFloat(phase) * 2.5, y: yPos - 5 - CGFloat(j % 3) * 2))
                ctx.stroke(tuft, with: .color(Color(red: 0.14, green: 0.40, blue: 0.16).opacity(0.7)), lineWidth: 0.8)
            }
        }
    }

    // MARK: - #12 Tree Silhouettes (5 different heights)

    private func drawTrees(_ ctx: inout GraphicsContext) {
        // #12 Tree rows with 5 distinct height profiles
        let treeBaseY = H * 0.34
        let heightProfiles: [CGFloat] = [0.09, 0.12, 0.07, 0.11, 0.08]

        // Left forest line
        for i in 0..<7 {
            let tx = W * 0.02 + CGFloat(i) * W * 0.038
            let profile = heightProfiles[i % 5]
            let th = H * profile
            let sway = CGFloat(sin(t * 0.55 + Double(i) * 1.4)) * 1.8
            // Trunk
            var trunk = Path()
            trunk.move(to: CGPoint(x: tx + sway, y: treeBaseY + th))
            trunk.addLine(to: CGPoint(x: tx + sway, y: treeBaseY + th * 0.62))
            ctx.stroke(trunk, with: .color(Color(red: 0.32, green: 0.20, blue: 0.09)), lineWidth: 2.8)
            // Pine canopy (triangle)
            if i % 3 == 0 {
                var pine = Path()
                pine.move(to: CGPoint(x: tx + sway, y: treeBaseY))
                pine.addLine(to: CGPoint(x: tx + sway - 10, y: treeBaseY + th * 0.65))
                pine.addLine(to: CGPoint(x: tx + sway + 10, y: treeBaseY + th * 0.65))
                pine.closeSubpath()
                ctx.fill(pine, with: .color(Color(red: 0.09, green: 0.26, blue: 0.11)))
            } else {
                // Round canopy
                let canopy = Path(ellipseIn: CGRect(x: tx + sway - 11, y: treeBaseY, width: 22, height: th * 0.72))
                ctx.fill(canopy, with: .color(Color(red: 0.10, green: 0.28, blue: 0.12)))
            }
        }

        // Right forest line
        for i in 0..<7 {
            let tx = W * 0.98 - CGFloat(i) * W * 0.038
            let profile = heightProfiles[(i + 2) % 5]
            let th = H * profile
            let sway = CGFloat(sin(t * 0.55 + Double(i) * 1.6 + 2.1)) * 1.8
            var trunk = Path()
            trunk.move(to: CGPoint(x: tx + sway, y: treeBaseY + th))
            trunk.addLine(to: CGPoint(x: tx + sway, y: treeBaseY + th * 0.62))
            ctx.stroke(trunk, with: .color(Color(red: 0.32, green: 0.20, blue: 0.09)), lineWidth: 2.8)
            if i % 3 == 1 {
                var pine = Path()
                pine.move(to: CGPoint(x: tx + sway, y: treeBaseY))
                pine.addLine(to: CGPoint(x: tx + sway - 11, y: treeBaseY + th * 0.65))
                pine.addLine(to: CGPoint(x: tx + sway + 11, y: treeBaseY + th * 0.65))
                pine.closeSubpath()
                ctx.fill(pine, with: .color(Color(red: 0.09, green: 0.26, blue: 0.11)))
            } else {
                let canopy = Path(ellipseIn: CGRect(x: tx + sway - 11, y: treeBaseY, width: 22, height: th * 0.72))
                ctx.fill(canopy, with: .color(Color(red: 0.10, green: 0.28, blue: 0.12)))
            }
        }
    }

    // MARK: - #13 Water Hazard

    private func drawWaterHazard(_ ctx: inout GraphicsContext) {
        // #13 Draw water hazard obstacles with animated shimmer
        for obs in obstacles where obs.type == .water {
            let ox = nx(obs.position.x)
            let oy = ny(obs.position.y)
            let ow = CGFloat(obs.size.width) * W
            let oh = CGFloat(obs.size.height) * H
            let rect = CGRect(x: ox - ow / 2, y: oy - oh / 2, width: ow, height: oh)

            // Water base
            ctx.fill(Path(ellipseIn: rect), with: .linearGradient(
                Gradient(colors: [Color(red: 0.15, green: 0.45, blue: 0.90),
                                  Color(red: 0.08, green: 0.28, blue: 0.68)]),
                startPoint: CGPoint(x: ox - ow / 2, y: oy - oh / 2),
                endPoint: CGPoint(x: ox + ow / 2, y: oy + oh / 2)
            ))

            // Animated shimmer lines
            for si in 0..<5 {
                let phase = fmod(t * 1.1 + Double(si) * 0.65, 1.0)
                let sx = ox - ow * 0.4 + CGFloat(phase) * ow * 0.8
                var shimmer = Path()
                shimmer.move(to: CGPoint(x: sx - 7, y: oy - oh * 0.1 + CGFloat(si % 2) * 4))
                shimmer.addQuadCurve(
                    to: CGPoint(x: sx + 7, y: oy + oh * 0.1 + CGFloat(si % 2) * 4),
                    control: CGPoint(x: sx + 3, y: oy + CGFloat(si % 2) * 4)
                )
                ctx.stroke(shimmer, with: .color(.white.opacity(0.32)), lineWidth: 1.1)
            }

            // "W" label
            ctx.draw(Text("W").font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8)),
                     at: CGPoint(x: ox, y: oy), anchor: .center)

            // Hazard border
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color(red: 0.20, green: 0.55, blue: 0.95).opacity(0.5)), lineWidth: 1.2)
        }
    }

    // MARK: - #14 Sand Trap

    private func drawSandTrap(_ ctx: inout GraphicsContext) {
        // #14 Draw sand trap obstacles with stippling texture
        for obs in obstacles where obs.type == .sandTrap {
            let ox = nx(obs.position.x)
            let oy = ny(obs.position.y)
            let ow = CGFloat(obs.size.width) * W
            let oh = CGFloat(obs.size.height) * H
            let rect = CGRect(x: ox - ow / 2, y: oy - oh / 2, width: ow, height: oh)

            // Sand base
            ctx.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.90, green: 0.82, blue: 0.54)))

            // Stipple dots
            for di in 0..<18 {
                let angle = Double(di) * .pi * 2.0 / 18.0
                let rr = ow * 0.30
                let dx = ox + rr * CGFloat(cos(angle)) * 0.85
                let dy = oy + (oh / ow) * rr * CGFloat(sin(angle))
                ctx.fill(Path(ellipseIn: CGRect(x: dx - 1.5, y: dy - 1.5, width: 3, height: 3)),
                         with: .color(Color(red: 0.68, green: 0.58, blue: 0.32).opacity(0.65)))
            }

            ctx.draw(Text("S").font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.50, green: 0.40, blue: 0.15)),
                     at: CGPoint(x: ox, y: oy), anchor: .center)

            // Border
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color(red: 0.75, green: 0.65, blue: 0.35).opacity(0.6)), lineWidth: 1.0)
        }
    }

    // MARK: - #15–#16 Fairway

    private func drawFairway(_ ctx: inout GraphicsContext) {
        let top = H * 0.36

        // #15 Rough (dark green base under fairway)
        var roughBase = Path()
        roughBase.addRect(CGRect(x: 0, y: top, width: W, height: H - top))
        ctx.fill(roughBase, with: .color(Color(red: 0.08, green: 0.22, blue: 0.10)))

        // Perspective fairway trapezoid
        let topL = CGPoint(x: W * 0.28, y: top)
        let topR = CGPoint(x: W * 0.72, y: top)
        let botL = CGPoint(x: W * 0.04, y: H)
        let botR = CGPoint(x: W * 0.96, y: H)

        var fw = Path()
        fw.move(to: topL); fw.addLine(to: topR)
        fw.addLine(to: botR); fw.addLine(to: botL)
        fw.closeSubpath()
        ctx.fill(fw, with: .color(Color(red: 0.16, green: 0.42, blue: 0.18)))

        // #16 Mowing stripes
        let stripes = 18
        for i in 0..<stripes {
            if i % 2 == 0 { continue }
            let t0 = CGFloat(i) / CGFloat(stripes)
            let t1 = CGFloat(i + 1) / CGFloat(stripes)
            let y0 = top + t0 * (H - top)
            let y1 = top + t1 * (H - top)
            let x0l = lerp(topL.x, botL.x, t0); let x0r = lerp(topR.x, botR.x, t0)
            let x1l = lerp(topL.x, botL.x, t1); let x1r = lerp(topR.x, botR.x, t1)
            var stripe = Path()
            stripe.move(to: CGPoint(x: x0l, y: y0)); stripe.addLine(to: CGPoint(x: x0r, y: y0))
            stripe.addLine(to: CGPoint(x: x1r, y: y1)); stripe.addLine(to: CGPoint(x: x1l, y: y1))
            stripe.closeSubpath()
            ctx.fill(stripe, with: .color(Color(red: 0.19, green: 0.46, blue: 0.20).opacity(0.50)))
        }
    }

    // MARK: - #17–#20 Green

    private func drawGreen(_ ctx: inout GraphicsContext) {
        let gr: CGFloat = 52

        // #17 Fringe ring
        let fringeRect = CGRect(x: hx - gr - 12, y: hy - gr - 12, width: (gr + 12) * 2, height: (gr + 12) * 2)
        ctx.fill(Path(ellipseIn: fringeRect), with: .color(Color(red: 0.17, green: 0.48, blue: 0.19)))

        // #18 Green surface
        ctx.fill(Path(ellipseIn: CGRect(x: hx - gr, y: hy - gr, width: gr * 2, height: gr * 2)),
                 with: .color(Color(red: 0.22, green: 0.62, blue: 0.24)))

        // #19 Contour rings
        for ri in [0.78, 0.54, 0.30] as [CGFloat] {
            let rr = gr * ri
            ctx.stroke(Path(ellipseIn: CGRect(x: hx - rr, y: hy - rr, width: rr * 2, height: rr * 2)),
                       with: .color(Color(red: 0.20, green: 0.56, blue: 0.22).opacity(0.42)), lineWidth: 0.7)
        }

        // #20 Cup shadow glow + cup
        var cupGlow = ctx
        cupGlow.addFilter(.blur(radius: 4))
        cupGlow.fill(Path(ellipseIn: CGRect(x: hx - 9, y: hy - 4, width: 18, height: 11)),
                     with: .color(.black.opacity(0.52)))
        ctx.fill(Path(ellipseIn: CGRect(x: hx - 6, y: hy - 5, width: 12, height: 10)),
                 with: .color(.black.opacity(0.88)))
    }

    // MARK: - #21–#28 Mini-Map Inset

    private func drawMiniMap(_ ctx: inout GraphicsContext) {
        let mapX: CGFloat = W - 82
        let mapY: CGFloat = 10
        let mapW: CGFloat = 72
        let mapH: CGFloat = 90

        // #21 Mini-map background
        var mapBg = ctx
        mapBg.addFilter(.blur(radius: 0))
        var bgRect = Path()
        bgRect.addRoundedRect(in: CGRect(x: mapX, y: mapY, width: mapW, height: mapH),
                              cornerSize: CGSize(width: 6, height: 6))
        ctx.fill(bgRect, with: .color(Color.black.opacity(0.72)))
        ctx.stroke(bgRect, with: .color(Color(red: 0.3, green: 0.8, blue: 0.4).opacity(0.6)), lineWidth: 1.0)

        // #22 Fairway path on mini-map
        let mfxL = mapX + mapW * 0.22
        let mfxR = mapX + mapW * 0.78
        let mfyT = mapY + mapH * 0.12
        let mfyB = mapY + mapH * 0.88
        var mapFairway = Path()
        mapFairway.move(to: CGPoint(x: mfxL, y: mfyB))
        mapFairway.addLine(to: CGPoint(x: mfxR, y: mfyB))
        mapFairway.addLine(to: CGPoint(x: mfxR - 6, y: mfyT))
        mapFairway.addLine(to: CGPoint(x: mfxL + 6, y: mfyT))
        mapFairway.closeSubpath()
        ctx.fill(mapFairway, with: .color(Color(red: 0.16, green: 0.44, blue: 0.18)))

        // #23 Green oval on mini-map
        let mgx = mapX + CGFloat(holePosition.x) * mapW
        let mgy = mapY + (1.0 - CGFloat(holePosition.y)) * mapH
        ctx.fill(Path(ellipseIn: CGRect(x: mgx - 6, y: mgy - 4, width: 12, height: 8)),
                 with: .color(Color(red: 0.22, green: 0.72, blue: 0.26)))

        // #24 Pin on mini-map
        var miniPin = Path()
        miniPin.move(to: CGPoint(x: mgx, y: mgy - 4))
        miniPin.addLine(to: CGPoint(x: mgx, y: mgy - 10))
        ctx.stroke(miniPin, with: .color(.white), lineWidth: 0.8)
        ctx.fill(Path(ellipseIn: CGRect(x: mgx, y: mgy - 12, width: 5, height: 4)),
                 with: .color(.red))

        // #25 Fairway path line on mini-map
        let mbx = mapX + CGFloat(ballX) * mapW
        let mby = mapY + (1.0 - CGFloat(ballY)) * mapH
        var pathLine = Path()
        pathLine.move(to: CGPoint(x: mbx, y: mby))
        pathLine.addLine(to: CGPoint(x: mgx, y: mgy))
        ctx.stroke(pathLine, with: .color(Color(red: 0.3, green: 0.9, blue: 0.5).opacity(0.45)), lineWidth: 0.7)

        // #26 Player dot on mini-map
        var playerGlow = ctx
        playerGlow.addFilter(.blur(radius: 2))
        playerGlow.fill(Path(ellipseIn: CGRect(x: mbx - 4, y: mby - 4, width: 8, height: 8)),
                        with: .color(Color.yellow.opacity(0.6)))
        ctx.fill(Path(ellipseIn: CGRect(x: mbx - 3, y: mby - 3, width: 6, height: 6)),
                 with: .color(.yellow))

        // #27 Par badge in mini-map corner
        var parBadge = Path()
        parBadge.addRoundedRect(in: CGRect(x: mapX + 2, y: mapY + 2, width: 22, height: 14),
                                cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(parBadge, with: .color(Color(red: 0.15, green: 0.55, blue: 0.25)))
        ctx.draw(Text("P\(parPerHole)").font(.system(size: 7, weight: .black, design: .monospaced))
            .foregroundStyle(.white),
                 at: CGPoint(x: mapX + 13, y: mapY + 9), anchor: .center)

        // #28 Hole number label on mini-map
        ctx.draw(Text("H\(currentHole)").font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(red: 0.8, green: 0.9, blue: 0.8)),
                 at: CGPoint(x: mapX + mapW - 14, y: mapY + 9), anchor: .center)
    }

    // MARK: - #29–#31 Flagstick

    private func drawFlag(_ ctx: inout GraphicsContext) {
        let poleH: CGFloat = 40
        let poleBase = CGPoint(x: hx, y: hy - 5)
        let poleTop  = CGPoint(x: hx, y: hy - 5 - poleH)

        // #29 Pole shadow
        var shadowPole = Path()
        shadowPole.move(to: CGPoint(x: poleBase.x + 2, y: poleBase.y + 2))
        shadowPole.addLine(to: CGPoint(x: poleTop.x + 3, y: poleTop.y + 3))
        ctx.stroke(shadowPole, with: .color(.black.opacity(0.22)), lineWidth: 2)

        // #30 Pole
        var pole = Path()
        pole.move(to: poleBase); pole.addLine(to: poleTop)
        ctx.stroke(pole, with: .color(Color(white: 0.90)), lineWidth: 1.8)

        // #31 Waving flag
        let wave = CGFloat(sin(t * 3.8)) * 5
        let wave2 = CGFloat(sin(t * 3.8 + 1.2)) * 3
        var flag = Path()
        flag.move(to: poleTop)
        flag.addCurve(
            to:       CGPoint(x: poleTop.x + 20, y: poleTop.y + 11 + wave),
            control1: CGPoint(x: poleTop.x + 7,  y: poleTop.y - 1 + wave2),
            control2: CGPoint(x: poleTop.x + 15, y: poleTop.y + 5 + wave)
        )
        flag.addLine(to: CGPoint(x: poleTop.x, y: poleTop.y + 13))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(Color(red: 0.10, green: 0.72, blue: 0.32)))
        ctx.stroke(flag, with: .color(Color(red: 0.08, green: 0.55, blue: 0.25)), lineWidth: 0.5)
    }

    // MARK: - #32 Putt Line

    private func drawPuttLine(_ ctx: inout GraphicsContext) {
        // #32 Dashed putt line from ball to hole when on green
        let gr: CGFloat = 52
        let dx = ballCX - hx
        let dy = ballCY - hy
        let distToGreen = sqrt(dx * dx + dy * dy)
        guard distToGreen < gr * 1.8, ballProgress < 0 else { return }

        let segs = 12
        for i in 0..<segs {
            if i % 2 == 1 { continue }
            let t0 = CGFloat(i) / CGFloat(segs)
            let t1 = CGFloat(i + 1) / CGFloat(segs)
            var seg = Path()
            seg.move(to: CGPoint(x: ballCX + (hx - ballCX) * t0, y: ballCY + (hy - ballCY) * t0))
            seg.addLine(to: CGPoint(x: ballCX + (hx - ballCX) * t1, y: ballCY + (hy - ballCY) * t1))
            ctx.stroke(seg, with: .color(Color.white.opacity(0.38)), lineWidth: 1.2)
        }
    }

    // MARK: - #33 Landing Ring

    private func drawLandingRing(_ ctx: inout GraphicsContext) {
        // #33 Animated landing ring at ball end position when flying
        guard ballProgress > 0.6 && ballProgress < 1.0 else { return }
        let ex = nx(ballEndX); let ey = ny(ballEndY)
        let pulse = CGFloat(sin(t * 10.0)) * 3
        let ringR: CGFloat = 12 + pulse
        var ring = Path()
        ring.addEllipse(in: CGRect(x: ex - ringR, y: ey - ringR * 0.5, width: ringR * 2, height: ringR))
        ctx.stroke(ring, with: .color(Color(red: 0.3, green: 0.9, blue: 0.4).opacity(0.6)), lineWidth: 1.5)
    }

    // MARK: - #34–#35 Aim Arc

    private func drawAimLine(_ ctx: inout GraphicsContext) {
        guard shotState == .idle || shotState == .draggingBack else { return }
        let power = min(1.0, Double(pullDistance) / 80.0)
        guard power > 0.02 else { return }

        let radians = aimAngle * .pi / 180.0
        let dist = CGFloat(power * 0.55) * W
        let ex = ballCX + dist * CGFloat(sin(radians))
        let ey = ballCY - dist * CGFloat(cos(radians))
        let peakH: CGFloat = CGFloat(power) * 75

        // #34 Dashed aim arc
        let segs = 16
        for i in 0..<segs {
            if i % 2 == 1 { continue }
            let t0 = CGFloat(i) / CGFloat(segs)
            let t1 = CGFloat(i + 1) / CGFloat(segs)
            let ax = ballCX + (ex - ballCX) * t0
            let ay = ballCY + (ey - ballCY) * t0 - peakH * 4 * t0 * (1 - t0)
            let bxp = ballCX + (ex - ballCX) * t1
            let byp = ballCY + (ey - ballCY) * t1 - peakH * 4 * t1 * (1 - t1)
            var seg = Path()
            seg.move(to: CGPoint(x: ax, y: ay))
            seg.addLine(to: CGPoint(x: bxp, y: byp))
            ctx.stroke(seg, with: .color(Color(red: 0.30, green: 0.88, blue: 0.42).opacity(0.78)), lineWidth: 1.9)
        }

        // #35 Pulsing target ring
        let pulse = CGFloat(sin(t * 5.0)) * 2.5
        let ring = Path(ellipseIn: CGRect(x: ex - 10 - pulse, y: ey - 10 - pulse,
                                          width: (10 + pulse) * 2, height: (10 + pulse) * 2))
        ctx.stroke(ring, with: .color(Color(red: 0.30, green: 0.88, blue: 0.42).opacity(0.58)), lineWidth: 1.6)
    }

    // MARK: - #36–#43 Ball Trail (8 ghost frames)

    private func drawTrail(_ ctx: inout GraphicsContext) {
        guard ballProgress >= 0 else { return }
        let sx = nx(ballStartX); let sy = ny(ballStartY)
        let ex = nx(ballEndX);   let ey = ny(ballEndY)
        let peakH: CGFloat = 85

        // #36–#43 8 ghost trail dots
        for g in 1...8 {
            let gp = CGFloat(max(0, ballProgress - Double(g) * 0.05))
            let tx = sx + (ex - sx) * gp
            let ty = sy + (ey - sy) * gp - peakH * 4 * gp * (1 - gp)
            let r: CGFloat = CGFloat(9 - g) * 0.7
            let alpha = (1.0 - Double(g) * 0.11) * 0.52
            // Each ghost numbered implicitly #36..#43
            ctx.fill(Path(ellipseIn: CGRect(x: tx - r, y: ty - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(alpha)))
        }
    }

    // MARK: - #44 Wind Drift Arrow

    private func drawWindDrift(_ ctx: inout GraphicsContext) {
        // #44 Small wind drift arrow during ball flight
        let (bx, by) = currentBallPos
        let arrowLen: CGFloat = 18 * CGFloat(windSpeed / 15.0)
        let wr = windAngle * .pi / 180.0
        let ax = bx + arrowLen * CGFloat(cos(wr))
        let ay = by + arrowLen * CGFloat(sin(wr))
        var windArrow = Path()
        windArrow.move(to: CGPoint(x: bx, y: by))
        windArrow.addLine(to: CGPoint(x: ax, y: ay))
        ctx.stroke(windArrow, with: .color(Color.cyan.opacity(0.6)), lineWidth: 1.4)
        // Arrowhead
        let ha: CGFloat = 0.5
        ctx.fill(Path(ellipseIn: CGRect(x: ax - 3, y: ay - 3, width: 6, height: 6)),
                 with: .color(Color.cyan.opacity(0.7 * ha)))
    }

    // MARK: - #45 Apex Indicator

    private func drawApexIndicator(_ ctx: inout GraphicsContext) {
        // #45 Dotted apex height indicator at the peak of ball flight
        guard ballProgress > 0.3 && ballProgress < 0.7 else { return }
        let sx = nx(ballStartX); let sy = ny(ballStartY)
        let ex = nx(ballEndX);   let ey = ny(ballEndY)
        let peakH: CGFloat = 85
        let apexX = sx + (ex - sx) * 0.5
        let apexY = sy + (ey - sy) * 0.5 - peakH
        let (bx, _) = currentBallPos
        // Vertical dashed line from ball ground to apex
        var apexLine = Path()
        apexLine.move(to: CGPoint(x: bx, y: apexY + 4))
        apexLine.addLine(to: CGPoint(x: bx, y: apexY + 14))
        ctx.stroke(apexLine, with: .color(Color.yellow.opacity(0.55)), lineWidth: 0.9)
        // Apex circle
        ctx.fill(Path(ellipseIn: CGRect(x: apexX - 3, y: apexY - 3, width: 6, height: 6)),
                 with: .color(Color.yellow.opacity(0.70)))
    }

    // MARK: - #46–#50 Ball

    private func drawBall(_ ctx: inout GraphicsContext) {
        let (bxPos, byPos) = currentBallPos
        let r: CGFloat = ballProgress >= 0 ? max(4, 8 - CGFloat(ballProgress) * 3.5) : 8

        // #46 Drop shadow glow
        var shadowGlow = ctx
        shadowGlow.addFilter(.blur(radius: r * 0.7))
        shadowGlow.fill(Path(ellipseIn: CGRect(x: bxPos - r * 0.95, y: byPos + r * 0.45,
                                               width: r * 1.9, height: r * 0.65)),
                        with: .color(.black.opacity(0.28)))

        // #47 Ball body radial gradient
        ctx.fill(Path(ellipseIn: CGRect(x: bxPos - r, y: byPos - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(
                    Gradient(colors: [.white, Color(white: 0.76)]),
                    center: CGPoint(x: bxPos - r * 0.28, y: byPos - r * 0.28),
                    startRadius: 0, endRadius: r * 1.25))

        // #48 Dimple seam arc
        var seam = Path()
        seam.addArc(center: CGPoint(x: bxPos, y: byPos), radius: r - 2.0,
                    startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
        ctx.stroke(seam, with: .color(Color(white: 0.52).opacity(0.42)), lineWidth: 0.9)

        // #49 Second seam arc
        var seam2 = Path()
        seam2.addArc(center: CGPoint(x: bxPos, y: byPos), radius: r - 2.0,
                     startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        ctx.stroke(seam2, with: .color(Color(white: 0.52).opacity(0.30)), lineWidth: 0.9)

        // #50 Specular highlight
        ctx.fill(Path(ellipseIn: CGRect(x: bxPos - r * 0.48, y: byPos - r * 0.62,
                                        width: r * 0.38, height: r * 0.24)),
                 with: .color(.white.opacity(0.88)))
    }

    // MARK: - #51–#53 Caddie Silhouette

    private func drawCaddie(_ ctx: inout GraphicsContext) {
        // Caddie stands to the right/behind the golfer
        let cgx = ballCX + 22
        let cBaseY = ballCY + 34
        let cColor = Color(red: 0.30, green: 0.28, blue: 0.42)

        // #51 Caddie head
        ctx.fill(Path(ellipseIn: CGRect(x: cgx - 4, y: cBaseY - 28, width: 8, height: 8)),
                 with: .color(cColor))

        // #52 Caddie body
        var cBody = Path()
        cBody.move(to: CGPoint(x: cgx, y: cBaseY - 20))
        cBody.addLine(to: CGPoint(x: cgx, y: cBaseY - 8))
        ctx.stroke(cBody, with: .color(cColor), lineWidth: 4)

        // #53 Caddie golf bag (rectangle behind them)
        var bagRect = Path()
        bagRect.addRoundedRect(in: CGRect(x: cgx + 4, y: cBaseY - 22, width: 6, height: 18),
                               cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(bagRect, with: .color(Color(red: 0.45, green: 0.30, blue: 0.18)))
        // Club shafts sticking out
        for ci in 0..<3 {
            var shaft = Path()
            shaft.move(to: CGPoint(x: cgx + 5 + CGFloat(ci) * 1.5, y: cBaseY - 22))
            shaft.addLine(to: CGPoint(x: cgx + 5 + CGFloat(ci) * 1.5, y: cBaseY - 28))
            ctx.stroke(shaft, with: .color(Color(white: 0.65)), lineWidth: 0.8)
        }
    }

    // MARK: - #54–#65 Golfer at Address / Swing Poses

    private func drawGolfer(_ ctx: inout GraphicsContext) {
        let gx = ballCX
        let headY  = ballCY + 10
        let waistY = ballCY + 22
        let feetY  = ballCY + 34

        let jersey = Color(red: 0.92, green: 0.75, blue: 0.25)
        let skin   = Color(red: 0.94, green: 0.80, blue: 0.68)
        let pants  = Color(red: 0.20, green: 0.22, blue: 0.50)
        let clubC  = Color(white: 0.65)

        // #54 Stance shadow on ground
        var stance = ctx
        stance.addFilter(.blur(radius: 4))
        stance.fill(Path(ellipseIn: CGRect(x: gx - 14, y: feetY - 2, width: 28, height: 6)),
                    with: .color(.black.opacity(0.32)))

        // #55 Hat brim
        let hatBrim = Path(ellipseIn: CGRect(x: gx - 7, y: headY - 8, width: 14, height: 5))
        ctx.fill(hatBrim, with: .color(Color(red: 0.15, green: 0.50, blue: 0.20)))

        // #56 Hat top
        let hatTop = Path(ellipseIn: CGRect(x: gx - 4.5, y: headY - 14, width: 9, height: 8))
        ctx.fill(hatTop, with: .color(Color(red: 0.12, green: 0.42, blue: 0.16)))

        // #57 Head
        ctx.fill(Path(ellipseIn: CGRect(x: gx - 5.5, y: headY - 5.5, width: 11, height: 11)),
                 with: .color(skin))

        // #58 Body torso
        var body = Path()
        body.move(to: CGPoint(x: gx, y: headY + 4))
        body.addLine(to: CGPoint(x: gx, y: waistY))
        ctx.stroke(body, with: .color(jersey), lineWidth: 4)

        // #59–#62 Arms + club (pose-dependent)
        switch golferPose {
        case "backswing":
            // #59 Backswing arms rotate up-right
            var arms = Path()
            arms.move(to: CGPoint(x: gx - 9, y: headY + 12))
            arms.addLine(to: CGPoint(x: gx, y: headY + 7))
            arms.addLine(to: CGPoint(x: gx + 8, y: headY + 4))
            arms.addLine(to: CGPoint(x: gx + 14, y: headY - 7))
            ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)
            var cl = Path()
            cl.move(to: CGPoint(x: gx + 14, y: headY - 7))
            cl.addLine(to: CGPoint(x: gx + 22, y: headY - 16))
            ctx.stroke(cl, with: .color(clubC), lineWidth: 1.6)

        case "impact":
            // #60 Impact position — arms extended toward ball
            var arms = Path()
            arms.move(to: CGPoint(x: gx + 10, y: headY + 8))
            arms.addLine(to: CGPoint(x: gx, y: headY + 6))
            arms.addLine(to: CGPoint(x: gx - 12, y: headY + 9))
            ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)
            var cl = Path()
            cl.move(to: CGPoint(x: gx - 12, y: headY + 9))
            cl.addLine(to: CGPoint(x: gx - 20, y: headY + 7))
            ctx.stroke(cl, with: .color(clubC), lineWidth: 1.6)
            // #61 Impact sparks
            for sp in 0..<6 {
                let a = Double(sp) * .pi / 3.0
                let sr: CGFloat = 7
                var spark = Path()
                spark.move(to: CGPoint(x: gx - 20, y: headY + 7))
                spark.addLine(to: CGPoint(x: gx - 20 + sr * CGFloat(cos(a)),
                                           y: headY + 7 + sr * CGFloat(sin(a))))
                ctx.stroke(spark, with: .color(Color(red: 1, green: 0.85, blue: 0.2).opacity(0.80)), lineWidth: 1.0)
            }

        case "followthrough":
            // #62 Follow-through arc — arms wrap around left high
            var arms = Path()
            arms.move(to: CGPoint(x: gx + 8, y: headY + 12))
            arms.addLine(to: CGPoint(x: gx, y: headY + 7))
            arms.addLine(to: CGPoint(x: gx - 8, y: headY + 3))
            arms.addLine(to: CGPoint(x: gx - 15, y: headY - 8))
            ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)
            var cl = Path()
            cl.move(to: CGPoint(x: gx - 15, y: headY - 8))
            cl.addLine(to: CGPoint(x: gx - 22, y: headY - 18))
            ctx.stroke(cl, with: .color(clubC), lineWidth: 1.6)
            // #63 Follow-through divot dirt splash
            for di in 0..<8 {
                let da = Double(di) * .pi / 4.0 + .pi * 1.1
                let dr: CGFloat = CGFloat(4 + di % 4) * 1.8
                ctx.fill(Path(ellipseIn: CGRect(
                    x: ballCX - 12 + dr * CGFloat(cos(da)) - 1.5,
                    y: ballCY + dr * CGFloat(sin(da)) - 1.5,
                    width: 3, height: 3)),
                         with: .color(Color(red: 0.25, green: 0.18, blue: 0.08).opacity(0.72)))
            }

        default: // address
            // #64 Address — arms down holding club at setup
            var arms = Path()
            arms.move(to: CGPoint(x: gx - 9, y: headY + 10))
            arms.addLine(to: CGPoint(x: gx, y: headY + 7))
            arms.addLine(to: CGPoint(x: gx + 9, y: headY + 10))
            ctx.stroke(arms, with: .color(skin), lineWidth: 2.2)
            var cl = Path()
            cl.move(to: CGPoint(x: gx - 9, y: headY + 10))
            cl.addLine(to: CGPoint(x: gx - 10, y: ballCY + 4))
            cl.addLine(to: CGPoint(x: gx - 6, y: ballCY + 4))
            ctx.stroke(cl, with: .color(clubC), lineWidth: 1.6)
        }

        // #65 Legs
        var legs = Path()
        legs.move(to: CGPoint(x: gx - 6, y: feetY))
        legs.addLine(to: CGPoint(x: gx, y: waistY))
        legs.addLine(to: CGPoint(x: gx + 6, y: feetY))
        ctx.stroke(legs, with: .color(pants), lineWidth: 2.8)
    }

    // MARK: - #66–#76 Impact FX

    private func drawImpactFX(_ ctx: inout GraphicsContext) {
        let impactX = nx(ballStartX)
        let impactY = ny(ballStartY)

        switch impactFXType {
        case "driver":
            // #66 Grass spray — 12 green dots
            for gi in 0..<12 {
                let ga = Double(gi) * .pi * 2.0 / 12.0
                let gr: CGFloat = CGFloat(8 + gi % 5) * 2.0
                let px = impactX + gr * CGFloat(cos(ga))
                let py = impactY + gr * CGFloat(sin(ga)) * 0.5
                ctx.fill(Path(ellipseIn: CGRect(x: px - 2, y: py - 2, width: 4, height: 4)),
                         with: .color(Color(red: 0.20, green: 0.65, blue: 0.22).opacity(0.80)))
            }
            // #67 Grass spray glow
            var grassGlow = ctx
            grassGlow.addFilter(.blur(radius: 5))
            grassGlow.fill(Path(ellipseIn: CGRect(x: impactX - 16, y: impactY - 8, width: 32, height: 16)),
                           with: .color(Color(red: 0.15, green: 0.60, blue: 0.20).opacity(0.40)))
            // #68 Speed lines from drive
            for sl in 0..<5 {
                let sly = impactY - CGFloat(sl) * 6
                var speedLine = Path()
                speedLine.move(to: CGPoint(x: impactX - 22, y: sly))
                speedLine.addLine(to: CGPoint(x: impactX - 8, y: sly))
                ctx.stroke(speedLine, with: .color(Color.white.opacity(0.50)), lineWidth: 0.9)
            }

        case "iron":
            // #69 Iron divot explosion — turf chunks
            for di in 0..<10 {
                let da = Double(di) * .pi / 5.0 + .pi * 0.8
                let dr: CGFloat = CGFloat(5 + di % 4) * 2.2
                ctx.fill(Path(ellipseIn: CGRect(
                    x: impactX + dr * CGFloat(cos(da)) - 2,
                    y: impactY + dr * CGFloat(sin(da)) * 0.55 - 2,
                    width: 4, height: 4)),
                         with: .color(Color(red: 0.22, green: 0.15, blue: 0.06).opacity(0.75)))
            }
            // #70 Iron impact ring
            var ironRing = ctx
            ironRing.addFilter(.blur(radius: 2))
            ironRing.stroke(Path(ellipseIn: CGRect(x: impactX - 12, y: impactY - 6, width: 24, height: 12)),
                            with: .color(Color.orange.opacity(0.45)), lineWidth: 2)

        case "bunker":
            // #71 Bunker sand burst — tan dots exploding outward
            for si in 0..<16 {
                let sa = Double(si) * .pi * 2.0 / 16.0
                let sr: CGFloat = CGFloat(6 + si % 6) * 2.0
                ctx.fill(Path(ellipseIn: CGRect(
                    x: impactX + sr * CGFloat(cos(sa)) - 2,
                    y: impactY + sr * CGFloat(sin(sa)) * 0.5 - 2,
                    width: 4, height: 4)),
                         with: .color(Color(red: 0.88, green: 0.78, blue: 0.48).opacity(0.78)))
            }
            // #72 Sand burst center glow
            var sandGlow = ctx
            sandGlow.addFilter(.blur(radius: 8))
            sandGlow.fill(Path(ellipseIn: CGRect(x: impactX - 14, y: impactY - 8, width: 28, height: 16)),
                          with: .color(Color(red: 0.95, green: 0.85, blue: 0.55).opacity(0.50)))

        case "water":
            // #73 Splash ring on water surface
            var splashRing = ctx
            splashRing.addFilter(.blur(radius: 1))
            splashRing.stroke(Path(ellipseIn: CGRect(x: impactX - 18, y: impactY - 8, width: 36, height: 16)),
                              with: .color(Color(red: 0.30, green: 0.65, blue: 0.95).opacity(0.70)), lineWidth: 2.5)
            // #74 Inner splash ring
            ctx.stroke(Path(ellipseIn: CGRect(x: impactX - 10, y: impactY - 4, width: 20, height: 8)),
                       with: .color(.white.opacity(0.50)), lineWidth: 1.5)
            // #75 Water droplets
            for wi in 0..<8 {
                let wa = Double(wi) * .pi / 4.0
                let wr2: CGFloat = 20
                ctx.fill(Path(ellipseIn: CGRect(
                    x: impactX + wr2 * CGFloat(cos(wa)) - 2,
                    y: impactY + wr2 * CGFloat(sin(wa)) * 0.4 - 3,
                    width: 3, height: 5)),
                         with: .color(.white.opacity(0.60)))
            }

        case "holein":
            // #76 Hole-out burst — gold ring + 8 gold stars
            var goldGlow = ctx
            goldGlow.addFilter(.blur(radius: 10))
            goldGlow.fill(Path(ellipseIn: CGRect(x: hx - 24, y: hy - 24, width: 48, height: 48)),
                          with: .color(Color(red: 1.0, green: 0.85, blue: 0.20).opacity(0.65)))
            ctx.stroke(Path(ellipseIn: CGRect(x: hx - 20, y: hy - 20, width: 40, height: 40)),
                       with: .color(Color(red: 1.0, green: 0.85, blue: 0.20)), lineWidth: 2.5)
            for si in 0..<8 {
                let sa = Double(si) * .pi / 4.0 + t * 2.0
                let sr: CGFloat = 26
                var starPt = Path()
                starPt.move(to: CGPoint(x: hx + (sr - 6) * CGFloat(cos(sa)), y: hy + (sr - 6) * CGFloat(sin(sa))))
                starPt.addLine(to: CGPoint(x: hx + sr * CGFloat(cos(sa)), y: hy + sr * CGFloat(sin(sa))))
                ctx.stroke(starPt, with: .color(Color(red: 1.0, green: 0.88, blue: 0.30)), lineWidth: 2)
            }

        default: break
        }
    }

    // MARK: - #77–#80 Scorecard Panel

    private func drawScorecardPanel(_ ctx: inout GraphicsContext) {
        let panelX: CGFloat = 8
        let panelY: CGFloat = 10
        let panelW: CGFloat = 80
        let panelH: CGFloat = 62

        // #77 Scorecard background
        var panelBg = Path()
        panelBg.addRoundedRect(in: CGRect(x: panelX, y: panelY, width: panelW, height: panelH),
                               cornerSize: CGSize(width: 6, height: 6))
        ctx.fill(panelBg, with: .color(Color.black.opacity(0.70)))
        ctx.stroke(panelBg, with: .color(Color(red: 0.3, green: 0.75, blue: 0.4).opacity(0.55)), lineWidth: 0.8)

        // #78 Hole label
        ctx.draw(Text("HOLE \(currentHole)")
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .foregroundStyle(Color(red: 0.6, green: 0.9, blue: 0.6)),
                 at: CGPoint(x: panelX + panelW / 2, y: panelY + 10), anchor: .center)

        // #79 Divider line
        var divider = Path()
        divider.move(to: CGPoint(x: panelX + 4, y: panelY + 18))
        divider.addLine(to: CGPoint(x: panelX + panelW - 4, y: panelY + 18))
        ctx.stroke(divider, with: .color(Color.white.opacity(0.15)), lineWidth: 0.6)

        // Strokes row
        ctx.draw(Text("SHOT")
            .font(.system(size: 6, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.55)),
                 at: CGPoint(x: panelX + 14, y: panelY + 28), anchor: .center)
        ctx.draw(Text("\(currentStrokes)")
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundStyle(.white),
                 at: CGPoint(x: panelX + 14, y: panelY + 42), anchor: .center)

        // #80 Total running score
        let svp = totalStrokes - (holeResults.count * parPerHole)
        let totalLabel = svp == 0 ? "E" : (svp > 0 ? "+\(svp)" : "\(svp)")
        let totalColor: Color = svp < 0 ? Color(red: 0.3, green: 0.9, blue: 0.4) : (svp == 0 ? .white : .red)
        ctx.draw(Text("TOT")
            .font(.system(size: 6, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.55)),
                 at: CGPoint(x: panelX + panelW - 22, y: panelY + 28), anchor: .center)
        ctx.draw(Text(totalLabel)
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundStyle(totalColor),
                 at: CGPoint(x: panelX + panelW - 22, y: panelY + 42), anchor: .center)
    }

    // MARK: - #81–#82 Wind Dial

    private func drawWindDial(_ ctx: inout GraphicsContext) {
        let dialX: CGFloat = 8 + 40
        let dialY: CGFloat = 92
        let dialR: CGFloat = 18

        // #81 Wind dial background circle
        ctx.fill(Path(ellipseIn: CGRect(x: dialX - dialR, y: dialY - dialR, width: dialR * 2, height: dialR * 2)),
                 with: .color(Color.black.opacity(0.65)))
        ctx.stroke(Path(ellipseIn: CGRect(x: dialX - dialR, y: dialY - dialR, width: dialR * 2, height: dialR * 2)),
                   with: .color(Color.cyan.opacity(0.45)), lineWidth: 0.8)

        // #82 Wind arrow on dial
        let wr = windAngle * .pi / 180.0
        let arrowTip = CGPoint(x: dialX + (dialR - 4) * CGFloat(cos(wr)),
                               y: dialY + (dialR - 4) * CGFloat(sin(wr)))
        var windArrow = Path()
        windArrow.move(to: CGPoint(x: dialX - 4 * CGFloat(cos(wr)), y: dialY - 4 * CGFloat(sin(wr))))
        windArrow.addLine(to: arrowTip)
        ctx.stroke(windArrow, with: .color(Color.cyan.opacity(0.85)), lineWidth: 1.5)
        // Speed label
        ctx.draw(Text("\(Int(windSpeed))").font(.system(size: 6, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.cyan.opacity(0.80)),
                 at: CGPoint(x: dialX, y: dialY + dialR + 7), anchor: .center)
        // "W" label
        ctx.draw(Text("W").font(.system(size: 5, weight: .black, design: .monospaced))
            .foregroundStyle(Color.cyan.opacity(0.55)),
                 at: CGPoint(x: dialX, y: dialY - dialR - 5), anchor: .center)
    }

    // MARK: - #83 Club Selection Display

    private func drawClubDisplay(_ ctx: inout GraphicsContext) {
        // #83 Club label inset (bottom left area)
        let cdX: CGFloat = 8
        let cdY: CGFloat = H - 48
        var clubBg = Path()
        clubBg.addRoundedRect(in: CGRect(x: cdX, y: cdY, width: 76, height: 22),
                              cornerSize: CGSize(width: 5, height: 5))
        ctx.fill(clubBg, with: .color(Color.black.opacity(0.62)))
        ctx.stroke(clubBg, with: .color(Color(red: 0.8, green: 0.7, blue: 0.3).opacity(0.50)), lineWidth: 0.7)
        ctx.draw(Text("♦ \(shotTypeLabel)")
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.45)),
                 at: CGPoint(x: cdX + 38, y: cdY + 11), anchor: .center)
    }

    // MARK: - #84 Distance Ring Meter

    private func drawDistanceRing(_ ctx: inout GraphicsContext) {
        // #84 Semi-circular distance meter in bottom center
        let meterCX = W / 2
        let meterCY = H - 28
        let meterR: CGFloat = 22
        let arcStart: Double = .pi * 1.15
        let arcEnd: Double = .pi * 1.85

        // Background arc
        var bgArc = Path()
        bgArc.addArc(center: CGPoint(x: meterCX, y: meterCY),
                     radius: meterR,
                     startAngle: .radians(arcStart),
                     endAngle: .radians(arcEnd),
                     clockwise: false)
        ctx.stroke(bgArc, with: .color(Color.white.opacity(0.18)), lineWidth: 5)

        // Distance from ball to hole (normalized)
        let dxN = ballX - Double(holePosition.x)
        let dyN = ballY - Double(holePosition.y)
        let distNorm = min(1.0, sqrt(dxN * dxN + dyN * dyN) / 0.9)
        let fillEnd = arcStart + (arcEnd - arcStart) * (1.0 - distNorm)

        // Fill arc
        var fillArc = Path()
        fillArc.addArc(center: CGPoint(x: meterCX, y: meterCY),
                       radius: meterR,
                       startAngle: .radians(arcStart),
                       endAngle: .radians(fillEnd),
                       clockwise: false)
        ctx.stroke(fillArc, with: .color(Color(red: 0.30, green: 0.88, blue: 0.42).opacity(0.80)), lineWidth: 5)

        // Distance yards label (approximate)
        let yardsApprox = Int(distNorm * 350)
        ctx.draw(Text("\(yardsApprox)y")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.70)),
                 at: CGPoint(x: meterCX, y: meterCY + 6), anchor: .center)
    }

    // MARK: - Helpers

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}

// MARK: - GolfGameView

struct GolfGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // MARK: Game state
    @State private var phase: GolfPhase = .ready
    @State private var currentHole: Int = 1
    @State private var currentStrokes: Int = 0
    @State private var totalStrokes: Int = 0
    @State private var holeResults: [GolfHoleResult] = []
    @State private var ballOnGreen: Bool = false
    @State private var shotState: ShotState = .idle

    // MARK: Shot mechanic
    @State private var aimAngle: Double = 0.0
    @State private var pullDistance: CGFloat = 0.0
    @State private var dragStartLocation: CGPoint = .zero

    // MARK: Ball position (normalized 0–1, origin bottom-left)
    @State private var ballX: Double = 0.5
    @State private var ballY: Double = 0.1

    // MARK: Ball animation arc
    @State private var ballProgress: Double = -1.0
    @State private var ballStartX: Double = 0.5
    @State private var ballStartY: Double = 0.1
    @State private var ballEndX: Double = 0.5
    @State private var ballEndY: Double = 0.5

    // MARK: Golfer
    @State private var golferPose: String = "address"

    // MARK: Hole layout
    @State private var holePosition: CGPoint = CGPoint(x: 0.5, y: 0.88)
    @State private var obstacles: [GolfObstacleLayout] = []

    // MARK: Feedback
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var penaltyText: String = ""
    @State private var showPenalty: Bool = false
    @State private var crowdExcitement: Double = 0.20

    // MARK: Hole transition
    @State private var showHoleCard: Bool = false
    @State private var holeCardText: String = ""
    @State private var holeCardColor: Color = .white

    // MARK: Environment & FX
    @State private var windAngle: Double = 45.0
    @State private var windSpeed: Double = 8.0
    @State private var windDirection: Double = 45.0   // alias kept in sync with windAngle
    @State private var shotsSinceWindChange: Int = 0   // wind updates every 2 shots
    @State private var showImpactFX: Bool = false
    @State private var impactFXType: String = "driver"
    @State private var currentShotType: ShotType = .driver
    @State private var shotTypeLabel: String = "DRIVER"

    // MARK: Club Selection (14 clubs)
    @State private var selectedClub: GolfClub = .driver
    @State private var showClubSelector: Bool = false
    @State private var recommendedClub: GolfClub = .driver

    // MARK: Shot Shape
    @State private var shotShape: ShotShape = .straight
    @State private var showShotShapeSelector: Bool = false

    // MARK: Spin Control
    @State private var appliedSpin: Spin = .neutral
    @State private var showSpinSelector: Bool = false

    // MARK: Green Reading
    @State private var greenSlope: CGVector = CGVector(dx: 0, dy: 0)
    @State private var slopeArrows: [GreenSlopeArrow] = []
    @State private var showGreenReading: Bool = false
    @State private var breakText: String = ""

    // MARK: Scorecard overlay between holes
    @State private var showFullScorecard: Bool = false

    // MARK: Rewards
    @State private var rewardGranted: Bool = false
    // AI opponent — live per-hole scoring
    @State private var aiHoleScores: [Int] = []
    @State private var aiTotalStrokes: Int = 0
    @State private var showingAiTurn: Bool = false
    @State private var aiShotResultText: String = ""
    private let XP_CAP = 500
    private let WIN_SHARDS = 50; private let DRAW_SHARDS = 25; private let LOSS_SHARDS = 15
    private let accentColor = Color(red: 0.3, green: 0.7, blue: 0.4)

    // MARK: Per-hole par from course card
    private var parPerHole: Int { courseCard[min(currentHole - 1, courseCard.count - 1)].par }
    private var totalPar: Int { courseCard.reduce(0) { $0 + $1.par } }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(colors: [Color(red: 0.02, green: 0.08, blue: 0.03), Theme.deepBlack],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Golf · Closest to Pin",
                    subtitle: "9 Holes · Par 3 Each · Drag to Aim & Shoot",
                    countdown: 3, accentColor: accentColor,
                    onComplete: { startHole() }
                )

            case .aiming:
                VStack(spacing: 0) {
                    holeHeader.padding(.top, 8)

                    ZStack {
                        GolfCourseCanvas(
                            ballX: ballX, ballY: ballY,
                            ballProgress: ballProgress,
                            ballStartX: ballStartX, ballStartY: ballStartY,
                            ballEndX: ballEndX, ballEndY: ballEndY,
                            holePosition: holePosition,
                            obstacles: obstacles,
                            aimAngle: aimAngle, pullDistance: pullDistance,
                            shotState: shotState, golferPose: golferPose,
                            crowdExcitement: crowdExcitement,
                            currentHole: currentHole,
                            currentStrokes: currentStrokes,
                            totalStrokes: totalStrokes,
                            parPerHole: parPerHole,
                            holeResults: holeResults,
                            windAngle: windAngle,
                            windSpeed: windSpeed,
                            showImpactFX: showImpactFX,
                            impactFXType: impactFXType,
                            shotTypeLabel: shotTypeLabel
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in onDragChanged(v) }
                                .onEnded   { v in onDragEnded(v) }
                        )

                        if showFeedback {
                            Text(feedbackText)
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .shadow(color: accentColor.opacity(0.7), radius: 14)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                        if showPenalty { penaltyOverlay }
                        if showHoleCard { holeCardOverlay }
                        if showingAiTurn { aiTurnOverlay }
                        if showClubSelector { clubSelectorOverlay }
                        if showGreenReading { greenReadingOverlay }
                        if showFullScorecard { fullScorecardOverlay }
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    controlPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                }

            case .result:
                let playerWon = totalStrokes < aiTotalStrokes
                let isDraw    = totalStrokes == aiTotalStrokes
                let scoreVsPar = totalStrokes - totalPar
                ResultScreen(
                    winner: playerWon ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: totalStrokes, p2Score: aiTotalStrokes,
                    title: "Golf · 9 Holes", accentColor: accentColor,
                    prqGain: playerWon ? 10 : (isDraw ? 4 : 2),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: scoreVsPar <= 0 ? "Under Par" : "Over Par",
                    modeAttributeValue: max(0, 1.0 - Double(abs(scoreVsPar)) / 18.0),
                    onReturn: { dismiss() }
                )
                .onAppear { grantShards(playerWon: playerWon, isDraw: isDraw) }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Hole Header

    private var holeHeader: some View {
        let hole = courseCard[min(currentHole - 1, courseCard.count - 1)]
        let svp  = totalStrokes - holeResults.reduce(0) { $0 + courseCard[min($1.hole - 1, courseCard.count - 1)].par }
        return VStack(spacing: 4) {
            HStack(spacing: 8) {
                compactStatCell(label: "HOLE",  value: "\(currentHole)")
                thinDivider
                compactStatCell(label: "PAR",   value: "\(hole.par)", color: accentColor)
                thinDivider
                compactStatCell(label: "YDS",   value: "\(hole.yardage)")
                thinDivider
                compactStatCell(label: "SHOTS", value: "\(currentStrokes)")
                thinDivider
                compactStatCell(label: "TOTAL",
                         value: svp == 0 ? "E" : (svp > 0 ? "+\(svp)" : "\(svp)"),
                         color: svp < 0 ? accentColor : (svp == 0 ? .white : .red))
            }
            // Hole description + difficulty badge
            HStack(spacing: 8) {
                Text(hole.description)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(hole.difficulty.uppercased())
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(hole.difficulty == "Easy" ? accentColor : (hole.difficulty == "Hard" ? .red : .orange))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.cardBackground))
            }
            .padding(.horizontal, 4)
            // Live leaderboard widget
            if aiTotalStrokes > 0 || !aiHoleScores.isEmpty {
                liveLeaderboard
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1)))
        .padding(.horizontal, 16)
    }

    private var liveLeaderboard: some View {
        let playerVsPar = totalStrokes - holeResults.reduce(0) { $0 + courseCard[min($1.hole - 1, courseCard.count - 1)].par }
        let aiPlayedPar = aiHoleScores.indices.reduce(0) { $0 + courseCard[min($1, courseCard.count - 1)].par }
        let aiVsPar = aiTotalStrokes - aiPlayedPar
        let playerStr = playerVsPar == 0 ? "E" : (playerVsPar > 0 ? "+\(playerVsPar)" : "\(playerVsPar)")
        let aiStr     = aiVsPar == 0 ? "E" : (aiVsPar > 0 ? "+\(aiVsPar)" : "\(aiVsPar)")
        return HStack(spacing: 0) {
            Text("YOU: ")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(playerStr)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(playerVsPar < 0 ? accentColor : (playerVsPar == 0 ? .white : .red))
            Text("  |  RIVAL: ")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(aiStr)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(aiVsPar < 0 ? accentColor : (aiVsPar == 0 ? .white : .red))
                .animation(.easeInOut(duration: 0.3), value: aiTotalStrokes)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func compactStatCell(label: String, value: String, color: Color = .white) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(1)
            Text(value).font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }.frame(maxWidth: .infinity)
    }

    private var thinDivider: some View {
        Rectangle().fill(Theme.cardBorder).frame(width: 1, height: 28)
    }

    private func statCell(label: String, value: String, color: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(2)
            Text(value).font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }.frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.cardBorder).frame(width: 1, height: 36)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 10) {
            // Row 1: Direction / Power / Club
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("DIRECTION")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    ZStack {
                        Circle().fill(Theme.cardBackground).frame(width: 52, height: 52)
                            .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
                        Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold))
                            .foregroundStyle(accentColor)
                            .rotationEffect(.degrees(aimAngle))
                            .animation(.interactiveSpring(response: 0.15), value: aimAngle)
                    }
                }

                VStack(spacing: 4) {
                    Text("POWER")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.cardBackground)
                                .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Theme.brandCyan, accentColor, .yellow],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(0, geo.size.width * powerRatio))
                                .animation(.interactiveSpring(response: 0.1), value: pullDistance)
                        }
                    }.frame(height: 14)
                    Text("\(Int(powerRatio * 100))%")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }.frame(maxWidth: .infinity)

                // Club selector button — opens club picker
                VStack(spacing: 4) {
                    Text("CLUB")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Button {
                        withAnimation(.spring(response: 0.3)) { showClubSelector.toggle() }
                        hapticSoft()
                    } label: {
                        VStack(spacing: 1) {
                            Text(selectedClub.shortName)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Text("\(selectedClub.baseYardage)y")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 52, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1)))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1)))

            // Row 2: Shot Shape + Spin selectors side by side
            HStack(spacing: 10) {
                shotShapeSelectorRow
                if selectedClub.supportsSpinControl {
                    Divider().frame(height: 36)
                    spinSelectorRow
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1)))

            // Row 3: Wind info + Green reading button (when close to pin)
            windInfoRow

            HStack {
                Image(systemName: "hand.draw.fill").font(.system(size: 10)).foregroundStyle(accentColor)
                Text("Drag to rotate aim · Pull back & release to shoot")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }

            if !holeResults.isEmpty { holeScoreSummary }
        }
    }

    private var powerRatio: CGFloat { min(1.0, pullDistance / 80.0) }

    // MARK: - Shot Shape Selector Row

    private var shotShapeSelectorRow: some View {
        HStack(spacing: 6) {
            Text("SHAPE")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            ForEach(ShotShape.allCases, id: \.rawValue) { shape in
                Button {
                    shotShape = shape
                    hapticSoft()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: shape.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(shape.rawValue)
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(shotShape == shape ? Color(red: 0.95, green: 0.85, blue: 0.45) : .secondary)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(shotShape == shape ? Theme.cardBackground : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(shotShape == shape ? Theme.cardBorder : Color.clear, lineWidth: 1)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Spin Selector Row

    private var spinSelectorRow: some View {
        HStack(spacing: 6) {
            Text("SPIN")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
            ForEach(Spin.allCases, id: \.rawValue) { spin in
                Button {
                    appliedSpin = spin
                    hapticSoft()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: spin.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(spin.rawValue)
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(appliedSpin == spin ? Theme.brandCyan : .secondary)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(appliedSpin == spin ? Theme.cardBackground : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(appliedSpin == spin ? Theme.brandCyan.opacity(0.5) : Color.clear, lineWidth: 1)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Wind Info Row

    private var windInfoRow: some View {
        HStack(spacing: 12) {
            // Wind compass
            VStack(spacing: 2) {
                Text("WIND")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                        .rotationEffect(.degrees(windAngle))
                    Text("\(Int(windSpeed)) mph")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                Text(windDirectionLabel)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 36)

            // Drift impact warning
            let drift = windSpeed * sin(windAngle * .pi / 180.0) * 0.8
            VStack(spacing: 2) {
                Text("DRIFT")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(drift > 0 ? "+\(Int(abs(drift)))y R" : (abs(drift) < 0.5 ? "NONE" : "-\(Int(abs(drift)))y L"))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(abs(drift) > 3 ? .orange : .white)
            }

            Spacer()

            // Green reading button (appears when within putting range)
            if showGreenReading {
                Button {
                    withAnimation(.spring(response: 0.3)) { showGreenReading.toggle() }
                    hapticSoft()
                } label: {
                    Label("READ GREEN", systemImage: "arrow.triangle.branch")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accentColor.opacity(0.4), lineWidth: 1)))
                }
            }

            // Scorecard button
            Button {
                withAnimation(.spring(response: 0.3)) { showFullScorecard.toggle() }
                hapticSoft()
            } label: {
                Image(systemName: "tablecells")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1)))
    }

    private var windDirectionLabel: String {
        let normalized = ((windAngle.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        switch normalized {
        case 0..<22.5, 337.5...360: return "N"
        case 22.5..<67.5:   return "NE"
        case 67.5..<112.5:  return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default:             return "N"
        }
    }

    // MARK: - Club Cycling (legacy — kept for backward compat, full picker preferred)

    private func cycleShotType() {
        let clubs = GolfClub.allCases
        let idx = clubs.firstIndex(of: selectedClub) ?? 0
        selectedClub = clubs[(idx + 1) % clubs.count]
        shotTypeLabel = selectedClub.rawValue
        switch selectedClub {
        case .driver, .threeWood, .fiveWood, .hybridFour:
            currentShotType = .driver
        case .fourIron, .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron:
            currentShotType = .iron
        case .pitchingWedge, .sandWedge, .lobWedge:
            currentShotType = .wedge
        case .putter:
            currentShotType = .putt
        }
        if !selectedClub.supportsSpinControl { appliedSpin = .neutral }
        hapticSoft()
    }

    // MARK: - Hole Score Summary

    private var holeScoreSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(holeResults, id: \.hole) { r in
                    let hPar = courseCard[min(r.hole - 1, courseCard.count - 1)].par
                    let svp  = r.strokes - hPar
                    VStack(spacing: 2) {
                        Text("H\(r.hole)").font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("P\(hPar)").font(.system(size: 6, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("\(r.strokes)").font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(scoreSymbol(svp))
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(scoreColor(svp))
                    }
                    .padding(.horizontal, 5).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.cardBackground.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(scoreColor(svp).opacity(0.4), lineWidth: 1)))
                }
            }.padding(.horizontal, 4)
        }
    }

    private func scoreSymbol(_ vsPar: Int) -> String {
        switch vsPar {
        case ..<(-2): return "ALB"
        case -2:      return "EGL"
        case -1:      return "BRD"
        case 0:       return "PAR"
        case 1:       return "BOG"
        case 2:       return "DBL"
        default:      return "+\(vsPar)"
        }
    }
    private func scoreColor(_ vsPar: Int) -> Color {
        switch vsPar {
        case ..<(-1): return Color(red: 1.0, green: 0.85, blue: 0.20)
        case -1:      return accentColor
        case 0:       return .white
        case 1:       return .orange
        default:      return .red
        }
    }

    // MARK: - Overlays

    private var penaltyOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 28)).foregroundStyle(.orange)
            Text(penaltyText).font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white).multilineTextAlignment(.center)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.5), lineWidth: 1)))
        .shadow(color: .black.opacity(0.4), radius: 20)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private var holeCardOverlay: some View {
        let holeIdx = min((holeResults.last?.hole ?? currentHole) - 1, courseCard.count - 1)
        let holePar = courseCard[holeIdx].par
        return VStack(spacing: 12) {
            Text("HOLE \(holeResults.last?.hole ?? currentHole) COMPLETE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(3)
            Text(holeCardText).font(.system(size: 32, weight: .black)).italic()
                .foregroundStyle(holeCardColor).shadow(color: holeCardColor.opacity(0.5), radius: 16)
            if let last = holeResults.last {
                let svp = last.scoreVsPar
                HStack(spacing: 8) {
                    Text("\(last.strokes) strokes · Par \(holePar)")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    Text(svp == 0 ? "EVEN" : (svp > 0 ? "+\(svp)" : "\(svp)"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(svp < 0 ? accentColor : (svp == 0 ? .white : .red))
                }
            }
            // Running total vs par
            let runningPar = holeResults.reduce(0) { $0 + courseCard[min($1.hole - 1, courseCard.count - 1)].par }
            let runningTotal = totalStrokes
            let runSvp = runningTotal - runningPar
            HStack(spacing: 4) {
                Text("RUNNING TOTAL:").font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
                Text(runSvp == 0 ? "EVEN" : (runSvp > 0 ? "+\(runSvp)" : "\(runSvp)"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(runSvp < 0 ? accentColor : (runSvp == 0 ? .white : .red))
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground.opacity(0.95))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(holeCardColor.opacity(0.3), lineWidth: 1)))
        .shadow(color: .black.opacity(0.5), radius: 24)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    // MARK: - AI Turn Overlay

    private var aiTurnOverlay: some View {
        let (labelColor, bgBorder): (Color, Color) = {
            if aiShotResultText.contains("EAGLE") { return (accentColor, accentColor.opacity(0.4)) }
            if aiShotResultText.contains("BIRDIE") { return (Theme.brandCyan, Theme.brandCyan.opacity(0.4)) }
            if aiShotResultText.contains("BOGEY") { return (.orange, Color.orange.opacity(0.4)) }
            return (.white, Color.white.opacity(0.2))
        }()
        return VStack(spacing: 10) {
            Text("RIVAL'S TURN")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary).tracking(3)
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.red.opacity(0.85))
            if !aiShotResultText.isEmpty {
                Text(aiShotResultText)
                    .font(.system(size: 26, weight: .black, design: .monospaced)).italic()
                    .foregroundStyle(labelColor)
                    .shadow(color: labelColor.opacity(0.6), radius: 12)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                Text("Calculating…")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground.opacity(0.95))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(bgBorder, lineWidth: 1)))
        .shadow(color: .black.opacity(0.5), radius: 24)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: aiShotResultText)
    }

    // MARK: - Club Selector Overlay (14 clubs wheel/list)

    private var clubSelectorOverlay: some View {
        let distToHole: Int = {
            let dx = ballX - Double(holePosition.x)
            let dy = ballY - Double(holePosition.y)
            return Int(sqrt(dx * dx + dy * dy) * 350)
        }()
        let recClub = GolfClub.recommended(forYards: distToHole)
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { withAnimation { showClubSelector = false } }
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SELECT CLUB")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("~\(distToHole)y to pin")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button { withAnimation { showClubSelector = false } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }.padding(.leading, 8)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

                Divider().background(Theme.cardBorder)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(GolfClub.allCases) { club in
                            Button {
                                selectedClub = club
                                shotTypeLabel = club.rawValue
                                // Update legacy ShotType for FX
                                switch club {
                                case .driver, .threeWood, .fiveWood, .hybridFour:
                                    currentShotType = .driver
                                case .fourIron, .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron:
                                    currentShotType = .iron
                                case .pitchingWedge, .sandWedge, .lobWedge:
                                    currentShotType = .wedge
                                case .putter:
                                    currentShotType = .putt
                                }
                                // Reset spin when changing club
                                if !club.supportsSpinControl { appliedSpin = .neutral }
                                withAnimation { showClubSelector = false }
                                hapticSoft()
                            } label: {
                                HStack(spacing: 12) {
                                    // Club short name badge
                                    Text(club.shortName)
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundStyle(selectedClub == club ? Theme.deepBlack : Color(red: 0.95, green: 0.85, blue: 0.45))
                                        .frame(width: 36, height: 28)
                                        .background(RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedClub == club ? Color(red: 0.95, green: 0.85, blue: 0.45) : Theme.cardBackground))

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(club.rawValue)
                                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                                .foregroundStyle(selectedClub == club ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                                            if club == recClub {
                                                Text("RECOMMENDED")
                                                    .font(.system(size: 6, weight: .black, design: .monospaced))
                                                    .foregroundStyle(.black)
                                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                                    .background(Capsule().fill(accentColor))
                                            }
                                        }
                                        Text(club.distanceRange)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    // Loft angle indicator
                                    VStack(spacing: 1) {
                                        Text("\(Int(club.launchAngle))°")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text("LOFT")
                                            .font(.system(size: 6, design: .monospaced))
                                            .foregroundStyle(.secondary.opacity(0.7))
                                    }

                                    if selectedClub == club {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(accentColor)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedClub == club ? Theme.cardBackground.opacity(1.0) : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedClub == club ? Theme.cardBorder : Color.clear, lineWidth: 1)))
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                }
                .frame(maxHeight: 380)
            }
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground.opacity(0.97))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1)))
            .shadow(color: .black.opacity(0.5), radius: 24)
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Green Reading Overlay

    private var greenReadingOverlay: some View {
        VStack(spacing: 12) {
            Text("GREEN READING")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor).tracking(3)

            // Break text
            Text(breakText.isEmpty ? "FLAT GREEN" : breakText)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Slope visualization
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2
                // Draw green circle
                let greenPath = Path(ellipseIn: CGRect(x: cx - 48, y: cy - 32, width: 96, height: 64))
                ctx.fill(greenPath, with: .color(Color(red: 0.22, green: 0.62, blue: 0.24).opacity(0.6)))
                ctx.stroke(greenPath, with: .color(Color(red: 0.20, green: 0.56, blue: 0.22)), lineWidth: 1.2)
                // Draw slope arrows
                for arrow in slopeArrows {
                    let ax = cx - 48 + arrow.position.x * 96
                    let ay = cy - 32 + arrow.position.y * 64
                    let angleR = arrow.angle * .pi / 180.0
                    let len: CGFloat = 14 * CGFloat(arrow.strength)
                    let ex = ax + len * CGFloat(cos(angleR))
                    let ey = ay + len * CGFloat(sin(angleR))
                    var arrowPath = Path()
                    arrowPath.move(to: CGPoint(x: ax, y: ay))
                    arrowPath.addLine(to: CGPoint(x: ex, y: ey))
                    ctx.stroke(arrowPath, with: .color(Color.cyan.opacity(0.7 * arrow.strength + 0.2)), lineWidth: 1.5)
                    // Arrowhead
                    let hAngle1 = angleR + 2.4
                    let hAngle2 = angleR - 2.4
                    var head = Path()
                    head.move(to: CGPoint(x: ex, y: ey))
                    head.addLine(to: CGPoint(x: ex + 5 * CGFloat(cos(hAngle1)), y: ey + 5 * CGFloat(sin(hAngle1))))
                    head.move(to: CGPoint(x: ex, y: ey))
                    head.addLine(to: CGPoint(x: ex + 5 * CGFloat(cos(hAngle2)), y: ey + 5 * CGFloat(sin(hAngle2))))
                    ctx.stroke(head, with: .color(Color.cyan.opacity(0.8)), lineWidth: 1.2)
                }
                // Cup marker
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10)),
                         with: .color(.black.opacity(0.88)))
            }
            .frame(width: 180, height: 120)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.16, green: 0.42, blue: 0.18).opacity(0.3)))

            // Slope magnitude
            let slopeMag = sqrt(greenSlope.dx * greenSlope.dx + greenSlope.dy * greenSlope.dy)
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("SLOPE")
                        .font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", slopeMag * 100))
                        .font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.white)
                }
                VStack(spacing: 2) {
                    Text("GRAIN")
                        .font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
                    Text(greenSlope.dy > 0 ? "DOWNGRAIN" : "UPGRAIN")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(greenSlope.dy > 0 ? .orange : accentColor)
                }
            }

            Button { withAnimation { showGreenReading = false } } label: {
                Text("DISMISS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground.opacity(0.97))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(accentColor.opacity(0.3), lineWidth: 1)))
        .shadow(color: .black.opacity(0.5), radius: 24)
        .padding(.horizontal, 30)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    // MARK: - Full Scorecard Overlay

    private var fullScorecardOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { withAnimation { showFullScorecard = false } }
            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("SCORECARD")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                    Spacer()
                    Button { withAnimation { showFullScorecard = false } } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                Divider().background(Theme.cardBorder)

                // Column headers
                HStack(spacing: 0) {
                    Text("HOLE").frame(width: 40, alignment: .leading)
                    Text("PAR").frame(width: 32, alignment: .center)
                    Text("YDS").frame(width: 44, alignment: .center)
                    Text("SCORE").frame(width: 44, alignment: .center)
                    Text("+/-").frame(width: 40, alignment: .center)
                }
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 6)

                Divider().background(Theme.cardBorder.opacity(0.5))

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(courseCard, id: \.number) { hole in
                            let result = holeResults.first(where: { $0.hole == hole.number })
                            let isCurrentHole = hole.number == currentHole
                            HStack(spacing: 0) {
                                Text("\(hole.number)").frame(width: 40, alignment: .leading)
                                    .foregroundStyle(isCurrentHole ? accentColor : .white)
                                Text("\(hole.par)").frame(width: 32, alignment: .center)
                                    .foregroundStyle(.secondary)
                                Text("\(hole.yardage)").frame(width: 44, alignment: .center)
                                    .foregroundStyle(.secondary)
                                if let r = result {
                                    Text("\(r.strokes)").frame(width: 44, alignment: .center)
                                        .foregroundStyle(.white)
                                    let svp = r.scoreVsPar
                                    Text(svp == 0 ? "E" : (svp > 0 ? "+\(svp)" : "\(svp)"))
                                        .frame(width: 40, alignment: .center)
                                        .foregroundStyle(svp < 0 ? accentColor : (svp == 0 ? .white : .red))
                                } else if isCurrentHole {
                                    Text("–").frame(width: 44, alignment: .center).foregroundStyle(accentColor)
                                    Text("NOW").frame(width: 40, alignment: .center).foregroundStyle(accentColor)
                                } else {
                                    Text("–").frame(width: 44, alignment: .center).foregroundStyle(.secondary.opacity(0.4))
                                    Text("–").frame(width: 40, alignment: .center).foregroundStyle(.secondary.opacity(0.4))
                                }
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(isCurrentHole ? accentColor.opacity(0.08) : Color.clear)
                            if hole.number != 9 { Divider().background(Theme.cardBorder.opacity(0.3)) }
                        }
                    }
                }
                .frame(maxHeight: 340)

                Divider().background(Theme.cardBorder)

                // Total row
                let completedPar    = holeResults.reduce(0) { $0 + courseCard[min($1.hole - 1, courseCard.count - 1)].par }
                let completedShots  = totalStrokes
                let completedSvp    = completedShots - completedPar
                HStack(spacing: 0) {
                    Text("TOTAL").frame(width: 40, alignment: .leading).foregroundStyle(.white)
                    Text("\(completedPar)").frame(width: 32, alignment: .center).foregroundStyle(accentColor)
                    Text("–").frame(width: 44, alignment: .center).foregroundStyle(.secondary)
                    Text("\(completedShots)").frame(width: 44, alignment: .center).foregroundStyle(.white)
                    Text(completedSvp == 0 ? "E" : (completedSvp > 0 ? "+\(completedSvp)" : "\(completedSvp)"))
                        .frame(width: 40, alignment: .center)
                        .foregroundStyle(completedSvp < 0 ? accentColor : (completedSvp == 0 ? .white : .red))
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground.opacity(0.97))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1)))
            .shadow(color: .black.opacity(0.5), radius: 24)
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Drag Gesture

    private func onDragChanged(_ v: DragGesture.Value) {
        guard shotState == .idle || shotState == .aiming || shotState == .draggingBack else { return }
        if shotState == .idle {
            dragStartLocation = v.startLocation
            shotState = .aiming
        }
        let dx = v.location.x - dragStartLocation.x
        let dy = v.location.y - dragStartLocation.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist > 8 {
            shotState = .draggingBack
            aimAngle  = atan2(dx, -dy) * 180.0 / .pi
            pullDistance = min(80, dist * 0.7)
        }
    }

    private func onDragEnded(_ v: DragGesture.Value) {
        guard shotState == .draggingBack || shotState == .aiming else {
            shotState = .idle; return
        }
        let power = Double(pullDistance / 80.0)
        fireShot(power: power)
    }

    // MARK: - Shot Logic

    private func fireShot(power: Double) {
        guard shotState != .ballFlying, !ballOnGreen else { return }
        shotState = .ballFlying
        currentStrokes += 1

        // Determine shot type for haptics and FX
        let isLongShot = power > 0.7
        let distToHole: Double = {
            let dx = ballX - Double(holePosition.x)
            let dy = ballY - Double(holePosition.y)
            return sqrt(dx * dx + dy * dy)
        }()
        let isOnGreenApproach = distToHole < 0.15

        // Select haptic based on shot type
        if isOnGreenApproach {
            // Putt haptic — #HAPTIC-SOFT
            hapticSoft()
        } else if currentShotType == .driver && isLongShot {
            // Heavy haptic fires on impact below — no pre-fire here
        } else {
            // Medium for iron/approach — #HAPTIC-MEDIUM
            hapticMedium()
        }

        let radians = aimAngle * .pi / 180.0

        // ── Wind drift applied to landing position ──
        // landingDrift = windSpeed * sin(windDirection) * 0.8  (normalized canvas units / ~250)
        let windDriftRaw = windSpeed * sin(windAngle * .pi / 180.0) * 0.8
        let windDriftNorm = windDriftRaw / 250.0

        // ── Shot shape lateral bias ──
        let shapeLateral = shotShape.lateralBias
        let shapeDistMult = shotShape.distanceMultiplier

        // ── Spin roll modifier (applied along shot direction) ──
        let spinRollMod = selectedClub.supportsSpinControl ? appliedSpin.rollModifier : 0.0

        // ── Mishit random scatter based on club mishit penalty ──
        let mishitScatter = Double.random(in: -selectedClub.mishitPenalty...selectedClub.mishitPenalty)

        let dist = 0.55 * power * shapeDistMult + spinRollMod
        // Perpendicular (lateral) offset direction
        let perpRadians = radians + .pi / 2.0
        let lateralOffset = (windDriftNorm + shapeLateral + mishitScatter) * 0.55
        let newBallX = clamp(ballX + sin(radians) * dist + cos(perpRadians) * lateralOffset, 0.05, 0.95)
        let newBallY = clamp(ballY + cos(radians) * dist + sin(perpRadians) * lateralOffset, 0.05, 0.95)

        let hitObstacle = obstacles.first { obs in
            let oL = obs.position.x - obs.size.width  / 2
            let oR = obs.position.x + obs.size.width  / 2
            let oB = obs.position.y - obs.size.height / 2
            let oT = obs.position.y + obs.size.height / 2
            return newBallX >= oL && newBallX <= oR && newBallY >= oB && newBallY <= oT
        }

        ballStartX = ballX; ballStartY = ballY
        ballEndX   = newBallX; ballEndY = newBallY
        ballProgress = 0
        golferPose = "backswing"

        // ── Dynamic wind: changes every 2 shots with ±3mph and ±15° variation ──
        shotsSinceWindChange += 1
        if shotsSinceWindChange >= 2 {
            shotsSinceWindChange = 0
            windSpeed = clamp(windSpeed + Double.random(in: -3.0...3.0), 0, 25)
            windAngle = (windAngle + Double.random(in: -15.0...15.0)).truncatingRemainder(dividingBy: 360)
            if windAngle < 0 { windAngle += 360 }
            windDirection = windAngle
        }

        Task {
            try? await Task.sleep(nanoseconds: 40_000_000)
            await MainActor.run { golferPose = "impact" }

            // Full-driver heavy haptic on impact — #HAPTIC-HEAVY
            if currentShotType == .driver && isLongShot {
                hapticHeavy()
            }

            // Set impact FX type
            await MainActor.run {
                if let obs = hitObstacle {
                    impactFXType = obs.type == .water ? "water" : "bunker"
                } else if currentShotType == .driver {
                    impactFXType = "driver"
                } else if currentShotType == .iron {
                    impactFXType = "iron"
                } else {
                    impactFXType = "driver"
                }
                showImpactFX = true
            }

            let steps = 30
            for step in 0..<steps {
                try? await Task.sleep(nanoseconds: 14_000_000)
                await MainActor.run { ballProgress = Double(step + 1) / Double(steps) }
            }

            await MainActor.run {
                ballProgress = -1
                golferPose = "followthrough"
                showImpactFX = false
                if let obs = hitObstacle {
                    applyObstaclePenalty(obs)
                } else {
                    ballX = newBallX; ballY = newBallY
                    checkIfHoled()
                }
                pullDistance = 0
                shotState = .idle
            }

            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run { golferPose = "address" }
        }
    }

    private func applyObstaclePenalty(_ obs: GolfObstacleLayout) {
        currentStrokes += obs.type.strokePenalty
        if obs.type == .water {
            // Water hazard error haptic — #HAPTIC-ERROR
            hapticError()
            penaltyText = "Water Hazard!\n+\(obs.type.strokePenalty) Strokes · Ball Reset"
        } else {
            // Sand trap — medium haptic
            hapticMedium()
            ballX = ballEndX; ballY = ballEndY
            penaltyText = "Sand Trap!\n+\(obs.type.strokePenalty) Stroke"
        }
        withAnimation(.spring(response: 0.3)) { showPenalty = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            await MainActor.run { withAnimation { showPenalty = false } }
        }
    }

    private func checkIfHoled() {
        let dx = ballX - Double(holePosition.x)
        let dy = ballY - Double(holePosition.y)
        let dist = sqrt(dx * dx + dy * dy)

        // When ball reaches putting range (<0.18) show green reading hint
        if dist < 0.18 && !ballOnGreen {
            showGreenReading = true
        }

        if dist < 0.10 {
            ballOnGreen = true
            showGreenReading = false
            // Check for hole-in-one
            if currentStrokes == 1 {
                // Hole-in-one rigid haptic — #HAPTIC-RIGID
                hapticRigid()
                impactFXType = "holein"
                showImpactFX = true
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    await MainActor.run { showImpactFX = false }
                }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            recordHole()
        } else if currentStrokes >= parPerHole + 3 {
            ballOnGreen = true
            showGreenReading = false
            recordHole()
        }
    }

    private func recordHole() {
        let holePar    = courseCard[min(currentHole - 1, courseCard.count - 1)].par
        let scoreVsPar = currentStrokes - holePar
        let (name, color): (String, Color) = {
            switch scoreVsPar {
            case ..<(-2): return ("Albatross",     Color(red: 1.0, green: 0.85, blue: 0.20))
            case -2:      return ("Eagle",          accentColor)
            case -1:      return ("Birdie",         Theme.brandCyan)
            case 0:       return ("Par",            .white)
            case 1:       return ("Bogey",          .orange)
            case 2:       return ("Double Bogey",   .red)
            default:      return ("Triple Bogey+",  Color(red: 0.6, green: 0.0, blue: 0.0))
            }
        }()

        holeResults.append(GolfHoleResult(hole: currentHole, strokes: currentStrokes,
                                          scoreName: name, scoreVsPar: scoreVsPar))
        totalStrokes += currentStrokes
        holeCardText = name; holeCardColor = color
        if scoreVsPar < 0 { crowdExcitement = min(1.0, crowdExcitement + 0.3) }

        withAnimation(.spring(response: 0.3)) { showHoleCard = true }
        Task {
            try? await Task.sleep(for: .milliseconds(2200))
            await MainActor.run {
                withAnimation { showHoleCard = false }
                showingAiTurn = true
                playAiHole()
            }
        }
    }

    private func playAiHole() {
        let holePar = courseCard[min(currentHole - 1, courseCard.count - 1)].par
        // Weighted random: bogey 30%, par 50%, birdie 15%, eagle 5%
        // Holes 7-9: AI improves slightly (lower bogey chance)
        let isLateHole = currentHole >= 7
        let roll = Double.random(in: 0..<1)
        let aiScoreVsPar: Int
        if isLateHole {
            // Holes 7-9: bogey 20%, par 55%, birdie 20%, eagle 5%
            if roll < 0.05 { aiScoreVsPar = -2 }
            else if roll < 0.25 { aiScoreVsPar = -1 }
            else if roll < 0.80 { aiScoreVsPar = 0 }
            else { aiScoreVsPar = 1 }
        } else {
            if roll < 0.05 { aiScoreVsPar = -2 }
            else if roll < 0.20 { aiScoreVsPar = -1 }
            else if roll < 0.70 { aiScoreVsPar = 0 }
            else { aiScoreVsPar = 1 }
        }
        let aiStrokes = holePar + aiScoreVsPar
        let (resultLabel, _): (String, Color) = {
            switch aiScoreVsPar {
            case -2: return ("EAGLE -2", accentColor)
            case -1: return ("BIRDIE -1", Theme.brandCyan)
            case 0:  return ("PAR", .white)
            default: return ("BOGEY +1", .orange)
            }
        }()
        aiShotResultText = ""
        Task {
            // Brief delay — rival is "calculating" shot
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) { aiShotResultText = resultLabel }
            }
            try? await Task.sleep(for: .milliseconds(1600))
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    aiHoleScores.append(aiStrokes)
                    aiTotalStrokes += aiStrokes
                }
                showingAiTurn = false
                aiShotResultText = ""
                if currentHole < 9 { advanceHole() } else {
                    GameResultService.saveResult(modeId: "golf", userScore: totalStrokes)
                    phase = .result
                }
            }
        }
    }

    private func advanceHole() {
        currentHole += 1; currentStrokes = 0; ballOnGreen = false
        ballX = 0.5; ballY = 0.1; ballProgress = -1
        aimAngle = 0; pullDistance = 0; shotState = .idle
        golferPose = "address"
        // Reset club to recommended for new hole (updated in generateHoleLayout)
        currentShotType = .driver
        selectedClub = .driver
        shotTypeLabel = "DRIVER"
        // Reset shot shape, spin, and green reading
        shotShape = .straight
        appliedSpin = .neutral
        showGreenReading = false
        showClubSelector = false
        showShotShapeSelector = false
        showSpinSelector = false
        generateHoleLayout()
    }

    private func startHole() { phase = .aiming; generateHoleLayout() }

    private func generateHoleLayout() {
        holePosition = CGPoint(x: Double.random(in: 0.25...0.75),
                               y: Double.random(in: 0.72...0.88))
        var newObs: [GolfObstacleLayout] = []
        let count = Int.random(in: 2...3)
        let types: [GolfObstacle] = count > 2 ? [.sandTrap, .water, .sandTrap] : [.sandTrap, .water]
        for (i, t) in types.prefix(count).enumerated() {
            newObs.append(GolfObstacleLayout(
                type: t,
                position: CGPoint(x: Double.random(in: 0.25...0.75),
                                  y: 0.30 + Double(i) * 0.18 + Double.random(in: -0.05...0.05)),
                size: CGSize(width: Double.random(in: 0.15...0.22),
                             height: Double.random(in: 0.08...0.12))
            ))
        }
        obstacles = newObs

        // ── Initialize wind for new hole (full random each hole) ──
        windSpeed     = Double.random(in: 0...25)
        windAngle     = Double.random(in: 0...360)
        windDirection = windAngle
        shotsSinceWindChange = 0

        // ── Green slope: random slope vector and break text ──
        let slopeDx = Double.random(in: -0.15...0.15)
        let slopeDy = Double.random(in: -0.15...0.15)
        greenSlope   = CGVector(dx: slopeDx, dy: slopeDy)
        generateSlopeArrows()
        updateBreakText()

        // ── Recommend club based on hole yardage and ball starting position ──
        let holeData = courseCard[min(currentHole - 1, courseCard.count - 1)]
        // Rough guess: ball starts at ~0.1 normalized which maps to ~0 yards → use full hole yardage
        recommendedClub = GolfClub.recommended(forYards: holeData.yardage)
    }

    private func generateSlopeArrows() {
        var arrows: [GreenSlopeArrow] = []
        let baseAngle = atan2(greenSlope.dy, greenSlope.dx) * 180.0 / .pi
        let slopeStrength = min(1.0, sqrt(greenSlope.dx * greenSlope.dx + greenSlope.dy * greenSlope.dy) / 0.15)
        // Place 4–5 arrows spread across the green
        let arrowPositions: [CGPoint] = [
            CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.25),
            CGPoint(x: 0.50, y: 0.50), CGPoint(x: 0.25, y: 0.75),
            CGPoint(x: 0.75, y: 0.75)
        ]
        let count = Int.random(in: 3...5)
        for i in 0..<count {
            let pos = arrowPositions[i % arrowPositions.count]
            let variation = Double.random(in: -10...10)
            arrows.append(GreenSlopeArrow(
                position: pos,
                angle: baseAngle + variation,
                strength: max(0.3, slopeStrength + Double.random(in: -0.15...0.15))
            ))
        }
        slopeArrows = arrows
    }

    private func updateBreakText() {
        let slopeMag = sqrt(greenSlope.dx * greenSlope.dx + greenSlope.dy * greenSlope.dy)
        let breakFeet = Int(slopeMag * 30)
        guard breakFeet > 0 else { breakText = "FLAT GREEN"; return }
        let lateral  = greenSlope.dx
        let vertical = greenSlope.dy
        var parts: [String] = []
        if abs(lateral) > 0.02  { parts.append(lateral < 0 ? "BREAK LEFT \(Int(abs(lateral) * 20))ft" : "BREAK RIGHT \(Int(abs(lateral) * 20))ft") }
        if abs(vertical) > 0.02 { parts.append(vertical > 0 ? "DOWNHILL \(Int(abs(vertical) * 20))ft" : "UPHILL \(Int(abs(vertical) * 20))ft") }
        breakText = parts.joined(separator: " · ")
    }

    // MARK: - Rewards

    private func grantShards(playerWon: Bool, isDraw: Bool) {
        guard !rewardGranted else { return }
        rewardGranted = true
        let earned = playerWon ? WIN_SHARDS : (isDraw ? DRAW_SHARDS : LOSS_SHARDS)
        viewModel.profile.evolutionShards += min(earned, XP_CAP)
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { max(lo, min(hi, v)) }
}
