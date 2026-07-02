import Foundation

/// PREVIEW stub — sandbox save hook for future CMake / `nexus_build_gate` regen (see `docs/NEXUS_STUDIO_IDE.md`).
enum NexusStudioHotReloadStub {
    static func notifySandboxSave(relativePath: String) {
        NotificationCenter.default.post(
            name: .nexusStudioSandboxSaved,
            object: nil,
            userInfo: ["relative_path": relativePath]
        )
    }

    /// Returns a human-readable status line for the Run panel / IDE footer (no engine side-effects yet).
    static func statusLine(for relativePath: String) -> String {
        "Hot-reload stub: queued \(relativePath) — regen not wired (PREVIEW)"
    }
}
