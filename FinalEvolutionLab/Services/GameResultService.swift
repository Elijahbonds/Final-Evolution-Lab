import Foundation

struct GameResultService {
    static let backendURL: String = {
        ProcessInfo.processInfo.environment["REACT_APP_BACKEND_URL"]
            ?? "https://final-evolution-lab-backend.onrender.com"
    }()

    struct GameResult: Encodable {
        let user_id: String
        let mode_id: String
        let user_score: Int
        let opponent_score: Int
        let duration_seconds: Int
        let creator_card_ids: [String]
        let prq_delta: Int
    }

    static func saveResult(
        modeId: String,
        userScore: Int,
        opponentScore: Int = 0,
        durationSeconds: Int = 0,
        creatorCardIds: [String] = [],
        prqDelta: Int = 0,
        userId: String = "player"
    ) {
        guard let url = URL(string: "\(backendURL)/api/games/result") else { return }
        let body = GameResult(
            user_id: userId,
            mode_id: modeId,
            user_score: userScore,
            opponent_score: opponentScore,
            duration_seconds: durationSeconds,
            creator_card_ids: creatorCardIds,
            prq_delta: prqDelta
        )
        guard let data = try? JSONEncoder().encode(body) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 10
        URLSession.shared.dataTask(with: req).resume()
    }
}
