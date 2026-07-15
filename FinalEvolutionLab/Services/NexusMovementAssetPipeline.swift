import Combine
import Foundation
import SceneKit

/// Custom lightweight animation asset format that stores header metadata and keyframe joint transforms.
public struct NexusMovementCaptureAsset: Codable, Identifiable {
    public var id: UUID {
        UUID(uuidString: "\(header.athleteID)-\(header.captureTimestamp)") ?? UUID()
    }
    
    public struct Header: Codable {
        public var athleteID: String
        public var captureTimestamp: TimeInterval
        public var frameRate: Double
        public var duration: Double
        public var jointCount: Int
        public var movementType: String // e.g., "Jump", "Squat", "Kick"
    }
    
    public struct JointTransform: Codable {
        public var rotation: [Float] // Quaternion [x, y, z, w]
        public var translation: [Float] // [x, y, z]
    }
    
    public struct Keyframe: Codable {
        public var timestamp: Double
        public var joints: [String: JointTransform] // JointName rawValue -> JointTransform
    }
    
    public var header: Header
    public var keyframes: [Keyframe]
}

/// Pipeline to record, serialize, save, load, and export captured animations.
/// Also exposes bundled canonical animations (from NexusAnimationLoader) alongside
/// live-recorded ones so the rest of the app has a single source of truth.
public class NexusMovementAssetPipeline: ObservableObject {
    @Published public var recordedAnimations: [NexusMovementCaptureAsset] = []
    @Published public var isRecording = false

    // MARK: - Canonical Bundled Animation Access

    /// Returns a pre-baked NexusAnimationAsset from the app bundle by Seeles/animation id.
    /// These are the recreated versions of the remote FBX files — fully usable at runtime.
    public func canonicalAnimation(for animationId: String) -> NexusAnimationAsset? {
        NexusAnimationLoader.shared.load(animationId)
    }

    /// Samples a canonical animation at a given playback time (seconds).
    /// Returns joint rotations keyed by bone name for use with NexusMoCapRetargeter.
    public func sampleCanonical(
        _ animationId: String,
        at time: Double,
        looping: Bool = false
    ) -> [String: SCNQuaternion] {
        guard let asset = canonicalAnimation(for: animationId) else { return [:] }
        return looping
            ? NexusAnimationLoader.shared.sampleLooping(asset, at: time)
            : NexusAnimationLoader.shared.samplePose(asset, at: time)
    }

    /// Pre-warms the animation loader cache for all known bundled animations.
    public func preloadCanonicalAnimations() {
        NexusAnimationLoader.shared.preloadAll()
    }
    
    private var currentRecordingKeyframes: [NexusMovementCaptureAsset.Keyframe] = []
    private var recordingStartTime: Date?
    private var activeAthleteID: String = "ATHLETE_01"
    private var activeMovementType: String = "Athletic Drill"
    
    private let fileManager = FileManager.default
    private var animationsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("NexusAnimations", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        return directory
    }
    
    public static let shared = NexusMovementAssetPipeline()
    
    public init() {
        loadRecordedAnimations()
    }
    
    // MARK: - Recording Controls
    
    public func startRecording(athleteID: String, movementType: String) {
        activeAthleteID = athleteID
        activeMovementType = movementType
        currentRecordingKeyframes.removeAll()
        recordingStartTime = Date()
        isRecording = true
    }
    
    public func addKeyframe(joints: [String: SCNVector3], rotations: [String: SCNQuaternion]) {
        guard isRecording, let startTime = recordingStartTime else { return }
        let timestamp = Date().timeIntervalSince(startTime)
        
        var jointTransforms: [String: NexusMovementCaptureAsset.JointTransform] = [:]
        for (name, position) in joints {
            let rotation = rotations[name] ?? SCNQuaternion(0, 0, 0, 1)
            jointTransforms[name] = NexusMovementCaptureAsset.JointTransform(
                rotation: [Float(rotation.x), Float(rotation.y), Float(rotation.z), Float(rotation.w)],
                translation: [Float(position.x), Float(position.y), Float(position.z)]
            )
        }
        
        let keyframe = NexusMovementCaptureAsset.Keyframe(timestamp: timestamp, joints: jointTransforms)
        currentRecordingKeyframes.append(keyframe)
    }
    
    public func stopRecording() -> NexusMovementCaptureAsset? {
        guard isRecording, let startTime = recordingStartTime else { return nil }
        isRecording = false
        
        let duration = Date().timeIntervalSince(startTime)
        let frameRate = duration > 0 ? Double(currentRecordingKeyframes.count) / duration : 30.0
        let jointCount = currentRecordingKeyframes.first?.joints.count ?? 0
        
        let header = NexusMovementCaptureAsset.Header(
            athleteID: activeAthleteID,
            captureTimestamp: startTime.timeIntervalSince1970,
            frameRate: frameRate,
            duration: duration,
            jointCount: jointCount,
            movementType: activeMovementType
        )
        
        let asset = NexusMovementCaptureAsset(header: header, keyframes: currentRecordingKeyframes)
        
        // Save to disk
        if let savedURL = saveAnimation(asset) {
            print("Animation saved successfully to: \(savedURL.lastPathComponent)")
            loadRecordedAnimations()
        }
        
        return asset
    }
    
    // MARK: - Disk Persistence
    
    @discardableResult
    public func saveAnimation(_ asset: NexusMovementCaptureAsset) -> URL? {
        let filename = "nexusanim_\(Int(asset.header.captureTimestamp)).nexusanim.json"
        let fileURL = animationsDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(asset) else { return nil }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Failed to write animation asset to disk: \(error)")
            return nil
        }
    }
    
    public func loadRecordedAnimations() {
        guard let files = try? fileManager.contentsOfDirectory(at: animationsDirectory, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        
        let decoder = JSONDecoder()
        var loaded: [NexusMovementCaptureAsset] = []
        
        for file in files where file.pathExtension == "json" && file.lastPathComponent.contains("nexusanim_") {
            if let data = try? Data(contentsOf: file),
               let asset = try? decoder.decode(NexusMovementCaptureAsset.self, from: data) {
                loaded.append(asset)
            }
        }
        
        // Sort by newest first
        loaded.sort { $0.header.captureTimestamp > $1.header.captureTimestamp }
        
        DispatchQueue.main.async {
            self.recordedAnimations = loaded
        }
    }
    
    public func deleteAnimation(_ asset: NexusMovementCaptureAsset) {
        let filename = "nexusanim_\(Int(asset.header.captureTimestamp)).nexusanim.json"
        let fileURL = animationsDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
        loadRecordedAnimations()
    }
    
    // MARK: - Exporting & Sharing
    
    public func exportAnimationAsJson(_ asset: NexusMovementCaptureAsset) -> URL? {
        let tempDir = fileManager.temporaryDirectory
        let filename = "\(asset.header.movementType.replacingOccurrences(of: " ", with: "_"))_Capture.nexusanim.json"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(asset) else { return nil }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Failed to export animation: \(error)")
            return nil
        }
    }
}
