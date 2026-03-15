import SwiftUI

/// Reusable character performing the exercise/movement. Use in workout rows and detail headers so every exercise has a visual.
struct ExerciseCharacterView: View {
    let category: Exercise.ExerciseCategory
    var difficulty: Exercise.Difficulty = .foundation
    var compact: Bool = false

    @State private var phase: CGFloat = 0
    @State private var glowPulse: Bool = false

    private var movementAmplitude: CGFloat {
        switch difficulty {
        case .foundation: 0.6
        case .flight: 0.8
        case .elite: 1.0
        }
    }

    private var cycleDuration: Double {
        switch category {
        case .plyometric: 0.6
        case .strength: 1.2
        case .mobility: 1.8
        case .agility: 0.5
        case .recovery: 2.0
        }
    }

    var body: some View {
        ZStack {
            if !compact {
                gridBackground
            }
            skeletonFigure
            if !compact {
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "figure.mixed.cardio")
                            .font(.system(size: 8, weight: .bold))
                        Text("DEMO")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(Theme.brandCyan.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: cycleDuration).repeatForever(autoreverses: true)) {
                phase = 1
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var gridBackground: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            for col in 0...cols {
                let x = CGFloat(col) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
            }
            for row in 0...rows {
                let y = CGFloat(row) * spacing
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
            }
        }
    }

    private var skeletonFigure: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let scale = (compact ? min(size.width, size.height) * 0.28 : min(size.width, size.height) * 0.35)
            let t = phase
            let joints = SkeletonJoints.compute(category: category, amplitude: movementAmplitude, cx: cx, cy: cy, scale: scale, t: t)
            let limbColor = Theme.brandBlue
            let jointColor = Theme.brandCyan
            let lineWidth: CGFloat = compact ? 2 : 3
            for bone in SkeletonJoints.bones {
                guard let from = joints[bone.0], let to = joints[bone.1] else { continue }
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                context.stroke(path, with: .color(limbColor.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            let glowRadius: CGFloat = glowPulse ? (compact ? 4 : 8) : (compact ? 2 : 4)
            let jointSize: CGFloat = compact ? 6 : 10
            for (_, point) in joints {
                let rect = CGRect(x: point.x - jointSize/2, y: point.y - jointSize/2, width: jointSize, height: jointSize)
                context.fill(Circle().path(in: rect.insetBy(dx: -glowRadius, dy: -glowRadius)), with: .color(jointColor.opacity(0.15)))
                context.fill(Circle().path(in: rect), with: .color(jointColor))
            }
        }
    }
}

private enum SkeletonJoints {
    static let bones: [(String, String)] = [
        ("head", "neck"),
        ("neck", "lShoulder"), ("neck", "rShoulder"),
        ("lShoulder", "lElbow"), ("lElbow", "lWrist"),
        ("rShoulder", "rElbow"), ("rElbow", "rWrist"),
        ("neck", "spine"),
        ("spine", "lHip"), ("spine", "rHip"),
        ("lHip", "lKnee"), ("lKnee", "lAnkle"),
        ("rHip", "rKnee"), ("rKnee", "rAnkle"),
    ]

