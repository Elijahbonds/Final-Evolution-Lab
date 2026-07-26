import Foundation
import SwiftUI

/// Cross-surface launch context for NEXUS Studio (Dashboard, Game Generator, Agent).
@MainActor
@Observable
final class NexusStudioCoordinator {
    static let shared = NexusStudioCoordinator()

    private(set) var pendingLaunch: NexusStudioLaunchContext?

    private init() {}

    func open(panel: NexusStudioPanel = .editor, sandboxRelativePath: String? = nil) {
        pendingLaunch = NexusStudioLaunchContext(panel: panel, sandboxRelativePath: sandboxRelativePath)
        postOpenNotification()
    }

    func openEditor(relativePath: String? = nil) {
        open(panel: .editor, sandboxRelativePath: relativePath)
    }

    func openAIStudioSettings() {
        open(panel: .aiStudio)
    }

    func openRunPanel(
        modeId: GameModeId?,
        readiness: Double = 75,
        sandboxRelativePath: String? = nil
    ) {
        pendingLaunch = NexusStudioLaunchContext(
            panel: .run,
            modeId: modeId,
            readiness: readiness,
            sandboxRelativePath: sandboxRelativePath
        )
        postOpenNotification()
    }

    func consumePendingLaunch() -> NexusStudioLaunchContext? {
        defer { pendingLaunch = nil }
        return pendingLaunch
    }

    private func postOpenNotification() {
        NotificationCenter.default.post(name: .nexusStudioOpen, object: nil)
    }
}
