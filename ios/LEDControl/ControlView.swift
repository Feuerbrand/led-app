import SwiftUI

/// Bereiche der Steuerseite
enum ControlSection: String, CaseIterable, Identifiable {
    case color, effects, scenes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .color: return "Farbe"
        case .effects: return "Effekte"
        case .scenes: return "Szenen"
        }
    }

    var symbol: String {
        switch self {
        case .color: return "paintpalette.fill"
        case .effects: return "sparkles"
        case .scenes: return "square.grid.2x2.fill"
        }
    }

    /// Für die automatischen App-Store-Bilder: Startargument „-screenshotPage effects“
    static var initial: ControlSection {
        switch UserDefaults.standard.string(forKey: "screenshotPage") {
        case "effects": return .effects
        case "scenes": return .scenes
        default: return .color
        }
    }
}

/// Steuerung für ein Licht oder für alle Lichter zusammen:
/// oben Name, Schalter und große Helligkeit, darunter Farbe, Effekte und Szenen
struct ControlView: View {
    let target: Target

    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var section = ControlSection.initial
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmRemove = false
    @State private var naming = false
    @State private var sceneName = ""

    private var item: Light? {
        if case .light(let id) = target { return light.hub.light(id: id) }
        return nil
    }

    var body: some View {
        let usable: Bool = light.demo || light.isConnected(target)
        Page {
            ControlHeader(target: target, item: item)
                .rise(0)

            BrightnessBar(target: target)
                .padding(.top, 18)
                .rise(1)

            SectionTabs(selection: $section)
                .padding(.top, 14)
                .padding(.bottom, 20)
                .rise(2)

            Group {
                switch section {
                case .color: ColorSection()
                case .effects: EffectsSection(target: target)
                case .scenes: SceneGrid(target: target)
                }
            }
            .opacity(usable ? 1 : 0.35)
            .allowsHitTesting(usable)
            .animation(.easeOut(duration: 0.3), value: usable)
            .rise(3)

            if !usable {
                Hint(text: "Nicht verbunden. Ist das Licht an und in der Nähe? Andere Licht-Apps ganz schließen.")
                    .padding(.top, 12)
            }
        }
        .background(alignment: .top) { ControlGlow(target: target) }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    menuItems
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Mehr")
            }
        }
        .alert("Als Szene speichern", isPresented: $naming) {
            TextField("Name", text: $sceneName)
            Button("Speichern") { light.saveScene(named: sceneName) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Merkt sich Farbe oder Effekt, Helligkeit und Tempo. Die Szene erscheint im Hauptmenü.")
        }
        .alert("Licht umbenennen", isPresented: $renaming) {
            TextField(item?.name ?? "", text: $newName)
            Button("Sichern") {
                if let item { light.hub.rename(item, to: newName == item.name ? "" : newName) }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Gerätename: \(item?.name ?? "")")
        }
        .confirmationDialog("\(item?.title ?? "Licht") entfernen?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) {
                if let item {
                    light.hub.remove(item)
                    if !nav.path.isEmpty { nav.path.removeLast() }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Verbindung wird getrennt. Du kannst das Licht jederzeit wieder hinzufügen.")
        }
        .pageBackground()
        .onAppear {
            light.select(target)
            if let start = nav.section {
                section = start
                nav.section = nil
            }
        }
    }

    /// Menü hinter ⋯
    @ViewBuilder
    private var menuItems: some View {
        Button {
            sceneName = light.suggestedSceneName
            naming = true
        } label: {
            Label("Als Szene speichern", systemImage: "bookmark")
        }
        if let item {
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
            Button(role: .destructive) {
                confirmRemove = true
            } label: {
                Label("Entfernen", systemImage: "trash")
            }
        }
    }
}

// MARK: - Kopf

/// Name und Zustand, rechts der Schalter
private struct ControlHeader: View {
    let target: Target
    let item: Light?

    @Environment(LightController.self) private var light

    private var stateText: String {
        let look = light.lookOf(target)
        if let item {
            if !item.enabled { return "Getrennt" }
            switch item.state {
            case .busy: return item.rssi == nil ? "Nicht in Reichweite" : "Verbindet …"
            case .off: return "Getrennt"
            case .on: break
            }
        } else if !light.demo && !light.isConnected(target) {
            return "Nicht verbunden"
        }
        if look.power == false { return "Aus" }
        if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) { return "Effekt: \(flow.name)" }
        if look.builtin != nil { return "Effekt in der Leiste" }
        if light.goodnight != nil { return "Gute Nacht" }
        if light.sunrise != nil { return "Sonnenaufgang" }
        return ColorName.of(look.base)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(light.title(target))
                    .font(.geist(34, 800))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(stateText)
                    .font(.geist(15, 500))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .contentTransition(.interpolate)
                    .animation(.snappy(duration: 0.2), value: stateText)
            }
            Spacer(minLength: 8)
            PowerSwitch(target: target)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}

