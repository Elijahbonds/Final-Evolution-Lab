import ARKit
import AVFoundation
import CoreMotion
import Foundation
import Vision

/// Captures body/motion metrics via ARKit pose, Vision camera, or CoreMotion fallback.
@MainActor
@Observable
final class ScanCaptureService {
    enum Phase: Equatable {
        case idle
        case capturing(progress: Double)
        case complete(ScanEnvelope)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var usesSimulation: Bool = false

    private let motionManager = CMMotionManager()
    private var captureTask: Task<Void, Never>?
    private var peakAccelG: Double = 0
    private var motionSamples: [(ax: Double, ay: Double, az: Double)] = []

    private var visionJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    private var visionConfidence: Double = 0
    private var bodySession: ARSession?
    private var bodyAnchorAvailable = false

    static let captureDurationSeconds: Double = 4.0

    var previewLabel: String {
        if usesSimulation {
            return FELPremiumCopy.Preview.simulatedPose
        }
        switch phase {
        case .complete(let envelope):
            return envelope.measuredSource
                ? "Live scan · Ready to generate"
                : FELPremiumCopy.humanizePreviewLabel("PREVIEW · \(envelope.source.rawValue.uppercased())")
        default:
            return FELPremiumCopy.Preview.scanToGenerate
        }
    }

