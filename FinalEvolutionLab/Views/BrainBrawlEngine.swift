import Foundation
import Combine

// MARK: - Question Model

/// One multiple-choice quiz question — exactly four answers, one correct.
nonisolated struct BrainBrawlQuizQuestion: Identifiable, Equatable, Sendable {
    let id: Int
    let prompt: String
    let answers: [String]
    let correctIndex: Int

    /// Returns a copy with the answer tiles re-ordered (correct answer tracked).
    func shufflingAnswers() -> BrainBrawlQuizQuestion {
        let order = Array(answers.indices).shuffled()
        return BrainBrawlQuizQuestion(
            id: id,
            prompt: prompt,
            answers: order.map { answers[$0] },
            correctIndex: order.firstIndex(of: correctIndex) ?? 0
        )
    }
}

// MARK: - Scoring (pure, unit-testable)

/// Kahoot-style scoring math. Kept `nonisolated` + static so tests exercise it
/// without spinning up the engine.
nonisolated enum BrainBrawlScoring {
    static let basePoints = 1000
    static let questionDuration: TimeInterval = 15
    static let streakBonusStep = 100
    static let streakBonusCap = 500

    /// Base 1000 scaled by remaining time: instant answer pays the full base,
    /// an answer at the buzzer still pays half. Inputs are clamped.
    static func timeScaledPoints(
        remaining: TimeInterval,
        duration: TimeInterval = questionDuration,
        base: Int = basePoints
    ) -> Int {
        guard duration > 0 else { return 0 }
        let fraction = min(max(remaining / duration, 0), 1)
        return Int((Double(base) * (0.5 + 0.5 * fraction)).rounded())
    }

    /// +100 per consecutive correct answer beyond the first, capped at +500.
    static func streakBonus(afterConsecutiveCorrect streak: Int) -> Int {
        guard streak >= 2 else { return 0 }
        return min((streak - 1) * streakBonusStep, streakBonusCap)
    }
}

// MARK: - Engine

/// Single-player Brain Brawl round engine. Owns question flow, the per-question
/// timeout, scoring, and streak state. Score submission stays behind the
/// `onGameEnd` hook so the existing scoring/multipeer harness can plug in later.
@MainActor
final class BrainBrawlEngine: ObservableObject {

    enum Phase: Equatable {
        case ready
        case question
        case feedback(correct: Bool)
        case results
    }

    struct AnswerBreakdown: Equatable {
        let timePoints: Int
        let streakBonus: Int
        var total: Int { timePoints + streakBonus }
    }

    // MARK: Published state

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var questions: [BrainBrawlQuizQuestion] = []
    @Published private(set) var questionIndex = 0
    @Published private(set) var score = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var correctCount = 0
    @Published private(set) var answeredCount = 0
    @Published private(set) var selectedAnswerIndex: Int?
    @Published private(set) var questionStartedAt = Date.now
    @Published private(set) var lastBreakdown: AnswerBreakdown?

    // MARK: Configuration

    let questionsPerGame: Int
    let questionDuration: TimeInterval
    private let feedbackDelay: TimeInterval

    /// Future hook: multipeer / backend score submission at game end.
    var onGameEnd: ((Int) -> Void)?

    private var timeoutTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?

    init(
        questionsPerGame: Int = 10,
        questionDuration: TimeInterval = BrainBrawlScoring.questionDuration,
        feedbackDelay: TimeInterval = 1.6
    ) {
        self.questionsPerGame = questionsPerGame
        self.questionDuration = questionDuration
        self.feedbackDelay = feedbackDelay
    }

    // MARK: Derived state

    var currentQuestion: BrainBrawlQuizQuestion? {
        guard questions.indices.contains(questionIndex) else { return nil }
        return questions[questionIndex]
    }

    var accuracy: Double {
        guard answeredCount > 0 else { return 0 }
        return Double(correctCount) / Double(answeredCount)
    }

    // MARK: Flow

    func startGame(
        bank: [BrainBrawlQuizQuestion] = BrainBrawlQuizBank.all,
        shuffle: Bool = true
    ) {
        cancelTasks()
        let drawn = shuffle ? Array(bank.shuffled().prefix(questionsPerGame)) : Array(bank.prefix(questionsPerGame))
        questions = shuffle ? drawn.map { $0.shufflingAnswers() } : drawn
        questionIndex = 0
        score = 0
        streak = 0
        bestStreak = 0
        correctCount = 0
        answeredCount = 0
        lastBreakdown = nil
        beginQuestion()
    }

    /// Live answer path — elapsed time measured from `questionStartedAt`.
    func answer(_ index: Int) {
        answer(index, elapsed: Date.now.timeIntervalSince(questionStartedAt))
    }

