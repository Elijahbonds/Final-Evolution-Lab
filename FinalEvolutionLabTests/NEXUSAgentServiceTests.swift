import Testing
@testable import FinalEvolutionLab

@Suite("NEXUS Agent sandbox")
struct NEXUSAgentServiceTests {
    @Test("repo path blocks traversal")
    func pathTraversalBlocked() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(name: .readFile, arguments: ["path": "../etc/passwd"])
        )
        #expect(result.success == false)
        #expect(result.summary.contains("traversal") || result.summary.contains("blocked"))
    }

    @Test("list_modes returns registry rows")
    func listModes() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(name: .listModes, arguments: ["include_preview": true])
        )
        #expect(result.success)
        #expect((result.payload["count"] as? Int ?? 0) >= GameModeRegistry.arenaRegistryModeIds.count)
    }

    @Test("creative_command rejects unknown fel command")
    func creativeReject() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(
                name: .creativeCommand,
                arguments: ["command": "fel.admin.drop_database", "params": [:]]
            )
        )
        #expect(result.success == false)
    }

    @Test("build_gate alias maps to run_build_gate")
    func buildGateAlias() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(name: .buildGate, arguments: ["target": "full_gate"])
        )
        #if os(iOS)
        #expect(result.success == false)
        #expect(result.payload["blocked_reason"] != nil || result.payload["manual_command"] != nil)
        #endif
    }

    @Test("agent_command routes read_file")
    func agentCommandRoute() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(
                name: .agentCommand,
                arguments: [
                    "tool": "read_file",
                    "arguments": ["path": "NEXUS_ONLY_PIVOT.md"],
                ]
            )
        )
        #expect(result.success)
        #expect(result.payload["routed_tool"] as? String == "read_file")
    }

    @Test("playtest alias launches mode notification path")
    func playtestAlias() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(
                name: .playtest,
                arguments: ["mode_id": GameModeId.basketballDunkContest3D.rawValue]
            )
        )
        #expect(result.success)
        #expect(result.payload["mode_id"] as? String == GameModeId.basketballDunkContest3D.rawValue)
    }

    @Test("playtest accepts canonical C++ dunk alias")
    func playtestCanonicalDunkAlias() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(
                name: .playtest,
                arguments: ["mode_id": "basketball_dunk"]
            )
        )
        #expect(result.success)
        #expect(result.payload["mode_id"] as? String == GameModeId.basketballDunkContest3D.rawValue)
        #expect(result.payload["registry_mode_id"] as? String == "basketball_dunk")
        #expect(result.payload["runtime_mode_id"] as? String == "basketball_dunk")
    }

    @Test("playtest rejects non-runtime mode")
    func playtestRejectsNonRuntimeMode() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(
                name: .playtest,
                arguments: ["mode_id": GameModeId.basketballDunkContestIRL.rawValue]
            )
        )
        #expect(result.success == false)
        #expect(result.summary.contains("not launchable"))
    }

    @Test("scan_to_generate returns simulated plan when bridge unlinked")
    func scanToGenerateSimulated() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(
                name: .scanToGenerate,
                arguments: ["use_simulated": true]
            )
        )
        #expect(result.success)
        if NexusGameplayBridge.isLinked {
            #expect(result.payload["recommended_mode_id"] != nil)
        } else {
            #expect(result.payload["command_plan"] != nil)
            #expect(result.payload["bridge_linked"] as? Bool == false)
        }
    }

    @Test("run_build_gate blocked on iOS target")
    func buildGateSandbox() async {
        let service = NEXUSAgentService.shared
        let result = await service.execute(
            toolCall: NEXUSAgentToolCall(name: .runBuildGate, arguments: ["target": "full_gate"])
        )
        #if os(iOS)
        #expect(result.success == false)
        #expect(result.payload["blocked_reason"] != nil)
        #endif
    }
}
