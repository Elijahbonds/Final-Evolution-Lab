import SwiftUI

/// The shared on-screen controller, designed for landscape (emulator-style).
/// Left edge: D-pad above the left stick. Right edge: face buttons above the
/// right stick. Top corners: L2/L1 and R2/R1. Monochrome premium styling —
/// white glyphs on dark glass, cyan press states; no per-button rainbow.
///
/// All input flows into one `FELGamepadState`, shared by every game mode.
struct FELGamepadView: View {
    @Bindable var state: FELGamepadState
    var isActive: Bool = true

    private let stickWellSize: CGFloat = 96
    private let stickThumbSize: CGFloat = 48
    private let stickTravel: CGFloat = 30

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                shoulderColumn(trigger: .l2, bumper: .l1, alignment: .leading)
                Spacer()
                shoulderColumn(trigger: .r2, bumper: .r1, alignment: .trailing)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                VStack(spacing: FELDesign.Space.md) {
                    dPad
                    analogStick(\.leftStick, label: "L")
                }

                Spacer(minLength: 0)

                VStack(spacing: FELDesign.Space.md) {
                    faceCluster
                    analogStick(\.rightStick, label: "R")
                }
            }
        }
        .padding(.horizontal, FELDesign.Space.lg)
        .padding(.vertical, FELDesign.Space.sm)
        .opacity(isActive ? 1 : 0.3)
        .allowsHitTesting(isActive)
        .onDisappear { state.reset() }
    }

    // MARK: - Shoulders & triggers

    private func shoulderColumn(trigger: FELPadButton, bumper: FELPadButton, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: FELDesign.Space.xxs) {
            holdButton(trigger) { pressed in
                capsuleLabel(trigger.glyph, pressed: pressed, width: 64)
            }
            holdButton(bumper) { pressed in
                capsuleLabel(bumper.glyph, pressed: pressed, width: 76)
            }
        }
    }

    private func capsuleLabel(_ text: String, pressed: Bool, width: CGFloat) -> some View {
        Text(text)
            .font(FELDesign.Typography.statSmall)
            .foregroundStyle(pressed ? FELDesign.Colors.ink : FELDesign.Colors.textSecondary)
            .frame(width: width, height: 26)
            .background(pressed ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised.opacity(0.72))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline))
            .shadow(color: pressed ? FELDesign.Colors.glow(FELDesign.Colors.cyan) : .clear, radius: 8)
    }

    // MARK: - D-pad

    private var dPad: some View {
        VStack(spacing: 2) {
            dPadKey(.up, icon: "chevron.up")
            HStack(spacing: 2) {
                dPadKey(.left, icon: "chevron.left")
                RoundedRectangle(cornerRadius: FELDesign.Radius.sm - 4)
                    .fill(FELDesign.Colors.surface.opacity(0.72))
                    .frame(width: 40, height: 40)
                dPadKey(.right, icon: "chevron.right")
            }
            dPadKey(.down, icon: "chevron.down")
        }
    }

    private func dPadKey(_ direction: FELPadDirection, icon: String) -> some View {
        let pressed = state.heldDirections.contains(direction)
        return Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(pressed ? FELDesign.Colors.ink : FELDesign.Colors.textSecondary)
            .frame(width: 44, height: 44)
            .background(pressed ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                    .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
            )
            .shadow(color: pressed ? FELDesign.Colors.glow(FELDesign.Colors.cyan) : .clear, radius: 8)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in state.press(direction) }
                    .onEnded { _ in state.release(direction) }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, held in held }
            .accessibilityLabel("D-pad \(direction.rawValue)")
    }

    // MARK: - Face buttons

    private var faceCluster: some View {
        VStack(spacing: FELDesign.Space.xxs) {
            faceButton(.triangle)
            HStack(spacing: FELDesign.Space.lg) {
                faceButton(.square)
                faceButton(.circle)
            }
            faceButton(.cross)
        }
    }

    private func faceButton(_ button: FELPadButton) -> some View {
        let pressed = state.heldButtons.contains(button)
        let accent = button == .triangle ? FELDesign.Colors.purple : FELDesign.Colors.cyan
        return Text(button.glyph)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(pressed ? FELDesign.Colors.ink : FELDesign.Colors.textPrimary)
            .frame(width: 52, height: 52)
            .background(pressed ? accent : FELDesign.Colors.surfaceRaised.opacity(0.72))
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    pressed ? accent : FELDesign.Colors.hairlineStrong,
                    lineWidth: FELDesign.Stroke.accent
                )
            )
            .shadow(color: pressed ? FELDesign.Colors.glow(accent) : .clear, radius: 10)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in state.press(button) }
                    .onEnded { _ in state.release(button) }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: pressed) { _, held in held }
            .accessibilityLabel("Button \(button.rawValue)")
    }

    // MARK: - Analog sticks

    private func analogStick(_ keyPath: ReferenceWritableKeyPath<FELGamepadState, CGPoint>, label: String) -> some View {
        let value = state[keyPath: keyPath]
        let thumbOffset = CGSize(width: value.x * stickTravel, height: -value.y * stickTravel)
        let engaged = value != .zero

        return ZStack {
            Circle()
                .fill(FELDesign.Colors.surface.opacity(0.72))
                .overlay(
                    Circle().stroke(
                        engaged ? FELDesign.Colors.cyan.opacity(0.6) : FELDesign.Colors.hairline,
                        lineWidth: FELDesign.Stroke.hairline
                    )
                )

            Circle()
                .fill(engaged ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised)
                .frame(width: stickThumbSize, height: stickThumbSize)
                .overlay(Circle().stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline))
                .shadow(color: engaged ? FELDesign.Colors.glow(FELDesign.Colors.cyan) : .black.opacity(0.4), radius: 8, y: 2)
                .offset(thumbOffset)

            Text(label)
                .font(FELDesign.Typography.statSmall)
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .offset(y: stickWellSize / 2 + FELDesign.Space.sm)
        }
        .frame(width: stickWellSize, height: stickWellSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    let raw = CGPoint(
                        x: (gesture.translation.width / stickTravel).clamped(to: -1...1),
                        y: (-gesture.translation.height / stickTravel).clamped(to: -1...1)
                    )
                    state.setStick(keyPath, raw: raw)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
                        state[keyPath: keyPath] = .zero
                    }
                }
        )
        .accessibilityLabel("\(label == "L" ? "Left" : "Right") stick")
    }

    // MARK: - Press-and-hold helper for capsule buttons

    private func holdButton<Label: View>(_ button: FELPadButton, @ViewBuilder label: (Bool) -> Label) -> some View {
        let pressed = state.heldButtons.contains(button)
        return label(pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in state.press(button) }
                    .onEnded { _ in state.release(button) }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, held in held }
            .accessibilityLabel("Button \(button.rawValue)")
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
