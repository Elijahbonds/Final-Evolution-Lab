import SwiftUI
import UIKit

// MARK: - AvatarDemoView
// AAA console-grade biomechanics exercise demonstration view.
// Renders a full gym environment with animated skeleton figure,
// muscle group highlights, form coach overlays, and rep counter.

struct AvatarDemoView: View {
    // MARK: - Public Properties (preserved API)
    let category: Exercise.ExerciseCategory
    let amplitude: CGFloat

    // MARK: - Init (preserved from original)
    init(exercise: Exercise) {
        self.category = exercise.category
        self.amplitude = switch exercise.difficulty {
        case .foundation: 0.6
        case .flight: 0.8
        case .elite: 1.0
        }
    }

    init(trainingExercise: TrainingExercise) {
        self.category = trainingExercise.category
        self.amplitude = switch trainingExercise.progressionLevel {
        case 1: 0.6
        case 2: 0.8
        default: 1.0
        }
    }

    // MARK: - State
    @State private var repCount: Int = 0
    @State private var setCount: Int = 1
    @State private var exerciseIndex: Int = 0
    @State private var caloriesBurned: Double = 0
    @State private var prqPoints: Int = 0
    @State private var isResting: Bool = false
    @State private var restProgress: CGFloat = 0
    @State private var heartRate: Int = 72
    @State private var effortPercent: Int = 0
    @State private var lastRepPhase: Int = -1   // tracks phase crossing for haptic trigger
    @State private var personalBestReps: Int = 0

    // Timer fires at ~60fps for smooth animation logic
    private let animationTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    // Rep-cycle timer — fires once per exercise cycle duration
    private let repTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // Accumulated time for rep counting
    @State private var accumulatedTime: Double = 0
    @State private var lastRepTime: Double = 0

    // MARK: - Haptics
    private let feedbackMedium = UIImpactFeedbackGenerator(style: .medium)
    private let feedbackHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let feedbackRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let feedbackSoft = UIImpactFeedbackGenerator(style: .soft)

    // MARK: - Body
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let t = CGFloat(now.truncatingRemainder(dividingBy: exerciseCycleDuration) / exerciseCycleDuration)
                let tSmooth = smoothstep(t)

