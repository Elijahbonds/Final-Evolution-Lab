import SwiftUI
import SceneKit

// MARK: - MeshyAvatarView
// Shows a 3D USDZ model when available, or a canvas placeholder when not.
// Drop the .usdz file into Models3D/ to activate 3D display — no code changes needed.

struct MeshyAvatarView: View {
    let slot: MeshyModelSlot
    var autoRotate: Bool = true

    var body: some View {
        if MeshyModelRegistry.shared.isAvailable(slot) {
            MeshySceneView(slot: slot, autoRotate: autoRotate)
        } else {
            AvatarPlaceholderView(slot: slot)
        }
    }
}

// MARK: - MeshySceneView (UIViewRepresentable)

private struct MeshySceneView: UIViewRepresentable {
    let slot: MeshyModelSlot
    let autoRotate: Bool

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = true

        if let scene = MeshyModelRegistry.shared.scene(for: slot) {
            scnView.scene = scene
        }

        if autoRotate {
            scnView.scene?.rootNode.runAction(
                SCNAction.repeatForever(
                    SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12)
                )
            )
        }

        // Camera node
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, 0.5, 2.5)
        scnView.scene?.rootNode.addChildNode(cameraNode)

        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 400
        scnView.scene?.rootNode.addChildNode(ambientLight)

        // Key light
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 800
        keyLight.light?.castsShadow = true
        keyLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scnView.scene?.rootNode.addChildNode(keyLight)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// MARK: - AvatarPlaceholderView

private struct AvatarPlaceholderView: View {
    let slot: MeshyModelSlot
    @State private var pulse: Double = 0

    var body: some View {
        ZStack {
            // Animated background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.14),
                    Color(red: 0.05, green: 0.05, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Canvas stick figure
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    drawPlaceholder(ctx: ctx, size: size, t: t, slot: slot)
                }
            }

            // Bottom overlay
            VStack {
                Spacer()
                VStack(spacing: 6) {
                    Text(slot.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                        Text("Drop \(slot.usdzFileName) into Models3D/")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.55))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func drawPlaceholder(ctx: GraphicsContext, size: CGSize, t: Double, slot: MeshyModelSlot) {
        let cx = size.width / 2
        let cy = size.height * 0.42
        let scale = min(size.width, size.height) * 0.55

        let sway = sin(t * 1.4) * 0.06
        let bobY = sin(t * 2.0) * 0.02 * scale

        // Glow beneath figure
        var glowCtx = ctx
        glowCtx.addFilter(.blur(radius: 18))
        let glowColor: Color
        switch slot.category {
        case .character:   glowColor = Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.35)
        case .environment: glowColor = Color(red: 0.2, green: 0.9, blue: 0.5).opacity(0.25)
        case .prop:        glowColor = Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.30)
        }
        glowCtx.fill(
            Path(ellipseIn: CGRect(x: cx - 30, y: cy + scale * 0.35, width: 60, height: 18)),
            with: .color(glowColor)
        )

        let transform = CGAffineTransform(translationX: cx, y: cy + bobY)
            .rotated(by: sway)

        switch slot.category {
        case .character:
            drawCharacterFigure(ctx: ctx, transform: transform, scale: scale, t: t)
        case .environment:
            drawEnvironmentIcon(ctx: ctx, size: size, t: t, slot: slot)
        case .prop:
            drawPropIcon(ctx: ctx, cx: cx, cy: cy, scale: scale, t: t, slot: slot)
        }

        // Corner cube wireframe hint
        drawWireframeCube(ctx: ctx, cx: cx, cy: cy - scale * 0.38, size: scale * 0.25, t: t)
    }

    private func drawCharacterFigure(ctx: GraphicsContext, transform: CGAffineTransform, scale: CGFloat, t: Double) {
        let lineColor = Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.90)
        let jointColor = Color(red: 0.4, green: 0.85, blue: 1.0)
        var path = Path()

        let h = scale * 0.72
        let headR = h * 0.13
        let shoulderY = -h * 0.35
        let hipY = shoulderY + h * 0.30
        let kneeY = hipY + h * 0.25
        let ankleY = kneeY + h * 0.25

