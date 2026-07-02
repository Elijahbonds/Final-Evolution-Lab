import SceneKit
import UIKit

/// Clustered chase camera, hybrid backdrop, and lighting tuning for premium 3D viewports.
enum PremiumViewpointConfig {
    enum Cluster: String, Sendable {
        case basketball
        case dojo
        case stadium
        case outdoor
        case indoor
    }

    struct ChaseCamera: Sendable {
        let offsetX: Float
        let offsetY: Float
        let offsetZ: Float
        let lookAtY: Float
        let followSpeed: Float
        let targetSpeed: Float
        let fovNormal: CGFloat
        let fovAction: CGFloat
    }

    struct BackdropPlacement: Sendable {
        let manifestPosition: SCNVector3
        let manifestScale: SCNVector3
        let environmentPosition: SCNVector3
        let environmentScale: SCNVector3
        let renderingOrder: Int
    }

    struct Lighting: Sendable {
        let ambientIntensity: CGFloat
        let venueFillIntensity: CGFloat
        let avatarFillIntensity: CGFloat
        let spotIntensity: CGFloat
        let exposureOffset: CGFloat
    }

    static func cluster(for mode: GameModeId) -> Cluster {
        switch mode {
        case .basketballHeadToHead, .venicePickup, .basketballDunkContestIRL, .basketballDunkContest3D, .basketball3v3,
             .courtCarnival, .surfing, .tennis:
            return .basketball
        case .karate, .karateEndless:
            return .dojo
        case .baseball, .football, .soccer:
            return .stadium
        case .golf, .volleyball, .skateboarding, .snowboarding:
            return .outdoor
        case .gymnastics, .brainBrawl, .whoSceneIt, .marketBrowse:
            return .indoor
        }
    }

    static func chaseCamera(for mode: GameModeId) -> ChaseCamera {
        let base = clusterBaseCamera[cluster(for: mode)] ?? clusterBaseCamera[.basketball]!
        return modeCameraDelta[mode]?.merged(into: base) ?? base
    }

    static func backdropPlacement(for mode: GameModeId) -> BackdropPlacement {
        backdropByCluster[cluster(for: mode)] ?? backdropByCluster[.basketball]!
    }

    static func lighting(for mode: GameModeId) -> Lighting {
        lightingByCluster[cluster(for: mode)] ?? lightingByCluster[.basketball]!
    }

    static func defaultFieldOfView(for mode: GameModeId) -> CGFloat {
        chaseCamera(for: mode).fovNormal
    }

