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

    /// Für die automatischen App-Store-Bilder: Startargument „-screenshotPage effects“
    static var initial: ControlSection {
        switch UserDefaults.standard.string(forKey: "screenshotPage") {
        case "effects": return .effects
        case "scenes": return .scenes
        default: return .color
        }
    }
}

/// Steuerung für ein Licht oder für alle Lichter zusammen
struct ControlView: View {
    let target: Target

    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var section = ControlSection.initial
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmRemove = false

    private var item: Light? {
        if case .light(let id) = target { return light.hub.light(id: id) }
        return nil
    }

    var body: some View {
        let usable: Bool = light.demo || light.isConnected(target)
        Page {
            ControlHero(target: target, item: item)
                .padding(.top, 4)
                .rise(0)

            SectionTabs(selection: $section)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .rise(1)

            Group {
                switch section {
                case .color: ColorSection()
                case .effects: EffectsSection(target: target)
                case .scenes: ScenesSection()
                }
            }
            .opacity(usable ? 1 : 0.35)
            .allowsHitTesting(usable)
            .animation(.easeOut(duration: 0.3), value: usable)
            .rise(2)

            if !usable {
                Hint(text: "Dieses Licht ist gerade nicht verbunden. Ist es eingeschaltet und in der Nähe? Andere Licht-Apps ganz schließen.")
                    .padding(.top, 12)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let item {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
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
                    } label: {
                        Icon(kind: .dots, size: 20, color: Theme.text)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Licht bearbeiten")
                }
            }
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
}

// MARK: - Große Karte oben

/// Wie die Karten im Hauptmenü: die Fläche leuchtet in der Farbe des Lichts,
/// dazu Name, Zustand, Schalter und die Helligkeit zum Ziehen
private struct ControlHero: View {
    let target: Target
    let item: Light?

    @Environment(LightController.self) private var light

    static let height: CGFloat = 244

    private var meta: String {
        if let item {
            if let badge = item.model.pixels.badge { return "\(item.name) · \(badge)" }
            return item.name
        }
        let lights = light.lightsOf(.all)
        if lights.isEmpty { return light.demo ? "Vorführmodus" : "Noch kein Licht" }
        let on = lights.filter { $0.state == .on }.count
        return "\(on)/\(lights.count) Lichter verbunden"
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
        } else if !light.demo && !light.isConnected(target) {
            return "Nicht verbunden"
        }
        if look.power == false { return "Aus" }
        if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) { return flow.name }
        if look.builtin != nil { return "Eingebauter Effekt" }
        if light.sunrise != nil { return "Sonnenaufgang" }
        return "Farbe \(light.glow(target).hex)"
    }

    /// Bei „Alle Lichter“ mit verschiedenen Farben bekommt jedes Licht ein Stück vom Verlauf
    private var colors: [RGB] {
        let look = light.lookOf(target)
        let lights = light.lightsOf(target)
        if target == .all && lights.count > 1 && look.flowID == nil && look.builtin == nil {
            let each: [RGB] = lights.map { light.glow(.light($0.id)) }
            let distinct: Set<String> = Set(each.map { $0.hex })
            if distinct.count > 1 { return each }
        }
        return CardPalette.colors(look: look, glow: light.glow(target))
    }

    var body: some View {
        let look = light.lookOf(target)
        let live: Bool = light.isLive(target)
        let all: [RGB] = colors
        let dark: Bool = CardPalette.darkText(all)
        let ink: Color = live ? (dark ? Theme.ink : .white) : Theme.text
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        ZStack(alignment: .topLeading) {
            if live {
                CardSurface(colors: all, brightness: look.brightness, seed: 0)
                    .transition(.opacity)
            } else {
                Theme.card
            }
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(meta.uppercased())
                        .font(.geistMono(11, 600))
                        .tracking(1.6)
                        .foregroundStyle(ink.opacity(0.7))
                        .lineLimit(1)
                    Text(light.title(target))
                        .font(.geist(32, 800))
                        .foregroundStyle(live ? ink : Theme.text.opacity(0.75))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                .padding(.trailing, 72)
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(stateText)
                        .font(.geist(15, 700))
                        .foregroundStyle(live ? ink : Theme.muted)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if live {
                        HeroPercent(value: look.brightness)
                            .foregroundStyle(ink)
                    } else if let item, item.state == .on || item.rssi != nil {
                        SignalBars(rssi: item.rssi)
                    }
                }
                // Platz für die Helligkeits-Leiste (liegt als eigene Fläche darüber)
                Color.clear.frame(height: live ? 32 : 0)
            }
            .padding(20)
        }
        .frame(height: Self.height)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Color.white.opacity(live ? 0.14 : 0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.55), radius: 20, y: 14)
        .overlay(alignment: .topTrailing) {
            PowerSwitch(target: target, onColor: live)
                .padding(18)
        }
        .overlay(alignment: .bottom) {
            if live {
                CardBrightness(value: look.brightness, color: ink) { light.setBrightness($0, for: target) }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: live)
    }
}

