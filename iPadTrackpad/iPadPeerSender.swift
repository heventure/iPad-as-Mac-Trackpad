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
 private var discoveredPeers=Set<MCPeerID>()
 private var lastInviteAt:[MCPeerID:Date]=[:]
 private var reconnectTimer:Timer?
 private var browserStarted=false
 private var lastBrowserRestart=Date.distantPast
 private let inviteRetryInterval:TimeInterval=6
 private let browserRestartInterval:TimeInterval=8

 private let udpQueue=DispatchQueue(label:"ipadpad.udp.sender",qos:.userInteractive)
 private var udpConnection:NWConnection?
 private var udpSendCount=0

 override init(){
  super.init()
  print("[UDP-iPad] init")
  session.delegate=self
  browser.delegate=self
  startBrowsing()
  startReconnectTimer()
 }

 func stop(){
  reconnectTimer?.invalidate()
  reconnectTimer=nil
  if browserStarted {
   browser.stopBrowsingForPeers()
   browserStarted=false
  }
  session.disconnect()
  resetUDP(status:"UDP: 已断开")
 }

 // Pointer movement bypasses MultipeerConnectivity completely.
 func sendPointerUDP(dx:Double,dy:Double){
  guard connectedPeerName != nil,let connection=udpConnection else{return}
  var data=Data([1])
  appendFloat32(Float32(dx),to:&data)
  appendFloat32(Float32(dy),to:&data)
  udpSendCount += 1
  connection.send(content:data,contentContext:.defaultMessage,isComplete:true,completion:.contentProcessed({ [weak self,weak connection] error in
   Task { @MainActor in
    guard let self,let connection,self.udpConnection === connection else{return}
    if let error {
     print("[UDP-iPad] send error=\(error)")
     self.resetUDP(status:"UDP发送失败: \(error.localizedDescription)")
    } else if self.udpSendCount == 1 || self.udpSendCount % 100 == 0 {
     print("[UDP-iPad] send processed count=\(self.udpSendCount) dx=\(dx) dy=\(dy) endpoint=\(connection.endpoint)")
     self.realtimeStatus="UDP: 已确认发送 \(self.udpSendCount) 个 datagram"
    }
   }
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

 private func startBrowsing(){
  guard !browserStarted else{return}
  browser.startBrowsingForPeers()
  browserStarted=true
  lastBrowserRestart=Date()
 }

 private func restartBrowsing(){
  guard session.connectedPeers.isEmpty else{return}
  if browserStarted {
   browser.stopBrowsingForPeers()
   browserStarted=false
  }
  browser.startBrowsingForPeers()
  browserStarted=true
  lastBrowserRestart=Date()
  statusText="正在搜索 Mac…"
 }

 private func startReconnectTimer(){
  reconnectTimer?.invalidate()
  reconnectTimer=Timer.scheduledTimer(withTimeInterval:2.0,repeats:true){ [weak self] _ in
   Task { @MainActor in self?.recoverConnectionIfNeeded() }
  }
 }

 private func recoverConnectionIfNeeded(){
  guard session.connectedPeers.isEmpty else{return}
  let now=Date()
  if now.timeIntervalSince(lastBrowserRestart) >= browserRestartInterval {
   restartBrowsing()
   return
  }
  guard let peer=discoveredPeers.first else{return}
  inviteIfNeeded(peer,now:now)
 }

 private func inviteIfNeeded(_ peer:MCPeerID,now:Date=Date()){
  guard session.connectedPeers.isEmpty else{return}
  if let last=lastInviteAt[peer],now.timeIntervalSince(last) < inviteRetryInterval{return}
  lastInviteAt[peer]=now
  statusText="正在连接 \(peer.displayName)…"
  print("[MC-iPad] invite peer=\(peer.displayName)")
  browser.invitePeer(peer,to:session,withContext:nil,timeout:5)
 }

 private func resetUDP(status:String){
  let old=udpConnection
  udpConnection=nil
  old?.stateUpdateHandler=nil
  old?.cancel()
  udpSendCount=0
  realtimeStatus=status
 }

 private func connectUDP(to endpoint:NWEndpoint){
  print("[UDP-iPad] connect endpoint=\(endpoint)")
  resetUDP(status:"UDP: 正在连接…")
  let c=NWConnection(to:endpoint,using:.udp)
  c.stateUpdateHandler={ [weak self,weak c] state in
   print("[UDP-iPad] connection state=\(state) endpoint=\(endpoint)")
   Task{@MainActor in
    guard let self=self,let c,self.udpConnection === c else{return}
    switch state{
    case .ready:self.realtimeStatus="UDP: 实时通道已连接"
    case .preparing:self.realtimeStatus="UDP: 正在连接…"
    case .failed(let e):
     self.udpConnection=nil
     c.stateUpdateHandler=nil
     c.cancel()
     self.realtimeStatus="UDP: \(e.localizedDescription)"
    case .cancelled:self.realtimeStatus="UDP: 已断开"
    default:break
    }
   }
  }
  udpConnection=c
  c.start(queue:udpQueue)
 }
}

extension iPadPeerSender:MCNearbyServiceBrowserDelegate{
 nonisolated func browser(_ browser:MCNearbyServiceBrowser,foundPeer peerID:MCPeerID,withDiscoveryInfo info:[String:String]?){
  Task{@MainActor in
   self.discoveredPeers.insert(peerID)
   self.inviteIfNeeded(peerID)
  }
 }

 nonisolated func browser(_ browser:MCNearbyServiceBrowser,lostPeer peerID:MCPeerID){
  Task{@MainActor in
   self.discoveredPeers.remove(peerID)
   self.lastInviteAt.removeValue(forKey:peerID)
   if self.session.connectedPeers.isEmpty {
    self.statusText="连接已断开，正在重新搜索…"
   }
  }
 }
}

extension iPadPeerSender:MCSessionDelegate{
 nonisolated func session(_ session:MCSession,peer peerID:MCPeerID,didChange state:MCSessionState){
  Task{@MainActor in
   switch state{
   case .connected:
    self.lastInviteAt.removeValue(forKey:peerID)
    self.connectedPeerName=peerID.displayName
    self.statusText="已连接 \(peerID.displayName)"
    self.resetUDP(status:"UDP: 等待 Mac endpoint…")
   case .connecting:
    self.statusText="正在连接 \(peerID.displayName)…"
   case .notConnected:
    self.lastInviteAt.removeValue(forKey:peerID)
    if self.session.connectedPeers.isEmpty {
     self.connectedPeerName=nil
     self.statusText="连接已断开，正在重新搜索…"
     self.resetUDP(status:"UDP: 控制通道已断开")
     self.restartBrowsing()
    }
   @unknown default:
    self.statusText="连接状态未知"
   }
  }
 }

 nonisolated func session(_ session:MCSession,didReceive data:Data,fromPeer peerID:MCPeerID){
  guard let text=String(data:data,encoding:.utf8),text.hasPrefix("UDP_ENDPOINT:") else{return}
  let value=String(text.dropFirst("UDP_ENDPOINT:".count))
  let parts=value.split(separator:":",maxSplits:1).map(String.init)
  guard parts.count==2,let portValue=UInt16(parts[1]),let port=NWEndpoint.Port(rawValue:portValue) else{
   print("[UDP-iPad] invalid endpoint payload=\(text)")
   return
  }
  let host=NWEndpoint.Host(parts[0])
  let endpoint=NWEndpoint.hostPort(host:host,port:port)
  Task{@MainActor in
   guard self.session.connectedPeers.contains(peerID) else{return}
   self.realtimeStatus="UDP: \(parts[0]):\(portValue)"
   print("[UDP-iPad] received UDP endpoint=\(parts[0]):\(portValue) from=\(peerID.displayName)")
   self.connectUDP(to:endpoint)
  }
 }

 nonisolated func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID){}
 nonisolated func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress){}
 nonisolated func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?){}
}
