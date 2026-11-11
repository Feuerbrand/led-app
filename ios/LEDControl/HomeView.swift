import SwiftUI

/// Hauptmenü: die Lichter als Liste (antippen öffnet die Steuerung), darunter die Szenen
/// und unten fest „Alle aus“ und „Alle steuern“. Szenen liegen auf der Lichtseite.
struct HomeView: View {
    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var adding = false

    var body: some View {
        let hub = light.hub
        let mine = hub.mine
        let filled = !mine.isEmpty || light.demo
        Page {
            HomeHeader(adding: $adding)

            UpdateBanner().rise(1)

            if hub.bluetooth != .ready && hub.bluetooth != .starting && !light.demo {
                BluetoothProblem(state: hub.bluetooth).rise(1)
            }

            if !filled {
                EmptyHome(adding: $adding).rise(2)
            } else {
                LightList(lights: mine)
                    .padding(.top, 20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if filled { HomeDock() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(alignment: .top) { HomeGlow() }
        .pageBackground()
        .sheet(isPresented: $adding) {
            AddLightSheet()
        }
        .onAppear { light.select(.all) }
        .onChange(of: nav.addLight, initial: true) { _, wanted in
            if wanted {
                nav.addLight = false
                adding = true
            }
        }
    }
}

// MARK: - Kopf

private struct HomeHeader: View {
    @Binding var adding: Bool

    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav

    private var status: String {
        let hub = light.hub
        let mine = hub.mine
        if light.demo && mine.isEmpty { return "Vorführmodus" }
        switch hub.bluetooth {
        case .off: return "Bluetooth aus"
        case .denied: return "Bluetooth nicht erlaubt"
        case .unsupported: return "Kein Bluetooth"
        case .starting: return "Startet"
        case .ready: break
        }
        if mine.isEmpty { return hub.setupDone ? "Noch kein Licht" : "Sucht" }
        if !light.demo && hub.targets.isEmpty { return "Verbindet" }
        let on = mine.filter { light.isLive(.light($0.id)) }.count
        return "\(on) von \(mine.count) an"
    }

    var body: some View {
        let count = light.hub.mine.count
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                StatusLED(state: light.link)
                Text(status.uppercased())
                    .font(.geistMono(12, 500))
                    .tracking(1.8)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: status)
                Spacer(minLength: 8)
                RoundIconButton(symbol: "plus", label: "Licht hinzufügen") { adding = true }
                RoundIconButton(symbol: "gearshape", label: "Einstellungen") { nav.path.append(.settings) }
            }
            Text(count == 1 ? "Mein Licht" : "Meine Lichter")
                .font(.geist(36, 800))
                .foregroundStyle(Theme.text)
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.horizontal, 4)
        .rise(0)
    }
}

/// Runder Knopf mit Symbol (Kopf des Hauptmenüs)
struct RoundIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.07), in: Circle())
                .overlay { Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel(label)
        .accessibilityIdentifier(label)
    }
}

/// Leichtes Leuchten oben in der Farbe des ersten eingeschalteten Lichts
private struct HomeGlow: View {
    @Environment(LightController.self) private var light

    private var tint: RGB? {
        let mine = light.hub.mine
        if mine.isEmpty { return light.isLive(.all) ? light.glow(.all) : nil }
        for item in mine where light.isLive(.light(item.id)) {
            return light.glow(.light(item.id))
        }
        return nil
    }

    var body: some View {
        let c: Color = tint?.color ?? Color.clear
        RadialGradient(colors: [c.opacity(0.22), c.opacity(0)],
                       center: UnitPoint(x: 0.25, y: 0.15), startRadius: 0, endRadius: 420)
            .frame(height: 560)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: tint?.hex ?? "")
            .allowsHitTesting(false)
    }
}

// MARK: - Lichter

private struct LightList: View {
    let lights: [Light]

    var body: some View {
        VStack(spacing: 12) {
            if lights.isEmpty {
                LightRow(target: .all, item: nil).enter(0)
            } else {
                ForEach(Array(lights.enumerated()), id: \.element.id) { index, item in
                    LightRow(target: .light(item.id), item: item).enter(index)
                }
            }
        }
    }
}

/// Ein Licht als Zeile: Farbe, Name, Zustand und Schalter; eingeschaltet mit Helligkeit zum Ziehen.
/// Antippen öffnet die Steuerung, gedrückt halten zeigt das Menü.
private struct LightRow: View {
    let target: Target
    let item: Light?

    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav

