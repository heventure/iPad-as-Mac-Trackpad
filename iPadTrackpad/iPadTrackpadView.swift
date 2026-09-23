import SwiftUI
import UIKit

struct iPadTrackpadView:View {
 @ObservedObject var peer:iPadPeerSender
 @State private var sensitivity=1.2
 @State private var mode=0
 @State private var swapped=false

 var body:some View {
  GeometryReader { geo in
   let landscape=geo.size.width>geo.size.height
   VStack(spacing:12) {
    HStack {
     VStack(alignment:.leading,spacing:3) {
      Text("iPad Remote").font(.title2.bold())
      Text(peer.statusText).font(.subheadline).foregroundStyle(peer.connectedPeerName == nil ? .secondary:.green)
      Text(peer.realtimeStatus).font(.system(.caption,design:.monospaced)).foregroundStyle(.cyan)
     }
     Spacer()
     if mode==1 {
      Button { withAnimation(.snappy){swapped.toggle()} } label:{Image(systemName:"arrow.left.arrow.right").font(.title3)}
       .buttonStyle(.bordered).accessibilityLabel("交换触控板和键盘")
     }
     Circle().fill(peer.connectedPeerName == nil ? .orange:.green).frame(width:12,height:12)
    }
    Picker("模式",selection:$mode){Text("触控板").tag(0);Text("触控板 + 键盘").tag(1)}.pickerStyle(.segmented)

    if mode==0 {
     trackpad
    } else if landscape {
     HStack(spacing:12) {
      if swapped { keyboard(compact:true); trackpad } else { trackpad; keyboard(compact:true) }
     }
    } else {
     VStack(spacing:12) {
      if swapped { keyboard(compact:false); trackpad } else { trackpad; keyboard(compact:false) }
     }
    }

    HStack(spacing:12) {
     Image(systemName:"tortoise");Slider(value:$sensitivity,in:0.5...2.5,step:0.1);Image(systemName:"hare")
     Text(String(format:"%.1fx",sensitivity)).font(.system(.footnote,design:.monospaced)).frame(width:42)
    }.foregroundStyle(.secondary)
   }.padding(landscape ? 16:20).background(Color.black.ignoresSafeArea())
  }
 }

 private var trackpad:some View {
  TrackpadSurface(sensitivity:sensitivity,onMessage:peer.send,onRawMove:peer.sendPointerUDP)
   .frame(maxWidth:.infinity,maxHeight:.infinity)
   .overlay(alignment:.bottomLeading){
    Text("单指移动 · 轻点左键 · 双指轻点右键 · 双指滚动").font(.footnote).foregroundStyle(.secondary).padding(16).allowsHitTesting(false)
   }
 }

 private func keyboard(compact:Bool)->some View {
  MacKeyboard(compact:compact){code,flags in peer.send(.key(code,flags))}
   .frame(maxWidth:.infinity)
   .layoutPriority(1)
 }
}

private struct KeySpec:Identifiable {
 let id=UUID();let label:String;let code:UInt16;var width:CGFloat=1
}

private struct MacKeyboard:View {
 let compact:Bool
 let send:(UInt16,UInt64)->Void
 @State private var shift=false
 @State private var control=false
 @State private var option=false
 @State private var command=false
 @State private var caps=false

 private let number=[
  KeySpec(label:"esc",code:53),KeySpec(label:"1",code:18),KeySpec(label:"2",code:19),KeySpec(label:"3",code:20),KeySpec(label:"4",code:21),
  KeySpec(label:"5",code:23),KeySpec(label:"6",code:22),KeySpec(label:"7",code:26),KeySpec(label:"8",code:28),KeySpec(label:"9",code:25),
  KeySpec(label:"0",code:29),KeySpec(label:"-",code:27),KeySpec(label:"=",code:24),KeySpec(label:"⌫",code:51,width:1.45)
 ]
 private let qwerty=[
  KeySpec(label:"tab",code:48,width:1.3),KeySpec(label:"Q",code:12),KeySpec(label:"W",code:13),KeySpec(label:"E",code:14),KeySpec(label:"R",code:15),
  KeySpec(label:"T",code:17),KeySpec(label:"Y",code:16),KeySpec(label:"U",code:32),KeySpec(label:"I",code:34),KeySpec(label:"O",code:31),KeySpec(label:"P",code:35),
  KeySpec(label:"[",code:33),KeySpec(label:"]",code:30),KeySpec(label:"\\",code:42,width:1.15)
 ]
 private let home=[
  KeySpec(label:"A",code:0),KeySpec(label:"S",code:1),KeySpec(label:"D",code:2),KeySpec(label:"F",code:3),KeySpec(label:"G",code:5),KeySpec(label:"H",code:4),
  KeySpec(label:"J",code:38),KeySpec(label:"K",code:40),KeySpec(label:"L",code:37),KeySpec(label:";",code:41),KeySpec(label:"'",code:39),KeySpec(label:"return",code:36,width:1.7)
 ]
 private let bottom=[
  KeySpec(label:"Z",code:6),KeySpec(label:"X",code:7),KeySpec(label:"C",code:8),KeySpec(label:"V",code:9),KeySpec(label:"B",code:11),
  KeySpec(label:"N",code:45),KeySpec(label:"M",code:46),KeySpec(label:",",code:43),KeySpec(label:".",code:47),KeySpec(label:"/",code:44)
 ]

