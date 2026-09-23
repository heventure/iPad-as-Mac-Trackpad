import SwiftUI
import UIKit

struct TrackpadSurface: UIViewRepresentable {
    let sensitivity: Double
    let onMessage: (PointerMessage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onMessage: onMessage) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 24
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.cgColor
        view.isMultipleTouchEnabled = true

        let one = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.one(_:)))
        one.minimumNumberOfTouches = 1
        one.maximumNumberOfTouches = 1
        one.delegate = context.coordinator
        view.addGestureRecognizer(one)

        let two = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.two(_:)))
        two.minimumNumberOfTouches = 2
        two.maximumNumberOfTouches = 2
        two.delegate = context.coordinator
        view.addGestureRecognizer(two)

        let left = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.left(_:)))
        left.numberOfTouchesRequired = 1
        left.delegate = context.coordinator
        view.addGestureRecognizer(left)

        let right = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.right(_:)))
        right.numberOfTouchesRequired = 2
        right.delegate = context.coordinator
        view.addGestureRecognizer(right)

        left.require(toFail: right)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.sensitivity = sensitivity
        context.coordinator.onMessage = onMessage
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var sensitivity = 1.2
        var onMessage: (PointerMessage) -> Void

        private var inertiaLink: CADisplayLink?
        private var inertiaVX: CGFloat = 0
        private var inertiaVY: CGFloat = 0
        private var lastTimestamp: CFTimeInterval = 0

        init(onMessage: @escaping (PointerMessage) -> Void) {
            self.onMessage = onMessage
        }

        @objc func one(_ r: UIPanGestureRecognizer) {
            let d = r.translation(in: r.view)
            r.setTranslation(.zero, in: r.view)
            guard r.state == .began || r.state == .changed else { return }
            onMessage(.move(dx: d.x * sensitivity, dy: d.y * sensitivity))
        }

        @objc func two(_ r: UIPanGestureRecognizer) {
            switch r.state {
            case .began:
                stopInertia()
                r.setTranslation(.zero, in: r.view)

            case .changed:
                let d = r.translation(in: r.view)
                r.setTranslation(.zero, in: r.view)
                onMessage(.scroll(dx: d.x, dy: d.y))

            case .ended:
                let velocity = r.velocity(in: r.view)
                startInertia(vx: velocity.x, vy: velocity.y)

            case .cancelled, .failed:
                stopInertia()

            default:
                break
            }
        }

        private func startInertia(vx: CGFloat, vy: CGFloat) {
            stopInertia()

            // Ignore tiny releases so a slow two-finger gesture stops immediately.
            guard hypot(vx, vy) > 80 else { return }

            // Clamp a very fast flick to keep scrolling controllable.
            let maxVelocity: CGFloat = 5_000
            let scale = min(1, maxVelocity / max(hypot(vx, vy), 1))
            inertiaVX = vx * scale
            inertiaVY = vy * scale
            lastTimestamp = 0

            let link = CADisplayLink(target: self, selector: #selector(inertiaTick(_:)))
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            }
            link.add(to: .main, forMode: .common)
            inertiaLink = link
        }

        @objc private func inertiaTick(_ link: CADisplayLink) {
            if lastTimestamp == 0 {
                lastTimestamp = link.timestamp
                return
            }

            let dt = min(link.timestamp - lastTimestamp, 1.0 / 30.0)
            lastTimestamp = link.timestamp

            onMessage(.scroll(
                dx: inertiaVX * dt,
                dy: inertiaVY * dt
            ))

            // Exponential decay makes the result independent of 60/120 Hz.
            let decay = pow(0.075, dt)
            inertiaVX *= decay
            inertiaVY *= decay

            if hypot(inertiaVX, inertiaVY) < 18 {
                stopInertia()
            }
        }

        private func stopInertia() {
            inertiaLink?.invalidate()
            inertiaLink = nil
            inertiaVX = 0
            inertiaVY = 0
            lastTimestamp = 0
        }

        @objc func left(_ r: UITapGestureRecognizer) {
            if r.state == .ended { onMessage(.leftClick) }
        }

        @objc func right(_ r: UITapGestureRecognizer) {
            if r.state == .ended { onMessage(.rightClick) }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}