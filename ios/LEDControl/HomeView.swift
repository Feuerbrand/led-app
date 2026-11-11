import SwiftUI

/// Hauptmenü: Stimmungen zum Wischen, die Lichter als Karten im Stapel (wie in der Wallet),
/// Schnellzugriffe und unten fest „Alle aus“ und „Alle Lichter“
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
                HomeLabel("Stimmungen · wischen").rise(2)
                MoodRail().rise(2)

                HomeLabel(mine.count == 1 ? "Mein Licht" : "Meine Lichter").rise(3)
                if mine.isEmpty {
                    LightCard(target: .all, item: nil, expanded: true, seed: 0) {
                        nav.path.append(.control(.all))
                    }
                    .enter(0)
                } else {
                    LightStack(lights: mine)
                }
                AddLightButton { adding = true }
                    .padding(.top, 12)
                    .rise(5)

                HomeLabel("Schnell").rise(5)
                QuickRow().rise(6)

                Hint(text: mine.count > 1
                     ? "Karte antippen holt sie nach vorne, nochmal antippen öffnet die Steuerung. Gedrückt halten: blinken, umbenennen, entfernen."
                     : "Karte antippen zum Steuern, über die Leiste ziehen für die Helligkeit. Gedrückt halten: blinken, umbenennen, entfernen.")
                    .padding(.top, 14)
                    .rise(7)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if filled { HomeDock() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .pageBackground()
        .sheet(isPresented: $adding) {
            AddLightSheet()
        }
        .onAppear { light.select(.all) }
    }
}

// MARK: - Kopf

private struct HomeHeader: View {
    @Binding var adding: Bool

    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav

    private static func greeting(_ date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return "Guten Morgen"
        case 11..<17: return "Guten Tag"
        case 17..<23: return "Guten Abend"
        default: return "Gute Nacht"
        }
    }

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
        let count = mine.count == 1 ? "1 Licht" : "\(mine.count) Lichter"
        if !light.demo && hub.targets.isEmpty { return count + " · verbindet" }
        let on = mine.filter { light.isLive(.light($0.id)) }.count
        return "\(count) · \(on) an"
    }

    var body: some View {
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
                RoundIconButton(icon: .plus, label: "Licht hinzufügen") { adding = true }
                RoundIconButton(icon: .sliders, label: "Einstellungen") { nav.path.append(.settings) }
            }
            Text(Self.greeting(Date()))
                .font(.geist(17, 500))
                .foregroundStyle(Theme.muted)
                .padding(.top, 18)
            Text("Was liegt an?")
                .font(.geist(36, 800))
                .foregroundStyle(Theme.text)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.horizontal, 4)
        .rise(0)
    }
}

/// Runder Knopf mit Symbol (Kopf des Hauptmenüs)
struct RoundIconButton: View {
    let icon: IconKind
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(kind: icon, size: 18, color: Theme.text)
                .frame(width: 44, height: 44)
                .background(Theme.panel, in: Circle())
                .overlay { Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5) }
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel(label)
    }
}

private struct HomeLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.geistMono(11, 600))
            .tracking(1.8)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 28, leading: 4, bottom: 12, trailing: 0))
    }
}

// MARK: - Stimmungen

private struct MoodItem: Identifiable {
    enum Kind {
        case scene(LightScene)
        case sunrise
        case create
    }

    let id: String
    let kind: Kind
}

/// Poster zum Wischen: die gespeicherten Szenen, der Sonnenaufgang und „Eigene Stimmung“
private struct MoodRail: View {
    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var current: String?
    @State private var removing: LightScene?

    private var items: [MoodItem] {
        var list: [MoodItem] = light.scenes.map { scene in MoodItem(id: scene.id.uuidString, kind: .scene(scene)) }
        list.append(MoodItem(id: "sunrise", kind: .sunrise))
        list.append(MoodItem(id: "create", kind: .create))
        return list
    }

    private func isActive(_ scene: LightScene) -> Bool {
        guard light.isLive(.all), light.sunrise == nil else { return false }
        let look = light.lookOf(.all)
        if let id = scene.flowID { return look.flowID == id }
        return look.flowID == nil && look.builtin == nil && look.base == scene.color
    }

    private static func subtitle(_ scene: LightScene) -> String {
        let what: String
        if let id = scene.flowID, let flow = Flow.everything.first(where: { $0.id == id }) {
            what = flow.name
        } else {
            what = scene.color.hex
        }
        return "\(what) · \(scene.brightness) %"
    }

