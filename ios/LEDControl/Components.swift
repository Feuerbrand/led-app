import SwiftUI
import UIKit

// MARK: - Seiten

/// Scrollbare Seite: Inhalt mittig, höchstens 520 Punkte breit
struct Page<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: 520)
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 36, trailing: 16))
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) { StatusBarShade() }
    }
}

/// Weicher, dunkler Streifen hinter Uhrzeit und Akku: Inhalt, der nach oben geschoben wird,
/// verschwindet darunter, statt sich mit der Statusleiste zu überlagern.
private struct StatusBarShade: View {
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Theme.bg.opacity(0.55))
                .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                             .init(color: .black, location: 0.72),
                                             .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: geo.safeAreaInsets.top + 14)
                .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Große Überschrift einer Seite
struct PageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle.uppercased())
                .font(.geistMono(11, 600))
                .tracking(1.8)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
            Text(title)
                .font(.geist(36, 800))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .padding(.horizontal, 4)
        .rise(0)
    }
}

/// Hintergrund mit Lochraster hinter jeder Seite
struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background { Backdrop() }
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

extension View {
    func pageBackground() -> some View { modifier(PageBackground()) }
}

// MARK: - LEDs

/// Zeichnet eine einzelne LED: aus = dunkler Punkt; an = Punkt in der Farbe mit kleinem, echtem Lichthof
enum LED {
    static func draw(_ context: GraphicsContext, at p: CGPoint, size d: CGFloat, color: Color?) {
        let rect = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
        guard let color else {
            context.fill(Path(ellipseIn: rect), with: .color(Theme.ledOff))
            return
        }
        let halo = d * 1.25
        context.fill(
            Path(ellipseIn: rect.insetBy(dx: -halo, dy: -halo)),
            with: .radialGradient(Gradient(colors: [color.opacity(0.42), color.opacity(0)]),
                                  center: p, startRadius: 0, endRadius: d / 2 + halo))
        context.fill(Path(ellipseIn: rect), with: .color(color))
        // Kleiner Glanzpunkt wie auf einer echten LED-Linse
        context.fill(Path(ellipseIn: CGRect(x: p.x - d * 0.2, y: p.y - d * 0.32, width: d * 0.3, height: d * 0.22)),
                     with: .color(Color.white.opacity(0.5)))
    }

    /// Farbe mit der Helligkeit verrechnet (dunkle Stufen bleiben sichtbar)
    static func dim(_ c: RGB, _ brightness: Int) -> Color {
        let k = 0.3 + 0.7 * Double(min(max(brightness, 0), 100)) / 100
        return Color(.sRGB, red: Double(c.r) / 255 * k, green: Double(c.g) / 255 * k, blue: Double(c.b) / 255 * k, opacity: 1)
    }
}

/// Merkt sich die Farben der letzten Sekunden, damit eine LED-Reihe sie „entlanglaufen“ lassen kann
final class ColorTrail {
    private var samples: [(t: Double, c: RGB)] = []

    func push(_ c: RGB, at t: Double) {
        if samples.last?.c == c { return }
        samples.append((t: t, c: c))
        // Nur die letzten Sekunden behalten (mindestens einen Wert davor)
        if let cut = samples.lastIndex(where: { $0.t < t - 3 }), cut > 0 {
            samples.removeFirst(cut)
        }
    }

    func color(at t: Double, fallback: RGB) -> RGB {
        guard let first = samples.first else { return fallback }
        var result = first.c
        for s in samples where s.t <= t { result = s.c }
        return result
    }
}

/// LED-Feld: eine oder mehrere Reihen. Mit einer Farbe läuft jede Änderung von links nach rechts durch,
/// mit mehreren Farben bekommt jedes Licht einen eigenen Abschnitt.
struct LEDPanel: View {
    let colors: [RGB]
    let live: Bool
    var brightness: Int = 100
    var rows: Int = 1
    var dot: CGFloat = 7
    var gap: CGFloat = 5
    /// Verzögerung je LED beim Durchlaufen einer Farbänderung (Sekunden)
    var delay: Double = 0.03

    @State private var trail = ColorTrail()
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still || !live)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let cols = max(Int((size.width + gap) / (dot + gap)), 1)
                let width = CGFloat(cols) * dot + CGFloat(cols - 1) * gap
                let height = CGFloat(rows) * dot + CGFloat(rows - 1) * gap
                let x0 = (size.width - width) / 2 + dot / 2
                let y0 = (size.height - height) / 2 + dot / 2
                for r in 0..<rows {
                    for i in 0..<cols {
                        var c: Color? = nil
                        if live {
                            if colors.count > 1 {
                                let seg = min(i * colors.count / cols, colors.count - 1)
                                c = LED.dim(colors[seg], brightness)
                            } else {
                                let fallback = colors.first ?? RGB(255, 210, 63)
                                c = LED.dim(trail.color(at: now - Double(i) * delay, fallback: fallback), brightness)
                            }
                        }
                        let p = CGPoint(x: x0 + CGFloat(i) * (dot + gap), y: y0 + CGFloat(r) * (dot + gap))
                        LED.draw(context, at: p, size: dot, color: c)
                    }
                }
            }
        }
        .frame(height: CGFloat(rows) * dot + CGFloat(rows - 1) * gap + dot * 2.6)
        .onChange(of: colors.first ?? RGB(0, 0, 0), initial: true) { _, c in
            trail.push(c, at: Date().timeIntervalSinceReferenceDate)
        }
        .accessibilityHidden(true)
    }
}

