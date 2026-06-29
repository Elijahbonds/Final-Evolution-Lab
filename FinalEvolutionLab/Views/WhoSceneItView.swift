import SwiftUI

struct WhoSceneItView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @State private var phase: WhoPhase = .ready
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var currentIndex = 0
    @State private var timeRemaining = 20
    @State private var selectedAnswer: Int? = nil
    @State private var showAnswer = false
    @State private var showCreatorSpotlight = false
    @State private var timerTask: Task<Void, Never>?

    private enum WhoPhase { case ready, playing, result }
    private var questions: [WhoQuestion] { WhoSceneItQuestions.all }
    private var current: WhoQuestion { questions[min(currentIndex, questions.count - 1)] }

    private var activeCreatorCard: CreatorCard? {
        guard let state = viewModel.profile.activeCreatorCard else { return nil }
        return CreatorCard.catalog.first(where: { $0.id == state.cardId })
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.03, blue: 0.02), Color(red: 0.02, green: 0.02, blue: 0.06)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: gameMode.name,
                    subtitle: "Sports & creator trivia · Spot the scene",
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
                    title: "Who Scene It",
                    accentColor: gameMode.accentColor,
                    prqGain: playerScore > opponentScore ? 10 : 2,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "IQ",
                    modeAttributeValue: Double(playerScore) / Double(max(1, questions.count * 10)),
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
            ToolbarItem(placement: .topBarTrailing) {
                if let card = activeCreatorCard {
                    Button { showCreatorSpotlight = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: card.iconName).font(.system(size: 10, weight: .bold))
                            Text(card.creatorName.uppercased()).font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(card.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(card.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showCreatorSpotlight) {
            if let card = activeCreatorCard {
                CreatorCardShowcaseView(card: card)
            }
        }
        .onDisappear { timerTask?.cancel() }
    }

    private var playingBody: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, 20)
            .padding(.top, 4)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(timeRemaining > 8 ? gameMode.accentColor : Color.red)
                        .frame(width: geo.size.width * CGFloat(timeRemaining) / 20)
                        .animation(.linear(duration: 1), value: timeRemaining)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()

            if let card = activeCreatorCard, current.featureCreatorCard {
                creatorHighlightCard(card: card)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            questionArea
                .padding(.horizontal, 20)

            Spacer()

            answersGrid
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private func creatorHighlightCard(card: CreatorCard) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(card.accentColor.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: card.iconName).font(.system(size: 14, weight: .bold)).foregroundStyle(card.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("CREATOR CARD ACTIVE").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(card.accentColor)
                Text(card.showcaseTagline).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { showCreatorSpotlight = true } label: {
                Text("VIEW IP").font(.system(size: 8, weight: .black, design: .monospaced))
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(card.accentColor.opacity(0.15))
                    .foregroundStyle(card.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(card.accentColor.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 12).stroke(card.accentColor.opacity(0.18), lineWidth: 0.5)))
    }

    private var questionArea: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(gameMode.accentColor.opacity(0.08))
                    .frame(height: 80)
                Text(current.sceneDescription)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(gameMode.accentColor.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            Text(current.question)
                .font(.system(.title3, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var answersGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(current.answers.indices, id: \.self) { idx in
                answerButton(index: idx)
            }
        }
    }

    private func answerButton(index: Int) -> some View {
        let isSelected = selectedAnswer == index
        let isCorrect = index == current.correctIndex
        let bg: Color = showAnswer ? (isCorrect ? Color.green.opacity(0.18) : (isSelected ? Color.red.opacity(0.15) : Color.white.opacity(0.03))) : (isSelected ? gameMode.accentColor.opacity(0.18) : Color.white.opacity(0.05))
        let border: Color = showAnswer ? (isCorrect ? .green : (isSelected ? .red : Color.white.opacity(0.06))) : (isSelected ? gameMode.accentColor : Color.white.opacity(0.08))

        return Button {
            guard selectedAnswer == nil else { return }
            selectedAnswer = index
            handleAnswer(index: index)
        } label: {
            Text(current.answers[index])
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 12).fill(bg))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(selectedAnswer != nil)
    }

    private func startGame() {
        playerScore = 0; opponentScore = 0; currentIndex = 0
        phase = .playing
        beginQuestion()
    }

    private func beginQuestion() {
        timeRemaining = 20; selectedAnswer = nil; showAnswer = false
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeRemaining -= 1 }
            }
            await MainActor.run {
                showAnswer = true
                Task { try? await Task.sleep(for: .milliseconds(1200)); await MainActor.run { advance() } }
            }
        }
        Task {
            let delay = Double.random(in: 5...17)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, phase == .playing else { return }
            await MainActor.run {
                if Double.random(in: 0...1) < 0.55 { opponentScore += 10 }
            }
        }
    }

    private func handleAnswer(index: Int) {
        timerTask?.cancel(); showAnswer = true
        if index == current.correctIndex { playerScore += 10 + max(0, timeRemaining - 5) }
        Task { try? await Task.sleep(for: .milliseconds(1400)); await MainActor.run { advance() } }
    }

    private func advance() {
        if currentIndex + 1 >= questions.count { phase = .result }
        else { currentIndex += 1; beginQuestion() }
    }
}

