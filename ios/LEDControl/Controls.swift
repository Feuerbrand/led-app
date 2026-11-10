import SwiftUI
import UIKit

// MARK: - Uhr für laufende Animationen

/// Zeichnet den Inhalt rund 30-mal pro Sekunde neu und gibt die laufende Zeit in Sekunden mit.
/// Bei „Bewegung reduzieren“ bleibt das Bild stehen.
struct Clock<Content: View>: View {
    private let content: (Double) -> Content

    @Environment(\.accessibilityReduceMotion) private var still

    init(@ViewBuilder content: @escaping (Double) -> Content) {
        self.content = content
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { timeline in
            content(timeline.date.timeIntervalSinceReferenceDate)
        }
    }
}

// MARK: - Kacheln und Überschriften

/// Kachel wie `.qt` auf der Webseite
struct Tile: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.soft, lineWidth: Theme.border)
            }
    }
}

/// Einblenden beim Start, eine Kachel nach der anderen
struct Rise: ViewModifier {
    let index: Int

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var still

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.98)
            .offset(y: shown ? 0 : 18)
            .onAppear {
                if shown { return }
                if still {
                    shown = true
                } else if Date().timeIntervalSince(Intro.start) < 2 {
                    // Beim Start: Kachel für Kachel einblenden
                    withAnimation(Theme.curve.delay(Double(index) * 0.065 + 0.26)) { shown = true }
                } else {
                    // Beim Wechsel des Reiters nur kurz und schnell
                    withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45).delay(Double(index) * 0.025)) { shown = true }
                }
            }
    }
}

/// Zeitpunkt des App-Starts (für die Einblend-Animation)
enum Intro {
    static let start = Date()
}

extension View {
    func tile() -> some View { modifier(Tile()) }
    func rise(_ index: Int) -> some View { modifier(Rise(index: index)) }
}

struct SectionTitle: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.geist(11, 600))
            .tracking(1.3)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 24, leading: 4, bottom: 10, trailing: 0))
    }
}

/// Kopfzeile einer Kachel: Symbol, Titel, rechts der aktuelle Wert
struct TileHeader: View {
    let icon: IconKind
    let title: String
    let value: String
    /// Nur bei der Helligkeit: das Symbol dreht und wächst mit dem Wert (0…100)
    var level: Double? = nil

    var body: some View {
        let turn: Double = (level ?? 0) * 1.8
        let grow: Double = level == nil ? 1 : 0.75 + (level ?? 0) / 100 * 0.45
        HStack(spacing: 10) {
            Icon(kind: icon, size: 17, color: Theme.accent)
                .rotationEffect(.degrees(turn))
                .scaleEffect(CGFloat(grow))
            Text(title)
                .font(.geist(16, 500))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            Text(value)
                .font(.geist(18, 600))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
        }
    }
}

// MARK: - Knöpfe

/// Knopf mit hellem Rahmen wie `.ob`: gedrückt oder aktiv wird er gelb umrandet
struct OutlineButtonStyle: ButtonStyle {
    var on = false

    func makeBody(configuration: Configuration) -> some View {
        Face(on: on, pressed: configuration.isPressed, label: configuration.label)
    }

    private struct Face: View {
        let on: Bool
        let pressed: Bool
        let label: ButtonStyleConfiguration.Label

        @Environment(\.isEnabled) private var enabled

        var body: some View {
            let hot = on || pressed
            label
                .font(.geist(16, 500))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .environment(\.iconTint, hot ? Theme.accent : Theme.icon)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(hot ? Theme.hot : Theme.fill, in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5).strokeBorder(hot ? Theme.accent : Theme.line, lineWidth: Theme.border)
                }
                .contentShape(Rectangle())
                .scaleEffect(pressed ? 0.96 : 1)
                .opacity(enabled ? 1 : 0.35)
                .animation(.easeOut(duration: 0.15), value: hot)
        }
    }
}

/// Nur leicht eindrücken (Karten und Farbfelder)
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Regler

