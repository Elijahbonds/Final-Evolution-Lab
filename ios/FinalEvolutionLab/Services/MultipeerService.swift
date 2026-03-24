import Foundation
import UIKit
import MultipeerConnectivity

@Observable
@MainActor
class MultipeerService: NSObject {
    var isConnected = false
    var connectedPeerName: String = ""
    var lastReceivedAction: String = ""
    var lastReceivedScore: Int = 0

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceType = "fel-arena"

    func startHosting(gameId: String) {
        setupSession()
        advertiser?.stopAdvertisingPeer()
        advertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: ["game": gameId], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func startBrowsing(gameId: String) {
        setupSession()
        browser?.stopBrowsingForPeers()
        browser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        isConnected = false
        connectedPeerName = ""
    }

    func sendAction(_ action: String, score: Int) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let payload = "\(action)|\(score)"
        if let data = payload.data(using: .utf8) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
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
        let parts = message.split(separator: "|")
        Task { @MainActor in
            if parts.count >= 2 {
                lastReceivedAction = String(parts[0])
                lastReceivedScore = Int(parts[1]) ?? 0
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
            if let session {
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
