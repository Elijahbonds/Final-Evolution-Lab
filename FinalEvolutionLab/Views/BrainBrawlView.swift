import SwiftUI

/// Brain Brawl — Kahoot-style rapid-fire quiz. Pure SwiftUI (no SceneKit shell);
/// built exclusively from FELDesign tokens. Game logic lives in ``BrainBrawlEngine``.
struct BrainBrawlView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode
    /// Optional dismissal override for navigation-destination hosts; falls back to `dismiss`.
    var onExit: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = BrainBrawlEngine()
    @State private var resultSubmitted = false
    @State private var gameStartedAt = Date.now
    @State private var timerFrozenAt: Date?

    /// Kahoot-style shape identity per tile — FELDesign palette only.
    private static let tileSpecs: [(icon: String, accent: Color)] = [
        ("triangle.fill", FELDesign.Colors.cyan),
        ("diamond.fill", FELDesign.Colors.purple),
        ("circle.fill", FELDesign.Colors.textPrimary),
        ("square.fill", FELDesign.Colors.textSecondary),
    ]

    var body: some View {
        ZStack {
            FELDesign.Colors.ink.ignoresSafeArea()
            content
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    exitMode()
                } label: {
                    HStack(spacing: FELDesign.Space.xxs) {
                        Image(systemName: "chevron.left")
                            .font(FELDesign.Typography.caption)
                        Text("EXIT")
                            .font(FELDesign.Typography.micro)
                            .tracking(FELDesign.Typography.microTracking)
                    }
                    .foregroundStyle(FELDesign.Colors.cyan)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { FELHaptics.prepare() }
        .onDisappear { engine.stop() }
        .onChange(of: engine.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .ready:
            readyBody
        case .question, .feedback:
            gameplayBody
        case .results:
            resultsBody
        }
    }

    // MARK: - Ready

    private var readyBody: some View {
        VStack(spacing: FELDesign.Space.lg) {
            Spacer()

            Image(systemName: gameMode.iconName)
                .font(FELDesign.Typography.display)
                .foregroundStyle(FELDesign.Colors.cyan)

            VStack(spacing: FELDesign.Space.xs) {
                Text(gameMode.name)
                    .font(FELDesign.Typography.display)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                FELMicroLabel(
                    text: "\(engine.questionsPerGame) QUESTIONS · \(Int(engine.questionDuration))S EACH · STREAK BONUSES",
                    color: FELDesign.Colors.textSecondary
                )
            }

            Text("Answer fast — the quicker you lock in, the more of the \(BrainBrawlScoring.basePoints)-point base you keep. Chain correct answers to stack streak bonuses.")
                .font(FELDesign.Typography.body)
                .foregroundStyle(FELDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FELDesign.Space.xl)

            Button("Start Quiz") { startGame() }
                .buttonStyle(FELPrimaryButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Gameplay (portrait + landscape)

    private var gameplayBody: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            Group {
                if isLandscape {
                    HStack(spacing: FELDesign.Space.lg) {
                        VStack(spacing: FELDesign.Space.md) {
                            hudStrip
                            timerBar
                            questionCard
                            Spacer(minLength: 0)
                        }
                        .frame(width: geo.size.width * 0.42)

                        answerGrid
                    }
                } else {
                    VStack(spacing: FELDesign.Space.md) {
                        hudStrip
                        timerBar
                        questionCard
                        answerGrid
                    }
                }
            }
            .padding(FELDesign.Space.md)
        }
    }

    private var hudStrip: some View {
        PremiumGameplayHUDStrip(
            scoreLine: "\(engine.score)",
            subtitle: "Question \(min(engine.questionIndex + 1, engine.questions.count)) of \(engine.questions.count)",
            accentColor: gameMode.accentColor,
            prqScore: Int(viewModel.effectiveMetrics.prqScore)
        )
        .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.md))
    }

    private var timerBar: some View {
        TimelineView(.animation) { timeline in
            let reference = timerFrozenAt ?? timeline.date
            let elapsed = reference.timeIntervalSince(engine.questionStartedAt)
            let remaining = max(0, engine.questionDuration - elapsed)
            let fraction = engine.questionDuration > 0 ? remaining / engine.questionDuration : 0
            let urgent = remaining < 5

            HStack(spacing: FELDesign.Space.sm) {
                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(FELDesign.Colors.surfaceRaised)
                        Capsule()
                            .fill(urgent ? FELDesign.Colors.danger : FELDesign.Colors.cyan)
                            .frame(width: max(6, bar.size.width * fraction))
                    }
                }
                .frame(height: 6)

                Text("\(Int(remaining.rounded(.up)))")
                    .font(FELDesign.Typography.stat)
                    .foregroundStyle(urgent ? FELDesign.Colors.danger : FELDesign.Colors.textSecondary)
                    .contentTransition(.numericText())
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .frame(height: 16)
        .accessibilityLabel("Time remaining")
    }

    private var questionCard: some View {
        VStack(spacing: FELDesign.Space.sm) {
            HStack(spacing: FELDesign.Space.sm) {
                FELMicroLabel(text: "Q\(min(engine.questionIndex + 1, engine.questions.count))/\(engine.questions.count)")
                if engine.streak >= 2 {
                    FELMicroLabel(text: "STREAK ×\(engine.streak)", color: FELDesign.Colors.purple)
                }
            }

            Text(engine.currentQuestion?.prompt ?? "")
                .font(FELDesign.Typography.heading)
                .foregroundStyle(FELDesign.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.7)

            if case .feedback(let correct) = engine.phase {
                feedbackBanner(correct: correct)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .frame(maxWidth: .infinity)
        .felCard(padding: FELDesign.Space.lg)
        .overlay(alignment: .topTrailing) {
            if case .feedback(true) = engine.phase, let breakdown = engine.lastBreakdown {
                BrainBrawlPointsFlyUp(text: "+\(breakdown.total)")
                    .padding(.trailing, FELDesign.Space.md)
                    .id(engine.questionIndex)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: engine.phase)
    }

    private func feedbackBanner(correct: Bool) -> some View {
        VStack(spacing: FELDesign.Space.xxs) {
            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(FELDesign.Typography.label)
                Text(feedbackTitle(correct: correct))
                    .font(FELDesign.Typography.label)
            }
            .foregroundStyle(correct ? FELDesign.Colors.success : FELDesign.Colors.danger)

            if correct, let breakdown = engine.lastBreakdown, breakdown.streakBonus > 0 {
                Text("+\(breakdown.timePoints) speed · +\(breakdown.streakBonus) streak")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            } else if !correct, let question = engine.currentQuestion {
                Text("Answer: \(question.answers[question.correctIndex])")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }
        }
    }

    private func feedbackTitle(correct: Bool) -> String {
        if correct { return "CORRECT" }
        return engine.selectedAnswerIndex == nil ? "TIME'S UP" : "WRONG"
    }

    // MARK: - Answer grid (2×2)

    private var answerGrid: some View {
        VStack(spacing: FELDesign.Space.sm) {
            HStack(spacing: FELDesign.Space.sm) {
                answerTile(index: 0)
                answerTile(index: 1)
            }
            HStack(spacing: FELDesign.Space.sm) {
                answerTile(index: 2)
                answerTile(index: 3)
            }
        }
    }

    private enum TileVisualState {
        case idle, correctReveal, wrongSelected, dimmed
    }

    private func tileVisualState(index: Int) -> TileVisualState {
        guard case .feedback = engine.phase, let question = engine.currentQuestion else { return .idle }
        if index == question.correctIndex { return .correctReveal }
        if index == engine.selectedAnswerIndex { return .wrongSelected }
        return .dimmed
    }

    @ViewBuilder
    private func answerTile(index: Int) -> some View {
        let spec = Self.tileSpecs[index % Self.tileSpecs.count]
        let state = tileVisualState(index: index)
        let text = answerText(index: index)

        Button {
            guard engine.phase == .question else { return }
            engine.answer(index)
        } label: {
            VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
                Image(systemName: spec.icon)
                    .font(FELDesign.Typography.heading)
                    .foregroundStyle(tileIconColor(state: state, accent: spec.accent))
                Spacer(minLength: 0)
                Text(text)
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(tileTextColor(state: state))
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.72)
                    .lineLimit(3)
            }
            .padding(FELDesign.Space.md)
            .frame(maxWidth: .infinity, minHeight: 92, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                    .fill(tileFill(state: state))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                    .stroke(tileStroke(state: state, accent: spec.accent), lineWidth: tileStrokeWidth(state: state))
            )
            .opacity(state == .dimmed ? 0.35 : 1)
            .scaleEffect(state == .correctReveal ? 1.03 : (state == .wrongSelected ? 0.97 : 1))
        }
        .buttonStyle(.plain)
        .disabled(engine.phase != .question)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: engine.phase)
        .accessibilityLabel(text)
    }

    private func answerText(index: Int) -> String {
        guard let question = engine.currentQuestion, question.answers.indices.contains(index) else { return "" }
        return question.answers[index]
    }

    private func tileFill(state: TileVisualState) -> Color {
        switch state {
        case .idle, .dimmed: return FELDesign.Colors.surface
        case .correctReveal: return FELDesign.Colors.glow(FELDesign.Colors.success, 0.16)
        case .wrongSelected: return FELDesign.Colors.glow(FELDesign.Colors.danger, 0.14)
        }
    }

    private func tileStroke(state: TileVisualState, accent: Color) -> Color {
        switch state {
        case .idle: return accent.opacity(0.5)
        case .dimmed: return FELDesign.Colors.hairline
        case .correctReveal: return FELDesign.Colors.success
        case .wrongSelected: return FELDesign.Colors.danger
        }
    }

    private func tileStrokeWidth(state: TileVisualState) -> CGFloat {
        switch state {
        case .correctReveal, .wrongSelected: return FELDesign.Stroke.accent
        case .idle, .dimmed: return FELDesign.Stroke.hairline
        }
    }

    private func tileIconColor(state: TileVisualState, accent: Color) -> Color {
        switch state {
        case .correctReveal: return FELDesign.Colors.success
        case .wrongSelected: return FELDesign.Colors.danger
        case .idle, .dimmed: return accent
        }
    }

    private func tileTextColor(state: TileVisualState) -> Color {
        state == .dimmed ? FELDesign.Colors.textTertiary : FELDesign.Colors.textPrimary
    }

    // MARK: - Results

    private var resultsBody: some View {
        VStack(spacing: FELDesign.Space.lg) {
            Spacer()

            FELMicroLabel(text: "SESSION COMPLETE")

            VStack(spacing: FELDesign.Space.xxs) {
                Text("\(engine.score)")
                    .font(FELTypography.mono(56, weight: .black))
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                    .contentTransition(.numericText())
                FELMicroLabel(text: "FINAL SCORE", color: FELDesign.Colors.cyan)
            }

            HStack(spacing: FELDesign.Space.sm) {
                resultStatCard(label: "BEST STREAK", value: "×\(engine.bestStreak)", accent: FELDesign.Colors.purple)
                resultStatCard(label: "ACCURACY", value: "\(Int((engine.accuracy * 100).rounded()))%", accent: FELDesign.Colors.cyan)
                resultStatCard(label: "CORRECT", value: "\(engine.correctCount)/\(engine.questions.count)", accent: FELDesign.Colors.textPrimary)
            }
            .padding(.horizontal, FELDesign.Space.lg)

            HStack(spacing: FELDesign.Space.sm) {
                Button("Replay") { startGame() }
                    .buttonStyle(FELPrimaryButtonStyle())
                Button("Exit") { exitMode() }
                    .buttonStyle(FELGhostButtonStyle())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func resultStatCard(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: FELDesign.Space.xxs) {
            Text(value)
                .font(FELDesign.Typography.statLarge)
                .foregroundStyle(accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            FELMicroLabel(text: label)
        }
        .frame(maxWidth: .infinity)
        .felCard()
    }

    // MARK: - Actions

    private func startGame() {
        resultSubmitted = false
        gameStartedAt = .now
        timerFrozenAt = nil
        FELHaptics.modeSelect()
        engine.startGame()
    }

    private func exitMode() {
        engine.stop()
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }

    private func handlePhaseChange(_ phase: BrainBrawlEngine.Phase) {
        switch phase {
        case .ready:
            break
        case .question:
            timerFrozenAt = nil
        case .feedback(let correct):
            timerFrozenAt = .now
            if correct {
                FELHaptics.actionSuccess(isCritical: engine.streak >= 3)
            } else {
                FELHaptics.actionFail()
            }
        case .results:
            FELHaptics.sessionEnd(won: engine.accuracy >= 0.5)
            submitResultIfNeeded()
        }
    }

    private func submitResultIfNeeded() {
        guard !resultSubmitted else { return }
        resultSubmitted = true
        GameResultService.saveResult(
            modeId: gameMode.id.rawValue,
            userScore: engine.score,
            durationSeconds: max(0, Int(Date.now.timeIntervalSince(gameStartedAt)))
        )
    }
}

// MARK: - Points fly-up

/// "+842" score chip that rises and fades in above the question card on a correct answer.
private struct BrainBrawlPointsFlyUp: View {
    let text: String
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(FELDesign.Typography.statLarge)
            .foregroundStyle(FELDesign.Colors.success)
            .opacity(risen ? 1 : 0)
            .offset(y: risen ? -34 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    risen = true
                }
            }
            .allowsHitTesting(false)
    }
}