    private var stateText: String {
        let look = light.lookOf(target)
        if let item {
            if !item.enabled { return "Getrennt" }
            switch item.state {
            case .busy: return item.rssi == nil ? "Nicht in Reichweite" : "Verbindet …"
            case .off: return "Getrennt"
            case .on: break
            }
        }
        if look.power == false { return "Aus" }
        let percent = " · \(look.brightness) %"
        if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) { return flow.name + percent }
        if look.builtin != nil { return "Effekt" + percent }
        if light.goodnight != nil { return "Gute Nacht" + percent }
        if light.sunrise != nil { return "Sonnenaufgang" }
        return ColorName.of(look.base) + percent
    }

    var body: some View {
        let look = light.lookOf(target)
        let live: Bool = light.isLive(target)
        let glow: RGB = light.glow(target)
        let tint: Color = glow.color
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    nav.path.append(.control(target))
                } label: {
                    HStack(spacing: 14) {
                        RowBulb(color: glow, live: live)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item?.title ?? "Alle Lichter")
                                .font(.geist(18, 700))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Text(stateText)
                                .font(.geist(14, 500))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.2), value: stateText)
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.98))
                PowerSwitch(target: target)
            }
            if live {
                CardBrightness(value: look.brightness, color: tint) { light.setBrightness($0, for: target) }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background { RowBackground(color: tint, live: live) }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(live ? tint.opacity(0.4) : Theme.edge, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.3), value: live)
        .modifier(LightMenu(item: item))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item?.title ?? "Alle Lichter"), \(stateText)")
    }
}

/// Fläche einer Zeile: eingeschaltet ein Schimmer in der Farbe des Lichts
private struct RowBackground: View {
    let color: Color
    let live: Bool

    var body: some View {
        ZStack {
            Theme.card
            if live {
                LinearGradient(colors: [color.opacity(0.32), color.opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .transition(.opacity)
            }
        }
    }
}

/// Farbiges Lämpchen links in der Zeile
private struct RowBulb: View {
    let color: RGB
    let live: Bool

    var body: some View {
        let dark: Bool = CardPalette.darkText([color])
        let fill: Color = live ? color.color : Color(rgb: 0x24221C)
        let ink: Color = live ? (dark ? Theme.ink : .white) : Theme.muted
        Image(systemName: live ? "lightbulb.fill" : "lightbulb.slash")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(ink)
            .frame(width: 48, height: 48)
            .background(fill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: live ? color.color.opacity(0.6) : .clear, radius: 12)
    }
}

/// Name einer Farbe zum Anzeigen („Pink“, „Warmweiß“ …)
enum ColorName {
    static func of(_ c: RGB) -> String {
        let mx = Double(max(c.r, c.g, c.b))
        let mn = Double(min(c.r, c.g, c.b))
        let saturation: Double = mx > 0 ? (mx - mn) / mx : 0
        if saturation < 0.2 { return c.r > c.b + 20 ? "Warmweiß" : "Weiß" }
        if saturation < 0.45 && c.r > c.b { return "Warmweiß" }
        let hue = ColorMath.hue(of: c)
        if hue < 15 || hue >= 345 { return "Rot" }
        if hue < 42 { return "Orange" }
        if hue < 70 { return "Gelb" }
        if hue < 160 { return "Grün" }
        if hue < 200 { return "Türkis" }
        if hue < 250 { return "Blau" }
        if hue < 290 { return "Lila" }
        return "Pink"
    }
}

// MARK: - Unten: alle Lichter

private struct HomeDock: View {
    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav

    var body: some View {
        let usable = light.demo || light.isConnected(.all)
        let lights = light.lightsOf(.all)
        let anyOn = lights.isEmpty ? light.isLive(.all) : lights.contains { light.isLive(.light($0.id)) }
        HStack(spacing: 10) {
            Button {
                light.setPower(!anyOn, for: .all)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(anyOn ? Theme.text : Theme.accent)
                    Text(anyOn ? "Alle aus" : "Alle an")
                        .font(.geist(16, 600))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.interpolate)
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressStyle(scale: 0.96))
            .disabled(!usable)
            .opacity(usable ? 1 : 0.4)
            .sensoryFeedback(.impact(weight: .heavy), trigger: anyOn)

            Button {
                nav.path.append(.control(.all))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .bold))
                    Text("Alle steuern")
                        .font(.geist(16, 700))
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressStyle(scale: 0.96))
            .accessibilityIdentifier("alle-steuern")
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Bausteine (auch für die Steuerseite)

/// Farben einer Karte: laufender Effekt, eingebauter Effekt oder die Farbe, in der das Licht gerade leuchtet
enum CardPalette {
    static func colors(look: LightLook, glow: RGB) -> [RGB] {
        if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) {
            return flowColors(flow, base: look.base)
        }
        if look.builtin != nil { return builtin }
        return shades(glow)
    }

    /// Farben eines Effekts (für Karten und Effekt-Kacheln)
    static func flowColors(_ flow: Flow, base: RGB) -> [RGB] {
        switch flow.kind {
        case .rainbow, .palette: return flow.previewStops
        case .music: return Flow.all[0].previewStops
        case .candle: return [RGB(255, 176, 70), RGB(255, 118, 28), RGB(232, 74, 12)]
        case .breathe: return shades(base)
        }
    }

    /// Eingebaute Effekte: bunte Mischung
    static let builtin: [RGB] = [RGB(255, 45, 106), RGB(255, 138, 0), RGB(47, 212, 255), RGB(193, 60, 255)]

    static func shades(_ c: RGB) -> [RGB] {
        [c.toward(.white, 0.4), c, c.scaled(0.8), c.toward(.white, 0.18)]
    }

    /// Dunkle Schrift auf hellen Karten, helle Schrift auf dunklen
    static func darkText(_ colors: [RGB]) -> Bool {
        guard !colors.isEmpty else { return false }
        var sum: Double = 0
        for c in colors { sum += c.perceived }
        return sum / Double(colors.count) > 0.45
    }
}

/// Laufende Fläche einer Karte: wandernder Farbverlauf, Lichtreflex, feine Linien
struct CardSurface: View {
    let colors: [RGB]
    let brightness: Int
    let seed: Double

