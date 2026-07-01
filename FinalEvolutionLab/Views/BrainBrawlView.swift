import SwiftUI

// MARK: - Category

private enum BBCategory: String, CaseIterable, Identifiable {
    case sports        = "Sports"
    case science       = "Science"
    case entertainment = "Entertainment"
    case history       = "History"
    case geography     = "Geography"
    case stem          = "STEM"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .sports:        return Color(red: 1.0, green: 0.50, blue: 0.00)
        case .science:       return Color(red: 0.1, green: 0.70, blue: 1.00)
        case .entertainment: return Color(red: 0.8, green: 0.20, blue: 0.90)
        case .history:       return Color(red: 0.85, green: 0.65, blue: 0.20)
        case .geography:     return Color(red: 0.2, green: 0.78, blue: 0.40)
        case .stem:          return Color(red: 0.0, green: 0.90, blue: 0.85)
        }
    }

    var icon: String {
        switch self {
        case .sports:        return "figure.basketball"
        case .science:       return "atom"
        case .entertainment: return "film.fill"
        case .history:       return "books.vertical.fill"
        case .geography:     return "globe.americas.fill"
        case .stem:          return "function"
        }
    }

    var aiAccuracy: Double {
        switch self {
        case .sports:        return 0.55
        case .science:       return 0.65
        case .entertainment: return 0.60
        case .history:       return 0.60
        case .geography:     return 0.65
        case .stem:          return 0.70
        }
    }

    var subjectLine: String {
        switch self {
        case .sports:        return "Training · Kinesiology · Athletic IQ"
        case .science:       return "Biology · Physics · Chemistry"
        case .entertainment: return "Film · Music · Culture"
        case .history:       return "World History · Social Studies"
        case .geography:     return "Countries · Cities · Maps"
        case .stem:          return "Math · Coding · Engineering"
        }
    }
}

// MARK: - Question

private struct BBQuestion {
    let category: BBCategory
    let question: String
    let answers: [String]
    let correctIndex: Int
}

// MARK: - Phase

private enum BBPhase {
    case ready, spinning, question, feedback, opponentTurn, result
}

// MARK: - Question Bank

