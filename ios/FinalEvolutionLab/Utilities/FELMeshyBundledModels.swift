import Foundation
import SceneKit

/// Loads Meshy `.glb` exports from the app bundle when present (same filenames as `UnrealStarter/IMPORT_CHECKLIST.md`).
/// Add files under the **`Meshy/`** folder in the `FinalEvolutionLab` target (see `Meshy/README.md`).
enum FELMeshyBundledModels {

    private static let meshySubdirectory = "Meshy"

    /// HoopBus basketball — import to `/Game/FEL/Props/SM_HoopBusBasketball` in Unreal.
    static let hoopBusBasketballFile = "Meshy_AI_HoopBus_Basketball_0319064117_texture"

    /// Elijah — prefer running, then walking (matches checklist).
    static let elijahRunningFile = "Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin"
    static let elijahWalkingFile = "Meshy_AI_Elijah_Bonds_biped_Animation_Walking_withSkin"

    /// Soccer / tennis (see `Content/FEL/External/Meshy/README.md`) — optional for future SceneKit modes.
    static let meshySoccerBallFile = "Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture"
    static let meshyTennisBallFile = "Meshy_AI_Tennis_Ball_Bright__0323202210_texture"

    private static func urlInBundle(baseName: String, ext: String) -> URL? {
        Bundle.main.url(forResource: baseName, withExtension: ext, subdirectory: meshySubdirectory)
    }

    /// Builds an `SCNNode` hierarchy from a `.glb` in `Meshy/`, or nil if missing / invalid.
    static func loadGLBNode(baseName: String) -> SCNNode? {
        guard let url = urlInBundle(baseName: baseName, ext: "glb") else { return nil }
        do {
            let scene = try SCNScene(url: url, options: [
                SCNSceneSource.LoadingOption.convertToYUp: true,
                SCNSceneSource.LoadingOption.checkConsistency: true
            ])
            let root = SCNNode()
            root.name = baseName
            for child in scene.rootNode.childNodes {
                root.addChildNode(child.clone())
            }
            guard root.childNodes.count > 0 else { return nil }
            return root
        } catch {
            return nil
        }
    }

    /// Scales and offsets so the model’s bottom sits at local Y = 0 (for placing at court position).
    private static func groundAndScale(node: SCNNode, targetHeight: CGFloat) {
        let (minB, maxB) = node.boundingBox
        let h = CGFloat(maxB.y - minB.y)
        guard h > 0.001 else { return }
        let s = Float(targetHeight / h)
        node.scale = SCNVector3(s, s, s)
        let (minAfter, _) = node.boundingBox
        node.position = SCNVector3(0, -minAfter.y, 0)
    }

    /// Hero character for basketball scenes (~1.78 m). Tries running GLB, then walking.
    static func loadElijahHeroNode() -> SCNNode? {
        let bases = [elijahRunningFile, elijahWalkingFile]
        for base in bases {
            guard let root = loadGLBNode(baseName: base) else { continue }
            groundAndScale(node: root, targetHeight: 1.78)
            return root
        }
        return nil
    }

    /// HoopBus basketball mesh; normalized to ~24 cm diameter (matches procedural ball scale).
    static func loadHoopBusBasketballNode() -> SCNNode? {
        guard let root = loadGLBNode(baseName: hoopBusBasketballFile) else { return nil }
        let targetDiameter: CGFloat = 0.24
        let (minB, maxB) = root.boundingBox
        let extent = max(CGFloat(maxB.x - minB.x), CGFloat(maxB.y - minB.y), CGFloat(maxB.z - minB.z))
        guard extent > 0.001 else { return root }
        let s = Float(targetDiameter / extent)
        nodeUniformScale(root, s)
        let (minAfter, _) = root.boundingBox
        root.position = SCNVector3(0, -minAfter.y, 0)
        return root
    }

    private static func nodeUniformScale(_ node: SCNNode, _ s: Float) {
        node.scale = SCNVector3(s, s, s)
    }
}
