import Foundation

/// Reads `artifacts/playtest/latest.json` from the NEXUS repo for Studio Run panel + Agent tools.
enum NexusPlaytestArtifactReader {
    static let relativePath = "artifacts/playtest/latest.json"

    struct Summary: Sendable {
        let overallStatus: String
        let modeId: String?
        let venue: String?
        let generatedAt: String?
        let runtimeFPS: Double?
        let triangleCount: Int?
        let rawPath: String
        let exists: Bool
    }

    static func loadSummary() -> Summary {
        let root = NEXUSCursorBridge.resolvedRepoRootPath()
        let path = (root as NSString).appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return Summary(
                overallStatus: "missing",
                modeId: nil,
                venue: nil,
                generatedAt: nil,
                runtimeFPS: nil,
                triangleCount: nil,
                rawPath: path,
                exists: false
            )
        }

        let playtest = json["playtest"] as? [String: Any]
        let runtime = json["runtime"] as? [String: Any]
        let environment = json["environment"] as? [String: Any]

        return Summary(
            overallStatus: json["overall_status"] as? String ?? "unknown",
            modeId: playtest?["mode"] as? String ?? (json["mode_state"] as? [String: Any])?["mode_id"] as? String,
            venue: playtest?["venue"] as? String ?? environment?["venue_key"] as? String,
            generatedAt: json["generated_at"] as? String,
            runtimeFPS: runtime?["fps_last"] as? Double,
            triangleCount: (runtime?["triangle_count"] as? Int) ?? (environment?["triangle_count"] as? Int),
            rawPath: path,
            exists: true
        )
    }

    static func loadRawJSON() -> String? {
        let root = NEXUSCursorBridge.resolvedRepoRootPath()
        let path = (root as NSString).appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
}
