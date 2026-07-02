import Foundation
import CoreGraphics
import Vision
import Testing
@testable import FinalEvolutionLab

/// Dev-harness seam: a recorded pose trace drives ScanCaptureService's capture
/// through the existing `ingestVisionFrame` injection point — deterministic,
/// camera-free, and producing a real completed ScanEnvelope.
@MainActor
struct PoseTraceTests {

    private func squatDunkTrace() -> [PoseFrame] {
        // Stand → dip (knees rise toward hips) → extend, 3 frames.
        let stand = PoseFrame.neutralStance(at: 0.0)
        var dip = PoseFrame.neutralStance(at: 0.5, confidence: 0.85)
        let leftKnee = VNHumanBodyPoseObservation.JointName.leftKnee.rawValue.rawValue
        let rightKnee = VNHumanBodyPoseObservation.JointName.rightKnee.rawValue.rawValue
        dip.joints[leftKnee] = .init(x: 0.45, y: 0.40)
        dip.joints[rightKnee] = .init(x: 0.55, y: 0.40)
        let extend = PoseFrame.neutralStance(at: 1.0, confidence: 0.9)
        return [stand, dip, extend]
    }

    @Test func neutralStanceCarriesAllMetricJoints() {
        let frame = PoseFrame.neutralStance(at: 0)
        let typed = frame.visionJoints
        // computeJointMetrics needs both hips, knees, ankles.
        for joint: VNHumanBodyPoseObservation.JointName in
            [.leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle] {
            #expect(typed[joint] != nil, "missing \(joint.rawValue.rawValue)")
        }
    }

    @Test func replayFeedsIngestPathWithoutCrashing() {
        let service = ScanCaptureService()
        let provider = service.replayPoseTrace(squatDunkTrace(), realtime: false)
        // Synchronous replay drains the whole trace into ingestVisionFrame on
        // return; the provider had frames to play.
        #expect(provider.isAvailable)
    }

    @Test func emptyTraceProviderIsUnavailable() {
        let provider = PoseTraceProvider(frames: [], realtime: false)
        #expect(!provider.isAvailable)
    }

    @Test func poseFrameRoundTripsThroughJSON() throws {
        let trace = squatDunkTrace()
        let data = try JSONEncoder().encode(trace)
        let decoded = try JSONDecoder().decode([PoseFrame].self, from: data)
        #expect(decoded == trace)
    }

    @Test func typedJointInitPreservesRawKeys() {
        let frame = PoseFrame(timestamp: 0, confidence: 1, typedJoints: [
            .leftKnee: CGPoint(x: 0.1, y: 0.2)
        ])
        let key = VNHumanBodyPoseObservation.JointName.leftKnee.rawValue.rawValue
        #expect(frame.joints[key] != nil)
        #expect(frame.visionJoints[.leftKnee] == CGPoint(x: 0.1, y: 0.2))
    }
}
