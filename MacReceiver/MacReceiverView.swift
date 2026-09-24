import SwiftUI
import Combine

struct MacReceiverView:View {
 @ObservedObject var receiver:MacPeerReceiver
 @State private var accessibilityGranted=MouseController.hasAccessibilityPermission
 @State private var settingsPresented=false
 private let permissionTimer=Timer.publish(every:1.0,on:.main,in:.common).autoconnect()

 var body:some View {
  VStack(spacing:16) {
   header
   connectionCard
   statusGrid
   footer
  }
  .padding(22)
  .frame(width:440,height:330)
  .background(
   LinearGradient(
    colors:[Color.black,Color(white:0.06)],
    startPoint:.topLeading,
    endPoint:.bottomTrailing
   ).ignoresSafeArea()
  )
  .preferredColorScheme(.dark)
  .onAppear {
   accessibilityGranted=MouseController.hasAccessibilityPermission
   if !accessibilityGranted {
    MouseController.requestAccessibilityPermission()
   }
  }
  .onReceive(permissionTimer) { _ in
   accessibilityGranted=MouseController.hasAccessibilityPermission
  }
 }

 private var header:some View {
  HStack(spacing:12) {
   ZStack {
    RoundedRectangle(cornerRadius:12,style:.continuous)
     .fill(Color.white.opacity(0.07))
    Image(systemName:"rectangle.connected.to.line.below")
     .font(.system(size:20,weight:.semibold))
     .symbolRenderingMode(.hierarchical)
   }
   .frame(width:42,height:42)

   VStack(alignment:.leading,spacing:2) {
    Text("iPad Remote Receiver")
     .font(.title3.weight(.semibold))
    Text("Mac input bridge")
     .font(.caption)
     .foregroundStyle(Color.secondary)
   }

   Spacer()

   Button {
    settingsPresented=true
   } label:{
    Image(systemName:"gearshape")
     .frame(width:30,height:30)
   }
   .buttonStyle(ReceiverUtilityButtonStyle())
   .accessibilityLabel("设置")
   .accessibilityIdentifier("receiver-settings")
   .popover(isPresented:$settingsPresented,arrowEdge:.top) {
    settingsPopover
     .presentationCompactAdaptation(.popover)
   }
  }
 }

 private var connectionCard:some View {
  HStack(spacing:14) {
   Circle()
    .fill(receiver.connectedPeerName == nil ? Color.orange:Color.green)
    .frame(width:11,height:11)
    .shadow(
     color:(receiver.connectedPeerName == nil ? Color.orange:Color.green).opacity(0.5),
     radius:5
    )

   VStack(alignment:.leading,spacing:3) {
    if let peer=receiver.connectedPeerName {
     Text(peer)
      .font(.headline)
      .lineLimit(1)
     Text("Connected")
      .font(.caption.weight(.medium))
      .foregroundStyle(Color.secondary)
    } else {
     Text("Waiting for iPad…")
      .font(.headline)
     Text(receiver.statusText)
      .font(.caption)
      .foregroundStyle(Color.secondary)
      .lineLimit(1)
    }
   }

   Spacer()

   if receiver.connectedPeerName != nil {
    Button("Disconnect") {
     receiver.disconnectCurrentPeer()
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .accessibilityLabel("断开当前 iPad")
    .accessibilityIdentifier("disconnect-ipad")
   }
  }
  .padding(16)
  .background(Color.white.opacity(0.055),in:RoundedRectangle(cornerRadius:16,style:.continuous))
  .overlay(
   RoundedRectangle(cornerRadius:16,style:.continuous)
    .stroke(Color.white.opacity(0.08),lineWidth:1)
  )
 }

 private var statusGrid:some View {
  VStack(spacing:0) {
   ReceiverStatusRow(
    title:"Pointer UDP",
    detail:pointerDetail,
    systemImage:"cursorarrow.motionlines",
    tone:pointerTone
   )

   Divider().opacity(0.45)

   ReceiverStatusRow(
    title:"Keyboard",
    detail:receiver.connectedPeerName == nil ? "Waiting":"Ready",
    systemImage:"keyboard",
    tone:receiver.connectedPeerName == nil ? .secondary:.green
   )

   Divider().opacity(0.45)

   ReceiverStatusRow(
    title:"Accessibility",
    detail:accessibilityGranted ? "Authorized":"Permission Required",
    systemImage:accessibilityGranted ? "checkmark.shield.fill":"exclamationmark.triangle.fill",
    tone:accessibilityGranted ? .green:.orange
   )
  }
  .padding(.horizontal,14)
  .background(Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:16,style:.continuous))
  .overlay(
   RoundedRectangle(cornerRadius:16,style:.continuous)
    .stroke(Color.white.opacity(0.06),lineWidth:1)
  )
 }

