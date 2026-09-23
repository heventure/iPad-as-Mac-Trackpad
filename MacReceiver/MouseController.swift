import AppKit
import ApplicationServices

enum MouseController {
 static var hasAccessibilityPermission:Bool{AXIsProcessTrusted()}
 static func requestAccessibilityPermission(){let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary;_ = AXIsProcessTrustedWithOptions(options)}

 private static let keyQueue=DispatchQueue(label:"ipadpad.keyboard.events",qos:.userInteractive)
 private static var heldFlags:[UInt16:UInt64]=[:]
 private static var repeatTimers:[UInt16:DispatchSourceTimer]=[:]

 static func handle(_ m:PointerMessage){
  guard hasAccessibilityPermission else{return}
  switch m{
  case let .move(dx,dy):move(dx:dx,dy:dy)
  case let .scroll(dx,dy):scroll(dx:dx,dy:dy)
  case .leftClick:click(.left)
  case .rightClick:click(.right)
  case let .text(s):type(s)
  case let .key(code,flags,isDown):key(code,flags,isDown)
  }
 }

 static func releaseAllKeys(){
  keyQueue.async {
   for (code,raw) in heldFlags {
    repeatTimers.removeValue(forKey:code)?.cancel()
    postKey(code,raw,isDown:false,isRepeat:false)
   }
   repeatTimers.removeAll()
   heldFlags.removeAll()
  }
 }

 private static func current()->CGPoint{CGEvent(source:nil)?.location ?? .zero}
 private static func move(dx:Double,dy:Double){let speed=hypot(dx,dy);let gain=1.0+min(1.2,speed/18.0);let p=current();CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:CGPoint(x:p.x+dx*gain,y:p.y+dy*gain),mouseButton:.left)?.post(tap:.cghidEventTap)}
 private static func click(_ b:CGMouseButton){let p=current(),d:CGEventType=b == .right ? .rightMouseDown:.leftMouseDown,u:CGEventType=b == .right ? .rightMouseUp:.leftMouseUp;CGEvent(mouseEventSource:nil,mouseType:d,mouseCursorPosition:p,mouseButton:b)?.post(tap:.cghidEventTap);CGEvent(mouseEventSource:nil,mouseType:u,mouseCursorPosition:p,mouseButton:b)?.post(tap:.cghidEventTap)}
 private static func scroll(dx:Double,dy:Double){CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:2,wheel1:Int32(max(-120,min(120,-dy))),wheel2:Int32(max(-120,min(120,-dx))),wheel3:0)?.post(tap:.cghidEventTap)}
 private static func type(_ s:String){
  let units=Array(s.utf16)
  guard !units.isEmpty else{return}
  let chunkSize=20
  var index=0
  while index<units.count{
   let end=min(index+chunkSize,units.count)
   var chunk=Array(units[index..<end])
   chunk.withUnsafeMutableBufferPointer { buffer in
    guard let base=buffer.baseAddress else{return}
    if let down=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:true){
     down.keyboardSetUnicodeString(stringLength:buffer.count,unicodeString:base)
     down.post(tap:.cghidEventTap)
    }
    if let up=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:false){
     up.keyboardSetUnicodeString(stringLength:buffer.count,unicodeString:base)
     up.post(tap:.cghidEventTap)
    }
   }
   index=end
  }
 }

 private static func key(_ code:UInt16,_ raw:UInt64,_ isDown:Bool){
  keyQueue.async {
   if isDown {
    guard heldFlags[code] == nil else{return}
    heldFlags[code]=raw
    postKey(code,raw,isDown:true,isRepeat:false)

    let timer=DispatchSource.makeTimerSource(queue:keyQueue)
    timer.schedule(deadline:.now()+.milliseconds(420),repeating:.milliseconds(55),leeway:.milliseconds(8))
    timer.setEventHandler {
     guard let heldRaw=heldFlags[code] else{return}
     postKey(code,heldRaw,isDown:true,isRepeat:true)
    }
    repeatTimers[code]=timer
    timer.resume()
   } else {
    let heldRaw=heldFlags.removeValue(forKey:code) ?? raw
    repeatTimers.removeValue(forKey:code)?.cancel()
    postKey(code,heldRaw,isDown:false,isRepeat:false)
   }
  }
 }

 private static func postKey(_ code:UInt16,_ raw:UInt64,isDown:Bool,isRepeat:Bool){
  guard let event=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(code),keyDown:isDown) else{return}
  event.flags=CGEventFlags(rawValue:raw)
  event.setIntegerValueField(.keyboardEventAutorepeat,value:isRepeat ? 1:0)
  event.post(tap:.cghidEventTap)
 }
}