    /// Deterministic answer path (tests inject elapsed time directly).
    func answer(_ index: Int, elapsed: TimeInterval) {
        guard phase == .question, let question = currentQuestion, selectedAnswerIndex == nil else { return }
        timeoutTask?.cancel()
        selectedAnswerIndex = index
        answeredCount += 1

        let correct = index == question.correctIndex
        if correct {
            streak += 1
            bestStreak = max(bestStreak, streak)
            correctCount += 1
            let remaining = max(0, questionDuration - elapsed)
            let breakdown = AnswerBreakdown(
                timePoints: BrainBrawlScoring.timeScaledPoints(remaining: remaining, duration: questionDuration),
                streakBonus: BrainBrawlScoring.streakBonus(afterConsecutiveCorrect: streak)
            )
            lastBreakdown = breakdown
            score += breakdown.total
        } else {
            streak = 0
            lastBreakdown = nil
        }

        phase = .feedback(correct: correct)
        scheduleAdvance()
    }

    /// Countdown hit zero with no answer — counts as a miss and breaks the streak.
    func timeExpired() {
        guard phase == .question, selectedAnswerIndex == nil else { return }
        timeoutTask?.cancel()
        answeredCount += 1
        streak = 0
        lastBreakdown = nil
        phase = .feedback(correct: false)
        scheduleAdvance()
    }

    /// Moves from feedback to the next question, or to results after the last one.
    func advance() {
        guard case .feedback = phase else { return }
        advanceTask?.cancel()
        if questionIndex + 1 >= questions.count {
            phase = .results
            onGameEnd?(score)
        } else {
            questionIndex += 1
            beginQuestion()
        }
    }

    func stop() {
        cancelTasks()
    }

    // MARK: Private

    private func beginQuestion() {
        selectedAnswerIndex = nil
        questionStartedAt = .now
        phase = .question
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self, questionDuration] in
            try? await Task.sleep(for: .seconds(questionDuration))
            guard !Task.isCancelled else { return }
            self?.timeExpired()
        }
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task { [weak self, feedbackDelay] in
            try? await Task.sleep(for: .seconds(feedbackDelay))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    private func cancelTasks() {
        timeoutTask?.cancel()
        advanceTask?.cancel()
    }
}

// MARK: - Question Bank

