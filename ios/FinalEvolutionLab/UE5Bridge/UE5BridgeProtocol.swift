// UE5BridgeProtocol.swift
// Protocol defining the interface between Swift UI and UE5 game engine.
// This abstraction allows the app to run with or without UE5 embedded.

import Foundation
import UIKit

/// Protocol for UE5 game engine integration
protocol UE5BridgeProtocol {
    /// Whether the UE5 framework is loaded and ready
    var isAvailable: Bool { get }
    
    /// Initialize the UE5 engine
    func initialize() async throws
    
    /// Shut down the UE5 engine
    func shutdown()
    
    /// Create a UIView that renders the UE5 Metal content
    func createGameView() -> UIView?
    
    /// Launch a specific game mode
    /// - Parameter modeId: The game mode identifier (e.g., "basketball_h2h")
    func launchMode(_ modeId: String)
    
    /// Exit the current game mode and return to menu
    func exitMode()
    
    /// Send motion data from CoreMotion to UE5
    /// - Parameter jsonData: JSON-encoded motion data
    func sendMotionData(_ jsonData: String)
    
    /// Play an exercise demo animation
    /// - Parameter exerciseId: Exercise identifier
    func playExerciseDemo(_ exerciseId: String)
    
    /// Get the current score from UE5
    var currentScore: Int { get }
    
    /// Callback when score changes
    var onScoreUpdate: ((Int) -> Void)? { get set }
    
    /// Callback when game mode completes
    var onModeComplete: ((String, Int) -> Void)? { get set }
}

/// Stub implementation when UE5 framework is not embedded
/// The app falls back to SceneKit rendering
class UE5BridgeStub: UE5BridgeProtocol {
    var isAvailable: Bool { false }
    var currentScore: Int = 0
    var onScoreUpdate: ((Int) -> Void)?
    var onModeComplete: ((String, Int) -> Void)?
    
    func initialize() async throws {
        // No-op: UE5 not available
    }
    
    func shutdown() {
        // No-op
    }
    
    func createGameView() -> UIView? {
        // Return nil — caller should fall back to SceneKit
        return nil
    }
    
    func launchMode(_ modeId: String) {
        print("[UE5Bridge] Stub — mode \(modeId) not available without UE5")
    }
    
    func exitMode() {
        // No-op
    }
    
    func sendMotionData(_ jsonData: String) {
        // No-op
    }
    
    func playExerciseDemo(_ exerciseId: String) {
        print("[UE5Bridge] Stub — exercise \(exerciseId) demo not available")
    }
}

/// Singleton accessor — returns real UE5 bridge or stub
enum UE5Bridge {
    static let shared: UE5BridgeProtocol = {
        // Try to load UE5 framework dynamically
        // If available, return real implementation
        // Otherwise return stub
        #if canImport(FinalEvolutionLabUE5)
        return UE5BridgeReal()
        #else
        return UE5BridgeStub()
        #endif
    }()
}
