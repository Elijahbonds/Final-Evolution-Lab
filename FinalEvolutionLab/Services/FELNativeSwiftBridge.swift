import Foundation
import SwiftUI

@MainActor
enum FELNativeSwiftBridge {
    /// Venue tokens aligned with ``backend/FEL_ModeManager.production.json`` map registry (Emergent / UE deep link).
    private static let modeToVenueToken: [String: String] = [
        "basketball_h2h": "Venice_Beach_Court",
        "basketball_dunk": "Venice_Beach_Court",
        "basketball_3v3": "Venice_Beach_Court",
        "karate_h2h": "Zen_Dojo",
        "karate_endless": "Zen_Dojo",
        "baseball": "Baseball_Park",
        "football": "Gridiron_Stadium",
        "soccer": "Soccer_Stadium",
        "golf": "Links_Course",
        "tennis": "Tennis_Court",
        "volleyball": "Sand_Court",
        "gymnastics": "Training_Floor",
        "surfing": "Venice_Beach_Surf",
        "skateboarding": "Skate_Park",
        "snowboarding": "Mountain_Slope",
        "brain_brawl": "Neuro_Arena",
        // Matches ``backend/FEL_ModeManager.production.json`` / UE Emergent bridge venue tokens.
        "who_scene_it": "Neuro_Arena",
        "court_carnival": "Venice_Beach_Court",
    ]

    /// Builds an optional custom-scheme URL used only for **legacy / tooling** deep links into an external UE client.
    ///
    /// The shipped Super App hosts Unreal in-process with WKWebView overlays; inline gameplay routing should not depend on this helper.
    /// Shop / commerce flows belong to Swift routes — there is no ``market_browse`` venue mapping here.
    static func makeUnrealLaunchURL(modeId: String, creatorId: String? = nil) -> URL? {
        var comps = URLComponents()
        comps.scheme = "finalevolution"
        comps.host = "launch"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "mode", value: modeId),
        ]
        if let map = modeToVenueToken[modeId] {
            items.append(URLQueryItem(name: "map", value: map))
        }
        if let creatorId, !creatorId.isEmpty {
            // UE side should map this to the travel option CreatorId=...
            items.append(URLQueryItem(name: "creator", value: creatorId))
        }
        comps.queryItems = items
        return comps.url
    }
}

