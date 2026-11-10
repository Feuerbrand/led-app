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
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 32, trailing: 16))
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

/// Große Überschrift einer Seite
struct PageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.geist(26, 700))
                .tracking(2)
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.geist(13, 400))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .padding(.horizontal, 4)
        .rise(0)
    }
}

/// Warmes Schwarz mit Lichtpunkten hinter jeder Seite
struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Backdrop()
                    ParticleField()
                }
                .ignoresSafeArea()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

extension View {
    func pageBackground() -> some View { modifier(PageBackground()) }
}

// MARK: - Status

/// Punkt vor dem Status: grau = getrennt, gelb mit Ringen = sucht (schnell) oder verbunden (ruhig)
struct StatusDot: View {
    let state: LinkState

    var body: some View {
        Circle()
            .fill(state == .off ? Color.white.opacity(0.25) : Theme.accent)
            .frame(width: 9, height: 9)
            .shadow(color: Theme.accent.opacity(state == .on ? 0.8 : 0), radius: 5)
            .background {
                if state != .off {
                    let period = state == .on ? 3.0 : 1.3
                    Clock { t in
                        let p = t.truncatingRemainder(dividingBy: period) / period
                        let out = 1 - (1 - p) * (1 - p)
                        Circle()
                            .strokeBorder(Theme.accent, lineWidth: 1.5)
                            .frame(width: 12, height: 12)
                            .scaleEffect(CGFloat(1 + 2.6 * out))
                            .opacity(0.9 * (1 - out))
                    }
                }
            }
    }
}

/// Laufender Lichtstreifen um eine Kachel, solange gesucht oder verbunden wird
struct ScanBorder: View {
    var radius: CGFloat = 8

    var body: some View {
        Clock { t in
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(
                    AngularGradient(
                        stops: [
                            .init(color: Theme.accent.opacity(0), location: 0),
                            .init(color: Theme.accent.opacity(0), location: 0.6),
                            .init(color: Theme.accent, location: 0.92),
                            .init(color: Theme.accent.opacity(0), location: 1),
                        ],
                        center: .center,
                        angle: .degrees((t / 1.5 * 360).truncatingRemainder(dividingBy: 360))),
                    lineWidth: Theme.border)
        }
        .allowsHitTesting(false)
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
                RoundedRectangle(cornerRadius: 1)
                    .fill(i <= level ? Theme.text : Color.white.opacity(0.18))
                    .frame(width: 3, height: CGFloat(4 + i * 3))
            }
        }
        .frame(height: 14, alignment: .bottom)
        .accessibilityLabel(level == 0 ? "Kein Empfang" : "Empfang \(level) von 3")
    }
}

/// Kleiner, sich drehender Bogen: „sucht gerade“
struct SearchingMark: View {
    var body: some View {
        Clock { t in
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees((t * 300).truncatingRemainder(dividingBy: 360)))
        }
        .accessibilityLabel("Sucht")
    }
}

/// Grauer Hinweistext unter oder zwischen Kacheln
struct Hint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.geist(12, 400))
            .foregroundStyle(Theme.muted)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
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
                Icon(kind: .bluetooth, size: 17, color: Theme.accent)
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

// MARK: - Knöpfe

/// Kleiner Knopf mit gelbem Rahmen (Hinzufügen, Prüfen …)
struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.text)
            .environment(\.iconTint, Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Theme.hot : Theme.fill, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.accent, lineWidth: Theme.border)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
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
                .font(.geist(16, 600))
                .foregroundStyle(Color(rgb: 0x14130E))
                .environment(\.iconTint, Color(rgb: 0x14130E))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: Theme.accent.opacity(pressed ? 0.2 : 0.45), radius: pressed ? 6 : 16)
                .scaleEffect(pressed ? 0.97 : 1)
                .opacity(enabled ? 1 : 0.4)
                .animation(.easeOut(duration: 0.12), value: pressed)
        }
    }
}

/// Runder Knopf mit Symbol (Kopfzeile des Hauptmenüs)
struct CircleIconButton: View {
    let icon: IconKind
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(kind: icon, size: 19, color: Theme.text)
                .frame(width: 44, height: 44)
                .background(Theme.fill, in: Circle())
                .overlay { Circle().strokeBorder(Theme.soft, lineWidth: Theme.border) }
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel(label)
    }
}

// MARK: - Lampe als kleines Symbol

/// Kleine Lampe, die in der Farbe des Lichts leuchtet (Karten im Hauptmenü)
struct LampBadge: View {
    let color: RGB
    let live: Bool
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            BulbGlass().fill(live ? color.color : Theme.text.opacity(0.35))
            BulbBase().fill(Theme.icon.opacity(live ? 1 : 0.5))
        }
        .frame(width: size, height: size)
        .shadow(color: color.color.opacity(live ? 0.9 : 0), radius: size * 0.25)
        .shadow(color: color.color.opacity(live ? 0.5 : 0), radius: size * 0.6)
    }
}

// MARK: - Vorschauen der Effekte

