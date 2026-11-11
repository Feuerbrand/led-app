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

extension LightScene {
    /// Kurz, was die Szene macht: Effekt oder Farbe, dazu die Helligkeit
    var summary: String {
        let what: String
        if let id = flowID, let flow = Flow.everything.first(where: { $0.id == id }) {
            what = flow.name
        } else {
            what = color.hex
        }
        return "\(what) · \(brightness) %"
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
        let a: Double = 0.1 * sin(t * 5.3)
        let b: Double = 0.06 * sin(t * 13.1 + 1)
        let d: Double = 0.04 * sin(t * 29.7 + 2)
        let flick: Double = 0.8 + a + b + d
        let screenTop: CGFloat = 54
        let screenHeight: CGFloat = 112
        let back: [Color] = [c.toward(.white, 0.15).color, c.scaled(0.55).color, Color(rgb: 0x1A0A04)]
        let reach: CGFloat = size.height * 1.05
        let cone: Path = Self.cone(top: screenTop + screenHeight, size: size)
        let beam = LinearGradient(colors: [Color(rgb: 0xFFF6E8).opacity(0.28), Color.clear], startPoint: .top, endPoint: .bottom)
        let halo: Color = c.toward(.white, 0.4).color.opacity(0.8)
        return ZStack(alignment: .top) {
            RadialGradient(colors: back, center: UnitPoint(x: 0.5, y: 1.1), startRadius: 0, endRadius: reach)
            cone
                .fill(beam)
                .opacity(flick)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(rgb: 0xFFF6E8))
                .frame(height: screenHeight)
                .padding(.horizontal, 28)
                .padding(.top, screenTop)
                .opacity(flick)
                .shadow(color: halo, radius: 30)
        }
    }

    /// Lichtkegel von der Unterkante der Leinwand bis zum Boden
    private static func cone(top y: CGFloat, size: CGSize) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 28, y: y))
        p.addLine(to: CGPoint(x: size.width - 28, y: y))
        p.addLine(to: CGPoint(x: size.width + 50, y: size.height))
        p.addLine(to: CGPoint(x: -50, y: size.height))
        p.closeSubpath()
        return p
    }

    // Party: schwenkende Lichtstrahlen, Puls auf den Takt
    private static func party(_ colors: [RGB], _ t: Double, _ size: CGSize) -> some View {
        let wave: Double = max(0, cos(t * 2.07 * Double.pi * 2))
        let beat: Double = pow(wave, 10)
        let flash: Color = colors[0].color.opacity(0.45 * beat)
        return ZStack {
            Color(rgb: 0x120614)
            RadialGradient(colors: [flash, Color.clear], center: .top, startRadius: 0, endRadius: size.height)
            ForEach(0..<3, id: \.self) { i in
                Self.beam(colors[i % colors.count], i, t, beat, size)
            }
        }
    }

    private static let beamSpeeds: [Double] = [1.9, 1.4, 2.4]

    private static func beam(_ rgb: RGB, _ i: Int, _ t: Double, _ beat: Double, _ size: CGSize) -> some View {
        let c: Color = rgb.color
        let x: CGFloat = size.width * (0.18 + 0.32 * CGFloat(i))
        let swing: Double = sin(t * beamSpeeds[i % beamSpeeds.count] + Double(i) * 1.7)
        let angle: Double = 26 * swing
        let length: CGFloat = size.height * 1.6
        let y: CGFloat = size.height * 0.8 - 30
        let strength: Double = 0.65 + 0.3 * beat
        let fade = LinearGradient(colors: [c, c.opacity(0)], startPoint: .top, endPoint: .bottom)
        return ZStack {
            Rectangle()
                .fill(fade)
                .frame(width: 54, height: length)
                .blur(radius: 6)
                .opacity(strength)
                .rotationEffect(.degrees(angle), anchor: .top)
                .position(x: x, y: y)
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .shadow(color: c, radius: 8)
                .position(x: x, y: 2)
        }
    }

    // Polarlicht und Ozean: weiche Farbbänder, darüber funkelnde Sterne
    private static func waves(_ colors: [RGB], _ t: Double, _ size: CGSize) -> some View {
        let sky = LinearGradient(colors: [Color(rgb: 0x041019), Color(rgb: 0x06202A)], startPoint: .top, endPoint: .bottom)
        let area = CGSize(width: size.width, height: size.height * 0.5)
        return ZStack {
            sky
            Stars(t: t, count: 16, area: area)
            ForEach(0..<3, id: \.self) { i in
                Self.band(colors[i % colors.count], i, t, size)
            }
        }
    }

    private static func band(_ rgb: RGB, _ i: Int, _ t: Double, _ size: CGSize) -> some View {
        let k = Double(i)
        let angle: Double = 7 * sin(t * 0.5 + k)
        let dx: Double = 32 * sin(t * (0.35 + 0.12 * k) + k * 2)
        let drift: Double = 10 * sin(t * 0.7 + k)
        let dy: Double = (k - 1) * 70 - 20 + drift
        let width: CGFloat = size.width * 1.6
        return Ellipse()
            .fill(rgb.color)
            .frame(width: width, height: 130)
            .blur(radius: 30)
            .opacity(0.8)
            .rotationEffect(.degrees(angle))
            .offset(x: CGFloat(dx), y: CGFloat(dy))
    }

    // Sonnenuntergang und Lava: Sonne über dem Horizont mit Spiegelung
    private static func sun(_ colors: [RGB], _ t: Double, _ size: CGSize) -> some View {
        let n = colors.count
        let top: RGB = colors[min(3, n - 1)].scaled(0.5)
        let mid: RGB = colors[min(2, n - 1)].scaled(0.85)
        let sky: [Color] = [Color(rgb: 0x14061C), top.color, mid.color, colors[0].color]
        let disc: [Color] = [Color(rgb: 0xFFF1C2), colors[min(1, n - 1)].color, colors[0].color.opacity(0)]
        let rise: Double = 18 * sin(t * 0.45)
        let sunY: CGFloat = size.height * 0.62 + CGFloat(rise)
        let seaY: CGFloat = size.height * 0.8
        let midX: CGFloat = size.width / 2
        return ZStack {
            LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: disc, center: .center, startRadius: 0, endRadius: 115))
                .frame(width: 230, height: 230)
                .position(x: midX, y: sunY)
            VStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { i in
                    Self.ripple(i, t)
                }
            }
            .position(x: midX, y: seaY)
        }
    }

    private static func ripple(_ i: Int, _ t: Double) -> some View {
        let wobble: Double = 10 * sin(t * 1.6 + Double(i))
        let width: CGFloat = CGFloat(150 - i * 22) + CGFloat(wobble)
        let alpha: Double = 0.35 - Double(i) * 0.05
        return Capsule()
            .fill(Color(rgb: 0xFFF1C2).opacity(alpha))
            .frame(width: width, height: 2.5)
    }

    // Kerzenschein: flackernde Flamme mit warmem Schein
    private static func flame(_ t: Double, _ size: CGSize) -> some View {
        let a: Double = 0.07 * sin(t * 7.3)
        let b: Double = 0.04 * sin(t * 13.1 + 1)
        let d: Double = 0.03 * sin(t * 23.3 + 2)
        let f = CGFloat(1 + a + b + d)
        let sway: Double = 4 * sin(t * 2.3)
        let center = CGPoint(x: size.width / 2, y: size.height * 0.36)
        let reach: CGFloat = size.height * 0.8
        let warm = Color(rgb: 0xFFB347)
        let fire = LinearGradient(colors: [Color(rgb: 0xFFF6D8), warm, Color(rgb: 0xFF5A1F)], startPoint: .top, endPoint: .bottom)
        let wax = LinearGradient(colors: [Color(rgb: 0xF2E6CF), Color(rgb: 0xB9A783)], startPoint: .leading, endPoint: .trailing)
        let shine = RadialGradient(colors: [warm.opacity(0.6), Color.clear], center: .center, startRadius: 0, endRadius: 130)
        let candleY: CGFloat = center.y + 104
        let flameY: CGFloat = center.y + 4
        return ZStack {
            RadialGradient(colors: [Color(rgb: 0x5A2A08), Color(rgb: 0x140803)],
                           center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: reach)
            Circle()
                .fill(shine)
                .frame(width: 260, height: 260)
                .scaleEffect(f)
                .position(center)
            RoundedRectangle(cornerRadius: 6)
                .fill(wax)
                .frame(width: 46, height: 120)
                .position(x: center.x, y: candleY)
            IconShape(kind: .drop)
                .fill(fire)
                .frame(width: 54, height: 72)
                .scaleEffect(x: 0.75, y: f, anchor: .bottom)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .shadow(color: warm, radius: 18)
                .position(x: center.x, y: flameY)
        }
    }

    // Feste Farbe und Atmen: leuchtender Kern, Lichtwellen breiten sich aus
    private static func glow(_ c: RGB, _ breathe: Bool, _ t: Double, _ size: CGSize) -> some View {
        let calm: Double = 0.5 + 0.15 * sin(t * 1.1)
        let deep: Double = 0.5 - 0.5 * cos(t * 1.4)
        let pulse: Double = breathe ? deep : calm
        let center = CGPoint(x: size.width / 2, y: size.height * 0.4)
        let reach: CGFloat = size.height * 0.8
        let back: [Color] = [c.scaled(0.28).color, Color(rgb: 0x0A0807)]
        let core: [Color] = [Color.white, c.toward(.white, 0.25).color, c.color]
        let haze: Double = 0.5 + 0.4 * pulse
        let grow = CGFloat(0.9 + 0.25 * pulse)
        return ZStack {
            RadialGradient(colors: back, center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: reach)
            Circle()
                .fill(c.color)
                .frame(width: 170, height: 170)
                .blur(radius: 46)
                .opacity(haze)
                .scaleEffect(grow)
                .position(center)
            ForEach(0..<3, id: \.self) { i in
                Self.ring(c, i, t, center)
            }
            Circle()
                .fill(RadialGradient(colors: core, center: .center, startRadius: 0, endRadius: 28))
                .frame(width: 56, height: 56)
                .shadow(color: c.color, radius: 24)
                .position(center)
        }
    }

    private static func ring(_ c: RGB, _ i: Int, _ t: Double, _ center: CGPoint) -> some View {
        let k: Double = (t / 3.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
        let d = CGFloat(56 + 230 * k)
        let line: Color = c.toward(.white, 0.3).color.opacity(0.55 * (1 - k))
        return Circle()
            .strokeBorder(line, lineWidth: 1.5)
            .frame(width: d, height: d)
            .position(center)
    }

    // Aufwachen: die Sonne geht auf, die Sterne verblassen
    private static func dawn(_ t: Double, _ size: CGSize, _ progress: Double?) -> some View {
        let idle: Double = 0.5 - 0.5 * cos(t * 0.55)
        let k: Double = progress ?? idle
        let night: [Color] = [Color(rgb: 0x160D24), Color(rgb: 0x3A1630), Color(rgb: 0x7A2D1A)]
        let morning: [Color] = [Color(rgb: 0xFF9A4D).opacity(0), Color(rgb: 0xFFB36B).opacity(0.55)]
        let disc: [Color] = [Color(rgb: 0xFFF1C2), Color(rgb: 0xFFB347), Color(rgb: 0xFF5A3C).opacity(0)]
        let area = CGSize(width: size.width, height: size.height * 0.45)
        let sunY: CGFloat = size.height + 40 - CGFloat(k) * 140
        return ZStack {
            LinearGradient(colors: night, startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: morning, startPoint: .top, endPoint: .bottom)
                .opacity(k)
            Stars(t: t, count: 14, area: area)
                .opacity(1 - k)
            Circle()
                .fill(RadialGradient(colors: disc, center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .position(x: size.width / 2, y: sunY)
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
                let speed: Double = 1.3 + Double(i % 4) * 0.4
                let twinkle: Double = 0.5 + 0.5 * sin(t * speed + Double(i))
                let a: Double = 0.25 + 0.55 * twinkle
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
                                .frame(width: 3.5, height: Self.bar(i, t))
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
        .shadow(color: active ? Theme.accent.opacity(0.7) : Color.black.opacity(0.3), radius: active ? 12 : 6)
        .accessibilityHidden(true)
    }

    /// Höhe eines tanzenden Balkens
    static func bar(_ i: Int, _ t: Double) -> CGFloat {
        let speed: Double = 3.1 + Double(i) * 1.3
        let swing: Double = abs(sin(t * speed + Double(i)))
        return CGFloat(5 + 11 * swing)
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