private enum BBBank {
    static let all: [BBCategory: [BBQuestion]] = [
        .sports: [
            BBQuestion(category: .sports,
                       question: "Which muscle group primarily drives a standing vertical jump?",
                       answers: ["Hip Flexors", "Hamstrings", "Glutes & Quads", "Calves"], correctIndex: 2),
            BBQuestion(category: .sports,
                       question: "The NBA shot clock is how many seconds?",
                       answers: ["30", "24", "20", "28"], correctIndex: 1),
            BBQuestion(category: .sports,
                       question: "PRQ stands for:",
                       answers: ["Physical Readiness Quotient", "Power Response Quality", "Peak Range Qualifier", "Performance Reaction Quotient"], correctIndex: 0),
            BBQuestion(category: .sports,
                       question: "High HRV generally signals:",
                       answers: ["High fatigue", "High readiness", "Low heart rate", "Injury risk"], correctIndex: 1),
            BBQuestion(category: .sports,
                       question: "The stretch-shortening cycle (SSC) primarily explains:",
                       answers: ["Hypertrophy", "Plyometric power", "Aerobic endurance", "Flexibility"], correctIndex: 1),
            BBQuestion(category: .sports,
                       question: "Which periodization model varies intensity and volume daily?",
                       answers: ["Linear", "Undulating", "Block", "Conjugate"], correctIndex: 1),
            BBQuestion(category: .sports,
                       question: "A regulation NBA hoop is how high from the floor?",
                       answers: ["9 feet", "10 feet", "10.5 feet", "11 feet"], correctIndex: 1),
            BBQuestion(category: .sports,
                       question: "Phosphocreatine (PCr) system fuels explosive efforts up to:",
                       answers: ["30 seconds", "10 seconds", "2 minutes", "5 minutes"], correctIndex: 1),
            BBQuestion(category: .sports,
                       question: "Eccentric overload training primarily develops:",
                       answers: ["Cardiovascular capacity", "Tendon stiffness & strength", "Flexibility", "Reaction time"], correctIndex: 1),
            BBQuestion(category: .sports,
                       question: "RPE stands for:",
                       answers: ["Rate of Perceived Exertion", "Reactive Power Evaluation", "Resting Phase Estimate", "Rhythmic Performance Effort"], correctIndex: 0),
        ],
        .science: [
            BBQuestion(category: .science,
                       question: "The powerhouse of the cell is the:",
                       answers: ["Nucleus", "Ribosome", "Mitochondria", "Golgi Apparatus"], correctIndex: 2),
            BBQuestion(category: .science,
                       question: "ATP stands for:",
                       answers: ["Adenosine Triphosphate", "Adenine Tri-Peptide", "Arterial Transport Protein", "Active Transfer Point"], correctIndex: 0),
            BBQuestion(category: .science,
                       question: "Newton's second law — Force equals:",
                       answers: ["Mass × Velocity", "Mass × Acceleration", "Weight × Distance", "Energy / Time"], correctIndex: 1),
            BBQuestion(category: .science,
                       question: "Type II muscle fibers are best described as:",
                       answers: ["Slow-twitch, fatigue-resistant", "Fast-twitch, high power", "Aerobic, high endurance", "Oxidative, low force"], correctIndex: 1),
            BBQuestion(category: .science,
                       question: "The neurotransmitter at the neuromuscular junction is:",
                       answers: ["Dopamine", "Serotonin", "Acetylcholine", "GABA"], correctIndex: 2),
            BBQuestion(category: .science,
                       question: "Which organ produces insulin?",
                       answers: ["Liver", "Pancreas", "Kidney", "Adrenal Gland"], correctIndex: 1),
            BBQuestion(category: .science,
                       question: "The SI unit of power is the:",
                       answers: ["Joule", "Newton", "Watt", "Pascal"], correctIndex: 2),
            BBQuestion(category: .science,
                       question: "DNA's sugar component is:",
                       answers: ["Ribose", "Deoxyribose", "Glucose", "Fructose"], correctIndex: 1),
            BBQuestion(category: .science,
                       question: "Which energy system fuels efforts lasting 30 seconds to 2 minutes?",
                       answers: ["Oxidative", "Glycolytic", "Phosphocreatine", "Lactic acid only"], correctIndex: 1),
            BBQuestion(category: .science,
                       question: "The spine has how many vertebrae in an adult?",
                       answers: ["26", "30", "33", "24"], correctIndex: 2),
        ],
        .entertainment: [
            BBQuestion(category: .entertainment,
                       question: "Space Jam (1996) starred which NBA legend?",
                       answers: ["Kobe Bryant", "LeBron James", "Michael Jordan", "Charles Barkley"], correctIndex: 2),
            BBQuestion(category: .entertainment,
                       question: "'Be like water' is attributed to:",
                       answers: ["Jackie Chan", "Jet Li", "Bruce Lee", "Chuck Norris"], correctIndex: 2),
            BBQuestion(category: .entertainment,
                       question: "The '97–98 Bulls documentary is called:",
                       answers: ["Basketball Empire", "The Last Dance", "Championship Run", "Bulls Dynasty"], correctIndex: 1),
            BBQuestion(category: .entertainment,
                       question: "IMDb stands for:",
                       answers: ["International Movie Database", "Internet Movie Database", "Indexed Media Base", "Integrated Media Directory"], correctIndex: 1),
            BBQuestion(category: .entertainment,
                       question: "'Above the Rim' (1994) starred:",
                       answers: ["Ice Cube", "Tupac Shakur", "Snoop Dogg", "DMX"], correctIndex: 1),
            BBQuestion(category: .entertainment,
                       question: "Which platform pioneered short-form vertical video?",
                       answers: ["YouTube", "Instagram", "TikTok", "Snapchat"], correctIndex: 2),
            BBQuestion(category: .entertainment,
                       question: "Creed (2015) is a sequel to which franchise?",
                       answers: ["Ali", "Rocky", "Southpaw", "Champion"], correctIndex: 1),
            BBQuestion(category: .entertainment,
                       question: "Which streamer hosts the most live sports content globally?",
                       answers: ["Netflix", "Hulu", "Amazon Prime Video", "ESPN+"], correctIndex: 3),
            BBQuestion(category: .entertainment,
                       question: "Grammy Awards honor achievement in:",
                       answers: ["Film", "Television", "Music", "Theatre"], correctIndex: 2),
            BBQuestion(category: .entertainment,
                       question: "Masterclass is known for courses taught by:",
                       answers: ["University professors", "World-class experts", "AI tutors", "High school teachers"], correctIndex: 1),
        ],
        .history: [
            BBQuestion(category: .history,
                       question: "James Naismith invented basketball in:",
                       answers: ["1885", "1891", "1899", "1905"], correctIndex: 1),
            BBQuestion(category: .history,
                       question: "The original Olympic Games were held in:",
                       answers: ["Athens", "Olympia", "Sparta", "Corinth"], correctIndex: 1),
            BBQuestion(category: .history,
                       question: "Title IX (1972) prohibited:",
                       answers: ["Drug use in sports", "Sex discrimination in funded programs", "Olympic professionalism", "College recruitment violations"], correctIndex: 1),
            BBQuestion(category: .history,
                       question: "The ABA merged with the NBA in:",
                       answers: ["1972", "1976", "1980", "1984"], correctIndex: 1),
            BBQuestion(category: .history,
                       question: "The Civil Rights Act was passed in:",
                       answers: ["1954", "1960", "1964", "1968"], correctIndex: 2),
            BBQuestion(category: .history,
                       question: "The first modern Olympic Games were held in:",
                       answers: ["1888", "1896", "1900", "1904"], correctIndex: 1),
            BBQuestion(category: .history,
                       question: "The Berlin Wall fell in:",
                       answers: ["1987", "1989", "1991", "1993"], correctIndex: 1),
            BBQuestion(category: .history,
                       question: "The Harlem Renaissance primarily took place in:",
                       answers: ["1880s–1900s", "1900s–1910s", "1920s–1930s", "1940s–1950s"], correctIndex: 2),
            BBQuestion(category: .history,
                       question: "Muhammad Ali refused induction into the US Army in:",
                       answers: ["1963", "1967", "1970", "1973"], correctIndex: 1),
            BBQuestion(category: .history,
                       question: "Jesse Owens won how many gold medals at the 1936 Berlin Olympics?",
                       answers: ["2", "3", "4", "5"], correctIndex: 2),
        ],
        .geography: [
            BBQuestion(category: .geography,
                       question: "Venice Beach is in which US city?",
                       answers: ["San Francisco", "Los Angeles", "San Diego", "Santa Monica"], correctIndex: 1),
            BBQuestion(category: .geography,
                       question: "Which continent has the most countries?",
                       answers: ["Asia", "Europe", "Africa", "South America"], correctIndex: 2),
            BBQuestion(category: .geography,
                       question: "The Amazon River primarily flows through:",
                       answers: ["Colombia", "Peru", "Brazil", "Venezuela"], correctIndex: 2),
            BBQuestion(category: .geography,
                       question: "The capital of Canada is:",
                       answers: ["Toronto", "Vancouver", "Montreal", "Ottawa"], correctIndex: 3),
            BBQuestion(category: .geography,
                       question: "Which US state has the most NBA franchise cities?",
                       answers: ["New York", "Texas", "California", "Florida"], correctIndex: 2),
            BBQuestion(category: .geography,
                       question: "The Nile River flows which direction?",
                       answers: ["South to North", "North to South", "East to West", "West to East"], correctIndex: 0),
            BBQuestion(category: .geography,
                       question: "The Ural Mountains separate:",
                       answers: ["Asia / Africa", "Europe / Asia", "Asia / Australia", "Europe / Africa"], correctIndex: 1),
            BBQuestion(category: .geography,
                       question: "Which ocean is the largest?",
                       answers: ["Atlantic", "Indian", "Arctic", "Pacific"], correctIndex: 3),
            BBQuestion(category: .geography,
                       question: "Compton, CA is in which county?",
                       answers: ["Orange County", "San Bernardino County", "Los Angeles County", "Riverside County"], correctIndex: 2),
            BBQuestion(category: .geography,
                       question: "The equator passes through how many continents?",
                       answers: ["2", "3", "4", "5"], correctIndex: 1),
        ],
        .stem: [
            BBQuestion(category: .stem,
                       question: "An algorithm is best defined as:",
                       answers: ["A data structure", "A step-by-step problem-solving procedure", "A programming language", "A network protocol"], correctIndex: 1),
            BBQuestion(category: .stem,
                       question: "The derivative of position with respect to time is:",
                       answers: ["Acceleration", "Force", "Velocity", "Momentum"], correctIndex: 2),
            BBQuestion(category: .stem,
                       question: "A standard deviation of 0 means:",
                       answers: ["Maximum spread", "No data", "All values are equal", "Normal distribution"], correctIndex: 2),
            BBQuestion(category: .stem,
                       question: "Biomechanics is the study of:",
                       answers: ["Animal behavior", "Mechanical laws applied to living organisms", "Brain chemistry", "Genetic mutations"], correctIndex: 1),
            BBQuestion(category: .stem,
                       question: "v² = u² + 2as solves for:",
                       answers: ["Time", "Final velocity squared", "Displacement only", "Force"], correctIndex: 1),
            BBQuestion(category: .stem,
                       question: "'if-else' in programming represents:",
                       answers: ["Loops", "Conditional logic", "Data types", "Functions"], correctIndex: 1),
            BBQuestion(category: .stem,
                       question: "The center of mass is also called:",
                       answers: ["Centroid", "Fulcrum", "Center of gravity", "Pivot point"], correctIndex: 2),
            BBQuestion(category: .stem,
                       question: "Ground reaction force (GRF) is measured in:",
                       answers: ["Joules", "Newtons", "Watts", "Pascals"], correctIndex: 1),
            BBQuestion(category: .stem,
                       question: "The Pythagorean theorem applies to which triangles?",
                       answers: ["Equilateral", "Isosceles", "Right-angled", "Obtuse"], correctIndex: 2),
            BBQuestion(category: .stem,
                       question: "Machine learning is a subset of:",
                       answers: ["Robotics", "Statistics", "Artificial Intelligence", "Computer Networks"], correctIndex: 2),
        ],
    ]
}