        let armSwing = sin(t * 2.2) * 0.18
        let legSwing = sin(t * 2.2 + .pi) * 0.18

        // Head
        path.addEllipse(in: CGRect(x: -headR, y: -h * 0.50 - headR, width: headR * 2, height: headR * 2))

        // Spine
        path.move(to: CGPoint(x: 0, y: -h * 0.37))
        path.addLine(to: CGPoint(x: 0, y: hipY))

        // Shoulders
        path.move(to: CGPoint(x: -h * 0.18, y: shoulderY))
        path.addLine(to: CGPoint(x: h * 0.18, y: shoulderY))

        // Left arm
        let lElbow = CGPoint(x: -h * 0.24 + armSwing * h * 0.10, y: shoulderY + h * 0.18)
        let lHand  = CGPoint(x: -h * 0.28 + armSwing * h * 0.15, y: shoulderY + h * 0.35)
        path.move(to: CGPoint(x: -h * 0.18, y: shoulderY))
        path.addLine(to: lElbow)
        path.addLine(to: lHand)

        // Right arm
        let rElbow = CGPoint(x: h * 0.24 - armSwing * h * 0.10, y: shoulderY + h * 0.18)
        let rHand  = CGPoint(x: h * 0.28 - armSwing * h * 0.15, y: shoulderY + h * 0.35)
        path.move(to: CGPoint(x: h * 0.18, y: shoulderY))
        path.addLine(to: rElbow)
        path.addLine(to: rHand)

        // Left leg
        let lKnee = CGPoint(x: -h * 0.08 - legSwing * h * 0.08, y: kneeY)
        let lAnkle = CGPoint(x: -h * 0.06, y: ankleY)
        path.move(to: CGPoint(x: -h * 0.08, y: hipY))
        path.addLine(to: lKnee)
        path.addLine(to: lAnkle)

        // Right leg
        let rKnee = CGPoint(x: h * 0.08 + legSwing * h * 0.08, y: kneeY)
        let rAnkle = CGPoint(x: h * 0.06, y: ankleY)
        path.move(to: CGPoint(x: h * 0.08, y: hipY))
        path.addLine(to: rKnee)
        path.addLine(to: rAnkle)

        // Apply transform
        let transformed = path.applying(transform)

        var gCtx = ctx
        gCtx.addFilter(.blur(radius: 3))
        gCtx.stroke(transformed, with: .color(lineColor.opacity(0.5)), lineWidth: 3.5)
        ctx.stroke(transformed, with: .color(lineColor), lineWidth: 2)

