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

    private var meta: String {
        if let item {
            let state: String
            switch item.state {
            case .on: state = "Verbunden"
            case .busy: state = item.rssi == nil ? "Nicht in Reichweite" : "Verbindet"
            case .off: state = "Getrennt"
            }
            return "\(item.name) · \(state)".uppercased()
        }
        let lights = light.lightsOf(.all)
        if lights.isEmpty { return light.demo ? "VORFÜHRMODUS" : "NOCH KEIN LICHT" }
        return "\(lights.filter { $0.state == .on }.count)/\(lights.count) LICHTER VERBUNDEN"
    }

    /// Farben im großen LED-Feld: bei „Alle Lichter“ jedes Licht als Abschnitt
    private var panelColors: [RGB] {
        let lights = light.lightsOf(target)
        if target == .all && lights.count > 1 {
            return lights.map { light.glow(.light($0.id)) }
        }
        return [light.glow(target)]
    }

    /// Ablesezeile unter dem LED-Feld: Farbe · Helligkeit · laufender Effekt
    private var readout: String {
        let look = light.lookOf(target)
        if look.power == false { return "AUS" }
        var parts = [light.glow(target).hex, "\(look.brightness) %"]
        if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) {
            parts.append(flow.name.uppercased())
        } else if look.builtin != nil {
            parts.append("EINGEBAUTER EFFEKT")
        }
        return parts.joined(separator: "   ")
    }

    var body: some View {
        let usable = light.demo || light.isConnected(target)
        let live = light.isLive(target)
        Page {
            // Kopf: Name, Status, Schalter
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(light.title(target))
                        .font(.geist(32, 700))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 7) {
                        StatusLED(state: usable ? .on : (item?.state == .busy ? .busy : .off))
                        if let item { PixelBadge(kind: item.model.pixels) }
                        Text(meta)
                            .font(.geistMono(11, 500))
                            .tracking(1)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                PowerSwitch(target: target)
                    .padding(.top, 6)
            }
            .padding(.top, 4)
            .rise(0)

            // Großes LED-Feld mit Ablesezeile
            VStack(alignment: .leading, spacing: 12) {
                LEDPanel(colors: panelColors, live: live, brightness: light.lookOf(target).brightness,
                         rows: 3, dot: 11, gap: 6, delay: 0.035)
                HStack {
                    Text(readout)
                        .font(.geistMono(12, 600))
                        .tracking(1)
                        .foregroundStyle(live ? Theme.text : Theme.muted)
                        .contentTransition(.numericText())
                    Spacer()
                }
            }
            .tile()
            .padding(.top, 18)
            .rise(1)

            SectionTabs(selection: $section)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .rise(2)

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
            .rise(3)

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
        .onAppear { light.select(target) }
    }
}

/// Reiter FARBE · EFFEKTE · SZENEN mit gleitender gelber Linie
private struct SectionTabs: View {
    @Binding var selection: ControlSection
    @Namespace private var line

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ControlSection.allCases) { s in
                let on = selection == s
                Button {
                    withAnimation(.snappy(duration: 0.3)) { selection = s }
                } label: {
                    VStack(spacing: 10) {
                        Text(s.title.uppercased())
                            .font(.geistMono(12, on ? 700 : 500))
                            .tracking(1.6)
                            .foregroundStyle(on ? Theme.accent : Theme.muted)
                        ZStack {
                            Rectangle().fill(Color.clear).frame(height: 2)
                            if on {
                                Rectangle()
                                    .fill(Theme.accent)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "line", in: line)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hair).frame(height: 1)
        }
        .sensoryFeedback(.selection, trigger: selection)
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
        VStack(spacing: 12) {
            LEDMeter(label: "Helligkeit", value: light.brightness) { light.setBrightness($0) }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("FARBE")
                        .font(.geistMono(11, 600))
                        .tracking(1.6)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text(light.base.hex)
                        .font(.geistMono(20, 600))
                        .foregroundStyle(Theme.text)
                }
                ColorWheel(color: light.base) { light.pick($0, instant: true) }
                    .frame(maxWidth: 290)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)

                Text("WEISSTON")
                    .font(.geistMono(11, 600))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)
                    .padding(.bottom, 10)
                ColorBar(colors: Self.whiteColors, position: light.bar == .white ? light.whitePos : nil, label: "Weißton") {
                    light.dragWhite($0)
                }

                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(0..<Self.swatches.count, id: \.self) { i in
                        swatch(i)
                    }
                }
                .padding(.top, 20)

                Button {
                    picking = true
                } label: {
                    Text("FARBWÄHLER VON iOS")
                        .font(.geistMono(11, 600))
                        .tracking(1.2)
                }
                .buttonStyle(CompactButtonStyle())
                .padding(.top, 18)
            }
            .tile()
        }
        .sensoryFeedback(.selection, trigger: light.swatch)
        .sheet(isPresented: $picking) {
            SystemColorPicker(initial: light.base) { light.pick($0, instant: true) }
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
        }
    }

    /// Farbfeld als runde LED
    private func swatch(_ i: Int) -> some View {
        let c = Self.swatches[i]
        let on = light.swatch == i
        return Button {
            light.pick(c, swatch: i)
        } label: {
            Circle()
                .fill(c.color)
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 7, height: 5)
                        .offset(x: -4, y: -7)
                }
                .padding(4)
                .overlay {
                    Circle().strokeBorder(on ? Theme.accent : Color.clear, lineWidth: 2)
                }
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(on ? 1.06 : 1)
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
            EffectTile(flow: Flow.music, wide: true)
            LazyVGrid(columns: Self.columns, spacing: 10) {
                ForEach(Flow.all) { flow in
                    EffectTile(flow: flow, wide: false)
                }
            }
            Hint(text: "Diese Effekte berechnet die App live. Sie laufen, solange die App offen ist – der Bildschirm bleibt dabei an. Nochmal antippen hält bei der aktuellen Farbe an.")
                .padding(.top, 2)
            LEDMeter(label: "Tempo", value: light.speed) { light.setSpeed($0) }
                .padding(.top, 6)
            BuiltinTiles(target: target)
                .padding(.top, 6)
            if singleOnly {
                SingleColorNote(multiple: target == .all && lights.count > 1)
                    .padding(.top, 6)
            }
        }
        .sensoryFeedback(.selection, trigger: light.flowID)
    }
}

