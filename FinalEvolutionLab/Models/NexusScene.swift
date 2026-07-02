import Foundation
import CoreGraphics
import SwiftUI

// MARK: - NexusScene

/// A scene graph container for the Nexus game engine.
/// Describes all entities, environment settings, and physics configuration
/// for a single game mode session.
struct NexusScene: Identifiable, Codable, Sendable {
    let id: String
    var name: String
    let gameModeId: GameModeId
    var entities: [NexusEntity]
    var environment: NexusEnvironment
    var physicsConfig: NexusPhysicsConfig

    static func `default`(for modeId: GameModeId, prq: Double = 50) -> NexusScene {
        var config = NexusPhysicsConfig()
        config.applyPRQ(prq)
        return NexusScene(
            id: UUID().uuidString,
            name: modeId.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
            gameModeId: modeId,
            entities: defaultEntities(for: modeId),
            environment: NexusEnvironment.default(for: modeId),
            physicsConfig: config
        )
    }

    private static func defaultEntities(for mode: GameModeId) -> [NexusEntity] {
        [
            NexusEntity(
                id: "player_\(mode.rawValue)",
                name: "Player",
                transform: NexusTransform(position: CGPoint(x: 0.5, y: 0.72), rotation: 0, scale: 1.0),
                components: [
                    .skeleton(category: mode.avatarCategory, amplitude: 1.0),
                    .physics(mass: 80, restitution: 0.3)
                ]
            ),
            NexusEntity(
                id: "floor_\(mode.rawValue)",
                name: "Floor",
                transform: NexusTransform(position: CGPoint(x: 0.5, y: 0.88), rotation: 0, scale: 1.0),
                components: [.surface(friction: 0.4)]
            ),
            NexusEntity(
                id: "camera_main",
                name: "Main Camera",
                transform: NexusTransform(position: CGPoint(x: 0.5, y: 0.5), rotation: 0, scale: 1.0),
                components: [.camera(zoom: 1.0, fov: 60)]
            ),
        ]
    }
}

// MARK: - NexusEntity

struct NexusEntity: Identifiable, Codable, Sendable {
    let id: String
    var name: String
    var transform: NexusTransform
    var components: [NexusComponentType]
    var isEnabled: Bool = true

    var isCamera: Bool { components.contains { if case .camera = $0 { true } else { false } } }
    var hasPhysics: Bool { components.contains { if case .physics = $0 { true } else { false } } }
}

// MARK: - NexusTransform

/// Normalized 2-D transform. Position values are in the 0–1 range (relative to scene bounds).
struct NexusTransform: Codable, Sendable {
    var position: CGPoint
    var rotation: CGFloat
    var scale: CGFloat

    func resolvedPosition(in size: CGSize) -> CGPoint {
        CGPoint(x: position.x * size.width, y: position.y * size.height)
    }
}

// MARK: - NexusComponentType

enum NexusComponentType: Codable, Sendable {
    case physics(mass: Double, restitution: Double)
    case surface(friction: Double)
    case sprite(systemImage: String, hexColor: String)
    case skeleton(category: Exercise.ExerciseCategory, amplitude: CGFloat)
    case trigger(radius: CGFloat, eventName: String)
    case camera(zoom: CGFloat, fov: Double)
    case light(intensity: Double, hexColor: String)

    var displayName: String {
        switch self {
        case .physics:  "Physics Body"
        case .surface:  "Surface"
        case .sprite:   "Sprite"
        case .skeleton: "Skeleton Animator"
        case .trigger:  "Trigger Zone"
        case .camera:   "Camera"
        case .light:    "Light"
        }
    }

    var systemImage: String {
        switch self {
        case .physics:  "figure.walk.motion"
        case .surface:  "rectangle.fill"
        case .sprite:   "photo.fill"
        case .skeleton: "figure.mixed.cardio"
        case .trigger:  "circle.dashed"
        case .camera:   "camera.fill"
        case .light:    "light.max"
        }
    }
}

// MARK: - NexusEnvironment

struct NexusEnvironment: Codable, Sendable {
    var backgroundColor: String
    var accentColor: String
    var ambientLight: Double
    var floorY: CGFloat
    var fogDensity: Double

