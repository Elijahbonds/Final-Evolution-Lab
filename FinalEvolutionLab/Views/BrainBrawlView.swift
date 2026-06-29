import SwiftUI

struct BrainBrawlView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @State private var phase: BrainPhase = .ready
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var currentIndex = 0
    @State private var timeRemaining = 15
    @State private var selectedAnswer: Int? = nil
    @State private var showAnswer = false
    @State private var timerTask: Task<Void, Never>?
    @State private var opponentAnsweredCorrectly = false
    @State private var questionFlash = false
    @State private var appeared = false

    private enum BrainPhase { case ready, playing, result }

    private var questions: [BrainQuestion] { BrainBrawlQuestions.all }
    private var current: BrainQuestion { questions[min(currentIndex, questions.count - 1)] }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()

            LinearGradient(
                colors: [Color(red: 0.05, green: 0.02, blue: 0.14), Color(red: 0.02, green: 0.02, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: gameMode.name,
                    subtitle: "10 rounds · 15 sec each · Sports smarts",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { startGame() }
                )
            case .playing:
                playingBody
            case .result:
                ResultScreen(
                    winner: playerScore > opponentScore ? .p1 : (opponentScore > playerScore ? .p2 : .draw),
                    p1Score: playerScore,
                    p2Score: opponentScore,
                    title: "Brain Brawl",
                    accentColor: gameMode.accentColor,
                    prqGain: playerScore > opponentScore ? 12 : 3,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "IQ",
                    modeAttributeValue: Double(playerScore) / Double(max(1, questions.count)) ,
                    onReturn: { dismiss() }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { timerTask?.cancel() }
    }

    private var playingBody: some View {
        VStack(spacing: 0) {
            scoreBar
                .padding(.horizontal, 20)
                .padding(.top, 4)

            timerBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer()

            questionCard
                .padding(.horizontal, 20)
                .opacity(questionFlash ? 0.4 : 1)
                .animation(.easeIn(duration: 0.1), value: questionFlash)

            Spacer()

            answersGrid
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private var scoreBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOU").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(gameMode.accentColor.opacity(0.8))
                Text("\(playerScore)").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundStyle(.white)
            }
            Spacer()
            Text("Q \(currentIndex + 1)/\(questions.count)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(gameMode.accentColor)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("OPP").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                Text("\(opponentScore)").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 3)
                    .fill(timeRemaining > 7 ? gameMode.accentColor : Color.red)
                    .frame(width: geo.size.width * CGFloat(timeRemaining) / 15)
                    .animation(.linear(duration: 1), value: timeRemaining)
            }
        }
        .frame(height: 6)
    }

    private var questionCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(gameMode.accentColor.opacity(0.12)).frame(width: 56, height: 56)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(gameMode.accentColor)
            }
            Text(current.question)
                .font(.system(.title3, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            if showAnswer {
                HStack(spacing: 6) {
                    if opponentAnsweredCorrectly {
                        Image(systemName: "person.fill.xmark").foregroundStyle(.red)
                        Text("Opponent answered correctly").font(.system(size: 10, design: .monospaced)).foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(gameMode.accentColor.opacity(0.18), lineWidth: 1))
        )
    }

    private var answersGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(current.answers.indices, id: \.self) { idx in
                answerButton(index: idx)
            }
        }
    }

    private func answerButton(index: Int) -> some View {
        let isSelected = selectedAnswer == index
        let isCorrectAnswer = index == current.correctIndex
        let bgColor: Color = {
            guard showAnswer else { return isSelected ? gameMode.accentColor.opacity(0.2) : Color.white.opacity(0.05) }
            if isCorrectAnswer { return Color.green.opacity(0.2) }
            if isSelected && !isCorrectAnswer { return Color.red.opacity(0.18) }
            return Color.white.opacity(0.03)
        }()
        let borderColor: Color = {
            guard showAnswer else { return isSelected ? gameMode.accentColor : Color.white.opacity(0.08) }
            if isCorrectAnswer { return .green }
            if isSelected && !isCorrectAnswer { return .red }
            return Color.white.opacity(0.06)
        }()

        return Button {
            guard selectedAnswer == nil, !showAnswer else { return }
            selectedAnswer = index
            handleAnswer(index: index)
        } label: {
            Text(current.answers[index])
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(RoundedRectangle(cornerRadius: 14).fill(bgColor))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(selectedAnswer != nil || showAnswer)
    }

    private func startGame() {
        playerScore = 0
        opponentScore = 0
        currentIndex = 0
        phase = .playing
        startQuestionTimer()
    }

    private func startQuestionTimer() {
        timeRemaining = 15
        selectedAnswer = nil
        showAnswer = false
        opponentAnsweredCorrectly = false
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeRemaining -= 1 }
            }
            await MainActor.run { timeExpired() }
        }
        simulateOpponentAnswer()
    }

    private func simulateOpponentAnswer() {
        let opponentDelay = Double.random(in: 4...13)
        Task {
            try? await Task.sleep(for: .seconds(opponentDelay))
            guard !Task.isCancelled, phase == .playing else { return }
            await MainActor.run {
                let correct = Double.random(in: 0...1) < 0.58
                opponentAnsweredCorrectly = correct
                if correct { opponentScore += 10 }
            }
        }
    }

    private func handleAnswer(index: Int) {
        timerTask?.cancel()
        showAnswer = true
        if index == current.correctIndex {
            let bonus = max(0, timeRemaining - 3)
            playerScore += 10 + bonus
        }
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            await MainActor.run { advanceQuestion() }
        }
    }

    private func timeExpired() {
        showAnswer = true
        Task {
            try? await Task.sleep(for: .milliseconds(1000))
            await MainActor.run { advanceQuestion() }
        }
    }

    private func advanceQuestion() {
        if currentIndex + 1 >= questions.count {
            timerTask?.cancel()
            phase = .result
        } else {
            currentIndex += 1
            questionFlash = true
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run { questionFlash = false; startQuestionTimer() }
            }
        }
    }
}

