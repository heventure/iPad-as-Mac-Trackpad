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
      Text(peer.statusText).font(.subheadline).foregroundStyle(peer.connectedPeerName == nil ? Color.secondary : Color.green)
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
      if swapped {
       keyboard(compact:true).frame(width:max(560,geo.size.width*0.66))
       trackpad.frame(minWidth:220)
      } else {
       trackpad.frame(minWidth:220)
       keyboard(compact:true).frame(width:max(560,geo.size.width*0.66))
      }
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
  GeometryReader { geo in
   let unit=max(18,(geo.size.width-gap*15)/15.5)
   VStack(spacing:gap) {
    functionRow(unit:unit)
    keyboardRow(number,unit:unit)
    HStack(spacing:gap){ForEach(qwerty){k in fixedKey(k,unit:unit)}}
    HStack(spacing:gap){
     modifierKey("caps",active:caps,units:1.75,unit:unit){caps.toggle();send(57,flags)}
     ForEach(home){k in fixedKey(k,unit:unit)}
    }
    HStack(spacing:gap){
     modifierKey("shift",active:shift,units:2.25,unit:unit){shift.toggle()}
     ForEach(bottom){k in fixedKey(k,unit:unit)}
     modifierKey("shift",active:shift,units:2.25,unit:unit){shift.toggle()}
    }
    HStack(spacing:gap){
     fixedKey(KeySpec(label:"fn",code:63,width:0.8),unit:unit)
     modifierKey("control",active:control,units:1.15,unit:unit){control.toggle()}
     modifierKey("option",active:option,units:1.15,unit:unit){option.toggle()}
     modifierKey("⌘",active:command,units:1.2,unit:unit){command.toggle()}
     fixedKey(KeySpec(label:"",code:49,width:4.2),unit:unit)
     modifierKey("⌘",active:command,units:1.2,unit:unit){command.toggle()}
     modifierKey("option",active:option,units:1.15,unit:unit){option.toggle()}
     arrowCluster(unit:unit)
    }
   }
   .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
   .padding(compact ? 7:10)
   .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:18,style:.continuous))
  }
  .frame(height:compact ? 230:340)
 }

 private func functionRow(unit:CGFloat)->some View {
  HStack(spacing:gap) {
   flexibleKey("esc",code:53)
   ForEach(1...12,id:\.self){n in flexibleKey("F\(n)",code:functionCode(n),small:true)}
  }
  .frame(maxWidth:.infinity)
 }

 private func keyboardRow(_ keys:[KeySpec],unit:CGFloat)->some View {
  HStack(spacing:gap){ForEach(keys){k in fixedKey(k,unit:unit)}}
 }

 private func flexibleKey(_ label:String,code:UInt16,small:Bool=false)->some View {
  Button{send(code,flags);if shift{shift=false}} label:{
   Text(label).font(.system(size:compact ? (small ? 9:11):(small ? 11:15),weight:.medium,design:.rounded))
    .frame(maxWidth:.infinity,maxHeight:.infinity)
  }
  .buttonStyle(KeyboardKeyStyle())
  .frame(maxWidth:.infinity,minHeight:height,maxHeight:height)
 }

 private func arrowCluster(unit:CGFloat)->some View {
  VStack(spacing:2) {
   fixedKey(KeySpec(label:"↑",code:126),unit:unit)
    .frame(height:(height-2)/2)
   HStack(spacing:2) {
    fixedKey(KeySpec(label:"←",code:123),unit:unit)
    fixedKey(KeySpec(label:"↓",code:125),unit:unit)
    fixedKey(KeySpec(label:"→",code:124),unit:unit)
   }
   .frame(height:(height-2)/2)
  }
  .frame(width:unit*3+4,height:height)
 }

 private func fixedKey(_ spec:KeySpec,unit:CGFloat,small:Bool=false)->some View {
  Button{send(spec.code,flags);if shift{shift=false}} label:{
   Text(spec.label).font(.system(size:compact ? (small ? 9:11):(small ? 11:15),weight:.medium,design:.rounded))
    .frame(maxWidth:.infinity,maxHeight:.infinity)
  }
  .buttonStyle(KeyboardKeyStyle())
  .frame(width:max(20,unit*spec.width+gap*(spec.width-1)),height:height)
 }

 private func modifierKey(_ label:String,active:Bool,units:CGFloat,unit:CGFloat,action:@escaping()->Void)->some View {
  Button(action:action){Text(label).font(.system(size:compact ? 10:13,weight:.semibold,design:.rounded)).frame(maxWidth:.infinity,maxHeight:.infinity)}
   .buttonStyle(KeyboardKeyStyle(active:active))
   .frame(width:max(24,unit*units+gap*(units-1)),height:height)
 }

 private var gap:CGFloat { compact ? 4 : 7 }
 private var height:CGFloat { compact ? 31 : 42 }

 private var flags:UInt64 {
  var f:UInt64=0
  if caps { f |= 1 << 16 }
  if shift { f |= 1 << 17 }
  if control { f |= 1 << 18 }
  if option { f |= 1 << 19 }
  if command { f |= 1 << 20 }
  return f
 }

 private func functionCode(_ n:Int)->UInt16 {
  [122,120,99,118,96,97,98,100,101,109,103,111][n-1]
 }
}

private struct KeyboardKeyStyle:ButtonStyle {
 var active=false
 func makeBody(configuration:Configuration)->some View {
  configuration.label
   .foregroundStyle(Color.primary)
   .background(active ? Color.accentColor.opacity(0.75) : Color.white.opacity(configuration.isPressed ? 0.22 : 0.12))
   .clipShape(RoundedRectangle(cornerRadius:7,style:.continuous))
   .overlay(RoundedRectangle(cornerRadius:7,style:.continuous).stroke(Color.white.opacity(0.12),lineWidth:1))
   .scaleEffect(configuration.isPressed ? 0.96 : 1)
   .animation(.easeOut(duration:0.06),value:configuration.isPressed)
 }
}

