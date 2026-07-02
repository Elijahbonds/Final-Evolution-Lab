import CoreMotion
import Foundation

@Observable
@MainActor
final class CoreMotionHelper {
    static let shared = CoreMotionHelper()

    private let motionManager = CMMotionManager()
    private(set) var isStreaming: Bool = false

    private(set) var accelerationX: Double = 0
    private(set) var accelerationY: Double = 0
    private(set) var accelerationZ: Double = 0

    private(set) var gyroX: Double = 0
    private(set) var gyroY: Double = 0
    private(set) var gyroZ: Double = 0

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
                self.sendMotionToUnity()
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
    }

    func stopStreaming() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        isStreaming = false
    }

    private func sendMotionToUnity() {
        let payload: [String: Double] = [
            "ax": accelerationX,
            "ay": accelerationY,
            "az": accelerationZ,
            "gx": gyroX,
            "gy": gyroY,
            "gz": gyroZ,
            "t": Date().timeIntervalSince1970
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        UnityManager.shared.sendDataToUnity(data: jsonString)
    }

    var totalAcceleration: Double {
        sqrt(accelerationX * accelerationX + accelerationY * accelerationY + accelerationZ * accelerationZ)
    }
}
