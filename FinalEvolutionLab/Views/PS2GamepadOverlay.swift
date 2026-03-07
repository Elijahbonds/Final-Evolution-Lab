import SwiftUI

struct PS2GamepadOverlay: View {
    let onFaceButton: (PS2FaceButton) -> Void
    let onDPad: (PS2DPadDirection) -> Void
    var accentColor: Color = Theme.brandBlue
    var isActive: Bool = true

    var body: some View {
        ZStack {
            PS2ControllerShellView()

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    dPadCluster
                        .padding(.leading, 12)
                        .padding(.bottom, 44)

                    Spacer()

                    faceButtonCluster
                        .padding(.trailing, 12)
                        .padding(.bottom, 44)
                }
            }
        }
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
        .opacity(isActive ? 1 : 0.3)
    }

    private func dPadButton(_ direction: PS2DPadDirection, icon: String) -> some View {
        Button {
            onDPad(direction)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 52, height: 52)
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
        .opacity(isActive ? 1 : 0.3)
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
