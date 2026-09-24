import Foundation
import MultipeerConnectivity
import Network
import UIKit

@MainActor final class iPadPeerSender:NSObject,ObservableObject {
 @Published private(set)var connectedPeerName:String?
 @Published private(set)var statusText="正在搜索 Mac…"
 @Published private(set)var realtimeStatus="UDP: 搜索 Mac…"
 @Published private(set)var discoveredMacNames:[String]=[]
 @Published private(set)var preferredMacName:String?

 private let serviceType="ipadpad"
 private let peerID=MCPeerID(displayName:UIDevice.current.name)
 private lazy var session=MCSession(peer:peerID,securityIdentity:nil,encryptionPreference:.required)
 private lazy var browser=MCNearbyServiceBrowser(peer:peerID,serviceType:serviceType)
 private var discoveredPeers=Set<MCPeerID>()
 private var lastInviteAt:[MCPeerID:Date]=[:]
 private var retryAfter:[MCPeerID:Date]=[:]
 private var pendingInvitePeer:MCPeerID?
 private var pendingInviteStartedAt:Date?
 private var chosenPeer:MCPeerID?
 private var preferredPeerName:String?
 private var reconnectTimer:Timer?
 private var browserStarted=false
 private var lastBrowserRestart=Date.distantPast
 private let inviteRetryInterval:TimeInterval=6
 private let failedPeerCooldown:TimeInterval=20
 private let browserRestartInterval:TimeInterval=8

 private let udpQueue=DispatchQueue(label:"ipadpad.udp.sender",qos:.userInteractive)
 private var udpConnection:NWConnection?
 private var udpSendCount=0

 override init(){
  super.init()
  print("[UDP-iPad] init")
  preferredPeerName=UserDefaults.standard.string(forKey:"preferredMacPeerName")
  preferredMacName=preferredPeerName
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
  guard let peer=chosenPeer,session.connectedPeers.contains(peer),let data=try? PropertyListEncoder().encode(message) else{return}
  try? session.send(data,toPeers:[peer],with:.unreliable)
 }

 func selectMac(named name:String){
  guard let target=discoveredPeers.first(where:{$0.displayName==name}) else{return}
  preferredPeerName=name
  preferredMacName=name
  UserDefaults.standard.set(name,forKey:"preferredMacPeerName")
  retryAfter.removeValue(forKey:target)
  lastInviteAt.removeValue(forKey:target)

  if chosenPeer==target,session.connectedPeers.contains(target){return}

  print("[MC-iPad] manual select peer=\(name)")
  pendingInvitePeer=nil
  pendingInviteStartedAt=nil
  chosenPeer=nil
  connectedPeerName=nil
  resetUDP(status:"UDP: 正在切换 Mac…")
  statusText="正在切换到 \(name)…"

  if !session.connectedPeers.isEmpty {
   session.disconnect()
  }
  DispatchQueue.main.asyncAfter(deadline:.now() + .milliseconds(350)){ [weak self] in
   guard let self,self.chosenPeer==nil,self.session.connectedPeers.isEmpty else{return}
   self.inviteIfNeeded(target)
  }
 }

 private func publishDiscoveredMacs(){
  discoveredMacNames=discoveredPeers.map(\.displayName).sorted{$0.localizedCaseInsensitiveCompare($1)==.orderedAscending}
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
  if let peer=pendingInvitePeer,let started=pendingInviteStartedAt,now.timeIntervalSince(started) >= inviteRetryInterval {
   print("[MC-iPad] pending invite timed out peer=\(peer.displayName)")
   markPeerFailed(peer,now:now)
   pendingInvitePeer=nil
   pendingInviteStartedAt=nil
  }
  if pendingInvitePeer != nil {return}

  if let peer=nextCandidate(now:now) {
   inviteIfNeeded(peer,now:now)
   return
  }

  if now.timeIntervalSince(lastBrowserRestart) >= browserRestartInterval {
   restartBrowsing()
  }
 }

