import Foundation
import os

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Shared HTTP helpers for NEXUS ↔ FastAPI contract (`docs/NEXUS_BACKEND_CONTRACT.md`).
enum NexusBackendClient {
    private static let log = Logger(subsystem: "com.finalevolutionlab.app", category: "NexusBackendClient")

    /// UserDefaults mirror for `FEL_BACKEND_AUTH_TOKEN` / web `POST /api/auth/session` handoff.
    static let backendAuthTokenDefaultsKey = "fel_backend_auth_token"

    /// Outcome of ``postSessionReceipt(body:timeout:)`` — distinguishes PREVIEW queue-only from live POST failures.
    enum SessionReceiptPostOutcome: Sendable, Equatable {
        case success(response: [String: Any])
        /// Placeholder plist / `--preview-firebase` — receipt stays on disk; no network attempt.
        case previewQueuedLocally
        case authUnavailable(reason: String)
        case serverError(statusCode: Int, detail: String)
        case networkError(String)
        case invalidURL

        /// Human-readable surface for Dashboard toasts and debug HUD.
        var userFacingMessage: String {
            switch self {
            case .success:
                return "Session receipt verified by server."
            case .previewQueuedLocally:
                return "PREVIEW build — receipts saved locally (no backend POST in preview lane)."
            case .authUnavailable(let reason):
                return "Session receipt upload needs backend auth: \(reason)"
            case .serverError(let code, let detail):
                return "Server rejected receipt (HTTP \(code)): \(detail)"
            case .networkError(let detail):
                return "Network error uploading receipt: \(detail)"
            case .invalidURL:
                return "Invalid session receipt URL — check FEL_API_BASE_URL / FEL_SESSION_RECEIPT_URL."
            }
        }

        /// `true` when the on-disk receipt should remain for a later drain attempt.
        var keepsReceiptOnDisk: Bool {
            switch self {
            case .success:
                return false
            case .previewQueuedLocally, .authUnavailable, .serverError, .networkError, .invalidURL:
                return true
            }
        }

        static func == (lhs: SessionReceiptPostOutcome, rhs: SessionReceiptPostOutcome) -> Bool {
            switch (lhs, rhs) {
            case (.previewQueuedLocally, .previewQueuedLocally),
                 (.invalidURL, .invalidURL):
                return true
            case let (.authUnavailable(l), .authUnavailable(r)):
                return l == r
            case let (.serverError(lCode, lDetail), .serverError(rCode, rDetail)):
                return lCode == rCode && lDetail == rDetail
            case let (.networkError(l), .networkError(r)):
                return l == r
            case (.success, .success):
                return true
            default:
                return false
            }
        }
    }

    /// `true` when TestFlight preview plist lane — POST is skipped unless an explicit backend token is present.
    static var isPreviewLane: Bool {
        FirebaseBootstrap.isPreviewMode && resolvedBackendAuthToken == nil
    }

    /// `true` when a backend auth token or Firebase ID token can be attached (Phase 7 — Firebase optional).
    static var hasUploadAuthCredential: Bool {
        resolvedBackendAuthToken != nil || firebaseAuthMayProvideToken
    }

    /// `true` when not in preview lane, URL is valid, and an auth credential exists.
    static var canPostSessionReceipts: Bool {
        guard !isPreviewLane else { return false }
        guard URL(string: sessionReceiptURL) != nil else { return false }
        return hasUploadAuthCredential
    }

    /// Human-readable lane label for Status / Dashboard surfaces.
    static var sessionReceiptLaneLabel: String {
        if isPreviewLane {
            return FELPremiumCopy.Receipt.savedLocally
        }
        if !hasUploadAuthCredential {
            return FELPremiumCopy.Receipt.awaitingAuth
        }
        if resolvedBackendAuthToken != nil {
            return FELPremiumCopy.Receipt.backendConnected
        }
        return FELPremiumCopy.Receipt.firebaseConnected
    }

