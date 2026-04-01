// Config.swift - Final Evolution Lab Configuration
// Streaming and API configuration for production deployment

import Foundation

enum Config {
    // ── Streaming Server ────────────────────────────────────────────
    /// Production Pixel Streaming signalling server URL (WebSocket)
    static let STREAMING_SERVER_URL = "wss://stream.finalevolutiongroup.com"
    
    /// HTTP API base URL for the signalling server
    static let STREAMING_API_URL = "https://stream.finalevolutiongroup.com"
    
    /// TURN/STUN server for WebRTC NAT traversal
    static let TURN_SERVER_URL = "turn:turn.finalevolutiongroup.com:3478"
    static let TURN_USERNAME = "fel"
    static let TURN_CREDENTIAL = "felpass"
    static let STUN_SERVER_URL = "stun:stun.finalevolutiongroup.com:3478"
    
    // ── Main Website ────────────────────────────────────────────────
    static let WEBSITE_URL = "https://finalevolutiongroup.com"
    static let WEB_APP_URL = "https://app.finalevolutiongroup.com"
    
    // ── Legacy / Rork Platform ──────────────────────────────────────
    static let EXPO_PUBLIC_PROJECT_ID = ""
    static let EXPO_PUBLIC_RORK_API_BASE_URL = ""
    static let EXPO_PUBLIC_RORK_AUTH_URL = ""
    static let EXPO_PUBLIC_TEAM_ID = ""
    static let EXPO_PUBLIC_TOOLKIT_URL = ""
    
    // ── App Info ────────────────────────────────────────────────────
    static let APP_BUNDLE_ID = "com.finalevolutiongroup.lab"
    static let APP_VERSION = "1.0.0"
    static let APP_BUILD = "1"
    
    // ── Feature Flags ───────────────────────────────────────────────
    static let ENABLE_PIXEL_STREAMING = true
    static let ENABLE_EXERCISE_DEMOS = true
    static let ENABLE_MULTIPLAYER = true
    static let ENABLE_ANALYTICS = true
    
    static let allValues: [String: String] = [
        "STREAMING_SERVER_URL": STREAMING_SERVER_URL,
        "STREAMING_API_URL": STREAMING_API_URL,
        "WEBSITE_URL": WEBSITE_URL,
        "WEB_APP_URL": WEB_APP_URL,
        "APP_BUNDLE_ID": APP_BUNDLE_ID,
        "EXPO_PUBLIC_PROJECT_ID": EXPO_PUBLIC_PROJECT_ID,
        "EXPO_PUBLIC_RORK_API_BASE_URL": EXPO_PUBLIC_RORK_API_BASE_URL,
        "EXPO_PUBLIC_RORK_AUTH_URL": EXPO_PUBLIC_RORK_AUTH_URL,
        "EXPO_PUBLIC_TEAM_ID": EXPO_PUBLIC_TEAM_ID,
        "EXPO_PUBLIC_TOOLKIT_URL": EXPO_PUBLIC_TOOLKIT_URL,
    ]
}
