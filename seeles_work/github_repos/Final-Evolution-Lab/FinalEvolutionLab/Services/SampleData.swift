import Foundation

struct SampleData {
    static let foundationExercises: [Exercise] = [
        Exercise(id: "f1", name: "Scaled Pogos", category: .plyometric, difficulty: .foundation, muscleGroups: ["Calves", "Ankles"], demoDescription: "Quick, low-amplitude hops focusing on ankle stiffness and ground contact time.", sets: 3, reps: "20", restSeconds: 45),
        Exercise(id: "f2", name: "Box Jumps", category: .plyometric, difficulty: .foundation, muscleGroups: ["Quads", "Glutes"], demoDescription: "Explosive vertical jump onto a stable box, focusing on hip extension and soft landing.", sets: 4, reps: "8", restSeconds: 60),
        Exercise(id: "f3", name: "Split Squats", category: .strength, difficulty: .foundation, muscleGroups: ["Quads", "Glutes", "Hip Flexors"], demoDescription: "Single-leg strength builder with controlled eccentric phase.", sets: 3, reps: "12 each", restSeconds: 60),
        Exercise(id: "f4", name: "Ankle Mobility Flow", category: .mobility, difficulty: .foundation, muscleGroups: ["Ankles", "Calves"], demoDescription: "Dynamic ankle circles and dorsiflexion stretches to improve range of motion.", sets: 2, reps: "60s", restSeconds: 30),
        Exercise(id: "f5", name: "Lateral Shuffles", category: .agility, difficulty: .foundation, muscleGroups: ["Hip Abductors", "Quads"], demoDescription: "Quick lateral movement pattern with low center of gravity.", sets: 3, reps: "30s", restSeconds: 45),
    ]

    static let flightExercises: [Exercise] = [
        Exercise(id: "fl1", name: "Depth Jumps", category: .plyometric, difficulty: .flight, muscleGroups: ["Quads", "Calves", "Glutes"], demoDescription: "Step off box, absorb landing, immediately explode upward for maximum height.", sets: 4, reps: "6", restSeconds: 90),
        Exercise(id: "fl2", name: "Lateral Leaps", category: .plyometric, difficulty: .flight, muscleGroups: ["Hip Abductors", "Quads", "Glutes"], demoDescription: "Explosive lateral bound with single-leg stabilization on landing.", sets: 3, reps: "8 each", restSeconds: 75),
        Exercise(id: "fl3", name: "Bulgarian Split Squats", category: .strength, difficulty: .flight, muscleGroups: ["Quads", "Glutes", "Core"], demoDescription: "Rear-foot elevated single-leg squat with deep knee flexion.", sets: 4, reps: "10 each", restSeconds: 75),
        Exercise(id: "fl4", name: "Hip Flexor Activation", category: .mobility, difficulty: .flight, muscleGroups: ["Hip Flexors", "Core"], demoDescription: "Active hip flexion drills to improve knee drive during takeoff.", sets: 3, reps: "12 each", restSeconds: 45),
        Exercise(id: "fl5", name: "Cone Agility Circuit", category: .agility, difficulty: .flight, muscleGroups: ["Full Body"], demoDescription: "Multi-directional speed work through cone patterns.", sets: 4, reps: "45s", restSeconds: 60),
    ]

    static let eliteExercises: [Exercise] = [
        Exercise(id: "e1", name: "Dunk Sessions", category: .plyometric, difficulty: .elite, muscleGroups: ["Full Body"], demoDescription: "Full approach dunking practice with emphasis on penultimate step mechanics and arm swing timing.", sets: 5, reps: "5", restSeconds: 120),
        Exercise(id: "e2", name: "Weighted Depth Jumps", category: .plyometric, difficulty: .elite, muscleGroups: ["Quads", "Calves", "Glutes"], demoDescription: "Depth jump variation with light vest for overload adaptation.", sets: 3, reps: "5", restSeconds: 120),
        Exercise(id: "e3", name: "Trap Bar Deadlifts", category: .strength, difficulty: .elite, muscleGroups: ["Posterior Chain", "Quads", "Core"], demoDescription: "Heavy compound lift for peak force production.", sets: 5, reps: "5", restSeconds: 180),
        Exercise(id: "e4", name: "Neural Drive Sprint", category: .agility, difficulty: .elite, muscleGroups: ["Full Body"], demoDescription: "Maximum effort 20m sprints for neural recruitment optimization.", sets: 6, reps: "20m", restSeconds: 120),
        Exercise(id: "e5", name: "Recovery Protocol", category: .recovery, difficulty: .elite, muscleGroups: ["Full Body"], demoDescription: "Foam rolling, static stretching, and breathing techniques for CNS recovery.", sets: 1, reps: "15 min", restSeconds: 0),
    ]

    static let tracks: [CurriculumTrack] = [
        CurriculumTrack(id: "foundations", name: "Foundations", subtitle: "Build the base. Master the fundamentals.", difficulty: .foundation, exercises: foundationExercises, weekDuration: 6),
        CurriculumTrack(id: "flight", name: "Flight", subtitle: "Unlock explosive vertical power.", difficulty: .flight, exercises: flightExercises, weekDuration: 8),
        CurriculumTrack(id: "elite", name: "Elite", subtitle: "Peak performance. No ceiling.", difficulty: .elite, exercises: eliteExercises, weekDuration: 12),
    ]

    static let leaderboard: [LeaderboardEntry] = [
        LeaderboardEntry(id: "l1", athleteName: "Coach V", athleteTag: "0xCoachV", prqScore: 98, evolutionShards: 12400, rank: 1, avatarSystemName: "crown.fill"),
        LeaderboardEntry(id: "l2", athleteName: "SkyWalker", athleteTag: "0xSky42", prqScore: 85, evolutionShards: 10800, rank: 2, avatarSystemName: "bolt.fill"),
        LeaderboardEntry(id: "l3", athleteName: "FlightRisk", athleteTag: "0xFlight", prqScore: 79, evolutionShards: 9600, rank: 3, avatarSystemName: "flame.fill"),
        LeaderboardEntry(id: "l4", athleteName: "VertKing", athleteTag: "0xVert", prqScore: 74, evolutionShards: 8200, rank: 4, avatarSystemName: "figure.basketball"),
        LeaderboardEntry(id: "l5", athleteName: "AirMax", athleteTag: "0xAir", prqScore: 69, evolutionShards: 7100, rank: 5, avatarSystemName: "wind"),
        LeaderboardEntry(id: "l6", athleteName: "RocketFuel", athleteTag: "0xRocket", prqScore: 64, evolutionShards: 6400, rank: 6, avatarSystemName: "airplane"),
        LeaderboardEntry(id: "l7", athleteName: "Bounce", athleteTag: "0xBounce", prqScore: 58, evolutionShards: 5800, rank: 7, avatarSystemName: "arrow.up.circle.fill"),
    ]
}
