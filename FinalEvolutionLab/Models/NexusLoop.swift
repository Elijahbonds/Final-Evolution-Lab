import Foundation
import QuartzCore
import OSLog

// MARK: - NexusLoop

/// CADisplayLink-driven game loop for the Nexus engine.
///
/// Provides a 60/120 Hz tick source that feeds delta time to scene physics,
/// animation interpolators, and any registered tick handlers. Prefer using
/// SwiftUI's `TimelineView(.animation)` for pure rendering; use NexusLoop when
/// you need a stable, off-render-thread physics integration step.
@Observable
@MainActor
final class NexusLoop {

    static let shared = NexusLoop()

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab",
        category: "NexusLoop"
    )

    // MARK: - Public state

    private(set) var isRunning: Bool = false
    private(set) var tick: UInt64 = 0
    private(set) var deltaTime: Double = 0.016_667
    private(set) var elapsedTime: Double = 0

    // MARK: - Tick handlers

    typealias TickHandler = @MainActor (Double) -> Void
    private var handlers: [String: TickHandler] = [:]

    // MARK: - Private

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    private init() {}

    // MARK: - Control

    func start() {
        guard !isRunning else { return }
        let link = CADisplayLink(target: DisplayLinkProxy(owner: self), selector: #selector(DisplayLinkProxy.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
        isRunning = true
        Self.log.info("NexusLoop started.")
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
        lastTimestamp = 0
        Self.log.info("NexusLoop stopped after \(self.tick) ticks, \(String(format: "%.1f", self.elapsedTime))s.")
    }

    func reset() {
        stop()
        tick = 0
        elapsedTime = 0
        deltaTime = 0.016_667
    }

    // MARK: - Handler registration

    /// Registers a named tick handler. Replaces any existing handler with the same id.
    func addHandler(id: String, _ handler: @escaping TickHandler) {
        handlers[id] = handler
    }

    func removeHandler(id: String) {
        handlers.removeValue(forKey: id)
    }

    func removeAllHandlers() {
        handlers.removeAll()
    }

    // MARK: - Tick (called by DisplayLinkProxy on main thread)

    fileprivate func processTick(_ link: CADisplayLink) {
        let now = link.timestamp
        if lastTimestamp == 0 {
            lastTimestamp = now
        }
        let dt = min(now - lastTimestamp, 0.1) // clamp to 100 ms to prevent spiral-of-death
        lastTimestamp = now

        deltaTime = dt
        elapsedTime += dt
        tick &+= 1

        for handler in handlers.values {
            handler(dt)
        }
    }
}

// MARK: - DisplayLinkProxy (breaks ARC cycle)

private final class DisplayLinkProxy: NSObject {
    weak var owner: NexusLoop?

    init(owner: NexusLoop) {
        self.owner = owner
    }

    @objc func tick(_ link: CADisplayLink) {
        Task { @MainActor [weak self] in
            self?.owner?.processTick(link)
        }
    }
}
