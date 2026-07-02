import Foundation
import Security

/// Bootstraps Google AI Studio (Gemini REST) for agent chat, game generator, and BioFuel flows.
/// Does **not** require Firebase or `GoogleService-Info.plist`.
enum NexusAIStudioBootstrap {
    enum ConnectionStatus: String, Sendable {
        case connected
        case offline
    }

    enum KeySource: String, Sendable {
        case environment
        case keychain
        case none
    }

    private static let keychainService = "com.finalevolutionlab.nexus.aistudio"
    private static let keychainAccount = "gemini_api_key"

    private static let envKeyNames = [
        "NEXUS_AI_STUDIO_API_KEY",
        "NEXUS_AGENT_GEMINI_KEY",
        "GEMINI_API_KEY",
        "FEL_LLM_KEY",
    ]

    private static var cachedKey: String?
    private static var cachedKeySource: KeySource = .none
    private static var didConfigure = false

    /// `true` when a non-empty Gemini / AI Studio API key resolved at launch.
    static var isConfigured: Bool {
        guard let key = cachedKey else { return false }
        return !key.isEmpty
    }

    static var connectionStatus: ConnectionStatus {
        isConfigured ? .connected : .offline
    }

    static var keySource: KeySource { cachedKeySource }

    static var resolvedModel: String {
        if let env = ProcessInfo.processInfo.environment["NEXUS_AI_STUDIO_MODEL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        if let env = ProcessInfo.processInfo.environment["NEXUS_AGENT_GEMINI_MODEL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        return "gemini-2.0-flash"
    }

    /// Human-readable status for dashboard cards (never includes the key).
    static var statusLabel: String {
        switch connectionStatus {
        case .connected:
            let source = keySource == .keychain ? "Keychain" : "Env"
            return FELPremiumCopy.AIStudio.connectedStatus(model: resolvedModel, source: source)
        case .offline:
            return FELPremiumCopy.AIStudio.offlineStatus
        }
    }

    /// Resolved API key for Gemini REST clients. Never log or persist outside Keychain.
    static func apiKey() -> String? {
        cachedKey
    }

    /// Call once at process launch before agent / generator surfaces.
    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        if let (key, source) = resolveAPIKey() {
            cachedKey = key
            cachedKeySource = source
            if source == .environment {
                persistKeyToKeychainIfNeeded(key)
            }
#if DEBUG
            print("[NexusAIStudioBootstrap] Configured model=\(resolvedModel) source=\(source.rawValue)")
#endif
        } else {
            cachedKey = nil
            cachedKeySource = .none
#if DEBUG
            print("[NexusAIStudioBootstrap] No API key — AI Studio offline (Firebase not required).")
#endif
        }
    }

    /// Stores a key in Keychain (Settings / dev tooling). Does not echo the key.
    @discardableResult
    static func storeAPIKeyInKeychain(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecSuccess {
            cachedKey = trimmed
            cachedKeySource = .keychain
            return true
        }
        return false
    }

    static func clearKeychainAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        if cachedKeySource == .keychain {
            cachedKey = nil
            cachedKeySource = .none
        }
    }

    // MARK: - Private

    private static func resolveAPIKey() -> (String, KeySource)? {
        for name in envKeyNames {
            if let value = ProcessInfo.processInfo.environment[name]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return (value, .environment)
            }
        }
        if let keychain = readKeyFromKeychain() {
            return (keychain, .keychain)
        }
        return nil
    }

    private static func readKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty
        else {
            return nil
        }
        return key
    }

    /// Dev convenience: persist scheme env key so subsequent launches work without Xcode env vars.
    private static func persistKeyToKeychainIfNeeded(_ key: String) {
        guard readKeyFromKeychain() == nil else { return }
        _ = storeAPIKeyInKeychain(key)
    }
}
