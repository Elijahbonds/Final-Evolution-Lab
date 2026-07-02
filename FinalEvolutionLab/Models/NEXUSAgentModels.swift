import Foundation

// MARK: - Chat

nonisolated enum NEXUSAgentRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

nonisolated struct NEXUSAgentMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: NEXUSAgentRole
    let text: String
    let toolName: String?
    let toolResultJSON: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: NEXUSAgentRole,
        text: String,
        toolName: String? = nil,
        toolResultJSON: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.toolName = toolName
        self.toolResultJSON = toolResultJSON
        self.createdAt = createdAt
    }
}

// MARK: - Tools

nonisolated enum NEXUSAgentToolName: String, CaseIterable, Codable, Sendable {
    case listModes = "list_modes"
    case readFile = "read_file"
    case runBuildGate = "run_build_gate"
    case buildGate = "build_gate"
    case launchMode = "launch_mode"
    case playtest = "playtest"
    case creativeCommand = "creative_command"
    case scanToGenerate = "scan_to_generate"
    case generateGame = "generate_game"
    case openIDEFile = "open_ide_file"
    case agentCommand = "agent_command"

    /// Canonical executor used by `NEXUSAgentService` (MCP aliases collapse here).
    var canonical: NEXUSAgentToolName {
        switch self {
        case .buildGate: return .runBuildGate
        case .playtest: return .launchMode
        default: return self
        }
    }

    /// MCP-exposed tool names (Cursor + in-app chat primary surface).
    static let mcpSurfaceTools: [NEXUSAgentToolName] = [
        .listModes, .playtest, .buildGate, .agentCommand,
    ]

    /// Quick-run chips shown in Agent chat (whitelisted only).
    static let quickRunChips: [(tool: NEXUSAgentToolName, label: String, arguments: [String: Any])] = [
        (.listModes, "List Modes", [:]),
        (.playtest, "Dunk Playtest", ["mode_id": GameModeId.basketballDunkContest3D.rawValue]),
        (.readFile, "Read Matrix", ["path": "NEXUS_DELIVERY_MATRIX.md"]),
        (.openIDEFile, "Open Config", ["path": "FinalEvolutionLab/Config.swift"]),
        (.scanToGenerate, "Scan→Gen", ["use_simulated": true]),
        (.generateGame, "Generate Game", ["text": "Hard basketball dunk contest on Venice court"]),
    ]

    var displayTitle: String {
        switch self {
        case .listModes: return "List Modes"
        case .readFile: return "Read File"
        case .runBuildGate, .buildGate: return "Build Gate"
        case .launchMode, .playtest: return "Playtest"
        case .creativeCommand: return "Creative Command"
        case .scanToGenerate: return "Scan to Generate"
        case .generateGame: return "Generate Game"
        case .openIDEFile: return "Open IDE File"
        case .agentCommand: return "Agent Command"
        }
    }
}

nonisolated struct NEXUSAgentToolDefinition: Sendable {
    let name: NEXUSAgentToolName
    let description: String
    let parametersSchema: [String: Any]

    var geminiDeclaration: [String: Any] {
        [
            "name": name.rawValue,
            "description": description,
            "parameters": parametersSchema,
        ]
    }
}

nonisolated struct NEXUSAgentToolCall: Equatable, Sendable {
    let name: NEXUSAgentToolName
    let arguments: [String: Any]

    static func == (lhs: NEXUSAgentToolCall, rhs: NEXUSAgentToolCall) -> Bool {
        lhs.name == rhs.name
            && (try? JSONSerialization.data(withJSONObject: lhs.arguments))
            == (try? JSONSerialization.data(withJSONObject: rhs.arguments))
    }
}

nonisolated struct NEXUSAgentToolResult: Sendable {
    let tool: NEXUSAgentToolName
    let success: Bool
    let summary: String
    let payload: [String: Any]

    var jsonString: String {
        let envelope: [String: Any] = [
            "tool": tool.rawValue,
            "success": success,
            "summary": summary,
            "payload": payload,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{\"success\":\(success),\"summary\":\"\(summary)\"}"
        }
        return text
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let nexusAgentLaunchMode = Notification.Name("NEXUSAgentLaunchMode")
    static let nexusAgentOpenIDEFile = Notification.Name("NEXUSAgentOpenIDEFile")
    static let nexusStudioOpen = Notification.Name("NEXUSStudioOpen")
    static let nexusStudioSandboxSaved = Notification.Name("NEXUSStudioSandboxSaved")
}

nonisolated struct NEXUSAgentLaunchModePayload: Sendable {
    let modeId: String
    let modeName: String
}

nonisolated enum NEXUSAgentLLMBackend: String, CaseIterable, Sendable {
    case localStub = "local_stub"
    case gemini = "gemini"

    var label: String {
        switch self {
        case .localStub: return "Local Stub"
        case .gemini: return "Gemini (Firebase AI Logic compatible)"
        }
    }
}
