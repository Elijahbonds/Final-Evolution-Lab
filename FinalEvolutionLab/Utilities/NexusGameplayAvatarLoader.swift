import Foundation
import SceneKit
import SwiftUI
import UIKit

/// Persistent avatar skin + equipped creator card — loaded from ``UserProfile`` before each scene build.
struct GameplayAvatarAppearance: Equatable, Sendable {
    var skinConfig: AvatarSkinConfig
    var creatorCardId: String?

    static let `default` = GameplayAvatarAppearance(skinConfig: .default, creatorCardId: nil)

    static func fromProfile(_ profile: UserProfile) -> GameplayAvatarAppearance {
        GameplayAvatarAppearance(
            skinConfig: profile.avatarConfig,
            creatorCardId: profile.activeCreatorCard?.cardId
        )
    }

    @MainActor var resolvedCreatorCard: CreatorCard? {
        guard let creatorCardId else { return nil }
        return CreatorCard.catalog.first { $0.id == creatorCardId }
    }
}

enum NexusGameplayAvatarContext {
    private(set) static var current: GameplayAvatarAppearance = .default

    static func refreshFromProfile() {
        current = GameplayAvatarAppearance.fromProfile(SaveSystem.loadProfile())
    }

    static func refresh(from appearance: GameplayAvatarAppearance) {
        current = appearance
    }
}

