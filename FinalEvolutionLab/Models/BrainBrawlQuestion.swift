import Foundation

/// A single quiz question for Brain Brawl. Curriculum-focused for a person's learning path (e.g. Coursebox-style subject).
nonisolated struct BrainBrawlQuestion: Identifiable, Sendable {
    let id: String
    let trackId: String
    let subject: String
    let question: String
    let choices: [String]
    let correctIndex: Int

    var correctAnswer: String {
        guard correctIndex >= 0, correctIndex < choices.count else { return "" }
        return choices[correctIndex]
    }
}

// MARK: - Question Bank (curriculum / path-focused; expandable via API or Coursebox later)

enum BrainBrawlQuestionBank {
    /// Questions keyed by curriculum track id; "general" when no track selected.
    static func questionsForTrack(_ trackId: String?) -> [BrainBrawlQuestion] {
        let id = trackId ?? "general"
        let pool: [BrainBrawlQuestion]
        switch id {
        case "foundations":
            pool = foundationsQuestions
        case "flight":
            pool = flightQuestions
        case "elite":
            pool = eliteQuestions
        default:
            pool = generalQuestions
        }
        return pool.shuffled()
    }

    static var generalQuestions: [BrainBrawlQuestion] {
        [
            BrainBrawlQuestion(id: "g1", trackId: "general", subject: "Training", question: "What is the main benefit of a proper warm-up?", choices: ["Increases injury risk", "Raises body temp and prepares nervous system", "Shortens workout", "Replaces cool-down"], correctIndex: 1),
            BrainBrawlQuestion(id: "g2", trackId: "general", subject: "Recovery", question: "Which factor is most important for muscle recovery?", choices: ["Skipping rest days", "Sleep and nutrition", "Only stretching", "More volume"], correctIndex: 1),
            BrainBrawlQuestion(id: "g3", trackId: "general", subject: "Movement", question: "What does 'ground contact time' refer to in plyometrics?", choices: ["Time in the air", "Time foot is on the ground per hop", "Rest between sets", "Session length"], correctIndex: 1),
            BrainBrawlQuestion(id: "g4", trackId: "general", subject: "Anatomy", question: "Which muscles are primary for vertical jump?", choices: ["Only biceps", "Quads, glutes, calves", "Only calves", "Upper back only"], correctIndex: 1),
            BrainBrawlQuestion(id: "g5", trackId: "general", subject: "Programming", question: "What does 'progressive overload' mean?", choices: ["Doing the same weight forever", "Gradually increasing demand over time", "Only doing one exercise", "Skipping hard days"], correctIndex: 1),
            BrainBrawlQuestion(id: "g6", trackId: "general", subject: "Recovery", question: "What is a key role of the central nervous system in performance?", choices: ["Only digestion", "Recruiting muscles and coordinating movement", "Storing fat", "Cooling the body"], correctIndex: 1),
            BrainBrawlQuestion(id: "g7", trackId: "general", subject: "Movement", question: "Why is the 'penultimate step' important in a jump approach?", choices: ["It doesn't matter", "It sets up hip and knee angles for max force", "It's only for style", "It slows you down"], correctIndex: 1),
            BrainBrawlQuestion(id: "g8", trackId: "general", subject: "Training", question: "What is the purpose of a deload week?", choices: ["Train harder every day", "Reduce volume to allow adaptation and recovery", "Only for beginners", "Skip the gym entirely"], correctIndex: 1),
            BrainBrawlQuestion(id: "g9", trackId: "general", subject: "Anatomy", question: "Which joint is most involved in ankle stiffness during hopping?", choices: ["Shoulder", "Hip", "Ankle (talocrural)", "Wrist"], correctIndex: 2),
            BrainBrawlQuestion(id: "g10", trackId: "general", subject: "Programming", question: "What does 'periodization' refer to?", choices: ["Random workouts", "Structured planning of intensity and volume over time", "Only competition day", "Single week plans"], correctIndex: 1),
        ]
    }