struct BrainQuestion {
    let question: String
    let answers: [String]
    let correctIndex: Int
}

enum BrainBrawlQuestions {
    static let all: [BrainQuestion] = [
        BrainQuestion(question: "How high is a regulation NBA basket?", answers: ["8 feet", "9 feet", "10 feet", "11 feet"], correctIndex: 2),
        BrainQuestion(question: "What sport uses a shuttlecock?", answers: ["Squash", "Badminton", "Pickleball", "Table tennis"], correctIndex: 1),
        BrainQuestion(question: "How many players on a volleyball team on the court?", answers: ["5", "6", "7", "8"], correctIndex: 1),
        BrainQuestion(question: "What is the maximum score for a perfect game in bowling?", answers: ["200", "250", "300", "350"], correctIndex: 2),
        BrainQuestion(question: "In track, how many laps make one mile on a standard 400m track?", answers: ["3", "4", "5", "6"], correctIndex: 1),
        BrainQuestion(question: "Which muscle group is most critical for vertical jump?", answers: ["Biceps", "Quads + Glutes", "Lats", "Traps"], correctIndex: 1),
        BrainQuestion(question: "What does PRQ stand for in Final Evolution Lab?", answers: ["Peak Response Quotient", "Performance Readiness Quotient", "Physical Reaction Quality", "Power Rhythm Quotient"], correctIndex: 1),
        BrainQuestion(question: "In a regulation dunk contest, how many dunks per round?", answers: ["1", "2", "3", "4"], correctIndex: 1),
        BrainQuestion(question: "What HealthKit metric tracks nervous system recovery?", answers: ["Step count", "Sleep score", "HRV", "VO2 max"], correctIndex: 2),
        BrainQuestion(question: "Venice Beach is located in which US city?", answers: ["Miami", "Los Angeles", "San Diego", "Santa Barbara"], correctIndex: 1),
    ]
}
