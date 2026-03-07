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

    private let analogRange: CGFloat = 22

    var body: some View {
        ZStack {
            PS2ControllerShellView()

            VStack {
                HStack {
                    shoulderButton("L1", action: onLeftShoulder)
                    Spacer()
                    shoulderButton("R1", action: onRightShoulder)
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                Spacer()
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(spacing: 10) {
                        dPadCluster
                        analogStick(
                            title: "L",
                            offset: $leftStickOffset,
                            onChanged: onLeftStick
                        )
                    }
                    .padding(.leading, 12)
                    .padding(.bottom, 22)

                    Spacer()

                    VStack(spacing: 10) {
                        faceButtonCluster
                        analogStick(
                            title: "R",
                            offset: $rightStickOffset,
                            onChanged: onRightStick
                        )
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 22)
                }
            }
        }
        .opacity(isActive ? 1 : 0.35)
    }

    private var dPadCluster: some View {
        VStack(spacing: 2) {
            dPadButton(.up, icon: "chevron.up")

            HStack(spacing: 2) {
                dPadButton(.left, icon: "chevron.left")

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.10))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .fill(Color(white: 0.08))
                            .frame(width: 8, height: 8)
                    )

                dPadButton(.right, icon: "chevron.right")
            }

            dPadButton(.down, icon: "chevron.down")
        }
    }

    private func dPadButton(_ direction: PS2DPadDirection, icon: String) -> some View {
        Button {
            onDPad(direction)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.20), Color(white: 0.11)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.08), lineWidth: 1)
                )
        }
        .disabled(!isActive)
        .sensoryFeedback(.impact(weight: .light), trigger: direction.rawValue)
    }

    private var faceButtonCluster: some View {
        let btnSize: CGFloat = 56

        return VStack(spacing: 6) {
            ps2FaceButton(.triangle, symbol: "△", color: Color(red: 0.3, green: 0.78, blue: 0.47), size: btnSize)

            HStack(spacing: 24) {
                ps2FaceButton(.square, symbol: "□", color: Color(red: 0.96, green: 0.44, blue: 0.71), size: btnSize)
                ps2FaceButton(.circle, symbol: "○", color: Color(red: 0.97, green: 0.44, blue: 0.44), size: btnSize)
            }

            ps2FaceButton(.cross, symbol: "✕", color: Color(red: 0.38, green: 0.65, blue: 0.98), size: btnSize)
        }
    }

    private func ps2FaceButton(_ button: PS2FaceButton, symbol: String, color: Color, size: CGFloat) -> some View {
        Button {
            onFaceButton(button)
        } label: {
            Text(symbol)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.4), lineWidth: 2.5)
                        )
                )
                .shadow(color: color.opacity(0.25), radius: 6)
        }
        .disabled(!isActive)
    }

    private func shoulderButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 54, height: 24)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.24), Color(white: 0.14)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color(white: 0.08), lineWidth: 1)
                )
        }
        .disabled(!isActive)
    }

    private func analogStick(
        title: String,
        offset: Binding<CGSize>,
        onChanged: @escaping (CGPoint) -> Void
    ) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.14), Color(white: 0.07)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 28
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.05), lineWidth: 2)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.18), Color(white: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                .offset(offset.wrappedValue)

            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .offset(y: 24)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isActive else { return }
                    let clamped = clampToRange(value.translation, radius: analogRange)
                    offset.wrappedValue = clamped
                    onChanged(normalizedVector(for: clamped))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.65)) {
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