/// Lauflicht hin und her (beim Suchen von Lichtern)
struct ScannerLEDs: View {
    var dot: CGFloat = 7
    var gap: CGFloat = 5

    var body: some View {
        Clock { t in
            Canvas { context, size in
                let n = max(Int((size.width + gap) / (dot + gap)), 2)
                let width = CGFloat(n) * dot + CGFloat(n - 1) * gap
                let x0 = (size.width - width) / 2 + dot / 2
                // Position pendelt weich zwischen erster und letzter LED
                let p = (1 - cos(t * 2.4)) / 2 * Double(n - 1)
                for i in 0..<n {
                    let d = abs(Double(i) - p)
                    let c: Color? = d < 3 ? Theme.accent.opacity(1 - d / 3) : nil
                    LED.draw(context, at: CGPoint(x: x0 + CGFloat(i) * (dot + gap), y: size.height / 2), size: dot, color: c)
                }
            }
        }
        .frame(height: dot * 3.4)
        .accessibilityLabel("Sucht")
    }
}

// MARK: - Status

/// Status-LED: aus = dunkel, verbindet = blinkt, verbunden = leuchtet
struct StatusLED: View {
    let state: LinkState

    var body: some View {
        Clock { t in
            let blink = state == .busy ? t.truncatingRemainder(dividingBy: 0.9) < 0.45 : true
            let lit = state != .off && blink
            Circle()
                .fill(lit ? Theme.accent : Theme.ledOff)
                .frame(width: 8, height: 8)
                .shadow(color: Theme.accent.opacity(lit ? 0.85 : 0), radius: 4)
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }
}

/// Empfangsstärke als drei Balken; ohne Wert gedimmt
struct SignalBars: View {
    let rssi: Int?

    private var level: Int {
        guard let rssi else { return 0 }
        if rssi > -62 { return 3 }
        if rssi > -78 { return 2 }
        return 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                Rectangle()
                    .fill(i <= level ? Theme.text : Color.white.opacity(0.18))
                    .frame(width: 3, height: CGFloat(4 + i * 3))
            }
        }
        .frame(height: 14, alignment: .bottom)
        .accessibilityLabel(level == 0 ? "Kein Empfang" : "Empfang \(level) von 3")
    }
}

/// Grauer Hinweistext unter oder zwischen Paneelen
struct Hint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.geist(12, 400))
            .foregroundStyle(Theme.muted)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }
}

/// Kleines Abzeichen: kann das Licht Lauflichter (RGBIC) oder nur eine Farbe (RGB)?
struct PixelBadge: View {
    let kind: PixelKind

    var body: some View {
        if let text = kind.badge {
            let addressable = kind == .addressable
            Text(text)
                .font(.geistMono(10, 700))
                .tracking(1)
                .foregroundStyle(addressable ? Theme.ink : Theme.muted)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background {
                    if addressable {
                        Capsule().fill(Theme.accent)
                    } else {
                        Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    }
                }
                .accessibilityLabel(addressable ? "Einzeln steuerbare LEDs" : "Eine Farbe für die ganze Leiste")
        }
    }
}

struct BluetoothProblem: View {
    let state: BluetoothState

    @Environment(\.openURL) private var openURL

    private var text: String {
        switch state {
        case .off: return "Bluetooth ist ausgeschaltet. Bitte im Kontrollzentrum einschalten."
        case .denied: return "Die App darf Bluetooth nicht benutzen. Bitte in den Einstellungen erlauben."
        case .unsupported: return "Dieses Gerät kann kein Bluetooth LE."
        default: return "Bluetooth startet …"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                StatusLED(state: state == .starting ? .busy : .off)
                Text(text)
                    .font(.geist(14, 500))
                    .foregroundStyle(Theme.text)
            }
            if state == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Einstellungen öffnen") { openURL(url) }
                    .buttonStyle(OutlineButtonStyle(on: true))
            }
        }
        .tile()
        .padding(.top, 12)
    }
}

// MARK: - Bedienelemente

/// Schalter wie auf den Karten im Hauptmenü: dunkle Kapsel, gelber leuchtender Knopf.
/// `onColor`: der Schalter liegt auf einer farbigen Karte.
struct PowerSwitch: View {
    let target: Target
    var onColor: Bool = false

    @Environment(LightController.self) private var light

