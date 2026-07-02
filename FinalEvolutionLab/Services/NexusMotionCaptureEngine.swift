import Foundation
import Vision
import SceneKit
import AVFoundation
import simd
import Combine

/// High-fidelity 3D motion capture engine that processes live camera feeds or recorded videos
/// using Apple's Vision framework (VNDetectHumanBodyPose3DRequest) to track 3D joints and retarget them.
public class NexusMotionCaptureEngine: NSObject, ObservableObject {
    @Published public var isSessionRunning = false
    @Published public var isTrackingActive = false
    @Published public var capturedJoints: [String: SCNVector3] = [:]
    @Published var capturedRotations: [String: SCNQuaternion] = [:]
    @Published public var errorMessage: String?
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.nexus.mocap.sessionQueue")
    private let visionQueue = DispatchQueue(label: "com.nexus.mocap.visionQueue")
    
    private var bodyPoseRequest = VNDetectHumanBodyPose3DRequest()
    public var onPoseDetected: ((VNHumanBodyPose3DObservation) -> Void)?
    
    public override init() {
        super.init()
        setupVision()
    }
    
    private func setupVision() {
        // Initialize the 3D body pose request
        bodyPoseRequest = VNDetectHumanBodyPose3DRequest()
    }
    
    // MARK: - Camera Capture Setup
    
    public func startCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .hd1280x720
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Front camera unavailable. Please check permissions."
                }
                self.captureSession.commitConfiguration()
                return
            }
            
            if self.captureSession.canAddInput(videoInput) {
                self.captureSession.addInput(videoInput)
            }
            
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            self.videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
            
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = true
                self.isTrackingActive = true
                self.errorMessage = nil
            }
        }
    }
    
    public func stopCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                    self.isTrackingActive = false
                }
            }
        }
    }
    
    // MARK: - Offline Video File Processing
    
    public func processVideoFile(url: URL, progressHandler: @escaping (Double) -> Void, completion: @escaping ([VNHumanBodyPose3DObservation]) -> Void) {
        visionQueue.async {
            let asset = AVAsset(url: url)
            guard let reader = try? AVAssetReader(asset: asset),
                  let videoTrack = asset.tracks(withMediaType: .video).first else {
                completion([])
                return
            }
            
            let outputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
            reader.add(trackOutput)
            reader.startReading()
            
            var observations: [VNHumanBodyPose3DObservation] = []
            let duration = asset.duration.seconds
            
            while reader.status == .reading {
                guard let sampleBuffer = trackOutput.copyNextSampleBuffer(),
                      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    break
                }
                
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                let progress = duration > 0 ? (presentationTime / duration) : 0.0
                DispatchQueue.main.async {
                    progressHandler(progress)
                }
                
                let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, options: [:])
                let request = VNDetectHumanBodyPose3DRequest()
                try? handler.perform([request])
                
                if let observation = request.results?.first {
                    observations.append(observation)
                }
            }
            
            DispatchQueue.main.async {
                progressHandler(1.0)
                completion(observations)
            }
        }
    }
    
    // MARK: - Joint Extraction & Rotation Computation
    
    public func extractJointData(from observation: VNHumanBodyPose3DObservation) {
        var joints: [String: SCNVector3] = [:]
        var rotations: [String: SCNQuaternion] = [:]
        
        let jointNames: [VNHumanBodyPose3DObservation.JointName] = [
            .root, .spine, .centerShoulder, .centerHead, .topHead,
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        for name in jointNames {
            if let point = try? observation.recognizedPoint(name) {
                // Position is returned in meters relative to the root joint (hips)
                let translation = point.position.translation
                joints[name.rawValue.rawValue] = SCNVector3(translation.x, translation.y, translation.z)
                
                // localPosition contains the rotation relative to its parent joint
                let localMatrix = point.localPosition
                let rot3x3 = simd_float3x3(
                    simd_float3(localMatrix.columns.0.x, localMatrix.columns.0.y, localMatrix.columns.0.z),
                    simd_float3(localMatrix.columns.1.x, localMatrix.columns.1.y, localMatrix.columns.1.z),
                    simd_float3(localMatrix.columns.2.x, localMatrix.columns.2.y, localMatrix.columns.2.z)
                )
                let quat = simd_quaternion(rot3x3)
                rotations[name.rawValue.rawValue] = SCNQuaternion(quat.vector.x, quat.vector.y, quat.vector.z, quat.vector.w)
            }
        }
        
        DispatchQueue.main.async {
            self.capturedJoints = joints
            self.capturedRotations = rotations
            self.onPoseDetected?(observation)
        }
    }
    
    // MARK: - Procedural 3D Mannequin Rig Builder
    
    public static func buildMannequinRig() -> SCNNode {
        let rootNode = SCNNode()
        rootNode.name = "mocap_mannequin"
        
        // Materials
        let jointMaterial = SCNMaterial()
        jointMaterial.diffuse.contents = UIColor(red: 0.0, green: 0.95, blue: 0.9, alpha: 1.0)
        jointMaterial.emission.contents = UIColor(red: 0.0, green: 0.6, blue: 0.6, alpha: 1.0)
        jointMaterial.metalness.contents = 0.8
        jointMaterial.roughness.contents = 0.1
        
        let boneMaterial = SCNMaterial()
        boneMaterial.diffuse.contents = UIColor(white: 0.15, alpha: 1.0)
        boneMaterial.emission.contents = UIColor(red: 0.0, green: 0.15, blue: 0.3, alpha: 1.0)
        boneMaterial.metalness.contents = 0.5
        boneMaterial.roughness.contents = 0.4
        
        let jointNames = [
            "root", "spine", "centerShoulder", "centerHead", "topHead",
            "leftShoulder", "rightShoulder", "leftElbow", "rightElbow",
            "leftWrist", "rightWrist", "leftHip", "rightHip",
            "leftKnee", "rightKnee", "leftAnkle", "rightAnkle"
        ]
        
        // Create joint spheres
        for name in jointNames {
            let sphereRadius: CGFloat = (name == "centerHead" || name == "topHead") ? 0.08 : 0.04
            let sphere = SCNSphere(radius: sphereRadius)
            sphere.materials = [jointMaterial]
            
            let node = SCNNode(geometry: sphere)
            node.name = "joint_\(name)"
            rootNode.addChildNode(node)
        }
        
        // Define bone connections (parent -> child)
        let bones = [
            ("root", "spine"),
            ("spine", "centerShoulder"),
            ("centerShoulder", "centerHead"),
            ("centerHead", "topHead"),
            // Arms
            ("centerShoulder", "leftShoulder"),
            ("leftShoulder", "leftElbow"),
            ("leftElbow", "leftWrist"),
            ("centerShoulder", "rightShoulder"),
            ("rightShoulder", "rightElbow"),
            ("rightElbow", "rightWrist"),
            // Legs
            ("root", "leftHip"),
            ("leftHip", "leftKnee"),
            ("leftKnee", "leftAnkle"),
            ("root", "rightHip"),
            ("rightHip", "rightKnee"),
            ("rightKnee", "rightAnkle")
        ]
        
        // Create bone cylinders
        for (parent, child) in bones {
            let cylinder = SCNCylinder(radius: 0.02, height: 1.0)
            cylinder.materials = [boneMaterial]
            
            let boneNode = SCNNode(geometry: cylinder)
            boneNode.name = "bone_\(parent)_\(child)"
            rootNode.addChildNode(boneNode)
        }
        
        return rootNode
    }
    
    // MARK: - Real-time Retargeting
    
    public static func retarget(joints: [String: SCNVector3], to mannequin: SCNNode) {
        // 1. Update joint positions
        for (name, position) in joints {
            if let jointNode = mannequin.childNode(withName: "joint_\(name)", recursively: true) {
                jointNode.position = position
            }
        }
        
        // 2. Update bone positions, scales, and rotations to connect joints
        let bones = [
            ("root", "spine"),
            ("spine", "centerShoulder"),
            ("centerShoulder", "centerHead"),
            ("centerHead", "topHead"),
            ("centerShoulder", "leftShoulder"),
            ("leftShoulder", "leftElbow"),
            ("leftElbow", "leftWrist"),
            ("centerShoulder", "rightShoulder"),
            ("rightShoulder", "rightElbow"),
            ("rightElbow", "rightWrist"),
            ("root", "leftHip"),
            ("leftHip", "leftKnee"),
            ("leftKnee", "leftAnkle"),
            ("root", "rightHip"),
            ("rightHip", "rightKnee"),
            ("rightKnee", "rightAnkle")
        ]
        
        for (parentName, childName) in bones {
            guard let parentPos = joints[parentName],
                  let childPos = joints[childName],
                  let boneNode = mannequin.childNode(withName: "bone_\(parentName)_\(childName)", recursively: true) else {
                continue
            }
            
            // Vector from parent to child
            let dx = childPos.x - parentPos.x
            let dy = childPos.y - parentPos.y
            let dz = childPos.z - parentPos.z
            let distance = sqrt(dx*dx + dy*dy + dz*dz)
            
            // Position bone at midpoint
            boneNode.position = SCNVector3(
                parentPos.x + dx/2,
                parentPos.y + dy/2,
                parentPos.z + dz/2
            )
            
            // Scale cylinder height to match distance
            boneNode.scale = SCNVector3(1, Double(distance), 1)
            
            // Align cylinder with the vector
            let direction = SCNVector3(dx, dy, dz)
            boneNode.orientation = SCNQuaternion.rotation(from: SCNVector3(0, 1, 0), to: direction)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension NexusMotionCaptureEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isTrackingActive,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([bodyPoseRequest])
            if let observation = bodyPoseRequest.results?.first {
                extractJointData(from: observation)
            }
        } catch {
            print("Vision performance error: \(error)")
        }
    }
}