 var body:some View {
  VStack(spacing:gap) {
   functionRow
   row(number)
   row(qwerty)
   HStack(spacing:gap){toggle("caps",active:caps,width:1.6){caps.toggle();send(57,flags)};row(home)}
   HStack(spacing:gap){toggle("shift",active:shift,width:1.7){shift.toggle()};row(bottom);toggle("shift",active:shift,width:1.7){shift.toggle()}}
   HStack(spacing:gap){
    key("fn",63,width:.8);toggle("control",active:control){control.toggle()};toggle("option",active:option){option.toggle()}
    toggle("⌘",active:command){command.toggle()};key("",49,width:4.7);toggle("⌘",active:command){command.toggle()}
    toggle("option",active:option){option.toggle()};key("←",123);key("↓",125);key("↑",126);key("→",124)
   }
  }
  .padding(compact ? 7:10)
  .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:18,style:.continuous))
 }

 private var functionRow:some View {
  HStack(spacing:gap) {
   key("esc",53)
   ForEach(1...12,id:\.self){n in key("F\(n)",functionCode(n),small:true)}
  }
 }

 private var gap:CGFloat { compact ? 4:7 }
 private var height:CGFloat { compact ? 31:42 }
 private var flags:UInt64 {
  var f:UInt64=0;if caps{f|=1<<16};if shift{f|=1<<17};if control{f|=1<<18};if option{f|=1<<19};if command{f|=1<<20};return f
 }
 private func functionCode(_ n:Int)->UInt16 { [122,120,99,118,96,97,98,100,101,109,103,111][n-1] }

 @ViewBuilder private func row(_ keys:[KeySpec])->some View {
  HStack(spacing:gap){ForEach(keys){k in key(k.label,k.code,width:k.width)}}
 }
 private func key(_ label:String,_ code:UInt16,width:CGFloat=1,small:Bool=false)->some View {
  Button{send(code,flags);if shift{shift=false}} label:{
   Text(label).font(.system(size:compact ? (small ? 9:11):(small ? 11:15),weight:.medium,design:.rounded)).frame(maxWidth:.infinity,maxHeight:.infinity)
  }.buttonStyle(KeyboardKeyStyle()).frame(minWidth:(compact ? 23:34)*width,minHeight:height,maxHeight:height)
 }
 private func toggle(_ label:String,active:Bool,width:CGFloat=1,action:@escaping()->Void)->some View {
  Button(action:action){Text(label).font(.system(size:compact ? 10:13,weight:.semibold,design:.rounded)).frame(maxWidth:.infinity,maxHeight:.infinity)}
   .buttonStyle(KeyboardKeyStyle(active:active)).frame(minWidth:(compact ? 30:50)*width,minHeight:height,maxHeight:height)
 }
}

private struct KeyboardKeyStyle:ButtonStyle {
 var active=false
 func makeBody(configuration:Configuration)->some View {
  configuration.label.foregroundStyle(.primary)
   .background(active ? Color.accentColor.opacity(.75):Color.white.opacity(configuration.isPressed ? .22:.12))
   .clipShape(RoundedRectangle(cornerRadius:7,style:.continuous))
   .overlay(RoundedRectangle(cornerRadius:7,style:.continuous).stroke(Color.white.opacity(.12),lineWidth:1))
   .scaleEffect(configuration.isPressed ? .96:1).animation(.easeOut(duration:.06),value:configuration.isPressed)
 }
}