/// Leuchten oben in der Farbe des Lichts
private struct ControlGlow: View {
    let target: Target

    @Environment(LightController.self) private var light

    var body: some View {
        let live: Bool = light.isLive(target)
        let c: Color = light.glow(target).color
        RadialGradient(colors: [c.opacity(live ? 0.3 : 0), c.opacity(0)],
                       center: UnitPoint(x: 0.5, y: 0.12), startRadius: 0, endRadius: 400)
            .frame(height: 560)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: live)
            .allowsHitTesting(false)
    }
}

// MARK: - Große Helligkeit

/// Breite Leiste in der Farbe des Lichts: ziehen oder antippen stellt die Helligkeit ein
private struct BrightnessBar: View {
    let target: Target

    @Environment(LightController.self) private var light

    var body: some View {
        let look = light.lookOf(target)
        let live: Bool = light.isLive(target)
        let glow: RGB = light.glow(target)
        let value: Int = look.brightness
        let ink: Color = CardPalette.darkText([glow]) ? Theme.ink : .white
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        GeometryReader { geo in
            let fill: CGFloat = live ? max(60, geo.size.width * CGFloat(value) / 100) : 0
            ZStack(alignment: .leading) {
                Color(rgb: 0x1B1A15)
                LinearGradient(colors: [glow.toward(.white, 0.3).color, glow.color], startPoint: .leading, endPoint: .trailing)
                    .frame(width: fill)
                    .overlay(alignment: .trailing) {
                        Capsule()
                            .fill(ink.opacity(0.75))
                            .frame(width: 5, height: 30)
                            .padding(.trailing, 10)
                    }
                BarLabels(live: live, value: value, ink: ink)
            }
        }
        .frame(height: 68)
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1) }
        .shadow(color: live ? glow.color.opacity(0.35) : .clear, radius: 18, y: 6)
        .overlay {
            if live {
                DragStrip { f in
                    let v = Int((f * 100).rounded())
                    if v != value { light.setBrightness(v, for: target) }
                }
            }
        }
        .animation(.easeOut(duration: 0.08), value: value)
        .sensoryFeedback(.selection, trigger: value / 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Helligkeit")
        .accessibilityValue(live ? "\(value) Prozent" : "Aus")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: light.setBrightness(min(value + 10, 100), for: target)
            case .decrement: light.setBrightness(max(value - 10, 1), for: target)
            @unknown default: break
            }
        }
    }
}

/// Beschriftung der Helligkeits-Leiste; die Schrift wird dunkel, wo die helle Füllung darunter liegt
private struct BarLabels: View {
    let live: Bool
    let value: Int
    let ink: Color

