import Foundation

public struct BrainBrawlQuestion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public let category: BrainBrawlCategory
    public let text: String
    public let choices: [String]
    public let correctIndex: Int
    public let explanation: String
    public let difficultyMultiplier: Double

    public init(
        category: BrainBrawlCategory,
        text: String,
        choices: [String],
        correctIndex: Int,
        explanation: String,
        difficultyMultiplier: Double = 1.0
    ) {
        self.category = category
        self.text = text
        self.choices = choices
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.difficultyMultiplier = difficultyMultiplier
    }
}

public enum BrainBrawlQuestionBank {
    public static var categories: [BrainBrawlCategory] {
        BrainBrawlCategory.allCases
    }

    public static let questions: [BrainBrawlQuestion] = scienceQuestions
        + sportsQuestions
        + entertainmentQuestions
        + geographyQuestions
        + historyQuestions
        + artsQuestions

    public static func questions(for category: BrainBrawlCategory) -> [BrainBrawlQuestion] {
        questions.filter { $0.category == category }
    }

    public static func randomQuestion(
        for category: BrainBrawlCategory,
        excluding ids: Set<UUID> = []
    ) -> BrainBrawlQuestion? {
        let pool = questions(for: category).filter { !ids.contains($0.id) }
        return pool.randomElement() ?? questions(for: category).randomElement()
    }

    // MARK: - Science
    private static let scienceQuestions: [BrainBrawlQuestion] = [
        BrainBrawlQuestion(
            category: .science,
            text: "Which organelle is known as the powerhouse of the cell?",
            choices: ["Nucleus", "Ribosome", "Mitochondria", "Golgi apparatus"],
            correctIndex: 2,
            explanation: "Mitochondria generate ATP through cellular respiration."
        ),
        BrainBrawlQuestion(
            category: .science,
            text: "What is the chemical symbol for gold?",
            choices: ["Go", "Gd", "Au", "Ag"],
            correctIndex: 2,
            explanation: "Au comes from the Latin word aurum."
        ),
        BrainBrawlQuestion(
            category: .science,
            text: "How many bones are in an adult human body?",
            choices: ["186", "206", "226", "256"],
            correctIndex: 1,
            explanation: "Adults have 206 bones; infants have more before fusion."
        ),
        BrainBrawlQuestion(
            category: .science,
            text: "Which planet is known as the Red Planet?",
            choices: ["Venus", "Mars", "Jupiter", "Saturn"],
            correctIndex: 1,
            explanation: "Iron oxide on Mars gives it a reddish appearance."
        ),
        BrainBrawlQuestion(
            category: .science,
            text: "What gas do plants absorb from the atmosphere for photosynthesis?",
            choices: ["Oxygen", "Nitrogen", "Carbon dioxide", "Hydrogen"],
            correctIndex: 2,
            explanation: "Plants use CO₂ and sunlight to produce glucose."
        ),
        BrainBrawlQuestion(
            category: .science,
            text: "What is the speed of light in a vacuum (approx.)?",
            choices: ["150,000 km/s", "299,792 km/s", "450,000 km/s", "1,000,000 km/s"],
            correctIndex: 1,
            explanation: "Light travels at 299,792,458 m/s in a vacuum.",
            difficultyMultiplier: 1.2
        ),
        BrainBrawlQuestion(
            category: .science,
            text: "Which subatomic particle has a negative charge?",
            choices: ["Proton", "Neutron", "Electron", "Photon"],
            correctIndex: 2,
            explanation: "Electrons orbit the nucleus and carry a negative charge."
        ),
        BrainBrawlQuestion(
            category: .science,
            text: "What is the hardest natural substance on Earth?",
            choices: ["Quartz", "Diamond", "Topaz", "Corundum"],
            correctIndex: 1,
            explanation: "Diamond ranks 10 on the Mohs hardness scale."
        )
    ]

