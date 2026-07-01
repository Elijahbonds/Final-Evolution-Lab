import Foundation
import ARKit
import Network
import Combine
import SceneKit

/// High-fidelity 3D face tracking and optional Live Link UDP streaming engine.
/// Uses ARKit's ARFaceTrackingConfiguration and TrueDepth camera to perform markerless
/// 3D face scanning and real-time facial expression tracking.
public class NexusLiveLinkFaceEngine: NSObject, ObservableObject {
    @Published public var isSessionRunning = false
    @Published public var isTrackingActive = false
    @Published public var isStreaming = false
    @Published public var blendshapes: [String: Float] = [:]
    @Published public var errorMessage: String?
    
    // Streaming Configuration
    @Published public var targetIP: String = "192.168.1.100" {
        didSet { restartStreamerIfNeeded() }
    }
    @Published public var targetPort: UInt16 = 11111 {
        didSet { restartStreamerIfNeeded() }
    }
    @Published public var subjectName: String = "Athlete_Face"
    
    public var onFaceAnchorUpdated: ((ARFaceAnchor) -> Void)?
    
    private let arSession = ARSession()
    private var streamer: LiveLinkUDPStreamer?
    private var frameCount: UInt32 = 0
    
    public override init() {
        super.init()
        arSession.delegate = self
        setupStreamer()
    }
    
    deinit {
        stopSession()
        streamer?.disconnect()
    }
    
    // MARK: - Session Management
    
    public func startSession() {
        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                self.errorMessage = "TrueDepth camera or ARKit Face Tracking is not supported on this device."
            }
            return
        }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        DispatchQueue.main.async {
            self.isSessionRunning = true
            self.errorMessage = nil
        }
    }
    
    public func stopSession() {
        arSession.pause()
        DispatchQueue.main.async {
            self.isSessionRunning = false
            self.isTrackingActive = false
        }
    }
    
    // MARK: - Streaming Controls
    
    public func toggleStreaming() {
        isStreaming.toggle()
        if isStreaming {
            setupStreamer()
        } else {
            streamer?.disconnect()
        }
    }
    
    private func setupStreamer() {
        streamer?.disconnect()
        let newStreamer = LiveLinkUDPStreamer()
        newStreamer.connect(ip: targetIP, port: targetPort)
        self.streamer = newStreamer
    }
    
    private func restartStreamerIfNeeded() {
        if isStreaming {
            setupStreamer()
        }
    }
    
    // MARK: - Live Link Packet Serialization
    
    /// Packs the 61 blendshapes and metadata into the Live Link protocol wire format (version 6).
    private func serializeLiveLinkPacket(blendshapeValues: [Float]) -> Data {
        var data = Data()
        
        // 1. PacketVersion (uint8_t) -> 6
        data.append(6 as UInt8)
        
        // 2. Device ID (Length as int32_t + UTF8 bytes)
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "iOS_Device"
        let deviceIDData = deviceID.data(using: .utf8) ?? Data()
        data.appendBigEndian(Int32(deviceIDData.count))
        data.append(deviceIDData)
        
        // 3. Subject Name (Length as int32_t + UTF8 bytes)
        let subjectData = subjectName.data(using: .utf8) ?? Data()
        data.appendBigEndian(Int32(subjectData.count))
        data.append(subjectData)
        
        // 4. FrameTime (16 bytes: uint32_t Frame, uint32_t SubFrame, uint32_t fps, uint32_t denominator)
        frameCount += 1
        data.appendBigEndian(frameCount) // Frame
        data.appendBigEndian(UInt32(0))  // SubFrame
        data.appendBigEndian(UInt32(60)) // fps
        data.appendBigEndian(UInt32(1))  // denominator
        
        // 5. BlendShapeCount (uint8_t) -> 61
        data.append(61 as UInt8)
        
        // 6. Blendshapes (61 floats)
        for val in blendshapeValues {
            data.appendBigEndian(val)
        }
        
        return data
    }
}