/// Effekt-Kachel mit laufender LED-Vorschau; die aktive bekommt eine gelbe Linie und „LÄUFT“
private struct EffectTile: View {
    let flow: Flow
    let wide: Bool

    @Environment(LightController.self) private var light

    var body: some View {
        let on = light.flowID == flow.id
        Button {
            light.toggleFlow(flow)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                EffectLEDs(flow: flow, base: light.base, active: on, dot: wide ? 7 : 5, gap: wide ? 5 : 4)
                HStack(spacing: 8) {
                    if flow.kind == .music {
                        Icon(kind: .music, size: 14, color: on ? Theme.accent : Theme.muted)
                    }
                    Text(flow.name)
                        .font(.geist(wide ? 17 : 15, 600))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    if on {
                        Text("LÄUFT")
                            .font(.geistMono(10, 700))
                            .tracking(1.2)
                            .foregroundStyle(Theme.accent)
                    }
                }
                if wide {
                    Text("Die Lichter folgen dem Takt – die App hört über das Mikrofon mit, nimmt aber nichts auf.")
                        .font(.geist(12, 400))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Theme.hot : Theme.panel, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4).strokeBorder(on ? Theme.accent : Theme.hair, lineWidth: 1)
            }
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }
}

/// Welle über alle Lichter: die Farbe wandert von Licht zu Licht
private struct WavePanel: View {
    let count: Int

    @Environment(LightController.self) private var light

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(get: { light.wave }, set: { light.setWave($0) })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Welle über alle Lichter")
                        .font(.geist(16, 600))
                        .foregroundStyle(Theme.text)
                    Text("FARBE WANDERT VON LICHT ZU LICHT")
                        .font(.geistMono(10, 500))
                        .tracking(1)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Lauflicht")
                    .font(.geist(16, 600))
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1)
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
                        .font(.geist(14, 500))
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
                    Text(family.title.uppercased())
                        .font(.geistMono(12, 600))
                        .tracking(1.2)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text("\(family.effects.count)")
                        .font(.geistMono(12, 500))
                        .foregroundStyle(Theme.muted)
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
                            light.deleteScene(scene)
                        } label: {
                            Label("Szene löschen", systemImage: "trash")
                        }
                    }
                }
                Button {
                    name = light.suggestedSceneName
                    naming = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Icon(kind: .plus, size: 18, color: Theme.accent)
                            .frame(height: 17)
                        Text("Speichern")
                            .font(.geist(15, 600))
                            .foregroundStyle(Theme.text)
                        Text("AKTUELLE EINSTELLUNG")
                            .font(.geistMono(10, 500))
                            .tracking(0.8)
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Theme.bg.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.hair, lineWidth: 1)
                    }
                }
                .buttonStyle(PressStyle(scale: 0.97))
            }
            Hint(text: "Eine Szene merkt sich Farbe oder Effekt, Helligkeit und Tempo – für das, was du gerade steuerst. Lange drücken löscht sie.")
        }
        .sensoryFeedback(.selection, trigger: light.sceneID)
        .alert("Szene speichern", isPresented: $naming) {
            TextField("Name", text: $name)
            Button("Speichern") { light.saveScene(named: name) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Speichert Farbe oder Effekt, Helligkeit und Tempo.")
        }
    }
}
