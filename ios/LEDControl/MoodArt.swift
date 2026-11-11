import SwiftUI

// MARK: - Farbhilfen für Karten und Poster

extension RGB {
    static let white = RGB(255, 255, 255)

    /// Dunkler (k < 1) oder heller (k > 1), jede Grundfarbe für sich
    func scaled(_ k: Double) -> RGB {
        func f(_ v: Int) -> Int { min(255, max(0, Int((Double(v) * k).rounded()))) }
        return RGB(f(r), f(g), f(b))
    }

    /// Ein Stück in Richtung einer anderen Farbe (k = 0…1)
    func toward(_ o: RGB, _ k: Double) -> RGB {
        func f(_ a: Int, _ b: Int) -> Int { Int((Double(a) + Double(b - a) * k).rounded()) }
        return RGB(f(r, o.r), f(g, o.g), f(b, o.b))
    }

    /// Wie hell die Farbe wirkt (0…1)
    var perceived: Double {
        (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255
    }
}

// MARK: - Bild einer Stimmung

/// Wie das Poster einer Stimmung aussieht – abgeleitet aus Name, Farbe und Effekt der Szene
enum MoodArt {
    case cinema(RGB)
    case party([RGB])
    case waves([RGB])
    case sun([RGB])
    case flame
    case glow(RGB, breathe: Bool)
    case dawn

    static func style(for scene: LightScene) -> MoodArt {
        let name = scene.name.lowercased()
        if name.contains("kino") || name.contains("film") { return .cinema(scene.color) }
        guard let id = scene.flowID, let flow = Flow.everything.first(where: { $0.id == id }) else {
            if name.contains("party") { return .party(partyColors) }
            return .glow(scene.color, breathe: false)
        }
        switch flow.kind {
        case .rainbow, .music:
            return .party(partyColors)
        case .palette(let stops):
            switch flow.id {
            case "neon": return .party(stops)
            case "sunset", "lava": return .sun(stops)
            default: return .waves(stops)
            }
        case .candle:
            return .flame
        case .breathe:
            return .glow(scene.color, breathe: true)
        }
    }

    private static let partyColors = [RGB(255, 45, 106), RGB(47, 212, 255), RGB(255, 210, 63)]
}

/// Laufendes Bild einer Stimmung (füllt den ganzen Platz)
struct MoodArtView: View {
    let art: MoodArt
    /// Bei laufendem Sonnenaufgang: wie weit er ist (0…1)
    var progress: Double? = nil