    static func compute(category: Exercise.ExerciseCategory, amplitude: CGFloat, cx: CGFloat, cy: CGFloat, scale: CGFloat, t: CGFloat) -> [String: CGPoint] {
        let amp = amplitude
        var joints: [String: CGPoint] = [:]
        switch category {
        case .plyometric:
            let jumpOffset = sin(t * .pi) * scale * 0.5 * amp
            let kneeAngle = sin(t * .pi) * 0.3 * amp
            joints["head"] = CGPoint(x: cx, y: cy - scale * 0.8 - jumpOffset)
            joints["neck"] = CGPoint(x: cx, y: cy - scale * 0.65 - jumpOffset)
            joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.6 - jumpOffset)
            joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.6 - jumpOffset)
            joints["lElbow"] = CGPoint(x: cx - scale * 0.35, y: cy - scale * 0.35 - jumpOffset + sin(t * .pi) * scale * 0.15)
            joints["rElbow"] = CGPoint(x: cx + scale * 0.35, y: cy - scale * 0.35 - jumpOffset + sin(t * .pi) * scale * 0.15)
            joints["lWrist"] = CGPoint(x: cx - scale * 0.3, y: cy - scale * 0.15 - jumpOffset + sin(t * .pi) * scale * 0.2)
            joints["rWrist"] = CGPoint(x: cx + scale * 0.3, y: cy - scale * 0.15 - jumpOffset + sin(t * .pi) * scale * 0.2)
            joints["spine"] = CGPoint(x: cx, y: cy - scale * 0.3 - jumpOffset)
            joints["lHip"] = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.15 - jumpOffset)
            joints["rHip"] = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.15 - jumpOffset)
            joints["lKnee"] = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.15 - jumpOffset * 0.5 + kneeAngle * scale)
            joints["rKnee"] = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.15 - jumpOffset * 0.5 + kneeAngle * scale)
            joints["lAnkle"] = CGPoint(x: cx - scale * 0.13, y: cy + scale * 0.45)
            joints["rAnkle"] = CGPoint(x: cx + scale * 0.13, y: cy + scale * 0.45)
        case .strength:
            let squat = sin(t * .pi) * scale * 0.2 * amp
            joints["head"] = CGPoint(x: cx, y: cy - scale * 0.8 + squat * 0.5)
            joints["neck"] = CGPoint(x: cx, y: cy - scale * 0.65 + squat * 0.5)
            joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.6 + squat * 0.5)
            joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.6 + squat * 0.5)
            joints["lElbow"] = CGPoint(x: cx - scale * 0.35, y: cy - scale * 0.4 + squat * 0.3)
            joints["rElbow"] = CGPoint(x: cx + scale * 0.35, y: cy - scale * 0.4 + squat * 0.3)
            joints["lWrist"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.2 + squat * 0.2)
            joints["rWrist"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.2 + squat * 0.2)
            joints["spine"] = CGPoint(x: cx, y: cy - scale * 0.3 + squat * 0.5)
            joints["lHip"] = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.1 + squat * 0.6)
            joints["rHip"] = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.1 + squat * 0.6)
            joints["lKnee"] = CGPoint(x: cx - scale * 0.2, y: cy + scale * 0.2 + squat * 0.3)
            joints["rKnee"] = CGPoint(x: cx + scale * 0.2, y: cy + scale * 0.2 + squat * 0.3)
            joints["lAnkle"] = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.45)
            joints["rAnkle"] = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.45)
        case .agility:
            let lateral = sin(t * .pi) * scale * 0.3 * amp
            let bob = abs(sin(t * .pi * 2)) * scale * 0.05
            joints["head"] = CGPoint(x: cx + lateral, y: cy - scale * 0.8 + bob)
            joints["neck"] = CGPoint(x: cx + lateral, y: cy - scale * 0.65 + bob)
            joints["lShoulder"] = CGPoint(x: cx + lateral - scale * 0.25, y: cy - scale * 0.6 + bob)
            joints["rShoulder"] = CGPoint(x: cx + lateral + scale * 0.25, y: cy - scale * 0.6 + bob)
            joints["lElbow"] = CGPoint(x: cx + lateral - scale * 0.35, y: cy - scale * 0.4)
            joints["rElbow"] = CGPoint(x: cx + lateral + scale * 0.35, y: cy - scale * 0.4)
            joints["lWrist"] = CGPoint(x: cx + lateral - scale * 0.3, y: cy - scale * 0.25)
            joints["rWrist"] = CGPoint(x: cx + lateral + scale * 0.3, y: cy - scale * 0.25)
            joints["spine"] = CGPoint(x: cx + lateral, y: cy - scale * 0.3 + bob)
            joints["lHip"] = CGPoint(x: cx + lateral - scale * 0.15, y: cy - scale * 0.1 + bob)
            joints["rHip"] = CGPoint(x: cx + lateral + scale * 0.15, y: cy - scale * 0.1 + bob)
            joints["lKnee"] = CGPoint(x: cx + lateral - scale * 0.25, y: cy + scale * 0.15)
            joints["rKnee"] = CGPoint(x: cx + lateral + scale * 0.1, y: cy + scale * 0.15)
            joints["lAnkle"] = CGPoint(x: cx + lateral - scale * 0.3, y: cy + scale * 0.45)
            joints["rAnkle"] = CGPoint(x: cx + lateral + scale * 0.05, y: cy + scale * 0.45)
        case .mobility:
            let stretch = sin(t * .pi) * scale * 0.15 * amp
            joints["head"] = CGPoint(x: cx, y: cy - scale * 0.8)
            joints["neck"] = CGPoint(x: cx, y: cy - scale * 0.65)
            joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.6)
            joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.6)
            joints["lElbow"] = CGPoint(x: cx - scale * 0.4 - stretch, y: cy - scale * 0.5 - stretch)
            joints["rElbow"] = CGPoint(x: cx + scale * 0.4 + stretch, y: cy - scale * 0.5 - stretch)
            joints["lWrist"] = CGPoint(x: cx - scale * 0.5 - stretch * 1.5, y: cy - scale * 0.55 - stretch * 1.2)
            joints["rWrist"] = CGPoint(x: cx + scale * 0.5 + stretch * 1.5, y: cy - scale * 0.55 - stretch * 1.2)
            joints["spine"] = CGPoint(x: cx, y: cy - scale * 0.3)
            joints["lHip"] = CGPoint(x: cx - scale * 0.12, y: cy - scale * 0.1)
            joints["rHip"] = CGPoint(x: cx + scale * 0.12, y: cy - scale * 0.1)
            joints["lKnee"] = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.2)
            joints["rKnee"] = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.2)
            joints["lAnkle"] = CGPoint(x: cx - scale * 0.13, y: cy + scale * 0.45)
            joints["rAnkle"] = CGPoint(x: cx + scale * 0.13, y: cy + scale * 0.45)
        case .recovery:
            let breathe = sin(t * .pi) * scale * 0.04 * amp
            joints["head"] = CGPoint(x: cx, y: cy - scale * 0.75 + breathe)
            joints["neck"] = CGPoint(x: cx, y: cy - scale * 0.6 + breathe)
            joints["lShoulder"] = CGPoint(x: cx - scale * 0.25, y: cy - scale * 0.55 + breathe)
            joints["rShoulder"] = CGPoint(x: cx + scale * 0.25, y: cy - scale * 0.55 + breathe)
            joints["lElbow"] = CGPoint(x: cx - scale * 0.3, y: cy - scale * 0.3)
            joints["rElbow"] = CGPoint(x: cx + scale * 0.3, y: cy - scale * 0.3)
            joints["lWrist"] = CGPoint(x: cx - scale * 0.2, y: cy - scale * 0.15)
            joints["rWrist"] = CGPoint(x: cx + scale * 0.2, y: cy - scale * 0.15)
            joints["spine"] = CGPoint(x: cx, y: cy - scale * 0.25 + breathe)
            joints["lHip"] = CGPoint(x: cx - scale * 0.2, y: cy + scale * 0.05)
            joints["rHip"] = CGPoint(x: cx + scale * 0.2, y: cy + scale * 0.05)
            joints["lKnee"] = CGPoint(x: cx - scale * 0.35, y: cy + scale * 0.15)
            joints["rKnee"] = CGPoint(x: cx + scale * 0.35, y: cy + scale * 0.15)
            joints["lAnkle"] = CGPoint(x: cx - scale * 0.15, y: cy + scale * 0.1)
            joints["rAnkle"] = CGPoint(x: cx + scale * 0.15, y: cy + scale * 0.1)
        }
        return joints
    }
}