    var body: some View {
        let leftInk: Color = live && value >= 45 ? ink : Theme.text
        let rightInk: Color = live && value >= 82 ? ink : Theme.text
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 18, weight: .semibold))
            Text("Helligkeit")
                .font(.geist(17, 600))
            Spacer(minLength: 8)
            Text(live ? "\(value) %" : "Aus")
                .font(.geistMono(20, 700))
                .foregroundStyle(rightInk)
                .contentTransition(.numericText(value: Double(value)))
        }
        .foregroundStyle(leftInk)
        .padding(.horizontal, 18)
    }
}

/// Reiter Farbe · Effekte; die gelbe Pille gleitet zum gewählten
private struct SectionTabs: View {
    @Binding var selection: ControlSection
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ControlSection.allCases) { s in
                tab(s)
            }
        }
        .padding(4)
        .background(Theme.panel, in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.edge, lineWidth: 1) }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tab(_ s: ControlSection) -> some View {
        let on = selection == s
        return Button {
            withAnimation(.snappy(duration: 0.3)) { selection = s }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: s.symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(s.title)
                    .font(.geist(15, on ? 700 : 600))
            }
            .foregroundStyle(on ? Theme.ink : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if on {
                    Capsule()
                        .fill(Theme.accent)
                        .shadow(color: Theme.accent.opacity(0.35), radius: 10)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Kleine Überschrift in Großbuchstaben
private struct SmallLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.geistMono(11, 600))
            .tracking(1.8)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

// MARK: - Farbe

private struct ColorSection: View {
    @Environment(LightController.self) private var light
    @State private var camera = false

    private static let whiteColors: [Color] = [RGB(255, 147, 41), RGB(255, 214, 170), RGB(255, 255, 255), RGB(201, 226, 255)].map { $0.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CameraButton { camera = true }
                .padding(.bottom, 22)
            SmallLabel(text: "Zuletzt benutzt")
                .padding(.bottom, 12)
            RecentColors()

            ColorWheel(color: light.base) { light.pick($0, instant: true) }
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)

            HStack {
                Text("Weißton")
                    .font(.geist(15, 700))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("warm · kalt")
                    .font(.geist(13, 500))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
            ColorBar(colors: Self.whiteColors, position: light.bar == .white ? light.whitePos : nil, label: "Weißton") {
                light.dragWhite($0)
            }
        }
        .fullScreenCover(isPresented: $camera) {
            ColorCameraView()
        }
    }
}

/// Großer Knopf „Farbe abfotografieren“ mit buntem Rand
private struct CameraButton: View {
    let action: () -> Void

    private static let rim: [Color] = [RGB(255, 59, 122), RGB(255, 179, 59), RGB(59, 255, 138), RGB(59, 208, 255), RGB(138, 75, 255), RGB(255, 59, 122)].map { $0.color }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 46, height: 46)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Farbe abfotografieren")
                        .font(.geist(16, 700))
                        .foregroundStyle(Theme.text)
                    Text("Kamera auf etwas halten – das Licht übernimmt die Farbe")
                        .font(.geist(13, 500))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.panel, in: shape)
            .overlay {
                shape.strokeBorder(AngularGradient(colors: Self.rim, center: .center), lineWidth: 1.5)
                    .opacity(0.8)
            }
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}

/// Die letzten sechs Farben zum schnellen Antippen
private struct RecentColors: View {
    @Environment(LightController.self) private var light

