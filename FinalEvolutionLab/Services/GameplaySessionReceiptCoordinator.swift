import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Bridges legacy UE / Emergent JSON into the same local receipt path as ``GamePlayView/finalizeResults()`` (GAME-33 / Phase 5).
/// **NEXUS ship:** prefer ``NexusGameplayEngine/flushReceipts`` + ``SessionReceiptUploadService``.
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

    /// Parses Emergent / legacy UE JSON (transport may be authenticated; see file header — not a signed gameplay receipt). NEXUS ship prefers ``NexusGameplayEngine/flushReceipts``.
    func applyVerifiedPayload(_ obj: [String: Any]) {
        guard let vm = labViewModel else {
            Self.persistReceiptWithoutViewModel(obj)
            return
        }
        vm.ingestVerifiedGameplayReceipt(fromEmergentPayload: obj)
    }

    /// POST Swift fallback session to ``Config/gameplaySessionReceiptURL``; on 2xx ingests response as ``serverVerified``.
    @discardableResult
    func submitNativeSessionReceipt(
        matchSessionId: UUID,
        gameModeId: String,
        playerScore: Int,
        opponentScore: Int,
        durationSeconds: Int,
        comboCount: Int,
        criticalCount: Int,
        pacingScore: Int,
        isMultiplayer: Bool = false
    ) async -> Bool {
        #if DEBUG
        guard Config.submitNativeGameplayReceiptsInDebug else { return false }
        #endif

        let outcome: String = {
            switch VersusMatchOutcome.winnerSide(playerScore: playerScore, opponentScore: opponentScore) {
            case .playerWins: return "win"
            case .opponentWins: return "loss"
            case .draw: return "draw"
            }
        }()

        let body: [String: Any] = [
            "mode_id": gameModeId,
            "score": playerScore,
            "opponent_score": opponentScore,
            "duration_seconds": max(1, durationSeconds),
            "completed": true,
            "outcome": outcome,
            "combo_count": comboCount,
            "critical_count": criticalCount,
            "pacing_score": pacingScore,
            "mri_score": 72.0,
            "game_session_id": matchSessionId.uuidString,
            "is_multiplayer": isMultiplayer,
        ]

        guard let payload = await Self.postSessionReceipt(body: body) else { return false }
        applyVerifiedPayload(payload)
        return true
    }

    private static func postSessionReceipt(body: [String: Any]) async -> [String: Any]? {
        let outcome = await NexusBackendClient.postSessionReceipt(body: body, timeout: 12)
        switch outcome {
        case .success(let json):
            return nativeReceiptPayload(from: json, requestBody: body)
        case .previewQueuedLocally, .authUnavailable, .invalidURL, .networkError, .serverError:
            return nil
        }
    }

    private static func nativeReceiptPayload(from response: [String: Any], requestBody: [String: Any]) -> [String: Any] {
        let session = response["session"] as? [String: Any] ?? [:]
        let sessionId = (session["id"] as? String)
            ?? (requestBody["game_session_id"] as? String)
            ?? UUID().uuidString
        let modeId = (session["mode_id"] as? String)
            ?? (requestBody["mode_id"] as? String)
            ?? "basketball_h2h"
        let playerScore = (session["score"] as? Int)
            ?? (requestBody["score"] as? Int)
            ?? 0
        let opponentScore = (requestBody["opponent_score"] as? Int) ?? 0
        let duration = (session["duration_seconds"] as? Int)
            ?? (requestBody["duration_seconds"] as? Int)
            ?? 0
        let prqDelta = (response["prq_delta"] as? Double)
            ?? (response["prq_delta"] as? Int).map(Double.init)
            ?? 0
        let shardsEarned = (response["shards_earned"] as? Int) ?? 0
        let isMultiplayer = (requestBody["is_multiplayer"] as? Bool) ?? false

        return [
            "fel_trust_level": "server_verified",
            "fel_receipt_id": "srv:\(sessionId)",
            "session_id": sessionId,
            "game_mode_id": modeId,
            "player_score": playerScore,
            "opponent_score": opponentScore,
            "duration_seconds": duration,
            "prq_bonus": prqDelta,
            "shards_earned": shardsEarned,
            "is_multiplayer": isMultiplayer,
            "verificationSeed": sessionId,
        ]
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