/// Builds SceneKit player avatars from system-scan skin config and optional creator-card mesh overlay.
enum NexusGameplayAvatarLoader {
    /// Primary player rig for all 3D modes — procedural body with PRQ-driven scale, outfit, and creator trail.
    static func makeAvatarNode(
        name: String,
        position: SCNVector3,
        fallbackTint: UIColor,
        appearance: GameplayAvatarAppearance = NexusGameplayAvatarContext.current
    ) -> SCNNode {
        let config = appearance.skinConfig
        let creator = appearance.resolvedCreatorCard
        let primaryTint = skinToneUIColor(config.skinTone)
        let jointTint = creator.map { UIColor($0.movementSignature.trailColor) } ?? primaryTint.withAlphaComponent(0.85)

        let root = SCNNode()
        root.position = position
        root.name = name

        let hScale = Float(config.heightScale)
        let wScale = Float(config.weightScale)
        let lScale = Float(config.limbLength)

        func limb(radius: CGFloat, height: CGFloat, outfit: Bool = true) -> SCNNode {
            let geo = SCNCapsule(capRadius: radius, height: height)
            let mat = SCNMaterial()
            if outfit {
                applyOutfitMaterial(mat, style: config.outfitStyle, accent: jointTint)
            } else {
                mat.diffuse.contents = primaryTint
                mat.emission.contents = primaryTint.withAlphaComponent(0.15)
            }
            mat.metalness.contents = 0.45
            mat.roughness.contents = 0.35
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.castsShadow = true
            return node
        }

        func joint(radius: CGFloat) -> SCNNode {
            let geo = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            mat.diffuse.contents = jointTint
            mat.emission.contents = jointTint.withAlphaComponent(0.35 + CGFloat(config.trailIntensity) * 0.25)
            mat.metalness.contents = 0.55
            geo.materials = [mat]
            return SCNNode(geometry: geo)
        }

        let head = SCNNode()
        head.position = SCNVector3(0, 1.88 * hScale, 0)
        head.name = "head"
        let headSphere = SCNSphere(radius: CGFloat(0.11 * wScale))
        let headMat = SCNMaterial()
        headMat.diffuse.contents = primaryTint
        headMat.emission.contents = primaryTint.withAlphaComponent(0.12)
        headSphere.materials = [headMat]
        head.geometry = headSphere
        NexusFaceAnimationMapper.addFacialFeatures(to: head)

        let visor = SCNBox(width: 0.16, height: 0.04, length: 0.02, chamferRadius: 0.01)
        let visorMat = SCNMaterial()
        visorMat.diffuse.contents = jointTint
        visorMat.emission.contents = jointTint.withAlphaComponent(0.5)
        visor.materials = [visorMat]
        let visorNode = SCNNode(geometry: visor)
        visorNode.position = SCNVector3(0, 0, 0.1)
        head.addChildNode(visorNode)

        let neck = joint(radius: 0.035)
        neck.position = SCNVector3(0, 1.74 * hScale, 0)
        neck.name = "neck"

        let upperTorso = limb(radius: CGFloat(0.07 * wScale), height: CGFloat(0.35 * hScale))
        upperTorso.position = SCNVector3(0, 1.52 * hScale, 0)
        upperTorso.name = "torso"

        let lowerTorso = limb(radius: CGFloat(0.06 * wScale), height: CGFloat(0.25 * hScale))
        lowerTorso.position = SCNVector3(0, 1.25 * hScale, 0)
        lowerTorso.name = "lowerTorso"

        let shoulderL = joint(radius: 0.04)
        shoulderL.position = SCNVector3(-0.22 * wScale, 1.62 * hScale, 0)
        let shoulderR = joint(radius: 0.04)
        shoulderR.position = SCNVector3(0.22 * wScale, 1.62 * hScale, 0)

        let lArm = limb(radius: 0.03, height: CGFloat(0.32 * lScale))
        lArm.position = SCNVector3(-0.22 * wScale, 1.45 * hScale, 0)
        lArm.eulerAngles.z = 0.35
        lArm.name = "lArm"

        let rArm = limb(radius: 0.03, height: CGFloat(0.32 * lScale))
        rArm.position = SCNVector3(0.22 * wScale, 1.45 * hScale, 0)
        rArm.eulerAngles.z = -0.35
        rArm.name = "rArm"

        let hip = joint(radius: CGFloat(0.055 * wScale))
        hip.position = SCNVector3(0, 1.08 * hScale, 0)
        hip.name = "hip"

        let lLeg = limb(radius: 0.04, height: CGFloat(0.42 * lScale))
        lLeg.position = SCNVector3(-0.09 * wScale, 0.82 * hScale, 0)
        lLeg.name = "lLeg"

        let rLeg = limb(radius: 0.04, height: CGFloat(0.42 * lScale))
        rLeg.position = SCNVector3(0.09 * wScale, 0.82 * hScale, 0)
        rLeg.name = "rLeg"

        let lShin = limb(radius: 0.035, height: CGFloat(0.38 * lScale), outfit: false)
        lShin.position = SCNVector3(-0.09 * wScale, 0.36 * hScale, 0)
        lShin.name = "lShin"

        let rShin = limb(radius: 0.035, height: CGFloat(0.38 * lScale), outfit: false)
        rShin.position = SCNVector3(0.09 * wScale, 0.36 * hScale, 0)
        rShin.name = "rShin"

        for node in [head, neck, upperTorso, lowerTorso, shoulderL, shoulderR, lArm, rArm, hip, lLeg, rLeg, lShin, rShin] {
            root.addChildNode(node)
        }

        if config.trailIntensity > 0.08 {
            let auraColor = UIColor(
                red: CGFloat(config.auraColorR),
                green: CGFloat(config.auraColorG),
                blue: CGFloat(config.auraColorB),
                alpha: 1
            )
            let ring = SCNTorus(ringRadius: CGFloat(0.26 * wScale), pipeRadius: 0.008)
            let auraMat = SCNMaterial()
            auraMat.diffuse.contents = auraColor.withAlphaComponent(0.15)
            auraMat.emission.contents = auraColor.withAlphaComponent(CGFloat(config.trailIntensity * 0.7))
            ring.materials = [auraMat]
            let auraNode = SCNNode(geometry: ring)
            auraNode.position = SCNVector3(0, 1.2 * hScale, 0)
            auraNode.eulerAngles.x = .pi / 2
            auraNode.name = "aura"
            root.addChildNode(auraNode)
        }

        attachCreatorMeshOverlay(to: root, creator: creator, fallbackTint: fallbackTint)

        let glow = SCNNode()
        glow.light = SCNLight()
        glow.light?.type = .omni
        glow.light?.color = jointTint.withAlphaComponent(0.45)
        glow.light?.intensity = 40
        glow.position = SCNVector3(0, 1.3 * hScale, 0)
        root.addChildNode(glow)

        let breatheUp = SCNAction.moveBy(x: 0, y: 0.02, z: 0, duration: 1.6)
        breatheUp.timingMode = .easeInEaseOut
        let breatheDown = SCNAction.moveBy(x: 0, y: -0.02, z: 0, duration: 1.6)
        breatheDown.timingMode = .easeInEaseOut
        root.runAction(SCNAction.repeatForever(SCNAction.sequence([breatheUp, breatheDown])), forKey: "breathe")

        return root
    }