private struct HeroPercent: View {
    let value: Int

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text("\(value)")
                .font(.geistMono(40, 800))
                .contentTransition(.numericText(value: Double(value)))
                .animation(.snappy(duration: 0.2), value: value)
            Text("%")
                .font(.geistMono(16, 700))
        }
    }
}

/// Reiter Farbe · Effekte · Szenen als Pillen; die gelbe gleitet zum gewählten
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
            Text(s.title)
                .font(.geist(15, on ? 700 : 600))
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

// MARK: - Farbe

private struct ColorSection: View {
    @Environment(LightController.self) private var light
    @State private var picking = false

    private static let swatches: [RGB] = [
        RGB(hex: 0xFF0000), RGB(hex: 0xFF7A00), RGB(hex: 0xFFD400), RGB(hex: 0x00FF40),
        RGB(hex: 0x00E5FF), RGB(hex: 0x0040FF), RGB(hex: 0x8A2BE2), RGB(hex: 0xFF00C8),
        RGB(hex: 0xFFFFFF), RGB(hex: 0xFF2A2A), RGB(hex: 0x00FFA2), RGB(hex: 0xFFB3D9),
    ]
    private static let whiteColors: [Color] = [RGB(255, 147, 41), RGB(255, 214, 170), RGB(255, 255, 255), RGB(201, 226, 255)].map { $0.color }
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Farbe")
                    .font(.geist(17, 700))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(light.base.hex)
                    .font(.geistMono(15, 600))
                    .foregroundStyle(Theme.muted)
            }
            ColorWheel(color: light.base) { light.pick($0, instant: true) }
                .frame(maxWidth: 290)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)

            Text("Weißton")
                .font(.geist(15, 700))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 12)
            ColorBar(colors: Self.whiteColors, position: light.bar == .white ? light.whitePos : nil, label: "Weißton") {
                light.dragWhite($0)
            }

            LazyVGrid(columns: Self.columns, spacing: 12) {
                ForEach(0..<Self.swatches.count, id: \.self) { i in
                    swatch(i)
                }
            }
            .padding(.top, 22)

            Button {
                picking = true
            } label: {
                Text("Farbwähler von iOS")
                    .font(.geist(14, 600))
            }
            .buttonStyle(CompactButtonStyle())
            .padding(.top, 18)
        }
        .tile()
        .sensoryFeedback(.selection, trigger: light.swatch)
        .sheet(isPresented: $picking) {
            SystemColorPicker(initial: light.base) { light.pick($0, instant: true) }
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
        }
    }

    /// Rundes Farbfeld; das gewählte leuchtet und bekommt einen gelben Ring
    private func swatch(_ i: Int) -> some View {
        let c = Self.swatches[i]
        let on = light.swatch == i
        let glow: Color = c.color.opacity(on ? 0.6 : 0)
        return Button {
            light.pick(c, swatch: i)
        } label: {
            Circle()
                .fill(c.color)
                .padding(4)
                .overlay {
                    Circle().strokeBorder(on ? Theme.accent : Color.clear, lineWidth: 2.5)
                }
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: glow, radius: 8)
                .scaleEffect(on ? 1.08 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: on)
        }
        .buttonStyle(PressStyle(scale: 0.88))
        .accessibilityLabel("Farbe \(c.hex)")
    }
}

// MARK: - Effekte

private struct EffectsSection: View {
    let target: Target

    @Environment(LightController.self) private var light

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        let lights = light.lightsOf(target)
        let connected = lights.filter { $0.state == .on }
        let addressable = connected.contains { $0.model.pixels == .addressable }
        let singleOnly = !connected.isEmpty && connected.allSatisfy { $0.model.pixels == .singleColor }
        VStack(spacing: 10) {
            if addressable {
                RunningLightPanel()
            }
            if target == .all && (lights.count > 1 || light.demo) {
                WavePanel(count: max(lights.count, 2))
            }
            EffectCard(flow: Flow.music, wide: true, seed: 0)
            LazyVGrid(columns: Self.columns, spacing: 10) {
                ForEach(Array(Flow.all.enumerated()), id: \.element.id) { index, flow in
                    EffectCard(flow: flow, wide: false, seed: Double(index) * 1.3)
                }
            }
            Hint(text: "Diese Effekte berechnet die App live. Sie laufen, solange die App offen ist – der Bildschirm bleibt dabei an. Nochmal antippen hält bei der aktuellen Farbe an.")
                .padding(.top, 2)
            LEDMeter(label: "Tempo", value: light.speed) { light.setSpeed($0) }
                .padding(.top, 6)
            SectionTitle("Im Licht eingebaut")
            BuiltinTiles(target: target)
            if singleOnly {
                SingleColorNote(multiple: target == .all && lights.count > 1)
                    .padding(.top, 6)
            }
        }
        .sensoryFeedback(.selection, trigger: light.flowID)
    }
}