    // MARK: - Sports
    private static let sportsQuestions: [BrainBrawlQuestion] = [
        BrainBrawlQuestion(
            category: .sports,
            text: "How high is a regulation NBA basketball rim?",
            choices: ["9 feet", "10 feet", "10.5 feet", "11 feet"],
            correctIndex: 1,
            explanation: "NBA rims are 10 feet (3.05 m) above the floor."
        ),
        BrainBrawlQuestion(
            category: .sports,
            text: "How many players per team are on a soccer field?",
            choices: ["9", "10", "11", "12"],
            correctIndex: 2,
            explanation: "Each side fields 11 players including the goalkeeper."
        ),
        BrainBrawlQuestion(
            category: .sports,
            text: "Which country has won the most FIFA World Cups?",
            choices: ["Germany", "Italy", "Argentina", "Brazil"],
            correctIndex: 3,
            explanation: "Brazil has won five World Cups (1958–2002)."
        ),
        BrainBrawlQuestion(
            category: .sports,
            text: "In tennis, what is a score of zero called?",
            choices: ["Nil", "Love", "Blank", "Zero"],
            correctIndex: 1,
            explanation: "Love likely derives from the French l'oeuf (egg = zero)."
        ),
        BrainBrawlQuestion(
            category: .sports,
            text: "How many points is a touchdown worth before the extra point?",
            choices: ["3", "6", "7", "8"],
            correctIndex: 1,
            explanation: "A touchdown is worth 6 points in American football."
        ),
        BrainBrawlQuestion(
            category: .sports,
            text: "Which Grand Slam is played on grass courts?",
            choices: ["US Open", "French Open", "Wimbledon", "Australian Open"],
            correctIndex: 2,
            explanation: "Wimbledon is the only major still played on grass."
        ),
        BrainBrawlQuestion(
            category: .sports,
            text: "How many rings are on the Olympic flag?",
            choices: ["4", "5", "6", "7"],
            correctIndex: 1,
            explanation: "Five interlocking rings represent the inhabited continents."
        ),
        BrainBrawlQuestion(
            category: .sports,
            text: "In basketball, how many personal fouls typically disqualify an NBA player?",
            choices: ["4", "5", "6", "7"],
            correctIndex: 2,
            explanation: "NBA players foul out after six personal fouls."
        )
    ]

    // MARK: - Entertainment
    private static let entertainmentQuestions: [BrainBrawlQuestion] = [
        BrainBrawlQuestion(
            category: .entertainment,
            text: "How many squares are on a chessboard?",
            choices: ["32", "64", "72", "81"],
            correctIndex: 1,
            explanation: "A chessboard is an 8x8 grid — 64 squares."
        ),
        BrainBrawlQuestion(
            category: .entertainment,
            text: "What is a perfect score in ten-pin bowling?",
            choices: ["200", "250", "300", "500"],
            correctIndex: 2,
            explanation: "Twelve consecutive strikes score a perfect 300."
        ),
        BrainBrawlQuestion(
            category: .entertainment,
            text: "How many cards are in a standard deck, not counting jokers?",
            choices: ["48", "50", "52", "54"],
            correctIndex: 2,
            explanation: "Four suits of thirteen cards make 52."
        ),
        BrainBrawlQuestion(
            category: .entertainment,
            text: "Karaoke singing originated in which country?",
            choices: ["China", "Japan", "South Korea", "United States"],
            correctIndex: 1,
            explanation: "Karaoke — 'empty orchestra' — began in Japan in the 1970s."
        ),
        BrainBrawlQuestion(
            category: .entertainment,
            text: "In darts, what is the highest score from a single throw?",
            choices: ["20", "40", "50", "60"],
            correctIndex: 3,
            explanation: "A triple 20 scores 60 — the bullseye is only 50."
        ),
        BrainBrawlQuestion(
            category: .entertainment,
            text: "Competitive organized video gaming is commonly known as what?",
            choices: ["Cybergames", "Esports", "Prohacking", "Speedplay"],
            correctIndex: 1,
            explanation: "Esports tournaments now fill arenas worldwide."
        ),
        BrainBrawlQuestion(
            category: .entertainment,
            text: "On a film set, what does the clapperboard help synchronize?",
            choices: ["Lighting cues", "Sound and picture", "Actor blocking", "Camera focus"],
            correctIndex: 1,
            explanation: "The clap gives editors a sharp sync point for audio and video."
        ),
        BrainBrawlQuestion(
            category: .entertainment,
            text: "In improv comedy, what is the classic guiding principle called?",
            choices: ["No, but", "Yes, and", "Go big", "Freeze frame"],
            correctIndex: 1,
            explanation: "'Yes, and' keeps a scene building instead of stalling."
        )
    ]

