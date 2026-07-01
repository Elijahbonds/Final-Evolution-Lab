import Foundation
import SwiftUI

nonisolated struct CreatorLink: Sendable {
    enum LinkType: String, Sendable { case masterclass, imdb, product, website, youtube, instagram, spotify, gallery, tiktok, twitter, podcast }
    let type: LinkType
    let label: String
    let url: String
}

nonisolated struct CreatorCard: Identifiable, Sendable {
    let id: String
    let creatorName: String
    let title: String
    let description: String
    let costShards: Int
    let iconName: String
    let accentColor: Color
    let metricsBoost: PerformanceMetrics
    let movementSignature: MovementSignature
    /// One-line creator tagline shown in the showcase screen.
    let showcaseTagline: String
    /// Key IP highlights the creator shares with their audience.
    let showcaseHighlights: [String]
    /// Short bio paragraph (2–3 sentences) shown in the showcase screen.
    let miniBio: String
    /// External links — masterclass, IMDb, product, website, etc.
    let links: [CreatorLink]

    static let catalog: [CreatorCard] = [
        CreatorCard(
            id: "amir_smith",
            creatorName: "Amir Smith",
            title: "Amir Smith Signature",
            description: "Elite guard footwork and explosive first step. +14 PRQ, +22 Vertical, +12 Neural Drive.",
            costShards: 800,
            iconName: "figure.run.treadmill",
            accentColor: Color(red: 0.1, green: 0.7, blue: 1.0),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 12,
                prqScore: 14,
                readinessScore: 8,
                verticalPotential: 22,
                neuralDrive: 12,
                currentOutfit: "amir_smith"
            ),
            movementSignature: MovementSignature(
                style: .explosive,
                jumpApex: 1.4,
                hangTimeFactor: 1.5,
                firstStepBurst: 1.6,
                limbEmission: 0.65,
                trailColor: Color(red: 0.1, green: 0.7, blue: 1.0)
            ),
            showcaseTagline: "First step is a weapon. Let the data prove it.",
            showcaseHighlights: [
                "14-year pro career at elite guard position",
                "Patented 3-step deceleration-acceleration cycle",
                "Venice Beach open run champion · 3 consecutive seasons",
                "Meshy athlete scan: MESHY_amir_smith_athlete",
                "Training philosophy: slow is smooth, smooth is fast"
            ],
            miniBio: "Amir Smith is an elite guard with 14 years of professional experience and a reputation for the most explosive first step in the game. He trains at Venice Beach and uses data-driven movement analysis to coach the next generation of guards.",
            links: [
                CreatorLink(type: .product, label: "Amir Smith Training Program", url: "https://amirsmith.training"),
                CreatorLink(type: .instagram, label: "@amirsmithhoops", url: "https://instagram.com/amirsmithhoops"),
                CreatorLink(type: .youtube, label: "Amir Smith Movement Lab", url: "https://youtube.com/@amirsmith")
            ]
        ),
        CreatorCard(
            id: "coach_v_elite",
            creatorName: "Coach V",
            title: "Coach V Elite Card",
            description: "Unlock Coach V's elite movement data. +15 PRQ, +20 Vertical, +10 Neural Drive.",
            costShards: 500,
            iconName: "crown.fill",
            accentColor: .yellow,
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 10,
                prqScore: 15,
                readinessScore: 5,
                verticalPotential: 20,
                neuralDrive: 10,
                currentOutfit: "coach_v"
            ),
            movementSignature: MovementSignature(
                style: .explosive,
                jumpApex: 1.3,
                hangTimeFactor: 1.4,
                firstStepBurst: 1.2,
                limbEmission: 0.5,
                trailColor: .yellow
            ),
            showcaseTagline: "Twenty years of elite coaching compressed into one card.",
            showcaseHighlights: [
                "Head coach of 3 national championship programs",
                "Developed 40+ D1 athletes from grassroots",
                "Proprietary neural activation warm-up protocol",
                "Zone 2 base + CNS spike periodization framework",
                "Movement audit: elite biomechanics film library"
            ],
            miniBio: "Coach V is a veteran performance coach with two decades of elite-level experience building champions from the ground up. Known for turning raw athletes into D1 prospects, he combines periodization science with old-school intensity to produce results that speak for themselves.",
            links: [
                CreatorLink(type: .masterclass, label: "Coach V Masterclass", url: "https://coachv.training/masterclass"),
                CreatorLink(type: .website, label: "CoachV.training", url: "https://coachv.training"),
                CreatorLink(type: .youtube, label: "Coach V Performance", url: "https://youtube.com/@coachvperformance")
            ]
        ),
        CreatorCard(
            id: "bonds_bounce",
            creatorName: "Bonds Bounce",
            title: "Bonds Bounce Blueprint",
            description: "The vertical jump architecture. +12 PRQ, +25 Vertical, +8 Efficiency.",
            costShards: 750,
            iconName: "bolt.trianglebadge.exclamationmark.fill",
            accentColor: Color(red: 0.95, green: 0.49, blue: 0.15),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 8,
                prqScore: 12,
                readinessScore: 5,
                verticalPotential: 25,
                neuralDrive: 8,
                currentOutfit: "bonds_bounce"
            ),
            movementSignature: MovementSignature(
                style: .vertical,
                jumpApex: 1.5,
                hangTimeFactor: 1.6,
                firstStepBurst: 1.0,
                limbEmission: 0.6,
                trailColor: Color(red: 0.95, green: 0.49, blue: 0.15)
            ),
            showcaseTagline: "Every inch of vertical was engineered, not gifted.",
            showcaseHighlights: [
                "42-inch verified standing vertical leap",
                "Tendon stiffness training: depth drops to max intent",
                "Plyometric periodization from base to peak in 12 weeks",
                "Personal Meshy scan embedded as primary avatar",
                "Full Final Evolution Lab methodology · Venice Beach origin"
            ],
            miniBio: "Bonds Bounce is the vertical jump system born at Venice Beach — every inch of air engineered through tendon stiffness, plyometric periodization, and relentless max-intent training. The methodology is documented in the Final Evolution Lab and backed by a 42-inch standing vertical.",
            links: [
                CreatorLink(type: .product, label: "Bonds Bounce Program", url: "https://bondsbounce.com"),
                CreatorLink(type: .instagram, label: "@bondsbounce", url: "https://instagram.com/bondsbounce"),
                CreatorLink(type: .youtube, label: "Bonds Bounce Lab", url: "https://youtube.com/@bondsbounce")
            ]
        ),
        CreatorCard(
            id: "flight_lab",
            creatorName: "Flight Lab",
            title: "Flight Lab Pro Card",
            description: "Advanced flight mechanics data. +10 PRQ, +18 Vertical, +15 Neural Drive.",
            costShards: 600,
            iconName: "airplane.departure",
            accentColor: Color(red: 0, green: 0.95, blue: 0.9),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 5,
                prqScore: 10,
                readinessScore: 8,
                verticalPotential: 18,
                neuralDrive: 15,
                currentOutfit: "flight_lab"
            ),
            movementSignature: MovementSignature(
                style: .fluid,
                jumpApex: 1.2,
                hangTimeFactor: 1.8,
                firstStepBurst: 1.1,
                limbEmission: 0.7,
                trailColor: Color(red: 0, green: 0.95, blue: 0.9)
            ),
            showcaseTagline: "Hang time isn't luck — it's a skill you train.",
            showcaseHighlights: [
                "Flight mechanics research: air time vs. peak height study",
                "Peak hang time optimization via hip flexor protocol",
                "Aerial awareness drills: spin, grab, control",
                "Cross-sport application: basketball, volleyball, gymnastics",
                "Open-source movement library · 200+ hours of footage"
            ],
            miniBio: "Flight Lab is an open research collective dedicated to the science of hang time — studying how elite athletes maximize air time through hip flexor activation, body awareness, and aerial control. Their 200+ hour movement library spans basketball, volleyball, and gymnastics.",
            links: [
                CreatorLink(type: .website, label: "Flight Lab Research", url: "https://flightlabmovement.com"),
                CreatorLink(type: .youtube, label: "Flight Lab Channel", url: "https://youtube.com/@flightlab"),
                CreatorLink(type: .instagram, label: "@flightlabmovement", url: "https://instagram.com/flightlabmovement")
            ]
        ),
        CreatorCard(
            id: "neural_max",
            creatorName: "Neural Max",
            title: "Neural Max Override",
            description: "Peak CNS recruitment protocols. +8 PRQ, +12 Vertical, +25 Neural Drive.",
            costShards: 400,
            iconName: "brain.head.profile.fill",
            accentColor: Color(red: 0.6, green: 0.2, blue: 1.0),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 5,
                prqScore: 8,
                readinessScore: 10,
                verticalPotential: 12,
                neuralDrive: 25,
                currentOutfit: "neural_max"
            ),
            movementSignature: MovementSignature(
                style: .neural,
                jumpApex: 1.1,
                hangTimeFactor: 1.2,
                firstStepBurst: 1.5,
                limbEmission: 0.9,
                trailColor: Color(red: 0.6, green: 0.2, blue: 1.0)
            ),
            showcaseTagline: "Your nervous system is the real performance engine.",
            showcaseHighlights: [
                "CNS fatigue monitoring: HRV-based readiness scoring",
                "Neural priming protocol: PAP complex for peak output",
                "Slow-motion film analysis: CNS recruitment patterns",
                "Sleep + recovery optimization framework for athletes",
                "Collaborates with sports neuroscience research labs"
            ],
            miniBio: "Neural Max is a sports neuroscience platform that treats the central nervous system as the true engine of athletic performance. By monitoring HRV, optimizing sleep, and applying PAP complex protocols, they help athletes unlock recruitment patterns that most training programs leave untouched.",
            links: [
                CreatorLink(type: .masterclass, label: "Neural Max Protocol", url: "https://neuralmax.io/protocol"),
                CreatorLink(type: .website, label: "NeuralMax.io", url: "https://neuralmax.io"),
                CreatorLink(type: .youtube, label: "Neural Max Science", url: "https://youtube.com/@neuralmax")
            ]
        ),
    ]
}

nonisolated struct MovementSignature: Sendable {
    let style: MovementStyle
    let jumpApex: Double
    let hangTimeFactor: Double
    let firstStepBurst: Double
    let limbEmission: Double
    let trailColor: Color
}

nonisolated enum MovementStyle: String, Sendable {
    case explosive
    case vertical
    case fluid
    case neural
    case standard

    var animationSpeed: Double {
        switch self {
        case .explosive: 0.8
        case .vertical: 1.0
        case .fluid: 1.2
        case .neural: 0.7
        case .standard: 1.0
        }
    }
}