// MARK: - Wheel Shape

private struct WedgeShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        p.move(to: center)
        p.addArc(center: center, radius: radius,
                 startAngle: .degrees(startAngle),
                 endAngle: .degrees(endAngle), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct PointerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Brain Brawl Canvas FX

private struct SpinFXCanvas: View {
    let spinning: Bool

    var body: some View {
        TimelineView(.animation(paused: !spinning)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                guard spinning else { return }
                let cx = size.width / 2
                let cy = size.height / 2
                let R: CGFloat = 110

                var rimGC = ctx
                rimGC.addFilter(.blur(radius: 14))
                rimGC.stroke(Path(ellipseIn: CGRect(x: cx-R, y: cy-R, width: R*2, height: R*2)),
                             with: .color(Color.white.opacity(0.55)), lineWidth: 8)

                for i in 0..<14 {
                    let phase = Double(i) / 14.0
                    let pT = fmod(t * 2.8 + phase, 1.0)
                    let angle = phase * .pi * 2.0 + t * 8.0
                    let dist = R + CGFloat(pT) * R * 0.72
                    let px = cx + CGFloat(cos(angle)) * dist
                    let py = cy + CGFloat(sin(angle)) * dist
                    var sparkGC = ctx
                    sparkGC.addFilter(.blur(radius: 2.5))
                    sparkGC.fill(Path(ellipseIn: CGRect(x: px-3.5, y: py-3.5, width: 7, height: 7)),
                                 with: .color(Color.white.opacity((1.0 - pT) * 0.85)))
                }
            }
        }
    }
}

