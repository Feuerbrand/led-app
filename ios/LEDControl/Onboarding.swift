import CoreBluetooth
import SwiftUI

/// Einführung beim allerersten Start: kurz zeigen, was die App kann, und dabei Bluetooth starten
enum Onboarding {
    /// Für die automatischen App-Store-Bilder keine Einführung
    static var skipped: Bool {
        let defaults = UserDefaults.standard
        // „-showIntro YES“ zeigt sie trotzdem (für das Vorführ-Video)
        if defaults.bool(forKey: "showIntro") { return false }
        return defaults.string(forKey: "screenshotPage") != nil || defaults.bool(forKey: "demo")
    }

    /// Bluetooth gleich beim Start einschalten? Beim ersten Start erst in der Einführung (dort kommt die Abfrage),
    /// außer die App darf Bluetooth schon benutzen.
    static var mayStartBluetooth: Bool {
        if UserDefaults.standard.bool(forKey: "led-app.onboarded") || skipped { return true }
        return CBCentralManager.authorization == .allowedAlways
    }
}

struct OnboardingView: View {
    let finish: () -> Void

    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var page = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Group {
                switch page {
                case 0: IntroPage(next: next)
                case 1: ConnectPage(next: next)
                case 2: ColorPage(next: next)
                case 3: MusicPage(next: next)
                default: DonePage(finish: done)
                }
            }
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .overlay(alignment: .topTrailing) {
            if page >= 1 && page <= 3 {
                Button("Überspringen") { done(addLight: false) }
                    .font(.geist(15, 500))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .medium), trigger: page)
    }

    private func next() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) { page += 1 }
    }

    private func done(addLight: Bool) {
        light.start()
        if addLight { nav.addLight = true }
        finish()
    }
}

// MARK: - Bausteine

/// Einblenden: von unten, unscharf zu scharf
private struct Reveal: ViewModifier {
    let delay: Double

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var still

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 24)
            .blur(radius: shown ? 0 : 8)
            .onAppear {
                if still {
                    shown = true
                } else {
                    withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.75).delay(delay)) { shown = true }
                }
            }
    }
}

/// Aufploppen mit Nachfedern
private struct Pop: ViewModifier {
    let delay: Double

    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.4)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(delay)) { shown = true }
            }
    }
}

private extension View {
    func reveal(_ delay: Double) -> some View { modifier(Reveal(delay: delay)) }
    func pop(_ delay: Double) -> some View { modifier(Pop(delay: delay)) }
}

/// Großer gelber Knopf unten
private struct BigButton: View {
    let title: String
    var symbol: String? = nil
    var shine = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.geist(18, 700))
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                if shine { Shine().clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) }
            }
            .shadow(color: Theme.accent.opacity(0.35), radius: 20, y: 8)
        }
        .buttonStyle(PressStyle(scale: 0.95))
    }
}