// MARK: - ARSessionDelegate

extension NexusLiveLinkFaceEngine: ARSessionDelegate {
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            return
        }
        
        if !isTrackingActive {
            DispatchQueue.main.async {
                self.isTrackingActive = true
            }
        }
        
        // Extract 52 standard ARKit blendshapes
        var currentBlendshapes: [String: Float] = [:]
        var orderedValues = [Float](repeating: 0.0, count: 61)
        
        for shape in EARFaceBlendShape.allCases {
            if let arkitLoc = shape.arkitLocation {
                let val = faceAnchor.blendShapes[arkitLoc]?.floatValue ?? 0.0
                currentBlendshapes[shape.rawValueString] = val
                orderedValues[shape.rawValue] = val
            }
        }
        
        // Extract Head Rotation (Euler angles in degrees)
        let transform = faceAnchor.transform
        let r31 = transform.columns.2.x
        let r32 = transform.columns.2.y
        let r33 = transform.columns.2.z
        let r12 = transform.columns.0.y
        let r22 = transform.columns.1.y
        
        let pitch = asin(-r32) * 180.0 / .pi
        let yaw = atan2(r31, r33) * 180.0 / .pi
        let roll = atan2(r12, r22) * 180.0 / .pi
        
        currentBlendshapes["headPitch"] = pitch
        currentBlendshapes["headYaw"] = yaw
        currentBlendshapes["headRoll"] = roll
        
        orderedValues[EARFaceBlendShape.headPitch.rawValue] = pitch
        orderedValues[EARFaceBlendShape.headYaw.rawValue] = yaw
        orderedValues[EARFaceBlendShape.headRoll.rawValue] = roll
        
        // Extract Eye Rotations
        let leftEyeTransform = faceAnchor.leftEyeTransform
        let rightEyeTransform = faceAnchor.rightEyeTransform
        
        let leftEyeYaw = atan2(leftEyeTransform.columns.2.x, leftEyeTransform.columns.2.z) * 180.0 / .pi
        let leftEyePitch = asin(-leftEyeTransform.columns.2.y) * 180.0 / .pi
        let leftEyeRoll = atan2(leftEyeTransform.columns.0.y, leftEyeTransform.columns.1.y) * 180.0 / .pi
        
        let rightEyeYaw = atan2(rightEyeTransform.columns.2.x, rightEyeTransform.columns.2.z) * 180.0 / .pi
        let rightEyePitch = asin(-rightEyeTransform.columns.2.y) * 180.0 / .pi
        let rightEyeRoll = atan2(rightEyeTransform.columns.0.y, rightEyeTransform.columns.1.y) * 180.0 / .pi
        
        currentBlendshapes["leftEyeYaw"] = leftEyeYaw
        currentBlendshapes["leftEyePitch"] = leftEyePitch
        currentBlendshapes["leftEyeRoll"] = leftEyeRoll
        currentBlendshapes["rightEyeYaw"] = rightEyeYaw
        currentBlendshapes["rightEyePitch"] = rightEyePitch
        currentBlendshapes["rightEyeRoll"] = rightEyeRoll
        
        orderedValues[EARFaceBlendShape.leftEyeYaw.rawValue] = leftEyeYaw
        orderedValues[EARFaceBlendShape.leftEyePitch.rawValue] = leftEyePitch
        orderedValues[EARFaceBlendShape.leftEyeRoll.rawValue] = leftEyeRoll
        orderedValues[EARFaceBlendShape.rightEyeYaw.rawValue] = rightEyeYaw
        orderedValues[EARFaceBlendShape.rightEyePitch.rawValue] = rightEyePitch
        orderedValues[EARFaceBlendShape.rightEyeRoll.rawValue] = rightEyeRoll
        
        DispatchQueue.main.async {
            self.blendshapes = currentBlendshapes
            self.onFaceAnchorUpdated?(faceAnchor)
        }
        
        // Stream over UDP when enabled
        if isStreaming {
            let packet = serializeLiveLinkPacket(blendshapeValues: orderedValues)
            streamer?.send(data: packet)
        }
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.isTrackingActive = false
            self.errorMessage = "AR Session was interrupted."
        }
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        startSession()
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isTrackingActive = false
            self.errorMessage = "AR Session failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Live Link UDP Streamer

