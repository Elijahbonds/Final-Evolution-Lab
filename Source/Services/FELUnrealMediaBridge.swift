import Foundation
import Photos
import UIKit

/// Receives Unreal → iOS notifications: avatar PNG snapshot + Neuro-Flow `.mp4` export path.
/// Uses `NSObject` selectors so `Notification` is not captured in Swift 6 `@Sendable` notification blocks.
@MainActor
final class FELUnrealMediaBridge {
    static let shared = FELUnrealMediaBridge()

    private var sink: NotificationSink?
    private init() {}

    deinit {
        if let sink {
            NotificationCenter.default.removeObserver(sink)
        }
    }

    func register() {
        guard sink == nil else { return }
        let s = NotificationSink()
        s.bridge = self
        NotificationCenter.default.addObserver(
            s,
            selector: #selector(NotificationSink.onLevelLoading(_:)),
            name: NSNotification.Name("felUnrealLevelLoading"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            s,
            selector: #selector(NotificationSink.onAvatarSnapshot(_:)),
            name: .felAvatarSnapshotPngReady,
            object: nil
        )
        NotificationCenter.default.addObserver(
            s,
            selector: #selector(NotificationSink.onNeuroFlowMp4(_:)),
            name: .felNeuroFlowMp4ExportReady,
            object: nil
        )
        sink = s
    }

    fileprivate func handleAvatarPng(pngData: Data?) {
        guard let data = pngData, !data.isEmpty else { return }
        autoreleasepool {
            if let img = UIImage(data: data) {
                _ = img
            }
        }
    }

    fileprivate func handleNeuroFlowMp4(path: String?) {
        guard let path, !path.isEmpty else { return }
        let src = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: src.path) else { return }

        let fileName = "FinalEvolution_#FinalEvolution_\(UUID().uuidString).mp4"
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: src, to: dest)
        } catch {
            return
        }

        let destURL = dest
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            Task { @MainActor in
                guard status == .authorized || status == .limited else { return }
                FELUnrealMediaBridge.shared.performPhotoLibrarySave(destURL: destURL)
            }
        }
    }

    private func performPhotoLibrarySave(destURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destURL)
        }, completionHandler: { success, _ in
            Task { @MainActor in
                if success {
                    try? FileManager.default.removeItem(at: destURL)
                }
            }
        })
    }
}

// MARK: - Selector-based observer (avoids @Sendable + Notification)

private final class NotificationSink: NSObject {
    @MainActor weak var bridge: FELUnrealMediaBridge?

    @objc func onLevelLoading(_ notification: Notification) {
        Task { @MainActor in
            UFELUnrealOverlayRuntime.shared.setUnrealReady(true)
        }
    }

    @objc func onAvatarSnapshot(_ notification: Notification) {
        let pngData = notification.userInfo?["pngData"] as? Data
        Task { @MainActor [weak self] in
            guard let self, let bridge = self.bridge else { return }
            bridge.handleAvatarPng(pngData: pngData)
        }
    }

    @objc func onNeuroFlowMp4(_ notification: Notification) {
        let mp4Path = notification.userInfo?["mp4Path"] as? String
        Task { @MainActor [weak self] in
            guard let self, let bridge = self.bridge else { return }
            bridge.handleNeuroFlowMp4(path: mp4Path)
        }
    }
}
