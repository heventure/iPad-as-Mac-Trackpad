import SwiftUI
import UIKit
struct TrackpadSurface: UIViewRepresentable {
    let sensitivity: Double
    let onMessage: (PointerMessage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onMessage: onMessage) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 24; view.layer.cornerCurve = .continuous; view.layer.borderWidth = 1; view.layer.borderColor = UIColor.separator.cgColor; view.isMultipleTouchEnabled = true
        let one = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.one(_:))); one.minimumNumberOfTouches=1; one.maximumNumberOfTouches=1; one.delegate=context.coordinator; view.addGestureRecognizer(one)
        let two = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.two(_:))); two.minimumNumberOfTouches=2; two.maximumNumberOfTouches=2; two.delegate=context.coordinator; view.addGestureRecognizer(two)
        let left = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.left(_:))); left.numberOfTouchesRequired=1; left.delegate=context.coordinator; view.addGestureRecognizer(left)
        let right = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.right(_:))); right.numberOfTouchesRequired=2; right.delegate=context.coordinator; view.addGestureRecognizer(right)
        left.require(toFail: right); return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.sensitivity=sensitivity; context.coordinator.onMessage=onMessage }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var sensitivity=1.2; var onMessage:(PointerMessage)->Void
        init(onMessage:@escaping(PointerMessage)->Void){self.onMessage=onMessage}
        @objc func one(_ r:UIPanGestureRecognizer){let d=r.translation(in:r.view);r.setTranslation(.zero,in:r.view);guard r.state == .began || r.state == .changed else{return};onMessage(.move(dx:d.x*sensitivity,dy:d.y*sensitivity))}
        @objc func two(_ r:UIPanGestureRecognizer){let d=r.translation(in:r.view);r.setTranslation(.zero,in:r.view);guard r.state == .began || r.state == .changed else{return};onMessage(.scroll(dx:d.x,dy:d.y))}
        @objc func left(_ r:UITapGestureRecognizer){if r.state == .ended{onMessage(.leftClick)}}
        @objc func right(_ r:UITapGestureRecognizer){if r.state == .ended{onMessage(.rightClick)}}
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer)->Bool{false}
    }
}