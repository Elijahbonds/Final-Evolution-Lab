import SceneKit
import UIKit

struct GameSceneFactory {
    private static let brandBlue = UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)
    private static let brandCyan = UIColor(red: 0, green: 0.95, blue: 0.9, alpha: 1)

    static func buildScene(for mode: GameModeId) -> SCNScene {
        switch mode {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3:
            return buildBasketballScene()
        case .karate:
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
        }
    }

    // MARK: - Basketball (Venice Beach Court)

    private static func buildBasketballScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)

        addCamera(to: scene, position: SCNVector3(4, 3.5, 6), lookAt: SCNVector3(0, 1.5, 0))
        addBasicLighting(to: scene, tint: brandBlue)

        let floor = SCNFloor()
        floor.reflectivity = 0.15
        floor.reflectionFalloffEnd = 3
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 1)
        floorMat.roughness.contents = 0.9
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let court = SCNBox(width: 8, height: 0.02, length: 5, chamferRadius: 0)
        let courtMat = SCNMaterial()
        courtMat.diffuse.contents = UIColor(red: 0.12, green: 0.08, blue: 0.04, alpha: 1)
        courtMat.roughness.contents = 0.9
        court.materials = [courtMat]
        let courtNode = SCNNode(geometry: court)
        courtNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(courtNode)

        addCourtLines(to: scene)
        addHoop(to: scene, x: 3.5)
        addHoop(to: scene, x: -3.5, flip: true)
        addAvatar(to: scene, at: SCNVector3(-1.5, 0, 0), color: brandBlue)
        addBall(to: scene, at: SCNVector3(-1.5, 1.4, 0), color: UIColor(red: 0.8, green: 0.35, blue: 0.1, alpha: 1))
        addVeniceBeachWalls(to: scene)
        addParticles(to: scene, color: brandCyan.withAlphaComponent(0.2), area: SCNVector3(8, 0.1, 5))

        return scene
    }

    // MARK: - Dojo (Karate)

    private static func buildDojoScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.03, green: 0.01, blue: 0.01, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 3, 6), lookAt: SCNVector3(0, 1, 0))
        addBasicLighting(to: scene, tint: UIColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 1))

        let floor = SCNFloor()
        floor.reflectivity = 0.1
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.06, green: 0.03, blue: 0.02, alpha: 1)
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let mat = SCNBox(width: 6, height: 0.05, length: 6, chamferRadius: 0)
        let matMaterial = SCNMaterial()
        matMaterial.diffuse.contents = UIColor(red: 0.15, green: 0.05, blue: 0.05, alpha: 1)
        mat.materials = [matMaterial]
        let matNode = SCNNode(geometry: mat)
        matNode.position = SCNVector3(0, 0.025, 0)
        scene.rootNode.addChildNode(matNode)

        for i in stride(from: -2.5, through: 2.5, by: 5.0) {
            let pillar = SCNCylinder(radius: 0.15, height: 4)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = UIColor(red: 0.15, green: 0.08, blue: 0.05, alpha: 1)
            pillar.materials = [pMat]
            let pNode = SCNNode(geometry: pillar)
            pNode.position = SCNVector3(Float(i), 2, -2.8)
            scene.rootNode.addChildNode(pNode)
        }

        let redTint = UIColor(red: 1.0, green: 0.15, blue: 0.1, alpha: 1)
        addAvatar(to: scene, at: SCNVector3(-1.2, 0, 0), color: redTint)
        addAvatar(to: scene, at: SCNVector3(1.2, 0, 0), color: brandCyan)
        addParticles(to: scene, color: UIColor.red.withAlphaComponent(0.15), area: SCNVector3(6, 0.1, 6))

        return scene
    }

    // MARK: - Baseball (Stadium Diamond)

    private static func buildBaseballScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 1)

        addCamera(to: scene, position: SCNVector3(-3, 4, 5), lookAt: SCNVector3(0, 1, 0))
        addBasicLighting(to: scene, tint: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1))

        let floor = SCNFloor()
        floor.reflectivity = 0.05
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.05, green: 0.08, blue: 0.03, alpha: 1)
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let dirt = SCNCylinder(radius: 4, height: 0.02)
        let dirtMat = SCNMaterial()
        dirtMat.diffuse.contents = UIColor(red: 0.12, green: 0.08, blue: 0.04, alpha: 1)
        dirt.materials = [dirtMat]
        let dirtNode = SCNNode(geometry: dirt)
        dirtNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(dirtNode)

        let homePlate = SCNBox(width: 0.4, height: 0.01, length: 0.4, chamferRadius: 0)
        let hpMat = SCNMaterial()
        hpMat.diffuse.contents = UIColor.white
        hpMat.emission.contents = UIColor.white.withAlphaComponent(0.3)
        homePlate.materials = [hpMat]
        let hpNode = SCNNode(geometry: homePlate)
        hpNode.position = SCNVector3(0, 0.02, 3)
        hpNode.eulerAngles.y = .pi / 4
        scene.rootNode.addChildNode(hpNode)

        addAvatar(to: scene, at: SCNVector3(0, 0, 2.5), color: UIColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1))

        let ball = SCNSphere(radius: 0.04)
        let ballMat = SCNMaterial()
        ballMat.diffuse.contents = UIColor.white
        ball.materials = [ballMat]
        let ballNode = SCNNode(geometry: ball)
        ballNode.position = SCNVector3(0, 1.2, -1)
        scene.rootNode.addChildNode(ballNode)
        let bob = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 0.6),
            SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 0.6)
        ])
        ballNode.runAction(SCNAction.repeatForever(bob))

        addParticles(to: scene, color: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.15), area: SCNVector3(8, 0.1, 8))

        return scene
    }

    // MARK: - Football (Stadium Field)

    private static func buildFootballScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 4, 7), lookAt: SCNVector3(0, 1, 0))
        addBasicLighting(to: scene, tint: UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1))

        let floor = SCNFloor()
        floor.reflectivity = 0.05
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.04, green: 0.08, blue: 0.03, alpha: 1)
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let field = SCNBox(width: 10, height: 0.02, length: 6, chamferRadius: 0)
        let fMat = SCNMaterial()
        fMat.diffuse.contents = UIColor(red: 0.06, green: 0.12, blue: 0.04, alpha: 1)
        field.materials = [fMat]
        let fieldNode = SCNNode(geometry: field)
        fieldNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(fieldNode)

        let lineColor = UIColor.white.withAlphaComponent(0.2)
        for z in stride(from: -3.0, through: 3.0, by: 1.0) {
            let line = SCNBox(width: 10, height: 0.005, length: 0.03, chamferRadius: 0)
            let lMat = SCNMaterial()
            lMat.diffuse.contents = lineColor
            lMat.emission.contents = lineColor
            line.materials = [lMat]
            let lNode = SCNNode(geometry: line)
            lNode.position = SCNVector3(0, 0.025, Float(z))
            scene.rootNode.addChildNode(lNode)
        }

        for side in [-1, 1] as [Float] {
            let goalPost = SCNCylinder(radius: 0.05, height: 4)
            let gpMat = SCNMaterial()
            gpMat.diffuse.contents = UIColor.yellow.withAlphaComponent(0.8)
            gpMat.emission.contents = UIColor.yellow.withAlphaComponent(0.2)
            goalPost.materials = [gpMat]
            let gpNode = SCNNode(geometry: goalPost)
            gpNode.position = SCNVector3(side * 5, 2, 0)
            scene.rootNode.addChildNode(gpNode)
        }

        addAvatar(to: scene, at: SCNVector3(0, 0, 2), color: UIColor(red: 0.5, green: 0.3, blue: 0.1, alpha: 1))

        let football = SCNSphere(radius: 0.08)
        let fbMat = SCNMaterial()
        fbMat.diffuse.contents = UIColor(red: 0.4, green: 0.25, blue: 0.1, alpha: 1)
        football.materials = [fbMat]
        let fbNode = SCNNode(geometry: football)
        fbNode.position = SCNVector3(0, 1.3, 2)
        scene.rootNode.addChildNode(fbNode)

        addParticles(to: scene, color: UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 0.1), area: SCNVector3(10, 0.1, 6))

        return scene
    }

    // MARK: - Soccer (Stadium Pitch)

    private static func buildSoccerScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.01, green: 0.03, blue: 0.02, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 3, 7), lookAt: SCNVector3(0, 1.2, 0))
        addBasicLighting(to: scene, tint: UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1))

        let floor = SCNFloor()
        floor.reflectivity = 0.05
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.04, green: 0.1, blue: 0.03, alpha: 1)
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let pitch = SCNBox(width: 8, height: 0.02, length: 5, chamferRadius: 0)
        let pMat = SCNMaterial()
        pMat.diffuse.contents = UIColor(red: 0.06, green: 0.14, blue: 0.05, alpha: 1)
        pitch.materials = [pMat]
        let pNode = SCNNode(geometry: pitch)
        pNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(pNode)

        buildGoalNet(in: scene, at: SCNVector3(0, 0, -2.5))

        addAvatar(to: scene, at: SCNVector3(0, 0, 2), color: UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1))
        addAvatar(to: scene, at: SCNVector3(0, 0, -2), color: UIColor.yellow)

        let soccerBall = SCNSphere(radius: 0.11)
        let sbMat = SCNMaterial()
        sbMat.diffuse.contents = UIColor.white
        sbMat.roughness.contents = 0.6
        soccerBall.materials = [sbMat]
        let sbNode = SCNNode(geometry: soccerBall)
        sbNode.position = SCNVector3(0, 0.11, 1.5)
        scene.rootNode.addChildNode(sbNode)

        addParticles(to: scene, color: UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.15), area: SCNVector3(8, 0.1, 5))

        return scene
    }

    // MARK: - Golf (Green)

    private static func buildGolfScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.01, green: 0.02, blue: 0.03, alpha: 1)

        addCamera(to: scene, position: SCNVector3(3, 3, 5), lookAt: SCNVector3(0, 0.5, 0))
        addBasicLighting(to: scene, tint: UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1))

        let floor = SCNFloor()
        floor.reflectivity = 0.05
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.03, green: 0.08, blue: 0.03, alpha: 1)
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

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

        addAvatar(to: scene, at: SCNVector3(0, 0, 3), color: UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1))

        let golfBall = SCNSphere(radius: 0.022)
        let gbMat = SCNMaterial()
        gbMat.diffuse.contents = UIColor.white
        golfBall.materials = [gbMat]
        let gbNode = SCNNode(geometry: golfBall)
        gbNode.position = SCNVector3(0, 0.04, 2.8)
        scene.rootNode.addChildNode(gbNode)

        addParticles(to: scene, color: UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 0.1), area: SCNVector3(8, 0.1, 8))

        return scene
    }

    // MARK: - Tennis (Venice Beach Court)

    private static func buildTennisScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)

        addCamera(to: scene, position: SCNVector3(0, 4, 7), lookAt: SCNVector3(0, 1, 0))
        addBasicLighting(to: scene, tint: UIColor(red: 0.85, green: 0.75, blue: 0.1, alpha: 1))

        let floor = SCNFloor()
        floor.reflectivity = 0.1
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.04, green: 0.06, blue: 0.03, alpha: 1)
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let court = SCNBox(width: 8, height: 0.02, length: 5, chamferRadius: 0)
        let courtMat = SCNMaterial()
        courtMat.diffuse.contents = UIColor(red: 0.05, green: 0.15, blue: 0.08, alpha: 1)
        court.materials = [courtMat]
        let courtNode = SCNNode(geometry: court)
        courtNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(courtNode)

        let lineColor = UIColor.white.withAlphaComponent(0.4)
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
        addLine(8, 0.03, SCNVector3(0, 0.025, -2.5))
        addLine(8, 0.03, SCNVector3(0, 0.025, 2.5))
        addLine(0.03, 5, SCNVector3(-4, 0.025, 0))
        addLine(0.03, 5, SCNVector3(4, 0.025, 0))
        addLine(5.4, 0.03, SCNVector3(0, 0.025, -1.5))
        addLine(5.4, 0.03, SCNVector3(0, 0.025, 1.5))
        addLine(0.03, 3, SCNVector3(0, 0.025, 0))

        let netPostColor = UIColor.white.withAlphaComponent(0.6)
        for x in [-2.8, 2.8] as [Float] {
            let post = SCNCylinder(radius: 0.03, height: 1.2)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = netPostColor
            post.materials = [pMat]
            let pNode = SCNNode(geometry: post)
            pNode.position = SCNVector3(x, 0.6, 0)
            scene.rootNode.addChildNode(pNode)
        }
        let net = SCNBox(width: 5.6, height: 0.8, length: 0.02, chamferRadius: 0)
        let netMat = SCNMaterial()
        netMat.diffuse.contents = UIColor.white.withAlphaComponent(0.15)
        netMat.isDoubleSided = true
        net.materials = [netMat]
        let netNode = SCNNode(geometry: net)
        netNode.position = SCNVector3(0, 0.7, 0)
        scene.rootNode.addChildNode(netNode)

        addAvatar(to: scene, at: SCNVector3(0, 0, 3), color: UIColor(red: 0.85, green: 0.75, blue: 0.1, alpha: 1))
        addAvatar(to: scene, at: SCNVector3(0, 0, -3), color: brandCyan)

        let ball = SCNSphere(radius: 0.035)
        let bMat = SCNMaterial()
        bMat.diffuse.contents = UIColor(red: 0.8, green: 0.9, blue: 0.1, alpha: 1)
        ball.materials = [bMat]
        let bNode = SCNNode(geometry: ball)
        bNode.position = SCNVector3(0, 1.0, 2)
        scene.rootNode.addChildNode(bNode)
        let bob = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 0.7),
            SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 0.7)
        ])
        bNode.runAction(SCNAction.repeatForever(bob))

        addVeniceBeachWalls(to: scene)
        addParticles(to: scene, color: UIColor(red: 0.85, green: 0.75, blue: 0.1, alpha: 0.12), area: SCNVector3(8, 0.1, 5))

        return scene
    }

    // MARK: - Venice Beach Environment Walls

    private static func addVeniceBeachWalls(to scene: SCNScene) {
        let wallHeight: CGFloat = 4
        let wallThickness: CGFloat = 0.05

        let sandColor = UIColor(red: 0.76, green: 0.70, blue: 0.50, alpha: 1)
        let skyColor = UIColor(red: 0.15, green: 0.35, blue: 0.65, alpha: 1)
        let boardwalkColor = UIColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1)
        let palmGreen = UIColor(red: 0.15, green: 0.45, blue: 0.15, alpha: 1)

        func wallMaterial(topColor: UIColor, bottomColor: UIColor) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.diffuse.contents = bottomColor
            mat.emission.contents = bottomColor.withAlphaComponent(0.05)
            mat.isDoubleSided = true
            return mat
        }

        let backWall = SCNBox(width: 16, height: wallHeight, length: wallThickness, chamferRadius: 0)
        backWall.materials = [wallMaterial(topColor: skyColor, bottomColor: sandColor)]
        let backNode = SCNNode(geometry: backWall)
        backNode.position = SCNVector3(0, Float(wallHeight / 2), -6)
        scene.rootNode.addChildNode(backNode)

        let frontWall = SCNBox(width: 16, height: wallHeight, length: wallThickness, chamferRadius: 0)
        frontWall.materials = [wallMaterial(topColor: skyColor, bottomColor: UIColor(red: 0.12, green: 0.30, blue: 0.55, alpha: 1))]
        let frontNode = SCNNode(geometry: frontWall)
        frontNode.position = SCNVector3(0, Float(wallHeight / 2), 8)
        scene.rootNode.addChildNode(frontNode)

        let leftWall = SCNBox(width: wallThickness, height: wallHeight, length: 14, chamferRadius: 0)
        leftWall.materials = [wallMaterial(topColor: skyColor, bottomColor: boardwalkColor)]
        let leftNode = SCNNode(geometry: leftWall)
        leftNode.position = SCNVector3(-8, Float(wallHeight / 2), 1)
        scene.rootNode.addChildNode(leftNode)

        let rightWall = SCNBox(width: wallThickness, height: wallHeight, length: 14, chamferRadius: 0)
        rightWall.materials = [wallMaterial(topColor: skyColor, bottomColor: boardwalkColor)]
        let rightNode = SCNNode(geometry: rightWall)
        rightNode.position = SCNVector3(8, Float(wallHeight / 2), 1)
        scene.rootNode.addChildNode(rightNode)

        for x in stride(from: -7.0, through: 7.0, by: 3.5) {
            let trunk = SCNCylinder(radius: 0.08, height: 3.5)
            let tMat = SCNMaterial()
            tMat.diffuse.contents = UIColor(red: 0.4, green: 0.3, blue: 0.15, alpha: 1)
            trunk.materials = [tMat]
            let tNode = SCNNode(geometry: trunk)
            tNode.position = SCNVector3(Float(x), 1.75, -5.5)
            scene.rootNode.addChildNode(tNode)

            let crown = SCNSphere(radius: 0.6)
            let cMat = SCNMaterial()
            cMat.diffuse.contents = palmGreen
            cMat.emission.contents = palmGreen.withAlphaComponent(0.1)
            crown.materials = [cMat]
            let cNode = SCNNode(geometry: crown)
            cNode.position = SCNVector3(Float(x), 3.8, -5.5)
            cNode.scale = SCNVector3(1, 0.6, 1)
            scene.rootNode.addChildNode(cNode)
        }

        let boardwalk = SCNBox(width: 16, height: 0.06, length: 1.5, chamferRadius: 0)
        let bwMat = SCNMaterial()
        bwMat.diffuse.contents = boardwalkColor
        bwMat.roughness.contents = 0.95
        boardwalk.materials = [bwMat]
        let bwNode = SCNNode(geometry: boardwalk)
        bwNode.position = SCNVector3(0, 0.03, -5)
        scene.rootNode.addChildNode(bwNode)

        let sandStrip = SCNBox(width: 16, height: 0.02, length: 3, chamferRadius: 0)
        let sMat = SCNMaterial()
        sMat.diffuse.contents = sandColor.withAlphaComponent(0.4)
        sandStrip.materials = [sMat]
        let sNode = SCNNode(geometry: sandStrip)
        sNode.position = SCNVector3(0, 0.005, 7)
        scene.rootNode.addChildNode(sNode)

        let sunGlow = SCNNode()
        sunGlow.light = SCNLight()
        sunGlow.light?.type = .omni
        sunGlow.light?.color = UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1)
        sunGlow.light?.intensity = 100
        sunGlow.position = SCNVector3(5, 6, -5)
        scene.rootNode.addChildNode(sunGlow)
    }

    // MARK: - Shared Builders

    private static func addCamera(to scene: SCNScene, position: SCNVector3, lookAt: SCNVector3) {
        let node = SCNNode()
        node.camera = SCNCamera()
        node.camera?.fieldOfView = 50
        node.camera?.zNear = 0.1
        node.camera?.zFar = 100
        node.position = position
        node.look(at: lookAt)
        scene.rootNode.addChildNode(node)
    }

    private static func addBasicLighting(to scene: SCNScene, tint: UIColor) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.12, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let spot = SCNNode()
        spot.light = SCNLight()
        spot.light?.type = .spot
        spot.light?.color = tint.withAlphaComponent(0.5)
        spot.light?.intensity = 800
        spot.light?.spotInnerAngle = 30
        spot.light?.spotOuterAngle = 60
        spot.light?.castsShadow = true
        spot.light?.shadowRadius = 4
        spot.position = SCNVector3(0, 8, 3)
        spot.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(spot)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.color = UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1)
        fill.light?.intensity = 250
        fill.position = SCNVector3(-3, 2, 4)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .omni
        rim.light?.color = brandCyan
        rim.light?.intensity = 150
        rim.position = SCNVector3(2, 4, -2)
        scene.rootNode.addChildNode(rim)
    }

    private static func addAvatar(to scene: SCNScene, at position: SCNVector3, color: UIColor) {
        let root = SCNNode()
        root.position = position

        func limb(radius: CGFloat, height: CGFloat) -> SCNNode {
            let geo = SCNCapsule(capRadius: radius, height: height)
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color.withAlphaComponent(0.25)
            geo.materials = [mat]
            return SCNNode(geometry: geo)
        }

        func joint(radius: CGFloat) -> SCNNode {
            let geo = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            mat.diffuse.contents = brandCyan
            mat.emission.contents = brandCyan.withAlphaComponent(0.5)
            geo.materials = [mat]
            return SCNNode(geometry: geo)
        }

        let head = joint(radius: 0.12)
        head.position = SCNVector3(0, 1.85, 0)

        let torso = limb(radius: 0.05, height: 0.6)
        torso.position = SCNVector3(0, 1.4, 0)

        let lArm = limb(radius: 0.03, height: 0.35)
        lArm.position = SCNVector3(-0.2, 1.55, 0)
        lArm.eulerAngles.z = 0.4

        let rArm = limb(radius: 0.03, height: 0.35)
        rArm.position = SCNVector3(0.2, 1.55, 0)
        rArm.eulerAngles.z = -0.4

        let lLeg = limb(radius: 0.04, height: 0.5)
        lLeg.position = SCNVector3(-0.1, 0.75, 0)

        let rLeg = limb(radius: 0.04, height: 0.5)
        rLeg.position = SCNVector3(0.1, 0.75, 0)

        let lShin = limb(radius: 0.035, height: 0.45)
        lShin.position = SCNVector3(-0.1, 0.3, 0)

        let rShin = limb(radius: 0.035, height: 0.45)
        rShin.position = SCNVector3(0.1, 0.3, 0)

        let hip = joint(radius: 0.06)
        hip.position = SCNVector3(0, 1.05, 0)

        for node in [head, torso, lArm, rArm, lLeg, rLeg, lShin, rShin, hip] {
            root.addChildNode(node)
        }

        scene.rootNode.addChildNode(root)

        let breathe = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 1.2),
            SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 1.2)
        ])
        root.runAction(SCNAction.repeatForever(breathe))
    }

    private static func addBall(to scene: SCNScene, at position: SCNVector3, color: UIColor) {
        let geo = SCNSphere(radius: 0.12)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.roughness.contents = 0.7
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        node.position = position
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
        particles.birthRate = 12
        particles.particleLifeSpan = 4
        particles.particleSize = 0.015
        particles.particleSizeVariation = 0.01
        particles.particleColor = color
        particles.emitterShape = SCNBox(width: CGFloat(area.x), height: CGFloat(area.y), length: CGFloat(area.z), chamferRadius: 0)
        particles.spreadingAngle = 10
        particles.particleVelocity = 0.3
        particles.particleVelocityVariation = 0.1
        particles.birthDirection = .constant
        particles.emittingDirection = SCNVector3(0, 1, 0)
        particles.blendMode = .additive
        emitter.addParticleSystem(particles)
        scene.rootNode.addChildNode(emitter)
    }

    private static func addCourtLines(to scene: SCNScene) {
        let lineColor = brandBlue.withAlphaComponent(0.3)

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

        makeLine(from: SCNVector3(-4, 0, -2.5), to: SCNVector3(-4, 0, 2.5))
        makeLine(from: SCNVector3(4, 0, -2.5), to: SCNVector3(4, 0, 2.5))
        makeLine(from: SCNVector3(-4, 0, -2.5), to: SCNVector3(4, 0, -2.5))
        makeLine(from: SCNVector3(-4, 0, 2.5), to: SCNVector3(4, 0, 2.5))
        makeLine(from: SCNVector3(0, 0, -2.5), to: SCNVector3(0, 0, 2.5))

        let circle = SCNTorus(ringRadius: 0.9, pipeRadius: 0.015)
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
            let post = SCNCylinder(radius: 0.04, height: 2.4)
            let pMat = SCNMaterial()
            pMat.diffuse.contents = postColor
            pMat.emission.contents = UIColor.white.withAlphaComponent(0.1)
            post.materials = [pMat]
            let pNode = SCNNode(geometry: post)
            pNode.position = SCNVector3(x + position.x, 1.2, position.z)
            scene.rootNode.addChildNode(pNode)
        }

        let crossbar = SCNCylinder(radius: 0.04, height: 2.4)
        let cbMat = SCNMaterial()
        cbMat.diffuse.contents = postColor
        crossbar.materials = [cbMat]
        let cbNode = SCNNode(geometry: crossbar)
        cbNode.position = SCNVector3(position.x, 2.4, position.z)
        cbNode.eulerAngles.z = .pi / 2
        scene.rootNode.addChildNode(cbNode)

        for i in 0..<6 {
            let netLine = SCNCylinder(radius: 0.005, height: 2.4)
            let nMat = SCNMaterial()
            nMat.diffuse.contents = UIColor.white.withAlphaComponent(0.15)
            netLine.materials = [nMat]
            let nNode = SCNNode(geometry: netLine)
            let xOffset = -1.0 + Float(i) * 0.4
            nNode.position = SCNVector3(xOffset + position.x, 1.2, position.z)
            scene.rootNode.addChildNode(nNode)
        }
    }
}