                // --- Layer 1: Gym environment background ---
                drawGymBackground(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 2: Rubberized floor with perspective grid ---
                drawFloor(ctx: ctx, size: size)

                // --- Layer 3: Equipment silhouettes ---
                drawGymEquipment(ctx: ctx, size: size)

                // --- Layer 4: Ambient gym lights ---
                drawGymLights(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 5: Wall mirror reflections ---
                drawMirrorReflection(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 6: Wall motivational text ---
                drawWallText(ctx: ctx, size: size)

                // --- Layer 7: Velocity trails (ghost frames) ---
                drawVelocityTrails(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 8: Muscle group highlights ---
                drawMuscleHighlights(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 9: Main avatar skeleton ---
                drawAvatarSkeleton(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 10: Force arrows on feet ---
                drawForceArrows(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 11: Form coach joint angle arcs ---
                drawFormCoachOverlay(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 12: Center of mass indicator ---
                drawCenterOfMass(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 13: Performance HUD ---
                drawPerformanceHUD(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 14: Phase label ---
                drawPhaseLabel(ctx: ctx, size: size, t: tSmooth)

                // --- Layer 15: Rest overlay (when between sets) ---
                if isResting {
                    drawRestOverlay(ctx: ctx, size: size, t: tSmooth)
                }
            }
        }
        .overlay(alignment: .bottom) {
            repCounterHUD
        }
        .overlay(alignment: .top) {
            setProgressBar
        }
        .onReceive(repTimer) { _ in
            updateRepCounter()
        }
        .onAppear {
            feedbackMedium.prepare()
            feedbackHeavy.prepare()
            feedbackRigid.prepare()
            feedbackSoft.prepare()
            heartRate = baseHeartRate
            effortPercent = baseEffort
        }
    }

    // MARK: - Rep Counter Logic
    private func updateRepCounter() {
        guard !isResting else { return }
        accumulatedTime += 0.05
        let cyclesCompleted = Int(accumulatedTime / exerciseCycleDuration)
        if cyclesCompleted > repCount {
            repCount = cyclesCompleted
            caloriesBurned += metFactor * 0.003
            prqPoints += 10

            // Haptic: rep complete
            feedbackMedium.impactOccurred()

            // Simulate heart rate drift upward
            heartRate = min(185, baseHeartRate + Int(Double(repCount) * 1.8))
            effortPercent = min(100, baseEffort + repCount * 3)

            // Every 10 reps: advance to next exercise variant, trigger set complete
            if repCount % 10 == 0 && repCount > 0 {
                if repCount > personalBestReps {
                    personalBestReps = repCount
                    feedbackRigid.impactOccurred() // personal best
                } else {
                    feedbackHeavy.impactOccurred() // set complete
                }
                setCount += 1
                exerciseIndex = (exerciseIndex + 1) % exerciseVariantCount

                // Trigger rest phase
                isResting = true
                restProgress = 0
                feedbackSoft.impactOccurred()
                startRestCountdown()
            }
        }
    }

    private func startRestCountdown() {
        let restDuration: Double = 3.0
        let steps = 60
        var step = 0
        Timer.scheduledTimer(withTimeInterval: restDuration / Double(steps), repeats: true) { timer in
            step += 1
            restProgress = CGFloat(step) / CGFloat(steps)
            if step >= steps {
                timer.invalidate()
                isResting = false
                feedbackMedium.impactOccurred()
            }
        }
    }

    // MARK: - Drawing: Gym Background
    private func drawGymBackground(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        // Deep dark gym gradient
        let gradRect = CGRect(origin: .zero, size: size)
        let bgGradient = Gradient(stops: [
            .init(color: Color(red: 0.03, green: 0.03, blue: 0.05), location: 0),
            .init(color: Color(red: 0.06, green: 0.05, blue: 0.08), location: 0.4),
            .init(color: Color(red: 0.04, green: 0.04, blue: 0.06), location: 0.75),
            .init(color: Color(red: 0.02, green: 0.02, blue: 0.03), location: 1.0)
        ])
        ctx.fill(
            Rectangle().path(in: gradRect),
            with: .linearGradient(bgGradient,
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height))
        )

        // Subtle vignette
        let vignette = Gradient(stops: [
            .init(color: Color.black.opacity(0.7), location: 0),
            .init(color: Color.clear, location: 0.5),
            .init(color: Color.black.opacity(0.5), location: 1.0)
        ])
        ctx.fill(
            Rectangle().path(in: gradRect),
            with: .radialGradient(vignette,
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: min(size.width, size.height) * 0.2,
                endRadius: min(size.width, size.height) * 0.8)
        )
    }

    // MARK: - Drawing: Rubberized Floor with Perspective Grid
    private func drawFloor(ctx: GraphicsContext, size: CGSize) {
        let floorY = size.height * 0.72
        let vp = CGPoint(x: size.width / 2, y: floorY * 0.45) // vanishing point

        // Floor base rubber surface
        let floorRect = CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)
        let floorGrad = Gradient(stops: [
            .init(color: Color(red: 0.12, green: 0.08, blue: 0.06), location: 0),
            .init(color: Color(red: 0.08, green: 0.05, blue: 0.04), location: 1)
        ])
        ctx.fill(Rectangle().path(in: floorRect),
                 with: .linearGradient(floorGrad,
                    startPoint: CGPoint(x: size.width / 2, y: floorY),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)))

        // Perspective grid lines converging to vanishing point
        let numVertical = 12
        let numHorizontal = 8
        let gridColor = Color(red: 0.3, green: 0.2, blue: 0.15).opacity(0.5)

        // Vertical lines (converge to vanishing point)
        for i in 0...numVertical {
            let xFrac = CGFloat(i) / CGFloat(numVertical)
            let bottomX = xFrac * size.width
            var path = Path()
            path.move(to: CGPoint(x: bottomX, y: size.height))
            path.addLine(to: vp)
            ctx.stroke(path, with: .color(gridColor), lineWidth: 0.6)
        }

        // Horizontal lines across the floor plane
        for i in 0...numHorizontal {
            let yFrac = CGFloat(i) / CGFloat(numHorizontal)
            let y = floorY + (size.height - floorY) * yFrac
            // Width narrows as y approaches vanishing point
            let widthFrac = (y - floorY) / (size.height - floorY)
            let halfW = size.width * 0.5 * (0.1 + 0.9 * widthFrac)
            var path = Path()
            path.move(to: CGPoint(x: size.width / 2 - halfW, y: y))
            path.addLine(to: CGPoint(x: size.width / 2 + halfW, y: y))
            ctx.stroke(path, with: .color(gridColor.opacity(Double(widthFrac) * 0.8)), lineWidth: 0.5)
        }

        // Floor edge highlight line
        var edgePath = Path()
        edgePath.move(to: CGPoint(x: 0, y: floorY))
        edgePath.addLine(to: CGPoint(x: size.width, y: floorY))
        ctx.stroke(edgePath, with: .color(Color(red: 0.5, green: 0.3, blue: 0.2).opacity(0.6)), lineWidth: 1.0)
    }

    // MARK: - Drawing: Gym Equipment Silhouettes
    private func drawGymEquipment(ctx: GraphicsContext, size: CGSize) {
        let floorY = size.height * 0.72
        let equipColor = Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.85)

        // 1. Bench (left side)
        drawBench(ctx: ctx, size: size, x: size.width * 0.12, floorY: floorY, color: equipColor)

        // 2. Barbell rack (far left background)
        drawBarbellRack(ctx: ctx, size: size, x: size.width * 0.04, floorY: floorY, color: equipColor)

        // 3. Pull-up bar (upper right)
        drawPullUpBar(ctx: ctx, size: size, x: size.width * 0.88, floorY: floorY, color: equipColor)

        // 4. Cable machine (right side)
        drawCableMachine(ctx: ctx, size: size, x: size.width * 0.92, floorY: floorY, color: equipColor)
    }

    private func drawBench(ctx: GraphicsContext, size: CGSize, x: CGFloat, floorY: CGFloat, color: Color) {
        let benchW: CGFloat = size.width * 0.09
        let benchH: CGFloat = size.height * 0.03
        let benchY = floorY - benchH - size.height * 0.005
        // Seat pad
        let seatRect = CGRect(x: x - benchW / 2, y: benchY, width: benchW, height: benchH * 0.6)
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in: seatRect), with: .color(color))
        // Legs
        for lx in [x - benchW * 0.35, x + benchW * 0.35] {
            var legPath = Path()
            legPath.move(to: CGPoint(x: lx, y: benchY + benchH * 0.5))
            legPath.addLine(to: CGPoint(x: lx - 3, y: floorY))
            legPath.addLine(to: CGPoint(x: lx + 3, y: floorY))
            ctx.fill(legPath, with: .color(color))
        }
    }

    private func drawBarbellRack(ctx: GraphicsContext, size: CGSize, x: CGFloat, floorY: CGFloat, color: Color) {
        let rackH = size.height * 0.28
        let rackW = size.width * 0.05
        let rackTop = floorY - rackH

        // Main uprights
        for side: CGFloat in [-1, 1] {
            var up = Path()
            let ux = x + side * rackW * 0.4
            up.move(to: CGPoint(x: ux - 2, y: floorY))
            up.addLine(to: CGPoint(x: ux - 2, y: rackTop))
            up.addLine(to: CGPoint(x: ux + 2, y: rackTop))
            up.addLine(to: CGPoint(x: ux + 2, y: floorY))
            ctx.fill(up, with: .color(color))
        }
        // Cross bar
        var crossBar = Path()
        crossBar.move(to: CGPoint(x: x - rackW * 0.45, y: rackTop + 4))
        crossBar.addLine(to: CGPoint(x: x + rackW * 0.45, y: rackTop + 4))
        ctx.stroke(crossBar, with: .color(color), lineWidth: 3)

        // Barbell on rack
        var barPath = Path()
        barPath.move(to: CGPoint(x: x - rackW * 1.8, y: rackTop + rackH * 0.25))
        barPath.addLine(to: CGPoint(x: x + rackW * 1.8, y: rackTop + rackH * 0.25))
        ctx.stroke(barPath, with: .color(color.opacity(0.7)), lineWidth: 2.5)

        // Weight plates
        for side: CGFloat in [-1, 1] {
            let plateX = x + side * rackW * 1.6
            let plateRect = CGRect(x: plateX - 4, y: rackTop + rackH * 0.22 - 7, width: 8, height: 14)
            ctx.fill(Ellipse().path(in: plateRect), with: .color(color.opacity(0.9)))
        }
    }

    private func drawPullUpBar(ctx: GraphicsContext, size: CGSize, x: CGFloat, floorY: CGFloat, color: Color) {
        let barH = size.height * 0.32
        let barY = floorY - barH

        // Vertical support posts
        for side: CGFloat in [-1, 1] {
            let px = x + side * size.width * 0.04
            var post = Path()
            post.move(to: CGPoint(x: px - 2, y: floorY))
            post.addLine(to: CGPoint(x: px - 2, y: barY))
            post.addLine(to: CGPoint(x: px + 2, y: barY))
            post.addLine(to: CGPoint(x: px + 2, y: floorY))
            ctx.fill(post, with: .color(color))
        }

        // Horizontal pull-up bar
        var bar = Path()
        bar.move(to: CGPoint(x: x - size.width * 0.055, y: barY))
        bar.addLine(to: CGPoint(x: x + size.width * 0.055, y: barY))
        ctx.stroke(bar, with: .color(color), lineWidth: 4)

        // Diagonal braces
        var brace1 = Path()
        brace1.move(to: CGPoint(x: x - size.width * 0.04, y: floorY - size.height * 0.05))
        brace1.addLine(to: CGPoint(x: x - size.width * 0.04, y: barY + size.height * 0.08))
        ctx.stroke(brace1, with: .color(color.opacity(0.6)), lineWidth: 1.5)

        var brace2 = Path()
        brace2.move(to: CGPoint(x: x + size.width * 0.04, y: floorY - size.height * 0.05))
        brace2.addLine(to: CGPoint(x: x + size.width * 0.04, y: barY + size.height * 0.08))
        ctx.stroke(brace2, with: .color(color.opacity(0.6)), lineWidth: 1.5)
    }

    private func drawCableMachine(ctx: GraphicsContext, size: CGSize, x: CGFloat, floorY: CGFloat, color: Color) {
        let machH = size.height * 0.38
        let machW = size.width * 0.06
        let top = floorY - machH

        // Body frame
        let bodyRect = CGRect(x: x - machW / 2, y: top, width: machW, height: machH)
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in: bodyRect), with: .color(color))

