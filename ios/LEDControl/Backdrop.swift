import SwiftUI

// MARK: - Hintergrund

/// Warmes Schwarz mit hellerer Mitte, wie `body::before` auf der Webseite:
/// radial-gradient(ellipse 150% 75% at 50% 30%, #1a1913, #100f0a 50%, #060504)
struct Backdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Rectangle()
                .fill(EllipticalGradient(
                    stops: [
                        .init(color: Color(rgb: 0x1A1913), location: 0),
                        .init(color: Color(rgb: 0x100F0A), location: 0.5),
                        .init(color: Color(rgb: 0x060504), location: 1),
                    ],
                    center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
                .frame(width: w * 3, height: h * 1.5)
                .position(x: w * 0.5, y: h * 0.3)
        }
        .background(Color(rgb: 0x060504))
        .clipped()
        .ignoresSafeArea()
    }
}

/// Schwebende Lichtpunkte, nehmen die Farbe der Leiste an.
/// Feste Zufallsfolge wie auf der Webseite, damit es bei jedem Start gleich aussieht.
struct ParticleField: View {
    @Environment(LightController.self) private var light
    @Environment(\.accessibilityReduceMotion) private var still

    private struct Dot {
        let x, y, size, alpha, period, delay, dx: Double
        let soft: Bool
    }

    private static let dots: [Dot] = {
        var seed = 11
        func rnd() -> Double {
            seed = (seed * 16807) % 2147483647
            return Double(seed) / 2147483647
        }
        var out: [Dot] = []
        for _ in 0..<26 {
            let soft = rnd() < 0.3
            let size = soft ? 12 + rnd() * 14 : 2 + rnd() * 4
            let period = 14 + rnd() * 22
            let x = rnd()
            let y = (8 + rnd() * 96) / 100
            let alpha = soft ? 0.05 + rnd() * 0.07 : 0.2 + rnd() * 0.4
            let delay = rnd() * period
            let dx = (rnd() - 0.5) * 70
            out.append(Dot(x: x, y: y, size: size, alpha: alpha, period: period, delay: delay, dx: dx, soft: soft))
        }
        return out
    }()

    /// Ein- und Ausblenden über den Weg: 0 → sichtbar bei 12 %, bis 85 %, dann wieder weg
    private static func fade(_ p: Double) -> Double {
        if p < 0.12 { return p / 0.12 }
        if p < 0.85 { return 1 }
        return (1 - p) / 0.15
    }

