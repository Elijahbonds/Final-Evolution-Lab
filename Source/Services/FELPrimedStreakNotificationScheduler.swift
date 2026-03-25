import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// “Ready for Game Day?” — if PRQ stays **> 85** on **three consecutive calendar days** (tracked per day), fire a high-priority local notification.
@MainActor
final class FELPrimedStreakNotificationScheduler {
    static let shared = FELPrimedStreakNotificationScheduler()

    private let streakDaysKey = "felPrimedStreakDayStarts"
    private let lastPrimedPushKey = "felLastPrimedGameDayNotification"

    private init() {}

    func registerForNotificationsIfNeeded() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        #endif
    }

    /// Call when app becomes active or after a PRQ sync (e.g. Lab tab).
    func recordSession(prq: Int) {
        guard prq > 85 else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let y1 = cal.date(byAdding: .day, value: -1, to: today),
              let y2 = cal.date(byAdding: .day, value: -2, to: today) else { return }

        var set = Set((UserDefaults.standard.array(forKey: streakDaysKey) as? [TimeInterval]) ?? [])
        set.insert(today.timeIntervalSince1970)
        UserDefaults.standard.set(Array(set), forKey: streakDaysKey)

        let t0 = today.timeIntervalSince1970
        let t1 = cal.startOfDay(for: y1).timeIntervalSince1970
        let t2 = cal.startOfDay(for: y2).timeIntervalSince1970
        if set.contains(t0), set.contains(t1), set.contains(t2) {
            schedulePrimedGameDayNotificationIfEligible()
        }
    }

    private func schedulePrimedGameDayNotificationIfEligible() {
        #if canImport(UserNotifications)
        let last = UserDefaults.standard.double(forKey: lastPrimedPushKey)
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600).timeIntervalSince1970
        if last > weekAgo { return }

        let content = UNMutableNotificationContent()
        content.title = "Ready for Game Day?"
        content.body = "You’ve been PRIMED (PRQ > 85) for three straight days. Hit the 3D Arena for a new personal best."
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let req = UNNotificationRequest(identifier: "fel.primed.game.day", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { _ in }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastPrimedPushKey)
        #endif
    }
}
