import Foundation

private struct NEXUSAgentPathError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Sandboxed tool executor for the NEXUS agent — Cursor-like control with whitelisted actions only.
@MainActor
@Observable
final class NEXUSAgentService {
    static let shared = NEXUSAgentService()

    private(set) var actionLog: [String] = []
    private var creativeSession: NexusGameplayHandle?

    private init() {}

    // MARK: - System prompt

    static let systemPrompt = """
    You are the NEXUS Agent for Final Evolution Lab — an on-device assistant that navigates and controls the NEXUS shipping environment.

    ## Ship rules (authoritative)
    - Production retail ship is **NEXUS only**: C++20 engine (`engine/`, `app/gameplay/`, `runtime/`) + Swift iOS app (`FinalEvolutionLab/`).
    - Unreal Engine 5.7 and Unity 6 are **archived legacy reference only** — never extend them for retail ship.
    - Engine vs app: gameplay authority lives in C++ (`nexus_gameplay`, fel.* protocol). Swift is shell, HUD, auth, receipts, and navigation.
    - Label preview/beta honestly where `NEXUS_DELIVERY_MATRIX.md` gaps remain (Metal stub, SceneKit dunk preview, unsigned archive, etc.).

    ## Tool policy
    - You may ONLY act through registered tools. No arbitrary shell, network fetches, or file writes.
    - Cursor MCP and this chat share the same registry (`Config/nexus_cursor_tool_registry.json`).
    - Primary surface tools: `list_modes`, `playtest`, `build_gate`, `agent_command`.
    - `build_gate` / `run_build_gate` whitelists `scripts/nexus_build_gate.sh` and validate-only scripts.
    - `playtest` / `launch_mode` navigates Arena gameplay for a registered `GameModeId`.
    - `agent_command` routes whitelisted sub-tools (`read_file`, `creative_command`, `scan_to_generate`, …).
    - `scan_to_generate` posts a scan envelope via `ScanToGenerationBridge` (simulated plan when bridge unlinked).
    - `read_file` is read-only under the NEXUS repo root with traversal blocked.
    - `open_ide_file` surfaces repo paths + `cursor://file/…` URIs (no silent writes).

    ## Response style
    - Be concise and honest about simulator vs device limits.
    - When a tool fails, explain the sandbox boundary and suggest the manual command if safe.
    - Prefer structured tool calls over prose when the user asks to run, read, launch, or build something.
    """

    // MARK: - Tool registry