    // MARK: - Geography
    private static let geographyQuestions: [BrainBrawlQuestion] = [
        BrainBrawlQuestion(
            category: .geography,
            text: "What is the capital of Japan?",
            choices: ["Seoul", "Beijing", "Tokyo", "Bangkok"],
            correctIndex: 2,
            explanation: "Tokyo has been Japan's capital since 1868."
        ),
        BrainBrawlQuestion(
            category: .geography,
            text: "Which is the longest river in the world?",
            choices: ["Amazon", "Nile", "Mississippi", "Yangtze"],
            correctIndex: 1,
            explanation: "The Nile flows about 6,650 km through northeastern Africa."
        ),
        BrainBrawlQuestion(
            category: .geography,
            text: "How many continents are there?",
            choices: ["5", "6", "7", "8"],
            correctIndex: 2,
            explanation: "Seven: Africa, Antarctica, Asia, Europe, N. America, S. America, Australia."
        ),
        BrainBrawlQuestion(
            category: .geography,
            text: "Which country has the largest land area?",
            choices: ["Canada", "China", "United States", "Russia"],
            correctIndex: 3,
            explanation: "Russia spans roughly 17.1 million km²."
        ),
        BrainBrawlQuestion(
            category: .geography,
            text: "What is the smallest country in the world?",
            choices: ["Monaco", "Vatican City", "San Marino", "Liechtenstein"],
            correctIndex: 1,
            explanation: "Vatican City covers about 0.44 km² within Rome."
        ),
        BrainBrawlQuestion(
            category: .geography,
            text: "Mount Everest lies on the border of Nepal and which country?",
            choices: ["India", "China", "Bhutan", "Pakistan"],
            correctIndex: 1,
            explanation: "Everest's summit straddles Nepal and Tibet (China)."
        ),
        BrainBrawlQuestion(
            category: .geography,
            text: "Which ocean is the largest?",
            choices: ["Atlantic", "Indian", "Arctic", "Pacific"],
            correctIndex: 3,
            explanation: "The Pacific covers more area than all land combined."
        ),
        BrainBrawlQuestion(
            category: .geography,
            text: "What is the capital of Australia?",
            choices: ["Sydney", "Melbourne", "Canberra", "Brisbane"],
            correctIndex: 2,
            explanation: "Canberra was chosen as a compromise between Sydney and Melbourne."
        )
    ]