    var body: some View {
        let plain: Bool = light.flowID == nil && light.builtin == nil
        let current: RGB = light.base
        HStack(spacing: 12) {
            ForEach(Array(light.recentColors.enumerated()), id: \.offset) { _, c in
                let on: Bool = plain && LightController.similar(c, current)
                Button {
                    light.pick(c)
                } label: {
                    Circle()
                        .fill(c.color)
                        .overlay { Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }
                        .padding(on ? 4 : 0)
                        .overlay {
                            Circle().strokeBorder(on ? Theme.accent : Color.clear, lineWidth: 2.5)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .shadow(color: c.color.opacity(on ? 0.6 : 0), radius: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: on)
                }
                .buttonStyle(PressStyle(scale: 0.88))
                .accessibilityLabel("Farbe \(ColorName.of(c))")
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: current.hex)
    }
}

// MARK: - Effekte

private struct EffectsSection: View {
    let target: Target

    @Environment(LightController.self) private var light

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    private static let flows: [Flow] = [Flow.music] + Flow.all

    var body: some View {
        let lights = light.lightsOf(target)
        let multi: Bool = target == .all && (lights.count > 1 || light.demo)
        VStack(spacing: 12) {
            LazyVGrid(columns: Self.columns, spacing: 10) {
                ForEach(Array(Self.flows.enumerated()), id: \.element.id) { index, flow in
                    EffectTile(flow: flow, seed: Double(index) * 1.3)
                }
            }
            TempoRow(value: light.speed) { light.setSpeed($0) }
                .padding(.top, 8)
            if multi {
                WaveRow()
            }
            BuiltinGroup(target: target)
        }
        .sensoryFeedback(.selection, trigger: light.flowID)
    }
}

/// Symbol je Effekt
enum FlowSymbol {
    static func of(_ flow: Flow) -> String {
        switch flow.id {
        case "music": return "music.note"
        case "rainbow": return "rainbow"
        case "aurora": return "sparkles"
        case "sunset": return "sun.horizon.fill"
        case "ocean": return "water.waves"
        case "lava": return "flame.fill"
        case "neon": return "bolt.fill"
        case "breathe": return "wind"
        case "candle": return "flame"
        default: return "sparkles"
        }
    }
}

/// Effekt als bunte Kachel mit laufendem Farbverlauf; der laufende bekommt einen gelben Rand
private struct EffectTile: View {
    let flow: Flow
    let seed: Double

    @Environment(LightController.self) private var light

    var body: some View {
        let on: Bool = light.flowID == flow.id
        let colors: [RGB] = CardPalette.flowColors(flow, base: light.base)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button {
            light.toggleFlow(flow)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CardSurface(colors: colors, brightness: 100, seed: seed)
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Image(systemName: FlowSymbol.of(flow))
                            .font(.system(size: 18, weight: .semibold))
                        Spacer(minLength: 0)
                        if on { LiveDot() }
                    }
                    Spacer(minLength: 4)
                    Text(flow.name)
                        .font(.geist(15, 700))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                .padding(12)
            }
            .frame(height: 86)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(on ? Theme.accent : Theme.edge, lineWidth: on ? 2.5 : 1)
            }
            .shadow(color: on ? Theme.accent.opacity(0.35) : .black.opacity(0.3), radius: 12, y: 6)
            .animation(.easeOut(duration: 0.2), value: on)
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .accessibilityLabel(flow.name)
        .accessibilityValue(on ? "Läuft" : "")
    }
}

/// Tempo der Effekte: schmale Leiste mit Knopf
private struct TempoRow: View {
    let value: Int
    let onChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tempo")
                    .font(.geist(15, 700))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(value) %")
                    .font(.geistMono(14, 600))
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText(value: Double(value)))
            }
            ThinSlider(value: value)
                .overlay {
                    DragStrip { f in
                        let v = Int((f * 100).rounded())
                        if v != value { onChange(v) }
                    }
                }
        }
        .padding(.horizontal, 4)
        .sensoryFeedback(.selection, trigger: value / 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tempo")
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

/// Schmale gelbe Leiste mit weißem Knopf
private struct ThinSlider: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            let w: CGFloat = geo.size.width
            let x: CGFloat = w * CGFloat(min(max(value, 0), 100)) / 100
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 8)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(8, x), height: 8)
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
                    .offset(x: min(max(x - 12, 0), w - 24))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 30)
        .animation(.easeOut(duration: 0.08), value: value)
    }
}

/// Welle über alle Lichter: die Farbe wandert von Licht zu Licht
private struct WaveRow: View {
    @Environment(LightController.self) private var light

