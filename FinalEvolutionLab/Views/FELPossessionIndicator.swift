import SwiftUI

/// Team-colored possession pill with a directional chevron. Flipping `side`
/// triggers a scale+opacity transition via `.id(side)`.
struct PossessionIndicator: View {
    enum Side {
        case home
        case away
    }

    let side: Side
    var homeColor: Color
    var awayColor: Color
    var homeLabel: String = "YOUR BALL"
    var awayLabel: String = "OPP BALL"

    private var tint: Color { side == .home ? homeColor : awayColor }
    private var label: String { side == .home ? homeLabel : awayLabel }
    private var chevron: String { side == .home ? "chevron.left" : "chevron.right" }

    var body: some View {
        HStack(spacing: 5) {
            if side == .home {
                Image(systemName: chevron)
            }
            Text(label.uppercased())
                .font(FELTypography.mono(9, weight: .black))
                .tracking(1.2)
            if side == .away {
                Image(systemName: chevron)
            }
        }
        .font(.system(size: 8, weight: .black))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(tint.opacity(0.16))
                .overlay {
                    Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 0.75)
                }
        }
        .id(side)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: side)
    }
}

#Preview {
    struct Demo: View {
        @State private var side: PossessionIndicator.Side = .home
        var body: some View {
            VStack(spacing: 24) {
                PossessionIndicator(
                    side: side,
                    homeColor: FELDesign.Colors.cyan,
                    awayColor: FELDesign.Colors.danger
                )
                Button("Flip") {
                    side = side == .home ? .away : .home
                }
                .buttonStyle(FELGhostButtonStyle())
            }
            .padding(40)
            .background(FELDesign.Colors.ink)
        }
    }
    return Demo()
}
