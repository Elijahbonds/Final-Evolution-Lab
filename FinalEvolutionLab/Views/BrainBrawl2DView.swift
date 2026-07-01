import SwiftUI

struct BrainBrawl2DView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode
    let onDismiss: () -> Void

    enum GameState {
        case selection
        case wheel
        case playing
        case crownCelebration
        case results
    }

    enum TurnOwner {
        case player
        case opponent
    }

    enum OpponentDifficulty: String, CaseIterable, Identifiable {
        case easy = "EASY"
        case medium = "MEDIUM"
        case hard = "HARD"

        var id: String { rawValue }
        var accuracy: Double {
            switch self {
            case .easy: return 0.42
            case .medium: return 0.65
            case .hard: return 0.85
            }
        }
        var delayRange: ClosedRange<Double> {
            switch self {
            case .easy: return 3.0...5.5
            case .medium: return 2.0...4.0
            case .hard: return 1.2...2.8
            }
        }
    }

    @State private var currentState: GameState = .selection
    @State private var selectedDifficulty: OpponentDifficulty = .medium

    // Trivia Crack match state
    @State private var currentTurn: TurnOwner = .player
    @State private var playerCrowns: Set<BrainBrawlCategory> = []
    @State private var opponentCrowns: Set<BrainBrawlCategory> = []
    @State private var playerLives: Int = BrainBrawlCategory.startingLives
    @State private var opponentLives: Int = BrainBrawlCategory.startingLives
    @State private var possessionStreak: [BrainBrawlCategory: Int] = [:]
    @State private var crownsEarnedThisMatch: [BrainBrawlCategory: Int] = [:]
    @State private var categoryStats: [BrainBrawlCategory: BrainBrawlCategoryStat] = [:]

    // Wheel / question
    @State private var wheelRotation: Double = 0
    @State private var isSpinning = false
    @State private var activeCategory: BrainBrawlCategory?
    @State private var currentQuestion: BrainBrawlQuestion?
    @State private var usedQuestionIDs: Set<UUID> = []
    @State private var playerSelectedAnswerIndex: Int?
    @State private var aiSelectedAnswerIndex: Int?
    @State private var showRoundFeedback = false
    @State private var timerValue: Double = 15.0
    @State private var timerTask: Task<Void, Never>?
    @State private var aiThinkingTask: Task<Void, Never>?
    @State private var totalQuestionsAsked = 0
    @State private var playerCorrectCount = 0
    @State private var playerMaxStreak = 0
    @State private var currentAnswerStreak = 0

    // UI feedback
    @State private var playerStatusText = "YOUR TURN"
    @State private var aiStatusText = "WAITING..."
    @State private var feedbackBannerText = ""
    @State private var feedbackBannerColor: Color = .green
    @State private var lastCrownCategory: BrainBrawlCategory?

    // Post-game
    @State private var xpEarned = 0
    @State private var shardsEarned = 0
    @State private var readinessBonus = 0.0
    @State private var oldLevel = 1
    @State private var newLevel = 1
    @State private var oldXp = 0
    @State private var newXp = 0
    @State private var levelUpOccurred = false
    @State private var animateXpBar = 0.0
    @State private var playerWon = false
    @State private var crownPulseScale: CGFloat = 0.6

    private var questionTimerLimit: Double {
        switch selectedDifficulty {
        case .easy: return 18.0
        case .medium: return 15.0
        case .hard: return 12.0
        }
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            Theme.meshGradient.ignoresSafeArea().opacity(0.4)

            VStack {
                switch currentState {
                case .selection:
                    selectionScreen
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                case .wheel:
                    wheelScreen
                        .transition(.scale)
                case .playing:
                    gameplayScreen
                        .transition(.scale)
                case .crownCelebration:
                    crownCelebrationOverlay
                case .results:
                    resultsScreen
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: currentState)
        }
        .statusBar(hidden: true)
        .onDisappear {
            timerTask?.cancel()
            aiThinkingTask?.cancel()
            FELSoundscapeEngine.shared.stop()
        }
    }

    // MARK: - Selection

    private var selectionScreen: some View {
        ScrollView {
            VStack(spacing: 22) {
                headerBar(title: "CROWN DUEL")

                VStack(spacing: 6) {
                    Text("COLLECT ALL CROWNS")
                        .font(FELTypography.mono(10, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(3)
                    Text("HEAD-TO-HEAD")
                        .font(FELTypography.display(32))
                        .foregroundStyle(.white)
                    Text("Spin the wheel · Answer 3 in a row · Win the crown")
                        .font(FELTypography.caption(11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                crownRulesCard

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(BrainBrawlCategory.allCases) { cat in
                        categoryPreviewTile(cat)
                    }
                }
                .padding(.horizontal)

                difficultyPicker
                    .padding(.horizontal)

                if let tier = gameMode.felHonestTierLabel {
                    FELPreviewLabel(text: tier)
                        .accessibilityIdentifier("BrainBrawlHonestTierLabel")
                }

                Button(action: launchMatch) {
                    Text("START CROWN DUEL")
                        .font(FELTypography.mono(14, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .leading, endPoint: .trailing))
                        }
                        .shadow(color: Theme.brandCyan.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private var crownRulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW TO WIN")
                .font(FELTypography.mono(11, weight: .black))
                .foregroundStyle(.white)
            ruleRow(icon: "crown.fill", text: "Answer 3 correctly in one turn to earn a category crown")
            ruleRow(icon: "arrow.triangle.2.circlepath", text: "Correct answers keep your turn — spin again")
            ruleRow(icon: "heart.fill", text: "Wrong answers cost 1 life and pass the turn")
            ruleRow(icon: "trophy.fill", text: "First to all 6 crowns — or last rival standing — wins")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder, lineWidth: 1) }
        .padding(.horizontal)
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.brandCyan)
                .frame(width: 18)
            Text(text)
                .font(FELTypography.caption(11))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func categoryPreviewTile(_ category: BrainBrawlCategory) -> some View {
        let prog = viewModel.profile.brainBrawlProgression?.categoryProgress[category.rawValue]
            ?? BrainBrawlCategoryProgress(category: category.rawValue)
        return VStack(spacing: 6) {
            Image(systemName: category.iconName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(categoryColor(category))
            Text(category.displayName.uppercased())
                .font(FELTypography.mono(7, weight: .black))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            if prog.crownsEarned > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 7))
                    Text("\(prog.crownsEarned)")
                        .font(FELTypography.mono(7, weight: .bold))
                }
                .foregroundStyle(.yellow)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardBorder, lineWidth: 1) }
    }

    private var difficultyPicker: some View {
        VStack(spacing: 12) {
            HStack {
                Text("OPPONENT SKILL")
                    .font(FELTypography.mono(12, weight: .black))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(OpponentDifficulty.allCases) { diff in
                    Button { selectedDifficulty = diff } label: {
                        Text(diff.rawValue)
                            .font(FELTypography.mono(10, weight: .black))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                Capsule().fill(selectedDifficulty == diff ? Theme.brandCyan.opacity(0.2) : Color.white.opacity(0.05))
                            }
                            .overlay {
                                Capsule().strokeBorder(selectedDifficulty == diff ? Theme.brandCyan : Color.clear, lineWidth: 1)
                            }
                            .foregroundStyle(selectedDifficulty == diff ? Theme.brandCyan : .white)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder, lineWidth: 1) }
    }

    // MARK: - Wheel

    private var wheelScreen: some View {
        VStack(spacing: 20) {
            matchHUD
                .padding(.horizontal)
                .padding(.top, 10)

            Text(currentTurn == .player ? "SPIN FOR YOUR CATEGORY" : "OPPONENT SPINNING...")
                .font(FELTypography.mono(11, weight: .black))
                .foregroundStyle(currentTurn == .player ? Theme.brandCyan : Theme.elitePurple)

            categoryWheel
                .padding(.vertical, 8)

            if let cat = activeCategory, !isSpinning {
                Text("LANDED: \(cat.displayName.uppercased())")
                    .font(FELTypography.mono(12, weight: .black))
                    .foregroundStyle(categoryColor(cat))
                    .transition(.scale)
            }

            if currentTurn == .player && !isSpinning {
                Button(action: spinWheel) {
                    Text(activeCategory == nil ? "SPIN WHEEL" : "START QUESTION")
                        .font(FELTypography.mono(13, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.brandCyan))
                }
                .padding(.horizontal, 32)
            } else if isSpinning {
                ProgressView()
                    .tint(Theme.brandCyan)
            }

            Spacer()
        }
    }

    private var categoryWheel: some View {
        let sliceCount = Double(BrainBrawlCategory.allCases.count)
        let sliceAngle = 360.0 / sliceCount

        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 260, height: 260)

            ForEach(Array(BrainBrawlCategory.allCases.enumerated()), id: \.element.id) { index, cat in
                let start = Double(index) * sliceAngle - 90
                WheelSlice(startAngle: .degrees(start), endAngle: .degrees(start + sliceAngle))
                    .fill(categoryColor(cat).opacity(playerCrowns.contains(cat) || opponentCrowns.contains(cat) ? 0.35 : 0.75))
                    .frame(width: 240, height: 240)

                let mid = start + sliceAngle / 2
                let rad = mid * .pi / 180
                Image(systemName: cat.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: cos(rad) * 78, y: sin(rad) * 78)
            }
            .rotationEffect(.degrees(wheelRotation))

            Circle()
                .fill(Theme.deepBlack)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.yellow)
                }

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -148)
        }
    }

    // MARK: - Gameplay

    private var gameplayScreen: some View {
        VStack(spacing: 12) {
            matchHUD
                .padding(.horizontal)
                .padding(.top, 8)

            turnBanner

            if let cat = activeCategory {
                possessionStreakBar(for: cat)
            }

            timerRow

            HStack(spacing: 14) {
                combatantCard(
                    title: "YOU",
                    crowns: playerCrowns,
                    lives: playerLives,
                    status: playerStatusText,
                    glow: Theme.elitePurple,
                    isActive: currentTurn == .player
                )
                combatantCard(
                    title: "RIVAL AI",
                    crowns: opponentCrowns,
                    lives: opponentLives,
                    status: aiStatusText,
                    glow: Theme.brandCyan,
                    isActive: currentTurn == .opponent
                )
            }
            .padding(.horizontal)

            questionPanel
                .padding(.horizontal)

            if currentTurn == .player {
                choicesGrid
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            } else {
                Text("RIVAL IS ANSWERING...")
                    .font(FELTypography.mono(10, weight: .black))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
        }
    }

    private var matchHUD: some View {
        HStack {
            let snapshot = NexusHUDSnapshot(
                brainPlayerCorrect: playerCrowns.count,
                brainOpponentCorrect: opponentCrowns.count,
                cognitiveScore: Double(playerCorrectCount * 10),
                cognitiveStreak: currentAnswerStreak,
                cognitiveWinTarget: BrainBrawlCategory.crownsToWin,
                scenePlayerHasBuzz: playerSelectedAnswerIndex != nil
            )
            FELBrainHudStrip(snapshot: snapshot, modeId: .brainBrawl)
            Spacer()
            Button(action: dismissMatch) {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
    }

    private var turnBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(currentTurn == .player ? Theme.brandCyan : Theme.elitePurple)
                .frame(width: 8, height: 8)
            Text(currentTurn == .player ? "YOUR TURN — KEEP THE WHEEL" : "RIVAL TURN")
                .font(FELTypography.mono(10, weight: .black))
                .foregroundStyle(currentTurn == .player ? Theme.brandCyan : Theme.elitePurple)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    private func possessionStreakBar(for category: BrainBrawlCategory) -> some View {
        let streak = possessionStreak[category, default: 0]
        return HStack(spacing: 6) {
            Text("CROWN PROGRESS")
                .font(FELTypography.mono(8, weight: .bold))
                .foregroundStyle(.secondary)
            ForEach(0..<BrainBrawlCategory.crownStreakTarget, id: \.self) { i in
                Image(systemName: i < streak ? "crown.fill" : "crown")
                    .font(.system(size: 12))
                    .foregroundStyle(i < streak ? .yellow : .white.opacity(0.2))
            }
            Text(category.displayName.uppercased())
                .font(FELTypography.mono(8, weight: .black))
                .foregroundStyle(categoryColor(category))
        }
    }

    private var timerRow: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 4)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(timerValue / questionTimerLimit))
                    .stroke(timerValue > 4 ? Theme.brandCyan : Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)
                Text(String(format: "%.0f", timerValue))
                    .font(FELTypography.mono(11, weight: .black))
                    .foregroundStyle(timerValue > 4 ? .white : .red)
            }
            Spacer()
        }
    }

    private func combatantCard(
        title: String,
        crowns: Set<BrainBrawlCategory>,
        lives: Int,
        status: String,
        glow: Color,
        isActive: Bool
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(FELTypography.mono(8, weight: .heavy))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ForEach(BrainBrawlCategory.allCases) { cat in
                    Image(systemName: crowns.contains(cat) ? "crown.fill" : "crown")
                        .font(.system(size: 9))
                        .foregroundStyle(crowns.contains(cat) ? .yellow : .white.opacity(0.15))
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<BrainBrawlCategory.startingLives, id: \.self) { i in
                    Image(systemName: i < lives ? "heart.fill" : "heart")
                        .font(.system(size: 10))
                        .foregroundStyle(i < lives ? .red : .white.opacity(0.15))
                }
            }
            Text(status)
                .font(FELTypography.mono(7, weight: .black))
                .foregroundStyle(isActive ? glow : .white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(isActive ? glow.opacity(0.1) : Theme.cardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isActive ? glow : Theme.cardBorder, lineWidth: isActive ? 2 : 1)
        }
    }

    private var questionPanel: some View {
        VStack(spacing: 10) {
            if let q = currentQuestion {
                Text(q.category.displayName.uppercased())
                    .font(FELTypography.mono(8, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor(q.category))
                    .cornerRadius(4)

                Text(q.text)
                    .font(FELTypography.headline(15))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .frame(minHeight: 60)

                if showRoundFeedback {
                    VStack(spacing: 4) {
                        Text(feedbackBannerText.uppercased())
                            .font(FELTypography.mono(9, weight: .black))
                            .foregroundStyle(feedbackBannerColor)
                        Text(q.explanation)
                            .font(FELTypography.caption(9))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surfaceElevated.opacity(0.6)))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(showRoundFeedback ? feedbackBannerColor.opacity(0.5) : Theme.cardBorder, lineWidth: 1.5)
        }
    }

    private var choicesGrid: some View {
        VStack(spacing: 10) {
            if let q = currentQuestion {
                ForEach(0..<q.choices.count, id: \.self) { index in
                    choiceButton(label: q.choices[index], index: index, correctIndex: q.correctIndex)
                }
            }
        }
    }

    private func choiceButton(label: String, index: Int, correctIndex: Int) -> some View {
        let isPlayerSelected = playerSelectedAnswerIndex == index
        let isAiSelected = aiSelectedAnswerIndex == index
        let isCorrect = index == correctIndex

        let strokeColor: Color
        let bgColor: Color
        let textColor: Color

        if showRoundFeedback {
            if isCorrect {
                strokeColor = .green; bgColor = Color.green.opacity(0.15); textColor = .green
            } else if isPlayerSelected {
                strokeColor = .red; bgColor = Color.red.opacity(0.15); textColor = .red
            } else {
                strokeColor = Theme.cardBorder; bgColor = Theme.cardBackground; textColor = .white.opacity(0.4)
            }
        } else if isPlayerSelected {
            strokeColor = Theme.brandCyan; bgColor = Theme.brandCyan.opacity(0.1); textColor = Theme.brandCyan
        } else {
            strokeColor = Theme.cardBorder; bgColor = Theme.cardBackground; textColor = .white
        }

        return Button { selectAnswer(index) } label: {
            HStack {
                Text(choicePrefix(for: index))
                    .font(FELTypography.mono(10, weight: .black))
                    .foregroundStyle(textColor.opacity(0.7))
                    .frame(width: 20)
                Text(label)
                    .font(FELTypography.body(13).weight(.medium))
                    .foregroundStyle(textColor)
                Spacer()
                if isAiSelected {
                    Text("AI")
                        .font(FELTypography.mono(7, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.brandCyan)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(bgColor))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(strokeColor, lineWidth: 1.5) }
        }
        .disabled(playerSelectedAnswerIndex != nil || showRoundFeedback || currentTurn != .player)
        .buttonStyle(.plain)
    }

    // MARK: - Crown celebration

    private var crownCelebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 20)
                    .scaleEffect(crownPulseScale)
                Text("CROWN EARNED!")
                    .font(FELTypography.display(28))
                    .foregroundStyle(.yellow)
                if let cat = lastCrownCategory {
                    Text(cat.displayName.uppercased())
                        .font(FELTypography.mono(12, weight: .black))
                        .foregroundStyle(categoryColor(cat))
                    Text("3 IN A ROW · \(cat.displayName)")
                        .font(FELTypography.mono(9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .onAppear {
            crownPulseScale = 0.6
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                crownPulseScale = 1.15
            }
            FELHaptics.actionSuccess(isCritical: true)
            FELSoundscapeEngine.shared.triggerApplause(intensity: 1.0)
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    crownPulseScale = 1.0
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                if checkMatchEnd() {
                    endMatch()
                } else {
                    activeCategory = nil
                    currentState = .wheel
                    if currentTurn == .opponent {
                        scheduleOpponentSpin()
                    }
                }
            }
        }
    }

    // MARK: - Results

    private var resultsScreen: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("CROWN DUEL COMPLETE")
                    .font(FELTypography.mono(10, weight: .heavy))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(4)
                    .padding(.top, 24)

                Text(playerWon ? "VICTORY" : "DEFEAT")
                    .font(FELTypography.display(42))
                    .foregroundStyle(playerWon ? .green : .red)

                crownSummaryCard
                    .padding(.horizontal)

                progressionCard
                    .padding(.horizontal)

                Button { currentState = .selection } label: {
                    Text("PLAY AGAIN")
                        .font(FELTypography.mono(12, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                }
                .padding(.horizontal)

                Button(action: onDismiss) {
                    Text("CLOSE LAB")
                        .font(FELTypography.mono(12, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.brandCyan))
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .onAppear { animateXPProgress() }
    }

    private var crownSummaryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 24) {
                VStack {
                    Text("YOUR CROWNS")
                        .font(FELTypography.mono(9, weight: .black))
                        .foregroundStyle(Theme.elitePurple)
                    Text("\(playerCrowns.count)/\(BrainBrawlCategory.crownsToWin)")
                        .font(FELTypography.display(36))
                        .foregroundStyle(.white)
                }
                Text("VS")
                    .font(FELTypography.mono(14, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                VStack {
                    Text("RIVAL CROWNS")
                        .font(FELTypography.mono(9, weight: .black))
                        .foregroundStyle(Theme.brandCyan)
                    Text("\(opponentCrowns.count)/\(BrainBrawlCategory.crownsToWin)")
                        .font(FELTypography.display(36))
                        .foregroundStyle(.white)
                }
            }
            HStack(spacing: 4) {
                ForEach(BrainBrawlCategory.allCases) { cat in
                    Image(systemName: playerCrowns.contains(cat) ? "crown.fill" : "crown")
                        .foregroundStyle(playerCrowns.contains(cat) ? .yellow : .white.opacity(0.2))
                }
            }
            Text("\(playerCorrectCount) correct · \(totalQuestionsAsked) questions")
                .font(FELTypography.mono(9, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder, lineWidth: 1) }
    }

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REWARDS")
                .font(FELTypography.mono(11, weight: .black))
                .foregroundStyle(.white)
            HStack {
                Text("+\(xpEarned) XP")
                    .font(FELTypography.mono(14, weight: .black))
                    .foregroundStyle(.green)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").foregroundStyle(.yellow)
                    Text("+\(shardsEarned) SHARDS")
                        .font(FELTypography.mono(12, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            if levelUpOccurred {
                Text("LEVEL \(oldLevel) → LEVEL \(newLevel)")
                    .font(FELTypography.mono(10, weight: .black))
                    .foregroundStyle(.yellow)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.brandCyan, Theme.elitePurple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(animateXpBar), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder, lineWidth: 1) }
    }

    // MARK: - Helpers

    private func headerBar(title: String) -> some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("BACK")
                }
                .font(FELTypography.mono(12, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            Spacer()
            Text(title)
                .font(FELTypography.mono(16, weight: .black))
                .foregroundStyle(Theme.elitePurple)
            Spacer()
            Color.clear.frame(width: 80, height: 30)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    private func categoryColor(_ category: BrainBrawlCategory) -> Color {
        switch category {
        case .science: return Theme.brandCyan
        case .sports: return .orange
        case .entertainment: return Theme.elitePurple
        case .geography: return .green
        case .history: return .yellow
        case .arts: return .pink
        }
    }

    private func choicePrefix(for index: Int) -> String {
        ["A.", "B.", "C.", "D."][safe: index] ?? "?"
    }

    // MARK: - Match flow

    private func launchMatch() {
        resetMatchState()
        FELSoundscapeEngine.shared.start(for: .brainBrawl)
        FELHaptics.modeSelect()
        currentState = .wheel
    }

    private func resetMatchState() {
        currentTurn = .player
        playerCrowns = []
        opponentCrowns = []
        playerLives = BrainBrawlCategory.startingLives
        opponentLives = BrainBrawlCategory.startingLives
        possessionStreak = [:]
        crownsEarnedThisMatch = [:]
        categoryStats = [:]
        wheelRotation = 0
        isSpinning = false
        activeCategory = nil
        currentQuestion = nil
        usedQuestionIDs = []
        playerSelectedAnswerIndex = nil
        aiSelectedAnswerIndex = nil
        showRoundFeedback = false
        totalQuestionsAsked = 0
        playerCorrectCount = 0
        playerMaxStreak = 0
        currentAnswerStreak = 0
        playerStatusText = "YOUR TURN"
        aiStatusText = "WAITING..."
        timerTask?.cancel()
        aiThinkingTask?.cancel()
    }

    private func dismissMatch() {
        timerTask?.cancel()
        aiThinkingTask?.cancel()
        currentState = .selection
    }

    private func spinWheel() {
        if activeCategory != nil {
            loadQuestion(for: activeCategory!)
            return
        }
        guard !isSpinning else { return }
        isSpinning = true
        let categories = BrainBrawlCategory.allCases
        let target = categories.randomElement() ?? .science
        let sliceAngle = 360.0 / Double(categories.count)
        let targetIndex = categories.firstIndex(of: target) ?? 0
        let targetRotation = 720 + (Double(targetIndex) * sliceAngle) + sliceAngle / 2

        withAnimation(.easeOut(duration: 1.6)) {
            wheelRotation = targetRotation
        }

        Task {
            try? await Task.sleep(for: .seconds(1.7))
            activeCategory = target
            isSpinning = false
            if currentTurn == .opponent {
                loadQuestion(for: target)
            }
        }
    }

    private func scheduleOpponentSpin() {
        aiStatusText = "SPINNING..."
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            spinWheel()
        }
    }

    private func loadQuestion(for category: BrainBrawlCategory) {
        guard let q = BrainBrawlQuestionBank.randomQuestion(for: category, excluding: usedQuestionIDs) else { return }
        usedQuestionIDs.insert(q.id)
        currentQuestion = q
        playerSelectedAnswerIndex = nil
        aiSelectedAnswerIndex = nil
        showRoundFeedback = false
        totalQuestionsAsked += 1
        currentState = .playing
        startQuestionTimer()
        if currentTurn == .opponent {
            startAIThinking()
        }
    }

    private func startQuestionTimer() {
        timerValue = questionTimerLimit
        timerTask?.cancel()
        timerTask = Task {
            while timerValue > 0 {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                timerValue -= 0.1
                if timerValue <= 0 {
                    timerValue = 0
                    timeExpired()
                }
            }
        }
    }

    private func startAIThinking() {
        aiSelectedAnswerIndex = nil
        aiStatusText = "THINKING..."
        aiThinkingTask?.cancel()
        let delay = Double.random(in: selectedDifficulty.delayRange)
        aiThinkingTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            guard let q = currentQuestion else { return }
            let isCorrect = Double.random(in: 0...1) < selectedDifficulty.accuracy
            if isCorrect {
                aiSelectedAnswerIndex = q.correctIndex
            } else {
                var wrong = Array(0..<q.choices.count)
                wrong.remove(at: q.correctIndex)
                aiSelectedAnswerIndex = wrong.randomElement() ?? 0
            }
            aiStatusText = "ANSWERED!"
            if currentTurn == .opponent {
                evaluateRound(activeCorrect: aiSelectedAnswerIndex == q.correctIndex)
            } else if playerSelectedAnswerIndex != nil {
                evaluateRound(activeCorrect: playerSelectedAnswerIndex == q.correctIndex)
            }
        }
    }

    private func selectAnswer(_ index: Int) {
        guard currentTurn == .player, playerSelectedAnswerIndex == nil else { return }
        playerSelectedAnswerIndex = index
        playerStatusText = "LOCKED IN"
        FELHaptics.actionSuccess(isCritical: false)
        guard let q = currentQuestion else { return }
        if aiSelectedAnswerIndex != nil {
            evaluateRound(activeCorrect: index == q.correctIndex)
        }
    }

    private func timeExpired() {
        guard let q = currentQuestion else { return }
        if currentTurn == .player && playerSelectedAnswerIndex == nil {
            playerSelectedAnswerIndex = -1
            playerStatusText = "TIMEOUT!"
        }
        if currentTurn == .opponent && aiSelectedAnswerIndex == nil {
            aiSelectedAnswerIndex = -1
            aiStatusText = "TIMEOUT!"
        }
        let activeCorrect: Bool
        if currentTurn == .player {
            activeCorrect = playerSelectedAnswerIndex == q.correctIndex
        } else {
            activeCorrect = aiSelectedAnswerIndex == q.correctIndex
        }
        evaluateRound(activeCorrect: activeCorrect)
    }

    private func evaluateRound(activeCorrect: Bool) {
        timerTask?.cancel()
        aiThinkingTask?.cancel()
        guard let cat = activeCategory, let q = currentQuestion else { return }

        showRoundFeedback = true
        let activeIsPlayer = currentTurn == .player

        var prior = categoryStats[cat] ?? BrainBrawlCategoryStat(correct: 0, total: 0)
        prior.total += 1
        if activeIsPlayer && activeCorrect { prior.correct += 1 }
        categoryStats[cat] = prior

        if activeCorrect {
            if activeIsPlayer {
                playerCorrectCount += 1
                currentAnswerStreak += 1
                playerMaxStreak = max(playerMaxStreak, currentAnswerStreak)
                feedbackBannerText = "CORRECT!"
                feedbackBannerColor = .green
                FELHaptics.actionSuccess(isCritical: false)
            } else {
                feedbackBannerText = "RIVAL CORRECT"
                feedbackBannerColor = Theme.brandCyan
            }

            let streak = possessionStreak[cat, default: 0] + 1
            possessionStreak[cat] = streak

            let crownSet = activeIsPlayer ? playerCrowns : opponentCrowns
            if streak >= BrainBrawlCategory.crownStreakTarget && !crownSet.contains(cat) {
                awardCrown(category: cat, toPlayer: activeIsPlayer)
                possessionStreak[cat] = 0
                // Keep turn after crown — Trivia Crack lets you continue
            }

            // Correct → keep turn, return to wheel after delay
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                if checkMatchEnd() {
                    endMatch()
                } else {
                    proceedAfterRound(keepTurn: true)
                }
            }
        } else {
            if activeIsPlayer {
                playerLives -= 1
                currentAnswerStreak = 0
                feedbackBannerText = playerSelectedAnswerIndex == -1 ? "TIME UP!" : "WRONG!"
                feedbackBannerColor = .red
                FELHaptics.actionFail()
            } else {
                opponentLives -= 1
                feedbackBannerText = "RIVAL WRONG — YOUR TURN!"
                feedbackBannerColor = .green
            }
            possessionStreak[cat] = 0
            currentTurn = activeIsPlayer ? .opponent : .player
            playerStatusText = currentTurn == .player ? "YOUR TURN" : "WAITING..."
            aiStatusText = currentTurn == .opponent ? "SPINNING..." : "WAITING..."

            Task {
                try? await Task.sleep(for: .seconds(2.5))
                if checkMatchEnd() {
                    endMatch()
                } else {
                    proceedAfterRound(keepTurn: false)
                }
            }
        }

        _ = q
    }

    private func awardCrown(category: BrainBrawlCategory, toPlayer: Bool) {
        if toPlayer {
            playerCrowns.insert(category)
        } else {
            opponentCrowns.insert(category)
        }
        crownsEarnedThisMatch[category, default: 0] += 1
        lastCrownCategory = category
        currentState = .crownCelebration
    }

    private func proceedAfterRound(keepTurn: Bool) {
        showRoundFeedback = false
        playerSelectedAnswerIndex = nil
        aiSelectedAnswerIndex = nil
        activeCategory = nil
        currentQuestion = nil
        currentState = .wheel
        if currentTurn == .opponent {
            scheduleOpponentSpin()
        }
        if !keepTurn && currentTurn == .player {
            playerStatusText = "YOUR TURN"
        }
    }

    private func checkMatchEnd() -> Bool {
        if playerCrowns.count >= BrainBrawlCategory.crownsToWin { return true }
        if opponentCrowns.count >= BrainBrawlCategory.crownsToWin { return true }
        if playerLives <= 0 || opponentLives <= 0 { return true }
        return false
    }

    private func endMatch() {
        timerTask?.cancel()
        aiThinkingTask?.cancel()
        playerWon = playerCrowns.count >= BrainBrawlCategory.crownsToWin
            || (opponentLives <= 0 && playerLives > 0)
            || (playerCrowns.count > opponentCrowns.count && opponentLives <= 0)

        let crownXP = playerCrowns.count * 150
        let correctXP = playerCorrectCount * 25
        let streakXP = playerMaxStreak * 15
        let outcomeXP = playerWon ? 200 : 50
        xpEarned = crownXP + correctXP + streakXP + outcomeXP
        shardsEarned = playerCrowns.count * 20 + playerCorrectCount * 5 + (playerWon ? 40 : 10)
        readinessBonus = Double(playerCrowns.count) * 1.5 + (playerWon ? 3.0 : 0.5)

        var currentProg = viewModel.profile.brainBrawlProgression ?? BrainBrawlProgression()
        let summary = BrainBrawlMatchSummary(
            playerCrowns: playerCrowns.count,
            opponentCrowns: opponentCrowns.count,
            playerCorrect: playerCorrectCount,
            totalQuestions: totalQuestionsAsked,
            playerWon: playerWon,
            crownsByCategory: crownsEarnedThisMatch,
            categoryStats: categoryStats
        )
        let result = currentProg.addMatchResult(summary: summary, xpGained: xpEarned, streak: playerMaxStreak)

        viewModel.profile.brainBrawlProgression = currentProg
        viewModel.profile.evolutionShards += shardsEarned
        viewModel.profile.metrics.readinessScore = min(100, viewModel.profile.metrics.readinessScore + readinessBonus)
        SaveSystem.saveProfile(viewModel.profile)

        Task {
            try? await TrainingLabSocialBridge.shared.recordShardLedgerDelta(
                deltaShards: shardsEarned,
                reason: "brain_brawl_crown_duel",
                referenceId: UUID().uuidString
            )
        }

        oldLevel = result.oldLevel
        newLevel = result.newLevel
        levelUpOccurred = newLevel > oldLevel
        oldXp = max(0, currentProg.overallXP - xpEarned)
        newXp = currentProg.overallXP
        currentState = .results
    }

    private func animateXPProgress() {
        animateXpBar = Double(oldXp % 1000) / 1000.0
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 1.0)) {
                animateXpBar = Double(newXp % 1000) / 1000.0
            }
        }
    }
}

// MARK: - Wheel slice shape

private struct WheelSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
