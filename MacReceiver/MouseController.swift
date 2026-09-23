import AppKit
import ApplicationServices
enum MouseController{
 static var hasAccessibilityPermission:Bool{AXIsProcessTrusted()}
 static func requestAccessibilityPermission(){let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary;_ = AXIsProcessTrustedWithOptions(options)}
 static func handle(_ message:PointerMessage){guard hasAccessibilityPermission else{return};switch message{case let .move(dx,dy):move(dx:dx,dy:dy);case let .scroll(dx,dy):scroll(dx:dx,dy:dy);case .leftClick:click(button:.left);case .rightClick:click(button:.right)}}
 private static func currentLocation()->CGPoint{CGEvent(source:nil)?.location ?? .zero}
 private static func move(dx:Double,dy:Double){let old=currentLocation();let target=CGPoint(x:old.x+dx,y:old.y+dy);CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:target,mouseButton:.left)?.post(tap:.cghidEventTap)}
 private static func click(button:CGMouseButton){let l=currentLocation();let down:CGEventType=button == .right ? .rightMouseDown:.leftMouseDown;let up:CGEventType=button == .right ? .rightMouseUp:.leftMouseUp;CGEvent(mouseEventSource:nil,mouseType:down,mouseCursorPosition:l,mouseButton:button)?.post(tap:.cghidEventTap);CGEvent(mouseEventSource:nil,mouseType:up,mouseCursorPosition:l,mouseButton:button)?.post(tap:.cghidEventTap)}
 private static func scroll(dx:Double,dy:Double){let v=Int32(max(-120,min(120,-dy)));let h=Int32(max(-120,min(120,-dx)));CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:2,wheel1:v,wheel2:h,wheel3:0)?.post(tap:.cghidEventTap)}
}