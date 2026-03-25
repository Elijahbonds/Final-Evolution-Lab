import UIKit

    /// Physical-device launch path: cold-start **Recovery Scan** before the SwiftUI root renders the Dashboard.
@MainActor
final class FELAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in
            FELUnrealSessionImporter.shared.performLaunchRecoveryScan()
            FELPrimedStreakNotificationScheduler.shared.registerForNotificationsIfNeeded()
        }
        return true
    }
}
