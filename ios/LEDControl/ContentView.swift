import SwiftUI
import UIKit

/// Die ganze Seite, aufgebaut wie index.html: Kopf, Verbindung, Licht, Farbe, Flow-Effekte, Protokoll.
struct ContentView: View {
    @Environment(LightController.self) private var light
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let connected = light.link == .on
        ZStack {
            Backdrop()
            ParticleField()
            ScrollView {
                VStack(spacing: 0) {
                    HeroView()
                    Text("Eigene App für ELK-BLEDOM-Leisten · iOS")
                        .font(.geist(13, 400))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 26)

                    SectionTitle("Verbindung").rise(0)
                    ConnectionTile().rise(1)

                    // Alles, was eine Verbindung braucht: ohne Leiste abgedunkelt und gesperrt
                    Group {
                        SectionTitle("Licht").rise(2)
                        PowerButtons().rise(3)
                        BrightnessTile().rise(4)
                        SectionTitle("Farbe").rise(5)
                        ColorTile().rise(6)
                        SectionTitle("Flow-Effekte").rise(7)
                        FlowGrid().rise(8)
                        SpeedTile().rise(10)
                        BuiltinTile().rise(11)
                    }
                    .opacity(connected ? 1 : 0.35)
                    .allowsHitTesting(connected)
                    .animation(.easeOut(duration: 0.5), value: connected)

                    SectionTitle("Protokoll").rise(12)
                    LogTile().rise(13)
                    Footer().rise(14)
                }
                .frame(maxWidth: 520)
                .padding(EdgeInsets(top: 22, leading: 16, bottom: 28, trailing: 16))
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            // Zurück in der App: Verbindung prüfen und wenn nötig neu aufbauen
            if phase == .active { light.resume() }
        }
        .onChange(of: light.keepAwake, initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
    }
}

// MARK: - Verbindung

private struct ConnectionTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        let state = light.link
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                StatusDot(state: state)
                Text(light.status)
                    .font(.geist(14, 400))
                    .foregroundStyle(state == .on ? Theme.text : Theme.muted)
            }
            HStack(spacing: 12) {
                Button {
                    light.connect()
                } label: {
                    HStack(spacing: 10) {
                        Icon(kind: .bluetooth, size: 15)
                        Text("Verbinden")
                    }
                }
                .buttonStyle(OutlineButtonStyle(on: state == .off))
                .disabled(state != .off)

                Button(state == .busy ? "Abbrechen" : "Trennen") {
                    light.disconnect()
                }
                .buttonStyle(OutlineButtonStyle())
                .disabled(state == .off)
            }
        }
        .tile()
        .overlay {
            if state == .busy { ScanBorder() }
        }
        .padding(.bottom, 12)
    }
}

/// Punkt vor dem Status: grau = getrennt, gelb mit Ringen = sucht (schnell) oder verbunden (ruhig)
private struct StatusDot: View {
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

/// Laufender Lichtstreifen um die Kachel, solange gesucht oder verbunden wird
private struct ScanBorder: View {
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

// MARK: - Licht

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
        .padding(.bottom, 12)
    }
}

private struct SpeedTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        VStack(spacing: 14) {
            TileHeader(icon: .speed, title: "Tempo", value: "\(light.speed) %")
            AccentSlider(value: light.speed, label: "Tempo") { light.setSpeed($0) }
                .frame(height: 28)
        }
        .tile()
        .padding(.bottom, 12)
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

// MARK: - Flow-Effekte

private struct FlowGrid: View {
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            Clock { t in
                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(Flow.all) { flow in
                        FlowCard(flow: flow, t: t)
                    }
                }
            }
            .padding(.bottom, 12)

            Text("Diese Effekte berechnet die App live und überblendet ohne Sprünge. Sie laufen, solange die App offen ist – der Bildschirm bleibt dabei an.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 12)
        }
    }
}

/// Karte mit laufender Vorschau; die aktive leuchtet in der Farbe der Leiste
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

private struct FlowPreview: View {
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
        .frame(height: 46)
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

/// Drei tanzende Balken neben dem Namen des laufenden Effekts
private struct EqBars: View {
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

// MARK: - Eingebaute Effekte der Leiste

private struct BuiltinTile: View {
    @Environment(LightController.self) private var light
    @State private var open = false

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) { open.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Icon(kind: .list, size: 17, color: Theme.accent)
                    Text("Standard-Effekte der Leiste")
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
                    ForEach(BuiltinEffect.all) { effect in
                        Button(effect.name) {
                            light.startBuiltin(effect.code)
                        }
                        .buttonStyle(OutlineButtonStyle(on: light.builtin == effect.code))
                    }
                }
                .padding(.top, 14)
                .transition(.opacity)
            }
        }
        .tile()
        .padding(.bottom, 12)
    }
}

// MARK: - Protokoll und Fuß

private struct LogTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        ScrollView {
            Text(light.log)
                .font(.geistMono(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(height: 110)
        .tile()
        .padding(.bottom, 12)
    }
}

private struct Footer: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                BulbGlass().fill(Theme.text)
                BulbBase().fill(Theme.text)
            }
            .frame(width: 16, height: 16)
            HStack(spacing: 0) {
                Text("LED").foregroundStyle(Theme.text)
                Text("CONTROL").foregroundStyle(Theme.accent)
            }
            .font(.geist(12, 700))
            .tracking(0.96)
            Text("iOS \(version)")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
        }
        .padding(.top, 14)
    }
}