    static var foundationsQuestions: [BrainBrawlQuestion] {
        [
            BrainBrawlQuestion(id: "f1", trackId: "foundations", subject: "Foundations", question: "What is the main goal of foundation-phase training?", choices: ["Max strength only", "Build base movement quality and capacity", "Only flexibility", "Peak power every day"], correctIndex: 1),
            BrainBrawlQuestion(id: "f2", trackId: "foundations", subject: "Foundations", question: "Why are scaled pogos used early in a program?", choices: ["To max out jump height", "To develop ankle stiffness with low impact", "To replace lifting", "Only for pros"], correctIndex: 1),
            BrainBrawlQuestion(id: "f3", trackId: "foundations", subject: "Foundations", question: "What is a key benefit of box jumps in foundations?", choices: ["No benefit", "Teaches landing and explosive intent with reduced risk", "Replaces running", "Only for testing"], correctIndex: 1),
            BrainBrawlQuestion(id: "f4", trackId: "foundations", subject: "Foundations", question: "Why is ankle mobility work included in foundations?", choices: ["It isn't important", "Better range supports squat and jump mechanics", "Only for injury rehab", "To replace strength work"], correctIndex: 1),
            BrainBrawlQuestion(id: "f5", trackId: "foundations", subject: "Foundations", question: "What do lateral shuffles primarily develop?", choices: ["Only vertical jump", "Agility and low stance control", "Max speed only", "Upper body power"], correctIndex: 1),
            BrainBrawlQuestion(id: "f6", trackId: "foundations", subject: "Foundations", question: "How does foundation phase support later 'flight' training?", choices: ["It doesn't", "Builds tissue tolerance and movement patterns", "By skipping it", "Only with weights"], correctIndex: 1),
            BrainBrawlQuestion(id: "f7", trackId: "foundations", subject: "Foundations", question: "What is a sensible rest between foundation plyometric sets?", choices: ["No rest", "~45–60 seconds for quality recovery", "5 minutes only", "Until next day"], correctIndex: 1),
            BrainBrawlQuestion(id: "f8", trackId: "foundations", subject: "Foundations", question: "Why is 'soft landing' emphasized in foundation jumps?", choices: ["For style only", "Reduces impact and reinforces good mechanics", "To jump lower", "Only in competition"], correctIndex: 1),
            BrainBrawlQuestion(id: "f9", trackId: "foundations", subject: "Foundations", question: "What role do split squats play in foundations?", choices: ["None", "Single-leg strength and balance", "Replace all jumping", "Only for warm-up"], correctIndex: 1),
            BrainBrawlQuestion(id: "f10", trackId: "foundations", subject: "Foundations", question: "When progressing from foundations, what should increase first?", choices: ["Only intensity", "Volume and complexity before max intensity", "Only frequency", "Rest only"], correctIndex: 1),
        ]
    }