    static func `default`(for mode: GameModeId) -> NexusEnvironment {
        switch mode {
        case .basketballHeadToHead, .basketball3v3, .basketballDunkContestIRL, .basketballDunkContest3D:
            return NexusEnvironment(backgroundColor: "#0A0F1E", accentColor: "#FF6B00", ambientLight: 0.85, floorY: 0.86, fogDensity: 0.02)
        case .karate, .karateEndless:
            return NexusEnvironment(backgroundColor: "#0A0A0A", accentColor: "#FF2D55", ambientLight: 0.70, floorY: 0.86, fogDensity: 0.04)
        case .soccer:
            return NexusEnvironment(backgroundColor: "#0D1A0D", accentColor: "#34C759", ambientLight: 0.90, floorY: 0.86, fogDensity: 0.01)
        case .golf:
            return NexusEnvironment(backgroundColor: "#0D1A0A", accentColor: "#30D158", ambientLight: 1.00, floorY: 0.80, fogDensity: 0.0)
        case .tennis:
            return NexusEnvironment(backgroundColor: "#1A0D0D", accentColor: "#FFD60A", ambientLight: 0.90, floorY: 0.86, fogDensity: 0.01)
        case .volleyball:
            return NexusEnvironment(backgroundColor: "#0D1020", accentColor: "#64D2FF", ambientLight: 0.85, floorY: 0.86, fogDensity: 0.02)
        case .baseball:
            return NexusEnvironment(backgroundColor: "#0F1A0A", accentColor: "#FF9F0A", ambientLight: 0.95, floorY: 0.84, fogDensity: 0.01)
        case .football:
            return NexusEnvironment(backgroundColor: "#0A1209", accentColor: "#34C759", ambientLight: 0.90, floorY: 0.85, fogDensity: 0.01)
        case .surfing:
            return NexusEnvironment(backgroundColor: "#001A33", accentColor: "#00B4D8", ambientLight: 0.85, floorY: 0.60, fogDensity: 0.08)
        case .snowboarding:
            return NexusEnvironment(backgroundColor: "#D0E4F0", accentColor: "#0A84FF", ambientLight: 1.00, floorY: 0.80, fogDensity: 0.06)
        case .skateboarding:
            return NexusEnvironment(backgroundColor: "#1A1A1A", accentColor: "#FF9F0A", ambientLight: 0.75, floorY: 0.86, fogDensity: 0.03)
        case .gymnastics:
            return NexusEnvironment(backgroundColor: "#0A0A12", accentColor: "#BF5AF2", ambientLight: 0.80, floorY: 0.86, fogDensity: 0.01)
        case .brainBrawl:
            return NexusEnvironment(backgroundColor: "#0A0014", accentColor: "#5E5CE6", ambientLight: 0.65, floorY: 0.86, fogDensity: 0.06)
        default:
            return NexusEnvironment(backgroundColor: "#0A0A12", accentColor: "#0A84FF", ambientLight: 0.75, floorY: 0.86, fogDensity: 0.02)
        }
    }
}

// MARK: - NexusPhysicsConfig

struct NexusPhysicsConfig: Codable, Sendable {
    var gravity: Double = 9.8
    var frictionCoefficient: Double = 0.30
    var airResistance: Double = 0.02
    var prqSpeedMultiplier: Double = 1.0
    var prqJumpBonus: Double = 0.0
    var prqReactionWindow: Double = 0.3

    /// Scales physics coefficients by a PRQ score (0–100).
    mutating func applyPRQ(_ prq: Double) {
        let t = max(0, min(100, prq)) / 100.0
        prqSpeedMultiplier = 1.0 + t * 0.55
        prqJumpBonus = t * 2.2
        prqReactionWindow = 0.5 - t * 0.25
    }
}

// MARK: - GameModeId + Nexus helpers

extension GameModeId {
    /// Default avatar animation category for this game mode.
    var avatarCategory: Exercise.ExerciseCategory {
        switch self {
        case .basketballHeadToHead, .basketball3v3, .basketballDunkContestIRL, .basketballDunkContest3D:
            .plyometric
        case .karate, .karateEndless, .soccer, .skateboarding, .snowboarding, .surfing:
            .agility
        case .baseball, .football, .tennis, .volleyball:
            .strength
        case .gymnastics, .golf:
            .mobility
        case .brainBrawl, .whoSceneIt, .courtCarnival, .marketBrowse:
            .recovery
        }
    }
}
