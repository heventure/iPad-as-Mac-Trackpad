import SwiftUI

@main struct MacReceiverApp:App {
 @StateObject private var receiver=MacPeerReceiver()

 var body:some Scene {
  WindowGroup {
   MacReceiverView(receiver:receiver)
    .frame(width:440,height:330)
  }
  .windowResizability(.contentSize)
 }
}
