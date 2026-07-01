import SceneKit
import UIKit

/// Central refresh / quality policy for gameplay tick vs viewport render (NEXUS mobile target: 60 Hz sim).
enum FELViewportRefreshPolicy {
    /// C++ session + HUD poll rate (`IOS_RUNBOOK.md` § NEXUS HUD poll).
    static let gameplayTickHz = 60

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    /// Check if the device is in low power mode or has a serious/critical thermal state.
    static var isLowPowerOrThrottled: Bool {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return true
        }
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }

    /// Merges iOS thermal/low-power signals with the active performance tier (worst tier wins).
    static var effectiveTier: FELPerformanceTier {
        let monitorTier = FELPerformanceMonitor.shared.currentTier
        if isLowPowerOrThrottled {
            return .lowPower
        }
        return monitorTier
    }

    /// SceneKit draw rate — tier-aware; caps simulator at 60; device may use ProMotion up to 120.
    static func sceneKitTargetFPS(for tier: FELPerformanceTier = effectiveTier) -> Int {
        switch tier {
        case .lowPower:
            return 30
        case .balanced:
            if isSimulator { return gameplayTickHz }
            return min(60, screenMaxFPS)
        case .high:
            if isLowPowerOrThrottled { return 30 }
            if isSimulator { return gameplayTickHz }
            return min(120, screenMaxFPS)
        }
    }

    static var sceneKitTargetFPS: Int {
        sceneKitTargetFPS(for: effectiveTier)
    }

    /// Metal draw rate — tier-aware; scales down under low-power or severe thermal conditions.
    static func metalTargetFPS(for tier: FELPerformanceTier = effectiveTier) -> Int {
        switch tier {
        case .lowPower:
            return 30
        case .balanced:
            return 45
        case .high:
            return isLowPowerOrThrottled ? 30 : gameplayTickHz
        }
    }

    static var metalTargetFPS: Int {
        metalTargetFPS(for: effectiveTier)
    }

    /// SceneKit antialiasing mode — tier-aware; disables AA under low-power or severe thermal.
    static func sceneKitAntialiasing(for tier: FELPerformanceTier = effectiveTier) -> SCNAntialiasingMode {
        switch tier {
        case .lowPower:
            return .none
        case .balanced:
            return .multisampling2X
        case .high:
            if isLowPowerOrThrottled { return .none }
            return isSimulator ? .multisampling2X : .multisampling4X
        }
    }

    static var sceneKitAntialiasing: SCNAntialiasingMode {
        sceneKitAntialiasing(for: effectiveTier)
    }

    private static var screenMaxFPS: Int {
        let screenMax = UIScreen.main.maximumFramesPerSecond
        return screenMax > 0 ? screenMax : gameplayTickHz
    }
}