/// Original FEL trivia — sports, fitness/kinesiology, basketball, martial arts.
/// 40 questions; each game draws 10 at random with shuffled answer tiles.
/// (Named distinctly from the legacy `Services/BrainBrawlQuestionBank`.)
nonisolated enum BrainBrawlQuizBank {
    static let all: [BrainBrawlQuizQuestion] = [
        // Basketball
        BrainBrawlQuizQuestion(id: 1, prompt: "How high is a regulation NBA rim from the floor?",
                               answers: ["8 feet", "9 feet", "10 feet", "11 feet"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 2, prompt: "How many seconds are on the NBA shot clock?",
                               answers: ["14", "24", "30", "35"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 3, prompt: "A made free throw is worth how many points?",
                               answers: ["1 point", "2 points", "3 points", "4 points"], correctIndex: 0),
        BrainBrawlQuizQuestion(id: 4, prompt: "How many players per team are on the court in basketball?",
                               answers: ["4", "5", "6", "7"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 5, prompt: "A triple-double means double digits in how many stat categories?",
                               answers: ["2", "3", "4", "5"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 6, prompt: "In what year was basketball invented?",
                               answers: ["1875", "1891", "1901", "1920"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 7, prompt: "How many minutes long is a regulation NBA game?",
                               answers: ["40", "44", "48", "60"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 8, prompt: "A shot that goes in touching nothing but net is called a:",
                               answers: ["Swish", "Bank shot", "Floater", "Brick"], correctIndex: 0),
        BrainBrawlQuizQuestion(id: 9, prompt: "The NBA three-point line at the top of the arc is about:",
                               answers: ["21 feet", "22 feet", "23.75 feet", "26 feet"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 10, prompt: "A double dribble violation results in a:",
                               answers: ["Free throw", "Turnover", "Jump ball", "Technical foul"], correctIndex: 1),

        // Fitness & kinesiology
        BrainBrawlQuizQuestion(id: 11, prompt: "What is the largest muscle in the human body?",
                               answers: ["Biceps brachii", "Quadriceps", "Gluteus maximus", "Latissimus dorsi"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 12, prompt: "ATP, the cell's energy currency, stands for:",
                               answers: ["Adenosine triphosphate", "Amino tripeptide", "Aerobic transfer protein", "Active tissue power"], correctIndex: 0),
        BrainBrawlQuizQuestion(id: 13, prompt: "In training, RPE stands for:",
                               answers: ["Rapid power expression", "Rate of perceived exertion", "Resting pulse estimate", "Reactive plyometric effort"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 14, prompt: "The squat primarily targets which muscles?",
                               answers: ["Chest and triceps", "Quads and glutes", "Lats and biceps", "Calves and shins"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 15, prompt: "HIIT stands for:",
                               answers: ["Heavy incline interval time", "High-impact isometric training", "High-intensity interval training", "Hybrid intensity indoor training"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 16, prompt: "How many bones are in the adult human body?",
                               answers: ["186", "206", "226", "250"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 17, prompt: "DOMS, the soreness after hard training, stands for:",
                               answers: ["Delayed onset muscle soreness", "Deep oxygen muscle shortage", "Direct overload muscle strain", "Daily output muscle score"], correctIndex: 0),
        BrainBrawlQuizQuestion(id: 18, prompt: "Fast-twitch, high-power muscle fibers are classified as:",
                               answers: ["Type I", "Type II", "Type III", "Type IV"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 19, prompt: "The plank exercise primarily trains the:",
                               answers: ["Core", "Hamstrings", "Forearms", "Neck"], correctIndex: 0),
        BrainBrawlQuizQuestion(id: 20, prompt: "VO2 max is a measure of:",
                               answers: ["Lung volume", "Maximal oxygen uptake", "Peak heart rate", "Blood pressure"], correctIndex: 1),

        // Martial arts
        BrainBrawlQuizQuestion(id: 21, prompt: "Karate was developed on which Japanese island chain?",
                               answers: ["Okinawa", "Hokkaido", "Shikoku", "Izu"], correctIndex: 0),
        BrainBrawlQuizQuestion(id: 22, prompt: "Who founded judo?",
                               answers: ["Gichin Funakoshi", "Jigoro Kano", "Morihei Ueshiba", "Ip Man"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 23, prompt: "The word \u{201C}dojo\u{201D} roughly translates to:",
                               answers: ["House of fists", "Iron fortress", "Place of the way", "Fighting pit"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 24, prompt: "Taekwondo originated in which country?",
                               answers: ["China", "Japan", "Thailand", "Korea"], correctIndex: 3),
        BrainBrawlQuizQuestion(id: 25, prompt: "Muay Thai is known as the art of how many limbs?",
                               answers: ["Four", "Six", "Eight", "Ten"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 26, prompt: "Brazilian jiu-jitsu specializes in:",
                               answers: ["High kicks", "Ground grappling and submissions", "Weapon forms", "Board breaking"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 27, prompt: "In many martial arts, a \u{201C}gi\u{201D} is the:",
                               answers: ["Training uniform", "Wooden sword", "Belt rank", "Bowing ritual"], correctIndex: 0),
        BrainBrawlQuizQuestion(id: 28, prompt: "\u{201C}Sensei\u{201D} is best translated as:",
                               answers: ["Champion", "Warrior", "Teacher", "Referee"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 29, prompt: "Capoeira, blending dance and combat, developed in:",
                               answers: ["Cuba", "Brazil", "Portugal", "Mexico"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 30, prompt: "In boxing, a \u{201C}southpaw\u{201D} fights from which stance?",
                               answers: ["Left-handed", "Right-handed", "Square-on", "Crouching"], correctIndex: 0),

        // General sports & body
        BrainBrawlQuizQuestion(id: 31, prompt: "The Summer Olympics are held every how many years?",
                               answers: ["2", "3", "4", "5"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 32, prompt: "A full marathon covers about how many miles?",
                               answers: ["13.1", "20.5", "26.2", "31.0"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 33, prompt: "In tennis, a score of zero is called:",
                               answers: ["Nil", "Love", "Duck", "Blank"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 34, prompt: "How many volleyball players are on the court per side?",
                               answers: ["5", "6", "7", "8"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 35, prompt: "Each half of a regulation soccer match lasts:",
                               answers: ["30 minutes", "40 minutes", "45 minutes", "50 minutes"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 36, prompt: "A hat-trick in soccer means one player scores:",
                               answers: ["Two goals", "Three goals", "Four goals", "Five goals"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 37, prompt: "Which swimming stroke is performed face-up?",
                               answers: ["Butterfly", "Breaststroke", "Freestyle", "Backstroke"], correctIndex: 3),
        BrainBrawlQuizQuestion(id: 38, prompt: "A bronze medal is awarded for finishing in which place?",
                               answers: ["First", "Second", "Third", "Fourth"], correctIndex: 2),
        BrainBrawlQuizQuestion(id: 39, prompt: "In baseball, three strikes on a batter result in a:",
                               answers: ["Walk", "Strikeout", "Balk", "Home run"], correctIndex: 1),
        BrainBrawlQuizQuestion(id: 40, prompt: "Which muscle separates the chest from the abdomen and drives breathing?",
                               answers: ["Deltoid", "Sartorius", "Diaphragm", "Trapezius"], correctIndex: 2),
    ]
}
