import QuartzCore
import UIKit

/// CADisplayLink gameplay tick — locked to ``FELViewportRefreshPolicy/gameplayTickHz`` (60 Hz).
/// Viewport render (MTKView / SCNView) may run at ProMotion; sim + C++ session stay at mobile target.
@MainActor
final class FELProMotionTicker {
    private var displayLink: CADisplayLink?
    private var callback: ((TimeInterval) -> Void)?

    deinit {
        displayLink?.invalidate()
        displayLink = nil
        callback = nil
    }

    func start(onTick: @escaping (TimeInterval) -> Void) {
        stop()
        callback = onTick

        let tickHz = FELViewportRefreshPolicy.gameplayTickHz
        let link = CADisplayLink(target: self, selector: #selector(handleTick(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(tickHz),
                maximum: Float(tickHz),
                preferred: Float(tickHz)
            )
        } else {
            link.preferredFramesPerSecond = tickHz
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        callback = nil
    }

    @objc private func handleTick(_ link: CADisplayLink) {
        let delta = link.targetTimestamp - link.timestamp
        let maxDelta = 1.0 / Double(FELViewportRefreshPolicy.gameplayTickHz)
        let clamped = delta > 0 ? min(delta, 1.0 / 30.0) : maxDelta
        callback?(clamped)
    }
}
