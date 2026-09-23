import SwiftUI

struct MacReceiverView: View {
    @ObservedObject var receiver: MacPeerReceiver

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 64, weight: .light))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Mac Trackpad Receiver").font(.largeTitle.bold())
                Text(receiver.statusText)
                    .foregroundStyle(receiver.connectedPeerName == nil ? Color.secondary : Color.green)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("保持此 App 运行，iPad 会自动发现这台 Mac。", systemImage: "wifi")
                    Label("第一次控制鼠标前，需要授予“辅助功能”权限。", systemImage: "hand.raised")
                    Label("Demo 使用加密的 MultipeerConnectivity 会话，但没有设备配对确认。", systemImage: "lock")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack {
                Button("检查/申请辅助功能权限") { MouseController.requestAccessibilityPermission() }
                    .buttonStyle(.borderedProminent)
                Button("重新广播") { receiver.restartAdvertising() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .onAppear {
            if !MouseController.hasAccessibilityPermission {
                MouseController.requestAccessibilityPermission()
            }
        }
    }
}