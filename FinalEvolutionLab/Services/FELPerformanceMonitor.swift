import Foundation
import QuartzCore
import UIKit

@objc public enum FELPerformanceTier: Int {
    case high = 0
    case balanced = 1
    case lowPower = 2

    public var name: String {
        switch self {
        case .high: return "high"
        case .balanced: return "balanced"
        case .lowPower: return "lowPower"
        }
    }

    /// Worst-tier merge for bidirectional iOS ↔ engine sync.
    static func merge(_ a: FELPerformanceTier, _ b: FELPerformanceTier) -> FELPerformanceTier {
        FELPerformanceTier(rawValue: max(a.rawValue, b.rawValue)) ?? .lowPower
    }
}

@objc public final class FELPerformanceMonitor: NSObject {
    @objc public static let shared = FELPerformanceMonitor()

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0

    @objc public private(set) var currentFPS: Double = 60.0
    @objc public private(set) var frameDrops: Int = 0
    @objc public private(set) var memoryUsageBytes: UInt64 = 0
    @objc public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @objc public private(set) var currentTier: FELPerformanceTier = .high

    /// C++ engine metrics (polled via NexusGameplayBridge).
    @objc public private(set) var engineFPS: Double = 60.0
    @objc public private(set) var engineFrameTimeMs: Double = 16.67
    @objc public private(set) var engineSuggestedTier: FELPerformanceTier = .high
    @objc public private(set) var physicsSubstepFactor: Double = 1.0
    @objc public private(set) var collisionCheckFactor: Double = 1.0

    public var onTierChanged: ((FELPerformanceTier) -> Void)?

    private override init() {
        super.init()
        setupThermalObserver()
    }

    @objc public func start() {
        stop()
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
        lastTimestamp = 0
        frameCount = 0
        frameDrops = 0
    }

    @objc public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        nexus_perf_clear_platform_tier()
    }

    @objc private func tick(_ link: CADisplayLink) {
        frameCount += 1
        let currentTimestamp = link.timestamp
        if lastTimestamp == 0 {
            lastTimestamp = currentTimestamp
            return
        }

        let elapsed = currentTimestamp - lastTimestamp
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed

            let targetFPS = Double(FELViewportRefreshPolicy.sceneKitTargetFPS(for: currentTier))
            let expectedFrames = targetFPS * elapsed
            frameDrops = max(0, Int(expectedFrames) - frameCount)

            frameCount = 0
            lastTimestamp = currentTimestamp

            updateMemoryUsage()
            syncEngineMetrics()
            evaluatePerformanceTier()
        }
    }

    private func updateMemoryUsage() {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            memoryUsageBytes = taskInfo.resident_size
        }
    }

    private func setupThermalObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        thermalState = ProcessInfo.processInfo.thermalState
    }

    @objc private func thermalStateChanged() {
        thermalState = ProcessInfo.processInfo.thermalState
        evaluatePerformanceTier()
    }

    /// Pull C++ PerfMonitor state (bidirectional: engine → iOS).
    private func syncEngineMetrics() {
        engineFPS = Double(nexus_perf_get_fps())
        engineFrameTimeMs = Double(nexus_perf_get_frame_time_ms())
        physicsSubstepFactor = Double(nexus_perf_get_physics_substep_factor())
        collisionCheckFactor = Double(nexus_perf_get_collision_check_factor())

        if let suggested = FELPerformanceTier(rawValue: Int(nexus_perf_get_engine_suggested_tier())) {
            engineSuggestedTier = suggested
        }
    }

    /// Compute iOS-side tier, merge with engine suggestion (worst wins), push to C++.
    public func evaluatePerformanceTier() {
        let previousTier = currentTier

        let iosTier: FELPerformanceTier
        if ProcessInfo.processInfo.isLowPowerModeEnabled || thermalState == .critical || thermalState == .serious {
            iosTier = .lowPower
        } else if thermalState == .fair || currentFPS < 45.0 || frameDrops > 15 {
            iosTier = .balanced
        } else if engineFrameTimeMs > 33.0 || engineFPS < 30.0 {
            iosTier = .lowPower
        } else if engineFrameTimeMs > 18.0 || engineFPS < 50.0 {
            iosTier = .balanced
        } else {
            iosTier = .high
        }

        let merged = FELPerformanceTier.merge(iosTier, engineSuggestedTier)
        currentTier = merged

        nexus_perf_set_tier(Int32(merged.rawValue))

        if currentTier != previousTier {
            onTierChanged?(currentTier)
            NotificationCenter.default.post(
                name: NSNotification.Name("FELPerformanceTierChanged"),
                object: nil,
                userInfo: ["tier": currentTier.rawValue]
            )
        }
    }
}
