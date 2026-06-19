import Foundation

/// Swift façade over the headless NEXUS `nexus_gameplay` C++ module (fel.* protocol).
@MainActor
@Observable
final class NexusGameplayEngine {
    enum ThrowCatchPhase: Int {
        case catchPhase = 0
        case load = 1
        case throwPhase = 2
        case recover = 3

        var label: String {
            switch self {
            case .catchPhase: return "CATCH"
            case .load: return "LOAD"
            case .throwPhase: return "THROW"
            case .recover: return "RECOVER"
            }
        }
    }

    private(set) var isLinked: Bool = false
    private(set) var throwCatchPhase: ThrowCatchPhase = .catchPhase
    private(set) var powerMultiplier: Double = 1.0
    private(set) var throwsTriggered: UInt64 = 0

    private var session: NexusGameplayHandle?
    private var tickTask: Task<Void, Never>?

    func start(readiness: Double) {
        stop()
        guard NexusGameplayBridge.isLinked else { return }

        guard let created = NexusGameplayBridge.createSession() else { return }
        session = created
        isLinked = true
        NexusGameplayBridge.syncReadiness(session, readiness: Float(readiness))
        refreshState()

        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled, let self else { return }
                NexusGameplayBridge.tick(self.session, deltaSeconds: 1.0 / 60.0)
                self.refreshState()
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        NexusGameplayBridge.destroySession(session)
        session = nil
        isLinked = NexusGameplayBridge.isLinked
    }

    private func refreshState() {
        guard let json = NexusGameplayBridge.sessionStateJSON(session),
              let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["payload"] as? [String: Any],
              let throwCatch = payload["throw_catch"] as? [String: Any]
        else {
            return
        }

        if let phaseRaw = throwCatch["phase"] as? Int,
           let phase = ThrowCatchPhase(rawValue: phaseRaw) {
            throwCatchPhase = phase
        }
        if let power = throwCatch["power_multiplier"] as? Double {
            powerMultiplier = power
        } else if let power = throwCatch["power_multiplier"] as? NSNumber {
            powerMultiplier = power.doubleValue
        }
        if let throwsCount = throwCatch["throws_triggered"] as? UInt64 {
            throwsTriggered = throwsCount
        } else if let throwsCount = throwCatch["throws_triggered"] as? NSNumber {
            throwsTriggered = throwsCount.uint64Value
        }
    }
}

enum NexusGameplayBridge {
    static var isLinked: Bool {
        nexus_gameplay_bridge_is_linked()
    }

    static func createSession() -> NexusGameplayHandle? {
        nexus_gameplay_session_create()
    }

    static func destroySession(_ session: NexusGameplayHandle?) {
        nexus_gameplay_session_destroy(session)
    }

    static func tick(_ session: NexusGameplayHandle?, deltaSeconds: Double) {
        nexus_gameplay_session_tick(session, deltaSeconds)
    }

    static func syncReadiness(_ session: NexusGameplayHandle?, readiness: Float) {
        nexus_gameplay_session_sync_readiness(session, readiness)
    }

    static func sessionStateJSON(_ session: NexusGameplayHandle?) -> String? {
        guard let cString = nexus_gameplay_session_state_json(session) else {
            return nil
        }
        defer { nexus_gameplay_session_free_string(cString) }
        return String(cString: cString)
    }
}
