import Foundation

/// Bridges UE / Emergent JSON into the same local receipt path as ``GamePlayView/finalizeResults()`` (GAME-33 / Phase 5).
///
/// Use ``GameSessionTrustLevel``: default bridge payloads are ``sessionBound`` (history only in Release). Set ``fel_trust_level``
/// / ``trust_level`` to ``server_verified`` when the backend certifies the session. Cryptographic signing is future work.
///
/// Parses Emergent / UE bridge payloads and merges them into ``LabViewModel`` or offline profile persistence.
@MainActor
final class GameplaySessionReceiptCoordinator {
    static let shared = GameplaySessionReceiptCoordinator()

    weak var labViewModel: LabViewModel?

    func attach(_ viewModel: LabViewModel) {
        labViewModel = viewModel
    }

    /// Parses server/UE JSON (transport may be authenticated; see file header — not a signed gameplay receipt). Emergent WS or ``UnrealManager`` bridge.
    func applyVerifiedPayload(_ obj: [String: Any]) {
        guard let vm = labViewModel else {
            Self.persistReceiptWithoutViewModel(obj)
            return
        }
        vm.ingestVerifiedGameplayReceipt(fromEmergentPayload: obj)
    }

    private static func persistReceiptWithoutViewModel(_ obj: [String: Any]) {
        guard let parsed = parseReceiptFields(obj) else { return }
        let rid = stableReceiptId(obj: obj, parsed: parsed)
        let existing = SaveSystem.loadGameResults()
        if existing.contains(where: { $0.id == rid }) { return }

        var profile = SaveSystem.loadProfile()
        if parsed.trustLevel == .serverVerified {
            profile.metrics.prqScore = PRQ.clamp(profile.metrics.prqScore + parsed.prqBonus)
            profile.metrics.neuralDrive = min(100, profile.metrics.neuralDrive + 3)
            if parsed.shardsEarned > 0 {
                profile.pendingUnverifiedShardCredits += parsed.shardsEarned
            }
        }

        let result = GameSessionResult(
            id: rid,
            gameModeId: parsed.mode.rawValue,
            date: Date(),
            score: parsed.playerScore,
            opponentScore: parsed.opponentScore,
            shardsEarned: parsed.shardsEarned,
            prqBonus: parsed.prqBonus,
            isMultiplayer: parsed.isMultiplayer,
            duration: parsed.durationSeconds,
            verificationSeed: parsed.verificationSeed,
            trustLevel: parsed.trustLevel
        )
        SaveSystem.saveProfile(profile)
        SaveSystem.saveGameResult(result)
    }

    struct ParsedReceiptFields {
        let mode: GameModeId
        let playerScore: Int
        let opponentScore: Int
        let durationSeconds: Int
        let prqBonus: Double
        let shardsEarned: Int
        let isMultiplayer: Bool
        let verificationSeed: UInt64?
        let trustLevel: GameSessionTrustLevel
    }

    /// UE/Emergent payloads default to ``sessionBound`` until the backend sets ``fel_trust_level`` / ``trust_level`` to ``server_verified``.
    static func parseTrustLevel(_ obj: [String: Any]) -> GameSessionTrustLevel {
        let raw = ((obj["fel_trust_level"] as? String) ?? (obj["trust_level"] as? String) ?? "")
            .lowercased()
        switch raw {
        case "server_verified", "serververified": return .serverVerified
        case "session_bound", "sessionbound": return .sessionBound
        case "local_practice", "localpractice": return .localPractice
        default: return .sessionBound
        }
    }

    /// Stable id for dedup — ``ue:<session>`` from bridge fields, or deterministic fallback when no session id is present.
    static func stableReceiptId(obj: [String: Any], parsed: ParsedReceiptFields) -> String {
        if let pre = obj["fel_receipt_id"] as? String, !pre.isEmpty { return pre }
        for key in ["session_id", "ue_session_id", "emergent_session_id", "game_session_id", "fel_session_id"] {
            if let s = obj[key] as? String, !s.isEmpty {
                return s.hasPrefix("ue:") ? s : "ue:\(s)"
            }
        }
        var h: UInt64 = 14_695_981_039_346_561
        let basis = "\(parsed.mode.rawValue)|\(parsed.playerScore)|\(parsed.opponentScore)|\(parsed.durationSeconds)"
        for b in basis.utf8 { h ^= UInt64(b); h &*= 1_099_505_333 }
        return "ue:nosession:\(h)"
    }

    static func parseReceiptFields(_ obj: [String: Any]) -> ParsedReceiptFields? {
        let modeStr =
            (obj["gameModeId"] as? String)
            ?? (obj["game_mode_id"] as? String)
            ?? (obj["mode"] as? String)
            ?? "basketball_h2h"
        guard let mode = GameModeId(rawValue: modeStr) else { return nil }

        let playerScore = firstInt(obj, keys: "playerScore", "player_score", "score", "trainingScore") ?? 0
        let opponentScore = firstInt(obj, keys: "opponentScore", "opponent_score", "aiScore", "ai_score") ?? 0
        let durationSeconds = max(0, firstInt(obj, keys: "duration", "durationSeconds", "duration_seconds", "elapsedSeconds") ?? 0)
        let shardsEarned = firstInt(obj, keys: "shardsEarned", "shards_earned", "evolutionShardsDelta") ?? 0

        let prqBonus: Double = {
            if let d = obj["prqBonus"] as? Double { return d }
            if let d = obj["prq_bonus"] as? Double { return d }
            if let i = obj["prqBonus"] as? Int { return Double(i) }
            if let d = obj["prq_delta"] as? Double { return d }
            if let i = obj["prq_delta"] as? Int { return Double(i) }
            return 0
        }()

        let isMultiplayer = (obj["isMultiplayer"] as? Bool)
            ?? (obj["is_multiplayer"] as? Bool)
            ?? (obj["multiplayer"] as? Bool)
            ?? false

        let verificationSeed: UInt64? = {
            if let u = obj["verificationSeed"] as? UInt64 { return u }
            if let i = obj["verificationSeed"] as? Int { return UInt64(bitPattern: Int64(i)) }
            if let s = obj["verificationSeed"] as? String {
                var h: UInt64 = 14_695_981_039_346_561
                for b in s.utf8 { h ^= UInt64(b); h &*= 1_099_505_333 }
                return h
            }
            if let s = obj["ue_session_id"] as? String {
                var h: UInt64 = 14_695_981_039_346_561
                for b in s.utf8 { h ^= UInt64(b); h &*= 1_099_505_333 }
                return h
            }
            return nil
        }()

        return ParsedReceiptFields(
            mode: mode,
            playerScore: playerScore,
            opponentScore: opponentScore,
            durationSeconds: durationSeconds,
            prqBonus: prqBonus,
            shardsEarned: shardsEarned,
            isMultiplayer: isMultiplayer,
            verificationSeed: verificationSeed,
            trustLevel: parseTrustLevel(obj)
        )
    }

    private static func firstInt(_ obj: [String: Any], keys: String...) -> Int? {
        for k in keys {
            if let v = obj[k] as? Int { return v }
            if let v = obj[k] as? Double { return Int(v.rounded()) }
            if let v = obj[k] as? String, let i = Int(v) { return i }
        }
        return nil
    }
}
