import Foundation
import CoreMotion
import OSLog

// MARK: - Motion seam
//
// Hardware seam for device motion so gameplay features (jump tracking, future
// motion streams) can run from recorded traces in the Simulator, in unit tests,
// and in the dev harness. Mirrors the simulation pattern ScanCaptureService
// already uses (`-UITestMode`): live hardware by default, replay when the
// `-FELSimulatedSensors` launch argument is present.

/// One device-motion sample in g units. Codable so traces round-trip as JSON
/// fixtures (`[MotionSample]`) that the harness can record, edit, and replay.
nonisolated struct MotionSample: Sendable, Codable, Equatable {
    /// Seconds; monotonic within a trace (mirrors `CMDeviceMotion.timestamp`).
    var timestamp: TimeInterval
    var gravityX: Double
    var gravityY: Double
    var gravityZ: Double
    var userAccelerationX: Double
    var userAccelerationY: Double
    var userAccelerationZ: Double

    /// Magnitude of gravity + user acceleration — ~1 standing, ~0 in free fall.
    var totalG: Double {
        let x = gravityX + userAccelerationX
        let y = gravityY + userAccelerationY
        let z = gravityZ + userAccelerationZ
        return (x * x + y * y + z * z).squareRoot()
    }

    /// Convenience for stationary (1g) and free-fall (0g) trace authoring.
    static func resting(at t: TimeInterval) -> MotionSample {
        MotionSample(timestamp: t, gravityX: 0, gravityY: 0, gravityZ: -1,
                     userAccelerationX: 0, userAccelerationY: 0, userAccelerationZ: 0)
    }

    static func freefall(at t: TimeInterval) -> MotionSample {
        MotionSample(timestamp: t, gravityX: 0, gravityY: 0, gravityZ: -1,
                     userAccelerationX: 0, userAccelerationY: 0, userAccelerationZ: 1)
    }

    static func impact(at t: TimeInterval, g: Double = 2.4) -> MotionSample {
        MotionSample(timestamp: t, gravityX: 0, gravityY: 0, gravityZ: -1,
                     userAccelerationX: 0, userAccelerationY: 0, userAccelerationZ: -(g - 1))
    }
}

@MainActor
protocol MotionSampleProviding: AnyObject {
    var isAvailable: Bool { get }
    func startUpdates(interval: TimeInterval, handler: @escaping @MainActor (MotionSample) -> Void)
    func stopUpdates()
}

// MARK: - Live hardware provider

/// Wraps `CMMotionManager` — the production path on a physical device.
@MainActor
final class LiveMotionProvider: MotionSampleProviding {
    private let manager = CMMotionManager()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func startUpdates(interval: TimeInterval, handler: @escaping @MainActor (MotionSample) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = interval
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let sample = MotionSample(
                timestamp: motion.timestamp,
                gravityX: motion.gravity.x,
                gravityY: motion.gravity.y,
                gravityZ: motion.gravity.z,
                userAccelerationX: motion.userAcceleration.x,
                userAccelerationY: motion.userAcceleration.y,
                userAccelerationZ: motion.userAcceleration.z
            )
            MainActor.assumeIsolated { handler(sample) }
        }
    }

    func stopUpdates() {
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Replay provider

/// Plays a recorded/authored `[MotionSample]` trace. `realtime: true` paces
/// delivery by the trace's own timestamps (Simulator demos); `realtime: false`
/// delivers every sample synchronously on start (deterministic unit tests).
@MainActor
final class ReplayMotionProvider: MotionSampleProviding {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab",
        category: "ReplayMotionProvider"
    )

    private let samples: [MotionSample]
    private let realtime: Bool
    private let loops: Bool
    private var playbackTask: Task<Void, Never>?

    init(samples: [MotionSample], realtime: Bool = true, loops: Bool = false) {
        self.samples = samples.sorted { $0.timestamp < $1.timestamp }
        self.realtime = realtime
        self.loops = loops
    }

    convenience init(traceURL: URL, realtime: Bool = true, loops: Bool = false) throws {
        let data = try Data(contentsOf: traceURL)
        let samples = try JSONDecoder().decode([MotionSample].self, from: data)
        self.init(samples: samples, realtime: realtime, loops: loops)
    }

    var isAvailable: Bool { !samples.isEmpty }

    func startUpdates(interval: TimeInterval, handler: @escaping @MainActor (MotionSample) -> Void) {
        stopUpdates()
        guard !samples.isEmpty else { return }
        if !realtime {
            for sample in samples { handler(sample) }
            return
        }
        let samples = self.samples
        let loops = self.loops
        playbackTask = Task { @MainActor in
            var passStartOffset: TimeInterval = 0
            repeat {
                var previous = samples[0].timestamp
                for sample in samples {
                    if Task.isCancelled { return }
                    let delay = sample.timestamp - previous
                    if delay > 0 {
                        try? await Task.sleep(for: .seconds(delay))
                    }
                    previous = sample.timestamp
                    var shifted = sample
                    shifted.timestamp += passStartOffset
                    handler(shifted)
                }
                // Keep timestamps monotonic across loop passes.
                passStartOffset += (samples.last!.timestamp - samples[0].timestamp) + 1.0
            } while loops && !Task.isCancelled
        }
    }

    func stopUpdates() {
        playbackTask?.cancel()
        playbackTask = nil
    }
}

// MARK: - Trace authoring

extension ReplayMotionProvider {
    /// Synthesizes a jump trace at 100Hz: stand → free fall for `flightTime`
    /// seconds → landing impact → stand. Flight-time method: h = g·t²/8.
    static func syntheticJumpTrace(flightTime: TimeInterval, startingAt t0: TimeInterval = 1.0) -> [MotionSample] {
        var samples: [MotionSample] = []
        let dt = 0.01
        var t = 0.0
        while t < t0 { samples.append(.resting(at: t)); t += dt }
        let takeoff = t
        while t < takeoff + flightTime { samples.append(.freefall(at: t)); t += dt }
        samples.append(.impact(at: t))
        t += dt
        let settleEnd = t + 0.5
        while t < settleEnd { samples.append(.resting(at: t)); t += dt }
        return samples
    }

    /// Demo provider for the Simulator: one ~0.5s-flight jump (~12"), looping.
    static func syntheticJumpLoop() -> ReplayMotionProvider {
        ReplayMotionProvider(samples: syntheticJumpTrace(flightTime: 0.5), realtime: true, loops: true)
    }
}

// MARK: - Factory

enum MotionProviderFactory {
    /// `-FELSimulatedSensors` launch argument (or any Simulator run with
    /// `FEL_MOTION_TRACE` set) swaps live hardware for trace replay — same
    /// convention as ScanCaptureService's `-UITestMode` simulation path.
    @MainActor
    static func makeDefault() -> MotionSampleProviding {
        let process = ProcessInfo.processInfo
        let simulated = process.arguments.contains("-FELSimulatedSensors")
        let tracePath = process.environment["FEL_MOTION_TRACE"]

        if let tracePath, simulated || tracePath.isEmpty == false {
            if let provider = try? ReplayMotionProvider(
                traceURL: URL(fileURLWithPath: tracePath), realtime: true, loops: true
            ), provider.isAvailable {
                return provider
            }
        }
        if simulated {
            return ReplayMotionProvider.syntheticJumpLoop()
        }
        return LiveMotionProvider()
    }
}