private struct NeuralBGCanvas: View {
    let catColor: Color

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width; let H = size.height
                let nx: [CGFloat] = [0.12, 0.85, 0.55, 0.28, 0.72, 0.10, 0.60, 0.90]
                let ny: [CGFloat] = [0.12, 0.09, 0.22, 0.52, 0.44, 0.76, 0.68, 0.82]
                let nPhase: [Double] = [0.0, 0.5, 1.1, 0.3, 1.8, 2.2, 0.7, 1.5]
                let nSpeed: [Double] = [1.2, 0.9, 1.4, 0.8, 1.1, 1.3, 0.7, 1.0]
                let edges: [(Int, Int)] = [(0,2),(2,1),(2,4),(3,0),(3,6),(4,7),(5,6),(5,3),(1,4),(6,7)]

                var positions = [CGPoint](repeating: .zero, count: 8)
                for i in 0..<8 {
                    let dx = CGFloat(sin(t * nSpeed[i] + nPhase[i])) * W * 0.012
                    let dy = CGFloat(cos(t * nSpeed[i] * 0.7 + nPhase[i])) * H * 0.012
                    positions[i] = CGPoint(x: nx[i] * W + dx, y: ny[i] * H + dy)
                }

                for (a, b) in edges {
                    var line = Path()
                    line.move(to: positions[a])
                    line.addLine(to: positions[b])
                    ctx.stroke(line, with: .color(catColor.opacity(0.07)), lineWidth: 1)
                }