    var body: some View {
        Clock { t in
            GeometryReader { geo in
                let size = geo.size
                switch art {
                case .cinema(let c): Self.cinema(c, t, size)
                case .party(let colors): Self.party(colors, t, size)
                case .waves(let colors): Self.waves(colors, t, size)
                case .sun(let colors): Self.sun(colors, t, size)
                case .flame: Self.flame(t, size)
                case .glow(let c, let breathe): Self.glow(c, breathe, t, size)
                case .dawn: Self.dawn(t, size, progress)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // Kino: flackernde Leinwand, Lichtkegel in den Saal
    private static func cinema(_ c: RGB, _ t: Double, _ size: CGSize) -> some View {
        let flick = 0.8 + 0.1 * sin(t * 5.3) + 0.06 * sin(t * 13.1 + 1) + 0.04 * sin(t * 29.7 + 2)
        let screenTop: CGFloat = 54
        let screenHeight: CGFloat = 112
        return ZStack(alignment: .top) {
            RadialGradient(colors: [c.toward(.white, 0.15).color, c.scaled(0.55).color, Color(rgb: 0x1A0A04)],
                           center: UnitPoint(x: 0.5, y: 1.1), startRadius: 0, endRadius: size.height * 1.05)
            Path { p in
                let y = screenTop + screenHeight
                p.move(to: CGPoint(x: 28, y: y))
                p.addLine(to: CGPoint(x: size.width - 28, y: y))
                p.addLine(to: CGPoint(x: size.width + 50, y: size.height))
                p.addLine(to: CGPoint(x: -50, y: size.height))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(rgb: 0xFFF6E8).opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
            .opacity(flick)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(rgb: 0xFFF6E8))
                .frame(height: screenHeight)
                .padding(.horizontal, 28)
                .padding(.top, screenTop)
                .opacity(flick)
                .shadow(color: c.toward(.white, 0.4).color.opacity(0.8), radius: 30)
        }
    }

    // Party: schwenkende Lichtstrahlen, Puls auf den Takt
    private static func party(_ colors: [RGB], _ t: Double, _ size: CGSize) -> some View {
        let beat = pow(max(0, cos(t * 2.07 * .pi * 2)), 10)
        let speeds = [1.9, 1.4, 2.4]
        return ZStack {
            Color(rgb: 0x120614)
            RadialGradient(colors: [colors[0].color.opacity(0.45 * beat), .clear],
                           center: .top, startRadius: 0, endRadius: size.height)
            ForEach(0..<3, id: \.self) { i in
                let c = colors[i % colors.count].color
                let x = size.width * (0.18 + 0.32 * CGFloat(i))
                let angle = 26 * sin(t * speeds[i] + Double(i) * 1.7)
                Rectangle()
                    .fill(LinearGradient(colors: [c, c.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 54, height: size.height * 1.6)
                    .blur(radius: 6)
                    .opacity(0.65 + 0.3 * beat)
                    .rotationEffect(.degrees(angle), anchor: .top)
                    .position(x: x, y: size.height * 0.8 - 30)
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: c, radius: 8)
                    .position(x: x, y: 2)
            }
        }
    }

    // Polarlicht und Ozean: weiche Farbbänder, darüber funkelnde Sterne
    private static func waves(_ colors: [RGB], _ t: Double, _ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(rgb: 0x041019), Color(rgb: 0x06202A)], startPoint: .top, endPoint: .bottom)
            Stars(t: t, count: 16, area: CGSize(width: size.width, height: size.height * 0.5))
            ForEach(0..<3, id: \.self) { i in
                let c = colors[i % colors.count].color
                Ellipse()
                    .fill(c)
                    .frame(width: size.width * 1.6, height: 130)
                    .blur(radius: 30)
                    .opacity(0.8)
                    .rotationEffect(.degrees(7 * sin(t * 0.5 + Double(i))))
                    .offset(x: CGFloat(32 * sin(t * (0.35 + 0.12 * Double(i)) + Double(i) * 2)),
                            y: CGFloat(Double(i - 1) * 70 - 20 + 10 * sin(t * 0.7 + Double(i))))
            }
        }
    }

    // Sonnenuntergang und Lava: Sonne über dem Horizont mit Spiegelung
    private static func sun(_ colors: [RGB], _ t: Double, _ size: CGSize) -> some View {
        let n = colors.count
        let top = colors[min(3, n - 1)].scaled(0.5)
        let mid = colors[min(2, n - 1)].scaled(0.85)
        let rise = 18 * sin(t * 0.45)
        return ZStack {
            LinearGradient(colors: [Color(rgb: 0x14061C), top.color, mid.color, colors[0].color],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [Color(rgb: 0xFFF1C2), colors[min(1, n - 1)].color, colors[0].color.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 115))
                .frame(width: 230, height: 230)
                .position(x: size.width / 2, y: size.height * 0.62 + CGFloat(rise))
            VStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { i in
                    let wobble = CGFloat(10 * sin(t * 1.6 + Double(i)))
                    Capsule()
                        .fill(Color(rgb: 0xFFF1C2).opacity(0.35 - Double(i) * 0.05))
                        .frame(width: CGFloat(150 - i * 22) + wobble, height: 2.5)
                }
            }
            .position(x: size.width / 2, y: size.height * 0.8)
        }
    }

    // Kerzenschein: flackernde Flamme mit warmem Schein
    private static func flame(_ t: Double, _ size: CGSize) -> some View {
        let f = 1 + 0.07 * sin(t * 7.3) + 0.04 * sin(t * 13.1 + 1) + 0.03 * sin(t * 23.3 + 2)
        let center = CGPoint(x: size.width / 2, y: size.height * 0.36)
        return ZStack {
            RadialGradient(colors: [Color(rgb: 0x5A2A08), Color(rgb: 0x140803)],
                           center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: size.height * 0.8)
            Circle()
                .fill(RadialGradient(colors: [Color(rgb: 0xFFB347).opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 260)
                .scaleEffect(CGFloat(f))
                .position(center)
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(rgb: 0xF2E6CF), Color(rgb: 0xB9A783)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 46, height: 120)
                .position(x: center.x, y: center.y + 104)
            IconShape(kind: .drop)
                .fill(LinearGradient(colors: [Color(rgb: 0xFFF6D8), Color(rgb: 0xFFB347), Color(rgb: 0xFF5A1F)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 54, height: 72)
                .scaleEffect(x: 0.75, y: CGFloat(f), anchor: .bottom)
                .rotationEffect(.degrees(4 * sin(t * 2.3)), anchor: .bottom)
                .shadow(color: Color(rgb: 0xFFB347), radius: 18)
                .position(x: center.x, y: center.y + 4)
        }
    }

    // Feste Farbe und Atmen: leuchtender Kern, Lichtwellen breiten sich aus
    private static func glow(_ c: RGB, _ breathe: Bool, _ t: Double, _ size: CGSize) -> some View {
        let pulse = breathe ? 0.5 - 0.5 * cos(t * 1.4) : 0.5 + 0.15 * sin(t * 1.1)
        let center = CGPoint(x: size.width / 2, y: size.height * 0.4)
        return ZStack {
            RadialGradient(colors: [c.scaled(0.28).color, Color(rgb: 0x0A0807)],
                           center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: size.height * 0.8)
            Circle()
                .fill(c.color)
                .frame(width: 170, height: 170)
                .blur(radius: 46)
                .opacity(0.5 + 0.4 * pulse)
                .scaleEffect(CGFloat(0.9 + 0.25 * pulse))
                .position(center)
            ForEach(0..<3, id: \.self) { i in
                let k = (t / 3.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Circle()
                    .strokeBorder(c.toward(.white, 0.3).color.opacity(0.55 * (1 - k)), lineWidth: 1.5)
                    .frame(width: CGFloat(56 + 230 * k), height: CGFloat(56 + 230 * k))
                    .position(center)
            }
            Circle()
                .fill(RadialGradient(colors: [.white, c.toward(.white, 0.25).color, c.color], center: .center, startRadius: 0, endRadius: 28))
                .frame(width: 56, height: 56)
                .shadow(color: c.color, radius: 24)
                .position(center)
        }
    }

    // Aufwachen: die Sonne geht auf, die Sterne verblassen
    private static func dawn(_ t: Double, _ size: CGSize, _ progress: Double?) -> some View {
        let k = progress ?? (0.5 - 0.5 * cos(t * 0.55))
        return ZStack {
            LinearGradient(colors: [Color(rgb: 0x160D24), Color(rgb: 0x3A1630), Color(rgb: 0x7A2D1A)],
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [Color(rgb: 0xFF9A4D).opacity(0), Color(rgb: 0xFFB36B).opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
                .opacity(k)
            Stars(t: t, count: 14, area: CGSize(width: size.width, height: size.height * 0.45))
                .opacity(1 - k)
            Circle()
                .fill(RadialGradient(colors: [Color(rgb: 0xFFF1C2), Color(rgb: 0xFFB347), Color(rgb: 0xFF5A3C).opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .position(x: size.width / 2, y: size.height + 40 - CGFloat(k) * 140)
        }
    }
}

/// Funkelnde Sterne an festen Stellen
private struct Stars: View {
    let t: Double
    let count: Int
    let area: CGSize

    var body: some View {
        Canvas { context, _ in
            for i in 0..<count {
                // Feste, gut verteilte Stellen (keine Zufallszahlen, damit nichts springt)
                let x = CGFloat((Double(i) * 0.618034).truncatingRemainder(dividingBy: 1)) * area.width
                let y = CGFloat((Double(i) * 0.381966 + 0.07).truncatingRemainder(dividingBy: 1)) * area.height
                let a = 0.25 + 0.55 * (0.5 + 0.5 * sin(t * (1.3 + Double(i % 4) * 0.4) + Double(i)))
                let d: CGFloat = i % 3 == 0 ? 2.2 : 1.4
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(.white.opacity(a)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Poster

/// Poster einer Stimmung: Bild, Name, Wert und Start-Knopf
struct MoodPoster: View {
    let art: MoodArt
    let title: String
    let subtitle: String
    let active: Bool
    var ramp: LightController.Ramp? = nil
    let action: () -> Void

    static let size = CGSize(width: 252, height: 330)

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                if let ramp {
                    Clock { _ in
                        MoodArtView(art: art, progress: ramp.progress(at: Date()))
                    }
                } else {
                    MoodArtView(art: art)
                }
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.6)], startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.geist(32, 800))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(subtitle.uppercased())
                        .font(.geistMono(11, 600))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    if let ramp {
                        Clock { _ in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.22))
                                    Capsule()
                                        .fill(Theme.accent)
                                        .frame(width: max(4, geo.size.width * CGFloat(ramp.progress(at: Date()))))
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(20)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(active ? Theme.accent : Color.white.opacity(0.08), lineWidth: active ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                PlayBadge(active: active).padding(16)
            }
            .shadow(color: .black.opacity(0.55), radius: 22, y: 14)
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .sensoryFeedback(.impact(weight: .medium), trigger: active)
        .accessibilityLabel("Stimmung \(title)")
        .accessibilityValue(active ? "Läuft" : "")
        .accessibilityHint("Startet die Stimmung auf allen Lichtern")
    }
}

/// Start-Knopf auf dem Poster; läuft die Stimmung, tanzen dort kleine Balken
private struct PlayBadge: View {
    let active: Bool

    var body: some View {
        ZStack {
            Circle().fill(active ? Theme.accent : Color.white.opacity(0.92))
            if active {
                Clock { t in
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(Theme.ink)
                                .frame(width: 3.5, height: 5 + 11 * abs(sin(t * (3.1 + Double(i) * 1.3) + Double(i))))
                        }
                    }
                    .frame(height: 17, alignment: .bottom)
                }
            } else {
                PlayShape()
                    .fill(Theme.ink)
                    .frame(width: 15, height: 16)
                    .offset(x: 1.5)
            }
        }
        .frame(width: 46, height: 46)
        .shadow(color: active ? Theme.accent.opacity(0.7) : .black.opacity(0.3), radius: active ? 12 : 6)
        .accessibilityHidden(true)
    }
}

struct PlayShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Letztes Poster: eigene Stimmung aus dem aktuellen Licht anlegen
struct NewMoodPoster: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Icon(kind: .plus, size: 26, color: Theme.accent)
                    .frame(width: 62, height: 62)
                    .background(Theme.accent.opacity(0.1), in: Circle())
                Text("Eigene Stimmung")
                    .font(.geist(20, 700))
                    .foregroundStyle(Theme.text)
                Text("AKTUELLES LICHT SPEICHERN")
                    .font(.geistMono(10, 600))
                    .tracking(1.4)
                    .foregroundStyle(Theme.muted)
            }
            .frame(width: MoodPoster.size.width * 0.72, height: MoodPoster.size.height)
            .background(Theme.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }
}
