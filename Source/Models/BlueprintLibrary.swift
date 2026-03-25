import SwiftUI

struct BlueprintLibrary {
    struct Blueprint: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let category: String
        let url: URL
        let phases: [String]
    }

    struct Phase {
        let number: Int
        let name: String
        let description: String
        let color: Color
    }

    static let blueprints: [Blueprint] = [
        Blueprint(
            id: "bb_master",
            title: "Bonds Bounce Blueprint",
            subtitle: "The master overview of the vertical jump architecture.",
            icon: "play.rectangle.fill",
            category: "Master",
            url: SafeURL.make("https://youtu.be/hrlGbS0r-hM"),
            phases: ["Overview", "Architecture", "Progression"]
        ),
        Blueprint(
            id: "bb_overview",
            title: "Bonds Bounce Overview",
            subtitle: "The original vertical jump architecture breakdown.",
            icon: "play.circle.fill",
            category: "Overview",
            url: SafeURL.make("https://youtu.be/dAoLYThf1bc"),
            phases: ["Foundations", "Mechanics", "Application"]
        ),
        Blueprint(
            id: "bb_bodyweight",
            title: "Bodyweight & Mobility",
            subtitle: "Full exercise list with timestamps for structural integrity.",
            icon: "figure.flexibility",
            category: "Mobility",
            url: SafeURL.make("https://youtu.be/q1HLjLbhS2s"),
            phases: ["Ankle Mobility", "Hip Extension", "Structural Balance"]
        ),
        Blueprint(
            id: "bb_plyo",
            title: "Plyometric Exercises",
            subtitle: "Comprehensive reactive power drills with timestamps.",
            icon: "figure.jumprope",
            category: "Power",
            url: SafeURL.make("https://youtu.be/pqyxTY85x4U"),
            phases: ["Reactive Strength", "Depth Jumps", "Bounding"]
        ),
        Blueprint(
            id: "bb_fitness",
            title: "Final Evolution Fitness",
            subtitle: "Master exercise list for the complete training system.",
            icon: "flame.fill",
            category: "Complete",
            url: SafeURL.make("https://youtu.be/J037GG99GT0"),
            phases: ["Strength", "Power", "Speed", "Recovery"]
        ),
    ]

    static let phases: [Phase] = [
        Phase(number: 1, name: "Foundations", description: "Build structural integrity. Ankle stiffness, hip mobility, and ground contact mastery.", color: .green),
        Phase(number: 2, name: "Load", description: "Absorb and redirect force. Eccentric strength and stiffness under load for better RFD.", color: Color(red: 0.3, green: 0.7, blue: 0.4)),
        Phase(number: 3, name: "Launch", description: "Translate load into takeoff. Short ground-contact, high ground reaction force.", color: Color(red: 0.2, green: 0.5, blue: 1.0)),
        Phase(number: 4, name: "Flight", description: "Unlock explosive vertical power through plyometric progressions and neural drive.", color: Color(red: 0.4, green: 0.6, blue: 1.0)),
        Phase(number: 5, name: "Elite", description: "Peak performance. Max-intent jumping, resisted sprints, and pro-level dunk sessions.", color: Color(red: 0.6, green: 0.2, blue: 1.0)),
        Phase(number: 6, name: "Lifelong Mover", description: "Maintain Flight through sustainable movement systems like FRC and GOATA.", color: Color(red: 0.95, green: 0.49, blue: 0.15)),
    ]
}
