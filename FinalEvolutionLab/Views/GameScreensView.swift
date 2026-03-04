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

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))

            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 26, weight: .black))
                    .italic()
                    .tracking(2)
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1)
                }

                if count > 0 {
                    ZStack {
                        Circle()
                            .stroke(accentColor.opacity(0.3), lineWidth: 4)
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(accentColor.opacity(0.08))
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulse ? 1.2 : 1.0)
                            .opacity(pulse ? 0.0 : 0.5)

                        Text("\(count)")
                            .font(.system(size: 44, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            count = countdown
            pulse = false
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
                }
                withAnimation(.easeOut(duration: 0.8)) {
                    pulse = true
                }
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation { pulse = false }
                try? await Task.sleep(for: .milliseconds(800))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.2)) {
                count = 0
            }
            try? await Task.sleep(for: .milliseconds(200))
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

    private var isP1Win: Bool { winner == .p1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            VStack(spacing: 20) {
                Spacer()

                if let title {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)
                }

                Image(systemName: isP1Win ? "trophy.fill" : (winner == .draw ? "equal.circle.fill" : "flag.checkered"))
                    .font(.system(size: 48))
                    .foregroundStyle(isP1Win ? .yellow : .secondary)

                Text(isP1Win ? "YOU WIN!" : (winner == .draw ? "DRAW" : "OPPONENT WINS"))
                    .font(.system(size: 32, weight: .black))
                    .italic()
                    .foregroundStyle(isP1Win ? accentColor : .white.opacity(0.9))

                HStack(spacing: 8) {
                    Text("\(p1Score)")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("–")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("\(p2Score)")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Button {
                    onReturn()
                } label: {
                    Text("RETURN TO LAB")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.top, 8)

                Spacer()
            }
        }
        .transition(.opacity)
    }
}
