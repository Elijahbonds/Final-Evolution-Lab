import SwiftUI
import UIKit

/// App delegate whose only job is dynamic orientation control. The app defaults
/// to its Info.plist orientations; gameplay screens opt into a landscape lock
/// via `.felLandscapeLocked()`.
final class FELAppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .allButUpsideDown

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }
}

@MainActor
enum OrientationLock {
    static func lock(_ mask: UIInterfaceOrientationMask) {
        FELAppDelegate.orientationMask = mask

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

/// Forces landscape while the view is on screen (emulator-style gameplay),
/// restoring free rotation when it leaves.
struct FELLandscapeLockModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { OrientationLock.lock(.landscape) }
            .onDisappear { OrientationLock.lock(.allButUpsideDown) }
    }
}

extension View {
    func felLandscapeLocked() -> some View {
        modifier(FELLandscapeLockModifier())
    }
}
