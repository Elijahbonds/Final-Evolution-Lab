import Foundation

nonisolated struct UserProfile: Codable, Sendable, Identifiable {
    var id: String
    var displayName: String
    var athleteTag: String
    var metrics: PerformanceMetrics
    var evolutionShards: Int
    var totalWorkouts: Int
    var streakDays: Int
    var joinDate: Date
    var avatarSystemName: String
    var blueprintCredits: Int

    var sport: String?
    var age: Int?
    var goal: String?
    var hasCompletedOnboarding: Bool
    var systemScan: SystemScanResult?
    var activeCreatorCard: CreatorCardState?

    static let guest = UserProfile(
        id: "guest_\(Int.random(in: 1000...9999))",
        displayName: "Guest Athlete",
        athleteTag: "0xGuest",
        metrics: .empty,
        evolutionShards: 0,
        totalWorkouts: 0,
        streakDays: 0,
        joinDate: Date(),
        avatarSystemName: "figure.run",
        blueprintCredits: 0,
        sport: nil,
        age: nil,
        goal: nil,
        hasCompletedOnboarding: false,
        systemScan: nil,
        activeCreatorCard: nil
    )
}

nonisolated struct SystemScanResult: Codable, Sendable {
    let id: String
    let date: Date
    let prqScore: Double
    let verticalEstimateInches: Double
    let flightTimeSeconds: Double
    let movementGrade: String
    let notes: [String]
    let recommendedTrack: String
}

nonisolated struct CreatorCardState: Codable, Sendable {
    let cardId: String
    let creatorName: String
    let appliedAt: Date
    let costShards: Int
    let metricsBoost: PerformanceMetrics
}
