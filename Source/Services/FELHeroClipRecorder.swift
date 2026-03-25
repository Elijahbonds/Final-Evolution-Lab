import Foundation
import Photos
import ReplayKit
import UIKit

/// ReplayKit capture for Bonds Apex hero moments (Unreal viewport + Sonic Flare); saves to Photos.
enum FELHeroClipRecorder {
    static let captureDuration: TimeInterval = 3.5

    @MainActor
    static func startBuffering() {
        if #available(iOS 15.0, *) {
            let recorder = RPScreenRecorder.shared()
            guard recorder.isAvailable, !recorder.isRecording else { return }
            recorder.startClipBuffering { error in
                if let error {
                    print("FELHeroClipRecorder: Failed to start buffering - \(error.localizedDescription)")
                }
            }
        }
    }

    @MainActor
    static func stopBuffering() {
        if #available(iOS 15.0, *) {
            let recorder = RPScreenRecorder.shared()
            if recorder.isRecording {
                recorder.stopClipBuffering { _ in }
            }
        }
    }

    @MainActor
    static func recordAndSaveToPhotos(completion: @escaping (Result<Void, Error>) -> Void) {
        if #available(iOS 15.0, *) {
            let recorder = RPScreenRecorder.shared()
            guard recorder.isAvailable else {
                completion(.failure(NSError(domain: "FELHeroClip", code: 1, userInfo: [NSLocalizedDescriptionKey: "Screen recording not available."])))
                return
            }

            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("fel_hero_\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: outputURL)

            // If we are already buffering, instantly export the last few seconds (zero lag!)
            if recorder.isRecording {
                recorder.exportClip(to: outputURL, duration: captureDuration) { error in
                    if let error {
                        DispatchQueue.main.async { completion(.failure(error)) }
                        return
                    }
                    saveVideoToPhotos(url: outputURL, completion: completion)
                }
            } else {
                // Fallback: start buffering now, wait, then export
                recorder.startClipBuffering { error in
                    if let error {
                        DispatchQueue.main.async { completion(.failure(error)) }
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + captureDuration) {
                        recorder.exportClip(to: outputURL, duration: captureDuration) { exportError in
                            if let exportError {
                                DispatchQueue.main.async { completion(.failure(exportError)) }
                                return
                            }
                            saveVideoToPhotos(url: outputURL, completion: completion)
                        }
                    }
                }
            }
        } else {
            completion(.failure(NSError(domain: "FELHeroClip", code: 2, userInfo: [NSLocalizedDescriptionKey: "Hero Clip export requires iOS 15 or later."])))
        }
    }

    private static func saveVideoToPhotos(url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "FELHeroClip", code: 3, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied."])))
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }, completionHandler: { success, saveError in
                DispatchQueue.main.async {
                    if let saveError {
                        completion(.failure(saveError))
                        return
                    }
                    if success {
                        try? FileManager.default.removeItem(at: url)
                        completion(.success(()))
                    } else {
                        completion(.failure(NSError(domain: "FELHeroClip", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to save hero clip."])))
                    }
                }
            })
        }
    }
}
