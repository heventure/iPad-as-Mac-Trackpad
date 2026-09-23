import SwiftUI
import UIKit

struct iPadTrackpadView:View {
 @ObservedObject var peer:iPadPeerSender
 @State private var sensitivity=1.2
 @State private var mode=0
 @State private var swapped=false
 @State private var landscapeKeyboardShare:CGFloat=0.618
 @State private var portraitTrackpadShare:CGFloat=0.618
 @State private var joystickArrows=false

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
      Toggle(isOn:$joystickArrows) {
       Label("摇杆",systemImage:"dot.circle.and.hand.point.up.left.fill")
      }
      .toggleStyle(.button)
      .buttonStyle(.bordered)
      .accessibilityLabel("方向键与八向摇杆切换")
      Button { withAnimation(.snappy){swapped.toggle()} } label:{Image(systemName:"arrow.left.arrow.right").font(.title3)}
       .buttonStyle(.bordered).accessibilityLabel("交换触控板和键盘")
     }
     Circle().fill(peer.connectedPeerName == nil ? .orange:.green).frame(width:12,height:12)
    }
    Picker("模式",selection:$mode){Text("触控板").tag(0);Text("触控板 + 键盘").tag(1)}.pickerStyle(.segmented)

    if mode==0 {
     trackpad
    } else {
     AdaptiveInputSplit(
      landscape:landscape,
      swapped:swapped,
      landscapeKeyboardShare:$landscapeKeyboardShare,
      portraitTrackpadShare:$portraitTrackpadShare,
      trackpad:{trackpad},
      keyboard:{keyboard(compact:landscape)}
     )
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
  MacKeyboard(compact:compact,joystickArrows:joystickArrows){code,flags in peer.send(.key(code,flags))}
   .frame(maxWidth:.infinity,maxHeight:.infinity)
   .layoutPriority(1)
 }
}

private struct AdaptiveInputSplit<Trackpad:View,Keyboard:View>:View {
 let landscape:Bool
 let swapped:Bool
 @Binding var landscapeKeyboardShare:CGFloat
 @Binding var portraitTrackpadShare:CGFloat
 @ViewBuilder let trackpad:()->Trackpad
 @ViewBuilder let keyboard:()->Keyboard
 @State private var dragging=false

 var body:some View {
  GeometryReader { geo in
   if landscape {
    let divider:CGFloat=18
    let available=max(1,geo.size.width-divider)
    let keyboardWidth=available*landscapeKeyboardShare
    let trackpadWidth=available-keyboardWidth
    HStack(spacing:0) {
     if swapped {
      keyboard().frame(width:keyboardWidth,height:geo.size.height)
      dragHandle(horizontal:false,total:available)
      trackpad().frame(width:trackpadWidth,height:geo.size.height)
     } else {
      trackpad().frame(width:trackpadWidth,height:geo.size.height)
      dragHandle(horizontal:false,total:available)
      keyboard().frame(width:keyboardWidth,height:geo.size.height)
     }
    }.transaction { if dragging { $0.animation=nil } }
   } else {
    let divider:CGFloat=18
    let available=max(1,geo.size.height-divider)
    let trackpadHeight=available*portraitTrackpadShare
    let keyboardHeight=available-trackpadHeight
    VStack(spacing:0) {
     if swapped {
      keyboard().frame(width:geo.size.width,height:keyboardHeight)
      dragHandle(horizontal:true,total:available)
      trackpad().frame(width:geo.size.width,height:trackpadHeight)
     } else {
      trackpad().frame(width:geo.size.width,height:trackpadHeight)
      dragHandle(horizontal:true,total:available)
      keyboard().frame(width:geo.size.width,height:keyboardHeight)
     }
    }.transaction { if dragging { $0.animation=nil } }
   }
  }
  .coordinateSpace(name:"inputSplit")
 }

 private func dragHandle(horizontal:Bool,total:CGFloat)->some View {
  ZStack {
   Color.clear
   Capsule().fill(Color.secondary.opacity(0.55))
    .frame(width:horizontal ? 48:4,height:horizontal ? 4:48)
  }
  .frame(width:horizontal ? nil:18,height:horizontal ? 18:nil)
  .contentShape(Rectangle())
  .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("inputSplit"))
   .onChanged { value in
    dragging=true
    if landscape {
     let dividerX=min(total,max(0,value.location.x))
     let keyboardWidth=swapped ? dividerX:(total-dividerX)
     landscapeKeyboardShare=min(0.72,max(0.52,keyboardWidth/total))
    } else {
     let dividerY=min(total,max(0,value.location.y))
     let trackpadHeight=swapped ? (total-dividerY):dividerY
     portraitTrackpadShare=min(0.72,max(0.50,trackpadHeight/total))
    }
   }
   .onEnded { _ in dragging=false }
  )
  .accessibilityLabel("调整触控板和键盘比例")
 }
}

