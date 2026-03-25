import SwiftUI
import Combine
import Combine

/// Simple golf swing mini-view: set power and slight aim, then swing for closest-to-pin feel.
struct GolfSwingView: View {
    let mode: GameMode
    let onExit: () -> Void
    let onSwingResolved: (_ shotQuality: Double) -> Void

    @State private var power: Double = 0.4
    @State private var aimOffset: Double = 0 /// -1 left, 0 center, 1 right
    @State private var isCharging: Bool = false
    @State private var didSwing: Bool = false

    private var accentColor: Color { mode.accentColor }

    var body: some View {
        VStack(spacing: 24) {
            header
            greenView
            powerBar
            aimControls
            swingButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onPhysicalControllerCross(down: { isCharging = true }, up: { isCharging = false; takeSwing() })
        .onReceive(Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()) { _ in
            if isCharging {
                power = min(1.0, power + 0.018)
            }
        }
        .overlay(alignment: .topLeading) {
            exitButton
        }
    }

    private var header: some View {
        HStack {
            Text("CLOSEST TO PIN")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
            Spacer()
        }
    }

    private var greenView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(0.9), Color.green.opacity(0.5)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 140
                    )
                )
                .frame(height: 140)
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: 26, height: 26)
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .offset(x: CGFloat(aimOffset) * 40, y: CGFloat(1 - power) * 40)
                .shadow(radius: 4)
        }
    }

    private var powerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POWER")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(accentColor)
                        .frame(width: geo.size.width * CGFloat(max(0.1, power)))
                }
            }
            .frame(height: 12)
        }
    }

    private var aimControls: some View {
        HStack(spacing: 16) {
            Button {
                aimOffset = max(-1, aimOffset - 0.5)
            } label: {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 22, weight: .bold))
            }
            .buttonStyle(.plain)

            Text(aimLabel)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

            Button {
                aimOffset = min(1, aimOffset + 0.5)
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
    }

    private var aimLabel: String {
        switch aimOffset {
        case ..<(-0.25): return "LEFT"
        case (-0.25)...0.25: return "CENTER"
        default: return "RIGHT"
        }
    }

    private var swingButton: some View {
        Button {
            takeSwing()
        } label: {
            Text(didSwing ? "SWING COMPLETE" : "HOLD ✕ TO BUILD POWER, RELEASE TO SWING")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(1.3)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(accentColor)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Swing for the pin")
        .accessibilityHint("Adjust aim, then hold Cross to build power and release to swing")
    }

    private var exitButton: some View {
        Button {
            onExit()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("EXIT")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.secondary)
            .padding(8)
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.leading, 16)
    }

    private func takeSwing() {
        guard !didSwing else { return }
        didSwing = true
        // Map power + small aim offset to a quality where center & mid-high power is best.
        let powerScore = 1 - abs(power - 0.7)
        let aimPenalty = 1 - abs(aimOffset) * 0.3
        let quality = max(0.5, min(0.9, 0.6 + 0.4 * powerScore * aimPenalty))
        onSwingResolved(quality)
    }
}

