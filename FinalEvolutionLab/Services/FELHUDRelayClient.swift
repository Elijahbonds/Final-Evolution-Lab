import Foundation
import os

/// Outbound WebSocket relay for `fel.hud.frame` snapshots (spec §7.3).
/// Connect when `FEL_HUD_WS_URL` is set; otherwise no-op.
final class FELHUDRelayClient {
    static let shared = FELHUDRelayClient()

    private let log = Logger(subsystem: "com.finalevolutionlab.app", category: "FELHUDRelay")
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var pendingURL: URL?
    private var reconnectGeneration: UInt64 = 0
    private var reconnectAttempt = 0
    private var lastSendTime: CFAbsoluteTime = 0
    private var pendingFrameJSON: String?
    private let minSendInterval: CFAbsoluteTime = 1.0 / 30.0

    private init() {}

    func startIfConfigured() {
        guard let urlString = Config.resolvedHUDWebSocketURL(),
              let baseURL = URL(string: urlString) else { return }
        pendingURL = connectionURL(from: baseURL)
        reconnectAttempt = 0
        openConnection(to: pendingURL!)
    }

    func stop() {
        reconnectGeneration += 1
        pendingURL = nil
        reconnectAttempt = 0
        pendingFrameJSON = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    /// Accepts full `nexus_gameplay_session_hud_poll_json()` wrapper; throttles to ~30 Hz.
    func sendFrameIfConfigured(json: String) {
        guard task != nil else { return }
        pendingFrameJSON = json
        flushPendingFrameIfDue(force: false)
    }

    private func connectionURL(from base: URL) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        var query = components.queryItems ?? []
        if let uid = FirebaseIdentity.userId, !uid.isEmpty {
            query.removeAll { $0.name == "user_id" }
            query.append(URLQueryItem(name: "user_id", value: uid))
        }
        components.queryItems = query.isEmpty ? nil : query
        return components.url ?? base
    }

    private func flushPendingFrameIfDue(force: Bool) {
        guard let json = pendingFrameJSON, task != nil else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard force || now - lastSendTime >= minSendInterval else { return }

        guard let wireJSON = Self.wireEnvelope(fromPollJSON: json) else {
            log.debug("HUD relay skipped: unparsable poll JSON")
            return
        }

        lastSendTime = now
        pendingFrameJSON = nil

        task?.send(.string(wireJSON)) { [weak self] error in
            if let error {
                self?.log.debug("HUD relay send failed: \(error.localizedDescription, privacy: .public)")
                self?.scheduleReconnect()
            } else if let pending = self?.pendingFrameJSON {
                _ = pending
                self?.flushPendingFrameIfDue(force: false)
            }
        }
    }

    /// Extracts `{ event, type, seq, payload }` fel.hud.frame envelope from agent poll wrapper.
    static func wireEnvelope(fromPollJSON json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let frame = root["payload"] as? [String: Any]
        else {
            return nil
        }

        var envelope = frame
        if envelope["event"] == nil {
            envelope["event"] = frame["type"] ?? "fel.hud.frame"
        }
        if envelope["type"] == nil {
            envelope["type"] = "fel.hud.frame"
        }

        guard let wire = try? JSONSerialization.data(withJSONObject: envelope),
              let wireJSON = String(data: wire, encoding: .utf8)
        else {
            return nil
        }
        return wireJSON
    }

    private func openConnection(to url: URL) {
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        let sess = URLSession(configuration: cfg)
        session = sess
        let ws = sess.webSocketTask(with: url)
        task = ws
        ws.resume()
        log.info("HUD relay connected to \(url.absoluteString, privacy: .public)")
        listenForMessages()
    }

    private func listenForMessages() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message, text.contains("ping") {
                    self.task?.send(.string("{\"event\":\"pong\"}")) { _ in }
                }
                self.listenForMessages()
            case .failure:
                self.scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        guard let url = pendingURL else { return }
        reconnectGeneration += 1
        let gen = reconnectGeneration
        reconnectAttempt += 1
        let delay = min(30.0, pow(2.0, Double(reconnectAttempt)))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, gen == self.reconnectGeneration else { return }
            self.openConnection(to: url)
        }
    }
}
