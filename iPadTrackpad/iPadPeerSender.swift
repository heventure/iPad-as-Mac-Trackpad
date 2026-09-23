import Foundation
import MultipeerConnectivity
import Network
import UIKit

@MainActor final class iPadPeerSender:NSObject,ObservableObject {
 @Published private(set)var connectedPeerName:String?
 @Published private(set)var statusText="正在搜索 Mac…"
 @Published private(set)var realtimeStatus="UDP: 搜索 Mac…"

 private let serviceType="ipadpad"
 private let peerID=MCPeerID(displayName:UIDevice.current.name)
 private lazy var session=MCSession(peer:peerID,securityIdentity:nil,encryptionPreference:.required)
 private lazy var browser=MCNearbyServiceBrowser(peer:peerID,serviceType:serviceType)
 private var invitedPeers=Set<MCPeerID>()

 private let udpQueue=DispatchQueue(label:"ipadpad.udp.sender",qos:.userInteractive)
 private var udpBrowser:NWBrowser?
 private var udpConnection:NWConnection?
 private var udpSendCount=0

 override init(){super.init();session.delegate=self;browser.delegate=self;browser.startBrowsingForPeers();startUDPDiscovery()}

 func stop(){browser.stopBrowsingForPeers();session.disconnect();udpBrowser?.cancel();udpConnection?.cancel()}

 // Pointer movement bypasses MultipeerConnectivity completely.
 func sendPointerUDP(dx:Double,dy:Double){
  guard let connection=udpConnection else{return}
  var data=Data([1])
  appendFloat32(Float32(dx),to:&data);appendFloat32(Float32(dy),to:&data)
  udpSendCount += 1
  if udpSendCount == 1 || udpSendCount % 100 == 0 { realtimeStatus="UDP: 已发送 \(udpSendCount) 个指针包" }
  connection.send(content:data,completion:.contentProcessed({ [weak self] error in
   if let error { Task { @MainActor in self?.realtimeStatus="UDP发送失败: \(error.localizedDescription)" } }
  }))
 }

 // Clicks, scrolling and keyboard remain on the encrypted control channel.
 func send(_ message:PointerMessage){
  guard !session.connectedPeers.isEmpty,let data=try? PropertyListEncoder().encode(message) else{return}
  try? session.send(data,toPeers:session.connectedPeers,with:.unreliable)
 }

 private func appendFloat32(_ value:Float32,to data:inout Data){
  var bits=value.bitPattern.littleEndian
  withUnsafeBytes(of:&bits){data.append(contentsOf:$0)}
 }

 private func startUDPDiscovery(){
  let b=NWBrowser(for:.bonjour(type:"_ipadpad-input._udp",domain:nil),using:.udp)
  b.browseResultsChangedHandler={ [weak self] results,_ in
   guard let endpoint=results.first?.endpoint else{return}
   Task{@MainActor in self?.connectUDP(to:endpoint)}
  }
  b.stateUpdateHandler={ [weak self] state in
   if case let .failed(error)=state { Task{@MainActor in self?.realtimeStatus="UDP: \(error.localizedDescription)"} }
  }
  b.start(queue:udpQueue);udpBrowser=b
 }

 private func connectUDP(to endpoint:NWEndpoint){
  udpConnection?.cancel()
  let c=NWConnection(to:endpoint,using:.udp)
  c.stateUpdateHandler={ [weak self,weak c] state in
   Task{@MainActor in
    guard let self=self,self.udpConnection === c else{return}
    switch state{
    case .ready:self.realtimeStatus="UDP: 实时通道已连接"
    case .preparing:self.realtimeStatus="UDP: 正在连接…"
    case .failed(let e):self.realtimeStatus="UDP: \(e.localizedDescription)"
    case .cancelled:self.realtimeStatus="UDP: 已断开"
    default:break
    }
   }
  }
  udpConnection=c;c.start(queue:udpQueue)
 }
}

extension iPadPeerSender:MCNearbyServiceBrowserDelegate{
 nonisolated func browser(_ browser:MCNearbyServiceBrowser,foundPeer peerID:MCPeerID,withDiscoveryInfo info:[String:String]?){Task{@MainActor in guard self.session.connectedPeers.isEmpty,!self.invitedPeers.contains(peerID) else{return};self.invitedPeers.insert(peerID);self.statusText="正在连接 \(peerID.displayName)…";browser.invitePeer(peerID,to:self.session,withContext:nil,timeout:10)}}
 nonisolated func browser(_ browser:MCNearbyServiceBrowser,lostPeer peerID:MCPeerID){Task{@MainActor in self.invitedPeers.remove(peerID);if self.connectedPeerName==peerID.displayName{self.connectedPeerName=nil;self.statusText="连接已断开，正在重新搜索…"}}}
}
extension iPadPeerSender:MCSessionDelegate{
 nonisolated func session(_ session:MCSession,peer peerID:MCPeerID,didChange state:MCSessionState){Task{@MainActor in switch state{case .connected:self.connectedPeerName=peerID.displayName;self.statusText="已连接 \(peerID.displayName)";case .connecting:self.statusText="正在连接 \(peerID.displayName)…";case .notConnected:self.connectedPeerName=nil;self.invitedPeers.remove(peerID);self.statusText="正在搜索 Mac…";@unknown default:self.statusText="连接状态未知"}}}
 nonisolated func session(_ session:MCSession,didReceive data:Data,fromPeer peerID:MCPeerID){}
 nonisolated func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID){}
 nonisolated func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress){}
 nonisolated func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?){}
}