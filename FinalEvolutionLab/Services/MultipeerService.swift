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

    /// Display name of a peer requesting join — accept/reject from UI.
    var pendingInvitationPeerName: String?

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceType = "fel-arena"

    /// Must match ``GameModeId/rawValue`` on both ends.
    private(set) var activeGameId: String = ""

    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?

    func startHosting(gameId: String) {
        activeGameId = gameId
        rebuildSessionIfNeeded()
        advertiser?.stopAdvertisingPeer()
        advertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: ["game": gameId], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func startBrowsing(gameId: String) {
        activeGameId = gameId
        rebuildSessionIfNeeded()
        browser?.stopBrowsingForPeers()
        browser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stop() {
        pendingInvitationHandler = nil
        pendingInvitationPeerName = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        session = nil
        isConnected = false
        connectedPeerName = ""
        activeGameId = ""
    }

    func acceptPendingInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(true, session)
        pendingInvitationHandler = nil
        pendingInvitationPeerName = nil
    }

    func rejectPendingInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(false, nil)
        pendingInvitationHandler = nil
        pendingInvitationPeerName = nil
    }

    func sendAction(_ action: String, score: Int) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let payload = "\(action)|\(score)"
        if let data = payload.data(using: .utf8) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    private func rebuildSessionIfNeeded() {
        session?.disconnect()
        session = nil
        session = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
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
            pendingInvitationPeerName = peerID.displayName
            pendingInvitationHandler = invitationHandler
        }
    }
}

extension MultipeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard let session, !activeGameId.isEmpty else { return }
            guard info?["game"] == activeGameId else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
