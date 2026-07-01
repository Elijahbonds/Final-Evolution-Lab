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

// MARK: - AI Personality

private enum AIPersonality: CaseIterable {
    case confident, nervous, taunting, scholarly

    var name: String {
        switch self {
        case .confident: return "Kai Nexus"
        case .nervous: return "Kai Nexus"
        case .taunting: return "Kai Nexus"
        case .scholarly: return "Kai Nexus"
        }
    }

    var thinkingLines: [String] {
        switch self {
        case .confident:
            return ["Processing...", "I know this.", "Simple.", "Calculated.", "Data confirmed."]
        case .nervous:
            return ["Hmm... let me think...", "I... think...", "Wait, no—", "Maybe...?", "Processing..."]
        case .taunting:
            return ["Too easy.", "Is that it?", "Let me not even try.", "Yawn.", "Obviously..."]
        case .scholarly:
            return ["Cross-referencing...", "Consulting index...", "Verifying hypothesis...", "Analyzing data...", "Computing..."]
        }
    }

    var correctLines: [String] {
        switch self {
        case .confident:
            return ["Knew it.", "Of course.", "Never in doubt.", "That's my speed.", "Crown acquired."]
        case .nervous:
            return ["Oh! I got it!", "Wait — really?!", "Yes! Finally!", "That... worked?", "Lucky guess!"]
        case .taunting:
            return ["Is that your final answer? Really?", "Too slow.", "Study harder.", "I was barely trying.", "Child's play."]
        case .scholarly:
            return ["Hypothesis confirmed.", "Literature supports this.", "Textbook correct.", "Academically sound.", "Peer-reviewed answer."]
        }
    }

    var incorrectLines: [String] {
        switch self {
        case .confident:
            return ["Minor error.", "Recalibrating.", "That was... a test.", "Acceptable margin.", "Noted."]
        case .nervous:
            return ["I knew I was wrong!", "See? I knew it.", "Ugh, why do I always—", "This is not good.", "Panic mode activated."]
        case .taunting:
            return ["That question was unfair.", "Irrelevant trivia.", "I don't care about that.", "Technicality.", "The phrasing was bad."]
        case .scholarly:
            return ["Insufficient data.", "Requires further analysis.", "Conflicting sources.", "Margin of error.", "Re-reviewing literature."]
        }
    }

    var thinkDelay: ClosedRange<Double> {
        switch self {
        case .confident: return 1.0...2.2
        case .nervous: return 3.0...4.5
        case .taunting: return 0.8...1.6
        case .scholarly: return 2.8...4.0
        }
    }

    var accuracyModifier: Double {
        switch self {
        case .confident: return 0.05
        case .nervous: return -0.10
        case .taunting: return 0.0
        case .scholarly: return 0.08
        }
    }

    var thinkingColor: Color {
        switch self {
        case .confident: return Color(red: 0.2, green: 0.8, blue: 1.0)
        case .nervous: return Color(red: 0.9, green: 0.7, blue: 0.1)
        case .taunting: return Color(red: 1.0, green: 0.2, blue: 0.3)
        case .scholarly: return Color(red: 0.5, green: 0.9, blue: 0.5)
        }
    }
}

// MARK: - Lifeline

private enum BBLifeline: CaseIterable {
    case fiftyFifty, phoneAFan, extraTime

    var label: String {
        switch self {
        case .fiftyFifty:  return "50/50"
        case .phoneAFan:   return "FAN"
        case .extraTime:   return "+8s"
        }
    }

    var icon: String {
        switch self {
        case .fiftyFifty: return "scissors"
        case .phoneAFan:  return "person.wave.2.fill"
        case .extraTime:  return "clock.badge.plus"
        }
    }
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

// MARK: - SpinFXCanvas (AAA Enhanced)

private struct SpinFXCanvas: View {
    let spinning: Bool
    let selectedCatColor: Color
    let streakCount: Int

