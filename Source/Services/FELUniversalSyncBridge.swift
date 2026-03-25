import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

/// Universal Master: XOR+Base64 payload from `UFELSaveGame::ExportSaveToJSON` (host posts via `FelUniversalSyncExport`).
enum FELUniversalSyncBridge {
    static let userDefaultsKey = "felLastUniversalSyncBase64"

    static func cacheFromNotification(_ base64: String) {
        UserDefaults.standard.set(base64, forKey: userDefaultsKey)
    }

    static var cachedBase64: String? {
        UserDefaults.standard.string(forKey: userDefaultsKey)
    }

    /// Manual bridge: log full payload (console) + system clipboard for Firebase / iCloud handoff.
    static func syncToCloudConsoleAndClipboard() {
        let payload = cachedBase64 ?? ""
        print("[FEL UniversalSync] base64 length=\(payload.count)")
        print("[FEL UniversalSync] payload=\(payload)")
        #if canImport(UIKit)
        UIPasteboard.general.string = payload
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        #endif
    }
}
