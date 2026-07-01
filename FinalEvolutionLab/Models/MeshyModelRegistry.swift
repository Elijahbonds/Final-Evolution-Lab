import Foundation
import SceneKit

// MARK: - MeshyModelRegistry
// Maps slot IDs (used throughout the app) to USDZ file names in Models3D/.
// Drop the downloaded .usdz files into Models3D/ and the registry finds them automatically.

enum MeshyModelSlot: String, CaseIterable {
    // Characters
    case elijahBonds      = "elijah_bonds"
    case amirSmith        = "amir_smith"

    // Environments
    case veniceBachHoop   = "venice_beach_hoop"
    case basketballSet    = "basketball_court_set"
    case hoopBus          = "hoopbus_basketball"
    case indoorCourt      = "indoor_basketball_court"
    case soccerStadium    = "soccer_stadium"

    // Props
    case soccerBall       = "soccer_ball"
    case tennisBall       = "tennis_ball"
    case tennisRacket     = "tennis_racket"

    var usdzFileName: String { "\(rawValue).usdz" }

    var displayName: String {
        switch self {
        case .elijahBonds:     return "Elijah Bonds"
        case .amirSmith:       return "Amir Smith"
        case .veniceBachHoop:  return "Venice Beach Hoop"
        case .basketballSet:   return "Basketball Court Set"
        case .hoopBus:         return "HoopBus"
        case .indoorCourt:     return "Indoor Court"
        case .soccerStadium:   return "Soccer Stadium"
        case .soccerBall:      return "Soccer Ball"
        case .tennisBall:      return "Tennis Ball"
        case .tennisRacket:    return "Tennis Racket"
        }
    }

    var category: SlotCategory {
        switch self {
        case .elijahBonds, .amirSmith: return .character
        case .veniceBachHoop, .basketballSet, .hoopBus, .indoorCourt, .soccerStadium: return .environment
        case .soccerBall, .tennisBall, .tennisRacket: return .prop
        }
    }

    var meshyShareURL: URL? {
        let ids: [MeshyModelSlot: String] = [
            .elijahBonds:     "sm8Bi9",
            .amirSmith:       "AW2mM7",
            .veniceBachHoop:  "J4Ldo6",
            .basketballSet:   "vsNQzK",
            .hoopBus:         "ev2MZQ",
            .indoorCourt:     "pcPfoa",
            .soccerStadium:   "gbvJVm",
            .soccerBall:      "FEZUHT",
            .tennisBall:      "QiHuT3",
            .tennisRacket:    "QYupzy",
        ]
        guard let id = ids[self] else { return nil }
        return URL(string: "https://www.meshy.ai/s/\(id)")
    }

    enum SlotCategory { case character, environment, prop }
}

// MARK: - MeshyModelRegistry

final class MeshyModelRegistry {
    static let shared = MeshyModelRegistry()
    private var cache: [MeshyModelSlot: SCNScene] = [:]

    private init() {}

    /// Returns an SCNScene for the slot if the .usdz file exists in the bundle.
    /// Returns nil if the file hasn't been dropped in yet — callers should show a canvas fallback.
    func scene(for slot: MeshyModelSlot) -> SCNScene? {
        if let cached = cache[slot] { return cached }
        guard let url = Bundle.main.url(forResource: slot.rawValue, withExtension: "usdz") else {
            return nil
        }
        let scene = try? SCNScene(url: url, options: [
            .checkConsistency: false,
            .convertToYUp: true
        ])
        if let scene { cache[slot] = scene }
        return scene
    }

    /// True if the USDZ file is present in the bundle.
    func isAvailable(_ slot: MeshyModelSlot) -> Bool {
        Bundle.main.url(forResource: slot.rawValue, withExtension: "usdz") != nil
    }

    /// All slots that have been loaded (files are present).
    var availableSlots: [MeshyModelSlot] {
        MeshyModelSlot.allCases.filter { isAvailable($0) }
    }
}
