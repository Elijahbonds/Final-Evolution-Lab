import UIKit

/// Centralized haptic feedback for arena gameplay (UIImpactFeedbackGenerator tier).
@MainActor
enum FELHaptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    static func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notification.prepare()
        selection.prepare()
    }

    static func modeSelect() {
        selection.selectionChanged()
    }

    static func dunkApex(isCritical: Bool) {
        if isCritical {
            heavy.impactOccurred(intensity: 1.0)
        } else {
            medium.impactOccurred(intensity: 0.85)
        }
    }

    static func dunkChargeRelease() {
        light.impactOccurred(intensity: 0.6)
    }

    static func actionSuccess(isCritical: Bool) {
        if isCritical {
            heavy.impactOccurred()
        } else {
            medium.impactOccurred()
        }
    }

    static func actionFail() {
        notification.notificationOccurred(.error)
    }

    static func sessionEnd(won: Bool, isDraw: Bool = false) {
        if isDraw {
            notification.notificationOccurred(.warning)
        } else if won {
            notification.notificationOccurred(.success)
            heavy.impactOccurred(intensity: 0.7)
        } else {
            notification.notificationOccurred(.error)
            medium.impactOccurred(intensity: 0.5)
        }
    }
}