    var body: some View {
        let all = items
        let shown = current ?? all.first?.id
        VStack(spacing: 16) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(all) { item in
                        poster(item)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(height: MoodPoster.size.height)
            .padding(.horizontal, -16)

            HStack(spacing: 6) {
                ForEach(all) { item in
                    Capsule()
                        .fill(item.id == shown ? Theme.accent : Color.white.opacity(0.25))
                        .frame(width: item.id == shown ? 22 : 6, height: 6)
                }
            }
            .animation(.snappy(duration: 0.25), value: shown)
            .accessibilityHidden(true)
        }
        .sensoryFeedback(.selection, trigger: current)
        .confirmationDialog("Stimmung „\(removing?.name ?? "")“ löschen?", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let scene = removing { light.deleteScene(scene) }
                removing = nil
            }
            Button("Abbrechen", role: .cancel) { removing = nil }
        }
    }

    @ViewBuilder
    private func poster(_ item: MoodItem) -> some View {
        switch item.kind {
        case .scene(let scene):
            MoodPoster(art: MoodArt.style(for: scene), title: scene.name, subtitle: Self.subtitle(scene),
                       active: isActive(scene)) {
                light.apply(scene, to: .all)
            }
            .contextMenu {
                Button(role: .destructive) {
                    removing = scene
                } label: {
                    Label("Stimmung löschen", systemImage: "trash")
                }
            }
        case .sunrise:
            MoodPoster(art: .dawn, title: "Aufwachen", subtitle: "Sonnenaufgang · 90 s",
                       active: light.sunrise != nil, ramp: light.sunrise) {
                light.startSunrise()
            }
        case .create:
            NewMoodPoster {
                nav.section = .scenes
                nav.path.append(.control(.all))
            }
        }
    }
}

// MARK: - Lichter als Kartenstapel

/// Karten übereinander wie in der Wallet: vorne die ganze Karte, dahinter schauen die Köpfe heraus.
/// Antippen holt eine Karte nach vorne, nochmal antippen öffnet die Steuerung.
private struct LightStack: View {
    let lights: [Light]

    @Environment(Navigator.self) private var nav
    @State private var front: UUID?

    static let peek: CGFloat = 80

    var body: some View {
        let frontID: UUID? = Self.frontID(front, lights)
        let order: [Light] = Self.order(lights, front: frontID)
        let height: CGFloat = CGFloat(max(order.count - 1, 0)) * Self.peek + LightCard.height
        ZStack(alignment: .top) {
            ForEach(Array(order.enumerated()), id: \.element.id) { index, item in
                let isFront = item.id == frontID
                LightCard(target: .light(item.id), item: item, expanded: isFront, seed: Double(index) * 1.7) {
                    if isFront {
                        nav.path.append(.control(.light(item.id)))
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { front = item.id }
                    }
                }
                .offset(y: CGFloat(index) * Self.peek)
                .zIndex(Double(index))
                .enter(index)
            }
        }
        .frame(height: height, alignment: .top)
        .sensoryFeedback(.selection, trigger: front)
    }

    /// Vordere Karte: die zuletzt angetippte, sonst das erste Licht
    private static func frontID(_ front: UUID?, _ lights: [Light]) -> UUID? {
        if let front, lights.contains(where: { $0.id == front }) { return front }
        return lights.first?.id
    }

    /// Reihenfolge im Stapel: die vordere Karte kommt nach unten (ganz sichtbar)
    private static func order(_ lights: [Light], front: UUID?) -> [Light] {
        var list: [Light] = lights.filter { $0.id != front }
        list.append(contentsOf: lights.filter { $0.id == front })
        return list
    }
}

/// Farben einer Karte: laufender Effekt, eingebauter Effekt oder die Farbe, in der das Licht gerade leuchtet
enum CardPalette {
    static func colors(look: LightLook, glow: RGB) -> [RGB] {
        if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) {
            switch flow.kind {
            case .rainbow, .palette: return flow.previewStops
            case .music: return Flow.all[0].previewStops
            case .candle: return [RGB(255, 176, 70), RGB(255, 118, 28), RGB(232, 74, 12)]
            case .breathe: return shades(look.base)
            }
        }
        if look.builtin != nil {
            return [RGB(255, 45, 106), RGB(255, 138, 0), RGB(47, 212, 255), RGB(193, 60, 255)]
        }
        return shades(glow)
    }

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