    var body: some View {
        TimelineView(.animation(paused: !spinning)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                guard spinning else { return }
                let cx = size.width / 2
                let cy = size.height / 2
                let rimR: CGFloat = 110
                let maxR: CGFloat = 148

                // --- Original pulsing rim glow ---
                var rimGC = ctx
                rimGC.addFilter(.blur(radius: 14))
                rimGC.stroke(Path(ellipseIn: CGRect(x: cx-rimR, y: cy-rimR, width: rimR*2, height: rimR*2)),
                             with: .color(Color.white.opacity(0.55)), lineWidth: 8)

                // --- Power core: 3 concentric layered glow rings ---
                let coreR: CGFloat = 18 + CGFloat(sin(t * 4.2)) * 4
                let corePulse = CGFloat((sin(t * 3.0) + 1) / 2)
                let coreRings: [(CGFloat, CGFloat, CGFloat)] = [
                    (coreR * 2.8, 22, 0.18),
                    (coreR * 1.7, 14, 0.30),
                    (coreR * 1.0, 8,  0.55)
                ]
                for (r, blur, alpha) in coreRings {
                    var coreGC = ctx
                    coreGC.addFilter(.blur(radius: blur))
                    coreGC.fill(Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2)),
                                with: .color(selectedCatColor.opacity(Double(corePulse) * Double(alpha) + 0.08)))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: cy-5, width: 10, height: 10)),
                         with: .color(Color.white.opacity(0.95)))

                // --- Electric arc effects: 8 lightning bolts from rim outward ---
                let arcFrame = Int(t * 8)
                for i in 0..<8 {
                    let baseAngle = Double(i) * .pi / 4 + t * 5
                    let segments = 5
                    var arc = Path()
                    let seed1 = Double((i * 17 + arcFrame * 3) % 23) - 11.5
                    let seed2 = Double((i * 11 + arcFrame * 7) % 19) - 9.5
                    let seed3 = Double((i * 13 + arcFrame * 5) % 17) - 8.5
                    let seed4 = Double((i * 7  + arcFrame * 11) % 13) - 6.5
                    let seeds = [seed1, seed2, seed3, seed4, 0.0]
                    arc.move(to: CGPoint(x: cx + rimR * CGFloat(cos(baseAngle)),
                                        y: cy + rimR * CGFloat(sin(baseAngle))))
                    for s in 1...segments {
                        let r = rimR + CGFloat(s) * (maxR - rimR) / CGFloat(segments)
                        let jitter = seeds[min(s-1, seeds.count-1)]
                        let jAngle = baseAngle + jitter * 0.05
                        arc.addLine(to: CGPoint(x: cx + r * CGFloat(cos(jAngle)),
                                               y: cy + r * CGFloat(sin(jAngle))))
                    }
                    var arcGlowGC = ctx
                    arcGlowGC.addFilter(.blur(radius: 3))
                    arcGlowGC.stroke(arc, with: .color(Color.cyan.opacity(0.35)), lineWidth: 3)
                    ctx.stroke(arc, with: .color(Color.cyan.opacity(0.65)), lineWidth: 1.5)
                }

                // --- Spinning particle trail: 24 comet-tail particles ---
                for i in 0..<24 {
                    let phase = Double(i) / 24.0
                    let pT = fmod(t * 2.8 + phase, 1.0)
                    let orbitR = rimR * 0.92 + CGFloat(phase) * 14
                    let angle = phase * .pi * 2.0 + t * 8.0
                    let px = cx + CGFloat(cos(angle)) * orbitR
                    let py = cy + CGFloat(sin(angle)) * orbitR
                    let fadeAlpha = (1.0 - pT) * 0.78
                    let particleR: CGFloat = 2.5 + CGFloat(1.0 - pT) * 2.5
                    var sparkGC = ctx
                    sparkGC.addFilter(.blur(radius: 2.0))
                    sparkGC.fill(Path(ellipseIn: CGRect(x: px-particleR, y: py-particleR,
                                                        width: particleR*2, height: particleR*2)),
                                 with: .color(Color.white.opacity(fadeAlpha)))
                    ctx.fill(Path(ellipseIn: CGRect(x: px-1.2, y: py-1.2, width: 2.4, height: 2.4)),
                             with: .color(selectedCatColor.opacity(fadeAlpha * 0.9)))
                }

                // --- Rune symbols: 8 geometric glyphs rotating with wheel ---
                let runeR: CGFloat = rimR + 16
                for i in 0..<8 {
                    let rAngle = Double(i) * .pi / 4 + t * 1.8
                    let rx = cx + runeR * CGFloat(cos(rAngle))
                    let ry = cy + runeR * CGFloat(sin(rAngle))
                    let rs: CGFloat = 5
                    var runePath = Path()
                    switch i % 3 {
                    case 0:
                        runePath.move(to: CGPoint(x: rx,      y: ry - rs))
                        runePath.addLine(to: CGPoint(x: rx + rs, y: ry))
                        runePath.addLine(to: CGPoint(x: rx,      y: ry + rs))
                        runePath.addLine(to: CGPoint(x: rx - rs, y: ry))
                        runePath.closeSubpath()
                    case 1:
                        runePath.move(to: CGPoint(x: rx,              y: ry - rs))
                        runePath.addLine(to: CGPoint(x: rx + rs*0.87, y: ry + rs*0.5))
                        runePath.addLine(to: CGPoint(x: rx - rs*0.87, y: ry + rs*0.5))
                        runePath.closeSubpath()
                    default:
                        runePath.move(to: CGPoint(x: rx - rs, y: ry))
                        runePath.addLine(to: CGPoint(x: rx + rs, y: ry))
                        runePath.move(to: CGPoint(x: rx, y: ry - rs))
                        runePath.addLine(to: CGPoint(x: rx, y: ry + rs))
                    }
                    let runeAlpha = 0.5 + 0.3 * sin(t * 2.0 + Double(i) * 0.7)
                    var runeGlowGC = ctx
                    runeGlowGC.addFilter(.blur(radius: 3))
                    runeGlowGC.stroke(runePath, with: .color(selectedCatColor.opacity(runeAlpha * 0.5)), lineWidth: 2)
                    ctx.stroke(runePath, with: .color(Color.white.opacity(runeAlpha)), lineWidth: 1)
                }

                // --- Category icon symbols drawn as canvas shapes ---
                // Ball (sports) — circle with seam lines
                let iconR: CGFloat = maxR + 20
                let catIconAngle = t * 0.5
                let ballX = cx + iconR * CGFloat(cos(catIconAngle))
                let ballY = cy + iconR * CGFloat(sin(catIconAngle))
                let ballS: CGFloat = 9
                ctx.stroke(Path(ellipseIn: CGRect(x: ballX-ballS, y: ballY-ballS, width: ballS*2, height: ballS*2)),
                           with: .color(Color.orange.opacity(0.6)), lineWidth: 1.5)
                var seamH = Path()
                seamH.move(to: CGPoint(x: ballX - ballS, y: ballY))
                seamH.addLine(to: CGPoint(x: ballX + ballS, y: ballY))
                ctx.stroke(seamH, with: .color(Color.orange.opacity(0.4)), lineWidth: 0.8)
                var seamV = Path()
                seamV.move(to: CGPoint(x: ballX, y: ballY - ballS))
                seamV.addLine(to: CGPoint(x: ballX, y: ballY + ballS))
                ctx.stroke(seamV, with: .color(Color.orange.opacity(0.4)), lineWidth: 0.8)

                // Brain (science) — two oval lobes
                let brainAngle = catIconAngle + .pi * 0.5
                let brainX = cx + iconR * CGFloat(cos(brainAngle))
                let brainY = cy + iconR * CGFloat(sin(brainAngle))
                let bS: CGFloat = 8
                ctx.stroke(Path(ellipseIn: CGRect(x: brainX - bS*1.2, y: brainY - bS*0.7, width: bS*1.1, height: bS*1.4)),
                           with: .color(Color.cyan.opacity(0.55)), lineWidth: 1.2)
                ctx.stroke(Path(ellipseIn: CGRect(x: brainX + bS*0.1, y: brainY - bS*0.7, width: bS*1.1, height: bS*1.4)),
                           with: .color(Color.cyan.opacity(0.55)), lineWidth: 1.2)

                // Film strip (movies) — rectangle with tick marks
                let filmAngle = catIconAngle + .pi
                let filmX = cx + iconR * CGFloat(cos(filmAngle))
                let filmY = cy + iconR * CGFloat(sin(filmAngle))
                let fW: CGFloat = 14; let fH: CGFloat = 10
                ctx.stroke(Path(CGRect(x: filmX - fW/2, y: filmY - fH/2, width: fW, height: fH)),
                           with: .color(Color.purple.opacity(0.6)), lineWidth: 1.2)
                for fi in 0..<3 {
                    let fx = filmX - fW/2 + CGFloat(fi+1) * fW / 4
                    var tick = Path()
                    tick.move(to: CGPoint(x: fx, y: filmY - fH/2))
                    tick.addLine(to: CGPoint(x: fx, y: filmY - fH/2 + 2))
                    ctx.stroke(tick, with: .color(Color.purple.opacity(0.5)), lineWidth: 1)
                    var tick2 = Path()
                    tick2.move(to: CGPoint(x: fx, y: filmY + fH/2 - 2))
                    tick2.addLine(to: CGPoint(x: fx, y: filmY + fH/2))
                    ctx.stroke(tick2, with: .color(Color.purple.opacity(0.5)), lineWidth: 1)
                }

                // Music notes (entertainment) — note head + stem
                let musicAngle = catIconAngle + .pi * 1.5
                let musicX = cx + iconR * CGFloat(cos(musicAngle))
                let musicY = cy + iconR * CGFloat(sin(musicAngle))
                ctx.fill(Path(ellipseIn: CGRect(x: musicX - 5, y: musicY + 2, width: 7, height: 5)),
                         with: .color(Color.yellow.opacity(0.55)))
                var noteStem = Path()
                noteStem.move(to: CGPoint(x: musicX + 2, y: musicY + 4))
                noteStem.addLine(to: CGPoint(x: musicX + 2, y: musicY - 6))
                ctx.stroke(noteStem, with: .color(Color.yellow.opacity(0.55)), lineWidth: 1.2)
                ctx.fill(Path(ellipseIn: CGRect(x: musicX + 4, y: musicY - 1, width: 7, height: 5)),
                         with: .color(Color.yellow.opacity(0.45)))
                var noteStem2 = Path()
                noteStem2.move(to: CGPoint(x: musicX + 11, y: musicY + 1))
                noteStem2.addLine(to: CGPoint(x: musicX + 11, y: musicY - 9))
                ctx.stroke(noteStem2, with: .color(Color.yellow.opacity(0.45)), lineWidth: 1.2)

                // --- Trophy particle burst: 8 gold spinning triangles on streak >= 3 ---
                if streakCount >= 3 {
                    let trophyR: CGFloat = rimR * 0.65
                    for i in 0..<8 {
                        let triAngle = Double(i) * .pi / 4.0 + t * 2.5
                        let tx = cx + trophyR * CGFloat(cos(triAngle))
                        let ty = cy + trophyR * CGFloat(sin(triAngle))
                        let ts: CGFloat = 7
                        let spinA = t * 4.0 + Double(i) * .pi / 4.0
                        var tri = Path()
                        tri.move(to: CGPoint(
                            x: tx + ts * CGFloat(cos(spinA)),
                            y: ty + ts * CGFloat(sin(spinA))))
                        tri.addLine(to: CGPoint(
                            x: tx + ts * CGFloat(cos(spinA + .pi * 2.0/3.0)),
                            y: ty + ts * CGFloat(sin(spinA + .pi * 2.0/3.0))))
                        tri.addLine(to: CGPoint(
                            x: tx + ts * CGFloat(cos(spinA + .pi * 4.0/3.0)),
                            y: ty + ts * CGFloat(sin(spinA + .pi * 4.0/3.0))))
                        tri.closeSubpath()
                        let tAlpha = 0.5 + 0.4 * sin(t * 3.0 + Double(i))
                        var triGlowGC = ctx
                        triGlowGC.addFilter(.blur(radius: 4))
                        triGlowGC.fill(tri, with: .color(Color.yellow.opacity(tAlpha * 0.5)))
                        ctx.fill(tri, with: .color(Color(red: 1.0, green: 0.82, blue: 0.0).opacity(tAlpha)))
                    }
                }
            }
        }
    }
}

