import SwiftUI
import SceneKit
import MetalKit

/// One-shot opponent (fighter2) animation event, driven from GamePlayView's
/// local opponent AI through the nonce bridge.
enum KarateOpponentEvent: Equatable, Sendable {
    case telegraph(duration: Double)
    case strike(FELBundledAsset)
    case `guard`(duration: Double)
    case stagger
}

public enum ScenicCameraAngle: String, CaseIterable, Codable, Sendable {
    case chase = "Chase Cam"
    case broadcast = "Broadcast Cam"
    case actionCloseUp = "Action Close-up"
    case cinematicPan = "Cinematic Pan"

    /// Baseline scenic angle per production mode — event cuts still override temporarily.
    static func defaultForMode(_ mode: GameModeId) -> ScenicCameraAngle {
        switch mode {
        case .basketballDunkContest3D, .karate:
            return .actionCloseUp
        case .basketball3v3, .football, .soccer, .volleyball, .tennis, .karateEndless:
            return .broadcast
        case .golf, .courtCarnival, .whoSceneIt:
            return .cinematicPan
        default:
            return .chase
        }
    }
}

/// Hosts Metal venue backdrop + transparent SceneKit gameplay overlay when bundled mesh is available.
final class NexusHybridGameplayContainerView: UIView {
    let metalView: MTKView
    let overlayView: SCNView
    /// Fired after Auto Layout assigns bounds so CAMetalLayer drawableSize is valid before first draw.
    var onMetalViewLaidOut: ((MTKView) -> Void)?

    init(metalView: MTKView, overlayView: SCNView) {
        self.metalView = metalView
        self.overlayView = overlayView
        super.init(frame: .zero)
        metalView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metalView)
        addSubview(overlayView)
        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        accessibilityIdentifier = "GameSceneViewport"
        accessibilityValue = "loading"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onMetalViewLaidOut?(metalView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct GameSceneHostView: UIViewRepresentable {
    /// SceneKit when no bundled venue mesh or explicit opt-out. Metal when compile/env flag set,
    /// or any production mode with bundled `.nexusmesh.json` (see `IOS_RUNBOOK.md` § Metal viewport).
    static func prefersMetalRenderer(for gameMode: GameModeId) -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["NEXUS_USE_SCENEKIT"] == "1" || env["NEXUS_USE_METAL"] == "0" {
            return false
        }
        #if NEXUS_USE_METAL
        return true
        #else
        if env["NEXUS_USE_METAL"] == "1" {
            return true
        }
        guard nexus_metal_bridge_is_linked() else {
            return false
        }
        return gameMode.nexusRuntimeModeId.withCString { modeCStr in
            nexus_metal_bridge_bundled_venue_mesh_loadable(modeCStr)
        }
        #endif
    }

    var gameMode: GameModeId = .basketballHeadToHead
    /// When true, routes through NEXUS 3D engine (hybrid Metal venue + SceneKit player, or full SceneKit rig).
    var useNexus3DEngine: Bool = false
    var neuralDrive: Double = 50
    var scenicCameraAngle: ScenicCameraAngle = .chase
    var onAction: () -> Void = {}
    var onViewportReady: () -> Void = {}
    var leftStickInput: CGPoint = .zero
    var rightStickInput: CGPoint = .zero
    var isMidAir: Bool = false
    var isSpecialMove: Bool = false
    var isSlowMotion: Bool = false
    var avatarAppearance: GameplayAvatarAppearance = .default
    /// One-shot karate strike signal: set `karateStrikeAsset` and bump the
    /// nonce to fire; the coordinator plays the clip once and restores the
    /// fighter. Defaults keep existing call sites compiling unchanged.
    var karateStrikeNonce: Int = 0
    var karateStrikeAsset: FELBundledAsset? = nil

    /// One-shot opponent (fighter2) animation event, nonce-triggered like the
    /// player strike above. Set `karateOpponentEvent` then bump the nonce.
    var karateOpponentEventNonce: Int = 0
    var karateOpponentEvent: KarateOpponentEvent? = nil

    /// One-shot impact hitstop + contact-burst signal (nonce-triggered).
    var karateHitstopNonce: Int = 0
    var karateHitstopCritical: Bool = false

    func makeUIView(context: Context) -> UIView {
        if Nexus3DGameplayCoordinator.shouldUseHybridMetal(for: gameMode, explicit3D: useNexus3DEngine) {
            return context.coordinator.makeHybridView()
        }
        return context.coordinator.makeSceneKitView()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.teardown(view: uiView)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let scnView = context.coordinator.activeSceneKitView else { return }
        context.coordinator.neuralDrive = neuralDrive
        context.coordinator.leftStickInput = leftStickInput
        context.coordinator.rightStickInput = rightStickInput
        if context.coordinator.isMidAir != isMidAir {
            context.coordinator.setDunkClipActive(isMidAir)
        }
        context.coordinator.isMidAir = isMidAir
        if context.coordinator.lastKarateStrikeNonce != karateStrikeNonce {
            context.coordinator.lastKarateStrikeNonce = karateStrikeNonce
            if let asset = karateStrikeAsset {
                context.coordinator.playKarateStrike(asset)
            }
        }
        if context.coordinator.lastOpponentEventNonce != karateOpponentEventNonce {
            context.coordinator.lastOpponentEventNonce = karateOpponentEventNonce
            switch karateOpponentEvent {
            case .telegraph(let dur): context.coordinator.showOpponentTelegraph(duration: dur)
            case .strike(let asset): context.coordinator.playOpponentStrike(asset)
            case .guard(let dur): context.coordinator.playOpponentGuard(duration: dur)
            case .stagger: context.coordinator.playOpponentStagger()
            case .none: break
            }
        }
        if context.coordinator.lastHitstopNonce != karateHitstopNonce {
            context.coordinator.lastHitstopNonce = karateHitstopNonce
            context.coordinator.triggerKarateImpact(critical: karateHitstopCritical)
        }
        context.coordinator.isSpecialMove = isSpecialMove
        context.coordinator.isSlowMotion = isSlowMotion
        context.coordinator.updateAvatarAppearanceIfNeeded(avatarAppearance, in: scnView.scene)
        context.coordinator.applyNeuralDriveTuning(in: scnView.scene)
        context.coordinator.setScenicCameraAngle(scenicCameraAngle)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onAction: onAction, onViewportReady: onViewportReady, gameMode: gameMode, neuralDrive: neuralDrive)
    }

    class Coordinator: NSObject, SCNSceneRendererDelegate, MTKViewDelegate {
        let onAction: () -> Void
        let onViewportReady: () -> Void
        let gameMode: GameModeId
        var neuralDrive: Double
        var usesMetalPath = false
        var usesHybridPath = false
        var metalInitSucceeded = false
        weak var scnView: SCNView?
        weak var hybridContainer: NexusHybridGameplayContainerView?
        weak var mtkView: MTKView?
        weak var tapGesture: UITapGestureRecognizer?
        var metalRendererHandle: NexusMetalRendererHandle?
        private var lastMetalDrawableSize: CGSize = .zero

        /// SceneKit view driving player/camera (full SceneKit path or hybrid overlay).
        var activeSceneKitView: SCNView? {
            if usesHybridPath { return hybridContainer?.overlayView }
            if usesMetalPath { return nil }
            return scnView
        }

        /// Updated by ``SCNSceneRendererDelegate`` — drives camera smoothing at real frame deltas.
        var latestFrameDelta: Float = 1.0 / 60.0
        private var lastRendererTime: CFTimeInterval?

        var leftStickInput: CGPoint = .zero
        var rightStickInput: CGPoint = .zero
        var isMidAir: Bool = false
        var isSpecialMove: Bool = false
        var isSlowMotion: Bool = false
        private var lastAvatarAppearance: GameplayAvatarAppearance = .default
        private var dunkClipNode: SCNNode?
        private var ai3v3: Basketball3v3AIController?
        var lastKarateStrikeNonce: Int = 0
        private var strikeClipNode: SCNNode?
        private var strikeRestoreTask: Task<Void, Never>?

        // Opponent (fighter2) runtime animation state.
        var lastOpponentEventNonce: Int = 0
        private var opponentClipNode: SCNNode?
        private var opponentRestoreTask: Task<Void, Never>?
        private var telegraphGlowNode: SCNNode?
        // Impact hitstop.
        var lastHitstopNonce: Int = 0
        private var hitstopTask: Task<Void, Never>?

