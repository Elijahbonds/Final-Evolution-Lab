import SwiftUI

/// Phase 2 gate demo: the shared controller driving a live test scene,
/// built entirely from `FELDesign` tokens. Supports portrait and landscape.
///
/// Left stick / D-pad move the player marker; right stick aims the reticle;
/// face buttons, bumpers and triggers light the input monitor and pulse the
/// arena. Reachable from Settings → Developer, or the `-ControllerTestScene`
/// launch argument.
struct ControllerTestSceneView: View {
    @State private var pad = FELGamepadState()
    @State private var playerPosition: CGPoint = .zero
    @State private var aimAngle: Double = 0
    @State private var lastEvent: String = "—"
    @State private var pulseColor: Color = .clear
    @State private var pulseAmount: Double = 0
    @Environment(\.dismiss) private var dismiss

    private let playerSpeed: Double = 260 // pt/s at full deflection

    var body: some View {
        TimelineView(.animation) { timeline in
            arena(now: timeline.date.timeIntervalSinceReferenceDate)
        }
        .overlay {
            FELGamepadView(state: pad)
        }
        .overlay(alignment: .top) {
            topBar
        }
        .background(FELDesign.Colors.ink)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .onAppear { configurePad() }
    }

    // MARK: - Scene

    private func arena(now: TimeInterval) -> some View {
        GeometryReader { proxy in
            let bounds = proxy.size
            ZStack {
                arenaFloor(in: bounds)
                playerMarker
                    .position(
                        x: bounds.width / 2 + playerPosition.x,
                        y: bounds.height / 2 - playerPosition.y
                    )
            }
            .onChange(of: now) { previous, current in
                step(deltaTime: min(current - previous, 1.0 / 20.0), bounds: bounds)
            }
        }
        .ignoresSafeArea()
    }

    private func arenaFloor(in bounds: CGSize) -> some View {
        Canvas { context, size in
            let spacing: CGFloat = 44
            var lines = Path()
            var x: CGFloat = 0
            while x <= size.width {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(lines, with: .color(.white.opacity(0.05)), lineWidth: 1)

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let ring = Path(ellipseIn: CGRect(x: center.x - 90, y: center.y - 90, width: 180, height: 180))
            context.stroke(ring, with: .color(.white.opacity(0.08)), lineWidth: 1)
        }
        .background(FELDesign.Colors.ink)
        .overlay(
            Rectangle()
                .fill(pulseColor.opacity(pulseAmount * 0.12))
                .ignoresSafeArea()
        )
    }

    private var playerMarker: some View {
        ZStack {
            // Aim reticle driven by the right stick
            Capsule()
                .fill(FELDesign.Colors.purple.opacity(pad.rightStick == .zero ? 0.25 : 0.9))
                .frame(width: 44, height: 3)
                .offset(x: 40)
                .rotationEffect(.radians(-aimAngle))

            Circle()
                .fill(FELDesign.Colors.cyan)
                .frame(width: 26, height: 26)
                .shadow(color: FELDesign.Colors.glow(FELDesign.Colors.cyan, 0.6), radius: 14)

            Circle()
                .stroke(FELDesign.Colors.cyan.opacity(0.35), lineWidth: FELDesign.Stroke.hairline)
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Top bar (tokens on display)

    private var topBar: some View {
        HStack(spacing: FELDesign.Space.md) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(FELDesign.Colors.surfaceRaised.opacity(0.72))
                    .clipShape(Circle())
            }

            FELMicroLabel(text: "Controller Test", color: FELDesign.Colors.textSecondary)

            Spacer()

            HStack(spacing: FELDesign.Space.sm) {
                stickReadout(label: "L", value: pad.moveVector)
                stickReadout(label: "R", value: pad.rightStick)
                Text(lastEvent)
                    .font(FELDesign.Typography.stat)
                    .foregroundStyle(FELDesign.Colors.cyan)
                    .frame(minWidth: 96, alignment: .trailing)
            }
            .padding(.horizontal, FELDesign.Space.md)
            .padding(.vertical, FELDesign.Space.xs)
            .background(FELDesign.Colors.surface.opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline))
        }
        .padding(.horizontal, 120) // clear the corner shoulder/trigger stacks
        .padding(.top, FELDesign.Space.xs)
    }

    private func stickReadout(label: String, value: CGPoint) -> some View {
        Text("\(label) \(String(format: "%+.2f", value.x)) \(String(format: "%+.2f", value.y))")
            .font(FELDesign.Typography.statSmall)
            .foregroundStyle(value == .zero ? FELDesign.Colors.textTertiary : FELDesign.Colors.textPrimary)
    }

    // MARK: - Simulation

    private func configurePad() {
        pad.onEvent = { event in
            switch event {
            case .buttonDown(let button):
                lastEvent = button.glyph
                pulse(button == .triangle ? FELDesign.Colors.purple : FELDesign.Colors.cyan)
            case .dpadDown(let direction):
                lastEvent = "DPAD \(direction.rawValue.uppercased())"
            case .buttonUp, .dpadUp:
                break
            }
        }
    }

    private func step(deltaTime: TimeInterval, bounds: CGSize) {
        let move = pad.moveVector
        if move != .zero {
            playerPosition.x += move.x * playerSpeed * deltaTime
            playerPosition.y += move.y * playerSpeed * deltaTime
            let xLimit = bounds.width / 2 - 40
            let yLimit = bounds.height / 2 - 40
            playerPosition.x = max(-xLimit, min(xLimit, playerPosition.x))
            playerPosition.y = max(-yLimit, min(yLimit, playerPosition.y))
        }

        let aim = pad.rightStick
        if aim != .zero {
            aimAngle = atan2(aim.y, aim.x)
        }

        if pulseAmount > 0 {
            pulseAmount = max(0, pulseAmount - deltaTime * 3)
        }
    }

    private func pulse(_ color: Color) {
        pulseColor = color
        pulseAmount = 1
    }
}

#Preview(traits: .landscapeLeft) {
    ControllerTestSceneView()
}
