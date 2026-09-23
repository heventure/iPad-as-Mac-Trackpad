import Foundation
import MultipeerConnectivity
import Network

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

 override init(){super.init();session.delegate=self;advertiser.delegate=self;advertiser.startAdvertisingPeer();startUDPListener()}
 func stop(){advertiser.stopAdvertisingPeer();session.disconnect();udpListener?.cancel()}
 func restartAdvertising(){advertiser.stopAdvertisingPeer();advertiser.startAdvertisingPeer();if connectedPeerName==nil{statusText="等待 iPad 连接…"}}

 private func startUDPListener(){
  do{
   let listener=try NWListener(using:.udp)
   listener.service=NWListener.Service(name:nil,type:"_ipadpad-input._udp")
   listener.stateUpdateHandler={ [weak self] state in
    Task{@MainActor in
     switch state{
     case .ready:self?.realtimeStatus="UDP: 实时通道就绪"
     case .failed(let e):self?.realtimeStatus="UDP: \(e.localizedDescription)"
     default:break
     }
    }
   }
   listener.newConnectionHandler={ [weak self] connection in self?.receiveUDP(on:connection) }
   listener.start(queue:udpQueue);udpListener=listener
  }catch{realtimeStatus="UDP: \(error.localizedDescription)"}
 }

 nonisolated private func receiveUDP(on connection:NWConnection){
  connection.start(queue:udpQueue)
  func next(){
   connection.receiveMessage{ [weak self] data,_,_,error in
    if let data=data { self?.handleUDPPacket(data) }
    if error == nil { next() }
   }
  }
  next()
 }

 nonisolated private func handleUDPPacket(_ data:Data){
  guard data.count==9,data[0]==1 else{return}
  let b=[UInt8](data)
  let xBits=UInt32(b[1]) | UInt32(b[2])<<8 | UInt32(b[3])<<16 | UInt32(b[4])<<24
  let yBits=UInt32(b[5]) | UInt32(b[6])<<8 | UInt32(b[7])<<16 | UInt32(b[8])<<24
  MouseController.handle(.move(dx:Double(Float32(bitPattern:xBits)),dy:Double(Float32(bitPattern:yBits))))
 }
}
extension MacPeerReceiver:MCNearbyServiceAdvertiserDelegate{
 nonisolated func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didReceiveInvitationFromPeer peerID:MCPeerID,withContext context:Data?,invitationHandler:@escaping(Bool,MCSession?)->Void){Task{@MainActor in let accept=self.session.connectedPeers.isEmpty || self.session.connectedPeers.contains(peerID);invitationHandler(accept,accept ? self.session:nil)}}
 nonisolated func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didNotStartAdvertisingPeer error:Error){Task{@MainActor in self.statusText="广播失败：\(error.localizedDescription)"}}
}
extension MacPeerReceiver:MCSessionDelegate{
 nonisolated func session(_ session:MCSession,peer peerID:MCPeerID,didChange state:MCSessionState){Task{@MainActor in switch state{case .connected:self.connectedPeerName=peerID.displayName;self.statusText="已连接 \(peerID.displayName)";case .connecting:self.statusText="正在连接 \(peerID.displayName)…";case .notConnected:self.connectedPeerName=nil;self.statusText="等待 iPad 连接…";@unknown default:self.statusText="连接状态未知"}}}
 nonisolated func session(_ session:MCSession,didReceive data:Data,fromPeer peerID:MCPeerID){guard let m=try? PropertyListDecoder().decode(PointerMessage.self,from:data) else{return};MouseController.handle(m)}
 nonisolated func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID){}
 nonisolated func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress){}
 nonisolated func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?){}
}