    func startCapture(preferARKit: Bool = true) {
        cancelCapture()
        peakAccelG = 0
        motionSamples.removeAll()
        visionJoints.removeAll()
        visionConfidence = 0
        bodyAnchorAvailable = false

        #if targetEnvironment(simulator)
        usesSimulation = true
        #else
        usesSimulation = ProcessInfo.processInfo.arguments.contains("-UITestMode")
        #endif

        if usesSimulation {
            runSimulatedCapture()
            return
        }

        startCoreMotionSampling()

        if preferARKit, ARBodyTrackingConfiguration.isSupported {
            startARKitBodyCapture()
        } else {
            startVisionCapture()
        }

        captureTask = Task {
            let steps = 40
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(Int(Self.captureDurationSeconds * 1000 / Double(steps))))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    phase = .capturing(progress: Double(step) / Double(steps))
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                finishLiveCapture(source: bodyAnchorAvailable ? .arkitPose : .visionCamera)
            }
        }
    }

    func cancelCapture() {
        captureTask?.cancel()
        captureTask = nil
        stopCoreMotionSampling()
        bodySession?.pause()
        bodySession = nil
        if phase.isCapturing {
            phase = .idle
        }
    }

    private var phaseIsCapturing: Bool {
        if case .capturing = phase { return true }
        return false
    }

    private func runSimulatedCapture() {
        captureTask = Task {
            let steps = 20
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    phase = .capturing(progress: Double(step) / Double(steps))
                }
            }
            guard !Task.isCancelled else { return }
            let envelope = ScanCaptureService.simulatedEnvelope()
            await MainActor.run {
                phase = .complete(envelope)
            }
        }
    }

    static func simulatedEnvelope() -> ScanEnvelope {
        ScanEnvelope(
            schemaVersion: ScanEnvelope.currentSchemaVersion,
            scanId: UUID().uuidString,
            source: .simulated,
            capturedAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000),
            confidence01: 0.42,
            joints: .init(
                leftKneeAngleDeg: 108,
                rightKneeAngleDeg: 112,
                leftShoulderReach01: 0.62,
                rightShoulderReach01: 0.59,
                hipStability01: 0.71
            ),
            motion: .init(
                verticalEstimateInches: 24.5,
                flightTimeSeconds: 0.48,
                peakAccelG: 1.15
            ),
            frcProxies: nil
        )
    }

    private func startCoreMotionSampling() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 60.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let ax = data.acceleration.x
            let ay = data.acceleration.y
            let az = data.acceleration.z
            let magnitude = sqrt(ax * ax + ay * ay + az * az)
            self.peakAccelG = max(self.peakAccelG, magnitude)
            self.motionSamples.append((ax, ay, az))
            if self.motionSamples.count > 240 {
                self.motionSamples.removeFirst(self.motionSamples.count - 240)
            }
        }
    }

    private func stopCoreMotionSampling() {
        motionManager.stopAccelerometerUpdates()
    }

    private func startARKitBodyCapture() {
        let session = ARSession()
        let config = ARBodyTrackingConfiguration()
        config.isAutoFocusEnabled = true
        config.frameSemantics.insert(.bodyDetection)
        session.run(config)
        bodySession = session
        bodyAnchorAvailable = true
    }

    private func startVisionCapture() {
        // Vision sampling is driven by ScanCaptureCameraProbe when embedded in the capture UI.
    }

    func ingestVisionFrame(joints: [VNHumanBodyPoseObservation.JointName: CGPoint], confidence: Double) {
        visionJoints = joints
        visionConfidence = confidence
    }

    private func finishLiveCapture(source: ScanCaptureSource) {
        stopCoreMotionSampling()
        bodySession?.pause()
        bodySession = nil

        let resolvedSource: ScanCaptureSource
        if motionSamples.count > 8, visionJoints.isEmpty, !bodyAnchorAvailable {
            resolvedSource = .coreMotion
        } else {
            resolvedSource = source
        }

        let metrics = computeJointMetrics(from: visionJoints)
        let flight = estimateFlightTime(from: motionSamples)
        let vertical = estimateVerticalInches(flightSeconds: flight, peakG: peakAccelG)
        let confidence = min(1, max(0.15, max(visionConfidence, bodyAnchorAvailable ? 0.72 : 0.45)))

        let envelope = ScanEnvelope(
            schemaVersion: ScanEnvelope.currentSchemaVersion,
            scanId: UUID().uuidString,
            source: resolvedSource,
            capturedAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000),
            confidence01: confidence,
            joints: metrics,
            motion: .init(
                verticalEstimateInches: vertical,
                flightTimeSeconds: flight,
                peakAccelG: peakAccelG
            ),
            frcProxies: nil
        )
        phase = .complete(envelope)
    }

    private func computeJointMetrics(from joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> ScanEnvelope.JointMetrics {
        guard let hipL = joints[.leftHip],
              let kneeL = joints[.leftKnee],
              let ankleL = joints[.leftAnkle],
              let hipR = joints[.rightHip],
              let kneeR = joints[.rightKnee],
              let ankleR = joints[.rightAnkle],
              let shoulderL = joints[.leftShoulder],
              let shoulderR = joints[.rightShoulder],
              let wristL = joints[.leftWrist],
              let wristR = joints[.rightWrist]
        else {
            return .init(
                leftKneeAngleDeg: 165,
                rightKneeAngleDeg: 165,
                leftShoulderReach01: 0.5,
                rightShoulderReach01: 0.5,
                hipStability01: 0.55
            )
        }

        let leftKnee = angleDegrees(a: hipL, b: kneeL, c: ankleL)
        let rightKnee = angleDegrees(a: hipR, b: kneeR, c: ankleR)
        let leftReach = min(1, max(0, distance(shoulderL, wristL) * 2.2))
        let rightReach = min(1, max(0, distance(shoulderR, wristR) * 2.2))
        let hipWidth = abs(hipL.x - hipR.x)
        let kneeWidth = abs(kneeL.x - kneeR.x)
        let stability = min(1, max(0, 1 - abs(kneeWidth - hipWidth) * 3))

        return .init(
            leftKneeAngleDeg: leftKnee,
            rightKneeAngleDeg: rightKnee,
            leftShoulderReach01: leftReach,
            rightShoulderReach01: rightReach,
            hipStability01: stability
        )
    }

    private func angleDegrees(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let len1 = hypot(v1.dx, v1.dy)
        let len2 = hypot(v2.dx, v2.dy)
        guard len1 > 0.001, len2 > 0.001 else { return 180 }
        let cosAngle = (v1.dx * v2.dx + v1.dy * v2.dy) / (len1 * len2)
        return Darwin.acos(min(1, max(-1, cosAngle))) * 180 / .pi
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func estimateFlightTime(from samples: [(ax: Double, ay: Double, az: Double)]) -> Double {
        guard samples.count > 4 else { return 0.42 }
        var peaks: [Double] = []
        for index in 1..<(samples.count - 1) {
            let prev = samples[index - 1]
            let curr = samples[index]
            let next = samples[index + 1]
            let magPrev = sqrt(prev.ax * prev.ax + prev.ay * prev.ay + prev.az * prev.az)
            let magCurr = sqrt(curr.ax * curr.ax + curr.ay * curr.ay + curr.az * curr.az)
            let magNext = sqrt(next.ax * next.ax + next.ay * next.ay + next.az * next.az)
            if magCurr > magPrev, magCurr > magNext, magCurr > 1.05 {
                peaks.append(magCurr)
            }
        }
        let peakCount = max(1, peaks.count)
        return min(0.72, max(0.28, Double(peakCount) * 0.08))
    }

    private func estimateVerticalInches(flightSeconds: Double, peakG: Double) -> Double {
        let gravity = 386.09
        let inches = 0.5 * gravity * pow(flightSeconds / 2, 2) / 12
        return min(38, max(16, inches + peakG * 2.5))
    }
}

private extension ScanCaptureService.Phase {
    var isCapturing: Bool {
        if case .capturing = self { return true }
        return false
    }
}

private extension ScanEnvelope {
    var measuredSource: Bool {
        source == .arkitPose || source == .visionCamera
    }
}