// MARK: - simd_float4x4 Extensions

extension simd_float4x4 {
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
}

// MARK: - SCNQuaternion Extensions

extension SCNQuaternion {
    /// Computes a rotation quaternion to align vector 'from' to vector 'to'
    static func rotation(from: SCNVector3, to: SCNVector3) -> SCNQuaternion {
        let v1 = simd_normalize(simd_float3(from.x, from.y, from.z))
        let v2 = simd_normalize(simd_float3(to.x, to.y, to.z))
        
        let cosTheta = simd_dot(v1, v2)
        
        // If vectors are parallel
        if cosTheta > 0.999999 {
            return SCNQuaternion(0, 0, 0, 1)
        } else if cosTheta < -0.999999 {
            // Opposite vectors: rotate 180 degrees around any orthogonal axis
            var orthogonal = simd_cross(v1, simd_float3(1, 0, 0))
            if simd_length(orthogonal) < 0.01 {
                orthogonal = simd_cross(v1, simd_float3(0, 1, 0))
            }
            orthogonal = simd_normalize(orthogonal)
            return SCNQuaternion(orthogonal.x, orthogonal.y, orthogonal.z, 0)
        }
        
        let axis = simd_normalize(simd_cross(v1, v2))
        let s = sqrt((1 + cosTheta) * 2)
        let invS = 1 / s
        
        let qVec = axis * (s * 0.5)
        let qW = s * 0.5
        
        let quat = simd_quaternion(simd_float4(qVec.x * invS, qVec.y * invS, qVec.z * invS, qW * invS))
        return SCNQuaternion(quat.vector.x, quat.vector.y, quat.vector.z, quat.vector.w)
    }
}