 private func nextCandidate(now:Date)->MCPeerID?{
  let available=discoveredPeers.filter { peer in
   if let until=retryAfter[peer],until>now{return false}
   if let last=lastInviteAt[peer],now.timeIntervalSince(last)<inviteRetryInterval{return false}
   return true
  }
  if let preferredPeerName,
     let preferred=available.first(where:{$0.displayName==preferredPeerName}) {
   return preferred
  }
  return available.min { lhs,rhs in
   (lastInviteAt[lhs] ?? .distantPast) < (lastInviteAt[rhs] ?? .distantPast)
  }
 }

 private func markPeerFailed(_ peer:MCPeerID,now:Date=Date()){
  retryAfter[peer]=now.addingTimeInterval(failedPeerCooldown)
  lastInviteAt[peer]=now
  print("[MC-iPad] cooling down peer=\(peer.displayName) for \(Int(failedPeerCooldown))s")
 }

 private func inviteIfNeeded(_ peer:MCPeerID,now:Date=Date()){
  guard session.connectedPeers.isEmpty,pendingInvitePeer==nil,chosenPeer==nil else{return}
  if let until=retryAfter[peer],until>now{return}
  if let last=lastInviteAt[peer],now.timeIntervalSince(last) < inviteRetryInterval{return}
  lastInviteAt[peer]=now
  pendingInvitePeer=peer
  pendingInviteStartedAt=now
  statusText="正在连接 \(peer.displayName)…"
  print("[MC-iPad] invite peer=\(peer.displayName)")
  browser.invitePeer(peer,to:session,withContext:Data("role=ipad".utf8),timeout:5)
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
  guard info?["role"]=="mac" else{
   print("[MC-iPad] ignored non-Mac peer=\(peerID.displayName) info=\(String(describing:info))")
   return
  }
  Task{@MainActor in
   self.discoveredPeers.insert(peerID)
   self.publishDiscoveredMacs()
   self.inviteIfNeeded(peerID)
  }
 }

 nonisolated func browser(_ browser:MCNearbyServiceBrowser,lostPeer peerID:MCPeerID){
  Task{@MainActor in
   self.discoveredPeers.remove(peerID)
   self.publishDiscoveredMacs()
   self.lastInviteAt.removeValue(forKey:peerID)
   self.retryAfter.removeValue(forKey:peerID)
   if self.pendingInvitePeer==peerID {
    self.pendingInvitePeer=nil
    self.pendingInviteStartedAt=nil
   }
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
    guard self.chosenPeer==nil || self.chosenPeer==peerID else{
     print("[MC-iPad] multiple peers detected; disconnecting session unexpected=\(peerID.displayName)")
     self.session.disconnect()
     return
    }
    self.pendingInvitePeer=nil
    self.pendingInviteStartedAt=nil
    self.lastInviteAt.removeValue(forKey:peerID)
    self.retryAfter.removeValue(forKey:peerID)
    self.chosenPeer=peerID
    self.preferredPeerName=peerID.displayName
    self.preferredMacName=peerID.displayName
    UserDefaults.standard.set(peerID.displayName,forKey:"preferredMacPeerName")
    self.connectedPeerName=peerID.displayName
    self.statusText="已连接 \(peerID.displayName)"
    self.resetUDP(status:"UDP: 等待 Mac endpoint…")
   case .connecting:
    if self.pendingInvitePeer==nil {self.pendingInvitePeer=peerID;self.pendingInviteStartedAt=Date()}
    self.statusText="正在连接 \(peerID.displayName)…"
   case .notConnected:
    let failedBeforeConnect=self.pendingInvitePeer==peerID && self.chosenPeer != peerID
    if failedBeforeConnect {self.markPeerFailed(peerID)}
    if self.pendingInvitePeer==peerID {
     self.pendingInvitePeer=nil
     self.pendingInviteStartedAt=nil
    }
    if self.chosenPeer==peerID {self.chosenPeer=nil}
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
   guard self.chosenPeer==peerID,self.session.connectedPeers.contains(peerID) else{return}
   self.realtimeStatus="UDP: \(parts[0]):\(portValue)"
   print("[UDP-iPad] received UDP endpoint=\(parts[0]):\(portValue) from=\(peerID.displayName)")
   self.connectUDP(to:endpoint)
  }
 }

 nonisolated func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID){}
 nonisolated func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress){}
 nonisolated func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?){}
}