    var body: some View {
        let usable = light.demo || light.isConnected(target)
        let on = usable && light.lookOf(target).power != false
        Button {
            light.setPower(!on, for: target)
        } label: {
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule()
                    .fill(onColor ? Color(rgb: 0x14130E, opacity: 0.85) : Color(rgb: 0x2A2822))
                Circle()
                    .fill(on ? Theme.accent : Color(rgb: 0x8A8678))
                    .frame(width: 26, height: 26)
                    .shadow(color: on ? Theme.accent.opacity(0.85) : .clear, radius: 8)
                    .padding(4)
            }
            .frame(width: 58, height: 34)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: on)
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .disabled(!usable)
        .opacity(usable ? 1 : 0.4)
        .sensoryFeedback(.impact(weight: .medium), trigger: on)
        .accessibilityLabel(on ? "Ausschalten" : "Einschalten")
    }
}

/// Großer Regler 0…100 (Helligkeit, Tempo): gelbe Füllung mit Griff, große Zahl; ziehen oder antippen
struct LEDMeter: View {
    let label: String
    let value: Int
    let onChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(label)
                    .font(.geist(17, 700))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                Text("\(value)")
                    .font(.geistMono(30, 800))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.snappy(duration: 0.2), value: value)
                Text("%")
                    .font(.geistMono(14, 700))
                    .foregroundStyle(Theme.muted)
            }
            MeterBar(value: value)
                .overlay {
                    DragStrip { f in
                        let v = Int((f * 100).rounded())
                        if v != value { onChange(v) }
                    }
                }
        }
        .tile()
        .sensoryFeedback(.selection, trigger: value / 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) Prozent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(value + 10, 100))
            case .decrement: onChange(max(value - 10, 0))
            @unknown default: break
            }
        }
    }
}

/// Die Leiste des Reglers
private struct MeterBar: View {
    let value: Int

    private static let height: CGFloat = 46

    var body: some View {
        GeometryReader { geo in
            let fill: CGFloat = Self.fill(value, geo.size.width)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.accent.opacity(0.7), Theme.accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fill)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 10)
                Capsule()
                    .fill(Theme.ink.opacity(0.5))
                    .frame(width: 4, height: 20)
                    .offset(x: fill - 14)
            }
        }
        .frame(height: Self.height)
        .animation(.easeOut(duration: 0.08), value: value)
    }

    /// Breite der Füllung; der Griff bleibt auch bei 0 sichtbar
    private static func fill(_ value: Int, _ width: CGFloat) -> CGFloat {
        let k: CGFloat = CGFloat(min(max(value, 0), 100)) / 100
        return max(height - 10, width * k)
    }
}

/// Kleiner runder Knopf (Prüfen, Farbwähler …)
struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.text)
            .environment(\.iconTint, Theme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Großer gelber Hauptknopf
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Face(pressed: configuration.isPressed, label: configuration.label)
    }

    private struct Face: View {
        let pressed: Bool
        let label: ButtonStyleConfiguration.Label

        @Environment(\.isEnabled) private var enabled

        var body: some View {
            label
                .font(.geist(16, 700))
                .foregroundStyle(Theme.ink)
                .environment(\.iconTint, Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.accent.opacity(enabled ? 0.35 : 0), radius: 14)
                .scaleEffect(pressed ? 0.97 : 1)
                .opacity(enabled ? 1 : 0.4)
                .animation(.easeOut(duration: 0.12), value: pressed)
        }
    }
}

/// Gelbes Schild „LÄUFT“ mit kleinen tanzenden Balken
struct LiveTag: View {
    var body: some View {
        HStack(spacing: 6) {
            Clock { t in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(Theme.ink)
                            .frame(width: 2.5, height: Self.bar(i, t))
                    }
                }
                .frame(height: 11, alignment: .bottom)
            }
            .frame(width: 12, height: 11)
            Text("LÄUFT")
                .font(.geistMono(10, 700))
                .tracking(1.2)
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.accent, in: Capsule())
        .shadow(color: Theme.accent.opacity(0.6), radius: 8)
        .accessibilityLabel("Läuft")
    }

    private static func bar(_ i: Int, _ t: Double) -> CGFloat {
        let speed: Double = 3 + Double(i) * 1.2
        let swing: Double = abs(sin(t * speed + Double(i)))
        return CGFloat(3 + 8 * swing)
    }
}

// MARK: - Szenen

/// Szene als kleines Poster mit laufendem Bild (wie die Stimmungen im Hauptmenü)
struct SceneCard: View {
    let scene: LightScene
    let on: Bool
    let action: () -> Void

    static let height: CGFloat = 168

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                MoodArtView(art: MoodArt.style(for: scene))
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.65)], startPoint: UnitPoint(x: 0.5, y: 0.35), endPoint: .bottom)
                VStack(alignment: .leading, spacing: 5) {
                    Text(scene.name)
                        .font(.geist(19, 800))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(scene.summary.uppercased())
                        .font(.geistMono(10, 600))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(14)
            }
            .frame(height: Self.height)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(on ? Theme.accent : Theme.edge, lineWidth: on ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if on { LiveTag().padding(10) }
            }
            .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .accessibilityLabel("Szene \(scene.name)")
        .accessibilityValue(on ? "Läuft" : "")
    }
}
