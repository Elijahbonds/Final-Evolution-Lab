// Copyright (c) Final Evolution Lab.
// Lightweight camera preview (no recording) — feeds `sampleBuffer` into `FELLuminanceAnalyzer` for Arena forensic gating.

import AVFoundation
import Combine
import CoreMedia
import Foundation

final class FELArenaAmbientLuminanceMonitor: NSObject, ObservableObject {
    /// Latest frame mean (0…1); `nil` until first buffer arrives.
    @Published var lastNormalizedBrightness: Float?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.finalevolution.fel.luminance", qos: .userInitiated)
    private var isConfigured = false

    func start() {
        Task { @MainActor in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                break
            case .notDetermined:
                guard await AVCaptureDevice.requestAccess(for: .video) else { return }
            default:
                return
            }
            self.queue.async {
                guard !self.session.isRunning else { return }
                self.configureSessionIfNeeded()
                self.session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    nonisolated func captureOutput(
        _ output: AVCaptureVideoDataOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // `setSampleBufferDelegate(_:queue:)` uses `queue`; keep luma math off the main thread.
        let v = FELLuminanceAnalyzer.averageBrightness(from: sampleBuffer)
        DispatchQueue.main.async { [weak self] in
            self?.lastNormalizedBrightness = v
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        session.beginConfiguration()
        session.sessionPreset = .medium
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            return
        }
        session.addInput(input)

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
    }
}

extension FELArenaAmbientLuminanceMonitor: AVCaptureVideoDataOutputSampleBufferDelegate {}
