import AppKit
import ApplicationServices
enum MouseController {
 static var hasAccessibilityPermission:Bool{AXIsProcessTrusted()}
 static func requestAccessibilityPermission(){let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary;_ = AXIsProcessTrustedWithOptions(options)}
 static func handle(_ m:PointerMessage){guard hasAccessibilityPermission else{return};switch m{case let .move(dx,dy):move(dx:dx,dy:dy);case let .scroll(dx,dy):scroll(dx:dx,dy:dy);case .leftClick:click(.left);case .rightClick:click(.right);case let .text(s):type(s);case let .key(code,flags):key(code,flags)}}
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
 private static func key(_ code:UInt16,_ raw:UInt64){let flags=CGEventFlags(rawValue:raw);let d=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(code),keyDown:true);d?.flags=flags;d?.post(tap:.cghidEventTap);let u=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(code),keyDown:false);u?.flags=flags;u?.post(tap:.cghidEventTap)}
}