/// Glanz, der über den Knopf läuft
private struct Shine: View {
    var body: some View {
        Clock { t in
            GeometryReader { geo in
                let w: CGFloat = geo.size.width
                let s: Double = (t / 2.2).truncatingRemainder(dividingBy: 1)
                let k: CGFloat = CGFloat(min(s / 0.55, 1))
                LinearGradient(colors: [.clear, .white.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 90)
                    .rotationEffect(.degrees(12))
                    .offset(x: -120 + k * (w + 240))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Punkte für die Seiten
private struct PageDots: View {
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.accent : Color.white.opacity(0.22))
                    .frame(width: i == current ? 24 : 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

/// Seite mit Text oben, Bild in der Mitte und Knopf unten
private struct StepPage<Visual: View>: View {
    let index: Int
    let label: String
    let title: String
    let text: String
    let next: () -> Void
    @ViewBuilder let visual: () -> Visual

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.geistMono(12, 600))
                .tracking(1.8)
                .foregroundStyle(Theme.accent)
                .reveal(0.1)
            Text(title)
                .font(.geist(40, 800))
                .foregroundStyle(Theme.text)
                .padding(.top, 12)
                .reveal(0.18)
            Text(text)
                .font(.geist(17, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)
                .reveal(0.28)
            Spacer(minLength: 12)
            visual()
                .frame(maxWidth: .infinity)
            Spacer(minLength: 12)
            PageDots(current: index)
                .padding(.bottom, 22)
            BigButton(title: "Weiter", action: next)
                .reveal(0.45)
        }
        .padding(.horizontal, 26)
        .padding(.top, 56)
        .padding(.bottom, 12)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

/// Farben, die weich ineinander übergehen (hin und zurück, ohne trübe Zwischentöne)
private enum Glow {
    static let colors: [RGB] = [RGB(255, 59, 122), RGB(162, 75, 255), RGB(59, 107, 255), RGB(0, 200, 255)]

    static func color(_ t: Double) -> Color {
        let x: Double = (1 - cos(t * 0.9)) / 2 * Double(colors.count - 1)
        let i: Int = min(Int(x), colors.count - 2)
        let e: Double = x - Double(i)
        let a: RGB = colors[i]
        let b: RGB = colors[i + 1]
        return a.toward(b, e).color
    }
}

// MARK: - 1 · Start

private struct IntroPage: View {
    let next: () -> Void

    @State private var strip: CGFloat = 0
    @State private var stripGone = false
    @State private var orb = false

    private static let letters: [String] = "LED Controller".map { String($0) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Clock { t in
                    OrbArt(t: t, shown: orb)
                }
                RainbowStrip(width: strip)
                    .opacity(stripGone ? 0 : 1)
            }
            .frame(height: 300)

            HStack(spacing: 0) {
                ForEach(Array(Self.letters.enumerated()), id: \.offset) { i, letter in
                    Text(letter)
                        .reveal(1.45 + Double(i) * 0.045)
                }
            }
            .font(.geist(40, 800))
            .foregroundStyle(Theme.text)
            .padding(.top, 26)

            Text("Dein Licht. Deine Farben.\nEin Wisch.")
                .font(.geist(18, 400))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 12)
                .reveal(2.05)
            Spacer(minLength: 0)
            BigButton(title: "Los geht’s", symbol: "arrow.right", action: next)
                .reveal(2.4)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 12)
        .frame(maxWidth: 520)
        .onAppear {
            withAnimation(.timingCurve(0.6, 0, 0.2, 1, duration: 0.55).delay(0.15)) { strip = 290 }
            withAnimation(.timingCurve(0.6, 0, 0.4, 1, duration: 0.45).delay(0.95)) {
                strip = 24
                stripGone = true
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(1.1)) { orb = true }
        }
    }
}

/// Leuchtende Regenbogen-Leiste, deren Farben laufen
private struct RainbowStrip: View {
    let width: CGFloat

    var body: some View {
        Clock { t in
            let colors: [Color] = (0..<7).map { i in
                ColorMath.hsv((Double(i) * 60 + t * 140).truncatingRemainder(dividingBy: 360), 0.85, 1).color
            }
            Capsule()
                .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .frame(width: width, height: 7)
                .shadow(color: Color(rgb: 0xFF78C8).opacity(0.8), radius: 14)
        }
    }
}

/// Die Lichtkugel: wechselt die Farbe, atmet, Ringe laufen nach außen
private struct OrbArt: View {
    let t: Double
    let shown: Bool

    var body: some View {
        let c: Color = Glow.color(t)
        let breathe: CGFloat = 1 + 0.08 * CGFloat(sin(t * 3.6))
        ZStack {
            Circle()
                .fill(c)
                .frame(width: 330, height: 330)
                .blur(radius: 60)
                .opacity(0.45)
                .scaleEffect(breathe)
            ForEach(0..<2, id: \.self) { k in
                OrbRing(t: t, offset: Double(k) * 0.5)
            }
            Circle()
                .fill(c)
                .overlay {
                    Circle().fill(RadialGradient(colors: [.white.opacity(0.95), .white.opacity(0.3), .clear, .black.opacity(0.3)],
                                                 center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: 90))
                }
                .frame(width: 150, height: 150)
                .shadow(color: c.opacity(0.8), radius: 40)
        }
        .scaleEffect(shown ? 1 : 0.2)
        .opacity(shown ? 1 : 0)
    }
}

private struct OrbRing: View {
    let t: Double
    let offset: Double

    var body: some View {
        let p: Double = (t * 0.55 + offset).truncatingRemainder(dividingBy: 1)
        Circle()
            .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
            .frame(width: 150, height: 150)
            .scaleEffect(1 + 1.1 * CGFloat(p))
            .opacity(0.8 * (1 - p))
    }
}

// MARK: - 2 · Verbinden

private struct ConnectPage: View {
    let next: () -> Void

    @Environment(LightController.self) private var light

    var body: some View {
        StepPage(index: 1, label: "SCHRITT 1 · VERBINDEN", title: "Licht an.\nWir finden es.",
                 text: "Einfach einstecken – die App sucht von allein. Kein Code, kein Koppeln.", next: next) {
            VStack(spacing: 26) {
                Radar()
                    .frame(height: 200)
                    .pop(0.35)
                FoundList()
            }
        }
        .onAppear { light.start() }
    }
}

/// Bluetooth-Symbol mit Radar-Ringen
private struct Radar: View {
    var body: some View {
        Clock { t in
            ZStack {
                ForEach(0..<3, id: \.self) { k in
                    RadarRing(t: t, offset: Double(k) / 3)
                }
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 104, height: 104)
                    .background(Theme.accent, in: Circle())
                    .shadow(color: Theme.accent.opacity(0.55), radius: 30)
            }
        }
    }
}

private struct RadarRing: View {
    let t: Double
    let offset: Double

    var body: some View {
        let p: Double = (t / 2.1 + offset).truncatingRemainder(dividingBy: 1)
        Circle()
            .strokeBorder(Theme.accent.opacity(0.6), lineWidth: 2)
            .frame(width: 104, height: 104)
            .scaleEffect(1 + 2.0 * CGFloat(p))
            .opacity(0.9 * (1 - p))
    }
}

/// Gefundene Lichter erscheinen nacheinander
private struct FoundList: View {
    @Environment(LightController.self) private var light

    private var problem: String? {
        switch light.hub.bluetooth {
        case .off: return "Bluetooth ist aus – im Kontrollzentrum einschalten."
        case .denied: return "Bluetooth ist nicht erlaubt – später in den Einstellungen erlauben."
        case .unsupported: return "Dieses Gerät kann kein Bluetooth."
        default: return nil
        }
    }

    var body: some View {
        let mine = Array(light.hub.mine.prefix(3))
        VStack(spacing: 10) {
            if let problem {
                FoundRow(title: problem, color: nil, found: false)
            } else if mine.isEmpty {
                FoundRow(title: "Sucht in der Nähe …", color: nil, found: false)
            } else {
                ForEach(mine) { item in
                    FoundRow(title: item.title, color: light.glow(.light(item.id)), found: true)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: mine.map { $0.id })
        .reveal(0.6)
    }
}

private struct FoundRow: View {
    let title: String
    let color: RGB?
    let found: Bool

    var body: some View {
        HStack(spacing: 14) {
            if let color {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CardPalette.darkText([color]) ? Theme.ink : Color.white)
                    .frame(width: 40, height: 40)
                    .background(color.color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: color.color.opacity(0.7), radius: 10)
            } else {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(width: 40, height: 40)
            }
            Text(title)
                .font(.geist(16, 600))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
            Spacer(minLength: 6)
            if found {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("gefunden")
                }
                .font(.geist(14, 600))
                .foregroundStyle(Color(rgb: 0x5EE08A))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 68)
        .background(Color(rgb: 0x1E1C16, opacity: 0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        }
    }
}

// MARK: - 3 · Farbe

private struct ColorPage: View {
    let next: () -> Void

    @Environment(LightController.self) private var light
    @State private var picked: RGB? = nil

    var body: some View {
        StepPage(index: 2, label: "SCHRITT 2 · FARBE", title: "Wischen.\nLeuchten.",
                 text: "Farbe antippen, Helligkeit ziehen – fertig. Probier’s aus und dreh am Rad.", next: next) {
            Clock { t in
                let auto: RGB = ColorMath.hsv((t * 45).truncatingRemainder(dividingBy: 360), 0.8, 1)
                let c: RGB = picked ?? auto
                ZStack {
                    Circle()
                        .fill(c.color)
                        .frame(width: 360, height: 360)
                        .blur(radius: 70)
                        .opacity(0.5)
                    ColorWheel(color: c) { chosen in
                        picked = chosen
                        // Ist schon ein Licht verbunden, leuchtet es gleich mit
                        if light.isConnected(.all) { light.pick(chosen, instant: true) }
                    }
                    .frame(width: 250, height: 250)
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                    .accessibilityIdentifier("intro-farbrad")
                }
            }
            .frame(height: 300)
            .pop(0.3)
        }
    }
}

// MARK: - 4 · Musik

private struct MusicPage: View {
    let next: () -> Void

    var body: some View {
        StepPage(index: 3, label: "SCHRITT 3 · EFFEKTE", title: "Licht, das\nmittanzt.",
                 text: "Musik an – deine Lichter pulsieren im Takt. Dazu Effekte, Szenen und Gute Nacht.", next: next) {
            VStack(spacing: 28) {
                Clock { t in
                    Equalizer(t: t)
                }
                .frame(height: 210)
                .pop(0.3)
                HStack(spacing: 9) {
                    Chip(symbol: "music.note", title: "Musik").pop(0.7)
                    Chip(symbol: "sparkles", title: "Effekte").pop(0.85)
                    Chip(symbol: "moon.stars.fill", title: "Gute Nacht").pop(1.0)
                }
            }
        }
    }
}

/// Bunte Balken, die im Takt springen
private struct Equalizer: View {
    let t: Double

    private static let count = 11

    var body: some View {
        let beat: Double = pow(abs(sin(t * 3.4)), 6)
        ZStack {
            Circle()
                .fill(Color(rgb: 0x8A4BFF))
                .frame(width: 330, height: 330)
                .blur(radius: 70)
                .opacity(0.35 + 0.3 * beat)
                .scaleEffect(1 + 0.1 * CGFloat(beat))
            HStack(spacing: 9) {
                ForEach(0..<Self.count, id: \.self) { i in
                    EqualizerBar(index: i, count: Self.count, t: t)
                }
            }
        }
    }
}

private struct EqualizerBar: View {
    let index: Int
    let count: Int
    let t: Double

    var body: some View {
        let i: Double = Double(index)
        let a: Double = abs(sin(t * (3.1 + i * 0.37) + i * 1.3))
        let b: Double = abs(sin(t * (5.3 - i * 0.21) + i * 0.7))
        let level: Double = 0.18 + 0.82 * (0.6 * a + 0.4 * b)
        let hue: Double = 330 - i / Double(count - 1) * 170
        let c: Color = ColorMath.hsv(hue.truncatingRemainder(dividingBy: 360), 0.8, 1).color
        Capsule()
            .fill(c)
            .frame(width: 15, height: 190 * CGFloat(level))
            .shadow(color: c.opacity(0.8), radius: 10)
    }
}

private struct Chip: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.geist(15, 600))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }
    }
}