// MARK: - NeuralBGCanvas (AAA Enhanced)

private struct NeuralBGCanvas: View {
    let catColor: Color
    let isAnswering: Bool

    // 20 node positions (normalized 0..1)
    private let nx: [CGFloat] = [
        0.12, 0.85, 0.55, 0.28, 0.72, 0.10, 0.60, 0.90,
        0.38, 0.48, 0.20, 0.75, 0.33, 0.65, 0.82, 0.15,
        0.50, 0.92, 0.42, 0.70
    ]
    private let ny: [CGFloat] = [
        0.12, 0.09, 0.22, 0.52, 0.44, 0.76, 0.68, 0.82,
        0.18, 0.36, 0.62, 0.28, 0.74, 0.15, 0.56, 0.40,
        0.88, 0.48, 0.05, 0.92
    ]
    private let nPhase: [Double] = [
        0.0, 0.5, 1.1, 0.3, 1.8, 2.2, 0.7, 1.5,
        0.9, 1.3, 0.4, 2.0, 1.6, 0.2, 0.8, 1.9,
        0.6, 1.2, 2.4, 0.1
    ]
    private let nSpeed: [Double] = [
        1.2, 0.9, 1.4, 0.8, 1.1, 1.3, 0.7, 1.0,
        1.5, 0.6, 1.2, 0.95, 1.35, 0.75, 1.1, 0.85,
        1.25, 1.0, 0.65, 1.4
    ]
    private let nSizes: [CGFloat] = [
        3.5, 4.0, 3.0, 4.5, 3.2, 2.8, 4.2, 3.8,
        3.0, 5.0, 2.5, 4.0, 3.5, 3.0, 4.5, 2.8,
        3.8, 4.2, 2.5, 3.5
    ]
    // 30 edges among 20 nodes
    private let edges: [(Int, Int)] = [
        (0,2),(2,1),(2,4),(3,0),(3,6),(4,7),(5,6),(5,3),(1,4),(6,7),
        (8,0),(8,9),(9,3),(9,4),(10,5),(10,3),(11,4),(11,1),(12,6),(12,10),
        (13,1),(13,11),(14,7),(14,4),(15,10),(15,3),(16,12),(16,6),(17,14),(17,7)
    ]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width
                let H = size.height

                // --- Perspective grid background ---
                let vanishX = W * 0.5
                let vanishY = H * 0.35
                for g in 0..<10 {
                    let fx = W * CGFloat(g) / 9.0
                    var vLine = Path()
                    vLine.move(to: CGPoint(x: fx, y: H))
                    vLine.addLine(to: CGPoint(x: vanishX + (fx - vanishX) * 0.08, y: vanishY))
                    ctx.stroke(vLine, with: .color(catColor.opacity(0.04)), lineWidth: 0.8)
                }
                for g in 0..<10 {
                    let fy = vanishY + (H - vanishY) * CGFloat(g) / 9.0
                    var hLine = Path()
                    hLine.move(to: CGPoint(x: 0, y: fy))
                    hLine.addLine(to: CGPoint(x: W, y: fy))
                    ctx.stroke(hLine, with: .color(catColor.opacity(0.025)), lineWidth: 0.5)
                }

                // --- Compute animated node positions ---
                var positions = [CGPoint](repeating: .zero, count: 20)
                for i in 0..<20 {
                    let dx = CGFloat(sin(t * nSpeed[i] + nPhase[i])) * W * 0.010
                    let dy = CGFloat(cos(t * nSpeed[i] * 0.7 + nPhase[i])) * H * 0.010
                    positions[i] = CGPoint(x: nx[i] * W + dx, y: ny[i] * H + dy)
                }

                // Determine "active" node: closest to center of screen
                let centerPt = CGPoint(x: W * 0.5, y: H * 0.5)
                var activeNode = 0
                var minDist = CGFloat.greatestFiniteMagnitude
                for i in 0..<20 {
                    let d = hypot(positions[i].x - centerPt.x, positions[i].y - centerPt.y)
                    if d < minDist { minDist = d; activeNode = i }
                }

                // --- Draw 30 edges with animated pulse dot ---
                for (edgeIdx, (a, b)) in edges.enumerated() {
                    guard a < 20 && b < 20 else { continue }
                    var line = Path()
                    line.move(to: positions[a])
                    line.addLine(to: positions[b])
                    let edgeActive = (a == activeNode || b == activeNode)
                    ctx.stroke(line, with: .color(catColor.opacity(edgeActive ? 0.14 : 0.06)),
                               lineWidth: edgeActive ? 1.2 : 0.8)

                    // Bright dot traveling along edge
                    let edgeT = fmod(t * 0.8 + Double(edgeIdx) * 0.3, 1.0)
                    let pX = positions[a].x + (positions[b].x - positions[a].x) * CGFloat(edgeT)
                    let pY = positions[a].y + (positions[b].y - positions[a].y) * CGFloat(edgeT)
                    let pulseAlpha = sin(edgeT * .pi)
                    var dotGC = ctx
                    dotGC.addFilter(.blur(radius: 2.5))
                    dotGC.fill(Path(ellipseIn: CGRect(x: pX-4, y: pY-4, width: 8, height: 8)),
                               with: .color(catColor.opacity(pulseAlpha * 0.55)))
                    ctx.fill(Path(ellipseIn: CGRect(x: pX-1.5, y: pY-1.5, width: 3, height: 3)),
                             with: .color(Color.white.opacity(pulseAlpha * 0.85)))
                }

                // --- Data packets: 6 squares traveling along specific edges ---
                let packetEdgeIndices = [0, 5, 11, 17, 22, 27]
                for (pIdx, edgeIdx) in packetEdgeIndices.enumerated() {
                    guard edgeIdx < edges.count else { continue }
                    let (a, b) = edges[edgeIdx]
                    guard a < 20 && b < 20 else { continue }
                    let pktT = fmod(t * 0.6 + Double(pIdx) * 0.18, 1.0)
                    let pkX = positions[a].x + (positions[b].x - positions[a].x) * CGFloat(pktT)
                    let pkY = positions[a].y + (positions[b].y - positions[a].y) * CGFloat(pktT)
                    let pktRect = CGRect(x: pkX-3, y: pkY-3, width: 6, height: 6)
                    var pktGlowGC = ctx
                    pktGlowGC.addFilter(.blur(radius: 3))
                    pktGlowGC.fill(RoundedRectangle(cornerRadius: 1).path(in: pktRect.insetBy(dx: -2, dy: -2)),
                                   with: .color(catColor.opacity(0.4)))
                    ctx.fill(RoundedRectangle(cornerRadius: 1.5).path(in: pktRect),
                             with: .color(catColor.opacity(0.9)))
                }

                // --- Draw 20 nodes with glow and active highlight ---
                for i in 0..<20 {
                    let pulse = CGFloat(0.5 + sin(t * nSpeed[i] + nPhase[i]) * 0.5)
                    let pos = positions[i]
                    let baseR = nSizes[i]
                    let r = baseR + pulse * baseR * 0.6
                    let isActive = (i == activeNode)

                    if isActive {
                        var activeGC = ctx
                        activeGC.addFilter(.blur(radius: 20))
                        activeGC.fill(Path(ellipseIn: CGRect(x: pos.x-r*5, y: pos.y-r*5,
                                                              width: r*10, height: r*10)),
                                      with: .color(catColor.opacity(0.28)))
                    }

                    var glowGC = ctx
                    glowGC.addFilter(.blur(radius: isActive ? 9 : 5))
                    glowGC.fill(Path(ellipseIn: CGRect(x: pos.x-r*2.2, y: pos.y-r*2.2,
                                                        width: r*4.4, height: r*4.4)),
                                with: .color(catColor.opacity(Double(pulse) * (isActive ? 0.35 : 0.18))))
                    ctx.fill(Path(ellipseIn: CGRect(x: pos.x-r*0.7, y: pos.y-r*0.7,
                                                     width: r*1.4, height: r*1.4)),
                             with: .color(catColor.opacity(Double(pulse) * (isActive ? 0.9 : 0.50))))
                    ctx.fill(Path(ellipseIn: CGRect(x: pos.x-r*0.25, y: pos.y-r*0.25,
                                                     width: r*0.5, height: r*0.5)),
                             with: .color(Color.white.opacity(isActive ? 0.95 : 0.7)))
                }