    var body: some View {
        let stops: [Color] = Self.loop(colors)
        Clock { t in
            GeometryReader { geo in
                let w: CGFloat = geo.size.width
                let h: CGFloat = geo.size.height
                let flow: Double = ((t + seed * 3) / 9).truncatingRemainder(dividingBy: 1)
                let shift: CGFloat = -w * CGFloat(flow)
                let sheenX: CGFloat = w * Self.sheen(t + seed)
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: w * 2, height: h)
                        .offset(x: shift)
                    // Lichtreflex: läuft alle fünf Sekunden über die Karte
                    LinearGradient(colors: [Color.clear, Color.white.opacity(0.3), Color.clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 90, height: h * 1.8)
                        .rotationEffect(.degrees(18))
                        .position(x: sheenX, y: h / 2)
                }
            }
        }
        .overlay { Grain() }
        .overlay { Color.black.opacity(Self.dim(brightness)) }
        .allowsHitTesting(false)
    }

    /// Farben zweimal hintereinander, damit der Verlauf beim Wandern nahtlos weiterläuft
    private static func loop(_ colors: [RGB]) -> [Color] {
        let base: [RGB] = colors.isEmpty ? [RGB(40, 40, 40)] : colors
        var all: [RGB] = base
        all.append(contentsOf: base)
        all.append(base[0])
        return all.map { $0.color }
    }

    /// Stelle des Lichtreflexes (Anteil der Breite): läuft in 3 s über die Karte, dann 2 s Pause
    private static func sheen(_ t: Double) -> CGFloat {
        let s: Double = (t / 5).truncatingRemainder(dividingBy: 1)
        let k: Double = min(s / 0.6, 1)
        return CGFloat(-0.3 + k * 1.6)
    }

    /// Dunkler bei wenig Helligkeit
    private static func dim(_ brightness: Int) -> Double {
        let b: Double = Double(min(max(brightness, 0), 100)) / 100
        return (1 - b) * 0.4
    }
}

/// Feine waagerechte Linien wie auf einer bedruckten Karte
private struct Grain: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white.opacity(0.035)))
                y += 3
            }
        }
        .allowsHitTesting(false)
    }
}

