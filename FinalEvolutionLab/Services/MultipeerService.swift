import Foundation
import UIKit
import MultipeerConnectivity

/// Discovered peer when browsing (not yet connected).
struct DiscoveredPeer: Identifiable {
    var id: String { peerId.displayName }
    let peerId: MCPeerID
    let gameId: String?
}

@Observable
@MainActor
class MultipeerService: NSObject {
    var isConnected = false
    var connectedPeerName: String = ""
    var lastReceivedAction: String = ""
    var lastReceivedScore: Int = 0
    /// Round number for last received message (local play sync).
    var lastReceivedRound: Int?
    /// Raw last message (for trade and other protocols).
    var lastReceivedMessage: String = ""
    /// Discovered peers when browsing (do not auto-invite; user picks one).
    var discoveredPeers: [DiscoveredPeer] = []

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceType = "fel-arena"
    private var currentGameId: String?

    func startHosting(gameId: String) {
        currentGameId = gameId
        setupSession()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        discoveredPeers = []
        advertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: ["game": gameId], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func startBrowsing(gameId: String) {
        currentGameId = gameId
        setupSession()
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        discoveredPeers = []
        browser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    /// Invite a discovered peer to the session (call after startBrowsing).
    func invite(peer: MCPeerID) {
        guard let browser, let session else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    }

    func clearDiscovered() {
        discoveredPeers = []
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        isConnected = false
        connectedPeerName = ""
        discoveredPeers = []
        currentGameId = nil
    }

    /// Send action and score; optional round for local play sync.
    func sendAction(_ action: String, score: Int, round: Int? = nil) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let payload = round != nil ? "\(action)|\(score)|\(round!)" : "\(action)|\(score)"
        if let data = payload.data(using: .utf8) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    /// Send a trade or other custom message (e.g. TRADE_OFFER|20, TRADE_CONFIRM|20|15).
    func send(_ message: String) {
        guard let session, !session.connectedPeers.isEmpty,
              let data = message.data(using: .utf8) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func setupSession() {
        if session == nil {
            session = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .none)
            session?.delegate = self
        }
    }
}

extension MultipeerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                isConnected = true
                connectedPeerName = peerID.displayName
            case .notConnected:
                isConnected = false
                connectedPeerName = ""
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = String(data: data, encoding: .utf8) else { return }
        let parts = message.split(separator: "|").map { String($0) }
        Task { @MainActor in
            lastReceivedMessage = message
            if parts.count >= 2 {
                lastReceivedAction = parts[0]
                lastReceivedScore = Int(parts[1]) ?? 0
                lastReceivedRound = parts.count >= 3 ? Int(parts[2]) : nil
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            invitationHandler(true, session)
        }
    }
}

extension MultipeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            let gameId = info?["game"]
            if !discoveredPeers.contains(where: { $0.peerId == peerID }) {
                discoveredPeers.append(DiscoveredPeer(peerId: peerID, gameId: gameId))
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            discoveredPeers.removeAll { $0.peerId == peerID }
        }
    }
}
