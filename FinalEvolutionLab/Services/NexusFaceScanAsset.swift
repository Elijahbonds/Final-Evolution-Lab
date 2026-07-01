import Combine
import Foundation

/// Custom lightweight facial animation asset format that stores header metadata and keyframe blendshape values.
public struct NexusFaceScanAsset: Codable, Identifiable {
    public var id: UUID {
        UUID(uuidString: "\(header.athleteID)-\(header.captureTimestamp)") ?? UUID()
    }
    
    public struct Header: Codable {
        public var athleteID: String
        public var scanID: String
        public var captureTimestamp: TimeInterval
        public var frameRate: Double
        public var duration: Double
        public var blendshapeCount: Int
    }
    
    public struct Keyframe: Codable {
        public var timestamp: Double
        public var blendshapes: [String: Float] // Blendshape name -> value (0.0 to 1.0)
    }
    
    public var header: Header
    public var keyframes: [Keyframe]
}

/// Pipeline to record, serialize, save, load, and export captured facial animations.
public class NexusFaceScanAssetPipeline: ObservableObject {
    @Published public var recordedFaceScans: [NexusFaceScanAsset] = []
    @Published public var isRecording = false
    
    private var currentRecordingKeyframes: [NexusFaceScanAsset.Keyframe] = []
    private var recordingStartTime: Date?
    private var activeAthleteID: String = "ATHLETE_01"
    private var activeScanID: String = "SCAN_01"
    
    private let fileManager = FileManager.default
    private var faceScansDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("NexusFaceScans", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        return directory
    }
    
    public static let shared = NexusFaceScanAssetPipeline()
    
    public init() {
        loadRecordedFaceScans()
    }
    
    // MARK: - Recording Controls
    
    public func startRecording(athleteID: String, scanID: String) {
        activeAthleteID = athleteID
        activeScanID = scanID
        currentRecordingKeyframes.removeAll()
        recordingStartTime = Date()
        isRecording = true
    }
    
    public func addKeyframe(blendshapes: [String: Float]) {
        guard isRecording, let startTime = recordingStartTime else { return }
        let timestamp = Date().timeIntervalSince(startTime)
        
        let keyframe = NexusFaceScanAsset.Keyframe(timestamp: timestamp, blendshapes: blendshapes)
        currentRecordingKeyframes.append(keyframe)
    }
    
    public func stopRecording() -> NexusFaceScanAsset? {
        guard isRecording, let startTime = recordingStartTime else { return nil }
        isRecording = false
        
        let duration = Date().timeIntervalSince(startTime)
        let frameRate = duration > 0 ? Double(currentRecordingKeyframes.count) / duration : 30.0
        let blendshapeCount = currentRecordingKeyframes.first?.blendshapes.count ?? 0
        
        let header = NexusFaceScanAsset.Header(
            athleteID: activeAthleteID,
            scanID: activeScanID,
            captureTimestamp: startTime.timeIntervalSince1970,
            frameRate: frameRate,
            duration: duration,
            blendshapeCount: blendshapeCount
        )
        
        let asset = NexusFaceScanAsset(header: header, keyframes: currentRecordingKeyframes)
        
        // Save to disk
        if let savedURL = saveFaceScan(asset) {
            print("Face Scan saved successfully to: \(savedURL.lastPathComponent)")
            loadRecordedFaceScans()
        }
        
        return asset
    }
    
    // MARK: - Disk Persistence
    
    @discardableResult
    public func saveFaceScan(_ asset: NexusFaceScanAsset) -> URL? {
        let filename = "nexusface_\(Int(asset.header.captureTimestamp)).nexusface.json"
        let fileURL = faceScansDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(asset) else { return nil }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Failed to write face scan asset to disk: \(error)")
            return nil
        }
    }
    
    public func loadRecordedFaceScans() {
        guard let files = try? fileManager.contentsOfDirectory(at: faceScansDirectory, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        
        let decoder = JSONDecoder()
        var loaded: [NexusFaceScanAsset] = []
        
        for file in files where file.pathExtension == "json" && file.lastPathComponent.contains("nexusface_") {
            if let data = try? Data(contentsOf: file),
               let asset = try? decoder.decode(NexusFaceScanAsset.self, from: data) {
                loaded.append(asset)
            }
        }
        
        // Sort by newest first
        loaded.sort { $0.header.captureTimestamp > $1.header.captureTimestamp }
        
        DispatchQueue.main.async {
            self.recordedFaceScans = loaded
        }
    }
    
    public func deleteFaceScan(_ asset: NexusFaceScanAsset) {
        let filename = "nexusface_\(Int(asset.header.captureTimestamp)).nexusface.json"
        let fileURL = faceScansDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
        loadRecordedFaceScans()
    }
    
    // MARK: - Exporting & Sharing
    
    public func exportFaceScanAsJson(_ asset: NexusFaceScanAsset) -> URL? {
        let tempDir = fileManager.temporaryDirectory
        let filename = "FaceScan_\(asset.header.scanID).nexusface.json"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(asset) else { return nil }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Failed to export face scan: \(error)")
            return nil
        }
    }
}
