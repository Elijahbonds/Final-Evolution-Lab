import Foundation
import GameController
import Observation

// MARK: - Controller discovery for emulator-style input handoff
// DualShock 5, Xbox, MFi: when any hardware controller is connected,
// games can hide the on-screen virtual controller and use physical input only.

@Observable
@MainActor
final class ControllerDiscoveryService {
    static let shared = ControllerDiscoveryService()

    private(set) var hasPhysicalController: Bool = false
    private(set) var controllerName: String?

    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?

    private init() {
        updateFromControllers()
    }

    func startObserving() {
        guard connectObserver == nil else { return }
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            ControllerDiscoveryService.handleControllerEvent(self)
        }
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            ControllerDiscoveryService.handleControllerEvent(self)
        }
        updateFromControllers()
    }

    func stopObserving() {
        if let o = connectObserver {
            NotificationCenter.default.removeObserver(o)
            connectObserver = nil
        }
        if let o = disconnectObserver {
            NotificationCenter.default.removeObserver(o)
            disconnectObserver = nil
        }
    }

    private func updateFromControllers() {
        let controllers = GCController.controllers()
        hasPhysicalController = !controllers.isEmpty
        controllerName = controllers.first.flatMap { name(for: $0) }
    }

    private func name(for controller: GCController) -> String? {
        if let name = controller.vendorName, !name.isEmpty { return name }
        let cat = controller.productCategory
        if cat.contains("DualSense") || cat.contains("Dual Shock") { return "DualSense" }
        if cat.contains("Xbox") { return "Xbox" }
        if cat.contains("MFi") { return "MFi Controller" }
        return cat.isEmpty ? "Controller" : cat
    }
    
    nonisolated private static func handleControllerEvent(_ instance: ControllerDiscoveryService?) {
        guard let instance else { return }
        Task { @MainActor in
            instance.updateFromControllers()
        }
    }
}
