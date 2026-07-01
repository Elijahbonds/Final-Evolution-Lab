import SwiftUI

struct ArenaPadOverlay: View {
    let onFaceButton: (ArenaPadFaceButton) -> Void
    let onDPad: (ArenaPadDPadDirection) -> Void
    var onLeftStick: (CGPoint) -> Void = { _ in }
    var onRightStick: (CGPoint) -> Void = { _ in }
    var onLeftShoulder: () -> Void = {}
    var onRightShoulder: () -> Void = {}
    var accentColor: Color = Theme.brandBlue
    var isActive: Bool = true
    @State private var leftStickOffset: CGSize = .zero
    @State private var rightStickOffset: CGSize = .zero

    private let analogRange: CGFloat = 20

    var body: some View {
        ZStack {
            ArenaPadShellView()

            HStack {
                shoulderButton("L1", action: onLeftShoulder)
                    .padding(.leading, 14)
                Spacer()
                shoulderButton("R1", action: onRightShoulder)
                    .padding(.trailing, 14)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 4)

            HStack(alignment: .bottom, spacing: 0) {
                VStack(spacing: 6) {
                    dPadCluster
                    analogStick(
                        title: "L",
                        offset: $leftStickOffset,
                        onChanged: onLeftStick
                    )
                }
                .padding(.leading, 10)
                .padding(.bottom, 14)

                Spacer()

                VStack(spacing: 6) {
                    faceButtonCluster
                    analogStick(
                        title: "R",
                        offset: $rightStickOffset,
                        onChanged: onRightStick
                    )
                }
                .padding(.trailing, 10)
                .padding(.bottom, 14)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .opacity(isActive ? 1 : 0.3)
    }

    private var dPadCluster: some View {
        VStack(spacing: 1) {
            dPadButton(.up, icon: "chevron.up")

            HStack(spacing: 1) {
                dPadButton(.left, icon: "chevron.left")

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.10).opacity(0.6))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(Color(white: 0.08))
                            .frame(width: 6, height: 6)
                    )

                dPadButton(.right, icon: "chevron.right")
            }

            dPadButton(.down, icon: "chevron.down")
        }
    }

    private func dPadButton(_ direction: ArenaPadDPadDirection, icon: String) -> some View {
        Button {
            onDPad(direction)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.22).opacity(0.9), Color(white: 0.12).opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(white: 0.08), lineWidth: 0.5)
                )
        }
        .disabled(!isActive)
        .sensoryFeedback(.impact(weight: .light), trigger: direction.rawValue)
    }

    private var faceButtonCluster: some View {
        let btnSize: CGFloat = 46

        return VStack(spacing: 3) {
            ps2FaceButton(.triangle, symbol: "△", color: Color(red: 0.3, green: 0.78, blue: 0.47), size: btnSize)

            HStack(spacing: 18) {
                ps2FaceButton(.square, symbol: "□", color: Color(red: 0.96, green: 0.44, blue: 0.71), size: btnSize)
                ps2FaceButton(.circle, symbol: "○", color: Color(red: 0.97, green: 0.44, blue: 0.44), size: btnSize)
            }

            ps2FaceButton(.cross, symbol: "✕", color: Color(red: 0.38, green: 0.65, blue: 0.98), size: btnSize)
        }
    }

    private func ps2FaceButton(_ button: ArenaPadFaceButton, symbol: String, color: Color, size: CGFloat) -> some View {
        Button {
            onFaceButton(button)
        } label: {
            Text(symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.45), lineWidth: 2)
                        )
                )
                .shadow(color: color.opacity(0.3), radius: 4)
        }
        .disabled(!isActive)
        .sensoryFeedback(.impact(weight: .medium), trigger: button.rawValue)
    }

    private func shoulderButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 50, height: 22)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.26).opacity(0.9), Color(white: 0.15).opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color(white: 0.10), lineWidth: 0.5)
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
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.15).opacity(0.8), Color(white: 0.08).opacity(0.8)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 24
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.06), lineWidth: 1.5)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.32), Color(white: 0.20), Color(white: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.24), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                .offset(offset.wrappedValue)

            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .offset(y: 20)
        }
        .contentShape(Circle().size(width: 60, height: 60))
        .frame(width: 60, height: 60)
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

nonisolated enum ArenaPadFaceButton: String, Sendable {
    case triangle
    case square
    case circle
    case cross
}

nonisolated enum ArenaPadDPadDirection: String, Sendable {
    case up
    case down
    case left
    case right
}
