import Foundation

// MARK: - Vertical Velocity Academy — 12-Module Educational Blueprint
// CNS Freeway framework; SFMA/FMS as Assessment GPS; clinical/biomechanical tone.
// Modules 11–12: Bio-Molecular Fuel & Supplementing the Sling (nutrition × tools).
// Curriculum-driven, Brain Brawl–aligned.

nonisolated struct VerticalVelocityModule: Identifiable, Sendable, Hashable {
    let id: String
    let number: Int
    let title: String
    let subtitle: String
    let learningObjective: String
    let tools: String
    let correctivePair: String?
    /// Longer lesson body for detail screen.
    let detailBody: String?
    /// Bullet takeaways for detail screen.
    let keyTakeaways: [String]
    /// Optional link to Training (e.g. "Foundations", "Flight").
    let phase: String?
    /// Estimated read/practice minutes.
    let estimatedMinutes: Int?

    init(id: String, number: Int, title: String, subtitle: String, learningObjective: String, tools: String, correctivePair: String? = nil, detailBody: String? = nil, keyTakeaways: [String] = [], phase: String? = nil, estimatedMinutes: Int? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.learningObjective = learningObjective
        self.tools = tools
        self.correctivePair = correctivePair
        self.detailBody = detailBody
        self.keyTakeaways = keyTakeaways
        self.phase = phase
        self.estimatedMinutes = estimatedMinutes
    }

    var displayTitle: String { "Mod \(number): \(title)" }
}