private struct KeySpec:Identifiable {
 let id=UUID();let label:String;let code:UInt16;var width:CGFloat=1
}

private struct MacKeyboard:View {
 let compact:Bool
 let joystickArrows:Bool
 let send:(UInt16,UInt64)->Void
 @State private var shift=false
 @State private var control=false
 @State private var option=false
 @State private var command=false
 @State private var caps=false

 private let number=[
  KeySpec(label:"`  ~",code:50),KeySpec(label:"1",code:18),KeySpec(label:"2",code:19),KeySpec(label:"3",code:20),KeySpec(label:"4",code:21),
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
   let padding:CGFloat=compact ? 7:10
   let usableHeight=max(120,geo.size.height-padding*2)
   let gap=max(3,min(7,usableHeight*0.018))
   // Six rows total: five normal rows + one taller bottom row.
   // Portrait needs two full letter-height square arrow keys stacked vertically.
   let bottomScale:CGFloat=compact ? 1.6 : 2.08
   let keyHeight=max(22,(usableHeight-gap*5)/(5+bottomScale))
   let bottomHeight=keyHeight*bottomScale
   let usableWidth=max(200,geo.size.width-padding*2)
   let unit=max(16,(usableWidth-gap*15)/15.5)
   let font=max(9,min(15,keyHeight*0.34))
   VStack(spacing:gap) {
    functionRow(unit:unit,height:keyHeight,gap:gap,font:font)
    keyboardRow(number,unit:unit,height:keyHeight,gap:gap,font:font)
    HStack(spacing:gap){ForEach(qwerty){k in flexibleSpecKey(k,height:keyHeight,font:font)}}
    HStack(spacing:gap){
     modifierKey("caps",active:caps,units:1.75,unit:unit,height:keyHeight,gap:gap,font:font){caps.toggle();send(57,flags)}
     ForEach(home){k in flexibleSpecKey(k,height:keyHeight,font:font)}
    }
    HStack(spacing:gap){
     modifierKey("shift",active:shift,units:2.25,unit:unit,height:keyHeight,gap:gap,font:font){shift.toggle()}
     ForEach(bottom){k in flexibleSpecKey(k,height:keyHeight,font:font)}
     modifierKey("shift",active:shift,units:2.25,unit:unit,height:keyHeight,gap:gap,font:font){shift.toggle()}
    }
    bottomRow(totalWidth:usableWidth,height:bottomHeight,letterHeight:keyHeight,gap:gap,font:font,minArrowScale:compact ? 0.8 : 1.0)
   }
   .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
   .padding(padding)
   .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:18,style:.continuous))
  }
 }

 private func functionRow(unit:CGFloat,height:CGFloat,gap:CGFloat,font:CGFloat)->some View {
  HStack(spacing:gap) {
   flexibleKey("esc",code:53,height:height,font:font)
   ForEach(1...12,id:\.self){n in flexibleKey("F\(n)",code:functionCode(n),height:height,font:font*0.82)}
  }.frame(maxWidth:.infinity)
 }

 private func keyboardRow(_ keys:[KeySpec],unit:CGFloat,height:CGFloat,gap:CGFloat,font:CGFloat)->some View {
  HStack(spacing:gap){ForEach(keys){k in flexibleSpecKey(k,height:height,font:font)}}
 }

 private func flexibleKey(_ label:String,code:UInt16,height:CGFloat,font:CGFloat)->some View {
  Button{keyFeedback();send(code,flags);if shift{shift=false}} label:{
   Text(label).font(.system(size:font,weight:.medium,design:.rounded)).frame(maxWidth:.infinity,maxHeight:.infinity)
  }.buttonStyle(KeyboardKeyStyle()).frame(maxWidth:.infinity).frame(height:height)
 }

 private func bottomRow(totalWidth:CGFloat,height:CGFloat,letterHeight:CGFloat,gap:CGFloat,font:CGFloat,minArrowScale:CGFloat)->some View {
  // Arrow keys must stay easy to hit: each arrow is at least 0.8x a letter-key height,
  // and is square whenever the bottom row has enough height.
  // Two square arrow keys stack vertically, so the row itself is tall enough
  // for the complete inverted-T cluster. Each arrow is >= 0.8x letter height.
  let availableSide=max(1,(height-3)/2)
  let arrowSide=min(availableSide,max(letterHeight*minArrowScale,min(letterHeight,availableSide)))
  let arrowWidth=arrowSide*3+6
  let gaps=gap*7
  let remaining=max(1,totalWidth-arrowWidth-gaps)

  // Explicit widths prevent the space bar from starving the modifier keys.
  let weightTotal:CGFloat=12.2
  let u=remaining/weightTotal
  return HStack(spacing:gap) {
   bottomFixedKey("fn",code:63,width:u*1.25,height:height,font:font)
   bottomFixedModifier("ctrl",active:control,width:u*1.35,height:height,font:font){control.toggle()}
   bottomFixedModifier("⌥",active:option,width:u*1.25,height:height,font:font){option.toggle()}
   bottomFixedModifier("⌘",active:command,width:u*1.35,height:height,font:font){command.toggle()}
   bottomFixedKey("",code:49,width:u*3.8,height:height,font:font)
   bottomFixedModifier("⌘",active:command,width:u*1.35,height:height,font:font){command.toggle()}
   bottomFixedModifier("⌥",active:option,width:u*1.25,height:height,font:font){option.toggle()}
   if joystickArrows {
    EightWayArrowJoystick(width:arrowWidth,height:height,send:send,flags:flags)
   } else {
    arrowCluster(side:arrowSide,height:height,font:font)
   }
  }
  .frame(width:totalWidth,height:height)
 }

 private func arrowCluster(side:CGFloat,height:CGFloat,font:CGFloat)->some View {
  // ↑ sits over ↓. The whole cluster is contained by the bottom row.
  return ZStack(alignment:.bottom) {
   HStack(spacing:3) {
    arrowKey("←",code:123,width:side,height:side,font:font)
    arrowKey("↓",code:125,width:side,height:side,font:font)
    arrowKey("→",code:124,width:side,height:side,font:font)
   }
   arrowKey("↑",code:126,width:side,height:side,font:font)
    .offset(y:-(side+3))
  }
  .frame(width:side*3+6,height:height,alignment:.bottom)
 }

 private func arrowKey(_ label:String,code:UInt16,width:CGFloat,height:CGFloat,font:CGFloat)->some View {
  Button{keyFeedback();send(code,flags)} label:{Text(label).font(.system(size:font,weight:.medium)).frame(maxWidth:.infinity,maxHeight:.infinity)}
   .buttonStyle(KeyboardKeyStyle()).frame(width:width,height:height)
 }

 private func bottomFixedKey(_ label:String,code:UInt16,width:CGFloat,height:CGFloat,font:CGFloat)->some View {
  Button{keyFeedback();send(code,flags);if shift{shift=false}} label:{
   Text(label).font(.system(size:font,weight:.medium,design:.rounded)).lineLimit(1).frame(maxWidth:.infinity,maxHeight:.infinity)
  }
  .buttonStyle(KeyboardKeyStyle())
  .frame(width:width,height:height)
 }

 private func bottomFixedModifier(_ label:String,active:Bool,width:CGFloat,height:CGFloat,font:CGFloat,action:@escaping()->Void)->some View {
  Button(action:{keyFeedback();action()}) {
   Text(label).font(.system(size:font*0.9,weight:.semibold,design:.rounded)).lineLimit(1).frame(maxWidth:.infinity,maxHeight:.infinity)
  }
  .buttonStyle(KeyboardKeyStyle(active:active))
  .frame(width:width,height:height)
 }

 private func flexibleSpecKey(_ spec:KeySpec,height:CGFloat,font:CGFloat)->some View {
  Button{keyFeedback();send(spec.code,flags);if shift{shift=false}} label:{
   Text(spec.label).font(.system(size:font,weight:.medium,design:.rounded)).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth:.infinity,maxHeight:.infinity)
  }
  .buttonStyle(KeyboardKeyStyle())
  .frame(maxWidth:.infinity,minHeight:height,maxHeight:height)
 }

 private func keyFeedback() {
  UIImpactFeedbackGenerator(style:.light).impactOccurred(intensity:0.65)
 }

 private func fixedKey(_ spec:KeySpec,unit:CGFloat,height:CGFloat,gap:CGFloat,font:CGFloat)->some View {
  Button{keyFeedback();send(spec.code,flags);if shift{shift=false}} label:{
   Text(spec.label).font(.system(size:font,weight:.medium,design:.rounded)).frame(maxWidth:.infinity,maxHeight:.infinity)
  }.buttonStyle(KeyboardKeyStyle())
   .frame(width:max(18,unit*spec.width+gap*(spec.width-1)),height:height)
 }

 private func modifierKey(_ label:String,active:Bool,units:CGFloat,unit:CGFloat,height:CGFloat,gap:CGFloat,font:CGFloat,action:@escaping()->Void)->some View {
  Button(action:{keyFeedback();action()}){Text(label).font(.system(size:font*0.9,weight:.semibold,design:.rounded)).frame(maxWidth:.infinity,maxHeight:.infinity)}
   .buttonStyle(KeyboardKeyStyle(active:active))
   .frame(width:max(22,unit*units+gap*(units-1)),height:height)
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

 private func functionCode(_ n:Int)->UInt16 {
  [122,120,99,118,96,97,98,100,101,109,103,111][n-1]
 }
}