/// Regler 0…100 wie in den Client-Einstellungen: gelbe Füllung, heller Knopf mit gelbem Ring.
/// Dahinter steckt der UISlider von iOS, damit Ziehen und Scrollen sich nicht stören.
struct AccentSlider: UIViewRepresentable {
    let value: Int
    let label: String
    let onChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = Float(value)
        slider.minimumTrackTintColor = UIColor(Theme.accent)
        slider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.18)
        slider.setThumbImage(Self.thumb, for: .normal)
        slider.setThumbImage(Self.thumb, for: .highlighted)
        slider.accessibilityLabel = label
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.moved(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.onChange = onChange
        if !slider.isTracking, Int(slider.value.rounded()) != value {
            slider.value = Float(value)
        }
    }

    final class Coordinator: NSObject {
        var onChange: (Int) -> Void
        private var last: Int?

        init(onChange: @escaping (Int) -> Void) {
            self.onChange = onChange
        }

        @objc func moved(_ slider: UISlider) {
            let v = Int(slider.value.rounded())
            if v == last { return }
            last = v
            onChange(v)
        }
    }

    private static let thumb: UIImage = {
        let size = CGSize(width: 20, height: 20)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let circle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5))
            circle.lineWidth = 3
            UIColor(red: 244 / 255, green: 241 / 255, blue: 232 / 255, alpha: 1).setFill()
            UIColor(red: 1, green: 210 / 255, blue: 63 / 255, alpha: 1).setStroke()
            circle.fill()
            circle.stroke()
        }
    }()
}

// MARK: - Leisten zum Ziehen (Farbton, Weißton)

/// Unsichtbare Fläche, die beim Antippen und Ziehen die Stelle 0…1 von links nach rechts meldet.
/// Waagerechtes Ziehen gehört der Leiste, senkrechtes Wischen scrollt weiter die Seite.
struct DragStrip: UIViewRepresentable {
    let onChange: (Double) -> Void

    func makeUIView(context: Context) -> Surface {
        let surface = Surface()
        surface.onChange = onChange
        return surface
    }

    func updateUIView(_ surface: Surface, context: Context) {
        surface.onChange = onChange
    }

    final class Surface: UIView {
        var onChange: ((Double) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            let pan = UIPanGestureRecognizer(target: self, action: #selector(moved(_:)))
            pan.maximumNumberOfTouches = 1
            addGestureRecognizer(pan)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(moved(_:))))
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: self)
            return abs(v.x) >= abs(v.y)
        }

        @objc private func moved(_ recognizer: UIGestureRecognizer) {
            let width = bounds.width
            if width <= 0 { return }
            let f = recognizer.location(in: self).x / width
            onChange?(Double(min(max(f, 0), 1)))
        }
    }
}

/// Farbleiste mit Knopf an der gewählten Stelle. `position` nil = kein Knopf sichtbar.
struct ColorBar: View {
    let colors: [Color]
    let position: Double?
    let label: String
    let onDrag: (Double) -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .overlay {
                RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line, lineWidth: Theme.border)
            }
            .frame(height: 34)
            .overlay {
                GeometryReader { geo in
                    knob
                        .position(x: geo.size.width * CGFloat(position ?? 0), y: geo.size.height / 2)
                        .opacity(position == nil ? 0 : 1)
                        .animation(.easeOut(duration: 0.2), value: position == nil)
                }
                .allowsHitTesting(false)
            }
            .overlay {
                DragStrip(onChange: onDrag)
            }
            .accessibilityElement()
            .accessibilityLabel(label)
    }

    private var knob: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Theme.text)
            .overlay {
                RoundedRectangle(cornerRadius: 6).strokeBorder(Color(rgb: 0x14130E), lineWidth: 2)
            }
            .frame(width: 12, height: 46)
            .padding(1.5)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 7.5))
            .shadow(color: .black.opacity(0.7), radius: 5, y: 2)
    }
}

// MARK: - Farbwähler von iOS

struct SystemColorPicker: UIViewControllerRepresentable {
    let initial: RGB
    let onPick: (RGB) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = UIColor(red: CGFloat(initial.r) / 255, green: CGFloat(initial.g) / 255,
                                       blue: CGFloat(initial.b) / 255, alpha: 1)
        picker.title = "Farbe"
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIColorPickerViewController, context: Context) {
        context.coordinator.onPick = onPick
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var onPick: (RGB) -> Void

        init(onPick: @escaping (RGB) -> Void) {
            self.onPick = onPick
        }

        func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
            func byte(_ v: CGFloat) -> Int {
                Int((min(max(v, 0), 1) * 255).rounded())
            }
            onPick(RGB(byte(r), byte(g), byte(b)))
        }
    }
}
