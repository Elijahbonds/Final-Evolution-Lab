import Foundation

/// Indexes and reads NEXUS repo sources (`engine/`, `app/gameplay/`, `assets/`).
/// Edits are written only under Application Support — never back to the live repo tree.
@MainActor
final class NexusStudioWorkspaceService {
    static let shared = NexusStudioWorkspaceService()

    private let fileManager = FileManager.default
    private let allowedExtensions: Set<String> = [
        "cpp", "cc", "cxx", "h", "hpp", "mm", "m", "swift", "json", "md", "markdown", "ini", "txt"
    ]
    private let skippedDirectoryNames: Set<String> = [
        ".git", "build", "DerivedData", "node_modules", ".swiftpm", "xcuserdata"
    ]

    private(set) var repoRoot: URL?
    private(set) var lastError: String?
    private(set) var flatFilePaths: [String] = []

    private let recentFilesKey = "NexusStudio.recentFiles"
    private let recentFilesLimit = 8

    private var sandboxRoot: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("NexusStudio/sandbox", isDirectory: true)
    }

    func bootstrap() {
        repoRoot = Self.resolveRepoRoot()
        lastError = nil
        do {
            try fileManager.createDirectory(at: sandboxRoot, withIntermediateDirectories: true)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func buildFileTree(filter: NexusStudioRootFilter = .all, searchQuery: String = "") -> [NexusStudioFileNode] {
        guard let repoRoot else {
            flatFilePaths = []
            return []
        }

        let roots: [NexusStudioRoot]
        switch filter {
        case .all:
            roots = NexusStudioRoot.allCases
        case .engine:
            roots = [.engine]
        case .swift:
            roots = [.swiftApp]
        case .gameplay:
            roots = [.gameplay]
        case .assets:
            roots = [.assets]
        }

        var collectedPaths: [String] = []
        let tree = roots.compactMap { root -> NexusStudioFileNode? in
            let url = repoRoot.appendingPathComponent(root.rawValue, isDirectory: true)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let children = scanDirectory(at: url, relativePrefix: root.rawValue, pathsOut: &collectedPaths)
            return NexusStudioFileNode(
                id: root.rawValue,
                name: root.displayName,
                relativePath: root.rawValue,
                isDirectory: true,
                children: children
            )
        }

        flatFilePaths = collectedPaths.sorted()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return tree }
        return filterTree(tree, query: trimmed.lowercased())
    }

    func recentFiles() -> [NexusStudioRecentFile] {
        guard let data = UserDefaults.standard.data(forKey: recentFilesKey),
              let decoded = try? JSONDecoder().decode([NexusStudioRecentFile].self, from: data)
        else { return [] }
        return decoded
    }

    func recordRecentFile(relativePath: String) {
        var entries = recentFiles().filter { $0.relativePath != relativePath }
        entries.insert(NexusStudioRecentFile(relativePath: relativePath, openedAt: Date()), at: 0)
        if entries.count > recentFilesLimit {
            entries = Array(entries.prefix(recentFilesLimit))
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: recentFilesKey)
        }
    }

    func loadFile(relativePath: String) throws -> NexusStudioOpenFile {
        if let sandboxURL = sandboxFileURL(relativePath: relativePath),
           fileManager.fileExists(atPath: sandboxURL.path) {
            let data = try Data(contentsOf: sandboxURL)
            let text = String(data: data, encoding: .utf8) ?? ""
            return NexusStudioOpenFile(
                relativePath: relativePath,
                content: text,
                isDirty: false,
                source: .sandbox
            )
        }

        guard let repoRoot else {
            throw NexusStudioError.repoUnavailable
        }

        let repoURL = repoRoot.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: repoURL.path) else {
            throw NexusStudioError.fileNotFound(relativePath)
        }

        let data = try Data(contentsOf: repoURL)
        let text = String(data: data, encoding: .utf8) ?? ""
        let source: NexusStudioFileSource = repoRoot.lastPathComponent == "NexusStudioSnapshot" ? .bundled : .repo
        return NexusStudioOpenFile(
            relativePath: relativePath,
            content: text,
            isDirty: false,
            source: source
        )
    }

    func saveToSandbox(relativePath: String, content: String) throws {
        guard let url = sandboxFileURL(relativePath: relativePath) else {
            throw NexusStudioError.sandboxUnavailable
        }
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = content.data(using: .utf8) else {
            throw NexusStudioError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    func sandboxPathLabel() -> String {
        sandboxRoot.path
    }

    func repoPathLabel() -> String {
        repoRoot?.path ?? "Unavailable"
    }

    /// Lists Game Generator exports under `generated_games/` (newest first).
    func listGeneratedGameSpecs() -> [NexusGeneratedGameEntry] {
        let directory = sandboxRoot.appendingPathComponent("generated_games", isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { lhs, rhs in
                let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lDate > rDate
            }
            .compactMap { url -> NexusGeneratedGameEntry? in
                let relativePath = "generated_games/\(url.lastPathComponent)"
                guard let data = try? Data(contentsOf: url),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return nil }
                return NexusGeneratedGameEntry.parse(relativePath: relativePath, json: json)
            }
    }

    // MARK: - Private

    private func scanDirectory(at url: URL, relativePrefix: String, pathsOut: inout [String]) -> [NexusStudioFileNode] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries
            .sorted { lhs, rhs in
                let lDir = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let rDir = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if lDir != rDir { return lDir && !rDir }
                return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            }
            .compactMap { entry -> NexusStudioFileNode? in
                let name = entry.lastPathComponent
                if skippedDirectoryNames.contains(name) { return nil }

                let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let relativePath = relativePrefix.isEmpty ? name : "\(relativePrefix)/\(name)"

                if isDirectory {
                    let children = scanDirectory(at: entry, relativePrefix: relativePath, pathsOut: &pathsOut)
                    guard !children.isEmpty else { return nil }
                    return NexusStudioFileNode(
                        id: relativePath,
                        name: name,
                        relativePath: relativePath,
                        isDirectory: true,
                        children: children
                    )
                }

                let ext = entry.pathExtension.lowercased()
                guard allowedExtensions.contains(ext) else { return nil }
                pathsOut.append(relativePath)
                return NexusStudioFileNode(
                    id: relativePath,
                    name: name,
                    relativePath: relativePath,
                    isDirectory: false,
                    children: []
                )
            }
    }

    private func sandboxFileURL(relativePath: String) -> URL? {
        sandboxRoot.appendingPathComponent(relativePath)
    }

    private func filterTree(_ nodes: [NexusStudioFileNode], query: String) -> [NexusStudioFileNode] {
        nodes.compactMap { node in
            if node.isDirectory {
                let children = filterTree(node.children, query: query)
                guard !children.isEmpty else { return nil }
                return NexusStudioFileNode(
                    id: node.id,
                    name: node.name,
                    relativePath: node.relativePath,
                    isDirectory: true,
                    children: children
                )
            }
            let haystack = "\(node.name) \(node.relativePath)".lowercased()
            return haystack.contains(query) ? node : nil
        }
    }

    static func resolveRepoRoot() -> URL? {
        for key in ["NEXUS_REPO_ROOT", "FEL_NEXUS_REPO_ROOT"] {
            if let env = ProcessInfo.processInfo.environment[key]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !env.isEmpty,
               FileManager.default.fileExists(atPath: env) {
                return URL(fileURLWithPath: env, isDirectory: true)
            }
        }

        let bridgeRoot = NEXUSCursorBridge.resolvedRepoRootPath()
        if FileManager.default.fileExists(atPath: bridgeRoot) {
            return URL(fileURLWithPath: bridgeRoot, isDirectory: true)
        }

        #if DEBUG
        var devCandidates = [
            "/Users/elijahbonds/Final-Evolution-Lab",
        ]
        #if os(macOS)
        devCandidates.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Final-Evolution-Lab").path
        )
        #endif
        for path in devCandidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif

        if let bundled = Bundle.main.url(forResource: "NexusStudioSnapshot", withExtension: nil),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        return nil
    }
}

enum NexusStudioError: LocalizedError {
    case repoUnavailable
    case fileNotFound(String)
    case sandboxUnavailable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .repoUnavailable:
            "NEXUS repo root not found. Set NEXUS_REPO_ROOT or FEL_NEXUS_REPO_ROOT, or run from a checkout containing NEXUS_ONLY_PIVOT.md."
        case .fileNotFound(let path):
            "File not found: \(path)"
        case .sandboxUnavailable:
            "Sandbox directory is unavailable."
        case .encodingFailed:
            "Could not encode file as UTF-8."
        }
    }
}
