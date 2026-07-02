import Foundation
import SwiftUI

@MainActor
enum FELNativeSwiftBridge {
    /// Launches the standalone Unreal iOS app (if installed) via URL scheme.
    ///
    /// This is the "two-app" integration path: SwiftUI stays responsive (Scan/NASM-CNC/etc),
    /// then hands off to UE for the high-fidelity viewport.
    static func makeUnrealLaunchURL(modeId: String, creatorId: String? = nil) -> URL? {
        var comps = URLComponents()
        comps.scheme = "finalevolution"
        comps.host = "launch"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "mode", value: modeId),
        ]
        if let creatorId, !creatorId.isEmpty {
            // UE side should map this to the travel option CreatorId=...
            items.append(URLQueryItem(name: "creator", value: creatorId))
        }
        comps.queryItems = items
        return comps.url
    }
}