                for i in 0..<8 {
                    let pulse = CGFloat(0.5 + sin(t * nSpeed[i] + nPhase[i]) * 0.5)
                    let pos = positions[i]
                    let r = 2.5 + pulse * 2.5
                    var glowGC = ctx
                    glowGC.addFilter(.blur(radius: 5))
                    glowGC.fill(Path(ellipseIn: CGRect(x: pos.x-r*2, y: pos.y-r*2, width: r*4, height: r*4)),
                                with: .color(catColor.opacity(Double(pulse) * 0.18)))
                    ctx.fill(Path(ellipseIn: CGRect(x: pos.x-r*0.6, y: pos.y-r*0.6, width: r*1.2, height: r*1.2)),
                             with: .color(catColor.opacity(Double(pulse) * 0.45)))
                }
            }
        }
    }
}

private struct AIThinkCanvas: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2

                for i in 0..<3 {
                    let phase = Double(i) / 3.0
                    let pulse = fmod(t * 0.75 + phase, 1.0)
                    let r = 20 + CGFloat(pulse) * 68
                    let alpha = (1.0 - pulse) * 0.55
                    var glowGC = ctx
                    glowGC.addFilter(.blur(radius: 8))
                    let ring = Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
                    glowGC.stroke(ring, with: .color(Color.red.opacity(alpha * 0.8)), lineWidth: 4)
                    ctx.stroke(ring, with: .color(Color.red.opacity(alpha * 0.3)), lineWidth: 1)
                }

                for i in 0..<6 {
                    let orbit: CGFloat = i < 3 ? 42 : 66
                    let speed = i < 3 ? 1.4 : -1.0
                    let angle = t * speed + Double(i % 3) * .pi * 2.0 / 3.0
                    let px = cx + CGFloat(cos(angle)) * orbit
                    let py = cy + CGFloat(sin(angle)) * orbit
                    var pktGC = ctx
                    pktGC.addFilter(.blur(radius: 3))
                    pktGC.fill(Path(ellipseIn: CGRect(x: px-5, y: py-5, width: 10, height: 10)),
                               with: .color(Color.red.opacity(0.65)))
                    ctx.fill(Path(ellipseIn: CGRect(x: px-2, y: py-2, width: 4, height: 4)),
                             with: .color(Color.white.opacity(0.9)))
                }

                var coreGC = ctx
                coreGC.addFilter(.blur(radius: 16))
                let coreR = 16 + CGFloat(sin(t * 3.5)) * 4
                coreGC.fill(Path(ellipseIn: CGRect(x: cx-coreR, y: cy-coreR, width: coreR*2, height: coreR*2)),
                            with: .color(Color.red.opacity(0.55)))
                ctx.fill(Path(ellipseIn: CGRect(x: cx-8, y: cy-8, width: 16, height: 16)),
                         with: .color(Color.red.opacity(0.9)))
            }
        }
    }
}