/// Helligkeit direkt auf der Karte: über die Leiste ziehen oder tippen
struct CardBrightness: View {
    let value: Int
    let color: Color
    let onChange: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.22))
                Capsule()
                    .fill(color.opacity(0.88))
                    .frame(width: max(6, geo.size.width * CGFloat(value) / 100))
            }
            .frame(height: 6)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 22)
        .contentShape(Rectangle())
        .overlay {
            DragStrip { f in
                let v = Int((f * 100).rounded())
                if v != value { onChange(v) }
            }
        }
        .animation(.easeOut(duration: 0.08), value: value)
        .sensoryFeedback(.selection, trigger: value / 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Helligkeit")
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

/// Gedrückt halten: blinken lassen, umbenennen, trennen, entfernen
private struct LightMenu: ViewModifier {
    let item: Light?

    @Environment(LightController.self) private var light
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmRemove = false

    func body(content: Content) -> some View {
        if let item {
            content
                .contextMenu {
                    Button {
                        light.identify(item)
                    } label: {
                        Label("Blinken lassen", systemImage: "light.max")
                    }
                    .disabled(item.state != .on)
                    Button {
                        newName = item.title
                        renaming = true
                    } label: {
                        Label("Umbenennen", systemImage: "pencil")
                    }
                    Button {
                        light.hub.setEnabled(item, !item.enabled)
                    } label: {
                        Label(item.enabled ? "Trennen" : "Verbinden", systemImage: item.enabled ? "bolt.slash" : "bolt")
                    }
                    Button(role: .destructive) {
                        confirmRemove = true
                    } label: {
                        Label("Entfernen", systemImage: "trash")
                    }
                }
                .alert("Licht umbenennen", isPresented: $renaming) {
                    TextField(item.name, text: $newName)
                    Button("Sichern") { light.hub.rename(item, to: newName == item.name ? "" : newName) }
                    Button("Abbrechen", role: .cancel) {}
                } message: {
                    Text("Gerätename: \(item.name)")
                }
                .confirmationDialog("\(item.title) entfernen?", isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button("Entfernen", role: .destructive) { light.hub.remove(item) }
                    Button("Abbrechen", role: .cancel) {}
                } message: {
                    Text("Die Verbindung wird getrennt. Du kannst das Licht jederzeit wieder hinzufügen.")
                }
        } else {
            content
        }
    }
}

/// Karte von unten hereinschieben (beim Start eine nach der anderen)
private struct CardEnter: ViewModifier {
    let index: Int

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var still

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 80)
            .scaleEffect(shown ? 1 : 0.94)
            .onAppear {
                if shown { return }
                if still {
                    shown = true
                } else {
                    let first = Date().timeIntervalSince(Intro.start) < 2
                    withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.9).delay((first ? 0.35 : 0.05) + Double(index) * 0.08)) {
                        shown = true
                    }
                }
            }
    }
}

private extension View {
    func enter(_ index: Int) -> some View { modifier(CardEnter(index: index)) }
}

// MARK: - Noch kein Licht

/// Noch kein Licht: Suche, Hinzufügen und Vorführmodus
private struct EmptyHome: View {
    @Binding var adding: Bool

    @Environment(LightController.self) private var light

    var body: some View {
        let searching = !light.hub.setupDone && light.hub.bluetooth == .ready
        VStack(alignment: .leading, spacing: 14) {
            if searching {
                ScannerLEDs()
            } else {
                LEDPanel(colors: [RGB(255, 210, 63)], live: false, rows: 1)
            }
            Text(searching ? "Suche deine LED-Leiste" : "Noch kein Licht")
                .font(.geist(22, 700))
                .foregroundStyle(Theme.text)
            Text(searching
                 ? "Die erste ELK-Leiste in der Nähe übernimmt die App automatisch. Andere Licht-Apps vorher ganz schließen."
                 : "Licht einschalten, in die Nähe gehen und andere Licht-Apps ganz schließen. Dann hier hinzufügen.")
                .font(.geist(13, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
            Button {
                adding = true
            } label: {
                HStack(spacing: 8) {
                    Icon(kind: .plus, size: 15)
                    Text("Licht hinzufügen")
                }
            }
            .buttonStyle(AccentButtonStyle())
            .padding(.top, 4)
            Button {
                withAnimation(.easeOut(duration: 0.3)) { light.setDemo(true) }
            } label: {
                Text("Ohne Licht ausprobieren")
            }
            .buttonStyle(OutlineButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .padding(.top, 22)
    }
}

// MARK: - Update-Hinweis

struct UpdateBanner: View {
    @Environment(Updater.self) private var updater
    @Environment(Navigator.self) private var nav

    var body: some View {
        if let release = updater.available {
            Button {
                nav.path.append(.settings)
            } label: {
                HStack(spacing: 12) {
                    Icon(kind: .download, size: 18, color: Theme.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update \(release.version)")
                            .font(.geist(15, 600))
                        Text("ANTIPPEN FÜR DIE ANLEITUNG")
                            .font(.geistMono(10, 600))
                            .tracking(1)
                    }
                    .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .padding(.top, 16)
        }
    }
}
