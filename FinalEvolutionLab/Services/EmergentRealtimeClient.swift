import Foundation

/// WebSocket client for the Emergent-style game backend: applies inbound PRQ payloads to `RorkScoreManager`.
/// URL: `EMERGENT_GAME_WS_URL` environment variable, then UserDefaults key `fel_emergent_game_ws_url`.
///
/// **Trust:** PRQ mutations and ``fel_game_result`` sharing require `game_session_id` / `ue_session_id` to match
/// ``EmergentRealtimeTrust.bindTrustedGameplaySession`` (set when UE or server validates a session). Debug-only bypass: env `FEL_ALLOW_UNVERIFIED_EMERGENT=1`.
///
/// **Outbound:** maintains a small queue and retries after reconnect (matches Unreal bridge resilience pattern).
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
    private var pendingURL: URL?

    private let outboundQueueLock = NSLock()
    private var outboundQueue: [String] = []
    private var isSendingOutbound = false
    /// Caps memory if server never ACKs (drops oldest).
    private let maxOutboundQueue = 128

    private var reconnectGeneration: UInt64 = 0
    private var reconnectAttempt: Int = 0

    private init() {}

    func startIfConfigured() {
        let urlString = Config.resolvedEmergentGameWebSocketURL()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else { return }
        pendingURL = url
        reconnectAttempt = 0
        openConnection(to: url)
    }

    private func openConnection(to url: URL) {
        stopSocketsOnly()
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
        if let t = task {
            pumpOutboundQueueIfNeeded(task: t)
        }
    }

    /// Stops socket without clearing pending URL / outbound queue (used before reconnect).
    private func stopSocketsOnly() {
        listenGeneration += 1
        outboundQueueLock.lock()
        isSendingOutbound = false
        outboundQueueLock.unlock()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    func stop() {
        reconnectGeneration += 1
        pendingURL = nil
        reconnectAttempt = 0
        stopSocketsOnly()
        clearOutboundQueue()
    }

    private func clearOutboundQueue() {
        outboundQueueLock.lock()
        outboundQueue.removeAll()
        outboundQueueLock.unlock()
    }

    private func enqueueOutbound(_ text: String) {
        outboundQueueLock.lock()
        if outboundQueue.count >= maxOutboundQueue {
            outboundQueue.removeFirst(outboundQueue.count - maxOutboundQueue + 1)
        }
        outboundQueue.append(text)
        outboundQueueLock.unlock()
    }

    /// Serializes WebSocket `send` calls so a failed frame stays queued and ordering is preserved.
    private func pumpOutboundQueueIfNeeded(task: URLSessionWebSocketTask) {
        outboundQueueLock.lock()
        if isSendingOutbound || outboundQueue.isEmpty {
            outboundQueueLock.unlock()
            return
        }
        isSendingOutbound = true
        let text = outboundQueue.first!
        outboundQueueLock.unlock()

        task.send(.string(text)) { [weak self] error in
            guard let self else { return }
            self.outboundQueueLock.lock()
            self.isSendingOutbound = false
            if error == nil {
                if !self.outboundQueue.isEmpty, self.outboundQueue.first == text {
                    self.outboundQueue.removeFirst()
                }
            }
            let more = !self.outboundQueue.isEmpty
            let nextTask = self.task
            self.outboundQueueLock.unlock()

            if error == nil {
                self.reconnectAttempt = 0
                if more, let t = nextTask {
                    self.pumpOutboundQueueIfNeeded(task: t)
                }
            } else {
                self.scheduleReconnect(reason: "send_error")
            }
        }
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
                self.scheduleReconnect(reason: "receive_failed")
            }
        }
    }

    private func scheduleReconnect(reason: String) {
        guard pendingURL != nil else { return }
#if DEBUG
        print("[EmergentRealtimeClient] reconnect scheduled (\(reason)), attempt \(reconnectAttempt + 1)")
#endif
        reconnectGeneration += 1
        let gen = reconnectGeneration
        reconnectAttempt += 1
        let delay = min(30.0, 0.5 * pow(2.0, Double(min(reconnectAttempt, 8))))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard gen == self.reconnectGeneration else { return }
            guard let url = self.pendingURL else { return }
            self.openConnection(to: url)
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
        case "fel_game_result":
            guard EmergentRealtimeTrust.canApplyInboundGameplayMutation(from: obj) else { return }
            let mode =
                (obj["gameModeId"] as? String)
                ?? (obj["game_mode_id"] as? String)
                ?? (obj["mode"] as? String)
                ?? "game_mode"
            let score: Double? = {
                if let n = obj["trainingScore"] as? Double { return n }
                if let n = obj["trainingScore"] as? Int { return Double(n) }
                if let n = obj["score"] as? Double { return n }
                if let n = obj["score"] as? Int { return Double(n) }
                return nil
            }()
            let clip =
                (obj["clipUrl"] as? String)
                ?? (obj["clip_url"] as? String)
            SocialShareCoordinator.shared.presentGameResult(gameModeId: mode, score: score, clipUrl: clip)
            GameplaySessionReceiptCoordinator.shared.applyVerifiedPayload(obj)
        case "prq_delta":
            guard EmergentRealtimeTrust.canApplyInboundGameplayMutation(from: obj) else { return }
            if let delta = obj["delta"] as? Int {
                let current = RorkScoreManager.shared.currentPrqScore
                RorkScoreManager.shared.applyClampedPrq(current + delta)
            } else if let delta = obj["delta"] as? Double {
                let current = RorkScoreManager.shared.currentPrqScore
                RorkScoreManager.shared.applyClampedPrq(current + Int(delta.rounded()))
            }
        case "prq_set", "prq_update", "prq":
            guard EmergentRealtimeTrust.canApplyInboundGameplayMutation(from: obj) else { return }
            applyAbsolutePrq(from: obj)
        case .none:
            if obj["prq"] != nil || obj["value"] != nil || obj["score"] != nil {
                guard EmergentRealtimeTrust.canApplyInboundGameplayMutation(from: obj) else { return }
                applyAbsolutePrq(from: obj)
            }
        default:
            if t?.contains("prq") == true {
                guard EmergentRealtimeTrust.canApplyInboundGameplayMutation(from: obj) else { return }
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

    /// Sends a UTF-8 text frame; **queues** if disconnected and drains after reconnect.
    func sendText(_ text: String) {
        enqueueOutbound(text)
        guard let t = task else {
            scheduleReconnect(reason: "send_no_task")
            return
        }
        pumpOutboundQueueIfNeeded(task: t)
    }

    /// Wraps `UnrealSystemScanPayload` JSON in a typed envelope for UE / backend routing.
    func sendSystemScanBridge(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return }
        let envelope: [String: Any] = [
            "type": "fel_system_scan",
            "scan": obj,
        ]
        guard let out = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]),
              let text = String(data: out, encoding: .utf8) else { return }
        sendText(text)
    }
}
