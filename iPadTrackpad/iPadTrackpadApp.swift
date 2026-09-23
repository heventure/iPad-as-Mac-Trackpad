import SwiftUI
@main struct iPadTrackpadApp: App {
    @StateObject private var peer = iPadPeerSender()
    var body: some Scene { WindowGroup { iPadTrackpadView(peer: peer).preferredColorScheme(.dark) } }
}