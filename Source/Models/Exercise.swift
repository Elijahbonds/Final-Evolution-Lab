import Foundation

nonisolated struct Exercise: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let difficulty: Difficulty
    let muscleGroups: [String]
    let demoDescription: String
    let sets: Int
    let reps: String
    let restSeconds: Int
    /// Optional per-exercise regressions (easier options) and progressions (harder options) for coaching.
    let regressions: [String]?
    let progressions: [String]?
    let plyometricDepthTier: PlyometricDepthTier?
    let cnsIgnition: Bool

    init(
        id: String,
        name: String,
        category: ExerciseCategory,
        difficulty: Difficulty,
        muscleGroups: [String],
        demoDescription: String,
        sets: Int,
        reps: String,
        restSeconds: Int,
        regressions: [String]? = nil,
        progressions: [String]? = nil,
        plyometricDepthTier: PlyometricDepthTier? = nil,
        cnsIgnition: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.muscleGroups = muscleGroups
        self.demoDescription = demoDescription
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.regressions = regressions
        self.progressions = progressions
        self.plyometricDepthTier = plyometricDepthTier
        self.cnsIgnition = cnsIgnition
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, difficulty, muscleGroups, demoDescription, sets, reps, restSeconds, regressions, progressions, plyometricDepthTier, watsonTier
        case cnsIgnition
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(ExerciseCategory.self, forKey: .category)
        difficulty = try c.decode(Difficulty.self, forKey: .difficulty)
        muscleGroups = try c.decode([String].self, forKey: .muscleGroups)
        demoDescription = try c.decode(String.self, forKey: .demoDescription)
        sets = try c.decode(Int.self, forKey: .sets)
        reps = try c.decode(String.self, forKey: .reps)
        restSeconds = try c.decode(Int.self, forKey: .restSeconds)
        regressions = try c.decodeIfPresent([String].self, forKey: .regressions)
        progressions = try c.decodeIfPresent([String].self, forKey: .progressions)
        if let s = try c.decodeIfPresent(String.self, forKey: .plyometricDepthTier),
           let t = PlyometricDepthTier(rawValue: s) ?? PlyometricDepthTier(legacyStored: s) {
            plyometricDepthTier = t
        } else if let s = try c.decodeIfPresent(String.self, forKey: .watsonTier),
                  let t = PlyometricDepthTier(rawValue: s) ?? PlyometricDepthTier(legacyStored: s) {
            plyometricDepthTier = t
        } else {
            plyometricDepthTier = nil
        }
        cnsIgnition = try c.decodeIfPresent(Bool.self, forKey: .cnsIgnition) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(category, forKey: .category)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(muscleGroups, forKey: .muscleGroups)
        try c.encode(demoDescription, forKey: .demoDescription)
        try c.encode(sets, forKey: .sets)
        try c.encode(reps, forKey: .reps)
        try c.encode(restSeconds, forKey: .restSeconds)
        try c.encodeIfPresent(regressions, forKey: .regressions)
        try c.encodeIfPresent(progressions, forKey: .progressions)
        try c.encodeIfPresent(plyometricDepthTier?.rawValue, forKey: .plyometricDepthTier)
        try c.encode(cnsIgnition, forKey: .cnsIgnition)
    }

    nonisolated enum ExerciseCategory: String, Codable, Sendable, CaseIterable {
        case plyometric = "Plyometric"
        case strength = "Strength"
        case mobility = "Mobility"
        case agility = "Agility"
        case recovery = "Recovery"

        var systemImage: String {
            switch self {
            case .plyometric: "figure.jumprope"
            case .strength: "dumbbell.fill"
            case .mobility: "figure.flexibility"
            case .agility: "figure.run"
            case .recovery: "heart.circle.fill"
            }
        }
    }

    nonisolated enum Difficulty: String, Codable, Sendable, CaseIterable {
        case foundation = "Foundation"
        case flight = "Flight"
        case elite = "Elite"

        var sortOrder: Int {
            switch self {
            case .foundation: 0
            case .flight: 1
            case .elite: 2
            }
        }
    }
}
