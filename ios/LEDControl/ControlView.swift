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

    private var subtitle: String {
        if let item {
            let state: String
            switch item.state {
            case .on: state = "Verbunden"
            case .busy: state = item.rssi == nil ? "Nicht in Reichweite" : "Verbindet …"
            case .off: state = "Getrennt"
            }
            return "\(item.model.label) · \(state)"
        }
        let lights = light.lightsOf(.all)
        if lights.isEmpty { return light.demo ? "Vorführmodus" : "Noch kein Licht" }
        return "\(lights.filter { $0.state == .on }.count) von \(lights.count) Lichtern verbunden"
    }

    /// Farben für die Leiste unter dem Namen: bei „Alle Lichter“ die Farben aller Lichter nebeneinander
    private var stripColors: [Color] {
        let lights = light.lightsOf(target)
        if target == .all && lights.count > 1 {
            return lights.map { light.glow(.light($0.id)).color }
        }
        return [light.glow(target).color]
    }

    var body: some View {
        let usable = light.demo || light.isConnected(target)
        Page {
            HeroView(target: target, title: light.title(target))
                .padding(.top, -12)
            Text(subtitle)
                .font(.geist(13, 400))
                .foregroundStyle(Theme.muted)
            LightStrip(colors: stripColors, live: light.isLive(target), height: 6)
                .frame(maxWidth: 220)
                .padding(.top, 14)
                .padding(.bottom, 22)

            Group {
                PowerButtons().rise(0)
                SectionPicker(selection: $section)
                    .padding(.top, 14)
                    .padding(.bottom, 14)
                    .rise(1)
                Group {
                    switch section {
                    case .color: ColorSection()
                    case .effects: EffectsSection(target: target)
                    case .scenes: ScenesSection()
                    }
                }
                .rise(2)
            }
            .opacity(usable ? 1 : 0.35)
            .allowsHitTesting(usable)
            .animation(.easeOut(duration: 0.4), value: usable)

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

// MARK: - Kopfteil

private struct PowerButtons: View {
    @Environment(LightController.self) private var light

    var body: some View {
        HStack(spacing: 12) {
            Button {
                light.setPower(true)
            } label: {
                HStack(spacing: 10) {
                    Icon(kind: .power, size: 15)
                    Text("An")
                }
            }
            .buttonStyle(OutlineButtonStyle(on: light.power == true))

            Button {
                light.setPower(false)
            } label: {
                HStack(spacing: 10) {
                    Icon(kind: .moon, size: 15)
                    Text("Aus")
                }
            }
            .buttonStyle(OutlineButtonStyle(on: light.power == false))
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: light.power)
    }
}

/// Umschalter Farbe · Effekte · Szenen mit gleitender gelber Markierung
private struct SectionPicker: View {
    @Binding var selection: ControlSection
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ControlSection.allCases) { s in
                let on = selection == s
                Button {
                    withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.35)) { selection = s }
                } label: {
                    Text(s.title)
                        .font(.geist(14, on ? 600 : 500))
                        .foregroundStyle(on ? Color(rgb: 0x14130E) : Theme.text)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background {
                            if on {
                                Capsule()
                                    .fill(Theme.accent)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                                    .shadow(color: Theme.accent.opacity(0.45), radius: 10)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.fill, in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.soft, lineWidth: Theme.border) }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Farbe

private struct BrightnessTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        VStack(spacing: 14) {
            TileHeader(icon: .sun, title: "Helligkeit", value: "\(light.brightness) %", level: Double(light.brightness))
            AccentSlider(value: light.brightness, label: "Helligkeit") { light.setBrightness($0) }
                .frame(height: 28)
        }
        .tile()
    }
}

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
            BrightnessTile()

            VStack(alignment: .leading, spacing: 0) {
                TileHeader(icon: .drop, title: "Farbe", value: light.base.hex)
                ColorWheel(color: light.base) { light.pick($0, instant: true) }
                    .shadow(color: light.base.color.opacity(0.45), radius: 30)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                Text("Weißton")
                    .font(.geist(12, 400))
                    .foregroundStyle(Theme.muted)
                    .padding(.bottom, 8)
                ColorBar(colors: Self.whiteColors, position: light.bar == .white ? light.whitePos : nil, label: "Weißton") {
                    light.dragWhite($0)
                }

                LazyVGrid(columns: Self.columns, spacing: 10) {
                    ForEach(0..<Self.swatches.count, id: \.self) { i in
                        swatch(i)
                    }
                }
                .padding(.top, 16)

                Button {
                    picking = true
                } label: {
                    HStack(spacing: 8) {
                        Icon(kind: .drop, size: 13)
                        Text("Farbwähler von iOS")
                            .font(.geist(13, 500))
                    }
                }
                .buttonStyle(CompactButtonStyle())
                .padding(.top, 16)
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

    private func swatch(_ i: Int) -> some View {
        let c = Self.swatches[i]
        let on = light.swatch == i
        return Button {
            light.pick(c, swatch: i)
        } label: {
            RoundedRectangle(cornerRadius: 5)
                .fill(c.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(on ? Theme.accent : Color.white.opacity(0.22), lineWidth: Theme.border)
                }
                .padding(2)
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Theme.accent.opacity(on ? 1 : 0), lineWidth: 2)
                }
                .padding(-2)
                .shadow(color: c.color.opacity(on ? 0.6 : 0), radius: 9)
                .animation(.easeOut(duration: 0.2), value: on)
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel("Farbe \(c.hex)")
    }
}

