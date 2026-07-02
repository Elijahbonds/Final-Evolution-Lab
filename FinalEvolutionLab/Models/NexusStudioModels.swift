import Foundation

/// Roots exposed in the NEXUS Studio file tree.
enum NexusStudioRoot: String, CaseIterable, Identifiable, Sendable {
    case engine
    case gameplay = "app/gameplay"
    case swiftApp = "FinalEvolutionLab"
    case assets

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .engine: "engine (C++)"
        case .gameplay: "app/gameplay"
        case .swiftApp: "FinalEvolutionLab (Swift)"
        case .assets: "assets"
        }
    }

    var icon: String {
        switch self {
        case .engine: "cpu"
        case .gameplay: "gamecontroller.fill"
        case .swiftApp: "swift"
        case .assets: "cube.transparent"
        }
    }

    var filterCategory: NexusStudioRootFilter {
        switch self {
        case .engine: .engine
        case .gameplay: .gameplay
        case .swiftApp: .swift
        case .assets: .assets
        }
    }
}

/// Sidebar filter for engine vs Swift vs asset roots.
enum NexusStudioRootFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case engine
    case swift
    case gameplay
    case assets

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .engine: "Engine"
        case .swift: "Swift"
        case .gameplay: "Gameplay"
        case .assets: "Assets"
        }
    }
}

enum NexusStudioPanel: String, CaseIterable, Identifiable, Sendable {
    case editor
    case run
    case aiStudio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .editor: "Browse"
        case .run: "Play"
        case .aiStudio: "Creative AI"
        }
    }

    var icon: String {
        switch self {
        case .editor: "doc.text"
        case .run: "play.fill"
        case .aiStudio: "sparkles"
        }
    }
}

struct NexusStudioRecentFile: Identifiable, Codable, Equatable, Sendable {
    let relativePath: String
    let openedAt: Date

    var id: String { relativePath }

    var fileName: String { (relativePath as NSString).lastPathComponent }
}

enum NexusStudioLanguage: String, Sendable {
    case cpp
    case swift
    case json
    case markdown
    case plain

    static func from(path: String) -> NexusStudioLanguage {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "cpp", "cc", "cxx", "h", "hpp", "mm", "m": return .cpp
        case "swift": return .swift
        case "json": return .json
        case "md", "markdown": return .markdown
        default: return .plain
        }
    }

    var displayLabel: String {
        switch self {
        case .cpp: "C++"
        case .swift: "Swift"
        case .json: "JSON"
        case .markdown: "Markdown"
        case .plain: "Plain"
        }
    }
}

struct NexusStudioFileNode: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let relativePath: String
    let isDirectory: Bool
    let children: [NexusStudioFileNode]

    var language: NexusStudioLanguage {
        NexusStudioLanguage.from(path: relativePath)
    }
}

struct NexusStudioOpenFile: Identifiable, Equatable, Sendable {
    let relativePath: String
    var content: String
    var isDirty: Bool
    var source: NexusStudioFileSource

    var id: String { relativePath }

    var fileName: String { (relativePath as NSString).lastPathComponent }
}

enum NexusStudioFileSource: String, Sendable {
    case repo
    case sandbox
    case bundled
}

enum NexusStudioAccessMode: String, CaseIterable, Sendable {
    case readOnly
    case sandboxEdit

    var label: String {
        switch self {
        case .readOnly: "View only"
        case .sandboxEdit: "Draft edits"
        }
    }
}

/// Launch context consumed once when `NexusStudioIDEView` appears.
struct NexusStudioLaunchContext: Equatable, Sendable {
    var panel: NexusStudioPanel = .editor
    var modeId: GameModeId?
    var readiness: Double = 75
    var sandboxRelativePath: String?
}

/// Parsed entry from `NexusStudio/sandbox/generated_games/*.json` (Game Generator export).
struct NexusGeneratedGameEntry: Identifiable, Equatable, Sendable {
    let relativePath: String
    let specId: String
    let modeId: String
    let displayName: String
    let difficultyTier: String
    let venueToken: String

    var id: String { relativePath }

    var readinessEstimate: Double {
        Self.readiness(for: difficultyTier)
    }

    static func readiness(for difficultyTier: String) -> Double {
        switch difficultyTier.lowercased() {
        case "easy", "casual", "beginner":
            return 55
        case "hard", "elite", "competitive":
            return 88
        case "intense", "extreme", "pro":
            return 95
        default:
            return 75
        }
    }

    static func parse(relativePath: String, json: [String: Any]) -> NexusGeneratedGameEntry? {
        guard let modeId = json["mode_id"] as? String else { return nil }
        let rules = json["rules"] as? [String: Any] ?? [:]
        return NexusGeneratedGameEntry(
            relativePath: relativePath,
            specId: json["spec_id"] as? String ?? (relativePath as NSString).lastPathComponent,
            modeId: modeId,
            displayName: json["display_name"] as? String ?? modeId,
            difficultyTier: rules["difficulty_tier"] as? String ?? "normal",
            venueToken: json["venue_token"] as? String ?? ""
        )
    }
}
