import SceneKit
import UIKit
import ObjectiveC

struct GameSceneFactory {
    private static let brandBlue = UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)
    private static let brandCyan = UIColor(red: 0, green: 0.95, blue: 0.9, alpha: 1)
    private static let threeVThreeTeamSize = 3
    private static let rallySnapSmoothingWindow: Double = 0.2

    static func buildScene(for mode: GameModeId) -> SCNScene {
        switch mode {
        case .basketballHeadToHead:
            return buildBasketballScene(mode: mode)
        case .basketballDunkContest:
            return buildDunkContestScene()
        case .basketball3v3:
            return build3v3Scene()
        case .karate1v1, .karateEndless:
            return buildDojoScene()
        case .baseball:
            return buildBaseballScene()
        case .football:
            return buildFootballScene()
        case .soccer:
            return buildSoccerScene()
        case .golf:
            return buildGolfScene()
        case .tennis:
            return buildTennisScene()
        case .volleyball:
            return buildVolleyballScene()
        case .gymnastics:
            return buildGymnasticsScene()
        }
    }

    // MARK: - Basketball (Venice Beach Court)

    private static func buildBasketballScene(mode: GameModeId) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = ArenaSceneConfig.arenaTwilightSkyGradientImage()

        let h2h = ArenaSceneConfig.BasketballH2H.self
        addCamera(to: scene, position: SCNVector3(3.5, 5, 8.5), lookAt: SCNVector3(0, 1.2, 0))
        addLighting(to: scene, tint: brandBlue)

        addFloor(to: scene, color: UIColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 1), reflectivity: 0.15)

        let court = SCNBox(width: CGFloat(h2h.courtW), height: 0.02, length: CGFloat(h2h.courtL), chamferRadius: 0)
        let courtMat = SCNMaterial()
        courtMat.diffuse.contents = UIColor(red: 0.12, green: 0.08, blue: 0.04, alpha: 1)
        courtMat.roughness.contents = 0.9
        court.materials = [courtMat]
        let courtNode = SCNNode(geometry: court)
        courtNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(courtNode)

        addCourtLines(to: scene, halfWidth: h2h.halfW, halfDepth: h2h.halfD)
        addHoop(to: scene, x: h2h.hoopX)
        addHoop(to: scene, x: -h2h.hoopX, flip: true)
        addAvatar(to: scene, at: SCNVector3(-1.875, 0, 0), color: brandBlue, name: "player1", preferMeshyHero: true)
        addAvatar(to: scene, at: SCNVector3(1.875, 0, 0), color: UIColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 1), name: "opponent")
        addBall(to: scene, at: SCNVector3(-1.875, 1.4, 0), color: UIColor(red: 0.8, green: 0.35, blue: 0.1, alpha: 1), useMeshyHoopBusBall: true)
        addVeniceBeachWalls(to: scene)
        addVeniceBeachCrowd(to: scene, depth: 6.25)
        addParticles(to: scene, color: brandCyan.withAlphaComponent(0.2), area: SCNVector3(h2h.courtW, 0.1, h2h.courtL))

        return scene
    }

    // MARK: - Dunk Contest (Arena)

    private static func buildDunkContestScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = ArenaSceneConfig.arenaTwilightSkyGradientImage()

        let dunk = ArenaSceneConfig.BasketballDunk.self
        addCamera(to: scene, position: SCNVector3(2.5, 6.5, 11), lookAt: SCNVector3(0, 2.0, -1))
        addLighting(to: scene, tint: UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1))

        let spotCenter = SCNNode()
        spotCenter.light = SCNLight()
        spotCenter.light?.type = .spot
        spotCenter.light?.color = UIColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1)
        spotCenter.light?.intensity = 1800
        spotCenter.light?.spotInnerAngle = 15
        spotCenter.light?.spotOuterAngle = 40
        spotCenter.light?.castsShadow = true
        spotCenter.light?.shadowRadius = 6
        spotCenter.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        spotCenter.position = SCNVector3(0, 12, 2)
        spotCenter.look(at: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(spotCenter)

        let spotRim = SCNNode()
        spotRim.light = SCNLight()
        spotRim.light?.type = .spot
        spotRim.light?.color = UIColor.orange.withAlphaComponent(0.8)
        spotRim.light?.intensity = 800
        spotRim.light?.spotInnerAngle = 10
        spotRim.light?.spotOuterAngle = 30
        spotRim.position = SCNVector3(-2, 8, -3)
        spotRim.look(at: SCNVector3(2.5, 3, -1))
        scene.rootNode.addChildNode(spotRim)

        addFloor(to: scene, color: UIColor(red: 0.05, green: 0.04, blue: 0.02, alpha: 1), reflectivity: 0.25)

        let court = SCNBox(width: CGFloat(dunk.courtW), height: 0.02, length: CGFloat(dunk.courtL), chamferRadius: 0)
        let courtMat = SCNMaterial()
        courtMat.diffuse.contents = UIColor(red: 0.10, green: 0.06, blue: 0.03, alpha: 1)
        courtMat.roughness.contents = 0.85
        court.materials = [courtMat]
        let courtNode = SCNNode(geometry: court)
        courtNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(courtNode)

        let runway = SCNBox(width: 1.2, height: 0.005, length: CGFloat(dunk.runwayLength), chamferRadius: 0)
        let runwayMat = SCNMaterial()
        runwayMat.diffuse.contents = UIColor.orange.withAlphaComponent(0.08)
        runwayMat.emission.contents = UIColor.orange.withAlphaComponent(0.04)
        runway.materials = [runwayMat]
        let runwayNode = SCNNode(geometry: runway)
        runwayNode.position = SCNVector3(0, 0.02, dunk.runwayZ)
        scene.rootNode.addChildNode(runwayNode)

        for i in 0..<6 {
            let chevron = SCNBox(width: 0.6, height: 0.003, length: 0.04, chamferRadius: 0)
            let cMat = SCNMaterial()
            cMat.diffuse.contents = UIColor.orange.withAlphaComponent(0.2 + Double(i) * 0.05)
            cMat.emission.contents = UIColor.orange.withAlphaComponent(0.1)
            chevron.materials = [cMat]
            let cNode = SCNNode(geometry: chevron)
            cNode.position = SCNVector3(0, 0.025, Float(i) * 1.25 - 1.25)
            scene.rootNode.addChildNode(cNode)
        }

        addCourtLines(to: scene, halfWidth: dunk.halfW, halfDepth: dunk.halfD)
        addHoop(to: scene, x: dunk.hoopX, flip: true)

        let dunker = brandBlue
        addAvatar(to: scene, at: SCNVector3(0, 0, 5), color: dunker, name: "dunker", preferMeshyHero: true)
        addBall(to: scene, at: SCNVector3(0, 1.4, 5), color: UIColor(red: 0.85, green: 0.4, blue: 0.1, alpha: 1), useMeshyHoopBusBall: true)

        let judgeColor = UIColor(white: 0.45, alpha: 1)
        for (i, x) in ([-3.125, 0.0, 3.125] as [Float]).enumerated() {
            let table = SCNBox(width: 1.2, height: 0.7, length: 0.4, chamferRadius: 0.02)
            let tMat = SCNMaterial()
            tMat.diffuse.contents = UIColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 1)
            table.materials = [tMat]
            let tNode = SCNNode(geometry: table)
            tNode.position = SCNVector3(x, 0.35, -6.875)
            scene.rootNode.addChildNode(tNode)
            addAvatar(to: scene, at: SCNVector3(x, 0, -6.25), color: judgeColor, name: "judge\(i)")
        }

        addStadiumStands(to: scene, depth: 15, sideBaseX: dunk.standSideBaseX)
        addStadiumLights(to: scene, width: 15, depth: 15)

        let crowdEmitter = SCNNode()
        let crowdParticles = SCNParticleSystem()
        crowdParticles.birthRate = 3
        crowdParticles.particleLifeSpan = 5
        crowdParticles.particleSize = 0.015
        crowdParticles.particleSizeVariation = 0.01
        crowdParticles.particleColor = UIColor.orange.withAlphaComponent(0.15)
        crowdParticles.emitterShape = SCNBox(width: CGFloat(dunk.courtW), height: 0.1, length: CGFloat(dunk.courtL), chamferRadius: 0)
        crowdParticles.spreadingAngle = 15
        crowdParticles.particleVelocity = 0.2
        crowdParticles.particleVelocityVariation = 0.08
        crowdParticles.birthDirection = .constant
        crowdParticles.emittingDirection = SCNVector3(0, 1, 0)
        crowdParticles.blendMode = .additive
        crowdEmitter.addParticleSystem(crowdParticles)
        crowdEmitter.position = SCNVector3(0, 0.1, 0)
        scene.rootNode.addChildNode(crowdEmitter)

        addVeniceBeachWalls(to: scene)

        return scene
    }

    // MARK: - 3v3 Streetball (6 Players)

    private static func build3v3Scene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = ArenaSceneConfig.arenaTwilightSkyGradientImage()

        let v3 = ArenaSceneConfig.Basketball3v3.self
        addCamera(to: scene, position: SCNVector3(0, 7, 12.5), lookAt: SCNVector3(0, 1, 0))
        addLighting(to: scene, tint: brandCyan)

        addFloor(to: scene, color: UIColor(red: 0.06, green: 0.05, blue: 0.03, alpha: 1), reflectivity: 0.2)

        let court = SCNBox(width: CGFloat(v3.courtW), height: 0.02, length: CGFloat(v3.courtL), chamferRadius: 0)
        let courtMat = SCNMaterial()
        courtMat.diffuse.contents = UIColor(red: 0.0, green: 0.12, blue: 0.35, alpha: 1)
        courtMat.roughness.contents = 0.85
        court.materials = [courtMat]
        let courtNode = SCNNode(geometry: court)
        courtNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(courtNode)

        addCourtLines(to: scene, halfWidth: v3.halfW, halfDepth: v3.halfD)
        addHoop(to: scene, x: v3.hoopX)
        addHoop(to: scene, x: -v3.hoopX, flip: true)

        let teamBlue = brandBlue
        let teamRed = UIColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 1)
        let teamAStart: [SCNVector3] = [
            SCNVector3(-1.25, 0, -1.25),
            SCNVector3(0.625, 0, 1.875),
            SCNVector3(-3.125, 0, 0.625)
        ]
        let teamBStart: [SCNVector3] = [
            SCNVector3(1.25, 0, -0.625),
            SCNVector3(-0.625, 0, 2.5),
            SCNVector3(3.125, 0, -1.25)
        ]

        for index in 0..<threeVThreeTeamSize {
            addAvatar(to: scene, at: teamAStart[index], color: teamBlue, name: "blue\(index + 1)", preferMeshyHero: index == 0)
            addAvatar(to: scene, at: teamBStart[index], color: teamRed, name: "red\(index + 1)")
        }

        addBall(to: scene, at: SCNVector3(teamAStart[0].x, 1.4, teamAStart[0].z), color: UIColor(red: 0.8, green: 0.35, blue: 0.1, alpha: 1), useMeshyHoopBusBall: true)

        add3v3Animations(to: scene, teamSize: threeVThreeTeamSize)
        addHomingDefense(
            to: scene,
            defenderNames: (1...threeVThreeTeamSize).map { "red\($0)" },
            targetName: "blue1",
            clampHalfX: v3.homingClampX,
            clampHalfZ: v3.homingClampZ
        )

        addVeniceBeachWalls(to: scene)
        addVeniceBeachCrowd(to: scene, depth: 7.5)
        addParticles(to: scene, color: brandCyan.withAlphaComponent(0.15), area: SCNVector3(v3.courtW, 0.1, v3.courtL))

        return scene
    }

    private static func add3v3Animations(to scene: SCNScene, teamSize: Int) {
        var avatarNames: [String] = []
        if teamSize >= 2 {
            avatarNames.append(contentsOf: (2...teamSize).map { "blue\($0)" })
        }
        avatarNames.append(contentsOf: (1...teamSize).map { "red\($0)" })
        for name in avatarNames {
            guard let node = scene.rootNode.childNode(withName: name, recursively: true) else { continue }
            let dx = Float.random(in: -1.0...1.0)
            let dz = Float.random(in: -0.8...0.8)
            let duration = Double.random(in: 1.8...3.0)
            let move1 = SCNAction.moveBy(x: CGFloat(dx), y: 0, z: CGFloat(dz), duration: duration)
            move1.timingMode = .easeInEaseOut
            let move2 = SCNAction.moveBy(x: CGFloat(-dx), y: 0, z: CGFloat(-dz), duration: duration)
            move2.timingMode = .easeInEaseOut
            node.runAction(SCNAction.repeatForever(SCNAction.sequence([move1, move2])), forKey: "shuffle")
        }
    }

    private static func addHomingDefense(
        to scene: SCNScene,
        defenderNames: [String],
        targetName: String,
        clampHalfX: Float = 4.6,
        clampHalfZ: Float = 2.7
    ) {
        for (index, defenderName) in defenderNames.enumerated() {
            guard let defender = scene.rootNode.childNode(withName: defenderName, recursively: true) else { continue }
            let baseOffset = SCNVector3(Float.random(in: -0.35...0.35), 0, Float.random(in: -0.25...0.25))
            let chaseSpeed = Float.random(in: 0.03...0.055)
            let homingAction = SCNAction.customAction(duration: 1000) { node, elapsed in
                guard let target = scene.rootNode.childNode(withName: targetName, recursively: true) else { return }
                let offsetPulse = sin(Float(elapsed) * 3.2 + Float(index)) * 0.18
                var desired = target.presentation.position
                desired.x += baseOffset.x + offsetPulse
                desired.z += baseOffset.z - offsetPulse * 0.7
                desired.x = min(clampHalfX, max(-clampHalfX, desired.x))
                desired.z = min(clampHalfZ, max(-clampHalfZ, desired.z))
                let next = moveTowards(current: node.presentation.position, target: desired, maxDistanceDelta: chaseSpeed)
                node.position = SCNVector3(next.x, node.position.y, next.z)
                let dx = desired.x - node.position.x
                let dz = desired.z - node.position.z
                if abs(dx) > 0.01 || abs(dz) > 0.01 {
                    node.eulerAngles.y = atan2(dx, dz)
                }
            }
            defender.runAction(SCNAction.repeatForever(homingAction), forKey: "homingDefense")
        }
    }

    // MARK: - Dojo (Karate)

    private static func buildDojoScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.03, green: 0.01, blue: 0.01, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 3.5, 6.5), lookAt: SCNVector3(0, 1.2, 0))
        addLighting(to: scene, tint: UIColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 1))

        addFloor(to: scene, color: UIColor(red: 0.06, green: 0.03, blue: 0.02, alpha: 1), reflectivity: 0.1)

        let mat = SCNBox(width: 6, height: 0.05, length: 6, chamferRadius: 0)
        let matMaterial = SCNMaterial()
        matMaterial.diffuse.contents = UIColor(red: 0.15, green: 0.05, blue: 0.05, alpha: 1)
        mat.materials = [matMaterial]
        let matNode = SCNNode(geometry: mat)
        matNode.position = SCNVector3(0, 0.025, 0)
        scene.rootNode.addChildNode(matNode)

        let borderColor = UIColor(red: 1.0, green: 0.15, blue: 0.1, alpha: 0.3)
        for z in [-3.0, 3.0] as [Float] {
            let border = SCNBox(width: 6, height: 0.01, length: 0.06, chamferRadius: 0)
            let bMat = SCNMaterial()
            bMat.diffuse.contents = borderColor
            bMat.emission.contents = borderColor
            border.materials = [bMat]
            let bNode = SCNNode(geometry: border)
            bNode.position = SCNVector3(0, 0.06, z)
            scene.rootNode.addChildNode(bNode)
        }
        for x in [-3.0, 3.0] as [Float] {
            let border = SCNBox(width: 0.06, height: 0.01, length: 6, chamferRadius: 0)
            let bMat = SCNMaterial()
            bMat.diffuse.contents = borderColor
            bMat.emission.contents = borderColor
            border.materials = [bMat]
            let bNode = SCNNode(geometry: border)
            bNode.position = SCNVector3(x, 0.06, 0)
            scene.rootNode.addChildNode(bNode)
        }

        for i in stride(from: -2.5, through: 2.5, by: 5.0) {
            let pillar = SCNCylinder(radius: 0.15, height: 4)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = UIColor(red: 0.15, green: 0.08, blue: 0.05, alpha: 1)
            pillar.materials = [pMat]
            let pNode = SCNNode(geometry: pillar)
            pNode.position = SCNVector3(Float(i), 2, -2.8)
            scene.rootNode.addChildNode(pNode)
        }

        let torii = SCNBox(width: 4.0, height: 0.15, length: 0.12, chamferRadius: 0.02)
        let toriiMat = SCNMaterial()
        toriiMat.diffuse.contents = UIColor(red: 0.7, green: 0.1, blue: 0.05, alpha: 1)
        toriiMat.emission.contents = UIColor(red: 0.7, green: 0.1, blue: 0.05, alpha: 0.15)
        torii.materials = [toriiMat]
        let toriiNode = SCNNode(geometry: torii)
        toriiNode.position = SCNVector3(0, 3.8, -2.8)
        scene.rootNode.addChildNode(toriiNode)

        let redTint = UIColor(red: 1.0, green: 0.15, blue: 0.1, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(-1.2, 0, 0), color: redTint, name: "fighter1")
        addAvatar(to: scene, at: SCNVector3(1.2, 0, 0), color: brandCyan, name: "fighter2")

        addKarateAnimations(to: scene)

        addArenaWalls(to: scene, wallColor: UIColor(red: 0.24, green: 0.16, blue: 0.08, alpha: 1), width: 12, depth: 12, height: 5)
        addDojoSpectators(to: scene)
        addParticles(to: scene, color: UIColor.red.withAlphaComponent(0.12), area: SCNVector3(6, 0.1, 6))

        return scene
    }

    private static func addKarateAnimations(to scene: SCNScene) {
        guard let fighter1 = scene.rootNode.childNode(withName: "fighter1", recursively: true),
              let fighter2 = scene.rootNode.childNode(withName: "fighter2", recursively: true) else { return }

        let f1Circle = SCNAction.sequence([
            SCNAction.moveBy(x: 0.4, y: 0, z: 0.3, duration: 1.2),
            SCNAction.moveBy(x: -0.3, y: 0, z: -0.5, duration: 1.0),
            SCNAction.moveBy(x: -0.1, y: 0, z: 0.2, duration: 0.8)
        ])
        f1Circle.timingMode = .easeInEaseOut
        fighter1.runAction(SCNAction.repeatForever(f1Circle), forKey: "circle")

        let f2Circle = SCNAction.sequence([
            SCNAction.moveBy(x: -0.3, y: 0, z: -0.3, duration: 1.0),
            SCNAction.moveBy(x: 0.4, y: 0, z: 0.5, duration: 1.2),
            SCNAction.moveBy(x: -0.1, y: 0, z: -0.2, duration: 0.8)
        ])
        f2Circle.timingMode = .easeInEaseOut
        fighter2.runAction(SCNAction.repeatForever(f2Circle), forKey: "circle")

        if let rArm = fighter1.childNode(withName: "rArm", recursively: false) {
            let punch = SCNAction.sequence([
                SCNAction.wait(duration: 2.0),
                SCNAction.rotateTo(x: -1.8, y: 0, z: -0.4, duration: 0.08),
                SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.2),
                SCNAction.wait(duration: 1.5),
                SCNAction.rotateTo(x: -1.5, y: 0.3, z: -0.6, duration: 0.1),
                SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.25)
            ])
            rArm.runAction(SCNAction.repeatForever(punch), forKey: "punch")
        }

        if let lLeg = fighter2.childNode(withName: "lLeg", recursively: false) {
            let kick = SCNAction.sequence([
                SCNAction.wait(duration: 3.0),
                SCNAction.rotateTo(x: 1.2, y: 0, z: 0, duration: 0.1),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3),
                SCNAction.wait(duration: 2.5)
            ])
            lLeg.runAction(SCNAction.repeatForever(kick), forKey: "kick")
        }
    }

    // MARK: - Baseball (Stadium Diamond with Pitcher/Catcher/Mound)

    private static func buildBaseballScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 1)

        addCamera(to: scene, position: SCNVector3(-2, 4, 6), lookAt: SCNVector3(0, 1, 0))
        addLighting(to: scene, tint: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1))

        addFloor(to: scene, color: UIColor(red: 0.05, green: 0.08, blue: 0.03, alpha: 1), reflectivity: 0.05)

        let outfield = SCNBox(width: 16, height: 0.01, length: 14, chamferRadius: 0)
        let ofMat = SCNMaterial()
        ofMat.diffuse.contents = UIColor(red: 0.04, green: 0.1, blue: 0.03, alpha: 1)
        outfield.materials = [ofMat]
        let ofNode = SCNNode(geometry: outfield)
        ofNode.position = SCNVector3(0, 0.005, -2)
        scene.rootNode.addChildNode(ofNode)

        let infield = SCNCylinder(radius: 4, height: 0.02)
        let dirtMat = SCNMaterial()
        dirtMat.diffuse.contents = UIColor(red: 0.14, green: 0.09, blue: 0.04, alpha: 1)
        infield.materials = [dirtMat]
        let infieldNode = SCNNode(geometry: infield)
        infieldNode.position = SCNVector3(0, 0.01, 1)
        scene.rootNode.addChildNode(infieldNode)

        let mound = SCNCylinder(radius: 0.5, height: 0.25)
        let moundMat = SCNMaterial()
        moundMat.diffuse.contents = UIColor(red: 0.16, green: 0.1, blue: 0.05, alpha: 1)
        mound.materials = [moundMat]
        let moundNode = SCNNode(geometry: mound)
        moundNode.position = SCNVector3(0, 0.125, -1.0)
        scene.rootNode.addChildNode(moundNode)

        let rubber = SCNBox(width: 0.3, height: 0.02, length: 0.06, chamferRadius: 0)
        let rubberMat = SCNMaterial()
        rubberMat.diffuse.contents = UIColor.white
        rubber.materials = [rubberMat]
        let rubberNode = SCNNode(geometry: rubber)
        rubberNode.position = SCNVector3(0, 0.26, -1.0)
        scene.rootNode.addChildNode(rubberNode)

        let homePlate = SCNBox(width: 0.4, height: 0.01, length: 0.4, chamferRadius: 0)
        let hpMat = SCNMaterial()
        hpMat.diffuse.contents = UIColor.white
        hpMat.emission.contents = UIColor.white.withAlphaComponent(0.3)
        homePlate.materials = [hpMat]
        let hpNode = SCNNode(geometry: homePlate)
        hpNode.position = SCNVector3(0, 0.02, 3)
        hpNode.eulerAngles.y = .pi / 4
        scene.rootNode.addChildNode(hpNode)

        let bases: [(Float, Float)] = [(-2.8, 0), (0, -2.5), (2.8, 0)]
        for (bx, bz) in bases {
            let base = SCNBox(width: 0.35, height: 0.01, length: 0.35, chamferRadius: 0)
            let baseMat = SCNMaterial()
            baseMat.diffuse.contents = UIColor.white
            baseMat.emission.contents = UIColor.white.withAlphaComponent(0.2)
            base.materials = [baseMat]
            let baseNode = SCNNode(geometry: base)
            baseNode.position = SCNVector3(bx, 0.02, bz)
            baseNode.eulerAngles.y = .pi / 4
            scene.rootNode.addChildNode(baseNode)
        }

        let baselineColor = UIColor.white.withAlphaComponent(0.2)
        func baselineMat() -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = baselineColor
            m.emission.contents = baselineColor
            return m
        }
        let line1 = SCNBox(width: 0.03, height: 0.005, length: 8.0, chamferRadius: 0)
        line1.materials = [baselineMat()]
        let line1Node = SCNNode(geometry: line1)
        line1Node.position = SCNVector3(-1.5, 0.025, 1.5)
        line1Node.eulerAngles.y = -.pi / 6.5
        scene.rootNode.addChildNode(line1Node)

        let line2 = SCNBox(width: 0.03, height: 0.005, length: 8.0, chamferRadius: 0)
        line2.materials = [baselineMat()]
        let line2Node = SCNNode(geometry: line2)
        line2Node.position = SCNVector3(1.5, 0.025, 1.5)
        line2Node.eulerAngles.y = .pi / 6.5
        scene.rootNode.addChildNode(line2Node)

        let batterColor = UIColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(0.4, 0, 2.8), color: batterColor, name: "batter")

        let pitcherColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(0, 0.25, -1.0), color: pitcherColor, name: "pitcher")

        let catcherColor = UIColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(0, 0, 3.6), color: catcherColor, name: "catcher")

        if let catcher = scene.rootNode.childNode(withName: "catcher", recursively: true) {
            catcher.scale = SCNVector3(0.9, 0.85, 0.9)
        }

        let pitcherHand = SCNNode()
        pitcherHand.name = "pitcherHand"
        pitcherHand.position = SCNVector3(0.18, 1.55, -0.78)
        scene.rootNode.addChildNode(pitcherHand)

        let batGeo = SCNBox(width: 0.06, height: 0.85, length: 0.04, chamferRadius: 0.01)
        let batMat = SCNMaterial()
        batMat.diffuse.contents = UIColor(red: 0.47, green: 0.32, blue: 0.16, alpha: 1)
        batMat.roughness.contents = 0.75
        batGeo.materials = [batMat]
        let batNode = SCNNode(geometry: batGeo)
        batNode.name = "bat"
        batNode.position = SCNVector3(0.63, 1.05, 2.85)
        batNode.eulerAngles = SCNVector3(0.2, 0.2, 0.45)
        scene.rootNode.addChildNode(batNode)

        HomeRunDerbyManager.installIfNeeded(in: scene, pitcherHandNodeName: "pitcherHand", batNodeName: "bat")

        if let pitcher = scene.rootNode.childNode(withName: "pitcher", recursively: true),
           let rArm = pitcher.childNode(withName: "rArm", recursively: false) {
            let windupAction = SCNAction.sequence([
                SCNAction.wait(duration: 1.5),
                SCNAction.rotateTo(x: -2.5, y: 0, z: -0.4, duration: 0.4),
                SCNAction.rotateTo(x: 0.8, y: 0, z: -0.4, duration: 0.15),
                SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.4),
                SCNAction.wait(duration: 0.5)
            ])
            rArm.runAction(SCNAction.repeatForever(windupAction), forKey: "windup")
        }

        addStadiumStands(to: scene, depth: 14)
        addStadiumLights(to: scene, width: 16, depth: 14)
        addStadiumCrowd(to: scene, width: 16, depth: 14, color: UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1))
        addArenaWalls(to: scene, wallColor: UIColor(red: 0.18, green: 0.29, blue: 0.18, alpha: 1), width: 16, depth: 14, height: 5)
        addParticles(to: scene, color: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.1), area: SCNVector3(8, 0.1, 8))

        return scene
    }

    // MARK: - Football (Kick Return with Defenders)

    private static func buildFootballScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 6, 10), lookAt: SCNVector3(0, 0.5, -2))
        addLighting(to: scene, tint: UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1))

        addFloor(to: scene, color: UIColor(red: 0.04, green: 0.08, blue: 0.03, alpha: 1), reflectivity: 0.05)

        let field = SCNBox(width: 12, height: 0.02, length: 20, chamferRadius: 0)
        let fMat = SCNMaterial()
        fMat.diffuse.contents = UIColor(red: 0.06, green: 0.14, blue: 0.04, alpha: 1)
        field.materials = [fMat]
        let fieldNode = SCNNode(geometry: field)
        fieldNode.position = SCNVector3(0, 0.01, -3)
        scene.rootNode.addChildNode(fieldNode)

        let lineColor = UIColor.white.withAlphaComponent(0.2)
        for z in stride(from: -10.0, through: 7.0, by: 2.0) {
            let line = SCNBox(width: 12, height: 0.005, length: 0.04, chamferRadius: 0)
            let lMat = SCNMaterial()
            lMat.diffuse.contents = lineColor
            lMat.emission.contents = lineColor
            line.materials = [lMat]
            let lNode = SCNNode(geometry: line)
            lNode.position = SCNVector3(0, 0.025, Float(z))
            scene.rootNode.addChildNode(lNode)
        }

        let hashColor = UIColor.white.withAlphaComponent(0.12)
        for z in stride(from: -10.0, through: 7.0, by: 2.0) {
            for x in [-2.0, 2.0] as [Float] {
                let hash = SCNBox(width: 0.04, height: 0.005, length: 0.3, chamferRadius: 0)
                let hMat = SCNMaterial()
                hMat.diffuse.contents = hashColor
                hash.materials = [hMat]
                let hNode = SCNNode(geometry: hash)
                hNode.position = SCNVector3(x, 0.025, Float(z))
                scene.rootNode.addChildNode(hNode)
            }
        }

        let endzoneColor = UIColor(red: 0.15, green: 0.05, blue: 0.0, alpha: 0.3)
        for zPos in [-12.0, 8.0] as [Float] {
            let ez = SCNBox(width: 12, height: 0.005, length: 4, chamferRadius: 0)
            let ezMat = SCNMaterial()
            ezMat.diffuse.contents = endzoneColor
            ezMat.emission.contents = endzoneColor
            ez.materials = [ezMat]
            let ezNode = SCNNode(geometry: ez)
            ezNode.position = SCNVector3(0, 0.02, zPos)
            scene.rootNode.addChildNode(ezNode)
        }

        for side in [-1, 1] as [Float] {
            let upright = SCNCylinder(radius: 0.04, height: 5)
            let gpMat = SCNMaterial()
            gpMat.diffuse.contents = UIColor.yellow.withAlphaComponent(0.8)
            gpMat.emission.contents = UIColor.yellow.withAlphaComponent(0.15)
            upright.materials = [gpMat]
            let gpNode = SCNNode(geometry: upright)
            gpNode.position = SCNVector3(side * 1.5, 2.5, -13)
            scene.rootNode.addChildNode(gpNode)
        }
        let crossbar = SCNCylinder(radius: 0.04, height: 3.0)
        let cbMat = SCNMaterial()
        cbMat.diffuse.contents = UIColor.yellow.withAlphaComponent(0.8)
        crossbar.materials = [cbMat]
        let cbNode = SCNNode(geometry: crossbar)
        cbNode.position = SCNVector3(0, 2.8, -13)
        cbNode.eulerAngles.z = .pi / 2
        scene.rootNode.addChildNode(cbNode)

        let returnerColor = UIColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(0, 0, 5), color: returnerColor, name: "returner")

        let football = SCNSphere(radius: 0.09)
        let fbMat = SCNMaterial()
        fbMat.diffuse.contents = UIColor(red: 0.4, green: 0.25, blue: 0.1, alpha: 1)
        football.materials = [fbMat]
        let fbNode = SCNNode(geometry: football)
        fbNode.position = SCNVector3(0, 3.5, 5)
        fbNode.name = "football"
        scene.rootNode.addChildNode(fbNode)

        let kickArc = SCNAction.sequence([
            SCNAction.group([
                SCNAction.moveBy(x: 0, y: 2, z: 0, duration: 1.2),
                SCNAction.rotateBy(x: 3, y: 0, z: 0, duration: 1.2)
            ]),
            SCNAction.group([
                SCNAction.moveBy(x: 0, y: -4, z: 0, duration: 1.0),
                SCNAction.rotateBy(x: 2, y: 0, z: 0, duration: 1.0)
            ]),
            SCNAction.move(to: SCNVector3(0, 1.3, 5), duration: 0.01),
            SCNAction.wait(duration: 2.0)
        ])
        fbNode.runAction(SCNAction.repeatForever(kickArc), forKey: "kick")

        let defColor = UIColor(red: 0.8, green: 0.2, blue: 0.15, alpha: 1)
        let defPositions: [SCNVector3] = [
            SCNVector3(-3, 0, 0), SCNVector3(-1.5, 0, -1), SCNVector3(0, 0, -2),
            SCNVector3(1.5, 0, -1), SCNVector3(3, 0, 0),
            SCNVector3(-2, 0, -3), SCNVector3(0, 0, -4),
            SCNVector3(2, 0, -3), SCNVector3(-1, 0, -5),
            SCNVector3(1, 0, -5), SCNVector3(0, 0, -7)
        ]
        for (i, pos) in defPositions.enumerated() {
            addAvatar(to: scene, at: pos, color: defColor, name: "def\(i)")
        }

        for i in 0..<defPositions.count {
            guard let def = scene.rootNode.childNode(withName: "def\(i)", recursively: true) else { continue }
            let speed = Double.random(in: 0.04...0.08)
            let lateralDrift = Float.random(in: -0.02...0.02)
            let homing = SCNAction.customAction(duration: 1000) { node, elapsed in
                guard let returner = node.parent?.childNode(withName: "returner", recursively: true) else { return }
                let dx = returner.position.x - node.position.x
                let dz = returner.position.z - node.position.z
                let dist = sqrt(dx * dx + dz * dz)
                guard dist > 0.4 else { return }
                let factor = Float(speed)
                let wobble = sin(Float(elapsed) * 2.5 + Float(i)) * lateralDrift
                node.position.x += (dx / dist * factor) + wobble
                node.position.z += dz / dist * factor
                let angle = atan2(dx, dz)
                node.eulerAngles.y = angle
            }
            def.runAction(SCNAction.repeatForever(homing), forKey: "homing")
        }

        addStadiumStands(to: scene, depth: 20)
        addStadiumLights(to: scene, width: 12, depth: 20)
        addStadiumCrowd(to: scene, width: 12, depth: 20, color: UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1))
        addFootballEndzonePaint(to: scene)
        addArenaWalls(to: scene, wallColor: UIColor(red: 0.12, green: 0.23, blue: 0.37, alpha: 1), width: 18, depth: 24, height: 5)
        addParticles(to: scene, color: UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 0.08), area: SCNVector3(12, 0.1, 20))

        return scene
    }

    // MARK: - Soccer (Penalty Shootout)

    private static func buildSoccerScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.01, green: 0.03, blue: 0.02, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 4, 8), lookAt: SCNVector3(0, 1.0, -1))
        addLighting(to: scene, tint: UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1))

        addFloor(to: scene, color: UIColor(red: 0.04, green: 0.1, blue: 0.03, alpha: 1), reflectivity: 0.05)

        let pitch = SCNBox(width: 14, height: 0.02, length: 10, chamferRadius: 0)
        let pMat = SCNMaterial()
        pMat.diffuse.contents = UIColor(red: 0.06, green: 0.14, blue: 0.05, alpha: 1)
        pitch.materials = [pMat]
        let pNode = SCNNode(geometry: pitch)
        pNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(pNode)

        let grassStripeLight = UIColor(red: 0.07, green: 0.16, blue: 0.06, alpha: 1)
        for i in stride(from: -5.0, through: 5.0, by: 2.0) {
            let stripe = SCNBox(width: 14, height: 0.003, length: 1.0, chamferRadius: 0)
            let sMat = SCNMaterial()
            sMat.diffuse.contents = grassStripeLight
            stripe.materials = [sMat]
            let sNode = SCNNode(geometry: stripe)
            sNode.position = SCNVector3(0, 0.015, Float(i))
            scene.rootNode.addChildNode(sNode)
        }

        let lineColor = UIColor.white.withAlphaComponent(0.35)
        func addLine(_ w: CGFloat, _ l: CGFloat, _ pos: SCNVector3) {
            let geo = SCNBox(width: w, height: 0.005, length: l, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = lineColor
            mat.emission.contents = lineColor
            geo.materials = [mat]
            let n = SCNNode(geometry: geo)
            n.position = pos
            scene.rootNode.addChildNode(n)
        }
        addLine(4.5, 0.04, SCNVector3(0, 0.025, -3.5))
        addLine(4.5, 0.04, SCNVector3(0, 0.025, -1.0))
        addLine(0.04, 2.5, SCNVector3(-2.25, 0.025, -2.25))
        addLine(0.04, 2.5, SCNVector3(2.25, 0.025, -2.25))

        let penaltySpot = SCNCylinder(radius: 0.06, height: 0.005)
        let psMat = SCNMaterial()
        psMat.diffuse.contents = UIColor.white
        psMat.emission.contents = UIColor.white.withAlphaComponent(0.4)
        penaltySpot.materials = [psMat]
        let psNode = SCNNode(geometry: penaltySpot)
        psNode.position = SCNVector3(0, 0.025, 2.0)
        scene.rootNode.addChildNode(psNode)

        buildGoalNet(in: scene, at: SCNVector3(0, 0, -3.5))

        let kickerColor = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(0, 0, 3.5), color: kickerColor, name: "kicker")

        let gkColor = UIColor(red: 0.9, green: 0.8, blue: 0.1, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(0, 0, -3.2), color: gkColor, name: "goalkeeper")

        if let gk = scene.rootNode.childNode(withName: "goalkeeper", recursively: true) {
            let sway = SCNAction.sequence([
                SCNAction.moveBy(x: 0.8, y: 0, z: 0, duration: 0.7),
                SCNAction.moveBy(x: -1.6, y: 0, z: 0, duration: 1.4),
                SCNAction.moveBy(x: 0.8, y: 0, z: 0, duration: 0.7)
            ])
            sway.timingMode = .easeInEaseOut
            gk.runAction(SCNAction.repeatForever(sway), forKey: "sway")

            if let rArm = gk.childNode(withName: "rArm", recursively: false) {
                let readyArm = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: 0, z: -0.8, duration: 0.5),
                    SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.5)
                ])
                rArm.runAction(SCNAction.repeatForever(readyArm), forKey: "ready")
            }
        }

        if let kicker = scene.rootNode.childNode(withName: "kicker", recursively: true),
           let rLeg = kicker.childNode(withName: "rLeg", recursively: false) {
            let kickLeg = SCNAction.sequence([
                SCNAction.wait(duration: 3.0),
                SCNAction.rotateTo(x: -1.5, y: 0, z: 0, duration: 0.12),
                SCNAction.rotateTo(x: 0.8, y: 0, z: 0, duration: 0.08),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3),
                SCNAction.wait(duration: 0.5)
            ])
            rLeg.runAction(SCNAction.repeatForever(kickLeg), forKey: "kick")
        }

        let soccerBallFlight = SCNNode()
        soccerBallFlight.name = "ballFlight"
        let flightParticles = SCNParticleSystem()
        flightParticles.birthRate = 0
        flightParticles.particleLifeSpan = 0.3
        flightParticles.particleSize = 0.015
        flightParticles.particleColor = UIColor.white.withAlphaComponent(0.2)
        flightParticles.emitterShape = SCNSphere(radius: 0.05)
        flightParticles.blendMode = .additive
        soccerBallFlight.addParticleSystem(flightParticles)
        soccerBallFlight.position = SCNVector3(0, 0.11, 2.0)
        scene.rootNode.addChildNode(soccerBallFlight)

        let soccerBall = SCNSphere(radius: 0.11)
        let sbMat = SCNMaterial()
        sbMat.diffuse.contents = UIColor.white
        sbMat.roughness.contents = 0.6
        soccerBall.materials = [sbMat]
        let sbNode = SCNNode(geometry: soccerBall)
        sbNode.position = SCNVector3(0, 0.11, 2.0)
        sbNode.name = "soccerball"
        scene.rootNode.addChildNode(sbNode)

        addStadiumStands(to: scene, depth: 10)
        addStadiumLights(to: scene, width: 14, depth: 10)
        addStadiumCrowd(to: scene, width: 14, depth: 10, color: UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1))
        addArenaWalls(to: scene, wallColor: UIColor(red: 0.1, green: 0.28, blue: 0.17, alpha: 1), width: 16, depth: 14, height: 4)
        addParticles(to: scene, color: UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.1), area: SCNVector3(8, 0.1, 5))

        return scene
    }

    // MARK: - Golf (Green)

    private static func buildGolfScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.01, green: 0.02, blue: 0.03, alpha: 1)

        addCamera(to: scene, position: SCNVector3(3, 3, 5), lookAt: SCNVector3(0, 0.5, 0))
        addLighting(to: scene, tint: UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1))

        addFloor(to: scene, color: UIColor(red: 0.03, green: 0.08, blue: 0.03, alpha: 1), reflectivity: 0.05)

        let green = SCNCylinder(radius: 5, height: 0.02)
        let gMat = SCNMaterial()
        gMat.diffuse.contents = UIColor(red: 0.06, green: 0.15, blue: 0.05, alpha: 1)
        green.materials = [gMat]
        let gNode = SCNNode(geometry: green)
        gNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(gNode)

        let flagPole = SCNCylinder(radius: 0.015, height: 1.5)
        let fpMat = SCNMaterial()
        fpMat.diffuse.contents = UIColor.white
        flagPole.materials = [fpMat]
        let fpNode = SCNNode(geometry: flagPole)
        fpNode.position = SCNVector3(0, 0.75, -2)
        scene.rootNode.addChildNode(fpNode)

        let flag = SCNBox(width: 0.4, height: 0.2, length: 0.005, chamferRadius: 0)
        let flagMat = SCNMaterial()
        flagMat.diffuse.contents = UIColor.red
        flagMat.emission.contents = UIColor.red.withAlphaComponent(0.3)
        flag.materials = [flagMat]
        let flagNode = SCNNode(geometry: flag)
        flagNode.position = SCNVector3(0.2, 1.4, -2)
        scene.rootNode.addChildNode(flagNode)

        let hole = SCNCylinder(radius: 0.054, height: 0.01)
        let holeMat = SCNMaterial()
        holeMat.diffuse.contents = UIColor.black
        hole.materials = [holeMat]
        let holeNode = SCNNode(geometry: hole)
        holeNode.position = SCNVector3(0, 0.025, -2)
        scene.rootNode.addChildNode(holeNode)

        addAvatar(to: scene, at: SCNVector3(0, 0, 3), color: UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1), name: "golfer")

        let club = SCNCylinder(radius: 0.012, height: 1.0)
        let clubMat = SCNMaterial()
        clubMat.diffuse.contents = UIColor(white: 0.6, alpha: 1)
        clubMat.metalness.contents = 0.8
        club.materials = [clubMat]
        let clubNode = SCNNode(geometry: club)
        clubNode.position = SCNVector3(0.2, 0.5, 3)
        clubNode.eulerAngles.z = 0.3
        scene.rootNode.addChildNode(clubNode)

        let clubHead = SCNBox(width: 0.06, height: 0.02, length: 0.04, chamferRadius: 0.005)
        let chMat = SCNMaterial()
        chMat.diffuse.contents = UIColor(white: 0.5, alpha: 1)
        chMat.metalness.contents = 0.9
        clubHead.materials = [chMat]
        let chNode = SCNNode(geometry: clubHead)
        chNode.position = SCNVector3(0.35, 0.05, 3)
        scene.rootNode.addChildNode(chNode)

        if let golfer = scene.rootNode.childNode(withName: "golfer", recursively: true),
           let rArm = golfer.childNode(withName: "rArm", recursively: false) {
            let swingAnim = SCNAction.sequence([
                SCNAction.wait(duration: 2.0),
                SCNAction.rotateTo(x: -2.0, y: 0, z: -0.4, duration: 0.4),
                SCNAction.rotateTo(x: 1.0, y: 0, z: -0.4, duration: 0.15),
                SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.3),
                SCNAction.wait(duration: 2.0)
            ])
            rArm.runAction(SCNAction.repeatForever(swingAnim), forKey: "swing")
        }

        let golfBall = SCNSphere(radius: 0.022)
        let gbMat = SCNMaterial()
        gbMat.diffuse.contents = UIColor.white
        golfBall.materials = [gbMat]
        let gbNode = SCNNode(geometry: golfBall)
        gbNode.position = SCNVector3(0, 0.04, 2.8)
        scene.rootNode.addChildNode(gbNode)

        for z in stride(from: -4.0, through: 4.0, by: 2.0) {
            let tree = SCNCylinder(radius: 0.06, height: 3.0)
            let treeMat = SCNMaterial()
            treeMat.diffuse.contents = UIColor(red: 0.35, green: 0.25, blue: 0.12, alpha: 1)
            tree.materials = [treeMat]
            let treeNode = SCNNode(geometry: tree)
            treeNode.position = SCNVector3(-6.5, 1.5, Float(z))
            scene.rootNode.addChildNode(treeNode)

            let canopy = SCNSphere(radius: 0.8)
            let canopyMat = SCNMaterial()
            canopyMat.diffuse.contents = UIColor(red: 0.12, green: 0.35, blue: 0.1, alpha: 1)
            canopy.materials = [canopyMat]
            let canopyNode = SCNNode(geometry: canopy)
            canopyNode.position = SCNVector3(-6.5, 3.2, Float(z))
            canopyNode.scale = SCNVector3(1.2, 0.7, 1.2)
            scene.rootNode.addChildNode(canopyNode)
        }

        let fairway = SCNBox(width: 3, height: 0.005, length: 6, chamferRadius: 0)
        let fwMat = SCNMaterial()
        fwMat.diffuse.contents = UIColor(red: 0.05, green: 0.12, blue: 0.04, alpha: 1)
        fairway.materials = [fwMat]
        let fwNode = SCNNode(geometry: fairway)
        fwNode.position = SCNVector3(0, 0.008, 0)
        scene.rootNode.addChildNode(fwNode)

        let bunker = SCNCylinder(radius: 0.6, height: 0.02)
        let bunkerMat = SCNMaterial()
        bunkerMat.diffuse.contents = UIColor(red: 0.85, green: 0.78, blue: 0.55, alpha: 1)
        bunker.materials = [bunkerMat]
        let bunkerNode = SCNNode(geometry: bunker)
        bunkerNode.position = SCNVector3(1.5, 0.015, -1.5)
        scene.rootNode.addChildNode(bunkerNode)

        addGolfGallery(to: scene)
        addArenaWalls(to: scene, wallColor: UIColor(red: 0.1, green: 0.24, blue: 0.1, alpha: 1), width: 16, depth: 14, height: 4)
        addParticles(to: scene, color: UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 0.1), area: SCNVector3(8, 0.1, 8))

        return scene
    }

    // MARK: - Tennis (Rally Court)

    private static func buildTennisScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 5, 8), lookAt: SCNVector3(0, 0.8, 0))
        addLighting(to: scene, tint: UIColor(red: 0.85, green: 0.75, blue: 0.1, alpha: 1))

        addFloor(to: scene, color: UIColor(red: 0.04, green: 0.06, blue: 0.03, alpha: 1), reflectivity: 0.1)

        let court = SCNBox(width: 8.2, height: 0.02, length: 11, chamferRadius: 0)
        let courtMat = SCNMaterial()
        courtMat.diffuse.contents = UIColor(red: 0.15, green: 0.08, blue: 0.05, alpha: 1)
        court.materials = [courtMat]
        let courtNode = SCNNode(geometry: court)
        courtNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(courtNode)

        let innerCourt = SCNBox(width: 6.4, height: 0.003, length: 9.0, chamferRadius: 0)
        let icMat = SCNMaterial()
        icMat.diffuse.contents = UIColor(red: 0.12, green: 0.07, blue: 0.04, alpha: 1)
        innerCourt.materials = [icMat]
        let icNode = SCNNode(geometry: innerCourt)
        icNode.position = SCNVector3(0, 0.015, 0)
        scene.rootNode.addChildNode(icNode)

        let lineColor = UIColor.white.withAlphaComponent(0.5)
        func addLine(_ w: CGFloat, _ l: CGFloat, _ pos: SCNVector3) {
            let geo = SCNBox(width: w, height: 0.005, length: l, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = lineColor
            mat.emission.contents = lineColor
            geo.materials = [mat]
            let n = SCNNode(geometry: geo)
            n.position = pos
            scene.rootNode.addChildNode(n)
        }
        addLine(8.2, 0.04, SCNVector3(0, 0.025, -5.5))
        addLine(8.2, 0.04, SCNVector3(0, 0.025, 5.5))
        addLine(0.04, 11, SCNVector3(-4.1, 0.025, 0))
        addLine(0.04, 11, SCNVector3(4.1, 0.025, 0))
        addLine(0.04, 11, SCNVector3(-3.2, 0.025, 0))
        addLine(0.04, 11, SCNVector3(3.2, 0.025, 0))
        addLine(6.4, 0.04, SCNVector3(0, 0.025, -2.0))
        addLine(6.4, 0.04, SCNVector3(0, 0.025, 2.0))
        addLine(0.04, 4, SCNVector3(0, 0.025, 0))

        for x in [-3.2, 3.2] as [Float] {
            let post = SCNCylinder(radius: 0.035, height: 1.3)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = UIColor(white: 0.7, alpha: 1)
            post.materials = [pMat]
            let pNode = SCNNode(geometry: post)
            pNode.position = SCNVector3(x, 0.65, 0)
            scene.rootNode.addChildNode(pNode)
        }
        let net = SCNBox(width: 6.4, height: 1.0, length: 0.02, chamferRadius: 0)
        let netMat = SCNMaterial()
        netMat.diffuse.contents = UIColor.white.withAlphaComponent(0.18)
        netMat.isDoubleSided = true
        net.materials = [netMat]
        let netNode = SCNNode(geometry: net)
        netNode.position = SCNVector3(0, 0.8, 0)
        scene.rootNode.addChildNode(netNode)

        let netBand = SCNBox(width: 6.4, height: 0.04, length: 0.025, chamferRadius: 0)
        let nbMat = SCNMaterial()
        nbMat.diffuse.contents = UIColor.white
        netBand.materials = [nbMat]
        let nbNode = SCNNode(geometry: netBand)
        nbNode.position = SCNVector3(0, 1.3, 0)
        scene.rootNode.addChildNode(nbNode)

        addAvatar(to: scene, at: SCNVector3(0, 0, 4.5), color: UIColor(red: 0.85, green: 0.75, blue: 0.1, alpha: 1), name: "player")
        addAvatar(to: scene, at: SCNVector3(0, 0, -4.5), color: brandCyan, name: "opponent")

        let ball = SCNSphere(radius: 0.035)
        let bMat = SCNMaterial()
        bMat.diffuse.contents = UIColor(red: 0.8, green: 0.9, blue: 0.1, alpha: 1)
        bMat.emission.contents = UIColor(red: 0.8, green: 0.9, blue: 0.1, alpha: 0.15)
        ball.materials = [bMat]
        let bNode = SCNNode(geometry: ball)
        bNode.position = SCNVector3(0, 1.0, 3.5)
        bNode.name = "tennisball"
        scene.rootNode.addChildNode(bNode)

        let rallyAction = SCNAction.customAction(duration: 1000) { node, elapsed in
            let cycle = Float(elapsed.truncatingRemainder(dividingBy: 2.0))
            let phase = cycle / 2.0
            let t = phase < 0.5 ? phase * 2.0 : 2.0 - phase * 2.0
            let eased = t * t * (3.0 - 2.0 * t)
            let xWobble = sin(Float(elapsed) * 1.7) * 1.5
            let zStart: Float = 3.5
            let zEnd: Float = -3.5
            let yArc: Float = 1.2 + sin(eased * .pi) * 0.8
            node.position = SCNVector3(
                xWobble,
                yArc,
                zStart + (zEnd - zStart) * eased
            )
        }
        bNode.runAction(SCNAction.repeatForever(rallyAction), forKey: "rally")
        addRallySnapToBall(in: scene, playerName: "opponent", ballName: "tennisball", laneZ: -4.5, xLimit: -2.8...2.8)
        addRallySnapToBall(in: scene, playerName: "player", ballName: "tennisball", laneZ: 4.5, xLimit: -2.8...2.8)

        if let opponent = scene.rootNode.childNode(withName: "opponent", recursively: true),
           let rArm = opponent.childNode(withName: "rArm", recursively: false) {
            let swing = SCNAction.sequence([
                SCNAction.wait(duration: 1.8),
                SCNAction.rotateTo(x: -1.8, y: 0, z: -0.4, duration: 0.1),
                SCNAction.rotateTo(x: 0.5, y: 0, z: -0.4, duration: 0.08),
                SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.25),
                SCNAction.wait(duration: 1.5)
            ])
            rArm.runAction(SCNAction.repeatForever(swing), forKey: "swing")
        }

        if let player = scene.rootNode.childNode(withName: "player", recursively: true) {
            if let rArm = player.childNode(withName: "rArm", recursively: false) {
                let swing = SCNAction.sequence([
                    SCNAction.wait(duration: 2.5),
                    SCNAction.rotateTo(x: -2.0, y: 0, z: -0.4, duration: 0.12),
                    SCNAction.rotateTo(x: 0.6, y: 0, z: -0.4, duration: 0.1),
                    SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.3),
                    SCNAction.wait(duration: 1.2)
                ])
                rArm.runAction(SCNAction.repeatForever(swing), forKey: "swing")
            }
        }

        addStadiumStands(to: scene, depth: 11)
        addStadiumCrowd(to: scene, width: 8, depth: 11, color: UIColor(red: 0.85, green: 0.75, blue: 0.1, alpha: 1))
        addVeniceBeachWalls(to: scene)
        addParticles(to: scene, color: UIColor(red: 0.85, green: 0.75, blue: 0.1, alpha: 0.1), area: SCNVector3(8, 0.1, 11))

        return scene
    }

    // MARK: - Volleyball (Beach Court)

    private static func buildVolleyballScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.03, green: 0.02, blue: 0.01, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 4, 8), lookAt: SCNVector3(0, 1.5, 0))
        addLighting(to: scene, tint: UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1))

        addFloor(to: scene, color: UIColor(red: 0.76, green: 0.70, blue: 0.50, alpha: 1), reflectivity: 0.05)

        let sand = SCNBox(width: 9, height: 0.02, length: 9, chamferRadius: 0)
        let sandMat = SCNMaterial()
        sandMat.diffuse.contents = UIColor(red: 0.85, green: 0.78, blue: 0.58, alpha: 1)
        sandMat.roughness.contents = 0.98
        sand.materials = [sandMat]
        let sandNode = SCNNode(geometry: sand)
        sandNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(sandNode)

        let lineColor = UIColor.white.withAlphaComponent(0.5)
        func addLine(_ w: CGFloat, _ l: CGFloat, _ pos: SCNVector3) {
            let geo = SCNBox(width: w, height: 0.005, length: l, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = lineColor
            mat.emission.contents = lineColor
            geo.materials = [mat]
            let n = SCNNode(geometry: geo)
            n.position = pos
            scene.rootNode.addChildNode(n)
        }
        addLine(9, 0.04, SCNVector3(0, 0.025, -4.5))
        addLine(9, 0.04, SCNVector3(0, 0.025, 4.5))
        addLine(0.04, 9, SCNVector3(-4.5, 0.025, 0))
        addLine(0.04, 9, SCNVector3(4.5, 0.025, 0))

        for x in [-3.5, 3.5] as [Float] {
            let post = SCNCylinder(radius: 0.04, height: 2.6)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = UIColor(white: 0.8, alpha: 1)
            post.materials = [pMat]
            let pNode = SCNNode(geometry: post)
            pNode.position = SCNVector3(x, 1.3, 0)
            scene.rootNode.addChildNode(pNode)
        }
        let net = SCNBox(width: 7, height: 1.0, length: 0.02, chamferRadius: 0)
        let netMat = SCNMaterial()
        netMat.diffuse.contents = UIColor.white.withAlphaComponent(0.2)
        netMat.isDoubleSided = true
        net.materials = [netMat]
        let netNode = SCNNode(geometry: net)
        netNode.position = SCNVector3(0, 2.1, 0)
        scene.rootNode.addChildNode(netNode)

        let netBand = SCNBox(width: 7, height: 0.06, length: 0.025, chamferRadius: 0)
        let nbMat = SCNMaterial()
        nbMat.diffuse.contents = UIColor.white
        netBand.materials = [nbMat]
        let nbNode = SCNNode(geometry: netBand)
        nbNode.position = SCNVector3(0, 2.6, 0)
        scene.rootNode.addChildNode(nbNode)

        let playerColor = UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(-1.0, 0, 2.5), color: playerColor, name: "vPlayer1")
        addAvatar(to: scene, at: SCNVector3(1.5, 0, 3.5), color: playerColor, name: "vPlayer2")

        let oppColor = brandCyan
        addAvatar(to: scene, at: SCNVector3(1.0, 0, -2.5), color: oppColor, name: "vOpp1")
        addAvatar(to: scene, at: SCNVector3(-1.5, 0, -3.5), color: oppColor, name: "vOpp2")

        for name in ["vPlayer2", "vOpp1", "vOpp2"] {
            guard let node = scene.rootNode.childNode(withName: name, recursively: true) else { continue }
            let dx = Float.random(in: -1.0...1.0)
            let dz = Float.random(in: -0.5...0.5)
            let dur = Double.random(in: 1.5...2.5)
            let m1 = SCNAction.moveBy(x: CGFloat(dx), y: 0, z: CGFloat(dz), duration: dur)
            m1.timingMode = .easeInEaseOut
            let m2 = SCNAction.moveBy(x: CGFloat(-dx), y: 0, z: CGFloat(-dz), duration: dur)
            m2.timingMode = .easeInEaseOut
            node.runAction(SCNAction.repeatForever(SCNAction.sequence([m1, m2])), forKey: "shuffle")
        }

        let vball = SCNSphere(radius: 0.11)
        let vbMat = SCNMaterial()
        vbMat.diffuse.contents = UIColor.white
        vbMat.roughness.contents = 0.5
        vball.materials = [vbMat]
        let vbNode = SCNNode(geometry: vball)
        vbNode.position = SCNVector3(0, 2.5, 2)
        vbNode.name = "volleyball"
        scene.rootNode.addChildNode(vbNode)

        let vRallyAction = SCNAction.customAction(duration: 1000) { node, elapsed in
            let cycle = Float(elapsed.truncatingRemainder(dividingBy: 2.2))
            let phase = cycle / 2.2
            let t = phase < 0.5 ? phase * 2.0 : 2.0 - phase * 2.0
            let eased = t * t * (3.0 - 2.0 * t)
            let xWobble = sin(Float(elapsed) * 1.8) * 1.5
            let zStart: Float = 2.5
            let zEnd: Float = -2.5
            let yArc: Float = 2.2 + sin(eased * .pi) * 1.8
            node.position = SCNVector3(
                xWobble,
                yArc,
                zStart + (zEnd - zStart) * eased
            )
            let spin = Float(elapsed) * 6.0
            node.eulerAngles = SCNVector3(spin, spin * 0.5, 0)
        }
        vbNode.runAction(SCNAction.repeatForever(vRallyAction), forKey: "rally")
        addRallySnapToBall(in: scene, playerName: "vPlayer1", ballName: "volleyball", laneZ: 2.5, xLimit: -3.0...3.0)
        addRallySnapToBall(in: scene, playerName: "vOpp1", ballName: "volleyball", laneZ: -2.5, xLimit: -3.0...3.0)

        if let vp1 = scene.rootNode.childNode(withName: "vPlayer1", recursively: true),
           let rArm = vp1.childNode(withName: "rArm", recursively: false) {
            let spike = SCNAction.sequence([
                SCNAction.wait(duration: 2.0),
                SCNAction.rotateTo(x: -2.2, y: 0, z: -0.4, duration: 0.12),
                SCNAction.rotateTo(x: 0.5, y: 0, z: -0.4, duration: 0.08),
                SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.3),
                SCNAction.wait(duration: 1.8)
            ])
            rArm.runAction(SCNAction.repeatForever(spike), forKey: "spike")
        }

        addVeniceBeachWalls(to: scene)
        addVeniceBeachCrowd(to: scene, depth: 9)
        addParticles(to: scene, color: UIColor(red: 0.96, green: 0.75, blue: 0.14, alpha: 0.1), area: SCNVector3(9, 0.1, 9))

        return scene
    }

    // MARK: - Gymnastics (Arena with Apparatus)

    private static func buildGymnasticsScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)

        addCamera(to: scene, position: SCNVector3(3, 3.5, 6), lookAt: SCNVector3(0, 1, 0))
        addLighting(to: scene, tint: UIColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1))

        addFloor(to: scene, color: UIColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 1), reflectivity: 0.15)

        let mat = SCNBox(width: 7, height: 0.05, length: 7, chamferRadius: 0)
        let matMaterial = SCNMaterial()
        matMaterial.diffuse.contents = UIColor(red: 0.15, green: 0.12, blue: 0.30, alpha: 1)
        mat.materials = [matMaterial]
        let matNode = SCNNode(geometry: mat)
        matNode.position = SCNVector3(0, 0.025, 0)
        scene.rootNode.addChildNode(matNode)

        let gymBlue = UIColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1)
        let lineColor = gymBlue.withAlphaComponent(0.3)
        for z in [-3.5, 3.5] as [Float] {
            let border = SCNBox(width: 7, height: 0.005, length: 0.04, chamferRadius: 0)
            let bMat = SCNMaterial()
            bMat.diffuse.contents = lineColor
            bMat.emission.contents = lineColor
            border.materials = [bMat]
            let n = SCNNode(geometry: border)
            n.position = SCNVector3(0, 0.055, z)
            scene.rootNode.addChildNode(n)
        }
        for x in [-3.5, 3.5] as [Float] {
            let sideBorder = SCNBox(width: 0.04, height: 0.005, length: 7, chamferRadius: 0)
            let bMat = SCNMaterial()
            bMat.diffuse.contents = lineColor
            bMat.emission.contents = lineColor
            sideBorder.materials = [bMat]
            let n = SCNNode(geometry: sideBorder)
            n.position = SCNVector3(x, 0.055, 0)
            scene.rootNode.addChildNode(n)
        }

        let vaultTable = SCNBox(width: 0.6, height: 1.3, length: 1.2, chamferRadius: 0.04)
        let vtMat = SCNMaterial()
        vtMat.diffuse.contents = UIColor(red: 0.20, green: 0.18, blue: 0.40, alpha: 1)
        vtMat.emission.contents = gymBlue.withAlphaComponent(0.06)
        vaultTable.materials = [vtMat]
        let vtNode = SCNNode(geometry: vaultTable)
        vtNode.position = SCNVector3(3.0, 0.65, 0)
        scene.rootNode.addChildNode(vtNode)

        let springboard = SCNBox(width: 0.6, height: 0.15, length: 0.8, chamferRadius: 0.02)
        let sbMat = SCNMaterial()
        sbMat.diffuse.contents = UIColor(red: 0.3, green: 0.28, blue: 0.55, alpha: 1)
        springboard.materials = [sbMat]
        let sbNode = SCNNode(geometry: springboard)
        sbNode.position = SCNVector3(1.5, 0.075, 0)
        sbNode.eulerAngles.x = -0.1
        scene.rootNode.addChildNode(sbNode)

        let beamColor = UIColor(red: 0.6, green: 0.55, blue: 0.45, alpha: 1)
        let beam = SCNBox(width: 0.1, height: 0.08, length: 5, chamferRadius: 0.01)
        let beamMat = SCNMaterial()
        beamMat.diffuse.contents = beamColor
        beam.materials = [beamMat]
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(-2.5, 1.2, 0)
        scene.rootNode.addChildNode(beamNode)

        for z in [-2.5, 2.5] as [Float] {
            let leg = SCNCylinder(radius: 0.03, height: 1.2)
            let lMat = SCNMaterial()
            lMat.diffuse.contents = UIColor(white: 0.3, alpha: 1)
            leg.materials = [lMat]
            let lNode = SCNNode(geometry: leg)
            lNode.position = SCNVector3(-2.5, 0.6, z)
            scene.rootNode.addChildNode(lNode)
        }

        let barColor = UIColor(white: 0.7, alpha: 1)
        for (h, xOff) in [(2.5, -0.3), (1.7, 0.3)] as [(Float, Float)] {
            let bar = SCNCylinder(radius: 0.02, height: 2.5)
            let barMat = SCNMaterial()
            barMat.diffuse.contents = barColor
            barMat.metalness.contents = 0.7
            bar.materials = [barMat]
            let barNode = SCNNode(geometry: bar)
            barNode.position = SCNVector3(0 + xOff, Float(h), -3)
            barNode.eulerAngles.z = .pi / 2
            scene.rootNode.addChildNode(barNode)

            for x in [-1.25, 1.25] as [Float] {
                let support = SCNCylinder(radius: 0.025, height: CGFloat(h))
                let sMat = SCNMaterial()
                sMat.diffuse.contents = UIColor(white: 0.4, alpha: 1)
                support.materials = [sMat]
                let sNode = SCNNode(geometry: support)
                sNode.position = SCNVector3(x + xOff, Float(h) / 2, -3)
                scene.rootNode.addChildNode(sNode)
            }
        }

        addAvatar(to: scene, at: SCNVector3(0, 0, 0), color: gymBlue, name: "gymnast")

        let judges: [(Float, Float)] = [(-3, 4), (0, 4), (3, 4)]
        for (i, (jx, jz)) in judges.enumerated() {
            let judgeTable = SCNBox(width: 1.0, height: 0.8, length: 0.5, chamferRadius: 0.02)
            let jtMat = SCNMaterial()
            jtMat.diffuse.contents = UIColor(red: 0.12, green: 0.11, blue: 0.2, alpha: 1)
            judgeTable.materials = [jtMat]
            let jtNode = SCNNode(geometry: judgeTable)
            jtNode.position = SCNVector3(jx, 0.4, jz)
            scene.rootNode.addChildNode(jtNode)

            addAvatar(to: scene, at: SCNVector3(jx, 0, jz + 0.5), color: UIColor(white: 0.5, alpha: 1), name: "judge\(i)")
        }

        addGymnasticsAnimations(to: scene)

        addStadiumStands(to: scene, depth: 16)
        addStadiumCrowd(to: scene, width: 14, depth: 16, color: UIColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1))
        addArenaWalls(to: scene, wallColor: UIColor(red: 0.17, green: 0.16, blue: 0.26, alpha: 1), width: 16, depth: 16, height: 5)
        addParticles(to: scene, color: gymBlue.withAlphaComponent(0.1), area: SCNVector3(7, 0.1, 7))

        return scene
    }

    private static func addGymnasticsAnimations(to scene: SCNScene) {
        guard let gymnast = scene.rootNode.childNode(withName: "gymnast", recursively: true) else { return }

        let tumblePass1 = SCNAction.group([
            SCNAction.moveBy(x: 1.2, y: 0.6, z: 0, duration: 0.3),
            SCNAction.rotateBy(x: .pi * 2, y: 0, z: 0, duration: 0.3)
        ])
        tumblePass1.timingMode = .easeOut
        let land1 = SCNAction.moveBy(x: 0, y: -0.6, z: 0, duration: 0.15)
        land1.timingMode = .easeIn
        let squash1 = SCNAction.sequence([
            SCNAction.customAction(duration: 0.06) { node, _ in
                node.scale = SCNVector3(1.08, 0.92, 1.08)
            },
            SCNAction.customAction(duration: 0.12) { node, elapsed in
                let t = Float(elapsed / 0.12)
                node.scale = SCNVector3(1.08 - t * 0.08, 0.92 + t * 0.08, 1.08 - t * 0.08)
            }
        ])

        let tumblePass2 = SCNAction.group([
            SCNAction.moveBy(x: 1.0, y: 0.9, z: 0.3, duration: 0.35),
            SCNAction.rotateBy(x: .pi * 2, y: .pi, z: 0, duration: 0.35)
        ])
        tumblePass2.timingMode = .easeOut
        let land2 = SCNAction.moveBy(x: 0, y: -0.9, z: 0, duration: 0.18)
        land2.timingMode = .easeIn

        let returnHome = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.6)
        returnHome.timingMode = .easeInEaseOut
        let resetRotation = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
        resetRotation.timingMode = .easeInEaseOut

        let armRaise = SCNAction.customAction(duration: 0.2) { node, _ in
            if let lArm = node.childNode(withName: "lArm", recursively: false) {
                lArm.eulerAngles.z = 2.5
            }
            if let rArm = node.childNode(withName: "rArm", recursively: false) {
                rArm.eulerAngles.z = -2.5
            }
        }
        let armReset = SCNAction.customAction(duration: 0.2) { node, _ in
            if let lArm = node.childNode(withName: "lArm", recursively: false) {
                lArm.eulerAngles.z = 0.4
            }
            if let rArm = node.childNode(withName: "rArm", recursively: false) {
                rArm.eulerAngles.z = -0.4
            }
        }

        let tumble = SCNAction.sequence([
            SCNAction.wait(duration: 1.2),
            armRaise,
            tumblePass1, land1, squash1,
            SCNAction.wait(duration: 0.3),
            tumblePass2, land2, squash1,
            armReset,
            SCNAction.wait(duration: 0.5),
            armRaise,
            SCNAction.wait(duration: 0.3),
            armReset,
            SCNAction.wait(duration: 0.5),
            SCNAction.group([returnHome, resetRotation])
        ])
        gymnast.runAction(SCNAction.repeatForever(tumble), forKey: "tumble")
    }

    // MARK: - Shared Builders

    private static func addCamera(to scene: SCNScene, position: SCNVector3, lookAt: SCNVector3) {
        let node = SCNNode()
        node.camera = SCNCamera()
        node.camera?.fieldOfView = 48
        node.camera?.zNear = 0.1
        node.camera?.zFar = 100
        node.camera?.wantsHDR = true
        node.camera?.bloomIntensity = 0.6
        node.camera?.bloomThreshold = 0.6
        node.camera?.bloomBlurRadius = 10
        node.camera?.wantsDepthOfField = false
        node.camera?.vignettingIntensity = 0.6
        node.camera?.vignettingPower = 1.3
        node.camera?.contrast = 1.08
        node.camera?.saturation = 1.12
        node.camera?.colorGrading.contents = UIColor(red: 0.98, green: 0.96, blue: 1.0, alpha: 1)
        node.position = position
        node.look(at: lookAt)
        node.name = "mainCamera"
        scene.rootNode.addChildNode(node)
    }

    private static func addLighting(to scene: SCNScene, tint: UIColor) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1)
        ambient.light?.intensity = 400
        scene.rootNode.addChildNode(ambient)

        let spot = SCNNode()
        spot.light = SCNLight()
        spot.light?.type = .spot
        spot.light?.color = tint.withAlphaComponent(0.8)
        spot.light?.intensity = 1400
        spot.light?.spotInnerAngle = 25
        spot.light?.spotOuterAngle = 55
        spot.light?.castsShadow = true
        spot.light?.shadowRadius = 5
        spot.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        spot.light?.shadowSampleCount = 8
        spot.light?.shadowColor = UIColor.black.withAlphaComponent(0.6)
        spot.position = SCNVector3(2, 10, 4)
        spot.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(spot)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.color = UIColor(red: 0.08, green: 0.08, blue: 0.20, alpha: 1)
        fill.light?.intensity = 400
        fill.position = SCNVector3(-4, 3, 5)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .omni
        rim.light?.color = brandCyan
        rim.light?.intensity = 300
        rim.position = SCNVector3(3, 5, -3)
        scene.rootNode.addChildNode(rim)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor.white.withAlphaComponent(0.15)
        keyLight.light?.intensity = 200
        keyLight.eulerAngles = SCNVector3(-0.5, 0.3, 0)
        scene.rootNode.addChildNode(keyLight)
    }

    private static func addFloor(to scene: SCNScene, color: UIColor, reflectivity: CGFloat) {
        let floor = SCNFloor()
        floor.reflectivity = reflectivity
        floor.reflectionFalloffEnd = 3
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = color
        floorMat.roughness.contents = 0.9
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))
    }

    private static func addAvatar(to scene: SCNScene, at position: SCNVector3, color: UIColor, name: String = "avatar", preferMeshyHero: Bool = false) {
        if preferMeshyHero, let hero = FELMeshyBundledModels.loadElijahHeroNode() {
            let root = SCNNode()
            root.position = position
            root.name = name
            root.addChildNode(hero)
            scene.rootNode.addChildNode(root)
            addAvatarAmbientMotion(to: root)
            return
        }

        let root = SCNNode()
        root.position = position
        root.name = name

        let jointColor = brandCyan

        func limb(radius: CGFloat, height: CGFloat, isPrimary: Bool = true) -> SCNNode {
            let geo = SCNCapsule(capRadius: radius, height: height)
            let mat = SCNMaterial()
            mat.diffuse.contents = isPrimary ? color : color.withAlphaComponent(0.85)
            mat.emission.contents = color.withAlphaComponent(0.2)
            mat.metalness.contents = 0.55
            mat.roughness.contents = 0.3
            mat.fresnelExponent = 2.0
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.castsShadow = true
            return node
        }

        func joint(radius: CGFloat) -> SCNNode {
            let geo = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            mat.diffuse.contents = jointColor
            mat.emission.contents = jointColor.withAlphaComponent(0.4)
            mat.metalness.contents = 0.6
            mat.roughness.contents = 0.2
            mat.fresnelExponent = 2.5
            geo.materials = [mat]
            return SCNNode(geometry: geo)
        }

        let head = SCNNode()
        head.position = SCNVector3(0, 1.88, 0)
        head.name = "head"
        let headSphere = SCNSphere(radius: 0.11)
        let headMat = SCNMaterial()
        headMat.diffuse.contents = color
        headMat.emission.contents = color.withAlphaComponent(0.15)
        headMat.metalness.contents = 0.5
        headMat.roughness.contents = 0.35
        headMat.fresnelExponent = 2.0
        headSphere.materials = [headMat]
        head.geometry = headSphere

        let visor = SCNBox(width: 0.16, height: 0.04, length: 0.02, chamferRadius: 0.01)
        let visorMat = SCNMaterial()
        visorMat.diffuse.contents = jointColor
        visorMat.emission.contents = jointColor.withAlphaComponent(0.6)
        visorMat.metalness.contents = 0.8
        visorMat.roughness.contents = 0.1
        visor.materials = [visorMat]
        let visorNode = SCNNode(geometry: visor)
        visorNode.position = SCNVector3(0, 0, 0.1)
        head.addChildNode(visorNode)

        let neck = joint(radius: 0.035)
        neck.position = SCNVector3(0, 1.74, 0)
        neck.name = "neck"

        let upperTorso = limb(radius: 0.07, height: 0.35)
        upperTorso.position = SCNVector3(0, 1.52, 0)
        upperTorso.name = "torso"

        let lowerTorso = limb(radius: 0.06, height: 0.25, isPrimary: false)
        lowerTorso.position = SCNVector3(0, 1.25, 0)
        lowerTorso.name = "lowerTorso"

        let shoulderL = joint(radius: 0.04)
        shoulderL.position = SCNVector3(-0.22, 1.62, 0)
        let shoulderR = joint(radius: 0.04)
        shoulderR.position = SCNVector3(0.22, 1.62, 0)

        let lArm = limb(radius: 0.03, height: 0.32)
        lArm.position = SCNVector3(-0.22, 1.45, 0)
        lArm.eulerAngles.z = 0.35
        lArm.name = "lArm"

        let rArm = limb(radius: 0.03, height: 0.32)
        rArm.position = SCNVector3(0.22, 1.45, 0)
        rArm.eulerAngles.z = -0.35
        rArm.name = "rArm"

        let lForearm = limb(radius: 0.025, height: 0.28, isPrimary: false)
        lForearm.position = SCNVector3(-0.24, 1.18, 0.02)
        lForearm.eulerAngles.z = 0.25
        lForearm.name = "lForearm"

        let rForearm = limb(radius: 0.025, height: 0.28, isPrimary: false)
        rForearm.position = SCNVector3(0.24, 1.18, 0.02)
        rForearm.eulerAngles.z = -0.25
        rForearm.name = "rForearm"

        let hip = joint(radius: 0.055)
        hip.position = SCNVector3(0, 1.08, 0)
        hip.name = "hip"

        let lLeg = limb(radius: 0.04, height: 0.42)
        lLeg.position = SCNVector3(-0.09, 0.82, 0)
        lLeg.name = "lLeg"

        let rLeg = limb(radius: 0.04, height: 0.42)
        rLeg.position = SCNVector3(0.09, 0.82, 0)
        rLeg.name = "rLeg"

        let kneeL = joint(radius: 0.03)
        kneeL.position = SCNVector3(-0.09, 0.58, 0)
        let kneeR = joint(radius: 0.03)
        kneeR.position = SCNVector3(0.09, 0.58, 0)

        let lShin = limb(radius: 0.035, height: 0.38, isPrimary: false)
        lShin.position = SCNVector3(-0.09, 0.36, 0)
        lShin.name = "lShin"

        let rShin = limb(radius: 0.035, height: 0.38, isPrimary: false)
        rShin.position = SCNVector3(0.09, 0.36, 0)
        rShin.name = "rShin"

        let lFoot = SCNBox(width: 0.06, height: 0.03, length: 0.1, chamferRadius: 0.01)
        let footMat = SCNMaterial()
        footMat.diffuse.contents = color.withAlphaComponent(0.9)
        footMat.roughness.contents = 0.5
        lFoot.materials = [footMat]
        let lFootNode = SCNNode(geometry: lFoot)
        lFootNode.position = SCNVector3(-0.09, 0.15, 0.02)
        lFootNode.name = "lFoot"

        let rFoot = SCNBox(width: 0.06, height: 0.03, length: 0.1, chamferRadius: 0.01)
        rFoot.materials = [footMat]
        let rFootNode = SCNNode(geometry: rFoot)
        rFootNode.position = SCNVector3(0.09, 0.15, 0.02)
        rFootNode.name = "rFoot"

        for node in [head, neck, upperTorso, lowerTorso, shoulderL, shoulderR, lArm, rArm, lForearm, rForearm, hip, lLeg, rLeg, kneeL, kneeR, lShin, rShin, lFootNode, rFootNode] {
            root.addChildNode(node)
        }

        scene.rootNode.addChildNode(root)

        let avatarGlow = SCNNode()
        avatarGlow.light = SCNLight()
        avatarGlow.light?.type = .omni
        avatarGlow.light?.color = color.withAlphaComponent(0.5)
        avatarGlow.light?.intensity = 50
        avatarGlow.light?.attenuationStartDistance = 0.3
        avatarGlow.light?.attenuationEndDistance = 1.8
        avatarGlow.position = SCNVector3(0, 1.3, 0)
        root.addChildNode(avatarGlow)

        addAvatarAmbientMotion(to: root)
    }

    private static func addAvatarAmbientMotion(to root: SCNNode) {
        let breatheUp = SCNAction.moveBy(x: 0, y: 0.02, z: 0, duration: 1.6)
        breatheUp.timingMode = .easeInEaseOut
        let breatheDown = SCNAction.moveBy(x: 0, y: -0.02, z: 0, duration: 1.6)
        breatheDown.timingMode = .easeInEaseOut
        root.runAction(SCNAction.repeatForever(SCNAction.sequence([breatheUp, breatheDown])), forKey: "breathe")

        let weightShift = SCNAction.sequence([
            SCNAction.rotateTo(x: 0, y: 0, z: 0.015, duration: 2.0),
            SCNAction.rotateTo(x: 0, y: 0, z: -0.015, duration: 2.0)
        ])
        weightShift.timingMode = .easeInEaseOut
        root.runAction(SCNAction.repeatForever(weightShift), forKey: "weightShift")
    }

    private static func addBall(to scene: SCNScene, at position: SCNVector3, color: UIColor, useMeshyHoopBusBall: Bool = false) {
        let node: SCNNode
        if useMeshyHoopBusBall, let meshy = FELMeshyBundledModels.loadHoopBusBasketballNode() {
            node = meshy
            node.position = position
        } else {
            let geo = SCNSphere(radius: 0.12)
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.roughness.contents = 0.7
            geo.materials = [mat]
            node = SCNNode(geometry: geo)
            node.position = position
        }
        scene.rootNode.addChildNode(node)

        let bob = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.8),
            SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.8)
        ])
        node.runAction(SCNAction.repeatForever(bob))
    }

    private static func addParticles(to scene: SCNScene, color: UIColor, area: SCNVector3) {
        let emitter = SCNNode()
        let particles = SCNParticleSystem()
        particles.birthRate = 8
        particles.particleLifeSpan = 4
        particles.particleSize = 0.012
        particles.particleSizeVariation = 0.008
        particles.particleColor = color
        particles.emitterShape = SCNBox(width: CGFloat(area.x), height: CGFloat(area.y), length: CGFloat(area.z), chamferRadius: 0)
        particles.spreadingAngle = 12
        particles.particleVelocity = 0.15
        particles.particleVelocityVariation = 0.06
        particles.birthDirection = .constant
        particles.emittingDirection = SCNVector3(0, 1, 0)
        particles.blendMode = .additive
        emitter.addParticleSystem(particles)
        emitter.position = SCNVector3(0, 0.1, 0)
        scene.rootNode.addChildNode(emitter)
    }

    private static func addCourtLines(to scene: SCNScene, halfWidth: Float, halfDepth: Float) {
        let lineColor = brandBlue.withAlphaComponent(0.3)
        let hw = halfWidth
        let hd = halfDepth

        func makeLine(from: SCNVector3, to: SCNVector3) {
            let dx = to.x - from.x
            let dz = to.z - from.z
            let length = sqrt(dx * dx + dz * dz)
            let line = SCNBox(width: CGFloat(length), height: 0.005, length: 0.03, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = lineColor
            mat.emission.contents = lineColor
            line.materials = [mat]
            let node = SCNNode(geometry: line)
            node.position = SCNVector3((from.x + to.x) / 2, 0.025, (from.z + to.z) / 2)
            let angle = atan2(dz, dx)
            node.eulerAngles.y = -angle
            scene.rootNode.addChildNode(node)
        }

        makeLine(from: SCNVector3(-hw, 0, -hd), to: SCNVector3(-hw, 0, hd))
        makeLine(from: SCNVector3(hw, 0, -hd), to: SCNVector3(hw, 0, hd))
        makeLine(from: SCNVector3(-hw, 0, -hd), to: SCNVector3(hw, 0, -hd))
        makeLine(from: SCNVector3(-hw, 0, hd), to: SCNVector3(hw, 0, hd))
        makeLine(from: SCNVector3(0, 0, -hd), to: SCNVector3(0, 0, hd))

        let ringRadius = min(hw, hd) * 0.36
        let circle = SCNTorus(ringRadius: CGFloat(ringRadius), pipeRadius: 0.015)
        let cMat = SCNMaterial()
        cMat.diffuse.contents = lineColor
        cMat.emission.contents = lineColor
        circle.materials = [cMat]
        let cNode = SCNNode(geometry: circle)
        cNode.position = SCNVector3(0, 0.025, 0)
        scene.rootNode.addChildNode(cNode)
    }

    private static func addHoop(to scene: SCNScene, x: Float, flip: Bool = false) {
        let dir: Float = flip ? -1 : 1

        let pole = SCNCylinder(radius: 0.06, height: 3.05)
        let poleMat = SCNMaterial()
        poleMat.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        poleMat.metalness.contents = 0.8
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(x, 1.525, 0)
        scene.rootNode.addChildNode(poleNode)

        let bb = SCNBox(width: 1.2, height: 0.8, length: 0.04, chamferRadius: 0.02)
        let bbMat = SCNMaterial()
        bbMat.diffuse.contents = UIColor(white: 0.15, alpha: 1)
        bbMat.transparency = 0.7
        bb.materials = [bbMat]
        let bbNode = SCNNode(geometry: bb)
        bbNode.position = SCNVector3(x - dir * 0.3, 3.05, 0)
        scene.rootNode.addChildNode(bbNode)

        let rim = SCNTorus(ringRadius: 0.225, pipeRadius: 0.015)
        let rimMat = SCNMaterial()
        rimMat.diffuse.contents = UIColor.orange
        rimMat.emission.contents = UIColor.orange.withAlphaComponent(0.3)
        rimMat.metalness.contents = 0.9
        rim.materials = [rimMat]
        let rimNode = SCNNode(geometry: rim)
        rimNode.position = SCNVector3(x - dir * 0.65, 3.05, 0)
        scene.rootNode.addChildNode(rimNode)
    }

    private static func buildGoalNet(in scene: SCNScene, at position: SCNVector3) {
        let postColor = UIColor.white.withAlphaComponent(0.8)

        for x in [-1.2, 1.2] as [Float] {
            let post = SCNCylinder(radius: 0.05, height: 2.4)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = postColor
            pMat.emission.contents = UIColor.white.withAlphaComponent(0.1)
            post.materials = [pMat]
            let pNode = SCNNode(geometry: post)
            pNode.position = SCNVector3(x + position.x, 1.2, position.z)
            scene.rootNode.addChildNode(pNode)
        }

        let crossbar = SCNCylinder(radius: 0.05, height: 2.4)
        let cbMat = SCNMaterial()
        cbMat.diffuse.contents = postColor
        crossbar.materials = [cbMat]
        let cbNode = SCNNode(geometry: crossbar)
        cbNode.position = SCNVector3(position.x, 2.4, position.z)
        cbNode.eulerAngles.z = .pi / 2
        scene.rootNode.addChildNode(cbNode)

        let netGeo = SCNBox(width: 2.4, height: 2.4, length: 0.8, chamferRadius: 0)
        let netMat = SCNMaterial()
        netMat.diffuse.contents = UIColor.white.withAlphaComponent(0.08)
        netMat.isDoubleSided = true
        netGeo.materials = [netMat]
        let netNode = SCNNode(geometry: netGeo)
        netNode.position = SCNVector3(position.x, 1.2, position.z - 0.4)
        scene.rootNode.addChildNode(netNode)

        for i in 0..<8 {
            let netLine = SCNCylinder(radius: 0.005, height: 2.4)
            let nMat = SCNMaterial()
            nMat.diffuse.contents = UIColor.white.withAlphaComponent(0.15)
            netLine.materials = [nMat]
            let nNode = SCNNode(geometry: netLine)
            let xOffset = -1.0 + Float(i) * 0.286
            nNode.position = SCNVector3(xOffset + position.x, 1.2, position.z)
            scene.rootNode.addChildNode(nNode)
        }
    }

    private static func addArenaWalls(to scene: SCNScene, wallColor: UIColor, width: Float = 16, depth: Float = 14, height: Float = 4) {
        let halfW = width / 2
        let halfD = depth / 2
        let halfH = height / 2
        let thick: Float = 0.15

        func wallMat(_ color: UIColor) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.roughness.contents = 0.85
            m.isDoubleSided = true
            return m
        }

        let backWall = SCNBox(width: CGFloat(width + 0.4), height: CGFloat(height), length: CGFloat(thick), chamferRadius: 0)
        backWall.materials = [wallMat(wallColor)]
        let backNode = SCNNode(geometry: backWall)
        backNode.position = SCNVector3(0, halfH, -halfD)
        scene.rootNode.addChildNode(backNode)

        let frontWall = SCNBox(width: CGFloat(width + 0.4), height: CGFloat(height), length: CGFloat(thick), chamferRadius: 0)
        frontWall.materials = [wallMat(wallColor)]
        let frontNode = SCNNode(geometry: frontWall)
        frontNode.position = SCNVector3(0, halfH, halfD)
        scene.rootNode.addChildNode(frontNode)

        let leftWall = SCNBox(width: CGFloat(thick), height: CGFloat(height), length: CGFloat(depth + 0.4), chamferRadius: 0)
        leftWall.materials = [wallMat(wallColor)]
        let leftNode = SCNNode(geometry: leftWall)
        leftNode.position = SCNVector3(-halfW, halfH, 0)
        scene.rootNode.addChildNode(leftNode)

        let rightWall = SCNBox(width: CGFloat(thick), height: CGFloat(height), length: CGFloat(depth + 0.4), chamferRadius: 0)
        rightWall.materials = [wallMat(wallColor)]
        let rightNode = SCNNode(geometry: rightWall)
        rightNode.position = SCNVector3(halfW, halfH, 0)
        scene.rootNode.addChildNode(rightNode)
    }

    private static func addVeniceBeachWalls(to scene: SCNScene) {
        let wallHeight: CGFloat = 5
        let wallThickness: CGFloat = 0.15
        let sandColor = UIColor(red: 0.82, green: 0.75, blue: 0.55, alpha: 1)
        let boardwalkColor = UIColor(red: 0.38, green: 0.28, blue: 0.16, alpha: 1)
        let palmGreen = UIColor(red: 0.18, green: 0.50, blue: 0.18, alpha: 1)
        let oceanColor = UIColor(red: 0.10, green: 0.28, blue: 0.52, alpha: 1)
        let sunsetOrange = UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 0.4)

        func wallMaterial(_ color: UIColor) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.isDoubleSided = true
            return mat
        }

        let backWall = SCNBox(width: 18, height: wallHeight, length: wallThickness, chamferRadius: 0)
        backWall.materials = [wallMaterial(sandColor)]
        let backNode = SCNNode(geometry: backWall)
        backNode.position = SCNVector3(0, Float(wallHeight / 2), -7)
        scene.rootNode.addChildNode(backNode)

        let skyPanel = SCNBox(width: 18, height: wallHeight * 0.5, length: 0.01, chamferRadius: 0)
        let skyMat = SCNMaterial()
        skyMat.diffuse.contents = UIColor(red: 0.20, green: 0.42, blue: 0.72, alpha: 1)
        skyPanel.materials = [skyMat]
        let skyNode = SCNNode(geometry: skyPanel)
        skyNode.position = SCNVector3(0, Float(wallHeight * 0.75), -6.93)
        scene.rootNode.addChildNode(skyNode)

        let sunsetPanel = SCNBox(width: 18, height: wallHeight * 0.25, length: 0.01, chamferRadius: 0)
        let sunsetMat = SCNMaterial()
        sunsetMat.diffuse.contents = sunsetOrange
        sunsetMat.emission.contents = sunsetOrange
        sunsetPanel.materials = [sunsetMat]
        let sunsetNode = SCNNode(geometry: sunsetPanel)
        sunsetNode.position = SCNVector3(0, Float(wallHeight * 0.55), -6.92)
        scene.rootNode.addChildNode(sunsetNode)

        let frontWall = SCNBox(width: 18, height: wallHeight, length: wallThickness, chamferRadius: 0)
        frontWall.materials = [wallMaterial(oceanColor)]
        let frontNode = SCNNode(geometry: frontWall)
        frontNode.position = SCNVector3(0, Float(wallHeight / 2), 10)
        scene.rootNode.addChildNode(frontNode)

        let leftWall = SCNBox(width: wallThickness, height: wallHeight, length: 18, chamferRadius: 0)
        leftWall.materials = [wallMaterial(boardwalkColor)]
        let leftNode = SCNNode(geometry: leftWall)
        leftNode.position = SCNVector3(-9, Float(wallHeight / 2), 1.5)
        scene.rootNode.addChildNode(leftNode)

        let rightWall = SCNBox(width: wallThickness, height: wallHeight, length: 18, chamferRadius: 0)
        rightWall.materials = [wallMaterial(boardwalkColor)]
        let rightNode = SCNNode(geometry: rightWall)
        rightNode.position = SCNVector3(9, Float(wallHeight / 2), 1.5)
        scene.rootNode.addChildNode(rightNode)

        for x in stride(from: -7.0, through: 7.0, by: 3.5) {
            let trunk = SCNCylinder(radius: 0.09, height: 4.0)
            let tMat = SCNMaterial()
            tMat.diffuse.contents = UIColor(red: 0.42, green: 0.32, blue: 0.16, alpha: 1)
            tMat.roughness.contents = 0.9
            trunk.materials = [tMat]
            let tNode = SCNNode(geometry: trunk)
            tNode.position = SCNVector3(Float(x), 2.0, -6.5)
            tNode.eulerAngles.z = Float.random(in: -0.06...0.06)
            scene.rootNode.addChildNode(tNode)

            for leafOffset in [(-0.3, 0.5), (0.4, 0.3), (-0.1, -0.4), (0.2, 0.6)] as [(Float, Float)] {
                let frond = SCNSphere(radius: CGFloat(Float.random(in: 0.5...0.8)))
                let fMat = SCNMaterial()
                fMat.diffuse.contents = palmGreen
                fMat.emission.contents = palmGreen.withAlphaComponent(0.05)
                frond.materials = [fMat]
                let fNode = SCNNode(geometry: frond)
                fNode.position = SCNVector3(Float(x) + leafOffset.0, 4.2 + leafOffset.1 * 0.3, -6.5)
                fNode.scale = SCNVector3(1.3, 0.5, 1.3)
                scene.rootNode.addChildNode(fNode)
            }
        }

        let boardwalk = SCNBox(width: 18, height: 0.08, length: 2.0, chamferRadius: 0)
        let bwMat = SCNMaterial()
        bwMat.diffuse.contents = boardwalkColor
        bwMat.roughness.contents = 0.95
        boardwalk.materials = [bwMat]
        let bwNode = SCNNode(geometry: boardwalk)
        bwNode.position = SCNVector3(0, 0.04, -5.5)
        scene.rootNode.addChildNode(bwNode)

        let graffitiWall = SCNBox(width: 3.0, height: 2.0, length: 0.1, chamferRadius: 0)
        let gwMat = SCNMaterial()
        gwMat.diffuse.contents = UIColor(red: 0.25, green: 0.20, blue: 0.15, alpha: 1)
        gwMat.emission.contents = UIColor(red: 0.1, green: 0.05, blue: 0.0, alpha: 0.1)
        graffitiWall.materials = [gwMat]
        let gwNode = SCNNode(geometry: graffitiWall)
        gwNode.position = SCNVector3(-7, 1.0, -4.0)
        scene.rootNode.addChildNode(gwNode)

        let bench = SCNBox(width: 1.5, height: 0.08, length: 0.4, chamferRadius: 0.02)
        let benchMat = SCNMaterial()
        benchMat.diffuse.contents = UIColor(red: 0.45, green: 0.35, blue: 0.20, alpha: 1)
        bench.materials = [benchMat]
        let benchNode = SCNNode(geometry: bench)
        benchNode.position = SCNVector3(7, 0.4, -4.5)
        scene.rootNode.addChildNode(benchNode)
        for bx in [-0.5, 0.5] as [Float] {
            let leg = SCNCylinder(radius: 0.03, height: 0.4)
            let lMat = SCNMaterial()
            lMat.diffuse.contents = UIColor(white: 0.3, alpha: 1)
            leg.materials = [lMat]
            let lNode = SCNNode(geometry: leg)
            lNode.position = SCNVector3(7 + bx, 0.2, -4.5)
            scene.rootNode.addChildNode(lNode)
        }

        let sandFloor = SCNBox(width: 18, height: 0.01, length: 4, chamferRadius: 0)
        let sfMat = SCNMaterial()
        sfMat.diffuse.contents = UIColor(red: 0.80, green: 0.73, blue: 0.52, alpha: 0.6)
        sandFloor.materials = [sfMat]
        let sfNode = SCNNode(geometry: sandFloor)
        sfNode.position = SCNVector3(0, 0.005, -5)
        scene.rootNode.addChildNode(sfNode)
    }

    private static func addStadiumStands(to scene: SCNScene, depth: Float, sideBaseX: Float = 7) {
        let standColor = UIColor(red: 0.12, green: 0.1, blue: 0.15, alpha: 1)
        let crowdColor = UIColor(red: 0.25, green: 0.2, blue: 0.15, alpha: 0.5)

        for side in [-1.0, 1.0] as [Float] {
            for tier in 0..<3 {
                let h = Float(tier) * 0.8 + 0.4
                let x = side * (sideBaseX + Float(tier) * 0.5)
                let stand = SCNBox(width: 0.8, height: CGFloat(h), length: CGFloat(depth - 2), chamferRadius: 0)
                let sMat = SCNMaterial()
                sMat.diffuse.contents = standColor
                stand.materials = [sMat]
                let sNode = SCNNode(geometry: stand)
                sNode.position = SCNVector3(x, h / 2, 0)
                scene.rootNode.addChildNode(sNode)

                let crowd = SCNBox(width: 0.6, height: 0.3, length: CGFloat(depth - 3), chamferRadius: 0)
                let cMat = SCNMaterial()
                cMat.diffuse.contents = crowdColor
                cMat.emission.contents = crowdColor.withAlphaComponent(0.03)
                crowd.materials = [cMat]
                let cNode = SCNNode(geometry: crowd)
                cNode.position = SCNVector3(x, h + 0.15, 0)
                scene.rootNode.addChildNode(cNode)
            }
        }
    }

    private static func addStadiumLights(to scene: SCNScene, width: Float, depth: Float) {
        let lightPositions: [(Float, Float)] = [
            (-width / 2 - 1, -depth / 2 + 2),
            (width / 2 + 1, -depth / 2 + 2),
            (-width / 2 - 1, depth / 2 - 2),
            (width / 2 + 1, depth / 2 - 2)
        ]

        for (lx, lz) in lightPositions {
            let pole = SCNCylinder(radius: 0.06, height: 6)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = UIColor(white: 0.3, alpha: 1)
            pole.materials = [pMat]
            let pNode = SCNNode(geometry: pole)
            pNode.position = SCNVector3(lx, 3, lz)
            scene.rootNode.addChildNode(pNode)

            let lightHead = SCNBox(width: 0.5, height: 0.15, length: 0.3, chamferRadius: 0.02)
            let lhMat = SCNMaterial()
            lhMat.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
            lhMat.emission.contents = UIColor.white.withAlphaComponent(0.3)
            lightHead.materials = [lhMat]
            let lhNode = SCNNode(geometry: lightHead)
            lhNode.position = SCNVector3(lx, 6.1, lz)
            scene.rootNode.addChildNode(lhNode)
        }
    }

    // MARK: - Crowd & Spectator Systems

    private static func addStadiumCrowd(to scene: SCNScene, width: Float, depth: Float, color: UIColor) {
        let crowdColors: [UIColor] = [
            color.withAlphaComponent(0.6),
            UIColor(red: 0.9, green: 0.85, blue: 0.75, alpha: 0.5),
            UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.5),
            color.withAlphaComponent(0.4)
        ]

        for side in [-1.0, 1.0] as [Float] {
            for tier in 0..<3 {
                let h = Float(tier) * 0.8 + 0.4
                let x = side * (7.0 + Float(tier) * 0.5)
                let rowLength = depth - 3
                let personCount = Int(rowLength / 0.4)
                for p in 0..<personCount {
                    let pz = -rowLength / 2 + Float(p) * (rowLength / Float(personCount))
                    let pColor = crowdColors[p % crowdColors.count]
                    let person = SCNCapsule(capRadius: 0.08, height: 0.35)
                    let pMat = SCNMaterial()
                    pMat.diffuse.contents = pColor
                    pMat.emission.contents = pColor.withAlphaComponent(0.05)
                    person.materials = [pMat]
                    let pNode = SCNNode(geometry: person)
                    let xJitter = Float.random(in: -0.1...0.1)
                    pNode.position = SCNVector3(x + xJitter, h + 0.35, pz)
                    scene.rootNode.addChildNode(pNode)

                    let sway = SCNAction.sequence([
                        SCNAction.moveBy(x: CGFloat(Float.random(in: -0.03...0.03)), y: CGFloat(Float.random(in: 0...0.04)), z: 0, duration: Double.random(in: 1.5...2.5)),
                        SCNAction.moveBy(x: CGFloat(Float.random(in: -0.03...0.03)), y: CGFloat(Float.random(in: -0.04...0)), z: 0, duration: Double.random(in: 1.5...2.5))
                    ])
                    pNode.runAction(SCNAction.repeatForever(sway), forKey: "crowdSway")
                }
            }
        }

        let crowdNoise = SCNNode()
        let noiseParticles = SCNParticleSystem()
        noiseParticles.birthRate = 5
        noiseParticles.particleLifeSpan = 3
        noiseParticles.particleSize = 0.01
        noiseParticles.particleSizeVariation = 0.005
        noiseParticles.particleColor = color.withAlphaComponent(0.1)
        noiseParticles.emitterShape = SCNBox(width: CGFloat(width), height: 0.5, length: CGFloat(depth), chamferRadius: 0)
        noiseParticles.spreadingAngle = 20
        noiseParticles.particleVelocity = 0.1
        noiseParticles.birthDirection = .constant
        noiseParticles.emittingDirection = SCNVector3(0, 1, 0)
        noiseParticles.blendMode = .additive
        crowdNoise.addParticleSystem(noiseParticles)
        crowdNoise.position = SCNVector3(0, 2, 0)
        scene.rootNode.addChildNode(crowdNoise)
    }

    private static func addVeniceBeachCrowd(to scene: SCNScene, depth: Float) {
        let spectatorColors: [UIColor] = [
            UIColor(red: 0.85, green: 0.72, blue: 0.55, alpha: 1),
            UIColor(red: 0.3, green: 0.6, blue: 0.8, alpha: 1),
            UIColor(red: 0.9, green: 0.4, blue: 0.3, alpha: 1),
            UIColor(red: 0.2, green: 0.7, blue: 0.5, alpha: 1),
            UIColor(red: 0.95, green: 0.85, blue: 0.4, alpha: 1),
            UIColor(white: 0.5, alpha: 1)
        ]

        for side in [-1, 1] as [Int] {
            let xBase: Float = Float(side) * 5.5
            let count = Int(depth / 0.6)
            for i in 0..<count {
                let z = -depth / 2 + Float(i) * (depth / Float(count))
                let sColor = spectatorColors[i % spectatorColors.count]

                let person = SCNCapsule(capRadius: 0.07, height: 0.3)
                let pMat = SCNMaterial()
                pMat.diffuse.contents = sColor
                pMat.emission.contents = sColor.withAlphaComponent(0.08)
                person.materials = [pMat]
                let pNode = SCNNode(geometry: person)
                let xOff = Float.random(in: -0.3...0.3)
                pNode.position = SCNVector3(xBase + xOff, 0.18, z)
                scene.rootNode.addChildNode(pNode)

                let sway = SCNAction.sequence([
                    SCNAction.moveBy(x: CGFloat(Float.random(in: -0.02...0.02)), y: CGFloat(Float.random(in: 0...0.03)), z: 0, duration: Double.random(in: 1.8...3.0)),
                    SCNAction.moveBy(x: CGFloat(Float.random(in: -0.02...0.02)), y: CGFloat(Float.random(in: -0.03...0)), z: 0, duration: Double.random(in: 1.8...3.0))
                ])
                pNode.runAction(SCNAction.repeatForever(sway), forKey: "crowdSway")
            }
        }

        let backRowZ: Float = -depth / 2 - 1.5
        for i in 0..<8 {
            let x = -4.0 + Float(i) * 1.1
            let sColor = spectatorColors[i % spectatorColors.count]
            let person = SCNCapsule(capRadius: 0.07, height: 0.3)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = sColor
            person.materials = [pMat]
            let pNode = SCNNode(geometry: person)
            pNode.position = SCNVector3(x, 0.18, backRowZ)
            scene.rootNode.addChildNode(pNode)
        }
    }

    private static func addDojoSpectators(to scene: SCNScene) {
        let spectatorColor = UIColor(red: 0.3, green: 0.2, blue: 0.15, alpha: 0.8)
        let robeColors: [UIColor] = [
            UIColor(red: 0.15, green: 0.1, blue: 0.08, alpha: 1),
            UIColor(red: 0.9, green: 0.85, blue: 0.78, alpha: 1),
            UIColor(red: 0.5, green: 0.1, blue: 0.05, alpha: 1)
        ]

        let positions: [(Float, Float)] = [
            (-4.5, -2), (-4.5, -1), (-4.5, 0), (-4.5, 1), (-4.5, 2),
            (4.5, -2), (4.5, -1), (4.5, 0), (4.5, 1), (4.5, 2),
            (-3, -4.5), (-1.5, -4.5), (0, -4.5), (1.5, -4.5), (3, -4.5)
        ]

        for (i, (sx, sz)) in positions.enumerated() {
            let robe = robeColors[i % robeColors.count]
            let body = SCNCapsule(capRadius: 0.08, height: 0.35)
            let bMat = SCNMaterial()
            bMat.diffuse.contents = robe
            body.materials = [bMat]
            let bNode = SCNNode(geometry: body)
            bNode.position = SCNVector3(sx, 0.2, sz)
            scene.rootNode.addChildNode(bNode)

            let head = SCNSphere(radius: 0.06)
            let hMat = SCNMaterial()
            hMat.diffuse.contents = spectatorColor
            head.materials = [hMat]
            let hNode = SCNNode(geometry: head)
            hNode.position = SCNVector3(sx, 0.48, sz)
            scene.rootNode.addChildNode(hNode)
        }

        for side in [-1, 1] as [Float] {
            let banner = SCNBox(width: 0.05, height: 1.5, length: 0.6, chamferRadius: 0)
            let bannerMat = SCNMaterial()
            bannerMat.diffuse.contents = UIColor(red: 0.7, green: 0.1, blue: 0.05, alpha: 0.8)
            bannerMat.emission.contents = UIColor(red: 0.7, green: 0.1, blue: 0.05, alpha: 0.1)
            banner.materials = [bannerMat]
            let bannerNode = SCNNode(geometry: banner)
            bannerNode.position = SCNVector3(side * 5.5, 2.5, 0)
            scene.rootNode.addChildNode(bannerNode)
        }
    }

    private static func addGolfGallery(to scene: SCNScene) {
        let galleryColors: [UIColor] = [
            UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1),
            UIColor(red: 0.9, green: 0.85, blue: 0.75, alpha: 1),
            UIColor(red: 0.7, green: 0.4, blue: 0.3, alpha: 1),
            UIColor(red: 0.4, green: 0.6, blue: 0.4, alpha: 1),
            UIColor(white: 0.6, alpha: 1)
        ]

        let ropePositions: [(Float, Float, Float, Float)] = [
            (-4.0, 0.4, 4.0, 0.4),
            (-4.0, -3.5, 4.0, -3.5)
        ]
        for (x1, z1, x2, z2) in ropePositions {
            let ropeLen = sqrt((x2 - x1) * (x2 - x1) + (z2 - z1) * (z2 - z1))
            let rope = SCNCylinder(radius: 0.008, height: CGFloat(ropeLen))
            let rMat = SCNMaterial()
            rMat.diffuse.contents = UIColor(red: 0.8, green: 0.75, blue: 0.6, alpha: 0.6)
            rope.materials = [rMat]
            let rNode = SCNNode(geometry: rope)
            rNode.position = SCNVector3((x1 + x2) / 2, 0.5, (z1 + z2) / 2)
            rNode.eulerAngles.z = .pi / 2
            scene.rootNode.addChildNode(rNode)

            for i in 0..<6 {
                let t = Float(i) / 5.0
                let px = x1 + (x2 - x1) * t + Float.random(in: -0.2...0.2)
                let pz = (z1 + z2) / 2 + Float(z1 < 0 ? -1 : 1) * Float.random(in: 0.5...1.2)
                let gColor = galleryColors[i % galleryColors.count]
                let person = SCNCapsule(capRadius: 0.07, height: 0.3)
                let pMat = SCNMaterial()
                pMat.diffuse.contents = gColor
                person.materials = [pMat]
                let pNode = SCNNode(geometry: person)
                pNode.position = SCNVector3(px, 0.18, pz)
                scene.rootNode.addChildNode(pNode)
            }
        }

        for i in 0..<4 {
            let x = Float.random(in: 4.0...5.5)
            let z = Float.random(in: -2.0...2.0)
            let gColor = galleryColors[i % galleryColors.count]
            let person = SCNCapsule(capRadius: 0.07, height: 0.3)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = gColor
            person.materials = [pMat]
            let pNode = SCNNode(geometry: person)
            pNode.position = SCNVector3(x, 0.18, z)
            scene.rootNode.addChildNode(pNode)
        }
    }

    private static func addFootballEndzonePaint(to scene: SCNScene) {
        let letterColor = UIColor.white.withAlphaComponent(0.15)
        for (text, zPos) in [("HOME", Float(-12.0)), ("AWAY", Float(8.0))] as [(String, Float)] {
            let _ = text
            let paint = SCNBox(width: 4, height: 0.003, length: 1.5, chamferRadius: 0)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = letterColor
            pMat.emission.contents = letterColor
            paint.materials = [pMat]
            let pNode = SCNNode(geometry: paint)
            pNode.position = SCNVector3(0, 0.025, zPos)
            scene.rootNode.addChildNode(pNode)
        }

        let sidelineColor = UIColor.white.withAlphaComponent(0.25)
        for x in [-6.0, 6.0] as [Float] {
            let sideline = SCNBox(width: 0.04, height: 0.005, length: 20, chamferRadius: 0)
            let slMat = SCNMaterial()
            slMat.diffuse.contents = sidelineColor
            slMat.emission.contents = sidelineColor
            sideline.materials = [slMat]
            let slNode = SCNNode(geometry: sideline)
            slNode.position = SCNVector3(x, 0.025, -3)
            scene.rootNode.addChildNode(slNode)
        }
    }

    private static func addRallySnapToBall(
        in scene: SCNScene,
        playerName: String,
        ballName: String,
        laneZ: Float,
        xLimit: ClosedRange<Float>
    ) {
        guard let player = scene.rootNode.childNode(withName: playerName, recursively: true),
              let ball = scene.rootNode.childNode(withName: ballName, recursively: true) else { return }
        let smoothingAlpha = Float(min(1.0, (1.0 / 60.0) / max(0.05, rallySnapSmoothingWindow)))
        let snap = SCNAction.customAction(duration: 1000) { node, _ in
            let presentedBall = ball.presentation.position
            let clampedBallX = min(xLimit.upperBound, max(xLimit.lowerBound, presentedBall.x))
            let current = node.presentation.position
            let nextX = current.x + (clampedBallX - current.x) * smoothingAlpha
            let nextZ = current.z + (laneZ - current.z) * smoothingAlpha
            node.position = SCNVector3(nextX, node.position.y, nextZ)

            let dx = presentedBall.x - nextX
            let dz = presentedBall.z - nextZ
            if abs(dx) > 0.01 || abs(dz) > 0.01 {
                node.eulerAngles.y = atan2(dx, dz)
            }
        }
        player.runAction(SCNAction.repeatForever(snap), forKey: "snapToBall")
    }

    private static func moveTowards(current: SCNVector3, target: SCNVector3, maxDistanceDelta: Float) -> SCNVector3 {
        let dx = target.x - current.x
        let dy = target.y - current.y
        let dz = target.z - current.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)
        guard distance > 0.0001 else { return target }
        if distance <= maxDistanceDelta { return target }
        let scale = maxDistanceDelta / distance
        return SCNVector3(
            current.x + dx * scale,
            current.y + dy * scale,
            current.z + dz * scale
        )
    }

    // MARK: - Cinematic Impact Effects

    static func triggerHitStop(on node: SCNNode, duration: Double = AvatarStateMachine.hitStopDuration) {
        node.isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            node.isPaused = false
        }
    }

    static func triggerImpactRing(in scene: SCNScene, at position: SCNVector3, color: UIColor) {
        let ring = SCNNode()
        let ringGeo = SCNTorus(ringRadius: 0.01, pipeRadius: 0.005)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = color
        ringMat.emission.contents = color
        ringGeo.materials = [ringMat]
        ring.geometry = ringGeo
        ring.position = position
        scene.rootNode.addChildNode(ring)

        let expand = SCNAction.group([
            SCNAction.scale(to: 8, duration: 0.5),
            SCNAction.fadeOut(duration: 0.5)
        ])
        ring.runAction(SCNAction.sequence([expand, SCNAction.removeFromParentNode()]))
    }

    static func triggerCinematicSlowMo(in scene: SCNScene, duration: Double = 1.0, timeScale: Double = 0.2) {
        scene.physicsWorld.speed = CGFloat(timeScale)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            scene.physicsWorld.speed = 1.0
            SCNTransaction.commit()
        }
    }

    static func updateDunkCamera(in scene: SCNScene, phase: DunkPhase, jumpHeight: Double) {
        guard let camera = scene.rootNode.childNode(withName: "mainCamera", recursively: true) else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        switch phase {
        case .approach:
            camera.camera?.fieldOfView = CGFloat(DunkCameraConfig.normalFOV)
            camera.position = SCNVector3(3, 4, 8)
        case .launch:
            camera.camera?.fieldOfView = CGFloat(DunkCameraConfig.gatherFOV)
            camera.position = SCNVector3(2.5, 3.5, 7)
        case .airborne:
            camera.camera?.fieldOfView = CGFloat(DunkCameraConfig.flightFOV)
            let heightOffset = Float(jumpHeight) * 1.5
            camera.position = SCNVector3(4, 4.5 + heightOffset, 9)
        case .landing, .scored:
            camera.camera?.fieldOfView = CGFloat(DunkCameraConfig.impactFOV)
            camera.position = SCNVector3(1.5, 1.5, 5)
        case .idle:
            camera.camera?.fieldOfView = CGFloat(DunkCameraConfig.normalFOV)
            camera.position = SCNVector3(3, 4, 8)
        }
        SCNTransaction.commit()
    }

    static func triggerRimDistortion(in scene: SCNScene, config: RimDistortionConfig) {
        guard let hoop = scene.rootNode.childNode(withName: "hoop", recursively: true) ??
              scene.rootNode.childNodes(passingTest: { node, _ in
                  node.geometry is SCNTorus && node.position.y > 2.5
              }).first else { return }
        let backboardNodes = scene.rootNode.childNodes(passingTest: { node, _ in
            guard let box = node.geometry as? SCNBox else { return false }
            return box.width > 1.0 && box.height > 0.5 && node.position.y > 2.5
        })
        let flexAmount = Float(config.flexAmount)
        let flexAction = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: CGFloat(-flexAmount * 0.5), z: CGFloat(flexAmount), duration: 0.06),
            SCNAction.moveBy(x: 0, y: CGFloat(flexAmount * 0.3), z: CGFloat(-flexAmount * 0.7), duration: 0.08),
            SCNAction.moveBy(x: 0, y: CGFloat(flexAmount * 0.15), z: CGFloat(-flexAmount * 0.2), duration: 0.06),
            SCNAction.moveBy(x: 0, y: CGFloat(flexAmount * 0.05), z: CGFloat(-flexAmount * 0.1), duration: 0.04)
        ])
        hoop.runAction(flexAction, forKey: "rimFlex")
        for bb in backboardNodes {
            let bbFlex = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0, z: CGFloat(config.backboardBounce * 0.3), duration: 0.05),
                SCNAction.moveBy(x: 0, y: 0, z: CGFloat(-config.backboardBounce * 0.25), duration: 0.08),
                SCNAction.moveBy(x: 0, y: 0, z: CGFloat(-config.backboardBounce * 0.05), duration: 0.06)
            ])
            bb.runAction(bbFlex, forKey: "backboardFlex")
        }
    }

    static func triggerDunkImpactParticles(in scene: SCNScene, at position: SCNVector3, modifier: DunkModifier) {
        let emitter = SCNNode()
        let particles = SCNParticleSystem()
        particles.birthRate = modifier == .power ? 60 : (modifier == .signature ? 80 : 30)
        particles.particleLifeSpan = 0.6
        particles.particleSize = 0.02
        particles.particleSizeVariation = 0.015
        let color: UIColor
        switch modifier {
        case .standard: color = UIColor.orange.withAlphaComponent(0.6)
        case .flashy: color = UIColor(red: 0.8, green: 0.2, blue: 0.9, alpha: 0.7)
        case .power: color = UIColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 0.8)
        case .signature: color = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 0.9)
        }
        particles.particleColor = color
        particles.emitterShape = SCNSphere(radius: 0.3)
        particles.spreadingAngle = 180
        particles.particleVelocity = 2.0
        particles.particleVelocityVariation = 1.0
        particles.blendMode = .additive
        particles.loops = false
        particles.emissionDuration = 0.15
        emitter.addParticleSystem(particles)
        emitter.position = position
        scene.rootNode.addChildNode(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            emitter.removeFromParentNode()
        }
    }

    static func triggerVanishEffect(in scene: SCNScene, at position: SCNVector3, color: UIColor) {
        let flash = SCNNode()
        let flashGeo = SCNSphere(radius: 0.5)
        let flashMat = SCNMaterial()
        flashMat.diffuse.contents = color
        flashMat.emission.contents = color
        flashMat.transparency = 0.8
        flashGeo.materials = [flashMat]
        flash.geometry = flashGeo
        flash.position = position
        scene.rootNode.addChildNode(flash)

        let expand = SCNAction.group([
            SCNAction.scale(to: 3, duration: 0.2),
            SCNAction.fadeOut(duration: 0.2)
        ])
        flash.runAction(SCNAction.sequence([expand, SCNAction.removeFromParentNode()]))
    }

    static func triggerScoreEffect(in scene: SCNScene, at position: SCNVector3, color: UIColor, isCritical: Bool) {
        let burstCount: CGFloat = isCritical ? 50 : 20
        let emitter = SCNNode()
        let particles = SCNParticleSystem()
        particles.birthRate = burstCount
        particles.particleLifeSpan = isCritical ? 1.0 : 0.6
        particles.particleSize = isCritical ? 0.025 : 0.015
        particles.particleSizeVariation = 0.01
        particles.particleColor = color
        particles.emitterShape = SCNSphere(radius: 0.15)
        particles.spreadingAngle = 180
        particles.particleVelocity = isCritical ? 3.0 : 1.5
        particles.particleVelocityVariation = 0.5
        particles.blendMode = .additive
        particles.loops = false
        particles.emissionDuration = 0.1
        emitter.addParticleSystem(particles)
        emitter.position = position
        scene.rootNode.addChildNode(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            emitter.removeFromParentNode()
        }

        if isCritical {
            triggerImpactRing(in: scene, at: position, color: color)
        }
    }

    static func triggerAvatarJump(in scene: SCNScene, avatarName: String, height: Float, duration: Double) {
        guard let avatar = scene.rootNode.childNode(withName: avatarName, recursively: true) else { return }
        let originalY = avatar.position.y

        let jumpUp = SCNAction.moveBy(x: 0, y: CGFloat(height), z: 0, duration: duration * 0.4)
        jumpUp.timingMode = .easeOut
        let hangTime = SCNAction.wait(duration: duration * 0.2)
        let fallDown = SCNAction.move(to: SCNVector3(avatar.position.x, originalY, avatar.position.z), duration: duration * 0.3)
        fallDown.timingMode = .easeIn
        let land = SCNAction.sequence([
            SCNAction.customAction(duration: 0.06) { node, _ in
                node.scale = SCNVector3(1.08, 0.92, 1.08)
            },
            SCNAction.customAction(duration: 0.1) { node, elapsed in
                let t = Float(elapsed / 0.1)
                node.scale = SCNVector3(1.08 - t * 0.08, 0.92 + t * 0.08, 1.08 - t * 0.08)
            }
        ])

        avatar.runAction(SCNAction.sequence([jumpUp, hangTime, fallDown, land]), forKey: "jump")
    }

    static func triggerAvatarAttack(in scene: SCNScene, avatarName: String, direction: SCNVector3, intensity: Float) {
        guard let avatar = scene.rootNode.childNode(withName: avatarName, recursively: true) else { return }

        let lunge = SCNAction.moveBy(
            x: CGFloat(direction.x * intensity * 0.3),
            y: 0,
            z: CGFloat(direction.z * intensity * 0.3),
            duration: 0.08
        )
        lunge.timingMode = .easeOut
        let recover = SCNAction.moveBy(
            x: CGFloat(-direction.x * intensity * 0.3),
            y: 0,
            z: CGFloat(-direction.z * intensity * 0.3),
            duration: 0.15
        )
        recover.timingMode = .easeInEaseOut

        avatar.runAction(SCNAction.sequence([lunge, recover]), forKey: "attack")

        if let rArm = avatar.childNode(withName: "rArm", recursively: false) {
            let strike = SCNAction.sequence([
                SCNAction.rotateTo(x: CGFloat(-2.0 * Double(intensity)), y: 0, z: -0.4, duration: 0.06),
                SCNAction.rotateTo(x: CGFloat(0.8 * Double(intensity)), y: 0, z: -0.4, duration: 0.05),
                SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.12)
            ])
            rArm.runAction(strike, forKey: "strikeArm")
        }
    }

    static func triggerFloorImpact(in scene: SCNScene, at position: SCNVector3, intensity: Float) {
        let shockwave = SCNNode()
        let ring = SCNCylinder(radius: 0.01, height: 0.005)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
        mat.emission.contents = UIColor.white.withAlphaComponent(0.2)
        ring.materials = [mat]
        shockwave.geometry = ring
        shockwave.position = SCNVector3(position.x, 0.03, position.z)
        scene.rootNode.addChildNode(shockwave)

        let expand = SCNAction.group([
            SCNAction.scale(to: CGFloat(80 * intensity), duration: 0.4),
            SCNAction.fadeOut(duration: 0.4)
        ])
        shockwave.runAction(SCNAction.sequence([expand, SCNAction.removeFromParentNode()]))
    }

    static func triggerCameraShake(in scene: SCNScene, intensity: Float, duration: Double) {
        guard let camera = scene.rootNode.childNode(withName: "mainCamera", recursively: true) else { return }
        let originalPos = camera.position

        let shakeCount = Int(duration / 0.04)
        var actions: [SCNAction] = []
        for i in 0..<shakeCount {
            let decay = Float(1.0 - Double(i) / Double(shakeCount))
            let dx = Float.random(in: -intensity...intensity) * decay
            let dy = Float.random(in: -intensity * 0.5...intensity * 0.5) * decay
            actions.append(SCNAction.moveBy(x: CGFloat(dx), y: CGFloat(dy), z: 0, duration: 0.04))
        }
        actions.append(SCNAction.move(to: originalPos, duration: 0.08))
        camera.runAction(SCNAction.sequence(actions), forKey: "cameraShake")
    }
}

