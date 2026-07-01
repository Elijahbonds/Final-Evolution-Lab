import Foundation

/// POST scan envelope to NEXUS `fel.generate.arena_from_scan` (fitness + voxel fill).
@MainActor
enum ScanToGenerationBridge {
    struct GenerationResult: Equatable {
        var arenaScale: Double
        var difficultyTier: Int
        var recommendedModeId: String
        var voxelMaterial: Int
        var paintRadius: Int
        var previewLabel: String
        var commandsApplied: [String]
    }

    @discardableResult
    static func submit(envelope: ScanEnvelope) -> GenerationResult? {
        guard NexusGameplayBridge.isLinked else {
            FelToastCenter.shared.show("NEXUS gameplay module not linked on this build.", isError: true)
            return nil
        }

        guard let session = NexusGameplayBridge.createSession() else {
            FelToastCenter.shared.show("Could not create NEXUS gameplay session.", isError: true)
            return nil
        }
        defer { NexusGameplayBridge.destroySession(session) }

        guard let envelopeData = try? JSONEncoder().encode(envelope),
              let envelopeObject = try? JSONSerialization.jsonObject(with: envelopeData) as? [String: Any]
        else {
            return nil
        }

        let payload: [String: Any] = [
            "command": "fel.generate.arena_from_scan",
            "id": "ios_scan_generate_\(envelope.scanId)",
            "params": envelopeObject,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let raw = NexusGameplayBridge.handleCommand(session, commandJson: json),
              let response = parseResponse(raw),
              response.status == "ok",
              let generative = response.payload?["generative"] as? [String: Any]
        else {
            FelToastCenter.shared.show("Scan generation failed — see command log.", isError: true)
            return nil
        }

        let result = GenerationResult(
            arenaScale: number(generative["arena_scale"]),
            difficultyTier: int(generative["difficulty_tier"]),
            recommendedModeId: generative["recommended_mode_id"] as? String ?? "court_carnival",
            voxelMaterial: int(generative["voxel_material"]),
            paintRadius: int(generative["paint_radius"]),
            previewLabel: FELPremiumCopy.humanizePreviewLabel(
                response.payload?["preview_label"] as? String ?? "PREVIEW · GENERATED FROM SCAN"
            ),
            commandsApplied: response.payload?["commands_applied"] as? [String] ?? []
        )

        NotificationCenter.default.post(name: .felScanGenerationCompleted, object: result)
        return result
    }

    private static func parseResponse(_ json: String) -> (status: String, payload: [String: Any]?)? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = root["status"] as? String
        else { return nil }
        return (status, root["payload"] as? [String: Any])
    }

    private static func number(_ value: Any?) -> Double {
        if let n = value as? Double { return n }
        if let n = value as? NSNumber { return n.doubleValue }
        return 1.0
    }

    private static func int(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
        if let n = value as? NSNumber { return n.intValue }
        return 0
    }
}

extension Notification.Name {
    static let felScanGenerationCompleted = Notification.Name("felScanGenerationCompleted")
}
