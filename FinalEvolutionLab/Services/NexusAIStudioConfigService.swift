import Foundation

/// Google AI Studio / Gemini REST config for NEXUS Studio (direct API — not Firebase AI Logic).
@MainActor
@Observable
final class NexusAIStudioConfigService {
    static let shared = NexusAIStudioConfigService()

    enum ConnectionStatus: Equatable, Sendable {
        case unknown
        case checking
        case connected
        case templateFallback(reason: String)

        var label: String {
            switch self {
            case .unknown: "Not verified"
            case .checking: "Connecting…"
            case .connected: "Connected"
            case .templateFallback: "Templates only"
            }
        }

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    static let availableModels: [String] = [
        "gemini-2.0-flash",
        "gemini-2.5-flash",
        "gemini-1.5-flash",
        "gemini-1.5-pro",
    ]

    private static let modelDefaultsKey = "NexusAIStudio.selectedModel"
    private static let lastPingDefaultsKey = "NexusAIStudio.lastPingSummary"

    private(set) var connectionStatus: ConnectionStatus = .unknown
    private(set) var lastPingMessage: String?

    var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: Self.modelDefaultsKey)
        }
    }

    /// In-memory draft while editing; persisted to Keychain on Save.
    var apiKeyDraft: String = ""

    private init() {
        NexusAIStudioBootstrap.configureIfNeeded()
        let stored = UserDefaults.standard.string(forKey: Self.modelDefaultsKey)
        selectedModel = stored ?? NexusAIStudioBootstrap.resolvedModel
        lastPingMessage = UserDefaults.standard.string(forKey: Self.lastPingDefaultsKey)
    }

    var hasStoredKey: Bool {
        NexusAIStudioBootstrap.isConfigured
    }

    func refreshKeyPresence() {
        NexusAIStudioBootstrap.configureIfNeeded()
        if !hasStoredKey, case .connected = connectionStatus {
            connectionStatus = .templateFallback(reason: "No API key")
        }
    }

    /// Keychain → env fallbacks (same order as C++ `resolvedGeminiApiKey`).
    func resolvedAPIKey() -> String? {
        NexusAIStudioBootstrap.apiKey()
    }

    var apiKeySourceLabel: String {
        switch NexusAIStudioBootstrap.keySource {
        case .keychain: "Keychain"
        case .environment: "Environment"
        case .none: "none"
        }
    }

    func saveAPIKeyFromDraft() throws {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            NexusAIStudioBootstrap.clearKeychainAPIKey()
            apiKeyDraft = ""
            connectionStatus = .templateFallback(reason: "No API key")
            return
        }
        guard NexusAIStudioBootstrap.storeAPIKeyInKeychain(trimmed) else {
            throw SaveError.keychainWriteFailed
        }
        apiKeyDraft = ""
    }

    func clearStoredKey() {
        NexusAIStudioBootstrap.clearKeychainAPIKey()
        apiKeyDraft = ""
        connectionStatus = .templateFallback(reason: "No API key")
    }

    /// Params for `fel.generate.game` / `fel.generate.refine_game`.
    func gameplayCommandParams(forceTemplate: Bool = false) -> [String: Any] {
        var params: [String: Any] = ["force_template": forceTemplate]
        if !forceTemplate, let key = resolvedAPIKey() {
            params["gemini_api_key"] = key
            params["gemini_model"] = selectedModel
        }
        return params
    }

    var shouldForceTemplate: Bool {
        !NexusAIStudioBootstrap.isConfigured
    }

    /// Lightweight REST ping — `generateContent` with "ping".
    func pingGemini() async {
        connectionStatus = .checking
        lastPingMessage = nil

        guard let apiKey = resolvedAPIKey() else {
            connectionStatus = .templateFallback(reason: "No API key")
            lastPingMessage = "Add an AI Studio API key or set GEMINI_API_KEY in the scheme."
            persistPingSummary()
            return
        }

        let model = selectedModel
        guard let url = URL(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        ) else {
            connectionStatus = .templateFallback(reason: "Invalid model URL")
            lastPingMessage = "Invalid model selection."
            persistPingSummary()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": "Reply with exactly: pong"]]],
            ],
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw PingError.invalidResponse
            }
            guard http.statusCode == 200 else {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                throw PingError.httpStatus(http.statusCode, bodyText)
            }

            connectionStatus = .connected
            lastPingMessage = "Gemini \(model) responded OK · source: \(apiKeySourceLabel)"
        } catch let error as PingError {
            connectionStatus = .templateFallback(reason: error.localizedDescription)
            lastPingMessage = error.localizedDescription
        } catch {
            connectionStatus = .templateFallback(reason: error.localizedDescription)
            lastPingMessage = error.localizedDescription
        }

        persistPingSummary()
    }

    private func persistPingSummary() {
        UserDefaults.standard.set(lastPingMessage, forKey: Self.lastPingDefaultsKey)
    }

    enum SaveError: LocalizedError {
        case keychainWriteFailed

        var errorDescription: String? {
            "Keychain save failed."
        }
    }

    enum PingError: LocalizedError {
        case invalidResponse
        case httpStatus(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Gemini returned an unparseable response."
            case .httpStatus(let code, let body):
                let snippet = String(body.prefix(160))
                return "Gemini HTTP \(code): \(snippet)"
            }
        }
    }
}
