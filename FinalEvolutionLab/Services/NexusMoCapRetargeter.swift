import Foundation
import SceneKit
import Vision
import simd

/// A robust, real-time skeletal retargeting engine that converts 2D screen coordinates
/// or 3D landmarks into joint rotation quaternions (SCNQuaternion) and maps them to a SceneKit humanoid skeleton.
/// Features built-in smooth slerp interpolation to eliminate capture jitter.
public class NexusMoCapRetargeter {
    
    /// Map of standard humanoid bones and their parent-child joint connections
    public struct BoneConnection {
        public let parentJoint: String
        public let childJoint: String
        public let defaultDirection: SCNVector3
        
        public init(parentJoint: String, childJoint: String, defaultDirection: SCNVector3 = SCNVector3(0, 1, 0)) {
            self.parentJoint = parentJoint
            self.childJoint = childJoint
            self.defaultDirection = defaultDirection
        }
    }
    
    // Configurable smoothing factor for slerp (0.0 < factor <= 1.0).
    // Lower values result in smoother movement but slightly more latency.
    public var smoothingFactor: Float = 0.25
    
    // Mapping of standard SceneKit bone node names to their Joint definition
    public var boneMappings: [String: BoneConnection] = [
        "spine": BoneConnection(parentJoint: "root", childJoint: "spine"),
        "neck": BoneConnection(parentJoint: "centerShoulder", childJoint: "centerHead"),
        "leftShoulder": BoneConnection(parentJoint: "leftShoulder", childJoint: "leftElbow"),
        "leftElbow": BoneConnection(parentJoint: "leftElbow", childJoint: "leftWrist"),
        "rightShoulder": BoneConnection(parentJoint: "rightShoulder", childJoint: "rightElbow"),
        "rightElbow": BoneConnection(parentJoint: "rightElbow", childJoint: "rightWrist"),
        "leftKnee": BoneConnection(parentJoint: "leftHip", childJoint: "leftKnee"),
        "leftAnkle": BoneConnection(parentJoint: "leftKnee", childJoint: "leftAnkle"),
        "rightKnee": BoneConnection(parentJoint: "rightHip", childJoint: "rightKnee"),
        "rightAnkle": BoneConnection(parentJoint: "rightKnee", childJoint: "rightAnkle")
    ]
    
    // Parent hierarchy map for hierarchical forward kinematics calculation
    public var skeletalHierarchy: [String: String] = [
        "neck": "spine",
        "leftShoulder": "spine",
        "leftElbow": "leftShoulder",
        "rightShoulder": "spine",
        "rightElbow": "rightShoulder",
        "leftAnkle": "leftKnee",
        "rightAnkle": "rightKnee"
    ]
    
    // Cache to hold the previous frame's rotations for slerp smoothing (key: bone name)
    private var previousRotations: [String: simd_quatf] = [:]
    
    public init(smoothingFactor: Float = 0.25) {
        self.smoothingFactor = smoothingFactor
    }
    
    /// Resets the smoothing history. Call this when starting a new session or after a tracking loss.
    public func reset() {
        previousRotations.removeAll()
    }
    
    // MARK: - Retargeting 2D Joint Coordinates
    
    /// Converts 2D joint coordinates to rotations and retargets them to standard bone nodes.
    /// - Parameters:
    ///   - joints: Normalized 2D coordinates (e.g., from VNHumanBodyPoseObservation)
    ///   - mannequin: The SceneKit root node of the skeletal model
    ///   - hierarchical: If true, calculates hierarchical rotations relative to parent nodes
    public func retarget2D(
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        to mannequin: SCNNode,
        hierarchical: Bool = true
    ) {
        var absoluteRotations: [String: SCNQuaternion] = [:]
        
        // 1. Calculate absolute orientations for each configured bone
        for (boneName, connection) in boneMappings {
            guard let parentJointName = mapTo2DJointName(connection.parentJoint),
                  let childJointName = mapTo2DJointName(connection.childJoint),
                  let parentPos = joints[parentJointName],
                  let childPos = joints[childJointName] else {
                continue
            }
            
            // Convert screen space (Y-down) to 3D space (Y-up, Z = 0)
            let dx = Float(childPos.x - parentPos.x)
            let dy = -Float(childPos.y - parentPos.y) // Invert Y
            let dz: Float = 0.0
            
            let direction = SCNVector3(dx, dy, dz)
            let absRot = NexusMoCapRetargeter.rotation(from: connection.defaultDirection, to: direction)
            absoluteRotations[boneName] = absRot
        }
        
        // 2. Compute local or absolute rotations and apply them
        applyRotations(absoluteRotations, to: mannequin, hierarchical: hierarchical)
    }
    