    var body: some View {
        Toggle(isOn: Binding(get: { light.wave }, set: { light.setWave($0) })) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Welle über alle Lichter")
                    .font(.geist(15, 700))
                    .foregroundStyle(Theme.text)
                Text("Die Farbe wandert von Licht zu Licht")
                    .font(.geist(13, 500))
                    .foregroundStyle(Theme.muted)
            }
        }
        .tint(Theme.accent)
        .tile()
    }
}

/// Effekte, die im Licht selbst eingebaut sind – zugeklappt, damit die Seite ruhig bleibt
private struct BuiltinGroup: View {
    let target: Target

    @Environment(LightController.self) private var light
    @State private var open = false

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    private var families: [EffectFamily] {
        let lights = light.lightsOf(target).filter { $0.state == .on }
        var list: [EffectFamily] = []
        if lights.contains(where: { $0.model.pixels == .addressable }) { list.append(.stripX) }
        for family in EffectFamily.allCases where family != .stripX && lights.contains(where: { $0.model.family == family }) {
            list.append(family)
        }
        return list.isEmpty ? [.elk] : list
    }

    var body: some View {
        let all = families
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { open.toggle() }
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "cpu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34)
                        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Effekte in der Leiste")
                            .font(.geist(15, 700))
                            .foregroundStyle(Theme.text)
                        Text("Laufen auch, wenn die App zu ist")
                            .font(.geist(13, 500))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(all, id: \.self) { family in
                        if all.count > 1 {
                            Text(family.title)
                                .font(.geist(13, 600))
                                .foregroundStyle(Theme.muted)
                        }
                        LazyVGrid(columns: Self.columns, spacing: 8) {
                            ForEach(family.effects) { effect in
                                Button(effect.name) {
                                    light.startBuiltin(effect.code, family: family)
                                }
                                .buttonStyle(OutlineButtonStyle(on: light.builtin == effect.code && light.builtinFamily == family))
                            }
                        }
                    }
                }
                .padding(.top, 16)
                .transition(.opacity)
            }
        }
        .tile()
    }
}

// MARK: - Szenen

/// Szenen als bunte Kacheln, dazu „Gute Nacht“, „Aufwachen“ und „Neue Szene“
private struct SceneGrid: View {
    let target: Target

    @Environment(LightController.self) private var light
    @State private var naming = false
    @State private var name = ""
    @State private var removing: LightScene?

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private func isActive(_ scene: LightScene) -> Bool {
        guard light.isLive(target), light.sunrise == nil, light.goodnight == nil else { return false }
        let look = light.lookOf(target)
        if let id = scene.flowID { return look.flowID == id }
        return look.flowID == nil && look.builtin == nil && look.base == scene.color
    }

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 10) {
            ForEach(light.scenes) { scene in
                SceneTile(title: scene.name, symbol: SceneLook.symbol(scene), colors: SceneLook.colors(scene),
                          note: nil, active: isActive(scene)) {
                    light.apply(scene, to: target)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        removing = scene
                    } label: {
                        Label("Szene löschen", systemImage: "trash")
                    }
                }
            }
            SceneTile(title: "Gute Nacht", symbol: "moon.stars.fill", colors: SceneLook.night,
                      note: light.goodnight == nil ? "10 min" : "läuft", active: light.goodnight != nil) {
                if light.goodnight == nil { light.startGoodnight(for: target) } else { light.cancelGoodnight() }
            }
            SceneTile(title: "Aufwachen", symbol: "sunrise.fill", colors: SceneLook.dawn,
                      note: "90 s", active: light.sunrise != nil) {
                light.startSunrise(for: target)
            }
            NewSceneTile {
                name = light.suggestedSceneName
                naming = true
            }
        }
        .sensoryFeedback(.selection, trigger: light.sceneID)
        .alert("Neue Szene", isPresented: $naming) {
            TextField("Name", text: $name)
            Button("Speichern") { light.saveScene(named: name) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Merkt sich Farbe oder Effekt, Helligkeit und Tempo.")
        }
        .confirmationDialog("Szene „\(removing?.name ?? "")“ löschen?", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let scene = removing { light.deleteScene(scene) }
                removing = nil
            }
            Button("Abbrechen", role: .cancel) { removing = nil }
        }
    }
}