                // --- EEG brain wave strip at bottom ---
                let eegY = H - 22
                let eegW = W * 0.7
                let eegX0 = W * 0.15
                var eegPath = Path()
                eegPath.move(to: CGPoint(x: eegX0, y: eegY))
                for pt in 0...60 {
                    let px = eegX0 + eegW * CGFloat(pt) / 60.0
                    let phase1 = Double(pt) / 60.0 * .pi * 6 - t * 4
                    let phase2 = Double(pt) / 60.0 * .pi * 14 - t * 6
                    let amp1 = 6.0 * sin(phase1)
                    let amp2 = 3.0 * sin(phase2) * max(0, sin(phase1 * 0.5))
                    eegPath.addLine(to: CGPoint(x: px, y: eegY + CGFloat(amp1 + amp2)))
                }
                var eegGlowGC = ctx
                eegGlowGC.addFilter(.blur(radius: 2))
                eegGlowGC.stroke(eegPath, with: .color(catColor.opacity(0.30)), lineWidth: 2)
                ctx.stroke(eegPath, with: .color(catColor.opacity(0.60)), lineWidth: 1)

                // --- Synaptic firing: when isAnswering, 6 bright white flashes radiate from center ---
                if isAnswering {
                    let cx2 = W / 2; let cy2 = H / 2
                    for i in 0..<6 {
                        let flashAngle = Double(i) * .pi / 3.0 + t * 2.0
                        let flashProgress = fmod(t * 2.5 + Double(i) * 0.18, 1.0)
                        let flashDist = 20 + CGFloat(flashProgress) * 120
                        let fAlpha = (1.0 - flashProgress) * 0.85
                        let fX = cx2 + flashDist * CGFloat(cos(flashAngle))
                        let fY = cy2 + flashDist * CGFloat(sin(flashAngle))
                        var flashGC = ctx
                        flashGC.addFilter(.blur(radius: 8))
                        flashGC.fill(Path(ellipseIn: CGRect(x: fX-10, y: fY-10, width: 20, height: 20)),
                                     with: .color(Color.white.opacity(fAlpha * 0.7)))
                        ctx.fill(Path(ellipseIn: CGRect(x: fX-3, y: fY-3, width: 6, height: 6)),
                                 with: .color(Color.white.opacity(fAlpha)))
                        var flashRay = Path()
                        flashRay.move(to: CGPoint(x: cx2, y: cy2))
                        flashRay.addLine(to: CGPoint(x: fX, y: fY))
                        ctx.stroke(flashRay, with: .color(Color.white.opacity(fAlpha * 0.4)), lineWidth: 0.8)
                    }
                }

                // --- DNA double helix strands: two sine waves offset by pi, connected by rungs ---
                let dnaX0: CGFloat = W * 0.05
                let dnaX1: CGFloat = W * 0.18
                let dnaXMid = (dnaX0 + dnaX1) / 2
                let dnaScrollOffset = CGFloat(fmod(t * 30, Double(H)))
                let strandPoints = 40
                var strand1 = Path()
                var strand2 = Path()
                let dnaAmp: CGFloat = (dnaX1 - dnaX0) * 0.45
                for si in 0...strandPoints {
                    let rawY = CGFloat(si) / CGFloat(strandPoints) * H
                    let scrolledY = fmod(rawY + dnaScrollOffset, H)
                    let wave = CGFloat(sin(Double(si) / Double(strandPoints) * .pi * 6 - t * 1.5))
                    let x1 = dnaXMid + dnaAmp * wave
                    let x2 = dnaXMid - dnaAmp * wave
                    if si == 0 {
                        strand1.move(to: CGPoint(x: x1, y: scrolledY))
                        strand2.move(to: CGPoint(x: x2, y: scrolledY))
                    } else {
                        strand1.addLine(to: CGPoint(x: x1, y: scrolledY))
                        strand2.addLine(to: CGPoint(x: x2, y: scrolledY))
                    }
                }
                ctx.stroke(strand1, with: .color(catColor.opacity(0.35)), lineWidth: 1.2)
                ctx.stroke(strand2, with: .color(catColor.opacity(0.25)), lineWidth: 1.2)
                // Rungs connecting the two strands
                let rungCount = 10
                for ri in 0..<rungCount {
                    let rawY = CGFloat(ri) / CGFloat(rungCount) * H
                    let scrolledY = fmod(rawY + dnaScrollOffset, H)
                    let wave = CGFloat(sin(Double(ri) / Double(rungCount) * .pi * 6 - t * 1.5))
                    let x1 = dnaXMid + dnaAmp * wave
                    let x2 = dnaXMid - dnaAmp * wave
                    var rung = Path()
                    rung.move(to: CGPoint(x: x1, y: scrolledY))
                    rung.addLine(to: CGPoint(x: x2, y: scrolledY))
                    let rungAlpha = 0.2 + 0.3 * abs(Double(wave))
                    ctx.stroke(rung, with: .color(Color.white.opacity(rungAlpha)), lineWidth: 0.8)
                }

                // --- Brain scan cross-section silhouette at top-right corner ---
                let bsCX = W * 0.82; let bsCY = H * 0.22
                let bsRX: CGFloat = 38; let bsRY: CGFloat = 48
                var brainOval = Path()
                brainOval.addEllipse(in: CGRect(x: bsCX - bsRX, y: bsCY - bsRY, width: bsRX*2, height: bsRY*2))
                var brainGlowGC = ctx
                brainGlowGC.addFilter(.blur(radius: 6))
                brainGlowGC.stroke(brainOval, with: .color(catColor.opacity(0.20)), lineWidth: 4)
                ctx.stroke(brainOval, with: .color(catColor.opacity(0.30)), lineWidth: 1.2)
                // Sulci / gyri interior faint lines
                for gyriLine in 0..<5 {
                    let gyriY = bsCY - bsRY * 0.6 + CGFloat(gyriLine) * bsRY * 0.3
                    let halfW = bsRX * sqrt(max(0, 1 - pow((gyriY - bsCY)/bsRY, 2)))
                    var gyri = Path()
                    let waveMag = 4.0 * sin(Double(gyriLine) + t * 0.4)
                    gyri.move(to: CGPoint(x: bsCX - halfW + 4, y: gyriY + CGFloat(waveMag)))
                    gyri.addQuadCurve(
                        to: CGPoint(x: bsCX + halfW - 4, y: gyriY - CGFloat(waveMag)),
                        control: CGPoint(x: bsCX, y: gyriY + CGFloat(waveMag) * 1.5))
                    ctx.stroke(gyri, with: .color(catColor.opacity(0.12)), lineWidth: 0.8)
                }
                // Corpus callosum hint — horizontal arc across middle
                var corpusArc = Path()
                corpusArc.addArc(center: CGPoint(x: bsCX, y: bsCY + 10),
                                 radius: bsRX * 0.5,
                                 startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                ctx.stroke(corpusArc, with: .color(catColor.opacity(0.18)), lineWidth: 1.0)

                // --- Frequency spectrum bars at bottom: 12 bars animated to brain wave pattern ---
                let barCount = 12
                let barAreaW = W * 0.55
                let barAreaX = W * 0.225
                let barMaxH: CGFloat = 28
                let barBottomY = H - 6
                let barSpacing = barAreaW / CGFloat(barCount)
                for bi in 0..<barCount {
                    let barPhase = Double(bi) / Double(barCount) * .pi * 2 - t * 3.5
                    let barH = barMaxH * CGFloat((sin(barPhase) * 0.4 + 0.6) * (0.5 + 0.5 * sin(barPhase * 2.3 + t)))
                    let barX = barAreaX + CGFloat(bi) * barSpacing + barSpacing * 0.15
                    let barW = barSpacing * 0.6
                    let barAlpha = 0.35 + 0.45 * (sin(barPhase) * 0.5 + 0.5)
                    var barPath = Path()
                    barPath.addRoundedRect(in: CGRect(x: barX, y: barBottomY - barH, width: barW, height: barH),
                                          cornerSize: CGSize(width: 2, height: 2))
                    var barGlowGC = ctx
                    barGlowGC.addFilter(.blur(radius: 3))
                    barGlowGC.fill(barPath, with: .color(catColor.opacity(barAlpha * 0.6)))
                    ctx.fill(barPath, with: .color(catColor.opacity(barAlpha)))
                }
            }
        }
    }
}

