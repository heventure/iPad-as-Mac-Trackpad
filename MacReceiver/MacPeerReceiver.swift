import Foundation
import MultipeerConnectivity
@MainActor final class MacPeerReceiver:NSObject,ObservableObject{
 @Published private(set)var connectedPeerName:String?;@Published private(set)var statusText="等待 iPad 连接…"
 private let serviceType="ipadpad";private let peerID=MCPeerID(displayName:Host.current().localizedName ?? "Mac")
 private lazy var session=MCSession(peer:peerID,securityIdentity:nil,encryptionPreference:.required)
 private lazy var advertiser=MCNearbyServiceAdvertiser(peer:peerID,discoveryInfo:["role":"mac"],serviceType:serviceType)
 override init(){super.init();session.delegate=self;advertiser.delegate=self;advertiser.startAdvertisingPeer()}
 deinit{advertiser.stopAdvertisingPeer();session.disconnect()}
 func restartAdvertising(){advertiser.stopAdvertisingPeer();advertiser.startAdvertisingPeer();if connectedPeerName==nil{statusText="等待 iPad 连接…"}}
}
extension MacPeerReceiver:MCNearbyServiceAdvertiserDelegate{
 nonisolated func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didReceiveInvitationFromPeer peerID:MCPeerID,withContext context:Data?,invitationHandler:@escaping(Bool,MCSession?)->Void){Task{@MainActor in let accept=self.session.connectedPeers.isEmpty || self.session.connectedPeers.contains(peerID);invitationHandler(accept,accept ? self.session:nil)}}
 nonisolated func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didNotStartAdvertisingPeer error:Error){Task{@MainActor in self.statusText="广播失败：\(error.localizedDescription)"}}
}
extension MacPeerReceiver:MCSessionDelegate{
 nonisolated func session(_ session:MCSession,peer peerID:MCPeerID,didChange state:MCSessionState){Task{@MainActor in switch state{case .connected:self.connectedPeerName=peerID.displayName;self.statusText="已连接 \(peerID.displayName)";case .connecting:self.statusText="正在连接 \(peerID.displayName)…";case .notConnected:self.connectedPeerName=nil;self.statusText="等待 iPad 连接…";@unknown default:self.statusText="连接状态未知"}}}
 nonisolated func session(_ session:MCSession,didReceive data:Data,fromPeer peerID:MCPeerID){guard let m=try? JSONDecoder().decode(PointerMessage.self,from:data) else{return};MouseController.handle(m)}
 nonisolated func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID){}
 nonisolated func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress){}
 nonisolated func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?){}
}