    var body: some View {
        if !still {
            let tint = light.live ? light.led.color : Color(rgb: 0xFFE28C)
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let w = Double(size.width)
                    let h = Double(size.height)
                    for dot in Self.dots {
                        let p = (t + dot.delay).truncatingRemainder(dividingBy: dot.period) / dot.period
                        let alpha = dot.alpha * Self.fade(p)
                        let cx = dot.x * w + dot.dx * p + dot.size / 2
                        let cy = dot.y * h - 140 * p + dot.size / 2
                        if dot.soft {
                            // Weicher, unscharfer Punkt
                            let r = dot.size / 2 + 6
                            let glow = Gradient(colors: [tint.opacity(alpha), tint.opacity(0)])
                            context.fill(
                                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                                with: .radialGradient(glow, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: CGFloat(r)))
                        } else {
                            let r = dot.size / 2
                            context.fill(
                                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                                with: .color(tint.opacity(alpha)))
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Kopf: Lampe mit Lichtschein in der Farbe, die gerade im Zimmer leuchtet

struct HeroView: View {
    /// Wessen Farbe die Lampe zeigt
    var target: Target = .all
    /// nil = Schriftzug LEDCONTROL, sonst dieser Titel (Name des Lichts)
    var title: String? = nil

    @Environment(LightController.self) private var light

    var body: some View {
        let live = light.isLive(target)
        let led = light.glow(target)
        VStack(spacing: 14) {
            Bulb(led: led, live: live)
                .background {
                    SkyGlow(color: led.color, live: live, burst: light.connectedCount)
                }
            if let title {
                Text(title.uppercased())
                    .font(.geist(26, 700))
                    .tracking(2)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Wordmark()
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title ?? "LED Control")
    }
}

private struct Bulb: View {
    let led: RGB
    let live: Bool

    /// Kolbenfarbe: die Leistenfarbe, etwas mit Weiß aufgehellt (color-mix 62 %)
    private var glass: Color {
        func lighten(_ v: Int) -> Double {
            (Double(v) * 0.62 + 255 * 0.38) / 255
        }
        return Color(.sRGB, red: lighten(led.r), green: lighten(led.g), blue: lighten(led.b), opacity: 1)
    }

    var body: some View {
        ZStack {
            BulbGlass().fill(live ? glass : Theme.text.opacity(0.88))
            BulbBase().fill(Theme.icon)
        }
        .frame(width: 58, height: 58)
        .shadow(color: led.color.opacity(live ? 0.95 : 0), radius: 6)
        .shadow(color: led.color.opacity(live ? 0.55 : 0), radius: 19)
        .animation(.easeOut(duration: 0.6), value: live)
    }
}

/// Lichtschein hinter der Lampe: weiter Schimmer, drehende Strahlen, atmender Hof, Lichtring beim Verbinden
private struct SkyGlow: View {
    let color: Color
    let live: Bool
    let burst: Int

    var body: some View {
        ZStack {
            Rectangle()
                .fill(EllipticalGradient(
                    stops: [
                        .init(color: color.opacity(0.11), location: 0),
                        .init(color: color.opacity(0), location: 1),
                    ],
                    center: .center, startRadiusFraction: 0, endRadiusFraction: 0.467))
                .frame(width: 900, height: 640)
                .opacity(live ? 1 : 0.35)
            Rays(color: color)
                .opacity(live ? 1 : 0)
            Halo(color: color)
                .opacity(live ? 1 : 0.28)
            if burst > 0 {
                BurstRing().id(burst)
            }
        }
        .animation(.easeInOut(duration: 1), value: live)
        .allowsHitTesting(false)
    }
}

private struct Rays: View {
    let color: Color

    /// Wie repeating-conic-gradient: 5° Strahl, 15° Lücke
    private var stops: [Gradient.Stop] {
        let on = color.opacity(0.12)
        let off = color.opacity(0)
        var out: [Gradient.Stop] = []
        for i in 0..<18 {
            let a = Double(i) / 18
            let edge = a + 5.0 / 360
            out.append(Gradient.Stop(color: on, location: a))
            out.append(Gradient.Stop(color: on, location: edge))
            out.append(Gradient.Stop(color: off, location: edge))
            out.append(Gradient.Stop(color: off, location: a + 20.0 / 360))
        }
        return out
    }

    var body: some View {
        let rays = stops
        Clock { t in
            Circle()
                .fill(AngularGradient(stops: rays, center: .center))
                .frame(width: 440, height: 440)
                .mask {
                    RadialGradient(
                        stops: [
                            .init(color: .black, location: 0.08),
                            .init(color: .clear, location: 0.62),
                        ],
                        center: .center, startRadius: 0, endRadius: 311)
                }
                .rotationEffect(.degrees((t * 4.5).truncatingRemainder(dividingBy: 360)))     // eine Umdrehung in 80 s
        }
    }
}

private struct Halo: View {
    let color: Color

    var body: some View {
        Clock { t in
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: color.opacity(0.36), location: 0),
                        .init(color: color.opacity(0.12), location: 0.36),
                        .init(color: color.opacity(0), location: 0.68),
                    ],
                    center: .center, startRadius: 0, endRadius: 240))
                .frame(width: 340, height: 340)
                .scaleEffect(CGFloat(1 - 0.08 * cos(t * 2 * Double.pi / 5.5)))                 // atmet alle 5,5 s
        }
    }
}

/// Gelber Ring, der sich einmal ausbreitet, wenn die Verbindung steht
private struct BurstRing: View {
    @State private var grown = false

    var body: some View {
        Circle()
            .strokeBorder(Theme.accent, lineWidth: 2)
            .frame(width: 120, height: 120)
            .scaleEffect(grown ? 4.2 : 0.4)
            .opacity(grown ? 0 : 0.9)
            .onAppear {
                withAnimation(.easeOut(duration: 1)) { grown = true }
            }
    }
}

/// Schriftzug LEDCONTROL, Buchstabe für Buchstabe eingeblendet
private struct Wordmark: View {
    @State private var shown = false

    private static let letters = Array("LEDCONTROL")

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.letters.count, id: \.self) { i in
                Text(String(Self.letters[i]))
                    .font(.geist(28, 700))
                    .tracking(2.24)
                    .foregroundStyle(i < 3 ? Theme.text : Theme.accent)
                    .offset(y: shown ? 0 : 36)
                    .rotationEffect(.degrees(shown ? 0 : 9))
                    .opacity(shown ? 1 : 0)
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.75).delay(Double(i) * 0.045 + 0.12), value: shown)
            }
        }
        .padding(.bottom, 2)
        .clipped()
        .onAppear { shown = true }
    }
}
