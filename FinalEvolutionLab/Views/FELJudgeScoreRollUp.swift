import SwiftUI

/// Dunk-judge reveal: when `reveal` flips true, each judge card counts its
/// number up from 0 with staggered timing, then a total counts up. An elite
/// total (>= `eliteTotalThreshold`, or `isPerfect`) gets a cyan->elite gradient
/// and glow.
struct JudgeScoreRollUp: View {
    let judges: [Int]
    var maxPerJudge: Int = 10
    var accent: Color
    var eliteColor: Color = FELDesign.Colors.purple
    var eliteTotalThreshold: Int? = nil
    var message: String = ""
    var isPerfect: Bool = false
    var staggerStart: Double = 0.6
    var staggerStep: Double = 0.42
    @Binding var reveal: Bool
    /// Alternative gate: caller-driven per-judge reveal flags. When provided,
    /// a judge shows its value once its flag is true (ignores internal timing).
    var externalRevealed: [Bool]? = nil
    var onJudgeLand: ((Int) -> Void)? = nil

    @State private var displayed: [Int]
    @State private var displayedTotal: Int = 0
    @State private var showTotal: Bool = false

    init(
        judges: [Int],
        maxPerJudge: Int = 10,
        accent: Color,
        eliteColor: Color = FELDesign.Colors.purple,
        eliteTotalThreshold: Int? = nil,
        message: String = "",
        isPerfect: Bool = false,
        staggerStart: Double = 0.6,
        staggerStep: Double = 0.42,
        reveal: Binding<Bool>,
        externalRevealed: [Bool]? = nil,
        onJudgeLand: ((Int) -> Void)? = nil
    ) {
        self.judges = judges
        self.maxPerJudge = maxPerJudge
        self.accent = accent
        self.eliteColor = eliteColor
        self.eliteTotalThreshold = eliteTotalThreshold
        self.message = message
        self.isPerfect = isPerfect
        self.staggerStart = staggerStart
        self.staggerStep = staggerStep
        self._reveal = reveal
        self.externalRevealed = externalRevealed
        self.onJudgeLand = onJudgeLand
        self._displayed = State(initialValue: Array(repeating: 0, count: judges.count))
    }

    private var total: Int { judges.reduce(0, +) }

    private var isElite: Bool {
        if isPerfect { return true }
        if let threshold = eliteTotalThreshold { return total >= threshold }
        return false
    }

    private var totalGradient: LinearGradient {
        LinearGradient(
            colors: isElite ? [accent, eliteColor] : [accent, accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(spacing: FELDesign.Space.md) {
            HStack(spacing: FELDesign.Space.sm) {
                ForEach(Array(judges.enumerated()), id: \.offset) { index, _ in
                    judgeCard(index: index)
                }
            }

            if showTotal {
                VStack(spacing: 4) {
                    FELMicroLabel(text: "Total", color: FELDesign.Colors.textTertiary)
                    Text("\(displayedTotal)")
                        .font(FELTypography.mono(44, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(totalGradient)
                        .contentTransition(.numericText())
                        .shadow(color: isElite ? eliteColor.opacity(0.6) : .clear, radius: 14)
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            if !message.isEmpty {
                Text(message.uppercased())
                    .font(FELTypography.mono(11, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(isElite ? eliteColor : FELDesign.Colors.textSecondary)
                    .transition(.opacity)
            }
        }
        .onChange(of: reveal) { _, newValue in
            if newValue { runReveal() }
        }
        .onChange(of: externalRevealedKey) { _, _ in
            applyExternalRevealed()
        }
        .onAppear {
            if reveal { runReveal() }
            applyExternalRevealed()
        }
    }

    private func judgeCard(index: Int) -> some View {
        let score = displayed[index]
        let tierColor = tier(for: score)
        let fillFraction = maxPerJudge > 0 ? CGFloat(score) / CGFloat(maxPerJudge) : 0

        return VStack(spacing: 6) {
            FELMicroLabel(text: "J\(index + 1)", color: FELDesign.Colors.textTertiary)
            Text("\(score)")
                .font(FELTypography.mono(28, weight: .black))
                .monospacedDigit()
                .foregroundStyle(tierColor)
                .contentTransition(.numericText())

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FELDesign.Colors.hairline)
                    Capsule()
                        .fill(tierColor)
                        .frame(width: geo.size.width * fillFraction)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: fillFraction)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, FELDesign.Space.sm)
        .padding(.horizontal, FELDesign.Space.xs)
        .frame(maxWidth: .infinity)
        .background(FELDesign.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
        )
    }

    private func tier(for score: Int) -> Color {
        guard maxPerJudge > 0 else { return accent }
        let f = Double(score) / Double(maxPerJudge)
        if f >= 0.9 { return eliteColor }
        if f >= 0.6 { return accent }
        if f >= 0.3 { return FELDesign.Colors.success }
        return FELDesign.Colors.textSecondary
    }

    // MARK: - Reveal timing

    /// Stable key so `onChange` fires whenever the external gate array changes.
    private var externalRevealedKey: String {
        externalRevealed?.map { $0 ? "1" : "0" }.joined() ?? ""
    }

    private func applyExternalRevealed() {
        guard let flags = externalRevealed else { return }
        for (index, isOn) in flags.enumerated() where index < judges.count {
            let target = isOn ? judges[index] : 0
            if displayed[index] != target {
                withAnimation(.snappy) { displayed[index] = target }
                if isOn { onJudgeLand?(index) }
            }
        }
        let allShown = flags.prefix(judges.count).allSatisfy { $0 }
        if allShown, !judges.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showTotal = true
                displayedTotal = total
            }
        }
    }

    private func runReveal() {
        // Skip internal timing when the caller owns the gate.
        guard externalRevealed == nil else { return }
        for index in judges.indices {
            let delay = staggerStart + Double(index) * staggerStep
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard reveal, index < displayed.count else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    displayed[index] = judges[index]
                }
                onJudgeLand?(index)
            }
        }
        let totalDelay = staggerStart + Double(judges.count) * staggerStep
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            guard reveal else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                showTotal = true
            }
            withAnimation(.easeOut(duration: 0.5)) {
                displayedTotal = total
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var reveal = false
        var body: some View {
            VStack(spacing: 32) {
                JudgeScoreRollUp(
                    judges: [9, 10, 8, 10],
                    accent: FELDesign.Colors.cyan,
                    eliteTotalThreshold: 34,
                    message: "Elite Dunk",
                    isPerfect: false,
                    reveal: $reveal
                )
                Button(reveal ? "Reset" : "Reveal") {
                    reveal.toggle()
                }
                .buttonStyle(FELPrimaryButtonStyle())
            }
            .padding(40)
            .background(FELDesign.Colors.ink)
        }
    }
    return Demo()
}
