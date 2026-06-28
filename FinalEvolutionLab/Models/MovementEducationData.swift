import Foundation

nonisolated struct BioDigitalModule: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let learningObjectives: [String]  // Exactly 5
    let masteryThreshold: Double      // 0.80 for all modules
    var isCompleted: Bool
    var masteryScore: Double?         // Score when completed

    init(id: String, title: String, learningObjectives: [String], masteryThreshold: Double = 0.80) {
        self.id = id
        self.title = title
        self.learningObjectives = learningObjectives
        self.masteryThreshold = masteryThreshold
        self.isCompleted = false
        self.masteryScore = nil
    }
}

enum BioDigitalModuleLibrary {
    static let skeletalBasics = BioDigitalModule(
        id: "skeletal_basics",
        title: "Skeletal Anatomy Fundamentals",
        learningObjectives: [
            "Identify the major bones of the axial and appendicular skeleton",
            "Understand the role of bone density in athletic performance",
            "Recognize common injury sites and their skeletal causes",
            "Describe joint types and their range of motion characteristics",
            "Apply skeletal anatomy knowledge to sport-specific movement analysis"
        ]
    )

    static let muscularChains = BioDigitalModule(
        id: "muscular_chains",
        title: "Muscular Chain Systems",
        learningObjectives: [
            "Identify the anterior, posterior, lateral, and spiral muscular chains",
            "Understand the principle of myofascial force transmission",
            "Recognize how muscular imbalances affect movement efficiency",
            "Apply chain activation sequencing to explosive athletic movements",
            "Assess muscular chain integrity through functional movement screening"
        ]
    )

    static let kineticChainPillars = BioDigitalModule(
        id: "kinetic_chain_pillars",
        title: "Kinetic Chain Pillars",
        learningObjectives: [
            "Define the open and closed kinetic chain concepts in sport",
            "Explain proximal-to-distal sequencing in throwing and striking",
            "Identify the three pillars: mobility, stability, and strength integration",
            "Analyze kinetic chain breakdowns that lead to injury patterns",
            "Design corrective exercises targeting specific kinetic chain weaknesses"
        ]
    )

    static let neuralPriming = BioDigitalModule(
        id: "neural_priming",
        title: "Neural Priming Protocols",
        learningObjectives: [
            "Understand the role of the central nervous system in motor learning",
            "Explain post-activation potentiation (PAP) and its training applications",
            "Identify neural fatigue markers and recovery indicators",
            "Apply pre-performance neural priming sequences for power output",
            "Design warm-up protocols that optimize neural drive for competition"
        ]
    )

    static let all: [BioDigitalModule] = [
        skeletalBasics, muscularChains, kineticChainPillars, neuralPriming
    ]

    static func module(for id: String) -> BioDigitalModule? {
        all.first { $0.id == id }
    }
}

extension TrainingProgramData {

    // MARK: - Movement Education Programs

    static let meFoundationsProgram = TrainingProgram(
        id: "me_foundations", track: .foundations, equipment: .movementEducation, weeks: 6, days: meFoundationsDays
    )
    static let meFlightProgram = TrainingProgram(
        id: "me_flight", track: .flight, equipment: .movementEducation, weeks: 8, days: meFlightDays
    )
    static let meEliteProgram = TrainingProgram(
        id: "me_elite", track: .elite, equipment: .movementEducation, weeks: 12, days: meEliteDays
    )

    // MARK: - Foundations Days (Sensory Education & Basic Patterns)