 private var footer:some View {
  HStack {
   Label(
    receiver.connectedPeerName == nil ? "Advertising on local network":"Control channel active",
    systemImage:receiver.connectedPeerName == nil ? "dot.radiowaves.left.and.right":"lock.fill"
   )
   .font(.caption)
   .foregroundStyle(Color.secondary)

   Spacer()

   if !accessibilityGranted {
    Button("Grant Access") {
     MouseController.requestAccessibilityPermission()
     accessibilityGranted=MouseController.hasAccessibilityPermission
    }
    .buttonStyle(.borderedProminent)
    .tint(Color.orange)
    .controlSize(.small)
    .accessibilityIdentifier("grant-accessibility")
   }
  }
 }

 private var settingsPopover:some View {
  VStack(alignment:.leading,spacing:16) {
   Text("Receiver Settings")
    .font(.headline)

   VStack(alignment:.leading,spacing:8) {
    Label("Accessibility",systemImage:"hand.raised")
     .font(.subheadline.weight(.semibold))
    Text(accessibilityGranted ? "Input control is authorized.":"Permission is required before mouse and keyboard events can be injected.")
     .font(.caption)
     .foregroundStyle(Color.secondary)

    Button(accessibilityGranted ? "Check Permission":"Grant Permission") {
     MouseController.requestAccessibilityPermission()
     accessibilityGranted=MouseController.hasAccessibilityPermission
    }
    .accessibilityIdentifier("check-accessibility")
   }

   Divider()

   VStack(alignment:.leading,spacing:8) {
    Label("Connection",systemImage:"network")
     .font(.subheadline.weight(.semibold))
    Button("Restart Advertising") {
     receiver.restartAdvertising()
    }
    .accessibilityIdentifier("restart-advertising")
   }

   Divider()

   VStack(alignment:.leading,spacing:6) {
    Label("Diagnostics",systemImage:"waveform.path.ecg")
     .font(.subheadline.weight(.semibold))
    Text(receiver.statusText)
    Text(receiver.realtimeStatus)
   }
   .font(.system(.caption,design:.monospaced))
   .foregroundStyle(Color.secondary)
   .accessibilityIdentifier("receiver-diagnostics")
  }
  .padding(18)
  .frame(width:310)
 }

 private var pointerDetail:String {
  let status=receiver.realtimeStatus
  if status.contains("失败") || status.contains("未找到") {
   return "Issue"
  }
  if status.contains("已收到") || status.contains("客户端已连接") {
   return "Active"
  }
  return "Ready"
 }

 private var pointerTone:Color {
  let status=receiver.realtimeStatus
  if status.contains("失败") || status.contains("未找到") {
   return .orange
  }
  return receiver.connectedPeerName == nil ? .secondary:.green
 }
}

private struct ReceiverStatusRow:View {
 let title:String
 let detail:String
 let systemImage:String
 let tone:Color

 var body:some View {
  HStack(spacing:12) {
   Image(systemName:systemImage)
    .font(.system(size:15,weight:.semibold))
    .foregroundStyle(tone)
    .frame(width:24)
   Text(title)
    .font(.subheadline.weight(.medium))
   Spacer()
   HStack(spacing:6) {
    Circle().fill(tone).frame(width:7,height:7)
    Text(detail)
     .font(.caption.weight(.medium))
     .foregroundStyle(Color.secondary)
   }
  }
  .frame(height:44)
 }
}

private struct ReceiverUtilityButtonStyle:ButtonStyle {
 func makeBody(configuration:Configuration)->some View {
  configuration.label
   .background(
    Color.white.opacity(configuration.isPressed ? 0.11:0.06),
    in:RoundedRectangle(cornerRadius:9,style:.continuous)
   )
   .overlay(
    RoundedRectangle(cornerRadius:9,style:.continuous)
     .stroke(Color.white.opacity(0.07),lineWidth:1)
   )
   .scaleEffect(configuration.isPressed ? 0.96:1)
   .animation(.easeOut(duration:0.08),value:configuration.isPressed)
 }
}
