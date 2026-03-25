import Foundation

/// Shared `Documents/FEL` root — matches Unreal `FELPlatformPaths_IOS.mm` (device-local cache; excluded from iCloud backup).
enum FELDocumentsFolder {
    /// FileManager + URL resource updates are main-actor aligned in Swift 6; call from `@MainActor` or `await MainActor.run { … }`.
    @MainActor
    static func urlCreatingIfNeeded() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fel = docs.appendingPathComponent("FEL", isDirectory: true)
        try FileManager.default.createDirectory(at: fel, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutable = fel
        try mutable.setResourceValues(resourceValues)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: mutable.path
        )
        return mutable
    }
}
