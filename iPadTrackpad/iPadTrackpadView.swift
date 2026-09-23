import SwiftUI
import UIKit

struct iPadTrackpadView: View {
    @ObservedObject var peer: iPadPeerSender
    @State private var sensitivity = 1.2
    @State private var mode = 0
    @FocusState private var keyboardFocused: Bool
    @State private var keyboardBuffer = ""

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment:.leading,spacing:4) {
                    Text("iPad Remote").font(.title2.bold())
                    Text(peer.statusText).font(.subheadline)
                        .foregroundStyle(peer.connectedPeerName == nil ? Color.secondary : Color.green)
                    Text(peer.realtimeStatus)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                }
                Spacer()
                Circle().fill(peer.connectedPeerName == nil ? Color.orange : Color.green).frame(width:12,height:12)
            }

            Picker("模式", selection:$mode) {
                Text("触控板").tag(0)
                Text("触控板 + 键盘").tag(1)
            }.pickerStyle(.segmented)

            TrackpadSurface(sensitivity:sensitivity,onMessage:peer.send,onRawMove:peer.sendPointerUDP)
                .overlay(alignment:.bottomLeading) {
                    Text("单指移动 · 轻点左键 · 双指轻点右键 · 双指滚动")
                        .font(.footnote).foregroundStyle(Color.secondary).padding(16).allowsHitTesting(false)
                }

            if mode == 1 {
                VStack(spacing:10) {
                    HStack(spacing:8) {
                        SpecialKey("esc") { peer.send(.key(53,0)) }
                        SpecialKey("tab") { peer.send(.key(48,0)) }
                        SpecialKey("⌘C") { peer.send(.key(8,CGEventFlagMask.command)) }
                        SpecialKey("⌘V") { peer.send(.key(9,CGEventFlagMask.command)) }
                        SpecialKey("⌘Z") { peer.send(.key(6,CGEventFlagMask.command)) }
                        SpecialKey("⌫") { peer.send(.key(51,0)) }
                        SpecialKey("↩") { peer.send(.key(36,0)) }
                    }
                    TextField("点这里输入文字…", text:$keyboardBuffer)
                        .textFieldStyle(.roundedBorder)
                        .focused($keyboardFocused)
                        .onChange(of:keyboardBuffer) { oldValue,newValue in
                            if newValue.count > oldValue.count, newValue.hasPrefix(oldValue) {
                                peer.send(.text(String(newValue.dropFirst(oldValue.count))))
                            } else if newValue.count < oldValue.count {
                                for _ in 0..<(oldValue.count-newValue.count) { peer.send(.key(51,0)) }
                            } else if !newValue.isEmpty { peer.send(.text(newValue)) }
                            if newValue.count > 64 { keyboardBuffer="" }
                        }
                    Button("显示系统键盘") { keyboardFocused=true }
                        .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing:12) {
                Image(systemName:"tortoise")
                Slider(value:$sensitivity,in:0.5...2.5,step:0.1)
                Image(systemName:"hare")
                Text(String(format:"%.1fx",sensitivity)).font(.system(.footnote,design:.monospaced)).frame(width:42)
            }.foregroundStyle(Color.secondary)
        }
        .padding(20).background(Color.black.ignoresSafeArea())
        .onChange(of:mode) { _,newValue in if newValue == 1 { keyboardFocused=true } }
    }
}

private let CGEventFlagMaskCommand: UInt64 = 1 << 20
private enum CGEventFlagMask { static let command = CGEventFlagMaskCommand }

private struct SpecialKey: View {
    let title:String
    let action:()->Void
    init(_ title:String,action:@escaping()->Void){self.title=title;self.action=action}
    var body:some View { Button(title,action:action).buttonStyle(.bordered).frame(maxWidth:.infinity) }
}