// MARK: - AIThinkCanvas (AAA Enhanced)

private struct AIThinkCanvas: View {
    let startTime: Date
    let confidencePercent: Int
    var thinkingColor: Color = .red

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let elapsed = tl.date.timeIntervalSince(startTime)
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2

                // --- Circuit board background traces (PCB right-angle style) ---
                let traceNodes: [(CGFloat, CGFloat)] = [
                    (cx-55, cy-50), (cx+55, cy-50),
                    (cx-55, cy+50), (cx+55, cy+50),
                    (cx-55, cy),    (cx+55, cy),
                    (cx,    cy-50), (cx,    cy+50)
                ]
                let traceEdges: [(Int, Int)] = [(0,4),(4,2),(1,5),(5,3),(6,0),(6,1),(7,2),(7,3),(4,5),(6,7)]
                for (a, b) in traceEdges {
                    guard a < traceNodes.count && b < traceNodes.count else { continue }
                    var tr = Path()
                    let nA = traceNodes[a]; let nB = traceNodes[b]
                    tr.move(to: CGPoint(x: nA.0, y: nA.1))
                    tr.addLine(to: CGPoint(x: nB.0, y: nA.1))
                    tr.addLine(to: CGPoint(x: nB.0, y: nB.1))
                    ctx.stroke(tr, with: .color(thinkingColor.opacity(0.08)), lineWidth: 1)
                    let padR: CGFloat = 2
                    ctx.fill(Path(ellipseIn: CGRect(x: nB.0-padR, y: nA.1-padR, width: padR*2, height: padR*2)),
                             with: .color(thinkingColor.opacity(0.12)))
                }

                // --- Processing scan line sweeping top-to-bottom ---
                let scanFrac = fmod(t / 3.0, 1.0)
                let scanY = cy - 70 + CGFloat(scanFrac) * 140
                var scanLine = Path()
                scanLine.move(to: CGPoint(x: cx-75, y: scanY))
                scanLine.addLine(to: CGPoint(x: cx+75, y: scanY))
                var scanGC = ctx
                scanGC.addFilter(.blur(radius: 4))
                scanGC.stroke(scanLine, with: .color(thinkingColor.opacity(0.25)), lineWidth: 6)
                ctx.stroke(scanLine, with: .color(thinkingColor.opacity(0.45)), lineWidth: 1)

                // --- 5 dashed fractal rings, alternating rotation direction ---
                for i in 0..<5 {
                    let phase = Double(i) / 5.0
                    let direction: Double = i % 2 == 0 ? 1.0 : -1.0
                    let pulse = fmod(t * 0.65 + phase, 1.0)
                    let baseR: CGFloat = 18 + CGFloat(i) * 14
                    let r = baseR + CGFloat(pulse) * 22
                    let alpha = (1.0 - pulse) * (0.55 - Double(i) * 0.06)
                    let rotOffset = t * direction * (0.4 + Double(i) * 0.15)
                    let dashCount = 6 + i * 2
                    for d in 0..<dashCount {
                        let startA = Double(d) / Double(dashCount) * .pi * 2 + rotOffset
                        let endA   = startA + .pi / Double(dashCount) * 0.6
                        var arc = Path()
                        arc.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                                   startAngle: .radians(startA), endAngle: .radians(endA), clockwise: false)
                        var glowGC = ctx
                        glowGC.addFilter(.blur(radius: 6))
                        glowGC.stroke(arc, with: .color(thinkingColor.opacity(alpha * 0.7)), lineWidth: 4)
                        ctx.stroke(arc, with: .color(thinkingColor.opacity(alpha)), lineWidth: 1.5)
                    }
                }

                // --- 12 orbiting packets on 3 different radii ---
                let orbitConfig: [(CGFloat, Double, Int)] = [
                    (30, 1.8,  0),
                    (52, -1.2, 4),
                    (74, 1.0,  8)
                ]
                for (orbit, speed, startIdx) in orbitConfig {
                    for j in 0..<4 {
                        let angle = t * speed + Double(startIdx + j) * .pi / 2.0
                        let px = cx + CGFloat(cos(angle)) * orbit
                        let py = cy + CGFloat(sin(angle)) * orbit
                        var pktGC = ctx
                        pktGC.addFilter(.blur(radius: 3))
                        pktGC.fill(Path(ellipseIn: CGRect(x: px-5, y: py-5, width: 10, height: 10)),
                                   with: .color(thinkingColor.opacity(0.60)))
                        ctx.fill(Path(ellipseIn: CGRect(x: px-2.5, y: py-2.5, width: 5, height: 5)),
                                 with: .color(Color.white.opacity(0.90)))
                    }
                }

                // --- Eye indicator opens/closes as AI thinks ---
                let openness = CGFloat((sin(t * 0.8) + 1) / 2)
                let eyeCenter = CGPoint(x: cx, y: cy)
                let eyeHalfW: CGFloat = 14
                let eyeHalfH: CGFloat = 8 * openness
                if eyeHalfH > 0.3 {
                    var eyePath = Path()
                    eyePath.move(to: CGPoint(x: eyeCenter.x - eyeHalfW, y: eyeCenter.y))
                    eyePath.addQuadCurve(to: CGPoint(x: eyeCenter.x + eyeHalfW, y: eyeCenter.y),
                                        control: CGPoint(x: eyeCenter.x, y: eyeCenter.y - eyeHalfH))
                    eyePath.addQuadCurve(to: CGPoint(x: eyeCenter.x - eyeHalfW, y: eyeCenter.y),
                                        control: CGPoint(x: eyeCenter.x, y: eyeCenter.y + eyeHalfH))
                    var eyeGlowGC = ctx
                    eyeGlowGC.addFilter(.blur(radius: 5))
                    eyeGlowGC.fill(eyePath, with: .color(thinkingColor.opacity(Double(openness) * 0.4)))
                    ctx.stroke(eyePath, with: .color(Color.white.opacity(Double(openness) * 0.85)), lineWidth: 1.5)
                    let pupilR: CGFloat = 4 * openness
                    var pupilGC = ctx
                    pupilGC.addFilter(.blur(radius: 2))
                    pupilGC.fill(Path(ellipseIn: CGRect(x: eyeCenter.x-pupilR, y: eyeCenter.y-pupilR,
                                                         width: pupilR*2, height: pupilR*2)),
                                 with: .color(thinkingColor.opacity(Double(openness) * 0.8)))
                    ctx.fill(Path(ellipseIn: CGRect(x: eyeCenter.x-pupilR*0.5, y: eyeCenter.y-pupilR*0.5,
                                                     width: pupilR, height: pupilR)),
                             with: .color(Color.white.opacity(Double(openness))))
                }

                // --- Confidence meter arc fills as delay progresses ---
                let confFrac = min(elapsed / 3.8, 1.0)
                let confStart = -CGFloat.pi * 0.8
                let confSweep = CGFloat.pi * 1.6 * CGFloat(confFrac)
                let confR: CGFloat = 85
                var bgArc = Path()
                bgArc.addArc(center: CGPoint(x: cx, y: cy), radius: confR,
                             startAngle: .radians(Double(confStart)),
                             endAngle: .radians(Double(confStart + CGFloat.pi * 1.6)),
                             clockwise: false)
                ctx.stroke(bgArc, with: .color(thinkingColor.opacity(0.10)), lineWidth: 3)
                if confSweep > 0.01 {
                    var fillArc = Path()
                    fillArc.addArc(center: CGPoint(x: cx, y: cy), radius: confR,
                                   startAngle: .radians(Double(confStart)),
                                   endAngle: .radians(Double(confStart + confSweep)),
                                   clockwise: false)
                    var confGlowGC = ctx
                    confGlowGC.addFilter(.blur(radius: 5))
                    confGlowGC.stroke(fillArc, with: .color(thinkingColor.opacity(0.4)), lineWidth: 5)
                    ctx.stroke(fillArc, with: .color(thinkingColor.opacity(0.85)), lineWidth: 2.5)
                }

                // --- Core glow ---
                var coreGC = ctx
                coreGC.addFilter(.blur(radius: 16))
                let coreR = 16 + CGFloat(sin(t * 3.5)) * 4
                coreGC.fill(Path(ellipseIn: CGRect(x: cx-coreR, y: cy-coreR, width: coreR*2, height: coreR*2)),
                            with: .color(thinkingColor.opacity(0.55)))
                ctx.fill(Path(ellipseIn: CGRect(x: cx-8, y: cy-8, width: 16, height: 16)),
                         with: .color(thinkingColor.opacity(0.90)))

                // --- Loading dots cascade: 5 dots that light up sequentially while AI thinks ---
                let dotCount = 5
                let dotSpacing: CGFloat = 16
                let dotsStartX = cx - CGFloat(dotCount - 1) * dotSpacing / 2
                let dotBaseY = cy + confR + 18
                for di in 0..<dotCount {
                    let dotPhase = fmod(t * 2.2 - Double(di) * 0.25, 1.0)
                    let lit = dotPhase < 0.45
                    let dotAlpha = lit ? (0.55 + 0.45 * sin(dotPhase / 0.45 * .pi)) : 0.15
                    let dotR: CGFloat = lit ? 5 : 3.5
                    let dotX = dotsStartX + CGFloat(di) * dotSpacing
                    var dotGlowGC = ctx
                    dotGlowGC.addFilter(.blur(radius: lit ? 5 : 1))
                    dotGlowGC.fill(Path(ellipseIn: CGRect(x: dotX-dotR*1.4, y: dotBaseY-dotR*1.4,
                                                           width: dotR*2.8, height: dotR*2.8)),
                                   with: .color(thinkingColor.opacity(dotAlpha * 0.6)))
                    ctx.fill(Path(ellipseIn: CGRect(x: dotX-dotR, y: dotBaseY-dotR, width: dotR*2, height: dotR*2)),
                             with: .color(Color.white.opacity(dotAlpha)))
                }

                // --- Neural pathway highlight: winning answer pathway traced with animated line ---
                let pathProgress = min(elapsed / 2.5, 1.0)
                if pathProgress > 0.05 {
                    let pathPoints: [CGPoint] = [
                        CGPoint(x: cx - 60, y: cy - 60),
                        CGPoint(x: cx - 30, y: cy - 35),
                        CGPoint(x: cx,      y: cy - 15),
                        CGPoint(x: cx + 30, y: cy - 35),
                        CGPoint(x: cx + 60, y: cy - 60)
                    ]
                    let totalSegments = pathPoints.count - 1
                    let drawnUpTo = pathProgress * Double(totalSegments)
                    var pathLine = Path()
                    pathLine.move(to: pathPoints[0])
                    for seg in 0..<totalSegments {
                        let segFrac = max(0.0, min(1.0, drawnUpTo - Double(seg)))
                        if segFrac <= 0 { break }
                        let from = pathPoints[seg]
                        let to = pathPoints[seg + 1]
                        let endPt = CGPoint(x: from.x + (to.x - from.x) * CGFloat(segFrac),
                                           y: from.y + (to.y - from.y) * CGFloat(segFrac))
                        pathLine.addLine(to: endPt)
                    }
                    var pathGlowGC = ctx
                    pathGlowGC.addFilter(.blur(radius: 5))
                    pathGlowGC.stroke(pathLine, with: .color(thinkingColor.opacity(0.55)), lineWidth: 4)
                    ctx.stroke(pathLine, with: .color(Color.white.opacity(0.75)), lineWidth: 1.2)
                    // Dot at path tip
                    let tipFrac = min(pathProgress, 1.0)
                    let tipSeg = min(Int(tipFrac * Double(totalSegments)), totalSegments - 1)
                    let tipLocal = tipFrac * Double(totalSegments) - Double(tipSeg)
                    let tipFrom = pathPoints[tipSeg]
                    let tipTo   = pathPoints[min(tipSeg + 1, totalSegments)]
                    let tipX = tipFrom.x + (tipTo.x - tipFrom.x) * CGFloat(tipLocal)
                    let tipY = tipFrom.y + (tipTo.y - tipFrom.y) * CGFloat(tipLocal)
                    ctx.fill(Path(ellipseIn: CGRect(x: tipX-4, y: tipY-4, width: 8, height: 8)),
                             with: .color(Color.white.opacity(0.9)))
                }

                // --- Confidence readout text label rendered on canvas ---
                let confPct = max(0, min(100, confidencePercent))
                let confLabel = "CONFIDENCE: \(confPct)%"
                ctx.draw(
                    Text(confLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(thinkingColor.opacity(0.75)),
                    at: CGPoint(x: cx, y: cy + confR + 38),
                    anchor: .center
                )
            }
        }
    }
}