// MARK: - Main View

struct BrainBrawlView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    @State private var phase: BBPhase = .ready
    @State private var playerCrowns: Set<BBCategory> = []
    @State private var opponentCrowns: Set<BBCategory> = []
    @State private var spinDegrees: Double = 0
    @State private var selectedCategory: BBCategory = .sports
    @State private var usedIndices: [BBCategory: Set<Int>] = [:]
    @State private var currentQuestion: BBQuestion? = nil
    @State private var timeLeft: Int = 15
    @State private var selectedAnswer: Int? = nil
    @State private var isCorrect: Bool? = nil
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var isPlayerTurn: Bool = true
    @State private var feedbackMessage: String = ""
    @State private var opponentLabel: String = ""
    @State private var crownFlash: BBCategory? = nil
    @State private var spinning: Bool = false

    private let opponentName = "Kai Nexus"
    private let totalCrowns = BBCategory.allCases.count

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.02, blue: 0.14), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Brain Brawl",
                    subtitle: "6 categories · Collect all crowns · Winner takes all",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { phase = .spinning }
                )
            case .spinning:
                spinningBody
            case .question:
                questionBody
            case .feedback:
                feedbackBody
            case .opponentTurn:
                opponentTurnBody
            case .result:
                ResultScreen(
                    winner: playerCrowns.count == totalCrowns ? .p1 : .p2,
                    p1Score: playerCrowns.count * 10,
                    p2Score: opponentCrowns.count * 10,
                    title: "Brain Brawl",
                    accentColor: gameMode.accentColor,
                    prqGain: playerCrowns.count == totalCrowns ? 15 : 3,
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: "IQ",
                    modeAttributeValue: Double(playerCrowns.count) / Double(totalCrowns),
                    onReturn: { dismiss() }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { timerTask?.cancel(); dismiss() } label: {
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

    // MARK: - Crown Bar

    private var crownBar: some View {
        HStack(spacing: 0) {
            crownRow(crowns: playerCrowns, label: "YOU", alignment: .leading)
            Spacer()
            crownRow(crowns: opponentCrowns, label: opponentName.uppercased(), alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func crownRow(crowns: Set<BBCategory>, label: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
            HStack(spacing: 4) {
                ForEach(BBCategory.allCases) { cat in
                    let owned = crowns.contains(cat)
                    ZStack {
                        Circle()
                            .fill(owned ? cat.color : Color.white.opacity(0.06))
                            .frame(width: 26, height: 26)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(owned ? .black : Color.white.opacity(0.15))
                    }
                    .scaleEffect(crownFlash == cat && owned ? 1.5 : 1.0)
                    .animation(.spring(response: 0.25), value: crownFlash)
                }
            }
        }
    }

    // MARK: - Spinning

    private var spinningBody: some View {
        VStack(spacing: 0) {
            crownBar
            Spacer()

            Text(isPlayerTurn ? "YOUR TURN — SPIN" : "\(opponentName.uppercased())'S TURN")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(isPlayerTurn ? gameMode.accentColor : .red)
                .tracking(3)
                .padding(.bottom, 20)

            ZStack {
                // Wheel wedges
                ForEach(Array(BBCategory.allCases.enumerated()), id: \.element.id) { i, cat in
                    let slice = 360.0 / Double(BBCategory.allCases.count)
                    WedgeShape(startAngle: slice * Double(i) - 90, endAngle: slice * Double(i + 1) - 90)
                        .fill(cat.color.opacity(0.85))
                }
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(spinDegrees))
                .animation(.easeOut(duration: 2.2), value: spinDegrees)

                // Category icons on wheel
                ForEach(Array(BBCategory.allCases.enumerated()), id: \.element.id) { i, cat in
                    let slice = 360.0 / Double(BBCategory.allCases.count)
                    let mid = (slice * Double(i) + slice / 2 - 90 + spinDegrees) * .pi / 180
                    Image(systemName: cat.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .offset(x: cos(mid) * 72, y: sin(mid) * 72)
                }
                .animation(.easeOut(duration: 2.2), value: spinDegrees)

                // Center hub
                Circle().fill(Theme.deepBlack).frame(width: 52, height: 52)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(gameMode.accentColor)

                // Top pointer
                VStack(spacing: 0) {
                    PointerTriangle()
                        .fill(Color.white)
                        .frame(width: 14, height: 16)
                    Spacer()
                }
                .frame(height: 124)
            }
            .frame(width: 220, height: 240)
            .overlay(
                SpinFXCanvas(spinning: spinning)
                    .frame(width: 280, height: 280)
                    .allowsHitTesting(false)
            )

            Spacer().frame(height: 36)

            if isPlayerTurn {
                Button {
                    guard !spinning else { return }
                    spinning = true
                    spinWheel()
                } label: {
                    Text("SPIN")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(spinning ? Color.white.opacity(0.3) : gameMode.accentColor)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .disabled(spinning)
            } else {
                Text("Spinning for \(opponentName)…")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Question

    private var questionBody: some View {
        VStack(spacing: 0) {
            crownBar
            Spacer()

            if let q = currentQuestion {
                VStack(spacing: 20) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(selectedCategory.color.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedCategory.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(selectedCategory.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedCategory.rawValue.uppercased())
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(selectedCategory.color)
                                .tracking(2)
                            Text(selectedCategory.subjectLine)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(timeLeft > 7 ? selectedCategory.color : .red, lineWidth: 2.5)
                                .frame(width: 38, height: 38)
                            Text("\(timeLeft)")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(timeLeft > 7 ? .white : .red)
                                .contentTransition(.numericText())
                        }
                    }
                    .padding(.horizontal, 24)

                    Text(q.question)
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(q.answers.indices, id: \.self) { i in
                            answerButton(index: i, text: q.answers[i], question: q)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer()
        }
        .background(
            NeuralBGCanvas(catColor: selectedCategory.color)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
    }

    private func answerButton(index: Int, text: String, question: BBQuestion) -> some View {
        let isSelected = selectedAnswer == index
        let accent = selectedCategory.color
        return Button {
            guard selectedAnswer == nil else { return }
            selectAnswer(index, for: question)
        } label: {
            HStack(spacing: 14) {
                Text(["A", "B", "C", "D"][index])
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(isSelected ? .black : accent)
                    .frame(width: 28, height: 28)
                    .background(isSelected ? accent : accent.opacity(0.12))
                    .clipShape(Circle())

                Text(text)
                    .font(.system(.subheadline, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accent.opacity(0.1) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? accent.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedAnswer != nil)
    }

    // MARK: - Feedback

    private var feedbackBody: some View {
        VStack(spacing: 24) {
            Spacer()
            crownBar
            Spacer()

            ZStack {
                Circle()
                    .fill((isCorrect == true ? Color.green : Color.red).opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: isCorrect == true ? "crown.fill" : "xmark.circle.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(isCorrect == true ? .yellow : .red)
            }

            Text(feedbackMessage)
                .font(.system(.title2, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if isCorrect == true {
                HStack(spacing: 8) {
                    Image(systemName: selectedCategory.icon)
                        .foregroundStyle(selectedCategory.color)
                    Text("\(selectedCategory.rawValue) crown earned!")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(selectedCategory.color)
                }
            }

            Spacer()
        }
    }

    // MARK: - Opponent Turn

    private var opponentTurnBody: some View {
        VStack(spacing: 20) {
            Spacer()
            crownBar
            Spacer()

            AIThinkCanvas()
                .frame(width: 160, height: 160)

            Text(opponentLabel)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("\(opponentName.uppercased()) IS ANSWERING")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)

            Spacer()
        }
    }

    // MARK: - Logic

    private func spinWheel() {
        let extra = Double.random(in: 720...1440)
        spinDegrees += extra

        // Determine which category the pointer lands on after spin
        let normalised = spinDegrees.truncatingRemainder(dividingBy: 360)
        let slice = 360.0 / Double(BBCategory.allCases.count)
        // Pointer is at top (0°). Wheel rotates clockwise (positive degrees).
        // The category at the top after rotation: (360 - normalised) / slice
        let idx = Int((360 - normalised) / slice) % BBCategory.allCases.count
        selectedCategory = BBCategory.allCases[max(0, min(idx, BBCategory.allCases.count - 1))]

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                spinning = false
                loadQuestion()
            }
        }
    }

    private func loadQuestion() {
        let pool = BBBank.all[selectedCategory] ?? []
        guard !pool.isEmpty else { return }
        var used = usedIndices[selectedCategory] ?? []
        let available = pool.indices.filter { !used.contains($0) }
        let idx: Int
        if let pick = available.randomElement() {
            idx = pick
        } else {
            used = []
            idx = pool.indices.randomElement() ?? 0
        }
        used.insert(idx)
        usedIndices[selectedCategory] = used
        currentQuestion = pool[idx]
        selectedAnswer = nil
        isCorrect = nil
        timeLeft = 15
        phase = .question
        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while timeLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { timeLeft -= 1 }
            }
            await MainActor.run { timeExpired() }
        }
    }

    private func timeExpired() {
        timerTask?.cancel()
        isCorrect = false
        feedbackMessage = "Time's up!"
        phase = .feedback
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { beginOpponentTurn() }
        }
    }

    private func selectAnswer(_ index: Int, for question: BBQuestion) {
        timerTask?.cancel()
        selectedAnswer = index
        let correct = index == question.correctIndex
        UIImpactFeedbackGenerator(style: correct ? .heavy : .medium).impactOccurred()
        isCorrect = correct

        if correct {
            feedbackMessage = "Correct!"
            if !playerCrowns.contains(selectedCategory) {
                playerCrowns.insert(selectedCategory)
                crownFlash = selectedCategory
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await MainActor.run { crownFlash = nil }
                }
            }
        } else {
            feedbackMessage = "Wrong — "\(question.answers[question.correctIndex])""
        }

        phase = .feedback
        Task {
            try? await Task.sleep(for: .seconds(correct ? 1.8 : 2.0))
            await MainActor.run {
                if checkWin() { return }
                if correct { nextPlayerTurn() } else { beginOpponentTurn() }
            }
        }
    }

    private func beginOpponentTurn() {
        isPlayerTurn = false
        let cat = BBCategory.allCases.randomElement()!
        let pool = BBBank.all[cat] ?? []
        guard let q = pool.randomElement() else { nextPlayerTurn(); return }
        opponentLabel = "\(cat.rawValue): \"\(q.question)\""
        phase = .opponentTurn

        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.0...3.8)))
            await MainActor.run {
                let correct = Double.random(in: 0...1) < cat.aiAccuracy
                if correct && !opponentCrowns.contains(cat) {
                    opponentCrowns.insert(cat)
                    opponentLabel = "\(opponentName) answered correctly!"
                } else {
                    opponentLabel = "\(opponentName) missed it."
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.3))
                    await MainActor.run {
                        if checkWin() { return }
                        nextPlayerTurn()
                    }
                }
            }
        }
    }

    private func nextPlayerTurn() {
        isPlayerTurn = true
        spinning = false
        phase = .spinning
    }

    @discardableResult
    private func checkWin() -> Bool {
        if playerCrowns.count == totalCrowns || opponentCrowns.count == totalCrowns {
            phase = .result
            return true
        }
        return false
    }
}
