import Foundation
import UIKit

/// Graphics/performance preset for gameplay. Aligns with INSPIRATIONS_COMPARISON: High (2K/Storm polish), Standard (balanced), Performance (Wii-like reliability, battery).
nonisolated enum GameQualityPreset: String, CaseIterable, Identifiable, Sendable {
    case high = "High"
    case standard = "Standard"
    case performance = "Performance"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var subtitle: String {
        switch self {
        case .high: return "60fps · Best visuals"
        case .standard: return "60fps · Balanced"
        case .performance: return "30fps · Battery & older devices"
        }
    }

    var contentScaleFactor: CGFloat {
        switch self {
        case .high: return 2.0
        case .standard: return 1.5
        case .performance: return 1.0
        }
    }

    var preferredFramesPerSecond: Int {
        switch self {
        case .high, .standard: return 60
        case .performance: return 30
        }
    }

    var shadowMapSize: Int {
        switch self {
        case .high: return 4096
        case .standard: return 2048
        case .performance: return 1024
        }
    }

    var shadowSampleCount: Int {
        switch self {
        case .high: return 64
        case .standard: return 32
        case .performance: return 16
        }
    }

    /// Multiplier for particle birth rate and size (1.0 = current default).
    var particleScale: Double {
        switch self {
        case .high: return 1.0
        case .standard: return 0.75
        case .performance: return 0.4
        }
    }

    static let userDefaultsKey = "gameQualityPreset"

    static var current: GameQualityPreset {
        get {
            guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
                  let preset = GameQualityPreset(rawValue: raw) else { return .standard }
            return preset
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }
}