// MARK: - AnswerFlashCanvas

private struct AnswerFlashCanvas: View {
    let correct: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2

                if correct {
                    // 16 green burst particles radiating from center
                    for i in 0..<16 {
                        let angle = Double(i) / 16.0 * .pi * 2
                        let progress = fmod(t * 1.5, 1.0)
                        let dist = 20 + CGFloat(progress) * 90
                        let alpha = (1.0 - progress) * 0.9
                        let px = cx + dist * CGFloat(cos(angle))
                        let py = cy + dist * CGFloat(sin(angle))
                        let pR: CGFloat = 5 * (1.0 - CGFloat(progress)) + 1.5
                        var glowGC = ctx
                        glowGC.addFilter(.blur(radius: 4))
                        glowGC.fill(Path(ellipseIn: CGRect(x: px-pR*1.5, y: py-pR*1.5, width: pR*3, height: pR*3)),
                                    with: .color(Color.green.opacity(alpha * 0.5)))
                        ctx.fill(Path(ellipseIn: CGRect(x: px-pR, y: py-pR, width: pR*2, height: pR*2)),
                                 with: .color(Color.green.opacity(alpha)))
                    }

                    // Golden ring pulse
                    let ringProg = fmod(t * 1.2, 1.0)
                    let ringR: CGFloat = 30 + CGFloat(ringProg) * 110
                    let ringAlpha = (1.0 - ringProg) * 0.85
                    var ringGlowGC = ctx
                    ringGlowGC.addFilter(.blur(radius: 10))
                    ringGlowGC.stroke(Path(ellipseIn: CGRect(x: cx-ringR, y: cy-ringR, width: ringR*2, height: ringR*2)),
                                      with: .color(Color.yellow.opacity(ringAlpha * 0.6)), lineWidth: 8)
                    ctx.stroke(Path(ellipseIn: CGRect(x: cx-ringR, y: cy-ringR, width: ringR*2, height: ringR*2)),
                               with: .color(Color.yellow.opacity(ringAlpha)), lineWidth: 2)

                    // CORRECT! text flash
                    let textAlpha = max(0.0, min(1.0, 2.0 - fmod(t * 0.8, 1.0) * 2.2))
                    ctx.draw(Text("CORRECT!")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(textAlpha)),
                             at: CGPoint(x: cx, y: cy - 8), anchor: .center)

                } else {
                    // Red screen vignette
                    let vigAlpha = 0.3 + 0.2 * sin(t * 8)
                    var vigGC = ctx
                    vigGC.addFilter(.blur(radius: 30))
                    vigGC.fill(Path(CGRect(origin: .zero, size: size)),
                               with: .color(thinkingColor.opacity(vigAlpha * 0.5)))

                    // WRONG text with shake
                    let shakeSeed = floor(t * 12)
                    let shakeX = CGFloat((Int(shakeSeed) * 7 % 11) - 5) * 0.8
                    let shakeY = CGFloat((Int(shakeSeed) * 13 % 9) - 4) * 0.6
                    let wrongAlpha = max(0.0, min(1.0, 1.8 - fmod(t * 0.7, 1.0) * 1.8))
                    ctx.draw(Text("WRONG")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(thinkingColor.opacity(wrongAlpha)),
                             at: CGPoint(x: cx + shakeX, y: cy - 8 + shakeY), anchor: .center)

                    // Scattered spark particles
                    for i in 0..<20 {
                        let angle = Double(i) / 20.0 * .pi * 2 + Double(i % 3) * 0.4
                        let prog = fmod(t * 1.8 + Double(i) * 0.07, 1.0)
                        let dist = 15 + CGFloat(prog) * 80 + CGFloat(i % 4) * 12
                        let alpha = (1.0 - prog) * 0.8
                        let px = cx + dist * CGFloat(cos(angle))
                        let py = cy + dist * CGFloat(sin(angle))
                        let sR: CGFloat = 3 * (1.0 - CGFloat(prog)) + 1
                        var sparkGC = ctx
                        sparkGC.addFilter(.blur(radius: 2))
                        sparkGC.fill(Path(ellipseIn: CGRect(x: px-sR*1.5, y: py-sR*1.5, width: sR*3, height: sR*3)),
                                     with: .color(Color.orange.opacity(alpha * 0.6)))
                        ctx.fill(Path(ellipseIn: CGRect(x: px-sR*0.5, y: py-sR*0.5, width: sR, height: sR)),
                                 with: .color(thinkingColor.opacity(alpha)))
                    }
                }
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
    @State private var showAnswerFlash: Bool = false
    @State private var answerFlashCorrect: Bool = false
    @State private var opponentTurnStart: Date = .now
    @State private var isAnswering: Bool = false

    // Streak multiplier
    @State private var streakMultiplier: Int = 1
    @State private var currentStreak: Int = 0
    @State private var totalScore: Int = 0
    @State private var showStreakBanner: Bool = false
    @State private var streakBannerText: String = ""

    // Lifelines
    @State private var lifelinesUsed: Set<BBLifeline> = []
    @State private var eliminatedAnswers: Set<Int> = []
    @State private var showFanVote: Bool = false
    @State private var fanVotePercents: [Int] = [25, 25, 25, 25]

    // AI Coach Commentary
    @State private var coachComment: String = ""
    @State private var showCoachComment: Bool = false

    // Round tracking for time pressure
    @State private var roundNumber: Int = 1

    // AI Personality
    @State private var aiPersonality: AIPersonality = .confident
    @State private var aiConfidence: Double = 1.0
    @State private var aiThinkingText: String = "Processing..."
    @State private var aiShaking: Bool = false

    private var opponentName: String { aiPersonality.name }
    private let totalCrowns = BBCategory.allCases.count

    private let correctComments = [
        "Neural pathways firing correctly!",
        "Locked in!",
        "FEL IQ rising!",
        "System optimal.",
        "That's the data right there."
    ]
    private let wrongComments = [
        "Reset and recalibrate.",
        "Study the fundamentals.",
        "AI would have known that.",
        "Recalibrate and reload.",
        "Processing error. Try again."
    ]

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
                    onComplete: {
                        aiPersonality = AIPersonality.allCases.randomElement() ?? .confident
                        aiConfidence = 1.0
                        phase = .spinning
                    }
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
                    p1Score: totalScore,
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

            // Answer flash overlay shown briefly after each answer
            if showAnswerFlash {
                AnswerFlashCanvas(correct: answerFlashCorrect)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Streak banner overlay
            if showStreakBanner {
                VStack {
                    Spacer()
                    Text(streakBannerText)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.yellow)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black.opacity(0.75))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5))
                        )
                        .shadow(color: Color.yellow.opacity(0.5), radius: 12)
                        .transition(.scale.combined(with: .opacity))
                    Spacer().frame(height: 80)
                }
                .allowsHitTesting(false)
                .animation(.spring(response: 0.3), value: showStreakBanner)
            }

            // Coach comment overlay
            if showCoachComment {
                VStack {
                    Spacer().frame(height: 120)
                    HStack(spacing: 10) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(gameMode.accentColor)
                        Text(coachComment)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(gameMode.accentColor.opacity(0.35), lineWidth: 1))
                    )
                    .padding(.horizontal, 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    Spacer()
                }
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.35), value: showCoachComment)
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
            // Score + multiplier crown indicator in center
            VStack(spacing: 2) {
                if streakMultiplier > 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.yellow)
                        Text("\(streakMultiplier)x")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.yellow)
                    }
                }
                Text("\(totalScore)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
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
                ForEach(Array(BBCategory.allCases.enumerated()), id: \.element.id) { i, cat in
                    let slice = 360.0 / Double(BBCategory.allCases.count)
                    WedgeShape(startAngle: slice * Double(i) - 90, endAngle: slice * Double(i + 1) - 90)
                        .fill(cat.color.opacity(0.85))
                }
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(spinDegrees))
                .animation(.easeOut(duration: 2.2), value: spinDegrees)

                ForEach(Array(BBCategory.allCases.enumerated()), id: \.element.id) { i, cat in
                    let slice = 360.0 / Double(BBCategory.allCases.count)
                    let mid = (slice * Double(i) + slice / 2 - 90 + spinDegrees) * .pi / 180
                    Image(systemName: cat.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .offset(x: cos(mid) * 72, y: sin(mid) * 72)
                }
                .animation(.easeOut(duration: 2.2), value: spinDegrees)

                Circle().fill(Theme.deepBlack).frame(width: 52, height: 52)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(gameMode.accentColor)

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
                SpinFXCanvas(spinning: spinning, selectedCatColor: selectedCategory.color, streakCount: currentStreak)
                    .frame(width: 280, height: 280)
                    .allowsHitTesting(false)
            )

            Spacer().frame(height: 36)

            if isPlayerTurn {
                Button {
                    guard !spinning else { return }
                    spinning = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                Text("Spinning for \(opponentName)\u{2026}")
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
                        // Timer with draining arc
                        ZStack {
                            let maxTime = timerMax()
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                                .frame(width: 42, height: 42)
                            Circle()
                                .trim(from: 0, to: CGFloat(timeLeft) / CGFloat(maxTime))
                                .stroke(timeLeft > 5 ? selectedCategory.color : Color.red,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 42, height: 42)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: timeLeft)
                            Text("\(timeLeft)")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(timeLeft > 5 ? .white : .red)
                                .contentTransition(.numericText())
                        }
                        .frame(width: 42, height: 42)
                    }
                    .padding(.horizontal, 24)

                    Text(q.question)
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)

                    // Fan vote display
                    if showFanVote {
                        HStack(spacing: 6) {
                            ForEach(q.answers.indices, id: \.self) { i in
                                if !eliminatedAnswers.contains(i) {
                                    VStack(spacing: 2) {
                                        Text(["A","B","C","D"][i])
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .foregroundStyle(selectedCategory.color)
                                        Text("\(fanVotePercents[i])%")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory.color.opacity(0.12))
                                    .clipShape(.rect(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    VStack(spacing: 10) {
                        ForEach(q.answers.indices, id: \.self) { i in
                            if !eliminatedAnswers.contains(i) {
                                answerButton(index: i, text: q.answers[i], question: q)
                            } else {
                                // Dimmed eliminated answer slot
                                HStack(spacing: 14) {
                                    Text(["A", "B", "C", "D"][i])
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.1))
                                        .frame(width: 28, height: 28)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(Circle())
                                    Text(q.answers[i])
                                        .font(.system(.subheadline, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.1))
                                        .strikethrough(true, color: Color.white.opacity(0.1))
                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.02))
                                        .overlay(RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.03), lineWidth: 1))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Lifeline buttons
                    lifelineBar(for: q)
                }
            }

            Spacer()
        }
        .background(
            NeuralBGCanvas(catColor: selectedCategory.color, isAnswering: isAnswering)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
    }

    private func lifelineBar(for question: BBQuestion) -> some View {
        HStack(spacing: 12) {
            ForEach(BBLifeline.allCases, id: \.label) { lifeline in
                let used = lifelinesUsed.contains(lifeline)
                Button {
                    guard !used else { return }
                    useLifeline(lifeline, for: question)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: lifeline.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(used ? Color.white.opacity(0.2) : gameMode.accentColor)
                        Text(lifeline.label)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(used ? Color.white.opacity(0.2) : Color.white.opacity(0.7))
                    }
                    .frame(width: 60, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(used ? Color.white.opacity(0.03) : Color.white.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(used ? Color.white.opacity(0.04) : gameMode.accentColor.opacity(0.3), lineWidth: 1))
                    )
                    .opacity(used ? 0.4 : 1.0)
                }
                .disabled(used || selectedAnswer != nil)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func answerButton(index: Int, text: String, question: BBQuestion) -> some View {
        let isSelected = selectedAnswer == index
        let accent = selectedCategory.color
        return Button {
            guard selectedAnswer == nil else { return }
            isAnswering = true
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
                if streakMultiplier > 1 {
                    Text("+\(10 * streakMultiplier) pts  (\(streakMultiplier)x multiplier)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.yellow)
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

            // Personality label chip
            Text(personalityLabel)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(aiPersonality.thinkingColor)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(aiPersonality.thinkingColor.opacity(0.15).cornerRadius(6))
                .tracking(1.5)

            AIThinkCanvas(startTime: opponentTurnStart,
                          confidencePercent: Int(min(0.95, max(0.05, selectedCategory.aiAccuracy + aiPersonality.accuracyModifier * aiConfidence)) * 100),
                          thinkingColor: aiPersonality.thinkingColor)
                .frame(width: 200, height: 200)
                .offset(x: aiShaking ? CGFloat.random(in: -6...6) : 0)
                .animation(aiShaking ? .easeInOut(duration: 0.05).repeatCount(6) : .default, value: aiShaking)

            // Thinking text
            Text(aiThinkingText)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(aiPersonality.thinkingColor.opacity(0.85))
                .multilineTextAlignment(.center)
                .italic()

            Text(opponentLabel)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Confidence meter
            VStack(spacing: 4) {
                Text("CONFIDENCE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(aiPersonality.thinkingColor)
                            .frame(width: geo.size.width * aiConfidence, height: 6)
                            .animation(.spring(response: 0.5), value: aiConfidence)
                    }
                }.frame(width: 140, height: 6)
            }

            Text("\(opponentName.uppercased()) IS ANSWERING")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)

            Spacer()
        }
    }

    private var personalityLabel: String {
        switch aiPersonality {
        case .confident: return "CONFIDENT MODE"
        case .nervous: return "NERVOUS ENERGY"
        case .taunting: return "TRASH TALK MODE"
        case .scholarly: return "SCHOLAR MODE"
        }
    }

    // MARK: - Logic

    private func timerMax() -> Int {
        switch roundNumber {
        case 1: return 15
        case 2: return 12
        default: return 10
        }
    }

    private func spinWheel() {
        let extra = Double.random(in: 720...1440)
        spinDegrees += extra

        let normalised = spinDegrees.truncatingRemainder(dividingBy: 360)
        let slice = 360.0 / Double(BBCategory.allCases.count)
        let idx = Int((360 - normalised) / slice) % BBCategory.allCases.count
        selectedCategory = BBCategory.allCases[max(0, min(idx, BBCategory.allCases.count - 1))]

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                spinning = false
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
        eliminatedAnswers = []
        showFanVote = false
        isAnswering = false
        let maxTime = timerMax()
        timeLeft = maxTime
        phase = .question
        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while timeLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    timeLeft -= 1
                    if timeLeft <= 3 && timeLeft > 0 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            await MainActor.run { timeExpired() }
        }
    }

    private func timeExpired() {
        timerTask?.cancel()
        isCorrect = false
        isAnswering = false
        streakMultiplier = 1
        currentStreak = 0
        feedbackMessage = "Time's up!"
        triggerAnswerFlash(correct: false)
        showCoachMessage(correct: false)
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

        if correct {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        isCorrect = correct
        triggerAnswerFlash(correct: correct)
        showCoachMessage(correct: correct)

        if correct {
            // Streak multiplier update
            currentStreak += 1
            let newMultiplier = min(4, 1 + (currentStreak - 1) / 1)
            if newMultiplier > streakMultiplier {
                streakMultiplier = newMultiplier
                flashStreakBanner()
            }
            let basePoints = 10
            totalScore += basePoints * streakMultiplier

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
            streakMultiplier = 1
            currentStreak = 0
            feedbackMessage = "Wrong \u{2014} \u{201C}\(question.answers[question.correctIndex])\u{201D}"
        }

        isAnswering = false
        phase = .feedback
        roundNumber += 1

        Task {
            try? await Task.sleep(for: .seconds(correct ? 1.8 : 2.0))
            await MainActor.run {
                if checkWin() { return }
                if correct { nextPlayerTurn() } else { beginOpponentTurn() }
            }
        }
    }

    private func flashStreakBanner() {
        let banners = ["2x STREAK!", "3x STREAK!", "4x MULTIPLIER!"]
        let idx = min(streakMultiplier - 2, banners.count - 1)
        guard idx >= 0 else { return }
        streakBannerText = banners[idx]
        withAnimation { showStreakBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run {
                withAnimation { showStreakBanner = false }
            }
        }
    }

    private func showCoachMessage(correct: Bool) {
        coachComment = correct
            ? (correctComments.randomElement() ?? "Locked in!")
            : (wrongComments.randomElement() ?? "Reset and recalibrate.")
        withAnimation { showCoachComment = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                withAnimation { showCoachComment = false }
            }
        }
    }

    private func useLifeline(_ lifeline: BBLifeline, for question: BBQuestion) {
        lifelinesUsed.insert(lifeline)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch lifeline {
        case .fiftyFifty:
            // Eliminate 2 wrong answers
            var wrongIndices = question.answers.indices.filter { $0 != question.correctIndex }
            wrongIndices.shuffle()
            let toEliminate = wrongIndices.prefix(2)
            eliminatedAnswers = Set(toEliminate)
        case .phoneAFan:
            // Show crowd vote: correct answer gets 70-85%, rest share remainder
            let correctPct = Int.random(in: 70...85)
            let remainder = 100 - correctPct
            var others = question.answers.indices.filter { $0 != question.correctIndex }
            others.shuffle()
            var percents = [Int](repeating: 0, count: question.answers.count)
            percents[question.correctIndex] = correctPct
            if others.count >= 2 {
                let split1 = remainder / 2
                percents[others[0]] = split1
                percents[others[1]] = remainder - split1
                if others.count == 3 {
                    percents[others[2]] = 0
                }
            } else if others.count == 1 {
                percents[others[0]] = remainder
            }
            fanVotePercents = percents
            showFanVote = true
        case .extraTime:
            timeLeft = min(timeLeft + 8, timerMax() + 8)
        }
    }

    private func triggerAnswerFlash(correct: Bool) {
        answerFlashCorrect = correct
        withAnimation(.easeIn(duration: 0.1)) { showAnswerFlash = true }
        Task {
            try? await Task.sleep(for: .seconds(correct ? 1.6 : 1.8))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { showAnswerFlash = false }
            }
        }
    }

    private func beginOpponentTurn() {
        isPlayerTurn = false
        let cat = BBCategory.allCases.randomElement()!
        let pool = BBBank.all[cat] ?? []
        guard let q = pool.randomElement() else { nextPlayerTurn(); return }
        opponentLabel = "\(cat.rawValue): \u{201C}\(q.question)\u{201D}"
        aiThinkingText = aiPersonality.thinkingLines.randomElement() ?? "Processing..."
        opponentTurnStart = .now
        phase = .opponentTurn

        Task {
            let delay = Double.random(in: aiPersonality.thinkDelay)
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run {
                let baseAccuracy = cat.aiAccuracy + aiPersonality.accuracyModifier * aiConfidence
                let correct = Double.random(in: 0...1) < min(0.95, max(0.05, baseAccuracy))
                if correct && !opponentCrowns.contains(cat) {
                    opponentCrowns.insert(cat)
                    opponentLabel = aiPersonality.correctLines.randomElement() ?? "\(opponentName) answered correctly!"
                    aiConfidence = min(1.0, aiConfidence + 0.1)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    opponentLabel = aiPersonality.incorrectLines.randomElement() ?? "\(opponentName) missed it."
                    aiConfidence = max(0.2, aiConfidence - 0.15)
                    aiShaking = true
                    Task {
                        try? await Task.sleep(for: .seconds(0.5))
                        await MainActor.run { aiShaking = false }
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
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
            GameResultService.saveResult(modeId: "brain_brawl", userScore: totalScore)
            phase = .result
            return true
        }
        return false
    }
}
