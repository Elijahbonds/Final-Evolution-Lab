import Foundation

/// Non-blocking reachability probe for DeepMotion (or placeholder). Fails open for zero-friction launch when offline.
enum FELDeepMotionHealthCheck {
    /// Override via scheme env `DEEPMOTION_HEALTH_URL` or Info.plist `DEEPMOTION_HEALTH_URL`.
    static func ping() async -> Bool {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "DEEPMOTION_HEALTH_URL") as? String
            ?? ProcessInfo.processInfo.environment["DEEPMOTION_HEALTH_URL"]
            ?? "https://www.deepmotion.com"
        guard let url = URL(string: urlString) else { return true }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200 ..< 400).contains(http.statusCode)
            }
            return true
        } catch {
            return true
        }
    }
}
