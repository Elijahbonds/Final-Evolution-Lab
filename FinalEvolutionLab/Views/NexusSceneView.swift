import SwiftUI

// MARK: - NexusSceneView

/// Canvas-backed renderer for a NexusScene.
///
/// Driven by SwiftUI's TimelineView for smooth 60 Hz animation. Each entity
/// with a skeleton component runs an independent phase offset so multiple
/// characters animate without lockstep. Physics-body entities are drawn as
/// shaded capsules; triggers as dashed rings; cameras as crosshair icons.
struct NexusSceneView: View {
    let scene: NexusScene
    let physics: NexusPhysicsConfig
    var showDebugOverlay: Bool = false

    @State private var startDate = Date()

    private var backgroundColor: Color {
        Color(hex: scene.environment.backgroundColor) ?? .black
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)

                Canvas { context, size in
                    drawEnvironment(context: context, size: size)
                    drawEntities(context: context, size: size, elapsed: elapsed)
                    if showDebugOverlay {
                        drawDebugGrid(context: context, size: size)
                        drawEntityLabels(context: context, size: size)
                    }
                }
            }

            if showDebugOverlay {
                debugHUD
            }

            engineWatermark
        }
        .onAppear { startDate = Date() }
    }

    // MARK: - Environment

    private func drawEnvironment(context: GraphicsContext, size: CGSize) {
        let floorY = scene.environment.floorY * size.height
        let accentColor = Color(hex: scene.environment.accentColor) ?? Theme.brandBlue

        // Atmospheric fog gradient
        if scene.environment.fogDensity > 0 {
            let fogRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            context.fill(
                Path(fogRect),
                with: .linearGradient(
                    Gradient(colors: [
                        accentColor.opacity(scene.environment.fogDensity * 0.3),
                        .clear
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: floorY)
                )
            )
        }

        // Floor line
        var floorPath = Path()
        floorPath.move(to: CGPoint(x: 0, y: floorY))
        floorPath.addLine(to: CGPoint(x: size.width, y: floorY))
        context.stroke(floorPath, with: .color(accentColor.opacity(0.35)), lineWidth: 1.5)

        // Floor reflection gradient
        let reflectRect = CGRect(x: 0, y: floorY, width: size.width, height: min(40, size.height - floorY))
        context.fill(
            Path(reflectRect),
            with: .linearGradient(
                Gradient(colors: [accentColor.opacity(0.08), .clear]),
                startPoint: CGPoint(x: size.width / 2, y: floorY),
                endPoint: CGPoint(x: size.width / 2, y: floorY + 40)
            )
        )

        // Ambient grid lines (subtle)
        let gridSpacing: CGFloat = 40
        let cols = Int(size.width / gridSpacing)
        for col in 0...cols {
            let x = CGFloat(col) * gridSpacing
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(.white.opacity(0.02)), lineWidth: 0.5)
        }
    }

    // MARK: - Entities

    private func drawEntities(context: GraphicsContext, size: CGSize, elapsed: Double) {
        for (index, entity) in scene.entities.enumerated() where entity.isEnabled && !entity.isCamera {
            let pos = entity.transform.resolvedPosition(in: size)
            let phaseOffset = Double(index) * 0.4
            drawEntity(entity, at: pos, in: context, size: size, phase: elapsed + phaseOffset)
        }
    }

    private func drawEntity(
        _ entity: NexusEntity,
        at position: CGPoint,
        in context: GraphicsContext,
        size: CGSize,
        phase: Double
    ) {
        let accentColor = Color(hex: scene.environment.accentColor) ?? Theme.brandBlue
        let t = CGFloat(phase)

        for component in entity.components {
            switch component {
            case .skeleton(let category, let amplitude):
                let scale = min(size.width, size.height) * 0.18 * amplitude * CGFloat(physics.prqSpeedMultiplier)
                drawSkeleton(
                    category: category,
                    at: position,
                    scale: scale,
                    phase: t,
                    amplitude: amplitude,
                    context: context,
                    accentColor: accentColor
                )

            case .physics(_, _):
                // Draw as a subtle capsule shadow indicating physics body
                let capsuleHeight: CGFloat = 6
                let capsuleWidth: CGFloat = 20
                let shadowRect = CGRect(
                    x: position.x - capsuleWidth / 2,
                    y: position.y + 2,
                    width: capsuleWidth,
                    height: capsuleHeight
                )
                context.fill(
                    Capsule().path(in: shadowRect),
                    with: .color(accentColor.opacity(0.15))
                )

            case .surface(_):
                // Surface is drawn as part of the floor environment
                break

            case .sprite(let systemImage, let hexColor):
                let spriteColor = Color(hex: hexColor) ?? accentColor
                let rect = CGRect(x: position.x - 20, y: position.y - 20, width: 40, height: 40)
                context.draw(
                    Text(Image(systemName: systemImage))
                        .font(.system(size: 36))
                        .foregroundColor(spriteColor),
                    in: rect
                )

            case .trigger(let radius, _):
                let resolvedRadius = radius * min(size.width, size.height)
                let triggerRect = CGRect(
                    x: position.x - resolvedRadius,
                    y: position.y - resolvedRadius,
                    width: resolvedRadius * 2,
                    height: resolvedRadius * 2
                )
                let pulse = CGFloat(0.5 + 0.5 * sin(phase * 2.0))
                context.stroke(
                    Circle().path(in: triggerRect),
                    with: .color(accentColor.opacity(Double(pulse) * 0.5)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )

            case .camera, .light:
                break
            }
        }
    }

    // MARK: - Skeleton rendering (from AvatarDemoView, adapted for NexusScene)

    private let boneConnections: [(String, String)] = [
        ("head", "neck"),
        ("neck", "lShoulder"), ("neck", "rShoulder"),
        ("lShoulder", "lElbow"), ("lElbow", "lWrist"),
        ("rShoulder", "rElbow"), ("rElbow", "rWrist"),
        ("neck", "spine"),
        ("spine", "lHip"), ("spine", "rHip"),
        ("lHip", "lKnee"), ("lKnee", "lAnkle"),
        ("rHip", "rKnee"), ("rKnee", "rAnkle"),
    ]

    private func drawSkeleton(
        category: Exercise.ExerciseCategory,
        at center: CGPoint,
        scale: CGFloat,
        phase: CGFloat,
        amplitude: CGFloat,
        context: GraphicsContext,
        accentColor: Color
    ) {
        let joints = computeJoints(category: category, center: center, scale: scale, t: phase, amp: amplitude)
        let jointColor = Theme.brandCyan

        for bone in boneConnections {
            guard let from = joints[bone.0], let to = joints[bone.1] else { continue }
            var bonePath = Path()
            bonePath.move(to: from)
            bonePath.addLine(to: to)
            context.stroke(bonePath, with: .color(accentColor.opacity(0.75)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }

        for (_, point) in joints {
            let jointRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            context.fill(Circle().path(in: jointRect.insetBy(dx: -3, dy: -3)), with: .color(jointColor.opacity(0.12)))
            context.fill(Circle().path(in: jointRect), with: .color(jointColor))
        }
    }

    private func computeJoints(
        category: Exercise.ExerciseCategory,
        center: CGPoint,
        scale: CGFloat,
        t: CGFloat,
        amp: CGFloat
    ) -> [String: CGPoint] {
        let cx = center.x
        let cy = center.y
        var j: [String: CGPoint] = [:]

        switch category {
        case .plyometric:
            let jump = sin(t * .pi) * scale * 0.45 * amp
            j["head"]      = CGPoint(x: cx, y: cy - scale * 0.80 - jump)
            j["neck"]      = CGPoint(x: cx, y: cy - scale * 0.65 - jump)
            j["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.60 - jump)
            j["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.60 - jump)
            j["lElbow"]    = CGPoint(x: cx - scale * 0.35, y: cy - scale * 0.35 - jump + sin(t * .pi) * scale * 0.15)
            j["rElbow"]    = CGPoint(x: cx + scale * 0.35, y: cy - scale * 0.35 - jump + sin(t * .pi) * scale * 0.15)
            j["lWrist"]    = CGPoint(x: cx - scale * 0.30, y: cy - scale * 0.15 - jump + sin(t * .pi) * scale * 0.20)
            j["rWrist"]    = CGPoint(x: cx + scale * 0.30, y: cy - scale * 0.15 - jump + sin(t * .pi) * scale * 0.20)
            j["spine"]     = CGPoint(x: cx, y: cy - scale * 0.30 - jump)
            j["lHip"]      = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.15 - jump)
            j["rHip"]      = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.15 - jump)
            j["lKnee"]     = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.15 - jump * 0.5)
            j["rKnee"]     = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.15 - jump * 0.5)
            j["lAnkle"]    = CGPoint(x: cx - scale * 0.13, y: cy + scale * 0.45)
            j["rAnkle"]    = CGPoint(x: cx + scale * 0.13, y: cy + scale * 0.45)

        case .strength:
            let squat = sin(t * .pi) * scale * 0.20 * amp
            j["head"]      = CGPoint(x: cx, y: cy - scale * 0.80 + squat * 0.5)
            j["neck"]      = CGPoint(x: cx, y: cy - scale * 0.65 + squat * 0.5)
            j["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.60 + squat * 0.5)
            j["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.60 + squat * 0.5)
            j["lElbow"]    = CGPoint(x: cx - scale * 0.35, y: cy - scale * 0.40 + squat * 0.3)
            j["rElbow"]    = CGPoint(x: cx + scale * 0.35, y: cy - scale * 0.40 + squat * 0.3)
            j["lWrist"]    = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.20 + squat * 0.2)
            j["rWrist"]    = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.20 + squat * 0.2)
            j["spine"]     = CGPoint(x: cx, y: cy - scale * 0.30 + squat * 0.5)
            j["lHip"]      = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.10 + squat * 0.6)
            j["rHip"]      = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.10 + squat * 0.6)
            j["lKnee"]     = CGPoint(x: cx - scale * 0.20, y: cy + scale * 0.20 + squat * 0.3)
            j["rKnee"]     = CGPoint(x: cx + scale * 0.20, y: cy + scale * 0.20 + squat * 0.3)
            j["lAnkle"]    = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.45)
            j["rAnkle"]    = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.45)

        case .agility:
            let lateral = sin(t * .pi) * scale * 0.30 * amp
            let bob = abs(sin(t * .pi * 2)) * scale * 0.05
            j["head"]      = CGPoint(x: cx + lateral, y: cy - scale * 0.80 + bob)
            j["neck"]      = CGPoint(x: cx + lateral, y: cy - scale * 0.65 + bob)
            j["lShoulder"] = CGPoint(x: cx + lateral - scale * 0.25, y: cy - scale * 0.60 + bob)
            j["rShoulder"] = CGPoint(x: cx + lateral + scale * 0.25, y: cy - scale * 0.60 + bob)
            j["lElbow"]    = CGPoint(x: cx + lateral - scale * 0.35, y: cy - scale * 0.40)
            j["rElbow"]    = CGPoint(x: cx + lateral + scale * 0.35, y: cy - scale * 0.40)
            j["lWrist"]    = CGPoint(x: cx + lateral - scale * 0.30, y: cy - scale * 0.25)
            j["rWrist"]    = CGPoint(x: cx + lateral + scale * 0.30, y: cy - scale * 0.25)
            j["spine"]     = CGPoint(x: cx + lateral, y: cy - scale * 0.30 + bob)
            j["lHip"]      = CGPoint(x: cx + lateral - scale * 0.15, y: cy - scale * 0.10 + bob)
            j["rHip"]      = CGPoint(x: cx + lateral + scale * 0.15, y: cy - scale * 0.10 + bob)
            j["lKnee"]     = CGPoint(x: cx + lateral - scale * 0.25, y: cy + scale * 0.15)
            j["rKnee"]     = CGPoint(x: cx + lateral + scale * 0.10, y: cy + scale * 0.15)
            j["lAnkle"]    = CGPoint(x: cx + lateral - scale * 0.30, y: cy + scale * 0.45)
            j["rAnkle"]    = CGPoint(x: cx + lateral + scale * 0.05, y: cy + scale * 0.45)

        case .mobility:
            let stretch = sin(t * .pi) * scale * 0.15 * amp
            j["head"]      = CGPoint(x: cx, y: cy - scale * 0.80)
            j["neck"]      = CGPoint(x: cx, y: cy - scale * 0.65)
            j["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.60)
            j["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.60)
            j["lElbow"]    = CGPoint(x: cx - scale * 0.40 - stretch, y: cy - scale * 0.50 - stretch)
            j["rElbow"]    = CGPoint(x: cx + scale * 0.40 + stretch, y: cy - scale * 0.50 - stretch)
            j["lWrist"]    = CGPoint(x: cx - scale * 0.50 - stretch * 1.5, y: cy - scale * 0.55 - stretch * 1.2)
            j["rWrist"]    = CGPoint(x: cx + scale * 0.50 + stretch * 1.5, y: cy - scale * 0.55 - stretch * 1.2)
            j["spine"]     = CGPoint(x: cx, y: cy - scale * 0.30)
            j["lHip"]      = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.10)
            j["rHip"]      = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.10)
            j["lKnee"]     = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.20)
            j["rKnee"]     = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.20)
            j["lAnkle"]    = CGPoint(x: cx - scale * 0.13, y: cy + scale * 0.45)
            j["rAnkle"]    = CGPoint(x: cx + scale * 0.13, y: cy + scale * 0.45)

        case .recovery:
            let breathe = sin(t * .pi) * scale * 0.04 * amp
            j["head"]      = CGPoint(x: cx, y: cy - scale * 0.75 + breathe)
            j["neck"]      = CGPoint(x: cx, y: cy - scale * 0.60 + breathe)
            j["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.55 + breathe)
            j["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.55 + breathe)
            j["lElbow"]    = CGPoint(x: cx - scale * 0.30, y: cy - scale * 0.30)
            j["rElbow"]    = CGPoint(x: cx + scale * 0.30, y: cy - scale * 0.30)
            j["lWrist"]    = CGPoint(x: cx - scale * 0.20, y: cy - scale * 0.15)
            j["rWrist"]    = CGPoint(x: cx + scale * 0.20, y: cy - scale * 0.15)
            j["spine"]     = CGPoint(x: cx, y: cy - scale * 0.25 + breathe)
            j["lHip"]      = CGPoint(x: cx - scale * 0.20, y: cy + scale * 0.05)
            j["rHip"]      = CGPoint(x: cx + scale * 0.20, y: cy + scale * 0.05)
            j["lKnee"]     = CGPoint(x: cx - scale * 0.35, y: cy + scale * 0.15)
            j["rKnee"]     = CGPoint(x: cx + scale * 0.35, y: cy + scale * 0.15)
            j["lAnkle"]    = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.10)
            j["rAnkle"]    = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.10)
        }

        return j
    }

    // MARK: - Debug

    private func drawDebugGrid(context: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = size.width / 10
        for i in 0...10 {
            var hPath = Path()
            hPath.move(to: CGPoint(x: CGFloat(i) * spacing, y: 0))
            hPath.addLine(to: CGPoint(x: CGFloat(i) * spacing, y: size.height))
            context.stroke(hPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
        }
        for j in 0...10 {
            var vPath = Path()
            vPath.move(to: CGPoint(x: 0, y: CGFloat(j) * spacing))
            vPath.addLine(to: CGPoint(x: size.width, y: CGFloat(j) * spacing))
            context.stroke(vPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
        }
    }

    private func drawEntityLabels(context: GraphicsContext, size: CGSize) {
        for entity in scene.entities where !entity.isCamera {
            let pos = entity.transform.resolvedPosition(in: size)
            let labelPos = CGPoint(x: pos.x, y: pos.y - 10)
            context.draw(
                Text(entity.name)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4)),
                at: labelPos
            )
        }
    }

    private var debugHUD: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NEXUS ENGINE")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
            Text("scene: \(scene.name)")
                .font(.system(size: 8, design: .monospaced))
            Text("entities: \(scene.entities.count)")
                .font(.system(size: 8, design: .monospaced))
            Text("speed: \(String(format: "%.2f", physics.prqSpeedMultiplier))x")
                .font(.system(size: 8, design: .monospaced))
        }
        .foregroundStyle(.white.opacity(0.6))
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private var engineWatermark: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "atom")
                        .font(.system(size: 8, weight: .bold))
                    Text("NEXUS ENGINE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(
                    (Color(hex: scene.environment.accentColor) ?? Theme.brandBlue).opacity(0.4)
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            Spacer()
        }
        .padding(10)
    }
}