        // Joints
        let joints: [CGPoint] = [
            CGPoint(x: 0, y: -h * 0.50),
            CGPoint(x: -h * 0.18, y: shoulderY), CGPoint(x: h * 0.18, y: shoulderY),
            CGPoint(x: 0, y: hipY),
            lElbow, rElbow, lKnee, rKnee, lAnkle, rAnkle
        ]
        for j in joints {
            let tp = j.applying(transform)
            ctx.fill(Path(ellipseIn: CGRect(x: tp.x - 3, y: tp.y - 3, width: 6, height: 6)),
                     with: .color(jointColor))
        }
    }

    private func drawEnvironmentIcon(ctx: GraphicsContext, size: CGSize, t: Double, slot: MeshyModelSlot) {
        let cx = size.width / 2
        let cy = size.height * 0.42
        let baseColor: Color

        switch slot {
        case .veniceBachHoop:
            baseColor = Color(red: 0.3, green: 0.6, blue: 0.9)
            // Simplified hoop silhouette
            var path = Path()
            path.addEllipse(in: CGRect(x: cx - 18, y: cy - 30, width: 36, height: 10))
            path.move(to: CGPoint(x: cx, y: cy - 25))
            path.addLine(to: CGPoint(x: cx, y: cy + 50))
            ctx.stroke(path, with: .color(baseColor.opacity(0.85)), lineWidth: 3)
        case .basketballSet, .indoorCourt:
            baseColor = Color(red: 0.9, green: 0.55, blue: 0.2)
            var path = Path()
            path.addRect(CGRect(x: cx - 45, y: cy - 10, width: 90, height: 60))
            path.addEllipse(in: CGRect(x: cx - 18, y: cy - 20, width: 36, height: 10))
            ctx.stroke(path, with: .color(baseColor.opacity(0.85)), lineWidth: 2.5)
        case .soccerStadium:
            baseColor = Color(red: 0.25, green: 0.75, blue: 0.35)
            var path = Path()
            path.addEllipse(in: CGRect(x: cx - 55, y: cy - 20, width: 110, height: 70))
            path.addRect(CGRect(x: cx - 20, y: cy - 25, width: 40, height: 40))
            ctx.stroke(path, with: .color(baseColor.opacity(0.85)), lineWidth: 2.5)
        default:
            baseColor = Color(red: 0.5, green: 0.7, blue: 0.9)
            var path = Path()
            path.addRect(CGRect(x: cx - 40, y: cy - 30, width: 80, height: 70))
            ctx.stroke(path, with: .color(baseColor.opacity(0.85)), lineWidth: 2.5)
        }
    }

    private func drawPropIcon(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat, t: Double, slot: MeshyModelSlot) {
        let spin = t * 1.2
        let r = scale * 0.28
        let color: Color

        switch slot {
        case .soccerBall:  color = Color(red: 1.0, green: 1.0, blue: 1.0)
        case .tennisBall:  color = Color(red: 0.8, green: 1.0, blue: 0.2)
        case .tennisRacket: color = Color(red: 0.9, green: 0.6, blue: 0.2)
        default: color = .white
        }

        var ballPath = Path()
        ballPath.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

        var gCtx = ctx
        gCtx.addFilter(.blur(radius: 8))
        gCtx.stroke(ballPath, with: .color(color.opacity(0.4)), lineWidth: 12)
        ctx.stroke(ballPath, with: .color(color.opacity(0.85)), lineWidth: 2.5)

        // Seam lines
        var seam = Path()
        let s1 = CGPoint(x: cx + r * cos(spin), y: cy + r * 0.5 * sin(spin))
        let s2 = CGPoint(x: cx + r * cos(spin + .pi), y: cy + r * 0.5 * sin(spin + .pi))
        seam.move(to: s1)
        seam.addQuadCurve(to: s2, control: CGPoint(x: cx, y: cy - r * 0.6))
        ctx.stroke(seam, with: .color(color.opacity(0.50)), lineWidth: 1.5)
    }

    private func drawWireframeCube(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, size: CGFloat, t: Double) {
        let angle = t * 0.6
        let s = size * 0.5
        let color = Color.white.opacity(0.18)

        func project(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
            let rx = x * cos(angle) - z * sin(angle)
            let rz = x * sin(angle) + z * cos(angle)
            let ry = y
            let perspective: CGFloat = 1.8
            let px = rx / (rz / (s * perspective) + 1)
            let py = ry / (rz / (s * perspective) + 1)
            return CGPoint(x: cx + px, y: cy + py)
        }

        let verts: [(CGFloat, CGFloat, CGFloat)] = [
            (-s, -s, -s), (s, -s, -s), (s, s, -s), (-s, s, -s),
            (-s, -s,  s), (s, -s,  s), (s, s,  s), (-s, s,  s)
        ]
        let edges: [(Int, Int)] = [
            (0,1),(1,2),(2,3),(3,0),
            (4,5),(5,6),(6,7),(7,4),
            (0,4),(1,5),(2,6),(3,7)
        ]
        var path = Path()
        for e in edges {
            let a = project(verts[e.0].0, verts[e.0].1, verts[e.0].2)
            let b = project(verts[e.1].0, verts[e.1].1, verts[e.1].2)
            path.move(to: a)
            path.addLine(to: b)
        }
        ctx.stroke(path, with: .color(color), lineWidth: 1)
    }
}

// MARK: - Preview

#if DEBUG
struct MeshyAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            MeshyAvatarView(slot: .elijahBonds)
                .frame(width: 160, height: 240)
            MeshyAvatarView(slot: .soccerBall)
                .frame(width: 160, height: 240)
            MeshyAvatarView(slot: .soccerStadium)
                .frame(width: 160, height: 240)
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif
