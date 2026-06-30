import Foundation

/// Firebase Realtime Database listener for arena dunk sessions using the REST streaming API.
/// Uses `text/event-stream` (Server-Sent Events) — no FirebaseDatabase SDK needed.
///
/// Subscribes to: /arena/sessions/{sessionId}.json?auth={idToken}
/// Emits jump events and phase changes published to DunkCompetitionView.
@Observable
@MainActor
final class ArenaRealtimeService {

    // MARK: - Published state

    var player1Jumps: [RTDBJump] = []
    var player2Jumps: [RTDBJump] = []
    var sessionStatus: String = "lobby"
    var isConnected: Bool = false
    var error: String?

    // MARK: - Private

    private var streamTask: URLSessionDataTask?
    private var lineBuffer: String = ""
    private var currentEventName: String = ""
    private var sessionId: String?

    private let databaseURL: String
    private let idTokenProvider: () async -> String?

    /// - Parameters:
    ///   - databaseURL: e.g. `https://final-evolution-lab-default-rtdb.firebaseio.com`
    ///   - idTokenProvider: async closure that returns the current Firebase ID token
    init(
        databaseURL: String = "https://final-evolution-lab-default-rtdb.firebaseio.com",
        idTokenProvider: @escaping () async -> String?
    ) {
        self.databaseURL = databaseURL
        self.idTokenProvider = idTokenProvider
    }

    // MARK: - Subscribe / unsubscribe

    func subscribe(sessionId: String) {
        unsubscribe()
        self.sessionId = sessionId
        Task { await startStream(sessionId: sessionId) }
    }

    func unsubscribe() {
        streamTask?.cancel()
        streamTask = nil
        isConnected = false
        lineBuffer = ""
        currentEventName = ""
    }

    // MARK: - Private

    private func startStream(sessionId: String) async {
        let token = await idTokenProvider()
        let authSuffix = token.map { "?auth=\($0)" } ?? ""
        let urlString = "\(databaseURL)/arena/sessions/\(sessionId).json\(authSuffix)"
        guard let url = URL(string: urlString) else {
            error = "Invalid Realtime DB URL"
            return
        }
        var req = URLRequest(url: url)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let delegate = SSEDelegate(onLine: { [weak self] line in
            Task { @MainActor in self?.processLine(line) }
        })
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: req)
        streamTask = task
        isConnected = true
        task.resume()
    }

    private func processLine(_ line: String) {
        if line.hasPrefix("event:") {
            currentEventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            handleEvent(name: currentEventName, data: payload)
            currentEventName = ""
        }
    }

    private func handleEvent(name: String, data: String) {
        guard data != "null", !data.isEmpty,
              let jsonData = data.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return }

        switch name {
        case "put":
            applyPut(path: obj["path"] as? String ?? "/", body: obj["data"])
        case "patch":
            applyPatch(body: obj["data"])
        default:
            break
        }
    }

    private func applyPut(path: String, body: Any?) {
        guard let root = body as? [String: Any] else { return }
        applyRoot(root)
    }

    private func applyPatch(body: Any?) {
        guard let patch = body as? [String: Any] else { return }
        if let statusVal = patch["status"] as? String {
            sessionStatus = statusVal
        }
        if let p1 = patch["player1"] as? [String: Any],
           let jumps = p1["jumps"] as? [String: [String: Any]] {
            mergeJumps(into: &player1Jumps, from: jumps)
        }
        if let p2 = patch["player2"] as? [String: Any],
           let jumps = p2["jumps"] as? [String: [String: Any]] {
            mergeJumps(into: &player2Jumps, from: jumps)
        }
    }

    private func applyRoot(_ root: [String: Any]) {
        if let status = root["status"] as? String { sessionStatus = status }
        if let p1 = root["player1"] as? [String: Any],
           let jumps = p1["jumps"] as? [String: [String: Any]] {
            player1Jumps = []
            mergeJumps(into: &player1Jumps, from: jumps)
        }
        if let p2 = root["player2"] as? [String: Any],
           let jumps = p2["jumps"] as? [String: [String: Any]] {
            player2Jumps = []
            mergeJumps(into: &player2Jumps, from: jumps)
        }
    }

    private func mergeJumps(into target: inout [RTDBJump], from dict: [String: [String: Any]]) {
        for (key, val) in dict {
            guard let h = val["heightInches"] as? Double,
                  let ts = val["timestamp"] as? Double else { continue }
            if !target.contains(where: { $0.key == key }) {
                target.append(RTDBJump(key: key, heightInches: h, timestamp: Date(timeIntervalSince1970: ts)))
            }
        }
        target.sort { $0.timestamp < $1.timestamp }
    }

    // MARK: - Write helpers (post jump to own player slot)

    func recordJump(slot: Int, heightInches: Double, token: String) async {
        guard let sid = sessionId else { return }
        let playerKey = slot == 1 ? "player1" : "player2"
        let jumpId = "j_\(Int(Date().timeIntervalSince1970 * 1000))"
        let urlString = "\(databaseURL)/arena/sessions/\(sid)/\(playerKey)/jumps/\(jumpId).json?auth=\(token)"
        guard let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["heightInches": heightInches, "timestamp": Date().timeIntervalSince1970]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }
}

// MARK: - RTDBJump model

struct RTDBJump: Identifiable {
    let id = UUID()
    let key: String
    let heightInches: Double
    let timestamp: Date
}

// MARK: - SSE URLSession delegate

private final class SSEDelegate: NSObject, URLSessionDataDelegate {
    private let onLine: (String) -> Void
    private var buffer = ""

    init(onLine: @escaping (String) -> Void) { self.onLine = onLine }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])
            onLine(line)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error, (err as NSError).code != NSURLErrorCancelled {
            onLine("error: \(err.localizedDescription)")
        }
    }
}