/// Aussehen einer Szene: Farben für den Verlauf und ein passendes Symbol
enum SceneLook {
    static let night: [RGB] = [RGB(52, 62, 130), RGB(15, 18, 48)]
    static let dawn: [RGB] = [RGB(255, 208, 107), RGB(255, 122, 89), RGB(122, 60, 138)]

    static func colors(_ scene: LightScene) -> [RGB] {
        if let id = scene.flowID, let flow = Flow.everything.first(where: { $0.id == id }) {
            let list = CardPalette.flowColors(flow, base: scene.color)
            if list.count > 1 { return list }
        }
        let c = scene.color
        return [c.toward(.white, 0.15), c.scaled(0.55)]
    }

    static func symbol(_ scene: LightScene) -> String {
        switch MoodArt.style(for: scene) {
        case .cinema: return "film.fill"
        case .party: return "sparkles"
        case .waves: return "water.waves"
        case .sun: return "sun.horizon.fill"
        case .flame: return "flame.fill"
        case .glow: return "lightbulb.fill"
        case .dawn: return "sunrise.fill"
        }
    }
}

/// Bunte Kachel einer Szene; die laufende bekommt einen gelben Rand
private struct SceneTile: View {
    let title: String
    let symbol: String
    let colors: [RGB]
    let note: String?
    let active: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let stops: [Color] = colors.map { $0.color }
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: symbol)
                        .font(.system(size: 19, weight: .semibold))
                    Spacer(minLength: 0)
                    if active { LiveDot() }
                }
                Spacer(minLength: 8)
                Text(title)
                    .font(.geist(14, 700))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.leading)
                if let note {
                    Text(note)
                        .font(.geist(11, 500))
                        .opacity(0.8)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 108, maxHeight: 108, alignment: .leading)
            .background {
                ZStack {
                    LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
                    LinearGradient(colors: [.black.opacity(0), .black.opacity(0.3)], startPoint: .center, endPoint: .bottom)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(active ? Theme.accent : Color.white.opacity(0.1), lineWidth: active ? 2.5 : 1)
            }
            .shadow(color: active ? Theme.accent.opacity(0.35) : .clear, radius: 12)
            .animation(.easeOut(duration: 0.2), value: active)
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .accessibilityLabel(title)
        .accessibilityValue(active ? "Läuft" : "")
    }
}

/// Kleiner gelber Punkt mit tanzenden Balken: läuft gerade
struct LiveDot: View {
    var body: some View {
        Clock { t in
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(Theme.ink)
                        .frame(width: 2.5, height: Self.bar(i, t))
                }
            }
            .frame(height: 10, alignment: .bottom)
        }
        .frame(width: 22, height: 22)
        .background(Theme.accent, in: Circle())
        .shadow(color: Theme.accent.opacity(0.6), radius: 6)
        .accessibilityHidden(true)
    }

    private static func bar(_ i: Int, _ t: Double) -> CGFloat {
        let speed: Double = 3 + Double(i) * 1.2
        let swing: Double = abs(sin(t * speed + Double(i)))
        return CGFloat(3 + 7 * swing)
    }
}

/// Gestrichelte Kachel: so wie die Lichter gerade leuchten als Szene speichern
private struct NewSceneTile: View {
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .semibold))
                Spacer(minLength: 8)
                Text("Neue Szene")
                    .font(.geist(14, 700))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(Theme.muted)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 108, maxHeight: 108, alignment: .leading)
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(shape)
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .accessibilityLabel("Neue Szene speichern")
    }
}
