import Foundation

/// 1D Kalman — dampens frame-to-frame noise (lighting, clothing) before leakage / joint thresholds.
nonisolated struct FELKalmanFilter1D: Sendable {
    var x: Double = 0
    var p: Double = 1
    var q: Double = 0.0008
    var r: Double = 0.22

    mutating func update(measurement z: Double) -> Double {
        guard z.isFinite else { return x }
        p += q
        let k = p / (p + r)
        x += k * (z - x)
        p *= (1 - k)
        return x
    }

    mutating func reset(initial: Double = 0) {
        x = initial
        p = 1
    }
}
