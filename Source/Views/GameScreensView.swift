import SwiftUI

struct GetReadyScreen: View {
    let title: String
    var subtitle: String? = nil
    /// Optional style tag for Get Ready screen (no third-party product names).
    var inspirationTag: String? = nil
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
                Text("GET READY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(accentColor.opacity(0.9))
                Text(title)
                    .font(.system(size: 28, weight: .black))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: accentColor.opacity(0.4), radius: 12)
                    .animation(.easeOut(duration: 0.3), value: title)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1)
                        .multilineTextAlignment(.center)
                }
                if let tag = inspirationTag, !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(accentColor.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accentColor.opacity(0.15)))
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
                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: showGo ? 1 : count)
                .padding(.top, 8)

                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 10))
                    Text("READY?")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(5)
                }
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 8)

                Text("Tap or controller • both work in game")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
                    .tracking(1)
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(showGo ? "Go" : "Get ready, \(count) seconds. Tap or controller both work in game.")
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
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            outerRingRotation = 360
        }
        timer?.cancel()
        timer = Task {
            for i in stride(from: countdown, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                    count = i
                    ringScale = 0.5
                }
                withAnimation(.easeOut(duration: 0.5)) {
                    pulse = true
                    ringScale = 1.4
                }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation { pulse = false }
                try? await Task.sleep(for: .milliseconds(480))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                count = 0
                showGo = true
            }
            try? await Task.sleep(for: .milliseconds(380))
            onComplete()
        }
    }
}

/// Pre-game movement snack: one short exercise from Foundations or Longevity. User taps Done to proceed.
struct PreGameMovementSnackView: View {
    let exercise: TrainingExercise
    var accentColor: Color = Theme.foundationGreen
    let onComplete: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            RadialGradient(
                colors: [accentColor.opacity(0.12), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 28) {
                HStack(spacing: 8) {
                    Image(systemName: exercise.category.systemImage)
                        .font(.system(size: 14))
                    Text("MOVEMENT SNACK")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(4)
                }
                .foregroundStyle(accentColor.opacity(0.9))

                Text(exercise.name)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(exercise.reps)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)

                if !exercise.cues.isEmpty {
                    Text(exercise.cues)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    onComplete()
                } label: {
                    Text("DONE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
                .padding(.top, 16)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appeared = true }
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
    var shardsEarned: Int = 0
    var prqGain: Double = 0
    var prqCurrent: Double = PRQ.default
    var modeAttributeLabel: String? = nil
    var modeAttributeValue: Double? = nil
    /// When provided (e.g. from Arena generic play), shows "Round 1: P1 1 – P2 0" style breakdown.
    var roundBreakdown: [(Int, Int)]? = nil
    /// Total Evolution Shards in vault after this match (persistent economy HUD).
    var vaultShardTotal: Int? = nil
    var returnButtonTitle: String = "CLAIM REWARDS & EXIT"
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
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel(isP1Win ? "Victory" : (winner == .draw ? "Draw" : "Defeat"))
                if isP1Win {
                    Text("PLAYER 1 WINS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(accentColor.opacity(0.8))
                        .opacity(appeared ? 1 : 0)
                }

                HStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("\(p1Score)")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: accentColor.opacity(0.3), radius: 8)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: p1Score)
                        Text("P1")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(accentColor.opacity(0.8))
                    }

                    Text("\u{2014}")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.tertiary)

                    VStack(spacing: 6) {
                        Text("\(p2Score)")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: p2Score)
                        Text("P2")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Score: Player 1 \(p1Score), Player 2 \(p2Score)")
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

                rewardsEarnedSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.15), value: appeared)

                if let vault = vaultShardTotal {
                    HStack(spacing: 8) {
                        Image(systemName: "vault.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.brandCyan.opacity(0.9))
                        Text("Vault")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(vault)")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("shards")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan.opacity(0.85))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.brandCyan.opacity(0.2), lineWidth: 1))
                    )
                    .opacity(appeared ? 1 : 0)
                }

                if let rounds = roundBreakdown, !rounds.isEmpty {
                    roundBreakdownSection(rounds)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.2), value: appeared)
                }

                prqBreakdownSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.25), value: appeared)

                Button {
                    onReturn()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .bold))
                        Text(returnButtonTitle)
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
                .accessibilityLabel(returnButtonTitle)
                .accessibilityHint("Returns to previous screen and claims rewards")
                .padding(.top, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                Spacer()
            }
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.08)) {
                appeared = true
            }
            if isP1Win { GameplaySoundService.playVictory() }
            else if winner == .p2 { GameplaySoundService.playDefeat() }
            if isP1Win {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5).delay(0.35)) {
                    trophyBounce = true
                }
                withAnimation(.spring(response: 0.25).delay(0.55)) {
                    trophyBounce = false
                }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(0.45)) {
                    glowPulse = true
                }
            }
        }
    }

    private func roundBreakdownSection(_ rounds: [(Int, Int)]) -> some View {
        VStack(spacing: 8) {
            Text("ROUND BY ROUND")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(Array(rounds.enumerated()), id: \.offset) { index, r in
                    HStack(spacing: 4) {
                        Text("R\(index + 1)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text("\(r.0)\u{2013}\(r.1)")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial.opacity(0.2))
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Round by round: \(rounds.enumerated().map { "Round \($0.offset + 1) P1 \($0.element.0) P2 \($0.element.1)" }.joined(separator: ", "))")
    }

    private var prqBreakdownSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 10))
                        Text("PRQ")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(Theme.brandBlue)
                    Text(String(format: "%.0f", prqCurrent))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    if prqGain > 0 {
                        Text(String(format: "+%.1f", prqGain))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity)

                if let label = modeAttributeLabel, let value = modeAttributeValue {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 10))
                            Text(label.uppercased())
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .lineLimit(1)
                        }
                        .foregroundStyle(accentColor)
                        Text("\(Int(value.rounded()))")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("RATING")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("TIER")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.yellow)
                    let tier = PRQTier.fromPRQ(prqCurrent + prqGain)
                    Text(tier.rawValue)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    let nextMin = nextTierMinPRQ(current: prqCurrent + prqGain)
                    if nextMin > 0 {
                        Text(String(format: "%.0f to next", nextMin - (prqCurrent + prqGain)))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.brandBlue.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
    }

    private var rewardsEarnedSection: some View {
        HStack(spacing: 24) {
            if shardsEarned > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.brandCyan)
                    Text("+\(shardsEarned)")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("SHARDS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.brandCyan.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.brandCyan.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            if prqGain > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.brandBlue)
                    Text(String(format: "+%.1f", prqGain))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("PRQ")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandBlue.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.brandBlue.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.brandBlue.opacity(0.25), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private func nextTierMinPRQ(current: Double) -> Double {
        let tiers: [(Double, PRQTier)] = [
            (90, .diamond), (75, .platinum), (60, .gold), (45, .silver), (25, .bronze)
        ]
        for (minPRQ, _) in tiers {
            if current < minPRQ { return minPRQ }
        }
        return 0
    }
}