    static let toolDefinitions: [NEXUSAgentToolDefinition] = [
        NEXUSAgentToolDefinition(
            name: .listModes,
            description: "List NEXUS arena game modes with sprint priority, release state, and playability.",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "include_preview": [
                        "type": "boolean",
                        "description": "Include preview-tier modes (default follows Config.showPreviewGameModes).",
                    ],
                ],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .playtest,
            description: "Launch an arena game mode for playtest (same as launch_mode; MCP surface name).",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "mode_id": [
                        "type": "string",
                        "description": "GameModeId raw value, e.g. basketball_dunk or karate_endless",
                    ],
                    "readiness": [
                        "type": "number",
                        "description": "Session readiness 0–100 (default 75).",
                    ],
                ],
                "required": ["mode_id"],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .buildGate,
            description: "Run a whitelisted NEXUS build gate script on macOS host only (MCP surface name).",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "target": [
                        "type": "string",
                        "enum": ["full_gate", "validate_only"],
                        "description": "full_gate → nexus_build_gate.sh; validate_only → nexus_validate_production_modes.sh",
                    ],
                ],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .agentCommand,
            description: "Route a whitelisted sub-tool through the shared NEXUS sandbox registry.",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "tool": [
                        "type": "string",
                        "description": "Whitelisted tool name, e.g. read_file or creative_command",
                    ],
                    "arguments": [
                        "type": "object",
                        "description": "Arguments for the sub-tool",
                    ],
                ],
                "required": ["tool"],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .readFile,
            description: "Read a text file under the NEXUS repo root (read-only, max 256 KB).",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Repo-relative path, e.g. NEXUS_ONLY_PIVOT.md or FinalEvolutionLab/Config.swift",
                    ],
                ],
                "required": ["path"],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .runBuildGate,
            description: "Run a whitelisted NEXUS build gate script on macOS host only.",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "target": [
                        "type": "string",
                        "enum": ["full_gate", "validate_only"],
                        "description": "full_gate → nexus_build_gate.sh; validate_only → nexus_validate_production_modes.sh",
                    ],
                ],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .launchMode,
            description: "Navigate the iOS app to launch an arena game mode by id.",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "mode_id": [
                        "type": "string",
                        "description": "GameModeId raw value, e.g. basketball_dunk or karate_endless",
                    ],
                    "readiness": [
                        "type": "number",
                        "description": "Session readiness 0–100 (default 75).",
                    ],
                ],
                "required": ["mode_id"],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .creativeCommand,
            description: "Apply a fel.creative.* voxel terrain command via the C++ gameplay bridge.",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "command": [
                        "type": "string",
                        "enum": [
                            "fel.creative.raise_terrain",
                            "fel.creative.lower_terrain",
                            "fel.creative.flatten_terrain",
                            "fel.creative.paint_terrain",
                        ],
                    ],
                    "params": [
                        "type": "object",
                        "description": "Command params: position [x,y,z], radius, height, material as applicable.",
                    ],
                ],
                "required": ["command", "params"],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .scanToGenerate,
            description: "Submit scan envelope to fel.generate.arena_from_scan (ScanToGenerationBridge or simulated command plan).",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "use_simulated": [
                        "type": "boolean",
                        "description": "Use ScanCaptureService.simulatedEnvelope() when envelope omitted (default true).",
                    ],
                    "envelope": [
                        "type": "object",
                        "description": "Optional ScanEnvelope JSON (schema_version, scan_id, joints, motion, …).",
                    ],
                ],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .generateGame,
            description: "Generate playable game spec from natural language via fel.generate.game / fel.generate.refine_game.",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "text": [
                        "type": "string",
                        "description": "Natural language prompt or refinement follow-up",
                    ],
                    "refine": [
                        "type": "boolean",
                        "description": "When true, routes to fel.generate.refine_game (default false).",
                    ],
                    "include_arena": [
                        "type": "boolean",
                        "description": "Also run arena voxel steps when prompt mentions venue/court (default false).",
                    ],
                    "start_session": [
                        "type": "boolean",
                        "description": "Bootstrap fel.arena.start_session after spec (default true).",
                    ],
                ],
                "required": ["text"],
            ]
        ),
        NEXUSAgentToolDefinition(
            name: .openIDEFile,
            description: "Surface a repo-relative source path for IDE navigation (notification + pasteboard).",
            parametersSchema: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Repo-relative file path"],
                    "line": ["type": "integer", "description": "Optional 1-based line hint"],
                ],
                "required": ["path"],
            ]
        ),
    ]

    // MARK: - Dispatch

    func execute(toolCall: NEXUSAgentToolCall) async -> NEXUSAgentToolResult {
        let result = await executeCanonical(toolCall: toolCall)
        appendActionLog(tool: toolCall.name, arguments: toolCall.arguments, result: result)
        return result
    }

    private func executeCanonical(toolCall: NEXUSAgentToolCall) async -> NEXUSAgentToolResult {
        switch toolCall.name.canonical {
        case .listModes:
            return listModes(arguments: toolCall.arguments)
        case .readFile:
            return readFile(arguments: toolCall.arguments)
        case .runBuildGate:
            return await runBuildGate(arguments: toolCall.arguments)
        case .launchMode:
            return launchMode(arguments: toolCall.arguments)
        case .creativeCommand:
            return creativeCommand(arguments: toolCall.arguments)
        case .scanToGenerate:
            return scanToGenerate(arguments: toolCall.arguments)
        case .generateGame:
            return generateGame(arguments: toolCall.arguments)
        case .openIDEFile:
            return openIDEFile(arguments: toolCall.arguments)
        case .agentCommand:
            return await agentCommand(arguments: toolCall.arguments)
        case .buildGate, .playtest:
            return failure(toolCall.name, "Alias should have been canonicalized")
        }
    }

    private func agentCommand(arguments: [String: Any]) async -> NEXUSAgentToolResult {
        guard let toolRaw = arguments["tool"] as? String, !toolRaw.isEmpty else {
            return failure(.agentCommand, "Missing tool argument")
        }

        guard NEXUSCursorBridge.isWhitelistedAgentCommandTarget(toolRaw) else {
            return failure(.agentCommand, "Tool '\(toolRaw)' is not whitelisted for agent_command")
        }

        guard let canonical = NEXUSCursorBridge.canonicalToolName(for: toolRaw) else {
            return failure(.agentCommand, "Unknown tool '\(toolRaw)'")
        }

        let nested = arguments["arguments"] as? [String: Any] ?? [:]
        let nestedResult = await executeCanonical(toolCall: NEXUSAgentToolCall(name: canonical, arguments: nested))

        return NEXUSAgentToolResult(
            tool: .agentCommand,
            success: nestedResult.success,
            summary: "[agent_command → \(toolRaw)] \(nestedResult.summary)",
            payload: [
                "routed_tool": toolRaw,
                "nested": nestedResult.payload,
            ]
        )
    }

    // MARK: - Tool implementations

    private func listModes(arguments: [String: Any]) -> NEXUSAgentToolResult {
        let includePreview = (arguments["include_preview"] as? Bool) ?? Config.showPreviewGameModes
        let modes = includePreview ? GameModeRegistry.all : GameModeRegistry.shippingModes

        let rows: [[String: Any]] = modes.map { mode in
            [
                "mode_id": mode.id.rawValue,
                "name": mode.name,
                "subtitle": mode.subtitle,
                "release_state": mode.releaseState.rawValue,
                "sprint_priority": "P\(mode.nexusSprintPriority.rawValue)",
                "nexus_playable": mode.isNexusSprintPlayable,
                "environment": mode.environmentName,
            ]
        }

        return NEXUSAgentToolResult(
            tool: .listModes,
            success: true,
            summary: "Listed \(rows.count) mode(s)",
            payload: [
                "count": rows.count,
                "include_preview": includePreview,
                "modes": rows,
                "sprint_p0_p1": GameModeRegistry.nexusSprintModeIds.map(\.rawValue),
            ]
        )
    }

    private func readFile(arguments: [String: Any]) -> NEXUSAgentToolResult {
        guard let relative = arguments["path"] as? String, !relative.isEmpty else {
            return failure(.readFile, "Missing path argument")
        }

        switch resolveRepoPath(relative) {
        case .failure(let error):
            return failure(.readFile, error.message)
        case .success(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                return failure(.readFile, "File not found: \(relative)")
            }

            let ext = url.pathExtension.lowercased()
            let blockedExtensions: Set<String> = [
                "png", "jpg", "jpeg", "gif", "webp", "heic", "mp4", "mov", "a", "o", "dylib", "framework",
            ]
            if blockedExtensions.contains(ext) {
                return failure(.readFile, "Binary extension blocked: .\(ext)")
            }

            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = (attrs[FileAttributeKey.size] as? NSNumber)?.intValue ?? 0
                let maxBytes = 256 * 1024
                if size > maxBytes {
                    return failure(.readFile, "File exceeds \(maxBytes) byte read cap (\(size) bytes)")
                }

                let text = try String(contentsOf: url, encoding: .utf8)
                return NEXUSAgentToolResult(
                    tool: .readFile,
                    success: true,
                    summary: "Read \(relative) (\(text.count) chars)",
                    payload: [
                        "path": relative,
                        "bytes": size,
                        "content": text,
                    ]
                )
            } catch {
                return failure(.readFile, "Read failed: \(error.localizedDescription)")
            }
        }
    }

    private func runBuildGate(arguments: [String: Any]) async -> NEXUSAgentToolResult {
        let target = (arguments["target"] as? String) ?? "full_gate"
        let scriptName: String
        switch target {
        case "validate_only":
            scriptName = "scripts/nexus_validate_production_modes.sh"
        case "full_gate":
            scriptName = "scripts/nexus_build_gate.sh"
        default:
            return failure(.runBuildGate, "Unknown target '\(target)'. Use full_gate or validate_only.")
        }

        switch resolveRepoPath(scriptName) {
        case .failure(let error):
            return failure(.runBuildGate, error.message)
        case .success(let scriptURL):
            guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
                return failure(.runBuildGate, "Script not executable: \(scriptName)")
            }

            #if os(macOS)
            let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
            do {
                let output = try await runWhitelistedScript(at: scriptURL, workingDirectory: repoRoot)
                return NEXUSAgentToolResult(
                    tool: .runBuildGate,
                    success: output.exitCode == 0,
                    summary: output.exitCode == 0 ? "\(scriptName) PASS" : "\(scriptName) FAILED (exit \(output.exitCode))",
                    payload: [
                        "target": target,
                        "script": scriptName,
                        "exit_code": output.exitCode,
                        "stdout": output.stdout,
                        "stderr": output.stderr,
                    ]
                )
            } catch {
                return failure(.runBuildGate, "Process error: \(error.localizedDescription)")
            }
            #else
            return NEXUSAgentToolResult(
                tool: .runBuildGate,
                success: false,
                summary: "run_build_gate requires macOS host",
                payload: [
                    "blocked_reason": "iOS sandbox cannot spawn whitelisted shell scripts",
                    "manual_command": "cd \(Self.resolvedRepoRootPath()) && ./\(scriptName)",
                    "target": target,
                    "script": scriptName,
                ]
            )
            #endif
        }
    }

    private func launchMode(arguments: [String: Any]) -> NEXUSAgentToolResult {
        guard let modeId = arguments["mode_id"] as? String, !modeId.isEmpty else {
            return failure(.launchMode, "Missing mode_id")
        }

        guard let mode = GameModeRegistry.playableMode(forRegistryId: modeId) else {
            let valid = GameModeRegistry.arenaRegistryModeIds.map(\.rawValue).joined(separator: ", ")
            return failure(.launchMode, "Unknown mode_id '\(modeId)'. Valid: \(valid)")
        }

        if mode.releaseState == .preview && !Config.showPreviewGameModes {
            return failure(.launchMode, "\(modeId) is preview-only; enable preview modes or ship flag.")
        }

        let readiness = min(100, max(0, (arguments["readiness"] as? Double)
            ?? (arguments["readiness"] as? Int).map(Double.init)
            ?? 75))

        NotificationCenter.default.post(
            name: .nexusAgentLaunchMode,
            object: nil,
            userInfo: [
                "mode_id": modeId,
                "resolved_mode_id": mode.id.rawValue,
                "mode_name": mode.name,
                "readiness": readiness,
            ]
        )

        return NEXUSAgentToolResult(
            tool: .launchMode,
            success: true,
            summary: "Playtest: launching \(mode.name) (\(mode.id.rawValue))",
            payload: [
                "mode_id": mode.id.rawValue,
                "registry_mode_id": modeId,
                "mode_name": mode.name,
                "readiness": readiness,
                "preview_label": mode.isNexusSprintPlayable ? "sprint_playable" : "preview_or_p2",
                "cursor_repo_uri": NEXUSCursorBridge.cursorRepoURI(),
            ]
        )
    }

    private func creativeCommand(arguments: [String: Any]) -> NEXUSAgentToolResult {
        guard let command = arguments["command"] as? String else {
            return failure(.creativeCommand, "Missing command")
        }

        let allowed: Set<String> = [
            "fel.creative.raise_terrain",
            "fel.creative.lower_terrain",
            "fel.creative.flatten_terrain",
            "fel.creative.paint_terrain",
        ]
        guard allowed.contains(command) else {
            return failure(.creativeCommand, "Command not whitelisted: \(command)")
        }

        guard NexusGameplayBridge.isLinked else {
            return failure(.creativeCommand, "NEXUS gameplay bridge not linked in this build")
        }

        if creativeSession == nil {
            creativeSession = NexusGameplayBridge.createSession()
        }
        guard let session = creativeSession else {
            return failure(.creativeCommand, "Failed to create creative session")
        }

        let params = arguments["params"] as? [String: Any] ?? [:]
        let payload: [String: Any] = [
            "command": command,
            "id": "nexus_agent_creative",
            "params": params,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let raw = NexusGameplayBridge.handleCommand(session, commandJson: json),
              let response = parseBridgeResponse(raw)
        else {
            return failure(.creativeCommand, "Bridge returned no response")
        }

        let ok = response["status"] as? String == "ok"
        return NEXUSAgentToolResult(
            tool: .creativeCommand,
            success: ok,
            summary: ok ? "Applied \(command)" : (response["error"] as? String ?? "Creative command failed"),
            payload: response
        )
    }

    private func generateGame(arguments: [String: Any]) -> NEXUSAgentToolResult {
        guard let text = arguments["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return failure(.generateGame, "Missing text prompt")
        }

        guard NexusGameplayBridge.isLinked else {
            return failure(.generateGame, "NEXUS gameplay bridge not linked in this build")
        }

        if creativeSession == nil {
            creativeSession = NexusGameplayBridge.createSession()
        }
        guard let session = creativeSession else {
            return failure(.generateGame, "Failed to create generator session")
        }

        let refine = (arguments["refine"] as? Bool) ?? false
        let includeArena = (arguments["include_arena"] as? Bool) ?? false
        let startSession = (arguments["start_session"] as? Bool) ?? true
        let command = refine ? "fel.generate.refine_game" : "fel.generate.game"

        var params: [String: Any] = [
            "text": text,
            "include_arena": includeArena,
            "start_session": startSession,
            "user_id": "nexus_agent",
        ]

        let payload: [String: Any] = [
            "command": command,
            "id": "nexus_agent_generate_game",
            "params": params,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let raw = NexusGameplayBridge.handleCommand(session, commandJson: json),
              let response = parseBridgeResponse(raw)
        else {
            return failure(.generateGame, "Bridge returned no response")
        }

        let ok = response["status"] as? String == "ok"
        let responsePayload = response["payload"] as? [String: Any] ?? [:]
        let gameSpec = responsePayload["game_spec"] as? [String: Any] ?? responsePayload
        let modeId = gameSpec["mode_id"] as? String ?? "unknown"

        return NEXUSAgentToolResult(
            tool: .generateGame,
            success: ok,
            summary: ok
                ? "Generated game spec (\(modeId)) via \(command)"
                : (response["error"] as? String ?? "Game generation failed"),
            payload: response
        )
    }

    private func scanToGenerate(arguments: [String: Any]) -> NEXUSAgentToolResult {
        let envelope: ScanEnvelope
        if let envelopeObject = arguments["envelope"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: envelopeObject),
           let decoded = try? JSONDecoder().decode(ScanEnvelope.self, from: data) {
            envelope = decoded
        } else if (arguments["use_simulated"] as? Bool) ?? true {
            envelope = ScanCaptureService.simulatedEnvelope()
        } else {
            return failure(.scanToGenerate, "Provide envelope object or set use_simulated:true")
        }

        let envelopeJSON = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(envelope))) as? [String: Any] ?? [:]

        if NexusGameplayBridge.isLinked {
            guard let result = ScanToGenerationBridge.submit(envelope: envelope) else {
                return failure(.scanToGenerate, "ScanToGenerationBridge returned no result — see command log")
            }

            return NEXUSAgentToolResult(
                tool: .scanToGenerate,
                success: true,
                summary: "Generated arena from scan (\(result.recommendedModeId), tier \(result.difficultyTier))",
                payload: [
                    "bridge_linked": true,
                    "simulated": envelope.source == .simulated,
                    "scan_id": envelope.scanId,
                    "preview_label": result.previewLabel,
                    "recommended_mode_id": result.recommendedModeId,
                    "difficulty_tier": result.difficultyTier,
                    "arena_scale": result.arenaScale,
                    "voxel_material": result.voxelMaterial,
                    "paint_radius": result.paintRadius,
                    "commands_applied": result.commandsApplied,
                    "envelope": envelopeJSON,
                ]
            )
        }

        let plan = ScanEnvelopeCommandMapper.commandPlan(for: envelope)
        return NEXUSAgentToolResult(
            tool: .scanToGenerate,
            success: true,
            summary: "Simulated scan-to-generation plan (NEXUS bridge not linked)",
            payload: [
                "bridge_linked": false,
                "simulated": true,
                "scan_id": envelope.scanId,
                "envelope": envelopeJSON,
                "command_plan": plan,
                "doc": "docs/NEXUS_SCAN_TO_GENERATION.md",
                "ctest_command": "cmake --build build-headless --target nexus_scan_envelope_test && ./build-headless/nexus_scan_envelope_test",
            ]
        )
    }

    private func openIDEFile(arguments: [String: Any]) -> NEXUSAgentToolResult {
        guard let relative = arguments["path"] as? String, !relative.isEmpty else {
            return failure(.openIDEFile, "Missing path")
        }

        switch resolveRepoPath(relative) {
        case .failure(let error):
            return failure(.openIDEFile, error.message)
        case .success(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                return failure(.openIDEFile, "File not found: \(relative)")
            }

            let line = (arguments["line"] as? Int) ?? (arguments["line"] as? NSNumber)?.intValue
            NotificationCenter.default.post(
                name: .nexusAgentOpenIDEFile,
                object: nil,
                userInfo: [
                    "path": url.path,
                    "relative_path": relative,
                    "line": line as Any,
                ]
            )

            #if os(iOS)
            UIPasteboard.general.string = line.map { "\(url.path):\($0)" } ?? url.path
            #endif

            return NEXUSAgentToolResult(
                tool: .openIDEFile,
                success: true,
                summary: "Surfaced \(relative)\(line.map { ":\($0)" } ?? "")",
                payload: [
                    "absolute_path": url.path,
                    "relative_path": relative,
                    "line": line as Any,
                    "cursor_uri": NEXUSCursorBridge.cursorFileURI(absolutePath: url.path, line: line),
                    "cursor_repo_uri": NEXUSCursorBridge.cursorRepoURI(),
                ]
            )
        }
    }

    // MARK: - Sandbox helpers

    static func resolvedRepoRootPath() -> String {
        NEXUSCursorBridge.resolvedRepoRootPath()
    }

    private func resolveRepoPath(_ relative: String) -> Result<URL, NEXUSAgentPathError> {
        let trimmed = relative.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            return .failure(NEXUSAgentPathError(message: "Absolute paths blocked — use repo-relative paths"))
        }
        if trimmed.contains("..") {
            return .failure(NEXUSAgentPathError(message: "Path traversal blocked"))
        }

        let root = URL(fileURLWithPath: Self.resolvedRepoRootPath(), isDirectory: true)
        let candidate = root.appendingPathComponent(trimmed).standardizedFileURL

        guard candidate.path.hasPrefix(root.standardizedFileURL.path) else {
            return .failure(NEXUSAgentPathError(message: "Resolved path escapes repo root"))
        }
        return .success(candidate)
    }

    #if os(macOS)
    private struct ScriptOutput {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private func runWhitelistedScript(at scriptURL: URL, workingDirectory: URL) async throws -> ScriptOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]
            process.currentDirectoryURL = workingDirectory

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(
                    returning: ScriptOutput(
                        exitCode: proc.terminationStatus,
                        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                        stderr: String(data: stderrData, encoding: .utf8) ?? ""
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #endif

    private func parseBridgeResponse(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return root
    }

    private func failure(_ tool: NEXUSAgentToolName, _ message: String) -> NEXUSAgentToolResult {
        NEXUSAgentToolResult(tool: tool, success: false, summary: message, payload: ["error": message])
    }

    // MARK: - Action log

    private func appendActionLog(
        tool: NEXUSAgentToolName,
        arguments: [String: Any],
        result: NEXUSAgentToolResult
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let argsSummary: String = {
            guard let data = try? JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys]),
                  let text = String(data: data, encoding: .utf8)
            else { return "{}" }
            return text.count > 120 ? String(text.prefix(117)) + "..." : text
        }()

        let line = "| \(timestamp) | `\(tool.rawValue)` | \(result.success ? "PASS" : "FAIL") | \(argsSummary) | \(result.summary) |"
        actionLog.append(line)

        appendToRepoActionLog(line)
    }

    private func appendToRepoActionLog(_ line: String) {
        let logPath = URL(fileURLWithPath: Self.resolvedRepoRootPath())
            .appendingPathComponent("docs/NEXUS_AGENT_TOOLS.md")

        guard FileManager.default.isWritableFile(atPath: logPath.deletingLastPathComponent().path) else {
            return
        }

        do {
            var existing = (try? String(contentsOf: logPath, encoding: .utf8)) ?? ""
            if existing.isEmpty {
                existing = Self.defaultActionLogHeader
            }
            if !existing.hasSuffix("\n") {
                existing += "\n"
            }
            existing += line + "\n"
            try existing.write(to: logPath, atomically: true, encoding: .utf8)
        } catch {
            // Best-effort — in-app log still retained.
        }
    }

    static let defaultActionLogHeader = """
    # NEXUS Agent Tools

    Sandboxed tool registry for `NEXUSAgentService` / `NexusAgentChatView`.

    ## Action log (auto-appended when repo is writable)

    | Timestamp | Tool | Result | Arguments | Summary |
    | --- | --- | --- | --- | --- |

    """
}

#if os(iOS)
import UIKit
#endif