private struct EightWayArrowJoystick:View {
 let width:CGFloat
 let height:CGFloat
 let send:(UInt16,UInt64)->Void
 let flags:UInt64
 @State private var knob=CGSize.zero
 @State private var lastDirection:Int?
 @State private var lastSentAt=Date.distantPast

 var body:some View {
  GeometryReader { geo in
   let diameter=min(geo.size.width,geo.size.height)
   let knobSize=max(18,diameter*0.34)
   let radius=max(1,(diameter-knobSize)/2-3)
   ZStack {
    Circle()
     .fill(Color.white.opacity(0.08))
     .overlay(Circle().stroke(Color.white.opacity(0.16),lineWidth:1))
    ForEach(0..<8,id:\.self) { i in
     Image(systemName:"triangle.fill")
      .font(.system(size:max(7,diameter*0.08),weight:.bold))
      .foregroundStyle(Color.secondary.opacity(0.7))
      .offset(y:-diameter*0.34)
      .rotationEffect(.degrees(Double(i)*45))
    }
    Circle()
     .fill(Color.white.opacity(0.22))
     .overlay(Circle().stroke(Color.white.opacity(0.24),lineWidth:1))
     .frame(width:knobSize,height:knobSize)
     .offset(knob)
   }
   .frame(width:diameter,height:diameter)
   .position(x:geo.size.width/2,y:geo.size.height/2)
   .contentShape(Rectangle())
   .gesture(
    DragGesture(minimumDistance:0)
     .onChanged { value in
      let center=CGPoint(x:geo.size.width/2,y:geo.size.height/2)
      let dx=value.location.x-center.x
      let dy=value.location.y-center.y
      let distance=sqrt(dx*dx+dy*dy)
      let scale=distance > radius ? radius/distance : 1
      knob=CGSize(width:dx*scale,height:dy*scale)
      guard distance > max(10,diameter*0.12) else { lastDirection = nil;return }
      let angle=atan2(dy,dx)
      var sector=Int(round(angle/(.pi/4)))
      if sector < 0 { sector += 8 }
      if sector != lastDirection || Date().timeIntervalSince(lastSentAt) > 0.11 {
       sendDirection(sector)
       lastDirection=sector
       lastSentAt=Date()
       UIImpactFeedbackGenerator(style:.light).impactOccurred(intensity:0.55)
      }
     }
     .onEnded { _ in
      knob = .zero
      lastDirection = nil
     }
   )
  }
  .frame(width:width,height:height)
  .accessibilityLabel("八向方向摇杆")
 }

 private func sendDirection(_ direction:Int) {
  // atan2 sectors: right, down-right, down, down-left, left, up-left, up, up-right.
  switch direction {
  case 0: send(124,flags)
  case 1: send(125,flags);send(124,flags)
  case 2: send(125,flags)
  case 3: send(125,flags);send(123,flags)
  case 4: send(123,flags)
  case 5: send(126,flags);send(123,flags)
  case 6: send(126,flags)
  default: send(126,flags);send(124,flags)
  }
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

