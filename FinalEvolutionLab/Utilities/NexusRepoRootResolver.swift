import Foundation

/// Resolves the NEXUS monorepo root for Studio IDE, Agent tools, and Cursor deep links.
enum NexusRepoRootResolver {
    private static let envKeys = ["NEXUS_REPO_ROOT", "FEL_NEXUS_REPO_ROOT"]
    private static let repoMarker = "NEXUS_ONLY_PIVOT.md"

    /// Best-effort repo root when running from a dev checkout, Cloud Agent VM, or bundled snapshot.
    static func resolveURL() -> URL? {
        for key in envKeys {
            if let value = ProcessInfo.processInfo.environment[key]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty,
               looksLikeNexusRepo(at: value) {
                return URL(fileURLWithPath: value, isDirectory: true)
            }
        }

        for path in debugCheckoutCandidates() where looksLikeNexusRepo(at: path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        if let bundled = Bundle.main.url(forResource: "NexusStudioSnapshot", withExtension: nil),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        return nil
    }

    /// Path for Cursor URIs and pasteboard — falls back to `~/Final-Evolution-Lab` when unresolved.
    static func resolvedPath() -> String {
        resolveURL()?.path ?? fallbackPath
    }

    private static var fallbackPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Final-Evolution-Lab").path
    }

    private static func looksLikeNexusRepo(at path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let marker = (path as NSString).appendingPathComponent(repoMarker)
        return FileManager.default.fileExists(atPath: marker)
    }

    private static func debugCheckoutCandidates() -> [String] {
        #if DEBUG
        var paths = ["/workspace"]
        #if os(macOS)
        paths.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Final-Evolution-Lab").path
        )
        #endif
        return paths
        #else
        return []
        #endif
    }
}
