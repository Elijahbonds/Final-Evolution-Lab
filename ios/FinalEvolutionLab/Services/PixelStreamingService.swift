// Copyright (c) Final Evolution Lab.
// Pixel Streaming client for iOS app — connects to signalling server,
// establishes WebRTC stream, and provides data channel for mode control.

import Foundation
import Combine

/// Connection state for the Pixel Streaming service
enum StreamingConnectionState: String {
    case disconnected
    case connecting
    case connected
    case streaming
    case error
}

/// Pixel Streaming service — manages WebSocket + WebRTC connection to UE5
class PixelStreamingService: ObservableObject {
    static let shared = PixelStreamingService()
    
    @Published var connectionState: StreamingConnectionState = .disconnected
    @Published var streamerConnected: Bool = false
    @Published var activeMode: String? = nil
    @Published var playerId: String? = nil
    @Published var latencyMs: Int = 0
    
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    
    // Configuration
    private var signallingURL: URL?
    private let reconnectInterval: TimeInterval = 3.0
    private let heartbeatInterval: TimeInterval = 10.0
    
    private init() {
        session = URLSession(configuration: .default)
    }
    
    // MARK: - Connection
    
    /// Connect to the Pixel Streaming signalling server
    func connect(serverURL: String = Config.STREAMING_SERVER_URL) {
        guard let url = URL(string: serverURL) else {
            connectionState = .error
            return
        }
        
        signallingURL = url
        connectionState = .connecting
        
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()
        
        listenForMessages()
        startHeartbeat()
        
        connectionState = .connected
        print("[FEL] Connected to signalling server: \(serverURL)")
    }
    
    /// Disconnect from the signalling server
    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        
        connectionState = .disconnected
        streamerConnected = false
        activeMode = nil
        playerId = nil
    }
    
    // MARK: - Mode Control
    
    /// Launch a game mode by key
    func launchMode(_ modeKey: String) {
        sendCommand("launch_mode", payload: ["mode_key": modeKey])
    }
    
    /// Exit the current game mode
    func exitMode() {
        sendCommand("exit_mode")
        activeMode = nil
    }
    
    /// Request available modes
    func requestModes() {
        sendCommand("get_modes")
    }
    
    /// Request current status
    func requestStatus() {
        sendCommand("get_status")
    }
    
    /// Play a 3D exercise demonstration
    func playExerciseDemo(_ exerciseId: String) {
        sendCommand("exercise_demo", payload: ["exercise_id": exerciseId])
    }
    
    // MARK: - Data Channel
    
    /// Send a command to the UE5 game server via the signalling data channel
    func sendCommand(_ command: String, payload: [String: Any]? = nil) {
        var message: [String: Any] = ["command": command]
        if let payload = payload {
            message["payload"] = payload
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        webSocket?.send(.string(jsonString)) { error in
            if let error = error {
                print("[FEL] Send error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private
    
    private func listenForMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    // Binary frame (video/audio) — pass to WebRTC layer
                    break
                @unknown default:
                    break
                }
                // Continue listening
                self?.listenForMessages()
                
            case .failure(let error):
                print("[FEL] Receive error: \(error.localizedDescription)")
                self?.handleDisconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            // Player connected message
            if let type = json["type"] as? String, type == "playerConnected" {
                self?.playerId = json["playerId"] as? String
                self?.streamerConnected = json["streamerConnected"] as? Bool ?? false
                self?.activeMode = json["activeMode"] as? String
            }
            
            // Mode launch result
            if let response = json["response"] as? String {
                switch response {
                case "launch_mode_result":
                    if json["success"] as? Bool == true {
                        self?.activeMode = json["mode_key"] as? String
                        self?.connectionState = .streaming
                    }
                case "status":
                    self?.streamerConnected = json["connected"] as? Bool ?? false
                    self?.activeMode = json["current_mode"] as? String
                default:
                    break
                }
            }
        }
    }
    
    private func handleDisconnect() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
            self?.streamerConnected = false
            self?.scheduleReconnect()
        }
    }
    
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: false) { [weak self] _ in
            guard let url = self?.signallingURL?.absoluteString else { return }
            self?.connect(serverURL: url)
        }
    }
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.requestStatus()
        }
    }
}
