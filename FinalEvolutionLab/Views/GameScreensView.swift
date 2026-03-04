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

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.4))

            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 28, weight: .black))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(.white)
                    .shadow(color: accentColor.opacity(0.3), radius: 12)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.8))
                        .tracking(1)
                }

                ZStack {
                    Circle()
                        .stroke(accentColor.opacity(0.15), lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .stroke(accentColor.opacity(0.4), lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringScale)
                        .opacity(pulse ? 0.0 : 0.6)

                    Circle()
                        .fill(accentColor.opacity(0.06))
                        .frame(width: 100, height: 100)

                    if showGo {
                        Text("GO!")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .shadow(color: accentColor.opacity(0.5), radius: 16)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    } else if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                }
                .padding(.top, 8)

                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 10))
                    Text("GET READY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(4)
                }
                .foregroundStyle(.white.opacity(0.3))
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
                    ringScale = 1.4
                }
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation { pulse = false }
                try? await Task.sleep(for: .milliseconds(800))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
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

    private var isP1Win: Bool { winner == .p1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            if isP1Win {
                RadialGradient(
                    colors: [accentColor.opacity(0.12), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            VStack(spacing: 20) {
                Spacer()

                if let title {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                }

                Image(systemName: isP1Win ? "trophy.fill" : (winner == .draw ? "equal.circle.fill" : "flag.checkered"))
                    .font(.system(size: 56))
                    .foregroundStyle(isP1Win ? .yellow : .secondary)
                    .shadow(color: isP1Win ? .yellow.opacity(0.4) : .clear, radius: 20)
                    .scaleEffect(trophyBounce ? 1.15 : 1.0)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(isP1Win ? "VICTORY" : (winner == .draw ? "DRAW" : "DEFEAT"))
                    .font(.system(size: 36, weight: .black))
                    .italic()
                    .tracking(2)
                    .foregroundStyle(isP1Win ? accentColor : .white.opacity(0.9))
                    .shadow(color: isP1Win ? accentColor.opacity(0.3) : .clear, radius: 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(p1Score)")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Text("\u{2014}")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.tertiary)

                    VStack(spacing: 4) {
                        Text("\(p2Score)")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("OPP")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
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
                    .background(accentColor)
                    .clipShape(.rect(cornerRadius: 14))
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
            }
        }
    }
}
