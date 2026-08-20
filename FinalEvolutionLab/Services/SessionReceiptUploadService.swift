import Foundation
import os

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Scans `~/.fel/pending_receipts/*.json` (written by NEXUS flush) and POSTs each to the session API.
enum SessionReceiptUploadService {
    private static let log = Logger(subsystem: "com.finalevolutionlab.app", category: "SessionReceiptUpload")

    static var pendingReceiptsDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".fel/pending_receipts", isDirectory: true)
    }

    struct UploadSummary: Sendable {
        let attempted: Int
        let succeeded: Int
        let failed: Int
        /// Receipts left on disk because Firebase is in PREVIEW / offline lane (not counted as failures).
        let skippedPreview: Int
        /// Live lane but auth/token unavailable — receipts remain queued (not hard failures).
        let authSkipped: Int
        /// Corrupt JSON on disk — not retriable via POST until file is fixed or removed.
        let invalidJSON: Int
        /// Last honest error for Dashboard / toast surfaces.
        let lastErrorMessage: String?

        var hadFailures: Bool { failed > 0 || invalidJSON > 0 }
        var pendingOnDisk: Int { max(0, attempted - succeeded) }
        var isPreviewLane: Bool { skippedPreview > 0 && failed == 0 && authSkipped == 0 }
    }

    /// Updated after each ``uploadPendingReceipts()`` call for Dashboard status surfaces.
    private(set) static var lastDrainSummary: UploadSummary?

    struct QueueSnapshot: Sendable {
        let pendingCount: Int
        let queueDirectory: String
        let canPost: Bool
        let laneLabel: String
    }

    static func queueSnapshot() -> QueueSnapshot {
        let count = (try? pendingReceiptFileURLs()?.count) ?? 0
        return QueueSnapshot(
            pendingCount: count,
            queueDirectory: pendingReceiptsDirectory.path,
            canPost: NexusBackendClient.canPostSessionReceipts,
            laneLabel: NexusBackendClient.sessionReceiptLaneLabel
        )
    }

    private static func pendingReceiptFileURLs() throws -> [URL]? {
        let directory = pendingReceiptsDirectory
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let entries = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return entries.filter { $0.pathExtension.lowercased() == "json" }
    }

    /// Uploads every JSON file in the pending queue; deletes files on HTTP 2xx.
    /// PREVIEW lane skips POST honestly; live lane needs backend URL + auth token (Firebase optional).
    @discardableResult
    static func uploadPendingReceipts() async -> UploadSummary {
        if NexusBackendClient.isPreviewLane {
            let pending = (try? pendingReceiptFileURLs()?.count) ?? 0
            if pending > 0 {
                log.info(
                    "PREVIEW lane — \(pending) receipt(s) queued at \(pendingReceiptsDirectory.path, privacy: .public); POST deferred until non-preview build"
                )
            } else {
                log.debug("PREVIEW lane — no pending receipts")
            }
            let summary = UploadSummary(
                attempted: pending,
                succeeded: 0,
                failed: 0,
                skippedPreview: pending,
                authSkipped: 0,
                invalidJSON: 0,
                lastErrorMessage: pending > 0
                    ? NexusBackendClient.SessionReceiptPostOutcome.previewQueuedLocally.userFacingMessage
                    : nil
            )
            lastDrainSummary = summary
            return summary
        }

        let directory = pendingReceiptsDirectory
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: directory.path) else {
            log.debug("No pending receipt directory at \(directory.path, privacy: .public)")
            let summary = UploadSummary(
                attempted: 0, succeeded: 0, failed: 0, skippedPreview: 0,
                authSkipped: 0, invalidJSON: 0, lastErrorMessage: nil
            )
            lastDrainSummary = summary
            return summary
        }

        guard let jsonFiles = try? pendingReceiptFileURLs(), !jsonFiles.isEmpty else {
            if (try? pendingReceiptFileURLs()) == nil {
                log.error("Failed to list pending receipts at \(directory.path, privacy: .public)")
                let message = "Could not read pending session receipts."
                await MainActor.run {
                    FelToastCenter.shared.show(
                        message,
                        isError: true,
                        retry: { Task { await uploadPendingReceipts() } }
                    )
                }
                let summary = UploadSummary(
                    attempted: 0, succeeded: 0, failed: 1, skippedPreview: 0,
                    authSkipped: 0, invalidJSON: 0, lastErrorMessage: message
                )
                lastDrainSummary = summary
                return summary
            }
            let summary = UploadSummary(
                attempted: 0, succeeded: 0, failed: 0, skippedPreview: 0,
                authSkipped: 0, invalidJSON: 0, lastErrorMessage: nil
            )
            lastDrainSummary = summary
            return summary
        }

        var succeeded = 0
        var failed = 0
        var authSkipped = 0
        var invalidJSON = 0
        var lastErrorMessage: String?
        for fileURL in jsonFiles {
            let result = await uploadReceiptFile(at: fileURL)
            switch result {
            case .success:
                succeeded += 1
            case .authSkipped:
                authSkipped += 1
            case .invalidJSON:
                invalidJSON += 1
                lastErrorMessage = "Invalid receipt JSON — check \(fileURL.lastPathComponent)."
            case .failed(let outcome):
                failed += 1
                lastErrorMessage = outcome.userFacingMessage
            }
        }

        let summary = UploadSummary(
            attempted: jsonFiles.count,
            succeeded: succeeded,
            failed: failed,
            skippedPreview: 0,
            authSkipped: authSkipped,
            invalidJSON: invalidJSON,
            lastErrorMessage: lastErrorMessage
        )
        lastDrainSummary = summary
        if summary.hadFailures {
            await MainActor.run {
                FelToastCenter.shared.show(
                    lastErrorMessage ?? "Session receipt upload failed — saved offline for retry.",
                    isError: true,
                    retry: { Task { await uploadPendingReceipts() } }
                )
            }
        } else if authSkipped > 0 {
            await MainActor.run {
                FelToastCenter.shared.show(
                    lastErrorMessage ?? "Set FEL_BACKEND_AUTH_TOKEN or sign in to upload queued session receipts.",
                    isError: true,
                    retry: { Task { await uploadPendingReceipts() } }
                )
            }
        } else if succeeded > 0 {
            await MainActor.run {
                FelToastCenter.shared.show(
                    "Uploaded \(succeeded) session receipt\(succeeded == 1 ? "" : "s").",
                    isError: false
                )
            }
        }
        return summary
    }

    private enum UploadReceiptResult {
        case success
        case authSkipped
        case invalidJSON
        case failed(NexusBackendClient.SessionReceiptPostOutcome)
    }

    /// Ensures NEXUS disk receipts match ``SessionReceiptIn`` before POST.
    static func normalizedReceiptBody(from raw: [String: Any]) -> [String: Any] {
        var body = raw

        if body["mode_id"] == nil,
           let telemetry = body["telemetry"] as? [String: Any],
           let modeId = telemetry["mode_id"] as? String {
            body["mode_id"] = modeId
        }
        if let modeId = body["mode_id"] as? String,
           let normalized = GameModeId.fromNexusRuntimeModeId(modeId)?.nexusReceiptModeId,
           !normalized.isEmpty {
            body["mode_id"] = normalized
        }

        if body["score"] == nil, let playerScore = body["player_score"] {
            body["score"] = playerScore
        }

        if body["outcome"] == nil {
            let rawOutcome = (body["result_type"] as? String)
                ?? ((body["telemetry"] as? [String: Any])?["results"] as? [String: Any])?["outcome"] as? String
                ?? "loss"
            switch rawOutcome.lowercased() {
            case "win", "draw", "loss":
                body["outcome"] = rawOutcome.lowercased()
            default:
                body["outcome"] = "loss"
            }
        }

        if body["duration_seconds"] == nil {
            body["duration_seconds"] = 60
        }
        if body["completed"] == nil {
            body["completed"] = true
        }
        if body["combo_count"] == nil {
            body["combo_count"] = 0
        }
        if body["critical_count"] == nil {
            body["critical_count"] = 0
        }
        if body["pacing_score"] == nil {
            body["pacing_score"] = 0
        }
        if body["mri_score"] == nil {
            body["mri_score"] = 50.0
        }
        if body["arv"] == nil {
            body["arv"] = 50
        }
        if body["esi"] == nil {
            body["esi"] = 50
        }
        var telemetry = body["telemetry"] as? [String: Any] ?? [:]
        if telemetry["device_id"] == nil {
            telemetry["device_id"] = NexusDeviceIdentity.anonymousDeviceId
        }
        if NexusBackendClient.isAIStudioConfigured, telemetry["ai_provider"] == nil {
            telemetry["ai_provider"] = "ai_studio"
        }
        body["telemetry"] = telemetry

        return body
    }

    @discardableResult
    private static func uploadReceiptFile(at fileURL: URL) async -> UploadReceiptResult {
        guard let data = try? Data(contentsOf: fileURL),
              let rawBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            log.error("Invalid receipt JSON at \(fileURL.lastPathComponent, privacy: .public)")
            return .invalidJSON
        }

        let requestBody = normalizedReceiptBody(from: rawBody)
        let outcome = await NexusBackendClient.postSessionReceipt(body: requestBody)

        switch outcome {
        case .previewQueuedLocally:
            log.info("Receipt kept on disk (PREVIEW lane): \(fileURL.lastPathComponent, privacy: .public)")
            return .failed(outcome)
        case .authUnavailable(let reason):
            log.warning("Receipt upload skipped (auth): \(reason, privacy: .public)")
            return .authSkipped
        case .invalidURL, .networkError, .serverError:
            log.warning("Receipt upload failed: \(outcome.userFacingMessage, privacy: .public)")
            return .failed(outcome)
        case .success(let responseJSON):
            try? FileManager.default.removeItem(at: fileURL)
            log.info("Uploaded receipt \(fileURL.lastPathComponent, privacy: .public)")
            await ingestServerResponse(responseJSON, requestBody: requestBody)
            return .success
        }
    }

    @MainActor
    private static func ingestServerResponse(_ response: [String: Any], requestBody: [String: Any]) {
        let sessionId = (response["session_id"] as? String) ?? UUID().uuidString
        let modeId = (response["mode_id"] as? String)
            ?? (requestBody["mode_id"] as? String)
            ?? "basketball_h2h"
        let playerScore = (response["score"] as? Int)
            ?? (requestBody["score"] as? Int)
            ?? 0
        let economy = response["economy"] as? [String: Any]
        let prqDelta = (economy?["prq_delta"] as? Double)
            ?? (response["prq_delta"] as? Double)
            ?? 0
        let shardsEarned = (economy?["shards"] as? Int)
            ?? (response["shards_earned"] as? Int)
            ?? 0

        let payload: [String: Any] = [
            "fel_trust_level": "server_verified",
            "fel_receipt_id": "srv:\(sessionId)",
            "session_id": sessionId,
            "game_mode_id": modeId,
            "player_score": playerScore,
            "duration_seconds": requestBody["duration_seconds"] as? Int ?? 0,
            "prq_bonus": prqDelta,
            "shards_earned": shardsEarned,
            "verificationSeed": sessionId,
        ]
        GameplaySessionReceiptCoordinator.shared.applyVerifiedPayload(payload)
    }
}