// MARK: - 5 · Fertig

private struct DonePage: View {
    let finish: (Bool) -> Void

    @Environment(LightController.self) private var light
    @State private var burst = false
    @State private var check = false

    var body: some View {
        let needsLight: Bool = light.hub.mine.isEmpty && !light.demo
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Clock { t in
                    ZStack {
                        ForEach(0..<2, id: \.self) { k in
                            DoneRing(t: t, offset: Double(k) * 0.5)
                        }
                    }
                }
                ForEach(0..<Self.sparks.count, id: \.self) { i in
                    Spark(spark: Self.sparks[i], burst: burst)
                }
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 130, height: 130)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 40)
                    .pop(0.1)
                CheckShape()
                    .trim(from: 0, to: check ? 1 : 0)
                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                    .frame(width: 130, height: 130)
            }
            .frame(height: 300)

            Text("Alles bereit.")
                .font(.geist(40, 800))
                .foregroundStyle(Theme.text)
                .padding(.top, 20)
                .reveal(0.6)
            Text(needsLight ? "Jetzt noch dein erstes Licht hinzufügen." : "Viel Spaß mit deinem Licht.")
                .font(.geist(18, 400))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .reveal(0.75)
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                if needsLight {
                    BigButton(title: "Erstes Licht hinzufügen", symbol: "plus", shine: true) { finish(true) }
                    Button("Später") { finish(false) }
                        .font(.geist(15, 600))
                        .foregroundStyle(Theme.muted)
                } else {
                    BigButton(title: "Los geht’s", symbol: "arrow.right", shine: true) { finish(false) }
                }
            }
            .reveal(0.95)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 12)
        .frame(maxWidth: 520)
        .sensoryFeedback(.success, trigger: check)
        .onAppear {
            withAnimation(.timingCurve(0.1, 0.7, 0.3, 1, duration: 1.3).delay(0.2)) { burst = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.55)) { check = true }
        }
    }

    fileprivate struct SparkInfo {
        let x: CGFloat
        let y: CGFloat
        let color: RGB
    }

    private static let sparks: [SparkInfo] = [
        SparkInfo(x: -150, y: -120, color: RGB(255, 59, 122)), SparkInfo(x: 150, y: -130, color: RGB(255, 179, 59)),
        SparkInfo(x: -170, y: 40, color: RGB(59, 208, 255)), SparkInfo(x: 170, y: 60, color: RGB(138, 75, 255)),
        SparkInfo(x: -60, y: -190, color: RGB(59, 255, 138)), SparkInfo(x: 70, y: -185, color: RGB(255, 42, 212)),
        SparkInfo(x: -110, y: 150, color: RGB(255, 230, 59)), SparkInfo(x: 120, y: 150, color: RGB(0, 229, 255)),
        SparkInfo(x: -190, y: -40, color: RGB(255, 122, 89)), SparkInfo(x: 195, y: -30, color: RGB(196, 59, 255)),
        SparkInfo(x: 0, y: -210, color: RGB(255, 255, 255)), SparkInfo(x: 10, y: 190, color: RGB(255, 59, 154)),
    ]
}