        /// Dunk contest: while airborne the dunker swaps to the retargeted
        /// mocap dunk clip (Elijah Bonds model, rim-normalized to the 3.05m
        /// hoop); the running-loop character returns on landing.
        func setDunkClipActive(_ active: Bool) {
            guard gameMode == .basketballDunkContest3D,
                  let scene = activeSceneKitView?.scene,
                  let dunker = scene.rootNode.childNode(withName: "dunker", recursively: false) else {
                return
            }
            if active {
                guard dunkClipNode == nil,
                      let clip = FELBundledAssets.characterNode(.elijahDunk, height: 1.85) else { return }
                clip.name = "dunkerClip"
                clip.position = dunker.position
                clip.eulerAngles = dunker.eulerAngles
                (dunker.parent ?? scene.rootNode).addChildNode(clip)
                dunker.isHidden = true
                dunkClipNode = clip
                startDunkCinematic()          // begin approach beat
            } else {
                dunkClipNode?.removeFromParentNode()
                dunkClipNode = nil
                dunker.isHidden = false
                setDunkClipTimeScale(1.0)
                // Clip cleared = the dunk has landed; play land -> restore even
                // if approach/apex hadn't finished (short dunks still get a beat).
                if dunkCinePhase != .inactive {
                    advanceDunkCine(to: .land)
                }
            }
        }

        // MARK: - Dunk cinematic helpers

        /// Time-dilate ONLY the baked dunk-clip animation (not the whole scene
        /// clock — that would slow crowd/judges/particles too). No-op if the
        /// clip has no animation players (procedural fallback avatar).
        private func setDunkClipTimeScale(_ scale: CGFloat) {
            guard let clip = dunkClipNode else { return }
            clip.enumerateHierarchy { node, _ in
                for key in node.animationKeys {
                    node.animationPlayer(forKey: key)?.speed = scale
                }
            }
        }

        private func advanceDunkCine(to phase: DunkCinePhase) {
            dunkCinePhase = phase
            dunkCineElapsed = 0
        }

        private func startDunkCinematic() {
            guard gameMode == .basketballDunkContest3D else { return }
            dunkCineOrbit = .pi * 0.15   // start slightly off-axis for a 3/4 hero look
            dunkCineTimeScale = 1.0
            advanceDunkCine(to: .approach)
        }

        private func endDunkCinematic() {
            dunkCinePhase = .inactive
            dunkCineTimeScale = 1.0
            setDunkClipTimeScale(1.0)
        }

        private func resolveDunkRimTarget(in scene: SCNScene) -> SCNVector3 {
            if let hoop = scene.rootNode.childNode(withName: "hoop", recursively: true) {
                return hoop.presentation.position
            }
            return dunkRimFallback
        }

        /// Drives the cinematic camera during a dunk. Returns true if it owns
        /// the frame (caller skips the normal chase switch). Writes desired
        /// pos/lookAt/FOV that the shared smoothing tail then consumes.
        private func computeDunkCinematic(
            in scene: SCNScene,
            delta: Float,
            desiredCamPos: inout SCNVector3,
            desiredLookAt: inout SCNVector3,
            targetFOV: inout CGFloat,
            followSpeedMult: inout Float,
            targetSpeedMult: inout Float
        ) -> Bool {
            guard gameMode == .basketballDunkContest3D, dunkCinePhase != .inactive else { return false }
            let trackedName = dunkClipNode != nil ? "dunkerClip" : "dunker"
            guard let dunkerNode = scene.rootNode.childNode(withName: trackedName, recursively: true) else {
                endDunkCinematic()
                return false   // fall through to normal chase; never freeze
            }
            let p = dunkerNode.presentation.position
            let r = resolveDunkRimTarget(in: scene)

            dunkCineElapsed += delta            // wall-clock phase timing (real)
            let cineDelta = delta * dunkCineTimeScale

            switch dunkCinePhase {
            case .approach:
                dunkCineTimeScale = 1.0
                setDunkClipTimeScale(1.0)
                desiredCamPos = SCNVector3(p.x + 1.6, p.y + 1.3, p.z + 3.2)
                desiredLookAt = lerpVec3(SCNVector3(p.x, p.y + 1.4, p.z), r, t: 0.35)
                targetFOV = 34
                followSpeedMult = 2.2; targetSpeedMult = 2.4
                if dunkCineElapsed >= dunkApproachDur { advanceDunkCine(to: .apex) }

            case .apex:
                dunkCineTimeScale = 0.3
                setDunkClipTimeScale(0.3)
                let m = lerpVec3(p, r, t: 0.5)
                dunkCineOrbit += cineDelta * 0.75
                let radius: Float = 3.4
                desiredCamPos = SCNVector3(
                    m.x + radius * sin(dunkCineOrbit),
                    m.y + 2.2,
                    m.z + radius * cos(dunkCineOrbit)
                )
                desiredLookAt = m
                let e = min(1, dunkCineElapsed / dunkApexDur)
                targetFOV = 28 - CGFloat(e) * 4     // 28 -> 24
                followSpeedMult = 3.5; targetSpeedMult = 3.5
                if dunkCineElapsed >= dunkApexDur { advanceDunkCine(to: .land) }

            case .land:
                let ramp = min(1, dunkCineElapsed / 0.15)
                dunkCineTimeScale = 0.3 + 0.7 * ramp
                setDunkClipTimeScale(CGFloat(dunkCineTimeScale))
                desiredCamPos = SCNVector3(p.x + 0.8, p.y + 2.4, p.z + 4.4)
                desiredLookAt = SCNVector3(p.x, p.y + 1.2, p.z)
                targetFOV = 40
                if cameraShakeIntensity < 0.55 { cameraShakeIntensity = 0.6 }
                followSpeedMult = 2.2; targetSpeedMult = 2.2
                if dunkCineElapsed >= dunkLandDur { advanceDunkCine(to: .restore) }

            case .restore:
                dunkCineTimeScale = 1.0
                setDunkClipTimeScale(1.0)
                let cfg = cameraConfig
                desiredCamPos = SCNVector3(p.x + cfg.offsetX, p.y + cfg.offsetY, p.z + cfg.offsetZ)
                desiredLookAt = SCNVector3(p.x, p.y + cfg.lookAtY, p.z)
                targetFOV = cfg.fovNormal
                followSpeedMult = 1.4; targetSpeedMult = 1.6
                if dunkCineElapsed >= dunkRestoreDur { endDunkCinematic() }

            case .inactive:
                return false
            }
            return true
        }

