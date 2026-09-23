import SwiftUI

struct iPadTrackpadView: View {
    @ObservedObject var peer: iPadPeerSender
    @State private var sensitivity = 1.2

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iPad Trackpad")
                        .font(.title2.bold())

                    Text(peer.statusText)
                        .font(.subheadline)
                        .foregroundStyle(
                            peer.connectedPeerName == nil
                                ? Color.secondary
                                : Color.green
                        )
                }

                Spacer()

                Circle()
                    .fill(peer.connectedPeerName == nil ? Color.orange : Color.green)
                    .frame(width: 12, height: 12)
            }

            TrackpadSurface(sensitivity: sensitivity, onMessage: peer.send)
                .overlay(alignment: .bottomLeading) {
                    Text("单指移动 · 轻点左键 · 双指轻点右键 · 双指滚动")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .padding(16)
                        .allowsHitTesting(false)
                }

            HStack(spacing: 12) {
                Image(systemName: "tortoise")
                Slider(value: $sensitivity, in: 0.5...2.5, step: 0.1)
                Image(systemName: "hare")
                Text(String(format: "%.1fx", sensitivity))
                    .font(.system(.footnote, design: .monospaced))
                    .frame(width: 42, alignment: .trailing)
            }
            .foregroundStyle(Color.secondary)
        }
        .padding(20)
        .background(Color.black.ignoresSafeArea())
    }
}