private class LiveLinkUDPStreamer {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.nexus.livelink.udp")
    
    func connect(ip: String, port: UInt16) {
        let host = NWEndpoint.Host(ip)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        let parameters = NWParameters.udp
        connection = NWConnection(host: host, port: nwPort, using: parameters)
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Live Link UDP Streamer ready to send to \(ip):\(port)")
            case .failed(let error):
                print("Live Link UDP Streamer failed: \(error)")
            default:
                break
            }
        }
        connection?.start(queue: queue)
    }
    
    func send(data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("Live Link UDP send error: \(error)")
            }
        }))
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}

// MARK: - Data Serialization Helpers

private extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { buffer in
            self.append(buffer.bindMemory(to: UInt8.self))
        }
    }
    
    mutating func appendBigEndian(_ value: Float) {
        var bitPattern = value.bitPattern.bigEndian
        Swift.withUnsafeBytes(of: &bitPattern) { buffer in
            self.append(buffer.bindMemory(to: UInt8.self))
        }
    }
}

// MARK: - EARFaceBlendShape Enum

public enum EARFaceBlendShape: Int, CaseIterable {
    // Left eye blend shapes
    case eyeBlinkLeft = 0
    case eyeLookDownLeft
    case eyeLookInLeft
    case eyeLookOutLeft
    case eyeLookUpLeft
    case eyeSquintLeft
    case eyeWideLeft
    
    // Right eye blend shapes
    case eyeBlinkRight
    case eyeLookDownRight
    case eyeLookInRight
    case eyeLookOutRight
    case eyeLookUpRight
    case eyeSquintRight
    case eyeWideRight
    
    // Jaw blend shapes
    case jawForward
    case jawLeft
    case jawRight
    case jawOpen
    
    // Mouth blend shapes
    case mouthClose
    case mouthFunnel
    case mouthPucker
    case mouthLeft
    case mouthRight
    case mouthSmileLeft
    case mouthSmileRight
    case mouthFrownLeft
    case mouthFrownRight
    case mouthDimpleLeft
    case mouthDimpleRight
    case mouthStretchLeft
    case mouthStretchRight
    case mouthRollLower
    case mouthRollUpper
    case mouthShrugLower
    case mouthShrugUpper
    case mouthPressLeft
    case mouthPressRight
    case mouthLowerDownLeft
    case mouthLowerDownRight
    case mouthUpperUpLeft
    case mouthUpperUpRight
    
    // Brow blend shapes
    case browDownLeft
    case browDownRight
    case browInnerUp
    case browOuterUpLeft
    case browOuterUpRight
    
    // Cheek blend shapes
    case cheekPuff
    case cheekSquintLeft
    case cheekSquintRight
    
    // Nose blend shapes
    case noseSneerLeft
    case noseSneerRight
    case tongueOut
    
    // Treat the head rotation as curves for LiveLink support
    case headYaw
    case headPitch
    case headRoll
    
    // Treat eye rotation as curves for LiveLink support
    case leftEyeYaw
    case leftEyePitch
    case leftEyeRoll
    case rightEyeYaw
    case rightEyePitch
    case rightEyeRoll
    
