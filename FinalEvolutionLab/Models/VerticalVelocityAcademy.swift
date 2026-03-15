import Foundation

// MARK: - Vertical Velocity Academy — 12-Module Educational Blueprint
// CNS Freeway framework; SFMA/FMS as Assessment GPS; clinical/biomechanical tone.
// Modules 11–12: Bio-Molecular Fuel & Supplementing the Sling (nutrition × tools).
// Big Brain Academy × Coursebox: curriculum-driven, Brain Brawl–aligned.

nonisolated struct VerticalVelocityModule: Identifiable, Sendable {
    let id: String
    let number: Int
    let title: String
    let subtitle: String
    let learningObjective: String
    let tools: String // e.g. "No Equipment", "PJF Band", "TBB"
    let correctivePair: String? // e.g. "Rotation Fail → Isometric Wall Push"

    var displayTitle: String { "Mod \(number): \(title)" }
}

enum VerticalVelocityAcademyCurriculum {
    static let modules: [VerticalVelocityModule] = [
        VerticalVelocityModule(
            id: "mod1",
            number: 1,
            title: "The Bio-Electric Freeway",
            subtitle: "CNS, Tensegrity, Roadblock Theory",
            learningObjective: "Frame the CNS as a freeway; adhesions and densification as roadblocks that reduce signal velocity.",
            tools: "No Equipment",
            correctivePair: nil
        ),
        VerticalVelocityModule(
            id: "mod2",
            number: 2,
            title: "The Internal GPS",
            subtitle: "SFMA/FMS Step-by-Step",
            learningObjective: "Use SFMA/FMS as diagnostic tools. A Fail = Musculoskeletal Disorder (MSD) or neuromuscular signal roadblock.",
            tools: "No Equipment",
            correctivePair: nil
        ),
        VerticalVelocityModule(
            id: "mod3",
            number: 3,
            title: "The Piston",
            subtitle: "IAP: Diaphragm & Pelvic Floor",
            learningObjective: "Cue intra-abdominal pressure and 360° breathing for bracing and power transfer.",
            tools: "No Equipment",
            correctivePair: "Breathing Fail → 90/90 Seated Reset"
        ),
        VerticalVelocityModule(
            id: "mod4",
            number: 4,
            title: "The 24/7 Athlete",
            subtitle: "Movement Snacks",
            learningObjective: "Rehydrate fascia and clear roadblocks with seated 90/90s and movement snacks throughout the day.",
            tools: "No Equipment",
            correctivePair: nil
        ),
        VerticalVelocityModule(
            id: "mod5",
            number: 5,
            title: "Anatomy of the Sling",
            subtitle: "Spiral, Front & Back Functional Lines",
            learningObjective: "3D view of muscle slings (Spiral, Front Functional, Back) for jump and run mechanics.",
            tools: "No Equipment",
            correctivePair: nil
        ),
        VerticalVelocityModule(
            id: "mod6",
            number: 6,
            title: "Clearing the Path",
            subtitle: "NMS Correctives",
            learningObjective: "GFR and Isometric Split Stance Wall Pushes to clear neuromuscular roadblocks.",
            tools: "No Equipment",
            correctivePair: "Rotation Fail → Isometric Wall Push"
        ),
        VerticalVelocityModule(
            id: "mod7",
            number: 7,
            title: "The Loaded Spring",
            subtitle: "Overcoming ISOs",
            learningObjective: "PJF Band and Total Body Board for overcoming isometrics and elastic readiness.",
            tools: "PJF Extended Band, Total Body Board (TBB)",
            correctivePair: nil
        ),
        VerticalVelocityModule(
            id: "mod8",
            number: 8,
            title: "The Rhythmic Penultimate",
            subtitle: "RFD & Push 1, 2",
            learningObjective: "Rate of force development and 'Push 1, 2' rhythmic cueing for the penultimate step.",
            tools: "No Equipment, TBB",
            correctivePair: "Ankle Fail → Low Anchor PJF Band Ankle Anchors"
        ),
        VerticalVelocityModule(
            id: "mod9",
            number: 9,
            title: "The Elastic Engine",
            subtitle: "Watson's Tiered Plyometrics",
            learningObjective: "Extensive to reactive plyometrics; progress from low to high demand.",
            tools: "No Equipment, TBB",
            correctivePair: nil
        ),
        VerticalVelocityModule(
            id: "mod10",
            number: 10,
            title: "The Flight Blueprint",
            subtitle: "Programming, TBB, Approach Variations",
            learningObjective: "Program design, TBB logic, and approach variations for competition.",
            tools: "TBB, PJF Band",
            correctivePair: nil
        ),
        VerticalVelocityModule(
            id: "mod11",
            number: 11,
            title: "The Bio-Molecular Fuel",
            subtitle: "Systemic Inflammation & Fascial Glue",
            learningObjective: "Understand how systemic inflammation creates fascial glue and roadblocks on the Bio-Electric Freeway; nutrition as high-grade fuel.",
            tools: "No Equipment",
            correctivePair: nil
        ),
        VerticalVelocityModule(
            id: "mod12",
            number: 12,
            title: "Supplementing the Sling",
            subtitle: "PJF/TBB + Nutritional Timing for RFD",
            learningObjective: "Use PJF and TBB tools in tandem with specific nutritional timing for maximum Rate of Force Development and elastic readiness.",
            tools: "PJF Band, TBB",
            correctivePair: nil
        ),
    ]

    static func module(id: String) -> VerticalVelocityModule? {
        modules.first { $0.id == id }
    }
}