final class HomeRunDerbyManager: NSObject, SCNPhysicsContactDelegate {
    struct HitResult {
        let estimatedDistanceFeet: Int
        let timingErrorSeconds: Double
        let grade: TimingGrade
    }

    enum TimingGrade: String {
        case perfect
        case great
        case early
        case late
        case missed
    }

    private enum PhysicsMask {
        static let baseball = 1 << 8
        static let bat = 1 << 9
    }

    private static let managerStorageKey = "homeRunDerbyManager"

    private weak var scene: SCNScene?
    private let pitcherHandNodeName: String
    private let batNodeName: String

    private var pitchReleaseTimes: [String: CFTimeInterval] = [:]
    private let pitchLoopKey = "homeRunDerbyPitchLoop"
    private let batSwingKey = "homeRunDerbyBatSwing"

    private let pitchVelocity = SCNVector3(0.0, -0.05, 15.5)
    private let pitchInterval: TimeInterval = 2.0
    private let nominalContactTime: TimeInterval = 0.24

    var onHitResult: ((HitResult) -> Void)?

    private init(scene: SCNScene, pitcherHandNodeName: String, batNodeName: String) {
        self.scene = scene
        self.pitcherHandNodeName = pitcherHandNodeName
        self.batNodeName = batNodeName
        super.init()
        scene.physicsWorld.contactDelegate = self
    }