    /// Hybrid Metal venue + SceneKit overlay — avatar fill, depth layering, premium exposure.
    static func configureHybridOverlay(_ scene: SCNScene, for mode: GameModeId) {
        let lighting = lighting(for: mode)
        applyClusterLighting(to: scene, lighting: lighting, hybridOverlay: true)
        configureDepthLayering(in: scene)
        attachAvatarFillLight(to: scene, intensity: lighting.avatarFillIntensity, tint: clusterTint(for: mode))

        if let camNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true),
           let camera = camNode.camera {
            camera.fieldOfView = defaultFieldOfView(for: mode)
            camera.zNear = 0.08
            camera.zFar = 140
            camera.wantsHDR = false
            camera.exposureOffset = lighting.exposureOffset
            camera.bloomIntensity = 0.18
            camera.vignettingIntensity = 0.35
        }
    }

    /// Full SceneKit path — cluster atmosphere + chase-ready camera FOV.
    static func applyToScene(_ scene: SCNScene, for mode: GameModeId) {
        let lighting = lighting(for: mode)
        applyClusterLighting(to: scene, lighting: lighting, hybridOverlay: false)
        tuneAtmosphereNodes(in: scene, for: mode)

        if let camNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true),
           let camera = camNode.camera {
            camera.fieldOfView = defaultFieldOfView(for: mode)
            camera.zNear = 0.1
            camera.zFar = 120
        }
    }

    static func applyBackdropTuning(to node: SCNNode, for mode: GameModeId) {
        let placement = backdropPlacement(for: mode)
        node.renderingOrder = placement.renderingOrder
        node.categoryBitMask = 1 << 1
    }

    private static func clusterTint(for mode: GameModeId) -> UIColor {
        switch cluster(for: mode) {
        case .basketball:
            return UIColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 1)
        case .dojo:
            return UIColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1)
        case .stadium:
            return UIColor(red: 0.75, green: 0.95, blue: 0.65, alpha: 1)
        case .outdoor:
            return UIColor(red: 0.95, green: 0.88, blue: 0.55, alpha: 1)
        case .indoor:
            return UIColor(red: 0.65, green: 0.72, blue: 1.0, alpha: 1)
        }
    }

    private static let clusterBaseCamera: [Cluster: ChaseCamera] = [
        .basketball: ChaseCamera(
            offsetX: 2.4, offsetY: 5.8, offsetZ: 9.8,
            lookAtY: 1.35, followSpeed: 5.5, targetSpeed: 7.5,
            fovNormal: 54, fovAction: 44
        ),
        .dojo: ChaseCamera(
            offsetX: 0, offsetY: 4.2, offsetZ: 7.8,
            lookAtY: 1.25, followSpeed: 7.5, targetSpeed: 9.5,
            fovNormal: 52, fovAction: 42
        ),
        .stadium: ChaseCamera(
            offsetX: 0.5, offsetY: 7.2, offsetZ: 11.0,
            lookAtY: 1.05, followSpeed: 5.0, targetSpeed: 6.5,
            fovNormal: 56, fovAction: 46
        ),
        .outdoor: ChaseCamera(
            offsetX: 1.6, offsetY: 5.0, offsetZ: 9.5,
            lookAtY: 1.2, followSpeed: 4.5, targetSpeed: 6.5,
            fovNormal: 54, fovAction: 44
        ),
        .indoor: ChaseCamera(
            offsetX: 0.8, offsetY: 4.4, offsetZ: 8.0,
            lookAtY: 1.35, followSpeed: 4.0, targetSpeed: 6.0,
            fovNormal: 52, fovAction: 42
        ),
    ]

    private static let modeCameraDelta: [GameModeId: ChaseCamera] = [
        .basketballDunkContest3D: ChaseCamera(
            offsetX: 1.8, offsetY: 6.2, offsetZ: 10.5,
            lookAtY: 2.05, followSpeed: 6.0, targetSpeed: 8.0,
            fovNormal: 54, fovAction: 42
        ),
        .marketBrowse: ChaseCamera(
            offsetX: 0.4, offsetY: 2.6, offsetZ: 5.2,
            lookAtY: 1.4, followSpeed: 4.0, targetSpeed: 6.0,
            fovNormal: 56, fovAction: 48
        ),
        .baseball: ChaseCamera(
            offsetX: -2.2, offsetY: 4.2, offsetZ: 7.5,
            lookAtY: 1.55, followSpeed: 4.0, targetSpeed: 6.0,
            fovNormal: 54, fovAction: 44
        ),
        .golf: ChaseCamera(
            offsetX: 2.2, offsetY: 3.4, offsetZ: 8.5,
            lookAtY: 1.0, followSpeed: 3.0, targetSpeed: 5.0,
            fovNormal: 52, fovAction: 42
        ),
        .brainBrawl: ChaseCamera(
            offsetX: 0.9, offsetY: 4.5, offsetZ: 7.8,
            lookAtY: 1.45, followSpeed: 3.0, targetSpeed: 5.0,
            fovNormal: 50, fovAction: 38
        ),
    ]

    private static let backdropByCluster: [Cluster: BackdropPlacement] = [
        .basketball: BackdropPlacement(
            manifestPosition: SCNVector3(0, 0.2, -16),
            manifestScale: SCNVector3(2.85, 2.85, 2.85),
            environmentPosition: SCNVector3(0, -0.35, -8),
            environmentScale: SCNVector3(1.55, 1.55, 1.55),
            renderingOrder: -120
        ),
        .dojo: BackdropPlacement(
            manifestPosition: SCNVector3(0, 0, -14),
            manifestScale: SCNVector3(2.45, 2.45, 2.45),
            environmentPosition: SCNVector3(0, -0.25, -7),
            environmentScale: SCNVector3(1.35, 1.35, 1.35),
            renderingOrder: -120
        ),
        .stadium: BackdropPlacement(
            manifestPosition: SCNVector3(0, 0.4, -18),
            manifestScale: SCNVector3(3.05, 3.05, 3.05),
            environmentPosition: SCNVector3(0, -0.6, -9),
            environmentScale: SCNVector3(1.65, 1.65, 1.65),
            renderingOrder: -130
        ),
        .outdoor: BackdropPlacement(
            manifestPosition: SCNVector3(0, 0.1, -17),
            manifestScale: SCNVector3(2.75, 2.75, 2.75),
            environmentPosition: SCNVector3(0, -0.4, -8.5),
            environmentScale: SCNVector3(1.5, 1.5, 1.5),
            renderingOrder: -120
        ),
        .indoor: BackdropPlacement(
            manifestPosition: SCNVector3(0, 0, -13),
            manifestScale: SCNVector3(2.35, 2.35, 2.35),
            environmentPosition: SCNVector3(0, -0.2, -6.5),
            environmentScale: SCNVector3(1.3, 1.3, 1.3),
            renderingOrder: -110
        ),
    ]

    private static let lightingByCluster: [Cluster: Lighting] = [
        .basketball: Lighting(
            ambientIntensity: 1050, venueFillIntensity: 820, avatarFillIntensity: 1100,
            spotIntensity: 1500, exposureOffset: 0.55
        ),
        .dojo: Lighting(
            ambientIntensity: 980, venueFillIntensity: 760, avatarFillIntensity: 1050,
            spotIntensity: 1350, exposureOffset: 0.5
        ),
        .stadium: Lighting(
            ambientIntensity: 1120, venueFillIntensity: 900, avatarFillIntensity: 1150,
            spotIntensity: 1600, exposureOffset: 0.6
        ),
        .outdoor: Lighting(
            ambientIntensity: 1000, venueFillIntensity: 780, avatarFillIntensity: 1080,
            spotIntensity: 1450, exposureOffset: 0.52
        ),
        .indoor: Lighting(
            ambientIntensity: 940, venueFillIntensity: 720, avatarFillIntensity: 1000,
            spotIntensity: 1280, exposureOffset: 0.48
        ),
    ]

    private static func applyClusterLighting(to scene: SCNScene, lighting: Lighting, hybridOverlay: Bool) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let light = node.light else { return }
            switch light.type {
            case .ambient:
                light.intensity = max(light.intensity, lighting.ambientIntensity)
            case .omni where node.name == "venueFillLight" || node.name == "avatarFillLight":
                light.intensity = node.name == "avatarFillLight"
                    ? lighting.avatarFillIntensity
                    : lighting.venueFillIntensity
            case .spot:
                light.intensity = max(light.intensity, lighting.spotIntensity)
            default:
                break
            }
            if hybridOverlay {
                light.castsShadow = false
            }
        }
    }

    private static func attachAvatarFillLight(to scene: SCNScene, intensity: CGFloat, tint: UIColor) {
        if let existing = scene.rootNode.childNode(withName: "avatarFillLight", recursively: false) {
            existing.light?.intensity = intensity
            existing.light?.color = tint.withAlphaComponent(0.92)
            return
        }
        let fill = SCNNode()
        fill.name = "avatarFillLight"
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.color = tint.withAlphaComponent(0.92)
        fill.light?.intensity = intensity
        fill.light?.attenuationStartDistance = 2
        fill.light?.attenuationEndDistance = 14
        fill.position = SCNVector3(1.2, 4.5, 6.5)
        scene.rootNode.addChildNode(fill)
    }

    private static func configureDepthLayering(in scene: SCNScene) {
        scene.rootNode.enumerateChildNodes { node, _ in
            let name = node.name ?? ""
            if name.hasPrefix("atmosphericBackdrop") || name == "veniceLumaBackdrop"
                || name == "bundledVenueBackdrop" || name == "bundledVenueEnvironment"
                || name == "venueSky" {
                node.renderingOrder = min(node.renderingOrder, -100)
            }
            if name == "avatarFillLight" || name == "venueFillLight" {
                return
            }
            if GameSceneFactory.isGameplayAvatarNodeName(name) {
                node.renderingOrder = max(node.renderingOrder, 5)
            }
            if ["ball", "basketball", "soccerball", "baseball", "golfball", "tennisball", "volleyball"].contains(name) {
                node.renderingOrder = 8
            }
        }
    }

    private static func tuneAtmosphereNodes(in scene: SCNScene, for mode: GameModeId) {
        let cluster = cluster(for: mode)
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }
            if name == "venueSky", let sphere = node.geometry as? SCNSphere,
               let mat = sphere.firstMaterial {
                switch cluster {
                case .basketball:
                    mat.emission.contents = UIColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1)
                case .dojo:
                    mat.emission.contents = UIColor(red: 0.18, green: 0.06, blue: 0.08, alpha: 1)
                case .stadium:
                    mat.emission.contents = UIColor(red: 0.04, green: 0.1, blue: 0.2, alpha: 1)
                default:
                    break
                }
            }
            if name.hasPrefix("atmosphericBackdrop") {
                node.renderingOrder = backdropPlacement(for: mode).renderingOrder
            }
        }
    }
}

private extension PremiumViewpointConfig.ChaseCamera {
    func merged(into base: PremiumViewpointConfig.ChaseCamera) -> PremiumViewpointConfig.ChaseCamera {
        PremiumViewpointConfig.ChaseCamera(
            offsetX: offsetX,
            offsetY: offsetY,
            offsetZ: offsetZ,
            lookAtY: lookAtY,
            followSpeed: followSpeed,
            targetSpeed: targetSpeed,
            fovNormal: fovNormal,
            fovAction: fovAction
        )
    }
}