    public var rawValueString: String {
        switch self {
        case .eyeBlinkLeft: return "eyeBlinkLeft"
        case .eyeLookDownLeft: return "eyeLookDownLeft"
        case .eyeLookInLeft: return "eyeLookInLeft"
        case .eyeLookOutLeft: return "eyeLookOutLeft"
        case .eyeLookUpLeft: return "eyeLookUpLeft"
        case .eyeSquintLeft: return "eyeSquintLeft"
        case .eyeWideLeft: return "eyeWideLeft"
        case .eyeBlinkRight: return "eyeBlinkRight"
        case .eyeLookDownRight: return "eyeLookDownRight"
        case .eyeLookInRight: return "eyeLookInRight"
        case .eyeLookOutRight: return "eyeLookOutRight"
        case .eyeLookUpRight: return "eyeLookUpRight"
        case .eyeSquintRight: return "eyeSquintRight"
        case .eyeWideRight: return "eyeWideRight"
        case .jawForward: return "jawForward"
        case .jawLeft: return "jawLeft"
        case .jawRight: return "jawRight"
        case .jawOpen: return "jawOpen"
        case .mouthClose: return "mouthClose"
        case .mouthFunnel: return "mouthFunnel"
        case .mouthPucker: return "mouthPucker"
        case .mouthLeft: return "mouthLeft"
        case .mouthRight: return "mouthRight"
        case .mouthSmileLeft: return "mouthSmileLeft"
        case .mouthSmileRight: return "mouthSmileRight"
        case .mouthFrownLeft: return "mouthFrownLeft"
        case .mouthFrownRight: return "mouthFrownRight"
        case .mouthDimpleLeft: return "mouthDimpleLeft"
        case .mouthDimpleRight: return "mouthDimpleRight"
        case .mouthStretchLeft: return "mouthStretchLeft"
        case .mouthStretchRight: return "mouthStretchRight"
        case .mouthRollLower: return "mouthRollLower"
        case .mouthRollUpper: return "mouthRollUpper"
        case .mouthShrugLower: return "mouthShrugLower"
        case .mouthShrugUpper: return "mouthShrugUpper"
        case .mouthPressLeft: return "mouthPressLeft"
        case .mouthPressRight: return "mouthPressRight"
        case .mouthLowerDownLeft: return "mouthLowerDownLeft"
        case .mouthLowerDownRight: return "mouthLowerDownRight"
        case .mouthUpperUpLeft: return "mouthUpperUpLeft"
        case .mouthUpperUpRight: return "mouthUpperUpRight"
        case .browDownLeft: return "browDownLeft"
        case .browDownRight: return "browDownRight"
        case .browInnerUp: return "browInnerUp"
        case .browOuterUpLeft: return "browOuterUpLeft"
        case .browOuterUpRight: return "browOuterUpRight"
        case .cheekPuff: return "cheekPuff"
        case .cheekSquintLeft: return "cheekSquintLeft"
        case .cheekSquintRight: return "cheekSquintRight"
        case .noseSneerLeft: return "noseSneerLeft"
        case .noseSneerRight: return "noseSneerRight"
        case .tongueOut: return "tongueOut"
        case .headYaw: return "headYaw"
        case .headPitch: return "headPitch"
        case .headRoll: return "headRoll"
        case .leftEyeYaw: return "leftEyeYaw"
        case .leftEyePitch: return "leftEyePitch"
        case .leftEyeRoll: return "leftEyeRoll"
        case .rightEyeYaw: return "rightEyeYaw"
        case .rightEyePitch: return "rightEyePitch"
        case .rightEyeRoll: return "rightEyeRoll"
        }
    }
    