    // MARK: - Retargeting 3D Joint Coordinates
    
    /// Converts 3D joint coordinates (String keys) to rotations and retargets them to standard bone nodes.
    /// - Parameters:
    ///   - joints: 3D coordinates relative to root (e.g. from VNDetectHumanBodyPose3DRequest)
    ///   - mannequin: The SceneKit root node of the skeletal model
    ///   - hierarchical: If true, calculates hierarchical rotations relative to parent nodes
    public func retarget3D(
        joints: [String: SCNVector3],
        to mannequin: SCNNode,
        hierarchical: Bool = true
    ) {
        var absoluteRotations: [String: SCNQuaternion] = [:]
        
        // 1. Calculate absolute orientations for each configured bone
        for (boneName, connection) in boneMappings {
            guard let parentPos = joints[connection.parentJoint],
                  let childPos = joints[connection.childJoint] else {
                continue
            }
            
            let dx = Float(childPos.x - parentPos.x)
            let dy = Float(childPos.y - parentPos.y)
            let dz = Float(childPos.z - parentPos.z)
            
            let direction = SCNVector3(dx, dy, dz)
            let absRot = NexusMoCapRetargeter.rotation(from: connection.defaultDirection, to: direction)
            absoluteRotations[boneName] = absRot
        }
        
        // 2. Compute local or absolute rotations and apply them
        applyRotations(absoluteRotations, to: mannequin, hierarchical: hierarchical)
    }
    
    // MARK: - Core Math & Rotation Application
    
    /// Computes either hierarchical or absolute rotations, smoothly slerps them, and applies them to SceneKit bone nodes.
    private func applyRotations(
        _ absoluteRotations: [String: SCNQuaternion],
        to mannequin: SCNNode,
        hierarchical: Bool
    ) {
        let targets = hierarchical ?
            NexusMoCapRetargeter.computeLocalRotations(absoluteRotations: absoluteRotations, parentMapping: skeletalHierarchy) :
            absoluteRotations
        
        for (boneName, targetRot) in targets {
            guard let boneNode = NexusMoCapRetargeter.findNode(named: boneName, in: mannequin) else {
                continue
            }
            
            // Convert to simd_quatf for high-perf slerp interpolation
            let rawQuat = simd_quatf(
                ix: Float(targetRot.x),
                iy: Float(targetRot.y),
                iz: Float(targetRot.z),
                r: Float(targetRot.w)
            )
            
            // Slerp smooth rotation to eliminate capture jitter
            let smoothedQuat = smoothRotation(for: boneName, targetQuat: rawQuat)
            
            // Apply rotation back to SceneKit bone node
            boneNode.orientation = SCNQuaternion(
                SCNFloat(smoothedQuat.vector.x),
                SCNFloat(smoothedQuat.vector.y),
                SCNFloat(smoothedQuat.vector.z),
                SCNFloat(smoothedQuat.vector.w)
            )
        }
    }
    
    /// Computes local rotations for nested bone nodes in a skeletal hierarchy.
    public static func computeLocalRotations(
        absoluteRotations: [String: SCNQuaternion],
        parentMapping: [String: String]
    ) -> [String: SCNQuaternion] {
        var localRotations: [String: SCNQuaternion] = [:]
        
        for (boneName, absRot) in absoluteRotations {
            if let parentName = parentMapping[boneName], let parentAbsRot = absoluteRotations[parentName] {
                let qParent = simd_quatf(ix: Float(parentAbsRot.x), iy: Float(parentAbsRot.y), iz: Float(parentAbsRot.z), r: Float(parentAbsRot.w))
                let qChild = simd_quatf(ix: Float(absRot.x), iy: Float(absRot.y), iz: Float(absRot.z), r: Float(absRot.w))
                
                // qParent * qLocal = qChild  =>  qLocal = qParent.inverse * qChild
                let qLocal = qParent.inverse * qChild
                
                localRotations[boneName] = SCNQuaternion(
                    SCNFloat(qLocal.vector.x),
                    SCNFloat(qLocal.vector.y),
                    SCNFloat(qLocal.vector.z),
                    SCNFloat(qLocal.vector.w)
                )
            } else {
                localRotations[boneName] = absRot
            }
        }
        
        return localRotations
    }
    
