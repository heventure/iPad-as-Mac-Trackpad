import SwiftUI

@main struct MacReceiverApp:App {
 @StateObject private var receiver=MacPeerReceiver()

 var body:some Scene {
  WindowGroup {
   MacReceiverView(receiver:receiver)
    .frame(minWidth:440,minHeight:330)
  }
  .windowResizability(.contentSize)
 }
}
