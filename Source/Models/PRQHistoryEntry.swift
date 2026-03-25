import Foundation

/// One row for PRQ / neuro history (Unreal sessions, scans, etc.).
nonisolated struct PRQHistoryEntry: Codable, Sendable, Identifiable {
    let id: String
    let date: Date
    /// e.g. "unreal_session", "arena", "scan"
    let source: String
    let prqBonus: Double
    let mentalSharpness: Double?
    let neuroPerformance: Double?
    let gameModeId: String?

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        source: String,
        prqBonus: Double,
        mentalSharpness: Double?,
        neuroPerformance: Double?,
        gameModeId: String?
    ) {
        self.id = id
        self.date = date
        self.source = source
        self.prqBonus = prqBonus
        self.mentalSharpness = mentalSharpness
        self.neuroPerformance = neuroPerformance
        self.gameModeId = gameModeId
    }
}
