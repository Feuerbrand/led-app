import Foundation

/// Eine Farbe als ganze Zahlen 0…255, so wie sie an die Leiste geht.
struct RGB: Equatable {
    var r: Int
    var g: Int
    var b: Int

    init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        self.init(Int((hex >> 16) & 0xff), Int((hex >> 8) & 0xff), Int(hex & 0xff))
    }

    /// Aus Text wie „FF7A00“ oder „#ff7a00“
    init?(hexString: String) {
        let text = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(hex: value)
    }

    /// Hellste der drei Grundfarben
    var peak: Int { max(r, g, b) }

    var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
}

/// Farbrechnung, 1:1 aus index.html übernommen (hsv, hueOf, mix, palette, ease).
enum ColorMath {
    static let tau = Double.pi * 2

    /// Rundet wie Math.round in JavaScript (…,5 immer nach oben)
    static func jsRound(_ x: Double) -> Int {
        Int((x + 0.5).rounded(.down))
    }

    static func ease(_ k: Double) -> Double {
        k * k * (3 - 2 * k)
    }

    static func hsv(_ h: Double, _ s: Double, _ v: Double) -> RGB {
        func f(_ n: Double) -> Int {
            let k = (n + h / 60).truncatingRemainder(dividingBy: 6)
            let m = max(0, min(k, 4 - k, 1))
            return jsRound(255 * (v - v * s * m))
        }
        return RGB(f(5), f(3), f(1))
    }

    static func hue(of c: RGB) -> Double {
        let r = Double(c.r), g = Double(c.g), b = Double(c.b)
        let mx = max(r, g, b)
        let d = mx - min(r, g, b)
        if d == 0 { return 0 }
        var h: Double
        if mx == r {
            h = (g - b) / d
        } else if mx == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h = h * 60 + 360
        return h.truncatingRemainder(dividingBy: 360)
    }

    /// Überblenden ohne Helligkeitsloch: die hellste Grundfarbe wandert gleichmäßig von a nach b
    static func mix(_ a: RGB, _ b: RGB, _ e: Double) -> RGB {
        let cr = Double(a.r) + Double(b.r - a.r) * e
        let cg = Double(a.g) + Double(b.g - a.g) * e
        let cb = Double(a.b) + Double(b.b - a.b) * e
        let m = max(cr, cg, cb)
        let pa = Double(a.peak)
        let pb = Double(b.peak)
        let want = pa + (pb - pa) * e
        func scaled(_ v: Double) -> Int {
            m != 0 ? jsRound(v * want / m) : 0
        }
        return RGB(scaled(cr), scaled(cg), scaled(cb))
    }

    /// Farbverlauf im Kreis durch mehrere Farben, immer mit voller Leuchtkraft
    static func palette(_ stops: [RGB], _ t: Double) -> RGB {
        let n = stops.count
        let x = t.truncatingRemainder(dividingBy: 1) * Double(n)
        let i = Int(x.rounded(.down))
        return mix(stops[i % n], stops[(i + 1) % n], ease(x - Double(i)))
    }
}
