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
 private static func type(_ s:String){for scalar in s.unicodeScalars{var u=UniChar(scalar.value);if let e=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:true){e.keyboardSetUnicodeString(stringLength:1,unicodeString:&u);e.post(tap:.cghidEventTap)};if let e=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:false){e.keyboardSetUnicodeString(stringLength:1,unicodeString:&u);e.post(tap:.cghidEventTap)}}}
 private static func key(_ code:UInt16,_ raw:UInt64){let flags=CGEventFlags(rawValue:raw);let d=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(code),keyDown:true);d?.flags=flags;d?.post(tap:.cghidEventTap);let u=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(code),keyDown:false);u?.flags=flags;u?.post(tap:.cghidEventTap)}
}