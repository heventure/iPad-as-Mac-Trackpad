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
 @State private var pointerJoystick=false

 var body:some View {
  GeometryReader { geo in
   let landscape=geo.size.width>geo.size.height
   VStack(spacing:12) {
    HStack {
     VStack(alignment:.leading,spacing:3) {
      Text("iPad Remote").font(.title2.bold())
      if let connected=peer.connectedPeerName {
       Label("当前 Mac：\(connected)",systemImage:"desktopcomputer")
        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.green)
      } else {
       Text(peer.statusText).font(.subheadline).foregroundStyle(Color.secondary)
      }
      Text(peer.realtimeStatus).font(.system(.caption,design:.monospaced)).foregroundStyle(.cyan)
     }
     Spacer()
     if !peer.discoveredMacNames.isEmpty {
      Menu {
       ForEach(peer.discoveredMacNames,id:\.self) { name in
        Button {
         peer.selectMac(named:name)
        } label: {
         HStack {
          Text(name)
          if peer.connectedPeerName==name {Image(systemName:"checkmark")}
          else if peer.preferredMacName==name {Image(systemName:"star.fill")}
         }
        }
       }
      } label: {
       Label("Mac",systemImage:"desktopcomputer")
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("选择 Mac")
     }
     if mode==1 {
      Toggle(isOn:$pointerJoystick) {
       Label("指针摇杆",systemImage:"scope")
      }
      .toggleStyle(.button)
      .buttonStyle(.bordered)
      .accessibilityLabel("触控板与指针摇杆切换")
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
      trackpad:{pointerSurface},
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

 @ViewBuilder private var pointerSurface:some View {
  if pointerJoystick {
   AnalogPointerJoystick(sensitivity:sensitivity){vx,vy in peer.sendAnalogPointerUDP(vx:vx,vy:vy)}
    .frame(maxWidth:.infinity,maxHeight:.infinity)
  } else {
   trackpad
  }
 }

 private var trackpad:some View {
  TrackpadSurface(sensitivity:sensitivity,onMessage:peer.send,onRawMove:peer.sendPointerUDP)
   .frame(maxWidth:.infinity,maxHeight:.infinity)
   .overlay(alignment:.bottomLeading){
    if mode==0 {
     Text("单指移动 · 轻点左键 · 双指轻点右键 · 双指滚动").font(.footnote).foregroundStyle(.secondary).padding(16).allowsHitTesting(false)
    }
   }
   .clipped()
 }

 private func keyboard(compact:Bool)->some View {
  MacKeyboard(compact:compact,joystickArrows:joystickArrows){code,flags,isDown in peer.send(.key(code,flags,isDown))}
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
 let send:(UInt16,UInt64,Bool)->Void
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
     modifierKey("caps",active:caps,units:1.75,unit:unit,height:keyHeight,gap:gap,font:font){caps.toggle();tapKey(57,flags)}
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
  KeyLifecycleButton(code:code,flags:flags,send:send,accessibilityLabel:label,onPress:{keyFeedback();if shift{shift=false}}) {
   Text(label).font(.system(size:font,weight:.medium,design:.rounded)).frame(maxWidth:.infinity,maxHeight:.infinity)
  }.frame(maxWidth:.infinity).frame(height:height)
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
  KeyLifecycleButton(code:code,flags:flags,send:send,accessibilityLabel:label,onPress:keyFeedback) {
   Text(label).font(.system(size:font,weight:.medium)).frame(maxWidth:.infinity,maxHeight:.infinity)
  }.frame(width:width,height:height)
 }

 private func bottomFixedKey(_ label:String,code:UInt16,width:CGFloat,height:CGFloat,font:CGFloat)->some View {
  KeyLifecycleButton(code:code,flags:flags,send:send,accessibilityLabel:label.isEmpty ? "空格" : label,onPress:{keyFeedback();if shift{shift=false}}) {
   Text(label).font(.system(size:font,weight:.medium,design:.rounded)).lineLimit(1).frame(maxWidth:.infinity,maxHeight:.infinity)
  }
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
  KeyLifecycleButton(code:spec.code,flags:flags,send:send,accessibilityLabel:spec.label,onPress:{keyFeedback();if shift{shift=false}}) {
   Text(spec.label).font(.system(size:font,weight:.medium,design:.rounded)).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth:.infinity,maxHeight:.infinity)
  }
  .frame(maxWidth:.infinity,minHeight:height,maxHeight:height)
 }

 private func keyFeedback() {
  UIImpactFeedbackGenerator(style:.light).impactOccurred(intensity:0.65)
 }

 private func tapKey(_ code:UInt16,_ rawFlags:UInt64) {
  send(code,rawFlags,true)
  send(code,rawFlags,false)
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


private struct AnalogPointerJoystick:View {
 let sensitivity:Double
 let send:(Double,Double)->Void
 @State private var knob=CGSize.zero
 @State private var velocity=CGVector.zero
 @State private var timer:Timer?
 private let deadZone:CGFloat=0.14

 var body:some View {
  GeometryReader { geo in
   let diameter=max(120,min(geo.size.width,geo.size.height)*0.72)
   let knobSize=max(54,diameter*0.28)
   let radius=max(1,(diameter-knobSize)/2-8)
   ZStack {
    RoundedRectangle(cornerRadius:18,style:.continuous).fill(Color.white.opacity(0.035))
    Circle()
     .fill(Color.white.opacity(0.08))
     .overlay(Circle().stroke(Color.white.opacity(0.16),lineWidth:1))
     .frame(width:diameter,height:diameter)
    Circle()
     .stroke(Color.white.opacity(0.12),style:StrokeStyle(lineWidth:1,dash:[5,5]))
     .frame(width:diameter*deadZone*2,height:diameter*deadZone*2)
    ForEach(0..<8,id:\.self) { i in
     Image(systemName:"triangle.fill")
      .font(.system(size:max(8,diameter*0.035),weight:.bold))
      .foregroundStyle(Color.secondary.opacity(0.55))
      .offset(y:-diameter*0.42)
      .rotationEffect(.degrees(Double(i)*45))
    }
    Circle()
     .fill(Color.white.opacity(0.22))
     .overlay(Circle().stroke(Color.white.opacity(0.28),lineWidth:1))
     .frame(width:knobSize,height:knobSize)
     .offset(knob)
     .animation(.interactiveSpring(response:0.12,dampingFraction:0.82),value:knob)
   }
   .contentShape(Rectangle())
   .gesture(
    DragGesture(minimumDistance:0)
     .onChanged { value in
      let center=CGPoint(x:geo.size.width/2,y:geo.size.height/2)
      update(dx:value.location.x-center.x,dy:value.location.y-center.y,radius:radius)
     }
     .onEnded { _ in stop() }
   )
  }
  .onDisappear { stop() }
  .accessibilityLabel("模拟量指针摇杆")
 }

 private func update(dx:CGFloat,dy:CGFloat,radius:CGFloat){
  let distance=sqrt(dx*dx+dy*dy)
  let scale=distance>radius ? radius/distance : 1
  knob=CGSize(width:dx*scale,height:dy*scale)
  let normalized=min(1,distance/radius)
  guard normalized>deadZone else {
   velocity=.zero
   stopTimerOnly()
   return
  }
  let magnitude=(normalized-deadZone)/(1-deadZone)
  let curved=magnitude*magnitude
  let directionX=dx/max(distance,0.001)
  let directionY=dy/max(distance,0.001)
  velocity=CGVector(dx:directionX*curved*CGFloat(sensitivity),dy:directionY*curved*CGFloat(sensitivity))
  startTimerIfNeeded()
 }

 private func startTimerIfNeeded(){
  guard timer==nil else{return}
  sendCurrent()
  timer=Timer.scheduledTimer(withTimeInterval:1.0/60.0,repeats:true){ _ in
   sendCurrent()
  }
 }

 private func sendCurrent(){
  let v=velocity
  guard v.dx != 0 || v.dy != 0 else{return}
  send(Double(v.dx),Double(v.dy))
 }

 private func stopTimerOnly(){
  timer?.invalidate()
  timer=nil
 }

 private func stop(){
  stopTimerOnly()
  velocity=.zero
  knob = .zero
 }
}

private struct EightWayArrowJoystick:View {
 let width:CGFloat
 let height:CGFloat
 let send:(UInt16,UInt64,Bool)->Void
 let flags:UInt64
 @State private var knob=CGSize.zero
 @State private var activeCodes:[UInt16]=[]
 @State private var activeFlags:UInt64=0

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
      guard distance > max(10,diameter*0.12) else {
       updateDirection(nil)
       return
      }
      let angle=atan2(dy,dx)
      var sector=Int(round(angle/(.pi/4)))
      if sector < 0 { sector += 8 }
      updateDirection(sector)
     }
     .onEnded { _ in
      releaseActiveKeys()
      knob = .zero
     }
   )
  }
  .frame(width:width,height:height)
  .onDisappear { releaseActiveKeys() }
  .accessibilityLabel("八向方向摇杆")
 }

 private func updateDirection(_ direction:Int?) {
  let next=direction.map { directionCodes($0) } ?? []
  guard next != activeCodes else{return}
  if activeCodes.isEmpty && !next.isEmpty { activeFlags=flags }

  for code in activeCodes where !next.contains(code) {
   send(code,activeFlags,false)
  }
  for code in next where !activeCodes.contains(code) {
   send(code,activeFlags,true)
  }

  activeCodes=next
  if next.isEmpty {
   activeFlags=0
  } else {
   UIImpactFeedbackGenerator(style:.light).impactOccurred(intensity:0.55)
  }
 }

 private func releaseActiveKeys() {
  guard !activeCodes.isEmpty else{return}
  for code in activeCodes {
   send(code,activeFlags,false)
  }
  activeCodes=[]
  activeFlags=0
 }

 private func directionCodes(_ direction:Int)->[UInt16] {
  switch direction {
  case 0:return [124]
  case 1:return [125,124]
  case 2:return [125]
  case 3:return [125,123]
  case 4:return [123]
  case 5:return [126,123]
  case 6:return [126]
  default:return [126,124]
  }
 }
}

private struct KeyLifecycleButton<Label:View>:View {
 let code:UInt16
 let flags:UInt64
 let send:(UInt16,UInt64,Bool)->Void
 let accessibilityLabel:String
 let onPress:()->Void
 let label:Label
 @State private var pressed=false
 @State private var activeFlags:UInt64=0

 init(code:UInt16,flags:UInt64,send:@escaping(UInt16,UInt64,Bool)->Void,accessibilityLabel:String,onPress:@escaping()->Void={},@ViewBuilder label:()->Label) {
  self.code=code
  self.flags=flags
  self.send=send
  self.accessibilityLabel=accessibilityLabel
  self.onPress=onPress
  self.label=label()
 }

 var body:some View {
  label
   .foregroundStyle(Color.primary)
   .background(Color.white.opacity(pressed ? 0.22:0.12))
   .clipShape(RoundedRectangle(cornerRadius:7,style:.continuous))
   .overlay(RoundedRectangle(cornerRadius:7,style:.continuous).stroke(Color.white.opacity(0.12),lineWidth:1))
   .scaleEffect(pressed ? 0.96:1)
   .animation(.easeOut(duration:0.06),value:pressed)
   .contentShape(Rectangle())
   .gesture(
    DragGesture(minimumDistance:0)
     .onChanged { _ in beginPress() }
     .onEnded { _ in endPress() }
   )
   .onDisappear { endPress() }
   .accessibilityElement(children:.ignore)
   .accessibilityLabel(accessibilityLabel)
   .accessibilityIdentifier("key-\(code)")
   .accessibilityAddTraits(.isButton)
   .accessibilityAction {
    beginPress()
    endPress()
   }
 }

 private func beginPress() {
  guard !pressed else{return}
  activeFlags=flags
  pressed=true
  onPress()
  send(code,activeFlags,true)
 }

 private func endPress() {
  guard pressed else{return}
  send(code,activeFlags,false)
  pressed=false
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