struct FlowPreview: View {
    let flow: Flow
    let on: Bool
    let t: Double
    let pick: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                Color(rgb: 0x0B0A07)
                switch flow.kind {
                case .breathe:
                    // Die gewählte Farbe, langsam heller und dunkler
                    let period = on ? 1.8 : 3.2
                    pick.opacity(0.65 - 0.35 * cos(t * 2 * Double.pi / period))
                case .candle:
                    Rectangle()
                        .fill(EllipticalGradient(
                            stops: [
                                .init(color: Color(rgb: 0xFFC46B), location: 0),
                                .init(color: Color(rgb: 0xFF7D1A), location: 0.46),
                                .init(color: Color(rgb: 0x6B2400), location: 1),
                            ],
                            center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
                        .frame(width: w * 1.6, height: h * 2.6)
                        .position(x: w * 0.5, y: h * 1.15)
                        .opacity(Self.flicker(t, period: on ? 1.8 : 2.6))
                case .music:
                    MusicBars(t: t, fast: on)
                case .rainbow, .palette:
                    // Farbverlauf, der endlos nach links durchläuft
                    let period = on ? 4.0 : 10.0
                    let p = t.truncatingRemainder(dividingBy: period) / period
                    LinearGradient(colors: Self.loop(flow.previewStops), startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 2, height: h)
                        .offset(x: -w * CGFloat(p))
                }
                // Glanz von oben, Schatten unten
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.16), location: 0),
                        .init(color: Color.white.opacity(0), location: 0.42),
                        .init(color: Color.black.opacity(0.28), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Zwei Durchläufe hintereinander, damit die Verschiebung um einen Durchlauf nahtlos ist
    private static func loop(_ stops: [RGB]) -> [Color] {
        let once = stops.map { $0.color }
        guard let first = once.first else { return [.black, .black] }
        return once + once + [first]
    }

    /// Unruhiges Flackern der Kerze (Helligkeit über einen Durchlauf)
    private static func flicker(_ t: Double, period: Double) -> Double {
        let keys: [(Double, Double)] = [(0, 0.78), (0.18, 1), (0.31, 0.6), (0.47, 0.92), (0.63, 0.7), (0.82, 0.98), (1, 0.78)]
        let p = t.truncatingRemainder(dividingBy: period) / period
        for i in 1..<keys.count where p <= keys[i].0 {
            let a = keys[i - 1]
            let b = keys[i]
            let k = ColorMath.ease((p - a.0) / (b.0 - a.0))
            return a.1 + (b.1 - a.1) * k
        }
        return 0.78
    }
}

/// Vorschau des Musik-Modus: bunte Balken, die auf und ab springen
struct MusicBars: View {
    let t: Double
    let fast: Bool

    var body: some View {
        let speed = fast ? 1.6 : 0.8
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<12, id: \.self) { i in
                let x = Double(i)
                let a = sin(t * speed * 5.1 + x * 0.9)
                let b = sin(t * speed * 3.3 + x * 1.7)
                let level = 0.25 + 0.75 * abs(a * 0.6 + b * 0.4)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(ColorMath.hsv((x / 12 * 300 + t * 20).truncatingRemainder(dividingBy: 360), 1, 1).color)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .scaleEffect(x: 1, y: CGFloat(level), anchor: .bottom)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 6)
    }
}

/// Drei tanzende Balken neben dem Namen des laufenden Effekts
struct EqBars: View {
    let t: Double

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                let wave = cos((t + Double(i) * 0.3) * 2 * Double.pi / 0.9)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.accent)
                    .frame(width: 3, height: 12)
                    .scaleEffect(x: 1, y: CGFloat(0.625 - 0.375 * wave), anchor: .bottom)
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Szenen

struct SceneCard: View {
    let scene: LightScene
    let on: Bool
    let action: () -> Void

    private var flow: Flow? {
        guard let id = scene.flowID else { return nil }
        return Flow.all.first { $0.id == id }
    }

    private var fill: AnyShapeStyle {
        if let flow {
            let stops = flow.previewStops
            if stops.count > 1 {
                return AnyShapeStyle(LinearGradient(colors: stops.map { $0.color }, startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            if flow.kind == .candle {
                return AnyShapeStyle(LinearGradient(colors: [Color(rgb: 0xFFC46B), Color(rgb: 0xFF7D1A), Color(rgb: 0x6B2400)],
                                                    startPoint: .top, endPoint: .bottom))
            }
        }
        return AnyShapeStyle(scene.color.color)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(fill)
                    .overlay {
                        LinearGradient(colors: [Color.white.opacity(0.18), Color.clear, Color.black.opacity(0.25)],
                                       startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .frame(height: 52)
                Spacer(minLength: 8)
                Text(scene.name)
                    .font(.geist(14, 600))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(flow.map { "\($0.name) · \(scene.brightness) %" } ?? "\(scene.brightness) %")
                    .font(.geist(11, 400))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(on ? Theme.accent : Theme.soft, lineWidth: Theme.border)
            }
            .shadow(color: scene.color.color.opacity(on ? 0.45 : 0), radius: 12)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Szene \(scene.name)")
    }
}