    // MARK: - History
    private static let historyQuestions: [BrainBrawlQuestion] = [
        BrainBrawlQuestion(
            category: .history,
            text: "In what year did World War II end?",
            choices: ["1943", "1944", "1945", "1946"],
            correctIndex: 2,
            explanation: "Germany surrendered in May 1945; Japan in August 1945."
        ),
        BrainBrawlQuestion(
            category: .history,
            text: "Who was the first President of the United States?",
            choices: ["Thomas Jefferson", "John Adams", "George Washington", "Benjamin Franklin"],
            correctIndex: 2,
            explanation: "Washington served from 1789 to 1797."
        ),
        BrainBrawlQuestion(
            category: .history,
            text: "The Great Wall was built primarily to protect which country?",
            choices: ["Japan", "India", "China", "Mongolia"],
            correctIndex: 2,
            explanation: "Chinese dynasties built walls against northern invaders."
        ),
        BrainBrawlQuestion(
            category: .history,
            text: "Which ancient civilization built the pyramids at Giza?",
            choices: ["Romans", "Greeks", "Egyptians", "Persians"],
            correctIndex: 2,
            explanation: "The Great Pyramid was completed around 2560 BCE."
        ),
        BrainBrawlQuestion(
            category: .history,
            text: "The Renaissance began in which country?",
            choices: ["France", "England", "Italy", "Spain"],
            correctIndex: 2,
            explanation: "Florence was a cradle of Renaissance art and science."
        ),
        BrainBrawlQuestion(
            category: .history,
            text: "Who wrote the Declaration of Independence?",
            choices: ["George Washington", "Thomas Jefferson", "James Madison", "John Hancock"],
            correctIndex: 1,
            explanation: "Jefferson drafted it; Congress adopted it on July 4, 1776."
        ),
        BrainBrawlQuestion(
            category: .history,
            text: "The Berlin Wall fell in which year?",
            choices: ["1987", "1989", "1991", "1993"],
            correctIndex: 1,
            explanation: "East and West Berliners began dismantling it in November 1989."
        ),
        BrainBrawlQuestion(
            category: .history,
            text: "Which empire was ruled by Julius Caesar?",
            choices: ["Greek", "Roman", "Ottoman", "Byzantine"],
            correctIndex: 1,
            explanation: "Caesar was a dictator of the Roman Republic before its empire."
        )
    ]

    // MARK: - Arts
    private static let artsQuestions: [BrainBrawlQuestion] = [
        BrainBrawlQuestion(
            category: .arts,
            text: "Who painted the Mona Lisa?",
            choices: ["Michelangelo", "Leonardo da Vinci", "Raphael", "Donatello"],
            correctIndex: 1,
            explanation: "Da Vinci painted it in the early 1500s."
        ),
        BrainBrawlQuestion(
            category: .arts,
            text: "Who wrote Romeo and Juliet?",
            choices: ["Charles Dickens", "William Shakespeare", "Jane Austen", "Mark Twain"],
            correctIndex: 1,
            explanation: "Shakespeare's tragedy was written around 1594–1596."
        ),
        BrainBrawlQuestion(
            category: .arts,
            text: "Which instrument has 88 keys?",
            choices: ["Organ", "Piano", "Harpsichord", "Accordion"],
            correctIndex: 1,
            explanation: "Standard pianos have 88 keys spanning seven octaves plus a minor third."
        ),
        BrainBrawlQuestion(
            category: .arts,
            text: "What literary device compares two things using 'like' or 'as'?",
            choices: ["Metaphor", "Simile", "Hyperbole", "Irony"],
            correctIndex: 1,
            explanation: "A simile uses like/as; a metaphor states direct comparison."
        ),
        BrainBrawlQuestion(
            category: .arts,
            text: "Who composed the Four Seasons?",
            choices: ["Bach", "Mozart", "Vivaldi", "Beethoven"],
            correctIndex: 2,
            explanation: "Antonio Vivaldi wrote the violin concertos circa 1720."
        ),
        BrainBrawlQuestion(
            category: .arts,
            text: "The Starry Night was painted by which artist?",
            choices: ["Van Gogh", "Monet", "Picasso", "Dali"],
            correctIndex: 0,
            explanation: "Van Gogh painted it in 1889 while at an asylum in France."
        ),
        BrainBrawlQuestion(
            category: .arts,
            text: "How many lines does a sonnet traditionally have?",
            choices: ["12", "14", "16", "18"],
            correctIndex: 1,
            explanation: "A Shakespearean sonnet has 14 lines in iambic pentameter."
        ),
        BrainBrawlQuestion(
            category: .arts,
            text: "Which dance originated in Argentina?",
            choices: ["Salsa", "Tango", "Flamenco", "Samba"],
            correctIndex: 1,
            explanation: "The tango emerged in Buenos Aires in the late 19th century."
        )
    ]
}
