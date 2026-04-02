// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Live Link Client - Streams facial data to Unreal Engine

import Foundation
import Network
import Combine

/// Connection state for Live Link streaming.
enum LiveLinkConnectionState: String, CaseIterable {
    case disconnected = "Disconnected"
    case discovering = "Discovering"
    case connecting = "Connecting"
    case connected = "Connected"
    case streaming = "Streaming"
    case error = "Error"
    
    var displayName: String { rawValue }
}

/// Manages the network connection to UE5 Live Link and streams blend shape data.
class LiveLinkConnectionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var connectionState: LiveLinkConnectionState = .disconnected
    @Published var serverAddress: String = ""
    @Published var serverPort: UInt16 = 11111
    @Published var subjectName: String = "FELFaceCapture"
    @Published var packetsSent: Int = 0
    @Published var errorMessage: String = ""
    @Published var discoveredServers: [DiscoveredServer] = []
    
    // MARK: - Internal State
    
    private var connection: NWConnection?
    private var browser: NWBrowser?
    private var sendQueue = DispatchQueue(label: "com.fel.livelink.send", qos: .userInteractive)
    private var lastSendTime: Date = Date()
    private let minSendInterval: TimeInterval = 1.0 / 60.0 // 60 FPS cap
    
    // MARK: - Server Discovery
    
    struct DiscoveredServer: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let host: String
        let port: UInt16
    }
    
    // MARK: - Public API
    
    /// Start discovering UE5 Live Link servers on the local network.
    func startDiscovery() {
        connectionState = .discovering
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_livelink._tcp", domain: nil)
        browser = NWBrowser(for: descriptor, using: parameters)
        
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            
            var servers: [DiscoveredServer] = []
            for result in results {
                switch result.endpoint {
                case .service(let name, _, _, _):
                    servers.append(DiscoveredServer(
                        name: name,
                        host: name,
                        port: self.serverPort
                    ))
                default:
                    break
                }
            }
            
            DispatchQueue.main.async {
                self.discoveredServers = servers
            }
        }
        
        browser?.start(queue: .main)
        print("[FELLiveLink] Server discovery started.")
    }
    
    /// Stop server discovery.
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
    }
    
    /// Connect to the UE5 Live Link server.
    func connect() {
        guard !serverAddress.isEmpty else {
            connectionState = .error
            errorMessage = "Server address is empty."
            return
        }
        
        connectionState = .connecting
        
        let host = NWEndpoint.Host(serverAddress)
        let port = NWEndpoint.Port(rawValue: serverPort)!
        
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.allowFastOpen = true
        
        let conn = NWConnection(host: host, port: port, using: parameters)
        
        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.connectionState = .connected
                    print("[FELLiveLink] Connected to \(self.serverAddress):\(self.serverPort)")
                case .failed(let error):
                    self.connectionState = .error
                    self.errorMessage = error.localizedDescription
                    print("[FELLiveLink] Connection failed: \(error)")
                case .cancelled:
                    self.connectionState = .disconnected
                    print("[FELLiveLink] Connection cancelled.")
                case .waiting(let error):
                    self.connectionState = .connecting
                    print("[FELLiveLink] Waiting: \(error)")
                default:
                    break
                }
            }
        }
        
        conn.start(queue: sendQueue)
        connection = conn
    }
    
    /// Connect to a discovered server.
    func connectToServer(_ server: DiscoveredServer) {
        serverAddress = server.host
        serverPort = server.port
        connect()
    }
    
    /// Disconnect from the server.
    func disconnect() {
        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        packetsSent = 0
    }
    
    /// Send blend shape data to UE5 Live Link.
    func sendBlendShapes(_ blendShapes: [String: Float]) {
        guard connection != nil,
              connectionState == .connected || connectionState == .streaming else {
            return
        }
        
        // Rate limit to target FPS
        let now = Date()
        guard now.timeIntervalSince(lastSendTime) >= minSendInterval else { return }
        lastSendTime = now
        
        // Build Live Link packet
        let packet = buildLiveLinkPacket(subjectName: subjectName, blendShapes: blendShapes)
        
        connection?.send(content: packet, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("[FELLiveLink] Send error: \(error)")
            } else {
                DispatchQueue.main.async {
                    self?.packetsSent += 1
                    if self?.connectionState != .streaming {
                        self?.connectionState = .streaming
                    }
                }
            }
        })
    }
    
    // MARK: - Packet Building
    
    /// Build a Live Link compatible UDP packet with blend shape data.
    private func buildLiveLinkPacket(subjectName: String, blendShapes: [String: Float]) -> Data {
        var data = Data()
        
        // Magic number (FEL Live Link protocol)
        let magic: UInt32 = 0x46454C4C // "FELL"
        data.append(contentsOf: withUnsafeBytes(of: magic.littleEndian) { Array($0) })
        
        // Protocol version
        let version: UInt16 = 1
        data.append(contentsOf: withUnsafeBytes(of: version.littleEndian) { Array($0) })
        
        // Timestamp (milliseconds since epoch)
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        data.append(contentsOf: withUnsafeBytes(of: timestamp.littleEndian) { Array($0) })
        
        // Subject name (null-terminated UTF8, padded to 64 bytes)
        var nameBytes = Array(subjectName.utf8)
        nameBytes.append(0) // null terminator
        while nameBytes.count < 64 { nameBytes.append(0) }
        data.append(contentsOf: nameBytes.prefix(64))
        
        // Number of blend shapes
        let count: UInt16 = UInt16(blendShapes.count)
        data.append(contentsOf: withUnsafeBytes(of: count.littleEndian) { Array($0) })
        
        // Blend shape values (52 floats, ordered by ARKit convention)
        let orderedNames = FaceTracker.arkitBlendShapeNames.map { $0.rawValue }
        for name in orderedNames {
            let value = blendShapes[name] ?? 0.0
            data.append(contentsOf: withUnsafeBytes(of: value.bitPattern.littleEndian) { Array($0) })
        }
        
        return data
    }
}