    private static let associatedKey = UnsafeRawPointer(bitPattern: "HomeRunDerbyManager".hashValue)!

    static func installIfNeeded(
        in scene: SCNScene,
        pitcherHandNodeName: String = "pitcherHand",
        batNodeName: String = "bat"
    ) {
        if let existing = objc_getAssociatedObject(scene, associatedKey) as? HomeRunDerbyManager {
            existing.startPitchLoop()
            return
        }

        let manager = HomeRunDerbyManager(
            scene: scene,
            pitcherHandNodeName: pitcherHandNodeName,
            batNodeName: batNodeName
        )
        objc_setAssociatedObject(scene, associatedKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        manager.configureBatCollider()
        manager.startPitchLoop()
    }

    func startPitchLoop() {
        guard let scene else { return }
        guard scene.rootNode.action(forKey: pitchLoopKey) == nil else { return }

        let pitch = SCNAction.run { [weak self] _ in
            self?.spawnAndThrowPitch()
        }
        let loop = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.wait(duration: 0.4),
                pitch,
                SCNAction.wait(duration: pitchInterval)
            ])
        )
        scene.rootNode.runAction(loop, forKey: pitchLoopKey)
        startBatSwingLoopIfNeeded()
    }

    private func configureBatCollider() {
        guard let scene,
              let bat = scene.rootNode.childNode(withName: batNodeName, recursively: true) else { return }
        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: bat))
        body.categoryBitMask = PhysicsMask.bat
        body.contactTestBitMask = PhysicsMask.baseball
        body.collisionBitMask = PhysicsMask.baseball
        body.isAffectedByGravity = false
        bat.physicsBody = body
    }

    private func startBatSwingLoopIfNeeded() {
        guard let scene,
              let bat = scene.rootNode.childNode(withName: batNodeName, recursively: true) else { return }
        guard bat.action(forKey: batSwingKey) == nil else { return }

        let load = SCNAction.rotateTo(x: 0.18, y: 0.26, z: 0.75, duration: 0.08)
        let swing = SCNAction.rotateTo(x: 0.03, y: -0.2, z: -0.65, duration: 0.08)
        let recover = SCNAction.rotateTo(x: 0.2, y: 0.2, z: 0.45, duration: 0.12)
        let batLoop = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.wait(duration: 0.58),
                load,
                swing,
                recover,
                SCNAction.wait(duration: pitchInterval - 0.25)
            ])
        )
        bat.runAction(batLoop, forKey: batSwingKey)
    }

    private func spawnAndThrowPitch() {
        guard let scene else { return }

        let spawnNode = scene.rootNode.childNode(withName: pitcherHandNodeName, recursively: true)
        let spawnPosition = spawnNode?.presentation.position ?? SCNVector3(0, 1.55, -0.78)
        let baseball = makeBaseballNode()
        baseball.position = spawnPosition
        baseball.name = "derbyBall-\(UUID().uuidString)"
        pitchReleaseTimes[baseball.name ?? ""] = CACurrentMediaTime()
        scene.rootNode.addChildNode(baseball)

        baseball.physicsBody?.velocity = pitchVelocity
        baseball.physicsBody?.angularVelocity = SCNVector4(0, 1, 0.1, 22)
        let timeout = SCNAction.sequence([
            SCNAction.wait(duration: 3.0),
            SCNAction.removeFromParentNode()
        ])
        baseball.runAction(timeout, forKey: "timeout")
    }

    private func makeBaseballNode() -> SCNNode {
        let ball = SCNSphere(radius: 0.04)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.roughness.contents = 0.55
        ball.materials = [mat]
        let node = SCNNode(geometry: ball)
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ball, options: nil))
        body.mass = 0.145
        body.isAffectedByGravity = false
        body.damping = 0
        body.angularDamping = 0.05
        body.categoryBitMask = PhysicsMask.baseball
        body.contactTestBitMask = PhysicsMask.bat
        body.collisionBitMask = PhysicsMask.bat
        node.physicsBody = body
        return node
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        guard let ballNode = baseballNode(from: contact) else { return }
        handleBatCollision(for: ballNode)
    }

    private func baseballNode(from contact: SCNPhysicsContact) -> SCNNode? {
        if contact.nodeA.physicsBody?.categoryBitMask == PhysicsMask.baseball {
            return contact.nodeA
        }
        if contact.nodeB.physicsBody?.categoryBitMask == PhysicsMask.baseball {
            return contact.nodeB
        }
        return nil
    }

    private func handleBatCollision(for baseball: SCNNode) {
        guard let id = baseball.name else { return }
        let releasedAt = pitchReleaseTimes[id] ?? CACurrentMediaTime()
        let elapsed = CACurrentMediaTime() - releasedAt
        let timingError = elapsed - nominalContactTime
        let result = estimateResult(fromTimingError: timingError)
        onHitResult?(result)

        let launchSpeed = max(16.0, 22.0 + Double(result.estimatedDistanceFeet) * 0.12)
        let launchAngleY = Float.random(in: -0.22...0.22)
        let launchVector = SCNVector3(
            sin(launchAngleY) * Float(launchSpeed * 0.15),
            Float(6.5 + Double(result.estimatedDistanceFeet) * 0.03),
            Float(launchSpeed)
        )
        baseball.removeAction(forKey: "timeout")
        baseball.physicsBody?.isAffectedByGravity = true
        baseball.physicsBody?.velocity = launchVector
        baseball.physicsBody?.angularVelocity = SCNVector4(0.6, 1, 0.2, 35)
        baseball.runAction(
            SCNAction.sequence([
                SCNAction.wait(duration: 3.5),
                SCNAction.removeFromParentNode()
            ]),
            forKey: "homeRunCleanup"
        )
        pitchReleaseTimes.removeValue(forKey: id)
    }

    private func estimateResult(fromTimingError timingError: Double) -> HitResult {
        let absError = abs(timingError)
        let perfectWindow = 0.03
        let greatWindow = 0.07
        let playableWindow = 0.12

        let grade: TimingGrade
        if absError <= perfectWindow {
            grade = .perfect
        } else if absError <= greatWindow {
            grade = .great
        } else if absError <= playableWindow {
            grade = timingError < 0 ? .early : .late
        } else {
            grade = .missed
        }

        let contactQuality = max(0, 1.0 - (absError / 0.22))
        let baseDistance = 250.0 + contactQuality * 210.0
        let directionalPenalty = timingError < -0.08 || timingError > 0.1 ? 35.0 : 0.0
        let distance = max(120, Int(baseDistance - directionalPenalty))
        return HitResult(
            estimatedDistanceFeet: distance,
            timingErrorSeconds: timingError,
            grade: grade
        )
    }
}
