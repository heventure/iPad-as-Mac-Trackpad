import SwiftUI
import Combine

struct MacReceiverView: View {
    @ObservedObject var receiver: MacPeerReceiver
    @State private var accessibilityGranted = MouseController.hasAccessibilityPermission
    private let permissionTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 64, weight: .light))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Mac Trackpad Receiver").font(.largeTitle.bold())
                Text(receiver.statusText)
                    .foregroundStyle(receiver.connectedPeerName == nil ? Color.secondary : Color.green)
                Text(receiver.realtimeStatus)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.cyan)
                Label(
                    accessibilityGranted ? "辅助功能权限：已授权" : "辅助功能权限：未授权，控制事件将被忽略",
                    systemImage: accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accessibilityGranted ? Color.green : Color.orange)
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
                Button(accessibilityGranted ? "重新检查辅助功能权限" : "检查/申请辅助功能权限") {
                    MouseController.requestAccessibilityPermission()
                    accessibilityGranted = MouseController.hasAccessibilityPermission
                }
                .buttonStyle(.borderedProminent)
                .tint(accessibilityGranted ? Color.green : Color.orange)

                Button("重新广播") { receiver.restartAdvertising() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .onAppear {
            accessibilityGranted = MouseController.hasAccessibilityPermission
            if !accessibilityGranted {
                MouseController.requestAccessibilityPermission()
            }
        }
        .onReceive(permissionTimer) { _ in
            accessibilityGranted = MouseController.hasAccessibilityPermission
        }
    }
}
