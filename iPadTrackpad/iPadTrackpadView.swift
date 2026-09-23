import SwiftUI
import UIKit

struct iPadTrackpadView: View {
    @ObservedObject var peer: iPadPeerSender
    @State private var sensitivity = 1.2
    @State private var mode = 0

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
                    IMETextInput(
                        onCommit: { text in peer.send(.text(text)) },
                        onDelete: { peer.send(.key(51,0)) }
                    )
                    .frame(height:44)
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
    }
}

private struct IMETextInput:UIViewRepresentable {
    let onCommit:(String)->Void
    let onDelete:()->Void

    func makeCoordinator()->Coordinator { Coordinator(onCommit:onCommit,onDelete:onDelete) }

    func makeUIView(context:Context)->UITextField {
        let field=UITextField()
        field.borderStyle = .roundedRect
        field.placeholder = "点这里输入文字（支持中文输入法）…"
        field.autocorrectionType = .no
        field.delegate = context.coordinator
        field.addTarget(context.coordinator,action:#selector(Coordinator.changed(_:)),for:.editingChanged)
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field:UITextField,context:Context) {
        context.coordinator.onCommit=onCommit
        context.coordinator.onDelete=onDelete
        if field.window != nil && !field.isFirstResponder { field.becomeFirstResponder() }
    }

    final class Coordinator:NSObject,UITextFieldDelegate {
        var onCommit:(String)->Void
        var onDelete:()->Void
        private var committedText=""

        init(onCommit:@escaping(String)->Void,onDelete:@escaping()->Void) {
            self.onCommit=onCommit; self.onDelete=onDelete
        }

        @objc func changed(_ field:UITextField) {
            guard field.markedTextRange == nil else{return}
            let text=field.text ?? ""
            if text.hasPrefix(committedText) {
                let suffix=String(text.dropFirst(committedText.count))
                if !suffix.isEmpty { onCommit(suffix) }
            }
            committedText=text
            if committedText.count > 64 {
                field.text=""
                committedText=""
            }
        }

        func textField(_ textField:UITextField,shouldChangeCharactersIn range:NSRange,replacementString string:String)->Bool {
            if string.isEmpty && textField.markedTextRange == nil {
                let current=textField.text ?? ""
                if range.location < (current as NSString).length {
                    onDelete()
                    let ns=current as NSString
                    committedText=ns.replacingCharacters(in:range,with:"")
                }
            }
            return true
        }

        func textFieldShouldReturn(_ textField:UITextField)->Bool {
            onCommit("\n")
            return false
        }
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
