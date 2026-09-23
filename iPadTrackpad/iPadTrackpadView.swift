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
                MacKeyboard { code,flags in peer.send(.key(code,flags)) }
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

private struct KeySpec:Identifiable {
    let id=UUID()
    let label:String
    let code:UInt16
    var width:CGFloat=1
}

private struct MacKeyboard:View {
    let send:(UInt16,UInt64)->Void
    @State private var shift=false
    @State private var control=false
    @State private var option=false
    @State private var command=false
    @State private var caps=false

    private let row1=[
        KeySpec(label:"esc",code:53),KeySpec(label:"1",code:18),KeySpec(label:"2",code:19),KeySpec(label:"3",code:20),
        KeySpec(label:"4",code:21),KeySpec(label:"5",code:23),KeySpec(label:"6",code:22),KeySpec(label:"7",code:26),
        KeySpec(label:"8",code:28),KeySpec(label:"9",code:25),KeySpec(label:"0",code:29),KeySpec(label:"-",code:27),
        KeySpec(label:"=",code:24),KeySpec(label:"⌫",code:51,width:1.55)
    ]
    private let row2=[
        KeySpec(label:"tab",code:48,width:1.35),KeySpec(label:"Q",code:12),KeySpec(label:"W",code:13),KeySpec(label:"E",code:14),
        KeySpec(label:"R",code:15),KeySpec(label:"T",code:17),KeySpec(label:"Y",code:16),KeySpec(label:"U",code:32),
        KeySpec(label:"I",code:34),KeySpec(label:"O",code:31),KeySpec(label:"P",code:35),KeySpec(label:"[",code:33),
        KeySpec(label:"]",code:30),KeySpec(label:"\\",code:42,width:1.2)
    ]
    private let row3=[
        KeySpec(label:"A",code:0),KeySpec(label:"S",code:1),KeySpec(label:"D",code:2),KeySpec(label:"F",code:3),
        KeySpec(label:"G",code:5),KeySpec(label:"H",code:4),KeySpec(label:"J",code:38),KeySpec(label:"K",code:40),
        KeySpec(label:"L",code:37),KeySpec(label:";",code:41),KeySpec(label:"'",code:39),KeySpec(label:"return",code:36,width:1.8)
    ]
    private let row4=[
        KeySpec(label:"Z",code:6),KeySpec(label:"X",code:7),KeySpec(label:"C",code:8),KeySpec(label:"V",code:9),
        KeySpec(label:"B",code:11),KeySpec(label:"N",code:45),KeySpec(label:"M",code:46),KeySpec(label:",",code:43),
        KeySpec(label:".",code:47),KeySpec(label:"/",code:44)
    ]

    var body:some View {
        VStack(spacing:7) {
            keyRow(row1)
            keyRow(row2)
            HStack(spacing:7) {
                toggle("caps",active:caps){caps.toggle();send(57,flags)}
                keyRow(row3)
            }
            HStack(spacing:7) {
                toggle("⇧",active:shift){shift.toggle()}
                keyRow(row4)
                key("↑",126)
                toggle("⇧",active:shift){shift.toggle()}
            }
            HStack(spacing:7) {
                toggle("control",active:control){control.toggle()}
                toggle("option",active:option){option.toggle()}
                toggle("⌘",active:command){command.toggle()}
                key("space",49,width:5.5)
                toggle("⌘",active:command){command.toggle()}
                toggle("option",active:option){option.toggle()}
                key("←",123); key("↓",125); key("→",124)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:18,style:.continuous))
    }

    private var flags:UInt64 {
        var f:UInt64=0
        if caps { f |= 1 << 16 }
        if shift { f |= 1 << 17 }
        if control { f |= 1 << 18 }
        if option { f |= 1 << 19 }
        if command { f |= 1 << 20 }
        return f
    }

    @ViewBuilder private func keyRow(_ keys:[KeySpec])->some View {
        HStack(spacing:7) { ForEach(keys){k in key(k.label,k.code,width:k.width)} }
    }

    private func key(_ label:String,_ code:UInt16,width:CGFloat=1)->some View {
        Button {
            send(code,flags)
            if shift { shift=false }
        } label: {
            Text(label).font(.system(size:16,weight:.medium,design:.rounded))
                .frame(maxWidth:.infinity,maxHeight:.infinity)
        }
        .buttonStyle(KeyboardKeyStyle())
        .frame(minWidth:38*width,idealWidth:52*width,maxWidth:70*width,minHeight:42)
    }

    private func toggle(_ label:String,active:Bool,action:@escaping()->Void)->some View {
        Button(action:action) {
            Text(label).font(.system(size:14,weight:.semibold,design:.rounded))
                .frame(maxWidth:.infinity,maxHeight:.infinity)
        }
        .buttonStyle(KeyboardKeyStyle(active:active))
        .frame(minWidth:58,minHeight:42)
    }
}

private struct KeyboardKeyStyle:ButtonStyle {
    var active=false
    func makeBody(configuration:Configuration)->some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(active ? Color.accentColor.opacity(0.75) : Color.white.opacity(configuration.isPressed ? 0.22 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius:9,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:9,style:.continuous).stroke(Color.white.opacity(0.12),lineWidth:1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration:0.06),value:configuration.isPressed)
    }
}
