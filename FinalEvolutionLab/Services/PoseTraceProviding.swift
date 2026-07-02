import Foundation
import CoreGraphics
import Vision

// MARK: - Camera pose seam
//
// The live camera path already exposes a clean injection point:
// `ScanCaptureService.ingestVisionFrame(joints:confidence:)`, driven by
// ScanCaptureCameraProbe on device. This seam feeds that same method from a
// recorded/authored `[PoseFrame]` trace, so pose-driven capture (dunk form,
// movement scan) runs deterministically in the Simulator and in tests without
// a camera — the camera analogue of the motion seam.

/// One normalized-coordinate body-pose frame. Joint keys are the raw string
/// values of `VNHumanBodyPoseObservation.JointName`, so traces are Codable
/// JSON fixtures the harness can record, trim, and replay.
nonisolated struct PoseFrame: Sendable, Codable, Equatable {
    var timestamp: TimeInterval
    var confidence: Double
    /// joint raw name → normalized point (0…1, Vision's bottom-left origin).
    var joints: [String: CGPointCodable]

    struct CGPointCodable: Sendable, Codable, Equatable {
        var x: Double
        var y: Double
        var cgPoint: CGPoint { CGPoint(x: x, y: y) }
        init(_ p: CGPoint) { x = p.x; y = p.y }
        init(x: Double, y: Double) { self.x = x; self.y = y }
    }

    /// Decode joints back into Vision's typed dictionary for `ingestVisionFrame`.
    var visionJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var out: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (raw, p) in joints {
            out[VNHumanBodyPoseObservation.JointName(rawValue: VNRecognizedPointKey(rawValue: raw))] = p.cgPoint
        }
        return out
    }

    init(timestamp: TimeInterval, confidence: Double, joints: [String: CGPoint]) {
        self.timestamp = timestamp
        self.confidence = confidence
        self.joints = joints.mapValues(CGPointCodable.init)
    }

    /// Author from typed Vision joint names so trace keys always match the raw
    /// strings `ScanCaptureService` reads back.
    init(timestamp: TimeInterval, confidence: Double,
         typedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        self.timestamp = timestamp
        self.confidence = confidence
        var out: [String: CGPointCodable] = [:]
        for (name, p) in typedJoints {
            out[name.rawValue.rawValue] = CGPointCodable(p)
        }
        self.joints = out
    }
}

@MainActor
protocol PoseTraceProviding: AnyObject {
    var isAvailable: Bool { get }
    func start(handler: @escaping @MainActor (PoseFrame) -> Void)
    func stop()
}

/// Plays a recorded/authored `[PoseFrame]` trace. `realtime: true` paces by the
/// trace's own timestamps (Simulator demos); `false` delivers synchronously
/// (deterministic tests).
@MainActor
final class PoseTraceProvider: PoseTraceProviding {
    private let frames: [PoseFrame]
    private let realtime: Bool
    private var task: Task<Void, Never>?

    init(frames: [PoseFrame], realtime: Bool = true) {
        self.frames = frames.sorted { $0.timestamp < $1.timestamp }
        self.realtime = realtime
    }

    convenience init(traceURL: URL, realtime: Bool = true) throws {
        let data = try Data(contentsOf: traceURL)
        self.init(frames: try JSONDecoder().decode([PoseFrame].self, from: data), realtime: realtime)
    }

    var isAvailable: Bool { !frames.isEmpty }

    func start(handler: @escaping @MainActor (PoseFrame) -> Void) {
        stop()
        guard !frames.isEmpty else { return }
        if !realtime {
            for frame in frames { handler(frame) }
            return
        }
        let frames = self.frames
        task = Task { @MainActor in
            var previous = frames[0].timestamp
            for frame in frames {
                if Task.isCancelled { return }
                let delay = frame.timestamp - previous
                if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                previous = frame.timestamp
                handler(frame)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Driving ScanCaptureService from a pose trace

@MainActor
extension ScanCaptureService {
    /// Feeds a pose trace through the existing `ingestVisionFrame` injection
    /// point. Use `realtime: false` in tests for synchronous, deterministic
    /// ingestion of the final frame.
    func replayPoseTrace(_ frames: [PoseFrame], realtime: Bool = true) -> PoseTraceProvider {
        let provider = PoseTraceProvider(frames: frames, realtime: realtime)
        provider.start { [weak self] frame in
            self?.ingestVisionFrame(joints: frame.visionJoints, confidence: frame.confidence)
        }
        return provider
    }
}

// MARK: - Trace authoring

extension PoseFrame {
    /// A neutral standing pose (normalized coords) built from the exact joint
    /// names `computeJointMetrics` reads (hips, knees, ankles, shoulders).
    /// Starting point for authoring dunk/squat progressions by nudging joint Y.
    static func neutralStance(at t: TimeInterval, confidence: Double = 0.8) -> PoseFrame {
        PoseFrame(timestamp: t, confidence: confidence, typedJoints: [
            .leftShoulder:  CGPoint(x: 0.42, y: 0.72),
            .rightShoulder: CGPoint(x: 0.58, y: 0.72),
            .leftHip:       CGPoint(x: 0.45, y: 0.50),
            .rightHip:      CGPoint(x: 0.55, y: 0.50),
            .leftKnee:      CGPoint(x: 0.45, y: 0.30),
            .rightKnee:     CGPoint(x: 0.55, y: 0.30),
            .leftAnkle:     CGPoint(x: 0.45, y: 0.10),
            .rightAnkle:    CGPoint(x: 0.55, y: 0.10),
        ])
    }
}
