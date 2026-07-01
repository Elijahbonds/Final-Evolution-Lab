import Foundation

/// WebSocket client for IRL dunk contest arena sessions.
/// Connects to /ws/game/{sessionId} on the FEL backend and
/// decodes dunk-specific event envelopes for the DunkCompetitionView.
@Observable
@MainActor
final class ArenaWebSocketService {

    // MARK: - Observable state consumed by DunkCompetitionView

    var phase: ArenaPhase = .idle
    var opponentJumps: [ArenaJumpEvent] = []
    var opponentMaxHeight: Double = 0
    var playerCount: Int = 0
    var allReady: Bool = false
    var errorMessage: String?

    // MARK: - Private

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var listenGeneration: UInt64 = 0
    private var sessionId: String?

    // MARK: - Connect / disconnect

    func connect(sessionId: String, baseURL: String = "wss://finalevolutiongroup.com") {
        disconnect()
        self.sessionId = sessionId
        guard let url = URL(string: "\(baseURL)/ws/game/\(sessionId)") else { return }
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        let sess = URLSession(configuration: cfg)
        session = sess
        let ws = sess.webSocketTask(with: url)
        task = ws
        listenGeneration += 1
        let gen = listenGeneration
        ws.resume()
        receiveLoop(generation: gen)
    }

    func disconnect() {
        listenGeneration += 1
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        phase = .idle
    }

    // MARK: - Send events

    func sendReady() {
        send(["type": "ready"])
    }

    func sendJump(heightInches: Double, styleKey: String = "two_hand_power") {
        send([
            "type": "dunk_jump",
            "height_inches": heightInches,
            "style_key": styleKey,
        ])
    }

    func sendMatchComplete(playerMaxHeight: Double, opponentMaxHeight: Double, playerWon: Bool) {
        send([
            "type": "dunk_match_complete",
            "player_max_height": playerMaxHeight,
            "opponent_max_height": opponentMaxHeight,
            "player_won": playerWon,
        ])
    }

    // MARK: - Private

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func receiveLoop(generation: UInt64) {
        task?.receive { [weak self] result in
            guard let self, generation == self.listenGeneration else { return }
            switch result {
            case .success(let msg):
                let text: String? = switch msg {
                case .string(let s): s
                case .data(let d): String(data: d, encoding: .utf8)
                @unknown default: nil
                }
                if let t = text { Task { @MainActor in self.handle(text: t) } }
                self.receiveLoop(generation: generation)
            case .failure(let err):
                Task { @MainActor in self.errorMessage = err.localizedDescription }
            }
        }
    }

    private func handle(text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // EmergentRealtimeTrust gate — block PRQ mutations without trusted session
        if EmergentRealtimeTrust.canApplyInboundGameplayMutation(from: obj) == false {
            let safeTypes: Set<String> = ["player_joined", "player_left", "ready_status",
                                          "dunk_jump", "score_update"]
            guard let type = obj["type"] as? String, safeTypes.contains(type) else { return }
        }

        switch obj["type"] as? String {
        case "player_joined":
            playerCount = obj["players"] as? Int ?? playerCount
        case "player_left":
            playerCount = max(0, playerCount - 1)
        case "ready_status":
            allReady = obj["all_ready"] as? Bool ?? false
            if allReady { phase = .battle }
        case "dunk_jump":
            if let h = obj["height_inches"] as? Double {
                let jump = ArenaJumpEvent(
                    heightInches: h,
                    styleKey: obj["style_key"] as? String ?? "two_hand_power",
                    timestamp: Date()
                )
                opponentJumps.append(jump)
                if h > opponentMaxHeight { opponentMaxHeight = h }
            }
        case "score_update":
            break   // handled by DunkCompetitionView local state
        case "dunk_match_complete":
            phase = .result
        default:
            break
        }
    }
}

// MARK: - Supporting types

enum ArenaPhase: String {
    case idle, lobby, matched, setup, countdown, battle, result
}

struct ArenaJumpEvent: Identifiable {
    let id = UUID()
    let heightInches: Double
    let styleKey: String
    let timestamp: Date
}
