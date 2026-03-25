// Copyright (c) Final Evolution Lab.
// Ambient luminance from one camera frame (Y-plane average, normalized 0…1) for Neuro-Mechanic forensic gating.

import AVFoundation
import CoreMedia
import Foundation

/// Measures average brightness from a single `CMSampleBuffer` (video) for low-light gating.
/// Pixel-buffer work is `nonisolated` so `AVCaptureVideoDataOutput` can invoke it on the session’s serial queue; publish on main in the monitor.
enum FELLuminanceAnalyzer: Sendable {
    /// Normalized luma mean from Y plane (420) or luminance from BGRA; returns 0.5 if unreadable.
    nonisolated static func averageBrightness(from sampleBuffer: CMSampleBuffer) -> Float {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return 0.5
        }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let format = CVPixelBufferGetPixelFormatType(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        if width < 2 || height < 2 {
            return 0.5
        }

        if format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        {
            guard let baseY = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else {
                return 0.5
            }
            let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
            let base = baseY.assumingMemoryBound(to: UInt8.self)
            var sum: Double = 0
            var count = 0
            let stepY = max(1, height / 48)
            let stepX = max(1, width / 48)
            for y in stride(from: 0, to: height, by: stepY) {
                for x in stride(from: 0, to: width, by: stepX) {
                    sum += Double(base[y * rowBytes + x]) / 255.0
                    count += 1
                }
            }
            return count > 0 ? Float(sum / Double(count)) : 0.5
        }

        if let base = CVPixelBufferGetBaseAddress(imageBuffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            let b = base.assumingMemoryBound(to: UInt8.self)
            var sum: Double = 0
            var count = 0
            let bpp = 4
            let stepY = max(1, height / 32)
            let stepX = max(1, width / 32)
            for y in stride(from: 0, to: height, by: stepY) {
                for x in stride(from: 0, to: width, by: stepX) {
                    let o = y * bytesPerRow + x * bpp
                    let r = Double(b[o])
                    let g = Double(b[o + 1])
                    let bl = Double(b[o + 2])
                    sum += (0.2126 * r + 0.7152 * g + 0.0722 * bl) / 255.0
                    count += 1
                }
            }
            return count > 0 ? Float(sum / Double(count)) : 0.5
        }

        return 0.5
    }
}