// MARK: - Effekte

private struct EffectsSection: View {
    let target: Target

    @Environment(LightController.self) private var light

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        let lights = light.lightsOf(target)
        let connected = lights.filter { $0.state == .on }
        let addressable = connected.contains { $0.model.pixels == .addressable }
        let singleOnly = !connected.isEmpty && connected.allSatisfy { $0.model.pixels == .singleColor }
        VStack(spacing: 12) {
            if addressable {
                RunningLightTile()
            }
            if target == .all && (lights.count > 1 || light.demo) {
                WaveTile()
            }
            Clock { t in
                VStack(spacing: 12) {
                    MusicCard(t: t)
                    LazyVGrid(columns: Self.columns, spacing: 12) {
                        ForEach(Flow.all) { flow in
                            FlowCard(flow: flow, t: t)
                        }
                    }
                }
            }
            Hint(text: "Diese Effekte berechnet die App live. Sie laufen, solange die App offen ist – der Bildschirm bleibt dabei an. Nochmal antippen hält bei der aktuellen Farbe an.")
            SpeedTile()
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

/// Nur bei Leisten mit einzeln steuerbaren LEDs: Lauflichter, die die Leiste entlangfahren
private struct RunningLightTile: View {
    @Environment(LightController.self) private var light

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Icon(kind: .flash, size: 17, color: Theme.accent)
                Text("Lauflicht")
                    .font(.geist(16, 600))
                    .foregroundStyle(Theme.text)
                PixelBadge(kind: .addressable)
                Spacer(minLength: 0)
            }
            Clock { t in
                GeometryReader { geo in
                    let w = Double(geo.size.width)
                    let p = (t * 0.5).truncatingRemainder(dividingBy: 1)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [Color(rgb: 0xFF3B6B).opacity(0), Color(rgb: 0xFF3B6B), Theme.accent],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: CGFloat(w * 0.3))
                            .offset(x: CGFloat(-w * 0.3 + p * w * 1.3))
                            .shadow(color: Theme.accent.opacity(0.8), radius: 6)
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 8)
            Text("Diese Leiste hat einzeln steuerbare LEDs – die Effekte fahren die Leiste entlang. Das Tempo stellst du unten ein.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
            LazyVGrid(columns: Self.columns, spacing: 10) {
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
        .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
        .overlay { ScanBorder(radius: 8, color: Theme.accent, period: 3, width: 1.5) }
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

/// Welle über alle Lichter: die Farbe wandert von Licht zu Licht
private struct WaveTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(get: { light.wave }, set: { light.setWave($0) })) {
                HStack(spacing: 10) {
                    Icon(kind: .sparkle, size: 17, color: Theme.accent)
                    Text("Welle über alle Lichter")
                        .font(.geist(16, 600))
                        .foregroundStyle(Theme.text)
                }
            }
            .tint(Theme.accent)
            Clock { t in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        let hue = (t * 50 - (light.wave ? Double(i) * 28 : 0)).truncatingRemainder(dividingBy: 360)
                        let c = ColorMath.hsv(hue < 0 ? hue + 360 : hue, 1, 1).color
                        RoundedRectangle(cornerRadius: 3)
                            .fill(c)
                            .frame(height: 10)
                            .shadow(color: c.opacity(0.8), radius: 5)
                    }
                }
            }
            .frame(height: 14)
            Text("Bei einem Effekt wandert die Farbe von Licht zu Licht – wie ein Lauflicht durch den Raum. Die Reihenfolge ist die im Hauptmenü.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
        }
        .tile()
    }
}