/// Effekt als bunte Kachel mit laufendem Farbverlauf; die laufende bekommt einen gelben Rand und „LÄUFT“
private struct EffectCard: View {
    let flow: Flow
    let wide: Bool
    let seed: Double

    @Environment(LightController.self) private var light

    var body: some View {
        let on = light.flowID == flow.id
        let colors: [RGB] = CardPalette.flowColors(flow, base: light.base)
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        Button {
            light.toggleFlow(flow)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CardSurface(colors: colors, brightness: 100, seed: seed)
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    if flow.kind == .music {
                        Icon(kind: .music, size: 20, color: .white)
                    }
                    Text(flow.name)
                        .font(.geist(wide ? 24 : 17, 800))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if wide {
                        Text("Die Lichter folgen dem Takt – die App hört über das Mikrofon mit, nimmt aber nichts auf.")
                            .font(.geist(12, 500))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(14)
            }
            .frame(height: wide ? 150 : 108)
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
        .accessibilityLabel(flow.name)
        .accessibilityValue(on ? "Läuft" : "")
    }
}

/// Welle über alle Lichter: die Farbe wandert von Licht zu Licht
private struct WavePanel: View {
    let count: Int

    @Environment(LightController.self) private var light

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { light.wave }, set: { light.setWave($0) })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Welle über alle Lichter")
                        .font(.geist(17, 700))
                        .foregroundStyle(Theme.text)
                    Text("Die Farbe wandert von Licht zu Licht")
                        .font(.geist(12, 500))
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.accent)
            // Vorschau: jedes Licht ein Abschnitt, die Farbe läuft versetzt durch
            Clock { t in
                Canvas { context, size in
                    let dot: CGFloat = 6
                    let gap: CGFloat = 4
                    let n = max(Int((size.width + gap) / (dot + gap)), 1)
                    let width = CGFloat(n) * dot + CGFloat(n - 1) * gap
                    let x0 = (size.width - width) / 2 + dot / 2
                    for i in 0..<n {
                        let seg = min(i * count / n, count - 1)
                        let shift = light.wave ? Double(seg) * 0.12 : 0
                        var phase = (t / 6 - shift).truncatingRemainder(dividingBy: 1)
                        if phase < 0 { phase += 1 }
                        let color = ColorMath.hsv(phase * 360, 1, 1).color
                        LED.draw(context, at: CGPoint(x: x0 + CGFloat(i) * (dot + gap), y: size.height / 2), size: dot, color: color)
                    }
                }
            }
            .frame(height: 20)
        }
        .tile()
    }
}

/// Nur bei Leisten mit einzeln steuerbaren LEDs: Lauflichter, die die Leiste entlangfahren
private struct RunningLightPanel: View {
    @Environment(LightController.self) private var light

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Lauflicht")
                    .font(.geist(17, 700))
                    .foregroundStyle(Theme.text)
                PixelBadge(kind: .addressable)
                Spacer(minLength: 0)
            }
            Clock { t in
                Canvas { context, size in
                    let dot: CGFloat = 6
                    let gap: CGFloat = 4
                    let n = max(Int((size.width + gap) / (dot + gap)), 1)
                    let width = CGFloat(n) * dot + CGFloat(n - 1) * gap
                    let x0 = (size.width - width) / 2 + dot / 2
                    let head = (t * 18).truncatingRemainder(dividingBy: Double(n + 8))
                    for i in 0..<n {
                        let d = head - Double(i)
                        let color: Color? = d >= 0 && d < 8 ? ColorMath.hsv(Double(i) / Double(n) * 300, 1, 1 - d / 8).color : nil
                        LED.draw(context, at: CGPoint(x: x0 + CGFloat(i) * (dot + gap), y: size.height / 2), size: dot, color: color)
                    }
                }
            }
            .frame(height: 20)
            Text("Die LEDs dieser Leiste sind einzeln steuerbar – die Effekte fahren die Leiste entlang. Das Tempo stellst du unten ein.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(EffectFamily.stripX.effects) { effect in
                    Button(effect.name) {
                        light.startBuiltin(effect.code, family: .stripX)
                    }
                    .buttonStyle(OutlineButtonStyle(on: light.builtin == effect.code && light.builtinFamily == .stripX))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: shape)
        .overlay {
            shape.strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1.5)
        }
    }
}

