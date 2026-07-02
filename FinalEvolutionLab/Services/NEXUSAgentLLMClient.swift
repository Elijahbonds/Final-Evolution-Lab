import Foundation

/// Local stub + optional Gemini REST (Firebase AI Logic–compatible) for structured tool calls.
@MainActor
final class NEXUSAgentLLMClient {
    enum ClientError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpStatus(Int, String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Set NEXUS_AI_STUDIO_API_KEY (or NEXUS_AGENT_GEMINI_KEY) in the Xcode scheme or Keychain to enable Gemini."
            case .invalidResponse:
                return "LLM returned an unparseable response."
            case .httpStatus(let code, let body):
                return "Gemini HTTP \(code): \(body)"
            }
        }
    }

    struct PlannerOutput {
        let assistantText: String
        let toolCalls: [NEXUSAgentToolCall]
    }

    func plan(
        backend: NEXUSAgentLLMBackend,
        history: [NEXUSAgentMessage],
        userText: String
    ) async throws -> PlannerOutput {
        switch backend {
        case .localStub:
            return localStubPlan(userText: userText)
        case .gemini:
            return try await geminiPlan(history: history, userText: userText)
        }
    }

    // MARK: - Local stub

    private func localStubPlan(userText: String) -> PlannerOutput {
        let lower = userText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let embedded = parseEmbeddedToolCalls(from: userText), !embedded.isEmpty {
            return PlannerOutput(
                assistantText: "Executing \(embedded.count) structured tool call(s).",
                toolCalls: embedded
            )
        }

        if lower.hasPrefix("/list") || lower.contains("list mode") || lower.contains("what modes") {
            return PlannerOutput(
                assistantText: "Listing registered NEXUS arena modes with sprint priority.",
                toolCalls: [NEXUSAgentToolCall(name: .listModes, arguments: [:])]
            )
        }

        if lower.contains("playtest") || lower.contains("launch") || lower.contains("open mode") || lower.contains("play ") {
            if let modeId = inferModeId(from: lower) {
                return PlannerOutput(
                    assistantText: "Playtest arena mode `\(modeId)`.",
                    toolCalls: [NEXUSAgentToolCall(name: .playtest, arguments: ["mode_id": modeId])]
                )
            }
        }

        if lower.contains("build gate") || lower.contains("nexus_build_gate") || lower.hasPrefix("/gate") {
            let validateOnly = lower.contains("validate")
            return PlannerOutput(
                assistantText: validateOnly
                    ? "Running validate-only production mode gate (whitelisted script)."
                    : "Running full NEXUS build gate (headless + renderer ctest).",
                toolCalls: [
                    NEXUSAgentToolCall(
                        name: .buildGate,
                        arguments: ["target": validateOnly ? "validate_only" : "full_gate"]
                    ),
                ]
            )
        }

        if lower.hasPrefix("/read ") || lower.hasPrefix("read ") {
            let path = userText
                .replacingOccurrences(of: "/read ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "read ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return PlannerOutput(
                assistantText: "Reading `\(path)` via agent_command → read_file.",
                toolCalls: [
                    NEXUSAgentToolCall(
                        name: .agentCommand,
                        arguments: ["tool": "read_file", "arguments": ["path": path]]
                    ),
                ]
            )
        }

        if lower.contains("raise terrain") || lower.contains("creative") {
            return PlannerOutput(
                assistantText: "Applying fel.creative.raise_terrain via C++ voxel parser.",
                toolCalls: [
                    NEXUSAgentToolCall(
                        name: .creativeCommand,
                        arguments: [
                            "command": "fel.creative.raise_terrain",
                            "params": [
                                "position": [0, 0, 0],
                                "radius": 1,
                                "height": 2,
                                "material": 9,
                            ],
                        ]
                    ),
                ]
            )
        }

        if lower.hasPrefix("/open ") || lower.contains("open file") || lower.contains("go to ") {
            let path = extractPathHint(from: userText) ?? "NEXUS_ONLY_PIVOT.md"
            return PlannerOutput(
                assistantText: "Surfacing `\(path)` for IDE navigation.",
                toolCalls: [NEXUSAgentToolCall(name: .openIDEFile, arguments: ["path": path])]
            )
        }

        return PlannerOutput(
            assistantText: """
            NEXUS Agent (local stub). MCP surface tools match Cursor:
            • "list modes" — list_modes
            • "playtest basketball_dunk" — playtest
            • "run build gate" — build_gate (macOS host)
            • "read NEXUS_ONLY_PIVOT.md" — agent_command → read_file
            • "open FinalEvolutionLab/Config.swift" — open_ide_file / Cursor URI

            Set `NEXUS_AGENT_GEMINI_KEY` for Gemini tool planning.
            """,
            toolCalls: []
        )
    }

    private func inferModeId(from lower: String) -> String? {
        for id in GameModeRegistry.arenaRegistryModeIds {
            if lower.contains(id.rawValue.replacingOccurrences(of: "_", with: " "))
                || lower.contains(id.rawValue) {
                return id.rawValue
            }
        }
        if lower.contains("irl") || lower.contains("record") || lower.contains("camera") {
            return GameModeId.basketballDunkContestIRL.rawValue
        }
        if lower.contains("dunk") { return GameModeId.basketballDunkContest3D.rawValue }
        if lower.contains("karate") && lower.contains("endless") { return GameModeId.karateEndless.rawValue }
        if lower.contains("karate") { return GameModeId.karate.rawValue }
        return nil
    }

    private func extractPathHint(from text: String) -> String? {
        let markers = ["/open ", "open file ", "go to ", "read "]
        for marker in markers {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                let tail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !tail.isEmpty { return tail.components(separatedBy: " ").first }
            }
        }
        return nil
    }

    private func parseEmbeddedToolCalls(from text: String) -> [NEXUSAgentToolCall]? {
        guard text.contains("tool_call") || text.contains("\"name\"") else { return nil }

        let pattern = #"\{[\s\S]*?"name"\s*:\s*"([a-z_]+)"[\s\S]*?\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var calls: [NEXUSAgentToolCall] = []

        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2,
                  let jsonRange = Range(match.range, in: text),
                  let nameRange = Range(match.range(at: 1), in: text)
            else { return }

            let jsonFragment = String(text[jsonRange])
            guard let data = jsonFragment.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let nameRaw = object["name"] as? String ?? Optional(String(text[nameRange])),
                  let tool = NEXUSAgentToolName(rawValue: nameRaw)
                      ?? NEXUSCursorBridge.canonicalToolName(for: nameRaw)
            else { return }

            let args = object["arguments"] as? [String: Any] ?? [:]
            calls.append(NEXUSAgentToolCall(name: tool, arguments: args))
        }

        return calls.isEmpty ? nil : calls
    }

    // MARK: - Gemini REST

    private func geminiPlan(history: [NEXUSAgentMessage], userText: String) async throws -> PlannerOutput {
        guard let apiKey = resolvedGeminiKey() else {
            throw ClientError.missingAPIKey
        }

        var contents: [[String: Any]] = []
        for message in history.suffix(12) where message.role != .tool {
            let role = message.role == .assistant ? "model" : "user"
            contents.append(["role": role, "parts": [["text": message.text]]])
        }
        contents.append(["role": "user", "parts": [["text": userText]]])

        let tools: [[String: Any]] = [
            [
                "functionDeclarations": NEXUSAgentService.toolDefinitions.map(\.geminiDeclaration),
            ],
        ]

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": NEXUSAgentService.systemPrompt]]],
            "contents": contents,
            "tools": tools,
            "toolConfig": ["functionCallingConfig": ["mode": "AUTO"]],
        ]

        let model = NexusAIStudioBootstrap.resolvedModel
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw ClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.httpStatus(http.statusCode, bodyText)
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else {
            throw ClientError.invalidResponse
        }

        var assistantText = ""
        var toolCalls: [NEXUSAgentToolCall] = []

        for part in parts {
            if let text = part["text"] as? String {
                assistantText += text
            }
            if let call = part["functionCall"] as? [String: Any],
               let name = call["name"] as? String,
               let tool = NEXUSAgentToolName(rawValue: name)
                   ?? NEXUSCursorBridge.canonicalToolName(for: name) {
                let args = call["args"] as? [String: Any] ?? [:]
                toolCalls.append(NEXUSAgentToolCall(name: tool, arguments: args))
            }
        }

        if assistantText.isEmpty && !toolCalls.isEmpty {
            assistantText = "Planned \(toolCalls.count) tool call(s)."
        }
        if assistantText.isEmpty {
            assistantText = "No actionable response from Gemini."
        }

        return PlannerOutput(assistantText: assistantText, toolCalls: toolCalls)
    }

    private func resolvedGeminiKey() -> String? {
        NexusAIStudioBootstrap.apiKey()
    }
}