    /// Calculates the rotation quaternion to rotate from a default bone direction to a target direction.
    public static func rotation(from defaultDir: SCNVector3, to targetDir: SCNVector3) -> SCNQuaternion {
        let v1 = simd_normalize(simd_float3(Float(defaultDir.x), Float(defaultDir.y), Float(defaultDir.z)))
        let v2 = simd_normalize(simd_float3(Float(targetDir.x), Float(targetDir.y), Float(targetDir.z)))
        
        let cosTheta = simd_dot(v1, v2)
        
        // Parallel vectors
        if cosTheta > 0.999999 {
            return SCNQuaternion(0, 0, 0, 1)
        } else if cosTheta < -0.999999 {
            // Opposite vectors: rotate 180 degrees around any orthogonal axis
            var orthogonal = simd_cross(v1, simd_float3(1, 0, 0))
            if simd_length(orthogonal) < 0.01 {
                orthogonal = simd_cross(v1, simd_float3(0, 1, 0))
            }
            orthogonal = simd_normalize(orthogonal)
            return SCNQuaternion(SCNFloat(orthogonal.x), SCNFloat(orthogonal.y), SCNFloat(orthogonal.z), 0)
        }
        
        let axis = simd_normalize(simd_cross(v1, v2))
        let s = sqrt((1 + cosTheta) * 2)
        let invS = 1 / s
        
        let qVec = axis * (s * 0.5)
        let qW = s * 0.5
        
        let quat = simd_quaternion(simd_float4(qVec.x * invS, qVec.y * invS, qVec.z * invS, qW * invS))
        return SCNQuaternion(
            SCNFloat(quat.vector.x),
            SCNFloat(quat.vector.y),
            SCNFloat(quat.vector.z),
            SCNFloat(quat.vector.w)
        )
    }
    
    /// Smoothly interpolates (slerp) a rotation for a given bone name to eliminate capture jitter.
    private func smoothRotation(for boneName: String, targetQuat: simd_quatf) -> simd_quatf {
        guard let prevQuat = previousRotations[boneName] else {
            previousRotations[boneName] = targetQuat
            return targetQuat
        }
        let smoothed = simd_slerp(prevQuat, targetQuat, smoothingFactor)
        previousRotations[boneName] = smoothed
        return smoothed
    }
    
    /// Robust bone node discovery within a given SceneKit mannequin root node.
    public static func findNode(named boneName: String, in rootNode: SCNNode) -> SCNNode? {
        if let node = rootNode.childNode(withName: boneName, recursively: true) {
            return node
        }
        let patterns = ["joint_\(boneName)", "bone_\(boneName)", "SCNNode_\(boneName)", boneName.capitalized]
        for pattern in patterns {
            if let node = rootNode.childNode(withName: pattern, recursively: true) {
                return node
            }
        }
        return nil
    }
    
    // MARK: - Utilities
    
    private func mapTo2DJointName(_ stringName: String) -> VNHumanBodyPoseObservation.JointName? {
        switch stringName {
        case "root": return .leftHip // Approximation for 2D root
        case "spine": return .neck
        case "centerShoulder": return .neck
        case "centerHead": return .nose
        case "leftShoulder": return .leftShoulder
        case "leftElbow": return .leftElbow
        case "leftWrist": return .leftWrist
        case "rightShoulder": return .rightShoulder
        case "rightElbow": return .rightElbow
        case "rightWrist": return .rightWrist
        case "leftHip": return .leftHip
        case "leftKnee": return .leftKnee
        case "leftAnkle": return .leftAnkle
        case "rightHip": return .rightHip
        case "rightKnee": return .rightKnee
        case "rightAnkle": return .rightAnkle
        default: return nil
        }
    }
}

// MARK: - Cross-Platform Compatibility SCNFloat Definition
#if os(macOS)
public typealias SCNFloat = CGFloat
#else
public typealias SCNFloat = Float
#endif
