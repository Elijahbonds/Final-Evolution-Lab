import UIKit

// MARK: - Haptic seam
//
// Gameplay calls the same `FELHaptics.*` API it always has, but each call now
// forwards a semantic `HapticEvent` to a swappable sink. Production uses
// `LiveHapticSink` (UIFeedbackGenerator). The harness swaps in a recording sink
// so haptic cues land on the session timeline ("dunk apex haptic at t=3.2s")
// and tests can assert feedback fired without a physical device.

/// Semantic haptic cue — Codable so it serializes into recorded session logs.
nonisolated enum HapticEvent: String, Sendable, Codable, Equatable {
    case modeSelect
    case dunkApex
    case dunkApexCritical
    case dunkChargeRelease
    case actionSuccess
    case actionSuccessCritical
    case actionFail
    case sessionWin
    case sessionLoss
    case sessionDraw
}

@MainActor
protocol HapticSink: AnyObject {
    func emit(_ event: HapticEvent)
}

/// Production sink — real Taptic Engine feedback.
@MainActor
final class LiveHapticSink: HapticSink {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notification.prepare()
        selection.prepare()
    }

    func emit(_ event: HapticEvent) {
        switch event {
        case .modeSelect:
            selection.selectionChanged()
        case .dunkApex:
            medium.impactOccurred(intensity: 0.85)
        case .dunkApexCritical:
            heavy.impactOccurred(intensity: 1.0)
        case .dunkChargeRelease:
            light.impactOccurred(intensity: 0.6)
        case .actionSuccess:
            medium.impactOccurred()
        case .actionSuccessCritical:
            heavy.impactOccurred()
        case .actionFail:
            notification.notificationOccurred(.error)
        case .sessionWin:
            notification.notificationOccurred(.success)
            heavy.impactOccurred(intensity: 0.7)
        case .sessionLoss:
            notification.notificationOccurred(.error)
            medium.impactOccurred(intensity: 0.5)
        case .sessionDraw:
            notification.notificationOccurred(.warning)
        }
    }
}

/// Harness/test sink — records the ordered cue stream, fires nothing.
@MainActor
final class RecordingHapticSink: HapticSink {
    private(set) var events: [HapticEvent] = []
    func emit(_ event: HapticEvent) { events.append(event) }
    func reset() { events.removeAll() }
}

/// Centralized haptic feedback for arena gameplay. Public API unchanged; calls
/// route through a swappable ``HapticSink``.
@MainActor
enum FELHaptics {
    private static let liveSink = LiveHapticSink()
    private static var sink: HapticSink = liveSink

    /// Test/harness hook — route cues to a recorder or silence.
    static func setSink(_ newSink: HapticSink) { sink = newSink }
    static func resetSink() { sink = liveSink }

    static func prepare() { liveSink.prepare() }

    static func modeSelect() { sink.emit(.modeSelect) }

    static func dunkApex(isCritical: Bool) {
        sink.emit(isCritical ? .dunkApexCritical : .dunkApex)
    }

    static func dunkChargeRelease() { sink.emit(.dunkChargeRelease) }

    static func actionSuccess(isCritical: Bool) {
        sink.emit(isCritical ? .actionSuccessCritical : .actionSuccess)
    }

    static func actionFail() { sink.emit(.actionFail) }

    static func sessionEnd(won: Bool, isDraw: Bool = false) {
        if isDraw {
            sink.emit(.sessionDraw)
        } else if won {
            sink.emit(.sessionWin)
        } else {
            sink.emit(.sessionLoss)
        }
    }
}
