import SwiftUI

/// Reiter „Licht“: Lampe, Verbindung, An/Aus, Helligkeit, Szenen und Farbe
struct LightTab: View {
    @Environment(LightController.self) private var light

    var body: some View {
        let connected = light.canControl
        TabPage {
            HeroView()
            Text("Eigene App für ELK-BLEDOM- und MELK-Lichter")
                .font(.geist(13, 400))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.bottom, 18)

            UpdateBanner().rise(0)
            StatusTile().rise(1)
            DemoOffer()

            // Alles, was eine Verbindung braucht: ohne Licht abgedunkelt und gesperrt
            Group {
                SectionTitle("Licht").rise(2)
                PowerButtons().rise(3)
                BrightnessTile().rise(4)
                SectionTitle("Szenen").rise(5)
                SceneRow().rise(6)
                SectionTitle("Farbe").rise(7)
                ColorTile().rise(8)
            }
            .opacity(connected ? 1 : 0.35)
            .allowsHitTesting(connected)
            .animation(.easeOut(duration: 0.5), value: connected)
        }
    }
}

// MARK: - Update-Hinweis

private struct UpdateBanner: View {
    @Environment(Updater.self) private var updater
    @Environment(Navigator.self) private var nav

    var body: some View {
        if let release = updater.available {
            Button {
                nav.tab = .more
            } label: {
                HStack(spacing: 12) {
                    Icon(kind: .download, size: 20, color: Theme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Update \(release.version) verfügbar")
                            .font(.geist(15, 600))
                            .foregroundStyle(Theme.text)
                        Text("Antippen für die Anleitung")
                            .font(.geist(12, 400))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    Icon(kind: .chevron, size: 15, color: Theme.muted)
                        .rotationEffect(.degrees(-90))
                }
                .padding(14)
                .background(Theme.hot, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accent, lineWidth: Theme.border)
                }
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Verbindung

/// Ohne verbundenes Licht: Angebot, die App im Vorführmodus auszuprobieren
private struct DemoOffer: View {
    @Environment(LightController.self) private var light

    var body: some View {
        if !light.hub.hasTargets && !light.demo {
            Button {
                withAnimation(.easeOut(duration: 0.3)) { light.setDemo(true) }
            } label: {
                HStack(spacing: 8) {
                    Icon(kind: .sparkle, size: 15)
                    Text("Ohne Licht ausprobieren")
                }
            }
            .buttonStyle(OutlineButtonStyle())
            .padding(.top, 10)
            .transition(.opacity)
        }
    }
}

/// Status aller Lichter auf einen Blick; Antippen öffnet „Geräte“
private struct StatusTile: View {
    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav

    var body: some View {
        let hub = light.hub
        let state = light.link
        Button {
            nav.tab = .devices
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    StatusDot(state: state)
                    Text(light.status)
                        .font(.geist(14, 400))
                        .foregroundStyle(state == .on ? Theme.text : Theme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Text("Geräte")
                        .font(.geist(13, 500))
                        .foregroundStyle(Theme.text)
                    Icon(kind: .chevron, size: 14, color: Theme.muted)
                        .rotationEffect(.degrees(-90))
                }
                if hub.mine.count > 0 {
                    // Jedes eigene Licht als kleine Marke: leuchtet, wenn verbunden
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(hub.mine) { item in
                                LightChip(item: item, color: light.live ? light.led.color : Theme.accent)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .tile()
            .overlay {
                if state == .busy { ScanBorder() }
            }
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .padding(.bottom, 4)
    }
}

private struct LightChip: View {
    let item: Light
    let color: Color

    var body: some View {
        let on = item.state == .on
        HStack(spacing: 7) {
            Circle()
                .fill(on ? color : Color.white.opacity(item.enabled ? 0.35 : 0.15))
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(on ? 0.9 : 0), radius: 4)
            Text(item.title)
                .font(.geist(12, 500))
                .foregroundStyle(on ? Theme.text : Theme.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.fill, in: Capsule())
        .overlay {
            Capsule().strokeBorder(on ? Theme.accent.opacity(0.6) : Theme.soft, lineWidth: 1)
        }
    }
}

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
    var body: some View {
        Clock { t in
            RoundedRectangle(cornerRadius: 8)
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

// MARK: - An/Aus und Helligkeit

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
        .padding(.bottom, 12)
    }
}

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

// MARK: - Szenen

/// Gespeicherte Szenen zum Antippen; die letzte Karte speichert die aktuelle Einstellung
private struct SceneRow: View {
    @Environment(LightController.self) private var light
    @State private var naming = false
    @State private var name = ""

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
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
                        Text("Speichern")
                            .font(.geist(12, 500))
                            .foregroundStyle(Theme.text)
                    }
                    .frame(width: 92, height: 92)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Theme.line.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }
                .buttonStyle(PressStyle())
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: light.sceneID)
        .alert("Szene speichern", isPresented: $naming) {
            TextField("Name", text: $name)
            Button("Speichern") { light.saveScene(named: name) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Speichert Farbe oder Flow, Helligkeit und Tempo. Lange drücken auf eine Szene löscht sie.")
        }
        .padding(.bottom, 4)
    }
}

private struct SceneCard: View {
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
                    .frame(height: 38)
                Spacer(minLength: 6)
                Text(scene.name)
                    .font(.geist(13, 600))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(flow.map { "\($0.name) · \(scene.brightness) %" } ?? "\(scene.brightness) %")
                    .font(.geist(11, 400))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(width: 118, height: 92, alignment: .topLeading)
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

// MARK: - Farbe

private struct ColorTile: View {
    @Environment(LightController.self) private var light
    @State private var picking = false

    private static let swatches: [RGB] = [
        RGB(hex: 0xFF0000), RGB(hex: 0xFF7A00), RGB(hex: 0xFFD400), RGB(hex: 0x00FF40),
        RGB(hex: 0x00E5FF), RGB(hex: 0x0040FF), RGB(hex: 0x8A2BE2), RGB(hex: 0xFF00C8),
        RGB(hex: 0xFFFFFF), RGB(hex: 0xFF2A2A), RGB(hex: 0x00FFA2), RGB(hex: 0xFFB3D9),
    ]
    private static let hueValues: [UInt32] = [0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF, 0xFF0000]
    private static let hueColors: [Color] = hueValues.map { Color(rgb: $0) }
    private static let whiteColors: [Color] = [RGB(255, 147, 41), RGB(255, 214, 170), RGB(255, 255, 255), RGB(201, 226, 255)].map { $0.color }
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileHeader(icon: .drop, title: "Farbe", value: light.base.hex)
                .padding(.bottom, 14)

            // Aktuelle Farbe; Antippen öffnet den Farbwähler von iOS
            Button {
                picking = true
            } label: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(light.base.color)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line, lineWidth: Theme.border)
                    }
                    .frame(height: 48)
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .accessibilityLabel("Eigene Farbe wählen")

            caption("Farbton")
            ColorBar(colors: Self.hueColors, position: light.bar == .hue ? light.huePos : nil, label: "Farbton") {
                light.dragHue($0)
            }

            caption("Weißton")
            ColorBar(colors: Self.whiteColors, position: light.bar == .white ? light.whitePos : nil, label: "Weißton") {
                light.dragWhite($0)
            }

            LazyVGrid(columns: Self.columns, spacing: 10) {
                ForEach(0..<Self.swatches.count, id: \.self) { i in
                    swatch(i)
                }
            }
            .padding(.top, 16)
        }
        .tile()
        .padding(.bottom, 12)
        .sensoryFeedback(.selection, trigger: light.swatch)
        .sheet(isPresented: $picking) {
            SystemColorPicker(initial: light.base) { light.pick($0, instant: true) }
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.geist(12, 400))
            .foregroundStyle(Theme.muted)
            .padding(.top, 14)
            .padding(.bottom, 8)
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
