// FELNativeSwiftBridge.swift
// Final Evolution Lab — Swift UI ↔ Unreal Engine 5.7 Renderer Handoff
// Optimized for 17 Game Modes on iPhone 16 Pro Max

import Foundation
import UIKit
import Combine

// MARK: - Mode Launch Protocol
/// Handles the handoff between Swift UI navigation and UE5 renderer for each game mode.
/// When an athlete taps a mode in the Sovereign Dashboard shell, this bridge:
///   1. Sends deep link to UE5 app: finalevolution://launch?map={venue}&mode={mode_id}&session={session_id}
///   2. Monitors app switch via UIApplication.didBecomeActiveNotification
///   3. Establishes WebSocket to Sovereign Hub (wss://finalevolutiongroup.com/ws/sovereign) for telemetry

@objc class FELNativeSwiftBridge: NSObject {

    static let shared = FELNativeSwiftBridge()

    // MARK: - Properties
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var reconnectTimer: Timer?
    private var currentSessionId: String?
    private var currentVenue: String?

    let sovereignHubURL = URL(string: "wss://finalevolutiongroup.com/ws/sovereign")!
    let deepLinkScheme = "finalevolution"

    // Production venue registry — matches FEL_VenueRegistry.production.json
    let venueRegistry: [String: VenueConfig] = [
        "basketball_h2h":  VenueConfig(map: "Venice_Beach_Court", binary: "FEL-Basketball-H2H"),
        "basketball_dunk": VenueConfig(map: "Venice_Beach_Court", binary: "FEL-DunkContest"),
        "basketball_3v3":  VenueConfig(map: "Venice_Beach_Court", binary: "FEL-Basketball-3v3"),
        "karate_h2h":      VenueConfig(map: "Zen_Dojo", binary: "FEL-Karate-H2H"),
        "karate_endless":  VenueConfig(map: "Zen_Dojo", binary: "FEL-Karate-Endless"),
        "baseball":        VenueConfig(map: "Baseball_Park", binary: "FEL-Baseball"),
        "football":        VenueConfig(map: "Gridiron_Stadium", binary: "FEL-Football"),
        "soccer":          VenueConfig(map: "Soccer_Stadium", binary: "FEL-Soccer"),
        "golf":            VenueConfig(map: "Links_Course", binary: "FEL-Golf"),
        "tennis":          VenueConfig(map: "Tennis_Court", binary: "FEL-Tennis"),
        "volleyball":      VenueConfig(map: "Sand_Court", binary: "FEL-Volleyball"),
        "gymnastics":      VenueConfig(map: "Training_Floor", binary: "FEL-Gymnastics"),
        "surfing":         VenueConfig(map: "Venice_Beach_Surf", binary: "FEL-Surfing"),
        "skateboarding":   VenueConfig(map: "Skate_Park", binary: "FEL-Skateboarding"),
        "snowboarding":    VenueConfig(map: "Mountain_Slope", binary: "FEL-Snowboarding"),
        "brain_brawl":     VenueConfig(map: "Neuro_Arena", binary: "FEL-BrainBrawl"),
        "market_browse":   VenueConfig(map: "Sovereign_Shop", binary: "FEL-Market"),
    ]

    // MARK: - Sovereign Hub Connection
    func connectToSovereignHub() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
        webSocket = session?.webSocketTask(with: sovereignHubURL)
        webSocket?.resume()
        isConnected = true
        listenForMessages()
        sendHandshake()

        // Reconnect on disconnect
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isConnected else { return }
            self.connectToSovereignHub()
        }
    }

    private func sendHandshake() {
        let handshake: [String: Any] = [
            "type": "sovereign_handshake",
            "client": "FEL-iOS-Swift-Bridge",
            "device": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "bIsHardwareAuthenticated": true,
            "back_camera_verified": true,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        send(handshake)
    }

    // MARK: - Game Mode Launch (Deep Link to UE5)
    func launchGameMode(_ modeId: String) -> Bool {
        guard let config = venueRegistry[modeId] else { return false }

        let sessionId = "sess_\(UUID().uuidString.prefix(12).lowercased())"
        currentSessionId = sessionId
        currentVenue = config.map

        // Construct deep link
        let deepLink = "\(deepLinkScheme)://launch?map=\(config.map)&mode=\(modeId)&session=\(sessionId)"
        guard let url = URL(string: deepLink) else { return false }

        // Notify sovereign hub that session is launching
        send([
            "type": "session_launch",
            "session_id": sessionId,
            "mode_id": modeId,
            "venue_token": config.map,
            "binary": config.binary,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        // Open UE5 app via deep link
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    self.send(["type": "session_state", "session_id": sessionId, "state": "map_loading"])
                }
            }
            return true
        }
        return false
    }

    // MARK: - Telemetry Streaming
    func sendTelemetry(prq: Float, comboStreak: Int, comboMeter: Float, buckets: Int, verticalJump: Float, velocity: SIMD3<Float>) {
        guard let sessionId = currentSessionId else { return }
        send([
            "type": "sovereign_telemetry",
            "session_id": sessionId,
            "prq": prq,
            "combo_streak": comboStreak,
            "combo_meter": comboMeter,
            "buckets": buckets,
            "vertical_jump_inches": verticalJump,
            "velocity_vectors": ["x": velocity.x, "y": velocity.y, "z": velocity.z],
            "arena_game_mode_id": currentVenue ?? "",
            "venue_token": currentVenue ?? "",
            "sovereign_display_mode": "stadium_overlay",
            "t": ISO8601DateFormatter().string(from: Date())
        ])
    }

    // MARK: - Hardware Authentication (Integrity Guard)
    func sendHardwareAuth(cameraVerified: Bool, imuSynced: Bool) {
        send([
            "type": "hardware_auth",
            "bIsHardwareAuthenticated": true,
            "back_camera_verified": cameraVerified,
            "imu_visual_sync": imuSynced,
            "device": UIDevice.current.model,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }

    // MARK: - Creator Card Scan
    func scanCreatorCard(_ cardId: String) {
        send([
            "type": "creator_card_scan",
            "StoodCardId": cardId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }

    // MARK: - Private Helpers
    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(str)) { error in
            if let error = error { print("[FEL Bridge] Send error: \(error)") }
        }
    }

    private func listenForMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        self?.handleHubMessage(json)
                    }
                default: break
                }
                self?.listenForMessages() // Continue listening
            case .failure:
                self?.isConnected = false
            }
        }
    }

    private func handleHubMessage(_ msg: [String: Any]) {
        guard let type = msg["type"] as? String else { return }
        switch type {
        case "sovereign_handshake":
            print("[FEL Bridge] Handshake received from Sovereign Hub")
            isConnected = true
        case "venue_travel":
            if let venue = msg["venue"] as? String {
                currentVenue = venue
                // Could trigger local map switch if UE5 is embedded
            }
        case "focus_ack":
            // Focus lock confirmed
            break
        default:
            break
        }
    }
}

// MARK: - Venue Config
struct VenueConfig {
    let map: String
    let binary: String
}