/// Karte mit laufender Vorschau; die aktive leuchtet in der Farbe des Lichts
private struct FlowCard: View {
    let flow: Flow
    let t: Double

    @Environment(LightController.self) private var light

    var body: some View {
        let on = light.flowID == flow.id
        let glow = on ? light.led.color.opacity(0.4) : Color.clear
        Button {
            light.toggleFlow(flow)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                FlowPreview(flow: flow, on: on, t: t, pick: light.base.color)
                    .frame(height: 46)
                HStack(spacing: 8) {
                    Text(flow.name)
                        .font(.geist(15, 500))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    EqBars(t: t)
                        .opacity(on ? 1 : 0)
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            }
            .padding(10)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(on ? Theme.accent : Theme.soft, lineWidth: Theme.border)
            }
            .shadow(color: glow, radius: 15)
        }
        .buttonStyle(PressStyle())
    }
}

/// Breite Karte für den Musik-Modus
private struct MusicCard: View {
    let t: Double

    @Environment(LightController.self) private var light

    var body: some View {
        let on = light.flowID == Flow.music.id
        Button {
            light.toggleFlow(Flow.music)
        } label: {
            HStack(spacing: 14) {
                FlowPreview(flow: Flow.music, on: on, t: t, pick: light.base.color)
                    .frame(width: 96, height: 58)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Icon(kind: .music, size: 15, color: Theme.accent)
                        Text("Musik")
                            .font(.geist(16, 600))
                            .foregroundStyle(Theme.text)
                        Spacer(minLength: 0)
                        EqBars(t: t)
                            .opacity(on ? 1 : 0)
                    }
                    Text("Lichter pulsieren im Takt – die App hört über das Mikrofon mit, nimmt aber nichts auf.")
                        .font(.geist(12, 400))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(10)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(on ? Theme.accent : Theme.soft, lineWidth: Theme.border)
            }
            .shadow(color: on ? light.led.color.opacity(0.4) : Color.clear, radius: 15)
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}

private struct SpeedTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        VStack(spacing: 14) {
            TileHeader(icon: .speed, title: "Tempo", value: "\(light.speed) %")
            AccentSlider(value: light.speed, label: "Tempo") { light.setSpeed($0) }
                .frame(height: 28)
            Text("Gilt für die Effekte der App und die eingebauten Effekte.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tile()
    }
}

/// Eine Liste je Bauart der verbundenen Lichter (ELK und MELK haben verschiedene Effekte)
private struct BuiltinTiles: View {
    let target: Target

    @Environment(LightController.self) private var light

    var body: some View {
        let lights = light.lightsOf(target).filter { $0.state == .on }
        let families = EffectFamily.allCases.filter { family in family != .stripX && lights.contains { $0.model.family == family } }
        VStack(spacing: 12) {
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
    @State private var open = true

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) { open.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Icon(kind: .list, size: 17, color: Theme.accent)
                    Text(family.title)
                        .font(.geist(16, 500))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Icon(kind: .chevron, size: 17, color: Theme.muted)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                LazyVGrid(columns: Self.columns, spacing: 12) {
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

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Self.columns, spacing: 12) {
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
                    VStack(spacing: 8) {
                        Icon(kind: .plus, size: 20, color: Theme.accent)
                        Text("Aktuelles speichern")
                            .font(.geist(13, 500))
                            .foregroundStyle(Theme.text)
                    }
                    .frame(maxWidth: .infinity, minHeight: 116)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Theme.line.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }
                .buttonStyle(PressStyle())
            }
            Hint(text: "Eine Szene merkt sich Farbe oder Effekt, Helligkeit und Tempo. Sie gilt für das, was du gerade steuerst. Lange drücken löscht sie.")
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