struct WhoQuestion {
    let sceneDescription: String
    let question: String
    let answers: [String]
    let correctIndex: Int
    var featureCreatorCard: Bool = false
}

enum WhoSceneItQuestions {
    static let all: [WhoQuestion] = [
        WhoQuestion(sceneDescription: "🏀 Venice Beach · Blue outdoor court · Sunset", question: "Which city is the birthplace of streetball culture?", answers: ["New York", "Los Angeles", "Chicago", "Houston"], correctIndex: 1),
        WhoQuestion(sceneDescription: "🎿 Mountain halfpipe · Fresh powder · Clear sky", question: "Who invented the modern halfpipe in snowboarding?", answers: ["Shaun White", "Tom Sims & Mike Chantry", "Travis Rice", "Mark McMorris"], correctIndex: 1),
        WhoQuestion(sceneDescription: "🥋 Dojo · Wooden floor · Neon lights", question: "In karate, what does 'kiai' refer to?", answers: ["A defensive stance", "An energy shout", "A tournament format", "A throwing technique"], correctIndex: 1),
        WhoQuestion(sceneDescription: "⛳ Golf green · Coastal course · Morning mist", question: "What is an eagle in golf?", answers: ["1 over par", "1 under par", "2 under par", "Hole in one"], correctIndex: 2),
        WhoQuestion(sceneDescription: "🏄 Venice Beach ocean · Head-high waves · Midday", question: "What surfing move involves rotating 360° in the air?", answers: ["Cutback", "Aerial 360", "Bottom turn", "Floater"], correctIndex: 1, featureCreatorCard: true),
        WhoQuestion(sceneDescription: "🏐 Beach volleyball · Sand court · Crowd watching", question: "How many sets in a standard beach volleyball match?", answers: ["2", "3", "4", "5"], correctIndex: 1),
        WhoQuestion(sceneDescription: "⚽ Stadium pitch · Night match · Floodlights", question: "What is a 'brace' in football/soccer?", answers: ["A yellow card", "A player scoring twice", "A defensive formation", "An overtime period"], correctIndex: 1),
        WhoQuestion(sceneDescription: "🏈 Stadium field · Friday night lights", question: "How many yards for a first down in American football?", answers: ["5", "8", "10", "15"], correctIndex: 2),
        WhoQuestion(sceneDescription: "🎿 Skate park · Concrete ramps · Street setting", question: "What is an 'ollie' in skateboarding?", answers: ["A grind trick", "A jump without hands", "A rail slide", "A foot flip"], correctIndex: 1, featureCreatorCard: true),
        WhoQuestion(sceneDescription: "🧠 Neural Arena · Two podiums · Tense atmosphere", question: "What does HRV measure in athlete recovery?", answers: ["Heart rate variability", "Hydration levels", "High rep volume", "Hip rotation velocity"], correctIndex: 0),
    ]
}
