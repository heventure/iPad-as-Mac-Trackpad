import SwiftUI
import UIKit

struct TrackpadSurface: UIViewRepresentable {
    let sensitivity: Double
    let onMessage: (PointerMessage) -> Void
    let onRawMove: (Double, Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onMessage: onMessage, onRawMove: onRawMove) }

    func makeUIView(context: Context) -> TouchProbeView {
        let view = TouchProbeView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 24
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.cgColor
        view.clipsToBounds = true
        view.isMultipleTouchEnabled = true

        view.onRawTouch = { [weak coordinator = context.coordinator] point, timestamp in
            coordinator?.updateProbe(point: point, timestamp: timestamp)
        }
        view.onRawMove = { [weak coordinator = context.coordinator] dx, dy in
            coordinator?.sendRawMove(dx: dx, dy: dy)
        }
        view.onTouchEnded = { [weak coordinator = context.coordinator] in coordinator?.hideProbeSoon() }

        let probe = UIView(frame: CGRect(x:0,y:0,width:28,height:28))
        probe.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.8)
        probe.layer.cornerRadius = 14
        probe.layer.borderWidth = 2
        probe.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        probe.isUserInteractionEnabled = false
        probe.isHidden = true
        view.addSubview(probe)
        context.coordinator.probeView = probe

        let label = UILabel()
        label.text = "RAW TOUCH → UDP"
        label.font = .monospacedSystemFont(ofSize:11,weight:.semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo:view.topAnchor,constant:12),
            label.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-14)
        ])

        let two = UIPanGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.two(_:)))
        two.minimumNumberOfTouches=2; two.maximumNumberOfTouches=2; two.cancelsTouchesInView=false
        view.addGestureRecognizer(two)

        let left = UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.left(_:)))
        left.numberOfTouchesRequired=1; left.cancelsTouchesInView=false
        view.addGestureRecognizer(left)

        let right = UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.right(_:)))
        right.numberOfTouchesRequired=2; right.cancelsTouchesInView=false
        view.addGestureRecognizer(right)
        left.require(toFail:right)
        return view
    }

    func updateUIView(_ uiView:TouchProbeView,context:Context) {
        context.coordinator.sensitivity=sensitivity
        context.coordinator.onMessage=onMessage
        context.coordinator.onRawMove=onRawMove
    }

    final class TouchProbeView:UIView {
        var onRawTouch:((CGPoint,TimeInterval)->Void)?
        var onRawMove:((CGFloat,CGFloat)->Void)?
        var onTouchEnded:(()->Void)?
        private var lastSinglePoint:CGPoint?

        override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
            super.touchesBegan(touches,with:event)
            guard let touch=touches.first else{return}
            let point=touch.location(in:self)
            onRawTouch?(point,touch.timestamp)
            let active=event?.allTouches?.filter{$0.phase != .ended && $0.phase != .cancelled}.count ?? touches.count
            lastSinglePoint = active == 1 ? point : nil
        }

        override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) {
            super.touchesMoved(touches,with:event)
            guard let touch=touches.first else{return}
            let active=event?.allTouches?.filter{$0.phase != .ended && $0.phase != .cancelled}.count ?? touches.count
            let samples=event?.coalescedTouches(for:touch) ?? [touch]
            for sample in samples {
                let point=sample.location(in:self)
                onRawTouch?(point,sample.timestamp)
                if active == 1, let last=lastSinglePoint { onRawMove?(point.x-last.x,point.y-last.y) }
                lastSinglePoint = active == 1 ? point : nil
            }
        }

        override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) {
            super.touchesEnded(touches,with:event); lastSinglePoint=nil; onTouchEnded?()
        }
        override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?) {
            super.touchesCancelled(touches,with:event); lastSinglePoint=nil; onTouchEnded?()
        }
    }

    final class Coordinator:NSObject {
        var sensitivity=1.2
        var onMessage:(PointerMessage)->Void
        var onRawMove:(Double,Double)->Void
        weak var probeView:UIView?
        private var hideWork:DispatchWorkItem?
        private var inertiaLink:CADisplayLink?
        private var inertiaVX:CGFloat=0,inertiaVY:CGFloat=0
        private var lastTimestamp:CFTimeInterval=0

        init(onMessage:@escaping(PointerMessage)->Void,onRawMove:@escaping(Double,Double)->Void) {
            self.onMessage=onMessage; self.onRawMove=onRawMove
        }

        func sendRawMove(dx:CGFloat,dy:CGFloat) { onRawMove(Double(dx)*sensitivity,Double(dy)*sensitivity) }

        func updateProbe(point:CGPoint,timestamp:TimeInterval) {
            hideWork?.cancel(); probeView?.isHidden=false
            CATransaction.begin(); CATransaction.setDisableActions(true); probeView?.center=point; CATransaction.commit()
        }

        func hideProbeSoon() {
            let work=DispatchWorkItem{[weak self] in self?.probeView?.isHidden=true}
            hideWork=work; DispatchQueue.main.asyncAfter(deadline:.now()+0.12,execute:work)
        }

        @objc func two(_ r:UIPanGestureRecognizer) {
            switch r.state {
            case .began: stopInertia(); r.setTranslation(.zero,in:r.view)
            case .changed:
                let d=r.translation(in:r.view); r.setTranslation(.zero,in:r.view); onMessage(.scroll(dx:d.x,dy:d.y))
            case .ended:
                let v=r.velocity(in:r.view); startInertia(vx:v.x,vy:v.y)
            case .cancelled,.failed: stopInertia()
            default: break
            }
        }

        private func startInertia(vx:CGFloat,vy:CGFloat) {
            stopInertia(); guard hypot(vx,vy)>80 else{return}
            let scale=min(1,5000/max(hypot(vx,vy),1)); inertiaVX=vx*scale; inertiaVY=vy*scale; lastTimestamp=0
            let link=CADisplayLink(target:self,selector:#selector(inertiaTick(_:)))
            if #available(iOS 15.0,*) { link.preferredFrameRateRange=CAFrameRateRange(minimum:60,maximum:120,preferred:120) }
            link.add(to:.main,forMode:.common); inertiaLink=link
        }

        @objc private func inertiaTick(_ link:CADisplayLink) {
            if lastTimestamp==0 { lastTimestamp=link.timestamp; return }
            let dt=min(link.timestamp-lastTimestamp,1.0/30.0); lastTimestamp=link.timestamp
            onMessage(.scroll(dx:inertiaVX*dt,dy:inertiaVY*dt))
            let decay=pow(0.075,dt); inertiaVX*=decay; inertiaVY*=decay
            if hypot(inertiaVX,inertiaVY)<18 { stopInertia() }
        }

        private func stopInertia(){inertiaLink?.invalidate();inertiaLink=nil;inertiaVX=0;inertiaVY=0;lastTimestamp=0}
        @objc func left(_ r:UITapGestureRecognizer){if r.state == .ended{onMessage(.leftClick)}}
        @objc func right(_ r:UITapGestureRecognizer){if r.state == .ended{onMessage(.rightClick)}}
    }
}