/// Bei normalen RGB-Leisten: kurz erklären, warum es dort kein Lauflicht gibt
private struct SingleColorNote: View {
    let multiple: Bool

    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) { open.toggle() }
            } label: {
                HStack(spacing: 10) {
                    PixelBadge(kind: .singleColor)
                    Text("Lauflicht entlang der Leiste?")
                        .font(.geist(14, 600))
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                    Icon(kind: .chevron, size: 15, color: Theme.muted)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                Text("Diese Leiste ist eine normale RGB-Leiste (Stecker mit 4 Kontakten: +, R, G, B). Alle LEDs bekommen dasselbe Signal und zeigen immer dieselbe Farbe – auch zwei Leisten am selben Verteiler. Für ein Lauflicht entlang der Leiste braucht es eine RGBIC-Leiste (3 Kontakte: +, Daten, −)."
                     + (multiple ? " Mit mehreren Lichtern geht stattdessen die Welle: Die Farbe wandert von Licht zu Licht." : ""))
                    .font(.geist(12, 400))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(2)
                    .transition(.opacity)
            }
        }
        .tile()
    }
}

/// Eingebaute Effekte je Bauart der verbundenen Lichter (ELK und MELK haben verschiedene)
private struct BuiltinTiles: View {
    let target: Target

    @Environment(LightController.self) private var light

    var body: some View {
        let lights = light.lightsOf(target).filter { $0.state == .on }
        let families = EffectFamily.allCases.filter { family in family != .stripX && lights.contains { $0.model.family == family } }
        VStack(spacing: 10) {
            if !families.isEmpty || lights.isEmpty {
                ForEach(families.isEmpty ? [EffectFamily.elk] : families, id: \.self) { family in
                    BuiltinTile(family: family)
                }
            }
            Hint(text: "Eingebaute Effekte laufen im Licht selbst weiter, auch wenn die App zu ist.")
        }
    }
}

private struct BuiltinTile: View {
    let family: EffectFamily

    @Environment(LightController.self) private var light
    @State private var open = false

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { open.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text(family.title)
                        .font(.geist(16, 700))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text("\(family.effects.count)")
                        .font(.geistMono(12, 700))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.07), in: Capsule())
                    Icon(kind: .chevron, size: 15, color: Theme.muted)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                LazyVGrid(columns: Self.columns, spacing: 8) {
                    ForEach(family.effects) { effect in
                        Button(effect.name) {
                            light.startBuiltin(effect.code, family: family)
                        }
                        .buttonStyle(OutlineButtonStyle(on: light.builtin == effect.code && light.builtinFamily == family))
                    }
                }
                .padding(.top, 14)
                .transition(.opacity)
            }
        }
        .tile()
    }
}

// MARK: - Szenen

private struct ScenesSection: View {
    @Environment(LightController.self) private var light
    @State private var naming = false
    @State private var name = ""
    @State private var removing: LightScene?

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: Self.columns, spacing: 10) {
                ForEach(light.scenes) { scene in
                    SceneCard(scene: scene, on: light.sceneID == scene.id) {
                        light.apply(scene)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            removing = scene
                        } label: {
                            Label("Szene löschen", systemImage: "trash")
                        }
                    }
                }
                SaveSceneTile {
                    name = light.suggestedSceneName
                    naming = true
                }
            }
            Hint(text: "Eine Szene merkt sich Farbe oder Effekt, Helligkeit und Tempo – für das, was du gerade steuerst. Sie erscheint auch als Stimmung im Hauptmenü. Gedrückt halten löscht sie.")
                .padding(.top, 4)
        }
        .sensoryFeedback(.selection, trigger: light.sceneID)
        .alert("Szene speichern", isPresented: $naming) {
            TextField("Name", text: $name)
            Button("Speichern") { light.saveScene(named: name) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Speichert Farbe oder Effekt, Helligkeit und Tempo.")
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

/// Gestrichelte Kachel: aktuelles Licht als Szene speichern
private struct SaveSceneTile: View {
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        Button(action: action) {
            VStack(spacing: 10) {
                Icon(kind: .plus, size: 22, color: Theme.accent)
                    .frame(width: 50, height: 50)
                    .background(Theme.accent.opacity(0.1), in: Circle())
                Text("Speichern")
                    .font(.geist(16, 700))
                    .foregroundStyle(Theme.text)
                Text("AKTUELLES LICHT")
                    .font(.geistMono(10, 600))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: SceneCard.height)
            .background(Theme.panel.opacity(0.6), in: shape)
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }
}