    static let meFoundationsDays: [TrainingDay] = [
        TrainingDay(
            id: "me_f_d1", dayNumber: 1, variant: "A", title: "Movement Education & Sensory",
            category: .movementEducation,
            warmUp: [
                tex("me_f_w1", "Dynamic Stretching", 1, "5-10 min", 0, .mobility, ["Full Body"], "Hip openers, arm swings, thoracic rotations"),
                tex("me_f_w2", "Foot Tripod Sensory Education", 2, "30s each foot", 20, .mobility, ["Feet", "Ankles"], "Feel big toe, little toe, heel — shift pressure between all three points consciously"),
            ],
            mainWork: [
                tex("me_f_d1_1", "Staggered Stance + Rotation", 3, "8 each", 45, .strength, ["Core", "Hips", "Thoracic Spine"], "Cue pressure redistribution through foot tripod as you rotate — feel weight shift from heel to forefoot"),
                tex("me_f_d1_2", "Front Foot Elevated + Rotation", 3, "6 each", 45, .mobility, ["Hip Flexors", "Thoracic Spine", "Ankles"], "Elevate front foot, rotate torso over front hip — maintain tripod contact throughout"),
                tex("me_f_d1_3", "Rear Foot Elevated + Rotation", 3, "6 each", 45, .mobility, ["Hip Flexors", "Quads", "Core"], "Rear foot on step, rotate over front leg — feel pressure shift in front foot"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_f_d2", dayNumber: 2, variant: "A", title: "Strength & Stability",
            category: .strength,
            warmUp: [
                tex("me_f_w3", "Bodyweight Squats", 2, "10-15", 30, .strength, ["Quads", "Glutes"], "Full depth, maintain foot tripod pressure, control tempo"),
                tex("me_f_w4", "Dynamic Lunges", 2, "10 each", 30, .strength, ["Quads", "Glutes", "Hip Flexors"], "Alternate legs, drive through front heel"),
            ],
            mainWork: [
                tex("me_f_d2_1", "RDL Foot to Wall + Rotation", 3, "8 each", 60, .strength, ["Hamstrings", "Glutes", "Core"], "Hinge with foot pressing into wall behind, add thoracic rotation at bottom"),
                texLeveled("me_f_d2_2", "Long Lever Hamstring Iso", 3, "20-30s each", 60, .strength, ["Hamstrings"], "Extend leg long, hold at max tolerable length — progress through levels"),
                tex("me_f_d2_3", "Isometric Full Body Hold (Plank)", 3, "30-45s", 45, .strength, ["Core", "Shoulders", "Glutes"], "Brace everything, breathe through the hold"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_f_d3", dayNumber: 3, variant: "A", title: "Plyometrics & Agility",
            category: .plyometrics,
            warmUp: [
                tex("me_f_w5", "High Knees", 2, "30s", 20, .agility, ["Hip Flexors", "Calves"], "Drive knees high, quick ground contact"),
                tex("me_f_w6", "Butt Kicks", 2, "30s", 20, .agility, ["Hamstrings", "Quads"], "Quick heel-to-glute tempo"),
            ],
            mainWork: [
                tex("me_f_d3_1", "Progressed Plyometrics (Tuck Jumps)", 3, "6-8", 75, .plyometric, ["Quads", "Calves", "Core"], "Drive knees to chest, land soft with tripod foot contact"),
                tex("me_f_d3_2", "Regressed Plyometrics (Squat Jumps)", 3, "8-10", 60, .plyometric, ["Quads", "Glutes"], "Quarter squat to vertical jump, focus on landing mechanics"),
                tex("me_f_d3_3", "Lateral Bounds", 3, "6 each", 75, .plyometric, ["Hip Abductors", "Quads"], "Max distance, stick landing on foot tripod for 2s"),
                tex("me_f_d3_4", "Rotational Hops (Both Ways)", 3, "6 each", 60, .plyometric, ["Core", "Quads", "Ankles"], "90° rotation mid-air, land with pressure redistribution cue"),
                tex("me_f_d3_5", "Single-Leg Balance with Rotation", 3, "8 each", 45, .mobility, ["Ankles", "Core", "Hips"], "Stand on one leg, rotate torso — feel tripod pressure shift"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_f_d4", dayNumber: 4, variant: "A", title: "Recovery & Isometrics",
            category: .recoveryIso,
            warmUp: [
                tex("me_f_w7", "Foam Rolling / Soft Tissue Work", 1, "5-10 min", 0, .recovery, ["Full Body"], "Roll quads, hamstrings, calves, IT band — moderate pressure"),
                tex("me_f_w8", "Gentle Stretching Routine", 1, "5-10 min", 0, .mobility, ["Hips", "Hamstrings"], "Hold each stretch 30s, breathe into tight areas"),
            ],
            mainWork: [
                tex("me_f_d4_1", "Side-Lying Leg Lifts", 3, "12 each", 30, .strength, ["Hip Abductors", "Glutes"], "Slow, controlled lifts — maintain hip stack"),
                tex("me_f_d4_2", "Wall Sit", 3, "30-45s", 45, .strength, ["Quads", "Core"], "Back flat against wall, thighs parallel, feel tripod pressure in feet"),
                tex("me_f_d4_3", "Glute Bridge Hold", 3, "20-30s", 30, .strength, ["Glutes", "Hamstrings"], "Drive through heels, squeeze at top, maintain position"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_f_d5", dayNumber: 5, variant: "A", title: "Movement Control",
            category: .movementEducation,
            warmUp: [
                tex("me_f_w9", "Arm Circles + Leg Swings", 1, "5 min", 0, .mobility, ["Shoulders", "Hips"], "Gradually increase range, forward and backward"),
            ],
            mainWork: [
                tex("me_f_d5_1", "Walking Lunges with Rotation", 3, "10 each", 45, .strength, ["Quads", "Core", "Thoracic Spine"], "Rotate torso over front leg at bottom of each lunge"),
                tex("me_f_d5_2", "Foot Tripod Pressure Mapping", 2, "60s each foot", 20, .mobility, ["Feet", "Ankles"], "Stand single-leg, consciously shift weight between big toe, little toe, heel — map your balance"),
                tex("me_f_d5_3", "Staggered Stance Reaches (3-Way)", 3, "8 each direction", 45, .mobility, ["Hips", "Ankles", "Core"], "Forward, lateral, rotational reaches from staggered stance — track pressure redistribution"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - Flight Days (Plyometrics & Dynamic Movements)

    static let meFlightDays: [TrainingDay] = [
        TrainingDay(
            id: "me_fl_d1", dayNumber: 1, variant: "A", title: "Dynamic Movement Education",
            category: .movementEducation,
            warmUp: [
                tex("me_fl_w1", "Foot Tripod Activation (Progressive)", 2, "30s each foot", 20, .mobility, ["Feet", "Ankles"], "Single-leg tripod hold, progress to eyes closed"),
                tex("me_fl_w2", "Dynamic Lunges with Arm Reach", 2, "10 each", 30, .mobility, ["Full Body"], "Lunge and reach overhead/lateral to prime rotation"),
            ],
            mainWork: [
                tex("me_fl_d1_1", "Staggered Stance + Rotation (Speed)", 3, "10 each", 45, .strength, ["Core", "Hips"], "Faster tempo rotation with maintained tripod contact"),
                tex("me_fl_d1_2", "Front Foot Elevated + Rotation (Deep)", 3, "8 each", 45, .mobility, ["Hip Flexors", "Thoracic Spine"], "Greater elevation, deeper rotation range"),
                tex("me_fl_d1_3", "Rear Foot Elevated + Rotation (Loaded)", 3, "8 each", 60, .strength, ["Quads", "Core", "Hip Flexors"], "Add arm drivers for load — reach and rotate"),
                tex("me_fl_d1_4", "Pressure Shift Lateral Lunges", 3, "8 each", 45, .strength, ["Adductors", "Quads", "Hips"], "Lateral lunge — consciously shift pressure from heel to forefoot as you drive back"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_fl_d2", dayNumber: 2, variant: "A", title: "Explosive Strength",
            category: .strength,
            warmUp: [
                tex("me_fl_w3", "Bodyweight Squats (Tempo)", 2, "12", 30, .strength, ["Quads", "Glutes"], "3s down, 1s pause, explode up"),
                tex("me_fl_w4", "Inchworms", 2, "8", 30, .mobility, ["Hamstrings", "Shoulders", "Core"], "Walk hands out to plank, walk feet in"),
            ],
            mainWork: [
                tex("me_fl_d2_1", "RDL Foot to Wall + Rotation (Tempo)", 3, "8 each", 75, .strength, ["Hamstrings", "Glutes", "Core"], "Slow 3s eccentric hinge, rotate, drive up explosively"),
                texLeveled("me_fl_d2_2", "Long Lever Hamstring Iso (Extended)", 3, "30s each", 60, .strength, ["Hamstrings"], "Extended hold at end range — progress through levels"),
                tex("me_fl_d2_3", "Single-Leg Glute Bridge", 3, "10 each", 60, .strength, ["Glutes", "Hamstrings", "Core"], "Drive through heel, maintain level hips"),
                tex("me_fl_d2_4", "Push-Up to Rotation", 3, "8 each", 60, .strength, ["Chest", "Core", "Shoulders"], "Push up then rotate to T-position, reach skyward"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_fl_d3", dayNumber: 3, variant: "A", title: "Plyometrics & Rotation",
            category: .plyometrics,
            warmUp: [
                tex("me_fl_w5", "A-Skips", 2, "20m", 30, .agility, ["Hip Flexors", "Calves"], "Drive knee high, quick ground contact"),
                tex("me_fl_w6", "Lateral Shuffles", 2, "20m each", 30, .agility, ["Hip Abductors", "Quads"], "Stay low, quick lateral movement"),
            ],
            mainWork: [
                tex("me_fl_d3_1", "Depth Drop to Stick (Tripod Focus)", 3, "6", 90, .plyometric, ["Quads", "Calves"], "Step off elevation, absorb and freeze — feel all three tripod points on landing"),
                tex("me_fl_d3_2", "Rotational Hops (Progressive)", 3, "8 each", 75, .plyometric, ["Core", "Quads", "Ankles"], "Progress from 90° to 180° rotation, maintain tripod landing"),
                tex("me_fl_d3_3", "Split Squat Jumps", 3, "6 each", 75, .plyometric, ["Quads", "Glutes"], "Explode from split stance, switch legs mid-air, land with control"),
                tex("me_fl_d3_4", "Lateral Bounds to Rotation", 3, "6 each", 90, .plyometric, ["Full Body"], "Lateral bound then immediately rotate 90° on landing leg"),
                tex("me_fl_d3_5", "Continuous Hops (Tripod)", 3, "30s", 45, .plyometric, ["Calves", "Ankles"], "Quick continuous hops — maintain foot tripod on every contact"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_fl_d4", dayNumber: 4, variant: "A", title: "Recovery & Isometrics",
            category: .recoveryIso,
            warmUp: [
                tex("me_fl_w7", "Foam Rolling", 1, "5 min", 0, .recovery, ["Full Body"], "Quads, hamstrings, calves, thoracic — moderate pressure"),
            ],
            mainWork: [
                tex("me_fl_d4_1", "Side-Lying Breathing Corrective", 2, "60s each", 30, .recovery, ["Core", "Diaphragm"], "4s inhale, 6s exhale — feel rib expansion laterally"),
                texLeveled("me_fl_d4_2", "Maximal Yielding Hamstring Iso", 3, "30s each", 45, .strength, ["Hamstrings"], "Hold at longest tolerable length — progress through levels"),
                tex("me_fl_d4_3", "Standing 4-Way Hip Iso", 3, "20s each direction", 30, .strength, ["Hips", "Glutes"], "Press into wall in all 4 directions with max effort"),
                tex("me_fl_d4_4", "Foot Tripod Single-Leg Iso", 2, "30s each", 30, .mobility, ["Feet", "Ankles", "Core"], "Single-leg stand, consciously maintain equal tripod pressure"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_fl_d5", dayNumber: 5, variant: "A", title: "Movement Integration",
            category: .movementEducation,
            warmUp: [
                tex("me_fl_w8", "Arm Circles + Hip Circles", 1, "5 min", 0, .mobility, ["Shoulders", "Hips"], "Large circles both directions, increasing range"),
            ],
            mainWork: [
                tex("me_fl_d5_1", "Walking Lunges with Rotation (Tempo)", 3, "10 each", 45, .strength, ["Quads", "Core", "Thoracic Spine"], "Slower tempo, deeper rotation, track pressure shift"),
                tex("me_fl_d5_2", "Bear Crawl (Forward + Backward)", 3, "20m each", 60, .agility, ["Core", "Shoulders", "Hips"], "Knees 1 inch off ground, slow and controlled"),
                tex("me_fl_d5_3", "Single-Leg RDL with Rotation", 3, "8 each", 60, .strength, ["Hamstrings", "Glutes", "Core"], "Hinge on one leg, rotate torso at bottom — feel tripod shift"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - Elite Days (Advanced Strength & Movement Control)

    static let meEliteDays: [TrainingDay] = [
        TrainingDay(
            id: "me_e_d1", dayNumber: 1, variant: "A", title: "Advanced Movement Education",
            category: .movementEducation,
            warmUp: [
                tex("me_e_w1", "Foot Tripod Reactive Drill", 2, "30s each foot", 20, .mobility, ["Feet", "Ankles"], "Single-leg tripod hold with partner perturbation or self-induced sway"),
                tex("me_e_w2", "Multi-Plane Dynamic Warm Up", 2, "5 min", 30, .mobility, ["Full Body"], "Sagittal, frontal, transverse plane movements — world's greatest stretch flow"),
            ],
            mainWork: [
                tex("me_e_d1_1", "Staggered Stance + Rotation (Reactive)", 3, "10 each", 45, .strength, ["Core", "Hips"], "Max speed rotation with unpredictable direction cues"),
                tex("me_e_d1_2", "Front Foot Elevated + Multi-Reach Rotation", 3, "8 each", 60, .mobility, ["Hip Flexors", "Thoracic Spine"], "Elevate front foot, rotate and reach in 3 different planes"),
                tex("me_e_d1_3", "Rear Foot Elevated + Rotation (Explosive)", 3, "8 each", 60, .strength, ["Quads", "Core", "Hip Flexors"], "Add explosive drive from bottom position with rotation"),
                tex("me_e_d1_4", "Pressure Redistribution Flow", 3, "60s each foot", 30, .mobility, ["Feet", "Ankles", "Core"], "Single-leg: shift through heel-dominant → toe-dominant → lateral → medial in continuous flow"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_e_d2", dayNumber: 2, variant: "A", title: "Max Strength (Bodyweight)",
            category: .strength,
            warmUp: [
                tex("me_e_w3", "CNS Activation", 2, "3 min", 60, .plyometric, ["Full Body"], "Tuck jumps, clap push-ups, A-skips — prime the nervous system"),
            ],
            mainWork: [
                tex("me_e_d2_1", "Single-Leg RDL with Rotation (Tempo)", 3, "6 each", 75, .strength, ["Hamstrings", "Glutes", "Core"], "Slow 3s eccentric, rotate at bottom, drive up explosively"),
                texLeveled("me_e_d2_2", "Long Lever Hamstring Iso (Tripod Focus)", 3, "30s each", 60, .strength, ["Hamstrings"], "Extended hold with conscious foot tripod engagement — progress through levels"),
                tex("me_e_d2_3", "Pistol Squat Progressions", 3, "5 each", 90, .strength, ["Quads", "Glutes", "Core"], "Assisted → eccentric-only → full — maintain tripod contact throughout"),
                tex("me_e_d2_4", "Rotational Split Squats", 3, "8 each", 60, .strength, ["Quads", "Core", "Hips"], "Deep split squat with torso rotation, feel pressure redistribution in front foot"),
                tex("me_e_d2_5", "Planche Lean Push-Ups", 3, "8", 60, .strength, ["Shoulders", "Core", "Chest"], "Lean forward past hands, push up maintaining forward lean"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_e_d3", dayNumber: 3, variant: "A", title: "Advanced Plyometrics",
            category: .plyometrics,
            warmUp: [
                tex("me_e_w4", "Sprint Build-Ups", 3, "40m", 60, .agility, ["Full Body"], "70-80-90% progressive sprints"),
                tex("me_e_w5", "Lateral Bounds (Max)", 3, "6 each", 45, .plyometric, ["Full Body"], "Max distance, tripod landing, stick 2s"),
            ],
            mainWork: [
                tex("me_e_d3_1", "Depth Jumps (Reactive)", 4, "5", 120, .plyometric, ["Quads", "Calves", "Glutes"], "Step off elevation, minimize ground contact, explode to max height"),
                tex("me_e_d3_2", "Rotational Box Jumps", 3, "6-8", 90, .plyometric, ["Full Body"], "Jump with 90° rotation, land on top with tripod foot contact"),
                tex("me_e_d3_3", "Continuous Bounds", 3, "20m", 90, .plyometric, ["Full Body"], "Alternating single-leg bounds, max distance each contact"),
                tex("me_e_d3_4", "Lateral Bound to Rotational Hop", 3, "6 each", 90, .plyometric, ["Full Body"], "Bound laterally, immediately rotate 180° and stick"),
                tex("me_e_d3_5", "Neural Drive Sprints", 4, "20m", 120, .agility, ["Full Body"], "Maximum recruitment, full effort, track performance"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "me_e_d4", dayNumber: 4, variant: "A", title: "Recovery & Isometrics",
            category: .recoveryIso,
            warmUp: [
                tex("me_e_w6", "Foam Rolling (Deep)", 1, "10 min", 0, .recovery, ["Full Body"], "Extended rolling session — quads, hamstrings, calves, thoracic, lats"),
            ],
            mainWork: [
                tex("me_e_d4_1", "Side Lying Breathing Corrective", 2, "90s each", 30, .recovery, ["Core", "Diaphragm"], "Deep diaphragmatic breathing for CNS downregulation"),
                texLeveled("me_e_d4_2", "Maximal Yielding Hamstring Iso", 3, "45s each", 60, .strength, ["Hamstrings"], "Extended hold at end range — progress through levels"),
                tex("me_e_d4_3", "Standing 4-Way Hip Iso (Max Effort)", 3, "25s each", 45, .strength, ["Hips", "Glutes"], "Maximum effort isometric in all 4 directions"),
                tex("me_e_d4_4", "Tripod Pressure Mapping (Reactive)", 2, "60s each foot", 30, .mobility, ["Feet", "Ankles"], "Single-leg, eyes closed, react to perturbations while maintaining tripod"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "me_e_d5", dayNumber: 5, variant: "A", title: "Elite Movement Integration",
            category: .movementEducation,
            warmUp: [
                tex("me_e_w7", "Movement Flow Warm Up", 1, "5 min", 0, .mobility, ["Full Body"], "Inchworm → world's greatest stretch → cossack squat flow"),
            ],
            mainWork: [
                tex("me_e_d5_1", "Single-Leg RDL to Rotational Hop", 3, "6 each", 90, .plyometric, ["Full Body"], "Hinge, rotate, then explosively hop with rotation — land on tripod"),
                tex("me_e_d5_2", "Walking Lunge Complex (Rotation + Reach + Hop)", 3, "8 each", 75, .strength, ["Full Body"], "Lunge → rotate → overhead reach → drive knee to hop"),
                tex("me_e_d5_3", "Pressure Flow Sequence", 3, "90s each foot", 30, .mobility, ["Feet", "Ankles", "Core"], "Single-leg: heel-dominant squat → toe-dominant calf raise → lateral tilt → medial arch press in continuous flow"),
                tex("me_e_d5_4", "Max Vertical Testing", 3, "3", 120, .plyometric, ["Full Body"], "Full approach, max effort vertical — apply all movement education principles"),
            ],
            isGated: true, isCompleted: false
        ),
    ]
}