    public var arkitLocation: ARFaceAnchor.BlendShapeLocation? {
        switch self {
        case .eyeBlinkLeft: return .eyeBlinkLeft
        case .eyeLookDownLeft: return .eyeLookDownLeft
        case .eyeLookInLeft: return .eyeLookInLeft
        case .eyeLookOutLeft: return .eyeLookOutLeft
        case .eyeLookUpLeft: return .eyeLookUpLeft
        case .eyeSquintLeft: return .eyeSquintLeft
        case .eyeWideLeft: return .eyeWideLeft
        case .eyeBlinkRight: return .eyeBlinkRight
        case .eyeLookDownRight: return .eyeLookDownRight
        case .eyeLookInRight: return .eyeLookInRight
        case .eyeLookOutRight: return .eyeLookOutRight
        case .eyeLookUpRight: return .eyeLookUpRight
        case .eyeSquintRight: return .eyeSquintRight
        case .eyeWideRight: return .eyeWideRight
        case .jawForward: return .jawForward
        case .jawLeft: return .jawLeft
        case .jawRight: return .jawRight
        case .jawOpen: return .jawOpen
        case .mouthClose: return .mouthClose
        case .mouthFunnel: return .mouthFunnel
        case .mouthPucker: return .mouthPucker
        case .mouthLeft: return .mouthLeft
        case .mouthRight: return .mouthRight
        case .mouthSmileLeft: return .mouthSmileLeft
        case .mouthSmileRight: return .mouthSmileRight
        case .mouthFrownLeft: return .mouthFrownLeft
        case .mouthFrownRight: return .mouthFrownRight
        case .mouthDimpleLeft: return .mouthDimpleLeft
        case .mouthDimpleRight: return .mouthDimpleRight
        case .mouthStretchLeft: return .mouthStretchLeft
        case .mouthStretchRight: return .mouthStretchRight
        case .mouthRollLower: return .mouthRollLower
        case .mouthRollUpper: return .mouthRollUpper
        case .mouthShrugLower: return .mouthShrugLower
        case .mouthShrugUpper: return .mouthShrugUpper
        case .mouthPressLeft: return .mouthPressLeft
        case .mouthPressRight: return .mouthPressRight
        case .mouthLowerDownLeft: return .mouthLowerDownLeft
        case .mouthLowerDownRight: return .mouthLowerDownRight
        case .mouthUpperUpLeft: return .mouthUpperUpLeft
        case .mouthUpperUpRight: return .mouthUpperUpRight
        case .browDownLeft: return .browDownLeft
        case .browDownRight: return .browDownRight
        case .browInnerUp: return .browInnerUp
        case .browOuterUpLeft: return .browOuterUpLeft
        case .browOuterUpRight: return .browOuterUpRight
        case .cheekPuff: return .cheekPuff
        case .cheekSquintLeft: return .cheekSquintLeft
        case .cheekSquintRight: return .cheekSquintRight
        case .noseSneerLeft: return .noseSneerLeft
        case .noseSneerRight: return .noseSneerRight
        case .tongueOut: return .tongueOut
        default: return nil
        }
    }
}

// MARK: - Procedural Facial Animation Mapper

public class NexusFaceAnimationMapper {
    public static func addFacialFeatures(to headNode: SCNNode) {
        // Remove existing facial features if any
        headNode.childNode(withName: "eyeL", recursively: false)?.removeFromParentNode()
        headNode.childNode(withName: "eyeR", recursively: false)?.removeFromParentNode()
        headNode.childNode(withName: "browL", recursively: false)?.removeFromParentNode()
        headNode.childNode(withName: "browR", recursively: false)?.removeFromParentNode()
        headNode.childNode(withName: "mouth", recursively: false)?.removeFromParentNode()
        
        let eyeMat = SCNMaterial()
        eyeMat.diffuse.contents = UIColor.black
        eyeMat.emission.contents = UIColor(red: 0, green: 0.95, blue: 0.9, alpha: 1) // glowing brandCyan
        
        let browMat = SCNMaterial()
        browMat.diffuse.contents = UIColor.white
        
        let mouthMat = SCNMaterial()
        mouthMat.diffuse.contents = UIColor.red
        mouthMat.emission.contents = UIColor(red: 0.95, green: 0.1, blue: 0.1, alpha: 1) // glowing red
        
        // Left Eye
        let eyeL = SCNNode(geometry: SCNSphere(radius: 0.015))
        eyeL.name = "eyeL"
        eyeL.position = SCNVector3(-0.04, 0.02, 0.105)
        eyeL.geometry?.materials = [eyeMat]
        headNode.addChildNode(eyeL)
        
        // Right Eye
        let eyeR = SCNNode(geometry: SCNSphere(radius: 0.015))
        eyeR.name = "eyeR"
        eyeR.position = SCNVector3(0.04, 0.02, 0.105)
        eyeR.geometry?.materials = [eyeMat]
        headNode.addChildNode(eyeR)
        
        // Left Brow
        let browL = SCNNode(geometry: SCNBox(width: 0.03, height: 0.006, length: 0.01, chamferRadius: 0))
        browL.name = "browL"
        browL.position = SCNVector3(-0.04, 0.045, 0.105)
        browL.geometry?.materials = [browMat]
        headNode.addChildNode(browL)
        
        // Right Brow
        let browR = SCNNode(geometry: SCNBox(width: 0.03, height: 0.006, length: 0.01, chamferRadius: 0))
        browR.name = "browR"
        browR.position = SCNVector3(0.04, 0.045, 0.105)
        browR.geometry?.materials = [browMat]
        headNode.addChildNode(browR)
        
        // Mouth
        let mouth = SCNNode(geometry: SCNCapsule(capRadius: 0.008, height: 0.04))
        mouth.name = "mouth"
        mouth.position = SCNVector3(0, -0.04, 0.105)
        mouth.eulerAngles = SCNVector3(0, 0, Float.pi / 2) // horizontal
        mouth.geometry?.materials = [mouthMat]
        headNode.addChildNode(mouth)
    }
    