        /// Karate strike one-shot: swaps "fighter1" for the requested Meshy
        /// preset strike clip (Elijah Bonds model, joint-normalized) and
        /// schedules restore after the clip's baked animation finishes.
        /// Mirrors ``setDunkClipActive(_:)`` — the clip node is loaded fresh
        /// (never cloned; SCNSkinner nodes must not be cloned) and inserted
        /// at the fighter's position/orientation.
        func playKarateStrike(_ asset: FELBundledAsset) {
            guard gameMode == .karate || gameMode == .karateEndless,
                  let scene = activeSceneKitView?.scene,
                  let fighter = scene.rootNode.childNode(withName: "fighter1", recursively: true) else {
                return
            }
            // Overlapping strike — tear down the active clip before starting.
            if let existing = strikeClipNode {
                strikeRestoreTask?.cancel()
                strikeRestoreTask = nil
                existing.removeFromParentNode()
                strikeClipNode = nil
            }
            guard let clip = FELBundledAssets.characterNode(asset, height: 1.75) else { return }
            clip.name = "fighter1StrikeClip"
            clip.position = fighter.position
            clip.eulerAngles = fighter.eulerAngles
            (fighter.parent ?? scene.rootNode).addChildNode(clip)
            fighter.isHidden = true
            strikeClipNode = clip

            // Restore after the baked clip's duration (longest animation
            // player anywhere in the loaded hierarchy; 1.2s fallback).
            var clipDuration: Double = 0
            clip.enumerateHierarchy { node, _ in
                for key in node.animationKeys {
                    if let player = node.animationPlayer(forKey: key) {
                        clipDuration = max(clipDuration, player.animation.duration)
                    }
                }
            }
            if clipDuration <= 0 { clipDuration = 1.2 }

            strikeRestoreTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(clipDuration))
                guard let self, !Task.isCancelled else { return }
                self.strikeClipNode?.removeFromParentNode()
                self.strikeClipNode = nil
                self.strikeRestoreTask = nil
                self.activeSceneKitView?.scene?.rootNode
                    .childNode(withName: "fighter1", recursively: true)?.isHidden = false
            }
        }

        // MARK: - Opponent (fighter2) runtime animation

        /// Opponent attack: swap "fighter2" for a fresh baked strike clip
        /// (never cloned — SCNSkinner nodes must not be cloned), restoring the
        /// base fighter after the clip finishes. Mirrors ``playKarateStrike``.
        func playOpponentStrike(_ asset: FELBundledAsset) {
            guard gameMode == .karate || gameMode == .karateEndless,
                  let scene = activeSceneKitView?.scene,
                  let fighter = scene.rootNode.childNode(withName: "fighter2", recursively: true) else {
                return
            }
            removeTelegraphGlow()
            teardownOpponentClip()
            guard let clip = FELBundledAssets.characterNode(asset, height: 1.75) else { return }
            clip.name = "fighter2StrikeClip"
            clip.position = fighter.position
            clip.eulerAngles = fighter.eulerAngles
            (fighter.parent ?? scene.rootNode).addChildNode(clip)
            fighter.isHidden = true
            opponentClipNode = clip

            var clipDuration: Double = 0
            clip.enumerateHierarchy { node, _ in
                for key in node.animationKeys {
                    if let player = node.animationPlayer(forKey: key) {
                        clipDuration = max(clipDuration, player.animation.duration)
                    }
                }
            }
            if clipDuration <= 0 { clipDuration = 0.8 }
            scheduleOpponentRestore(after: clipDuration)
        }

        /// Opponent guard: hold the ElijahGuard pose for `duration`.
        func playOpponentGuard(duration: Double) {
            guard gameMode == .karate || gameMode == .karateEndless,
                  let scene = activeSceneKitView?.scene,
                  let fighter = scene.rootNode.childNode(withName: "fighter2", recursively: true),
                  let clip = FELBundledAssets.characterNode(.elijahGuard, height: 1.75) else {
                return
            }
            removeTelegraphGlow()
            teardownOpponentClip()
            clip.name = "fighter2GuardClip"
            clip.position = fighter.position
            clip.eulerAngles = fighter.eulerAngles
            (fighter.parent ?? scene.rootNode).addChildNode(clip)
            fighter.isHidden = true
            opponentClipNode = clip
            scheduleOpponentRestore(after: max(0.35, duration))
        }

        /// Opponent stagger: quick backward knockback + twist on the live
        /// fighter node (no clip clone), then settle.
        func playOpponentStagger() {
            guard let scene = activeSceneKitView?.scene,
                  let fighter = scene.rootNode.childNode(withName: "fighter2", recursively: true) else {
                return
            }
            removeTelegraphGlow()
            teardownOpponentClip()   // if mid-attack, drop the clip and show base
            // Knock back along +X (away from the player at -X).
            let knock = SCNAction.sequence([
                SCNAction.moveBy(x: 0.35, y: 0, z: 0, duration: 0.09),
                SCNAction.moveBy(x: -0.2, y: 0, z: 0, duration: 0.22)
            ])
            knock.timingMode = .easeOut
            fighter.runAction(knock, forKey: "stagger")
            let baseYaw = fighter.eulerAngles.y
            let twist = SCNAction.sequence([
                SCNAction.rotateTo(x: 0, y: CGFloat(baseYaw) + 0.18, z: -0.14, duration: 0.09),
                SCNAction.rotateTo(x: 0, y: CGFloat(baseYaw), z: 0, duration: 0.26)
            ])
            fighter.runAction(twist, forKey: "staggerTwist")
        }

        /// Telegraph glow: a brief pulsing halo at the opponent so an incoming
        /// attack is readable (fair blocking).
        func showOpponentTelegraph(duration: Double) {
            guard let scene = activeSceneKitView?.scene,
                  let fighter = scene.rootNode.childNode(withName: "fighter2", recursively: true) else {
                return
            }
            removeTelegraphGlow()
            let glow = SCNNode(geometry: SCNSphere(radius: 0.55))
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.clear
            mat.emission.contents = UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 1)
            mat.blendMode = .add
            mat.writesToDepthBuffer = false
            mat.lightingModel = .constant
            glow.geometry?.materials = [mat]
            glow.opacity = 0.0
            glow.name = "oppTelegraphGlow"
            glow.position = SCNVector3(fighter.position.x, 1.2, fighter.position.z)
            scene.rootNode.addChildNode(glow)
            telegraphGlowNode = glow
            glow.runAction(.sequence([
                .group([.fadeOpacity(to: 0.6, duration: duration * 0.5),
                        .scale(to: 1.25, duration: duration * 0.5)]),
                .fadeOut(duration: duration * 0.5)
            ]))
        }

        private func removeTelegraphGlow() {
            telegraphGlowNode?.removeFromParentNode()
            telegraphGlowNode = nil
        }

        private func teardownOpponentClip() {
            opponentRestoreTask?.cancel()
            opponentRestoreTask = nil
            opponentClipNode?.removeFromParentNode()
            opponentClipNode = nil
            activeSceneKitView?.scene?.rootNode
                .childNode(withName: "fighter2", recursively: true)?.isHidden = false
        }

        private func scheduleOpponentRestore(after duration: Double) {
            opponentRestoreTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard let self, !Task.isCancelled else { return }
                self.opponentClipNode?.removeFromParentNode()
                self.opponentClipNode = nil
                self.opponentRestoreTask = nil
                self.activeSceneKitView?.scene?.rootNode
                    .childNode(withName: "fighter2", recursively: true)?.isHidden = false
            }
        }

        // MARK: - Impact hitstop + VFX

        /// Freeze the active strike/opponent clips for a beat to sell impact,
        /// spawn a contact burst at mid-ring, then resume. `critical` deepens
        /// the freeze and the burst.
        func triggerKarateImpact(critical: Bool) {
            guard let scene = activeSceneKitView?.scene else { return }
            // Contact burst between the fighters, chest height.
            let f1x = scene.rootNode.childNode(withName: "fighter1", recursively: true)?.position.x ?? -1.2
            let f2x = scene.rootNode.childNode(withName: "fighter2", recursively: true)?.position.x ?? 1.2
            let midX = (f1x + f2x) / 2
            KarateImpactVFX.burst(in: scene, at: SCNVector3(midX, 1.2, 0), critical: critical)

            // Hitstop: pause the strike/opponent clip animations briefly.
            hitstopTask?.cancel()
            let clips = [strikeClipNode, opponentClipNode].compactMap { $0 }
            guard !clips.isEmpty else { return }
            for clip in clips { setAnimationSpeed(0.0, on: clip) }
            let freeze: Double = critical ? 0.12 : 0.06
            hitstopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(freeze))
                guard let self, !Task.isCancelled else { return }
                for clip in clips { self.setAnimationSpeed(1.0, on: clip) }
                self.hitstopTask = nil
            }
        }

        private func setAnimationSpeed(_ speed: CGFloat, on node: SCNNode) {
            node.enumerateHierarchy { n, _ in
                for key in n.animationKeys {
                    n.animationPlayer(forKey: key)?.speed = speed
                }
            }
        }

        var currentScenicCameraAngle: ScenicCameraAngle = .chase
        private var temporaryCameraAngleOverride: ScenicCameraAngle? = nil
        private var overrideTimerTask: Task<Void, Never>? = nil
        private var orbitAngle: Float = 0.0
        private var jumpProgress: Float = 0.0

        private var smoothedCameraPosition = SCNVector3(0, 4, 8)
        private var smoothedCameraTarget = SCNVector3(0, 1.2, 0)
        private var cameraShakeIntensity: Float = 0

        // MARK: Dunk cinematic camera (approach -> apex slow-mo -> land -> restore)
        private enum DunkCinePhase { case inactive, approach, apex, land, restore }
        private var dunkCinePhase: DunkCinePhase = .inactive
        private var dunkCineElapsed: Float = 0        // seconds within current phase
        private var dunkCineTimeScale: Float = 1.0    // 1.0 normal, 0.3 at apex
        private var dunkCineOrbit: Float = 0          // apex hero-orbit angle
        // Fail-soft rim target derived from addHoop(x:-4.5, flip:true): rim at
        // x - dir*0.65 = -4.5 - (-1)*0.65 = -3.85, y=3.05.
        private let dunkRimFallback = SCNVector3(-3.85, 3.05, 0)
        private let dunkApproachDur: Float = 0.8
        private let dunkApexDur: Float = 0.6
        private let dunkLandDur: Float = 0.4
        private let dunkRestoreDur: Float = 0.6
        private var cinematicZoomOffset: Float = 0
        private var cinematicHeightOffset: Float = 0
        private var cinematicAngleOffset: Float = 0
        private var lastCinematicState: CinematicState = .normal
        private var cinematicTransitionProgress: Float = 0
        private var playerVelocity: SCNVector3 = SCNVector3(0, 0, 0)
        private var lastPlayerY: Float = 0
        private var renderedFrameCount = 0
        private var didReportViewportReady = false
        private var scenicCameraAngle: ScenicCameraAngle = .chase

        private enum CinematicState: Equatable {
            case normal
            case midAir
            case specialMove
            case landing
        }

        private var playerNodeName: String {
            GameSceneFactory.primaryGameplayAvatarName(for: gameMode)
        }

        /// H2H dunk — temporarily tracks opponent during AI turn scenic cuts.
        private var avatarFocusOverride: String?
        private var opponentFocusTimerTask: Task<Void, Never>?

        private var trackedAvatarName: String {
            avatarFocusOverride ?? playerNodeName
        }

        func updateAvatarAppearanceIfNeeded(_ appearance: GameplayAvatarAppearance, in scene: SCNScene?) {
            guard appearance != lastAvatarAppearance else { return }
            lastAvatarAppearance = appearance
            GameSceneFactory.replacePrimaryAvatar(
                in: scene,
                for: gameMode,
                fallbackTint: UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1),
                appearance: appearance
            )
        }

        private var cameraConfig: CameraFollowConfig {
            let premium = PremiumViewpointConfig.chaseCamera(for: gameMode)
            return CameraFollowConfig(
                offsetX: premium.offsetX,
                offsetY: premium.offsetY,
                offsetZ: premium.offsetZ,
                lookAtY: premium.lookAtY,
                followSpeed: premium.followSpeed,
                targetSpeed: premium.targetSpeed,
                fovNormal: premium.fovNormal,
                fovAction: premium.fovAction
            )
        }

        private var movementBounds: MovementBounds {
            switch gameMode {
            case .basketballHeadToHead, .venicePickup:
                return MovementBounds(minX: -3.8, maxX: 3.8, minZ: -2.5, maxZ: 2.5, speed: 0.12)
            case .marketBrowse:
                return MovementBounds(minX: -2.6, maxX: 2.6, minZ: -2.8, maxZ: 2.4, speed: 0.08)
            case .basketballDunkContest3D, .basketballDunkContestIRL:
                return MovementBounds(minX: -5.0, maxX: 4.0, minZ: -3.5, maxZ: 3.5, speed: 0.14)
            case .basketball3v3:
                return MovementBounds(minX: -4.5, maxX: 4.5, minZ: -2.8, maxZ: 2.8, speed: 0.12)
            case .karate, .karateEndless:
                return MovementBounds(minX: -2.5, maxX: 2.5, minZ: -2.5, maxZ: 2.5, speed: 0.10)
            case .football:
                return MovementBounds(minX: -4.0, maxX: 4.0, minZ: -12.0, maxZ: 12.0, speed: 0.16)
            case .soccer:
                return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -2.0, maxZ: 2.0, speed: 0.08)
            case .baseball:
                return MovementBounds(minX: -1.0, maxX: 1.0, minZ: -0.5, maxZ: 0.5, speed: 0.04)
            case .golf:
                return MovementBounds(minX: -1.0, maxX: 1.0, minZ: -0.5, maxZ: 0.5, speed: 0.03)
            case .tennis:
                return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -2.0, maxZ: 2.0, speed: 0.10)
            case .volleyball:
                return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -1.5, maxZ: 1.5, speed: 0.09)
            case .gymnastics:
                return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -2.0, maxZ: 2.0, speed: 0.08)
            case .surfing:
                return MovementBounds(minX: -3.5, maxX: 3.5, minZ: -2.8, maxZ: 2.8, speed: 0.095)
            case .skateboarding:
                return MovementBounds(minX: -3.2, maxX: 3.2, minZ: -2.4, maxZ: 2.4, speed: 0.11)
            case .snowboarding:
                return MovementBounds(minX: -3.8, maxX: 3.8, minZ: -3.2, maxZ: 3.2, speed: 0.09)
            case .brainBrawl, .whoSceneIt:
                return MovementBounds(minX: -2.4, maxX: 2.4, minZ: -1.6, maxZ: 1.6, speed: 0.055)
            case .courtCarnival:
                return MovementBounds(minX: -4.5, maxX: 4.5, minZ: -2.8, maxZ: 2.8, speed: 0.12)
            }
        }

        func makeSceneKitView() -> SCNView {
            usesMetalPath = false
            let scnView = SCNView()
            let scene = GameSceneFactory.buildScene(for: gameMode)
            GameSceneFactory.warmSceneForDisplay(scene)
            scnView.scene = scene
            scnView.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
            scnView.autoenablesDefaultLighting = true
            scnView.allowsCameraControl = false
            scnView.antialiasingMode = FELViewportRefreshPolicy.sceneKitAntialiasing
            scnView.isPlaying = true
            scnView.rendersContinuously = true
            if let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
                scnView.pointOfView = cameraNode
            } else if let fallbackCamera = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
                scnView.pointOfView = fallbackCamera
            }
            scnView.accessibilityIdentifier = "GameSceneViewport"
            scnView.accessibilityValue = "loading"
            scnView.preferredFramesPerSecond = FELViewportRefreshPolicy.sceneKitTargetFPS
            scnView.showsStatistics = false

            let tap = UITapGestureRecognizer(target: self, action: #selector(Coordinator.handleTap(_:)))
            scnView.addGestureRecognizer(tap)
            tapGesture = tap
            scnView.delegate = self

            self.scnView = scnView
            applyNeuralDriveTuning(in: scnView.scene)
            syncInitialCameraToPlayer(in: scnView.scene)
            startCameraFollowLoop()
            startPlayerMovementLoop()
            startAI3v3Loop()
            applyPerformanceTier(FELPerformanceMonitor.shared.currentTier)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.reportViewportReadyIfNeeded()
            }

            return scnView
        }

        func makeHybridView() -> NexusHybridGameplayContainerView {
            usesMetalPath = true
            usesHybridPath = true
            metalInitSucceeded = false

            let metalView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
            metalView.delegate = self
            metalView.isPaused = false
            metalView.enableSetNeedsDisplay = false
            metalView.preferredFramesPerSecond = FELViewportRefreshPolicy.metalTargetFPS
            metalView.colorPixelFormat = .bgra8Unorm
            metalView.framebufferOnly = true
            metalView.autoResizeDrawable = true
            metalView.isOpaque = true
            metalView.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
            metalView.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
            Self.configureMetalLayer(for: metalView)
            mtkView = metalView

            if nexus_metal_bridge_is_linked() {
                metalRendererHandle = nexus_metal_renderer_create()
                if let handle = metalRendererHandle {
                    gameMode.nexusRuntimeModeId.withCString { modeCStr in
                        nexus_metal_renderer_set_mode_id(handle, modeCStr)
                    }
                    nexus_metal_renderer_set_orbit_rate(handle, 0)
                }
            }

            let overlay = SCNView()
            let scene = GameSceneFactory.buildGameplayOverlay(for: gameMode)
            GameSceneFactory.warmSceneForDisplay(scene)
            scene.background.contents = UIColor.clear
            overlay.scene = scene
            overlay.backgroundColor = .clear
            overlay.isOpaque = false
            overlay.layer.isOpaque = false
            overlay.autoenablesDefaultLighting = true
            overlay.allowsCameraControl = false
            overlay.antialiasingMode = FELViewportRefreshPolicy.sceneKitAntialiasing
            overlay.isPlaying = true
            overlay.rendersContinuously = true
            if let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
                overlay.pointOfView = cameraNode
            }
            overlay.preferredFramesPerSecond = FELViewportRefreshPolicy.sceneKitTargetFPS
            overlay.delegate = self

            let tap = UITapGestureRecognizer(target: self, action: #selector(Coordinator.handleTap(_:)))
            overlay.addGestureRecognizer(tap)
            tapGesture = tap

            scnView = overlay
            let container = NexusHybridGameplayContainerView(metalView: metalView, overlayView: overlay)
            container.onMetalViewLaidOut = { [weak self] view in
                self?.syncMetalDrawableLayout(for: view)
            }
            hybridContainer = container

            applyNeuralDriveTuning(in: overlay.scene)
            syncInitialCameraToPlayer(in: overlay.scene)
            startCameraFollowLoop()
            startPlayerMovementLoop()
            startAI3v3Loop()
            applyPerformanceTier(FELPerformanceMonitor.shared.currentTier)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.reportViewportReadyIfNeeded()
            }

            return container
        }

        func makeMetalView() -> MTKView {
            usesMetalPath = true
            metalInitSucceeded = false
            let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
            view.delegate = self
            view.isPaused = false
            view.enableSetNeedsDisplay = false
            view.preferredFramesPerSecond = FELViewportRefreshPolicy.metalTargetFPS
            view.colorPixelFormat = .bgra8Unorm
            view.framebufferOnly = true
            view.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
            view.accessibilityIdentifier = "GameSceneViewport"
            view.accessibilityValue = "loading"
            mtkView = view

            if nexus_metal_bridge_is_linked() {
                metalRendererHandle = nexus_metal_renderer_create()
                if let handle = metalRendererHandle {
                    gameMode.nexusRuntimeModeId.withCString { modeCStr in
                        nexus_metal_renderer_set_mode_id(handle, modeCStr)
                    }
                }
            }

            return view
        }

        private static func configureMetalLayer(for view: MTKView) {
            guard let layer = view.layer as? CAMetalLayer else { return }
            layer.pixelFormat = .bgra8Unorm
            layer.framebufferOnly = true
            layer.contentsScale = view.contentScaleFactor
            syncMetalDrawableSize(for: view)
        }

        private static func syncMetalDrawableSize(for view: MTKView) {
            guard let layer = view.layer as? CAMetalLayer else { return }
            let scale = view.contentScaleFactor
            let width = max(view.bounds.width * scale, 1)
            let height = max(view.bounds.height * scale, 1)
            guard width > 1, height > 1 else { return }
            layer.drawableSize = CGSize(width: width, height: height)
        }

        private func syncMetalDrawableLayout(for view: MTKView) {
            Self.configureMetalLayer(for: view)
            guard usesMetalPath, let handle = metalRendererHandle else { return }
            let size = view.drawableSize
            guard size.width > 1, size.height > 1 else { return }
            if metalInitSucceeded, size == lastMetalDrawableSize { return }
            if metalInitSucceeded {
                nexus_metal_renderer_shutdown(handle)
                metalInitSucceeded = false
            }
            lastMetalDrawableSize = size
            guard let layer = view.layer as? CAMetalLayer else { return }
            let width = max(UInt32(size.width.rounded()), 1)
            let height = max(UInt32(size.height.rounded()), 1)
            metalInitSucceeded = nexus_metal_renderer_initialize(handle, layer, width, height)
            if !metalInitSucceeded {
                lastMetalDrawableSize = .zero
            }
        }

        private func ensureMetalRendererInitialized(for view: MTKView) -> Bool {
            guard usesMetalPath, let handle = metalRendererHandle,
                  let layer = view.layer as? CAMetalLayer else { return metalInitSucceeded }
            if metalInitSucceeded { return true }
            Self.syncMetalDrawableSize(for: view)
            let width = max(UInt32(view.drawableSize.width.rounded()), 1)
            let height = max(UInt32(view.drawableSize.height.rounded()), 1)
            guard width > 1, height > 1 else { return false }
            metalInitSucceeded = nexus_metal_renderer_initialize(handle, layer, width, height)
            if metalInitSucceeded {
                lastMetalDrawableSize = view.drawableSize
            }
            return metalInitSucceeded
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            guard usesMetalPath else { return }
            guard size.width > 1, size.height > 1 else { return }
            syncMetalDrawableLayout(for: view)
        }

        func draw(in view: MTKView) {
            guard usesMetalPath, let handle = metalRendererHandle else { return }
            guard ensureMetalRendererInitialized(for: view) else {
                view.accessibilityValue = "metal_init_pending"
                return
            }
            let drew = nexus_metal_renderer_render(handle)
            if drew {
                view.accessibilityValue = "ready"
                hybridContainer?.accessibilityValue = "ready"
                reportViewportReadyIfNeeded()
            } else if let err = nexus_metal_renderer_last_error(handle) {
                view.accessibilityValue = "metal_error:\(String(cString: err))"
            }
        }

        init(onAction: @escaping () -> Void, onViewportReady: @escaping () -> Void, gameMode: GameModeId, neuralDrive: Double) {
            self.onAction = onAction
            self.onViewportReady = onViewportReady
            self.gameMode = gameMode
            self.neuralDrive = neuralDrive
            let config = GameSceneHostView.Coordinator.defaultCameraConfig(for: gameMode)
            self.smoothedCameraPosition = SCNVector3(config.offsetX, config.offsetY, config.offsetZ)
            self.smoothedCameraTarget = SCNVector3(0, config.lookAtY, 0)
            super.init()
            
            // Register event listener for event-triggered camera cuts
            NotificationCenter.default.addObserver(
                forName: .felGameplayScored,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.triggerTemporaryCameraCut(to: .actionCloseUp, duration: 2.0)
                self?.triggerCinematicShake(intensity: 0.5)
            }
            
            NotificationCenter.default.addObserver(
                forName: .felGameplayBuzzIn,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.triggerTemporaryCameraCut(to: .actionCloseUp, duration: 1.5)
            }
            
            NotificationCenter.default.addObserver(
                forName: .felGameplayPenalty,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.triggerTemporaryCameraCut(to: .broadcast, duration: 1.5)
                self?.triggerCinematicShake(intensity: 0.3)
            }
            
            NotificationCenter.default.addObserver(
                forName: .felGameplayKarateBlock,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.triggerTemporaryCameraCut(to: .actionCloseUp, duration: 1.0)
                self?.triggerCinematicShake(intensity: 0.4)
            }
            
            NotificationCenter.default.addObserver(
                forName: .felGameplayWaveCompleted,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.triggerTemporaryCameraCut(to: .cinematicPan, duration: 3.5)
            }

            NotificationCenter.default.addObserver(
                forName: .felGameplayOpponentScored,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.avatarFocusOverride = "opponent"
                self.triggerTemporaryCameraCut(to: .broadcast, duration: 3.5)
                self.triggerCinematicShake(intensity: 0.35)
                self.triggerAvatarAction(named: "opponent")
                self.opponentFocusTimerTask?.cancel()
                self.opponentFocusTimerTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3.5))
                    guard let self, !Task.isCancelled else { return }
                    self.avatarFocusOverride = nil
                }
            }

            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FELPerformanceTierChanged"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                if let rawValue = notification.userInfo?["tier"] as? Int,
                   let tier = FELPerformanceTier(rawValue: rawValue) {
                    self.applyPerformanceTier(tier)
                }
            }
        }

        private static func defaultCameraConfig(for mode: GameModeId) -> CameraFollowConfig {
            let premium = PremiumViewpointConfig.chaseCamera(for: mode)
            return CameraFollowConfig(
                offsetX: premium.offsetX,
                offsetY: premium.offsetY,
                offsetZ: premium.offsetZ,
                lookAtY: premium.lookAtY,
                followSpeed: premium.followSpeed,
                targetSpeed: premium.targetSpeed,
                fovNormal: premium.fovNormal,
                fovAction: premium.fovAction
            )
        }

        func applyPerformanceTier(_ tier: FELPerformanceTier) {
            scnView?.preferredFramesPerSecond = FELViewportRefreshPolicy.sceneKitTargetFPS(for: tier)
            mtkView?.preferredFramesPerSecond = FELViewportRefreshPolicy.metalTargetFPS(for: tier)
            scnView?.antialiasingMode = FELViewportRefreshPolicy.sceneKitAntialiasing(for: tier)

            if let scene = scnView?.scene {
                GameSceneFactory.adjustSceneQuality(scene, for: tier)
            }
        }

        func setScenicCameraAngle(_ angle: ScenicCameraAngle) {
            if currentScenicCameraAngle != angle {
                currentScenicCameraAngle = angle
                cinematicTransitionProgress = 0
            }
        }

        func triggerTemporaryCameraCut(to angle: ScenicCameraAngle, duration: Double) {
            overrideTimerTask?.cancel()
            temporaryCameraAngleOverride = angle
            cinematicTransitionProgress = 0
            
            overrideTimerTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard let self else { return }
                self.temporaryCameraAngleOverride = nil
                self.cinematicTransitionProgress = 0
            }
        }

        func syncInitialCameraToPlayer(in scene: SCNScene?) {
            guard let scene,
                  let camNode = scene.rootNode.childNode(withName: "mainCamera", recursively: false),
                  let playerNode = scene.rootNode.childNode(withName: playerNodeName, recursively: true) else { return }

            let config = cameraConfig
            let playerPos = playerNode.position
            smoothedCameraPosition = SCNVector3(
                playerPos.x + config.offsetX,
                playerPos.y + config.offsetY,
                playerPos.z + config.offsetZ
            )
            smoothedCameraTarget = SCNVector3(
                playerPos.x,
                playerPos.y + config.lookAtY,
                playerPos.z
            )
            camNode.position = smoothedCameraPosition
            camNode.look(at: smoothedCameraTarget)
        }

        func startCameraFollowLoop() {
            guard let scene = activeSceneKitView?.scene else { return }
            let cameraAction = SCNAction.customAction(duration: 100000) { [weak self] _, _ in
                self?.updateCameraFollow()
            }
            scene.rootNode.runAction(SCNAction.repeatForever(cameraAction), forKey: "cameraFollowLoop")
        }

        func startPlayerMovementLoop() {
            guard let scene = activeSceneKitView?.scene else { return }
            let moveAction = SCNAction.customAction(duration: 100000) { [weak self] _, _ in
                self?.updatePlayerMovement()
            }
            scene.rootNode.runAction(SCNAction.repeatForever(moveAction), forKey: "playerMoveLoop")
        }

        /// 3v3: an AI tick drives the five non-player nodes (offense spacing +
        /// cuts, man-mark + help-defense rotation) so they move believably
        /// instead of a static shuffle/homing fight. Player (blue1) stays under
        /// stick control. No-op for other modes.
        func startAI3v3Loop() {
            guard gameMode == .basketball3v3, let scene = activeSceneKitView?.scene else { return }
            let controller = Basketball3v3AIController(
                config: .init(seed: 0xB0A11, offenseSide: .blue, neuralDrive: neuralDrive)
            )
            ai3v3 = controller
            let aiAction = SCNAction.customAction(duration: 100000) { [weak self, weak scene] _, _ in
                guard let self, let scene else { return }
                self.ai3v3?.tick(dt: max(self.latestFrameDelta, 1.0 / 240.0), in: scene)
            }
            scene.rootNode.runAction(SCNAction.repeatForever(aiAction), forKey: "ai3v3Loop")
        }

        private func updateCameraFollow() {
            guard let scene = activeSceneKitView?.scene,
                  let camNode = scene.rootNode.childNode(withName: "mainCamera", recursively: false) else { return }

            let playerNode = scene.rootNode.childNode(withName: trackedAvatarName, recursively: true)
            let playerPos = playerNode?.presentation.position ?? SCNVector3(0, 0, 0)

            let delta = max(latestFrameDelta, 1.0 / 240.0)
            let config = cameraConfig

            let activeAngle = temporaryCameraAngleOverride ?? currentScenicCameraAngle
            
            var desiredCamPos = SCNVector3(0, 0, 0)
            var desiredLookAt = SCNVector3(0, 0, 0)
            var targetFOV: CGFloat = config.fovNormal
            var followSpeedMult: Float = 1.0
            var targetSpeedMult: Float = 1.0

            // Dunk cinematic owns the camera while active (approach/apex/land/
            // restore). It writes the same desired* vars the smoothing tail
            // consumes, so it inherits the exponential ease + shake for free.
            let dunkCineActive = computeDunkCinematic(
                in: scene, delta: delta,
                desiredCamPos: &desiredCamPos, desiredLookAt: &desiredLookAt,
                targetFOV: &targetFOV,
                followSpeedMult: &followSpeedMult, targetSpeedMult: &targetSpeedMult
            )

            if !dunkCineActive {
            switch activeAngle {
            case .chase:
                let currentState = determineCinematicState()
                if currentState != lastCinematicState {
                    cinematicTransitionProgress = 0
                    lastCinematicState = currentState
                }
                cinematicTransitionProgress = min(1.0, cinematicTransitionProgress + delta * 3.0)
                let t = easeInOut(cinematicTransitionProgress)

                var targetZoomOffset: Float = 0
                var targetHeightOffset: Float = 0
                var targetAngleOffset: Float = 0
                targetFOV = config.fovNormal
                followSpeedMult = 1.0
                targetSpeedMult = 1.0

                switch currentState {
                case .midAir:
                    targetZoomOffset = -2.5
                    targetHeightOffset = 1.5
                    targetAngleOffset = -0.3
                    targetFOV = config.fovAction
                    followSpeedMult = 1.8
                    targetSpeedMult = 2.0
                    if cameraShakeIntensity < 0.1 {
                        cameraShakeIntensity = 0.15
                    }
                case .specialMove:
                    targetZoomOffset = -3.5
                    targetHeightOffset = 0.8
                    targetAngleOffset = 0.2
                    targetFOV = config.fovAction - 4
                    followSpeedMult = 2.5
                    targetSpeedMult = 3.0
                    if cameraShakeIntensity < 0.3 {
                        cameraShakeIntensity = 0.4
                    }
                case .landing:
                    targetZoomOffset = -1.0
                    targetHeightOffset = -0.5
                    targetFOV = config.fovNormal + 3
                    followSpeedMult = 1.5
                    targetSpeedMult = 1.5
                    cameraShakeIntensity = max(cameraShakeIntensity, 0.5)
                case .normal:
                    break
                }

                cinematicZoomOffset += (targetZoomOffset - cinematicZoomOffset) * t
                cinematicHeightOffset += (targetHeightOffset - cinematicHeightOffset) * t
                cinematicAngleOffset += (targetAngleOffset - cinematicAngleOffset) * t

                desiredCamPos = SCNVector3(
                    playerPos.x + config.offsetX + cinematicAngleOffset * 3,
                    playerPos.y + config.offsetY + cinematicHeightOffset,
                    playerPos.z + config.offsetZ + cinematicZoomOffset
                )
                desiredLookAt = SCNVector3(
                    playerPos.x,
                    playerPos.y + config.lookAtY + cinematicHeightOffset * 0.4,
                    playerPos.z
                )

            case .broadcast:
                // High wide static angle tracking the action
                desiredCamPos = SCNVector3(
                    playerPos.x * 0.25,
                    playerPos.y + 11.0,
                    playerPos.z + 15.0
                )
                desiredLookAt = SCNVector3(
                    playerPos.x,
                    playerPos.y + config.lookAtY,
                    playerPos.z
                )
                targetFOV = 55.0
                followSpeedMult = 0.8
                targetSpeedMult = 1.2

            case .actionCloseUp:
                // Zoomed-in dramatic angle on the active player
                desiredCamPos = SCNVector3(
                    playerPos.x + config.offsetX * 0.32,
                    playerPos.y + config.offsetY * 0.32 + 1.1,
                    playerPos.z + config.offsetZ * 0.32
                )
                desiredLookAt = SCNVector3(
                    playerPos.x,
                    playerPos.y + config.lookAtY,
                    playerPos.z
                )
                targetFOV = 22.0
                followSpeedMult = 2.0
                targetSpeedMult = 2.2

            case .cinematicPan:
                // Slow orbit around the player / venue
                orbitAngle += delta * 0.22
                let radius: Float = 8.5
                desiredCamPos = SCNVector3(
                    playerPos.x + radius * sin(orbitAngle),
                    playerPos.y + 4.2,
                    playerPos.z + radius * cos(orbitAngle)
                )
                desiredLookAt = SCNVector3(
                    playerPos.x,
                    playerPos.y + config.lookAtY,
                    playerPos.z
                )
                targetFOV = 44.0
                followSpeedMult = 1.6
                targetSpeedMult = 2.0
            }
            } // end if !dunkCineActive

            let cameraLerp = 1.0 - exp(-config.followSpeed * followSpeedMult * delta)
            let targetLerp = 1.0 - exp(-config.targetSpeed * targetSpeedMult * delta)

            smoothedCameraPosition = lerpVec3(smoothedCameraPosition, desiredCamPos, t: cameraLerp)
            smoothedCameraTarget = lerpVec3(smoothedCameraTarget, desiredLookAt, t: targetLerp)

            let shakeAmt = cameraShakeIntensity
            let shakeX = Float.random(in: -0.1...0.1) * shakeAmt
            let shakeY = Float.random(in: -0.08...0.08) * shakeAmt
            let shakeZ = Float.random(in: -0.1...0.1) * shakeAmt

            camNode.position = SCNVector3(
                smoothedCameraPosition.x + shakeX,
                smoothedCameraPosition.y + shakeY,
                smoothedCameraPosition.z + shakeZ
            )
            camNode.look(at: smoothedCameraTarget)

            let fovLerp = 1.0 - exp(Double(-4 * delta))
            let currentFOV = camNode.camera?.fieldOfView ?? config.fovNormal
            camNode.camera?.fieldOfView = currentFOV + (targetFOV - currentFOV) * fovLerp

            if isSlowMotion {
                camNode.camera?.motionBlurIntensity = 0.15
            } else {
                camNode.camera?.motionBlurIntensity = 0
            }

            cameraShakeIntensity = max(0, cameraShakeIntensity - delta * 2.5)
        }

        private func determineCinematicState() -> CinematicState {
            if isSpecialMove { return .specialMove }
            if isMidAir { return .midAir }

            guard let scene = activeSceneKitView?.scene,
                  let playerNode = scene.rootNode.childNode(withName: playerNodeName, recursively: true) else {
                return .normal
            }
            let currentY = playerNode.presentation.position.y
            let wasAirborne = lastPlayerY > 0.3
            let isGrounded = currentY < 0.15

            if wasAirborne && isGrounded {
                lastPlayerY = currentY
                return .landing
            }

            lastPlayerY = currentY

            if currentY > 0.5 { return .midAir }

            return .normal
        }

        /// True if any node in `node`'s hierarchy carries an embedded animation
        /// clip (a skinned Meshy character) — such nodes are alive on their own
        /// and must NOT get the procedural bob idle.
        private func playerHasEmbeddedAnimation(_ node: SCNNode) -> Bool {
            var found = false
            node.enumerateHierarchy { child, stop in
                if !child.animationKeys.isEmpty { found = true; stop.pointee = true }
            }
            return found
        }

        private func updatePlayerMovement() {
            guard let scene = activeSceneKitView?.scene,
                  let playerNode = scene.rootNode.childNode(withName: playerNodeName, recursively: true) else { return }

            let stickX = Float(leftStickInput.x)
            let stickY = Float(leftStickInput.y)
            let magnitude = hypot(stickX, stickY)
            guard magnitude > 0.08 else {
                // Standing still: restore the gentle procedural "alive" idle so
                // the player node breathes instead of freezing (skinned chars
                // keep their embedded loop; this is the no-embedded fallback).
                FELBundledAssets.applyAliveIdle(to: playerNode, force: false,
                                                alreadyAnimated: playerHasEmbeddedAnimation(playerNode))
                animateIdleState(playerNode)
                return
            }
            // Moving: the movement loop owns this node's transform this frame —
            // drop the procedural idle so the bob/sway doesn't fight position writes.
            FELBundledAssets.stopAliveIdle(playerNode)

            let bounds = movementBounds
            let speed = bounds.speed * Float(1.0 + neuralDrive / 200.0)
            let delta = max(latestFrameDelta, 1.0 / 240.0)
            let tickScale = delta * 60.0

            let moveX = stickX * speed * tickScale
            let moveZ = -stickY * speed * tickScale

            var newPos = playerNode.position
            newPos.x = min(bounds.maxX, max(bounds.minX, newPos.x + moveX))
            newPos.z = min(bounds.maxZ, max(bounds.minZ, newPos.z + moveZ))

            playerNode.position = newPos

            let targetAngle = atan2(stickX * speed, -stickY * speed)
            let currentAngle = playerNode.eulerAngles.y
            var angleDiff = targetAngle - currentAngle
            if angleDiff > .pi { angleDiff -= .pi * 2 }
            if angleDiff < -.pi { angleDiff += .pi * 2 }
            playerNode.eulerAngles.y += angleDiff * 0.15 * tickScale

            animateRunState(playerNode, speed: magnitude)

            if let ball = findBallNode(in: scene) {
                let ballOffset = SCNVector3(0, 1.4, 0)
                let targetBallPos = SCNVector3(newPos.x + ballOffset.x, ballOffset.y, newPos.z + ballOffset.z)
                let followT = min(0.35, 0.2 * tickScale)
                ball.position = lerpVec3(ball.position, targetBallPos, t: followT)
            }

            let rightMag = hypot(Float(rightStickInput.x), Float(rightStickInput.y))
            if rightMag > 0.3 {
                let lookAngle = atan2(Float(rightStickInput.x), Float(rightStickInput.y))
                let currentY = playerNode.eulerAngles.y
                var diff = lookAngle - currentY
                if diff > .pi { diff -= .pi * 2 }
                if diff < -.pi { diff += .pi * 2 }
                playerNode.eulerAngles.y += diff * 0.1 * tickScale
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            if let last = lastRendererTime {
                latestFrameDelta = Float(max(time - last, 1.0 / 240.0))
            }
            lastRendererTime = time
        }

        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            renderedFrameCount += 1
            guard renderedFrameCount >= 1 else { return }
            scnView?.accessibilityValue = "ready"
            reportViewportReadyIfNeeded()
        }

        func reportViewportReadyIfNeeded() {
            guard !didReportViewportReady else { return }
            didReportViewportReady = true
            Task { @MainActor in
                onViewportReady()
            }
        }

        func teardown(view: UIView) {
            NotificationCenter.default.removeObserver(self)
            overrideTimerTask?.cancel()
            opponentFocusTimerTask?.cancel()
            strikeRestoreTask?.cancel()
            strikeRestoreTask = nil
            strikeClipNode = nil
            dunkClipNode = nil
            dunkCinePhase = .inactive
            dunkCineTimeScale = 1.0
            ai3v3 = nil
            avatarFocusOverride = nil
            if let container = view as? NexusHybridGameplayContainerView {
                container.overlayView.delegate = nil
                lastRendererTime = nil
                renderedFrameCount = 0
                didReportViewportReady = false
                container.accessibilityValue = "loading"
                container.overlayView.accessibilityValue = "loading"
                if let g = tapGesture {
                    container.overlayView.removeGestureRecognizer(g)
                    tapGesture = nil
                }
                container.overlayView.scene?.rootNode.removeAction(forKey: "cameraFollowLoop")
                container.overlayView.scene?.rootNode.removeAction(forKey: "playerMoveLoop")
                container.overlayView.scene?.rootNode.removeAction(forKey: "ai3v3Loop")
                container.overlayView.isPlaying = false
                container.overlayView.scene = nil
                container.metalView.isPaused = true
                container.metalView.delegate = nil
                if let handle = metalRendererHandle {
                    nexus_metal_renderer_shutdown(handle)
                    nexus_metal_renderer_destroy(handle)
                    metalRendererHandle = nil
                }
                mtkView = nil
                scnView = nil
                hybridContainer = nil
                usesMetalPath = false
                usesHybridPath = false
                metalInitSucceeded = false
                lastMetalDrawableSize = .zero
                return
            }

            if let scnView = view as? SCNView {
                scnView.delegate = nil
                lastRendererTime = nil
                renderedFrameCount = 0
                didReportViewportReady = false
                scnView.accessibilityValue = "loading"
                if let g = tapGesture {
                    scnView.removeGestureRecognizer(g)
                    tapGesture = nil
                }
                scnView.scene?.rootNode.removeAction(forKey: "cameraFollowLoop")
                scnView.scene?.rootNode.removeAction(forKey: "playerMoveLoop")
                scnView.scene?.rootNode.removeAction(forKey: "ai3v3Loop")
                scnView.isPlaying = false
                scnView.scene = nil
                self.scnView = nil
            }

            if let mtkView = view as? MTKView {
                mtkView.isPaused = true
                mtkView.delegate = nil
                mtkView.accessibilityValue = "loading"
                if let handle = metalRendererHandle {
                    nexus_metal_renderer_shutdown(handle)
                    nexus_metal_renderer_destroy(handle)
                    metalRendererHandle = nil
                }
                self.mtkView = nil
                lastMetalDrawableSize = .zero
                usesMetalPath = false
                metalInitSucceeded = false
                didReportViewportReady = false
            }
        }

        private func animateRunState(_ node: SCNNode, speed: Float) {
            guard node.action(forKey: "runBob") == nil else { return }
            let bobHeight = Double(speed * 0.03)
            let bobDuration = Double(max(0.15, 0.3 - speed * 0.1))
            let bob = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: bobHeight, z: 0, duration: bobDuration),
                SCNAction.moveBy(x: 0, y: -bobHeight, z: 0, duration: bobDuration)
            ])
            bob.timingMode = .easeInEaseOut
            node.runAction(SCNAction.repeatForever(bob), forKey: "runBob")

            if let lLeg = node.childNode(withName: "lLeg", recursively: false),
               let rLeg = node.childNode(withName: "rLeg", recursively: false) {
                let legSwing = Double(speed * 0.4)
                let legDuration = Double(max(0.12, 0.25 - speed * 0.08))
                let lForward = SCNAction.rotateTo(x: CGFloat(-legSwing), y: 0, z: 0, duration: legDuration)
                let lBack = SCNAction.rotateTo(x: CGFloat(legSwing), y: 0, z: 0, duration: legDuration)
                lLeg.runAction(SCNAction.repeatForever(SCNAction.sequence([lForward, lBack])), forKey: "legAnim")

                let rForward = SCNAction.rotateTo(x: CGFloat(legSwing), y: 0, z: 0, duration: legDuration)
                let rBack = SCNAction.rotateTo(x: CGFloat(-legSwing), y: 0, z: 0, duration: legDuration)
                rLeg.runAction(SCNAction.repeatForever(SCNAction.sequence([rForward, rBack])), forKey: "legAnim")
            }

            if let lArm = node.childNode(withName: "lUpperArm", recursively: false),
               let rArm = node.childNode(withName: "rUpperArm", recursively: false) {
                let armSwing = Double(speed * 0.3)
                let armDuration = Double(max(0.12, 0.25 - speed * 0.08))
                let laFwd = SCNAction.rotateTo(x: CGFloat(armSwing), y: 0, z: 0.4, duration: armDuration)
                let laBack = SCNAction.rotateTo(x: CGFloat(-armSwing), y: 0, z: 0.4, duration: armDuration)
                lArm.runAction(SCNAction.repeatForever(SCNAction.sequence([laFwd, laBack])), forKey: "armAnim")

                let raFwd = SCNAction.rotateTo(x: CGFloat(-armSwing), y: 0, z: -0.4, duration: armDuration)
                let raBack = SCNAction.rotateTo(x: CGFloat(armSwing), y: 0, z: -0.4, duration: armDuration)
                rArm.runAction(SCNAction.repeatForever(SCNAction.sequence([raFwd, raBack])), forKey: "armAnim")
            }
        }

        private func animateIdleState(_ node: SCNNode) {
            if node.action(forKey: "runBob") != nil {
                node.removeAction(forKey: "runBob")
                for childName in ["lLeg", "rLeg", "lUpperArm", "rUpperArm"] {
                    if let child = node.childNode(withName: childName, recursively: false) {
                        child.removeAction(forKey: "legAnim")
                        child.removeAction(forKey: "armAnim")
                        let resetZ: Float = childName.contains("lUpper") ? 0.4 : (childName.contains("rUpper") ? -0.4 : 0)
                        let reset = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(resetZ), duration: 0.2)
                        reset.timingMode = .easeOut
                        child.runAction(reset)
                    }
                }
            }
        }

        private func findBallNode(in scene: SCNScene) -> SCNNode? {
            let ballNames = ["ball", "basketball", "soccerball", "baseball", "golfball", "tennisball", "volleyball"]
            for name in ballNames {
                if let node = scene.rootNode.childNode(withName: name, recursively: true) {
                    return node
                }
            }
            for child in scene.rootNode.childNodes {
                if let geo = child.geometry as? SCNSphere, geo.radius < 0.2 {
                    return child
                }
            }
            return nil
        }

        private func lerpVec3(_ a: SCNVector3, _ b: SCNVector3, t: Float) -> SCNVector3 {
            SCNVector3(
                a.x + (b.x - a.x) * t,
                a.y + (b.y - a.y) * t,
                a.z + (b.z - a.z) * t
            )
        }

        private func easeInOut(_ t: Float) -> Float {
            t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = activeSceneKitView else { return }
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [.searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue)])

            if let hit = hitResults.first {
                triggerHitEffect(at: hit.worldCoordinates, in: scnView.scene)
            }

            triggerPlayerAction(in: scnView.scene)

            Task { @MainActor in
                onAction()
            }
        }

        func triggerCinematicShake(intensity: Float) {
            cameraShakeIntensity = max(cameraShakeIntensity, intensity)
        }

        private func triggerPlayerAction(in scene: SCNScene?) {
            triggerAvatarAction(named: playerNodeName, in: scene)
        }

        private func triggerAvatarAction(named avatarName: String, in scene: SCNScene? = nil) {
            let scene = scene ?? activeSceneKitView?.scene
            guard let scene else { return }
            guard let node = scene.rootNode.childNode(withName: avatarName, recursively: true) else { return }
            let speedMultiplier = actionSpeedMultiplier()
            let actionPulse = SCNAction.sequence([
                SCNAction.scale(to: 1.12, duration: 0.06 / speedMultiplier),
                SCNAction.scale(to: 0.96, duration: 0.05 / speedMultiplier),
                SCNAction.scale(to: 1.0, duration: 0.1 / speedMultiplier)
            ])
            actionPulse.timingMode = .easeOut
            node.runAction(actionPulse, forKey: "actionPulse")

            if let rArm = node.childNode(withName: "rArm", recursively: false) {
                let armSwing = SCNAction.sequence([
                    SCNAction.rotateTo(x: -1.8, y: 0, z: -0.4, duration: 0.08 / speedMultiplier),
                    SCNAction.rotateTo(x: 0.5, y: 0, z: -0.4, duration: 0.06 / speedMultiplier),
                    SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.15 / speedMultiplier)
                ])
                rArm.runAction(armSwing, forKey: "actionArm")
            }
        }

        private func actionSpeedMultiplier() -> Double {
            if gameMode == .karate || gameMode == .karateEndless {
                return 1.0 + (max(0, min(neuralDrive, 100)) / 100.0) * 0.55
            }
            return 1.0
        }

        func applyNeuralDriveTuning(in scene: SCNScene?) {
            guard (gameMode == .karate || gameMode == .karateEndless), let scene else { return }
            let boost = max(0, min(neuralDrive, 100)) / 100.0
            let emissionStrength = 0.2 + boost * 0.5
            for nodeName in ["fighter1", "fighter2"] {
                guard let fighter = scene.rootNode.childNode(withName: nodeName, recursively: true) else { continue }
                fighter.enumerateChildNodes { child, _ in
                    if let material = child.geometry?.firstMaterial {
                        material.emission.contents = UIColor(red: 1.0, green: 0.2, blue: 0.1, alpha: emissionStrength)
                    }
                }
            }
        }

        private func triggerHitEffect(at position: SCNVector3, in scene: SCNScene?) {
            guard let scene else { return }
            let ring = SCNNode()
            let ringGeo = SCNTorus(ringRadius: 0.01, pipeRadius: 0.004)
            let ringMat = SCNMaterial()
            let color = UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 0.8)
            ringMat.diffuse.contents = color
            ringMat.emission.contents = color
            ringGeo.materials = [ringMat]
            ring.geometry = ringGeo
            ring.position = position
            scene.rootNode.addChildNode(ring)

            let expand = SCNAction.group([
                SCNAction.scale(to: 5, duration: 0.4),
                SCNAction.fadeOut(duration: 0.4)
            ])
            ring.runAction(SCNAction.sequence([expand, SCNAction.removeFromParentNode()]))
        }
    }
}

nonisolated private struct CameraFollowConfig: Sendable {
    let offsetX: Float
    let offsetY: Float
    let offsetZ: Float
    let lookAtY: Float
    let followSpeed: Float
    let targetSpeed: Float
    let fovNormal: CGFloat
    let fovAction: CGFloat
}

nonisolated private struct MovementBounds: Sendable {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
    let speed: Float
}
