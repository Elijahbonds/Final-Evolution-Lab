import SwiftUI

// MARK: - Brain Brawl — full quiz vs AI (curriculum questions, tap to answer, first correct wins the question)

struct BrainBrawlPlayView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let multipeer: MultipeerService?
    let isLocalHost: Bool
    let onExit: () -> Void
    let onGameEnd: (Int, Int, Int, Double) -> Void

    private var totalRounds: Int { mode.id.environmentRoundCount }
    @State private var round: Int = 1
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var questions: [BrainBrawlQuestion] = []
    @State private var currentQuestion: BrainBrawlQuestion?
    @State private var selectedIndex: Int? = nil
    @State private var showingRoundResult: Bool = false
    @State private var roundResult: (p1: Int, p2: Int)?
    @State private var roundFeedback: String? = nil

    private var accentColor: Color { mode.accentColor }
    private var roundLabel: String { mode.id.environmentRoundLabel }

    var body: some View {
        ZStack {
            environmentGradient
            VStack(spacing: 24) {
                environmentHeader
                roundIndicator
                scoreRow
                if let q = currentQuestion {
                    questionCard(q)
                    choicesSection(q)
                } else {
                    ProgressView()
                        .tint(accentColor)
                    Text("Loading question...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if let feedback = roundFeedback {
                    Text(feedback)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? accentColor : (feedback == mode.id.commitFeedbackMiss ? .red : .orange))
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .onAppear {
            loadQuestions()
        }
        .alert("\(roundLabel) \(round)", isPresented: $showingRoundResult) {
            Button("Next") {
                nextRound()
            }
        } message: {
            if let r = roundResult {
                Text(r.p1 > r.p2 ? "Correct! You got it." : "AI got this one.")
            }
        }
    }

    private var environmentGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.18),
                    mode.id.environmentSecondaryColor.opacity(0.25),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            Color.black.opacity(0.4)
                .ignoresSafeArea()
        }
    }

    private var environmentHeader: some View {
        HStack {
            Button {
                onExit()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("EXIT")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(mode.environmentName)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                Text(mode.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var roundIndicator: some View {
        HStack(spacing: 6) {
            Text(roundLabel)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.5))
            Text("\(round)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("OF \(totalRounds)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var scoreRow: some View {
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                Text("\(playerScore)")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("YOU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
            }
            Text("—")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.tertiary)
            VStack(spacing: 4) {
                Text("\(opponentScore)")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Text("AI")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }

    private func questionCard(_ q: BrainBrawlQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(q.subject.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(accentColor.opacity(0.9))
            Text(q.question)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func choicesSection(_ q: BrainBrawlQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(q.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    selectAnswer(index, question: q)
                } label: {
                    HStack {
                        Text(choice)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if selectedIndex == index {
                            Image(systemName: index == q.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(index == q.correctIndex ? .green : .red)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedIndex != nil ? (index == q.correctIndex ? Color.green.opacity(0.15) : (selectedIndex == index ? Color.red.opacity(0.15) : Color.white.opacity(0.04))) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(accentColor.opacity(selectedIndex == nil ? 0.3 : 0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedIndex != nil)
                .animation(.easeOut(duration: 0.2), value: selectedIndex)
                .accessibilityLabel(choice)
                .accessibilityHint(selectedIndex == nil ? "Tap to select this answer" : (index == q.correctIndex ? "Correct answer" : ""))
            }
        }
    }

    private func loadQuestions() {
        let pool = BrainBrawlQuestionBank.questionsForTrack(nil)
        questions = Array(pool.prefix(totalRounds))
        if !questions.isEmpty {
            currentQuestion = questions[round - 1]
        }
    }

    private func selectAnswer(_ index: Int, question: BrainBrawlQuestion) {
        guard selectedIndex == nil else { return }
        selectedIndex = index
        let correct = (index == question.correctIndex)
        #if !targetEnvironment(simulator)
        if correct { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
        else { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        #endif
        roundFeedback = correct ? mode.id.commitFeedbackPerfect : mode.id.commitFeedbackMiss
        let p1Point = correct ? 1 : 0
        let aiPoint = correct ? 0 : 1
        roundResult = (p1Point, aiPoint)
        playerScore += p1Point
        opponentScore += aiPoint
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            roundFeedback = nil
            showingRoundResult = true
        }
    }

    private func nextRound() {
        selectedIndex = nil
        roundResult = nil
        if round >= totalRounds {
            finishGame()
        } else {
            round += 1
            currentQuestion = questions.indices.contains(round - 1) ? questions[round - 1] : nil
        }
    }

    private func finishGame() {
        let prq = viewModel.effectiveMetrics.prqScore
        let won = playerScore > opponentScore
        let tied = playerScore == opponentScore
        let diff = playerScore - opponentScore
        let gain = PRQ.modeReward(mode: mode.id, won: won, tied: tied, combo: 0, criticals: 0, scoreDifferential: diff)
        let baseShards = 6 + totalRounds * 2
        let shards = max(8, min(40, baseShards + (playerScore * 3) + (won ? 12 : 0) + (diff > 0 ? diff * 2 : 0)))
        onGameEnd(playerScore, opponentScore, shards, gain)
    }
}