    public static func applyBlendshapes(_ blendshapes: [String: Float], to headNode: SCNNode) {
        // 1. Blinking (scale eyes along Y axis)
        let blinkL = blendshapes["eyeBlinkLeft"] ?? 0.0
        let blinkR = blendshapes["eyeBlinkRight"] ?? 0.0
        if let eyeL = headNode.childNode(withName: "eyeL", recursively: false) {
            eyeL.scale.y = Float(max(0.1, 1.0 - blinkL))
        }
        if let eyeR = headNode.childNode(withName: "eyeR", recursively: false) {
            eyeR.scale.y = Float(max(0.1, 1.0 - blinkR))
        }
        
        // 2. Brows (move brows up/down)
        let browUpL = (blendshapes["browOuterUpLeft"] ?? 0.0) + (blendshapes["browInnerUp"] ?? 0.0)
        let browDownL = blendshapes["browDownLeft"] ?? 0.0
        let browUpR = (blendshapes["browOuterUpRight"] ?? 0.0) + (blendshapes["browInnerUp"] ?? 0.0)
        let browDownR = blendshapes["browDownRight"] ?? 0.0
        
        if let browL = headNode.childNode(withName: "browL", recursively: false) {
            browL.position.y = Float(0.045 + (browUpL * 0.01) - (browDownL * 0.01))
        }
        if let browR = headNode.childNode(withName: "browR", recursively: false) {
            browR.position.y = Float(0.045 + (browUpR * 0.01) - (browDownR * 0.01))
        }
        
        // 3. Mouth (jawOpen scales mouth height, mouthSmileLeft/Right bends/scales width)
        let jawOpen = blendshapes["jawOpen"] ?? 0.0
        let smileL = blendshapes["mouthSmileLeft"] ?? 0.0
        let smileR = blendshapes["mouthSmileRight"] ?? 0.0
        let smile = (smileL + smileR) / 2.0
        
        if let mouth = headNode.childNode(withName: "mouth", recursively: false) {
            mouth.scale.x = Float(1.0 + jawOpen * 1.5)
            mouth.scale.y = Float(1.0 + smile * 0.5)
            mouth.position.y = Float(-0.04 - (jawOpen * 0.015))
        }
        
        // 4. Head rotation
        let yaw = blendshapes["headYaw"] ?? 0.0
        let pitch = blendshapes["headPitch"] ?? 0.0
        let roll = blendshapes["headRoll"] ?? 0.0
        
        headNode.eulerAngles = SCNVector3(
            pitch * Float.pi / 180.0,
            yaw * Float.pi / 180.0,
            roll * Float.pi / 180.0
        )
    }
}
