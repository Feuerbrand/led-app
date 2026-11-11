import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Nur für das Vorführ-Video (Startargument „-tour YES“): jeder Finger erscheint als heller Kreis,
/// damit man im Video sieht, wo getippt und gezogen wird.
enum TourTouches {
    private static var overlay: UIWindow?

    static var enabled: Bool { UserDefaults.standard.bool(forKey: "tour") }

    static func install() {
        guard enabled, overlay == nil else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first else { return }
        guard let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else { return }
        let top = UIWindow(windowScene: scene)
        top.frame = window.bounds
        top.windowLevel = UIWindow.Level.alert + 10
        top.backgroundColor = .clear
        top.isUserInteractionEnabled = false
        top.isHidden = false
        overlay = top
        let spy = TouchSpy(target: nil, action: nil)
        spy.overlay = top
        window.addGestureRecognizer(spy)
    }
}

/// Beobachtet alle Berührungen im Fenster, ohne sie abzufangen
private final class TouchSpy: UIGestureRecognizer {
    weak var overlay: UIWindow?
    private var dots: [ObjectIdentifier: UIView] = [:]

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            let dot = Self.makeDot()
            dot.center = touch.location(in: nil)
            dot.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            dot.alpha = 0
            overlay?.addSubview(dot)
            dots[ObjectIdentifier(touch)] = dot
            UIView.animate(withDuration: 0.12) {
                dot.transform = .identity
                dot.alpha = 1
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            dots[ObjectIdentifier(touch)]?.center = touch.location(in: nil)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let dot = dots.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            UIView.animate(withDuration: 0.45, delay: 0.15, options: [.curveEaseOut]) {
                dot.alpha = 0
                dot.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
            } completion: { _ in
                dot.removeFromSuperview()
            }
        }
        if dots.isEmpty { state = .failed }
    }

    private static func makeDot() -> UIView {
        let dot = UIView(frame: CGRect(x: 0, y: 0, width: 46, height: 46))
        dot.backgroundColor = UIColor(white: 1, alpha: 0.35)
        dot.layer.cornerRadius = 23
        dot.layer.borderWidth = 2.5
        dot.layer.borderColor = UIColor.white.cgColor
        dot.isUserInteractionEnabled = false
        return dot
    }
}
