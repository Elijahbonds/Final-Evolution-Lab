import Foundation

/// Loads `ACADEMY_CURRICULUM_V1.json` from the app bundle (`Source/Config/`) for Sovereign Ignition UI / deep links.
nonisolated struct AcademyCurriculumV1Manifest: Codable, Sendable {
    let version: String
    let name: String
    let modules: [AcademyCurriculumV1Module]
}

nonisolated struct AcademyCurriculumV1Module: Codable, Sendable, Identifiable {
    let id: String
    let number: Int
    let title: String
    let subtitle: String
    let muscleMotionLayer: String
    let phase: String?
}

nonisolated enum AcademyCurriculumV1Loader {
    static func loadManifest() -> AcademyCurriculumV1Manifest? {
        guard let url = Bundle.main.url(forResource: "ACADEMY_CURRICULUM_V1", withExtension: "json", subdirectory: "Config")
                ?? Bundle.main.url(forResource: "ACADEMY_CURRICULUM_V1", withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AcademyCurriculumV1Manifest.self, from: data)
    }
}
