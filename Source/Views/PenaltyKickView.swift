import SwiftUI
import Combine
import Combine

/// Simple penalty-kick mini-view: aim with left/right, set power, then shoot vs keeper.
struct PenaltyKickView: View {
    let mode: GameMode
    let onExit: () -> Void
    let onShotResolved: (_ shotQuality: Double, _ wasGoal: Bool) -> Void

    @State private var aim: Double = 0 /// -1 = left, 0 = center, 1 = right
    @State private var power: Double = 0
    @State private var isCharging: Bool = false
    @State private var keeperGuess: Double = 0
    @State private var didShoot: Bool = false
    @State private var wasGoal: Bool = false

    private var accentColor: Color { mode.accentColor }

    var body: some View {
        VStack(spacing: 24) {
            header
            pitchView
            powerBar
            aimControls
            shootButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear {
            randomizeKeeper()
        }
        .onPhysicalControllerCross(down: { isCharging = true }, up: { isCharging = false; takeShot() })
        .overlay(alignment: .topLeading) {
            exitButton
        }
        .onReceive(Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()) { _ in
            if isCharging {
                power = min(1.0, power + 0.02)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("PENALTY SHOOTOUT")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
            Spacer()
        }
    }

    private var pitchView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color.green.opacity(0.4), Color.green.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                .frame(height: 140)
            VStack {
                HStack {
                    keeperColumn(side: -1)
                    keeperColumn(side: 0)
                    keeperColumn(side: 1)
                }
                .padding(.horizontal, 24)
                Spacer()
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .offset(x: CGFloat(aim) * 40)
                    .shadow(radius: 4)
            }
            .padding(.vertical, 16)
        }
    }

    private func keeperColumn(side: Double) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(side == keeperGuess ? Color.white.opacity(0.3) : Color.clear)
            )
            .frame(height: 56)
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
                        .frame(width: geo.size.width * CGFloat(max(0.05, power)))
                }
            }
            .frame(height: 12)
        }
    }

    private var aimControls: some View {
        HStack(spacing: 16) {
            Button {
                aim = max(-1, aim - 0.5)
            } label: {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 22, weight: .bold))
            }
            .buttonStyle(.plain)

            Text(aimLabel)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

            Button {
                aim = min(1, aim + 0.5)
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
    }

    private var aimLabel: String {
        switch aim {
        case ..<(-0.25): return "LEFT"
        case (-0.25)...0.25: return "CENTER"
        default: return "RIGHT"
        }
    }

    private var shootButton: some View {
        Button {
            takeShot()
        } label: {
            Text(didShoot ? (wasGoal ? "GOAL!" : "SAVED") : "HOLD ✕ TO CHARGE, RELEASE TO SHOOT")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(1.5)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(accentColor)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shoot the penalty")
        .accessibilityHint("Aim with left or right; hold Cross to build power, release to shoot")
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

    private func randomizeKeeper() {
        keeperGuess = [-1, 0, 1].randomElement() ?? 0
    }

    private func takeShot() {
        guard !didShoot else { return }
        didShoot = true
        let keeperOnSide: Bool
        switch aimLabel {
        case "LEFT": keeperOnSide = keeperGuess == -1
        case "CENTER": keeperOnSide = keeperGuess == 0
        default: keeperOnSide = keeperGuess == 1
        }
        let baseQuality = 0.6 + power * 0.4
        if keeperOnSide {
            wasGoal = Double.random(in: 0..<1) < 0.25
        } else {
            wasGoal = Double.random(in: 0..<1) < 0.9
        }
        let quality = wasGoal ? baseQuality : max(0.4, baseQuality - 0.25)
        onShotResolved(quality, wasGoal)
    }
}