/// Farbiger Lichtpunkt, der aus der Mitte fliegt und verglüht
private struct Spark: View {
    let spark: DonePage.SparkInfo
    let burst: Bool

    var body: some View {
        let c: Color = spark.color.color
        Circle()
            .fill(c)
            .frame(width: 12, height: 12)
            .shadow(color: c, radius: 8)
            .offset(x: burst ? spark.x : 0, y: burst ? spark.y : 0)
            .scaleEffect(burst ? 1 : 0.3)
            .opacity(burst ? 0 : 1)
    }
}

private struct DoneRing: View {
    let t: Double
    let offset: Double

    var body: some View {
        let p: Double = (t / 2 + offset).truncatingRemainder(dividingBy: 1)
        Circle()
            .strokeBorder(Theme.accent.opacity(0.55), lineWidth: 2)
            .frame(width: 130, height: 130)
            .scaleEffect(1 + 1.2 * CGFloat(p))
            .opacity(0.9 * (1 - p))
    }
}

/// Haken im 130er-Kreis
private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s: CGFloat = rect.width / 130
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 40 * s, y: rect.minY + 67 * s))
        p.addLine(to: CGPoint(x: rect.minX + 58 * s, y: rect.minY + 85 * s))
        p.addLine(to: CGPoint(x: rect.minX + 92 * s, y: rect.minY + 48 * s))
        return p
    }
}
