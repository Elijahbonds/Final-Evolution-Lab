import SwiftUI

struct PS2GamepadOverlay: View {
    let onFaceButton: (PS2FaceButton) -> Void
    let onDPad: (PS2DPadDirection) -> Void
    var onLeftStick: (CGPoint) -> Void = { _ in }
    var onRightStick: (CGPoint) -> Void = { _ in }
    var onLeftShoulder: () -> Void = {}
    var onRightShoulder: () -> Void = {}
    var accentColor: Color = Theme.brandBlue
    var isActive: Bool = true
    @State private var leftStickOffset: CGSize = .zero
    @State private var rightStickOffset: CGSize = .zero
    @State private var pressedFaceButton: PS2FaceButton? = nil
    @State private var pressedDPadDirection: PS2DPadDirection? = nil

    private let analogRange: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let gutterWidth = min(geo.size.width * 0.22, 100)
            let bottomInset = max(geo.safeAreaInsets.bottom, 10)
            let sideInset = max(geo.safeAreaInsets.leading, 8)

            Color.clear
                .allowsHitTesting(false)
                .overlay(alignment: .top) {
                    HStack {
                        shoulderButton("L1", action: onLeftShoulder)
                        Spacer(minLength: 0)
                            .allowsHitTesting(false)
                        shoulderButton("R1", action: onRightShoulder)
                    }
                    .padding(.horizontal, sideInset + 4)
                    .padding(.top, 2)
                    .allowsHitTesting(true)
                }
                .overlay(alignment: .bottomLeading) {
                    leftGutter(width: gutterWidth)
                        .padding(.leading, sideInset)
                        .padding(.bottom, bottomInset)
                        .allowsHitTesting(true)
                }
                .overlay(alignment: .bottomTrailing) {
                    rightGutter(width: gutterWidth)
                        .padding(.trailing, max(geo.safeAreaInsets.trailing, 8))
                        .padding(.bottom, bottomInset)
                        .allowsHitTesting(true)
                }
        }
        .allowsHitTesting(false)
        .opacity(isActive ? 1 : 0.35)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game controller")
    }

    private func leftGutter(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            dPadCluster
            analogStick(
                title: "L",
                offset: $leftStickOffset,
                onChanged: onLeftStick
            )
        }
        .frame(width: width, alignment: .leading)
    }

    private func rightGutter(width: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            faceButtonCluster
            analogStick(
                title: "R",
                offset: $rightStickOffset,
                onChanged: onRightStick
            )
        }
        .frame(width: width, alignment: .trailing)
    }

    private var dPadCluster: some View {
        VStack(spacing: 1) {
            dPadButton(.up, icon: "chevron.up")

            HStack(spacing: 1) {
                dPadButton(.left, icon: "chevron.left")

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.10).opacity(0.45))
                    .frame(width: 12, height: 12)

                dPadButton(.right, icon: "chevron.right")
            }

            dPadButton(.down, icon: "chevron.down")
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.28))
        )
    }

    private func dPadButton(_ direction: PS2DPadDirection, icon: String) -> some View {
        let isPressed = pressedDPadDirection == direction
        return Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white.opacity(isPressed ? 1.0 : 0.8))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: isPressed ? 0.35 : 0.18).opacity(0.75))
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isActive else { return }
                        if pressedDPadDirection != direction {
                            pressedDPadDirection = direction
                            onDPad(direction)
                            FELHaptics.dunkChargeRelease()
                        }
                    }
                    .onEnded { _ in
                        pressedDPadDirection = nil
                    }
            )
            .disabled(!isActive)
    }

    private var faceButtonCluster: some View {
        let btnSize: CGFloat = 40

        return VStack(spacing: 2) {
            ps2FaceButton(.triangle, symbol: "△", color: Color(red: 0.3, green: 0.78, blue: 0.47), size: btnSize)

            HStack(spacing: 14) {
                ps2FaceButton(.square, symbol: "□", color: Color(red: 0.96, green: 0.44, blue: 0.71), size: btnSize)
                ps2FaceButton(.circle, symbol: "○", color: Color(red: 0.97, green: 0.44, blue: 0.44), size: btnSize)
            }

            ps2FaceButton(.cross, symbol: "✕", color: Color(red: 0.38, green: 0.65, blue: 0.98), size: btnSize)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.22))
        )
    }

    private func ps2FaceButton(_ button: PS2FaceButton, symbol: String, color: Color, size: CGFloat) -> some View {
        let isPressed = pressedFaceButton == button
        return Text(symbol)
            .font(.system(size: 16, weight: .black))
            .foregroundStyle(isPressed ? .white : color)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isPressed ? color : color.opacity(0.14))
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 1.5)
                    )
            )
            .shadow(color: color.opacity(0.25), radius: 3)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isActive else { return }
                        if pressedFaceButton != button {
                            pressedFaceButton = button
                            onFaceButton(button)
                            FELHaptics.actionSuccess(isCritical: false)
                        }
                    }
                    .onEnded { _ in
                        pressedFaceButton = nil
                    }
            )
            .disabled(!isActive)
    }

    private func shoulderButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 44, height: 20)
                .background(
                    Capsule()
                        .fill(Color(white: 0.16).opacity(0.65))
                )
        }
        .disabled(!isActive)
        .sensoryFeedback(.impact(weight: .light), trigger: label)
    }

    private func analogStick(
        title: String,
        offset: Binding<CGSize>,
        onChanged: @escaping (CGPoint) -> Void
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.12).opacity(0.55))
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.24), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .offset(offset.wrappedValue)

            Text(title)
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
                .offset(y: 22)
        }
        .contentShape(Circle().size(width: 56, height: 56))
        .frame(width: 56, height: 56)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isActive else { return }
                    let clamped = clampToRange(value.translation, radius: analogRange)
                    offset.wrappedValue = clamped
                    onChanged(normalizedVector(for: clamped))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                        offset.wrappedValue = .zero
                    }
                    onChanged(.zero)
                }
        )
    }

    private func clampToRange(_ translation: CGSize, radius: CGFloat) -> CGSize {
        let length = sqrt(translation.width * translation.width + translation.height * translation.height)
        guard length > radius, length > 0 else { return translation }
        let scale = radius / length
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }

    private func normalizedVector(for translation: CGSize) -> CGPoint {
        guard analogRange > 0 else { return .zero }
        let normalizedX = max(-1, min(1, translation.width / analogRange))
        let normalizedY = max(-1, min(1, -translation.height / analogRange))
        return CGPoint(x: normalizedX, y: normalizedY)
    }
}

nonisolated enum PS2FaceButton: String, Sendable {
    case triangle
    case square
    case circle
    case cross
}

nonisolated enum PS2DPadDirection: String, Sendable {
    case up
    case down
    case left
    case right
}
