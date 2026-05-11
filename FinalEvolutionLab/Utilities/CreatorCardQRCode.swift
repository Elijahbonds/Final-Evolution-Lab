import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Renders a QR bitmap for creator card deep links (HTTPS for universal camera scanners).
enum CreatorCardQRImage {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    nonisolated static func uiImage(payload: String, dimension: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = dimension / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct CreatorCardQRThumbnail: View {
    let payload: String
    var dimension: CGFloat = 52

    var body: some View {
        Group {
            if let ui = CreatorCardQRImage.uiImage(payload: payload, dimension: dimension * UIScreen.main.scale) {
                Image(uiImage: ui)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: dimension, height: dimension)
            }
        }
    }
}
