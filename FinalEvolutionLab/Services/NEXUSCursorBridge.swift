import Foundation

#if os(iOS)
import UIKit
#endif

/// Shared Cursor ↔ NEXUS Agent bridge — repo root, deep links, and tool registry metadata.
enum NEXUSCursorBridge {
    static let registryRelativePath = "Config/nexus_cursor_tool_registry.json"

    static let mcpSurfaceTools: [String] = [
        "list_modes",
        "playtest",
        "build_gate",
        "agent_command",
        "list_artifacts",
        "studio_open_file",
        "studio_run_playtest",
    ]

    static func resolvedRepoRootPath() -> String {
        NexusRepoRootResolver.resolvedPath()
    }

    static func cursorRepoURI() -> String {
        "cursor://file/\(resolvedRepoRootPath())"
    }

    static func cursorFileURI(absolutePath: String, line: Int? = nil) -> String {
        if let line {
            return "cursor://file/\(absolutePath):\(line)"
        }
        return "cursor://file/\(absolutePath)"
    }

    static func copyRepoRootToPasteboard() {
        #if os(iOS)
        UIPasteboard.general.string = resolvedRepoRootPath()
        #endif
    }

    static func copyTextToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }

    static func openCursorRepoURL() {
        guard let url = URL(string: cursorRepoURI()) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    static func openCursorFileURL(absolutePath: String, line: Int? = nil) {
        guard let url = URL(string: cursorFileURI(absolutePath: absolutePath, line: line)) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Resolve MCP / registry aliases to canonical executor tool names.
    static func canonicalToolName(for raw: String) -> NEXUSAgentToolName? {
        if let direct = NEXUSAgentToolName(rawValue: raw) {
            return direct.canonical
        }
        switch raw {
        case "build_gate":
            return .runBuildGate
        case "playtest", "studio_run_playtest":
            return .launchMode
        case "studio_open_file":
            return .openIDEFile
        default:
            return nil
        }
    }

    static func isWhitelistedAgentCommandTarget(_ raw: String) -> Bool {
        guard let routes = loadedRegistry()?["tools"] as? [String: Any],
              let agent = routes["agent_command"] as? [String: Any],
              let list = agent["routes_to"] as? [String]
        else {
            return defaultAgentCommandRoutes.contains(raw)
        }
        return list.contains(raw)
    }

    private static let defaultAgentCommandRoutes: Set<String> = [
        "list_modes",
        "playtest",
        "build_gate",
        "run_build_gate",
        "launch_mode",
        "read_file",
        "creative_command",
        "scan_to_generate",
        "generate_game",
        "open_ide_file",
        "studio_open_file",
        "studio_run_playtest",
        "list_artifacts",
        "nexus_scan_playtest",
    ]

    static func loadedRegistry() -> [String: Any]? {
        let url = URL(fileURLWithPath: resolvedRepoRootPath(), isDirectory: true)
            .appendingPathComponent(registryRelativePath)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }
}

#if os(macOS)
import AppKit
#endif