/// Eine Licht-Karte. Im Stapel ist nur der Kopf zu sehen, vorne die ganze Karte mit Helligkeit.
private struct LightCard: View {
    let target: Target
    let item: Light?
    let expanded: Bool
    /// Versatz für die Animation, damit nicht alle Karten gleichzeitig glänzen
    let seed: Double
    let action: () -> Void

    static let height: CGFloat = 228

    @Environment(LightController.self) private var light

    private var meta: String {
        guard let item else {
            return light.demo ? "Vorführmodus" : "Alle Lichter"
        }
        if let badge = item.model.pixels.badge { return "\(item.name) · \(badge)" }
        return item.name
    }

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
        if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) { return flow.name }
        if look.builtin != nil { return "Eingebauter Effekt" }
        if light.sunrise != nil { return "Sonnenaufgang" }
        return "Farbe \(light.glow(target).hex)"
    }

    var body: some View {
        let look = light.lookOf(target)
        let live = light.isLive(target)
        let colors = CardPalette.colors(look: look, glow: light.glow(target))
        let ink: Color = live ? (CardPalette.darkText(colors) ? Theme.ink : .white) : Theme.text
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                if live {
                    CardSurface(colors: colors, brightness: look.brightness, seed: seed)
                        .transition(.opacity)
                } else {
                    Color(rgb: 0x191813)
                }
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(meta.uppercased())
                            .font(.geistMono(11, 600))
                            .tracking(1.6)
                            .foregroundStyle(ink.opacity(0.7))
                            .lineLimit(1)
                        Text(item?.title ?? "Alle Lichter")
                            .font(.geist(26, 800))
                            .foregroundStyle(live ? ink : Theme.text.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(.trailing, 72)
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(stateText)
                                .font(.geist(15, 700))
                                .foregroundStyle(live ? ink : Theme.muted)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if live {
                                HStack(alignment: .lastTextBaseline, spacing: 1) {
                                    Text("\(look.brightness)")
                                        .font(.geistMono(34, 800))
                                        .contentTransition(.numericText(value: Double(look.brightness)))
                                        .animation(.snappy(duration: 0.2), value: look.brightness)
                                    Text("%")
                                        .font(.geistMono(15, 700))
                                }
                                .foregroundStyle(ink)
                            } else if let item, item.state == .on || item.rssi != nil {
                                SignalBars(rssi: item.rssi)
                            }
                        }
                        // Platz für die Helligkeits-Leiste (liegt als eigene Fläche darüber)
                        Color.clear.frame(height: live ? 22 : 0)
                    }
                    .opacity(expanded ? 1 : 0)
                }
                .padding(20)
            }
            .frame(height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(live ? 0.14 : 0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.55), radius: 20, y: 14)
            .animation(.easeInOut(duration: 0.35), value: live)
        }
        .buttonStyle(PressStyle(scale: 0.985))
        .overlay(alignment: .topTrailing) {
            CardSwitch(target: target, onColor: live)
                .padding(18)
        }
        .overlay(alignment: .bottom) {
            if expanded && live {
                CardBrightness(value: look.brightness, color: ink) { light.setBrightness($0, for: target) }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .modifier(LightMenu(item: item))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item?.title ?? "Alle Lichter"), \(stateText)")
    }
}

/// Laufende Fläche einer Karte: wandernder Farbverlauf, Lichtreflex, feine Linien
private struct CardSurface: View {
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

/// Schalter auf der Karte: dunkle Kapsel, gelber leuchtender Knopf
private struct CardSwitch: View {
    let target: Target
    let onColor: Bool

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

/// Helligkeit direkt auf der Karte: über die Leiste ziehen oder tippen
private struct CardBrightness: View {
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

private struct AddLightButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Icon(kind: .plus, size: 18, color: Theme.accent)
                Text("Licht hinzufügen")
                    .font(.geist(15, 600))
                    .foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}

// MARK: - Schnellzugriffe

private struct QuickRow: View {
    @Environment(LightController.self) private var light
    @State private var askTimer = false
    @State private var rolls = 0

    var body: some View {
        let usable = light.demo || light.isConnected(.all)
        let music = light.isLive(.all) && light.lookOf(.all).flowID == Flow.music.id
        let timer = light.sleepTimer
        HStack(spacing: 10) {
            QuickTile(icon: .speed, title: "Timer", on: timer != nil, action: { askTimer = true }) {
                if let timer {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = max(0, Int(timer.end.timeIntervalSince(context.date).rounded(.up)))
                        Text(String(format: "%d:%02d", left / 60, left % 60))
                            .font(.geistMono(13, 700))
                            .monospacedDigit()
                    }
                } else {
                    Text("Aus").font(.geist(12, 500))
                }
            } badge: {
                if let timer {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        TimerRing(left: 1 - timer.progress(at: context.date))
                    }
                }
            }

