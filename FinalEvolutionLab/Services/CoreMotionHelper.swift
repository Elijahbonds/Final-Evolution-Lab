import CoreMotion
import Foundation
import OSLog

@Observable
@MainActor
final class CoreMotionHelper {
    static let shared = CoreMotionHelper()

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab", category: "CoreMotionHelper")
    private static var didLogNexusOnlyPreview = false

    private let motionManager = CMMotionManager()
    private(set) var isStreaming: Bool = false

    private(set) var accelerationX: Double = 0
    private(set) var accelerationY: Double = 0
    private(set) var accelerationZ: Double = 0

    private(set) var gyroX: Double = 0
    private(set) var gyroY: Double = 0
    private(set) var gyroZ: Double = 0

    private(set) var pitch: Double = 0
    private(set) var roll: Double = 0
    private(set) var yaw: Double = 0

    private init() {}

    func startStreaming() {
        guard !isStreaming else { return }
        isStreaming = true

        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 60.0
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.accelerationX = data.acceleration.x
                self.accelerationY = data.acceleration.y
                self.accelerationZ = data.acceleration.z
                self.relayMotionSample()
            }
        }

        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 1.0 / 60.0
            motionManager.startGyroUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.gyroX = data.rotationRate.x
                self.gyroY = data.rotationRate.y
                self.gyroZ = data.rotationRate.z
            }
        }

        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.pitch = data.attitude.pitch
                self.roll = data.attitude.roll
                self.yaw = data.attitude.yaw
            }
        }
    }

    func stopStreaming() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        isStreaming = false
    }

    private func relayMotionSample() {
        let payload: [String: Double] = [
            "ax": accelerationX,
            "ay": accelerationY,
            "az": accelerationZ,
            "gx": gyroX,
            "gy": gyroY,
            "gz": gyroZ,
            "t": Date().timeIntervalSince1970
        ]

        guard (try? JSONSerialization.data(withJSONObject: payload)) != nil else { return }

        logNexusOnlyPreviewOnce()
    }

    private func logNexusOnlyPreviewOnce() {
        guard !Self.didLogNexusOnlyPreview else { return }
        Self.didLogNexusOnlyPreview = true
        Self.log.notice("Motion relay disabled (NEXUS-only) — samples kept in Swift only.")
#if DEBUG
        print("[CoreMotionHelper] Motion relay disabled (NEXUS-only) — motion sampled locally only.")
#endif
    }

    var totalAcceleration: Double {
        sqrt(accelerationX * accelerationX + accelerationY * accelerationY + accelerationZ * accelerationZ)
    }
}
