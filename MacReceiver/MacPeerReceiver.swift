import Foundation
import MultipeerConnectivity
import Network
import Darwin

@MainActor final class MacPeerReceiver:NSObject,ObservableObject{
 @Published private(set)var connectedPeerName:String?
 @Published private(set)var statusText="等待 iPad 连接…"
 @Published private(set)var realtimeStatus="UDP: 启动中…"

 private let serviceType="ipadpad"
 private let peerID=MCPeerID(displayName:Host.current().localizedName ?? "Mac")
 private lazy var session=MCSession(peer:peerID,securityIdentity:nil,encryptionPreference:.required)
 private lazy var advertiser=MCNearbyServiceAdvertiser(peer:peerID,discoveryInfo:["role":"mac"],serviceType:serviceType)
 private let udpQueue=DispatchQueue(label:"ipadpad.udp.receiver",qos:.userInteractive)
 private var udpListener:NWListener?
 private var udpConnections:[NWConnection]=[]
 private var udpPacketCount=0
 private var udpConnectionCount=0
 private var advertiserRestartWorkItem:DispatchWorkItem?
 private var pendingInvitationPeer:MCPeerID?
 private var chosenPeer:MCPeerID?

 override init(){super.init();print("[UDP-Mac] init");session.delegate=self;advertiser.delegate=self;advertiser.startAdvertisingPeer();startUDPListener()}
 func stop(){
  advertiserRestartWorkItem?.cancel()
  advertiserRestartWorkItem=nil
  MouseController.releaseAllKeys()
  advertiser.stopAdvertisingPeer()
  session.disconnect()
  resetUDPClients()
  udpListener?.cancel()
 }
 func restartAdvertising(){
  advertiserRestartWorkItem?.cancel()
  advertiserRestartWorkItem=nil
  advertiser.stopAdvertisingPeer()
  advertiser.startAdvertisingPeer()
  if connectedPeerName==nil{statusText="等待 iPad 连接…"}
 }

 private func scheduleAdvertisingRestart(){
  advertiserRestartWorkItem?.cancel()
  let work=DispatchWorkItem{ [weak self] in
   guard let self,self.session.connectedPeers.isEmpty else{return}
   print("[MC-Mac] restarting advertiser after disconnect")
   self.restartAdvertising()
  }
  advertiserRestartWorkItem=work
  DispatchQueue.main.asyncAfter(deadline:.now() + .milliseconds(350),execute:work)
 }

 private func resetUDPClients(){
  let connections=udpConnections
  udpConnections.removeAll()
  for connection in connections {
   connection.stateUpdateHandler=nil
   connection.cancel()
  }
  udpConnectionCount=0
  if udpListener != nil { realtimeStatus="UDP: 实时通道就绪" }
 }

 private func startUDPListener(){
  do{
   let listener=try NWListener(using:.udp)
   print("[UDP-Mac] listener created port=\(String(describing:listener.port))")
   listener.stateUpdateHandler={ [weak self,weak listener] state in
    print("[UDP-Mac] listener state=\(state) port=\(String(describing:listener?.port))")
    Task{@MainActor in
     switch state{
     case .ready:self?.realtimeStatus="UDP: 实时通道就绪";self?.sendUDPEndpointToConnectedPeers()
     case .failed(let e):self?.realtimeStatus="UDP: \(e.localizedDescription)"
     default:break
     }
    }
   }
   listener.newConnectionHandler={ [weak self] connection in
    print("[UDP-Mac] NEW CONNECTION endpoint=\(connection.endpoint)")
    guard let self else{return}
    connection.stateUpdateHandler={ [weak self,weak connection] state in
     print("[UDP-Mac] connection state=\(state) endpoint=\(String(describing:connection?.endpoint))")
     Task{@MainActor in
      guard let self else{return}
      switch state{
      case .ready:
       self.udpConnectionCount += 1
       self.realtimeStatus="UDP: 客户端已连接 (\(self.udpConnectionCount))，等待指针包…"
      case .failed(let e):
       self.realtimeStatus="UDP连接失败: \(e.localizedDescription)"
       if let connection { self.udpConnections.removeAll{$0 === connection} }
      case .cancelled:
       if let connection { self.udpConnections.removeAll{$0 === connection} }
      default:break
      }
     }
    }
    Task{@MainActor in
     self.udpConnections.append(connection)
    }
    self.receiveUDP(on:connection)
   }
   listener.start(queue:udpQueue);udpListener=listener
  }catch{realtimeStatus="UDP: \(error.localizedDescription)"}
 }

 nonisolated private func receiveUDP(on connection:NWConnection){
  connection.start(queue:udpQueue)
  receiveNextUDP(on:connection)
 }

 nonisolated private func receiveNextUDP(on connection:NWConnection){
  connection.receiveMessage{ [weak self,weak connection] data,context,isComplete,error in
   guard let self,let connection else{return}
   if let data,!data.isEmpty { print("[UDP-Mac] receive bytes=\(data.count) complete=\(isComplete) context=\(String(describing:context))"); self.handleUDPPacket(data) }
   if let error {
    print("[UDP-Mac] receive error=\(error)")
    Task{@MainActor in self.realtimeStatus="UDP接收失败: \(error.localizedDescription)"}
    return
   }
   self.receiveNextUDP(on:connection)
  }
 }

 private func sendUDPEndpoint(to peer:MCPeerID){
  guard let port=udpListener?.port else{print("[UDP-Mac] endpoint not ready yet");return}
  guard let host=localIPv4Address() else{print("[UDP-Mac] no LAN IPv4 address found");realtimeStatus="UDP: 未找到局域网 IPv4";return}
  let payload=Data(("UDP_ENDPOINT:\(host):\(port.rawValue)").utf8)
  do{try session.send(payload,toPeers:[peer],with:.reliable);print("[UDP-Mac] sent UDP endpoint=\(host):\(port.rawValue) to=\(peer.displayName)")}
  catch{print("[UDP-Mac] endpoint send failed=\(error)")}
 }