    static var flightQuestions: [BrainBrawlQuestion] {
        [
            BrainBrawlQuestion(id: "fl1", trackId: "flight", subject: "Flight", question: "What is the main purpose of a depth jump?", choices: ["Land only", "Use the stretch-shorten cycle for reactive power", "Replace box jumps", "Only for testing"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl2", trackId: "flight", subject: "Flight", question: "Why is single-leg stabilization trained in flight phase?", choices: ["It isn't", "Jumps often land on one leg; stability prevents injury", "Only for balance", "To replace bilateral work"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl3", trackId: "flight", subject: "Flight", question: "What does 'hip flexor activation' support in jumping?", choices: ["Nothing", "Knee drive and front-side mechanics", "Only running", "Only cool-down"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl4", trackId: "flight", subject: "Flight", question: "How does Bulgarian split squat help flight performance?", choices: ["It doesn't", "Single-leg strength and depth for takeoff", "Only for size", "Replaces plyos"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl5", trackId: "flight", subject: "Flight", question: "What is the goal of cone agility work in flight phase?", choices: ["Only conditioning", "Multi-directional speed and change of direction", "Replace jumps", "Only for fun"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl6", trackId: "flight", subject: "Flight", question: "Why is rest longer (e.g. 75–90s) in flight phase than foundations?", choices: ["Arbitrary", "Higher intensity needs more recovery for quality", "To do fewer sets", "Only for elites"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl7", trackId: "flight", subject: "Flight", question: "What is 'reactive strength' in the context of flight training?", choices: ["Only strength", "Ability to produce force quickly after landing", "Only speed", "Only flexibility"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl8", trackId: "flight", subject: "Flight", question: "How does lateral leap differ from a lateral shuffle?", choices: ["Same thing", "Leap is explosive and single-response; shuffle is repeated", "Shuffle is harder", "Only name difference"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl9", trackId: "flight", subject: "Flight", question: "What should you prioritize when moving from foundations to flight?", choices: ["Volume only", "Progressive intensity while keeping quality", "Only frequency", "Skip foundations"], correctIndex: 1),
            BrainBrawlQuestion(id: "fl10", trackId: "flight", subject: "Flight", question: "Why is hip extension emphasized in flight phase?", choices: ["It isn't", "Primary driver of vertical and horizontal power", "Only for sprinting", "Only for lifting"], correctIndex: 1),
        ]
    }

    static var eliteQuestions: [BrainBrawlQuestion] {
        [
            BrainBrawlQuestion(id: "e1", trackId: "elite", subject: "Elite", question: "What is the main focus of dunk sessions in elite phase?", choices: ["Volume only", "Penultimate step and arm swing timing at game intensity", "Only conditioning", "Only testing"], correctIndex: 1),
            BrainBrawlQuestion(id: "e2", trackId: "elite", subject: "Elite", question: "Why might weighted depth jumps be used in elite training?", choices: ["Never used", "Controlled overload for advanced athletes", "Replace all plyos", "Only for testing"], correctIndex: 1),
            BrainBrawlQuestion(id: "e3", trackId: "elite", subject: "Elite", question: "What does trap bar deadlift contribute to elite vertical performance?", choices: ["Nothing", "Peak force in posterior chain and quads", "Only size", "Replaces jumping"], correctIndex: 1),
            BrainBrawlQuestion(id: "e4", trackId: "elite", subject: "Elite", question: "What is 'neural drive' in the context of elite sprint work?", choices: ["Only psychology", "High intent and CNS recruitment", "Only endurance", "Only warm-up"], correctIndex: 1),
            BrainBrawlQuestion(id: "e5", trackId: "elite", subject: "Elite", question: "Why is recovery protocol part of elite programming?", choices: ["Optional", "CNS and tissue recovery to sustain high load", "Only for injury", "Replace training"], correctIndex: 1),
            BrainBrawlQuestion(id: "e6", trackId: "elite", subject: "Elite", question: "How does elite phase differ from flight phase?", choices: ["Same thing", "Higher intensity, sport-specific skill, and recovery focus", "Only more volume", "Only for pros"], correctIndex: 1),
            BrainBrawlQuestion(id: "e7", trackId: "elite", subject: "Elite", question: "What is a key risk of skipping foundation and flight before elite?", choices: ["No risk", "Injury and underperformance from insufficient base", "Only mental", "Only for young athletes"], correctIndex: 1),
            BrainBrawlQuestion(id: "e8", trackId: "elite", subject: "Elite", question: "Why are rest periods longest in elite phase?", choices: ["Arbitrary", "Max efforts require full recovery for quality", "To train less", "Only in competition"], correctIndex: 1),
            BrainBrawlQuestion(id: "e9", trackId: "elite", subject: "Elite", question: "What role does 'intent' play in elite plyometrics?", choices: ["None", "Max intent each rep drives neural adaptation", "Only for motivation", "Only in games"], correctIndex: 1),
            BrainBrawlQuestion(id: "e10", trackId: "elite", subject: "Elite", question: "How should elite training be periodized around competition?", choices: ["Always max", "Peak and taper so athlete is fresh for key dates", "No planning", "Only volume"], correctIndex: 1),
        ]
    }
}
