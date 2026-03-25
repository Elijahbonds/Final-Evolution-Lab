import SwiftUI

/// PlayStation-style virtual controller: D-pad (left), left stick (left), face buttons △ □ ○ ✕ (right), right stick (right).
/// Console-standard layout; touch targets optimized for mobile (thumb-friendly). Optional Cross down/up for charge mechanics.
struct PS2GamepadOverlay: View {
    let onFaceButton: (PS2FaceButton) -> Void
    let onDPad: (PS2DPadDirection) -> Void
    var onLeftStick: (CGPoint) -> Void = { _ in }
    var onRightStick: (CGPoint) -> Void = { _ in }
    var onLeftShoulder: () -> Void = {}
    var onRightShoulder: () -> Void = {}
    /// When set, Cross uses press/release (down/up) instead of single tap — for charge-and-release gameplay.
    var onCrossDown: (() -> Void)? = nil
    var onCrossUp: (() -> Void)? = nil
    var accentColor: Color = Theme.brandBlue
    var isActive: Bool = true
    /// Mobile-optimized: larger touch targets (52pt face, 48pt d-pad, 64pt stick hit area).
    var mobileOptimized: Bool = true
    @State private var leftStickOffset: CGSize = .zero
    @State private var rightStickOffset: CGSize = .zero

    private var faceButtonSize: CGFloat { mobileOptimized ? 52 : 46 }
    private var dPadButtonSize: CGFloat { mobileOptimized ? 48 : 44 }
    private var stickHitSize: CGFloat { mobileOptimized ? 64 : 60 }
    private let analogRange: CGFloat = 30
    private let stickDeadzone: CGFloat = 10

    var body: some View {
        ZStack {
            PS2ControllerShellView()

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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Virtual controller. D-pad and left stick on the left, face buttons and right stick on the right. Hold Cross to charge, release to fire.")
    }

    private var dPadCluster: some View {
        VStack(spacing: 1) {
            dPadButton(.up, icon: "chevron.up")

            HStack(spacing: 1) {
                dPadButton(.left, icon: "chevron.left")

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.12).opacity(0.4))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(Color(white: 0.10).opacity(0.5))
                            .frame(width: 6, height: 6)
                    )

                dPadButton(.right, icon: "chevron.right")
            }

            dPadButton(.down, icon: "chevron.down")
        }
    }

    private func dPadButton(_ direction: PS2DPadDirection, icon: String) -> some View {
        let size = dPadButtonSize
        return Button {
            onDPad(direction)
        } label: {
            Image(systemName: icon)
                .font(.system(size: mobileOptimized ? 14 : 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.26).opacity(0.5), Color(white: 0.16).opacity(0.48)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(white: 0.15).opacity(0.6), lineWidth: 0.5)
                )
        }
        .disabled(!isActive)
        .sensoryFeedback(.impact(weight: .light), trigger: direction.rawValue)
    }

    private var faceButtonCluster: some View {
        let btnSize = faceButtonSize
        let spacing: CGFloat = mobileOptimized ? 8 : 3
        return VStack(spacing: spacing) {
            ps2FaceButton(.triangle, symbol: "△", color: Color(red: 0.3, green: 0.78, blue: 0.47), size: btnSize)

            HStack(spacing: mobileOptimized ? 22 : 18) {
                ps2FaceButton(.square, symbol: "□", color: Color(red: 0.96, green: 0.44, blue: 0.71), size: btnSize)
                ps2FaceButton(.circle, symbol: "○", color: Color(red: 0.97, green: 0.44, blue: 0.44), size: btnSize)
            }

            crossButton(size: btnSize)
        }
    }

    @ViewBuilder
    private func crossButton(size: CGFloat) -> some View {
        let color = Color(red: 0.38, green: 0.65, blue: 0.98)
        if onCrossDown != nil, onCrossUp != nil {
            Text("✕")
                .font(.system(size: mobileOptimized ? 20 : 18, weight: .black))
                .foregroundStyle(color.opacity(0.92))
                .frame(width: size, height: size)
                .contentShape(Circle())
                .background(
                    Circle()
                        .fill(color.opacity(0.28))
                        .overlay(Circle().stroke(color.opacity(0.55), lineWidth: 2))
                )
                .shadow(color: color.opacity(0.2), radius: 3)
                .onLongPressGesture(minimumDuration: 1000, pressing: { pressing in
                    guard isActive else { return }
                    if pressing {
                        onCrossDown?()
                    } else {
                        onCrossUp?()
                    }
                }, perform: {})
        } else {
            ps2FaceButton(.cross, symbol: "✕", color: color, size: size)
        }
    }

    private func ps2FaceButton(_ button: PS2FaceButton, symbol: String, color: Color, size: CGFloat) -> some View {
        Button {
            onFaceButton(button)
        } label: {
            Text(symbol)
                .font(.system(size: mobileOptimized ? 20 : 18, weight: .black))
                .foregroundStyle(color.opacity(0.92))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color.opacity(0.28))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.55), lineWidth: 2)
                        )
                )
                .shadow(color: color.opacity(0.2), radius: 3)
        }
        .buttonStyle(.plain)
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
                                colors: [Color(white: 0.28).opacity(0.5), Color(white: 0.18).opacity(0.48)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color(white: 0.15).opacity(0.6), lineWidth: 0.5)
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
                        colors: [Color(white: 0.18).opacity(0.45), Color(white: 0.10).opacity(0.4)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 24
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.12).opacity(0.5), lineWidth: 1.5)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.34).opacity(0.65), Color(white: 0.22).opacity(0.6), Color(white: 0.18).opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.26).opacity(0.7), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .offset(offset.wrappedValue)

            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .offset(y: 20)
        }
        .contentShape(Circle().size(width: stickHitSize, height: stickHitSize))
        .frame(width: stickHitSize, height: stickHitSize)
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
        let length = sqrt(translation.width * translation.width + translation.height * translation.height)
        guard length > stickDeadzone else { return .zero }
        let effectiveRange = analogRange - stickDeadzone
        let scale = (length - stickDeadzone) / max(0.01, effectiveRange)
        let nx = max(-1, min(1, (translation.width / max(0.01, length)) * scale))
        let ny = max(-1, min(1, (-translation.height / max(0.01, length)) * scale))
        return CGPoint(x: nx, y: ny)
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
