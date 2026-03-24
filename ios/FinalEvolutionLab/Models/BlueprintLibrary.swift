import SwiftUI

struct BlueprintLibrary {
    struct Blueprint: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let category: String
        let referenceURL: String
        let phases: [String]
        let allowsExternalOpen: Bool
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
            referenceURL: "https://youtu.be/hrlGbS0r-hM",
            phases: ["Overview", "Architecture", "Progression"],
            allowsExternalOpen: false
        ),
        Blueprint(
            id: "bb_overview",
            title: "Bonds Bounce Overview",
            subtitle: "The original vertical jump architecture breakdown.",
            icon: "play.circle.fill",
            category: "Overview",
            referenceURL: "https://youtu.be/dAoLYThf1bc",
            phases: ["Foundations", "Mechanics", "Application"],
            allowsExternalOpen: false
        ),
        Blueprint(
            id: "bb_bodyweight",
            title: "Bodyweight & Mobility",
            subtitle: "Full exercise list with timestamps for structural integrity.",
            icon: "figure.flexibility",
            category: "Mobility",
            referenceURL: "https://youtu.be/q1HLjLbhS2s",
            phases: ["Ankle Mobility", "Hip Extension", "Structural Balance"],
            allowsExternalOpen: false
        ),
        Blueprint(
            id: "bb_plyo",
            title: "Plyometric Exercises",
            subtitle: "Comprehensive reactive power drills with timestamps.",
            icon: "figure.jumprope",
            category: "Power",
            referenceURL: "https://youtu.be/pqyxTY85x4U",
            phases: ["Reactive Strength", "Depth Jumps", "Bounding"],
            allowsExternalOpen: false
        ),
        Blueprint(
            id: "bb_fitness",
            title: "Final Evolution Fitness",
            subtitle: "Master exercise list for the complete training system.",
            icon: "flame.fill",
            category: "Complete",
            referenceURL: "https://youtu.be/J037GG99GT0",
            phases: ["Strength", "Power", "Speed", "Recovery"],
            allowsExternalOpen: false
        ),
    ]

    static let phases: [Phase] = [
        Phase(number: 1, name: "Foundations", description: "Build structural integrity. Ankle stiffness, hip mobility, and ground contact mastery.", color: .green),
        Phase(number: 2, name: "Flight", description: "Unlock explosive vertical power through plyometric progressions and neural drive.", color: Color(red: 0.2, green: 0.5, blue: 1.0)),
        Phase(number: 3, name: "Elite", description: "Peak performance. Max-intent jumping, resisted sprints, and pro-level dunk sessions.", color: Color(red: 0.6, green: 0.2, blue: 1.0)),
        Phase(number: 4, name: "Lifelong Mover", description: "Maintain Flight through sustainable movement systems like FRC and GOATA.", color: Color(red: 0.95, green: 0.49, blue: 0.15)),
    ]
}
