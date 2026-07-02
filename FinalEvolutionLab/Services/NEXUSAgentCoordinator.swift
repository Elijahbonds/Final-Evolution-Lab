import Foundation
import SwiftUI

@MainActor
@Observable
final class NEXUSAgentCoordinator {
    static let shared = NEXUSAgentCoordinator()

    var messages: [NEXUSAgentMessage] = []
    var isProcessing = false
    var backend: NEXUSAgentLLMBackend = .localStub
    var pendingLaunch: NEXUSAgentLaunchModePayload?
    var pendingLaunchReadiness: Double = 75
    var lastOpenFilePath: String?

    private let service = NEXUSAgentService.shared
    private let llm = NEXUSAgentLLMClient()

    private init() {
        messages = [
            NEXUSAgentMessage(
                role: .system,
                text: NEXUSAgentService.systemPrompt
            ),
            NEXUSAgentMessage(
                role: .assistant,
                text: """
                NEXUS Agent online (preview). I control the ship environment through whitelisted tools only — list modes, read repo files, run build gates on macOS, launch arena modes, creative fel.* commands, and surface IDE paths.

                Backend: \(NEXUSAgentLLMBackend.localStub.label). Ask anything about NEXUS ship status or say "list modes" to start.
                """
            ),
        ]
    }

    func send(userText: String) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        messages.append(NEXUSAgentMessage(role: .user, text: trimmed))
        isProcessing = true
        defer { isProcessing = false }

        do {
            let plan = try await llm.plan(backend: backend, history: messages, userText: trimmed)
            messages.append(NEXUSAgentMessage(role: .assistant, text: plan.assistantText))

            for call in plan.toolCalls {
                let result = await service.execute(toolCall: call)
                messages.append(
                    NEXUSAgentMessage(
                        role: .tool,
                        text: result.summary,
                        toolName: call.name.rawValue,
                        toolResultJSON: result.jsonString
                    )
                )

                if (call.name.canonical == .launchMode), result.success,
                   let modeId = result.payload["mode_id"] as? String,
                   let modeName = result.payload["mode_name"] as? String {
                    pendingLaunch = NEXUSAgentLaunchModePayload(modeId: modeId, modeName: modeName)
                    pendingLaunchReadiness = (result.payload["readiness"] as? Double)
                        ?? (result.payload["readiness"] as? NSNumber)?.doubleValue
                        ?? 75
                }

                if call.name == .openIDEFile, result.success,
                   let path = result.payload["absolute_path"] as? String {
                    lastOpenFilePath = path
                }
            }
        } catch {
            messages.append(
                NEXUSAgentMessage(
                    role: .assistant,
                    text: "Planner error: \(error.localizedDescription)"
                )
            )
        }
    }

    func clearChat() {
        messages = [
            NEXUSAgentMessage(role: .system, text: NEXUSAgentService.systemPrompt),
            NEXUSAgentMessage(role: .assistant, text: "Chat cleared. NEXUS Agent ready."),
        ]
    }

    /// Run a whitelisted tool directly from the chip bar (no LLM planner).
    func runQuickTool(_ tool: NEXUSAgentToolName, arguments: [String: Any] = [:]) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        let call = NEXUSAgentToolCall(name: tool, arguments: arguments)
        messages.append(
            NEXUSAgentMessage(
                role: .user,
                text: "Run tool: \(tool.rawValue)"
            )
        )

        let result = await service.execute(toolCall: call)
        messages.append(
            NEXUSAgentMessage(
                role: .tool,
                text: result.summary,
                toolName: tool.rawValue,
                toolResultJSON: result.jsonString
            )
        )

        if tool.canonical == .launchMode, result.success,
           let modeId = result.payload["mode_id"] as? String,
           let modeName = result.payload["mode_name"] as? String {
            pendingLaunch = NEXUSAgentLaunchModePayload(modeId: modeId, modeName: modeName)
            pendingLaunchReadiness = (result.payload["readiness"] as? Double)
                ?? (result.payload["readiness"] as? NSNumber)?.doubleValue
                ?? 75
        }
    }
}
