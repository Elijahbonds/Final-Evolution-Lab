import Foundation

struct TrainingProgramData {
    static func program(for track: TrainingTrack) -> TrainingProgram {
        switch track {
        case .foundations: foundationsProgram
        case .flight: flightProgram
        case .elite: eliteProgram
        }
    }

    static let foundationsProgram = TrainingProgram(
        id: "foundations_program",
        track: .foundations,
        weeks: 6,
        days: foundationsDays
    )

    static let flightProgram = TrainingProgram(
        id: "flight_program",
        track: .flight,
        weeks: 8,
        days: flightDays
    )

    static let eliteProgram = TrainingProgram(
        id: "elite_program",
        track: .elite,
        weeks: 12,
        days: eliteDays
    )

    // MARK: - Foundations Days

    static let foundationsDays: [TrainingDay] = [
        TrainingDay(
            id: "f_d1a", dayNumber: 1, variant: "A", title: "Strength A",
            category: .strength,
            warmUp: [
                tex("f_w1", "Hip Switch", 2, "10 each", 0, .mobility, ["Hips"], "Control rotation through the hips, keep core braced"),
                tex("f_w2", "Scaled Pogos (All Plants)", 3, "20", 30, .plyometric, ["Calves", "Ankles"], "Quick, low-amplitude hops — ankle stiffness focus"),
                tex("f_w3", "Lateral Leaps (All Plants)", 3, "8 each", 30, .plyometric, ["Hip Abductors", "Quads"], "Explosive lateral bound with single-leg stabilization"),
                tex("f_w4", "Broad Jump + High Jump", 3, "5 each", 45, .plyometric, ["Full Body"], "Max intent on each rep, full arm swing"),
            ],
            mainWork: [
                tex("f_d1a_1", "Split Stance Unilateral Horizontal Press", 3, "10 each", 60, .strength, ["Chest", "Shoulders", "Core"], "Maintain split stance stability throughout press"),
                tex("f_d1a_2", "Split Stance Unilateral Horizontal Row", 3, "10 each", 60, .strength, ["Back", "Biceps", "Core"], "Pull to hip, squeeze scapula"),
                tex("f_d1a_3", "Reverse Pivot Cross Chops", 3, "12 each", 45, .strength, ["Core", "Obliques"], "Rotate through thoracic spine, hips stay square"),
                tex("f_d1a_4", "Reverse Lunge", 3, "10 each", 60, .strength, ["Quads", "Glutes"], "Step back with control, drive through front heel"),
                tex("f_d1a_5", "RDL with Distraction", 3, "10 each", 60, .strength, ["Hamstrings", "Glutes"], "Hinge at hips, maintain neutral spine with band tension"),
                tex("f_d1a_6", "Hinged Side Plank", 3, "30s each", 45, .strength, ["Obliques", "Core"], "Stack hips, brace through obliques"),
                tex("f_d1a_7", "Glute Bridge Leg Swing Plank", 3, "10 each", 45, .strength, ["Glutes", "Core"], "Bridge up, controlled leg swing without dropping hips"),
                tex("f_d1a_8", "Cross Connect Toe Touch", 3, "12 each", 45, .strength, ["Core", "Hip Flexors"], "Reach opposite hand to foot, slow eccentric"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d1b", dayNumber: 1, variant: "B", title: "Strength B",
            category: .strength,
            warmUp: [
                tex("f_w5", "Skips + Back Pedal (Progressions)", 3, "30s", 30, .agility, ["Full Body"], "Start slow, increase speed each set"),
                tex("f_w6", "Lateral Bounds", 3, "8 each", 30, .plyometric, ["Hip Abductors", "Quads"], "Max distance, stick each landing"),
                tex("f_w7", "Karaoke (1 Over 2 Over)", 3, "30s", 30, .agility, ["Hips", "Core"], "Keep shoulders square, hips rotate"),
                tex("f_w8", "Lateral Double Hop Rebound Hop", 3, "6 each", 45, .plyometric, ["Calves", "Quads"], "Two quick lateral hops into one max vertical"),
            ],
            mainWork: [
                tex("f_d1b_1", "Dumbbell Bench / Full Range Push-Ups", 4, "10", 60, .strength, ["Chest", "Triceps", "Shoulders"], "Full range of motion, control the eccentric"),
                tex("f_d1b_2", "Dumbbell Row", 4, "10 each", 60, .strength, ["Back", "Biceps"], "Pull to hip, 1s pause at top"),
                texLeveled("f_d1b_3", "Step Down with Progressions", 3, "8 each", 75, .strength, ["Quads", "Glutes"], "Controlled descent, drive back up — progress through levels"),
                tex("f_d1b_4", "Single Leg Calf Raise", 3, "15 each", 45, .strength, ["Calves"], "Full range, 2s pause at top"),
                tex("f_d1b_5", "Hip Thrust", 4, "12", 60, .strength, ["Glutes", "Hamstrings"], "Drive through heels, squeeze glutes at top"),
                tex("f_d1b_6", "Unilateral Seated Forward Folds", 3, "30s each", 45, .mobility, ["Hamstrings", "Lower Back"], "Breathe into the stretch, maintain flat back"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d2a", dayNumber: 2, variant: "A", title: "Recovery + Isos A",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("f_d2a_1", "Side Lying Breathing Corrective", 2, "60s each", 30, .recovery, ["Core", "Diaphragm"], "Inhale through nose 4s, exhale 6s, feel ribs expand"),
                texLeveled("f_d2a_2", "Maximal Yielding Hamstring Iso", 3, "30s each", 45, .strength, ["Hamstrings"], "Hold at longest tolerable length — progress through levels"),
                tex("f_d2a_3", "Standing 4-Way Hip Iso", 3, "20s each direction", 30, .strength, ["Hips", "Glutes"], "Press into wall/band in all 4 directions"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d2b", dayNumber: 2, variant: "B", title: "Recovery + Isos B",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("f_d2b_1", "Seated Resisted Rotation with Breathing", 3, "10 each", 30, .recovery, ["Core", "Thoracic Spine"], "Exhale as you rotate, maintain tall posture"),
                tex("f_d2b_2", "Seated Resisted ER/IR with Torso Rotation", 3, "10 each", 30, .mobility, ["Shoulders", "Rotator Cuff"], "Rotate forearm while torso stays stable"),
                texLeveled("f_d2b_3", "Spanish Squat + Iso", 3, "30s", 45, .strength, ["Quads", "Knees"], "Lean back into band, hold deep position — progress through levels"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d3a", dayNumber: 3, variant: "A", title: "Strength C",
            category: .strength,
            warmUp: [
                tex("f_w9", "Mini Band Warm Up", 2, "10 each", 20, .mobility, ["Glutes", "Hips"], "Lateral walks, monster walks, clamshells"),
                tex("f_w10", "Split Stance to Single Leg (Banded)", 2, "8 each", 30, .strength, ["Glutes", "Core"], "Shift weight forward to single leg balance"),
                tex("f_w11", "Lateral Banded Walk", 2, "15 each", 30, .agility, ["Hip Abductors", "Glutes"], "Stay low, resist band pulling knees in"),
            ],
            mainWork: [
                tex("f_d3a_1", "Half Kneeling Shoulder Press", 3, "10 each", 60, .strength, ["Shoulders", "Core"], "Brace core, press directly overhead"),
                tex("f_d3a_2", "Half Kneeling Pull Down", 3, "10 each", 60, .strength, ["Lats", "Core"], "Drive elbow to hip, maintain upright torso"),
                tex("f_d3a_3", "2-Step Straight Arm Step Outs", 3, "10 each", 45, .strength, ["Shoulders", "Core"], "Arms locked, step out with control"),
                tex("f_d3a_4", "Adductor/Abductor Cross Step", 3, "10 each", 45, .agility, ["Adductors", "Abductors"], "Controlled cross-over pattern"),
                tex("f_d3a_5", "Heels Elevated Pulse Squats", 3, "15", 60, .strength, ["Quads"], "Small pulses at bottom range, heels on plate"),
                tex("f_d3a_6", "Hamstring Curl / Regressed Nordics", 3, "10", 60, .strength, ["Hamstrings"], "Control the eccentric, push back with hands if needed"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d3b", dayNumber: 3, variant: "B", title: "Strength D",
            category: .strength,
            warmUp: [
                tex("f_w12", "Resisted Skips", 3, "20m", 30, .plyometric, ["Full Body"], "Drive knee up against band resistance"),
                tex("f_w13", "Backpedal", 3, "20m", 30, .agility, ["Quads", "Calves"], "Stay low, quick feet"),
                tex("f_w14", "Lateral Leap", 3, "6 each", 30, .plyometric, ["Hip Abductors"], "Max distance lateral bound"),
            ],
            mainWork: [
                tex("f_d3b_1", "Resisted Sprints", 4, "20m × 2 each plant", 90, .agility, ["Full Body"], "Max effort through band resistance"),
                tex("f_d3b_2", "Sled Push / Acceleration Step with Band", 3, "20m", 90, .strength, ["Quads", "Glutes"], "45° body angle, drive through ground"),
                tex("f_d3b_3", "Horizontal Force Deceleration Step", 3, "6 each", 60, .agility, ["Quads", "Core"], "Sprint then decelerate in 2-3 steps"),
                tex("f_d3b_4", "Straight Arm Low Anchor Flies", 3, "12", 45, .strength, ["Chest", "Shoulders"], "Arms straight, squeeze through full arc"),
                tex("f_d3b_5", "High Anchor Tricep Pull Down", 3, "12", 45, .strength, ["Triceps"], "Lock elbows, full extension"),
                tex("f_d3b_6", "RDL to Hip Flexion", 3, "8 each", 60, .strength, ["Hamstrings", "Hip Flexors"], "Hinge down then drive knee to chest"),
                tex("f_d3b_7", "Deep Tier Yielding Hops (RFE + Lunge)", 3, "8 each", 75, .plyometric, ["Quads", "Calves"], "Absorb and re-explode from deep position"),
                tex("f_d3b_8", "Single Leg Balance (Progressions)", 3, "30s each", 30, .mobility, ["Ankles", "Core"], "Eyes open → closed → unstable surface"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d3c", dayNumber: 3, variant: "C", title: "Max Intent Jumping",
            category: .maxIntent,
            warmUp: [
                tex("f_w15", "Dynamic Warm Up Circuit", 2, "5 min", 60, .mobility, ["Full Body"], "Joint circles, leg swings, arm circles, light jog"),
            ],
            mainWork: [
                tex("f_d3c_1", "Dunk Session — Approach Progressions", 5, "5", 120, .plyometric, ["Full Body"], "Focus on penultimate step, arm swing timing, and gather mechanics"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "f_d4a", dayNumber: 4, variant: "A", title: "Recovery + Pilates",
            category: .recoveryPilates,
            warmUp: [],
            mainWork: [
                tex("f_d4a_1", "Hand Walk Out", 3, "8", 30, .mobility, ["Hamstrings", "Shoulders", "Core"], "Walk hands to plank, walk feet to hands"),
                tex("f_d4a_2", "Cat Camel", 3, "10", 20, .mobility, ["Spine", "Core"], "Slow transitions, breathe into each position"),
                tex("f_d4a_3", "Swimming", 3, "30s", 30, .recovery, ["Back", "Glutes"], "Alternating arm/leg lifts, keep core engaged"),
                tex("f_d4a_4", "Deep Split Stance Iso", 3, "30s each", 30, .strength, ["Hip Flexors", "Quads"], "Sink deep into lunge, hold and breathe"),
                tex("f_d4a_5", "Thread the Needle", 3, "8 each", 30, .mobility, ["Thoracic Spine", "Shoulders"], "Rotate through thoracic, reach under and up"),
                tex("f_d4a_6", "Low-Level Hops (Timed)", 3, "30s", 30, .plyometric, ["Calves", "Ankles"], "Quick, minimal ground contact, stay on balls of feet"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d4b", dayNumber: 4, variant: "B", title: "Recovery + Isos C",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("f_d4b_1", "Roll Down", 3, "8", 30, .mobility, ["Spine", "Hamstrings"], "Vertebra by vertebra, breathe at the bottom"),
                tex("f_d4b_2", "Terminal Knee Extension (TKE)", 3, "15 each", 30, .strength, ["Quads", "Knees"], "Lock out knee against band resistance"),
                tex("f_d4b_3", "Hip Flexor Iso Hold", 3, "30s each", 30, .strength, ["Hip Flexors"], "Hold knee at 90° against gravity or band"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d4c", dayNumber: 4, variant: "C", title: "Jump Variations",
            category: .jumpVariations,
            warmUp: [],
            mainWork: [
                tex("f_d4c_1", "Seated Broad Jump to Vertical Jump", 4, "5", 90, .plyometric, ["Full Body"], "Explode from seated to broad, immediately convert to vertical"),
                tex("f_d4c_2", "Seated Pivot Jumps", 4, "5 each", 90, .plyometric, ["Full Body"], "Rotate 90° mid-air from seated start"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "f_d5a", dayNumber: 5, variant: "A", title: "Recovery A",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("f_d5a_1", "Horizontal Force Open Chain Ankle CARs", 3, "10 each", 20, .mobility, ["Ankles"], "Full circles, maximize range at each position"),
                tex("f_d5a_2", "Horizontal Slant Ankle Raise (Both Ways)", 3, "12 each", 30, .strength, ["Calves", "Ankles"], "Inversion and eversion on slant board"),
                tex("f_d5a_3", "DaVinci Plank", 3, "30s", 30, .strength, ["Core", "Shoulders"], "Spread arms and legs wide in plank, brace hard"),
                tex("f_d5a_4", "Split Stance Horizontal Hinge/RDL", 3, "8 each", 45, .strength, ["Hamstrings", "Glutes"], "Hinge with split stance, maintain neutral spine"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "f_d5b", dayNumber: 5, variant: "B", title: "Recovery B",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("f_d5b_1", "Supine Banded Leg Raises (Both Directions)", 3, "10 each", 30, .mobility, ["Hip Flexors", "Core"], "Control both the lift and the lower"),
                tex("f_d5b_2", "Step Down Iso (Forward + Reverse)", 3, "20s each", 30, .strength, ["Quads", "Knees"], "Hold at bottom of step down, both directions"),
                tex("f_d5b_3", "Tennis Ball Foot Mobility", 2, "60s each", 20, .recovery, ["Feet", "Plantar Fascia"], "Roll under arch, apply moderate pressure"),
                tex("f_d5b_4", "Toe CARs", 2, "10 each", 20, .mobility, ["Toes", "Feet"], "Isolate each toe through full range"),
                tex("f_d5b_5", "Banded Ankle CARs", 2, "10 each", 20, .mobility, ["Ankles"], "Circle against band resistance"),
                tex("f_d5b_6", "Floor Seated Plank with Breathing", 3, "30s", 30, .recovery, ["Core", "Diaphragm"], "Brace plank position, cue internal/external rotation breathing"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - Flight Days

    static let flightDays: [TrainingDay] = [
        TrainingDay(
            id: "fl_d1a", dayNumber: 1, variant: "A", title: "Explosive Strength A",
            category: .strength,
            warmUp: [
                tex("fl_w1", "Hip Switch", 2, "10 each", 0, .mobility, ["Hips"], "Control rotation, core braced"),
                tex("fl_w2", "Depth Drop to Stick", 3, "6", 45, .plyometric, ["Quads", "Calves"], "Step off box, absorb and freeze landing"),
                tex("fl_w3", "Lateral Bounds (Max Distance)", 3, "8 each", 30, .plyometric, ["Hip Abductors", "Quads"], "Stick each landing for 2 seconds"),
                tex("fl_w4", "Broad Jump to Vertical", 3, "5", 45, .plyometric, ["Full Body"], "Chain horizontal to vertical with no pause"),
            ],
            mainWork: [
                tex("fl_d1a_1", "Rear Foot Elevated Split Squat", 4, "8 each", 75, .strength, ["Quads", "Glutes", "Core"], "Deep knee flexion, drive through front heel"),
                tex("fl_d1a_2", "Pallof Press Step Outs", 3, "10 each", 45, .strength, ["Core", "Obliques"], "Step out against band while pressing, resist rotation"),
                tex("fl_d1a_3", "Inverted Row", 4, "10", 60, .strength, ["Back", "Biceps", "Core"], "Body straight, pull chest to bar"),
                tex("fl_d1a_4", "Hip Thrust (Heavy)", 4, "8", 75, .strength, ["Glutes", "Hamstrings"], "Pause 2s at top, drive through heels"),
                tex("fl_d1a_5", "Tiered Plyometrics (Watson)", 3, "6", 90, .plyometric, ["Full Body"], "Progress from low to med to high box"),
                tex("fl_d1a_6", "Side Plank Clam", 3, "12 each", 45, .strength, ["Obliques", "Glutes"], "Side plank with clamshell hip abduction"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "fl_d1b", dayNumber: 1, variant: "B", title: "Explosive Strength B",
            category: .strength,
            warmUp: [
                tex("fl_w5", "Cone Agility Circuit", 3, "45s", 45, .agility, ["Full Body"], "Multi-directional cuts through cone patterns"),
                tex("fl_w6", "Karaoke to Sprint", 3, "20m", 30, .agility, ["Hips", "Full Body"], "Karaoke 10m then burst into 10m sprint"),
            ],
            mainWork: [
                tex("fl_d1b_1", "Bulgarian Split Squat (Loaded)", 4, "8 each", 75, .strength, ["Quads", "Glutes", "Core"], "Deep range, maintain upright torso"),
                tex("fl_d1b_2", "Single Arm Dumbbell Row", 4, "10 each", 60, .strength, ["Back", "Biceps"], "Pull to hip, 1s squeeze at top"),
                tex("fl_d1b_3", "Depth Jump to Max Vertical", 4, "5", 120, .plyometric, ["Quads", "Calves", "Glutes"], "Step off, absorb, explode — minimize ground contact"),
                tex("fl_d1b_4", "Lateral Leap to Sprint", 3, "6 each", 90, .plyometric, ["Full Body"], "Bound laterally then accelerate forward"),
                tex("fl_d1b_5", "Continuous Hops (30s)", 3, "30s", 60, .plyometric, ["Calves", "Ankles"], "Minimize ground contact, stay on balls of feet"),
                tex("fl_d1b_6", "Hip Flexor Activation Series", 3, "12 each", 45, .mobility, ["Hip Flexors", "Core"], "Active flexion drills to improve knee drive"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "fl_d2a", dayNumber: 2, variant: "A", title: "Recovery + Isos A",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("fl_d2a_1", "Side Lying Breathing Corrective", 2, "60s each", 30, .recovery, ["Core", "Diaphragm"], "4s inhale, 6s exhale, feel lateral rib expansion"),
                texLeveled("fl_d2a_2", "Maximal Yielding Hamstring Iso", 3, "30s each", 45, .strength, ["Hamstrings"], "Hold at longest tolerable length"),
                tex("fl_d2a_3", "Standing 4-Way Hip Iso", 3, "20s each", 30, .strength, ["Hips", "Glutes"], "Press into resistance in all 4 directions"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "fl_d2b", dayNumber: 2, variant: "B", title: "Recovery + Isos B",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("fl_d2b_1", "Seated Resisted Rotation with Breathing", 3, "10 each", 30, .recovery, ["Core", "Thoracic"], "Exhale as you rotate"),
                texLeveled("fl_d2b_2", "Spanish Squat + Iso", 3, "30s", 45, .strength, ["Quads", "Knees"], "Lean back, hold deep position"),
                tex("fl_d2b_3", "Foam Roll + Neural Flush", 2, "5 min", 0, .recovery, ["Full Body"], "Roll quads, hamstrings, calves, thoracic"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "fl_d3a", dayNumber: 3, variant: "A", title: "Power + Agility",
            category: .strength,
            warmUp: [
                tex("fl_w7", "Mini Band Warm Up", 2, "10 each", 20, .mobility, ["Glutes", "Hips"], "Lateral walks, monster walks"),
                tex("fl_w8", "Resisted Skips (Progressive)", 3, "20m", 30, .plyometric, ["Full Body"], "Increase intensity each set"),
            ],
            mainWork: [
                tex("fl_d3a_1", "Trap Bar Deadlift (Moderate)", 4, "6", 120, .strength, ["Posterior Chain", "Quads"], "Explosive concentric, controlled eccentric"),
                tex("fl_d3a_2", "Cone/Ladder Agility Circuit", 4, "45s", 60, .agility, ["Full Body"], "Multi-directional speed with rapid direction changes"),
                tex("fl_d3a_3", "Resisted Sprints", 4, "20m", 90, .agility, ["Full Body"], "Max effort through band resistance"),
                tex("fl_d3a_4", "Deep Tier Yielding Hops", 3, "8 each", 75, .plyometric, ["Quads", "Calves"], "Absorb deep and re-explode"),
                tex("fl_d3a_5", "Nordic Hamstring Curl", 3, "6", 75, .strength, ["Hamstrings"], "Slow eccentric, push back with hands at bottom"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "fl_d3c", dayNumber: 3, variant: "C", title: "Max Intent Jumping",
            category: .maxIntent,
            warmUp: [
                tex("fl_w9", "Dynamic Warm Up + CNS Primers", 2, "5 min", 60, .mobility, ["Full Body"], "Tuck jumps, A-skips, sprint build-ups"),
            ],
            mainWork: [
                tex("fl_d3c_1", "Dunk Session — Approach + Gather", 5, "5", 120, .plyometric, ["Full Body"], "Focus on penultimate step conversion and arm swing timing"),
                tex("fl_d3c_2", "Max Vertical Jump Testing", 3, "3", 120, .plyometric, ["Full Body"], "Full approach, max effort, measure and track"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "fl_d4a", dayNumber: 4, variant: "A", title: "Recovery + Pilates",
            category: .recoveryPilates,
            warmUp: [],
            mainWork: [
                tex("fl_d4a_1", "Hand Walk Out", 3, "8", 30, .mobility, ["Hamstrings", "Shoulders"], "Walk to plank, walk feet to hands"),
                tex("fl_d4a_2", "Cat Camel", 3, "10", 20, .mobility, ["Spine"], "Slow, controlled transitions"),
                tex("fl_d4a_3", "Swimming", 3, "30s", 30, .recovery, ["Back", "Glutes"], "Alternating limb lifts"),
                tex("fl_d4a_4", "Deep Split Stance Iso", 3, "30s each", 30, .strength, ["Hip Flexors"], "Sink deep, breathe"),
                tex("fl_d4a_5", "Thread the Needle", 3, "8 each", 30, .mobility, ["Thoracic Spine"], "Full thoracic rotation"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "fl_d5a", dayNumber: 5, variant: "A", title: "Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("fl_d5a_1", "Ankle CARs", 3, "10 each", 20, .mobility, ["Ankles"], "Full circles, maximize range"),
                tex("fl_d5a_2", "Slant Ankle Raise", 3, "12 each", 30, .strength, ["Calves", "Ankles"], "Both inversion and eversion"),
                tex("fl_d5a_3", "DaVinci Plank", 3, "30s", 30, .strength, ["Core"], "Wide base plank, brace hard"),
                tex("fl_d5a_4", "Supine Banded Leg Raises", 3, "10 each", 30, .mobility, ["Hip Flexors"], "Control both directions"),
                tex("fl_d5a_5", "Tennis Ball Foot Mobility", 2, "60s each", 20, .recovery, ["Feet"], "Roll arch, moderate pressure"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - Elite Days

    static let eliteDays: [TrainingDay] = [
        TrainingDay(
            id: "e_d1a", dayNumber: 1, variant: "A", title: "Max Strength A",
            category: .strength,
            warmUp: [
                tex("e_w1", "CNS Activation Circuit", 2, "3 min", 60, .plyometric, ["Full Body"], "Box jumps, tuck jumps, clap push-ups — prime the system"),
                tex("e_w2", "Scaled Pogos (All Plants Max Intent)", 3, "20", 30, .plyometric, ["Calves", "Ankles"], "Max stiffness, minimal ground contact"),
                tex("e_w3", "Depth Drop to Max Vertical", 3, "5", 60, .plyometric, ["Full Body"], "Absorb and immediately explode"),
            ],
            mainWork: [
                tex("e_d1a_1", "Trap Bar Deadlift (Heavy)", 5, "3-5", 180, .strength, ["Posterior Chain", "Quads", "Core"], "Peak force production, explosive concentric"),
                tex("e_d1a_2", "Rear Foot Elevated Split Squat (Loaded)", 4, "6 each", 90, .strength, ["Quads", "Glutes"], "Deep range with heavy load"),
                tex("e_d1a_3", "Weighted Hip Thrust", 4, "8", 90, .strength, ["Glutes", "Hamstrings"], "Heavy load, 2s pause at top"),
                tex("e_d1a_4", "Nordic Hamstring Curl (Full)", 3, "5", 90, .strength, ["Hamstrings"], "Full eccentric control, no hand assist"),
                tex("e_d1a_5", "Weighted Depth Jump", 3, "5", 120, .plyometric, ["Quads", "Calves", "Glutes"], "Light vest, maximize reactive power"),
                tex("e_d1a_6", "Cross Connect Core Circuit", 3, "12 each", 45, .strength, ["Core", "Obliques"], "Toe touches + rotational chops"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "e_d1b", dayNumber: 1, variant: "B", title: "Max Strength B",
            category: .strength,
            warmUp: [
                tex("e_w4", "Sprint Build-Ups", 3, "40m", 60, .agility, ["Full Body"], "70-80-90% progressive sprints"),
                tex("e_w5", "Lateral Bounds (Max)", 3, "8 each", 45, .plyometric, ["Full Body"], "Max distance, stick landing"),
            ],
            mainWork: [
                tex("e_d1b_1", "Barbell Back Squat (Heavy)", 5, "3-5", 180, .strength, ["Quads", "Glutes", "Core"], "Below parallel, explosive drive"),
                tex("e_d1b_2", "Single Arm Dumbbell Row (Heavy)", 4, "8 each", 75, .strength, ["Back", "Biceps"], "Heavy pull, controlled eccentric"),
                tex("e_d1b_3", "Depth Jump to Broad Jump", 4, "5", 120, .plyometric, ["Full Body"], "Absorb vertically, redirect horizontally"),
                tex("e_d1b_4", "Neural Drive Sprint", 6, "20m", 120, .agility, ["Full Body"], "Maximum effort for neural recruitment optimization"),
                tex("e_d1b_5", "Tiered Plyometrics (Watson — Advanced)", 3, "5", 120, .plyometric, ["Full Body"], "High box series with max intent"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "e_d2a", dayNumber: 2, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("e_d2a_1", "Side Lying Breathing Corrective", 2, "90s each", 30, .recovery, ["Core", "Diaphragm"], "Deep diaphragmatic breathing, CNS downregulation"),
                texLeveled("e_d2a_2", "Maximal Yielding Hamstring Iso", 3, "45s each", 60, .strength, ["Hamstrings"], "Extended hold at end range"),
                tex("e_d2a_3", "Standing 4-Way Hip Iso (Heavy Band)", 3, "25s each", 45, .strength, ["Hips", "Glutes"], "Max effort isometric in all 4 directions"),
                texLeveled("e_d2a_4", "Spanish Squat + Extended Iso", 3, "45s", 60, .strength, ["Quads", "Knees"], "Deep hold with heavy band tension"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "e_d3c", dayNumber: 3, variant: "C", title: "Dunk Session — Max Intent",
            category: .maxIntent,
            warmUp: [
                tex("e_w6", "Full CNS Warm Up", 2, "8 min", 60, .mobility, ["Full Body"], "Sprint build-ups, approach rehearsals, tuck jumps"),
            ],
            mainWork: [
                tex("e_d3c_1", "Dunk Session — Full Approach", 5, "5", 150, .plyometric, ["Full Body"], "Full approach dunking with emphasis on penultimate step and arm swing timing"),
                tex("e_d3c_2", "Dunk Contest Simulation", 3, "3", 150, .plyometric, ["Full Body"], "Style tricks — windmills, between-the-legs, tomahawks"),
                tex("e_d3c_3", "Max Vertical Testing", 3, "3", 120, .plyometric, ["Full Body"], "Track and record peak vertical reach"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "e_d4a", dayNumber: 4, variant: "A", title: "Recovery + Pilates",
            category: .recoveryPilates,
            warmUp: [],
            mainWork: [
                tex("e_d4a_1", "Hand Walk Out", 3, "8", 30, .mobility, ["Hamstrings", "Shoulders"], "Full range walk out to plank"),
                tex("e_d4a_2", "Cat Camel", 3, "10", 20, .mobility, ["Spine"], "Slow controlled movement"),
                tex("e_d4a_3", "Swimming", 3, "30s", 30, .recovery, ["Back", "Glutes"], "Alternating limb lifts"),
                tex("e_d4a_4", "Deep Split Stance Iso", 3, "45s each", 45, .strength, ["Hip Flexors"], "Max depth, controlled breathing"),
                tex("e_d4a_5", "Thread the Needle", 3, "10 each", 30, .mobility, ["Thoracic Spine"], "Full rotation range"),
                tex("e_d4a_6", "Low-Level Hops (Timed)", 3, "45s", 30, .plyometric, ["Calves", "Ankles"], "Quick ground contact, maintain form"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "e_d4c", dayNumber: 4, variant: "C", title: "Jump Variations",
            category: .jumpVariations,
            warmUp: [],
            mainWork: [
                tex("e_d4c_1", "Seated Broad Jump to Max Vertical", 4, "5", 120, .plyometric, ["Full Body"], "Seated start to horizontal, redirect to max vertical"),
                tex("e_d4c_2", "Seated Pivot Jumps", 4, "5 each", 120, .plyometric, ["Full Body"], "90° rotation from seated start"),
                tex("e_d4c_3", "Skip Progressions into Cherokee Bound", 3, "20m", 90, .plyometric, ["Full Body"], "Build from skip to max distance bound"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "e_d5a", dayNumber: 5, variant: "A", title: "Recovery Protocol",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("e_d5a_1", "Ankle CARs + Banded Ankle CARs", 3, "10 each", 20, .mobility, ["Ankles"], "Full circles with and without resistance"),
                tex("e_d5a_2", "Slant Ankle Raise (Both Ways)", 3, "15 each", 30, .strength, ["Calves", "Ankles"], "Full range on slant board"),
                tex("e_d5a_3", "DaVinci Plank", 3, "45s", 30, .strength, ["Core"], "Wide base, max brace"),
                tex("e_d5a_4", "Split Stance Hinge/RDL", 3, "8 each", 45, .strength, ["Hamstrings", "Glutes"], "Maintain neutral spine"),
                tex("e_d5a_5", "Supine Banded Leg Raises", 3, "12 each", 30, .mobility, ["Hip Flexors"], "Both directions, full control"),
                tex("e_d5a_6", "Tennis Ball + Toe CARs", 2, "60s each", 20, .recovery, ["Feet", "Toes"], "Full foot mobility protocol"),
                tex("e_d5a_7", "Recovery Protocol — Foam Roll + Stretch", 1, "15 min", 0, .recovery, ["Full Body"], "Full body foam rolling, static stretching, and breathing techniques"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - Helpers

    private static func tex(_ id: String, _ name: String, _ sets: Int, _ reps: String, _ rest: Int, _ cat: Exercise.ExerciseCategory, _ muscles: [String], _ cues: String) -> TrainingExercise {
        TrainingExercise(id: id, name: name, sets: sets, reps: reps, restSeconds: rest, category: cat, muscleGroups: muscles, cues: cues, progressionLevel: 1, hasLevels: false)
    }

    private static func texLeveled(_ id: String, _ name: String, _ sets: Int, _ reps: String, _ rest: Int, _ cat: Exercise.ExerciseCategory, _ muscles: [String], _ cues: String) -> TrainingExercise {
        TrainingExercise(id: id, name: name, sets: sets, reps: reps, restSeconds: rest, category: cat, muscleGroups: muscles, cues: cues, progressionLevel: 1, hasLevels: true)
    }
}
