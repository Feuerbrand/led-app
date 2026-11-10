import SwiftUI

/// Reiter „Effekte“: Flow-Effekte der App, Musik-Modus, Tempo und die eingebauten Effekte der Lichter
struct EffectsTab: View {
    @Environment(LightController.self) private var light

    var body: some View {
        let connected = light.hub.hasTargets
        TabPage {
            PageTitle(title: "Effekte", subtitle: "Berechnet live in der App, überblendet ohne Sprünge")
            Group {
                SectionTitle("Flow-Effekte").rise(1)
                FlowGrid().rise(2)
                SectionTitle("Tempo").rise(3)
                SpeedTile().rise(4)
                SectionTitle("Eingebaut").rise(5)
                BuiltinTiles().rise(6)
            }
            .opacity(connected ? 1 : 0.35)
            .allowsHitTesting(connected)
            .animation(.easeOut(duration: 0.5), value: connected)
        }
    }
}

// MARK: - Flow-Effekte

private struct FlowGrid: View {
    @Environment(LightController.self) private var light

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.bottom, 12)

            Text("Die Effekte laufen, solange die App offen ist – der Bildschirm bleibt dabei an. Nochmal antippen hält bei der aktuellen Farbe an.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .sensoryFeedback(.selection, trigger: light.flowID)
    }
}

/// Karte mit laufender Vorschau; die aktive leuchtet in der Farbe der Lichter
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
private struct MusicBars: View {
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

// MARK: - Tempo

private struct SpeedTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        VStack(spacing: 14) {
            TileHeader(icon: .speed, title: "Tempo", value: "\(light.speed) %")
            AccentSlider(value: light.speed, label: "Tempo") { light.setSpeed($0) }
                .frame(height: 28)
            Text("Gilt für die Flow-Effekte und die eingebauten Effekte.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tile()
        .padding(.bottom, 4)
    }
}

// MARK: - Eingebaute Effekte der Lichter

/// Eine Liste je Bauart der verbundenen Lichter (ELK und MELK haben verschiedene Effekte)
private struct BuiltinTiles: View {
    @Environment(LightController.self) private var light

    var body: some View {
        let families = light.hub.families
        VStack(spacing: 12) {
            ForEach(families.isEmpty ? [EffectFamily.elk] : families, id: \.self) { family in
                BuiltinTile(family: family)
            }
            Text("Diese Effekte laufen im Licht selbst weiter, auch wenn die App zu ist.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .padding(.bottom, 12)
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
