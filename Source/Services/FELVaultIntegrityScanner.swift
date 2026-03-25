import Foundation

/// Gold Master: quick consistency check of `Documents/FEL/` before the main shell loads.
enum FELVaultIntegrityScanner {
    struct Result: Sendable {
        var isHealthy: Bool
        var readablePaths: [String]
        var issues: [String]
    }

    static func performScan() async -> Result {
        await MainActor.run {
            var readable: [String] = []
            var issues: [String] = []
            guard let fel = try? FELDocumentsFolder.urlCreatingIfNeeded() else {
                return Result(isHealthy: false, readablePaths: [], issues: ["fel_root_unavailable"])
            }
            readable.append(fel.path)
            let fm = FileManager.default
            if !fm.isReadableFile(atPath: fel.path) {
                issues.append("fel_not_readable")
            }
            let readiness = fel.appendingPathComponent("readiness_snapshot.json")
            if fm.fileExists(atPath: readiness.path) {
                readable.append("readiness_snapshot.json")
            }
            let sessionResults = fel.appendingPathComponent("session_results.json")
            if fm.fileExists(atPath: sessionResults.path) {
                readable.append("session_results.json")
            }
            let healthy = issues.isEmpty
            return Result(isHealthy: healthy, readablePaths: readable, issues: issues)
        }
    }
}
