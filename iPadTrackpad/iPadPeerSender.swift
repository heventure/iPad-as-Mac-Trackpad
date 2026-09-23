import Foundation
import MultipeerConnectivity
import UIKit

@MainActor
final class iPadPeerSender: NSObject, ObservableObject {
    @Published private(set) var connectedPeerName: String?
    @Published private(set) var statusText = "正在搜索 Mac…"

    private let serviceType = "ipadpad"
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private lazy var session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    private lazy var browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
    private var invitedPeers = Set<MCPeerID>()

    override init() {
        super.init()
        session.delegate = self
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    func stop() {
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    func send(_ message: PointerMessage) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }
}

extension iPadPeerSender: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard self.session.connectedPeers.isEmpty,
                  !self.invitedPeers.contains(peerID) else { return }
            self.invitedPeers.insert(peerID)
            self.statusText = "正在连接 \(peerID.displayName)…"
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.invitedPeers.remove(peerID)
            if self.connectedPeerName == peerID.displayName {
                self.connectedPeerName = nil
                self.statusText = "连接已断开，正在重新搜索…"
            }
        }
    }
}

extension iPadPeerSender: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.connectedPeerName = peerID.displayName
                self.statusText = "已连接 \(peerID.displayName)"
            case .connecting:
                self.statusText = "正在连接 \(peerID.displayName)…"
            case .notConnected:
                self.connectedPeerName = nil
                self.invitedPeers.remove(peerID)
                self.statusText = "正在搜索 Mac…"
            @unknown default:
                self.statusText = "连接状态未知"
            }
        }
    }
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}