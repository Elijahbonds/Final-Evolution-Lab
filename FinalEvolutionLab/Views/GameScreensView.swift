import SwiftUI

struct GetReadyScreen: View {
    let title: String
    var subtitle: String? = nil
    var countdown: Int = 3
    var accentColor: Color = Theme.brandBlue
    var onComplete: () -> Void

    @State private var count: Int = 3
    @State private var timer: Task<Void, Never>?
    @State private var pulse: Bool = false
    @State private var ringScale: CGFloat = 0.5
    @State private var showGo: Bool = false
    @State private var outerRingRotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            RadialGradient(
                colors: [accentColor.opacity(0.08), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 24) {
                Text(title)
                    .font(.system(size: 32, weight: .black))
                    .italic()
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: accentColor.opacity(0.4), radius: 16)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.8))
                        .tracking(1)
                }

                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [accentColor.opacity(0.3), accentColor.opacity(0.05), accentColor.opacity(0.3)],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(outerRingRotation))

                    Circle()
                        .stroke(accentColor.opacity(0.12), lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .stroke(accentColor.opacity(0.4), lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringScale)
                        .opacity(pulse ? 0.0 : 0.6)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentColor.opacity(0.1), accentColor.opacity(0.02)],
                                center: .center,
                                startRadius: 5,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)

                    if showGo {
                        Text("GO!")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .shadow(color: accentColor.opacity(0.6), radius: 20)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    } else if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 52, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 8)
                            .contentTransition(.numericText())
                    }
                }
                .padding(.top, 8)

                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 10))
                    Text("GET READY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(5)
                }
                .foregroundStyle(.white.opacity(0.25))
                .padding(.top, 8)
            }
        }
        .onAppear {
            count = countdown
            pulse = false
            showGo = false
            ringScale = 0.5
            startCountdown()
        }
        .onDisappear {
            timer?.cancel()
        }
    }

    private func startCountdown() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            outerRingRotation = 360
        }
        timer?.cancel()
        timer = Task {
            for i in stride(from: countdown, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    count = i
                    ringScale = 0.5
                }
                withAnimation(.easeOut(duration: 0.8)) {
                    pulse = true
                    ringScale = 1.5
                }
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation { pulse = false }
                try? await Task.sleep(for: .milliseconds(800))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                count = 0
                showGo = true
            }
            try? await Task.sleep(for: .milliseconds(400))
            onComplete()
        }
    }
}

struct RoundTransitionScreen: View {
    let round: Int
    var totalRounds: Int = 3
    var label: String = "Round"
    var accentColor: Color = Theme.brandBlue
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.4))

            VStack(spacing: 16) {
                Text("\(label) \(round) of \(totalRounds)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(2)

                Text("Get ready")
                    .font(.system(size: 36, weight: .black))
                    .italic()
                    .foregroundStyle(.white)

                Button {
                    onContinue()
                } label: {
                    Text("CONTINUE")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.top, 12)
            }
        }
    }
}

struct ResultScreen: View {
    let winner: ResultWinner
    let p1Score: Int
    let p2Score: Int
    var title: String? = nil
    var accentColor: Color = Theme.brandBlue
    var onReturn: () -> Void

    enum ResultWinner {
        case p1, p2, draw
    }

    @State private var appeared = false
    @State private var trophyBounce = false
    @State private var glowPulse = false

    private var isP1Win: Bool { winner == .p1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            if isP1Win {
                ZStack {
                    RadialGradient(
                        colors: [accentColor.opacity(glowPulse ? 0.16 : 0.08), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 350
                    )
                    .ignoresSafeArea()

                    RadialGradient(
                        colors: [.yellow.opacity(glowPulse ? 0.06 : 0.02), .clear],
                        center: .top,
                        startRadius: 20,
                        endRadius: 300
                    )
                    .ignoresSafeArea()
                }
                .allowsHitTesting(false)
            }

            VStack(spacing: 24) {
                Spacer()

                if let title {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(4)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                }

                ZStack {
                    if isP1Win {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.yellow.opacity(0.15), .clear],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(glowPulse ? 1.2 : 1.0)
                    }

                    Image(systemName: isP1Win ? "trophy.fill" : (winner == .draw ? "equal.circle.fill" : "flag.checkered"))
                        .font(.system(size: 60))
                        .foregroundStyle(
                            isP1Win
                                ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(.secondary)
                        )
                        .shadow(color: isP1Win ? .yellow.opacity(0.5) : .clear, radius: 24)
                        .scaleEffect(trophyBounce ? 1.15 : 1.0)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Text(isP1Win ? "VICTORY" : (winner == .draw ? "DRAW" : "DEFEAT"))
                    .font(.system(size: 40, weight: .black))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(
                        isP1Win
                            ? AnyShapeStyle(LinearGradient(colors: [accentColor, .white, accentColor], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(.white.opacity(0.9))
                    )
                    .shadow(color: isP1Win ? accentColor.opacity(0.4) : .clear, radius: 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                HStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("\(p1Score)")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: accentColor.opacity(0.3), radius: 8)
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentColor.opacity(0.7))
                    }

                    Text("\u{2014}")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.tertiary)

                    VStack(spacing: 6) {
                        Text("\(p2Score)")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("OPP")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(accentColor.opacity(0.15), lineWidth: 1)
                        )
                )
                .opacity(appeared ? 1 : 0)

                Button {
                    onReturn()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("CLAIM & EXIT")
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: accentColor.opacity(0.3), radius: 12)
                }
                .padding(.top, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                Spacer()
            }
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
            if isP1Win {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4).delay(0.3)) {
                    trophyBounce = true
                }
                withAnimation(.spring(response: 0.3).delay(0.6)) {
                    trophyBounce = false
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                    glowPulse = true
                }
            }
        }
    }
}
