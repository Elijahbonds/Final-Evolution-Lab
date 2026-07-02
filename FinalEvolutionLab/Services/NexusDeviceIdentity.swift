import Foundation
import Security

/// Stable anonymous device id for session receipts when Firebase Auth is unavailable.
/// Persists in Keychain (survives reinstall only when Keychain item is preserved; UserDefaults is fallback for tests).
enum NexusDeviceIdentity {
    private static let keychainService = "com.finalevolutionlab.app.device-identity"
    private static let keychainAccount = "anonymous_device_id"
    private static let userDefaultsFallbackKey = "fel_anonymous_device_id"

    /// UUID persisted on first access; included in receipt telemetry and `X-FEL-Device-Id`.
    static var anonymousDeviceId: String {
        if let existing = readKeychain() ?? UserDefaults.standard.string(forKey: userDefaultsFallbackKey),
           !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString.lowercased()
        _ = writeKeychain(fresh)
        UserDefaults.standard.set(fresh, forKey: userDefaultsFallbackKey)
        return fresh
    }

    private static func readKeychain() -> String? {
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
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    @discardableResult
    private static func writeKeychain(_ value: String) -> Bool {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}