        // Weight stack
        let stackRect = CGRect(x: x - machW * 0.35, y: top + machH * 0.1, width: machW * 0.7, height: machH * 0.5)
        ctx.fill(RoundedRectangle(cornerRadius: 2).path(in: stackRect), with: .color(color.opacity(0.6)))

        // Cable groove lines on weight stack
        for i in 0..<4 {
            let lineY = stackRect.minY + stackRect.height * CGFloat(i) / 3
            var linePath = Path()
            linePath.move(to: CGPoint(x: stackRect.minX + 2, y: lineY))
            linePath.addLine(to: CGPoint(x: stackRect.maxX - 2, y: lineY))
            ctx.stroke(linePath, with: .color(Color.black.opacity(0.4)), lineWidth: 1)
        }

        // Pulley at top
        let pulleyRect = CGRect(x: x - 4, y: top - 4, width: 8, height: 8)
        ctx.fill(Circle().path(in: pulleyRect), with: .color(color.opacity(0.8)))

        // Cable line
        var cable = Path()
        cable.move(to: CGPoint(x: x, y: top))
        cable.addLine(to: CGPoint(x: x - machW, y: top + machH * 0.3))
        ctx.stroke(cable, with: .color(Color.gray.opacity(0.5)), lineWidth: 1)
    }

    // MARK: - Drawing: Gym Lights
    private func drawGymLights(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let lightPositions: [CGFloat] = [0.08, 0.22, 0.38, 0.62, 0.78, 0.92]
        let lightY = size.height * 0.06
        let flicker = 0.85 + 0.15 * sin(t * .pi * 7)

        for (idx, xFrac) in lightPositions.enumerated() {
            let lx = size.width * xFrac
            let flickerOffset = CGFloat(idx % 2) * 0.1
            let lightIntensity = flicker + flickerOffset * sin(t * .pi * 3 + CGFloat(idx))

            // Light housing
            let housingRect = CGRect(x: lx - 8, y: lightY - 4, width: 16, height: 8)
            ctx.fill(RoundedRectangle(cornerRadius: 2).path(in: housingRect),
                     with: .color(Color(red: 0.2, green: 0.2, blue: 0.22)))

            // Lamp glow
            var gc = ctx
            gc.addFilter(.blur(radius: 6))
            let glowRect = CGRect(x: lx - 10, y: lightY - 5, width: 20, height: 10)
            gc.fill(Ellipse().path(in: glowRect),
                    with: .color(Color(red: 1.0, green: 0.95, blue: 0.8).opacity(0.8 * lightIntensity)))

            // Cone beam
            let coneDepth = size.height * 0.55
            let coneHalfWidthBottom = size.width * 0.09
            var conePath = Path()
            conePath.move(to: CGPoint(x: lx - 4, y: lightY + 4))
            conePath.addLine(to: CGPoint(x: lx + 4, y: lightY + 4))
            conePath.addLine(to: CGPoint(x: lx + coneHalfWidthBottom, y: lightY + coneDepth))
            conePath.addLine(to: CGPoint(x: lx - coneHalfWidthBottom, y: lightY + coneDepth))
            conePath.closeSubpath()

            var coneCtx = ctx
            coneCtx.addFilter(.blur(radius: 18))
            let coneGrad = Gradient(stops: [
                .init(color: Color(red: 1.0, green: 0.97, blue: 0.85).opacity(0.12 * lightIntensity), location: 0),
                .init(color: Color.clear, location: 1.0)
            ])
            coneCtx.fill(conePath,
                         with: .linearGradient(coneGrad,
                            startPoint: CGPoint(x: lx, y: lightY),
                            endPoint: CGPoint(x: lx, y: lightY + coneDepth)))
        }
    }

    // MARK: - Drawing: Mirror Reflection
    private func drawMirrorReflection(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let cx = size.width / 2
        let cy = size.height / 2
        let scale = min(size.width, size.height) * 0.28

        let joints = computeJoints(category: category, cx: cx, cy: cy, scale: scale, t: t)

        // Left mirror (flipped horizontally, positioned far left)
        let mirrorOffsetX: CGFloat = -size.width * 0.35
        let mirrorOpacity = 0.12

        for bone in bones {
            guard let from = joints[bone.0], let to = joints[bone.1] else { continue }
            // Mirror: reflect X around center, then shift left
            let fromM = CGPoint(x: cx - (from.x - cx) + mirrorOffsetX, y: from.y)
            let toM = CGPoint(x: cx - (to.x - cx) + mirrorOffsetX, y: to.y)
            var path = Path()
            path.move(to: fromM)
            path.addLine(to: toM)
            ctx.stroke(path, with: .color(Theme.brandBlue.opacity(mirrorOpacity)), lineWidth: 1.5)
        }

        // Right mirror
        let mirrorOffsetXRight: CGFloat = size.width * 0.35
        for bone in bones {
            guard let from = joints[bone.0], let to = joints[bone.1] else { continue }
            let fromM = CGPoint(x: cx - (from.x - cx) + mirrorOffsetXRight, y: from.y)
            let toM = CGPoint(x: cx - (to.x - cx) + mirrorOffsetXRight, y: to.y)
            var path = Path()
            path.move(to: fromM)
            path.addLine(to: toM)
            ctx.stroke(path, with: .color(Theme.brandBlue.opacity(mirrorOpacity * 0.7)), lineWidth: 1.5)
        }
    }

    // MARK: - Drawing: Wall Motivational Text
    private func drawWallText(ctx: GraphicsContext, size: CGSize) {
        let textColor = Color(red: 0.18, green: 0.18, blue: 0.22).opacity(0.9)

        // "PUSH YOUR LIMITS" on upper left wall area
        var resolved1 = ctx.resolve(Text("PUSH YOUR LIMITS")
            .font(.system(size: size.width * 0.045, weight: .black, design: .rounded))
            .foregroundColor(textColor)
            .tracking(4))
        ctx.draw(resolved1, at: CGPoint(x: size.width * 0.25, y: size.height * 0.12), anchor: .center)

        // "FINAL EVOLUTION" on upper right
        var resolved2 = ctx.resolve(Text("FINAL EVOLUTION")
            .font(.system(size: size.width * 0.042, weight: .black, design: .rounded))
            .foregroundColor(Color(red: 0.0, green: 0.3, blue: 0.4).opacity(0.8))
            .tracking(4))
        ctx.draw(resolved2, at: CGPoint(x: size.width * 0.75, y: size.height * 0.12), anchor: .center)

        // Subtle line under text
        var line = Path()
        line.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.16))
        line.addLine(to: CGPoint(x: size.width * 0.95, y: size.height * 0.16))
        ctx.stroke(line, with: .color(Color(red: 0.15, green: 0.15, blue: 0.2).opacity(0.4)), lineWidth: 0.5)
    }

    // MARK: - Drawing: Velocity Trails (Ghost Frames)
    private func drawVelocityTrails(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let cx = size.width / 2
        let cy = size.height * 0.5
        let scale = min(size.width, size.height) * 0.32

        let trailOffsets: [(CGFloat, CGFloat)] = [(-0.15, 0.07), (-0.08, 0.12)]
        for (tOffset, opacity) in trailOffsets {
            let tTrail = max(0, min(1, t + tOffset))
            let tSmoothed = smoothstep(tTrail)
            let trailJoints = computeJoints(category: category, cx: cx, cy: cy, scale: scale, t: tSmoothed)
            for bone in bones {
                guard let from = trailJoints[bone.0], let to = trailJoints[bone.1] else { continue }
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                ctx.stroke(path, with: .color(muscleGlowColor.opacity(opacity)), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Drawing: Muscle Group Highlights
    private func drawMuscleHighlights(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let cx = size.width / 2
        let cy = size.height * 0.5
        let scale = min(size.width, size.height) * 0.32
        let joints = computeJoints(category: category, cx: cx, cy: cy, scale: scale, t: t)

        let pulse = 0.5 + 0.5 * sin(t * .pi * 2)
        let glowColor = muscleGlowColor

        var muscleJointGroups: [[String]] = []
        switch category {
        case .plyometric:
            // Quads + glutes (lower body)
            muscleJointGroups = [["lHip", "lKnee"], ["rHip", "rKnee"], ["spine", "lHip"], ["spine", "rHip"]]
        case .strength:
            // Chest + shoulders
            muscleJointGroups = [["lShoulder", "rShoulder"], ["lShoulder", "lElbow"], ["rShoulder", "rElbow"], ["neck", "lShoulder"], ["neck", "rShoulder"]]
        case .agility:
            // Calves + core
            muscleJointGroups = [["lKnee", "lAnkle"], ["rKnee", "rAnkle"], ["spine", "lHip"], ["spine", "rHip"]]
        case .mobility:
            // Back + hips
            muscleJointGroups = [["neck", "spine"], ["spine", "lHip"], ["spine", "rHip"], ["lElbow", "lWrist"], ["rElbow", "rWrist"]]
        case .recovery:
            // Full body soft glow — all bones
            muscleJointGroups = bones.map { [$0.0, $0.1] }
        }

        var glowCtx = ctx
        glowCtx.addFilter(.blur(radius: 12))
        for group in muscleJointGroups {
            guard group.count >= 2,
                  let from = joints[group[0]],
                  let to = joints[group[1]] else { continue }
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            glowCtx.stroke(path, with: .color(glowColor.opacity(0.55 + 0.35 * pulse)), lineWidth: 10)
        }
    }

    // MARK: - Drawing: Avatar Skeleton (thick capsule bones + joints)
    private func drawAvatarSkeleton(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let cx = size.width / 2
        let cy = size.height * 0.5
        let scale = min(size.width, size.height) * 0.32
        let joints = computeJoints(category: category, cx: cx, cy: cy, scale: scale, t: t)

        let pulse = 0.5 + 0.5 * sin(t * .pi * 2)

        // Draw bones as thick capsule shapes (overlapping ellipses along bone direction)
        for bone in bones {
            guard let from = joints[bone.0], let to = joints[bone.1] else { continue }
            drawCapsuleBone(ctx: ctx, from: from, to: to,
                            color: Theme.brandBlue, width: capsuleWidth(for: bone))
        }

        // Draw joints as circles with size variation by importance
        let jointImportance: [String: CGFloat] = [
            "head": 1.4,
            "lHip": 1.3, "rHip": 1.3,
            "lShoulder": 1.2, "rShoulder": 1.2,
            "lKnee": 1.1, "rKnee": 1.1,
            "neck": 1.0, "spine": 1.0,
            "lElbow": 0.9, "rElbow": 0.9,
            "lAnkle": 0.85, "rAnkle": 0.85,
            "lWrist": 0.8, "rWrist": 0.8
        ]

        for (name, point) in joints {
            let importance = jointImportance[name] ?? 1.0
            let baseRadius: CGFloat = name == "head" ? 9 : 5
            let r = baseRadius * importance

            // Glow halo
            var glowCtx = ctx
            glowCtx.addFilter(.blur(radius: 6))
            let glowR = r + 4 + pulse * 3
            let glowRect = CGRect(x: point.x - glowR, y: point.y - glowR, width: glowR * 2, height: glowR * 2)
            glowCtx.fill(Circle().path(in: glowRect),
                         with: .color(Theme.brandCyan.opacity(0.35)))

            // Outer ring
            let outerRect = CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)
            ctx.fill(Circle().path(in: outerRect), with: .color(Theme.brandCyan.opacity(0.6)))

            // Inner bright core
            let innerR = r * 0.55
            let innerRect = CGRect(x: point.x - innerR, y: point.y - innerR, width: innerR * 2, height: innerR * 2)
            ctx.fill(Circle().path(in: innerRect), with: .color(Color.white.opacity(0.9)))
        }
    }

    private func drawCapsuleBone(ctx: GraphicsContext, from: CGPoint, to: CGPoint,
                                  color: Color, width: CGFloat) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 1 else { return }

        // Draw the capsule as a filled path between two circles
        let nx = -dy / length * width / 2
        let ny = dx / length * width / 2

        var capsule = Path()
        capsule.move(to: CGPoint(x: from.x + nx, y: from.y + ny))
        capsule.addLine(to: CGPoint(x: to.x + nx, y: to.y + ny))
        // Rounded end at `to`
        capsule.addArc(center: to, radius: width / 2,
                       startAngle: .radians(atan2(Double(ny), Double(nx))),
                       endAngle: .radians(atan2(Double(-ny), Double(-nx))),
                       clockwise: false)
        capsule.addLine(to: CGPoint(x: from.x - nx, y: from.y - ny))
        // Rounded end at `from`
        capsule.addArc(center: from, radius: width / 2,
                       startAngle: .radians(atan2(Double(-ny), Double(-nx))),
                       endAngle: .radians(atan2(Double(ny), Double(nx))),
                       clockwise: false)
        capsule.closeSubpath()

        // Dark core fill
        ctx.fill(capsule, with: .color(color.opacity(0.2)))

        // Bright outline stroke
        ctx.stroke(capsule, with: .color(color.opacity(0.85)), lineWidth: 1.0)

        // Center highlight stripe
        var stripe = Path()
        stripe.move(to: CGPoint(x: from.x + nx * 0.3, y: from.y + ny * 0.3))
        stripe.addLine(to: CGPoint(x: to.x + nx * 0.3, y: to.y + ny * 0.3))
        ctx.stroke(stripe, with: .color(Color.white.opacity(0.25)), lineWidth: 1.0)
    }

    private func capsuleWidth(for bone: (String, String)) -> CGFloat {
        switch bone.0 {
        case "spine", "neck": return 6
        case "lHip", "rHip": return 7
        case "lShoulder", "rShoulder": return 6
        case "lKnee", "rKnee": return 5.5
        default: return 4.5
        }
    }

    // MARK: - Drawing: Force Arrows on Feet
    private func drawForceArrows(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let cx = size.width / 2
        let cy = size.height * 0.5
        let scale = min(size.width, size.height) * 0.32
        let joints = computeJoints(category: category, cx: cx, cy: cy, scale: scale, t: t)

        guard let lAnkle = joints["lAnkle"], let rAnkle = joints["rAnkle"] else { return }

        let forceColor = Color(red: 1.0, green: 0.8, blue: 0.0)
        // GRF magnitude scales with phase (peak at bottom of motion)
        let forceMag = scale * 0.15 * amplitude * (0.4 + 0.6 * abs(sin(t * .pi)))

        for ankle in [lAnkle, rAnkle] {
            let arrowTip = CGPoint(x: ankle.x, y: ankle.y + forceMag)
            let arrowBase = CGPoint(x: ankle.x, y: ankle.y + 4)

            // Shaft
            var shaft = Path()
            shaft.move(to: arrowBase)
            shaft.addLine(to: arrowTip)
            ctx.stroke(shaft, with: .color(forceColor.opacity(0.85)), lineWidth: 2)

            // Arrowhead (pointing down = ground reaction force pointing down into ground)
            let headSize: CGFloat = 6
            var head = Path()
            head.move(to: CGPoint(x: arrowTip.x, y: arrowTip.y + headSize))
            head.addLine(to: CGPoint(x: arrowTip.x - headSize * 0.5, y: arrowTip.y))
            head.addLine(to: CGPoint(x: arrowTip.x + headSize * 0.5, y: arrowTip.y))
            head.closeSubpath()
            ctx.fill(head, with: .color(forceColor.opacity(0.85)))

            // Glow
            var glowCtx = ctx
            glowCtx.addFilter(.blur(radius: 4))
            glowCtx.stroke(shaft, with: .color(forceColor.opacity(0.4)), lineWidth: 4)
        }
    }

    // MARK: - Drawing: Form Coach Overlay (joint angle arcs + badges)
    private func drawFormCoachOverlay(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let cx = size.width / 2
        let cy = size.height * 0.5
        let scale = min(size.width, size.height) * 0.32
        let joints = computeJoints(category: category, cx: cx, cy: cy, scale: scale, t: t)

        // Show knee angle arc for plyometric and strength
        switch category {
        case .plyometric, .strength:
            if let hip = joints["lHip"], let knee = joints["lKnee"], let ankle = joints["lAnkle"] {
                let kneeAngleDeg = angleDegrees(a: hip, vertex: knee, b: ankle)
                drawAngleArc(ctx: ctx, vertex: knee, a: hip, b: ankle,
                             angleDeg: kneeAngleDeg, label: "\(Int(kneeAngleDeg))°",
                             color: Theme.brandCyan)
                // Form badge
                let isGoodForm = kneeAngleDeg > 80 && kneeAngleDeg < 170
                drawFormBadge(ctx: ctx, at: CGPoint(x: size.width * 0.82, y: size.height * 0.35),
                              good: isGoodForm)
            }
            if category == .strength {
                // "KEEP BACK STRAIGHT" hint
                drawHintText(ctx: ctx, text: "KEEP BACK STRAIGHT",
                             at: CGPoint(x: size.width / 2, y: size.height * 0.22))
            }

        case .mobility:
            if let shoulder = joints["lShoulder"], let elbow = joints["lElbow"], let wrist = joints["lWrist"] {
                let armAngleDeg = angleDegrees(a: shoulder, vertex: elbow, b: wrist)
                drawAngleArc(ctx: ctx, vertex: elbow, a: shoulder, b: wrist,
                             angleDeg: armAngleDeg, label: "\(Int(armAngleDeg))°",
                             color: Color(red: 0.7, green: 0.3, blue: 1.0))
            }

        case .agility:
            drawHintText(ctx: ctx, text: "STAY LIGHT ON FEET",
                         at: CGPoint(x: size.width / 2, y: size.height * 0.22))

        case .recovery:
            drawHintText(ctx: ctx, text: "BREATHE DEEPLY",
                         at: CGPoint(x: size.width / 2, y: size.height * 0.22))
        }
    }

    private func drawAngleArc(ctx: GraphicsContext, vertex: CGPoint,
                               a: CGPoint, b: CGPoint,
                               angleDeg: Double, label: String, color: Color) {
        let arcRadius: CGFloat = 18
        let dirA = atan2(a.y - vertex.y, a.x - vertex.x)
        let dirB = atan2(b.y - vertex.y, b.x - vertex.x)

        var arcPath = Path()
        arcPath.addArc(center: vertex, radius: arcRadius,
                       startAngle: .radians(Double(dirA)),
                       endAngle: .radians(Double(dirB)),
                       clockwise: dirA > dirB)
        ctx.stroke(arcPath, with: .color(color.opacity(0.8)), lineWidth: 1.5)

        // Angle label
        let midAngle = (Double(dirA) + Double(dirB)) / 2
        let labelPos = CGPoint(x: vertex.x + cos(midAngle) * (arcRadius + 12),
                               y: vertex.y + sin(midAngle) * (arcRadius + 12))
        let labelText = ctx.resolve(Text(label)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(color))
        ctx.draw(labelText, at: labelPos, anchor: .center)
    }

    private func drawFormBadge(ctx: GraphicsContext, at point: CGPoint, good: Bool) {
        let badgeColor = good ? Color.green : Color.orange
        let badgeText = good ? "FORM ✓" : "ADJUST"
        let bgRect = CGRect(x: point.x - 26, y: point.y - 10, width: 52, height: 20)
        ctx.fill(RoundedRectangle(cornerRadius: 4).path(in: bgRect),
                 with: .color(badgeColor.opacity(0.25)))
        let outline = ctx.resolve(Text(badgeText)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundColor(badgeColor))
        ctx.draw(outline, at: point, anchor: .center)
    }

    private func drawHintText(ctx: GraphicsContext, text: String, at point: CGPoint) {
        let hint = ctx.resolve(Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.5))
            .tracking(1.5))
        ctx.draw(hint, at: point, anchor: .center)
    }

    private func angleDegrees(a: CGPoint, vertex: CGPoint, b: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = sqrt(v1.dx * v1.dx + v1.dy * v1.dy) * sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        guard mag > 0 else { return 0 }
        return acos(max(-1, min(1, Double(dot / mag)))) * 180 / .pi
    }

    // MARK: - Drawing: Center of Mass Indicator
    private func drawCenterOfMass(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let cx = size.width / 2
        let cy = size.height * 0.5
        let scale = min(size.width, size.height) * 0.32
        let joints = computeJoints(category: category, cx: cx, cy: cy, scale: scale, t: t)

        // CoM ~ weighted average of spine, hips, shoulders
        let comJointNames = ["spine", "lHip", "rHip", "lShoulder", "rShoulder"]
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        var count: CGFloat = 0
        for name in comJointNames {
            if let pt = joints[name] {
                sumX += pt.x
                sumY += pt.y
                count += 1
            }
        }
        guard count > 0 else { return }
        let com = CGPoint(x: sumX / count, y: sumY / count)

        // Draw CoM dot
        let comColor = Color(red: 1.0, green: 0.9, blue: 0.0)
        var glowCtx = ctx
        glowCtx.addFilter(.blur(radius: 5))
        let gR: CGFloat = 8
        glowCtx.fill(Circle().path(in: CGRect(x: com.x - gR, y: com.y - gR, width: gR * 2, height: gR * 2)),
                     with: .color(comColor.opacity(0.6)))

        let r: CGFloat = 4
        ctx.fill(Circle().path(in: CGRect(x: com.x - r, y: com.y - r, width: r * 2, height: r * 2)),
                 with: .color(comColor))
        ctx.stroke(Circle().path(in: CGRect(x: com.x - r, y: com.y - r, width: r * 2, height: r * 2)),
                   with: .color(Color.white.opacity(0.8)), lineWidth: 1)

        // Label
        let comLabel = ctx.resolve(Text("CoM")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(comColor.opacity(0.9)))
        ctx.draw(comLabel, at: CGPoint(x: com.x + 8, y: com.y - 8), anchor: .leading)
    }

    // MARK: - Drawing: Performance HUD Overlay
    private func drawPerformanceHUD(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let hudX = size.width * 0.04
        let hudY = size.height * 0.18
        let barW = size.width * 0.06
        let barH = size.height * 0.22

        // Heart rate bar
        let hrFrac = CGFloat(heartRate - 60) / CGFloat(185 - 60)
        let hrColor = Color(red: 1.0 - hrFrac * 0.3, green: 0.2 + (1.0 - hrFrac) * 0.3, blue: 0.2)

        // BG bar
        let hudBgRect = CGRect(x: hudX, y: hudY, width: barW, height: barH)
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in: hudBgRect),
                 with: .color(Color.black.opacity(0.5)))

        // Filled bar
        let fillH = barH * hrFrac
        let fillRect = CGRect(x: hudX, y: hudY + barH - fillH, width: barW, height: fillH)
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in: fillRect),
                 with: .color(hrColor.opacity(0.85)))

        // HR label
        let hrLabel = ctx.resolve(Text("HR")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.7)))
        ctx.draw(hrLabel, at: CGPoint(x: hudX + barW / 2, y: hudY - 8), anchor: .center)

        let hrValue = ctx.resolve(Text("\(heartRate)")
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundColor(hrColor))
        ctx.draw(hrValue, at: CGPoint(x: hudX + barW / 2, y: hudY + barH + 8), anchor: .center)

        // Effort % bar (right side)
        let effortX = size.width * 0.90
        let effortFrac = CGFloat(effortPercent) / 100.0
        let effortColor = Color(red: 0.0, green: 0.85, blue: 1.0)

        let effortBgRect = CGRect(x: effortX, y: hudY, width: barW, height: barH)
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in: effortBgRect),
                 with: .color(Color.black.opacity(0.5)))

        let effortFillH = barH * effortFrac
        let effortFillRect = CGRect(x: effortX, y: hudY + barH - effortFillH, width: barW, height: effortFillH)
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in: effortFillRect),
                 with: .color(effortColor.opacity(0.85)))

        let effortLabel = ctx.resolve(Text("EFF%")
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.7)))
        ctx.draw(effortLabel, at: CGPoint(x: effortX + barW / 2, y: hudY - 8), anchor: .center)

        let effortValue = ctx.resolve(Text("\(effortPercent)%")
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundColor(effortColor))
        ctx.draw(effortValue, at: CGPoint(x: effortX + barW / 2, y: hudY + barH + 8), anchor: .center)
    }

    // MARK: - Drawing: Phase Label
    private func drawPhaseLabel(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        let phaseText: String
        let phaseColor: Color

        if t < 0.33 {
            phaseText = "LOADING"
            phaseColor = Color(red: 1.0, green: 0.6, blue: 0.0)
        } else if t < 0.66 {
            phaseText = "PEAK"
            phaseColor = Color(red: 0.0, green: 1.0, blue: 0.6)
        } else {
            phaseText = "RELEASING"
            phaseColor = Color(red: 0.4, green: 0.7, blue: 1.0)
        }

        // Phase dot indicators (3 dots)
        let dotSpacing: CGFloat = 16
        let dotY = size.height * 0.25
        let dotCX = size.width / 2
        for i in 0..<3 {
            let dotX = dotCX - dotSpacing + CGFloat(i) * dotSpacing
            let isActive = (t < 0.33 && i == 0) || (t >= 0.33 && t < 0.66 && i == 1) || (t >= 0.66 && i == 2)
            let dotR: CGFloat = isActive ? 4.5 : 3
            let dotColor: Color = isActive ? phaseColor : Color.white.opacity(0.3)
            let dotRect = CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2)
            ctx.fill(Circle().path(in: dotRect), with: .color(dotColor))
        }

        // Phase text label
        let label = ctx.resolve(Text(phaseText)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(phaseColor)
            .tracking(2))
        ctx.draw(label, at: CGPoint(x: size.width / 2, y: size.height * 0.25 + 18), anchor: .center)
    }

    // MARK: - Drawing: Rest Overlay
    private func drawRestOverlay(ctx: GraphicsContext, size: CGSize, t: CGFloat) {
        // Semi-transparent overlay
        let overlayRect = CGRect(origin: .zero, size: size)
        ctx.fill(Rectangle().path(in: overlayRect),
                 with: .color(Color.black.opacity(0.55)))

        // REST text
        let pulse = 0.75 + 0.25 * sin(t * .pi * 4)
        let restText = ctx.resolve(Text("REST")
            .font(.system(size: size.width * 0.12, weight: .black, design: .rounded))
            .foregroundColor(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(pulse))
            .tracking(8))
        ctx.draw(restText, at: CGPoint(x: size.width / 2, y: size.height * 0.42), anchor: .center)

        // Countdown progress arc
        let arcCenter = CGPoint(x: size.width / 2, y: size.height * 0.58)
        let arcR: CGFloat = size.width * 0.08
        var arcBg = Path()
        arcBg.addArc(center: arcCenter, radius: arcR,
                     startAngle: .radians(-.pi / 2),
                     endAngle: .radians(3 * .pi / 2),
                     clockwise: false)
        ctx.stroke(arcBg, with: .color(Color.white.opacity(0.1)), lineWidth: 3)

        var arcFill = Path()
        arcFill.addArc(center: arcCenter, radius: arcR,
                       startAngle: .radians(-.pi / 2),
                       endAngle: .radians(-.pi / 2 + Double(restProgress) * 2 * .pi),
                       clockwise: false)
        ctx.stroke(arcFill, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.9)), lineWidth: 3)

        // Breathing wave hint
        let breatheText = ctx.resolve(Text("BREATHE DEEPLY")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.5))
            .tracking(2))
        ctx.draw(breatheText, at: CGPoint(x: size.width / 2, y: size.height * 0.68), anchor: .center)
    }

    // MARK: - Overlaid SwiftUI Views
    private var repCounterHUD: some View {
        VStack(spacing: 4) {
            // Rep counter
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(repCount)")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                Text("REPS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .tracking(2)
                    .padding(.bottom, 4)
            }

            // Calories + PRQ points
            HStack(spacing: 16) {
                Label {
                    Text(String(format: "%.1f kcal", caloriesBurned))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.7, blue: 0.2))
                } icon: {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.0))
                }

                Label {
                    Text("+\(prqPoints) PRQ")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.brandBlue)
                } icon: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.brandBlue)
                }

                Label {
                    Text("SET \(setCount)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.7))
                } icon: {
                    Image(systemName: "repeat")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            // AI Avatar mode badge
            HStack(spacing: 6) {
                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 10, weight: .bold))
                Text("AI AVATAR MODE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                Text("·")
                    .foregroundStyle(Color.white.opacity(0.3))
                Text(categoryLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(Theme.brandCyan)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .padding(.bottom, 12)
    }

    private var setProgressBar: some View {
        VStack(spacing: 4) {
            // Exercise name / variant indicator
            Text(exerciseName)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
                .tracking(1.5)
                .padding(.top, 8)

            // Set progress bar (reps in current 10-rep block)
            let repsInSet = repCount % 10
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(muscleGlowColor)
                        .frame(width: geo.size.width * CGFloat(repsInSet) / 10.0, height: 4)
                        .animation(.linear(duration: 0.1), value: repsInSet)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Joint Computation (preserved & extended)
    private let bones: [(String, String)] = [
        ("head", "neck"),
        ("neck", "lShoulder"), ("neck", "rShoulder"),
        ("lShoulder", "lElbow"), ("lElbow", "lWrist"),
        ("rShoulder", "rElbow"), ("rElbow", "rWrist"),
        ("neck", "spine"),
        ("spine", "lHip"), ("spine", "rHip"),
        ("lHip", "lKnee"), ("lKnee", "lAnkle"),
        ("rHip", "rKnee"), ("rKnee", "rAnkle"),
    ]

    private func computeJoints(category: Exercise.ExerciseCategory, cx: CGFloat, cy: CGFloat,
                                scale: CGFloat, t: CGFloat) -> [String: CGPoint] {
        let amp = amplitude
        var joints: [String: CGPoint] = [:]

        switch category {
        case .plyometric:
            let jumpOffset = sin(t * .pi) * scale * 0.5 * amp
            let kneeAngle = sin(t * .pi) * 0.3 * amp
            let armSwing = sin(t * .pi) * scale * 0.2 * amp

            joints["head"]      = CGPoint(x: cx, y: cy - scale * 0.8 - jumpOffset)
            joints["neck"]      = CGPoint(x: cx, y: cy - scale * 0.65 - jumpOffset)
            joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.6 - jumpOffset)
            joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.6 - jumpOffset)
            joints["lElbow"]    = CGPoint(x: cx - scale * 0.35, y: cy - scale * 0.35 - jumpOffset + armSwing)
            joints["rElbow"]    = CGPoint(x: cx + scale * 0.35, y: cy - scale * 0.35 - jumpOffset + armSwing)
            joints["lWrist"]    = CGPoint(x: cx - scale * 0.3, y: cy - scale * 0.15 - jumpOffset + armSwing * 1.3)
            joints["rWrist"]    = CGPoint(x: cx + scale * 0.3, y: cy - scale * 0.15 - jumpOffset + armSwing * 1.3)
            joints["spine"]     = CGPoint(x: cx, y: cy - scale * 0.3 - jumpOffset)
            joints["lHip"]      = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.15 - jumpOffset)
            joints["rHip"]      = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.15 - jumpOffset)
            joints["lKnee"]     = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.15 - jumpOffset * 0.5 + kneeAngle * scale)
            joints["rKnee"]     = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.15 - jumpOffset * 0.5 + kneeAngle * scale)
            joints["lAnkle"]    = CGPoint(x: cx - scale * 0.13, y: cy + scale * 0.45)
            joints["rAnkle"]    = CGPoint(x: cx + scale * 0.13, y: cy + scale * 0.45)

        case .strength:
            let squat = sin(t * .pi) * scale * 0.2 * amp
            let armPress = (1.0 - sin(t * .pi)) * scale * 0.25 * amp
            // Variant 0: squat, Variant 1: press
            if exerciseIndex % 2 == 1 {
                // Overhead press pose
                joints["head"]      = CGPoint(x: cx, y: cy - scale * 0.82)
                joints["neck"]      = CGPoint(x: cx, y: cy - scale * 0.67)
                joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.62)
                joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.62)
                joints["lElbow"]    = CGPoint(x: cx - scale * 0.28, y: cy - scale * 0.75 - armPress * 0.5)
                joints["rElbow"]    = CGPoint(x: cx + scale * 0.28, y: cy - scale * 0.75 - armPress * 0.5)
                joints["lWrist"]    = CGPoint(x: cx - scale * 0.22, y: cy - scale * 0.95 - armPress)
                joints["rWrist"]    = CGPoint(x: cx + scale * 0.22, y: cy - scale * 0.95 - armPress)
                joints["spine"]     = CGPoint(x: cx, y: cy - scale * 0.32)
                joints["lHip"]      = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.1)
                joints["rHip"]      = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.1)
                joints["lKnee"]     = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.22)
                joints["rKnee"]     = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.22)
                joints["lAnkle"]    = CGPoint(x: cx - scale * 0.13, y: cy + scale * 0.45)
                joints["rAnkle"]    = CGPoint(x: cx + scale * 0.13, y: cy + scale * 0.45)
            } else {
                // Squat pose
                joints["head"]      = CGPoint(x: cx, y: cy - scale * 0.8 + squat * 0.5)
                joints["neck"]      = CGPoint(x: cx, y: cy - scale * 0.65 + squat * 0.5)
                joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.6 + squat * 0.5)
                joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.6 + squat * 0.5)
                joints["lElbow"]    = CGPoint(x: cx - scale * 0.35, y: cy - scale * 0.4 + squat * 0.3)
                joints["rElbow"]    = CGPoint(x: cx + scale * 0.35, y: cy - scale * 0.4 + squat * 0.3)
                joints["lWrist"]    = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.2 + squat * 0.2)
                joints["rWrist"]    = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.2 + squat * 0.2)
                joints["spine"]     = CGPoint(x: cx, y: cy - scale * 0.3 + squat * 0.5)
                joints["lHip"]      = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.1 + squat * 0.6)
                joints["rHip"]      = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.1 + squat * 0.6)
                joints["lKnee"]     = CGPoint(x: cx - scale * 0.2, y: cy + scale * 0.2 + squat * 0.3)
                joints["rKnee"]     = CGPoint(x: cx + scale * 0.2, y: cy + scale * 0.2 + squat * 0.3)
                joints["lAnkle"]    = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.45)
                joints["rAnkle"]    = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.45)
            }

        case .agility:
            let lateral = sin(t * .pi) * scale * 0.3 * amp
            let bob = abs(sin(t * .pi * 2)) * scale * 0.05
            joints["head"]      = CGPoint(x: cx + lateral, y: cy - scale * 0.8 + bob)
            joints["neck"]      = CGPoint(x: cx + lateral, y: cy - scale * 0.65 + bob)
            joints["lShoulder"] = CGPoint(x: cx + lateral - scale * 0.25, y: cy - scale * 0.6 + bob)
            joints["rShoulder"] = CGPoint(x: cx + lateral + scale * 0.25, y: cy - scale * 0.6 + bob)
            joints["lElbow"]    = CGPoint(x: cx + lateral - scale * 0.38, y: cy - scale * 0.4 - lateral * 0.3)
            joints["rElbow"]    = CGPoint(x: cx + lateral + scale * 0.32, y: cy - scale * 0.4 + lateral * 0.3)
            joints["lWrist"]    = CGPoint(x: cx + lateral - scale * 0.3, y: cy - scale * 0.25 - lateral * 0.2)
            joints["rWrist"]    = CGPoint(x: cx + lateral + scale * 0.3, y: cy - scale * 0.25 + lateral * 0.2)
            joints["spine"]     = CGPoint(x: cx + lateral, y: cy - scale * 0.3 + bob)
            joints["lHip"]      = CGPoint(x: cx + lateral - scale * 0.15, y: cy - scale * 0.1 + bob)
            joints["rHip"]      = CGPoint(x: cx + lateral + scale * 0.15, y: cy - scale * 0.1 + bob)
            joints["lKnee"]     = CGPoint(x: cx + lateral - scale * 0.25, y: cy + scale * 0.15)
            joints["rKnee"]     = CGPoint(x: cx + lateral + scale * 0.1, y: cy + scale * 0.15)
            joints["lAnkle"]    = CGPoint(x: cx + lateral - scale * 0.3, y: cy + scale * 0.45)
            joints["rAnkle"]    = CGPoint(x: cx + lateral + scale * 0.05, y: cy + scale * 0.45)

        case .mobility:
            let stretch = sin(t * .pi) * scale * 0.15 * amp
            let sideStretch = cos(t * .pi) * scale * 0.08 * amp
            joints["head"]      = CGPoint(x: cx + sideStretch * 0.2, y: cy - scale * 0.8)
            joints["neck"]      = CGPoint(x: cx + sideStretch * 0.1, y: cy - scale * 0.65)
            joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.6)
            joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.6)
            joints["lElbow"]    = CGPoint(x: cx - scale * 0.4 - stretch, y: cy - scale * 0.5 - stretch)
            joints["rElbow"]    = CGPoint(x: cx + scale * 0.4 + stretch, y: cy - scale * 0.5 - stretch)
            joints["lWrist"]    = CGPoint(x: cx - scale * 0.5 - stretch * 1.5, y: cy - scale * 0.55 - stretch * 1.2)
            joints["rWrist"]    = CGPoint(x: cx + scale * 0.5 + stretch * 1.5, y: cy - scale * 0.55 - stretch * 1.2)
            joints["spine"]     = CGPoint(x: cx, y: cy - scale * 0.3)
            joints["lHip"]      = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.1)
            joints["rHip"]      = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.1)
            joints["lKnee"]     = CGPoint(x: cx - scale * 0.15 - sideStretch * 0.3, y: cy + scale * 0.2)
            joints["rKnee"]     = CGPoint(x: cx + scale * 0.15 + sideStretch * 0.3, y: cy + scale * 0.2)
            joints["lAnkle"]    = CGPoint(x: cx - scale * 0.13, y: cy + scale * 0.45)
            joints["rAnkle"]    = CGPoint(x: cx + scale * 0.13, y: cy + scale * 0.45)

        case .recovery:
            let breathe = sin(t * .pi) * scale * 0.04 * amp
            let armFloat = sin(t * .pi * 0.5) * scale * 0.06 * amp
            joints["head"]      = CGPoint(x: cx, y: cy - scale * 0.75 + breathe)
            joints["neck"]      = CGPoint(x: cx, y: cy - scale * 0.6 + breathe)
            joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.55 + breathe)
            joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.55 + breathe)
            joints["lElbow"]    = CGPoint(x: cx - scale * 0.3, y: cy - scale * 0.3 + armFloat)
            joints["rElbow"]    = CGPoint(x: cx + scale * 0.3, y: cy - scale * 0.3 + armFloat)
            joints["lWrist"]    = CGPoint(x: cx - scale * 0.2, y: cy - scale * 0.15 + armFloat * 0.8)
            joints["rWrist"]    = CGPoint(x: cx + scale * 0.2, y: cy - scale * 0.15 + armFloat * 0.8)
            joints["spine"]     = CGPoint(x: cx, y: cy - scale * 0.25 + breathe)
            joints["lHip"]      = CGPoint(x: cx - scale * 0.2, y: cy + scale * 0.05)
            joints["rHip"]      = CGPoint(x: cx + scale * 0.2, y: cy + scale * 0.05)
            joints["lKnee"]     = CGPoint(x: cx - scale * 0.35, y: cy + scale * 0.15)
            joints["rKnee"]     = CGPoint(x: cx + scale * 0.35, y: cy + scale * 0.15)
            joints["lAnkle"]    = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.1)
            joints["rAnkle"]    = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.1)
        }

        return joints
    }

    // MARK: - Helpers / Computed Properties
    private func smoothstep(_ t: CGFloat) -> CGFloat {
        let c = max(0, min(1, t))
        return c * c * (3 - 2 * c)
    }

    private var exerciseCycleDuration: Double {
        switch category {
        case .plyometric: return 0.6
        case .strength: return 1.2
        case .mobility: return 1.8
        case .agility: return 0.5
        case .recovery: return 2.0
        }
    }

    private var muscleGlowColor: Color {
        switch category {
        case .plyometric: return Color(red: 1.0, green: 0.35, blue: 0.0)   // red/orange - quads + glutes
        case .strength:   return Color(red: 0.0, green: 0.6, blue: 1.0)    // blue/cyan - chest + shoulders
        case .agility:    return Color(red: 0.15, green: 1.0, blue: 0.35)  // green - calves + core
        case .mobility:   return Color(red: 0.65, green: 0.2, blue: 1.0)   // purple - back + hips
        case .recovery:   return Color(red: 0.5, green: 0.85, blue: 1.0)   // pale blue - full body
        }
    }

    private var categoryLabel: String {
        switch category {
        case .plyometric: return "PLYOMETRIC"
        case .strength:   return "STRENGTH"
        case .agility:    return "AGILITY"
        case .mobility:   return "MOBILITY"
        case .recovery:   return "RECOVERY"
        }
    }

    private var exerciseName: String {
        switch category {
        case .plyometric:
            return ["BOX JUMP", "DEPTH JUMP", "BROAD JUMP"][exerciseIndex % 3]
        case .strength:
            return ["SQUAT", "OVERHEAD PRESS", "DEADLIFT", "BENCH PRESS"][exerciseIndex % 4]
        case .agility:
            return ["LATERAL SHUFFLE", "CONE DRILL", "LADDER DRILL"][exerciseIndex % 3]
        case .mobility:
            return ["HIP FLEXOR STRETCH", "THORACIC ROTATION", "HAMSTRING STRETCH"][exerciseIndex % 3]
        case .recovery:
            return ["DIAPHRAGMATIC BREATHING", "LIGHT WALK", "FOAM ROLL"][exerciseIndex % 3]
        }
    }

    private var exerciseVariantCount: Int {
        switch category {
        case .plyometric: return 3
        case .strength: return 4
        case .agility: return 3
        case .mobility: return 3
        case .recovery: return 3
        }
    }

    private var metFactor: Double {
        switch category {
        case .plyometric: return 8.0
        case .strength: return 6.0
        case .agility: return 9.0
        case .mobility: return 3.0
        case .recovery: return 2.0
        }
    }

    private var baseHeartRate: Int {
        switch category {
        case .plyometric: return 110
        case .strength: return 95
        case .agility: return 115
        case .mobility: return 75
        case .recovery: return 68
        }
    }

    private var baseEffort: Int {
        switch category {
        case .plyometric: return 45
        case .strength: return 40
        case .agility: return 50
        case .mobility: return 20
        case .recovery: return 10
        }
    }
}
