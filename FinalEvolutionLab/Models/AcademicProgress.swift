import Foundation

public struct AcademicTrackProgress: Codable, Equatable, Sendable {
    public var trackId: String
    public var completedLessons: Set<String> = []
    public var correctAnswers: Int = 0
    public var totalQuestionsAttempted: Int = 0
    public var xpGained: Int = 0
    
    public init(trackId: String, completedLessons: Set<String> = [], correctAnswers: Int = 0, totalQuestionsAttempted: Int = 0, xpGained: Int = 0) {
        self.trackId = trackId
        self.completedLessons = completedLessons
        self.correctAnswers = correctAnswers
        self.totalQuestionsAttempted = totalQuestionsAttempted
        self.xpGained = xpGained
    }
}

public struct AcademicProgress: Codable, Equatable, Sendable {
    public var trackProgress: [String: AcademicTrackProgress] = [:]
    public var totalXP: Int = 0
    
    public init(trackProgress: [String: AcademicTrackProgress] = [:], totalXP: Int = 0) {
        self.trackProgress = trackProgress
        self.totalXP = totalXP
    }
    
    public mutating func addResult(trackId: String, lessonId: String, correct: Int, total: Int, xpGained: Int) {
        var progress = trackProgress[trackId] ?? AcademicTrackProgress(trackId: trackId)
        progress.completedLessons.insert(lessonId)
        progress.correctAnswers += correct
        progress.totalQuestionsAttempted += total
        progress.xpGained += xpGained
        trackProgress[trackId] = progress
        self.totalXP += xpGained
    }
}
