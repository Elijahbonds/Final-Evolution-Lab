import Foundation

/// Applies `NSFileProtectionComplete` so biometric/readiness payloads are encrypted at rest when the device is locked.
enum FELBiometricFileProtection {
    /// Sets complete file protection on a file URL (creates parent directories first if needed — caller should write file before this).
    static func applyCompleteProtection(to url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    /// Ensures the `Documents/FEL` directory exists and applies complete protection to the directory (inherits to new files where supported).
    @MainActor
    static func applyCompleteProtectionToFELRootIfPossible() {
        guard let fel = try? FELDocumentsFolder.urlCreatingIfNeeded() else { return }
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fel.path
        )
    }
}
