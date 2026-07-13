import Foundation
import Testing
@testable import FinalEvolutionLab

struct BrainBrawlEngineTests {

    private func makeQuestions(_ count: Int) -> [BrainBrawlQuizQuestion] {
        (0..<count).map { i in
            BrainBrawlQuizQuestion(id: i, prompt: "Q\(i)", answers: ["A", "B", "C", "D"], correctIndex: 1)
        }
    }

    // MARK: - Scoring math

    @Test func timeScaledPointsFullMidAndFloor() {
        #expect(BrainBrawlScoring.timeScaledPoints(remaining: 15, duration: 15) == 1000)
        #expect(BrainBrawlScoring.timeScaledPoints(remaining: 7.5, duration: 15) == 750)
        #expect(BrainBrawlScoring.timeScaledPoints(remaining: 0, duration: 15) == 500)
    }

    @Test func timeScaledPointsClampsOutOfRangeInputs() {
        #expect(BrainBrawlScoring.timeScaledPoints(remaining: 40, duration: 15) == 1000)
        #expect(BrainBrawlScoring.timeScaledPoints(remaining: -3, duration: 15) == 500)
        #expect(BrainBrawlScoring.timeScaledPoints(remaining: 5, duration: 0) == 0)
    }

    @Test func streakBonusRampsAndCaps() {
        #expect(BrainBrawlScoring.streakBonus(afterConsecutiveCorrect: 0) == 0)
        #expect(BrainBrawlScoring.streakBonus(afterConsecutiveCorrect: 1) == 0)
        #expect(BrainBrawlScoring.streakBonus(afterConsecutiveCorrect: 2) == 100)
        #expect(BrainBrawlScoring.streakBonus(afterConsecutiveCorrect: 4) == 300)
        #expect(BrainBrawlScoring.streakBonus(afterConsecutiveCorrect: 6) == 500)
        #expect(BrainBrawlScoring.streakBonus(afterConsecutiveCorrect: 20) == 500)
    }

    // MARK: - Engine flow

    @MainActor @Test func engineScoresSpeedAndStreaks() {
        let engine = BrainBrawlEngine(questionsPerGame: 3)
        engine.startGame(bank: makeQuestions(3), shuffle: false)
        #expect(engine.phase == .question)
        #expect(engine.currentQuestion?.prompt == "Q0")

        // Instant correct answer: full 1000 base, streak 1, no bonus yet.
        engine.answer(1, elapsed: 0)
        #expect(engine.phase == .feedback(correct: true))
        #expect(engine.score == 1000)
        #expect(engine.streak == 1)
        #expect(engine.lastBreakdown?.streakBonus == 0)
        engine.advance()

        // Buzzer-beater correct: 500 time points + 100 streak bonus.
        engine.answer(1, elapsed: 15)
        #expect(engine.score == 1600)
        #expect(engine.streak == 2)
        #expect(engine.bestStreak == 2)
        #expect(engine.lastBreakdown == BrainBrawlEngine.AnswerBreakdown(timePoints: 500, streakBonus: 100))
        engine.advance()

        // Wrong answer: no points, streak resets, best streak preserved.
        engine.answer(0, elapsed: 0)
        #expect(engine.phase == .feedback(correct: false))
        #expect(engine.score == 1600)
        #expect(engine.streak == 0)
        #expect(engine.bestStreak == 2)
        engine.advance()

        #expect(engine.phase == .results)
        #expect(engine.correctCount == 2)
        #expect(engine.answeredCount == 3)
        #expect(abs(engine.accuracy - 2.0 / 3.0) < 0.0001)
    }

    @MainActor @Test func timeoutCountsAsMissAndBreaksStreak() {
        let engine = BrainBrawlEngine(questionsPerGame: 2)
        engine.startGame(bank: makeQuestions(2), shuffle: false)

        engine.answer(1, elapsed: 0)
        #expect(engine.streak == 1)
        engine.advance()

        engine.timeExpired()
        #expect(engine.phase == .feedback(correct: false))
        #expect(engine.streak == 0)
        #expect(engine.answeredCount == 2)
        engine.advance()

        #expect(engine.phase == .results)
        #expect(engine.score == 1000)
    }

    @MainActor @Test func duplicateAnswersAndWrongPhaseAreIgnored() {
        let engine = BrainBrawlEngine(questionsPerGame: 2)
        engine.startGame(bank: makeQuestions(2), shuffle: false)

        engine.answer(1, elapsed: 0)
        let scoreAfterFirst = engine.score
        engine.answer(1, elapsed: 0) // already in feedback — ignored
        #expect(engine.score == scoreAfterFirst)
        #expect(engine.answeredCount == 1)

        engine.timeExpired() // not in .question — ignored
        #expect(engine.answeredCount == 1)
    }

    @MainActor @Test func gameDrawsRequestedQuestionCount() {
        let engine = BrainBrawlEngine(questionsPerGame: 10)
        engine.startGame()
        #expect(engine.questions.count == 10)
        #expect(engine.score == 0)
        #expect(engine.phase == .question)
    }

    // MARK: - Question bank + shuffle integrity

    @Test func questionBankIntegrity() {
        let bank = BrainBrawlQuizBank.all
        #expect(bank.count >= 40)
        #expect(Set(bank.map(\.id)).count == bank.count)
        for question in bank {
            #expect(question.answers.count == 4)
            #expect(question.answers.indices.contains(question.correctIndex))
            #expect(Set(question.answers).count == 4)
        }
    }

    @Test func answerShuffleTracksCorrectAnswer() {
        let question = BrainBrawlQuizQuestion(
            id: 99, prompt: "P", answers: ["W1", "Right", "W2", "W3"], correctIndex: 1
        )
        for _ in 0..<25 {
            let shuffled = question.shufflingAnswers()
            #expect(shuffled.answers[shuffled.correctIndex] == "Right")
            #expect(Set(shuffled.answers) == Set(question.answers))
        }
    }
}
