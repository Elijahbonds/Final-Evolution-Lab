import Foundation

/// Phase 4 / 8 — Two experiences: lightweight native (SceneKit) vs full simulation (Unreal). See `UNREAL_ONLY.md` § Dual track.
/// SceneKit is **not** Luma/Venice ship fidelity — `DOCS/FEL_PHASE4_SHELL_UNREAL_HANDOFF.md`.
enum FELArenaRuntimePreference: String, CaseIterable, Identifiable, Hashable {
    case labSceneKit
    case fullUnreal

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .labSceneKit: return "Lightweight Arena (native)"
        case .fullUnreal: return "Full Simulation (Unreal)"
        }
    }

    var detail: String {
        switch self {
        case .labSceneKit:
            return "SceneKit lab in this app — fast, not the Unreal Luma/Venice build."
        case .fullUnreal:
            return "Canonical game: one Unreal iOS app (ship) or Pixel Streaming — not SceneKit."
        }
    }

    static let userDefaultsKey = "felArenaRuntimePreference"
    static let pixelStreamingURLKey = "felArenaPixelStreamingURL"

    static var stored: FELArenaRuntimePreference {
        get {
            let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? Self.labSceneKit.rawValue
            return FELArenaRuntimePreference(rawValue: raw) ?? .labSceneKit
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }

    /// Optional `https://` URL for a Pixel Streaming player (open in Safari or WKWebView later).
    static var pixelStreamingURLString: String {
        get { UserDefaults.standard.string(forKey: pixelStreamingURLKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: pixelStreamingURLKey) }
    }

    /// Handles `fel://arena/lab` and `fel://arena/unreal` when URL scheme `fel` is registered (Xcode → Info → URL Types).
    @discardableResult
    static func applyIfHandled(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "fel", url.host?.lowercased() == "arena" else {
            return false
        }
        let path = url.path.lowercased()
        if path.contains("unreal") || path.hasSuffix("/full") {
            stored = .fullUnreal
            return true
        }
        if path.contains("lab") || path.contains("scenekit") || path.hasSuffix("/fast") {
            stored = .labSceneKit
            return true
        }
        return false
    }
}