    /// `true` when an AI Studio / Gemini API key is configured (AI Studio era metadata on receipts).
    static var isAIStudioConfigured: Bool {
        if NexusAIStudioBootstrap.isConfigured { return true }
        for key in [
            "NEXUS_AI_STUDIO_API_KEY",
            "NEXUS_AGENT_GEMINI_KEY",
            "GEMINI_API_KEY",
            "FEL_LLM_KEY",
        ] {
            if let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return true
            }
        }
        return false
    }

    /// FEL session token from env or UserDefaults — preferred over Firebase when set.
    static var resolvedBackendAuthToken: String? {
        for key in ["FEL_BACKEND_AUTH_TOKEN", "FEL_SESSION_TOKEN"] {
            if let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        if let stored = UserDefaults.standard.string(forKey: backendAuthTokenDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }
        return nil
    }

    private static var firebaseAuthMayProvideToken: Bool {
#if canImport(FirebaseAuth)
        FirebaseBootstrap.isConfigured && !FirebaseBootstrap.isPreviewMode
#else
        false
#endif
    }

    /// Production API host; override with `FEL_API_BASE_URL` (no trailing slash).
    static var apiBaseURL: String {
        if let env = ProcessInfo.processInfo.environment["FEL_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env.trimmingSuffix("/")
        }
        #if DEBUG
        if let local = ProcessInfo.processInfo.environment["FEL_LOCAL_API"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !local.isEmpty {
            return local.trimmingSuffix("/")
        }
        return "http://127.0.0.1:8000"
        #else
        return "https://api.finalevolutiongroup.com"
        #endif
    }

    static var sessionReceiptURL: String {
        if let env = ProcessInfo.processInfo.environment["FEL_SESSION_RECEIPT_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        return "\(apiBaseURL)/api/games/session"
    }

    static var mobileConfigURL: String {
        "\(apiBaseURL)/api/mobile/config"
    }

    static func applyClientHeaders(to request: inout URLRequest) {
        request.setValue("ios", forHTTPHeaderField: "X-FEL-Client")
        request.setValue(NexusDeviceIdentity.anonymousDeviceId, forHTTPHeaderField: "X-FEL-Device-Id")
        request.setValue("fel-ios/1.0 (NEXUS)", forHTTPHeaderField: "User-Agent")
    }

    /// `GET /api/mobile/config` — applies optional remote WS hub when no local override is set.
    static func fetchMobileConfig() async -> [String: Any]? {
        guard let url = URL(string: mobileConfigURL) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        applyClientHeaders(to: &request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            applyMobileConfig(json)
            return json
        } catch {
            return nil
        }
    }

    private static func applyMobileConfig(_ config: [String: Any]) {
        let hasEnvWS = !(ProcessInfo.processInfo.environment["FEL_GAME_WS_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasStoredWS = !(UserDefaults.standard.string(forKey: Config.emergentGameWebSocketDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard !hasEnvWS, !hasStoredWS else { return }

        guard let hub = config["live_data_hub"] as? [String: Any],
              let wsURL = hub["ws_url"] as? String,
              !wsURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        UserDefaults.standard.set(wsURL, forKey: Config.emergentGameWebSocketDefaultsKey)
    }

    /// `POST /api/games/session` — PREVIEW lane skips; live lane uses backend token or Firebase Bearer.
    static func postSessionReceipt(
        body: [String: Any],
        timeout: TimeInterval = 15
    ) async -> SessionReceiptPostOutcome {
        if isPreviewLane {
            log.info("Session receipt POST skipped — \(sessionReceiptLaneLabel, privacy: .public)")
            return .previewQueuedLocally
        }

        guard let url = URL(string: sessionReceiptURL) else {
            log.error("Invalid sessionReceiptURL")
            return .invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        applyClientHeaders(to: &request)

        switch await resolveAuthorizationBearer() {
        case .success(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .failure(let reason):
            log.warning("Receipt POST auth unavailable: \(reason, privacy: .public)")
            return .authUnavailable(reason: reason)
        }

        let enrichedBody = SessionReceiptUploadService.normalizedReceiptBody(from: body)
        guard let httpBody = try? JSONSerialization.data(withJSONObject: enrichedBody) else {
            return .networkError("Failed to encode receipt body")
        }
        request.httpBody = httpBody

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .networkError("Non-HTTP response")
            }
            guard (200...299).contains(http.statusCode) else {
                let detail = Self.serverErrorDetail(from: responseData)
                log.warning("Receipt POST failed status=\(http.statusCode) detail=\(detail, privacy: .public)")
                return .serverError(statusCode: http.statusCode, detail: detail)
            }
            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                return .networkError("Invalid JSON response")
            }
            log.info("Receipt POST succeeded status=\(http.statusCode)")
            return .success(response: json)
        } catch {
            log.error("Receipt POST error: \(error.localizedDescription, privacy: .public)")
            return .networkError(error.localizedDescription)
        }
    }

    private enum AuthResolveResult {
        case success(String)
        case failure(String)
    }

    /// Prefer `FEL_BACKEND_AUTH_TOKEN` / stored session token; fall back to Firebase ID token.
    private static func resolveAuthorizationBearer() async -> AuthResolveResult {
        if let backendToken = resolvedBackendAuthToken {
            return .success(backendToken)
        }

#if canImport(FirebaseAuth)
        guard firebaseAuthMayProvideToken else {
            return .failure("Set FEL_BACKEND_AUTH_TOKEN or configure Firebase for receipt POST.")
        }
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
        } catch {
            return .failure(error.localizedDescription)
        }
        guard let token = try? await Auth.auth().currentUser?.getIDToken() else {
            return .failure("Missing Firebase ID token")
        }
        return .success(token)
#else
        return .failure("Set FEL_BACKEND_AUTH_TOKEN for receipt POST (FirebaseAuth unavailable).")
#endif
    }

    /// Extract FastAPI `detail` (string or validation array) for honest client error surfaces.
    static func serverErrorDetail(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "Unexpected response body"
        }
        if let detail = json["detail"] as? String, !detail.isEmpty {
            return detail
        }
        if let items = json["detail"] as? [[String: Any]] {
            let messages = items.compactMap { item -> String? in
                if let msg = item["msg"] as? String { return msg }
                return nil
            }
            if !messages.isEmpty {
                return messages.joined(separator: "; ")
            }
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        return "Request failed"
    }
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
