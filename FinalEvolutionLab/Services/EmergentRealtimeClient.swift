import Foundation

/// WebSocket client for the Emergent-style game backend: applies inbound PRQ payloads to `RorkScoreManager`.
/// URL: `EMERGENT_GAME_WS_URL` environment variable, then UserDefaults key `fel_emergent_game_ws_url`.
///
/// Supported JSON shapes (examples):
/// - `{ "type": "prq_update", "prq": 72 }`
/// - `{ "type": "prq_set", "value": 72 }`
/// - `{ "type": "prq_delta", "delta": 5 }`
/// - `{ "prq": 72 }` (implicit set when no `type` but `prq` is present)
final class EmergentRealtimeClient {
    static let shared = EmergentRealtimeClient()

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var listenGeneration: UInt64 = 0

    private init() {}

    func startIfConfigured() {
        let urlString = Config.resolvedEmergentGameWebSocketURL()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else { return }
        stop()
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        let sess = URLSession(configuration: cfg, delegate: nil, delegateQueue: nil)
        session = sess
        let ws = sess.webSocketTask(with: url)
        task = ws
        listenGeneration += 1
        let gen = listenGeneration
        ws.resume()
        receiveLoop(generation: gen)
    }

    func stop() {
        listenGeneration += 1
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func receiveLoop(generation: UInt64) {
        task?.receive { [weak self] result in
            guard let self else { return }
            guard generation == self.listenGeneration else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncoming(text: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncoming(text: text)
                    }
                @unknown default:
                    break
                }
                self.receiveLoop(generation: generation)
            case .failure:
                break
            }
        }
    }

    private func handleIncoming(text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let type = (obj["type"] as? String) ?? (obj["event"] as? String) ?? (obj["action"] as? String)
        Task { @MainActor in
            Self.applyEmergentPayload(obj, type: type)
        }
    }

    /// Shared JSON contract for tests and runtime (must run on the main actor).
    @MainActor
    static func applyEmergentPayload(_ obj: [String: Any], type: String?) {
        let t = type?.lowercased()
        switch t {
        case "prq_delta":
            if let delta = obj["delta"] as? Int {
                let current = RorkScoreManager.shared.currentPrqScore
                RorkScoreManager.shared.applyClampedPrq(current + delta)
            } else if let delta = obj["delta"] as? Double {
                let current = RorkScoreManager.shared.currentPrqScore
                RorkScoreManager.shared.applyClampedPrq(current + Int(delta.rounded()))
            }
        case "prq_set", "prq_update", "prq":
            applyAbsolutePrq(from: obj)
        case .none:
            if obj["prq"] != nil || obj["value"] != nil || obj["score"] != nil {
                applyAbsolutePrq(from: obj)
            }
        default:
            if t?.contains("prq") == true {
                applyAbsolutePrq(from: obj)
            }
        }
    }

    @MainActor
    private static func applyAbsolutePrq(from obj: [String: Any]) {
        let value: Int?
        if let v = obj["prq"] as? Int {
            value = v
        } else if let v = obj["value"] as? Int {
            value = v
        } else if let v = obj["score"] as? Int {
            value = v
        } else if let v = obj["prq"] as? Double {
            value = Int(v.rounded())
        } else if let v = obj["value"] as? Double {
            value = Int(v.rounded())
        } else {
            value = nil
        }
        guard let value else { return }
        RorkScoreManager.shared.applyClampedPrq(value)
    }
}
