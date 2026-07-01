import Foundation

struct TrainingProgramData {
    static func program(for track: TrainingTrack, equipment: EquipmentType = .bodyweight) -> TrainingProgram {
        switch equipment {
        case .bodyweight:
            switch track {
            case .foundations: foundationsProgram
            case .flight: flightProgram
            case .elite: eliteProgram
            }
        case .movementEducation:
            switch track {
            case .foundations: meFoundationsProgram
            case .flight: meFlightProgram
            case .elite: meEliteProgram
            }
        case .pjfBand:
            switch track {
            case .foundations: pjfBandFoundationsProgram
            case .flight: pjfBandFlightProgram
            case .elite: pjfBandEliteProgram
            }
        case .totalBodyBoard:
            switch track {
            case .foundations: tbbFoundationsProgram
            case .flight: tbbFlightProgram
            case .elite: tbbEliteProgram
            }
        case .pushPullHinge:
            switch track {
            case .foundations: pphFoundationsProgram
            case .flight: pphFlightProgram
            case .elite: pphEliteProgram
            }
        }
    }

    // MARK: - Bodyweight Programs

    static let foundationsProgram = TrainingProgram(
        id: "foundations_program",
        track: .foundations,
        equipment: .bodyweight,
        weeks: 6,
        days: foundationsDays
    )

    static let flightProgram = TrainingProgram(
        id: "flight_program",
        track: .flight,
        equipment: .bodyweight,
        weeks: 8,
        days: flightDays
    )

