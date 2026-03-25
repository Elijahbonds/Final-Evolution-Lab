import Foundation

// MARK: - SFMA / FMS corrective GPS (Vertical Velocity Academy — Build 6)

/// Top-tier SFMA screens used for the in-app corrective loop.
nonisolated enum SFMAScreen: String, Sendable, CaseIterable, Codable {
    case multiSegmentalRotation = "Multi-Segmental Rotation"
    case ankleClearing = "Ankle Clearing"
}

nonisolated enum SFMAScreenResult: String, Sendable, Codable {
    case pass
    case fail
}

/// Skeletal regions for 3D heatmap / Unreal anatomy sync (normalized concept keys — map in engine to bone names).
nonisolated enum SFMASkeletalRegion: String, Sendable, Codable, CaseIterable {
    case thoracicSpine = "ThoracicSpine"
    case spiralLine = "SpiralLine"
    case leftAnkle = "Ankle_L"
    case rightAnkle = "Ankle_R"
    case deepFrontLine = "DeepFrontLine"
}

/// Red “congestion” overlay target for failed screens (Swift + Unreal).
nonisolated struct SFMAHeatmapPayload: Sendable, Codable {
    var regions: [SFMASkeletalRegion]
    var intensity01: Double
    var label: String
}

/// Central SFMA logic gate + bridge payloads for the Interactive Clinical Anatomy Engine.
enum SFMA_DiagnosticManager {
    /// If rotation fails → NMS reset via isometric split stance wall push.
    private static let msrFailCorrective = "NMS Reset: Isometric Split Stance Wall Push"
    /// If ankle clearing fails → PJF band ankle work on TBB.
    private static let ankleFailCorrective = "Ankle Anchor drills — PJF Band on Total Body Board (TBB)"

    /// GPS-style corrective line from screen results.
    static func correctiveSuggestions(for results: [SFMAScreen: SFMAScreenResult]) -> [String] {
        var lines: [String] = []
        if results[.multiSegmentalRotation] == .fail {
            lines.append(msrFailCorrective)
        }
        if results[.ankleClearing] == .fail {
            lines.append(ankleFailCorrective)
        }
        return lines
    }

    /// Maps failed screens to **skeletal coordinates** (conceptual regions) for Unity/Unreal / SceneKit heatmaps.
    static func heatmapPayload(for results: [SFMAScreen: SFMAScreenResult]) -> SFMAHeatmapPayload? {
        var regions: [SFMASkeletalRegion] = []
        if results[.multiSegmentalRotation] == .fail {
            regions.append(contentsOf: [.thoracicSpine, .spiralLine])
        }
        if results[.ankleClearing] == .fail {
            regions.append(contentsOf: [.leftAnkle, .rightAnkle])
        }
        guard !regions.isEmpty else { return nil }
        return SFMAHeatmapPayload(regions: regions, intensity01: 0.92, label: "SFMA_FAIL_CONGESTION")
    }

    /// JSON for Unreal `UFELFascialSlingVisualizer` / material parameters (red congestion, spiral line).
    static func unrealClinicalJSON(for results: [SFMAScreen: SFMAScreenResult]) -> String {
        let payload: [String: Any] = [
            "multiSegmentalRotation": results[.multiSegmentalRotation]?.rawValue ?? "unknown",
            "ankleClearing": results[.ankleClearing]?.rawValue ?? "unknown",
            "redCongestionRegions": heatmapPayload(for: results)?.regions.map(\.rawValue) ?? [],
            "spiralLineHighlight": results[.multiSegmentalRotation] == .fail,
            "fascialSlingActive": true,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    /// Post notification for embedded Unreal Lab to apply heatmap + fascial line materials.
    static func publishToClinicalBridge(results: [SFMAScreen: SFMAScreenResult]) {
        let json = unrealClinicalJSON(for: results)
        var info: [String: Any] = ["json": json]
        if let h = heatmapPayload(for: results) {
            info["regionNames"] = h.regions.map(\.rawValue)
            info["intensity01"] = h.intensity01
        }
        NotificationCenter.default.post(name: .felSFMAClinicalAnatomyHeatmap, object: nil, userInfo: info)
    }
}