    static func mergeCreatorCardVisuals(_ card: CreatorCard, into config: AvatarSkinConfig) -> AvatarSkinConfig {
        var merged = config
        merged.outfitStyle = AvatarOutfitStyle.fromCreatorOutfitId(card.metricsBoost.currentOutfit)
        merged.trailIntensity = max(config.trailIntensity, card.movementSignature.limbEmission)
        let uiColor = UIColor(card.movementSignature.trailColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        merged.auraColorR = Double(r)
        merged.auraColorG = Double(g)
        merged.auraColorB = Double(b)
        return merged
    }

    private static func attachCreatorMeshOverlay(to root: SCNNode, creator: CreatorCard?, fallbackTint: UIColor) {
        guard let creator else { return }
        if let meshId = creator.meshAssetId,
           NexusBundledMeshLoader.isMeshLoadable(assetId: meshId),
           let overlay = NexusBundledMeshLoader.loadNode(
               assetId: meshId,
               nodeName: "creatorMeshOverlay",
               position: SCNVector3(0, 1.35, 0),
               scale: SCNVector3(0.18, 0.18, 0.18)
           ) {
            overlay.renderingOrder = 10
            root.addChildNode(overlay)
            return
        }
        if creator.usesCatalogPlaceholderPreview {
            let badge = SCNBox(width: 0.14, height: 0.04, length: 0.02, chamferRadius: 0.008)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(creator.accentColor)
            mat.emission.contents = UIColor(creator.accentColor).withAlphaComponent(0.35)
            badge.materials = [mat]
            let badgeNode = SCNNode(geometry: badge)
            badgeNode.position = SCNVector3(0, 2.05, 0.08)
            badgeNode.name = "creatorBadge"
            root.addChildNode(badgeNode)
        }
        _ = fallbackTint
    }

    private static func applyOutfitMaterial(_ mat: SCNMaterial, style: AvatarOutfitStyle, accent: UIColor) {
        switch style {
        case .standard:
            mat.diffuse.contents = UIColor.darkGray
        case .developing:
            mat.diffuse.contents = UIColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1)
            mat.emission.contents = accent.withAlphaComponent(0.15)
        case .flight:
            mat.diffuse.contents = UIColor(red: 0.0, green: 0.6, blue: 0.8, alpha: 1)
            mat.emission.contents = accent.withAlphaComponent(0.2)
        case .elite:
            mat.diffuse.contents = UIColor(red: 0.4, green: 0.1, blue: 0.7, alpha: 1)
            mat.metalness.contents = 0.75
        case .neon:
            mat.diffuse.contents = UIColor.black
            mat.emission.contents = accent.withAlphaComponent(0.55)
        case .shadow:
            mat.diffuse.contents = UIColor(white: 0.06, alpha: 1)
            mat.emission.contents = accent.withAlphaComponent(0.12)
        case .chrome:
            mat.diffuse.contents = UIColor(white: 0.9, alpha: 1)
            mat.metalness.contents = 1.0
            mat.roughness.contents = 0.05
        case .gold:
            mat.diffuse.contents = UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
            mat.metalness.contents = 0.85
        }
    }

    private static func skinToneUIColor(_ tone: AvatarSkinTone) -> UIColor {
        switch tone {
        case .cyan: return UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)
        case .blue: return UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1)
        case .green: return UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1)
        case .elitePurple: return UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1)
        case .orange: return UIColor.orange
        }
    }
}

extension AvatarOutfitStyle {
    static func fromCreatorOutfitId(_ id: String) -> AvatarOutfitStyle {
        switch id {
        case "coach_v", "directors_cut": return .elite
        case "bonds_bounce", "chris_staples", "bald_barbie": return .gold
        case "flight_lab", "tyler_currie", "amir_smith": return .flight
        case "neural_max", "method_acting": return .neon
        case "action_sequence", "andrew_mcfly", "ty2_skills": return .shadow
        case "baller_bree": return .chrome
        default: return .developing
        }
    }
}