 private func localIPv4Address()->String?{
  var ifaddr:UnsafeMutablePointer<ifaddrs>?
  guard getifaddrs(&ifaddr)==0,let first=ifaddr else{return nil}
  defer{freeifaddrs(ifaddr)}
  var fallback:String?
  var ptr:UnsafeMutablePointer<ifaddrs>?=first
  while let current=ptr{
   let item=current.pointee
   defer{ptr=item.ifa_next}
   guard let addr=item.ifa_addr,addr.pointee.sa_family==UInt8(AF_INET) else{continue}
   let name=String(cString:item.ifa_name)
   if name=="lo0"{continue}
   var host=[CChar](repeating:0,count:Int(NI_MAXHOST))
   let length=socklen_t(addr.pointee.sa_len)
   if getnameinfo(addr,length,&host,socklen_t(host.count),nil,0,NI_NUMERICHOST)==0{
    let ip=String(cString:host)
    if name=="en0"{print("[UDP-Mac] LAN IPv4 en0=\(ip)");return ip}
    if fallback==nil{fallback=ip}
   }
  }
  if let fallback{print("[UDP-Mac] LAN IPv4 fallback=\(fallback)")}
  return fallback
 }

 private func sendUDPEndpointToConnectedPeers(){
  guard let peer=chosenPeer,session.connectedPeers.contains(peer) else{return}
  sendUDPEndpoint(to:peer)
 }

 nonisolated private func handleUDPPacket(_ data:Data){
  guard data.count==9,data[0]==1 else{return}
  let b=[UInt8](data)
  let xBits=UInt32(b[1]) | UInt32(b[2])<<8 | UInt32(b[3])<<16 | UInt32(b[4])<<24
  let yBits=UInt32(b[5]) | UInt32(b[6])<<8 | UInt32(b[7])<<16 | UInt32(b[8])<<24
  MouseController.handle(.move(dx:Double(Float32(bitPattern:xBits)),dy:Double(Float32(bitPattern:yBits))))
  Task{@MainActor in
   self.udpPacketCount += 1
   if self.udpPacketCount == 1 || self.udpPacketCount % 100 == 0 { self.realtimeStatus="UDP: 已收到 \(self.udpPacketCount) 个指针包" }
  }
 }
}
extension MacPeerReceiver:MCNearbyServiceAdvertiserDelegate{
 nonisolated func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didReceiveInvitationFromPeer peerID:MCPeerID,withContext context:Data?,invitationHandler:@escaping(Bool,MCSession?)->Void){Task{@MainActor in
  guard let context,String(data:context,encoding:.utf8)=="role=ipad" else{
   print("[MC-Mac] rejected peer with invalid role context=\(peerID.displayName)")
   invitationHandler(false,nil)
   return
  }
  if peerID.displayName==self.peerID.displayName{print("[MC-Mac] rejected same-name peer=\(peerID.displayName)");invitationHandler(false,nil);return}
  guard self.session.connectedPeers.isEmpty,self.pendingInvitationPeer==nil,self.chosenPeer==nil else{
   print("[MC-Mac] rejected extra invitation peer=\(peerID.displayName)")
   invitationHandler(false,nil)
   return
  }
  self.pendingInvitationPeer=peerID
  print("[MC-Mac] accepted invitation peer=\(peerID.displayName)")
  invitationHandler(true,self.session)
 }}
 nonisolated func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didNotStartAdvertisingPeer error:Error){Task{@MainActor in self.statusText="广播失败：\(error.localizedDescription)"}}
}
extension MacPeerReceiver:MCSessionDelegate{
 nonisolated func session(_ session:MCSession,peer peerID:MCPeerID,didChange state:MCSessionState){
  Task{@MainActor in
   switch state{
   case .connected:
    guard self.chosenPeer==nil || self.chosenPeer==peerID else{
     print("[MC-Mac] multiple peers detected; disconnecting session unexpected=\(peerID.displayName)")
     self.session.disconnect()
     return
    }
    self.pendingInvitationPeer=nil
    self.chosenPeer=peerID
    self.advertiserRestartWorkItem?.cancel()
    self.advertiserRestartWorkItem=nil
    self.connectedPeerName=peerID.displayName
    self.statusText="已连接 \(peerID.displayName)"
    self.sendUDPEndpoint(to:peerID)
   case .connecting:
    if self.pendingInvitationPeer==nil {self.pendingInvitationPeer=peerID}
    self.statusText="正在连接 \(peerID.displayName)…"
   case .notConnected:
    if self.pendingInvitationPeer==peerID {self.pendingInvitationPeer=nil}
    if self.chosenPeer==peerID {self.chosenPeer=nil}
    MouseController.releaseAllKeys()
    if self.session.connectedPeers.isEmpty {
     self.connectedPeerName=nil
     self.statusText="等待 iPad 连接…"
     self.resetUDPClients()
     self.scheduleAdvertisingRestart()
    }
   @unknown default:
    self.statusText="连接状态未知"
   }
  }
 }
 nonisolated func session(_ session:MCSession,didReceive data:Data,fromPeer peerID:MCPeerID){
  Task{@MainActor in
   guard self.chosenPeer==peerID,self.session.connectedPeers.contains(peerID),let message=try? PropertyListDecoder().decode(PointerMessage.self,from:data) else{return}
   MouseController.handle(message)
  }
 }
 nonisolated func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID){}
 nonisolated func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress){}
 nonisolated func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?){}
}