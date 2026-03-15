import SwiftUI
import GameController

/// Console-first: physical controller support. When a game controller is connected, Cross (button A) fires the given action on main actor.
struct PhysicalControllerCrossModifier: ViewModifier {
    var onCross: () -> Void
    @State private var observer: NSObjectProtocol?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard observer == nil else { return }
                let action = onCross
                if let controller = GCController.controllers().first {
                    setupHandler(controller: controller, action: action)
                }
                observer = NotificationCenter.default.addObserver(
                    forName: .GCControllerDidConnect,
                    object: nil,
                    queue: .main
                ) { notification in
                    guard let controller = notification.object as? GCController else { return }
                    setupHandler(controller: controller, action: action)
                }
            }
            .onDisappear {
                if let o = observer {
                    NotificationCenter.default.removeObserver(o)
                    observer = nil
                }
            }
    }

    private func setupHandler(controller: GCController, action: @escaping () -> Void) {
        controller.handlerQueue = .main
        if let pad = controller.extendedGamepad {
            pad.buttonA.pressedChangedHandler = { _, _, pressed in
                if pressed { action() }
            }
        } else if let pad = controller.gamepad {
            pad.buttonA.pressedChangedHandler = { _, _, pressed in
                if pressed { action() }
            }
        }
    }
}

/// Physical controller Cross with down/up for charge-and-release (hold to charge, release to fire).
struct PhysicalControllerCrossDownUpModifier: ViewModifier {
    var onDown: () -> Void
    var onUp: () -> Void
    @State private var observer: NSObjectProtocol?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard observer == nil else { return }
                let down = onDown, up = onUp
                for controller in GCController.controllers() {
                    setupHandler(controller: controller, down: down, up: up)
                }
                observer = NotificationCenter.default.addObserver(
                    forName: .GCControllerDidConnect,
                    object: nil,
                    queue: .main
                ) { notification in
                    guard let controller = notification.object as? GCController else { return }
                    setupHandler(controller: controller, down: down, up: up)
                }
            }
            .onDisappear {
                if let o = observer {
                    NotificationCenter.default.removeObserver(o)
                    observer = nil
                }
            }
    }

    private func setupHandler(controller: GCController, down: @escaping () -> Void, up: @escaping () -> Void) {
        controller.handlerQueue = .main
        if let pad = controller.extendedGamepad {
            pad.buttonA.pressedChangedHandler = { _, _, pressed in
                if pressed { down() } else { up() }
            }
        } else if let pad = controller.gamepad {
            pad.buttonA.pressedChangedHandler = { _, _, pressed in
                if pressed { down() } else { up() }
            }
        }
    }
}

extension View {
    /// When a physical controller is connected, Cross (A) triggers the action. Use for Arena commit or dunk actions.
    func onPhysicalControllerCross(perform action: @escaping () -> Void) -> some View {
        modifier(PhysicalControllerCrossModifier(onCross: action))
    }

    /// Physical controller Cross down/up for charge: onDown when pressed, onUp when released.
    func onPhysicalControllerCross(down: @escaping () -> Void, up: @escaping () -> Void) -> some View {
        modifier(PhysicalControllerCrossDownUpModifier(onDown: down, onUp: up))
    }
}