/// Curriculum data is `Sendable`; keep the enum `nonisolated` so lookups work from `nonisolated` decoders without `nonisolated(unsafe)`.
nonisolated enum VerticalVelocityAcademyCurriculum {
    static let modules: [VerticalVelocityModule] = [
        VerticalVelocityModule(
            id: "mod1",
            number: 1,
            title: "The Bio-Electric Freeway",
            subtitle: "CNS, Tensegrity, Roadblock Theory",
            learningObjective: "Frame the CNS as a freeway; adhesions and densification as roadblocks that reduce signal velocity.",
            tools: "No Equipment",
            correctivePair: nil,
            detailBody: "Your central nervous system is the freeway that carries intent from brain to muscle. Tensegrity describes how bones float in a continuous tension network. When fascia densifies or adhesions form—from immobility, inflammation, or overload—they act like roadblocks: signal velocity drops, movement quality suffers, and power leaks. This module establishes the language you'll use for every corrective and drill that follows.",
            keyTakeaways: ["CNS = freeway; adhesions = roadblocks.", "Tensegrity: continuous tension, compression through bones.", "Clear the road to increase signal velocity and power transfer."],
            phase: "Foundations",
            estimatedMinutes: 12
        ),
        VerticalVelocityModule(
            id: "mod2",
            number: 2,
            title: "The Internal GPS",
            subtitle: "SFMA/FMS Step-by-Step",
            learningObjective: "Use SFMA/FMS as diagnostic tools. A Fail = Musculoskeletal Disorder (MSD) or neuromuscular signal roadblock.",
            tools: "No Equipment",
            correctivePair: nil,
            detailBody: "SFMA (Selective Functional Movement Assessment) and FMS (Functional Movement Screen) are your diagnostic GPS. They don't tell you the drill—they tell you where the roadblock is. A clear Fail points to either a Musculoskeletal Disorder (MSD) that needs referral or a neuromuscular roadblock you can address with correctives. Screen first; then clear; then load.",
            keyTakeaways: ["Screen before you load.", "Fail = MSD or neuromuscular roadblock.", "Use correctives to clear before progressing."],
            phase: "Foundations",
            estimatedMinutes: 15
        ),
        VerticalVelocityModule(
            id: "mod3",
            number: 3,
            title: "The Piston",
            subtitle: "IAP: Diaphragm & Pelvic Floor",
            learningObjective: "Cue intra-abdominal pressure and 360° breathing for bracing and power transfer.",
            tools: "No Equipment",
            correctivePair: "Breathing Fail → 90/90 Seated Reset",
            detailBody: "Intra-abdominal pressure (IAP) is the piston that stabilizes the spine and transfers force from legs to arms. 360° breathing—expanding rib cage and belly in all directions—rehydrates fascia and resets the diaphragm. Cue posterior mediastinal expansion (thoracic volume behind the sternum) without hiking shoulders—consistent with FMS breathing-screen standards. When screening reveals a breathing or bracing fail, the 90/90 seated reset is your go-to corrective before loading the system.",
            keyTakeaways: ["IAP = stability and power transfer.", "360° breathing rehydrates fascia.", "90/90 seated reset corrects breathing/bracing fails."],
            phase: "Foundations",
            estimatedMinutes: 14
        ),
        VerticalVelocityModule(
            id: "mod4",
            number: 4,
            title: "The 24/7 Athlete",
            subtitle: "Movement Snacks",
            learningObjective: "Rehydrate fascia and clear roadblocks with seated 90/90s and movement snacks throughout the day.",
            tools: "No Equipment",
            correctivePair: nil,
            detailBody: "Elite output isn't just the hour in the gym—it's what you do the other 23. Movement snacks are short, frequent doses of correctives and mobility (90/90s, hip openers, ankle rocks) that keep the freeway clear. Think of them as clearing roadblocks before they become chronic. The Training tab's Movement Snacks are built from this principle.",
            keyTakeaways: ["Movement snacks = small, frequent correctives.", "90/90s and openers keep fascia hydrated.", "Use the Training tab's Movement Snacks daily."],
            phase: "Foundations",
            estimatedMinutes: 10
        ),
        VerticalVelocityModule(
            id: "mod5",
            number: 5,
            title: "Anatomy of the Sling",
            subtitle: "Spiral, Front & Back Functional Lines",
            learningObjective: "3D view of muscle slings (Spiral, Front Functional, Back) for jump and run mechanics.",
            tools: "No Equipment",
            correctivePair: nil,
            detailBody: "Jump and run don't happen in single muscles—they happen along slings. The Spiral Line wraps from foot through trunk to opposite shoulder; the Front and Back Functional Lines drive stride and arm swing. Understanding these lines helps you cue and correct: a leak in the spiral shows up as rotation or arm-path issues; a stiff back functional line limits extension.",
            keyTakeaways: ["Movement happens along slings, not single muscles.", "Spiral, Front and Back Functional Lines drive jump and run.", "Leaks show as rotation, arm path, or extension limits."],
            phase: "Foundations",
            estimatedMinutes: 18
        ),
        VerticalVelocityModule(
            id: "mod6",
            number: 6,
            title: "Clearing the Path",
            subtitle: "NMS Correctives",
            learningObjective: "GFR and Isometric Split Stance Wall Pushes to clear neuromuscular roadblocks.",
            tools: "No Equipment",
            correctivePair: "Rotation Fail → Isometric Wall Push",
            detailBody: "Neuromuscular roadblocks need neuromuscular correctives. Global Functional Range (GFR) progressions and Isometric Split Stance Wall Pushes target rotation and stability fails without adding load. When your screen says rotation fail, the isometric wall push is your first tool. Clear the path before you add speed or load.",
            keyTakeaways: ["NMS correctives clear roadblocks without load.", "Rotation fail → Isometric Wall Push.", "GFR progressions build capacity before intensity."],
            phase: "Foundations",
            estimatedMinutes: 16
        ),
        VerticalVelocityModule(
            id: "mod7",
            number: 7,
            title: "The Loaded Spring",
            subtitle: "Overcoming ISOs",
            learningObjective: "PJF Band and Total Body Board for overcoming isometrics and elastic readiness.",
            tools: "PJF Extended Band, Total Body Board (TBB)",
            correctivePair: nil,
            detailBody: "The body is a loaded spring: store energy in the eccentric, release in the concentric. PJF Band overcoming isometrics and Total Body Board (TBB) progressions build stiffness and elastic readiness without the impact of jumping. You're teaching the system to accept load and return it—the foundation for reactive plyometrics.",
            keyTakeaways: ["Overcoming isometrics build stiffness and readiness.", "PJF Band and TBB are your primary tools.", "Store and return load before adding jump volume."],
            phase: "Load",
            estimatedMinutes: 20
        ),
        VerticalVelocityModule(
            id: "mod8",
            number: 8,
            title: "The Rhythmic Penultimate",
            subtitle: "RFD & Push 1, 2",
            learningObjective: "Rate of force development and 'Push 1, 2' rhythmic cueing for the penultimate step.",
            tools: "No Equipment, TBB",
            correctivePair: "Ankle Fail → Low Anchor PJF Band Ankle Anchors",
            detailBody: "Rate of force development (RFD) is how fast you can produce force. The penultimate step is where you set the spring; 'Push 1, 2' is a rhythmic cue that syncs the last two steps and arm swing. Ankle stiffness is non-negotiable—if screening shows ankle fail, low-anchor PJF Band ankle work comes before you chase more air time.",
            keyTakeaways: ["RFD = speed of force production.", "Penultimate step sets the spring; cue Push 1, 2.", "Ankle fail → PJF Band ankle anchors first."],
            phase: "Launch",
            estimatedMinutes: 18
        ),
        VerticalVelocityModule(
            id: "mod9",
            number: 9,
            title: "The Elastic Engine",
            subtitle: "Tiered Plyometrics — Extensive to Deep",
            learningObjective: "Extensive to reactive plyometrics; progress from low to high demand.",
            tools: "No Equipment, TBB",
            correctivePair: nil,
            detailBody: "Plyometrics aren't one bucket—they're tiered. Extensive work (low intensity, more contacts) builds work capacity and tissue readiness; reactive work (short ground contact, max intent) trains the elastic system. Progress from extensive to reactive only after the freeway is clear and the spring is loaded. Your Training Flight track follows this progression.",
            keyTakeaways: ["Extensive first, then reactive.", "Short ground contact + max intent = reactive.", "Match plyometric volume to your cleared capacity."],
            phase: "Flight",
            estimatedMinutes: 22
        ),
        VerticalVelocityModule(
            id: "mod10",
            number: 10,
            title: "The Flight Blueprint",
            subtitle: "Programming, TBB, Approach Variations",
            learningObjective: "Program design, TBB logic, and approach variations for competition.",
            tools: "TBB, PJF Band",
            correctivePair: nil,
            detailBody: "Programming ties everything together: correctives and mobility, then strength and stiffness, then plyometrics and approach work. TBB progressions and approach variations (one-step, two-step, full approach) let you periodize for competition. Your System Scan and recommended track in the Lab drive which phase you're in—Foundations, Flight, or Elite.",
            keyTakeaways: ["Correctives → stiffness → plyos → approach.", "TBB and approach progressions are periodized.", "Use your PRQ and recommended track to choose phase."],
            phase: "Flight",
            estimatedMinutes: 25
        ),
        VerticalVelocityModule(
            id: "mod11",
            number: 11,
            title: "The Bio-Molecular Fuel",
            subtitle: "Systemic Inflammation & Fascial Glue",
            learningObjective: "Understand how systemic inflammation creates fascial glue and roadblocks on the Bio-Electric Freeway; nutrition as high-grade fuel.",
            tools: "No Equipment",
            correctivePair: nil,
            detailBody: "Systemic inflammation doesn't just hurt—it glues fascia. Sugar, processed foods, and poor sleep add roadblocks to the freeway regardless of how well you train. Nutrition is high-grade fuel: anti-inflammatory foods, timing around sessions, and hydration support tissue quality and recovery. Clear the molecular roadblocks so the mechanical work can land.",
            keyTakeaways: ["Inflammation = fascial glue and roadblocks.", "Nutrition = fuel quality and recovery.", "Clear molecular roadblocks for mechanical gains."],
            phase: nil,
            estimatedMinutes: 14
        ),
        VerticalVelocityModule(
            id: "mod12",
            number: 12,
            title: "Supplementing the Sling",
            subtitle: "PJF/TBB + Nutritional Timing for RFD",
            learningObjective: "Use PJF and TBB tools in tandem with specific nutritional timing for maximum Rate of Force Development and elastic readiness.",
            tools: "PJF Band, TBB",
            correctivePair: nil,
            detailBody: "Supplements and timing can support RFD and readiness—caffeine, creatine, and peri-workout nutrition are evidence-based tools. They don't replace the freeway work; they support it. Use them in tandem with your PJF and TBB sessions so the sling is fueled and the nervous system is ready when you train.",
            keyTakeaways: ["Timing and supplements support RFD and readiness.", "Caffeine, creatine, peri-workout nutrition are tools.", "Fuel the sling; don't replace correctives with supplements."],
            phase: nil,
            estimatedMinutes: 12
        ),
    ]

    static func module(id: String) -> VerticalVelocityModule? {
        modules.first { $0.id == id }
    }
}