            QuickTile(icon: .music, title: "Musik", on: music, action: {
                light.toggleFlow(Flow.music, for: .all)
            }) {
                Text(music ? "Im Takt" : "Mikrofon").font(.geist(12, 500))
            } badge: {
                if music { DancingBars() }
            }

            QuickTile(icon: .dice, title: "Würfeln", on: false, iconTurn: Double(rolls) * 360, action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { rolls += 1 }
                light.shuffleColors()
            }) {
                Text("Neue Farben").font(.geist(12, 500))
            } badge: {
                EmptyView()
            }
        }
        .disabled(!usable)
        .opacity(usable ? 1 : 0.4)
        .sensoryFeedback(.impact(weight: .light), trigger: rolls)
        .confirmationDialog("Timer", isPresented: $askTimer, titleVisibility: .visible) {
            ForEach([15, 30, 60, 90], id: \.self) { minutes in
                Button(Self.label(minutes)) {
                    light.startSleepTimer(minutes: minutes)
                }
            }
            if timer != nil {
                Button("Timer beenden", role: .destructive) { light.cancelSleepTimer() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Danach gehen alle Lichter aus. Lass die App dafür offen – der Bildschirm bleibt so lange an.")
        }
    }

    private static func label(_ minutes: Int) -> String {
        if minutes == 60 { return "1 Stunde" }
        if minutes == 90 { return "1,5 Stunden" }
        return "\(minutes) Minuten"
    }
}

private struct QuickTile<Value: View, Badge: View>: View {
    let icon: IconKind
    let title: String
    let on: Bool
    var iconTurn: Double = 0
    let action: () -> Void
    @ViewBuilder let value: () -> Value
    @ViewBuilder let badge: () -> Badge

    var body: some View {
        let ink = on ? Theme.ink : Theme.text
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Icon(kind: icon, size: 21, color: on ? Theme.ink : Theme.accent)
                        .rotationEffect(.degrees(iconTurn))
                    Spacer(minLength: 4)
                    badge()
                }
                Spacer(minLength: 10)
                Text(title)
                    .font(.geist(15, 700))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                value()
                    .foregroundStyle(on ? Theme.ink.opacity(0.75) : Theme.muted)
                    .lineLimit(1)
                    .padding(.top, 3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
            .background(on ? Theme.accent : Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(on ? 0 : 0.1), lineWidth: 1.5)
            }
            .shadow(color: Theme.accent.opacity(on ? 0.4 : 0), radius: 16)
            .animation(.easeOut(duration: 0.25), value: on)
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .accessibilityLabel(title)
        .accessibilityValue(on ? "An" : "Aus")
    }
}

/// Restzeit des Timers als Ring
private struct TimerRing: View {
    let left: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.ink.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, left))))
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
        .animation(.linear(duration: 1), value: left)
    }
}

/// Kleine tanzende Balken (Musik läuft)
private struct DancingBars: View {
    var body: some View {
        Clock { t in
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(Theme.ink)
                        .frame(width: 3, height: Self.bar(i, t))
                }
            }
            .frame(height: 20, alignment: .bottom)
        }
    }

    private static func bar(_ i: Int, _ t: Double) -> CGFloat {
        let speed: Double = 2.8 + Double(i) * 1.1
        let swing: Double = abs(sin(t * speed + Double(i) * 0.9))
        return CGFloat(5 + 14 * swing)
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
                HStack(spacing: 10) {
                    Icon(kind: .power, size: 18, color: anyOn ? Theme.text : Theme.accent)
                    Text(anyOn ? "Alle aus" : "Alle an")
                        .font(.geist(15, 600))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.interpolate)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5)
                }
            }
            .buttonStyle(PressStyle(scale: 0.96))
            .disabled(!usable)
            .opacity(usable ? 1 : 0.4)
            .sensoryFeedback(.impact(weight: .heavy), trigger: anyOn)

            Button {
                nav.path.append(.control(.all))
            } label: {
                Text("Alle Lichter")
                    .font(.geist(15, 700))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 14)
            }
            .buttonStyle(PressStyle(scale: 0.96))
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg.opacity(0.94), Theme.bg],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55))
                .ignoresSafeArea()
        }
    }
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