    static let eliteProgram = TrainingProgram(
        id: "elite_program",
        track: .elite,
        equipment: .bodyweight,
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

    static func tex(_ id: String, _ name: String, _ sets: Int, _ reps: String, _ rest: Int, _ cat: Exercise.ExerciseCategory, _ muscles: [String], _ cues: String) -> TrainingExercise {
        TrainingExercise(id: id, name: name, sets: sets, reps: reps, restSeconds: rest, category: cat, muscleGroups: muscles, cues: cues, progressionLevel: 1, hasLevels: false)
    }

    static func texLeveled(_ id: String, _ name: String, _ sets: Int, _ reps: String, _ rest: Int, _ cat: Exercise.ExerciseCategory, _ muscles: [String], _ cues: String) -> TrainingExercise {
        TrainingExercise(id: id, name: name, sets: sets, reps: reps, restSeconds: rest, category: cat, muscleGroups: muscles, cues: cues, progressionLevel: 1, hasLevels: true)
    }

    // MARK: - PJF Band Programs

    static let pjfBandFoundationsProgram = TrainingProgram(
        id: "pjf_foundations", track: .foundations, equipment: .pjfBand, weeks: 6, days: pjfBandFoundationsDays
    )
    static let pjfBandFlightProgram = TrainingProgram(
        id: "pjf_flight", track: .flight, equipment: .pjfBand, weeks: 8, days: pjfBandFlightDays
    )
    static let pjfBandEliteProgram = TrainingProgram(
        id: "pjf_elite", track: .elite, equipment: .pjfBand, weeks: 12, days: pjfBandEliteDays
    )

    static let pjfBandFoundationsDays: [TrainingDay] = [
        TrainingDay(
            id: "pjf_f_d1", dayNumber: 1, variant: "A", title: "Mobility & Patterning",
            category: .recovery,
            warmUp: [
                tex("pjf_f_w1", "3-Way Hip Hinge with Band Distraction", 2, "5 each way", 30, .mobility, ["Hips", "Hamstrings"], "Hinge forward/lateral/rotational with band pulling hip back"),
                tex("pjf_f_w2", "Split Stance Hip Flexor 2-Way Reach with Band", 2, "5 each way", 30, .mobility, ["Hip Flexors", "Thoracic Spine"], "Reach overhead then lateral while band distracts hip"),
                tex("pjf_f_w3", "Lateral Lunge Adductor Stretch", 2, "8", 30, .mobility, ["Adductors", "Groin"], "Shift deep into lateral lunge, feel inner thigh stretch"),
            ],
            mainWork: [
                tex("pjf_f_d1_1", "Curtsy Hinge to Step Through", 2, "10", 45, .mobility, ["Hips", "Glutes", "Core"], "Cross behind into curtsy hinge, step through to single leg"),
                tex("pjf_f_d1_2", "Back Line / Front Line Stretch", 2, "12", 30, .mobility, ["Posterior Chain", "Anterior Chain"], "Alternate between full posterior and anterior chain stretches"),
                tex("pjf_f_d1_3", "Supine Long Length Hamstring Raise", 2, "15", 30, .mobility, ["Hamstrings"], "Lie supine, raise straight leg maintaining band tension"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_f_d2", dayNumber: 2, variant: "A", title: "Strength & Agility",
            category: .strength,
            warmUp: [
                tex("pjf_f_w4", "Band Resisted Skips", 4, "50 ft", 30, .plyometric, ["Full Body"], "Drive knee up against band resistance, max height"),
                tex("pjf_f_w5", "Lateral Bounds with Band", 3, "6 each", 30, .plyometric, ["Hip Abductors", "Quads"], "Lateral bound against band, stick landing"),
            ],
            mainWork: [
                texLeveled("pjf_f_d2_1", "Maximal Overcoming Hamstring Isometric", 3, "5-8s", 60, .strength, ["Hamstrings"], "Press into immovable resistance at max effort"),
                tex("pjf_f_d2_2", "1-Leg RDL with Hand Support", 3, "8-10 each", 60, .strength, ["Hamstrings", "Glutes"], "Hinge on one leg, light hand touch for balance"),
                tex("pjf_f_d2_3", "Forward Lunge Isometric", 3, "45s", 60, .strength, ["Quads", "Hip Flexors"], "Hold deep lunge position, brace core"),
                tex("pjf_f_d2_4", "Lunge Rapid Switches", 2, "10", 45, .agility, ["Quads", "Glutes"], "Explosive alternating lunge jumps"),
                tex("pjf_f_d2_5", "Diagonal Split Lateral Jumps", 3, "8", 45, .plyometric, ["Hip Abductors", "Quads"], "Jump diagonally into split stance, alternate sides"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_f_d3", dayNumber: 3, variant: "A", title: "Speed & Power",
            category: .strength,
            warmUp: [
                tex("pjf_f_w6", "Hand Assisted Marching", 2, "10", 20, .mobility, ["Hip Flexors", "Core"], "Light hand support, drive knees high with control"),
                tex("pjf_f_w7", "Stationary Sprinting", 2, "20s", 30, .agility, ["Full Body"], "Max effort sprint in place against band resistance"),
            ],
            mainWork: [
                tex("pjf_f_d3_1", "Resisted Broad Jumps", 3, "6", 75, .plyometric, ["Full Body"], "Explode forward against band, max distance"),
                tex("pjf_f_d3_2", "Resisted Pogos", 3, "15", 45, .plyometric, ["Calves", "Ankles"], "Quick hops against band, minimal ground contact"),
                tex("pjf_f_d3_3", "Resisted 1-Leg Cycle Overs", 3, "10 each", 45, .agility, ["Hip Flexors", "Quads"], "Drive knee up and over against band resistance"),
                tex("pjf_f_d3_4", "Diagonal Split Rotational Reach to Crash Through", 2, "8", 60, .plyometric, ["Core", "Hips"], "Rotate and reach then explosively drive through"),
                tex("pjf_f_d3_5", "Hip Flexor + Rotational Shoulder Press", 3, "12", 45, .strength, ["Shoulders", "Hip Flexors", "Core"], "Drive knee up while pressing band overhead with rotation"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_f_d4", dayNumber: 4, variant: "A", title: "Recovery & Isometrics",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("pjf_f_d4_1", "Floating Toes Dorsiflexion with Band Distraction", 2, "15", 30, .mobility, ["Ankles", "Calves"], "Lift toes while band pulls ankle into dorsiflexion"),
                tex("pjf_f_d4_2", "Half Kneel Underhand Press with Band Distraction", 2, "8", 45, .strength, ["Shoulders", "Core"], "Press from half-kneel, band distracts hip for stretch"),
                texLeveled("pjf_f_d4_3", "Maximal Yielding Hamstring Iso", 3, "15-30s", 45, .strength, ["Hamstrings"], "Hold at longest tolerable length — progress through levels"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_f_d5", dayNumber: 5, variant: "A", title: "Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("pjf_f_d5_1", "Banded Ankle CARs", 2, "10 each", 20, .mobility, ["Ankles"], "Full circles against band resistance"),
                tex("pjf_f_d5_2", "Supine Banded Leg Raises", 3, "10 each", 30, .mobility, ["Hip Flexors", "Core"], "Control both lift and lower against band"),
                tex("pjf_f_d5_3", "Banded Toe CARs", 2, "10 each", 20, .mobility, ["Toes", "Feet"], "Isolate each toe through range with light band"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    static let pjfBandFlightDays: [TrainingDay] = [
        TrainingDay(
            id: "pjf_fl_d1", dayNumber: 1, variant: "A", title: "Explosive Band Strength",
            category: .strength,
            warmUp: [
                tex("pjf_fl_w1", "Band Resisted Skips (Progressive)", 4, "50 ft", 30, .plyometric, ["Full Body"], "Increase intensity each set"),
                tex("pjf_fl_w2", "Lateral Bounds with Band (Max)", 3, "8 each", 30, .plyometric, ["Hip Abductors"], "Max distance, stick each landing 2s"),
            ],
            mainWork: [
                tex("pjf_fl_d1_1", "Resisted RFESS Jumps", 3, "12", 75, .plyometric, ["Quads", "Glutes"], "Rear foot elevated, explode up against band"),
                tex("pjf_fl_d1_2", "Resisted Repeat Jumps", 3, "8", 75, .plyometric, ["Full Body"], "Consecutive max jumps against band resistance"),
                tex("pjf_fl_d1_3", "Resisted Split Stance Rapid Switches", 3, "6 each", 60, .agility, ["Quads", "Glutes"], "Explosive alternating lunges against band"),
                tex("pjf_fl_d1_4", "Hip Flexor + Rotational Press (Heavy Band)", 3, "10 each", 60, .strength, ["Shoulders", "Hip Flexors"], "Heavier band, drive knee + press with rotation"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_fl_d2", dayNumber: 2, variant: "A", title: "Speed & Power",
            category: .strength,
            warmUp: [
                tex("pjf_fl_w3", "Stationary Sprinting (Resisted)", 3, "20s", 30, .agility, ["Full Body"], "Max effort sprint in place, heavy band"),
                tex("pjf_fl_w4", "Hand Assisted High Knees", 2, "15 each", 20, .agility, ["Hip Flexors"], "Drive knees max height against band"),
            ],
            mainWork: [
                tex("pjf_fl_d2_1", "Resisted Broad Jumps (Max)", 4, "6", 90, .plyometric, ["Full Body"], "Max distance broad jumps against heavy band"),
                tex("pjf_fl_d2_2", "Resisted Pogos (Rapid)", 3, "20", 45, .plyometric, ["Calves", "Ankles"], "Fastest possible ground contact, band loaded"),
                tex("pjf_fl_d2_3", "Resisted 1-Leg Cycle Overs (Speed)", 3, "12 each", 45, .agility, ["Hip Flexors"], "Fast cycle overs, maintain form under load"),
                tex("pjf_fl_d2_4", "Diagonal Split Rotational Crash Through", 3, "8", 60, .plyometric, ["Core", "Hips", "Full Body"], "Explosive rotational drive through with band"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_fl_d3", dayNumber: 3, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("pjf_fl_d3_1", "3-Way Hip Hinge with Band (Deep)", 2, "8 each way", 30, .mobility, ["Hips", "Hamstrings"], "Deeper range, maintain band tension throughout"),
                texLeveled("pjf_fl_d3_2", "Maximal Yielding Hamstring Iso", 3, "30s each", 45, .strength, ["Hamstrings"], "Extended hold at end range"),
                tex("pjf_fl_d3_3", "Floating Toes Dorsiflexion (Progressive)", 3, "15", 30, .mobility, ["Ankles"], "Increase band tension each set"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_fl_d4", dayNumber: 4, variant: "A", title: "Agility & Deceleration",
            category: .strength,
            warmUp: [
                tex("pjf_fl_w5", "Band Resisted Lateral Walks", 3, "15 each", 20, .agility, ["Hip Abductors", "Glutes"], "Stay low, resist band pulling knees in"),
            ],
            mainWork: [
                tex("pjf_fl_d4_1", "Lateral Split Stance Decels", 3, "10", 60, .agility, ["Quads", "Core"], "Lateral bound then decelerate in 2 steps"),
                tex("pjf_fl_d4_2", "Cross Step Change of Direction", 3, "8", 60, .agility, ["Hips", "Quads"], "Cross step then explode in new direction"),
                tex("pjf_fl_d4_3", "Resisted Sprints (Band)", 4, "20m", 90, .agility, ["Full Body"], "Max effort sprint through band resistance"),
                tex("pjf_fl_d4_4", "Lunge Rapid Switches (Loaded)", 3, "12", 45, .plyometric, ["Quads", "Glutes"], "Heavier band, maintain explosion"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_fl_d5", dayNumber: 5, variant: "A", title: "Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("pjf_fl_d5_1", "Split Stance Hip Flexor Reach with Band", 2, "8 each", 30, .mobility, ["Hip Flexors"], "Deeper stretch with band distraction"),
                tex("pjf_fl_d5_2", "Banded Ankle CARs", 3, "10 each", 20, .mobility, ["Ankles"], "Full circles against resistance"),
                tex("pjf_fl_d5_3", "Supine Banded Leg Raises", 3, "12 each", 30, .mobility, ["Hip Flexors"], "Both directions, slow and controlled"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    static let pjfBandEliteDays: [TrainingDay] = [
        TrainingDay(
            id: "pjf_e_d1", dayNumber: 1, variant: "A", title: "Max Power (Band)",
            category: .strength,
            warmUp: [
                tex("pjf_e_w1", "Band Resisted Skips (Max Intent)", 4, "50 ft", 45, .plyometric, ["Full Body"], "Maximum height and drive each rep"),
                tex("pjf_e_w2", "Lateral Bounds with Band (Reactive)", 3, "8 each", 30, .plyometric, ["Full Body"], "Bound and immediately rebound"),
            ],
            mainWork: [
                tex("pjf_e_d1_1", "Resisted RFESS Jumps (Heavy)", 4, "8 each", 90, .plyometric, ["Quads", "Glutes"], "Heavy band, max height each rep"),
                tex("pjf_e_d1_2", "Resisted Repeat Jumps (Continuous)", 4, "10", 90, .plyometric, ["Full Body"], "No pause between jumps, band loaded"),
                tex("pjf_e_d1_3", "Resisted Broad Jump to Vertical", 4, "6", 120, .plyometric, ["Full Body"], "Chain horizontal to vertical against band"),
                tex("pjf_e_d1_4", "Neural Drive Sprints (Band)", 5, "20m", 120, .agility, ["Full Body"], "Maximum recruitment, heavy band resistance"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_e_d2", dayNumber: 2, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                texLeveled("pjf_e_d2_1", "Maximal Yielding Hamstring Iso", 3, "45s each", 60, .strength, ["Hamstrings"], "Extended hold at end range, max effort"),
                tex("pjf_e_d2_2", "Half Kneel Underhand Press (Heavy Band)", 3, "10 each", 45, .strength, ["Shoulders", "Core"], "Heavy band, maintain hip distraction"),
                tex("pjf_e_d2_3", "3-Way Hip Hinge Deep Holds", 3, "20s each way", 30, .mobility, ["Hips", "Hamstrings"], "Hold end range each direction"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_e_d3", dayNumber: 3, variant: "A", title: "Max Intent Jumping (Band)",
            category: .maxIntent,
            warmUp: [
                tex("pjf_e_w3", "CNS Primers (Resisted)", 2, "5 min", 60, .plyometric, ["Full Body"], "Resisted tuck jumps, A-skips, sprint build-ups"),
            ],
            mainWork: [
                tex("pjf_e_d3_1", "Resisted Approach Jumps", 5, "5", 120, .plyometric, ["Full Body"], "Full approach with band, focus on penultimate step"),
                tex("pjf_e_d3_2", "Resisted Split Stance Rapid Switches (Max)", 4, "8 each", 75, .agility, ["Quads", "Glutes"], "Maximum speed alternating lunges"),
                tex("pjf_e_d3_3", "Resisted Pogos to Free Pogos", 3, "10+10", 60, .plyometric, ["Calves", "Ankles"], "10 banded then immediately 10 free for potentiation"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_e_d4", dayNumber: 4, variant: "A", title: "Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("pjf_e_d4_1", "Lateral Lunge Adductor Stretch (Deep)", 3, "10 each", 30, .mobility, ["Adductors"], "Max depth, breathe into stretch"),
                tex("pjf_e_d4_2", "Floating Toes Dorsiflexion (Heavy)", 3, "15", 30, .mobility, ["Ankles"], "Heavy band, maximize dorsiflexion"),
                tex("pjf_e_d4_3", "Supine Long Length Hamstring Raise (Banded)", 3, "12 each", 30, .mobility, ["Hamstrings"], "Full range with band assistance"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pjf_e_d5", dayNumber: 5, variant: "A", title: "Elite Agility (Band)",
            category: .strength,
            warmUp: [
                tex("pjf_e_w4", "Band Resisted Lateral Walks (Heavy)", 3, "15 each", 20, .agility, ["Hip Abductors"], "Heavy band, stay low and controlled"),
            ],
            mainWork: [
                tex("pjf_e_d5_1", "Lateral Split Stance Decels (Loaded)", 4, "10", 75, .agility, ["Quads", "Core"], "Band-loaded deceleration drills"),
                tex("pjf_e_d5_2", "Cross Step Change of Direction (Max)", 4, "8", 75, .agility, ["Hips", "Quads"], "Max speed direction changes"),
                tex("pjf_e_d5_3", "Diagonal Split Lateral Jumps (Reactive)", 3, "10", 60, .plyometric, ["Full Body"], "Immediate rebound on each landing"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - Total Body Board Programs

    static let tbbFoundationsProgram = TrainingProgram(
        id: "tbb_foundations", track: .foundations, equipment: .totalBodyBoard, weeks: 6, days: tbbFoundationsDays
    )
    static let tbbFlightProgram = TrainingProgram(
        id: "tbb_flight", track: .flight, equipment: .totalBodyBoard, weeks: 8, days: tbbFlightDays
    )
    static let tbbEliteProgram = TrainingProgram(
        id: "tbb_elite", track: .elite, equipment: .totalBodyBoard, weeks: 12, days: tbbEliteDays
    )

    static let tbbFoundationsDays: [TrainingDay] = [
        TrainingDay(
            id: "tbb_f_d1", dayNumber: 1, variant: "A", title: "Mobility & Patterning",
            category: .recovery,
            warmUp: [
                tex("tbb_f_w1", "Dynamic Stretching", 1, "5-10 min", 0, .mobility, ["Full Body"], "Hip openers, arm circles, thoracic rotations"),
                tex("tbb_f_w2", "Bodyweight Squats", 2, "10-15", 30, .strength, ["Quads", "Glutes"], "Full depth, control tempo"),
            ],
            mainWork: [
                tex("tbb_f_d1_1", "Lateral Step-Ups on Board", 3, "10 each", 45, .strength, ["Quads", "Glutes", "Hip Abductors"], "Step up laterally onto board, control descent"),
                tex("tbb_f_d1_2", "Single-Leg Balance with Reach on Board", 3, "8 each", 45, .mobility, ["Ankles", "Core", "Hips"], "Stand on board, reach in multiple directions"),
                tex("tbb_f_d1_3", "Hip Hinge with Board Resistance", 3, "10", 45, .strength, ["Hamstrings", "Glutes"], "Hinge while maintaining board stability"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_f_d2", dayNumber: 2, variant: "A", title: "Strength & Agility",
            category: .strength,
            warmUp: [
                tex("tbb_f_w3", "Band Resisted Lateral Walks", 3, "10 each", 20, .agility, ["Hip Abductors", "Glutes"], "Stay low, resist band"),
                tex("tbb_f_w4", "High Knees", 2, "30s", 20, .agility, ["Hip Flexors", "Calves"], "Drive knees high, quick tempo"),
            ],
            mainWork: [
                tex("tbb_f_d2_1", "Push-Ups on Total Body Board", 3, "8-12", 60, .strength, ["Chest", "Triceps", "Core"], "Hands on board edges, full range, engage stabilizers"),
                tex("tbb_f_d2_2", "Squats with Board Resistance", 3, "10-15", 60, .strength, ["Quads", "Glutes", "Core"], "Stand on board, maintain balance through full squat"),
                tex("tbb_f_d2_3", "Plank to Shoulder Tap on Board", 3, "10 each", 45, .strength, ["Core", "Shoulders"], "Plank on board, tap opposite shoulder without rotating"),
                tex("tbb_f_d2_4", "Lateral Bounds on Board", 3, "6 each", 60, .plyometric, ["Hip Abductors", "Quads"], "Bound laterally onto and off board"),
                tex("tbb_f_d2_5", "Forward-Backward Board Hops", 3, "8", 45, .plyometric, ["Calves", "Quads"], "Quick hops over board, minimize ground contact"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_f_d3", dayNumber: 3, variant: "A", title: "Speed & Power",
            category: .strength,
            warmUp: [
                tex("tbb_f_w5", "Skipping", 2, "30 ft", 20, .agility, ["Full Body"], "Light, rhythmic skipping to warm up"),
                tex("tbb_f_w6", "Butt Kicks", 2, "30s", 20, .agility, ["Hamstrings", "Quads"], "Quick heel-to-glute tempo"),
            ],
            mainWork: [
                tex("tbb_f_d3_1", "Board Jumps (Broad/Vertical)", 3, "6", 75, .plyometric, ["Full Body"], "Jump onto board, step off, or jump over for height"),
                tex("tbb_f_d3_2", "Medicine Ball Slams on Board", 3, "8", 60, .plyometric, ["Core", "Shoulders", "Full Body"], "Slam from board stance, maintain balance"),
                tex("tbb_f_d3_3", "Resisted Sprints from Board Start", 3, "20 yds", 90, .agility, ["Full Body"], "Start on board, explode into sprint"),
                tex("tbb_f_d3_4", "Rotational Lunges on Board", 3, "10 each", 60, .strength, ["Quads", "Core", "Hips"], "Lunge onto board with torso rotation"),
                tex("tbb_f_d3_5", "Single-Leg Deadlift on Board", 3, "8 each", 60, .strength, ["Hamstrings", "Glutes", "Core"], "Stand on board, hinge on one leg"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_f_d4", dayNumber: 4, variant: "A", title: "Recovery & Isometrics",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("tbb_f_d4_1", "Standing Calf Raises on Board", 3, "15", 30, .strength, ["Calves"], "Full range on board edge, 2s pause at top"),
                tex("tbb_f_d4_2", "Side-Lying Leg Lifts on Board", 3, "12 each", 30, .strength, ["Hip Abductors", "Glutes"], "Lie with hip on board, controlled lifts"),
                tex("tbb_f_d4_3", "Isometric Squat Hold on Board", 3, "30-45s", 45, .strength, ["Quads", "Core"], "Hold deep squat on board, maintain stability"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_f_d5", dayNumber: 5, variant: "A", title: "Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("tbb_f_d5_1", "Board Balance Holds", 3, "30s each", 20, .mobility, ["Ankles", "Core"], "Stand on board, eyes open then closed"),
                tex("tbb_f_d5_2", "Toe CARs on Board", 2, "10 each", 20, .mobility, ["Toes", "Feet"], "Full range toe circles while balancing"),
                tex("tbb_f_d5_3", "Hip Opener Stretch on Board", 2, "30s each", 30, .mobility, ["Hips", "Groin"], "Use board for elevated hip stretch"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    static let tbbFlightDays: [TrainingDay] = [
        TrainingDay(
            id: "tbb_fl_d1", dayNumber: 1, variant: "A", title: "Explosive Board Strength",
            category: .strength,
            warmUp: [
                tex("tbb_fl_w1", "Mini Band Warm Up on Board", 2, "10 each", 20, .mobility, ["Glutes", "Hips"], "Lateral walks on board, clamshells"),
            ],
            mainWork: [
                tex("tbb_fl_d1_1", "Deadlifts on Total Body Board", 3, "8-10", 90, .strength, ["Posterior Chain", "Core"], "Stand on board, maintain flat back through deadlift"),
                tex("tbb_fl_d1_2", "Overhead Press on Board", 3, "8-10", 75, .strength, ["Shoulders", "Core"], "Press overhead while balancing on board"),
                tex("tbb_fl_d1_3", "Renegade Rows on Board", 3, "8 each", 75, .strength, ["Back", "Core", "Biceps"], "Plank on board, row dumbbell to hip"),
                tex("tbb_fl_d1_4", "Board Jump Squats", 3, "10", 60, .plyometric, ["Quads", "Glutes"], "Squat on board then explode upward"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_fl_d2", dayNumber: 2, variant: "A", title: "Agility & Power",
            category: .strength,
            warmUp: [
                tex("tbb_fl_w2", "Board Balance Drill", 2, "30s each", 20, .mobility, ["Ankles", "Core"], "Single-leg balance challenges on board"),
            ],
            mainWork: [
                tex("tbb_fl_d2_1", "Agility Ladder Drills on Board", 3, "30s", 45, .agility, ["Full Body"], "Quick feet patterns stepping on/off board"),
                tex("tbb_fl_d2_2", "Lateral Step Down on Board", 3, "6 each", 75, .strength, ["Quads", "Glutes"], "Controlled lateral step down from board"),
                tex("tbb_fl_d2_3", "Board Depth Drops", 3, "6", 90, .plyometric, ["Quads", "Calves"], "Step off board, absorb and freeze landing"),
                tex("tbb_fl_d2_4", "Rotational Hops Over Board", 3, "8", 60, .plyometric, ["Core", "Quads"], "90° rotation hop over the board"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_fl_d3", dayNumber: 3, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("tbb_fl_d3_1", "Single-Leg Balance on Board (Eyes Closed)", 3, "30s each", 30, .mobility, ["Ankles", "Core"], "Progress to eyes closed for proprioception"),
                tex("tbb_fl_d3_2", "Isometric Lunge Hold on Board", 3, "30s each", 45, .strength, ["Quads", "Hip Flexors"], "Front foot on board, hold deep lunge"),
                tex("tbb_fl_d3_3", "Board Calf Raise Iso Holds", 3, "20s", 30, .strength, ["Calves"], "Hold at peak contraction on board edge"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_fl_d4", dayNumber: 4, variant: "A", title: "Max Intent Board Work",
            category: .maxIntent,
            warmUp: [
                tex("tbb_fl_w3", "Dynamic Warm Up on Board", 2, "5 min", 60, .mobility, ["Full Body"], "Board balance, light hops, ankle circles"),
            ],
            mainWork: [
                tex("tbb_fl_d4_1", "Board to Max Vertical Jump", 4, "5", 120, .plyometric, ["Full Body"], "Stand on board, step off, explode to max height"),
                tex("tbb_fl_d4_2", "Single-Leg Board Hops to Stick", 3, "6 each", 90, .plyometric, ["Calves", "Quads"], "Hop off board onto one leg, stick 2s"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_fl_d5", dayNumber: 5, variant: "A", title: "Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("tbb_fl_d5_1", "Board Ankle CARs", 3, "10 each", 20, .mobility, ["Ankles"], "Full ankle circles while balancing on board"),
                tex("tbb_fl_d5_2", "Hip Opener on Board", 3, "30s each", 30, .mobility, ["Hips"], "Elevated hip stretches using board"),
                tex("tbb_fl_d5_3", "Prone Board Back Extension", 2, "12", 30, .recovery, ["Lower Back", "Glutes"], "Lie prone on board, controlled extensions"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    static let tbbEliteDays: [TrainingDay] = [
        TrainingDay(
            id: "tbb_e_d1", dayNumber: 1, variant: "A", title: "Max Strength (Board)",
            category: .strength,
            warmUp: [
                tex("tbb_e_w1", "CNS Activation on Board", 2, "3 min", 60, .plyometric, ["Full Body"], "Board hops, tuck jumps from board, clap push-ups on board"),
            ],
            mainWork: [
                tex("tbb_e_d1_1", "Deadlifts on Board (Heavy)", 4, "5", 120, .strength, ["Posterior Chain", "Core"], "Heavy load, maintain board stability"),
                tex("tbb_e_d1_2", "Overhead Press on Board (Heavy)", 4, "6", 90, .strength, ["Shoulders", "Core"], "Heavier load, strict press from board"),
                tex("tbb_e_d1_3", "Renegade Rows on Board (Heavy)", 4, "8 each", 90, .strength, ["Back", "Core"], "Heavier dumbbells, maintain plank on board"),
                tex("tbb_e_d1_4", "Explosive Board Squat to Jump", 4, "6", 90, .plyometric, ["Quads", "Glutes"], "Deep board squat, explode to max height"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_e_d2", dayNumber: 2, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("tbb_e_d2_1", "Single-Leg Board Balance (Reactive)", 3, "30s each", 30, .mobility, ["Ankles", "Core"], "Eyes closed, partner perturbations"),
                tex("tbb_e_d2_2", "Isometric Squat Hold on Board (Deep)", 3, "45s", 60, .strength, ["Quads", "Core"], "Max depth hold with stability challenge"),
                tex("tbb_e_d2_3", "Board Calf Raise Eccentrics", 3, "10 each", 45, .strength, ["Calves"], "Slow 5s eccentric on board edge"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_e_d3", dayNumber: 3, variant: "A", title: "Max Intent Board Session",
            category: .maxIntent,
            warmUp: [
                tex("tbb_e_w2", "Full CNS Warm Up (Board)", 2, "8 min", 60, .mobility, ["Full Body"], "Board hops, sprint build-ups, approach rehearsals"),
            ],
            mainWork: [
                tex("tbb_e_d3_1", "Board Drop to Max Vertical", 5, "5", 120, .plyometric, ["Full Body"], "Step off board into max vertical, track height"),
                tex("tbb_e_d3_2", "Board Reactive Series", 4, "6", 90, .plyometric, ["Full Body"], "Board hop → stick → explode, continuous chain"),
                tex("tbb_e_d3_3", "Single-Leg Board to Bound", 3, "5 each", 120, .plyometric, ["Full Body"], "Single leg on board, step off, max distance bound"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_e_d4", dayNumber: 4, variant: "A", title: "Recovery + Pilates",
            category: .recoveryPilates,
            warmUp: [],
            mainWork: [
                tex("tbb_e_d4_1", "Hand Walk Out on Board", 3, "8", 30, .mobility, ["Hamstrings", "Shoulders"], "Hands on board, walk out to plank"),
                tex("tbb_e_d4_2", "Board Swimming", 3, "30s", 30, .recovery, ["Back", "Glutes"], "Prone on board, alternating limb lifts"),
                tex("tbb_e_d4_3", "Thread the Needle on Board", 3, "8 each", 30, .mobility, ["Thoracic Spine"], "Kneel on board for added instability"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "tbb_e_d5", dayNumber: 5, variant: "A", title: "Elite Agility (Board)",
            category: .strength,
            warmUp: [
                tex("tbb_e_w3", "Board Agility Circuit", 2, "3 min", 30, .agility, ["Full Body"], "Multi-directional hops on/off board"),
            ],
            mainWork: [
                tex("tbb_e_d5_1", "Lateral Board Hops (Reactive)", 4, "10", 60, .plyometric, ["Hip Abductors", "Quads"], "Rapid lateral hops over board"),
                tex("tbb_e_d5_2", "Board Depth Jump to Broad", 4, "5", 120, .plyometric, ["Full Body"], "Step off board, absorb, redirect horizontal"),
                tex("tbb_e_d5_3", "Single-Leg Board Step Down (Weighted)", 3, "8 each", 75, .strength, ["Quads", "Glutes"], "Weighted step down from board"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - Push-Pull-Hinge Programs

    static let pphFoundationsProgram = TrainingProgram(
        id: "pph_foundations", track: .foundations, equipment: .pushPullHinge, weeks: 6, days: pphFoundationsDays
    )
    static let pphFlightProgram = TrainingProgram(
        id: "pph_flight", track: .flight, equipment: .pushPullHinge, weeks: 8, days: pphFlightDays
    )
    static let pphEliteProgram = TrainingProgram(
        id: "pph_elite", track: .elite, equipment: .pushPullHinge, weeks: 12, days: pphEliteDays
    )

    // MARK: - PPH Foundations Days

    static let pphFoundationsDays: [TrainingDay] = [
        TrainingDay(
            id: "pph_f_d1", dayNumber: 1, variant: "A", title: "Push Day",
            category: .strength,
            warmUp: [
                tex("pph_f_w1", "Arm Circles", 2, "30s", 0, .mobility, ["Shoulders"], "Forward and backward, increasing range"),
                tex("pph_f_w2", "Shoulder Dislocations (Band/Stick)", 2, "10", 20, .mobility, ["Shoulders", "Chest"], "Slow, controlled full arc"),
                tex("pph_f_w3", "Push-Up Progression", 2, "8-10", 30, .strength, ["Chest", "Triceps", "Shoulders"], "Scale to ability — incline, standard, or deficit"),
            ],
            mainWork: [
                tex("pph_f_d1_1", "Barbell Bench Press", 4, "6-8", 90, .strength, ["Chest", "Triceps", "Shoulders"], "Control eccentric, drive through chest"),
                tex("pph_f_d1_2", "Dynamic Shoulder Press (Split Stance to Stand)", 3, "8-10", 75, .strength, ["Shoulders", "Core", "Legs"], "Press as you drive up from split stance to standing"),
                tex("pph_f_d1_3", "Incline Push-Ups", 3, "10-12", 60, .strength, ["Upper Chest", "Triceps"], "Hands elevated, full range of motion"),
                tex("pph_f_d1_4", "Dips (Bench or Parallel Bars)", 3, "6-8", 75, .strength, ["Triceps", "Chest", "Shoulders"], "Lean slightly forward for chest emphasis"),
                tex("pph_f_d1_5", "Lateral Raises", 3, "10-12", 45, .strength, ["Lateral Deltoids"], "Slight bend in elbows, control the negative"),
                tex("pph_f_d1_6", "Split Stance Rotational Fly", 3, "8-10 each", 60, .strength, ["Chest", "Core", "Shoulders"], "Rotate through thoracic as you fly, maintain split stance"),
                tex("pph_f_d1_7", "Reverse Fly", 3, "10-12", 45, .strength, ["Rear Deltoids", "Rhomboids"], "Squeeze scapulae together at peak contraction"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_f_d2", dayNumber: 2, variant: "A", title: "Pull Day",
            category: .strength,
            warmUp: [
                tex("pph_f_w4", "Arm Swings", 2, "30s", 0, .mobility, ["Shoulders", "Back"], "Cross-body swings, gradually increase range"),
                tex("pph_f_w5", "Torso Twists", 2, "10 each", 20, .mobility, ["Thoracic Spine", "Core"], "Rotate through mid-back, hips stable"),
                tex("pph_f_w6", "Band Pull-Aparts", 2, "10-15", 20, .strength, ["Rear Deltoids", "Rhomboids"], "Pull band to chest height, squeeze back"),
            ],
            mainWork: [
                tex("pph_f_d2_1", "Pull-Ups / Assisted Pull-Ups", 4, "5-8", 90, .strength, ["Lats", "Biceps", "Core"], "Full hang to chin over bar, control descent"),
                tex("pph_f_d2_2", "Barbell Bent Over Row", 4, "6-8", 90, .strength, ["Back", "Biceps", "Core"], "Hinge at hips 45°, pull to lower chest"),
                tex("pph_f_d2_3", "One-Arm Dumbbell Row", 3, "8-10 each", 60, .strength, ["Lats", "Biceps", "Core"], "Pull to hip, 1s squeeze at top"),
                tex("pph_f_d2_4", "Face Pulls", 3, "10-12", 45, .strength, ["Rear Deltoids", "Rotator Cuff"], "Pull to forehead level, externally rotate at peak"),
                tex("pph_f_d2_5", "Bicep Curls", 3, "10-12", 45, .strength, ["Biceps"], "Full range, no swinging"),
                tex("pph_f_d2_6", "Rear Delt Flys", 3, "10-12", 45, .strength, ["Rear Deltoids", "Upper Back"], "Bent over, squeeze scapulae at top"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_f_d3", dayNumber: 3, variant: "A", title: "Hinge Day",
            category: .strength,
            warmUp: [
                tex("pph_f_w7", "Leg Swings (Front/Back + Lateral)", 2, "10 each", 0, .mobility, ["Hips", "Hamstrings"], "Control at end range, increase amplitude"),
                tex("pph_f_w8", "Hip Circles", 2, "10 each", 20, .mobility, ["Hips"], "Full range circles both directions"),
                tex("pph_f_w9", "Bodyweight Good Mornings", 2, "10-15", 20, .mobility, ["Hamstrings", "Lower Back"], "Hands behind head, hinge at hips"),
            ],
            mainWork: [
                tex("pph_f_d3_1", "Deadlifts (Conventional or Romanian)", 4, "6-8", 120, .strength, ["Hamstrings", "Glutes", "Back"], "Brace core, hinge at hips, neutral spine throughout"),
                tex("pph_f_d3_2", "Kettlebell Swings", 3, "10-15", 60, .strength, ["Glutes", "Hamstrings", "Core"], "Snap hips, squeeze glutes at top"),
                tex("pph_f_d3_3", "Single-Leg Deadlift", 3, "8-10 each", 60, .strength, ["Hamstrings", "Glutes", "Core"], "Reach long, maintain flat back"),
                tex("pph_f_d3_4", "Hip Thrusts", 3, "8-10", 75, .strength, ["Glutes", "Hamstrings"], "Drive through heels, 2s squeeze at top"),
                tex("pph_f_d3_5", "Hamstring Curls (Machine or Ball)", 3, "10-12", 60, .strength, ["Hamstrings"], "Control eccentric, squeeze at peak"),
                tex("pph_f_d3_6", "Plank Variations", 3, "30-45s", 45, .strength, ["Core"], "Front, side, or weighted — maintain neutral spine"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_f_d4", dayNumber: 4, variant: "A", title: "Active Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("pph_f_d4_1", "Light Cardio (Jog/Cycle/Swim)", 1, "20-30 min", 0, .recovery, ["Full Body"], "Conversational pace, keep heart rate moderate"),
                tex("pph_f_d4_2", "Foam Rolling — Quads & Hamstrings", 2, "60s each", 20, .recovery, ["Quads", "Hamstrings"], "Slow rolls, pause on tender spots"),
                tex("pph_f_d4_3", "Foam Rolling — Thoracic & Calves", 2, "60s each", 20, .recovery, ["Thoracic Spine", "Calves"], "Extend over roller for thoracic mobility"),
                tex("pph_f_d4_4", "Dynamic Stretches — Full Body", 2, "5 min", 0, .mobility, ["Full Body"], "Leg swings, arm circles, hip openers, world's greatest stretch"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_f_d5", dayNumber: 5, variant: "A", title: "Performance Combo",
            category: .strength,
            warmUp: [
                tex("pph_f_w10", "Full Body Dynamic Warm-Up", 2, "5 min", 30, .mobility, ["Full Body"], "Multi-planar movements, build to moderate intensity"),
                tex("pph_f_w11", "Agility Drills", 2, "30s", 30, .agility, ["Full Body"], "Ladder, cone cuts, or lateral shuffles"),
            ],
            mainWork: [
                tex("pph_f_d5_1", "Push Press", 4, "6-8", 90, .strength, ["Shoulders", "Triceps", "Legs"], "Dip and drive, use leg power to initiate press"),
                tex("pph_f_d5_2", "Power Clean", 4, "3-5", 120, .strength, ["Full Body"], "Triple extension, catch in front rack"),
                tex("pph_f_d5_3", "Medicine Ball Slams", 3, "8-10", 60, .plyometric, ["Core", "Lats", "Shoulders"], "Full overhead, slam with max intent"),
                tex("pph_f_d5_4", "Box Jumps", 3, "6", 90, .plyometric, ["Quads", "Glutes", "Calves"], "Soft landing, step down, reset each rep"),
                tex("pph_f_d5_5", "Farmers Walk", 3, "30-60s", 60, .strength, ["Grip", "Core", "Traps"], "Tall posture, heavy load, controlled steps"),
                tex("pph_f_d5_6", "Core Circuit (Russian Twists + Bicycle Crunches + Plank)", 3, "1 round", 60, .strength, ["Core", "Obliques"], "15 twists, 15 bicycles, 30s plank per round"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - PPH Flight Days

    static let pphFlightDays: [TrainingDay] = [
        TrainingDay(
            id: "pph_fl_d1", dayNumber: 1, variant: "A", title: "Explosive Push",
            category: .strength,
            warmUp: [
                tex("pph_fl_w1", "Shoulder Dislocations", 2, "10", 20, .mobility, ["Shoulders"], "Controlled arc, gradually narrow grip"),
                tex("pph_fl_w2", "Plyo Push-Ups", 2, "6", 30, .plyometric, ["Chest", "Triceps"], "Explosive push, hands leave ground"),
            ],
            mainWork: [
                tex("pph_fl_d1_1", "Barbell Bench Press (Heavy)", 4, "5-6", 120, .strength, ["Chest", "Triceps", "Shoulders"], "Control descent, explosive drive off chest"),
                tex("pph_fl_d1_2", "Dynamic Shoulder Press (Split Stance to Stand)", 4, "8 each", 75, .strength, ["Shoulders", "Core", "Legs"], "Explode from split stance to standing press"),
                tex("pph_fl_d1_3", "Weighted Dips", 4, "6-8", 90, .strength, ["Triceps", "Chest", "Shoulders"], "Add load via belt or dumbbell between feet"),
                tex("pph_fl_d1_4", "Incline Dumbbell Press", 3, "8-10", 75, .strength, ["Upper Chest", "Shoulders"], "30° incline, full range of motion"),
                tex("pph_fl_d1_5", "Split Stance Rotational Fly", 3, "10 each", 60, .strength, ["Chest", "Core", "Shoulders"], "Rotate through thoracic, feel stretch at bottom"),
                tex("pph_fl_d1_6", "Reverse Fly (Incline Bench)", 3, "10-12", 45, .strength, ["Rear Deltoids", "Rhomboids"], "Prone on incline bench, squeeze back at top"),
                tex("pph_fl_d1_7", "Lateral Raises (Controlled Tempo)", 3, "12", 45, .strength, ["Lateral Deltoids"], "3s up, 3s down, constant tension"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_fl_d2", dayNumber: 2, variant: "A", title: "Power Pull",
            category: .strength,
            warmUp: [
                tex("pph_fl_w3", "Band Pull-Aparts", 2, "15", 20, .strength, ["Rear Deltoids"], "Chest height, squeeze back"),
                tex("pph_fl_w4", "Scapular Pull-Ups", 2, "8", 30, .strength, ["Lats", "Scapulae"], "Dead hang, retract scapulae only"),
            ],
            mainWork: [
                tex("pph_fl_d2_1", "Weighted Pull-Ups", 4, "5-8", 120, .strength, ["Lats", "Biceps", "Core"], "Add load, full range, controlled negative"),
                tex("pph_fl_d2_2", "Pendlay Row", 4, "6-8", 90, .strength, ["Back", "Biceps"], "Explosive pull from dead stop, back to floor each rep"),
                tex("pph_fl_d2_3", "Chest-Supported Row", 3, "10", 60, .strength, ["Back", "Rear Deltoids"], "Incline bench, pull to sternum"),
                tex("pph_fl_d2_4", "Face Pulls (Rope)", 3, "12-15", 45, .strength, ["Rear Deltoids", "Rotator Cuff"], "High pull, external rotation at end"),
                tex("pph_fl_d2_5", "Hammer Curls", 3, "10-12", 45, .strength, ["Biceps", "Brachialis"], "Neutral grip, no swinging"),
                tex("pph_fl_d2_6", "Rear Delt Cable Fly", 3, "12", 45, .strength, ["Rear Deltoids", "Upper Back"], "Cables at face height, reverse fly pattern"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_fl_d3", dayNumber: 3, variant: "A", title: "Explosive Hinge",
            category: .strength,
            warmUp: [
                tex("pph_fl_w5", "Hip Circles + Leg Swings", 2, "10 each", 0, .mobility, ["Hips", "Hamstrings"], "Multi-directional, build range"),
                tex("pph_fl_w6", "Broad Jump (Max Intent)", 3, "5", 45, .plyometric, ["Full Body"], "Max distance, full arm swing"),
            ],
            mainWork: [
                tex("pph_fl_d3_1", "Trap Bar Deadlift (Heavy)", 4, "5-6", 120, .strength, ["Quads", "Glutes", "Hamstrings", "Back"], "Drive through floor, lock out hips"),
                tex("pph_fl_d3_2", "Kettlebell Swings (Heavy)", 4, "12", 75, .strength, ["Glutes", "Hamstrings", "Core"], "Aggressive hip snap, bell to chest height"),
                tex("pph_fl_d3_3", "Single-Leg RDL (Loaded)", 3, "8 each", 75, .strength, ["Hamstrings", "Glutes", "Core"], "Dumbbell opposite hand, reach for control"),
                tex("pph_fl_d3_4", "Hip Thrust (Heavy)", 4, "8", 90, .strength, ["Glutes", "Hamstrings"], "Barbell loaded, 2s pause at top"),
                tex("pph_fl_d3_5", "Nordic Hamstring Curl", 3, "5-8", 90, .strength, ["Hamstrings"], "Control eccentric as long as possible"),
                tex("pph_fl_d3_6", "Hanging Leg Raises", 3, "10-12", 60, .strength, ["Core", "Hip Flexors"], "Slow and controlled, no swinging"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_fl_d4", dayNumber: 4, variant: "A", title: "Active Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("pph_fl_d4_1", "Light Cardio (Jog/Cycle/Swim)", 1, "25-30 min", 0, .recovery, ["Full Body"], "Zone 2, conversational pace"),
                tex("pph_fl_d4_2", "Foam Rolling — Full Body", 2, "8 min", 0, .recovery, ["Full Body"], "Quads, hamstrings, thoracic, lats, calves"),
                tex("pph_fl_d4_3", "Dynamic Mobility Flow", 2, "5 min", 0, .mobility, ["Full Body"], "World's greatest stretch, hip openers, thoracic rotations"),
                tex("pph_fl_d4_4", "Diaphragmatic Breathing", 2, "3 min", 0, .recovery, ["Core", "Diaphragm"], "4s inhale, 6s exhale, feel ribs expand laterally"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_fl_d5", dayNumber: 5, variant: "A", title: "Power Performance",
            category: .strength,
            warmUp: [
                tex("pph_fl_w7", "Dynamic Warm-Up Circuit", 2, "5 min", 30, .mobility, ["Full Body"], "A-skips, high knees, lateral shuffles"),
                tex("pph_fl_w8", "Depth Drop to Stick", 3, "5", 45, .plyometric, ["Quads", "Calves"], "Step off box, absorb and freeze"),
            ],
            mainWork: [
                tex("pph_fl_d5_1", "Push Press (Heavy)", 4, "5-6", 120, .strength, ["Shoulders", "Triceps", "Legs"], "Aggressive dip-drive, lock out overhead"),
                tex("pph_fl_d5_2", "Power Clean", 4, "3-5", 120, .strength, ["Full Body"], "Triple extension, fast elbows under bar"),
                tex("pph_fl_d5_3", "Rotational Medicine Ball Throw", 3, "8 each", 60, .plyometric, ["Core", "Obliques", "Hips"], "Max rotation, release at wall"),
                tex("pph_fl_d5_4", "Depth Jump to Max Vertical", 4, "5", 120, .plyometric, ["Quads", "Calves", "Glutes"], "Step off box, minimize ground contact, max height"),
                tex("pph_fl_d5_5", "Farmers Walk (Heavy)", 3, "45-60s", 90, .strength, ["Grip", "Core", "Traps"], "Heavy load, brisk pace, tall posture"),
                tex("pph_fl_d5_6", "Anti-Rotation Core Circuit", 3, "1 round", 60, .strength, ["Core", "Obliques"], "Pallof press 10 each + plank shoulder taps 10 each + dead bug 10"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: - PPH Elite Days

    static let pphEliteDays: [TrainingDay] = [
        TrainingDay(
            id: "pph_e_d1", dayNumber: 1, variant: "A", title: "Max Push",
            category: .strength,
            warmUp: [
                tex("pph_e_w1", "Shoulder CARs", 2, "8 each", 20, .mobility, ["Shoulders"], "Full range controlled articular rotations"),
                tex("pph_e_w2", "Plyo Push-Ups", 3, "5", 30, .plyometric, ["Chest", "Triceps"], "Clap or hands off ground each rep"),
            ],
            mainWork: [
                tex("pph_e_d1_1", "Barbell Bench Press (Max Effort)", 5, "3-5", 150, .strength, ["Chest", "Triceps", "Shoulders"], "Work to heavy 3-5 RM, spotter recommended"),
                tex("pph_e_d1_2", "Dynamic Shoulder Press (Split to Stand, Loaded)", 4, "6 each", 90, .strength, ["Shoulders", "Core", "Legs"], "Heavier load, explosive transition to standing"),
                tex("pph_e_d1_3", "Weighted Dips (Heavy)", 4, "5-6", 120, .strength, ["Triceps", "Chest", "Shoulders"], "Max load you can control for full range"),
                tex("pph_e_d1_4", "Landmine Press", 3, "8 each", 75, .strength, ["Shoulders", "Core"], "Single arm, press at 45° angle"),
                tex("pph_e_d1_5", "Split Stance Rotational Fly (Loaded)", 3, "8 each", 60, .strength, ["Chest", "Core", "Shoulders"], "Cable or heavy dumbbell, rotational emphasis"),
                tex("pph_e_d1_6", "Reverse Fly (Band or Cable)", 3, "12", 45, .strength, ["Rear Deltoids", "Rhomboids"], "Constant tension, full squeeze"),
                tex("pph_e_d1_7", "Lateral Raise 21s", 3, "21", 60, .strength, ["Lateral Deltoids"], "7 bottom half, 7 top half, 7 full range"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_e_d2", dayNumber: 2, variant: "A", title: "Max Pull",
            category: .strength,
            warmUp: [
                tex("pph_e_w3", "Scapular Pull-Ups", 2, "10", 20, .strength, ["Scapulae", "Lats"], "Retract and depress scapulae from dead hang"),
                tex("pph_e_w4", "Band Pull-Aparts (Various Angles)", 2, "15", 20, .strength, ["Rear Deltoids", "Rotator Cuff"], "Overhead, chest, and waist angles"),
            ],
            mainWork: [
                tex("pph_e_d2_1", "Weighted Pull-Ups (Max Effort)", 5, "3-5", 150, .strength, ["Lats", "Biceps", "Core"], "Heavy load, full range, controlled 3s negative"),
                tex("pph_e_d2_2", "Barbell Row (Heavy)", 4, "5-6", 120, .strength, ["Back", "Biceps", "Core"], "Strict form, pull to lower sternum"),
                tex("pph_e_d2_3", "Meadows Row", 3, "8 each", 75, .strength, ["Lats", "Rear Deltoids"], "Landmine row, pull to hip, stretch at bottom"),
                tex("pph_e_d2_4", "Face Pulls + External Rotation", 3, "15", 45, .strength, ["Rear Deltoids", "Rotator Cuff"], "High pull, hold external rotation 2s"),
                tex("pph_e_d2_5", "Barbell Curl", 3, "8-10", 60, .strength, ["Biceps"], "Strict form, squeeze at top"),
                tex("pph_e_d2_6", "Rear Delt Fly (Heavy)", 3, "10", 45, .strength, ["Rear Deltoids", "Upper Back"], "Max load with control"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_e_d3", dayNumber: 3, variant: "A", title: "Max Hinge",
            category: .strength,
            warmUp: [
                tex("pph_e_w5", "Hip CARs", 2, "8 each", 20, .mobility, ["Hips"], "Full range controlled articular rotations"),
                tex("pph_e_w6", "Broad Jump (Max Distance)", 3, "3", 60, .plyometric, ["Full Body"], "Full arm swing, max intent each rep"),
            ],
            mainWork: [
                tex("pph_e_d3_1", "Deadlift (Max Effort)", 5, "3-5", 180, .strength, ["Hamstrings", "Glutes", "Back"], "Work to heavy 3-5 RM, perfect form non-negotiable"),
                tex("pph_e_d3_2", "Kettlebell Swing (Heavy, Overspeed)", 4, "10", 90, .strength, ["Glutes", "Hamstrings", "Core"], "Banded or heavy KB, maximum hip snap"),
                tex("pph_e_d3_3", "Single-Leg RDL (Heavy)", 4, "6 each", 90, .strength, ["Hamstrings", "Glutes", "Core"], "Loaded with DB or KB, max range"),
                tex("pph_e_d3_4", "Barbell Hip Thrust (Heavy)", 4, "6-8", 90, .strength, ["Glutes", "Hamstrings"], "Heavy barbell, 3s hold at top"),
                tex("pph_e_d3_5", "Nordic Hamstring Curl", 4, "5-8", 90, .strength, ["Hamstrings"], "Full eccentric control, push back to reset"),
                tex("pph_e_d3_6", "Ab Wheel Rollout", 3, "8-10", 60, .strength, ["Core"], "Full extension, brace hard, slow return"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_e_d4", dayNumber: 4, variant: "A", title: "Neural Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("pph_e_d4_1", "Zone 2 Cardio", 1, "25-30 min", 0, .recovery, ["Full Body"], "Light jog, cycle, or swim — stay conversational"),
                tex("pph_e_d4_2", "Contrast Shower Protocol", 1, "10 min", 0, .recovery, ["Full Body"], "2 min hot / 30s cold × 3-4 rounds"),
                tex("pph_e_d4_3", "Foam Rolling + Lacrosse Ball", 2, "10 min", 0, .recovery, ["Full Body"], "Deep tissue focus on quads, glutes, lats, thoracic"),
                tex("pph_e_d4_4", "Diaphragmatic Breathing + Visualization", 2, "5 min", 0, .recovery, ["Core", "Diaphragm"], "Box breathing 4-4-4-4, visualize next session"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "pph_e_d5", dayNumber: 5, variant: "A", title: "Elite Performance",
            category: .maxIntent,
            warmUp: [
                tex("pph_e_w7", "Full CNS Warm-Up", 2, "8 min", 60, .mobility, ["Full Body"], "A-skips, sprints, jumps — build to max intent"),
                tex("pph_e_w8", "Depth Drop to Max Vertical", 3, "3", 60, .plyometric, ["Full Body"], "Step off box, minimize ground contact, explode up"),
            ],
            mainWork: [
                tex("pph_e_d5_1", "Push Press (Max Effort)", 5, "3-5", 150, .strength, ["Shoulders", "Triceps", "Legs"], "Work to heavy 3-5 RM, aggressive leg drive"),
                tex("pph_e_d5_2", "Power Clean (Max Effort)", 5, "2-3", 150, .strength, ["Full Body"], "Max load with clean technique"),
                tex("pph_e_d5_3", "Rotational Med Ball Slam (Max Intent)", 4, "6 each", 90, .plyometric, ["Core", "Obliques", "Hips"], "Maximum rotational velocity"),
                tex("pph_e_d5_4", "Depth Jump to Max Vertical", 4, "5", 120, .plyometric, ["Full Body"], "Higher box, max reactive output"),
                tex("pph_e_d5_5", "Heavy Farmers Walk", 3, "60s", 90, .strength, ["Grip", "Core", "Traps"], "Max load you can maintain posture with"),
                tex("pph_e_d5_6", "Advanced Core Circuit", 3, "1 round", 90, .strength, ["Core", "Obliques"], "Dragon flags 5 + L-sit 15s + pallof press 10 each"),
            ],
            isGated: true, isCompleted: false
        ),
    ]

    // MARK: - Sport-Specific Programs (Basketball & Karate)

    // MARK: Basketball — Beginner

    static let beginnerBasketballProgram = TrainingProgram(
        id: "bball_beginner",
        track: .foundations,
        equipment: .bodyweight,
        weeks: 4,
        days: beginnerBasketballDays
    )

    static let beginnerBasketballDays: [TrainingDay] = [
        TrainingDay(
            id: "bball_b_d1", dayNumber: 1, variant: "A", title: "Foundation Strength A",
            category: .strength,
            warmUp: [
                tex("bball_b_w1", "Jump Rope (or Simulate)", 2, "60s", 30, .agility, ["Calves", "Ankles"], "Quick feet, stay on balls of feet, light cadence"),
                tex("bball_b_w2", "Leg Swings (Front/Back)", 2, "10 each", 20, .mobility, ["Hips", "Hamstrings"], "Hold wall for balance, build range gradually"),
                tex("bball_b_w3", "Arm Circles", 2, "30s", 0, .mobility, ["Shoulders"], "Forward and backward, increasing range"),
            ],
            mainWork: [
                tex("bball_b_d1_1", "Bodyweight Squat", 3, "15", 60, .strength, ["Quads", "Glutes"], "Drive knees over toes, sit to parallel depth"),
                tex("bball_b_d1_2", "Reverse Lunge", 3, "10 each", 60, .strength, ["Quads", "Glutes"], "Step back, back knee hovers an inch from floor"),
                tex("bball_b_d1_3", "Push-Up", 3, "10", 60, .strength, ["Chest", "Triceps", "Shoulders"], "Full range, body rigid — scale to incline if needed"),
                tex("bball_b_d1_4", "Glute Bridge", 3, "12", 45, .strength, ["Glutes", "Hamstrings"], "Drive hips up, squeeze at top, 2s hold"),
                tex("bball_b_d1_5", "Plank Hold", 3, "30s", 45, .strength, ["Core"], "Wrists under shoulders, body straight from head to heels"),
                tex("bball_b_d1_6", "Lateral Shuffle (Court Width)", 3, "30s", 45, .agility, ["Hips", "Quads"], "Low stance, stay on balls of feet, quick side-to-side"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_b_d2", dayNumber: 2, variant: "A", title: "Recovery + Movement",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("bball_b_d2_1", "Foam Roll — Quads + Calves", 2, "60s each", 20, .recovery, ["Quads", "Calves"], "Slow rolls, pause on tender spots"),
                tex("bball_b_d2_2", "Hip Flexor Stretch", 3, "30s each", 20, .mobility, ["Hip Flexors"], "Low lunge position, gentle forward pressure"),
                tex("bball_b_d2_3", "Dribbling Footwork (Stationary)", 2, "2 min", 30, .agility, ["Full Body"], "Triple-threat stance, quick jab steps and pivots"),
                tex("bball_b_d2_4", "Wall Slides", 2, "10", 20, .mobility, ["Shoulders", "Thoracic Spine"], "Back flat on wall, slide arms overhead without arching"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_b_d3", dayNumber: 3, variant: "A", title: "Foundation Strength B",
            category: .strength,
            warmUp: [
                tex("bball_b_w4", "High Knees", 2, "30s", 20, .agility, ["Hip Flexors", "Calves"], "Drive knees to hip height, pump arms"),
                tex("bball_b_w5", "Butt Kicks", 2, "30s", 20, .agility, ["Hamstrings"], "Heels to glutes, quick tempo"),
            ],
            mainWork: [
                tex("bball_b_d3_1", "Step-Up (Box or Bench)", 3, "10 each", 60, .strength, ["Quads", "Glutes"], "Drive through heel, stand fully on top before stepping down"),
                tex("bball_b_d3_2", "Single-Leg Glute Bridge", 3, "10 each", 45, .strength, ["Glutes", "Hamstrings"], "One leg extended, drive single leg hip up"),
                tex("bball_b_d3_3", "Inverted Row (Table or Bar)", 3, "8", 60, .strength, ["Back", "Biceps"], "Body straight, pull chest to surface"),
                tex("bball_b_d3_4", "Calf Raise (Double-Leg)", 3, "20", 30, .strength, ["Calves"], "Full range — from deep dorsiflexion to full plantarflexion"),
                tex("bball_b_d3_5", "Dead Bug", 3, "8 each", 45, .strength, ["Core", "Hip Flexors"], "Lower back pressed to floor, slow and controlled"),
                tex("bball_b_d3_6", "Defensive Slide Drill", 3, "30s", 45, .agility, ["Hip Abductors", "Quads"], "Wide stance, stay low, mirror partner or cone pattern"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_b_d4", dayNumber: 4, variant: "A", title: "Jump Intro + Recovery",
            category: .plyometrics,
            warmUp: [
                tex("bball_b_w6", "Dynamic Warm-Up Circuit", 1, "5 min", 30, .mobility, ["Full Body"], "Leg swings, arm circles, light jog, hip openers"),
            ],
            mainWork: [
                tex("bball_b_d4_1", "Standing Broad Jump", 3, "5", 90, .plyometric, ["Full Body"], "Two-foot take-off, land softly, stick 2 seconds"),
                tex("bball_b_d4_2", "Box Jump (Low Box)", 3, "5", 90, .plyometric, ["Full Body"], "Step off to reset, soft landing, don't drop jump"),
                tex("bball_b_d4_3", "Ankle Mobility CARs", 2, "10 each", 20, .mobility, ["Ankles"], "Seated or standing full ankle circles"),
                tex("bball_b_d4_4", "Static Stretching — Lower Body", 1, "8 min", 0, .recovery, ["Full Body"], "Quads, hamstrings, calves, hip flexors — 30s each"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_b_d5", dayNumber: 5, variant: "A", title: "Skills + Conditioning",
            category: .movementEducation,
            warmUp: [
                tex("bball_b_w7", "Shooting Form (No Ball)", 2, "5 min", 0, .mobility, ["Shoulders", "Core"], "Elbow alignment, wrist snap, balanced base — mirror practice"),
            ],
            mainWork: [
                tex("bball_b_d5_1", "Lay-Up Footwork (Slow)", 3, "10 each side", 45, .agility, ["Full Body"], "Two-step approach, focus on gather step and angle to basket"),
                tex("bball_b_d5_2", "Cone Weave Sprint", 3, "4 lengths", 60, .agility, ["Full Body"], "Weave through 5 cones, 2m spacing, increase speed each set"),
                tex("bball_b_d5_3", "Free Throw Form Practice", 2, "10 shots", 30, .mobility, ["Shoulders", "Core"], "Focus on consistent pre-shot routine and follow-through arc"),
                tex("bball_b_d5_4", "Reactive Jump (Partner Cue or Own)", 3, "6", 60, .plyometric, ["Full Body"], "React on verbal/visual cue, vertical jump max intent"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: Basketball — Intermediate

    static let intermediateBasketballProgram = TrainingProgram(
        id: "bball_intermediate",
        track: .flight,
        equipment: .bodyweight,
        weeks: 4,
        days: intermediateBasketballDays
    )

    static let intermediateBasketballDays: [TrainingDay] = [
        TrainingDay(
            id: "bball_i_d1", dayNumber: 1, variant: "A", title: "Explosive Strength A",
            category: .strength,
            warmUp: [
                tex("bball_i_w1", "Jump Rope (Double Speed)", 3, "60s", 30, .agility, ["Calves", "Ankles"], "Quick cadence, alternate single/double legs"),
                tex("bball_i_w2", "Hip Circles + Lateral Leg Swings", 2, "10 each", 20, .mobility, ["Hips"], "Full range in both planes"),
                tex("bball_i_w3", "Pogos", 2, "20", 20, .plyometric, ["Calves", "Ankles"], "Stiff ankles, quick off ground"),
            ],
            mainWork: [
                tex("bball_i_d1_1", "Bulgarian Split Squat", 4, "8 each", 75, .strength, ["Quads", "Glutes", "Core"], "Rear foot elevated, deep range, drive through front heel"),
                tex("bball_i_d1_2", "Hip Thrust (Loaded)", 4, "10", 75, .strength, ["Glutes", "Hamstrings"], "Barbell or plate, pause 2s at lockout"),
                tex("bball_i_d1_3", "Single-Leg Calf Raise", 3, "15 each", 45, .strength, ["Calves"], "Full range, 2s pause at top, control descent"),
                tex("bball_i_d1_4", "Dumbbell Row", 3, "10 each", 60, .strength, ["Back", "Biceps"], "Pull to hip, squeeze at top"),
                tex("bball_i_d1_5", "Side Plank (Hip Lift)", 3, "10 each", 45, .strength, ["Obliques", "Glutes"], "Raise and lower hips from side plank position"),
                tex("bball_i_d1_6", "Lateral Change of Direction Drill", 3, "30s", 60, .agility, ["Full Body"], "5-10-5 shuttle pattern, max effort, track time"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_i_d2", dayNumber: 2, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("bball_i_d2_1", "Foam Roll — Full Lower Body", 2, "8 min", 0, .recovery, ["Quads", "Hamstrings", "Calves", "IT Band"], "1 min per area, slow controlled pressure"),
                tex("bball_i_d2_2", "Maximal Yielding Hamstring Iso", 3, "30s each", 45, .strength, ["Hamstrings"], "Hold at longest tolerable length, 3-position approach"),
                tex("bball_i_d2_3", "Spanish Squat Iso", 3, "30s", 45, .strength, ["Quads", "Knees"], "Band behind back and knees, hold deep position"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_i_d3", dayNumber: 3, variant: "A", title: "Power + Plyometrics",
            category: .plyometrics,
            warmUp: [
                tex("bball_i_w4", "A-Skips", 3, "20m", 30, .agility, ["Hip Flexors", "Calves"], "Drive knee up to hip height, arm swing in opposition"),
                tex("bball_i_w5", "Lateral Bounds (Stick)", 3, "8 each", 30, .plyometric, ["Hip Abductors", "Quads"], "Max distance, stick landing 2s each side"),
            ],
            mainWork: [
                tex("bball_i_d3_1", "Depth Jump to Max Vertical", 4, "5", 120, .plyometric, ["Full Body"], "Step off box, minimal ground contact, explode up"),
                tex("bball_i_d3_2", "Lateral Bound to Sprint", 3, "6 each", 90, .plyometric, ["Full Body"], "Max lateral bound, plant and burst forward"),
                tex("bball_i_d3_3", "Approach Jump (1-Step)", 4, "5", 90, .plyometric, ["Full Body"], "One-step approach, focus on penultimate gather step"),
                tex("bball_i_d3_4", "Continuous Box Jumps", 3, "8", 90, .plyometric, ["Full Body"], "Step down each time, reset stance, rapid rebound"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_i_d4", dayNumber: 4, variant: "A", title: "Recovery + Pilates",
            category: .recoveryPilates,
            warmUp: [],
            mainWork: [
                tex("bball_i_d4_1", "Cat Camel", 3, "10", 20, .mobility, ["Spine", "Core"], "Slow transitions, breathe into each position"),
                tex("bball_i_d4_2", "Thread the Needle", 3, "8 each", 30, .mobility, ["Thoracic Spine"], "Full thoracic rotation range"),
                tex("bball_i_d4_3", "Hip Flexor Iso Hold", 3, "30s each", 30, .strength, ["Hip Flexors"], "March position, hold knee at 90° against gravity"),
                tex("bball_i_d4_4", "Swimming (Prone)", 3, "30s", 30, .recovery, ["Back", "Glutes"], "Alternating arm/leg lifts, core engaged"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_i_d5", dayNumber: 5, variant: "A", title: "Game Speed + Skills",
            category: .maxIntent,
            warmUp: [
                tex("bball_i_w6", "Dynamic CNS Primer", 2, "5 min", 45, .mobility, ["Full Body"], "Tuck jumps, sprint build-ups, quick feet ladder"),
            ],
            mainWork: [
                tex("bball_i_d5_1", "Full-Court Sprint (Suicides)", 3, "4 lengths", 120, .agility, ["Full Body"], "Touch each line, max effort, track split times"),
                tex("bball_i_d5_2", "Pick-and-Roll Footwork", 3, "8 reps", 60, .agility, ["Full Body"], "Simulate ball-handler curl and roll, attack rim footwork"),
                tex("bball_i_d5_3", "Shot-Release off Movement", 3, "10 shots", 45, .agility, ["Full Body"], "Catch-and-shoot off 2 lateral shuffle steps — balance and consistency"),
                tex("bball_i_d5_4", "Jump Shot Vertical Approach", 3, "8", 90, .plyometric, ["Full Body"], "Max intent jump shot — full approach, simulated catch, release at peak"),
            ],
            isGated: true, isCompleted: false
        ),
    ]

    // MARK: Basketball — Advanced

    static let advancedBasketballProgram = TrainingProgram(
        id: "bball_advanced",
        track: .elite,
        equipment: .bodyweight,
        weeks: 4,
        days: advancedBasketballDays
    )

    static let advancedBasketballDays: [TrainingDay] = [
        TrainingDay(
            id: "bball_a_d1", dayNumber: 1, variant: "A", title: "Max Strength A",
            category: .strength,
            warmUp: [
                tex("bball_a_w1", "CNS Primer Circuit", 2, "4 min", 60, .plyometric, ["Full Body"], "Tuck jumps, clap push-ups, sprint build-ups — prime for max output"),
                tex("bball_a_w2", "Pogos + Lateral Bounds", 3, "20 + 6 each", 30, .plyometric, ["Calves", "Hip Abductors"], "Stiff pogos then max lateral bound — reactive chain"),
            ],
            mainWork: [
                tex("bball_a_d1_1", "Trap Bar Deadlift (Heavy)", 5, "3-5", 180, .strength, ["Posterior Chain", "Quads"], "Max force, explosive concentric, full lockout"),
                tex("bball_a_d1_2", "Rear Foot Elevated Split Squat (Loaded)", 4, "6 each", 90, .strength, ["Quads", "Glutes"], "Deep range, heavy dumbbell, drive through front heel"),
                tex("bball_a_d1_3", "Nordic Hamstring Curl", 4, "5", 90, .strength, ["Hamstrings"], "Full eccentric control — fight the fall as long as possible"),
                tex("bball_a_d1_4", "Barbell Hip Thrust (Heavy)", 4, "8", 90, .strength, ["Glutes", "Hamstrings"], "Heavy load, 3s pause at peak extension"),
                tex("bball_a_d1_5", "Weighted Depth Jump", 4, "5", 120, .plyometric, ["Full Body"], "Light vest, step off box, maximize reactive output"),
                tex("bball_a_d1_6", "Anti-Rotation Plank Complex", 3, "1 round", 60, .strength, ["Core"], "Pallof press 10 each + dead bug 10 + bird dog 10 each"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_a_d2", dayNumber: 2, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("bball_a_d2_1", "Side Lying Breathing Corrective", 2, "90s each", 30, .recovery, ["Core", "Diaphragm"], "4s in, 6s out, feel lateral rib expansion — CNS downregulation"),
                tex("bball_a_d2_2", "Maximal Yielding Hamstring Iso (Extended)", 3, "45s each", 60, .strength, ["Hamstrings"], "Hold at end range with max effort, progress through 3 lengths"),
                tex("bball_a_d2_3", "Standing 4-Way Hip Iso (Heavy Band)", 3, "25s each", 45, .strength, ["Hips", "Glutes"], "Max isometric press into resistance in all 4 directions"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_a_d3", dayNumber: 3, variant: "A", title: "Max Power + Agility",
            category: .maxIntent,
            warmUp: [
                tex("bball_a_w3", "Full CNS Warm-Up", 2, "8 min", 60, .mobility, ["Full Body"], "Sprint build-ups, approach rehearsals, tuck jumps"),
            ],
            mainWork: [
                tex("bball_a_d3_1", "Dunk Approach — Full Run-Up", 5, "5", 150, .plyometric, ["Full Body"], "Full approach, max intent — focus on penultimate step and arm swing"),
                tex("bball_a_d3_2", "Reactive Change of Direction (COD)", 4, "6 each", 90, .agility, ["Full Body"], "React to visual cue — hard cut then burst, record split times"),
                tex("bball_a_d3_3", "Depth Jump to Broad Jump", 4, "5", 120, .plyometric, ["Full Body"], "Step off box, absorb vertically, redirect horizontal — chain seamlessly"),
                tex("bball_a_d3_4", "Neural Drive Sprint Series", 5, "20m", 120, .agility, ["Full Body"], "Max effort sprints for neural recruitment — full recovery between"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "bball_a_d4", dayNumber: 4, variant: "A", title: "Recovery Protocol",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("bball_a_d4_1", "Foam Roll + Lacrosse Ball", 1, "12 min", 0, .recovery, ["Full Body"], "Quads, glutes, lats, calves — deep tissue focus"),
                tex("bball_a_d4_2", "Ankle CARs + Banded Ankle CARs", 3, "10 each", 20, .mobility, ["Ankles"], "Full circles with and without band resistance"),
                tex("bball_a_d4_3", "Diaphragmatic Breathing Protocol", 2, "5 min", 0, .recovery, ["Core", "Diaphragm"], "4s in / 4s hold / 6s out — CNS rebalance post-intensity"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "bball_a_d5", dayNumber: 5, variant: "A", title: "Game Simulation",
            category: .maxIntent,
            warmUp: [
                tex("bball_a_w4", "Scrimmage Warm-Up", 1, "8 min", 30, .mobility, ["Full Body"], "3v3 half-court walk-through, touch all movement patterns"),
            ],
            mainWork: [
                tex("bball_a_d5_1", "5v5 Full-Court Scrimmage or Solo Drill Set", 1, "20 min", 0, .agility, ["Full Body"], "Full intensity — defensive rotations, offensive sets, transition"),
                tex("bball_a_d5_2", "Clutch Free-Throw Protocol", 2, "10 shots", 30, .mobility, ["Shoulders"], "After max effort sprint — simulate game fatigue shooting"),
                tex("bball_a_d5_3", "Post-Session Jump Test", 1, "3 attempts", 60, .plyometric, ["Full Body"], "Max vertical — track, record, compare to baseline"),
            ],
            isGated: true, isCompleted: false
        ),
    ]

    // MARK: Karate — Beginner

    static let beginnerKarateProgram = TrainingProgram(
        id: "karate_beginner",
        track: .foundations,
        equipment: .bodyweight,
        weeks: 4,
        days: beginnerKarateDays
    )

    static let beginnerKarateDays: [TrainingDay] = [
        TrainingDay(
            id: "kar_b_d1", dayNumber: 1, variant: "A", title: "Kata Basics + Foundation",
            category: .strength,
            warmUp: [
                tex("kar_b_w1", "Shiko (Sumo Squat) Stretch", 2, "30s", 20, .mobility, ["Adductors", "Hips"], "Wide stance, hands on knees, push knees out gently"),
                tex("kar_b_w2", "Hip Rotations (Standing)", 2, "10 each", 20, .mobility, ["Hips", "Lower Back"], "Both directions, gradually increase range"),
                tex("kar_b_w3", "Wrist and Shoulder Circles", 2, "10 each", 0, .mobility, ["Wrists", "Shoulders"], "Full range, both directions — protect joint health"),
            ],
            mainWork: [
                tex("kar_b_d1_1", "Zenkutsu-Dachi (Front Stance) Hold", 3, "30s each", 45, .strength, ["Quads", "Glutes", "Core"], "Deep front stance, front knee bent at 90°, back leg straight"),
                tex("kar_b_d1_2", "Kiba-Dachi (Horse Stance) Hold", 3, "30s", 45, .strength, ["Quads", "Adductors", "Glutes"], "Feet double shoulder-width, thighs parallel to floor"),
                tex("kar_b_d1_3", "Oi-Tsuki (Lunge Punch) Basic", 3, "10 each", 45, .strength, ["Quads", "Shoulders", "Core"], "Reverse punch from front stance — power from hip rotation"),
                tex("kar_b_d1_4", "Age-Uke (Rising Block)", 3, "10 each", 30, .strength, ["Shoulders", "Core"], "Rising block with hip counter-rotation, kiai on final rep"),
                tex("kar_b_d1_5", "Squat + Rise", 3, "12", 45, .strength, ["Quads", "Glutes"], "Deep squat to full stand, prepare hip mobility for stances"),
                tex("kar_b_d1_6", "Core Brace + Kiai Drill", 3, "10", 30, .strength, ["Core", "Diaphragm"], "Standing, brace core fully then exhale sharp kiai — condition IAP"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_b_d2", dayNumber: 2, variant: "A", title: "Recovery + Flexibility",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("kar_b_d2_1", "Standing Quadriceps Stretch", 2, "30s each", 20, .mobility, ["Quads", "Hip Flexors"], "Balance on one foot, pull heel to glute"),
                tex("kar_b_d2_2", "Seated Hamstring Stretch", 2, "30s each", 20, .mobility, ["Hamstrings"], "Reach for toes, breathe out tension"),
                tex("kar_b_d2_3", "Butterfly Stretch (Baddha Konasana)", 2, "60s", 20, .mobility, ["Adductors", "Groin"], "Feet together, press knees gently toward floor"),
                tex("kar_b_d2_4", "Hip Flexor Lunge Stretch", 2, "30s each", 20, .mobility, ["Hip Flexors"], "Low lunge, push hips forward gently — maintain upright torso"),
                tex("kar_b_d2_5", "Shoulder Cross-Body Stretch", 2, "20s each", 20, .mobility, ["Shoulders", "Rotator Cuff"], "Pull arm across body at shoulder height"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_b_d3", dayNumber: 3, variant: "A", title: "Kicks + Lower Body Power",
            category: .strength,
            warmUp: [
                tex("kar_b_w4", "Leg Swings (Front + Lateral)", 2, "10 each", 0, .mobility, ["Hips", "Hamstrings"], "Hold wall, build amplitude with each rep"),
                tex("kar_b_w5", "Hip Circles", 2, "10 each direction", 0, .mobility, ["Hips"], "Full range, keep torso still"),
            ],
            mainWork: [
                tex("kar_b_d3_1", "Mae-Geri (Front Kick) Slow", 3, "8 each", 45, .strength, ["Hip Flexors", "Quads"], "Chamber knee high, extend kick slowly, control return"),
                tex("kar_b_d3_2", "Yoko-Geri (Side Kick) Slow", 3, "6 each", 60, .strength, ["Hip Abductors", "Quads"], "Chamber knee, drive heel out to side, foot flat — slow practice"),
                tex("kar_b_d3_3", "Single-Leg Balance", 3, "20s each", 30, .mobility, ["Ankles", "Core"], "Eyes open → eyes closed progression — stability for kicking"),
                tex("kar_b_d3_4", "Body-Weight Squat Jump", 3, "8", 60, .plyometric, ["Quads", "Glutes"], "Full squat depth, explode to maximum height, soft landing"),
                tex("kar_b_d3_5", "Glute Bridge (Pulsing)", 3, "30s", 30, .strength, ["Glutes"], "Small pulses at top — activate glutes for kicking power"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_b_d4", dayNumber: 4, variant: "A", title: "Kata Practice A",
            category: .movementEducation,
            warmUp: [
                tex("kar_b_w6", "Full-Body Dynamic Warm-Up", 1, "5 min", 0, .mobility, ["Full Body"], "Joint circles, leg swings, light jog, breathing"),
            ],
            mainWork: [
                tex("kar_b_d4_1", "Heian Shodan or Taikyoku Shodan (Slow)", 5, "1 run-through", 90, .mobility, ["Full Body"], "Every technique slow and deliberate — focus on stance depth and kime"),
                tex("kar_b_d4_2", "Stances Transition Drill", 3, "10 each", 45, .strength, ["Quads", "Hips", "Core"], "Transition front → horse → back stance with body stay level"),
                tex("kar_b_d4_3", "Punching Combination (3-Count)", 3, "10", 30, .strength, ["Shoulders", "Core"], "Jab-cross-reverse punch with hip rotation, kiai on last"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_b_d5", dayNumber: 5, variant: "A", title: "Recovery + Conditioning",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("kar_b_d5_1", "Light Jog or Walk", 1, "15 min", 0, .recovery, ["Full Body"], "Conversational pace — active recovery for CNS"),
                tex("kar_b_d5_2", "Full Kata Run-Through (Normal Speed)", 3, "1 each", 60, .mobility, ["Full Body"], "Apply week's learning — add snap and kiai in correct places"),
                tex("kar_b_d5_3", "Deep Breathing / Mokuso", 2, "3 min", 0, .recovery, ["Core", "Diaphragm"], "Eyes closed, seated seiza, 4s in / 6s out — meditative focus"),
            ],
            isGated: false, isCompleted: false
        ),
    ]

    // MARK: Karate — Intermediate

    static let intermediateKarateProgram = TrainingProgram(
        id: "karate_intermediate",
        track: .flight,
        equipment: .bodyweight,
        weeks: 4,
        days: intermediateKarateDays
    )

    static let intermediateKarateDays: [TrainingDay] = [
        TrainingDay(
            id: "kar_i_d1", dayNumber: 1, variant: "A", title: "Sparring Prep — Strength",
            category: .strength,
            warmUp: [
                tex("kar_i_w1", "Shadow Sparring (Light)", 2, "2 min", 30, .agility, ["Full Body"], "Loose, free-form — hands up, move feet, throw light techniques"),
                tex("kar_i_w2", "Hip Flexor + Adductor Kick Warm-Up", 2, "10 each", 20, .mobility, ["Hips", "Adductors"], "Slow kicks building range, full circles"),
            ],
            mainWork: [
                tex("kar_i_d1_1", "Squat Jump (Kicking Power)", 4, "8", 60, .plyometric, ["Quads", "Glutes"], "Deep squat, explosive jump — generate power for high kicks"),
                tex("kar_i_d1_2", "Hip Thrust (Loaded)", 4, "10", 75, .strength, ["Glutes", "Hamstrings"], "Drive for hip extension power — foundation for all kicks"),
                tex("kar_i_d1_3", "Single-Leg Deadlift", 3, "8 each", 60, .strength, ["Hamstrings", "Glutes", "Core"], "Slow eccentric, maintain flat back — mirrors kicking balance"),
                tex("kar_i_d1_4", "Push-Up + Rotating Hip Drive", 3, "10", 60, .strength, ["Chest", "Core", "Shoulders"], "Push-up then rotate to side plank, drive knee to chest"),
                tex("kar_i_d1_5", "Rotational Med Ball Slam", 3, "8 each", 60, .plyometric, ["Core", "Obliques", "Shoulders"], "Mirror gyaku-tsuki rotation — develop rotational hip power"),
                tex("kar_i_d1_6", "Kiba-Dachi Squat (Pulsing)", 3, "30s", 45, .strength, ["Quads", "Adductors"], "Deep horse stance, small pulses — build sustained stance endurance"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_i_d2", dayNumber: 2, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("kar_i_d2_1", "Side Lying Breathing Corrective", 2, "60s each", 30, .recovery, ["Core", "Diaphragm"], "4s inhale, 6s exhale — downregulate after training"),
                tex("kar_i_d2_2", "Maximal Yielding Hamstring Iso", 3, "30s each", 45, .strength, ["Hamstrings"], "Kick position length — maximize flexibility for high kicks"),
                tex("kar_i_d2_3", "Standing 4-Way Hip Iso", 3, "20s each", 30, .strength, ["Hips", "Glutes"], "Press into wall/band all 4 directions — balance hip strength"),
                tex("kar_i_d2_4", "Adductor Iso Hold", 3, "30s", 30, .strength, ["Adductors"], "Squeeze medicine ball or pillow between knees — groin protection"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_i_d3", dayNumber: 3, variant: "A", title: "Kumite Movement + Power",
            category: .plyometrics,
            warmUp: [
                tex("kar_i_w3", "Shadow Kumite (Medium Intensity)", 2, "2 min", 30, .agility, ["Full Body"], "Controlled sparring footwork — in/out, lateral, level change"),
                tex("kar_i_w4", "Plyometric Pogos", 2, "20", 20, .plyometric, ["Calves", "Ankles"], "Stiff ankles, quick contact — mirrors kumite bounce"),
            ],
            mainWork: [
                tex("kar_i_d3_1", "Mae-Geri (Front Kick) — Fast + Chamber", 4, "8 each", 45, .plyometric, ["Hip Flexors", "Quads"], "Full speed chamber and extension — snap back to chamber before lower"),
                tex("kar_i_d3_2", "Mawashi-Geri (Roundhouse Kick) — Controlled", 4, "6 each", 60, .strength, ["Hip Abductors", "Quads", "Core"], "Hip rotation drives kick, snap back to chamber, maintain guard"),
                tex("kar_i_d3_3", "Footwork Combination (3-Step)", 3, "10", 45, .agility, ["Full Body"], "Advance-lunge punch, retreat-block, lateral-gyaku — link seamlessly"),
                tex("kar_i_d3_4", "Explosive Step-In Lunge Punch", 3, "10 each", 60, .plyometric, ["Full Body"], "Drive off rear foot into oi-tsuki — explosive hip extension and hip lock"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_i_d4", dayNumber: 4, variant: "A", title: "Kata + Recovery",
            category: .movementEducation,
            warmUp: [
                tex("kar_i_w5", "Full-Body Dynamic Warm-Up", 1, "5 min", 0, .mobility, ["Full Body"], "Joint prep, leg swings, arm circles, light movement"),
            ],
            mainWork: [
                tex("kar_i_d4_1", "Kata (Intermediate — Heian Godan or Bassai-Dai)", 5, "1 run-through", 90, .mobility, ["Full Body"], "First 3 slow, last 2 full speed with kiai and kime"),
                tex("kar_i_d4_2", "Bunkai (Application) Partner or Solo", 3, "10 each technique", 60, .strength, ["Full Body"], "Extract 3 techniques from kata, apply in practical defense context"),
                tex("kar_i_d4_3", "Flexibility Flow", 2, "5 min", 0, .mobility, ["Hips", "Hamstrings", "Shoulders"], "Long holds — target areas used in kata techniques"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_i_d5", dayNumber: 5, variant: "A", title: "Sparring Simulation",
            category: .maxIntent,
            warmUp: [
                tex("kar_i_w6", "Karate CNS Primer", 2, "5 min", 45, .plyometric, ["Full Body"], "Fast stances, snap kicks, combination punches — ramp intensity"),
            ],
            mainWork: [
                tex("kar_i_d5_1", "Light Contact Sparring or Shadow Kumite (Full)", 1, "3×2 min rounds", 60, .agility, ["Full Body"], "Control contact, practice point-scoring techniques — maai management"),
                tex("kar_i_d5_2", "Kizami-Tsuki + Gyaku-Tsuki Combination Sprint", 3, "10 combos", 45, .plyometric, ["Full Body"], "Jab + reverse punch, explosive hip drive — max speed on each"),
                tex("kar_i_d5_3", "Post-Training Mokuso + Stretch", 1, "5 min", 0, .recovery, ["Full Body"], "Meditative breathing, long hamstring and hip flexor stretches"),
            ],
            isGated: true, isCompleted: false
        ),
    ]

    // MARK: Karate — Advanced

    static let advancedKarateProgram = TrainingProgram(
        id: "karate_advanced",
        track: .elite,
        equipment: .bodyweight,
        weeks: 4,
        days: advancedKarateDays
    )

    static let advancedKarateDays: [TrainingDay] = [
        TrainingDay(
            id: "kar_a_d1", dayNumber: 1, variant: "A", title: "Competition Prep — Max Strength",
            category: .strength,
            warmUp: [
                tex("kar_a_w1", "Kata CNS Primer (Full Speed)", 1, "1 run-through", 60, .mobility, ["Full Body"], "Selected competition kata at full speed — prime CNS for max output"),
                tex("kar_a_w2", "Explosive Plyometric Warm-Up", 2, "3 min", 45, .plyometric, ["Full Body"], "Tuck jumps, broad jumps, lateral bounds — activate fast-twitch"),
            ],
            mainWork: [
                tex("kar_a_d1_1", "Trap Bar Deadlift (Heavy)", 5, "3-5", 180, .strength, ["Posterior Chain", "Quads"], "Max strength foundation — peak hip extension power for all kicking"),
                tex("kar_a_d1_2", "Rear Foot Elevated Split Squat (Loaded)", 4, "6 each", 90, .strength, ["Quads", "Glutes"], "Deep range — mirrors front stance mechanics under load"),
                tex("kar_a_d1_3", "Nordic Hamstring Curl", 4, "5", 90, .strength, ["Hamstrings"], "Injury prevention critical for high-kick practitioners"),
                tex("kar_a_d1_4", "Barbell Hip Thrust (Max)", 4, "6", 90, .strength, ["Glutes", "Hamstrings"], "Heavy load, 3s lockout — maximize glute drive for explosive kicks"),
                tex("kar_a_d1_5", "Rotational Med Ball Throw (Wall)", 4, "8 each", 75, .plyometric, ["Core", "Obliques"], "Simulate gyaku-tsuki rotation velocity — max intent each throw"),
                tex("kar_a_d1_6", "Cross Connect Core Circuit", 3, "12 each", 45, .strength, ["Core", "Obliques"], "Toe touches + chops + Pallof press — iron out rotational leakage"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_a_d2", dayNumber: 2, variant: "A", title: "Recovery + Isos",
            category: .recoveryIso,
            warmUp: [],
            mainWork: [
                tex("kar_a_d2_1", "Side Lying Breathing Corrective", 2, "90s each", 30, .recovery, ["Core", "Diaphragm"], "Extended CNS downregulation protocol — 4s in / 6s out × 10"),
                tex("kar_a_d2_2", "Maximal Yielding Hamstring Iso (Extended)", 3, "45s each", 60, .strength, ["Hamstrings"], "End range kicks — maximize length for jodan kicks"),
                tex("kar_a_d2_3", "Standing 4-Way Hip Iso (Heavy Band)", 3, "25s each", 45, .strength, ["Hips", "Glutes"], "Max isometric output in all 4 directions"),
                tex("kar_a_d2_4", "Adductor Long-Length Iso", 3, "30s", 45, .strength, ["Adductors"], "Groin protection and mawashi-geri chamber strength"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_a_d3", dayNumber: 3, variant: "A", title: "Competition Kata + Kumite Power",
            category: .maxIntent,
            warmUp: [
                tex("kar_a_w3", "Full CNS Warm-Up + Shadow Kumite", 2, "8 min", 60, .mobility, ["Full Body"], "Build from light shadow to 90% intensity — full competition simulation"),
            ],
            mainWork: [
                tex("kar_a_d3_1", "Competition Kata — Max Effort", 5, "1 per set", 120, .mobility, ["Full Body"], "Judged run-throughs — power, rhythm, kime, zanshin"),
                tex("kar_a_d3_2", "High-Speed Kick Combination", 4, "8 each leg", 90, .plyometric, ["Hip Flexors", "Quads", "Core"], "Mae-geri + mawashi-geri in sequence — acceleration and deceleration"),
                tex("kar_a_d3_3", "Explosive Punch Combination (5-Count)", 4, "10", 60, .plyometric, ["Shoulders", "Core", "Full Body"], "Kizami + gyaku + uraken + empi + gyaku — max hip rotation each"),
                tex("kar_a_d3_4", "Depth Jump → Jodan Kick Combination", 3, "5", 120, .plyometric, ["Full Body"], "Step off box, land, immediately deliver upper-level kick — explosive chain"),
            ],
            isGated: true, isCompleted: false
        ),
        TrainingDay(
            id: "kar_a_d4", dayNumber: 4, variant: "A", title: "Neural Recovery",
            category: .recovery,
            warmUp: [],
            mainWork: [
                tex("kar_a_d4_1", "Zone 2 Cardio (Light Run / Cycle)", 1, "25 min", 0, .recovery, ["Full Body"], "Conversational pace — CNS rebalancing, avoid high intensity"),
                tex("kar_a_d4_2", "Foam Roll + Lacrosse Ball Protocol", 1, "12 min", 0, .recovery, ["Full Body"], "Quads, glutes, lats, calves — deep tissue compression"),
                tex("kar_a_d4_3", "Extended Mokuso + Visualization", 2, "5 min", 0, .recovery, ["Core", "Diaphragm"], "Eyes closed — visualize competition kata flawlessly executed"),
            ],
            isGated: false, isCompleted: false
        ),
        TrainingDay(
            id: "kar_a_d5", dayNumber: 5, variant: "A", title: "Competition Simulation Day",
            category: .maxIntent,
            warmUp: [
                tex("kar_a_w4", "Pre-Competition Ritual Warm-Up", 1, "10 min", 30, .mobility, ["Full Body"], "Replicate exact pre-competition warm-up sequence for neural priming"),
            ],
            mainWork: [
                tex("kar_a_d5_1", "Competition Kata (Timed + Evaluated)", 3, "1 per set", 180, .mobility, ["Full Body"], "Video if possible — score kime, timing, zanshin, and spirit"),
                tex("kar_a_d5_2", "Ippon Kumite Combinations (Full Speed)", 4, "5 each", 90, .agility, ["Full Body"], "Attacker/defender rotation — reaction speed and counter precision"),
                tex("kar_a_d5_3", "Jiyu Kumite or Controlled Sparring", 1, "3×2 min rounds", 60, .agility, ["Full Body"], "Full competition simulation — scoring, maai, strategy"),
                tex("kar_a_d5_4", "Post-Competition Cool Down + Mokuso", 1, "10 min", 0, .recovery, ["Full Body"], "Full body stretch, breathing, mental debrief — prepare for next cycle"),
            ],
            isGated: true, isCompleted: false
        ),
    ]
}
