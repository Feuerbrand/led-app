import Foundation

/// Flow-Effekte: die App berechnet die Farbe laufend selbst. Entspricht `FLOWS` in index.html.
struct Flow: Identifiable, Equatable {
    enum Kind: Equatable {
        case rainbow
        case palette([RGB])
        case breathe
        case candle
    }

    let id: String
    let name: String
    let kind: Kind

    /// Wie oft der Effekt in einem Durchlauf läuft (`rate` in index.html)
    var rate: Double { kind == .breathe ? 4 : 1 }

    /// Farbe an der Stelle t (0…1) des Durchlaufs. `base` ist die zuletzt gewählte feste Farbe.
    func color(at t: Double, base: RGB) -> RGB {
        switch kind {
        case .rainbow:
            return ColorMath.hsv(t * 360, 1, 1)

        case .palette(let stops):
            return ColorMath.palette(stops, t)

        case .breathe:
            // Die gewählte Farbe wird sanft heller und dunkler, geht aber nie aus
            let wave = 0.5 - 0.5 * cos(t * ColorMath.tau)
            let v = 0.3 + 0.7 * wave
            return RGB(ColorMath.jsRound(Double(base.r) * v),
                       ColorMath.jsRound(Double(base.g) * v),
                       ColorMath.jsRound(Double(base.b) * v))

        case .candle:
            // Warmes Licht mit ruhigem, unregelmäßigem Schimmern
            let a = 0.12 * sin(t * ColorMath.tau * 7)
            let b = 0.05 * sin(t * ColorMath.tau * 17 + 1)
            let c = 0.03 * sin(t * ColorMath.tau * 31 + 2)
            let v = 0.8 + a + b + c
            let green = 118 * v * (0.8 + 0.2 * v)
            let blue = 22 * v * v
            return RGB(ColorMath.jsRound(255 * v), ColorMath.jsRound(green), ColorMath.jsRound(blue))
        }
    }

    /// Farben für die laufende Vorschau auf der Karte (leer = eigene Vorschau)
    var previewStops: [RGB] {
        switch kind {
        case .rainbow:
            return [RGB(255, 0, 0), RGB(255, 255, 0), RGB(0, 255, 0), RGB(0, 255, 255), RGB(0, 0, 255), RGB(255, 0, 255)]
        case .palette(let stops):
            return stops
        case .breathe, .candle:
            return []
        }
    }

    static let all: [Flow] = [
        Flow(id: "rainbow", name: "Regenbogen", kind: .rainbow),
        Flow(id: "aurora", name: "Polarlicht",
             kind: .palette([RGB(0, 255, 130), RGB(0, 215, 255), RGB(80, 110, 255), RGB(170, 70, 255)])),
        Flow(id: "sunset", name: "Sonnenuntergang",
             kind: .palette([RGB(255, 60, 0), RGB(255, 135, 0), RGB(255, 30, 90), RGB(190, 0, 255), RGB(255, 0, 120)])),
        Flow(id: "ocean", name: "Ozean",
             kind: .palette([RGB(0, 60, 255), RGB(0, 170, 255), RGB(0, 255, 200), RGB(0, 170, 255)])),
        Flow(id: "lava", name: "Lava",
             kind: .palette([RGB(255, 0, 0), RGB(255, 70, 0), RGB(255, 150, 0), RGB(255, 70, 0)])),
        Flow(id: "neon", name: "Neon",
             kind: .palette([RGB(255, 0, 200), RGB(130, 0, 255), RGB(0, 200, 255), RGB(130, 0, 255)])),
        Flow(id: "breathe", name: "Atmen", kind: .breathe),
        Flow(id: "candle", name: "Kerzenschein", kind: .candle),
    ]
}
